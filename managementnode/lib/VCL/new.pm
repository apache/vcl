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
 my $request_info = get_request_info->($request_id);

 # Set the reservation ID in the hash
 $request_info->{RESERVATIONID} = $reservation_id;

 # Create a new VCL::new object based on the request information
 my $new = VCL::new->new($request_info);

=head1 DESCRIPTION

 This module supports the VCL "new" state.

=cut

###############################################################################
package VCL::new;

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
use English '-no_match_vars';

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  :
 Returns     :
 Description :

=cut

sub process {
	my $self = shift;
	
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
	my $computer_provisioning_name      = $self->data->get_computer_provisioning_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	
	# If reload state is reload and computer is part of block allocation confirm imagerevisionid is the production image.
	if ($request_state_name eq 'reload' && is_inblockrequest($computer_id)) {
		notify($ERRORS{'OK'}, 0, "request state is '$request_state_name', computer $computer_id is in blockrequest, making sure reservation is assigned production image revision");
		my $imagerev_info = get_production_imagerevision_info($image_id);
		
		unless ($imagerevision_id == $imagerev_info->{id}) {
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
	if ($request_state_name eq 'tovmhostinuse' && ($image_name =~ /noimage/i || $computer_provisioning_name =~ /none/i)) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name will not be reloaded, image: $image_name, provisioning name: $computer_provisioning_name");
	}
	elsif ($self->reload_image()) {
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
		# Needed for computerloadflow	
		insertloadlog($reservation_id, $computer_id, "nodeready", "$computer_short_name is loaded with $image_name (cluster parent)");
		
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
		$self->state_exit(undef, 'available');
	}
	
	my $next_computer_state;
	my $next_request_state;
	
	# Attempt to reserve the computer if this is a 'new' reservation
	# These steps are not done for simple reloads
	notify($ERRORS{'OK'}, 0, "request_state_name= $request_state_name");
	if ($request_state_name =~ /^(new|reinstall)/) {
		
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
	
	# Add nodeready last before process exits, this is used by the cluster parent to determine when child reservations are ready
	# Needed for computerloadflow	
	insertloadlog($reservation_id, $computer_id, "nodeready", "$computer_short_name is loaded with $image_name");
	
	notify($ERRORS{'OK'}, 0, "exiting");
	exit;
} ## end sub process

#//////////////////////////////////////////////////////////////////////////////

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
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $server_request_id               = $self->data->get_server_request_id();
	my $server_request_fixed_ip         = $self->data->get_server_request_fixed_ip();
	
	my $node_status_string;
	insertloadlog($reservation_id, $computer_id, "statuscheck", "checking status of node");
	
	# If request state is 'reinstall' or computer state is 'reload', force reload
	if ($request_state_name eq 'reinstall' || $computer_state_name eq 'reload') {
		$node_status_string = 'reload';
		$computer_state_name = 'reload';
	}
	else {
		$node_status_string = $self->provisioner->node_status() || 'RELOAD';
	}
	
	
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
	}
	elsif ($node_status_string =~ /^post_load/i) {
		notify($ERRORS{'OK'}, 0, "node_status returned '$node_status_string', OS post_load tasks will be performed on $computer_short_name");
		
		# Check if the OS module implements a post_load subroutine
		if ($self->os->can('post_load')) {
			if ($self->os->post_load()) {
				$node_status_string = 'READY';
				
				# Add a line to currentimage.txt indicating post_load has run
				$self->os->set_post_load_status();
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to execute OS module's post_load() subroutine, $computer_short_name will be reloaded");
				$node_status_string = 'POST_LOAD_FAILED';
			}
		}
		else {
			$node_status_string = 'READY';
			notify($ERRORS{'WARNING'}, 0, "provisioning module's node_status subroutine returned '$node_status_string' but OS module " . ref($self->os) . " does not implement a post_load() subroutine, $computer_short_name will not be reloaded");
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
		
		# Make sure the image exists on this management node's local disks
		# Attempt to retrieve it if necessary
		if ($self->provisioner->can("does_image_exist")) {
			notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->provisioner) . "->does_image_exist()");
			
			if ($self->provisioner->does_image_exist($image_name)) {
				notify($ERRORS{'OK'}, 0, "$image_name exists on this management node");
				# Needed for computerloadflow	
				insertloadlog($reservation_id, $computer_id, "doesimageexists", "confirmed image exists");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$image_name does not exist on this management node");
				insertloadlog($reservation_id, $computer_id, "doesimageexists", "confirmed image exists");
				
				# Try to retrieve the image files from another management node
				if ($self->provisioner->can("retrieve_image")) {
					notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->provisioner) . "->retrieve_image()");
					
					if ($self->provisioner->retrieve_image($image_name)) {
						notify($ERRORS{'OK'}, 0, "$image_name was retrieved from another management node");
						# Needed for computerloadflow	
						insertloadlog($reservation_id, $computer_id, "copyfrompartnerMN", "Retrieving image");
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "$image_name does not exist on management node and could not be retrieved");
						insertloadlog($reservation_id, $computer_id, "failed", "requested image does not exist on management node and could not be retrieved");
						$self->reservation_failed("$image_name does not exist unable to retrieve image from another management node", "available");
					}
				} ## end if ($self->provisioner->can("retrieve_image"...
				else {
					notify($ERRORS{'CRITICAL'}, 0, "unable to retrieve image from another management node, retrieve_image() is not implemented by " . ref($self->provisioner));
					insertloadlog($reservation_id, $computer_id, "failed", "failed requested image does not exist on management node, retrieve_image() is not implemented");
					$self->reservation_failed("$image_name does not exist", "available");
				}
			} ## end else [ if ($self->provisioner->does_image_exist($image_name...
		} ## end if ($self->provisioner->can("does_image_exist"...
		else {
			notify($ERRORS{'OK'}, 0, "unable to check if image exists, does_image_exist() not implemented by " . ref($self->provisioner));
		}
		
		# OS currently installed on computer may not be the same type as $self->os
		# Attempt to create a new OS object representing OS currently installed and check if that object implements a 'pre_reload' subroutine
		if ($self->os->is_ssh_responding()) {
			my $computer_current_os = $self->create_current_os_object($computer_id, 1);
			if ($computer_current_os) {
				$computer_current_os->pre_reload();
			}
		}
		
		# Call provisioning module's load() subroutine
		notify($ERRORS{'OK'}, 0, "calling " . ref($self->provisioner) . "->load() subroutine");
		insertloadlog($reservation_id, $computer_id, "info", "calling " . ref($self->provisioner) . "->load() subroutine");
		if ($self->provisioner->load()) {
			# Add a line to currentimage.txt indicating post_load has run
			$self->os->set_post_load_status();
			
			notify($ERRORS{'OK'}, 0, "$image_name was successfully reloaded on $computer_short_name");
			insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "$image_name was successfully reloaded on $computer_short_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$image_name failed to load on $computer_short_name, returning");
			insertloadlog($reservation_id, $computer_id, "loadimagefailed", "$image_name failed to load on $computer_short_name");
			return;
		}
	}
	
	# Update the current image ID in the computer table
	if (update_currentimage($computer_id, $image_id, $imagerevision_id)) {
		notify($ERRORS{'OK'}, 0, "updated computer table for $computer_short_name: currentimageid=$image_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update computer table for $computer_short_name: currentimageid=$image_id");
	}
	
	if ($server_request_id) {
		notify($ERRORS{'DEBUG'}, 0, "  SERVER_REQUEST_ID detected");
		if ($server_request_fixed_ip) {
			notify($ERRORS{'DEBUG'}, 0, "server_request_fixed_ip is set calling update_public_ip_address");
			if (!$self->os->server_request_set_fixed_ip()) {
				notify($ERRORS{'WARNING'}, 0, "failed to update IP address for $computer_short_name");
				insertloadlog($reservation_id, $computer_id, "failed", "unable to set public IP address on $computer_short_name possibly IP address is inuse");
				return;
			}
		}
	}	
	
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub reload_image

