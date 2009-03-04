#!/usr/bin/perl -w

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

##############################################################################
# $Id: inuse.pm 1945 2008-12-11 20:58:08Z fapeeler $
##############################################################################

=head1 NAME

VCL::inuse - Perl module for the VCL inuse state

=head1 SYNOPSIS

 use VCL::inuse;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::inuse object based on the request information
 my $inuse = VCL::inuse->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "inuse" state. The inuse state is reached after
 a user has made a reservation, acknowledged the reservation, and connected to
 the machine. Once connected, vcld creates a new process which then
 creates a new instance of this module.

 If the "checkuser" flag is set for the image that the user requested,
 this process will periodically check to make sure the user is still
 connected. Users have 15 minutes to reconnect before the machine is
 reclaimed.

 This module periodically checks the end time for the user's request versus
 the current time. If the end time is near, notifications may be sent to the
 user. Once the end time has been reached, the user is disconnected and the
 request and computer are put into the "timeout" state.

=cut

##############################################################################
package VCL::inuse;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

# Specify the version of this module
our $VERSION = '2.00';

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

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Processes a reservation in the inuse state. You must pass this
               method a reference to a hash containing request data.

=cut

sub process {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# Store hash variables into local variables
	my $request_data = $self->data->get_request_data;

	my $request_id            = $request_data->{id};
	my $reservation_id        = $request_data->{RESERVATIONID};
	my $request_end           = $request_data->{end};
	my $request_logid         = $request_data->{logid};
	my $request_checktime     = $request_data->{CHECKTIME};
	my $reservation_remoteip  = $request_data->{reservation}{$reservation_id}{remoteIP};
	my $computer_id           = $request_data->{reservation}{$reservation_id}{computer}{id};
	my $computer_shortname    = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};
	my $computer_type         = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $computer_hostname     = $request_data->{reservation}{$reservation_id}{computer}{hostname};
	my $computer_nodename     = $request_data->{reservation}{$reservation_id}{computer}{NODENAME};
	my $computer_ipaddress    = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};
	my $image_os_name         = $request_data->{reservation}{$reservation_id}{image}{OS}{name};
	my $imagemeta_checkuser   = $request_data->{reservation}{$reservation_id}{image}{imagemeta}{checkuser};
	my $user_unityid          = $request_data->{user}{unityid};
	my $request_forimaging    = $request_data->{forimaging};
	my $identity_key          = $request_data->{reservation}{$reservation_id}{image}{IDENTITY};
	my $image_os_type         = $self->data->get_image_os_type();
	my $reservation_count     = $self->data->get_reservation_count();
	my $is_parent_reservation = $self->data->is_parent_reservation();

	# Set the user connection timeout limit in minutes
	my $connect_timeout_limit = 15;
	
	# Check if request imaging status has changed
	# Check if this is an imaging request, causes process to exit if state or laststate = image
	$request_forimaging = $self->_check_imaging_request();

	# Remove rows from computerloadlog for this reservation, don't remove the loadstate=begin row
	if (delete_computerloadlog_reservation($reservation_id, '!begin')) {
		notify($ERRORS{'OK'}, 0, "rows removed from computerloadlog table for reservation $reservation_id");
	}
	else {
		notify($ERRORS{'OK'}, 0, "unable to remove rows from computerloadlog table for reservation $reservation_id");
	}

	# Update the lastcheck value for this reservation to now
	if (update_reservation_lastcheck($reservation_id)) {
		notify($ERRORS{'OK'}, 0, "updated lastcheck time for reservation $reservation_id");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to update lastcheck time for reservation $reservation_id");
	}

	# For inuse state, check_time should return 'end', 'poll', or 'nothing'

	# Is this a poll or end time
	if ($request_checktime eq "poll") {
		notify($ERRORS{'OK'}, 0, "beginning to poll");

		if ($image_os_type =~ /windows/) {
			if (firewall_compare_update($computer_nodename, $reservation_remoteip, $identity_key, $image_os_type)) {
				notify($ERRORS{'OK'}, 0, "confirmed firewall scope has been updated");
			}
		}
		
		# Check the imagemeta checkuser flag, request forimaging flag, and if cluster request
		if (!$imagemeta_checkuser || $request_forimaging || ($reservation_count > 1)) {
			# Either imagemeta checkuser flag = 0, forimaging = 1, or cluster request
			if (!$imagemeta_checkuser) {
				notify($ERRORS{'OK'}, 0, "imagemeta checkuser flag not set, skipping user connection check");
			}
			if ($request_forimaging) {
				notify($ERRORS{'OK'}, 0, "forimaging flag is set to 1, skipping user connection check");
			}
			if ($reservation_count > 1) {
				notify($ERRORS{'OK'}, 0, "reservation count is $reservation_count, skipping user connection check");
			}

			# Get a date string for the current time
			my $date_string;

			# Check end time for a notice interval
			# This returns 0 if no notice is to be given
			my $notice_interval = check_endtimenotice_interval($request_end);

			if ($notice_interval) {
				notify($ERRORS{'OK'}, 0, "notice interval is set to $notice_interval");

				# Notify the user of the end time
				$self->_notify_user_endtime($notice_interval);

				# Set lastcheck time ahead by 16 minutes for all notices except the last (30 minute) notice
				if ($notice_interval ne "30 minutes") {
					my $epoch_now = convert_to_epoch_seconds();
					$date_string = convert_to_datetime(($epoch_now + (16 * 60)));
				}
				else {
					my $epoch_now = convert_to_epoch_seconds();
					$date_string = convert_to_datetime($epoch_now);
				}
			} ## end if ($notice_interval)

			# Check if the user deleted the request
			if (is_request_deleted($request_id)) {
				# User deleted request, exit queitly
				notify($ERRORS{'OK'}, 0, "user has deleted the request, quietly exiting");
				exit;
			}

			# Check if request imaging status has changed
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$request_forimaging = $self->_check_imaging_request();

			# Put this request back into the inuse state
			if ($is_parent_reservation && update_request_state($request_id, "inuse", "inuse")) {
				notify($ERRORS{'OK'}, 0, "request state set back to inuse");
			}
			elsif (!$is_parent_reservation) {
				notify($ERRORS{'OK'}, 0, "child reservation, request state NOT set back to inuse");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
			}

			# Update the lastcheck time for this reservation
			if (update_reservation_lastcheck($reservation_id)) {
				my $dstring = convert_to_datetime();
				notify($ERRORS{'OK'}, 0, "updated lastcheck time for this reservation to $dstring");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to update lastcheck time for this reservation to $date_string");
			}

			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}    # Close if poll and checkuser = 0


		# Poll:
		# Simply check for user connection
		# If not connected:
		#   Loop; check end time, continue to check for connection
		#   If not connected within 15 minutes -- timeout
		#   If end time is near prepare
		notify($ERRORS{'OK'}, 0, "proceeding to check for user connection");

		# Get epoch seconds for current and end time, calculate difference
		my $now_epoch       = convert_to_epoch_seconds();
		my $end_epoch       = convert_to_epoch_seconds($request_end);
		my $time_difference = $end_epoch - $now_epoch;

		# If end time is 10-15 minutes from now:
		#    Sleep difference
		#    Go to end mode
		if ($time_difference >= (10 * 60) && $time_difference <= (15 * 60)) {
			notify($ERRORS{'OK'}, 0, "end time ($time_difference seconds) is 10-15 minutes from now");

			# Calculate the sleep time = time until the request end - 10 minutes
			# User will have 10 minutes after this sleep call before disconnected
			my $sleep_time = $time_difference - (10 * 60);
			notify($ERRORS{'OK'}, 0, "sleeping for $sleep_time seconds");
			sleep $sleep_time;
			$request_data->{CHECKTIME} = "end";
			goto ENDTIME;
		}    # Close if poll, checkuser=1, and end time is 10-15 minutes away

		notify($ERRORS{'OK'}, 0, "end time not yet reached, polling machine for user connection");

		# Check the user connection, this will loop until user connects or time limit is reached
		my $check_connection = check_connection($computer_nodename, $computer_ipaddress, $computer_type, $reservation_remoteip, $connect_timeout_limit, $image_os_name, 0, $request_id, $user_unityid,$image_os_type);

		#TESTING
		#$check_connection = 'timeout';

		# Proceed based on status of check_connection
		if ($check_connection eq "connected" || $check_connection eq "conn_wrong_ip") {
			notify($ERRORS{'OK'}, 0, "user connected");

			# Check if request imaging status has changed
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$request_forimaging = $self->_check_imaging_request();
	
			# Put this request back into the inuse state
			if (update_request_state($request_id, "inuse", "inuse")) {
				notify($ERRORS{'OK'}, 0, "request state set back to inuse");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
			}

			# Update the lastcheck time for this reservation
			if (update_reservation_lastcheck($reservation_id)) {
				notify($ERRORS{'OK'}, 0, "updated lastcheck time for this reservation to now");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to update lastcheck time for this reservation to now");
			}

			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}    # Close check_connection is connected

		elsif (!$request_forimaging && $check_connection eq "timeout") {
			notify($ERRORS{'OK'}, 0, "user did not reconnect within $connect_timeout_limit minute time limit");

			# Check if request imaging status has changed
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$request_forimaging = $self->_check_imaging_request();
	
			notify($ERRORS{'OK'}, 0, "notifying user that request timed out");
			$self->_notify_user_timeout();

			# Put this request into the timeout state
			if (update_request_state($request_id, "timeout", "inuse")) {
				notify($ERRORS{'OK'}, 0, "request state set to timeout");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set request state to timeout");
			}

			# Get the current computer state directly from the database
			my $computer_state;
			if ($computer_state = get_computer_current_state_name($computer_id)) {
				notify($ERRORS{'OK'}, 0, "computer $computer_id state retrieved from database: $computer_state");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to retrieve computer $computer_id state from database");
			}

			# Check if computer is in maintenance state
			if ($computer_state =~ /maintenance/) {
				notify($ERRORS{'OK'}, 0, "computer $computer_shortname in maintenance state, skipping update");
			}
			else {
				# Computer is not in maintenance state, set its state to timeout
				if (update_computer_state($computer_id, "timeout")) {
					notify($ERRORS{'OK'}, 0, "computer $computer_id set to timeout state");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to set computer $computer_id to the timeout state");
				}
			}

			# Update the entry in the log table with the current finalend time and ending set to timeout
			if (update_log_ending($request_logid, "timeout")) {
				notify($ERRORS{'OK'}, 0, "log id $request_logid finalend was updated to now and ending set to timeout");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "log id $request_logid finalend could not be updated to now and ending set to timeout");
			}

			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		} ## end elsif ($check_connection eq "timeout")  [ if ($check_connection eq "connected")

		elsif ($check_connection eq "deleted") {
			# Exit quietly
			notify($ERRORS{'OK'}, 0, "user has deleted the request, quietly exiting");
			exit;
		}

		else {
			notify($ERRORS{'CRITICAL'}, 0, "unexpected return value from check_connection: $check_connection, treating request as connected");

			# Check if request imaging status has changed
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$request_forimaging = $self->_check_imaging_request();
			
			# Put this request back into the inuse state
			if (update_request_state($request_id, "inuse", "inuse")) {
				notify($ERRORS{'OK'}, 0, "request state set back to inuse");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
			}

			# Update the lastcheck time for this reservation
			if (update_reservation_lastcheck($reservation_id)) {
				notify($ERRORS{'OK'}, 0, "updated lastcheck time for this reservation to now");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to update lastcheck time for this reservation to now");
			}

			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		} ## end else [ if ($check_connection eq "connected")  [... [elsif ($check_connection eq "deleted")

	}    # Close if checktime is poll

	elsif ($request_checktime eq "end") {
		# Time has ended
		# Notify user to save work and exit within 10 minutes

		ENDTIME:
		my $notified        = 0;
		my $disconnect_time = 10;

		# Loop until disconnect time = 0
		while ($disconnect_time != 0) {
			notify($ERRORS{'OK'}, 0, "minutes left until user is disconnected: $disconnect_time");

			# Notify user at 10 minutes until disconnect
			if ($disconnect_time == 10) {
				$self->_notify_user_disconnect($disconnect_time);
				insertloadlog($reservation_id, $computer_id, "inuseend10", "notifying user of disconnect");
			}

			# Sleep one minute and decrement disconnect time by a minute
			sleep 60;
			$disconnect_time--;
		
			# Check if the user deleted the request
			if (is_request_deleted($request_id)) {
				# User deleted request, exit queitly
				notify($ERRORS{'OK'}, 0, "user has deleted the request, quietly exiting");
				exit;
			}
			
			# Perform some actions at 5 minutes until end of request
			if ($disconnect_time == 5) {
				# Check for connection
				if (isconnected($computer_hostname, $computer_type, $reservation_remoteip, $image_os_name, $computer_ipaddress,$image_os_type)) {
					insertloadlog($reservation_id, $computer_id, "inuseend5", "notifying user of endtime");
					$self->_notify_user_disconnect($disconnect_time);
				}
				else {
					insertloadlog($reservation_id, $computer_id, "inuseend5", "user is not connected, notification skipped");
					notify($ERRORS{'OK'}, 0, "user has disconnected from $computer_shortname, skipping additional notices");
				}
			}    # Close if disconnect time = 5

			# Check to see if the end time was extended
			my $new_request_end;
			if ($new_request_end = get_request_end($request_id)) {
				notify($ERRORS{'OK'}, 0, "request end value in database: $new_request_end");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to retrieve updated request end value from database");
			}

			# Convert the current and new end times to epoch seconds
			my $new_request_end_epoch = convert_to_epoch_seconds($new_request_end);
			my $request_end_epoch     = convert_to_epoch_seconds($request_end);
			
			# Check if request imaging status has changed
			# Check if this is an imaging request, causes process to exit if state or laststate = image
			$request_forimaging = $self->_check_imaging_request();

			# Check if request end is later than the original (user extended time)
			if ($new_request_end_epoch > $request_end_epoch) {
				notify($ERRORS{'OK'}, 0, "user extended end time, returning request to inuse state");

				# Put this request back into the inuse state
				if ($is_parent_reservation && update_request_state($request_id, "inuse", "inuse")) {
					notify($ERRORS{'OK'}, 0, "request state set back to inuse");
				}
				elsif (!$is_parent_reservation) {
					notify($ERRORS{'OK'}, 0, "child reservation, request state NOT set back to inuse");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
				}

				notify($ERRORS{'OK'}, 0, "exiting");
				exit;
			} ## end if ($new_request_end_epoch > $request_end_epoch)

		}    # Close while disconnect time is not 0

		# Check if this is an imaging request, causes process to exit if state or laststate = image
		$request_forimaging = $self->_check_imaging_request();

		# Insert an entry into the load log
		insertloadlog($reservation_id, $computer_id, "timeout", "endtime reached moving to timeout");
		notify($ERRORS{'OK'}, 0, "end time reached, setting request to timeout state");

		# Put this request into the timeout state
		if ($is_parent_reservation && update_request_state($request_id, "timeout", "inuse")) {
			notify($ERRORS{'OK'}, 0, "request state set to timeout");
		}
		elsif (!$is_parent_reservation) {
			notify($ERRORS{'OK'}, 0, "child reservation, request state NOT set back to timeout");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request state to timout");
		}

		# Get the current computer state directly from the database
		my $computer_state;
		if ($computer_state = get_computer_current_state_name($computer_id)) {
			notify($ERRORS{'OK'}, 0, "computer $computer_id state retrieved from database: $computer_state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to retrieve computer $computer_id state from database");
		}

		# Check if computer is in maintenance state
		if ($computer_state =~ /maintenance/) {
			notify($ERRORS{'OK'}, 0, "computer $computer_shortname in maintenance state, skipping computer state update");
		}
		else {
			notify($ERRORS{'OK'}, 0, "computer not in maintenance, setting computer to timeout state");
			# Computer is not in maintenance state, set its state to timeout
			if (update_computer_state($computer_id, "timeout")) {
				notify($ERRORS{'OK'}, 0, "computer $computer_id set to timeout state");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set computer $computer_id to the timeout state");
			}
		} ## end else [ if ($computer_state =~ /maintenance/)

		# Notify user about ending request
		$self->_notify_user_request_ended();

		# Update the entry in the log table with the current finalend time and ending set to timeout
		if ($is_parent_reservation && update_log_ending($request_logid, "EOR")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid finalend was updated to now and ending set to EOR");
		}
		elsif (!$is_parent_reservation) {
			notify($ERRORS{'OK'}, 0, "child reservation, log id $request_logid finalend was NOT updated");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid finalend could not be updated to now and ending set to EOR");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;

	}    # Close if request checktime is end

	# Not poll or end
	else {
		notify($ERRORS{'OK'}, 0, "returning \'$request_checktime\', exiting");
		exit;
	}

	notify($ERRORS{'OK'}, 0, "exiting");
	exit;
} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_endtime

 Parameters  : $request_data_hash_reference, $notice_interval
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user how long they have until the end of the
               request. Based on the user configuration, an e-mail message,
               IM message, or wall message may be sent.
               A notice interval string must be passed. Its value should be
               something like "5 minutes".

