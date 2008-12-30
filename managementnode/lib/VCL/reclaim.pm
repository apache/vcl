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
# $Id: reclaim.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

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
	my ($package, $filename, $line, $sub) = caller(0);

	# Store hash variables into local variables
	my $request_data = $self->data->get_request_data;

	my $request_id              = $request_data->{id};
	my $request_state_name      = $request_data->{state}{name};
	my $request_laststate_name  = $request_data->{laststate}{name};
	my $reservation_id          = $request_data->{RESERVATIONID};
	my $reservation_remoteip    = $request_data->{reservation}{$reservation_id}{remoteIP};
	my $computer_type           = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $computer_id             = $request_data->{reservation}{$reservation_id}{computer}{id};
	my $computer_shortname      = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};
	my $computer_hostname       = $request_data->{reservation}{$reservation_id}{computer}{hostname};
	my $computer_ipaddress      = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};
	my $computer_state_name     = $request_data->{reservation}{$reservation_id}{computer}{state}{name};
	my $image_os_name           = $request_data->{reservation}{$reservation_id}{image}{OS}{name};
	my $imagerevision_imagename = $request_data->{reservation}{$reservation_id}{imagerevision}{imagename};
	my $user_unityid            = $request_data->{user}{unityid};
	my $computer_currentimage_name = $self->data->get_computer_currentimage_name();

	# Assemble a consistent prefix for notify messages
	my $notify_prefix = "req=$request_id, res=$reservation_id:";

	# Retrieve next image
	# It's possible the results may not get used based on the state of the reservation 
	my @nextimage;

	if($self->data->can("get_next_image_dataStructure")){
		@nextimage = $self->data->get_next_image_dataStructure();
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix predictor module does not support get_next_image, calling default get_next_image from utils");
		@nextimage = get_next_image_default($computer_id);
	}

	# Assign values to hash for insert reload request
	# Not necessary to change local variables for active image
	$request_data->{reservation}{$reservation_id}{imagerevision}{imagename} = $nextimage[0];
	$request_data->{reservation}{$reservation_id}{image}{id}                = $nextimage[1];
	$request_data->{reservation}{$reservation_id}{imagerevision}{id}        = $nextimage[2];
	$request_data->{reservation}{$reservation_id}{imageid}                  = $nextimage[1];
	$request_data->{reservation}{$reservation_id}{imagerevisionid}          = $nextimage[2];

	my $nextimagename = $nextimage[0];
	notify($ERRORS{'OK'}, 0, "$notify_prefix nextimage results imagename=$nextimage[0] imageid=$nextimage[1] imagerevisionid=$nextimage[2]");


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
		notify($ERRORS{'OK'}, 0, "$notify_prefix request laststate is $request_laststate_name, nothing needs to be done to the computer");
		# Proceed to set request to complete and computer to available
	}

	# Don't attempt to do anything to machines that are currently reloading
	elsif ($computer_state_name =~ /maintenance|reloading/) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix computer in $computer_state_name state, nothing needs to be done to the computer");
		# Proceed to set request to complete
	}

	# Check the computer type
	# Treat blades and virtual machines the same
	#    The request will either be changed to "reload" or they will be cleaned
	#    up based on the OS.
	# Lab computers only need to have sshd disabled.
	
	elsif ($computer_type =~ /blade|virtualmachine/) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix computer type is $computer_type");

		# Check if request laststate is reserved
		# This is the only case where computers will be cleaned and not reloaded
		if ($request_laststate_name =~ /reserved/) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix request laststate is $request_laststate_name, attempting to clean up computer for next user");

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
			
			# Attempt to call modularized OS module's sanitize() subroutine
			# This subroutine should perform all the tasks necessary to sanitize the OS if it was reserved and not logged in to
			if ($self->os->can("sanitize")) {
				notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "::sanitize() subroutine");
				if ($self->os->sanitize()) {
					notify($ERRORS{'OK'}, 0, "OS has been sanitized on $computer_shortname");
				}
				else {
					# OS module's sanitize() subroutine returned false, meaning reload is necessary
					notify($ERRORS{'WARNING'}, 0, "failed to sanitize OS on $computer_shortname, computer will be reloaded");
					$self->insert_reload_and_exit();
				}
			}
			# *** END MODULARIZED OS CODE ***
	
			# Check the image OS type and clean up computer accordingly
			elsif ($image_os_name =~ /^(win|vmwarewin|vmwareesxwin)/) {
				# Loaded Windows image needs to be cleaned up
				notify($ERRORS{'OK'}, 0, "$notify_prefix attempting steps to clean up loaded $image_os_name image");

				# Remove user
				if (del_user($computer_shortname, $user_unityid, $computer_type, $image_os_name)) {
					notify($ERRORS{'OK'}, 0, "$notify_prefix user $user_unityid removed from $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: removed user");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "$notify_prefix could not remove user $user_unityid from $computer_shortname, proceed to forced reload");

					# Insert reload request data into the datbase
					if (insert_reload_request($request_data)) {
						notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id imagename=$nextimagename");

						# Switch the request state to complete, leave the computer state as is
						# Update log ending to EOR
						# Exit
						switch_state($request_data, 'complete', '', 'EOR', '1');
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id imagename=$nextimagename");

						# Switch the request and computer states to failed, log ending to failed, exit
						switch_state($request_data, 'failed', 'failed', 'failed', '1');
					}
					exit;
				} ## end else [ if (del_user($computer_shortname, $user_unityid...

				# Disable RDP
				if (remotedesktopport($computer_shortname, "DISABLE")) {
					notify($ERRORS{'OK'}, 0, "$notify_prefix remote desktop disabled on $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: disabled RDP");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "$notify_prefix remote desktop could not be disabled on $computer_shortname");

					# Insert reload request data into the datbase
					if (insert_reload_request($request_data)) {
						notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id imagename=$nextimagename");

						# Switch the request state to complete, leave the computer state as is, log ending to EOR, exit
						switch_state($request_data, 'complete', '', 'EOR', '1');
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id imagename=$nextimagename");

						# Switch the request and computer states to failed, log ending to failed, exit
						switch_state($request_data, 'failed', 'failed', 'failed', '1');
					}
					exit;
				} ## end else [ if (remotedesktopport($computer_shortname,...

				## Stop Tivoli Monitoring
				#if (system_monitoring($computer_shortname, $imagerevision_imagename, "stop", "ITM")) {
				#	notify($ERRORS{'OK'}, 0, "$notify_prefix ITM monitoring disabled");
				#}
			} ## end if ($image_os_name =~ /^(win|vmwarewin|vmwareesxwin)/)

			elsif ($image_os_name =~ /^(rh[0-9]image|rhel[0-9]|fc[0-9]image|rhfc[0-9]|rhas[0-9])/) {
				# Loaded Linux image needs to be cleaned up
				notify($ERRORS{'OK'}, 0, "$notify_prefix attempting steps to clean up loaded $image_os_name image");

				# Make sure user is not connected
				if (isconnected($computer_shortname, $computer_type, $reservation_remoteip, $image_os_name, $computer_ipaddress)) {
					notify($ERRORS{'WARNING'}, 0, "$notify_prefix user $user_unityid is connected to $computer_shortname, vm will be reloaded");

					# Insert reload request data into the datbase
					if (insert_reload_request($request_data)) {
						notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id imagename=$nextimagename");

						# Switch the request state to complete, leave the computer state as is, set log ending to EOR, exit
						switch_state($request_data, 'complete', '', 'EOR', '1');
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id");

						# Switch the request and computer states to failed, log ending to failed, exit
						switch_state($request_data, 'failed', 'failed', 'failed', '1');
					}
					exit;
				} ## end if (isconnected($computer_shortname, $computer_type...

				# User is not connected, delete the user
				if (del_user($computer_shortname, $user_unityid, $computer_type, $image_os_name)) {
					notify($ERRORS{'OK'}, 0, "$notify_prefix user $user_unityid removed from $computer_shortname");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: removed user");
				}
				else {
					notify($ERRORS{'OK'}, 0, "$notify_prefix user $user_unityid could not be removed from $computer_shortname, vm will be reloaded");

					# Insert reload request data into the datbase
					if (insert_reload_request($request_data)) {
						notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id");

						# Switch the request state to complete, leave the computer state as is, log ending to EOR, exit
						switch_state($request_data, 'complete', '', 'EOR', '1');
					}
					else {
						notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id");

						# Switch the request and computer states to failed, log ending to failed, exit
						switch_state($request_data, 'failed', 'failed', 'failed', '1');
					}
					exit;
				} ## end else [ if (del_user($computer_shortname, $user_unityid...
			} ## end elsif ($image_os_name =~ /^(rh[0-9]image|rhel[0-9]|fc[0-9]image|rhfc[0-9]|rhas[0-9])/) [ if ($image_os_name =~ /^(win|vmwarewin|vmwareesxwin)/)

			else {
				# Unknown image type
				notify($ERRORS{'WARNING'}, 0, "$notify_prefix unsupported image OS detected: $image_os_name, reload will be attempted");

				# Insert reload request data into the datbase
				if (insert_reload_request($request_data)) {
					notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id");

					# Switch the request state to complete, leave the computer state as is, log ending to EOR, exit
					switch_state($request_data, 'complete', '', 'EOR', '1');
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id");

					# Switch the request and computer states to failed, log ending to failed, exit
					switch_state($request_data, 'failed', 'failed', 'failed', '1');
				}
				exit;
			} ## end else [ if ($image_os_name =~ /^(win|vmwarewin|vmwareesxwin)/) [elsif ($image_os_name =~ /^(rh[0-9]image|rhel[0-9]|fc[0-9]image|rhfc[0-9]|rhas[0-9])/)
		} ## end if ($request_laststate_name =~ /reserved/)

		else {
			# Either blade or vm, request laststate is not reserved
			# Computer should be reloaded
			notify($ERRORS{'OK'}, 0, "$notify_prefix request laststate is $request_laststate_name, reload will be attempted");

			# Insert reload request data into the datbase
			if (insert_reload_request($request_data)) {
				notify($ERRORS{'OK'}, 0, "$notify_prefix inserted reload request into database for computer id=$computer_id imagename=$nextimagename");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix failed to insert reload request into database for computer id=$computer_id imagename=$nextimagename");

				# Switch the request and computer states to failed, log ending to failed, exit
				switch_state($request_data, 'failed', 'failed', 'failed', '1');
			}

			# Switch the request state to complete, leave the computer state as is, log ending to EOR, exit
			switch_state($request_data, 'complete', '', 'EOR', '1');

		} ## end else [ if ($request_laststate_name =~ /reserved/)

	} ## end elsif ($computer_type =~ /blade|virtualmachine/) [ if ($request_laststate_name =~ /new/)

	elsif ($computer_type =~ /lab/) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix computer type is $computer_type");

		# Display a warning if laststate is not inuse, or reserved
		#    but still try to clean up computer
		if ($request_laststate_name =~ /inuse|reserved/) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix request laststate is $request_laststate_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$notify_prefix laststate for request is $request_laststate_name, this shouldn't happen");
		}

		# Disable sshd
		if (disablesshd($computer_ipaddress, $user_unityid, $reservation_remoteip, "timeout", $image_os_name)) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix sshd on $computer_shortname $computer_ipaddress has been disabled");
			insertloadlog($reservation_id, $computer_id, "info", "reclaim: disabled sshd");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix unable to disable sshd on $computer_shortname $computer_ipaddress");
			insertloadlog($reservation_id, $computer_id, "info", "reclaim: unable to disable sshd");

			# Attempt to put lab computer in failed state if not already in maintenance
			if ($computer_state_name =~ /maintenance/) {
				notify($ERRORS{'OK'}, 0, "$notify_prefix $computer_shortname in $computer_state_name state, skipping state update to failed");
			}
			else {
				if (update_computer_state($computer_id, "failed")) {
					notify($ERRORS{'OK'}, 0, "$notify_prefix $computer_shortname put into failed state");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: set computer state to failed");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix unable to put $computer_shortname into failed state");
					insertloadlog($reservation_id, $computer_id, "info", "reclaim: unable to set computer state to failed");
				}
			} ## end else [ if ($computer_state_name =~ /maintenance/)
		} ## end else [ if (disablesshd($computer_ipaddress, $user_unityid...
	} ## end elsif ($computer_type =~ /lab/)  [ if ($request_laststate_name =~ /new/)

	# Unknown computer type, this shouldn't happen
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$notify_prefix unsupported computer type: $computer_type, not blade, virtualmachine, or lab");
		insertloadlog($reservation_id, $computer_id, "info", "reclaim: unsupported computer type: $computer_type");
	}

	# Update the request state to complete and exit
	# Set the computer state to available if it isn't in the maintenance or reloading state
	if ($computer_state_name =~ /maintenance|reloading/) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix $computer_shortname in $computer_state_name state, skipping state update to available");
		switch_state($request_data, 'complete', '', '', '1');
	}
	else {
		switch_state($request_data, 'complete', 'available', '', '1');
	}

} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_reload_and_exit

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : 

