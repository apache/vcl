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
our $VERSION = '2.00';

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


#use Date::Calc qw(Delta_DHMS Time_to_Date Date_to_Time);

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
  _checknstartservice
  _getcurrentimage
  _is_user_added
  _killsysprep
  _machine_os
  _pingnode
  _set_sshd_startmode
  _sshd_status
  add_user
  add_users_by_group
  changelinuxpassword
  changewindowspasswd
  check_blockrequest_time
  check_connection
  check_endtimenotice_interval
  check_ssh
  check_time
  check_uptime
  checkonprocess
  clearfromblockrequest
  collectsshkeys
  construct_image_name
  controlVM
  convert_to_datetime
  convert_to_epoch_seconds
  database_execute
  database_select
  del_user
  delete_computerloadlog_reservation
  delete_request
  disablesshd
  enablesshd
  firewall_compare_update
  format_data
  get_computer_current_state_name
  get_computer_grp_members
  get_computer_info
  get_computers_controlled_by_MN
  get_highest_imagerevision_info
  get_image_info
  get_imagemeta_info
  get_imagerevision_info
  get_ip_address_from_hosts
  get_management_node_blockrequests
  get_management_node_id
  get_management_node_info
  get_management_node_requests
  get_management_predictive_info
  get_next_image_default
  get_production_imagerevision_info
  get_request_by_computerid
  get_request_end
  get_request_info
  get_resource_groups
  get_managable_resource_groups
  get_vmhost_info
  getanothermachine
  getdynamicaddress
  getimagesize
  getnewdbh
  getpw
  getusergroupmembers
  hostname
  insert_reload_request
  insert_request
  insertloadlog
  is_inblockrequest
  is_request_deleted
  is_request_imaging
  isconnected
  isfilelocked
  kill_reservation_process
  known_hosts
  lockfile
  mail
  makedatestring
  monitorloading
  nmap_port
  notify
  notify_via_IM
  notify_via_msg
  notify_via_wall
  preplogfile
  remotedesktopport
  rename_vcld_process
  reservation_being_processed
  reservations_ready
  restoresshkeys
  round
  run_command
  run_scp_command
  run_ssh_command
  set_hash_process_id
  set_logfile_path
  setimageid
  setpreferredimage
  setstaticaddress
  string_to_ascii
  switch_state
  switch_vmhost_id
  system_monitoring
  time_exceeded
  timefloor15interval
  unlockfile
  update_blockrequest_processing
  update_cluster_info
  update_computer_address
  update_computer_state
  update_computer_lastcheck
  update_currentimage
  update_computer_imagename
  update_image_name
  update_lastcheckin
  update_log_ending
  update_log_loaded_time
  update_preload_flag
  update_request_password
  update_request_state
  update_reservation_lastcheck
  update_sublog_ipaddress
  virtual_status_unix
  virtual_status_vm
  windowsroutetable
  write_currentimage_txt

  $CONF_FILE_PATH
  $DATABASE
  $DEFAULTHELPEMAIL
  $DEFAULTURL
  $ETHDEVICE
  $FQDN
  $IDENTITY_bladerhel
  $IDENTITY_wxp
  $IDENTITY_linux_lab
  $IDENTITY_solaris_lab
  $IPCONFIGURATION
  $jabPass
  $jabPort
  $jabResource
  $jabServer
  $jabUser
  $LINUX_IMAGE
  $LINUX_IMAGEREPOSITORY
  $LOGFILE
  $MYSQL_SSL
  $MYSQL_SSL_CERT
  $PIDFILE
  $PROCESSNAME
  $WINDOWS_ROOT_PASSWORD
  $SERVER
  $SYSADMIN
  $SYSPREP
  $SYSPREP_2003
  $TESTING
  $THROTTLE
  $TOOLS
  $VERBOSE
  $VMWAREREPOSITORY
  $WRTPASS
  $WRTUSER
  %ERRORS
  %OPTIONS

  $IMAGELIBENABLE
  $IMAGELIBUSER
  $IMAGELIBKEY
  $IMAGESERVERS

  $TOOLS
  $VMWAREREPOSITORY
  $SYSPREP_2003
  $SYSPREP
  $SYSPREP_VMWARE
  $SYSPREP_VMWARE2003
  $VERBOSE
);

#our %ERRORS=('DEPENDENT'=>4,'UNKNOWN'=>3,'OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'MAILMASTERS'=>5);

BEGIN {
	#parse config file and set globals

	our ($JABBER, $jabServer, $jabUser, $jabPass, $jabResource, $jabPort) = 0;
	our ($LOGFILE, $PIDFILE, $PROCESSNAME) = 0;
	our ($DATABASE, $SERVER, $WRTUSER, $WRTPASS, $LockerRdUser, $rdPass) = 0;
	our ($SYSADMIN, $SHARED_MAILBOX, $DEFAULTURL, $DEFAULTHELPEMAIL, $RETURNPATH) = 0;
	our ($XCATROOT) = 0;
	our ($FQDN)     = 0;
	our ($MYSQL_SSL,       $MYSQL_SSL_CERT);
	our ($IPCONFIGURATION, $DNSserver, $GATEWAY, $NETMASK, $ETHDEVICE) = 0;
	our ($LINUX_IMAGE,     $THROTTLE);
	our ($CORE_IMAGEREPOSITORY, $WIN_IMAGEREPOSITORY, $LINUX_IMAGEREPOSITORY);
	our ($IDENTITY_linux_lab, $IDENTITY_solaris_lab, $IDENTITY_wxp, $IDENTITY_newwxp, $IDENTITY_bladerhel);
	our ($IMAGELIBENABLE) = 0;
	our ($IMAGESERVERS, $IMAGELIBUSER, $IMAGELIBKEY);
	our ($VMWARETYPE, $VMWARE_DISK);
	our ($WINDOWS_ROOT_PASSWORD);

	# Set Getopt pass_through so this module doesn't erase parameters that other modules may use
	Getopt::Long::Configure('pass_through');

	# Set the VERBOSE flag to 0 by default
	our ($VERBOSE) = 0;

	# Set the TESTING flag to 0 by default
	our ($TESTING) = 0;

	# Use the default configuration file path if -conf isn't specified on the command line
	our $BIN_PATH = $FindBin::Bin;
	print STDOUT "BIN PATH: $BIN_PATH\n";
	our ($CONF_FILE_PATH) = 'C:/vcldev.conf';
	if (!-f $CONF_FILE_PATH) {
		if ($BIN_PATH =~ /dev/) {
			$CONF_FILE_PATH = "/etc/vcl/vcldev.conf";
		}
		else {
			$CONF_FILE_PATH = "/etc/vcl/vcld.conf";
		}
	}

	# Store the command line options in this hash
	our %OPTIONS;

	GetOptions(\%OPTIONS, 'verbose', 'testing', 'config=s', 'logfile=s');

	# Get the command line parameters
	$CONF_FILE_PATH = $OPTIONS{config} if (defined($OPTIONS{config} && $OPTIONS{config}));

	print STDOUT "pre-execution: config file being used: $CONF_FILE_PATH\n";

	if (open(CONF, $CONF_FILE_PATH)) {
		my @conf = <CONF>;
		close(CONF);
		foreach my $l (@conf) {
			# Remove all new line and carriage return characters from the end of the line
			# Chomp doesn't always remove carriage returns
			$l =~ s/[\r\n]*$//;
			
			#logfile
			if ($l =~ /^log=(.*)/ && (!defined($LOGFILE) || !($LOGFILE))) {
				chomp($l);
				$LOGFILE = $1;
			}
			#pidfile
			if ($l =~ /^pidfile=(.*)/) {
				chomp($l);
				$PIDFILE = $1;
			}

			if ($l =~ /^DEFAULTURL=(.*)/) {
				$DEFAULTURL = $1;
			}

			if ($l =~ /^DEFAULTHELPEMAIL=(.*)/) {
				$DEFAULTHELPEMAIL = $1;
			}

			#FQDN - to many issues trying to figure out my FQDN so just tell me
			if ($l =~ /^FQDN=([-.a-zA-Z0-9]*)/) {
				$FQDN = $1;
			}

			#mysql settings
			#name of db
			if ($l =~ /^database=(.*)/) {
				$DATABASE = $1;
			}
			#name of database server
			if ($l =~ /^server=([-.a-zA-Z0-9]*)/) {
				$SERVER = $1;
			}
			#write user name
			if ($l =~ /^LockerWrtUser=(.*)/) {
				$WRTUSER = $1;
			}

			#write user password
			if ($l =~ /^wrtPass=(.*)/) {
				$WRTPASS = $1;
			}

			#read user name
			if ($l =~ /^LockerRdUser=(.*)/) {
				$LockerRdUser = $1;
			}

			#read user password
			if ($l =~ /^rdPass=(.*)/) {
				$rdPass = $1;
			}
			#is mysql ssl option enabled
			if ($l =~ /^enable_mysql_ssl=(yes)/) {
				$MYSQL_SSL = 1;
			}
			elsif ($l =~ /^enable_mysql_ssl=(no)/) {
				$MYSQL_SSL = 0;
			}

			#collect path to cert -- only valid if $MYSQL_SSL is true
			if ($l =~ /^mysql_ssl_cert=(.*)/) {
				$MYSQL_SSL_CERT = $1;
			}

			#ipconfiguration
			if ($l =~ /^ipconfiguration=(static|manualDHCP|dynamicDHCP)/) {
				$IPCONFIGURATION = $1;
			}

			if ($l =~ /^DNSserver=([,.0-9]*)/) {
				$DNSserver = $1;
			}
			if ($l =~ /^GATEWAY=([.0-9]*)/) {
				$GATEWAY = $1;
			}
			if ($l =~ /^NETMASK=([.0-9]*)/) {
				$NETMASK = $1;
			}
			if ($l =~ /^ETHDEVICE=(eth[0-9])/) {
				$ETHDEVICE = $1;
			}
			#Sysadmin list
			if ($l =~ /^sysadmin=([,-.\@a-zA-Z0-9_]*)/) {
				$SYSADMIN = $1;
			}

			#Sendmail Envelope Sender 
			if ($l =~ /^RETURNPATH=([,-.\@a-zA-Z0-9_]*)/) {
				$RETURNPATH = $1;
			}

			#sharedmailbox
			if ($l =~ /^sharedmailbox=([,-.\@a-zA-Z0-9_]*)/) {
				$SHARED_MAILBOX = $1;
			}

			#jabber - stuff
			if ($l =~ /^jabber=(yes)/) {
				$JABBER = 1;
			}
			if ($l =~ /^jabber=(no)/) {
				$JABBER = 0;
			}
			#collect remaining pieces of the jabber settings
			#$jabServer,$jabUser,$jabPass,$jabResource,$jabPort
			if ($l =~ /^jabServer=([.a-zA-Z0-9]*)/) {
				$jabServer = $1;
			}
			if ($l =~ /^jabPort=([0-9]*)/) {
				$jabPort = $1;
			}
			if ($l =~ /^jabUser=(.*)/) {
				$jabUser = $1;
			}
			if ($l =~ /^jabPass=(.*)/) {
				$jabPass = $1;
			}
			if ($l =~ /^jabResource=(.*)/) {
				$jabResource = $1;
			}

			#process name
			if ($l =~ /^processname=([-_a-zA-Z0-9]*)/) {
				$PROCESSNAME = $1;
			}

			#xcat linux image path
			# linux kernal 2.4 - we had to modify xcat to load from seperate install tree.
			if ($l =~ /^LINUXIMAGEid=(image|linux_image)/) {
				$LINUX_IMAGE = $1;
			}

			#Linux_imagerepository
			if ($l =~ /^LINUX_IMAGEREPOSITORY=([\/a-zA-Z0-9]*)/) {
				$LINUX_IMAGEREPOSITORY = $1;
			}

			#throttle
			if ($l =~ /^THROTTLE=([0-9]*)/) {
				$THROTTLE = $1;
			}

			#ssh private keys
			if ($l =~ /^IDENTITY_blade_linux=(.*)/) {
				$IDENTITY_bladerhel = $1;
			}
			if ($l =~ /^IDENTITY_blade_win=(.*)/) {
				$IDENTITY_wxp = $1;
			}
			if ($l =~ /^IDENTITY_solaris_lab=(.*)/) {
				$IDENTITY_solaris_lab = $1;
			}
			if ($l =~ /^IDENTITY_linux_lab=(.*)/) {
				$IDENTITY_linux_lab = $1;
			}

			#image library share - sync images across multiple management nodes
			# $IMAGELIBENABLE,$IMAGESERVERS,$IMAGELIBUSER,$IMAGELIBKEY
			if ($l =~ /^IMAGELIBENABLE=(yes)/) {
				$IMAGELIBENABLE = 1;
			}
			elsif ($l =~ /^IMAGELIBENABLE=(no)/) {
				$IMAGELIBENABLE = 0;
			}
			if ($l =~ /^imageservers=(.*)/) {
				$IMAGESERVERS = $1;
			}
			if ($l =~ /^imagelibuser=(.*)/) {
				$IMAGELIBUSER = $1;
			}
			if ($l =~ /^imagelibidkey=(.*)/) {
				$IMAGELIBKEY = $1;
			}
			#vmware settings
			# localdisk
			if ($l =~ /^VMWARE_DISK=(localdisk|networkdisk)/) {
				$VMWARE_DISK = $1;
			}
			
			if ($l =~ /^windows_root_password=(.*)/i) {
				$WINDOWS_ROOT_PASSWORD = $1;
			}

			if ($l =~ /^verbose=(.*)/i) {
				$VERBOSE = $1;
			}

			if ($l =~ /^test=(.*)/i) {
				$TESTING = $1;
			}
		}    # Close foreach line in conf file
	}    # Close open conf file

	else {
		die "VCLD : $CONF_FILE_PATH does not exist, exiting --  $! \n";
	}

	if (!$PROCESSNAME) {
		$PROCESSNAME = "vcld";
	}
	if (!($LOGFILE) && $LOGFILE ne '0') {
		#set default
		$LOGFILE = "/var/log/$PROCESSNAME.log";
	}

	if (!$THROTTLE) {
		$THROTTLE = 0;
	}

	if (!$IDENTITY_bladerhel) {

	}
	if (!$IDENTITY_wxp) {

	}
	if (!$IDENTITY_solaris_lab) {
	}
	if (!$IDENTITY_linux_lab) {
	}
	
	if (!$WINDOWS_ROOT_PASSWORD) {
		$WINDOWS_ROOT_PASSWORD = "clOudy";
	}

	if (!($FQDN)) {
		print STDOUT "FQDN is not listed\n";
	}
	if (!($PIDFILE)) {
		#set default
		$PIDFILE = "/var/run/$PROCESSNAME.pid";
	}
	if (!($RETURNPATH)){
		$RETURNPATH="";
	}
	if (!$IPCONFIGURATION) {
		#default
		$IPCONFIGURATION = "manualDHCP";
	}
	elsif ($IPCONFIGURATION eq "static") {
		#check for dependiencies
		if (!$DNSserver) {
			print STDOUT "pre-execution: ipconfiguration is $IPCONFIGURATION dnsserver setting is missing in configuration file\n";
		}
		if (!$GATEWAY) {
			print STDOUT "pre-execution: ipconfiguration is $IPCONFIGURATION gateway setting is missing in configuration file\n";
		}
		if (!$NETMASK) {
			print STDOUT "pre-execution: ipconfiguration is $IPCONFIGURATION netmask setting is missing in configuration file\n";
		}
	} ## end elsif ($IPCONFIGURATION eq "static")  [ if (!$IPCONFIGURATION)

	if (!$LINUX_IMAGE) {
		$LINUX_IMAGE = "image";
	}

	if ($JABBER) {
		#jabber is enabled - import required jabber module
		# todo - check if Jabber module is installed
		# i.e. perl -MNet::Jabber -e1
		# check version -- perl -MNet::Jabber -e'print $Net::Jabber::VERSION\n";'
		require "Net/Jabber.pm";
		import Net::Jabber qw(client);
	}

	# Get the remaining command line parameters
	$VERBOSE = $OPTIONS{verbose} if (defined($OPTIONS{verbose} && $OPTIONS{verbose}));
	$TESTING = $OPTIONS{testing} if (defined($OPTIONS{testing} && $OPTIONS{testing}));
	$LOGFILE = $OPTIONS{logfile} if (defined($OPTIONS{logfile} && $OPTIONS{logfile}));

	print STDOUT "pre-execution: process name is set to: $PROCESSNAME\n";
	print STDOUT "pre-execution: verbose mode is set to: $VERBOSE\n";
	print STDOUT "pre-execution: testing mode is set to: $TESTING\n";
	print STDOUT "pre-execution: log file being used: $LOGFILE\n";
	print STDOUT "pre-execution: PID file being used: $PIDFILE\n";
} ## end BEGIN


#use Net::Jabber qw(Client);
our ($JABBER, $PROCESSNAME);
our %ERRORS = ('DEPENDENT' => 4, 'UNKNOWN' => 3, 'OK' => 0, 'WARNING' => 1, 'CRITICAL' => 2, 'MAILMASTERS' => 5, 'DEBUG' => 6);
our ($LockerWrtUser, $wrtPass,  $database,       $server);
our ($jabServer,     $jabUser,  $jabPass,        $jabResource, $jabPort);
our ($vcldquerykey,  $SYSADMIN, $SHARED_MAILBOX, $DEFAULTURL, $DEFAULTHELPEMAIL,$RETURNPATH);
our ($LOGFILE, $PIDFILE, $VCLDRPCQUERYKEY);
our ($SERVER, $DATABASE, $WRTUSER, $WRTPASS);
our ($MYSQL_SSL,       $MYSQL_SSL_CERT);
our ($IPCONFIGURATION, $DNSserver, $GATEWAY, $NETMASK, $ETHDEVICE);
our ($LINUX_IMAGE,     $THROTTLE);
our ($FQDN);
our ($IDENTITY_linux_lab, $IDENTITY_solaris_lab, $IDENTITY_wxp, $IDENTITY_bladerhel);
our ($IMAGELIBENABLE,     $IMAGESERVERS,         $IMAGELIBUSER, $IMAGELIBKEY);
our ($VMWARE_DISK);
our $IDENTITY_newwxp    = "$FindBin::Bin/../lib/VCL/newwinxp_blade.key";
our $XCATROOT           = "/opt/xcat";
our $TOOLS              = "$FindBin::Bin/../tools";
our $VMWAREREPOSITORY   = "/install/vmware_images";
our $SYSPREP_2003       = "$TOOLS/Sysprep_2003";
our $SYSPREP            = "$TOOLS/Sysprep";
our $SYSPREP_VMWARE     = "$TOOLS/Sysprep_vmware";
our $SYSPREP_VMWARE2003 = "$TOOLS/Sysprep_vmware2003";
our $VERBOSE;
our $TESTING;
our $CONF_FILE_PATH;
our $WINDOWS_ROOT_PASSWORD;

sub makedatestring;

#/////////////////////////////////////////////////////////////////////////////

=head2 preplogfile

 Parameters  : nothing
 Returns     : nothing
 Description : writes header to global log file

=cut

