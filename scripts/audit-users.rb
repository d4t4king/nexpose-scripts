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
at_exit { @nsc.logout }

@nsc.list_users.each do |user|
	puts "=" * 72
	pp user
	puts "=" * 72
	fquser = Nexpose::User.load(@nsc, user.id)
	pp fquser
	puts "=" * 72
	break
end
