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

cark = 'cark_conf.json'
if File.exists?(cark)
	fileraw = File.read(cark)
	@config = JSON.parse(fileraw)
	user,pass = Utils.get_cark_creds(@config)
else
	raise "Couldn't find the CyberARK config file."
end

if @config['nexposehost'].nil?
	host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
else
	host = @config['nexposehost']
end
#user = ask("Enter your username to log on: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

@nsc.reports.each do |rpt|
	#pp rpt
	#puts "#{rpt.config_id} #{rpt.name} #{rpt.template_id}"
	report = Nexpose::ReportConfig.load(@nsc, rpt.config_id)
	if rpt.generated_on.nil? or rpt.generated_on == ""
		puts "Name: #{report.name} Generated on: #{rpt.generated_on} Users: #{report.users} Status: #{rpt.status}".yellow.bold
		begin
			tmp = Nexpose::ReportTemplate.load(@nsc, rpt.template_id)
			puts "	Assets: #{tmp.show_asset_names}".yellow.bold
			if report.users.size == 0 and rpt.status == "Unknown"
				puts "Abandoned report: #{report.name}  Deleting.".cyan
				report.delete(@nsc)
			end
		rescue Nexpose::APIError => err
			if err.message =~ /Template not found/
				$stderr.puts "ERROR:  Template not found.  Deleting report.".red.bold
				report.delete(@nsc)
			else
				raise err
			end
		end
	else
		puts "Name: #{report.name} Generated on: #{rpt.generated_on} Users: #{report.users} Status: #{rpt.status}"
	end
end
