#!/usr/bin/env ruby

require 'pp'
require 'nexpose'
require 'colorize'
require 'highline/import'

default_host = 'is-vmcrbn-p01***REMOVED***'
default_user = 'sv-nexposegem'

@host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
@user = ask("Enter your username to log on: ") { |q| q.default = default_user }
@pass = ask("Enter your password: ") { |q| q.echo = "*" }

@staleDays = 90

@nsc = Nexpose::Connection.new(@host, @user, @pass)
@nsc.login

at_exit { @nsc.logout }

scheduledSites = Array.new
@nsc.sites.each do |ss|
	site = Nexpose::Site.load(@nsc, ss.id)
	if site.schedules.any?
		scheduledSites << ss.id
	else 
		puts "No scheduled scans for SiteID: #{ss.id} SiteName: #{ss.name}"
	end
end


old_assets = @nsc.filter(Nexpose::Search::Field::SCAN_DATE, Nexpose::Search::Operator::EARLIER_THAN, @staleDays)
totalStale = 0
deletedStale = 0
old_assets.each do |dev|
	#pp dev
	#gets
	if scheduledSites.include?(dev.site_id)
		puts "Stale: #{dev.ip.to_s.green} [ID: #{dev.id.to_s.yellow}] Site: #{dev.site_id.to_s.light_yellow} Last Scanned: #{dev.last_scan.to_s.magenta}"
		totalStale += 1
		if dev.vuln_count == 0
			ider = dev.name ? dev.name : dev.ip
			puts "\tVulnerability count 0 for device #{ider.to_s.red}, deleting..."
			@nsc.delete_device(dev.id)
			deletedStale += 1
		end
	end
end

puts "Total stale: #{totalStale.to_s.yellow}"
puts "total stales deleted: #{deletedStale.to_s.magenta}"
