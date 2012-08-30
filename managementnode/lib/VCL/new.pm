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
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

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
	my $request_state_name              = $self->data->get_request_state_name();
	my $request_preload_only            = $self->data->get_request_preload_only();
	my $reservation_count               = $self->data->get_reservation_count();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $computer_next_image_name        = $self->data->get_computer_nextimage_name(0);
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $user_standalone                 = $self->data->get_user_standalone();

	#If reload state is reload and computer is part of block allocation confirm imagerevisionid is the production image.
	if ($request_state_name eq 'reload' && is_inblockrequest($computer_id)) {
		notify($ERRORS{'OK'}, 0, "request state is '$request_state_name', computer $computer_id is in blockrequest, making sure reservation is assigned production image revision");
		my $imagerev_info = get_production_imagerevision_info($image_id);
		
		unless($imagerevision_id == $imagerev_info->{id}){
			notify($ERRORS{'OK'}, 0, "imagerevision_id does not match imagerevision_id= $imagerevision_id imagerev_info $imagerev_info->{id}");	
			$self->data->set_imagerevision_id($imagerev_info->{id});
			$self->data->set_sublog_imagerevisionid($imagerev_info->{id});
			$self->data->set_image_name($imagerev_info->{imagename});
			$self->data->set_imagerevision_revision($imagerev_info->{revision});
			
			# Reset variables in this scope
			$imagerevision_id = $imagerev_info->{id};
			$image_name = $imagerev_info->{imagename};
		}

	}
	
	# Confirm requested computer is available
	if ($self->computer_not_being_used()) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is not being used");
	}
	elsif ($request_state_name eq 'tomaintenance') {
		# Computer is being used
		# Loop until computer is not being used
		
		# Wait a maximum of 3 hours
		my $total_wait_seconds = (60 * 60 * 3);
		
		# Check every 5 minutes
		my $attempt_delay_seconds = (60 * 5);
		
		my $sub_ref = $self->can("computer_not_being_used");
		my $message = "waiting for existing reservations on $computer_short_name to end";
	
		if (!$self->code_loop_timeout($sub_ref, [$self], $message, $total_wait_seconds, $attempt_delay_seconds)) {
			notify($ERRORS{'CRITICAL'}, 0, "$computer_short_name could not be put into maintenance because it is NOT available");
			
			# Return request state back to the original
			if (update_request_state($request_id, 'failed', $request_state_name)) {
				notify($ERRORS{'OK'}, 0, "request state set to 'failed'/'$request_state_name'");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set request state back to 'failed'/'$request_state_name'");
			}
			
			notify($ERRORS{'OK'}, 0, "exiting");
			exit;
		}
	}
	elsif ($request_state_name ne 'new') {
		# Computer is not available, not a new request (most likely a simple reload)
		notify($ERRORS{'WARNING'}, 0, "request state=$request_state_name, $computer_short_name is NOT available");

		# Set the computer next image so it gets loaded if/when other reservations are complete
		if (!defined($computer_next_image_name) || $image_name ne $computer_next_image_name) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name is not available, setting computer next image to $image_name");
			if (setnextimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name next image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name next image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "$computer_short_name is not available, computer next image is already set to $image_name");
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

		# Set the computer next image so it gets loaded if/when other reservations are complete
		if (!defined($computer_next_image_name) || $image_name ne $computer_next_image_name) {
			notify($ERRORS{'OK'}, 0, "preload only request, $computer_short_name is not available, setting computer next image to $image_name");
			if (setnextimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name next image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name next image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "preload only request, $computer_short_name is not available, computer next image is already set to $image_name");
		}

		# Only the parent reservation  is allowed to modify the request state in this module
		if (!$reservation_is_parent) {
			notify($ERRORS{'OK'}, 0, "child preload reservation, computer is not available, states will be changed by the parent, exiting");
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

	# If state is tomaintenance, place machine into maintenance state and set request to complete
	if ($request_state_name =~ /tomaintenance/) {
		notify($ERRORS{'OK'}, 0, "setting computer $computer_short_name state to 'maintenance'");
		
		# Set the computer state to 'maintenance' first
		if (update_computer_state($computer_id, 'maintenance')) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name state set to 'maintenance'");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to set $computer_short_name state to 'maintenance', exiting");
			exit;
		}
		
		if ($self->provisioner->can("post_maintenance_action")) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to perform post maintenance actions for provisioning engine: " . ref($self->provisioner));
			
			if ($self->provisioner->post_maintenance_action()) {
				notify($ERRORS{'OK'}, 0, "post maintenance actions completed $computer_short_name");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to complete post maintenance actions on $computer_short_name");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "post maintenance actions skipped, post_maintenance_action subroutine not implemented by " . ref($self->provisioner));
		}
		
		
		# Update the request state to complete
		# Do not update log.ending for tomaintenance reservations
		if (update_request_state($request_id, 'complete', $request_state_name)) {
			notify($ERRORS{'OK'}, 0, "request state set to 'complete'/'$request_state_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set request state to 'complete'/'$request_state_name'");
		}
		
		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
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
	notify($ERRORS{'OK'}, 0, "request_state_name= $request_state_name");
	if ($request_state_name =~ /^(new|reinstall)/) {
		# Set the computer next image to the one for this reservation
		if (!defined($computer_next_image_name) || $image_name ne $computer_next_image_name) {
			if (setnextimage($computer_id, $image_id)) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name next image set to $image_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name next image to $image_name");
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "$computer_short_name next image is already set to $image_name");
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
			# Don't change state of computer to reserved yet, reserved.pm will do this after it initializes
			# This is done to reduce the delay between when Connect is shown to the user and the firewall is prepared
			$next_computer_state = "";
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
	if ($next_computer_state) {
		if (update_computer_state($computer_id, $next_computer_state)) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name state set to '$next_computer_state'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set $computer_short_name state to '$next_computer_state'");
		}
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

	my $request_state_name              = $self->data->get_request_state_name();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();
	my $image_os_install_type				= $self->data->get_image_os_install_type();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	
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
	
	#If reinstall state - force reload state
	$computer_state_name = 'reload' if ($request_state_name eq 'reinstall');

	if ($computer_state_name eq 'reload') {
		# Always call load() if state is reload regardless of node_status()
		# Admin-initiated reloads will always cause node to be reloaded
		notify($ERRORS{'OK'}, 0, "request state is $request_state_name, node will be reloaded regardless of status");
		$node_status_string = 'reload';
	}

	# Check if the status string returned by node_status = 'ready'
	if ($node_status_string =~ /^ready/i) {
		# node_status returned 'ready'
		notify($ERRORS{'OK'}, 0, "node_status returned '$node_status_string', $computer_short_name will not be reloaded");
		insertloadlog($reservation_id, $computer_id, "nodeready", "node status is $node_status_string, $computer_short_name will not be reloaded");
	}
	
	elsif ($node_status_string =~ /^post_load/i) {
		notify($ERRORS{'OK'}, 0, "node_status returned '$node_status_string', OS post_load tasks will be performed on $computer_short_name");
		
		# Check if the OS module implements a post_load subroutine and that post_load has been run
		if ($self->os->can('post_load')) {
			if ($self->os->post_load()) {
				# Add the vcld_post_load line to currentimage.txt
				$self->os->set_vcld_post_load_status();
				$node_status_string = 'READY';
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to execute OS module's post_load() subroutine, $computer_short_name will be reloaded");
				$node_status_string = 'POST_LOAD_FAILED';
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "provisioning module's node_status subroutine returned '$node_status' but OS module " . ref($self->os) . " does not implement a post_load() subroutine, $computer_short_name will not be reloaded");
		}
	}
	
	# Provisioning module's node_status subroutine did not return 'ready'
	if ($node_status_string !~ /^ready/i) {
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
		
		notify($ERRORS{'OK'}, 0, "node ready: successfully reloaded $computer_short_name with $image_name");
		insertloadlog($reservation_id, $computer_id, "nodeready", "$computer_short_name was reloaded with $image_name");
	}
	
	# Update the current image ID in the computer table
	if (update_currentimage($computer_id, $image_id, $imagerevision_id, $image_id)) {
		notify($ERRORS{'OK'}, 0, "updated computer table for $computer_short_name: currentimageid=$image_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update computer table for $computer_short_name: currentimageid=$image_id");
	}
	
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub reload_image

#/////////////////////////////////////////////////////////////////////////////

=head2 computer_not_being_used

 Parameters  : none
 Returns     : boolean
 Description : Checks if any other reservations are currently using the
               computer.

=cut

sub computer_not_being_used {
	my $self = shift;
	my $request_id                      = $self->data->get_request_id();
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	my $computer_state_name             = $self->data->get_computer_state_name();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $image_name                      = $self->data->get_image_name();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $request_state_name              = $self->data->get_request_state_name();
	
	# Return 0 if computer state is maintenance, deleted, vmhostinuse
	if ($computer_state_name =~ /^(deleted|maintenance|vmhostinuse)$/) {
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, its state is $computer_state_name");
		return 0;
	}
	
	# Warn if computer state isn't available or reload - except for reinstall requests
	if ($request_state_name !~ /^(reinstall)$/ && $computer_state_name !~ /^(available|reload)$/) {
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name state is $computer_state_name, checking if any conflicting reservations are active");
	}
	
	# Check if there is another request using this machine
	# Get a hash containing all of the reservations for the computer
	notify($ERRORS{'OK'}, 0, "retrieving info for reservations assigned to $computer_short_name");
	my $competing_request_info = get_request_by_computerid($computer_id);
	
	# There should be at least 1 request -- the one being processed
	if (!$competing_request_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve any requests for computer id=$computer_id, there should be at least 1");
		return;
	}
	
	# Remove the request currently being processed from the hash
	delete $competing_request_info->{$request_id};
	
	if (!keys(%$competing_request_info)) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is not assigned to any other reservations");
		return 1;
	}
	
	# Loop through the competing requests
	COMPETING_REQUESTS: for my $competing_request_id (sort keys %$competing_request_info) {
		my $competing_reservation_id    = $competing_request_info->{$competing_request_id}{data}->get_reservation_id();
		my $competing_request_state     = $competing_request_info->{$competing_request_id}{data}->get_request_state_name();
		my $competing_request_laststate = $competing_request_info->{$competing_request_id}{data}->get_request_laststate_name();
		my $competing_imagerevision_id  = $competing_request_info->{$competing_request_id}{data}->get_imagerevision_id();
		my $competing_request_start     = $competing_request_info->{$competing_request_id}{data}->get_request_start_time();
		my $competing_request_end       = $competing_request_info->{$competing_request_id}{data}->get_request_end_time();
		
		my $competing_request_start_epoch = convert_to_epoch_seconds($competing_request_start);
		my $competing_request_end_epoch   = convert_to_epoch_seconds($competing_request_end);
		
		my $now_epoch = time;
		
		my $competing_request_info_string;
		$competing_request_info_string .= "request:reservation ID: $competing_request_id:$competing_reservation_id\n";
		$competing_request_info_string .= "request state: $competing_request_state/$competing_request_laststate\n";
		$competing_request_info_string .= "request start time: $competing_request_start\n";
		$competing_request_info_string .= "request end time: $competing_request_end";
		
		notify($ERRORS{'DEBUG'}, 0, "checking reservation assigned to $computer_short_name:\n$competing_request_info_string");
		
		# Check for existing image creation requests
		if ($competing_request_state =~ /^(image)$/ || $competing_request_laststate =~ /^(image)$/) {
			notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, it is assigned to an existing imaging reservation:\n$competing_request_info_string");
			return 0;
		}
		
		# Check for any requests in the maintenance state
		if ($competing_request_state =~ /^(maintenance)$/) {
			notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, it is assigned to an existing request in the '$competing_request_state' state:\n$competing_request_info_string");
			return 0;
		}
		
		# Ignore 'complete', 'failed' requests
		if ($competing_request_state =~ /^(complete|failed)$/) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring request in state: $competing_request_state/$competing_request_laststate");
			next COMPETING_REQUESTS;
		}
		
		# Check if the other reservation assigned to computer hasn't started yet
		if ($competing_request_start_epoch > $now_epoch) {
			# If they overlap, let the other reservation worry about it
			notify($ERRORS{'OK'}, 0, "request $competing_request_id:$competing_reservation_id start time is in the future: $competing_request_start");
			next COMPETING_REQUESTS;
		}
		
		# Check if the other reservation is a 'reload' reservation for the same image revision
		if ($competing_imagerevision_id eq $imagerevision_id && $competing_request_state eq 'pending' && $competing_request_laststate =~ /(reload)/) {
			notify($ERRORS{'OK'}, 0, "reservation $competing_reservation_id is currently loading $computer_short_name with the correct image: $image_name, waiting for the other reload process to complete");
			
			my $message = "reload reservation $competing_request_id:$competing_reservation_id is still loading $computer_short_name with $image_name";
			my $total_wait_seconds = (60 * $image_reloadtime);
			my $attempt_delay_seconds = 30;
			
			# Loop until other process is done
			if ($self->code_loop_timeout(sub{return !reservation_being_processed(@_)}, [$competing_reservation_id], $message, $total_wait_seconds, $attempt_delay_seconds)) {
				notify($ERRORS{'DEBUG'}, 0, "reload reservation $competing_reservation_id finished loading $computer_short_name with $image_name");
				
				# Call this subroutine again in order to retrieve a current list of competing reservations
				# The list of competing reservations may have changed while waiting
				notify($ERRORS{'OK'}, 0, "calling this subroutine again to retrieve the current list of competing reservations assigned to $computer_short_name");
				return $self->computer_not_being_used();
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reload reservation $competing_reservation_id has NOT finished loading $computer_short_name with $image_name, waited $total_wait_seconds seconds");
			}
		}
		
		# Check if the other reservation assigned to computer end time has been reached
		# -or-
		# Reload reservation -- either for a different image or the previous check loop monitoring the reload process for the same image timed out
		# 
		if ($competing_request_end_epoch <= $now_epoch ||
			 ($competing_request_state =~ /(timeout|deleted|reload)/) ||
			 ($competing_request_state eq 'pending' && $competing_request_laststate =~ /(timeout|deleted|reload)/)) {
			
			# Update the competing request state to complete
			# If this fails, check if the competing request has already been deleted
			# Do this before checking if the reservation is being processed to prevent new processes from being created
			if (update_request_state($competing_request_id, "complete", ($competing_request_state eq 'pending') ? $competing_request_laststate : $competing_request_state)) {
				notify($ERRORS{'OK'}, 0, "request state set to 'complete' for competing reservation $competing_reservation_id");
			}
			elsif (is_request_deleted($competing_request_id)) {
				notify($ERRORS{'OK'}, 0, "request state not set to 'complete' for competing reservation $competing_reservation_id because request has been deleted");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, failed to set request state to 'complete', competing request has NOT been deleted:\n$competing_request_info_string");
				return 0;
			}
			
			# Check if the other reservation is still being processed
			if (reservation_being_processed($competing_reservation_id)) {
				notify($ERRORS{'OK'}, 0, "reservation $competing_reservation_id is currently being processed, making sure the process doesn't have any Semaphore objects open before attempting to kill it");
				
				# Create a Semaphore object and check if the competing process owns any of its own Semaphore objects
				# This would indicate it's doing something such as retrieving an image
				# Don't kill it or a partial image may be copied
				my $semaphore = VCL::Module::Semaphore->new();
				if ($semaphore->get_reservation_semaphore_ids($competing_reservation_id)) {
					notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, reservation $competing_reservation_id is still being processed and owns a Semaphore object, not killing the competing process, it may be transferring an image:\n$competing_request_info_string");
					return 0;
				}
				
				# Kill competing process and update request state to complete
				notify($ERRORS{'OK'}, 0, "attempting to kill process of competing reservation $competing_reservation_id assigned to $computer_short_name");
				if (kill_reservation_process($competing_reservation_id)) {
					notify($ERRORS{'OK'}, 0, "killed process for competing reservation $competing_reservation_id");
				}
				
				# Wait for competing process to end before verifying that it was successfully killed
				sleep 2;
				
				# Verify that the competing reservation process was killed
				if (reservation_being_processed($competing_reservation_id)) {
					notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, failed to kill process for competing reservation, competing reservation is still being processed:\n$competing_request_info_string");
					return 0;
				}
			}
			
			# Call this subroutine again in order to retrieve a current list of competing reservations
			# The list of competing reservations may have changed
			# A new reload reservation may have been added by timeout/deleted processes
			notify($ERRORS{'OK'}, 0, "calling this subroutine again to retrieve the current list of competing reservations assigned to $computer_short_name");
			return $self->computer_not_being_used();
		}
		elsif (reservation_being_processed($competing_reservation_id)) {
			notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, assigned overlapping reservations, competing reservation is currently being processed:\n$competing_request_info_string");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, assigned overlapping reservations, competing reservation is NOT currently being processed:\n$competing_request_info_string");
			return 0;
		}
	}
	
	# Checked all competing requests and didn't find any conflicting reservations
	notify($ERRORS{'OK'}, 0, "$computer_short_name is available, did not find any conflicting reservations");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve_computer

 Parameters  :
 Returns     :
 Description :

