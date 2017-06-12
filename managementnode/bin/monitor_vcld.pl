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

VCL::monitor_vcld - VCL management node daemon service monitoring utility

=head1 SYNOPSIS

 perl monitory_vcld.pl [OPTION]...

=head1 DESCRIPTION

 Usage: perl monitory_vcld.pl [OPTION]...

 Checks the VCL management node daemon service. Starts the service if it is not
 running. Restarts the service if number of seconds since the management node
 last checked into the VCL database is greater than the critical threashold.

   --service-name=NAME      name of the service to check (default: vcld)
   --warning-seconds=NUM    a notice is sent to the VCL system administrators if
                            the management node last checked into the VCL
                            database more than NUM seconds ago (default: 60)
   --critical-seconds=NUM   the service is restarted and a warning message is
                            sent to the VCL system administrators if the
                            management node last checked into the VCL database
                            more than NUM seconds ago (default: 180)

=cut

###############################################################################
package VCL::monitor_vcld;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../lib";

# Specify the version of this module
our $VERSION = '2.5';

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use English -no_match_vars;
use Getopt::Long;

###############################################################################

our $LOGFILE = '/var/log/monitor_vcld.log';
our $DAEMON_MODE = 0;

INIT {
	Getopt::Long::Configure('pass_through');
	my $options = {};
	GetOptions($options, 'help');
	help() if defined($options->{'help'});
}

#==============================================================================

use VCL::utils;
use VCL::Module;

#..............................................................................
# Get the command line options
my $options = {};
GetOptions($options, 'service-name=s');
GetOptions($options, 'warning-seconds=s');
GetOptions($options, 'critical-seconds=s');

# Set default option values if not specified on the command line
my $vcld_service_name = defined($options->{'service-name'}) ? $options->{'service-name'} : 'vcld';
my $lastcheckin_warning_seconds = defined($options->{'warning-seconds'}) ? $options->{'warning-seconds'} : 60;
my $lastcheckin_critical_seconds = defined($options->{'critical-seconds'}) ? $options->{'critical-seconds'} : 180;

# Verify explicit option values
if ($lastcheckin_warning_seconds !~ /^\d+$/) {
	print_warning("--warning-seconds argument is not an integer: $lastcheckin_warning_seconds");
	help();
}
elsif ($lastcheckin_critical_seconds !~ /^\d+$/) {
	print_warning("--critical-seconds argument is not an integer: $lastcheckin_critical_seconds");
	help();
}
elsif ($lastcheckin_warning_seconds > $lastcheckin_critical_seconds) {
	print_warning("--warning-seconds argument ($lastcheckin_warning_seconds) is not less than --critical-seconds argument ($lastcheckin_critical_seconds)");
	help();
}

#..............................................................................
# Create a management node OS object
my $mn_os_perl_package = 'VCL::Module::OS::Linux::ManagementNode';
my $mn_os = VCL::Module::create_object($mn_os_perl_package);
if (!$mn_os) {
	print_warning("failed to create management node OS object");
	exit 1;
}

# Set the object's own MN OS to itself
# This is needed because some places in Linux.pm use $self->mn_os
$mn_os->set_mn_os($mn_os);

my $management_node_name = $mn_os->data->get_management_node_short_name();

#..............................................................................

print_message("checking $vcld_service_name service on $management_node_name, last checkin thresholds, warning: $lastcheckin_warning_seconds seconds, critical: $lastcheckin_critical_seconds");

# Check if the vcld service exists
if (!$mn_os->service_exists($vcld_service_name)) {
	print_warning("$vcld_service_name service does not exist on $management_node_name");
	exit 1;
}

# Check if the vcld service is running
my $service_status = $mn_os->is_service_running($vcld_service_name);
if (!defined($service_status)) {
	print_critical("failed to determine if $vcld_service_name service is running on $management_node_name");
	exit 1;
}
elsif ($service_status) {
	print_message("$vcld_service_name service is running on $management_node_name");
}
else {
	print_warning("$vcld_service_name service is not running on $management_node_name");
	
	# Attempt to start the service
	if ($mn_os->start_service($vcld_service_name)) {
		print_message("started $vcld_service_name service on $management_node_name, waiting 30 seconds before checking if daemon is checking into database");
		
		# Wait for 30 seconds and then check last checkin time
		sleep_uninterrupted(30);
	}
	else {
		print_critical("failed to start $vcld_service_name service on $management_node_name");
		exit 1;
	}
}