sub preplogfile {
	my $currenttime = makedatestring();
	my ($package, $filename, $line, $sub) = caller(0);
	$filename =~ s(^.*/)();    #remove leading path from filename
	                           # print initial info to log file
	print STDERR "===========================================================\n";
	print STDERR "OUTPUT for $filename run on $currenttime\n";
	print STDERR "===========================================================\n";
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
	my $LOG    = shift;
	my $string = shift;
	my @data   = @_;

	# Just return if DEBUG and verbose isn't enabled
	return if ($error == 6 && !$VERBOSE);

	# Get the current time
	my $currenttime = makedatestring();

	# Redirect STDOUT and STDERR to the log file
	$LOG = $LOGFILE if (!$LOG);
	open(STDOUT, ">>$LOG") if $LOG;
	open(STDERR, ">>$LOG") if $LOG;

	# Get info about the subroutine which called this subroutine
	my ($package, $filename, $line, $sub) = caller(0);

	# Remove leading path from filename
	$filename =~ s/.*\///;

	# Remove the leading package path from the sub name (VC::...)
	$sub =~ s/.*:://;

	# Assemble the caller information
	my $caller_info;
	if (caller(1)) {
		my ($caller_previous_package, $caller_previous_filename, $caller_previous_line, $caller_previous_sub) = caller(1);
		$caller_previous_filename =~ s/.*\///;
		$caller_previous_sub      =~ s/.*:://;
		$caller_info = "$filename:$caller_previous_sub($line)";
	}
	else {
		$caller_info = "$filename:$sub($line)";
	}

	# Get the caller trace information
	my $caller_trace = get_caller_trace(6);
	
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
	if ($string !~ /[\'\"]/gs) {
		$string =~ s/[ \t]+/ /gs;
	}

	# Assemble the process identifier string
	my $process_identifier = $PID;
	$process_identifier .= "|$ENV{request_id}:$ENV{reservation_id}" if (defined $ENV{request_id} && defined $ENV{reservation_id});
	$process_identifier .= "|$ENV{state}" if (defined $ENV{state});

	# Assemble the log message
	my $log_message = "$currenttime|$process_identifier|$caller_info|$string";

	# Format the data if WARNING or CRITICAL, and @data was passed
	my $formatted_data;
	if (@data && ($error == 1 || $error == 2)) {
		# Add the data to the message body if it was passed
		$formatted_data = "DATA:\n" . format_data(\@data, 'DATA');
		chomp $formatted_data;
	}

	# Assemble an email message body if CRITICAL
	my $body;
	if ($error == 2 ) {
		# Get the previous several log file entries for this process
		my $log_history_count = 100;
		my $log_history       = "RECENT LOG ENTRIES FOR THIS PROCESS:\n";
		$log_history .= `grep "|$PID|" $LOG | tail -n $log_history_count`;
		chomp $log_history;

		# Assemble the e-mail message body
		$body = <<"END";
$string

Time: $currenttime
PID: $PID
Caller: $caller_info

$caller_trace

$log_history
END

		# Add the formatted data to the message body if data was passed
		$body .= "\n\n$formatted_data\n" if $formatted_data;
	} ## end if ($error == 2) 


	# OK, VERBOSE
	if (!$error || ($error == 6 && $VERBOSE)) {

	}

	# WARNING
	if ($error == 1) {
		$log_message = "\n---- WARNING ---- \n$log_message\n$caller_trace\n\n";
	}

	# CRITICAL
	elsif ($error == 2) {
		$log_message = "\n---- CRITICAL ---- \n$log_message\n$caller_trace\n";
		$log_message .= "$formatted_data\n" if $formatted_data;
		$log_message .= "\n";

		my $from    = "root\@$FQDN";
		my $to      = $SYSADMIN;
		my $subject = "PROBLEM -- $filename";
		mail($to, $subject, $body, $from);
	} ## end elsif ($error == 2)  [ if ($error == 1)

	# MAILMASTERS - only for email notifications
	elsif ($error == 5 && $SHARED_MAILBOX) {
		my $to      = $SHARED_MAILBOX;
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
	$log_message =~ s/\n([^\n])/\n|$process_identifier| $1/g;

	# Print the log message to the log file
	print STDOUT "$log_message\n";

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
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "endtime not set") if (!defined($end));
	my $now      = time();
	my $epochend = convert_to_epoch_seconds($end);
	#flag on: 2 & 1 week; 2,1 day, 1 hour, 30,15,10,5 minutes
	#2 week: between 14 days and a 14 day -15 minutes window
	if ($epochend <= (14 * 60 * 60 * 24) && $epochend >= (14 * 60 * 60 * 24 - 15 * 60)) {
		return (1, "2week");
	}
	#1 week: between 7 days and a 14 day -15 minute window
	elsif ($epochend <= (7 * 60 * 60 * 24) && $epochend >= (7 * 60 * 60 * 24 - 15 * 60)) {
		return (1, "1week");
	}
	#2 day: between 2 days and a 2 day -15 minute window
	if ($epochend <= (2 * 60 * 60 * 24) && $epochend >= (2 * 60 * 60 * 24 - 15 * 60)) {
		return (1, "2day");
	}
	#1 day: between 1 days and a 1 day -15 minute window
	if ($epochend <= (1 * 60 * 60 * 24) && $epochend >= (1 * 60 * 60 * 24 - 15 * 60)) {
		return (1, "1day");
	}
	#30-25 minutes
	if ($epochend <= (30 * 60) && $epochend >= (25 * 60)) {
		return (1, "30min");
	}
} ## end sub check_endtimenotice_interval
#sub new_check_endtimenotice_interval {
#	 my ($request_end, $base_time) = @_;
#	 my ($package, $filename, $line, $sub) = caller(0);
#
#	# Check the parameter
#	if (!defined($request_end)) {
#		notify($ERRORS{'WARNING'}, 0, "request end time was not specified"");
#		return 0;
#	 }
#	elsif (!$request_end) {
#		notify($ERRORS{'WARNING'}, 0, "request end time was specified but is blank"");
#		return 0;
#	 }
#
#	# Convert the request end time to epoch seconds
#	 my $end_epoch_seconds = convert_to_epoch_seconds($request_end);
#
#	# This is only used for testing
#	my @now;
#	if ($base_time) {
#		my $base_epoch_seconds = convert_to_epoch_seconds($base_time);
#		@now = Time_to_Date($base_epoch_seconds);
#	 }
#	else {
#		@now = Time_to_Date();
#	 }
#
#	# Get arrays from the Date::Calc::Time_to_Date functions for now and the end time
#	my @end = Time_to_Date($end_epoch_seconds);
#
#	# Calculate the difference
#	my ($days, $hours, $minutes, $seconds) = Delta_DHMS(@now, @end);
#
#	 # Return a value on: 2 & 1 week; 2,1 day, 1 hour, 30,15,10,5 minutes
#	my $return_value = 0;
#
#	# Ignore: over 14 days away
#	 if ($days >= 14){
#	    $return_value = 0;
#	 }
#	# 2 week notice: between 14 days and a 14 day - 15 minute window
#	elsif ($days >= 13 && $hours >= 23 && $minutes >= 45){
#	    $return_value = "2 weeks";
#	 }
#	# Ignore: between 7 days and 14 day - 15 minute window
#	elsif ($days >= 7) {
#		$return_value = 0;
#	}
#	 # 1 week notice: between 7 days and a 7 day -15 minute window
#	 elsif ($days >= 6 && $hours >= 23 && $minutes >= 45) {
#	    $return_value = "1 week";
#	 }
#	# Ignore: between 2 days and 7 day - 15 minute window
#	elsif ($days >= 2) {
#		$return_value = 0;
#	}
#	 # 2 day notice: between 2 days and a 2 day -15 minute window
#	 elsif($days >= 1 && $hours >= 23 && $minutes >= 45) {
#	    $return_value = "2 days";
#	 }
#	# Ignore: between 1 days and 2 day - 15 minute window
#	elsif ($days >= 1) {
#		$return_value = 0;
#	}
#	 # 1 day notice: between 1 days and a 1 day -15 minute window
#	 elsif($days >= 0 && $hours >= 23 && $minutes >= 45) {
#	    $return_value = "1 day";
#	 }
#	 #30-25 minutes
#	 elsif ($minutes >= 25 && $minutes <= 30) {
#	    $return_value = "30 minutes";
#	 }

#	notify($ERRORS{'OK'}, 0, "days: time difference is days:$days hours:$hours minutes:$minutes, returning $return_value");
#	return $return_value;
#}

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

	# 4:00 to 4:15 hours in advance: start assigning resources
	if ($start_delta_minutes >= (4 * 60) && $start_delta_minutes <= (4 * 60 + 10)) {
		# Block request within start window
		notify($ERRORS{'OK'}, 0, "block request start time is within start window ($start_delta_minutes minutes from now), returning 'start'");
		return "start";
	}

	# 2:00 to 2:15 hours in advance: start assigning resources
	if ($start_delta_minutes >= (2 * 60) && $start_delta_minutes <= (2 * 60 + 10)) {
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

	my ($package, $filename, $line, $sub) = caller(0);

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
	if ($request_state_name =~ /new|imageprep|reload|tomaintenance|tovmhostinuse/) {
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
	} ## end if ($request_state_name =~ /new|imageprep|reload|tomaintenance|tovmhostinuse/)

	elsif ($request_state_name =~ /inuse|imageinuse/) {
		if ($end_diff_minutes <= 10) {
			#notify($ERRORS{'DEBUG'}, 0, "reservation will end in 10 minutes or less ($end_diff_minutes)");
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

=head2 time_exceeded

 Parameters  : $time_slice, $limit
 Returns     : 1(success) or 0(failure)
 Description : preform a difference check,
					if delta of now and input $time_slice
					is less than input $limit return 1(true)
=cut

sub time_exceeded {

	my ($time_slice, $limit) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	my $now  = time();
	my $diff = $now - $time_slice;
	if ($diff > ($limit * 60)) {
		#time  exceeded
		return 1;
	}
	else {
		return 0;
	}
} ## end sub time_exceeded

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
	my $localreturnpath = "-f $RETURNPATH";
	my $mailer = Mail::Mailer->new("sendmail", $localreturnpath);

	if ($SHARED_MAILBOX) {
		my $bcc = $SHARED_MAILBOX;
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
	} ## end if ($SHARED_MAILBOX)
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
	} ## end else [ if ($SHARED_MAILBOX)
} ## end sub mail

#/////////////////////////////////////////////////////////////////////////////

=head2 setstaticaddress

 Parameters  : $node, $osname, $IPaddress
 Returns     : 1,0 -- success failure
 Description : assigns statically assigned IPaddress
=cut

sub setstaticaddress {
	my ($node, $osname, $image_os_type, $IPaddress) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'},       0, "nodename not set")  if (!defined($node));
	notify($ERRORS{'OK'},       0, "osname not set")    if (!defined($osname));
	notify($ERRORS{'CRITICAL'}, 0, "IPaddress not set") if (!defined($IPaddress));
	#collect private address -- read hosts file only useful if running
	# xcat setup and private addresses are listsed in the local
	# /etc/hosts file
	#should also store/pull private address from the database
	my $privateIP;
	if (open(HOSTS, "/etc/hosts")) {
		my @hosts = <HOSTS>;
		close(HOSTS);
		foreach my $line (@hosts) {
			if ($line =~ /([0-9]*.[0-9]*.[0-9]*.[0-9]*)\s+($node)/) {
				$privateIP = $1;
				notify($ERRORS{'OK'}, 0, "PrivateIP address for $node collected $privateIP");
				last;
			}
		}
	} ## end if (open(HOSTS, "/etc/hosts"))
	if (!defined($privateIP)) {
		notify($ERRORS{'WARNING'}, 0, "private IP address not found for $node, possible issue with regex");

	}

	my $identity;
	my @sshcmd;
	if ($image_os_type =~ /linux/i) {
		$identity = $IDENTITY_bladerhel;
		#create local tmp file
		# down interface
		#copy tmpfile to  /etc/sysconfig/network-scripts/ifcfg-eth1
		# up interface
		#set route for correct gateway
		my @eth1file;
		my $tmpfile = "/tmp/ifcfg-eth_device-$node";
		push(@eth1file, "DEVICE=eth1\n");
		push(@eth1file, "BOOTPROTO=static\n");
		push(@eth1file, "IPADDR=$IPaddress\n");
		push(@eth1file, "NETMASK=$NETMASK\n");
		push(@eth1file, "STARTMODE=onboot\n");
		push(@eth1file, "ONBOOT=yes\n");

		#write to tmpfile
		if (open(TMP, ">$tmpfile")) {
			print TMP @eth1file;
			close(TMP);
		}
		else {
			#print "could not write $tmpfile $!\n";

		}
		@sshcmd = run_ssh_command($node, $identity, "/etc/sysconfig/network-scripts/ifdown $ETHDEVICE", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "sshcmd outpuer ifdown $node $l");
			}
		}
		#copy new ifcfg-Device
		if (run_scp_command($tmpfile, "$node:/etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE", $identity)) {

			#confirm it got there
			undef @sshcmd;
			@sshcmd = run_ssh_command($node, $identity, "cat /etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE", "root");
			my $success = 0;
			foreach my $i (@{$sshcmd[1]}) {
				if ($i =~ /$IPaddress/) {
					notify($ERRORS{'OK'}, 0, "SUCCESS - copied ifcfg_$ETHDEVICE\n");
					$success = 1;
				}
			}
			if (unlink($tmpfile)) {
				notify($ERRORS{'OK'}, 0, "unlinking $tmpfile");
			}

			if (!$success) {
				notify($ERRORS{'WARNING'}, 0, "unable to copy $tmpfile to $node file ifcfg-$ETHDEVICE did get updated with $IPaddress ");
				return 0;
			}
		} ## end if (run_scp_command($tmpfile, "$node:/etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE"...

		#bring device up
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "/etc/sysconfig/network-scripts/ifup $ETHDEVICE", "root");
		#should be empty
		foreach my $l (@{$sshcmd[1]}) {
			if ($l) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "possible problem with ifup $ETHDEVICE $l");
			}
		}
		#correct route table - delete old default and add new in same line
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "/sbin/route del default", "root");
		#should be empty
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /Usage:/) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "possible problem with route del default $l");
			}
			if ($l =~ /No such process/) {
				notify($ERRORS{'OK'}, 0, "$l - ok  just no default route since we downed eth device");
			}
		}

		notify($ERRORS{'OK'}, 0, "Setting default route");
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "/sbin/route add default gw $GATEWAY metric 0 $ETHDEVICE", "root");
		#should be empty
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /Usage:/) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "possible problem with route add default gw $GATEWAY metric 0 $ETHDEVICE");
			}
			if ($l =~ /No such process/) {
				notify($ERRORS{'CRITICAL'}, 0, "problem with $node $l add default gw $GATEWAY metric 0 $ETHDEVICE ");
				return 0;
			}
		} ## end foreach my $l (@{$sshcmd[1]})

		#correct external sshd file
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "cat /etc/ssh/external_sshd_config", "root");
		foreach my $i (@{$sshcmd[1]}) {
			if ($i =~ /No such file or directory/) {
				notify($ERRORS{'OK'}, 0, "possible problem $i could not read $node /etc/ssh/external_sshd_config");
				#problem
			}

			if ($i =~ s/ListenAddress (.*)/ListenAddress $IPaddress/) {
				notify($ERRORS{'OK'}, 0, "changed Listen Address on $node");
			}

		} ## end foreach my $i (@{$sshcmd[1]})

		#Write contents to tmp file
		my $extsshtmpfile = "/tmp/extsshtmpfile$node";
		if (open(TMPFILE, ">$extsshtmpfile")) {
			print TMPFILE @{$sshcmd[1]};
			close(TMPFILE);
		}
		else {
			notify($ERRORS{'OK'}, 0, "could not write tmpfile $extsshtmpfile $!");
		}

		#copy back to host
		if (run_scp_command($extsshtmpfile, "$node:/etc/ssh/external_sshd_config", $identity)) {
			notify($ERRORS{'OK'}, 0, "success copied $extsshtmpfile to $node");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not write copy $extsshtmpfile to $node");
		}
		if (unlink($extsshtmpfile)) {
			notify($ERRORS{'OK'}, 0, "unlinking $extsshtmpfile");
		}

		#modify /etc/resolve.conf
		my $search;
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "cat /etc/resolv.conf", "root");
		foreach my $l (@{$sshcmd[1]}) {
			chomp($l);
			if ($l =~ /search/) {
				$search = $l;
			}
		}

		if (defined($search)) {
			my @resolvconf;
			push(@resolvconf, "$search\n");
			my ($s1, $s2, $s3);
			if ($DNSserver =~ /,/) {
				($s1, $s2, $s3) = split(/,/, $DNSserver);
			}
			else {
				$s1 = $DNSserver;
			}
			push(@resolvconf, "nameserver $s1\n");
			push(@resolvconf, "nameserver $s2\n") if (defined($s2));
			push(@resolvconf, "nameserver $s3\n") if (defined($s3));
			my $rtmpfile = "/tmp/resolvconf$node";
			if (open(RES, ">$rtmpfile")) {
				print RES @resolvconf;
				close(RES);
			}
			else {
				notify($ERRORS{'OK'}, 0, "could not write to $rtmpfile $!");
			}
			#put resolve.conf  file back on node
			notify($ERRORS{'OK'}, 0, "copying in new resolv.conf");
			if (run_scp_command($rtmpfile, "$node:/etc/resolv.conf", $identity)) {
				notify($ERRORS{'OK'}, 0, "SUCCESS copied new resolv.conf to $node");
			}
			else {
				notify($ERRORS{'OK'}, 0, "FALIED to copied new resolv.conf to $node");
				return 0;
			}

			if (unlink($rtmpfile)) {
				notify($ERRORS{'OK'}, 0, "unlinking $rtmpfile");
			}
		} ## end if (defined($search))
		else {
			notify($ERRORS{'WARNING'}, 0, "pulling resolve.conf from $node failed output= @{ $sshcmd[1] }");
		}
	} ## end if 
	#elsif ($osname =~ 
	elsif ($image_os_type =~ /windows/i) {
		$identity = $IDENTITY_wxp;
		#scan adapter list to figure out which adapter is public
		# run netsh command to set the public adapter to static
		# correct the route table

		my $myadapter;
		my %ip;
		my ($privateadapter, $publicadapter);
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "ipconfig -all", "root");
		# build hash of needed info and set the correct private adapter.
		my $id = 1;
		foreach my $a (@{$sshcmd[1]}) {
			if ($a =~ /Ethernet adapter (.*):/) {
				$myadapter                 = $1;
				$ip{$myadapter}{"id"}      = $id;
				$ip{$myadapter}{"private"} = 0;
			}
			if ($a =~ /IP Address([\s.]*): $privateIP/) {
				$ip{$myadapter}{"private"} = 1;
			}
			if ($a =~ /Physical Address([\s.]*): ([-0-9]*)/) {
				$ip{$myadapter}{"MACaddress"} = $2;
			}

			$id++;
		} ## end foreach my $a (@{$sshcmd[1]})


		foreach my $key (keys %ip) {
			if (defined($ip{$key}{private})) {
				if (!($ip{$key}{private})) {
					$publicadapter = "\"$key\"";
				}
			}
		}

		#Make sure we have publicadapter defined
		if (!defined($publicadapter)) {
			notify($ERRORS{'WARNING'}, 0, "publicadapter not detected from $node");
			return 0;
		}

		#setting publicadapter to static
		notify($ERRORS{'OK'}, 0, "executing netsh interface ip set address name=\\\"$publicadapter\\\" source=static addr=$IPaddress mask=$NETMASK gateway=$GATEWAY gwmetric=2\n");
		undef @sshcmd;
		my $cmdstring = "netsh interface ip set address name=\\\"$publicadapter\\\" source=static addr=$IPaddress mask=$NETMASK gateway=$GATEWAY gwmetric=2";
		@sshcmd = run_ssh_command($node, $identity, $cmdstring, "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /Ok/) {
				notify($ERRORS{'OK'}, 0, "successfully set  $publicadapter to static");
			}
		}

		#set dns
		my ($s1, $s2, $s3);
		if ($DNSserver =~ /,/) {
			($s1, $s2, $s3) = split(/,/, $DNSserver);
		}
		else {
			$s1 = $DNSserver;
		}
		notify($ERRORS{'OK'}, 0, "executing setting DNS netsh interface ip set dns name=\\\"$publicadapter\\\" source=static addr=$s1 register=none\n");
		undef @sshcmd;
		$cmdstring = "netsh interface ip set dns name=\\\"$publicadapter\\\" source=static addr=$s1 register=none";
		@sshcmd = run_ssh_command($node, $identity, $cmdstring, "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /Ok/) {
				notify($ERRORS{'OK'}, 0, "successfully set dns $publicadapter ");
			}
		}

		#correct route table - delete old default and add new in same line
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "route del 0.0.0.0", "root");
		#should be empty
		foreach my $l (@{$sshcmd[1]}) {
			if ($l) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "possible problem with route del default $l");
			}
		}

		notify($ERRORS{'OK'}, 0, "Setting default route");
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "route -p ADD 0.0.0.0 MASK 0.0.0.0 $GATEWAY METRIC 2", "root");
		#should be empty
		foreach my $l (@{$sshcmd[1]}) {
			if ($l) {
				#potential problem
				notify($ERRORS{'OK'}, 0, "possible problem with route add default gw $GATEWAY metric 0 $ETHDEVICE");
			}
		}

	} ## end elsif 
	else {

		# osname not defined
	}


} ## end sub setstaticaddress

#/////////////////////////////////////////////////////////////////////////////

=head2 getdynamicaddress

 Parameters  : $node, $osname
 Returns     : assigned ipaddress
 Description : collects the dynamically assigned ipaddress
=cut

sub getdynamicaddress {
	my ($node, $osname, $image_os_type) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'}, 0, "nodename not set") if (!defined($node));
	notify($ERRORS{'OK'}, 0, "osname not set")   if (!defined($osname));
	notify($ERRORS{'OK'}, 0, "image_os_type not set")   if (!defined($image_os_type));

	#collect private address -- read hosts file only useful if running
	# xcat setup and private addresses are listsed in the local
	# /etc/hosts file
	#should also store/pull private address from the database
	my $privateIP;
	my @sshcmd;
	if (open(HOSTS, "/etc/hosts")) {
		my @hosts = <HOSTS>;
		close(HOSTS);
		foreach my $line (@hosts) {
			if ($line =~ /([0-9]*.[0-9]*.[0-9]*.[0-9]*)\s+($node)/) {
				$privateIP = $1;
				notify($ERRORS{'OK'}, 0, "PrivateIP address for $node collected $privateIP");
				last;
			}
		}
	} ## end if (open(HOSTS, "/etc/hosts"))
	if (!defined($privateIP)) {
		notify($ERRORS{'WARNING'}, 0, "private IP address not found for $node, possible issue with regex");
	}

	my $identity;
	my $dynaIPaddress = 0;
	my $ip_address;
	if ($image_os_type =~ /windows/i) {
		$identity = $IDENTITY_wxp;

		@sshcmd = run_ssh_command($node, $identity, "ipconfig", "root");
		for my $l (@{$sshcmd[1]}) {
			# skip class a,b,c private addresses
                        next if ($l !~ /IP(.*)?Address[\s\.:]*([\d\.]*)/);
                        my $ip_address_found = $2;
                        next if ($ip_address && $ip_address_found =~ /^(10|127|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\./);
                        next if ($ip_address_found =~ /$privateIP/);
                        $ip_address = $ip_address_found;
                }
                $dynaIPaddress = $ip_address;

	} ## end if ($osname =~ /windows/)
	elsif ($image_os_type =~ /linux/) {
		$identity = $IDENTITY_bladerhel;
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $identity, "/sbin/ifconfig \|grep inet", "root");
		for my $l (@{$sshcmd[1]}) {
			# skip class a,b,c private addresses
			next if ($l !~ /inet addr:([\d\.]*)/);
                        my $ip_address_found = $1;
                        next if ($ip_address && $ip_address_found =~ /^(10|127|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\./);
                        next if ($ip_address_found =~ /$privateIP/);
                        $ip_address = $ip_address_found;
		}
		$dynaIPaddress = $ip_address;

	} ## end elsif ($image_os_type =~ /linux/)  [ if ($image_os_type =~ /windows/)
	else {
		notify($ERRORS{'WARNING'}, 0, "OStype $image_os_type not supported ");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "dynamic IP address for $node collected: $dynaIPaddress");
	return $dynaIPaddress;

} ## end sub getdynamicaddress

#/////////////////////////////////////////////////////////////////////////////

=head2 _set_sshd_startmode

 Parameters  : $node, $mode
 Returns     : 1 or 0
 Description : sets the sshd service on winxp images to auto or manual
=cut

sub _set_sshd_startmode {
	my ($node, $mode) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'}, 0, "nodename not set")  if (!defined($node));
	notify($ERRORS{'OK'}, 0, "ipaddress not set") if (!defined($mode));

	#specific to sc command
	$mode = "demand" if ($mode eq "manual");

	# start using sc to change the start mode
	my $cmd = "cmd /c C:\/WINDOWS\/system32\/sc config sshd start= $mode";
	my @SC = run_ssh_command($node, $IDENTITY_wxp, $cmd);
	for my $line (@{$SC[1]}) {
		if ($line =~ /ChangeServiceConfig SUCCESS/) {
			notify($ERRORS{'OK'}, 0, "successfully set sshd on $node to $mode");
			return 1;
		}
	}
	notify($ERRORS{'WARNING'}, 0, "_set_sshd_startmode failed return status $SC[0] array= @{ $SC[1] }");

	return 0;
} ## end sub _set_sshd_startmode

#/////////////////////////////////////////////////////////////////////////////

=head2 _checknstartservice

 Parameters  : $service name
 Returns     : 1 or 0
 Description : checks for running local service attempts to restart
					xCAT specific
=cut

sub _checknstartservice {
	my $service = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'}, 0, "service not set") if (!defined($service));
	my $status = 0;
	if (open(SERVICE, "/sbin/service $service status |")) {
		while (<SERVICE>) {
			chomp($_);
			#notify($ERRORS{'OK'},0,"_checknstartservice: $_");
			if ($_ =~ /running/) {
				$status = 1;
				notify($ERRORS{'OK'}, 0, "_checknstartservice: $service is running");
			}
		}
		close(SERVICE);
		if ($status == 1) {
			return 1;
		}
		else {
			notify($ERRORS{'OK'}, 0, "_checknstartservice: $service is not running will try to start");
			# try to start service
			if (open(SERVICE, "/sbin/service $service start |")) {
				while (<SERVICE>) {
					chomp($_);
					notify($ERRORS{'WARNING'}, 0, "_checknstartservice: $_");
					if ($_ =~ /started/) {
						$status = 1;
						last;
					}
				}
				close(SERVICE);
				if ($status == 1) {
					return 1;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "_checknstartservice: $service could not start");
					return 0;
				}
			} ## end if (open(SERVICE, "/sbin/service $service start |"...
			else {
				notify($ERRORS{'WARNING'}, 0, "_checknstartservice: WARNING -- could not run service command for $service start. $! ");
				return 0;
			}
		} ## end else [ if ($status == 1)
	} ## end if (open(SERVICE, "/sbin/service $service status |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "_checknstartservice: WARNING -- could not run service command for $service check. $! ");
		return 0;
	}
} ## end sub _checknstartservice

#/////////////////////////////////////////////////////////////////////////////

=head2 check_connection

 Parameters  : $nodename, $ipaddress, $type, $remoteIP, $time_limit, $osname, $dbh, $requestid, $user
 Returns     : value - deleted  failed timeout connected  conn_wrong_ip
 Description : uses ssh to log into remote node and preform checks on user connection
=cut

sub check_connection {
	my ($nodename, $ipaddress, $type, $remoteIP, $time_limit, $osname, $dbh, $requestid, $user,$image_os_type) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'}, 0, "nodename not set")   if (!defined($nodename));
	notify($ERRORS{'OK'}, 0, "ipaddress not set")  if (!defined($ipaddress));
	notify($ERRORS{'OK'}, 0, "type not set")       if (!defined($type));
	notify($ERRORS{'OK'}, 0, "remoteIP not set")   if (!defined($remoteIP));
	notify($ERRORS{'OK'}, 0, "time_limit not set") if (!defined($time_limit));
	notify($ERRORS{'OK'}, 0, "osname not set")     if (!defined($osname));
	notify($ERRORS{'OK'}, 0, "dbh not set")        if (!defined($dbh));
	notify($ERRORS{'OK'}, 0, "requestid not set")  if (!defined($requestid));
	notify($ERRORS{'OK'}, 0, "user not set")       if (!defined($user));
	notify($ERRORS{'OK'}, 0, "image_os_type not set")       if (!defined($image_os_type));

	my $start_time    = time();
	my $time_exceeded = 0;
	my $break         = 0;
	my $ret_val       = "no";

	$dbh = getnewdbh() if !$dbh;
	my $identity;
	if ($image_os_type =~ /windows/i) {
		$identity = $IDENTITY_wxp;
	}
	elsif ($image_os_type =~ /linux/i) {
		$identity = $IDENTITY_bladerhel;
	}
	else {
		$identity = $IDENTITY_bladerhel;
	}
	# Figure out number of loops for log messates
	my $maximum_loops = $time_limit * 2;
	my $loop_count    = 0;
	my @SSHCMD;

	while (!$break) {
		$loop_count++;

		notify($ERRORS{'OK'}, 0, "checking for connection by $user on $nodename, attempt $loop_count ");

		# confirm we still have an active db handle
		if (!$dbh || !($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'}, 0, "database handle re-set") if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "inuse process: database handle NOT re-set") if (!($dbh->ping));
		}
		if (is_request_deleted($requestid)) {
			notify($ERRORS{'OK'}, 0, "user has deleted request");
			$break   = 1;
			$ret_val = "deleted";
			return $ret_val;
		}
		#notify($ERRORS{'OK'},0,"comparing wait time for connection");
		$time_exceeded = time_exceeded($start_time, $time_limit);
		if ($time_exceeded) {
			notify($ERRORS{'OK'}, 0, "$time_limit minute time limit exceeded begin cleanup process");
			#time_exceeded, begin cleanup process
			$break = 1;
			if ($package =~ /reserved/) {
				notify($ERRORS{'OK'}, 0, "user never logged in returning nologin");
				$ret_val = "nologin";
			}
			else {
				$ret_val = "timeout";
			}
			return $ret_val;
		} ## end if ($time_exceeded)
		else {    #time not exceeded check for connection
			if ($type =~ /blade|virtualmachine/) {
				my $shortnodename = $nodename;
				$shortnodename = $1 if ($nodename =~ /([-_a-zA-Z0-9]*)\./);
				if ($image_os_type =~ /windows/i) {
					undef @SSHCMD;
					@SSHCMD = run_ssh_command($shortnodename, $identity, "netstat -an", "root", 22, 1);
					foreach my $line (@{$SSHCMD[1]}) {
						#check for rdp and ssh connections
						# rdp:3389,ssh:22
						#check for connection refused, if ssh is gone something
						#has happenned put in timeout state
						if ($line =~ /Connection refused|Permission denied/) {
							chomp($line);
							notify($ERRORS{'WARNING'}, 0, "$line");
							if ($package =~ /reserved/) {
								$ret_val = "failed";
							}
							else {
								$ret_val = "timeout";
							}
							return $ret_val;
						} ## end if ($line =~ /Connection refused|Permission denied/)
						if ($line =~ /\s+($ipaddress:3389)\s+([.0-9]*):([0-9]*)\s+(ESTABLISHED)/) {
							if ($2 eq $remoteIP) {
								$break   = 1;
								$ret_val = "connected";
								return $ret_val;
							}
							else {
								#this isn't the remoteIP
								$ret_val = "conn_wrong_ip";
								return $ret_val;
							}
						} ## end if ($line =~ /\s+($ipaddress:3389)\s+([.0-9]*):([0-9]*)\s+(ESTABLISHED)/)
					}    #foreach

				} ## end if ($osname =~ /win|vmwarewin/)
				elsif ($image_os_type =~ /linux/i) {
					#run two checks
					# 1:check connected IP address
					# 2:simply check who ouput
					my @lines;
					undef @SSHCMD;
					@SSHCMD = run_ssh_command($shortnodename, $identity, "netstat -an", "root", 22, 1);
					foreach my $line (@{$SSHCMD[1]}) {
						if ($line =~ /Connection refused|Permission denied/) {
							chomp($line);
							notify($ERRORS{'WARNING'}, 0, "$line");
							if ($package =~ /reserved/) {
								$ret_val = "failed";
							}
							else {
								$ret_val = "timeout";
							}
							return $ret_val;
						} ## end if ($line =~ /Connection refused|Permission denied/)
						if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
							if ($4 eq $remoteIP) {
								$break   = 1;
								$ret_val = "connected";
								return $ret_val;
							}
							else {
								#this isn't the remoteIP
								$ret_val = "conn_wrong_ip";
								return $ret_val;
							}
						}    # tcp check
					}    #foreach
					     #who; too make sure we didn't miss it through netstat
					undef @SSHCMD;
					@SSHCMD = run_ssh_command($shortnodename, $identity, "who", "root");
					foreach my $w (@{$SSHCMD[1]}) {
						if ($w =~ /$user/) {
							$break = 1;
							notify($ERRORS{'CRITICAL'}, 0, "found user connected through who command on node $nodename , strange that netstat missed it\nnetstat output:\n @lines");
							$ret_val = "connected";
							return $ret_val;
						}
					}

				} ## end elsif ($image_os_type =~ /linux/) [ if ($osname =~ /windows/)
			} ## end if ($type =~ /blade|virtualmachine/)
			elsif ($type eq "lab") {
				my $identity;
				if ($osname =~ /sun4x_/) {
					$identity = $IDENTITY_solaris_lab;
				}
				elsif ($osname =~ /rhel/) {
					$identity = $IDENTITY_linux_lab;
				}
				else {
					#if all else fails
					$identity = $IDENTITY_solaris_lab;
				}
				undef @SSHCMD;
				@SSHCMD = run_ssh_command($nodename, $identity, "netstat -an", "vclstaff", 24, 1);
				foreach my $line (@{$SSHCMD[1]}) {
					chomp($line);
					if ($line =~ /Connection refused|Permission denied/) {
						notify($ERRORS{'WARNING'}, 0, "$line");
						if ($package =~ /reserved/) {
							$ret_val = "failed";
						}
						else {
							$ret_val = "timeout";
						}
						return $ret_val;
					} ## end if ($line =~ /Connection refused|Permission denied/)
					if ($osname =~ /sun4x_/) {
						if ($line =~ /\s*($ipaddress\.22)\s+([.0-9]*)\.([0-9]*)(.*)(ESTABLISHED)/) {
							if ($2 eq $remoteIP) {
								$break   = 1;
								$ret_val = "connected";
								return $ret_val;
							}
							else {
								#this isn't the remoteIP
								$ret_val = "conn_wrong_ip";
								return $ret_val;
							}
						} ## end if ($line =~ /\s*($ipaddress\.22)\s+([.0-9]*)\.([0-9]*)(.*)(ESTABLISHED)/)
					} ## end if ($osname =~ /sun4x_/)
					elsif ($osname =~ /rhel/) {
						if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
							if ($4 eq $remoteIP) {
								$break   = 1;
								$ret_val = "connected";
								return $ret_val;
							}
							else {
								#this isn't the remoteIP
								$ret_val = "conn_wrong_ip";
								return $ret_val;
							}
						} ## end if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/)
						if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s::ffff:($ipaddress:22)\s+::ffff:([.0-9]*):([0-9]*)(.*)(ESTABLISHED) /) {
							if ($4 eq $remoteIP) {
								$break   = 1;
								$ret_val = "connected";
								return $ret_val;
							}
							else {
								#this isn't the remoteIP
								$ret_val = "conn_wrong_ip";
								return $ret_val;
							}
						} ## end if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s::ffff:($ipaddress:22)\s+::ffff:([.0-9]*):([0-9]*)(.*)(ESTABLISHED) /)
					} ## end elsif ($osname =~ /rhel/)  [ if ($osname =~ /sun4x_/)
				}    #foreach
			}    #if lab
		}    #else
		     #sleep 30;
		sleep 20;
	}    #while
	return $ret_val;
} ## end sub check_connection

#/////////////////////////////////////////////////////////////////////////////

=head2 isconnected

 Parameters  : $nodename, $type, $remoteIP, $osname, $ipaddress
 Returns     : 1 connected 0 not connected
 Description : confirms user is connected to node
					assumes port 3389 for windows and port 22 for linux/solaris
=cut

