#!/usr/bin/perl -w
###############################################################################
# $Id$
###############################################################################
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
###############################################################################

=head1 NAME

VCL::utils

=head1 SYNOPSIS

 use VCL::utils;

=head1 DESCRIPTION

 This module contains general VCL utility subroutines.

=cut

##############################################################################
package VCL::utils;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use Mail::Mailer;
use Shell qw(mkdir);
use File::Find;
use Time::Local;
use DBI;
use DBI::Const::GetInfoType;
use diagnostics;
use Net::Ping;
use Fcntl qw(:DEFAULT :flock);
use FindBin;
use Getopt::Long;
use Carp;
use Text::Wrap;
use English;
use List::Util qw(min max);
use HTTP::Headers;
use RPC::XML::Client;
use Scalar::Util 'blessed';
use Data::Dumper;
use Cwd;
use Sys::Hostname;
use XML::Simple;
use Time::HiRes qw(gettimeofday tv_interval);
use Crypt::OpenSSL::RSA;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
  _pingnode
  check_blockrequest_time
  check_endtimenotice_interval
  check_ssh
  check_time
  clearfromblockrequest
  clear_next_image_id
  convert_to_datetime
  convert_to_epoch_seconds
  create_management_node_directory
  database_execute
  database_select
  delete_computerloadlog_reservation
  delete_request
  escape_file_path
  format_data
  format_hash_keys
  format_number
  get_affiliation_info
  get_block_request_image_info
  get_caller_trace
  get_calling_subroutine
  get_computer_current_state_name
  get_computer_grp_members
  get_computer_ids
  get_computer_info
  get_computers_controlled_by_mn
  get_connect_method_info
  get_copy_speed_info_string
  get_current_file_name
  get_current_package_name
  get_current_subroutine_name
  get_database_table_columns
  get_file_size_info_string
  get_group_name
  get_image_info
  get_imagemeta_info
  get_imagerevision_info
  get_current_image_contents_noDS
  get_current_reservation_lastcheck
  get_local_user_info
  get_management_node_blockrequests
  get_management_node_computer_ids
  get_management_node_vmhost_info
  get_management_node_id
  get_management_node_info
  get_management_node_requests
  get_management_predictive_info
  get_module_info
  get_next_image_default
  get_os_info
  get_production_imagerevision_info
  get_random_mac_address
  get_request_by_computerid
  get_request_current_state_name
  get_request_end
  get_request_info
  get_request_loadstate_names
  get_reservation_accounts
  get_resource_groups
  get_managable_resource_groups
  get_user_info
  get_vmhost_assigned_vm_info
  get_vmhost_info
  getnewdbh
  getpw
  getusergroupmembers
  get_user_group_member_info
  hash_to_xml_string
  help
  insert_reload_request
  insert_request
  insertloadlog
  is_ip_assigned_query
  is_management_node_process_running
  is_inblockrequest
  is_public_ip_address
  is_request_deleted
  is_request_imaging
  is_valid_dns_host_name
  is_valid_ip_address
  kill_child_processes
  kill_reservation_process
  known_hosts
  mail
  makedatestring
  nmap_port
  normalize_file_path
  notify
  notify_via_IM
  notify_via_msg
  notify_via_wall
  notify_via_oascript
  parent_directory_path
  preplogfile
  read_file_to_array
  rename_vcld_process
  reservation_being_processed
  round
  run_command
  run_scp_command
  run_ssh_command
  set_hash_process_id
  set_logfile_path
  set_managementnode_state
  setnextimage
  setup_confirm
  setup_get_array_choice
  setup_get_hash_choice
  setup_get_input_string
  setup_print_wrap
  sleep_uninterrupted
  sort_by_file_name
  stopwatch
  string_to_ascii
  switch_state
  switch_vmhost_id
  update_blockrequest_processing
  update_cluster_info
  update_computer_address
  update_computer_state
  update_computer_lastcheck
  update_computer_procnumber
  update_computer_procspeed
  update_computer_ram
  update_currentimage
  update_computer_imagename
  update_image_name
  update_image_type
  update_lastcheckin
  update_log_ending
  update_log_loaded_time
  update_preload_flag
  update_request_password
  update_request_state
  update_reservation_accounts
  update_reservation_lastcheck
  update_sublog_ipaddress
  write_currentimage_txt
  xmlrpc_call
  xml_string_to_hash
  add_imageid_to_newimages

  $CONF_FILE_PATH
  $DAEMON_MODE
  $DATABASE
  $DEFAULTHELPEMAIL
  $FQDN
  $LOGFILE
  $MYSQL_SSL
  $MYSQL_SSL_CERT
  $PIDFILE
  $PROCESSNAME
  $WINDOWS_ROOT_PASSWORD
  $SERVER
  $SETUP_MODE
  $TOOLS
  $VERBOSE
  $WRTPASS
  $WRTUSER
  $XMLRPC_USER
  $XMLRPC_PASS
  $XMLRPC_URL
  %ERRORS
  %OPTIONS

);

our %ERRORS = (
	'OK' => 0,
	'WARNING' => 1,
	'CRITICAL' => 2,
	'UNKNOWN' => 3,
	'DEPENDENT' => 4,
	'MAILMASTERS' => 5,
	'DEBUG' => 6
);

our $PROCESSNAME;
our $LOGFILE;
our $PIDFILE;
our $FQDN;

our $SERVER;
our $DATABASE;
our $WRTUSER;
our $WRTPASS;
our $MYSQL_SSL;
our $MYSQL_SSL_CERT;

our $JABBER;
our $JABBER_SERVER;
our $JABBER_USER;
our $JABBER_PASSWORD;
our $JABBER_RESOURCE;
our $JABBER_PORT;

our $DEFAULTHELPEMAIL;
our $RETURNPATH;

our $WINDOWS_ROOT_PASSWORD;

our $XMLRPC_USER;
our $XMLRPC_PASS;
our $XMLRPC_URL;

our $BIN_PATH = $FindBin::Bin;
our $TOOLS = "$FindBin::Bin/../tools";
our $VERBOSE;
our $CONF_FILE_PATH;
our $DAEMON_MODE;
our $SETUP_MODE;


INIT {
	# Parse config file and set globals
	
	# Set Getopt pass_through so this module doesn't erase parameters that other modules may use
	Getopt::Long::Configure('pass_through');
	
	# Set a default config file path
	my $hostname = hostname();
	$hostname =~ s/\..*//g;
	my $cwd = getcwd();
	$CONF_FILE_PATH = "$cwd/$hostname.conf";
	if (!-f $CONF_FILE_PATH) {
		if ($BIN_PATH =~ /dev/) {
			$CONF_FILE_PATH = "/etc/vcl/vcldev.conf";
		}
		else {
			$CONF_FILE_PATH = "/etc/vcl/vcld.conf";
		}
	}

	# Store the command line options in hash
	our %OPTIONS;
	GetOptions(\%OPTIONS,
				  'config=s' => \$CONF_FILE_PATH,
				  'daemon!' => \$DAEMON_MODE,
				  'logfile=s' => \$LOGFILE,
				  'help' => \&help,
				  'setup!' => \$SETUP_MODE,
				  'verbose!' => \$VERBOSE,
	);

	my %parameters = (
		'log'							=> \$LOGFILE,
		'pidfile'					=> \$PIDFILE,
		'fqdn'						=> \$FQDN,
		'database'					=> \$DATABASE,
		'server'						=> \$SERVER,
		'lockerwrtuser'			=> \$WRTUSER,
		'wrtpass'					=> \$WRTPASS,
		'xmlrpc_username'			=> \$XMLRPC_USER,
		'xmlrpc_pass'				=> \$XMLRPC_PASS,
		'xmlrpc_url'				=> \$XMLRPC_URL,
		'enable_mysql_ssl'		=> \$MYSQL_SSL,
		'mysql_ssl_cert'			=> \$MYSQL_SSL_CERT,
		'returnpath'				=> \$RETURNPATH,
		'jabber'						=> \$JABBER,
		'jabserver'					=> \$JABBER_SERVER,
		'jabuser'					=> \$JABBER_USER,
		'jabpass'					=> \$JABBER_PASSWORD,
		'jabport'					=> \$JABBER_PORT,
		'jabresource'				=> \$JABBER_RESOURCE,
		'processname'				=> \$PROCESSNAME,
		'windows_root_password'	=> \$WINDOWS_ROOT_PASSWORD,
		'verbose'					=> \$VERBOSE,
		'defaulthelpemail'		=> \$DEFAULTHELPEMAIL,
	);
	
	# Make sure the config file exists
	if (!-f $CONF_FILE_PATH) {
		if (!$SETUP_MODE) {
			print STDERR "FATAL: vcld configuration file does not exist: $CONF_FILE_PATH\n";
			help();
		}
	}
	elsif (!open(CONF, $CONF_FILE_PATH)) {
		print STDERR "FATAL: failed to open vcld configuration file: $CONF_FILE_PATH, $!\n";
		exit;
	}
	
	my @conf_file_lines = <CONF>;
	close(CONF);
	
	my $line_number = 0;
	foreach my $line (@conf_file_lines) {
		$line_number++;
		
		$line =~ s/[\s]*$//g;
		
		# Skip commented and blank lines
		if ($line =~ /^\s*#/ || $line !~ /\w/) {
			next;
		}
		
		my ($parameter, $value) = $line =~ /\s*([^=]+)=(.+)/;
		if (!defined($parameter) || !defined($value)) {
			print STDERR "WARNING: ignoring line $line_number in $CONF_FILE_PATH: $line\n";
			next;
		}
		
		# Remove any leading and trailing spaces
		for ($parameter, $value) {
			s/^\s+//;
			s/\s+$//;
		}
		
		$parameter = lc($parameter);
		
		if (my $variable_ref = $parameters{$parameter}) {
			if (defined($$variable_ref)) {
				#print STDOUT "INFO: ignoring previously set parameter: $parameter\n";
			}
			else {
				$$variable_ref = $value;
				#print STDOUT "set parameter: '$parameter' = '$value'\n";
			}
		}
		else {
			print STDERR "WARNING: unsupported parameter found on line $line_number in $CONF_FILE_PATH: " . string_to_ascii($parameter) . "\n";
		}
	}
	
	if (!$FQDN) {
		print STDERR "FATAL: FQDN parameter must be configured in $CONF_FILE_PATH\n";
		exit;
	}
	
	$PROCESSNAME = 'vcld' if !$PROCESSNAME;
	$PIDFILE = "/var/run/$PROCESSNAME.pid" if !$PIDFILE;
	$LOGFILE = "/var/log/$PROCESSNAME.log" if !defined($LOGFILE);
	$WINDOWS_ROOT_PASSWORD = "clOudy" if !defined($WINDOWS_ROOT_PASSWORD);
	$DEFAULTHELPEMAIL = "vcl_help\@example.org" if !$DEFAULTHELPEMAIL;
	
	# Can't be both daemon mode and setup mode, use setup if both are set
	if ($SETUP_MODE) {
		$DAEMON_MODE = 0;
	}
	elsif (!defined($DAEMON_MODE)) {
		$DAEMON_MODE = 1;
	}
	
	# Set boolean variables to 0 or 1, they may be set to 'no' or 'yes' in the conf file
	for ($MYSQL_SSL, $JABBER, $VERBOSE, $DAEMON_MODE, $SETUP_MODE) {
		if (!$_ || $_ =~ /no/i) {
			$_ = 0;
		}
		else {
			$_ = 1;
		}
	}
	
	if ($JABBER) {
		# Jabber is enabled - import required module
		eval {
			require "Net/Jabber.pm";
			import Net::Jabber qw(client);
		};
		if ($EVAL_ERROR) {
			print STDERR "FATAL: failed to load Jabber module, error:\n$EVAL_ERROR\n";
			exit;
		}
	}
} ## end INIT

#/////////////////////////////////////////////////////////////////////////////

=head2 help

 Parameters  : None
 Returns     : Nothing, terminates program
 Description : Displays a help message and exits.

=cut

sub help {
	my $message = <<"END";
============================================================================
Please read the README and INSTALLATION files in the source directory.
Documentation is available at http://cwiki.apache.org/VCL.

Command line options:
-setup       | Run management node setup
-conf=<path> | Specify vcld configuration file
-verbose     | Run vcld in verbose mode
-debug       | Run vcld in non-daemon mode
-help        | Display this help information
============================================================================
END

	print $message;
	exit 1;
} ## end sub help

#/////////////////////////////////////////////////////////////////////////////

=head2 preplogfile

 Parameters  : nothing
 Returns     : nothing
 Description : writes header to global log file

=cut

sub preplogfile {
	my $currenttime = makedatestring();
	
	#Print the vcld process info
	my $process_info = <<EOF;
============================================================================
VCL Management Node Daemon (vcld) | $currenttime
============================================================================
bin path:      $BIN_PATH
config file:   $CONF_FILE_PATH
log file:      $LOGFILE
pid file:      $PIDFILE
daemon mode:   $DAEMON_MODE
setup mode:    $SETUP_MODE
verbose mode:  $VERBOSE
============================================================================
EOF

	if ($LOGFILE) {
		if (!open(LOGFILE, ">>$LOGFILE")) {
			die "Failed to open log file: $LOGFILE";
		}
		print LOGFILE $process_info;
		close(LOGFILE);
	} else {
        print STDOUT $process_info;
    }
}

#/////////////////////////////////////////////////////////////////////////////

=head2 notify

 Parameters  : $error, $LOG, $string, $data
 Returns     : nothing
 Description : based on error value write string and/or data to
					provide or default log file
=cut

sub notify {
	my $error  = shift;
	my $log    = shift;
	my $string = shift;
	my @data   = @_;

	# Just return if DEBUG and verbose isn't enabled
	return if ($error == 6 && !$VERBOSE);

	# Get the current time
	my $currenttime = makedatestring();
	
	# Open the log file for writing if passed as an argument or set globally
	# If not, print to STDOUT
	$log = $LOGFILE if (!$log);
	
	# Get info about the subroutine which called this subroutine
	my ($package, $filename, $line, $sub) = caller(0);
	
	# Assemble the caller information
	my $caller_info;
	if (caller(1)) {
		$sub = (caller(1))[3];
	}

	# Remove leading path from filename
	$filename =~ s/.*\///;

	# Remove the leading package path from the sub name (VC::...)
	$sub =~ s/.*:://;
	
	$caller_info = "$filename:$sub($line)";

	# Format the message string
	# Remove Windows carriage returns from the message string for consistency
	$string =~ s/\r//gs;
	
	## Remove newlines from the beginning and end of the message string
	#$string =~ s/^\n+//;
	#$string =~ s/\n+$//;
	
	# Remove any spaces from the beginning or end of the string
	$string =~ s/(^\s+)|(\s+$)//gs;
	
	# Remove any spaces from the beginning or end of the each line
	$string =~ s/\s*\n\s*/\n/gs;
	
	# Replace consecutive spaces with a single space to keep log file concise as long as string doesn't contain a quote
	if ($string !~ /[\'\"]/gs && $string !~ /\s:\s/gs) {
		$string =~ s/[ \t]+/ /gs;
	}

	# Assemble the process identifier string
	my $process_identifier;
	$process_identifier .= "|$PID|";
	$process_identifier .= $ENV{request_id} if defined $ENV{request_id};
	$process_identifier .= "|";
	$process_identifier .= $ENV{reservation_id} if defined $ENV{reservation_id};
	$process_identifier .= "|";
	$process_identifier .= $ENV{state} || 'vcld';
	$process_identifier .= "|$filename:$sub|$line";

	# Assemble the log message
	my $log_message = "$currenttime$process_identifier|$string";

	# Format the data if WARNING or CRITICAL, and @data was passed
	my $formatted_data;
	if (@data && ($error == 1 || $error == 2)) {
		# Add the data to the message body if it was passed
		$formatted_data = "DATA:\n" . format_data(\@data, 'DATA');
		chomp $formatted_data;
	}

	# Assemble an email message body if CRITICAL
	my $body;
	my $body_separator = '-' x 72;
	
	my $sysadmin = '';
	my $shared_mail_box = '';
	
	if ($error == 2 || $error == 5) {
		my $caller_trace = get_caller_trace(999);
		if ($caller_trace !~ /get_management_node_info/) {
			my $management_node_info = get_management_node_info();
			if ($management_node_info) {
				$sysadmin = $management_node_info->{SYSADMIN_EMAIL} if $management_node_info->{SYSADMIN_EMAIL};
				$shared_mail_box = $management_node_info->{SHARED_EMAIL_BOX} if $management_node_info->{SHARED_EMAIL_BOX};
			}
		}
	}
	
	# WARNING
	if ($error == 1) {
		my $caller_trace = get_caller_trace(6);
		$log_message = "\n---- WARNING ---- \n$log_message\n$caller_trace\n\n";
	}

	# CRITICAL
	elsif ($error == 2) {
		my $caller_trace = get_caller_trace(15);
		$log_message = "\n---- CRITICAL ---- \n$log_message\n$caller_trace\n\n";
		if($sysadmin) {
			
			# Assemble the e-mail message body
			$body = <<"END";
$string
$body_separator
time: $currenttime
caller: $caller_info
$caller_trace
$body_separator
END
			
			# Add the reservation info to the message if the DataStructure object is defined in %ENV
			if ($ENV{data}) {
				my $reservation_info_string = $ENV{data}->get_reservation_info_string();
				if ($reservation_info_string) {
					$reservation_info_string =~ s/\s+$//;
					$body .= "$reservation_info_string\n";
					$body .= "$body_separator\n";
				}
			}
			
			# Get the previous several log file entries for this process
			my $log_history_count = 100;
			my $log_history       = "RECENT LOG ENTRIES FOR THIS PROCESS:\n";
			$log_history .= `grep "|$PID|" $log | tail -n $log_history_count` if $log;
			chomp $log_history;
			$body .= $log_history;
			
			# Add the formatted data to the message body if data was passed
			$body .= "\n\nDATA:\n$formatted_data\n" if $formatted_data;
			
			my ($management_node_short_name) = $FQDN =~ /^([^.]+)/;
			my $subject = "PROBLEM -- $management_node_short_name|";
			
			# Assemble the process identifier string
			if (defined $ENV{request_id} && defined $ENV{reservation_id} && defined $ENV{state}) {
				$subject .= "$ENV{request_id}:$ENV{reservation_id}|$ENV{state}|$filename";
			}
			else {
				$subject .= "$caller_info";
			}
			
			if (defined($ENV{data})) {
				my $blockrequest_name = $ENV{data}->get_blockrequest_name(0);
				$subject .= "|$blockrequest_name" if (defined $blockrequest_name);
				
				my $computer_name = $ENV{data}->get_computer_short_name(0);
				$subject .= "|$computer_name" if (defined $computer_name);
				
				my $vmhost_hostname = $ENV{data}->get_vmhost_hostname(0);
				$subject .= ">$vmhost_hostname" if (defined $vmhost_hostname);
				
				my $image_name = $ENV{data}->get_image_name(0);
				$subject .= "|$image_name" if (defined $image_name);
				
				my $user_name = $ENV{data}->get_user_login_id(0);
				$subject .= "|$user_name" if (defined $user_name);
			}
			
			my $from    = "root\@$FQDN";
			my $to      = $sysadmin;
			
			mail($to, $subject, $body, $from);
		}
	} ## end elsif ($error == 2)  [ if ($error == 1)
	
	# MAILMASTERS - only for email notifications
	elsif ($error == 5 && $shared_mail_box) {
		my $to      = $shared_mail_box;
		my $from    = "root\@$FQDN";
		my $subject = "Informational -- $filename";
		
		# Assemble the e-mail message body
		$body = <<"END";
$string

Time: $currenttime
PID: $PID
Caller: $caller_info

END
		
		mail($to, $subject, $body, $from);
	}

	# Add the process identifier to every line of the log message
	chomp $log_message;
	$log_message =~ s/\n([^\n])/\n$process_identifier| $1/g;
	
	# Check if the logfile path has been set and not running in daemon mode and redirect output to log file
	# No need to redirect in daemon mode because STDOUT is redirected by vcld
	if (!$DAEMON_MODE && $log) {
		open(OUTPUT, ">>$log");
		print OUTPUT "$log_message\n";
		close OUTPUT;
	}
	else {
		open(STDOUT, ">>$log");
		print STDOUT "$log_message\n";
	}
} ## end sub notify

#/////////////////////////////////////////////////////////////////////////////

=head2  makedatestring

 Parameters  : empty
 Returns     : current time in date_time format
 Description :

=cut

sub makedatestring {
	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime();
	$year += 1900;
	$mon++;
	my $datestring = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
	return $datestring;
}

#/////////////////////////////////////////////////////////////////////////////

=head2  convert_to_datetime

 Parameters  : time in epoch format
 Returns     : date in datetime format
 Description : accepts time in epoch format (10 digit) and
					returns time  in datetime format

=cut

sub convert_to_datetime {
	my ($epochtime) = shift;

	if (!defined($epochtime) || $epochtime == 0) {
		$epochtime = time();
	}

	my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime($epochtime);
	$year += 1900;
	$mon++;
	my $datestring = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon, $mday, $hour, $min, $sec);
	return $datestring;

} ## end sub convert_to_datetime

#/////////////////////////////////////////////////////////////////////////////

=head2  convert_to_epoch_seconds

 Parameters  : datetime
 Returns     : time in epoch format
 Description : takes input(optional) and returns epoch 10 digit string of
					the supplied date_time or the current time

=cut

sub convert_to_epoch_seconds {
	my ($date_time) = shift;
	if (!defined($date_time)) {
		return time();
	}
	#somehow we got a null timestamp, set it to current time
	if ($date_time =~ /0000-00-00 00:00:00/) {
		$date_time = makedatestring;
	}

	#format received: year-mon-mday hr:min:sec
	my ($vardate, $vartime) = split(/ /, $date_time);
	my ($yr, $mon, $mday) = split(/-/, $vardate);
	my ($hr, $min, $sec)  = split(/:/, $vartime);
	$mon = $mon - 1;    #time uses 0-11 for months :(
	my $epoch_time = timelocal($sec, $min, $hr, $mday, $mon, $yr);
	return $epoch_time;
} ## end sub convert_to_epoch_seconds


#/////////////////////////////////////////////////////////////////////////////

=head2  check_endtimenotice_interval

 Parameters  : endtime
 Returns     : scalar: 2week, 1week, 2day, 1day, 30min, or 0
 Description : used to send a notice to owner regarding how far out the end of
					their reservation is

=cut

sub check_endtimenotice_interval {
	my $end = $_[0];
	notify($ERRORS{'WARNING'}, 0, "endtime not set") if (!defined($end));
	
	my $now      = convert_to_epoch_seconds();
	my $epochend = convert_to_epoch_seconds($end);
	my $epoch_until_end = $epochend - $now;
	
	notify($ERRORS{'OK'}, 0, "endtime= $end epoch_until_end= $epoch_until_end");
	
	my $diff_seconds = $epoch_until_end;
	
	my $diff_weeks = int($epoch_until_end/604800);
	$diff_seconds -= $diff_weeks * 604800;
	
	my $diff_days = int($diff_seconds/86400);
	my $Total_days = int($epoch_until_end/86400);
	$diff_seconds -= $diff_days * 86400;
	
	my $diff_hours = int($diff_seconds/3600);
	$diff_seconds -= $diff_hours * 3600;
	
	my $diff_minutes = int($diff_seconds/60);
	$diff_seconds -= $diff_minutes * 60;
	
	notify($ERRORS{'OK'}, 0, "End Time is in: $diff_weeks week\(s\) $diff_days day\(s\) $diff_hours hour\(s\) $diff_minutes min\(s\) and $diff_seconds sec\(s\)");
	
	#flag on: 2 & 1 week; 2,1 day, 1 hour, 30,15,10,5 minutes
	#ignore over 2weeks away
	if($diff_weeks >= 2){
		return 0;
	}
	#2 week: between 14 days and a 14 day -6 minutes window
	elsif($Total_days >= 13 && $diff_hours >= 23 && $diff_minutes >= 55){
		return "2 weeks";
	}
	#Ignore: between 7 days and 14 day - 6 minute window
	elsif($Total_days >=7) {
		return 0;
	}
	# 1 week notice: between 7 days and a 7 day -6 minute window
	elsif ($Total_days >= 6 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "1 week";
	}
	# Ignore: between 2 days and 7 day - 15 minute window
	elsif ($Total_days >= 2) {
		return 0;
	}
	# 2 day notice: between 2 days and a 2 day -6 minute window
	elsif($Total_days >= 1 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "2 days";
	}
	# 1 day notice: between 1 days and a 1 day -6 minute window
	elsif($Total_days >= 0 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "24 hours";
	}
	
	return 0;
} ## end sub check_endtimenotice_interval

#/////////////////////////////////////////////////////////////////////////////

=head2 check_blockrequest_time

 Parameters  : start, end, and expire times
 Returns     : 0 or 1 and task
 Description : check current time against all three tasks
					expire time overides end, end overrides start

=cut

sub check_blockrequest_time {
	my ($start_datetime, $end_datetime, $expire_datetime) = @_;

	# Check the arguments
	if (!$start_datetime) {
		notify($ERRORS{'WARNING'}, 0, "start time argument was not passed correctly");
		return;
	}
	if (!$end_datetime) {
		notify($ERRORS{'WARNING'}, 0, "end time argument was not passed correctly");
		return;
	}
	if (!$expire_datetime) {
		notify($ERRORS{'WARNING'}, 0, "expire time argument was not passed correctly");
		return;
	}

	# Get the current time in epoch seconds
	my $current_time_epoch_seconds = time();

	my $expire_time_epoch_seconds = convert_to_epoch_seconds($expire_datetime);
	my $expire_delta_minutes      = int(($expire_time_epoch_seconds - $current_time_epoch_seconds) / 60);
	#notify($ERRORS{'DEBUG'}, 0, "expire: $expire_datetime, epoch: $expire_time_epoch_seconds, delta: $expire_delta_minutes minutes");

	# If expire time is in the past, remove it
	if ($expire_delta_minutes < 0) {
		# Block request has expired
		notify($ERRORS{'OK'}, 0, "block request expired " . abs($expire_delta_minutes) . " minutes ago, returning 'expire'");
		return "expire";
	}

	if ($start_datetime =~ /^-?\d*$/ || $end_datetime =~ /^-?\d*$/) {
		notify($ERRORS{'DEBUG'}, 0, "block request is not expired but has no block times assigned to it, returning 0");
		return 0;
	}

	# Convert the argument datetimes to epoch seconds for easy calculation
	my $start_time_epoch_seconds = convert_to_epoch_seconds($start_datetime);
	my $end_time_epoch_seconds   = convert_to_epoch_seconds($end_datetime);

	# Calculate # of seconds away start, end, and expire times are from now
	# Positive value means time is in the future
	my $start_delta_minutes = int(($start_time_epoch_seconds - $current_time_epoch_seconds) / 60);
	my $end_delta_minutes   = int(($end_time_epoch_seconds - $current_time_epoch_seconds) / 60);

	#notify($ERRORS{'DEBUG'}, 0, "start:  $start_datetime,  epoch: $start_time_epoch_seconds,  delta: $start_delta_minutes minutes");
	#notify($ERRORS{'DEBUG'}, 0, "end:    $end_datetime,    epoch: $end_time_epoch_seconds,    delta: $end_delta_minutes minutes");

	# if 1min to 6 hrs in advance: start assigning resources
	if ($start_delta_minutes <= (6 * 60)) {
		# Block request within start window
		notify($ERRORS{'OK'}, 0, "block request start time is within start window ($start_delta_minutes minutes from now), returning 'start'");
		return "start";
	}

	# End time it is less than 1 minute
	if ($end_delta_minutes < 0) {
		# Block request end time is near
		notify($ERRORS{'OK'}, 0, "block request end time has been reached ($end_delta_minutes minutes from now), returning 'end'");
		return "end";
	}

	#notify($ERRORS{'DEBUG'}, 0, "block request does not need to be processed now, returning 0");
	return 0;

} ## end sub check_blockrequest_time

#/////////////////////////////////////////////////////////////////////////////

=head2 check_time

 Parameters  : $request_start, $request_end, $reservation_lastcheck, $request_state_name, $request_laststate_name
 Returns     : start, preload, end, poll, old, remove, or 0
 Description : based on the input return a value used by vcld
=cut

sub check_time {
	my ($request_start, $request_end, $reservation_lastcheck, $request_state_name, $request_laststate_name) = @_;
	
	# Check the arguments
	if (!defined($request_state_name)) {
		notify($ERRORS{'WARNING'}, 0, "\$request_state_name argument is not defined");
		return 0;
	}
	if (!defined($request_laststate_name)) {
		notify($ERRORS{'WARNING'}, 0, "\$request_laststate_name argument is not defined");
		return 0;
	}

	# If lastcheck isn't set, set it to now
	if (!defined($reservation_lastcheck) || !$reservation_lastcheck) {
		$reservation_lastcheck = makedatestring();
	}

	# First convert to datetime in case epoch seconds was passed
	if ($reservation_lastcheck !~ /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}/) {
		$reservation_lastcheck = convert_to_datetime($reservation_lastcheck);
	}
	if ($request_end !~ /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}/) {
		$request_end = convert_to_datetime($request_end);
	}
	if ($request_start !~ /\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}/) {
		$request_start = convert_to_datetime($request_start);
	}

	# Convert times to epoch seconds
	my $lastcheck_epoch_seconds  = convert_to_epoch_seconds($reservation_lastcheck);
	my $start_time_epoch_seconds = convert_to_epoch_seconds($request_start);
	my $end_time_epoch_seconds   = convert_to_epoch_seconds($request_end);

	# Get the current time epoch seconds
	my $current_time_epoch_seconds = time();

	# Calculate time differences from now in seconds
	# These will be positive if in the future, negative if in the past
	my $lastcheck_diff_seconds = $lastcheck_epoch_seconds - $current_time_epoch_seconds;
	my $start_diff_seconds     = $start_time_epoch_seconds - $current_time_epoch_seconds;
	my $end_diff_seconds       = $end_time_epoch_seconds - $current_time_epoch_seconds;

	# Calculate the time differences from now in minutes
	# These will be positive if in the future, negative if in the past
	my $lastcheck_diff_minutes = round($lastcheck_diff_seconds / 60);
	my $start_diff_minutes     = round($start_diff_seconds / 60);
	my $end_diff_minutes       = round($end_diff_seconds / 60);

	# Print the time differences
	#notify($ERRORS{'OK'}, 0, "reservation lastcheck difference: $lastcheck_diff_minutes minutes");
	#notify($ERRORS{'OK'}, 0, "request start time difference:    $start_diff_minutes minutes");
	#notify($ERRORS{'OK'}, 0, "request end time difference:      $end_diff_minutes minutes");

	# Check the state, and then figure out the return code
	if ($request_state_name =~ /new|imageprep|reload|tovmhostinuse/) {
		if ($start_diff_minutes > 0) {
			# Start time is either now or in future, $start_diff_minutes is positive
			
			if ($start_diff_minutes > 35) {
				#notify($ERRORS{'DEBUG'}, 0, "reservation will start in more than 35 minutes ($start_diff_minutes)");
				return "0";
			}
			elsif ($start_diff_minutes >= 25 && $start_diff_minutes <= 35) {
				notify($ERRORS{'DEBUG'}, 0, "reservation will start in 25-35 minutes ($start_diff_minutes)");
				return "preload";
			}
			else {
				#notify($ERRORS{'DEBUG'}, 0, "reservation will start less than 25 minutes ($start_diff_minutes)");
				return "0";
			}
		} ## end if ($start_diff_minutes > 0)
		else {
			# Start time is in past, $start_diff_minutes is negative
			
			#Start time is fairly old - something is off
			#send warning to log for tracking purposes
			if ($start_diff_minutes < -17) {
				notify($ERRORS{'WARNING'}, 0, "reservation start time was in the past 17 minutes ($start_diff_minutes)");
			}
			
			return "start";
			
		} ## end else [ if ($start_diff_minutes > 0)
	}
	elsif ($request_state_name =~ /tomaintenance/) {
		if ($start_diff_minutes > 0) {
			# Start time is either now or in future, $start_diff_minutes is positive
			notify($ERRORS{'DEBUG'}, 0, "$request_state_name request will be processed in $start_diff_minutes minutes");
			return "0";
		}
		else {
			# Start time is in past, $start_diff_minutes is negative
			notify($ERRORS{'DEBUG'}, 0, "$request_state_name request will be processed now");
			return "start";
		}
	}
	elsif ($request_state_name =~ /inuse/) {
		if ($end_diff_minutes <= 10) {
			notify($ERRORS{'DEBUG'}, 0, "reservation will end in 10 minutes or less ($end_diff_minutes)");
			return "end";
		}
		else {
			# End time is more than 10 minutes in the future
			#notify($ERRORS{'DEBUG'}, 0, "reservation will end in more than 10 minutes ($end_diff_minutes)");

			if ($lastcheck_diff_minutes <= -5) {
				#notify($ERRORS{'DEBUG'}, 0, "reservation was last checked more than 5 minutes ago ($lastcheck_diff_minutes)");
				return "poll";
			}
			else {
				#notify($ERRORS{'DEBUG'}, 0, "reservation has been checked within the past 5 minutes ($lastcheck_diff_minutes)");
				return 0;
			}
		} ## end else [ if ($end_diff_minutes <= 10)
	} ## end elsif ($request_state_name =~ /inuse|imageinuse/) [ if ($request_state_name =~ /new|imageprep|reload|tomaintenance|tovmhostinuse/)

	elsif ($request_state_name =~ /complete|failed/) {
		# Don't need to keep requests in database if laststate was...
		if ($request_laststate_name =~ /image|deleted|makeproduction|reload|tomaintenance|tovmhostinuse/) {
			return "remove";
		}

		if ($end_diff_minutes < 0) {
			notify($ERRORS{'DEBUG'}, 0, "reservation end time was in the past ($end_diff_minutes)");
			return "remove";
		}
		else {
			# End time is now or in the future
			#notify($ERRORS{'DEBUG'}, 0, "reservation end time is either right now or in the future ($end_diff_minutes)");
			return "0";
		}
	}    # Close if state is complete or failed

	# Just return start for all other states
	else {
		return "start";
	}

} ## end sub check_time

#/////////////////////////////////////////////////////////////////////////////

=head2 mail

 Parameters  : $to, $subject,  $mailstring, $from
 Returns     : 1(success) or 0(failure)
 Description : send an email
=cut

