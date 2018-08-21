#!/usr/bin/env ruby  

require 'pp'
require 'json'
require 'nexpose'
require 'colorize'
require 'getoptlong'
require 'highline/import'
include Nexpose

def usage
	puts <<-END

Where:
-h|--help		Display this message and then exit.
-c|--config		Specify the JSON config file for CyberARK
-H|--host		Nexpose Console host to connect to.
-o|--output		File path to output the results.
END
	exit 0
end

def get_cark_creds(config)
	pass = %x{ssh root@#{config['aimproxy']} '/opt/CARKaim/sdk/clipasswordsdk GetPassword -p AppDescs.AppID=#{config['appid']} -p "Query=safe=#{config['safe']};Folder=#{config['folder']};object=#{config['objectname']}" -o Password'}
	pass.chomp!
	return config['username'],pass
end

default_host = 'localhost'
default_user = 'user'
default_file = "/tmp/scan_time_analysis.csv"

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
	['--host', '-H', GetoptLong::REQUIRED_ARGUMENT ],
	['--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
)

@help = false
@config = nil
conffile = nil
@host = nil
@user = nil
@pass = nil
@outfile = nil

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--config'
		conffile = arg
	when '--host'
		@host = arg
	when '--output'
		@outfile = arg
	else
		raise ArgumentError "Unrecognized argument: #{opt}"
	end
end

usage if @help

if conffile.nil?
	@host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
	@user = ask("Enter your username: ") { |q| q.default = default_user }
	@pass = ask("Enter your password: ") { |q| q.echo = "*" }
	@outfile = ask("Enter the path to write out the results: ") { |q| q.default = default_file }
else
	fileraw = File.read(conffile)
	@config = JSON.parse(fileraw)
	@user,@pass = get_cark_creds(@config)
end
  
#nsc = Connection.new(host, port, user, pass)
nsc = Connection.new(@host, @user, @pass)
nsc.login  
at_exit { nsc.logout }  
  
scan_times = {}  
scan_assets = {}  
  
nsc.sites.each do |site|  
	config = Site.load(nsc, site.id)
	#puts "#{config.name}|#{config.scan_template_id}"
	
	scan_history = nsc.site_scan_history(site.id)
	scan_history.each do |scan|
		next unless scan.status == "finished"
		#pp scan_history
		scan_id = scan.scan_id
		live = scan.nodes.live if scan.nodes
		start_time = scan.start_time
		end_time = scan.end_time

		if live
			scan_times["#{site.id}:#{scan_id}"] ||= 0
			scan_times["#{site.id}:#{scan_id}"] += (end_time - start_time)
			scan_assets["#{site.id}:#{scan_id}"] ||= 0
			scan_assets["#{site.id}:#{scan_id}"] += live
		else
			puts "No live hosts in scan (#{site.id} => #{scan_id})."
		end
	end
end

sites = nsc.list_sites
File.open(@outfile, 'w') do |f|
	puts "Site Name,Site ID,Asset Count,Total Time (seconds),Total Time (Human),Average (min/asset)"
	f.puts "Site Name,Site ID,Asset Count,Total Time (seconds),Total Time (Human),Average (min/asset)"
	scan_times.each do |id,time|
		site_name = sites.find { |s| s.id == id.to_s.split(":")[0].to_i }.name
		avg_time = '%.2f' % (time / scan_assets[id] / 60)
		mm, ss = time.divmod(60)
		hh, mm = mm.divmod(60)
		dd,hh = hh.divmod(24)
		puts "#{site_name},#{id},Assets: #{scan_assets[id]},#{time},#{dd}d #{hh}:#{mm}:#{ss},#{avg_time}"
		f.puts "#{site_name},#{id},#{scan_assets[id]},#{time},#{dd}d #{hh}:#{mm}:#{ss},#{avg_time}"
	end
end