sub isconnected {
	my ($nodename, $type, $remoteIP, $osname, $ipaddress, $image_os_type) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'OK'}, 0, "nodename not set")  if (!defined($nodename));
	notify($ERRORS{'OK'}, 0, "type not set")      if (!defined($type));
	notify($ERRORS{'OK'}, 0, "remoteIP not set")  if (!defined($remoteIP));
	notify($ERRORS{'OK'}, 0, "osname not set")    if (!defined($osname));
	notify($ERRORS{'OK'}, 0, "image_os_type not set")    if (!defined($image_os_type));
	notify($ERRORS{'OK'}, 0, "ipaddress not set") if (!defined($ipaddress));

	my $identity;

	if ($image_os_type =~ /windows/i) {
		$identity = $IDENTITY_wxp;
	}
	elsif ($image_os_type =~ /linux/i) {
		$identity = $IDENTITY_bladerhel;
	}
	else {
		$identity = $IDENTITY_bladerhel;
	}

	my @netstat;
	my @SSHCMD;
	if ($type =~ /blade|virtualmachine/) {
		my $shortname = 0;
		$shortname = $1 if ($nodename =~ /([-_a-zA-Z0-9]*)\./);
		if ($shortname) {
			#convert shortname
			$nodename = $shortname;
		}

		if ($image_os_type =~ /windows/i) {
			#notify($ERRORS{'OK'},0,"checking $nodename $ipaddress");
			undef @SSHCMD;
			@SSHCMD = run_ssh_command($shortname, $identity, "netstat -an", "root", 22, 1);
			foreach my $line (@{$SSHCMD[1]}) {
				chomp($line);
				if ($line =~ /Connection refused/) {
					notify($ERRORS{'WARNING'}, 0, "$line");
					return 0;
				}
				#if($line =~ /\s+($ipaddress:3389)\s+([.0-9]*):([0-9]*)\s+(ESTABLISHED)/){
				if ($line =~ /\s+(TCP\s+[.0-9]*:3389)\s+([.0-9]*):([0-9]*)\s+(ESTABLISHED)/) {
					#notify($ERRORS{'WARNING'},0,"$line");
					return 1 if ($2 eq $remoteIP);
					if ($2 ne $remoteIP) {
						notify($ERRORS{'WARNING'}, 0, "not correct remote IP is connected");
						return 1;
					}
				}
			} ## end foreach my $line (@{$SSHCMD[1]})
		} ## end if ($osname =~ /win|vmwarewin/)
		elsif ($image_os_type =~ /linux/i) {
			undef @SSHCMD;
			@SSHCMD = run_ssh_command($nodename, $identity, "netstat -an", "root", 22, 1);
			foreach my $line (@{$SSHCMD[1]}) {
				chomp($line);
				if ($line =~ /Warning/) {
					if (known_hosts($nodename, "linux", $ipaddress)) {
						#good
					}
					next;
				}
				if ($line =~ /Connection refused/) {
					notify($ERRORS{'WARNING'}, 0, "$line");
					return 0;
				}
				if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
					return 1 if ($4 eq $remoteIP);
					if ($4 ne $remoteIP) {
						notify($ERRORS{'WARNING'}, 0, "not correct remote IP connected: $line");
						return 1;
					}
				}
			} ## end foreach my $line (@{$SSHCMD[1]})
		} 
		return 0;
	} ## end if ($type =~ /blade|virtualmachine/)
	elsif ($type eq "lab") {
		my $identity;
		if ($osname =~ /sun4x_/) {
			$identity = $IDENTITY_solaris_lab;
		}
		elsif ($osname =~ /realmrhel/) {
			$identity = $IDENTITY_linux_lab;
		}
		else {
			#if all else fails
			notify($ERRORS{'OK'}, 0, "osname $osname not found setting identity file to default");
			$identity = $IDENTITY_solaris_lab;
		}
		undef @SSHCMD;
		@SSHCMD = run_ssh_command($nodename, $identity, "netstat -an", "vclstaff", 24, 1);
		foreach my $line (@{$SSHCMD[1]}) {
			chomp($line);
			if ($line =~ /Connection refused/) {
				notify($ERRORS{'WARNING'}, 0, "$nodename $line");
				return 0;
			}
			if ($osname =~ /sun4x_/) {
				if ($line =~ /\s*($ipaddress\.22)\s+([.0-9]*)\.([0-9]*)(.*)(ESTABLISHED)/) {
					return 1 if ($2 eq $remoteIP);
					if ($2 ne $remoteIP) {
						notify($ERRORS{'WARNING'}, 0, "not correct remote IP connected $4");
						return 1;
					}
				}
			}
			elsif ($osname =~ /realmrhel3/) {
				if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
					return 1 if ($4 eq $remoteIP);
					if ($4 ne $remoteIP) {
						notify($ERRORS{'WARNING'}, 0, "not correct remote IP connected $4");
						return 1;
					}
				}
			}
		} ## end foreach my $line (@{$SSHCMD[1]})
		return 0;
	} ## end elsif ($type eq "lab")  [ if ($type =~ /blade|virtualmachine/)
} ## end sub isconnected

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

 Parameters  : request id, state name, last state(optional), log(optional)
 Returns     : 1 success 0 failure
 Description : update states

=cut

sub update_request_state {
	my ($request_id, $state_name, $laststate_name, $log) = @_;
	my ($package,    $filename,   $line,           $sub) = caller(0);

	# Check the passed parameters
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, $log, "unable to update request state, request id is not defined");
		return 0;
	}
	if (!defined($state_name)) {
		notify($ERRORS{'WARNING'}, $log, "unable to update request $request_id state, state name not defined");
		return 0;
	}

	my $update_statement;

	# Determine whether or not to update laststate, construct the SQL statement
	if (defined $laststate_name && $laststate_name ne "") {
		$update_statement = "
		UPDATE
		request,
		state state,
		state laststate
		SET
		request.stateid = state.id,
		request.laststateid = laststate.id
		WHERE
		state.name = \'$state_name\'
		AND laststate.name = \'$laststate_name\'
		AND request.id = $request_id
		";
	} ## end if (defined $laststate_name && $laststate_name...
	else {
		$update_statement = "
		UPDATE
		request,
		state state
		SET
		request.stateid = state.id
		WHERE
		state.name = \'$state_name\'
		AND request.id = $request_id
		";

		$laststate_name = 'unchanged';
	} ## end else [ if (defined $laststate_name && $laststate_name...

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		# Update successful
		notify($ERRORS{'OK'}, $LOGFILE, "request $request_id state updated to: $state_name, laststate to: $laststate_name");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update states for request $request_id");
		return 0;
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
	notify($ERRORS{'WARNING'}, $log, "$datestring is not defined") unless (defined($datestring));
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

	if ($state_name eq 'deleted' || $laststate_name eq 'deleted') {
		return 1;
	}

	return 0;
} ## end sub is_request_deleted

#/////////////////////////////////////////////////////////////////////////////

=head2 is_reservation_deleted

 Parameters  : $reservation_id
 Returns     : return 1 if reservation's request state or laststate is set to deleted or if reservation does not exist
					return 0 if reservation exists and neither request state nor laststate is set to deleted: 1 success, 0 failure
 Description : checks if reservation has been deleted

=cut

sub is_reservation_deleted {
	my ($reservation_id) = @_;

	# Check the passed parameter
	if (!(defined($reservation_id))) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified");
		return 0;
	}

	# Create the select statement
	my $select_statement = "
	SELECT
   reservation.id AS reservation_id,
	request.stateid AS currentstate_id,
	request.laststateid AS laststate_id,
	currentstate.name AS currentstate_name,
	laststate.name AS laststate_name
	FROM
	reservation, request, state currentstate, state laststate
	WHERE
   reservation.id = $reservation_id
	AND reservation.requestid = request.id
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

	if ($state_name eq 'deleted' || $laststate_name eq 'deleted') {
		return 1;
	}

	return 0;
} ## end sub is_reservation_deleted

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

 Parameters  : $computerid
 Returns     : imageid,imagerevisionid,imagename
 Description : Looks for any upcoming reservations
					for supplied computerid, if starttime is
					within 50 minutes return that imageid. Else
					fetch and return preferred image
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

	# No upcoming reservations - fetch preferred image information
	my $select_preferredimage = "
	SELECT DISTINCT
	imagerevision.imagename AS imagename,
	imagerevision.id AS imagerevisionid,
	image.id AS imageid
	FROM
	image,
	computer,
	imagerevision
   WHERE
	imagerevision.imageid = computer.preferredimageid
	AND imagerevision.production = 1
	AND computer.preferredimageid = image.id
	AND computer.id = $computerid
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @preferred_selected_rows = database_select($select_preferredimage);

	# Check to make sure at least 1 row were returned
	if (scalar @preferred_selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "get_next_image_default failed to fetch preferred image for computerid $computerid");
		return 0;
	}
	elsif (scalar @preferred_selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @preferred_selected_rows . " rows were returned from database select");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "get_next_image_default : returning preferredimage image=$preferred_selected_rows[0]{imagename} imageid=$preferred_selected_rows[0]{imageid}");
	push(@ret_array, $preferred_selected_rows[0]{imagename}, $preferred_selected_rows[0]{imageid}, $preferred_selected_rows[0]{imagerevisionid});
	return @ret_array;

} ## end sub get_next_image

#/////////////////////////////////////////////////////////////////////////////

=head2 setimagid

 Parameters  : $dbh, $computerid, $image, $imageid, $imagerevisionid
 Returns     : 1
 Description : updates imageid and imagerevisionid on provided computerid

sub setimageid {
	my ($dbh, $computerid, $image, $imageid, $imagerevisionid) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "setimageid: computerid is not defined") if (!(defined($computerid)));
	notify($ERRORS{'WARNING'}, 0, "setimageid: image is not defined")      if (!(defined($image)));
	notify($ERRORS{'WARNING'}, 0, "setimageid: imageid is not defined")    if (!(defined($imageid)));
	$imagerevisionid = 0 if (!(defined($imagerevisionid)));


	my $update_statement="UPDATE computer c SET c.currentimageid = $imageid,c.imagerevisionid = $imagerevisionid WHERE c.id = $computerid" ;
	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update preferredimageid");
		return 0;
	}
} ## end sub setimageid
=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 setpreferredimage

 Parameters  : $computerid, $image
 Returns     : 1 success, 0 failed
 Description : updates preferredimageid on provided computerid
=cut

sub setpreferredimage {
	my ($computerid, $imageid) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "computerid: node is not defined") if (!(defined($computerid)));
	notify($ERRORS{'WARNING'}, 0, "imageid: node is not defined")    if (!(defined($imageid)));

	my $update_statement = " UPDATE computer SET preferredimageid = $imageid WHERE id = $computerid ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update preferredimageid");
		return 0;
	}
} ## end sub setpreferredimage

#/////////////////////////////////////////////////////////////////////////////

=head2 _getcurrentimage

 Parameters  : $node
 Returns     : retrieve the currentimage from currentimage.txt file on the node
 Description :

=cut

sub _getcurrentimage {

	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	# TODO - loop through the available ssh keys to figure out which one works
	my $identity = $IDENTITY_bladerhel;
	my @sshcmd = run_ssh_command($node, $identity, "cat currentimage.txt");
	foreach my $s (@{$sshcmd[1]}) {
		if ($s =~ /Warning: /) {
			#need to run makesshgkh
			#if (VCL::Module::Provisioning::xCAT::makesshgkh($node)) {
			#success
			#not worth output here
			#}
			#else {
			#}
		}
		if ($s =~ /^(rh|win|fc|vmware|cent)/) {
			chomp($s);
			if ($s =~ s/\x0d//) {
				notify($ERRORS{'OK'}, 0, "stripped dos newline $s");
			}
			return $s;
		}
	} ## end foreach my $s (@{$sshcmd[1]})
	return 0;
} ## end sub _getcurrentimage

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

=head2 _sshd_status

 Parameters  : $node, $imagename, $log
 Returns     : on or off
 Description : actually logs into remote node
=cut

sub _sshd_status {
	my ($node, $imagename,$image_os_type, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!defined($log));
	notify($ERRORS{'WARNING'}, $log, "node is not defined") if (!(defined($node)));

	if (!nmap_port($node, 22)) {
		return "off";
	}

	my $identity;

	if ($image_os_type =~ /windows/i) {
		$identity = $IDENTITY_wxp;
	}
	elsif ($image_os_type =~ /linux/i) {
		$identity = $IDENTITY_bladerhel;
	}
	else {
		$identity = $IDENTITY_bladerhel;
	}

	my @sshcmd = run_ssh_command($node, $identity, "uname -s", "root");
	
	return "off" if (!defined($sshcmd[0]) || !defined($sshcmd[1]) || $sshcmd[0] == 1);
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /^Warning:/) {
			#if (VCL::Module::Provisioning::xCAT::makesshgkh($node)) {
			#}
		}
		return "off" if ($l =~ /noping/);
		return "off" if ($l =~ /No route to host/);
		return "off" if ($l =~ /Connection refused/);
		return "off" if ($l =~ /Permission denied/);
	} ## end foreach my $l (@{$sshcmd[1]})
	return "on";
} ## end sub _sshd_status

#/////////////////////////////////////////////////////////////////////////////

=head2 _machine_os

 Parameters  : $node, $imagename, $log
 Returns     : 0 or system type name
 Description : actually logs into remote node
=cut

sub _machine_os {
	my ($node, $imagename) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	if (!nmap_port($node, 22)) {
		notify($ERRORS{'OK'}, 0, "ssh port not open cannot check $node OS");
		return 0;
	}
	my $identity;
	if (defined($imagename)) {
		$identity = $IDENTITY_bladerhel if ($imagename =~ /^(rhel|rh3image|fc|rh|esx)/);
	}
	else {
		$identity = $IDENTITY_wxp;
	}
	my @sshcmd = run_ssh_command($node, $identity, "uname -s", "root");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /CYGWIN_NT-5\.1/) {
			return "WinXp";
		}
		elsif ($l =~ "CYGWIN_NT-5\.2") {
			return "win2003";
		}
		elsif ($l =~ /Linux/) {
			return "Linux";
		}
		elsif ($l =~ /Connection refused/) {
			return 0;
		}
		elsif ($l =~ /No route to host/) {
			return 0;
		}
		elsif ($l =~ /Permission denied/) {
			return 0;
		}
		else {
			return 0;
		}
	} ## end foreach my $l (@{$sshcmd[1]})
} ## end sub _machine_os

#/////////////////////////////////////////////////////////////////////////////

=head2 _is_user_added

 Parameters  : $node,    $user,     $type, $os
 Returns     : 1 yes user exists - 0 no
 Description : logs into remote node checks to see if
					supplied user account exists
=cut

sub _is_user_added {
	my ($node,    $user,     $type, $os,$image_os_type)  = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "user is not defined") if (!(defined($user)));
	notify($ERRORS{'WARNING'}, 0, "type is not defined") if (!(defined($type)));
	notify($ERRORS{'WARNING'}, 0, "os is not defined")   if (!(defined($os)));

	my @lines;
	my $l;
	my @SSHCMD;

	if ($type =~ /blade|virtualmachine/) {

		if ($image_os_type =~ /windows/i) {
			undef @SSHCMD;
			@SSHCMD = run_ssh_command($node, $IDENTITY_wxp, "cscript.exe //Nologo list_users.vbs", "root");
			foreach $l (@{$SSHCMD[1]}) {
				return 1 if ($l =~ /$user/);
			}
			return 0;
		}
		elsif ($image_os_type =~ /linux/i) {
			undef @SSHCMD;
			@SSHCMD = run_ssh_command($node, $IDENTITY_bladerhel, "cat /etc/passwd", "root");
			foreach $l (@{$SSHCMD[1]}) {
				return 1 if ($l =~ /$user/);
			}
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "osname is not defined or supported $os");
			return 0;
		}
	} ## end if ($type =~ /blade|virtualmachine/)
	elsif ($type eq "lab") {
		#tobe done later

	}
} ## end sub _is_user_added

#/////////////////////////////////////////////////////////////////////////////

=head2 add_user

 Parameters  : $node, $user, $uid, $passwd, $hostname, $os, $remoteip, $grpflag, @group
 Returns     : 1 success, 0 failed
 Description : logs into remote node adds supplied user account

=cut

sub add_user {
	my ($node, $user, $uid, $passwd, $hostname, $os, $image_os_type,$remoteip, $grpflag, @group) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")     if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "user is not defined")     if (!(defined($user)));
	notify($ERRORS{'OK'},      0, "uid is not defined")      if (!(defined($uid)));
	notify($ERRORS{'WARNING'}, 0, "passwd is not defined")   if (!(defined($passwd)));
	notify($ERRORS{'WARNING'}, 0, "os is not defined")       if (!(defined($os)));
	notify($ERRORS{'OK'},      0, "remoteip is not defined") if (!(defined($remoteip)));
	notify($ERRORS{'OK'},      0, "grpflag is not defined")  if (!(defined($grpflag)));

	if (!(defined($grpflag))) {
		$grpflag = 0;
	}
	elsif ($grpflag > 0) {
		notify($ERRORS{'OK'}, 0, "group access memberlist= @group ");
	}

	my $identity;

	if ($image_os_type =~ /windows/i) {
       $identity = $IDENTITY_wxp;
   }
   elsif ($image_os_type =~ /linux/i) {
         $identity = $IDENTITY_bladerhel;
   }
   else {
         $identity = $IDENTITY_bladerhel;
   }

	

	if ($image_os_type =~ /windows/i) {
		my @sshcmd1 = run_ssh_command($node, $identity, "cscript.exe //Nologo add_user.vbs $user $passwd", "root");
		my $delete_user = 0;
		foreach my $l (@{$sshcmd1[1]}) {
			if ($l =~ /The filename, directory name, or volume label syntax is incorrect/) {
				#ok, user is already there must have been a problem earlier
				#let delete the user and continue
				$delete_user = 1;
			}

		}
		if ($delete_user) {
			notify($ERRORS{'OK'}, 0, "error $user may already be listed");
			if (del_user($node, $user, "blade", $os, $image_os_type)) {
				notify($ERRORS{'OK'}, 0, "$user deleted");
			}

			#rerun command
			if (run_ssh_command($node, $identity, "cscript.exe //Nologo add_user.vbs $user $passwd", "root")) {
				#good
			}
		} ## end if ($delete_user)

		return _is_user_added($node, $user, "blade", $os, $image_os_type);

		notify($ERRORS{'OK'}, 0, "prep $node $user $passwd");

	} ## end if ($os =~ /win|vmwarewin/)
	elsif ($image_os_type =~ /linux/i) {
		# set common linux useradd string
		my $useradd_string;
		if (!(defined($uid))) {    # check for uid if not let OS set one
			$useradd_string = "/usr/sbin/useradd -d /home/$user -m $user -g ncsu";
		}
		else {
			$useradd_string = "/usr/sbin/useradd -u $uid -d /home/$user -m $user -g ncsu";
		}

		# two methods: single user or group of users
		if ($grpflag) {
			#assumes owner is already member of group
			#ok group flag set proceed
			my $allowuserstring = "AllowUsers";
			foreach my $u (@group) {
				#$u in form of  unity:uid
				my ($user_unityid, $uid) = split(":", $u);
				my $cmd = "/usr/sbin/useradd -u $uid -d /home/$user_unityid -m $user_unityid -g ncsu";
				if (run_ssh_command($node, $identity, $cmd, "root")) {
					notify($ERRORS{'OK'}, 0, "added user $user_unityid to $node");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to execute $cmd");
					return 0;
				}
				#append to ssh string
				$allowuserstring .= " $user_unityid";
			} ## end foreach my $u (@group)

			# modify external_sshd config
			my $cmdstring = "echo \"$allowuserstring\" >> /etc/ssh/external_sshd_config";
			my @sshcmd;
			if (run_ssh_command($node, $identity, $cmdstring, "root")) {
				notify($ERRORS{'OK'}, 0, "adding user string to sshd conf $allowuserstring");
				undef @sshcmd;
				@sshcmd = run_ssh_command($node, $identity, "/etc/init.d/ext_sshd restart", "root");
				foreach my $l (@{$sshcmd[1]}) {
					if ($l =~ /Stopping ext_sshd:/i) {
						#notify($ERRORS{'OK'},0,"stopping sshd on $node ");
					}
					if ($l =~ /Starting ext_sshd:[  OK  ]/i) {
						notify($ERRORS{'OK'}, 0, "ext_sshd on $node started");
					}
				}    #foreach
				notify($ERRORS{'OK'}, 0, "started ext_sshd on $node");
				return 1;
			} ## end if (run_ssh_command($node, $IDENTITY_bladerhel...
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to add $allowuserstring to external_sshd_config on $node ");
				return 0;
			}

		} ## end if ($grpflag)
		else {
			#single user proceed
			my @sshcmd = run_ssh_command($node, $identity, $useradd_string, "root");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /user $user exists/) {
					notify($ERRORS{'OK'}, 0, "detected user already has account, deleting");
					#FIXME - if type or project is not  HPC related.
					if (del_user($node, $user, "blade", $os, $image_os_type)) {
						notify($ERRORS{'OK'}, 0, "$user deleted");
					}
					if (run_ssh_command($node, $identity, $useradd_string, "root")) {
						notify($ERRORS{'OK'}, 0, "user $user added");
					}
				} ## end if ($l =~ /user $user exists/)

			} ## end foreach my $l (@{$sshcmd[1]})
			if (_is_user_added($node, $user, "blade", $os, $image_os_type)) {
				notify($ERRORS{'OK'}, 0, "added user account $user to $node");
				undef @sshcmd;
				my $cmd = "echo \"AllowUsers $user\" >> /etc/ssh/external_sshd_config";
				if (run_ssh_command($node, $identity, $cmd, "root")) {
					notify($ERRORS{'DEBUG'}, 0, "added AllowUsers $user to external_sshd_config");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user to external_sshd_config");
					return 0;
				}
				undef @sshcmd;
				@sshcmd = run_ssh_command($node, $identity, "/etc/init.d/ext_sshd restart", "root");

				foreach my $l (@{$sshcmd[1]}) {
					if ($l =~ /Stopping ext_sshd:/i) {
						#notify($ERRORS{'OK'},0,"stopping sshd on $node ");
					}
					if ($l =~ /Starting ext_sshd:[  OK  ]/i) {
						notify($ERRORS{'OK'}, 0, "ext_sshd on $node started");
					}
				}    #foreach
				notify($ERRORS{'OK'}, 0, "started ext_sshd on $node");
				return 1;
			} ## end if (_is_user_added($node, $user, "blade", ...
			else {
				notify($ERRORS{'CRITICAL'}, 0, "PROBLEM added user $user to $node @{ $sshcmd[1] }");
				return 0;
			}
			# add user to external_sshd config
		}    # grpflag true
	}    # rhel
	else {
		return 0;
	}
} ## end sub add_user

#/////////////////////////////////////////////////////////////////////////////

=head2 add_users_by_group

 Parameters  : computer_short_name,pw,computer_hostname,OSname,%usergrpmembers
 Returns     : 1 sucess,0 failed
 Description : adds a group users to remote machine

=cut

sub add_users_by_group {
	my ($computer_short_name, $passwd, $computer_hostname, $OSname,$image_os_type, %usermembers) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "computer_short_name is not defined") if (!(defined($computer_short_name)));
	notify($ERRORS{'WARNING'}, 0, "pw is not defined")                  if (!(defined($passwd)));
	notify($ERRORS{'WARNING'}, 0, "computer_hostname is not defined")   if (!(defined($computer_hostname)));
	notify($ERRORS{'WARNING'}, 0, "OSname is not defined")              if (!(defined($OSname)));

	#make sure we have something in our hash
	if (scalar keys %usermembers < 2) {
		notify($ERRORS{'WARNING'}, 0, "the supplied user group had 1 or less member");
	}

	foreach my $user (keys %usermembers) {
		#if ($OSname =~ /win|vmwarewin/) {
		if ($image_os_type =~ /windows/i) {
			my $cmd = "cscript.exe //Nologo add_user.vbs $usermembers{$user}{username} $passwd";
			my @cmdout = run_ssh_command($computer_short_name, $IDENTITY_wxp, $cmd, "root");
			foreach my $line (@{$cmdout[1]}) {
				#check for errors
				notify($ERRORS{'DEBUG'}, 0, "return status $cmdout[0] output= $line");
			}
		}
	} ## end foreach my $user (keys %usermembers)

	return 1;
} ## end sub add_users_by_group

#/////////////////////////////////////////////////////////////////////////////

=head2 del_user

 Parameters  : $node, $user, $type, $osname
 Returns     : 1 success 0 failure
 Description : removes user account from specificed node

=cut

sub del_user {
	my ($node, $user, $type, $osname, $image_os_type) = @_;
	my ($package, $filename, $line, $sub)    = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")   if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "user is not defined")   if (!(defined($user)));
	notify($ERRORS{'WARNING'}, 0, "type is not defined")   if (!(defined($type)));
	notify($ERRORS{'WARNING'}, 0, "osname is not defined") if (!(defined($osname)));
	notify($ERRORS{'WARNING'}, 0, "image_os_type is not defined") if (!(defined($image_os_type)));
	#set variables to use
	my $cmd;
	my @sshcmd;
	if ($type =~ /blade|virtualmachine/) {
		#my $os = _machine_os($node);
		if ($image_os_type =~ /windows/i) {
			$cmd = "cscript.exe //Nologo del_user.vbs $user";
			@sshcmd = run_ssh_command($node, $IDENTITY_wxp, $cmd, "root");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /The filename, directory name, or volume label syntax is incorrect/) {
					# user account not listed. no need to confirm
					return 1;
				}

			}
			notify($ERRORS{'DEBUG'}, 0, "cscript.exe //Nologo del_user.vbs $user produced output: " . join("\n", @{$sshcmd[1]}));

			if (!(_is_user_added($node, $user, $type, $osname, $image_os_type))) {
				return 1;
			}
			else {
				return 0;
			}

			#make sure user home dir is deleted
			undef $cmd;
			undef @sshcmd;
			$cmd = "/bin/rm -rf /cygdrive/c/Documents\ and\ Settings/$user";
			@sshcmd = run_ssh_command($node, $IDENTITY_wxp, $cmd, "root");
			foreach my $l (@{$sshcmd[1]}) {
				#shouldn't have any output  - report if necessary
				notify($ERRORS{'DEBUG'}, 0, "$cmd produced output $l");
			}

		} ## end if ($osname =~ /wxp|win|vmware/)
		elsif ($image_os_type =~ /linux/i) {
			#remove user from machine
			my @file;
			my $l;
			undef $cmd;
			undef @sshcmd;
			# do not currently use userdel -r  will affect HPC user storage for HPC installs
			$cmd = "/usr/sbin/userdel $user";
			@sshcmd = run_ssh_command($node, $IDENTITY_bladerhel, $cmd, "root");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /currently logged in/) {
					notify($ERRORS{'WARNING'}, 0, "$user currently logged in returning 0");
					return 0;
				}
			}
			#user successfully deleted
			my $path1 = "$node:/etc/ssh/external_sshd_config";
			my $path2 = "/tmp/$node.sshd";
			if (run_scp_command($path1, $path2, $IDENTITY_bladerhel)) {
				notify($ERRORS{'DEBUG'}, 0, "scp success retrieved $path1");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve $path1");
				return 0;
			}
			#remove from sshd
			if (open(SSHDCFG, "/tmp/$node.sshd")) {
				@file = <SSHDCFG>;
				close SSHDCFG;
				foreach $l (@file) {
					$l = "" if ($l =~ /AllowUsers/);
				}
				if (open(SCP, ">/tmp/$node.sshd")) {
					print SCP @file;
					close SCP;
				}
				undef $path1;
				undef $path2;
				$path1 = "/tmp/$node.sshd";
				$path2 = "$node:/etc/ssh/external_sshd_config";
				if (run_scp_command($path1, $path2, $IDENTITY_bladerhel)) {
					notify($ERRORS{'DEBUG'}, 0, "scp success copied $path1 to $path2");
					unlink $path1;
					#turn off external sshd
					if (run_ssh_command($node, $IDENTITY_bladerhel, "/etc/init.d/ext_sshd stop")) {
						notify($ERRORS{'DEBUG'}, 0, "turned off ext_sshd on $node");
					}
					return 1;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy $path1 to $path2");
					return 0;
				}
			} ## end if (open(SSHDCFG, "/tmp/$node.sshd"))
		} ## end elsif 
		else {
			notify($ERRORS{'WARNING'}, 0, "$osname does not exist ");
			return 0;
		}
	} ## end if ($type =~ /blade|virtualmachine/)

} ## end sub del_user

#/////////////////////////////////////////////////////////////////////////////

=head2 disablesshd

 Parameters  : $hostname, $unityname, $remoteIP, $state, $osname, $log
 Returns     : 1 success 0 failure
 Description : using ssh identity key log into remote lab machine
					and set flag for vclclientd to disable sshd for  remote user

=cut

sub disablesshd {
	my ($hostname, $unityname, $remoteIP, $state, $osname, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!(defined($log)));
	notify($ERRORS{'WARNING'}, $log, "hostname is not defined")  if (!(defined($hostname)));
	notify($ERRORS{'WARNING'}, $log, "unityname is not defined") if (!(defined($unityname)));
	notify($ERRORS{'WARNING'}, $log, "remoteIP is not defined")  if (!(defined($remoteIP)));
	notify($ERRORS{'WARNING'}, $log, "state is not defined")     if (!(defined($state)));
	notify($ERRORS{'WARNING'}, $log, "osname is not defined")    if (!(defined($osname)));

	if (!(defined($remoteIP))) {
		$remoteIP = "127.0.0.1";
	}
	my @lines;
	my $l;
	my $identity;
	if ($osname =~ /sun4x_/) {
		$identity = $IDENTITY_solaris_lab;
	}
	elsif ($osname =~ /rhel/) {
		$identity = $IDENTITY_linux_lab;
	}
	else {
		#if all else fails
		$identity = $IDENTITY_solaris_lab;
	}
	# create clientdata file
	my $clientdata = "/tmp/clientdata.$hostname";
	if (open(CLIENTDATA, ">$clientdata")) {
		print CLIENTDATA "$state\n";
		print CLIENTDATA "$unityname\n";
		print CLIENTDATA "$remoteIP\n";
		close CLIENTDATA;

		# scp to hostname
		my $target = "vclstaff\@$hostname:/home/vclstaff/clientdata";
		if (run_scp_command($clientdata, $target, $identity, "24")) {
			notify($ERRORS{'OK'}, $log, "Success copied $clientdata to $target");
			unlink($clientdata);

			# send flag to activate changes
			my @sshcmd = run_ssh_command($hostname, $identity, "echo 1 > /home/vclstaff/flag", "vclstaff", "24");
			notify($ERRORS{'OK'}, $log, "setting flag to 1 on $hostname");

			my $nmapchecks = 0;
			# return nmap check

			NMAPPORT:
			if (!(nmap_port($hostname, 22))) {
				return 1;
			}
			else {
				if ($nmapchecks < 5) {
					$nmapchecks++;
					sleep 1;
					notify($ERRORS{'OK'}, $log, "port 22 not closed yet calling NMAPPORT code block");
					goto NMAPPORT;
				}
				else {
					notify($ERRORS{'WARNING'}, $log, "port 22 never closed on client $hostname");
					return 0;
				}
			} ## end else [ if (!(nmap_port($hostname, 22)))
		} ## end if (run_scp_command($clientdata, $target, ...
		else {
			notify($ERRORS{'OK'}, $log, "could not copy src=$clientdata to target=$target");
			return 0;
		}
	} ## end if (open(CLIENTDATA, ">$clientdata"))
	else {
		notify($ERRORS{'WARNING'}, $log, "could not open /tmp/clientdata.$hostname $! ");
		return 0;
	}
} ## end sub disablesshd

