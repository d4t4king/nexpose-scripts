#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'
require 'resolv'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password: ') { |q| q.echo = '*' }

nsc = Nexpose::Connection.new(host, user, pass)
nsc.login
at_exit { nsc.logout }

if ARGV[0].nil?
	puts "Usage: $0 <site name>"
	raise "Specify a site name".red.bold
else 
	@site2a = ARGV[0]
end

# build site name to id hash (?)
s2id = Utils.sites2ids(nsc)
# get the list of global exclusions
globex = Nexpose::GlobalSettings.load(nsc).asset_exclusions

puts "Found ID: #{s2id[@site2a]}"

site = Nexpose::Site.load(nsc, s2id[@site2a])

total_addrs = 0
ex_addrs = 0
unres_addrs = 0
site.included_addresses.each do |iaddr|
	total_addrs += 1
	ip = ''
	if iaddr.is_a?(Nexpose::HostName)
		dns = Resolv::DNS.new
		begin
			if iaddr.host =~ /.*\.sempra\.com/
				ip = dns.getaddress(iaddr.to_s)
			else
				ip = dns.getaddress("#{iaddr.host}***REMOVED***")
			end
		rescue Resolv::ResolvError => rre
			ip = "unresolved"
			unres_addrs += 1
			next
		end
	elsif iaddr.is_a?(Nexpose::IPRange)
		# handle the range
		puts "Found a range: #{iaddr.to_s}".yellow
	end
	globex.each do |gex|
		if gex.to.nil? == false
			if gex.from < IPAddr.new(ip.to_s) and IPAddr.new(ip.to_s) < gex.to
				puts "Excluded: #{ip.to_s}".red.bold
				ex_addrs += 1
			end
		else 
			if gex.from == ip
				puts "Excluded: #{ip.to_s}".red.bold
				ex_addrs += 1
			end
		end
	end
end

puts "Total: #{total_addrs}"
puts "Excluded: #{ex_addrs}"
puts "Unresolved: #{unres_addrs}"
