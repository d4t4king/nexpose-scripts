#!/usr/bin/env ruby

require 'pp'
require 'csv'
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
  ['--output', '-o', GetoptLong::REQUIRED_ARGUMENT],
)

@help = false
@config = nil
conffile = nil
@host = nil
@output

opts.each do |opt,arg|
  case opt
  when '--help'
    @help = true
  when '--host'
    @host = arg
  when '--config'
    conffile = arg
  when '--output'
	@output = arg
  else
    raise ArgumentError "Unrecognized argument: #{opt}"
  end
end

usage if @help
usage if @host.nil?
usage if @output.nil?

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

CSV.open(@output, 'wb') do |csv|
	csv << ["ID",'Name','Full Name','Email','Enabled','All Sites','All Groups','Auth Source ID','Role','Sites','Groups']
	nsc.list_users.each do |u|
		#pp u
		user = Nexpose::User.load(nsc, u.id)
		print "#{user.id},#{user.name},#{user.full_name},#{user.email},#{user.enabled},"
		print "#{user.all_sites},#{user.all_groups},#{user.authsrcid},#{user.role_name},"
		puts "#{user.sites},#{user.groups}"
		row = [user.id,user.name,user.full_name,user.email,user.enabled]
		row << user.all_sites
		row << user.all_groups
		row << user.authsrcid
		row << user.role_name
		row << user.sites
		row << user.groups
		csv << row
	end
end
