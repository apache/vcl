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

VCL::Module::Provisioning - VCL provisioning base module

=head1 SYNOPSIS

 use base qw(VCL::Module::Provisioning);

=head1 DESCRIPTION

 Needs to be written.

=cut

##############################################################################
package VCL::Module::Provisioning;

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

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 set_vmhost_os

 Parameters  : None
 Returns     : Process's VM host OS object
 Description : Sets the VM host OS object for the provisioner module to access.

=cut

sub set_vmhost_os {
	my $self = shift;
	my $vmhost_os = shift;
	$self->{vmhost_os} = $vmhost_os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vmhost_os

 Parameters  : None
 Returns     : Process's VM host OS object
 Description : Allows provisioning modules to access the reservation's VM host OS
               object.

=cut

sub vmhost_os {
	my $self = shift;
	
	if (!$self->{vmhost_os}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return VM host OS object, \$self->{vmhost_os} is not set");
		return;
	}
	else {
		return $self->{vmhost_os};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 retrieve_image

 Parameters  : none
 Returns     : boolean
 Description : Retrieves an image from another management node.

=cut

sub retrieve_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	# Make sure image library functions are enabled
	my $image_lib_enable = $self->data->get_management_node_image_lib_enable();
	if (!$image_lib_enable) {
		notify($ERRORS{'OK'}, 0, "image retrieval skipped, image library functions are disabled for this management node");
		return;
	}

	# Get the image name from the reservation data
	my $image_name = $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine image name from reservation data");
		return;
	}
	
	# Get the last digit of the reservation ID and sleep that number of seconds
	# This is done in case 2 reservations for the same image were started at the same time
	# Both may attempt to retrieve an image and execute the SCP command at nearly the same time
	# does_image_exist() may not catch this and allow 2 SCP retrieval processes to start
	# It's likely that the reservation IDs are consecutive and the the last digits will be different
	my ($pre_retrieval_sleep) = $self->data->get_reservation_id() =~ /(\d)$/;
	notify($ERRORS{'DEBUG'}, 0, "sleeping for $pre_retrieval_sleep seconds to prevent multiple SCP image retrieval processes");
	sleep $pre_retrieval_sleep;
	
	# Get a semaphore so only 1 process is able to retrieve the image at a time
	# Do this before checking if the image exists in case another process is retrieving the image
	my $semaphore = $self->get_semaphore("/tmp/retrieve_$image_name.lock", (60 * 15)) || return;
	
	# Make sure image does not already exist on this management node
	if ($self->does_image_exist($image_name)) {
		notify($ERRORS{'OK'}, 0, "$image_name already exists on this management node");
		return 1;
	}

	# Get the image library partner string
	my $image_lib_partners = $self->data->get_management_node_image_lib_partners();
	if (!$image_lib_partners) {
		notify($ERRORS{'WARNING'}, 0, "image library partners could not be determined");
		return;
	}
	
	# Split up the partner list
	my @partner_list = split(/,/, $image_lib_partners);
	if ((scalar @partner_list) == 0) {
		notify($ERRORS{'WARNING'}, 0, "image lib partners variable is not listed correctly or does not contain any information: $image_lib_partners");
		return;
	}
	
	# Get the local image repository path
	my $image_repository_path_local = $self->get_image_repository_path();
	if (!$image_repository_path_local) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the local image repository path");
		return;
	}
	
	# Loop through the partners
	# Find partners which have the image
	# Check size for each partner
	# Retrieve image from partner with largest image
	# It's possible that another partner (management node) is currently copying the image from another managment node
	# This should prevent copying a partial image
	my %partner_info;
	my $largest_partner_image_size = 0;
	my @partners_with_image;
	
	foreach my $partner (@partner_list) {
		# Get the connection information for the partner management node
		$partner_info{$partner}{hostname} = $self->data->get_management_node_hostname($partner);
		$partner_info{$partner}{user} = $self->data->get_management_node_image_lib_user($partner) || 'root';
		$partner_info{$partner}{identity_key} = $self->data->get_management_node_image_lib_key($partner) || '';
		$partner_info{$partner}{port} = $self->data->get_management_node_ssh_port($partner) || '22';
		
		# Call the provisioning module's get_image_repository_search_paths() subroutine
		# This returns an array of strings to pass to du
		$partner_info{$partner}{search_paths} = [$self->get_image_repository_search_paths($partner)];
		if (!$partner_info{$partner}{search_paths}) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve image repository search paths for partner: $partner");
			next;
		}
		
		# Run du to get the size of the image files on the partner if the image exists in any of the search paths
		my $du_command = "du -b " . join(" ", @{$partner_info{$partner}{search_paths}});
		my ($du_exit_status, $du_output) = run_ssh_command($partner, $partner_info{$partner}{identity_key}, $du_command, $partner_info{$partner}{user}, $partner_info{$partner}{port}, 1);
		if (!defined($du_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if image $image_name exists on $partner_info{$partner}{hostname}: $du_command");
			next;
		}
		
		# Loop through the du output lines, parse lines beginning with a number followed by a '/'
		for my $line (@$du_output) {
			my ($file_size, $file_path) = $line =~ /^(\d+)\s+(\/.+)/;
			next if (!defined($file_size) || !defined($file_path));
			$partner_info{$partner}{file_paths}{$file_path} = $file_size;
			$partner_info{$partner}{image_size} += $file_size;
		}
		
		# Display the image size if any files were found
		if ($partner_info{$partner}{image_size}) {
			notify($ERRORS{'OK'}, 0, "$image_name exists on $partner_info{$partner}{hostname}, size: " . format_number($partner_info{$partner}{image_size}) . " bytes");
		}
		else {
			notify($ERRORS{'OK'}, 0, "$image_name does NOT exist on $partner_info{$partner}{hostname}");
			next;
		}

		# Check if the image size is larger than any previously found on other partners
		if ($partner_info{$partner}{image_size} > $largest_partner_image_size) {
			@partners_with_image = ();
		}
		
		# Check if the image size is larger than any previously found on other partners
		if ($partner_info{$partner}{image_size} >= $largest_partner_image_size) {
			push @partners_with_image, $partner;
			$largest_partner_image_size = $partner_info{$partner}{image_size};
		}
	}
	
	# Check if any partner was found
	if (!@partners_with_image) {
		notify($ERRORS{'WARNING'}, 0, "unable to find $image_name on other management nodes");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "found $image_name on partner management nodes:\n" . join("\n", map { $partner_info{$_}{hostname} } (sort @partners_with_image)));
	
	# Choose a random partner so that the same management node isn't used for most transfers
	my $random_index = int(rand(scalar(@partners_with_image)));
	my $retrieval_partner = $partners_with_image[$random_index];
	notify($ERRORS{'OK'}, 0, "selected random retrieval partner: $partner_info{$retrieval_partner}{hostname}");
	
	# Create the directory in the image repository
	my $mkdir_command = "mkdir -pv $image_repository_path_local";
	my ($mkdir_exit_status, $mkdir_output) = run_command($mkdir_command);
	if (!defined($mkdir_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create image repository directory: $mkdir_command");
		return;
	}
	
	# Copy each file path to the image repository directory
	notify($ERRORS{'OK'}, 0, "attempting to retrieve $image_name from $partner_info{$retrieval_partner}{hostname}");
	for my $partner_file_path (sort keys %{$partner_info{$retrieval_partner}{file_paths}}) {
		my ($file_name) = $partner_file_path =~ /([^\/]+)$/;
		if (run_scp_command("$partner_info{$retrieval_partner}{user}\@$retrieval_partner:$partner_file_path", "$image_repository_path_local/$file_name", $partner_info{$retrieval_partner}{key}, $partner_info{$retrieval_partner}{port})) {
		notify($ERRORS{'OK'}, 0, "image $image_name was copied from $partner_info{$retrieval_partner}{hostname}");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy image $image_name from $partner_info{$retrieval_partner}{hostname}");
			return;
		}
	}
	
	# Make sure image was retrieved
	if (!$self->does_image_exist($image_name)) {
		notify($ERRORS{'WARNING'}, 0, "does_image_exist subroutine returned false for $image_name after it should have been retrieved");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_power_off

 Parameters  : Maximum number of seconds to wait (optional), seconds to delay between attempts (optional)
 Returns     : 1 - If computer is powered off
               0 - If computer is still powered on after waiting
               undefined - Unable to determine power status
 Description : Attempts to check the power status of the computer specified in
               the DataStructure for the current reservation. It will wait up to
               a maximum number of seconds for the computer to be powered off
               (default: 300 seconds). The delay between attempts can be
               specified as the 2nd argument in seconds (default: 15 seconds).

=cut

sub wait_for_power_off {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the total number of seconds to wait from the arguments
	my $total_wait_seconds = shift;
	if (!defined($total_wait_seconds) || $total_wait_seconds !~ /^\d+$/) {
		$total_wait_seconds = 300;
	}
	
	# Seconds to wait in between loop attempts
	my $attempt_delay_seconds = shift;
	if (!defined($attempt_delay_seconds) || $attempt_delay_seconds !~ /^\d+$/) {
		$attempt_delay_seconds = 15;
	}
	
	# Check if the provisioning module implements a power status subroutine
	if (!$self->can('power_status')) {
		notify($ERRORS{'WARNING'}, 0, "power_status subroutine has not been implemented by the provisioning module: " . ref($self));
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $message = "waiting a maximum of $total_wait_seconds for $computer_name to be powered off";
	
	# Call code_loop_timeout and invert the result
	if ($self->code_loop_timeout(sub{return ($self->power_status() =~ /off/i)}, [$computer_name], "waiting for $computer_name to power off", $total_wait_seconds, $attempt_delay_seconds)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$computer_name has not powered off after waiting $total_wait_seconds seconds, returning 0");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
