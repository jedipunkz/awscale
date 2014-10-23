#!/usr/bin/env ruby

# require 'active_record'
# require 'mysql2'
require './lib/http.rb'
require './lib/mysql.rb'
require './lib/aws.rb'
require './lib/chef.rb'
require './lib/ssh.rb'
require 'daemon_spawn'
require 'yaml'
require 'json'

config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
$flavor_id = config['aws_instance_type']
$key_name = config['aws_ssh_secret_key_name']
$secgroup = config['aws_security_group']
$ami = config['aws_ami']

def bootstrap(flavor_id, key_name, secgroup, ami, group_name, instance_name)
  date = Time.now.strftime("%Y-%m-%d-%H:%M:%S")
  count = mysql_search_count_info(group_name, 'count')
  instance_id = aws_create_instance(flavor_id, ami, key_name, secgroup, instance_name+count.to_s)
  puts instance_id
  ssh_check_loop(instance_id, 'ubuntu')
  Thread.new do
    chef_bootstrap_node(instance_id, group_name, 'cpi-slave')
  end
  private_dns_name = aws_search_private_dns_name(instance_id)
  public_dns_name = aws_search_public_dns_name(instance_id)
  az = aws_search_az(instance_id)
  insert_table_cluster_members(instance_id, instance_name+count.to_s,
    private_dns_name, public_dns_name, az, secgroup, ami, flavor_id,
    group_name, '', 'up', date, date)
  update_inc_counter(group_name, date)
  aws_register_elb(group_name, instance_id)
  update_elb_name_cluster_members(instance_id, group_name)
  return instance_id
end

def destroy_node(group_name)
  count = mysql_search_count_info(group_name, 'count')
  count -= 1
  instance_id = mysql_search_instance_id(group_name+count.to_s)
  p group_name+count.to_s
  p instance_id
  date = Time.now.strftime("%Y-%m-%d-%H:%M:%S")
  chef_delete_node(instance_id)
  aws_destroy_instance(instance_id)
  aws_deregister_elb(group_name, instance_id)
  delete_table_cluster_members(instance_id)
  update_dec_counter(group_name, date)
  return instance_id
end

class AwscaleDaemon < DaemonSpawn::Base
  def start(args)
    puts "start: #{Time.now}"
    loop do
      puts "loop starting: #{Time.now}"
      date = Time.now.strftime("%Y-%m-%d-%H:%M:%S")
      all_groups = mysql_search_count_all()
      all_groups.each do |group_name, v|
        puts "group_name: #{group_name} --------"
        elb_dns_name = mysql_search_count_info(group_name, 'elb_dns_name')
        status = http_check_status('http://' + elb_dns_name)
        puts "elb_dns_name: #{elb_dns_name}"
        puts "status: #{status}"
        if status == true then
          update_inc_health(group_name, date)
        elsif status == false then
          update_dec_health(group_name, date)
        else
          puts 'http_check_status method does not return value.'
        end
        time_count = mysql_search_health_info(group_name, 'time_count')
        puts "---- #{time_count}"
        if time_count > 9 then
          health_count = mysql_search_health_info(group_name, 'healthy_count')
          count = mysql_search_health_info(group_name, 'count')
          if health_count >= count then
            max_instance_count = mysql_search_count_info(group_name, 'max_count')
            instance_count = mysql_search_count_info(group_name, 'count')
            if instance_count >= max_instance_count then
              puts 'adding ... but number of your instances already max count.'
            else
              puts 'adding ...'
              $instance_name = mysql_search_count_info(group_name, 'group_name')
              bootstrap($flavor_id, $key_name, $secgroup, $ami, group_name, $instance_name)
            end
          else
            basic_instance_count = mysql_search_count_info(group_name, 'basic_count')
            instance_count = mysql_search_count_info(group_name, 'count')
            puts "basic_instance_count: #{basic_instance_count}"
            puts "instance_count: #{instance_count}"
            if basic_instance_count >= instance_count then
              puts 'deleting ... but number of your instances already basic count.'
            else
              puts 'deleting ...'
              destroy_node(group_name)
            end
          end
          update_count_health(group_name, 0)
          update_clear_health_time_count(group_name, date)
        end # <= loop_counter >9
        update_inc_health_time_count(group_name, date)
      end # <= all_groups.each
      sleep(5)
    end
  end

  def stop
    puts "stop : #{Time.now}"
  end
end

AwscaleDaemon.spawn!({
    :working_dir => "/tmp",
    :pid_file => "/tmp/awscale.pid",
    :log_file => "/tmp/awscale.log",
    :sync_log => true,
  })

