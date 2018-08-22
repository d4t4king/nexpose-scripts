#!/usr/bin/env ruby

require 'pp'
require 'date'
require 'colorize'
require 'getoptlong'

require_relative '../lib/scanlog'

def usage
	puts <<-END

#{$0} -hv -i <input_file>

Where:
--help|-h			Displays this message then exists.
--verbose|-v		Displays more output.
--input|-i			Specifies the full path to the input file.

end

END
	exit 0
end

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--verbose', '-v', GetoptLong::NO_ARGUMENT ],
	['--input', '-i', GetoptLong::REQUIRED_ARGUMENT ],
)

@help = false
@verbose = false
@input = nil

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--verbose'
		@verbose = true
	when '--input'
		@input = arg
	else
		Raise ArgumentError "Unrecognized argument. (#{opt})"
	end
end

usage if @help

print "Verbose is "
if @verbose
	puts "on."
else
	puts "off."
end

if @input.nil?
	usage
	raise "You must specify a scan log to process.".red
end

puts "Got #{@input} as the input file." if @verbose

scan_log = ScanLog::Log.new(@input)

if @verbose
	scan_log.entries.each do |e|
		next if e.message =~ /Loaded protocol helper:/
		next if e.message =~ /^(.*)\s+ALIVE/
		next if e.message =~ /^(.*)\s+DEAD/
		next if e.message =~ /Unable to determine IP address for target: (.+)/
		next if e.message =~ /Excluding (?:address range|named host): (.*)/
		puts e.message.to_s.red.bold
	end
end

puts "#{scan_log.entry_count} entries."
puts "#{scan_log.thread_count} threads."
puts "#{scan_log.site_count} sites."
scan_log.sites.keys.each do |k|
	puts "\t#{k}"
end
puts "#{scan_log.protocol_helpers.size} protocol helpers."
puts "#{scan_log.error_count} errors."
pp scan_log.error_types
puts "#{scan_log.target_count} targets."
puts "#{scan_log.unresolved_count} unresolved names."
puts "#{scan_log.dead_target_count} dead targets."
puts "#{scan_log.exclusions.size} exclusions."

asset_creds = Hash.new
creds_success = Hash.new
creds_success["false"] = 0
creds_success["true"] = 0
scan_log.entries.each do |entry|
	if entry.message =~ /Administrative credentials/
		if entry.message =~ /(.+):445\/tcp\s+Administrative credentials failed \(access denied\)./
			asset = $1
			asset_creds[asset] = false
			creds_success["false"] += 1
		elsif entry.message =~ /(.+):139\/tcp\s+/
			# We don't care about 139 right now.  Just count the 445 connection attempts.
			next
		else
			puts "\t#{entry.message}"
		end
	end
end

puts "Total: #{asset_creds.keys.size} Success: #{creds_success["true"]} Fail: #{creds_success["false"]}"
puts "Percent success: #{(creds_success["true"] % asset_creds.keys.size)}%"
