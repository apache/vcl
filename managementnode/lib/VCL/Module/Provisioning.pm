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
our $VERSION = '2.3.2';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use File::Basename;

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $computer_id (optional)
 Returns     : string
 Description : Checks the status of the computer in order to determine if the
               computer is ready to be reserved or needs to be reloaded. A
               string is returned depending on the status of the computer:
               'READY':
                  * Computer is ready to be reserved
                  * It is accessible
                  * It is loaded with the correct image
                  * OS module's post-load tasks have run
               'POST_LOAD':
                  * Computer is loaded with the correct image
                  * OS module's post-load tasks have not run
               'RELOAD':
                  * Computer is not accessible or not loaded with the correct
                    image

=cut

sub node_status {
	my $self;
	
	# Get the argument
	my $argument = shift;
	
	# Check if this subroutine was called an an object method or an argument was passed
	if (ref($argument) =~ /VCL::Module/i) {
		$self = $argument;
	}
	elsif (!ref($argument) || ref($argument) eq 'HASH') {
		# An argument was passed, check its type and determine the computer ID
		my $computer_id;
		if (ref($argument)) {
			# Hash reference was passed
			$computer_id = $argument->{id};
		}
		elsif ($argument =~ /^\d+$/) {
			# Computer ID was passed
			$computer_id = $argument;
		}
		else {
			# Computer name was passed
			($computer_id) = get_computer_ids($argument);
		}
		
		if ($computer_id) {
			notify($ERRORS{'DEBUG'}, 0, "computer ID: $computer_id");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to determine computer ID from argument:\n" . format_data($argument));
			return;
		}
		
		# Create a DataStructure object containing data for the computer specified as the argument
		my $data;
		eval {
			$data= new VCL::DataStructure({computer_id => $computer_id});
		};
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, error: $EVAL_ERROR");
			return;
		}
		elsif (!$data) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, DataStructure object is not defined");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "created DataStructure object  for computer ID: $computer_id");
		}
		
		# Create a provisioning object
		my $provisioning_module_perl_package = $data->get_computer_provisioning_module_perl_package();
		if ($self = ($provisioning_module_perl_package)->new({data_structure => $data})) {
			notify($ERRORS{'DEBUG'}, 0, "created $provisioning_module_perl_package object to check the status of computer ID: $computer_id");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create $provisioning_module_perl_package object to check the status of computer ID: $computer_id");
			return;
		}
		
		# Create an OS object for the provisioning object to access
		if (!$self->create_os_object()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create OS object");
			return;
		}
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_name = $self->data->get_computer_node_name();
	my $image_name = $self->data->get_image_name();
	my $request_forimaging = $self->data->get_request_forimaging();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to check the status of computer $computer_name, image: $image_name imagerevision_id; $imagerevision_id");
	
	# Create a hash reference and populate it with the default values
	my $status;
	$status->{currentimage} = '';
	$status->{ssh} = 0;
	$status->{image_match} = 0;
	$status->{status} = 'RELOAD';
	
	# Check if SSH is available
	if ($self->os->is_ssh_responding()) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name is responding to SSH");
		$status->{ssh} = 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "$computer_name is not responding to SSH, returning 'RELOAD'");
		$status->{status} = 'RELOAD';
		$status->{ssh} = 0;
		
		# Skip remaining checks if SSH isn't available
		return $status;
	}
	
	# Get the contents of currentimage.txt and check if currentimage.txt matches the requested image name
	my $current_image_revision_id = $self->os->get_current_image_info();
	$status->{currentimagerevision_id} = $current_image_revision_id;

	$status->{currentimage} = $self->data->get_computer_currentimage_name();
	my $vcld_post_load_status = $self->data->get_computer_currentimage_vcld_post_load();
	
	if (!$current_image_revision_id) {
		notify($ERRORS{'OK'}, 0, "unable to retrieve currentimage.txt contents on $computer_name, returning 'RELOAD'");
		return $status;
	}
	#elsif ($current_image_name eq $image_name) {
	elsif ($current_image_revision_id eq $imagerevision_id) {
		notify($ERRORS{'DEBUG'}, 0, "currentimage.txt image $current_image_revision_id ($status->{currentimage}) matches requested image $imagerevision_id ($image_name) on $computer_name");
		$status->{image_match} = 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "currentimage.txt image $current_image_revision_id ($status->{currentimage}) does not match requested image name $imagerevision_id ($image_name) on $computer_name, returning 'RELOAD'");
		return $status;
	}
	
	# Check if the OS post_load tasks have run
	if ($vcld_post_load_status) {
		notify($ERRORS{'DEBUG'}, 0, "OS module post_load tasks have been completed on $computer_name");
		$status->{status} = 'READY';
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "OS module post_load tasks have not been completed on $computer_name, returning 'POST_LOAD'");
		$status->{status} = 'POST_LOAD';
	}
	
	notify($ERRORS{'OK'}, 0, "status of $computer_name: $status->{status}");
	return $status;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_search_paths

 Parameters  : $management_node_identifier (optional)
 Returns     : array
 Description : Returns an array containing paths on the management node where an
               image may reside. The paths may contain wildcards. This is used
               to attempt to locate an image on another managment node in order
               to retrieve it.

