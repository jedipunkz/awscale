#!/usr/bin/env ruby

require 'active_record'
require 'mysql2'
require 'sinatra'
require './lib/aws.rb'
require './lib/chef.rb'
require './lib/mysql.rb'
require './lib/ssh.rb'
require 'yaml'
require 'json'

get '/' do
  @cluster_members = mysql_search_instances()
  @counter = mysql_search_count_all()
  erb :index
end

get '/instances/json' do
  content_type :json, :charset => 'utf-8'
  instances = mysql_search_instances()
  instances.to_json(:root => false)
end

get '/instances/:instance_id/:search_key' do |instance_id, search_key|
  content_type :json, :charset => 'utf-8'
  value = mysql_search_instance_info(instance_id, search_key)
  value.to_json(:root => false)
end

post '/instances/destroy' do
  content_type :json, :charset => 'utf-8'
  params = JSON.parse(request.env["rack.input"].read)
  instance_id = params['instance_id']
  group_name = mysql_search_instance_info(instance_id, 'group_name')
  date = Time.now.strftime("%Y-%m-%d-%H:%M:%S")
  chef_delete_node(instance_id)
  result = aws_destroy_instance(instance_id)
  aws_deregister_elb(group_name, instance_id)
  delete_table_cluster_members(instance_id)
  update_dec_counter(group_name, date)
  result.to_json(:root => false)
end

post '/instances/stop' do
  content_type :json, :charset => 'utf-8'
  params = JSON.parse(request.env["rack.input"].read)
  instance_id = params['instance_id']
  result = aws_stop_instance(instance_id)
  result.to_json(:root => false)
end

post '/instances/start' do
  content_type :json, :charset => 'utf-8'
  params = JSON.parse(request.env["rack.input"].read)
  instance_id = params['instance_id']
  result = aws_start_instance(instance_id)
  result.to_json(:root => false)
end

get '/cluster_members/:group_name/json' do |group_name|
  content_type :json, :charset => 'utf-8'
  cluster_members = mysql_search_cluster_members(group_name, 'all')
  cluster_members.to_json(:root => false)
end

get '/counter/json' do
  content_type :json, :charset => 'utf-8'
  counter = mysql_search_count_all()
  counter.to_json(:root => false)
end

post '/databags' do
  raw_data = request.body.read
  chef_input_databags(raw_data)
  raw_data.to_json(:root => false)
end

post '/bootstrap' do
  params = JSON.parse(request.env["rack.input"].read)
  flavor_id = params['flavor_id']
  key_name = params['key_name']
  secgroup = params['secgroup']
  ami = params['ami']
  group_name = params['group_name']
  instance_name = params['instance_name']
  count = params['count']
  bootstrap(flavor_id, key_name, secgroup, ami, group_name, instance_name, count)
end

post '/destroy_cluster' do
  content_type :json, :charset => 'utf-8'
  params = JSON.parse(request.env["rack.input"].read)
  group_name  = params['group_name']
  result = destroy_cluster(group_name)
  result.to_json(:root => false)
end

def bootstrap(flavor_id, key_name, secgroup, ami, group_name, instance_name, count)
  instance_num = 0 #-> number of instance counter
  date = Time.now.strftime("%Y-%m-%d-%H:%M:%S")
  while instance_num < count.to_i do
    instance_id = aws_create_instance(flavor_id, ami, key_name, secgroup, instance_name+instance_num.to_s)
    ssh_check_loop(instance_id, 'ubuntu')
    chef_create_environment(group_name)
    check_databags = chef_check_databags(group_name)
    if check_databags == false then
      chef_input_dummy_databags(group_name)
    end
    # Thread.new do
      if instance_num == 0 then
        chef_bootstrap_node(instance_id, group_name, 'cpi-master')
      else 
        chef_bootstrap_node(instance_id, group_name, 'cpi-slave')
      end
    # end
    private_dns_name = aws_search_private_dns_name(instance_id)
    public_dns_name = aws_search_public_dns_name(instance_id)
    az = aws_search_az(instance_id)
    insert_table_cluster_members(instance_id, instance_name+instance_num.to_s,
      private_dns_name, public_dns_name, az, secgroup, ami, flavor_id,
      group_name, '', 'up', date, date)
    instance_num += 1
  end
  elb_dns_name = aws_create_elb(group_name)
  config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
  insert_table_counter(group_name, elb_dns_name, count,
    config['awscale_instance_basic_count'], config['awscale_instance_max_count'], date, date)
  insert_table_health(group_name, elb_dns_name, 10, 3, 7, 0, 0, date, date)
  instances = mysql_search_cluster_members(group_name, 'instance_id')
  instances.each do |server|
    aws_register_elb(group_name, server)
    update_elb_name_cluster_members(server, group_name)
  end
  return instances
end

def destroy_cluster(group_name)
  instances = mysql_search_cluster_members(group_name, 'instance_id')
  instances.each do |instance_id|
    chef_delete_node(instance_id)
    aws_destroy_instance(instance_id)
    delete_table_cluster_members(instance_id)
  end
  chef_delete_environment(group_name)
  aws_delete_elb(group_name)
  delete_table_counter(group_name)
  delete_table_health(group_name)
  return instances
end
