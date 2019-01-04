#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'netaddr'
require 'colorize'
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

  END

  exit 0
end

default_host = 'localhost'
default_user = 'user'

opts = GetoptLong.new(
  ['--help', '-h', GetoptLong::NO_ARGUMENT],
  ['--host', '-H', GetoptLong::REQUIRED_ARGUMENT],
  ['--config', '-c', GetoptLong::REQUIRED_ARGUMENT],
)

@help = false
@config = nil
conffile = nil
@host = nil

opts.each do |opt,arg|
  case opt
  when '--help'
    @help = true
  when '--host'
    @host = arg
  when '--config'
    conffile = arg
  else
    raise ArgumentError "Unrecognized argument: #{opt}"
  end
end

usage if @help
usage if @host.nil?

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

nsc.list_asset_groups.each do |assg|
	#pp assg
	ag = Nexpose::AssetGroup.load(nsc, assg.id)
	puts ag.as_xml
	break
end