sub mail {
	my ($to,      $subject,  $mailstring, $from) = @_;
	my ($package, $filename, $line,       $sub)  = caller(0);

	# Mail::Mailer relies on sendmail as written, this causes a "die" on Windows
	# TODO: Reqork this subroutine to not rely on sendmail
	my $osname = lc($^O);
	if ($osname =~ /win/i) {
		notify($ERRORS{'OK'}, 0, "sending mail from Windows not yet supported\n-----\nTo: $to\nSubject: $subject\nFrom: $from\n$mailstring\n-----");
		return;
	}

	# Wrap text for lines longer than 72 characters
	#$Text::Wrap::columns = 72;
	#$mailstring = wrap('', '', $mailstring);

	# compare requestor and owner, if same only mail one
	if (!(defined($from))) {
		$from = $DEFAULTHELPEMAIL;
	}
	
	my $mailer;
	if (defined($RETURNPATH)) {
		$mailer = Mail::Mailer->new("sendmail", "-f $RETURNPATH");
	}
	else {
		$mailer = Mail::Mailer->new("sendmail");
	}
	
	my $shared_mail_box = '';
	my $management_node_info = get_management_node_info();
	if ($management_node_info) {
		$shared_mail_box = $management_node_info->{SHARED_EMAIL_BOX} if $management_node_info->{SHARED_EMAIL_BOX};
	}

	if ($shared_mail_box) {
		my $bcc = $shared_mail_box;
		if ($mailer->open({From    => $from,
								 To      => $to,
								 Bcc     => $bcc,
								 Subject => $subject,}))
		{
			print $mailer $mailstring;
			$mailer->close();
			notify($ERRORS{'OK'}, 0, "SUCCESS -- Sending mail To: $to, $subject");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "NOTICE --  Problem sending mail to: $to From");
		}
	} ## end if ($shared_mail_box)
	else {
		if ($mailer->open({From    => $from,
								 To      => $to,
								 Subject => $subject,}))
		{
			print $mailer $mailstring;
			$mailer->close();
			notify($ERRORS{'OK'}, 0, "SUCCESS -- Sending mail To: $to, $subject");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "NOTICE --  Problem sending mail to: $to From");
		}
	} ## end else [ if ($shared_mail_box)
} ## end sub mail

#/////////////////////////////////////////////////////////////////////////////

=head2 update_preload_fla

 Parameters  : request id, flag 1,0
 Returns     : 1 success 0 failure
 Description : update preload flag

=cut

sub update_preload_flag {
	my ($request_id, $flag) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	notify($ERRORS{'WARNING'}, 0, "request id is not defined")   unless (defined($request_id));
	notify($ERRORS{'WARNING'}, 0, "preload flag is not defined") unless (defined($flag));

	my $update_statement = "
	UPDATE
   request
	SET
	preload = $flag
	WHERE
   id = $request_id
	";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'OK'}, $LOGFILE, "preload flag updated for request_id $request_id ");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update preload flag updated for request_id $request_id");
		return 0;
	}
} ## end sub update_preload_flag

#/////////////////////////////////////////////////////////////////////////////

=head2 update_request_state

 Parameters  : $request_id, $state_name, $laststate_name, $force (optional)
 Returns     : boolean
 Description : Updates the request state and laststate. If the state is being
               updated to pending, the laststate argument must match the current
               state. This prevents problems if the state was updated via the
               website after the running vcld process was launched:
               OK - Current: inuse/reserved --> Argument: pending/inuse
               Not OK - Current: image/inuse --> Argument: pending/inuse
               
               This can be overridden by passing the $force argument and should
               only be done for testing.

=cut

sub update_request_state {
	my ($request_id, $state_name, $laststate_name, $force) = @_;
	
	# Check the passed parameters
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update request state, request id is argument not supplied");
		return;
	}
	if (!defined($state_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update request $request_id state, state name argument not supplied");
		return;
	}
	if (!defined($laststate_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update request $request_id state, last state name argument not supplied");
		return;
	}
	
	
	my $update_statement = <<EOF;
UPDATE
request,
state state,
state laststate,
state currentstate,
state currentlaststate
SET
request.stateid = state.id,
request.laststateid = laststate.id
WHERE
request.id = $request_id
AND request.stateid = currentstate.id
AND request.laststateid = currentlaststate.id
AND state.name = '$state_name'
AND laststate.name = '$laststate_name'
EOF
	
	if (!$force) {
		if ($state_name eq 'pending') {
			$update_statement .= "AND laststate.name = currentstate.name\n";
		}
		elsif ($state_name !~ /(failed|maintenance)/) {
			# New state is not pending
			# Need to avoid:
			#    pending/image --> inuse/inuse
			$update_statement .= "AND currentstate.name = 'pending'\n";
			$update_statement .= "AND currentlaststate.name = '$laststate_name'\n";
		}
	}
	
	# Call the database execute subroutine
	my $result = database_execute($update_statement);
	if (defined($result)) {
		my $rows_updated = (sprintf '%d', $result);
		if ($rows_updated) {
			notify($ERRORS{'OK'}, $LOGFILE, "request $request_id state updated to: $state_name, laststate to: $laststate_name");
			return 1;
		}
		else {
			my ($current_state_name, $current_laststate_name) = get_request_current_state_name($request_id);
			if ($state_name eq $current_state_name && $laststate_name eq $current_laststate_name) {
				notify($ERRORS{'OK'}, $LOGFILE, "request $request_id state already set to: $current_state_name/$current_laststate_name");
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, $LOGFILE, "unable to update request $request_id state to: $state_name/$laststate_name, current state: $current_state_name/$current_laststate_name");
				return;
			}
		}
		return $rows_updated;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update states for request $request_id");
		return;
	}
} ## end sub update_request_state

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_state

 Parameters  : $computer_id, $state_name, $log
 Returns     : 1 success 0 failure
 Description : update computer state

=cut

sub update_computer_state {
	my ($computer_id, $state_name, $log) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	notify($ERRORS{'WARNING'}, $log, "computer id is not defined") unless (defined($computer_id));
	notify($ERRORS{'WARNING'}, $log, "statename is not defined")   unless (defined($state_name));
	return 0 unless (defined $computer_id && defined $state_name);

	my $update_statement = "
	UPDATE
	computer,
	state
	SET
	computer.stateid = state.id
	WHERE
	state.name = \'$state_name\'
	AND computer.id = $computer_id
	";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'OK'}, $LOGFILE, "computer $computer_id state updated to: $state_name");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update states for computer $computer_id");
		return 0;
	}
} ## end sub update_computer_state

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_lastcheck

 Parameters  : $computer_id, $datestring, $log
 Returns     : 1 success 0 failure
 Description : update computer state

=cut

sub update_computer_lastcheck {
	my ($computer_id, $datestring, $log) = @_;

	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 unless (defined $log);

	notify($ERRORS{'WARNING'}, $log, "computer id is not defined") unless (defined($computer_id));
	return 0 unless (defined $computer_id);

	unless (defined($datestring) ) {
		$datestring = makedatestring;
	}

	my $update_statement = "
	UPDATE
	computer
	SET
	computer.lastcheck = '$datestring'
	WHERE
	computer.id = $computer_id
	";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'DEBUG'}, $log, "computer $computer_id lastcheck updated to: $datestring");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, $log, "unable to update datestring for computer $computer_id");
		return 0;
	}
} ## end

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_procnumber

 Parameters  : $computer_id, $cpu_count
 Returns     : boolean
 Description : Updates the computer.procnumber value for the specified computer.

=cut

sub update_computer_procnumber {
	my ($computer_id, $cpu_count) = @_;

	if (!$computer_id || !$cpu_count) {
		notify($ERRORS{'WARNING'}, 0, "computer ID and CPU count arguments were not supplied correctly");
		return;
	}

	my $update_statement = <<EOF;
UPDATE
computer
SET
computer.procnumber = '$cpu_count'
WHERE
computer.id = $computer_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated the procnumber value to $cpu_count for computer ID $computer_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update the procnumber value to $cpu_count for computer ID $computer_id");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_procspeed

 Parameters  : $computer_id, $cpu_speed
 Returns     : boolean
 Description : Updates the computer.procspeed value for the specified computer.
					The $cpu_speed argument should contain an integer value of the
					CPU speed in MHz.

=cut

sub update_computer_procspeed {
	my ($computer_id, $cpu_speed_mhz) = @_;

	if (!$computer_id || !$cpu_speed_mhz) {
		notify($ERRORS{'WARNING'}, 0, "computer ID and CPU speed arguments were not supplied correctly");
		return;
	}

	my $update_statement = <<EOF;
UPDATE
computer
SET
computer.procspeed = '$cpu_speed_mhz'
WHERE
computer.id = $computer_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated the procspeed value to $cpu_speed_mhz for computer ID $computer_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update the procspeed value to $cpu_speed_mhz for computer ID $computer_id");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_ram

 Parameters  : $computer_id, $ram_mb
 Returns     : boolean
 Description : Updates the computer.ram value for the specified computer.
					The $ram_mb argument should contain an integer value of the
					RAM in MB.

=cut

sub update_computer_ram {
	my ($computer_id, $ram_mb) = @_;

	if (!$computer_id || !$ram_mb) {
		notify($ERRORS{'WARNING'}, 0, "computer ID and RAM arguments were not supplied correctly");
		return;
	}

	my $update_statement = <<EOF;
UPDATE
computer
SET
computer.ram = '$ram_mb'
WHERE
computer.id = $computer_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated the RAM value to $ram_mb for computer ID $computer_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update the RAM value to $ram_mb for computer ID $computer_id");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_request_password

 Parameters  : $reservation_id, $password
 Returns     : 1 success 0 failure
 Description : updates password field for reservation id

=cut

sub update_request_password {
	my ($reservation_id, $password) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	notify($ERRORS{'WARNING'}, 0, "reservation id is not defined") unless (defined($reservation_id));
	notify($ERRORS{'WARNING'}, 0, "password is not defined")       unless (defined($password));

	my $update_statement = "
	UPDATE
   reservation
	SET
	pw = \'$password\'
	WHERE
   id = $reservation_id
	";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'OK'}, $LOGFILE, "password updated for reservation_id $reservation_id ");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update password for reservation $reservation_id");
		return 0;
	}
} ## end sub update_request_password

#/////////////////////////////////////////////////////////////////////////////

=head2 is_request_deleted

 Parameters  : $request_id
 Returns     : return 1 if request state or laststate is set to deleted or if request does not exist
					return 0 if request exists and neither request state nor laststate is set to deleted1 success 0 failure
 Description : checks if request has been deleted

=cut

sub is_request_deleted {

	my ($request_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return 0;
	}

	# Create the select statement
	my $select_statement = "
	SELECT
	request.stateid AS currentstate_id,
	request.laststateid AS laststate_id,
	currentstate.name AS currentstate_name,
	laststate.name AS laststate_name
	FROM
	request, state currentstate, state laststate
	WHERE
	request.id = $request_id
	AND request.stateid = currentstate.id
	AND request.laststateid = laststate.id
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		return 1;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return 0;
	}
	
	my $state_name     = $selected_rows[0]{currentstate_name};
	my $laststate_name = $selected_rows[0]{laststate_name};

	#notify($ERRORS{'DEBUG'}, 0,"state=$state_name, laststate=$laststate_name");
	
	if ($state_name =~ /(deleted|makeproduction)/ || $laststate_name =~ /(deleted|makeproduction)/) {
		return 1;
	}

	return 0;
} ## end sub is_request_deleted

#/////////////////////////////////////////////////////////////////////////////

=head2 is_request_imaging

 Parameters  : $request_id
 Returns     : return 'image' if request state or laststate is set to image
					return 'forimaging' if forimaging is set to 1, and neither request state nor laststate is set to image
					return 0 if forimaging is set to 0, and neither request state nor laststate is set to image
					return undefined if an error occurred
 Description : checks if request is in imaging mode and if forimaging has been set

=cut

sub is_request_imaging {

	my ($request_id) = @_;
	
	# Check the passed parameter
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return;
	}

	# Create the select statement
	my $select_statement = "
	SELECT
	request.forimaging AS forimaging,
	request.stateid AS currentstate_id,
	request.laststateid AS laststate_id,
	currentstate.name AS currentstate_name,
	laststate.name AS laststate_name
	FROM
	request, state currentstate, state laststate
	WHERE
	request.id = $request_id
	AND request.stateid = currentstate.id
	AND request.laststateid = laststate.id
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows != 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select");
		return;
	}

	my $forimaging     = $selected_rows[0]{forimaging};
	my $state_name     = $selected_rows[0]{currentstate_name};
	my $laststate_name = $selected_rows[0]{laststate_name};

	notify($ERRORS{'DEBUG'}, 0, "forimaging=$forimaging, currentstate=$state_name, laststate=$laststate_name");

	# If request state or laststate has been changed to image, return 1
	# If forimaging is set, return 0
	# If neither state is image and forimaging is not set, return undefined
	if ($state_name eq 'image' || $laststate_name eq 'image') {
		return 'image';
	}
	elsif ($forimaging) {
		return 'forimaging';
	}
	else {
		return 0;
	}
} ## end sub is_request_imaging

#/////////////////////////////////////////////////////////////////////////////

=head2 get_next_image_default

 Parameters  : $reservationid
 Returns     : userid,password,affiliation
 Description : Used for server loads, provides list of users for group access

=cut

sub get_reservation_accounts {
        my ($reservationid) = @_;
        my ($calling_package, $calling_filename, $calling_line, $calling_sub) = caller(0);

        if (!defined($reservationid)) {
                notify($ERRORS{'WARNING'}, 0, "$calling_sub $calling_package missing mandatory variable: reservationid ");
                return 0;
        }

        my $select_statement = "
	SELECT DISTINCT
	reservationaccounts.userid AS reservationaccounts_userid,
	reservationaccounts.password AS reservationaccounts_password,
	affiliation.name AS affiliation_name,
	user.unityid AS user_name
	FROM
	reservationaccounts,
	affiliation,
	user
	WHERE
	user.id = reservationaccounts.userid AND
	affiliation.id = user.affiliationid AND
	reservationaccounts.reservationid = $reservationid
	";

        # Call the database select subroutine
        # This will return an array of one or more rows based on the select statement
        my @selected_rows = database_select($select_statement);

        my @ret_array;
	my %user_info;

        # Check to make sure 1 or more rows were returned
        if (scalar @selected_rows > 0) {
		# It contains a hash
                for (@selected_rows) {
                        my %reservation_acct= %{$_};
			my $userid = $reservation_acct{reservationaccounts_userid};
			$user_info{$userid}{"userid"} = $userid;
			$user_info{$userid}{"password"} = $reservation_acct{reservationaccounts_password};
			$user_info{$userid}{"affiliation"} = $reservation_acct{affiliation_name};
			$user_info{$userid}{"username"} = $reservation_acct{user_name};
		}
		
		return %user_info;

	}
		
	return ();

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_reservation_lastcheck

 Parameters  : @reservation_ids
 Returns     : string
 Description : Retrieves the current value of reservation.lastcheck from the
               database. Either a single reservation ID or multiple reservation
               IDs may be passed as the argument. If a single reservation ID is
               passed, a string is returned containing the reservation.lastcheck
               value. If multiple reservation IDs are passed, a hash reference
               is returned with the keys set to the reservation IDs.

=cut

sub get_current_reservation_lastcheck {
	my @reservation_ids = @_;

	# Check the passed parameter
	if (!@reservation_ids) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	
	my $reservation_id_string = join(', ', @reservation_ids);

	# Create the select statement
	my $select_statement = <<EOF;
SELECT
reservation.id,
reservation.lastcheck
FROM
reservation
WHERE
reservation.id IN ($reservation_id_string)
EOF

	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current reservation lastcheck for reservations: $reservation_id_string");
		return;
	}
	elsif (scalar(@selected_rows) == 1) {
		my $row = $selected_rows[0];
		return $row->{lastcheck};
	}
	else {
		my $reservation_lastcheck_info = {};
		for my $row (@selected_rows) {
			$reservation_lastcheck_info->{$row->{id}} = $row->{lastcheck};
		}
		return $reservation_lastcheck_info;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_reservation_accounts

 Parameters  : $reservation_id, $userid, $password, $mode
 Returns     : boolean
 Description : 

=cut

sub update_reservation_accounts {
	my $reservation_id = shift;
	my $user_id = shift;
	my $password = shift;
	my $mode = shift;
	
	if (!$mode) {
		notify($ERRORS{'WARNING'}, 0, "mode argument was not specified, it must be either add or delete");
		return;
	}
	
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	
	if (!$user_id) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not specified");
		return;
	}
	
	if (!$password) {
		$password = '';
	}
	
	my $statement;
	if ($mode =~ /add/i) {
		$statement = <<EOF;
INSERT IGNORE INTO 
reservationaccounts
(
	reservationid,
	userid,
	password
)
VALUES
(
	'$reservation_id',
	'$user_id',
	'$password'
)
ON DUPLICATE KEY UPDATE password = '$password'
EOF
	}
	elsif ($mode =~ /delete/i) {
		$statement = <<EOF;
DELETE 
reservationaccounts
FROM
reservationaccounts
WHERE
reservationid = '$reservation_id' AND
userid = '$user_id' 
EOF
	}
	
	if (database_execute($statement)) {
		#notify($ERRORS{'OK'}, 0, "executed $statement $reservation_id $user_id");
		return 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "failed to to execute statement to update reservationaccounts table:\n$statement");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_next_image_default

 Parameters  : $computerid
 Returns     : imageid,imagerevisionid,imagename
 Description : Looks for any upcoming reservations
					for supplied computerid, if starttime is
					within 50 minutes return that imageid. Else
					fetch and return next image
=cut

sub get_next_image_default {
	my ($computerid) = @_;
	my ($calling_package, $calling_filename, $calling_line, $calling_sub) = caller(0);

	if (!defined($computerid)) {
		notify($ERRORS{'WARNING'}, 0, "$calling_sub $calling_package missing mandatory variable: computerid ");
		return 0;
	}

	my $select_statement = "
	SELECT DISTINCT
	req.start AS starttime,
	ir.imagename AS imagename,
	res.imagerevisionid AS imagerevisionid,
	res.imageid AS imageid
	FROM
	reservation res,
	request req,
	image i,
	state s,
	imagerevision ir
   WHERE
	res.requestid = req.id
	AND req.stateid = s.id
	AND i.id = res.imageid
	AND ir.id = res.imagerevisionid
	AND res.computerid = $computerid
	AND (s.name = \'new\' OR s.name = \'reload\' OR s.name = \'imageprep\')
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	my @ret_array;

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows > 0) {
		# Loop through list of upcoming reservations
		# Based on the start time load the next one

		my $now = time();

		# It contains a hash
		for (@selected_rows) {
			my %reservation_row = %{$_};
			# $reservation_row{starttime}
			# $reservation_row{imagename}
			# $reservation_row{imagerevisionid}
			# $reservation_row{imageid}
			my $epoch_start = convert_to_epoch_seconds($reservation_row{starttime});
			my $diff        = $epoch_start - $now;
			# If start time is less than 50 minutes from now return this image
			notify($ERRORS{'OK'}, 0, "get_next_image_default : diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
			if ($diff < (50 * 60)) {
				notify($ERRORS{'OK'}, 0, "get_next_image_default : future reservation detected diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
				push(@ret_array, $reservation_row{imagename}, $reservation_row{imageid}, $reservation_row{imagerevisionid});
				return @ret_array;
			}
		} ## end for (@selected_rows)
	} ## end if (scalar @selected_rows > 0)

	# No upcoming reservations - fetch next image information
	my $select_nextimage = "
	SELECT DISTINCT
	imagerevision.imagename AS imagename,
	imagerevision.id AS imagerevisionid,
	image.id AS imageid
	FROM
	image,
	computer,
	imagerevision
   WHERE
	imagerevision.imageid = computer.nextimageid
	AND imagerevision.production = 1
	AND computer.nextimageid = image.id
	AND computer.id = $computerid
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @next_selected_rows = database_select($select_nextimage);

	# Check to make sure at least 1 row were returned
	if (scalar @next_selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "get_next_image_default failed to fetch next image for computerid $computerid");
		return 0;
	}
	elsif (scalar @next_selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @next_selected_rows . " rows were returned from database select");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "get_next_image_default : returning next image=$next_selected_rows[0]{imagename} imageid=$next_selected_rows[0]{imageid}");
	push(@ret_array, $next_selected_rows[0]{imagename}, $next_selected_rows[0]{imageid}, $next_selected_rows[0]{imagerevisionid});
	return @ret_array;

} ## end sub get_next_image

#/////////////////////////////////////////////////////////////////////////////

=head2 setnextimage

 Parameters  : $computerid, $image
 Returns     : 1 success, 0 failed
 Description : updates nextimageid on provided computerid
=cut

sub setnextimage {
	my ($computerid, $imageid) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "computerid: node is not defined") if (!(defined($computerid)));
	notify($ERRORS{'WARNING'}, 0, "imageid: node is not defined")    if (!(defined($imageid)));

	my $update_statement = " UPDATE computer SET nextimageid = $imageid WHERE id = $computerid ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update nextimageid");
		return 0;
	}
} ## end sub setnextimage

#/////////////////////////////////////////////////////////////////////////////

=head2 check_ssh

 Parameters  : $node, $port, $log
 Returns     : 1(active) or 0(inactive)
 Description : uses check_ssh binary from tools dir to check
					the sshd statuse on the remote node
=cut

sub check_ssh {
	my ($node, $port, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!(defined($log)));
	notify($ERRORS{'WARNING'}, $log, "node is not defined") if (!(defined($node)));
	notify($ERRORS{'WARNING'}, $log, "port is not defined") if (!(defined($port)));

	if (!defined($node)) {
		return 0;
	}
	if (!defined($port)) {
		$port = 22;
	}

	if(nmap_port($node,$port)){
		notify($ERRORS{'OK'}, $log, " $node ssh port $port open");
		return 1;
	}
	else{
		notify($ERRORS{'OK'}, $log, " $node ssh port $port closed");
		return 0;
	}

		return 0;
} ## end sub check_ssh

#/////////////////////////////////////////////////////////////////////////////

=head2 nmap_port

 Parameters  : $hostname,n $port
 Returns     : 1 open 0 closed
 Description : use nmap port scanning tool to determine if port is open

=cut

sub nmap_port {
	my ($hostname, $port) = @_;
	
	if (!$hostname) {
		notify($ERRORS{'WARNING'}, 0, "hostname argument was not specified");
		return;
	}
	if (!defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "port argument was not specified");
		return;
	}
	
	my $command = "/usr/bin/nmap $hostname -P0 -p $port -T Aggressive";
	my ($exit_status, $output) = run_command($command, 1);
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run nmap command on management node: '$command'");
		return;
	}
	
	if (grep(/(open|filtered)/i, @$output)) {
		#notify($ERRORS{'DEBUG'}, 0, "port $port is open on $hostname");
		return 1;
	}
	elsif (grep(/(nmap:|warning)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running nmap command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "port $port is closed on $hostname");
		return 0;
	}
} ## end sub nmap_port

#/////////////////////////////////////////////////////////////////////////////

=head2 _pingnode

 Parameters  : $hostname
 Returns     : 1 pingable 0 not-pingable
 Description : using Net::Ping to check if node is pingable
					assumes icmp echo is allowed
=cut

sub _pingnode {
	my ($hostname) = $_[0];
	if (!$hostname) {
		notify($ERRORS{'WARNING'}, 0, "hostname argument was not supplied");
		return;
	}

	my $p = Net::Ping->new("icmp");
	my $result = $p->ping($hostname, 1);
	$p->close();

	if (!$result) {
		return 0;
	}
	else {
		return 1;
	}
} ## end sub _pingnode

#/////////////////////////////////////////////////////////////////////////////

=head2 getnewdbh

 Parameters  : none
 Returns     : 0 failed or database handle
 Description : gets a databasehandle

=cut

sub getnewdbh {
	#my $caller_trace = get_caller_trace(7, 1);
	#notify($ERRORS{'DEBUG'}, 0, "called from: $caller_trace");

	my ($database) = @_;
	$database = $DATABASE if !$database;

	my $dbh;

	# Try to use the existing database handle
	if ($ENV{dbh} && $ENV{dbh}->ping && $ENV{dbh}->{Name} =~ /^$database:/) {
		#notify($ERRORS{'DEBUG'}, 0, "using database handle stored in \$ENV{dbh}");
		return $ENV{dbh};
	}
	elsif ($ENV{dbh} && $ENV{dbh}->ping) {
		my ($stored_database_name) = $ENV{dbh}->{Name} =~ /^([^:]*)/;
		notify($ERRORS{'DEBUG'}, 0, "database requested ($database) does not match handle stored in \$ENV{dbh} (" . $ENV{dbh}->{Name} . ")");
	}
	elsif (defined $ENV{dbh}) {
		notify($ERRORS{'DEBUG'}, 0, "unable to use database handle stored in \$ENV{dbh}");
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "\$ENV{dbh} is not defined, creating new database handle");
	}

	my $attempt      = 0;
	my $max_attempts = 5;
	my $retry_delay  = 2;

	# Assemble the data source string
	my $data_source;
	if ($MYSQL_SSL) {
		$data_source = "$database:$SERVER;mysql_ssl=1;mysql_ssl_ca_file=$MYSQL_SSL_CERT";
	}
	else {
		$data_source = "$database:$SERVER";
	}

	# Attempt to connect to the data source and get a database handle object
	my $dbi_result;
	while (!$dbh && $attempt < $max_attempts) {
		$attempt++;

		# Attempt to connect
		#notify($ERRORS{'DEBUG'}, 0, "attempting to connect to data source: $data_source, user: " . string_to_ascii($WRTUSER) . ", pass: " . string_to_ascii($WRTPASS));
		$dbh = DBI->connect(qq{dbi:mysql:$data_source}, $WRTUSER, $WRTPASS, {PrintError => 0});

		# Check if connect was successful
		if ($dbh && $dbh->ping) {
			# Set InactiveDestroy = 1 for all dbh's belonging to child processes
			# Set InactiveDestroy = 0 for all dbh's belonging to vcld
			if (!defined $ENV{vcld} || !$ENV{vcld}) {
				$dbh->{InactiveDestroy} = 1;
			}
			else {
				$dbh->{InactiveDestroy} = 0;
			}

			# Increment the dbh count environment variable if it is defined
			# This is only for development and testing to see how many handles a process creates
			$ENV{dbh_count}++ if defined($ENV{dbh_count});

			# Store the newly created database handle in an environment variable
			# Only store it if $ENV{dbh} is already defined
			# It's up to other modules to determine if $ENV{dbh} is defined, they must initialize it
			if (defined $ENV{dbh}) {
				$ENV{dbh} = $dbh;
				notify($ERRORS{'DEBUG'}, 0, "database handle stored in \$ENV{dbh}");
			}

			return $dbh;
		} ## end if ($dbh && $dbh->ping)

		# Something went wrong, construct a DBI result string
		$dbi_result = "DBI result: ";
		if (defined(DBI::err())) {
			$dbi_result = "(" . DBI::err() . ")";
		}
		if (defined(DBI::errstr())) {
			$dbi_result .= " " . DBI::errstr();
		}

		# Check for access denied
		if (DBI::err() == 1045 || DBI::errstr() =~ /access denied/i) {
			notify($ERRORS{'WARNING'}, 0, "unable to connect to database, $dbi_result");
			return 0;
		}

		# Either connect or ping failed
		if ($dbh && !$dbh->ping) {
			notify($ERRORS{'DEBUG'}, 0, "database connect succeeded but ping failed, attempt $attempt/$max_attempts, $dbi_result");
			$dbh->disconnect;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "database connect failed, attempt $attempt/$max_attempts, $dbi_result");
		}

		notify($ERRORS{'DEBUG'}, 0, "sleeping for $retry_delay seconds");
		sleep $retry_delay;
		next;
	} ## end while (!$dbh && $attempt < $max_attempts)

	# Maximum number of attempts was reached
	notify($ERRORS{'WARNING'}, 0, "failed to connect to database, attempts made: $attempt/$max_attempts, $dbi_result");
	return 0;
} ## end sub getnewdbh

 #/////////////////////////////////////////////////////////////////////////////

=head2 notify_via_oascript

 Parameters  : $node, $user, $message
 Returns     : 0 or 1
 Description : using apple oascript write supplied $message to finder

=cut

sub notify_via_oascript {
        my ($node, $user, $message) = @_;
        my ($package, $filename, $line, $sub) = caller(0);

        notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
        notify($ERRORS{'WARNING'}, 0, "message is not defined") if (!(defined($message)));
        notify($ERRORS{'WARNING'}, 0, "user is not defined")    if (!(defined($user)));

        # Escape new lines
        $message =~ s/\n/ /gs;
        $message =~ s/\'/\\\\\\\'/gs;
        notify($ERRORS{'DEBUG'}, 0, "message:\n$message");

        my $command = "/var/root/VCL/oamessage \"$message\"";

        if (run_ssh_command($node, $ENV{management_node_info}{keys}, $command)) {
                notify($ERRORS{'OK'}, 0, "successfully sent message to OSX user $user on $node");
                return 1;
        }
        else {
                notify($ERRORS{'WARNING'}, 0, "failed to send message to OSX user $user on $node");
                return 0;
        }

} ## end sub notify_via_oascript

#/////////////////////////////////////////////////////////////////////////////

=head2 notify_via_wall

 Parameters  : empty
 Returns     : 0 or 1
 Description : talks to user at the console using wall

=cut

sub notify_via_wall {
	my ($hostname, $username, $string, $OSname, $type) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "hostname is not defined") if (!(defined($hostname)));
	notify($ERRORS{'WARNING'}, 0, "username is not defined") if (!(defined($username)));
	notify($ERRORS{'WARNING'}, 0, "string is not defined")   if (!(defined($string)));
	notify($ERRORS{'WARNING'}, 0, "OSname is not defined")   if (!(defined($OSname)));
	notify($ERRORS{'WARNING'}, 0, "type is not defined")     if (!(defined($type)));
	my @ssh;
	my $n;
	my $identity;
	#create file, copy to remote host, then run wall
	if (open(TMP, ">/tmp/wall.$hostname")) {
		print TMP $string;
		close TMP;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "could not open tmp file $!");
	}
	my $identity_keys = get_management_node_info()->{keys};
	if ($type eq "blade") {
		#this is only going to be rhel
		if (run_scp_command("/tmp/wall.$hostname", "$hostname:/root/wall.txt", $identity_keys)) {
			unlink "/tmp/wall.$hostname";
			if (run_ssh_command($hostname, $identity_keys, " cat /root/wall.txt \| wall; /bin/rm -v /root/wall.txt", "root")) {
				notify($ERRORS{'OK'}, 0, "successfully sent wall notification to $hostname");
				return 1;
			}
		}
	} ## end if ($type eq "blade")
	elsif ($type eq "lab") {
		
		if (run_scp_command("/tmp/wall.$hostname", "vclstaff\@$hostname:/home/vclstaff/wall.txt", $identity_keys, 24)) {
			unlink "/tmp/wall.$hostname";
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not scp tmp file for wall notification$!");
		}

		if ($OSname =~ /sun4x_/) {
			if (run_ssh_command($hostname, $identity_keys, "wall -a /home/vclstaff/wall.txt; /bin/rm -v /home/vclstaff/wall.txt", "vclstaff", "24")) {
				notify($ERRORS{'OK'}, 0, "successfully sent wall notification to $hostname");
				return 1;
			}
			else {
				notify($ERRORS{'OK'}, 0, "wall notification $hostname failed ");
			}
		}
		elsif ($OSname =~ /rhel/) {
			if (run_ssh_command($hostname, $identity_keys, "cat /home/vclstaff/wall.txt \| wall ; /bin/rm -v /home/vclstaff/wall.txt", "vclstaff", "24")) {
				notify($ERRORS{'OK'}, 0, "successfully sent wall notification to $hostname");
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "wall notification $hostname failed ");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "not an OS I can handle, os is $OSname");
		}
		return 1;
	} ## end elsif ($type eq "lab")  [ if ($type eq "blade")
} ## end sub notify_via_wall

#/////////////////////////////////////////////////////////////////////////////

=head2 notify_via_msg

 Parameters  : $node, $user, $message
 Returns     : 0 or 1
 Description : using windows msg.exe cmd writes supplied $message
					to windows user console

=cut

sub notify_via_msg {
	my ($node, $user, $message) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	my $osname = lc($^O);
	if ($osname =~ /win/i) {
		notify($ERRORS{'OK'}, 0, "notifying from Windows not yet supported\n-----\nTo: $user\nNode: $node\n$message\n-----");
		return;
	}
	notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "message is not defined") if (!(defined($message)));
	notify($ERRORS{'WARNING'}, 0, "user is not defined")    if (!(defined($user)));

	# Escape new lines
	$message =~ s/\n/ /gs;
	$message =~ s/\'/\\\\\\\'/gs;
	notify($ERRORS{'DEBUG'}, 0, "message:\n$message");

	my $command = "msg $user /TIME:180 '$message'";
	
	my $identity_keys = get_management_node_info()->{keys};
	if (run_ssh_command($node, $identity_keys, $command)) {
		notify($ERRORS{'OK'}, 0, "successfully sent message to Windows user $user on $node");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to send message to Windows user $user on $node");
		return 0;
	}

} ## end sub notify_via_msg

#/////////////////////////////////////////////////////////////////////////////

=head2 getpw

 Parameters  : length(optional) - if not defined sets to 6
 Returns     : randomized password
 Description : called for standalone accounts and used in randomizing
					privileged account passwords
=cut

sub getpw {

	my $length = $_[0];
	$length = 6 if (!(defined($length)));
	my @a = ("A" .. "H", "J" .. "N", "P" .. "Z", "a" .. "k", "m" .. "z", "2" .. "9");
	my $b;
	srand;
	for (1 .. $length) {
		$b .= $a[rand(57)];
	}
	return $b;

} ## end sub getpw

#/////////////////////////////////////////////////////////////////////////////

=head2 known_hosts

 Parameters  : $node , management OS, $ipaddress
 Returns     : 0 or 1
 Description : check for or add nodenames public rsa key to local known_hosts file

=cut

