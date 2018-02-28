#!/usr/bin/env ruby

require 'rubygems'
require 'colorize'
require 'nexpose'
require 'netaddr'
require 'pp'

require_relative '../lib/utils'

host = "172.16.100.170"
user = 'sv-nexposegem'
pass = 'Sempra01!'
port = '3780'

@nsc = Nexpose::Connection.new(host, user, pass, port)

at_exit{ @nsc.logout }

begin
	@nsc.login
rescue ::Nexpose::APIError => e
	puts "Connection failed: #{e.message}"
	@nsc.logout
	exit 1
end

ips = Hash.new
excl = Hash.new

# loop thru all the sites on the console
@nsc.sites.each do |ssum|
	# skip the site if it doesn't have "internal" in the name
	if ssum.name !~ /Internal - /
		next
	end
	# load the site details
	s = Nexpose::Site.load(@nsc, ssum.id)
	s.included_addresses.each do |ia|
		if ia.is_a?(Nexpose::IPRange)
			if ia.to.nil?
				range = ia.from.to_s
			else
				range = ia.from.to_s + "-" + ia.to.to_s
			end
			if ips[ia.from.to_s].nil?
				ips[ia.from.to_s] = [{range => ssum.id}]
			else
				ips[ia.from.to_s].push( {range => ssum.id} ) unless ips.keys.include?(ia.from.to_s)
			end
		end
	end
	#if s.excluded_addresses.size > 0
	#	s.excluded_addresses.each do |ex|
	#		if ex.is_a?(Nexpose::IPRange)
	#			if ex.to.nil?
	#				range = ex.from.to_s
	#			else
	#				range = ex.from.to_s + "-" + ex.to.to_s
	#			end
	#			if ips[ex.from.to_s].nil?
	#				ips[ex.from.to_s] = [{range => ssum.id}]
	#			else
	#				ips[ex.from.to_s].push( {range => ssum.id} ) unless ips.keys.include?(ex.from.to_s)
	#			end
	#		end
	#	end
	#end
end

ipaddrs = Array.new
ips.keys.sort.each do |start_ip|
	ips[start_ip].each do |r2s_map|
		r2s_map.keys.each do |r|
			(lower,upper) = r.to_s.split('-')
			if upper.nil?
				upper = lower
			end
			#print lower.to_s.green
			#puts upper.to_s.red
			bits = Utils.calc_mask(lower, upper)
			#puts "L: #{lower.to_s} U: #{upper.to_s} B: #{bits.to_s}"
			nacidr = NetAddr::CIDR.create("#{lower.to_s}/#{bits}")
			#puts nacidr.to_s.yellow.bold
			ipaddrs.push(nacidr)
		end
	end
end

coverage = Array.new
ipaddrs.each do |net|
	next if net.bits == 32
	ipaddrs.each do |net2|
		#print "Is #{net2.to_s} contained in #{net.to_s}?  "
		if net.contains?(net2)
			#puts "Found a container: #{net.to_s} <== #{nacidr.to_s}".green
			#puts "Yes".green
			coverage.push(net) unless coverage.include?(net)
		else
			#puts "No".red
			if net.is_contained?(net2)
				coverage.push(net2) unless coverage.include?(net2)
			end	
		end
	end
end

ipmerge = NetAddr.merge(ipaddrs)
puts "#{ipmerge.size.to_s} after merge 1."
merge2 = NetAddr.merge(ipmerge)
puts "#{merge2.size.to_s} after merge 2."
merge3 = NetAddr.merge(merge2)
puts "#{merge3.size.to_s} after merge 3."
merge4 = NetAddr.merge(merge3)
puts "#{merge4.size.to_s} after merge 4."
merge4.each do |n|
	puts n.to_s + " ( " + NetAddr::CIDR.create(n).first.to_s + " - " + NetAddr::CIDR.create(n).last.to_s + " ) "
end