=cut

sub reserve_computer {
	my $self = shift;

	my $request_data                    = $self->data->get_request_data();
	my $request_state_name              = $self->data->get_request_state_name();
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
	
	notify($ERRORS{'OK'}, 0, "user_standalone=$user_standalone, image OS type=$image_os_type");

	my ($mailstring, $subject, $r);

	# check for deletion
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "user has deleted, quietly exiting");
		#return 0 and let process routine handle reset computer state
		return 0;
	}

	if ($computer_type =~ /blade|virtualmachine/) {
	
		#Confirm public IP address
		if($self->confirm_public_ip_address()) {

		}	
			
		# Update the $computer_ip_address varible in case the IP address was different than what was originally in the database
		#$computer_ip_address = $self->data->get_computer_ip_address();
		
		insertloadlog($reservation_id, $computer_id, "info", "node ready adding user account");
		
		# Only generate new password if:
		# ! reinstall
		# linux and user standalone	
		if ( $request_state_name !~ /^(reinstall)/ ) {
			# Create a random password and update the reservation table unless the reservation if for a Linux non-standalone image
			unless ($image_os_type =~ /linux/ && !$user_standalone) {
				# Create a random password for the reservation
				my $reservation_password = getpw();
			
				# Update the password in the reservation table
				if (update_request_password($reservation_id, $reservation_password)) {
					notify($ERRORS{'DEBUG'}, 0, "updated password in the reservation table");
				}
				else {
					$self->reservation_failed("failed to update password in the reservation table");
				}
			
				# Set the password in the DataStructure object
				$self->data->set_reservation_password($reservation_password);
			}
		}
		
		# Check if OS module implements a reserve() subroutine
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
		
		# Check if this is a parent reservation, only the parent reservation handles notifications
		if (!$reservation_is_parent) {
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
		
		

		# Assemble the message body reservations
		if ($request_forimaging) {
			$mailstring = <<"EOF";

The resources for your VCL image creation request have been successfully reserved.

EOF
		}
		elsif ($request_state_name =~ /^(reinstall)$/) {
			$mailstring = <<"EOF";

Your reservation was successfully reinstalled and you can proceed to reconnect. 
Please revisit the Current reservations page for any additional information.

EOF
		}
		else {
			$mailstring = <<"EOF";

The resources for your VCL request have been successfully reserved.

EOF
		}

		# Add the image name and IP address information
		$mailstring .= "Reservation Information:\n";
		foreach $r (keys %{$request_data->{reservation}}) {
			my $reservation_image_name = $request_data->{reservation}{$r}{image}{prettyname};
			$mailstring .= "Image Name: $reservation_image_name\n";
		}

		if ($request_state_name !~ /^(reinstall)$/) {
                        $mailstring = <<"EOF";

Connection will not be allowed until you acknowledge using the VCL web interface.  You must acknowledge the reservation within the next 15 minutes or the resources will be reclaimed for other VCL users.

EOF
		}

		$mailstring .= <<"EOF";

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

=head2 confirm_public_ip_address

 Parameters  :
 Returns     :
 Description :

=cut

sub confirm_public_ip_address {
	my $self = shift;

	my $computer_short_name             = $self->data->get_computer_short_name();
	my $public_ip_address;
	my $computer_ip_address             = $self->data->get_computer_ip_address();
   my $computer_id                     = $self->data->get_computer_id();
   my $computer_short_name             = $self->data->get_computer_short_name();

	#Try to get public IP address from OS module
	if(!$self->os->can("get_public_ip_address")) {
		 notify($ERRORS{'WARNING'}, 0, "unable to retrieve public IP address from $computer_short_name, OS module " . ref($self) . " does not implement a 'get_public_ip_address' subroutine");
         return;
	}
	elsif ($public_ip_address = $self->os->get_public_ip_address()) {
         notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address from $computer_short_name using the OS module: $public_ip_address");

			# Update the Datastructure and computer table if the retrieved IP address does not match what is in the database
      	if ($computer_ip_address ne $public_ip_address) {
         	$self->data->set_computer_ip_address($public_ip_address);
     
         	if (update_computer_address($computer_id, $public_ip_address)) {
            	notify($ERRORS{'OK'}, 0, "updated dynamic public IP address in computer table for $computer_short_name, $public_ip_address");
         	}    
        	 	else {
            	notify($ERRORS{'WARNING'}, 0, "failed to update dynamic public IP address in computer table for $computer_short_name, $public_ip_address");
            return 0;
         	}    
      	}
   }
   else {
      notify($ERRORS{'WARNING'}, 0, "failed to retrieve dynamic public IP address from $computer_short_name");
		#It might not exist or got droppred
		if (!$self->os->update_public_ip_address()) {
          $self->reservation_failed("failed to update public IP address");
       }
   }
	
	return 1;

}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
