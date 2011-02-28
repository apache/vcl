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

 Parameters  : Reference to state object
 Returns     : Nothing, process always exits
 Description : Processes a reservation in the timeout and deleted states.

=cut

sub process {
	my $self = shift;
	
	# Get required data
	my $request_data                        = $self->data->get_request_data();
	my $reservation_id                      = $self->data->get_reservation_id();
	my $request_state_name                  = $self->data->get_request_state_name();
	my $request_laststate_name              = $self->data->get_request_laststate_name();
	my $computer_id                         = $self->data->get_computer_id();
	my $computer_type                       = $self->data->get_computer_type();
	my $computer_shortname                  = $self->data->get_computer_short_name();
	my $computer_state_name                 = $self->data->get_computer_state_name();
	my $computer_currentimage_name          = $self->data->get_computer_currentimage_name(0);
	
	# Insert into computerloadlog if request state = timeout
	if ($request_state_name =~ /timeout|deleted/) {
		insertloadlog($reservation_id, $computer_id, $request_state_name, "reclaim: starting $request_state_name process");
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning to reclaim $computer_shortname:\nrequest state: $request_state_name\nrequest laststate: $request_laststate_name\ncomputer state: $computer_state_name\ncomputer type: $computer_type");
	
	# Don't attempt to do anything to machines that are currently reloading
	if ($computer_state_name =~ /maintenance|reloading/) {
		notify($ERRORS{'OK'}, 0, "computer in $computer_state_name state, nothing needs to be done to the computer");
	}
	# If request laststate = new, nothing needs to be done
	elsif ($request_laststate_name =~ /new/) {
		notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name, nothing needs to be done to the computer");
	}
	# Lab computers only need to be sanitized (have sshd disabled)
	elsif ($computer_type =~ /lab/) {
		notify($ERRORS{'OK'}, 0, "computer type is $computer_type, computer will be sanitized");
		$self->call_os_sanitize();
	}
	# If request laststate = reserved, user did not log in
	# Make sure image loaded on computer (currentimage.txt) matches what's set in computer.currentimageid
	elsif ($request_laststate_name =~ /reserved/) {
		notify($ERRORS{'DEBUG'}, 0, "request laststate is $request_laststate_name, checking if computer table current image matches image currently loaded on $computer_shortname");
		
		# Make sure computer current image name was retrieved from the database
		if (!$computer_currentimage_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve computer current image name from the database, computer will be reloaded");
			$self->insert_reload_and_exit();
		}
		
		# Reload the computer if unable to retrieve the current image name
		my $os_current_image_name = $self->os->get_current_image_name();
		if (!$os_current_image_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve name of image currently loaded on $computer_shortname, computer will be reloaded");
			$self->insert_reload_and_exit();
		}
		
		# Compare the database current image value with what's on the computer
		if ($computer_currentimage_name eq $os_current_image_name) {
			notify($ERRORS{'OK'}, 0, "computer table current image name ($computer_currentimage_name) matches image name on computer ($os_current_image_name), computer will be sanitized");
			$self->call_os_sanitize();
		}
		else {
			notify($ERRORS{'OK'}, 0, "computer table current image name ($computer_currentimage_name) does NOT match image name on computer ($os_current_image_name), computer will be reloaded");
			$self->insert_reload_and_exit();
		}
	}
	# Request laststate is not reserved, user logged in
	else {
		notify($ERRORS{'OK'}, 0, "request laststate is $request_laststate_name, computer will be reloaded");
		$self->insert_reload_and_exit();
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
	
	notify($ERRORS{'DEBUG'}, 0, "exiting");
	exit;

} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_reload_and_exit

 Parameters  : Reference to state object
 Returns     : Nothing, process always exits
 Description : -Retrieves the next image to be loaded on the computer based on
                a predictive loading algorithm
               -Inserts a new reload request
               -Sets the state of the request being processed to complete
               -Sets the state of the computer to reload

=cut

sub insert_reload_and_exit {
	my $self = shift;
	my $request_data               = $self->data->get_request_data;
	my $computer_id                = $self->data->get_computer_id();
	
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
	
	# Insert reload request data into the database
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
	
	notify($ERRORS{'DEBUG'}, 0, "exiting");
	exit;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 call_os_sanitize

 Parameters  : Reference to state object
 Returns     : If successful: true
               If failed: exits
 Description : Calls the OS module's sanitize subroutine. If sanitize() fails,
               a reload request will be inserted into the database and this
               process will exit.

=cut

sub call_os_sanitize {
	my $self = shift;
	
	# Make sure sanitize() has been implemented by the OS module
	if (!$self->os->can("sanitize")) {
		notify($ERRORS{'WARNING'}, 0, "sanitize subroutine has not been implemented by the " . ref($self->os) . " OS module, computer will be reloaded");
		$self->insert_reload_and_exit();
	}
	
	my $computer_shortname = $self->data->get_computer_short_name();
	
	# Attempt to call OS module's sanitize() subroutine
	# This subroutine should perform all the tasks necessary to sanitize the OS if it was reserved and not logged in to
	notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "::sanitize() subroutine");
	if ($self->os->sanitize()) {
		notify($ERRORS{'OK'}, 0, "$computer_shortname has been sanitized");
	}
	else {
		# OS module's sanitize() subroutine returned false, meaning reload is necessary
		notify($ERRORS{'WARNING'}, 0, "failed to sanitize $computer_shortname, computer will be reloaded");
		$self->insert_reload_and_exit();
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
