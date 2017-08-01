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

VCL::Core::State - VCL state base module

=head1 SYNOPSIS

 use base qw(VCL::Module::State);

=head1 DESCRIPTION

 This is the base module for all of the state objects which are instantiated by
 vcld (new.pm, reserved.pm, etc).

=cut

###############################################################################
package VCL::Module::State;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../..";

# Configure inheritance
use base qw(VCL::Module);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';
use POSIX qw(floor);

use VCL::utils;
use VCL::DataStructure;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Prepares VCL::Module::State objects to process a reservation.
               - Renames the process
               - Updates reservation.lastcheck
               - Creates OS, management node OS, VM host OS (conditional), and
                 provisioner objects
               - If this is a cluster request parent reservation, waits for
                 child reservations to begin
               - Updates request.state to 'pending'

=cut

sub initialize {
	my $self = shift;
	notify($ERRORS{'DEBUG'}, 0, "initializing VCL::Module::State object");
	
	$self->{start_time} = time;
	
	my $request_id = $self->data->get_request_id();
	my $reservation_id = $self->data->get_reservation_id();
	my $request_state_name = $self->data->get_request_state_name();
	my $computer_id = $self->data->get_computer_id();
	my $is_vm = $self->data->get_computer_vmhost_id(0);
	my $is_parent_reservation = $self->data->is_parent_reservation();
	my $reservation_count = $self->data->get_reservation_count();
	my $nathost_id = $self->data->get_nathost_id(0);
	
	# Initialize the database handle count
	$ENV{dbh_count} = 0;
	
	# Attempt to get a database handle
	if ($ENV{dbh} = getnewdbh()) {
		notify($ERRORS{'DEBUG'}, 0, "obtained a database handle for this state process, stored as \$ENV{dbh}");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to obtain a database handle for this state process");
		return;
	}
	
	# Update reservation lastcheck value to prevent processes from being forked over and over if a problem occurs
	my $reservation_lastcheck = update_reservation_lastcheck($reservation_id);
	if ($reservation_lastcheck) {
		$self->data->set_reservation_lastcheck_time($reservation_lastcheck);
	}
	
	# If this is a cluster request, wait for all reservations to begin before proceeding
	if ($reservation_count > 1) {
		if (!$self->wait_for_all_reservations_to_begin('begin', 300, 5)) {
			$self->reservation_failed("failed to detect start of processing for all reservation processes", 'available');
		}
	}
	
	# Parent reservation needs to update the request state to pending
	if ($is_parent_reservation) {
		if ($reservation_count > 1) {
			# Check if any reservations have failed
			if (my @failed_reservation_ids = $self->does_loadstate_exist_any_reservation('failed')) {
				notify($ERRORS{'WARNING'}, 0, "reservations failed: " . join(', ', @failed_reservation_ids));
				$self->state_exit('failed');
			}
		}
		
		# Update the request state to pending for this reservation
		if (!update_request_state($request_id, "pending", $request_state_name)) {
			# Check if request was deleted
			if (is_request_deleted($request_id)) {
				exit;
			}
			
			# Check the current state
			my ($current_request_state, $current_request_laststate) = get_request_current_state_name($request_id);
			if (!$current_request_state) {
				# Request probably complete and already removed
				notify($ERRORS{'DEBUG'}, 0, "current request state could not be retrieved, it was probably completed by another vcld process");
				exit;
			}
			if ($current_request_state =~ /^(deleted|complete)$/ || $current_request_laststate =~ /^(deleted)$/) {
				notify($ERRORS{'DEBUG'}, 0, "current request state: $current_request_state/$current_request_laststate, exiting");
				exit;
			}
			
			$self->reservation_failed("failed to update request state to pending");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "child reservation, not updating request state to 'pending'");
	}
	
	# Set the PID and PPID in the DataStructure
	# These will be wrong if set in get_request_info before the state process is forked
	$self->data->set_process_pid($PID);
	$self->data->set_process_ppid(getppid() || '<unknown>');
	
	# Create an OS object
	if (my $os = $self->create_os_object()) {
		$self->set_os($os);
	}
	else {
		$self->reservation_failed("failed to create OS object");
	}
	
	# Set the os under mn_os to the OS object for the computer being loaded
	# This allows the $self->mn_os object to call $self->os to retrieve the OS object for the computer being loaded
	# This is useful because the DataStructure object changes when mn_os is created and it would otherwise not have access to the original data
	if ($self->mn_os()) {
		$self->mn_os->set_os($self->os);
	}
	
	# Create a VM host OS object if vmhostid is set for the computer
	my $vmhost_os;
	if ($is_vm) {
		$vmhost_os = $self->create_vmhost_os_object();
		if (!$vmhost_os) {
			$self->reservation_failed("failed to create VM host OS object");
		}
		$self->set_vmhost_os($vmhost_os);
	}
	
	# Create a NAT host OS object if computer is mapped to a NAT host
	my $nathost_os;
	if ($nathost_id) {
		$nathost_os = $self->create_nathost_os_object();
		if (!$nathost_os) {
			$self->reservation_failed("failed to create NAT host OS object");
		}
		$self->set_nathost_os($nathost_os);
		
		# Allow the OS object to access the nathost_os object
		# This is necessary to allow the OS code to call the subroutines to forward ports
		$self->os->set_nathost_os($self->nathost_os());
		
		# Allow the NAT host OS object to access the OS object
		# This allows the NAT host OS object to retrieve info about the computer being loaded
		$nathost_os->set_os($self->os());
	}
	
	# Create a provisioning object
	if (my $provisioner = $self->create_provisioning_object()) {
		$self->set_provisioner($provisioner);
		
		# Allow the provisioning object to access the OS object
		$self->provisioner->set_os($self->os());
		
		# Allow the OS object to access the provisioning object
		# This is necessary to allow the OS code to be able to call the provisioning power* subroutines if the OS reboot or shutdown fails
		$self->os->set_provisioner($self->provisioner());
	}
	else {
		$self->reservation_failed("failed to create provisioning object");
	}
	
	# Create a VM host OS object if vmhostid is set for the computer
	if ($is_vm) {
		# Check if provisioning object already has a VM host OS object
		my $provisioner_vmhost_os = $self->provisioner->vmhost_os(0);
		
		if (ref($provisioner_vmhost_os) ne ref($vmhost_os)) {
			$self->set_vmhost_os($provisioner_vmhost_os);
		}
	}
	
	return 1;
} ## end sub initialize

