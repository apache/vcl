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
# $Id$
##############################################################################

=head1 NAME

VCL::makeproduction - Perl module for the VCL makeproduction state

=head1 SYNOPSIS

 use VCL::makeproduction;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::makeproduction object based on the request information
 my $makeproduction = VCL::makeproduction->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "makeproduction" state.

=cut

##############################################################################
package VCL::makeproduction;

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

 Parameters  : 
 Returns     : exits with status 0 if successful, 1 if failed
 Description : Processes a reservation in the makeproduction state.
 
=cut

sub process {
	my $self = shift;
	my $request_data                    = $self->data->get_request_data();
	my $request_id                      = $self->data->get_request_id();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $request_state_name              = $self->data->get_request_state_name();
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();

	# Update the image and imagerevision tables:
	#    image.name = imagename of new production revision
	#    image.test = 0
	#    image.lastupdate = now
	#    imagerevision.production = 1 for revision specified in hash
	#    imagerevision.production = 0 for all other revisions associated with this image
	if ($self->set_imagerevision_to_production()) {
		notify($ERRORS{'OK'}, 0, "successfully updated image and imagerevision tables");
	}
	else {
		$self->reservation_failed("unable to update the image and imagerevision tables");
	}

	# Notify owner that image is in production mode
	if ($self->notify_imagerevision_to_production()) {
		notify($ERRORS{'OK'}, 0, "successfully notified owner that $image_name is in production mode");
	}
	else {
		$self->reservation_failed("failed to notify owner that $image_name is in production mode");
	}

	# Update the request state to deleted, leave the computer state alone, exit
	switch_state($request_data, 'deleted', '', 'EOR', '1');

} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 set_imagerevision_to_production

 Parameters  : None, uses image and image revision set in DataStructure
 Returns     : 1 if successful, 0 if failed
 Description : Changes the production image revision for a given image.
               It sets the imagerevision.production column to 1 for the
					imagerevision specified in the DataStructure, and all other
					image revisions to 0 for the same image.
 
=cut

sub set_imagerevision_to_production {
	my $self = shift;
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	
	# Check the variables necessary to update the database
	if (!defined $image_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to change production imagerevision, image id is not defined");
		return 0;
	}
	elsif ($image_id <= 0) {
		notify($ERRORS{'WARNING'}, 0, "unable to change production imagerevision, image id is $image_id");
		return 0;
	}
	if (!defined $imagerevision_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to change production imagerevision, imagerevision id is not defined");
		return 0;
	}
	elsif ($imagerevision_id <= 0) {
		notify($ERRORS{'WARNING'}, 0, "unable to change production imagerevision, imagerevision id is $image_id");
		return 0;
	}

	# Clear production flag for all image revisions
	# Set the correct image revision to production
	# Update the image name, set test = 0, and lastupdate to now
	my $sql_statement = "
	UPDATE
	image,
	imagerevision imagerevision_production,
	imagerevision imagerevision_others
	SET
	image.name = imagerevision_production.imagename,
	image.test = 0,
	image.lastupdate = NOW(),
	imagerevision_production.production = 1,
	imagerevision_others.production = 0
	WHERE
	image.id = '$image_id'
	AND imagerevision_production.imageid = image.id
	AND imagerevision_others.imageid = image.id
	AND imagerevision_production.id = '$imagerevision_id'
	AND imagerevision_others.id != imagerevision_production.id
	";
	
	# Call the database execute subroutine
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "imagerevision $imagerevision_id set to production for image $image_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set imagerevision $imagerevision_id to production for image $image_name");
		return 0;
	}

} ## end sub _update_flags

#/////////////////////////////////////////////////////////////////////////////

=head2 notify_imagerevision_to_production

 Parameters  : 
 Returns     : 
 Description : 
 
=cut

sub notify_imagerevision_to_production {
	my $self         = shift;
	my $image_id                        = $self->data->get_image_id();
	my $image_name                      = $self->data->get_image_name();
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $imagerevision_id                = $self->data->get_imagerevision_id();
	my $imagerevision_revision          = $self->data->get_imagerevision_revision();
	my $user_preferredname              = $self->data->get_user_preferred_name();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_email                      = $self->data->get_user_email();
	

	# Assemble the message subject
	my $subject = "VCL -- Image $image_prettyname made production";
	
	# Assemble the message body
	my $body = <<"END";
$user_preferredname,
Revision $imagerevision_revision of your VCL '$image_prettyname' image has been made production.  Any new reservations for the image will receive this revision by default.

If you have any questions, please contact $user_affiliation_helpaddress.

Thank You,
VCL Team
END
	
	# Send the message
	if (mail($user_email, $subject, $body)) {
		notify($ERRORS{'OK'}, 0, "email message sent to $user_email");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to send email message to $user_email");
		return 0;
	}

} ## end sub _notify_owner

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
