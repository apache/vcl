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

VCL::reserved - Perl module for the VCL reserved state

=head1 SYNOPSIS

 use VCL::reserved;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my $request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info->{RESERVATIONID} = $reservation_id;

 # Create a new VCL::reserved object based on the request information
 my $reserved = VCL::reserved->new($request_info);

=head1 DESCRIPTION

 This module supports the VCL "reserved" state. The reserved state is reached
 after a computer has been loaded. This module checks if the user has
 acknowledged the reservation by clicking the Connect button and has connected
 to the computer. Once connected, the reservation will be put into the "inuse"
 state and the reserved process exits.

=cut

###############################################################################
package VCL::reserved;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use POSIX qw(strftime);

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  : none
 Returns     : exits
 Description : Processes a reservation in the reserved state. Waits for user
               acknowledgement and connection.

=cut

sub process {
	my $self = shift;
	
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_checkuser               = $self->data->get_request_checkuser();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_count               = $self->data->get_reservation_count();
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	my $parent_reservation_id           = $self->data->get_parent_reservation_id();
	my $is_server_request               = $self->data->is_server_request();
	my $imagemeta_checkuser             = $self->data->get_imagemeta_checkuser();
	
	my $acknowledge_timeout_seconds     = $self->os->get_timings('acknowledgetimeout');
	my $initial_connect_timeout_seconds = $self->os->get_timings('initialconnecttimeout');
	
	# Update the log loaded time to now for this request
	update_log_loaded_time($request_logid);
	
	# Make sure firewall object is initialized early to reduce time it takes to configure things after user clicks Connect
	$self->os->firewall() if ($self->os->can('firewall'));
	
	# Update the computer state to reserved
	# This causes pending to change to the Connect button on the Current Reservations page
	update_computer_state($computer_id, 'reserved');
	insertloadlog($reservation_id, $computer_id, "reserved", "$computer_short_name successfully reserved");
	
	
	if ($is_parent_reservation) {
		# Send an email and/or IM to the user
		# Do this after updating the computer state to reserved because this is when the Connect button appears
		$self->notify_user_ready();
		
		# Insert acknowledgetimeout immediately before beginning to check user clicked Connect
		# Web uses timestamp of this to determine when next to refresh the page
		# Important because page should refresh as soon as possible to reservation timing out
		insertloadlog($reservation_id, $computer_id, "acknowledgetimeout", "begin acknowledge timeout ($acknowledge_timeout_seconds seconds)");
	}
	
	my $acknowledge_check_start_epoch_seconds = $self->wait_for_reservation_loadstate($parent_reservation_id, "acknowledgetimeout", $acknowledge_timeout_seconds, 5);
	if (!$acknowledge_check_start_epoch_seconds) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve timestamp of parent reservation $parent_reservation_id 'acknowledgetimeout' computerloadlog entry");
		return;
	}
	
	# Get the current time
	my $now_epoch_seconds = time;
	
	# Calculate the exact time when connection checking should end
	my $acknowledge_check_end_epoch_seconds = ($acknowledge_check_start_epoch_seconds + $acknowledge_timeout_seconds);
	my $acknowledge_timeout_remaining_seconds = ($acknowledge_check_end_epoch_seconds - $now_epoch_seconds);
	
	my $now_string                           = strftime('%H:%M:%S', localtime($now_epoch_seconds));
	my $acknowledge_check_start_string       = strftime('%H:%M:%S', localtime($acknowledge_check_start_epoch_seconds));
	my $acknowledge_check_end_string         = strftime('%H:%M:%S', localtime($acknowledge_check_end_epoch_seconds));
	my $acknowledge_timeout_string           = strftime('%H:%M:%S', gmtime($acknowledge_timeout_seconds));
	my $acknowledge_timeout_remaining_string = strftime('%H:%M:%S', gmtime($acknowledge_timeout_remaining_seconds));
	
	notify($ERRORS{'DEBUG'}, 0, "beginning to check for user acknowledgement:\n" .
		"acknowledge check start   :   $acknowledge_check_start_string\n" .
		"acknowledge timeout total : + $acknowledge_timeout_string\n" .
		"--------------------------------------\n" .
		"acknowledge check end     : = $acknowledge_check_end_string\n" .
		"current time              : - $now_string\n" .
		"--------------------------------------\n" .
		"acknowledge timeout remaining : = $acknowledge_timeout_remaining_string ($acknowledge_timeout_remaining_seconds seconds)\n"
	);
	
	# Wait for the user to acknowledge the request by clicking Connect button or from API
	# Note: for server requests, this will always return true because the frontend inserts reservation.remoteIP when the reservation is made
	my $user_acknowledged = $self->code_loop_timeout(sub{$self->user_acknowledged()}, [], 'waiting for user acknowledgement', $acknowledge_timeout_remaining_seconds, 1, 10);
	if (!$user_acknowledged) {
		$self->notify_user_timeout_no_acknowledgement();
		$self->state_exit('timeout', 'available', 'noack');
	}
	
	# Add noinitialconnection and then delete acknowledgetimeout
	insertloadlog($reservation_id, $computer_id, "noinitialconnection", "user clicked Connect");
	delete_computerloadlog_reservation($reservation_id, 'acknowledgetimeout');
	
	# For non-server requests, the frontend should have inserted an 'initialconnecttimeout' computerloadlog entry for the parent reservation when the user clicks Connect
	# Web uses timestamp of this to determine when next to refresh the page
	# The timestamp of this computerloadlog entry will be used to determine when to timeout the connection checking during the inuse state
	my $connection_check_start_epoch_seconds;
	if ($is_server_request) {
		$connection_check_start_epoch_seconds = time;
		insertloadlog($parent_reservation_id, $computer_id, "initialconnecttimeout", "begin initial connection timeout ($initial_connect_timeout_seconds seconds)");
	}
	else {
		$connection_check_start_epoch_seconds = get_reservation_computerloadlog_time($parent_reservation_id, 'initialconnecttimeout');
		if ($connection_check_start_epoch_seconds) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved timestamp of computerloadlog 'initialconnecttimeout' entry inserted by web frontend: $connection_check_start_epoch_seconds");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "could not retrieve timestamp of computerloadlog 'initialconnecttimeout' entry, web frontend should have inserted this, inserting new entry");
			$connection_check_start_epoch_seconds = time;
			insertloadlog($reservation_id, $computer_id, "initialconnecttimeout", "begin initial connection timeout ($initial_connect_timeout_seconds seconds)");
		}
	}
	
	# Call OS module's grant_access() subroutine which adds user accounts to computer
	if ($self->os->can("grant_access") && !$self->os->grant_access()) {
		$self->reservation_failed("OS module grant_access failed");
	}
	
	# User acknowledged request
	# Add the cluster information to the loaded computers if this is a cluster reservation
	if ($reservation_count > 1 && !$self->os->update_cluster()) {
		$self->reservation_failed("update_cluster failed");
	}
	
	# Create a JSON file containing the reservation info
	my $enable_experimental_features = get_variable('enable_experimental_features', 0);
	if ($enable_experimental_features) {
		$self->os->create_reservation_info_json_file();
	}
	
	# Check if OS module's post_reserve() subroutine exists
	if ($self->os->can("post_reserve") && !$self->os->post_reserve()) {
		$self->reservation_failed("OS module post_reserve failed");
	}
	
	# Add a 'postreserve' computerloadlog entry
	# Do this last - important for cluster reservation timing
	# Parent's reserved process will loop until this exists for all child reservations
	insertloadlog($reservation_id, $computer_id, "postreserve", "$computer_short_name post reserve successful");
	
	# Get the current time
	$now_epoch_seconds = time;
	
	# Calculate the exact time when connection checking should end
	my $connection_check_end_epoch_seconds = ($connection_check_start_epoch_seconds + $initial_connect_timeout_seconds);
	my $connect_timeout_remaining_seconds = ($connection_check_end_epoch_seconds - $now_epoch_seconds);
	
	$now_string                       = strftime('%H:%M:%S', localtime($now_epoch_seconds));
	my $connection_check_start_string    = strftime('%H:%M:%S', localtime($connection_check_start_epoch_seconds));
	my $connection_check_end_string      = strftime('%H:%M:%S', localtime($connection_check_end_epoch_seconds));
	my $connect_timeout_string           = strftime('%H:%M:%S', gmtime($initial_connect_timeout_seconds));
	my $connect_timeout_remaining_string = strftime('%H:%M:%S', gmtime($connect_timeout_remaining_seconds));
	
	notify($ERRORS{'DEBUG'}, 0, "beginning to check for initial user connection:\n" .
		"connection check start    :   $connection_check_start_string\n" .
		"connect timeout total     : + $connect_timeout_string\n" .
		"--------------------------------------\n" .
		"connection check end      : = $connection_check_end_string\n" .
		"current time              : - $now_string\n" .
		"--------------------------------------\n" .
		"connect timeout remaining : = $connect_timeout_remaining_string ($connect_timeout_remaining_seconds seconds)\n"
	);
	
	# Check to see if user is connected. user_connected will true(1) for servers and requests > 24 hours
	my $user_connected = $self->code_loop_timeout(sub{$self->user_connected()}, [], "waiting for initial user connection to $computer_short_name", $connect_timeout_remaining_seconds, 15);
	
	# Delete the connecttimeout immediately after acknowledgement loop ends
	delete_computerloadlog_reservation($reservation_id, 'connecttimeout');
	
	if (!$user_connected) {
		if (!$imagemeta_checkuser || !$request_checkuser) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, imagemeta checkuser: $imagemeta_checkuser, request checkuser: $request_checkuser");
		}
		elsif ($is_server_request) {
			notify($ERRORS{'OK'}, 0, "never detected user connection, skipping timeout, server reservation");
		}
		elsif (is_request_deleted($request_id) || $self->request_state_changed()) {
			$self->state_exit();
		}
		else {
			$self->notify_user_timeout_no_initial_connection();
			$self->state_exit('timeout', 'reserved', 'nologin');
		}
	}
	
	# Add a line to currentimage.txt indicating it's possible a user logged on to the computer
	$self->os->set_tainted_status('user may have logged in');
	
	# Update reservation lastcheck, otherwise inuse request will be processed immediately again
	update_reservation_lastcheck($reservation_id);
	
	# Tighten up the firewall
	# Process the connect methods again, lock the firewall down to the address the user connected from
	my $remote_ip = $self->data->get_reservation_remote_ip();
	if ($self->os->can('firewall') && $self->os->firewall->can('process_inuse')) {
		$self->os->firewall->process_inuse($remote_ip);
	}
	else {
		if (!$self->os->process_connect_methods($remote_ip, 1)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to process connect methods after user connected to computer");
		}
	}
	
	# Perform steps after a user makes an initial connection
	$self->os->post_initial_connection();
	
	# For cluster reservations, the parent must wait until all child reserved processes have exited
	# Otherwise, the state will change to inuse while the child processes are still finishing up the reserved state
	# vcld will then fail to fork inuse processes for the child reservations
	if ($reservation_count > 1 && $is_parent_reservation) {
		if (!$self->code_loop_timeout(sub{$self->wait_for_child_reservations()}, [], "waiting for child reservation reserved processes to complete", 360, 5)) {
			$self->reservation_failed('all child reservation reserved processes did not complete');
		}
		
		# Parent can't tell if reserved processes on other management nodes have terminated
		# Wait a short time in case processes on other management nodes are terminating
		sleep 3;
	}
	
	# Change the request and computer state to inuse then exit
	$self->state_exit('inuse', 'inuse');
} ## end sub process

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_child_reservations

 Parameters  : none
 Returns     : boolean
 Description : Checks if all child reservation 'reserved' processes have
               completed.

