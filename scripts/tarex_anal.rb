#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'netaddr'
require 'resolv'
require 'nexpose'

require_relative 'scanlog'
require_relative 'utils'

def show_wait_spinner(fps=10)
	chars = %w[|/-\\]
	delay = 1.0/fps
	iter = 0
	spinner = Thread.new do
		while iter do	# Keep spinning until told otherwise
			print chars[(iter+=1) % chars.length]
			sleep delay
			print "\b"
		end
	end
	yield.tap{			# After yielding to the block, save the return value
		iter = false	# Tell the thread to exit, cleaning up after itself
		spinner.join	# ...and wait for it to do so.
	}					# Use the block's value as the method's
end

#sl = ''
#show_wait_spinner(30){
	sl = ScanLog::Log.new(ARGV[0])
#}
dns = Resolv::DNS.new
ex_cidrs = Utils.cidrize(sl.exclusions)

total_count = 0
unr_count = 0
ex_count = 0

sl.targets.each do |tar|
	tar.strip!
	total_count += 1
	addr = ''
	if tar =~ /[a-zA-Z0-9-]+/
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
			#puts IPAddr.new(c.network).to_i.to_s.magenta + IPAddr.new(addr.to_s).to_i.to_s.green + IPAddr.new(c.last).to_i.to_s.magenta
			if k == addr.to_s or c.contains?(addr.to_s)
				ex_count += 1
				# only need to count once, even if there are multiple matches
				break
			elsif IPAddr.new(c.network).to_i < IPAddr.new(addr.to_s).to_i and IPAddr.new(addr.to_s).to_i < IPAddr.new(c.last).to_i
				ex_count += 1
				break
			end
		end
	else
		raise "target not a name: #{tar}"
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

