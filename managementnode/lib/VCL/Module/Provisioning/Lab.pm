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

VCL::Provisioning::Lab - VCL module to support povisioning of lab machines

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::Provisioning::Lab;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  :
 Returns     :
 Description :

=cut

sub initialize {
	my $self                  = shift;
	my $request_id            = $self->data->get_request_id();
	my $reservation_id        = $self->data->get_reservation_id();
	my $reservation_is_parent = $self->data->is_parent_reservation;
	my $request_check_time    = $self->data->get_request_check_time();
	my $computer_id           = $self->data->get_computer_id();

	notify($ERRORS{'OK'}, 0, "initializing Lab module, computer id: $computer_id, is parent reservation: $reservation_is_parent");

	# Check if this is a preload request
	# Nothing needs to be done for lab preloads
	if ($request_check_time eq 'preload') {
		notify($ERRORS{'OK'}, 0, "check_time result is $request_check_time, nothing needs to be done for lab preloads");

		insertloadlog($reservation_id, $computer_id, "info", "lab preload does not need to be processed");

		# Only the parent reservation should update the preload flag
		if ($reservation_is_parent) {
			# Set the preload flag back to 1 so it will be processed again
			if (update_preload_flag($request_id, 1)) {
				notify($ERRORS{'OK'}, 0, "parent reservation: updated preload flag to 1");
				insertloadlog($reservation_id, $computer_id, "info", "request preload flag updated to 1");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "parent reservation: failed to update preload flag to 1");
				insertloadlog($reservation_id, $computer_id, "info", "failed to update request preload flag to 1");
			}
		} ## end if ($reservation_is_parent)
		else {
			notify($ERRORS{'OK'}, 0, "child reservation: request preload flag will be changed by the parent reservation");
		}
		notify($ERRORS{'OK'}, 0, "preload lab reservation process exiting");
		exit;
	} ## end if ($request_check_time eq 'preload')
	else {
		notify($ERRORS{'OK'}, 0, "check_time result is $request_check_time, reservation will be processed");
	}
} ## end sub initialize

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : [0]: computer node name (optional)
               [1]: log file path (optional)
 Returns     : Depends on the context which node_status was called:
               default: string containing "READY" or "FAIL"
					boolean: true if ping, SSH, and VCL client checks are successful
					         false if any checks fail
               list: array, values are 1 for SUCCESS, 0 for FAIL
					         [0]: Node status ("READY" or "FAIL")
							   [1]: Ping status (0 or 1)
							   [2]: SSH status (0 or 1)
						   	[3]: VCL client daemon status (0 ir 1)
					arrayref: reference to array described above
               hashref: reference to hash with keys/values:
					         {status} => <"READY","FAIL">
						   	{ping} => <0,1>
						   	{ssh} => <0,1>
							   {vcl_client} => <0,1>
 Description : Checks the status of a lab machine.  Checks if the machine is
               pingable, can be accessed via SSH, and the VCL client is running.

=cut

