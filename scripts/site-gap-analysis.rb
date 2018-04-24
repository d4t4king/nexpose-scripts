#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'ipaddr'

require_relative '../lib/utils'

include Nexpose

default_host = 'localhost'
default_user = 'user'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
  
nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  
  
# loop through every site
puts "Looping through the sites on the console specified...."
nsc.sites.each do |ss|  
	site = Site.load(nsc, ss.id)
	if site.included_addresses.size > 1
		types = Hash.new
		# count the address types
		puts "Counting address object types in site (#{site.name})...."
		site.included_addresses.each do |ip|
			if types.key?(ip.class)
				types[ip.class] += 1
			else
				types[ip.class] = 1
			end
		end
		# Skip sites with host names, since they are unlikely to be contiguous anyway
		if types.key?(Nexpose::HostName)
			puts "Skipping site with hostnames (#{site.name})...."
			next
		end
		er_ary = Array.new
		if site.name =~ /^.*\s+-\s+Vulnerability\s+Scan\s+-\s+(.*)$/
			er_str = $1
			er_str.strip!
			# Skip sites without the target network in the name (for now)
			next unless er_str =~ /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:\/\d{1,2})?$/
			if !er_str.nil?
				er_ary = NetAddr::CIDR.create(er_str).enumerate
			else
				raise "Didn't get expected range string".red.bold
			end
		else
			next
		end
		puts "#{site.name}: ".cyan.bold
		print "#{er_ary.size}".green.bold
		puts " IP addresses in network definition."
		gap_ary = er_ary
		got_ary = Array.new
		# if we got here, then it's likely a scheduled vulnerability scan
		site.included_addresses.each do |ipr|
			if ipr.from and ipr.to
				i = IPAddr.new(ipr.from.to_s)
				until i.to_s == ipr.to.to_s
					got_ary.push(i.to_s)
					gap_ary.delete(i.to_s)
					i = i.succ
				end
			elsif ipr.from and ipr.to.nil?
				# is a single IP
				got_ary.push(ipr.from)
				gap_ary.delete(ipr.from)
			else
				raise "Got unexpected object #{ipr.class}\n#{ipr.inspect}".red.bold
			end
		end
		print "#{got_ary.size}".green.bold
		puts " IP addresses in explicit target definition."
		#gap_ary = er_ary - got_ary
		print "#{gap_ary.size}".green.bold
		puts " IP addresses in omitted gaps."
		octs = Array.new
		gap_ary.each do |g|
			part = g.split(".").slice(0..2).join('.')
			octs.push(part) unless octs.include?(part)
		end
		pp gap_ary
		#break
	end
end
