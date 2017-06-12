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

VCL::Module::Semaphore - VCL module to control semaphores

=head1 SYNOPSIS

 my $semaphore = VCL::Module::Semaphore->new({data_structure => $self->data});
 $semaphore->obtain('something-unique', 240, $3);

=head1 DESCRIPTION

 A semaphore is used to ensure that only 1 process performs a particular task at
 a time. An example would be the retrieval of an image from another management
 node. If multiple reservations are being processed for the same image, each
 reservation may attempt to retrieve it via SCP at the same time. A
 VCL::Module::Semaphore can be used to only allow 1 process to retrieve the
 image. The others will wait until the semaphore is released by the retrieving
 process.

=cut

###############################################################################
package VCL::Module::Semaphore;

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

use English qw(-no_match_vars);
use IO::File;
use Fcntl qw(:flock);

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 obtain

 Parameters  : $semaphore_identifier, $semaphore_expire_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : string
 Description : Obtains a semaphore by inserting a row into the vcldsemaphore
               database table.
					
					The $semaphore_expire_seconds is used to both determine when the
					semaphore should be considered orphaned and to determine how long
					the current process attempts to obtain a semaphore if blocked by
					another process.

=cut

sub obtain {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($semaphore_identifier, $semaphore_expire_seconds, $attempt_delay_seconds) = @_;
	if (!$semaphore_identifier) {
		notify($ERRORS{'WARNING'}, 0, "semaphore identifier argument was not supplied");
		return;
	}
	elsif (defined($semaphore_expire_seconds) && $semaphore_expire_seconds !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "semaphore expire seconds argument is not a valid integer: $semaphore_expire_seconds");
		return;
	}
	
	$semaphore_expire_seconds = 300 unless defined($semaphore_expire_seconds);
	$attempt_delay_seconds = 5 if !$attempt_delay_seconds;
	
	# Attempt to set the variable
	my $wait_message = "attempting to add a row to the vcldsemaphore table with identifier: '$semaphore_identifier'";
	if ($self->code_loop_timeout(\&_obtain, [$self, $semaphore_identifier, $semaphore_expire_seconds], $wait_message, $semaphore_expire_seconds, $attempt_delay_seconds)) {
		notify($ERRORS{'OK'}, 0, "*** created semaphore by adding a row to the vcldsemaphore table with identifier: '$semaphore_identifier' ***");
		$self->{vcldsemaphore_table_identifiers}{$semaphore_identifier} = 1;
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to obtain semaphore by adding a row to the vcldsemaphore table after attempting for $semaphore_expire_seconds seconds: '$semaphore_identifier'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _obtain

 Parameters  : $semaphore_identifier, $semaphore_expire_seconds
 Returns     : boolean
 Description : Helper function for Semaphore.pm::obtain. Attempts to call
               insert_vcld_semaphore. If this fails, it retrieves existing
               vcldsemaphore table entries and deletes expired rows.

=cut

sub _obtain {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($semaphore_identifier, $semaphore_expire_seconds) = @_;
	
	my $reservation_id = $self->data->get_reservation_id();
	
	if (insert_vcld_semaphore($semaphore_identifier, $reservation_id, $semaphore_expire_seconds)) {
		return 1;
	}
	
	my $current_datetime = makedatestring();
	my $current_epoch = convert_to_epoch_seconds($current_datetime);
	
	my $semaphore_info = get_vcld_semaphore_info();
	for my $existing_semaphore_identifier (keys %$semaphore_info) {
		# Ignore if identifier is different
		if ($existing_semaphore_identifier ne $semaphore_identifier) {
			next;
		}
		
		my $existing_reservation_id = $semaphore_info->{$existing_semaphore_identifier}{reservationid};
		my $existing_expires_datetime = $semaphore_info->{$existing_semaphore_identifier}{expires};
		my $existing_expires_epoch = convert_to_epoch_seconds($existing_expires_datetime);
		
		# Make sure existing semaphore wasn't created for this reservation - this should never happen
		if ($existing_reservation_id eq $reservation_id) {
			notify($ERRORS{'WARNING'}, 0, "semaphore with same identifier already exists for this reservation: $existing_semaphore_identifier, attempting to forcefully update existing vclsemaphore entry:\n" . format_data($semaphore_info->{$existing_semaphore_identifier}));
			if (insert_vcld_semaphore($semaphore_identifier, $reservation_id, $semaphore_expire_seconds, 1)) {
				return 1;
			}
		}
		
		if ($existing_expires_epoch < $current_epoch) {
			notify($ERRORS{'WARNING'}, 0, "attempting to delete expired vcldsemaphore table entry:\n" .
				"current time: $current_datetime ($current_epoch)\n" .
				"expire time: $existing_expires_datetime ($existing_expires_epoch)"
			);
			delete_vcld_semaphore($existing_semaphore_identifier, $existing_expires_datetime);
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "existing vcldsemaphore table entry has NOT expired:\n" .
				"current time: $current_datetime ($current_epoch)\n" .
				"expire time: $existing_expires_datetime ($existing_expires_epoch)"
			);
		}
	}
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the semaphore object. Database vcldsemaphore table
               entries created for this object are deleted.

=cut

sub DESTROY {
	my $self = shift;
	my $address = sprintf('%x', $self);
	
	for my $semaphore_identifier (keys %{$self->{vcldsemaphore_table_identifiers}}) {
		delete_vcld_semaphore($semaphore_identifier);
	}
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	notify($ERRORS{'DEBUG'}, 0, "destroyed Semaphore object, memory address: $address");
} ## end sub DESTROY

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