#//////////////////////////////////////////////////////////////////////////////

=head2 user_connected

 Parameters  : none
 Returns     : boolean
 Description : Checks if the user is connected to the computer. If the user
               isn't connected and this is a cluster request, checks if a
               computerloadlog 'connected' entry exists for any of the other
               reservations in cluster.

=cut

sub user_connected {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my $request_id                   = $self->data->get_request_id();
	my @reservation_ids              = $self->data->get_reservation_ids();
	my $reservation_id               = $self->data->get_reservation_id();
	my $reservation_lastcheck        = $self->data->get_reservation_lastcheck_time();
	my $reservation_count            = $self->data->get_request_reservation_count();
	my $computer_id                  = $self->data->get_computer_id();
	my $computer_short_name          = $self->data->get_computer_short_name();
	my $server_request_id            = $self->data->get_server_request_id();
	my $request_duration_epoch_secs  = $self->data->get_request_duration_epoch();
	my $request_duration_hrs         = floor($request_duration_epoch_secs / 60 / 60);
	my $ignore_connections_gte_min   = $self->os->get_timings('ignore_connections_gte');
	my $ignore_connections_gte       = floor($ignore_connections_gte_min / 60);
	
	# Check if the request state changed for any reason
	# This will occur if the user deletes the request, makeproduction is initiated, reboot is initiated, image capture is started
	if ($self->request_state_changed()) {
		$self->state_exit();
	}
	
	# Check if this is a server request, causes process to exit if server request
	if ($server_request_id) {
		notify($ERRORS{'DEBUG'}, 0, "server reservation detected, set as user is connected");
		insertloadlog($reservation_id, $computer_id, "connected", "user connected to $computer_short_name");
		return 1;
	}
	
	# If duration is >= 24 hrs set as connected and return
	if ($request_duration_hrs >= $ignore_connections_gte) {
		notify($ERRORS{'OK'}, 0, "reservation duration is $request_duration_hrs hrs is >= to ignore_connections setting $ignore_connections_gte hrs, skipping inuse checks");
		insertloadlog($reservation_id, $computer_id, "connected", "user connected to $computer_short_name");
		return 1;
	}	

	# Check if the user has connected to the reservation being processed
	if ($self->os->is_user_connected()) {
		insertloadlog($reservation_id, $computer_id, "connected", "user connected to $computer_short_name");
		
		# If this is a cluster request, update the lastcheck value for all reservations
		# This signals the other reservation inuse processes that a connection was detected on another computer
		if ($reservation_count > 1) {
			update_reservation_lastcheck(@reservation_ids);
		}
		return 1;
	}
	
	if ($reservation_count > 1) {
		my $current_reservation_lastcheck = get_current_reservation_lastcheck($reservation_id);
		if ($current_reservation_lastcheck ne $reservation_lastcheck) {
			notify($ERRORS{'DEBUG'}, 0, "user connected to another computer in the cluster, reservation.lastcheck updated since this process began: $reservation_lastcheck --> $current_reservation_lastcheck");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "no connection to another computer in the cluster detected, reservation.lastcheck has not been updated since this process began: $reservation_lastcheck");
		}
	}
	
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 request_state_changed

 Parameters  : none
 Returns     : boolean
 Description : Returns true if the neither current request state changed after
               the process began, including:
               * Request deleted
               * Request deleted and makeproduction initiated
               * Image capture initiated
               * Checkpoint capture initiated
               * Reboot initiated

