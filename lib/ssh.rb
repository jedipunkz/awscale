#!/usr/bin/env ruby

require 'fog'
require 'net/ssh'
require 'yaml'

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

def ssh_check_conn(instance_id, user_name)
  AWSCompute.connect() do |sock|
    server = sock.servers.get(instance_id)
    begin
      config = YAML.load_file("/Users/thirai/aws/awscale.yaml")
      opt = {
        :keys => config['aws_ssh_secret_key'],
        :passphrase => '',
        :port => 22,
        :timeout => 10
      }
      Net::SSH.start("#{server.dns_name}", "#{user_name}", opt) do |ssh|
        return 'ok'
      end
    rescue Timeout::Error
      @error = "Time out"
    rescue Errno::EHOSTUNREACH
      @error = "Host unreachable"
    rescue Errno::ECONNREFUSED
      @error = "Connection refused"
    rescue Net::SSH::AuthenticationFailed
      @error = "Authentication failure"
    rescue Net::SSH::HostKeyMismatch => e
      puts "remembering new key: #{e.fingerprint}"
      e.remember_host!
      retry
    end
  end
end
# check = ssh_check_conn('i-6504f97c', 'ubuntu')
# p check

def ssh_check_loop(instance_id, user_name)
  loop do
    result_ssh = ssh_check_conn(instance_id, 'ubuntu')
    if result_ssh != 'ok' then
      puts "Waiting SSH Session from Instance : #{instance_id}, SSH User : #{user_name} ......."
      sleep (5)
      redo
    else
      puts 'I Found SSH Session. Now Bootstrap the Node via Chef.....'
      sleep (8)
      break
    end
  end
end
#ssh_check_loop('i-c2c789c4', 'ubuntu')