=cut

sub get_image_repository_search_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_identifier = shift;
	
	my $image_name = $self->data->get_image_name();
	
	my @search_paths;
	
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	if ($management_node_install_path) {
		push @search_paths, "$management_node_install_path/$image_name*";
		push @search_paths, "$management_node_install_path/vmware_images/$image_name*";
	}
	
	my $vmhost_profile_repository_path = $self->data->get_vmhost_profile_repository_path(0);
	push @search_paths, "$vmhost_profile_repository_path/$image_name*" if $vmhost_profile_repository_path;
	
	return @search_paths;
} ## end sub get_image_repository_search_paths

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
	
	# Get a semaphore so only 1 process is able to retrieve the image at a time
	# Do this before checking if the image exists in case another process is retrieving the image
	# Wait up to 2 hours in case a large image is being retrieved
	my $semaphore = $self->get_semaphore("retrieve_$image_name", (60 * 120)) || return;
	
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
	
	# Get the image repository path
	my $image_repository_path_local;
	if ($self->can('get_image_repository_path')) {
		$image_repository_path_local = $self->get_image_repository_path();
	}
	elsif ($self->can('get_image_repository_directory_path')) {
		$image_repository_path_local = $self->get_image_repository_directory_path();
	}
	else {
		$image_repository_path_local = $self->data->get_vmhost_profile_repository_path(0);
	}
	
	if (!$image_repository_path_local) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the local image repository path");
		return;
	}
	
	# Make sure the parent image repository path exists
	my ($image_repository_directory_name, $image_repository_parent_directory_path) = fileparse($image_repository_path_local, qr/\.[^\\\/]*/);
	if (!$image_repository_parent_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image, unable to determine parent directory of local image repository path: $image_repository_path_local");
		return;
	}
	elsif (!$self->mn_os->file_exists($image_repository_parent_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image, local image repository parent path does not exist: $image_repository_parent_directory_path");
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
	
	PARTNER: foreach my $partner (@partner_list) {
		# Get the connection information for the partner management node
		$partner_info{$partner}{hostname} = $self->data->get_management_node_hostname($partner);
		$partner_info{$partner}{user} = $self->data->get_management_node_image_lib_user($partner) || 'root';
		$partner_info{$partner}{identity_key} = $self->data->get_management_node_image_lib_key($partner) || '';
		$partner_info{$partner}{port} = $self->data->get_management_node_ssh_port($partner) || '22';
		
		# Call the provisioning module's get_image_repository_search_paths() subroutine
		# This returns an array of strings to pass to du
		my @search_paths = $self->get_image_repository_search_paths($partner);
		if (@search_paths) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved image repository search paths for partner $partner:\n" . join("\n", @search_paths));
			$partner_info{$partner}{search_paths} = \@search_paths;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve image repository search paths for partner: $partner");
			next PARTNER;
		}
		
		# Run du to get the size of the image files on the partner if the image exists in any of the search paths
		my $du_command = "du -b " . join(" ", @{$partner_info{$partner}{search_paths}});
		my ($du_exit_status, $du_output) = VCL::Module::OS::execute(
			{
				node => $partner,
				command => $du_command,
				display_output => 0,
				timeout => 30,
				max_attempts => 2,
				port => $partner_info{$partner}{port},
				user => $partner_info{$partner}{user},
				identity_key => $partner_info{$partner}{identity_key},
			}
		);
		
		if (!defined($du_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if image $image_name exists on $partner_info{$partner}{hostname}: $du_command");
			next PARTNER;
		}
		
		# Loop through the du output lines, parse lines beginning with a number followed by a '/'
		LINE: for my $line (@$du_output) {
			my ($file_size, $file_path) = $line =~ /^(\d+)\s+(\/.+)/;
			next if (!defined($file_size) || !defined($file_path));
			
			my ($file_prefix, $directory_path, $file_extension) = fileparse($file_path, qr/\.[^.]*/);
			if (!$file_prefix || !$directory_path || !$file_extension) {
				next LINE;
			}
			
			my $file_name = "$file_prefix$file_extension";
			$partner_info{$partner}{directory_paths}{$directory_path}{file_paths}{$file_path}{file_name} = $file_name;
			$partner_info{$partner}{directory_paths}{$directory_path}{file_paths}{$file_path}{file_size} = $file_size;
			$partner_info{$partner}{directory_paths}{$directory_path}{image_size} += $file_size;
		}
		
		if (!$partner_info{$partner}{directory_paths}) {
			notify($ERRORS{'OK'}, 0, "$image_name does NOT exist on $partner_info{$partner}{hostname}, output:\n" . join("\n", @$du_output));
			next PARTNER;
		}
		
		# Loop through the directories containing image files found on the partner
		# The image may have been found in multiple directories
		my $directory_path;
		DIRECTORY_PATH: for my $check_directory_path (keys %{$partner_info{$partner}{directory_paths}}) {
			if (!$directory_path) {
				$directory_path = $check_directory_path;
				next DIRECTORY_PATH;
			}
			
			my $file_count = scalar(keys %{$partner_info{$partner}{directory_paths}{$directory_path}{file_paths}});
			my $image_size = $partner_info{$partner}{directory_paths}{$directory_path}{image_size};
			my $check_file_count = scalar(keys %{$partner_info{$partner}{directory_paths}{$check_directory_path}{file_paths}});
			my $check_image_size = $partner_info{$partner}{directory_paths}{$check_directory_path}{image_size};
			
			notify($ERRORS{'DEBUG'}, 0, "found $image_name in multiple directories on $partner_info{$partner}{hostname}:\n" .
				"$directory_path: file count: $file_count, image size: $image_size\n" .
				"$check_directory_path: file count: $check_file_count, image size: $check_image_size"
			);
			
			# Compare the file count and image size, use the larger image
			if ($check_image_size > $image_size || $check_file_count > $file_count) {
				$directory_path = $check_directory_path;
			}
		}
		
		# Add the info for the winning directory to the top of the hash
		$partner_info{$partner}{file_paths} = $partner_info{$partner}{directory_paths}{$directory_path}{file_paths};
		$partner_info{$partner}{image_size} = $partner_info{$partner}{directory_paths}{$directory_path}{image_size};
		
		# Display the image size if any files were found
		if ($partner_info{$partner}{image_size}) {
			notify($ERRORS{'OK'}, 0, "$image_name exists on $partner_info{$partner}{hostname}, size: " . format_number($partner_info{$partner}{image_size}) . " bytes");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$image_name does NOT exist on $partner_info{$partner}{hostname}");
			next PARTNER;
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
	my $retrieval_partner_hostname = $partner_info{$retrieval_partner}{hostname};
	
	notify($ERRORS{'OK'}, 0, "selected random retrieval partner: $retrieval_partner_hostname:\n" . format_data($partner_info{$retrieval_partner}));
	
	# Create the directory in the image repository
	my $mkdir_command = "mkdir -pv $image_repository_path_local";
	my ($mkdir_exit_status, $mkdir_output) = run_command($mkdir_command);
	if (!defined($mkdir_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create image repository directory: $mkdir_command");
		return;
	}
	
	# Copy each file path to the image repository directory
	for my $partner_file_path (sort {lc($a) cmp lc($b)} keys %{$partner_info{$retrieval_partner}{file_paths}}) {
		my $file_name = $partner_info{$retrieval_partner}{file_paths}{$partner_file_path}{file_name};
		my $local_file_path = "$image_repository_path_local/$file_name";
		
		if (run_scp_command("$partner_info{$retrieval_partner}{user}\@$retrieval_partner:$partner_file_path", $local_file_path, $partner_info{$retrieval_partner}{key}, $partner_info{$retrieval_partner}{port})) {
			notify($ERRORS{'OK'}, 0, "image $image_name was copied from $retrieval_partner_hostname");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy image $image_name from $retrieval_partner_hostname");
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
	my $code_loop_result = $self->code_loop_timeout(
		sub{
			my $power_status = $self->power_status();
			if (!defined($power_status)) {
				return;
			}
			elsif ($power_status =~ /off/i) {
				return 1;
			}
			else {
				return 0;
			}
		},
		[$computer_name],
		"waiting for $computer_name to power off",
		$total_wait_seconds,
		$attempt_delay_seconds
	);
	
	if (!defined($code_loop_result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine power status of $computer_name, returning undefined");
		return;
	}
	elsif ($code_loop_result) {
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
