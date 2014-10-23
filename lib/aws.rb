#!/usr/bin/env ruby

require 'fog'
require 'yaml'

# create connection to aws compute api
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

module AWSELB
  def self.connect()
    config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
    conn = Fog::AWS::ELB.new(
      :aws_access_key_id => config['aws_access_key_id'],
      :aws_secret_access_key => config['aws_secret_access_key'],
      :region => config['region']
    )
    begin
      yield conn
    ensure
      # conn.close
    end
  rescue Errno::ECONNREFUSED
  end
end

def aws_create_instance(flavor_id, image_id, key_name, secgroup, instance_name)
  AWSCompute.connect() do |sock|
    server = sock.servers.create(
      :image_id => image_id,
      :flavor_id => flavor_id,
      :key_name => key_name,
      :tags => {'Name' => instance_name},
      :groups => secgroup
    )
    server.wait_for { ready? }
    return server.id
  end
end
# aws_create_instance('t1.micro', 'ami-bddaa2bc', 'test02', 'ssh', 'fog01')

def aws_destroy_instance(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    server.destroy
    return server.id
  end
end
# aws_destroy_instance('i-8c0cf195')

def aws_start_instance(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    server.start
    return server.id
  end
end
# result = aws_start_instance('i-61ceb067')
# p result

def aws_stop_instance(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    server.stop
    return server.id
  end
end
# result = aws_stop_instance('i-61ceb067')
# p result

def aws_search_private_ip(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    return server.private_ip_address
  end
end
# instance = aws_search_private_ip('i-cb7803cd')
# p instance

def aws_search_private_dns_name(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    return server.private_dns_name
  end
end
# dns = aws_search_private_dns_name('i-cb7803cd')
# p dns

def aws_search_public_ip(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    return server.public_ip_address
  end
end
# instance =  aws_search_public_ip('i-cb7803cd')
# p instance

def aws_search_public_dns_name(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    return server.dns_name
  end
end
# dns = aws_search_public_dns_name('i-cb7803cd')
# p dns

def aws_search_az(instance_id)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    return server.availability_zone
  end
end
# az = aws_search_az('i-cb7803cd')
# p az

def aws_check_flavor(flavor_id)
  AWSCompute.connect() do |sock|
    flavor = sock.flavors.get(flavor_id)
    if flavor then
      return 'ok'
    else
      return 'ng'
    end
  end
end
# check = aws_check_flavor('t1.micro')
# p check

def aws_check_image(image_id)
  AWSCompute.connect() do |sock|
    image = sock.images.get(image_id)
    if image then
      return 'ok'
    else
      return 'ng'
    end
  end
end
# check = aws_check_image('ami-bddaa2bc')
# p check

def aws_create_elb(elbname)
  config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
  AWSELB.connect() do |sock|
    listeners = [{ "Protocol" => "HTTP", "LoadBalancerPort" => 80, "InstancePort" => 80, "InstanceProtocol" => "HTTP" }]
    elb = sock.create_load_balancer(config['az'], elbname, listeners)
    return elb.data[:body]["CreateLoadBalancerResult"]["DNSName"]
  end
end
#test = aws_create_elb("rubytest")
#p test

def aws_delete_elb(elbname)
  AWSELB.connect() do |sock|
    sock.delete_load_balancer(elbname)
  end
end
# aws_delete_elb('mynewlb02')

def aws_register_elb(elbname, instance_id)
  AWSELB.connect() do |sock|
    elbregister = sock.register_instances_with_load_balancer(instance_id, elbname)
    p elbregister
  end
end
# aws_register_elb('foglb01', 'i-61ceb067')
# aws_register_elb('foglb01', 'i-cb7803cd')

def aws_deregister_elb(elbname, instance_id)
  AWSELB.connect() do |sock|
    elbderegister = sock.deregister_instances_from_load_balancer(instance_id, elbname)
    p elbderegister
  end
end
# aws_deregister_elb('foglb01', 'i-61ceb067')
# aws_deregister_elb('foglb01', 'i-cb7803cd')
