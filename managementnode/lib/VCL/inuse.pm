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
our $VERSION = '2.2.1';

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
	
	my $request_id            = $self->data->get_request_id();
	my $reservation_id        = $self->data->get_reservation_id();
	my $request_end           = $self->data->get_request_end_time();
	my $request_duration      = $self->data->get_request_duration_epoch();
	my $request_logid         = $self->data->get_request_log_id();
	my $request_checktime     = $self->data->get_request_check_time();
	my $reservation_remoteip  = $self->data->get_reservation_remote_ip();
	my $computer_id           = $self->data->get_computer_id();
	my $computer_short_name   = $self->data->get_computer_short_name();
	my $computer_type         = $self->data->get_computer_type();
	my $computer_hostname     = $self->data->get_computer_hostname();
	my $computer_nodename     = $self->data->get_computer_node_name();
	my $computer_ip_address   = $self->data->get_computer_ip_address();
	my $image_os_name         = $self->data->get_image_os_name();
	my $imagemeta_checkuser   = $self->data->get_imagemeta_checkuser();
	my $user_login_id         = $self->data->get_user_login_id();
	my $request_forimaging    = $self->data->get_request_forimaging();
	my $image_os_type         = $self->data->get_image_os_type();
	my $reservation_count     = $self->data->get_reservation_count();
	my $is_parent_reservation = $self->data->is_parent_reservation();
	my $identity_key          = $self->data->get_image_identity();
	my $request_state_name    = $self->data->get_request_state_name();
	
	my $connect_info      = $self->data->get_connect_methods();
	
	foreach my $CMid (sort keys % {$connect_info}) {
		notify($ERRORS{'OK'}, 0, "id= $$connect_info{$CMid}{id}") if(defined ($$connect_info{$CMid}{id}) );
		notify($ERRORS{'OK'}, 0, "description= $$connect_info{$CMid}{description}") if(defined ($$connect_info{$CMid}{description}) );
		notify($ERRORS{'OK'}, 0, "port== $$connect_info{$CMid}{port}") if(defined ($$connect_info{$CMid}{port}) );
		notify($ERRORS{'OK'}, 0, "servicename= $$connect_info{$CMid}{servicename}") if(defined ($$connect_info{$CMid}{servicename}) );
		notify($ERRORS{'OK'}, 0, "startupscript= $$connect_info{$CMid}{startupscript}") if(defined ($$connect_info{$CMid}{startupscript}) );
		notify($ERRORS{'OK'}, 0, "autoprov= $$connect_info{$CMid}{autoprovisioned}") if(defined ($$connect_info{$CMid}{autoprovisioned}) );
	}
	
	if ($request_state_name =~ /reboot|rebootsoft|reboothard/) {
		notify($ERRORS{'OK'}, 0, "this is a 'reboot' request");
		if ($self->os->can('reboot')) {
			if ($self->os->reboot()) {
				notify($ERRORS{'OK'}, 0, "successfuly rebooted $computer_nodename");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to reboot $computer_nodename");
				# Do not fail request or machine
			}
			
			# Put this request back into the inuse state
			if (update_request_state($request_id, "inuse", "inuse")) {
				notify($ERRORS{'OK'}, 0, "request state set back to inuse");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
			}
			
			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}
	}
	
	#Server modified
	if($request_state_name =~ /servermodified/) {
      notify($ERRORS{'OK'}, 0, "this is a 'servermodified' request");

		#FIXME - a cmd queue is needed to tell vcld what to do
		#for now we assume a user has been added/removed from a user group
		# 
		
		if (!$self->os->manage_server_access()) {
			notify($ERRORS{'WARNING'}, 0, "Failed to update server access");
      }	


		# Put this request back into the inuse state
		if (update_request_state($request_id, "inuse", "inuse")) {
			notify($ERRORS{'OK'}, 0, "request state set back to inuse");
      }
      else {
         notify($ERRORS{'WARNING'}, 0, "unable to set request state back to inuse");
      }
         
      notify($ERRORS{'OK'}, 0, "exiting");
      exit;
	
	}
	
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

				notify($ERRORS{'OK'}, 0, "confirming firewall scope needs to be updated");
		if ($self->os->can('firewall_compare_update')) {
         if ($self->os->firewall_compare_update()) {
				notify($ERRORS{'OK'}, 0, "confirmed firewall scope has been updated");
			}
		}	
		else {
			notify($ERRORS{'OK'}, 0, "OS does not support firewall_compare_update");
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
			# If duration is greater than 24hrs 5minutes then perform end time notice checks
			if($request_duration >= 86640 ){
				# Check end time for a notice interval
				# This returns 0 if no notice is to be given
				my $notice_interval = check_endtimenotice_interval($request_end);
				
				if ($notice_interval && $is_parent_reservation) {
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
			}
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
		}    # if (!$imagemeta_checkuser || $request_forimaging.......
		
		
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
			$request_checktime = "end";
			goto ENDTIME;
		}  # Close if poll, checkuser=1, and end time is 10-15 minutes away
		
		notify($ERRORS{'OK'}, 0, "end time not yet reached, polling machine for user connection");
		
		my $check_connection;
		if($self->os->can("is_user_connected")) {

			#Use new code if it exists
			$check_connection = $self->os->is_user_connected($connect_timeout_limit);
		}	
		else {
		
			# Check the user connection, this will loop until user connects or time limit is reached
			$check_connection = check_connection($computer_nodename, $computer_ip_address, $computer_type, $reservation_remoteip, $connect_timeout_limit, $image_os_name, 0, $request_id, $user_login_id,$image_os_type);
		}
		
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
		} # Close check_connection is connected
		
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
				notify($ERRORS{'OK'}, 0, "computer $computer_short_name in maintenance state, skipping update");
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
				if (isconnected($computer_hostname, $computer_type, $reservation_remoteip, $image_os_name, $computer_ip_address,$image_os_type)) {
					insertloadlog($reservation_id, $computer_id, "inuseend5", "notifying user of endtime");
					$self->_notify_user_disconnect($disconnect_time);
				}
				else {
					insertloadlog($reservation_id, $computer_id, "inuseend5", "user is not connected, notification skipped");
					notify($ERRORS{'OK'}, 0, "user has disconnected from $computer_short_name, skipping additional notices");
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
		
		# Automatically capture image
		# If forimaging and not a cluster reservation - initiate capture process
		if($request_forimaging && ($reservation_count < 2) ){
			# Check if the user deleted the request
			if (is_request_deleted($request_id)) {
				# User deleted request, exit queitly
				notify($ERRORS{'OK'}, 0, "user has deleted the request, quietly exiting");
				exit;
			}
			if ($self->_start_imaging_request){
				notify($ERRORS{'OK'}, 0, "Started image capture process. This process is Exiting.");
				#notify user - endtime and image capture has started
				$self->_notify_user_request_ended();
				exit;
			}	
			else {
				notify($ERRORS{'CRITICAL'}, 0, "_start_imaging_request xmlrpc call failed putting request and node into maintenance");
				# Update the request state to maintenance, laststate to inuse
				if (update_request_state($request_id, "maintenance", "inuse")) {
					notify($ERRORS{'OK'}, 0, "request state set to maintenance, laststate to inuse");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "unable to set request state to maintenance, laststate to inuse");
				}
				
				# Update the computer state to maintenance
				if (update_computer_state($computer_id, "maintenance")) {
					notify($ERRORS{'OK'}, 0, "$computer_short_name state set to maintenance");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "unable to set $computer_short_name state to maintenance");
				}
				exit;
			}
		}
		
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
			notify($ERRORS{'OK'}, 0, "computer $computer_short_name in maintenance state, skipping computer state update");
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
               request. Based on the user configuration, an e-mail message, IM
               message, or wall message may be sent. A notice interval string
               must be passed. Its value should be something like "5 minutes".

