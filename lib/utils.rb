#!/usr/bin/env ruby

require 'nexpose'
require 'colorize'
require 'pp'
require 'netaddr'
require 'resolv'

module Utils

	def self.get_mask(size)
		case size
		when 8388609..16777216 then
			return 8
		when 4194305..8388608 then
			return 9
		when 2097153..14194304 then
			return 10
		when 1048577..2097152 then
			return 11
		when 524289..1048576 then
			return 12
		when 262145..524288 then
			return 13
		when 131073..262144 then
			return 14
		when 65536..131072 then
			return 15
		when 32768..65536 then
			return 16
		when 16385..32768 then
			return 17
		when 8193..16384 then
			return 18
		when 4097..8192 then
			return 19
		when 2049..4096 then
			return 20
		when 1025..2048 then
			return 21
		when 513..1024 then
			return 22
		when 257..512 then
			return 23
		when 129..256 then
			return 24
		when 65..128 then
			return 25
		when 33..64 then
			return 26
		when 17..32 then
			return 27
		when 9..16 then
			return 28
		when 5..8 then
			return 29
		when 3..4 then
			return 30
		when 1..2 then
			return 31
		when 0 then
			return 32
		else
			raise ArgumentError, "Do not recognize this size: #{size}"
		end
	end

	@mbit_dict = {
		8388608 =>  9,
		8388607 =>  9,
		8388606 =>  9,
		8388604 =>  9,
		1048576 =>  12,
		1048575 =>  12,
		1048574 =>  12,
		1048573 =>  12,
		1048572 =>  12,
		524288  =>  13,
		524284  =>  13,
		262144  =>  14,
		262140  =>  14,
		65536   =>  16,
		65535   =>  16,
		65534   =>  16,
		65532   =>  16,
		16384   =>  18,
		16380   =>  18,
		8192    =>  19,
		8188    =>  19,
		6397    =>  19,
		5118    =>  19,
		4096    =>  20,
		2048    =>  21,
		2046    =>  21,
		2044    =>  21,
		1024    =>  22,
		1022    =>  22,
		1021    =>  22,
		1020    =>  22,
		766     =>  22,
		512     =>  23,
		511     =>  23,
		510     =>  23,
		509     =>  23,
		508     =>  23,
		255     =>  24,
		254     =>  24,
		253     =>  24,
		252     =>  24,
		250     =>  24,
		226     =>  24,
		211		=>	24,
		201     =>  24,
		184     =>  24,
		154     =>  24,
		149     =>  24,
		128     =>  25,
		126		=>	25,
		124     =>  25,
		123     =>  25,
		105     =>  25,
		97      =>  25,
		86      =>  25,
		83      =>  25,
		82      =>  25,
		65      =>  25,
		64      =>  25,
		60      =>  26,
		58      =>  26,
		42      =>  26,
		41      =>  26,
		38		=>	26,
		36      =>  26,
		35      =>  26,
		34      =>  26,
		33      =>  26,
		32      =>  27,
		31      =>  27,
		30      =>  27,
		29      =>  27,
		28      =>  27,
		27      =>  27,
		26      =>  27,
		25      =>  27,
		24      =>  27,
		23      =>  27,
		22      =>  27,
		21      =>  27,
		20      =>  27,
		19      =>  27,
		18      =>  27,
		17      =>  27,
		16      =>  28,
		15      =>  28,
		14      =>  28,
		13      =>  28,
		12      =>  28,
		11      =>  28,
		10      =>  28,
		9       =>  29,
		8       =>  29,
		7       =>  29,
		6       =>  29,
		5       =>  29,
		4       =>  30,
		3       =>  30,
		2       =>  31,
		1       =>  32,
		0       =>  32
	}

	def Utils.calc_mask(l,u)
		if l.nil? or u.nil?
			raise "calc_mask() expects a lower and upper ip"
		else
			laddr = NetAddr::IPv4.parse(l)
			uaddr = NetAddr::IPv4.parse(u)
			diff = uaddr.addr - laddr.addr
			#mask = NetAddr::Mask32.parse(self.get_mask(diff))
		end

		return NetAddr::Mask32.parse(self.get_mask(diff).to_s)
		#if @mbit_dict.include?(ipra.size)
		#	return @mbit_dict[ipra.size]
		#else
		#	raise "Bit size not in dictionary: #{ipra.size}".red
		#end
	end

	def Utils.hashize(cidr_ary)
		tmp = Hash.new
		cidr_ary.each do |c|
			tmp[c.to_s] = c
		end
		return tmp
	end

	def Utils.cidrize(ipaddr_ary)
		cidr_hsh = Hash.new
		ipaddr_ary.each do |ex|
			if ex.is_a?(Nexpose::IPRange)
				if ex.to.nil?
					lower = ex.from.to_s
					upper = ex.from.to_s
				else
					lower = ex.from.to_s
					upper = ex.to.to_s
				end
				bits = Utils.calc_mask(lower,upper)
				cidr = NetAddr::CIDR.create("#{ex.from}/#{bits}")
				cidr_hsh[cidr.to_s] = cidr unless cidr_hsh.has_key?(cidr.to_s)
			elsif ex.is_a?(NetAddr::CIDR)
				cidr_hsh[ex.to_s] = ex unless cidr_hsh.has_key?(ex.to_s)
			elsif ex.is_a?(Nexpose::HostName)
				# don't do anything
			else
				raise "Unexpected object class: #{ex.class}".red
			end
		end
		one = NetAddr.merge(cidr_hsh.values.sort, :Objectify => true)
		two = NetAddr.merge(one.sort, :Objectify => true)
		three = NetAddr.merge(two.sort, :Objectify => true)
		return Utils.hashize(three)
	end

	def Utils.sites2ids(conn)
		s2i = Hash.new
		ssums = conn.sites
		ssums.each do |s|
			s2i[s.name] = s.id unless s2i.has_key?(s.name)
		end
		return s2i
	end

	def Utils.get_cark_creds(config)
    pass = %x{ssh root@#{config['aimproxy']} '/opt/CARKaim/sdk/clipasswordsdk GetPassword -p AppDescs.AppID=#{config['appid']} -p "Query=safe=#{config['safe']};Folder=#{config['folder']};object=#{config['objectname']}" -o Password'}
    pass.chomp!
    #puts "|#{pass}|"
    return config['username'],pass
	end
end
