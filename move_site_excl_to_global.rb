#!/usr/bin/env ruby  

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
include Nexpose  
  
require_relative 'Utils.rb'

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password: ') { |q| q.echo = '*' }

def hashize(cidr_ary)
	tmp = Hash.new
	cidr_ary.each do |c|
		tmp[c.to_s] = c
	end
	return tmp
end

def cidrize(ipaddr_ary)
	cidr_hsh = Hash.new
	ipaddr_ary.each do |ex|
		if ex.is_a?(IPRange)
			if ex.to.nil?
				#range = ex.from.to_s
				lower = ex.from.to_s
				upper = ex.from.to_s
			else
				#range = ex.from.to_s + "-" + ex.to.to_s
				lower = ex.from.to_s
				upper = ex.to.to_s
			end
			bits = Utils.calc_mask(lower,upper)
			cidr = NetAddr::CIDR.create("#{ex.from}/#{bits}")
			cidr_hsh[cidr.to_s] = cidr unless cidr_hsh[cidr.to_s]
		else
			raise "Unexpacted object class: #{ex.class}".red
		end
	end
	one = NetAddr.merge(cidr_hsh.values.sort, :Objectify => true)
	two = NetAddr.merge(one.sort, :Objectify => true)
	three = NetAddr.merge(two.sort, :Objectify => true)
	return hashize(three)
end

nsc = Connection.new(host, user, pass)
nsc.login  
at_exit { nsc.logout }  

excls = Array.new
excls_cidrs = Array.new
gexcls = GlobalSettings.load(nsc).asset_exclusions
gexcls_cidrs = Array.new

nsc.sites.each do |ssum|
	site = Site.load(nsc, ssum.id)
	#printf "%5d - %s - %-5d \n", ssum.id, site.name, site.excluded_addresses.size
	next if site.excluded_addresses.size == 0
	if site.excluded_addresses.is_a?(Array)
		site.excluded_addresses.sort.each do |addr|
			excls.push(addr)
		end
	else
		raise "Unexpected object type: #{site.excluded_addresses.class}".red
	end			
end

excls_cidrs = cidrize(excls)
gexcls_cidrs = cidrize(gexcls)

#excls_cidrs.each do |c|
#	puts "#{c} : #{c.first} - #{c.last}"
#end
#puts "================================================================================"
#gexcls_cidrs.each do |c|
#	puts "#{c} : #{c.first} - #{c.last}"
#end
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
			to_add_gcidrs[gk] = lobj
			to_rem_lcidrs[lk] = lobj
		end
	end
end

#pp to_add_gcidrs

#exit 0

puts "Global exclusions to be removed:"
to_rem_gcidrs.values.sort.each do |c|
	puts c.to_s.green
	gexcls_cidrs.delete(c.to_s)
end
puts "Global exclusions to be added:"
to_add_gcidrs.values.sort.each do |c|
	puts c.to_s.cyan
	gexcls_cidrs[c.to_s] = c unless gexcls_cidrs.keys.include?(c.to_s)
end
puts "Local exclusions to be removed:"
to_rem_lcidrs.values.sort.each do |c|
	puts c.to_s.magenta
end
puts "All global exclusions:"
gexcls_cidrs.keys.sort.each do |k|
	puts k.to_s.yellow.bold
end
