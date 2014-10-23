#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'active_record'

config = YAML.load_file("/Users/thirai/aws/awscale.yaml")

ActiveRecord::Base.establish_connection(
  adapter:  "mysql2",
  host:     config['mysql_host'],
  username: config['mysql_user'],
  password: config['mysql_pass'],
  database: config['mysql_database']
)

class Cluster_Members < ActiveRecord::Base
  self.table_name = 'cluster_members'
end

class Counter < ActiveRecord::Base
  self.table_name = 'counter'
end

class Health < ActiveRecord::Base
  self.table_name = 'health'
end

def insert_table_cluster_members(instance_id, name, private_dns_name,
  public_dns_name, az, security_group, ami, instance_type, group_name, elb_name,
  status, created_date, updated_date)
  member = Cluster_Members.new
  member.instance_id = instance_id
  member.name = name
  member.private_dns_name = private_dns_name
  member.public_dns_name = public_dns_name
  member.az = az
  member.security_group = security_group
  member.ami = ami
  member.instance_type = instance_type
  member.group_name = group_name
  member.elb_name = elb_name
  member.status = status
  member.created_date = created_date
  member.updated_date = updated_date
  member.save
end
# insert_table_cluster_members('i-6504f97a', 'bar', '1.1.1.1', '2.2.2.2', 'ap-northeast-1c', 'ssh', 'ami-bddaa2bc', 't1.micro', 'foogroup', '', '2014-05-27 12:30', '2014-05-27 12:31')
# insert_table_cluster_members('i-6504f97a', 'bar', '1.1.1.1', '2.2.2.2', 'ap-northeast-1c', 'ssh', 'ami-bddaa2bc', 't1.micro', 'foogroup', '', 'up', '2014-05-27 12:30', '2014-05-27 12:31')

def delete_table_cluster_members(instance_id)
  Cluster_Members.destroy_all(:instance_id => instance_id)
end
# delete_table_cluster_members('i-6504f97a')

def update_elb_name_cluster_members(instance_id, elb_name)
  cluster_members = Cluster_Members.where(:instance_id => instance_id).first
  cluster_members.elb_name = elb_name
  cluster_members.save
end
# update_elb_name_cluster_members('i-6504f97a', 'buzzbuzz-group-1627080907.ap-northeast-1.elb.amazonaws.com')

def update_status_cluster_members(instance_id, status)
  cluster_members = Cluster_Members.where(:instance_id => instance_id).first
  cluster_members.status = status
  cluster_members.save
end
# update_status_cluster_members('i-6504f97a', 'up')

def insert_table_counter(group_name, elb_dns_name, count, basic_count, max_count, created_date, updated_date)
  counter = Counter.new
  counter.group_name = group_name
  counter.elb_dns_name = elb_dns_name
  counter.count = count
  counter.basic_count = basic_count
  counter.max_count = max_count
  counter.created_date = created_date
  counter.updated_date = updated_date
  counter.save
end
# insert_table_counter('foogroup', 3, 3, '2014-05-27', '2014-05-27')

def delete_table_counter(group_name)
  Counter.destroy_all(:group_name => group_name)
end
# delete_table_counter('foogroup')

def update_elb_dns_name_counter(group_name, elb_dns_name)
  counter = Counter.where(group_name: group_name).first
  counter.elb_dns_name = elb_dns_name
  counter.save
end

def update_inc_counter(group_name, date)
  counter = Counter.where(group_name: group_name).first
  counter.increment!(:count)
  counter.updated_date = date
  counter.save
end
# update_inc_counter('foogroup', '2014-05-05')

def update_dec_counter(group_name, date)
  counter = Counter.where(group_name: group_name).first
  counter.decrement!(:count)
  counter.updated_date = date
  counter.save
end
# update_dec_counter('foogroup', '2014-05-28')

def insert_table_health(group_name, elb_dns_name, healthy_threshold, unhealthy_threshold,
  healthy_count, count, time_count, created_date, updated_date)
  health = Health.new
  health.group_name = group_name
  health.elb_dns_name = elb_dns_name
  health.healthy_threshold = healthy_threshold
  health.unhealthy_threshold = unhealthy_threshold
  health.healthy_count = healthy_count
  health.count = count
  health.time_count = time_count
  health.created_date = created_date
  health.updated_date = updated_date
  health.save
end
# insert_table_health('foo-group', 'foo-group-elb', 10, 3, 7, 0, 0, '2014-06-02', '2014-06-02')

def delete_table_health(group_name)
  Health.destroy_all(:group_name => group_name)
end
# delete_table_health('foo-group')

def update_elb_dns_name_health(group_name, elb_dns_name)
  health = Health.where(group_name: group_name).first
  health.elb_dns_name = elb_dns_name
  health.save
end
# update_elb_dns_name_health('foo-group', 'foo-group-elb2')

def update_count_health(group_name, count)
  health = Health.where(group_name: group_name).first
  health.count = count
  health.save
end
# update_count_health('foo-group', 0)

def update_inc_health(group_name, date)
  health = Health.where(group_name: group_name).first
  health.increment!(:count)
  health.updated_date = date
  health.save
end
# update_inc_health('foo-group', '2014-05-05')

