#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'colorize'
require 'nexpose'
require 'highline/import'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'nxadmin'
default_format = 'pdf'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
#user = ask("Enter your username to log on: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }

cark = 'cark_conf.json'
if File.exists?(cark)
  fileraw = File.read(cark)
  @config = JSON.parse(fileraw)
  user,pass = Utils.get_cark_creds(@config)
else
  raise "Unable to find the CyberARK config file."
end

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login

# Check Session ID
if @nsc.session_id
    puts 'Login Successful'
else
    puts 'Login Failure'
end

at_exit { @nsc.logout }

@nsc.report_templates.each do |rpt|
	template = Nexpose::ReportTemplate.load(@nsc, rpt.template_id)
	pp template.properties
	break
end
