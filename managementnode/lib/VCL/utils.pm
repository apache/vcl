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

###############################################################################
package VCL::utils;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use Mail::Mailer;
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
use Term::ANSIColor 2.00 qw(:constants :pushpop color colored);
use Text::Wrap;
use English;
use List::Util qw(min max);
use HTTP::Headers;
use RPC::XML::Client;
use Scalar::Util 'blessed';
use Storable qw(dclone);
use Data::Dumper;
use Cwd;
use Sys::Hostname;
use XML::Simple;
use Time::HiRes qw(gettimeofday tv_interval);
use Crypt::OpenSSL::RSA;
use B qw(svref_2object);
use Socket;
use Net::Netmask;

BEGIN {
	$ENV{PERL_RL} = 'Perl';
};

use Term::ReadLine;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
	_pingnode
	add_imageid_to_newimages
	add_reservation_account
	call_check_crypt_secrets
	character_to_ascii_value
	check_blockrequest_time
	check_endtimenotice_interval
	check_messages_need_validating
	check_time
	clear_next_image_id
	clearfromblockrequest
	convert_to_datetime
	convert_to_epoch_seconds
	create_management_node_directory
	database_execute
	database_select
	delete_computerloadlog_reservation
	delete_management_node_cryptsecret
	delete_request
	delete_reservation_account
	delete_variable
	delete_vcld_semaphore
	determine_remote_connection_target
	escape_file_path
	format_array_reference
	format_data
	format_hash_keys
	format_number
	get_all_reservation_ids
	get_affiliation_info
	get_array_intersection
	get_block_request_image_info
	get_caller_trace
	get_calling_subroutine
	get_changelog_info
	get_changelog_remote_ip_address_info
	get_database_names
	get_database_table_columns
	get_database_table_names
	get_code_ref_package_name
	get_code_ref_subroutine_name
	get_collapsed_hash_reference
	get_computer_current_private_ip_address
	get_computer_current_state_name
	get_computer_grp_members
	get_computer_ids
	get_computer_info
	get_computer_nathost_info
	get_computer_private_ip_address_info
	get_computers_controlled_by_mn
	get_connectlog_info
	get_connectlog_remote_ip_address_info
	get_copy_speed_info_string
	get_current_file_name
	get_current_image_contents_no_data_structure
	get_current_package_name
	get_current_reservation_lastcheck
	get_current_subroutine_name
	get_file_size_info_string
	get_group_name
	get_image_active_directory_domain_info
	get_image_info
	get_imagemeta_info
	get_imagerevision_cleanup_info
	get_imagerevision_info
	get_imagerevision_loaded_info
	get_imagerevision_names
	get_imagerevision_names_recently_reserved
	get_imagerevision_reservation_info
	get_local_user_info
	get_managable_resource_groups
	get_management_node_ad_domain_credentials
	get_management_node_blockrequests
	get_management_node_computer_ids
	get_management_node_id
	get_management_node_info
	get_management_node_cryptkey_pubkey
	get_management_node_cryptsecret_info
	get_management_node_cryptsecret_value
	get_management_node_requests
	get_management_node_vmhost_ids
	get_management_node_vmhost_info
	get_message_variable_info
	get_module_info
	get_nathost_assigned_public_ports
	get_natport_ranges
	get_next_image_default
	get_os_info
	get_production_imagerevision_info
	get_provisioning_osinstalltype_info
	get_provisioning_table_info
	get_random_mac_address
	get_request_by_computerid
	get_request_current_state_name
	get_request_end
	get_request_info
	get_request_log_info
	get_reservation_accounts
	get_reservation_computerloadlog_entries
	get_reservation_computerloadlog_time
	get_reservation_connect_method_info
	get_reservation_management_node_hostname
	get_reservation_vcld_process_name_regex
	get_request_loadstate_names
	get_resource_groups
	get_user_group_member_info
	get_user_info
	get_variable
	get_vcld_semaphore_info
	get_vmhost_assigned_vm_info
	get_vmhost_assigned_vm_provisioning_info
	get_vmhost_info
	getnewdbh
	getpw
	hash_to_xml_string
	help
	hostname_to_ip_address
	insert_nathost
	insert_natport
	insert_reload_request
	insert_request
	insert_vcld_semaphore
	insertloadlog
	ip_address_to_hostname
	ip_address_to_network_address
	is_inblockrequest
	is_ip_assigned_query
	is_management_node_process_running
	is_public_ip_address
	is_request_deleted
	is_valid_dns_host_name
	is_valid_ip_address
	is_variable_set
	kill_child_processes
	mail
	makedatestring
	nmap_port
	normalize_file_path
	notify
	notify_via_im
	notify_via_oascript
	parent_directory_path
	pfd
	populate_reservation_natport
	preplogfile
	prune_array_reference
	prune_hash_child_references
	prune_hash_reference
	read_file_to_array
	remove_array_duplicates
	rename_vcld_process
	reservation_being_processed
	round
	run_command
	run_scp_command
	run_ssh_command
	set_logfile_path
	set_management_node_cryptkey_pubkey
	set_managementnode_state
	set_reservation_lastcheck
	set_variable
	setnextimage
	setup_confirm
	setup_get_array_choice
	setup_get_hash_choice
	setup_get_hash_multiple_choice
	setup_get_input_file_path
	setup_get_input_string
	setup_get_menu_choice
	setup_print_break
	setup_print_error
	setup_print_ok
	setup_print_warning
	setup_print_wrap
	set_production_imagerevision
	sleep_uninterrupted
	sort_by_file_name
	stopwatch
	string_to_ascii
	switch_vmhost_id
	update_blockrequest_processing
	update_changelog_request_user_remote_ip
	update_changelog_reservation_remote_ip
	update_changelog_reservation_user_remote_ip
	update_computer_imagename
	update_computer_lastcheck
	update_computer_private_ip_address
	update_computer_procnumber
	update_computer_procspeed
	update_computer_public_ip_address
	update_computer_ram
	update_computer_state
	update_computer_vmhost_id
	update_connectlog
	update_currentimage
	update_image_name
	update_image_type
	update_lastcheckin
	update_log_ending
	update_log_loaded_time
	update_preload_flag
	update_request_checkuser
	update_request_state
	update_reservation_lastcheck
	update_reservation_natlog
	update_reservation_password
	update_sublog_ipaddress
	wrap_string
	xml_string_to_hash
	xmlrpc_call
	yaml_deserialize
	yaml_serialize

	$CONF_FILE_PATH
	$DAEMON_MODE
	$DATABASE
	$DEFAULTHELPEMAIL
	$EXECUTE_NEW
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
our $EXECUTE_NEW;


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
		if ($BIN_PATH && $BIN_PATH =~ /dev/) {
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
		'exn!' => \$EXECUTE_NEW,
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
			#print STDERR "WARNING: ignoring line $line_number in $CONF_FILE_PATH: $line\n";
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
			#print STDERR "WARNING: unsupported parameter found on line $line_number in $CONF_FILE_PATH: " . string_to_ascii($parameter) . "\n";
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
	elsif (!defined($EXECUTE_NEW)) {
		$EXECUTE_NEW = 0;
	}
	$ENV{execute_new} = $EXECUTE_NEW if $EXECUTE_NEW;
	
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

#//////////////////////////////////////////////////////////////////////////////

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
-conf=<path> | Specify vcld configuration file (default: /etc/vcl/vcld.conf)
-log=<path>  | Specify vcld log file (default: /var/log/vcld.log)
-setup       | Run management node setup
-verbose     | Run vcld in verbose mode
-nodaemon    | Run vcld in non-daemon mode
-exn         | Use persistent SSH connections (experimental)
-help        | Display this help information
============================================================================
END

	print $message;
	exit 1;
} ## end sub help

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 notify

 Parameters  : $error, $LOG, $string, $data
 Returns     : true
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
	#$string =~ s/\s*\n\s*/\n/gs;
	
	# Remove blank lines
	$string =~ s/\n{2,}/\n/gs;
	
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
		my $caller_trace = get_caller_trace();
		$log_message = "\n---- WARNING ---- \n$log_message\n$caller_trace\n\n";
	}

	# CRITICAL
	elsif ($error == 2) {
		my $caller_trace = get_caller_trace(15);
		$log_message = "\n---- CRITICAL ---- \n$log_message\n$caller_trace\n\n";
		if ($sysadmin) {
			
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
				
				my $vmhost_hostname = $ENV{data}->get_vmhost_short_name(0);
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
		
		# ARK - for testing competing reservations
		#if ($ENV{reservation_id}) {
		#	if ($ENV{reservation_id} == 3115) {
		#		print colored($log_message, "YELLOW");
		#	}
		#	elsif ($ENV{reservation_id} == 3116) {
		#		print colored($log_message, "CYAN");
		#	}
		#	else {
		#		print colored($log_message, "MAGENTA");
		#	}
		#	print "\n";
		#	return 1;
		#}
		print STDOUT "$log_message\n";
	}
} ## end sub notify

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2  convert_to_datetime

 Parameters  : time in epoch format
 Returns     : date in datetime format
 Description : accepts time in epoch format (10 digit) and returns time in
               datetime format

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

#//////////////////////////////////////////////////////////////////////////////

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


#//////////////////////////////////////////////////////////////////////////////

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
	my $total_days = int($epoch_until_end/86400);
	$diff_seconds -= $diff_days * 86400;
	
	my $diff_hours = int($diff_seconds/3600);
	$diff_seconds -= $diff_hours * 3600;
	
	my $diff_minutes = int($diff_seconds/60);
	$diff_seconds -= $diff_minutes * 60;
	
	notify($ERRORS{'OK'}, 0, "End Time is in: $diff_weeks week\(s\) $diff_days day\(s\) $diff_hours hour\(s\) $diff_minutes min\(s\) and $diff_seconds sec\(s\)");
	
	#flag on: 2 & 1 week; 2,1 day, 1 hour, 30,15,10,5 minutes
	#ignore over 2weeks away
	if ($diff_weeks >= 2) {
		return 0;
	}
	#2 week: between 14 days and a 14 day -6 minutes window
	elsif ($total_days >= 13 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "2 weeks";
	}
	#Ignore: between 7 days and 14 day - 6 minute window
	elsif ($total_days >=7) {
		return 0;
	}
	# 1 week notice: between 7 days and a 7 day -6 minute window
	elsif ($total_days >= 6 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "1 week";
	}
	# Ignore: between 2 days and 7 day - 15 minute window
	elsif ($total_days >= 2) {
		return 0;
	}
	# 2 day notice: between 2 days and a 2 day -6 minute window
	elsif ($total_days >= 1 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "2 days";
	}
	# 1 day notice: between 1 days and a 1 day -6 minute window
	elsif ($total_days >= 0 && $diff_hours >= 23 && $diff_minutes >= 55) {
		return "24 hours";
	}
	
	return 0;
} ## end sub check_endtimenotice_interval

#//////////////////////////////////////////////////////////////////////////////

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
	
	# End time it is less than 1 minute
	if ($end_delta_minutes < 0) {
		# Block request end time is reached
		notify($ERRORS{'OK'}, 0, "block request end time has been reached ($end_delta_minutes minutes from now), returning 'end'");
		return "end";
	}

	# if 1min to 6 hrs in advance: start assigning resources
	if ($start_delta_minutes <= (6 * 60)) {
		# Block request within start window
		notify($ERRORS{'OK'}, 0, "block request start time is within start window ($start_delta_minutes minutes from now), returning 'start'");
		return "start";
	}


	#notify($ERRORS{'DEBUG'}, 0, "block request does not need to be processed now, returning 0");
	return 0;

} ## end sub check_blockrequest_time

#//////////////////////////////////////////////////////////////////////////////

=head2 check_time

 Parameters  : $request_start, $request_end, $reservation_lastcheck, $request_state_name, $request_laststate_name
 Returns     : start, preload, end, poll, old, remove, or 0
 Description : based on the input return a value used by vcld

=cut

sub check_time {
	my ($request_start, $request_end, $reservation_lastcheck, $request_state_name, $request_laststate_name, $serverrequest, $reservation_cnt, $changelog_timestamp) = @_;
	
	# Check the arguments
	if (!defined($request_state_name)) {
		notify($ERRORS{'WARNING'}, 0, "\$request_state_name argument is not defined");
		return 0;
	}
	if (!defined($request_laststate_name)) {
		notify($ERRORS{'WARNING'}, 0, "\$request_laststate_name argument is not defined");
		return 0;
	}
	
	# Get the current time epoch seconds
	my $current_time_epoch_seconds = time();
	
	# If lastcheck isn't set, set it to now
	if (!defined($reservation_lastcheck) || !$reservation_lastcheck) {
		$reservation_lastcheck = makedatestring($current_time_epoch_seconds);
	}
	
	if (!defined($changelog_timestamp) || !$changelog_timestamp) {
		$changelog_timestamp = makedatestring($current_time_epoch_seconds);
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
	my $changelog_epoch_seconds   = convert_to_epoch_seconds($changelog_timestamp);

	# Calculate time differences from now in seconds
	# These will be positive if in the future, negative if in the past
	my $lastcheck_diff_seconds = $lastcheck_epoch_seconds - $current_time_epoch_seconds;
	my $start_diff_seconds     = $start_time_epoch_seconds - $current_time_epoch_seconds;
	my $end_diff_seconds       = $end_time_epoch_seconds - $current_time_epoch_seconds;
	my $changelog_diff_seconds = $changelog_epoch_seconds - $current_time_epoch_seconds;
	
	# Calculate the time differences from now in minutes
	# These will be positive if in the future, negative if in the past
	my $lastcheck_diff_minutes = round($lastcheck_diff_seconds / 60);
	my $start_diff_minutes     = round($start_diff_seconds / 60);
	my $end_diff_minutes       = round($end_diff_seconds / 60);
	
	my $preload_window_minutes_prior_high = 35;
	my $preload_window_minutes_prior_low = 25;

	# Print the time differences
	#notify($ERRORS{'OK'}, 0, "reservation lastcheck difference: $lastcheck_diff_minutes minutes ($lastcheck_diff_seconds seconds)");
	#notify($ERRORS{'OK'}, 0, "request start time difference:    $start_diff_minutes minutes");
	#notify($ERRORS{'OK'}, 0, "request end time difference:      $end_diff_minutes minutes");
	#notify($ERRORS{'OK'}, 0, "changelog timestamp difference:   $changelog_diff_seconds seconds");

	# Check the state, and then figure out the return code
	if ($request_state_name =~ /(new|imageprep|reload|tovmhostinuse|test)/) {
		if ($start_diff_minutes > 0) {
			# Start time is either now or in future, $start_diff_minutes is positive
			my $preload_start_minutes = ($start_diff_minutes - $preload_window_minutes_prior_high);
			if ($start_diff_minutes > $preload_window_minutes_prior_high) {
				if (($preload_start_minutes <= 5 || $start_diff_minutes % 5 == 0) && ($start_diff_seconds % 60) >= 50) {
					notify($ERRORS{'DEBUG'}, 0, "$request_state_name request start time is $start_diff_minutes minutes from now, preload process will begin in $preload_start_minutes minutes ($preload_window_minutes_prior_high minutes prior to request start time), returning 0");
				}
				return "0";
			}
			elsif ($start_diff_minutes >= $preload_window_minutes_prior_low && $start_diff_minutes <= $preload_window_minutes_prior_high) {
				notify($ERRORS{'DEBUG'}, 0, "$request_state_name request start time is $start_diff_minutes minutes from now, returning 'preload'");
				return "preload";
			}
			else {
				if (($start_diff_minutes <= 5 || $start_diff_minutes % 5 == 0) && ($start_diff_seconds % 60) >= 50) {
					notify($ERRORS{'DEBUG'}, 0, "$request_state_name request will be processed in $start_diff_minutes minutes, returning 0");
				}
				return "0";
			}
		} ## end if ($start_diff_minutes > 0)
		else {
			# Start time is in past, $start_diff_minutes is negative
			
			#Start time is fairly old - something is off
			#send warning to log for tracking purposes
			if ($start_diff_minutes < -17) {
				notify($ERRORS{'WARNING'}, 0, "reservation start time was in the past 17 minutes ($start_diff_minutes), returning 'start'");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "reservation start time was $start_diff_minutes minutes ago, returning 'start'");
			}
			
			return "start";
			
		} ## end else [ if ($start_diff_minutes > 0)
	}
	elsif ($request_state_name =~ /(tomaintenance)/) {
		# Only display this once per hour at most, tomaintenance can be far into the future
		if ($start_diff_minutes > 0) {
			if ($start_diff_minutes % 60 == 0 && ($start_diff_seconds % 60) >= 50) {
				notify($ERRORS{'DEBUG'}, 0, "$request_state_name request will be processed in $start_diff_minutes minutes, returning 0");
			}
			return "0";
		}
		else {
			# Start time is in past, $start_diff_minutes is negative
			notify($ERRORS{'DEBUG'}, 0, "$request_state_name request will be processed now, returning 'start'");
			return "start";
		}
	}
	elsif ($request_state_name =~ /(inuse)/) {
		if ($end_diff_minutes <= 10) {
			notify($ERRORS{'DEBUG'}, 0, "reservation will end in 10 minutes or less ($end_diff_minutes), returning 'end'");
			return "end";
		}
		elsif ($lastcheck_epoch_seconds < $changelog_epoch_seconds && $changelog_diff_seconds < 0) {
			notify($ERRORS{'DEBUG'}, 0, "reservation lastcheck $reservation_lastcheck is older than most recent changelog timestamp $changelog_timestamp, returning 'poll'");
			return "poll";
		}
		else {
			# End time is more than 10 minutes in the future
			if ($serverrequest) {	
				my $server_inuse_check_time = ($ENV{management_node_info}->{SERVER_INUSE_CHECK} * -1);
				if ($lastcheck_diff_minutes <= $server_inuse_check_time) {
					return "poll";
				}
				else {
					return 0;
				}
			}
			elsif ($reservation_cnt > 1) {
				my $cluster_inuse_check_time = ($ENV{management_node_info}->{CLUSTER_INUSE_CHECK} * -1);; 
				if ($lastcheck_diff_minutes <= $cluster_inuse_check_time) {
					return "poll";
				}
				else {
					return 0;
				}
			}
			else {
				#notify($ERRORS{'DEBUG'}, 0, "reservation will end in more than 10 minutes ($end_diff_minutes)");
				my $general_inuse_check_time = ($ENV{management_node_info}->{GENERAL_INUSE_CHECK} * -1);
				if ($lastcheck_diff_minutes <= $general_inuse_check_time) {
					notify($ERRORS{'DEBUG'}, 0, "reservation was last checked more than $general_inuse_check_time minutes ago ($lastcheck_diff_minutes), returning 'poll'");
					return "poll";
				}
				else {
					#notify($ERRORS{'DEBUG'}, 0, "reservation has been checked within the past $general_inuse_check_time minutes ($lastcheck_diff_minutes), returning 0");
					return 0;
				}
			}
		} ## end else [ if ($end_diff_minutes <= 10)
	}
	elsif ($request_state_name =~ /(complete|failed)/) {
		# Don't need to keep requests in database if laststate was...
		if ($request_laststate_name =~ /image|deleted|makeproduction|reload|tomaintenance|tovmhostinuse/) {
			notify($ERRORS{'DEBUG'}, 0, "request laststate is '$request_laststate_name', returning 'remove'");
			return "remove";
		}
		elsif ($end_diff_minutes < 0) {
			notify($ERRORS{'DEBUG'}, 0, "reservation end time was in the past ($end_diff_minutes), returning 'remove'");
			return "remove";
		}
		else {
			# End time is now or in the future
			#notify($ERRORS{'DEBUG'}, 0, "reservation end time is either right now or in the future ($end_diff_minutes), returning 0");
			return "0";
		}
	}    # Close if state is complete or failed
	# Just return start for all other states
	else {
		notify($ERRORS{'DEBUG'}, 0, "request state is '$request_state_name', returning 'start'");
		return "start";
	}

} ## end sub check_time

#//////////////////////////////////////////////////////////////////////////////

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
	my $mailer_options = '';
	if (defined($RETURNPATH)) {
		$mailer_options = "-f $RETURNPATH";
	}
	
	eval {
		$mailer = Mail::Mailer->new("sendmail", $mailer_options);
	};
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to send mail, error:\n$EVAL_ERROR");
		return;
	}
	
	my $shared_mail_box = '';
	my $management_node_info = get_management_node_info();
	if ($management_node_info) {
		$shared_mail_box = $management_node_info->{SHARED_EMAIL_BOX} if $management_node_info->{SHARED_EMAIL_BOX};
	}

	if ($shared_mail_box) {
		my $bcc = $shared_mail_box;
		if ($mailer->open({From => $from, To => $to, Bcc => $bcc, Subject => $subject})) {
			print $mailer $mailstring;
			$mailer->close();
			notify($ERRORS{'OK'}, 0, "SUCCESS -- Sending mail To: $to, $subject");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "NOTICE --  Problem sending mail to: $to From");
		}
	} ## end if ($shared_mail_box)
	else {
		if ($mailer->open({From => $from, To => $to, Subject => $subject,}))
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
		notify($ERRORS{'WARNING'}, 0, "unable to update request state, request id argument was not supplied");
		return;
	}
	if (!defined($state_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update request $request_id state, state name argument not supplied");
		return;
	}
	if (!defined($laststate_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update request $request_id state to $state_name, last state name argument not supplied");
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
AND currentstate.name != 'maintenance'
EOF
	
	if (!$force) {
		if ($state_name eq 'pending') {
			# Avoid: deleted/inuse --> pending/inuse
			$update_statement .= "AND laststate.name = currentstate.name\n";
		}
		elsif ($state_name !~ /(complete|failed|maintenance)/) {
			# New state is not pending
			# Avoid: pending/image --> inuse/inuse
			$update_statement .= "AND currentstate.name = 'pending'\n";
			$update_statement .= "AND currentlaststate.name = '$laststate_name'\n";
		}
	}
	
	# Call the database execute subroutine
	my $result = database_execute($update_statement);
	if (defined($result)) {
		my $rows_updated = (sprintf '%d', $result);
		if ($rows_updated) {
			notify($ERRORS{'OK'}, $LOGFILE, "request $request_id state updated to $state_name/$laststate_name");
			return 1;
		}
		else {
			my ($current_state_name, $current_laststate_name) = get_request_current_state_name($request_id);
			if ($state_name eq $current_state_name && $laststate_name eq $current_laststate_name) {
				notify($ERRORS{'OK'}, $LOGFILE, "request $request_id state already set to $current_state_name/$current_laststate_name");
				return 1;
			}
			elsif ($current_state_name eq 'deleted' || $current_laststate_name eq 'deleted') {
				notify($ERRORS{'OK'}, $LOGFILE, "request $request_id has been deleted, state not set to $state_name/$laststate_name, current state: $current_state_name/$current_laststate_name");
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, $LOGFILE, "unable to update request $request_id state to $state_name/$laststate_name, current state: $current_state_name/$current_laststate_name, SQL statement:\n$update_statement");
				return;
			}
		}
		return $rows_updated;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update request $request_id state to $state_name/$laststate_name");
		return;
	}
} ## end sub update_request_state

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

	unless (defined($datestring)) {
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 update_reservation_password

 Parameters  : $reservation_id, $password
 Returns     : 1 success 0 failure
 Description : updates password field for reservation id

=cut

sub update_reservation_password {
	my ($reservation_id, $password) = @_;
	
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	if (!$password) {
		notify($ERRORS{'WARNING'}, 0, "password argument was not supplied");
		return;
	}
	
	my $update_statement = "UPDATE reservation SET pw = \'$password\'	WHERE id = $reservation_id";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'OK'}, $LOGFILE, "password updated for reservation $reservation_id: $password");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update password for reservation $reservation_id");
		return 0;
	}
} ## end sub update_reservation_password

#//////////////////////////////////////////////////////////////////////////////

=head2 is_request_deleted

 Parameters  : $request_id
 Returns     : boolean
 Description : Checks if the request state or laststate is deleted.

=cut

sub is_request_deleted {
	my ($request_id) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not specified");
		return;
	}
	
	my ($state_name, $laststate_name) = get_request_current_state_name($request_id, 1);
	if (!$state_name || !$laststate_name) {
		notify($ERRORS{'OK'}, 0, "request $request_id state data could not be retrieved, assuming request is deleted and was removed from the database, returning true");
		return 1;
	}
	
	if ($state_name =~ /(deleted)/ || $laststate_name =~ /(deleted)/) {
		notify($ERRORS{'DEBUG'}, 0, "request $request_id state: $state_name/$laststate_name, returning true");
		return 1;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "request $request_id state: $state_name/$laststate_name, returning false");
		return 0;
	}
} ## end sub is_request_deleted

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_accounts

 Parameters  : $reservation_id
 Returns     : hash reference
 Description : Used for server loads, provides list of users for group access

=cut

sub get_reservation_accounts {
	my ($reservation_id) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return 0;
	}
	
	my $select_statement = <<EOF;
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
user.id = reservationaccounts.userid
AND affiliation.id = user.affiliationid
AND reservationaccounts.reservationid = $reservation_id
EOF
	
	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	
	my $reservation_accounts = {};
	for my $row (@selected_rows) {
		my $user_id = $row->{reservationaccounts_userid};
		$reservation_accounts->{$user_id}{"userid"} = $user_id;
		$reservation_accounts->{$user_id}{"password"} = $row->{reservationaccounts_password};
		$reservation_accounts->{$user_id}{"affiliation"} = $row->{affiliation_name};
		$reservation_accounts->{$user_id}{"username"} = $row->{user_name};
	}
	
	return $reservation_accounts;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 add_reservation_account

 Parameters  : $reservation_id, $userid, $password
 Returns     : boolean
 Description : Adds an entry to the reservationaccounts table.

=cut

sub add_reservation_account {
	my ($reservation_id, $user_id, $password) = @_;
	
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	elsif (!$user_id) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not specified");
		return;
	}
	
	my $password_string;
	if ($password) {
		$password_string = "'$password'";
	}
	else {
		$password_string = 'NULL';
	}
	
	my $statement = <<EOF;
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
	$password_string
)
ON DUPLICATE KEY UPDATE password = $password_string
EOF
	
	if (!database_execute($statement)) {
		notify($ERRORS{'OK'}, 0, "failed to add user $user_id to reservationaccounts table");
		return;
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_reservation_account

 Parameters  : $reservation_id, $userid
 Returns     : boolean
 Description : Deletes an entry from the reservationaccounts table.

=cut

sub delete_reservation_account {
	my ($reservation_id, $user_id) = @_;
	
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	elsif (!$user_id) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not specified");
		return;
	}
	
	my $statement = <<EOF;
DELETE FROM
reservationaccounts
WHERE
reservationid = '$reservation_id'
AND userid = '$user_id' 
EOF

	if (!database_execute($statement)) {
		notify($ERRORS{'OK'}, 0, "failed to delete user $user_id from reservationaccounts table");
		return;
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_next_image_default

 Parameters  : $computerid
 Returns     : imageid,imagerevisionid,imagename
 Description : Looks for any upcoming reservations for supplied computerid, if
               starttime is within 50 minutes return that imageid. Else fetch
               and return next image

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 nmap_port

 Parameters  : $hostname, $port
 Returns     : boolean
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
	
	# Determine which string to use as the connection target
	my $remote_connection_target = determine_remote_connection_target($hostname);
	my $hostname_string = $remote_connection_target;
	$hostname_string .= " ($hostname)" if ($hostname ne $remote_connection_target);

	my $command = "/usr/bin/nmap $remote_connection_target -P0 -p $port -T Aggressive -n";

	my ($exit_status, $output) = run_command($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run nmap command on management node: '$command'");
		return;
	}
	elsif (grep(/(open|filtered)/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "port $port is open on $hostname_string");
		return 1;
	}
	elsif (grep(/(nmap:|warning)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running nmap command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "port $port is closed on $hostname_string");
		return 0;
	}
} ## end sub nmap_port

#//////////////////////////////////////////////////////////////////////////////

=head2 _pingnode

 Parameters  : $node
 Returns     : boolean
 Description : Uses Net::Ping to check if a node is responding to ICMP echo
               ping.

=cut

sub _pingnode {
	my ($node) = @_;
	if (!$node) {
		notify($ERRORS{'WARNING'}, 0, "node argument was not supplied");
		return;
	}
	
	my $node_string = $node;
	my $remote_connection_target;
	if (is_valid_ip_address($node, 0)) {
		$remote_connection_target = $node;
	}
	else {
		$remote_connection_target = determine_remote_connection_target($node);
		if ($remote_connection_target) {
			$node_string .= " ($remote_connection_target)";
			$node = $remote_connection_target;
		}
	}
	
	my $p = Net::Ping->new("icmp");
	my $result = $p->ping($remote_connection_target, 1);
	$p->close();

	if ($result) {
		#notify($ERRORS{'DEBUG'}, 0, "$node_string is responding to ping");
		return 1;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "$node_string is NOT responding to ping");
		return 0;
	}
} ## end sub _pingnode

#//////////////////////////////////////////////////////////////////////////////

=head2 getnewdbh

 Parameters  : none
 Returns     : 0 failed or database handle
 Description : gets a databasehandle

=cut

