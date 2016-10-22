#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
include Nexpose

default_host = 'localhost'
default_port = 3780
default_name = 'user'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
port = ask("Enter the port for Nexpose: ") { |q| q.default = default_port }
user = ask("Enter your username: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
  
nsc = Connection.new(host, port, user, pass)
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
scan_times.each do |id,time|
	site_name = sites.find { |s| s.id == id.to_s.split(":")[0].to_i }.name
	avg_time = '%.2f' % (time / scan_assets[id] / 60)
	puts "#{site_name} : #{id} : Assets: #{scan_assets[id]} : Total: #{time} secs : Avg: #{avg_time} min/asset"
end