sub known_hosts {
	my ($node, $mnOS, $ipaddress) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'CRITICAL'}, 0, "node is not defined")      if (!(defined($node)));
	notify($ERRORS{'CRITICAL'}, 0, "mnOS is not defined")      if (!(defined($mnOS)));
	notify($ERRORS{'CRITICAL'}, 0, "ipaddress is not defined") if (!(defined($ipaddress)));

	my ($known_hosts, $existed, $ssh_keyscan, $port);
	#set up dependiences
	if ($mnOS eq "solaris") {
		$known_hosts = "/.ssh/known_hosts";
		$ssh_keyscan = "/local/openssh/bin/ssh-keyscan";
		$port        = 24;
	}
	elsif ($mnOS eq "linux") {
		$known_hosts = "/root/.ssh/known_hosts";
		$ssh_keyscan = "/usr/bin/ssh-keyscan";
		$port        = 24;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unsupported management node OS: $mnOS");
		return 0;
	}

	#remove key
	my @known_hosts_file;
	if (open(KNOWNHOSTS, "< $known_hosts")) {
		@known_hosts_file = <KNOWNHOSTS>;
		close(KNOWNHOSTS);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "could not read $known_hosts $!");
	}
	foreach my $l (@known_hosts_file) {
		if ($l =~ /$node|$ipaddress/) {
			$l       = "";
			$existed = 1;
		}
	}
	#write back
	if ($existed) {
		if (open(KNOWNHOSTS, ">$known_hosts")) {
			print KNOWNHOSTS @known_hosts_file;
			close(KNOWNHOSTS);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not write to $known_hosts file $!");
		}
	}
	#proceed to get public rsa key
	#notify($ERRORS{'OK'},0,"executing $ssh_keyscan -t rsa -p $port $node >> $known_hosts");
	if (open(KEYSCAN, "$ssh_keyscan -t rsa -p $port $node >> $known_hosts 2>&1|")) {
		my @ret = <KEYSCAN>;
		close(KEYSCAN);
		foreach my $r (@ret) {
			notify($ERRORS{'OK'}, 0, "$r");
			return 0 if ($r =~ /Name or service not known/);

		}
		return 1;
	} ## end if (open(KEYSCAN, "$ssh_keyscan -t rsa -p $port $node >> $known_hosts 2>&1|"...
	else {
		notify($ERRORS{'WARNING'}, 0, "could not execute append of $node public key to $known_hosts file $!");
		return 0;
	}
} ## end sub known_hosts

#/////////////////////////////////////////////////////////////////////////////

=head2 getusergroupmembers

 Parameters  : usergroupid
 Returns     : array of user group memebers
 Description : queries database and collects user members of supplied usergroupid

=cut

sub getusergroupmembers {
	my $usergroupid = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "usergroupid is not defined") if (!(defined($usergroupid)));

	if (!(defined($usergroupid))) {
		return ();
	}

	my $select_statement = "
   SELECT

   user.unityid,
   user.uid,
   user.id

   FROM
   user,
   usergroupmembers

   WHERE
   user.id = usergroupmembers.userid
   AND usergroupmembers.usergroupid = '$usergroupid'
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "no data returned for usergroupid $usergroupid returning empty lists");
		return ();
	}

	my %hash;
	my (@retarray);

	for (@selected_rows) {
		my %hash = %{$_};
		if(!defined($hash{uid})){
			$hash{uid} = 0;
		}
		push(@retarray, "$hash{unityid}:$hash{uid}:$hash{id}");
	}

	return @retarray;

} ## end sub getusergroupmembers



#/////////////////////////////////////////////////////////////////////////////

=head2 get_user_group_member_info

 Parameters  : $usergroupid
 Returns     : array of user group memebers
 Description : queries database and collects user members of supplied usergroupid

=cut

sub get_user_group_member_info {
	my ($user_group_id) = @_;
	
	if (!defined($user_group_id)) {
		notify($ERRORS{'WARNING'}, 0, "user group ID argument was not specified");
		return;
	}

	my $select_statement = <<EOF;
SELECT
user.*
FROM
user,
usergroupmembers
WHERE
user.id = usergroupmembers.userid
AND usergroupmembers.usergroupid = '$user_group_id'
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	if (!@selected_rows) {
		notify($ERRORS{'DEBUG'}, 0, "no data was returned for user group ID $user_group_id, returning an empty list");
		return {};
	}
	
	my $user_group_member_info;
	for my $row (@selected_rows) {
		my $user_id = $row->{id};
		for my $column (keys %$row) {
			next if $column eq 'id';
			$user_group_member_info->{$user_id}{$column} = $row->{$column};
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved member info for user group ID $user_group_id:\n" . format_data($user_group_member_info));
	return $user_group_member_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2  notifyviaIM

 Parameters  : IM type, IM user ID, message string
 Returns     : 0 or 1
 Description : if Jabber enabled - send IM to user
					currently only supports jabber

=cut

sub notify_via_IM {
	my ($im_type, $im_id, $im_message) = @_;
	
	notify($ERRORS{'WARNING'}, 0, "IM type is not defined") if (!(defined($im_type)));
	notify($ERRORS{'WARNING'}, 0, "IM id is not defined")   if (!(defined($im_id)));
	notify($ERRORS{'WARNING'}, 0, "IM message is not defined")  if (!(defined($im_message)));

	if ($im_type eq "jabber") {
		# Check if jabber functions are disabled on this management node
		if ($JABBER) {
			notify($ERRORS{'DEBUG'}, 0, "jabber functions are enabled on this management node");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "jabber functions are disabled on this management node");
			return 1;
		}
		
		# Create a jabber client object
		my $jabber_client = new Net::Jabber::Client();
		if ($jabber_client) {
			notify($ERRORS{'DEBUG'}, 0, "jabber client object created");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "failed to created jabber client object");
			return;
		}
		
		# Attempt to connect to the jabber server
		my $jabber_connect_result = $jabber_client->Connect(hostname => $JABBER_SERVER, port => $JABBER_PORT);
		if (!$jabber_connect_result) {
			notify($ERRORS{'DEBUG'}, 0, "connected to jabber server: $JABBER_SERVER, port: $JABBER_PORT, result: $jabber_connect_result");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to connect to jabber server: $JABBER_SERVER, port: $JABBER_PORT, result: $jabber_connect_result");
			return;
		}
		
		# Attempt to authenticate to jabber
		my @jabber_auth_result = $jabber_client->AuthSend(
			username => $JABBER_USER,
			password => $JABBER_PASSWORD,
			resource => $JABBER_RESOURCE
		);
		
		# Check the jabber authentication result
		if ($jabber_auth_result[0] && $jabber_auth_result[0] eq "ok") {
			notify($ERRORS{'DEBUG'}, 0, "authenticated to jabber server: $JABBER_SERVER, user: $JABBER_USER, resource: $JABBER_RESOURCE");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to authenticate to jabber server: $JABBER_SERVER, user: $JABBER_USER, resource: $JABBER_RESOURCE");
			return;
		}
	
		# Create jabber message
		my $jabber_message = Net::Jabber::Message->new();
		$jabber_message->SetMessage(
			to      => $im_id,
			subject => "Notification",
			type    => "chat",
			body    => $im_message
		);
		
		# Attempt to send the jabber message
		my $jabber_send_result = $jabber_client->Send($jabber_message);
		if ($jabber_send_result) {
			notify($ERRORS{'OK'}, 0, "jabber message sent to $im_id");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to send jabber message to $JABBER_USER");
			return;
		}
		
	} ## end if ($im_type eq "jabber" && defined $jabberready)
	
	else {
		notify($ERRORS{'WARNING'}, 0, "IM type is not supported: $im_type");
		return 0;
	}
	
	return 1;
} ## end sub notify_via_IM

#/////////////////////////////////////////////////////////////////////////////

=head2 insertloadlog

 Parameters  : $resid,   $computerid, $loadstatename, $additionalinfo
 Returns     : 0 or 1
 Description : accepts info from processes to update the loadlog table

=cut

sub insertloadlog {
	my ($resid,   $computerid, $loadstatename, $additionalinfo) = @_;
	my ($package, $filename,   $line,          $sub)            = caller(0);

	# Check the parameters
	if (!(defined($resid))) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to insert into computerloadlog, reservation id is not defined");
		return 0;
	}
	elsif (!($resid)) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to insert into computerloadlog, reservation id is 0");
		return 0;
	}

	if (!(defined($computerid))) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to insert into computerloadlog, computer id is not defined");
		return 0;
	}
	elsif (!($computerid)) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to insert into computerloadlog, computer id is 0");
		return 0;
	}

	if (!(defined($additionalinfo)) || !$additionalinfo) {
		notify($ERRORS{'WARNING'}, 0, "additionalinfo is either not defined or 0, using 'no additional info'");
		$additionalinfo = 'no additional info';
	}

	my $loadstateid;
	if (!(defined($loadstatename)) || !$loadstatename) {
		notify($ERRORS{'WARNING'}, 0, "loadstatename is either not defined or 0, using NULL");
		$loadstatename = 'NULL';
		$loadstateid   = 'NULL';
	}
	else {
		# loadstatename was specified as a parameter
		# Check if the loadstatename exists in the computerloadstate table
		my $select_statement = "
      SELECT DISTINCT
      computerloadstate.id
      FROM
      computerloadstate
      WHERE
      computerloadstate.loadstatename = '$loadstatename'
      ";

		my @selected_rows = database_select($select_statement);
		if ((scalar @selected_rows) == 0) {
			notify($ERRORS{'WARNING'}, 0, "computerloadstate table entry does not exist: $loadstatename, using NULL");
			$loadstateid   = 'NULL';
			$loadstatename = 'NULL';
		}
		else {
			$loadstateid = $selected_rows[0]{id};
			#notify($ERRORS{'DEBUG'}, 0, "computerloadstate id found: id=$loadstateid, name=$loadstatename");
		}
	} ## end else [ if (!(defined($loadstatename)) || !$loadstatename)

	# Escape any single quotes in additionalinfo
	$additionalinfo =~ s/\'/\\\'/g;

	# Assemble the SQL statement
	my $insert_loadlog_statement = "
   INSERT INTO
   computerloadlog
   (
      reservationid,
      computerid,
      loadstateid,
      timestamp,
      additionalinfo
   )
   VALUES
   (
      '$resid',
      '$computerid',
      '$loadstateid',
      NOW(),
      '$additionalinfo'
   )
   ";

	# Execute the insert statement, the return value should be the id of the computerloadlog row that was inserted
	my $loadlog_id = database_execute($insert_loadlog_statement);
	if ($loadlog_id) {
		notify($ERRORS{'OK'}, 0, "inserted computer=$computerid, $loadstatename, $additionalinfo");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert entry into computerloadlog table");
		return 0;
	}

	return 1;
} ## end sub insertloadlog

#/////////////////////////////////////////////////////////////////////////////

=head2 kill_reservation_process

 Parameters  : $request_state_name, $reservation_id
 Returns     : 0 or 1
 Description :

=cut

sub kill_reservation_process {
	my ($reservation_id) = @_;
	
	# Sanity check, make sure reservation id is valid
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation id is not defined");
		return;
	}
	if ($reservation_id !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "reservation id is not valid: $reservation_id");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "attempting to kill process for reservation $reservation_id");
	
	# Use the pkill utility to find processes matching the reservation ID
	# Do not use -9 or else DESTROY won't run
	my $pkill_command = "pkill -f ':$reservation_id ' 2>&1";
	notify($ERRORS{'DEBUG'}, 0, "executing pkill command: $pkill_command");
	
	my $pkill_output = `$pkill_command`;
	my $pkill_exit_status = $? >> 8;
	
	# Check the pgrep exit status
	if ($pkill_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "reservation $reservation_id process was killed, returning 1");
		return 1;
	}
	elsif ($? == -1) {
		notify($ERRORS{'OK'}, 0, "\$? is set to -1, Perl bug likely encountered, assuming reservation $reservation_id process was killed, returning 1");
		return 1;
	}
	elsif ($pkill_exit_status == 1) {
		notify($ERRORS{'OK'}, 0, "process was not found for reservation $reservation_id, returning 1");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "pkill error occurred, returning undefined, output:\n$pkill_output");
		return;
	}
	
} ## end sub kill_reservation_process

#/////////////////////////////////////////////////////////////////////////////

=head2 database_select

 Parameters  : SQL select statement
 Returns     : array containing hash references to rows returned
 Description : gets information from the database

=cut

sub database_select {
	my ($select_statement, $database) = @_;
	
	my $calling_sub = (caller(1))[3];
	
	# Initialize the database_select_calls element if not already initialized
	if (!ref($ENV{database_select_calls})) {
		$ENV{database_select_calls} = {};
	}
	
	# For performance tuning - count the number of calls
	$ENV{database_select_count}++;
	if (!defined($ENV{database_select_calls}{$calling_sub})) {
		$ENV{database_select_calls}{$calling_sub} = 1;
	}
	else {
		$ENV{database_select_calls}{$calling_sub}++;
	}
	
	my $dbh;
	if (!($dbh = getnewdbh($database))) {
		# Try again if first attempt failed
		if (!($dbh = getnewdbh($database))) {
			notify($ERRORS{'WARNING'}, 0, "unable to obtain database handle, " . DBI::errstr());
			return ();
		}
	}

	# Prepare the select statement handle
	my $select_handle;
	$select_handle = $dbh->prepare($select_statement);

	# Check the select statement handle
	if (!$select_handle) {
		notify($ERRORS{'WARNING'}, 0, "could not prepare select statement, $select_statement, " . $dbh->errstr());
		$dbh->disconnect if !defined $ENV{dbh};
		return ();
	}

	# Execute the statement handle
	if (!($select_handle->execute())) {
		notify($ERRORS{'WARNING'}, 0, "could not execute statement, $select_statement, " . $dbh->errstr());
		$select_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return ();
	}

	# Fetch all the rows returned by the select query
	# An array reference is created containing hash refs because {} is passed to fetchall_arrayref
	my @return_rows = @{$select_handle->fetchall_arrayref({})};
	$select_handle->finish;
	$dbh->disconnect if !defined $ENV{dbh};
	
	return @return_rows;
} ## end sub database_select

#/////////////////////////////////////////////////////////////////////////////

=head2 database_execute

 Parameters  : $sql_statement, $database (optional)
 Returns     : boolean
 Description : Executes an SQL statement. If $sql_statement is an INSERT
               statement, the ID of the row inserted is returned. For other
               statements such as UPDATE, the number of rows updated is
               returned.

=cut

sub database_execute {
	my ($sql_statement, $database) = @_;
	
	$ENV{database_execute_count}++;
	
	my $dbh;
	if (!($dbh = getnewdbh($database))) {
		# Try again if first attempt failed
		if (!($dbh = getnewdbh($database))) {
			notify($ERRORS{'WARNING'}, 0, "unable to obtain database handle, " . DBI::errstr());
			return;
		}
	}
	
	# Prepare the statement handle
	my $statement_handle = $dbh->prepare($sql_statement);
	
	# Check the statement handle
	if (!$statement_handle) {
		notify($ERRORS{'WARNING'}, 0, "could not prepare SQL statement, $sql_statement, " . $dbh->errstr());
		$dbh->disconnect if !defined $ENV{dbh};
		return;
	}
	
	# Execute the statement handle
	my $result = $statement_handle->execute();
	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "could not execute SQL statement, $sql_statement, " . $dbh->errstr());
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return;
	}
	
	# Get the id of the last inserted record if this is an INSERT statement
	if ($sql_statement =~ /insert/i) {
		my $sql_insertid = $statement_handle->{'mysql_insertid'};
		my $sql_warning_count = $statement_handle->{'mysql_warning_count'};
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		if($sql_insertid) {
			return $sql_insertid;
		}
		else {
			return $result;
		}
	}
	else {
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return $result;
	}

} ## end sub database_execute

#/////////////////////////////////////////////////////////////////////////////

=head2  get_request_info

 Parameters  : $request_id
 Returns     : hash
 Description : Retrieves all request/reservation information.

=cut


sub get_request_info {
	my ($request_id) = @_;
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not specified");
		return;
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my %tables = (
		'request' => 'request',
		'serverrequest' => 'serverrequest',
		'reservation' => 'reservation',
		'state' => 'state',
		'laststate' => 'state',
	);
	
	# Construct the select statement
	my $select_statement = "SELECT DISTINCT\n";
	
	# Get the column names for each table and add them to the select statement
	for my $table_alias (keys %tables) {
		my $table_name = $tables{$table_alias};
		my @columns = @{$database_table_columns->{$table_name}};
		for my $column (@columns) {
			$select_statement .= "$table_alias.$column AS '$table_alias-$column',\n";
		}
	}
	
	# Remove the comma after the last column line
	$select_statement =~ s/,$//;
	
	# Complete the select statement
	$select_statement .= <<EOF;

FROM
request
LEFT JOIN (serverrequest) ON (serverrequest.requestid = request.id),
reservation,
state,
state laststate

WHERE
request.id = $request_id
AND reservation.requestid = request.id
AND state.id = request.stateid
AND laststate.id = request.laststateid

GROUP BY
reservation.id
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure 1 or more rows were returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "info for request $request_id could not be retrieved from the database, select statement:\n$select_statement");
		return;
	}

	# Build the hash
	my $request_info;

	for my $reservation_row (@selected_rows) {
		my $reservation_id = $reservation_row->{'reservation-id'};
		if (!$reservation_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve request info, row does not contain a reservation-id value:\n" . format_data($reservation_row));
			return;
		}
		$request_info->{RESERVATIONID} = $reservation_id if (scalar @selected_rows == 1);
		
		# Loop through all the columns returned
		for my $key (keys %$reservation_row) {
			my $value = $reservation_row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			if ($table eq 'request') {
				$request_info->{$column} = $value;
			}
			elsif ($table eq 'reservation') {
				$request_info->{reservation}{$reservation_id}{$column} = $value;
			}
			elsif ($table eq 'serverrequest') {
				$request_info->{reservation}{$reservation_id}{serverrequest}{$column} = $value;
			}
			else {
				$request_info->{$table}{$column} = $value;
			}
		}
		
		# Store duration in epoch seconds format
		my $request_start_epoch = convert_to_epoch_seconds($request_info->{start});
		my $request_end_epoch = convert_to_epoch_seconds($request_info->{end});
		$request_info->{DURATION} = ($request_end_epoch - $request_start_epoch);
		
		# Add the image info to the hash
		my $image_id = $request_info->{reservation}{$reservation_id}{imageid};
		my $image_info = get_image_info($image_id, 1);
		$request_info->{reservation}{$reservation_id}{image} = $image_info;
		
		# Add the imagerevision info to the hash
		my $imagerevision_id = $request_info->{reservation}{$reservation_id}{imagerevisionid};
		my $imagerevision_info = get_imagerevision_info($imagerevision_id, 1);
		$request_info->{reservation}{$reservation_id}{imagerevision} = $imagerevision_info;
		
		# Add the computer info to the hash
		my $computer_id = $request_info->{reservation}{$reservation_id}{computerid};
		my $computer_info = get_computer_info($computer_id, 1);
		$request_info->{reservation}{$reservation_id}{computer} = $computer_info;
		
		# Add the connect method info to the hash
		my $connect_method_info = get_connect_method_info($imagerevision_id);
		$request_info->{reservation}{$reservation_id}{connect_methods} = $connect_method_info;
	
		# Add the managementnode info to the hash
		my $management_node_id = $request_info->{reservation}{$reservation_id}{managementnodeid};
		my $management_node_info = get_management_node_info($management_node_id);
		$request_info->{reservation}{$reservation_id}{managementnode} = $management_node_info;
		
		# Retrieve the user info and add to the hash
		my $user_id = $request_info->{userid};
		my $user_info = get_user_info($user_id, 0, 1);
		$request_info->{user} = $user_info;
		
		my $imagemeta_root_access = $request_info->{reservation}{$reservation_id}{image}{imagemeta}{rootaccess};
		
		# Add the request user to the hash, set ROOTACCESS to the value configured in imagemeta
		$request_info->{reservation}{$reservation_id}{users}{$user_id} = $user_info;
		$request_info->{reservation}{$reservation_id}{users}{$user_id}{ROOTACCESS} = $imagemeta_root_access;
		
		# If server request and logingroupid is set, add user group members to hash, set ROOTACCESS to 0
		if (my $login_group_id = $request_info->{reservation}{$reservation_id}{serverrequest}{logingroupid}) {
			my $login_group_member_info = get_user_group_member_info($login_group_id);
			for my $login_user_id (keys %$login_group_member_info) {
				$request_info->{reservation}{$reservation_id}{users}{$login_user_id} = get_user_info($login_user_id, 0, 1);
				$request_info->{reservation}{$reservation_id}{users}{$login_user_id}{ROOTACCESS} = 0;
			}
		}
		
		# If server request and admingroupid is set, add user group members to hash, set ROOTACCESS to 1
		if (my $admin_group_id = $request_info->{reservation}{$reservation_id}{serverrequest}{admingroupid}) {
			my $admin_group_member_info = get_user_group_member_info($admin_group_id);
			for my $admin_user_id (keys %$admin_group_member_info, $user_id) {
				$request_info->{reservation}{$reservation_id}{users}{$admin_user_id} = get_user_info($admin_user_id, 0, 1);
				$request_info->{reservation}{$reservation_id}{users}{$admin_user_id}{ROOTACCESS} = 1;
			}
		}
		
		# If server request or duration is greater >= 24 hrs disable user checks
		if ($request_info->{reservation}{$reservation_id}{serverrequest}{id}) {
			notify($ERRORS{'DEBUG'}, 0, "server sequest - disabling user checks");
			$request_info->{checkuser} = 0;
			$request_info->{reservation}{$reservation_id}{serverrequest}{ALLOW_USERS} = $request_info->{user}{unityid};
		}
		elsif ($request_info->{DURATION} >= (60 * 60 * 24) ){
			#notify($ERRORS{'DEBUG'}, 0, "request length > 24 hours, disabling user checks");
			$request_info->{checkuser} = 0;
		}
		
		$request_info->{reservation}{$reservation_id}{serverrequest}{id} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{fixedIP} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{fixedMAC} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{router} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{netmask} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{DNSservers} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{admingroupid} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{logingroupid} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{monitored} ||= 0;
		$request_info->{reservation}{$reservation_id}{serverrequest}{ALLOW_USERS} ||= 0;
		
		$request_info->{reservation}{$reservation_id}{READY} = '0';
	}
	
	# Set some default non-database values for the entire request
	# All data ever added to the hash should be initialized here
	$request_info->{PID}              = '';
	$request_info->{PPID}             = '';
	$request_info->{PARENTIMAGE}      = '';
	$request_info->{PRELOADONLY}      = '0';
	$request_info->{SUBIMAGE}         = '';
	$request_info->{CHECKTIME}        = '';
	$request_info->{NOTICEINTERVAL}   = '';
	$request_info->{RESERVATIONCOUNT} = scalar keys %{$request_info->{reservation}};
	$request_info->{UPDATED}          = '0';
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved request info:\n" . format_data($request_info));
	return %$request_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_managementnode_state

 Parameters  : management node info, state
 Returns     : 1 or 0
 Description : sets a given management node to maintenance

=cut