=cut

sub request_state_changed {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method, reservation failure tasks not attempted, process exiting");
		exit 1;
	}
	
	my $request_id = $self->data->get_request_id();
	my $processing_request_state_name = $self->data->get_request_state_name();
	
	my ($current_state_name, $current_laststate_name) = get_request_current_state_name($request_id);
	if (!$current_state_name || !$current_laststate_name) {
		notify($ERRORS{'WARNING'}, 0, "request $request_id state data could not be retrieved, assuming request is deleted and was removed from the database, returning true");
		return 1;
	}
	elsif (($current_state_name ne 'pending' and $current_state_name ne $processing_request_state_name) ||
		($current_state_name eq 'pending' and $current_laststate_name ne $processing_request_state_name)) {
		notify($ERRORS{'OK'}, 0, "request state changed after this process began: $processing_request_state_name --> $current_state_name/$current_laststate_name, returning true");
		return 1;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "request state has NOT changed after this process began: $processing_request_state_name --> $current_state_name/$current_laststate_name, returning false");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reservation_failed

 Parameters  : $message
 Returns     : exits
 Description : Performs the steps required when a reservation fails:
               - Checks if request was deleted, if so:
                 - Sets computer.state to 'available'
                 - Exits with status 0
               - Inserts 'failed' computerloadlog table entry
               - Updates log.ending to 'failed'
               - Updates computer.state to 'failed'
               - Updates request.state to 'failed', laststate to request's
                 previous state
               - Removes computer from blockcomputers table if this is a block
                 request
               - Exits with status 1

=cut

sub reservation_failed {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method, reservation failure tasks not attempted, process exiting");
		exit 1;
	}

	# Check if a message was passed as an argument
	my $message = shift;
	if (!$message) {
		$message = 'reservation failed';
	}

	# Check if computer needs to be marked as failed
	my $computer_input_state = shift;
   if (!$computer_input_state) {
      $computer_input_state = 0;
   }

	# Get the required data
	my $request_id                  = $self->data->get_request_id();
	my $reservation_id              = $self->data->get_reservation_id();
	my $computer_id                 = $self->data->get_computer_id();
	my $computer_short_name         = $self->data->get_computer_short_name();
	my $request_state_name          = $self->data->get_request_state_name();
	my $request_laststate_name      = $self->data->get_request_laststate_name();
	my $computer_state_name         = $self->data->get_computer_state_name();
	
	# Determine if the failure occurred during initialization
	my $calling_subroutine = get_calling_subroutine();
	my $initialize_failed = 0;
	if ($calling_subroutine =~ /initialize/) {
		$initialize_failed = 1;
	}
	
	# Check if the request has been deleted
	# Ignore if this process's state is deleted
	# If a 'deleted' request fails during initialization and before the request state was changed to 'pending', vcld will try to process over and over again
	if ($request_state_name ne 'deleted' && is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to available and exiting");
		
		# Update the computer state to available
		if ($computer_state_name !~ /^(maintenance)/) {
			if (update_computer_state($computer_id, "available")) {
				notify($ERRORS{'OK'}, 0, "$computer_short_name ($computer_id) state set to 'available'");
			}
			else {
				notify($ERRORS{'OK'}, 0, "failed to set $computer_short_name ($computer_id) state to 'available'");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name ($computer_id) state NOT set to available because the current state is $computer_state_name");
		}
		
		notify($ERRORS{'OK'}, 0, "exiting 0");
		exit 0;
	} ## end if (is_request_deleted($request_id))
	
	
	my $new_request_state_name;
	my $new_computer_state_name;
	my $request_log_ending;
	
	if ($request_state_name =~ /(inuse|reboot|server)/) {
		# Check if the request end time has not been reached
		my $request_end_time_epoch = convert_to_epoch_seconds($self->data->get_request_end_time());
		my $current_time_epoch = time;
		if ($request_end_time_epoch <= $current_time_epoch) {
			# If the end has been reached, set the request state to complete and the computer state to failed
			# This was likely caused by this process failing to initialize all of its module objects
			$new_request_state_name = 'complete';
			$new_computer_state_name = 'failed';
			$request_log_ending = 'EOR';
			notify($ERRORS{'CRITICAL'}, 0, ($initialize_failed ? 'process failed to initialize: ' : '') . "$message, request end time has been reached, setting request state to $new_request_state_name, computer state to $new_computer_state_name");
		}
		else {
			# End time has not been reached, never set inuse requests to failed, set the state back to inuse
			notify($ERRORS{'WARNING'}, 0, ($initialize_failed ? 'process failed to initialize: ' : '') . "$message, setting request and computer states back to 'inuse'");
			$self->state_exit('inuse', 'inuse');
		}
	}
	else {
		# Display the message
		notify($ERRORS{'CRITICAL'}, 0, "reservation failed on $computer_short_name" . ($initialize_failed ? ', process failed to initialize' : '') . ": $message");
		
		if ($request_state_name =~ /(image|checkpoint)/) {
			$new_request_state_name = 'maintenance';
			$new_computer_state_name = 'maintenance';
		}
		elsif ($request_state_name eq 'deleted') {
			$new_request_state_name = 'complete';
			$new_computer_state_name = 'failed';
		}
		elsif ($computer_input_state) {
			$new_request_state_name = 'failed';
			$new_computer_state_name = $computer_input_state;
		}
		else {
			$new_request_state_name = 'failed';
			$new_computer_state_name = 'failed';
		}
	}
	
	if ($request_state_name =~ /^(new|reserved)/) {
		# Update log table ending column to failed for this request
		$request_log_ending = 'failed';
	}
	
	# Insert a row into the computerloadlog table
	if (insertloadlog($reservation_id, $computer_id, "failed", $message)) {
		notify($ERRORS{'OK'}, 0, "inserted computerloadlog 'failed' entry for reservation $reservation_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert computerloadlog entry");
	}
	
	# Check if computer is part of a blockrequest, if so pull out of blockcomputers table
	if (is_inblockrequest($computer_id)) {
		notify($ERRORS{'OK'}, 0, "$computer_short_name in blockcomputers table");
		if (clearfromblockrequest($computer_id)) {
			notify($ERRORS{'OK'}, 0, "removed $computer_short_name from blockcomputers table");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to remove $computer_short_name from blockcomputers table");
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "$computer_short_name is NOT in blockcomputers table");
	}
	
	$self->state_exit($new_request_state_name, $new_computer_state_name, $request_log_ending);
} ## end sub reservation_failed