=cut

sub _notify_user_endtime {
	my $self            = shift;
	my $notice_interval = shift;

	my ($package, $filename, $line, $sub) = caller(0);

	my $request_data          = $self->data->get_request_data;
	my $is_parent_reservation = $self->data->is_parent_reservation();

	# Check to make sure notice interval is set
	if (!defined($notice_interval)) {
		notify($ERRORS{'WARNING'}, 0, "end time message not set, notice interval was not passed");
		return 0;
	}

	# Store hash variables into local variables
	my $request_id                 = $request_data->{id};
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $user_preferredname         = $request_data->{user}{preferredname};
	my $user_email                 = $request_data->{user}{email};
	my $user_emailnotices          = $request_data->{user}{emailnotices};
	my $user_im_name               = $request_data->{user}{IMtype}{name};
	my $user_im_id                 = $request_data->{user}{IMid};
	my $user_unityid               = $request_data->{user}{unityid};
	my $affiliation_sitewwwaddress = $request_data->{user}{affiliation}{sitewwwaddress};
	my $affiliation_helpaddress    = $request_data->{user}{affiliation}{helpaddress};
	my $image_prettyname           = $request_data->{reservation}{$reservation_id}{image}{prettyname};
	my $image_os_name              = $request_data->{reservation}{$reservation_id}{image}{OS}{name};
	my $computer_ipaddress         = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};
	my $computer_type              = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $computer_shortname         = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};

	my $message = <<"EOF";
