#!/usr/bin/env ruby

require 'pp'
require 'getoptlong'
require 'colorize'
require 'nexpose'
require 'highline/import'
require 'ipaddr'

require_relative '../lib/utils'
require_relative '../lib/scanlog'

default_host = 'nc1***REMOVED***'
#default_port = 3780
default_user = 'user'
default_ip = '10.0.0.1'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
check_ip = ask("Enter the IP address to check: ") { |q| q.default = default_ip }

check_iprobj = Nexpose::IPRange.new("#{check_ip}/32")

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

# check for specified IP in Global Exclusions
gexcl = Nexpose::GlobalSettings.load(@nsc).asset_exclusions
is_global_exclusion = false
gexcl.each do |ipr|
	ck_ipaddr = IPAddr.new(check_iprobj.to_s)
	if ipr.to.nil?						# just a single IP
		if IPAddr.new(ipr.from) == ck_ipaddr
			puts "#{check_ip} was found in the Global Exclusion list.".green
			is_global_exclusion = true
			break
		end
	else								# Must be an actual range
		bits = Utils.calc_mask(ipr.from,ipr.to)
		cmp_iprobj = IPAddr.new("#{ipr.from}/#{bits}")
		if cmp_iprobj === ck_ipaddr
			puts "#{check_ip} found in Global Exclusion list (range: #{ipr.from}-#{ipr.to})".green
			is_global_exclusion = true
			break
		end
	end
end
unless is_global_exclusion
	puts "#{check_ip} was NOT found in the Global Exclusion list.".red
end

print "Searching for device by address...."
device = @nsc.find_device_by_address(check_ip)
puts "done."
affsite = Nexpose::Site.load(@nsc, device.site_id)
print "Affiliated site: ".green
puts "#{affsite.name}".yellow
# loop through the sites
#@nsc.sites.each do |ssum|
#	site = Nexpose::Site.load(@nsc, ssum.id)