=cut

sub wait_for_child_reservations {
	my $self = shift;
	my $request_id = $self->data->get_request_id();
	
	exit if is_request_deleted($request_id);
	
	# Check if 'reserved' computerloadlog entry exists for all reservations
	my $request_loadstate_names = get_request_loadstate_names($request_id);
	if (!$request_loadstate_names) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve request loadstate names");
		return;
	}
	
	my @reserved_exists;
	my @reserved_does_not_exist;
	my @failed;
	for my $reservation_id (keys %$request_loadstate_names) {
		my @loadstate_names = @{$request_loadstate_names->{$reservation_id}};
		if (grep { $_ eq 'postreserve' } @loadstate_names) {
			push @reserved_exists, $reservation_id;
		}
		else {
			push @reserved_does_not_exist, $reservation_id;
		}
		
		if (grep { $_ eq 'failed' } @loadstate_names) {
			push @failed, $reservation_id;
		}
	}
	
	# Check if any child reservations failed
	if (@failed) {
		$self->reservation_failed("child reservation reserve process failed: " . join(', ', @failed));
		return;
	}
	
	if (@reserved_does_not_exist) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'postreserve' entry does NOT exist for all reservations:\n" .
			"exists for reservation IDs: " . join(', ', @reserved_exists) . "\n" .
			"does not exist for reservation IDs: " . join(', ', @reserved_does_not_exist)
		);
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'postreserve' entry exists for all reservations");
	}
	
	notify($ERRORS{'DEBUG'}, 0, "all child reservation reserved processes have completed");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 user_acknowledged

 Parameters  : none
 Returns     : boolean
 Description : Used as a helper function to the call to code_loop_timeout() in
               process. First checks if the request has been deleted. If so, the
               process exits. If not deleted, checks if the user has
               acknowledged the request by checking if reservation.remoteip is
               set.