$user_preferredname,
You have $notice_interval until the end of your reservation for image $image_prettyname.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

To edit this reservation:
-Visit $affiliation_sitewwwaddress
-Select Current Reservations

Thank You,
VCL Team
EOF

	my $subject = "VCL -- $notice_interval until end of reservation";

	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}

	# Send IM
	if ($is_parent_reservation && $user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
	}

	return 1;
} ## end sub _notify_user_endtime
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_disconnect

 Parameters  : $request_data_hash_reference, $disconnect_time
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the session will be disconnected soon.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent.
               A scalar containing the number of minutes until the user is
               disconnected must be passed as the 2nd parameter.

=cut

sub _notify_user_disconnect {
	my $self            = shift;
	my $disconnect_time = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	my $request_data          = $self->data->get_request_data;
	my $is_parent_reservation = $self->data->is_parent_reservation();

	# Check to make sure disconnect time was passed
	if (!defined($disconnect_time)) {
		notify($ERRORS{'WARNING'}, 0, "disconnect time message not set, disconnect time was not passed");
		return 0;
	}

	# Store hash variables into local variables
	my $request_id                 = $request_data->{id};
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $user_preferredname         = $request_data->{user}{preferredname};
	my $user_email                 = $request_data->{user}{email};
	my $user_emailnotices          = $request_data->{user}{emailnotices};
	my $user_im_name               = $request_data->{user}{IMtype}{name};
	my $user_im_id                 = $request_data->{user}{IMid};
	my $user_unityid               = $request_data->{user}{unityid};
	my $affiliation_sitewwwaddress = $request_data->{user}{affiliation}{sitewwwaddress};
	my $affiliation_helpaddress    = $request_data->{user}{affiliation}{helpaddress};
	my $image_prettyname           = $self->data->get_image_prettyname();
	my $image_os_name              = $self->data->get_image_os_name();
	my $computer_ipaddress         = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};
	my $computer_type              = $self->data->get_computer_type();
	my $image_os_type					 = $self->data->get_image_os_type();
	my $computer_shortname         = $self->data->get_computer_short_name();

	my $disconnect_string;
	if ($disconnect_time == 0) {
		$disconnect_string = "0 minutes";
	}
	elsif ($disconnect_time == 1) {
		$disconnect_string = "1 minute";
	}
	else {
		$disconnect_string = "$disconnect_time minutes";
	}

	my $message = <<"EOF";