=cut

sub _notify_user_endtime {
	my $self            = shift;
	my $notice_interval = shift;
	
	# Check to make sure notice interval is set
	if (!defined($notice_interval)) {
		notify($ERRORS{'WARNING'}, 0, "end time message not set, notice interval was not passed");
		return 0;
	}
	
	my $is_parent_reservation = $self->data->is_parent_reservation();
	if (!$is_parent_reservation) {
		notify($ERRORS{'DEBUG'}, 0, "child reservation - not notifying user of endtime");
		return 1;
	}
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $request_forimaging 		    = $self->_check_imaging_request();	
	my $request_id                      = $self->data->get_request_id();
	
	my $message;
	my $subject;
	my $short_message = "You have $notice_interval until the scheduled end time of your reservation. VCL Team";
	
	$message  = <<"EOF";

You have $notice_interval until the scheduled end time of your reservation for image $image_prettyname.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

To edit this reservation:
-Visit $user_affiliation_sitewwwaddress
-Select Current Reservations

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	$subject = "VCL -- $notice_interval until end of reservation for $image_prettyname";
	
	# Send mail
	if ($user_emailnotices) {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id email notices enabled - notifying user of endtime");
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id email notices disabled - not notifying user of endtime");
	}
	
	# Send message to machine
	if ($computer_type =~ /blade|virtualmachine/) {
		if ($image_os_type =~ /windows/) {
			# Notify via windows msg cmd
			$user_login_id= "administrator" if($request_forimaging);
			notify_via_msg($computer_short_name, $user_login_id, $short_message);
		}
		elsif ($image_os_type =~ /linux/){
			# Notify via wall
			notify_via_wall($computer_short_name, $user_login_id, $short_message, $image_os_name, $computer_type);
		}
	} ## end if ($computer_type =~ /blade|virtualmachine/)
	elsif ($computer_type eq "lab") {
		# Notify via wall
		notify_via_wall($computer_ip_address, $user_login_id, $short_message, $image_os_name, $computer_type);
	}
	
	# Send IM
	if ($user_imtype_name ne "none") {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id IM type: $user_imtype_name - notifying user of endtime");
		notify_via_IM($user_imtype_name, $user_im_id, $message);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id IM type: $user_imtype_name - not notifying user of endtime");
	}
	
	return 1;
} ## end sub _notify_user_endtime
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_disconnect

 Parameters  : $request_data_hash_reference, $disconnect_time
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the session will be disconnected soon.
               Based on the user configuration, an e-mail message, IM message,
               Windows msg, or Linux wall message may be sent. A scalar
               containing the number of minutes until the user is disconnected
               must be passed as the 2nd parameter.

