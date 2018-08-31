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
#{0} -h -H 'hostname' -f 'format' -v <vuln_list> -c <conffile>

Where:
-h|--help				Display this message and exit.
-H|--host			The Nexpose console to log into and manage
-c|--config			The JSON config file for CyberARK
-f|--format			Format for output; defaults to PDF
-v|--vuln_list	List of vulnerabilities to upload.

END
	exit 0
end

default_host = 'localhost'
default_user = 'nxadmin'
default_format = 'pdf'
default_vuln_list = '/tmp/vuln.list'

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT],
	['--host', '-H', GetoptLong::REQUIRED_ARGUMENT],
	['--config', '-c', GetoptLong::REQUIRED_ARGUMENT],
	['--format', '-f', GetoptLong::REQUIRED_ARGUMENT],
	['--vuln_list', '-v', GetoptLong::REQUIRED_ARGUMENT],
)

@host = nil
@help = false
@vulns_file = nil
@format = 'pdf'
@config = nil
conffile = nil

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--host'
		@host = arg
	when '--config'
		conffile = arg
	when '--format'
		@format = arg
	when '--vuln_list'
		@vulns_file = arg
	else
		raise "Unrecognized argument: #{opt}"
	end
end

usage if @help
usage if @host.nil?
usage if @vulns_file.nil?

if conffile.nil?
	@host = ask("Enter the server name (host) for Nexpose: ") { |q| q.default = default_host }
	@user = ask("Enter your username to log on: ") { |q| q.default = default_user }
	@pass = ask("Enter your password: ") { |q| q.echo = "*" }
	@vulns_file = ask("Enter the filename that contains the list of vulns to process: ") { |q| q.default = default_vuln_list }
else
	fileraw = File.read(conffile)
	@config = JSON.parse(fileraw)
	@user,@pass = Utils.get_cark_creds(@config)
end

@nsc = Nexpose::Connection.new(@host, @user, @pass)
@nsc.login
at_exit { @nsc.logout }

vulns = Array.new

f = File.open(@vulns_file)
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
	#vobj = @nsc.find_vulns_by_title(vt, true)
	vobj = @nsc.find_vuln_check(vt, false, true)
	#pp vobj
	if vobj.is_a?(Array)
		puts "Found #{vobj.size} checks partially matching #{vt}"
	#	if vobj.size <= 5
	#		pp vobj
	#	end
	end

	#exit 1
	if vobj.is_a?(Array)
		#pp vobj
		#exit 1
		vobj.each do |v|
			if !vuln_ids.include?(v.check_id)
				vuln_ids << v.check_id
			end
		end
	else
		if !vuln_ids.include?(vobj.check_id)
			vuln_ids << vobj.check_id
		end
	end
end

#pp vuln_ids

egrc_templ_id = nil
@nsc.scan_templates.each do |st|
	if st.name == 'Archer_Imported_Vulns'
		puts "ID: #{st.id} Name: #{st.name}"
		egrc_templ_id = st.id
		break
	end
end

puts "#{vuln_ids.uniq.size} total vulns selected for addition to scan template."

### create the scan template with the desired vuln checks.
template = Nexpose::ScanTemplate.load(@nsc, egrc_templ_id)
vuln_ids.uniq.each do |vuln|
	puts vuln.to_s.magenta
	template.enable_vuln_check(vuln)
end
#template.web_spidering = false
#template.policy_scanning = false
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

exit 0

=begin
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
=end