$user_preferredname,
You have $disconnect_string until the end of your reservation for image $image_prettyname, please save all work and prepare to exit.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

Visit $affiliation_sitewwwaddress and select Current Reservations to edit this reservation.

Thank you,
VCL Team
EOF

	my $short_message = "$user_preferredname, You have $disconnect_string until the end of your reservation. Please save all work and prepare to log off.";

	my $subject = "VCL -- $disconnect_string until end of reservation";

	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}

	# Send IM
	if ($is_parent_reservation && $user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
	}

	# Send message to machine
	if ($computer_type =~ /blade|virtualmachine/) {
		if ($image_os_type =~ /windows/) {
			# Notify via windows msg cmd
			notify_via_msg($computer_shortname, $user_unityid, $short_message);
		}
		elsif ($image_os_type =~ /linux/){
			# Notify via wall
			notify_via_wall($computer_shortname, $user_unityid, $short_message, $image_os_name, $computer_type);
		}
	} ## end if ($computer_type =~ /blade|virtualmachine/)
	elsif ($computer_type eq "lab") {
		# Notify via wall
		notify_via_wall($computer_ipaddress, $user_unityid, $short_message, $image_os_name, $computer_type);
	}

	return 1;
} ## end sub _notify_user_disconnect
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_timeout

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the session has timed out.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent.

