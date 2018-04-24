#!/usr/bin/env ruby

require 'nexpose'
require 'colorize'
require 'pp'
require 'highline/import'
require 'netaddr'
require 'sqlite3'

require_relative '../lib/utils'

include Nexpose

default_host = 'localhost'
default_user = 'user'
default_pass = 'pass'

host = ask('Enter the server name (host) for Nexpose: ') { |q| q.default = default_host }
user = ask('Enter your username: ') { |q| q.default = default_user }
pass = ask('Enter your password: ') { |q| q.echo = '*' }

raise "You must specify a file to reconcile the global exclusions against/".red unless ARGV[0]
raise "Specified file does not exist! (#{ARGV[0]})".red unless File.exist?(ARGV[0])
raise "Specified file is zero (0) bytes! (#{ARGV[0]})".red if File.zero?(ARGV[0])

fexcls = Array.new
File.open(ARGV[0], 'rb').each_line do |l|
	l.strip!
	case l
	when /^[0-9.]+$/								# single IP
		fexcls.push(IPRange.new(l)) unless fexcls.include?(IPRange.new(l))
	when /^[0-9.]+\s*-\s*[0-9.]+/					# IP range
		lower,upper = l.split('-')
		lower.gsub!(/\s+/, "")
		upper.gsub!(/\s+/, "")
		fexcls.push(IPRange.new(lower,upper)) unless fexcls.include?(IPRange.new(lower,upper))
	when /^[0-9.]+\/[0-9]{1,2}$/					# CIDR block
		fexcls.push(IPRange.new(l)) unless fexcls.include?(IPRange.new(l))
	else
		raise "Unrecognized format: #{l}".red
	end
end

fexcls_cidrs = Utils.cidrize(fexcls)

nsc = Connection.new(host, user, pass)
nsc.login
at_exit{ nsc.logout }

settings = GlobalSettings.load(nsc)
gexcls = settings.asset_exclusions
gexcls_cidrs = Utils.cidrize(gexcls)
to_add = Array.new
found = Hash.new
fexcls_cidrs.sort.each do |key,obj|
	gexcls_cidrs.sort.each do |gkey,gobj|
		if key.eql?(gkey)
			puts "Found: #{gkey}|#{key}".green
			if !found[key]
				found[key] = 1
			else
				found[key] += 1
			end
			break
		elsif gobj.contains?(obj)
			puts "Found: #{gkey} contains #{key}".green
			if !found[key]
				found[key] = 1
			else
				found[key] += 1
			end
			break
		end
	end
	to_add.push(key) unless found[key]
end

if to_add.size == 0
	puts "All nets in file reconciled with Global Exclusion list.".green.bold
else
	puts "These nets were not in the global list:".magenta
	to_add.each do |ip|
		puts ip.to_s
	end
end

#to_add.sort.each do |ip|
#	settings.add_exclusion(ip)
#	settings.save(nsc)
#end
