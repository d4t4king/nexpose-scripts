#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'netaddr'
require 'resolv'
require 'nexpose'

require_relative 'scanlog'
require_relative 'Utils'

sl = ScanLog::Log.new(ARGV[0])
dns = Resolv::DNS.new
ex_cidrs = Utils.cidrize(sl.exclusions)

total_count = 0
unr_count = 0
ex_count = 0

sl.targets.each do |tar|
	tar.strip!
	total_count += 1
	addr = ''
	begin
		tar = "#{tar}***REMOVED***" unless tar =~ /.*\.sempra\.com/
		addr = dns.getaddress(tar)
	rescue Resolv::ResolvError => rre
		addr = "unresolved"
		unr_count += 1
	end
	#puts "#{tar}: #{addr}"
	# skip unresolved addresses
	next if addr.to_s == "unresolved"
	ex_cidrs.each do |k,c|
		if k == addr.to_s or c.contains?(addr.to_s)
			ex_count += 1
			# only need to count once, even if there are multiple matches
			break
		end
	end
end

puts "===================================================================="
puts "#{total_count} total targets"
puts "#{unr_count} unresolved targets"
pct = unr_count.to_f / total_count.to_f * 100.0
printf "%3.2f%% unresolved.\n", pct
puts "#{ex_count} excluded targets"
xpct = ex_count.to_f / total_count.to_f * 100.0
printf "%3.2f%% excluded.\n", xpct