=cut

sub _notify_user_timeout {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	my $request_data          = $self->data->get_request_data;
	my $is_parent_reservation = $self->data->is_parent_reservation();

	# Store some hash variables into local variables
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $user_preferredname         = $request_data->{user}{preferredname};
	my $user_email                 = $request_data->{user}{email};
	my $user_emailnotices          = $request_data->{user}{emailnotices};
	my $user_im_name               = $request_data->{user}{IMtype}{name};
	my $user_im_id                 = $request_data->{user}{IMid};
	my $affiliation_sitewwwaddress = $request_data->{user}{affiliation}{sitewwwaddress};
	my $affiliation_helpaddress    = $request_data->{user}{affiliation}{helpaddress};
	my $image_prettyname           = $request_data->{reservation}{$reservation_id}{image}{prettyname};
	my $computer_ipaddress         = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};

	my $message = <<"EOF";
$user_preferredname,
Your reservation has timed out due to inactivity for image $image_prettyname at address $computer_ipaddress.

To make another reservation, please revisit:
$affiliation_sitewwwaddress

Thank you
VCL Team
EOF

	my $subject = "VCL -- reservation timeout";

	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}

	# Send IM
	if ($is_parent_reservation && $user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
	}

	return 1;
} ## end sub _notify_user_timeout
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_request_ended

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the session has ended.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent.