sub getnewdbh {
	#my $caller_trace = get_caller_trace(7, 1);
	#notify($ERRORS{'DEBUG'}, 0, "called from: $caller_trace");

	my ($database) = @_;
	$database = $DATABASE if !defined($database);

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 getpw

 Parameters  : $password_length (optional), $include_special_characters (optional)
 Returns     : string 
 Description : Generates a random password.

=cut

sub getpw {
	my ($password_length, $include_special_characters) = @_;
	
	if (!$password_length) {
		$password_length = $ENV{management_node_info}{USER_PASSWORD_LENGTH} || 8;
	}
	if (!defined($include_special_characters)) {
		$include_special_characters = $ENV{management_node_info}{INCLUDE_SPECIAL_CHARS};
	}
	
	#Skip certain confusing chars like: iI1lL,0Oo Zz2
	my @character_set = (
		'A' .. 'H',
		'J' .. 'N',
		'P' .. 'Y',
		'a' .. 'h',
		'j' .. 'n',
		'p' .. 'y',
		'3' .. '9',
	);
	
	if ($include_special_characters) {
		my @special_characters = (
			'-',
			'_',
			'!',
			'%',
			'#',
			'$',
			'@',
			'+',
			'=',
			'{',
			'}',
			'?',
		);
		push @character_set, @special_characters;
	}
	my $character_set_size = (scalar(@character_set));
	
	my $password;
	srand;
	for (1 .. $password_length) {
		my $random_index = int(rand($character_set_size));
		$password .= $character_set[$random_index];
	}

	return $password;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2  notifyviaIM

 Parameters  : IM type, IM user ID, message string
 Returns     : 0 or 1
 Description : if Jabber enabled - send IM to user
               currently only supports jabber

=cut

sub notify_via_im {
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
} ## end sub notify_via_im

#//////////////////////////////////////////////////////////////////////////////

=head2 insertloadlog

 Parameters  : $reservation_id, $computer_id, $loadstatename, $additional_info
 Returns     : boolean
 Description : Inserts an entry into the computerloadlog table.

=cut

sub insertloadlog {
	my ($reservation_id, $computer_id, $loadstatename, $additional_info) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	elsif (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID argument was not supplied");
		return;
	}
	elsif (!defined($loadstatename)) {
		notify($ERRORS{'WARNING'}, 0, "computerloadstate name argument was not supplied");
		return;
	}
	$additional_info = 'no additional info' unless defined($additional_info);

	# Escape any special characters in additional info
	$additional_info = quotemeta $additional_info;

	# Assemble the SQL statement
	my $insert_loadlog_statement = <<EOF;
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
	'$reservation_id',
	'$computer_id',
	(SELECT id FROM computerloadstate WHERE loadstatename = '$loadstatename'),
	NOW(),
	'$additional_info'
)
EOF

	# Execute the insert statement, the return value should be the id of the computerloadlog row that was inserted
	if (database_execute($insert_loadlog_statement)) {
		notify($ERRORS{'OK'}, 0, "inserted '$loadstatename' computerloadlog entry");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert '$loadstatename' computerloadlog entry");
		return;
	}
} ## end sub insertloadlog

#//////////////////////////////////////////////////////////////////////////////

=head2 database_select

 Parameters  : SQL select statement
 Returns     : array containing hash references to rows returned
 Description : gets information from the database

=cut

sub database_select {
	my ($select_statement, $database) = @_;
	
	my $calling_sub = (caller(1))[3] || 'undefined';
	
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
	
	$database = $DATABASE unless $database;
	
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
		(my $select_statement_condensed = $select_statement) =~ s/[\n\s]+/ /g;
		notify($ERRORS{'WARNING'}, 0, "failed to execute statement on $database database:\n$select_statement\n" .
			"---\n" .
			"copy/paste select statement:\n$select_statement_condensed\n" .
			"---\n" .
			"error: " . $dbh->errstr()
		);
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

#//////////////////////////////////////////////////////////////////////////////

=head2 database_execute

 Parameters  : $sql_statement, $database (optional)
 Returns     : boolean
 Description : Executes an SQL statement. If $sql_statement is an INSERT
               statement, the ID of the row inserted is returned.

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
		my $error_string = $dbh->errstr() || '<unknown error>';
		notify($ERRORS{'WARNING'}, 0, "could not prepare SQL statement, $sql_statement, $error_string");
		$dbh->disconnect if !defined $ENV{dbh};
		return;
	}
	
	# Execute the statement handle
	my $result = $statement_handle->execute();
	if (!defined($result)) {
		my $error_string = $dbh->errstr() || '<unknown error>';
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		
		if (wantarray) {
			return (0, $error_string);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not execute SQL statement: $sql_statement\n$error_string");
			return;
		}
	}
	
	#my $sql_warning_count = $statement_handle->{'mysql_warning_count'};
	#if ($sql_warning_count) {
	#	my $warnings = $dbh->selectall_arrayref('SHOW WARNINGS');
	#	notify($ERRORS{'WARNING'}, 0, "warning generated from SQL statement:\n$sql_statement\nwarnings:\n" . format_data($warnings));
	#}
	
	# Get the id of the last inserted record if this is an INSERT statement
	if ($sql_statement =~ /^\s*insert/i) {
		my $sql_insertid = $statement_handle->{'mysql_insertid'};
		my $sql_warning_count = $statement_handle->{'mysql_warning_count'};
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		if ($sql_insertid) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 database_update

 Parameters  : $update_statement, $database (optional)
 Returns     : boolean
 Description : Executes an SQL UPDATE statement. Returns the number of rows
               updated. 0 is returned if the statement was successfully executed
               but no rows were updated. Undefined is returned if the statement
               failed to execute.

=cut

sub database_update {
	my ($update_statement, $database) = @_;
	if (!$update_statement) {
		notify($ERRORS{'WARNING'}, 0, "SQL UPDATE statement argument not supplied");
		return;
	}
	elsif ($update_statement !~ /^\s*UPDATE\s/i) {
		notify($ERRORS{'WARNING'}, 0, "invalid SQL UPDATE statement argument, it does not begin with 'UPDATE':\n$update_statement");
		return;
	}
	
	
	my $dbh = getnewdbh($database);
	if (!$dbh) {
		sleep_uninterrupted(3);
		$dbh = getnewdbh($database);
		if (!$dbh) {
			notify($ERRORS{'WARNING'}, 0, "unable to obtain database handle, " . DBI::errstr());
			return;
		}
	}
	
	# Prepare the statement handle
	my $statement_handle = $dbh->prepare($update_statement);
	
	# Check the statement handle
	if (!$statement_handle) {
		my $error_string = $dbh->errstr() || '<unknown error>';
		notify($ERRORS{'WARNING'}, 0, "failed to prepare SQL UPDATE statement, $update_statement, $error_string");
		$dbh->disconnect if !defined $ENV{dbh};
		return;
	}
	
	# Execute the statement handle
	my $result = $statement_handle->execute();
	
	if (!defined($result)) {
		my $error_string = $dbh->errstr() || '<unknown error>';
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		notify($ERRORS{'WARNING'}, 0, "failed to execute SQL UPDATE statement: $update_statement\nerror:\n$error_string");
		return;
	}
	
	my $updated_row_count = $statement_handle->rows;
	$statement_handle->finish;
	$dbh->disconnect if !defined $ENV{dbh};
	
	$update_statement =~ s/[\n\s]+/ /g;
	notify($ERRORS{'DEBUG'}, 0, "returning number of rows affected by UPDATE statement: $updated_row_count\n$update_statement");
	return $updated_row_count;
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_request_info

 Parameters  : $request_id, $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves all request/reservation information.

=cut


sub get_request_info {
	my ($request_id, $no_cache) = @_;
	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not specified");
		return;
	}
	
	# Don't use cached info by default
	if (!$no_cache) {
		$no_cache = 1;
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
	my $request_state_name;
	
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
		
		$request_state_name = $request_info->{state}{name};
		
		# Store duration in epoch seconds format
		my $request_start_epoch = convert_to_epoch_seconds($request_info->{start});
		my $request_end_epoch = convert_to_epoch_seconds($request_info->{end});
		$request_info->{DURATION} = ($request_end_epoch - $request_start_epoch);
		
		# Add the image info to the hash
		my $image_id = $request_info->{reservation}{$reservation_id}{imageid};
		my $image_info = get_image_info($image_id, $no_cache);
		$request_info->{reservation}{$reservation_id}{image} = $image_info;
		
		# Add the imagerevision info to the hash
		my $imagerevision_id = $request_info->{reservation}{$reservation_id}{imagerevisionid};
		my $imagerevision_info = get_imagerevision_info($imagerevision_id, $no_cache);
		$request_info->{reservation}{$reservation_id}{imagerevision} = $imagerevision_info;
		
		# Add the computer info to the hash
		my $computer_id = $request_info->{reservation}{$reservation_id}{computerid};
		my $computer_info = get_computer_info($computer_id, $no_cache);
		$request_info->{reservation}{$reservation_id}{computer} = $computer_info;
		
		# Populate natport table for reservation
		# Make sure this wasn't called from populate_reservation_natport or else recursive loop will occur
		if (defined $ENV{reservation_id} && $ENV{reservation_id} eq $reservation_id) {
			my $caller_trace = get_caller_trace(5);
			if ($caller_trace !~ /populate_reservation_natport/) {
				if ($request_state_name =~ /(new|reserved|modified|test)/) {
					if (!populate_reservation_natport($reservation_id)) {
						notify($ERRORS{'CRITICAL'}, 0, "failed to populate natport table for reservation");
					}
					if (!update_reservation_natlog($reservation_id)) {
						notify($ERRORS{'CRITICAL'}, 0, "failed to populate natlog table for reservation");
					}
				}
			}
		}
		
		# Add the connect method info to the hash
		my $connect_method_info = get_reservation_connect_method_info($reservation_id, 0);
		$request_info->{reservation}{$reservation_id}{connect_methods} = $connect_method_info;
		
		# Add the managementnode info to the hash
		my $management_node_id = $request_info->{reservation}{$reservation_id}{managementnodeid};
		my $management_node_info = get_management_node_info($management_node_id, $no_cache);
		$request_info->{reservation}{$reservation_id}{managementnode} = $management_node_info;
		
		# Retrieve the user info and add to the hash
		my $user_id = $request_info->{userid};
		my $user_info = get_user_info($user_id, 0, $no_cache);
		$request_info->{user} = $user_info;
		
		my $imagemeta_root_access = $request_info->{reservation}{$reservation_id}{image}{imagemeta}{rootaccess};
		
		# If server request and logingroupid is set, add user group members to hash, set ROOTACCESS to 0
		if (my $login_group_id = $request_info->{reservation}{$reservation_id}{serverrequest}{logingroupid}) {
			my $login_group_member_info = get_user_group_member_info($login_group_id);
			for my $login_user_id (keys %$login_group_member_info) {
				$request_info->{reservation}{$reservation_id}{users}{$login_user_id} = get_user_info($login_user_id, 0, 1);
				$request_info->{reservation}{$reservation_id}{users}{$login_user_id}{ROOTACCESS} = 0;
			}
		}
		
		# If server request and admingroupid is set, add user group members to hash, set ROOTACCESS to the value configured in imagemeta
		if (my $admin_group_id = $request_info->{reservation}{$reservation_id}{serverrequest}{admingroupid}) {
			my $admin_group_member_info = get_user_group_member_info($admin_group_id);
			for my $admin_user_id (keys %$admin_group_member_info, $user_id) {
				$request_info->{reservation}{$reservation_id}{users}{$admin_user_id} = get_user_info($admin_user_id, 0, 1);
				$request_info->{reservation}{$reservation_id}{users}{$admin_user_id}{ROOTACCESS} = $imagemeta_root_access;
			}
		}
		
		# Add the request user to the hash, set ROOTACCESS to the value configured in imagemeta
		$request_info->{reservation}{$reservation_id}{users}{$user_id} = $user_info;
		$request_info->{reservation}{$reservation_id}{users}{$user_id}{ROOTACCESS} = $imagemeta_root_access;
		
		# For imaging reservations if imagemeta.rootaccess = 0, make sure the reservation user has root access ONLY IF the user is the image owner
		# The web frontend should not allow an image capture by anyone but the image owner if imagemeta.rootaccess = 0
		my $image_owner_id = $image_info->{ownerid};
		my $request_forimaging = $request_info->{forimaging};
		if ($request_forimaging && !$imagemeta_root_access) {
			my $image_name = $imagerevision_info->{imagename};
			my $image_owner_login_name = $image_info->{unityid};
			if ($user_id eq $image_owner_id) {
				notify($ERRORS{'OK'}, 0, "user $user_id is the owner of image $image_name, overriding imagemeta.rootaccess: $imagemeta_root_access --> 1");
				$request_info->{reservation}{$reservation_id}{users}{$user_id}{ROOTACCESS} = 1;
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "capture attempted for image with root access disabled by a user other than the image owner\n" .
					"image: $image_name\n" .
					"imagemeta.rootaccess: $imagemeta_root_access\n" .
					"image owner ID: $image_owner_id\n" .
					"request user ID: $user_id"
				);
			}
		}
		
		# If server request or duration is greater >= 24 hrs disable user checks
		if ($request_info->{reservation}{$reservation_id}{serverrequest}{id}) {
			notify($ERRORS{'DEBUG'}, 0, "server request - disabling user checks");
			$request_info->{checkuser} = 0;
			$request_info->{reservation}{$reservation_id}{serverrequest}{ALLOW_USERS} = $request_info->{user}{unityid};
		}
		elsif ($request_info->{DURATION} >= (60 * 60 * 24)) {
			#notify($ERRORS{'DEBUG'}, 0, "request length > 24 hours, disabling user checks");
			$request_info->{checkuser} = 0;
		}
		
		$request_info->{reservation}{$reservation_id}{READY} = '0';
	}
	
	# Set some default non-database values for the entire request
	# All data ever added to the hash should be initialized here
	$request_info->{PID}              = $PID;
	$request_info->{PPID}             = getppid();
	$request_info->{PRELOADONLY}      = '0';
	$request_info->{CHECKTIME}        = '';
	$request_info->{NOTICEINTERVAL}   = '';
	$request_info->{RESERVATIONCOUNT} = scalar keys %{$request_info->{reservation}};
	$request_info->{UPDATED}          = '0';
	$request_info->{NOTICE_INTERVAL}  = '';
	
	if ($request_state_name eq 'image') {
		$request_info->{IMAGE_CAPTURE_TYPE} = 'Capture';
	}
	elsif ($request_state_name eq 'checkpoint') {
		$request_info->{IMAGE_CAPTURE_TYPE} = 'Checkpoint';
	}
	else {
		$request_info->{IMAGE_CAPTURE_TYPE} = '';
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved request info:\n" . format_data($request_info));
	return $request_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_request_log_info

 Parameters  : $request_id, $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves data from the log and sublog tables for the request.
               A hash is constructed. Example:
               {
                 "computerid" => 3588,
                 "ending" => "none",
                 "finalend" => "0000-00-00 00:00:00",
                 "id" => 5354,
                 ...
                 "sublog" => {
                   74 => {
                     "IPaddress" => undef,
                     "blockEnd" => undef,
                     "blockRequestid" => undef,
                     "blockStart" => undef,
                     "computerid" => 3588,
                     "hostcomputerid" => undef,
                     "id" => 74,
                     "imageid" => 3081,
                     "imagerevisionid" => 9147,
                     "logid" => 5354,
                     "managementnodeid" => 8,
                     "predictivemoduleid" => 8
                   },
                   75 => {
                     "IPaddress" => undef,
                     ...
                   },
                 },
                 "userid" => 2870,
                 "wasavailable" => 0
               }

=cut

sub get_request_log_info {
	my ($request_id, $no_cache) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not specified");
		return;
	}
	
	if (!$no_cache && defined($ENV{log_info}{$request_id})) {
		return $ENV{log_info}{$request_id};
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my %tables = (
		'log' => 'log',
		'sublog' => 'sublog',
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
request,
log,
sublog
WHERE
request.id = $request_id
AND log.id = request.logid
AND sublog.logid = log.id
EOF

	# Call the database select subroutine
	my @rows = database_select($select_statement);
	if (!@rows) {
		notify($ERRORS{'WARNING'}, 0, "log info for request $request_id could not be retrieved from the database, select statement:\n$select_statement");
		return;
	}

	# Build the hash
	my $log_info;

	for my $row (@rows) {
		my $sublog_id = $row->{'sublog-id'};
		if (!$sublog_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve log info for request $request_id, row does not contain a 'sublog-id' value:\n" . format_data($row));
			return;
		}
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			if ($table eq 'log') {
				$log_info->{$column} = $value;
			}
			elsif ($table eq 'sublog') {
				$log_info->{$table}{$sublog_id}{$column} = $value;
			}
			else {
				$log_info->{$table}{$column} = $value;
			}
		}
	}
	
	$ENV{log_info}{$request_id} = $log_info;
	#notify($ERRORS{'DEBUG'}, 0, "retrieved log info for request $request_id:\n" . format_data($log_info));
	return $log_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_managementnode_state

 Parameters  : management node info, state
 Returns     : 1 or 0
 Description : sets a given management node to maintenance

=cut

sub set_managementnode_state {
	my ($mninfo, $state) = @_;

	if (!(defined($state))) {
		notify($ERRORS{'WARNING'}, 0, "state was not specified");
		return ();
	}
	if (!(defined($mninfo->{hostname}))) {
		notify($ERRORS{'WARNING'}, 0, "management node hostname was not specified");
		return ();
	}
	if (!(defined($mninfo->{id}))) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_requests

 Parameters  : $management_node_id
 Returns     : hash
 Description : gets request information for a particular management node

=cut


sub get_management_node_requests {
	my ($management_node_id) = @_;
	
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
	reservation.lastcheck AS reservation_lastcheck,

	serverrequest.id AS serverrequest_serverrequestid,
	
	MAX(changelog.timestamp) AS changelog_timestamp

   FROM
   request
	LEFT JOIN (serverrequest) ON (serverrequest.requestid = request.id)
	LEFT JOIN (log, changelog) ON (request.logid = log.id AND changelog.logid = log.id AND changelog.remoteIP IS NOT NULL),
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
	
	# Build the hash
	my $requests = {};

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
			
			if ($key =~ /^request_/) {
				# Set the top-level key if not already set
				$requests->{$request_id}{$original_key} = $value if (!$requests->{$request_id}{$original_key});
			}
			elsif ($key =~ /requeststate_/) {
				$requests->{$request_id}{state}{$original_key} = $value if (!$requests->{$request_id}{state}{$original_key});
			}
			elsif ($key =~ /requestlaststate_/) {
				$requests->{$request_id}{laststate}{$original_key} = $value if (!$requests->{$request_id}{laststate}{$original_key});
			}
			elsif ($key =~ /reservation_/) {
				$requests->{$request_id}{reservation}{$reservation_id}{$original_key} = $value;
			}
			elsif ($key =~ /serverrequest_/) {
				$requests->{$request_id}{reservation}{$reservation_id}{$original_key} = $value;
			}
			elsif ($key =~ /changelog_/) {
				$requests->{$request_id}{log}{changelog}{$original_key} = $value;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
			}
		}    # Close foreach key in reservation row
	}    # Close loop through selected rows
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved management node requests:\n" . format_data($requests));
	return $requests;
} ## end sub get_management_node_requests


#//////////////////////////////////////////////////////////////////////////////

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
	
	if ($image_identifier =~ /^\d+$/) {
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
	
	# TODO: Get rid of the IDENTITY key, it shouldn't be used anymore
	my $management_node_info = get_management_node_info();
	if ($management_node_info) {
		$image_info->{IDENTITY} = $management_node_info->{keys};
	}
	
	# Retrieve AD info if configured for the image
	my $image_id = $image_info->{id};
	my $domain_info = get_image_active_directory_domain_info($image_id, $no_cache);
	$image_info->{imagedomain} = $domain_info;
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for image '$image_identifier':\n" . format_data($image_info));
	$ENV{image_info}{$image_identifier} = $image_info;
	$ENV{image_info}{$image_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{image_info}{$image_identifier};
}

#//////////////////////////////////////////////////////////////////////////////

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
	if ($imagerevision_identifier =~ /^\d/) {
		$select_statement .= "imagerevision.id = '$imagerevision_identifier'";
	}
	else {
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

#//////////////////////////////////////////////////////////////////////////////

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
	if ($image_identifier =~ /^\d/) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 set_production_imagerevision

 Parameters  : $imagerevision_id
 Returns     : boolean
 Description : Sets the production flag to 1 for the image revision specified by
               the argument. Sets production to 0 for all other revisions of the
               image. Sets image.name to imagerevision.imagename of the
               production revision. Sets the image.test flag to 0.
 
=cut

sub set_production_imagerevision {
	my ($imagerevision_id) = @_;
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision ID argument was not supplied");
		return;
	}
	
	# Delete cached data
	delete $ENV{production_imagerevision_info};
	
	my $sql_statement = <<EOF;
UPDATE
image,
imagerevision imagerevision_production,
imagerevision imagerevision_others
SET
image.name = imagerevision_production.imagename,
image.test = 0,
image.lastupdate = NOW(),
imagerevision_production.production = 1,
imagerevision_others.production = 0
WHERE
imagerevision_production.id = $imagerevision_id
AND imagerevision_production.imageid = image.id
AND imagerevision_others.imageid = imagerevision_production.imageid
AND imagerevision_others.id != imagerevision_production.id
EOF
	
	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "imagerevision $imagerevision_id set to production");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set imagerevision $imagerevision_id to production");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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


#//////////////////////////////////////////////////////////////////////////////

=head2  get_vmhost_info

 Parameters  : $vmhost_identifier, $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves info from the database for the vmhost, vmprofile, and
               repository and datastore imagetypes. The $vmhost_identifier
               argument may be used to match vmhost.id, vmprofile.profilename,
               or computer.hostname.

=cut


sub get_vmhost_info {
	my ($vmhost_identifier, $no_cache) = @_;
	
	# Check the passed parameter
	if (!defined($vmhost_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "VM host identifier argument was not specified");
		return;
	}
	
	return $ENV{vmhost_info}{$vmhost_identifier} if (!$no_cache && $ENV{vmhost_info}{$vmhost_identifier});
	
	my $management_node_id = get_management_node_id();
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my %tables = (
		'vmhost' => 'vmhost',
		'vmprofile' => 'vmprofile',
		'repositoryimagetype' => 'imagetype',
		'datastoreimagetype' => 'imagetype',
		'cryptsecret' => 'cryptsecret',
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
vmprofile
LEFT JOIN (cryptsecret, cryptkey) ON (
	vmprofile.secretid = cryptsecret.secretid AND
	cryptsecret.cryptkeyid = cryptkey.id AND
	cryptkey.hosttype = 'managementnode' AND
	cryptkey.hostid = $management_node_id
),
imagetype repositoryimagetype,
imagetype datastoreimagetype,
computer

WHERE
vmprofile.id = vmhost.vmprofileid
AND vmprofile.repositoryimagetypeid = repositoryimagetype.id
AND vmprofile.datastoreimagetypeid = datastoreimagetype.id
AND vmhost.computerid = computer.id
AND 
EOF
	
	if ($vmhost_identifier =~ /^\d+$/) {
		$select_statement .= "vmhost.id = '$vmhost_identifier'\n";
	}
	else {
		$select_statement .= "(\n";
		$select_statement .= "   computer.hostname REGEXP '$vmhost_identifier(\\\\.|\$)'\n";
		$select_statement .= "   OR vmprofile.profilename = '$vmhost_identifier'\n";
		$select_statement .= ")";
	}
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select statement:\n$select_statement");
		return;
	}
	
	my $row;
	if (scalar @selected_rows > 1) {
		my $vmhost_string;
		for my $selected_row (@selected_rows) {
			# Check if the vmprofile.profilename exactly matches the VM host identifier argument
			if ($selected_row->{'vmprofile-profilename'} eq $vmhost_identifier) {
				$row = $selected_row;
				last;
			}
			$vmhost_string .= "VM host ID: " . $selected_row->{'vmhost-id'};
			$vmhost_string .= ", computer ID: " . $selected_row->{'vmhost-computerid'};
			$vmhost_string .= ", VM profile ID: " . $selected_row->{'vmprofile-id'};
			$vmhost_string .= ", VM profile name: " . $selected_row->{'vmprofile-profilename'};
			$vmhost_string .= "\n";
		}
		if (!$row) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine VM host from ambiguous argument: $vmhost_identifier, " . scalar @selected_rows . " rows were returned from database select statement:\n$select_statement\nrows:\n$vmhost_string");
			return;
		}
	}
	else {
		# Get the single row returned from the select statement
		$row = $selected_rows[0];
	}
	
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
		elsif ($table eq 'cryptsecret') {
			$vmhost_info->{vmprofile}{$table}{$column} = $value;
		}
		else {
			$vmhost_info->{$table}{$column} = $value;
		}
	}
	
	# Get the vmhost computer info and add it to the hash
	my $computer_id = $vmhost_info->{computerid};
	my $computer_info = get_computer_info($computer_id, $no_cache);
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
	
	my $vmhost_id = $vmhost_info->{id};
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved VM host $vmhost_identifier info, VM host ID: $vmhost_id, computer: $vmhost_info->{computer}{hostname}, computer ID: $vmhost_info->{computer}{id}");
	$ENV{vmhost_info}{$vmhost_identifier} = $vmhost_info;
	
	
	if ($vmhost_identifier ne $vmhost_id) {
		$ENV{vmhost_info}{$vmhost_id} = $vmhost_info;
	}
	
	return $ENV{vmhost_info}{$vmhost_identifier};
}

#//////////////////////////////////////////////////////////////////////////////

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
		$timeout_seconds = $arguments->{timeout_seconds};
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
	
	if (!defined $identity_paths || length($identity_paths) == 0) {
		my $management_node_info = get_management_node_info();
		$identity_paths = $management_node_info->{keys}
	}
	
	# TESTING: use the new subroutine if $ENV{execute_new} is set and the command isn't one that's known to fail with the new subroutine
	my $calling_subroutine = get_calling_subroutine();
	if ($calling_subroutine && $calling_subroutine !~ /execute/) {
		if ($ENV{execute_new} && $command !~ /(vmkfstools|qemu-img|Convert-VHD|scp|reboot|shutdown)/) {
			return VCL::Module::OS::execute_new($node, $command, $output_level, $timeout_seconds, $max_attempts, $port, $user, '', $identity_paths);
		}
	}
	
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
	elsif (-f 'C:/cygwin64/bin/ssh.exe') {
		$ssh_path = 'C:/cygwin64/bin/ssh.exe';
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
	
	# Determine which string to use as the connection target
	my $remote_connection_target = determine_remote_connection_target($node);
	my $node_string = $remote_connection_target;
	$node_string .= " ($node)" if ($node ne $remote_connection_target);
	
	# Command argument is enclosed in single quotes in ssh command
	# Single quotes contained within the command argument won't work without splitting it up
	# Argument:
	#   echo 'foo bar' > file
	# Enclosed in single quotes
	#    'echo 'foo bar' > file'   <-- won't work
	# For each single quote in the argument, split the command by adding single quotes before and after
	# Enclose the original single quote in double quotes
	#    'echo '"'"'foo bar'"'"' > file'
	if ($command =~ /'/) {
		my $original_command = $command;
		$command =~ s/'/'"'"'/g;
		notify($ERRORS{'DEBUG'}, 0, "command argument contains single quotes, enclosed all single quotes in double quotes:\n" .
			"original command: '$original_command'\n" .
			"modified command: '$command'"
		);
	}
	
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
	$ssh_command .= "-o ConnectTimeout=30 ";
	$ssh_command .= "-o BatchMode=no ";
	$ssh_command .= "-o PasswordAuthentication=no ";
	$ssh_command .= "-l $user ";
	$ssh_command .= "-p $port ";
	$ssh_command .= "-x ";
	$ssh_command .= "$remote_connection_target '$command' 2>&1";
	
	# Truncate command shown in vcld.log if it is very long
	my $max_command_output_length = 3000;
	my $beginning_characters_shown = 500;
	my $ending_characters_shown = 200;
	
	my $command_length = length($command);
	my $command_summary;
	my $command_chars_suppressed = ($command_length - $beginning_characters_shown - $ending_characters_shown - $max_command_output_length);
	if ($command_chars_suppressed > 0) {
		$command_summary = substr($command, 0, $beginning_characters_shown) . "<$command_chars_suppressed characters omitted>" . substr($command, -$ending_characters_shown);
	}
	else {
		$command_summary = $command;
	}
	
	my $ssh_command_length = length($ssh_command);
	my $ssh_command_summary;
	my $ssh_command_chars_suppressed = ($ssh_command_length - $beginning_characters_shown - $ending_characters_shown - $max_command_output_length);
	if ($ssh_command_chars_suppressed > 0) {
		$ssh_command_summary = substr($ssh_command, 0, $beginning_characters_shown) . "<$ssh_command_chars_suppressed characters omitted>" . substr($ssh_command, -$ending_characters_shown);
	}
	else {
		$ssh_command_summary = $ssh_command;
	}
	
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
			notify($ERRORS{'DEBUG'}, 0, "executing SSH command on $node_string: '$ssh_command_summary'") if $output_level;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: executing SSH command on $node_string: '$ssh_command_summary'") if $output_level;
		}
		
		# Enclose SSH command in an eval block and use alarm to eventually timeout the SSH command if it hangs
		my $start_time = time;
		eval {
			# Override the die and alarm handlers
			local $SIG{__DIE__} = sub{};
			
			local $SIG{__WARN__} = sub{
				my $warning_message = shift || '';
				notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: warning was generated attempting to run SSH command on $node_string, command length: $ssh_command_length, warning message: $warning_message\nSSH command:\n$ssh_command_summary");
			};
			
			local $SIG{ALRM} = sub { die "alarm\n" };
			
			if ($timeout_seconds) {
				notify($ERRORS{'DEBUG'}, 0, "waiting up to $timeout_seconds seconds for SSH process to finish") if $output_level;
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
			
			if ($command =~ /testing/) {
				notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: SSH command timed out after $duration seconds, timeout threshold: $timeout_seconds seconds, command: $node_string:\n$ssh_command");
				return;
			}
			elsif ($max_attempts == 1 || $attempts < $max_attempts) {
				notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: SSH command timed out after $duration seconds, timeout threshold: $timeout_seconds seconds, command: $node_string:\n$ssh_command");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "attempt $attempts/$max_attempts: SSH command timed out after $duration seconds, timeout threshold: $timeout_seconds seconds, command: $node_string:\n$ssh_command");
				return;
			}
			next;
		}
		elsif ($EVAL_ERROR) {
			notify($ERRORS{'CRITICAL'}, 0, "attempt $attempts/$max_attempts: eval error was generated attempting to run SSH command: $node_string:\n$ssh_command_summary, eval error: $EVAL_ERROR");
			next;
		}
		elsif (!defined($ssh_output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: SSH output is not defined after attempting to run SSH command: $node_string:\n$ssh_command_summary, command length: $ssh_command_length");
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
		$ssh_output =~ s/.*ssh-askpass:[^\n]*//ig;
		$ssh_output =~ s/.*bad permissions:[^\n]*//ig;
		
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
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: failed to execute SSH command on $node_string: '$command', exit status: $exit_status, output:\n$ssh_output_formatted") if $output_level;
			next;
		}
		elsif ($ssh_output_formatted =~ /(Connection timed out during banner exchange)/i) {
			$banner_exchange_error_count++;
			if ($banner_exchange_error_count >= $banner_exchange_error_limit) {
				notify($ERRORS{'WARNING'}, 0, "failed to execute SSH command on $node_string, encountered $banner_exchange_error_count banner exchange errors");
				return ();
			}
			else {
				# Don't count against attempt limit
				$attempts--;
				my $banner_exchange_delay_seconds = ($banner_exchange_error_count * 2);
				notify($ERRORS{'DEBUG'}, 0, "encountered banner exchange error on $node_string, sleeping for $banner_exchange_delay_seconds seconds, command:\n$command\noutput:\n$ssh_output") if $output_level;
				sleep $banner_exchange_delay_seconds;
				next;
			}
		}
		elsif ($exit_status == 255 && $ssh_command !~ /(vmware-cmd|vim-cmd|vmkfstools|vmrun)/i) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: failed to execute SSH command on $node_string: '$command', exit status: $exit_status, SSH exits with the exit status of the remote command or with 255 if an error occurred, output $output_level:\n$ssh_output_formatted") if $output_level;
			next;
		}
		else {
			# SSH command was executed successfully, actual command on node may have succeeded or failed
			
			# Split the output up into an array of lines
			my @output_lines = split(/[\r\n]+/, $ssh_output);
			
			# Print the output unless no_output is set
			notify($ERRORS{'DEBUG'}, 0, "command: '$command_summary', exit_status: $exit_status, output:\n" . join("\n", @output_lines)) if $output_level > 1;
			
			# Return the exit status and output
			return ($exit_status, \@output_lines);
		}
	} ## end while ($attempts < $max_attempts)

	# Failure, SSH command did not run at all
	notify($ERRORS{'WARNING'}, 0, "failed to run SSH command after $attempts attempts, command: $ssh_command_summary, exit status: $exit_status, output:\n$ssh_output_formatted") if $output_level;
	return ();

} ## end sub run_ssh_command

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Determine which IP address or hostname should be used to connect to the target
	if ($path1 =~ /^([^:]+):/) {
		my $node = $1;
		my $connection_target = determine_remote_connection_target($node);
		if ($connection_target ne $node) {
			$path1 =~ s/^$node:/$connection_target:/;
		}
	}
	
	if ($path2 =~ /^([^:]+):/) {
		my $node = $1;
		my $connection_target = determine_remote_connection_target($node);
		if ($connection_target ne $node) {
			$path2 =~ s/^$node:/$connection_target:/;
		}
	}
	
	
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

#//////////////////////////////////////////////////////////////////////////////

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
			#notify($ERRORS{'DEBUG'}, 0, "retrieving current management node info for '$management_node_identifier' from database, cached data is stale: $data_age_seconds seconds old");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "management node info for '$management_node_identifier' is not stored in \$ENV{management_node_info}");
	}

	my $select_statement = "
SELECT
managementnode.*,
resource.id AS resource_id,
state.name AS statename
FROM
managementnode,
resource,
resourcetype,
state
WHERE
managementnode.stateid = state.id
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

	# Get the inuse timing checks for general and server based reservations
	my $general_inuse_check = get_variable('general_inuse_check') || 300;
	$management_node_info->{GENERAL_INUSE_CHECK} = round($general_inuse_check / 60);
	$ENV{management_node_info}{GENERAL_INUSE_CHECK} = $management_node_info->{GENERAL_INUSE_CHECK};

	my $server_inuse_check = get_variable('server_inuse_check') || 300;
	$management_node_info->{SERVER_INUSE_CHECK} = round($server_inuse_check / 60);
	$ENV{management_node_info}{SERVER_INUSE_CHECK} = $management_node_info->{SERVER_INUSE_CHECK};
	
	my $cluster_inuse_check = get_variable('cluster_inuse_check') || 300;
	$management_node_info->{CLUSTER_INUSE_CHECK} = round($cluster_inuse_check / 60);
	$ENV{management_node_info}{CLUSTER_INUSE_CHECK} = $management_node_info->{CLUSTER_INUSE_CHECK};

	my $user_password_length = get_variable('user_password_length') || 6;
	$management_node_info->{USER_PASSWORD_LENGTH} = $user_password_length;
	$ENV{management_node_info}{USER_PASSWORD_LENGTH} = $management_node_info->{USER_PASSWORD_LENGTH};

	my $user_password_include_spchar = get_variable('user_password_spchar') || 0;
	$management_node_info->{INCLUDE_SPECIAL_CHARS} = $user_password_include_spchar;
	$ENV{management_node_info}{INCLUDE_SPECIAL_CHARS} =  $management_node_info->{INCLUDE_SPECIAL_CHARS};

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
	
	# Store the info in $ENV{management_node_info}
	# Add keys for all of the unique identifiers that may be passed as an argument to this subroutine
	$ENV{management_node_info}{$management_node_identifier} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{hostname}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{SHORTNAME}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{id}} = $management_node_info;
	$ENV{management_node_info}{$management_node_info->{IPaddress}} = $management_node_info;
	
	# Save the time when the data was retrieved
	$ENV{management_node_info}{$management_node_identifier}{RETRIEVAL_TIME} = time;
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved management node info: '$management_node_identifier' ($management_node_info->{SHORTNAME})");
	return $management_node_info;
} ## end sub get_management_node_info

#//////////////////////////////////////////////////////////////////////////////

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
	if ($imagerevision_info = get_imagerevision_info($imagename)) {
		notify($ERRORS{'DEBUG'}, 0, "successfully retreived image info for $imagename");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to get_imagerevision_info for $imagename");
		return 0;
	}

	my $image_id  = $imagerevision_info->{imageid};
	my $imagerevision_id = $imagerevision_info->{id};

	if (update_currentimage($computerid, $image_id, $imagerevision_id)) {
		notify($ERRORS{'DEBUG'}, 0, "successfully updated computerid= $computerid image_id= $image_id imagerevision_id= $imagerevision_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update_currentimage imagename= $imagename computerid= $computerid");
		return 0;
	}

	return 0;

}

