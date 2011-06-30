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

VCL::image - Perl module for the VCL image state

=head1 SYNOPSIS

 use VCL::image;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::image object based on the request information
 my $image = VCL::image->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "image" state.

=cut

##############################################################################
package VCL::image;

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
use English '-no_match_vars';

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Processes a reservation in the timout state. You must pass this
               method a reference to a hash containing request data.

=cut

sub process {
	my $self                       = shift;
	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_id                   = $self->data->get_image_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_size                 = $self->data->get_image_size();
	my $imagerevision_id           = $self->data->get_imagerevision_id();
	my $imagemeta_sysprep          = $self->data->get_imagemeta_sysprep();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_type              = $self->data->get_computer_type();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email();

	if ($sysadmin_mail_address) {
		# Notify administrators that image creation is starting
		my $body = <<"END";
VCL Image Creation Started

Request ID: $request_id
Reservation ID: $reservation_id
PID: $$

Image ID: $image_id
Image name: $image_name
Base image size: $image_size
Base revision ID: $imagerevision_id

Management node: $managementnode_shortname

Username: $user_unityid
User ID: $user_id

Computer ID: $computer_id
Computer name: $computer_shortname

Use Sysprep: $imagemeta_sysprep
END
		mail($sysadmin_mail_address, "VCL IMAGE Creation Started: $image_name", $body, $affiliation_helpaddress);
	}
	
	# Make sure image does not exist in the repository
	my $image_already_exists = $self->provisioner->does_image_exist();
	if ($image_already_exists) {
		notify($ERRORS{'CRITICAL'}, 0, "image $image_name already exists in the repository");
		$self->reservation_failed();
	}
	elsif (!defined($image_already_exists)) {
		notify($ERRORS{'CRITICAL'}, 0, "image $image_name already partially exists in the repository");
		$self->reservation_failed();
	}
	else {
		notify($ERRORS{'OK'}, 0, "image $image_name does not exist in the repository");
	}

	# Get the current timestamp
	# This will be used for image.lastupdate, imagerevision.datecreated and currentimage.txt
	my $timestamp = makedatestring();
	$self->data->set_image_lastupdate($timestamp);
	$self->data->set_imagerevision_date_created($timestamp);
	
	my $create_image_result;
	
	# --- BEGIN NEW MODULARIZED METHOD ---
	# Check if capture() subroutine has been implemented by the provisioning module
	if ($self->provisioner->can("capture")) {
		# Call the provisioning modules's capture() subroutine
		# The provisioning module should do everything necessary to capture the image
		notify($ERRORS{'OK'}, 0, "calling provisioning module's capture() subroutine");
		if ($create_image_result = $self->provisioner->capture()) {
			notify($ERRORS{'OK'}, 0, "$image_name image was successfully captured by the provisioning module");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$image_name image failed to be captured by provisioning module");
			$self->reservation_failed();
		}
	}
	# --- END NEW MODULARIZED METHOD ---

	elsif ($computer_type eq "blade" && $self->os) {
		$create_image_result = 1;

		notify($ERRORS{'OK'}, 0, "OS modularization supported, beginning OS module capture prepare");
		if (!$self->os->capture_prepare()) {
			notify($ERRORS{'WARNING'}, 0, "OS module capture prepare failed");
			$self->reservation_failed();
		}

		notify($ERRORS{'OK'}, 0, "beginning provisioning module capture prepare");
		if (!$self->provisioner->capture_prepare()) {
			notify($ERRORS{'WARNING'}, 0, "provisioning module capture prepare failed");
			$self->reservation_failed();
		}
		
		notify($ERRORS{'OK'}, 0, "beginning OS module capture start");
		if (!$self->os->capture_start()) {
			notify($ERRORS{'WARNING'}, 0, "OS module capture start failed");
			$self->reservation_failed();
		}

		notify($ERRORS{'OK'}, 0, "beginning provisioning module capture monitor");
		if (!$self->provisioner->capture_monitor()) {
			notify($ERRORS{'WARNING'}, 0, "provisioning module capture monitor failed");
			$self->reservation_failed();
		}

	} ## end if ($computer_type eq "blade" && $self->os)
	
	elsif ($computer_type eq "blade") {
		$create_image_result = $self->provisioner->capture_prepare();

		if ($create_image_result) {
			$create_image_result = $self->provisioner->capture_monitor();
		}
	}
	elsif ($computer_type eq "virtualmachine") {
		$create_image_result = $self->provisioner->capture();
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unsupported computer type: $computer_type");
		$self->reservation_failed();
	}

	# Image creation was successful, proceed to update database tables
	if ($create_image_result) {
		# Success
		notify($ERRORS{'OK'}, 0, "$image_name image files successfully saved");

		# Update the request state to completed, laststate to image
		if (update_request_state($request_id, "completed", "image")) {
			notify($ERRORS{'OK'}, 0, "request state updated to completed, laststate to image");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to update request state to completed, laststate to image");
		}

		# Get the new image size
		my $image_size_new;
		if ($image_size_new = $self->provisioner->get_image_size($image_name)) {
			notify($ERRORS{'OK'}, 0, "size of $image_name: $image_size_new");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to retrieve size of new revision: $image_name, old size will be used");
			$image_size_new = $image_size;
		}
		$self->data->set_image_size($image_size_new);

		# Update image timestamp, clear deleted flag
		# Set test flag if according to whether this image is new or updated
		# Update the image size
		my $update_image_statement = "
		UPDATE
		image,
		imagerevision
		SET
		image.lastupdate = \'$timestamp\',
		image.deleted = \'0\',
		image.size = \'$image_size_new\',
		image.name = \'$image_name\',
		imagerevision.deleted = \'0\',
		imagerevision.datecreated = \'$timestamp\'
		WHERE
		image.id = $image_id
		AND imagerevision.id = $imagerevision_id
		";

		# Execute the image update statement
		if (database_execute($update_image_statement)) {
			notify($ERRORS{'OK'}, 0, "image and imagerevision tables updated for image=$image_id, imagerevision=$imagerevision_id, name=$image_name, lastupdate=$timestamp, deleted=0, size=$image_size_new");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "image table could not be updated for image=$image_id");
		}
	} ## end if ($create_image_result)

	# Check if image creation was successful and database tables were successfully updated
	# Notify user and admins of the results
	if ($create_image_result) {
		$self->reservation_successful($image_size);
	}

	else {
		notify($ERRORS{'CRITICAL'}, 0, "image creation failed, see previous log messages");
		$self->reservation_failed();
	}

} ## end sub process
#/////////////////////////////////////////////////////////////////////////////

