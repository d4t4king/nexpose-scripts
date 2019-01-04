#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'

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

nsc.sites.each do |ssum|
	site = Nexpose::Site.load(nsc, ssum.id)
	#pp site
	if site.schedules.size >= 1
		puts "There is at least one schedule for site #{site.name}."
		puts "\tTotal schedule: #{site.schedules.size}"
		enabled = 0
		site.schedules.each do |sched|
			if sched.enabled
				enabled += 1
				sched.enabled = false
			end
		end
		puts "\t Total enabled: #{enabled}"
		site.save(nsc)	
	else
		puts "No schedule for site #{site.name}."
	end
end
