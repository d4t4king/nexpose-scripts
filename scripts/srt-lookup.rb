#!/usr/bin/env ruby

require 'pp'
require 'getoptlong'
require 'colorize'
require 'nexpose'
require 'highline/import'
require 'ipaddr'

require_relative '../lib/utils'
require_relative '../lib/scanlog'

default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'user'
default_ip = '10.0.0.1'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
check_ip = ask("Enter the IP address to check: ") { |q| q.default = default_ip }

check_iprobj = Nexpose::IPRange.new("#{check_ip}/32")

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

# check for specified IP in Global Exclusions
#gsettings = Nexpose::GlobalSettings.load(@nsc)
gexcl = Nexpose::GlobalSettings.load(@nsc).asset_exclusions
#pp gexcl
is_global_exclusion = false
gexcl.each do |ipr|
	ck_ipaddr = IPAddr.new(check_iprobj.to_s)
	if ipr.to.nil?						# just a single IP
		if IPAddr.new(ipr.from) == ck_ipaddr
			puts "#{check_ip} was found in the Global Exclusion list.".green
			is_global_exclusion = true
			break
		end
	else								# Must be an actual range
		bits = Utils.calc_mask(ipr.from,ipr.to)
		cmp_iprobj = IPAddr.new("#{ipr.from}/#{bits}")
		if cmp_iprobj === ck_ipaddr
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
		puts "Site ID: #{as.site_id}".yellow
		puts "Found #{as.status} scan for site: #{site_obj.name}"
		puts "Above scan started at #{as.start_time}"
		puts "Includes the following range(s):"
		addrs = site_obj.included_scan_targets[:addresses]
		# check for specified IP in scan ranges
		if addrs.size == 1
			print "#{addrs[0].from}-#{addrs[0].to} "
			#bits = Utils.calc_mask(addrs[0].from, addrs[0].to)
			#put s"[*] Got bits #{bits} for range #{addrs[0].from}-#{addrs[0].to}".yellow
			#ipaddr = IPAddr.new("#{addrs[0].from}/#{bits}")
			#pp ipaddr
			# if IP/range in scan range, 
			retval = addrs[0] <=> check_iprobj
			#print " retval == #{retval} ".yellow
			if retval == 0
				puts "(#{addrs[0]})".red
				completed = @nsc.completed_assets(as.scan_id)
				#pp completed
				completed.each do |c|
					if c.ip =~ /#{check_ip}/
						puts "IP found in completed assets #{c.ip}.".cyan
						pp c
					end
				end
				incompleted = @nsc.incomplete_assets(as.scan_id)
				incompleted.each do |i|
					if i.ip =~ /#{check_ip}/
						puts "IP found in incomplete assets: #{i.ip}.".yellow
						pp i
					end
				end
				#pp incompleted
			else
				puts "(not found)".green
			end
			#puts addrs[0].inspect.to_s.yellow
			#puts check_iprobj.inspect.to_s.yellow.bold
		else
			puts "There's more than one range....".yellow
			if addrs.size > 1 and addrs.size < 50
				addrs.each do |addr|
					if addr.is_a?(Nexpose::IPRange)
						print "#{addr.from}-#{addr.to} "
						retval = addr <=> check_iprobj
						if retval == 0
							puts "(#{addr})".red
						else
							puts "(not found)".green
						end
					elsif addr.is_a?(Nexpose::HostName)
						puts "#{addr}".cyan
					end
				end
			else
				puts "More than 50 entries.  Too many to list.".yellow
			end
		end
	end
end
