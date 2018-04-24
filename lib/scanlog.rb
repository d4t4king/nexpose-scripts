#!/usr/bin/env ruby

require 'pp'
require 'colorize'
require 'date'
require 'nexpose'

module ScanLog

end

class ScanLog::Entry
	attr_accessor :datetime
	attr_accessor :loglevel
	attr_accessor :thread
	attr_accessor :site
	attr_accessor :message
	attr_accessor :is_init_entry
	attr_accessor :is_multiline_entry

	def initialize(log_line)
		@is_init_entry = false

		parts = log_line.split(/ /)
		begin
			d = parts.shift
			#puts d.to_s.cyan
			@datetime = DateTime.parse(d)
		rescue ArgumentError => ae
			print "In ScanLog::Entry.initialize::ArgumentError: ".red
			print "#{ae.message} ".magenta
			#puts "|#{d}|".cyan
			pp parts
			exit 1
		end
		@loglevel = parts.shift.gsub(/[\[\]]/, "")
		str = parts.join(" ")
		parts = str.split(/[\[\]]/)
		parts.shift if parts[0].empty? or parts[0] =~ /^\s+$/
		@thread = parts.shift.gsub(/Thread: /, "").strip
		begin
			parts.shift if parts[0].empty? or parts[0] =~ /^\s+$/
		rescue NoMethodError => nme
			print "In ScanLog::Entry.initialize::NoMethodError: ".red
			pp parts
			exit 1
		end
		site = parts.shift
		if site == "Logging initialized."
			# initialization entry
			@is_init_entry = true
		else
			@site = site.gsub(/Site:/, "").strip
		end
		#parts.shift if parts[0].empty? or parts[0] =~ /^\s+$/
		@message = parts.join(" ").strip
	end

	alias new initialize

	def to_s
		return ":datetime => #{@datetime.to_s}, :loglevel => #{@loglevel}, :thread => #{@thread}, :site => #{@site}, :message => #{@message}"
	end

	alias to_string to_s
end

