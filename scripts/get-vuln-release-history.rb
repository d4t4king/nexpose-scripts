#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'colorize'
#require 'highline/import'

require_relative '../lib/utils'

default_host = 'localhost'
#default_user = 'user'

verbose = false

carkconf = "cark_conf.json"
if File.exists?(carkconf)
	fileraw = File.read(carkconf)
	@config = JSON.parse(fileraw)
	@user,@pass = Utils.get_cark_creds(@config)
else
	raise "Couldn't find the CyberARK config file.  Expected cark_conf.json."
end

#host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
#user = ask("Enter your username to log on: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }

if @configp'nexposehost'].nil?
  host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
else
  host = @config['nexposehost']
end

@nsc = Nexpose::Connection.new(host, @user, @pass)
@nsc.login
at_exit { @nsc.logout }

puts "Showing vulns added or updated in the last 90 days."
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
	if !h_vulns.has_key?(v.published)
		h_vulns[v.published] = v.title
	end
end

pp h_vulns.sort