sub set_managementnode_state {
	my ($mninfo, $state) = @_;

	if(!(defined($state))){
		notify($ERRORS{'WARNING'}, 0, "state was not specified");
		return ();
	}
	if(!(defined($mninfo->{hostname}))){
		notify($ERRORS{'WARNING'}, 0, "management node hostname was not specified");
		return ();
	}
	if(!(defined($mninfo->{id}))){
		notify($ERRORS{'WARNING'}, 0, "management node ID was not specified");
		return ();
	}

	my $mn_ID = $mninfo->{id};
	my $mn_hostname = $mninfo->{hostname};

	# Construct the update statement
	my $update_statement = "
	   UPDATE
		managementnode,
		state
		SET
		managementnode.stateid = state.id
		WHERE
		state.name = '$state' AND 
		managementnode.id = '$mn_ID'
	 ";


	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful, return timestamp
		notify($ERRORS{'OK'}, 0, "Successfully updated management node $mn_hostname state to $state");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update database, management node $mn_hostname state to $state");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_requests

 Parameters  : management node id
 Returns     : hash
 Description : gets request information for a particular management node

=cut


sub get_management_node_requests {
	my ($management_node_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	if (!(defined($management_node_id))) {
		notify($ERRORS{'WARNING'}, 0, "management node ID was not specified");
		return ();
	}

	my $select_statement = "
   SELECT DISTINCT

   request.id AS request_id,
   request.stateid AS request_stateid,
   request.laststateid AS request_laststateid,
   request.logid AS request_logid,
   request.start AS request_start,
   request.end AS request_end,
   request.daterequested AS request_daterequested,
   request.datemodified AS request_datemodified,
   request.preload AS request_preload,

   requeststate.name AS requeststate_name,

	requestlaststate.name AS requestlaststate_name,

   reservation.id AS reservation_id,
   reservation.requestid AS reservation_requestid,
   reservation.managementnodeid AS reservation_managementnodeid,
	reservation.lastcheck AS reservation_lastcheck

   FROM
   request,
   reservation,
	state requeststate,
   state requestlaststate

   WHERE
   reservation.managementnodeid = $management_node_id
   AND reservation.requestid = request.id
   AND requeststate.id = request.stateid
	AND requestlaststate.id = request.laststateid

   GROUP BY
   reservation.id
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows == 0) {
		return ();
	}

	# Build the hash
	my %requests;

	for (@selected_rows) {
		my %reservation_row = %{$_};

		# Grab the request and reservation IDs to make the code a little cleaner
		my $request_id     = $reservation_row{request_id};
		my $reservation_id = $reservation_row{reservation_id};

		# Loop through all the columns returned for the reservation
		foreach my $key (keys %reservation_row) {
			my $value = $reservation_row{$key};

			# Create another variable by stripping off the column_ part of each key
			# This variable stores the original (correct) column name
			(my $original_key = $key) =~ s/^.+_//;

			if ($key =~ /request_/) {
				# Set the top-level key if not already set
				$requests{$request_id}{$original_key} = $value if (!$requests{$request_id}{$original_key});
			}
			elsif ($key =~ /requeststate_/) {
				$requests{$request_id}{state}{$original_key} = $value if (!$requests{$request_id}{state}{$original_key});
			}
			elsif ($key =~ /requestlaststate_/) {
				$requests{$request_id}{laststate}{$original_key} = $value if (!$requests{$request_id}{laststate}{$original_key});
			}
			elsif ($key =~ /reservation_/) {
				$requests{$request_id}{reservation}{$reservation_id}{$original_key} = $value;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
			}

		}    # Close foreach key in reservation row
	}    # Close loop through selected rows

	# Each selected row represents a reservation associated with this request
	
	return %requests;
} ## end sub get_management_node_requests


#/////////////////////////////////////////////////////////////////////////////

=head2  get_image_info

 Parameters  : $image_identifier, $no_cache (optional), $ignore_error (optional)
 Returns     : hash reference
 Description : Retrieves info for the image specified by the argument. The
               argument can either be the image ID or image name.

=cut


sub get_image_info {
	my ($image_identifier, $no_cache, $ignore_error) = @_;
	if (!defined($image_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "image identifier argument was not specified");
		return;
	}
	
	# Check if cached image info exists
	if (!$no_cache && defined($ENV{image_info}{$image_identifier})) {
		# Check the time the info was last retrieved
		my $data_age_seconds = (time - $ENV{image_info}{$image_identifier}{RETRIEVAL_TIME});
		if ($data_age_seconds < 600) {
			return $ENV{image_info}{$image_identifier};
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieving current image info for '$image_identifier' from database, cached data is stale: $data_age_seconds seconds old");
		}
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'image',
		'platform',
		'OS',
		'OStype',
		'imagetype',
		'module',
	);
	
	# Construct the select statement
	my $select_statement = "SELECT DISTINCT\n";
	
	# Get the column names for each table and add them to the select statement
	for my $table (@tables) {
		my @columns = @{$database_table_columns->{$table}};
		for my $column (@columns) {
			$select_statement .= "$table.$column AS '$table-$column',\n";
		}
	}
	
	# Remove the comma after the last column line
	$select_statement =~ s/,$//;
	
	# Complete the select statement
	$select_statement .= <<EOF;
FROM
image,
platform,
OS,
OStype,
imagetype,
module

WHERE
platform.id = image.platformid
AND OS.id = image.OSid
AND OS.type = OStype.name
AND image.imagetypeid = imagetype.id
AND module.id = OS.moduleid
AND 
EOF
	
	if ($image_identifier =~ /^\d+$/){
		$select_statement .= "image.id = $image_identifier";
	}
	else {
		$image_identifier =~ s/(-v)\d+$/$1/g;
		$select_statement .= "image.name LIKE '$image_identifier\%'";
	}
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		if ($ignore_error) {
			notify($ERRORS{'DEBUG'}, 0, "image does NOT exist in the database: $image_identifier");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select statement:\n$select_statement");
		}
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}

	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	
	# Construct a hash with all of the image info
	my $image_info;
	
	# Loop through all the columns returned
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Split the table-column names
		my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
		
		# Add the values for the primary table to the hash
		# Add values for other tables under separate keys
		if ($table eq $tables[0]) {
			$image_info->{$column} = $value;
		}
		elsif ($table =~ /^(module|OStype)$/) {
			$image_info->{OS}{$table}{$column} = $value;
		}
		else {
			$image_info->{$table}{$column} = $value;
		}
	}
	
	# Retrieve the imagemeta info and add it to the hash
	my $imagemeta_id = $image_info->{imagemetaid};
	my $imagemeta_info = get_imagemeta_info($imagemeta_id);
	$image_info->{imagemeta} = $imagemeta_info;

	my $image_owner_id = $image_info->{ownerid};
	my $image_owner_user_info = get_user_info($image_owner_id);
	$image_info->{owner} = $image_owner_user_info;
	
	$image_info->{IDENTITY} = get_management_node_info()->{keys};
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for image '$image_identifier':\n" . format_data($image_info));
	$ENV{image_info}{$image_identifier} = $image_info;
	$ENV{image_info}{$image_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{image_info}{$image_identifier};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_info

 Parameters  : $imagerevision_identifier, $no_cache (optional)
 Returns     : Hash reference
 Description : collects data from database on supplied $imagerevision_id

=cut

sub get_imagerevision_info {
	my ($imagerevision_identifier, $no_cache) = @_;
	if (!defined($imagerevision_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision identifier argument was not specified");
		return;
	}
	
	# Check if cached imagerevision info exists
	if (!$no_cache && defined($ENV{imagerevision_info}{$imagerevision_identifier})) {
		# Check the time the info was last retrieved
		my $data_age_seconds = (time - $ENV{imagerevision_info}{$imagerevision_identifier}{RETRIEVAL_TIME});
		if ($data_age_seconds < 600) {
			return $ENV{imagerevision_info}{$imagerevision_identifier};
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieving current imagerevision info for '$imagerevision_identifier' from database, cached data is stale: $data_age_seconds seconds old");
		}
	}

	my $select_statement = <<EOF;
SELECT
imagerevision.*
FROM
imagerevision
WHERE
EOF

	# Check input value - complete select_statement
	if($imagerevision_identifier =~ /^\d/){
		$select_statement .= "imagerevision.id = '$imagerevision_identifier'";
	}
	else{
		$select_statement .= "imagerevision.imagename = \'$imagerevision_identifier\'";
	}

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision '$imagerevision_identifier' was not found in the database, 0 rows were returned from database select statement:\n$select_statement");
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}
	
	my $imagerevision_info = $selected_rows[0];
	
	# Retrieve the image info
	my $imagerevision_image_id = $imagerevision_info->{imageid};
	my $imagerevision_image_info = get_image_info($imagerevision_image_id);
	if (!$imagerevision_image_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve imagerevision info, image info could not be retrieved for image ID: $imagerevision_image_id");
		return;
	}
	$imagerevision_info->{image} = $imagerevision_image_info;
	
	# Retrieve the imagerevision user info
	$imagerevision_info->{user} = get_user_info($imagerevision_info->{userid});
	
	# Add the info to %ENV so it doesn't need to be retrieved from the database again
	$ENV{imagerevision_info}{$imagerevision_identifier} = $imagerevision_info;
	$ENV{imagerevision_info}{$imagerevision_identifier}{RETRIEVAL_TIME} = time;
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info from database for imagerevision '$imagerevision_identifier':\n" . format_data($ENV{imagerevision_info}{$imagerevision_identifier}));
	return $ENV{imagerevision_info}{$imagerevision_identifier};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_production_imagerevision_info

 Parameters  : $image_id, $no_cache (optional)
 Returns     : Hash containing imagerevision data for the production revision of an image
 Description :

=cut


sub get_production_imagerevision_info {
	my ($image_identifier, $no_cache) = @_;

	# Check the passed parameter
	if (!defined($image_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision identifier argument was not specified");
		return;
	}
	
	return $ENV{production_imagerevision_info}{$image_identifier} if (!$no_cache && $ENV{production_imagerevision_info}{$image_identifier});
	
	my $select_statement = <<EOF;
SELECT
id
FROM
imagerevision
WHERE
imagerevision.production = '1'
AND 
EOF

	# Check input value - complete select_statement
	if($image_identifier =~ /^\d/){
		$select_statement .= "imagerevision.imageid = '$image_identifier'";
	}
	else {
		# Assume $image_identifier is the image name, strip off '-v*' from the end
		# Otherwise query may fail if production version is not the exact revision passed as the argument
		$image_identifier =~ s/-v\d+$/-v%/;
		$select_statement .= "imagerevision.imagename LIKE \'$image_identifier\'";
	}

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "production imagerevision for image '$image_identifier' was not found in the database, 0 rows were returned, select statement:\n$select_statement");
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}
	
	my $imagerevision_id = $selected_rows[0]{id};
	
	my $imagerevision_info = get_imagerevision_info($imagerevision_id);
	
	my $image_name = $imagerevision_info->{imagename};
	$ENV{production_imagerevision_info}{$image_identifier} = $imagerevision_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved info from database for production revision for image identifier '$image_identifier', production image: '$image_name'");
	return $ENV{production_imagerevision_info}{$image_identifier};
	
} ## end sub get_production_imagerevision_info

#/////////////////////////////////////////////////////////////////////////////

=head2 get_imagemeta_info

 Parameters  : $imagemeta_id, $no_cache (optional)
 Returns     : Hash reference
 Description :

=cut


sub get_imagemeta_info {
	my ($imagemeta_id, $no_cache) = @_;
	
	my $default_imagemeta_info = get_default_imagemeta_info();
	
	# Return defaults if nothing was passed as the imagemeta id
	if (!$imagemeta_id) {
		return $default_imagemeta_info;
	}
	
	if (!$no_cache && $ENV{imagemeta_info}{$imagemeta_id}) {
		return $ENV{imagemeta_info}{$imagemeta_id};
	}
	
	# If imagemetaid isnt' NULL, perform another query to get the meta info
	my $select_statement = <<EOF;
SELECT
imagemeta.*
FROM
imagemeta
WHERE
imagemeta.id = '$imagemeta_id'
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure 1 row was returned
	if (!@selected_rows || scalar @selected_rows > 1) {
		$ENV{imagemeta_info}{$imagemeta_id} = $default_imagemeta_info;
		
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve imagemeta ID=$imagemeta_id, returning default imagemeta values");
		return $ENV{imagemeta_info}{$imagemeta_id};
	}

	# Get the single row returned from the select statement
	my $imagemeta_info = $selected_rows[0];
	
	for my $column (keys %$imagemeta_info) {
		if (!defined($imagemeta_info->{$column})) {
			$imagemeta_info->{$column} = $default_imagemeta_info->{$column};
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved imagemeta info:\n" . format_data($imagemeta_info));
	$ENV{imagemeta_info}{$imagemeta_id} = $imagemeta_info;
	return $ENV{imagemeta_info}{$imagemeta_id};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_default_imagemeta_info

 Parameters  : 
 Returns     : Hash reference
 Description :

=cut


sub get_default_imagemeta_info {
	if ($ENV{imagemeta_info}{default}) {
		# Create a copy to ensure that the correct default data is returned
		# Other processes may use the same cached copy
		# If the same reference is returned for multiple processes, one process may alter the data
		my %default_imagemeta_info = %{$ENV{imagemeta_info}{default}};
		return \%default_imagemeta_info;
	}
	
	# Call the database select subroutine to retrieve the imagemeta table structure
	my $describe_imagemeta_statement = "DESCRIBE imagemeta";
	my @describe_imagemeta_rows = database_select($describe_imagemeta_statement);
	if (!@describe_imagemeta_rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve imagemeta table structure, SQL statement:\n$describe_imagemeta_statement");
		return;
	}
	
	my $default_imagemeta_info;
	for my $describe_imagemeta_row (@describe_imagemeta_rows) {
		my $field = $describe_imagemeta_row->{Field};
		my $default_value = $describe_imagemeta_row->{Default};
		if (defined($default_value)) {
			$default_imagemeta_info->{$field} = $default_value;
		}
		else {
			$default_imagemeta_info->{$field} = '';
		}
	}
	
	$ENV{imagemeta_info}{default} = $default_imagemeta_info;
	
	my %default_imagemeta_info_copy = %{$ENV{imagemeta_info}{default}};
	#notify($ERRORS{'DEBUG'}, 0, "retrieved default imagemeta info:\n" . format_data(\%default_imagemeta_info_copy));
	return \%default_imagemeta_info_copy;
}


#/////////////////////////////////////////////////////////////////////////////

=head2  get_vmhost_info

 Parameters  : $vmhost_id
 Returns     : Hash reference
 Description : Retrieves info from the database for the vmhost, vmprofile, and
               repository and datastore imagetypes.

=cut


sub get_vmhost_info {
	my ($vmhost_id) = @_;
	
	# Check the passed parameter
	if (!defined($vmhost_id)) {
		notify($ERRORS{'WARNING'}, 0, "vmhost ID argument was not specified");
		return;
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my %tables = (
		'vmhost' => 'vmhost',
		'vmprofile' => 'vmprofile',
		'repositoryimagetype' => 'imagetype',
		'datastoreimagetype' => 'imagetype',
	);
	
	# Construct the select statement
	my $select_statement = "SELECT\n";
	
	# Get the column names for each table and add them to the select statement
	for my $table_alias (keys %tables) {
		my $table_name = $tables{$table_alias};
		my @columns = @{$database_table_columns->{$table_name}};
		for my $column (@columns) {
			$select_statement .= "$table_alias.$column AS '$table_alias-$column',\n";
		}
	}
	
	# Remove the comma after the last column line
	$select_statement =~ s/,$//;
	
	# Complete the select statement
	$select_statement .= <<EOF;
FROM
vmhost,
vmprofile,
imagetype repositoryimagetype,
imagetype datastoreimagetype

WHERE
vmhost.id = '$vmhost_id'
AND vmprofile.id = vmhost.vmprofileid
AND vmprofile.repositoryimagetypeid = repositoryimagetype.id
AND vmprofile.datastoreimagetypeid = datastoreimagetype.id
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select statement:\n$select_statement");
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}

	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	
	# Construct a hash with all of the vmhost info
	my $vmhost_info;
	
	# Loop through all the columns returned
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Split the table-column names
		my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
		
		# Add the values for the vmhost table to the hash
		# Add values for other tables under separate keys
		if ($table eq 'vmhost') {
			$vmhost_info->{$column} = $value;
		}
		else {
			$vmhost_info->{$table}{$column} = $value;
		}
	}
	
	# Get the vmhost computer info and add it to the hash
	my $computer_id = $vmhost_info->{computerid};
	my $computer_info = get_computer_info($computer_id);
	if ($computer_info) {
		$vmhost_info->{computer} = $computer_info;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve vmhost computer info, computer ID: $computer_id");
	}
	
	# Get the vmprofile image info and add it to the hash
	my $vmprofile_image_identifier = $vmhost_info->{vmprofile}{imageid};
	$vmprofile_image_identifier = 'noimage' if !$vmprofile_image_identifier;
	my $vmprofile_image_info = get_image_info($vmprofile_image_identifier);
	if ($vmprofile_image_info) {
		$vmhost_info->{vmprofile}{image} = $vmprofile_image_info;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve vmprofile image info, image identifier: $vmprofile_image_identifier");
	}
	
	$vmhost_info->{vmprofile}{username} = '' if !$vmhost_info->{vmprofile}{username};
	$vmhost_info->{vmprofile}{password} = '' if !$vmhost_info->{vmprofile}{password};
	
	# Decrypt the vmhost password
	if ($vmhost_info->{vmprofile}{rsakey} && -f $vmhost_info->{vmprofile}{rsakey} && $vmhost_info->{vmprofile}{encryptedpasswd}) {
		# Read the private keyfile into a string
        local $/ = undef;
        open FH, $vmhost_info->{vmprofile}{rsakey} or
                notify($ERRORS{'WARNING'}, 0, "Could not read private keyfile (" . $vmhost_info->{vmprofile}{rsakey} . "): $!");
        my $key = <FH>;
        close FH;
		if ($key) {
			my $encrypted = $vmhost_info->{vmprofile}{encryptedpasswd};
			my $rsa = Crypt::OpenSSL::RSA->new_private_key($key);
			# Croak on an invalid key
			$rsa->check_key;
			# Use the same padding algorithm as the PHP code
			$rsa->use_pkcs1_oaep_padding;
			# Convert password from hex to binary, decrypt
			# and store in the vmprofile.password field
			$vmhost_info->{vmprofile}{password} = $rsa->decrypt(pack("H*", $encrypted));
			notify($ERRORS{'DEBUG'}, 0, "decrypted vmprofile password with key: " . $vmhost_info->{vmprofile}{rsakey});
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to decrypt vmprofile password");    
		}
	}
	# Clean up the extraneous data
	delete $vmhost_info->{vmprofile}{rsakey};
	delete $vmhost_info->{vmprofile}{encryptedpassword};
	
	$vmhost_info->{vmprofile}{vmpath} = $vmhost_info->{vmprofile}{datastorepath} if !$vmhost_info->{vmprofile}{vmpath};
	$vmhost_info->{vmprofile}{virtualdiskpath} = $vmhost_info->{vmprofile}{vmpath} if !$vmhost_info->{vmprofile}{virtualdiskpath};
	
	return $vmhost_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 run_ssh_command

 Parameters  : $node, $identity_path, $command, $user, $port, $output_level, $timeout_seconds
					-or-
					Hash reference with the following keys:
						node - node name (required)
						command - command to be executed remotely (required)
						identity_paths - string containing paths to identity key files separated by commas (optional)
						user - user to run remote command as (optional, default is 'root')
						port - SSH port number (optional, default is 22)
						output_level - allows the amount of output to be controlled: 0, 1, or 2 (optional)
						max_attempts - maximum number of SSH attempts to make
						timeout_seconds - maximum number seconds SSH process can run before being terminated
 Returns     : If successful: array:
                  $array[0] = the exit status of the command
					   $array[1] = reference to array containing lines of output
					If failed: false
 Description : Runs an SSH command on the specified node.

=cut

sub run_ssh_command {
	my ($node, $identity_paths, $command, $user, $port, $output_level, $timeout_seconds) = @_;
	
	my $max_attempts = 3;
	
	if (ref($_[0]) eq 'HASH') {
		my $arguments = shift;
		
		$node = $arguments->{node};
		$command = $arguments->{command};
		$identity_paths = $arguments->{identity_paths} || '';
		$user = $arguments->{user} || 'root';
		$port = $arguments->{port} || '22';
		$output_level = $arguments->{output_level};
		$max_attempts = $arguments->{max_attempts} || 3;
		$timeout_seconds = $arguments->{timeout};
	}
	
	# Determine the output level if it was specified
	# Set $output_level to 0, 1, or 2
	if (!defined($output_level)) {
		$output_level = 2;
	}
	elsif ($output_level =~ /0|none/i) {
		$output_level = 0;
	}
	elsif ($output_level =~ /1|min/i) {
		$output_level = 1;
	}
	else {
		$output_level = 2;
	}
	
	# Check the arguments
	if (!defined($node) || !$node) {
		notify($ERRORS{'WARNING'}, 0, "computer node was not specified");
		return 0;
	}
	if (!defined($command) || !$command) {
		notify($ERRORS{'WARNING'}, 0, "command was not specified");
		return 0;
	}

	# Set default values if not passed as an argument
	$user = "root" if (!$user);
	$port = 22 if (!$port);
	$timeout_seconds = 0 if (!$timeout_seconds);
	$identity_paths = get_management_node_info()->{keys} if (!defined $identity_paths || length($identity_paths) == 0);

#return VCL::Module::OS::execute_new($node, $command, $output_level, $timeout_seconds, $max_attempts, $port, $user, '', $identity_paths);
	
	# TODO: Add ssh path to config file and set global variable
	# Locate the path to the ssh binary
	my $ssh_path;
	if (-f '/usr/bin/ssh') {
		$ssh_path = '/usr/bin/ssh';
	}
	elsif (-f 'C:/cygwin/bin/ssh.exe') {
		$ssh_path = 'C:/cygwin/bin/ssh.exe';
	}
	elsif (-f 'D:/cygwin/bin/ssh.exe') {
		$ssh_path = 'D:/cygwin/bin/ssh.exe';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to locate the SSH executable in the usual places");
		return 0;
	}

	# Format the identity path string
	if (defined $identity_paths && length($identity_paths) > 0) {
		# Add -i to beginning of string
		$identity_paths = "-i $identity_paths";
		
		# Split string on commas, add -i to each value after a comma
		$identity_paths =~ s/\s*,\s*/ -i /g;
		
		# Add a space to the end of the string
		$identity_paths .= ' ';
	}
	else {
		$identity_paths = '';
	}

	#notify($ERRORS{'DEBUG'}, 0, "ssh path: $ssh_path");
	#notify($ERRORS{'DEBUG'}, 0, "node: $node, identity file paths: $identity_paths, user: $user, port: $port");
	#notify($ERRORS{'DEBUG'}, 0, "command: $command");
	
	#if ($command =~ /['\\]/) {
	#	my @octals = map { "0" . sprintf("%o", $_) } unpack("C*", $command);
	#	my $octal_string = '\\' . join("\\", @octals);
	#	$command = "echo -e \"$octal_string\" | \$SHELL";
	#	notify($ERRORS{'DEBUG'}, 0, "octal command:\n$command");
	#}

	# Assemble the SSH command
	# -i <identity_file>, Selects the file from which the identity (private key) for RSA authentication is read.
	# -l <login_name>, Specifies the user to log in as on the remote machine.
	# -p <port>, Port to connect to on the remote host.
	# -x, Disables X11 forwarding.
	# Dont use: -q, Quiet mode.  Causes all warning and diagnostic messages to be suppressed.
	my $ssh_command = "$ssh_path $identity_paths ";
	$ssh_command .= "-o StrictHostKeyChecking=no ";
	$ssh_command .= "-o UserKnownHostsFile=/dev/null ";
	$ssh_command .= "-o ConnectionAttempts=1 ";
	$ssh_command .= "-o ConnectTimeout=3 ";
	$ssh_command .= "-o BatchMode=no ";
	$ssh_command .= "-o PasswordAuthentication=no ";
	$ssh_command .= "-l $user ";
	$ssh_command .= "-p $port ";
	$ssh_command .= "-x ";
	$ssh_command .= "$node '$command' 2>&1";
	
	# Execute the command
	my $ssh_output = '';
	my $ssh_output_formatted = '';
	my $attempts = 0;
	my $exit_status = 255;
	
	my $banner_exchange_error_count = 0;
	my $banner_exchange_error_limit = 3;
	
	# Make multiple attempts if failure occurs
	while ($attempts < $max_attempts) {
		$attempts++;
		
		# Delay performing next attempt if this isn't the first attempt
		if ($attempts > 1) {
			my $delay_seconds = (2 * ($attempts - 1));
			notify($ERRORS{'DEBUG'}, 0, "sleeping for $delay_seconds seconds before making next SSH attempt") if $output_level;
			sleep $delay_seconds;
		}
		
		## Add -v (verbose) argument to command if this is the 2nd attempt
		#$ssh_command =~ s/$ssh_path/$ssh_path -v/ if $attempts == 2;
		
		# Print the SSH command, only display the attempt # if > 1
		if ($attempts == 1) {
			notify($ERRORS{'DEBUG'}, 0, "executing SSH command on $node: '$command'") if $output_level;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: executing SSH command on $node: '$ssh_command'") if $output_level;
		}
		
		# Enclose SSH command in an eval block and use alarm to eventually timeout the SSH command if it hangs
		my $start_time = time;
		eval {
			# Override the die and alarm handlers
			local $SIG{__DIE__} = sub{};
			local $SIG{ALRM} = sub { die "alarm\n" };
			
			if ($timeout_seconds) {
				notify($ERRORS{'DEBUG'}, 0, "waiting up to $timeout_seconds seconds for SSH process to finish");
				alarm $timeout_seconds;
			}
			
			# Execute the command
			$ssh_output = `$ssh_command`;
			
			# Save the exit status
			$exit_status = $? >> 8;
			
			# Ignore the returned value of $? if it is -1
			# This likely means a Perl bug was encountered
			# Assume command was successful
			if ($? == -1) {
				notify($ERRORS{'DEBUG'}, 0, "exit status changed from $exit_status to 0, Perl bug likely encountered") if $output_level;
				$exit_status = 0;
			}
			
			if ($timeout_seconds) {
				# Cancel the timer
				alarm 0;
			}
		};
	
		my $duration = (time - $start_time);
		
		# Check if the timeout was reached
		if ($EVAL_ERROR && $EVAL_ERROR eq "alarm\n") {
			# Kill the child processes of this reservation process
			kill_child_processes($PID);
			
			if ($max_attempts == 1 || $attempts < $max_attempts) {
				notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: SSH command timed out after $duration seconds, timeout threshold: $timeout_seconds seconds, command: $node:\n$ssh_command");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "attempt $attempts/$max_attempts: SSH command timed out after $duration seconds, timeout threshold: $timeout_seconds seconds, command: $node:\n$ssh_command");
				return;
			}
			next;
		}
		elsif ($EVAL_ERROR) {
			notify($ERRORS{'CRITICAL'}, 0, "attempt $attempts/$max_attempts: eval error was generated attempting to run SSH command: $node:\n$ssh_command, error: $EVAL_ERROR");
			next;
		}
		
		# Strip out the key warning message from the output
		$ssh_output =~ s/\@{10,}.*man-in-the-middle attacks\.//igs;
		
		# Strip out known SSH warning messages
		#    Warning: Permanently added 'blade1b2-8' (RSA) to the list of known hosts.
		# 
		#    Warning: the RSA host key for 'vi1-62' differs from the key for the IP address '10.25.7.62'
		#    Offending key for IP in /root/.ssh/known_hosts:264
		#    Matching host key in /root/.ssh/known_hosts:3977
		#    Address x.x.x.x maps to y.y.org, but this does not map back to the address - POSSIBLE BREAK-IN ATTEMPT!
		$ssh_output =~ s/^(Warning:.*[\r\n]+)+//ig;
		$ssh_output =~ s/Offending key.*//ig;
		$ssh_output =~ s/Matching host key in.*//ig;
		$ssh_output =~ s/.*POSSIBLE BREAK-IN ATTEMPT.*//ig;
		$ssh_output =~ s/.*ssh-askpass:[^\n]*//igs;
		$ssh_output =~ s/.*bad permissions:[^\n]*//igs;
		
		# Remove any spaces from the beginning and end of the output
		$ssh_output =~ s/(^\s+)|(\s+$)//g;

		# Set the output string to none if no output was produced
		$ssh_output = '' if !$ssh_output;

		# Replace line breaks in the output with \n$pid| SSH output:
		my $pid = $$;
		$ssh_output_formatted = $ssh_output;

		# Get a slice of the SSH output if there are many lines
		my @ssh_output_formatted_lines = split("\n", $ssh_output_formatted);
		my $ssh_output_formatted_line_count = scalar @ssh_output_formatted_lines;
		if ($ssh_output_formatted_line_count > 50) {
			@ssh_output_formatted_lines = @ssh_output_formatted_lines[0 .. 49];
			push(@ssh_output_formatted_lines, "displayed first 50 of $ssh_output_formatted_line_count SSH output lines");
			$ssh_output_formatted = join("\n", @ssh_output_formatted_lines);
		}

		my $command_prefix = substr($command, 0, 10);
		$command_prefix .= "..." if (length($command) > 10);
		$ssh_output_formatted =~ s/\r//g;
		$ssh_output_formatted =~ s/^/ssh output ($command_prefix): /g;
		$ssh_output_formatted =~ s/\n/\nssh output ($command_prefix): /g;

		# Check the exit status
		# ssh exits with the exit status of the remote command or with 255 if an error occurred.
		# Check for vmware-cmd usage message, it returns 255 if the vmware-cmd usage output is returned
		if ($ssh_output_formatted =~ /ssh:.*(lost connection|reset by peer|no route to host|connection refused|connection timed out|resource temporarily unavailable|connection reset)/i) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: failed to execute SSH command on $node: '$command', exit status: $exit_status, output:\n$ssh_output_formatted") if $output_level;
			next;
		}
		elsif ($ssh_output_formatted =~ /(Connection timed out during banner exchange)/i) {
			$banner_exchange_error_count++;
			if ($banner_exchange_error_count >= $banner_exchange_error_limit) {
				notify($ERRORS{'WARNING'}, 0, "failed to execute SSH command on $node, encountered $banner_exchange_error_count banner exchange errors");
				return ();
			}
			else {
				# Don't count against attempt limit
				$attempts--;
				my $banner_exchange_delay_seconds = ($banner_exchange_error_count * 2);
				notify($ERRORS{'DEBUG'}, 0, "encountered banner exchange error on $node, sleeping for $banner_exchange_delay_seconds seconds, command:\n$command\noutput:\n$ssh_output") if $output_level;
				sleep $banner_exchange_delay_seconds;
				next;
			}
		}
		elsif ($exit_status == 255 && $ssh_command !~ /(vmware-cmd|vim-cmd|vmkfstools|vmrun)/i) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: failed to execute SSH command on $node: '$command', exit status: $exit_status, SSH exits with the exit status of the remote command or with 255 if an error occurred, output:\n$ssh_output_formatted") if $output_level;
			next;
		}
		else {
			# SSH command was executed successfully, actual command on node may have succeeded or failed
			
			# Split the output up into an array of lines
			my @output_lines = split(/[\r\n]+/, $ssh_output);
			
			# Print the output unless no_output is set
			notify($ERRORS{'DEBUG'}, 0, "command: '$command', output:\n" . join("\n", @output_lines)) if $output_level > 1;
			
			# Return the exit status and output
			return ($exit_status, \@output_lines);
		}
	} ## end while ($attempts < $max_attempts)

	# Failure, SSH command did not run at all
	notify($ERRORS{'WARNING'}, 0, "failed to run SSH command after $attempts attempts, command: $ssh_command, exit status: $exit_status, output:\n$ssh_output_formatted") if $output_level;
	return ();

} ## end sub run_ssh_command

#/////////////////////////////////////////////////////////////////////////////

=head2 run_scp_command

 Parameters  : $path1, $path2, $identity_path, $port, $options
 Returns     : 1 success
 Description : assumes path1 or path2 contains the src and target
					example: copy from remote node to local file
					path1 = $user\@$node:<filename>
					path2 =  <localfilename>

					example: copy local file to remote node
					path1 =  <localfilename>
					path2 = $user\@$node:<filename>

=cut

sub run_scp_command {
	my ($path1, $path2, $identity_paths, $port, $options) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	if (!defined($path1) || !$path1) {
		notify($ERRORS{'WARNING'}, 0, "path1 was not specified");
		return 0;
	}
	if (!defined($path2) || !$path2) {
		notify($ERRORS{'WARNING'}, 0, "path2 was not specified");
		return 0;
	}
	
	# Escape spaces in the paths if they aren't already escaped
	$path1 =~ s/([^\\]) /$1\\ /g;
	$path2 =~ s/([^\\]) /$1\\ /g;
	
	# Format the identity path string
	if ($identity_paths) {
		$identity_paths =~ s/^\s*/-i /;
		$identity_paths =~ s/\s*,\s*/ -i /g;
		$identity_paths .= ' ';
	}
	else {
		$identity_paths = '';
	}

	# Set default values if not passed as an argument
	$port = 22 if (!defined($port));

	# TODO: Add SCP path to config file and set global variable
	# Locate the path to the SCP binary
	my $scp_path;
	if (-f '/usr/bin/scp') {
		$scp_path = '/usr/bin/scp';
	}
	elsif (-f 'C:/cygwin/bin/scp.exe') {
		$scp_path = 'C:/cygwin/bin/scp.exe';
	}
	elsif (-f 'D:/cygwin/bin/scp.exe') {
		$scp_path = 'D:/cygwin/bin/scp.exe';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to locate the SCP executable in the usual places");
		return 0;
	}
	
	# could be hazardous not confirming optional input flags
	if (defined($options)) {
		$scp_path .= " $options ";
	}
	
	# Print the configuration if $VERBOSE
	if ($VERBOSE) {
		#notify($ERRORS{'OK'}, 0, "path1: $path1, path2: $path2 identity file path: $identity_path, port: $port");
		#notify($ERRORS{'OK'}, 0, "node: $node, identity file path: $identity_path, user: $user, port: $port");
		#notify($ERRORS{'OK'}, 0, "source path: $source_path");
		#notify($ERRORS{'OK'}, 0, "destination path: $destination_path");
	}

	# Assemble the SCP command
	# -B, Selects batch mode (prevents asking for passwords or passphrases).
	# -i <identity_file>, Selects the file from which the identity (private key) for RSA authentication is read.
	# -P <port>, Specifies the port to connect to on the remote host.
	# -p, Preserves modification times, access times, and modes from the original file.
	# -r, Recursively copy entire directories.
	# -v, Verbose mode.  Causes scp and ssh to print debugging messages about their progress.
	# Don't use -q, Disables the progress meter. Error messages are more descriptive without it
	my $scp_command = "$scp_path -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -B $identity_paths-P $port -p -r $path1 $path2";

	# Redirect standard output and error output so all messages are captured
	$scp_command .= ' 2>&1';

	# Execute the command
	my $scp_output;
	my $attempts        = 0;
	my $max_attempts    = 3;
	my $scp_exit_status = 0;

	# Make multiple attempts if failure occurs
	while ($attempts < $max_attempts) {
		$attempts++;
		
		# Delay performing next attempt if this isn't the first attempt
		if ($attempts > 1) {
			my $delay = 2;
			notify($ERRORS{'DEBUG'}, 0, "sleeping for $delay seconds before making next SCP attempt");
			sleep $delay;
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: executing SCP command: $scp_command");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempting to copy file via SCP: '$path1' --> '$path2'");
		}
		
		## Add -v (verbose) argument to command if this is the 2nd attempt
		#$scp_command =~ s/$scp_path/$scp_path -v/ if $attempts == 2;
		
		$scp_output = `$scp_command`;
		
		# Save the exit status
		$scp_exit_status = $?;
		
		# Strip out the key warning message
		$scp_output =~ s/\@{10,}.*man-in-the-middle attacks\.//igs;
		$scp_output =~ s/^\s+|\s+$//g;
		$scp_output =~ s/Warning:.*known hosts.*//ig;
		
		if ($scp_output && length($scp_output) > 0) {
			# Add a newline to the beginning of the output if something was generated
			# This is to make multi-line output more readable
			$scp_output = "\n" . $scp_output;
		}
		else {
			# Indicate there was no output if it is blank
			$scp_output = '';
		}
		
		# Check the output for known error messages
		# Be careful with "no such file" warnings, this may be displayed if the copy was successful but there is a problem with an identity key:
		#    Warning: Identity file /etc/vcl/bad.key not accessible: No such file or directory.
		if ($scp_exit_status != 0 && $scp_output =~ /permission denied|no such file|ambiguous target|is a directory|not known|no space/i) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy via SCP: '$path1' --> '$path2'\nexit status: $scp_exit_status\ncommand: $scp_command\noutput:\n$scp_output");
			return 0;
		}
		elsif ($scp_output =~ /^(scp|ssh):/i) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: error occurred while attempting to copy file via SCP: '$path1' --> '$path2'\ncommand: $scp_command\noutput:\n$scp_output");
			next;
		}
		else {
			notify($ERRORS{'OK'}, 0, "copied file via SCP: '$path1' --> '$path2'");
			return 1;
		}
	} ## end while ($attempts < $max_attempts)
	
	# Failure
	return 0;
} ## end sub run_scp_command

#/////////////////////////////////////////////////////////////////////////////

=head2  write_currentimage_txt

 Parameters  : hash of hashes hash{image} contains image info
 Returns     : 0 failed or 1 successful
 Description : runs an ssh command on the specified node and returns the output

=cut

sub write_currentimage_txt {
	my ($data) = @_;

	# Store some hash variables into local variables
	my $computer_node_name         = $data->get_computer_node_name();
	my $computer_host_name         = $data->get_computer_host_name();
	my $computer_id                = $data->get_computer_id();
	my $image_identity             = $data->get_image_identity();
	my $image_id                   = $data->get_image_id();
	my $image_name                 = $data->get_image_name();
	my $image_prettyname           = $data->get_image_prettyname();
	my $imagerevision_id           = $data->get_imagerevision_id();
	my $imagerevision_date_created = $data->get_imagerevision_date_created();
	my $image_os_type					 = $data->get_image_os_type();

	my @current_image_lines;
	push @current_image_lines, "$image_name";
	push @current_image_lines, "id=$image_id";
	push @current_image_lines, "prettyname=$image_prettyname";
	push @current_image_lines, "imagerevision_id=$imagerevision_id";
	push @current_image_lines, "imagerevision_datecreated=$imagerevision_date_created";
	push @current_image_lines, "computer_id=$computer_id";
	push @current_image_lines, "computer_hostname=$computer_host_name";

	my $current_image_contents = join('\\r\\n', @current_image_lines);
	
	# Remove single quotes - they cause echo command to break
	$current_image_contents =~ s/'//g;

	#Make sure currentimage.txt writable
	my $chown_command = "chown root currentimage.txt; chmod 777 currentimage.txt";
	if(run_ssh_command($computer_node_name, $image_identity, $chown_command)){
		notify($ERRORS{'OK'}, 0, "updated ownership and permissions  on currentimage.txt");
	}

	my $command;
	if($image_os_type =~ /osx/i) {
		$command = 'echo "';
	}
	else {
		$command = 'echo -e "';		
	}

	$command .= $current_image_contents . '" > currentimage.txt && cat currentimage.txt';

	# Copy the temp file to the node as currentimage.txt
	my ($ssh_exit_status, $ssh_output) = run_ssh_command($computer_node_name, $image_identity, $command);

	if (defined($ssh_exit_status) && $ssh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created currentimage.txt file on $computer_node_name:\n" . join "\n", @{$ssh_output});
		return 1;
	}
	elsif (defined($ssh_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt file on $computer_node_name:\n" . join "\n", @{$ssh_output});
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to create currentimage.txt file on $computer_node_name");
		return;
	}

} ## end sub write_currentimage_txt

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_predictive_info

 Parameters  : Either a management node hostname or database ID
 Returns     : Hash containing data contained in the managementnode table
 Description :

=cut

sub get_management_predictive_info {
	my ($management_node_identifier) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($management_node_identifier))) {
		# If nothing was passed, assume management node is this machine
		# Try to get the hostname of this machine
		unless ($management_node_identifier = (hostname())[0]) {
			notify($ERRORS{'WARNING'}, 0, "management node hostname or ID was not specified and hostname could not be determined");
			return ();
		}
	}

	my $select_statement = "
   SELECT
   managementnode.*,
   predictivemodule.name AS predictive_name,
   predictivemodule.prettyname AS predictive_prettyname,
   predictivemodule.description AS predictive_description,
   predictivemodule.perlpackage  AS predictive_perlpackage,
	state.name AS statename
   FROM
   managementnode,
   module predictivemodule,
	state
   WHERE
   managementnode.predictivemoduleid = predictivemodule.id
	AND managementnode.stateid = state.id
   AND
   ";

	# Figure out if the ID or hostname was passed as the identifier and complete the SQL statement
	# Check if it only contains digits
	chomp $management_node_identifier;
	if ($management_node_identifier =~ /^\d+$/) {
		$select_statement .= "managementnode.id = $management_node_identifier";
	}
	else {
		$select_statement .= "managementnode.hostname like \'$management_node_identifier%\'";
	}

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}
	# Get the single returned row
	# It contains a hash
	my $management_node_info = $selected_rows[0];

	notify($ERRORS{'DEBUG'}, 0, "management node info retrieved from database ");
	return $management_node_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_info

 Parameters  : Either a management node hostname or database ID
 Returns     : Hash containing data contained in the managementnode table
 Description :

=cut

sub get_management_node_info {
	# Get the management node identifier argument
	# If argument was not passed, assume management node is this machine
	my $management_node_identifier = shift;
	
	# If a management node identifier argument wasn't specified get the hostname of this management node
	if (!$management_node_identifier) {
		if ($FQDN) {
			$management_node_identifier = $FQDN;
		}
		else {
			$management_node_identifier = (hostname())[0];
		}
	}
	
	if (!defined($ENV{management_node_info}) || !ref($ENV{management_node_info}) || ref($ENV{management_node_info}) ne 'HASH') {
		notify($ERRORS{'DEBUG'}, 0, "initializing management node info hash reference");
		$ENV{management_node_info} = {};
	}
	
	if (defined($ENV{management_node_info}{$management_node_identifier})) {
		my $data_age_seconds = (time - $ENV{management_node_info}{$management_node_identifier}{RETRIEVAL_TIME});
		
		if ($data_age_seconds < 60) {
			#notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved management node info for '$management_node_identifier'");
			return $ENV{management_node_info}{$management_node_identifier};
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieving current management node info for '$management_node_identifier' from database, cached data is stale: $data_age_seconds seconds old");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "management node info for '$management_node_identifier' is not stored in \$ENV{management_node_info}");
	}

	my $select_statement = "
SELECT
managementnode.*,
resource.id AS resource_id,
predictivemodule.name AS predictive_name,
predictivemodule.prettyname AS predictive_prettyname,
predictivemodule.description AS predictive_description,
predictivemodule.perlpackage  AS predictive_perlpackage,
state.name AS statename
FROM
managementnode,
module predictivemodule,
resource,
resourcetype,
state
WHERE
managementnode.predictivemoduleid = predictivemodule.id
AND managementnode.stateid = state.id
AND resource.resourcetypeid = resourcetype.id 
AND resource.subid =  managementnode.id
AND resourcetype.name = 'managementnode'
AND ";

	# Figure out if the ID or hostname was passed as the identifier and complete the SQL statement
	chomp $management_node_identifier;
	if ($management_node_identifier =~ /^\d+$/) {
		# Identifier only contains digits, assume it's the id
		$select_statement .= "managementnode.id = $management_node_identifier";
	}
	elsif ($management_node_identifier =~ /^[\d\.]+$/) {
		# Identifier contains digits and periods, assume it's the IP address
		$select_statement .= "managementnode.IPAddress like \'$management_node_identifier%\'";
	}
	else {
		# Assume hostname was specified
		$select_statement .= "managementnode.hostname REGEXP '^$management_node_identifier(\\\\.|\$)'";
	}
	
	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select, management node identifier may be invalid: '$management_node_identifier'\n$select_statement");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		my @id_hostnames = map ("management node: id=$_->{id}, hostname=$_->{hostname}, IP=$_->{IPaddress}", @selected_rows);
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select, management node identifier may be ambiguous: '$management_node_identifier'\n" . join("\n", @id_hostnames));
		return ();
	}

	# Get the single returned row
	# It contains a hash
	my $management_node_info = $selected_rows[0];

	# Move the state name to a subkey to match get_request_info
	$management_node_info->{state}{name} = $management_node_info->{statename};
	delete $management_node_info->{statename};

	$management_node_info->{hostname} =~ /([-_a-zA-Z0-9]*)(\.?)/;
	my $shortname = $1;
	$management_node_info->{SHORTNAME} = $shortname;

	# Get the image library partner info if imagelibenable=1 and imagelibgroupid>0
	my $imagelib_enable    = $management_node_info->{imagelibenable};
	my $imagelib_group_id  = $management_node_info->{imagelibgroupid};
	my $management_node_id = $management_node_info->{id};
	if ($imagelib_enable && defined($imagelib_group_id) && $imagelib_group_id) {
		my $imagelib_statement = "
SELECT DISTINCT
managementnode.IPaddress
FROM
managementnode,
resource,
resourcegroup,
resourcegroupmembers
WHERE
resourcegroup.id = $imagelib_group_id
AND resourcegroupmembers.resourcegroupid = resourcegroup.id
AND resource.id = resourcegroupmembers.resourceid
AND resource.subid = managementnode.id
AND managementnode.id != $management_node_id
		";
		
		# Call the database select subroutine
		my @imagelib_rows = database_select($imagelib_statement);
		
		# Check to make sure 1 row was returned
		if (scalar @imagelib_rows == 0) {
			notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select, image library functions will be disabled");
			$management_node_info->{imagelibenable} = 0;
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "imagelib partners found: " . scalar @imagelib_rows);
			# Loop through the rows, assemble a string separated by commas
			my $imagelib_ipaddress_string;
			for my $imagelib_row (@imagelib_rows) {
				$imagelib_ipaddress_string .= "$imagelib_row->{IPaddress},";
			}
			# Remove the trailing comma
			$imagelib_ipaddress_string =~ s/,$//;
			#notify($ERRORS{'DEBUG'}, 0, "image library partner IP address string: $imagelib_ipaddress_string");
			$management_node_info->{IMAGELIBPARTNERS} = $imagelib_ipaddress_string;
		} ## end else [ if (scalar @imagelib_rows == 0)
	} ## end if ($imagelib_enable && defined($imagelib_group_id...
	else {
		$management_node_info->{IMAGELIBPARTNERS} = 0;
		#notify($ERRORS{'DEBUG'}, 0, "image library sharing functions are disabled");
	}

	# Get the OS name
	my $os_name = lc($^O);
	$management_node_info->{OSNAME} = $os_name;
	
	# Add the public IP address configuration variables
	$management_node_info->{PUBLIC_IP_CONFIGURATION} = $management_node_info->{publicIPconfiguration};
	$management_node_info->{PUBLIC_SUBNET_MASK} = $management_node_info->{publicSubnetMask};
	$management_node_info->{PUBLIC_DEFAULT_GATEWAY} = $management_node_info->{publicDefaultGateway};
	$management_node_info->{PUBLIC_DNS_SERVER} = $management_node_info->{publicDNSserver};
	
	# Add sysadmin and sharedMailBox email address values
	$management_node_info->{SYSADMIN_EMAIL} = $management_node_info->{sysadminEmailAddress};
	$management_node_info->{SHARED_EMAIL_BOX} = $management_node_info->{sharedMailBox};
	
	# Add affiliations that are not to use the standalone passwords
	$management_node_info->{NOT_STANDALONE} = $management_node_info->{NOT_STANDALONE} || '';
	
	# Store the info in $ENV{management_node_info}
	# Add keys for all of the unique identifiers that may be passed as an argument to this subroutine
	$ENV{management_node_info}{$management_node_identifier} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{hostname}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{SHORTNAME}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{id}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{IPaddress}} = $management_node_info;
	
	# Save the time when the data was retrieved
	$ENV{management_node_info}{$management_node_identifier}{RETRIEVAL_TIME} = time;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved management node info: '$management_node_identifier' ($management_node_info->{SHORTNAME})");
	return $management_node_info;
} ## end sub get_management_node_info

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_imagename

 Parameters  : $computerid, $imagename
 Returns     : 0 failed or 1 success
 Description : Updates currentimage on a node, based on imagename only