sub reservation_successful {
	my $self           = shift;
	my $image_size_old = shift;

	my $request_data               = $self->data->get_request_data();
	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $user_email                 = $self->data->get_user_email();
	my $affiliation_sitewwwaddress = $self->data->get_user_affiliation_sitewwwaddress();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_id                   = $self->data->get_image_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_prettyname           = $self->data->get_image_prettyname();
	my $image_size                 = $self->data->get_image_size();
	my $imagerevision_id           = $self->data->get_imagerevision_id();
	my $imagemeta_sysprep          = $self->data->get_imagemeta_sysprep();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email();

	# Send image creation successful email to user
	my $body_user = <<"END";

Your VCL image creation request for $image_prettyname has
succeeded.  Please visit $affiliation_sitewwwaddress and
you should see an image called $image_prettyname.
Please test this image to confirm it works correctly.

Thank You,
VCL Team
END
	mail($user_email, "VCL -- $image_prettyname Image Creation Succeeded", $body_user, $affiliation_helpaddress);

	# Send mail to $sysadmin_mail_address
	my $body_admin = <<"END";
VCL Image Creation Completed

Request ID: $request_id
Reservation ID: $reservation_id
PID: $$

Image ID: $image_id
Image name: $image_name
Image size change: $image_size_old --> $image_size

Revision ID: $imagerevision_id

Management node: $managementnode_shortname

Username: $user_unityid
User ID: $user_id

Computer ID: $computer_id
Computer name: $computer_shortname

Use Sysprep: $imagemeta_sysprep
END

	mail($sysadmin_mail_address, "VCL IMAGE Creation Completed: $image_name", $body_admin, $affiliation_helpaddress);

	# Insert reload request data into the datbase
	if (insert_reload_request($request_data)) {
		notify($ERRORS{'OK'}, 0, "inserted reload request into database for computer id=$computer_id");

		# Switch the request state to complete, leave the computer state as is, update log ending to EOR, exit
		switch_state($request_data, 'complete', '', 'EOR', '1');
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to insert reload request into database for computer id=$computer_id");

		# Switch the request and computer states to failed, set log ending to failed, exit
		switch_state($request_data, 'failed', 'failed', 'failed', '1');
	}

	notify($ERRORS{'OK'}, 0, "exiting");
	exit;
} ## end sub reservation_successful