#//////////////////////////////////////////////////////////////////////////////

=head2 does_loadstate_exist_all_reservations

 Parameters  : $loadstate_name, $ignore_current_reservation (optional)
 Returns     : boolean
 Description : Checks the computerloadlog entries for all reservations belonging
               to the request. True is returned if an entry matching the
               $loadstate_name argument exists for all reservations. The
               $ignore_current_reservation argument may be used to check all
               reservations other than the one currently being processed. This
               may be used by a parent reservation to determine when all child
               reservations have begun to be processed.

=cut

sub does_loadstate_exist_all_reservations {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my $loadstate_name = shift;
	if (!defined($loadstate_name)) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog loadstate name argument was not supplied");
		return;
	}
	
	my $ignore_current_reservation = shift;
	
	my $request_id = $self->data->get_request_id();
	my $request_state = $self->data->get_request_state_name();
	my $reservation_id = $self->data->get_reservation_id();
	
	# Retrieve computerloadlog entries for all reservations
	my $request_loadstate_names = get_request_loadstate_names($request_id);
	if (!$request_loadstate_names) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve request loadstate names");
		return;
	}
	
	my @exists;
	my @does_not_exist;
	for my $check_reservation_id (sort {$a <=> $b} keys %$request_loadstate_names) {
		# Ignore the current reservation
		if ($ignore_current_reservation && $check_reservation_id eq $reservation_id) {
			next;
		}
		
		my @loadstate_names = @{$request_loadstate_names->{$check_reservation_id}};
		if (grep { $_ eq $loadstate_name } @loadstate_names) {
			push @exists, $check_reservation_id;
		}
		else {
			push @does_not_exist, $check_reservation_id;
		}
	}
	
	if (@does_not_exist) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog '$loadstate_name' entry does NOT exist for all reservations:\n" .
			"exists for reservation IDs: " . join(', ',  @exists) . "\n" .
			"does not exist for reservation IDs: " . join(', ',  @does_not_exist)
		);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog '$loadstate_name' entry exists for all reservations");
	}
	
	if (wantarray) {
		return (\@exists, \@does_not_exist);
	}
	else {
		return !scalar(@does_not_exist);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 does_loadstate_exist_any_reservation

 Parameters  : $loadstate_name, $ignore_current_reservation (optional)
 Returns     : array or integer
 Description : Checks the computerloadlog entries for all reservations belonging
               to the request. An array is returned containing reservation IDs
               of any reservations for which have a corresponding
               computerloadlog $loadstate_name entry. The
               $ignore_current_reservation argument may be used to check all
               reservations other than the one currently being processed.

=cut

sub does_loadstate_exist_any_reservation {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my $loadstate_name = shift;
	if (!defined($loadstate_name)) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog loadstate name argument was not supplied");
		return;
	}
	
	my $ignore_current_reservation = shift;
	
	my $request_id = $self->data->get_request_id();
	my $request_state = $self->data->get_request_state_name();
	my $reservation_id = $self->data->get_reservation_id();
	
	# Retrieve computerloadlog entries for all reservations
	my $request_loadstate_names = get_request_loadstate_names($request_id);
	if (!$request_loadstate_names) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve request loadstate names");
		return;
	}
	
	my @exists;
	my @does_not_exist;
	for my $check_reservation_id (keys %$request_loadstate_names) {
		# Ignore the current reservation
		if ($ignore_current_reservation && $check_reservation_id eq $reservation_id) {
			next;
		}
		
		my @loadstate_names = @{$request_loadstate_names->{$check_reservation_id}};
		if (grep { $_ eq $loadstate_name } @loadstate_names) {
			push @exists, $check_reservation_id;
		}
		else {
			push @does_not_exist, $check_reservation_id;
		}
	}
	
	if (@exists) {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog '$loadstate_name' entry exists for reservation:\n" .
			"exists for reservation IDs: " . join(', ', @exists) . "\n" .
			"does not exist for reservation IDs: " . join(', ', @does_not_exist)
		);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computerloadlog '$loadstate_name' entry does NOT exist for any reservation");
	}
	return (wantarray) ? @exists : scalar(@exists);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_all_reservations_to_begin

 Parameters  : $loadstate_name (optional), $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Loops until a computerloadlog entry exists for all child
               reservations matching the loadstate specified by the
               $loadstate_name argument. Returns false if the loop times out.
               Exits if the request has been deleted. The default
               $total_wait_seconds value is 300 seconds. The default
               $attempt_delay_seconds value is 15 seconds.