#//////////////////////////////////////////////////////////////////////////////

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
		notify($ERRORS{'WARNING'}, 0, "*******NEXTIMAGE updating computer $computerid: image=$imageid, imagerevision=$imagerevisionid nextimageid = $imageid");
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 update_computer_private_ip_address

 Parameters  : $computer_identifier, $private_ip_address
 Returns     : boolean
 Description : Updates the computer.privateIPaddress value of the computer
					specified by the argument. The value can be set to null by
					passing 'null' as the argument. The $computer_identifier argument
					may either be the numeric computer.id value or the
					computer.hostname value.

=cut

sub update_computer_private_ip_address {
	my ($computer_identifier, $private_ip_address) = @_;
	
	if (!defined($computer_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument was not specified");
		return;
	}
	if (!defined($private_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "private IP address argument was not specified");
		return;
	}
	
	# Figure out the computer ID based on the $computer_identifier argument
	my $computer_id;
	if ($computer_identifier =~ /^\d+$/) {
		$computer_id = $computer_identifier;
	}
	else {
		$computer_id = get_computer_ids($computer_identifier);
		if (!$computer_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to update computer private IP address, computer ID could not be determed from argument: $computer_identifier");
			return;
		}
	}
	
	my $computer_string = $computer_identifier;
	$computer_string .= " ($computer_id)" if ($computer_identifier ne $computer_id);
	
	# Delete cached data if previously set
	delete $ENV{computer_private_ip_address}{$computer_id};
	
	my $private_ip_address_text;
	if ($private_ip_address =~ /null/i) {
		$private_ip_address_text = 'NULL';
	}
	else {
		$private_ip_address_text = "'$private_ip_address'";
	}
	
	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
computer
SET
privateIPaddress = $private_ip_address_text
WHERE
computer.deleted != '1'
AND computer.id = '$computer_id'
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		if ($private_ip_address !~ /null/i) {
			$ENV{computer_private_ip_address}{$computer_id} = $private_ip_address;
		}
		notify($ERRORS{'OK'}, 0, "updated private IP address of computer $computer_string in database: $private_ip_address");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update private IP address of computer $computer_string in database: $private_ip_address");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_computer_public_ip_address

 Parameters  : $computer_id, $public_ip_address
 Returns     : boolean
 Description : Updates the computer.IPaddress value of the computer specified by
               the argument.

=cut

sub update_computer_public_ip_address {
	my ($computer_id, $public_ip_address) = @_;
	
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID argument was not specified");
		return;
	}
	if (!defined($public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "public IP address argument was not specified");
		return;
	}

	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
computer
SET
IPaddress = '$public_ip_address'
WHERE
id = $computer_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "updated public IP address of computer $computer_id in database: $public_ip_address");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update public IP address of computer $computer_id in database: $public_ip_address");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_computer_vmhost_id

 Parameters  : $computer_id, $vmhost_id
 Returns     : boolean
 Description : Updates the computer.vmhostid value of the computer specified by
               the argument.

=cut

sub update_computer_vmhost_id {
	my ($computer_id, $vmhost_id) = @_;
	
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID argument was not specified");
		return;
	}
	if (!defined($vmhost_id)) {
		notify($ERRORS{'WARNING'}, 0, "VM host ID argument was not specified");
		return;
	}

	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
computer
SET
vmhostid = '$vmhost_id'
WHERE
id = $computer_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "updated VM host ID of computer $computer_id in database: $vmhost_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update VM host ID of of computer $computer_id in database: $vmhost_id");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
		return;
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
		
		my $request_info = get_request_info($request_id);
		
		if (!$request_info) {
			# Request may have been deleted in this brief period
			if (is_request_deleted($request_id)) {
				notify($ERRORS{'OK'}, 0, "request was deleted before request info could be retrieved: $request_id");
				next;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve request info, request ID: $request_id");
				return;
			}
		}
		
		my $data_structure;
		eval {$data_structure = new VCL::DataStructure({request_data => $request_info, reservation_id => $reservation_id});};
		if (my $exception = Exception::Class::Base->caught()) {
			notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure object" . $exception->message);
			return;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "retrieved info and DataStructure object for $request_id:$reservation_id");
		$computer_request_info->{$request_id}{data} = $data_structure;
	}

	return $computer_request_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_request_current_state_name

 Parameters  : $request_id, $suppress_warnings (optional)
 Returns     : String containing state name for a request
 Description :

=cut


sub get_request_current_state_name {
	my ($request_id, $suppress_warnings) = @_;

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
	
	my $notify_type = ($suppress_warnings ? $ERRORS{'OK'} : $ERRORS{'WARNING'});
	# Check to make sure 1 row was returned
	if (!@selected_rows) {
		notify($notify_type, 0, "unable to determine current state of request $request_id, zero rows were returned from database select");
		return;
	}
	
	my $row = $selected_rows[0];
	my $state_name = $row->{state_name};
	my $laststate_name = $row->{laststate_name};
	#notify($ERRORS{'DEBUG'}, 0, "retrieved current state of request $request_id: $state_name/$laststate_name");
	
	if (wantarray) {
		return ($state_name, $laststate_name);
	}
	else {
		return $state_name;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_current_state_name

 Parameters  : $computer_id
 Returns     : string
 Description :

=cut


sub get_computer_current_state_name {
	my ($computer_id) = @_;
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID argument was not specified");
		return;
	}

	# Create the select statement
	my $select_statement = <<EOF;
SELECT
state.name
FROM
state,
computer
WHERE
computer.stateid = state.id
AND computer.id = $computer_id
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (!@rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current computer state, no rows were returned from database select statement:\n$select_statement");
		return;
	}
	
	my $row = $rows[0];
	my $state_name = $row->{name};
	notify($ERRORS{'DEBUG'}, 0, "retrieved current state of computer $computer_id: $state_name");
	return $state_name;
} ## end sub get_computer_current_state_name

#//////////////////////////////////////////////////////////////////////////////

=head2 update_log_ending

 Parameters  : $log_id, $log_ending
 Returns     : boolean
 Description : Updates log.ending to the value specified by the argument and
               log.finalend to the current time.

=cut

sub update_log_ending {
	my ($log_id, $log_ending) = @_;
	if (!defined($log_id)) {
		notify($ERRORS{'WARNING'}, 0, "log ID argument was not specified");
		return;
	}
	elsif (!defined($log_ending)) {
		notify($ERRORS{'WARNING'}, 0, "log ending argument was not specified");
		return;
	}
	
	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
log
SET
log.finalend = NOW(),
log.ending = '$log_ending'
WHERE
log.id = $log_id
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated log ID $log_id, set log.ending to '$log_ending', log.finalend to now");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update log ID $log_id, set log.ending to '$log_ending', log.finalend to now");
		return 0;
	}
} ## end sub update_log_ending

#//////////////////////////////////////////////////////////////////////////////

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
AND reservation.lastcheck <= NOW()
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

#//////////////////////////////////////////////////////////////////////////////

=head2 set_reservation_lastcheck

 Parameters  : $lastcheck, @reservation_ids
 Returns     : string
 Description : Updates reservation.lastcheck to the time specified.

=cut

sub set_reservation_lastcheck {
	my ($reservation_lastcheck, @reservation_ids) = @_;
	
	# Check the passed parameter
	if (!$reservation_lastcheck) {
		notify($ERRORS{'WARNING'}, 0, "reservation lastcheck argument was not specified");
		return;
	}
	elsif (!@reservation_ids) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	
	my $reservation_id_string = join(", ", @reservation_ids);
	
	if ($reservation_lastcheck !~ /:/) {
		$reservation_lastcheck = convert_to_datetime($reservation_lastcheck);
	}
	my $reservation_lastcheck_epoch = convert_to_epoch_seconds($reservation_lastcheck);
	
	# Only allow the lastcheck time to be set in the future
	my $current_time_epoch = time;
	my $duration_seconds = ($reservation_lastcheck_epoch-$current_time_epoch);
	if ($duration_seconds < 0) {
		notify($ERRORS{'WARNING'}, 0, "reservation.lastcheck not set to $reservation_lastcheck for reservation IDs: $reservation_id_string, time is in the past");
		return;
	}
	elsif ($duration_seconds < (20*60)) {
		notify($ERRORS{'WARNING'}, 0, "reservation.lastcheck not set to $reservation_lastcheck for reservation IDs: $reservation_id_string, time is too close to the current time");
		return;
	}
	
	# Construct the update statement
	my $update_statement = <<EOF;
UPDATE
reservation
SET
reservation.lastcheck = '$reservation_lastcheck'
WHERE
reservation.id IN ($reservation_id_string)
EOF

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "reservation.lastcheck set to '$reservation_lastcheck' for reservation IDs: $reservation_id_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set reservation.lastcheck to '$reservation_lastcheck' for reservation IDs: $reservation_id_string");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

	if (defined($new_image_pretty_name)) {
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_computerloadlog_reservation

 Parameters  : $reservation_id_argument, $loadstate_regex (optional)
 Returns     : boolean
 Description : Deletes rows from the computerloadlog table.
               
               The $reservation_id argument may be either a single integer ID or
               a reference to an array of integer IDs.
               
               A $loadstate_regex argument can be specified to limit the rows
               removed to a certain loadstate names. The regex does not allow
               all of the functionality of a Perl regex such as (?!...).
               
               To delete multiple loadstate names, pass something such as:
               (begin|info)
               
               To delete all entries except certain loadstate names, precede the
               expression with an exclaimation mark:
               !(begin|info)              

=cut

sub delete_computerloadlog_reservation {
	my $reservation_id_argument = shift;
	my $loadstate_regex = shift;

	# Check the passed parameter
	if (!defined($reservation_id_argument)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument were not specified");
		return;
	}
	
	# Check if a single reservation ID was specified or an array of IDs
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
computerloadlog,
computerloadstate
WHERE
computerloadlog.reservationid IN ($reservation_id_string)
AND computerloadlog.loadstateid = computerloadstate.id
EOF

	
	# Check if loadstateid was specified
	# If so, only delete rows matching the loadstateid
	my $regex_string = '';
	if ($loadstate_regex) {
		if ($loadstate_regex =~ /^\!/) {
			$loadstate_regex =~ s/^\!//;
			$regex_string = " NOT matching loadstate regex '$loadstate_regex'";
			$sql_statement .= "AND computerloadstate.loadstatename NOT REGEXP '$loadstate_regex'";
		}
		else {
			$regex_string = " matching loadstate regex '$loadstate_regex'";
			$sql_statement .= "AND computerloadstate.loadstatename REGEXP '$loadstate_regex'";
		}
	}

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted rows from computerloadlog$regex_string for reservation IDs: $reservation_id_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete from computerloadlog table for reservation IDs: $reservation_id_string");
		return 0;
	}
} ## end sub delete_computerloadlog_reservation

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_request

 Parameters  : $request_id
 Returns     : 0 or 1
 Description : Deletes request and all associated reservations for a given
               request ID. This also deletes all computerloadlog rows associated
               with any of the reservations.

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
		notify($ERRORS{'DEBUG'}, 0, "request deleted: $request_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from request and reservation tables where request id=$request_id");
		return 0;
	}
} ## end sub delete_request

#//////////////////////////////////////////////////////////////////////////////

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



#//////////////////////////////////////////////////////////////////////////////

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
	computer,
	image
	SET
	computer.nextimageid = image.id
	WHERE
	image.name LIKE 'noimage'
	AND computer.id = $computer_id
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 update_sublog_ipaddress

 Parameters  : $sublog_id, $computer_public_ip_address
 Returns     : boolean
 Description : Updates the sublog table with the public IP address of the
               computer.

=cut

sub update_sublog_ipaddress {
	my ($sublog_id, $computer_public_ip_address) = @_;
	if (!defined($sublog_id)) {
		notify($ERRORS{'WARNING'}, 0, "sublog ID argument was not specified");
		return;
	}
	elsif (!defined($computer_public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "computer public IP address argument was not specified");
		return;
	}

	# Construct the SQL statement
	my $sql_statement = <<EOF;
UPDATE
sublog
SET
sublog.IPaddress = '$computer_public_ip_address'
WHERE
sublog.id = $sublog_id
EOF

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated sublog table, sublog ID: $sublog_id, IP address: $computer_public_ip_address");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update sublog table, sublog ID: $sublog_id, IP address: $computer_public_ip_address");
		return 0;
	}
} ## end sub update_sublog_ipaddress

#//////////////////////////////////////////////////////////////////////////////

