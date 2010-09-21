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

VCL::Provisioning::VMware::Vmware

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for VMWare
 http://www.vmware.com

=cut

##############################################################################
package VCL::Module::Provisioning::VMware::VMware;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use IO::File;
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw( tempfile );

use VCL::utils;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 %VM_OS_CONFIGURATION

 Data type   : hash
 Description : Maps OS names to the appropriate guestOS, Ethernet, and SCSI
					virtualDev values to be used in the vmx file.

=cut

our %VM_OS_CONFIGURATION = (
	# Linux configurations:
	"linux-x86" => {
		"guestOS" => "otherlinux",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "busLogic",
	},
	"linux-x86_64" => {
		"guestOS" => "otherlinux-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	# Windows configurations:
	"xp-x86" => {
		"guestOS" => "winXPPro",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "busLogic",
	},
	"xp-x86_64" => {
		"guestOS" => "winXPPro-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"vista-x86" => {
		"guestOS" => "winvista",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"vista-x86_64" => {
		"guestOS" => "winvista-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	}, 
	"7-x86" => {
		"guestOS" => "winvista",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"7-x86_64" => {
		"guestOS" => "winvista-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	}, 
	"2003-x86" => {
		"guestOS" => "winNetEnterprise",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "lsiLogic",
	},
	"2003-x86_64" => {
		"guestOS" => "winNetEnterprise-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"2008-x86" => {
		"guestOS" => "winServer2008Enterprise-32",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"2008-x86_64" => {
		"guestOS" => "winServer2008Enterprise-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	# Default Windows configuration if Windows version isn't found above:
	"windows-x86" => {
		"guestOS" => "winXPPro",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "busLogic",
	},
	"windows-x86_64" => {
		"guestOS" => "winXPPro-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	# Default configuration if OS is not Windows or Linux:
	"default-x86" => {
		"guestOS" => "other",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "busLogic",
	},
	"default-x86_64" => {
		"guestOS" => "other-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
);

=head2 $VSPHERE_SDK_PACKAGE

 Data type   : string
 Description : Perl package name for the vSphere SDK module.

=cut

our $VSPHERE_SDK_PACKAGE = 'VCL::Module::Provisioning::VMware::vSphere_SDK';

=head2 $VIX_API_PACKAGE

 Data type   : string
 Description : Perl package name for the VIX API module.

=cut

our $VIX_API_PACKAGE = 'VCL::Module::Provisioning::VMware::VIX_API';

=head2 $VIM_SSH_PACKAGE

 Data type   : string
 Description : Perl package name for the VIM SSH command module.

=cut

our $VIM_SSH_PACKAGE = 'VCL::Module::Provisioning::VMware::VIM_SSH';

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Determines how the VM and VM host can be contolled. Creates an
               API object which is used to control the VM throughout the
               reservation. Creates a VM host OS object to be used to control
               the VM host throughout the reservation.

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_data = $self->get_vmhost_datastructure() || return;
	my $vmhost_computer_name = $vmhost_data->get_computer_node_name() || return;
	my $vm_computer_name = $self->data->get_computer_node_name() || return;
	
	my $vmware_api;
	my $vmhost_os;
	
	# Create an API object which will be used to control the VM (register, power on, etc.)
	if ($vmware_api = $self->get_vmhost_api_object($VSPHERE_SDK_PACKAGE)) {
		if ($vmware_api->is_restricted()) {
			undef $vmware_api;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "vSphere SDK object will be used to control the VM: $vm_computer_name, and to control the OS of the VM host: $vmhost_computer_name");
			$vmhost_os = $vmware_api;
		}
	}
	
	if (!$vmhost_os) {
		# vSphere SDK is not available, SSH access to the VM host is required
		# Get a DataStructure object containing the VM host's data and get the VM host OS module Perl package name
		my $vmhost_image_name = $vmhost_data->get_image_name();
		my $vmhost_os_module_package = $vmhost_data->get_image_os_module_perl_package();
		
		notify($ERRORS{'DEBUG'}, 0, "attempting to create OS object for the image currently loaded on the VM host: $vmhost_computer_name\nimage name: $vmhost_image_name\nOS module: $vmhost_os_module_package");
		if ($vmhost_os = $self->get_vmhost_os_object($vmhost_os_module_package)) {
			notify($ERRORS{'DEBUG'}, 0, "created OS object to control the OS of VM host: $vmhost_computer_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create OS object to control the OS of VM host: $vmhost_computer_name");
			return;
		}
		
		# Check if SSH is responding
		if ($vmhost_os->is_ssh_responding()) {
			notify($ERRORS{'DEBUG'}, 0, "OS of VM host $vmhost_computer_name will be controlled via SSH using OS object: " . ref($vmhost_os));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to control OS of VM host $vmhost_computer_name using OS object: " . ref($vmhost_os) . ", VM host is not responding to SSH");
			return;
		}
	}
	
	# Store the VM host OS object in this object
	$self->{vmhost_os} = $vmhost_os;
	
	
	if (!$vmware_api) {
		if ($vmware_api = $self->get_vmhost_api_object($VIM_SSH_PACKAGE)) {
			notify($ERRORS{'DEBUG'}, 0, "VIM SSH command object will be used to control the VM: $vm_computer_name");
		}
		#elsif (($vmware_api = $self->get_vmhost_api_object($VIX_API_PACKAGE)) && !$vmware_api->is_restricted()) {
		#	notify($ERRORS{'DEBUG'}, 0, "VIX API object will be used to control the VM: $vm_computer_name");
		#}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create an API object to control the VM: $vm_computer_name");
			return;
		}
	}
	
	# Store the VM host API object in this object
	$self->{api} = $vmware_api;
	
	# Make sure the VMware product name can be retrieved
	$self->get_vmhost_product_name() || return;
	
	# Make sure the vmx and vmdk base directories can be accessed
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path() || return;
	if (!$vmhost_os->file_exists($vmx_base_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to access vmx base directory path: $vmx_base_directory_path");
		return;
	}
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path() || return;
	if (($vmx_base_directory_path ne $vmdk_base_directory_path) && !$vmhost_os->file_exists($vmdk_base_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to access vmdk base directory path: $vmdk_base_directory_path");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VMware provisioning object initialized:\nVM host OS object type: " . ref($self->{vmhost_os}) . "\nAPI object type: " . ref($self->{api}));
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  : none
 Returns     : boolean
 Description : Loads a VM with the requested image.

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = $self->data->get_reservation_id() || return;
	my $vmx_file_path = $self->get_vmx_file_path() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $vmhost_hostname = $self->data->get_vmhost_hostname() || return;

	insertloadlog($reservation_id, $computer_id, "doesimageexists", "image exists $image_name");
	
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_name $image_name");
	
	# Remove existing VMs which were created for the reservation computer
	if (!$self->remove_existing_vms()) {
		notify($ERRORS{'WARNING'}, 0, "failed to remove existing VMs created for computer $computer_name on VM host: $vmhost_hostname");
		return;
	}
	
	# Check if the .vmdk files exist, copy them if necessary
	if (!$self->prepare_vmdk()) {
		notify($ERRORS{'WARNING'}, 0, "failed to prepare vmdk file for $computer_name on VM host: $vmhost_hostname");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "transfervm", "copied $image_name to $computer_name");
	
	# Generate the .vmx file
	if (!$self->prepare_vmx()) {
		notify($ERRORS{'WARNING'}, 0, "failed to prepare vmx file for $computer_name on VM host: $vmhost_hostname");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "prepared vmx file");
	
	# Register the VM
	if (!$self->api->vm_register($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM $computer_name on VM host: $vmhost_hostname");
		return;
	}
	
	# Power on the VM
	if (!$self->api->vm_power_on($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to power on VM $computer_name on VM host: $vmhost_hostname");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "startvm", "registered and powered on $computer_name");
	
	# Call the OS module's post_load() subroutine if implemented
	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			$self->os->set_vcld_post_load_status();
			insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "performed OS post-load tasks on $computer_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on VM $computer_name on VM host: $vmhost_hostname");
			return;
		}
	}
	else {
		insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "OS post-load tasks not necessary on $computer_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : none
 Returns     : boolean
 Description : Captures a VM image.

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_hostname = $self->data->get_vmhost_hostname() || return;
	my $vmprofile_vmdisk = $self->data->get_vmhost_profile_vmdisk() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $vmhost_profile_datastore_path = normalize_file_path($self->data->get_vmhost_profile_datastore_path());
	
	# Check if VM is responding to SSH before proceeding
	if (!$self->os->is_ssh_responding()) {
		notify($ERRORS{'WARNING'}, 0, "unable to capture image, VM $computer_name is not responding to SSH");
		return;
	}
	
	# Determine the vmx file path actively being used by the VM
	my $vmx_file_path_capture = $self->get_active_vmx_file_path();
	if (!$vmx_file_path_capture) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the vmx file path actively being used by $computer_name");
		return;
	}

	# Set the vmx file path in this object so that it overrides the default value that would normally be constructed
	if (!$self->set_vmx_file_path($vmx_file_path_capture)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmx file to the path that was determined to be in use by the VM being captured: $vmx_file_path_capture");
		return;
	}
	
	# Get the vmx directory path of the VM being captured
	my $vmx_directory_path_capture = $self->get_vmx_directory_path();
	if (!$vmx_directory_path_capture) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the vmx directory path of the VM being captured");
		return;
	}
	
	# Get the information contained within the vmx file
	my $vmx_info = $self->get_vmx_info($vmx_file_path_capture);
	notify($ERRORS{'DEBUG'}, 0, "vmx info for VM to be captured:\n" . format_data($vmx_info));
	
	# Get the vmdk info from the vmx info
	my @vmdk_identifiers = keys %{$vmx_info->{vmdk}};
	if (!@vmdk_identifiers) {
		notify($ERRORS{'WARNING'}, 0, "did not find vmdk file in vmx info ({vmdk} key):\n" . format_data($vmx_info));
		return;
	}
	elsif (scalar(@vmdk_identifiers) > 1) {
		notify($ERRORS{'WARNING'}, 0, "found multiple vmdk files in vmx info ({vmdk} keys):\n" . format_data($vmx_info));
		return;
	}
	
	# Get the vmdk file path to be captured from the vmx information
	my $vmdk_file_path_capture = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{vmdk_file_path};
	if (!$vmdk_file_path_capture) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path to be captured was not found in the vmx file info:\n" . format_data($vmx_info));
		return;	
	}
	notify($ERRORS{'DEBUG'}, 0, "vmdk file path used by the VM to be captured: $vmdk_file_path_capture");
	
	# Get the vmdk mode from the vmx information and make sure it's persistent
	my $vmdk_mode = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{mode};
	if (!$vmdk_mode) {
		notify($ERRORS{'WARNING'}, 0, "vmdk mode was not found in the vmx info:\n" . format_data($vmx_info));
		return;	
	}
	elsif ($vmdk_mode !~ /^(independent-)?persistent/i) {
		notify($ERRORS{'WARNING'}, 0, "mode of vmdk '$vmdk_file_path_capture': $vmdk_mode, the mode must be persistent in order to be captured");
		return;	
	}
	notify($ERRORS{'DEBUG'}, 0, "mode of vmdk to be captured is valid: $vmdk_mode");
	
	# Set the vmdk file path in this object so that it overrides the default value that would normally be constructed
	if (!$self->set_vmdk_file_path($vmdk_file_path_capture)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmdk file to the path that was determined to be in use by the VM being captured: $vmdk_file_path_capture");
		return;
	}
	
	# Construct the vmdk file path where the captured image will be saved to
	my $vmdk_file_path_renamed = "$vmhost_profile_datastore_path/$image_name/$image_name.vmdk";
	
	# Make sure the vmdk file path for the captured image doesn't already exist
	# Do this before calling pre_capture and shutting down the VM
	if ($vmdk_file_path_capture ne $vmdk_file_path_renamed && $self->vmhost_os->file_exists($vmdk_file_path_renamed)) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file that captured image will be renamed to already exists: $vmdk_file_path_renamed");
		return;
	}
	
	# Write the details about the new image to ~/currentimage.txt
	if (!write_currentimage_txt($self->data)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create the currentimage.txt file on the VM being captured");
		return;
	}
	
	# Call the OS module's pre_capture() subroutine if implemented
	if ($self->os->can("pre_capture") && !$self->os->pre_capture({end_state => 'off'})) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete OS module's pre_capture tasks");
		return;
	}

	# Wait for the VM to power off
	# This OS module may initiate a shutdown and immediately return
	if (!$self->wait_for_power_off(600)) {
		notify($ERRORS{'WARNING'}, 0, "VM $computer_name has not powered off after the OS module's pre_capture tasks were completed, powering off VM forcefully");
		
		if ($self->api->vm_power_off($vmx_file_path_capture)) {
			# Sleep for 10 seconds to make sure the power off is complete
			sleep 10;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to power off the VM being captured after the OS module's pre_capture tasks were completed");
			return;
		}
	}
	
	# Rename the vmdk files on the VM host and change the vmdk directory name to the image name
	if ($vmx_file_path_capture ne $vmdk_file_path_renamed) {
		if (!$self->rename_vmdk($vmdk_file_path_capture, $vmdk_file_path_renamed)) {
			notify($ERRORS{'WARNING'}, 0, "failed to rename the vmdk files after the VM was powered off: '$vmdk_file_path_capture' --> '$vmdk_file_path_renamed'");
			return;
		}
		
		if (!$self->set_vmdk_file_path($vmdk_file_path_renamed)) {
			notify($ERRORS{'WARNING'}, 0, "failed to set the vmdk file to the path after renaming the vmdk files: $vmdk_file_path_renamed");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file does not need to be renamed: $vmx_file_path_capture");
	}
	
	# Get the renamed vmdk directory path
	my $vmdk_directory_path_renamed = $self->get_vmdk_directory_path();
	
	# Check if the VM host is using local or network-based disk to store vmdk files
	# Don't have to do anything else for network disk because the vmdk directory has already been renamed
	if ($vmprofile_vmdisk eq "localdisk") {
		# Copy the vmdk directory from the VM host to the image repository
		my @vmdk_copy_paths = $self->vmhost_os->find_files($vmdk_directory_path_renamed, '*.vmdk');
		if (!@vmdk_copy_paths) {
			notify($ERRORS{'WARNING'}, 0, "failed to find the renamed vmdk files on VM host to copy back to the managment node's image repository");
			return;
		}
		
		# Get the image repository directory path on this management node
		my $repository_directory_path = $self->get_repository_vmdk_directory_path();
		if (!$repository_directory_path) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve management node's image repository path");
			return;
		}
		
		# Loop through the files, copy each to the management node's repository directory
		for my $vmdk_copy_path (@vmdk_copy_paths) {
			my ($vmdk_copy_name) = $vmdk_copy_path =~ /([^\/]+)$/;
			if (!$self->vmhost_os->copy_file_from($vmdk_copy_path, "$repository_directory_path/$vmdk_copy_name")) {
				notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk file from the VM host to the management node:\n '$vmdk_copy_path' --> '$repository_directory_path/$vmdk_copy_name'");
				return;
			}
		}
		
		# Delete the vmdk directory on the VM host
		if ($vmdk_directory_path_renamed eq $vmx_directory_path_capture) {
			notify($ERRORS{'DEBUG'}, 0, "renamed vmdk directory will not be deleted yet because it matches the vmx directory path and the VM has not been unregistered yet: $vmdk_directory_path_renamed");
		}
		else {
			if ($self->vmhost_os->delete_file($vmdk_directory_path_renamed)) {
				notify($ERRORS{'OK'}, 0, "deleted the vmdk directory after files were copied to the image repository: $vmdk_directory_path_renamed");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to delete the vmdk directory after files were copied to the image repository: $vmdk_directory_path_renamed");
			}
		}
	}
	
	
	# Unregister the VM
	if ($self->api->vm_unregister($vmx_file_path_capture)) {
		notify($ERRORS{'OK'}, 0, "unregistered the VM being captured: $vmx_file_path_capture");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister the VM being captured: $vmx_file_path_capture");
	}
	
	
	# Delete the vmx directory
	if ($vmprofile_vmdisk eq "networkdisk" && $vmx_directory_path_capture eq $vmdk_directory_path_renamed) {
		notify($ERRORS{'DEBUG'}, 0, "vmx directory will not be deleted because the VM disk mode is '$vmprofile_vmdisk' and the vmx directory path is the same as the vmdk directory path for the captured image: '$vmdk_directory_path_renamed'");
	}
	else {
		if ($self->vmhost_os->delete_file($vmx_directory_path_capture)) {
			notify($ERRORS{'OK'}, 0, "deleted the vmx directory after the image was captured: $vmx_directory_path_capture");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to delete the vmx directory that was captured: $vmx_directory_path_capture");
		}
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_active_vmx_file_path

 Parameters  : none
 Returns     : string
 Description : Determines the path to the vmx file being used by the VM assigned
               to the reservation. It essentually does a reverse lookup to
               locate the VM's vmx file given a running VM. This is accomplished
               by retrieving the MAC addresses being used by the VM according to
               the OS. The MAC addresses configured within the vmx files on the
               host are then checked to locate a match. This allows an image
               capture to work if the VM was created by hand with a different
               vmx directory name or file name. This is useful to make base
               image capture easier with fewer restrictions.

=cut

sub get_active_vmx_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Get the MAC addresses being used by the running VM for this reservation
	my @vm_mac_addresses = ($self->os->get_private_mac_address(), $self->os->get_public_mac_address());
	if (!@vm_mac_addresses) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the private and public MAC address being used by VM $computer_name");
		return;
	}
	
	# Remove the colons from the MAC addresses and convert to lower case so they can be compared
	map { s/[^\w]//g; $_ = lc($_) } (@vm_mac_addresses);

	# Get an array containing the existing vmx file paths on the VM host
	my @host_vmx_file_paths = $self->get_vmx_file_paths();
	notify($ERRORS{'DEBUG'}, 0, "retrieved vmx file paths currently residing on the VM host:\n" . join("\n", @host_vmx_file_paths));
	
	# Sort the vmx file path list so that paths containing the computer name are checked first
	my @ordered_host_vmx_file_paths;
	push @ordered_host_vmx_file_paths, grep(/$computer_name\_/, @host_vmx_file_paths);
	push @ordered_host_vmx_file_paths, grep(!/$computer_name\_/, @host_vmx_file_paths);
	@host_vmx_file_paths = @ordered_host_vmx_file_paths;
	notify($ERRORS{'DEBUG'}, 0, "sorted vmx file paths so that directories containing $computer_name are checked first:\n" . join("\n", @host_vmx_file_paths));
	
	# Loop through the vmx files found on the VM host
	# Check if the MAC addresses in the vmx file match the MAC addresses currently in use on the VM to be captured
	my @matching_host_vmx_paths;
	for my $host_vmx_path (@host_vmx_file_paths) {
		# Quit checking if a match has already been found and the vmx path being checked doesn't contain the computer name
		last if (@matching_host_vmx_paths && $host_vmx_path !~ /$computer_name/);
		
		# Get the info from the existing vmx file on the VM host
		my $host_vmx_info = $self->get_vmx_info($host_vmx_path);
		if (!$host_vmx_info) {
			notify($ERRORS{'WARNING'}, 0, "unable to retrieve the info from existing vmx file on VM host: $host_vmx_path");
			next;
		}
		
		my $vmx_file_name = $host_vmx_info->{"vmx_file_name"} || '';
		
		# Create an array containing the values of any ethernetx.address or ethernetx.generatedaddress lines
		my @vmx_mac_addresses;
		for my $vmx_property (keys %{$host_vmx_info}) {
			if ($vmx_property =~ /^ethernet\d+\.(generated)?address$/i) {
				push @vmx_mac_addresses, $host_vmx_info->{$vmx_property};
			}
		}
		
		# Remove the colons from the MAC addresses and convert to lowercase so they can be compared
		map { s/[^\w]//g; $_ = lc($_) } (@vmx_mac_addresses);
		
		# Check if any elements of the VM MAC address array intersect with the vmx MAC address array
		notify($ERRORS{'DEBUG'}, 0, "comparing MAC addresses\nused by $computer_name:\n" . join("\n", sort(@vm_mac_addresses)) . "\nconfigured in $vmx_file_name:\n" . join("\n", sort(@vmx_mac_addresses)));
		my @matching_mac_addresses = map { my $vm_mac_address = $_; grep(/$vm_mac_address/i, @vmx_mac_addresses) } @vm_mac_addresses;
		
		if (!@matching_mac_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring $vmx_file_name because MAC addresses do not match the ones being used by $computer_name");
			next;
		}
		
		# Ignore the vmx file if it is not registered
		if (!$self->is_vm_registered($host_vmx_path)) {
			notify($ERRORS{'OK'}, 0, "ignoring $vmx_file_name because the VM is not registered");
			next;
		}
		
		# Ignore the vmx file if the VM is powered on
		my $power_state = $self->api->get_vm_power_state($host_vmx_path) || 'unknown';
		if ($power_state !~ /on/i) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring $vmx_file_name because the VM is not powered on");
			next;
		}
		
		
		notify($ERRORS{'DEBUG'}, 0, "found matching MAC address between $computer_name and $vmx_file_name:\n" . join("\n", sort(@matching_mac_addresses)));
		push @matching_host_vmx_paths, $host_vmx_path;
	}
	
	# Check if any matching vmx files were found
	if (!@matching_host_vmx_paths) {
		notify($ERRORS{'WARNING'}, 0, "did not find any vmx files on the VM host containing a MAC address matching $computer_name");
		return;
	}
	elsif (scalar(@matching_host_vmx_paths) > 1) {
		notify($ERRORS{'WARNING'}, 0, "found multiple vmx files on the VM host containing a MAC address matching $computer_name:\n" . join("\n", @matching_host_vmx_paths));
		return
	}
	
	my $matching_vmx_file_path = $matching_host_vmx_paths[0];
	notify($ERRORS{'OK'}, 0, "found vmx file being used by $computer_name: $matching_vmx_file_path");
	return $matching_vmx_file_path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : none
 Returns     : string -- 'READY', 'POST_LOAD', or 'RELOAD'
 Description : Checks the status of a VM. 'READY' is returned if the VM is
               accessible via SSH, the virtual disk mode is persistent if
               necessary, the image loaded matches the requested image, and the
               OS module's post-load tasks have run. 'POST_LOAD' is returned if
               the VM only needs to have the OS module's post-load tasks run
               before it is ready. 'RELOAD' is returned otherwise.

=cut

sub node_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	my $image_name = $self->data->get_image_name();
	my $vm_persistent = $self->is_vm_persistent();
	
	# Check if SSH is available
	if ($self->os->is_ssh_responding()) {
		notify($ERRORS{'DEBUG'}, 0, "VM $computer_name is responding to SSH");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "VM $computer_name is not responding to SSH, returning 'RELOAD'");
		return {'status' => 'RELOAD'};
	}
	
	# Get the contents of currentimage.txt and check if currentimage.txt matches the requested image name
	my $current_image_name = $self->os->get_current_image_name();
	if (!$current_image_name) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve image name from currentimage.txt on VM $computer_name, returning 'RELOAD'");
		return {'status' => 'RELOAD'};
	}
	elsif ($current_image_name eq $image_name) {
		notify($ERRORS{'DEBUG'}, 0, "currentimage.txt image ($current_image_name) matches requested image name ($image_name) on VM $computer_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "currentimage.txt image ($current_image_name) does not match requested image name ($image_name) on VM $computer_name, returning 'RELOAD'");
		return {'status' => 'RELOAD'};
	}
	
	# If the VM should be persistent, make sure the VM already loaded is persistent
	if ($vm_persistent) {
		# Determine the vmx file path actively being used by the VM
		my $vmx_file_path = $self->get_active_vmx_file_path();
		if (!$vmx_file_path) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine the vmx file path actively being used by $computer_name, returning 'RELOAD'");
			return {'status' => 'RELOAD'};
		}
	
		# Set the vmx file path in this object so that it overrides the default value that would normally be constructed
		if (!$self->set_vmx_file_path($vmx_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to set the vmx file to the path that was determined to be in use by the VM: $vmx_file_path, returning 'RELOAD'");
			return {'status' => 'RELOAD'};
		}
		
		# Get the information contained within the vmx file
		my $vmx_info = $self->get_vmx_info($vmx_file_path);
		
		# Get the vmdk info from the vmx info
		my @vmdk_identifiers = keys %{$vmx_info->{vmdk}};
		if (!@vmdk_identifiers) {
			notify($ERRORS{'WARNING'}, 0, "did not find vmdk file in vmx info ({vmdk} key), returning 'RELOAD':\n" . format_data($vmx_info));
			return {'status' => 'RELOAD'};
		}
		elsif (scalar(@vmdk_identifiers) > 1) {
			notify($ERRORS{'WARNING'}, 0, "found multiple vmdk files in vmx info ({vmdk} keys), returning 'RELOAD':\n" . format_data($vmx_info));
			return {'status' => 'RELOAD'};
		}
		
		# Get the vmdk file path from the vmx information
		my $vmdk_file_path = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{vmdk_file_path};
		if (!$vmdk_file_path) {
			notify($ERRORS{'WARNING'}, 0, "vmdk file path was not found in the vmx file info, returning 'RELOAD':\n" . format_data($vmx_info));
			return {'status' => 'RELOAD'};
		}
		notify($ERRORS{'DEBUG'}, 0, "vmdk file path used by the VM already loaded: $vmdk_file_path");
		
		# Get the vmdk mode from the vmx information and make sure it's persistent
		my $vmdk_mode = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{mode};
		if (!$vmdk_mode) {
			notify($ERRORS{'WARNING'}, 0, "vmdk mode was not found in the vmx info, returning 'RELOAD':\n" . format_data($vmx_info));
			return {'status' => 'RELOAD'};
		}
		
		if ($vmdk_mode !~ /^(independent-)?persistent/i) {
			notify($ERRORS{'OK'}, 0, "mode of vmdk already loaded is not persistent: $vmdk_mode, returning 'RELOAD'");
			return {'status' => 'RELOAD'};
		}
		notify($ERRORS{'DEBUG'}, 0, "mode of vmdk already loaded is valid: $vmdk_mode");
	}
	
	# Check if the OS post_load tasks have run
	if ($self->os->get_vcld_post_load_status()) {
		notify($ERRORS{'DEBUG'}, 0, "OS module post_load tasks have been completed on VM $computer_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "OS module post_load tasks have not been completed on VM $computer_name, returning 'POST_LOAD'");
		return {'status' => 'POST_LOAD'};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "returning 'READY'");
	return {'status' => 'READY'};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vmhost_os

 Parameters  : none
 Returns     : OS object reference
 Description : Returns the OS object that is used to control the VM host.

=cut

sub vmhost_os {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (!$self->{vmhost_os}) {
		notify($ERRORS{'WARNING'}, 0, "VM host OS object is not defined");
		return;
	}
	
	return $self->{vmhost_os};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 api

 Parameters  : none
 Returns     : API object reference
 Description : Returns the VMware API object that is used to control VMs on the
               VM host.

=cut

sub api {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (!$self->{api}) {
		notify($ERRORS{'WARNING'}, 0, "api object is not defined");
		return;
	}
	
	return $self->{api};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_datastructure

 Parameters  : none
 Returns     : DataStructure object reference
 Description : Returns a DataStructure object containing the data for the VM
               host. The computer and image data stored in the object describe
               the VM host computer, not the VM. All of the other data in the
               DataStore object matches the data for the regular reservation
               DataStructure object.

=cut

sub get_vmhost_datastructure {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_data = $self->data->get_request_data() || return;
	my $reservation_id = $self->data->get_reservation_id() || return;
	my $vmhost_computer_id = $self->data->get_vmhost_computer_id() || return;
	my $vmhost_profile_image_id = $self->data->get_vmhost_profile_image_id() || return;
	
	# Create a DataStructure object containing computer data for the VM host
	my $vmhost_data;
	eval {
		$vmhost_data= new VCL::DataStructure({request_data => $request_data,
																		 reservation_id => $reservation_id,
																		 computer_id => $vmhost_computer_id,
																		 image_id => $vmhost_profile_image_id});
	};
	
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure object for VM host, exception thrown, error: $EVAL_ERROR");
		return;
	}
	elsif (!$vmhost_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure object for VM host, DataStructure object is not defined");
		return;
	}
	
	# Get the VM host nodename from the DataStructure object which was created for it
	# This acts as a test to make sure the DataStructure object is working
	my $vmhost_computer_node_name = $vmhost_data->get_computer_node_name();
	if (!$vmhost_computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host node name from DataStructure object created for VM host");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "created DataStructure object for VM host: $vmhost_computer_node_name");
	$self->{vmhost_data} = $vmhost_data;
	return $vmhost_data;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_os_object

 Parameters  : $vmhost_os_perl_package (optional)
 Returns     : OS object reference
 Description : Creates an OS object to be used to control the VM host OS. An
               optional argument may be specified containing the Perl package to
               instantiate. If an argument is not specified, the Perl package of
               the image currently installed on the VM host computer is used.

=cut

sub get_vmhost_os_object {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the VM host OS object type argument
	my $vmhost_os_perl_package = shift;
	
	# Get a DataStructure object containing the VM host's data
	my $vmhost_data = $self->get_vmhost_datastructure() || return;
	
	# Check if the VM host OS object type was specified as an argument
	if (!$vmhost_os_perl_package) {
		# Get the VM host OS module Perl package name
		$vmhost_os_perl_package = $vmhost_data->get_image_os_module_perl_package();
		if (!$vmhost_os_perl_package) {
			notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure or OS object for VM host, failed to retrieve VM host image OS module Perl package name");
			return;
		}
	}
	
	# Load the VM host OS module if it is different than the one already loaded for the reservation image OS
	notify($ERRORS{'DEBUG'}, 0, "attempting to load VM host OS module: $vmhost_os_perl_package");
	eval "use $vmhost_os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "VM host OS module could NOT be loaded: $vmhost_os_perl_package, error: $EVAL_ERROR");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "VM host OS module loaded: $vmhost_os_perl_package");
	
	# Create an OS object for the VM host
	my $vmhost_os;
	eval { $vmhost_os = ($vmhost_os_perl_package)->new({data_structure => $vmhost_data}) };
	if ($vmhost_os) {
		notify($ERRORS{'OK'}, 0, "VM host OS object created: " . ref($vmhost_os));
		$self->{vmhost_os} = $vmhost_os;
		return $self->{vmhost_os};
	}
	elsif ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "VM host OS object could not be created: type: $vmhost_os_perl_package, error:\n$EVAL_ERROR");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "VM host OS object could not be created, type: $vmhost_os_perl_package, no eval error");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_api_object

 Parameters  : none
 Returns     : VMware API object
 Description : 

=cut

sub get_vmhost_api_object {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the Perl package argument
	my $api_perl_package = shift;
	if (!$api_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "API Perl package argument was not specified");
		return;
	}
	
	# Get a DataStructure object containing the VM host's data
	my $vmhost_datastructure = $self->get_vmhost_datastructure() || return;
	
	# Get the VM host nodename from the DataStructure object which was created for it
	# This acts as a test to make sure the DataStructure object is working
	my $vmhost_nodename = $vmhost_datastructure->get_computer_node_name();
	if (!$vmhost_nodename) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host node name from DataStructure object created for VM host");
		return;
	}
	
	# Load the VMware control module
	notify($ERRORS{'DEBUG'}, 0, "attempting to load VMware control module: $api_perl_package");
	eval "use $api_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to load VMware control module: $api_perl_package");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "loaded VMware control module: $api_perl_package");
	
	# Create an API object to control the VM host and VMs
	my $api;
	eval { $api = ($api_perl_package)->new({data_structure => $vmhost_datastructure, vmhost_os => $self->{vmhost_os}}) };
	if (!$api) {
		my $error = $EVAL_ERROR || 'no eval error';
		notify($ERRORS{'WARNING'}, 0, "API object could not be created: $api_perl_package, $error");
		return;
	}
	
	$api->{api} = $api;
	
	notify($ERRORS{'DEBUG'}, 0, "created API object: $api_perl_package");
	return $api;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_existing_vms

 Parameters  : none
 Returns     : boolean
 Description : 

=cut

sub remove_existing_vms {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name() || return;
	
	# Check the VMs on the host to see if any match the computer assigned to this reservation
	# Get an array containing the existing vmx file paths on the VM host
	my @vmx_file_paths = $self->get_vmx_file_paths();
	
	# Get a list of the registered VMs
	my @registered_vmx_paths = $self->api->get_registered_vms();
	
	# Loop through all registered vmx file paths
	# Make sure the vmx file actually exists for the registered VM
	# A VM will remain in the registered list if the vmx file is deleted while it is registered
	for my $registered_vmx_path (@registered_vmx_paths) {
		if (!grep { $_ eq $registered_vmx_path } @vmx_file_paths) {
			notify($ERRORS{'WARNING'}, 0, "VM is registered but the vmx file does not exist: $registered_vmx_path");
			
			# Unregister the zombie VM
			if (!$self->api->vm_unregister($registered_vmx_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to unregister zombie VM: $registered_vmx_path");
			}
		}
	}
	
	# Loop through the existing vmx file paths found, check if it matches the VM for this reservation
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	for my $vmx_file_path (@vmx_file_paths) {
		# Parse the vmx file name from the path
		my ($vmx_directory_name, $vmx_file_name) = $vmx_file_path =~ /([^\/]+)\/([^\/]+\.vmx)$/i;
		if (!$vmx_directory_name || !$vmx_file_name) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine vmx directory and file name from vmx file path: $vmx_file_path");
			next;
		}
		
		# Ignore file if it does not begin with the base directory path
		# get_vmx_file_paths() will return all vmx files it finds under the base directory path and all registered vmx files
		# It's possible for a vmx file to be registered that resided on some other datastore
		if ($vmx_file_path !~ /^$vmx_base_directory_path/) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring existing vmx file '$vmx_file_path' because it does not begin with the base directory path: '$vmx_base_directory_path'");
			next;
		}
		
		# Check if the vmx directory name matches the pattern:
		# <computer_short_name>_<image id>-v<imagerevision revision>
		# <computer_short_name>_<image id>-v<imagerevision revision>_<request id>
		if ($vmx_directory_name =~ /^$computer_name\_\d+-v\d+(_\d+)?$/i) {
			notify($ERRORS{'DEBUG'}, 0, "found existing vmx directory with that appears to match $computer_name: $vmx_file_path");
			
			# Get the info from the vmx file
			my $vmx_info = $self->get_vmx_info($vmx_file_path);
			if (!$vmx_info) {
				notify($ERRORS{'WARNING'}, 0, "unable to retrieve info from existing vmx file on VM host: $vmx_file_path");
				next;
			}
			
			# Delete the existing VM from the VM host
			if (!$self->delete_vm($vmx_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to delete existing VM: $vmx_file_path");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "ignoring existing vmx directory: $vmx_directory_name");
			next;
		}
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 prepare_vmx

 Parameters  : none
 Returns     : boolean
 Description : Creates a .vmx file on the VM host configured for the
               reservation. Checks if a VM for the same VCL computer entry is
               already registered. If the VM is already registered, it is
               unregistered and the files for the existing VM are deleted.

=cut

sub prepare_vmx {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the required data to configure the .vmx file
	my $image_id                 = $self->data->get_image_id() || return;
	my $imagerevision_id         = $self->data->get_imagerevision_id() || return;
	my $image_project            = $self->data->get_image_project() || return;
	my $computer_id              = $self->data->get_computer_id() || return;
	my $vmx_file_name            = $self->get_vmx_file_name() || return;
	my $vmx_file_path            = $self->get_vmx_file_path() || return;
	my $vmx_directory_name       = $self->get_vmx_directory_name() || return;
	my $vmx_directory_path       = $self->get_vmx_directory_path() || return;
	my $vmdk_file_path           = $self->get_vmdk_file_path() || return;
	my $computer_name            = $self->data->get_computer_short_name() || return;
	my $image_name               = $self->data->get_image_name() || return;
	my $vm_ram                   = $self->get_vm_ram() || return;
	my $vm_cpu_count             = $self->data->get_image_minprocnumber() || 1;
	my $vm_ethernet_adapter_type = $self->get_vm_ethernet_adapter_type() || return;
	my $vm_eth0_mac              = $self->data->get_computer_eth0_mac_address() || return;
	my $vm_eth1_mac              = $self->data->get_computer_eth1_mac_address() || return;	
	my $virtual_switch_0         = $self->data->get_vmhost_profile_virtualswitch0() || return;
	my $virtual_switch_1         = $self->data->get_vmhost_profile_virtualswitch1() || return;
	my $vm_disk_adapter_type     = $self->get_vm_disk_adapter_type() || return;
	my $vm_hardware_version      = $self->get_vm_virtual_hardware_version() || return;
	my $vm_persistent            = $self->is_vm_persistent();
	my $guest_os                 = $self->get_vm_guest_os() || return;
	
	## Figure out how much additional space is required for the vmx directory for the VM for this reservation
	## This is the number of additional bytes which have not already been allocated the VM will likely use
	#my $vm_additional_vmx_bytes_required = $self->get_vm_additional_vmx_bytes_required();
	#return if !defined($vm_additional_vmx_bytes_required);
	#
	## Get the number of bytes available on the device where the base vmx directory resides
	#my $host_vmx_bytes_available = $self->vmhost_os->get_available_space($self->get_vmx_base_directory_path());
	#return if !defined($host_vmx_bytes_available);
	#
	## Check if there is enough space available for the VM's vmx files
	#if ($vm_additional_vmx_bytes_required > $host_vmx_bytes_available) {
	#	my $vmx_deficit_bytes = ($vm_additional_vmx_bytes_required - $host_vmx_bytes_available);
	#	my $vmx_deficit_mb = format_number($vmx_deficit_bytes / 1024 / 1024);
	#	notify($ERRORS{'WARNING'}, 0, "not enough space is available for the vmx files on the VM host, deficit: $vmx_deficit_bytes bytes ($vmx_deficit_mb MB)");
	#}
	#else {
	#	notify($ERRORS{'DEBUG'}, 0, "enough space is available for the vmx files on the VM host");
	#}
	
	# Create the .vmx directory on the host
	if (!$self->vmhost_os->create_directory($vmx_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create .vmx directory on VM host: $vmx_directory_path");
		return;
	}
	
	# Set the disk parameters based on whether or not persistent mode is used
	# Also set the display name to distinguish persistent and non-persistent VMs
	my $display_name;
	my $vm_disk_mode;
	my $vm_disk_write_through;
	if ($vm_persistent) {
		$display_name = "$computer_name:$image_name (persistent)";
		$vm_disk_mode = 'independent-persistent';
		$vm_disk_write_through = "TRUE";
	}
	else {
		$display_name = "$computer_name:$image_name (nonpersistent)";
		$vm_disk_mode = "independent-nonpersistent";
		#$vm_disk_mode = "undoable";
		$vm_disk_write_through = "FALSE";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "vm info:
			 display name: $display_name
			 
			 image ID: $image_id
			 imagerevision ID: $imagerevision_id
			 
			 vmx path: $vmx_file_path
			 vmx directory name: $vmx_directory_name
			 vmx directory path: $vmx_directory_path
			 vmdk file path: $vmdk_file_path
			 persistent: $vm_persistent
			 computer ID: $computer_id
			 computer name: $computer_name
			 image name: $image_name
			 guest OS: $guest_os
			 virtual hardware version: $vm_hardware_version
			 RAM: $vm_ram
			 CPU count: $vm_cpu_count
			 
			 ethernet adapter type: $vm_ethernet_adapter_type
			 
			 virtual switch 0: $virtual_switch_0
			 eth0 MAC address: $vm_eth0_mac
			 
			 virtual switch 1: $virtual_switch_1
			 eth1 MAC address: $vm_eth1_mac
			 
			 disk adapter type: $vm_disk_adapter_type
			 disk mode: $vm_disk_mode
			 disk write through: $vm_disk_write_through"
	);
	
	# Create a hash containing the vmx parameter names and values
	my %vmx_parameters = (
		"#image_id" => "$image_id",
		"#imagerevision_id" => "$imagerevision_id",
		"#computer_id" => "$computer_id",
		
		".encoding" => "UTF-8",
		
		"config.version" => "8",
		
		"disk.locking" => "false",
		
		"displayName" => "$display_name",
		
		"ethernet0.address" => "$vm_eth0_mac",
		"ethernet0.addressType" => "static",
		"ethernet0.present" => "TRUE",
		"ethernet0.virtualDev" => "$vm_ethernet_adapter_type",
		"ethernet0.networkName" => "$virtual_switch_0",
		
		"ethernet1.address" => "$vm_eth1_mac",
		"ethernet1.addressType" => "static",
		"ethernet1.present" => "TRUE",
		"ethernet1.virtualDev" => "$vm_ethernet_adapter_type",
		"ethernet1.networkName" => "$virtual_switch_1",
		
		"floppy0.present" => "FALSE",
		
		"guestOS" => "$guest_os",
		
		"gui.exitOnCLIHLT" => "TRUE",	# causes the virtual machine to power off automatically when you choose Start > Shut Down from the Windows guest
		
		"memsize" => "$vm_ram",
		
		"msg.autoAnswer" => "TRUE",	# tries to automatically answer all questions that may occur at boot-time.
		
		"numvcpus" => "$vm_cpu_count",
		
		"powerType.powerOff" => "soft",
		"powerType.powerOn" => "hard",
		"powerType.reset" => "soft",
		"powerType.suspend" => "hard",
		
		"snapshot.disabled" => "TRUE",
		
		"tools.remindInstall" => "TRUE",
		"tools.syncTime" => "FALSE",
		
		"toolScripts.afterPowerOn" => "TRUE",
		"toolScripts.afterResume" => "TRUE",
		"toolScripts.beforeSuspend" => "TRUE",
		"toolScripts.beforePowerOff" => "TRUE",
		
		"uuid.action" => "keep",	# Keep the VM's uuid, keeps existing MAC								
		
		"virtualHW.version" => "$vm_hardware_version",
	);
	
	# Add the disk adapter parameters to the hash
	if ($vm_disk_adapter_type =~ /ide/i) {
		%vmx_parameters = (%vmx_parameters, (
			"ide0:0.fileName" => "$vmdk_file_path",
			"ide0:0.mode" => "$vm_disk_mode",
			"ide0:0.present" => "TRUE",
			"ide0:0.writeThrough" => "$vm_disk_write_through",
		));
	}
	else {
		%vmx_parameters = (%vmx_parameters, (
			"scsi0.present" => "TRUE",
			"scsi0.virtualDev" => "$vm_disk_adapter_type",
			"scsi0:0.fileName" => "$vmdk_file_path",
			"scsi0:0.mode" => "$vm_disk_mode",
			"scsi0:0.present" => "TRUE",
			"scsi0:0.writeThrough" => "$vm_disk_write_through",
		));
	}
	
	if ($vm_hardware_version >= 7) {
		%vmx_parameters = (%vmx_parameters, (
			"pciBridge0.present" => "TRUE",
			"pciBridge4.present" => "TRUE",
			"pciBridge4.virtualDev" => "pcieRootPort",
			"pciBridge4.functions" => "8",
			"pciBridge5.present" => "TRUE",
			"pciBridge5.virtualDev" => "pcieRootPort",
			"pciBridge5.functions" => "8",
			"pciBridge6.present" => "TRUE",
			"pciBridge6.virtualDev" => "pcieRootPort",
			"pciBridge6.functions" => "8",
			"pciBridge7.present" => "TRUE",
			"pciBridge7.virtualDev" => "pcieRootPort",
			"pciBridge7.functions" => "8",
			"vmci0.present" => "TRUE",
		));
	}
	
	# Add additional Ethernet interfaces if the image project name is not vcl
	if ($image_project !~ /^vcl$/i) {
		notify($ERRORS{'DEBUG'}, 0, "image project is: $image_project, checking if additional network adapters should be configured");
		
		# Get a list of all the network names configured on the VMware host
		my @network_names = $self->api->get_network_names();
		notify($ERRORS{'DEBUG'}, 0, "retrieved network names configured on the VM host: " . join(", ", @network_names));
		
		# Check each network name
		# Begin the index at 2 for additional interfaces added because ethernet0 and ethernet1 have already been added
		my $interface_index = 2;
		for my $network_name (@network_names) {
			# Ignore network names which have already been added
			if ($network_name =~ /^($virtual_switch_0|$virtual_switch_1)$/) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring network name because it is already being used for the private or public interface: $network_name");
				next;
			}
			elsif ($network_name =~ /$image_project/i || $image_project =~ /$network_name/i) {
				notify($ERRORS{'DEBUG'}, 0, "network name ($network_name) and image project name ($image_project) intersect, adding network interface to VM for network $network_name");
				
				$vmx_parameters{"ethernet$interface_index.addressType"} = "generated";
				$vmx_parameters{"ethernet$interface_index.present"} = "TRUE";
				$vmx_parameters{"ethernet$interface_index.virtualDev"} = "$vm_ethernet_adapter_type";
				$vmx_parameters{"ethernet$interface_index.networkName"} = "$network_name";
				
				$interface_index++;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "network name ($network_name) and image project name ($image_project) do not intersect, network interface will not be added to VM for network $network_name");
			}
		}
		
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image project is: $image_project, additional network adapters will not be configured");
	}
	
	notify($ERRORS{'DEBUG'}, 0, "vmx parameters:\n" . format_data(\%vmx_parameters));
	
	# Create a string from the hash
	my $vmx_contents = "#!/usr/bin/vmware\n";
	map { $vmx_contents .= "$_ = \"$vmx_parameters{$_}\"\n" } sort keys %vmx_parameters;
	
	# Create a temporary vmx file on this managment node in /tmp
	my $temp_vmx_file_path = "/tmp/$vmx_file_name";
	if (open VMX_TEMP, ">", $temp_vmx_file_path) {
		print VMX_TEMP $vmx_contents;
		close VMX_TEMP;
		notify($ERRORS{'DEBUG'}, 0, "created temporary vmx file: $temp_vmx_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create temporary vmx file: $temp_vmx_file_path, error: @!");
		return;
	}
	
	# Copy the temporary vmx file the the VM host
	$self->vmhost_os->copy_file_to($temp_vmx_file_path, $vmx_file_path) || return;
	notify($ERRORS{'OK'}, 0, "created vmx file on VM host: $vmx_file_path");
	
	# Delete the temporary vmx file
	if	(unlink $temp_vmx_file_path) {
		notify($ERRORS{'DEBUG'}, 0, "deleted temporary vmx file: $temp_vmx_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete temporary vmx file: $temp_vmx_file_path, error: $!");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 prepare_vmdk

 Parameters  : none
 Returns     : boolean
 Description : Prepares the .vmdk files on the VM host. This subroutine
               determines whether or not the vmdk files need to be copied to the
               VM host.

=cut

sub prepare_vmdk {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $host_vmdk_directory_path = $self->get_vmdk_directory_path() || return;
	my $host_vmdk_file_path = $self->get_vmdk_file_path() || return;
	my $host_vmdk_file_path_nonpersistent = $self->get_vmdk_file_path_nonpersistent() || return;
	
	my $repository_vmdk_directory_path = $self->get_repository_vmdk_directory_path() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $vmhost_hostname = $self->data->get_vmhost_hostname() || return;
	
	my $is_vm_persistent = $self->is_vm_persistent();
	
	# Check if the first .vmdk file exists on the host
	if ($self->vmhost_os->file_exists($host_vmdk_file_path)) {
		
		if ($is_vm_persistent) {
			notify($ERRORS{'DEBUG'}, 0, "VM is persistent and vmdk file already exists on VM host: $host_vmdk_file_path, vmdk file will be deleted and a new copy will be used");
			exit;
			if (!$self->vmhost_os->delete_file($host_vmdk_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to deleted existing vmdk file: ");
				return;
			}
		}
		else {
			# vmdk file exists and not persistent
			# No copying necessary, proceed to check the disk type
			return $self->check_vmdk_disk_type();
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file does NOT exist on VM host: $host_vmdk_file_path");
	}
	
	## Figure out how much additional space is required for the vmdk directory for the VM for this reservation
	## This is the number of additional bytes which have not already been allocated the VM will likely use
	## The subroutine checks if the vmdk files already exist on the VM host
	#my $vm_additional_vmdk_bytes_required = $self->get_vm_additional_vmdk_bytes_required();
	#return if !defined($vm_additional_vmdk_bytes_required);
	#
	## Get the number of bytes available on the device where the base vmdk directory resides
	#my $host_vmdk_bytes_available = $self->vmhost_os->get_available_space($self->get_vmdk_base_directory_path());
	#return if !defined($host_vmdk_bytes_available);
	#
	## Check if there is enough space available for the VM's vmdk files
	#if ($vm_additional_vmdk_bytes_required > $host_vmdk_bytes_available) {
	#	my $vmdk_deficit_bytes = ($vm_additional_vmdk_bytes_required - $host_vmdk_bytes_available);
	#	my $vmdk_deficit_mb = format_number($vmdk_deficit_bytes / 1024 / 1024);
	#	notify($ERRORS{'WARNING'}, 0, "not enough space is available for the vmdk files on the VM host, deficit: $vmdk_deficit_bytes bytes ($vmdk_deficit_mb MB)");
	#	return;
	#}
	#else {
	#	notify($ERRORS{'DEBUG'}, 0, "enough space is available for the vmdk files on the VM host");
	#}
	
	# Check if the VM is persistent, if so, attempt to copy files locally from the nonpersistent directory if they exist
	if ($is_vm_persistent && $self->vmhost_os->file_exists($host_vmdk_file_path_nonpersistent)) {
		# Attempt to use the API's copy_virtual_disk subroutine
		if ($self->api->can('copy_virtual_disk') && $self->api->copy_virtual_disk($host_vmdk_file_path_nonpersistent, $host_vmdk_file_path)) {
			notify($ERRORS{'OK'}, 0, "copied vmdk files from nonpersistent to persistent directory on VM host");
			return $self->check_vmdk_disk_type();
		}
		else {
			# Unable to use the API's copy_virtual_disk subroutine, use VM host OS's copy_file subroutine
			my $host_vmdk_directory_path_nonpersistent = $self->get_vmdk_directory_path_nonpersistent() || return;
			
			my $vmdk_file_prefix = $self->get_vmdk_file_prefix() || return;
			
			if (my @vmdk_nonpersistent_file_paths = $self->vmhost_os->find_files($host_vmdk_directory_path_nonpersistent, "$vmdk_file_prefix*.vmdk")) {
				my $start_time = time;
				
				# Loop through the files, copy each file from the non-persistent directory to the persistent directory
				for my $vmdk_nonpersistent_file_path (sort @vmdk_nonpersistent_file_paths) {
					# Extract the file name from the path
					my ($vmdk_copy_file_name) = $vmdk_nonpersistent_file_path =~ /([^\/]+)$/g;
					
					# Attempt to copy the file on the VM host
					if (!$self->vmhost_os->copy_file($vmdk_nonpersistent_file_path, "$host_vmdk_directory_path/$vmdk_copy_file_name")) {
						notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk file from the non-persistent to the persistent directory on the VM host:\n'$vmdk_nonpersistent_file_path' --> '$host_vmdk_directory_path/$vmdk_copy_file_name'");
						return;
					}
				}
				
				# All vmdk files were copied
				my $duration = (time - $start_time);
				notify($ERRORS{'OK'}, 0, "copied vmdk files from nonpersistent to persistent directory on VM host, took " . format_number($duration) . " seconds");
				return $self->check_vmdk_disk_type();
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "non-persistent set of vmdk files does not exist: '$host_vmdk_directory_path_nonpersistent'");
			}
		}
	}
	
	# VM is either non-persistent or persistent and could not copy files from existing non-persistent directory
	# Copy the vmdk files from the image repository to the vmdk directory
	my $start_time = time;
	
	# Find the vmdk file paths in the image repository directory
	my @vmdk_repository_file_paths;
	my $command = "find \"$repository_vmdk_directory_path\" -type f -iname \"*.vmdk\"";
	my ($exit_status, $output) = run_command($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to find files in image repository directory: '$repository_vmdk_directory_path', pattern: '*.vmdk', command:\n$command");
		return;
	}
	elsif (grep(/(^find:.*no such file)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "directory does not exist in image repository: '$repository_vmdk_directory_path'");
		return;
	}
	elsif (grep(/(^find: |syntax error|unexpected EOF)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to find files in image repository directory: '$repository_vmdk_directory_path', pattern: '*.vmdk', command: $command, output:\n" . join("\n", @$output));
		return;
	}
	else {
		@vmdk_repository_file_paths = @$output;
		map { chomp $_ } @vmdk_repository_file_paths;
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@vmdk_repository_file_paths) . " vmdk files in image repository directory: '$repository_vmdk_directory_path':\n" . join("\n", sort @vmdk_repository_file_paths));
	}
	
	# Loop through the files, copy each from the management node's repository directory to the VM host
	for my $vmdk_repository_file_path (sort @vmdk_repository_file_paths) {
		my ($vmdk_copy_name) = $vmdk_repository_file_path =~ /([^\/]+)$/g;
		if (!$self->vmhost_os->copy_file_to($vmdk_repository_file_path, "$host_vmdk_directory_path/$vmdk_copy_name")) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk file from the repository to the VM host: '$vmdk_repository_file_path' --> '$host_vmdk_directory_path/$vmdk_copy_name'");
			return;
		}
	}
	my $duration = (time - $start_time);
	notify($ERRORS{'OK'}, 0, "copied vmdk files from management node image repository to the VM host, took " . format_number($duration) . " seconds");
	
	return $self->check_vmdk_disk_type();
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_vmdk_disk_type

 Parameters  : none
 Returns     : boolean
 Description : Determines if the vmdk disk type is compatible with the VMware
               product being used on the VM host. This subroutine currently only
               checks if ESX is being used and the vmdk disk type is flat. If
               using ESX and the disk type is not flat, a copy of the vmdk is
               created using the thin virtual disk type in the same directory as
               the incompatible vmdk directory. The name of the copied vmdk file
               is the same as the incompatible vmdk file with 'thin_' inserted
               at the beginning. Example:
               'vmwarewinxp-base1-v0.vmdk' --> 'thin_vmwarewinxp-base1-v0.vmdk'
               
               This subroutine returns true unless ESX is being used, the
               virtual disk type is not flat, and a thin copy cannot be created.

=cut

sub check_vmdk_disk_type {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_file_path = $self->get_vmdk_file_path() || return;
	
	# Check if the API object implements the required subroutines
	unless ($self->api->can("get_virtual_disk_type") && $self->api->can("copy_virtual_disk")) {
		notify($ERRORS{'DEBUG'}, 0, "skipping vmdk disk type check because required subroutines are not implemented by the API object");
		return 1;
	}
	
	# Retrieve the VMware product name
	my $vmware_product_name = $self->get_vmhost_product_name();
	if (!$vmware_product_name) {
		notify($ERRORS{'DEBUG'}, 0, "skipping vmdk disk type check because VMware product name could not be retrieved from the API object");
		return 1;
	}
	
	# Retrieve the virtual disk type from the API object
	my $virtual_disk_type = $self->api->get_virtual_disk_type($vmdk_file_path);
	if (!$virtual_disk_type) {
		notify($ERRORS{'DEBUG'}, 0, "skipping vmdk disk type check because virtual disk type could not be retrieved from the API object");
		return 1;
	}
	
	if ($vmware_product_name =~ /esx/i) {
		if ($virtual_disk_type !~ /flat/i) {
			notify($ERRORS{'DEBUG'}, 0, "virtual disk type is not compatible with $vmware_product_name: $virtual_disk_type");
			
			my $vmdk_file_path = $self->get_vmdk_file_path() || return;
			my $vmdk_directory_path = $self->get_vmdk_directory_path() || return;
			my $vmdk_file_prefix = $self->get_vmdk_file_prefix() || return;
			my $thin_vmdk_file_path = "$vmdk_directory_path/thin_$vmdk_file_prefix.vmdk";
			
			if ($self->vmhost_os->file_exists($thin_vmdk_file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "thin virtual disk already exists: $thin_vmdk_file_path");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "attempting to create a copy of the virtual disk using the thin virtual disk type: $thin_vmdk_file_path");
				
				# Attempt to create a thin copy of the virtual disk
				if ($self->api->copy_virtual_disk($vmdk_file_path, $thin_vmdk_file_path, 'thin')) {
					notify($ERRORS{'DEBUG'}, 0, "created a copy of the virtual disk using the thin virtual disk type: $thin_vmdk_file_path");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to create a copy of the virtual disk using the thin virtual disk type: $thin_vmdk_file_path");
					return;
				}
			}
			
			# Update this object to use the thin vmdk file path
			if ($self->set_vmdk_file_path($thin_vmdk_file_path)) {
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to update the VMware module object to use the thin virtual disk path");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "flat virtual disk ($virtual_disk_type) does not need to be converted for $vmware_product_name");
			return 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "skipping vmdk disk type check because VMware product is not ESX: $vmware_product_name");
		return 1;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the path to the vmx file being used for the reservation.
               Example:
               /vmfs/volumes/local-datastore/vclv1-29_vmwarewin7-Test75321-v0/vclv1-29_vmwarewin7-Test75321-v0.vmx

=cut

sub get_vmx_file_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $ENV{vmx_file_path} if $ENV{vmx_file_path};
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	if (!$vmx_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmx file path, vmx base directory path could not be determined");
		return;
	}
	
	my $vmx_directory_name = $self->get_vmx_directory_name();
	if (!$vmx_directory_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmx file path, vmx directory name could not be determined");
		return;
	}
	
	return "$vmx_base_directory_path/$vmx_directory_name/$vmx_directory_name.vmx";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_base_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the path on the VM host under which the vmx directory is
               located.
               Example:
               /vmfs/volumes/local-datastore

=cut

sub get_vmx_base_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_base_directory_path;
	
	# Check if vmx_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmx file name and directory name
	# /<vmx base directory path>/<vmx directory name>/<vmx file name>
	if ($ENV{vmx_file_path}) {
		($vmx_base_directory_path) = $ENV{vmx_file_path} =~ /(.+)\/[^\/]+\/[^\/]+.vmx$/i;
		if ($vmx_base_directory_path) {
			return $vmx_base_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmx base directory path could not be determined from vmx file path: '$ENV{vmx_file_path}'");
			return;
		}
	}
	
	# Get the vmprofile.vmpath
	# If this is not set, use vmprofile.datastorepath
	$vmx_base_directory_path = $self->data->get_vmhost_profile_vmpath() || $self->data->get_vmhost_profile_datastore_path();
	if (!$vmx_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmdk base directory path, failed to retrieve either the VM path or datastore path for the VM profile");
		return;
	}
	
	return normalize_file_path($vmx_base_directory_path);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_directory_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory in which the .vmx file is
               located.  The name differs depending on whether or not the VM
               is persistent.
               If not persistent: <computer name>_<image name>
               If persistent: <computer name>_<image name>_<request ID>

=cut

sub get_vmx_directory_name {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_directory_name;
	
	# Check if vmx_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmx file name
	# /<vmx base directory path>/<vmx directory name>/<vmx file name>
	if ($ENV{vmx_file_path}) {
		($vmx_directory_name) = $ENV{vmx_file_path} =~ /([^\/]+)\/[^\/]+.vmx$/i;
		if ($vmx_directory_name) {
			return $vmx_directory_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmx directory name could not be determined from vmx file path: '$ENV{vmx_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_persistent()) {
		return $self->get_vmx_directory_name_persistent();
	}
	else {
		return $self->get_vmx_directory_name_nonpersistent();
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_directory_name_persistent

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory in which the .vmx file is
               located if the VM is persistent. Example:
					<computer name>_<image name>

=cut

sub get_vmx_directory_name_persistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_directory_name_nonpersistent = $self->get_vmx_directory_name_nonpersistent();
	if (!$vmx_directory_name_nonpersistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the persistent vmx directory name, failed to retrieve the nonpersistent vmx directory name on which the persistent vmx directory name is based");
		return;
	}
	
	my $request_id = $self->data->get_request_id();
	if (!defined($request_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the persistent vmx directory name, failed to retrieve request ID");
		return;
	}
	
	return $vmx_directory_name_nonpersistent;
	#return "$vmx_directory_name_nonpersistent\_$request_id";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_directory_name_nonpersistent

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory in which the .vmx file is
               located if the VM is not persistent.
               Example:
               <computer name>_<image name>_<request ID>

=cut

sub get_vmx_directory_name_nonpersistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name
	my $computer_short_name = $self->data->get_computer_short_name();
	if (!$computer_short_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the nonpersistent vmx directory name, failed to retrieve computer short name");
		return;
	}
	
	# Get the image ID
	my $image_id = $self->data->get_image_id();
	if (!defined($image_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the nonpersistent vmx directory name, failed to retrieve image ID");
		return;
	}
	
	# Get the image revision number
	my $image_revision = $self->data->get_imagerevision_revision();
	if (!defined($image_revision)) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the nonpersistent vmx directory name, failed to retrieve image revision");
		return;
	}
	
	# Assemble the directory name
	return "$computer_short_name\_$image_id-v$image_revision";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the path on the VM host under which the vmx file is
               located.  Example:
               vmx file path: /vmfs/volumes/nfs-vmpath/vm1-6-987-v0/vm1-6-987-v0.vmx
               vmx directory path: /vmfs/volumes/nfs-vmpath/vm1-6-987-v0

=cut

sub get_vmx_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path
	my $vmx_file_path = $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx directory path could not be determined because vmx file path could not be retrieved");
		return;
	}
	
	# Parse the vmx file path, return the path preceding the vmx file name
	my ($vmx_directory_path) = $vmx_file_path =~ /(.+)\/[^\/]+.vmx$/i;
	if ($vmx_directory_path) {
		return $vmx_directory_path;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "vmx directory path could not be determined from vmx file path: '$vmx_file_path'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_file_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the .vmx file.  Example:
               vmx file path: /vmfs/volumes/nfs-vmpath/vm1-6-987-v0/vm1-6-987-v0.vmx
               vmx file name: vm1-6-987-v0.vmx

=cut

sub get_vmx_file_name {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path
	my $vmx_file_path = $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx directory path could not be determined because vmx file path could not be retrieved");
		return;
	}
	
	# Parse the vmx file path, return the path preceding the vmx file name
	my ($vmx_file_name) = $vmx_file_path =~ /\/([^\/]+.vmx)$/i;
	if ($vmx_file_name) {
		return $vmx_file_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "vmx file name could not be determined from vmx file path: '$vmx_file_path'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_vmx_file_path

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Sets the vmx path into %ENV so that the default values are
               overridden when the various get_vmx_ subroutines are called. This
               is useful when a base image is being captured. The vmx file does
               not need to be in the expected directory nor does it need to be
               named anything particular. The code locates the vmx file and then
               saves the non-default path in this object so that capture works
               regardless of the vmx path/name.

=cut

sub set_vmx_file_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path_argument = shift;
	if (!$vmx_file_path_argument) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	$vmx_file_path_argument = normalize_file_path($vmx_file_path_argument);
	
	# Make sure the vmx file path format is valid
	if ($vmx_file_path_argument !~ /^\/.+\/.+\/[^\/]+\.vmx$/i) {
		notify($ERRORS{'WARNING'}, 0, "unable to override vmx file path because the path format is invalid: '$vmx_file_path_argument'");
		return;
	}
	
	$ENV{vmx_file_path} = $vmx_file_path_argument;
	
	# Check all of the vmx file path components
	if ($self->check_file_paths('vmx')) {
		# Set the vmx_file_path environment variable
		notify($ERRORS{'OK'}, 0, "set overridden vmx file path: '$vmx_file_path_argument'");
		return 1;
	}
	else {
		delete $ENV{vmx_file_path};
		notify($ERRORS{'WARNING'}, 0, "failed to set overridden vmx file path: '$vmx_file_path_argument'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the path of the vmdk file. Example:
               vmdk file path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk

=cut

sub get_vmdk_file_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $ENV{vmdk_file_path} if $ENV{vmdk_file_path};
	
	if ($self->is_vm_persistent()) {
		return $self->get_vmdk_file_path_persistent();
	}
	else {
		return $self->get_vmdk_file_path_nonpersistent();
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_path_persistent

 Parameters  : none
 Returns     : string
 Description : Returns the vmdk file path for a persistent VM. This is
               useful when checking the image size on a VM host using
               network-based disks. It returns the vmdk file path that would be
               used for nonperistent VMs.

=cut

sub get_vmdk_file_path_persistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmprofile.datastorepath
	my $vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the persistent vmdk file path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_persistent = $self->get_vmdk_directory_name_persistent();
	if (!$vmdk_directory_name_persistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmdk file path, vmdk directory name could not be determined");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmdk file path, image name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_persistent/$image_name.vmdk";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_path_nonpersistent

 Parameters  : none
 Returns     : string
 Description : Returns the vmdk file path for a nonpersistent VM. This is
               useful when checking the image size on a VM host using
               network-based disks. It returns the vmdk file path that would be
               used for nonperistent VMs.

=cut

sub get_vmdk_file_path_nonpersistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmprofile.datastorepath
	my $vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the nonpersistent vmdk file path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_nonpersistent = $self->get_vmdk_directory_name_nonpersistent();
	if (!$vmdk_directory_name_nonpersistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmdk file path, vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_nonpersistent/$vmdk_directory_name_nonpersistent.vmdk";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_base_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the directories which
               store the .vmdk files are located.  Example:
               vmdk file path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               vmdk base directory path: /vmfs/volumes/nfs-datastore

=cut

sub get_vmdk_base_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_base_directory_path;
	
	# Check if vmdk_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmdk file name and directory name
	# /<vmdk base directory path>/<vmdk directory name>/<vmdk file name>
	if ($ENV{vmdk_file_path}) {
		($vmdk_base_directory_path) = $ENV{vmdk_file_path} =~ /(.+)\/[^\/]+\/[^\/]+.vmdk$/i;
		if ($vmdk_base_directory_path) {
			return $vmdk_base_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk base directory path could not be determined from vmdk file path: '$ENV{vmdk_file_path}'");
			return;
		}
	}
	
	# Get the vmprofile.datastorepath
	$vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmdk base directory path, failed to retrieve either the datastore path for the VM profile");
		return;
	}
	
	return normalize_file_path($vmdk_base_directory_path);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located. The name differs depending on whether or not the
               VM is persistent.
               If not persistent: <image name>
               If persistent: <computer name>_<image ID>-<revision>_<request ID>
               Example:
               vmdk directory path persistent: vmwarewinxp-base234-v12
               vmdk directory path non-persistent: vm1-6_987-v0_5435

=cut

sub get_vmdk_directory_name {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if vmdk_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmdk file name
	# /<vmdk base directory path>/<vmdk directory name>/<vmdk file name>
	if ($ENV{vmdk_file_path}) {
		my ($vmdk_directory_name) = $ENV{vmdk_file_path} =~ /([^\/]+)\/[^\/]+.vmdk$/i;
		if ($vmdk_directory_name) {
			return $vmdk_directory_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk directory name could not be determined from vmdk file path: '$ENV{vmdk_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_persistent()) {
		return $self->get_vmdk_directory_name_persistent();
	}
	else {
		return $self->get_vmdk_directory_name_nonpersistent();
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name_persistent

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located if the VM is persistent:
               <computer name>_<image ID>-<revision>_<request ID>

=cut

sub get_vmdk_directory_name_persistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Use the same name that's used for the persistent vmx directory name
	my $vmdk_directory_name_persistent = $self->get_vmx_directory_name_persistent();
	if ($vmdk_directory_name_persistent) {
		return $vmdk_directory_name_persistent;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine persistent vmdk directory name because persistent vmx directory name could not be retrieved");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name_nonpersistent

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located if the VM is not persistent:
               <image name>

=cut

sub get_vmdk_directory_name_nonpersistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Use the image name for the vmdk directory name
	my $image_name = $self->data->get_image_name();
	if ($image_name) {
		return $image_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable determine vmdk nonpersistent vmdk directory name because image name could not be retrieved");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the .vmdk files are
               located.  Example:
               vmdk file path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               vmdk directory path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12

=cut

sub get_vmdk_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if vmdk_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmdk file name
	# /<vmdk base directory path>/<vmdk directory name>/<vmdk file name>
	if ($ENV{vmdk_file_path}) {
		my ($vmdk_directory_path) = $ENV{vmdk_file_path} =~ /(.+)\/[^\/]+.vmdk$/i;
		if ($vmdk_directory_path) {
			return $vmdk_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk directory name could not be determined from vmdk file path: '$ENV{vmdk_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_persistent()) {
		return $self->get_vmdk_directory_path_persistent();
	}
	else {
		return $self->get_vmdk_directory_path_nonpersistent();
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_path_persistent

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the .vmdk files are
               located for persistent VMs.

=cut

sub get_vmdk_directory_path_persistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmprofile.datastorepath
	my $vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the persistent vmdk base directory path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_persistent = $self->get_vmdk_directory_name_persistent();
	if (!$vmdk_directory_name_persistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine persistent vmdk directory path because persistent vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_persistent";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_path_nonpersistent

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the .vmdk files are
               located for nonpersistent VMs.

=cut

sub get_vmdk_directory_path_nonpersistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmprofile.datastorepath
	my $vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the nonpersistent vmdk base directory path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_nonpersistent = $self->get_vmdk_directory_name_nonpersistent();
	if (!$vmdk_directory_name_nonpersistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine nonpersistent vmdk directory path because nonpersistent vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_nonpersistent";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_prefix

 Parameters  : none
 Returns     : string
 Description : Returns the name of the base .vmdk file without the trailing
               .vmdk. Example:
               vmdk file path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               vmdk file prefix: vmwarewinxp-base234-v12

=cut

sub get_vmdk_file_prefix {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path
	my $vmdk_file_path = $self->get_vmdk_file_path();
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk directory path could not be determined because vmdk file path could not be retrieved");
		return;
	}
	
	# Parse the vmdk file path, return the path preceding the vmdk file name
	my ($vmdk_file_name) = $vmdk_file_path =~ /\/([^\/]+)\.vmdk$/i;
	if ($vmdk_file_name) {
		return $vmdk_file_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "vmdk file name could not be determined from vmdk file path: '$vmdk_file_path'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the base .vmdk file including .vmdk. Example:
               vmdk file path: /vmfs/volumes/nfs-datastore/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               vmdk file name: vmwarewinxp-base234-v12.vmdk

=cut

sub get_vmdk_file_name {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path
	my $vmdk_file_path = $self->get_vmdk_file_path();
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk directory path could not be determined because vmdk file path could not be retrieved");
		return;
	}
	
	# Parse the vmdk file path, return the path preceding the vmdk file name
	my ($vmdk_file_name) = $vmdk_file_path =~ /\/([^\/]+\.vmdk)$/i;
	if ($vmdk_file_name) {
		return $vmdk_file_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "vmdk file name could not be determined from vmdk file path: '$vmdk_file_path'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_vmdk_file_path

 Parameters  : $vmx_file_path
 Returns     : 
 Description : Sets the vmdk path into %ENV so that the default values are
               overridden when the various get_vmdk_... subroutines are called.
               This is useful for base image imaging reservations if the
               code detects the vmdk path is not in the expected place.

=cut

sub set_vmdk_file_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path argument
	my $vmdk_file_path_argument = shift;
	if (!$vmdk_file_path_argument) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path argument was not supplied");
		return;
	}
	
	$vmdk_file_path_argument = normalize_file_path($vmdk_file_path_argument);
	
	# Make sure the vmdk file path format is valid
	if ($vmdk_file_path_argument !~ /^\/.+\/.+\/[^\/]+\.vmdk$/i) {
		notify($ERRORS{'WARNING'}, 0, "unable to override vmdk file path because the path format is invalid: '$vmdk_file_path_argument'");
		return;
	}
	
	$ENV{vmdk_file_path} = $vmdk_file_path_argument;
	
	# Check all of the vmdk file path components
	if ($self->check_file_paths('vmdk')) {
		# Set the vmdk_file_path environment variable
		notify($ERRORS{'OK'}, 0, "set overridden vmdk file path: '$vmdk_file_path_argument'");
		return 1;
	}
	else {
		delete $ENV{vmdk_file_path};
		notify($ERRORS{'WARNING'}, 0, "failed to set overridden vmdk file path: '$vmdk_file_path_argument'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_file_paths

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub check_file_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $file_type = shift || 'all';
	
	# Check to make sure all of the vmdk file path components can be retrieved
	my $undefined_string = "<undefined>";
	
	# Assemble a string of all of the components
	my $check_paths_string;
	
	if ($file_type !~ /vmdk/i) {
		$check_paths_string .= "vmx file path:                     '" . ($self->get_vmx_file_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx directory path:                '" . ($self->get_vmx_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx base directory path:           '" . ($self->get_vmx_base_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx directory name:                '" . ($self->get_vmx_directory_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx file name:                     '" . ($self->get_vmx_file_name() || $undefined_string) . "'\n";
		$check_paths_string .= "persistent vmx directory name:     '" . ($self->get_vmx_directory_name_persistent() || $undefined_string) . "'\n";
		$check_paths_string .= "nonpersistent vmx directory name:  '" . ($self->get_vmx_directory_name_nonpersistent() || $undefined_string) . "'\n";
	}
	
	if ($file_type !~ /vmx/i) {
		$check_paths_string .= "vmdk file path:                    '" . ($self->get_vmdk_file_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk directory path:               '" . ($self->get_vmdk_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk base directory path:          '" . ($self->get_vmdk_base_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk directory name:               '" . ($self->get_vmdk_directory_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk file name:                    '" . ($self->get_vmdk_file_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk file prefix:                  '" . ($self->get_vmdk_file_prefix() || $undefined_string) . "'\n";
		$check_paths_string .= "persistent vmdk file path:         '" . ($self->get_vmdk_file_path_persistent() || $undefined_string) . "'\n";
		$check_paths_string .= "persistent vmdk directory path:    '" . ($self->get_vmdk_directory_path_persistent() || $undefined_string) . "'\n";
		$check_paths_string .= "persistent vmdk directory name:    '" . ($self->get_vmdk_directory_name_persistent() || $undefined_string) . "'\n";
		$check_paths_string .= "nonpersistent vmdk file path:      '" . ($self->get_vmdk_file_path_nonpersistent() || $undefined_string) . "'\n";
		$check_paths_string .= "nonpersistent vmdk directory path: '" . ($self->get_vmdk_directory_path_nonpersistent() || $undefined_string) . "'\n";
		$check_paths_string .= "nonpersistent vmdk directory name: '" . ($self->get_vmdk_directory_name_nonpersistent() || $undefined_string) . "'\n";
	}
	
	if ($check_paths_string =~ /$undefined_string/) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve $file_type file path components:\n$check_paths_string");
		return;
	}
	else {
		# Set the vmdk_file_path environment variable
		notify($ERRORS{'OK'}, 0, "successfully retrieved $file_type file path components:\n$check_paths_string");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_path

 Parameters  : $management_node_identifier (optional)
 Returns     : 
 Description :

=cut

sub get_image_repository_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	return $self->get_repository_vmdk_directory_path();
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_search_paths

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_image_repository_search_paths {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_identifier = shift || $self->data->get_management_node_hostname();
	
	my $image_name = $self->data->get_image_name();
	
	my @repository_search_paths;
	
	if (my $vmhost_profile_repository_path = $self->data->get_vmhost_profile_repository_path()) {
		push @repository_search_paths, "$vmhost_profile_repository_path/$image_name/$image_name*.vmdk";
	}
	
	if (my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier)) {
		push @repository_search_paths, "$management_node_install_path/vmware_images/$image_name/$image_name*.vmdk";
		push @repository_search_paths, "$management_node_install_path/$image_name/$image_name*.vmdk";
	}
	
	push @repository_search_paths, "/install/vmware_images/$image_name/$image_name*.vmdk";
	
	my %seen;
	@repository_search_paths = grep { !$seen{$_}++ } @repository_search_paths; 
	#notify($ERRORS{'DEBUG'}, 0, "repository search paths on $management_node_identifier:\n" . join("\n", @repository_search_paths));
	return @repository_search_paths;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_repository_vmdk_base_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the image repository directory path on the management
					node under which the vmdk directories for all of the images
					reside. The preferred database value to use is
					vmprofile.repositorypath. If this is not available,
					managementnode.installpath is retrieved and "/vmware_images" is
					appended. If this is not available, "/install/vmware_images" is
					returned.
					Example:
               repository vmdk file path: /install/vmware_images/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               repository vmdk base directory path: /install/vmware_images
					

=cut

sub get_repository_vmdk_base_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $repository_vmdk_base_directory_path;
	
	# Attempt the retrieve vmhost.repositorypath
	if ($repository_vmdk_base_directory_path = $self->data->get_vmhost_profile_repository_path()) {
		$repository_vmdk_base_directory_path = normalize_file_path($repository_vmdk_base_directory_path);
		notify($ERRORS{'DEBUG'}, 0, "retrieved repository path from the VM profile: $repository_vmdk_base_directory_path");
	}
	elsif ($repository_vmdk_base_directory_path = $self->data->get_management_node_install_path()) {
		$repository_vmdk_base_directory_path = normalize_file_path($repository_vmdk_base_directory_path) . "/vmware_images";
		notify($ERRORS{'DEBUG'}, 0, "repository path is not set for the VM profile, using management node install path: $repository_vmdk_base_directory_path");
	}
	else {
		$repository_vmdk_base_directory_path = '/install/vmware_images';
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve repository path from VM profile or management node install path, returning '/install/vmware_images'");
	}
	
	return $repository_vmdk_base_directory_path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_repository_vmdk_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the image repository directory path on the management
               node under which the vmdk files reside.  Example:
               repository vmdk file path: /install/vmware_images/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk
               repository vmdk directory path: /install/vmware_images/vmwarewinxp-base234-v12

=cut

sub get_repository_vmdk_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $repository_vmdk_base_directory = $self->get_repository_vmdk_base_directory_path() || return;
	my $image_name = $self->data->get_image_name() || return;
	return "$repository_vmdk_base_directory/$image_name";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_repository_vmdk_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the image repository vmdk file path on the management
               node.  Example:
               repository vmdk file path: /install/vmware_images/vmwarewinxp-base234-v12/vmwarewinxp-base234-v12.vmdk

=cut

sub get_repository_vmdk_file_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $repository_vmdk_directory_path = $self->get_repository_vmdk_directory_path() || return;
	my $vmdk_file_name = $self->get_vmdk_file_name() || return;
	return "$repository_vmdk_directory_path/$vmdk_file_name";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_vm_persistent

 Parameters  : none
 Returns     : boolean
 Description : Determines if a VM should be persistent or not based on whether
               or not the reservation is an imaging reservation or if the end
               time is more than 24 hours in the future.

=cut

sub is_vm_persistent {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_forimaging = $self->data->get_request_forimaging();
	if ($request_forimaging) {
		return 1;
	}
	
	# Return true if the request end time is more than 24 hours in the future
	my $end_epoch = convert_to_epoch_seconds($self->data->get_request_end_time());
	my $now_epoch = time();
	my $end_hours = (($end_epoch - $now_epoch) / 60 / 60);
	if ($end_hours >= 24) {
		notify($ERRORS{'DEBUG'}, 0, "request end time is " . format_number($end_hours, 1) . " hours in the future, returning true");
		return 1;
	}
	
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_vm_registered

 Parameters  : $vmx_file_path (optional)
 Returns     : boolean
 Description : Determines if a VM is registered. An optional vmx file path
               argument can be supplied to check if a particular VM is
               registered. If an argument is not specified, the default vmx file
               path for the reservation is used.

=cut

sub is_vm_registered {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path
	# Use the argument if one was supplied
	my $vmx_file_path = shift || $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not specified and default vmx file path could not be determined");		
		return;
	}
	$vmx_file_path = normalize_file_path($vmx_file_path);
	
	my @registered_vmx_file_paths = $self->api->get_registered_vms();
	for my $registered_vmx_file_path (@registered_vmx_file_paths) {
		$registered_vmx_file_path = normalize_file_path($registered_vmx_file_path);
		if ($vmx_file_path eq $registered_vmx_file_path) {
			notify($ERRORS{'DEBUG'}, 0, "VM is registered: $vmx_file_path");
			return 1;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VM is not registered: '$vmx_file_path', registered paths:\n" . join("\n", @registered_vmx_file_paths));
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_size

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the image in megabytes. If the vmdk file path
               argument is not supplied and the VM disk type in the VM profile
               is set to localdisk, the size of the image in the image
               repository on the management node is checked. Otherwise, the size
               of the image in the vmdk directory on the VM host is checked.

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the image name argument
	my $image_name = shift;
	
	my $image_size_bytes = $self->get_image_size_bytes($image_name) || return;
	return round($image_size_bytes / 1024 / 1024);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_size_bytes

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the image in bytes. If the vmdk file path
               argument is not supplied and the VM disk type in the VM profile
               is set to localdisk, the size of the image in the image
               repository on the management node is checked. Otherwise, the size
               of the image in the vmdk directory on the VM host is checked.

=cut

sub get_image_size_bytes {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname() || return;
	
	# Attempt to get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		$image_name = $self->data->get_image_name() || return;
	}
	
	my $image_size_bytes;
	
	# Try to retrieve the image size from the repository if localdisk is being used
	if (my $repository_vmdk_base_directory_path = $self->get_repository_vmdk_base_directory_path()) {
		
		my $search_path = "$repository_vmdk_base_directory_path/$image_name/$image_name*.vmdk";
		
		notify($ERRORS{'DEBUG'}, 0, "checking size of image in image repository: $search_path");
		
		# Run du specifying image repository directory as an argument
		my ($exit_status, $output) = run_command("du -bc $search_path", 1);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to determine size of image in image repository: $search_path");
		}
		elsif (grep(/no such file/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "image does not exist in image repository");
		}
		elsif (grep(/du: /i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine size of image in image repository: $search_path, output:\n" . join("\n", @$output));
		}
		elsif (my ($total_line) = grep(/total/, @$output)) {
			($image_size_bytes) = $total_line =~ /(\d+)/;
			if (defined($image_size_bytes)) {
				notify($ERRORS{'DEBUG'}, 0, "retrieved size of image in image repository: $image_size_bytes");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to parse du output to determine size of vmdk directory in image repository: $search_path, output:\n" . join("\n", @$output));
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to locate 'total' line in du output while attempting to determine size of vmdk directory in image repository: $search_path, output:\n" . join("\n", @$output));
		}
	}
	
	# Unable to determine the image size from the image repository, attempt to retrieve size from VM host
	if (!defined($image_size_bytes)) {
		# Assemble a search path
		my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path() || return;
		my $search_path = "$vmdk_base_directory_path/$image_name/$image_name*.vmdk";
		
		# Get the size of the files on the VM host
		$image_size_bytes = $self->vmhost_os->get_file_size($search_path);
	}
	
	
	if (!defined($image_size_bytes)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the size of image in image repository or on VM host");
		return;
	}
	
	my $mb_used = format_number(($image_size_bytes / 1024 / 1024));
	my $gb_used = format_number(($image_size_bytes / 1024 / 1024 / 1024), 2);
	notify($ERRORS{'DEBUG'}, 0, "size of $image_name image: " . format_number($image_size_bytes) . " bytes ($mb_used MB, $gb_used GB)");
	return $image_size_bytes;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : none
 Returns     : boolean
 Description : Determines if an image exists in either the management node's
               image repository or on the VM host depending on the VM profile
               disk type setting. If the VM disk type in the VM profile is set
               to localdisk, the image repository on the management node is
               checked. Otherwise, the vmdk directory on the VM host is checked.

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmprofile_vmdisk = $self->data->get_vmhost_profile_vmdisk() || return;
	
	# Get the non-persistent vmdk file path used on the VM host
	my $vmhost_vmdk_file_path_nonpersistent = $self->get_vmdk_file_path_nonpersistent();
	if (!$vmhost_vmdk_file_path_nonpersistent) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine non-persistent vmdk file path on the VM host");
		return;
	}
	
	# Check if the vmdk file already exists on the VM host
	if ($self->vmhost_os->file_exists($vmhost_vmdk_file_path_nonpersistent)) {
		notify($ERRORS{'OK'}, 0, "image exists in the non-persistent directory on the VM host: $vmhost_vmdk_file_path_nonpersistent");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does not exist in the non-persistent directory on the VM host, checking the image repository");
	}
	
	
	# Get the image repository file path
	my $repository_vmdk_file_path = $self->get_repository_vmdk_file_path();
	if (!$repository_vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image repository vmdk file path");
		return;
	}
	
	
	# Remove any trailing slashes and separate the directory path and name pattern
	$repository_vmdk_file_path =~ s/\/*$//g;
	my ($directory_path, $name_pattern) = $repository_vmdk_file_path =~ /^(.*)\/([^\/]*)/g;
	
	# Check if the file exists
	(my ($exit_status, $output) = run_command("find \"$directory_path\" -iname \"$name_pattern\"")) || return;
	if (!grep(/find: /i, @$output) && grep(/$directory_path/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "image exists in the image repository: $repository_vmdk_file_path");
		return 1;
	}
	elsif (grep(/find: /i, @$output) && !grep(/no such file/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if file exists in repository: $repository_vmdk_file_path, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does not exist in image repository: $repository_vmdk_file_path");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_parameter_value

 Parameters  : $vmdk_parameter
 Returns     : string
 Description : Opens the .vmdk file, searches for the parameter argument, and
               returns the value for the parameter.  Example:
               vmdk file contains: ddb.adapterType = "buslogic"
               get_vmdk_parameter_value('adapterType') returns buslogic

=cut

sub get_vmdk_parameter_value {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the .vmdk parameter argument to search for
	my $vmdk_parameter = shift;
	if (!$vmdk_parameter) {
		notify($ERRORS{'WARNING'}, 0, "vmdk parameter name argument was not specified");
		return;
	}
	
	my $vmdk_file_path = $self->get_vmdk_file_path() || return;
	my $image_repository_vmdk_file_path = $self->get_repository_vmdk_file_path() || return;
	
	# Open the vmdk file for reading
	if (open FILE, "<", $vmdk_file_path) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to locate $vmdk_parameter value in vmdk file: $vmdk_file_path");
	}
	elsif (open FILE, "<", $image_repository_vmdk_file_path) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to locate $vmdk_parameter value in vmdk file: $image_repository_vmdk_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to open either vmdk file for reading: $vmdk_file_path, $image_repository_vmdk_file_path");
		return;
	}
	
	# Read the file line by line - do not read the file all at once
	# The vmdk file may be very large depending on the type - it may not be split up into a descriptor file and extents
	# If the vmdk file isn't split, the descriptor section will be at the beginning
	my $line_count = 0;
	my $value;
	while ($line_count < 100) {
		$line_count++;
		my $line = <FILE>;
		chomp $line;
		
		# Ignore comment lines
		next if ($line =~ /^\s*#/);
		
		# Check if the line contains the parameter name
		if ($line =~ /(^|\.)$vmdk_parameter[\s=]+/i) {
			notify($ERRORS{'DEBUG'}, 0, "found line containing $vmdk_parameter: '$line'");
			
			# Extract the value from the line
			($value) = $line =~ /\"(.+)\"/;
			last;
		}
	}
	
	close FILE;
	
	if (defined($value)) {
		notify($ERRORS{'DEBUG'}, 0, "found $vmdk_parameter value in vmdk file: '$value'");
		return $value;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "did not find $vmdk_parameter value in vmdk file");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_disk_adapter_type

 Parameters  : none
 Returns     : string
 Description : Returns the adapterType value in the vmdk file. Possible return
               values:
               -ide
               -lsilogic
               -buslogic

=cut

sub get_vm_disk_adapter_type {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_controller_type;
	
	if ($self->api->can("get_virtual_disk_controller_type") && ($vmdk_controller_type = $self->api->get_virtual_disk_controller_type($self->get_vmdk_file_path()))) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM disk adapter type from api object: $vmdk_controller_type");
	}
	elsif ($vmdk_controller_type = $self->get_vmdk_parameter_value('adapterType')) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM disk adapter type from vmdk file: $vmdk_controller_type");
	}
	
	if (!$vmdk_controller_type) {
		my $vm_os_configuration = $self->get_vm_os_configuration();
		if (!$vm_os_configuration) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine VM disk adapter type because unable to retrieve default VM OS configuration");
			return;
		}
		
		$vmdk_controller_type = $vm_os_configuration->{"scsi-virtualDev"};
		notify($ERRORS{'DEBUG'}, 0, "retrieved default VM disk adapter type for VM OS: $vmdk_controller_type");
	}
	
	if ($vmdk_controller_type) {
		return $vmdk_controller_type;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM disk adapter type");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_virtual_hardware_version

 Parameters  : none
 Returns     : string
 Description : Returns the virtualHWVersion value in the vmdk file.

=cut

sub get_vm_virtual_hardware_version {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $hardware_version;
	if ($self->api->can("get_virtual_disk_hardware_version")) {
		$hardware_version = $self->api->get_virtual_disk_hardware_version($self->get_vmdk_file_path());
		notify($ERRORS{'DEBUG'}, 0, "retrieved hardware version from api object: $hardware_version");
	}
	else {
		$hardware_version = $self->get_vmdk_parameter_value('virtualHWVersion');
		notify($ERRORS{'DEBUG'}, 0, "retrieved hardware version stored in the vmdk file: $hardware_version");
	}
	
	if (!$hardware_version) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine hardware version of vmdk file, returning 7");
		return 7;
	}
	
	# Under ESXi, IDE adapters are not allowed if the hardware version is 4
	# Override the hardware version retrieved from the vmdk file if:
	# -VMware product = ESX
	# -Adapter type = IDE
	# -Hardware version = 4
	if ($hardware_version < 7) {
		my $vmware_product_name = $self->get_vmhost_product_name();
		if (!$vmware_product_name) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine VMware product name in order to tell if hardware version should be overridden, returning $hardware_version");
			return $hardware_version;
		}
		
		if ($vmware_product_name =~ /esx/i) {
			my $adapter_type = $self->get_vm_disk_adapter_type();
			if (!$adapter_type) {
				notify($ERRORS{'WARNING'}, 0, "unable to determine disk adapter type in order to tell if hardware version should be overridden, returning $hardware_version");
				return $hardware_version;
			}
			
			if ($adapter_type =~ /ide/i) {
				notify($ERRORS{'OK'}, 0, "overriding hardware version $hardware_version --> 7, IDE adapters cannot be used on ESX unless the hardware version is 7 or higher, VMware product: '$vmware_product_name', vmdk adapter type: $adapter_type, vmdk hardware version: $hardware_version");
				return 7;
			}
		}
	}
	
	notify($ERRORS{'OK'}, 0, "returning hardware version: $hardware_version");
	return $hardware_version;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_os_configuration

 Parameters  : none
 Returns     : hash
 Description : Returns the information stored in %VM_OS_CONFIGURATION for
               the guest OS. The guest OS type, OS name, and archictecture are
               used to determine the appropriate guestOS and ethernet-virtualDev
               values to be used in the vmx file.

=cut

sub get_vm_os_configuration {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Return previously retrieved data if it exists
	return $self->{vm_os_configuration} if $self->{vm_os_configuration};
	
	my $image_os_type = $self->data->get_image_os_type() || return;
	my $image_os_name = $self->data->get_image_os_name() || return;
	my $image_architecture = $self->data->get_image_architecture() || return;
	
	# Figure out the key name in the %VM_OS_CONFIGURATION hash for the guest OS
	my $vm_os_configuration_key;
	if ($image_os_type =~ /linux/i) {
		$vm_os_configuration_key = "linux-$image_architecture";
	}
	elsif ($image_os_type =~ /windows/i) {
		my $regex = 'xp|2003|2008|vista|7';
		$image_os_name =~ /($regex)/i;
		my $windows_product = $1;
		if (!$windows_product) {
			notify($ERRORS{'WARNING'}, 0, "unsupported Windows product: $image_os_name, it does not contain ($regex), using default values for Windows");
			$windows_product = 'windows';
		}
		$vm_os_configuration_key = "$windows_product-$image_architecture";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unsupported OS type: $image_os_type, using default values");
		$vm_os_configuration_key = "default-$image_architecture";
	}
	
	# Retrieve the information from the hash, set an object variable
	$self->{vm_os_configuration} = $VM_OS_CONFIGURATION{$vm_os_configuration_key};
	if ($self->{vm_os_configuration}) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved default VM configuration for OS: $vm_os_configuration_key\n" . format_data($self->{vm_os_configuration}));
		return $self->{vm_os_configuration};
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to find default VM configuration for OS: $vm_os_configuration_key");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_guest_os

 Parameters  : none
 Returns     : string
 Description : Returns the appropriate guestOS value to be used in the vmx file.

=cut

sub get_vm_guest_os {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_os_configuration = $self->get_vm_os_configuration() || return;
	return $vm_os_configuration->{"guestOS"};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_ethernet_adapter_type

 Parameters  : none
 Returns     : string
 Description : Returns the appropriate ethernet virtualDev value to be used in
               the vmx file.

=cut

sub get_vm_ethernet_adapter_type {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_os_configuration = $self->get_vm_os_configuration() || return;
	return $vm_os_configuration->{"ethernet-virtualDev"};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_ram

 Parameters  : none
 Returns     : integer
 Description : Returns the amount of RAM in MB to be assigned to the VM. The
               VCL minimum RAM value configured for the image is used as the
               base value.
               
               The RAM setting in the vmx file must be a multiple of 4. The
               minimum RAM value is checked to make sure it is a multiple of 4.
               If not, the value is rounded down.
               
               The RAM value is also checked to make sure it is not lower than
               512 MB. If so, 512 MB is returned.

=cut

sub get_vm_ram {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $minimum_vm_ram_mb = 512;
	
	# Get the image minram setting
	my $image_minram_mb = $self->data->get_image_minram();
	if (!defined($image_minram_mb)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve image minram value");
		return;
	}
	
	# Make sure VM ram is a multiple of 4
	if ($image_minram_mb % 4) {
		my $image_minram_mb_original = $image_minram_mb;
		$image_minram_mb -= ($image_minram_mb % 4);
		notify($ERRORS{'DEBUG'}, 0, "image minram value is not a multiple of 4: $image_minram_mb_original, adjusting to $image_minram_mb");
	}
	
	# Check if the image setting is too low
	if ($image_minram_mb < $minimum_vm_ram_mb) {
		notify($ERRORS{'DEBUG'}, 0, "image ram setting is too low: $image_minram_mb MB, $minimum_vm_ram_mb MB will be used");
		return $minimum_vm_ram_mb;
	}
	
	return $image_minram_mb;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_file_paths

 Parameters  : none
 Returns     : array
 Description : Finds vmx files under the vmx base directory on the VM host.
               Returns an array containing the file paths.

=cut

sub get_vmx_file_paths {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to find existing vmx files on the VM host");
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path() || return;
	
	# Get a list of all the vmx files under the normal vmx base directory
	my @found_vmx_paths = $self->vmhost_os->find_files($vmx_base_directory_path, "*.vmx");
	
	# Get a list of the registered VMs in case a VM is registered and the vmx file does not reside under the normal vmx base directory
	my @registered_vmx_paths = $self->api->get_registered_vms();
	
	my %vmx_file_paths = map { $_ => 1 } (@found_vmx_paths, @registered_vmx_paths);
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(keys %vmx_file_paths) . " unique vmx files on VM host:\n" . join("\n", sort keys %vmx_file_paths));
	
	return sort keys %vmx_file_paths;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_info

 Parameters  : $vmx_file_path
 Returns     : hash
 Description : Reads the contents of the vmx file indicated by the
               $vmx_file_path argument and returns a hash containing the info:
               Example:
               |--{computer_id} = '2008'
               |--{displayname} = 'vm-ark-mcnc-9 (nonpersistent: vmwarewin2008-enterprisex86_641635-v0)'
               |--{ethernet0.address} = '00:50:56:03:54:11'
               |--{ethernet0.addresstype} = 'static'
               |--{ethernet0.virtualdev} = 'e1000'
               |--{ethernet0.vnet} = 'Private'
               |--{guestos} = 'winserver2008enterprise-32'
               |--{scsi0.present} = 'TRUE'
               |--{scsi0.virtualdev} = 'lsiLogic'
               |--{scsi0:0.devicetype} = 'scsi-hardDisk'
               |--{scsi0:0.filename} = '/vmfs/volumes/nfs-datastore/vmwarewin2008-enterprisex86_641635-v0/vmwarewin2008-enterprisex86_641635-v0.vmdk'
               |--{scsi0:0.mode} = 'independent-nonpersistent'
               |--{scsi0:0.present} = 'TRUE'
               |--{virtualhw.version} = '4'
               |--{vmx_directory} = '/vmfs/volumes/nfs-vmpath/vm-ark-mcnc-9_1635-v0'
               |--{vmx_file_name} = 'vm-ark-mcnc-9_1635-v0.vmx'
                  |--{vmdk}{scsi0:0}{devicetype} = 'scsi-hardDisk'
                  |--{vmdk}{scsi0:0}{mode} = 'independent-nonpersistent'
                  |--{vmdk}{scsi0:0}{present} = 'TRUE'
                  |--{vmdk}{scsi0:0}{vmdk_directory_path} = '/vmfs/volumes/nfs-datastore/vmwarewin2008-enterprisex86_641635-v0'
                  |--{vmdk}{scsi0:0}{vmdk_file_name} = 'vmwarewin2008-enterprisex86_641635-v0'
                  |--{vmdk}{scsi0:0}{vmdk_file_path} = '/vmfs/volumes/nfs-datastore/vmwarewin2008-enterprisex86_641635-v0/vmwarewin2008-enterprisex86_641635-v0.vmdk'

=cut

sub get_vmx_info {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not specified");
		return;
	}
	
	# Return previously retrieved data if defined
	if ($self->{vmx_info}{$vmx_file_path}) {
		notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved info from vmx file: $vmx_file_path");
		return $self->{vmx_info}{$vmx_file_path};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve info from vmx file: $vmx_file_path");
	
	my %vmx_info;
	
	my @vmx_file_contents = $self->vmhost_os->get_file_contents($vmx_file_path);
	if (!@vmx_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the contents of vmx file: $vmx_file_path");
		return;
	}
	
	for my $vmx_line (@vmx_file_contents) {
		# Ignore lines that don't contain a =
		next if $vmx_line !~ /=/;
		
		# Parse the property name and value from the vmx file line
		my ($property, $value) = $vmx_line =~ /[#\s"]*(.*[^\s])[\s"]*=[\s"]*(.*)"/g;
		
		# Add the property and value to the vmx info hash
		$vmx_info{lc($property)} = $value;
		
		# Check if the line is a storage identifier, add it to a special hash key
		if ($property =~ /((?:ide|scsi)\d+:\d+)\.(.*)/) {
			$vmx_info{vmdk}{lc($1)}{lc($2)} = $value;
		}
	}
	
	# Get the vmx file name and directory from the full path
	($vmx_info{vmx_file_name}) = $vmx_file_path =~ /([^\/]+)$/;
	($vmx_info{vmx_directory}) = $vmx_file_path =~ /(.*)\/[^\/]+$/;
	
	# Loop through the storage identifiers (idex:x or scsix:x lines found)
	# Find the ones with a fileName property set to a .vmdk path
	for my $storage_identifier (keys %{$vmx_info{vmdk}}) {
		my $vmdk_file_path = $vmx_info{vmdk}{$storage_identifier}{filename};
		if (!$vmdk_file_path) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring $storage_identifier, filename property not set");
			delete $vmx_info{vmdk}{$storage_identifier};
			next;
		}
		elsif ($vmdk_file_path !~ /\.vmdk$/i) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring $storage_identifier, filename property does not end with .vmdk: $vmdk_file_path");
			delete $vmx_info{vmdk}{$storage_identifier};
			next;
		}
		
		# Check if mode is set
		my $vmdk_mode = $vmx_info{vmdk}{$storage_identifier}{mode};
		if (!$vmdk_mode) {
			notify($ERRORS{'DEBUG'}, 0, "$storage_identifier mode property not set, setting default value: persistent");
			$vmx_info{vmdk}{$storage_identifier}{mode} = 'persistent';
		}
		
		# Check if the vmdk path begins with a /, if not, prepend the .vmx directory path
		if ($vmdk_file_path !~ /^\//) {
			my $vmdk_file_path_original = $vmdk_file_path;
			$vmx_info{vmdk}{$storage_identifier}{filename} = "$vmx_info{vmx_directory}\/$vmdk_file_path";
			$vmdk_file_path = $vmx_info{vmdk}{$storage_identifier}{filename};
			notify($ERRORS{'DEBUG'}, 0, "vmdk path appears to be relative: $vmdk_file_path_original, prepending the vmx directory: $vmdk_file_path");
		}
		
		# Get the directory path
		my ($vmdk_directory_path) = $vmdk_file_path =~ /(.*)\/[^\/]+$/;
		if (!$vmdk_directory_path) {
			notify($ERRORS{'DEBUG'}, 0, "unable to determine vmdk directory from path: $vmdk_file_path");
			delete $vmx_info{vmdk}{$storage_identifier};
			next;
		}
		else {
			$vmx_info{vmdk}{$storage_identifier}{vmdk_directory_path} = $vmdk_directory_path;
		}
		
		$vmx_info{vmdk}{$storage_identifier}{vmdk_file_path} = $vmdk_file_path;
		delete $vmx_info{vmdk}{$storage_identifier}{filename};
		($vmx_info{vmdk}{$storage_identifier}{vmdk_file_name}) = $vmdk_file_path =~ /([^\/]+)\.vmdk$/i;
	}
	
	# Store the vmx file info so it doesn't have to be retrieved again
	$self->{vmx_info}{$vmx_file_path} = \%vmx_info;
	return $self->{vmx_info}{$vmx_file_path};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_vm

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Deletes the VM specified by the vmx file path argument. The VM is
               first unregistered and the vmx directory is deleted. The vmdk
               files used by the VM are deleted if the disk type is persistent.

=cut

sub delete_vm {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "attempting to delete VM: $vmx_file_path");
	
	# Get the vmx info
	my $vmx_info = $self->get_vmx_info($vmx_file_path);
	if (!$vmx_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete VM, vmx info could not be retrieved: $vmx_file_path");
		return;
	}
	
	my $vmx_directory_path = $vmx_info->{vmx_directory};
	
	# Unregister the VM
	if (!$self->api->vm_unregister($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM: $vmx_file_path, VM not deleted");
		return;
	}
	
	for my $storage_identifier (keys %{$vmx_info->{vmdk}}) {
		my $vmdk_file_path = $vmx_info->{vmdk}{$storage_identifier}{vmdk_file_path};
		my $vmdk_file_name = $vmx_info->{vmdk}{$storage_identifier}{vmdk_file_name};
		my $vmdk_directory_path = $vmx_info->{vmdk}{$storage_identifier}{vmdk_directory_path};
		my $vmdk_mode = $vmx_info->{vmdk}{$storage_identifier}{mode};
		
		notify($ERRORS{'DEBUG'}, 0, "checking if existing VM's vmdk file should be deleted:
				 vmdk file path: $vmdk_file_path
				 vmx storage identier key: $storage_identifier
				 disk mode: $vmdk_mode");
		
		if ($vmdk_mode =~ /^(independent-)?persistent/) {
			notify($ERRORS{'DEBUG'}, 0, "mode of vmdk file: $vmdk_mode, attempting to delete vmdk directory: $vmdk_directory_path");
			$self->vmhost_os->delete_file($vmdk_directory_path) || return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "mode of vmdk file: $vmdk_mode, vmdk directory will NOT be deleted");
		}
	}
	
	# Delete the vmx directory
	my $attempt = 0;
	my $attempt_limit = 5;
	while ($attempt++ < $attempt_limit) {
		if ($attempt > 1) {
			notify($ERRORS{'DEBUG'}, 0, "sleeping for 5 seconds before making next attempt to delete vmx directory");
			sleep 3;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: attempting to delete vmx directory: $vmx_directory_path");
		if ($self->vmhost_os->delete_file($vmx_directory_path)) {
			notify($ERRORS{'DEBUG'}, 0, "deleted VM: $vmx_file_path");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to delete vmx directory: $vmx_directory_path");
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to delete VM, unable to delete vmx directory after $attempt_limit attempts: $vmx_directory_path");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_additional_vmdk_bytes_required

 Parameters  : none
 Returns     : integer
 Description : Checks if additional space is required for the VM's vmdk files
               before a VM is loaded by checking if the vmdk already exists on
               the VM host. If the vmdk does not exist, the image size is
               returned.

=cut

sub get_vm_additional_vmdk_bytes_required {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $additional_bytes_required = 0;
	
	# Check if the .vmdk files already exist on the host
	my $host_vmdk_file_exists = $self->vmhost_os->file_exists($self->get_vmdk_file_path());
	my $image_size_bytes = $self->get_image_size_bytes() || return;
	if (!defined $host_vmdk_file_exists) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if vmdk files already exist on VM host");
		return;
	}
	if ($host_vmdk_file_exists == 0) {
		$additional_bytes_required += $image_size_bytes;
		notify($ERRORS{'DEBUG'}, 0, "$image_size_bytes additional bytes required because vmdk files do NOT already exist on VM host");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no additional space required for vmdk files because they already exist on VM host");
	}
	
	my $additional_mb_required = format_number($additional_bytes_required / 1024 / 1024);
	my $additional_gb_required = format_number($additional_bytes_required / 1024 / 1024 / 1024);
	notify($ERRORS{'DEBUG'}, 0, "VM requires appoximately $additional_bytes_required additional bytes ($additional_mb_required MB, $additional_gb_required GB) of disk space on the VM host for the vmdk directory");
	return $additional_bytes_required;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_additional_vmx_bytes_required

 Parameters  : none
 Returns     : integer
 Description : Checks if additional space is required for the files that will be
               stored in the VM's vmx directory before a VM is loaded. Space is
               required for the VM's vmem file. This is calculated by retrieving
               the RAM setting for the VM. Space is required for REDO files if
               the virtual disk is non-persistent. This is estimated to be 1/4
               the disk size.

=cut

sub get_vm_additional_vmx_bytes_required {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $additional_bytes_required = 0;
	
	# Add the amount of RAM assigned to the VM to the bytes required for the vmem file
	my $vm_ram_mb = $self->get_vm_ram() || return;
	my $vm_ram_bytes = ($vm_ram_mb * 1024 * 1024);
	$additional_bytes_required += $vm_ram_bytes;
	notify($ERRORS{'DEBUG'}, 0, "$vm_ram_bytes additional bytes required for VM vmem file");
	
	# Check if the VM is persistent
	# If non-persistent, add bytes for the REDO files
	if ($self->is_vm_persistent()) {
		notify($ERRORS{'DEBUG'}, 0, "no additional space required for REDO files because VM disk mode is persistent");
	}
	else {
		# Estimate that REDO files will grow to 1/4 the image size
		my $image_size_bytes = $self->get_image_size_bytes() || return;
		my $redo_size = int($image_size_bytes / 4);
		$additional_bytes_required += $redo_size;
		notify($ERRORS{'DEBUG'}, 0, "$redo_size additional bytes required for REDO files because VM disk mode is NOT persistent");
	}
	
	my $additional_mb_required = format_number($additional_bytes_required / 1024 / 1024);
	my $additional_gb_required = format_number($additional_bytes_required / 1024 / 1024 / 1024);
	notify($ERRORS{'DEBUG'}, 0, "VM requires appoximately $additional_bytes_required additional bytes ($additional_mb_required MB, $additional_gb_required GB) of disk space on the VM host for the vmx directory");
	return $additional_bytes_required;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 rename_vmdk

 Parameters  : $source_vmdk_file_path, $destination_vmdk_file_path
 Returns     : boolean
 Description : Renames a vmdk. The full paths to the source and destination vmdk
               paths are required.

=cut

sub rename_vmdk {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my ($source_vmdk_file_path, $destination_vmdk_file_path) = @_;
	if (!$source_vmdk_file_path || !$destination_vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination vmdk file path arguments were not specified");
		return;
	}
	
	# Make sure the arguments end with .vmdk
	if ($source_vmdk_file_path !~ /\.vmdk$/i || $destination_vmdk_file_path !~ /\.vmdk$/i) {
		notify($ERRORS{'WARNING'}, 0, "source vmdk file path ($source_vmdk_file_path) and destination vmdk file path ($destination_vmdk_file_path) arguments do not end with .vmdk");
		return;
	}
	
	# Make sure the source vmdk file exists
	if (!$self->vmhost_os->file_exists($source_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "source vmdk file path does not exist: $source_vmdk_file_path");
		return;
	}
	
	# Make sure the destination vmdk file doesn't already exist
	if ($self->vmhost_os->file_exists($destination_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "destination vmdk file path already exists: $destination_vmdk_file_path");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to rename vmdk: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
	
	# Determine the destination vmdk directory path and create the directory
	my ($destination_vmdk_directory_path) = $destination_vmdk_file_path =~ /(.+)\/[^\/]+\.vmdk$/;
	if (!$destination_vmdk_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination vmdk directory path from vmdk file path: $destination_vmdk_file_path");
		return;
	}
	$self->vmhost_os->create_directory($destination_vmdk_directory_path) || return;
	
	# Check if the API object has implented a move_virtual_disk subroutine
	if ($self->api->can("move_virtual_disk")) {
		notify($ERRORS{'OK'}, 0, "attempting to rename vmdk file using API's 'move_virtual_disk' subroutine: $source_vmdk_file_path --> $destination_vmdk_file_path");
		
		if ($self->api->move_virtual_disk($source_vmdk_file_path, $destination_vmdk_file_path)) {
			notify($ERRORS{'OK'}, 0, "renamed vmdk using API's 'move_virtual_disk' subroutine: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "failed to rename vmdk using API's 'move_virtual_disk' subroutine");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'move_virtual_disk' subroutine has not been implemented by the API: " . ref($self->api));
	}
	
	# Check if the VM host OS object implements an execute subroutine and attempt to run vmware-vdiskmanager
	if ($self->vmhost_os->can("execute")) {
		
		# Try vmware-vdiskmanager
		notify($ERRORS{'OK'}, 0, "attempting to rename vmdk file using vmware-vdiskmanager: $source_vmdk_file_path --> $destination_vmdk_file_path");
		my $vdisk_command = "vmware-vdiskmanager -n \"$source_vmdk_file_path\" \"$destination_vmdk_file_path\"";
		my ($vdisk_exit_status, $vdisk_output) = $self->vmhost_os->execute($vdisk_command);
		if (!defined($vdisk_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware-vdiskmanager' command on VM host to rename vmdk file:\n$vdisk_command");
		}
		elsif (grep(/success/i, @$vdisk_output)) {
			notify($ERRORS{'OK'}, 0, "renamed vmdk file by executing 'vmware-vdiskmanager' command on VM host:\ncommand: $vdisk_command\noutput: " . join("\n", @$vdisk_output));
			return 1;
		}
		elsif (grep(/not found/i, @$vdisk_output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to rename vmdk using 'vmware-vdiskmanager' because the command is not available on VM host");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware-vdiskmanager' command on VM host to rename vmdk file:\n$vdisk_command\noutput:\n" . join("\n", @$vdisk_output));
		}
		
		
		# Try vmkfstools
		notify($ERRORS{'OK'}, 0, "attempting to rename vmdk file using vmkfstools: $source_vmdk_file_path --> $destination_vmdk_file_path");
		my $vmkfs_command = "vmkfstools -E \"$source_vmdk_file_path\" \"$destination_vmdk_file_path\"";
		my ($vmkfs_exit_status, $vmkfs_output) = $self->vmhost_os->execute($vmkfs_command);
		
		# There is no output if the command succeeded
		# Check to make sure the source file doesn't exist and the destination file does exist
		if (!defined($vmkfs_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmkfstools' command on VM host: $vmkfs_command");
		}
		elsif (grep(/command not found/i, @$vmkfs_output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to rename vmdk using 'vmkfstools' because the command is not available on VM host");
		}
		elsif ($self->vmhost_os->file_exists($source_vmdk_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to rename vmdk file using vmkfstools, source file still exists: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		}
		elsif (!$self->vmhost_os->file_exists($destination_vmdk_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to rename vmdk file using vmkfstools, destination file does not exist: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		}
		else {
			notify($ERRORS{'OK'}, 0, "renamed vmdk file using vmkfstools: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
			return 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to execute 'vmware-vdiskmanager' or 'vmkfstools' on VM host because 'execute' subroutine has not been implemented by the VM host OS: " . ref($self->vmhost_os));
	}
	
	# Unable to rename vmdk file using any VMware utilities or APIs
	# Attempt to manually rename the files
	
	# Determine the source vmdk directory path
	my ($source_vmdk_directory_path) = $source_vmdk_file_path =~ /(.+)\/[^\/]+\.vmdk$/;
	if (!$source_vmdk_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine source vmdk directory path from vmdk file path: $source_vmdk_file_path");
		return;
	}
	
	# Determine the source vmdk file name
	my ($source_vmdk_file_name) = $source_vmdk_file_path =~ /\/([^\/]+\.vmdk)$/;
	if (!$source_vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine source vmdk file name from vmdk file path: $source_vmdk_file_path");
		return;
	}
	
	# Determine the destination vmdk file name
	my ($destination_vmdk_file_name) = $destination_vmdk_file_path =~ /\/([^\/]+\.vmdk)$/;
	if (!$destination_vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination vmdk file name from vmdk file path: $destination_vmdk_file_path");
		return;
	}
	
	# Determine the source vmdk file prefix - "vmwinxp-image.vmdk" --> "vmwinxp-image"
	my ($source_vmdk_file_prefix) = $source_vmdk_file_path =~ /\/([^\/]+)\.vmdk$/;
	if (!$source_vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine source vmdk file prefix from vmdk file path: $source_vmdk_file_path");
		return;
	}
	
	# Determine the destination vmdk file prefix - "vmwinxp-image.vmdk" --> "vmwinxp-image"
	my ($destination_vmdk_file_prefix) = $destination_vmdk_file_path =~ /\/([^\/]+)\.vmdk$/;
	if (!$destination_vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination vmdk file prefix from vmdk file path: $destination_vmdk_file_path");
		return;
	}
	
	# Find all of the source vmdk file paths including the extents
	my @source_vmdk_file_paths = $self->vmhost_os->find_files($source_vmdk_directory_path, "$source_vmdk_file_prefix*.vmdk");
	if (@source_vmdk_file_paths) {
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@source_vmdk_file_paths) . " source vmdk file paths:\n" . join("\n", sort @source_vmdk_file_paths));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to find source vmdk file paths, source vmdk directory: $source_vmdk_directory_path, source vmdk file pattern: $source_vmdk_file_prefix*.vmdk");
		return;
	}
	
	# Loop through the source vmdk paths, figure out the destination file path, rename the file
	my %renamed_file_paths;
	my $rename_error_occurred = 0;
	for my $source_vmdk_copy_path (@source_vmdk_file_paths) {
		# Determine the extent identifier = "vmwinxp-image-s003.vmdk" --> "s003"
		my ($extent_identifier) = $source_vmdk_copy_path =~ /\/$source_vmdk_file_prefix([^\/]*)\.vmdk$/;
		$extent_identifier = '' if !$extent_identifier;
		
		# Construct the destination vmdk path
		my $destination_vmdk_copy_path = "$destination_vmdk_directory_path/$destination_vmdk_file_prefix$extent_identifier.vmdk";
		
		# Call the VM host OS's move_file subroutine to rename the vmdk file
		notify($ERRORS{'DEBUG'}, 0, "attempting to rename vmdk file:\n'$source_vmdk_copy_path' --> '$destination_vmdk_copy_path'");
		if (!$self->vmhost_os->move_file($source_vmdk_copy_path, $destination_vmdk_copy_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to rename vmdk file: '$source_vmdk_copy_path' --> '$destination_vmdk_copy_path'");
			$rename_error_occurred = 1;
			last;
		}
		
		# Add the source and destination vmdk file paths to a hash which will be used in case an error occurs and the files need to be reverted back to their original names
		$renamed_file_paths{$source_vmdk_copy_path} = $destination_vmdk_copy_path;

		# Delay next rename or else VMware may crash - "[2010-05-24 05:59:01.267 'App' 3083897744 error] Caught signal 11"
		sleep 5;
	}
	
	# If multiple vmdk file paths were found, edit the base vmdk file and update the extents
	# Don't do this if a single vmdk file was found because it will be very large and won't contain the extent information
	# This could happen if a virtual disk is in raw format
	if ($rename_error_occurred) {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file extents not updated because an error occurred moving the files");
	}
	elsif (scalar(@source_vmdk_file_paths) > 1) {
		# Attempt to retrieve the contents of the base vmdk file
		if (my @vmdk_file_contents = $self->vmhost_os->get_file_contents($destination_vmdk_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved vmdk file contents: '$destination_vmdk_file_path'\n" . join("\n", @vmdk_file_contents));
			
			# Loop through each line of the base vmdk file - replace the source vmdk file prefix with the destination vmdk file prefix
			my @updated_vmdk_file_contents;
			for my $vmdk_line (@vmdk_file_contents) {
				chomp $vmdk_line;
				(my $updated_vmdk_line = $vmdk_line) =~ s/($source_vmdk_file_prefix)([^\/]*\.vmdk)/$destination_vmdk_file_prefix$2/;
				if ($updated_vmdk_line ne $vmdk_line) {
					notify($ERRORS{'DEBUG'}, 0, "updating line in vmdk file:\n'$vmdk_line' --> '$updated_vmdk_line'");
				}
				push @updated_vmdk_file_contents, $updated_vmdk_line;
			}
			notify($ERRORS{'DEBUG'}, 0, "updated vmdk file contents: '$destination_vmdk_file_path'\n" . join("\n", @updated_vmdk_file_contents));
			
			# Create a temp file to store the update vmdk contents, this temp file will be copied to the VM host
			my ($temp_file_handle, $temp_file_path) = tempfile(CLEANUP => 1, SUFFIX => '.vmdk');
			if ($temp_file_handle && $temp_file_path) {
				# Write the contents to the temp file
				print $temp_file_handle join("\n", @updated_vmdk_file_contents);
				notify($ERRORS{'DEBUG'}, 0, "wrote updated vmdk contents to temp file: $temp_file_path");
				$temp_file_handle->close;
				
				# Copy the temp file to the VM host overwriting the original vmdk file
				if ($self->vmhost_os->copy_file_to($temp_file_path, $destination_vmdk_file_path)) {
					notify($ERRORS{'DEBUG'}, 0, "copied temp file containing updated vmdk contents to VM host:\n'$temp_file_path' --> '$destination_vmdk_file_path'");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy temp file containing updated vmdk contents to VM host:\n'$temp_file_path' --> '$destination_vmdk_file_path'");
					$rename_error_occurred = 1;
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to create temp file to store updated vmdk contents which will be copied to the VM host");
				$rename_error_occurred = 1;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve vmdk file contents: '$destination_vmdk_file_path'");
			$rename_error_occurred = 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file extents not updated because a single source vmdk file was found");
	}
	
	# Check if an error occurred, revert the file renames if necessary
	if ($rename_error_occurred) {
		for my $destination_vmdk_revert_path (sort keys(%renamed_file_paths)) {
			my $source_vmdk_revert_path = $renamed_file_paths{$destination_vmdk_revert_path};
			
			# Call the VM host OS's move_file subroutine to rename the vmdk file back to what it was originally
			notify($ERRORS{'DEBUG'}, 0, "attempting to revert the vmdk file move:\n'$source_vmdk_revert_path' --> '$destination_vmdk_revert_path'");
			if (!$self->vmhost_os->move_file($source_vmdk_revert_path, $destination_vmdk_revert_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to revert the vmdk file move:\n'$source_vmdk_revert_path' --> '$destination_vmdk_revert_path'");
				last;
			}
			sleep 5;
		}
		
		notify($ERRORS{'WARNING'}, 0, "failed to rename vmdk using any available methods: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "renamed vmdk file: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 mount_repository_datastore

 Parameters  : 
 Returns     : boolean
 Description : 

=cut

sub mount_repository_datastore {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $datastore_name = 'vcl-repository';
	
	my $management_node_short_name = $self->data->get_management_node_short_name();
	if (!$management_node_short_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve management short name");
		return;
	}
	
	my $repository_vmdk_base_directory_path = $self->get_repository_vmdk_base_directory_path();
	if (!$repository_vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve repository vmdk base directory path");
		return;
	}
	
	if ($self->api->can("create_nfs_datastore")) {
		if ($self->api->create_nfs_datastore($datastore_name, '10.25.0.245', $repository_vmdk_base_directory_path)) {
			notify($ERRORS{'OK'}, 0, "repository datastore mounted on VM host: $datastore_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to mount repository datastore on VM host: $datastore_name");
		}
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : none
 Returns     : boolean
 Description : Powers on the VM.

=cut

sub power_on {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->api->vm_power_on($self->get_vmx_file_path());
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : none
 Returns     : boolean
 Description : Powers off the VM.

=cut

sub power_off {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->api->vm_power_off($self->get_vmx_file_path());
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : none
 Returns     : boolean
 Description : Powers the VM off and then on.

=cut

sub power_reset {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path then power off and then power on the VM
	my $vmx_file_path = $self->get_vmx_file_path() || return;
	$self->api->vm_power_off($vmx_file_path);
	return$self->api->vm_power_on($vmx_file_path);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : none
 Returns     : string
 Description : Returns a string containing the power state of the VM.

=cut

sub power_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->api->get_vm_power_state($self->get_vmx_file_path());
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_product_name

 Parameters  : none
 Returns     : string
 Description : Returns a string containing the full VMware product name being
               used on the VM host. 

=cut

sub get_vmhost_product_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname() || return;
	my $product_name;
	
	# Attempt to retrieve the product name using the API object
	if ($self->api->can("get_vmware_product_name") && ($product_name = $self->api->get_vmware_product_name())) {
		return $product_name;
	}
	
	# Attempt to retrieve the product name by running 'vmware -v' on the VM host
	elsif ($self->vmhost_os->can("execute")) {
		my $command = "vmware -v";
		my ($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware -v' command on VM host $vmhost_computer_name to retrieve the VMware product name, command: $command");
		}
		elsif (my ($product_name) = grep(/vmware/i, @$output)) {
			notify($ERRORS{'OK'}, 0, "VMware product being used on VM host $vmhost_computer_name: '$product_name'");
			return $product_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware -v' command on VM host $vmhost_computer_name to retrieve the VMware product name, command: $command\noutput:\n" . join("\n", @$output));
		}
	}
	
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve VMware product name being used on VM host $vmhost_computer_name using the API or VM host OS object");
	}
	
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 post_maintenance_action

 Parameters  : none
 Returns     : boolean
 Description : 

=cut

sub post_maintenance_action {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_id = $self->data->get_computer_id();
	my $computer_short_name = $self->data->get_computer_short_name();
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vmx_file_path = $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path could not be determined");
		return;
	}
	
	# Delete the existing VM from the VM host
	if ($self->vmhost_os->file_exists($vmx_file_path)) {
		if (!$self->delete_vm($vmx_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete VM on VM host $vmhost_hostname: $vmx_file_path");
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "vmx file does not exist on the VM host $vmhost_hostname: $vmx_file_path");
	}
	
	if (switch_vmhost_id($computer_id, 'NULL')) {
		notify($ERRORS{'OK'}, 0, "set vmhostid to NULL for for VM $computer_short_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmhostid to NULL for VM $computer_short_name");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