=cut

sub wait_for_all_reservations_to_begin {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my $loadstate_name = shift;
	if (!$loadstate_name) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog loadstate name argument was not supplied");
		return;
	}
	
	my $total_wait_seconds = shift || 300;
	my $attempt_delay_seconds = shift || 30;
	
	my $request_id = $self->data->get_request_id();
	my $request_state_name = $self->data->get_request_state_name();
	
	my $result = $self->code_loop_timeout(
		sub {
			if ($request_state_name ne 'deleted' && is_request_deleted($request_id)) {
				notify($ERRORS{'OK'}, 0, "request has been deleted, exiting");
				exit;
			}
			
			return $self->does_loadstate_exist_all_reservations($loadstate_name, 1);
		},
		[],
		"waiting for all reservation processes to begin", $total_wait_seconds, $attempt_delay_seconds
	);
	
	if (!$result) {
		my ($exists, $not_exists) = $self->does_loadstate_exist_all_reservations($loadstate_name, 1);
		if (!defined($exists) || !defined($not_exists)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine if all reservation processes have begun, does_loadstate_exist_all_reservations returned a null value");
			return;
		}
		elsif (!ref($exists) || !ref($not_exists) || ref($exists) ne 'ARRAY' || ref($not_exists) ne 'ARRAY') {
			notify($ERRORS{'WARNING'}, 0, "failed to determine if all reservation processes have begun, does_loadstate_exist_all_reservations did not return 2 array references:\n1st item returned:\n" . format_data($exists) . "\n2nd item returned:\n" . format_data($not_exists));
			return;
		}
		
		if (scalar(@$not_exists) == 0) {
			notify($ERRORS{'DEBUG'}, 0, "detected all reservation processes have begun after loop timed out");
			return 1;
		}
		
		my $string = '';
		for my $reservation_id (@$not_exists) {
			my $management_node_hostname = get_reservation_management_node_hostname($reservation_id) || '<unknown>';
			$string .= "$reservation_id: $management_node_hostname\n"
		}
		$string =~ s/\n$//;
		
		notify($ERRORS{'WARNING'}, 0, "failed to determine if processes for the following reservations have begun, computerloadlog '$loadstate_name' entry does not exist:\n$string");
		return;
	}
	
	
	return $result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_reservation_loadstate

 Parameters  : $reservation_id, $loadstate_name, $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Waits for a computerloadlog entry to exist for a particular
               reservation.

=cut

sub wait_for_reservation_loadstate {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my ($reservation_id, $loadstate_name, $total_wait_seconds, $attempt_delay_seconds) = @_;
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog loadstate name argument was not supplied");
		return;
	}
	elsif (!$loadstate_name) {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog loadstate name argument was not supplied");
		return;
	}
	
	$total_wait_seconds = 300 unless defined($total_wait_seconds);
	$attempt_delay_seconds = 30 unless defined($attempt_delay_seconds);
	
	my $request_id = $self->data->get_request_id();
	my $request_state_name = $self->data->get_request_state_name();
	
	my $result = $self->code_loop_timeout(
		sub {
			if ($request_state_name ne 'deleted' && is_request_deleted($request_id)) {
				notify($ERRORS{'OK'}, 0, "request has been deleted, exiting");
				exit;
			}
			return get_reservation_computerloadlog_time($reservation_id, $loadstate_name);
		},
		[],
		"waiting for reservation $reservation_id to generate a $loadstate_name computerloadlog entry", $total_wait_seconds, $attempt_delay_seconds
	);
	
	if ($result) {
		return $result;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "computerloadlog '$loadstate_name' entry does not exist for reservation $reservation_id, waited $total_wait_seconds seconds");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_child_reservations_to_exit

 Parameters  : $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Loops until an 'exited' computerloadlog entry exists for all
               child reservations which also have a 'begin' entry. Returns false
               if the loop times out. The default $total_wait_seconds value is
               300 seconds. The default $attempt_delay_seconds value is 15
               seconds.

