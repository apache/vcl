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

 Parameters  : Reference to current reserved object is automatically passed
               when invoked as a class method.
 Returns     : Process exits
 Description : Processes a reservation in the reserved state. Waits for user
               acknowledgement and connection.

=cut

sub process {
	my $self = shift;
	
	my $request_id                  = $self->data->get_request_id();
	my @reservation_ids             = $self->data->get_reservation_ids();
	my $request_data                = $self->data->get_request_data();
	my $request_logid               = $self->data->get_request_log_id();
	my $request_forimaging          = $self->data->get_request_forimaging;
	my $reservation_id              = $self->data->get_reservation_id();
	my $reservation_count           = $self->data->get_reservation_count();
	my $computer_id                 = $self->data->get_computer_id();
	my $computer_short_name         = $self->data->get_computer_short_name();
	my $imagemeta_checkuser         = $self->data->get_imagemeta_checkuser();
	my $server_request_id	        = $self->data->get_server_request_id();
	my $acknowledge_timeout_seconds = $self->data->get_variable('acknowledgetimeout') || 900;
	my $connect_timeout_seconds     = $self->data->get_variable('connecttimeout') || 900;
	
	# Update the log loaded time to now for this request
	update_log_loaded_time($request_logid);
	
	# Update the computer state to reserved
	# This causes pending to change to the Connect button on the Current Reservations page
	update_computer_state($computer_id, 'reserved');
	
	# Wait for the user to acknowledge the request by clicking Connect button or from API
	if (!$self->code_loop_timeout(sub{$self->has_user_acknowledged()}, [], 'waiting for user acknowledgement', $acknowledge_timeout_seconds, 1, 10)) {
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
	
	# Wait for the user to connect to the computer
	# This calls process_connect_methods
	my $connected_result = $self->os->is_user_connected(($connect_timeout_seconds / 60));
	
	# Check once more if request has been deleted
	if ($connected_result =~ /deleted/ || is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request deleted, exiting");
		exit;
	}
	elsif ($connected_result =~ /(nologin)/) {
		# Check if user connection check should be ignored
		if (!$imagemeta_checkuser) {
			notify($ERRORS{'OK'}, 0, "ignoring user connection check, imagemeta checkuser flag is false");
		}
		elsif ($reservation_count > 1) {
			notify($ERRORS{'OK'}, 0, "ignoring user connection check, cluster reservation");
		}
		elsif ($request_forimaging){
			notify($ERRORS{'OK'}, 0, "ignoring user connection check, image creation reservation");
		}
		elsif ($server_request_id) {
			notify($ERRORS{'OK'}, 0, "ignoring user connection check, server reservation");
		}
		else {
			# Default case, user never connected, timeout
			$self->_notify_user_timeout($request_data);
			switch_state($request_data, 'timeout', 'timeout', 'nologin', 1);
		}
	}
	else {
		insertloadlog($reservation_id, $computer_id, "connected", "reserved: user connected to $computer_short_name");
	}
	
	# Process the connect methods again, lock the firewall down to the address the user connected from
	my $remote_ip = $self->data->get_reservation_remote_ip();
	if (!$self->os->process_connect_methods($remote_ip, 1)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to process connect methods after user connected to computer");
	}
	
	# Update the lastcheck value for this reservation to now so that inuse does not begin checking immediately
	# If this is a cluster request, update lastcheck for all reservations so they also don't attempt to process the inuse state immediately
	update_reservation_lastcheck(@reservation_ids);
	
	# Change the request and computer state to inuse then exit
	switch_state($request_data, 'inuse', 'inuse', '', 1);
} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 has_user_acknowledged

 Parameters  : none
 Returns     : boolean
 Description : Used as a helper function to the call to code_loop_timeout() in
               process. First checks if the request has been deleted. If so, the
               process exits. If not deleted, checks if the user has
               acknowledged the request by checking if reservation.remoteip is
               set.

=cut

sub has_user_acknowledged {
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

	if ($user_emailnotices) {
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