sub node_status {
	my $self = shift;
	my ($computer_node_name, $log);

	my ($management_node_os_name, $management_node_keys, $computer_host_name, $computer_short_name, $computer_ip_address, $image_os_name);

	# Check if subroutine was called as a class method
	if (ref($self) !~ /lab/i) {
		if (ref($self) eq 'HASH') {
			$log = $self->{logfile};
			notify($ERRORS{'DEBUG'}, $log, "self is a hash reference");
		}
		# Check if node_status returned an array ref
		elsif (ref($self) eq 'ARRAY') {
			notify($ERRORS{'DEBUG'}, 0, "self is a array reference");
		}

		$computer_node_name      = $self->{computer}->{hostname};
		$management_node_os_name = $self->{managementnode}->{OSNAME};
		$management_node_keys    = $self->{managementnode}->{keys};
		$computer_host_name      = $self->{computer}->{hostname};
		$computer_ip_address     = $self->{computer}->{IPaddress};
		$image_os_name           = $self->{image}->{OS}->{name};

		$log = 0 if !$log;
		$computer_short_name = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);

	} ## end if (ref($self) !~ /lab/i)
	else {
		# Get the computer name from the DataStructure
		$computer_node_name = $self->data->get_computer_node_name();

		# Check if this was called as a class method, but a node name was also specified as an argument
		my $node_name_argument = shift;
		$computer_node_name      = $node_name_argument if $node_name_argument;
		$management_node_os_name = $self->data->get_management_node_os_name();
		$management_node_keys    = $self->data->get_management_node_keys();
		$computer_host_name      = $self->data->get_computer_host_name();
		$computer_short_name     = $self->data->get_computer_short_name();
		$computer_ip_address     = $self->data->get_computer_ip_address();
		$image_os_name           = $self->data->get_image_os_name();
		$log                     = 0;
	} ## end else [ if (ref($self) !~ /lab/i)

	notify($ERRORS{'DEBUG'}, $log, "computer_short_name= $computer_short_name ");
	notify($ERRORS{'DEBUG'}, $log, "computer_node_name= $computer_node_name ");
	notify($ERRORS{'DEBUG'}, $log, "image_os_name= $image_os_name");
	notify($ERRORS{'DEBUG'}, $log, "management_node_os_name= $management_node_os_name");
	notify($ERRORS{'DEBUG'}, $log, "computer_ip_address= $computer_ip_address");
	notify($ERRORS{'DEBUG'}, $log, "management_node_keys= $management_node_keys");


	# Check the node name variable
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, $log, "node name could not be determined");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, $log, "checking status of node: $computer_node_name");

	$computer_host_name = $computer_node_name;

	# Create a hash to store status components
	my %status;

	# Initialize all hash keys here to make sure they're defined
	$status{status}     = 0;
	$status{ping}       = 0;
	$status{ssh}        = 0;
	$status{vcl_client} = 0;

	# Check if host is listed in management node's known_hosts file
	notify($ERRORS{'DEBUG'}, $log, "checking if $computer_host_name in management node known_hosts file");
	if (known_hosts($computer_host_name, $management_node_os_name, $computer_ip_address)) {
		notify($ERRORS{'OK'}, $log, "$computer_host_name public key added to management node known_hosts file");
	}
	else {
		notify($ERRORS{'WARNING'}, $log, "failed to add $computer_host_name public key to management node known_hosts");
	}


	# Check if node is pingable
	notify($ERRORS{'DEBUG'}, $log, "checking if $computer_ip_address is pingable");
	if (_pingnode($computer_ip_address)) {
		notify($ERRORS{'OK'}, $log, "$computer_ip_address is pingable");
		$status{ping} = 1;
	}
	else {
		notify($ERRORS{'OK'}, $log, "$computer_ip_address is not pingable");
		$status{ping} = 0;
	}


	# Check if sshd is open on the admin port (24)
	notify($ERRORS{'DEBUG'}, $log, "checking if $computer_ip_address sshd admin port 24 is accessible");
	if (check_ssh($computer_ip_address, 24, $log)) {
		notify($ERRORS{'OK'}, $log, "$computer_ip_address admin sshd port 24 is accessible");

		# Run uname -n to make sure ssh is usable
		notify($ERRORS{'OK'}, $log, "checking if ssh command can be run on $computer_ip_address");
		my ($uname_exit_status, $uname_output) = run_ssh_command($computer_ip_address, $management_node_keys, "uname -n", "vclstaff", 24);
		if (!defined($uname_output) || !$uname_output) {
			notify($ERRORS{'WARNING'}, $log, "unable to run 'uname -n' ssh command on $computer_ip_address");
			$status{ssh} = 0;
		}
		else {
			notify($ERRORS{'OK'}, $log, "successfully ran 'uname -n' ssh command on $computer_ip_address");
			$status{ssh} = 1;
		}

		## Check the uname -n output lines, make sure computer name is listed
		#if (grep /$computer_short_name/, @{$uname_output}) {
		#	notify($ERRORS{'OK'}, $log, "found computer name in ssh 'uname -n' output");
		#	#$status{ssh} = 1;
		#}
		#else {
		#	my $uname_output_string = join("\n", @{$uname_output});
		#	notify($ERRORS{'WARNING'}, $log, "unable to find computer name in ssh 'uname -n' output output:\n$uname_output_string");
		#	#$status{ssh} = 0;
		#}

		# Check if is VCL client daemon is running
		notify($ERRORS{'OK'}, $log, "checking if VCL client daemon is running on $computer_ip_address");
		my ($pgrep_exit_status, $pgrep_output) = run_ssh_command($computer_ip_address, $management_node_keys, "pgrep vclclient", "vclstaff", 24);
		if (!defined($pgrep_output) || !$pgrep_output) {
			notify($ERRORS{'WARNING'}, $log, "unable to run 'pgrep vclclient' command on $computer_ip_address");
			$status{vcl_client} = 0;
		}

		# Check the pgrep output lines, make sure process is listed
		if (grep /[0-9]+/, @{$pgrep_output}) {
			notify($ERRORS{'DEBUG'}, $log, "VCL client daemon is running");
			$status{vcl_client} = 1;
		}
		else {
			my $pgrep_output_string = join("\n", @{$pgrep_output});
			notify($ERRORS{'WARNING'}, $log, "VCL client daemon is not running, unable to find running process in 'pgrep vclclient' output:\n$pgrep_output_string");
			$status{vcl_client} = 0;
		}
	} ## end if (check_ssh($computer_ip_address, 24, $log...
	else {
		notify($ERRORS{'WARNING'}, $log, "$computer_ip_address sshd admin port 24 is not accessible");
		$status{ssh}        = 0;
		$status{vcl_client} = 0;
	}

	# Determine the overall machine status based on the individual status results
	if ($status{ping} && $status{ssh} && $status{vcl_client}) {
		$status{status} = 'READY';
	}
	else {
		# Lab machine is not available, return undefined to indicate error occurred
		notify($ERRORS{'WARNING'}, 0, "lab machine $computer_host_name ($computer_ip_address) is not available");
		$status{status} = 'RELOAD';
	}

	notify($ERRORS{'OK'}, 0, "returning node status hash reference with {status}=$status{status}");
	return \%status;
} ## end sub node_status

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