=cut

sub wait_for_child_reservations_to_exit {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	my $total_wait_seconds = shift || 300;
	my $attempt_delay_seconds = shift || 15;
	
	my $request_id = $self->data->get_request_id();
	my $request_state_name = $self->data->get_request_state_name();
	
	my $subroutine_name = get_current_subroutine_name();
	
	return $self->code_loop_timeout(
		sub {
			# Commented out - causes problems for cluster requests
			# Example: request deleted while in pending/reserved, waiting for acknowledgement
			# Parent sees state=deleted, and doesn't wait for child reserved processes to exit
			# Parent's deleted/reclaim.pm process starts up
			#   -Parent sees 'begin' entries for the child reservations
			#   -Sets request state to pending/deleted
			#   -reclaim.pm processes are never created for children
			# Child computer state gets left in 'reserved'
			#if (is_request_deleted($request_id)) {
			#	notify($ERRORS{'OK'}, 0, "request has been deleted, exiting");
			#	exit;
			#}
			
			my ($exited, $not_exited) = $self->does_loadstate_exist_all_reservations('exited', 1);
			# If no reservations are missing an 'exited' entry return true
			if (!@$not_exited) {
				notify($ERRORS{'DEBUG'}, 0, "$subroutine_name: computerloadlog 'exited' entry exists for all reservations");
				return 1;
			}
			
			# Some reservations are missing an 'exited' entry
			# Ignore reservations missing both an 'exited' and 'begin' entry
			my ($began, $not_began) = $self->does_loadstate_exist_all_reservations('begin', 1);
			my @began_not_exited = get_array_intersection($began, $not_exited);
			if (@began_not_exited) {
				notify($ERRORS{'DEBUG'}, 0, "$subroutine_name: reservation exists with a computerloadlog 'begin' entry but no 'exited' entry, returning false\n" . join(', ', @began_not_exited));
				return 0;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "$subroutine_name: no reservations have a computerloadlog 'begin' entry but no 'exited' entry, returning true");
				return 1;
			}
		},
		[$self, 'exited', 1],
		"waiting for child reservation processes to exit", $total_wait_seconds, $attempt_delay_seconds
	);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 state_exit

 Parameters  : $request_state_name_new (optional), $computer_state_name_new (optional), $request_log_ending (optional)
 Returns     : none, exits
 Description : Performs common tasks before a reservation process exits and then
               exits.

=cut

