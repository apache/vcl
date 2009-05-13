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

VCL::new - Perl module for the VCL new state

=head1 SYNOPSIS

 use VCL::new;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::new object based on the request information
 my $new = VCL::new->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "new" state.

=cut

##############################################################################
package VCL::new;

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

 Parameters  :
 Returns     :
 Description :

=cut

sub process {
	my $self = shift;

	my $request_data                    = $self->data->get_request_data();
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_state_name              = $self->data->get_request_state_name();
	my $request_laststate_name          = $self->data->get_request_laststate_name();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $request_preload_only            = $self->data->get_request_preload_only();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_host_name              = $self->data->get_computer_host_name();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $computer_preferred_image_id     = $self->data->get_computer_preferredimage_id();
	my $computer_preferred_image_name   = $self->data->get_computer_preferredimage_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_name                      = $self->data->get_image_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_project                   = $self->data->get_image_project();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $image_architecture              = $self->data->get_image_architecture();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $imagemeta_checkuser             = $self->data->get_imagemeta_checkuser();
	my $imagemeta_usergroupid           = $self->data->get_imagemeta_usergroupid();
	my $imagemeta_usergroupmembercount  = $self->data->get_imagemeta_usergroupmembercount();
	my $imagemeta_usergroupmembers      = $self->data->get_imagemeta_usergroupmembers();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $managementnode_id               = $self->data->get_management_node_id();
	my $managementnode_hostname         = $self->data->get_management_node_hostname();
	my $user_unityid                    = $self->data->get_user_login_id();
	my $user_uid                        = $self->data->get_user_uid();
	my $user_preferredname              = $self->data->get_user_preferred_name();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();

	notify($ERRORS{'OK'}, 0, "reservation is parent = $reservation_is_parent");
	notify($ERRORS{'OK'}, 0, "preload only = $request_preload_only");
	notify($ERRORS{'OK'}, 0, "originating request state = $request_state_name");
	notify($ERRORS{'OK'}, 0, "originating request laststate = $request_laststate_name");
	notify($ERRORS{'OK'}, 0, "originating computer state = $computer_state_name");
	notify($ERRORS{'OK'}, 0, "originating computer type = $computer_type");
	
	# If state is tomaintenance, place machine into maintenance state and set request to complete
	if ($request_state_name =~ /tomaintenance/) {
		notify($ERRORS{'OK'}, 0, "this is a 'tomaintenance' request");

		# Update the request state to complete, update the computer state to maintenance, exit
		# Do not update log.ending for tomaintenance reservations
		if (switch_state($request_data, 'complete', 'maintenance', '', '0')) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name set to maintenance");
		}

		# Set vmhostid to null
		if (switch_vmhost_id($computer_id, 'NULL')) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name vmhostid removed");

			if ($self->provisioner->can("post_maintenance_action")) {
				if ($self->provisioner->post_maintenance_action()) {
					notify($ERRORS{'OK'}, 0, "post action completed $computer_short_name");
				}
			}
			else {
				notify($ERRORS{'OK'}, 0, "post action skipped, post_maintenance_action not implemented by " . ref($self->provisioner) . ", assuming no steps required");
			}
		} ## end if (switch_vmhost_id($computer_id, 'NULL'))

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end if ($request_state_name =~ /tomaintenance/)
	
	# Confirm requested computer is available
	if ($self->computer_not_being_used()) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is not being used");
	}
	elsif ($request_state_name ne 'new') {
		# Computer is not available, not a new request (most likely a simple reload)
		notify($ERRORS{'WARNING'}, 0, "request state=$request_state_name, $computer_short_name is NOT available");

		# Set the computer preferred image so it gets loaded if/when other reservations are complete
		if ($image_name ne $computer_preferred_image_name) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name is not available, setting computer preferred image to $image_name");
			if (setpreferredimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name preferred image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name preferred image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "$computer_short_name is not available, computer preferred image is already set to $image_name");
		}

		# Update request state to complete
		if (update_request_state($request_id, "complete", $request_state_name)) {
			notify($ERRORS{'OK'}, 0, "request state updated to 'complete'/'$request_state_name'");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to update the request state to 'complete'/'$request_state_name'");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($request_state_name ne 'new')  [ if ($self->computer_not_being_used())
	elsif ($request_preload_only) {
		# Computer is not available, preload only = true
		notify($ERRORS{'WARNING'}, 0, "preload reservation, $computer_short_name is NOT available");

		# Set the computer preferred image so it gets loaded if/when other reservations are complete
		if ($image_name ne $computer_preferred_image_name) {
			notify($ERRORS{'OK'}, 0, "preload only request, $computer_short_name is not available, setting computer preferred image to $image_name");
			if (setpreferredimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name preferred image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name preferred image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "preload only request, $computer_short_name is not available, computer preferred image is already set to $image_name");
		}

		# Only the parent reservation  is allowed to modify the request state in this module
		if (!$reservation_is_parent) {
			notify($ERRORS{'OK'}, 0, "child preload reservation, computer is not available, states will be changed by the parent");
			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}

		# Return back to original states
		notify($ERRORS{'OK'}, 0, "parent preload reservation, returning states back to original");

		# Set the preload flag back to 1 so it will be processed again
		if (update_preload_flag($request_id, 1)) {
			notify($ERRORS{'OK'}, 0, "updated preload flag to 1");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update preload flag to 1");
		}

		# Return request state back to the original
		if (update_request_state($request_id, $request_state_name, $request_state_name)) {
			notify($ERRORS{'OK'}, 0, "request state set back to '$request_state_name'/'$request_state_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set request state back to '$request_state_name'/'$request_state_name'");
		}

		# Return computer state back to the original
		if (update_computer_state($computer_id, $computer_state_name)) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name state set back to '$computer_state_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name state back to '$computer_state_name'");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($request_preload_only)  [ if ($self->computer_not_being_used())
	else {
		# Computer not available, state=new, PRELOADONLY = false
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available");

		# Call reservation_failed
		$self->reservation_failed("process failed because computer is not available");
	}

	# Confirm requested resouces are available
	if ($self->reload_image()) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is loaded with $image_name");
	}
	elsif ($request_preload_only) {
		# Load failed preload only = true
		notify($ERRORS{'WARNING'}, 0, "preload reservation, failed to load $computer_short_name with $image_name");

		# Check if parent, only the parent is allowed to modify the request state in this module
		if (!$reservation_is_parent) {
			notify($ERRORS{'OK'}, 0, "this is a child preload reservation, states will be changed by the parent");

			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}

		# Return back to original states
		notify($ERRORS{'OK'}, 0, "this is a parent preload reservation, returning states back to original");

		# Set the preload flag back to 1 so it will be processed again
		if (update_preload_flag($request_id, 1)) {
			notify($ERRORS{'OK'}, 0, "updated preload flag to 1");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update preload flag to 1");
		}

		# Return request state back to the original
		if (update_request_state($request_id, $request_state_name, $request_state_name)) {
			notify($ERRORS{'OK'}, 0, "request state set back to '$request_state_name'/'$request_state_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set request state back to '$request_state_name'/'$request_state_name'");
		}

		# Return computer state back to the original
		if (update_computer_state($computer_id, $computer_state_name)) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name state set back to '$computer_state_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name state back to '$computer_state_name'");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($request_preload_only)  [ if ($self->reload_image())
	else {
		# Load failed, PRELOADONLY = false
		notify($ERRORS{'WARNING'}, 0, "failed to load $computer_short_name with $image_name");

		# Call reservation_failed, problem computer not opened for reservation
		$self->reservation_failed("process failed after trying to load or make available");
	}


	# Parent only checks and waits for any other images to complete and checkin
	if ($reservation_is_parent && $reservation_count > 1) {
		insertloadlog($reservation_id, $computer_id, "info", "cluster based reservation");

		# Wait on child reservations
		if ($self->wait_for_child_reservations()) {
			notify($ERRORS{'OK'}, 0, "done waiting for child reservations, they are all ready");
		}
		else {
			# Call reservation_failed, problem computer not opened for reservation
			$self->reservation_failed("child reservations never all became ready");
		}
	} ## end if ($reservation_is_parent && $reservation_count...


	# Check if request has been deleted
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to 'available' and exiting");

		# Update state of computer and exit
		switch_state($request_data, '', 'available', '', '1');
	}

	my $next_computer_state;
	my $next_request_state;

	# Attempt to reserve the computer if this is a 'new' reservation
	# These steps are not done for simple reloads
	if ($request_state_name eq 'new') {
		# Set the computer preferred image to the one for this reservation
		if ($image_name ne $computer_preferred_image_name) {
			if (setpreferredimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name preferred image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name preferred image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "$computer_short_name preferred image is already set to $image_name");
		}

		if ($request_preload_only) {
			# Return back to original states
			notify($ERRORS{'OK'}, 0, "this is a preload reservation, returning states back to original");

			# Set the preload flag back to 1 so it will be processed again
			if (update_preload_flag($request_id, 1)) {
				notify($ERRORS{'OK'}, 0, "updated preload flag to 1");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to update preload flag to 1");
			}

			# Set variables for the next states
			$next_computer_state = $computer_state_name;
			$next_request_state  = $request_state_name;

		} ## end if ($request_preload_only)
		else {
			# Perform the steps necessary to prepare the computer for a user
			if ($self->reserve_computer()) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name with $image_name successfully reserved");
			}
			else {
				# reserve_computer() returned false
				notify($ERRORS{'OK'}, 0, "$computer_short_name with $image_name could NOT be reserved");

				# Call reservation_failed, problem computer not opened for reservation
				$self->reservation_failed("process failed after attempting to reserve the computer");
			}

			# Insert a row into the computerloadlog table
			if (insertloadlog($reservation_id, $computer_id, "reserved", "$computer_short_name successfully reserved with $image_name")) {
				notify($ERRORS{'OK'}, 0, "inserted computerloadlog entry, load state=reserved");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to insert computerloadlog entry, load state=reserved");
			}

			# Set variables for the next states
			$next_computer_state = "reserved";
			$next_request_state  = "reserved";
		} ## end else [ if ($request_preload_only)
	} ## end if ($request_state_name eq 'new')
	elsif ($request_state_name eq 'tovmhostinuse') {
		# Set variables for the next states
		$next_computer_state = "vmhostinuse";
		$next_request_state  = "complete";
	}
	else {
		# Set variables for the next states
		$next_computer_state = "available";
		$next_request_state  = "complete";
	}

	# Update the computer state
	if (update_computer_state($computer_id, $next_computer_state)) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name state set to '$next_computer_state'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name state to '$next_computer_state'");
	}

	# Update request state if this is the parent reservation
	# Only parent reservations should modify the request state
	if ($reservation_is_parent && update_request_state($request_id, $next_request_state, $request_state_name)) {
		notify($ERRORS{'OK'}, 0, "request state set to '$next_request_state'/'$request_state_name'");
	}
	elsif ($reservation_is_parent) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to set request state to '$next_request_state'/'$request_state_name'");
		notify($ERRORS{'OK'},       0, "exiting");
		exit;
	}
	else {
		notify($ERRORS{'OK'}, 0, "this is a child image, request state NOT changed to '$next_request_state'");
	}

	# Insert a row into the computerloadlog table
	if (insertloadlog($reservation_id, $computer_id, "info", "$computer_short_name successfully set to $next_computer_state with $image_name")) {
		notify($ERRORS{'OK'}, 0, "inserted computerloadlog entry: $computer_short_name successfully set to $next_computer_state with $image_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert computerloadlog entry: $computer_short_name successfully set to $next_computer_state with $image_name");
	}

	notify($ERRORS{'OK'}, 0, "exiting");
	exit;

} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 reload_image

 Parameters  :
 Returns     :
 Description :

