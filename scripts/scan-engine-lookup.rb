#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'user'

default_site = 'localsite'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

#host = 'nc1***REMOVED***'
#user = ''
#pass = ''

w_site_name = ask("Enter the full site name: ") { |q| q.default = default_site }
w_site_id = nil
@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

@nsc.list_sites.each do |ssum|
	if ssum.name == w_site_name
		w_site_id = ssum.id
		break
	end
end

if w_site_id.nil?
	raise "Unable to identiy site by name (#{w_site_name})!".red
end

site_obj = Nexpose::Site.load(@nsc, w_site_id)
w_engine_id = site_obj.engine_id
eng_obj = Nexpose::Engine.load(@nsc, w_engine_id)
puts "Engine: #{eng_obj.name} IP: #{eng_obj.address}"

