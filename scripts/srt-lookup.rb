#!/usr/bin/env ruby

require 'pp'
require 'getoptlong'
require 'colorize'
require 'nexpose'
require 'highline/import'
require 'ipaddr'

require_relative '../lib/utils'
default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'user'
default_ip = '10.0.0.1'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
check_ip = ask("Enter the IP address to check: ") { |q| q.default = default_ip }

check_iprobj = IPAddr.new(check_ip)

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

# check for specified IP in Global Exclusions
#gsettings = Nexpose::GlobalSettings.load(@nsc)
gexcl = Nexpose::GlobalSettings.load(@nsc).asset_exclusions
#pp gexcl
is_global_exclusion = false
gexcl.each do |ipr|
	if ipr.to.nil?						# just a single IP
		if IPAddr.new(ipr.from) == check_iprobj
			puts "#{check_ip} was found in the Global Exclusion list.".green
			is_global_exclusion = true
			break
		end
	else								# Must be an actual range
		bits = Utils.calc_mask(ipr.from,ipr.to)
		cmp_iprobj = IPAddr.new("#{ipr.from}/#{bits}")
		if cmp_iprobj === check_iprobj
			puts "#{check_ip} found in Global Exclusion list (range: #{ipr.from}-#{ipr.to})".green
			is_global_exclusion = true
			break
		end
	end
end	
unless is_global_exclusion
	puts "#{check_ip} was NOT found in the Global Exclusion list.".red
end

# pull the active scans from the API
activeScans = @nsc.scan_activity()
if activeScans.size == 0
	puts "There are no active scans to check.".green
else
	puts "Found active scans."
	activeScans.each do |as|
		#pp as
		site_obj = Nexpose::Site.load(@nsc, as.site_id)
		#pp site_obj
		puts "Found #{as.status} scan for site: #{site_obj.name}"
		puts "\tAbove scan started at #{as.start_time}"
		puts "\tIncludes the following range(s):"
		addrs = site_obj.included_scan_targets[:addresses]
		# check for specified IP in scan ranges
		if addrs.size == 1
			print "\t\t#{addrs[0].from}-#{addrs[0].to} "
			bits = Utils.calc_mask(addrs[0].from, addrs[0].to)
			ipaddr = IPAddr.new("#{addrs[0].from}/#{bits}")
			# if IP/range in scan range, 
			if ipaddr === check_iprobj
				puts "(#{ipaddr.to_range})".red
				# export the scan log
				print "Pulling scan log...."
				#@nsc.export_scan(as.scan_id, "scanlog-#{as.scan_id}.zip")
				@nsc.download("https://#{@nsc.host}:3780/data/scan/log?scan-id=#{as.scan_id}", "./")
				puts "done."
				# objectify scan logg
				# look for affected IP/range
			else
				puts "(not found)".green
			end
		else
			puts "\tThere's more than one range....".yellow
		end
	end
end
