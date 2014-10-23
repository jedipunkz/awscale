#!/usr/bin/env ruby

require 'fog'
require 'chef'
require 'chef/knife/core/bootstrap_context'
require 'chef/knife'
require 'chef/knife/ssh'
require 'chef/knife/bootstrap'
require 'chef/knife/node_delete'
require 'chef/knife/client_delete'
require 'chef/knife/node_list'
require 'chef/knife/node_show'
require 'chef/knife/environment_delete'
require 'chef/knife/environment_list'
require 'net/ssh'
require 'net/ssh/multi'
require 'yaml'
require 'json'

config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
$chef_user = config['chef_user']
$chef_secret_key = config['chef_secret_key']
$chef_validation_key = config['chef_validation_key']
$chef_server_url = config['chef_server_url']
$chef_bootstrap_file = config['chef_bootstrap_file']
$aws_ssh_secret_key = config['aws_ssh_secret_key']
Chef::Config.from_file(File.expand_path('./.chef/knife.rb'))

module AWSCompute
  def self.connect()
    config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
    conn = Fog::Compute.new({
      :provider => 'AWS',
      :aws_access_key_id => config['aws_access_key_id'],
      :aws_secret_access_key => config['aws_secret_access_key'],
      :region => config['region']
    })
    begin
      yield conn
    ensure
      # conn.close
    end
  rescue Errno::ECONNREFUSED
  end
end

def chef_check_environment(environment_name)
  i = 0
  Chef::Environment::list.each do |env, url|
    if env = environment_name then i = 1 end
  end
  if i == 0 then return nil else return environment_name end
end
# env = chef_check_environment('cpi')
# p env

def chef_search_environment(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    p server.private_dns_name
    s = `knife node show #{server.private_dns_name}`.split("\n")
    ss = s[1].split(" ")
    return ss[1]
  end
end
# env = chef_search_environment('i-cb7803cd')
# p env

def chef_create_environment(environment_name)
  Chef::Config[:node_name] = $chef_user
  Chef::Config[:client_key] = $chef_secret_key
  Chef::Config[:chef_server_url] = $chef_server_url

  json_data = {
"name" => "#{environment_name}",
"description" => "Dummy environment for awscale",
"cookbook_versions" => {},
"default_attributes" => {},
"override_attributes" => {
    "apache2"=> {
      "vhosts"=> {
        "name"=> "rails.company.com",
        "aliases"=> [ "content-test.optimispt.com" ],
        "domain"=> "company",
        "environment"=> "production"
      },
      "listen_ports"=> "80"
    },
    "vhosts"=> {
      "data_bag_name"=> "#{environment_name}"
    }
  }
}

  @environment_item = Chef::Environment.json_create(json_data)
  @environment_item.save
end
# chef_create_environment('rubytest01')

def chef_delete_environment(environment_name)
  Chef::Config[:node_name] = $chef_user
  Chef::Config[:client_key] = $chef_secret_key
  Chef::Config[:chef_server_url] = $chef_server_url

  @environment_item = Chef::Knife::EnvironmentDelete.new
  @environment_item.name_args = [ environment_name ]
  @environment_item.config[:yes] = true
  @environment_item.run
end
# chef_delete_environment('rubytest01')

def chef_bootstrap_node(instance_id, environment_name, role_name)
  Chef::Config[:node_name] = $chef_user
  Chef::Config[:client_key] = $chef_secret_key
  Chef::Config[:validation_key] = $chef_validation_key
  Chef::Config[:chef_server_url] = $chef_server_url
  Chef::Config[:environment] = environment_name

  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)

    kb = Chef::Knife::Bootstrap.new
    kb.name_args = [server.dns_name]
    kb.config[:ssh_user] = "ubuntu"
    kb.config[:chef_node_name] = server.dns_name
    kb.config[:identity_file] = $aws_ssh_secret_key
    kb.config[:ssh_port] = "22"
    kb.config[:run_list] = "role[#{role_name}]"
    kb.config[:template_file] = $chef_bootstrap_file
    kb.config[:use_sudo] = true
    kb.run
  end
end
# chef_bootstrap_node('i-6504f97c', 'rubytest01', 'cpi')
# chef_bootstrap_node('i-58da935e', 'barbar', 'cpi')

def chef_delete_node(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)

    nd = Chef::Knife::NodeDelete.new
    nd.name_args = [server.dns_name]
    nd.config[:yes] = true
    begin
      nd.run
    rescue Net::HTTPServerException
      p 'not found.'
    end

    cd = Chef::Knife::ClientDelete.new
    cd.name_args = [server.dns_name]
    cd.config[:yes] = true
    begin
      cd.run
    rescue Net::HTTPServerException
      p 'not found.'
    end
  end
end
# chef_delete_node('i-c8a1e3ce')
# chef_delete_node('i-6504f97c')

def chef_input_databags(raw_data)
  hashed_raw_data = JSON.parse(raw_data)

  puts hashed_raw_data

  data_bag_list = Chef::DataBag.list
  if data_bag_list.include?("vhosts") then
    vhosts = Chef::DataBag.new
    vhosts.name("vhosts")
    vhosts.destroy
  end

  vhosts = Chef::DataBag.new
  vhosts.name("vhosts")
  vhosts.create
  databag_item = Chef::DataBagItem.new
  databag_item.data_bag("vhosts")
  databag_item.raw_data = hashed_raw_data
  databag_item.save
  
  data_bag_list = Chef::DataBag.list
end

def chef_input_dummy_databags(group_name)
  hashed_raw_data = {"id"=>"#{group_name}", "vhosts"=>{"test01"=>{"apache2"=>{"name"=>"test01.cpi.ad.jp", "aliases"=>["test01.jam.cpi.ad.jp"], "domain"=>"cpi.ad.jp", "environment"=>"production"}, "db"=>{"dbname"=>"wp-test01", "dbuser"=>"test01", "dbpass"=>"test01"}, "wordpress"=>{"wp_trig"=>false}}}}

  # puts hashed_raw_data

  data_bag_list = Chef::DataBag.list
  if data_bag_list.include?("vhosts") then
    vhosts = Chef::DataBag.new
    vhosts.name("vhosts")
    vhosts.destroy
  end

  vhosts = Chef::DataBag.new
  vhosts.name("vhosts")
  vhosts.create
  databag_item = Chef::DataBagItem.new
  databag_item.data_bag("vhosts")
  databag_item.raw_data = hashed_raw_data
  databag_item.save
  
  data_bag_list = Chef::DataBag.list
end

def chef_check_databags(environment)
  begin
    data_bag_list = Chef::DataBagItem.load('vhosts', environment)
    if ! data_bag_list.empty? then
      return true
    else
      return false
    end
  rescue Net::HTTPServerException
    @error = "HTTPServerException"
    return false
  end
end
# check = chef_check_databags('foofoo')
# p check