=cut

sub reload_image {
	my $self = shift;

	my $request_data                    = $self->data->get_request_data();
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_state_name              = $self->data->get_request_state_name();
	my $request_laststate_name          = $self->data->get_request_laststate_name();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $request_preload_only            = $self->data->get_request_preload_only();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_host_name              = $self->data->get_computer_host_name();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $computer_preferred_image_id     = $self->data->get_computer_preferredimage_id();
	my $computer_preferred_image_name   = $self->data->get_computer_preferredimage_name();
	my $computer_currentimage_name 		= $self->data->get_computer_currentimage_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_name                      = $self->data->get_image_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_project                   = $self->data->get_image_project();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $image_architecture              = $self->data->get_image_architecture();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $imagemeta_checkuser             = $self->data->get_imagemeta_checkuser();
	my $imagemeta_usergroupid           = $self->data->get_imagemeta_usergroupid();
	my $imagemeta_usergroupmembercount  = $self->data->get_imagemeta_usergroupmembercount();
	my $imagemeta_usergroupmembers      = $self->data->get_imagemeta_usergroupmembers();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $managementnode_id               = $self->data->get_management_node_id();
	my $managementnode_hostname         = $self->data->get_management_node_hostname();
	my $user_unityid                    = $self->data->get_user_login_id();
	my $user_uid                        = $self->data->get_user_uid();
	my $user_preferredname              = $self->data->get_user_preferred_name();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();

	# Try to get the node status if the provisioning engine has implemented a node_status() subroutine
	my $node_status;
	my $node_status_string = '';
	if ($self->provisioner->can("node_status")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->provisioner) . "->node_status()");
		insertloadlog($reservation_id, $computer_id, "statuscheck", "checking status of node");

		# Call node_status(), check the return value
		$node_status = $self->provisioner->node_status();

		# Make sure a return value is defined, an error occurred if it is undefined
		if (!defined($node_status)) {
			notify($ERRORS{'CRITICAL'}, 0, ref($self->provisioner) . "->node_status() returned an undefined value, returning");
			return;
		}

		# Check what node_status returned and try to get the "status" string
		# First see if it returned a hashref
		if (ref($node_status) eq 'HASH') {
			notify($ERRORS{'DEBUG'}, 0, "node_status returned a hash reference");

			# Check if the hash contains a key called "status"
			if (defined $node_status->{status}) {
				$node_status_string = $node_status->{status};
				notify($ERRORS{'DEBUG'}, 0, "node_status hash reference contains key {status}=$node_status_string");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "node_status hash reference does not contain a key called 'status'");
			}
		} ## end if (ref($node_status) eq 'HASH')

		# Check if node_status returned an array ref
		elsif (ref($node_status) eq 'ARRAY') {
			notify($ERRORS{'DEBUG'}, 0, "node_status returned an array reference");

			# Check if the hash contains a key called "status"
			if (defined((@{$node_status})[0])) {
				$node_status_string = (@{$node_status})[0];
				notify($ERRORS{'DEBUG'}, 0, "node_status array reference contains index [0]=$node_status_string");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "node_status array reference is empty");
			}
		} ## end elsif (ref($node_status) eq 'ARRAY')  [ if (ref($node_status) eq 'HASH')

		# Check if node_status didn't return a reference
		# Assume string was returned
		elsif (!ref($node_status)) {
			# Use scalar value of node_status's return value
			$node_status_string = $node_status;
			notify($ERRORS{'DEBUG'}, 0, "node_status returned a scalar: $node_status");
		}

		else {
			notify($ERRORS{'CRITICAL'}, 0, ref($self->provisioner) . "->node_status() returned an unsupported reference type: " . ref($node_status) . ", returning");
			insertloadlog($reservation_id, $computer_id, "failed", "node_status() returned an undefined value");
			return;
		}
	} ## end if ($self->provisioner->can("node_status"))
	else {
		notify($ERRORS{'OK'}, 0, "node status not checked, node_status() not implemented by " . ref($self->provisioner) . ", assuming load=true");
	}

	if ($computer_state_name eq 'reload') {
		# Always call load() if state is reload regardless of node_status()
		# Admin-initiated reloads will always cause node to be reloaded
		notify($ERRORS{'OK'}, 0, "request state is $request_state_name, node will be reloaded regardless of status");
		$node_status_string = 'reload';
	}

	# Check the status string returned by node_status = 'ready'
	if ($node_status_string =~ /^ready/i) {
		# node_status returned 'ready'
		notify($ERRORS{'OK'}, 0, "node_status returned '$node_status_string', $computer_short_name will not be reloaded");
		insertloadlog($reservation_id, $computer_id, "info", "node status is $node_status_string, $computer_short_name will not be reloaded");

		if($image_name ne $computer_currentimage_name){
			notify($ERRORS{'OK'}, 0, "request image_name does not match computer_current_image name, updating computer record");
			#update computer to reflect correct image name 
			if (update_currentimage($computer_id, $image_id, $imagerevision_id, $image_id)) {
			 notify($ERRORS{'OK'}, 0, "updated computer table for $computer_short_name: currentimageid=$image_id");
			}
			else {
			 notify($ERRORS{'WARNING'}, 0, "failed to update computer table for $computer_short_name: currentimageid=$image_id");
			}

		}
		notify($ERRORS{'OK'}, 0, "returning 1");
		return 1;
	}
	
	# node_status did not return 'ready'
	notify($ERRORS{'OK'}, 0, "node status is $node_status_string, $computer_short_name will be reloaded");
	insertloadlog($reservation_id, $computer_id, "loadimageblade", "$computer_short_name must be reloaded with $image_name");

	# Make sure provisioning module's load() subroutine exists
	if (!$self->provisioner->can("load")) {
		notify($ERRORS{'CRITICAL'}, 0, ref($self->provisioner) . "->load() subroutine does not exist, returning");
		insertloadlog($reservation_id, $computer_id, "failed", ref($self->provisioner) . "->load() subroutine does not exist");
		return;
	}


	# Make sure the image exists on this management node's local disks
	# Attempt to retrieve it if necessary
	if ($self->provisioner->can("does_image_exist")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->provisioner) . "->does_image_exist()");

		if ($self->provisioner->does_image_exist($image_name)) {
			notify($ERRORS{'OK'}, 0, "$image_name exists on this management node");
			insertloadlog($reservation_id, $computer_id, "doesimageexists", "confirmed image exists");
		}
		else {
			notify($ERRORS{'OK'}, 0, "$image_name does not exist on this management node");

			# Try to retrieve the image files from another management node
			if ($self->provisioner->can("retrieve_image")) {
				notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->provisioner) . "->retrieve_image()");

				if ($self->provisioner->retrieve_image($image_name)) {
					notify($ERRORS{'OK'}, 0, "$image_name was retrieved from another management node");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "$image_name does not exist on management node and could not be retrieved");
					insertloadlog($reservation_id, $computer_id, "failed", "requested image does not exist on management node and could not be retrieved");
					return;
				}
			} ## end if ($self->provisioner->can("retrieve_image"...
			else {
				notify($ERRORS{'CRITICAL'}, 0, "unable to retrieve image from another management node, retrieve_image() is not implemented by " . ref($self->provisioner));
				insertloadlog($reservation_id, $computer_id, "failed", "failed requested image does not exist on management node, retrieve_image() is not implemented");
				return;
			}
		} ## end else [ if ($self->provisioner->does_image_exist($image_name...
	} ## end if ($self->provisioner->can("does_image_exist"...
	else {
		notify($ERRORS{'OK'}, 0, "unable to check if image exists, does_image_exist() not implemented by " . ref($self->provisioner));
	}


	# Update the computer state to reloading
	if (update_computer_state($computer_id, "reloading")) {
		notify($ERRORS{'OK'}, 0, "computer $computer_short_name state set to reloading");
		insertloadlog($reservation_id, $computer_id, "info", "computer state updated to reloading");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to set $computer_short_name into reloading state, returning");
		insertloadlog($reservation_id, $computer_id, "failed", "unable to set computer $computer_short_name state to reloading");
		return;
	}


	# Call provisioning module's load() subroutine
	notify($ERRORS{'OK'}, 0, "calling " . ref($self->provisioner) . "->load() subroutine");
	insertloadlog($reservation_id, $computer_id, "info", "calling " . ref($self->provisioner) . "->load() subroutine");
	if ($self->provisioner->load($node_status)) {
		notify($ERRORS{'OK'}, 0, "$image_name was successfully reloaded on $computer_short_name");
		insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "$image_name was successfully reloaded on $computer_short_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$image_name failed to load on $computer_short_name, returning");
		insertloadlog($reservation_id, $computer_id, "loadimagefailed", "$image_name failed to load on $computer_short_name");
		return;
	}


	# Update the current image ID in the computer table
	if (update_currentimage($computer_id, $image_id, $imagerevision_id, $image_id)) {
		notify($ERRORS{'OK'}, 0, "updated computer table for $computer_short_name: currentimageid=$image_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update computer table for $computer_short_name: currentimageid=$image_id");
	}
	
	
	# Check if OS module's post_load() subroutine exists
	if ($self->os->can("post_load")) {
		notify($ERRORS{'OK'}, 0, ref($self->os) . "->post_load() subroutine exists");
	
		# Call OS module's post_load() subroutine
		notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "->post_load() subroutine");
		insertloadlog($reservation_id, $computer_id, "info", "calling " . ref($self->os) . "->post_load() subroutine");
		if ($self->os->post_load()) {
			notify($ERRORS{'OK'}, 0, "successfully performed OS post-load tasks for $image_name on $computer_short_name");
			insertloadlog($reservation_id, $computer_id, "info", "performed OS post-load tasks for $image_name on $computer_short_name");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to perform OS post-load tasks for $image_name on $computer_short_name, returning");
			insertloadlog($reservation_id, $computer_id, "loadimagefailed", "failed to perform OS post-load tasks for $image_name on $computer_short_name");
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, ref($self->os) . "->post_load() subroutine does not exist");
	}

	notify($ERRORS{'OK'}, 0, "node ready: successfully reloaded $computer_short_name with $image_name");
	insertloadlog($reservation_id, $computer_id, "nodeready", "$computer_short_name was reloaded with $image_name");

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub reload_image

