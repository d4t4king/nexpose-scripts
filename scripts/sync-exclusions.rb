#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'yaml'
require 'net/ftp'
require 'nexpose'
require 'colorize'
require 'highline/import'

require_relative '../lib/utils'

cark = 'cark_conf.json'
if File.exists?(cark)
	fileraw = File.read(cark)
	@config = JSON.parse(fileraw)
	user,pass = Utils.get_cark_creds(@config)
else
	raise "Couln't file the CyberARK config gile."
end

if @config['nexposehost'].nil?
	host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
else
	host = @config['nexposehost']
end

confyaml = 'consoles.yml'
if File.exists?(confyaml)
	yamldata = YAML.load_file(confyaml)
end
#pp yamldata

ref_excls = []
yamldata['consoles'].each do |console|
	pp console

	@nsc = Nexpose::Connection.new(console['ipaddress'], user, pass)
	at_exit { @nsc.logout }
	@nsc.login

	puts(console['authoritative'].cyan.bold)

	globalex = Nexpose::GlobalSettings.load(@nsc)

	to_file = Array.new()
	if globalex.asset_exclusions.is_a?(Array)
		puts("Got an array of objects from the Global Exclusion list.")
		globalex.asset_exclusions.each do |ex|
			print("Object Type: #{ex.class} ")
			if ex.is_a?(Nexpose::IPRange)
				puts("From: #{ex.from} To: #{ex.to}")
				if ex.to.nil?
					mask = Utils.calc_mask(ex.from, ex.from)
				else
					mask = Utils.calc_mask(ex.from, ex.to)
				end
				cidr = NetAddr::IPv4Net.parse("#{ex.from}#{mask}")
				puts("CIDR: #{cidr}".yellow)
				if !to_file.include?(cidr)
					to_file << cidr
				end
			else
				puts("Name: #{ex.name}")
			end
		end
	else
		puts("Got a #{globalex.class} from the Global Exclusion list.")
	end
end

exit 1

f = File.new("nexpose_exclusions.txt", 'w')
to_file.each do |c|
	f.write("#{c.to_s}\n")
end
f.close

# now ftp the file to the server
Net::FTP.open('***REMOVED***', 'scanexclusions\***REMOVED***', '***REMOVED***') do |ftp|
	ftp.putbinaryfile(f, "/site/wwwroot/Data/#{File.basename(f)}")
end

