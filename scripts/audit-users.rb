#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'nexpose'
require 'highline/import'

# returns a has of arrays containing userid (k) 
# and an array of siteids (v) the user can access
def pop_user_sites(conn)
	userSites = Hash.new
	conn.sites.each do |ss|
		siteDetail = Nexpose::Site.load(conn, ss.id)
		siteDetail.users.each do |su|
			if userSites.has_key?(su[:id])
				if !userSites[su[:id]].include?(ss.id)
					userSites[su[:id]].push(ss.id)
				end
			else
				# new user id
				# create placeholder array
				userSites[su[:id]] = Array.new
			end
		end
	end
	return userSites
end				
	
# returns an array of site names for the specified user
def get_user_sites(conn, userSites, userid)
	sitesArray = Array.new
	if userSites[userid].nil? or !userSites[userid].is_a?(Array)
		return sitesArray
	end
	userSites[userid].each do |sid|
		site = Nexpose::Site.load(conn, sid)
		if !sitesArray.include?(site.name)
			sitesArray.push(site.name)
		end
	end
	return sitesArray
end
	
default_host = 'is-vmcrbn-p01***REMOVED***'
#default_port = 3780
default_user = 'sv-nexposegem'
#default_site = 'localsite'
default_format = 'pdf'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login

at_exit { @nsc.logout }

userSites = pop_user_sites(@nsc)
#pp userSites
#exit 0

puts "ID,UserName,FullName,Email,AuthSource,IsAdmin,IsDisabled,IsLocked,SiteCount,Sites,GroupCount"
@nsc.list_users.each do |user|
	mySites = get_user_sites(@nsc, userSites, user.id)
	puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},\"#{mySites.inspect}\",#{user.group_count}"
end
