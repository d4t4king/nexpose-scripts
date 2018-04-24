#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'ipaddr'

require_relative '../lib/utils'

include Nexpose

default_host = 'localhost'
default_user = 'user'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
  
nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  
  
nsc.sites.each do |ss|  
	next unless ss.name =~ /^Internal - Vulnerability Scan - 1/
	site = Site.load(nsc, ss.id)
	puts "Site: #{site.name} Template: #{site.scan_template_id}"
end
