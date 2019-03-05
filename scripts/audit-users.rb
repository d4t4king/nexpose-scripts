#!/usr/bin/env ruby

require "pp"
require 'csv'
require 'mail'
require "nexpose"
require "colorize"
require "getoptlong"
require "highline/import"

require_relative '../lib/utils'

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

def pop_user_last_logons(conn)
	userLastLogons = Hash.new
	myTable = Nexpose::DataTable._get_dyn_table(conn, "/data/admin/users?tableID=UserAdminSynopsis")
	myTable.each do |row|
		#puts "#{row["User ID"]},#{row["Last Logon"]}"
		userLastLogons[row["User ID"].to_i] = row["Last Logon"].to_i
	end
	return userLastLogons
end

def pop_site_ids2names(conn)
	ids2names = Hash.new
	conn.sites.each do |ss|
		if !ids2names.include?(ss.id)
			ids2names[ss.id] = ss.name
		end
	end
	return ids2names
end

def usage
	puts <<-END

#{$0} -h -c <config> -a <action> -o <output file>

Where:
-h|--help				Displayes this message then exits.
-H|--host				Nexpose console to connect to.
-c|--config			Specifies the config file for CyberARK in JSON format.
-a|--action			The action to take.
-o|--output			File to dave output to.

END
	exit 0
end

default_host = "is-vmcrbn-p01.example.com"
default_user = "sv-nexposegem"
default_format = "pdf"
default_action = "show"
default_file = "/tmp/nexpose_export.csv"

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--host', '-H', GetoptLong::REQUIRED_ARGUMENT ],
	['--config', '-c', GetoptLong::REQUIRED_ARGUMENT ],
	['--action', '-a', GetoptLong::REQUIRED_ARGUMENT ],
	['--output', '-o', GetoptLong::REQUIRED_ARGUMENT ],
)

@help = false
@config = nil
conffile = nil
@action = nil
@output = nil
@host = nil

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--host'
		@host = arg
	when '--config'
		conffile = arg
	when '--action'
		@action = arg
	when '--output'
		@output = arg
	else
		raise ArgumentError "Unrecognized argument: #{opt}"
	end
end

usage if @help
usage if @action.nil?
usage if @host.nil?

if conffile.nil?
	@host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
	@user = ask("Enter your username to log on: ") { |q| q.default = default_user }
	@pass = ask("Enter your password: ") { |q| q.echo = "*" }
	@action = ask("Specify an action: (show|show_stale|export|mail|disable)") { |q| q.default = default_action }
	@file = ""
	if action == "export"
		@file = ask("Enter the path to the export file: ") { |q| q.default = default_file }
	end
else
	fileraw = File.read(conffile)
	@config = JSON.parse(fileraw)
	@user,@pass = Utils.get_cark_creds(@config)
end

@nsc = Nexpose::Connection.new(@host, @user, @pass)
@nsc.login

at_exit { @nsc.logout }

userSites = ''
site_ids2names = Hash.new
if @action == "show"
	print "Getting the sites for each user....."
	userSites = pop_user_sites(@nsc)
	puts "done.".green
	print "Mapping site IDs to names....."
	site_ids2names = pop_site_ids2names(@nsc)
	puts "done.".green
end

print "Mapping last logon date to user IDs....."
id2logon = pop_user_last_logons(@nsc)
puts "done".green

myNow = DateTime.now

case @action
when "show_stale"
	puts "ID,UserName,FullName,Email,AuthSource,IsAdmin,IsDisabled,IsLocked,SiteCount,GroupCount,LastLogon"
	@nsc.list_users.each do |user|
		# skip local, administrative only accounts
		next if user.name =~ /\.local/
		# skip nxadmin
		next if user.name == "nxadmin"
		# skip accounts already disabled
		next if user.is_disabled == true
		# mySites = get_user_sites(@nsc, userSites, user.id)
		if id2logon[user.id] == 0
			puts "Warning! User (#{user.name}) has never logged in!".red.bold
			puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},0".cyan
		else
			dt = DateTime.strptime(id2logon[user.id].to_s[0...-3], "%s")
			dt = dt.new_offset("-08:00")
			#puts "dt is a #{dt.class}"
			if (myNow - dt).to_i >= 365
				puts "User (#{user.name}) hasn't logged in 1 year or longer!".yellow.bold
				puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},#{dt}".cyan
			end
		end
	end
when "show"
	puts "ID,UserName,FullName,Email,AuthSource,IsAdmin,IsDisabled,IsLocked,SiteCount,GroupCount,LastLogon"
	@nsc.list_users.each do |user|
		# skip local, administrative only accounts
		next if user.name =~ /\.local/
		# skip nxadmin
		next if user.name == "nxadmin"
		# skip accounts already disabled
		next if user.is_disabled == true
		# mySites = get_user_sites(@nsc, userSites, user.id)
		if id2logon[user.id] == 0
			puts "Warning! User (#{user.name}) has never logged in!".red.bold
			puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},0".cyan
			if !userSites[user.id].nil?
				print "User sites for #{user.name}: "
				userSites[user.id].each do |sid|
					# some  users (Global Administrator) have access to ALL sites, so none are listed
					next if sid.nil?
					print "#{site_ids2names[sid]},"
				end
				puts
			end
		else
			dt = DateTime.strptime(id2logon[user.id].to_s[0...-3], "%s")
			dt = dt.new_offset("-08:00")
			#puts "dt is a #{dt.class}"
			if (myNow - dt).to_i >= 180
				puts "User (#{user.name}) hasn't logged in 180 days or longer!".yellow.bold
			end
			puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},#{dt}".cyan
			if !userSites[user.id].nil?
				print "User sites for #{user.name}: "
				userSites[user.id].each do |sid|
					# some  users (Global Administrator) have access to ALL sites, so none are listed
					next if sid.nil?
					print "#{site_ids2names[sid]},"
				end
				puts
			end
		end
	end
