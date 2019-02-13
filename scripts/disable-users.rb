#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'colorize'

require_relative '../lib/utils'

cark = 'cark_conf.json'
fileraw = File.read(cark)
config = JSON.parse(fileraw)
username, password = Utils.get_cark_creds(config)

puts "Host: #{config['nexposehost']} User: #{username} Pass: #{password}"
nsc = Nexpose::Connection.new(config['nexposehost'], username, password)
at_exit { nsc.logout }

nsc.login
if nsc.session_id
	puts "Login successful"
else
	puts "login failed"
	exit 1
end

nsc.users.each do |u|
	if u.auth_module == "XML" or u.auth_module == "DataStore"
		puts "Not disabling local accounts: #{u.name}".yellow
		next
	else
		if u.is_disabled
			puts "Account already disabled: (#{u.name})"
		else
			puts u.name.red
			user = Nexpose::User.load(nsc, u.id)
			user.enabled = 0
			user.save(nsc)
		end
	end
end
