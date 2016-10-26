#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'ipaddr'

require_relative 'Utils.rb'

include Nexpose

default_host = 'localhost'
default_user = 'user'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
  
nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  
  
nsc.sites.each do |ss|  
	site = Site.load(nsc, ss.id)
	if site.included_addresses.size > 1
		types = Hash.new
		site.included_addresses.each do |ip|
			if types.key?(ip.class)
				types[ip.class] += 1
			else
				types[ip.class] = 1
			end
		end
		# Skip sites with host names, since they are unlikely to be contiguous anyway
		next if types.key?(Nexpose::HostName)
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
		puts "#{site.name}".cyan.bold
		print "#{er_ary.size}".green
		puts " elements in expected range"
		got_ary = Array.new
		site.included_addresses.each do |ipr|
			if ipr.from and ipr.to
				diff = IPAddr.new(ipr.to).to_i - IPAddr.new(ipr.from).to_i
				#oct_ary = ipr.from.to_s.split(".").slice(0..2)
				#oct_str = oct_ary.join(".")
				oct_str = ipr.from.to_s.split(".").slice(0..2).join(".")
				#puts oct_str
				if diff < 255
					diff.times do |n|
						got_ary.push("#{oct_str}.#{n}")
						n += 1
					end
				else 
					$stderr.puts "Diff is greater than or equal to 255. Jumping to CIDR enumeration. (#{ipr.from}-#{ipr.to} [#{diff}])".red.bold
					bits = Utils.calc_mask(ipr.from,ipr.to)
					nac = NetAddr::CIDR.create("#{ipr.from}/#{bits}")
					#puts "A: #{ipr.from} - #{ipr.to} (#{IPAddr.new(ipr.to).to_i - IPAddr.new(ipr.from).to_i})"
					#puts "B: #{nac.first} - #{nac.last} (#{bits})"
					got_ary += nac.enumerate
					#raise "Diff is greater than or equal to 255! (#{diff})\n#{ipr.from}-#{ipr.to}".red.bold
				end
			elsif ipr.from and ipr.to.nil?
				got_ary.push(ipr.from)
			end
		end
		#pp got_ary
		print "#{got_ary.size}".green
		puts " elements in got range(s)"
		gap_ary = Array.new
		er_ary.each do |ip|
			gap_ary.push(ip) if !got_ary.include?(ip)
		end
		print "#{gap_ary.size}".green 
		puts " elements in gaps"
		break
	end
end

