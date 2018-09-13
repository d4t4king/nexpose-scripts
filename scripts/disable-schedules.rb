#!/usr/bin/env ruby

require 'nexpose'
require 'json'

require_relative '../utils'

cark = 'cark_conf.json'
fileraw = File.read(cark)
config = JSON.parse(fileraw)
password = Utils.get_cark_creds(config)

nsc = Nexpose::Connection(config['nexposehost'], config['username'], password)
at_exit { nsc.logout }

nsc.login
if nsc.session_id
	puts "Login successful"
else
	puts "login failed"
	exit 1
end