#/////////////////////////////////////////////////////////////////////////////

=head2 enablesshd

 Parameters  : $hostname, $unityname, $remoteIP, $state, $osname, $log
 Returns     : 1 success 0 failure
 Description : using ssh identity key log into remote lab machine
					and set flag for vclclientd to enable ssh access for remote user

=cut

sub enablesshd {
	my ($hostname, $unityname, $remoteIP, $state, $osname, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!(defined($log)));
	notify($ERRORS{'WARNING'}, $log, "hostname is not defined")  if (!(defined($hostname)));
	notify($ERRORS{'WARNING'}, $log, "unityname is not defined") if (!(defined($unityname)));
	notify($ERRORS{'WARNING'}, $log, "remoteIP is not defined")  if (!(defined($remoteIP)));
	notify($ERRORS{'WARNING'}, $log, "state is not defined")     if (!(defined($state)));
	notify($ERRORS{'WARNING'}, $log, "osname is not defined")    if (!(defined($osname)));
	my $identity;

	if ($osname =~ /sun4x_/) {
		$identity = $IDENTITY_solaris_lab;
	}
	elsif ($osname =~ /rhel/) {
		$identity = $IDENTITY_linux_lab;
	}
	# create clientdata file
	my $clientdata = "/tmp/clientdata.$hostname";
	if (open(CLIENTDATA, ">$clientdata")) {
		print CLIENTDATA "$state\n";
		print CLIENTDATA "$unityname\n";
		print CLIENTDATA "$remoteIP\n";
		close CLIENTDATA;

		# scp to hostname
		my $target = "vclstaff\@$hostname:/home/vclstaff/clientdata";
		if (run_scp_command($clientdata, $target, $identity, "24")) {
			notify($ERRORS{'OK'}, $log, "Success copied $clientdata to $target");
			unlink($clientdata);

			# send flag to activate changes
			my @sshcmd = run_ssh_command($hostname, $identity, "echo 1 > /home/vclstaff/flag", "vclstaff", "24");
			notify($ERRORS{'OK'}, $log, "setting flag to 1 on $hostname");

			my $nmapchecks = 0;
			# return nmap check

			NMAPPORT:
			if (nmap_port($hostname, 22)) {
				notify($ERRORS{'OK'}, $log, "sshd opened");
				return 1;
			}
			else {
				if ($nmapchecks < 6) {
					$nmapchecks++;
					sleep 1;
					#notify($ERRORS{'OK'},0,"calling NMAPPORT code block");
					goto NMAPPORT;
				}
				else {
					notify($ERRORS{'WARNING'}, $log, "port 22 never opened on client $hostname");
					return 0;
				}
			} ## end else [ if (nmap_port($hostname, 22))
		} ## end if (run_scp_command($clientdata, $target, ...
		else {
			notify($ERRORS{'WARNING'}, $log, "could not copy src=$clientdata to target= $target");
			return 0;
		}
	} ## end if (open(CLIENTDATA, ">$clientdata"))
	else {
		notify($ERRORS{'WARNING'}, $log, "could not open /tmp/clientdata.$hostname $! ");
		return 0;
	}
} ## end sub enablesshd

#/////////////////////////////////////////////////////////////////////////////

=head2 nmap_port

 Parameters  : $hostname, $port
 Returns     : 1 open 0 closed
 Description : use nmap port scanning tool to determine if port is open

=cut

sub nmap_port {
	my ($hostname, $port) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "hostname is not defined") if (!(defined($hostname)));
	notify($ERRORS{'WARNING'}, 0, "port is not defined")     if (!(defined($port)));
	my @file;
	my $l;
	if (open(NMAP, "/usr/bin/nmap $hostname -P0 -p $port -T Aggressive |")) {
		@file = <NMAP>;
		close NMAP;
		foreach $l (@file) {
			if ($l =~ /open/) {
				return 1;
			}
			elsif ($l =~ /is: closed/) {
				return 0;
			}
			elsif ($l =~ /Host seems down/) {
				return 0;
			}
			elsif ($l =~ /filtered/) {
				return 0;
			}
		} ## end foreach $l (@file)
	} ## end if (open(NMAP, "/usr/bin/nmap $hostname -P0 -p $port -T Aggressive |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "problems executing /usr/bin/nmap $hostname -P0 -p $port $!");
		return 0;
	}
	return 0;
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

=head2 virtual_status_unix

 Parameters  : $hostname, $os, $mnOS, $ipaddress, $log
 Returns     : array of values - pingable,sshd,vclclientd running
 Description : runs status check on supplied node
=cut

sub virtual_status_unix {
	my ($hostname, $os, $mnOS, $ipaddress, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!(defined($log)));
	notify($ERRORS{'WARNING'}, $log, "hostname is not defined")          if (!(defined($hostname)));
	notify($ERRORS{'WARNING'}, $log, "os is not defined")                if (!(defined($os)));
	notify($ERRORS{'WARNING'}, $log, "ManagementNode OS is not defined") if (!(defined($mnOS)));
	notify($ERRORS{'WARNING'}, $log, "ipaddress is not defined")         if (!(defined($ipaddress)));
	my @status;
	# status[0] =  pingable
	# status[1] = port 24 accessible
	# status[2] =  vclclientd running
	# status[3] =
	my @file;
	my $p;
	my $osname = lc($^O);
	$mnOS = $osname;
	notify($ERRORS{'DEBUG'}, $log, "virtual_status_unix MNos= $mnOS");


	#is host listed in our local known_hosts file?
	if (known_hosts($hostname, $mnOS, $ipaddress)) {
		notify($ERRORS{'OK'}, $log, "$hostname pub key added to local known_hosts");
	}
	else {
		notify($ERRORS{'OK'}, $log, "failed to add $hostname pub rsa key to local known_hosts");
	}

	#is pingable
	$status[0] = _pingnode($ipaddress);

	#is ssh open on admin port
	my @ssh;
	my ($n, $identity);

	if ($os =~ /sun4x/) {
		$identity = $IDENTITY_solaris_lab;
	}
	elsif ($os =~ /rhel/) {
		$identity = $IDENTITY_linux_lab;
	}
	else {
		notify($ERRORS{'OK'}, $log, "os $os set but not something I can handle yet, will attempt the unix identity.");

		$identity = $IDENTITY_solaris_lab;
	}
	$status[1] = 0;
	if (check_ssh($ipaddress, 24, $log)) {
		my $shortname = $1 if ($hostname =~ /([-_a-zA-Z0-9]*)\./);
		$shortname = $hostname if (!defined($shortname));

		my @ssh = run_ssh_command($ipaddress, $identity, "echo testing", "vclstaff", 24);
		foreach $n (@{$ssh[1]}) {
			next if ($n =~ /Warning: Permanently added/);
			notify($ERRORS{'OK'}, $log, "$n");
			if ($n =~ /testing/) {
				$status[1] = 1;
				notify($ERRORS{'OK'}, $log, "SUCCESS $ipaddress port 24 is accessible");
			}
		}
		if ($status[1]) {
			#is vclclientd running
			$status[2] = 0;
			my @file = run_ssh_command($ipaddress, $identity, "pgrep vclclient", "vclstaff", 24);
			foreach my $f (@{$file[1]}) {
				chomp($f);
				next if ($f =~ /Warning: Permanently added/);
				if ($f =~ /[0-9]+/) {
					#notify($ERRORS{'OK'},$log,"SUCCESS vclclientd is running on $hostname");
					$status[2] = 1;
				}
			}
		} ## end if ($status[1])
		else {
			# hrm -p24 is not accessible
			# return so caller can try to get another machine
			notify($ERRORS{'WARNING'}, $log, "FAILURE $hostname port 24 is NOT accessible ssh output @ssh");
			$status[2] = 0;
		}
	} ## end if (check_ssh($ipaddress, 24, $log))
	return @status;
} ## end sub virtual_status_unix

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
				notify($ERRORS{'DEBUG'}, 0, "database handle stored in \$ENV{dbh} ($ENV{dbh_count})");
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
	if ($type eq "blade") {
		#this is only going to be rhel
		if (run_scp_command("/tmp/wall.$hostname", "$hostname:/root/wall.txt", $IDENTITY_bladerhel)) {
			unlink "/tmp/wall.$hostname";
			if (run_ssh_command($hostname, $IDENTITY_bladerhel, " cat /root/wall.txt \| wall; /bin/rm -v /root/wall.txt", "root")) {
				notify($ERRORS{'OK'}, 0, "successfully sent wall notification to $hostname");
				return 1;
			}
		}
	} ## end if ($type eq "blade")
	elsif ($type eq "lab") {
		if ($OSname =~ /sun4x_/) {
			$identity = $IDENTITY_solaris_lab;
		}
		elsif ($OSname =~ /rhel/) {
			$identity = $IDENTITY_linux_lab;
		}
		else {
			#all else fails
			$identity = $IDENTITY_solaris_lab;
		}

		if (run_scp_command("/tmp/wall.$hostname", "vclstaff\@$hostname:/home/vclstaff/wall.txt", $identity, 24)) {
			unlink "/tmp/wall.$hostname";
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not scp tmp file for wall notification$!");
		}

		if ($OSname =~ /sun4x_/) {
			if (run_ssh_command($hostname, $identity, "wall -a /home/vclstaff/wall.txt; /bin/rm -v /home/vclstaff/wall.txt", "vclstaff", "24")) {
				notify($ERRORS{'OK'}, 0, "successfully sent wall notification to $hostname");
				return 1;
			}
			else {
				notify($ERRORS{'OK'}, 0, "wall notification $hostname failed ");
			}
		}
		elsif ($OSname =~ /rhel/) {
			if (run_ssh_command($hostname, $identity, "cat /home/vclstaff/wall.txt \| wall ; /bin/rm -v /home/vclstaff/wall.txt", "vclstaff", "24")) {
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

=head2 isfilelocked

 Parameters  : $file - file path
 Returns     : 0 no or 1 yes
 Description : looks for supplied file
					appends .lock to the end of supplied file

=cut

sub isfilelocked {
	my ($file) = $_[0];
	my $lockfile = $file . ".lock";
	if (-r $lockfile) {
		return 1;
	}
	else {
		return 0;
	}
} ## end sub isfilelocked

#/////////////////////////////////////////////////////////////////////////////

=head2 lockfile

 Parameters  : $file
 Returns     : 0 failed or 1 success
 Description : creates $file.lock

=cut

sub lockfile {
	my ($file) = $_[0];
	my $lockfile = $file . ".lock";
	while (!(-r $lockfile)) {
		if (open(LOCK, ">$lockfile")) {
			print LOCK "1";
			close LOCK;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not create $lockfile $!");
			return 0;
		}
		return 1;
	} ## end while (!(-r $lockfile))
} ## end sub lockfile

#/////////////////////////////////////////////////////////////////////////////

=head2 unlockfile

 Parameters  : $file
 Returns     : 0 or 1
 Description : removes file if exists

=cut

sub unlockfile {
	my ($file) = $_[0];
	my $lockfile = $file . ".lock";
	if (-r $lockfile) {
		unlink $lockfile;
	}
	else {
		# no lock file exists
	}
	return 1;
} ## end sub unlockfile

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

	if (run_ssh_command($node, $IDENTITY_wxp, $command)) {
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

=head2 changewindowspasswd

 Parameters  : node, account
 Returns     : 0 or 1
 Description : changes windows password on given node for given account

=cut

sub changewindowspasswd {
	# change the privileged account passwords on the blade images
	my ($node, $account, $passwd) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "account is not defined") if (!(defined($account)));


	#copy setpass.vbs to blade
	#set password for root and administrator accounts
	#remove setpass.vbs from blade
	my @ssh;
	my $l;
	my @sshcmd;
	#if not a predefined password, get one!
	if (!(defined($passwd))) {
		$passwd = getpw(15);
	}
	if (run_scp_command("$TOOLS/setpass.vbs", "$node:setpass.vbs", $IDENTITY_wxp)) {
		undef @sshcmd;
		@sshcmd = run_ssh_command($node, $IDENTITY_wxp, "cscript.exe //Nologo setpass.vbs $account $passwd", "root");
		for $l (@{$sshcmd[1]}) {
			if ($l =~ /Input Error/) {
				notify($ERRORS{'WARNING'}, 0, "$node: could not run setpass.vbs");
				return 0;
			}
		}
		if ($account eq "root") {
			#must set sshd service password also...
			my $cmd = "cmd /c C:\/WINDOWS\/system32\/sc config sshd password= $passwd";
			undef @sshcmd;
			@sshcmd = run_ssh_command($node, $IDENTITY_wxp, "$cmd", "root");
			foreach $l (@{$sshcmd[1]}) {
				if ($l =~ /ChangeServiceConfig SUCCESS/) {
					notify($ERRORS{'OK'}, 0, "$node: serviceConfig sshd password change success");
				}
				else {
					notify($ERRORS{'OK'}, 0, "$node: serviceConfig $l");
				}
			}
		} ## end if ($account eq "root")
		    #remove setpass.vbs
		if (run_ssh_command($node, $IDENTITY_wxp, "/bin/rm -v setpass.vbs", "root")) {
			#good removed setpass.vbs
		}
		return 1;
	} ## end if (run_scp_command("$TOOLS/setpass.vbs", ...
	return 0;
} ## end sub changewindowspasswd

#/////////////////////////////////////////////////////////////////////////////

=head2 _killsysprep

 Parameters  : node
 Returns     : 0 failed or 1 success
 Description : stops ssh initiated sysprep command,
					because the the box reboots and the command hangs

=cut

sub _killsysprep {
	my $node = $_[0];
	if (open(PS, "ps -ef |")) {
		notify($ERRORS{'DEBUG'}, 0, "_killsysprep: listing processes sysprep for $node");
		my @ps = <PS>;
		close(PS);
		foreach my $p (@ps) {
			if (($p =~ /sysprep.cmd/) && ($p =~ /$node/)) {
				notify($ERRORS{'DEBUG'}, 0, "_killsysprep: found sysprep.cmd on $node");
				if ($p =~ /(root)\s+([0-9]*)/) {
					notify($ERRORS{'DEBUG'}, 0, "_killsysprep: located pid $2");
					if (open(KILLIT, "kill -9 $2 |")) {
						close(KILLIT);
						notify($ERRORS{'OK'}, 0, "killed -9 $2 : $p");
						return 1;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "could not execute kill -9 $!");
					}
				} ## end if ($p =~ /(root)\s+([0-9]*)/)
			} ## end if (($p =~ /sysprep.cmd/) && ($p =~ /$node/...
		} ## end foreach my $p (@ps)

	} ## end if (open(PS, "ps -ef |"))
	else {
		notify($ERRORS{'WARNING'}, 0, "could not execute ps $!");
	}

	return 1;

} ## end sub _killsysprep

#/////////////////////////////////////////////////////////////////////////////

=head2 remotedesktopport

 Parameters  : node,state,remoteaddress
 Returns     : 0 failed or 1 success
 Description : routine to enable or disable remotedesktop port on xp blades
		 		  only currently works with windows XP service pack 2
=cut

sub remotedesktopport {
	my ($node, $state, $remoteaddress) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'CRITICAL'}, 0, "$node is not defined")  if (!(defined($node)));
	notify($ERRORS{'CRITICAL'}, 0, "$state is not defined") if (!(defined($state)));


	#machine must have the ability to edit firewall service using netsh firewall set service...
	my @list;
	my $RDopen = 0;
	my @sshcmd = run_ssh_command($node, $IDENTITY_wxp, "netsh firewall show state", "root");
	if (!($sshcmd[0])) {
		#notify($ERRORS{'WARNING'}, 0, "failed to run netsh firewall show state on $node");
	}
	for my $l (@{$sshcmd[1]}) {
		if ($l =~ /The following command was not found: firewall show/) {
			notify($ERRORS{'OK'}, 0, "firewall support is not available on $node returning true");
			return 1;
		}
		if ($l =~ /3389/) {
			#it's open
			$RDopen = 1;
		}
	} ## end for my $l (@{$sshcmd[1]})

	if ($state eq "ENABLE") {
		my ($netsh, $breakdown);
		if (defined($remoteaddress)) {
			# if(open(HOST,"/usr/bin/host $remoteaddress 2>&1 |")){
			#    my @host =<HOST>;
			#    close(HOST);
			#    foreach my $h (@host) {
			#          #sas environment users make http reservation through load-balanced set of outgoing servers but
			#          # connection is attempted through a nat server with different address
			#          # this could be the case at other locations as well
			#           $breakdown=1 if($h =~ /sas.com/);
			#   }
			# }
			if (!($remoteaddress)) {
				#should really check if a valid address
				#it's defined but equals 0 just open
				#no address was provided, just open it
				#$netsh = "netsh firewall set service REMOTEDESKTOP ENABLE";
				$netsh = "netsh firewall set portopening TCP 3389 RDP enable ALL";
				notify($ERRORS{'OK'}, 0, "no address provided, $node remotedesktop port enable executing");
			}
			else {
				$breakdown = 1;
				if ($breakdown) {
					#break down address
					my ($q1, $q2, $q3, $q4) = split(/[.]/, $remoteaddress);
					if ($q1) {
						$remoteaddress = "$q1.$q2.0.0/255.255.0.0";
						notify($ERRORS{'OK'}, 0, "enabling broad scope address $remoteaddress");
						$netsh = "netsh firewall set portopening TCP 3389 RDP enable CUSTOM $remoteaddress";
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "detected sas.com but could not break appart $remoteaddress, leaving empty");
						$netsh = "netsh firewall set portopening TCP 3389 RDP enable ALL";
					}
				} ## end if ($breakdown)
				else {
					$netsh = "netsh firewall set portopening TCP 3389 RDP enable CUSTOM $remoteaddress";
					#$netsh = "netsh firewall set service REMOTEDESKTOP ENABLE CUSTOM $remoteaddress";
					notify($ERRORS{'OK'}, 0, "$node remotedesktop port enable custom address $remoteaddress executing");
				}
			} ## end else [ if (!($remoteaddress))
		} ## end if (defined($remoteaddress))
		else {
			#no address was provided, just open it
			#$netsh = "netsh firewall set service REMOTEDESKTOP ENABLE";
			$netsh = "netsh firewall set portopening TCP 3389 RDP enable ALL";
			notify($ERRORS{'OK'}, 0, "no address provided, $node remotedesktop port enable executing");
		}

		my $RDopen = 0;
		my @enable = run_ssh_command($node, $IDENTITY_wxp, $netsh, "root");
		foreach my $e (@{$enable[1]}) {
			if ($e =~ /Ok/i) {
				notify($ERRORS{'DEBUG'}, 0, "netsh command $netsh executed ");
			}
		}
		#dbl check
		@sshcmd = run_ssh_command($node, $IDENTITY_wxp, "netsh firewall show state", "root");
		for my $l (@{$sshcmd[1]}) {
			$RDopen = 1 if ($l =~ /3389/);
		}
		if ($RDopen) {
			notify($ERRORS{'OK'}, 0, "$node remotedesktop port opened");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$node remotedesktop port not opened");
			return 0;
		}
	} ## end if ($state eq "ENABLE")
	if ($state eq "DISABLE") {
		if ($RDopen) {
			$RDopen = 0;
			#Disable it
			undef @sshcmd;
			if (run_ssh_command($node, $IDENTITY_wxp, "netsh firewall set service REMOTEDESKTOP DISABLE", "root")) {
				notify($ERRORS{'OK'}, 0, "$node remotedesktop port disabled");
			}
			#dbl check
			undef @sshcmd;
			@sshcmd = run_ssh_command($node, $IDENTITY_wxp, "netsh firewall show state", "root");
			if (!@sshcmd) {
				notify($ERRORS{'WARNING'}, 0, "failed to run netsh firewall show state on $node");
			}
			for my $l (@{$sshcmd[1]}) {
				$RDopen = 1 if ($l =~ /3389/);
			}
		} ## end if ($RDopen)
		    #is it closed or open
		if ($RDopen) {
			notify($ERRORS{'OK'}, 0, "$node remotedesktop port still open");
			return 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "$node remotedesktop port closed");
			return 1;
		}
	} ## end if ($state eq "DISABLE")
} ## end sub remotedesktopport

#/////////////////////////////////////////////////////////////////////////////

=head2 hostname

 Parameters  : NA
 Returns     : hostname of this machine
 Description : attempts to check local hostname using hostname cmd
					if global FQDN is set the routine returns this instead
=cut

sub hostname {
	my ($package, $filename, $line, $sub) = caller(0);
	my @host;
	my $h;
	#hack
	my $osname = lc($^O);

	if ($osname eq 'linux') {
		if ($FQDN) {
			@host = ($FQDN, "linux");
			return @host;
		}
		if (open(HOST, "/bin/hostname -f 2>&1 |")) {
			@host = <HOST>;
			close(HOST);
			foreach $h (@host) {
				if ($h =~ /([-a-z0-9]*)([.a-z]*)/) {
					chomp($h);
					
					@host = ($h, "linux");
					return @host;
				}
			} ## end foreach $h (@host)
		} ## end if (open(HOST, "/bin/hostname -f 2>&1 |"))
		else {
			notify($ERRORS{'CRITICAL'}, 0, "can't $!");
			return 0;
		}
	} ## end if ($osname eq 'linux')
	elsif ($osname eq 'solaris') {
		if ($FQDN) {
			@host = ($FQDN, "linux");
			return @host;
		}
		if (open(NODENAME, "< /etc/nodename")) {
			@host = <NODENAME>;
			close(NODENAME);
			foreach $h (@host) {
				if ($h =~ /([-a-z0-9]*)([.a-z]*)/) {
					chomp($h);
					my @host = ($h, "solaris");
					return @host;
				}
			}
		} ## end if (open(NODENAME, "< /etc/nodename"))
		else {
			notify($ERRORS{'CRITICAL'}, 0, "can't open /etc/nodename $!");
			return 0;
		}
	} ## end elsif ($osname eq 'solaris')  [ if ($osname eq 'linux')
	elsif ($osname eq 'mswin32') {
		if ($FQDN) {
			@host = ($FQDN, "windows");
			return @host;
		}
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unknown OS type: $osname");
		return 0;
	}
	return 0;
} ## end sub hostname

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

=head2 changelinuxpassword

 Parameters  : $node, $account, $passwd
 Returns     : 0 or 1
 Description : changes linux root password on stock blade installs

=cut

sub changelinuxpassword {
# change the privileged account passwords on the blade images
	my ($node, $account, $passwd) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "account is not defined") if (!(defined($account)));

	#set password for root and administrator accounts
	#remove setpass.vbs from blade
	my @ssh;
	my $l;
	if ($account eq "root") {


		#if not a predefined password, get one!
		$passwd = getpw(15) if (!(defined($passwd)));
		notify($ERRORS{'OK'}, 0, "password for $node is $passwd");

		if (open(OPENSSL, "openssl passwd -1 $passwd 2>&1 |")) {
			$passwd = <OPENSSL>;
			chomp $passwd;
			close(OPENSSL);
			if ($passwd =~ /command not found/) {
				notify($ERRORS{'CRITICAL'}, 0, "failed $passwd ");
				return 0;
			}
			my $tmpfile = "/tmp/shadow.$node";
			if (open(TMP, ">$tmpfile")) {
				print TMP "$account:$passwd:13061:0:99999:7:::\n";
				close(TMP);
				if (run_ssh_command($node, $IDENTITY_bladerhel, "cat /etc/shadow \|grep -v $account >> $tmpfile", "root")) {
					notify($ERRORS{'DEBUG'}, 0, "collected /etc/shadow file from $node");
					if (run_scp_command($tmpfile, "$node:/etc/shadow", $IDENTITY_bladerhel)) {
						notify($ERRORS{'DEBUG'}, 0, "copied updated /etc/shadow file to $node");
						if (run_ssh_command($node, $IDENTITY_bladerhel, "chmod 600 /etc/shadow", "root")) {
							notify($ERRORS{'DEBUG'}, 0, "updated permissions to 600 on /etc/shadow file on $node");
							unlink $tmpfile;
							return 1;
						}
						else {
							notify($ERRORS{'WARNING'}, 0, "failed to change file permissions on $node /etc/shadow");
							unlink $tmpfile;
							return 0;
						}
					} ## end if (run_scp_command($tmpfile, "$node:/etc/shadow"...
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to copy contents of shadow file on $node ");
					}
				} ## end if (run_ssh_command($node, $IDENTITY_bladerhel...
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy contents of shadow file on $node ");
					unlink $tmpfile;
					return 0;
				}
			} ## end if (open(TMP, ">$tmpfile"))
			else {
				notify($ERRORS{'OK'}, 0, "failed could open $tmpfile $!");
			}
		} ## end if (open(OPENSSL, "openssl passwd -1 $passwd 2>&1 |"...
		return 0;
	} ## end if ($account eq "root")
	else {
		#actual user
		#push it through passwd cmd stdin
		my @sshcmd = run_ssh_command($node, $IDENTITY_bladerhel, "echo $passwd \| /usr/bin/passwd -f $account --stdin", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /authentication tokens updated successfully/) {
				notify($ERRORS{'OK'}, 0, "successfully changed local password account $account");
				return 1;
			}
		}

	} ## end else [ if ($account eq "root")
} ## end sub changelinuxpassword


#/////////////////////////////////////////////////////////////////////////////

=head2 getanothermachine

 Parameters  : useid,imagename
 Returns     : available machine if successful or 0 on failure
 Description : NOT COMPLETED - to be used in case of a failure on reservation,
					if the box is reloading or failed in some fashion
					using rpc call to php on webserver

=cut

sub getanothermachine {
	my ($userid, $imageid) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "userid is not defined") if (!(defined($userid)));
	notify($ERRORS{'WARNING'}, 0, "imagid is not defined") if (!(defined($imageid)));

	my $function = "getUserResources";
	#Parameters for getUserResources function :
	#$userprivs - array of privileges to look for (such as imageAdmin, imageCheckOut, etc); don't include 'block' or 'cascade'
	#$resourceprivs- array of privileges to look for (such as available, administer, manageGroup); don't include 'block' or 'cascade'
	#$onlygroups - (optional) if 1, return the resource groups instead of the resources
	#$includedeleted - (optional) included deleted resources if 1, don't if 0
	#$userid - (optional) id from the user table, if not given, use the id of the currently logged in user

	my $arg1 = "imageAdmin:imageCheckOut";
	my $arg2 = "available:";
	my $arg3 = 0;
	my $arg4 = 0;
	my $arg5 = $userid;

	eval {
		my $doc = get("https://vcl.ncsu.edu/scheduling/index.php?mode=vcldquery&key=$VCLDRPCQUERYKEY&query=$function,$arg1,$arg2,$arg3,$arg4,$arg5");

	  }

} ## end sub getanothermachine


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
   user.uid

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
		push(@retarray, "$hash{unityid}:$hash{uid}");
	}

	return @retarray;

} ## end sub getusergroupmembers

#/////////////////////////////////////////////////////////////////////////////

=head2  getimagesize

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub getimagesize {
	my $imagename = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "imagename is not defined") if (!(defined($imagename)));

	if (!(defined($imagename))) {
		return 0;
	}
	my $IMAGEREPOSITORY;
	if ($imagename =~ /^(win|rh3image)/) {
		$IMAGEREPOSITORY = "/install/image/x86";
	}
	elsif ($imagename =~ /^(rh([0-9])image|fc([0-9])image)/) {
		$IMAGEREPOSITORY = "/install/$LINUX_IMAGE/x86";
	}
	elsif ($imagename =~ /^(vmware)/) {
		$IMAGEREPOSITORY = "$VMWAREREPOSITORY/$imagename";
	}
	else {
		return 0;
	}

	#list files in image directory, account for main .gz file and any .gz.00X files
	if (open(FILELIST, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1 |")) {
		my @filelist = <FILELIST>;
		close(FILELIST);
		my $size = 0;
		foreach my $f (@filelist) {
			if ($f =~ /$imagename.gz|vmdk/) {
				my ($presize, $blah) = split(" ", $f);
				$size += $presize;
			}
		}
		if ($size == 0) {
			#strange imagename not found
			return 0;
		}
		return int($size / 1024);
	} ## end if (open(FILELIST, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1 |"...

	return 0;
} ## end sub getimagesize

#/////////////////////////////////////////////////////////////////////////////

=head2 collectsshkeys

 Parameters  : node
 Returns     : 0 or 1
 Description : collects ssh keys from client

=cut