sub state_exit {
	my $self = shift;
	if (ref($self) !~ /VCL/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a class method of a VCL object");
		return;
	}
	
	# Set flag to avoid this subroutine from being called more than once
	$ENV{state_exit} = 1;
	
	my ($request_state_name_new, $computer_state_name_new, $request_log_ending) = @_;
	notify($ERRORS{'DEBUG'}, 0, "beginning state module exit tasks, " .
		"request state argument: " . ($request_state_name_new ? $request_state_name_new : '<not specified>') . ', ' .
		"computer state argument: " . ($computer_state_name_new ? $computer_state_name_new : '<not specified>') . ', ' .
		"log ending argument: " . ($request_log_ending ? $request_log_ending : '<not specified>')
	);
	
	
	my $calling_sub = get_calling_subroutine();
	
	my $request_id                 = $self->data->get_request_id();
	my $request_logid              = $self->data->get_request_log_id(0);
	my $reservation_id             = $self->data->get_reservation_id();
	my @reservation_ids            = $self->data->get_reservation_ids();
	my $reservation_count          = $self->data->get_reservation_count();
	my $is_parent_reservation      = $self->data->is_parent_reservation();
	my $request_state_name_old     = $self->data->get_request_state_name();
	my $request_laststate_name_old = $self->data->get_request_laststate_name();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $nathost_hostname           = $self->data->get_nathost_hostname(0);

	if ($is_parent_reservation) {
		# If parent of a cluster request, wait for child processes to exit before switching the state
		if ($reservation_count > 1) {
			# Check frequently if reservation timed out to cause Reservations page to remove the Connect button ASAP
			if ($request_state_name_new && $request_state_name_new =~ /(timeout)/) {
				$self->wait_for_child_reservations_to_exit(300, 3);
			}
			else {
				$self->wait_for_child_reservations_to_exit();
			}
			
			# Check if any reservations failed
			my @failed_reservation_ids = $self->does_loadstate_exist_any_reservation('failed');
			if (@failed_reservation_ids && (!$request_state_name_new || $request_state_name_new ne 'failed')) {
				notify($ERRORS{'OK'}, 0, "another reservation failed, request state will be updated to 'failed'");
				$request_state_name_new = 'failed';
			}
			
			if ($request_state_name_new && $request_state_name_new eq 'failed') {
				# Child reservations will leave the state of the computer to 'reloading' if they didn't fail
				# Need to change state back to available for child reservations which didn't fail
				for my $cluster_reservation_id (@reservation_ids) {
					next if $cluster_reservation_id eq $reservation_id;
					
					my $reservation_data = $self->data->get_reservation_data($cluster_reservation_id) || next;
					my $reservation_computer_id = $reservation_data->get_computer_id() || next;
					my $reservation_computer_hostname = $reservation_data->get_computer_hostname() || next;
					if (!(grep { $_ eq $cluster_reservation_id } @failed_reservation_ids)) {
						notify($ERRORS{'DEBUG'}, 0, "child reservation $cluster_reservation_id did not fail, checking state of computer assigned to reservation: $reservation_computer_id");
						
						my $computer_current_state_name = get_computer_current_state_name($reservation_computer_id) || next;
						if ($computer_current_state_name =~ /(reloading)/) {
							notify($ERRORS{'DEBUG'}, 0, "state of computer $reservation_computer_id assigned to child reservation $cluster_reservation_id is $computer_current_state_name, reservation did not fail, changing state to available");
							update_computer_state($reservation_computer_id, 'available');
						}
						else {
							notify($ERRORS{'DEBUG'}, 0, "state of computer $reservation_computer_id assigned to child reservation $cluster_reservation_id is $computer_current_state_name, reservation did not fail, state of computer will not be changed");
						}
					}
				}
			}
		}
		
		if ($request_state_name_new) {
			# Never set request state to failed if previous state is image
			# Allow pending/checkpoint --> reserved/checkpoint
			if ($request_state_name_old =~ /(image|checkpoint)/ && $request_state_name_new !~ /(reserved|complete|maintenance)/) {
				notify($ERRORS{'CRITICAL'}, 0, "previous request state is $request_state_name_old, not setting request state to $request_state_name_new, setting request and computer state to maintenance");
				$request_state_name_new = 'maintenance';
				$computer_state_name_new = 'maintenance';
			}
			elsif ($request_state_name_old =~ /(inuse|reboot|server)/ && $request_state_name_new !~ /(inuse|timeout|maintenance)/) {
				notify($ERRORS{'CRITICAL'}, 0, "previous request state is $request_state_name_old, not setting request state to $request_state_name_new, setting request and computer state to inuse");
				$request_state_name_new = 'inuse';
				$computer_state_name_new = 'inuse';
			}
		}
	}
	
	
	# If $request_log_ending was passed this should be the end of the reservation
	# If NAT is used, rules added to the NAT host should be removed
	if ($nathost_hostname) {
		my $nat_sanitize_needed = 0;
		if ($request_log_ending) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to sanitize firewall rules created for reservation $reservation_id on NAT host $nathost_hostname, \$request_log_ending argument was specified");
			$nat_sanitize_needed = 1;
		}
		elsif ($request_state_name_new && $request_state_name_new =~ /(timeout|deleted|complete|image|checkpoint|failed)/) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to sanitize firewall rules created for reservation $reservation_id on NAT host $nathost_hostname, next request state is '$request_state_name_new'");
			$nat_sanitize_needed = 1;
		}
		
		if ($nat_sanitize_needed) {
			$self->nathost_os->firewall->nat_sanitize_reservation();
		}
	}
	
	
	# Update the computer state if argument was supplied
	if ($computer_state_name_new) {
		my $computer_state_name_old = $self->data->get_computer_state_name();
		
		if ($computer_state_name_new eq $computer_state_name_old) {
			notify($ERRORS{'DEBUG'}, 0, "state of computer $computer_shortname not updated, already set to $computer_state_name_old");
		}
		elsif (!update_computer_state($computer_id, $computer_state_name_new)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed update state of computer $computer_shortname: $computer_state_name_old->$computer_state_name_new");
		}
	}
	
	
	if ($is_parent_reservation) {
		# Clean computerloadlog as late as possible
		if ($request_state_name_old =~ /(new|reserved)/) {
			# Only delete computerloadlog entries with loadstatename = 'begin' for all reservations in this request
			delete_computerloadlog_reservation(\@reservation_ids, '(begin)');
		}
		else {
			# Delete all computerloadlog entries for all reservations in this request
			delete_computerloadlog_reservation(\@reservation_ids);
		}
		
		# Update log.ending if this is the parent reservation and argument was supplied
		if ($request_logid && $request_log_ending) {
			if (!update_log_ending($request_logid, $request_log_ending)) {
				notify($ERRORS{'CRITICAL'}, 0, "failed to set log ending to $request_log_ending, log ID: $request_logid");
			}
		}
		
		# Update the reservation.lastcheck time to now if the next request state is inuse
		# Do this to ensure that reservations are not processed again quickly after this process exits
		# For cluster requests, the parent may have had to wait a while for child processes to exit
		# Resetting reservation.lastcheck causes reservations to wait the full interval between inuse checks
		if ($request_state_name_new && $request_state_name_new =~ /(reserved|inuse|reboot|server)/) {
			update_reservation_lastcheck(@reservation_ids);
		}
	}
	
	# Insert a computerloadlog 'exited' entry
	# This is used by the parent cluster reservation
	# Do this as late as possible, if request.state is changed to 'complete', vcld may begin processing it before this process exits
	# Warning will be generated if request is deleted before insertloadlog is executed
	insertloadlog($reservation_id, $computer_id, "exited", "vcld process exiting");
	
	
	if ($is_parent_reservation && $request_state_name_new) {	
		# Update the request state
		if ($request_state_name_old ne 'deleted') {
			if (is_request_deleted($request_id)) {
				notify($ERRORS{'OK'}, 0, "request has been deleted, request state not updated: $request_state_name_old --> $request_state_name_new");
			}
			else {
				# Check if the request state has already been updated
				# This can occur if another reservation in a cluster failed
				my ($request_state_name_current, $request_laststate_name_current) = get_request_current_state_name($request_id);
				if ($request_state_name_current eq $request_state_name_new && $request_laststate_name_current eq $request_state_name_old) {
					notify($ERRORS{'OK'}, 0, "request has NOT been deleted, current state already set to: $request_state_name_current/$request_laststate_name_current");
				}
				else {
					notify($ERRORS{'OK'}, 0, "request has NOT been deleted, updating request state: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_state_name_old");
					if (!update_request_state($request_id, $request_state_name_new, $request_state_name_old)) {
						notify($ERRORS{'WARNING'}, 0, "failed to change request state: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_state_name_old");
					}
				}
			}
		}
		else {
			# Current request state = 'deleted', always set the request state to 'complete'
			if (!update_request_state($request_id, 'complete', $request_state_name_old)) {
				notify($ERRORS{'WARNING'}, 0, "failed to change request state: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_state_name_old");
			}
		}
	}
	
	
	# Don't call exit if this was called from DESTROY or else DESTROY gets called again
	if ($calling_sub) {
		if ($calling_sub =~ /DESTROY/) {
			notify($ERRORS{'DEBUG'}, 0, "calling subroutine: $calling_sub, skipping call to exit");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "calling subroutine: $calling_sub, calling exit");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "calling subroutine not defined, calling exit");
	}
	exit;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : exits
 Description : Performs VCL::State module cleanup actions:
               - Removes computerloadlog 'begin' entries for reservation
               - If this is a cluster parent reservation, removes
                 computerloadlog 'begin' entries for all reservations in request
               - Closes the database connection