=cut

sub _notify_user_disconnect {
	my $self            = shift;
	my $disconnect_time = shift;
	
	# Check to make sure disconnect time was passed
	if (!defined($disconnect_time)) {
		notify($ERRORS{'WARNING'}, 0, "disconnect time message not set, disconnect time was not passed");
		return 0;
	}
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	my $request_forimaging		    = $self->_check_imaging_request();
	
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
	
	my $short_message;
	my $subject;
	my $message;
	
	if (!$request_forimaging) {
		$message = <<"EOF";

You have $disconnect_string until the end of your reservation for image $image_prettyname, please save all work and prepare to exit.

Reservation extensions are available if the machine you are on does not have a reservation immediately following.

Visit $user_affiliation_sitewwwaddress and select Current Reservations to edit this reservation.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

		$short_message = "You have $disconnect_string until the end of your reservation. Please save all work and prepare to log off.";
		$subject = "VCL -- $disconnect_string until end of reservation";
	}
	else {
		$short_message = "You have $disconnect_string until the auto capture process is started.";
		$subject = "VCL Imaging Reservation -- $disconnect_string until starting auto capture";
		$message = <<"EOF";

You have $disconnect_string until the end of your reservation for image $image_prettyname. 

At the scheduled end time your imaging reservation will be automatically captured. 

To prevent this auto capture, visit the VCL site $user_affiliation_sitewwwaddress manually start the image creation process.

Please note this auto capture feature is intended to prevent destorying any work you have done to the image.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	}
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_IM($user_imtype_name, $user_im_id, $message);
	}
	
	# Send message to machine
	if ($computer_type =~ /blade|virtualmachine/) {
		if ($image_os_type =~ /windows/) {
			# Notify via windows msg cmd
			$user_login_id= "administrator" if($request_forimaging);
			notify_via_msg($computer_short_name, $user_login_id, $short_message);
		}
		elsif ($image_os_type =~ /linux/){
			# Notify via wall
			notify_via_wall($computer_short_name, $user_login_id, $short_message, $image_os_name, $computer_type);
		}
	} ## end if ($computer_type =~ /blade|virtualmachine/)
	elsif ($computer_type eq "lab") {
		# Notify via wall
		notify_via_wall($computer_ip_address, $user_login_id, $short_message, $image_os_name, $computer_type);
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
	
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_login_id                   = $self->data->get_user_login_id();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	
	my $message = <<"EOF";

Your reservation has timed out due to inactivity for image $image_prettyname at address $computer_ip_address.

To make another reservation, please revisit:
$user_affiliation_sitewwwaddress

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	my $subject = "VCL -- reservation timeout";
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_IM($user_imtype_name, $user_im_id, $message);
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
	
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();
	my $is_parent_reservation           = $self->data->is_parent_reservation();
	my $subject;
	my $message;
	
	if(!$request_forimaging) {
	$subject = "VCL -- End of reservation";
	
	$message = <<"EOF";

Your reservation of $image_prettyname has ended. Thank you for using $user_affiliation_sitewwwaddress.

Regards,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF
	}
	else {
		$subject = "VCL Image Reservation - Auto capture started";
		
		$message = <<"EOF";

Your imaging reservation of $image_prettyname has reached it's scheduled end time.

To avoid losing your work we have started an automatic capture of this image. Upon completion of the 
image capture. You will be notified about the completion of the image capture.

Thank You,
VCL Team


******************************************************************
This is an automated notice. If you need assistance please respond 
with detailed information on the issue and a help ticket will be 
generated.

To disable email notices
-Visit $user_affiliation_sitewwwaddress
-Select User Preferences
-Select General Preferences

******************************************************************
EOF

	}
	
	# Send mail
	if ($is_parent_reservation && $user_emailnotices) {
		mail($user_email, $subject, $message, $user_affiliation_helpaddress);
	}
	
	# Send IM
	if ($is_parent_reservation && $user_imtype_name ne "none") {
		notify_via_IM($user_imtype_name, $user_im_id, $message);
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

=head2 _start_imaging_request

 Parameters  : none
 Returns     : boolean
 Description : If request is forimaging and times out, this inserts a imaging
               reservation. 

=cut

sub _start_imaging_request {
	my $self = shift;
	
	my $request_id = $self->data->get_request_id();
	
	my $method = "XMLRPCautoCapture";
	my @argument_string = ($method, $request_id);
	my $xml_ret = xmlrpc_call(@argument_string);
	
	# Check if the XML::RPC call failed
	if (!defined($xml_ret)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start imaging request, XML::RPC '$method' call failed");
		return;
	}
	elsif ($xml_ret->value->{status} !~ /success/) {
		notify($ERRORS{'WARNING'}, 0, "failed to start imaging request, XML::RPC '$method' status: $xml_ret->value->{status}\n" .
				 "error code $xml_ret->value->{errorcode}\n" .
				 "error message: $xml_ret->value->{errormsg}"
		);
		return;
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