class ScanLog::Log
	attr_accessor :first_entry_date
	attr_accessor :last_antry_date
	attr_accessor :scan_engine
	attr_accessor :protocol_helpers
	attr_accessor :threads
	attr_accessor :sites
	attr_accessor :targets
	attr_accessor :unresolved
	attr_accessor :dead_targets
	attr_accessor :entries
	attr_accessor :errors
	attr_accessor :error_types
	attr_accessor :exclusions

	def dead_target_count
		return @dead_targets.size
	end

	def unresolved_count
		return @unresolved.size
	end

	def target_count
		return @targets.size
	end

	def entry_count
		return @entries.size
	end

	def thread_count
		return @threads.keys.size
	end

	def site_count
		return @sites.keys.size
	end

	def error_count
		return @errors.size
	end

	def initialize(file)
		@threads = Hash.new
		@sites = Hash.new
		@errors = Array.new
		@error_types = Hash.new
		@entries = Array.new
		@protocol_helpers = Array.new
		@targets = Array.new
		@unresolved = Array.new
		@dead_targets = Array.new
		@exclusions = Array.new
		multiline = false
		line_count = 0
		
		errstr = ''
		in_error = false
		sb = ''
		File.open(file, 'r').each_line do |line|
			line.chomp!
			line.delete!("\C-M")
			line.delete!("\C-@")
			line_count += 1
			# com.rapid7.plugin.vulnck.TestException
			# com.rapid7.plugin.vulnck.TestException
			# com.rapid7.net.cifs.CifsException
			if line =~ /\Acom\.rapid7\.(?:plugin\.vulnck\.TestException|net\.cifs\.CifsException)/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\Acom\.jcraft\.jsch\.JSchException/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\Acom\.rapid7\.net\.NetException/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\Aorg\.snmp4j\.MessageException\:/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\AJess reported an error/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\Ajavax.net.ssl/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\A(?:Caused\s*by:\s*)?java\./
				puts "matched \"Caused by: java\"....".green.bold
				in_error = true
				puts "in_error: #{in_error}".green.bold
				errstr = line + "\n"
				if line =~ /\A(?:Caused\s*by:\s*)?java\.(?:util|net|lang|io)\.(.+):?\s*(.*)/
					exc = $1 
					print "Captured exception: "
					puts "#{exc}".magenta.bold
					msg = $2
					exc_str = ""
					case exc
					when /(?:concurrent|IO|Execution|Connect|SocketTimeout|Interrupted)Exception/
						exc_str = "#{exc}[#{msg}]"
					else
						exc_str = exc
					end
					if @error_types[exc_str].nil?
						@error_types[exc_str] = 1
					else
						@error_types[exc_str] += 1
					end
				# java.nio.channels.WritePendingException
				# this SHOULD NOT match here, but it is for some strange reason.
				# so throw it out
				elsif line =~ /\Ajava\.nio\.channels\.(?:Read|Write)PendingException/
					next
				elsif line =~ /\Ajava\.nio\.channels\.(?:UnresolvedAddress|ClosedByInterrupt)Exception/
					next
				elsif line =~ /java\.nio\.channels\.(?:SocketChannel|spi.AbstractInterruptibleChannel)/
					next
				elsif line =~ /\Ajava\.(?:net|lang|io)\.(.*?)$/
					exc = $1 
					if @error_types[exc].nil?
						@error_types[exc] = 1
					else
						@error_types[exc] += 1
					end
				else 
					raise "Line didn't match error regex: #{line}".red.bold
				end
				next
			end
			if line =~ /\A\s+while executing/
				in_error = true
				errstr = line + "\n"
				next
			end
			if line =~ /\,$/
				multiline = true
			end

			if multiline
				if line =~ /^\s*$/ or line =~ /^\s+\.\.\.\s*\d\d?\smore/
					multiline = false
					line = sb.to_s.chomp.strip
				else
					sb += " #{line}"
					next
				end
			end	
			if in_error 
				case line 
				when /^\s+Message: \w+/
					errstr += line + "\n"
					next
				when /^Caused by: /
					errstr += line + "\n"
					next
				when /^\s+at /
					errstr += line + "\n"
					next
				when /^\s*\.\.\.\s+\d+ more/
					errstr += line + "\n"
					next
				else
					in_error = false
					@errors.push(errstr)
					errstr = ""
				end
			end

			next if line =~ /backdoor-CVE-2015-7755-check/
			next if line =~ /[Pp]assword\:?/
			# (none) login:
			next if line =~ /\(none\)\s*login\:/
			next if line =~ /^(?:[Ll]ogin|diag|manuf|db2(?:as|fenc1|inst1)|admin|root|guest|[Uu]ser|[Cc]isco|\%|enable)/
			next if line =~ /^(pix|netrangr|SUNRTR|FreeBSD\/amd64)/
			next if line =~ /^\|/
			next if line =~ /\+\-+\+/
			#    03 00 00 0B 06 E0 00 00  00 00 00                   ...........
			next if line =~ /^\s+(?:[0-9a-zA-F]{2}\s)+.*/
			# skip empty lines
			next if line =~ /^\s*$/

			# if we've gotten here, and the line doesn't start with
			# something that looks like a date, just throw it out for now.
			next if line !~ /\A[0-9T:-]+/

			e = ScanLog::Entry.new(line)

			if @threads.include?(e.thread)
				@threads[e.thread].push(e)
			else
				@threads[e.thread] = Array.new 
				@threads[e.thread].push(e)
			end

			if @sites.include?(e.site)
				@sites[e.site].push(e)
			else
				@sites[e.site] = Array.new
				@sites[e.site].push(e)
			end

			@entries << e

			case e.message
			when /Loaded protocol helper: (.+)/
				pa = $1
				@protocol_helpers.push(pa.strip)
			when /^(.*)\s+ALIVE/
				targ = $1
				@targets.push(targ)
			when /^(.*)\s+DEAD/
				dead = $1
				@dead_targets.push(dead)
			when /Unable to determine IP address for target: (.+)/
				unres = $1
				@unresolved.push(unres)
			when /Excluding (?:address range|named host): (.*)/
				ex = $1
				if ex =~ /((?:\d+\.){3}\d+)\s*\-\s*((?:\d+\.){3}\d+)/
					lower = $1
					upper = $2
					nipr = Nexpose::IPRange.new(lower,upper)
					@exclusions.push(nipr)
				elsif ex =~ /^[AaCc][CcFfGgHh]\d{5,6}(?:\.sempra\.com)?/
					hn = Nexpose::HostName.new(ex)
					@exclusions.push(hn)
				else
					@exclusions.push(ex)
				end
			end
		end
	end

	alias new initialize
end
