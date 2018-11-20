#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'colorize'
require 'getoptlong'
require 'highline/import'

require_relative '../lib/utils'

def usage
	puts <<-END

#{$0} -h -C [JSON config]

Where:
-h|--help		Displays this message then exists.
-C|--config		Specifies the config information for CyberARK, in JSON format.
-H|--host		Specifies the Nexpose console to connect to.
-s|--stale-days	Specifies the retention period.

END
	exit 0
end

default_host = 'localhost'
default_user = 'nxadmin'
default_days = 90

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--host', '-H', GetoptLong::REQUIRED_ARGUMENT ],
	['--stale-days', '-s', GetoptLong::REQUIRED_ARGUMENT ],
	['--config', '-C', GetoptLong::REQUIRED_ARGUMENT ],
	['--pretend', '-p', GetoptLong::NO_ARGUMENT ],
)

@help = false
@config = nil
conffile = nil
@pretend = false

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--host'
		@host = arg
	when '--config'
		conffile = arg
	when '--stale-days'
		@staleDays = arg
	when '--pretend'
		@pretend = true
	else
		raise ArgumentError "Unrecognized argument: #{opt}"
	end
end

usage if @help

if conffile.nil?
	@host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
	@user = ask("Enter your username to log on: ") { |q| q.default = default_user }
	@pass = ask("Enter your password: ") { |q| q.echo = "*" }
	@staleDays = ask("Enter the maximum retention period (stale days): ") { |q| q.default = default_days }
else
	# import the JSON config from the file
	fileraw = File.read(conffile)
	@config = JSON.parse(fileraw)
	@user,@pass = Utils.get_cark_creds(@config)
end


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
		site = Nexpose::Site.load(@nsc, dev.site_id)
		puts "Stale: #{dev.ip.to_s.green} [ID: #{dev.id.to_s.yellow}] Site: #{site.name.light_yellow} Last Scanned: #{dev.last_scan.to_s.magenta}"
		totalStale += 1
		if @pretend; next; end
		if dev.vuln_count == 0
			ider = dev.name ? dev.name : dev.ip
			puts "\tVulnerability count 0 for device #{ider.to_s.red}, deleting..."
			@nsc.delete_device(dev.id)
			deletedStale += 1
		end
	end
end

puts "Total stale: #{totalStale.to_s.yellow}"
if not @pretend
	puts "total stales deleted: #{deletedStale.to_s.magenta}"
end
