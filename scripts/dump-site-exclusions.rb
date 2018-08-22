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

def get_cark_creds(config)
    pass = %x{ssh root@#{config['aimproxy']} '/opt/CARKaim/sdk/clipasswordsdk GetPassword -p AppDescs.AppID=#{config['appid']} -p "Query=safe=#{config['safe']};Folder=#{config['folder']};object=#{config['objectname']}" -o Password'}
    pass.chomp!
    #puts "|#{pass}|"
    return config['username'],pass
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
  @user,@pass = get_cark_creds(@config)
end

nsc = Nexpose::Connection.new(@host, @user, @pass)
nsc.login
at_exit { nsc.logout }

nsc.sites.each do |ssum|
	site = Nexpose::Site.load(nsc, ssum.id)
	#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
	if site.excluded_addresses.size == 0
    puts "No exclusions for site (#{site.name})"
    next
  end
	filename = site.name.tr(" ", "_")
	filename.tr!("/", "_")
	File.open("#{filename}.txt", 'w') { |f|
		site.excluded_addresses.each do |e|
			if e.is_a?(Nexpose::IPRange)
				f.puts "#{e.from}-#{e.to}"
			elsif e.is_a?{Nexpose::HostName}
				f.puts "#{e.name}"
			else
				raise "Unrecognized object type: #{e.class} \n #{e.inspect}".red
			end
		end
	}
end
