#!/usr/bin/env ruby

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'

default_host = 'localhost'
#default_port = 3780
default_user = 'user'
default_file = '/tmp/scan_history_dump.csv'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
#port = ask("Enter the port for Nexpose: ") { |q| q.default = default_port.to_s }
user = ask("Enter the username: ") { |q| q.default = default_user }
pass = ask("Enter the password: ") { |q| q.echo = '*' }
outfile = ask("Enter the path to write out the results: ") { |q| q.default = default_file }

#@nsc = Nexpose::Connection.new(host, port, user, pass)
@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login

at_exit { @nsc.logout }

scan_statuses = {}
force_end = false
@nsc.sites.each do |site|
	config = Nexpose::Site.load(@nsc, site.id)
	scan_history = @nsc.site_scan_history(site.id)
	scan_history.each do |scan|
		if scan_statuses.keys.include?(scan.status)
			scan_statuses[scan.status] += 1
		else
			scan_statuses[scan.status] = 1
		end
		if scan.status == 'stopped'
			force_end = true
			# is actually scan summery
			#pp scan
			this_site = Nexpose::Site.load(@nsc, scan.site_id)
			puts "Site Name: #{this_site.name}"
		end
		break
	end
	if force_end
		break
	end
end

scan_statuses.keys.each do |k|
	puts "#{k}: #{scan_statuses[k]}"
end