=cut

sub _notify_user_request_ended {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	my $request_data          = $self->data->get_request_data;
	my $is_parent_reservation = $self->data->is_parent_reservation();

	# Store some hash variables into local variables
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $user_preferredname         = $request_data->{user}{preferredname};
	my $user_email                 = $request_data->{user}{email};
	my $user_emailnotices          = $request_data->{user}{emailnotices};
	my $user_im_name               = $request_data->{user}{IMtype}{name};
	my $user_im_id                 = $request_data->{user}{IMid};
	my $affiliation_helpaddress    = $request_data->{user}{affiliation}{helpaddress};
	my $affiliation_sitewwwaddress = $request_data->{user}{affiliation}{sitewwwaddress};
	my $image_prettyname           = $request_data->{reservation}{$reservation_id}{image}{prettyname};

	my $subject = "VCL -- End of reservation";

	my $message = <<"EOF";
$user_preferredname,
Your reservation of $image_prettyname has ended. Thank you for using $affiliation_sitewwwaddress.

Regards,
VCL Team
EOF

	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $affiliation_helpaddress);
	}

	# Send IM
	if ($is_parent_reservation && $user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
	}

	return 1;
} ## end sub _notify_user_request_ended

#/////////////////////////////////////////////////////////////////////////////

=head2 _check_imaging_request

 Parameters  : 
 Returns     : 1 if not an imaging request, undefined if an error occurred, exits otherwise
 Description : The inuse process exits if the request state or laststate are set to image, or if the forimaging flag has been set.