=cut
sub update_computer_imagename {
	my ($computerid, $imagename, $log) = @_;

	my ($package,    $filename, $line,            $sub)             = caller(0);

	# Check the passed parameters
	if (!(defined($computerid))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}
	if (!(defined($imagename))) {
		notify($ERRORS{'WARNING'}, 0, "image name was not specified");
		return ();
	}

	#get computer infomation based on imagename
	my $imagerevision_info;
	if( $imagerevision_info = get_imagerevision_info($imagename)){
		notify($ERRORS{'DEBUG'}, 0, "successfully retreived image info for $imagename");
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to get_imagerevision_info for $imagename");
		return 0;
	}

	my $image_id  = $imagerevision_info->{imageid};
	my $imagerevision_id = $imagerevision_info->{id};

	if(update_currentimage($computerid, $image_id, $imagerevision_id)){
		notify($ERRORS{'DEBUG'}, 0, "successfully updated computerid= $computerid image_id= $image_id imagerevision_id= $imagerevision_id");
		return 1;
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to update_currentimage imagename= $imagename computerid= $computerid");
		return 0;
	}

	return 0;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_currentimage

 Parameters  : $computerid, $imageid, $imagerevisionid, $nextimagid(optional)
 Returns     : 0 failed or 1 success
 Description : Updates currentimage on a node, nextimageid = optional

=cut

sub update_currentimage {
	my ($computerid, $imageid,  $imagerevisionid, $nextimagid) = @_;
	my ($package,    $filename, $line,            $sub)             = caller(0);

	# Check the passed parameters
	if (!(defined($computerid))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}
	if (!(defined($imageid))) {
		notify($ERRORS{'WARNING'}, 0, "image ID was not specified");
		return ();
	}
	if (!(defined($imagerevisionid))) {
		notify($ERRORS{'WARNING'}, 0, "image revision ID was not specified");
		return ();
	}

	notify($ERRORS{'OK'}, 0, "updating computer $computerid: image=$imageid, imagerevision=$imagerevisionid");

	# Construct the update statement
	# If $nextimageid defined and set build slightly different statement
	my $update_statement = "
	    UPDATE
		computer c, image i
		SET
		c.currentimageid = $imageid,
	    c.imagerevisionid= $imagerevisionid
		WHERE
		c.id = $computerid
	 ";

	if (defined($nextimagid) && ($nextimagid)) {
		$update_statement = "
			UPDATE
			computer c, image i
			SET
			c.currentimageid = $imageid,
			c.nextimageid = $imageid,
			c.imagerevisionid= $imagerevisionid
			WHERE
			c.id = $computerid
			";
	} ## end if (defined($nextimagid) && ($nextimagid...

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful, return timestamp
		notify($ERRORS{'OK'}, 0, "updated currentimageid and imagerevision id for computer id $computerid");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update database, computerid $computerid currentimageid $imageid");
		return 0;
	}
} ## end sub update_currentimage

#/////////////////////////////////////////////////////////////////////////////

=head2  is_inblockrequest

 Parameters  : Updates currentimage on a node
 Returns     : 1 if successful, 0 otherwise
 Description : checks blockComputers table for supplied computerid

=cut


sub is_inblockrequest {
	my ($computerid) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameters
	if (!(defined($computerid))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}
	# Construct the select statement
	my $select_statement = "
	    SELECT
	    b.blockRequestid,c.blockTimeid
	    FROM blockTimes b, blockComputers c
	    WHERE
	    c.blockTimeid=b.id AND c.computerid = $computerid
	 ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check on what we return
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "zero rows were returned from database select");
		return 0;
	}
	elsif (scalar @selected_rows => 1) {
		notify($ERRORS{'OK'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return 1;
	}
} ## end sub is_inblockrequest

#/////////////////////////////////////////////////////////////////////////////

=head2 update_lastcheckin

 Parameters  : $management_node_id
 Returns     : 0 or 1
 Description : Updates lastcheckin for a management node

=cut


sub update_lastcheckin {
	my ($management_node_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($management_node_id))) {
		notify($ERRORS{'WARNING'}, 0, "management node ID was not specified");
		return ();
	}

	# Get current timestamp
	my $timestamp = makedatestring();

	# Construct the update statement
	my $update_statement = "
      UPDATE
		managementnode
		SET
		lastcheckin = \'$timestamp\'
		WHERE
		id = $management_node_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful, return timestamp
		return $timestamp;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update database, management node id $management_node_id");
		return 0;
	}
} ## end sub update_lastcheckin

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_ipaddress

 Parameters  : $computer_id, $IPaddress
 Returns     : 0 failed or 1 success
 Description : Updates computer's ipaddress - used in dynamic dhcp setup

=cut


sub update_computer_address {
	my ($computer_id, $IPaddress) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}
	# Check the passed parameter
	if (!(defined($IPaddress))) {
		notify($ERRORS{'WARNING'}, 0, "IPaddress was not specified");
		return ();
	}

	# Construct the update statement
	my $update_statement = "
	    UPDATE
		computer
		SET
		IPaddress = \'$IPaddress\'
		WHERE
		id = $computer_id
	 ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful, return timestamp
		notify($ERRORS{'OK'}, $LOGFILE, "computer $computer_id IP address $IPaddress updated in database");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update database, computer IPaddress $computer_id,$IPaddress");
		return 0;
	}
} ## end sub update_computer_address

#/////////////////////////////////////////////////////////////////////////////

=head2 get_request_end

 Parameters  : $request_id
 Returns     : Scalar containing end value for given request ID
 Description :

=cut

sub get_request_end {
	my ($request_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return ();
	}

	# Create the select statement
	my $select_statement = "
   SELECT
	request.end AS end
	FROM
	request
	WHERE
	request.id = $request_id
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# Get the single returned row
	# It contains a hash
	my $end;

	# Make sure we return undef if the column wasn't found
	if (defined $selected_rows[0]{end}) {
		$end = $selected_rows[0]{end};
		return $end;
	}
	else {
		return undef;
	}
} ## end sub get_request_end

#/////////////////////////////////////////////////////////////////////////////

=head2 get_request_by_computerid

 Parameters  : $computer_id
 Returns     : hash containing values of assigned request/reservation
 Description :

=cut


sub get_request_by_computerid {
	my ($computer_id) = @_;

	# Check the passed parameter
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID argument was not specified");
		return
	}

	# Create the select statement
	my $select_statement = <<EOF;
SELECT DISTINCT
request.id AS request_id,
reservation.id AS reservation_id

FROM
request,
reservation

WHERE
request.id = reservation.requestid
AND reservation.computerid = $computer_id

ORDER BY
reservation.id
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "$computer_id is not assigned to any reservations");
		return ();
	}

	my $computer_request_info;

	# It contains a hash
	for my $row (@selected_rows) {
		my $request_id = $row->{request_id};
		my $reservation_id = $row->{reservation_id};
		
		my %request_info = get_request_info($request_id);
		if (!%request_info) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to retrieve request info, request ID: $request_id");
			return;
		}
		
		my $data_structure;
		eval {$data_structure = new VCL::DataStructure({request_data => \%request_info, reservation_id => $reservation_id});};
		if (my $exception = Exception::Class::Base->caught()) {
			notify($ERRORS{'CRITICAL'}, 0, "unable to create DataStructure object" . $exception->message);
			return;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "retrieved info and DataStructure object for $request_id:$reservation_id");
		$computer_request_info->{$request_id}{data} = $data_structure;
	}

	return $computer_request_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_request_current_state_name

 Parameters  : $request_id
 Returns     : String containing state name for a request
 Description :

=cut


sub get_request_current_state_name {
	my ($request_id) = @_;

	# Check the passed parameter
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return ();
	}

	# Create the select statement
	my $select_statement = <<EOF;
SELECT
state.name AS state_name,
laststate.name AS laststate_name
FROM
request,
state,
state laststate
WHERE
request.id = $request_id
AND request.stateid = state.id
AND request.laststateid = laststate.id
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return;
	}
	
	my $row = $selected_rows[0];
	my $state_name = $row->{state_name};
	my $laststate_name = $row->{laststate_name};
	notify($ERRORS{'DEBUG'}, 0, "retrieved current request state: $state_name/$laststate_name");
	
	if (wantarray) {
		return ($state_name, $laststate_name);
	}
	else {
		return $state_name;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_current_state_name

 Parameters  : $computer_id
 Returns     : String containing state name for a particular computer
 Description :

=cut


sub get_computer_current_state_name {
	my ($computer_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}

	# Create the select statement
	my $select_statement = "
   SELECT DISTINCT
	state.name AS name
	FROM
	state,
	computer
	WHERE
	computer.stateid = state.id
	AND computer.id = $computer_id
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# Make sure we return undef if the column wasn't found
	if (defined $selected_rows[0]{name}) {
		return $selected_rows[0]{name};
	}
	else {
		return undef;
	}
} ## end sub get_computer_current_state_name

#/////////////////////////////////////////////////////////////////////////////

=head2 update_log_ending

 Parameters  : $log_id, $ending
 Returns     : 0 or 1
 Description : Updates the finalend and ending fields
					in the log table for the specified log ID

=cut

sub update_log_ending {
	my ($log_id, $ending) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($log_id))) {
		notify($ERRORS{'WARNING'}, 0, "$0: log ID was not specified");
		return ();
	}

	# Check the passed parameter
	if (!(defined($ending))) {
		notify($ERRORS{'WARNING'}, 0, "$0: ending string was not specified");
		return ();
	}

	my $datestring = makedatestring();

	# Construct the update statement
	my $update_statement = "
      UPDATE
		log
		SET
		finalend = \'$datestring\',
		ending = \'$ending\'
		WHERE
		id = $log_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "log id $log_id ending set to '$ending'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set log id $log_id ending to '$ending'");
		return 0;
	}
} ## end sub update_log_ending

#/////////////////////////////////////////////////////////////////////////////

=head2 update_reservation_lastcheck

 Parameters  : $reservation_id or @reservation_ids
 Returns     : string
 Description : Updates reservation.lastcheck to the current time. The argument
               may be a single reservation ID or an array of IDs. The timestamp
               which lastcheck was set to is returned.

=cut

sub update_reservation_lastcheck {
	my @reservation_ids = @_;
	
	# Check the passed parameter
	if (!@reservation_ids) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified");
		return;
	}
	my $reservation_id_string = join(', ', @reservation_ids);
	
	# Must use an explicit timestamp, can't use NOW() because calling subroutine may need the exact value this is set to
	my $lastcheck = makedatestring();
	
	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
reservation
SET
reservation.lastcheck = '$lastcheck'
WHERE
reservation.id IN ($reservation_id_string)
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated reservation.lastcheck to '$lastcheck' for reservation IDs: $reservation_id_string");
		return $lastcheck;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update reservation.lastcheck to '$lastcheck' for reservation IDs: $reservation_id_string");
		return;
	}
} ## end sub update_reservation_lastcheck

#/////////////////////////////////////////////////////////////////////////////

=head2 update_log_loaded_time

 Parameters  : $request_logid
 Returns     : 0 or 1
 Description : Updates the finalend and ending fields in the log table for the specified log ID

=cut

sub update_log_loaded_time {
	my ($request_logid) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($request_logid))) {
		notify($ERRORS{'WARNING'}, 0, "request log ID was not specified");
		return ();
	}

	# Construct the update statement
	# Use an IF clause to only update log.loaded if it is NULL
	# It should only be updated once to capture the time the image load was done
	my $update_statement = "
   UPDATE
   log
   SET
   log.loaded = IF(log.loaded IS NULL, NOW(), log.loaded)
   WHERE
   id = $request_logid
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "updated log loaded time to now for log id: $request_logid");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update log loaded time to now for log id: $request_logid");
		return 0;
	}
} ## end sub update_log_loaded_time

#/////////////////////////////////////////////////////////////////////////////

=head2 update_image_name

 Parameters  : $image_id, $imagerevision_id, $new_image_name
 Returns     : boolean
 Description : Updates the image.name and imagerevision.imagename values in the
					database.

=cut

sub update_image_name {
	my ($image_id, $imagerevision_id, $new_image_name, $new_image_pretty_name) = @_;

	# Check the passed parameter
	unless (defined($image_id) && defined($imagerevision_id) && defined($new_image_name)) {
		notify($ERRORS{'WARNING'}, 0, "image ID, imagerevision ID, and new image name arguments were not specified");
		return;
	}

	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
image,
imagerevision
SET
image.name = \'$new_image_name\',
EOF

	if(defined($new_image_pretty_name) ) {
		$update_statement .= <<EOF;
image.prettyname = \'$new_image_pretty_name\',
EOF
	}

$update_statement .= <<EOF;	
imagerevision.imagename = \'$new_image_name\'
WHERE
image.id = $image_id AND
imagerevision.id = $imagerevision_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated image.name and imagerevision.imagename in database to '$new_image_name' for image ID: $image_id, imagerevision ID: $imagerevision_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update image.name and imagerevision.imagename in database to '$new_image_name' for image ID: $image_id, imagerevision ID: $imagerevision_id");
		return 0;
	}
} ## end sub update_image_name

#/////////////////////////////////////////////////////////////////////////////

=head2 update_image_type

 Parameters  : $image_id, $image_type
 Returns     : boolean
 Description : Updates the image.imagetypeid value in the database. The
               $image_type argument may either be an imagetype ID or name.

=cut

sub update_image_type {
	my ($image_id, $image_type) = @_;

	# Check the passed parameter
	unless (defined($image_id) && defined($image_type)) {
		notify($ERRORS{'WARNING'}, 0, "image ID and image type arguments were not specified");
		return;
	}

	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
image
SET
EOF
	
	# Check if the $image_type argument is an integer (imagetype.id) or string (imagetype.name)
	if ($image_type =~ /^\d+$/) {
		$update_statement .= "image.imagetypeid = \'$image_type\'";
	}
	else {
		$update_statement .= "image.imagetypeid = (SELECT imagetype.id FROM imagetype WHERE imagetype.name = \'$image_type\')";
	}
	
	$update_statement .= <<EOF;
WHERE
image.id = $image_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated image type in database to $image_type for image ID: $image_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update image type in database to $image_type for image ID: $image_id");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_computerloadlog_reservation

 Parameters  : $reservation_id, $loadstatename (optional)
 Returns     : boolean
 Description : Deletes rows from the computerloadlog table. A loadstatename
               argument can be specified to limit the rows removed to a
               certain loadstatename value. To delete all rows except those
               matching a certain loadstatename, begin the loadstatename
               with a !. The $reservation_id argument may either be a single
               integer or an array reference.

=cut

sub delete_computerloadlog_reservation {
	my ($reservation_id_argument, $loadstatename) = @_;
	
	# Check the passed parameter
	if (!(defined($reservation_id_argument))) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified");
		return;
	}
	
	my $reservation_id_string;
	if (ref($reservation_id_argument)) {
		$reservation_id_string = join(', ', @$reservation_id_argument);
	}
	else {
		$reservation_id_string = $reservation_id_argument;
	}
	
	# Construct the SQL statement
	my $sql_statement = <<EOF;
DELETE
computerloadlog
FROM
reservation,
computerloadlog,
computerloadstate
WHERE
computerloadlog.reservationid IN ($reservation_id_string)
AND computerloadlog.loadstateid = computerloadstate.id
EOF
	
	# Check if loadstateid was specified
	# If so, only delete rows matching the loadstateid
	if ($loadstatename && $loadstatename !~ /^!/) {
		notify($ERRORS{'DEBUG'}, 0, "removing computerloadlog entries matching loadstate = $loadstatename");
		$sql_statement .= "AND computerloadstate.loadstatename = \'$loadstatename\'";
	}
	elsif ($loadstatename) {
		# Remove the first character of loadstatename, it is !
		$loadstatename = substr($loadstatename, 1);
		notify($ERRORS{'DEBUG'}, 0, "removing computerloadlog entries NOT matching loadstate = $loadstatename");
		$sql_statement .= "AND computerloadstate.loadstatename != \'$loadstatename\'";
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "removing all computerloadlog entries for reservation");
	}
	
	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted rows from computerloadlog for reservation IDs: $reservation_id_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from computerloadlog table for reservation IDs: $reservation_id_string");
		return 0;
	}
} ## end sub delete_computerloadlog_reservation

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_request

 Parameters  : $request_id
 Returns     : 0 or 1
 Description : Deletes request and all associated reservations for a given request
					ID. This also deletes all computerloadlog rows associated with any
					of the reservations.

=cut

sub delete_request {
	my ($request_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return 0;
	}

	# Construct the SQL statement
	my $sql_computerloadlog_delete = "
	DELETE
	computerloadlog.*
	FROM
	request,
	reservation,
	computerloadlog
   WHERE
	request.id = $request_id
	AND reservation.requestid = request.id
	AND computerloadlog.reservationid = reservation.id
   ";

	# Construct the SQL statement
	my $sql_request_delete = "
	DELETE
	request.*,
	reservation.*
	FROM
	request,
	reservation
   WHERE
	request.id = $request_id
	AND reservation.requestid = request.id
   ";

	# Try to delete any associated entries in the computerloadlog table
	# There may not be any entries, but database_execute should still return 1
	if (!database_execute($sql_computerloadlog_delete)) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from computerloadlog table where request id=$request_id");
	}

	# Try to delete any associated entries in the request and reservation tables
	if (database_execute($sql_request_delete)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from request and reservation tables where request id=$request_id");
		return 0;
	}
} ## end sub delete_request

#/////////////////////////////////////////////////////////////////////////////

=head2 update_blockrequest_processing

 Parameters  : $blockrequest_id, $processing
 Returns     : 0 or 1
 Description : Updates the processing flag in the blockRequest table

=cut

sub update_blockrequest_processing {
	my ($blockrequest_id, $processing) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($blockrequest_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockrequest ID was not specified");
		return 0;
	}
	if (!defined($processing)) {
		notify($ERRORS{'WARNING'}, 0, "processing was not specified");
		return 0;
	}

	# Construct the update statement
	my $update_statement = "
      UPDATE
		blockRequest
		SET
		blockRequest.processing = $processing
		WHERE
		blockRequest.id = $blockrequest_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update blockRequest table, id=$blockrequest_id, processing=$processing");
		return 0;
	}
} ## end sub update_blockrequest_processing



#/////////////////////////////////////////////////////////////////////////////

=head2 clear_next_image_id

 Parameters  : $computer_id
 Returns     : 0 or 1
 Description : sets next_image_id to 0

=cut
sub clear_next_image_id {
	my ($computer_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	# Check the passed parameter
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer_id was not specified");
		return 0;
	}

	my $update_statement = "
	UPDATE
	computer
	SET
	nextimageid = '0'
	WHERE
	id = $computer_id
	";

	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "updated nextimageid to 0 for computer id $computer_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update database, failed to set nextimageid=0 for computerid $computer_id");
		return 0;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 clearfromblockrequest

 Parameters  : $computer_id
 Returns     : 0 or 1
 Description : removes provided computerid and blcok request id from blockcomputer table

=cut


sub clearfromblockrequest {
	my ($computer_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	# Check the passed parameter
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer_id was not specified");
		return 0;
	}

	# Construct the SQL statement
	my $sql_statement = "
	DELETE
	blockComputers
	FROM
	blockComputers
	WHERE
	computerid = $computer_id
	";

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from computerloadlog table where computerid = $computer_id");
		return 0;
	}
} ## end sub clearfromblockrequest

#/////////////////////////////////////////////////////////////////////////////

=head2 update_sublog_ipaddress

 Parameters  : $computer_id
 Returns     : 0 or 1
 Description : updates log table with IPaddress of node
					when dynamic dhcp is enabled there is no way to track which IP was used
=cut


sub update_sublog_ipaddress {
	my ($logid, $computer_ip_address) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	# Check the passed parameter
	if (!(defined($computer_ip_address))) {
		notify($ERRORS{'WARNING'}, 0, "computer_ip_address was not specified");
		return 0;
	}
	if (!(defined($logid))) {
		notify($ERRORS{'WARNING'}, 0, "logid was not specified");
		return 0;
	}

	# Construct the SQL statement
	my $sql_statement = "UPDATE sublog SET IPaddress = \'$computer_ip_address\' WHERE logid=$logid";

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update sublog table logid = $logid with ipaddress $computer_ip_address");
		return 0;
	}
} ## end sub update_sublog_ipaddress

#/////////////////////////////////////////////////////////////////////////////

=head2 set_hash_process_id

 Parameters  : Reference to a hash
 Returns     : 0 or 1
 Description : Sets the process ID of the current process and parent process ID
					in a hash, to which a reference was passed.
					$hash{PID} = process ID
					$hash{PPID} = parent process ID

=cut

sub set_hash_process_id {
	my ($hash_ref) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($hash_ref))) {
		notify($ERRORS{'WARNING'}, 0, "hash reference was not specified");
		return 0;
	}

	# Make sure it's a hash reference
	if (ref($hash_ref) ne "HASH") {
		notify($ERRORS{'WARNING'}, 0, "passed parameter is not a hash reference");
		return 0;
	}

	# Get the parent PID and this process's PID
	# getppid() doesn't work under Windows so just set it to 0
	my $ppid = 0;
	$ppid = getppid() if ($^O !~ /win/i);
	$hash_ref->{PPID} = $ppid;
	my $pid = $$;
	$hash_ref->{PID} = $pid;

	return 1;
} ## end sub set_hash_process_id

#/////////////////////////////////////////////////////////////////////////////

=head2 rename_vcld_process

 Parameters  : hash - Reference to hash containing request data
 Returns     : 0 or 1
 Description : Renames running process based on request information.  Appends the state
					name, request ID, and reservation ID to the process name.
					Sets PARENTIMAGE and SUBIMAGE in the hash depending on whether or
					reservation ID is the lowest for a request.

=cut

sub rename_vcld_process {
	my ($input_data, $process_name) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$filename =~ s/.*\///;

	# IMPORTANT: if you change the process name, check the checkonprocess subroutine
	# It looks for running reservation processes based on the process name
	
	# Check the argument
	my $data_structure;
	if (defined($input_data) && (ref $input_data) =~ /HASH/) {
		# Get a new data structure object
		eval {
			$data_structure = new VCL::DataStructure({request_data => $input_data, reservation_id => $input_data->{RESERVATIONID}});
			notify($ERRORS{'DEBUG'}, 0, "created DataStructure object from passed hash");
		};
		if (my $e = Exception::Class::Base->caught()) {
			notify($ERRORS{'WARNING'}, 0, "hash was passed but could not be turned into a DataStructure, " . $e->message);
			$data_structure = undef;
		}
	} ## end if (defined($input_data) && (ref $input_data...
	elsif (defined($input_data) && (ref $input_data) !~ /DataStructure/) {
		notify($ERRORS{'WARNING'}, 0, "passed parameter (" . ref($input_data) . ") is not a reference to a hash or DataStructure, it will be ignored");
		$data_structure = undef;
	}
	else {
		$data_structure = $input_data;
	}

	# Begin assembling a new process name
	my $new_process_name = "$PROCESSNAME";

	# Check if DataStructure, assemble process name with additional information
	if (defined $data_structure) {
		my $state_name = $data_structure->get_state_name();

		if ($state_name ne 'blockrequest') {
			my $request_id            = $data_structure->get_request_id();
			my $reservation_id        = $data_structure->get_reservation_id();
			my $request_state_name    = $data_structure->get_request_state_name();
			my $computer_short_name   = $data_structure->get_computer_short_name();
			my $vmhost_hostname       = $data_structure->get_vmhost_hostname(0);
			my $image_name            = $data_structure->get_image_name();
			my $user_login_id         = $data_structure->get_user_login_id();
			my $request_forimaging    = $data_structure->get_request_forimaging();
			my $reservation_count     = $data_structure->get_reservation_count();
			my $reservation_is_parent = $data_structure->is_parent_reservation();
			
			# Append the request and reservation IDs if they are set
			$new_process_name .= " $request_id:$reservation_id";
			$new_process_name .= " $request_state_name" if ($request_state_name);
			$new_process_name .= " $computer_short_name" if ($computer_short_name);
			$new_process_name .= ">$vmhost_hostname" if ($vmhost_hostname);
			$new_process_name .= " $image_name" if ($image_name);
			$new_process_name .= " $user_login_id" if ($user_login_id);
			$new_process_name .= " (imaging)" if $request_forimaging;

			# Append cluster if there are multiple reservations for this request
			notify($ERRORS{'DEBUG'}, 0, "reservation count: $reservation_count");

			if ($reservation_count > 1) {
				if ($reservation_is_parent) {
					$data_structure->get_request_data->{PARENTIMAGE} = 1;
					$data_structure->get_request_data->{SUBIMAGE}    = 0;
					$new_process_name .= " (cluster=parent)";
				}
				else {
					$data_structure->get_request_data->{PARENTIMAGE} = 0;
					$data_structure->get_request_data->{SUBIMAGE}    = 1;
					$new_process_name .= " (cluster=child)";
				}
			} ## end if ($reservation_count > 1)
			else {
				$data_structure->get_request_data->{PARENTIMAGE} = 1;
				$data_structure->get_request_data->{SUBIMAGE}    = 0;
			}

			notify($ERRORS{'DEBUG'}, 0, "PARENTIMAGE: " . $data_structure->get_request_data->{PARENTIMAGE});
			notify($ERRORS{'DEBUG'}, 0, "SUBIMAGE: " . $data_structure->get_request_data->{SUBIMAGE});
		} ## end if ($state_name ne 'blockrequest')
		else {
			my $blockrequest_id   = $data_structure->get_blockrequest_id();
			my $blockrequest_name = $data_structure->get_blockrequest_name();
			my $blocktime_id      = $data_structure->get_blocktime_id();

			# Append the IDs if they are set
			$new_process_name .= " $blockrequest_id:$blocktime_id";
			$new_process_name .= " '$blockrequest_name'";
		}
	} ## end if (defined $data_structure)
	else {
		#notify($ERRORS{'DEBUG'}, 0, "DataStructure object is NOT defined");
	}

	# Rename this process
	$0 = $new_process_name;
	notify($ERRORS{'OK'}, 0, "renamed process to \'$0\'");
} ## end sub rename_vcld_process

#/////////////////////////////////////////////////////////////////////////////

=head2 round

 Parameters  : number
 Returns     : rounded number
 Description : rounds to the nearest whole number

=cut


sub round {
	my ($number) = @_;
	if ($number >= 0) {
		return int($number + .5);
	}
	else {
		return int($number - .5);
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_logfile_path

 Parameters  : file path
 Returns     : 0 or 1
 Description : This subroutine is for testing purposes.  It sets vcld's logfile
					path to the parameter passed.  It is useful when running automated
					tests to isoloate logfile output.
=cut

sub set_logfile_path {
	my ($package, $filename, $line, $sub) = caller(0);
	($LOGFILE) = @_;
	#print STDOUT "log file path changed to \'$LOGFILE\'\n";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 switch_state

 Parameters  : $request_data, $request_state_name_new, $computer_state_name_new, $request_log_ending, $exit
 Returns     : 0 if something goes wrong, exits if successful
 Description : Changes the state of this request to the state specified
               terminates. The vcld process will then pick up the switched
               request. It is important that this process sets the request
               laststate to the original state and that vcld does not alter it.

=cut

sub switch_state {
	my ($request_data, $request_state_name_new, $computer_state_name_new, $request_log_ending, $exit) = @_;

	my ($package,        $filename,        $line,        $sub)        = caller(0);
	my ($caller_package, $caller_filename, $caller_line, $caller_sub) = caller(1);

	my $caller_info = "$caller_sub($line)";

	my $caller = scalar caller;
	notify($ERRORS{'OK'}, 0, "called from $caller_info");

	# Check the arguments
	if (!defined($request_data)) {
		notify($ERRORS{'CRITICAL'}, 0, "request data hash reference is undefined");
		return 0;
	}
	elsif (!ref($request_data) eq "HASH") {
		notify($ERRORS{'CRITICAL'}, 0, "1st argument is not a hash reference to the request data");
		return 0;
	}

	# Set the default value for exit
	$exit = 0 if (!defined($exit));

	# Store some hash variables into local variables
	my $request_id                 = $request_data->{id};
	my $request_logid              = $request_data->{logid};
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $request_state_name_old     = $request_data->{state}{name};
	my $request_laststate_name_old = $request_data->{laststate}{name};
	my $computer_id                = $request_data->{reservation}{$reservation_id}{computer}{id};
	my $computer_type              = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $computer_state_name_old    = $request_data->{reservation}{$reservation_id}{computer}{state}{name};
	my $computer_shortname         = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};
	
	if($request_state_name_old eq 'reload'){
		$request_logid = 0;
	}

	# Figure out if this is the parent reservation
	my @reservation_ids = sort keys %{$request_data->{reservation}};
	# The parent reservation has the lowest ID
	my $parent_reservation_id = min @reservation_ids;
	my $is_parent_reservation;
	if ($reservation_id == $parent_reservation_id) {
		notify($ERRORS{'DEBUG'}, 0, "parent: parent reservation ID for this request: $parent_reservation_id");
		$is_parent_reservation = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "child: parent reservation ID for this request: $parent_reservation_id");
		$is_parent_reservation = 0;
	}
	
	# Don't set request state to failed if previous state is image or inuse
	if ($request_state_name_new && $request_state_name_new eq 'failed') {
		if ($request_state_name_old eq 'image') {
			notify($ERRORS{'DEBUG'}, 0, "previous request state is $request_state_name_old, not setting request state to $request_state_name_new, setting request state to maintenance");
			$request_state_name_new = 'maintenance';
			$computer_state_name_new = 'maintenance';
		}
		elsif ($request_state_name_old eq 'inuse') {
			notify($ERRORS{'DEBUG'}, 0, "previous request state is $request_state_name_old, not setting request state to $request_state_name_new, setting request state back to $request_state_name_old");
			$request_state_name_new = 'inuse';
			$computer_state_name_new = 'inuse';
		}
	}
	
	# Check if new request state was passed
	if (!$request_state_name_new) {
		notify($ERRORS{'DEBUG'}, 0, "request state was not specified, state not changed");
	}
	elsif (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "child reservation, request state not changed");
	}
	else {
		# Add an entry to the loadlog
		insertloadlog($reservation_id, $computer_id, "info", "$caller: switching request state to $request_state_name_new");

		# Update the request state to $request_state_name_new and set laststate to current state
		if (update_request_state($request_id, $request_state_name_new, $request_state_name_old)) {
			notify($ERRORS{'OK'}, 0, "request state changed: $request_state_name_old->$request_state_name_new, laststate: $request_laststate_name_old->$request_state_name_old");
			insertloadlog($reservation_id, $computer_id, "info", "$caller: request state changed to $request_state_name_new, laststate to $request_state_name_old");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "request state could not be changed: $request_state_name_old --> $request_state_name_new, laststate: $request_laststate_name_old->$request_state_name_old");
			insertloadlog($reservation_id, $computer_id, "info", "$caller: unable to change request state to $request_state_name_new, laststate to $request_state_name_old");
		}
	} ## end else [ if (!$request_state_name_new)  [elsif (!$is_parent_reservation)

	# Update the computer state
	if (!$computer_state_name_new) {
		notify($ERRORS{'DEBUG'}, 0, "computer state not specified, $computer_shortname state not changed");
	}
	else {
		# Add an entry to the loadlog
		insertloadlog($reservation_id, $computer_id, "info", "$caller: switching computer state to $computer_state_name_new");

		# Update the computer state
		if (update_computer_state($computer_id, $computer_state_name_new)) {
			notify($ERRORS{'OK'}, 0, "computer $computer_shortname state changed: $computer_state_name_old->$computer_state_name_new");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to computer $computer_shortname state: $computer_state_name_old->$computer_state_name_new");
		}
	} ## end else [ if (!$computer_state_name_new)

	# Update log table for this request
	# Ending can be deleted, released, failed, noack, nologin, timeout, EOR, none
	if (!$request_log_ending) {
		notify($ERRORS{'DEBUG'}, 0, "log table id=$request_logid will not be updated");
	}
	elsif (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "child reservation, log table id=$request_logid will not be updated");
	}
	elsif (update_log_ending($request_logid, $request_log_ending)) {
		notify($ERRORS{'OK'}, 0, "log table id=$request_logid, ending set to $request_log_ending");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to set log table id=$request_logid, ending to $request_log_ending");
	}

	# Call exit if the state changed, return otherwise
	if ($exit) {
		insertloadlog($reservation_id, $computer_id, "info", "$caller: process exiting");
		notify($ERRORS{'OK'}, 0, "process exiting");
		exit;
	}
	else {
		notify($ERRORS{'OK'}, 0, "returning");
		return;
	}

} ## end sub switch_state

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_blockrequests

 Parameters  : $managementnode_id
 Returns     : hash containing block request info
 Description :

