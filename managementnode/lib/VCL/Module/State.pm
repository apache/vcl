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

 Needs to be written.

=cut

##############################################################################
package VCL::Module::State;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../..";

# Configure inheritance
use base qw(VCL::Module);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use VCL::utils;
use VCL::DataStructure;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : Reference to current inuse object is automatically passed when
               invoked as a class method.
 Returns     : 1 if successful, 0 otherwise
 Description : Prepares the delete object to process a reservation. Renames the
               process.

=cut

sub initialize {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# Initialize the database handle count
	$ENV{dbh_count} = 0;

	# Attempt to get a database handle
	if ($ENV{dbh} = getnewdbh()) {
		notify($ERRORS{'DEBUG'}, 0, "obtained a database handle for this state process, stored as \$ENV{dbh}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain a database handle for this state process");
	}

	# Check the image OS before creating OS object
	if (!$self->check_image_os()) {
		notify($ERRORS{'WARNING'}, 0, "failed to check if image OS is correct");
		$self->reservation_failed();
	}

	# Store some hash variables into local variables
	my $request_id                = $self->data->get_request_id();
	my $reservation_id            = $self->data->get_reservation_id();
	my $provisioning_perl_package = $self->data->get_computer_provisioning_module_perl_package();
	my $os_perl_package           = $self->data->get_image_os_module_perl_package();
	#my $predictive_perl_package   = $self->data->get_management_node_predictive_module_perl_package();

	# Store the name of this class in an environment variable
	$ENV{class_name} = ref($self);

	# Rename this process to include some request info
	rename_vcld_process($self->data);

	# Set the PARENTIMAGE and SUBIMAGE keys in the request data hash
	# These are deprecated, DataStructure's is_parent_reservation function should be used
	$self->data->get_request_data->{PARENTIMAGE} = ($self->data->is_parent_reservation() + 0);
	$self->data->get_request_data->{SUBIMAGE}    = (!$self->data->is_parent_reservation() + 0);

	# Set the parent PID and this process's PID in the hash
	set_hash_process_id($self->data->get_request_data);

	# Attempt to load the computer provisioning module
	if ($provisioning_perl_package) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to load provisioning module: $provisioning_perl_package");
		eval "use $provisioning_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$provisioning_perl_package module could not be loaded, returning 0");
			return 0;
		}
		notify($ERRORS{'DEBUG'}, 0, "$provisioning_perl_package module loaded");

		# Create provisioner object
		if (my $provisioner = ($provisioning_perl_package)->new({data_structure => $self->data})) {
			notify($ERRORS{'OK'}, 0, ref($provisioner) . " provisioner object created");
			$self->{provisioner} = $provisioner;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "provisioning object could not be created, returning 0");
			return 0;
		}
	} ## end if ($provisioning_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "provisioning module not loaded, Perl package is not defined");
	}

	# Attempt to load the OS module
	if ($os_perl_package) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to load OS module: $os_perl_package");
		eval "use $os_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$os_perl_package module could not be loaded, returning 0");
			return 0;
		}
		notify($ERRORS{'DEBUG'}, 0, "$os_perl_package module loaded");

		if (my $os = ($os_perl_package)->new({data_structure => $self->data})) {
			notify($ERRORS{'OK'}, 0, ref($os) . " OS object created");
			$self->{os} = $os;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "OS object could not be created, returning 0");
			return 0;
		}
	} ## end if ($os_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "OS module not loaded, Perl package is not defined");
	}
	
	$self->{provisioner}->set_os($self->{os});
	$self->{os}->set_provisioner($self->{provisioner});

	notify($ERRORS{'DEBUG'}, 0, "returning 1");
	return 1;

} ## end sub initialize

#/////////////////////////////////////////////////////////////////////////////

=head2 provisioner

 Parameters  : None
 Returns     : Object's provisioner object
 Description : Returns this objects provisioner object, which is stored in
               $self->{provisioner}.  This method allows it to accessed using
					$self->provisioner.

=cut

