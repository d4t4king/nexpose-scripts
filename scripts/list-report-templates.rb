#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

default_host = 'is-vmcrbn-p01***REMOVED***'
#default_port = 3780
default_user = 'sv-nexposegem'
#default_site = 'localsite'
default_format = 'pdf'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login

# Check Session ID
if @nsc.session_id
    puts 'Login Successful'
else
    puts 'Login Failure'
end

at_exit { @nsc.logout }

@nsc.reports.each do |rpt|
	#if rpt.template_id =~ /(?:xml|scap)/i or rpt.name =~ /archer/i
	#if rpt.template_id == 'basic-vulnerability-check-results' and rpt.name =~ /internal - vulnerability scan/i
		#pp rpt
		puts "#{rpt.config_id} #{rpt.name} #{rpt.template_id}"
	#end
end