#/////////////////////////////////////////////////////////////////////////////

sub reservation_failed {
	my $self = shift;

	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $user_email                 = $self->data->get_user_email();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_id                   = $self->data->get_image_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_prettyname           = $self->data->get_image_prettyname();
	my $imagerevision_id           = $self->data->get_imagerevision_id();
	my $imagemeta_sysprep          = $self->data->get_imagemeta_sysprep();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email();

	# Image process failed
	notify($ERRORS{'CRITICAL'}, 0, "$image_name image creation failed");

	# Send mail to user
	my $body_user = <<"END";

We apologize for the inconvenience.
Your image creation of $image_prettyname has been delayed
due to a system issue that prevented the automatic completion.

The image creation request and the computing resource have
been placed in a safe mode. The VCL system administrators
have been notified for manual intervention.

Once the issues have been resolved, you will be notified
by the successful completion email or contacted directly
by the VCL system administrators.

If you do not receive a response within one business day, please
reply to this email.

Thank You,
VCL Team
END
	mail($user_email, "VCL -- NOTICE DELAY Image Creation $image_prettyname", $body_user, $affiliation_helpaddress);

	# Send mail to $sysadmin_mail_address
	my $body_admin = <<"END";
VCL Image Creation Failed

Request ID: $request_id
Reservation ID: $reservation_id
PID: $$

Image ID: $image_id
Image name: $image_name

Revision ID: $imagerevision_id

Management node: $managementnode_shortname

Username: $user_unityid
User ID: $user_id

Computer ID: $computer_id
Computer name: $computer_shortname

Use Sysprep: $imagemeta_sysprep
END

	mail($sysadmin_mail_address, "VCL -- NOTICE FAILED Image Creation $image_prettyname", $body_admin, $affiliation_helpaddress);

	# Update the request state to maintenance, laststate to image
	if (update_request_state($request_id, "maintenance", "image")) {
		notify($ERRORS{'OK'}, 0, "request state set to maintenance, laststate to image");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to set request state to maintenance, laststate to image");
	}

	# Update the computer state to maintenance
	if (update_computer_state($computer_id, "maintenance")) {
		notify($ERRORS{'OK'}, 0, "$computer_shortname state set to maintenance");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to set $computer_shortname state to maintenance");
	}

	notify($ERRORS{'OK'}, 0, "exiting");
	exit;
} ## end sub reservation_failed

#/////////////////////////////////////////////////////////////////////////////

=head2 setup

 Parameters  : none
 Returns     : 
 Description : This subroutine is used when vcld is run in setup mode. It
               presents a menu for the image module.

=cut