=cut

sub _check_imaging_request {
	my $self            = shift;
	my $request_id = $self->data->get_request_id();
	my $reservation_id = $self->data->get_reservation_id();
	my $request_forimaging = $self->data->get_request_forimaging();
	
	notify($ERRORS{'DEBUG'}, 0, "checking if request is imaging or if forimaging flag has changed");
	
	# Call is_request_imaging
	# -returns 'image' if request state or laststate = image
	# -returns 'forimaging' if request state and laststate != image, and forimaging = 1
	# -returns 0 if request state and laststate != image, and forimaging = 0
	# -returns undefined if an error occurred
	my $imaging_result = is_request_imaging($request_id);
	
	if ($imaging_result eq 'image') {
		notify($ERRORS{'OK'}, 0, "image creation process has begun, exiting");
		exit;
	}
	elsif ($imaging_result eq 'forimaging') {
		if ($request_forimaging != 1) {
			notify($ERRORS{'OK'}, 0, "request forimaging flag has changed to 1, updating data structure");
			$self->data->set_request_forimaging(1);
		}
		return 1;
	}
	elsif ($imaging_result == 0) {
		if ($request_forimaging != 0) {
			notify($ERRORS{'OK'}, 0, "request forimaging flag has changed to 0, updating data structure");
			$self->data->set_request_forimaging(0);
		}
		return 0;
	}
	elsif (!defined($imaging_result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve request imaging values from database");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected result returned from is_request_imaging: $imaging_result");
		return;
	}
	
}
#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 BUGS and LIMITATIONS

 There are no known bugs in this module.
 Please report problems to the VCL team (vcl_help@ncsu.edu).

=head1 AUTHOR

 Aaron Peeler, aaron_peeler@ncsu.edu
 Andy Kurth, andy_kurth@ncsu.edu

=head1 SEE ALSO

L<http://vcl.ncsu.edu>


=cut