when "mail"
	@nsc.list_users.each do |u|
		# skip local, administrative only accounts
		next if u.name =~ /\.local/
		# skip service accounts (?)
		next if u.name =~ /^sv-/
		# skip nxadmin
		next if u.name == "nxadmin"
		# skip accounts already disabled
		next if u.is_disabled == true

		Mail.defaults do
			delivery_method :smtp, host: "smtp.example.com", address: "smtp.example.com", openssl_verify_mode: OpenSSL::SSL::VERIFY_NONE, verify: false
		end

		if id2logon[u.id] == 0
			mail = Mail.new do
				from		"tvm-no-reply@example.com"
				to			u.email
				#to			"cheselton@example.com"
				cc			"cheselton@example.com"
				subject		"Account Never Logged In"
				body		<<~HERE
					You have an account (#{u.name}) on the Enterprise Rapid7 Nexpose console
					on #{@host} and have never logged in.  If you
					intend to use this account please log in within the next 30 days.
					Otherwise, your account will be disabled.

					If you require access and are having trouble accessing your account,
					please contact Charlie Heselton as soon as possible for assistance.

					Thank you,
					Threat and Vulnerability Management
							HERE
			end
		else
			dt = DateTime.strptime(id2logon[u.id].to_s[0...-3], "%s")
			dt = dt.new_offset("-08:00")
			if (myNow - dt).to_i >= 365
				mail = Mail.new do
					from		"tvm-no-reply@example.com"
					to			u.email
					#to			"cheselton@example.com"
					cc			"cheselton@example.com"
					subject		"Account Not Logged In Last Calendar Year"
					body		<<~HERE
						You have an account (#{u.name}) on the Enterprise Rapid7 Nexpose console
						on #{@host} and have not logged in within the last calendar year.
						If you intend to use this account, please log in within
						the next 30 days.  Otherwise, your account will be disabled.

						If you require access and are having trouble accessing your account,
						please contact Charlie Heselton as soon as possible for assistance.

						Thank you,
						Threat and Vulnerability Management
								HERE
				end
			end
		end
		if mail.nil? == false
			puts "=" * 72
			if mail.subject =~ /last calendar/i
				puts mail.to_s.light_yellow
			else
				puts mail.to_s.red
			end
			mail.deliver
		end
	end
when "disable"
	# Note: This option does not work.  For some reason there is an error when
	# trying to #save the user object after changing the enabled attribute.
	@nsc.list_users.each do |user|
		# skip local, administrative only accounts
		next if user.name =~ /\.local/
		# skip nxadmin
		next if user.name == "nxadmin"
		# skip accounts already disabled
		next if user.is_disabled == true
		# mySites = get_user_sites(@nsc, userSites, user.id)
		if id2logon[user.id] == 0
			puts "Warning! User (#{user.name}) has never logged in!".red.bold
			puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},0".cyan
			print "Disabling user....".red.bold
			uo = Nexpose::User.load(@nsc, user.id)
			uo.enabled = 0
			uo.save(@nsc)
			puts "done.".red.bold
		else
			dt = DateTime.strptime(id2logon[user.id].to_s[0...-3], "%s")
			dt = dt.new_offset("-08:00")
			#puts "dt is a #{dt.class}"
			if (myNow - dt).to_i >= 365
				puts "User (#{user.name}) hasn't logged in 1 year or longer!".yellow.bold
				puts "#{user.id},#{user.name},\"#{user.full_name}\",#{user.email},#{user.auth_source},#{user.is_admin},#{user.is_disabled},#{user.is_locked},#{user.site_count},#{user.group_count},#{dt}".cyan
				print "Disabling user.....".red.bold
				uo = Nexpose::User.load(@nsc, user.id)
				uo.enabled = 0
				uo.save(@nsc)
				puts "done.".red.bold
			end
		end
	end
when "export"
	CSV.open(file, "wb") do |csv|
		csv << %w(ID UserName FullName Email AuthSource IsAdmin IsDisabled IsLocked SiteCount GroupCount LastLogon)
		@nsc.list_users.each do |user|
			if id2logon[user.id] == 0
				csv << [user.id, user.name, "#{user.full_name}", user.email, user.auth_source, user.is_admin, user.is_disabled, user.is_locked, user.site_count, user.group_count, 0]
			else
				dt = DateTime.strptime(id2logon[user.id].to_s[0...-3], "%s")
				dt = dt.new_offset("-08:00")
				csv << [user.id, user.name, "#{user.full_name}", user.email, user.auth_source, user.is_admin, user.is_disabled, user.is_locked, user.site_count, user.group_count, dt]
			end
		end
	end
else
	raise "Unrecognized action! (#{@action})".red
end
