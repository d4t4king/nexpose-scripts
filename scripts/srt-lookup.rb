#!/usr/bin/env ruby

require 'pp'
require 'getoptlong'
require 'colorize'
require 'nexpose'
require 'highline/import'
require 'ipaddr'

require_relative '../lib/utils'
require_relative '../lib/scanlog'

default_host = 'localhost'
default_user = 'user'
default_ip = '10.0.0.1'

cark = 'cark_conf.json'
if File.exists?(cark)
	fileraw = File.read(cark)
	@config = JSON.parse(fileraw)
	user,pass = Utils.get_cark_creds(@config)
else
	raise "Unable to find CyberARK conf file."
end

if @config['nexposehost'].nil?
	host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
else
	host = @config['nexposehost']
end

#user = ask("Enter your username to log on: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }
check_ip = ask("Enter the IP address to check: ") { |q| q.default = default_ip }

check_iprobj = Nexpose::IPRange.new("#{check_ip}/32")

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

# check for specified IP in Global Exclusions
gexcl = Nexpose::GlobalSettings.load(@nsc).asset_exclusions
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
				# export the scan log
				print "Pulling scan log...."
				#@nsc.export_scan(as.scan_id, "scanlog-#{as.scan_id}.zip")
				@nsc.download("https://#{@nsc.host}:3780/data/scan/log?scan-id=#{as.scan_id}", "scanlog-#{as.scan_id}.zip")
				puts "done."
				# objectify scan logg
				%x{unzip scanlog-#{as.scan_id}.zip}
				log = ScanLog::Log.new("scan.log")
				#reg = DateTime.new
				reg = nil
				#unreg = DateTime.new
				unreg = nil
				lines_found = Array.new
				log.entries.each do |e|
					if e.message =~ /#{check_ip}/
						reg = DateTime.parse(e.datetime.to_s) if e.message =~ /Registered\./
						#puts "#{e.datetime} :: #{e.message}"
						unreg = DateTime.parse(e.datetime.to_s) if e.message =~ /Unregistered\./
						lines_found.push(e.to_s)
					end
				end
				# look for affected IP/range
				if reg.nil? and unreg.nil?
					puts "Unable to find register/unregister for IP (#{check_ip})".yellow
					pp lines_found
				else
					if reg.nil?
						reg = DateTime.new(1970,1,1,0,0,0)
					end
					if unreg.nil?
						unreg = DateTime.new(1970,1,1,0,0,0)
					end
					reg = reg.new_offset('-08:00')
					unreg = unreg.new_offset('-08:00')
					puts "#{check_ip} was first touched at " + reg.to_s.green + "."
					puts "The scan of #{check_ip} finished at " + unreg.to_s.green + "."
				end
				%x{/bin/rm -f *scan.log scanlog-#{as.scan_id}.zip}
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
