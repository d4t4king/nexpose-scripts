#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'date'
require 'getoptlong'

require_relative 'scanlog'

def usage
	puts <<-END

#{$0} -hv -i <input_file>

Where:
--help|-h			Displays this message then exists.
--verbose|-v		Displays more output.
--input|-i			Specifies the full path to the input file.

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
@input = ''

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

puts "Got #{@input} as the input file." if @verbose

scan_log = ScanLog::Log.new(@input)

if @verbose
	scan_log.entries.each do |e|
		next if e.message =~ /Loaded protocol helper:/
		next if e.message =~ /^(.*)\s+ALIVE/
		next if e.message =~ /^(.*)\s+DEAD/
		next if e.message =~ /Unable to determine IP address for target: (.+)/
		next if e.message =~ /Excluding (?:address range|named host): (.*)/
		puts e.message.to_s
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