#//////////////////////////////////////////////////////////////////////////////

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
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $image_name                      = $self->data->get_image_name();
	my $image_reloadtime                = $self->data->get_image_reload_time();
	my $request_state_name              = $self->data->get_request_state_name();
	
	my $attempt_limit = 24;
	ATTEMPT: for (my $attempt = 1; $attempt <= $attempt_limit; $attempt++) {
		if ($attempt > 2) {
			notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: sleeping 5 seconds before checking if $computer_short_name is not being used");
			sleep_uninterrupted(5);
		}
		
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: checking if $computer_short_name is not being used");
		my $computer_state_name = $self->data->get_computer_state_name();
		
		# Return 0 if computer state is deleted, vmhostinuse
		if ($computer_state_name =~ /^(deleted|vmhostinuse)$/) {
			notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, its state is $computer_state_name");
			return 0;
		}
		
		# Return 0 if computer state is maintenance and request state name is not vmhostinuse
		# Allow computers to go from maintenance directly to a vmhost
		if ($computer_state_name =~ /^(maintenance)$/ && $request_state_name !~ /tovmhostinuse/) {
			notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, its state is $computer_state_name");
			return 0;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "$computer_short_name state is $computer_state_name, checking if any competing reservations are active");
		
		# Check if there is another request using this machine
		# Get a hash containing all of the reservations for the computer
		my $competing_request_info = get_request_by_computerid($computer_id);
		
		# There should be at least 1 request -- the one being processed
		if (!$competing_request_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve any requests for computer $computer_id, there should probably be at least 1");
			next ATTEMPT;
		}
		
		# Loop through the competing requests
		COMPETING_REQUESTS: for my $competing_request_id (sort keys %$competing_request_info) {
			# Ignore the request currently being processed
			next if $competing_request_id == $request_id;
			
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
			if ($competing_request_state =~ /^(image|checkpoint)$/ || $competing_request_laststate =~ /^(image|checkpoint)$/) {
				notify($ERRORS{'WARNING'}, 0, "$computer_short_name is NOT available, it is assigned to an existing imaging reservation:\n$competing_request_info_string");
				next ATTEMPT;
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
			if ($competing_imagerevision_id eq $imagerevision_id &&
				 $competing_request_state =~ /^(pending|reload)$/ &&
				 $competing_request_laststate =~ /(reload)/) {
				notify($ERRORS{'OK'}, 0, "reservation $competing_reservation_id is assigned to $computer_short_name with the same image revision: $image_name, waiting for the other reload process to complete");
				
				my $message = "waiting for reload reservation $competing_request_id:$competing_reservation_id to finish loading $computer_short_name with $image_name";
				
				# Wait at least 5 minutes
				$image_reloadtime = 5 if $image_reloadtime < 10;
				my $total_wait_seconds = (60 * $image_reloadtime);
				my $attempt_delay_seconds = 10;
				
				# Loop until other process is done
				if ($self->code_loop_timeout(sub{return !reservation_being_processed(@_)}, [$competing_reservation_id], $message, $total_wait_seconds, $attempt_delay_seconds)) {
					# Check if reload request finished and was already deleted
					if (is_request_deleted($competing_request_id)) {
						notify($ERRORS{'OK'}, 0, "reload reservation $competing_request_id:$competing_reservation_id is no longer loading $computer_short_name with $image_name, request $competing_request_id has been deleted");
					}
					else {
						# Verified competing 'reload' is not being processed verify it is not stuck in pending/reload
						notify($ERRORS{'DEBUG'}, 0, "reload reservation $competing_request_id:$competing_reservation_id is not loading $computer_short_name with $image_name, checking current state of request $competing_request_id");
						my ($current_competing_request_state, $current_competing_request_laststate) = get_request_current_state_name($competing_request_id);
						if (!defined($current_competing_request_state)) {
							if (is_request_deleted($competing_request_id)) {
								notify($ERRORS{'OK'}, 0, "reload request $competing_request_id:$competing_reservation_id which was loading $computer_short_name with $image_name was just deleted");
							}
						}
						elsif ($current_competing_request_state eq 'pending' && $current_competing_request_laststate eq 'reload') {
							notify($ERRORS{'OK'}, 0, "state of competing reload request $competing_request_id:$competing_reservation_id is $current_competing_request_state/$current_competing_request_laststate, verified it is not being processed, changing state of competing request $competing_request_id to 'complete'");
							update_request_state($competing_request_id, 'complete', 'reload');
						}
					}
					
					# Try again in order to retrieve a current list of competing reservations
					# The list of competing reservations may have changed while waiting
					notify($ERRORS{'OK'}, 0, "making another attempt to retrieve the current list of competing reservations assigned to $computer_short_name");
					
					# It's possible for this condition to be reached on the last attempt, check one more time
					if ($attempt == 5) {
						$attempt_limit++;
					}
					next ATTEMPT;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "reload reservation $competing_reservation_id has NOT finished loading $computer_short_name with $image_name, waited $total_wait_seconds seconds");
				}
			}
			
			# Check if the other reservation assigned to computer end time has been reached
			# -or-
			# Reload reservation -- either for a different image or the previous check loop monitoring the reload process for the same image timed out
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
					notify($ERRORS{'CRITICAL'}, 0, "computer $computer_short_name is NOT available, failed to set request state to 'complete', competing request has NOT been deleted:\n$competing_request_info_string");
					return 0;
				}
				
				# Check if the other reservation is still being processed
				if (my @competing_reservation_pids = reservation_being_processed($competing_reservation_id)) {
					notify($ERRORS{'OK'}, 0, "reservation $competing_reservation_id is currently being processed by PID(s): " . join(', ', @competing_reservation_pids) . ", making sure the process doesn't have any Semaphore objects open before attempting to kill it");
					
					# Check if the competing process owns any semaphores
					# This would indicate it's doing something such as retrieving an image
					# Don't kill it or a partial image may be copied
					my $semaphore_info = get_vcld_semaphore_info();
					for my $semaphore_identifier (keys %$semaphore_info) {
						for my $competing_reservation_pid (@competing_reservation_pids) {
							if ($semaphore_info->{$semaphore_identifier}{reservationid} == $competing_reservation_id && $semaphore_info->{$semaphore_identifier}{pid} == $competing_reservation_pid) {
								notify($ERRORS{'CRITICAL'}, 0, "computer $computer_short_name is NOT available, reservation $competing_reservation_id is still being processed and owns a semaphore with identifier '$semaphore_identifier', not killing the competing process, it may be transferring an image:\n$competing_request_info_string, semaphore info:\n" . format_data($semaphore_info->{$semaphore_identifier}));
								return;
							}
						}
					}
					
					# Kill competing process
					notify($ERRORS{'OK'}, 0, "attempting to kill process of competing reservation $competing_reservation_id assigned to $computer_short_name");
					for my $competing_reservation_pid (@competing_reservation_pids) {
						$self->mn_os->kill_process($competing_reservation_pid);
					}
					
					# Wait for competing process to end before verifying that it was successfully killed
					sleep_uninterrupted(2);
					
					# Verify that the competing reservation process was killed
					if (reservation_being_processed($competing_reservation_id)) {
						notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, failed to kill process for competing reservation, competing reservation is still being processed:\n$competing_request_info_string");
						return 0;
					}
				}
				
				sleep_uninterrupted(5);
				
				# Try again in order to retrieve a current list of competing reservations
				# The list of competing reservations may have changed
				# A new reload reservation may have been added by timeout/deleted processes
				notify($ERRORS{'OK'}, 0, "making another attempt to retrieve the current list of competing reservations assigned to $computer_short_name");
				next ATTEMPT;
			}
			elsif (reservation_being_processed($competing_reservation_id)) {
				notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, assigned overlapping reservations, competing reservation is currently being processed:\n$competing_request_info_string");
				next ATTEMPT;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, assigned overlapping reservations, competing reservation is NOT currently being processed:\n$competing_request_info_string");
				next ATTEMPT;
			}
		}
		
		# Checked all competing requests and didn't find any conflicting reservations
		notify($ERRORS{'OK'}, 0, "$computer_short_name is available, did not find any conflicting reservations");
		return 1;
	}
	
	notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name is NOT available, made $attempt_limit attempts");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reserve_computer

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub reserve_computer {
	my $self = shift;

	my $request_id                      = $self->data->get_request_id();
	my $sublog_id                       = $self->data->get_sublog_id();
	my $reservation_is_parent           = $self->data->is_parent_reservation;
	my $reservation_id                  = $self->data->get_reservation_id();
	my $computer_id                     = $self->data->get_computer_id();
	my $computer_short_name             = $self->data->get_computer_short_name();
	
	# Needed for computerloadflow	
	insertloadlog($reservation_id, $computer_id, "addinguser", "Adding user to $computer_short_name");
	
	# Call OS module's reserve subroutine
	if (!$self->os->reserve()) {
		$self->reservation_failed("OS module failed to reserve resources for this reservation");
		return;
	}
	
	# Check if this is a parent reservation, only the parent reservation handles notifications
	if (!$reservation_is_parent) {
		return 1;
	}
	
	# Retrieve the computer IP address after reserve() is called because it may change
	# Reserve may retrieve a dynamically assigned IP address and should update the DataStructure object
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();
	
	# Update sublog table with the IP address of the machine
	if (!update_sublog_ipaddress($sublog_id, $computer_public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "could not update sublog $sublog_id for node $computer_short_name IP address $computer_public_ip_address");
	}

	# Check if request has been deleted
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to 'available' and exiting");
		$self->state_exit('', 'available');
	}
	
	return 1;
} ## end sub reserve_computer

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_child_reservations

 Parameters  : none
 Returns     : boolean
 Description : Called by the parent reservation if a cluster request is being
               processed. The parent waits for the child reservations to finish
               loading before proceeding to change the request state to
               reserved. Child reservations indicate they are finished loading
               by inserting a 'nodeready' computerloadlog entry.
               
               The parent attempts to detect any changes in child reservations
               by retrieving the reservation.lastupdate values for all children
               as well was all computerloadlog entries. The parent will wait up
               to 20 minutes if no change is detected for any children.

