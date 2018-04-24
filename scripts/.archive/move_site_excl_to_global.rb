#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'sqlite3'
include Nexpose  
  
require_relative '../lib/utils'

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password: ') { |q| q.echo = '*' }

nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  

excls = Array.new
excls_cidrs = Array.new
gexcls = GlobalSettings.load(nsc).asset_exclusions
gexcls_cidrs = Array.new
ex_by_site = Hash.new

nsc.sites.each do |ssum|
	site = Site.load(nsc, ssum.id)
	#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
	next if site.excluded_addresses.size == 0
	if site.excluded_addresses.is_a?(Array)
		site.excluded_addresses.sort.each do |addr|
			excls.push(addr)
			if ex_by_site.key?(site.name)
				ex_by_site[site.name] = ex_by_site[site.name] + "|" + addr.to_s
			else 
				ex_by_site[site.name] = addr.to_s
			end
			ex_by_site[addr.to_s] = site.name
		end
	else
		raise "Unexpected object type: #{site.excluded_addresses.class}".red
	end			
end

excls_cidrs = Utils.cidrize(excls)
gexcls_cidrs = Utils.cidrize(gexcls)

to_add_gcidrs = Hash.new
to_rem_gcidrs = Hash.new
to_rem_lcidrs = Hash.new
excls_cidrs.each do |lk,lobj|
	gexcls_cidrs.each do |gk,gobj|
		if gobj.contains?(lobj)
			puts "local exclusion found in global exclusion (L:#{lk} G:#{gk}".green
			to_rem_lcidrs[lk] = lobj
		elsif gobj.is_contained?(lobj)
			puts "global exclusion contained by local exclusion (G:#{gk} L:#{lk}".yellow
			to_rem_gcidrs[gk] = gobj
			to_add_gcidrs[lk] = lobj
		elsif gobj.eql?(lobj)
			puts "global object matches local exclusion (G:#{gk} L:#{lk}".blue
			to_rem_lcidrs[lk] = lobj
		else
			to_add_gcidrs[lk] = lobj
			to_rem_lcidrs[lk] = lobj
		end
	end
end

#puts "Global exclusions to be removed:"
#to_rem_gcidrs.values.sort.each do |c|
#	puts c.to_s.green
#	gexcls_cidrs.delete(c.to_s)
#end
#puts "Global exclusions to be added:"
#to_add_gcidrs.values.sort.each do |c|
#	puts c.to_s.cyan
#	gexcls_cidrs[c.to_s] = c unless gexcls_cidrs.keys.include?(c.to_s)
#end
#puts "Local exclusions to be removed:"
#to_rem_lcidrs.values.sort.each do |c|
#	puts c.to_s.magenta
#end
#puts "All global exclusions:"
#gexcls_cidrs.keys.sort.each do |k|
#	puts k.to_s.yellow.bold
#end

puts "Clearing out site-specific exclusions...."
nsc.sites.each do |ss|
	s = Site.load(nsc, ss.id)
	if  s.excluded_addresses.size > 0
		puts "  #{s.name}  "
		s.excluded_addresses = []
		s.save(nsc)
	end
end
puts "done."

puts "Adding exclusions to global settings...."
settings = GlobalSettings.load(nsc)
gexcls_cidrs.keys.sort.each do |k|
	settings.add_exclusion(k)
end
settings.save(nsc)
puts "done."