sub collectsshkeys {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	if (!(defined($node))) {
		return 0;
	}
	my ($id, $ipaddress, $type, $hostname, $currentimage, $osname);
	#if lab client and OS is linux or solaris fetch ssh keys
	#store repective key into computer table for the node
	my $dbh = getnewdbh;
	#collect a little information about the node.
	my $sel = $dbh->prepare("SELECT c.id,c.IPaddress,c.hostname,c.type,o.name,i.name FROM computer c, OS o, image i WHERE c.currentimageid=i.id AND i.OSid=o.id AND c.hostname REGEXP ?") or notify($ERRORS{'WARNING'}, 0, "could not prepare collect computer detail statement" . $dbh->errstr());
	$sel->execute($node) or notify($ERRORS{'WARNING'}, 0, "Problem could not execute on computer detail : " . $dbh->errstr);
	my $rows = $sel->rows;
	$sel->bind_columns(\($id, $ipaddress, $hostname, $type, $osname, $currentimage));

	if ($rows) {
		if ($sel->fetch) {
			print "$id,$ipaddress,$hostname,$type,$osname,$currentimage\n";
		}
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "no information found in computer table for $node ");
		$dbh->disconnect if !defined $ENV{dbh};
		return 0;
	}

	#what identity do we use
	my $key;
	if ($type =~ /lab/) {
		if ($osname =~ /rhel/) {
			$key = $IDENTITY_linux_lab;
		}
		else {
			$key = $IDENTITY_solaris_lab;
		}
	}
	#send fetch keys flag to node
	my @sshcmd = run_ssh_command($ipaddress, $key, "echo fetch > /home/vclstaff/clientdata; echo 1 > /home/vclstaff/flag", "vclstaff", "24");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Warning|denied|No such/) {
			notify($ERRORS{'CRITICAL'}, 0, "node $node ouput @{ $sshcmd[1] }");
		}
	}
	#retrieve the keys
	#sleep 6, node flag check is every 5 sec
	sleep 6;
	my ($loop, $ct) = 0;
	undef @sshcmd;
	@sshcmd = run_ssh_command($ipaddress, $key, "ls -1", "vclstaff", "24");
	foreach my $l (@{$sshcmd[1]}) {
		chomp($l);

		if ($l =~ /ssh_host/) {
			#print "$l\n";
			if (!(-d "/tmp/$id")) {
				notify($ERRORS{'OK'}, 0, "creating /tmp/$id") if (mkdir("/tmp/$id"));
			}
			if (run_scp_command("vclstaff\@$ipaddress:/home/vclstaff/$l", "/tmp/$id/$l", $key, "24")) {
				$ct++;
			}
		}
	}    #foreach
	if ($ct < 6) {
		notify($ERRORS{'OK'}, 0, "count copied, is less than 6 trying again");
		if ($loop > 2) {
			notify($ERRORS{'CRITICAL'}, 0, "could not copy 6 ssh keys from $node");
			$dbh->disconnect if !defined $ENV{dbh};
			return 0;
		}
		$loop++;
		goto COLLECT;
	} ## end if ($ct < 6)
	     #read in key files
	my $dsa;
	my $dsapub;
	my $rsa;
	my $rsapub;
	my $hostbuffer = "";
	my $hostpub;

	if (open(DSA, "/tmp/$id/ssh_host_dsa_key")) {
		print "slurping dsa_key\n";
		#@dsa=<DSA>;
		read(DSA, $dsa, 1024);
		close(DSA);
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open dsa file $!");
	}

	if (open(DSAPUB, "/tmp/$id/ssh_host_dsa_key.pub")) {
		print "slurping dsa_pub_key\n";
		#@dsapub=<DSAPUB>;
		read(DSAPUB, $dsapub, 1024);
		close(DSAPUB);
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open dsa.pub file $!");
	}

	if (open(RSA, "/tmp/$id/ssh_host_rsa_key")) {
		print "slurping rsa_key\n";
		#@rsa=<RSA>;
		read(RSA, $rsa, 1024);
		close(RSA);
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open rsa file $!");
	}

	if (open(RSAPUB, "/tmp/$id/ssh_host_rsa_key.pub")) {
		print "slurping rsa_pub_key\n";
		#@rsapub=<RSAPUB>;
		read(RSAPUB, $rsapub, 1024);
		close(RSAPUB);
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open rsa.pub file $!");
	}

	if (open(HOSTPUB, "/tmp/$id/ssh_host_key.pub")) {
		print "slurping host_pub_key\n";
		#@hostpub=<HOSTPUB>;
		read(HOSTPUB, $hostpub, 1024);
		close(HOSTPUB);
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open host.pub file $!");
	}

	#binary file
	if (open(HOST, "/tmp/$id/ssh_host_key.pub")) {
		print "slurping host_key\n";
		binmode(HOST);
		my $r = read(HOST, $hostbuffer, 1024);
		#@hostbuffer=<HOST>;
		close(HOST);
		if (defined($r)) {
			#print "read $r k chunks on binary file ssh_host_key.pub\n";
			#notify($ERRORS{'OK'},0,"read $r k chunks on binary file ssh_host_key.pub");
			#print "uploading: $dsa\n $dsapub\n$rsa\n$rsapub\n$hostbuffer\n$hostpub \n $id\n";
		}
		else {
			#print "could not read binary file ssh_host_key.pub\n";
			notify($ERRORS{'CRITICAL'}, 0, "could not read binary file ssh_host_key.pub");
		}
	} ## end if (open(HOST, "/tmp/$id/ssh_host_key.pub"...
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not open host binary file $!");
	}

	#print "uploading: @dsa\n @dsapub\n @rsa\n @rsapub\n $hostbuffer \n,@hostpub \n $id\n";
	#upload keys to db

	my $update = $dbh->prepare("UPDATE computer SET dsa=?,dsapub=?,rsa=?,rsapub=?,hostpub=? WHERE id=?") or print "could not prepare update key statement node= $node id= $id" . $dbh->errstr();
	$update->execute($dsa, $dsapub, $rsa, $rsapub, $hostpub, $id) or print "Problem could not execute on update key statement node= $node id= $id: " . $dbh->errstr;

	$dbh->disconnect if !defined $ENV{dbh};

} ## end sub collectsshkeys

#/////////////////////////////////////////////////////////////////////////////

=head2  restoresshkeys

 Parameters  : node
 Returns     : 0 or 1
 Description : NOT COMPLETED
					connects to node and replaces ssh keys with keys stored in db
=cut

sub restoresshkeys {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	if (!(defined($node))) {
		return 0;
	}
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
		my $jabber_connect_result = $jabber_client->Connect(hostname => $jabServer, port => $jabPort);
		if (!$jabber_connect_result) {
			notify($ERRORS{'DEBUG'}, 0, "connected to jabber server: $jabServer, port: $jabPort, result: $jabber_connect_result");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to connect to jabber server: $jabServer, port: $jabPort, result: $jabber_connect_result");
			return;
		}
		
		# Attempt to authenticate to jabber
		my @jabber_auth_result = $jabber_client->AuthSend(
			username => $jabUser,
			password => $jabPass,
			resource => $jabResource
		);
		
		# Check the jabber authentication result
		if ($jabber_auth_result[0] && $jabber_auth_result[0] eq "ok") {
			notify($ERRORS{'DEBUG'}, 0, "authenticated to jabber server: $jabServer, user: $jabUser, resource: $jabResource");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to authenticate to jabber server: $jabServer, user: $jabUser, resource: $jabResource");
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
			notify($ERRORS{'WARNING'}, 0, "failed to send jabber message to $jabUser");
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

=head2 check_uptime

 Parameters  : $node, $IPaddress, $OSname, $type, $log
 Returns     : value or 0(failed) + failure message
 Description : fetchs uptime of remote node

=cut

sub check_uptime {
	my ($node, $IPaddress, $OSname, $type, $log) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	$log = 0 if (!(defined($log)));
	notify($ERRORS{'WARNING'}, $log, "node is not defined")      if (!(defined($node)));
	notify($ERRORS{'WARNING'}, $log, "IPaddress is not defined") if (!(defined($IPaddress)));
	notify($ERRORS{'WARNING'}, $log, "OSname is not defined")    if (!(defined($OSname)));
	notify($ERRORS{'WARNING'}, $log, "type is not defined")      if (!(defined($type)));

	if ($type eq "lab") {
		my $identity;
		if ($OSname =~ /sun4x/) {
			$identity = $IDENTITY_solaris_lab;
		}
		elsif ($OSname =~ /rhel/) {
			$identity = $IDENTITY_linux_lab;
		}
		else {
			return (0, "failure : OSname not match");
		}
		my @sshcmd = run_ssh_command($node, $identity, "uptime", "vclstaff", "24");
		my $l;
		foreach $l (@{$sshcmd[1]}) {
			if ($l =~ /(\s*\d*:\d*:\d*\s*up\s*)(\d*)(\s*days,)/) {
				return $2;
			}
			if ($l =~ /^(\s*\d*:\d*)(am|pm)(\s*up\s*)(\d*)(\s*day)/) {
				return $4;
			}
			if ($l =~ /(\s*\d*:\d*:\d*\s*up)/) {
				return 1;
			}
			if ($l =~ /password/) {
				notify($ERRORS{'WARNING'}, $log, "@{ $sshcmd[1] }");
				return (0, $l);
			}
		} ## end foreach $l (@{$sshcmd[1]})


	} ## end if ($type eq "lab")
	elsif ($type eq "blade") {
		return 0;
	}
	elsif ($type eq "virtualmachine") {
		return 0;
	}

} ## end sub check_uptime

#/////////////////////////////////////////////////////////////////////////////

=head2  timefloor15interval

 Parameters  : time string(optional)
 Returns     : the nearest 15 minute interval 0,15,30,45 less than the current time and zero seconds
 Description :

=cut

sub timefloor15interval {
	my $time = $_[0];
	# we got nothing set to current time
	if (!defined($time)) {
		$time = makedatestring;
	}
	#we got a null timestamp, set it to current time
	if ($time =~ /0000-00-00 00:00:00/) {
		$time = makedatestring;
	}

	#format received: year-mon-mday hr:min:sec
	my ($vardate, $vartime) = split(/ /, $time);
	my ($yr, $mon, $mday) = split(/-/, $vardate);
	my ($hr, $min, $sec)  = split(/:/, $vartime);
	$sec = "0";
	if ($min < 15) {
		$min = 0;
	}
	elsif ($min < 30) {
		$min = 15;
	}
	elsif ($min < 45) {
		$min = 30;
	}
	elsif ($min < 60) {
		$min = 45;
	}

	my $datestring = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $yr, $mon, $mday, $hr, $min, $sec);
	return $datestring;

} ## end sub timefloor15interval


#/////////////////////////////////////////////////////////////////////////////

=head2  system_monitoring

 Parameters  : $nodename, $imagename, $action, $type
 Returns     : 0 or 1
 Description : primarily used for ITM -
					if windows ITM servicce exist start or stop it

=cut

sub system_monitoring {
	my ($nodename, $imagename, $action, $type) = @_;
	my ($package,  $filename,  $line,   $sub)  = caller(0);
	notify($ERRORS{'WARNING'}, 0, "nodename is not defined")  if (!(defined($nodename)));
	notify($ERRORS{'WARNING'}, 0, "imagename is not defined") if (!(defined($imagename)));
	notify($ERRORS{'WARNING'}, 0, "action is not defined")    if (!(defined($action)));
	notify($ERRORS{'WARNING'}, 0, "type is not defined")      if (!(defined($type)));

	my ($identity, $imagetype, $l);
	my @out;
	if ($imagename =~ /^(win|vmware)/) {
		$imagetype = "windows";
		$identity  = $IDENTITY_wxp;
	}
	elsif ($imagename =~ /^(rh|fc[0-9]image|esx)/) {
		$imagetype = "linux";
		$identity  = $IDENTITY_bladerhel;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not determin OS for $imagename : $type monitoring on $nodename for $imagename");
		return 0;
	}
	my @sshcmd;
	if ($type eq "ITM" && $imagetype eq "windows") {
		#check and start monitoring for ITM
		my $exists = 0;
		@sshcmd = run_ssh_command($nodename, $identity, "cmd /c C:\/WINDOWS\/system32\/sc qc KNTCMA_Primary", "root");
		foreach $l (@{$sshcmd[1]}) {
			next if ($l =~ /Warning: Permanently added/);
			if ($l =~ /The specified service does not exist/) {
				#not there skip and return
				return 0;
			}
			if ($l =~ /SERVICE_NAME: KNTCMA_Primary/) {
				$exists = 1;
			}
		} ## end foreach $l (@{$sshcmd[1]})

		#preform action
		if ($action =~ /start|stop/) {
			undef @sshcmd;
			@sshcmd = run_ssh_command($nodename, $identity, "cmd /c C:\/WINDOWS\/system32\/sc $action KNTCMA_Primary", "root");
			foreach $l (@{$sshcmd[1]}) {
				next if ($l =~ /Warning: Permanently added/);
				if ($l =~ /SERVICE_NAME: KNTCMA_Primary/) {
					return 1;
				}
				if ($l =~ /The service has not been started/) {
					return 1 if ($action eq "stop");
				}
				if ($l =~ /service is already running/) {
					return 1 if ($action eq "start");
				}
				#can run more checks to determine if it is running, stopped or start|stop pending
				#
			} ## end foreach $l (@{$sshcmd[1]})
		} ## end if ($action =~ /start|stop/)
		else {
			notify($ERRORS{'CRITICAL'}, 0, "skipping start up, $action not a supported action  for ITM service KNTCMA_Primary");
			return 0;
		}
	} ## end if ($type eq "ITM" && $imagetype eq "windows")
	elsif ($imagetype eq "linux") {
		#TODO - insert code for Linux related monitoring agents
	}
	return 0;

} ## end sub system_monitoring

#/////////////////////////////////////////////////////////////////////////////

=head2 monitorloading

 Parameters  : $reservationid, $requestedimagename, $computerid, $nodename, $ert
 Returns     : 0 or 1
 Description : using database loadlog table,
					monitor given node for available state

=cut


sub monitorloading {
	my ($reservationid, $requestedimagename, $computerid, $nodename, $ert) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "reservationid is not defined")      if (!(defined($reservationid)));
	notify($ERRORS{'WARNING'}, 0, "requestedimagename is not defined") if (!(defined($requestedimagename)));
	notify($ERRORS{'WARNING'}, 0, "computerid is not defined")         if (!(defined($computerid)));
	notify($ERRORS{'WARNING'}, 0, "nodename is not defined")           if (!(defined($nodename)));
	notify($ERRORS{'WARNING'}, 0, "ert is not defined")                if (!(defined($ert)));
	#get start time of this wait period
	my $mystarttime = convert_to_epoch_seconds;
	my $currentime  = 0;

	my $mydbhandle = getnewdbh();
	my $selhdl = $mydbhandle->prepare(
		"SELECT s.loadstatename,c.additionalinfo,c.timestamp
                                     FROM computerloadlog c, computerloadstate s
                                     WHERE s.id = c.loadstateid AND c.loadstateid=s.id AND c.reservationid =? AND c.computerid=?") or notify($ERRORS{'WARNING'}, 0, "could not prepare statement to monitor for available stat" . $mydbhandle->errstr());

	my $selhdl2 = $mydbhandle->prepare("SELECT s.name FROM computer c,state s WHERE c.stateid=s.id AND c.id =?") or notify($ERRORS{'WARNING'}, 0, "could not prepare statement check node for available state" . $mydbhandle->errstr());

	#get est reload time of image

	my $available     = 0;
	my $stillrunnning = 1;
	my $state;
	my $s1     = 0;
	my $s2     = 0;
	my $s3     = 0;
	my $s4     = 0;
	my $s5     = 0;
	my $s6     = 0;
	my $s7     = 0;
	my $s8     = 0;
	my $s1time = 0;
	my $s2time = 0;
	my $s3time = 0;
	my $s4time = 0;
	my $s5time = 0;
	my $s6time = 0;
	my $s7time = 0;

	MONITORLOADCHECKS:
	$selhdl->execute($reservationid, $computerid) or notify($ERRORS{'WARNING'}, 0, "could not execute statement to monitor for available stat" . $mydbhandle->errstr());
	my $rows = $selhdl->rows;
	#check state of machine
	$selhdl2->execute($computerid) or notify($ERRORS{'WARNING'}, 0, "could not execute statement to check state of blade " . $mydbhandle->errstr());
	my $irows = $selhdl2->rows;
	notify($ERRORS{'OK'}, 0, "checking if $nodename is available");
	if ($irows) {
		if (my @irow = $selhdl2->fetchrow_array) {
			if ($irow[0] =~ /available/) {
				#good machine is available
				notify($ERRORS{'OK'}, 0, "good $nodename is now available");
				return 1;
			}
			elsif ($irow[0] =~ /failed/) {
				notify($ERRORS{'WARNING'}, 0, "$nodename reported failure");
				return 0;
			}
		} ## end if (my @irow = $selhdl2->fetchrow_array)
	} ## end if ($irows)
	else {
		notify($ERRORS{'WARNING'}, 0, "strange no records found for computerid $computerid $nodename - possible issue with query");
		return 0;
	}
	my @row;
	while (@row = $selhdl->fetchrow_array) {
		if (!$s1) {
			if ($row[0] =~ /loadimage|loadimagevmware/) {
				notify($ERRORS{'OK'}, 0, "detected s1");
				$s1     = 1;
				$s1time = convert_to_epoch_seconds($row[2]);
			}
		}
		if (!$s2) {
			if ($row[0] =~ /startload/) {
				notify($ERRORS{'OK'}, 0, "detected startload state");
				if ($row[1] =~ /$requestedimagename/) {
					notify($ERRORS{'OK'}, 0, "good $nodename is loading $requestedimagename");
					$s2     = 1;
					$s2time = convert_to_epoch_seconds($row[2]);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "$nodename is not loading desired image");
					return 0;
				}
			} ## end if ($row[0] =~ /startload/)
		} ## end if (!$s2)
		if (!$s3) {
			if ($row[0] =~ /rinstall|transfervm/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] for $nodename");
				$s3     = 1;
				$s3time = convert_to_epoch_seconds($row[2]);
			}

		}
		if (!$s4) {
			if ($row[0] =~ /xcatstage5|startvm/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] for $nodename");
				$s4     = 1;
				$s4time = convert_to_epoch_seconds($row[2]);
			}
		}
		if (!$s5) {
			if ($row[0] =~ /bootstate|vmstage1/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] for $nodename");
				$s5     = 1;
				$s5time = convert_to_epoch_seconds($row[2]);
			}
		}
		if (!$s6) {
			if ($row[0] =~ /xcatround3|vmstage5/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] for $nodename");
				$s6     = 1;
				$s6time = convert_to_epoch_seconds($row[2]);
			}
		}
		if (!$s7) {
			if ($row[0] =~ /xcatREADY|vmwareready/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] for $nodename");
				$s7     = 1;
				$s7time = convert_to_epoch_seconds($row[2]);
			}
		}
		if (!$s8) {
			if ($row[0] =~ /loadimagecomplete|nodeready/) {
				notify($ERRORS{'OK'}, 0, "detected $row[0] returning to calling process");
				$s8 = 1;
				#ready to return
				return 1;
			}
		}
		if ($row[0] =~ /failed/) {
			return 0;
		}
	} ## end while (@row = $selhdl->fetchrow_array)

	notify($ERRORS{'OK'}, 0, "current stages passed s1='$s1' s2='$s2' s3='$s3' s4='$s4' s5='$s5' s6='$s6' s7='$s7' going to sleep 15");
	sleep 15;
	#prevent infinite loop - check how long we've waited
	$currentime = convert_to_epoch_seconds;
	my $delta = $currentime - $mystarttime;
	#check some state times
	#if($s5){
	#   if(!$s6){
	#      #how long has it been since $s5 was set
	#      my $s5diff = ($currentime-$s5time);
	#      if($s5diff > 5*60){
	#         #greater than 5 minutes
	#         notify($ERRORS{'OK'},0,"waited over 5 minutes - $s5diff seconds for stage 6 to complete, returning");
	#         return 0;
	#      }
	#   }
	#   if(!$s7){
	#      #how long has it been since $s6 was set
	#      my $s6diff = $currentime-$s6time;
	#      if($s6diff > 6*60){
	#         #greater than 4 minutes
	#         notify($ERRORS{'OK'},0,"waited over 6 minutes - $s6diff seconds for stage 7 to be reached, returning");
	#         return 0;
	#      }
#
#       }
#    }

	if ($delta > ($ert * 60)) {
		notify($ERRORS{'OK'}, 0, "waited $delta seconds and we have exceeded our ert of $ert, returning");
		#just return at this point - it should have been completed by now
		return 0;
	}

	goto MONITORLOADCHECKS;

} ## end sub monitorloading

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

	# Check to make sure the reservation has not been deleted
	# The INSERT statement will fail if it has been deleted because of the key constraint on reservationid
	if (is_reservation_deleted($resid)) {
		notify($ERRORS{'OK'}, 0, "computerloadlog entry not inserted, reservation has been deleted");
		return 1;
	}

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

=head2 checkonprocess

 Parameters  : $state, $requestid
 Returns     : 0 or 1
 Description : checks the process list to confirm the process for given request is actually running
					in case the process dies for some reason

=cut


sub checkonprocess {
	my ($request_state_name, $request_id) = @_;

	notify($ERRORS{'WARNING'}, 0, "state is not defined")     if (!(defined($request_state_name)));
	notify($ERRORS{'WARNING'}, 0, "requestid is not defined") if (!(defined($request_id)));
	return if (!(defined($request_state_name)));
	return if (!(defined($request_id)));

	# Use the pgrep utility to find processes matching the state and request ID
	if (open(PGREP, "/bin/pgrep -fl '$request_state_name $request_id' 2>&1 |")) {
		my @process_list = <PGREP>;
		close(PGREP);
		notify($ERRORS{'DEBUG'}, 0, "pgrep found " . scalar @process_list . " processes matching state=$request_state_name and request=$request_id");
		return scalar @process_list;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open handle for pgrep process");
		return;
	}
} ## end sub checkonprocess

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
	my ($package, $filename, $line, $sub) = caller(0);

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

 Parameters  : SQL statement
 Returns     : 1 if successful, 0 if failed
 Description : Executes an SQL statement

=cut

sub database_execute {
	my ($sql_statement, $database) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

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
	if (!($statement_handle->execute())) {
		notify($ERRORS{'WARNING'}, 0, "could not execute SQL statement, $sql_statement, " . $dbh->errstr());
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return;
	}

	# Get the id of the last inserted record if this is an INSERT statement
	if ($sql_statement =~ /insert/i) {
		my $sql_insertid = $statement_handle->{'mysql_insertid'};
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return $sql_insertid;
	}
	else {
		$statement_handle->finish;
		$dbh->disconnect if !defined $ENV{dbh};
		return 1;
	}

} ## end sub database_execute

#/////////////////////////////////////////////////////////////////////////////

=head2  get_request_info

 Parameters  : databasehandle, management node id
 Returns     : hash0 or 1
 Description : gets all reservation related information

=cut


