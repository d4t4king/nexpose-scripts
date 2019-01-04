#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'netaddr'
require 'colorize'
require 'fileutils'
require 'getoptlong'
require 'highline/import'

require_relative '../lib/utils'

def usage
  puts <<-END

#{$0} -h -c <config file> -H <Nexpose host>

Where:
-h|--help         Displays this message, then exits
-H|--host         Nexpose host to connect to
-c|--config       JSON config file for CyberARK
-d|--directory	  Directory to save XML outputs

  END

  exit 0
end

default_host = 'localhost'
default_user = 'user'

opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--host', '-H', GetoptLong::REQUIRED_ARGUMENT],
  ['--config', '-c', GetoptLong::REQUIRED_ARGUMENT],
  ['--directory', '-d', GetoptLong::REQUIRED_ARGUMENT],
)

@help = false
@config = nil
conffile = nil
@host = nil
@savedir = nil

opts.each do |opt,arg|
  case opt
  when '--help'
    @help = true
  when '--host'
    @host = arg
  when '--config'
    conffile = arg
  when '--directory'
	@savedir = arg
  else
    raise ArgumentError "Unrecognized argument: #{opt}"
  end
end

usage if @help
usage if @host.nil?
usage if @savedir.nil?

if conffile.nil?
  @host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
  @user = ask('Enter your username: ') { |q| q.default = default_user }
  @pass = ask('Enter your password: ') { |q| q.echo = '*' }
else
  fileraw = File.read(conffile)
  @config = JSON.parse(fileraw)
  @user,@pass = Utils.get_cark_creds(@config)
end

nsc = Nexpose::Connection.new(@host, @user, @pass)
nsc.login
at_exit { nsc.logout }
nsc.list_scan_templates.each do |tmpl|
	# ScanTemplateSummary
	# need to get the ScanTempalte to see config
	template = Nexpose::ScanTemplate.load(nsc, tmpl.id)
	if !File.exists?(@savedir)
		FileUtils.mkdir_p(@savedir)
	end
	#puts template.xml
	File.open("#{@savedir}/#{template.id}.xml", 'wb') do |f|
		f.write(template.xml)
	end
end