sub setup {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	push @{$ENV{setup_path}}, 'Image';
	
	my @operation_choices = (
		'Capture Base Image',
	);
	
	my @setup_path = @{$ENV{setup_path}};
	OPERATION: while (1) {
		@{$ENV{setup_path}} = @setup_path;
		
		print '-' x 76 . "\n";
		
		print "Choose an operation:\n";
		my $operation_choice_index = setup_get_array_choice(@operation_choices);
		last if (!defined($operation_choice_index));
		my $operation_name = $operation_choices[$operation_choice_index];
		print "\n";
		
		push @{$ENV{setup_path}}, $operation_name;
		
		if ($operation_name =~ /capture/i) {
			$self->setup_capture_base_image();
		}
	}
	
	pop @{$ENV{setup_path}};
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_capture_base_image

 Parameters  : none
 Returns     : 
 Description : This subroutine is used when vcld is run in setup mode. It
               inserts the database entries necessary to capture a base image.
               Several questions are presented to the user via the command line.

=cut

sub setup_capture_base_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the management node id, needed to insert a reservation row later on
	my $management_node_id = $self->data->get_management_node_id();
	if (!$management_node_id) {
		print "ERROR: failed to determine the management node ID\n";
		return;
	}
	
	# Get the user who the reservation and image will belong to
	my $user_id;
	my $username;
	while (!$user_id) {
		my $user_identifier = setup_get_input_string("Enter the VCL login name or ID of the user who will own the image:", 'admin');
		return if (!defined($user_identifier));
		my $user_info = get_user_info($user_identifier);
		if (!$user_info) {
			print "User was not found: $user_identifier\n";
		}
		else {
			$user_id = $user_info->{id};
			$username = $user_info->{unityid};
		}
	}
	print "\nUser who will own the image: $username (ID: $user_id)\n\n";
	
	# Determine the computer ID
	my $computer_id;
	my %computer_info;
	while (!$computer_id) {
		my $computer_identifier = setup_get_input_string("Enter the hostname or IP address of the computer to be captured:");
		return if (!defined($computer_identifier));
		
		# Search the computer table for a match
		my @computer_ids = get_computer_ids($computer_identifier);
		if (!@computer_ids) {
			print "No VCL computers were found with the name or IP address: $computer_identifier\n";
			next;
		}
		
		# Get information from the database for all of the computers found
		for my $computer_id (@computer_ids) {
			$computer_info{$computer_id} = get_computer_info($computer_id);
			if (!$computer_info{$computer_id}) {
				print "ERROR: unable to retrieve information for computer ID: $computer_id\n";
				return;
			}
		}
	
		if (scalar(@computer_ids) > 1) {
			print "Multiple VCL computers were found with the name or IP address: '$computer_identifier' (@computer_ids)\n\n";
			print "Choose a computer:\n";
			$computer_id = setup_get_hash_choice(\%computer_info, 'hostname');
			return if (!defined($computer_id));
		}
		else {
			$computer_id = (keys %computer_info)[0];
		}
		
		
	}
	
	my $computer_hostname = $computer_info{$computer_id}{hostname};
	my $computer_state_name = $computer_info{$computer_id}{state}{name};
	my $computer_provisioning_module_name = $computer_info{$computer_id}{provisioning}{module}{name};
	
	my $install_type;
	if ($computer_provisioning_module_name =~ /vm/i) {
		$install_type = 'vmware';
	}
	else {
		$install_type = 'partimage';
	}
	
	print "\nComputer to be captured: $computer_hostname (ID: $computer_id)\n";
	print "Provisioning module: $computer_provisioning_module_name\n";
	print "Install type: $install_type\n";
	print "\n";
	
	# Make sure the computer state is valid
	if ($computer_state_name =~ /(maintenance|deleted)/i) {
		print "ERROR: state of $computer_hostname is $computer_state_name\n";
		return;
	}
	
	
	# Get the OS table contents from the database
	my $os_info = get_os_info();
	if (!$os_info) {
		print "ERROR: failed to retrieve OS info from the database\n";
		return;
	}

	# Loop through the OS table info
	for my $os_id (keys %$os_info) {
		# Remove keys which don't match the selected computer type
		# Remove keys where the name begins with esx - deprecated OS type
		if ($os_info->{$os_id}{installtype} ne $install_type || $os_info->{$os_id}{name} =~ /^vmwareesx/i) {
			delete $os_info->{$os_id};
		}
	}

	print "Select the OS to be captured (install type: $install_type):\n";
	my $os_id = setup_get_hash_choice($os_info, 'prettyname');
	return if (!defined($os_id));
	my $os_prettyname = $os_info->{$os_id}{prettyname};
	my $os_module_perl_package = $os_info->{$os_id}{module}{perlpackage};
	my $os_type = $os_info->{$os_id}{type};
	print "\nSelected OS: $os_prettyname\n\n";
	
	my @architecture_choices = (
		'x86',
		'x86_64',
	);
	print "Image architecture:\n";
	my $architecture_choice_index = setup_get_array_choice(@architecture_choices);
	last if (!defined($architecture_choice_index));
	my $architecture_choice = $architecture_choices[$architecture_choice_index];
	print "\nImage architecture: $architecture_choice\n\n";
	
	# If Windows, ask if Sysprep should be used
	my $use_sysprep = 1;
	if ($os_type =~ /windows/i) {
		my @yes_no_choices = (
			'Yes',
			'No',
		);
		
		print "Use Sysprep:\n";
		my $sysprep_choice_index = setup_get_array_choice(@yes_no_choices);
		last if (!defined($sysprep_choice_index));
		my $use_sysprep_choice = $yes_no_choices[$sysprep_choice_index];
		print "\nUse Sysprep: $use_sysprep_choice\n\n";
		
		if ($use_sysprep_choice =~ /no/i) {
			$use_sysprep = 0;
		}
	}
	
	my $image_prettyname;
	while (!$image_prettyname) {
		$image_prettyname = setup_get_input_string("Enter the name of the image to be captured:");
		return if (!defined($image_prettyname));
		#if ($image_prettyname =~ //) {
		#	print "Image name is not valid: $image_prettyname\n";
		#	$image_prettyname = 0;
		#}
	}
	
	my $image_name = $image_prettyname;
	$image_name =~ s/[\s\W]//g;
	$image_name = $os_info->{$os_id}{name} . "-$image_name-v0";
	
	my $insert_imagemeta_statement = <<EOF;
INSERT INTO imagemeta
(sysprep)
VALUES
('$use_sysprep')
EOF
	
	my $imagemeta_id = database_execute($insert_imagemeta_statement);
	if (!defined($imagemeta_id)) {
		print "ERROR: failed to insert into imagemeta table\n";
		return;
	}
	
	
	my $insert_image_statement = <<EOF;
INSERT INTO image (name, prettyname, ownerid, platformid, OSid, imagemetaid, deleted, lastupdate, size, architecture, basedoffrevisionid)
VALUES ('$image_name', '$image_prettyname', '$user_id', '1', $os_id, $imagemeta_id, '1', NOW( ), '1450', '$architecture_choice', '4')
EOF
	
	my $image_id = database_execute($insert_image_statement);
	if (!defined($image_id)) {
		print "ERROR: failed to insert into image table\n";
		return;
	}
	
	# Add the newly inserted image ID to the image name
	$image_name =~ s/-v0$/$image_id-v0/;
	
	# Upadate the name in the image table
	my $update_image_statement = <<EOF;
UPDATE image
SET name = '$image_name'
WHERE
id = $image_id
EOF
	if (!database_execute($update_image_statement)) {
		print "ERROR: failed to update the image table with the correct image name: $image_name\n";
		return;
	}
	
	
	my $insert_imagerevision_statement = <<EOF;
INSERT INTO imagerevision
(imageid, revision, userid, datecreated, deleted, production, imagename)
VALUES
($image_id, '0', '$user_id', NOW( ), '1', '1', '$image_name')
EOF

	my $imagerevision_id = database_execute($insert_imagerevision_statement);
	if (!defined($imagerevision_id)) {
		print "ERROR: failed to insert into imagerevision table\n";
		return;
	}

	my $insert_resource_statement = <<EOF;
INSERT INTO resource
(resourcetypeid, subid)
VALUES ('13', '$image_id')
EOF

	my $resource_id = database_execute($insert_resource_statement);
	if (!defined($resource_id)) {
		print "ERROR: failed to insert into resource table\n";
		return;
	}
	
	print "\nAdded new image to database: '$image_prettyname'\n";
	print "   image.name: $image_name\n";
	print "   image.id: $image_id\n";
	print "   imagerevision.id: $imagerevision_id\n";
	print "   imagemeta.id: $imagemeta_id\n";
	print "   resource.id: $resource_id\n\n";
	
	
	my ($request_id, $reservation_id) = insert_request($management_node_id, 'image', 'image', 0, $username, $computer_id, $image_id, $imagerevision_id, 0, 60);
	if (!defined($request_id) || !defined($reservation_id)) {
		print "ERROR: failed to insert new imaging request\n";
		return;
	}
	
	my $message = <<EOF;
Inserted imaging request to the database:
request ID: $request_id
reservation ID: $reservation_id

This process will now display the contents of the vcld.log file if the vcld
daemon is running. If you do not see many lines of additional output, exit this
process, start the vcld daemon, and monitor the image capture process by running
the command:
tail -f $LOGFILE | grep '$request_id:$reservation_id'

EOF
	
	print '-' x 76 . "\n";
	print "$message";
	print '-' x 76 . "\n";
	
	# Pipe the command output to a file handle
	# The open function returns the pid of the process
	if (open(COMMAND, "tail -f $LOGFILE 2>&1 |")) {
		# Capture the output of the command
		
		while (my $output = <COMMAND>) {
			print $output if ($output =~ /$reservation_id/);
		}
	}
	
	exit;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