sub get_request_info {
	my ($request_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	if (!(defined($request_id))) {
		notify($ERRORS{'WARNING'}, 0, "request ID was not specified");
		return 0;
	}

	my $select_statement = "
   SELECT DISTINCT

   request.id AS request_id,
   request.stateid AS request_stateid,
   request.userid AS request_userid,
   request.laststateid AS request_laststateid,
   request.logid AS request_logid,
   request.forimaging AS request_forimaging,
   request.test AS request_test,
   request.preload AS request_preload,
   request.start AS request_start,
   request.end AS request_end,
   request.daterequested AS request_daterequested,
   request.datemodified AS request_datemodified,

   requeststate.name AS requeststate_name,

   requestlaststate.name AS requestlaststate_name,

   reservation.id AS reservation_id,
   reservation.requestid AS reservation_requestid,
   reservation.computerid AS reservation_computerid,
   reservation.imageid AS reservation_imageid,
   reservation.imagerevisionid AS reservation_imagerevisionid,
   reservation.managementnodeid AS reservation_managementnodeid,
   reservation.remoteIP AS reservation_remoteIP,
   reservation.lastcheck AS reservation_lastcheck,
   reservation.pw AS reservation_pw,

   image.id AS image_id,
   image.name AS image_name,
   image.prettyname AS image_prettyname,
   image.ownerid AS image_ownerid,
   image.deptid AS image_deptid,
   image.platformid AS image_platformid,
   image.OSid AS image_OSid,
   image.imagemetaid AS image_imagemetaid,
   image.minram AS image_minram,
   image.minprocnumber AS image_minprocnumber,
   image.minprocspeed AS image_minprocspeed,
   image.minnetwork AS image_minnetwork,
   image.maxconcurrent AS image_maxconcurrent,
   image.reloadtime AS image_reloadtime,
   image.deleted AS image_deleted,
   image.test AS image_test,
   image.lastupdate AS image_lastupdate,
   image.forcheckout AS image_forcheckout,
   image.maxinitialtime AS image_maxinitialtime,
   image.project AS image_project,
   image.size AS image_size,
   image.architecture AS image_architecture,

   imagerevision.id AS imagerevision_id,
   imagerevision.imageid AS imagerevision_imageid,
   imagerevision.revision AS imagerevision_revision,
   imagerevision.userid AS imagerevision_userid,
   imagerevision.datecreated AS imagerevision_datecreated,
   imagerevision.deleted AS imagerevision_deleted,
   imagerevision.production AS imagerevision_production,
   imagerevision.comments AS imagerevision_comments,
   imagerevision.imagename AS imagerevision_imagename,

   imagedept.name AS imagedept_name,
   imagedept.prettyname AS imagedept_prettyname,

   imageplatform.name AS imageplatform_name,

   OS.name AS OS_name,
   OS.prettyname AS OS_prettyname,
	OS.type AS OS_type,
	OS.installtype AS OS_installtype,
	OS.sourcepath AS OS_sourcepath,

	imageOSmodule.name AS imageOSmodule_name,
	imageOSmodule.prettyname AS imageOSmodule_prettyname,
	imageOSmodule.description AS imageOSmodule_description,
	imageOSmodule.perlpackage AS imageOSmodule_perlpackage,

   user.id AS user_id,
   user.uid AS user_uid,
   user.unityid AS user_unityid,
   user.affiliationid AS user_affiliationid,
   user.firstname AS user_firstname,
   user.middlename AS user_middlename,
   user.lastname AS user_lastname,
   user.preferredname AS user_preferredname,
   user.email AS user_email,
   user.emailnotices AS user_emailnotices,
   user.IMtypeid AS user_IMtypeid,
   user.IMid AS user_IMid,
   user.adminlevelid AS user_adminlevelid,
   user.width AS user_width,
   user.height AS user_height,
   user.bpp AS user_bpp,
   user.audiomode AS user_audiomode,
   user.mapdrives AS user_mapdrives,
   user.mapprinters AS user_mapprinters,
   user.mapserial AS user_mapserial,
   user.showallgroups AS user_showallgroups,
   user.lastupdated AS user_lastupdated,

   adminlevel.name AS adminlevel_name,

   affiliation.name AS affiliation_name,
   affiliation.dataUpdateText AS affiliation_dataUpdateText,
   affiliation.sitewwwaddress AS affiliation_sitewwwaddress,
   affiliation.helpaddress AS affiliation_helpaddress,


   IMtype.name AS IMtype_name,

   computer.id AS computer_id,
   computer.stateid AS computer_stateid,
   computer.ownerid AS computer_ownerid,
   computer.deptid AS computer_deptid,
   computer.platformid AS computer_platformid,
   computer.scheduleid AS computer_scheduleid,
   computer.currentimageid AS computer_currentimageid,
   computer.preferredimageid AS computer_preferredimageid,
   computer.imagerevisionid AS computer_imagerevisionid,
   computer.RAM AS computer_RAM,
   computer.procnumber AS computer_procnumber,
   computer.procspeed AS computer_procspeed,
   computer.network AS computer_network,
   computer.hostname AS computer_hostname,
   computer.IPaddress AS computer_IPaddress,
   computer.privateIPaddress AS computer_privateIPaddress,
   computer.eth0macaddress AS computer_eth0macaddress,
   computer.eth1macaddress AS computer_eth1macaddress,
   computer.type AS computer_type,
	computer.provisioningid AS computer_provisioningid,
   computer.drivetype AS computer_drivetype,
   computer.deleted AS computer_deleted,
   computer.notes AS computer_notes,
   computer.lastcheck AS computer_lastcheck,
   computer.location AS computer_location,
   computer.dsa AS computer_dsa,
   computer.dsapub AS computer_dsapub,
   computer.rsa AS computer_rsa,
   computer.rsapub AS computer_rsapub,
   computer.host AS computer_host,
   computer.hostpub AS computer_hostpub,
   computer.vmhostid AS computer_vmhostid,

   computerdept.name AS computerdept_name,
   computerdept.prettyname AS computerdept_prettyname,

   computerplatform.name AS computerplatform_name,

   computerstate.name AS computerstate_name,

   computerschedule.name AS computerschedule_name,

	computerprovisioning.name AS computerprovisioning_name,
	computerprovisioning.prettyname AS computerprovisioning_prettyname,
	computerprovisioning.moduleid AS computerprovisioning_moduleid,

	computerprovisioningmodule.name AS computerprovisioningmodule_name,
	computerprovisioningmodule.prettyname AS computerprovisioningmodule_prettyname,
	computerprovisioningmodule.description AS computerprovisioningmodule_description,
	computerprovisioningmodule.perlpackage AS computerprovisioningmodule_perlpackage

   FROM
   request,
   user,
   adminlevel,
   affiliation,
   IMtype,
   reservation,
   image,
   dept imagedept,
   platform imageplatform,
   imagerevision,
   OS,
	module imageOSmodule,
   computer,
	provisioning computerprovisioning,
	module computerprovisioningmodule,
   dept computerdept,
   platform computerplatform,
   schedule computerschedule,
   state requeststate,
   state requestlaststate,
   state computerstate

   WHERE
   request.id = $request_id
   AND user.id = request.userid
   AND adminlevel.id = user.adminlevelid
   AND affiliation.id = user.affiliationid
   AND reservation.requestid = request.id
   AND image.id = imagerevision.imageid
   AND imagedept.id = image.deptid
   AND imageplatform.id = image.platformid
   AND imagerevision.id = reservation.imagerevisionid
   AND OS.id = image.OSid
	AND imageOSmodule.id = OS.moduleid
   AND computer.id = reservation.computerid
   AND computerdept.id = computer.deptid
   AND computerplatform.id = computer.platformid
   AND computerschedule.id = computer.scheduleid
   AND computerstate.id = computer.stateid
	AND computerprovisioning.id = computer.provisioningid
	AND computerprovisioningmodule.id = computerprovisioning.moduleid
   AND requeststate.id = request.stateid
   AND requestlaststate.id = request.laststateid
	AND IMtype.id = user.IMtypeid

   GROUP BY
   reservation.id
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "request id $request_id information could not be retrieved");
		return ();
	}

	# Build the hash
	my %request_info;

	for (@selected_rows) {
		my %reservation_row = %{$_};

		# Grab the reservation ID to make the code a little cleaner
		my $reservation_id = $reservation_row{reservation_id};

		# If this request only has 1 reservation, populate the RESERVATIONID key
		# This is mainly for testing convenience
		# Calling program is responsible for setting this based on which reservation it's processing
		$request_info{RESERVATIONID} = $reservation_id if (scalar @selected_rows == 1);

		# Check if the image associated with this reservation has meta data
		# get_imagemeta_info will return default values if image_imagemetaid is undefined
		my %imagemeta_info = get_imagemeta_info($reservation_row{image_imagemetaid});
		# Make sure metadata was located if imagemetaid was specified for the image
		if (!%imagemeta_info) {
			notify($ERRORS{'WARNING'}, 0, "imagemetaid=" . $reservation_row{image_imagemetaid} . " was specified for image id=" . $reservation_row{image_id} . " but imagemeta could not be found");
		}
		else {
			# Image meta data found, add it to the hash
			$request_info{reservation}{$reservation_id}{image}{imagemeta} = \%imagemeta_info;
		}

		# Check if the computer associated with this reservation has a vmhostid set
		if ($reservation_row{computer_vmhostid}) {
			my %vmhost_info = get_vmhost_info($reservation_row{computer_vmhostid});
			# Make sure vmhost was located if vmhostid was specified for the image
			if (!%vmhost_info) {
				notify($ERRORS{'WARNING'}, 0, "vmhostid=" . $reservation_row{computer_vmhostid} . " was specified for computer id=" . $reservation_row{computer_id} . " but vmhost could not be found");
			}
			else {
				# Image meta data found, add it to the hash
				$request_info{reservation}{$reservation_id}{computer}{vmhost} = \%vmhost_info;
			}
		} ## end if ($reservation_row{computer_vmhostid})

		# Get the computer's current image information
		if ($reservation_row{computer_currentimageid}) {
			my %computer_currentimage_info;
			if (%computer_currentimage_info = get_image_info($reservation_row{computer_currentimageid})) {
				$request_info{reservation}{$reservation_id}{computer}{currentimage} = \%computer_currentimage_info;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to get current image info for computer");
			}
		}
		else {
			# currentimageid wasn't set for the computer
			notify($ERRORS{'WARNING'}, 0, "currentimageid is not set for computer id=" . $reservation_row{computer_id});
		}

		# Get the computer's preferred image information
		if ($reservation_row{computer_preferredimageid}) {
			my %computer_preferredimage_info;
			if (%computer_preferredimage_info = get_image_info($reservation_row{computer_preferredimageid})) {
				$request_info{reservation}{$reservation_id}{computer}{preferredimage} = \%computer_preferredimage_info;

				# For preferred imageid get the production imagerevision info
				my %preferred_imagerevision_info;
				if (%preferred_imagerevision_info = get_production_imagerevision_info($reservation_row{computer_preferredimageid})) {
					$request_info{reservation}{$reservation_id}{computer}{preferredimagerevision} = \%preferred_imagerevision_info;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to get preferred image revision info for computer, image revision ID is not set, tried to get production image for image ID " . $reservation_row{computer_preferredimageid});
				}
			} ## end if (%computer_preferredimage_info = get_image_info...
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to get preferredimage image info for computer");
			}
		} ## end if ($reservation_row{computer_preferredimageid...
		else {
			# currentimageid wasn't set for the computer
			notify($ERRORS{'WARNING'}, 0, "preferredimageid is not set for computer id=" . $reservation_row{computer_id});
		}

		# Get the computer's current imagemeta information
		my %computer_currentimagerevision_info;
		if ($reservation_row{computer_imagerevisionid} > 0) {
			# imagerevisionid is set for computer, get the info for that specific revision
			if (%computer_currentimagerevision_info = get_imagerevision_info($reservation_row{computer_imagerevisionid})) {
				$request_info{reservation}{$reservation_id}{computer}{currentimagerevision} = \%computer_currentimagerevision_info;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to get current image revision info for computer, image revision ID is set to " . $reservation_row{computer_imagerevisionid});
			}
		}
		else {
			# imagerevisionid is not set for computer, get the info for the production revision of currentimageid
			if (%computer_currentimagerevision_info = get_production_imagerevision_info($reservation_row{computer_currentimageid})) {
				$request_info{reservation}{$reservation_id}{computer}{currentimagerevision} = \%computer_currentimagerevision_info;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to get current image revision info for computer, image revision ID is not set, tried to get production image for image ID " . $reservation_row{computer_currentimageid});
			}
		}


		# Loop through all the columns returned for the reservation
		foreach my $key (keys %reservation_row) {
			my $value = $reservation_row{$key};

			# Create another variable by stripping off the column_ part of each key
			# This variable stores the original (correct) column name
			(my $original_key = $key) =~ s/^.+_//;

			if ($key =~ /request_/) {
				# Set the top-level key if not already set
				$request_info{$original_key} = $value if (!$request_info{$original_key});
			}
			elsif ($key =~ /requeststate_/) {
				$request_info{state}{$original_key} = $value if (!$request_info{state}{$original_key});
			}
			elsif ($key =~ /requestlaststate_/) {
				$request_info{laststate}{$original_key} = $value if (!$request_info{laststate}{$original_key});
			}
			elsif ($key =~ /user_/) {
				$request_info{user}{$original_key} = $value;
			}
			elsif ($key =~ /reservation_/) {
				$request_info{reservation}{$reservation_id}{$original_key} = $value;
			}
			elsif ($key =~ /image_/) {
				$request_info{reservation}{$reservation_id}{image}{$original_key} = $value;
			}
			elsif ($key =~ /imagedept_/) {
				$request_info{reservation}{$reservation_id}{image}{dept}{$original_key} = $value;
			}
			elsif ($key =~ /imageplatform_/) {
				$request_info{reservation}{$reservation_id}{image}{platform}{$original_key} = $value;
			}
			elsif ($key =~ /imagerevision_/) {
				$request_info{reservation}{$reservation_id}{imagerevision}{$original_key} = $value;
			}
			elsif ($key =~ /OS_/) {
				$request_info{reservation}{$reservation_id}{image}{OS}{$original_key} = $value;
			}
			elsif ($key =~ /imageOSmodule_/) {
				$request_info{reservation}{$reservation_id}{image}{OS}{module}{$original_key} = $value;
			}
			elsif ($key =~ /adminlevel_/) {
				$request_info{user}{adminlevel}{$original_key} = $value;
			}
			elsif ($key =~ /affiliation_/) {
				$request_info{user}{affiliation}{$original_key} = $value;
			}
			elsif ($key =~ /IMtype_/) {
				$request_info{user}{IMtype}{$original_key} = $value;
			}
			elsif ($key =~ /computer_/) {
				$request_info{reservation}{$reservation_id}{computer}{$original_key} = $value;
			}
			elsif ($key =~ /computerdept_/) {
				$request_info{reservation}{$reservation_id}{computer}{dept}{$original_key} = $value;
			}
			elsif ($key =~ /computerplatform_/) {
				$request_info{reservation}{$reservation_id}{computer}{platform}{$original_key} = $value;
			}
			elsif ($key =~ /computerschedule_/) {
				$request_info{reservation}{$reservation_id}{computer}{schedule}{$original_key} = $value;
			}
			elsif ($key =~ /computerstate_/) {
				$request_info{reservation}{$reservation_id}{computer}{state}{$original_key} = $value;
			}
			elsif ($key =~ /computerprovisioning_/) {
				$request_info{reservation}{$reservation_id}{computer}{provisioning}{$original_key} = $value;
			}
			elsif ($key =~ /computerprovisioningmodule_/) {
				$request_info{reservation}{$reservation_id}{computer}{provisioning}{module}{$original_key} = $value;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
			}

		}    # Close foreach key in reservation row
	}    # Close loop through selected rows

	# Set some default non-database values for the entire request
	# All data ever added to the hash should be initialized here
	$request_info{PID}              = '';
	$request_info{PPID}             = '';
	$request_info{PARENTIMAGE}      = '';
	$request_info{PRELOADONLY}      = '0';
	$request_info{SUBIMAGE}         = '';
	$request_info{user}{STANDALONE} = '0';
	$request_info{CHECKTIME}        = '';
	$request_info{NOTICEINTERVAL}   = '';
	$request_info{RESERVATIONCOUNT} = scalar keys %{$request_info{reservation}};
	$request_info{UPDATED}          = '0';

	# Each selected row represents a reservation associated with this request

	# Fix some of the data

	# Set the user's preferred name to the first name if it isn't defined
	if (!defined($request_info{user}{preferredname}) || !$request_info{user}{preferredname}) {
		$request_info{user}{preferredname} = $request_info{user}{firstname};
	}

	# Set the user's uid to to the VCL user ID if it's NULL
	if (!defined($request_info{user}{uid}) || !$request_info{user}{uid}) {
		$request_info{user}{uid} = $request_info{user}{id};
	}

	# Set the user's IMid to '' if it's NULL
	if (!defined($request_info{user}{IMid}) || !$request_info{user}{IMid}) {
		$request_info{user}{IMid} = '';
	}

	# Fix the unityid if non-NCSU account
	if ($request_info{user}{uid} >= 1000000) {
		my ($correct_unity_id, $user_domain) = split /@/, $request_info{user}{unityid};
		notify($ERRORS{'OK'}, 0, "non-NCSU user found: $request_info{user}{unityid}, $correct_unity_id from $user_domain");
		$request_info{user}{unityid}    = $correct_unity_id;
		$request_info{user}{STANDALONE} = 1;
	}

	# Affiliation specific changes
	if ($request_info{user}{affiliation}{name} ne "NCSU") {
		notify($ERRORS{'OK'}, 0, "non-NCSU user affiliation found: $request_info{user}{affiliation}{name}");
		$request_info{user}{STANDALONE} = 1;
	}

	# For test account only
	if ($request_info{user}{unityid} =~ /vcladmin/) {
		$request_info{user}{STANDALONE} = 1;
	}

	# Set the user's affiliation sitewwwaddress and help address if not defined or blank
	if (!defined($request_info{user}{affiliation}{sitewwwaddress}) || !$request_info{user}{affiliation}{sitewwwaddress}) {
		$request_info{user}{affiliation}{sitewwwaddress} = 'http://cwiki.apache.org/VCL';
	}
	if (!defined($request_info{user}{affiliation}{helpaddress}) || !$request_info{user}{affiliation}{helpaddress}) {
		$request_info{user}{affiliation}{helpaddress} = 'vcl-user@incubator.apache.org';
	}



	# Loop through all the reservations
	foreach my $reservation_id (keys %{$request_info{reservation}}) {

		# Confirm lastcheck time is not NULL
		if (!defined($request_info{reservation}{$reservation_id}{lastcheck})) {
			$request_info{reservation}{$reservation_id}{lastcheck} = 0;
		}

		# Set the reservation remote IP to 0 if it's NULL
		if (!defined($request_info{reservation}{$reservation_id}{remoteIP})) {
			$request_info{reservation}{$reservation_id}{remoteIP} = 0;
		}

		# Set the short name of the computer based on the hostname
		my $computer_hostname = $request_info{reservation}{$reservation_id}{computer}{hostname};
		$computer_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/;
		my $computer_shortname = $1;
		$request_info{reservation}{$reservation_id}{computer}{SHORTNAME} = $computer_shortname;

		# Add the managementnode info to the hash
		my $management_node_id   = $request_info{reservation}{$reservation_id}{managementnodeid};
		my $management_node_info = get_management_node_info($management_node_id);
		if (!$management_node_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve management node info");
			$request_info{reservation}{$reservation_id}{managementnode} = 0;
		}
		else {
			$request_info{reservation}{$reservation_id}{managementnode} = $management_node_info;
		}

		# Set the node name based on the type of computer
		my $computer_type = $request_info{reservation}{$reservation_id}{computer}{type};
		my $computer_id = $request_info{reservation}{$reservation_id}{computer}{id};

		# Figure out the nodename based on the type of computer
		my $computer_nodename;
		if ($computer_type eq "blade") {
			$computer_nodename = $computer_shortname;
		}
		elsif ($computer_type eq "lab") {
			$computer_nodename = $computer_hostname;
		}
		elsif ($computer_type eq "virtualmachine") {
			$computer_nodename = $computer_shortname;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "computer=$computer_id is of an unknown or unusual type=$computer_type");
		}
		$request_info{reservation}{$reservation_id}{computer}{NODENAME} = $computer_nodename;

		# Set the image identity file path
		my $imagerevision_imagename = $request_info{reservation}{$reservation_id}{imagerevision}{imagename};
		my $image_os_type = $request_info{reservation}{$reservation_id}{image}{OS}{type};

		my $identity_file_path;
		if($computer_type =~ /blade|virtualmachine/){
			if($image_os_type =~ /windows/i){
				$identity_file_path = $IDENTITY_wxp;
			}
			elsif ($image_os_type =~ /linux/i){
				$identity_file_path = $IDENTITY_bladerhel;
			}
			else{
				notify($ERRORS{'WARNING'}, 0, "computer_type=$computer_type is of an unknown or unusual image_os_type=$image_os_type type=$computer_type");
			}
		}
		elsif($computer_type eq "lab"){
			if ($imagerevision_imagename =~ /realmrh|i386_linux26/) {
				$identity_file_path = $IDENTITY_linux_lab;
			}
			elsif ($imagerevision_imagename =~ /sun/) {
				$identity_file_path = $IDENTITY_solaris_lab;
			}
			elsif ($imagerevision_imagename =~ /^mpls/) {
				notify($ERRORS{'OK'}, 0, "MPLS reservation: $request_id:$reservation_id");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unsupported image type: '$imagerevision_imagename'");
			}
		}
		else{
			notify($ERRORS{'WARNING'}, 0, "computer=$computer_id is of an unknown or unusual type=$computer_type");
		}

		$request_info{reservation}{$reservation_id}{image}{IDENTITY} = $identity_file_path;

		# Set some non-database defaults
		# All data ever added to the hash should be initialized here
		$request_info{reservation}{$reservation_id}{READY}                  = '0';
		$request_info{reservation}{$reservation_id}{image}{SETTESTFLAG}     = '';
		$request_info{reservation}{$reservation_id}{image}{UPDATEIMAGENAME} = '';

		# If machine type is virtual machine - build out a vmclient subhash
		# Allows for ease of use with existing vm subroutines
		if ($request_info{reservation}{$reservation_id}{computer}{type} eq "virtualmachine") {
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"drivetype"}          = $request_info{reservation}{$reservation_id}{computer}{drivetype};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"shortname"}          = $request_info{reservation}{$reservation_id}{computer}{SHORTNAME};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"hostname"}           = $request_info{reservation}{$reservation_id}{computer}{hostname};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"eth0MAC"}            = $request_info{reservation}{$reservation_id}{computer}{eth0macaddress};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"eth1MAC"}            = $request_info{reservation}{$reservation_id}{computer}{eth1macaddress};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"publicIPaddress"}    = $request_info{reservation}{$reservation_id}{computer}{IPaddress};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"privateIPaddress"}   = $request_info{reservation}{$reservation_id}{computer}{privateIPaddress};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"imageminram"}        = $request_info{reservation}{$reservation_id}{image}{minram};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"requestedimagename"} = $request_info{reservation}{$reservation_id}{imagerevision}{imagename};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"imageid"}            = $request_info{reservation}{$reservation_id}{image}{id};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"reloadtime"}         = $request_info{reservation}{$reservation_id}{image}{reloadtime};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"project"}            = $request_info{reservation}{$reservation_id}{image}{project};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"OSname"}             = $request_info{reservation}{$reservation_id}{image}{OS}{name};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"forimaging"}         = $request_info{forimaging};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"persistent"}         = $request_info{forimaging};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"currentimageid"}     = $request_info{reservation}{$reservation_id}{computer}{currentimageid};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"reservationid"}      = $reservation_id;
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"computerid"}         = $request_info{reservation}{$reservation_id}{computer}{id};
			$request_info{reservation}{$reservation_id}{computer}{"vmclient"}{"state"}              = $request_info{state}{name};
		} ## end if ($request_info{reservation}{$reservation_id...
	} ## end foreach my $reservation_id (keys %{$request_info...

	return %request_info;
} ## end sub get_request_info

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
   request.reservationid AS request_reservationid,
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

 Parameters  : Image ID
 Returns     : Hash containing image data
 Description : collects data from database on supplied image_id

=cut


sub get_image_info {
	my ($image_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($image_id))) {
		notify($ERRORS{'WARNING'}, 0, "image ID was not specified");
		return ();
	}

	# If imagemetaid isnt' NULL, perform another query to get the meta info
	my $select_statement = "
   SELECT
   image.*
   FROM
   image
   WHERE
   image.id = '$image_id'
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "image id $image_id does not exist in the database, 0 rows were returned");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# A single row was returned (good)
	# Return the hash
	return %{$selected_rows[0]};
} ## end sub get_image_info

#/////////////////////////////////////////////////////////////////////////////

=head2 get_imagerevision_info

 Parameters  : Imagerevision ID
 Returns     : Hash containing image data
 Description : collects data from database on supplied $imagerevision_id

=cut

sub get_imagerevision_info {
	my ($imagerevision) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($imagerevision))) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision ID was not specified");
		return ();
	}

	my $select_statement = "
   SELECT
   imagerevision.*
   FROM
   imagerevision
   WHERE
   ";

	#Check input value - complete select_statement
	if($imagerevision =~ /^\d/){
		$select_statement .= "imagerevision.id = '$imagerevision'";
	}
	else{
		$select_statement .= "imagerevision.imagename = '$imagerevision'";
	}

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "imagerevision id $imagerevision was not found in the database, 0 rows were returned");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# A single row was returned (good)
	# Return the hash
	return %{$selected_rows[0]};
} ## end sub get_imagerevision_info

#/////////////////////////////////////////////////////////////////////////////

=head2 get_production_imagerevision_info

 Parameters  : $image_id
 Returns     : Hash containing imagerevision data for the production revision of an image
 Description :

=cut


sub get_production_imagerevision_info {
	my ($image_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($image_id))) {
		notify($ERRORS{'WARNING'}, 0, "image ID was not specified");
		return ();
	}

	# If imagemetaid isnt' NULL, perform another query to get the meta info
	my $select_statement = "
	SELECT
	imagerevision.*
	FROM
	imagerevision
	WHERE
	imagerevision.imageid = '$image_id'
	AND imagerevision.production = '1'
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "production imagerevision for image id $image_id was not found in the database, 0 rows were returned");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# A single row was returned (good)
	# Return the hash
	return %{$selected_rows[0]};
} ## end sub get_production_imagerevision_info

#/////////////////////////////////////////////////////////////////////////////

=head2 get_imagemeta_info

 Parameters  : Imagemata ID
 Returns     : Hash containing imagemeta columns
 Description :

=cut


sub get_imagemeta_info {
	my ($imagemeta_id) = @_;

	# Create a hash with the default values in case imagemeta data can't be found
	my %default_usergroupmembers = ();
	my %default_imagemeta = ('id'                   => '',
									 'checkuser'            => '1',
									 'subimages'            => '0',
									 'usergroupid'          => '',
									 'sysprep'              => '1',
									 'postoption'           => '',
									 'rootaccess'           => '1',
									 'USERGROUPMEMBERS'     => \%default_usergroupmembers,
									 'USERGROUPMEMBERCOUNT' => 0);

	# Return defaults if nothing was passed as the imagemeta id
	if (!defined($imagemeta_id) || $imagemeta_id eq '') {
		#notify($ERRORS{'DEBUG'}, 0, "imagemeta data does not exist for image, default values will be used");
		return %default_imagemeta;
	}

	# If imagemetaid isnt' NULL, perform another query to get the meta info
	my $select_statement = "
   SELECT
   imagemeta.*
   FROM
   imagemeta
   WHERE
   imagemeta.id = '$imagemeta_id'
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "imagemeta data does not exist for image, using default values", \%default_imagemeta);
		return %default_imagemeta;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select, using default values", \%default_imagemeta);
		return %default_imagemeta;
	}

	my %imagemeta = %{$selected_rows[0]};

	# Collect additional information
	if (defined($imagemeta{usergroupid})) {
		my @userlist = getusergroupmembers($imagemeta{usergroupid});
		if (scalar @userlist > 0) {
			foreach my $userstring (@userlist) {
				my ($username, $uid) = split(/:/, $userstring);
				$imagemeta{"usergrpmembers"}{$uid}{"username"} = $username;
				$imagemeta{"usergrpmembers"}{$uid}{"uid"}      = $uid;
				$imagemeta{USERGROUPMEMBERS}{$uid}             = $username;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "imagemeta data has usergroupid set $imagemeta{usergroupid} - user group was not found");
		}
	} ## end if (defined($imagemeta{usergroupid}))

	# Set values to 0 if database values are null to avoid DataStructure warnings and concat errors
	$imagemeta{usergroupid}  = 0 if !defined($imagemeta{usergroupid});
	$imagemeta{postoption}   = 0 if !defined($imagemeta{postoption});
	$imagemeta{architecture} = 0 if !defined($imagemeta{architecture});
	$imagemeta{rootaccess} = 1 if !defined($imagemeta{rootaccess});

	# Populate the count of user group members
	$imagemeta{USERGROUPMEMBERCOUNT} = scalar(keys(%{$imagemeta{USERGROUPMEMBERS}}));

	# Return the hash
	return %imagemeta;
} ## end sub get_imagemeta_info

#/////////////////////////////////////////////////////////////////////////////

=head2  get_vmhost_info

 Parameters  : vmhost ID
 Returns     : Hash containing vmhost, vmprofile, and vmtype data
 Description :

=cut


sub get_vmhost_info {
	my ($vmhost_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($vmhost_id))) {
		notify($ERRORS{'WARNING'}, 0, "vmhost ID was not specified");
		return ();
	}

	# If imagemetaid isnt' NULL, perform another query to get the meta info
	my $select_statement = "
   SELECT

   vmhost.id AS vmhost_id,
   vmhost.computerid AS vmhost_computerid,
   vmhost.vmprofileid AS vmhost_vmprofileid,
   vmhost.vmlimit AS vmhost_vmlimit,
   vmhost.vmkernalnic AS vmhost_vmkernalnic,

   vmprofile.id AS vmprofile_id,
   vmprofile.profilename AS vmprofile_profilename,
   vmprofile.vmtypeid AS vmprofile_vmtypeid,
   vmprofile.nasshare AS vmprofile_nasshare,
   vmprofile.datastorepath AS vmprofile_datastorepath,
   vmprofile.vmpath AS vmprofile_vmpath,
   vmprofile.virtualswitch0 AS vmprofile_virtualswitch0,
   vmprofile.virtualswitch1 AS vmprofile_virtualswitch1,
   vmprofile.vmdisk AS vmprofile_vmdisk,
   vmprofile.username AS vmprofile_username,
   vmprofile.password AS vmprofile_password,

   vmtype.id AS vmtype_id,
	vmtype.name AS vmtype_name,

   state.name AS vmhost_state,
	image.name AS vmhost_imagename,
   computer.RAM AS vmhost_RAM,
	computer.hostname AS vmhost_hostname,
	computer.type AS vmhost_type

   FROM
   vmhost,
   vmprofile,
	vmtype,
   computer,
   state,
	image

   WHERE
   vmhost.id = '$vmhost_id'
   AND vmprofile.id = vmhost.vmprofileid
	AND vmtype.id = vmprofile.vmtypeid
   AND computer.id = vmhost.computerid
   AND state.id = computer.stateid
	AND image.id = computer.currentimageid
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
	my %vmhost_row = %{$selected_rows[0]};

	# Create a hash
	my %vmhost_info;

	# Loop through all the columns returned for the reservation
	foreach my $key (keys %vmhost_row) {
		my $value = $vmhost_row{$key};

		# Create another variable by stripping off the column_ part of each key
		# This variable stores the original (correct) column name
		(my $original_key = $key) =~ s/^.+_//;
		#notify($ERRORS{'OK'}, 0, "key=$key original_key=$original_key  value=$value");

		if ($key =~ /vmhost_/) {
			$vmhost_info{$original_key} = $value;
		}
		elsif ($key =~ /vmprofile_/) {
			# Set values to 0 if database values are null to avoid DataStructure warnings and concat errors
			if(!defined($value)){
			   $vmhost_info{"vmprofile"}{$original_key} = 0;
			}
			else{
			   $vmhost_info{"vmprofile"}{$original_key} = $value;
			}
		}
		elsif ($key =~ /vmtype_/) {
			$vmhost_info{"vmprofile"}{"vmtype"}{$original_key} = $value;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
		}
	}    # Close loop through hash keys (columns)

	$vmhost_info{vmprofile}{"datastorepath4vmx"} = $vmhost_info{vmprofile}{datastorepath};
	# FIXME - set vmpath to not null in database and update frontend 
	# IF vmpath is not defined set it to the datastorepath variable
	$vmhost_info{vmprofile}{"vmpath"} = $vmhost_info{vmprofile}{datastorepath} if (!($vmhost_info{vmprofile}{vmpath}));
	$vmhost_info{vmprofile}{datastorepath} =~ s/(\s+)/\\ /g;    #detect/handle any spaces;
	$vmhost_info{vmprofile}{vmpath}        =~ s/(\s+)/\\ /g;    #detect/handle any spaces;


	return %vmhost_info;
} ## end sub get_vmhost_info

#/////////////////////////////////////////////////////////////////////////////

=head2 run_ssh_command

 Parameters  : $node, $identity_path, $command, $user, $port
 Returns     : If ssh command completed successfully, an array containing
               the exit status and a reference to an array containing the
					lines of output of the command specified is returned.
               $array[0] = the exit status of the command
					$array[1] = reference to array containing lines of output
					generated by the command
					If the ssh command fails, an empty array is returned. You can
					therefore use "if (run_ssh_command())", true means the command
					executed, false means it failed.
 Description : Runs an SSH command on the specified node.

=cut