#/////////////////////////////////////////////////////////////////////////////

=head2 computer_not_being_used

 Parameters  :
 Returns     :
 Description :

=cut

sub computer_not_being_used {
	my $self = shift;

	my $request_data                    = $self->data->get_request_data();
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_state_name              = $self->data->get_request_state_name();
	my $request_laststate_name          = $self->data->get_request_laststate_name();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $request_preload_only            = $self->data->get_request_preload_only();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_host_name              = $self->data->get_computer_host_name();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $computer_preferred_image_id     = $self->data->get_computer_preferredimage_id();
	my $computer_preferred_image_name   = $self->data->get_computer_preferredimage_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_name                      = $self->data->get_image_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_project                   = $self->data->get_image_project();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $image_architecture              = $self->data->get_image_architecture();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $imagemeta_checkuser             = $self->data->get_imagemeta_checkuser();
	my $imagemeta_usergroupid           = $self->data->get_imagemeta_usergroupid();
	my $imagemeta_usergroupmembercount  = $self->data->get_imagemeta_usergroupmembercount();
	my $imagemeta_usergroupmembers      = $self->data->get_imagemeta_usergroupmembers();
	my $imagerevision_id                = $self->data->get_computer_imagerevision_id();
	my $managementnode_id               = $self->data->get_management_node_id();
	my $managementnode_hostname         = $self->data->get_management_node_hostname();
	my $user_unityid                    = $self->data->get_user_login_id();
	my $user_uid                        = $self->data->get_user_uid();
	my $user_preferredname              = $self->data->get_user_preferred_name();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();

	# Possible computer states:
	# available
	# deleted
	# failed
	# inuse
	# maintenance
	# reloading
	# reserved
	# vmhostinuse

	notify($ERRORS{'DEBUG'}, 0, "$computer_short_name state is $computer_state_name");
		
	# Return 0 if computer state is maintenance or deleted
	if ($computer_state_name =~ /^(deleted|maintenance)$/) {
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, its state is $computer_state_name");
		return 0;
	}

	# Check if computer state is available
	if ($computer_state_name =~ /^(available|reload)$/) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is available, its state is $computer_state_name");
		return 1;
	}
	# Warn if computer state is failed, proceed to check for neighbor reservations
	else {
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name state is $computer_state_name, checking if any conflicting requests are active");
	}

	# Set variables to control how may attempts are made to wait for an existing inuse reservation to end
	my $inuse_loop_attempts = 4;
	my $inuse_loop_wait     = 30;

	INUSE_LOOP: for (my $inuse_loop_count = 0; $inuse_loop_count < $inuse_loop_attempts; $inuse_loop_count++) {

		# Check if this isn't the first iteration meaning something conflicting was found
		if ($inuse_loop_count > 0) {
			notify($ERRORS{'OK'}, 0, "attempt $inuse_loop_count/$inuse_loop_attempts: waiting for $inuse_loop_wait seconds before checking neighbor requests again");
			sleep $inuse_loop_wait;
		}

		# Check if there is another request using this machine
		# Get a hash containing all of the reservations for the computer
		notify($ERRORS{'OK'}, 0, "checking neighbor reservations for $computer_short_name");
		my %neighbor_requests = get_request_by_computerid($computer_id);

		# There should be at least 1 request -- the one being processed
		if (!%neighbor_requests) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve any requests for computer id=$computer_id, there should be at least 1");
			return;
		}

		notify($ERRORS{'OK'}, 0, "found " . scalar keys(%neighbor_requests) . " total reservations for $computer_short_name");

		# Loop through the neighbor requests
		NEIGHBOR_REQUESTS: foreach my $neighbor_request_key (keys %neighbor_requests) {
			my $neighbor_request_id     = $neighbor_requests{$neighbor_request_key}{requestid};
			my $neighbor_reservation_id = $neighbor_requests{$neighbor_request_key}{reservationid};
			my $neighbor_state_name     = $neighbor_requests{$neighbor_request_key}{currentstate};
			my $neighbor_laststate_name = $neighbor_requests{$neighbor_request_key}{laststate};
			my $neighbor_request_start  = $neighbor_requests{$neighbor_request_key}{requeststart};

			my $neighbor_request_start_epoch = convert_to_epoch_seconds($neighbor_request_start);
			my $now_epoch                    = time();
			my $neighbor_start_diff          = $neighbor_request_start_epoch - $now_epoch;

			# Ignore the request currently being processed and any complete requests
			if ($neighbor_reservation_id == $reservation_id) {
				next NEIGHBOR_REQUESTS;
			}

			notify($ERRORS{'DEBUG'}, 0, "checking neighbor request=$neighbor_request_id, reservation=$neighbor_reservation_id, state=$neighbor_state_name, laststate=$neighbor_laststate_name");
			notify($ERRORS{'DEBUG'}, 0, "neighbor start time: $neighbor_request_start ($neighbor_start_diff)");

			# Ignore any complete requests
			if ($neighbor_state_name eq "complete") {
				notify($ERRORS{'OK'}, 0, "neighbor request is complete: id=$neighbor_request_id, state=$neighbor_state_name");
				next NEIGHBOR_REQUESTS;
			}

			# Check for overlapping reservations which user is involved or image is being created
			# Don't check for state = new, it could be a future reservation
			if ($neighbor_state_name =~ /^(maintenance|reserved|inuse|image)$/) {
				notify($ERRORS{'WARNING'}, 0, "detected overlapping reservation on $computer_short_name: req=$neighbor_request_id, res=$neighbor_reservation_id, request state=$neighbor_state_name, laststate=$neighbor_laststate_name, computer state=$computer_state_name");
				return 0;
			}

			# Check for other currently pending requests
			elsif ($neighbor_state_name eq "pending") {

				# Make sure neighbor request process is actually running
				my $neighbor_process_count = checkonprocess($neighbor_laststate_name, $neighbor_request_id);
				if ($neighbor_process_count) {
					notify($ERRORS{'OK'}, 0, "detected neighbor request $neighbor_request_id is active");
				}
				elsif ($neighbor_process_count == 0) {
					notify($ERRORS{'OK'}, 0, "detected neighbor request $neighbor_request_id is NOT active, setting its state to 'complete'");
					# Process was not found, set neighbor request to complete
					if (update_request_state($neighbor_request_id, "complete", $neighbor_laststate_name)) {
						notify($ERRORS{'OK'}, 0, "neighbor request $neighbor_request_id state set to 'complete'");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to set neighbor request $neighbor_request_id state to 'complete'");
					}
					# Check other neighbor requests
					next NEIGHBOR_REQUESTS;
				} ## end elsif ($neighbor_process_count == 0)  [ if ($neighbor_process_count)
				else {
					# Undefined was returned from checkonprocess(), meaning error occurred
					notify($ERRORS{'CRITICAL'}, 0, "error occurred while checking if neighbor request $neighbor_request_id process is running");

					# Wait then try again
					next INUSE_LOOP;
				}

				# Check for state = pending and laststate = new, reserved, inuse, or image
				# Just return 0 for these, don't bother waiting
				if ($neighbor_laststate_name =~ /^(new|reserved|inuse|image)$/) {
					notify($ERRORS{'WARNING'}, 0, "detected overlapping reservation on $computer_short_name: req=$neighbor_request_id, res=$neighbor_reservation_id, request state=$neighbor_state_name, laststate=$neighbor_laststate_name, computer state=$computer_state_name");
					return 0;
				}

				# Neighbor request state is pending and process is actively running
				# Neighbor request state should be deleted|timeout|reload|reclaim
				if ($neighbor_laststate_name !~ /^(deleted|timeout|reload|reclaim)$/) {
					notify($ERRORS{'WARNING'}, 0, "unexpected neighbor request laststate: $neighbor_laststate_name");
				}

				# Computer should be loading
				if (monitorloading($neighbor_reservation_id, $image_name, $computer_id, $computer_short_name, $image_reloadtime)) {
					# Returns 1 if specified image has been successfully loaded
					# Returns 0 if another image is being loaded or if loading fails
					notify($ERRORS{'OK'}, 0, "$image_name should have been loaded on $computer_short_name by reservation $neighbor_reservation_id");

					# Check other neighbor requests
					next NEIGHBOR_REQUESTS;
				}

				# Computer is not being loaded with the correct image or loading failed
				# Take evasive action - recheck on neighbor process
				if (checkonprocess($neighbor_laststate_name, $neighbor_request_id)) {
					notify($ERRORS{'OK'}, 0, "neighbor request=$neighbor_request_id, reservation=$neighbor_reservation_id owning $computer_short_name is not loading correct image or taking too long, attempting to kill process for reservation $neighbor_reservation_id");
					
					# Kill competing neighbor process - set it's state to complete
					if (kill_reservation_process($neighbor_reservation_id)) {
						notify($ERRORS{'OK'}, 0, "killed competing process for reservation $neighbor_reservation_id");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to kill competing process for reservation $neighbor_reservation_id");
					}
				} ## end if (checkonprocess($neighbor_laststate_name...

				# Either neighbor process was not found or competing process was just killed
				# Set neighbor request to complete
				if (update_request_state($neighbor_request_id, "deleted", $neighbor_laststate_name)) {
					notify($ERRORS{'OK'}, 0, "neighbor request $neighbor_request_id state set to 'deleted'");
					# Check other neighbor requests
					next NEIGHBOR_REQUESTS;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to set neighbor request $neighbor_request_id state to 'deleted'");
				}
			} ## end elsif ($neighbor_state_name eq "pending")  [ if ($neighbor_state_name =~ /^(reserved|inuse|image)$/)

			# Check for other requests
			else {
				notify($ERRORS{'OK'}, 0, "neighbor request state is OK: $neighbor_state_name/$neighbor_laststate_name");
			}

		} ## end foreach my $neighbor_request_key (keys %neighbor_requests)

		# Checked all neighbor requests and didn't find any conflicting reservations
		notify($ERRORS{'OK'}, 0, "checked neighbor requests and didn't find any conflicting reservations for $computer_short_name");
		return 1;

	} ## end for (my $inuse_loop_count = 0; $inuse_loop_count...

	# Checked all neighbor requests several times and find something conflicting every time
	notify($ERRORS{'WARNING'}, 0, "$computer_short_name does not appear to be available");
	return 0;

} ## end sub computer_not_being_used

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve_computer

 Parameters  :
 Returns     :
 Description :

