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
 after a user creates a reservation from the VCL web page. This module checks
 whether or not the user has acknowledged the reservation and connected to
 the machine. Once connected, the reservation will be put into the "inuse"
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
our $VERSION = '2.3.2';

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
 Returns     : 1 if successful, 0 otherwise
 Description : Processes a reservation in the reserved state. Waits for user
               acknowledgement and connection.

=cut

sub process {
	my $self = shift;
	
	my $request_data          = $self->data->get_request_data();
	my $request_id            = $self->data->get_request_id();
	my $request_logid         = $self->data->get_request_log_id();
	my $reservation_id        = $self->data->get_reservation_id();
	my $computer_id           = $self->data->get_computer_id();
	my $computer_hostname     = $self->data->get_computer_host_name();
	my $computer_short_name   = $self->data->get_computer_short_name();
	my $computer_type         = $self->data->get_computer_type();
	my $computer_ip_address   = $self->data->get_computer_ip_address();
	my $image_os_name         = $self->data->get_image_os_name();
	my $image_os_type         = $self->data->get_image_os_type();
	my $request_forimaging    = $self->data->get_request_forimaging;
	my $image_name            = $self->data->get_image_name();
	my $user_unityid          = $self->data->get_user_login_id();
	my $user_uid				  = $self->data->get_user_uid();
	my $user_standalone       = $self->data->get_user_standalone();
	my $imagemeta_checkuser   = $self->data->get_imagemeta_checkuser();
	my $reservation_count     = $self->data->get_reservation_count();
	my $server_request_id	  = $self->data->get_server_request_id();
	my $server_request_admingroupid = $self->data->get_server_request_admingroupid();
	my $server_request_logingroupid = $self->data->get_server_request_logingroupid();
	
	# Update the log table, set the loaded time to now for this request
	if (update_log_loaded_time($request_logid)) {
		notify($ERRORS{'OK'}, 0, "updated log table, set loaded time to now for id:$request_logid");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update log table while attempting to set id:$request_logid loaded time to now");
	}
	
	# Update the computer state to reserved
	if (update_computer_state($computer_id, 'reserved')) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name state set to 'reserved'");
	}
	else {
		# Call reservation_failed
		$self->reservation_failed("failed to set $computer_short_name state to 'reserved'");
	}

	my $nodename;
	my $retval_conn;

	# Figure out the node name based on the type of computer
	if ($computer_type eq "blade") {
		$nodename = $computer_short_name;
	}
	elsif ($computer_type eq "lab") {
		$nodename = $computer_hostname;
	}
	elsif ($computer_type eq "virtualmachine") {
		$nodename = $computer_short_name;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "computer id=$computer_id did not have a type, exiting");
		exit;
	}

	notify($ERRORS{'OK'}, 0, "computer info: id=$computer_id, type=$computer_type, hostname=$nodename");
	notify($ERRORS{'OK'}, 0, "user info: login_id id=$user_unityid, uid=$user_uid, standalone=$user_standalone");
	notify($ERRORS{'OK'}, 0, "imagemeta checkuser set to: $imagemeta_checkuser");
	notify($ERRORS{'OK'}, 0, "formimaging set to: $request_forimaging");

	my $connected     = 0;
	my $curr_time     = time();
	my $time_limit    = 15;
	my $time_exceeded = 0;
	my $break         = 0;

	# Create limit to keep our magic under control
	my $acknowledge_attempts = 0;

	notify($ERRORS{'OK'}, 0, "begin checking for user acknowledgement");
	insertloadlog($reservation_id, $computer_id, "info", "reserved: waiting for user acknowledgement");

	ACKNOWLEDGE:
	$acknowledge_attempts++;

	# Try to get the remote IP again and update the data hash
	my $remote_ip = $self->data->get_reservation_remote_ip();

	# 0 should be returned if remoteIP isn't set, undefined if an error occurred
	if (!defined $remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine remote IP");
		return;
	}

	# Check if remoteIP is defined yet (user has acknowledged)
	elsif ($remote_ip ne '0') {
		# User has acknowledged
		notify($ERRORS{'OK'}, 0, "user acknowledged, remote IP: $remote_ip");
		
		#if cluster reservation - populate parent node with child node information
		if ($reservation_count > 1) {
			notify($ERRORS{'OK'}, 0, "cluster reservation, attempting to populate nodes with cluster_info data");
			if (update_cluster_info($request_data)) {
				notify($ERRORS{'OK'}, 0, "updated cluster nodes with cluster infomation");
			}
		}
		# Attempt to call modularized OS module's grant_access() subroutine
		if ($self->os->can("grant_access")) {
			# If grant_access() has been implemented by OS module,
			# don't check for remote IP and open RDP firewall port directly in this module
			# OS module's grant_access() subroutine to perform the same tasks as below
			notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "::grant_access() subroutine");
			if ($self->os->grant_access()) {
				notify($ERRORS{'OK'}, 0, "OS access has been granted on $nodename");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to grant OS access on $nodename");
			}
		}
		else{
			notify($ERRORS{'CRITICAL'}, 0,"failed to grant access" . ref($self->os) . "::grant_access() subroutine not implemented");
			insertloadlog($reservation_id, $computer_id, "failed", "failed to grant access, grant_access ");
			return;
		}
		
		# Check if OS module's post_reserve() subroutine exists
		if ($self->os->can("post_reserve")) {
			notify($ERRORS{'DEBUG'}, 0, ref($self->os) . "->post_reserve() subroutine exists");
		
			# Call OS module's post_reserve() subroutine
			notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "->post_reserve() subroutine");
			insertloadlog($reservation_id, $computer_id, "info", "calling " . ref($self->os) . "->post_reserve() subroutine");
			if ($self->os->post_reserve()) {
				notify($ERRORS{'OK'}, 0, "performed OS post_reserve tasks for $image_name on $computer_short_name");
				insertloadlog($reservation_id, $computer_id, "info", "performed OS post_reserve tasks for $image_name on $computer_short_name");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to perform OS post_reserve tasks for $image_name on $computer_short_name");
				insertloadlog($reservation_id, $computer_id, "info", "failed to perform OS post_reserve tasks for $image_name on $computer_short_name");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, ref($self->os) . "->post_reserve() not implemented by " . ref($self->os));
		}
		
		notify($ERRORS{'OK'}, 0, "server_request_id = $server_request_id");
		
		#IF server_request_id
		if ($server_request_id) {
			if($server_request_admingroupid || $server_request_logingroupid ) {
				notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "::manage_server_access() subroutine");
				if ($self->os->manage_server_access()) {
					notify($ERRORS{'DEBUG'}, 0, "Added users to server reservation");
				
				}
			}
		}
		
		
	}    # close if defined remoteIP

	elsif ($acknowledge_attempts < 900) {
		# User has approximately 15 minutes to acknowledge (5 seconds * 180 attempts)

		if (($acknowledge_attempts % 30) == 0) {
			# Print message every tenth attempt
			notify($ERRORS{'OK'}, 0, "attempt $acknowledge_attempts/900, user has not acknowleged");
		}

		sleep 1;

		# Check if user deleted the request
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "user has deleted the request, exiting");
			exit;
		}

		# Going back to check for user acknowledgment again
		goto ACKNOWLEDGE;

	}    # Close acknowledge attempts < 120


	else {
		# Acknowledge attemtps >= 120
		# User never acknowledged reques, return noack
		notify($ERRORS{'OK'}, 0, "user never acknowleged request, proceed to timeout");

		# Check if user deleted the request
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "user has deleted the request, exiting");
			exit;
		}

		$retval_conn = "noack";

		# Skipping check_connection code
		goto RETVALCONN;
	} ## end else [ if (defined $remote_ip && $remote_ip eq '0') [... [elsif ($acknowledge_attempts < 180)
	
	$retval_conn = $self->os->is_user_connected($time_limit);
	
	if ($retval_conn eq "nologin") {
	
		# Determine if connection needs to be checked based on imagemeta checkuser flag
		if (!$imagemeta_checkuser) {
			# If checkuser = 1, check for a user connection
			# If checkuser = 0, set as inuse and return
			notify($ERRORS{'OK'}, 0, "checkuser flag set to 0, skipping user connection");
			$retval_conn = "connected";
			goto RETVALCONN;
		}
		# Check if cluster request
		elsif ($reservation_count > 1) {
			notify($ERRORS{'OK'}, 0, "reservation count is $reservation_count, skipping user connection check");
			$retval_conn = "connected";
			goto RETVALCONN;
		}
		# Check if forimaging 
		elsif ($request_forimaging){
			notify($ERRORS{'OK'}, 0, "reservation is for image creation skipping user connection check");
			$retval_conn = "connected";
			goto RETVALCONN;
		}
		elsif ($server_request_id) {
			notify($ERRORS{'OK'}, 0, "reservation is for server reservation skipping user connection check");
			$retval_conn = "connected";
			goto RETVALCONN;
		}
	}

	RETVALCONN:
	notify($ERRORS{'OK'}, 0, "retval_conn = $retval_conn");

	# Check the return value and perform some actions
	if ($retval_conn eq "deleted") {
		notify($ERRORS{'OK'}, 0, "user deleted request, exiting");
		exit;
	}

	elsif ($retval_conn eq "connected") {
		# User is connected, update state of the request, computer and set lastcheck time to current time
		notify($ERRORS{'OK'}, 0, "$remote_ip connected to $nodename");

		insertloadlog($reservation_id, $computer_id, "connected", "reserved: user connected to remote machine");
		
		if($self->os->process_connect_methods($remote_ip, 1)) {
			notify($ERRORS{'OK'}, 0, "process_connect_methods return successfully  $remote_ip $nodename");
		}

		# Update the request state to either inuse or imageinuse
		if (update_request_state($request_id, "inuse", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into inuse state");
		}

		# Update the computer state to inuse
		if (update_computer_state($computer_id, "inuse")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into inuse state");
		}

		# Update the lastcheck value for this reservation to now
		if (update_reservation_lastcheck($reservation_id)) {
			notify($ERRORS{'OK'}, 0, "updated lastcheck time for reservation $reservation_id");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to update lastcheck time for reservation $reservation_id");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "connected")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "conn_wrong_ip") {
		# does the same as above, until we make a firm decision as to how to handle this
		#update remote_ip
		$remote_ip = $self->data->get_reservation_remote_ip();

		if($self->os->process_connect_methods($remote_ip, 1)) {
         notify($ERRORS{'OK'}, 0, "process_connect_methods return successfully  $remote_ip $nodename");
      }

		# Update the request state to inuse
		if (update_request_state($request_id, "inuse", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into inuse state");
		}

		# Update the computer state to inuse
		if (update_computer_state($computer_id, "inuse")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into inuse state");
		}

		# Update the lastcheck value for this reservation to now
		if (update_reservation_lastcheck($reservation_id)) {
			notify($ERRORS{'OK'}, 0, "updated lastcheck time for reservation $reservation_id");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to update lastcheck time for reservation $reservation_id");
		}
	

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "conn_wrong_ip")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "nologin") {
		#user ack'd but did not login
		notify($ERRORS{'OK'}, 0, "user acknowledged but did not log in");

		# Update the request state to timeout
		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		$self->_notify_user_timeout($request_data);

		# Update the entry in the log table with the current finalend time and ending set to nologin
		if (update_log_ending($request_logid, "nologin")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to nologin");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to nologin");
		}

		insertloadlog($reservation_id, $computer_id, "info", "reserved: timing out user not connected to remote machine");

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "nologin")  [ if ($retval_conn eq "deleted")
	elsif ($retval_conn eq "noack") {
		# set to timeout state
		#user never ack'd
		notify($ERRORS{'OK'}, 0, "user never acknowledged");

		# Update the request state to timeout
		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		$self->_notify_user_timeout($request_data);

		# Update the entry in the log table with the current finalend time and ending set to noack
		if (update_log_ending($request_logid, "noack")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to noack");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to noack");
		}

		insertloadlog($reservation_id, $computer_id, "info", "reserved: timing out user not acknowledged reservation");

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "noack")  [ if ($retval_conn eq "deleted")
	elsif ($retval_conn eq "failed") {
		# Update the request state to failed
		notify($ERRORS{'OK'}, 0, "failed to reserve machine");

		if (update_request_state($request_id, "failed", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into failed state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into failed state");
		}

		# Update the computer state to failed
		if (update_computer_state($computer_id, "failed")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into failed state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into failed state");
		}

		# Update the entry in the log table with the current finalend time and ending set to noack
		if (update_log_ending($request_logid, "failed")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to failed");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to failed");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "failed")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "timeout") {
		# Update the request state to timeout
		notify($ERRORS{'OK'}, 0, "reservation timed out");

		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		# Update the entry in the log table with the current finalend time and ending set to timeout
		if (update_log_ending($request_logid, "timeout")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to timeout");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to timeout");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "timeout")  [ if ($retval_conn eq "deleted")
} ## end sub process
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_timeout

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the request has timed out becuase no
               initial connection was made. An e-mail and/or IM message will
               be sent to the user.

=cut

sub _notify_user_timeout {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

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
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

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
