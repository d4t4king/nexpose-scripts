#!/usr/bin/env ruby

require 'pp'
require 'csv'
require 'nexpose'
require 'getoptlong'

require_relative '../lib/utils'

def usage
	puts <<-END

#{$0} -h -C [JSON config]-s <Site>

Where:
-h|--help			Displays this useful message and exit.
-c|--config			Specifies the config file for CyberARK in JSON format.
-H|--host			Specifies the Nexpose console to connect to.  This can also be specified as 'nexposehost' in the config JSON.
-s|--site			The site to dump
-o|--out			Output file to save dump.

END
	exit 0
end

def get_site_id(nsc, name)
	nsc.sites.each do |ssum|
		if ssum.name == name
			return ssum.id
		end
	end
end
	
opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--host', '-H', GetoptLong::REQUIRED_ARGUMENT ],
	['--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
	['--site', '-s', GetoptLong::REQUIRED_ARGUMENT ],
	['--out', '-o', GetoptLong::REQUIRED_ARGUMENT ],
)

help = false
config = nil
conffile = nil
ssite = nil
outfile = nil

opts.each do |opt,arg|
	case opt
	when '--help'
		help = true
	when '--host'
		host = arg
	when '--config'
		conffile = arg
	when '--site'
		ssite = arg
	when '--out'
		outfile = arg
	else
		raise "Unrecognized argument: #{opt}"
	end
end

usage if help
usage if conffile.nil?
usage if ssite.nil?
usage if outfile.nil?

fileraw = File.read(conffile)
config = JSON.parse(fileraw)
username,password = Utils.get_cark_creds(config)

usage if config['nexposehost'].nil? and host.nil?
host = config['nexposehost'] if host.nil? and !config['nexposehost'].nil?
nsc = Nexpose::Connection.new(host, username, password)
nsc.login

at_exit { nsc.logout }

if nsc.session_id
	puts "Login successful."
else
	puts "Login failed."
end

siteid = get_site_id(nsc, ssite)
oses = Hash.new
osgroups = Hash.new
osgroups['Windows Server'] = 0
osgroups['Windows'] = 0
osgroups['Non-Windows'] = 0
osgroups['Other'] = 0
ossubs = Hash.new
ossubs['Windows Server'] = Array.new
ossubs['Windows'] = Array.new
ossubs['Non-Windows'] = Array.new
ossubs['Other'] = Array.new
os2group = Hash.new
nsc.assets(siteid).each do |assum|
	#pp assum
	asset = Nexpose::Asset.load(nsc, assum.id)
	if oses.has_key?(asset.os_name)
		oses[asset.os_name] += 1
	else
		oses[asset.os_name] = 1
	end
	case asset.os_name
	when /windows server/i
		osgroups['Windows Server'] += 1
		if !ossubs['Windows Server'].include?(asset.os_name)
			ossubs['Windows Server'] << asset.os_name
		end
		if !os2group.has_key?(asset.os_name)
			os2group[asset.os_name] = 'Windows Server'
		end
	when /windows/i 
		if asset.os_name !~ /server/i
			osgroups['Windows'] += 1
			if !ossubs['Windows'].include?(asset.os_name)
				ossubs['Windows'] << asset.os_name
			end
			if !os2group.has_key?(asset.os_name)
				os2group[asset.os_name] = 'Windows'
			end
		else
			osgroups['Windows Server'] += 1
			if !ossubs['Windows Server'].include?(asset.os_name)
				ossubs['Windows Server'] << asset.os_name
			end
			if !os2group.has_key?(asset.os_name)
				os2group[asset.os_name] = 'Windows Server'
			end
		end
#	when /(?!windows)/i
#		osgroups['Non-Windows'] += 1
#		if !ossubs['Non-Windows'].include?(asset.os_name)
#			ossubs['Non-Windows'] << asset.os_name
#		end
#		if !os2group.has_key?(asset.os_name)
#			os2group[asset.os_name] = 'Non-Windows'
#		end
	else
		# we should never actually get here.
		osgroups['Other'] += 1
		if !ossubs['Other'].include?(asset.os_name)
			ossubs['Other'] << asset.os_name
		end
		if !os2group.has_key?(asset.os_name)
			os2group[asset.os_name] = 'Other'
		end
	end	
end

CSV.open(outfile, 'wb') do |csv|
	csv << ["Windows Servers:", osgroups['Windows Servers'], "Windows", \
		osgroups['Windows'], "Non-Windows", osgroups['Non-Windows'], "Other:", \
		osgroups['Other']]
	csv << []
	csv << ["OS Name", "Asset Count", "OS Group"]
	oses.sort_by {|_key, value| value}.reverse.to_h.keys.each do |k|
		#pp k
		#puts "#{k}, #{oses[k]}"
		csv << [k, oses[k], os2group[k]]
	end
end


