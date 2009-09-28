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
 Description : Processes a reservation in the timout state. You must pass this
               method a reference to a hash containing request data.

=cut

sub process {
	my $self                       = shift;
	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $user_preferredname         = $self->data->get_user_preferred_name();
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
	my $computer_type              = $self->data->get_computer_type();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();

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
	mail($SYSADMIN, "VCL IMAGE Creation Started: $image_name", $body, $affiliation_helpaddress);

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
	my $user_preferredname         = $self->data->get_user_preferred_name();
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
	my $computer_type              = $self->data->get_computer_type();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();

	# Send image creation successful email to user
	my $body_user = <<"END";
$user_preferredname,
Your VCL image creation request for $image_prettyname has
succeeded.  Please visit $affiliation_sitewwwaddress and
you should see an image called $image_prettyname.
Please test this image to confirm it works correctly.

Thank You,
VCL Team
END
	mail($user_email, "VCL -- $image_prettyname Image Creation Succeeded", $body_user, $affiliation_helpaddress);

	# Send mail to SYSADMIN
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

	mail($SYSADMIN, "VCL IMAGE Creation Completed: $image_name", $body_admin, $affiliation_helpaddress);

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

	my $request_data               = $self->data->get_request_data();
	my $request_id                 = $self->data->get_request_id();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $user_preferredname         = $self->data->get_user_preferred_name();
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
	my $computer_type              = $self->data->get_computer_type();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();

	# Image process failed
	notify($ERRORS{'CRITICAL'}, 0, "$image_name image creation failed");

	# Send mail to user
	my $body_user = <<"END";
$user_preferredname,
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

	# Send mail to SYSADMIN
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

	mail($SYSADMIN, "VCL -- NOTICE FAILED Image Creation $image_prettyname", $body_admin, $affiliation_helpaddress);

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

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