=cut

sub DESTROY {
	my $self = shift;
	
	my $address = sprintf('%x', $self);
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " destructor called, address: $address");
	
	my $calling_sub = get_calling_subroutine();
	
	# Check if normal module object data is available
	if ($calling_sub && $self && $self->data(0) && !$self->data->is_blockrequest()) {
		if (!$ENV{state_exit}) {
			my $request_id = $self->data->get_request_id();
			my @reservation_ids = $self->data->get_reservation_ids();
			if (@reservation_ids && $request_id) {
				$self->state_exit();
				#notify($ERRORS{'DEBUG'}, 0, "computerloadlog states remaining after process exits:\n" . format_data(get_request_loadstate_names($request_id)));
			}
			elsif (!$SETUP_MODE) {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve the reservation ID, computerloadlog 'begin' rows not removed");
			}
		}
	}
	
	# Uncomment to enable database metrics
	# Print the number of database handles this process created for testing/development
	#if (defined $ENV{dbh_count}) {
	#	notify($ERRORS{'DEBUG'}, 0, "number of database handles state process created: $ENV{dbh_count}");
	#}
	#if (defined $ENV{database_select_count}) {
	#	notify($ERRORS{'DEBUG'}, 0, "database select queries: $ENV{database_select_count}");
	#}
	#if (defined $ENV{database_select_calls}) {
	#	my $database_select_calls_string;
	#	my %hash = %{$ENV{database_select_calls}};
	#	my @sorted_keys = sort { $hash{$b} <=> $hash{$a} } keys(%hash);
	#	for my $key (@sorted_keys) {
	#		$database_select_calls_string .= "$ENV{database_select_calls}{$key}: $key\n";
	#	}
	#	notify($ERRORS{'DEBUG'}, 0, "database select called from:\n$database_select_calls_string");
	#}
	#if (defined $ENV{database_execute_count}) {
	#	notify($ERRORS{'DEBUG'}, 0, "database execute queries: $ENV{database_execute_count}");
	#}

	# Close the database handle
	if (defined $ENV{dbh}) {
		if (!$ENV{dbh}->disconnect) {
			notify($ERRORS{'WARNING'}, 0, "\$ENV{dbh}: database disconnect failed, " . DBI::errstr());
		}
	}

	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	# Determine how long process took to run
	if ($self->{start_time}) {
		my $duration = (time - $self->{start_time});
		notify($ERRORS{'OK'}, 0, ref($self) . " process duration: $duration seconds");
	}
} ## end sub DESTROY

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
