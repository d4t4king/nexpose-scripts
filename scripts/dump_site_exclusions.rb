#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
include Nexpose  
  
require_relative 'utils'

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password: ') { |q| q.echo = '*' }

nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  

nsc.sites.each do |ssum|
	site = Site.load(nsc, ssum.id)
	#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
	next if site.excluded_addresses.size == 0
	filename = site.name.tr(" ", "_")
	filename.tr!("/", "_")
	File.open("#{filename}.txt", 'w') { |f|
		site.excluded_addresses.each do |e|
			if e.is_a?(IPRange)
				f.puts "#{e.from}-#{e.to}"
			elsif e.is_a?{HostName}
				f.puts "#{e.name}"
			else
				raise "Unrecognized object type: #{e.class} \n #{e.inspect}".red
			end
		end
	}
end