=cut

sub insert_reload_and_exit {
	my $self = shift;
	my $request_data = $self->data->get_request_data;
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_id = $self->data->get_computer_id();
	
	# Retrieve next image
	my $next_image_name;
	my $next_image_id;
	my $next_imagerevision_id;

	if($self->predictor->can("get_next_image")){
		($next_image_name, $next_image_id, $next_imagerevision_id) = $self->predictor->get_next_image();
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "predictor module does not support get_next_image, calling get_next_image_default");
		($next_image_name, $next_image_id, $next_imagerevision_id) = get_next_image_default($computer_id);
	}

	# Update the DataStructure object with the next image values
	# These will be used by insert_reload_request()
	$self->data->set_image_name($next_image_name);
	$self->data->set_image_id($next_image_id);
	$self->data->set_imagerevision_id($next_imagerevision_id);

	notify($ERRORS{'OK'}, 0, "next image: name=$next_image_name, image id=$next_image_id, imagerevisionid=$next_imagerevision_id");
	
	# Insert reload request data into the datbase
	if (insert_reload_request($request_data)) {
		notify($ERRORS{'OK'}, 0, "inserted reload request into database for computer id=$computer_id, image=$next_image_name");

		# Switch the request state to complete, leave the computer state as is, log ending to EOR, exit
		switch_state($request_data, 'complete', '', 'EOR', '1');
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert reload request into database for computer id=$computer_id image=$next_image_name");

		# Switch the request and computer states to failed, log ending to failed, exit
		switch_state($request_data, 'failed', 'failed', 'failed', '1');
	}
	
	# Make sure this VCL state process exits
	exit;
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

=======
