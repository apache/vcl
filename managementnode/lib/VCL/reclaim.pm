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

VCL::reclaim - Perl module for the VCL reclaim state

=head1 SYNOPSIS

 use VCL::reclaim;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::reclaim object based on the request information
 my $reclaim = VCL::reclaim->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "reclaim" state.

=cut

##############################################################################
package VCL::reclaim;

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
 Description : Processes a reservation in the reclaim state. You must pass this
               method a reference to a hash containing request data.

=cut

sub process {
	my $self = shift;
	
	# Store hash variables into local variables
	my $request_data = $self->data->get_request_data;

	my $request_id                 = $self->data->get_request_data();
	my $request_state_name         = $self->data->get_request_state_name();
	my $request_laststate_name     = $self->data->get_request_laststate_name();
	my $reservation_id             = $self->data->get_reservation_id();
	my $reservation_remoteip       = $self->data->get_reservation_remote_ip();
	my $computer_type              = $self->data->get_computer_type();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $computer_hostname          = $self->data->get_computer_host_name();
	my $computer_ipaddress         = $self->data->get_computer_ip_address();
	my $computer_state_name        = $self->data->get_computer_state_name();
	my $image_os_name              = $self->data->get_image_os_name();
	my $image_os_type              = $self->data->get_image_os_type();
	my $imagerevision_imagename    = $self->data->get_image_name();
	my $user_unityid               = $self->data->get_user_login_id();
	my $computer_currentimage_name = $self->data->get_computer_currentimage_name();

	# Insert into computerloadlog if request state = timeout
	if ($request_state_name =~ /timeout|deleted/) {
		insertloadlog($reservation_id, $computer_id, $request_state_name, "reclaim: starting $request_state_name process");
	}
	insertloadlog($reservation_id, $computer_id, "info", "reclaim: request state is $request_state_name");
	insertloadlog($reservation_id, $computer_id, "info", "reclaim: request laststate is $request_laststate_name");
	insertloadlog($reservation_id, $computer_id, "info", "reclaim: computer type is $computer_type");
	insertloadlog($reservation_id, $computer_id, "info", "reclaim: computer OS is $image_os_name");

	# If request laststate = new, nothing needs to be done
	if ($request_laststate_name =~ /new/) {
		notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name, nothing needs to be done to the computer");
		# Proceed to set request to complete and computer to available
	}

	# Don't attempt to do anything to machines that are currently reloading
	elsif ($computer_state_name =~ /maintenance|reloading/) {
		notify($ERRORS{'OK'}, 0, "computer in $computer_state_name state, nothing needs to be done to the computer");
		# Proceed to set request to complete
	}

	# Check the computer type
	# Treat blades and virtual machines the same
	# Either a reload request will be inserted or the node will be sanitized
	# Lab computers only need to have sshd disabled.
	
	elsif ($computer_type =~ /blade|virtualmachine/) {
		notify($ERRORS{'DEBUG'}, 0, "computer type is $computer_type");

		# Check if request laststate is reserved - computer should be sanitized and not reloaded because user did not log on
		if ($request_laststate_name =~ /reserved/) {
			notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name, attempting to sanitize computer");

			# *** BEGIN MODULARIZED OS CODE ***
			# Attempt to get the name of the image currently loaded on the computer
			# This should match the computer table's current image
			if ($self->os->can("get_current_image_name")) {
				notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "::get_current_image_name() subroutine");
				my $current_image_name;
				if ($current_image_name = $self->os->get_current_image_name()) {
					notify($ERRORS{'OK'}, 0, "retrieved name of image currently loaded on $computer_shortname: $current_image_name");
				}
				else {
					# OS module's get_current_image_name() subroutine returned false, reload is necessary
					notify($ERRORS{'WARNING'}, 0, "failed to retrieve name of image currently loaded on $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}
				
				# Make sure the computer table's current image name matches what's on the computer
				if ($current_image_name eq $computer_currentimage_name) {
					notify($ERRORS{'OK'}, 0, "computer table current image name ($computer_currentimage_name) matches OS's current image name ($current_image_name)");
				}
				else {
					# Computer table current image name does not match current image, reload is necessary
					notify($ERRORS{'WARNING'}, 0, "computer table current image name (" . string_to_ascii($computer_currentimage_name) . ") does not match OS's current image name (" . string_to_ascii($current_image_name) . "), computer will be reloaded");
					$self->insert_reload_and_exit();
				}
			}
			
			# Attempt to call OS module's sanitize() subroutine
			# This subroutine should perform all the tasks necessary to sanitize the OS if it was reserved and not logged in to
			if ($self->os->can("sanitize")) {
				notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "::sanitize() subroutine");
				if ($self->os->sanitize()) {
					notify($ERRORS{'OK'}, 0, "$computer_shortname has been sanitized");
				}
				else {
					# OS module's sanitize() subroutine returned false, meaning reload is necessary
					notify($ERRORS{'WARNING'}, 0, "failed to sanitize $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}
			}
			# *** END MODULARIZED OS CODE ***
	
			# Check the image OS type and clean up computer accordingly
			# This whole section should be removed once the original Windows.pm is replaced by Windows_mod.pm
			elsif ($image_os_type =~ /windows/) {
				# Loaded Windows image needs to be cleaned up
				notify($ERRORS{'DEBUG'}, 0, "attempting steps to clean up loaded $image_os_name image");

				# Remove user
				if (del_user($computer_shortname, $user_unityid, $computer_type, $image_os_name,$image_os_type)) {
					notify($ERRORS{'OK'}, 0, "user $user_unityid removed from $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: removed user");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "could not remove user $user_unityid from $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}

				# Disable RDP
				if (remotedesktopport($computer_shortname, "DISABLE")) {
					notify($ERRORS{'OK'}, 0, "remote desktop disabled on $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: disabled RDP");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "remote desktop could not be disabled on $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}
			}

			elsif ($image_os_type =~ /linux/){
				# Loaded Linux image needs to be cleaned up
				notify($ERRORS{'OK'}, 0, "attempting steps to clean up loaded $image_os_name image");

				# Make sure user is not connected
				if (isconnected($computer_shortname, $computer_type, $reservation_remoteip, $image_os_name, $computer_ipaddress, $image_os_type)) {
					notify($ERRORS{'WARNING'}, 0, "user $user_unityid is connected to $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				} ## end if (isconnected($computer_shortname, $computer_type...

				# User is not connected, delete the user
				if (del_user($computer_shortname, $user_unityid, $computer_type, $image_os_name)) {
					notify($ERRORS{'OK'}, 0, "user $user_unityid removed from $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: removed user");
				}
				else {
					notify($ERRORS{'OK'}, 0, "user $user_unityid could not be removed from $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}
			}

			else {
				# Unknown image type
				notify($ERRORS{'WARNING'}, 0, "unsupported image OS detected: $image_os_name, computer will be reloaded");
				$self->insert_reload_and_exit();
			}
		}

		else {
			# Either blade or vm and request laststate is not reserved
			# Computer should be reloaded
			notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name, computer will be reloaded");
			$self->insert_reload_and_exit();
		}
	}

	elsif ($computer_type =~ /lab/) {
		notify($ERRORS{'OK'}, 0, "computer type is $computer_type");

		# Display a warning if laststate is not inuse or reserved
		#    but still try to clean up computer
		if ($request_laststate_name =~ /inuse|reserved/) {
			notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "laststate for request is $request_laststate_name, this shouldn't happen");
		}

		# Disable sshd
		if (disablesshd($computer_ipaddress, $user_unityid, $reservation_remoteip, "timeout", $image_os_name)) {
			notify($ERRORS{'OK'}, 0, "sshd on $computer_shortname $computer_ipaddress has been disabled");
			insertloadlog($reservation_id, $computer_id, "info", "reclaim: disabled sshd");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to disable sshd on $computer_shortname $computer_ipaddress");
			insertloadlog($reservation_id, $computer_id, "info", "reclaim: unable to disable sshd");

			# Attempt to put lab computer in failed state if not already in maintenance
			if ($computer_state_name =~ /maintenance/) {
				notify($ERRORS{'OK'}, 0, "$computer_shortname in $computer_state_name state, skipping state update to failed");
			}
			else {
				if (update_computer_state($computer_id, "failed")) {
					notify($ERRORS{'OK'}, 0, "$computer_shortname put into failed state");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: set computer state to failed");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "unable to put $computer_shortname into failed state");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: unable to set computer state to failed");
				}
			}
		}
	}

	# Unknown computer type, this shouldn't happen
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unsupported computer type: $computer_type, not blade, virtualmachine, or lab");
		insertloadlog($reservation_id, $computer_id, "info", "reclaim: unsupported computer type: $computer_type");
	}

	# Update the request state to complete and exit
	# Set the computer state to available if it isn't in the maintenance or reloading state
	if ($computer_state_name =~ /maintenance|reloading/) {
		notify($ERRORS{'OK'}, 0, "$computer_shortname in $computer_state_name state, skipping state update to available");
		switch_state($request_data, 'complete', '', '', '1');
	}
	else {
		switch_state($request_data, 'complete', 'available', '', '1');
	}

} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_reload_and_exit

 Parameters  : Reference to state object
 Returns     : Nothing, process always exits
 Description : -Retrieves the next image to be loaded on the computer based on a predictive loading algorithm
					-Inserts a new reload request for the predicted image on the computer
					-Sets the state of the request being processed to complete
					-Sets the state of the computer to reload

=cut

sub insert_reload_and_exit {
	my $self = shift;
	my $request_data               = $self->data->get_request_data;
	my $computer_id                = $self->data->get_computer_id();
	my $computer_host_name         = $self->data->get_computer_hostname();
	
	# Retrieve next image
	my ($next_image_name, $next_image_id, $next_imagerevision_id) = $self->data->get_next_image_dataStructure();
	if (!$next_image_name || !$next_image_id || !$next_imagerevision_id) {
		notify($ERRORS{'WARNING'}, 0, "predictor module did not return required information, calling get_next_image_default from utils");
		($next_image_name, $next_image_id, $next_imagerevision_id) = get_next_image_default($computer_id);
	}

	# Update the DataStructure object with the next image values
	# These will be used by insert_reload_request()
	$self->data->set_image_name($next_image_name);
	$self->data->set_image_id($next_image_id);
	$self->data->set_imagerevision_id($next_imagerevision_id);

	notify($ERRORS{'OK'}, 0, "next image: $next_image_name, image id=$next_image_id, imagerevision id=$next_imagerevision_id");
	
	# Insert reload request data into the datbase
	if (insert_reload_request($request_data)) {
		notify($ERRORS{'OK'}, 0, "inserted reload request into database for computer id=$computer_id, image=$next_image_name");

		# Switch the request state to complete, the computer state to reload
		switch_state($request_data, 'complete', 'reload', '', '1');
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert reload request into database for computer id=$computer_id image=$next_image_name");

		# Switch the request and computer states to failed
		switch_state($request_data, 'failed', 'failed', '', '1');
	}
	
	# Make sure this VCL state process exits
	exit;
}

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