=cut

sub wait_for_child_reservations {
	my $self              = shift;
	
	my $request_id        = $self->data->get_request_id();
	my @reservation_ids   = $self->data->get_reservation_ids();
	my $reservation_count = $self->data->get_reservation_count();
	
	# Set limits on how long to wait
	my $overall_timeout_minutes = 60;
	my $nochange_timeout_minutes = 30;
	my $monitor_delay_seconds = 30;
	
	my $overall_timeout_seconds = ($overall_timeout_minutes * 60);
	my $nochange_timeout_seconds = ($nochange_timeout_minutes * 60);
	
	my $monitor_start_time = time;
	my $last_change_time = $monitor_start_time;
	my $current_time;
	my $nochange_timeout_time = ($monitor_start_time + $nochange_timeout_seconds);
	my $overall_timeout_time = ($monitor_start_time + $overall_timeout_seconds);
	
	my $previous_lastcheck_info;
	my $previous_request_loadstate_names;
	
	MONITOR_LOADING: while (($current_time = time) < $nochange_timeout_time && $current_time < $overall_timeout_time) {
		my $total_elapsed_seconds      = ($current_time - $monitor_start_time);
		my $nochange_elapsed_seconds   = ($current_time - $last_change_time);
		my $nochange_remaining_seconds = ($nochange_timeout_time - $current_time);
		my $overall_remaining_seconds  = ($overall_timeout_time - $current_time);
		
		notify($ERRORS{'DEBUG'}, 0, "waiting for child reservations seconds elapsed/until no change timeout: $nochange_elapsed_seconds/$nochange_remaining_seconds, unconditional timeout: $total_elapsed_seconds/$overall_remaining_seconds");
		
		# Check if request has been deleted
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to 'available' and exiting");
			$self->state_exit('', 'available');
		}
		
		my @reservations_ready;
		my @reservations_not_ready;
		my @reservations_failed;
		my @reservations_lastcheck_changed;
		my @reservations_loadstate_changed;
		my @reservations_unknown;
		
		# Get reservation.lastcheck value for all reservations
		my $current_lastcheck_info = get_current_reservation_lastcheck(@reservation_ids);
		$previous_lastcheck_info = $current_lastcheck_info if !$previous_lastcheck_info;
		
		# Get computerloadlog info for all reservations
		my $current_request_loadstate_names = get_request_loadstate_names($request_id);
		$previous_request_loadstate_names = $current_request_loadstate_names if !$previous_request_loadstate_names;
		
		RESERVATION_ID: for my $reservation_id (@reservation_ids) {
			if (!defined($current_request_loadstate_names->{$reservation_id})) {
				notify($ERRORS{'WARNING'}, 0, "request loadstate info does not contain a key for reservation $reservation_id:\n" . format_data($current_request_loadstate_names));
				next RESERVATION_ID;
			}
			
			my @previous_reservation_loadstate_names = @{$previous_request_loadstate_names->{$reservation_id}};
			my @current_reservation_loadstate_names = @{$current_request_loadstate_names->{$reservation_id}};
			
			if (grep {$_ eq 'failed'} @current_reservation_loadstate_names) {
				push @reservations_failed, $reservation_id;
				next RESERVATION_ID;
			}
			elsif (grep {$_ eq 'nodeready'} @current_reservation_loadstate_names) {
				push @reservations_ready, $reservation_id;
				next RESERVATION_ID;
			}
			elsif (grep {$_ eq 'begin'} @current_reservation_loadstate_names) {
				push @reservations_not_ready, $reservation_id;
			}
			else {
				push @reservations_unknown, $reservation_id;
			}
			
			if ($previous_lastcheck_info->{$reservation_id} ne $current_lastcheck_info->{$reservation_id}) {
				push @reservations_lastcheck_changed, $reservation_id;
			}
			if (scalar(@previous_reservation_loadstate_names) != scalar(@current_reservation_loadstate_names)) {
				push @reservations_loadstate_changed, $reservation_id;
			}
		}
		
		my $ready_count     = scalar @reservations_ready;
		my $not_ready_count = scalar @reservations_not_ready;
		my $unknown_count   = scalar @reservations_unknown;
		my $failed_count    = scalar @reservations_failed;
		
		notify($ERRORS{'DEBUG'}, 0, "current status of reservations:\n" .
			"ready     : $ready_count (" . join(', ', @reservations_ready) . ")\n" .
			"not ready : $not_ready_count (" . join(', ', @reservations_not_ready) . ")\n" .
			"unknown   : $unknown_count (" . join(', ', @reservations_unknown) . ")\n" .
			"failed    : $failed_count (" . join(', ', @reservations_failed) . ")"
		);
		
		if ($failed_count) {
			$self->state_exit('failed', 'available');
		}
		elsif ($ready_count == $reservation_count) {
			notify($ERRORS{'OK'}, 0, "all reservations are ready");
			return 1;
		}
		
		
		# If any changes were detected, reset the nochange timeout
		if (@reservations_lastcheck_changed || @reservations_loadstate_changed) {
			notify($ERRORS{'DEBUG'}, 0, "resetting no change timeout, detected reservation change:\n" .
				"reservation lastcheck changed: (" . join(', ', @reservations_lastcheck_changed) . ")\n" .
				"reservation loadstate changed: (" . join(', ', @reservations_loadstate_changed) . ")"
			);
			$last_change_time = $current_time;
			$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
		}
		
		$previous_request_loadstate_names = $current_request_loadstate_names;
		$previous_lastcheck_info = $current_lastcheck_info;
		
		if ($total_elapsed_seconds <= 30) {
			sleep_uninterrupted(3);
		}
		elsif ($total_elapsed_seconds <= 60) {
			sleep_uninterrupted(5);
		}
		else {
			sleep_uninterrupted($monitor_delay_seconds);
		}
	}
	
	# If out of main loop, waited maximum amount of time
	notify($ERRORS{'WARNING'}, 0, "waited maximum amount of time for all reservations to become ready");
	return;
} ## end sub wait_for_child_reservations

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
