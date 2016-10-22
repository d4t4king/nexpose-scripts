#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
include Nexpose  
  
require_relative 'Utils.rb'

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password; ') { |q| q.echo = '*' }

nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  

excls = Array.new
gexcls = GlobalSettings.load(nsc).asset_exclusions
gexcls_cidrs = Array.new
vbgexcls = Array.new

gexcls.each do |ex|
	if ex.is_a?(IPRange)
		if ex.to.nil?
			range = ex.from.to_s
			lower = ex.from.to_s
			upper = ex.from.to_s
		else
			range = ex.from.to_s + "-" + ex.to.to_s
			lower = ex.from.to_s
			upper = ex.to.to_s
		end
		bits = Utils.calc_mask(lower,upper)
		cidr = NetAddr::CIDR.create("#{ex.from}/#{bits}")
		gexcls_cidrs.push(cidr) unless gexcls_cidrs.include?(cidr)
	else
		raise "Unexpacted object class: #{ex.class}"
	end
end

nsc.sites.each do |ssum|
	site = Site.load(nsc, ssum.id)
	#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
	excls.push(site.excluded_addresses)
end

gexcls_cidrs.each do |c|
	puts "#{c} : #{c.first} - #{c.last}"
end
