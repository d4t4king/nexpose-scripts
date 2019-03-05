#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

default_host = 'nc1.example.com'
#default_port = 3780
default_user = 'sv-nexposegem'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

@nsc.sites.each do |ssum|
	site = Nexpose::Site.load(@nsc, ssum.id)
#	next unless site.name == "Internal - Vulnerability Scan - 172.24.0.0/13" or 
#		site.name == "Internal - Vulnerability Scan - 172.20.0.0/14"
	if site.name =~ /(?:In|Ex)ternal - (?:Authenticated )?Vulnerability Scan - /
		if site.schedules.size > 0
			#pp site.schedules
			if site.schedules.size > 1
				puts "More than one schedule for site!".red.bold
			else
				if site.schedules[0].repeater_type == "restart"
					puts "Changing repeaster type for #{site.name}".light_yellow
					site.schedules[0].repeater_type = "continue"
					site.save(@nsc)
				else
					puts "Site schedule already continues for #{site.name}".light_green
				end
			end
		end
	else
		puts "#{site.name} didn't match regex."
	end
end
