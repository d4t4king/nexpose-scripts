#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'date'
require 'getoptlong'

require_relative '../lib/scanlog'

def usage
	puts <<-END

#{$0} -hv -i <input_file>

Where:
--help|-h			Displays this message then exists.
--verbose|-v		Displays more output.
--input|-i			Specifies the full path to the input file.
--lookup|-l			Specify the IP to look up

END
	exit 0
end

opts = GetoptLong.new(
	['--help', '-h', GetoptLong::NO_ARGUMENT ],
	['--verbose', '-v', GetoptLong::NO_ARGUMENT ],
	['--input', '-i', GetoptLong::REQUIRED_ARGUMENT ],
	['--lookup', '-l', GetoptLong::REQUIRED_ARGUMENT ],
)

@help = false
@verbose = false
@input = ''
@lookup = ''

opts.each do |opt,arg|
	case opt
	when '--help'
		@help = true
	when '--verbose'
		@verbose = true
	when '--input'
		@input = arg
	when '--lookup'
		@lookup = arg
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

if @lookup.nil?
	usage
	raise "You must specify an IP to lookup.".red
end

puts "Got #{@input} as the input file." if @verbose
puts "Got #{@lookup} as the IP to look up." if @verbose

print "Objectifying the log file...." if @verbose
scan_log = ScanLog::Log.new(@input)
puts "done." if @verbose

if @verbose
	puts "Processed #{scan_log.entry_count} entries."
	puts "#{scan_log.target_count} targets."
	puts "#{scan_log.unresolved_count} unresolved names."
	puts "#{scan_log.dead_target_count} dead targets."
	puts "#{scan_log.exclusions.size} exclusions."
end

scan_log.entries.each do |e|
	if e.message =~ /#{@lookup}/
		puts e.to_s
	end
end
