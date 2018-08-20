#!/usr/bin/env ruby

require 'pp'
require 'json'
require 'nexpose'
require 'rest-client'

user = 'sv-nexposegem'
passwd = 'Sempra01'

@nsc = Nexpose::Connection.new('is-vmcrbn-p01***REMOVED***', user, passwd)
@nsc.login

at_exit { @nsc.logout }

tit1 = "Adobe Flash Player: APSB15-32 (CVE-2015-8433): Security updates available for Adobe Flash Player"
tit2 = "TLS/SSL Server Supports 3DES Cipher Suite"

vulns = @nsc.find_vuln_check(tit1)

puts "Got #{vulns.size} vulns for title."
#pp vulns
puts "First VulnID: #{vulns[0].id}"

base_url  = 'https://is-vmcrbn-p01***REMOVED***:3780/api/3/'

url = "#{base_url}/vulnerability_checks/#{vulns[0].id}"
resp = RestClient::Request.execute(method: :get, url: url, user: user, password: passwd, :verify_ssl => OpenSSL::SSL::VERIFY_NONE)

JSON.parse(resp.body).each do |k,v|
	puts k
end
