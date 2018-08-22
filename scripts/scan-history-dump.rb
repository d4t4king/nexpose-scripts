#!/usr/bin/env ruby

require 'pp'
require 'csv'
require 'nexpose'
require 'colorize'
require 'highline/import'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'nxadmin'
default_file = '/tmp/scan_history_dump.csv'

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

#user = ask("Enter the username: ") { |q| q.default = default_user }
#pass = ask("Enter the password: ") { |q| q.echo = '*' }
outfile = ask("Enter the path to write out the results: ") { |q| q.default = default_file }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login

at_exit { @nsc.logout }

scan_statuses = {}
force_end = false
rows = Array.new
@nsc.sites.each do |site|
	config = Nexpose::Site.load(@nsc, site.id)
	scan_history = @nsc.site_scan_history(site.id)
	scan_history.each do |scan|
		if scan_statuses.keys.include?(scan.status)
			scan_statuses[scan.status] += 1
		else
			scan_statuses[scan.status] = 1
		end
		site = Nexpose::Site.load(@nsc, scan.site_id)
		engine = ''
		if scan.engine_id == -1
			engine = 'Pool or Error'
		else
			eng = Nexpose::Engine.load(@nsc, scan.engine_id)
			engine = eng.name
		end
		rows << [ scan.scan_id, scan.site_id, site.name, scan.start_time, scan.end_time, scan.engine_id, engine, scan.status, scan.nodes.live, scan.nodes.dead, scan.nodes.filtered, scan.nodes.unresolved, scan.nodes.other ]
		print ".".cyan
	end
	print ".".green.blink
end
puts

scan_statuses.keys.each do |k|
	puts "#{k}: #{scan_statuses[k]}"
end

CSV.open(outfile, "wb") do |csv|
	csv << ["Scan ID","Site ID","Site Name","Start Time","End Time","Scan Engine ID", "Scan Engine Name","Scan Status","Live Nodes","Dead Nodes","Filtered Nodes","Unresolved Nodes","Other Nodes"]
	rows.each do |row|
		csv << row
	end
end