=cut

sub get_management_node_blockrequests {
	my ($managementnode_id) = @_;
	
	my ($package, $filename, $line, $sub) = caller(0);
	
	# Check the passed parameter
	if (!defined($managementnode_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID was not specified");
		return;
	}
	
	# Create the select statement
	my $select_statement = "
	SELECT
	blockRequest.id AS blockRequest_id,
	blockRequest.name AS blockRequest_name,
	blockRequest.imageid AS blockRequest_imageid,
	blockRequest.numMachines AS blockRequest_numMachines,
	blockRequest.groupid AS blockRequest_groupid,
	blockRequest.repeating AS blockRequest_repeating,
	blockRequest.ownerid AS blockRequest_ownerid,
	blockRequest.admingroupid AS blockRequest_admingroupid,
	blockRequest.managementnodeid AS blockRequest_managementnodeid,
	blockRequest.expireTime AS blockRequest_expireTime,
	blockRequest.processing AS blockRequest_processing,
	blockRequest.status AS blockRequest_status,
	
	blockTimes.id AS blockTimes_id,
	blockTimes.blockRequestid AS blockTimes_blockRequestid,
	blockTimes.start AS blockTimes_start,
	blockTimes.end AS blockTimes_end,
	blockTimes.processed AS blockTimes_processed
	
	FROM
	blockRequest
	
	LEFT JOIN
	blockTimes ON (
		blockRequest.id = blockTimes.blockRequestid 
	)
	
	WHERE
	blockRequest.managementnodeid = $managementnode_id AND
   blockRequest.status = 'accepted' AND
	blockTimes.processed = '0' AND
	(blockTimes.skip = '0' AND blockTimes.start < (NOW() + INTERVAL 360 MINUTE )) OR
   blockTimes.end < NOW() 
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows == 0) {
		#Lets check to see if we have blockRequests that have expired and don't have any time ids
		$select_statement = "
			SELECT
			blockRequest.id AS blockRequest_id,
			blockRequest.name AS blockRequest_name,
			blockRequest.imageid AS blockRequest_imageid,
			blockRequest.numMachines AS blockRequest_numMachines,
			blockRequest.groupid AS blockRequest_groupid,
			blockRequest.repeating AS blockRequest_repeating,
			blockRequest.ownerid AS blockRequest_ownerid,
			blockRequest.admingroupid AS blockRequest_admingroupid,
			blockRequest.managementnodeid AS blockRequest_managementnodeid,
			blockRequest.expireTime AS blockRequest_expireTime,
			blockRequest.processing AS blockRequest_processing,
			blockRequest.status AS blockRequest_status,
	
			blockTimes.id AS blockTimes_id,
			blockTimes.blockRequestid AS blockTimes_blockRequestid,
			blockTimes.start AS blockTimes_start,
			blockTimes.end AS blockTimes_end,
			blockTimes.processed AS blockTimes_processed
			
			FROM
			blockRequest
			LEFT JOIN
			blockTimes ON (
				blockRequest.id = blockTimes.blockRequestid
			)
			
			WHERE
			blockRequest.managementnodeid = $managementnode_id AND
			blockRequest.status = 'accepted' AND
			blockRequest.expireTime < NOW()
		";
		
		@selected_rows = database_select($select_statement);
		
		if (scalar @selected_rows == 0) {
			return 0;
		}
	}
	
	# Build the hash
	my %blockrequests;
	
	for (@selected_rows) {
		my %blockrequest_row = %{$_};
		
		# Get the blockRequest id and blockTimes id
		my $blockrequest_id = $blockrequest_row{blockRequest_id};
		my $blocktimes_id   = $blockrequest_row{blockTimes_id};
		$blocktimes_id = -1 if !$blocktimes_id;
		
		# Loop through all the columns returned for the blockrequest
		foreach my $key (keys %blockrequest_row) {
			my $value = $blockrequest_row{$key};
			
			# Create another variable by stripping off the column_ part of each key
			# This variable stores the original (correct) column name
			(my $original_key = $key) =~ s/^.+_//;
			
			$value = '-1' if (!defined($value));
			
			if ($key =~ /blockRequest_/) {
				$blockrequests{$blockrequest_id}{$original_key} = $value;
				if($key =~ /_groupid/){
					$blockrequests{$blockrequest_id}{groupname} = get_group_name($value);
				}
			}
			elsif ($key =~ /blockTimes_/) {
				$blockrequests{$blockrequest_id}{blockTimes}{$blocktimes_id}{$original_key} = $value;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
			}
		} ## end foreach my $key (keys %blockrequest_row)
	
	} ## end for (@selected_rows)
	
	return \%blockrequests;

} ## end sub get_management_node_blockrequests

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computers_controlled_by_mn

 Parameters  : $managementnode_id
 Returns     : hash containing computer info
 Description :

=cut

sub get_computers_controlled_by_mn {
	my (%managementnode) = @_;

	my %info;

	#set some local variables
	my $management_node_resourceid = $managementnode{resource_id};
	my $management_node_id       	 = $managementnode{id};
	my $management_node_hostname 	 = $managementnode{hostname};

	# Collect resource group this management node is a member of
	if($info{managementnode}{resoucegroups} = get_resource_groups($management_node_resourceid)){
		notify($ERRORS{'DEBUG'}, $LOGFILE, "retrieved management node resource groups from database");
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOGFILE, "unable to retrieve management node resource groups from database");
		return 0;
	}

	# Collect resource group management node grpcan control
	foreach my $mresgrp_id (keys %{$info{managementnode}{resoucegroups}} ) {  

		my $grp_id = $info{managementnode}{resoucegroups}{$mresgrp_id}{groupid}; 

		notify($ERRORS{'DEBUG'}, $LOGFILE, "grp_id = $grp_id ");

		if($info{manageable_resoucegroups}{$mresgrp_id} = get_managable_resource_groups($grp_id)){
			notify($ERRORS{'DEBUG'}, $LOGFILE, "retrieved manageable resource groups from database for mresgrp_id= $grp_id groupname= $info{managementnode}{resoucegroups}{$mresgrp_id}{groupname}");

			foreach my $id (keys %{ $info{manageable_resoucegroups}{$grp_id} } ) {
				my $computer_group_id = $info{manageable_resoucegroups}{$grp_id}{$id}{groupid};
				if($info{"manageable_computer_grps"}{$id}{"members"} = get_computer_grp_members($computer_group_id) ){
					notify($ERRORS{'DEBUG'}, $LOGFILE, "retrieved computers from computer groupname= $info{manageable_resoucegroups}{$grp_id}{$id}{groupname}");
				}
				else{ 
					notify($ERRORS{'DEBUG'}, $LOGFILE, "no computers in computer groupid= $computer_group_id}");
					delete $info{manageable_resoucegroups}{$grp_id}{$id};
				}
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, $LOGFILE, "no manageable resource groups associated for resgrp_id= $mresgrp_id groupname= $info{managementnode}{resoucegroups}{$mresgrp_id}{groupname}");
			#delete $info{managementnode}{resoucegroups}{$mresgrp_id};
		}
	}

	#Build master list of computerids
	my %computer_list;

	foreach my $computergroup (keys %{ $info{manageable_computer_grps}}){
		foreach my $computerid (keys %{ $info{manageable_computer_grps}{$computergroup}{members} }){
			  if ( !(exists $computer_list{$computerid}) ){
				  # add to return list
				  $computer_list{$computerid}{"computer_id"}=$computerid;
			  }
			}
	}

	return \%computer_list;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_resource_groups

 Parameters  : $management_node_resourceid
 Returns     : hash containing list of resource groups id is a part of
 Description :

=cut

sub get_resource_groups {
	my ($resource_id) = @_;

	if(!defined($resource_id)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "resource_id was not supplied");
		return 0;
	}

	my $select_statement = "
   SELECT DISTINCT
	resourcegroupmembers.resourcegroupid AS resource_groupid,
	resourcegroup.name AS resource_groupname
	FROM 
	resourcegroupmembers, 
	resourcegroup
	WHERE 
	resourcegroup.id = resourcegroupmembers.resourcegroupid
	AND resourceid = $resource_id
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select for resource id $resource_id");
		return ();
	}

	#my %return_hash = %{$selected_rows[0]};
	my %return_hash;
	for (@selected_rows) {
		my %resgrps = %{$_};
		my $resgrpid = $resgrps{resource_groupid};
		$return_hash{$resgrpid}{"groupid"} = $resgrpid;
		$return_hash{$resgrpid}{"groupname"} = $resgrps{resource_groupname};
	}

	return \%return_hash;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_managable_resource_groups

 Parameters  : $management_node_grp_id
 Returns     : hash containing list of resource groups that can be controlled
 Description :

=cut

sub get_managable_resource_groups {
	my ($managing_resgrp_id) = @_;

	if(!defined($managing_resgrp_id)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "managing_resgrp_id resource_id was not supplied");
		return 0;
	}

	my $select_statement = "
   SELECT DISTINCT
	resourcemap.resourcegroupid2 AS resource_groupid,
	resourcegroup.name AS resource_groupname
	FROM 
	resourcemap,
	resourcegroup, 
	resourcetype 
	WHERE 
	resourcemap.resourcetypeid2 = resourcetype.id 
	AND resourcetype.name = 'computer'
	AND resourcegroup.id = resourcemap.resourcegroupid2
	AND resourcemap.resourcegroupid1 = $managing_resgrp_id 
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'DEBUG'}, 0, "zero rows were returned from database select for resource id $managing_resgrp_id");
		return ();
	}
	my %return_hash;
   for (@selected_rows) {
        my %resgrps = %{$_};
        my $resgrpid = $resgrps{resource_groupid};
        $return_hash{$resgrpid}{"groupid"} = $resgrpid;
        $return_hash{$resgrpid}{"groupname"} = $resgrps{resource_groupname};
   }
   return \%return_hash;
}
#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_grp_members

 Parameters  : $computer_grp_id
 Returns     : hash containing list of of computer ids
 Description :

=cut

sub get_computer_grp_members {
	my ($computer_grp_id) = @_;

	if(!defined($computer_grp_id)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "computer_grp_id resource_id was not supplied");
		return 0;
	}

	my $select_statement = "
   SELECT DISTINCT
	resource.subid AS computer_id
   FROM 
	resourcegroupmembers,
	resourcetype,
	resource,
	computer
   WHERE 
	resourcegroupmembers.resourceid = resource.id 
	AND resourcetype.id = resource.resourcetypeid 
	AND resourcetype.name = 'computer' 
	AND resourcegroupmembers.resourcegroupid = $computer_grp_id
	AND computer.deleted != '1'
	AND computer.id = resource.subid
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'DEBUG'}, 0, "zero rows were returned from database select for computer grp id $computer_grp_id");
		return ();
	}
	my %return_hash;
   for (@selected_rows) {
        my %computerids = %{$_};
        my $compid = $computerids{computer_id};
        $return_hash{$compid}{"computer_id"} = $compid;
   }
   return \%return_hash;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_user_info

 Parameters  : $user_identifier, $affiliation_identifier (optional), $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves user information from the database. The user identifier
               argument can either be a user ID or unityid. A hash reference is
               returned.

=cut

sub get_user_info {
	my ($user_identifier, $affiliation_identifier, $no_cache) = @_;
	
	if (!defined($user_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "user identifier argument was not specified");
		return;
	}
	
	# Check if cached user info exists
	if (!$no_cache && defined($ENV{user_info}{$user_identifier})) {
		# Check the time the info was last retrieved
		my $data_age_seconds = (time - $ENV{user_info}{$user_identifier}{RETRIEVAL_TIME});
		if ($data_age_seconds < 600) {
			return $ENV{user_info}{$user_identifier};
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieving current user info for '$user_identifier' from database, cached data is stale: $data_age_seconds seconds old");
		}
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieving user info: $user_identifier");
	
	# If affiliation identifier argument wasn't supplied, set it to % wildcard
	$affiliation_identifier = '%' if !$affiliation_identifier;
	
	my $select_statement = <<EOF;
SELECT DISTINCT
user.*,
adminlevel.name AS adminlevel_name,
affiliation.name AS affiliation_name,
affiliation.shibname AS affiliation_shibname,
affiliation.dataUpdateText AS affiliation_dataUpdateText,
affiliation.sitewwwaddress AS affiliation_sitewwwaddress,
affiliation.helpaddress AS affiliation_helpaddress,
affiliation.shibonly AS affiliation_shibonly,

IMtype.name AS IMtype_name,

localauth.passhash AS localauth_passhash,
localauth.salt AS localauth_salt,
localauth.lastupdated AS localauth_lastupdated,
localauth.lockedout AS localauth_lockedout

FROM
user
LEFT JOIN (adminlevel) ON (adminlevel.id = user.adminlevelid)
LEFT JOIN (affiliation) ON (affiliation.id = user.affiliationid)
LEFT JOIN (IMtype) ON (IMtype.id = user.IMtypeid)
LEFT JOIN (localauth) ON (localauth.userid = user.id)
WHERE
EOF
	
	# If the user identifier is all digits match it to user.id
	# Otherwise, match user.unityid
	if ($user_identifier =~ /^\d+$/) {
		$select_statement .= "user.id = $user_identifier";
	}
	else {
		$select_statement .= "user.unityid LIKE '$user_identifier'";
	}
	
	# If the affiliation identifier argument was specified add affiliation table clause
	if (defined($affiliation_identifier)) {
		if ($affiliation_identifier =~ /^\d+$/) {
			$select_statement .= "\nAND affiliation.id = $affiliation_identifier";
		}
		else {
			$select_statement .= "\nAND affiliation.name LIKE '$affiliation_identifier'";
		}
	}

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure row was returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "user was not found in the database: '$user_identifier'");
		return;
	}
	elsif (scalar @selected_rows > 1) {
		my $user_ids;
		for my $row (@selected_rows) {
			$user_ids->{$row->{id}} = $row->{unityid} . '@' . $row->{affiliation_name};
		}
		
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select for user: '$user_identifier', affiliation '$affiliation_identifier':\n" . format_data($user_ids) . "\nSQL statement:\n$select_statement");
		return;
	}
	
	# Transform the database row into a hash
	my $row = $selected_rows[0];
	my $user_info;
	
	# Loop through all the columns returned
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Create another variable by stripping off the column_ part of each key
		# This variable stores the original (correct) column name
		(my $original_key = $key) =~ s/^.+_//;
		
		if ($key =~ /^(.+)_/) {
			 $user_info->{$1}{$original_key} = $value;
		}
		else {
			$user_info->{$original_key} = $value;
		}
	}
	
	my $user_id = $user_info->{id};
	my $user_login_id = $user_info->{unityid};
	
	# Set the user's preferred name to the first name if it isn't defined
	if (!defined($user_info->{preferredname}) || $user_info->{preferredname} eq '') {
		$user_info->{preferredname} = $user_info->{firstname};
	}

	# Set the user's IMid to '' if it's NULL
	if (!defined($user_info->{IMid})) {
		$user_info->{IMid} = '';
	}

	
	# Affiliation specific changes
	# Check if the user's affiliation is listed in the management node's NOT_STANDALONE parameter
	$user_info->{STANDALONE} = 1;
	
	# Set the user's UID to the VCL user ID if it's not configured in the database, set STANDALONE = 1
	if (!$user_info->{uid}) {
		$user_info->{uid} = ($user_info->{id} + 500);
		$user_info->{STANDALONE} = 1;
		notify($ERRORS{'DEBUG'}, 0, "UID value is not configured for user $user_login_id, setting UID to VCL user ID: $user_login_id, standalone: 1");
	}
	
	# Fix the unityid if the user's UID is >= 1,000,000
	# Remove the domain section if the user's unityid contains @...
	elsif ($user_info->{uid} >= 1000000) {
		$user_info->{STANDALONE} = 1;
		notify($ERRORS{'DEBUG'}, 0, "UID value for user $user_login_id is >= 1000000, standalone: 1");
	}
	
	# Check if the user's affiliation is listed in the management node's NOT_STANDALONE list
	elsif (my $not_standalone_list = get_management_node_info()->{NOT_STANDALONE}) {
		my $user_affiliation_name = $user_info->{affiliation}{name};
		if (grep(/^$user_affiliation_name$/i, split(/[,;]/, $not_standalone_list))) {
			notify($ERRORS{'DEBUG'}, 0, "non-standalone affiliation found for user $user_login_id:\nuser affiliation: $user_affiliation_name\nnot standalone list: $not_standalone_list");
			$user_info->{STANDALONE} = 0;
		}
	}
	
	# If user's unityid is an email address, use only the first part
	if ($user_login_id =~ /(.+)@/) {
		my $corrected_unity_id = $1;
		notify($ERRORS{'DEBUG'}, 0, "user's unityid value contains '\@': $user_login_id, changing to $corrected_unity_id");
		$user_info->{unityid} = $corrected_unity_id;
	}

	# If usepublickeys =0 && sshpublickeys is defined, disable public keys by setting sshpublickeys=0
	if (!$user_info->{usepublickeys} && defined($user_info->{sshpublickeys})) {
			$user_info->{sshpublickeys} = 0;
	}
	
	# For test account only
	if ($user_login_id =~ /vcladmin/) {
		$user_info->{STANDALONE} = 1;
	}
	
	# Set the user's affiliation sitewwwaddress and help address if not defined or blank
	if (!$user_info->{affiliation}{sitewwwaddress}) {
		$user_info->{affiliation}{sitewwwaddress} = 'http://cwiki.apache.org/VCL';
	}
	if (!$user_info->{affiliation}{helpaddress}) {
		$user_info->{affiliation}{helpaddress} = 'nobody@example.com';
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for user '$user_identifier', affiliation: '$affiliation_identifier':\n" . format_data($user_info));
	$ENV{user_info}{$user_identifier} = $user_info;
	$ENV{user_info}{$user_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{user_info}{$user_identifier};	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_local_user_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves info for all local users and returns a hash reference.
               The keys of the hash are user IDs.

=cut

sub get_local_user_info {
	my $select_statement = <<EOF;
SELECT
userid
FROM
localauth
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "local user was not found in the database, 0 rows were returned");
		return;
	}
	
	# Transform the array of database rows into a hash
	my $local_user_info;
	for my $row (@selected_rows) {
		my $user_id = $row->{userid};
		
		my $user_info = get_user_info($user_id);
		$local_user_info->{$user_id} = $user_info;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved local user info:\n" . format_data($local_user_info));
	return $local_user_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_group_name

 Parameters  : $group_id
 Returns     : scalar - group name
 Description :

=cut

sub get_group_name {
	my ($group_id) = @_;
	
	
	if(!defined($group_id)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "group_id was not supplied");
		return 0;
	}

	my $select_statement = <<EOF;
SELECT DISTINCT
usergroup.name
FROM
usergroup
WHERE
usergroup.id = $group_id
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}
	
	# Get the single returned row
	# It contains a hash
	my $end;
	
	# Make sure we return undef if the column wasn't found
	if (defined $selected_rows[0]{name}) {
		my $groupname = $selected_rows[0]{name};
		return $groupname;
	}
	else {
		return undef;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_info

 Parameters  : $computer_identifier, $no_cache (optional)
 Returns     : hash reference
 Description :

=cut

sub get_computer_info {
	my ($computer_identifier, $no_cache) = @_;
	if (!defined($computer_identifier)){
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument was not supplied");
		return;
	}
	
	return $ENV{computer_info}{$computer_identifier} if (!$no_cache && $ENV{computer_info}{$computer_identifier});
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'computer',
		'state',
		'provisioning',
		'module',
		'schedule',
		'platform',
	);
	
	# Construct the select statement
	my $select_statement = "SELECT DISTINCT\n";
	
	# Get the column names for each table and add them to the select statement
	for my $table (@tables) {
		my @columns = @{$database_table_columns->{$table}};
		for my $column (@columns) {
			$select_statement .= "$table.$column AS '$table-$column',\n";
		}
	}
	
	# Remove the comma after the last column line
	$select_statement =~ s/,$//;
	
	# Complete the select statement
	$select_statement .= <<EOF;
FROM
computer

LEFT JOIN (state) ON (state.id = computer.stateid)
LEFT JOIN (platform) ON (platform.id = computer.platformid)
LEFT JOIN (
	provisioning,
	module
)
ON (
	provisioning.id = computer.provisioningid
	AND module.id = provisioning.moduleid
)
LEFT JOIN (schedule) ON (schedule.id = computer.scheduleid)

WHERE
computer.deleted != '1'
AND 
EOF

	# If the computer identifier is all digits match it to computer.id
	# Otherwise, match computer.hostname
	if ($computer_identifier =~ /^\d+$/) {
		$select_statement .= "computer.id = \'$computer_identifier\'";
	}
	else {
		$select_statement .= "computer.hostname REGEXP '$computer_identifier(\\\\.|\$)'";
	}
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select statement:\n$select_statement");
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}

	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	
	# Construct a hash with all of the computer info
	my $computer_info;
	
	# Loop through all the columns returned
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Split the table-column names
		my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
		
		# Add the values for the primary table to the hash
		# Add values for other tables under separate keys
		if ($table eq $tables[0]) {
			$computer_info->{$column} = $value;
		}
		elsif ($table eq 'module') {
			$computer_info->{provisioning}{$table}{$column} = $value;
		}
		else {
			$computer_info->{$table}{$column} = $value;
		}
	}
	
	# Set the short name of the computer based on the hostname
	my $computer_hostname = $computer_info->{hostname};
	my ($computer_shortname) = $computer_hostname =~ /^([^\.]+)/;
	$computer_info->{SHORTNAME} = $computer_shortname;
	
	# Set the NODENAME key based on the type of computer
	# Use the full hostname if the computer type is lab
	# Use the short name otherwise
	my $computer_type = $computer_info->{type};
	if ($computer_type eq "lab") {
		$computer_info->{NODENAME} = $computer_hostname;
	}
	else {
		$computer_info->{NODENAME} = $computer_shortname;
	}
	
	# Get the imagerevision info and add it to the hash
	my $imagerevision_id = $computer_info->{imagerevisionid};
	if ($imagerevision_id && (my $imagerevision_info = get_imagerevision_info($imagerevision_id))) {
		$computer_info->{currentimagerevision} = $imagerevision_info;
		$computer_info->{currentimage} = $imagerevision_info->{image};
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve image revision info for $computer_hostname, imagerevision ID=$imagerevision_id, attempting to retrieve image revision info for the 'noimage' image");
		
		my $imagerevision_info = get_imagerevision_info('noimage');
		if ($imagerevision_info) {
			$computer_info->{currentimagerevision} = $imagerevision_info;
			$computer_info->{currentimage} = $imagerevision_info->{image};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve 'noimage' image revision info for $computer_hostname");
		}
	}
	
	# Get the nextimage info
	if (my $next_image_id = $computer_info->{nextimageid}) {
		if (my $next_imagerevision_info = get_production_imagerevision_info($next_image_id)) {
			$computer_info->{nextimagerevision} = $next_imagerevision_info;
			$computer_info->{nextimage} = $next_imagerevision_info->{image};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve nextimage info for $computer_hostname, nextimageid=$next_image_id");
		}
	}
	
	# Check if the computer associated with this reservation has a vmhostid set
	if (my $vmhost_id = $computer_info->{vmhostid}) {
		my $vmhost_info = get_vmhost_info($vmhost_id);
		
		if ($vmhost_info) {
			$computer_info->{vmhost} = $vmhost_info;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmhostid $vmhost_id is set for $computer_hostname but the vmhost info could not be retrieved");
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for computer '$computer_identifier':\n" . format_data($computer_info));
	$ENV{computer_info}{$computer_identifier} = $computer_info;
	$ENV{computer_info}{$computer_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{computer_info}{$computer_identifier};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_ids

 Parameters  : $computer_identifier
 Returns     : array
 Description : Queries the computer table for computers matching the
               $computer_identifier argument. The argument may contain either
               the computer's hostname or IP address. An array containing the
               computer IDs is returned.

=cut

sub get_computer_ids {
	my ($computer_identifier) = @_;

	if(!defined($computer_identifier)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "computer identifier argument was not supplied");
		return;
	}

	my $select_statement = <<EOF;
SELECT
*
FROM
computer
WHERE
hostname REGEXP '^$computer_identifier(\\\\.|\$)'
OR IPaddress = '$computer_identifier'
OR privateIPaddress = '$computer_identifier'
EOF

	my @selected_rows = database_select($select_statement);
	if (!@selected_rows) {
		notify($ERRORS{'DEBUG'}, 0, "no computers were found matching identifier: $computer_identifier");
		return ();
	}

	my @computer_ids = map { $_->{id} } @selected_rows;
	notify($ERRORS{'DEBUG'}, 0, "found computers matching identifier: $computer_identifier, IDs: @computer_ids");
	return sort @computer_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_request

 Parameters  : $managementnode_id, $request_state_name, $request_laststate_name, $end_minutes_in_future, $user_unityid, $computer_id, $image_id, $imagerevision_id
 Returns     : 1 if successful, 0 if failed
 Description :

=cut

sub insert_request {
	my ($managementnode_id, $request_state_name, $request_laststate_name, $request_logid, $user_unityid, $computer_id, $image_id, $imagerevision_id, $start_minutes_in_future, $end_minutes_in_future) = @_;


	if (!$request_state_name) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory request key: state_name");
		return 0;
	}
	if (!$request_laststate_name) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory request key: laststate_name");
		return 0;
	}
	if (!$user_unityid) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory request key: user_unityid");
		return 0;
	}

	if (!$computer_id) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory reservation key: computer_id");
		return 0;
	}
	if (!$image_id) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory reservation key: image_id");
		return 0;
	}
	if (!$imagerevision_id) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory reservation key: imagerevision_id");
		return 0;
	}
	if (!$managementnode_id) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory reservation key: managementnode_id");
		return 0;
	}
	
	if ($computer_id !~ /^\d+$/) {
		my @computer_ids = get_computer_ids($computer_id);
		if (scalar(@computer_ids) != 1) {
			notify($ERRORS{'WARNING'}, 0, "computer ID argument is not numeric and computer ID could not be determined");
			return;
		}
		$computer_id = $computer_ids[0];
	}

	my $insert_request_statment = "
	INSERT INTO
	request
	(
      request.stateid,
      request.laststateid,
      request.userid,
      request.logid,
      request.forimaging,
      request.test,
      request.preload,
      request.start,
      request.end,
      request.daterequested
	)
	VALUES
	(
      (SELECT id FROM state WHERE state.name = '$request_state_name'),
      (SELECT id FROM state WHERE state.name = '$request_laststate_name'),
      (SELECT id FROM user WHERE user.unityid = '$user_unityid'),
      '$request_logid',
      '0',
      '0',
      '0',
      TIMESTAMPADD(MINUTE, $start_minutes_in_future, NOW()),
      TIMESTAMPADD(MINUTE, $end_minutes_in_future, NOW()),
      NOW()
   )
	";

	# Execute the request insert statement
	# If successful, the id of the newly inserted row is returned
	my $request_id = database_execute($insert_request_statment);
	if ($request_id) {
		notify($ERRORS{'OK'}, 0, "inserted new $request_state_name/$request_laststate_name request into request table, request id=$request_id");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert new $request_state_name/$request_laststate_name request into request table");
		return 0;
	}

	my $insert_reservation_statment = "
	INSERT INTO
	reservation
	(
      reservation.requestid,
      reservation.computerid,
      reservation.imageid,
      reservation.imagerevisionid,
      reservation.managementnodeid
	)
	VALUES
	(
      '$request_id',
      '$computer_id',
      '$image_id',
      '$imagerevision_id',
      '$managementnode_id'
	)
	";

	# Execute the reservation insert statement
	# If successful, the id of the newly inserted row is returned
	my $reservation_id = database_execute($insert_reservation_statment);
	if ($reservation_id) {
		notify($ERRORS{'OK'}, 0, "inserted new reservation for request $request_id: $reservation_id");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert new reservation for request $request_id");
		return 0;
	}

	return ($request_id, $reservation_id);
} ## end sub insert_request

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_reload_request

 Parameters  : $request_data_hash_reference
 Returns     : nothing, always calls exit
 Description : Changes this request to a reload request then
               terminates. The vcld process will then pick up the reload
               request. It is important that this process sets the request
               laststate to 'reclaim' and that vcld does not alter it.

=cut

sub insert_reload_request {
	my ($request_data) = @_;
	my ($package,         $filename,         $line,         $sub)         = caller(0);
	my ($calling_package, $calling_filename, $calling_line, $calling_sub) = caller(0);

	# Store some hash variables into local variables
	my $request_id             = $request_data->{id};
	my $request_state_name     = $request_data->{state}{name};
	my $request_laststate_name = $request_data->{laststate}{name};
	my $reservation_id         = $request_data->{RESERVATIONID};
	my $computer_id            = $request_data->{reservation}{$reservation_id}{computer}{id};
	my $computer_type          = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $managementnode_id      = $request_data->{reservation}{$reservation_id}{managementnode}{id};
	my $request_logid          = $request_data->{logid};
	my $user_unityid           = $request_data->{user}{unityid};
	my $image_id               = $request_data->{reservation}{$reservation_id}{image}{id};
	my $imagerevision_id       = $request_data->{reservation}{$reservation_id}{imagerevision}{id};

	# Assemble a consistent prefix for notify messages
	my $notify_prefix = "req=$request_id:";

	# Add an entry to the loadlog
	if ($computer_type eq "blade") {
		insertloadlog($reservation_id, $computer_id, "loadimageblade", "$calling_sub: switching request state to reload");
	}
	elsif ($computer_type eq "virtualmachine") {
		insertloadlog($reservation_id, $computer_id, "loadimagevmware", "$calling_sub: switching request state to reload");
	}
	else {
		insertloadlog($reservation_id, $computer_id, "info", "$calling_sub: switching request state to reload");
	}

	# Check to make sure computer state is not currently reload or reloading
	# It's possible for reclaimed cluster reservations to attempt to insert multiple reloads for child reservations
	# because only the parent can update the request state
	my $current_computer_state_name = get_computer_current_state_name($computer_id);
	if ($current_computer_state_name =~ /reload/) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix current computer state is $current_computer_state_name, reload request will not be inserted");
		return 0;
	}

	# Modify computer state so reload will process
	if (update_computer_state($computer_id, "reload")) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix setting computerid $computer_id into reload state");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix unable to set computerid $computer_id reload state");
	}

	# Attempt to create a new reload request
	my $request_id_reload;
	if ($request_id_reload = insert_request($managementnode_id, 'reload', $request_laststate_name, '0', 'vclreload', $computer_id, $image_id, $imagerevision_id, '0', '30')) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix inserted new reload request, id=$request_id_reload nodeid=$computer_id, imageid=$image_id, imagerevision_id=$imagerevision_id");
		insertloadlog($reservation_id, $computer_id, "info", "$calling_sub: created new reload request");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert new reload request");
		return 0;
	}

	return 1;
} ## end sub insert_reload_request

#/////////////////////////////////////////////////////////////////////////////

=head2 update_cluster_info

 Parameters  :data hash 
 Returns     : 0 or 1
 Description :

=cut

sub update_cluster_info {

	my ($request_data) = @_;
	my ($package,         $filename,         $line,         $sub)         = caller(0);
	my ($calling_package, $calling_filename, $calling_line, $calling_sub) = caller(0);

	my $reservation_id      = $request_data->{RESERVATIONID};
	my $computer_short_name = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};
	my $image_OS_type       = $request_data->{reservation}{$reservation_id}{image}{OS}{type};
   my $is_cluster_parent	= $request_data->{PARENTIMAGE};
	my $is_cluster_child		= $request_data->{SUBIMAGE};

	my $cluster_info   = "/tmp/$computer_short_name.cluster_info";
	my @cluster_string = "";



	my @reservation_ids = sort keys %{$request_data->{reservation}};

	# parent reservation id lowest
	my $parent_reservation_id = min @reservation_ids;
	notify($ERRORS{'DEBUG'}, 0, "$computer_short_name is_cluster_parent = $is_cluster_parent ");
	notify($ERRORS{'DEBUG'}, 0, "$computer_short_name is_cluster_child = $is_cluster_child ");
	notify($ERRORS{'DEBUG'}, 0, "parent_reservation_id = $parent_reservation_id ");

	foreach my $rid (keys %{$request_data->{reservation}}) {
		if ($rid == $parent_reservation_id) {
			push(@cluster_string, "parent= $request_data->{reservation}{$rid}{computer}{IPaddress}" . "\n");
			notify($ERRORS{'DEBUG'}, 0, "writing parent=  $request_data->{reservation}{$rid}{computer}{IPaddress}");
		}
		else {
			push(@cluster_string, "child= $request_data->{reservation}{$rid}{computer}{IPaddress}" . "\n");
			notify($ERRORS{'DEBUG'}, 0, "writing child=  $request_data->{reservation}{$rid}{computer}{IPaddress}");
		}
	}


	if (open(CLUSTERFILE, ">$cluster_info")) {
		print CLUSTERFILE @cluster_string;
		close(CLUSTERFILE);
	}
	else {
		notify($ERRORS{'OK'}, 0, "could not write to $cluster_info");
	}

	my $identity;
	#scp cluster file to each node
	my $targetpath;
	foreach my $rid (keys %{$request_data->{reservation}}) {
		$identity = $request_data->{reservation}{$rid}{image}{IDENTITY};
		my $node_name = $request_data->{reservation}{$rid}{computer}{SHORTNAME};
		if ($image_OS_type =~ /linux/i) {
			$targetpath = "$node_name:/etc/cluster_info";
		}
		elsif ($image_OS_type =~ /windows/i) {
			$targetpath = "$node_name:C:\/cluster_info";
		}
		else {
			$targetpath = "$node_name:/etc/cluster_info";
		}

		if (run_scp_command($cluster_info, $targetpath, $identity)) {
			notify($ERRORS{'OK'}, 0, " successfully copied cluster_info file to $node_name");
		}
	} ## end foreach my $rid (keys %{$request_data->{reservation...

	unlink $cluster_info;

	return 1;

} ## end sub update_cluster_info