=cut

sub reserve_computer {
	my $self = shift;

	my $request_data                    = $self->data->get_request_data();
	my $request_id                      = $self->data->get_request_id();
	my $request_logid                   = $self->data->get_request_log_id();
	my $request_state_name              = $self->data->get_request_state_name();
	my $request_laststate_name          = $self->data->get_request_laststate_name();
	my $request_forimaging              = $self->data->get_request_forimaging();
	my $request_preload_only            = $self->data->get_request_preload_only();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_host_name              = $self->data->get_computer_host_name();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_type                   = $self->data->get_computer_type();
	my $computer_ip_address             = $self->data->get_computer_ip_address();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $computer_preferred_image_id     = $self->data->get_computer_preferredimage_id();
	my $computer_preferred_image_name   = $self->data->get_computer_preferredimage_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_os_name                   = $self->data->get_image_os_name();
	my $image_name                      = $self->data->get_image_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $image_project                   = $self->data->get_image_project();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $image_architecture              = $self->data->get_image_architecture();
	my $image_os_type                   = $self->data->get_image_os_type();
	my $imagemeta_checkuser             = $self->data->get_imagemeta_checkuser();
	my $imagemeta_usergroupid           = $self->data->get_imagemeta_usergroupid();
	my $imagemeta_usergroupmembercount  = $self->data->get_imagemeta_usergroupmembercount();
	my $imagemeta_usergroupmembers      = $self->data->get_imagemeta_usergroupmembers();
	my $imagerevision_id                = $self->data->get_computer_imagerevision_id();
	my $managementnode_id               = $self->data->get_management_node_id();
	my $managementnode_hostname         = $self->data->get_management_node_hostname();
	my $user_unityid                    = $self->data->get_user_login_id();
	my $user_uid                        = $self->data->get_user_uid();
	my $user_preferredname              = $self->data->get_user_preferred_name();
	my $user_affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_standalone                 = $self->data->get_user_standalone();
	my $user_email                      = $self->data->get_user_email();
	my $user_emailnotices               = $self->data->get_user_emailnotices();
	my $user_imtype_name                = $self->data->get_user_imtype_name();
	my $user_im_id                      = $self->data->get_user_im_id();

	notify($ERRORS{'OK'}, 0, "user_standalone=$user_standalone, image OS type=$image_os_type");

	my ($mailstring, $subject, $r);

	# check for deletion
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "user has deleted, quietly exiting");
		#return 0 and let process routine handle reset computer state
		return 0;
	}

	if ($computer_type =~ /blade|virtualmachine/) {
		# if dynamicDHCP update or dble check address in table
		#ipconfiguration
		if ($IPCONFIGURATION ne "manualDHCP") {
			#not default setting
			if ($IPCONFIGURATION eq "dynamicDHCP") {
				my $assignedIPaddress = getdynamicaddress($computer_short_name, $image_os_name,$image_os_type);

				if ($assignedIPaddress) {
					#$IPaddressforlog = $assignedIPaddress;
					#update computer table
					if (update_computer_address($computer_id, $assignedIPaddress)) {
						notify($ERRORS{'OK'}, 0, "dynamic address collect $assignedIPaddress -- updating computer table");
					}
					#change our local and hash variables
					$self->data->set_computer_ip_address($assignedIPaddress);
					$computer_ip_address = $assignedIPaddress;
				} ## end if ($assignedIPaddress)
				else {
					notify($ERRORS{'CRITICAL'}, 0, "could not fetch dynamic address from $computer_short_name $image_name");
					insertloadlog($reservation_id, $computer_id, "failed", "node problem could not collect IP address form $computer_short_name");
					return 0;
				}
			} ## end if ($IPCONFIGURATION eq "dynamicDHCP")
		} ## end if ($IPCONFIGURATION ne "manualDHCP")


		insertloadlog($reservation_id, $computer_id, "info", "node ready adding user account");

		if ($image_os_type =~ /windows/ || ($image_os_type =~ /linux/ && $user_standalone)) {
			# Get a random password
			my $reservation_password = getpw();

			# Update pw in reservation table
			if (update_request_password($reservation_id, $reservation_password)) {
				notify($ERRORS{'OK'}, 0, "updated password entry reservation_id $reservation_id");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to update password entry reservation_id $reservation_id");
			}
			
			# Set the password in the DataStructure object
			$self->data->set_reservation_password($reservation_password);
			
			# Check if OS module had implemented a reserve() subroutine
			# This is only true for modularized OS modules
			if ($self->os->can('reserve')) {
				# Call the OS module's reserve() subroutine
				notify($ERRORS{'DEBUG'}, 0, "calling OS module's reserve() subroutine");
				if ($self->os->reserve()) {
					notify($ERRORS{'DEBUG'}, 0, "OS module successfully reserved resources for this reservation");
				}
				else {
					$self->reservation_failed("OS module failed to reserve resources for this reservation");
				}
			}
			
			# Windows Vista reservation tasks
			# Much of this subroutine will be rearranged once other OS's are modularized
			elsif ($image_os_name =~ /winvista/) {
				if ($request_forimaging) {
					# Set the Administrator password
					notify($ERRORS{'OK'}, 0, "attempting to set Administrator password to $reservation_password on $computer_short_name");
					if (!$self->os->set_password('Administrator', $reservation_password)) {
						notify($ERRORS{'WARNING'}, 0, "reserve computer failed: unable to set password for administrator account on $computer_short_name");
						return 0;
					}
				}
				else {
					# Add the users to the computer
					# OS add_users() subroutine will add the primary reservation user and any imagemeta group users
					notify($ERRORS{'OK'}, 0, "attempting to add users to $computer_short_name");
					if (!$self->os->add_users()) {
						notify($ERRORS{'WARNING'}, 0, "reserve computer failed: unable to add users to $computer_short_name");
						return 0;
					}
				}
			}

			elsif ($image_os_type =~ /windows/ && $request_forimaging) {
				if (changewindowspasswd($computer_short_name, "administrator", $reservation_password)) {
					notify($ERRORS{'OK'}, 0, "password changed for administrator account on $computer_short_name to $reservation_password");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "unable to change password for administrator account on $computer_short_name to $reservation_password");
					return 0;
				}
			}
			elsif ($image_os_type =~ /windows/) {
				# Add user to computer
				# Linux user addition is handled in reserve.pm
				notify($ERRORS{'OK'}, 0, "attempting to add user $user_unityid to $computer_short_name");
				insertloadlog($reservation_id, $computer_id, "addinguser", "adding user account $user_unityid");

				# Add the request user to the computer
				if (add_user($computer_short_name, $user_unityid, $user_uid, $reservation_password, $computer_host_name, $image_os_name,$image_os_type, 0, 0, 0)) {
					notify($ERRORS{'OK'}, 0, "user $user_unityid added to $computer_short_name");
				}
				else {
					# check for deletion
					if (is_request_deleted($request_id)) {
						notify($ERRORS{'OK'}, 0, "unable to add user $user_unityid to $computer_short_name due to deleted requested ");
						#return 0 and let process routine handle reset computer state
						return 0;
					}
					notify($ERRORS{'CRITICAL'}, 0, "unable to add user $user_unityid to $computer_short_name");
					return 0;
				} ## end else [ if (add_user($computer_short_name, $user_unityid...

				# If imagemeta has user group members, add them to the computer
				if ($imagemeta_usergroupmembercount) {
					notify($ERRORS{'OK'}, 0, "multiple users detected");

					insertloadlog($reservation_id, $computer_id, "info", "multiple user accounts flagged adding additional users");

					if (add_users_by_group($computer_short_name, $reservation_password, $computer_host_name, $image_os_name,$image_os_type, $imagemeta_usergroupmembers)) {
						notify($ERRORS{'OK'}, 0, "successfully added multiple users");
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "failed to add multiple users");
						return 0;
					}
					notify($ERRORS{'OK'}, 0, "users from group $imagemeta_usergroupid added");

				} ## end if ($imagemeta_usergroupmembercount)

			} ## end elsif ($image_os_type =~ /windows/)  [ if ($image_os_type =~ /windows/ && $request_forimaging)
		} ## end if ($image_os_type =~ /windows/ || ($image_os_type...
		elsif ($image_os_type =~ /linux/) {
			if ($user_standalone) {
				# Get a random password
				my $reservation_password = getpw();

				# Update pw in reservation table
				if (update_request_password($reservation_id, $reservation_password)) {
					notify($ERRORS{'OK'}, 0, "updated password entry reservation_id $reservation_id");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "failed to update password entry reservation_id $reservation_id");
				}
			} ## end if ($user_standalone)
		} ## end elsif ($image_os_type =~ /linux/)  [ if ($image_os_type =~ /windows/ || ($image_os_type...
		else {
			notify($ERRORS{'CRITICAL'}, 0, "password set failed, unsupported image OS type: $image_os_type");
			return 0;
		}

		if (!$reservation_is_parent) {
			#sub image; parent handles notification
			return 1;
		}

		# Assemble the message subject based on whether this is a cluster based or normal request
		if ($request_forimaging) {
			$subject = "VCL -- $image_prettyname imaging reservation";
		}
		elsif ($reservation_count > 1) {
			$subject = "VCL -- Cluster-based reservation";
		}
		else {
			$subject = "VCL -- $image_prettyname reservation";
		}

		# Assemble the message body
		if ($request_forimaging) {
			$mailstring = <<"EOF";
$user_preferredname,
The resources for your VCL image creation request have been successfully reserved.

EOF
		}
		else {
			$mailstring = <<"EOF";
$user_preferredname,
The resources for your VCL request have been successfully reserved.

EOF
		}

		# Add the image name and IP address information
		$mailstring .= "Reservation Information:\n";
		foreach $r (keys %{$request_data->{reservation}}) {
			my $reservation_image_name = $request_data->{reservation}{$r}{image}{prettyname};
			my $computer_ip_address    = $request_data->{reservation}{$r}{computer}{IPaddress};
			$mailstring .= "Image Name: $reservation_image_name\n";
			$mailstring .= "IP Address: $computer_ip_address\n\n";
		}

		$mailstring .= <<"EOF";
