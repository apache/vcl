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

VCL::makeproduction - Perl module for the VCL makeproduction state

=head1 SYNOPSIS

 use VCL::makeproduction;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my $request_info = get_request_info->($request_id);

 # Set the reservation ID in the hash
 $request_info->{RESERVATIONID} = $reservation_id;

 # Create a new VCL::makeproduction object based on the request information
 my $makeproduction = VCL::makeproduction->new($request_info);

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
our $VERSION = '2.4.2';

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

 Parameters  : none
 Returns     : boolean
 Description : Processes a reservation in the makeproduction state.
 
=cut

sub process {
	my $self = shift;
	my $image_name = $self->data->get_image_name();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $request_laststate_name = $self->data->get_request_laststate_name();
	
	if (!set_production_imagerevision($imagerevision_id)) {
		$self->reservation_failed("failed to set imagerevision ID $imagerevision_id to production for image $image_name");
	}
	
	# Notify owner that image revision is production
	if (!$self->notify_imagerevision_to_production()) {
		$self->reservation_failed("failed to notify owner that $image_name is in production mode");
	}
	
	my $log_ending;
	my $computer_state;
	if ($request_laststate_name =~ /(new|reserved)/) {
		$log_ending = 'deleted';
		$computer_state = 'available';
	}
	elsif ($request_laststate_name =~ /(inuse)/) {
		$log_ending = 'released';
	}
	
	$self->state_exit('deleted', $computer_state, $log_ending);
} ## end sub process

#/////////////////////////////////////////////////////////////////////////////

=head2 notify_imagerevision_to_production

 Parameters  : 
 Returns     : 
 Description : 
 
=cut

sub notify_imagerevision_to_production {
	my $self = shift;
	my $image_prettyname                = $self->data->get_image_prettyname();
	my $imagerevision_revision          = $self->data->get_imagerevision_revision();
	my $user_affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $user_email                      = $self->data->get_user_email();
	

	# Assemble the message subject
	my $subject = "VCL -- Image $image_prettyname made production";
	
	# Assemble the message body
	my $body = <<"END";

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

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