#/////////////////////////////////////////////////////////////////////////////

=head2 format_data

 Parameters  : $data
 Returns     : string
 Description : Formats the data argument using Data::Dumper.

=cut

sub format_data {
	my @data = @_;
	
	if (!(@data)) {
		return '<undefined>';
	}
	
	# If a string was passed which appears to be XML, convert it to a hash using XML::Simple
	if (scalar(@data) == 1 && !ref($data[0]) && $data[0] =~ /^</) {
		my $xml_hashref = xml_string_to_hash($data[0]);
		return format_data($xml_hashref);
	}
	
	$Data::Dumper::Indent    = 1;
	$Data::Dumper::Purity    = 0;
	$Data::Dumper::Useqq     = 1;      # Use double quotes for representing string values
	$Data::Dumper::Terse     = 1;
	$Data::Dumper::Quotekeys = 1;      # Quote hash keys
	$Data::Dumper::Pair      = ' => '; # Specifies the separator between hash keys and values
	$Data::Dumper::Sortkeys  = 1;      # Hash keys are dumped in sorted order
	$Data::Dumper::Deparse   = 0;
	
	my $formatted_string = Dumper(@data);
	
	my @formatted_lines = split("\n", $formatted_string);
	
	map { $_ = ": $_" } @formatted_lines;
	
	return join("\n", @formatted_lines);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 format_hash_keys

 Parameters  : $hash_ref, $level (optional), $parent_keys (optional)
 Returns     : hash reference
 Description : 

=cut

sub format_hash_keys {
	my ($hash_ref, $display_parent_keys, $display_values_hashref, $parent_keys) = @_;
	if (!$hash_ref) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not supplied");
		return;
	}
	elsif (!ref($hash_ref) || ref($hash_ref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "first argument is not a hash reference");
		return;
	}
	
	my $return_string;
	if ($return_string) {
		$return_string .= "\n";
	}
	else {
		$return_string = '';
	}
	
	if (!defined($parent_keys)) {
		$parent_keys = [];
	}
	
	my $level = scalar(@$parent_keys);
	
	# Add specific values specified in $display_values_hashref to the return string
	if (@$parent_keys && $display_values_hashref) {
		my $parent_key = @$parent_keys[-1];
		for my $key (sort { lc($a) cmp lc($b) } keys %$hash_ref) {
			my $value = $hash_ref->{$key} || '<NULL>';
			next if ref($value);
			for my $display_parent_key (sort { lc($a) cmp lc($b) } keys %$display_values_hashref) {
				my $display_key = $display_values_hashref->{$display_parent_key};
				next if ($parent_key ne $display_parent_key || $key ne $display_key);
				$return_string .= '-' x ($level * 3);
				$return_string .= join('', map { "{$_}" } @$parent_keys) if ($display_parent_keys);
				$return_string .= "{$key} => '$value'";
				$return_string .= "\n";
			}
		}
	}
	
	for my $key (sort { lc($a) cmp lc($b) } keys %$hash_ref) {
		my $value = $hash_ref->{$key};
		my $type = ref($value);
		if (!$type) {
			next;
		}
		
		$return_string .= '-' x ($level * 3);
		
		if ($type eq 'HASH') {
			$return_string .= join('', map { "{$_}" } @$parent_keys) if ($display_parent_keys);
			$return_string .= "{$key}";
			$return_string .= "\n";
			
			push @$parent_keys, $key;
			$return_string .= format_hash_keys($value, $display_parent_keys, $display_values_hashref, $parent_keys);
			pop @$parent_keys;
		}
		elsif ($type eq 'ARRAY') {
			$return_string .= "[$key]\n";
		}
		else {
			$return_string .= "<$type: $key>\n";
		}
	}
	
	return $return_string;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_caller_trace

 Parameters  : $level_limit - number of previous calls to return
 Returns     : multi-line string containing subroutine caller information
 Description :

=cut

sub get_caller_trace {
	my ($level_limit, $brief_output) = @_;
	$level_limit = 4 if !$level_limit;

	# Add one to make the argument usage more intuitive
	# One of the levels is the subroutine which called this
	$level_limit++;
	
	# Check if this subroutine was called from notify
	my $called_from_notify = ((caller(1))[3] =~ /notify$/)? 1 : 0;
	
	my $caller_trace = "";
	for (1 .. $level_limit) {
		my $caller_index = $_;
		if (caller($caller_index)) {
			my ($package_last, $filename_last, $line_last, $sub_last) = caller($caller_index - 1);
			my ($package,      $filename,      $line,      $sub)      = caller($caller_index);
			
			$filename_last =~ s/.*\///;
			$sub           =~ s/.*:://;
			
			if ($called_from_notify) {
				if ($sub =~ /notify$/) {
					next;
				}
				else {
					$caller_index--;
				}
			}
			
			if ($brief_output) {
				$caller_trace .= (($caller_index - 1) * -1) . ":$filename_last:$sub:$line_last;";
			}
			else {
				$caller_trace .= "(" . sprintf("% d", (($caller_index - 1) * -1)) . ") $filename_last, $sub (line: $line_last)\n";
			}
		} ## end if (caller($caller_index))
		else {
			last;
		}
	} ## end for (1 .. $level_limit)

	# Remove the trailing semicolon if brief output is used
	$caller_trace =~ s/;$//;

	# Chomp the trailing newline if brief output isn't used
	chomp $caller_trace;

	return $caller_trace;
} ## end sub get_caller_trace

#/////////////////////////////////////////////////////////////////////////////

=head2 get_calling_subroutine

 Parameters  : none
 Returns     : string
 Description : Returns the name of the subroutine which called the subroutine in
               which get_calling_subroutine is called.

=cut

sub get_calling_subroutine {
	my @caller = caller(2);
	return $caller[3];
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_id

 Parameters  :
 Returns     :
 Description :

=cut

sub get_management_node_id {
	my $management_node_id;

	# Check the management_node_id environment variable
	if ($ENV{management_node_id}) {
		notify($ERRORS{'DEBUG'}, 0, "environment variable: $ENV{management_node_id}");
		return $ENV{management_node_id};
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "management_node_id environment variable not set");
	}

	# If $management_node_id wasn't set using the env variable, try the subroutine
	my $management_node_info = get_management_node_info();
	if ($management_node_info && ($management_node_id = $management_node_info->{id})) {
		notify($ERRORS{'DEBUG'}, 0, "get_managementnode_info(): $management_node_id");
		$ENV{management_node_id} = $management_node_id;
		return $management_node_id;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "get_management_node_info() failed");
	}

	notify($ERRORS{'WARNING'}, 0, "management node ID could not be determined");
	return 0;
} ## end sub get_management_node_id

#/////////////////////////////////////////////////////////////////////////////

sub get_database_table_columns {
	return $ENV{database_table_columns} if $ENV{database_table_columns};
	
	my $database = 'information_schema';

	my $select_all_table_columns = "
SELECT DISTINCT
TABLES.TABLE_NAME,
COLUMNS.COLUMN_NAME
FROM
TABLES,
COLUMNS
WHERE
COLUMNS.TABLE_SCHEMA = \'$DATABASE\'
AND
TABLES.TABLE_NAME = COLUMNS.TABLE_NAME
	";

	# Call the database select subroutine
	my @rows = database_select($select_all_table_columns, $database);

	# Check to make sure 1 row was returned
	if (scalar @rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "unable to get database table columns, 0 rows were returned from database select");
		return 0;
	}

	# Use the map function to populate a hash of arrays
	# The hash keys are the table names
	# The hash values are arrays of column names
	my %database_table_columns;
	map({push @{$database_table_columns{$_->{TABLE_NAME}}}, $_->{COLUMN_NAME}} @rows);
	
	$ENV{database_table_columns} = \%database_table_columns;
	
	return $ENV{database_table_columns};
}

#/////////////////////////////////////////////////////////////////////////////

sub switch_vmhost_id {
	my ($computer_id, $host_id) = @_;

	my ($package,        $filename,        $line,        $sub)        = caller(0);
	my ($caller_package, $caller_filename, $caller_line, $caller_sub) = caller(1);

	my $caller_info = "$caller_sub($line)";

	my $caller = scalar caller;
	notify($ERRORS{'OK'}, 0, "called from $caller_info");

	# Check the arguments
	if (!defined($computer_id)) {
		notify($ERRORS{'CRITICAL'}, 0, "computer_id is undefined");
		return 0;
	}

	if (!(defined($host_id)) || !$host_id) {
		notify($ERRORS{'WARNING'}, 0, "$host_id is either not defined or 0, using NULL");
		$host_id = 'NULL';
	}

	# Construct the update statement
	my $update_statement = "
      UPDATE
		computer
		SET
		vmhostid = $host_id
		WHERE
		computer.id = $computer_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update computer table, id=$computer_id, vmhostid=$host_id");
		return 0;
	}
} ## end sub switch_vmhost_id

#/////////////////////////////////////////////////////////////////////////////

=head2 get_request_loadstate_names

 Parameters  : $request_id
 Returns     : hash reference
 Description : Retrieves the computerloadlog entries for all reservations
               belonging to the request. A hash is constructed with keys set to
               the reservation IDs. The data of each key is a reference to an
               array containing the computerloadstate names.

=cut

sub get_request_loadstate_names {
	my ($request_id) = @_;
	if (!$request_id) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not passed");
		return;
	}

	my $select_statement = <<EOF;
SELECT
reservation.id AS reservation_id,
computerloadstate.loadstatename

FROM
request,
reservation

LEFT JOIN (computerloadlog, computerloadstate) ON (
computerloadlog.reservationid = reservation.id
AND computerloadlog.loadstateid = computerloadstate.id
)

WHERE
request.id = $request_id
AND reservation.requestid = request.id
ORDER BY computerloadlog.timestamp ASC
EOF

	my @rows = database_select($select_statement);
	
	my $computerloadlog_info = {};
	for my $row (@rows) {
		my $reservation_id = $row->{reservation_id};
		my $loadstatename = $row->{loadstatename};
		$computerloadlog_info->{$reservation_id} = [] if !defined($computerloadlog_info->{$reservation_id});
		push @{$computerloadlog_info->{$reservation_id}}, $loadstatename if defined($loadstatename);
	}
	
	my $computerloadlog_string = '';
	for my $reservation_id (keys %$computerloadlog_info) {
		$computerloadlog_string .= "$reservation_id: ";
		$computerloadlog_string .= join(', ', @{$computerloadlog_info->{$reservation_id}});
		$computerloadlog_string .= "\n";
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved computerloadstate names for request $request_id:\n$computerloadlog_string");
	return $computerloadlog_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reservation_being_processed

 Parameters  :  reservation ID
 Returns     :  true if reservation is avtively being processed, false otherwise
 Description :  Checks the computerloadlog table for rows matching the
                reservation ID and loadstate = begin. Returns true if any
					 matching rows exist, false otherwise.

=cut

sub reservation_being_processed {
	my ($reservation_id) = @_;

	# Make sure reservation ID was passed
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not passed");
		return;
	}
	
	my $select_statement = "
	SELECT
	computerloadlog.*
	
	FROM
	computerloadlog,
	computerloadstate
	
	WHERE
	computerloadlog.reservationid = $reservation_id
	AND computerloadlog.loadstateid = computerloadstate.id
	AND computerloadstate.loadstatename = \'begin\'
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @computerloadlog_rows = database_select($select_statement);

	# Check if at least 1 row was returned
	my $computerloadlog_exists;
	if (scalar @computerloadlog_rows == 1) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'begin' entry exists for reservation");
		$computerloadlog_exists = 1;
	}
	elsif (scalar @computerloadlog_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "multiple computerloadlog 'begin' entries exist for reservation");
		$computerloadlog_exists = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'begin' entry does NOT exist for reservation $reservation_id");
		$computerloadlog_exists = 0;
	}
	
	# Check if a vcld process is running matching for this reservation
	my @processes_running = is_management_node_process_running("$PROCESSNAME [0-9]+:$reservation_id ");
	
	# Check the results and return
	if ($computerloadlog_exists && @processes_running) {
		notify($ERRORS{'DEBUG'}, 0, "reservation is currently being processed, computerloadlog 'begin' entry exists and running process was found: @processes_running");
		return 1;
	}
	elsif (!$computerloadlog_exists && @processes_running) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog 'begin' entry does NOT exist but running process was found: @processes_running, assuming reservation is currently being processed");
		return 1;
	}
	elsif ($computerloadlog_exists && !@processes_running) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog 'begin' entry exists but running process was NOT found, assuming reservation is NOT currently being processed");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "reservation is NOT currently being processed");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 run_command

 Parameters  : string
 Returns     : array if command run, undefined if it didn't
 Description : Runs a command locally on the management node.
               If command completed successfully, an array containing
               the exit status and a reference to an array containing the
               lines of output of the command specified is returned.
               $array[0] = the exit status of the command
               $array[1] = reference to array containing lines of output
                           generated by the command
               If the command fails, an empty array is returned.

=cut

sub run_command {
	my ($command, $no_output) = @_;
	
	my $output_string = `$command 2>&1`;
	my $exit_status = $?;
	if ($exit_status >= 0) {
		$exit_status = $exit_status >> 8;
	}
	
	# Remove any trailing newlines from the output
	chomp $output_string;
	
	# Split the output string into an array of lines
	my @output = split(/[\r\n]+/, $output_string);
	
	if (!$no_output) {
		notify($ERRORS{'DEBUG'}, 0, "executed command: $command, exit status: $exit_status, output:\n@output");
	}
	return ($exit_status, \@output);
}
	
#/////////////////////////////////////////////////////////////////////////////

=head2 string_to_ascii

 Parameters  :  string
 Returns     :  string with special ASCII characters replaced with character
                names
 Description :  Takes the string passed, checks each character, and replaces
                special ASCII characters with the character name. For
					 example, "This is a\r\nstring." would return
					 "This[SP]is[SP]a[CR][LF]string."

=cut

sub string_to_ascii {
	my $string = shift;
	
	my %ascii_codes = (
		0 => 'NUL',
		1 => 'SOH',
		2 => 'STX',
		3 => 'ETX',
		4 => 'EOT',
		5 => 'ENQ',
		6 => 'ACK',
		7 => 'BEL',
		8 => 'BS',
		9 => 'HT',
		10 => 'LF',
		11 => 'VT',
		12 => 'FF',
		13 => 'CR',
		14 => 'SO',
		15 => 'SI',
		16 => 'DLE',
		17 => 'DC1',
		18 => 'DC2',
		19 => 'DC3',
		20 => 'DC4',
		21 => 'NAK',
		22 => 'SYN',
		23 => 'ETB',
		24 => 'CAN',
		25 => 'EM',
		26 => 'SUB',
		27 => 'ESC',
		28 => 'FS',
		29 => 'GS',
		30 => 'RS',
		31 => 'US',
		32 => 'SP',
		127 => 'DEL',
	);
	
	my $ascii_value_string;
	foreach my $ascii_code (unpack("C*", $string)) {
		if (defined($ascii_codes{$ascii_code})) {
			$ascii_value_string .= "[$ascii_codes{$ascii_code}]";
			$ascii_value_string .= "\n" if $ascii_code == 10;
		}
		else {
			$ascii_value_string .= pack("C*", $ascii_code);
		}
	}
	
	if (defined($ascii_value_string)) {
		return $ascii_value_string;
	}
	else {
		return '';
	}
}


#/////////////////////////////////////////////////////////////////////////////

=head2 add_imageid_to_newimages

 Parameters  : $ownerid, $resourceid, $virtual
 Returns     : 1, 0 
 Description : Calls the RPC::XML function defined in the arguments

