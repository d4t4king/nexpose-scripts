#!/usr/bin/env ruby

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'ipaddr'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'user'

cark = 'cark_conf.json'
if File.exists?(cark)
  fileraw = File.read(cark)
  @config = JSON.parse(fileraw)
  user,pass = Utils.get_cark_creds(@config)
else
  raise "Couldn't find CyberARK conf file."
end

if @config['nexposehost'].nil?
  host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
else
  host = @config['nexposehost']
end
#user = ask("Enter your username: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }

nsc = Nexpose::Connection.new(host, user, pass)
nsc.login
at_exit { nsc.logout }

nsc.sites.each do |ss|
	site = Nexpose::Site.load(nsc, ss.id)
	puts "Site: #{site.name} Template: #{site.scan_template_id}"
end
