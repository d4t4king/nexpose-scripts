#!/usr/bin/env ruby

require 'pp'
require 'nexpose'
require 'colorize'
require 'highline/import'

default_host = 'is-vmcrbn-p01***REMOVED***'
#default_port = 3780
default_user = 'ad-cheselto'
default_format = 'pdf'
default_host_list = '/tmp/host.list'
default_vuln_list = '/tmp/vuln.list'

host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
user = ask("Enter your username to log on: ") { |q| q.default = default_user }
pass = ask("Enter your password: ") { |q| q.echo = "*" }
hosts_file = ask("Enter the filename that contains the list of hosts to scan: ") { |q| q.default = default_host_list }
vulns_file = ask("Enter the filename that contains the list of vulns to process: ") { |q| q.default = default_vuln_list }

@nsc = Nexpose::Connection.new(host, user, pass)
@nsc.login
at_exit { @nsc.logout }

hosts = Array.new
vulns = Array.new

f = File.open(hosts_file)
f.each_line do |line|
	line.chomp!
	if !hosts.include?(line)
		hosts << line
	end
end
f.close
f = File.open(vulns_file)
f.each_line do |line|
	line.chomp!
	if !vulns.include?(line)
		vulns << line
	end
end

### populate the list of vulns for this run with the vuln-ids that Nexpose recognizes
vuln_ids = Array.new
vulns.each do |vt|
	puts "Title: #{vt}".green
	vobj = @nsc.find_vulns_by_title(vt, true)
	if vobj.is_a?(Array)
		#pp vobj
		#exit 1
		vobj.each do |v|
			if !vuln_ids.include?(v.id)
				vuln_ids << v.id
			end
		end
	else
		if !vuln_ids.include?(vobj.id)
			vuln_ids << vobj.id
		end
	end
end

pp vuln_ids

names = Array.new
@nsc.scan_templates.each do |st|
	puts "ID: #{st.id} Name: #{st.name}"
	if !names.include?(st.name)
		names << st.name
	end
end

### create the scan template with the desired vuln checks.
template = Nexpose::ScanTemplate.load(@nsc)
#if names.include?("archer_filtered_scan_test")
	salt = 1 + rand(99999)
#	puts "Default scan name exists. Using salt #{salt}"
	template.name = "archer_filtered_scan_test_#{salt}"
#else 
#	template.name = "archer_filtered_scan_test"
#end
template.description = "Vulnerability scan for specific vulns and hosts for import into Archer"
vuln_ids.uniq.each do |vuln|
	puts vuln.to_s.magenta
	template.enable_vuln_check(vuln)
end
template.web_spidering = false
template.policy_scanning = false
begin
	template.save(@nsc)
rescue Exception => e
	#puts "Error Message: #{e.message}".red
	#puts e.inspect.yellow
	if e.message =~ /NexposeAPI\: POST request to \/data\/scan\/templates failed\. request body\:/
		puts "There a ghost in the shell.....maybe that scan name already exists."
	else
		raise e
	end
end

puts template.name
site_obj = Nexpose::Site.new("charlie_archer_import_#{salt}", template.name)
site_obj.description = "scan to process filtered results from another scan"
hosts.each do |host|
	site_obj.include_asset(host)
end
site_obj.save(@nsc)
scan_data = site_obj.scan(@nsc)
pp scan_data.to_s.blue
begin
	status = @nsc.scan_status(scan_data.id)
	print "."
	sleep(1)
end while status == Nexpose::Scan::Status::RUNNING or status == "integrating"
puts "done"

adhoc = Nexpose::AdhocReportConfig.new('audit-report', 'xml', site_obj.id)
adhoc.add_filter('scan', scan_data.id)
print "Generating XML report..."
data = adhoc.generate(@nsc)
File.open("/tmp/site-#{site_obj.id}-scan-#{scan_data.id}-scap.xml", 'w') { |f| f.write(data) }
puts "done."
puts "Your report has been saved to /tmp/site-#{site_obj.id}-scan-#{scan_data.id}-scap.xml"

