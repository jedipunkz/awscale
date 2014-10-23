#!/usr/bin/env ruby

require 'httpclient'

def http_check_status(url)
  begin
    client = HTTPClient.new
    client.receive_timeout = 1000
    status = client.get(url).status
    if status == 200 then
      return true
    else
      return false
    end
  rescue HTTPClient::KeepAliveDisconnected
    @error = "KeepAliveDisconnected"
  rescue SocketError
    @error = "SocketError"
  end
end
check = http_check_status('http://foo-group-5567495.ap-northeast-1.elb.amazonaws.com')
p check

