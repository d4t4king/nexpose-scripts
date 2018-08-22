#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'colorize'
require 'getoptlong'
require 'highline/import'

require_relative '../lib/utils'

def usage
  puts <<-END

#{$0} -h -c <config file> -H <nexpose host> -i 'site id' -s 'scan id' -f 'format'

Where:
-h|--help         Display this message and exit.
-H|--host         Hostname or IP for the nexpose console to connect to
-c|--config       Config file for CyberARK in JSON format
-i|--site-id      Site id for which to run the report.
-s|--scan-id      Scan id for which to run the report.
-f|--format       Format of the report.  Default is pdf.

END
  exit 0
end

default_host = 'localhost'
default_user = 'nxadmin'
default_format = 'pdf'
default_site_id = '405'
default_scan_id = '0'

opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--host', '-H', GetoptLong::REQUIRED_ARGUMENT],
  ['--config', '-c', GetoptLong::REQUIRED_ARGUMENT],
  ['--site-id', '-i', GetoptLong::REQUIRED_ARGUMENT],
  ['--scan-id', '-s', GetoptLong::REQUIRED_ARGUMENT],
  ['--format', '-f', GetoptLong::REQUIRED_ARGUMENT],
)

@help = false
@host = nil
@user = nil
@pass = nil
@config = nil
conffile = nil
@format = nil
@site_id = 0
@scan_id = 0

opts.each do |opt,arg|
  case opt
  when '--help'
    @help = true
  when '--host'
    @host = arg
  when '--config'
    conffile = arg
  when '--site-id'
    @site_id = arg
  when '--scan-id'
    @scan_id = arg
  when '--format'
    @format = arg
  else
    raise ArgumentException "Unrecognized argument: #{opt}"
  end
end

if conffile.nil?
  @host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
  @user = ask("Enter your username to log on: ") { |q| q.default = default_user }
  @pass = ask("Enter your password: ") { |q| q.echo = "*" }
  #w_site_name = ask("Enter the full site name: ") { |q| q.default = default_site }
  @format = ask("Enter the output format: ") { |q| q.default = default_format }
  @site_id = ask("Enter the site id: ") { |q| q.default = default_site_id }
  @scan_id = ask("Enter the scan id: ") { |q| q.default = default_scan_id }
  #w_site_id = nil
else
  fileraw = File.read(conffile)
  @config = JSON.parse(fileraw)
  @user,@pass = Utils.get_cark_creds(@config)
end

@nsc = Nexpose::Connection.new(@host, @user, @pass)
@nsc.login
at_exit { @nsc.logout }

adhoc_report = Nexpose::AdhocReportConfig.new('prioritized-remediations-with-details', 'pdf', @site_id)
adhoc_report.add_filter('scan', @scan_id)
data = adhoc_report.generate(@nsc)
File.open("/tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf", 'wb') { |f| f.write(data) }
puts "You report has been saved to /tmp/site-#{site_id}-scan-#{scan_id}-audit.pdf"