sub provisioner {
	my $self = shift;
	return $self->{provisioner};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 os

 Parameters  : None
 Returns     : Object's OS object
 Description : Returns this objects OS object, which is stored in
               $self->{os}.  This method allows it to accessed using
					$self->os.

=cut

sub os {
	my $self = shift;
	return $self->{os};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 predictor

 Parameters  : None
 Returns     : Object's predictive loading object
 Description : Returns this objects predictive loading object, which is stored
               in $self->{predictor}.  This method allows it to accessed using
					$self->predictor.

=cut

sub predictor {
	my $self = shift;
	return $self->{predictor};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reservation_failed

 Parameters  : Message string
 Returns     : Nothing, process exits
 Description : Performs the steps required when a reservation fails:
					-if request was deleted
					   -sets computer state to available
						-exits with status 0
					
					-inserts 'failed' computerloadlog table entry
					-updates ending field in the log table to 'failed'
					-updates the computer state to 'failed'
					-updates the request state to 'failed', laststate to request's previous state
					-removes computer from blockcomputers table if this is a block request
               -exits with status 1

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

	# Get the required data
	my $request_id                  = $self->data->get_request_id();
	my $request_logid               = $self->data->get_request_log_id();
	my $reservation_id              = $self->data->get_reservation_id();
	my $computer_id                 = $self->data->get_computer_id();
	my $computer_short_name         = $self->data->get_computer_short_name();
	my $request_state_name          = $self->data->get_request_state_name();
	my $request_laststate_name      = $self->data->get_request_laststate_name();
	my $computer_state_name         = $self->data->get_computer_state_name();

	# Check if the request has been deleted
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to available and exiting");

		# Update the computer state to available
		if ($computer_state_name !~ /^(maintenance)/){
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

	# Display the message
	notify($ERRORS{'CRITICAL'}, 0, "reservation failed on $computer_short_name: $message");

	# Insert a row into the computerloadlog table
	if (insertloadlog($reservation_id, $computer_id, "failed", $message)) {
		notify($ERRORS{'OK'}, 0, "inserted computerloadlog entry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert computerloadlog entry");
	}
	
	
	if ($request_state_name =~ /^(new|reserved|inuse|image)/){
		# Update log table ending column to failed for this request
		if (update_log_ending($request_logid, "failed")) {
			notify($ERRORS{'OK'}, 0, "updated log ending value to 'failed', logid=$request_logid");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update log ending value to 'failed', logid=$request_logid");
		}
	}

	# Update the computer state to failed as long as it's not currently maintenance
	if ($computer_state_name !~ /^(maintenance)/){
		if (update_computer_state($computer_id, "failed")) {
			notify($ERRORS{'OK'}, 0, "computer $computer_short_name ($computer_id) state set to failed");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computer $computer_short_name ($computer_id) state to failed");
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "computer $computer_short_name ($computer_id) state NOT set to failed because the current state is $computer_state_name");
	}

	# Update the request state to failed
	if (update_request_state($request_id, "failed", $request_laststate_name)) {
		notify($ERRORS{'OK'}, 0, "set request state to 'failed'/'$request_laststate_name'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to set request to 'failed'/'$request_laststate_name'");
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

	notify($ERRORS{'OK'}, 0, "exiting 1");
	exit 1;
} ## end sub reservation_failed

#/////////////////////////////////////////////////////////////////////////////

=head2 update_request_state_new

 Parameters  : 
 Returns     : 1 if successful
               0 if the state was not updated because the state is already maintenance
					undefined if an error occurred
 Description : 

=cut

sub update_request_state_new {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was NOT called as a class method, process exiting");
		exit;
	}
	
	# Get and check the argument
	my $request_state_name_argument = shift;
	if (!$request_state_name_argument) {
		notify($ERRORS{'CRITICAL'}, 0, "new request state name argument was not passed");
		return;
	}
	
	# Get the necessary data from the DataStructure object
	my $request_id = $self->data->get_request_id();
	
	# Retrieve the current states directly from the database
	my $select_state_names_statement = "
	SELECT
	state.name AS state_name,
	laststate.name AS laststate_name
	FROM
	request,
	state state,
	state laststate
	WHERE
	request.id = $request_id
	AND state.id = request.stateid
	AND laststate.id = request.laststateid
	";
	
	# Execute the select statement
	my @selected_rows = database_select($select_state_names_statement);
	
	# Check if row was returned
	if ((scalar @selected_rows) == 0) {
		notify($ERRORS{'WARNING'}, 0, "0 rows returned from request state select statement, request was probably deleted, returning 0");
		return 0;
	}
	
	# Get the state names from the row
	my $request_state_name_old = $selected_rows[0]{state_name};
	my $request_laststate_name_old = $selected_rows[0]{laststate_name};
	
	# Check if request state is maintenance
	if ($request_state_name_old =~ /^(maintenance)$/ || ($request_state_name_old eq 'pending' && $request_laststate_name_old =~ /^(maintenance)$/)) {
		notify($ERRORS{'WARNING'}, 0, "request state not updated because it is already set to $request_state_name_old/$request_laststate_name_old, returning 0");
		return 0;
	}
	
	# Figure out the new states based on what was requested and the current values in the database
	my $request_state_name_new;
	my $request_laststate_name_new;
	
	# If request state name argument is 'pending':
	#   state --> 'pending'
	#   laststate --> previous state
	# If current state is already 'pending', leave states alone
	# Request laststate should never be set to 'pending' (that's useless data)
	if ($request_state_name_argument eq 'pending') {
		if ($request_state_name_old eq 'pending') {
			notify($ERRORS{'WARNING'}, 0, "request state not updated to $request_state_name_argument, it is already set to $request_state_name_old/$request_laststate_name_old, returning 1");
			return 1;
		}
		else {
			$request_state_name_new = $request_state_name_argument;
			$request_laststate_name_new = $request_state_name_old;
		}
	}
	else {
		if ($request_state_name_old eq 'pending') {
			# Request is currently: pending/yyy
			# Update to:            argument/yyy
			$request_state_name_new = $request_state_name_argument;
			$request_laststate_name_new = $request_laststate_name_old;
		}
		else {
			# Request is currently: xxx/yyy
			# Update to:            argument/xxx
			$request_state_name_new = $request_state_name_argument;
			$request_laststate_name_new = $request_laststate_name_old;
		}
	}
	

	# Construct the SQL update statement
	my $update_statement = "
	UPDATE
	request,
	state state,
	state laststate
	SET
	request.stateid = state.id,
	request.laststateid = laststate.id
	WHERE
	state.name = \'$request_state_name_new\'
	AND laststate.name = \'$request_laststate_name_new\'
	AND request.id = $request_id
	";
	
	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "database request state updated: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_laststate_name_new");
		$self->insert_computerloadlog("info", "request state updated: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_laststate_name_new");
		
		# Update the DataStructure object
		# Never update the request state or laststate in the DataStructure object to 'pending'
		if ($request_state_name_new eq 'pending') {
			# If the new request state is 'pending', update it to what was previously in the database
			$self->data->set_request_state_name($request_state_name_old);
			$self->data->set_request_laststate_name($request_laststate_name_old);
		}
		else {
			# If the new request state isn't 'pending', update it to what was just set in the database
			$self->data->set_request_state_name($request_state_name_new);
			$self->data->set_request_laststate_name($request_laststate_name_new);
		}
		notify($ERRORS{'DEBUG'}, 0, "DataStructure object request state updated: " . $self->data->get_request_state_name() . "/" . $self->data->get_request_laststate_name());
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update request state: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_laststate_name_new");
		$self->insert_computerloadlog("info", "failed to update request state: $request_state_name_old/$request_laststate_name_old --> $request_state_name_new/$request_laststate_name_new");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_computer_state_new

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub update_computer_state_new {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was NOT called as a class method, process exiting");
		exit;
	}
	
	# Get and check the argument
	my $computer_state_name_argument = shift;
	if (!$computer_state_name_argument) {
		notify($ERRORS{'CRITICAL'}, 0, "new computer state name argument was not passed");
		return;
	}
	
	# Get the necessary data from the DataStructure object
	my $computer_id = $self->data->get_computer_id();
	my $computer_state_name_old = $self->data->get_computer_state_name();
	
	# Construct the SQL update statement
	my $update_statement = "
	UPDATE
	computer,
	state
	SET
	computer.stateid = state.id
	WHERE
	state.name = \'$computer_state_name_argument\'
	AND computer.id = $computer_id
	";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "computer state updated: $computer_state_name_old --> $computer_state_name_argument");
		$self->insert_computerloadlog("info", "computer state updated: $computer_state_name_old --> $computer_state_name_argument");
		$self->data->set_computer_state_name($computer_state_name_argument);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update computer state: $computer_state_name_old --> $computer_state_name_argument");
		$self->insert_computerloadlog("info", "failed to update computer state: $computer_state_name_old --> $computer_state_name_argument");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_computerloadlog

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub insert_computerloadlog {
	my $self = shift;
	if (ref($self) !~ /VCL::/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was NOT called as a class method, process exiting");
		exit;
	}
	
	# Get and check the arguments
	my $loadstate_name = shift;
	my $additional_info = shift;
	if (!$loadstate_name || !$additional_info) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called with necessary arguments");
		return;
	}
	
	# Escape any single quotes in the additional info message
	$additional_info =~ s/\'/\\\'/g;
	
	# Get the reservation id
	my $reservation_id = $self->data->get_reservation_id();
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation id could not be retrieved");
		return;
	}
	
	# Get the computer id
	my $computer_id = $self->data->get_computer_id();
	if (!$computer_id) {
		notify($ERRORS{'WARNING'}, 0, "computer id could not be retrieved");
		return;
	}
	

	# Check to make sure the passed loadstatename exists in the computerloadstate table
	my $select_statement = "
	SELECT DISTINCT
	computerloadstate.id
	FROM
	computerloadstate
	WHERE
	computerloadstate.loadstatename = '$loadstate_name'
	";

	my $loadstate_id;
	my @selected_rows = database_select($select_statement);
	
	# Check if loadstate name was found
	if ((scalar @selected_rows) == 0) {
		notify($ERRORS{'CRITICAL'}, 0, "computerloadstate name does not exist: $loadstate_name, using NULL");
		$loadstate_id   = 'NULL';
		$loadstate_name = 'NULL';
	}
	else {
		$loadstate_id = $selected_rows[0]{id};
	}

	# Assemble the SQL statement
	my $insert_loadlog_statement = "
   INSERT INTO
   computerloadlog
   (
      reservationid,
      computerid,
      loadstateid,
      timestamp,
      additionalinfo
   )
   VALUES
   (
      '$reservation_id',
      '$computer_id',
      '$loadstate_id',
      NOW(),
      '$additional_info'
   )
   ";

	# Execute the insert statement, the return value should be the id of the computerloadlog row that was inserted
	my $loadlog_id = database_execute($insert_loadlog_statement);
	if ($loadlog_id) {
		notify($ERRORS{'DEBUG'}, 0, "inserted row into computerloadlog table: id=$loadlog_id, loadstate=$loadstate_name, additional info: '$additional_info'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to insert row into computerloadlog table: loadstate=$loadstate_name, additional info: '$additional_info'");
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_log_ending_new

 Parameters  : string containing the log ending value
 Returns     : true if successful, false if failed
 Description : Updates the log.ending value in the database for the log ID
               set for this reservation. Returns false if log ID is not
					set. A string argument must be passed containing the new
					log.ending value.
					
=cut

sub update_log_ending_new {
	# Check if subroutine was called as an object method
	my $self = shift;
	if (!ref($self) =~ /VCL::/) {
		notify($ERRORS{'WARNING'}, 0, "subroutine must be called as an object method");
		return;
	}
	
	# Make sure log ending value was passed
	my $request_log_ending = shift;
	if (!$request_log_ending) {
		notify($ERRORS{'WARNING'}, 0, "log ending value argument was not passed");
		return;
	}
	
	# Get the log id, make sure it is configured
	my $request_log_id = $self->data->get_request_log_id();
	if (!$request_log_id) {
		notify($ERRORS{'WARNING'}, 0, "request log id could not be retrieved");
		return;
	}
	
	# Get the other necessary data
	my $request_state_name = $self->data->get_request_state_name();
	my $image_id = $self->data->get_image_id();
	my $image_name = $self->data->get_image_name();
	my $imagerevision_production = $self->data->get_imagerevision_production();
		
	
	# Make sure the requested log ending makes sense
	if ($request_log_ending eq 'failed') {		
		
		# Don't set ending to 'failed' if imagerevision.production = 0
		if (!$imagerevision_production) {
			notify($ERRORS{'WARNING'}, 0, "log ending should not be set to '$request_log_ending' because imagerevision.production = 0, changing to 'failedtest'");
			$request_log_ending = 'failedtest';
		}
		
		else {
			# Construct a select statement to retrieve the resource group names this image belongs to
			my $select_image_groups_statement = "
			SELECT DISTINCT
			resourcegroup.name
			FROM
			image,
			resource,
			resourcetype,
			resourcegroup,
			resourcegroupmembers
			WHERE
			image.id = $image_id AND
			resource.subid = image.id AND resource.resourcetypeid = 13 AND
			resourcegroupmembers.resourceid = resource.id AND
			resourcegroup.id = resourcegroupmembers.resourcegroupid
			";
			
			# Call database_select() to execute the select statement
			my @image_group_rows = VCL::utils::database_select($select_image_groups_statement);
			if (!scalar @image_group_rows == 1) {
				notify($ERRORS{'WARNING'}, 0, "unable to retrieve image group names for image $image_name");
				return;
			}
			
			# Assemble an array from the select return array
			my @image_group_names;
			for my $image_group_row (@image_group_rows) {
				my $image_group_name = $image_group_row->{name};
				push @image_group_names, $image_group_name;
			}
			notify($ERRORS{'DEBUG'}, 0, "retrieved groups image $image_name belongs to:\n" . join("\n", @image_group_names));
			
			# Don't set ending to 'failed' if image only belongs to newimages-* group
			if ($request_log_ending eq 'failed' && scalar @image_group_names == 1 && $image_group_names[0] =~ /^newimages-.*/i) {
				notify($ERRORS{'WARNING'}, 0, "log ending should not be set to '$request_log_ending' because image only belongs to $image_group_names[0] group, changing to 'failedtest'");
				$request_log_ending = 'failedtest';
			}
		}
	}
	
	# Always set ending to 'none' if not a state the end user sees
	if ($request_log_ending ne 'none' && $request_state_name =~ /^(reload|to.*|.*hpc.*|image)$/) {
		notify($ERRORS{'WARNING'}, 0, "log ending should NOT be set to '$request_log_ending' because request state is $request_state_name, changing to 'none'");
		$request_log_ending = 'none';
	}
	
	# Construct the update statement 
	my $sql_update_statement = "
	UPDATE
	log
	SET
	log.ending = \'$request_log_ending\',
	log.finalend = NOW()
	WHERE
	log.id = $request_log_id
	";
	
	# Execute the update statement
	if (database_execute($sql_update_statement)) {
		notify($ERRORS{'DEBUG'}, 0, "executed update statement to set log ending to $request_log_ending for log id: $request_log_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute update statement to set log ending to $request_log_ending for log id: $request_log_id");
		return;
	}
	
	# Check the actual ending value in the database, SQL update returns 1 even if 0 rows were affected
	# Construct a select statement 
	my $sql_select_statement = "
	SELECT
	log.ending,
	log.finalend
	FROM
	log
	WHERE
	log.id = $request_log_id
	";
	
	# Call database_select() to execute the select statement and make sure 1 row was returned
	my @select_rows = VCL::utils::database_select($sql_select_statement);
	if (!scalar @select_rows == 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to verify log ending value, select statement returned " . scalar @select_rows . " rows:\n" . join("\n", $sql_select_statement));
		return;
	}
	
	# $select_rows[0] is a hash reference, the keys are the column names
	my $log_ending = $select_rows[0]->{ending};
	
	# Compare the ending value in the database to the argument
	if ($log_ending && $log_ending eq $request_log_ending) {
		notify($ERRORS{'OK'}, 0, "log ending was set to '$request_log_ending' for log id: $request_log_id");
		$self->insert_computerloadlog("info", "log ending was set to '$request_log_ending' for log id: $request_log_id");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "log ending in database ('$log_ending') does not match requested value ('$request_log_ending') for log id: $request_log_id");
		$self->insert_computerloadlog("info", "log ending in database ('$log_ending') does not match requested value ('$request_log_ending') for log id: $request_log_id");
		return;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_image_os

 Parameters  :
 Returns     :
 Description :

=cut


sub check_image_os {
	my $self               = shift;
	my $request_state_name = $self->data->get_request_state_name();
	my $image_id           = $self->data->get_image_id();
	my $image_name         = $self->data->get_image_name();
	my $image_os_name      = $self->data->get_image_os_name();
	my $imagerevision_id   = $self->data->get_imagerevision_id();

	# Only make corrections if state is image
	if ($request_state_name ne 'image') {
		notify($ERRORS{'DEBUG'}, 0, "no corrections need to be made, not an imaging request, returning 1");
		return 1;
	}

	my $image_os_name_new;
	if ($image_os_name =~ /^(rh)el[s]?([0-9])/ || $image_os_name =~ /^rh(fc)([0-9])/) {
		# Change rhelX --> rhXimage, rhfcX --> fcXimage
		$image_os_name_new = "$1$2image";
	}
	elsif($image_os_name =~ /^(centos)([0-9])/) {
		# Change rhelX --> rhXimage, rhfcX --> fcXimage
		$image_os_name_new = "$1$2image";
	}
	elsif ($image_os_name =~ /^(fedora)([0-9])/) {
		# Change fedoraX --> fcXimage
		$image_os_name_new = "fc$1image"
   }

	else {
		notify($ERRORS{'DEBUG'}, 0, "no corrections need to be made to image OS: $image_os_name");
		return 1;
	}

	# Change the image name
	$image_name =~ /^[^-]+-(.*)/;
	my $image_name_new = "$image_os_name_new-$1";

	notify($ERRORS{'OK'}, 0, "Kickstart image OS needs to be changed: $image_os_name -> $image_os_name_new, image name: $image_name -> $image_name_new");

	# Update the image table, change the OS for this image
	my $sql_statement = "
	UPDATE
	OS,
	image,
	imagerevision
	SET
	image.OSid = OS.id,
	image.name = \'$image_name_new\',
	imagerevision.imagename = \'$image_name_new\'
	WHERE
	image.id = $image_id
	AND imagerevision.id = $imagerevision_id
	AND OS.name = \'$image_os_name_new\'
	";

	# Update the image and imagerevision tables
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "image($image_id) and imagerevision($imagerevision_id) tables updated: $image_name -> $image_name_new");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update image and imagerevision tables: $image_name -> $image_name_new, returning 0");
		return 0;
	}

	if ($self->data->refresh()) {
		notify($ERRORS{'DEBUG'}, 0, "DataStructure refreshed after correcting image OS");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update DataStructure updated correcting image OS, returning 0");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "returning 1");
	return 1;
} ## end sub check_image_os

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : None
 Returns     : Nothing
 Description : Performs module cleanup actions:
               -closes the database connection

					If child classes of VCL::Module need to implement their own
					DESTROY method, they should call this method	from their own
					DESTROY method using:
					$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");

=cut

sub DESTROY {
	my $self = shift;
	
	notify($ERRORS{'DEBUG'}, 0, "destructor called, ref(\$self)=" . ref($self));
	
	# If not a blockrequest, delete computerloadlog entry
	if ($self && $self->data && !$self->data->is_blockrequest()) {
		my $reservation_id = $self->data->get_reservation_id();
		
		# Delete all computerloadlog rows with loadstatename = 'begin' for thie reservation
		if ($reservation_id && delete_computerloadlog_reservation($reservation_id, 'begin')) {
			notify($ERRORS{'DEBUG'}, 0, "removed computerloadlog rows with loadstate=begin for reservation");
		}
		elsif (!$reservation_id) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve the reservation id, computerloadlog rows not removed");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to remove computerloadlog rows with loadstate=begin for reservation");
		}
	}

	# Print the number of database handles this process created for testing/development
	if (defined $ENV{dbh_count}) {
		notify($ERRORS{'DEBUG'}, 0, "number of database handles state process created: $ENV{dbh_count}");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "state process created unknown number of database handles, \$ENV{dbh_count} is undefined");
	}

	# Close the database handle
	if (defined $ENV{dbh}) {
		notify($ERRORS{'DEBUG'}, 0, "process has a database handle stored in \$ENV{dbh}, attempting disconnect");

		if ($ENV{dbh}->disconnect) {
			notify($ERRORS{'DEBUG'}, 0, "\$ENV{dbh}: database disconnect successful");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "\$ENV{dbh}: database disconnect failed, " . DBI::errstr());
		}
	} ## end if (defined $ENV{dbh})
	else {
		notify($ERRORS{'DEBUG'}, 0, "process does not have a database handle stored in \$ENV{dbh}");
	}

	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	notify($ERRORS{'OK'}, 0, ref($self) . " process $PID exiting");
} ## end sub DESTROY

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
