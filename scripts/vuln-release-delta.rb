#!/usr/bin/env ruby

require 'pp'
require 'nexpose'
require 'colorize'
require 'highline/import'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'user'

verbose = false

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

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

today = DateTime.now
before = today - 90
print "Start: ".green
print "#{before}".yellow
print "  "
print "Today: ".green
puts "#{today}".yellow

vulns = @nsc.find_vulns_by_date(before, today)
h_vulns = Hash.new
vulns.each do |v|
	#pp v
	begin
		vd = Nexpose::VulnerabilityDefinition.load(@nsc, v.id)
	rescue Nexpose::APIError => err
		puts "There was a problem GETting the definition for vulnId #{v.id}.".red.bold
		puts "Title: #{v.title}".yellow
		puts "Error message: #{err.message}"
		next
	end
	print "Initial release: ".green
	print "#{vd.date_published}".yellow
	print ", "
	print "First Checked: ".green
	print "#{vd.date_added}".yellow
	print ", "
	print "Delta: ".green
	delta = vd.date_published - vd.date_added
	puts "#{delta}".red.bold
end