Connection will not be allowed until you acknowledge using the VCL web interface.  You must acknowledge the reservation within the next 15 minutes or the resources will be reclaimed for other VCL users.

-Visit $user_affiliation_sitewwwaddress
-Select "Current Reservations"
-Click the "Connect" button

Upon acknowledgement, all of the remaining connection details will be displayed.

EOF

		if ($request_forimaging) {
			$mailstring .= <<"EOF";
You have up to 8 hours to complete the new image.  Once you have completed preparing the new image:

-Visit $user_affiliation_sitewwwaddress
-Select "Current Reservations"
-Click the "Create Image" button and follow the instuctions

EOF
		} ## end if ($request_forimaging)

		$mailstring .= <<"EOF";
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
		if ($user_emailnotices) {
			mail($user_email, $subject, $mailstring, $user_affiliation_helpaddress);
		}
		else {
			#just for our email record keeping, might be overkill
			notify($ERRORS{'MAILMASTERS'}, 0, " $user_email\n$mailstring");
		}

		notify($ERRORS{'DEBUG'}, 0, "IMTYPE_name= $user_imtype_name calling notify_via");
		if ($user_imtype_name ne "none") {
			notify_via_IM($user_imtype_name, $user_im_id, $mailstring, $user_affiliation_helpaddress);
		}



	} ## end if ($computer_type =~ /blade|virtualmachine/)

	elsif ($computer_type eq "lab") {
		if ($image_os_name =~ /sun4x_|rhel/) {
			# i can't really do anything here
			# because I need the remoteIP the user
			# will be accessing the machine from
			$subject = "VCL -- $image_prettyname reservation";

			$mailstring = <<"EOF";
$user_preferredname,
A machine with $image_prettyname has been reserved. Use ssh to connect to $computer_ip_address.

Username: your Unity ID
Password: your Unity password

Connection will not be allowed until you acknowledge using the VCL web interface.
-Visit $user_affiliation_sitewwwaddress
-Select Current Reservations
-Click the Connect button to acknowledge


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

			if ($user_emailnotices) {
				#if  "0" user does not care to get additional notices
				mail($user_email, $subject, $mailstring, $user_affiliation_helpaddress);
			}
			else {
				#just for our record keeping
				notify($ERRORS{'MAILMASTERS'}, 0, "$user_email\n$mailstring");
			}
			if ($user_imtype_name ne "none") {
				notify_via_IM($user_imtype_name, $user_im_id, $mailstring, $user_affiliation_helpaddress);
			}
		} ## end if ($image_os_name =~ /sun4x_|rhel/)
		elsif ($image_os_name =~ /realm/) {
			#same as above
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "hrmm found an OS I am not set to handle $image_os_name");
			return 0;
		}
	} ## end elsif ($computer_type eq "lab")  [ if ($computer_type =~ /blade|virtualmachine/)

	#update log table with the IPaddress of the machine
	if (update_sublog_ipaddress($request_logid, $computer_ip_address)) {
		notify($ERRORS{'OK'}, 0, "updated sublog $request_logid for node $computer_short_name IPaddress $computer_ip_address");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "could not update sublog $request_logid for node $computer_short_name IPaddress $computer_ip_address");
	}

	return 1;
} ## end sub reserve_computer

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_child_reservations

 Parameters  :
 Returns     :
 Description :