=head2 rename_vcld_process

 Parameters  : hash - Reference to hash containing request data
 Returns     : boolean
 Description : Renames running process based on request information. Appends the
               state name, request ID, and reservation ID to the process name.

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
			my $vmhost_hostname       = $data_structure->get_vmhost_short_name(0);
			my $image_name            = $data_structure->get_image_name();
			my $user_login_id         = $data_structure->get_user_login_id();
			my $request_forimaging    = $data_structure->get_request_forimaging();
			my $reservation_count     = $data_structure->get_reservation_count();
			my $reservation_is_parent = $data_structure->is_parent_reservation();
			
			# !!! IMPORTANT !!!
			# If the reservation naming scheme is changed, always check get_reservation_vcld_process_name_regex to make sure it matches the new name pattern
			
			# Append the request and reservation IDs if they are set
			$new_process_name .= " '|$PID|$request_id|$reservation_id|";
			$new_process_name .= "$request_state_name|" if ($request_state_name);
			$new_process_name .= "'";
			$new_process_name .= " $computer_short_name" if ($computer_short_name);
			$new_process_name .= ">$vmhost_hostname" if ($vmhost_hostname);
			$new_process_name .= " $image_name" if ($image_name);
			$new_process_name .= " $user_login_id" if ($user_login_id && $user_login_id !~ /(vclreload)/);
			$new_process_name .= " (imaging)" if $request_forimaging;

			# Append cluster if there are multiple reservations for this request
			notify($ERRORS{'DEBUG'}, 0, "reservation count: $reservation_count");

			if ($reservation_count > 1) {
				if ($reservation_is_parent) {
					$new_process_name .= " (cluster=parent)";
				}
				else {
					$new_process_name .= " (cluster=child)";
				}
			} ## end if ($reservation_count > 1)
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	(blockTimes.skip = '0' AND blockTimes.start < (NOW() + INTERVAL 360 MINUTE)) OR
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
				if ($key =~ /_groupid/) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	my $management_node_id         = $managementnode{id};
	my $management_node_hostname   = $managementnode{hostname};

	# Collect resource group this management node is a member of
	if ($info{managementnode}{resoucegroups} = get_resource_groups($management_node_resourceid)) {
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

		if ($info{manageable_resoucegroups}{$mresgrp_id} = get_managable_resource_groups($grp_id)) {
			notify($ERRORS{'DEBUG'}, $LOGFILE, "retrieved manageable resource groups from database for mresgrp_id= $grp_id groupname= $info{managementnode}{resoucegroups}{$mresgrp_id}{groupname}");

			foreach my $id (keys %{ $info{manageable_resoucegroups}{$grp_id} } ) {
				my $computer_group_id = $info{manageable_resoucegroups}{$grp_id}{$id}{groupid};
				if ($info{"manageable_computer_grps"}{$id}{"members"} = get_computer_grp_members($computer_group_id)) {
					notify($ERRORS{'DEBUG'}, $LOGFILE, "retrieved computers from computer groupname= $info{manageable_resoucegroups}{$grp_id}{$id}{groupname}");
				}
				else {
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

	foreach my $computergroup (keys %{ $info{manageable_computer_grps}}) {
		foreach my $computerid (keys %{ $info{manageable_computer_grps}{$computergroup}{members} }) {
			if (!(exists $computer_list{$computerid})) {
				# add to return list
				$computer_list{$computerid}{"computer_id"}=$computerid;
			}
		}
	}

	return \%computer_list;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_resource_groups

 Parameters  : $management_node_resourceid
 Returns     : hash containing list of resource groups id is a part of
 Description :

=cut

sub get_resource_groups {
	my ($resource_id) = @_;

	if (!defined($resource_id)) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_managable_resource_groups

 Parameters  : $management_node_grp_id
 Returns     : hash containing list of resource groups that can be controlled
 Description :

=cut

sub get_managable_resource_groups {
	my ($managing_resgrp_id) = @_;

	if (!defined($managing_resgrp_id)) {
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
#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_grp_members

 Parameters  : $computer_grp_id
 Returns     : hash containing list of of computer ids
 Description :

=cut

sub get_computer_grp_members {
	my ($computer_grp_id) = @_;

	if (!defined($computer_grp_id)) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# If affiliation identifier argument wasn't supplied, set it to % wildcard
	$affiliation_identifier = '%' if !$affiliation_identifier;
	
	my $select_statement = <<EOF;
SELECT DISTINCT
user.*,
adminlevel.name AS adminlevel_name,
affiliation.id AS affiliation_id,
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
	my $user_affiliation_name = $user_info->{affiliation}{name};
	
	# Set the user's preferred name to the first name if it isn't defined
	if (!defined($user_info->{preferredname}) || $user_info->{preferredname} eq '') {
		$user_info->{preferredname} = $user_info->{firstname};
	}

	# Set the user's IMid to '' if it's NULL
	if (!defined($user_info->{IMid})) {
		$user_info->{IMid} = '';
	}
	
	$user_info->{FEDERATED_LINUX_AUTHENTICATION} = 0;
	if (!$user_info->{uid}) {
		# Set the user's UID to 500 + user.id if it's not configured in the database
		$user_info->{uid} = ($user_info->{id} + 500);
		notify($ERRORS{'DEBUG'}, 0, "UID value is not configured for $user_login_id\@$user_affiliation_name, setting UID=$user_info->{uid}, setting FEDERATED_LINUX_AUTHENTICATION=$user_info->{FEDERATED_LINUX_AUTHENTICATION}");
	}
	else {
		# Check if the user's affiliation is listed in the management node's NOT_STANDALONE list
		my $management_node_info = get_management_node_info() || return;
		my $not_standalone_list = $management_node_info->{NOT_STANDALONE} || '';
		my @standalone_affiliations = split(/[,;\s]+/, $not_standalone_list);
		if (@standalone_affiliations) {
			if (grep(/^\s*$user_affiliation_name\s*$/i, @standalone_affiliations)) {
				$user_info->{FEDERATED_LINUX_AUTHENTICATION} = 1;
				notify($ERRORS{'DEBUG'}, 0, "affiliation of $user_login_id\@$user_affiliation_name is in management node's 'Affiliations Using Federated Authentication for Linux Images' list: '$management_node_info->{NOT_STANDALONE}', setting FEDERATED_LINUX_AUTHENTICATION=$user_info->{FEDERATED_LINUX_AUTHENTICATION}");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "affiliation of $user_login_id\@$user_affiliation_name is NOT in management node's 'Affiliations Using Federated Authentication for Linux Images' list: '$management_node_info->{NOT_STANDALONE}', setting FEDERATED_LINUX_AUTHENTICATION=$user_info->{FEDERATED_LINUX_AUTHENTICATION}");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "management node's 'Affiliations Using Federated Authentication for Linux Images' list is empty, setting FEDERATED_LINUX_AUTHENTICATION=$user_info->{FEDERATED_LINUX_AUTHENTICATION}");
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
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for user '$user_identifier', affiliation: '$affiliation_identifier':\n" . format_data($user_info));
	$ENV{user_info}{$user_identifier} = $user_info;
	$ENV{user_info}{$user_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{user_info}{$user_identifier};	
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_group_name

 Parameters  : $group_id
 Returns     : scalar - group name
 Description :

=cut

sub get_group_name {
	my ($group_id) = @_;
	
	
	if (!defined($group_id)) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_info

 Parameters  : $computer_identifier, $no_cache (optional)
 Returns     : hash reference
 Description :

=cut

sub get_computer_info {
	my ($computer_identifier, $no_cache) = @_;
	if (!defined($computer_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument was not supplied");
		return;
	}
	
	if (!$no_cache && defined($ENV{computer_info}{$computer_identifier})) {
		return $ENV{computer_info}{$computer_identifier};
	}
	#notify($ERRORS{'DEBUG'}, 0, "retrieving info for computer $computer_identifier");
	
	my $calling_subroutine = get_calling_subroutine();
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'computer',
		'state',
		'provisioning',
		'module',
		'schedule',
		'platform',
		'resource',
		'resourcetype',
		'nathostcomputermap'
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

	# Add the column for predictive module info
   my @columns = @{$database_table_columns->{module}};
   for my $column (@columns) {
      $select_statement .= "predictivemodule.$column AS 'predictivemodule-$column',\n";
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
LEFT JOIN (module AS predictivemodule) ON (predictivemodule.id = computer.predictivemoduleid)
LEFT JOIN (
   resource,
   resourcetype
)
ON (
   resource.subid = computer.id
   AND resource.resourcetypeid = resourcetype.id
   AND resourcetype.name = 'computer'
)
LEFT JOIN (nathostcomputermap) ON (nathostcomputermap.computerid = computer.id)

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
		elsif ($table eq 'predictivemodule' ) {
			$computer_info->{predictive}{module}{$column} = $value;
		}
		elsif ($table eq 'resourcetype') {
			$computer_info->{resource}{$table}{$column} = $value;
		}
		elsif ($table eq 'nathostcomputermap') {
			$computer_info->{nathost}{$table}{$column} = $value;
		}
		else {
			$computer_info->{$table}{$column} = $value;
		}
	}
	
	my $computer_id = $computer_info->{id};
	
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
		if ($calling_subroutine !~ /(get_vmhost_info)/) {
			my $vmhost_info = get_vmhost_info($vmhost_id, $no_cache);
			
			if ($vmhost_info) {
				$computer_info->{vmhost} = $vmhost_info;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "vmhostid $vmhost_id is set for $computer_hostname but the vmhost info could not be retrieved");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "skipping retrieval of VM host $vmhost_id info for $computer_hostname to avoid recursion");
		}
	}
	
	# Check if the computer associated with this reservation is assigned a NAT host
	if (my $nathost_id = $computer_info->{nathost}{nathostcomputermap}{nathostid}) {
		if ($calling_subroutine !~ /(get_computer_nathost_info)/) {
			my $nathost_info = get_computer_nathost_info($computer_id, $no_cache);
			if ($nathost_info) {
				$computer_info->{nathost} = $nathost_info;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "$computer_hostname is mapped to NAT host $nathost_id but NAT host info could not be retrieved");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "skipping retrieval of NAT host $nathost_id info for $computer_hostname to avoid recursion");
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved info for computer: $computer_hostname ($computer_id)");
	$ENV{computer_info}{$computer_identifier} = $computer_info;
	$ENV{computer_info}{$computer_identifier}{RETRIEVAL_TIME} = time;
	return $ENV{computer_info}{$computer_identifier};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_nathost_info

 Parameters  : $computer_identifier
 Returns     : hash reference
 Description : Retrieves nathost info if a nathost is mapped to the computer via
               the nathostcomputermap table. Example:
               {
                 "HOSTNAME" => "nat1.vcl.org",
                 "datedeleted" => undef,
                 "deleted" => 0,
                 "id" => 2,
                 "publicIPaddress" => "x.x.x.x",
                 "internalIPaddress" => "x.x.x.x",
                 "nathostcomputermap" => {
                   "computerid" => 3591,
                   "nathostid" => 2
                 },
                 "resource" => {
                   "id" => 6185,
                   "resourcetype" => {
                     "id" => 16,
                     "name" => "managementnode"
                   },
                   "resourcetypeid" => 16,
                   "subid" => 8
                 },
                 "resourceid" => 6185
               }

=cut

sub get_computer_nathost_info {
	my ($computer_identifier, $no_cache) = @_;
	if (!defined($computer_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument was not supplied");
		return;
	}
	
	return $ENV{nathost_info}{$computer_identifier} if (!$no_cache && $ENV{nathost_info}{$computer_identifier});
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'nathost',
		'nathostcomputermap',
		'resource',
		'resourcetype',
	);
	
	# Construct the select statement
	my $select_statement = "SELECT DISTINCT\n";
	$select_statement .= "computer.id AS 'computer-id',\n";
	$select_statement .= "computer.hostname AS 'computer-hostname',\n";
	
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
computer,
nathostcomputermap,
nathost,
resource,
resourcetype

WHERE
nathostcomputermap.computerid = computer.id
AND nathostcomputermap.nathostid = nathost.id
AND nathost.resourceid = resource.id
AND resource.resourcetypeid = resourcetype.id
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

	if (!@selected_rows) {
		notify($ERRORS{'DEBUG'}, 0, "NAT host is not mapped to computer $computer_identifier");
		return {};
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine NAT host mapped to computer $computer_identifier, " . scalar @selected_rows . " rows were returned from database select statement:\n$select_statement");
		return;
	}
	
	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	
	# Construct a hash with all of the computer info
	my $nathost_info;
	
	# Loop through all the columns returned
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Split the table-column names
		my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
		
		# Add the values for the primary table to the hash
		# Add values for other tables under separate keys
		if ($table eq $tables[0]) {
			$nathost_info->{$column} = $value;
		}
		elsif ($table eq 'resourcetype') {
			$nathost_info->{resource}{resourcetype}{$column} = $value;
		}
		else {
			$nathost_info->{$table}{$column} = $value;
		}
	}
	
	$nathost_info->{HOSTNAME} = '<unknown>';
	
	my $computer_id = $nathost_info->{computer}{id};
	my $resource_id = $nathost_info->{resource}{id};
	my $resource_type = $nathost_info->{resource}{resourcetype}{name};
	my $resource_subid = $nathost_info->{resource}{subid};
	if ($resource_type eq 'managementnode') {
		my $management_node_info = get_management_node_info($resource_subid) || {};
		$nathost_info->{HOSTNAME} = $management_node_info->{hostname};
	}
	elsif ($resource_type eq 'computer') {
		# Check if NAT host is the same computer as it is assigned to to avoid recursion
		if ($computer_id eq $resource_subid) {
			$nathost_info->{HOSTNAME} = $nathost_info->{computer}{hostname};
		}
		else {
			my $computer_info = get_computer_info($resource_subid, $no_cache) || {};
			$nathost_info->{HOSTNAME} = $computer_info->{hostname};
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "NAT host resource type is not supported: $resource_type, resource ID: $resource_id");
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved info for NAT host mapped to computer computer $computer_identifier:\n" . format_data($nathost_info));
	$ENV{nathost_info}{$computer_identifier} = $nathost_info;
	return $ENV{nathost_info}{$computer_identifier};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_nathost_assigned_public_ports

 Parameters  : $nathost_id
 Returns     : array
 Description : Retrieves a list of natport.publicport values for the nathost
               specified by the argument.

=cut

sub get_nathost_assigned_public_ports {
	my ($nathost_id) = @_;
	if (!defined($nathost_id)) {
		notify($ERRORS{'WARNING'}, 0, "nathost ID argument was not supplied");
		return;
	}
	
	my $select_statement = "SELECT publicport FROM natport WHERE nathostid = $nathost_id ORDER BY publicport ASC";
	my @selected_rows = database_select($select_statement);
	my @ports;
	for my $row (@selected_rows) {
		push @ports, $row->{publicport};
	}
	
	if (@ports) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved assigned public ports for nathost $nathost_id: " . join(", ", @ports));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no public ports are assigned for nathost $nathost_id");
	}
	return @ports;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_natport_ranges

 Parameters  : none
 Returns     : array
 Description : Parses the 'natport_ranges' variable. Constucts an array of
               arrays. The child arrays are in the form:
               ($start_port, $end_port)

=cut

sub get_natport_ranges {
	return @{$ENV{natport_ranges}} if defined($ENV{natport_ranges});
	
	# Retrieve and parse the natport_ranges variable
	my $natport_ranges_variable = get_variable('natport_ranges') || '49152-65535';
	my @natport_range_strings = split(/[,;\n]+/, $natport_ranges_variable);
	my @natport_ranges;
	for my $natport_range_string (@natport_range_strings) {
		my ($start_port, $end_port) = $natport_range_string =~ /(\d+)-(\d+)/g;
		if (!defined($start_port)) {
			notify($ERRORS{'WARNING'}, 0, "unable to parse NAT port range: '$natport_range_string'");
			next;
		}
		
		# Make sure port range isn't backwards
		if ($end_port < $start_port) {
			my $start_port_temp = $start_port;
			$start_port = $end_port;
			$end_port = $start_port_temp;
		}
		
		push @natport_ranges, [$start_port, $end_port];
	}
	
	notify($ERRORS{'DEBUG'}, 0, "parsed natport_ranges variable:\n" . format_data(@natport_ranges));
	$ENV{natport_ranges} = \@natport_ranges;
	return @natport_ranges;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 populate_reservation_natport

 Parameters  : $reservation_id
 Returns     : boolean
 Description : Populates the natport table for a reservation if the computer is
               mapped to a nathost. The natport table is checked for each
               connect method port assigned to each connect method for the
               reservation.

=cut

sub populate_reservation_natport {
	my ($reservation_id) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	my $request_info = get_reservation_request_info($reservation_id, 0);
	my $computer_id = $request_info->{reservation}{$reservation_id}{computerid};
	my $computer_name = $request_info->{reservation}{$reservation_id}{computer}{SHORTNAME};
	my $imagerevision_id = $request_info->{reservation}{$reservation_id}{imagerevision}{id};
	
	my $nathost_info = $request_info->{reservation}{$reservation_id}{computer}{nathost};
	my $nathost_id = $nathost_info->{id};
	my $nathost_hostname = $nathost_info->{HOSTNAME};
	my $nathost_public_ip_address = $nathost_info->{publicIPaddress};
	
	# Make sure the nathost info is defined
	if (!defined($nathost_id)) {
		notify($ERRORS{'DEBUG'}, 0, "natport table does not need to be populated, computer $computer_id is not mapped to a NAT host");
		return 1;
	}
	notify($ERRORS{'DEBUG'}, 0, "computer $computer_id is mapped to NAT host $nathost_hostname ($nathost_hostname)");
	
	# Retrieve the connect method info - do not use cached info
	my $connect_method_info = get_reservation_connect_method_info($reservation_id, 1);
	
	# Retrieve the ports already assigned to the nathost
	my @assigned_ports = get_nathost_assigned_public_ports($nathost_id);
	
	# Put the assigned ports into a hash for easy checking
	my %assigned_port_hash = map { $_ => 1 } @assigned_ports;
	
	my %available_port_hash;
	
	# Retrieve the natport range pairs
	my @natport_ranges = get_natport_ranges();
	for my $natport_range (@natport_ranges) {
		my ($start_port, $end_port) = @$natport_range;
		if (!defined($start_port)) {
			notify($ERRORS{'WARNING'}, 0, "unable to parse NAT port range:\n" . format_data($natport_range));
			next;
		}
		
		# Loop through all of the ports in the range, check if already assigned
		for (my $port = $start_port; $port<=$end_port; $port++) {
			if (!defined($assigned_port_hash{$port})) {
				$available_port_hash{$port} = 1;
			}
		}
	}
	
	# Loop through the connect methods
	# Check if a public port has been assigned for each
	for my $connect_method_id (sort keys %$connect_method_info) {
		my $connect_method_port_info = $connect_method_info->{$connect_method_id}{connectmethodport};
		
		CONNECT_METHOD_PORT_ID: for my $connect_method_port_id (sort keys %$connect_method_port_info) {
			my $connect_method_port = $connect_method_port_info->{$connect_method_port_id};
			
			if (defined($connect_method_port->{natport})) {
				notify($ERRORS{'DEBUG'}, 0, "NAT public port is already assigned for connect method ID: $connect_method_id, port ID: $connect_method_port_id\n" . format_data($connect_method_port->{natport}));
				next CONNECT_METHOD_PORT_ID;
			}
			
			# Select a random port from the list of available ports
			my @available_ports = sort keys %available_port_hash;
			my $available_port_count = scalar(@available_ports);
			if (!$available_port_count) {
				notify($ERRORS{'CRITICAL'}, 0, "no NAT public ports are available for NAT host $nathost_hostname ($nathost_id)");
				return;
			}
			my $random_index =  int(rand($available_port_count));
			my $public_port = $available_ports[$random_index];
			
			# Remove the selected port from the available port hash
			delete $available_port_hash{$public_port};
			
			# Make multiple attempts, it's possible 2 reservations will attempt to assign the same public port at the same time
			# Using random ports helps avoid collisions
			# TODO: add semaphore
			my $attempt_limit = 5;
			for (my $attempt = 1; $attempt <= $attempt_limit; $attempt++) {
				sleep_uninterrupted(1);
				if (insert_natport($reservation_id, $nathost_id, $connect_method_port_id, $public_port)) {
					next CONNECT_METHOD_PORT_ID;
				}
			}
			notify($ERRORS{'CRITICAL'}, 0, "failed to insert natport entry after making $attempt_limit attempts:\n" .
				"connectmethod ID: $connect_method_id\n" .
				"connectmethodport ID: $connect_method_port_id\n" .
				"reservation ID: $reservation_id\n" .
				"nathost ID: $nathost_id\n" .
				"public port: $public_port"
			);
			return;
		}
	}
	
	# Get the connect method info again to verify all ports are assigned a NAT public port
	my $info_string = "";
	$connect_method_info = get_reservation_connect_method_info($reservation_id, 1);
	for my $connect_method_id (sort keys %$connect_method_info) {
		my $connect_method = $connect_method_info->{$connect_method_id};
		my $connect_method_name = $connect_method->{name};
		
		for my $connect_method_port_id (sort keys %{$connect_method->{connectmethodport}}) {
			my $connect_method_port = $connect_method->{connectmethodport}{$connect_method_port_id};
			my $protocol = $connect_method_port->{protocol};
			my $port = $connect_method_port->{port};
			
			my $nat_port = $connect_method_port->{natport};
			my $public_port = $nat_port->{publicport};
			if (!defined($nat_port)) {
				notify($ERRORS{'WARNING'}, 0, "NAT public port is not assigned for connect method ID: $connect_method_id, port ID: $connect_method_port_id");
				return;
			}
			$info_string .= "$connect_method_name: $nathost_public_ip_address:$public_port --> $computer_name:$port ($protocol)\n";
		}
	}
	notify($ERRORS{'DEBUG'}, 0, "NAT port forwarding information:\n$info_string");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 insert_natport

 Parameters  : $reservation_id, $nathost_id, $connect_method_port_id, $public_port
 Returns     : boolean
 Description : Inserts an entry into the natport table.

=cut

sub insert_natport {
	my ($reservation_id, $nathost_id, $connect_method_port_id, $public_port) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	elsif (!defined($nathost_id)) {
		notify($ERRORS{'WARNING'}, 0, "nathost ID argument was not supplied");
		return;
	}
	elsif (!defined($connect_method_port_id)) {
		notify($ERRORS{'WARNING'}, 0, "connect method port ID argument was not supplied");
		return;
	}
	elsif (!defined($public_port)) {
		notify($ERRORS{'WARNING'}, 0, "public port argument was not supplied");
		return;
	}
	
	my $insert_statement = <<EOF;
INSERT IGNORE INTO
natport
(
   reservationid,
   nathostid,
   connectmethodportid,
   publicport
)
VALUES
(
   $reservation_id,
   $nathost_id,
   $connect_method_port_id,
   $public_port
)
ON DUPLICATE KEY UPDATE publicport = $public_port
EOF

	my $result = database_execute($insert_statement);
	if ($result) {
		notify($ERRORS{'DEBUG'}, 0, "inserted entry into natport table:\nreservation: $reservation_id\nnathost ID: $nathost_id\nconnectmethodport ID: $connect_method_port_id\npublic port: $public_port");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert entry into natport table\nreservation: $reservation_id\nnathost ID: $nathost_id\nconnectmethodport ID: $connect_method_port_id\npublic port: $public_port");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 insert_nathost

 Parameters  : $resource_type, $resource_identifier
 Returns     : boolean
 Description : Inserts an entry into the nathost table. The $resource_type
               argument must either be 'computer' or 'managementnode'.

=cut

sub insert_nathost {
	my ($resource_type, $resource_identifier) = @_;
	if (!defined($resource_type)) {
		notify($ERRORS{'WARNING'}, 0, "resource type argument was not supplied");
		return;
	}
	elsif ($resource_type !~ /^(computer|managementnode)$/) {
		notify($ERRORS{'WARNING'}, 0, "resource type argument is not valid: '$resource_type', it must either be 'computer' or 'managementnode'");
		return;
	}
	elsif (!defined($resource_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "resource identifier argument was not supplied");
		return;
	}
	
	my $resource_id;
	my $public_ip_address;
	if ($resource_type eq 'computer') {
		my $computer_info = get_computer_info($resource_identifier);
		if (!$computer_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to insert nathost, info could not be retrieved for computer '$resource_identifier'");
			return;
		}
		$resource_id = $computer_info->{resource}{id};
		$public_ip_address = $computer_info->{IPaddress};
	}
	elsif ($resource_type eq 'managementnode') {
		my $management_node_info = get_management_node_info($resource_identifier);
		if (!$management_node_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to insert nathost, info could not be retrieved for management node '$resource_identifier'");
			return;
		}
		$resource_id = $management_node_info->{resource_id};
		$public_ip_address = $management_node_info->{IPaddress};
	}
	
	my $insert_statement = <<EOF;
INSERT IGNORE INTO
nathost
(
   resourceid,
   publicIPaddress
)
VALUES
(
   '$resource_id',
	'$public_ip_address'
)
ON DUPLICATE KEY UPDATE
resourceid=VALUES(resourceid),
publicIPaddress='$public_ip_address'
EOF

	if (database_execute($insert_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "inserted entry into nathost table for $resource_type, resource ID: $resource_id, NAT host public IP address: $public_ip_address");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert entry into nathost table for $resource_type, resource ID: $resource_id, NAT host public IP address: $public_ip_address");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_reservation_natlog

 Parameters  : $reservation_id
 Returns     : boolean
 Description : Adds or updates an entry in the natlog table.

=cut

sub update_reservation_natlog {
	my ($reservation_id) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	my $insert_statement = <<EOF;
INSERT IGNORE INTO
natlog
(
   sublogid,
   nathostresourceid,
   publicIPaddress,
   publicport,
	internalIPaddress,
   internalport,
   protocol,
   timestamp
)
(
SELECT
   sublog.id,
   nathost.resourceid,
   nathost.publicIPaddress,
   natport.publicport,
	nathost.internalIPaddress,
   connectmethodport.port AS internalport,
   connectmethodport.protocol,
   NOW()
   FROM
   request,
   reservation,
   sublog,
   natport,
   nathost,
   connectmethodport
   WHERE
   reservation.id = $reservation_id
   AND reservation.requestid = request.id
   AND request.logid = sublog.logid
   AND sublog.computerid = reservation.computerid
   AND natport.reservationid = reservation.id
   AND natport.nathostid = nathost.id
   AND natport.connectmethodportid = connectmethodport.id
)
ON DUPLICATE KEY UPDATE
timestamp=VALUES(timestamp)
EOF

	if (database_execute($insert_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "updated natlog table for reservation $reservation_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update natlog table for reservation $reservation_id");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vcld_semaphore_info

 Parameters  : $semaphore_identifier
 Returns     : hash reference
 Description : Retrieves information for all rows in the vcldsemaphore table. A
               hash is constructed. The keys are the vcldsemaphore.identifier
               values:
                  {
                    "sem_3115" => {
                      "expires" => "2017-03-15 11:54:36",
                      "pid" => 13775,
                      "reservationid" => 3115
                    },
                    "sem_3116" => {
                      "expires" => "2017-03-15 11:54:35",
                      "pid" => 13769,
                      "reservationid" => 3116
                    }
                  }

=cut

sub get_vcld_semaphore_info {
	my @rows = database_select('SELECT * FROM vcldsemaphore');
	
	my $vcld_semaphore_info = {};
	for my $row (@rows) {
		my $semaphore_identifier = $row->{'identifier'};
		for my $column (keys %$row) {
			next if $column eq 'identifier';
			$vcld_semaphore_info->{$semaphore_identifier}{$column} = $row->{$column};
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved vcld semaphore info:\n" . format_data($vcld_semaphore_info));
	return $vcld_semaphore_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 insert_vcld_semaphore

 Parameters  : $semaphore_identifier, $reservation_id, $semaphore_expire_seconds, $force (optional)
 Returns     : boolean
 Description : Attempts to insert a row into the vcldsemaphore table. The
					$semaphore_expire_seconds argument should contain an integer
					representing the number of seconds in the future when the
					semaphore can be deemed orphaned. The Semaphore.pm module should
					always clean up all rows added to the vcldsemaphore table when
					the semaphore object is destroyed. This is not guaranteed if a
					process dies abruptly with a KILL signal. If $expire_seconds is
					not provided, a default value of 600 seconds (10 minutes) will be
					used.

=cut

sub insert_vcld_semaphore {
	my ($semaphore_identifier, $reservation_id, $semaphore_expire_seconds, $force) = @_;
	if (!defined($semaphore_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "semaphore identifier argument was not supplied");
		return;
	}
	elsif (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	elsif (!defined($semaphore_expire_seconds)) {
		notify($ERRORS{'WARNING'}, 0, "semaphore expire seconds argument was not supplied");
		return;
	}
	elsif ($semaphore_expire_seconds !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "semaphore expire seconds argument is invalid: $semaphore_expire_seconds");
		return;
	}
	
	my $insert_statement = <<EOF;
INSERT INTO
vcldsemaphore
(
   identifier,
	reservationid,
	pid,
	expires
	
)
VALUES
(
   '$semaphore_identifier',
	$reservation_id,
	$PID,
   TIMESTAMPADD(SECOND, $semaphore_expire_seconds, NOW())
)
EOF

	if ($force) {
		$insert_statement .= <<"EOF";
ON DUPLICATE KEY UPDATE
identifier = VALUES(identifier),
reservationid = VALUES(reservationid),
pid = $PID,
expires = TIMESTAMPADD(SECOND, $semaphore_expire_seconds, NOW())
EOF
	}

	# Execute the insert statement, the return value should be the id of the row
	my ($result, $insert_error) = database_execute($insert_statement);
	if ($result) {
		notify($ERRORS{'DEBUG'}, 0, "inserted row into vcldsemaphore table, identifier: $semaphore_identifier, semaphore expire seconds: $semaphore_expire_seconds");
		return 1;
	}
	elsif ($insert_error =~ /Duplicate/i) {
		notify($ERRORS{'OK'}, 0, "vcldsemaphore table already contains a row with procid = '$semaphore_identifier': $insert_error");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert row into vcldsemaphore table, identifier: $semaphore_identifier, error: $insert_error\nSQL statement:\n$insert_statement");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_vcld_semaphore

 Parameters  : $semaphore_identifier, $expires_datetime (optional)
 Returns     : boolean
 Description : Deletes an entry from the vcldsemaphore table with the
               semaphore.identifier value specified by the argument.
               
               If the $expires_datetime argument is NOT supplied, only entries
               with a vcldsemaphore.pid value matching the current process's PID
               will be deleted for safety.
               
               In order to delete or clean up entries created by other
               processes, the $expires_datetime argument is required. This
               argument must be specified when deleting entries made by other
               processes to prevent accidental deletion of entries with the same
               identifier created between the time the current process retrieves
               the info and calls this subroutine. When $expires_datetime is
               specified, entries with any vcldsemaphore.pid value will be
               deleted but the semaphore.expires value must match the argument. 

=cut

sub delete_vcld_semaphore {
	my ($semaphore_identifier, $expires_datetime) = @_;
	if (!defined($semaphore_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "semaphore identifier argument was not supplied");
		return;
	}
	
	my $delete_statement .= <<"EOF";
DELETE 
FROM 
vcldsemaphore
WHERE
identifier = '$semaphore_identifier'
EOF
	
	my $where_string;
	if ($expires_datetime) {
		$delete_statement .= "AND expires = '$expires_datetime'";
		$where_string = ", expires: $expires_datetime";
	}
	else {
		$delete_statement .= "AND pid = $PID";
		$where_string = ", pid: $PID";
	}
	
	if (database_execute($delete_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted vcldsemaphore with identifier: '$semaphore_identifier'$where_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete vcldsemaphore with identifier: '$semaphore_identifier'$where_string");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_management_node_hostname

 Parameters  : $reservation_id, $no_cache (optional)
 Returns     : string
 Description : Returns the hostname of the management node assigned to the
               reservation specified by the argument.

=cut


sub get_reservation_management_node_hostname {
	my ($reservation_id, $no_cache) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	if (!$no_cache && defined($ENV{reservation_management_node_hostname}{$reservation_id})) {
		return $ENV{reservation_management_node_hostname}{$reservation_id};
	}
	
	my $select_statement = <<EOF;
SELECT
managementnode.hostname
FROM
reservation,
managementnode
WHERE
reservation.id = '$reservation_id'
AND reservation.managementnodeid = managementnode.id
EOF

	my @selected_rows = database_select($select_statement);
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve management node hostname for reservation $reservation_id");
		return;
	}
	
	my $row = $selected_rows[0];
	my $hostname = $row->{hostname};
	notify($ERRORS{'DEBUG'}, 0, "retrieved management node hostname for reservation $reservation_id: hostname");
	$ENV{reservation_management_node_hostname}{$reservation_id} = $hostname;
	return $hostname;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_request_id

 Parameters  : $reservation_id, $no_cache (optional)
 Returns     : integer
 Description : Retrieves the request ID assigned of a reservation.

=cut

sub get_reservation_request_id {
	my ($reservation_id, $no_cache) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	if (!$no_cache && defined($ENV{reservation_request_id}{$reservation_id})) {
		return $ENV{reservation_request_id}{$reservation_id};
	}
	
	my $select_statement = "SELECT requestid FROM reservation WHERE id = '$reservation_id'";
	my @selected_rows = database_select($select_statement);
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve request ID for reservation $reservation_id");
		return;
	}
	
	my $row = $selected_rows[0];
	my $request_id = $row->{requestid};
	notify($ERRORS{'DEBUG'}, 0, "retrieved reservation $reservation_id request ID: $request_id");
	$ENV{reservation_request_id}{$reservation_id} = $request_id;
	return $request_id;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_all_reservation_ids

 Parameters  : none
 Returns     : array
 Description : Retrieves the IDs of all reservations regardless of state or any
               other attributes.

=cut

sub get_all_reservation_ids {
	my @rows = database_select('SELECT id FROM reservation');
	my @reservation_ids = sort {$a <=> $b} map { $_->{id} } @rows;
	notify($ERRORS{'DEBUG'}, 0, "retrieved all reservation IDs currently defined in the database: " . join(', ', @reservation_ids));
	return @reservation_ids;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_request_info

 Parameters  : $reservation_id, $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves the request info for a reservation.

=cut

sub get_reservation_request_info {
	my ($reservation_id, $no_cache) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	my $request_id = get_reservation_request_id($reservation_id, $no_cache);
	if (!$request_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve request info for reservation $reservation_id, failed to determine request ID for reservation");
		return;
	}
	
	return get_request_info($request_id, $no_cache);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_ids

 Parameters  : $computer_identifier
 Returns     : If called in scalar context: integer
               If called in array context: array
 Description : Queries the computer table for computers matching the
               $computer_identifier argument. The argument may contain either
               the computer's hostname or IP address. Deleted computers are not
               considered.
               
               If called in scalar context:
               - returns an integer if a single computer matched the argument
               - returns null if no computers or multiple computers match the
                 argument
               
               If called in array context:
               - returns an array containing matching computer IDs
               - returns an empty array if no computers match the argument

=cut

sub get_computer_ids {
	my ($computer_identifier) = @_;
	
	if (!defined($computer_identifier)) {
		notify($ERRORS{'WARNING'}, $LOGFILE, "computer identifier argument was not supplied");
		return;
	}

	my $select_statement = <<EOF;
SELECT
id,
hostname
FROM
computer
WHERE
deleted = 0
AND (
   hostname REGEXP '^$computer_identifier(\\\\.|\$)'
   OR IPaddress = '$computer_identifier'
   OR privateIPaddress = '$computer_identifier'
)
EOF

	my @selected_rows = database_select($select_statement);
	my @computer_ids = map { $_->{id} } @selected_rows;
	my $computer_id_count = scalar(@computer_ids);
	
	if (!$computer_id_count) {
		notify($ERRORS{'WARNING'}, 0, "no computers were found matching argument: $computer_identifier");
		return;
	}
	
	if (wantarray) {
		notify($ERRORS{'DEBUG'}, 0, $computer_id_count . " computer" . ($computer_id_count == 1 ? ' was' : 's were') . " found matching argument: $computer_identifier, returning computer ID" . ($computer_id_count == 1 ? '' : 's') . ": " . join(", ", @computer_ids));
		return @computer_ids;
	}
	else {
		if ($computer_id_count > 1) {
			notify($ERRORS{'WARNING'}, 0, "multiple computers were found matching argument: $computer_identifier\n" . format_data(\@selected_rows));
			return;
		}
		else {
			my $computer_id = $computer_ids[0];
			#notify($ERRORS{'DEBUG'}, 0, "computer was found matching argument $computer_identifier, returning computer ID: $computer_id");
			return $computer_id;
		}
	}
}

##/////////////////////////////////////////////////////////////////////////////
#
#=head2 insert_reservation
#
# Parameters  : hash reference
# Returns     : array or integer
# Description : Inserts a reservation into the database. A hash reference
#               argument must be supplied with the following keys:
#                  state          : request state name
#                  user           : user identifier
#                  computer       : computer identifier
#                  imagerevision  : image revision identifier
#               
#               The following keys are optional:
#                  managementnode : management node identifier
#                                   (default: current management node)
#                  laststate      : request laststate name
#                                   (default: same as request.state)
#                  start_minutes  : minutes in future of request.start
#                                   (default: 0)
#                  end_minutes    : minutes in future of request.end
#                                   (default: 120)
#
#=cut
#
#sub insert_reservation {
#	my ($arguments) = @_;
#	if (!defined($arguments)) {
#		notify($ERRORS{'WARNING'}, 0, "argument hash reference was not supplied");
#		return;
#	}
#	elsif (!ref($arguments) || ref($arguments) ne 'HASH') {
#		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference:\n" . format_data($arguments));
#		return;
#	}
#	
#	my $managementnode_identifier 	= $arguments->{'managementnode'};
#	my $request_state_name 				= $arguments->{'state'};
#	my $request_laststate_name 		= $arguments->{'laststate'};
#	my $user_identifier 					= $arguments->{'user'};
#	my $computer_identifier 			= $arguments->{'computer'};
#	my $imagerevision_identifier 		= $arguments->{'imagerevision'};
#	my $future_start_minutes 			= $arguments->{'start_minutes'} || 0;
#	my $future_end_minutes 				= $arguments->{'end_minutes'} || 120;
#	
#	if (!defined($request_state_name)) {
#		notify($ERRORS{'WARNING'}, 0, "argument hash reference does not contain a required 'state' key");
#		return;
#	}
#	if (!defined($user_identifier)) {
#		notify($ERRORS{'WARNING'}, 0, "argument hash reference does not contain a required 'user' key");
#		return;
#	}
#	if (!defined($computer_identifier)) {
#		notify($ERRORS{'WARNING'}, 0, "argument hash reference does not contain a required 'computer' key");
#		return;
#	}
#	if (!defined($imagerevision_identifier)) {
#		notify($ERRORS{'WARNING'}, 0, "argument hash reference does not contain a required 'imagerevision' key");
#		return;
#	}
#	
#	$request_laststate_name = $request_state_name unless defined($request_laststate_name);
#	
#	# Retrieve current management node info if argument was not specified
#	my $management_node_info = get_management_node_info($managementnode_identifier);
#	if (!defined($management_node_info)) {
#		notify($ERRORS{'WARNING'}, 0, "failed to insert reservation, management node info could not be retrieved");
#		return;
#	}
#	my $management_node_id = $management_node_info->{id};
#	my $management_node_hostname = $management_node_info->{hostname};
#	
#	my $user_info = get_user_info($user_identifier);
#	if (!defined($user_info)) {
#		notify($ERRORS{'WARNING'}, 0, "failed to insert reservation, user info could not be retrieved");
#		return;
#	}
#	my $user_id = $user_info->{id};
#	my $user_unityid = $user_info->{unityid};
#	
#	my $computer_info = get_computer_info($computer_identifier);
#	if (!defined($computer_info)) {
#		notify($ERRORS{'WARNING'}, 0, "failed to insert reservation, computer info could not be retrieved");
#		return;
#	}
#	my $computer_id = $computer_info->{id};
#	my $computer_hostname = $computer_info->{hostname};
#	
#	my $imagerevision_info = get_imagerevision_info($imagerevision_identifier);
#	if (!defined($imagerevision_info)) {
#		notify($ERRORS{'WARNING'}, 0, "failed to insert reservation, image revision info could not be retrieved");
#		return;
#	}
#	my $imagerevision_id = $imagerevision_info->{id};
#	my $image_id = $imagerevision_info->{imageid};
#	my $image_name = $imagerevision_info->{imagename};
#	
#	notify($ERRORS{'DEBUG'}, 0, "attempting to insert reservation:\n" .
#		"request state: $request_state_name/$request_laststate_name\n" .
#		"management node: $management_node_hostname (ID: $management_node_id)\n" .
#		"user: $user_unityid (ID: $user_id)\n" .
#		"computer: $computer_hostname (ID: $computer_id)\n" .
#		"image: $image_name (ID: $image_id, imagerevision ID: $imagerevision_id)"
#	);
#	
#	# Only insert a log table entry if this reservation is tied to a user
#	# Don't insert for reload, tomaintenance, etc.
#	my $log_id;
#	my $sublog_id
#	if ($request_state_name =~ /^(new|inuse|reserved|timeout)$/) {
#		my $insert_log_statement = <<EOF;
#INSERT INTO log
#(userid, start, initialend, finalend, computerid, imageid)
#VALUES (
#	$user_id,
#	TIMESTAMPADD(MINUTE, $future_start_minutes, NOW()),
#	NOW(),
#	TIMESTAMPADD(MINUTE, $future_end_minutes, NOW()),
#	$computer_id,
#	$image_id
#)
#EOF
#		$log_id = database_execute($insert_log_statement);
#		if (!$log_id) {
#			notify($ERRORS{'WARNING'}, 0, "unable to insert reservation, failed to insert into log table");
#			return;
#		}
#		
#		
#		my $insert_sublog_statement = <<EOF;
#INSERT INTO sublog
#(logid, imageid, imagerevisionid, computerid, managementnodeid, predictivemoduleid)
#VALUES (
#	$log_id,
#	$image_id,
#	$imagerevision_id,
#	$computer_id,
#	$management_node_id,
#	(SELECT MIN(id) FROM module WHERE perlpackage = 'VCL::Module::Predictive::Level_0')
#)
#EOF
#		$sublog_id = database_execute($insert_sublog_statement);
#		if (!$sublog_id) {
#			notify($ERRORS{'WARNING'}, 0, "unable to insert reservation, failed to insert into sublog table");
#			return;
#		}
#	}
#	else {
#		notify($ERRORS{'DEBUG'}, 0, "log table entry not inserted, request state: $request_state_name");
#	}
#	
#	my $log_id_string = (defined($log_id) ? $log_id : 'NULL');
#	my $sublog_id_string = (defined($sublog_id) ? $sublog_id : 'NULL');
#	
#	my $insert_request_statement = <<EOF;
#INSERT INTO request
#(userid, stateid, laststateid, logid, start, end)
#VALUES (
#	$user_id,
#	(SELECT id FROM state WHERE name = '$request_state_name'),
#	(SELECT id FROM state WHERE name = '$request_laststate_name'),
#	$log_id_string,
#	TIMESTAMPADD(MINUTE, $future_start_minutes, NOW()),
#	TIMESTAMPADD(MINUTE, $future_end_minutes, NOW()),
#)
#EOF
#	my $request_id = database_execute($insert_request_statement);
#	if (!$request_id) {
#		notify($ERRORS{'WARNING'}, 0, "unable to insert reservation, failed to insert into request table");
#		return;
#	}
#	
#	my $insert_reservation_statement = <<EOF;
#INSERT INTO reservation
#(requestid, computerid, imageid, imagerevisionid, managementnodeid)
#VALUES (
#	$request_id,
#	$computer_id,
#	$image_id,
#	$imagerevision_id,
#	$management_node_id
#)
#EOF
#	my $reservation_id = database_execute($insert_reservation_statement);
#	if (!$reservation_id) {
#		notify($ERRORS{'WARNING'}, 0, "unable to insert reservation, failed to insert into reservation table");
#		return;
#	}
#	
#	if ($log_id) {
#		my $update_log_statement = "UPDATE log SET requestid = $request_id WHERE id = $log_id";
#		database_execute($update_log_statement);
#	}
#	
#	notify($ERRORS{'OK'}, 0, "inserted reservation:\n" .
#		"request ID: $request_id\n" .
#		"reservation ID: $reservation_id\n" .
#		"log ID: $log_id_string\n" .
#		"sublog ID: $sublog_id_string"
#	);
#	if (wantarray) {
#		return ($request_id, $reservation_id);
#	}
#	else {
#		return $reservation_id;
#	}
#}

#//////////////////////////////////////////////////////////////////////////////

=head2 insert_request

 Parameters  : $managementnode_id, $request_state_name, $request_laststate_name, $user_unityid, $computer_identifier, $image_id, $imagerevision_id, $start_minutes_in_future, $end_minutes_in_future
 Returns     : boolean
 Description :

=cut

sub insert_request {
	my ($managementnode_id, $request_state_name, $request_laststate_name, $user_unityid, $computer_identifier, $image_id, $imagerevision_id, $start_minutes_in_future, $end_minutes_in_future) = @_;


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

	if (!$computer_identifier) {
		notify($ERRORS{'WARNING'}, 0, "missing mandatory reservation key: computer_identifier");
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
	
	my $computer_id;
	if ($computer_identifier =~ /^\d+$/) {
		$computer_id = $computer_identifier;
	}
	else {
		$computer_id = get_computer_ids($computer_identifier);
		if (!$computer_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to insert request, computer ID could not be determined from argument: $computer_identifier");
			return;
		}
	}
	
	my $insert_request_statment = "
	INSERT INTO
	request
	(
      request.stateid,
      request.laststateid,
      request.userid,
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

#//////////////////////////////////////////////////////////////////////////////

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
	if ($request_id_reload = insert_request($managementnode_id, 'reload', $request_laststate_name, 'vclreload', $computer_id, $image_id, $imagerevision_id, '0', '30')) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix inserted new reload request, id=$request_id_reload nodeid=$computer_id, imageid=$image_id, imagerevision_id=$imagerevision_id");
		insertloadlog($reservation_id, $computer_id, "info", "$calling_sub: created new reload request");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert new reload request");
		return 0;
	}

	return 1;
} ## end sub insert_reload_request

#//////////////////////////////////////////////////////////////////////////////

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
	if (scalar(@data) == 1 && defined($data[0]) && !ref($data[0]) && $data[0] =~ /^</) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 pfd

 Parameters  : $data
 Returns     : 1
 Description : Intended as a quick shortcut to call:
               print format_data($var) . "\n";
               This should only be used for development. Calls to this should
               not be committed to the repository.

=cut


sub pfd {
	print "\n";
	if (scalar(@_) > 1) {
		print format_data(\@_);
	}
	else {
		print format_data(shift);
	}
	print "\n\n";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 format_hash_keys

 Parameters  : $hash_ref, $display_parent_keys, $display_values_hashref, $parents
 Returns     : hash reference
 Description : 

=cut

sub format_hash_keys {
	my ($hash_ref, $parents) = @_;
	if (!$hash_ref) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not supplied");
		return;
	}
	elsif (!ref($hash_ref) || ref($hash_ref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "first argument is not a hash reference");
		return;
	}
	
	my $indent_character = ' ';
	
	my $return_string;
	if ($return_string) {
		$return_string .= "\n";
	}
	else {
		$return_string = '';
	}
	
	if (!defined($parents)) {
		$return_string .= "{\n";
		$return_string .= format_hash_keys($hash_ref, ['']);
		$return_string .= "}";
		return $return_string;
	}
	
	my $level = scalar(@$parents);
	
	for my $key (sort { lc($a) cmp lc($b) } keys %$hash_ref) {
		my $value = $hash_ref->{$key};
		my $type = ref($value);
		
		$return_string .= $indent_character x ($level * 3);
		
		if ($type eq 'HASH') {
			push @$parents, $key;
			
			$return_string .= "$key = {\n";
			$return_string .= format_hash_keys($value, $parents);
			$return_string .= $indent_character x ($level * 3);
			$return_string .= "},\n";
			
			pop @$parents;
		}
		elsif ($type eq 'ARRAY') {
			$return_string .= "$key => [],\n";
		}
		elsif ($type) {
			$return_string .= "<$type: $key>\n";
		}
		else {
			$return_string .= "$key = '',\n";
		}
	}
	
	return $return_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 format_array_reference

 Parameters  : $data, $max_depth, $parents
 Returns     : none
 Description : 

=cut

sub format_array_reference {
	my ($data, $max_depth, $parents) = @_;
	
	$parents = [] unless $parents;
	
	my $indent_character = ' ';
	my $indent_count = 3;
	
	if (!defined($data)) {
		return "<undef>,\n";
	}
	
	my $data_type = ref($data);
	if (!$data_type) {
		if (length($data) > 100) {
			$data = substr($data, 0, 100) . '<truncated>';
		}
		return "'" . $data . "',\n";
	}
	elsif ($data_type !~ /(ARRAY|HASH)/) {
		return "<ref:$data_type>,\n";
	}

	my $hash_ref;
	my $opening_char;
	my $closing_char;
	if ($data_type eq 'ARRAY') {
		$opening_char = '[';
		$closing_char = ']';
		for (my $index = 0; $index < scalar(@$data); $index++) {
			$hash_ref->{"[$index]"}	= $data->[$index];
		}
	}
	elsif ($data_type eq 'HASH') {
		$opening_char = '{';
		$closing_char = '}';
		$hash_ref = $data;
	}
	
	
	
	my $return_string = "$opening_char";
	
	if (!$max_depth || scalar(@$parents) < $max_depth) {
		$return_string .= "\n";
		for my $key (sort keys %$hash_ref) {
			my $value = $hash_ref->{$key};
			push @$parents, $key;
			$return_string .= $indent_character x (scalar(@$parents) * $indent_count);
			$return_string .= "$key = " . format_array_reference($value, $max_depth, $parents);
			pop @$parents;
		}
		$return_string .= $indent_character x (scalar(@$parents) * $indent_count);
	}
	$return_string .= "$closing_char,\n";
	
	return $return_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_caller_trace

 Parameters  : $level_limit - number of previous calls to return
 Returns     : multi-line string containing subroutine caller information
 Description :

=cut

sub get_caller_trace {
	my ($level_limit, $brief_output) = @_;
	$level_limit = 99 if !$level_limit;

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_calling_subroutine

 Parameters  : none
 Returns     : string
 Description : Returns the name of the subroutine which called the subroutine in
               which get_calling_subroutine is called.

=cut

sub get_calling_subroutine {
	for (my $i=2; $i<10; $i++) {
		my @caller = caller($i);
		
		if (!@caller) {
			return '';
		}
		
		my $calling_subroutine = $caller[3];
		
		# Ignore if subroutine includes _ANON_
		# This is a workaround for DataStructure.pm::can
		# DataStructure.pm::_automethod checks if DataStructure.pm::can is called
		if ($calling_subroutine =~ /_ANON_/) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring calling subroutine: $calling_subroutine");
			next;
		}
		else {
			return $calling_subroutine;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to determine calling subroutine");
	return '';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_id

 Parameters  : none
 Returns     : integer
 Description : Retrieves the managementnode.id value of the local management
               node.

=cut

sub get_management_node_id {
	my $management_node_id;

	# Check the management_node_id environment variable
	if ($ENV{management_node_id}) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_database_names

 Parameters  : $no_cache (optional)
 Returns     : array
 Description : Retrieves an array containing the database names the user defined
               in vcld.conf has access to.

=cut

sub get_database_names {
	my $no_cache = shift;
	return @{$ENV{database_names}} if $ENV{database_names} && !$no_cache;
	
	my $select_statement = "
SELECT DISTINCT
SCHEMA_NAME
FROM
SCHEMATA
	";

	# Call the database select subroutine
	my @rows = database_select($select_statement, 'information_schema');

	# Check to make sure at least 1 row was returned
	if (scalar @rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "unable to get database names, 0 rows were returned from database select statement:\n$select_statement");
		return 0;
	}

	
	my @database_names;
	map({push @database_names, $_->{SCHEMA_NAME}} @rows);
	
	$ENV{database_names} = \@database_names;
	
	return @{$ENV{database_names}};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_database_table_names

 Parameters  : $database_name (optional)
 Returns     : array
 Description : Retrieves the names of all tables in the database sorted
               alphabetically. The VCL database configured in vcld.conf is used
               if no $database_name argument is specified.

=cut

sub get_database_table_names {
	my $database_name = shift || $DATABASE;
	
	my $select_statement = <<EOF;
SELECT DISTINCT
TABLES.TABLE_NAME
FROM
TABLES
WHERE
TABLES.TABLE_SCHEMA = '$database_name'
EOF

	# Call the database select subroutine
	my @rows = database_select($select_statement, 'information_schema');

	if (!@rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve database table columns");
		return;
	}
	
	my @database_columns = map { $_->{TABLE_NAME} } @rows;
	return sort { lc($a) cmp lc($b) } @database_columns;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_database_table_columns

 Parameters  : $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves information for all tables and columns from the VCL
               database and constructs a hash. The hash keys are the table
               names. Each key contains an array reference containing the
               table's column names. Example:
               {
                  "OStype" => [
                    "id",
                    "name"
                  ],
                  "adminlevel" => [
                    "id",
                    "name"
                  ],
                 "affiliation" => [
                    "id",
                    "name",
                    "shibname",
                    ...
                  ],
               }

=cut

sub get_database_table_columns {
	my $no_cache = shift;
	return $ENV{database_table_columns} if $ENV{database_table_columns} && !$no_cache;
	
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_computerloadlog_entries

 Parameters  : $reservation_id
 Returns     : array
 Description : Retrieves computerloadlog info for a single reservation. An array
               of hashes is returned. The array is ordered from oldest entry to
               newest.
               [
                  {
                     "additionalinfo" => "beginning to process, state is test",
                     "computerid" => 3582,
                     "computerloadstate" => {
                     "loadstatename" => "begin"
                     },
                        "id" => 3494,
                        "loadstateid" => 54,
                        "reservationid" => 3115,
                        "timestamp" => "2014-12-17 16:09:11"
                  },
                  {
                     "additionalinfo" => "begin initial connection timeout (xxx seconds)",
                     "computerid" => 3582,
                     "computerloadstate" => {
                     "loadstatename" => "initialconnecttimeout"
                     },
                        "id" => 3495,
                        "loadstateid" => 56,
                        "reservationid" => 3115,
                        "timestamp" => "2014-12-17 16:09:14"
                  }
               ]

=cut

sub get_reservation_computerloadlog_entries {
	my ($reservation_id) = @_;
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not passed");
		return;
	}

	my $select_statement = <<EOF;
SELECT
computerloadlog.*,
computerloadstate.loadstatename AS computerloadstate_loadstatename

FROM
computerloadlog,
computerloadstate

WHERE
computerloadlog.reservationid = $reservation_id
AND computerloadlog.loadstateid = computerloadstate.id

ORDER BY computerloadlog.timestamp ASC
EOF

	my @rows = database_select($select_statement);
	
	my @computerloadlog_info;
	for my $row (@rows) {
		for my $column (keys %$row) {
			my $value = $row->{$column};
			if ($column =~ /^([^_]+)_([^_]+)$/) {
				$row->{$1}{$2} = $value;
				delete $row->{$column};
			}
		}
		
		push @computerloadlog_info, $row;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved computerloadlog info for reservation $reservation_id:\n" . format_data(@computerloadlog_info));
	return @computerloadlog_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_computerloadlog_time

 Parameters  : $reservation_id, $loadstatename, $newest (optional)
 Returns     : string (datetime)
 Description : Retrieves the timestamp of a computerloadlog entry matching the
               $loadstatename argument for a reservation and returns the time in
               epoch seconds. By default, the timestamp of the oldest matching
               entry is returned. The newest may be returned by providing the
               $newest argument.

=cut

sub get_reservation_computerloadlog_time {
	my ($reservation_id, $loadstatename, $newest) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	if (!defined($loadstatename)) {
		notify($ERRORS{'WARNING'}, 0, "computerloadstate name argument was not supplied");
		return;
	}
	
	# Get all computerloadlog entries for the reservation
	my @computerloadlog_entries = get_reservation_computerloadlog_entries($reservation_id);
	if (!@computerloadlog_entries) {
		notify($ERRORS{'OK'}, 0, "computerloadlog entry does not exist for reservation $reservation_id");
		return;
	}
	
	my $timestamp;
	for my $computerloadlog_entry (@computerloadlog_entries) {
		if ($computerloadlog_entry->{computerloadstate}{loadstatename} eq $loadstatename) {
			$timestamp = $computerloadlog_entry->{timestamp};
			last unless $newest;
		}
	}
	
	my $type = ($newest ? 'newest' : 'oldest');
	if ($timestamp) {
		my $timestamp_epoch = convert_to_epoch_seconds($timestamp);
		notify($ERRORS{'DEBUG'}, 0, "retrieved $type timestamp of first '$loadstatename' computerloadlog entry for reservation $reservation_id: '$timestamp', returning $timestamp_epoch");
		return $timestamp_epoch;
	}
	else {
		notify($ERRORS{'OK'}, 0, "no '$loadstatename' computerloadlog entries exist for reservation $reservation_id");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_request_loadstate_names

 Parameters  : $request_id
 Returns     : hash reference
 Description : Retrieves the computerloadlog entries for all reservations
               belonging to the request. A hash is constructed with keys set to
               the reservation IDs. The data of each key is a reference to an
               array containing the computerloadstate names. Example:
               {
                 3115 => [
                   "begin",
                 ],
                 3116 => [
                   "begin",
                   "nodeready"
                 ]
               }

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

#//////////////////////////////////////////////////////////////////////////////

=head2 reservation_being_processed

 Parameters  :  reservation ID
 Returns     :  array or boolean
 Description :  Checks the computerloadlog table for rows matching the
                reservation ID and loadstate = begin.

=cut

sub reservation_being_processed {
	my ($reservation_id) = @_;

	# Make sure reservation ID was passed
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not passed");
		return;
	}
	
	my $select_statement = <<EOF;
SELECT
reservation.id AS reservation_id,
computerloadlog.id AS reservation_computerloadlog_id,
MIN(parentreservation.id) AS parent_reservation_id,
parentcomputerloadlog.id AS parent_computerloadlog_id
FROM
reservation
LEFT JOIN (computerloadlog, computerloadstate) ON (
   computerloadlog.reservationid = reservation.id
   AND computerloadlog.loadstateid = computerloadstate.id
   AND computerloadstate.loadstatename = 'begin'
),
request,
reservation parentreservation
LEFT JOIN (computerloadlog parentcomputerloadlog, computerloadstate parentcomputerloadstate) ON (
   parentcomputerloadlog.reservationid = parentreservation.id
   AND parentcomputerloadstate.loadstatename = 'begin'
)
WHERE
reservation.id = $reservation_id
AND reservation.requestid = request.id
AND parentreservation.requestid = request.id
GROUP BY reservation.id
EOF

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @computerloadlog_rows = database_select($select_statement);
	
	# Check if at least 1 row was returned
	my $computerloadlog_exists = 0;
	my $parent_reservation_id;
	my $parent_computerloadlog_exists = 0;
	
	
	for my $row (@computerloadlog_rows) {
		$parent_reservation_id = $row->{parent_reservation_id} if !defined($parent_reservation_id);
		
		my $reservation_computerloadlog_id = $row->{reservation_computerloadlog_id};
		my $parent_computerloadlog_id = $row->{parent_computerloadlog_id};
		
		if ($reservation_computerloadlog_id) {
			$computerloadlog_exists = 1 if (!$computerloadlog_exists);
		}
		if ($parent_computerloadlog_id) {
			$parent_computerloadlog_exists = 1 if (!$parent_computerloadlog_exists);
		}
	}
	
	$parent_reservation_id = '<unknown>' if !defined($parent_reservation_id);
	
	# Check if a vcld process is running matching for this reservation
	my $reservation_process_name_regex = get_reservation_vcld_process_name_regex($reservation_id);
	my @processes_running = is_management_node_process_running($reservation_process_name_regex);
	
	my $info_string = "reservation ID: $reservation_id\n";
	$info_string .= "parent reservation ID: $parent_reservation_id\n";
	$info_string .= "reservation computerloadlog 'begin' entry exists: " . ($computerloadlog_exists ? 'yes' : 'no') . "\n";
	$info_string .= "parent reservation computerloadlog 'begin' entry exists: " . ($parent_computerloadlog_exists ? 'yes' : 'no') . "\n";
	$info_string .= "reservation process running: " . (@processes_running ? (join(", ", @processes_running)) : 'no');
	
	# Check the results and return
	if ($computerloadlog_exists && @processes_running) {
		#notify($ERRORS{'DEBUG'}, 0, "reservation $reservation_id is currently being processed, computerloadlog 'begin' entry exists and running process was found:\n$info_string");
		return (wantarray ? @processes_running : 1);
	}
	elsif (!$computerloadlog_exists && @processes_running) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'begin' entry does NOT exist but running process was found: @processes_running, assuming reservation $reservation_id is currently being processed\n$info_string");
		return (wantarray ? @processes_running : 1);
	}
	elsif ($computerloadlog_exists && !@processes_running) {
		if ($reservation_id eq $parent_reservation_id) {
			#notify($ERRORS{'WARNING'}, 0, "$reservation_id is the parent reservation, computerloadlog 'begin' entry exists but running process was NOT found, assuming reservation $reservation_id is NOT currently being processed\n$info_string");
			return (wantarray ? () : 0);
		}
		else {
			# This is a child reservation, computerloadlog exists, no process running for this reservation
			if ($parent_computerloadlog_exists) {
				notify($ERRORS{'DEBUG'}, 0, "child reservation: $reservation_id, computerloadlog 'begin' entry exists but running process was NOT found, parent reservation $parent_reservation_id computerloadlog entry exists, assuming a process for this reservation already ran and parent reservation process is still running, returning true\n$info_string");
				return (wantarray ? () : 1);
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "child reservation: $reservation_id, computerloadlog 'begin' entry exists but running process was NOT found, parent reservation $parent_reservation_id computerloadlog entry does not exist, assuming this reservation is NOT currently being processed and has not been processed yet, returning false\n$info_string");
				return (wantarray ? () : 0);
			}
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "reservation $reservation_id is NOT currently being processed\n$info_string");
		return (wantarray ? () : 0);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_command

 Parameters  : $command, $no_output (optional), $timeout_seconds (optional)
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
	my ($command, $no_output, $timeout_seconds) = @_;
	
	my @output;
	my $output_string;
	my $exit_status;
	my $timeout_flag = 0;
	
	eval {
		# Override the die and alarm handlers
		local $SIG{__DIE__} = sub{};
		
		local $SIG{__WARN__} = sub {
			my $warning_message = shift || '';
			notify($ERRORS{'WARNING'}, 0, "warning was generated attempting to run command: $warning_message");
		};
		
		local $SIG{ALRM} = sub {
			$timeout_flag = 1;
			die;
		};
		
		if ($timeout_seconds) {
			notify($ERRORS{'DEBUG'}, 0, "waiting up to $timeout_seconds seconds for command to finish: '$command'");
			alarm $timeout_seconds;
		}
		
		$output_string = `$command 2>&1`;
		
		# Save the exit status
		$exit_status = $?;
		if ($exit_status >= 0) {
			$exit_status = $exit_status >> 8;
		}
		
		# Remove any trailing newlines from the output
		chomp $output_string;
		
		# Split the output string into an array of lines
		@output = split(/[\r\n]+/, $output_string);
	};
	
	if ($timeout_flag) {
		notify($ERRORS{'WARNING'}, 0, "command timed out after $timeout_seconds seconds: '$command'");
		kill_child_processes($PID);
		return;
	}
	elsif (!$no_output) {
		notify($ERRORS{'DEBUG'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @output));
	}
	
	return ($exit_status, \@output);
}
	
#//////////////////////////////////////////////////////////////////////////////

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
	my $previous_code = -1;
	my $consecutive_count = 0;
	foreach my $ascii_code (unpack("C*", $string)) {
		if ($ascii_code != 10 && $ascii_code == $previous_code) {
			$consecutive_count++;
			next;
		}
		else {
			if ($consecutive_count > 1) {
				chop $ascii_value_string;
				$ascii_value_string .= "x$consecutive_count]";
			}
			$consecutive_count = 1;
		}
		
		if (my $code = $ascii_codes{$ascii_code}) {
			$ascii_value_string .= "[$code]";
			$ascii_value_string .= "\n" if $ascii_code == 10;
			$previous_code = $ascii_code;
		}
		elsif ($ascii_code > 126) {
			$ascii_value_string .= pack("C*", $ascii_code) . "<$ascii_code>";
			$previous_code = -1;
		}
		else {
			$ascii_value_string .= pack("C*", $ascii_code);
			$previous_code = -1;
		}
	}
	
	if ($consecutive_count > 1) {
		chop $ascii_value_string;
		$ascii_value_string .= "x$consecutive_count]";
	}
	
	if (defined($ascii_value_string)) {
		return $ascii_value_string;
	}
	else {
		return '';
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 character_to_ascii_value

 Parameters  : $character, $numeral_system (optional)
 Returns     : hex number 
 Description : Determines the ASCII value of a given character. A numeral system
               argument may be specified. Valid values are 'decimal', 'hex', or
               'oct'. By default, the decimal value is returned.

=cut

sub character_to_ascii_value {
	my ($character, $numeral_system) = @_;
	if (!defined($character)) {
		notify($ERRORS{'WARNING'}, 0, "character argument was not supplied");
		return;
	}
	elsif (length($character) != 1) {
		notify($ERRORS{'WARNING'}, 0, "length of character argument is not 1: " . length($character));
		return;
	}
	if (defined($numeral_system)) {
		if ($numeral_system =~ /hex/i) {
			$numeral_system = 'hexadecimal';
		}
		elsif ($numeral_system =~ /dec/i) {
			$numeral_system = 'decimal';
		}
		elsif ($numeral_system =~ /oct/i) {
			$numeral_system = 'octal';
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "numeral system specified by the argument is not supported: $numeral_system");
			return;
		}
	}
	else {
		$numeral_system = 'decimal';
	}
	
	if (defined($ENV{ascii_value}{$character}{$numeral_system})) {
		return $ENV{ascii_value}{$character}{$numeral_system};
	}
	
	my $decimal_value = unpack("C*", $character);
	my $values = {
		'decimal' => $decimal_value,
		'hexadecimal' => sprintf("%X", $decimal_value),
		'octal' => sprintf("%o", $decimal_value),
	};
	
	# Store the results in %ENV to avoid repetitive messages in vcld.log
	$ENV{ascii_value}{$character} = $values;
	
	my $string = "ASCII $numeral_system value of '$character': $values->{$numeral_system}";
	if ($numeral_system ne 'decimal') {
		$string .= " (decimal: $values->{decimal})";
	}
	if ($numeral_system ne 'hexadecimal') {
		$string .= " (hexadecimal: $values->{hexadecimal})";
	}
	if ($numeral_system ne 'octal') {
		$string .= " (octal: $values->{octal})";
	}
	
	notify($ERRORS{'DEBUG'}, 0, $string);
	return $values->{$numeral_system};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_imageid_to_newimages

 Parameters  : $ownerid, $resourceid, $virtual
 Returns     : 1, 0 
 Description : Calls the RPC::XML function defined in the arguments

=cut
sub add_imageid_to_newimages {
	my ($user_id, $resource_id, $is_vm_image) = @_;
	
	# Check the arguments
	if (!defined($user_id)) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not specified");
		return;
	}
	elsif (!defined($resource_id)) {
		notify($ERRORS{'WARNING'}, 0, "resource ID argument was not specified");
		return;
	}
	elsif (!defined($is_vm_image)) {
		notify($ERRORS{'WARNING'}, 0, "'is vm image' argument was not specified");
		return;
	}
	
	my $method = "XMLRPCfinishBaseImageCapture";
	my @argument_string = ($method, $user_id, $resource_id, $is_vm_image); 
	my $response = xmlrpc_call(@argument_string);
	
	if (!defined($response)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add image to owner's new images group, XML-RPC $method call failed");
		return;
	}
	elsif (!defined($response->value)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add image to owner's new images group, XML-RPC $method response value is not defined:" . format_data($response));
		return;
	}
	
	my $status = $response->value->{status} || '<undefined>';
	my $error_message = $response->value->{errormsg} || '<undefined>';
	
	if ($status =~ /success/) {
		notify($ERRORS{'OK'}, 0, "added image to owner's new images group, user ID: $user_id, image resource ID: $resource_id, VM image: $is_vm_image");
		return 1;
	}
	
	my ($xmlrpc_username, $xmlrpc_affiliation) = $XMLRPC_USER =~ /^([^@]+)@?(.*)$/;
	my $xmlrpc_user_info = get_user_info($xmlrpc_username, $xmlrpc_affiliation) || {};
	my $xmlrpc_user_id = $xmlrpc_user_info->{id} || '<unknown>';
	
	notify($ERRORS{'WARNING'}, 0, "failed to add image to owner's new images group\n" .
		"make sure the value $xmlrpc_user_id (user ID of $XMLRPC_USER) is included in the \$xmlrpcBlockAPIUsers variable in the VCL website's conf.php file\n" .
		"image owner user ID: $user_id\n" .
		"image resource ID: $resource_id\n" .
		"VM image: $is_vm_image\n" .
		"XML-RPC method: $method\n" .
		"status: $status\n" .
		"error message: $error_message"
	);
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 is_management_node_process_running

 Parameters  : $process_regex
 Returns     : array or hash reference
 Description : Determines if any processes matching the $process_regex
               argument are running on the management node. The $process_regex
               must be a valid Perl regular expression.
               
               The following command is used to determine if a process is
               running:
               ps -e -o pid,args | grep -P "$process_regex"
               
               The behavior is different than if the -P argument is not used.
               The following characters must be escaped with a backslash in
               order for a literal match to be found:
               | ( ) [ ] . +
               
               If these are not escaped, grep will interpret them as the
               corresponing regular expression operational character. For
               example:
               
               To match this literal string:
               |(foo)|
               Pass this:
               \|\(foo\)\|
               
               To match 'foo' or 'bar, pass this:
               (foo|bar)
               
               To match a pipe character ('|'), followed by either 'foo' or
               'bar, followed by another pipe character:
               |foo|
               Pass this:
               \|(foo|bar)\|
               
               The return value differs based on how this subroutine is called.
               If called in scalar context, a hash reference is returned. The
               hash keys are PIDs and the values are the full name of the
               process. If called in list context, an array is returned
               containing the PIDs.

=cut

sub is_management_node_process_running {
	my ($process_regex) = @_;
	
	# Check the arguments
	unless ($process_regex) {
		notify($ERRORS{'WARNING'}, 0, "process regex pattern argument was not specified");
		return;
	}
	
	my $command = "ps -e -o pid,args | grep -P \"$process_regex\"";
	my ($exit_status, $output) = run_command($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine if process is running: $command");
		return;
	}
	
	my $processes_running = {};
	for my $line (@$output) {
		my ($pid, $process_name) = $line =~ /^\s*(\d+)\s*(.*)/g;
		
		if (!defined($pid)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring line, it does not begin with a number: '$line'");
			next;
		}
		elsif ($pid eq $PID) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring line for the currently running process: $line");
			next;
		}
		elsif ($line =~ /grep -P/) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring line containing for this command: $line");
			next;
		}
		elsif ($line =~ /sh -c/) {
			# Ignore lines containing 'sh -c', probably indicating a duplicate process of a command run remotely
			#notify($ERRORS{'DEBUG'}, 0, "ignoring containing 'sh -c': $line");
			next;
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "found matching process: $line");
			$processes_running->{$pid} = $process_name;
		}
	}
	
	my $process_count = scalar(keys %$processes_running);
	if ($process_count) {
		if (wantarray) {
			my @process_ids = sort keys %$processes_running;
			notify($ERRORS{'DEBUG'}, 0, "process is running, identifier: '$process_regex', returning array containing PIDs: @process_ids");
			return @process_ids;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "process is running, identifier: '$process_regex', returning hash reference:\n" . format_data($processes_running));
			return $processes_running;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "process is NOT running, identifier: '$process_regex'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_vcld_process_name_regex

 Parameters  : $reservation_id
 Returns     : string
 Description : Returns a string containing a regular expression which should
               match a single reservation process. This regex is passed to
               is_management_node_process_running.

=cut

sub get_reservation_vcld_process_name_regex {
	my ($reservation_id) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not specified");
		return;
	}
	
	return "$PROCESSNAME .\\|[0-9]+\\|[0-9]+\\|$reservation_id\\|";
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 is_valid_ip_address

 Parameters  : $ip_address, $display_output (optional)
 Returns     : If valid: true
               If not valid: false
 Description : Determines if the argument is a valid IP address.

=cut

sub is_valid_ip_address {
	my ($ip_address, $display_output) = @_;
	if (!$ip_address) {
		notify($ERRORS{'WARNING'}, 0, "IP address argument was not specified");
		return;
	}
	$display_output = 1 unless defined($display_output);
	
	# Split up the IP address being checked into its octets
	my @octets = split(/\./, $ip_address);
	
	# Make sure 4 octets were found
	if (scalar @octets != 4) {
		notify($ERRORS{'DEBUG'}, 0, "IP address does not contain 4 octets: $ip_address, octets:\n" . join("\n", @octets)) if $display_output;
		return 0;
	}
	
	# Make sure address only contains digits
	if (grep(/\D/, @octets)) {
		notify($ERRORS{'DEBUG'}, 0, "IP address contains a non-digit: $ip_address") if $display_output;
		return 0;
	}
	
	# Make sure none of the octets is > 255
	if ($octets[0] > 255 || $octets[0] > 255 || $octets[0] > 255 || $octets[0] > 255) {
		notify($ERRORS{'DEBUG'}, 0, "IP address contains an octet > 255: $ip_address") if $display_output;
		return 0;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "IP address is valid: $ip_address") if $display_output;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
#//////////////////////////////////////////////////////////////////////////////

=head2 get_block_request_image_info

 Parameters  :  computer ID
 Returns     :  imagename imageid imagerevisionid
 Description :  Checks the blockcomputers table matching computer id

=cut
#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_affiliation_info

 Parameters  : $affiliation_identifier (optional)
 Returns     : hash reference
 Description : Returns a hash reference containing information from the
               affiliation table.
               
               If no $affiliation_identifier argument is supplied, a hash
               reference is returned with the hash keys corresponding to the
               affiliation.id values:
                  {
                    1 => {
                      "dataUpdateText" => "",
                      "helpaddress" => "vcl_help\@example.edu",
                      "id" => 1,
                      "name" => "Local",
                      "shibname" => undef,
                      "shibonly" => 0,
                      "sitewwwaddress" => undef,
                      "theme" => "default"
                    },
                    2 => {
                      "dataUpdateText" => "",
                      "helpaddress" => "vcl_help\@example.edu",
                      "id" => 2,
                      "name" => "Global",
                      "shibname" => undef,
                      "shibonly" => 0,
                      "sitewwwaddress" => undef,
                      "theme" => "default"
                    },
                    ...
                  }
               
               If the $affiliation_identifier argument is supplied, a hash
               reference is returned which only contains information for the
               matching affiliation:
                  {
                    "dataUpdateText" => "",
                    "helpaddress" => "vcl_help\@example.edu",
                    "id" => 2,
                    "name" => "Global",
                    "shibname" => undef,
                    "shibonly" => 0,
                    "sitewwwaddress" => undef,
                    "theme" => "default"
                  }

=cut

sub get_affiliation_info {
	my ($affiliation_identifier) = @_;
	
	# Create the select statement
	my $select_statement = <<EOF;
SELECT
*
FROM
affiliation
EOF
	
	# Append a WHERE clause if a affiliation identifier argument was supplied
	if ($affiliation_identifier && $affiliation_identifier =~ /^\d+$/) {
		$select_statement .= "WHERE id = $affiliation_identifier";
	}
	elsif ($affiliation_identifier) {
		$select_statement .= "WHERE name = '$affiliation_identifier'";
	}

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure rows were returned
	if (!@selected_rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve rows from affiliation table");
		return;
	}
	
	# Transform the array of database rows into a hash
	my $affiliation_info = {};
	for my $row (@selected_rows) {
		my $affiliation_id = $row->{id};
		
		for my $key (keys %$row) {
			my $value = $row->{$key};
			$affiliation_info->{$affiliation_id}{$key} = $value;
		}
	}
	
	if ($affiliation_identifier) {
		my $affiliation_id = (keys %$affiliation_info)[0];
		$affiliation_info = $affiliation_info->{$affiliation_id};
		notify($ERRORS{'DEBUG'}, 0, "retrieved info for affiliation $affiliation_identifier:\n" . format_data($affiliation_info));
		return $affiliation_info;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved affiliation info:\n" . format_data($affiliation_info));
		return $affiliation_info;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_copy_speed_info_string

 Parameters  : $copied_bytes, $duration_seconds
 Returns     : string
 Description : Calculates various copy rates based on the amount of data copied
               and time the copy took.

=cut

sub get_copy_speed_info_string {
	my ($copied_bytes, $duration_seconds) = @_;
	
	# Avoid divide by zero errors
	if ($duration_seconds == 0) {
		$duration_seconds = 1;
	}

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu_choice

 Parameters  : $subref_hashref
 Returns     : subroutine reference
 Description : Accepts a hash reference which defines a 'vcld -setup' menu
               structure. The hash keys are the names of menu categories or menu
               items.
               
               If a hash key is the name of a menu category, its value must be a
               hash reference.
               
               If a hash key is the name of a menu item, its value must be a
               subroutine reference.

=cut

sub setup_get_menu_choice {
	my ($menu, $choices, $parent_menu_names) = @_;

	# Initialize the $choices array reference
	if (!$choices) {
		$choices = [];
	}
	
	if (!$parent_menu_names) {
		$parent_menu_names = [];
	}
	
	my $level = scalar(@$parent_menu_names);
	
	for my $name (sort keys %$menu) {
		my $value = $menu->{$name};
		my $type = ref($value);
		
		if ($type eq 'CODE') {
			push @$choices, { name => $name, sub_ref => $value, parent_menu_names => $parent_menu_names};
			
			print ' ' x ($level*3);
			print scalar(@$choices) . ": $name\n";
		}
		elsif ($type eq 'HASH') {
			print "\n" if ($level == 0 && scalar(@$choices) > 0);
			print ' ' x ($level*3);
			print "$name\n";
			
			# Recursively call this subroutine to add nested menu to choices
			setup_get_menu_choice($value, $choices, [@$parent_menu_names, $name]);
		}
	}
	
	# Check if this is a recursive call
	my $calling_subroutine = get_calling_subroutine();
	if ($calling_subroutine =~ /setup_get_menu_choice/) {
		return;
	}
	
	my $choice_index = setup_get_choice(scalar(@$choices));
	return if (!defined($choice_index));
	return @$choices[$choice_index];
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_hash_choice

 Parameters  : $hash_ref, $display_key1 (optional), $display_key2 (optional)
 Returns     : $choice_name
 Description : Prompts the user to select an element from the hash. By default,
               the choices displayed are the top-level hash key values. If
               $hash_ref is a hash of hashes, the menu choices displayed may be
               the value of child hash values if $display_key1 is provided. If
               $display_key2 is provided, the choices will be a concatenation of
               2 child hash values.

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
			if ($display_key2 =~ /^([^-]+)-([^-]+)$/) {
				$display_name .= " (" . $hash_ref->{$key}{$1}{$2} . ")";
			}
			else {
				my $display_key2_value = $hash_ref->{$key}{$display_key2};
				if (defined($display_key2_value) && length($display_key2_value) > 0) {
					$display_name .= " (" . $hash_ref->{$key}{$display_key2} . ")";
				}
			}
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

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_hash_multiple_choice

 Parameters  : $hash_ref, $argument_hash_ref (optional)
 Returns     : $hash_key
 Description : Given a hash reference structure, constructs a menu and retrieves
               user input.
               
               An optional hash reference can be supplied containing information
               to control how the menu is displayed. The hash may contain the
               following keys:
               * title - A string which will be displayed above the menu.
               * display_keys - An array reference containing strings. Each
                 array element may be a string enclosed in curly brackets. This
                 allows the menu items to be composed from any data elements
                 contained within the hash reference.
               
               Example:
               {
                  'title' => "Select VMs to be migrated off of $source_vmhost_computer_name",
                  'display_keys' => ['{SHORTNAME}', ' - ', '{currentimagerevision}{imagename}'],
               }
               
               This would result in menu entry names being assembled from:
               $hash_ref->{SHORTNAME} - $hash_ref->{currentimagerevision}{imagename}

=cut

sub setup_get_hash_multiple_choice {
	my $hash_ref = shift;
	if (!defined($hash_ref)) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not supplied");
		return;
	}
	elsif (!ref($hash_ref)) {
		notify($ERRORS{'WARNING'}, 0, "1st argument is not a reference, it must be a hash reference:\n$hash_ref");
		return;
	}
	elsif (ref($hash_ref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "1st argument is a " . ref($hash_ref) . " reference, it must be a hash reference:\n" . format_data($hash_ref));
		return;
	}
	
	my $arguments = shift;
	if (defined($arguments)) {
		if (!ref($arguments)) {
			notify($ERRORS{'WARNING'}, 0, "2nd argument is not a reference, it must be a hash reference:\n$arguments");
			return;
		}
		elsif (ref($arguments) ne 'HASH') {
			notify($ERRORS{'WARNING'}, 0, "2nd argument is a " . ref($arguments) . " reference, it must be a hash reference:\n" . format_data($arguments));
			return;
		}
	}
	else {
		$arguments = {};
	}
	
	my $title = $arguments->{title};
	my @display_keys = (defined($arguments->{display_keys}) ? @{$arguments->{display_keys}} : ());
	
	my $entry_hash = {};
	my $max_entry_length = 0;
	for my $key (sort keys %$hash_ref) {
		my $entry_display_name;
		
		for my $display_key (@display_keys) {
			if ($display_key =~ /^{.+}$/) {
				my $hash_path = "\$hash_ref->{$key}$display_key";
				notify($ERRORS{'DEBUG'}, 0, "retrieving hash value: $hash_path");
				my $value = eval $hash_path;
				if ($EVAL_ERROR) {
					notify($ERRORS{'WARNING'}, 0, "error encountered evaluating hash path: '$hash_path'\n$EVAL_ERROR");
					return;
				}
				elsif (!defined($value)) {
					notify($ERRORS{'WARNING'}, 0, "unable to determine entry display name, hash does not contain key: '$hash_path'\," . format_data($hash_ref->{$key}));
					return;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "retrieved entry display name component: $hash_path = '$value'");
					$entry_display_name .= $value;
				}
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "adding text to entry display name: '$display_key'");
				$entry_display_name .= $display_key;
			}
		}
		
		if (defined($entry_display_name) && defined($entry_hash->{$entry_display_name})) {
			notify($ERRORS{'WARNING'}, 0, "duplicate entry display names: '$entry_display_name', appending hash key: '$entry_display_name {$key}'");
			$entry_display_name = "$entry_display_name {$key}";
		}
		elsif (!defined($entry_display_name)) {
			$entry_display_name = $key;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "choice entry name for hash key $key: '$entry_display_name'");
		}
		
		$entry_hash->{$entry_display_name}{key} = $key;
		$entry_hash->{$entry_display_name}{selected} = 0;
		$entry_hash->{$entry_display_name}{entry_display_name} = $entry_display_name;
		
		my $entry_display_name_length = length($entry_display_name);
		$max_entry_length = $entry_display_name_length if ($entry_display_name_length > $max_entry_length);
	}
	
	my $entry_index_hash = {};
	my $i = 1;
	for my $entry_display_name (sort keys %$entry_hash) {
		$entry_index_hash->{$i} = $entry_hash->{$entry_display_name};
		$entry_index_hash->{$i}{entry_index} = $i;
		$i++;
	}

	my $entry_count = scalar(keys %$entry_hash);
	my $entry_count_length = length($entry_count);
	my $no_print_entries = 0;
	
	# Adjust $max_entry_length to include:
	# [_]_x._
	$max_entry_length = $max_entry_length + 6 + $entry_count_length;
	
	while (1) {
		print "\n";
		if (defined($title)) {
			my $title_length = length($title);
			my $title_pad_string = '';
			if ($max_entry_length > $title_length) {
				$title_pad_string = ' ' x ($max_entry_length - $title_length);
			}
			print colored("$title$title_pad_string", 'BOLD UNDERLINE');
			print "\n";
		}
		my $selection_made = 0;
		#if (!$no_print_entries) {
			for my $entry_index (sort {$a<=>$b} keys %$entry_index_hash) {
				my $entry_display_name = $entry_index_hash->{$entry_index}{entry_display_name};
				my $selected = $entry_index_hash->{$entry_index}{selected};
				$selection_made = 1 if $selected;
				
				my $selection_string = '[';
				if ($selected) {
					$selection_string .= '*';
				}
				else {
					$selection_string .= ' ';
				}
				$selection_string .= '] ';
				
				my $entry_index_length = length($entry_index);
				my $entry_pad_length = ($entry_count_length - $entry_index_length);
				my $entry_pad_string = ' ' x $entry_pad_length;
				
				$selection_string .= "$entry_index. $entry_pad_string";
				$selection_string .= "$entry_display_name";
				if ($selected) {
					print colored($selection_string, 'BOLD');
				}
				else {
					print $selection_string;
				}
				print "\n";
			}
		#}
		
		#print "\n[" . join("/", @{$ENV{setup_path}}) . "]\n" if defined($ENV{setup_path});
		my $option_pad_string = ' ' x ($entry_count_length - 1);
		
		print "\n";
		print "[1";
		print "-$entry_count" if ($entry_count > 1);
		print "] - toggle selection (multiple may be entered)\n";
		print "  $option_pad_string\[a] - select all\n";
		print "  $option_pad_string\[n] - select none\n";
		print "  $option_pad_string\[i] - invert selected\n";
		print "  $option_pad_string\[d] - done making selections\n";
		print "  $option_pad_string\[c] - cancel\n";
		print "Make a selection";
		print " [d]" if $selection_made;
		print ": ";
		my $choice = <STDIN>;
		chomp $choice;
		
		$no_print_entries = 0;
		
		if ($choice =~ /^c$/i) {
			return;
		}
		elsif ($choice =~ /^d$/i || $selection_made && !length($choice)) {
			last;
		}
		elsif ($choice =~ /^a$/i) {
			for my $entry_index (keys %$entry_index_hash) {
				$entry_index_hash->{$entry_index}{selected} = 1;
			}
			next;
		}
		elsif ($choice =~ /^n$/i) {
			for my $entry_index (keys %$entry_index_hash) {
				$entry_index_hash->{$entry_index}{selected} = 0;
			}
			next;
		}
		elsif ($choice =~ /^i$/i) {
			for my $entry_index (keys %$entry_index_hash) {
				$entry_index_hash->{$entry_index}{selected} = !$entry_index_hash->{$entry_index}{selected};
			}
			next;
		}
		else {
			my @selected_entry_indexes = split(/[\s,]+/, $choice);
			for my $selected_entry_index (@selected_entry_indexes) {
				if ($selected_entry_index =~ /^(\d+)-(\d+)$/) {
					my $start_index = $1;
					my $end_index = $2;
					if ($start_index < 1 || $start_index > $entry_count) {
						print colored("*** Choice ignored: $selected_entry_index, starting index must be an integer between 1 and $entry_count ***", 'YELLOW ON_RED');
						print "\n";
						$no_print_entries = 1;
						next;
					}
					elsif ($end_index < $start_index || $end_index > $entry_count) {
						print colored("*** Choice ignored: $selected_entry_index, ending index must be an integer between " . ($start_index+1) . " and $entry_count ***", 'YELLOW ON_RED');
						print "\n";
						$no_print_entries = 1;
						next;
					}
					else {
						for (my $index = $start_index; $index <= $end_index; $index++) {
							$entry_index_hash->{$index}{selected} = !$entry_index_hash->{$index}{selected};
						}
					}
				}
				elsif ($selected_entry_index !~ /^\d+$/ || $selected_entry_index < 1 || $selected_entry_index > $entry_count) {
					print colored("*** Choice ignored: $selected_entry_index, it must be an integer between 1 and $entry_count ***", 'YELLOW ON_RED');
					print "\n";
					$no_print_entries = 1;
					next;
				}
				else {
					$entry_index_hash->{$selected_entry_index}{selected} = !$entry_index_hash->{$selected_entry_index}{selected};
				}
			}
		}
	}
	
	my @selected_keys;
	for my $entry_index (sort {$a<=>$b} keys %$entry_index_hash) {
		if ($entry_index_hash->{$entry_index}{selected}) {
			push @selected_keys, $entry_index_hash->{$entry_index}{key};
		}
	}
	
	return @selected_keys;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_array_choice

 Parameters  : @choices
 Returns     : integer
 Description : Lists the elements in the @choices argument as a menu and accepts
               user input to select one of the elements. The array index
               corresponding to the user's choice is returned.

=cut

sub setup_get_array_choice {
	my (@choices) = @_;
	
	if (@choices) {
		notify($ERRORS{'DEBUG'}, 0, "choices argument:\n" . join("\n", @choices));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "choices argument was either not supplied or is emptry");
		return;
	}
	
	my $choice_count = scalar(@choices);
	my $choice_count_length = length($choice_count);
	
	while (1) {
		for (my $i=1; $i<=$choice_count; $i++) {
			my $choice_length = length($i);
			my $pad = ($choice_count_length - $choice_length);
			print "$i. ";
			print " " x $pad;
			print "$choices[$i-1]\n";
		}
		
		print "\n[" . join("/", @{$ENV{setup_path}}) . "]\n" if defined($ENV{setup_path});
		print "Make a selection (1";
		print "-$choice_count" if ($choice_count > 1);
		print ", 'c' to cancel or when done): ";
		
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

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_choice

 Parameters  : $choice_count
 Returns     : integer
 Description : Presents the 'Make a selection' prompt to the user loops until a
               valid choice is entered.

=cut

sub setup_get_choice {
	my ($choice_count) = @_;
	
	print "\n[" . join("/", @{$ENV{setup_path}}) . "]\n" if defined($ENV{setup_path});
	while (1) {
		print "Make a selection (1";
		print "-$choice_count" if ($choice_count > 1);
		print ", 'c' to cancel): ";
		
		my $choice = <STDIN>;
		if (!defined($choice)) {
			return;
		}
		
		chomp $choice;
		
		if ($choice =~ /^c$/i) {
			return;
		}
		if ($choice !~ /^\d+$/ || $choice < 1 || $choice > $choice_count) {
			print "*** Choice must be an integer between 1 and $choice_count ***\n";
		}
		else {
			return ($choice - 1);
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_input_string

 Parameters  : $message, $default_value (optional)
 Returns     : string
 Description : Prompts the user to enter a string.

=cut

sub setup_get_input_string {
	my ($message, $default_value) = @_;
	
	if ($message !~ /\n$/) {
		$message =~ s/\s+$//g;
		$message .= " ";
	}
	$message .= "('c' to cancel)";
	
	if ($default_value) {
		setup_print_wrap("$message [$default_value]: ", 0, 1);
	}
	else {
		setup_print_wrap("$message: ", 0, 1);
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

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_input_file_path

 Parameters  : $message, $default_value (optional)
 Returns     : string
 Description : Prompts the user to enter a file path.

=cut

sub setup_get_input_file_path {
	my ($message, $default_value) = @_;
	
	# Check if a Term::ReadLine object has already been created
	my $term;
	if (defined($ENV{term_readline})) {
		$term = $ENV{term_readline};
	}
	else {
		$term = Term::ReadLine->new('ReadLine');
		if (!$term) {
			notify($ERRORS{'WARNING'}, 0, "failed to create Term::ReadLine object");
			return setup_get_input_string($message, $default_value);
		}
		$term->ornaments(0);
		
		my $attribs = $term->Attribs;
		if ($term->ReadLine =~ /Perl/) {
			$attribs->{completion_function} = \&_term_readline_complete_file_path;
		}
		
		$ENV{term_readline} = $term;
	}
	
	$message = '' unless $message;
	
	my $trailing_newline = 0;
	if ($message =~ /\n$/) {
		$trailing_newline = 1;
	}
	$message =~ s/[\s\n]*$//g;
	
	if ($message) {
		$message .= " ";
	}
	$message .= "('c' to cancel)";
	
	if ($trailing_newline) {
		$message .= "\n";
	}
	if ($default_value) {
		$message .=  "[$default_value]";
	}
	print "$message";
	
	my $input = $term->readline(": ");
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

#//////////////////////////////////////////////////////////////////////////////

=head2 _term_readline_complete_file_path

 Parameters  : $text
 Returns     : @files
 Description : 

=cut

sub _term_readline_complete_file_path {
	my ($text) = @_;
	my @files = glob "$text*";
	
	my @return_files;
	for my $file (@files) {
		if (-d $file) {
			$file .= '/';
		}
		
		push @return_files, $file;
	}
	
	# Do this twice to avoid "used only once" warning
	$readline::rl_completer_terminator_character = '';
	$readline::rl_completer_terminator_character = '';
	
	return @return_files;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_confirm

 Parameters  : $message, $default_value (optional)
 Returns     : boolean
 Description : Displays the message to the user and loops until they enter Y or
               N.

=cut

sub setup_confirm {
	my ($message, $default_value) = @_;
	if (defined($message)) {
		$message =~ s/\s*$//g;
		$message .= ' ';
	}
	else {
		$message = '';
	}
	$message .= '(y/n)';
	
	my $default_yes = 0;
	my $default_no = 0;
	if (defined($default_value)) {
		if ($default_value =~ /^y$/i) {
			$message .= '[y]';
			$default_yes = 1;
		}
		elsif ($default_value =~ /^n$/i) {
			$message .= '[n]';
			$default_no = 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "default value is not valid: '$default_value', it must be either 'y' or 'n'");
		}
	}
	
	while (1) {
		setup_print_wrap("$message? ");
		my $input = <STDIN>;
		$input =~ s/[\s\r\n]+$//g;
		
		if ((length($input) == 0 && $default_yes) || $input =~ /^y(es)?$/i) {
			return 1;
		}
		elsif ((length($input) == 0 && $default_no) || $input =~ /^n(o)?$/i) {
			return 0;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_print_break

 Parameters  : $character (optional), $columns (optional)
 Returns     : true
 Description : Prints a horizontal line to stdout. Used to format the output
               from 'vcld -setup'.

=cut

sub setup_print_break {
	my $character = shift || '-';
	my $columns = shift || 100;
	$character =~ s/^(.).*/$1/;
	print $character x $columns . "\n";
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_print_wrap

 Parameters  : $message, $columns (optional), $no_trailing_newline (optional)
 Returns     : true
 Description : Prints a message to STDOUT formatted to the column width. 100 is
               the default column value.

=cut

sub setup_print_wrap {
	my $message = shift || return;
	my $columns = shift || 100;
	my $no_trailing_newline = shift;
	
	# Save the leading and trailing lines then remove them from the string
	# This is done so wrap doesn't lose them
	my ($leading_newlines) = $message =~ /^(\n+)/;
	$message =~ s/^\n+//g;
	my ($trailing_newlines) = $message =~ /(\n+)$/;
	$message =~ s/\n+$//g;
	
	$| = 1;
	
	# Wrap text for lines
	local($Text::Wrap::columns) = $columns;
	print $leading_newlines if $leading_newlines;
	print wrap('', '', $message);
	if ($trailing_newlines) {
		print $trailing_newlines;
	}
	elsif (!$no_trailing_newline) {
		print "\n";
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_print_ok

 Parameters  : $message
 Returns     : true
 Description : 

=cut

sub setup_print_ok {
	my ($message) = @_;
	return unless defined($message);
	$message =~ s/[\s\n]+$//g;
	
	my $prefix = 'OK';
	print colored(" $prefix ", "BOLD WHITE ON_GREEN");
	print " ";
	setup_print_wrap($message, (100-length($prefix)-2));
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_print_error

 Parameters  : $message
 Returns     : true
 Description : 

=cut

sub setup_print_error {
	my ($message) = @_;
	return unless defined($message);
	$message =~ s/[\s\n]+$//g;
	
	#print get_caller_trace() . "\n\n";
	
	my $prefix = 'ERROR';
	print colored(" $prefix ", "BOLD WHITE ON_RED");
	print " ";
	setup_print_wrap($message, (100-length($prefix)-2));
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_print_warning

 Parameters  : $message
 Returns     : true
 Description : 

=cut

sub setup_print_warning {
	my ($message) = @_;
	return unless defined($message);
	$message =~ s/[\s\n]+$//g;
	
	my $prefix = 'WARNING';
	print colored(" $prefix ", "BLACK ON_YELLOW");
	print " ";
	setup_print_wrap($message, (100-length($prefix)-2));
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 kill_child_processes

 Parameters  : $parent_pid
 Returns     : boolean
 Description : Kills all child processes belonging to the parent PID specified
               as the argument.

=cut

sub kill_child_processes {
	my @parent_pids = @_;
	if (!@parent_pids) {
		notify($ERRORS{'WARNING'}, 0, "parent PID argument not supplied");
		return;
	}
	
	my $parent_pid = $parent_pids[-1];
	my $parent_process_string = "parent PID: " . join(" > ", @parent_pids);
	
	# Make sure the parent vcld daemon process didn't call this subroutine for safety
	# Prevents all reservations being processed from being killed
	if ($ENV{vcld}) {
		notify($ERRORS{'CRITICAL'}, 0, "kill_child_processes subroutine called from the parent vcld process, not killing any processes for safety");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$parent_process_string: attempting to kill child processes");
	
	my $command = "ps -h --ppid $parent_pid -o pid,ppid,args | sort -r";
	my ($exit_status, $output) = run_command($command, 1);
	for my $line (@$output) {
		# Make sure the line only contains a PID
		my ($child_pid, $parent_pid, $child_command) = $line =~ /^\s*(\d+)\s+(\d+)\s+(.*)/;
		if (!defined($child_pid)) {
			notify($ERRORS{'WARNING'}, 0, "$parent_process_string: output line does not contain a PID:\nline: '$line'");
			next;
		}
		elsif ($child_command =~ /$command/) {
			# Ignore the pgrep command called to determine child processes
			notify($ERRORS{'DEBUG'}, 0, "ignoring process created by this subroutine: '$line'");
			next;
		}
		elsif ($child_command =~ /ssh -e none/) {
			# Ignore SSH sessions created for execute_new
			notify($ERRORS{'DEBUG'}, 0, "ignoring persistent SSH process: '$line'");
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "$parent_process_string, found child process: '$line'");
		
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_connect_method_info

 Parameters  : $imagerevision_id, $no_cache (optional)
 Returns     : hash reference
 Description : Returns the connect methods for the reservation. Example:
               {
                4 => {
                  "RETRIEVAL_TIME" => "1417709281",
                  "connectmethodmap" => {
                    "OSid" => 36,
                    "OStypeid" => undef,
                    "autoprovisioned" => undef,
                    "connectmethodid" => 4,
                    "disabled" => 0,
                    "imagerevisionid" => undef
                  },
                  "connectmethodport" => {
                    35 => {
                      "connectmethodid" => 4,
                      "id" => 35,
                      "natport" => {
                        "connectmethodportid" => 35,
                        "nathostid" => 2,
                        "publicport" => 56305,
                        "reservationid" => 3115
                      },
                      "port" => 3389,
                      "protocol" => "TCP"
                    },
                    37 => {
                      "connectmethodid" => 4,
                      "id" => 37,
                      "natport" => {
                        "connectmethodportid" => 37,
                        "nathostid" => 2,
                        "publicport" => 63058,
                        "reservationid" => 3115
                      },
                      "port" => 3389,
                      "protocol" => "UDP"
                    }
                  },
                  "description" => "Linux xRDP (Remote Desktop Protocol)",
                  "id" => 4,
                  "name" => "xRDP",
                  "servicename" => "xrdp",
                  "startupscript" => undef
                }
              }

=cut

sub get_reservation_connect_method_info {
	my ($reservation_id, $no_cache) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	# Check if cached info exists
	if (!$no_cache && defined($ENV{connect_method_info}{$reservation_id})) {
		my $connect_method_id = (keys(%{$ENV{connect_method_info}{$reservation_id}}))[0];
		if ($connect_method_id) {
			# Check the time the info was last retrieved
			my $data_age_seconds = (time - $ENV{connect_method_info}{$reservation_id}{$connect_method_id}{RETRIEVAL_TIME});
			if ($data_age_seconds < 600) {
				return $ENV{connect_method_info}{$reservation_id};
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "retrieving current connect method info for reservation $reservation_id from database, cached data is stale: $data_age_seconds seconds old");
			}
		}
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'connectmethod',
		'connectmethodport',
		'connectmethodmap',
		'natport',
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

reservation
LEFT JOIN image ON (image.id = reservation.imageid)
LEFT JOIN OS ON (OS.id = image.OSid)
LEFT JOIN OStype ON (OStype.name = OS.type),

connectmethodport
LEFT JOIN natport ON (natport.connectmethodportid = connectmethodport.id AND natport.reservationid = $reservation_id)

WHERE
reservation.id = $reservation_id
AND connectmethodport.connectmethodid = connectmethod.id
AND connectmethodmap.connectmethodid = connectmethod.id
AND connectmethodmap.autoprovisioned IS NULL
AND (
	connectmethodmap.OStypeid = OStype.id
	OR connectmethodmap.OSid = OS.id 
	OR connectmethodmap.imagerevisionid = reservation.imagerevisionid
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
		my $connectmethod_id = $row->{'connectmethod-id'};
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			next if $key eq 'connectmethod-connecttext';
			
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			if ($table eq 'connectmethod') {
				$connect_method_info->{$connectmethod_id}{$column} = $value;
			}
			elsif ($table eq 'connectmethodport') {
				my $connectmethodport_id = $row->{"connectmethodport-id"};
				$connect_method_info->{$connectmethod_id}{'connectmethodport'}{$connectmethodport_id}{$column} = $value;
			}
			elsif ($table eq 'natport') {
				if (defined($value)) {
					my $connectmethodport_id = $row->{"connectmethodport-id"};
					$connect_method_info->{$connectmethod_id}{'connectmethodport'}{$connectmethodport_id}{'natport'}{$column} = $value;
				}
			}
			else {
				$connect_method_info->{$connectmethod_id}{$table}{$column} = $value;
			}
		}
		$connect_method_info->{$connectmethod_id}{RETRIEVAL_TIME} = $timestamp;
	}

	notify($ERRORS{'DEBUG'}, 0, "retrieved connect method info for reservation $reservation_id:\n" . format_data($connect_method_info));
	$ENV{connect_method_info}{$reservation_id} = $connect_method_info;
	return $ENV{connect_method_info}{$reservation_id};
}

#//////////////////////////////////////////////////////////////////////////////

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
		$mac_address .= ":" . sprintf("%02X",int(rand(256)));
	}
	
	notify($ERRORS{'DEBUG'}, 0, "generated random MAC address: '$mac_address'");
	return $mac_address;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 xml_string_to_hash

 Parameters  : $xml_text, $force_array (optional)
 Returns     : hash reference
 Description : Converts XML text to a hash using XML::Simple:XMLin. The argument
               may be a string of XML text or array reference of lines of XML
               text.

=cut

sub xml_string_to_hash {
	my @arguments = @_;
	if (!@arguments) {
		notify($ERRORS{'WARNING'}, 0, "XML text argument was not specified");
		return;
	}
	
	my ($xml_text, $force_array) = @_;
	my $type = ref($xml_text);
	if ($type) {
		if ($type eq 'ARRAY') {
			$xml_text = join("\n", @$xml_text);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "invalid argument type: $type");
			return;
		}
	}
	
	$force_array = 1 if !defined $force_array;
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Convert the XML to a hash using XML::Simple
	my $xml_hashref;
	eval {
		$xml_hashref = XMLin($xml_text, 'ForceArray' => $force_array, 'KeyAttr' => []);
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_contents_no_data_structure

 Parameters  : node name
 Returns     : array
 Description : returns contents of currentimage.txt for given node

=cut

sub get_current_image_contents_no_data_structure {

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

#//////////////////////////////////////////////////////////////////////////////

=head2 is_ip_assigned_query

  Parameters  : IP address
  Returns     : boolean
  Description : checks if IP address exists in db

=cut

sub is_ip_assigned_query {
	
	my ($ip_address) = @_;

   if (!defined($ip_address)) {
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
computer.IPaddress = '$ip_address' AND
computer.stateid = state.id AND
state.name != 'deleted' AND
computer.vmhostid IS NOT NULL
EOF

   # Call the database select subroutine
   my @selected_rows = database_select($select_statement);

   # Check to make sure 1 row was returned
   if (scalar @selected_rows == 0) {
      notify($ERRORS{'OK'}, 0, "zero rows were returned from database select statement $ip_address is available");
      return 0;
   }
	elsif (scalar @selected_rows >= 1) {
      notify($ERRORS{'OK'}, 0, scalar @selected_rows . " rows were returned from database select statement: $ip_address is assigned");
      return 1;
   }

	return 1;	
		
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_computer_ids

 Parameters  : $management_node_identifier
 Returns     : hash reference
 Description : Retrieves a list of all computer IDs a particular management node
               controls.

=cut

sub get_management_node_computer_ids {
	my $management_node_identifier = shift || get_management_node_id{};
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_vmhost_ids

 Parameters  : $management_node_identifier (optional)
 Returns     : array
 Description : Returns a list of all VM host IDs controlled by a particular
               management node. This list will include any VM host computers
               mapped to the management node as well as VM host computers which
               are assigned a VM which is mapped to the management node.

=cut

sub get_management_node_vmhost_ids {
	my $management_node_identifier = shift || $FQDN;
	
	if ($ENV{management_node_vmhost_ids}{$management_node_identifier}) {
		notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved vmhost IDs assigned to management node: $management_node_identifier");
		return @{$ENV{management_node_vmhost_ids}{$management_node_identifier}};
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieving vmhost IDs assigned to management node: $management_node_identifier");
	
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
computer host,
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
host.deleted = 0 AND

computer.id = comp_resource.subid AND
comp_resource.id = comp_resourceourcegroupmembers.resourceid AND
comp_resourceourcegroupmembers.resourcegroupid = comp_resourcegroup.id AND
resourcemap.resourcegroupid1 = mn_resourcegroup.id AND
resourcemap.resourcegroupid2 = comp_resourcegroup.id

AND (
	(
		computer.type = 'virtualmachine' AND
		computer.vmhostid = vmhost.id
	)
	OR
	(
		computer.type = 'blade' AND
		vmhost.computerid = computer.id
	)
)
AND vmhost.computerid = host.id
EOF
	
	if ($management_node_identifier =~ /^\d+$/) {
		$select_statement .= "AND mn.id = $management_node_identifier";
	}
	else {
		$select_statement .= "AND mn.hostname = '$management_node_identifier'";
	}
	my @selected_rows = database_select($select_statement);
	
	my @vmhost_ids = map { $_->{id} } @selected_rows;
	
	notify($ERRORS{'DEBUG'}, 0, "vmhost IDs assigned to $management_node_identifier (" . scalar(@vmhost_ids) . "): " . join(', ', @vmhost_ids));
	$ENV{management_node_vmhost_ids}{$management_node_identifier} = \@vmhost_ids;
	return @{$ENV{management_node_vmhost_ids}{$management_node_identifier}};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_vmhost_info

 Parameters  : $management_node_identifier (optional)
 Returns     : hash
 Description : Retrieves information for all VM hosts assigned to a management
               node. The hash keys are vmhost.id values.

=cut

sub get_management_node_vmhost_info {
	my $management_node_identifier = shift || $FQDN;
	return $ENV{management_node_vmhost_info}{$management_node_identifier} if $ENV{management_node_vmhost_info}{$management_node_identifier};
	
	my @management_node_vmhost_ids = get_management_node_vmhost_ids($management_node_identifier);
	
	my $vmhost_info = {};
	for my $vmhost_id (@management_node_vmhost_ids) {
		$vmhost_info->{$vmhost_id} = get_vmhost_info($vmhost_id);
		$vmhost_info->{$vmhost_id}{hostname} = $vmhost_info->{$vmhost_id}{computer}{hostname};
		$vmhost_info->{$vmhost_id}{vmprofile_profilename} = $vmhost_info->{$vmhost_id}{vmprofile}{profilename};
	}
	
	$ENV{management_node_vmhost_info}{$management_node_identifier} = $vmhost_info;
	return $ENV{management_node_vmhost_info}{$management_node_identifier};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_assigned_vm_info

 Parameters  : $vmhost_id, $no_cache (optional)
 Returns     : hash reference
 Description : Returns a hash reference containing all of the computer IDs
               assigned to a VM host.

=cut

sub get_vmhost_assigned_vm_info {
	my ($vmhost_id, $no_cache) = @_;
	if (!$vmhost_id) {
		notify($ERRORS{'WARNING'}, 0, "VM host ID argument was not supplied");
		return;
	}
	
	if (!$no_cache && defined($ENV{vmhost_assigned_vm_info}{$vmhost_id})) {
		return $ENV{vmhost_assigned_vm_info}{$vmhost_id};
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
		$assigned_computer_info->{$computer_id} = $computer_info if $computer_info;
	}
	
	$ENV{vmhost_assigned_vm_info}{$vmhost_id} = $assigned_computer_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved computer info for VMs assigned to VM host $vmhost_id: " . join(', ', sort keys %$assigned_computer_info));
	return $assigned_computer_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_vmhost_assigned_vm_provisioning_info

 Parameters  : $vmhost_identifier, $no_cache (optional)
 Returns     : hash reference
 Description : For a given vmhost entry, retrieves the provisioning ID for all
               of the computers assigned to the VM host. This information can be
               used to attempt to determine which provisioning module should be
               used to control the VM host.
               
               There is currently no deterministic way to tie a VM host to a
               provisioning table type. It's possible to assign VMs with
               different computer.provisioningid values to the same VM host.
               This is usually done by mistake.
               
               This subroutine constructs a hash refererence with keys
               corresponding to provisioning.id values. Each key contains the
               provisioning table information.
               
               An 'ASSIGNED_COMPUTER_IDS' key is added containing a hash
               reference. The keys of this hash correspond to computer.id values
               of VMs assigned to the host with the corresponding
               computer.provisioningid value. An 'ASSIGNED_COMPUTER_COUNT' key
               is added containing the number of VMs.
               
               Example where VM host has multiple VM provisioning types
               assigned:
               
                  {
                    14 => {
                      "ASSIGNED_VM_COUNT" => 1,
                      "id" => 14,
                      "module" => {
                        "description" => "",
                        "id" => 33,
                        "name" => "provisioning_libvirt",
                        "perlpackage" => "VCL::Module::Provisioning::libvirt",
                        "prettyname" => "Libvirt Provisioning"
                      },
                      "moduleid" => 33,
                      "name" => "libvirt",
                      "prettyname" => "Libvirt"
                    },
                    8 => {
                      "ASSIGNED_VM_COUNT" => 27,
                      "id" => 8,
                      "module" => {
                        "description" => "",
                        "id" => 21,
                        "name" => "provisioning_vmware_vsphere",
                        "perlpackage" => "VCL::Module::Provisioning::VMware::VMware",
                        "prettyname" => "VMware Provisioning Module"
                      },
                      "moduleid" => 21,
                      "name" => "vmware",
                      "prettyname" => "VMware Server 2.x and ESX/ESXi"
                    }
                  }

=cut


sub get_vmhost_assigned_vm_provisioning_info {
	my ($vmhost_id, $no_cache) = @_;
	
	# Check the passed parameter
	if (!defined($vmhost_id)) {
		notify($ERRORS{'WARNING'}, 0, "VM host ID argument was not specified");
		return;
	}
	
	if (!$no_cache && defined($ENV{vmhost_assigned_vm_provisioning_info}{$vmhost_id})) {
		return $ENV{vmhost_assigned_vm_provisioning_info}{$vmhost_id};
	}
	
	my $vmhost_assigned_vm_info = get_vmhost_assigned_vm_info($vmhost_id, $no_cache) || return;

	my $vmhost_assigned_vm_provisioning_info = {};
	for my $computer_id (keys %$vmhost_assigned_vm_info) {
		my $provisioning_id = $vmhost_assigned_vm_info->{$computer_id}{provisioning}{id};
		if (!defined($vmhost_assigned_vm_provisioning_info->{$provisioning_id})) {
			$vmhost_assigned_vm_provisioning_info->{$provisioning_id} = $vmhost_assigned_vm_info->{$computer_id}{provisioning};
		}
		#$vmhost_assigned_vm_provisioning_info->{$provisioning_id}{ASSIGNED_COMPUTER_IDS}{$computer_id} = 1;
		$vmhost_assigned_vm_provisioning_info->{$provisioning_id}{ASSIGNED_VM_COUNT}++;
	}
	
	$ENV{vmhost_assigned_vm_provisioning_info}{$vmhost_id} = $vmhost_assigned_vm_provisioning_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved provisioning info for VMs assigned to VM host $vmhost_id:\n" . format_data($vmhost_assigned_vm_provisioning_info));
	return $vmhost_assigned_vm_provisioning_info;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_cleanup_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves various attribues from the database for all image
               revisions. A hash is constructed:
               "winxp-win_generator1485-v24" => {
                  "age" => 1270,
                  "datecreated" => "2010-07-19 13:24:44",
                  "deleted" => 1,
                  "imagename" => "winxp-win_generator1485-v24",
                  "production" => 0,
                  "productionrevision" => 28,
                  "revision" => 24
                  "image" => {
                     "deleted" => 1
                  },
               },

=cut

sub get_imagerevision_cleanup_info {
	return $ENV{imagerevision_cleanup_info} if $ENV{imagerevision_cleanup_info};
	
	my $sql = <<EOF;	
SELECT
imagerevision.imagename AS imagerevision_imagename,
imagerevision.datecreated AS imagerevision_datecreated,
TIMESTAMPDIFF(DAY, imagerevision.datecreated, NOW()) AS imagerevision_age,
imagerevision.production AS imagerevision_production,
imagerevision.revision AS imagerevision_revision,
image.deleted AS image_deleted,
imagerevision.deleted AS imagerevision_deleted,
productionimagerevision.revision AS imagerevision_productionrevision
FROM
image,
imagerevision,
imagerevision productionimagerevision
WHERE
imagerevision.imageid = image.id
AND productionimagerevision.imageid = imagerevision.imageid
AND productionimagerevision.production = 1
EOF
	
	my @rows = database_select($sql);
	my $imagerevision_count = scalar(@rows);
	my $imagerevision_cleanup_info = {};
	
	my $deleted_count = 0;
	
	for my $row (@rows) {
		my $imagerevision_imagename = $row->{imagerevision_imagename};
		for my $key (keys %$row) {
			my $value = $row->{$key};
			my ($table, $column) = $key =~ /^(\w+)_(\w+)$/;
			if ($table eq 'imagerevision') {
				$imagerevision_cleanup_info->{$imagerevision_imagename}{$column} = $value;
			}
			else {
				$imagerevision_cleanup_info->{$imagerevision_imagename}{$table}{$column} = $value;
			}
		}
		
		if ($row->{imagerevision_deleted} || $row->{image_deleted}) {
			$deleted_count++;
			$imagerevision_cleanup_info->{$imagerevision_imagename}{deleted} = 1;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved cleanup info for imagerevision entries in the database");
	$ENV{imagerevision_cleanup_info} = $imagerevision_cleanup_info;
	return $ENV{imagerevision_cleanup_info};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_reservation_info

 Parameters  : $imagerevision_identifier (optional)
 Returns     : hash
 Description : Retrieves info regarding the image revisions currently assigned
               to reservations. A hash reference is returned. The hash keys are
               imagerevision.imagename values. Image revisions not assigned to
               any reservations are not included in the hash. Result format:
               
               "winxp-Word2003Eclipseforclassroom1308-v11" => {
                 "id" => 8362,
                 "imagename" => "winxp-Word2003Eclipseforclassroom1308-v11",
                 "reservation" => {
                   2450746 => {
                     "id" => 2450746,
                     "request" => {
                       "end" => "2014-01-08 20:30:00",
                       "laststate" => {
                         "name" => "inuse"
                       },
                       "start" => "2014-01-05 20:15:00",
                       "state" => {
                         "name" => "pending"
                       }
                     },
                     "requestid" => 2356990
                   },
                   2450747 => {
                     "id" => 2450747,
                     "request" => {
                       "end" => "2014-01-08 20:45:00",
                       "laststate" => {
                         "name" => "inuse"
                       },
                       "start" => "2014-01-05 20:30:00",
                       "state" => {
                         "name" => "inuse"
                       }
                     },
                     "requestid" => 2356991
                   }
                 }
               }

=cut

sub get_imagerevision_reservation_info {
	my $imagerevision_identifier = shift;
	
	my $sql = <<EOF;	
SELECT
imagerevision.id AS imagerevision_id,
imagerevision.imagename AS imagerevision_imagename,
reservation.id AS reservation_id,
reservation.requestid AS reservation_requestid,
request.start AS request_start,
request.end AS request_end,
state.name AS state_name,
laststate.name AS laststate_name
FROM
imagerevision,
reservation,
request,
state,
state laststate
WHERE
reservation.imagerevisionid = imagerevision.id
AND reservation.requestid = request.id
AND request.stateid = state.id
AND request.laststateid = laststate.id
EOF
	
	if ($imagerevision_identifier) {
		if ($imagerevision_identifier =~ /^\d+$/) {
			$sql .= "AND imagerevision.id = '$imagerevision_identifier'";
		}
		else {
			$sql .= "AND imagerevision.imagename = '$imagerevision_identifier'";
		}
	}

	my @rows = database_select($sql);
	
	my $imagerevision_reservation_info = {};
	for my $row (@rows) {
		my $imagerevision_imagename = $row->{imagerevision_imagename};
		my $request_id = $row->{request_id};
		my $reservation_id = $row->{reservation_id};
		
		for my $key (keys %$row) {
			my $value = $row->{$key};
			my ($table, $column) = $key =~ /^(\w+)_(\w+)$/;
			if ($table eq 'imagerevision') {
				$imagerevision_reservation_info->{$imagerevision_imagename}{$column} = $value;
			}
			elsif ($table eq 'reservation') {
				$imagerevision_reservation_info->{$imagerevision_imagename}{$table}{$reservation_id}{$column} = $value;
			}
			elsif ($table eq 'request') {
				$imagerevision_reservation_info->{$imagerevision_imagename}{reservation}{$reservation_id}{$table}{$column} = $value;
			}
			elsif ($table =~ /state/) {
				$imagerevision_reservation_info->{$imagerevision_imagename}{reservation}{$reservation_id}{request}{$table}{$column} = $value;
			}
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved imagerevision reservation info:\n" . format_data($imagerevision_reservation_info));
	return $imagerevision_reservation_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_loaded_info

 Parameters  : $imagerevision_identifier (optional)
 Returns     : hash reference
 Description : Retrieves info regarding the image revisions currently loaded on
               computers. A hash reference is returned. The hash keys are
               imagerevision.imagename values. Image revisions not loaded on any
               computers according to computer.imagerevisionid are not included
               in the hash. Result format:
               
               "winxp-ICTN2531RHEL61onVMware2865-v6" => {
                 "computer" => {
                   508 => {
                     "hostname" => "vm-1",
                     "id" => 508,
                     "state" => {
                       "name" => "available"
                     }
                   },
                   554 => {
                     "hostname" => "vm-53",
                     "id" => 554,
                     "state" => {
                       "name" => "inuse"
                     }
                   },
                 },
                 "id" => 7452,
                 "imagename" => "winxp-ICTN2531RHEL61onVMware2865-v6"
               },

=cut

sub get_imagerevision_loaded_info {
	my $imagerevision_identifier = shift;
	
	my $sql = <<EOF;	
SELECT
imagerevision.id AS imagerevision_id,
imagerevision.imagename AS imagerevision_imagename,
computer.id AS computer_id,
computer.hostname AS computer_hostname,
state.name AS state_name
FROM
imagerevision,
computer,
state
WHERE
computer.imagerevisionid = imagerevision.id
AND computer.stateid = state.id
AND computer.deleted = 0
EOF
	
	if ($imagerevision_identifier) {
		if ($imagerevision_identifier =~ /^\d+$/) {
			$sql .= "AND imagerevision.id = '$imagerevision_identifier'";
		}
		else {
			$sql .= "AND imagerevision.imagename = '$imagerevision_identifier'";
		}
	}

	my @rows = database_select($sql);
	
	my $imagerevision_loaded_info = {};
	for my $row (@rows) {
		my $imagerevision_imagename = $row->{imagerevision_imagename};
		my $computer_id = $row->{computer_id};
		for my $key (keys %$row) {
			my $value = $row->{$key};
			my ($table, $column) = $key =~ /^(\w+)_(\w+)$/;
			if ($table eq 'imagerevision') {
				$imagerevision_loaded_info->{$imagerevision_imagename}{$column} = $value;
			}
			elsif ($table eq 'computer') {
				$imagerevision_loaded_info->{$imagerevision_imagename}{computer}{$computer_id}{$column} = $value;
			}
			elsif ($table eq 'state') {
				$imagerevision_loaded_info->{$imagerevision_imagename}{computer}{$computer_id}{state}{$column} = $value;
			}
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved imagerevision loaded computer info:\n" . format_data($imagerevision_loaded_info));
	return $imagerevision_loaded_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_names

 Parameters  : none
 Returns     : array
 Description : Retrieves a list of all image revision names from the database.

=cut

sub get_imagerevision_names {
	return @{$ENV{imagerevision_names}} if $ENV{imagerevision_names};
	
	my $sql = "SELECT imagerevision.imagename FROM imagerevision WHERE 1";
	my @rows = database_select($sql);
	my @imagerevision_names = map { $_->{imagename} } @rows;
	my $imagerevision_count = scalar(@imagerevision_names);
	notify($ERRORS{'DEBUG'}, 0, "retrieved $imagerevision_count imagerevision names from database");
	
	$ENV{imagerevision_names} = \@imagerevision_names;
	return @{$ENV{imagerevision_names}};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_names_recently_reserved

 Parameters  : $days
 Returns     : array
 Description : Retrieves a list of image revision names from the database which
               have been reserved in the last number of days specified by the
               argument. Image revisions included in the result have been
               reserved recently. Image revisions not included in the result
               have not been reserved recently.

=cut

sub get_imagerevision_names_recently_reserved {
	my $days = shift;
	if (!$days) {
		notify($ERRORS{'WARNING'}, 0, "days argument was not supplied");
		return;
	}
	
	my $sql = <<EOF;	
SELECT DISTINCT
imagerevision.imagename
FROM
image,
imagerevision,
log,
sublog
WHERE
imagerevision.imageid = image.id
AND sublog.imageid = image.id
AND sublog.logid = log.id
AND log.finalend >= DATE_SUB(NOW(), INTERVAL $days DAY)
EOF

	my @rows = database_select($sql);
	
	my @imagerevision_names = map { $_->{imagename} } @rows;
	my $imagerevision_count = scalar(@imagerevision_names);
	notify($ERRORS{'DEBUG'}, 0, "retrieved $imagerevision_count imagerevision names from database whose images were reserved within the past $days days");
	return @imagerevision_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_array_intersection

 Parameters  : $array_ref_1, $array_ref_2...
 Returns     : array
 Description : Finds the intersection of any number of arrays.

=cut

sub get_array_intersection {
	my @array_refs = @_;
	
	# Set the resulting intersection hash to the first array ref argument
	my $array_ref_1 = shift @array_refs;
	my $array_ref_1_type = ref($array_ref_1);
	if (!$array_ref_1_type || $array_ref_1_type ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "first argument is not a reference to an array");
		return;
	}
	
	my @intersection = @$array_ref_1;
	
	my $loop = 0;
	for my $array_ref (@array_refs) {
		my @array = @$array_ref;
		my %hash = map { $_ => 1 } @array;
		@intersection = grep($hash{$_}, @intersection);
	}
	
	return sort @intersection;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_code_ref_package_name

 Parameters  : $code_ref
 Returns     : string
 Description : Determines the perl package name of a subroutine reference. The
               subroutine name is not included.

=cut

sub get_code_ref_package_name {
	my $code_ref = shift;
	if (!$code_ref || !ref($code_ref)) {
		return;
	}
	
	my $cv = svref_2object($code_ref) || return;
	my $gv = $cv->GV || return;
	my $st = $gv->STASH || return;
	return $st->NAME;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_code_ref_subroutine_name

 Parameters  : $code_ref
 Returns     : string
 Description : Determines the subroutine name of a subroutine reference. The
               perl package is not included.

=cut

sub get_code_ref_subroutine_name {
	my $code_ref = shift;
	if (!$code_ref || !ref($code_ref)) {
		return;
	}
	
	my $cv = svref_2object($code_ref) || return;
	my $gv = $cv->GV || return;
	return $gv->NAME;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 is_variable_set

 Parameters  : variable name
 Returns     : If variable is set: 1
               If variable is not set: 0
               If an error occurred: undefined
 Description : Queries the variable table for the variable with the name
               specified by the argument. Returns true if the variable is set,
               false otherwise.

=cut

sub is_variable_set {
	my $variable_name = shift;
	
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument and call shift again
	if (ref($variable_name)) {
		$variable_name = shift;
	}
	
	# Check the argument
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	
	# Construct the select statement
my $select_statement .= <<"EOF";
SELECT
variable.value
FROM
variable
WHERE
variable.name = '$variable_name'
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make 1 sure row was returned
	if (!@selected_rows) {
		notify($ERRORS{'DEBUG'}, 0, "variable is NOT set: $variable_name");
		return 0;
	}
	elsif (@selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', multiple rows exist in the database for variable:\n" . format_data(\@selected_rows));
		return;
	}
	
	# Get the serialized value from the variable row
	my $database_value = $selected_rows[0]{value};
	
	if (defined($database_value)) {
		notify($ERRORS{'DEBUG'}, 0, "variable is set: $variable_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', row returned:\n" . format_data(\@selected_rows));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_variable

 Parameters  : $variable_name, $show_warnings (optional)
 Returns     : If successful: data stored in the variable table for the variable name specified
               If failed: false
 Description : Queries the variable table for the variable with the name
               specified by the argument. Returns the data stored for the
               variable. Values are deserialized before being returned if the
               value stored was a reference.
               
               Undefined is returned if the variable name does not exist in the
               variable table. A log message is displayed by default. To
               suppress the log message, supply the $show_warnings argument with
               a value of 0.

=cut

sub get_variable {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	# Check the argument
	my $variable_name = shift;
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	
	my $show_warnings = shift;
	$show_warnings = 1 unless defined $show_warnings;
	
	# Construct the select statement
my $select_statement .= <<"EOF";
SELECT
variable.value,
variable.serialization
FROM
variable
WHERE
variable.name = '$variable_name'
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make 1 sure row was returned
	if (!@selected_rows) {
		notify($ERRORS{'OK'}, 0, "variable '$variable_name' is not set in the database") if $show_warnings;
		return;
	}
	elsif (@selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', multiple rows exist in the database for variable:\n" . format_data(\@selected_rows));
		return;
	}
	
	# Get the serialized value from the variable row
	my $serialization_type = $selected_rows[0]{serialization};
	my $database_value = $selected_rows[0]{value};
	my $deserialized_value;
	
	# Deserialize the variable value if necessary
	if ($serialization_type eq 'none') {
		$deserialized_value = $database_value;
	}
	elsif ($serialization_type eq 'yaml') {
		# Attempt to deserialize the value
		$deserialized_value = yaml_deserialize($database_value);
		if (!defined($deserialized_value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to deserialize variable '$variable_name' using YAML");
			return;
		}
		
		# Display the data type of the value retrieved from the variable table
		if (my $deserialized_data_type = ref($deserialized_value)) {
			notify($ERRORS{'DEBUG'}, 0, "data type of variable '$variable_name': $deserialized_data_type reference");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "data type of variable '$variable_name': scalar");
		}
	}
	elsif ($serialization_type eq 'phpserialize') {
		# TODO: find Perl module to handle PHP serialized data
		# Add module to list of dependencies
		# Add code here to call PHP deserialize function
		notify($ERRORS{'CRITICAL'}, 0, "unable to get value of variable '$variable_name', PHP serialized data is NOT supported yet by the VCL backend, returning null");
		return;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to get value of variable '$variable_name', serialization type '$serialization_type' is NOT supported by the VCL backend, returning null");
		return;
	}
	
	return $deserialized_value;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 yaml_deserialize

 Parameters  : Data
 Returns     : If successful: data structure
               If failed: false
 Description : 

=cut

sub yaml_deserialize {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument and call shift again
	my $yaml_data_argument = shift;
	if (ref($yaml_data_argument)) {
		$yaml_data_argument = shift;
	}
	
	# Check to make sure argument was passed
	if (!defined($yaml_data_argument)) {
		notify($ERRORS{'WARNING'}, 0, "data argument was not passed");
		return;
	}
	
	my $deserialized_value;
	eval '$deserialized_value = YAML::Load($yaml_data_argument)';
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to deserialize data using YAML::Load(), data value: $yaml_data_argument");
		return;
	}
	
	return $deserialized_value;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_variable

 Parameters  : variable name, variable value
 Returns     : If successful: true
               If failed: false
 Description : Inserts or updates a row in the variable table. The variable name
               and value arguments must be specified.
               
               The value can be a simple scalar such as a string or a reference
               to a complex data structure such as an array of hashes.
               
               Simple scalar values are stored in the variable.value column
               as-is and the variable.serialization column will be set to
               'none'.
               
               References are serialized using YAML before being stored. The
               variable.value column will contain the YAML representation of the
               data and the variable.serialization column will be set to 'yaml'.
               
               This subroutine will also update the variable.timestamp column.
               The variable.setby column is automatically set to the filename
               and line number which called this subroutine.

=cut

sub set_variable {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	my $variable_name = shift;
	
	# Get the 2nd argument containing the variable value
	my $variable_value = shift;
	
	# Check the arguments
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	elsif (!defined($variable_value)) {
		notify($ERRORS{'WARNING'}, 0, "variable value argument was not supplied");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to set variable: $variable_name");
	
	# Set serialization type to yaml if the value being stored is a reference
	# Otherwise, a simple scalar is being stored and serialization is not necessary
	my $serialization_type;
	if (ref($variable_value)) {
		$serialization_type = 'yaml';
	}
	else {
		$serialization_type = 'none';
	}
	
	# Construct a string indicating where the variable was set from
	my $management_node_name = get_management_node_info()->{SHORTNAME} || hostname;
	my @caller = caller(0);
	(my $calling_file) = $caller[1] =~ /([^\/]*)$/;
	my $calling_line = $caller[2];
	my $caller_string = "$management_node_name:$calling_file:$calling_line";
	
	# Attempt to serialize the value if necessary
	my $database_value;
	if ($serialization_type eq 'none') {
		$database_value = $variable_value;
	}
	else {
		# Attempt to serialize the value using YAML
		$database_value = yaml_serialize($variable_value);
		if (!defined($database_value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to serialize variable '$variable_name' using YAML, value:\n" . format_data($variable_value));
			return;
		}
	}
	
	# Assemble an insert statement, if the variable already exists, update the existing row
	my $insert_statement .= <<"EOF";
INSERT INTO variable
(
name,
serialization,
value,
setby,
timestamp
)
VALUES
(
'$variable_name',
'$serialization_type',
'$database_value',
'$caller_string',
NOW()
)
ON DUPLICATE KEY UPDATE
name=VALUES(name),
serialization=VALUES(serialization),
value=VALUES(value),
setby=VALUES(setby),
timestamp=VALUES(timestamp)
EOF
	
	# Execute the insert statement, the return value should be the id of the row
	my $inserted_id = database_execute($insert_statement);
	if ($inserted_id) {
		notify($ERRORS{'OK'}, 0, "set variable '$variable_name', variable id: $inserted_id, serialization: $serialization_type");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set variable '$variable_name', serialization: $serialization_type");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_variable

 Parameters  : variable name
 Returns     : If successful: true
               If failed: false
 Description : Deletes record related to variable name from variable table

=cut

sub delete_variable {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	my $variable_name = shift;
	
	# Check the arguments
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete variable: $variable_name");
	
	# Assemble delete statement, if the variable already exists, update the existing row
	my $delete_statement .= <<"EOF";
DELETE 
FROM 
variable
WHERE
name = '$variable_name'
EOF
	
	# Execute the delete statement, the return value should be the id of the row
	if (database_execute($delete_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted variable '$variable_name' from variable table");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete variable '$variable_name'");
		return;
	}
	
	return 1;
}
#//////////////////////////////////////////////////////////////////////////////

=head2 yaml_serialize

 Parameters  : Data
 Returns     : If successful: string containing serialized representation of data
               If failed: false
 Description : 

=cut

sub yaml_serialize {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	# Check to make sure argument was passed
	my $data_argument = shift;
	if (!defined($data_argument)) {
		notify($ERRORS{'WARNING'}, 0, "data argument was not passed");
		return;
	}
	
	# Attempt to serialize the value using YAML::Dump()
	# Use eval because Dump() will call die() if it encounters an error
	my $serialized_data;
	eval '$serialized_data = YAML::Dump($data_argument)';
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to serialize data using YAML::Dump(), data value: $data_argument");
		return;
	}
	
	# Escape all backslashes
	$serialized_data =~ s/\\/\\\\/g;
	
	# Escape all single quote characters with a backslash
	#   or else the SQL statement will fail because it is wrapped in single quotes
	$serialized_data =~ s/'/\\'/g;
	
	return $serialized_data;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_array_duplicates

 Parameters  : @array
 Returns     : array
 Description : Removes duplicates from the array. Retains order.

=cut

sub remove_array_duplicates {
	my @array = @_;
	
	my $seen = {};
	my @pruned;
	for (my $i=0; $i < scalar(@array); $i++) {
		my $value = $array[$i];
		if (ref($value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to remove duplicates from an array containing references, returning original array");
			return @array;
		}
		if (!defined($seen->{$value})) {
			$seen->{$value} = 1;
			push @pruned, $value;
		}
	}
	return @pruned
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_changelog_info

 Parameters  : $request_id, $age_limit_timestamp (optional)
 Returns     : hash reference
 Description : Retrieves all of the changelog entries for a request which have a
               changelog.remoteIP value. If the $age_limit_timestamp argument is
               supplied, only entries with timestamp values greater than or
               equal to the argument will be returned. A hash is constructed.
               The hash values are the changelog.id values:
               
               194 => {
                 "computerid" => 3574,
                 "end" => undef,
                 "id" => 194,
                 "logid" => 5354,
                 "other" => undef,
                 "remoteIP" => "1.2.3.4",
                 "reservation" => {
                   "lastcheck" => "2014-06-06 11:43:29"
                 },
                 "reservationid" => 3115,
                 "start" => undef,
                 "timestamp" => "2014-06-06 11:41:05",
                 "user" => {
                   "unityid" => "admin"
                 },
                 "userid" => 1,
                 "wasavailable" => undef
               },

=cut

sub get_changelog_info {
	my ($request_id, $age_limit_timestamp) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my %tables = (
		'changelog' => 'changelog',
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
	
	# Complete the select statement
	$select_statement .= <<EOF;
user.unityid AS 'user-unityid',
reservation.lastcheck AS 'reservation-lastcheck'
FROM
log,
request,
changelog
LEFT JOIN (user) ON (changelog.userid = user.id)
LEFT JOIN (reservation) ON (changelog.reservationid = reservation.id)
WHERE
changelog.logid = log.id
AND log.id = request.logid
AND request.id = $request_id
AND changelog.remoteIP IS NOT NULL
EOF
	
	if ($age_limit_timestamp) {
		$select_statement .= "AND changelog.timestamp >= '$age_limit_timestamp'";
	}
	
	my @rows = database_select($select_statement);

	my $changelog_info = {};
	for my $row (@rows) {
		my $changelog_id = $row->{'changelog-id'};
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			if ($table eq 'changelog') {
				$changelog_info->{$changelog_id}{$column} = $value;
			}
			else {
				$changelog_info->{$changelog_id}{$table}{$column} = $value;
			}
		}
	}
	
	my $age_string = '';
	if ($age_limit_timestamp) {
		$age_string = " updated on or after $age_limit_timestamp";
	}
	
	if (scalar(%$changelog_info)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved changelog info for request $request_id$age_string:\n" . format_data($changelog_info));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no changelog entries exist for request $request_id$age_string");
	}
	return $changelog_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_changelog_remote_ip_address_info

 Parameters  : $request_id, $age_limit_timestamp (optional)
 Returns     : hash reference
 Description : Retrieves all of the changelog entries for a request which have a
               changelog.remoteIP value and organizes the results by remote IP
               address. If the $age_limit_timestamp argument is supplied, only
               entries with timestamp values greater than or equal to the
               argument will be returned. A hash is constructed. The hash values
               are the changelog.remoteIP values:

               "1.2.3.5" => [
                 {
                   "computerid" => 3574,
                   "end" => undef,
                   "id" => 199,
                   "logid" => 5354,
                   "other" => undef,
                   "remoteIP" => "1.2.3.5",
                   "reservation" => {
                     "lastcheck" => "2014-06-06 11:56:00"
                   },
                   "reservationid" => 3115,
                   "start" => undef,
                   "timestamp" => "2014-06-06 11:53:36",
                   "user" => {
                     "unityid" => "admin"
                   },
                   "userid" => 1,
                   "wasavailable" => undef
                 }
               ]

=cut

sub get_changelog_remote_ip_address_info {
	my ($request_id, $age_limit_timestamp) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	
	my $changelog_remote_ip_info = {};
	
	my $changelog_info = get_changelog_info($request_id, $age_limit_timestamp);
	for my $changelog_id (keys %$changelog_info) {
		my $remote_ip = $changelog_info->{$changelog_id}{remoteIP};
		
		push @{$changelog_remote_ip_info->{$remote_ip}}, $changelog_info->{$changelog_id};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved all changelog remote IP addresses for request $request_id: " . format_data($changelog_remote_ip_info));
	return $changelog_remote_ip_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_changelog_reservation_remote_ip

 Parameters  : $reservation_id, @remote_ip_addresses
 Returns     : boolean
 Description : Inserts a rows into the changelog table with the remoteIP value
               specified by the argument. If a changelog row already exists with
               the same reservationid and remoteIP values, the timestamp of that
               row is updated to the current time. The changelog.userid column
               is set to NULL.

=cut

sub update_changelog_reservation_remote_ip {
	my ($reservation_id, @remote_ip_addresses) = @_;
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	if (!@remote_ip_addresses) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not supplied");
		return;
	}
	
	for my $remote_ip (@remote_ip_addresses) {
		my $sql = <<EOF;
INSERT INTO changelog
(logid, reservationid, computerid, remoteIP, timestamp)
(
	SELECT
	log.id, reservation.id, reservation.computerid, '$remote_ip', NOW()
	FROM
	request,
	reservation,
	log
	WHERE
	reservation.id = $reservation_id
	AND request.id = reservation.requestid
	AND request.logid = log.id
)
ON DUPLICATE KEY UPDATE
changelog.timestamp=NOW(),
changelog.id=LAST_INSERT_ID(changelog.id)
EOF
		
		my $changelog_id = database_execute($sql);
		if ($changelog_id) {
			notify($ERRORS{'OK'}, 0, "updated changelog ID: $changelog_id, reservation: $reservation_id, remote IP: $remote_ip");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update into changelog table, reservation: $reservation_id, remote IP: $remote_ip");
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_changelog_reservation_user_remote_ip

 Parameters  : $reservation_id, $user_id, @remote_ip_addresses
 Returns     : boolean
 Description : Inserts a rows into the changelog table with the reservationid,
               userid, and remoteIP values specified by the arguments. If a
               changelog row already exists with the same reservationid and
               remoteIP values, the timestamp of that row is updated to the
               current time.

=cut

sub update_changelog_reservation_user_remote_ip {
	my ($reservation_id, $user_id, @remote_ip_addresses) = @_;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	if (!defined($user_id)) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not supplied");
		return;
	}
	elsif (!@remote_ip_addresses) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not supplied");
		return;
	}
	
	for my $remote_ip (@remote_ip_addresses) {
		my $sql = <<EOF;
INSERT INTO changelog
(logid, userid, reservationid, computerid, remoteIP, timestamp)
(
	SELECT
	log.id, user.id, reservation.id, reservation.computerid, '$remote_ip', NOW()
	FROM
	request,
	reservation,
	log,
	user
	WHERE
	reservation.id = $reservation_id
	AND request.id = reservation.requestid
	AND request.logid = log.id
	AND user.id = $user_id
)
ON DUPLICATE KEY UPDATE
changelog.timestamp=NOW(),
changelog.id=LAST_INSERT_ID(changelog.id)
EOF
		
		my $changelog_id = database_execute($sql);
		if ($changelog_id) {
			notify($ERRORS{'OK'}, 0, "updated changelog ID: $changelog_id, reservation: $reservation_id, user ID: $user_id, remote IP: $remote_ip");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update into changelog table, reservation: $reservation_id, user ID: $user_id, remote IP: $remote_ip");
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_changelog_request_user_remote_ip

 Parameters  : $request_id, $user_id, @remote_ip_addresses
 Returns     : boolean
 Description : Inserts a rows into the changelog table with the userid and
               remoteIP values specified by the arguments. The reservationid
               value is set to NULL.

=cut

sub update_changelog_request_user_remote_ip {
	my ($request_id, $user_id, @remote_ip_addresses) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	if (!defined($user_id)) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not supplied");
		return;
	}
	elsif (!@remote_ip_addresses) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not supplied");
		return;
	}
	
	for my $remote_ip (@remote_ip_addresses) {
		my $sql = <<EOF;
INSERT INTO changelog
(logid, userid, remoteIP, timestamp)
(
	SELECT
	request.logid, $user_id, '$remote_ip', NOW()
	FROM
	request
	WHERE
	request.id = $request_id
)
ON DUPLICATE KEY UPDATE
changelog.timestamp=NOW(),
changelog.id=LAST_INSERT_ID(changelog.id)
EOF
		
		my $changelog_id = database_execute($sql);
		if ($changelog_id) {
			notify($ERRORS{'OK'}, 0, "updated changelog ID: $changelog_id, request: $request_id, user ID: $user_id, remote IP: $remote_ip");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update into changelog table, request: $request_id, user ID: $user_id, remote IP: $remote_ip");
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_connectlog_info

 Parameters  : $request_id, $age_limit_timestamp (optional)
 Returns     : hash
 Description : Retrieves connectlog entries for a request and returns a hash
               reference organized by connectlog.id values:
               
               {
                 119 => {
                   "id" => 119,
                   "logid" => 5354,
                   "remoteIP" => "192.168.53.54",
                   "reservationid" => 3115,
                   "timestamp" => "2014-05-16 12:47:05",
                   "userid" => 1,
                   "verified" => 1
                 },
                 122 => {
                   "id" => 122,
                   "logid" => 5354,
                   "remoteIP" => "192.168.53.54",
                   "reservationid" => 3115,
                   "timestamp" => "2014-05-16 12:47:05",
                   "userid" => undef,
                   "verified" => 0
                 },

=cut

sub get_connectlog_info {
	my ($request_id, $age_limit_timestamp) = @_;
	if (!$request_id) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	
	my $select_statement = <<EOF;	
SELECT
connectlog.*
FROM
connectlog,
request
WHERE
request.id = $request_id
AND connectlog.logid = request.logid
EOF
	
	if ($age_limit_timestamp) {
		$select_statement .= "AND connectlog.timestamp >= '$age_limit_timestamp'";
	}
	
	my $connectlog_info = {};
	
	my @rows = database_select($select_statement);
	for my $row (@rows) {
		my $connectlog_id = $row->{id};
		$connectlog_info->{$connectlog_id} = $row;
	}
	
	my $age_string = '';
	if ($age_limit_timestamp) {
		$age_string = " updated on or after $age_limit_timestamp";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved connectlog info for request $request_id$age_string:\n" . format_data($connectlog_info));
	return $connectlog_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_connectlog_remote_ip_address_info

 Parameters  : $request_id, $age_limit_timestamp (optional)
 Returns     : hash
 Description : Retrieves connectlog entries for a request and returns a hash
               reference organized by connectlog.remoteIP values. Each hash key
               contains an array reference of the connectlog entries which match
               the remoteIP key:
               {
                  "192.168.53.54" => [
                    {
                      "id" => 119,
                      "logid" => 5354,
                      "remoteIP" => "192.168.53.54",
                      "reservationid" => 3115,
                      "timestamp" => "2014-05-16 12:47:05",
                      "userid" => 1,
                      "verified" => 1
                    },
                    {
                      "id" => 122,
                      "logid" => 5354,
                      "remoteIP" => "192.168.53.54",
                      "reservationid" => 3115,
                      "timestamp" => "2014-05-16 12:47:05",
                      "userid" => undef,
                      "verified" => 0
                    }
                  ],
               }

=cut

sub get_connectlog_remote_ip_address_info {
	my ($request_id, $age_limit_timestamp) = @_;
	if (!$request_id) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	
	my $connectlog_remote_ip_info = {};
	my $connectlog_info = get_connectlog_info($request_id, $age_limit_timestamp);
	for my $connectlog_id (keys %$connectlog_info) {
		my $remote_ip = $connectlog_info->{$connectlog_id}{remoteIP};
		push @{$connectlog_remote_ip_info->{$remote_ip}}, $connectlog_info->{$connectlog_id};
	}
	
	my $age_string = '';
	if ($age_limit_timestamp) {
		$age_string = " updated on or after $age_limit_timestamp";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved connectlog remote IP address info for request $request_id$age_string:\n" . format_data($connectlog_remote_ip_info));
	return $connectlog_remote_ip_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_connectlog

 Parameters  : $reservation_id, $remote_ip, $verified (optional), $user_id (optional)
 Returns     : boolean
 Description : Inserts into or updates the connectlog table. If an existing
               entry with the same reservation ID, user ID, and remote IP values
               exists, the timestamp is updated. The verified value is updated
               if the existing value is false and the verified argument is true.
               Otherwise, the verified value remains false.

=cut

sub update_connectlog {
	my ($reservation_id, $remote_ip, $verified, $user_id) = @_;
	
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	if (!$remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not supplied");
		return;
	}
	
	$verified = 0 unless defined($verified);
	$user_id = 'NULL' unless defined($user_id) && $verified;
	
	my $sql = <<EOF;
INSERT INTO connectlog
(logid, reservationid, userid, remoteIP, verified, timestamp)
SELECT
request.logid,
$reservation_id,
$user_id,
'$remote_ip',
$verified,
NOW()
FROM
request,
reservation
WHERE
reservation.id = $reservation_id
AND reservation.requestid = request.id
EOF
	
	# Try to prevent duplicate rows if userid is NULL
	if ($user_id eq 'NULL') {
		$sql .= <<EOF;
AND NOT EXISTS (
   SELECT
	id
	FROM
	connectlog
	WHERE
	reservationid = $reservation_id
	AND remoteIP = '$remote_ip'
	AND userid IS NULL
)
EOF
	}

	$sql .= <<EOF;
ON DUPLICATE KEY UPDATE
connectlog.logid = LAST_INSERT_ID(connectlog.logid),
connectlog.timestamp = NOW(),
connectlog.verified = IF(VALUES(verified) = 1, 1, connectlog.verified)
EOF
	
	# If user ID argument wasn't provided, set it to 'NULL' for the log message
	$user_id = 'NULL' unless defined($user_id);
	
	my $connectlog_id = database_execute($sql);
	if ($connectlog_id) {
		notify($ERRORS{'OK'}, 0, "updated connectlog ID: $connectlog_id, reservation: $reservation_id, remote IP: $remote_ip, verified: $verified, user ID: $user_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update into connectlog table, reservation: $reservation_id, remote IP: $remote_ip, verified: $verified, user ID: $user_id");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_private_ip_address_info

 Parameters  : @computer_ids (optional)
 Returns     : hash reference
 Description : Retrieves the privateIPaddress value from the computer table for
               all computers in the database. Deleted computers are not
               included. A hash is constructed:
               {
                  "vcl-46.vcl.edu" => "10.10.7.46",
                  "vcl-47.vcl.edu" => "10.10.7.47",
                  "vcl-48.vcl.edu" => "10.10.7.48",
                  "vcl-49.vcl.edu" => "10.10.7.49",
                  "vcl-50.vcl.edu" => "10.10.7.50",
               }

=cut

sub get_computer_private_ip_address_info {
	my @computer_ids = @_;
	if (@computer_ids) {
		my @invalid_computer_ids = grep { $_ !~ /^\d+$/ } @computer_ids;
		if (@invalid_computer_ids) {
			notify($ERRORS{'WARNING'}, 0, "argument may only contain numberic computer IDs, the following values are not valid:\n" . join("\n", @invalid_computer_ids));
			return;
		}
	}
	
	
	my $select_statement = <<EOF;
SELECT
computer.hostname,
computer.privateIPaddress
FROM
computer
WHERE
computer.deleted = 0
EOF
	
	if (@computer_ids) {
		my $computer_id_string = join(', ', @computer_ids);
		$select_statement .= "AND computer.id IN ($computer_id_string)"
	}

	my $private_ip_address_info = {};
	my @rows = database_select($select_statement);
	for my $row (@rows) {
		my $hostname = $row->{hostname};
		my $private_ip_address = $row->{privateIPaddress};
		$private_ip_address_info->{$hostname} = $private_ip_address;
	}
	
	my $count = scalar(keys %$private_ip_address_info);
	notify($ERRORS{'DEBUG'}, 0, "retrieved private IP addresses for $count computers from the database");
	return $private_ip_address_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_current_private_ip_address

 Parameters  : $computer_identifier, $no_cache (optional)
 Returns     : string
 Description : Retrieves the privateIPaddress value from the computer table for
               a single computer.
               
               Returns the private IP address if:
               - a single non-deleted or deleted computer matches the argument
                 (a warning is displayed if the computer is deleted)
               
               Returns null if:
               - no computers or multiple computers match the argument

=cut

sub get_computer_current_private_ip_address {
	my ($computer_identifier, $no_cache) = @_;
	if (!$computer_identifier) {
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument was not supplied");
		return;
	}
	$no_cache = 0 unless defined($no_cache);
	
	# Figure out the computer ID based on the $computer_identifier argument
	my $computer_id;
	if ($computer_identifier =~ /^\d+$/) {
		$computer_id = $computer_identifier;
	}
	else {
		$computer_id = get_computer_ids($computer_identifier);
		if (!$computer_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve current private IP address from database, computer ID could not be determed from argument: $computer_identifier");
			return;
		}
	}
	
	my $computer_string = $computer_identifier;
	$computer_string .= " ($computer_id)" if ($computer_identifier ne $computer_id);
	
	if (!$no_cache && defined($ENV{computer_private_ip_address}{$computer_id})) {
		notify($ERRORS{'DEBUG'}, 0, "returning cached private IP address for computer $computer_string: $ENV{computer_private_ip_address}{$computer_id}");
		return $ENV{computer_private_ip_address}{$computer_id};
	}
	
	my $select_statement = <<EOF;
SELECT
computer.hostname,
computer.privateIPaddress
FROM
computer
WHERE
computer.id = '$computer_id'
AND computer.deleted = 0
EOF
	
	my @rows = database_select($select_statement);
	if (!@rows) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve private IP address from database for computer $computer_string");
		return;
	}
	
	my $row = $rows[0];
	my $private_ip_address = $row->{privateIPaddress};
	my $hostname = $row->{hostname};
	if ($private_ip_address) {
		$ENV{computer_private_ip_address}{$computer_id} = $private_ip_address;
		notify($ERRORS{'DEBUG'}, 0, "retrieved private IP address for computer $computer_string from database: $private_ip_address");
		return $private_ip_address;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "private IP address for computer $computer_string is set to null in database");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 hostname_to_ip_address

 Parameters  : $hostname
 Returns     : string
 Description : Calls gethostbyname on the management node to determine the IP
               address the hostname resolves to. The IP address is returned. If
               the hostname cannot be resolved or if an error occurs, null is
               returned.

=cut

sub hostname_to_ip_address {
	my ($hostname) = @_;
	
	my $packed_ip_address = gethostbyname($hostname);
	if (defined $packed_ip_address) {
		my $ip_address = inet_ntoa($packed_ip_address);
		notify($ERRORS{'DEBUG'}, 0, "resolved IP address from hostname $hostname --> $ip_address");
		return $ip_address;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to resolve IP address from hostname: $hostname");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ip_address_to_hostname

 Parameters  : $ip_address
 Returns     : string
 Description : Calls gethostbyaddr on the management node to determine the
               hostname an IP address resolves to. The hostname is returned. If
               the IP address cannot be resolved or if an error occurs, null is
               returned.

=cut

sub ip_address_to_hostname {
	my ($ip_address) = @_;
	
	my $hostname = gethostbyaddr(inet_aton($ip_address), AF_INET);
	if (defined $hostname) {
		notify($ERRORS{'DEBUG'}, 0, "resolved hostname from IP address $ip_address --> $hostname");
		return $hostname;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to resolve hostname from IP address: $ip_address");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_request_checkuser

 Parameters  : $request_id, $checkuser
 Returns     : boolean
 Description : Updates the request.checkuser value. This allows modules to
               disable user connection checking.

=cut

sub update_request_checkuser {
	my ($request_id, $checkuser) = @_;
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not supplied");
		return;
	}
	if (!defined($checkuser)) {
		$checkuser = 0;
	}

	# Construct the SQL statement
	my $sql_statement = <<EOF;
UPDATE
request
SET
checkuser = $checkuser
WHERE
request.id = $request_id
EOF

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "updated request.checkuser to $checkuser for request $request_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update request.checkuser to $checkuser for request $request_id");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_provisioning_osinstalltype_info

 Parameters  : $provisioning_id
 Returns     : hash reference
 Description : Retrieves information for all of the OSinstalltypes mapped to a
               provisioning ID. A hash is returned:
               }
                  10 => {
                    "id" => 10,
                    "name" => "hyperv",
                    "provisioningOSinstalltype" => {
                      "OSinstalltypeid" => 10,
                      "provisioningid" => 8
                    }
                  },
                  4 => {
                    "id" => 4,
                    "name" => "vmware",
                    "provisioningOSinstalltype" => {
                      "OSinstalltypeid" => 4,
                      "provisioningid" => 8
                    }
                  }
               }

=cut

sub get_provisioning_osinstalltype_info {
	my ($provisioning_id) = @_;
	if (!defined($provisioning_id)) {
		notify($ERRORS{'WARNING'}, 0, "provisioning ID argument was not specified");
		return;
	}
	
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'provisioningOSinstalltype',
		'OSinstalltype',
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
provisioningOSinstalltype,
OSinstalltype
WHERE
provisioningOSinstalltype.provisioningid = $provisioning_id
AND provisioningOSinstalltype.OSinstalltypeid = OSinstalltype.id
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	my $info = {};
	for my $row (@selected_rows) {
		my $osinstalltype_id = $row->{'OSinstalltype-id'};
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			# Add the values for the primary table to the hash
			# Add values for other tables under separate keys
			if ($table eq 'OSinstalltype') {
				$info->{$osinstalltype_id}{$column} = $value;
			}
			else {
				$info->{$osinstalltype_id}{$table}{$column} = $value;
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved info for OSinstalltypes mapped to provisioning ID $provisioning_id: " . format_data($info));
	return $info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_provisioning_table_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information from the provisioning and module tables
               and assembles a hash. The hash keys are the provisioning.id
               values. Example:
               {
                 1 => {
                   "id" => 1,
                   "module" => {
                     "description" => "",
                     "id" => 1,
                     "name" => "provisioning_xCAT",
                     "perlpackage" => "VCL::Module::Provisioning::xCAT",
                     "prettyname" => "xCAT"
                   },
                   "moduleid" => 1,
                   "name" => "xcat",
                   "prettyname" => "xCAT"
                 },
                 13 => {
                   "id" => 13,
                   "module" => {
                     "description" => "",
                     "id" => 21,
                     "name" => "provisioning_vmware_vsphere",
                     "perlpackage" => "VCL::Module::Provisioning::VMware::VMware",
                     "prettyname" => "VMware Provisioning Module"
                   },
                   "moduleid" => 21,
                   "name" => "vmware_vsphere",
                   "prettyname" => "VMware vSphere"
                 },
                 15 => {
                   "id" => 15,
                   "module" => {
                     "description" => "",
                     "id" => 26,
                     "name" => "base_module",
                     "perlpackage" => "VCL::Module",
                     "prettyname" => "VCL Base Module"
                   },
                   "moduleid" => 26,
                   "name" => "none",
                   "prettyname" => "None"
                 },
               }

=cut

sub get_provisioning_table_info {
	return $ENV{provisioning_table_info} if (defined($ENV{provisioning_table_info}));
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'provisioning',
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
provisioning,
module
WHERE
provisioning.moduleid = module.id
EOF

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	my $provisioning_table_info = {};
	for my $row (@selected_rows) {
		my $provisioning_id = $row->{'provisioning-id'};
		
		# Loop through all the columns returned
		for my $key (keys %$row) {
			my $value = $row->{$key};
			
			# Split the table-column names
			my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
			
			# Add the values for the primary table to the hash
			# Add values for other tables under separate keys
			if ($table eq 'provisioning') {
				$provisioning_table_info->{$provisioning_id}{$column} = $value;
			}
			else {
				$provisioning_table_info->{$provisioning_id}{$table}{$column} = $value;
			}
		}
	}
	
	$ENV{provisioning_table_info} = $provisioning_table_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved provisioning info: " . format_data($provisioning_table_info));
	return $provisioning_table_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ip_address_to_network_address

 Parameters  : $ip_address, $subnet_mask
 Returns     : If called in array context: ($network_address, $network_bits)
               If called in scalar context: $network_address
 Description : Determines a network address and network bits.

=cut

sub ip_address_to_network_address {
	my ($ip_address, $subnet_mask) = @_;
	if (!defined($ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "$ip_address argument was not supplied");
		return;
	}
	if (!defined($subnet_mask)) {
		notify($ERRORS{'WARNING'}, 0, "$subnet_mask argument was not supplied");
		return;
	}
	
	my $netmask_object = new Net::Netmask("$ip_address/$subnet_mask");
	if (!$netmask_object) {
		notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address, subnet mask: $subnet_mask");
		return;
	}
	
	my $network_address = $netmask_object->base();
	my $network_bits = $netmask_object->bits();
	notify($ERRORS{'DEBUG'}, 0, "$ip_address/$subnet_mask --> $network_address/$network_bits");
	if (wantarray) {
		return ($network_address, $network_bits);
	}
	else {
		return $network_address;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 determine_remote_connection_target

 Parameters  : $argument, $no_cache (optional)
 Returns     : string
 Description : Attempts to determine the string to use when connecting to a
               remote node. If an IP address is passed, the same IP address is
               always returned. If a hostname is passed, an attempt is made to
               retrieve the private IP address of the host. If successful, the
               private IP address is returned. Otherwise, the hostname argument
               is returned.

=cut

sub determine_remote_connection_target {
	my ($argument, $no_cache) = @_;
	if (!defined($argument)) {
		notify($ERRORS{'WARNING'}, 0, "remote connection argument was not supplied");
		return;
	}
	
	# Check if argument contains an '@' character: root@x.x.x.x
	# Remove anything preceeding it
	$argument =~ s/.*@([^@]+)$/$1/g;
	
	if (!$no_cache && defined($ENV{remote_connection_target}{$argument})) {
		return $ENV{remote_connection_target}{$argument};
	}
	
	# If an IP address was passed, use it
	if (is_valid_ip_address($argument, 0)) {
		$ENV{remote_connection_target}{$argument} = $argument;
		notify($ERRORS{'DEBUG'}, 0, "argument is a valid IP address, it will be used as the remote connection target: $ENV{remote_connection_target}{$argument}");
		return $ENV{remote_connection_target}{$argument};
	}
	
	# Attempt to retrieve the private IP address from the database
	my $database_private_ip_address = get_computer_current_private_ip_address($argument);
	if ($database_private_ip_address) {
		$ENV{remote_connection_target}{$argument} = $database_private_ip_address;
		notify($ERRORS{'DEBUG'}, 0, "private IP address is set in database for $argument, it will be used as the remote connection target: $ENV{remote_connection_target}{$argument}");
		return $ENV{remote_connection_target}{$argument};
	}
	
	# Private IP address could not be retrieved from the database or is set to NULL
	# Try to resolve the argument to an IP address
	# First make sure it is a valid hostname
	if (!is_valid_dns_host_name($argument)) {
		$ENV{remote_connection_target}{$argument} = $argument;
		notify($ERRORS{'WARNING'}, 0, "failed to reliably determine the remote connection target to use for '$argument', it is not a valid IP address or DNS hostname");
		return $ENV{remote_connection_target}{$argument};
	}
	
	# Check if the hostname includes a DNS suffix
	# If so, extract the short hostname and try to resolve that
	my $resolved_ip_address;
	if ($argument =~ /^([^\.]+)\./) {
		my $short_hostname = $1;
		notify($ERRORS{'DEBUG'}, 0, "hostname $argument contains a DNS suffix, attempting to resolve the hostname without its DNS suffix: $short_hostname");
		$resolved_ip_address = hostname_to_ip_address($short_hostname);
	}
	if (!$resolved_ip_address) {
		$resolved_ip_address = hostname_to_ip_address($argument);
	}
	
	if ($resolved_ip_address) {
		# Attempt to set the private IP address in the database
		# Only do this if a private IP was retrieved earlier to avoid additional warnings
		if ($database_private_ip_address) {
			update_computer_private_ip_address($argument, $resolved_ip_address);
		}
		
		$ENV{remote_connection_target}{$argument} = $resolved_ip_address;
		notify($ERRORS{'DEBUG'}, 0, "$argument resolves to IP address $resolved_ip_address, it will be used as the remote connection target");
		return $ENV{remote_connection_target}{$argument};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reliably determine the remote connection target to use for '$argument', it is not a valid IP address, a private IP address is not set in the database, and '$argument' does not resolve to an IP address on this management node");
		$ENV{remote_connection_target}{$argument} = $argument;
		return $ENV{remote_connection_target}{$argument};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wrap_string

 Parameters  : $string, $columns, $prefix
 Returns     : string
 Description : Formats a string to limit the number of characters per line. The
               $prefix argument may be used to add comment characters to the
               beginning of each line, while still adhering to the line width
               limit. If $prefix is set to '# ' (not including the single-quote
               characters), the string returned will be something like:
               # My first line...
               # Second line...

=cut

sub wrap_string {
	my ($string, $columns, $prefix) = @_;
	return '' unless defined($string);
	$columns = 80 unless $columns;
	$prefix = '' unless defined($prefix);
	
	# Wrap text for lines
	local($Text::Wrap::columns) = $columns;
	
	my $wrapped_string = wrap($prefix, $prefix, $string);
	return $wrapped_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 prune_hash_reference

 Parameters  : $hash_ref, $prune_regex
 Returns     : hash reference
 Description : 

=cut

sub prune_hash_reference {
	my ($hash_ref_argument, $prune_regex) = @_;
	if (!defined($hash_ref_argument)) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not supplied");
		return;
	}
	elsif (!ref($hash_ref_argument) || ref($hash_ref_argument) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference:\n" . format_data($hash_ref_argument));
		return;
	}
	elsif (!defined($prune_regex)) {
		notify($ERRORS{'WARNING'}, 0, "prune regex argument was not supplied, returning original hash reference");
		return $hash_ref_argument;
	}
	
	# Create a clone if this wasn't recursively called
	my $calling_subroutine = get_calling_subroutine();
	my $hash_ref;
	if ($calling_subroutine =~ /^prune/) {
		$hash_ref = $hash_ref_argument;
	}
	else {
		$hash_ref = dclone($hash_ref_argument);
	}
	
	my $result = {};
	for my $key (keys %$hash_ref) {
		# Don't add keys which match the regex
		if ($key =~ /$prune_regex/) {
			next;
		}
		
		my $type = ref($hash_ref->{$key});
		if (!$type) {
			# If the value is not a reference, simply add it to the result
			$result->{$key} = $hash_ref->{$key};
			next;
		}
		elsif ($type eq 'HASH') {
			$result->{$key} = prune_hash_reference($hash_ref->{$key}, $prune_regex);
		}
		elsif ($type eq 'ARRAY') {
			$result->{$key} = prune_array_reference($hash_ref->{$key}, $prune_regex);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unsupported type: $type");
		}
	}
	return $result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 prune_array_reference

 Parameters  : $array_ref, $prune_regex
 Returns     : array reference
 Description : 

=cut

sub prune_array_reference {
	my ($array_ref_argument, $prune_regex) = @_;
	if (!defined($array_ref_argument)) {
		notify($ERRORS{'WARNING'}, 0, "array reference argument was not supplied");
		return;
	}
	elsif (!ref($array_ref_argument) || ref($array_ref_argument) ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a array reference:\n" . format_data($array_ref_argument));
		return;
	}
	elsif (!defined($prune_regex)) {
		notify($ERRORS{'WARNING'}, 0, "prune regex argument was not supplied, returning original array reference");
		return $array_ref_argument;
	}
	
	# Create a clone if this wasn't recursively called
	my $calling_subroutine = get_calling_subroutine();
	my $array_ref;
	if ($calling_subroutine =~ /^prune/) {
		$array_ref = $array_ref_argument;
	}
	else {
		$array_ref = dclone($array_ref_argument);
	}
	
	my $result = [];
	for my $element (@$array_ref) {
		my $type = ref($element);
		if (!$type) {
			push @$result, $element;
		}
		elsif ($type eq 'ARRAY') {
			push @$result, prune_array_reference($element, $prune_regex);
		}
		elsif ($type eq 'HASH') {
			push @$result, prune_hash_reference($element, $prune_regex);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unsupported type: $type");
		}
	}
	
	return $result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 prune_hash_child_references

 Parameters  : $hash_ref
 Returns     : hash reference
 Description : Makes a copy of the hash reference. Removes all keys that contain
               references as data.

=cut

sub prune_hash_child_references {
	my ($hash_ref_argument) = @_;
	if (!defined($hash_ref_argument)) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not supplied");
		return;
	}
	elsif (!ref($hash_ref_argument) || ref($hash_ref_argument) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference:\n" . format_data($hash_ref_argument));
		return;
	}
	
	# Create a clone
	my $hash_ref = dclone($hash_ref_argument);
	
	my $result = {};
	for my $key (keys %$hash_ref) {
		if (ref($hash_ref->{$key})) {
			next;
		}
		else {
			$result->{$key} = $hash_ref->{$key};
		}
	}
	return $result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_active_directory_domain_info

 Parameters  : $image_id, $no_cache (optional)
 Returns     : Hash containing image domain columns
 Description : Gets the imagedomain information from the database

=cut

sub get_image_active_directory_domain_info {
	my ($image_id, $no_cache) = @_;
	if (!$image_id) {
		notify($ERRORS{'WARNING'}, 0, "image ID argument was not specified");
		return;
	}
	
	my $management_node_id = get_management_node_id();
	
	# Get a hash ref containing the database column names
	my $database_table_columns = get_database_table_columns();
	
	my @tables = (
		'addomain',
		'imageaddomain',
		'cryptsecret',
		#'cryptkey',
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
imageaddomain,
addomain
LEFT JOIN (cryptsecret, cryptkey) ON (
	addomain.secretid = cryptsecret.secretid AND
	cryptsecret.cryptkeyid = cryptkey.id AND
	cryptkey.hosttype = 'managementnode' AND
	cryptkey.hostid = $management_node_id
)
WHERE
imageaddomain.imageid = $image_id
AND imageaddomain.addomainid = addomain.id
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'DEBUG'}, 0, "image $image_id is not configured for Active Directory");
		return {};
	}

	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	
	# Loop through all the columns returned
	my $info;
	for my $key (keys %$row) {
		my $value = $row->{$key};
		
		# Split the table-column names
		my ($table, $column) = $key =~ /^([^-]+)-(.+)/;
		
		if ($value && $column =~ /(dnsServers)/) {
			my @value_array = split(/[,;]+/, $value);
			$value = \@value_array;
		}
		
		# Add the values for the primary table to the hash
		# Add values for other tables under separate keys
		if ($table eq $tables[0]) {
			$info->{$column} = $value;
		}
		elsif ($table eq 'cryptkey') {
			$info->{cryptsecret}{$table}{$column} = $value;
		}
		else {
			$info->{$table}{$column} = $value;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved Active Directory info for image $image_id:\n" . format_data($info));
	return $info;
} ## end sub get_image_active_directory_domain_info

#//////////////////////////////////////////////////////////////////////////////

=head2 get_collapsed_hash_reference

 Parameters  : $hash_reference
 Returns     : array
 Description : Takes a potentially multi-level hash reference and generates a
               new single-level hash with key names constructed by concatenating
               the levels of key names. Example:
               Argument:
               {
                  "match_extensions" => {
                     "tcp" => {
                        "dport" => 22,
                     },
                  },
                  "parameters" => {
                     "jump" => {
                        "target" => "ACCEPT",
                        },
                     "protocol" => "tcp",
                  },
               }
               
               Result:
               {
                  "{'match_extensions'}{'tcp'}{'dport'}" => 22,
                  "{'parameters'}{'jump'}{'target'}" => "ACCEPT",
                  "{'parameters'}{'protocol'}" => "tcp"
               }
               
               This is potentially useful when 2 multi-level hashes need to be
               compared. The hash keys in the resultant hash can be used in an
               eval block to check if another hash has a key with the same name
               and/or value.

=cut

sub get_collapsed_hash_reference {
	my ($hash_reference, @parent_keys) = @_;
	if (!defined($hash_reference)) {
		notify($ERRORS{'WARNING'}, 0, "hash reference argument was not specified");
		return;
	}
	elsif (!ref($hash_reference) || ref($hash_reference) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference:\n" . format_data($hash_reference));
		return;
	}
	
	my %collapsed_hash;
	
	for my $key (keys %$hash_reference) {
		if (ref($hash_reference->{$key})) {
			if (ref($hash_reference->{$key}) eq 'HASH') {
				my $child_collapsed_hash_ref = get_collapsed_hash_reference($hash_reference->{$key}, (@parent_keys, $key)) || {};
				%collapsed_hash = (%collapsed_hash, %$child_collapsed_hash_ref);
			}
		}
		else {
			my $value = $hash_reference->{$key};
			
			my $key_path;
			for my $parent_key (@parent_keys) {
				$key_path .= "{'$parent_key'}";
			}
			$key_path .= "{'$key'}";
			
			$collapsed_hash{$key_path} = $value;
		}
	}
	return \%collapsed_hash;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_message_variable_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves info for all 'adminmessage|' and 'usermessage|' entries
               from the variable table. A hash is constructed. The keys are the
               variable.name values:
               {
                  "usermessage|endtime_reached|Global" => {
                    "id" => 957,
                    "serialization" => "yaml",
                    "setby" => undef,
                    "timestamp" => "0000-00-00 00:00:00",
                    "value" => "---\nmessage: |\n  Your reservation of [image_prettyname]\nshort_message: ~\nsubject: 'VCL -- End of reservation'\n"
                  },
                  "usermessage|reserved|Global" => {
                    "id" => 973,
                    "serialization" => "yaml",
                    "setby" => undef,
                    "timestamp" => "0000-00-00 00:00:00",
                    "value" => "---\nmessage: |\n  The rer_affiliation_sitewwwaddress]..."
                  },
                  ...
               }

=cut

sub get_message_variable_info {
	my $select_statement = <<EOF;
SELECT
*
FROM
variable
WHERE
variable.name REGEXP '^(admin|user)message\\\\|'
EOF

	my @rows = database_select($select_statement);
	
	my $info = {};
	for my $row (@rows) {
		my $variable_name = $row->{name};
		$info->{$variable_name} = $row;
		delete $info->{$variable_name}{name};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved info for all admin and user messages from the variable table:\n" . join("\n", sort keys %$info));
	return $info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_messages_need_validating

 Parameters  : none
 Returns     : boolean
 Description : If the variable table has an entry named
               'usermessage_needs_validating' with a value is set to 1 the
               management node's name, this subroutine proceeds to:
               * Set value of 'usermessage_needs_validating' to its hostname so
                 that other management nodes don't attempt to validate the
                 messages at the same time
               * Retrieves all of the adminmessage and usermessage rows from the
                 variable table
               * Checks the subject, message, and short_message strings
                 contained in variable.value for invalid substitution
                 identifiers (strings such as [request_foo] which don't
                 correspond to a function that DataStructure.pm implements)
					* If any invalid identifiers are found, an 'invalidfields' key is
					  added to variable.value containing a hash reference:
                     {
								"message" => [
								  "[is_blah]"
								],
								"subject" => [
								  "[usr_login_id]"
								]
                     }
               
               After validating is complete, the 'usermessage_needs_validating'
               variable is deleted.

=cut

sub check_messages_need_validating {
	my $management_node_name = get_management_node_info()->{SHORTNAME} || hostname;
	my $validate_variable_name = 'usermessage_needs_validating';
	
	#...........................................................................
	# Check if any messages have been updated
	# Just get the id to minimize this query since it runs with every vcld daemon loop
	my $select_id_statement = <<EOF;
SELECT
id,
timestamp
FROM
variable
WHERE
variable.name = '$validate_variable_name'
EOF
	my @select_needs_validating_rows = database_select($select_id_statement);
	if (!@select_needs_validating_rows) {
		#notify($ERRORS{'DEBUG'}, 0, "admin and user message variables to NOT need to be validated, $validate_variable_name variable does NOT exist in the database");
		return 0;
	}
	my $validate_variable_id = $select_needs_validating_rows[0]->{id};
	my $validate_variable_timestamp = $select_needs_validating_rows[0]->{timestamp};
	notify($ERRORS{'DEBUG'}, 0, "$validate_variable_name variable exists in the database, ID: $validate_variable_id, attempting to update variable value to '$management_node_name'");
	
	
	#...........................................................................
	# Messages have been updated and need validation
	# Try to allow only a single management node to processing the validation
	# Set usermessage_needs_validating variable.value --> <management node name>
	my $update_needs_validating_statement = <<EOF;
UPDATE
variable
SET
value = '$management_node_name',
timestamp = NOW()
WHERE
variable.id = $validate_variable_id
AND variable.timestamp = '$validate_variable_timestamp'
AND (
   variable.value = '1'
	OR variable.value = '$management_node_name'
)
EOF
	my $updated_needs_validating_rows = database_update($update_needs_validating_statement);
	if (!defined($updated_needs_validating_rows)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update value of $validate_variable_name variable (ID: $validate_variable_id) to '$management_node_name'");
		return;
	}
	elsif (!$updated_needs_validating_rows) {
		notify($ERRORS{'WARNING'}, 0, "no rows were affected in attempt to update value of $validate_variable_name variable (ID: $validate_variable_id) to '$management_node_name', another management node may have processed the verification and deleted the entry");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "updated the value of $validate_variable_name variable to '$management_node_name'");
	
	
	#...........................................................................
	# Check all of the admin and user messages
	my $message_variable_info = get_message_variable_info();
	for my $message_variable_name (sort keys %$message_variable_info) {
		my $yaml_string_value = $message_variable_info->{$message_variable_name}{value};
		my $hash_reference_value = yaml_deserialize($yaml_string_value);
		if (!defined($hash_reference_value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to validate '$message_variable_name' variable, YAML string could not be deserialized:\n$yaml_string_value");
			next;
		}
		elsif (!ref($hash_reference_value) || ref($hash_reference_value) ne 'HASH') {
			notify($ERRORS{'WARNING'}, 0, "unable to validate '$message_variable_name' variable, deserialized value is not a hash reference:\n" . format_data($hash_reference_value));
			next;
		}
		
		my $invalid_message_info;
		for my $key ('subject', 'message', 'short_message') {
			my $input_string = $hash_reference_value->{$key} || next;
			notify($ERRORS{'DEBUG'}, 0, "validating substitution identifiers contained in '$message_variable_name' $key");
			my @invalid_substitution_identifiers = VCL::DataStructure::get_invalid_substitution_identifiers($input_string);
			if (@invalid_substitution_identifiers) {
				$invalid_message_info->{$key} = \@invalid_substitution_identifiers;
			}
		}
		
		if ($invalid_message_info) {
			notify($ERRORS{'WARNING'}, 0, "'$message_variable_name' variable's value contains invalid substitution identifiers, setting 'invalidfields' key in variable.value to:\n" . format_data($invalid_message_info));
			$hash_reference_value->{invalidfields} = $invalid_message_info;
			set_variable($message_variable_name, $hash_reference_value);
		}
		elsif (defined($hash_reference_value->{invalidfields})) {
			# No invalid identifiers were found, 'invalidfields' was previously set for the variable, remove it
			notify($ERRORS{'WARNING'}, 0, "'$message_variable_name' variable's value contains an 'invalidfields' key but no invalid substitution identifiers were found, removing the key");
			delete $hash_reference_value->{invalidfields};
			set_variable($message_variable_name, $hash_reference_value);
		}
	}
	
	delete_variable($validate_variable_name);
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_cryptkey_pubkey

 Parameters  : $management_node_id, $show_warnings (optional)
 Returns     : string
 Description : Retrieves the cryptkey.pubkey value for the management node.

=cut

sub get_management_node_cryptkey_pubkey {
	my ($management_node_id, $show_warnings) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}
	
	$show_warnings = 1 unless defined($show_warnings);
	
	my $select_statement = <<EOF;
SELECT
cryptkey.pubkey
FROM
cryptkey
WHERE
cryptkey.hosttype = 'managementnode'
AND cryptkey.hostid = $management_node_id
EOF
	
	my @rows = database_select($select_statement);
	if (!@rows) {
		if ($show_warnings) {
			notify($ERRORS{'WARNING'}, 0, "cryptkey table does NOT contain a row for management node ID $management_node_id");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "cryptkey table does NOT contain a row for management node ID $management_node_id");
		}
		return;
	}
	
	my $row = $rows[0];
	my $public_key_string = $row->{pubkey};
	notify($ERRORS{'DEBUG'}, 0, "retrieved public key from cryptkey table for management node ID $management_node_id");
	return $public_key_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_management_node_cryptkey_pubkey

 Parameters  : $host_id, $public_key_string, $algorithm (optional), $algorithm_option (optional), $key_length (optional)
 Returns     : $cryptkey_id
 Description : Set or updates the cryptkey.pubkey value for the management node.

=cut

sub set_management_node_cryptkey_pubkey {
	my ($management_node_id, $public_key_string, $algorithm, $algorithm_option, $key_length) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}
	elsif (!defined($public_key_string)) {
		notify($ERRORS{'WARNING'}, 0, "public key string argument was not supplied");
		return;
	}
	$algorithm = 'RSA' unless $algorithm;
	$algorithm_option = 'OAEP' unless $algorithm_option;
	$key_length = 4096 unless $key_length;
	
	my $insert_statement = <<EOF;
INSERT INTO cryptkey
(hostid, hosttype, pubkey, algorithm, algorithmoption, keylength)
VALUES
(
	$management_node_id,
	'managementnode',
	'$public_key_string',
	'$algorithm',
	'$algorithm_option',
	$key_length
)
ON DUPLICATE KEY UPDATE
pubkey='$public_key_string',
algorithm='$algorithm',
algorithmoption='$algorithm_option',
keylength=$key_length
EOF
	
	my $cryptkey_id = database_execute($insert_statement);
	if ($cryptkey_id) {
		notify($ERRORS{'DEBUG'}, 0, "set public key in cryptkey table for management node ID $management_node_id, cryptkey ID");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute insert statement to set public key in cryptkey table for management node ID $management_node_id");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_cryptsecret_info

 Parameters  : $management_node_id
 Returns     : hash reference
 Description : 

=cut

sub get_management_node_cryptsecret_info {
	my ($management_node_id) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}

	my $select_statement = <<EOF;
SELECT
cryptsecret.*
FROM
cryptsecret,
cryptkey
WHERE
cryptkey.hostid = $management_node_id
AND cryptkey.hosttype = 'managementnode'
AND cryptsecret.cryptkeyid = cryptkey.id
EOF
	
	my @rows = database_select($select_statement);
	if (scalar @rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve cryptsecret info from database for management node $management_node_id");
		return;
	}

	print format_data(\@rows) . "\n\n";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_cryptsecret_value

 Parameters  : $management_node_id, $secret_id, $suppress_warning (optional)
 Returns     : boolean
 Description : Retrieves the cryptsecret.cryptsecret value matching the
               cryptsecret.secretid value from the database for the management
               node.

=cut

sub get_management_node_cryptsecret_value {
	my ($management_node_id, $secret_id, $suppress_warning) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}
	if (!defined($secret_id)) {
		notify($ERRORS{'WARNING'}, 0, "secret ID argument was not supplied");
		return;
	}

	my $select_statement = <<EOF;
SELECT
cryptsecret.cryptsecret
FROM
cryptsecret,
cryptkey
WHERE
cryptkey.hostid = $management_node_id
AND cryptkey.hosttype = 'managementnode'
AND cryptsecret.secretid = $secret_id
AND cryptsecret.cryptkeyid = cryptkey.id
EOF
	
	my @rows = database_select($select_statement);
	if (scalar @rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve cryptsecret from database for management node $management_node_id, secret ID: $secret_id") unless $suppress_warning;
		return;
	}

	my $cryptsecret = $rows[0]->{cryptsecret};	
	notify($ERRORS{'DEBUG'}, 0, "retrieved cryptsecret, management node ID: $management_node_id, secret ID: $secret_id");
	return $cryptsecret;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_ad_domain_credentials

 Parameters  : $management_node_id, $domain_dns_name, $no_cache (optional)
 Returns     : ($username, $secret_id, $encrypted_password)
 Description : Attempts to retrieve the username, encrypted password, and secret
               ID for the domain from the addomain table. This is used if a
               computer needs to be removed from a domain but the reservation
               image is not configured for Active Directory. When this occurs,
               the credentials are not available from $self->data.

=cut

sub get_management_node_ad_domain_credentials {
	my ($management_node_id, $domain_identifier, $no_cache) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}
	elsif (!$domain_identifier) {
		notify($ERRORS{'WARNING'}, 0, "domain identifier name argument was not specified");
		return;
	}
	
	if (!$no_cache && defined($ENV{management_node_ad_domain_credentials}{$domain_identifier})) {
		notify($ERRORS{'DEBUG'}, 0, "returning cached Active Directory credentials for domain: $domain_identifier");
		return @{$ENV{management_node_ad_domain_credentials}{$domain_identifier}};
	}
	
	# Construct the select statement
	my $select_statement = <<EOF;
SELECT DISTINCT
username,
password,
secretid
FROM
addomain
WHERE
EOF
	
	if ($domain_identifier =~ /^\d+$/) {
		$select_statement .= "addomain.id = $domain_identifier";
	}
	else {
		$select_statement .= "addomain.domainDNSName LIKE '$domain_identifier%'";
	}
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'DEBUG'}, 0, "Active Directory domain does not exist in the database: $domain_identifier");
		return ();
	}

	# Get the single row returned from the select statement
	my $row = $selected_rows[0];
	my $username = $row->{username};
	my $secret_id = $row->{secretid};
	my $encrypted_password = $row->{password};
	
	
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved credentials for domain: $domain_identifier\n" .
		"username           : '$username'\n" .
		"secret ID          : '$secret_id'\n" .
		"encrypted password : '$encrypted_password'"
	);
	$ENV{management_node_ad_domain_credentials}{$domain_identifier} = [$username, $secret_id, $encrypted_password];
	return @{$ENV{management_node_ad_domain_credentials}{$domain_identifier}};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_management_node_cryptsecret

 Parameters  : $management_node_id, $secret_id (optional)
 Returns     : boolean
 Description : 

=cut

sub delete_management_node_cryptsecret {
	my ($management_node_id, $secret_id) = @_;
	if (!defined($management_node_id)) {
		notify($ERRORS{'WARNING'}, 0, "management node ID argument was not supplied");
		return;
	}

	my $delete_statement = <<EOF;
DELETE
cryptsecret.*
FROM
cryptsecret,
cryptkey
WHERE
cryptkey.hostid = $management_node_id
AND cryptkey.hosttype = 'managementnode'
AND cryptsecret.cryptkeyid = cryptkey.id
EOF
	if ($secret_id) {
		$delete_statement .= "AND cryptsecret.secretid = $secret_id";
	}
	
	if (database_execute($delete_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted entries from cryptsecret table for management node ID $management_node_id" . ($secret_id ? ", secret ID: $secret_id" : ''));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete entries from cryptsecret table for management node ID $management_node_id" . ($secret_id ? ", secret ID: $secret_id" : ''));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 call_check_crypt_secrets

 Parameters  : none
 Returns     : boolean
 Description : Calls XMLRPCcheckCryptSecrets function to update the cryptsecret
               table for the reservation.

=cut

sub call_check_crypt_secrets {
	my $reservation_id = shift;
	if (!defined($reservation_id)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	my $xmlrpc_function = 'XMLRPCcheckCryptSecrets';
	my @xmlrpc_arguments = (
		$xmlrpc_function,
		$reservation_id
	);
	
	my $response = xmlrpc_call(@xmlrpc_arguments);
	if (!defined($response)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update cryptsecret table, $xmlrpc_function returned undefined");
		return;
	}
	elsif ($response->value->{status} =~ /success/) {
		notify($ERRORS{'OK'}, 0, "called XMLRPCcheckCryptSecrets, cryptsecret table successfully updated");
	}
	elsif ($response->value->{status} =~ /noupdate/) {
		notify($ERRORS{'OK'}, 0, "called XMLRPCcheckCryptSecrets, cryptsecret table does not need to be updated");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update cryptsecret table, $xmlrpc_function returned:\n" .
			"status        : " . format_data($response->value->{status}) . "\n" .
			"error code    : " . format_data($response->value->{errorcode}) . "\n" .
			"error message : " . format_data($response->value->{errormsg})
		);
		return;
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////


1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