sub run_ssh_command {
	my ($node, $identity_paths, $command, $user, $port, $no_output) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

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
	$user = "root" if (!defined($user) || !$user);
	$port = 22     if (!defined($port) || !$port);

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
	if ($identity_paths) {
		$identity_paths =~ s/^\s*/-i /;
		$identity_paths =~ s/\s*,\s*/ -i /g;
		$identity_paths .= ' ';
	}

	#notify($ERRORS{'DEBUG'}, 0, "node: $node, identity file path: $identity_path, user: $user, port: $port");
	#notify($ERRORS{'DEBUG'}, 0, "command: $command");

	# Assemble the SSH command
	# -i <identity_file>, Selects the file from which the identity (private key) for RSA authentication is read.
	# -l <login_name>, Specifies the user to log in as on the remote machine.
	# -p <port>, Port to connect to on the remote host.
	# -x, Disables X11 forwarding.
	# Dont use: -q, Quiet mode.  Causes all warning and diagnostic messages to be suppressed.
	my $ssh_command = "$ssh_path $identity_paths -l $user -p $port -x $node '$command'";

	# Redirect standard output and error output so all messages are captured
	$ssh_command .= ' 2>&1';

	# Execute the command
	my $ssh_output;
	my $ssh_output_formatted;
	my $attempts        = 0;
	my $max_attempts    = 3;
	my $exit_status = 255;

	# Make multiple attempts if failure occurs
	while ($attempts < $max_attempts) {
		$attempts++;

		## Add -v (verbose) argument to command if this is the 2nd attempt
		#$ssh_command =~ s/$ssh_path/$ssh_path -v/ if $attempts == 2;

		# Print the SSH command, only display the attempt # if > 1
		if ($attempts == 1) {
			notify($ERRORS{'DEBUG'}, 0, "executing SSH command on $node:\n$ssh_command");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: executing SSH command on $node:\n$ssh_command");
		}

		# Execute the command
		$ssh_output = `$ssh_command`;
		
		# Bits 0-7 of $? are set to the signal the child process received that caused it to die
		my $signal_number = $? & 127;
		
		# Bit 8 of $? will be true if a core dump occurred
		my $core_dump = $? & 128;
		
		# Bits 9-16 of $? contain the child process exit status
		$exit_status = $? >> 8;
		
		# Ignore the returned value of $? if it is -1
		# This likely means a Perl bug was encountered
		# Assume command was successful
		if ($? == -1) {
			notify($ERRORS{'DEBUG'}, 0, "exit status changed from $exit_status to 0, Perl bug likely encountered");
			$exit_status = 0;
		}
		
		#notify($ERRORS{'DEBUG'}, 0, "\$?: $?, signal: $signal_number, core dump: $core_dump, exit status: $exit_status");

		# Strip out the key warning message from the output
		$ssh_output =~ s/\@{10,}.*man-in-the-middle attacks\.//igs;
		
		# Strip out known hosts warning message
		#    Warning: Permanently added 'blade1b2-8' (RSA) to the list of known hosts.
		$ssh_output =~ s/Warning: Permanently added .+ to the list of known hosts\.//igs;
		
		# Remove any spaces from the beginning and end of the output
		$ssh_output =~ s/^\s+|\s+$//g;

		# Set the output string to none if no output was produced
		$ssh_output = 'none' if !$ssh_output;

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
		if ($exit_status == 255 || $ssh_output_formatted =~ /lost connection|reset by peer|no route to host|connection refused|connection timed out/i) {
			# Temporary fix for problem of nodes using different ports
			if ($attempts == 3) {
				$max_attempts++;
				notify($ERRORS{'OK'}, 0, "making 1 more attempt using port 24");
				$ssh_command = "$ssh_path $identity_paths -l $user -p 24 -x $node '$command 2>&1' 2>&1";
			}
			
			notify($ERRORS{'WARNING'}, 0, "attempt $attempts/$max_attempts: failed to execute SSH command on $node: $command, exit status: $exit_status, SSH exits with the exit status of the remote command or with 255 if an error occurred, output:\n$ssh_output_formatted");
			next;
		}
		else {
			# SSH command was executed successfully, actual command on node may have succeeded or failed
			
			# Split the output up into an array of lines
			my @output_lines = split(/\n/, $ssh_output);
			
			# Print the output unless no_output is set
			notify($ERRORS{'DEBUG'}, 0, "run_ssh_command output:\n$ssh_output") unless $no_output;
			
			# Print the command and exit status
			(my $ssh_output_summary = $ssh_output) =~ s/\s+/ /gs;
			if (length($ssh_output_summary) > 30) {
				$ssh_output_summary = substr($ssh_output_summary, 0, 30);
				$ssh_output_summary .= "...";
			}
			
			# Display the full ssh command if the exit status is not 0
			if ($exit_status && !$no_output) {
				notify($ERRORS{'OK'}, 0, "SSH command executed on $node, command:\n$ssh_command\nreturning ($exit_status, \"$ssh_output_summary\")");
			}
			elsif (!$no_output) {
				notify($ERRORS{'DEBUG'}, 0, "SSH command executed on $node, returning ($exit_status, \"$ssh_output_summary\")");
			}
			
			# Return the exit status and output
			return ($exit_status, \@output_lines);
		}
	} ## end while ($attempts < $max_attempts)

	# Failure, SSH command did not run at all
	notify($ERRORS{'WARNING'}, 0, "failed to run SSH command after $attempts attempts, command: $ssh_command, exit status: $exit_status, output:\n$ssh_output_formatted");
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
	my $scp_command = "$scp_path -B $identity_paths-P $port -p -r $path1 $path2";

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

		## Add -v (verbose) argument to command if this is the 2nd attempt
		#$scp_command =~ s/$scp_path/$scp_path -v/ if $attempts == 2;

		notify($ERRORS{'DEBUG'}, 0, "attempt $attempts/$max_attempts: executing SCP command: $scp_command");

		$scp_output = `$scp_command`;

		# Save the exit status
		$scp_exit_status = $?;

		# Strip out the key warning message
		$scp_output =~ s/\@{10,}.*man-in-the-middle attacks\.//igs;
		$scp_output =~ s/^\s+|\s+$//g;

		if ($scp_output && length($scp_output) > 0) {
			# Add a newline to the beginning of the output if something was generated
			# This is to make multi-line output more readable
			$scp_output = "\n" . $scp_output;
		}
		else {
			# Indicate there was no output if it is blank
			$scp_output = 'none';
		}

		# Get a slice of the SCP output if there are many lines
		my @scp_output_formatted_lines = split("\n", $scp_output);
		my $scp_output_formatted_line_count = scalar @scp_output_formatted_lines;
		if ($scp_output_formatted_line_count > 50) {
			@scp_output_formatted_lines = @scp_output_formatted_lines[0 .. 49];
			push(@scp_output_formatted_lines, "displayed first 50 of $scp_output_formatted_line_count SCP output lines");
			$scp_output = join("\n", @scp_output_formatted_lines);
		}

		# Check the output for known error messages
		# Check the exit status
		# scp exits with 0 on success or >0 if an error occurred
		if ($scp_exit_status > 0 || $scp_output =~ /lost connection|failed|reset by peer|no route to host|no such file|ambiguous target/i) {
			notify($ERRORS{'WARNING'}, 0, "scp error occurred: attempt $attempts/$max_attempts, command: $scp_command, exit status: $scp_exit_status, output: $scp_output");
			
			# Temporary fix for problem of nodes using different ports
			if ($attempts == 3) {
				$max_attempts++;
				notify($ERRORS{'OK'}, 0, "making 1 more attempt using port 24");
				$scp_command = "$scp_path -B $identity_paths-P 24 -p -r $path1 $path2 2>&1";
			}
			
			next;
		}
		else {
			notify($ERRORS{'OK'}, 0, "scp successful: attempt $attempts/$max_attempts, exit status: $scp_exit_status, output: $scp_output");
			return 1;
		}
	} ## end while ($attempts < $max_attempts)

	# Failure
	notify($ERRORS{'WARNING'}, 0, "failed to copy files using scp after $attempts attempts, command: $scp_command, exit status: $scp_exit_status, output: $scp_output");
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

	my @current_image_lines;
	push @current_image_lines, "$image_name";
	push @current_image_lines, "id=$image_id";
	push @current_image_lines, "prettyname=$image_prettyname";
	push @current_image_lines, "imagerevision_id=$imagerevision_id";
	push @current_image_lines, "imagerevision_datecreated=$imagerevision_date_created";
	push @current_image_lines, "computer_id=$computer_id";
	push @current_image_lines, "computer_hostname=$computer_host_name";

	my $current_image_contents = join('\\r\\n', @current_image_lines);

	my $command = 'echo -e "' . $current_image_contents . '" > currentimage.txt & cat currentimage.txt';

	# Copy the temp file to the node as currentimage.txt
	my ($ssh_exit_status, $ssh_output) = run_ssh_command($computer_node_name, $image_identity, $command);

	if (defined($ssh_exit_status) && $ssh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created currentimage.txt file on $computer_node_name:\n" . join "\n", @{$ssh_output});
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt file on $computer_node_name:\n" . join "\n", @{$ssh_output});
		return;
	}

} ## end sub write_currentimage_txt

#/////////////////////////////////////////////////////////////////////////////

=head2 vmwareclone

 Parameters  : $hostnode, $identity, $srcDisk, $dstDisk, $dstDir
 Returns     : 1 if successful, 0 if error occurred
 Description : using vm tools clone srcdisk to dstdisk
				  	currently using builtin vmkfstools

=cut

=pod

sub vmwareclone {
	my ($hostnode, $identity, $srcDisk, $dstDisk, $dstDir) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	#TODO - add checks for VI toolkit - then use vmclone.pl instead
	#vmclone.pl would need additional parameters

	my @list = run_ssh_command($hostnode, $identity, "ls -1 $srcDisk", "root");
	my $srcDiskexist = 0;

	foreach my $l (@{ $list[1] }) {
		$srcDiskexist = 1 if ($l =~ /($srcDisk)$/);
		$srcDiskexist = 0 if ($l =~ /No such file or directory/);
		notify($ERRORS{'OK'}, 0, "$l");
	}
	my @ssh;
	if ($srcDiskexist) {
		#make dir for dstdisk
		my @mkdir = run_ssh_command($hostnode, $identity, "mkdir -m 755 $dstDir", "root");
		notify($ERRORS{'OK'}, 0, "srcDisk is exists $srcDisk ");
		notify($ERRORS{'OK'}, 0, "starting clone process vmkfstools -d thin -i $srcDisk $dstDisk");
		if (open(SSH, "/usr/bin/ssh -x -q -i $identity -l root $hostnode \"vmkfstools -i $srcDisk -d thin $dstDisk\" 2>&1 |")) {
			#@ssh=<SSH>;
			#close(SSH);
			#foreach my $l (@ssh) {
			#  notify($ERRORS{'OK'},0,"$l");
			#}
			while (<SSH>) {
				notify($ERRORS{'OK'}, 0, "started $_") if ($_ =~ /Destination/);
				notify($ERRORS{'OK'}, 0, "started $_") if ($_ =~ /Cloning disk/);
				notify($ERRORS{'OK'}, 0, "status $_")  if ($_ =~ /Clone:/);
			}
			close(SSH);
		} ## end if (open(SSH, "/usr/bin/ssh -x -q -i $identity -l root $hostnode \"vmkfstools  -i $srcDisk -d thin $dstDisk\" 2>&1 |"...
	} ## end if ($srcDiskexist)
	else {
		notify($ERRORS{'OK'}, 0, "srcDisk $srcDisk does not exists");
	}
	#confirm
	@list = 0;
	@list = run_ssh_command($hostnode, $identity, "ls -1 $dstDisk", "root");
	my $dstDiskexist = 0;
	foreach my $l (@{ $list[1] }) {
		$dstDiskexist = 1 if ($l =~ /($dstDisk)$/);
		$dstDiskexist = 0 if ($l =~ /No such file or directory/);
	}
	if ($dstDiskexist) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "clone process failed dstDisk $dstDisk does not exist");
		return 0;
	}
} ## end sub vmwareclone

=cut

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

=head2 get_management_node_id

 Parameters  : Either a management node hostname or database ID
 Returns     : Hash containing data contained in the managementnode table
 Description :

=cut

sub get_management_node_info {
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
		$select_statement .= "managementnode.hostname like \'$management_node_identifier%\'";
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

	notify($ERRORS{'DEBUG'}, 0, "management node info retrieved from database for $shortname");
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
	my %info;
	if( %info = get_imagerevision_info($imagename)){
		notify($ERRORS{'DEBUG'}, 0, "successfully retreived image info for $imagename");
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to get_imagerevision_info for $imagename");
		return 0;
	}

	my $image_id  = $info{imageid};
	my $imagerevision_id = $info{id};

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

 Parameters  : $computerid, $imageid, $imagerevisionid, $preferredimagid(optional)
 Returns     : 0 failed or 1 success
 Description : Updates currentimage on a node, preferredimageid = optional

=cut

sub update_currentimage {
	my ($computerid, $imageid,  $imagerevisionid, $preferredimagid) = @_;
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
	# If $preferredimageid defined and set build slightly different statement
	my $update_statement = "
	    UPDATE
		computer c, image i
		SET
		c.currentimageid = $imageid,
	    c.imagerevisionid= $imagerevisionid
		WHERE
		c.id = $computerid
	 ";

	if (defined($preferredimagid) && ($preferredimagid)) {
		$update_statement = "
			UPDATE
			computer c, image i
			SET
			c.currentimageid = $imageid,
			c.preferredimageid = $imageid,
			c.imagerevisionid= $imagerevisionid
			WHERE
			c.id = $computerid
			";
	} ## end if (defined($preferredimagid) && ($preferredimagid...

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

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($computer_id))) {
		notify($ERRORS{'WARNING'}, 0, "computer ID was not specified");
		return ();
	}

	# Create the select statement
	my $select_statement = "
	SELECT DISTINCT
	res.id AS reservationid,
	s.name AS currentstate,
	ls.name AS laststate,
	req.id AS requestid,
    req.start AS requeststart
	FROM
	request req,reservation res,state s,state ls
	WHERE
	req.stateid=s.id AND
	req.laststateid = ls.id AND
	req.id=res.requestid AND
	res.computerid = $computer_id

	ORDER BY
	res.id
	 ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select $computer_id");
		return ();
	}

	my %returnhash;

	# It contains a hash
	for (@selected_rows) {
		my %reservation_row = %{$_};
		# Grab the reservation ID to make the code a little cleaner
		my $reservation_id = $reservation_row{reservationid};
		$returnhash{$reservation_id}{"reservationid"} = $reservation_id;
		$returnhash{$reservation_id}{"currentstate"}  = $reservation_row{currentstate};
		$returnhash{$reservation_id}{"laststate"}     = $reservation_row{laststate};
		$returnhash{$reservation_id}{"requestid"}     = $reservation_row{requestid};
		$returnhash{$reservation_id}{"requeststart"}  = $reservation_row{requeststart};
	} ## end for (@selected_rows)

	return %returnhash;
} ## end sub get_request_by_computerid

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

=head2 construct_image_name

 Parameters  : $image_name, $specified_version
 Returns     : String containing a new image name.
					If no number is specified, version is incremented by 1.
					If number is specified, version is set to that number
 Description :

=cut


sub construct_image_name {
	my ($image_name, $specified_version, $os_name) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($image_name))) {
		notify($ERRORS{'WARNING'}, 0, "image name was not specified");
		return 0;
	}

	# If version was specified, check to make sure it's just numerical digits
	if (defined($specified_version) && $specified_version !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "specified version is not in the correct format: $specified_version");
		return 0;
	}

	# Image Name Format: osname-longnameid-v#
	# Example: winxp-Thisistheimagename23-v0

	# Split the image name by dashes
	my @name_sections = split(/-/, $image_name);
	my $section_count = scalar @name_sections;

	# Check to make sure at least 3 sections were found (separated by "-")
	if ($section_count < 3) {
		notify($ERRORS{'WARNING'}, 0, "image name is in the wrong format, cannot construct: $image_name");
		return 0;
	}

	# The OS should be the first section
	my $os_section = $name_sections[0];

	# If an OS name was passed as an argument use it, otherwise use the OS name from the previous image name
	if (defined $os_name && $os_name ne '') {
		$os_section = $os_name;
	}

	# The version should be the last section
	my $version_section = $name_sections[$section_count - 1];

	# Everything in between should be the image name and version
	my $name_section = join('-', @name_sections[1 .. ($section_count - 2)]);

	# Check to make sure the version number is valid
	if ($version_section =~ /^([v|V])([0-9]+)/) {
		my $v              = $1;
		my $version_number = $2;

		# Increment version number or use the specified version if it was passed
		if (defined($specified_version)) {
			$version_number = $specified_version;
		}
		else {
			$version_number++;
		}

		return $os_section . "-" . "$name_section" . "-" . $v . $version_number;
	} ## end if ($version_section =~ /^([v|V])([0-9]+)/)

	else {
		notify($ERRORS{'WARNING'}, 0, "could not detect version number from image name: $image_name");
		return 0;
	}

} ## end sub construct_image_name

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
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update database, log id $log_id");
		return 0;
	}
} ## end sub update_log_ending

#/////////////////////////////////////////////////////////////////////////////

=head2 update_reservation_lastcheck

 Parameters  : Updates the finalend and ending fields in the log table for the specified log ID
 Returns     : date string if successful, 0 if failed
 Description :

=cut

sub update_reservation_lastcheck {
	my ($reservation_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($reservation_id))) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified");
		return ();
	}

	my $datestring = makedatestring();

	# Construct the update statement
	my $update_statement = "
      UPDATE
		reservation
		SET
		lastcheck = \'$datestring\'
		WHERE
		id = $reservation_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return $datestring;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update database, reservation id $reservation_id");
		return 0;
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
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update database, request log ID $request_logid");
		return 0;
	}
} ## end sub update_log_loaded_time

#/////////////////////////////////////////////////////////////////////////////

=head2 update_image_name

 Parameters  : $image_id,$imagerevision_revision_id,$new_image_name
 Returns     : 0 or 1
 Description : Updates the name in the image and imagerevision table

=cut

sub update_image_name {
	my ($image_id, $imagerevision_revision_id, $new_image_name) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($image_id))) {
		notify($ERRORS{'WARNING'}, 0, "image ID was not specified");
		return ();
	}

	# Construct the update statement
	my $update_statement = "
	UPDATE
	image,
	imagerevision
	SET
	name = \'$new_image_name\',
	imagename = \'$new_image_name\'
	WHERE
	image.id = $image_id AND
	imagerevision.id = $imagerevision_revision_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update database, imageID = $image_id imagerevisionID = $imagerevision_revision_id");
		return 0;
	}
} ## end sub update_image_name

#/////////////////////////////////////////////////////////////////////////////

=head2 windowsroutetable

 Parameters  : $node, $identity, $privateIP, $clearallPersistent
 Returns     : 0 or 1
 Description : scan route table and remove inactive persistent routes
					if clearallPersistent 1 remove all persistent routes

=cut

sub windowsroutetable {
	my ($node, $identity, $privateIP, $clearallPersistent) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	$clearallPersistent = 0 if (!defined($clearallPersistent));
	my ($myadapter, $publicgateway);
	my %ip;
	my $id = 0;
	my ($privateadapter, $publicadapter);
	my @ssh = run_ssh_command($node, $identity, "ipconfig", "root");
	foreach my $a (@{$ssh[1]}) {
		if ($a =~ /Ethernet adapter (.*):/) {
			$myadapter                 = $1;
			$ip{$myadapter}{"id"}      = $id;
			$ip{$myadapter}{"private"} = 0;
		}
		if ($a =~ /IP Address([\s.]*): $privateIP/) {
			$ip{$myadapter}{"private"} = 1;
			print "privateadapter $a\n";
		}
		if ($a =~ /Default Gateway([\s.]*): ([.0-9]*)/) {
			$ip{$myadapter}{"gateway"} = $2;
		}
		$id++;
	} ## end foreach my $a (@{$ssh[1]})
	    #get public gateway
	foreach my $key (keys %ip) {
		if (!($ip{$key}{private})) {
			if (defined($ip{$key}{gateway})) {
				$publicgateway = $ip{$key}{gateway};
				notify($ERRORS{'OK'}, 0, "setting publicgateway= $publicgateway");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "warning no gateway for $key");
				return 0;
			}
		} ## end if (!($ip{$key}{private}))
	} ## end foreach my $key (keys %ip)
	my @proutes;
	my @rte = run_ssh_command($node, $identity, "route print", "root");
	my $inproute = 0;
	foreach my $r (@{$rte[1]}) {
		$inproute = 1 if ($r =~ /Persistent Routes:/);
		if ($inproute) {
			if ($r =~ /\s+(0.0.0.0)\s+(0.0.0.0)\s+([0-9\..]*)\s+([0-9]+)/) {
				if (($3 != $publicgateway) || ($clearallPersistent)) {
					my $cmd = "route -p DELETE $1 MASK $2 $3 METRIC $4";
					my @rtedel = run_ssh_command($node, $identity, "$cmd", "root");
					notify($ERRORS{'OK'}, 0, "found inactive persistent route deleting $3");
					foreach my $line (@{$rtedel[1]}) {
						if ($line =~ /A matching persistent route was deleted/) {
							notify($ERRORS{'OK'}, 0, "$3 was successfully deleted");
							return 1;
						}
						if ($line =~ /The route specified was not found/) {
							notify($ERRORS{'OK'}, 0, "no route was found $cmd");
							return 0;
						}
					} ## end foreach my $line (@{$rtedel[1]})
				} ## end if (($3 != $publicgateway) || ($clearallPersistent...
			} ## end if ($r =~ /\s+(0.0.0.0)\s+(0.0.0.0)\s+([0-9\..]*)\s+([0-9]+)/)
		} ## end if ($inproute)
	} ## end foreach my $r (@{$rte[1]})
	notify($ERRORS{'OK'}, 0, "no inactive persistent routes found");
	return 1;
} ## end sub windowsroutetable

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_computerloadlog_reservation

 Parameters  : $reservation_id, optional loadstatename
 Returns     : 0 failed or 1 success
 Description : Deletes rows from the computerloadlog table. A loadstatename
               argument can be specified to limit the rows removed to a
               certain loadstatename. To delete all rows except those
               matching a certain loadstatename, begin the loadstatename
               with a !.

=cut


sub delete_computerloadlog_reservation {
	my ($reservation_id, $loadstatename) = @_;

	# Check the passed parameter
	if (!(defined($reservation_id))) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified");
		return ();
	}
	
	# Construct the SQL statement
	my $sql_statement;
	# Check if loadstateid was specified
	# If so, only delete rows matching the loadstateid
	if ($loadstatename && $loadstatename !~ /^!/) {
		notify($ERRORS{'DEBUG'}, 0, "removing computerloadlog entries matching loadstate = $loadstatename");
		
		$sql_statement = "
		DELETE
		computerloadlog
		FROM
		computerloadlog,
		computerloadstate
		WHERE
		computerloadlog.reservationid = $reservation_id
		AND computerloadlog.loadstateid = computerloadstate.id
		AND computerloadstate.loadstatename = \'$loadstatename\'
		";
	}
	elsif ($loadstatename) {
		# Remove the first character of loadstatename, it is !
		$loadstatename = substr($loadstatename, 1);
		notify($ERRORS{'DEBUG'}, 0, "removing computerloadlog entries NOT matching loadstate = $loadstatename");
		
		$sql_statement = "
		DELETE
		computerloadlog
		FROM
		computerloadlog,
		computerloadstate
		WHERE
		computerloadlog.reservationid = $reservation_id
		AND computerloadlog.loadstateid = computerloadstate.id
		AND computerloadstate.loadstatename != \'$loadstatename\'
		";
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "removing all computerloadlog entries for reservation");
		
		$loadstatename = 'all';
		$sql_statement = "
		DELETE
		computerloadlog
		FROM
		computerloadlog
		WHERE
		computerloadlog.reservationid = $reservation_id
		";
	}

	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "deleted rows from computerloadlog for reservation id=$reservation_id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete from computerloadlog table for reservation id=$reservation_id");
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

	# Append the class name or file name to the process name
	if (defined($ENV{class_name})) {
		$new_process_name .= (" " . $ENV{class_name});
	}
	elsif ($filename) {
		$new_process_name .= " $filename";
	}

	# Check if DataStructure, assemble process name with additional information
	if (defined $data_structure) {
		my $state_name = $data_structure->get_state_name();

		if ($state_name ne 'blockrequest') {
			my $request_id            = $data_structure->get_request_id();
			my $request_state_name    = $data_structure->get_request_state_name();
			my $reservation_id        = $data_structure->get_reservation_id();
			my $request_forimaging    = $data_structure->get_request_forimaging();
			my $reservation_count     = $data_structure->get_reservation_count();
			my $reservation_is_parent = $data_structure->is_parent_reservation();

			# Append the request and reservation IDs if they are set
			$new_process_name .= " $request_id:$reservation_id";
			$new_process_name .= " $request_state_name" if $request_state_name;
			$new_process_name .= " imaging" if $request_forimaging;

			# Append cluster if there are multiple reservations for this request
			notify($ERRORS{'DEBUG'}, 0, "reservation count: $reservation_count");

			if ($reservation_count > 1) {
				if ($reservation_is_parent) {
					$data_structure->get_request_data->{PARENTIMAGE} = 1;
					$data_structure->get_request_data->{SUBIMAGE}    = 0;
					$new_process_name .= " cluster=parent";
				}
				else {
					$data_structure->get_request_data->{PARENTIMAGE} = 0;
					$data_structure->get_request_data->{SUBIMAGE}    = 1;
					$new_process_name .= " cluster=child";
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
	print STDOUT "log file path changed to \'$LOGFILE\'\n";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_highest_imagerevision_info

 Parameters  : $image_id
 Returns     : Hash containing image revision data
 Description :

=cut


sub get_highest_imagerevision_info {
	my ($image_id) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the passed parameter
	if (!(defined($image_id))) {
		notify($ERRORS{'WARNING'}, 0, "image ID was not specified");
		return ();
	}

	# Select the highest image revision id for the specified image id
	my $select_statement = "
   SELECT
   MAX(imagerevision.id) AS id
   FROM
   imagerevision
   WHERE
   imagerevision.imageid = '$image_id'
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "image revision data for image id $image_id was not found in the database, 0 rows were returned");
		return -1;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# A single row was returned (good)
	my $imagerevision_id = $selected_rows[0]{id};

	return get_imagerevision_info($imagerevision_id);

} ## end sub get_highest_imagerevision_info

#/////////////////////////////////////////////////////////////////////////////

=head2 switch_state

 Parameters  : $request_data, $request_state_name_new, $computer_state_name_new, $request_log_ending, $exit
 Returns     : 0 if something goes wrong, exits if successful
 Description : Changes the state of this request to the state specified
               terminates. The vcld process will then pick up the switched
               request. It is important that this process sets the request
               laststate to the original state and that vcld does not alter it.

=cut

#/////////////////////////////////////////////////////////////////////////////

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

	# Update the notify prefix now that we have request info
	my $notify_prefix = "req=$request_id:";

	# Check if new request state was passed
	if (!$request_state_name_new) {
		notify($ERRORS{'DEBUG'}, 0, "$notify_prefix request state was not specified, state not changed");
	}
	elsif (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "$notify_prefix child reservation, request state not changed");
	}
	else {
		# Add an entry to the loadlog
		insertloadlog($reservation_id, $computer_id, "info", "$caller: switching request state to $request_state_name_new");

		# Update the request state to $request_state_name_new and set laststate to current state
		if (update_request_state($request_id, $request_state_name_new, $request_state_name_old)) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix request state changed: $request_state_name_old->$request_state_name_new, laststate: $request_laststate_name_old->$request_state_name_old");
			insertloadlog($reservation_id, $computer_id, "info", "$caller: request state changed to $request_state_name_new, laststate to $request_state_name_old");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$notify_prefix request state could not be changed: $request_state_name_old --> $request_state_name_new, laststate: $request_laststate_name_old->$request_state_name_old");
			insertloadlog($reservation_id, $computer_id, "info", "$caller: unable to change request state to $request_state_name_new, laststate to $request_state_name_old");
		}
	} ## end else [ if (!$request_state_name_new)  [elsif (!$is_parent_reservation)

	# Update the computer state
	if (!$computer_state_name_new) {
		notify($ERRORS{'DEBUG'}, 0, "$notify_prefix computer state not specified, $computer_shortname state not changed");
	}
	else {
		# Add an entry to the loadlog
		insertloadlog($reservation_id, $computer_id, "info", "$caller: switching computer state to $computer_state_name_new");

		# Update the computer state
		if (update_computer_state($computer_id, $computer_state_name_new)) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix computer $computer_shortname state changed: $computer_state_name_old->$computer_state_name_new");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix unable to computer $computer_shortname state: $computer_state_name_old->$computer_state_name_new");
		}
	} ## end else [ if (!$computer_state_name_new)

	# Update log table for this request
	# Ending can be deleted, released, failed, noack, nologin, timeout, EOR, none
	if (!$request_log_ending) {
		notify($ERRORS{'DEBUG'}, 0, "$notify_prefix log table id=$request_logid will not be updated");
	}
	elsif (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "$notify_prefix child reservation, log table id=$request_logid will not be updated");
	}
	elsif (update_log_ending($request_logid, $request_log_ending)) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix log table id=$request_logid, ending set to $request_log_ending");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix unable to set log table id=$request_logid, ending to $request_log_ending");
	}

	# Call exit if the state changed, return otherwise
	if ($exit) {
		insertloadlog($reservation_id, $computer_id, "info", "$caller: process exiting");
		notify($ERRORS{'OK'}, 0, "$notify_prefix process exiting");
		exit;
	}
	else {
		notify($ERRORS{'OK'}, 0, "$notify_prefix returning");
		return;
	}

} ## end sub switch_state

#/////////////////////////////////////////////////////////////////////////////

=head2 get_ip_address_from_hosts

 Parameters  : $host_name
 Returns     : IP address of specified node if successful, 0 if failed
 Description : Searches the local hosts file for a line containing the host
               name specified. Returns the corresponding IP address.

=cut

