#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'sv-nexposegem'


host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

File.open('/tmp/sites_nets.csv', "w") do |f|
	f.puts "Site_ID,Site_Name,Site_Targets,Scan_Engine_ID,Scan_Engine_Name,Scan_Engine_IP"
	@nsc.list_sites.each do |ssum|
		#pp ssum
		f.print "#{ssum.id},#{ssum.name},"
		site = Nexpose::Site.load(@nsc, ssum.id)
		#pp site
		addresses = site.included_scan_targets[:addresses]
		#pp addresses
		if addresses.size > 5
			f.print "More than 5 address objects,"
		else
			is_first = true
			addresses.each do |addr|
				if addr.is_a?(Nexpose::IPRange)
					if is_first
						f.print "#{addr.from}-#{addr.to}"
						is_first = false
					else
						f.print "|#{addr.from}-#{addr.to}"
					end
				else			# assume it's a HostName
					if is_first
						f.print "#{addr.host}"
						is_first = false
					else
						f.print "|#{addr.host}"
					end
				end
			end
			f.print ","
		end
		begin
			eng = Nexpose::Engine.load(@nsc, site.engine_id)
		rescue Nexpose::APIError => apierr
			if apierr.message =~ /Virtual engines are not supported/
				f.puts "Virtual engines are not supported"
				next
			end
		end
		#pp eng
		f.puts "#{eng.id},#{eng.name},#{eng.address}"
	end
end