def update_dec_health(group_name, date)
  health = Health.where(group_name: group_name).first
  health.decrement!(:count)
  health.updated_date = date
  health.save
end
# update_dec_health('foo-group', '2014-05-28')

def update_inc_health_time_count(group_name, date)
  health = Health.where(group_name: group_name).first
  health.increment!(:time_count)
  health.updated_date = date
  health.save
end
# update_inc_health_time_count('foo-group', '2014-06-05')

def update_clear_health_time_count(group_name, date)
  health = Health.where(group_name: group_name).first
  health.time_count = 0
  health.updated_date = date
  health.save
end
# update_clear_health_time_count('foo-group', '2014-06-05')

def mysql_search_instances()
  instances = []
  records = Cluster_Members.order("group_name DESC")
  records.each do |value|
    instances << [value.name , value]
  end
  return instances
end
# search = mysql_search_instances()
# p search

def mysql_search_cluster_members(group_name, key)
  instances = []
  records = Cluster_Members.where(group_name: group_name)
  if key == "instance_id" then
    records.each do |value|
      instance_id = value.instance_id
      instances << instance_id
    end
  elsif key == "all" then
    records.each do |value|
      instances << [value.name, value]
    end
  else
    puts "'key' must be 'all' or 'instance_id'."
  end
  return instances
end
# search = mysql_search_cluster_members('foo-group', 'all')
# p search

# def mysql_search_instance_all(instance_id)
#   records = Cluster_Members.where(instance_id: instance_id)
#   records.each do |value|
#     return value
#   end
# end
# search = mysql_search_instance_all('i-47976b5e')
# p search

def mysql_search_instance_id(instance_name)
  records = Cluster_Members.where(name: instance_name)
  records.each do |value|
    return value.instance_id
  end
end
# search = mysql_search_instance_id('foo1')
# p search


def mysql_search_instance_info(instance_id, search_key)
  records = Cluster_Members.where(instance_id: instance_id)
  records.each do |value|
    if search_key == "name" then
      return value.name
    elsif search_key == "private_dns_name" then
      return value.private_dns_name
    elsif search_key == "public_dns_name" then
      return value.public_dns_name
    elsif search_key == "az" then
      return value.az
    elsif search_key == "security_group" then
      return value.security_group
    elsif search_key == "ami" then
      return value.ami
    elsif search_key == "instance_type" then
      return value.instance_type
    elsif search_key == "group_name" then
      return value.group_name
    elsif search_key == "elb_name" then
      return value.elb_name
    elsif search_key == "status" then
      return value.status
    elsif search_key == "created_date" then
      return value.created_date
    elsif search_key == "updated_date" then
      return value.updated_date
    else
      puts 'Invalid search_key'
    end
  end
end
# search = mysql_search_instance_info('i-55b5f853', 'name')
# p search

def mysql_search_group_all()
  groups = []
  records = Cluster_Members.all
  records.each do |value|
    group_name = value.group_name
    groups << group_name
  end
  return groups
end
# search = mysql_search_instance_info('i-55b5f853', 'name')
# p search

def mysql_search_group_all()
  groups = []
  records = Cluster_Members.all
  records.each do |value|
    group_name = value.group_name
    groups << group_name
  end
  return groups
end
# search = mysql_search_group_all()
# p search

def mysql_search_count_all()
  count = []
  records = Counter.order("created_date DESC")
  records.each do |value|
    count << [value.group_name, value]
  end
  return count
end
# search = mysql_search_count_all()
# p search

def mysql_search_count_info(group_name, search_key)
  records = Counter.where(group_name: group_name)
  records.each do |value|
    if search_key == 'group_name' then
      return value.group_name
    elsif search_key == 'elb_dns_name' then
      return value.elb_dns_name
    elsif search_key == 'count' then
      return value.count
    elsif search_key == 'basic_count' then
      return value.basic_count
    elsif search_key == 'max_count' then
      return value.max_count
    elsif search_key == 'created_date' then
      return value.created_date
    elsif search_key == 'updated_date' then
      return value.updated_date
    end
  end
end
# search = mysql_search_count_info('foo-group', 'group_name')
# p search

def mysql_search_health_all()
  health = []
  records = Health.order("created_date DESC")
  records.each do |value|
    health << [value.group_name, value]
  end
  return health
end
# search = mysql_search_health_all()
# p search

def mysql_search_health_info(group_name, search_key)
  records = Health.where(group_name: group_name)
  records.each do |value|
    if search_key == 'group_name' then
      return value.group_name
    elsif search_key == 'elb_dns_name' then
      return value.elb_dns_name
    elsif search_key == 'healthy_threshold' then
      return value.healthy_threshold
    elsif search_key == 'unhealthy_threshold' then
      return value.unhealthy_threshold
    elsif search_key == 'healthy_count' then
      return value.healthy_count
    elsif search_key == 'count' then
      return value.count
    elsif search_key == 'time_count' then
      return value.time_count
    elsif search_key == 'created_date' then
      return value.created_date
    elsif search_key == 'updated_date' then
      return value.updated_date
    end
  end
end
# search = mysql_search_health_info('foo-group', 'unhealthy_threshold')
# p search
