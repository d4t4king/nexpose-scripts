#!/usr/bin/env ruby

require 'pp'
require 'nexpose'
require 'colorize'
require 'highline/import'

default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'user'

verbose = false

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

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
	if !h_vulns.has_key?(v.published)
		h_vulns[v.published] = v.title
	end
end

pp h_vulns.sort