sub get_ip_address_from_hosts {
	my ($host_name) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the argument
	if (!defined($host_name) || !$host_name) {
		notify($ERRORS{'WARNING'}, 0, "computer host name was not specified");
		return 0;
	}

	# Check the OS of the machine running this, set the hosts file accordingly
	my $hosts_file_path;
	if (lc($^O) =~ /win/i) {
		$hosts_file_path = $ENV{SystemRoot} . '\\system32\\drivers\\etc\\hosts';
	}
	else {
		$hosts_file_path = '/etc/hosts';
	}

	# Retrieve the node's private IP address from the hosts file
	# Try to open the hosts file
	if (open(HOSTS, $hosts_file_path)) {
		notify($ERRORS{'OK'}, 0, "opened hosts file: $hosts_file_path") if $VERBOSE;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to open the hosts file: $hosts_file_path");
		return 0;
	}

	# Find all lines in the hosts file containing the host name
	# Make sure the host name has a space in front of it so that host1 != xhost1
	# If host name being searched for is followed by a space or period, ignore rest of line
	#   This accounts for full DNS host names, host1.unity...
	# If host name isn't followed by space or period, make sure the end of sting is immediately following
	#   This accounts for host1 != host1x
	# This also accounts for the end of file immediately following the host name
	my @hosts_matching_lines = grep(/\s$host_name([\s\.].*)*$/i, <HOSTS>);

	# Close the HOSTS file
	close HOSTS;

	# Make sure only 1 line was returned
	if (scalar @hosts_matching_lines == 0) {
		notify($ERRORS{'WARNING'}, 0, "unable to find line containing $host_name in hosts file");
		return 0;
	}
	elsif (scalar @hosts_matching_lines > 1) {
		notify($ERRORS{'OK'}, 0, "found " . scalar @hosts_matching_lines . " lines containing $host_name in hosts file, first valid match will be used");
	}

	# Find the IP address
	my $ip_address;
	for (@hosts_matching_lines) {
		my $line = $_;
		chomp $line;

		# Check for IPv4 address pattern
		if ($line =~ /^\s*(([0-9]{1,3}\.{0,1}){4})\s/) {
			$ip_address = $1;
			notify($ERRORS{'OK'}, 0, "found IPv4 address: $ip_address") if $VERBOSE;
		}
		# Check for IPv6 address pattern
		elsif ($line =~ /^\s*(([0-9a-f]{0,4}:{0,2}){1,8})\s/i) {
			$ip_address = $1;
			notify($ERRORS{'OK'}, 0, "found IPv6 address: $ip_address") if $VERBOSE;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "hosts file line does not contain a valid IP address: $line");
			next;
		}

		# Check if the line is a comment
		if ($line =~ /^\s*#/) {
			notify($ERRORS{'OK'}, 0, "host name found in commented line: $line");
			# Proceed to try other matches, hoping for a non-commented match
			next;
		}
		else {
			# Line is not commented, return the IP address
			return $ip_address;
		}
	} ## end for (@hosts_matching_lines)

	# Check if an IP address was found
	if ($ip_address) {
		# This should only happen if the host name was found in a commented line
		return $ip_address;
	}
	else {
		# Address was not found
		notify($ERRORS{'WARNING'}, 0, "unable to find any valid matching address in hosts file");
		return 0;
	}
} ## end sub get_ip_address_from_hosts

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_compare_update

 Parameters  : $node,$reote_IP, $identity, $type
 Returns     : 0 or 1 (nochange or updated)
 Description : compares and updates the firewall for rdp port, specfically for windows
					Currently only handles windows and allows two seperate scopes

=cut

sub firewall_compare_update {
	my ($node, $remote_IP, $identity, $type) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($node)) {
		notify($ERRORS{'WARNING'}, 0, "node was not specified");
		return 0;
	}
	if (!defined($remote_IP)) {
		notify($ERRORS{'WARNING'}, 0, "remote_IP was not specified");
		return 0;
	}
	if (!defined($identity)) {
		notify($ERRORS{'WARNING'}, 0, "$identity was not specified");
		return 0;
	}
	if (!defined($type)) {
		notify($ERRORS{'WARNING'}, 0, "$type was not specified");
		return 0;
	}

	# Collect settings on node
	if ($type =~ /windows/) {
		my $cmd          = "netsh firewall show portopening enable";
		my @sshcmd       = run_ssh_command($node, $identity, $cmd, "root");
		my $update_scope = 0;
		my $scopelook    = 0;

		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /^3389\s*TCP/) {
				$scopelook = 1;
				#print "$l\n";
				next;
			}
			if ($scopelook) {
				$scopelook = 0;
				if ($l =~ /(\s*Scope:\s*)([.0-9]*)(\/)([.0-9]*)/) {
					# addresses into their quads
					# current scope
					my ($a1q1, $a1q2, $a1q3, $a1q4) = split(/[.]/, $2);
					my ($a2q1, $a2q2, $a2q3, $a2q4) = split(/[.]/, $remote_IP);
					#start comparing
					if ($a1q1 ne $a2q1) {
						$update_scope = 1;
						notify($ERRORS{'DEBUG'}, 0, "update_scope required addressquad1= $a1q1 addressquad2= $a2q1");
					}
					if ($a1q2 ne $a2q2) {
						$update_scope = 1;
						notify($ERRORS{'DEBUG'}, 0, "update_scope required address1uad2= $a1q2 address2quad2= $a2q2");
					}
					if ($update_scope) {
						my $scopeaddress = "$a1q1.$a1q2.0.0/255.255.0.0,$a2q1.$a2q2.0.0/255.255.0.0";
						my $netshcmd     = "netsh firewall set portopening TCP 3389 RDP enable CUSTOM $scopeaddress";
						my @sshcmd1      = run_ssh_command($node, $identity, $netshcmd, "root");
						foreach my $line (@{$sshcmd1[1]}) {
							if ($line =~ /Ok./) {
								notify($ERRORS{'OK'}, 0, "firewall_compare_update: firewall updated with $scopeaddress");
								return 1;
							}
							else {
								notify($ERRORS{'DEBUG'}, 0, "firewall_compare_update netsh output $line ");
							}
						}
					} ## end if ($update_scope)
					else {
						notify($ERRORS{'DEBUG'}, 0, "firewall_compare_update scope of ipaddess matches no change needed");
					}
				} ## end if ($l =~ /(\s*Scope:\s*)([.0-9]*)(\/)([.0-9]*)/)
			} ## end if ($scopelook)
		} ## end foreach my $l (@{$sshcmd[1]})
	} ## end if ($type =~ /windows/)
	else {
		#other types go here
		return 0;
	}

} ## end sub firewall_compare_update

#/////////////////////////////////////////////////////////////////////////////

=head2 update_log_ending

 Parameters  : $blockrequest_id, $processing
 Returns     : 0 or 1
 Description : Updates the finalend and ending fields in the log table for the specified log ID

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
	blockRequest.managementnodeid = $managementnode_id
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows == 0) {
		return 0;
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

=head2 get_computers_controlled_by_MN

 Parameters  : $managementnode_id
 Returns     : hash containing computer info
 Description :

=cut

sub get_computers_controlled_by_MN {
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
					notify($ERRORS{'DEBUG'}, $LOGFILE, "no computers in computer groupname= $info{managementnode}{resoucegroups}{$grp_id}{$id}{groupname}");
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
	resource
   WHERE 
	resourcegroupmembers.resourceid = resource.id 
	AND resourcetype.id = resource.resourcetypeid 
	AND resourcetype.name = 'computer' 
	AND resourcegroupmembers.resourcegroupid = $computer_grp_id
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

=head2 get_computer_info

 Parameters  : $computer_id
 Returns     : hash containing information on computer id
 Description :

=cut

sub get_computer_info {
	my ($computer_id) = @_;

	if(!defined($computer_id)){
		notify($ERRORS{'WARNING'}, $LOGFILE, "computer_id was not supplied");
		return 0;
	}

	my $select_statement = "
	SELECT DISTINCT
   computer.id AS computer_id,
   computer.ownerid AS computer_ownerid,
   computer.platformid AS computer_platformid,
   computer.currentimageid AS computer_currentimageid,
   computer.imagerevisionid AS computer_imagerevisionid,
   computer.RAM AS computer_RAM,
   computer.procnumber AS computer_procnumber,
   computer.procspeed AS computer_procspeed,
   computer.hostname AS computer_hostname,
   computer.IPaddress AS computer_IPaddress,
   computer.privateIPaddress AS computer_privateIPaddress,
   computer.eth0macaddress AS computer_eth0macaddress,
   computer.eth1macaddress AS computer_eth1macaddress,
	computer.type AS computer_type,
	computer.provisioningid AS computer_provisioningid,
	computer.drivetype AS computer_drivetype,
	computer.deleted AS computer_deleted,
	computer.notes AS computer_notes,
	computer.lastcheck AS computer_lastcheck,
	computer.location AS computer_location,
	computer.vmhostid AS computer_vmhostid,
	computerplatform.name AS computerplatform_name,
	computerstate.name AS computerstate_name,

	computerprovisioning.name AS computerprovisioning_name,
	computerprovisioning.prettyname AS computerprovisioning_prettyname,
	computerprovisioning.moduleid AS computerprovisioning_moduleid,
	
	computerprovisioningmodule.name AS computerprovisioningmodule_name,
	computerprovisioningmodule.prettyname AS computerprovisioningmodule_prettyname,
	computerprovisioningmodule.perlpackage AS computerprovisioningmodule_perlpackage,
	
	imagerevision.id AS imagerevision_id,
	imagerevision.revision AS imagerevision_revision,
	imagerevision.imagename AS imagerevision_imagename,

	image.id AS image_id,
	image.name AS image_name,
	image.prettyname AS image_prettyname,
	image.platformid AS image_platformid,
	image.OSid AS image_OSid,
	image.imagemetaid AS image_imagemetaid,
	image.architecture AS image_architecture,

	imageplatform.name AS imageplatform_name,

	OS.name AS OS_name,
   OS.prettyname AS OS_prettyname,
   OS.type AS OS_type,
   OS.installtype AS OS_installtype,
   OS.sourcepath AS OS_sourcepath,
	imageOSmodule.name AS imageOSmodule_name,
	imageOSmodule.perlpackage AS imageOSmodule_perlpackage

	FROM
	computer,
	platform computerplatform,
	platform imageplatform,
	state computerstate,
	provisioning computerprovisioning,
	module computerprovisioningmodule,
	image,
	OS,
	imagerevision,
	module imageOSmodule
   
	WHERE
	computerplatform.id = computer.platformid
	AND computerstate.id = computer.stateid
	AND computerprovisioning.id = computer.provisioningid
	AND computerprovisioningmodule.id = computerprovisioning.moduleid 
	AND imagerevision.id = computer.imagerevisionid
	AND image.id = imagerevision.imageid
	AND OS.id = image.OSid
	AND imageplatform.id = image.platformid
	AND imageOSmodule.id = OS.moduleid
	AND computer.deleted != '1'
	AND computer.id =  $computer_id;
	";


	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure only 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'DEBUG'}, 0, "zero rows were returned from database select for computer id $computer_id");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# Build the hash
   my %comp_info;

   for (@selected_rows) {
        my %computer_row = %{$_};
		  # Check if the computer associated with this reservation has a vmhostid set
        if ($computer_row{computer_vmhostid}) {
            my %vmhost_info = get_vmhost_info($computer_row{computer_vmhostid});
            # Make sure vmhost was located if vmhostid was specified for the image
            if (!%vmhost_info) {
               notify($ERRORS{'WARNING'}, 0, "vmhostid=" . $computer_row{computer_vmhostid} . " was specified for computer id=" . $computer_row{computer_id} . " but vmhost could not be found");
            }
            else {
               # Image meta data found, add it to the hash
               $comp_info{vmhost} = \%vmhost_info;
            }
        } ## end if ($reservation_row{computer_vmhostid})


		  # Loop through all the columns returned for the reservation
		  foreach my $key (keys %computer_row) {
           my $value = $computer_row{$key};
			  # Create another variable by stripping off the column_ part of each key
           # This variable stores the original (correct) column name
           (my $original_key = $key) =~ s/^.+_//;

			  if ($key =~ /computer_/) {
               $comp_info{computer}{$original_key} = $value;
           }
			  elsif ($key =~ /computerplatform_/) {
				  $comp_info{computer}{platform}{$original_key} = $value;
			  }
			  elsif ($key =~ /computerstate_/) {
				  $comp_info{computer}{state}{$original_key} = $value;
			  }
			  elsif ($key =~ /computerprovisioning_/) {
				  $comp_info{computer}{provisioning}{$original_key} = $value;
			  }
			  elsif ($key =~ /computerprovisioningmodule_/) {
				  $comp_info{computer}{provisioning}{module}{$original_key} = $value;
			  }
			  elsif ($key =~ /image_/) {
				  $comp_info{image}{$original_key} = $value;
			  }
			  elsif ($key =~ /imageplatform_/) {
				  $comp_info{platform}{$original_key} = $value;
			  }
			  elsif ($key =~ /imagerevision_/) {
				  $comp_info{imagerevision}{$original_key} = $value;
			  }
			  elsif ($key =~ /OS_/) {
				  $comp_info{image}{OS}{$original_key} = $value;
			  }
			  elsif ($key =~ /imageOSmodule_/) {
				  $comp_info{image}{OS}{module}{$original_key} = $value;
			  }
			  elsif ($key =~ /user_/) {
				  $comp_info{user}{$original_key} = $value;
			  }
			  else {
				  notify($ERRORS{'WARNING'}, 0, "unknown key found in SQL data: $key");
			  }

		  }	

	}

	return \%comp_info;

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
		notify($ERRORS{'OK'}, 0, "inserted new reload request into request table, request id=$request_id");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert new reload request into request table");
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
		notify($ERRORS{'OK'}, 0, "inserted new reload request into reservation table, reservation id=$reservation_id");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert new reload request into reservation table");
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
	my $image_id               = $request_data->{reservation}{$reservation_id}{imageid};
	my $imagerevision_id       = $request_data->{reservation}{$reservation_id}{imagerevisionid};

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

	my $cluster_info   = "/tmp/$computer_short_name.cluster_info";
	my @cluster_string = "";
	foreach my $rid (keys %{$request_data->{reservation}}) {
		if ($rid == $reservation_id) {
			push(@cluster_string, "parent= $request_data->{reservation}{$rid}{computer}{IPaddress}" . "\n");
		}
		else {
			push(@cluster_string, "child= $request_data->{reservation}{$rid}{computer}{IPaddress}" . "\n");
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

 Parameters  :
 Returns     : 0 or 1
 Description :

=cut

sub format_data {
	
	my $return_string;

	my $level = 0;
	$level = $_[scalar(@_) - 2] if (scalar(@_) > 2 && !ref($_[scalar(@_) - 2]));

	my $name = '';
	$name = $_[scalar(@_) - 1] if (scalar(@_) > 1 && !ref($_[scalar(@_) - 1]));

	my $type;
	my $data;

	if (ref($_[0]) eq "HASH") {
		$data = $_[0];
		$type = '%';
		return "%<empty>" if (keys(%{$_[0]}) == 0);
	}
	elsif (ref($_[0]) eq "ARRAY") {
		my $index = 0;
		for (@{$_[0]}) {
			$data->{$index} = $_;
			$index++;
		}
		$type = '@';
		return "@<empty>" if (@{$_[0]} == 0);
	}
	elsif (ref($_[0]) eq "SCALAR") {
		$data = $_[0];
		$type = '$';
	}
	else {
		$data = \$_[0];
		$type = '$';

		$return_string .= "ref: " . ref($_[0]) . "\n";
		$return_string .= "data: " . $_[0] . "\n";

		return $return_string;
	}

	$data = 'NULL' if (!defined $data);

	$return_string .= "$type$name\n";

	# Loop through values
	foreach my $key (sort {lc($a) cmp lc($b)} keys(%{$data})) {
		my $value = $data->{$key};

		$value = 'NULL' if (!defined $value);

		for (my $count = 0; $count < $level; $count++) {
			$return_string .= "   " if ($count < $level);
		}
		$return_string .= "|--";

		if (ref($value) eq 'SCALAR') {
			$value = "\\'$$value'";
		}
		elsif (!ref($value) && $value ne 'NULL') {
			$value = "'$value'";
		}

		if (!ref($value)) {
			if ($type eq '@') {
				$return_string .= "[$key] = $value\n";
			}
			elsif ($type eq '%') {
				$return_string .= "{$key} = $value\n";
			}
		}
		else {
			if ($type eq '@') {
				#$return_string .= "\[$key\]\n";
				$return_string .= format_data($value, $level + 1, "$name\[$key\]");
			}
			elsif ($type eq '%') {
				#$return_string .= "\{$key\} $name\n";
				$return_string .= format_data($value, $level + 1, "$name\{$key\}");
			}
		} ## end else [ if (!ref($value))

	} ## end foreach my $key (sort {lc($a) cmp lc($b)} keys(...

	return $return_string;
} ## end sub format_data

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

	my $caller_trace = "";
	for (1 .. $level_limit) {
		my $caller_index = $_;
		if (caller($caller_index)) {
			my ($package_last, $filename_last, $line_last, $sub_last) = caller($caller_index - 1);
			my ($package,      $filename,      $line,      $sub)      = caller($caller_index);

			$filename_last =~ s/.*\///;
			$sub           =~ s/.*:://;
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
	my %return_hash;
	map({push @{$return_hash{$_->{TABLE_NAME}}}, $_->{COLUMN_NAME}} @rows);
	return \%return_hash;
} ## end sub get_database_table_columns

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

=head2 reservations_ready

 Parameters  :  request ID
 Returns     :  1 if all reservations are ready, 0 if any are not ready, undefined if any failed
 Description :  

=cut

sub reservations_ready {
	my ($request_id) = @_;

	# Make sure request ID was passed
	if (!$request_id) {
		notify($ERRORS{'WARNING'}, 0, "request ID argument was not passed");
		return;
	}

	my $select_statement = "
	SELECT
	reservation.id AS reservation_id,
	computerloadstate.loadstatename
	
	FROM
	request,
	reservation
	
	LEFT JOIN
	computerloadlog
	ON (
	computerloadlog.reservationid = reservation.id
	)
	
	LEFT JOIN
	computerloadstate
	ON (
	computerloadstate.id = computerloadlog.loadstateid
	)
	
	WHERE
	request.id = $request_id
	AND reservation.requestid = request.id
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @computerloadlog_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @computerloadlog_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "reservations associated with request $request_id could not be retrieved from the database, 0 rows were returned");
		return;
	}

	my %reservation_status;

	# Loop through the rows, check the loadstate
	for my $computerloadlog_row (@computerloadlog_rows) {
		my $reservation_id         = $computerloadlog_row->{reservation_id};
		my $computerloadstate_name = $computerloadlog_row->{loadstatename};

		# Initialize the hash key for the reservation if it isn't defined
		if (!defined($reservation_status{$reservation_id})) {
			$reservation_status{$reservation_id} = 'not ready';
		}

		# Skip if loadstatename is undefined, means no computerloadlog rows exist for the reservation
		if (!defined($computerloadstate_name)) {
			next;
		}

		# Only populate hash keys with loadstatnames we care about
		# Ignore 'info' and other entries
		if ($computerloadstate_name =~ /loadimagecomplete|nodeready|failed/i) {

			# Update the reservation hash key, don't overwrite 'failed'
			if ($reservation_status{$reservation_id} !~ /failed/) {
				$reservation_status{$reservation_id} = $computerloadstate_name;
			}
		}
	} ## end for my $computerloadlog_row (@computerloadlog_rows)

	# Assemble a string of all of the statuses
	my $status_string = '';
	my $failed        = 0;
	my $ready         = 1;
	foreach my $reservation_check_id (sort keys(%reservation_status)) {
		my $reservation_check_status = $reservation_status{$reservation_check_id};
		$status_string .= "reservation $request_id:$reservation_check_id: $reservation_check_status\n";

		# Set the failed flag to 1 if any reservations failed
		if ($reservation_check_status =~ /failed/i) {
			$failed = 1;
		}

		# Set the ready flag to 0 if any reservations are set to 0 (matching state wasn't found)
		if ($reservation_check_status =~ /not ready/) {
			$ready = 0;
		}
	} ## end foreach my $reservation_check_id (sort keys(%reservation_status...

	if ($failed) {
		notify($ERRORS{'WARNING'}, 0, "request $request_id has failed reservations, returning undefined:\n$status_string");
		return;
	}

	if ($ready) {
		notify($ERRORS{'OK'}, 0, "all reservations for request $request_id are ready, returning $ready:\n$status_string");
	}
	else {
		notify($ERRORS{'OK'}, 0, "not all reservations for request $request_id are ready, returning $ready:\n$status_string");
	}

	return $ready;

} ## end sub reservations_ready

##/////////////////////////////////////////////////////////////////////////////
#
#=head2 reservations_ready
#
# Parameters  :  request ID
# Returns     :  1 if all reservations are ready, 0 if any are not ready, undefined if any failed
# Description :  
#
#=cut
#
#sub reservations_ready {
#	my ($request_id) = @_;
#
#	# Make sure request ID was passed
#	if (!$request_id) {
#		notify($ERRORS{'WARNING'}, 0, "request ID argument was not passed");
#		return;
#	}
#
#	my $select_statement = "
#	SELECT
#	requeststate.name AS request_state,
#	reservation.id AS reservation_id,
#	computerloadstate.loadstatename,
#	computerstate.name AS computer_state
#	
#	FROM
#	request,
#	state requeststate,
#	reservation
#	
#	LEFT JOIN
#	computerloadlog
#	ON (
#	computerloadlog.reservationid = reservation.id
#	)
#	
#	LEFT JOIN
#	computerloadstate
#	ON (
#	computerloadstate.id = computerloadlog.loadstateid
#	),
#
#	computer,
#	state computerstate
#	
#	WHERE
#	request.id = $request_id
#	AND reservation.requestid = request.id
#	AND computer.id = reservation.computerid
#	AND computerstate.id = computer.stateid
#	AND requeststate.id = request.stateid
#	";
#
#	# Call the database select subroutine
#	# This will return an array of one or more rows based on the select statement
#	my @computerloadlog_rows = database_select($select_statement);
#
#	# Check to make sure 1 row was returned
#	if (scalar @computerloadlog_rows == 0) {
#		notify($ERRORS{'WARNING'}, 0, "reservations associated with request $request_id could not be retrieved from the database, 0 rows were returned");
#		return;
#	}
#
#	my %reservation_status;
#
#	# Loop through the rows, check the loadstate and computer state
#	for my $computerloadlog_row (@computerloadlog_rows) {
#		my $reservation_id         = $computerloadlog_row->{reservation_id};
#		my $request_state_name = $computerloadlog_row->{request_state};
#		my $computerloadstate_name = $computerloadlog_row->{loadstatename};
#		my $computer_state_name = $computerloadlog_row->{computer_state};
#		
#		# If request state has been changed to reserved or inuse, assume all reservations are ready
#		if ($request_state_name =~ /^(reserved|inuse)$/i) {
#			notify($ERRORS{'OK'}, 0, "assuming all reservations are ready, request state is $request_state_name");
#			return 1;
#		}
#		
#		# If request state has been changed to failed or maintenance, return fail
#		if ($request_state_name =~ /^(failed|maintenance)$/i) {
#			notify($ERRORS{'WARNING'}, 0, "unable to determine if all reservations are ready, request state = $request_state_name");
#			return;
#		}
#		
#		# If request been deleted, return 0
#		if ($request_state_name =~ /^(deleted)$/i) {
#			notify($ERRORS{'OK'}, 0, "request state = $request_state_name");
#			return 0;
#		}
#		
#		
#		# Check for computerloadstate = failed
#		if ($computerloadstate_name =~ /failed/i) {
#			$reservation_status{$reservation_id} = "failed: computerloadstate = $computerloadstate_name";
#			next;
#		}
#		
#		# Check for bad computer states
#		if ($computer_state_name =~ /^(failed|maintenance|deleted)$/i) {
#			$reservation_status{$reservation_id} = "failed: computer state = $computer_state_name";
#			next
#		}
#		
#
#		# Skip if loadstatename is undefined, means no computerloadlog rows exist for the reservation
#		if (!defined($computerloadstate_name)) {
#			$reservation_status{$reservation_id} = 'not ready: no computerloadlog entries exist';
#			next;
#		}
#		
#		# Check for loadstatnames we care about
#		if ($computerloadstate_name =~ /^(loadimagecomplete|nodeready|reserved)$/i) {
#			$reservation_status{$reservation_id} = "ready: computerloadstate $computerloadstate_name";
#			next;
#		}
#		
#
#		# Check if computer state indicates it isn't ready
#		if ($computer_state_name =~ /^(reload|reloading|available)$/i) {
#			$reservation_status{$reservation_id} = "not ready: computer state = $computer_state_name";
#			next;
#		}
#
#		notify($ERRORS{'WARNING'}, 0, "unexpected situation: reservation $reservation_id, request state: $request_state_name, computer state: $computer_state_name, computerloadstate: $computerloadstate_name");
#		$reservation_status{$reservation_id} = "not ready: unexpected situation";
#		
#	} ## end for my $computerloadlog_row (@computerloadlog_rows)
#
#	
#	# Assemble a string of all of the statuses
#	my $status_string = '';
#	my $failed        = 0;
#	my $ready         = 1;
#	foreach my $reservation_check_id (sort keys(%reservation_status)) {
#		my $reservation_check_status = $reservation_status{$reservation_check_id};
#		$status_string .= "reservation $request_id:$reservation_check_id: $reservation_check_status\n";
#
#		# Set the failed flag to 1 if any reservations failed
#		if ($reservation_check_status =~ /failed/i) {
#			$failed = 1;
#		}
#
#		# Set the ready flag to 0 if any reservations are set to 0 (matching state wasn't found)
#		if ($reservation_check_status =~ /not ready/) {
#			$ready = 0;
#		}
#	} ## end foreach my $reservation_check_id (sort keys(%reservation_status...
#
#	if ($failed) {
#		notify($ERRORS{'WARNING'}, 0, "request $request_id has failed reservations, returning undefined:\n$status_string");
#		return;
#	}
#
#	if ($ready) {
#		notify($ERRORS{'OK'}, 0, "all reservations for request $request_id are ready, returning $ready:\n$status_string");
#	}
#	else {
#		notify($ERRORS{'OK'}, 0, "not all reservations for request $request_id are ready, returning $ready:\n$status_string");
#	}
#
#	return $ready;
#
#} ## end sub reservations_ready

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
	
	# Check for any running processes
	#my $ps_command = "ps -ef";
	#notify($ERRORS{'DEBUG'}, 0, "executing ps -ef command: $ps_command");
	#my ($ps_exit_status, $ps_output) = run_command($ps_command);
	#if (defined $ps_exit_status && $ps_exit_status == 0) {
	#	notify($ERRORS{'DEBUG'}, 0, "ps exit status=$ps_exit_status, output:\n@{$ps_output}");
	#	
	#	my @matching_processes = grep {/VCL::.*:$reservation_id/} @{$ps_output};
	#	notify($ERRORS{'DEBUG'}, 0, "matching processes: @matching_processes, count: " . scalar @matching_processes);
	#}
	#else {
	#	notify($ERRORS{'WARNING'}, 0, "failed to execute ps command");
	#}
	
	my $process_running = 0;

	#my $process_running;
	#if (defined($pgrep_exit_status) && @{$pgrep_output} > 0) {
	#	notify($ERRORS{'DEBUG'}, 0, "reservation is being processed by:\n@{$pgrep_output}");
	#	$process_running = 1;
	#}
	#elsif (defined($pgrep_exit_status) && @{$pgrep_output} == 0) {
	#	notify($ERRORS{'DEBUG'}, 0, "did not find any running processes for reservation");
	#	$process_running = 0;
	#}
	#elsif (defined($pgrep_exit_status))  {
	#	notify($ERRORS{'WARNING'}, 0, "error occurred running command: $pgrep_command, exit status: $pgrep_exit_status, output:\n@{$pgrep_output}");
	#	$process_running = 0;
	#}
	#else {
	#	notify($ERRORS{'WARNING'}, 0, "command could not be executed: $pgrep_command");
	#	$process_running = 0;
	#}
	
	# Check the results and return
	if ($computerloadlog_exists && $process_running) {
		notify($ERRORS{'DEBUG'}, 0, "reservation is currently being processed");
		return 1;
	}
	elsif (!$computerloadlog_exists && $process_running) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog 'begin' entry does NOT exist but running process was found, returning 1");
		return 1;
	}
	elsif ($computerloadlog_exists && !$process_running) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog 'begin' entry exists but running process was NOT found, returning 0");
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
	
	my $pid;
	my @output = ();
	my $exit_status;
	
	# Pipe the command output to a file handle
	# The open function returns the pid of the process
	if ($pid = open(COMMAND, "$command 2>&1 |")) {
		# Capture the output of the command
		@output = <COMMAND>;
		
		# Save the exit status
		$exit_status = $? >> 8;
		
		if ($? == -1) {
			notify($ERRORS{'OK'}, 0, "\$? is set to $?, setting exit status to 0, Perl bug likely encountered");
			$exit_status = 0;
		}
		
		# Close the command handle
		close(COMMAND);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command: $command, error: $!");
		return;
	}
	
	if (!$no_output) {
		notify($ERRORS{'DEBUG'}, 0, "executed command: $command, pid: $pid, exit status: $exit_status, output:\n@output");
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
	
	return $ascii_value_string;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