=cut

sub wait_for_child_reservations {
	my $self              = shift;
	my $request_data      = $self->data->get_request_data();
	my $request_id        = $self->data->get_request_id();
	my $reservation_count = $self->data->get_reservation_count();
	my $reservation_id    = $self->data->get_reservation_id();
	my @reservation_ids   = $self->data->get_reservation_ids();

	# Set limits on how many attempts to make and how long to wait between attempts
	# Wait a long time - 20 minutes
	my $loop_iteration_limit = 40;
	my $loop_iteration_delay = 30;

	WAITING_LOOP: for (my $loop_iteration = 1; $loop_iteration <= $loop_iteration_limit; $loop_iteration++) {
		if ($loop_iteration > 1) {
			notify($ERRORS{'OK'}, 0, "waiting for $loop_iteration_delay seconds");
			sleep $loop_iteration_delay;
		}

		# Check if request has been deleted
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to 'available' and exiting");

			# Update state of computer and exit
			switch_state($request_data, '', 'available', '', '1');
		}

		# Check if all of the reservations are ready according to the computerloadlog table
		my $computerloadlog_reservations_ready = reservations_ready($request_id);
		if ($computerloadlog_reservations_ready) {
			notify($ERRORS{'OK'}, 0, "ready: all child reservations are ready according to computerloadlog, returning 1");
			return 1;
		}
		elsif (defined $computerloadlog_reservations_ready) {
			notify($ERRORS{'OK'}, 0, "not ready: all child reservations are NOT ready according to computerloadlog");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "error occurred checking if child reservations are ready according to computerloadlog");
		}

		notify($ERRORS{'OK'}, 0, "attempt $loop_iteration/$loop_iteration_limit: waiting for child reservations to become ready");

		RESERVATION_LOOP: foreach my $child_reservation_id (@reservation_ids) {
			# Don't bother checking this reservation
			if ($child_reservation_id == $reservation_id) {
				next RESERVATION_LOOP;
			}

			# Get the computer ID of the child reservation
			my $child_computer_id = $request_data->{reservation}{$child_reservation_id}{computer}{id};
			notify($ERRORS{'DEBUG'}, 0, "checking reservation $child_reservation_id: computer ID=$child_computer_id");

			# Get the child reservation's current computer state
			my $child_computer_state = get_computer_current_state_name($child_computer_id);
			notify($ERRORS{'DEBUG'}, 0, "reservation $child_reservation_id: computer state=$child_computer_state");

			# Check child reservation's computer state, is it reserved?
			if ($child_computer_state eq "reserved") {
				notify($ERRORS{'OK'}, 0, "ready: reservation $child_reservation_id computer state is reserved");
			}
			elsif ($child_computer_state eq "reloading") {
				notify($ERRORS{'OK'}, 0, "not ready: reservation $child_reservation_id is still reloading");
				next WAITING_LOOP;
			}
			elsif ($child_computer_state eq "available" && $loop_iteration > 2) {
				# Child computer may still be in the available state if the request start is recent
				# Warn if still in available state after this subroutine has iterated a couple times
				notify($ERRORS{'WARNING'}, 0, "not ready: reservation $child_reservation_id: computer state is still $child_computer_state");
				next WAITING_LOOP;
			}
			elsif ($child_computer_state eq "available") {
				notify($ERRORS{'OK'}, 0, "not ready: reservation $child_reservation_id: reloading has not begun yet");
				next WAITING_LOOP;
			}
			elsif ($child_computer_state =~ /^(failed|maintenance|deleted)$/) {
				notify($ERRORS{'WARNING'}, 0, "abort: reservation $child_reservation_id: computer was put into maintenance, returning");
				return;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unexpected: reservation $child_reservation_id: computer in unexpected state: $child_computer_state");
				next WAITING_LOOP;
			}
		} ## end foreach my $child_reservation_id (@reservation_ids)

		notify($ERRORS{'OK'}, 0, "all child reservations are ready, returning 1");
		return 1;
	} ## end for (my $loop_iteration = 1; $loop_iteration...

	# If out of main loop, waited maximum amount of time
	notify($ERRORS{'WARNING'}, 0, "waited maximum amount of time for child reservations to become ready, returning 0");
	return 0;

} ## end sub wait_for_child_reservations

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 AUTHOR

 Aaron Peeler <aaron_peeler@ncsu.edu>
 Andy Kurth <andy_kurth@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