=cut

sub user_acknowledged {
	my $self = shift;
	if (ref($self) !~ /VCL::reserved/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL::reserved object");
		return;
	}
	
	my $request_id = $self->data->get_request_id();
	
	# Check if the request state changed for any reason
	# This will occur if the user deletes the request or makeproduction is initiated before the user acknowledges
	if ($self->request_state_changed()) {
		$self->state_exit();
	}
	
	my $remote_ip = $self->data->get_reservation_remote_ip();
	if ($remote_ip) {
		notify($ERRORS{'DEBUG'}, 0, "user acknowledged from remote IP address: $remote_ip");
		return 1;
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 notify_user_ready

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the reservation is ready.

=cut

sub notify_user_ready {
	my $self = shift;
	
	my $request_state_name = $self->data->get_request_id();
	my $user_email = $self->data->get_user_email();
	my $user_emailnotices = $self->data->get_user_emailnotices();
	my $user_imtype_name = $self->data->get_user_imtype_name() || 'none';;
	my $user_im_id = $self->data->get_user_im_id();
	my $affiliation_helpaddress = $self->data->get_user_affiliation_helpaddress();
	my $is_parent_reservation = $self->data->is_parent_reservation();
	
	my $user_message_key;
	if ($request_state_name =~ /^(reinstall)$/) {
		$user_message_key = 'reinstalled';
	}
	else {
		$user_message_key = 'reserved';
	}
	
	my ($subject, $message) = $self->get_user_message($user_message_key);
	if (!defined($subject) || !defined($message)) {
		return;
	}
	
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}
	else {
		notify($ERRORS{'MAILMASTERS'}, 0, "$user_email\n$message");
	}
	
	if ($user_imtype_name ne "none") {
		notify_via_im($user_imtype_name, $user_im_id, $message, $affiliation_helpaddress);
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 notify_user_timeout_no_initial_connection

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the request has timed out because no
               initial connection was made. An e-mail and/or IM message will
               be sent to the user.

=cut

sub notify_user_timeout_no_initial_connection {
	my $self = shift;
	
	my $user_email                 = $self->data->get_user_email();
	my $user_emailnotices          = $self->data->get_user_emailnotices();
	my $user_im_name               = $self->data->get_user_imtype_name() || 'none';;
	my $user_im_id                 = $self->data->get_user_im_id();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $is_parent_reservation      = $self->data->is_parent_reservation();
	
	my $user_message_key = 'timeout_no_initial_connection';
	my ($subject, $message) = $self->get_user_message($user_message_key);
	if (!defined($subject) || !defined($message)) {
		return;
	}
	
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}
	if ($user_im_name ne "none") {
		notify_via_im($user_im_name, $user_im_id, $message);
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 notify_user_timeout_no_acknowledgement

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the request has timed out because no
               initial connection was made. An e-mail and/or IM message will
               be sent to the user.

=cut

sub notify_user_timeout_no_acknowledgement {
	my $self = shift;
	
	my $user_email                 = $self->data->get_user_email();
	my $user_emailnotices          = $self->data->get_user_emailnotices();
	my $user_im_name               = $self->data->get_user_imtype_name() || 'none';;
	my $user_im_id                 = $self->data->get_user_im_id();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $is_parent_reservation      = $self->data->is_parent_reservation();
	
	my $user_message_key = 'timeout_no_acknowledgement';
	my ($subject, $message) = $self->get_user_message($user_message_key);
	if (!defined($subject) || !defined($message)) {
		return;
	}
	
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}
	if ($user_im_name ne "none") {
		notify_via_im($user_im_name, $user_im_id, $message);
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
