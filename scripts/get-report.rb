#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

default_host = 'is-vmcrbn-p02***REMOVED***'
#default_port = 3780
default_user = 'ad-cheselto'
#default_site = 'localsite'
default_format = 'pdf'
default_site_id = '405'
default_scan_id = '0'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
#w_site_name = ask("Enter the full site name: ") { |q| q.default = default_site }
format = ask("Enter the output format: ") { |q| q.default = default_format }
site_id = ask("Enter the site id: ") { |q| q.default = default_site_id }
scan_id = ask("Enter the scan id: ") { |q| q.default = default_scan_id }
#w_site_id = nil
@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

adhoc_report = Nexpose::AdhocReportConfig.new('prioritized-remediations-with-details', 'pdf', site_id)
adhoc_report.add_filter('scan', scan_id)
data = adhoc_report.generate(@nsc)
File.open("/tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf", 'wb') { |f| f.write(data) }
puts "You report has been saved to /tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf" 


