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
  ['--output', '-o', GetoptLong::REQUIRED_ARGUMENT]
)

@help = false
@config = nil
conffile = nil
@host = nil
@output = nil

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

CSV.open(@output, "wb") do |csv|
	csv << ["Site ID","Site Name","Description","Engine ID","Scan Template ID","Scan Template Name","Exclusions","Targets","SHared Credentialsk","Site Credentials","Tags","Users","Schedules"]
	nsc.sites.each do |ssum|
		row = Array.new
		site = Nexpose::Site.load(nsc, ssum.id)
		#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
		# assemble the row
		row << site.id
		row << site.name
		row << site.description
		row << site.engine_id
		row << site.scan_template_id
		row << site.scan_template_name
		exclusions = ""
		targets = ""
		if site.excluded_addresses.size == 0
	    	puts "No exclusions for site (#{site.name})"
		end
		site.excluded_addresses.each do |e|
			if e.is_a?(Nexpose::IPRange)
				if e.to.nil?
					exclusions += "#{e.from}, "
				else
					exclusions += "#{e.from}-#{e.to}, "
				end
			elsif e.is_a?(Nexpose::HostName)
				exclusions += "#{e.host}, "
			else
				raise "Unrecognized object type: #{e.class} \n #{e.inspect}".red
			end
		end
		row << exclusions
		site.included_addresses.each do |i|
			if i.is_a?(Nexpose::IPRange)
				if i.to.nil?
					targets += "#{i.from}, "
				else
					targets += "#{i.from} - #{i.to}, "
				end
			elsif i.is_a?(Nexpose::HostName)
				targets += "#{i.host}, "
			else
				raise "Unrecognized object type: #{i.class} \n #{i.inspect}".red
			end
		end
		row << targets
		row << site.shared_credentials
		row << site.site_credentials
		row << site.tags
		_users = ""
		if site.users.size > 0
			site.users.each do |u|
				puts u[:id]
				user = Nexpose::User.load(nsc, u[:id])
				_users += "#{user.name}, "
			end
		end
		row << _users
		row << site.schedules
		# write the row to the CSV
		csv << row
		next
	end
end