=cut
sub add_imageid_to_newimages {
	my ($ownerid, $resourceid, $virtual) = @_;

   my ($package, $filename, $line, $sub) = caller(0);

   # Check the arguments
   if (!defined($ownerid)) {
       notify($ERRORS{'WARNING'}, 0, "ownerid was not specified");
       return 0;
   }
   if (!defined($resourceid)) {
       notify($ERRORS{'WARNING'}, 0, "resourceid was not specified");
       return 0;
   }
   if (!defined($virtual)) {
       notify($ERRORS{'WARNING'}, 0, "virtual was not specified");
       return 0;
   }

	my $method = "XMLRPCfinishBaseImageCapture";
	my @argument_string = ($method,$ownerid, $resourceid, $virtual); 
	my $xml_ret = xmlrpc_call(@argument_string);
	# Check if the XML::RPC call failed
   if (!defined($xml_ret)) {
      notify($ERRORS{'WARNING'}, 0, "failed to add image to owner's new image group, XML::RPC '$method' call failed");
      return 0;
   }
   elsif ($xml_ret->value->{status} !~ /success/) {
      notify($ERRORS{'WARNING'}, 0, "failed to add image to owner's newimage group, XML::RPC '$method' status: $xml_ret->value->{status}\n" .
            "error code $xml_ret->value->{errorcode}\n" .
            "error message: $xml_ret->value->{errormsg}"
       );
       return 0;
	}
   else {
	 return 1;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 xmlrpc_call

 Parameters  : @arguments
 Returns     : RPC::XML::Client response value
 Description : Calls the RPC::XML function defined in the arguments

=cut

sub xmlrpc_call {
	my @arguments = @_;
	if (!@arguments) {
		notify($ERRORS{'WARNING'}, 0, "no arguments were passed to subroutine");
		return;
	}
	
	if (!$XMLRPC_URL || !$XMLRPC_USER || !$XMLRPC_PASS) {
		notify($ERRORS{'WARNING'}, 0, "unable to call " . join(", ", @arguments) . " function - RPC::XML values have not been set in the vcld.ini file");
		return;
	}
	
	# Create a Client object
	my $client;
	
	if (LWP::UserAgent->new->can('ssl_opts')) {
		notify($ERRORS{'DEBUG'}, 0, "RPC::XML version supports useragent options, setting verify_hostname to 0");
		$client = RPC::XML::Client->new($XMLRPC_URL, useragent => ['ssl_opts' => {verify_hostname => 0}]);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "RPC::XML version does not support useragent options");
		$client = RPC::XML::Client->new($XMLRPC_URL);
	}
	
	$client->request->header('X-User' => $XMLRPC_USER);
	$client->request->header('X-Pass' => $XMLRPC_PASS);
	$client->request->header('X-APIVERSION' => 2);
	
	if (defined($client)) {
		notify($ERRORS{'DEBUG'}, 0, "created RPC::XML client object:\n" .
				 "URL: $XMLRPC_URL\n" .
				 "username: $XMLRPC_USER"
		);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create a new RPC::XML client object, error: " . ($RPC::XML::ERROR || '<none>'));
		return;
	}
	
	# Call send_request
	my $response = $client->send_request(@arguments);
	$ENV{rpc_xml_response} = $response;
	
	if (!ref($response)) {	
		notify($ERRORS{'WARNING'}, 0, "RPC::XML::Client::send_request failed\n" .
			"URL: $XMLRPC_URL\n" .
			"username: $XMLRPC_USER\n" .
			"password: $XMLRPC_PASS\n" ."error: " . ($RPC::XML::ERROR || '<none>') . "\n" .
			"arguments: " . join(", ", @arguments) . "\n" .
			"response: '$response'\n" . format_data($response)
			#"client: '$client'\n" . format_data($client)
		);
		
		$ENV{rpc_xml_error} = $response;
		$ENV{rpc_xml_error} =~ s/^RPC::XML::Client::send_request:\s*//;
		return;
	}
	
	# Check if fault occurred
	if ($response->is_fault) {
		notify($ERRORS{'WARNING'}, 0, "RPC::XML::Client::send_request fault occurred\n" .
			"URL: $XMLRPC_URL\n" .
			"username: $XMLRPC_USER\n" .
			"password: $XMLRPC_PASS\n" .
			"arguments: " . join(", ", @arguments) . "\n" .
			"fault code: " . $response->code . "\n" .
			"fault string: " . $response->string
		);
		$ENV{rpc_xml_error} = $response->string;
		return;
	}
	
	# Display the response details
	notify($ERRORS{'OK'}, 0, "called RPC::XML::Client::send_request:\n" .
		"arguments: " . join(", ", @arguments) . "\n" .
		"response value:\n" . format_data($response->value)
	);
	
	# Return the response
	return $response;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_management_node_process_running

 Parameters  : $process_identifier
 Returns     : array or hash reference
 Description : Determines if any processes matching the $process_identifier
               argument are running on the management node. The
               $process_identifier must be a regular expression understood by
               pgrep. The return value differs based on how this subroutine is
               called.
               
               If called in scalar context, a hash reference is
               returned. The hash keys are PIDs and the values are the full name
               of the process.
               
               If called in list context, an array is returned containing the
               PIDs.

=cut

sub is_management_node_process_running {
	my ($process_identifier) = @_;
	
	# Check the arguments
	unless ($process_identifier) {
		notify($ERRORS{'WARNING'}, 0, "process PID or name argument was not specified");
		return;
	}
	
	my $command = "pgrep -fl '$process_identifier'";
	my ($exit_status, $output) = run_command($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine if process is running: $command");
		return;
	}
	
	my $processes_running = {};
	for my $line (@$output) {
		my ($pid, $process_name) = $line =~ /^(\d+)\s*(.*)/;
		
		if (!defined($pid)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring pgrep output line, it does not begin with a number: $line");
			next;
		}
		elsif ($pid eq $PID) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring pgrep output line for the currently running process: $line");
			next;
		}
		elsif ($line =~ /pgrep -fl/) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring pgrep output line containing for pgrep command: $line");
			next;
		}
		elsif ($line =~ /sh -c/) {
			# Ignore lines containing 'sh -c', probably indicating a duplicate process of a command run remotely
			notify($ERRORS{'DEBUG'}, 0, "ignoring pgrep output line containing 'sh -c': $line");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found matching process: $line");
			$processes_running->{$pid} = $process_name;
		}
	}
	
	my $process_count = scalar(keys %$processes_running);
	if ($process_count) {
		if (wantarray) {
			my @process_ids = sort keys %$processes_running;
			notify($ERRORS{'DEBUG'}, 0, "process is running, identifier: '$process_identifier', returning array containing PIDs: @process_ids");
			return @process_ids;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "process is running, identifier: '$process_identifier', returning hash reference:\n" . format_data($processes_running));
			return $processes_running;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "process is NOT running, identifier: '$process_identifier'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 read_file_to_array

 Parameters  : File path
 Returns     : If successful: array containing lines in file
               If failed: false
 Description : Returns the contents of the file specified by the argument in an
               array. Each array element contains a line from the file.

=cut

sub read_file_to_array {
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	unless (open(FILE, $file_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to open file: $file_path, reason: $!");
		return;
	}
   
	my @file_contents = <FILE>;
	close FILE;
	
	return @file_contents;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_valid_ip_address

 Parameters  : IP address string
 Returns     : If valid: true
               If not valid: false
 Description : Determines if the argument is a valid IP address.

=cut

sub is_valid_ip_address {
	my $ip_address = shift;
	if (!$ip_address) {
		notify($ERRORS{'WARNING'}, 0, "IP address argument was not specified");
		return;
	}
	
	# Split up the IP address being checked into its octets
	my @octets = split(/\./, $ip_address);
	
	# Make sure 4 octets were found
	if (scalar @octets != 4) {
		notify($ERRORS{'DEBUG'}, 0, "IP address does not contain 4 octets: $ip_address, octets:\n" . join("\n", @octets));
		return 0;
	}
	
	# Make sure address only contains digits
	if (grep(/\D/, @octets)) {
		notify($ERRORS{'DEBUG'}, 0, "IP address contains a non-digit: $ip_address");
		return 0;
	}
	
	# Make sure none of the octets is > 255
	if ($octets[0] > 255 || $octets[0] > 255 || $octets[0] > 255 || $octets[0] > 255) {
		notify($ERRORS{'DEBUG'}, 0, "IP address contains an octet > 255: $ip_address");
		return 0;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "IP address is valid: $ip_address");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_valid_dns_host_name

 Parameters  : $dns_host_name
 Returns     : If valid: true
               If not valid: false
 Description : Determines if the argument is a valid DNS host name.

=cut

sub is_valid_dns_host_name {
	my $dns_host_name = shift;
	if (!$dns_host_name) {
		notify($ERRORS{'WARNING'}, 0, "DNS host name argument was not specified");
		return;
	}
	
	if (!$dns_host_name) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name argument was not specified");
		return 0;
	}
	
	if ((my $length = length($dns_host_name)) > 255) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name is too long ($length characters): $dns_host_name");
		return 0;
	}
	
	if (my @illegal_characters = $dns_host_name =~ /([^\da-z\.\-])/i) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name contains illegal characters: " . join(" ", @illegal_characters));
		return 0;
	}
	
	if ($dns_host_name =~ /\.\./i) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name contains contiguous periods: $dns_host_name");
		return 0;
	}
	
	if ($dns_host_name !~ /^[\da-z]/i) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name does not begin with a letter or digit: " . string_to_ascii($dns_host_name));
		return 0;
	}
	
	if (grep(/^\d+$/, split(/\./, $dns_host_name))) {
		notify($ERRORS{'DEBUG'}, 0, "DNS host name contains a section comprised only of digits: $dns_host_name");
		return 0;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "DNS host name is valid: $dns_host_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_public_ip_address

 Parameters  : IP address string
 Returns     : If public: true
               If not public: false
 Description : Determines if the argument is a valid public IP address. It will
               return true if the IP address is valid and not in any of the
               following ranges:
               Private:
                  10.0.0.0 - 10.255.255.255
                  172.16.0.0 - 172.16.31.255.255
                  192.168.0.0 - 192.168.255.255
               Loopback:
                  127.0.0.0 - 127.255.255.255
               Reserved:
                  0.0.0.0
                  169.254.0.1 - 169.254.255.254
                  191.255.0.0
                  223.255.255.0
                  240.0.0.0 - 255.255.255.254
               Multicast:
                  224.0.0.0 - 239.255.255.255
               Broadcast:
                  255.255.255.255
=cut

sub is_public_ip_address {
	my $ip_address = shift;
	if (!$ip_address) {
		notify($ERRORS{'WARNING'}, 0, "IP address argument was not specified");
		return;
	}
	
	# Split up the IP address being checked into its octets
	my @octets = split(/\./, $ip_address);
	
	# Make sure the address is valid
	unless (is_valid_ip_address($ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if IP address is private, the address is not valid: $ip_address");
		return 0;
	}
	
	# Determine the type of address address
	# Private:
	# 10.0.0.0 - 10.255.255.255
	# 172.16.0.0 - 172.16.31.255.255
	# 192.168.0.0 - 192.168.255.255
	if (($octets[0] == 10) ||
		 ($octets[0] == 172 && ($octets[1] >= 16 && $octets[1] <= 31)) ||
		 ($octets[0] == 192 && $octets[1] == 168)
		) {
		notify($ERRORS{'DEBUG'}, 0, "private IP address: $ip_address, returning 0");
		return 0;
	}
	# Loopback:
	# 127.0.0.0 - 127.255.255.255
	elsif ($ip_address =~ /^127/) {
		notify($ERRORS{'DEBUG'}, 0, "loopback IP address: $ip_address, returning 0");
		return 0;
	}
	# Reserved:
	# 0.0.0.0
	# 169.254.0.1 - 169.254.255.254
	# 191.255.0.0
	# 223.255.255.0
	# 240.0.0.0 - 255.255.255.254
	elsif (($ip_address eq '0.0.0.0') ||
			 ($ip_address =~ /^169\.254/) ||
			 ($ip_address eq '191.255.0.0') ||
			 ($ip_address eq '223.255.255.0') ||
			 ($octets[0] >= 240 && $octets[0] <= 255)
			 ) {
		notify($ERRORS{'DEBUG'}, 0, "reserved IP address: $ip_address, returning 0");
		return 0;
	}
	# Multicast:
	# 224.0.0.0 - 239.255.255.255
	elsif ($octets[0] >= 224 && $octets[0] <= 239) {
		notify($ERRORS{'DEBUG'}, 0, "multicast IP address: $ip_address, returning 0");
		return 0;
	}
	# Broadcast:
	# 255.255.255.255
	elsif ($ip_address eq '255.255.255.255') {
		notify($ERRORS{'DEBUG'}, 0, "broadcast IP address: $ip_address, returning 0");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "public IP address: $ip_address, returning 1");
		return 1;
	}
}
#/////////////////////////////////////////////////////////////////////////////

=head2 get_block_request_image_info

 Parameters  :  computer ID
 Returns     :  imagename imageid imagerevisionid
 Description :  Checks the blockcomputers table matching computer id

=cut
#/////////////////////////////////////////////////////////////////////////////

sub get_block_request_image_info {
	my ($computerid) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameters
	if (!(defined($computerid))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}
	# Construct the select statement
	my $select_statement = "
	SELECT DISTINCT
	image.name AS image_name,
	image.id AS image_id,
	imagerevision.id AS imagerevision_id,
	blockTimes.start AS starttime
	FROM
	image,
	imagerevision,
	blockComputers,
	blockTimes
	WHERE
	blockComputers.imageid = image.id
	AND imagerevision.imageid = image.id 
   AND imagerevision.production = 1
	AND blockTimes.id = blockComputers.blockTimeid
	AND blockComputers.computerid = $computerid 
	ORDER BY blockTimes.start LIMIT 1
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @block_image_info = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @block_image_info == 0) {
		notify($ERRORS{'WARNING'}, 0, "no block reservation image information existed for $computerid, 0 rows were returned");
		return;
	}

	if (scalar @block_image_info == 1) {
		my @ret_array;
		push (@ret_array, $block_image_info[0]{image_name},$block_image_info[0]{image_id},$block_image_info[0]{imagerevision_id});
		return @ret_array;
	}

	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_module_info

 Parameters  : Module ID (optional)
 Returns     : Array
 Description : Returns a hash reference containing information from the module
               table.
               
               An optional module ID argument can be supplied. If supplied, only
               the information for the specified module is returned.
               
               A hash reference is returned. The keys of the hash are the module IDs.
               Example showing the format of the data structure returned:
               
               my $module_info = get_module_info();
               $module_info->{15}
                  |--{description} = 'Provides OS support for standalone Unix lab machines'
                  |--{name} = 'os_unix_lab'
                  |--{perlpackage} = 'VCL::Module::OS::Linux::UnixLab'
                  |--{prettyname} = 'Unix Lab OS Module'
               $module_info->{15}
                  |--{description} = ''
                  |--{name} = 'os_win2008'
                  |--{perlpackage} = 'VCL::Module::OS::Windows::Version_6::2008'
                  |--{prettyname} = 'Windows Server 2008 OS Module'

=cut

sub get_module_info {
	# Create the select statement
	my $select_statement = "
   SELECT
	*
	FROM
	module
	";
	
	# Append a WHERE clause if a module ID argument was supplied
	my $module_id = shift;
	if ($module_id) {
		$select_statement .= "WHERE id = $module_id";
	}

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure rows were returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve rows from module table");
		return;
	}
	
	# Transform the array of database rows into a hash
	my %module_info_hash;
	for my $row (@selected_rows) {
		my $module_id = $row->{id};
		
		for my $key (keys %$row) {
			next if $key eq 'id';
			my $value = $row->{$key};
			$module_info_hash{$module_id}{$key} = $value;
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved module info:\n" . format_data(\%module_info_hash));
	return \%module_info_hash;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_package_name

 Parameters  : None
 Returns     : String
 Description : Returns a string containing the name of the Perl package which
               called get_current_package_name.

=cut

sub get_current_package_name {
	my $package_name = (caller(0))[0];
	return $package_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_file_name

 Parameters  : None
 Returns     : String
 Description : Returns a string containing the name of the file which
               called get_current_file_name.

=cut

sub get_current_file_name {
	my $file_name = (caller(0))[1];
	
	# Remove path leaving only file name
	$file_name =~ s/.*\///g;
	
	return $file_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_subroutine_name

 Parameters  : None
 Returns     : String
 Description : Returns a string containing the name of the subroutine which
               called get_current_subroutine_name.

=cut

sub get_current_subroutine_name {
	my $subroutine_name = (caller(1))[3];
	
	# Remove path leaving only sub name
	$subroutine_name =~ s/.*:://g;
	
	return $subroutine_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_affiliation_info

 Parameters  : Affiliation ID (optional)
 Returns     : Array
 Description : Returns a hash reference containing information from the affiliation
               table.
               
               An optional affiliation ID argument can be supplied. If supplied, only
               the information for the specified affiliation is returned.
               
               A hash reference is returned. The keys of the hash are the affiliation IDs.
               Example showing the format of the data structure returned:
               
               my $affiliation_info = get_affiliation_info();
					$affiliation_info->{0}
						|--{dataUpdateText} = ''
						|--{helpaddress} = NULL
						|--{name} = 'Global'
						|--{shibname} = NULL
						|--{shibonly} = '0'
						|--{sitewwwaddress} = NULL
					$affiliation_info->{1}
						|--{dataUpdateText} = '<font size="-2">* To update any of these fields, follow the appropriate<br>link under <strong>Related Tools</strong> at the Campus Directory</font>'
						|--{helpaddress} = 'vcl_help@blah.edu'
						|--{name} = 'University of Blah'
						|--{shibname} = 'blah.edu'
						|--{shibonly} = '0'
						|--{sitewwwaddress} = 'http://vcl.blah.edu'


=cut

sub get_affiliation_info {
	# Create the select statement
	my $select_statement = "
   SELECT
	*
	FROM
	affiliation
	";
	
	# Append a WHERE clause if a affiliation ID argument was supplied
	my $affiliation_id = shift;
	if ($affiliation_id) {
		$select_statement .= "WHERE id = $affiliation_id";
	}

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure rows were returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve rows from affiliation table");
		return;
	}
	
	# Transform the array of database rows into a hash
	my %affiliation_info_hash;
	for my $row (@selected_rows) {
		my $affiliation_id = $row->{id};
		
		for my $key (keys %$row) {
			next if $key eq 'id';
			my $value = $row->{$key};
			$affiliation_info_hash{$affiliation_id}{$key} = $value;
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved affiliation info:\n" . format_data(\%affiliation_info_hash));
	return \%affiliation_info_hash;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 format_number

 Parameters  : $number, $decimal_places (optional)
 Returns     : string
 Description : Formats a number with commas and rounds it to a number of
               decimal places.  The default number of decimal places is 0 so
               that numbers are rounded to the nearest integer.

=cut

sub format_number {
	my ($number, $decimal_places) = @_;
	$decimal_places = 0 if !$decimal_places;
	$number = sprintf("%." . $decimal_places . "f", $number);
	
	$number = reverse($number);
	$number =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
	
	return scalar reverse $number;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_file_size_info_string

 Parameters  : $bytes
 Returns     : string
 Description : 

=cut

sub get_file_size_info_string {
	my ($size_bytes, $separator) = @_;
	$separator = " - " if !$separator;
	
	my $size_kb = format_number(($size_bytes / 1024), 1);
	my $size_mb = format_number(($size_bytes / 1024 ** 2), 1);
	my $size_gb = format_number(($size_bytes / 1024 ** 3), 2);
	my $size_tb = format_number(($size_bytes / 1024 ** 4), 2);
	
	my $size_info;
	$size_info .= format_number($size_bytes) . " bytes$separator";
	$size_info .= "$size_kb KB$separator";
	$size_info .= "$size_mb MB$separator";
	$size_info .=  "$size_gb GB";
	$size_info .=  "$separator$size_tb TB" if ($size_tb >= 1);
	return $size_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_copy_speed_info_string

 Parameters  : $copied_bytes, $duration_seconds
 Returns     : string
 Description : Calculates various copy rates based on the amount of data copied
               and time the copy took.

=cut

sub get_copy_speed_info_string {
	my ($copied_bytes, $duration_seconds) = @_;
	
	my $minutes = ($duration_seconds / 60);
	$minutes =~ s/\..*//g;
	my $seconds = ($duration_seconds - ($minutes * 60));
	if (length($seconds) == 0) {
		$seconds = "00";
	}
	elsif (length($seconds) == 1) {
		$seconds = "0$seconds";
	}
	
	my $copied_bits = ($copied_bytes * 8);
	
	my $copied_kb = ($copied_bytes / 1024);
	my $copied_mb = ($copied_bytes / 1024 / 1024);
	my $copied_gb = ($copied_bytes / 1024 / 1024 / 1024);
	
	my $copied_kbit = ($copied_bits / 1024);
	my $copied_mbit = ($copied_bits / 1024 / 1024);
	my $copied_gbit = ($copied_bits / 1024 / 1024 / 1024);
	
	my $bytes_per_second = ($copied_bytes / $duration_seconds);
	my $kb_per_second = ($copied_kb / $duration_seconds);
	my $mb_per_second = ($copied_mb / $duration_seconds);
	my $gb_per_second = ($copied_gb / $duration_seconds);
	
	my $bits_per_second = ($copied_bits / $duration_seconds);
	my $kbit_per_second = ($copied_kbit / $duration_seconds);
	my $mbit_per_second = ($copied_mbit / $duration_seconds);
	my $gbit_per_second = ($copied_gbit / $duration_seconds);
	
	my $bytes_per_minute = ($copied_bytes / $duration_seconds * 60);
	my $kb_per_minute = ($copied_kb / $duration_seconds * 60);
	my $mb_per_minute = ($copied_mb / $duration_seconds * 60);
	my $gb_per_minute = ($copied_gb / $duration_seconds * 60);
	
	my $info_string;
	
	$info_string .= "data copied: " . get_file_size_info_string($copied_bytes) . "\n";
	$info_string .= "time to copy: $minutes:$seconds (" . format_number($duration_seconds) . " seconds)\n";
	$info_string .= "---\n";
	$info_string .= "bits copied:  " . format_number($copied_bits) . " ($copied_bits)\n";
	$info_string .= "bytes copied: " . format_number($copied_bytes) . " ($copied_bytes)\n";
	$info_string .= "MB copied:    " . format_number($copied_mb, 1) . "\n";
	$info_string .= "GB copied:    " . format_number($copied_gb, 2) . "\n";
	$info_string .= "---\n";
	$info_string .= "B/m:    " . format_number($bytes_per_minute) . "\n";
	$info_string .= "MB/m:   " . format_number($mb_per_minute, 1) . "\n";
	$info_string .= "GB/m:   " . format_number($gb_per_minute, 2) . "\n";
	$info_string .= "---\n";
	$info_string .= "B/s:    " . format_number($bytes_per_second) . "\n";
	$info_string .= "MB/s:   " . format_number($mb_per_second, 1) . "\n";
	$info_string .= "GB/s:   " . format_number($gb_per_second, 2) . "\n";
	$info_string .= "---\n";
	$info_string .= "Mbit/s: " . format_number($mbit_per_second, 1) . "\n";
	$info_string .= "Gbit/s: " . format_number($gbit_per_second, 2);
	
	return $info_string;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_management_node_directory

 Parameters  : $directory_path
 Returns     : boolean
 Description : Creates a directory on the management node.

=cut

sub create_management_node_directory {
	my ($directory_path) = @_;
	
	# Check if the directory already exists
	if (-d $directory_path) {
		notify($ERRORS{'OK'}, 0, "directory already exists on management node: $directory_path");
		return 1;
	}
	
	# Attempt to create the directory
	my $command = "mkdir -p -v \"$directory_path\" 2>&1 && ls -1d \"$directory_path\"";
	my ($exit_status, $output) = run_command($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create directory on management node: $directory_path\ncommand: $command");
		return;
	}
	elsif (grep(/created directory/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "created directory on management node: $directory_path");
		return 1;
	}
	elsif (grep(/mkdir: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to create directory on management node: $directory_path:\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^$directory_path/, @$output)) {
		notify($ERRORS{'OK'}, 0, "directory already exists on management node: $directory_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to create directory on management node: $directory_path:\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 normalize_file_path

 Parameters  : $path
 Returns     : string
 Description : Normalizes a file or directory path:
               -spaces from the beginning and end of the path are removed
					-quotes from the beginning and end of the path are removed
					-trailing slashes are removed
					-escaped spaces are unescaped

=cut

sub normalize_file_path {
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Remove any spaces and quotes from the beginning and end of the path
	# Remove any slashes from the end of the path
	$path =~ s/(^['"\s]*|['"\s\\\/]*$)//g;
	
	# Unescape any spaces
	$path =~ s/\\+(\s)/$1/g;
	
	return $path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 escape_file_path

 Parameters  : $path
 Returns     : string
 Description : Escapes special characters in a file or directory path with
               backslashes:
               -spaces are escaped

=cut

sub escape_file_path {
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	$path = normalize_file_path($path);
	
	# Call quotemeta to escape all special character
	$path = quotemeta $path;
	
	# Unescape wildcard *, +, characters or else subroutines will fail which accept a wildcard file path
	$path =~ s/\\+([\*\+\/\~])/$1/g;
	
	return $path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parent_directory_path

 Parameters  : $path
 Returns     : string
 Description : Returns the parent directory path of the path argument. The path
               returned is normalized.

=cut

sub parent_directory_path {
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	$path = normalize_file_path($path);
	
	# Remove everything after the last forward or backslash
	$path =~ s/\/[^\/\\]+$//g;
	
	return $path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_get_array_choice

 Parameters  :
 Returns     :
 Description :

=cut

sub setup_get_array_choice {
	my (@choices) = @_;
	notify($ERRORS{'DEBUG'}, 0, "choices argument:\n" . join("\n", @choices));
	
	my $choice_count = scalar(@choices);
	
	while (1) {
		for (my $i=1; $i<=$choice_count; $i++) {
			print "$i. $choices[$i-1]\n";
		}
		print "\n[" . join("/", @{$ENV{setup_path}}) . "]\n";
		print "Make a selection (1";
		print "-$choice_count" if ($choice_count > 1);
		print ", 'c' to cancel): ";
		
		my $choice = <STDIN>;
		chomp $choice;
		
		if ($choice =~ /^c$/i) {
			return;
		}
		if ($choice !~ /^\d+$/ || $choice < 1 || $choice > $choice_count) {
			print "\n*** Choice must be an integer between 1 and $choice_count ***\n\n";
		}
		else {
			return ($choice - 1);
		}
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_get_input_string

 Parameters  :
 Returns     :
 Description :

=cut

sub setup_get_input_string {
	my ($message, $default_value) = @_;
	if ($default_value) {
		print "$message [$default_value]: ";
	}
	else {
		print "$message ('c' to cancel): ";
	}
	
	my $input = <STDIN>;
	chomp $input;
	if ($input =~ /^c$/i) {
		return;
	}
	elsif ($default_value && !length($input)) {
		return $default_value;
	}
	else {
		return $input;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_get_hash_choice

 Parameters  : $hash_ref, $display_key ()
 Returns     :
 Description :

=cut

sub setup_get_hash_choice {
	my ($hash_ref, $display_key1, $display_key2) = @_;
	
	my $choice_count = scalar(keys %$hash_ref);
	
	my %choices;
	for my $key (keys %$hash_ref) {
		my $display_name;
		if ($display_key1) {
			$display_name = $hash_ref->{$key}{$display_key1};
		}
		if ($display_key2) {
			$display_name .= " (" . $hash_ref->{$key}{$display_key2} . ")";
		}
		
		if (!$display_name) {
			$display_name = $key;
		}
		
		if ($choices{$display_name}) {
			notify($ERRORS{'WARNING'}, 0, "duplicate hash keys containing the value '$display_name', hash argument:\n" . format_data($hash_ref));
		}
		
		$choices{$display_name} = $key;
	}
	
	my $choice_index = setup_get_array_choice(sort keys %choices);
	return if (!defined($choice_index));
	
	my $choice_name = (sort keys %choices)[$choice_index];
	return $choices{$choice_name};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_confirm

 Parameters  : $message
 Returns     : boolean
 Description : Displays the message to the user and loops until they enter Y or
               N.

=cut

sub setup_confirm {
	my ($message) = @_;
	
	while (1) {
		print "$message (Y/N)? ";
		my $input = <STDIN>;
		if ($input =~ /^y(es)?$/i) {
			return 1;
		}
		elsif ($input =~ /^n(o)?$/i) {
			return 0;
		}
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_print_wrap

 Parameters  : $message, $columns (optional)
 Returns     :
 Description : Prints a message to STDOUT formatted to the column width. 76 is
               the default column value.

=cut

sub setup_print_wrap {
	my ($message, $columns) = @_;
	$columns = 76 if !defined($columns);
	
	return if !$message;
	
	# Save the leading and trailing lines then remove them from the string
	# This is done so wrap doesn't lose them
	my ($leading_newlines) = $message =~ /^(\n+)/;
	$message =~ s/^\n+//g;
	my ($trailing_newlines) = $message =~ /(\n+)$/;
	$message =~ s/\n+$//g;
	
	# Wrap text for lines
	local($Text::Wrap::columns) = $columns;
	print $leading_newlines if $leading_newlines;
	print wrap('', '', $message);
	print $trailing_newlines if $trailing_newlines;
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_os_info

 Parameters  : none
 Returns     : hash reference
 Description : Returns the contents of the OS table as a hash reference. The
               hash keys are the OS IDs.

=cut

sub get_os_info {
	# Create the select statement
	my $select_statement = <<EOF;
SELECT
OS.*,
module.name AS module_name,
module.prettyname AS module_prettyname,
module.perlpackage AS module_perlpackage
FROM
OS,
module
WHERE
OS.moduleid = module.id
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	my %info;
	
	for my $row (@selected_rows) {
		my $os_id = $row->{id};
		
		foreach my $key (keys %$row) {
			my $value = $row->{$key};
			
			(my $original_key = $key) =~ s/^.+_//;
	
			if ($key =~ /module_/) {
				 $info{$os_id}{module}{$original_key} = $value;
			}
			else {
				$info{$os_id}{$original_key} = $value;
			}
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved OS info:\n" . format_data(\%info));
	return \%info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 kill_child_processes

 Parameters  : $parent_pid
 Returns     : boolean
 Description : Kills all child processes belonging to the parent PID specified
               as the argument.

=cut

sub kill_child_processes {
	my @parent_pids = @_;
	my $parent_pid = $parent_pids[-1];
	my $parent_process_string = "parent PID: " . join(">", @parent_pids);
	
	# Make sure the parent vcld daemon process didn't call this subroutine for safety
	# Prevents all reservations being processed from being killed
	if ($ENV{vcld}) {
		notify($ERRORS{'CRITICAL'}, 0, "kill_child_processes subroutine called from the parent vcld process, not killing any processes for safety");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$parent_process_string: attempting to kill child processes");
	
	my $command = "pgrep -flP $parent_pid | sort -r";
	my ($exit_status, $output) = run_command($command, 1);
	
	for my $line (@$output) {
		# Make sure the line only contains a PID
		my ($child_pid, $child_command) = $line =~ /^(\d+)\s+(.*)/;
		if (!defined($child_pid) || !defined($child_command)) {
			notify($ERRORS{'WARNING'}, 0, "$parent_process_string: pgrep output line does not contain a PID and command:\nline: '$child_pid'\ncommand: '$command'");
			next;
		}
		elsif ($child_command =~ /$command/) {
			# Ignore the pgrep command called to determine child processes
			next;
		}
		
		# Create a string containing the beginning and end of the child process command to make log output more readable
		my $child_command_summary = join('...', ($child_command =~ /^(.{10,20}).*(.{20,30})$/));
		
		notify($ERRORS{'DEBUG'}, 0, "$parent_process_string, found child process: $child_pid '$child_command_summary'");
		
		# Recursively kill the child processes of the child process
		kill_child_processes(@parent_pids, $child_pid);
		
		my $kill_count = kill 9, $child_pid;
		if ($kill_count) {
			notify($ERRORS{'DEBUG'}, 0, "$parent_process_string, killed child process: $child_pid (kill count: $kill_count)");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$parent_process_string, kill command returned 0 attempting to kill child process: $child_pid");
		}
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_connect_method_info

 Parameters  : $imagerevision_id, $no_cache (optional)
 Returns     : hash reference
 Description : Returns the connect methods for the image revision specified as
               the argument.

=cut

sub get_connect_method_info {
	my ($imagerevision_id, $no_cache) = @_;
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision ID argument was not supplied");
		return;
	}
	
	# Check if cached image info exists
	if (!$no_cache && defined($ENV{connect_method_info}{$imagerevision_id})) {
		my $connect_method_id = (keys(%{$ENV{connect_method_info}{$imagerevision_id}}))[0];
		if ($connect_method_id) {
			# Check the time the info was last retrieved
			my $data_age_seconds = (time - $ENV{connect_method_info}{$imagerevision_id}{$connect_method_id}{RETRIEVAL_TIME});
			if ($data_age_seconds < 600) {
				return $ENV{connect_method_info}{$imagerevision_id};
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "retrieving current connect method info for imagerevision $imagerevision_id from database, cached data is stale: $data_age_seconds seconds old");
			}
		}
	}
	
	my $imagerevision_info = get_imagerevision_info($imagerevision_id);
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve connect method info:\n" .
		"imagerevision: $imagerevision_id - " . $imagerevision_info->{imagename} . "\n" .
		"OS: " . $imagerevision_info->{image}{OS}{id} . " - " . $imagerevision_info->{image}{OS}{name} . "\n" .
		"OS type: " . $imagerevision_info->{image}{OS}{OStype}{id} . " - " . $imagerevision_info->{image}{OS}{OStype}{name}
	);
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'connectmethod',
		'connectmethodmap'
	);
	
	# Construct the select statement
	my $select_statement = "SELECT DISTINCT\n";
	
	# Get the column names for each table and add them to the select statement
	for my $table (@tables) {
		my @columns = @{$database_table_columns->{$table}};
		for my $column (@columns) {
			$select_statement .= "$table.$column AS '$table-$column',\n";
		}
	}
	
	# Remove the comma after the last column line
	$select_statement =~ s/,$//;
	
	# Complete the select statement
	$select_statement .= <<EOF;
FROM
connectmethod,
connectmethodmap,
imagerevision

LEFT JOIN image ON (image.id = imagerevision.imageid)
LEFT JOIN OS ON (OS.id = image.OSid)
LEFT JOIN OStype ON (OStype.name = OS.type)

WHERE
connectmethodmap.connectmethodid = connectmethod.id
AND imagerevision.id = $imagerevision_id
AND connectmethodmap.autoprovisioned IS NULL
AND (
	connectmethodmap.OStypeid = OStype.id
	OR connectmethodmap.OSid = OS.id 
	OR connectmethodmap.imagerevisionid = imagerevision.id
)

ORDER BY
connectmethod.id,
connectmethodmap.imagerevisionid,
connectmethodmap.OSid,
connectmethodmap.OStypeid,
connectmethodmap.disabled
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	# Transform the array of database rows into a hash
	my $connect_method_info = {};
	
	my $timestamp = time;
	for my $row (@selected_rows) {	
		notify($ERRORS{'DEBUG'}, 0, $row->{"connectmethod-name"} . ": " .
		"connectmethodid=" . $row->{"connectmethod-id"} . ", " .
		"OStypeid=" . ($row->{"connectmethodmap-OStypeid"} || 'NULL') . ", " .
		"OSid=" . ($row->{"connectmethodmap-OSid"} || 'NULL') . ", " .
		"imagerevisionid=" . ($row->{"connectmethodmap-imagerevisionid"} || 'NULL') . ", " .
		"disabled=" . $row->{"connectmethodmap-disabled"});
		
		my $connectmethod_id = $row->{'connectmethod-id'};
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			next if $key eq 'connectmethod-connecttext';
			
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			# Add the values for the primary table to the hash
			# Add values for other tables under separate keys
			if ($table eq $tables[0]) {
				$connect_method_info->{$connectmethod_id}{$column} = $value;
			}
			else {
				$connect_method_info->{$connectmethod_id}{$table}{$column} = $value;
			}
		}
		$connect_method_info->{$connectmethod_id}{RETRIEVAL_TIME} = $timestamp;
	}

	#notify($ERRORS{'DEBUG'}, 0, "retrieved connect method info:\n" . format_data($connect_method_info));
	$ENV{connect_method_info}{$imagerevision_id} = $connect_method_info;
	return $ENV{connect_method_info}{$imagerevision_id};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_random_mac_address

 Parameters  : $prefix (optional)
 Returns     : string
 Description : Generates a random MAC address.

=cut

sub get_random_mac_address {
	my ($prefix) = @_;
	
	if ($prefix) {
		# Add a trailing colon if not supplied in the argument
		$prefix =~ s/:+$/:/;
		
		if ($prefix !~ /([a-f0-9]{2}:)+/i) {
			notify($ERRORS{'WARNING'}, 0, "invalid MAC address prefix argument: $prefix");
			return;
		}
		elsif (length($prefix) % 3 != 0) {
			notify($ERRORS{'WARNING'}, 0, "invalid MAC address prefix length: '$prefix'");
			return;
		}
		
	}
	else {
		$prefix = '52:54:';
	}
	
	my $random_octet_count = (6 - (length($prefix) / 3));
	
	# Remove the trailing colon
	$prefix =~ s/:+$//;
	
	my $mac_address = uc($prefix);
	
	for (my $i=0; $i<$random_octet_count; $i++) {
		$mac_address .= ":" . sprintf("%02X",int(rand(255)));
	}
	
	notify($ERRORS{'DEBUG'}, 0, "generated random MAC address: '$mac_address'");
	return $mac_address;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 xml_string_to_hash

 Parameters  : $xml_text
 Returns     : hash reference
 Description : Converts XML text to a hash using XML::Simple:XMLin. The argument
               may be a string of XML text, an array, or array reference of
               lines of XML text.

=cut

sub xml_string_to_hash {
	my @arguments = @_;
	if (!@arguments) {
		notify($ERRORS{'WARNING'}, 0, "XML text argument was not specified");
		return;
	}
	
	my $xml_text;
	
	# Check if the argument is an array of lines, array reference, or string
	if (scalar(@arguments) == 1) {
		my $argument = $arguments[0];
		if (my $type = ref($argument)) {
			if ($type eq 'ARRAY') {
				$xml_text = join("\n", @$argument);
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "XML text argument is a $type reference, it may only be a string or array reference");
				return;
			}
		}
		else {
			$xml_text = $argument;
		}
	}
	else {
		$xml_text = join("\n", @arguments);
	}
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Convert the XML to a hash using XML::Simple
	my $xml_hashref;
	eval {
		$xml_hashref = XMLin($xml_text, 'ForceArray' => 1, 'KeyAttr' => []);
	};
	
	if ($xml_hashref) {
		return $xml_hashref;
	}
	elsif ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML text to hash, error: $EVAL_ERROR\nXML text:$xml_text");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML text to hash, XML text:$xml_text");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 hash_to_xml_string

 Parameters  : $xml_hashref, $root_name (optional)
 Returns     : string
 Description : Converts an XML hash reference to text to a hash using
               XML::Simple:XMLout.

=cut

sub hash_to_xml_string {
	my $xml_hashref = shift;
	if (!$xml_hashref) {
		notify($ERRORS{'WARNING'}, 0, "XML hash reference argument was not specified");
		return;
	}
	elsif (!ref($xml_hashref) || ref($xml_hashref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference");
		return;
	}
	
	my $root_name = shift;
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Convert the XML hashref to text using XML::Simple::XMLout
	my $xml_text;
	eval {
		$xml_text = XMLout($xml_hashref, 'RootName' => $root_name, 'KeyAttr' => []);
	};
	
	if ($xml_text) {
		return $xml_text;
	}
	elsif ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML hash reference to text, error: $EVAL_ERROR\nXML hash reference:" . format_data($xml_hashref));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML hash reference to text, XML hash reference:" . format_data($xml_hashref));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sort_by_file_name

 Parameters  : @file_paths
 Returns     : array
 Description : Sorts a list of file paths by file name. Directory paths are
               ignored. File names beginning with numbers are sorted
               numerically.
               Example:
               
               Input array:
                  /var/file_a.txt
                  /tmp/file_b.txt
                  /var/1 file.txt
                  100 file.txt
                  /tmp/99 data.txt
                  50 file.txt
               
               Sorted result:
                  /var/1 file.txt
                  50 file.txt
                  /tmp/99 data.txt
                  100 file.txt
                  /var/file_a.txt
                  /tmp/file_b.txt

=cut

sub sort_by_file_name {
	if (!defined($a) && !defined($b)) {
		my @file_paths = @_;
		if (scalar(@file_paths)) {
			#notify($ERRORS{'DEBUG'}, 0, "not called by sort, \$a and \$b are not defined, array argument was passed");
			return sort sort_by_file_name @file_paths;
		}
		else {
			return ();
		}
	}
	
	# Get the file names from the 2 file paths being compared
	my $a_file_name = ($a =~ /([^\/]+)$/g)[0];
	my $b_file_name = ($b =~ /([^\/]+)$/g)[0];
	
	# Check if both file names begin with a number
	my $a_number = ($a_file_name =~ /^(\d+)/g)[0];
	my $b_number = ($b_file_name =~ /^(\d+)/g)[0];
	
	# If both file names begin with a number, sort numerically
	# Otherwise, sort alphabetically
	if (defined($a_number) && defined($b_number) && $a_number != $b_number) {
		#notify($ERRORS{'DEBUG'}, 0, "numeric comparison - a: $a_file_name ($a_number), b: $b_file_name ($b_number)");
		return $a_number <=> $b_number;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "alphabetic comparison - a: $a_file_name, b: $b_file_name");
		return lc($a_file_name) cmp lc($b_file_name);
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_contents_noDS

 Parameters  : node name
 Returns     : array
 Description : returns contents of currentimage.txt for given node

=cut

sub get_current_image_contents_noDS {

   my ($computer_node_name) = @_;

   if (!defined($computer_node_name)) {
      notify($ERRORS{'WARNING'}, 0, "computer_node_name  argument was not supplied");
      return;
   }

   # Attempt to retrieve the contents of currentimage.txt
   my $cat_command = "cat ~/currentimage.txt";
   my ($cat_exit_status, $cat_output) = run_ssh_command($computer_node_name, $ENV{management_node_info}{keys}, $cat_command);
   if (!defined($cat_output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to execute command to failed to retrieve currentimage.txt from $computer_node_name");
      return;
   }
   elsif ($cat_exit_status ne '0') {
      notify($ERRORS{'WARNING'}, 0, "failed to retrieve currentimage.txt from $computer_node_name, exit status: $cat_exit_status, output:\n@{$cat_output}");
      return;
   }
   else {
      notify($ERRORS{'DEBUG'}, 0, "retrieved currentimage.txt contents from $computer_node_name:\n" . join("\n", @$cat_output));
   }
   return @{$cat_output};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_ip_assigned_query

  Parameters  : IP address
  Returns     : boolean
  Description : checks if IP address exists in db

=cut

sub is_ip_assigned_query {
	
	my ($IPaddress) = @_;

   if (!defined($IPaddress)) {
      notify($ERRORS{'WARNING'}, 0, "IPaddress  argument was not supplied");
      return;
   }	

   my $select_statement = <<EOF;
SELECT
computer.id AS computer_id,
computer.hostname AS computer_hostname,
computer.stateid AS computer_stateid,
state.name AS state_name
FROM computer, state
WHERE
computer.IPaddress = '$IPaddress' AND
computer.stateid = state.id AND
state.name != 'deleted' AND
computer.vmhostid IS NOT NULL
EOF

   # Call the database select subroutine
   my @selected_rows = database_select($select_statement);

   # Check to make sure 1 row was returned
   if (scalar @selected_rows == 0) {
      notify($ERRORS{'OK'}, 0, "zero rows were returned from database select statement $IPaddress is available");
      return 0;
   }
	elsif (scalar @selected_rows >= 1) {
      notify($ERRORS{'OK'}, 0, scalar @selected_rows . " rows were returned from database select statement: $IPaddress is assigned");
      return 1;
   }

	return 1;	
		
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stopwatch

 Parameters  : $title (optional)
 Returns     : none
 Description : For vcld performance monitoring only. Every time stopwatch is
               called, it prints a message to STDOUT with the current time and
               the time elapsed since the last call.

=cut

sub stopwatch {
	my ($title) = @_;
	
	my ($seconds, $microseconds) = gettimeofday;
	
	if (!$ENV{'start'}) {
		$ENV{'start'} = [$seconds, $microseconds];
	}
	
	if (defined($ENV{'stopwatch_count'})) {
		$ENV{'stopwatch_count'}++;
	}
	else {
		$ENV{'stopwatch_count'} = 'a';
	}
	
	$ENV{'previous'} = $ENV{'current'} || $ENV{'start'};
	
	$ENV{'current'} = [$seconds, $microseconds];
	
	my $message = "[stopwatch] $ENV{'stopwatch_count'}: ";
	$message .= "$title " if defined($title);
	$title = '<none>' if !defined($title);
	
	my $previous_delta = sprintf("%.2f", tv_interval($ENV{'previous'}, $ENV{'current'}));
	my $start_delta = sprintf("%.2f", tv_interval($ENV{'start'}, $ENV{'current'}));
	
	$start_delta = 0 if $start_delta =~ /e/;
	$previous_delta = 0 if $previous_delta =~ /e/;
	
	$message .= "(previous/start: +$previous_delta/+$start_delta)";
	
	print "\n$message\n\n";
	
	my $info = {
		current => $ENV{'current'},
		previous => $ENV{'previous'},
		message => $message,
		start_delta => $start_delta,
		previous_delta => $previous_delta,
		title => "$ENV{'stopwatch_count'}: $title",
	};
	
	if (!$ENV{stopwatch}) {
		$ENV{stopwatch} = [];
	}
	
	push @{$ENV{stopwatch}}, $info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_computer_ids

 Parameters  : $management_node_identifier
 Returns     : hash reference
 Description : Retrieves a list of all computer IDs a particular management node
               controls.

=cut

sub get_management_node_computer_ids {
	my $management_node_identifier = shift;
	if (!$management_node_identifier) {
		notify($ERRORS{'WARNING'}, 0, "management node identifier argument was not supplied");
		return;
	}
	
	my $select_statement = <<EOF;
SELECT DISTINCT
computer.id,
computer.hostname

FROM
managementnode       mn,
resource             mn_resource,
resourcetype         mn_resourcetype,
resourcegroup        mn_resourcegroup,
resourcegroupmembers mn_resourcegroupmembers,
computer,
resource             comp_resource,
resourcegroup        comp_resourcegroup,
resourcegroupmembers comp_resourceourcegroupmembers,
resourcemap

WHERE

mn.id = mn_resource.subid AND
mn_resource.resourcetypeid = mn_resourcetype.id AND
mn_resourcetype.name = 'managementnode' AND

mn_resource.id = mn_resourcegroupmembers.resourceid AND
mn_resourcegroupmembers.resourcegroupid = mn_resourcegroup.id AND

computer.id = comp_resource.subid AND
comp_resource.id = comp_resourceourcegroupmembers.resourceid AND
comp_resourceourcegroupmembers.resourcegroupid = comp_resourcegroup.id AND

resourcemap.resourcegroupid1 = mn_resourcegroup.id AND
resourcemap.resourcegroupid2 = comp_resourcegroup.id AND

computer.deleted = 0
EOF
	
	if ($management_node_identifier =~ /^\d+$/) {
		$select_statement .= "AND mn.id = $management_node_identifier";
	}
	else {
		$select_statement .= "AND mn.hostname = '$management_node_identifier'";
	}
	
	my @selected_rows = database_select($select_statement);
	
	my %computers = map { $_->{id} => $_->{hostname} } @selected_rows;
	my @computer_ids = keys %computers;
	my $computer_count = scalar(@computer_ids);
	#notify($ERRORS{'DEBUG'}, 0, "computers assigned to $management_node_identifier: $computer_count\n" . format_data(\%computers));
	notify($ERRORS{'DEBUG'}, 0, "computers assigned to $management_node_identifier: $computer_count\n" . join(', ', @computer_ids));
	return @computer_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_vmhost_ids

 Parameters  : $management_node_identifier
 Returns     : array
 Description : Returns a list of all VM host IDs controlled by a particular
               management node.

=cut

sub get_management_node_vmhost_info {
	my $management_node_identifier = shift;
	if (!$management_node_identifier) {
		notify($ERRORS{'WARNING'}, 0, "management node identifier argument was not supplied");
		return;
	}
	
	my $select_statement = <<EOF;
SELECT DISTINCT
vmhost.id

FROM
managementnode       mn,
resource             mn_resource,
resourcetype         mn_resourcetype,
resourcegroup        mn_resourcegroup,
resourcegroupmembers mn_resourcegroupmembers,
computer,
vmhost,
resource             comp_resource,
resourcegroup        comp_resourcegroup,
resourcegroupmembers comp_resourceourcegroupmembers,
resourcemap

WHERE

mn.id = mn_resource.subid AND
mn_resource.resourcetypeid = mn_resourcetype.id AND
mn_resourcetype.name = 'managementnode' AND

mn_resource.id = mn_resourcegroupmembers.resourceid AND
mn_resourcegroupmembers.resourcegroupid = mn_resourcegroup.id AND

computer.deleted = 0 AND
computer.type = 'virtualmachine' AND
computer.id = comp_resource.subid AND
comp_resource.id = comp_resourceourcegroupmembers.resourceid AND
comp_resourceourcegroupmembers.resourcegroupid = comp_resourcegroup.id AND

computer.vmhostid = vmhost.id AND

resourcemap.resourcegroupid1 = mn_resourcegroup.id AND
resourcemap.resourcegroupid2 = comp_resourcegroup.id
EOF
	
	if ($management_node_identifier =~ /^\d+$/) {
		$select_statement .= "AND mn.id = $management_node_identifier";
	}
	else {
		$select_statement .= "AND mn.hostname = '$management_node_identifier'";
	}
	
	my @selected_rows = database_select($select_statement);
	
	my @vmhost_ids = map { $_->{id} } @selected_rows;
	
	notify($ERRORS{'DEBUG'}, 0, "vmhost IDs assigned to $management_node_identifier:\n" . join(', ', @vmhost_ids));
	return @vmhost_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_assigned_vm_info

 Parameters  : $vmhost_id
 Returns     : hash reference
 Description : Returns a hash reference containing all of the computer IDs
               assigned to a VM host.

=cut

sub get_vmhost_assigned_vm_info {
	my $vmhost_id = shift;
	if (!$vmhost_id) {
		notify($ERRORS{'WARNING'}, 0, "VM host ID argument was not supplied");
		return;
	}
	
	my $select_statement = <<EOF;
SELECT
computer.id
FROM
computer
WHERE
computer.vmhostid = $vmhost_id
EOF
	
	my @selected_rows = database_select($select_statement);
	
	my $assigned_computer_info = {};
	for my $row (@selected_rows) {
		my $computer_id = $row->{id};
		my $computer_info = get_computer_info($computer_id);
		$assigned_computer_info->{$computer_id} = $computer_info;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved computer info for VMs assigned to VM host $vmhost_id: " . join(', ', sort keys %$assigned_computer_info));
	return $assigned_computer_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sleep_uninterrupted

 Parameters  : $seconds
 Returns     : none
 Description : A normal sleep call may be interrupted by a signal from a child
               process. This occurs whenever a child vcld reservation process
               exits. As a result, the intended sleep duration will be shorter
               than intended. This subroutine loops to make sure the sleep time
               is what is intended.

=cut

sub sleep_uninterrupted {
	my $seconds = shift;
	my $start_time = Time::HiRes::time;
	my $end_time = ($start_time + $seconds);
	
	#notify($ERRORS{'DEBUG'}, 0, "sleeping for $seconds seconds, end time: $end_time");
	my $loop_count = 0;
	while (1) {
		$loop_count++;
		my $current_time = Time::HiRes::time;
		my $sleep_seconds = ($end_time - $current_time);
		last if ($sleep_seconds <= 0);
		if ($loop_count > 1) {
			#notify($ERRORS{'DEBUG'}, 0, "loop $loop_count: sleep was interrupted\n" .
			#	"start time    : $start_time\n" .
			#	"current time  : $current_time\n" .
			#	"end time      : $end_time\n" .
			#	"sleep seconds : $sleep_seconds seconds"
			#);
		}
		Time::HiRes::sleep($sleep_seconds);
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
