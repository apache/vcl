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
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::reserved object based on the request information
 my $reserved = VCL::reserved->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "reserved" state. The reserved state is reached
 after a computer has been loaded. This module checks if the user has
 acknowledged the reservation by clicking the Connect button and has connected
 to the computer. Once connected, the reservation will be put into the "inuse"
 state and the reserved process exits.

=cut

##############################################################################
package VCL::reserved;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  : none
 Returns     : exits
 Description : Processes a reservation in the reserved state. Waits for user
               acknowledgement and connection.

=cut

sub process {
	my $self = shift;
	
	my $request_id                  = $self->data->get_request_id();
	my $request_data                = $self->data->get_request_data();
	my $request_logid               = $self->data->get_request_log_id();
	my $reservation_id              = $self->data->get_reservation_id();
	my $reservation_count           = $self->data->get_reservation_count();
	my $computer_id                 = $self->data->get_computer_id();
	my $computer_short_name         = $self->data->get_computer_short_name();
	my $is_parent_reservation       = $self->data->is_parent_reservation();
	my $server_request_id           = $self->data->get_server_request_id();
	my $acknowledge_timeout_seconds = $self->data->get_variable('acknowledgetimeout') || 900;
	
	# Update the log loaded time to now for this request
	update_log_loaded_time($request_logid);
	
	# Update the computer state to reserved
	# This causes pending to change to the Connect button on the Current Reservations page
	update_computer_state($computer_id, 'reserved');
	
	# Wait for the user to acknowledge the request by clicking Connect button or from API
	if (!$self->code_loop_timeout(sub{$self->user_acknowledged()}, [], 'waiting for user acknowledgement', $acknowledge_timeout_seconds, 1, 10)) {
		$self->_notify_user_timeout($request_data);
		switch_state($request_data, 'timeout', 'timeout', 'noack', 1);
	}
	
	# User acknowledged request
	# Add the cluster information to the loaded computers if this is a cluster reservation
	if ($reservation_count > 1 && !update_cluster_info($request_data)) {
		$self->reservation_failed("update_cluster_info failed");
	}
	
	# Call OS module's grant_access() subroutine which adds user accounts to computer
	if ($self->os->can("grant_access") && !$self->os->grant_access()) {
		$self->reservation_failed("OS module grant_access failed");
	}
	
	# Add additional user accounts, perform other configuration tasks if this is a server request
	if ($server_request_id && !$self->os->manage_server_access()) {
		$self->reservation_failed("OS module manage_server_access failed");
	}
	
	# Check if OS module's post_reserve() subroutine exists
	if ($self->os->can("post_reserve") && !$self->os->post_reserve()) {
		$self->reservation_failed("OS module post_reserve failed");
	}

	# Add a 'reserved' computerloadlog entry
	# Do this last - important for cluster reservation timing
	# Parent's reserved process will loop until this exists for all child reservations
	insertloadlog($reservation_id, $computer_id, "reserved", "$computer_short_name successfully reserved");
	
	# For cluster reservations, the parent must wait until all child reserved processes have exited
	# Otherwise, the state will change to inuse while the child processes are still finishing up the reserved state
	# vcld will then fail to fork inuse processes for the child reservations
	if ($reservation_count > 1 && $is_parent_reservation) {
		if (!$self->code_loop_timeout(sub{$self->wait_for_child_reservations()}, [], "waiting for child reservation reserved processes to complete", 180, 5)) {
			$self->reservation_failed('all child reservation reserved processes did not complete');
		}
		
		# Parent can't tell if reserved processes on other management nodes have terminated
		# Wait a short time in case processes on other management nodes are terminating
		sleep 3;
	}
	
	# Change the request and computer state to inuse then exit
	switch_state($request_data, 'inuse', 'inuse', '', 1);
} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

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
		if (grep { $_ eq 'reserved' } @loadstate_names) {
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
	}
	
	if (@reserved_does_not_exist) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'reserved' entry does NOT exist for all reservations:\n" .
			"exists for reservation IDs: " . join(', ', @reserved_exists) . "\n" .
			"does not exist for reservation IDs: " . join(', ', @reserved_does_not_exist)
		);
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog 'reserved' entry exists for all reservations");
	}
	
	# Check if child reservation processes are running
	return 0 unless $self->is_child_process_running();
	
	notify($ERRORS{'DEBUG'}, 0, "all child reservation reserved processes have completed");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	# Check if user deleted the request
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'DEBUG'}, 0, "request deleted, exiting");
		exit;
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

#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_timeout

 Parameters  : none
 Returns     : boolean
 Description : Notifies the user that the request has timed out becuase no
               initial connection was made. An e-mail and/or IM message will
               be sent to the user.

=cut

sub _notify_user_timeout {
	my $self = shift;
	
	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_email                 = $self->data->get_user_email();
	my $user_emailnotices          = $self->data->get_user_emailnotices();
	my $user_im_name               = $self->data->get_user_imtype_name();
	my $user_im_id                 = $self->data->get_user_im_id();
	my $affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_prettyname           = $self->data->get_image_prettyname();
	my $computer_ip_address        = $self->data->get_computer_ip_address();
	my $is_parent_reservation      = $self->data->is_parent_reservation();

	my $message = <<"EOF";

Your reservation has timed out for image $image_prettyname at address $computer_ip_address because no initial connection was made.

To make another reservation, please revisit $affiliation_sitewwwaddress.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance
please respond with detailed information on the issue
and a help ticket will be generated.

To disable email notices
-Visit $affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences
******************************************************************
EOF

	my $subject = "VCL -- Reservation Timeout";

	if ($is_parent_reservation && $user_emailnotices) {
		#if  "0" user does not care to get additional notices
		mail($user_email, $subject, $message, $affiliation_helpaddress);
		notify($ERRORS{'OK'}, 0, "sent reservation timeout e-mail to $user_email");
	}
	if ($user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
		notify($ERRORS{'OK'}, 0, "sent reservation timeout IM to $user_im_name");
	}
	return 1;
} ## end sub _notify_user_timeout

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
