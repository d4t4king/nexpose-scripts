#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'colorize'
require 'nexpose'
require 'highline/import'

require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'nxadmin'
default_format = 'csv'
default_site_id = '405'
default_scan_id = '0'

cark = 'cark_conf.json'
if File.exists?(cark)
  fileraw = File.read(cark)
  @config = JSON.parse(fileraw)
  user,pass = Utils.get_cark_creds(@config)
end

#host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
host = default_host
#user = ask("Enter your username to log on: ") { |q| q.default = default_user }
#pass = ask("Enter your password: ") { |q| q.echo = "*" }
format = ask("Enter the output format: ") { |q| q.default = default_format }
site_id = ask("Enter the site id: ") { |q| q.default = default_site_id }
scan_id = ask("Enter the scan id: ") { |q| q.default = default_scan_id }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

report = Nexpose::AdhocReportConfig.new('prioritized-remediations-with-details', 'pdf', site_id)
adhoc_report.add_filter('scan', scan_id)
data = adhoc_report.generate(@nsc)
File.open("/tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf", 'wb') { |f| f.write(data) }
puts "You report has been saved to /tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf"
