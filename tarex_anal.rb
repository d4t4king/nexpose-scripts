#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'netaddr'
require 'resolv'

require_relative 'scanlog'

sl = ScanLog::Log.new(ARGV[0])
dns = Resolv::DNS.new(:nameserver => "10.136.20.111", :search => "sempra.com")

total_count = 0
unr_count = 0

sl.targets.each do |tar|
	total_count += 1
	addr = ''
	begin
		if tar =~ /.*\.sempra\.com$/
			addr = dns.getaddress(tar)
		else
			addr = dns.getaddress("#{tar}***REMOVED***")
		end
	rescue Resolv::ResolvError => rre
		addr = "unresolved"
		unr_count += 1
	end
	puts "#{tar}: #{addr}"
end

puts "===================================================================="
puts "#{total_count} total targets"
puts "#{unr_count} unresolved targets"
puts "#{(unr_count / total_count) * 100} %"

