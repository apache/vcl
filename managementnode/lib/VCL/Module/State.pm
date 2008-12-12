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
# $Id: State.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

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
		notify($ERRORS{'OK'}, 0, "obtained a database handle for this state process, stored as \$ENV{dbh}");
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
	my $predictive_perl_package   = $self->data->get_management_node_predictive_module_perl_package();

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
		notify($ERRORS{'OK'}, 0, "attempting to load provisioning module: $provisioning_perl_package");
		eval "use $provisioning_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$provisioning_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      0, "returning 0");
			return 0;
		}
		notify($ERRORS{'OK'}, 0, "$provisioning_perl_package module successfully loaded");

		# Create provisioner object
		if (my $provisioner = ($provisioning_perl_package)->new({data_structure => $self->data})) {
			notify($ERRORS{'OK'}, 0, ref($provisioner) . " provisioner object successfully created");
			$self->{provisioner} = $provisioner;
		}
		else {
			notify($ERRORS{'OK'}, 0, "provisioning object could not be created, returning 0");
			return 0;
		}
	} ## end if ($provisioning_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "provisioning module not loaded, Perl package is not defined");
	}

	# Attempt to load the OS module
	if ($os_perl_package) {
		notify($ERRORS{'OK'}, 0, "attempting to load OS module: $os_perl_package");
		eval "use $os_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$os_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      0, "returning 0");
			return 0;
		}
		if (my $os = ($os_perl_package)->new({data_structure => $self->data})) {
			notify($ERRORS{'OK'}, 0, ref($os) . " OS object successfully created");
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

	# Attempt to load the predictive loading module
	if ($predictive_perl_package) {
		notify($ERRORS{'OK'}, 0, "attempting to load predictive loading module: $predictive_perl_package");
		eval "use $predictive_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$predictive_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      0, "returning 0");
			return 0;
		}
		if (my $predictor = ($predictive_perl_package)->new({data_structure => $self->data})) {
			notify($ERRORS{'OK'}, 0, ref($predictor) . " predictive loading object successfully created");
			$self->{predictor} = $predictor;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "predictive loading object could not be created, returning 0");
			return 0;
		}
	} ## end if ($predictive_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "predictive loading module not loaded, Perl package is not defined");
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
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
	my $request_id             = $self->data->get_request_id();
	my $request_logid          = $self->data->get_request_log_id();
	my $reservation_id         = $self->data->get_reservation_id();
	my $computer_id            = $self->data->get_computer_id();
	my $computer_short_name    = $self->data->get_computer_short_name();
	my $request_state_name     = $self->data->get_request_state_name();
	my $request_laststate_name = $self->data->get_request_laststate_name();

	# Check if the request has been deleted
	if (is_request_deleted($request_id)) {
		notify($ERRORS{'OK'}, 0, "request has been deleted, setting computer state to available and exiting");

		# Update the computer state to available
		if (update_computer_state($computer_id, "available")) {
			notify($ERRORS{'OK'}, 0, "$computer_short_name ($computer_id) state set to 'available'");
		}
		else {
			notify($ERRORS{'OK'}, 0, "failed to set $computer_short_name ($computer_id) state to 'available'");
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

	# Update log table ending column to failed for this request
	if (update_log_ending($request_logid, "failed")) {
		notify($ERRORS{'OK'}, 0, "updated log ending value to 'failed', logid=$request_logid");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update log ending value to 'failed', logid=$request_logid");
	}

	# Update the computer state to failed
	if (update_computer_state($computer_id, "failed")) {
		notify($ERRORS{'OK'}, 0, "computer $computer_short_name ($computer_id) state set to failed");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to set computer $computer_short_name ($computer_id) state to failed");
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
		notify($ERRORS{'OK'}, 0, "no corrections need to be made, not an imaging request, returning 1");
		return 1;
	}

	my $image_os_name_new;
	if ($image_os_name =~ /^(rh)el([0-9])/ || $image_os_name =~ /^rh(fc)([0-9])/) {
		# Change rhelX --> rhXimage, rhfcX --> fcXimage
		$image_os_name_new = "$1$2image";
	}
	else {
		notify($ERRORS{'OK'}, 0, "no corrections need to be made to image OS: $image_os_name");
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
		notify($ERRORS{'OK'}, 0, "image and imagerevision tables updated: $image_name -> $image_name_new");
	}
	else {
		notify($ERRORS{'OK'}, 0, "failed to update image and imagerevision tables: $image_name -> $image_name_new, returning 0");
		return 0;
	}

	if ($self->data->refresh()) {
		notify($ERRORS{'OK'}, 0, "DataStructure refreshed after correcting image OS");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update DataStructure updated correcting image OS, returning 0");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
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
	my $reservation_id = $self->data->get_reservation_id();
	
	notify($ERRORS{'DEBUG'}, 0, "destructor called, ref(\$self)=" . ref($self));
	
	# Delete all computerloadlog rows with loadstatename = 'begin' for thie reservation
	if (delete_computerloadlog_reservation($reservation_id, 'begin')) {
		notify($ERRORS{'OK'}, 0, "removed computerloadlog rows with loadstate=begin for reservation");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to remove computerloadlog rows with loadstate=begin for reservation");
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
			notify($ERRORS{'OK'}, 0, "\$ENV{dbh}: database disconnect successful");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "\$ENV{dbh}: database disconnect failed, " . DBI::errstr());
		}
	} ## end if (defined $ENV{dbh})
	else {
		notify($ERRORS{'OK'}, 0, "process does not have a database handle stored in \$ENV{dbh}");
	}

	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
} ## end sub DESTROY

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
