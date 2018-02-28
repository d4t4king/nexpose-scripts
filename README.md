# nexspose-scripts
[![Code Climate](https://codeclimate.com/github/d4t4king/nexpose-scripts/badges/gpa.svg)](https://codeclimate.com/github/d4t4king/nexpose-scripts)

Collection of script to interact with the Nexpose console using the Ruby gem and the nexpose API

*** analyze_average_scan_time.rb
	Calculate the average scan time for each scan (site).

*** audit-users.rb
	Utility to show, mail and delete users who have never logged into the console, or have not logged in in a very long time.

*** dump_site_exclusions.rb
	Dumps the excluded_targets for each site.

*** get-report.rb
	Get a report.

*** get-sites-for-ip.rb
	Gets the sites for a given IP.

*** get-weekly-reports.rb
	Get the weekly reports.

*** list-report-templates.rb
	List the report templates in the console.  (Usefule for generating programmatic report data or consigs.)

*** list_scan_templates.rb
	List the scan templates in the console.  (Useful for generating programmatic scan data or configs.)

*** move_site_excl_to_global.rb
	Move site-specific exclusions to Global Settings as global exclusions.

*** push-to-scap.rb
	Push scan data to report and run SCAP-compat XML report.

*** reconcile_global_exclusions.rb
	Make sure the global exclusions seem "sane".

*** scan-coverage.rb
	Roll up target ranges and merge into largest CIDRs.

*** scan_history_dump.rb
	Dump the scan history.