# Service is running, check management node last checkin time
my $management_node_info = get_management_node_info();
if (!defined($management_node_info)) {
	print_critical("failed to retrieve management node info for $management_node_name");
	exit 1;
}

my $lastcheckin_timestamp = $management_node_info->{lastcheckin};
if (!defined($lastcheckin_timestamp)) {
	print_critical("failed to retrieve lastcheckin timestamp from management node info, 'lastcheckin' key was not found:\n" . format_data($management_node_info));
	exit 1;
}

my $current_epoch_seconds = convert_to_epoch_seconds();
my $lastcheckin_epoch_seconds = convert_to_epoch_seconds($lastcheckin_timestamp);
my $lastcheckin_seconds_ago = ($current_epoch_seconds - $lastcheckin_epoch_seconds);

if ($lastcheckin_seconds_ago < 0) {
	print_warning("$management_node_name last checkin time is in the future: $lastcheckin_timestamp, exiting");
}
elsif ($lastcheckin_seconds_ago < $lastcheckin_warning_seconds) {
	print_message("$management_node_name last checked in $lastcheckin_seconds_ago seconds ago at $lastcheckin_timestamp");
}
elsif ($lastcheckin_seconds_ago >= $lastcheckin_critical_seconds) {
	my $critical_message = "critical threshold exceeded, $management_node_name last checked in $lastcheckin_seconds_ago seconds ago at $lastcheckin_timestamp";
	# Attempt to restart the vcld service
	if ($mn_os->restart_service($vcld_service_name)) {
		print_critical("$critical_message, $vcld_service_name service restarted");
	}
	else {
		print_critical("$critical_message, failed to restart $vcld_service_name service");
	}
}
else {
	print_critical("last checkin warning threshold exceeded, $management_node_name last checked in $lastcheckin_seconds_ago seconds ago at $lastcheckin_timestamp");
}

print_message('done');

exit 0;

#/////////////////////////////////////////////////////////////////////////////

=head2 get_message_prefix

 Parameters  : none
 Returns     : string
 Description : 

=cut

sub get_message_prefix {
	my $calling_line = (caller(1))[2];
	
	# 2017-04-08 06:20:03|13772|||vcld|monitor_vcld.pl:print_message|222|vcld service is running on imgr05
	return makedatestring() . "|$PID||||monitor_vcld.pl:main|$calling_line|";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 print_message

 Parameters  : $message
 Returns     : 1
 Description : 

=cut

sub print_message {
	my ($message) = @_;
	print get_message_prefix() . "$message\n";
	VCL::utils::notify($ERRORS{'OK'}, 0, $message);
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 print_warning

 Parameters  : $message
 Returns     : 1
 Description : 

=cut

sub print_warning {
	my ($message) = @_;
	print get_message_prefix() . "WARNING: $message\n";
	VCL::utils::notify($ERRORS{'WARNING'}, 0, $message);
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 print_critical

 Parameters  : $message
 Returns     : 1
 Description : 

=cut

sub print_critical {
	my ($message) = @_;
	print get_message_prefix() . "CRITICAL: $message\n";
	VCL::utils::notify($ERRORS{'CRITICAL'}, 0, $message);
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 help

 Parameters  : none
 Returns     : exits
 Description : Displays a help message and exits.

=cut

sub help {
	
	print <<EOF;
Usage: perl monitory_vcld.pl [OPTION]...

Checks the VCL management node daemon service. Starts the service if it is not
running. Restarts the service if number of seconds since the management node
last checked into the VCL database is greater than the critical threashold.

  --service-name=NAME      name of the service to check
                          (default: vcld)
  --warning-seconds=NUM    a notice is sent to the VCL system administrators if
                           the management node last checked into the VCL
                           database more than NUM seconds ago
                           (default: 60 seconds)
  --critical-seconds=NUM   the service is restarted and a warning message is
                           sent to the VCL system administrators if the
                           management node last checked into the VCL database
                           more than NUM seconds ago
                           (default: 180 seconds)
   --conf=<path>           specify monitory_vcld.pl configuration file
                           (default: /etc/vcl/vcld.conf)
   --log=<path>            specify vcld log file
                           (default: /var/log/monitory_vcld.log)
   --verbose               generate verbose log output

EOF

	exit 1;
}

###############################################################################

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
