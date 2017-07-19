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

VCL::Module::Provisioning::VMware::VMware

=head1 SYNOPSIS

 use VCL::Module::Provisioning::VMware::VMware;
 my $provisioner = VCL::Module::Provisioning::VMware::VMware->new({data_structure => $self->data});

=head1 DESCRIPTION

 This module provides VCL support for the following VMware products:
 -VMware Server 1.x
 -VMware Server 2.x
 -VMware ESX 3.x
 -VMware ESX 4.x
 -VMware ESXi 4.x

=cut

###############################################################################
package VCL::Module::Provisioning::VMware::VMware;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use English qw(-no_match_vars);
use IO::File;
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw(tempfile);
use List::Util qw(max);
use Storable qw(dclone);
use Term::ANSIColor 2.00 qw(:constants colored);

use VCL::utils;

###############################################################################

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
  # OSX configuration
  "osx-x86" => {
     "guestOS" => "darwin10-64",
     "ethernet-virtualDev" => "e1000",
     "scsi-virtualDev" => "lsiLogic",
  },
  "osx-x86_64" => {
     "guestOS" => "darwin10-64",
     "ethernet-virtualDev" => "e1000",
     "scsi-virtualDev" => "lsiLogic",
  },
	# Windows configurations:
	"winxp-x86" => {
		"guestOS" => "winXPPro",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "busLogic",
		"cpu_socket_limit" => 2,
	},
	"winxp-x86_64" => {
		"guestOS" => "winXPPro-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	},
	"winvista-x86" => {
		"guestOS" => "winvista",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	},
	"vista-x86_64" => {
		"guestOS" => "winvista-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	}, 
	"win7-x86" => {
		"guestOS" => "windows7",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	},
	"win7-x86_64" => {
		"guestOS" => "windows7-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	},
	"win8-x86" => {
		"guestOS" => "windows8",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	}, 
	"win8-x86_64" => {
		"guestOS" => "windows8-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 2,
	},
	"win10-x86" => {
		"guestOS" => "windows9",
		"ethernet-virtualDev" => "e1000e",
		"scsi-virtualDev" => "lsisas1068",
		"cpu_socket_limit" => 2,
	}, 
	"win10-x86_64" => {
		"guestOS" => "windows9-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsisas1068",
		"cpu_socket_limit" => 2,
	},
	"win2003-x86" => {
		"guestOS" => "winNetEnterprise",
		"ethernet-virtualDev" => "vlance",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 64,
	},
	"win2003-x86_64" => {
		"guestOS" => "winNetEnterprise-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 64,
	},
	"win2008-x86" => {
		"guestOS" => "winServer2008Enterprise-32",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 64,
	},
	"win2008-x86_64" => {
		"guestOS" => "winServer2008Enterprise-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
		"cpu_socket_limit" => 64,
	},
	"win2012-x86_64" => {
		"guestOS" => "windows8srv-64",
		"ethernet-virtualDev" => "e1000e",
		"scsi-virtualDev" => "lsisas1068",
		"cpu_socket_limit" => 64,
	},
	"win2016-x86_64" => {
		"guestOS" => "windows9srv-64",
		"ethernet-virtualDev" => "e1000e",
		"scsi-virtualDev" => "lsisas1068",
		"cpu_socket_limit" => 64,
	},
	
	# Default Windows configuration if Windows version isn't found above:
	"windows-x86" => {
		"guestOS" => "windows7",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsisas1068",
	},
	"windows-x86_64" => {
		"guestOS" => "windows7-64",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsisas1068",
	},
	
	# Default configuration if OS is not Windows or Linux:
	"default-x86" => {
		"guestOS" => "otherlinux",
		"ethernet-virtualDev" => "e1000",
		"scsi-virtualDev" => "lsiLogic",
	},
	"default-x86_64" => {
		"guestOS" => "otherlinux-64",
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

=head2 $VMWARE_CMD_PACKAGE

 Data type   : string
 Description : Perl package name for the vmware-cmd module.

=cut

our $VMWARE_CMD_PACKAGE = 'VCL::Module::Provisioning::VMware::vmware_cmd';

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Get a DataStructure object containing data for the VM host computer
	my $vmhost_data = $self->get_vmhost_datastructure();
	if (!$vmhost_data) {
		notify($ERRORS{'WARNING'}, 0, "failed to create VM host DataStructure object");
		return;
	}
	
	my $request_state_name = $self->data->get_request_state_name();
	
	# Used only for development/testing
	# If request state is 'test', full initialization is bypassed by default to speed things up
	# Passing '1' as the argument causes full initialization
	if ($request_state_name eq 'test') {
		my $argument = shift;
		unless (defined($argument) && !ref($argument) && $argument eq '1') {
			notify($ERRORS{'DEBUG'}, 0, "request state is '$request_state_name', bypassing full " . ref($self) . " object initialization");
			return 1;
		}
	}
	
	my $vmhost_computer_name = $vmhost_data->get_computer_node_name();
	my $vmhost_image_name = $vmhost_data->get_image_name();
	my $vmhost_os_module_package = $vmhost_data->get_image_os_module_perl_package();
	my $vmhost_lastcheck_time = $vmhost_data->get_computer_lastcheck_time(0);
	my $vmhost_computer_id = $self->data->get_vmhost_computer_id();
	my $vmprofile_name = $self->data->get_vmhost_profile_name();
	my $vmprofile_password = $self->data->get_vmhost_profile_password(0);
	
	notify($ERRORS{'DEBUG'}, 0, "initializing " . ref($self) . " object");
	
	my $vmware_api;
	
	notify($ERRORS{'DEBUG'}, 0, "VM profile assigned to $vmhost_computer_name: $vmprofile_name");
	
	# Create an API object which will be used to control the VM (register, power on, etc.)
	if ($vmprofile_password && ($vmware_api = $self->get_vmhost_api_object($VSPHERE_SDK_PACKAGE)) && !$vmware_api->is_restricted()) {
		notify($ERRORS{'DEBUG'}, 0, "vSphere SDK object will be used to control VM host $vmhost_computer_name");
		
		$self->set_vmhost_os($vmware_api);
		$vmware_api->set_vmhost_os($vmware_api);
	}
	else {
		# SSH access to the VM host OS is required if the vSphere SDK can't be used
		if (!$self->vmhost_os) {
			notify($ERRORS{'WARNING'}, 0, "unable to control VM host $vmhost_computer_name, vSphere SDK cannot be used and the VM host OS object is not available");
			return;
		}
		
		# Check if SSH is responding
		if ($self->vmhost_os->is_ssh_responding(3)) {
			notify($ERRORS{'OK'}, 0, "OS on VM host $vmhost_computer_name will be controlled using " . ref($self->vmhost_os) . " OS object");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to control OS of VM host $vmhost_computer_name using $vmhost_os_module_package OS object because VM host is not responding to SSH");
			return;
		}
		
		# Try to create one of the other types of objects to control the VM host
		if ($vmware_api = $self->get_vmhost_api_object($VIM_SSH_PACKAGE)) {
			notify($ERRORS{'DEBUG'}, 0, "VM host $vmhost_computer_name will be controlled using vim-cmd via SSH");
		}
		elsif ($vmware_api = $self->get_vmhost_api_object($VMWARE_CMD_PACKAGE)) {
			notify($ERRORS{'DEBUG'}, 0, "VM host $vmhost_computer_name will be controlled using vmware-cmd via SSH");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create an object to control VM host: $vmhost_computer_name");
			return;
		}
	}
	
	if ($SETUP_MODE) {
		$vmware_api->initialize() || return;
	}
	
	# Store the VM host API object in this object
	$self->{api} = $vmware_api;
	
	notify($ERRORS{'DEBUG'}, 0, "VMware OS and API objects created for VM host $vmhost_computer_name:\n" .
		"VM host OS object type: " . ref($self->vmhost_os) . "\n" .
		"VMware API object type: " . ref($self->api) . "\n"
	);
	
	# Make sure the VMware product name can be retrieved
	my $vmhost_product_name = $self->get_vmhost_product_name();
	if (!$vmhost_product_name) {
		notify($ERRORS{'WARNING'}, 0, "VMware module initialization failed, unable to determine VMware product installed on VM host $vmhost_computer_name");
		return;
	}
	
	if ($SETUP_MODE) {
		return 1;
	}
	
	# Make sure the vmx and vmdk base directories can be accessed
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	if (!$vmx_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx base directory path on VM host $vmhost_computer_name");
		return;
	}
	elsif (!$self->vmhost_os->file_exists($vmx_base_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to access vmx base directory path on VM host $vmhost_computer_name: $vmx_base_directory_path");
		return;
	}
	
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmdk base directory path on VM host $vmhost_computer_name");
		return;
	}
	elsif ($vmx_base_directory_path eq $vmdk_base_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "not checking if vmdk base directory exists because it is the same as the vmx base directory: $vmdk_base_directory_path");
	}
	elsif (!$self->vmhost_os->file_exists($vmdk_base_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to access vmdk base directory path: $vmdk_base_directory_path");
		return;
	}
	
	# Retrieve the VM host's hardware info if:
	#    -request state is 'timeout', don't slow down user reservations
	#    -VM host computer.lastcheck is NULL or more than 30 days old
	if ($request_state_name eq 'timeout' && (!$vmhost_lastcheck_time || (time - convert_to_epoch_seconds($vmhost_lastcheck_time)) > (60 * 60 * 24 * 30))) {
		# Configure the SSH authorized_keys file to persist through reboots if the VM host is running VMware ESXi
		# This shouldn't need to be done more than once, only call this if the state is 'reclaim'
		if (ref($self->vmhost_os) =~ /Linux/i && $vmhost_product_name =~ /ESXi 4/) {
			$self->configure_vmhost_dedicated_ssh_key();
		}
		
		# Retrieve the CPU core count, update the database if necessary
		my $cpu_core_count;
		if ($self->api->can('get_cpu_core_count')) {
			$cpu_core_count = $self->api->get_cpu_core_count();
		}
		elsif (!$cpu_core_count && $self->vmhost_os->can('get_cpu_core_count')) {
			$cpu_core_count = $self->vmhost_os->get_cpu_core_count();
		}
		
		if (!$cpu_core_count) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.procnumber not updated, CPU core count could not be retrieved from the API or VM host OS object");
		}
		elsif ($cpu_core_count eq $vmhost_data->get_computer_processor_count()) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.procnumber is already correct in the database");
		}
		else {
			update_computer_procnumber($vmhost_computer_id, $cpu_core_count);
		}
		
		# Retrieve the CPU speed, update the database if necessary
		my $cpu_speed;
		if ($self->api->can('get_cpu_speed')) {
			$cpu_speed = $self->api->get_cpu_speed();
		}
		elsif (!$cpu_speed && $self->vmhost_os->can('get_cpu_speed')) {
			$cpu_speed = $self->vmhost_os->get_cpu_speed();
		}
		
		if (!$cpu_speed) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.procspeed not updated, CPU speed could not be retrieved from the API or VM host OS object");
		}
		elsif ($cpu_speed eq $vmhost_data->get_computer_processor_speed()) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.procspeed is already correct in the database");
		}
		else {
			update_computer_procspeed($vmhost_computer_id, $cpu_speed);
		}
		
		# Retrieve the RAM, update the database if necessary
		my $ram_mb;
		if ($self->api->can('get_total_memory')) {
			$ram_mb = $self->api->get_total_memory();
		}
		elsif (!$ram_mb && $self->vmhost_os->can('get_total_memory')) {
			$ram_mb = $self->vmhost_os->get_total_memory();
		}
		
		if (!$ram_mb) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.RAM not updated, total memory could not be retrieved from the API or VM host OS object");
		}
		elsif ($ram_mb eq $vmhost_data->get_computer_ram()) {
			notify($ERRORS{'DEBUG'}, 0, "VM host computer.RAM is already correct in the database");
		}
		else {
			update_computer_ram($vmhost_computer_id, $ram_mb);
		}
		
		# Update the VM host computer lastcheck time to now
		update_computer_lastcheck($vmhost_computer_id);
	}
	elsif ($request_state_name eq 'timeout') {
		notify($ERRORS{'DEBUG'}, 0, "VM host hardware parameters not updated in the database, last check is less than 30 days ago: $vmhost_lastcheck_time");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : none
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
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_state_name = $self->data->get_request_state_name();
	my $is_server_request = $self->data->is_server_request();
	my $computer_name = $self->data->get_computer_short_name();
	
	# Fist perform the normal checks using the subroutine in Provisioning.pm
	my $result = $self->SUPER::node_status();
	
	# If normal checks require a reload, return it
	if ($result =~ /reload/i) {
		notify($ERRORS{'OK'}, 0, "skipping VMware node status checks, parent node_status subroutine returned $result");
		return $result;
	}
	
	# VM is loaded with the correct image and responding, result is either READY or POST_LOAD
	# If this is a reload request, no additional checks are necessary
	if ($request_state_name =~ /reload/) {
		notify($ERRORS{'DEBUG'}, 0, "request state is '$request_state_name', returning result from normal node_status checks: '$result'");
		return $result;
	}
	
	my $vmx_file_path = $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx file path, returning 'RELOAD'");
		return 'RELOAD';
	}
	
	#>>>>>>>>>>
	# Experimental - Support for VMware ESXi's built in VNC server functionality
	#my $reservation_id = $self->data->get_reservation_id();
	#my $nathost_id = $self->data->get_nathost_id(0);
	#if ($nathost_id) {
	#	my $connect_method_info = get_reservation_connect_method_info($reservation_id);
	#	
	#	my $vnc_connect_method_port_id;
	#	
	#	for my $connect_method_id (keys %$connect_method_info) {
	#		my $connect_method_name = $connect_method_info->{$connect_method_id}{name};
	#		if ($connect_method_name =~ /(VMWare|ESX)/i && $connect_method_name =~ /VNC/i) {
	#			my @vnc_connect_method_port_ids = keys(%{$connect_method_info->{$connect_method_id}{connectmethodport}});
	#			$vnc_connect_method_port_id = $vnc_connect_method_port_ids[0];
	#			last;
	#		}
	#	}
	#	
	#	if ($vnc_connect_method_port_id) {
	#		my $vmx_info = $self->get_vmx_info($vmx_file_path);
	#		if (!$vmx_info) {
	#			notify($ERRORS{'WARNING'}, 0, "unable to retrieve vmx file info, returning 'RELOAD'");
	#			return 'RELOAD';
	#		}
	#		
	#		my $vnc_password = $vmx_info->{'remotedisplay.vnc.password'};
	#		if (!defined($vnc_password)) {
	#			notify($ERRORS{'WARNING'}, 0, "VMware VNC connect method enabled, vmx file does NOT contain VNC password, returning 'RELOAD'");
	#			return 'RELOAD';
	#		}
	#		
	#		my $vnc_port = $vmx_info->{'remotedisplay.vnc.port'};
	#		if (!defined($vnc_port)) {
	#			notify($ERRORS{'WARNING'}, 0, "VMware VNC connect method enabled, vmx file does NOT contain VNC port, returning 'RELOAD'");
	#			return 'RELOAD';
	#		}
	#		
	#		if (!$self->data->set_reservation_password($vnc_password) || !update_reservation_password($reservation_id, $vnc_password)) {
	#			notify($ERRORS{'WARNING'}, 0, "VMware VNC connect method enabled, failed to override reservation password, returning 'RELOAD'");
	#			return 'RELOAD';
	#		}
	#		
	#		if (!insert_natport($reservation_id, $nathost_id, $vnc_connect_method_port_id, $vnc_port)) {
	#			notify($ERRORS{'WARNING'}, 0, "VMware VNC connect method enabled, failed to override NAT port, returning 'RELOAD'");
	#			return 'RELOAD';
	#		}
	#	}
	#}
	#<<<<<<<<<<

	# If this is not a server request, no additional checks are necessary
	if (!$is_server_request) {
		notify($ERRORS{'DEBUG'}, 0, "this is not a server request, returning result from normal node_status checks: '$result'");
		return $result;
	}
	
	# Server request
	notify($ERRORS{'DEBUG'}, 0, "normal node_status checks returned $result, this is a server request, checking if $computer_name is using a dedicated or shared virtual disk");
	
	my $vmdk_file_path_dedicated = $self->get_vmdk_file_path_dedicated();
	if (!$vmdk_file_path_dedicated) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine dedicated vmdk file path, returning 'RELOAD'");
		return 'RELOAD';
	}
	
	
	
	my @vm_virtual_disk_file_paths = $self->api->get_vm_virtual_disk_file_paths($vmx_file_path);
	if (!@vm_virtual_disk_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve virtual disk files paths of $computer_name, returning 'RELOAD'");
		return 'RELOAD';
	}
	
	# Check if any of the vmdk files used by the VM match the dedicated vmdk file path
	for my $virtual_disk_array_ref (@vm_virtual_disk_file_paths) {
		for my $file_path (@$virtual_disk_array_ref) {
			if ($file_path eq $vmdk_file_path_dedicated) {
				notify($ERRORS{'DEBUG'}, 0, "$computer_name is using a dedicated virtual disk: $file_path, returning '$result'");
				return $result;
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$computer_name is NOT using a dedicated virtual disk, returning 'RELOAD'\ndedicated vmdk file path: $vmdk_file_path_dedicated\nvmdk files used by VM:\n" . format_data(\@vm_virtual_disk_file_paths));
	return 'RELOAD';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : none
 Returns     : boolean
 Description : Unloads a VM with the requested image.

=cut

sub unload {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;

	# Remove existing VMs which were created for the reservation computer
	if (!$self->remove_existing_vms()) {
		notify($ERRORS{'WARNING'}, 0, "failed to remove existing VMs created for computer $computer_name on VM host: $vmhost_name");
		return;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	
	
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_name $image_name");
	
	# Remove existing VMs which were created for the reservation computer
	if (!$self->remove_existing_vms()) {
		notify($ERRORS{'WARNING'}, 0, "failed to remove existing VMs created for computer $computer_name on VM host: $vmhost_name");
		return;
	}
	
	# Check if enough disk space is available
	my $enough_disk_space = $self->check_vmhost_disk_space();
	if (!defined($enough_disk_space)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if enough disk space is available on VM host $vmhost_name");
		return;
	}
	elsif (!$enough_disk_space) {
		if (!$self->reclaim_vmhost_disk_space()) {
			notify($ERRORS{'CRITICAL'}, 0, "not enough space is available on VM host $vmhost_name to accomodate the reservation");
			return;
		}
	}
	
	# Check if the .vmdk files exist, copy them if necessary
	if (!$self->prepare_vmdk()) {
		notify($ERRORS{'WARNING'}, 0, "failed to prepare vmdk file for $computer_name on VM host: $vmhost_name");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "transfervm", "copied $image_name to $computer_name");
	
	# Generate the .vmx file
	if (!$self->prepare_vmx()) {
		notify($ERRORS{'WARNING'}, 0, "failed to prepare vmx file for $computer_name on VM host: $vmhost_name");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "prepared vmx file");
	
	# Register the VM
	if (!$self->api->vm_register($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM $computer_name on VM host: $vmhost_name");
		return;
	}
	
	# If API implements 'add_ethernet_adapter' the adapters were not added to the vmx, add them now
	if ($self->api->can('add_ethernet_adapter')) {
		(my @vm_ethernet_adapter_configuration = $self->get_vm_ethernet_adapter_configuration()) || return;
		for my $adapter (@vm_ethernet_adapter_configuration) {
			if (!$self->api->add_ethernet_adapter($vmx_file_path, $adapter)) {
				notify($ERRORS{'WARNING'}, 0, "failed to add ethernet adapter to VM $computer_name on VM host: $vmhost_name\n" . format_data($adapter));
				return;
			}
		}
	}
	
	# Create a snapshot of the VM
	if (!$self->snapshot('register')) {
		notify($ERRORS{'WARNING'}, 0, "failed to create snapshot before powering on VM $computer_name on VM host: $vmhost_name, attempting to delete VM to prevent the possibility of writing to the shared vmdk if the VM is powered on");
		
		# Snapshot failed. If the VM is powered on, changes will be written directly to the shared vmdk
		# Attempt to delete the VM to prevent the shared vmdk from being written to
		if (!$self->delete_vm($vmx_file_path)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to delete VM $computer_name on VM host $vmhost_name after failing to create snapshot, changes may be written to shared vmdk if the VM is powered on");
		}
		return;
	}
	
	
	# Power on the VM
	if (!$self->power_on($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to power on VM $computer_name on VM host: $vmhost_name");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "startvm", "registered and powered on $computer_name");
	
	# Call the OS module's post_load() subroutine if implemented
	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			notify($ERRORS{'OK'}, 0, "performed OS post-load tasks on $computer_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on VM $computer_name on VM host: $vmhost_name");
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "OS post-load tasks not necessary on $computer_name");
	}
	
	# Check if the VM has the expected number of CPUs
	# Some OS's don't recognize additional CPUs when the VM is first loaded if the computer used to capture the image had fewer CPUs
	# Reboot the computer if it has fewer CPUs than expected
	my $vm_os_reported_cpu_count = $self->os->get_cpu_core_count();
	my $vm_expected_cpu_count = $self->get_vm_cpu_configuration();
	
	if (!$vm_os_reported_cpu_count) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if VM OS recognized all CPUs, CPU count could not be retrieved from the VM OS");
	}
	elsif (!$vm_expected_cpu_count) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if VM OS recognized all CPUs, expected CPU count could not be determined");
	}
	elsif ($vm_os_reported_cpu_count == $vm_expected_cpu_count) {
		notify($ERRORS{'DEBUG'}, 0, "verified VM OS recognized correct number of CPUs: $vm_os_reported_cpu_count");
	}
	elsif ($vm_os_reported_cpu_count > $vm_expected_cpu_count) {
		notify($ERRORS{'WARNING'}, 0, "VM OS recognized more CPUs than expected:\nrecognized CPU count: $vm_os_reported_cpu_count\nexpected CPU count: $vm_expected_cpu_count");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "VM OS did not recognize all CPUs, rebooting VM:\nrecognized CPU count: $vm_os_reported_cpu_count\nexpected CPU count: $vm_expected_cpu_count");
		$self->os->reboot(240, 4, 1, 0) || return;
		
		$vm_os_reported_cpu_count = $self->os->get_cpu_core_count();
		if ($vm_os_reported_cpu_count) {
			if ($vm_os_reported_cpu_count < $vm_expected_cpu_count) {
				notify($ERRORS{'WARNING'}, 0, "VM OS did not recognize all CPUs after rebooting VM:\nrecognized CPU count: $vm_os_reported_cpu_count\nexpected CPU count: $vm_expected_cpu_count");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "VM OS recognized correct number of CPUs after rebooting: $vm_os_reported_cpu_count");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine if VM OS recognized all CPUs, CPU count could not be retrieved from the VM OS after rebooting");
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $request_state_name = $self->data->get_request_state_name();
	my $computer_name = $self->data->get_computer_short_name();
	my $image_name = $self->data->get_image_name();
	my $vmhost_name = $self->data->get_vmhost_short_name();
	my $vmprofile_name = $self->data->get_vmhost_profile_name();
	my $vmprofile_vmdisk = $self->data->get_vmhost_profile_vmdisk();
	my $vmdk_base_directory_path_shared = $self->get_vmdk_base_directory_path_shared();
	my $repository_mounted_on_vmhost = $self->is_repository_mounted_on_vmhost();
	
	# Determine the vmx file path actively being used by the VM
	my $vmx_file_path_original = $self->get_active_vmx_file_path();
	if (!$vmx_file_path_original) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the vmx file path actively being used by VM $computer_name");
		return;
	}
	
	# Set the vmx file path in this object so that it overrides the default value that would normally be constructed
	if (!$self->set_vmx_file_path($vmx_file_path_original)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmx file to the path that was determined to be in use by VM $computer_name being captured: $vmx_file_path_original");
		return;
	}
	
	# Get the vmx directory path of the VM being captured
	my $vmx_directory_path_original = $self->get_vmx_directory_path();
	if (!$vmx_directory_path_original) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the vmx directory path of VM $computer_name being captured");
		return;
	}
	
	# Get the information contained within the vmx file
	my $vmx_info = $self->get_vmx_info($vmx_file_path_original);
	notify($ERRORS{'DEBUG'}, 0, "vmx info for VM $computer_name being captured:\n" . format_data($vmx_info));
	
	# Get the vmdk info from the vmx info
	my @vmdk_identifiers = keys %{$vmx_info->{vmdk}};
	if (!@vmdk_identifiers) {
		notify($ERRORS{'WARNING'}, 0, "did not find vmdk file path ({vmdk} key is missing) in vmx info for VM $computer_name being captured:\n" . format_data($vmx_info));
		return;
	}
	elsif (scalar(@vmdk_identifiers) > 1) {
		notify($ERRORS{'WARNING'}, 0, "found multiple vmdk file paths ({vmdk} keys) in vmx info for VM $computer_name being captured:\n" . format_data($vmx_info));
		return;
	}
	
	# Get the vmdk file path to be captured from the vmx information
	my $vmdk_file_path_original = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{vmdk_file_path};
	if (!$vmdk_file_path_original) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path to be captured was not found in the vmx info for VM $computer_name being captured:\n" . format_data($vmx_info));
		return;	
	}
	notify($ERRORS{'DEBUG'}, 0, "vmdk file path configured for VM $computer_name being captured: $vmdk_file_path_original");
	
	# Set the vmdk file path in this object so that it overrides the default value that would normally be constructed
	if (!$self->set_vmdk_file_path($vmdk_file_path_original)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmdk file to the path that is configured for VM $computer_name being captured: $vmdk_file_path_original");
		return;
	}
	
	# Get the vmdk directory path
	my $vmdk_directory_path_original = $self->get_vmdk_directory_path();
	
	# NOTE! Don't change $vmx_file_path_original, $vmx_directory_path_original, $vmdk_file_path_original, or $vmdk_directory_path_original after this point
	# They should not be changed in order to check later on whether the original VM can be deleted
	
	# Get the vmdk mode from the vmx information and make sure it is not nonpersistent
	my $vmdk_mode = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{mode};
	if (!$vmdk_mode) {
		notify($ERRORS{'WARNING'}, 0, "vmdk mode was not found in the vmx info for VM $computer_name being captured:\n" . format_data($vmx_info));
		return;	
	}
	elsif ($vmdk_mode =~ /nonpersistent/i) {
		notify($ERRORS{'WARNING'}, 0, "mode of vmdk: $vmdk_mode, the mode must be persistent or independent-persistent in order to be captured");
		return;	
	}
	notify($ERRORS{'DEBUG'}, 0, "mode of vmdk to be captured is valid: $vmdk_mode");
	
	
	# Construct the vmdk directory and file path where the captured image will be saved
	my $vmdk_directory_path_renamed = "$vmdk_base_directory_path_shared/$image_name";
	my $vmdk_file_path_renamed = "$vmdk_directory_path_renamed/$image_name.vmdk";
	
	# Construct the path of the reference vmx file to be saved with the vmdk
	# The .vmx file is only saved so that it can be referenced later
	my $reference_vmx_file_name = $self->get_reference_vmx_file_name();
	my $vmx_file_path_renamed = "$vmdk_directory_path_renamed/$reference_vmx_file_name";
	
	# Make sure the vmdk file path for the captured image doesn't already exist
	# Do this before calling pre_capture and shutting down the VM
	if ($vmdk_file_path_original ne $vmdk_file_path_renamed && $self->vmhost_os->file_exists($vmdk_file_path_renamed)) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file that captured image will be renamed to already exists: $vmdk_file_path_renamed");
		return;
	}
	
	# Set the imagemeta Sysprep value to 0 to prevent Sysprep from being used
	$self->data->set_imagemeta_sysprep(0);
	
	# Attempt to get the name of the OS running on the VM and tag the .vmx file with it
	# The name will be saved in the reference .vmx file and can be used to select the most appropriate guest OS when loading future VMs
	my $os_product_name = $self->os->get_product_name() if $self->os->can("get_product_name");
	my $os_is_64_bit = $self->os->is_64_bit() if $self->os->can("is_64_bit");
	
	# Call the OS module's pre_capture() subroutine if implemented
	if ($self->os->can("pre_capture") && !$self->os->pre_capture({end_state => 'off'})) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete OS module's pre_capture tasks");
		return;
	}
	
	# Wait for the VM to power off
	# This OS module may initiate a shutdown and immediately return
	if (!$self->wait_for_power_off(600)) {
		notify($ERRORS{'WARNING'}, 0, "VM $computer_name has not powered off after the OS module's pre_capture tasks were completed, powering off VM forcefully");
		
		if ($self->api->vm_power_off($vmx_file_path_original)) {
			# Sleep for 10 seconds to make sure the power off is complete
			sleep 10;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to power off the VM being captured after the OS module's pre_capture tasks were completed");
			return;
		}
	}
	
	# Tag the .vmx with the OS product name and architecture
	$self->vmhost_os->append_text_file($vmx_file_path_original, "#os_product_name = \"$os_product_name\"") if (defined($os_product_name));
	$self->vmhost_os->append_text_file($vmx_file_path_original, "#os_64_bit = \"$os_is_64_bit\"") if (defined($os_is_64_bit));
	
	
	if ($vmprofile_vmdisk =~ /(local|dedicated)/ && $repository_mounted_on_vmhost) {
		# See https://issues.apache.org/jira/browse/VCL-633
		# Don't save copy on VM host's datastore if dedicated, datastore may run out of space
		notify($ERRORS{'DEBUG'}, 0, "vmx and vmdk files will not be copied or renamed directly on the host, the VM profile disk type is $vmprofile_vmdisk and the image repository is mounted on the host");
		$vmdk_file_path_renamed = $vmdk_file_path_original;
		
		# Need to copy the original vmx to vmx.reference using the base name of the vmdk
		# copy_vmdk expects a file with this name to exist in order for the reference file to be created in the target directory
		my $vmdk_file_base_name_renamed = $self->_get_file_base_name($vmdk_file_path_renamed);
		$vmx_file_path_renamed = "$vmx_directory_path_original/$vmdk_file_base_name_renamed.vmx.reference";
	}
	else {
		# Rename the vmdk to the new image directory and file name
		# First check if vmdk file path already matches the destination file path
		if ($vmdk_file_path_original eq $vmdk_file_path_renamed) {
			notify($ERRORS{'DEBUG'}, 0, "vmdk files will not be renamed, vmdk file path being captured is already named as the image being captured: '$vmdk_file_path_original'");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "vmdk files will be renamed: '$vmdk_file_path_original' --> '$vmdk_file_path_renamed'");
			if (!$self->copy_vmdk($vmdk_file_path_original, $vmdk_file_path_renamed)) {
				notify($ERRORS{'WARNING'}, 0, "failed to copy the vmdk files after the VM was powered off: '$vmdk_file_path_original' --> '$vmdk_file_path_renamed'");
				return;
			}
		}
	}
	
	# Copy the vmx file to the new image directory for later reference
	# First check if vmx file already exists (could happen if base image VM was manually created)
	if ($vmx_file_path_original eq $vmx_file_path_renamed) {
		notify($ERRORS{'DEBUG'}, 0, "vmx file will not be copied, vmx file path being captured is already named as the image being captured: '$vmx_file_path_original'");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmx file will be copied: '$vmx_file_path_original' --> '$vmx_file_path_renamed'");
		if (!$self->vmhost_os->copy_file($vmx_file_path_original, $vmx_file_path_renamed)) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy the reference vmx file after the VM was powered off: '$vmx_file_path_original' --> '$vmx_file_path_renamed'");
			return;
		}
	}

	# Copy the vmdk to the image repository if the repository path is defined in the VM profile
	my $repository_directory_path = $self->get_repository_vmdk_directory_path();
	if ($repository_directory_path) {
		my $repository_copy_successful = 0;
		
		# Check if the image repository path configured in the VM profile is mounted on the host or on the management node
		if ($repository_mounted_on_vmhost) {
			# Files can be copied directly to the image repository and converted while they are copied
			my $repository_vmdk_file_path = $self->get_repository_vmdk_file_path();
			notify($ERRORS{'DEBUG'}, 0, "vmdk will be copied directly from VM host $vmhost_name to the image repository in the 2gbsparse disk format: '$vmdk_file_path_renamed' --> '$repository_vmdk_file_path'");
			if ($self->copy_vmdk($vmdk_file_path_renamed, $repository_vmdk_file_path, '2gbsparse')) {
				$repository_copy_successful = 1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to copy the vmdk files to the repository mounted on the VM host after the VM was powered off: '$vmdk_file_path_renamed' --> '$repository_vmdk_file_path'");
			}
		}
		else {
			# Repository is not mounted on the VM host
			# Check if virtual disk type is sparse - vmdk can't be converted to 2gb sparse while it is copied
			# If the virtual disk isn't sparse a sparse copy is created on the datastore
			my $vmdk_directory_path_sparse;
			my $vmdk_file_path_sparse;
			my @vmdk_copy_paths;
			
			my $virtual_disk_type = $self->api->get_virtual_disk_type($vmdk_file_path_renamed);
			if (!$virtual_disk_type) {
				notify($ERRORS{'WARNING'}, 0, "failed to determine the virtual disk type of the vmdk being captured: $vmdk_file_path_renamed");
			}
			elsif ($virtual_disk_type =~ /sparse/i) {
				# Virtual disk is sparse, get a list of the vmdk file paths
				notify($ERRORS{'DEBUG'}, 0, "vmdk can be copied directly from VM host $vmhost_name to the image repository because the virtual disk type is sparse: $virtual_disk_type");
				@vmdk_copy_paths = $self->find_datastore_files($vmdk_directory_path_renamed, '*.vmdk');
			}
			else {
				# Virtual disk is NOT sparse - a sparse copy must first be created before being copied to the repository
				notify($ERRORS{'DEBUG'}, 0, "vmdk disk type: $virtual_disk_type, a temporary 2gbsparse copy of the vmdk will be made on VM host $vmhost_name, copied to the image repository, and then deleted from the VM host");
				
				# Construct the vmdk file path where the 2gbsparse copy will be created
				# The vmdk files are copied to a directory with the same name but with '_2gbsparse' appended to the directory name
				# The vmdk files in the '_2gbsparse' are named the same as the original non-sparse directory
				$vmdk_directory_path_sparse = "$vmdk_directory_path_renamed\_2gbsparse";
				$vmdk_file_path_sparse = "$vmdk_directory_path_sparse/$image_name.vmdk";
				
				# Create a sparse copy of the virtual disk
				if ($self->copy_vmdk($vmdk_file_path_renamed, $vmdk_file_path_sparse, '2gbsparse')) {
					# Get a list of the 2gbsparse vmdk file paths
					@vmdk_copy_paths = $self->find_datastore_files($vmdk_directory_path_sparse, '*.vmdk');
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to create a temporary 2gbsparse copy of the vmdk file: '$vmdk_file_path_renamed' --> '$vmdk_file_path_sparse'");
				}
			}
			
			# Copy the vmdk directory from the VM host to the image repository
			if (@vmdk_copy_paths) {
				# Add the reference vmx file path to the array so that the vmx is copied to the repository
				push @vmdk_copy_paths, $vmx_file_path_renamed;
				
				# Loop through the files, copy each to the management node's repository directory
				notify($ERRORS{'DEBUG'}, 0, "vmdk files will be copied from VM host $vmhost_name to the image repository on the management node:\n" . join("\n", sort @vmdk_copy_paths));
				VMDK_COPY_PATH: for my $vmdk_copy_path (@vmdk_copy_paths) {
					my ($vmdk_copy_name) = $vmdk_copy_path =~ /([^\/]+)$/;
					
					# Set the flag to 1 before copying, set it back to 0 if any files fail to be copied
					$repository_copy_successful = 1;
					
					if (!$self->vmhost_os->copy_file_from($vmdk_copy_path, "$repository_directory_path/$vmdk_copy_name")) {
						notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk file from VM host $vmhost_name to the management node:\n '$vmdk_copy_path' --> '$repository_directory_path/$vmdk_copy_name'");
						$repository_copy_successful = 0;
						last VMDK_COPY_PATH;
					}
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to find the vmdk files on VM host $vmhost_name to copy back to the managment node's image repository");
			}
			
			# Check if the $vmdk_directory_path_sparse variable has been set
			# If set, a sparse copy of the vmdk files had to be created
			# The sparse directory should be deleted
			if ($vmdk_directory_path_sparse) {
				notify($ERRORS{'DEBUG'}, 0, "deleting the directory containing the temporary 2gbsparse copy of the vmdk files which were copied to the image repository: $vmdk_directory_path_sparse");
				
				if (!$self->vmhost_os->delete_file($vmdk_directory_path_sparse)) {
					notify($ERRORS{'WARNING'}, 0, "failed to delete the directory containing the 2gbsparse copy of the vmdk files: $vmdk_directory_path_sparse");
				}
			}
		}
		
		# The $repository_copy_successful flag should be set to 1 by this point if the copy was successful
		if (!$repository_copy_successful) {
			# Rename the vmdk back to the original file name
			# This is necessary to power the VM back on in order to fix the problem because the VM's vmx file still contains the path to the original vmdk
			# First check if vmdk file path already matches the destination file path
			if ($vmdk_file_path_original eq $vmdk_file_path_renamed) {
				notify($ERRORS{'DEBUG'}, 0, "vmdk file does not need to be renamed back to the original name, vmdk file path being captured is already named as the image being captured: '$vmdk_file_path_original'");
				
				# Attempt to power the VM back on
				# This saves a step when troubleshooting the problem
				notify($ERRORS{'DEBUG'}, 0, "attempting to power the VM back on so that it can be captured again");
				$self->power_on($vmx_file_path_original);
			}
			else {
				# Delete the directory where the vmdk was copied
				if ($vmdk_directory_path_original ne $vmdk_directory_path_renamed) {
					notify($ERRORS{'DEBUG'}, 0, "attempting to delete directory where moved vmdk resided before reverting the name back to the original: $vmdk_directory_path_renamed");
					$self->vmhost_os->delete_file($vmdk_directory_path_renamed);
				}
				
				# Attempt to power the VM back on
				# This saves a step when troubleshooting the problem
				notify($ERRORS{'DEBUG'}, 0, "attempting to power the VM back on so that it can be captured again");
				$self->power_on($vmx_file_path_original);
			}
			return;
		}
		
		# Attempt to set permissions on the image repository directory
		# Don't fail the capture if this fails, it only affects image retrieval from another managment node
		$self->set_image_repository_permissions();
	}
	else {
		# The repository path isn't set in the VM profile
		notify($ERRORS{'OK'}, 0, "vmdk files NOT copied to the image repository because the repository path is not configured in VM profile '$vmprofile_name'");
	}
	
	# Delete the VM that was captured
	# Make sure the VM's vmx and vmdk path don't match the path of the captured image
	if ($vmx_directory_path_original eq $vmdk_directory_path_renamed) {
		notify($ERRORS{'WARNING'}, 0, "VM will NOT be deleted because the VM's vmx directory path matches the captured vmdk directory path: '$vmdk_directory_path_renamed'");
	}
	elsif ($vmdk_directory_path_original eq $vmdk_directory_path_renamed) {
		notify($ERRORS{'WARNING'}, 0, "VM will NOT be deleted because the VM's vmdk directory path configured in the vmx file matches the captured vmdk directory path: '$vmdk_directory_path_renamed'");
	}
	elsif ($request_state_name !~ /^(image)$/) {
		notify($ERRORS{'OK'}, 0, "VM will NOT be deleted because the request state is '$request_state_name'");
	}
	else {
		# Delete the VM
		if (!$self->delete_vm($vmx_file_path_original)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete the VM after the image was captured: $vmx_file_path_original");
		}
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
               
               If the MAC addresses cannot be retrieved from the VM's OS, the
               MAC addresses in the database are used.

=cut

sub get_active_vmx_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $os_type = $self->data->get_image_os_type();
	my $computer_name = $self->data->get_computer_short_name();
	my $computer_eth0_mac_address = $self->data->get_computer_eth0_mac_address();
	my $computer_eth1_mac_address = $self->data->get_computer_eth1_mac_address();
	
	my @vm_mac_addresses;
	
	if (!$self->os->is_ssh_responding()) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name is not responding, unable to verify MAC addresses reported by OS match MAC addresses in vmx file");
		@vm_mac_addresses = ($computer_eth0_mac_address, $computer_eth1_mac_address);
	}
	else {
		my $active_os;
		my $active_os_type = $self->os->get_os_type();
		if (!$active_os_type) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine OS type currently installed on $computer_name");
			$active_os = $self->os();
		}
		elsif ($active_os_type ne $os_type) {
			notify($ERRORS{'DEBUG'}, 0, "OS type currently installed on $computer_name does not match the OS type of the reservation image:\nOS type installed on $computer_name: $active_os_type\nreservation image OS type: $os_type");
			
			my $active_os_perl_package;
			if ($active_os_type =~ /linux/i) {
				$active_os_perl_package = 'VCL::Module::OS::Linux';
			}
			else {
				$active_os_perl_package = 'VCL::Module::OS::Windows';
			}
			
			if ($active_os = $self->create_os_object($active_os_perl_package)) {
				notify($ERRORS{'DEBUG'}, 0, "created a '$active_os_perl_package' OS object for the '$active_os_type' OS type currently installed on $computer_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to determine active vmx file path, failed to create a '$active_os_perl_package' OS object for the '$active_os_type' OS type currently installed on $computer_name");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$active_os_type' OS type currently installed on $computer_name matches the OS type of the image assigned to this reservation");
			$active_os = $self->os;
		}
		
		# Make sure the active OS object implements the required subroutines called below
		if (!$active_os->can('get_private_mac_address') || !$active_os->can('get_public_mac_address')) {
			notify($ERRORS{'WARNING'}, 0, ref($active_os) . " OS object does not implement 'get_private_mac_address' and 'get_public_mac_address' subroutines, unable to verify MAC addresses reported by OS match MAC addresses in vmx file");
			@vm_mac_addresses = ($computer_eth0_mac_address, $computer_eth1_mac_address);
		}
		else {
			# Get the MAC addresses being used by the running VM for this reservation
			my $active_private_mac_address = $active_os->get_private_mac_address();
			my $active_public_mac_address = $active_os->get_public_mac_address();
			push @vm_mac_addresses, $active_private_mac_address if $active_private_mac_address;
			push @vm_mac_addresses, $active_public_mac_address if $active_public_mac_address;
		}
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
	my @matching_host_vmx_paths_powered_on;
	my @matching_host_vmx_paths_powered_off;
	for my $host_vmx_path (@host_vmx_file_paths) {
		# Quit checking if a match has already been found and the vmx path being checked doesn't contain the computer name
		last if ((@matching_host_vmx_paths_powered_on || @matching_host_vmx_paths_powered_off) && $host_vmx_path !~ /$computer_name/);
		
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
			notify($ERRORS{'DEBUG'}, 0, "ignoring $vmx_file_name because the VM is not registered");
			next;
		}
		
		# Ignore the vmx file if the VM is powered on
		my $power_state = $self->api->get_vm_power_state($host_vmx_path) || 'unknown';
		if ($power_state !~ /on/i) {
			notify($ERRORS{'DEBUG'}, 0, "found matching MAC address between $computer_name (powered off) and $vmx_file_name:\n" . join("\n", sort(@matching_mac_addresses)));
			push @matching_host_vmx_paths_powered_off, $host_vmx_path;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found matching MAC address between $computer_name (powered on) and $vmx_file_name:\n" . join("\n", sort(@matching_mac_addresses)));
			push @matching_host_vmx_paths_powered_on, $host_vmx_path;
		}
	}
	
	# Check if any matching vmx files were found
	if (@matching_host_vmx_paths_powered_on) {
		if (scalar(@matching_host_vmx_paths_powered_on) > 1) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine active vmx file path, found multiple vmx files of powered on VMs on the VM host containing a MAC address matching $computer_name:\n" . join("\n", @matching_host_vmx_paths_powered_on));
			return;
		}
		my $matching_vmx_file_path = $matching_host_vmx_paths_powered_on[0];
		notify($ERRORS{'OK'}, 0, "found vmx file being used by $computer_name (powered on): $matching_vmx_file_path");
		return $matching_vmx_file_path;
	}
	elsif (@matching_host_vmx_paths_powered_off) {
		if (scalar(@matching_host_vmx_paths_powered_off) > 1) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine active vmx file path, found no vmx files of powered on VMs, found multiple vmx files of powered off VMs on the VM host containing a MAC address matching $computer_name:\n" . join("\n", @matching_host_vmx_paths_powered_off));
			return;
		}
		my $matching_vmx_file_path = $matching_host_vmx_paths_powered_off[0];
		notify($ERRORS{'OK'}, 0, "found vmx file being used by $computer_name (powered off): $matching_vmx_file_path");
		return $matching_vmx_file_path;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine active vmx file path, did not find any vmx files on the VM host containing a MAC address matching $computer_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 vmhost_data

 Parameters  : none
 Returns     : DataStructure object reference
 Description : Returns the DataStructure object containing the VM host data.

=cut

sub vmhost_data {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (!$self->{vmhost_data}) {
		notify($ERRORS{'WARNING'}, 0, "VM host DataStructure object is not defined as \$self->{vmhost_data}");
		return;
	}
	
	return $self->{vmhost_data};
}

#//////////////////////////////////////////////////////////////////////////////

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
		notify($ERRORS{'DEBUG'}, 0, "attempting to initialize");
		if (!$self->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize");
			return;
		}
		elsif (!$self->{api}) {
			notify($ERRORS{'WARNING'}, 0, "api object is not defined");
			return;
		}
	}
	
	return $self->{api};
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $request_data = $self->data->get_request_data();
	my $reservation_id = $self->data->get_reservation_id();
	my $vmhost_computer_id = $self->data->get_vmhost_computer_id();
	my $vmhost_profile_image_id = $self->data->get_vmhost_profile_image_id();
	
	# Create a DataStructure object containing computer data for the VM host
	my $vmhost_data;
	eval {
		$vmhost_data= new VCL::DataStructure({request_data => $request_data,
			reservation_id => $reservation_id,
			computer_identifier => $vmhost_computer_id,
			image_identifier => $vmhost_profile_image_id});
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
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host node name from DataStructure object created for VM host\n");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "created DataStructure object for VM host: $vmhost_computer_node_name");
	$self->{vmhost_data} = $vmhost_data;
	return $vmhost_data;
}

#//////////////////////////////////////////////////////////////////////////////

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
		notify($ERRORS{'DEBUG'}, 0, "VM host OS object created: " . ref($vmhost_os));
		return $vmhost_os;
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

#//////////////////////////////////////////////////////////////////////////////

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
	eval { $api = ($api_perl_package)->new({
		data_structure => $self->data,
		vmhost_data => $vmhost_datastructure,
		vmhost_os => $self->vmhost_os
	})};
	if (!$api) {
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "API object could not be created: $api_perl_package, error:\n$EVAL_ERROR");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "API object could not be created: $api_perl_package");
			return;
		}
	}
	
	$api->{api} = $api;
	
	notify($ERRORS{'DEBUG'}, 0, "created API object: $api_perl_package");
	return $api;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_existing_vms

 Parameters  : none
 Returns     : boolean
 Description : Removes VMs from a VMware host which were previously created for
               the VM. It only removes VMs created for the VM assigned to the
               reservation. It does not delete all VM's from the host.

=cut

sub remove_existing_vms {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	
	# Get an array containing the existing vmx file paths on the VM host
	my @vmx_file_paths = $self->get_vmx_file_paths();
	my %vmx_file_path_hash = map { $_ => 1 } (@vmx_file_paths);
	
	# Loop through the existing vmx file paths found, check if it matches the VM for this reservation
	for my $vmx_file_path (@vmx_file_paths) {
		my $vmx_file_name = $self->_get_file_name($vmx_file_path);
		notify($ERRORS{'DEBUG'}, 0, "checking existing vmx file: '$vmx_file_path'");
		
		# Section commented out because it may prevent VM from being deleted if datastores change
		# Ignore file if it does not begin with the base directory path
		# get_vmx_file_paths() will return all vmx files it finds under the base directory path and all registered vmx files
		# It's possible for a vmx file to be registered that resided on some other datastore
		#if ($vmx_file_path !~ /^$vmx_base_directory_path/) {
		#	notify($ERRORS{'DEBUG'}, 0, "ignoring existing vmx file '$vmx_file_path' because it does not begin with the base directory path: '$vmx_base_directory_path'");
		#	next;
		#}
		
		# Check if the vmx directory name matches the naming convention VCL would use for the computer
		my $vmx_file_path_computer_name = $self->_get_file_path_computer_name($vmx_file_path);
		if (!$vmx_file_path_computer_name) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring existing vmx file $vmx_file_name, the computer name could not be determined from the directory name");
			next;
		}
		elsif ($vmx_file_path_computer_name ne $computer_name) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring existing vmx file: $vmx_file_name, the directory computer name '$vmx_file_path_computer_name' does not match the reservation computer name '$computer_name'");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found existing vmx file $vmx_file_name with matching computer name $computer_name: $vmx_file_path");
			
			# Delete the existing VM from the VM host
			if (!$self->delete_vm($vmx_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to delete existing VM: $vmx_file_path");
			}
		}
	}
	
	# Delete orphaned vmx or vmdk directories previously created by VCL for the computer
	# Find any files under the vmx or vmdk base directories matching the computer name
	my @orphaned_vmx_file_paths = $self->find_datastore_files($vmx_base_directory_path, "*$computer_name*\.vmx");
	
	# Check if any of the paths match the format of a directory VCL would have created for the computer
	for my $orphaned_vmx_file_path (@orphaned_vmx_file_paths) {
		# Check if the directory name matches the naming convention VCL would use for the computer
		my $orphaned_computer_name = $self->_get_file_path_computer_name($orphaned_vmx_file_path);
		if (!$orphaned_computer_name) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring existing file path '$orphaned_vmx_file_path', the computer name could not be determined from the directory name");
			next;
		}
		elsif ($orphaned_computer_name ne $computer_name) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring existing file: '$orphaned_vmx_file_path', the directory computer name '$orphaned_computer_name' does not match the reservation computer name '$computer_name'");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found orphaned file '$orphaned_vmx_file_path' with matching computer name $computer_name");
			
			# Delete the orphaned VM from the VM host
			if (!$self->delete_vm($orphaned_vmx_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to delete orphaned VM: $orphaned_vmx_file_path");
			}
		}
	}
	
	# Make sure the computer assigned to this reservation isn't still responding
	# This could occur if a VM was configured to use the IP address but the directory where the VM resides doesn't match the name VCL would have given it
	my $remote_connection_target = determine_remote_connection_target($computer_name);
	if (_pingnode($computer_name)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name ($remote_connection_target) is still responding to ping after deleting deleting matching VMs");
		return 0;
	}
	elsif ($self->os->is_ssh_responding()) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name ($remote_connection_target) is still responding to SSH after deleting deleting matching VMs");
		return 0;
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	my $image_id                  = $self->data->get_image_id() || return;
	my $imagerevision_id          = $self->data->get_imagerevision_id() || return;
	my $image_project             = $self->data->get_image_project() || return;
	my $computer_id               = $self->data->get_computer_id() || return;
	my $vmx_file_name             = $self->get_vmx_file_name() || return;
	my $vmx_file_path             = $self->get_vmx_file_path() || return;
	my $vmx_directory_name        = $self->get_vmx_directory_name() || return;
	my $vmx_directory_path        = $self->get_vmx_directory_path() || return;
	my $vmdk_file_path            = $self->get_vmdk_file_path() || return;
	my $computer_name             = $self->data->get_computer_short_name() || return;
	my $image_name                = $self->data->get_image_name() || return;
	my $vm_ram                    = $self->get_vm_ram() || return;
	my $vm_ethernet_adapter_type  = $self->get_vm_ethernet_adapter_type() || return;
	my $vm_eth0_generated         = $self->data->get_vmhost_profile_eth0generated(0);
	my $vm_eth1_generated         = $self->data->get_vmhost_profile_eth1generated(0);
	my $virtual_switch_0          = $self->data->get_vmhost_profile_virtualswitch0(0) || '';
	my $virtual_switch_1          = $self->data->get_vmhost_profile_virtualswitch1(0) || '';
	my $virtual_switch_2          = $self->data->get_vmhost_profile_virtualswitch2(0) || '';
	my $virtual_switch_3          = $self->data->get_vmhost_profile_virtualswitch3(0) || '';
	my $vm_disk_adapter_type      = $self->get_vm_disk_adapter_type() || return;
	my $vm_hardware_version       = $self->get_vm_virtual_hardware_version() || return;
	my $is_vm_dedicated           = $self->is_vm_dedicated();
	my $guest_os                  = $self->get_vm_guest_os() || return;
	my $vmware_product_name       = $self->get_vmhost_product_name();
	my $image_os_type            = $self->data->get_image_os_type();
	
	(my ($vm_cpu_count, $vm_cores_per_socket) = $self->get_vm_cpu_configuration()) || return;
	
	# Create the .vmx directory on the host
	if (!$self->vmhost_os->create_directory($vmx_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create .vmx directory on VM host: $vmx_directory_path");
		return;
	}
	
	# Set the disk parameters based on whether or not the VM has a dedicated virtual disk
	# Also set the display name to indicate if the VM has a shared or dedicated virtual disk
	my $display_name = "$computer_name\_$image_name";
	
	my $vm_disk_mode = 'persistent';
	my $vm_disk_write_through = "TRUE";
	my $vm_disk_shared_bus = "none";
	
	# Determine which parameter to use in the vmx file for the network name
	# VMware Server 1.x uses 'vnet', newer VMware products use 'networkName'
	my $network_parameter;
	if ($vmware_product_name =~ /VMware Server 1/i) {
		$network_parameter = 'vnet';
	}
	else {
		$network_parameter = 'networkName';
	}
	
	notify($ERRORS{'DEBUG'}, 0, "vm info:
		display name: $display_name
		vmx file path: $vmx_file_path
		vmdk file path: $vmdk_file_path"
	);
	
	# Create a hash containing the vmx parameter names and values
	my %vmx_parameters = (
		"#image_id" => "$image_id",
		"#imagerevision_id" => "$imagerevision_id",
		"#computer_id" => "$computer_id",
		".encoding" => "UTF-8",
		#"bios.bootDelay" => "1000",
		"config.version" => "8",
		"cpuid.coresPerSocket" => "$vm_cores_per_socket",
		"displayName" => "$display_name",
		"floppy0.present" => "FALSE",
		"guestOS" => "$guest_os",
		"gui.exitOnCLIHLT" => "TRUE",	# causes the virtual machine to power off automatically when you choose Start > Shut Down from the Windows guest
		"memsize" => "$vm_ram",
		"mem.hotadd" => "TRUE",
		"msg.autoAnswer" => "TRUE",	# tries to automatically answer all questions that may occur at boot-time.
		#"mks.enable3d" => "TRUE",
		#"mks.gl.allowBlacklistedDrivers" => "TRUE",
		"numvcpus" => "$vm_cpu_count",
		"powerType.powerOff" => "soft",
		"powerType.powerOn" => "hard",
		"powerType.reset" => "soft",
		"powerType.suspend" => "hard",
		"sched.swap.dir" => "$vmx_directory_path/",
		"snapshot.redoNotWithParent" => "TRUE",
		"svga.autodetect" => "TRUE",
		#"svga.yes3d" => "TRUE",
		"tools.remindInstall" => "FALSE",
		"tools.syncTime" => "FALSE",
		"toolScripts.afterPowerOn" => "FALSE",
		"toolScripts.afterResume" => "FALSE",
		"toolScripts.beforeSuspend" => "FALSE",
		"toolScripts.beforePowerOff" => "FALSE",
		#"tools.upgrade.policy" => "upgradeAtPowerCycle",
		"usb.present" => "TRUE",
		"uuid.action" => "keep",	# Keep the VM's uuid, keeps existing MAC
		"vcpu.hotadd" => "TRUE",
		"virtualHW.version" => "$vm_hardware_version",
		"workingDir" => "$vmx_directory_path",
	);
	
	if ($self->api->is_nested_virtualization_supported()) {
		%vmx_parameters = (%vmx_parameters, (
			"cpuid.1.ecx" => "--------------------------H-----",
			"featMask.vm.hv.capable" => "Min:1",
			"hypervisor.cpuid.v0" => "FALSE",
			"monitor.virtual_mmu" => "hardware",
			"monitor.virtual_exec" => "hardware",
			"vhv.enable" => "TRUE",
		));
	}
	
	#>>>>>>>>>>
	## Experimental - Support for VMware ESXi's built in VNC server functionality
	#my $reservation_id = $self->data->get_reservation_id();
	#my $vnc_password = $self->data->get_reservation_password(0);
	#if (!defined($vnc_password)) {
	#	$vnc_password = getpw();
	#	update_reservation_password($reservation_id, $vnc_password);
	#	$self->data->set_reservation_password($vnc_password);
	#}
	#
	#my $vnc_port = ($computer_id + 10000);
	#notify($ERRORS{'DEBUG'}, 0, "vnc access will be enabled, port: $vnc_port, password: $vnc_password");
	#%vmx_parameters = (%vmx_parameters, (
	#	"RemoteDisplay.vnc.enabled" => "TRUE",
	#	"RemoteDisplay.vnc.password" => $vnc_password,
	#	"RemoteDisplay.vnc.port" => $vnc_port,
	#));
	#<<<<<<<<<<
	
	# Add the disk adapter parameters to the hash
	if ($vm_disk_adapter_type =~ /ide/i) {
		%vmx_parameters = (%vmx_parameters, (
			"ide0:0.fileName" => "$vmdk_file_path",
			"ide0:0.mode" => "$vm_disk_mode",
			"ide0:0.present" => "TRUE",
			"ide0:0.writeThrough" => "$vm_disk_write_through",
			"ide0:0.sharedBus" => "$vm_disk_shared_bus",
			
			"ide0:1.startConnected" => "FALSE",
			"ide0:1.deviceType" => "cdrom-raw",
			"ide0:1.clientDevice" => "TRUE",
			"ide0:1.fileName" => "emptyBackingString",
			"ide0:1.present" => "TRUE",
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
			"scsi0:0.sharedBus" => "$vm_disk_shared_bus",
			
			"ide0:0.startConnected" => "FALSE",
			"ide0:0.deviceType" => "cdrom-raw",
			"ide0:0.clientDevice" => "TRUE",
			"ide0:0.fileName" => "emptyBackingString",
			"ide0:0.present" => "TRUE",
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
	
	# ide needed for boot
	# usb needed for mouse
	# monitor, ich7m, smc for darwin
	if ($image_os_type =~ /osx/i) {
		%vmx_parameters = (%vmx_parameters, (
			"ide1:0.clientDevice" => "TRUE",
			"ide1:0.deviceType" => "atapi-cdrom",
			"ide1:0.fileName" => "",           
			"ide1:0.present" => "TRUE", 
			"ide1:0.startConnected" => "FALSE",
			"usb.present" => "TRUE",                              
			"usb:1.deviceType" => "hub",      
			"usb:1.present" => "TRUE",    
			"usb:2.deviceType" => "mouse",    
			"usb:2.present" => "TRUE", 
			"monitor.virtual_exec" => "hardware",
			"monitor.virtual_mmu" => "software",
			"ich7m.present" => "TRUE",
			"smc.present" => "FALSE",
			"keyboard.vusb.enable" => "TRUE",
			"mouse.vusb.enable" => "TRUE",
		));
	}

	# Check if the API implements 'add_ethernet_adapter'
	# This is necessary if the host is using dvSwitches/dvPorts
	# Adding the info to the vmx before it is registered will not work
	if ($self->api->can('add_ethernet_adapter')) {
		notify($ERRORS{'DEBUG'}, 0, "ethernet adapters not added to vmx file, they will be added after the VM is registered");
	}
	else {
		(my @vm_ethernet_adapter_configuration = $self->get_vm_ethernet_adapter_configuration()) || return;
		
		my $interface_index = 0;
		for my $adapter (@vm_ethernet_adapter_configuration) {
			if ($adapter->{address_type} =~ /Manual/i) {
				%vmx_parameters = (%vmx_parameters, (
					"ethernet$interface_index.present" => "TRUE",
					"ethernet$interface_index.connectionType" => "custom",
					"ethernet$interface_index.virtualDev" => $adapter->{adapter_type},
					"ethernet$interface_index.networkName" => $adapter->{network_name},
					"ethernet$interface_index.addressType" => "static",
					"ethernet$interface_index.address" => $adapter->{address},
				));
			}
			else {
				%vmx_parameters = (%vmx_parameters, (
					"ethernet$interface_index.present" => "TRUE",
					"ethernet$interface_index.connectionType" => "custom",
					"ethernet$interface_index.virtualDev" => $adapter->{adapter_type},
					"ethernet$interface_index.networkName" => $adapter->{network_name},
					"ethernet$interface_index.addressType" => "generated",
				));
			}
			$interface_index++;
		}
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
	
	# The vmx file should be set to executable
	chmod("0755", "/tmp/$vmx_file_name");
	
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_ethernet_adapter_configuration

 Parameters  : none
 Returns     : array of hashes
 Description : Assembles a data structure containing the ethernet adapter
 configuration for the VM.

=cut

sub get_vm_ethernet_adapter_configuration {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_project = $self->data->get_image_project();
	my $virtual_switch_0 = $self->data->get_vmhost_profile_virtualswitch0(0);
	my $virtual_switch_1 = $self->data->get_vmhost_profile_virtualswitch1(0);
	my $virtual_switch_2 = $self->data->get_vmhost_profile_virtualswitch2(0);
	my $virtual_switch_3 = $self->data->get_vmhost_profile_virtualswitch3(0);
	my $vm_ethernet_adapter_type = $self->get_vm_ethernet_adapter_type() || return;
	
	# Get a list of all the network names configured on the VMware host
	my @network_names = $self->api->get_network_names();
	if (!@network_names) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble ethernet adapter configuration, network names could not be retrieved from the VM host");
		return;
	}
	
	# Make sure all network names configured in the VM host profile actually exist on the host
	for my $network_name ($virtual_switch_0, $virtual_switch_1, $virtual_switch_2, $virtual_switch_3) {
		if ($network_name && !grep(/^$network_name$/, @network_names)) {
			notify($ERRORS{'WARNING'}, 0, "unable to assemble ethernet adapter configuration, network name '$network_name' configured in the VM profile does not match any network names on the VM host:\n" . join("\n", sort @network_names));
			return;
		}
	}
	
	my @adapters;
	
	if ($virtual_switch_0) {
		my $adapter_configuration = {
			network_name => $virtual_switch_0,
			adapter_type => $vm_ethernet_adapter_type,
		};
		if ($self->data->get_vmhost_profile_eth0generated(0)) {
			$adapter_configuration->{address_type} = 'Generated',
		}
		else {
			$adapter_configuration->{address_type} = 'Manual';
			$adapter_configuration->{address} = $self->data->get_computer_eth0_mac_address();
		}
		push @adapters, $adapter_configuration;
	}
	
	if ($virtual_switch_1) {
		my $adapter_configuration = {
			network_name => $virtual_switch_1,
			adapter_type => $vm_ethernet_adapter_type,
		};
		if ($self->data->get_vmhost_profile_eth1generated(0)) {
			$adapter_configuration->{address_type} = 'Generated',
		}
		else {
			$adapter_configuration->{address_type} = 'Manual';
			$adapter_configuration->{address} = $self->data->get_computer_eth1_mac_address();
		}
		push @adapters, $adapter_configuration;
	}
	
	my @additional_network_names;
	push @additional_network_names, $virtual_switch_2 if $virtual_switch_2;
	push @additional_network_names, $virtual_switch_3 if $virtual_switch_3;
	
	# Add additional Ethernet interfaces if the image project name is not vcl
	if ($image_project !~ /^vcl$/i) {
		notify($ERRORS{'DEBUG'}, 0, "image project is: $image_project, checking if additional network adapters should be configured");
		
		# Check each network name
		for my $network_name (@network_names) {
			if ($network_name =~ /$image_project/i || $image_project =~ /$network_name/i) {
				notify($ERRORS{'DEBUG'}, 0, "network name ($network_name) and image project name ($image_project) intersect, adding network interface to VM for network $network_name");
				push @additional_network_names, $network_name;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "network name ($network_name) and image project name ($image_project) do not intersect, network interface will not be added to VM for network $network_name");
			}
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image project is: $image_project, no additional network adapters will be configured");
	}
	
	for my $network_name (@additional_network_names) {
		my $adapter_configuration = {
			network_name => $network_name,
			adapter_type => $vm_ethernet_adapter_type,
			address_type => 'Generated',
		};
		push @adapters, $adapter_configuration;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VM ethernet adapter configuration:\n" . format_data(\@adapters));
	return @adapters;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $host_vmdk_base_directory_path = $self->get_vmdk_base_directory_path() || return;
	my $host_vmdk_directory_path = $self->get_vmdk_directory_path() || return;
	my $host_vmdk_file_path = $self->get_vmdk_file_path() || return;
	my $host_vmdk_file_path_shared = $self->get_vmdk_file_path_shared() || return;
	my $host_vmdk_directory_path_shared = $self->get_vmdk_directory_path_shared() || return;
	
	my $request_state_name = $self->data->get_request_state_name(0) || 'unknown';
	my $image_name = $self->data->get_image_name() || return;
	my $vm_computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	
	my $is_vm_dedicated = $self->is_vm_dedicated();
	
	# Semaphores are created when exclusive access to a file/directory is needed to avoid conflicts
	# A semaphore ID is a string identifying a semaphore object when created
	# Only 1 process at a time may create a semaphore with a given ID - other processes must wait if they attempt to do so
	
	# Establish a semaphore for the shared vmdk directory before checking if it exists
	# This causes this process to wait if another process is copying to the shared directory
	# Wait a long time to create the semaphore in case another process is copying a large vmdk to the directory
	
	my $shared_vmdk_semaphore = $self->get_datastore_directory_semaphore($host_vmdk_directory_path_shared, (60 * 30)) || return;
	
	my $dedicated_vmdk_semaphore;
	if ($host_vmdk_directory_path_shared ne $host_vmdk_directory_path) {
		$dedicated_vmdk_semaphore = $self->get_datastore_directory_semaphore($host_vmdk_directory_path, (60 * 30)) || return;
	}
	
	# Return  if the VM is not dedicated and the shared vmdk already exists on the host
	my $shared_vmdk_exists = $self->vmhost_os->file_exists($host_vmdk_file_path_shared);
	if ($shared_vmdk_exists) {
		# Release the shared vmdk semaphore - image should be completely copied to correct location
		undef $shared_vmdk_semaphore;
		
		if (!$is_vm_dedicated) {
			notify($ERRORS{'DEBUG'}, 0, "VM is not dedicated and shared vmdk file already exists on VM host $vmhost_name: $host_vmdk_file_path");
			return 1;
		}
	}
	
	# VM is either:
	#    -dedicated
	#        -vmdk directory should be deleted if it already exists
	#        -vmdk directory should be created and vmdk files copied to it
	#    -shared and the directory doesn't exist
	#        -shared vmdk directory should be retrieved from the image repository
	
	
	# If the VM is dedicated, check if the dedicated vmdk already exists on the host, delete it if necessary
	if ($is_vm_dedicated) {
		if ($self->vmhost_os->file_exists($host_vmdk_directory_path)) {
			if ($request_state_name =~ /(new|reload)/) {
				notify($ERRORS{'WARNING'}, 0, "VM is dedicated and vmdk directory already exists on VM host $vmhost_name: $host_vmdk_directory_path, existing directory will be deleted");
				if (!$self->vmhost_os->delete_file($host_vmdk_directory_path)) {
					notify($ERRORS{'WARNING'}, 0, "failed to delete existing dedicated vmdk directory on VM host $vmhost_name: $host_vmdk_directory_path");
					return;
				}
			}
			else {
				# Don't delete the directory, it may be in use by a VM
				# Attempting to delete it will likely delete some files but not all, leaving a mess to reconstruct
				notify($ERRORS{'OK'}, 0, "VM is dedicated and vmdk directory already exists on VM host $vmhost_name: $host_vmdk_directory_path, request state is not new or reload, directory will not be deleted, returning true");
				return 1;
			}
		}
		
		# Attempt to copy files from the shared vmdk directory if it exists
		if ($shared_vmdk_exists) {
			notify($ERRORS{'DEBUG'}, 0, "VM is dedicated and shared vmdk exists on the VM host $vmhost_name, attempting to make a copy");
			if ($self->copy_vmdk($host_vmdk_file_path_shared, $host_vmdk_file_path)) {
				notify($ERRORS{'OK'}, 0, "copied vmdk from shared to dedicated directory on VM host $vmhost_name");
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk from shared to dedicated directory on VM host $vmhost_name");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "VM is dedicated, shared vmdk does not exist on the VM host $vmhost_name: $host_vmdk_file_path_shared");
		}
	}
	
	# Check if the image repository is mounted on the VM host
	# Copy vmdk files from repository datastore if it's mounted on the host
	# Attempt this before attempting to copy from the shared datastore to reduce load on shared datastore
	# Also - vmdk's are stored in 2gb sparse format in the repository. Copying from here may result in less space being used by the resulting copied vmdk.
	if ($self->is_repository_mounted_on_vmhost()) {
		notify($ERRORS{'DEBUG'}, 0, "files will be copied from this image repository directory mounted on the VM host");
		
		# Check if the vmdk file exists in the mounted repository
		my $repository_vmdk_file_path = $self->get_repository_vmdk_file_path();
		if ($self->vmhost_os->file_exists($repository_vmdk_file_path)) {
			# Attempt to copy the vmdk file from the mounted repository to the VM host datastore
			if ($self->copy_vmdk($repository_vmdk_file_path, $host_vmdk_file_path)) {
				notify($ERRORS{'OK'}, 0, "copied vmdk from image repository to VM host $vmhost_name");
				return 1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk from image repository to VM host $vmhost_name");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "vmdk file does not exist in image repository directory mounted on VM host $vmhost_name: $repository_vmdk_file_path");
		}
	}
	
	# Copy the vmdk files from the image repository on the management node to the vmdk directory
	my $repository_vmdk_directory_path = $self->get_repository_vmdk_directory_path() || return;
	my $start_time = time;
	
	# Find the vmdk file paths in the image repository directory
	my @vmdk_repository_file_paths;
	my $command = "find \"$repository_vmdk_directory_path\" -type f -iname \"$image_name*\"";
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
	
	# If SCP is used, the names of the vmdk files will be the image name
	if ("$host_vmdk_directory_path/$image_name.vmdk" ne $host_vmdk_file_path && !$self->move_vmdk("$host_vmdk_directory_path/$image_name.vmdk", $host_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to rename the vmdk that was copied via SCP to the VM host $vmhost_name: '$host_vmdk_directory_path/$image_name.vmdk' --> '$host_vmdk_file_path'");
		return;
	}
	
	# Check if the vmdk disk type is compatible with the VMware product installed on the host
	return 1 if $self->is_vmdk_compatible();
	
	# Disk type is not compatible with the VMware product installed on the host
	# Attempt to make a copy - copy_vmdk should create a copy in a compatible format
	# The destination copy is stored in a directory with the same name as the normal vmdk directory followed by a ~
	# Once the copy is done, delete the original vmdk directory and rename the copied directory
	my $vmdk_file_name = $self->get_vmdk_file_name();
	my $temp_vmdk_file_path = "$host_vmdk_directory_path~/$vmdk_file_name";
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy the vmdk using a compatible disk type on VM host $vmhost_name: '$host_vmdk_file_path' --> '$temp_vmdk_file_path'");
	
	if (!$self->copy_vmdk($host_vmdk_file_path, $temp_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy the vmdk using a compatible disk type on VM host $vmhost_name: '$host_vmdk_file_path' --> '$temp_vmdk_file_path'");
		return;
	}
	
	if (!$self->vmhost_os->delete_file($host_vmdk_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the directory containing the incompatible vmdk on VM host $vmhost_name: '$host_vmdk_directory_path'");
		return;
	}
	
	if (!$self->vmhost_os->move_file("$host_vmdk_directory_path~", $host_vmdk_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to rename the directory containing the compatible vmdk on VM host $vmhost_name: '$host_vmdk_directory_path~' --> '$host_vmdk_directory_path'");
		return;
	}
	
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 is_vmx_vmdk_volume_shared

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub is_vmx_vmdk_volume_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{vmx_vmdk_volume_shared} if defined($self->{vmx_vmdk_volume_shared});
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	
	# Check if the vmx and vmdk base directory paths are identical
	if ($vmx_base_directory_path eq $vmdk_base_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "vmx and vmdk base directory paths are identical: '$vmx_base_directory_path', they are on the same volume");
		$self->{vmx_vmdk_volume_shared} = 1;
		return $self->{vmx_vmdk_volume_shared};
	}
	
	my $vmx_volume_total_space = $self->get_vmx_volume_total_space();
	my $vmdk_volume_total_space = $self->get_vmdk_volume_total_space();
	my $vmx_volume_available_space = $self->vmhost_os->get_available_space($vmx_base_directory_path);
	my $vmdk_volume_available_space = $self->vmhost_os->get_available_space($vmdk_base_directory_path);
	unless (defined($vmx_volume_total_space) && defined($vmdk_volume_total_space) && defined($vmx_volume_available_space) && defined($vmdk_volume_available_space)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if vmx and vmdk base directory paths are on the same volume, vmx and vmdk total and available space could not be determined");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "checking if vmx and vmdk base directory paths appear to be on the same volume:\n" .
		"vmx base directory path: '$vmx_base_directory_path'\n" .
		"vmdk base directory path: '$vmdk_base_directory_path'\n" .
		"vmx volume total space: " . get_file_size_info_string($vmx_volume_total_space) . "\n" .
		"vmdk volume total space: " . get_file_size_info_string($vmdk_volume_total_space) . "\n" .
		"vmx volume available space: " . get_file_size_info_string($vmx_volume_available_space) . "\n" .
		"vmdk volume available space: " . get_file_size_info_string($vmdk_volume_available_space)
	);
	
	if ($vmx_base_directory_path eq $vmdk_base_directory_path || ($vmx_volume_total_space == $vmdk_volume_total_space && abs($vmx_volume_available_space - $vmdk_volume_available_space) < ($vmdk_volume_total_space * .01))) {
		notify($ERRORS{'DEBUG'}, 0, "vmx and vmdk base directory paths appear to be on the same volume based on the total and available space");
		$self->{vmx_vmdk_volume_shared} = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmx and vmdk base directory paths do not appear to be on the same volume based on the total and available space");
		$self->{vmx_vmdk_volume_shared} = 0;
	}
	
	return $self->{vmx_vmdk_volume_shared};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_volume_total_space

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_vmx_volume_total_space {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{vmx_total_space} if defined($self->{vmx_total_space});
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	$self->{vmx_total_space} = $self->vmhost_os->get_total_space($vmx_base_directory_path);
	return $self->{vmx_total_space};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_volume_total_space

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_vmdk_volume_total_space {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{vmdk_total_space} if defined($self->{vmdk_total_space});
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	$self->{vmdk_total_space} = $self->vmhost_os->get_total_space($vmdk_base_directory_path);
	return $self->{vmdk_total_space};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_vmhost_disk_space

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub check_vmhost_disk_space {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	notify($ERRORS{'DEBUG'}, 0, "checking if enough space is available on VM host $vmhost_name");
	
	my $shared_vmx_vmdk_volume = $self->is_vmx_vmdk_volume_shared();
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	
	my $vmx_volume_available_space = $self->vmhost_os->get_available_space($vmx_base_directory_path);
	if (!defined($vmx_volume_available_space)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine available space for the vmx directory on VM host $vmhost_name");
		return;
	}
	
	# Figure out how much additional space is required for the vmx and vmdk directories
	my $vmx_additional_bytes_required = $self->get_vm_additional_vmx_bytes_required();
	my $vmdk_additional_bytes_required = $self->get_vm_additional_vmdk_bytes_required();
	if (!defined($vmx_additional_bytes_required) || !defined($vmdk_additional_bytes_required)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine additional bytes required for the vmx and vmdk directories on VM host $vmhost_name");
		return;
	}
	
	my $space_message;
	
	if ($shared_vmx_vmdk_volume) {
		my $additional_bytes_required = ($vmx_additional_bytes_required + $vmdk_additional_bytes_required);
		
		my $space_message;
		$space_message .= "vmx additional space required:          " . get_file_size_info_string($vmx_additional_bytes_required) . "\n";
		$space_message .= "vmdk additional space required:         " . get_file_size_info_string($vmdk_additional_bytes_required) . "\n";
		$space_message .= "total additional space required:        " . get_file_size_info_string($additional_bytes_required) . "\n";
		$space_message .= "shared vmx/vmdk volume available space: " . get_file_size_info_string($vmx_volume_available_space);
		
		if ($additional_bytes_required <= $vmx_volume_available_space) {
			notify($ERRORS{'DEBUG'}, 0, "enough space is available on shared vmx/vmdk volume on VM host $vmhost_name: '$vmx_base_directory_path'\n$space_message");
			return 1;
		}
		else {
			my $deficit_space = ($additional_bytes_required - $vmx_volume_available_space);
			$space_message .= "\nshared vmx/vmdk volume space deficit:   " . get_file_size_info_string($deficit_space);
			notify($ERRORS{'DEBUG'}, 0, "not enough space is available on shared vmx/vmdk volume on VM host $vmhost_name: '$vmx_base_directory_path'\n$space_message");
			return 0;
		}
	}
	else {
		my $vmdk_volume_available_space = $self->vmhost_os->get_available_space($vmdk_base_directory_path);
		if (!defined($vmdk_volume_available_space)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine available space for the vmdk directory on VM host $vmhost_name");
			return;
		}
		
		$space_message .= "vmx additional space required:          " . get_file_size_info_string($vmx_additional_bytes_required) . "\n";
		$space_message .= "vmx volume available space:             " . get_file_size_info_string($vmx_volume_available_space) . "\n";
		$space_message .= "vmdk additional space required:         " . get_file_size_info_string($vmdk_additional_bytes_required) . "\n";
		$space_message .= "vmdk volume available space:            " . get_file_size_info_string($vmdk_volume_available_space);
		
		if ($vmx_additional_bytes_required <= $vmx_volume_available_space && $vmdk_additional_bytes_required <= $vmdk_volume_available_space) {
			notify($ERRORS{'DEBUG'}, 0, "enough space is available on vmx and vmdk volumes on VM host $vmhost_name:\n$space_message");
			return 1;
		}
		
		if ($vmdk_additional_bytes_required <= $vmdk_volume_available_space) {
			$space_message = "enough space is available on vmdk volume on VM host $vmhost_name:\n$space_message";
		}
		else {
			my $vmdk_deficit_space = ($vmdk_additional_bytes_required - $vmdk_volume_available_space);
			$space_message .= "\nvmdk volume space deficit:              " . get_file_size_info_string($vmdk_deficit_space);
			$space_message = "not enough space is available on vmdk volume on VM host $vmhost_name:\n$space_message";
		}
		
		if ($vmx_additional_bytes_required <= $vmx_volume_available_space) {
			$space_message = "enough space is available on vmx volume on VM host $vmhost_name:\n$space_message";
		}
		else {
			my $vmx_deficit_space = ($vmx_additional_bytes_required - $vmx_volume_available_space);
			$space_message .= "\nvmx volume space deficit:               " . get_file_size_info_string($vmx_deficit_space);
			$space_message = "not enough space is available on vmx volume on VM host $vmhost_name:\n$space_message";
		}
		
		notify($ERRORS{'DEBUG'}, 0, "$space_message");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reclaim_vmhost_disk_space

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub reclaim_vmhost_disk_space {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_id = $self->data->get_request_id();
	my $reservation_computer_id = $self->data->get_computer_id();
	my $vmhost_profile_vmdisk = $self->data->get_vmhost_profile_vmdisk();
	
	my $is_vm_dedicated = $self->is_vm_dedicated();
	my $reservation_vmdk_directory_path = $self->get_vmdk_directory_path();
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path();
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path();
	
	# Figure out how much additional space is required for the vmx and vmdk directories
	my $vmx_additional_bytes_required = $self->get_vm_additional_vmx_bytes_required();
	my $vmdk_additional_bytes_required = $self->get_vm_additional_vmdk_bytes_required();
	if (!defined($vmx_additional_bytes_required) || !defined($vmdk_additional_bytes_required)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the additional bytes required for the vmx and vmdk directories");
		return;
	}
	
	my $shared_vmx_vmdk_volume = $self->is_vmx_vmdk_volume_shared();

	my $vmx_files = {};
	my $deletable_vmx_files = {};
	my $vmdk_directories = {};
	my $deletable_vmdk_directories = {};
	
	my $total_deletable_vmx_size = 0;
	my $total_deletable_vmdk_size = 0;
	
	# Retrieve a list of existing vmdk directories matching the VCL naming convention
	my @vmdk_base_directory_contents = $self->get_datastore_imagerevision_names($vmdk_base_directory_path);
	for my $vmdk_directory_name (@vmdk_base_directory_contents) {
		$vmdk_directories->{"$vmdk_base_directory_path/$vmdk_directory_name"} = {}
	}
	
	my $vmdk_directory_count = scalar(keys %$vmdk_directories);
	notify($ERRORS{'DEBUG'}, 0, "retrieved list of existing vmdk directories under '$vmdk_base_directory_path' ($vmdk_directory_count):\n" . join("\n", sort keys %$vmdk_directories));
	
	# Find VMs that can can be deleted
	my @vmx_file_paths = $self->get_vmx_file_paths();
	for my $vmx_file_path (@vmx_file_paths) {
		$vmx_files->{$vmx_file_path} = {};
		
		my $vmx_info = $self->get_vmx_info($vmx_file_path);
		if (!$vmx_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve info from vmx file: $vmx_file_path");
			next;
		}
		
		# Retrieve the vmx_file_name value from the vmx info - this should exist if VCL created the vmx file
		my $vmx_file_name = $vmx_info->{vmx_file_name};
		if (!$vmx_file_name) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because the vmx file does not contain a vmx_file_name value");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		$vmx_files->{$vmx_file_path}{file_name} = $vmx_file_name;
		
		# Retrieve the vmx_directory_path value from the vmx info - this should exist if VCL created the vmx file
		my $vmx_directory_path = $vmx_info->{vmx_directory_path};
		if (!$vmx_directory_path) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because the vmx file does not contain a vmx_directory_path value");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		
		# Retrieve the computer_id value from the vmx info - this should exist if VCL created the vmx file
		my $check_computer_id = $vmx_info->{computer_id};
		if (!defined($check_computer_id)) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted, vmx file does not contain a computer_id value and ID could not be determined from the directory name");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		
		# Check if the vmx file was created for the same computer assigned to this reservation
		# If true, delete the VM and remove it from the $vmx_files hash
		if ($check_computer_id eq $reservation_computer_id) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to delete VM $vmx_file_path because vmx file contains the computer ID assigned to this reservation");
			if ($self->delete_vm($vmx_file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "deleted VM containing the computer ID assigned to this reservation: $vmx_file_path");
				delete $vmx_files->{$vmx_file_path};
				next;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to delete VM containing the computer ID assigned to this reservation: $vmx_file_path");
				return;
			}
		}
		
		# Retrieve the vmdk directory paths from the vmx info and add them to the $vmdk_directories hash
		for my $storage_identifier (keys %{$vmx_info->{vmdk}}) {
			my $vmdk_file_path = $vmx_info->{vmdk}{$storage_identifier}{vmdk_file_path};
			
			if ($self->is_vmdk_file_shared($vmdk_file_path)) {
				$vmx_files->{$vmx_file_path}{vmdk_shared} = 1;
			}
			else {
				$vmx_files->{$vmx_file_path}{vmdk_shared} = 0;
			}
		}
		
		# Create a DataStructure object for the computer
		my $check_computer_data;
		eval { $check_computer_data = new VCL::DataStructure({computer_identifier => $check_computer_id}); };
		if (!$check_computer_data) {
			notify($ERRORS{'WARNING'}, 0, "$vmx_file_name can't be deleted, failed to create a DataStructure object for computer $check_computer_id");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		
		# Retrieve the computer name from the DataStructure object
		my $check_computer_name = $check_computer_data->get_computer_short_name();
		if (!$check_computer_name) {
			notify($ERRORS{'WARNING'}, 0, "$vmx_file_name can't be deleted, failed to retrieve the computer name from the DataStructure object");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "name of computer ID $check_computer_id: $check_computer_name");
		}
		
		# Check the computer state
		# Don't remove computers in the maintenance state
		my $check_computer_state = $check_computer_data->get_computer_state_name();
		if (!$check_computer_state) {
			notify($ERRORS{'WARNING'}, 0, "$vmx_file_name can't be deleted, failed to retrieve the computer state from the DataStructure object");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		$vmx_files->{$vmx_file_path}{computer_state} = $check_computer_state;
		if ($check_computer_state =~ /maintenance/i) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because its current state is '$check_computer_state'");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "state of $check_computer_name: $check_computer_state");
		}
		
		
		# Check if the computer has been assigned to a block allocation
		if (is_inblockrequest($check_computer_id)) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because it has been assigned to a block allocation");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			$vmx_files->{$vmx_file_path}{block_allocation} = 1;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$check_computer_name has not been assigned to a block allocation");
			$vmx_files->{$vmx_file_path}{block_allocation} = 0;
		}
		
		
		# Check if any other requests have been assigned to the computer
		my $computer_requests = get_request_by_computerid($check_computer_id);
		
		# Remove the ID for the current request
		delete $computer_requests->{$request_id};
		if (keys(%$computer_requests)) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because it is assigned to another request: " . join(", ", sort keys(%$computer_requests)));
			$vmx_files->{$vmx_file_path}{requests} = [sort keys(%$computer_requests)];
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$check_computer_name has not been assigned to any other requests");
			$vmx_files->{$vmx_file_path}{requests} = [];
		}
		
		# Get the amount of space being used by the vmx directory
		my $vmx_directory_size = $self->vmhost_os->get_file_size($vmx_directory_path);
		if (!defined($vmx_directory_size)) {
			notify($ERRORS{'WARNING'}, 0, "$vmx_file_name can't be deleted because the size of the vmx directory could not be determined: '$vmx_directory_path'");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieved size of vmx directory '$vmx_directory_path': " . format_number($vmx_directory_size, 0) . " bytes");
			$vmx_files->{$vmx_file_path}{vmx_directory_size} = $vmx_directory_size;
		}
		
		# Check if the VM is registered
		my $registered = $self->is_vm_registered($vmx_file_path);
		if (!defined($registered)) {
			notify($ERRORS{'DEBUG'}, 0, "$vmx_file_name can't be deleted because failed to determine if the VM is registered");
			$vmx_files->{$vmx_file_path}{deletable} = 0;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieved registered status of $vmx_file_name: $registered");
			$vmx_files->{$vmx_file_path}{registered} = $registered;
			
			if ($registered) {
				# Get the power status of the VM
				my $power_status = $self->power_status($vmx_file_path);
				if (!defined($power_status)) {
					notify($ERRORS{'WARNING'}, 0, "$vmx_file_name can't be deleted because the power status of the VM could not be determined");
					$vmx_files->{$vmx_file_path}{deletable} = 0;
					next;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "retrieved power status of $vmx_file_name: $power_status");
					$vmx_files->{$vmx_file_path}{power_status} = $power_status;
				}
			}
		}
		
		$vmx_files->{$vmx_file_path}{deletable} = 1;
		$deletable_vmx_files->{$vmx_file_path} = $vmx_files->{$vmx_file_path};
		$total_deletable_vmx_size += $vmx_directory_size;
		notify($ERRORS{'DEBUG'}, 0, "VM $vmx_file_name can be deleted");
	}
	
	if ($vmhost_profile_vmdisk !~ /(local|dedicated)/) {
		notify($ERRORS{'OK'}, 0, "VM disk mode is '$vmhost_profile_vmdisk', no image directories will be deleted from $vmdk_base_directory_path");
	}
	elsif (!$self->get_repository_vmdk_base_directory_path()) {
		notify($ERRORS{'OK'}, 0, "VM disk mode is '$vmhost_profile_vmdisk' but repository path is NOT configured, no image directories will be deleted from $vmdk_base_directory_path");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "VM disk mode is '$vmhost_profile_vmdisk' and repository path is configured, checking if any image directories can be deleted from $vmdk_base_directory_path");
		for my $vmdk_directory_path (sort keys %$vmdk_directories) {
			$vmdk_directories->{$vmdk_directory_path}{deletable} = 1;
			for my $vmx_file_path (keys %{$vmdk_directories->{$vmdk_directory_path}{vmx_file_paths}}) {
				$vmdk_directories->{$vmdk_directory_path}{deletable} &= $vmx_files->{$vmx_file_path}{deletable};
			}
			
			my $vmx_file_path_count = scalar(keys %{$vmdk_directories->{$vmdk_directory_path}{vmx_file_paths}});
			$vmdk_directories->{$vmdk_directory_path}{vmx_file_path_count} = $vmx_file_path_count;
			
			# Retrieve additional information if the vmdk is deletable
			if ($vmdk_directories->{$vmdk_directory_path}{deletable}) {
				# Check if the vmdk directory matches the vmdk directory that will be used for this reservation
				# Don't delete this directory because it will just have to be copied back
				if (!$is_vm_dedicated && $vmdk_directory_path eq $reservation_vmdk_directory_path) {
					notify($ERRORS{'DEBUG'}, 0, "vmdk directory can't be deleted because it will be used for this reservation: $vmdk_directory_path");
					$vmdk_directories->{$vmdk_directory_path}{deletable} = 0;
					next;
				}
			
				# Get the vmdk directory name so that the image info for that directory can be retrieved
				# _get_file_name returns the last part of a file path
				my $vmdk_directory_name = $self->_get_file_name($vmdk_directory_path);
				$vmdk_directories->{$vmdk_directory_path}{directory_name} = $vmdk_directory_name;
				
				my $imagerevision_info = get_imagerevision_info($vmdk_directory_name);
				if (!$imagerevision_info) {
					notify($ERRORS{'WARNING'}, 0, "failed to retrieve info for the image revision matching the vmdk directory name: '$vmdk_directory_name'");
					$vmdk_directories->{$vmdk_directory_path}{deletable} = 0;
					next;
				}
				else {
					#notify($ERRORS{'DEBUG'}, 0, "retrieved info for the image revision matching the vmdk directory name: '$vmdk_directory_name'\n" . format_data(\%imagerevision_info));
					
					$vmdk_directories->{$vmdk_directory_path}{image_id} = $imagerevision_info->{imageid};
					$vmdk_directories->{$vmdk_directory_path}{imagerevision_id} = $imagerevision_info->{id};
					$vmdk_directories->{$vmdk_directory_path}{image_deleted} = $imagerevision_info->{deleted};
					$vmdk_directories->{$vmdk_directory_path}{imagerevision_production} = $imagerevision_info->{production};
					
					my $image_info = get_image_info($imagerevision_info->{imageid});
					if (!$image_info) {
						notify($ERRORS{'WARNING'}, 0, "failed to retrieve info for the image ID contained in the image revision info: $imagerevision_info->{imageid}");
					}
					else {
						#notify($ERRORS{'DEBUG'}, 0, "retrieved info for the image ID contained in the image revision info: $imagerevision_info->{imageid}\n" . format_data($image_info));
						# Use the 'or' operator to set the 'deleted' key so this value is set to 1 if either the image revision or image has deleted=1
						$vmdk_directories->{$vmdk_directory_path}{image_deleted} |= $image_info->{deleted};
					}
				}
				
				my $vmdk_directory_size = $self->vmhost_os->get_file_size($vmdk_directory_path);
				if (!defined($vmdk_directory_size)) {
					notify($ERRORS{'WARNING'}, 0, "$vmdk_directory_path can't be deleted because the size of the directory could not be determined");
					$vmdk_directories->{$vmdk_directory_path}{deletable} = 0;
					next;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "retrieved size of vmdk directory '$vmdk_directory_path': " . format_number($vmdk_directory_size, 0) . " bytes");
					$vmdk_directories->{$vmdk_directory_path}{vmdk_directory_size} = $vmdk_directory_size;
				}
				
				$deletable_vmdk_directories->{$vmdk_directory_path} = $vmdk_directories->{$vmdk_directory_path};
				$total_deletable_vmdk_size += $vmdk_directory_size;
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "all VMs:\n" . format_data($vmx_files));
	notify($ERRORS{'DEBUG'}, 0, "all vmdk directories:\n" . format_data($vmdk_directories));

	notify($ERRORS{'DEBUG'}, 0, "deletable VMs:\n" . format_data($deletable_vmx_files));
	notify($ERRORS{'DEBUG'}, 0, "deletable vmdk directories:\n" . format_data($deletable_vmdk_directories));
	
	if ($shared_vmx_vmdk_volume) {
		my $additional_space_required = ($vmx_additional_bytes_required + $vmdk_additional_bytes_required);
		
		my $available_space = $self->vmhost_os->get_available_space($vmx_base_directory_path);
		my $deletable_space = ($total_deletable_vmx_size + $total_deletable_vmdk_size);
		my $potential_available_space = ($available_space + $deletable_space);
		
		if ($available_space >= $additional_space_required) {
			notify($ERRORS{'DEBUG'}, 0, "enough space is already available to accomodate the VM:\n" .
				"currently available space: " . get_file_size_info_string($available_space) . "\n" .
				"space required for the VM: " . get_file_size_info_string($additional_space_required)
			);
			return 1;
		}
		elsif ($potential_available_space < $additional_space_required) {
			notify($ERRORS{'WARNING'}, 0, "not enough space can be reclaimed to accomodate the VM:\n" .
				"deletable space: " . get_file_size_info_string($deletable_space) . "\n" .
				"currently available space: " . get_file_size_info_string($available_space) . "\n" .
				"potential available space: " . get_file_size_info_string($potential_available_space) . "\n" .
				"space required for the VM: " . get_file_size_info_string($additional_space_required)
			);
			return 0;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "enough space can be reclaimed to accomodate the VM:\n" .
				"deletable space: " . get_file_size_info_string($deletable_space) . "\n" .
				"currently available space: " . get_file_size_info_string($available_space) . "\n" .
				"potential available space: " . get_file_size_info_string($potential_available_space) . "\n" .
				"space required for the VM: " . get_file_size_info_string($additional_space_required)
			);
		}
	}
	else {
		my $vmx_available_space = $self->vmhost_os->get_available_space($vmx_base_directory_path);
		my $vmdk_available_space = $self->vmhost_os->get_available_space($vmdk_base_directory_path);
		
		my $vmx_potential_available_space = ($vmx_available_space + $total_deletable_vmx_size);
		my $vmdk_potential_available_space = ($vmdk_available_space + $total_deletable_vmdk_size);
		
		if ($vmx_available_space >= $vmx_additional_bytes_required && $vmdk_available_space >= $vmdk_additional_bytes_required) {
			notify($ERRORS{'DEBUG'}, 0, "enough space is already available to accomodate the VM:\n" .
				"space required for the vmx directory: " . get_file_size_info_string($vmx_additional_bytes_required) . "\n" .
				"vmx volume available space: " . get_file_size_info_string($vmx_available_space) . "\n" .
				"space required for the vmdk directory: " . get_file_size_info_string($vmdk_additional_bytes_required) . "\n" .
				"vmdk volume available space: " . get_file_size_info_string($vmdk_available_space)
			);
			return 1;
		}
		
		my $deficit = 0;
		if ($vmx_potential_available_space < $vmx_additional_bytes_required) {
			notify($ERRORS{'WARNING'}, 0, "not enough space can be reclaimed to accomodate the vmx directory:\n" .
				"space required for the vmx directory: " . get_file_size_info_string($vmx_additional_bytes_required) . "\n" .
				"vmx volume available space: " . get_file_size_info_string($vmx_available_space) . "\n" .
				"vmx volume deletable space: " . get_file_size_info_string($total_deletable_vmx_size) . "\n" .
				"vmx volume potentially available space: " . get_file_size_info_string($vmx_potential_available_space)
			);
			
			$deficit = 1;
		}
		if ($vmdk_potential_available_space < $vmdk_additional_bytes_required) {
			notify($ERRORS{'WARNING'}, 0, "not enough space can be reclaimed to accomodate the vmdk directory:\n" .
				"space required for the vmdk directory: " . get_file_size_info_string($vmdk_additional_bytes_required) . "\n" .
				"vmdk volume available space: " . get_file_size_info_string($vmdk_available_space) . "\n" .
				"vmdk volume deletable space: " . get_file_size_info_string($total_deletable_vmdk_size) . "\n" .
				"vmdk volume potentially available space: " . get_file_size_info_string($vmdk_potential_available_space)
			);
			$deficit = 1;
		}
		return 0 if $deficit;
		
		notify($ERRORS{'DEBUG'}, 0, "enough space can be reclaimed to accomodate the VM:\n" .
			"space required for the vmx directory: " . get_file_size_info_string($vmx_additional_bytes_required) . "\n" .
			"vmx volume available space: " . get_file_size_info_string($vmx_available_space) . "\n" .
			"vmx volume deletable space: " . get_file_size_info_string($total_deletable_vmx_size) . "\n" .
			"vmx volume potentially available space: " . get_file_size_info_string($vmx_potential_available_space) . "\n" .
			"---\n" .
			"space required for the vmdk directory: " . get_file_size_info_string($vmdk_additional_bytes_required) . "\n" .
			"vmdk volume available space: " . get_file_size_info_string($vmdk_available_space) . "\n" .
			"vmdk volume deletable space: " . get_file_size_info_string($total_deletable_vmdk_size) . "\n" .
			"vmdk volume potentially available space: " . get_file_size_info_string($vmdk_potential_available_space)
		);
	}

	my @delete_stage_order = (
		['vmdk', 'image_deleted', '1'],
		['vmx', 'registered', '0'],
		['vmx', 'power_status', 'off'],
		['vmx', 'vmdk_shared', '0'],
		['vmdk', 'vmx_file_path_count', '0'],
		['vmdk', 'imagerevision_production', '0'],
		['vmx', 'deletable', '1'],
		['vmdk', 'deletable', '1'],
	);
	
	my $enough_space_reclaimed = 0;
	
	notify($ERRORS{'DEBUG'}, 0, "deletable vmx files:\n" . format_data($deletable_vmx_files));
	notify($ERRORS{'DEBUG'}, 0, "deletable vmdk directories:\n" . format_data($deletable_vmdk_directories));
	
	DELETE_STAGE: for my $delete_stage (@delete_stage_order) {
		my ($vmx_vmdk, $key, $value) = @$delete_stage;
		notify($ERRORS{'DEBUG'}, 0, "processing delete stage - $vmx_vmdk: $key = $value");
		
		if ($vmx_vmdk eq 'vmx') {
			for my $deletable_vmx_file_path (sort keys %$deletable_vmx_files) {
				my $deletable_vmx_file_name = $deletable_vmx_files->{$deletable_vmx_file_path}{file_name};
				my $deletable_vmx_file_value = $deletable_vmx_files->{$deletable_vmx_file_path}{$key};
				
				if (!defined($deletable_vmx_file_value)) {
					notify($ERRORS{'DEBUG'}, 0, "no value: $key is not set for vmx file $deletable_vmx_file_name");
					next;
				}
				elsif ($deletable_vmx_file_value ne $value) {
					notify($ERRORS{'DEBUG'}, 0, "no match: vmx file $deletable_vmx_file_name does not match delete stage criteria: $key = $value, vmx value: $deletable_vmx_file_value");
					next;
				}
				
				notify($ERRORS{'DEBUG'}, 0, "match: vmx file $deletable_vmx_file_name matches delete stage criteria: $key = $value, vmx value: $deletable_vmx_file_value");
				
				if ($self->delete_vm($deletable_vmx_file_path)) {
					notify($ERRORS{'DEBUG'}, 0, "reclaimed space used by VM: $deletable_vmx_file_path");
					
					for my $vmdk_directory_path (sort keys %{$deletable_vmx_files->{$deletable_vmx_file_path}{vmdk_directory_paths}}) {
						notify($ERRORS{'DEBUG'}, 0, "deleting $deletable_vmx_file_name from vmdk info: $vmdk_directory_path\n" . format_data($deletable_vmdk_directories->{$vmdk_directory_path}));
						delete $deletable_vmdk_directories->{$vmdk_directory_path}{vmx_file_paths}{$deletable_vmx_file_path};
						
						my $vmx_file_path_count = scalar(keys %{$deletable_vmdk_directories->{$vmdk_directory_path}{vmx_file_paths}});
						$deletable_vmdk_directories->{$vmdk_directory_path}{vmx_file_path_count} = $vmx_file_path_count;
						
						notify($ERRORS{'DEBUG'}, 0, "after:\n" . format_data($deletable_vmdk_directories->{$vmdk_directory_path}));
					}
					delete $deletable_vmx_files->{$deletable_vmx_file_path};
					
					$enough_space_reclaimed = $self->check_vmhost_disk_space();
					last DELETE_STAGE if $enough_space_reclaimed;
				}
			}
		}
		
		elsif ($vmx_vmdk eq 'vmdk') {
			DELETABLE_VMDK: for my $deletable_vmdk_directory_path (sort keys %$deletable_vmdk_directories) {
				my $deletable_vmdk_directory_name = $deletable_vmdk_directories->{$deletable_vmdk_directory_path}{directory_name};
				my $deletable_vmdk_directory_value = $deletable_vmdk_directories->{$deletable_vmdk_directory_path}{$key};
				
				if (!defined($deletable_vmdk_directory_name)) {
					notify($ERRORS{'WARNING'}, 0, "vmdk directory name is not set the hash for deletable vmdk directory path: '$deletable_vmdk_directory_path'\n" . format_data($deletable_vmdk_directories->{$deletable_vmdk_directory_path}));
					next;
				}
				elsif (!defined($deletable_vmdk_directory_value)) {
					notify($ERRORS{'DEBUG'}, 0, "no value: $key is not set for vmdk file $deletable_vmdk_directory_name");
					next;
				}
				elsif ($deletable_vmdk_directory_value ne $value) {
					notify($ERRORS{'DEBUG'}, 0, "no match: vmdk directory: $deletable_vmdk_directory_name\ndelete stage criteria: $key = $value\nvmdk value: $key = $deletable_vmdk_directory_value");
					next;
				}
				notify($ERRORS{'DEBUG'}, 0, "match: vmdk directory: $deletable_vmdk_directory_name\ndelete stage criteria: $key = $value\nvmdk value: $key = $deletable_vmdk_directory_value");
				for my $vmx_file_path (sort keys %{$deletable_vmdk_directories->{$deletable_vmdk_directory_path}{vmx_file_paths}}) {
					if ($self->delete_vm($vmx_file_path)) {
						notify($ERRORS{'DEBUG'}, 0, "reclaimed space used by VM: $vmx_file_path");
						delete $deletable_vmx_files->{$vmx_file_path};
						delete $deletable_vmdk_directories->{$deletable_vmdk_directory_path}{vmx_file_paths}{$vmx_file_path};
					}
					else {
						next DELETABLE_VMDK;
					}
				}
				
				if ($self->vmhost_os->delete_file($deletable_vmdk_directory_path)) {
					notify($ERRORS{'DEBUG'}, 0, "reclaimed space used by vmdk directory: $deletable_vmdk_directory_path");
					delete $deletable_vmdk_directories->{$deletable_vmdk_directory_path};
				}
				$enough_space_reclaimed = $self->check_vmhost_disk_space();
				last DELETE_STAGE if $enough_space_reclaimed;
			}
		}
	}
	
	if ($enough_space_reclaimed) {
		notify($ERRORS{'OK'}, 0, "reclaimed enough space to load the VM");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reclaim enough space to load the VM");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_vmdk_compatible

 Parameters  : none
 Returns     : boolean
 Description : Determines if the vmdk disk type is compatible with the VMware
               product being used on the VM host. This subroutine currently only
               checks if ESX is being used and the vmdk disk type is flat.
               Returns false if:
               -VM host is using ESX
               -vmdk disk type is not flat

=cut

sub is_vmdk_compatible {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_file_path = $self->get_vmdk_file_path() || return;
	
	# Retrieve the VMware product name
	my $vmware_product_name = $self->get_vmhost_product_name();
	if (!$vmware_product_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if vmdk is compatible with VM host, VMware product name could not be retrieved");
		return;
	}
	
	# Retrieve the virtual disk type from the API object
	my $virtual_disk_type = $self->api->get_virtual_disk_type($vmdk_file_path);
	if (!$virtual_disk_type) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if vmdk is compatible with VM host, vmdk disk type could not be retrieved");
		return;
	}
	
	if ($vmware_product_name =~ /esx/i && $virtual_disk_type !~ /flat/i) {
		notify($ERRORS{'DEBUG'}, 0, "virtual disk type is not compatible with $vmware_product_name: $virtual_disk_type");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "virtual disk type is compatible with $vmware_product_name: $virtual_disk_type");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $reservation_id = $self->data->get_reservation_id();
	
	return $self->{vmx_file_path} if $self->{vmx_file_path};
	
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
	
	my $vmx_file_path = "$vmx_base_directory_path/$vmx_directory_name/$vmx_directory_name.vmx";
	$self->{vmx_file_path} = $vmx_file_path;
	notify($ERRORS{'OK'}, 0, "determined vmx file path: $vmx_file_path");
	return $vmx_file_path;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $vmhost_short_name = $self->data->get_vmhost_short_name();
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	if ($self->{vmx_file_path}) {
		($vmx_base_directory_path) = $self->{vmx_file_path} =~ /(.+)\/[^\/]+\/[^\/]+.vmx$/i;
		if ($vmx_base_directory_path) {
			return $vmx_base_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmx base directory path could not be determined from vmx file path: '$self->{vmx_file_path}'");
			return;
		}
	}

	# Get the vmprofile.vmpath
	# If this is not set, use vmprofile.datastorepath
	$vmx_base_directory_path = $self->data->get_vmhost_profile_vmpath() || $self->data->get_vmhost_profile_datastore_path();
	if (!$vmx_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmx base directory path, failed to retrieve either the VM path or datastore path for the VM profile");
		return;
	}
	
	# Convert the path to a normal path
	# The path configured in the VM profile may be:
	# -normal absolute path: /vmfs/volumes/vcl-datastore
	# -datastore path: [vcl-datastore]
	# -datastore name: vcl-datastore
	my $vmx_base_directory_normal_path = $self->_get_normal_path($vmx_base_directory_path);
	if (!$vmx_base_directory_normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmx base directory path, failed to convert path configured in the VM profile to a normal path: $vmx_base_directory_path");
		return;
	}
	
	# Check if a directory exists under the vmx base directory named after the VM host
	# If one exists, use it instead of the directory configured in the VM profile
	if ($self->vmhost_os->file_exists("$vmx_base_directory_normal_path/$vmhost_hostname", 'd')) {
		$vmx_base_directory_normal_path = "$vmx_base_directory_normal_path/$vmhost_hostname";
		notify($ERRORS{'DEBUG'}, 0, "directory named after the VM host under vmx base directory path will be used: $vmx_base_directory_normal_path");
	}
	else {
		if ($vmhost_hostname ne $vmhost_short_name) {
			if ($self->vmhost_os->file_exists("$vmx_base_directory_normal_path/$vmhost_short_name", 'd')) {
				$vmx_base_directory_normal_path = "$vmx_base_directory_normal_path/$vmhost_short_name";
				notify($ERRORS{'DEBUG'}, 0, "directory named after the VM host under vmx base directory path will be used: $vmx_base_directory_normal_path");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "directory named '$vmhost_hostname' or '$vmhost_short_name' does not exist under the vmx base directory path: $vmx_base_directory_normal_path");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "directory named '$vmhost_hostname' does not exist under the vmx base directory path: $vmx_base_directory_normal_path");
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "determined vmx base directory path: $vmx_base_directory_normal_path");
	return $vmx_base_directory_normal_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_url_base_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the path on the VM host under which the vmx directory is
               located.
               Example:
               /vmfs/volumes/local-datastore

=cut

sub get_vmx_url_base_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $base_directory_path = $self->get_vmx_base_directory_path();
	if (!$base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx URL base directory path, failed to retrieve vmx base directory path");
		return;
	}
	
	my $datastore_root_url = $self->_get_datastore_url($base_directory_path);
	if (!$datastore_root_url) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx URL base directory path, failed to retrieve URL for base directory path: '$base_directory_path'");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($base_directory_path);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx URL base directory path, failed to retrieve datastore name for base directory path: '$base_directory_path'");
		return;
	}
	
	# Replace the datastore name with the URL
	my $url_base_directory_path = $base_directory_path;
	$url_base_directory_path =~ s/\/$datastore_name(\/|$)/\/$datastore_root_url$1/;
	
	notify($ERRORS{'DEBUG'}, 0, "determined vmx URL base directory path:\n" .
		"vmx base directory path: $base_directory_path\n" .
		"vmx url base directory path: $url_base_directory_path"
	);
	return $url_base_directory_path
	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_intermediate_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the path on the VM host under which all of the VM vmx
               directories reside, with the datastore section removed. This will
               return an empty string if the vmx base directory path is the root
               of a datastore. Example:
               
               get_vmx_base_directory_path:
                  '/vmfs/volumes/datastore1/VMs/vmhost2'
               get_vmx_intermediate_directory_path:
                  'VMs/vmhost2'
                  
               get_vmx_base_directory_path:
                  '/vmfs/volumes/datastore1'
               get_vmx_intermediate_directory_path:
                  ''

=cut

sub get_vmx_intermediate_directory_path {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_directory_path = $self->get_vmx_directory_path();
	if (!$vmx_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmx intermediate directory path, failed to retrieve vmx directory path");
		return;
	}
	
	my $intermediate_directory_path = $vmx_directory_path;
	$intermediate_directory_path =~ s/^\/vmfs\/volumes\/[^\/]+\/?//ig;
	notify($ERRORS{'DEBUG'}, 0, "determined vmx intermediate directory path:\n" .
		"vmx directory path: $vmx_directory_path\n" .
		"vmx intermediate directory path: $intermediate_directory_path"
	);
	return $intermediate_directory_path || '';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_directory_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory in which the .vmx file is
               located:
               <computer name>_<image ID>-v<image revision>

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
	if ($self->{vmx_file_path}) {
		($vmx_directory_name) = $self->{vmx_file_path} =~ /([^\/]+)\/[^\/]+.vmx$/i;
		if ($vmx_directory_name) {
			return $vmx_directory_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmx directory name could not be determined from vmx file path: '$self->{vmx_file_path}'");
			return;
		}
	}
	
	# Get the computer name
	my $computer_short_name = $self->data->get_computer_short_name();
	if (!$computer_short_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the vmx directory name, failed to retrieve computer short name");
		return;
	}
	
	# Get the image ID
	my $image_id = $self->data->get_image_id();
	if (!defined($image_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the vmx directory name, failed to retrieve image ID");
		return;
	}
	
	# Get the image revision number
	my $image_revision = $self->data->get_imagerevision_revision();
	if (!defined($image_revision)) {
		notify($ERRORS{'WARNING'}, 0, "unable to assemble the vmx directory name, failed to retrieve image revision");
		return;
	}
	
	# Assemble the directory name
	return "$computer_short_name\_$image_id-v$image_revision";
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 set_vmx_file_path

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Sets the vmx path into $self so that the default values are
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
	
	$self->{vmx_file_path} = $vmx_file_path_argument;
	
	# Check all of the vmx file path components
	if ($self->check_file_paths('vmx')) {
		# Set the vmx_file_path environment variable
		notify($ERRORS{'OK'}, 0, "set overridden vmx file path: '$vmx_file_path_argument'\n$self->{vmx_file_path}");
		return 1;
	}
	else {
		delete $self->{vmx_file_path};
		notify($ERRORS{'WARNING'}, 0, "failed to set overridden vmx file path: '$vmx_file_path_argument'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reference_vmx_file_name

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the name of the reference vmx file that was used when the
               image was captured.

=cut

sub get_reference_vmx_file_name {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	return "$image_name.vmx.reference";
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->{vmdk_file_path} if $self->{vmdk_file_path};
	
	# Get the information contained within the vmx file
	my $vmx_file_path = $self->get_vmx_file_path();
	if ($self->vmhost_os->file_exists($vmx_file_path)) {
		my $vmx_info = $self->get_vmx_info($vmx_file_path);
		if ($vmx_info) {
			# Get the vmdk info from the vmx info
			my @vmdk_identifiers = keys %{$vmx_info->{vmdk}};
			if (@vmdk_identifiers) {
				# Get the vmdk file path from the vmx information
				my $vmdk_file_path = $vmx_info->{vmdk}{$vmdk_identifiers[0]}{vmdk_file_path};
				if ($vmdk_file_path) {
					notify($ERRORS{'DEBUG'}, 0, "vmdk file path stored in vmx file: $vmdk_file_path");
					return $vmdk_file_path;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "vmdk file path was not found in the vmx file info:\n" . format_data($vmx_info));
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "did not find vmdk file in vmx info ({vmdk} key):\n" . format_data($vmx_info));
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve info from vmx file: $vmx_file_path\n");
		}
	}
	
	if ($self->is_vm_dedicated()) {
		return $self->get_vmdk_file_path_dedicated();
	}
	else {
		return $self->get_vmdk_file_path_shared();
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_path_dedicated

 Parameters  : none
 Returns     : string
 Description : Returns the vmdk file path for a dedicated VM. This is
               useful when checking the image size on a VM host using
               network-based disks. It returns the vmdk file path that would be
               used for nonperistent VMs.

=cut

sub get_vmdk_file_path_dedicated {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_directory_path_dedicated = $self->get_vmdk_directory_path_dedicated();
	if (!$vmdk_directory_path_dedicated) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the dedicated vmdk file path");
		return;
	}
	
	my $vmdk_directory_name_dedicated = $self->get_vmdk_directory_name_dedicated();
	if (!$vmdk_directory_name_dedicated) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the dedicated vmdk file path");
		return;
	}
	
	return "$vmdk_directory_path_dedicated/$vmdk_directory_name_dedicated.vmdk";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_file_path_shared

 Parameters  : none
 Returns     : string
 Description : Returns the vmdk file path for a shared VM. This is
               useful when checking the image size on a VM host using
               network-based disks. It returns the vmdk file path that would be
               used for nonperistent VMs.

=cut

sub get_vmdk_file_path_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_directory_path_shared = $self->get_vmdk_directory_path_shared();
	if (!$vmdk_directory_path_shared) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the shared vmdk file path");
		return;
	}
	
	my $vmdk_directory_name_shared = $self->get_vmdk_directory_name_shared();
	if (!$vmdk_directory_name_shared) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct vmdk file path, vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_directory_path_shared/$vmdk_directory_name_shared.vmdk";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_base_directory_path

 Parameters  : $ignore_cached_path
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
	
	my $ignore_cached_path = shift;
	
	my $vmdk_base_directory_path;
	
	# Check if vmdk_file_path environment variable has been set
	# If set, parse the path to return the directory name preceding the vmdk file name and directory name
	# /<vmdk base directory path>/<vmdk directory name>/<vmdk file name>
	if (!$ignore_cached_path && $self->{vmdk_file_path}) {
		($vmdk_base_directory_path) = $self->{vmdk_file_path} =~ /(.+)\/[^\/]+\/[^\/]+.vmdk$/i;
		if ($vmdk_base_directory_path) {
			return $vmdk_base_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk base directory path could not be determined from vmdk file path: '$self->{vmdk_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_dedicated()) {
		return $self->get_vmdk_base_directory_path_dedicated();
	}
	else {
		return $self->get_vmdk_base_directory_path_shared();
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_base_directory_path_shared

 Parameters  : 
 Returns     : string
 Description : 

=cut

sub get_vmdk_base_directory_path_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_base_directory_path;
	
	# Get the vmprofile.datastore
	if ($vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path()) {
		#notify($ERRORS{'DEBUG'}, 0, "using VM profile datastore path as the vmdk base directory path: $vmdk_base_directory_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmdk base directory path, failed to retrieve the datastore path for the VM profile");
		return;
	}
	
	# Convert the path to a normal path
	# The path configured in the VM profile may be:
	# -normal absolute path: /vmfs/volumes/vcl-datastore
	# -datastore path: [vcl-datastore]
	# -datastore name: vcl-datastore
	my $vmdk_base_directory_normal_path = $self->_get_normal_path($vmdk_base_directory_path);
	if ($vmdk_base_directory_normal_path) {
		return $vmdk_base_directory_normal_path;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the shared vmdk base directory path, failed to convert datastore path configured in the VM profile to a normal path: $vmdk_base_directory_path");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_base_directory_path_dedicated

 Parameters  : none
 Returns     : string
 Description : Determines the base directory under which vmdk files are stored
               if the vmdk is dedicated for the VM being loaded.

=cut

sub get_vmdk_base_directory_path_dedicated {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmdk_base_directory_path;
	
	my $computer_name = $self->data->get_computer_short_name();
	my @datastore_names = $self->_get_datastore_names();
	
	# Check if a datastore exists named after the computer being loaded
	if (grep { $_ eq $computer_name } @datastore_names) {
		$vmdk_base_directory_path = "[$computer_name]";
		notify($ERRORS{'DEBUG'}, 0, "using datastore named after the computer being loaded as the dedicated vmdk base directory path: $vmdk_base_directory_path");
	}
	
	# If virtualdiskpath isn't set, try to use the datastore path
	elsif ($vmdk_base_directory_path = $self->data->get_vmhost_profile_datastore_path()) {
		notify($ERRORS{'DEBUG'}, 0, "using VM profile datastore path as the vmdk base directory path: $vmdk_base_directory_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the vmdk base directory path, failed to retrieve either the virtual disk or datastore path for the VM profile");
		return;
	}
	
	# Convert the path to a normal path
	# The path configured in the VM profile may be:
	# -normal absolute path: /vmfs/volumes/vcl-datastore
	# -datastore path: [vcl-datastore]
	# -datastore name: vcl-datastore
	my $vmdk_base_directory_normal_path = $self->_get_normal_path($vmdk_base_directory_path);
	if ($vmdk_base_directory_normal_path) {
		return $vmdk_base_directory_normal_path;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the dedicated vmdk base directory path, failed to convert path configured in the VM profile to a normal path: $vmdk_base_directory_path");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located. The name differs depending on whether or not the
               VM is dedicated.
               If shared: <image name>
               If dedicated: <computer name>_<image ID>-<revision>_<request ID>
               Example:
               vmdk directory path is shared: vmwarewinxp-base234-v12
               vmdk directory path is dedicated: vm1-6_987-v0_5435

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
	if ($self->{vmdk_file_path}) {
		my ($vmdk_directory_name) = $self->{vmdk_file_path} =~ /([^\/]+)\/[^\/]+.vmdk$/i;
		if ($vmdk_directory_name) {
			return $vmdk_directory_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk directory name could not be determined from vmdk file path: '$self->{vmdk_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_dedicated()) {
		return $self->get_vmdk_directory_name_dedicated();
	}
	else {
		return $self->get_vmdk_directory_name_shared();
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name_dedicated

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located if the VM is dedicated:
               <computer name>_<image ID>-<revision>_<request ID>

=cut

sub get_vmdk_directory_name_dedicated {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Use the same name that's used for the vmx directory name
	my $vmdk_directory_name_dedicated = $self->get_vmx_directory_name();
	if ($vmdk_directory_name_dedicated) {
		return $vmdk_directory_name_dedicated;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine dedicated vmdk directory name because vmx directory name could not be retrieved");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_name_shared

 Parameters  : none
 Returns     : string
 Description : Returns the name of the directory under which the .vmdk files
               are located if the VM is not dedicated:
               <image name>

=cut

sub get_vmdk_directory_name_shared {
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
		notify($ERRORS{'WARNING'}, 0, "unable determine shared vmdk directory name because image name could not be retrieved");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	if ($self->{vmdk_file_path}) {
		my ($vmdk_directory_path) = $self->{vmdk_file_path} =~ /(.+)\/[^\/]+.vmdk$/i;
		if ($vmdk_directory_path) {
			return $vmdk_directory_path;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "vmdk directory name could not be determined from vmdk file path: '$self->{vmdk_file_path}'");
			return;
		}
	}
	
	if ($self->is_vm_dedicated()) {
		return $self->get_vmdk_directory_path_dedicated();
	}
	else {
		return $self->get_vmdk_directory_path_shared();
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_path_dedicated

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the .vmdk files are
               located for dedicated VMs.

=cut

sub get_vmdk_directory_path_dedicated {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk base directory path
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path_dedicated();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the dedicated vmdk base directory path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_dedicated = $self->get_vmdk_directory_name_dedicated();
	if (!$vmdk_directory_name_dedicated) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine dedicated vmdk directory path because dedicated vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_dedicated";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmdk_directory_path_shared

 Parameters  : none
 Returns     : string
 Description : Returns the directory path under which the .vmdk files are
               located for shared VMs.

=cut

sub get_vmdk_directory_path_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk base directory path
	my $vmdk_base_directory_path = $self->get_vmdk_base_directory_path_shared();
	if (!$vmdk_base_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the shared vmdk base directory path, failed to retrieve datastore path for the VM profile");
		return;
	}
	
	my $vmdk_directory_name_shared = $self->get_vmdk_directory_name_shared();
	if (!$vmdk_directory_name_shared) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine shared vmdk directory path because shared vmdk directory name could not be determined");
		return;
	}
	
	return "$vmdk_base_directory_path/$vmdk_directory_name_shared";
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 set_vmdk_file_path

 Parameters  : $vmx_file_path
 Returns     : 
 Description : Sets the vmdk path into $self so that the default values are
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
	
	$vmdk_file_path_argument = $self->_get_normal_path($vmdk_file_path_argument);
	
	# Make sure the vmdk file path format is valid
	if ($vmdk_file_path_argument !~ /^\/.+\/.+\/[^\/]+\.vmdk$/i) {
		notify($ERRORS{'WARNING'}, 0, "unable to override vmdk file path because the path format is invalid: '$vmdk_file_path_argument'");
		return;
	}
	
	$self->{vmdk_file_path} = $vmdk_file_path_argument;
	
	# Check all of the vmdk file path components
	if ($self->check_file_paths('vmdk')) {
		# Set the vmdk_file_path environment variable
		notify($ERRORS{'OK'}, 0, "set overridden vmdk file path: '$vmdk_file_path_argument'");
		return 1;
	}
	else {
		delete $self->{vmdk_file_path};
		notify($ERRORS{'WARNING'}, 0, "failed to set overridden vmdk file path: '$vmdk_file_path_argument'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	$check_paths_string .= "VM profile VM path:                '" . ($self->data->get_vmhost_profile_vmpath() || $undefined_string) . "'\n";
	$check_paths_string .= "VM profile datastore path:         '" . ($self->data->get_vmhost_profile_datastore_path() || $undefined_string) . "'\n";
	
	if ($file_type !~ /vmdk/i) {
		$check_paths_string .= "vmx file path:                     '" . ($self->get_vmx_file_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx directory path:                '" . ($self->get_vmx_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx base directory path:           '" . ($self->get_vmx_base_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx directory name:                '" . ($self->get_vmx_directory_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx file name:                     '" . ($self->get_vmx_file_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmx datastore URL path:            '" . ($self->_get_datastore_root_url_path($self->get_vmx_file_path()) || $undefined_string) . "'\n";
		$check_paths_string .= "vmx datastore URL:                 '" . ($self->_get_datastore_url($self->get_vmx_file_path()) || $undefined_string) . "'\n";
	}
	
	if ($file_type !~ /vmx/i) {
		$check_paths_string .= "vmdk file path:                    '" . ($self->get_vmdk_file_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk directory path:               '" . ($self->get_vmdk_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk base directory path:          '" . ($self->get_vmdk_base_directory_path() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk directory name:               '" . ($self->get_vmdk_directory_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk file name:                    '" . ($self->get_vmdk_file_name() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk file prefix:                  '" . ($self->get_vmdk_file_prefix() || $undefined_string) . "'\n";
		$check_paths_string .= "dedicated vmdk file path:          '" . ($self->get_vmdk_file_path_dedicated() || $undefined_string) . "'\n";
		$check_paths_string .= "dedicated vmdk directory path:     '" . ($self->get_vmdk_directory_path_dedicated() || $undefined_string) . "'\n";
		$check_paths_string .= "dedicated vmdk directory name:     '" . ($self->get_vmdk_directory_name_dedicated() || $undefined_string) . "'\n";
		$check_paths_string .= "shared vmdk file path:             '" . ($self->get_vmdk_file_path_shared() || $undefined_string) . "'\n";
		$check_paths_string .= "shared vmdk directory path:        '" . ($self->get_vmdk_directory_path_shared() || $undefined_string) . "'\n";
		$check_paths_string .= "shared vmdk directory name:        '" . ($self->get_vmdk_directory_name_shared() || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk datastore URL path:           '" . ($self->_get_datastore_root_url_path($self->get_vmdk_file_path()) || $undefined_string) . "'\n";
		$check_paths_string .= "vmdk datastore URL:                '" . ($self->_get_datastore_url($self->get_vmdk_file_path()) || $undefined_string) . "'\n";
	}
	
	if ($check_paths_string =~ /$undefined_string/) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve $file_type file path components:\n$check_paths_string");
		return;
	}
	else {
		# Set the vmdk_file_path environment variable
		notify($ERRORS{'DEBUG'}, 0, "successfully retrieved $file_type file path components:\n$check_paths_string");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	my $reference_vmx_file_name = $self->get_reference_vmx_file_name();
	
	my @repository_search_paths;
	
	if (my $repository_vmdk_directory_path = $self->get_repository_vmdk_directory_path()) {
		push @repository_search_paths, "$repository_vmdk_directory_path/$image_name*.vmdk";
		push @repository_search_paths, "$repository_vmdk_directory_path/$reference_vmx_file_name";
	}
	
	if (my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier)) {
		push @repository_search_paths, "$management_node_install_path/vmware_images/$image_name/$image_name*.vmdk";
		push @repository_search_paths, "$management_node_install_path/vmware_images/$image_name/$reference_vmx_file_name";
		
		push @repository_search_paths, "$management_node_install_path/$image_name/$image_name*.vmdk";
		push @repository_search_paths, "$management_node_install_path/$image_name/$reference_vmx_file_name";
	}
	
	push @repository_search_paths, "/install/vmware_images/$image_name/$image_name*.vmdk";
	push @repository_search_paths, "/install/vmware_images/$image_name/$reference_vmx_file_name";
	
	my %seen;
	@repository_search_paths = grep { !$seen{$_}++ } @repository_search_paths; 
	#notify($ERRORS{'DEBUG'}, 0, "repository search paths on $management_node_identifier:\n" . join("\n", @repository_search_paths));
	return @repository_search_paths;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Attempt the retrieve vmhost.repositorypath
	my $repository_vmdk_base_directory_path = $self->data->get_vmhost_profile_repository_path(0);
	if (!$repository_vmdk_base_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "repository path is not configured in the VM profile");
		return;
	}
	
	# Convert the path to a normal path
	# The path configured in the VM profile may be:
	# -normal absolute path: /vmfs/volumes/vcl-datastore
	# -datastore path: [vcl-datastore]
	# -datastore name: vcl-datastore
	my $repository_base_directory_normal_path = $self->_get_normal_path($repository_vmdk_base_directory_path);
	if ($repository_base_directory_normal_path) {
		return $repository_base_directory_normal_path;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the repository base directory path, failed to convert repository path configured in the VM profile to a normal path: $repository_vmdk_base_directory_path");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $repository_vmdk_base_directory = $self->get_repository_vmdk_base_directory_path;
	if (!$repository_vmdk_base_directory) {
		notify($ERRORS{'DEBUG'}, 0, "image repository vmdk directory path cannot be determined because repository path is not configured in the VM profile");
		return;
	}
	
	my $image_name = $self->data->get_image_name() || return;
	return "$repository_vmdk_base_directory/$image_name";
}

#//////////////////////////////////////////////////////////////////////////////

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
	my $image_name = $self->data->get_image_name() || return;
	return "$repository_vmdk_directory_path/$image_name.vmdk";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_vm_dedicated

 Parameters  : none
 Returns     : boolean
 Description : Determines if a VM's virtual disk must be dedicated to the VM or
               shared. Conditions that request the virtual disk to be dedicated:
               -server request
               -request duration is more than 24 hours long

=cut

sub is_vm_dedicated {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{vm_dedicated} if defined $self->{vm_dedicated};
	
	my $vm_dedicated = 0;
	
	if ($self->data->is_server_request()) {
		notify($ERRORS{'DEBUG'}, 0, "server request, VM's virtual disk must be dedicated");
		$vm_dedicated = 1;
	}
	#else {
	#	# Return true if the request end time is more than 24 hours in the future
	#	my $request_start_time = $self->data->get_request_start_time(0);
	#	my $request_end_time = $self->data->get_request_end_time(0);
	#	if ($request_end_time) {
	#		my $start_epoch = convert_to_epoch_seconds($request_start_time);
	#		my $end_epoch = convert_to_epoch_seconds($request_end_time);
	#		
	#		my $end_hours = (($end_epoch - $start_epoch) / 60 / 60);
	#		if ($end_hours >= 24) {
	#			notify($ERRORS{'DEBUG'}, 0, "request duration is " . format_number($end_hours, 1) . " hours long, VM's virtual disk must be dedicated");
	#			$vm_dedicated = 1;
	#		}
	#	}
	#}
	
	if (!$vm_dedicated) {
		notify($ERRORS{'DEBUG'}, 0, "VM disk mode does not need to be dedicated");
	}
	
	$self->{vm_dedicated} = $vm_dedicated;
	return $self->{vm_dedicated};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_vmdk_file_shared

 Parameters  : $vmdk_file_path
 Returns     : boolean
 Description : Checks if the vmdk directory appears to be shared. A vmdk is
               not considered shared if any of the following are true:
               -The vmdk file name doesn't begin with any of the OS names defined in the
                VCL database
               -The vmdk file appears to be a snaphot

=cut

sub is_vmdk_file_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path
	my $vmdk_file_path = shift || $self->get_vmdk_file_path();
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path argument was not supplied and path could not be retrieved");
		return;
	}
	elsif ($vmdk_file_path !~ /\.vmdk$/i) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path does not end with .vmdk: $vmdk_file_path");
		return;
	}
	
	# Get the vmdk file name
	my $vmdk_file_name = $self->_get_file_name($vmdk_file_path);
	
	# Get an array containing the OS names stored in the database
	my $os_info = get_os_info();
	my @os_names = sort(map { $os_info->{$_}{name} } keys %$os_info);
	
	# Check if the vmdk file name begins with any of the OS names
	# Shared:
	#    vmwarewinxp-base234-v23.vmdk
	#    vmwarewinxp-base234-v23-flat.vmdk
	#    vmwarewinxp-base234-v23-s004.vmdk
	#    vmwarewinxp-base234-v23-f004.vmdk
	
	# Snapshots - not shared:
	# monolithicSparse snapshot:
	#    *-00000*.vmdk        (vmwarewinxp-base234-v23-000001.vmdk)
	# twoGbMaxExtentSparse snapshot:
	#    *-00000*.vmdk        (vmwarewinxp-base234-v23-000001.vmdk)
	#    *-00000*-s00*.vmd    (vmwarewinxp-base234-v23-000001-s001.vmdk)
	# vmfsSparse snapshot:
	#    *-00000*.vmdk        (vmwarewinxp-base234-v23-000001.vmdk)
	#    *-00000*-delta.vmdk  (vmwarewinxp-base234-v23-000001-delta.vmdk)
	
	if (my @matching_os_names = map { $vmdk_file_name =~ /^($_)-/ || "vmware$vmdk_file_name" =~ /^($_)-/ } @os_names) {
		if ($vmdk_file_name =~ /-\d+(-delta|-s\d+)?\.vmdk$/i) {
			notify($ERRORS{'DEBUG'}, 0, "vmdk file does NOT appear to be shared, it is a snapshot file: '$vmdk_file_name'");
			return 0;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "vmdk file appears to be shared: '$vmdk_file_name', it is not a snapshot file and begins with the name of an OS in the database: " . join(' ,', @matching_os_names));
			return 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file does NOT appear to be shared, file name '$vmdk_file_name' does NOT begin with the name of an OS in the database");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_vmdk_directory_shared

 Parameters  : $vmdk_directory_path
 Returns     : boolean
 Description : Checks if the vmdk directory appears to be shared. A vmdk is
               not considered shared if any of the following are true:
               -The vmdk file name doesn't begin with any of the OS names defined in the
                VCL database
               -The vmdk file appears to be a snaphot

=cut

sub is_vmdk_directory_shared {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk directory path
	my $vmdk_directory_path = shift || $self->get_vmdk_directory_path();
	if (!$vmdk_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk directory path argument was not supplied and path could not be retrieved");
		return;
	}
	elsif ($vmdk_directory_path =~ /\.vmdk$/i) {
		$vmdk_directory_path = $self->_get_parent_directory_normal_path($vmdk_directory_path);
	}
	
	# Get the directory name
	my $vmdk_directory_name = $self->_get_file_name($vmdk_directory_path);
	if (!$vmdk_directory_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if vmdk directory is shared, directory name could not be determined from path: $vmdk_directory_path");
		return;
	}
	
	# Get an array containing the OS names stored in the database
	my $os_info = get_os_info();
	my @os_names = sort(map { $os_info->{$_}{name} } keys %$os_info);
	
	
	if (my @matching_os_names = map { $vmdk_directory_name =~ /^($_)-/ || "vmware$vmdk_directory_name" =~ /^($_)-/ } @os_names) {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory appears to be shared: '$vmdk_directory_path', it begins with the name of an OS in the database: " . join(' ,', @matching_os_names));
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory name '$vmdk_directory_name' does NOT begin with the name of an OS in the database");
	}
	
	my $file_path_computer_name = $self->_get_file_path_computer_name($vmdk_directory_path);
	if ($file_path_computer_name) {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory does NOT appear to be shared: '$vmdk_directory_path', it contains a computer name: $file_path_computer_name");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory may be shared: '$vmdk_directory_path', it does NOT appear to contain a computer name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	$vmx_file_path = $self->_get_normal_path($vmx_file_path);
	
	my @registered_vmx_file_paths = $self->api->get_registered_vms();
	for my $registered_vmx_file_path (@registered_vmx_file_paths) {
		$registered_vmx_file_path = $self->_get_normal_path($registered_vmx_file_path);
		if ($registered_vmx_file_path && $vmx_file_path eq $registered_vmx_file_path) {
			notify($ERRORS{'DEBUG'}, 0, "VM is registered: $vmx_file_path");
			return 1;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VM is not registered: '$vmx_file_path'");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_size_bytes

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the image in bytes. If the VM profile
               repository path is defined, an attempt is first made to retrieve
               the size from the repository. Otherwise, the size of the image in
               the vmdk directory on the VM host is checked.

=cut

sub get_image_size_bytes {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	my $management_node_hostname = $self->data->get_management_node_short_name() || 'management node';
	my $vmdk_base_directory_path_shared = $self->get_vmdk_base_directory_path_shared() || return;
	
	# Attempt to get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		$image_name = $self->data->get_image_name() || return;
	}
	
	my $image_size_bytes_repository;
	my $image_size_bytes_datastore;
	
	# Try to retrieve the image size from the repository if localdisk is being used
	my $repository_vmdk_base_directory_path = $self->get_repository_vmdk_base_directory_path();
	if ($repository_vmdk_base_directory_path) {
		my $repository_search_path = "$repository_vmdk_base_directory_path/$image_name/$image_name*.vmdk";
		
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve image size from image repository");
		if ($self->is_repository_mounted_on_vmhost()) {
			notify($ERRORS{'DEBUG'}, 0, "checking size of image in image repository mounted on VM host: $vmhost_name:$repository_vmdk_base_directory_path");
			
			# Get the size of the files on the VM host
			$image_size_bytes_repository = $self->vmhost_os->get_file_size($repository_search_path);
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "checking size of image in image repository in management node: $management_node_hostname:$repository_vmdk_base_directory_path");
			
			# Get the size of the files on the management node
			$image_size_bytes_repository = $self->mn_os->get_file_size($repository_search_path);
			notify($ERRORS{'DEBUG'}, 0, "size of image retrieved from image repository on management node: " . get_file_size_info_string($image_size_bytes_repository));
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image repository path is not configured in the VM profile, image size will NOT be retrieved from image repository");
	}
	
	# Attempt to retrieve size from the datastore on the VM host whether or not the size was retrieved from the image repository
	my $search_path_datastore = "$vmdk_base_directory_path_shared/$image_name/$image_name*.vmdk";
	$image_size_bytes_datastore = $self->vmhost_os->get_file_size($search_path_datastore);
	if (defined($image_size_bytes_datastore)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved the size of the image from the datastore on the VM host: " . format_number($image_size_bytes_datastore));
	}
	
	my $image_size_bytes;
	if (!defined($image_size_bytes_repository) && !defined($image_size_bytes_datastore)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the size of image in image repository or on the VM host");
		return;
	}
	elsif (defined($image_size_bytes_repository) && defined($image_size_bytes_datastore)) {
		notify($ERRORS{'DEBUG'}, 0, "image size retrieved from both the image repository and VM host datastore:\n" .
			"image repository: " . format_number($image_size_bytes_repository) . "\n" .
			"VM host datastore: " . format_number($image_size_bytes_datastore)
		);
		
		if ($image_size_bytes_repository > $image_size_bytes_datastore) {
			$image_size_bytes = $image_size_bytes_repository;
		}
		else {
			$image_size_bytes = $image_size_bytes_datastore;
		}
	}
	elsif (defined($image_size_bytes_repository)) {
		$image_size_bytes = $image_size_bytes_repository;
	}
	else {
		$image_size_bytes = $image_size_bytes_datastore;
	}
	
	my $image_size_mb = format_number(($image_size_bytes / 1024 / 1024));
	my $image_size_gb = format_number(($image_size_bytes / 1024 / 1024 / 1024), 2);
	notify($ERRORS{'DEBUG'}, 0, "size of $image_name image:\n" .
		format_number($image_size_bytes) . " bytes\n" .
		"$image_size_mb MB\n" .
		"$image_size_gb GB"
	);
	return $image_size_bytes;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $image_name = $self->data->get_image_name();
	my $image_name_truncated = $self->_clean_vm_name($image_name);
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	my $management_node_hostname = $self->data->get_management_node_short_name() || 'management node';
	
	# Get the shared vmdk file path used on the VM host
	my $vmhost_vmdk_file_path_shared = $self->get_vmdk_file_path_shared();
	if (!$vmhost_vmdk_file_path_shared) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine shared vmdk file path on the VM host");
		return;
	}
	
	# Check if the vmdk file already exists on the VM host
	if ($self->vmhost_os->file_exists($vmhost_vmdk_file_path_shared)) {
		notify($ERRORS{'OK'}, 0, "image exists in datastore on VM host $vmhost_name: $vmhost_vmdk_file_path_shared");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does NOT exist in datastore on VM host $vmhost_name: $vmhost_vmdk_file_path_shared");
	}
	
	# Check if the truncated vmdk file already exists on the VM host
	(my $vmhost_vmdk_file_path_shared_truncated = $vmhost_vmdk_file_path_shared) =~ s/$image_name/$image_name_truncated/g;
	if ($self->vmhost_os->file_exists($vmhost_vmdk_file_path_shared_truncated)) {
		notify($ERRORS{'OK'}, 0, "image exists with truncated name in datastore on VM host $vmhost_name: $vmhost_vmdk_file_path_shared_truncated");
		$self->data->set_image_name($image_name_truncated);
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does NOT exist with truncated name in datastore on VM host $vmhost_name: $vmhost_vmdk_file_path_shared_truncated");
	}
	
	# Get the image repository file path
	my $repository_vmdk_file_path = $self->get_repository_vmdk_file_path();
	if (!$repository_vmdk_file_path) {
		notify($ERRORS{'OK'}, 0, "image does not exist on the VM host and image repository path is not configured in the VM profile");
		return 0;
	}
	
	(my $repository_vmdk_file_path_truncated = $repository_vmdk_file_path) =~ s/$image_name/$image_name_truncated/g;
	
	if ($self->is_repository_mounted_on_vmhost()) {
		if ($self->vmhost_os->file_exists($repository_vmdk_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "image exists in image repository mounted on VM host: $vmhost_name:$repository_vmdk_file_path");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "image does NOT exist in image repository mounted on VM host: $vmhost_name:$repository_vmdk_file_path");
		}
		
		if ($self->vmhost_os->file_exists($repository_vmdk_file_path_truncated)) {
			notify($ERRORS{'DEBUG'}, 0, "image exists with truncated name in image repository mounted on VM host $vmhost_name: $repository_vmdk_file_path_truncated");
			$self->data->set_image_name($image_name_truncated);
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "image does NOT exist with truncated name in image repository mounted on VM host $vmhost_name: $repository_vmdk_file_path_truncated");
		}
	}
	else {
		if ($self->mn_os->file_exists($repository_vmdk_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "image exists in image repository mounted on management node: $repository_vmdk_file_path");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "image does NOT exist in image repository mounted on management node: $repository_vmdk_file_path");
		}
		
		if ($self->mn_os->file_exists($repository_vmdk_file_path_truncated)) {
			notify($ERRORS{'DEBUG'}, 0, "image exists with truncated name in image repository mounted on management node: $repository_vmdk_file_path_truncated");
			$self->data->set_image_name($image_name_truncated);
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "image does NOT exist with truncated name in image repository mounted on management node: $repository_vmdk_file_path_truncated");
		}
	}
	
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $vmhost_name = $self->data->get_vmhost_short_name();
	
	# Try to get the file contents from the VM host
	my $vmdk_file_path = $self->get_vmdk_file_path();
	my @vmdk_file_lines = $self->vmhost_os->get_file_contents($vmdk_file_path);
	
	if (!@vmdk_file_lines) {
		my $head_command = "head -n 100 $vmdk_file_path";
		
		my $image_repository_vmdk_file_path = $self->get_repository_vmdk_file_path();
		$head_command .= " $image_repository_vmdk_file_path" if $image_repository_vmdk_file_path;
		
		my ($head_exit_status, $head_output) = $self->mn_os->execute($head_command);
		if (!defined($head_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command on management node while attempting to locate $vmdk_parameter value in vmdk file: '$head_command'");
			return;
		}
		@vmdk_file_lines = @$head_output;
	}
	
	for my $vmdk_file_line (@vmdk_file_lines) {
		# Ignore comment lines
		next if ($vmdk_file_line =~ /^\s*#/);
		
		# Check if the line contains the parameter name
		if ($vmdk_file_line =~ /(?:^|\.)$vmdk_parameter[=\s\"]*([^\"]*)/ig) {
			my $value = $1;
			chomp $value;
			notify($ERRORS{'DEBUG'}, 0, "found '$vmdk_parameter' value in vmdk file:\nline: '$vmdk_file_line'\nvalue: '$value'");
			return $value;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "did not find '$vmdk_parameter' value in vmdk file");
	return;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $vmdk_file_path = shift || $self->get_vmdk_file_path_shared();
	
	my $vmdk_controller_type;
	
	# Attempt to retrieve the type from the reference vmx file for the image
	my $reference_vmx_file_info = $self->get_reference_vmx_info();
	if ($reference_vmx_file_info) {
		for my $vmx_key (keys %$reference_vmx_file_info) {
			if ($vmx_key =~ /scsi\d+\.virtualdev/i) {
				$vmdk_controller_type = $reference_vmx_file_info->{$vmx_key};
				notify($ERRORS{'DEBUG'}, 0, "retrieved VM disk adapter type from reference vmx file: $vmdk_controller_type");
				return $vmdk_controller_type;
			}
		}
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve VM disk adapter type from reference vmx file, 'scsi*.virtualDev' key does not exist");
	}
	
	# Try to get the type from the API module's get_virtual_disk_controller_type subroutine
	if ($self->api->can("get_virtual_disk_controller_type")) {
		if ($vmdk_controller_type = $self->api->get_virtual_disk_controller_type($vmdk_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved VM disk adapter type from api object: $vmdk_controller_type");
			return $vmdk_controller_type;
		}
	}
	
	# Try to retrieve the adapter type by reading the vmdk descriptor
	if ($vmdk_controller_type = $self->get_vmdk_parameter_value('adapterType')) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM disk adapter type from vmdk file: $vmdk_controller_type");
		return $vmdk_controller_type;
	}
	
	# Try to retrieve the default adapter type for the image OS
	my $vm_os_configuration = $self->get_vm_os_configuration();
	if ($vm_os_configuration && ($vmdk_controller_type = $vm_os_configuration->{"scsi-virtualDev"})) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved default VM disk adapter type for VM OS: $vmdk_controller_type");
		return $vmdk_controller_type;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM disk adapter type from default VM OS configuration");
		return;
	}
	
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Attempt to get the highest version supported by the VMware host
	if ($self->api->can('get_highest_vm_hardware_version_key')) {
		my $hardware_version_key = $self->api->get_highest_vm_hardware_version_key();
		if ($hardware_version_key) {
			($hardware_version) = $hardware_version_key =~ /-(\d+)$/g;
			if ($hardware_version) {
				notify($ERRORS{'DEBUG'}, 0, "retrieved highest VM hardware version supported on host: $hardware_version");
				return $hardware_version;
			}
		}
	}
	
	# Attempt to retrieve the type from the reference vmx file for the image
	my $reference_vmx_file_info = $self->get_reference_vmx_info();
	if ($reference_vmx_file_info) {
		for my $vmx_key (keys %$reference_vmx_file_info) {
			if ($vmx_key =~ /virtualHW\.version/i) {
				$hardware_version = $reference_vmx_file_info->{$vmx_key};
				notify($ERRORS{'DEBUG'}, 0, "retrieved VM virtual hardware version from reference vmx file: $hardware_version");
			}
		}
		if (!defined($hardware_version)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to retrieve VM virtual hardware version from reference vmx file, 'virtualHW.version' key does not exist");
		}
	}
	
	# If hardware version could not be retrieved from reference vmx file, try to retrieve it from the vmdk file via the API object
	if (!$hardware_version) {
		if ($self->api->can("get_virtual_disk_hardware_version")) {
			if ($hardware_version = $self->api->get_virtual_disk_hardware_version($self->get_vmdk_file_path())) {
				notify($ERRORS{'DEBUG'}, 0, "retrieved virtual disk hardware version from api object: $hardware_version");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "unable to retrieve virtual disk hardware version from api object");
			}
		}
	}
	
	# Next, try to retrieve it directly from the vmdk file
	if (!$hardware_version) {
		if ($hardware_version = $self->get_vmdk_parameter_value('virtualHWVersion')) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved hardware version stored in the vmdk file: $hardware_version");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to retrieve hardware version stored in the vmdk file");
		}
	}
	
	if (!$hardware_version) {
		notify($ERRORS{'DEBUG'}, 0, "unable to determine hardware version from the reference vmx file or vmdk file, assuming 7");
		$hardware_version = 7;
	}
	
	# Get the VMware product name
	my $vmware_product_name = $self->get_vmhost_product_name();
	if (!$vmware_product_name) {
		return $hardware_version;
	}
	
	# Under ESXi, IDE adapters are not allowed if the hardware version is 4
	# Override the hardware version retrieved from the vmdk file if:
	# -VMware product = ESX
	# -Adapter type = IDE
	# -Hardware version < 7
	if ($hardware_version < 7 && $vmware_product_name =~ /esx/i) {
		my $adapter_type = $self->get_vm_disk_adapter_type();
		if (!$adapter_type) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine disk adapter type in order to tell if hardware version should be overridden");
		}
		elsif ($adapter_type =~ /ide/i) {
			notify($ERRORS{'OK'}, 0, "overriding hardware version $hardware_version --> 7, IDE adapters cannot be used on ESX unless the hardware version is 7 or higher, VMware product: '$vmware_product_name', vmdk adapter type: $adapter_type, vmdk hardware version: $hardware_version");
			return 7;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "hardware version $hardware_version is not valid on $vmware_product_name, overriding to version 7");
			return 7;
		}
	}
	
	# Maximum hardware version by VMware version:
	my $vmware_max_hardware_versions = {
		'Server 1'  => 4,
		'Server 2'  => 7,
		'ESX 3'     => 4,
		'ESXi? 4'   => 7,
		'ESXi 5\.0' => 8,
		'ESXi 5\.1' => 9,
		'ESXi 5\.5' => 10,
	};
	
	for my $vmware_version (keys %$vmware_max_hardware_versions) {
		if ($vmware_product_name =~ /$vmware_version/i) {
			my $vmware_max_hardware_version = $vmware_max_hardware_versions->{$vmware_version};
			if ($hardware_version > $vmware_max_hardware_version) {
				notify($ERRORS{'OK'}, 0, "$vmware_product_name does not support hardware version $hardware_version, returning $vmware_max_hardware_version");
				return $vmware_max_hardware_version;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "$vmware_product_name supports hardware version $hardware_version");
				return $hardware_version;
			}
		}
	}
	
	notify($ERRORS{'OK'}, 0, "returning hardware version $hardware_version");
	return $hardware_version;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_os_configuration

 Parameters  : none
 Returns     : hash
 Description : Returns the information stored in %VM_OS_CONFIGURATION for
               the guest OS. The guest OS type, OS name, and archictecture are
               used to determine some of the appropriate values to be used in
               the vmx file.

=cut

sub get_vm_os_configuration {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Return previously retrieved data if it exists
	return $self->{vm_os_configuration} if $self->{vm_os_configuration};
	
	my $image_os_name = $self->data->get_image_os_name() || return;
	my $image_os_type = $self->data->get_image_os_type();
	my $image_architecture = $self->data->get_image_architecture() || return;

	# Figure out the key name in the %VM_OS_CONFIGURATION hash for the guest OS
	for my $vm_os_configuration_key (keys(%VM_OS_CONFIGURATION)) {
		my ($os_product_name, $os_architecture) = $vm_os_configuration_key =~ /(.+)-(.+)/;
		if (!$os_product_name || !$os_architecture) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse VM OS configuration key: $vm_os_configuration_key, format should be <OS product name>-<architecture>");
			next;
		}
		elsif ($image_architecture ne $os_architecture) {
			next;
		}
		elsif ($image_os_name !~ /$os_product_name/) {
			next;
		}
		else {
			$self->{vm_os_configuration} = $VM_OS_CONFIGURATION{$vm_os_configuration_key};
			notify($ERRORS{'DEBUG'}, 0, "returning matching '$vm_os_configuration_key' OS configuration: $image_os_name, image architecture: $image_architecture\n" . format_data($self->{vm_os_configuration}));
		}
	}
	
	if (!$self->{vm_os_configuration}) {
		# Check if the default key exists for the OS type - 'windows', 'linux', etc.
		if ($self->{vm_os_configuration} = $VM_OS_CONFIGURATION{"$image_os_type-$image_architecture"}) {
			notify($ERRORS{'DEBUG'}, 0, "returning default '$image_os_type' OS configuration, architecture: $image_architecture\n" . format_data($self->{vm_os_configuration}));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "default VM OS configuration key '$image_os_type-$image_architecture' does not exist for image OS type: $image_os_type, image architecture: $image_architecture");
			
			# Check if the default key exists for the image architecture
			if ($self->{vm_os_configuration} = $VM_OS_CONFIGURATION{"default-$image_architecture"}) {
				notify($ERRORS{'DEBUG'}, 0, "returning default OS configuration, architecture: $image_architecture\n" . format_data($self->{vm_os_configuration}));
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "default VM OS configuration key 'default-$image_architecture' does not exist for image architecture: $image_architecture");
				
				# Unable to locate closest matching key, return default x86 configuration
				$self->{vm_os_configuration} = $VM_OS_CONFIGURATION{"default-x86"};
				notify($ERRORS{'DEBUG'}, 0, "returning default x86 OS configuration\n" . format_data($self->{vm_os_configuration}));
			}
		}
	}
	
	return $self->{vm_os_configuration};
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Get the hard-coded default guest OS value
	my $vm_os_configuration = $self->get_vm_os_configuration() || {};
	my $default_guest_os = $vm_os_configuration->{'guestOS'} || 'other';
	
	my $guest_os_determination = 'default value for image OS';
	
	# Attempt to retrieve the guestOS from the reference vmx file for the image
	my $reference_vmx_file_info = $self->get_reference_vmx_info();
	if (!$reference_vmx_file_info) {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, reference .vmx file information could not be retrieved, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	my $refererence_guest_os = $reference_vmx_file_info->{guestos};
	if ($refererence_guest_os) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved guestOS value from reference vmx file: $refererence_guest_os");
		$default_guest_os = $refererence_guest_os;
		$guest_os_determination = 'value from reference .vmx file';
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, guestOS value could not be retrieved from reference .vmx file, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	
	
	# Get the supported guest OS names from the API object
	my @supported_guest_os_ids;
	if ($self->api->can('get_supported_guest_os_ids')) {
		@supported_guest_os_ids = $self->api->get_supported_guest_os_ids();
		if (!@supported_guest_os_ids) {
			notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, failed to retrieve list of supported guest OS names from the API object, returning $guest_os_determination: $default_guest_os");
			return $default_guest_os;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, API object does not implement a 'get_supported_guest_os_names' subroutine, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	
	# Get the 'os_product_name' value from the reference .vmx file if it exists
	# This gets added when a VM is loaded if it can be determined from the running OS
	my $captured_os_product_name = $reference_vmx_file_info->{'os_product_name'};
	if (!$captured_os_product_name) {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, reference .vmx file does not contain an 'os_product_name' key, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	
	my $captured_os_64_bit = $reference_vmx_file_info->{'os_64_bit'} || 1;
	my $guest_os_64_bit_section = ($captured_os_64_bit ? '-64' : '');
	
	# $captured_os_product_name should like like:
	# CentOS release 6.5 (Final)									: centos-64
	# Red Hat Enterprise Linux Server release 7.2 (Maipo)	: rhel7-64
	# Ubuntu 16.04.1 LTS												: ubuntu-64
	# Windows 7 Enterprise											: windows7-64
	# Windows 8 Enterprise											: windows8-64
	# Windows 10 Enterprise											: windows9-64
	# Windows Server 2008 R2 Datacenter							: windows7srv-64
	# Windows Server 2012 R2 Datacenter							: windows8srv-64
	my $image_os_product_patterns = {
		'^centos[^\d]*[4567]'			=> '"centos'		. $guest_os_64_bit_section . '"',
		'^(?:red hat|rh)[^\d]*(\d+)'	=> '"rhel$1'		. $guest_os_64_bit_section . '"',
		'^ubuntu'							=> '"ubuntu' 		. $guest_os_64_bit_section . '"',
		'^windows[^\d]*(7|8)'			=> '"windows$1'	. $guest_os_64_bit_section . '"',
		'^windows[^\d]*10'				=> '"windows9'		. $guest_os_64_bit_section . '"',
		'^windows[^\d]*2008'				=> '"windows7srv'	. $guest_os_64_bit_section . '"',
		'^windows[^\d]*2012'				=> '"windows8srv'	. $guest_os_64_bit_section . '"',
		'^windows[^\d]*2016'				=> '"windows9srv'	. $guest_os_64_bit_section . '"',
	};
	
	my $guest_os;
	for my $image_os_product_pattern (keys %$image_os_product_patterns) {
		my $guest_os_value = $image_os_product_patterns->{$image_os_product_pattern};
		if ($captured_os_product_name =~ /$image_os_product_pattern/i) {
			$guest_os = eval $guest_os_value;
			
			notify($ERRORS{'DEBUG'}, 0, "match:\n" .
				"image OS product : $captured_os_product_name\n" .
				"pattern          : $image_os_product_pattern\n" .
				"guest OS value   : $guest_os_value\n" .
				"guest OS         : $guest_os"
			);
			
			last;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "no match:\n" .
				"image OS product : $captured_os_product_name\n" .
				"pattern          : $image_os_product_pattern\n" .
				"guest OS value   : $guest_os_value"
			);
		}
	}
	
	if (!defined($guest_os)) {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, did not find a pattern matching OS product name: $captured_os_product_name, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	elsif (!grep { $guest_os eq $_ } @supported_guest_os_ids) {
		notify($ERRORS{'DEBUG'}, 0, "unable to dynamically determine VM guest OS value, '$guest_os' does not match any supported guest OS names, returning $guest_os_determination: $default_guest_os");
		return $default_guest_os;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "dynamically determined VM guest OS value: '$guest_os'");
		return $guest_os;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_cpu_socket_limit

 Parameters  : none
 Returns     : string
 Description : Returns the maximum number of CPU sockets which may be allocated
               to the VM based on the OS being loaded.

=cut

sub get_vm_cpu_socket_limit {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_os_configuration = $self->get_vm_os_configuration() || return;
	return $vm_os_configuration->{"cpu_socket_limit"};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_ethernet_adapter_type

 Parameters  : none
 Returns     : string
 Description : Returns the appropriate ethernet virtualDev value to be used in
               the vmx file. If the reference vmx file exists for the image, the
               type is retrieved from the ethernet0.virtualdev line in the file.
               Otherwise the default adapter type for the OS being loaded is
               returned.

=cut

sub get_vm_ethernet_adapter_type {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_ethernet_adapter_type;
	
	# Attempt to retrieve the type from the reference vmx file for the image
	my $reference_vmx_file_info = $self->get_reference_vmx_info();
	if ($reference_vmx_file_info) {
		for my $vmx_key (keys %$reference_vmx_file_info) {
			if ($vmx_key =~ /ethernet0\.virtualDev/i) {
				$vm_ethernet_adapter_type = $reference_vmx_file_info->{$vmx_key};
				notify($ERRORS{'DEBUG'}, 0, "retrieved VM ethernet adapter type from reference vmx file: $vm_ethernet_adapter_type");
				return $vm_ethernet_adapter_type;
			}
		}
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve VM ethernet adapter type from reference vmx file, 'ethernet0.virtualDev' key does not exist");
	}
	
	my $vm_os_configuration = $self->get_vm_os_configuration() || return;
	return $vm_os_configuration->{"ethernet-virtualDev"};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_ram

 Parameters  : none
 Returns     : integer
 Description : Returns the amount of RAM in MB to be assigned to the VM. The
               larger of the image and OS table 'minram' values is used as the
               base value.
               
               The RAM setting in the vmx file must be a multiple of 4. The
               minimum RAM value is checked to make sure it is a multiple of 4.
               If not, the value is rounded down.

=cut

sub get_vm_ram {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
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
		notify($ERRORS{'DEBUG'}, 0, "image minimum RAM value ($image_minram_mb_original MB) is not a multiple of 4, adjusting to $image_minram_mb MB");
	}
	
	return $image_minram_mb;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_cpu_configuration

 Parameters  : none
 Returns     : array or integer
 Description : Determines the total number of cores (vmx: numvcpus) and cores
               per socket (vmx: cpuid.coresPerSocket) that should be allocated
               to the VM. The image.minprocnumber value is used as a starting
               point. Checks are done to make the the VMware license vCPU limit
               isn't exceeded and that the host has at least as many cores as
               being assiged to the VM.
               
               Some VM guest OS's have CPU socket count limitations (2 for
               Windows 7) but can handle multicore CPU configurations. If this
               is the case, an attempt is made to determine a valid multicore
               configuration.
               
               This subroutine can be called expecting either a scalar or array
               returned. If called expecting an array, the total number of cores
               assigned to the VM and cores per socket are returned:
               my ($total_core_count, $cores_per_socket) = $self->get_vm_cpu_configuration();
               
               If called expecting a scalar, the total number of cores assigned
               to the VM is returned:
               my $total_core_count = $self->get_vm_cpu_configuration();

=cut

sub get_vm_cpu_configuration {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the image minimum processor number setting
	my $total_core_count = $self->data->get_image_minprocnumber() || 1;
	if (!defined($total_core_count)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve image.minprocnumber value, returning numvcpus=1, cpuid.coresPerSocket=1)");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	my $image_os_prettyname = $self->data->get_image_os_prettyname();

	my $socket_count = 1;
	my $cores_per_socket = 1;
	if ($total_core_count > 1) {
		# Check if the image.minprocnumber is greater than the VM host's CPUs/VM limit according the the VMware license
		my $vmhost_cpu_limit = $self->get_vm_cpu_limit();
		if ($vmhost_cpu_limit && $total_core_count > $vmhost_cpu_limit) {
			notify($ERRORS{'WARNING'}, 0, "$image_name image minimum CPU value ($total_core_count) is greater than the VM CPU limit for the VM host ($vmhost_cpu_limit), reducing to $vmhost_cpu_limit");
			$total_core_count = $vmhost_cpu_limit;
		}
		
		# Check if the image.minprocnumber is greater than the number of physical cores the VM host has
		# VMs can't be configured with more CPUs than the host has cores
		my $vmhost_cpu_core_count = $self->api->get_cpu_core_count();
		if ($vmhost_cpu_core_count && $total_core_count > $vmhost_cpu_core_count) {
			notify($ERRORS{'WARNING'}, 0, "$image_name image minimum CPU value ($total_core_count) is greater than the VM host's physical CPU cores ($vmhost_cpu_core_count), reducing to $vmhost_cpu_core_count");
			$total_core_count = $vmhost_cpu_core_count;
		}
		
		# Check if the VM guest OS has a socket limit and if image.minprocnumber is greater than this limit
		# This is defined as %VM_OS_CONFIGURATION{cpu_socket_limit}
		# Attempt to determine a valid multicore configuration
		my $vm_os_cpu_socket_limit = $self->get_vm_cpu_socket_limit();
		if ($vm_os_cpu_socket_limit && $total_core_count > $vm_os_cpu_socket_limit) {
			notify($ERRORS{'DEBUG'}, 0, "'$image_os_prettyname' image OS CPU socket limit: $vm_os_cpu_socket_limit, CPU count configured for image: $total_core_count, VM will be configured with multicore CPUs");
			
			# Loop through multicore configurations attempting to determine a valid one
			for ($cores_per_socket = 2; $cores_per_socket <= $total_core_count; $cores_per_socket++) {
				$socket_count = ($total_core_count / $cores_per_socket);
				
				# Check if the socket count result is a whole number
				if ($socket_count !~ /^\d+$/) {
					notify($ERRORS{'DEBUG'}, 0, "multicore configuration not valid, fractional socket count:\nOS CPU socket limit: $vm_os_cpu_socket_limit\ntotal core count: $total_core_count\ncores per CPU: $cores_per_socket\nfractional socket count: $socket_count");
					undef $socket_count;
				}
				elsif ($socket_count > $vm_os_cpu_socket_limit) {
					notify($ERRORS{'DEBUG'}, 0, "multicore configuration not valid, socket count ($socket_count) > OS socket limit ($vm_os_cpu_socket_limit):\nOS CPU socket limit: $vm_os_cpu_socket_limit\ntotal core count: $total_core_count\ncores per CPU: $cores_per_socket\ninvalid socket count: $socket_count");
					undef $socket_count;
				}
				else {
					last;
				}
			}
			
			if (!$socket_count) {
				notify($ERRORS{'WARNING'}, 0, "unable to determine valid multicore CPU configuration:\nOS CPU socket limit: $vm_os_cpu_socket_limit\ntotal core count: $total_core_count\n");
				return;
			}
		}
		else {
			# No OS socket limit defined, assign single-core CPUs
			$socket_count = $total_core_count;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VM CPU configuration:\nsockets: $socket_count\ncores per socket: $cores_per_socket\ntotal cores: $total_core_count");
	if (wantarray) {
		return ($total_core_count, $cores_per_socket);
	}
	else {
		return $total_core_count;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_cpu_limit

 Parameters  : none
 Returns     : integer
 Description : Retrieves the maximum number of vCPUs which may be assigned to
               the VM based on the vsmp license feature used on the host. If
               this cannot be determined, undefined is returned.

=cut

sub get_vm_cpu_limit {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if ($self->api->can('get_license_info')) {
		my $license_info = $self->api->get_license_info();
		if (!$license_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve VM host license information");
			return;
		}
		
		# Get the vsmp feature from the license info
		# There should be a key under $license_info->{properties}{feature} that looks like:
		#    "vsmp:32" => "Up to 32-way virtual SMP"
		#    "vsmp:4" => "Up to 4-way virtual SMP"
		my ($vsmp_value) = map { ($_) =~ /^vsmp:(\d+)/ } keys %{$license_info->{properties}{feature}};
		
		if ($vsmp_value) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved VM CPU limit from host license information: $vsmp_value");
			return $vsmp_value;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to retrieve VM CPU limit from host license information");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve VM host license information");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 find_datastore_files

 Parameters  : $base_directory_path, $pattern
 Returns     : array
 Description : Calls the VM host OS module's find_files subroutine and prunes
               files found in directories known to cause problems. Currently,
               the only files pruned are ones which have a parent directory
               named .snapshot.

=cut

sub find_datastore_files {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($base_directory_path, $pattern) = @_;
	if (!defined($base_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "base directory path argument was not supplied");
		return;
	}
	elsif (!defined($pattern)) {
		notify($ERRORS{'WARNING'}, 0, "file name pattern argument was not supplied");
		return;
	}
	
	# Use the VM host's OS module to find files
	my @file_paths = $self->vmhost_os->find_files($base_directory_path, $pattern);
	
	my @file_paths_pruned;
	for my $file_path (@file_paths) {
		# Prune any file path with an intermediate directory beginning with a period
		# This is to prevent Netapp (and possibly other) snapshot directory files from being included
		if ($file_path =~ /\/(\.snapshot)\//g) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring files under parent directory '$1': $file_path");
			next;
		}
		push @file_paths_pruned, $file_path;
	}
	
	return @file_paths_pruned;
}

#//////////////////////////////////////////////////////////////////////////////

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
	my @found_vmx_paths = $self->find_datastore_files($vmx_base_directory_path, "*.vmx");
	#notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@found_vmx_paths) . " vmx files under $vmx_base_directory_path\n" . join("\n", sort @found_vmx_paths));
	
	# Get a list of the registered VMs in case a VM is registered and the vmx file does not reside under the normal vmx base directory
	my @registered_vmx_paths = $self->api->get_registered_vms();
	#notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@registered_vmx_paths) . " registered vmx files\n" . join("\n", sort @registered_vmx_paths));
	
	my %vmx_file_paths = map { $_ => 1 } (@found_vmx_paths, @registered_vmx_paths);
	my @all_vmx_paths = sort keys %vmx_file_paths;
	
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@all_vmx_paths) . " vmx files on VM host\n" . join("\n", @all_vmx_paths));
	
	return @all_vmx_paths;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmx_info

 Parameters  : $vmx_file_path, $vmx_resides_on_management_node (optional)
 Returns     : hash
 Description : Reads the contents of the vmx file indicated by the
               $vmx_file_path argument and returns a hash containing the info:
               Example:
               |--{computer_id} = '2008'
               |--{displayname} = 'vm-ark-mcnc-9'
               |--{ethernet0.address} = '00:50:56:03:54:11'
               |--{ethernet0.addresstype} = 'static'
               |--{ethernet0.virtualdev} = 'e1000'
               |--{ethernet0.vnet} = 'Private'
               |--{guestos} = 'winserver2008enterprise-32'
               |--{scsi0.present} = 'TRUE'
               |--{scsi0.virtualdev} = 'lsiLogic'
               |--{scsi0:0.devicetype} = 'scsi-hardDisk'
               |--{scsi0:0.filename} = '/vmfs/volumes/nfs-datastore/vmwarewin2008-enterprisex86_641635-v0/vmwarewin2008-enterprisex86_641635-v0.vmdk'
               |--{scsi0:0.mode} = 'persistent'
               |--{scsi0:0.present} = 'TRUE'
               |--{virtualhw.version} = '4'
               |--{vmx_directory_path} = '/vmfs/volumes/nfs-vmpath/vm-ark-mcnc-9_1635-v0'
               |--{vmx_file_name} = 'vm-ark-mcnc-9_1635-v0.vmx'
                  |--{vmdk}{scsi0:0}{devicetype} = 'scsi-hardDisk'
                  |--{vmdk}{scsi0:0}{mode} = 'persistent'
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
	
	my $vmx_resides_on_management_node = shift;
	
	# Return previously retrieved data if defined
	if ($self->{vmx_info}{$vmx_file_path}) {
		notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved info from vmx file: $vmx_file_path");
		return $self->{vmx_info}{$vmx_file_path};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve info from vmx file: $vmx_file_path");
	
	my %vmx_info;
	
	my @vmx_file_contents;
	if ($vmx_resides_on_management_node) {
		@vmx_file_contents = $self->mn_os->get_file_contents($vmx_file_path);
	}
	else {
		@vmx_file_contents = $self->vmhost_os->get_file_contents($vmx_file_path);
	}
	
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
	$vmx_info{vmx_file_name} = $self->_get_file_name($vmx_file_path);
	$vmx_info{vmx_directory_path} = $self->_get_parent_directory_normal_path($vmx_file_path);
	
	
	# Check if the computer_id value exists in the vmx file
	# If not, try to determine it
	if (!defined($vmx_info{computer_id})) {
		notify($ERRORS{'DEBUG'}, 0, "vmx file does not contain a computer_id value, attempting to determine matching computer");
		
		my $computer_name = $self->_get_file_path_computer_name($vmx_file_path);
		if ($computer_name) {
			my @computer_ids = get_computer_ids($computer_name);
			if ((scalar(@computer_ids) == 1)) {
				$vmx_info{computer_id} = $computer_ids[0];
				notify($ERRORS{'DEBUG'}, 0, "determined ID of computer '$computer_name' belonging to vmx file '$vmx_file_path': $vmx_info{computer_id}");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "unable to determine ID of computer '$computer_name' belonging to vmx file '$vmx_file_path'");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to determine computer name from vmx file path: '$vmx_file_path'");
		}
	}
	
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
			notify($ERRORS{'DEBUG'}, 0, "ignoring $storage_identifier, filename property does not end with .vmdk: $vmdk_file_path\n" . format_data($vmx_info{vmdk}{$storage_identifier}));
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
			$vmx_info{vmdk}{$storage_identifier}{filename} = "$vmx_info{vmx_directory_path}\/$vmdk_file_path";
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
		$vmx_info{vmdk}{$storage_identifier}{vmdk_file_name} = $self->_get_file_name($vmdk_file_path);
		$vmx_info{vmdk}{$storage_identifier}{vmdk_file_base_name} = $self->_get_file_base_name($vmdk_file_path);
	}
	
	# Store the vmx file info so it doesn't have to be retrieved again
	$self->{vmx_info}{$vmx_file_path} = \%vmx_info;
	return $self->{vmx_info}{$vmx_file_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reference_vmx_info

 Parameters  : none
 Returns     : hash reference
 Description : Checks if the reference vmx file exists for the image and returns
               a hash reference containing the data contained in the file. This
               data is the configuration used when the image was captured.

=cut

sub get_reference_vmx_info {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if it was already determined that the reference vmx file doesn't exist
	# $self->{reference_vmx_info} is set to 0 if the file doesn't exist
	if (defined($self->{reference_vmx_info})) {
		return $self->{reference_vmx_info};
	}
	
	my $vmdk_directory_path_shared = $self->get_vmdk_directory_path_shared();
	if (!$vmdk_directory_path_shared) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct reference vmx file path, shared vmdk directory path could not be determined");
		return;
	}
	
	my $reference_vmx_file_name = $self->get_reference_vmx_file_name();
	if (!$reference_vmx_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to construct reference vmx file path, reference vmx file name could not be determined");
		return;
	}
	
	# Check if reference vmx file exists on the host or management node
	# Retrieve the info from the file
	my $reference_vmx_file_path = "$vmdk_directory_path_shared/$reference_vmx_file_name";
	my $reference_vmx_info;
	
	if ($self->vmhost_os->file_exists($reference_vmx_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "found reference vmx file in shared vmdk directory on VM host: $reference_vmx_file_path");
		$reference_vmx_info = $self->get_vmx_info($reference_vmx_file_path);
	}
	else {
		my $repository_vmdk_directory_path = $self->get_repository_vmdk_directory_path();
		if (!$repository_vmdk_directory_path) {
			notify($ERRORS{'DEBUG'}, 0, "unable to locate reference vmx file, it does NOT exist in shared vmdk directory on VM host and repository path is not configured");
			$self->{reference_vmx_info} = 0;
			return $self->{reference_vmx_info};
		}
		
		notify($ERRORS{'DEBUG'}, 0, "reference vmx file does NOT exist in shared vmdk directory on VM host, checking repository");
		$reference_vmx_file_path = "$repository_vmdk_directory_path/$reference_vmx_file_name";
		
		if ($self->is_repository_mounted_on_vmhost() && $self->vmhost_os->file_exists($reference_vmx_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "found reference vmx file in repository directory on VM host: $reference_vmx_file_path");
			$reference_vmx_info = $self->get_vmx_info($reference_vmx_file_path);
		}
		elsif ($self->mn_os->file_exists($reference_vmx_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "found reference vmx file in repository on management node: $reference_vmx_file_path");
			# Pass argument to get_vmx_info indicating file resides on managment node
			$reference_vmx_info = $self->get_vmx_info($reference_vmx_file_path, 1);
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "reference vmx file does NOT exist in repository on management node: $reference_vmx_file_path");
			$self->{reference_vmx_info} = 0;
			return $self->{reference_vmx_info};
		}
	}
	
	# Check if the info was successfully retrieved
	if ($reference_vmx_info) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved reference vmx info from file: $reference_vmx_file_path");
		$self->{reference_vmx_info} = $reference_vmx_info;
		return $self->{reference_vmx_info};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve reference vmx info from file: $reference_vmx_file_path");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $vmx_file_base_name = $self->_get_file_base_name($vmx_file_path);
	my $vmx_directory_path = $self->_get_parent_directory_normal_path($vmx_file_path);
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete VM: $vmx_file_path");
	
	
	my $vmx_info;
	if ($self->vmhost_os->file_exists($vmx_file_path)) {
		$vmx_info = $self->get_vmx_info($vmx_file_path);
	}
	
	my @virtual_disks;
	if ($self->is_vm_registered($vmx_file_path)) {
		# The VM needs to be registered for get_vm_virtual_disk_file_paths to work
		@virtual_disks = $self->api->get_vm_virtual_disk_file_paths($vmx_file_path);
		
		if (!$self->api->vm_unregister($vmx_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to unregister VM: $vmx_file_path, VM not deleted");
			return;
		}
	}
	
	delete $self->{vmx_info}{$vmx_file_path};
	my $deleted_directories = {};
	
	# Delete the vmx directory
	my $attempt = 0;
	my $attempt_limit = 5;
	DELETE_VMX_ATTEMPT: while ($attempt++ < $attempt_limit) {
		if ($attempt > 1) {
			notify($ERRORS{'DEBUG'}, 0, "sleeping for 3 seconds before making next attempt to delete vmx directory");
			sleep 3;
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: attempting to delete vmx directory: $vmx_directory_path");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempting to delete vmx directory: $vmx_directory_path");
		}
		
		if ($self->vmhost_os->delete_file($vmx_directory_path)) {
			notify($ERRORS{'DEBUG'}, 0, "deleted vmx directory: $vmx_directory_path");
			$deleted_directories->{$vmx_directory_path} = 1;
			last DELETE_VMX_ATTEMPT;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to delete vmx directory: $vmx_directory_path");
			if ($attempt == $attempt_limit) {
				return;
			}
		}
	}
	
	my $vmdk_file_paths = {};
	for my $virtual_disk_array_ref (@virtual_disks) {
		for my $vmdk_file_path (@$virtual_disk_array_ref) {
			$vmdk_file_paths->{$self->_get_normal_path($vmdk_file_path)} = 1;
		}
	}
	for my $controller (keys %{$vmx_info->{vmdk}}) {
		my $vmdk_file_path = $vmx_info->{vmdk}{$controller}{vmdk_file_path} || next;
		$vmdk_file_paths->{$self->_get_normal_path($vmdk_file_path)} = 1;
	}
	
	for my $vmdk_file_path (keys %$vmdk_file_paths) {
		my $vmdk_directory_path = $self->_get_parent_directory_normal_path($vmdk_file_path) || next;
		if ($deleted_directories->{$vmdk_directory_path}) {
			notify($ERRORS{'DEBUG'}, 0, "directory containing vmdk file was already deleted: $vmdk_file_path");
			next;
		}
		
		# Check if the directory containing the vmdk is shared among different VMs or dedicated to the VM being deleted
		my $vmdk_directory_shared = $self->is_vmdk_directory_shared($vmdk_directory_path);
		if (!defined($vmdk_directory_shared)) {
			notify($ERRORS{'DEBUG'}, 0, "vmdk directory will NOT be deleted, unable to determine if vmdk directory is shared: $vmdk_directory_path");
			next;
		}
		elsif ($vmdk_directory_shared) {
			notify($ERRORS{'DEBUG'}, 0, "vmdk directory will NOT be deleted because it may be shared with other VMs: $vmdk_directory_path");
			next;
		}
		
		if ($self->vmhost_os->delete_file($vmdk_directory_path)) {
			notify($ERRORS{'OK'}, 0, "directory containing vmdk file deleted: $vmdk_file_path");
			$deleted_directories->{$vmdk_directory_path} = 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to delete directory containing vmdk file: $vmdk_file_path");
		}
	}
	
	# TODO: delete orphaned directories named after the VM
	
	notify($ERRORS{'OK'}, 0, "deleted VM: $vmx_file_path");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Return the value stored in this object if it has previously been retrieved
	return $self->{additional_vmdk_bytes_required} if defined($self->{additional_vmdk_bytes_required});
	
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
	
	# Store the value in this object so it doesn't have to be retrieved again
	$self->{additional_vmdk_bytes_required} = $additional_bytes_required;
	return $self->{additional_vmdk_bytes_required};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_additional_vmx_bytes_required

 Parameters  : none
 Returns     : integer
 Description : Checks if additional space is required for the files that will be
               stored in the VM's vmx directory before a VM is loaded. Space is
               required for the VM's vmem file. This is calculated by retrieving
               the RAM setting for the VM. Space is required for REDO files if
               the virtual disk is shared. This is estimated to be 1/4
               the disk size.

=cut

sub get_vm_additional_vmx_bytes_required {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Return the value stored in this object if it has previously been retrieved
	return $self->{additional_vmx_bytes_required} if defined($self->{additional_vmx_bytes_required});
	
	my $additional_bytes_required = 0;
	
	# Add the amount of RAM assigned to the VM to the bytes required for the vmem file
	my $vm_ram_mb = $self->get_vm_ram() || return;
	my $vm_ram_bytes = ($vm_ram_mb * 1024 * 1024);
	$additional_bytes_required += $vm_ram_bytes;
	notify($ERRORS{'DEBUG'}, 0, "$vm_ram_bytes additional bytes required for VM vmem file");
	
	# Check if the VM is shared
	# If shared, add bytes for the delta/REDO files
	my $redo_size = 0;
	if ($self->is_vm_dedicated()) {
		notify($ERRORS{'DEBUG'}, 0, "no additional space required for delta/REDO files because VM disk is dedicated");
	}
	else {
		# Estimate that delta/REDO files will grow to 1/4 the image size
		my $image_size_bytes = $self->get_image_size_bytes() || return;
		$redo_size = int($image_size_bytes / 4);
		$additional_bytes_required += $redo_size;
		notify($ERRORS{'DEBUG'}, 0, "$redo_size additional bytes required for delta/REDO files because VM disk mode is shared");
	}
	
	notify($ERRORS{'DEBUG'}, 0, "estimate of additional space required for the vmx directory:\n" .
		"vmem/vswp file: " . get_file_size_info_string($vm_ram_bytes) . "\n" .
		"redo files: " . get_file_size_info_string($redo_size) . "\n" .
		"total: " . get_file_size_info_string($additional_bytes_required)
	);
	
	# Store the value in this object so it doesn't have to be retrieved again
	$self->{additional_vmx_bytes_required} = $additional_bytes_required;
	return $self->{additional_vmx_bytes_required};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_vmdk

 Parameters  : $source_vmdk_file_path, $destination_vmdk_file_path
 Returns     : boolean
 Description : Copies a vmdk. The full paths to the source and destination vmdk
               paths are required.

=cut

sub copy_vmdk {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->vmhost_data->get_computer_short_name();
	my $vmhost_product_name = $self->get_vmhost_product_name();
	
	# Get the arguments
	my ($source_vmdk_file_path, $destination_vmdk_file_path, $destination_virtual_disk_type) = @_;
	if (!$source_vmdk_file_path || !$destination_vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination vmdk file path arguments were not specified");
		return;
	}
	
	# Normalize the file paths
	$source_vmdk_file_path = $self->_get_normal_path($source_vmdk_file_path) || return;
	$destination_vmdk_file_path = $self->_get_normal_path($destination_vmdk_file_path) || return;
	
	my $source_directory_path = $self->_get_parent_directory_normal_path($source_vmdk_file_path) || return;
	my $destination_directory_path = $self->_get_parent_directory_normal_path($destination_vmdk_file_path) || return;
	
	my $source_vmdk_file_base_name = $self->_get_file_base_name($source_vmdk_file_path) || return;
	my $destination_vmdk_file_base_name = $self->_get_file_base_name($destination_vmdk_file_path) || return;
	
	# Construct the source and destination reference vmx file paths
	# The reference vmx file is copied to the vmdk directory if it exists
	my $source_reference_vmx_file_name = $self->get_reference_vmx_file_name($source_vmdk_file_base_name);
	my $source_reference_vmx_file_path = "$source_directory_path/$source_reference_vmx_file_name";
	
	my $destination_reference_vmx_file_name = $self->get_reference_vmx_file_name($destination_vmdk_file_base_name);
	my $destination_reference_vmx_file_path = "$destination_directory_path/$destination_reference_vmx_file_name";
	
	# Set the default virtual disk type if the argument was not specified
	if (!$destination_virtual_disk_type) {
		if ($vmhost_product_name =~ /esx/i) {
			$destination_virtual_disk_type = 'thin';
		}
		else {
			$destination_virtual_disk_type = '2gbsparse';
		}
	}
	
	# Make sure the arguments end with .vmdk
	if ($source_vmdk_file_path !~ /\.vmdk$/i || $destination_vmdk_file_path !~ /\.vmdk$/i) {
		notify($ERRORS{'WARNING'}, 0, "source vmdk file path ($source_vmdk_file_path) and destination vmdk file path ($destination_vmdk_file_path) arguments do not end with .vmdk");
		return;
	}
	
	# Make sure the source vmdk file exists
	if (!$self->vmhost_os->file_exists($source_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "source vmdk file path does not exist on VM host $vmhost_name: $source_vmdk_file_path");
		return;
	}
	
	# Make sure the destination vmdk file doesn't already exist
	if ($self->vmhost_os->file_exists($destination_vmdk_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "destination vmdk file path already exists on VM host $vmhost_name: $destination_vmdk_file_path");
		return;
	}
	
	my $start_time = time;
	my $end_time;
	# Attempt to use the API's copy_virtual_disk subroutine
	if ($self->api->can('copy_virtual_disk')) {
		my $copied_destination_vmdk_file_path = $self->api->copy_virtual_disk($source_vmdk_file_path, $destination_vmdk_file_path, $destination_virtual_disk_type);
		if ($copied_destination_vmdk_file_path) {
			$end_time = time;
			$copied_destination_vmdk_file_path = $self->_get_normal_path($copied_destination_vmdk_file_path);
			if ($copied_destination_vmdk_file_path ne $destination_vmdk_file_path) {
				notify($ERRORS{'DEBUG'}, 0, "copied vmdk using API's copy_virtual_disk subroutine but destination path was changed:\n" .
					"intended destination path: $destination_vmdk_file_path\n" .
					"copied destination path: $copied_destination_vmdk_file_path\n" .
					"attempting to move copied vmdk to intended path"
				);
				
				if ($self->move_vmdk($copied_destination_vmdk_file_path, $destination_vmdk_file_path)) {
					my $copied_destination_directory_path = $self->_get_parent_directory_normal_path($copied_destination_vmdk_file_path);
					$self->vmhost_os->delete_file($copied_destination_directory_path);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to move vmdk which was copied by API's copy_virtual_disk subroutine with a different name to the correct path");
					$self->vmhost_os->delete_file($copied_destination_vmdk_file_path);
					return;
				}
			}
			else {
				notify($ERRORS{'OK'}, 0, "copied vmdk using API's copy_virtual_disk subroutine");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk using API's copy_virtual_disk subroutine");
			return;
		}
	}
	
	# Make sure VM host OS object implements 'execute' before attempting to call utilities
	if (!$end_time && !$self->vmhost_os->can('execute')) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy vmdk on VM host $vmhost_name, unable to copy using API's copy_virtual_disk subroutine and an 'execute' subroutine is not implemented by the VM host OS object");
		return;
	}
	
	if (!$end_time) {
		# If the source disk is 2gb sparse, make sure multiextent is loaded
		my $source_virtual_disk_type = $self->api->get_virtual_disk_type($source_vmdk_file_path);
		if ($source_virtual_disk_type =~ /sparse/i || $destination_virtual_disk_type =~ /sparse/) {
			if (!$self->check_multiextent()) {
				notify($ERRORS{'WARNING'}, 0, "copy will likely fail, multiextent kernel module is disabled on VM host $vmhost_name");
			}
		}
		
		# Create the destination directory
		if (!$self->vmhost_os->create_directory($destination_directory_path)) {
			notify($ERRORS{'WARNING'}, 0, "unable to copy vmdk, destination directory could not be created on VM host $vmhost_name: $destination_directory_path");
			return;
		}
		
		# Try to use vmkfstools
		my $command = "vmkfstools -i \"$source_vmdk_file_path\" \"$destination_vmdk_file_path\" -d $destination_virtual_disk_type";
		notify($ERRORS{'DEBUG'}, 0, "attempting to copy virtual disk using vmkfstools, disk type: $destination_virtual_disk_type:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		
		$start_time = time;
		my ($exit_status, $output) = $self->vmhost_os->execute($command, 1, 7200);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command on VM host: $command");
		}
		elsif (grep(/command not found/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to copy virtual disk using vmkfstools because the command is not available on VM host $vmhost_name");
		}
		elsif (grep(/Enter username/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to copy virtual disk using vmkfstools, the command is not compatible on VM host $vmhost_name");
		}
		elsif (grep(/No space left/, @$output)) {
			# Check if the output indicates there is not enough space to copy the vmdk
			# Output will contain:
			#    Failed to clone disk : No space left on device (1835017).
			notify($ERRORS{'CRITICAL'}, 0, "failed to copy virtual disk, no space is left on the destination device on VM host $vmhost_name: '$destination_directory_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
			return;
		}
		elsif (grep(/needs.*repair/i, @$output)) {
			# The source disk needs to be repaired. Try option -x
			notify($ERRORS{'WARNING'}, 0, "virtual disk needs to be repaired, output:\n" . join("\n", @$output));
			
			my $vdisk_repair_command = "vmkfstools -x repair \"$source_vmdk_file_path\"";
			notify($ERRORS{'DEBUG'}, 0, "attempting to repair virtual disk using vmkfstools: '$source_vmdk_file_path'");
			
			my ($vdisk_repair_exit_status, $vdisk_repair_output) = $self->vmhost_os->execute($vdisk_repair_command, 1, 3600);
			if (!defined($vdisk_repair_output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to run command to repair the virtual disk: '$vdisk_repair_command'");
			}
			elsif (grep(/(successfully repaired|no errors)/i, @$vdisk_repair_output)) {
				notify($ERRORS{'DEBUG'}, 0, "repaired virtual disk using vmkfstools, output:\n" . join("\n", @$vdisk_repair_output));
				
				# Attempt to run the copy command again
				notify($ERRORS{'DEBUG'}, 0, "making a 2nd attempt to copy virtual disk using vmkfstools after the source was repaired:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
				$start_time = time;
				($exit_status, $output) = $self->vmhost_os->execute($command);
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to repair the virtual disk on VM host $vmhost_name, output:\n" . join("\n", @$vdisk_repair_output));
				return;
			}
		}
		elsif (grep(/(failed|warning|error)/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy virtual disk\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		}
		else {
			$end_time = time;
			notify($ERRORS{'OK'}, 0, "copied virtual disk on VM host using vmkfstools, destination disk type: $destination_virtual_disk_type:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		}
	}
	
	if (!$end_time) {
		# Try to use vmware-vdiskmanager
		# Use disk type  = 1 (2GB sparse)
		my $vdisk_command = "vmware-vdiskmanager -r \"$source_vmdk_file_path\" -t 1 \"$destination_vmdk_file_path\"";
		notify($ERRORS{'DEBUG'}, 0, "attempting to copy virtual disk using vmware-vdiskmanager, disk type: 2gbsparse:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		
		$start_time = time;
		my ($exit_status, $output) = $self->vmhost_os->execute($vdisk_command, 1, 7200);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command on VM host: $vdisk_command");
		}
		elsif (grep(/command not found/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to copy virtual disk using vmware-vdiskmanager because the command is not available on VM host $vmhost_name");
		}
		else {
			my $partial_chains_error = 0;
			my $delta_vmdk_file_path = $source_vmdk_file_path;
			
			# Check if the following error was displayed:
			# Failed to convert disk: The called function cannot be performed on partial chains. Please open the parent virtual disk (0x500003e83).
			# This occurs on VMware Server 2.0 when attempting to copy a delta vmdk created for a linked-clone VM
			# The workaround is to make a copy of the original master image, change the VM's .vmsd file and the delta .vmdk file to point to the copy, and then remove the snapshots from the VM
			# This effectively merges the delta changes into the copy of the master
			if (grep(/function cannot be performed on partial chains/i, @$output)) {
				$partial_chains_error = 1;
				
				# Find the parentFileNameHint line in the vmdk descriptor file, this desribes which vmdk is the master for the linked clone delta vmdk
				# parentFileNameHint="/var/lib/vmware/Virtual Machines/vmwarewinxp-base234-v28/vmwarewinxp-base234-v28.vmdk"
				
				my @source_vmdk_file_contents = $self->vmhost_os->get_file_contents($source_vmdk_file_path);
				my ($parent_vmdk_file_path) = join("\n", @source_vmdk_file_contents) =~ /parentFileNameHint="([^"]+)"/;
				if ($parent_vmdk_file_path) {
					notify($ERRORS{'DEBUG'}, 0, "retrieved parent file path from source vmdk descriptor file: '$parent_vmdk_file_path'");
					
					# Change $source_vmdk_file_path to the path of the original master vmdk, a copy of this will be created
					# Use $source_vmdk_file_path rather than a new variable name so that the repair code below doesn't need to be changed
					$source_vmdk_file_path = $parent_vmdk_file_path;
					
					$vdisk_command = "vmware-vdiskmanager -r \"$source_vmdk_file_path\" -t 1 \"$destination_vmdk_file_path\"";
					notify($ERRORS{'DEBUG'}, 0, "attempting to copy parent virtual disk using vmware-vdiskmanager, disk type: 2gbsparse:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
					
					$start_time = time;
					($exit_status, $output) = $self->vmhost_os->execute($vdisk_command, 1, 7200);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy virtual disk, unable to retrieve parent file path from source vmdk descriptor file contents:\n" . join("\n", @source_vmdk_file_contents));
				}
			}
			
			# Check if virtual disk needs to be repaired, vmware-vdisk manager may display the following:
			# Failed to convert diskCreating disk '<path>'
			# The specified virtual disk needs repair (0xe00003e86).
			if (grep(/needs repair/i, @$output)) {
				notify($ERRORS{'WARNING'}, 0, "virtual disk needs to be repaired, output:\n" . join("\n", @$output));
				
				my $vdisk_repair_command = "vmware-vdiskmanager -R \"$source_vmdk_file_path\"";
				notify($ERRORS{'DEBUG'}, 0, "attempting to repair virtual disk using vmware-vdiskmanager: '$source_vmdk_file_path'");
				
				my ($vdisk_repair_exit_status, $vdisk_repair_output) = $self->vmhost_os->execute($vdisk_repair_command, 1, 3600);
				if (!defined($vdisk_repair_output)) {
					notify($ERRORS{'WARNING'}, 0, "failed to run command to repair the virtual disk: '$vdisk_repair_command'");
				}
				
				elsif (grep(/(has been successfully repaired|no errors)/i, @$vdisk_repair_output)) {
					notify($ERRORS{'DEBUG'}, 0, "repaired virtual disk using vmware-vdiskmanage, output:\n" . join("\n", @$vdisk_repair_output));
					
					# Attempt to run the vmware-vdiskmanager copy command again
					notify($ERRORS{'DEBUG'}, 0, "making a 2nd attempt to copy virtual disk using vmware-vdiskmanager after the source was repaired, disk type: 2gbsparse:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
					$start_time = time;
					($exit_status, $output) = $self->vmhost_os->execute($vdisk_command, 1, 7200);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to repair the virtual disk on VM host $vmhost_name, output:\n" . join("\n", @$vdisk_repair_output));
				}
			}
			
			if (!defined($output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to run command on VM host $vmhost_name: $vdisk_command");
			}
			elsif (grep(/disk is full/i, @$output)) {
				# vmware-vdiskmgr output if not enough space is available:
				#    Failed to convert disk: An error occurred while writing a file; the disk is full. Data has not been saved. Free some space and try again (0xa00800000008).
				notify($ERRORS{'CRITICAL'}, 0, "failed to copy virtual disk on VM host $vmhost_name, no space is left on the destination device: '$destination_directory_path'\ncommand: '$vdisk_command'\noutput:\n" . join("\n", @$output));
				return;
			}
			elsif (!grep(/(100\% done|success)/, @$output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to copy virtual disk on VM host $vmhost_name, output does not contain '100% done' or 'success', command: '$vdisk_command', output:\n" . join("\n", @$output));
			}
			elsif ($partial_chains_error) {
				# Had to make a copy of the original master vmdk earlier, not the desired source vmdk
				# Still need to merge the delta vmdk into this copy
				$end_time = time;
				
				# Determine the .vmsd file path
				my $vmx_file_path = $self->get_vmx_file_path();
				(my $vmsd_file_path = $vmx_file_path) =~ s/\.vmx$/\.vmsd/;
				
				# Escape the strings which will be found/replaced in the files
				(my $source_vmdk_file_path_escaped = $source_vmdk_file_path) =~ s/\//\\\//g;
				(my $destination_vmdk_file_path_escaped = $destination_vmdk_file_path) =~ s/\//\\\//g;
				
				# Modify the .vmsd and delta .vmdk files
				# Change them to point to the copy of the original base image vmdk instead of the original master vmdk
				for my $replace_file_path ($vmsd_file_path, $delta_vmdk_file_path) {
					my $sed_command = "sed -i -e \"s/$source_vmdk_file_path_escaped/$destination_vmdk_file_path_escaped/\" \"$replace_file_path\"";
					my ($sed_exit_status, $sed_output) = $self->vmhost_os->execute($sed_command);
					if (!defined($sed_output)) {
						notify($ERRORS{'WARNING'}, 0, "failed to execute command to replace original vmdk file path with copied vmdk file path in $replace_file_path");
						undef $end_time;
						last;
					}
					elsif (grep(/sed: /, @$sed_output)) {
						notify($ERRORS{'WARNING'}, 0, "failed to replace original vmdk file path with copied vmdk file path in '$replace_file_path'\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'\ncommand: '$sed_command'\noutput:\n" . join("\n", @$sed_output));
						undef $end_time;
						last;
					}
					else {
						notify($ERRORS{'DEBUG'}, 0, "replaced original vmdk file path with copied vmdk file path in '$replace_file_path'\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'\ncommand: '$sed_command'\noutput:\n" . join("\n", @$sed_output));
					}
				}
				
				# Remove the VM's snapshots, this merges the delta vmdk into the copy of the original master vmdk
				if ($end_time) {
					if ($self->api->remove_snapshots($vmx_file_path)) {
						notify($ERRORS{'DEBUG'}, 0, "removed snapshots from VM, the merged delta vmdk '$delta_vmdk_file_path' with destination vmdk '$destination_vmdk_file_path'");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to remove snapshots from VM, delta vmdk '$delta_vmdk_file_path' was NOT merged with destination vmdk '$destination_vmdk_file_path'");
						return;
					}
				}
			}
			else {
				notify($ERRORS{'OK'}, 0, "copied virtual disk on VM host $vmhost_name using vmware-vdiskmanager:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
				$end_time = time;
			}
		}
	}
	
	# Check if any of the methods was successful
	if (!$end_time) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy virtual disk on VM host $vmhost_name using any available methods:\n'$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		
		# Delete the destination directory
		if ($self->_get_datastore_path($destination_directory_path) =~ /^\[.+\]$/) {
			notify($ERRORS{'WARNING'}, 0, "destination directory not deleted, it is the root of a datastore: $destination_directory_path");
		}
		elsif (!$self->vmhost_os->delete_file($destination_directory_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete destination directory after failing to copy virtual disk on VM host $vmhost_name: $destination_directory_path");
		}
		return;
	}
	
	# Calculate how long it took to copy
	# It's possible the copy took less than 1 second (experienced this with VAAI-enabled datastore)
	# If 0 seconds, set it to 1 second to avoid divide by 0 errors later on
	my $duration_seconds = ($end_time - $start_time) || 1;
	my $minutes = ($duration_seconds / 60);
	$minutes =~ s/\..*//g;
	my $seconds = ($duration_seconds - ($minutes * 60));
	if (length($seconds) == 0) {
		$seconds = "00";
	}
	elsif (length($seconds) == 1) {
		$seconds = "0$seconds";
	}
	
	# Check if the reference vmx file exists in the source directory
	# Copy it to the destination directory if it does exist
	if ($self->vmhost_os->file_exists($source_reference_vmx_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "copying reference vmx file to vmdk directory: '$source_reference_vmx_file_path' --> '$destination_reference_vmx_file_path'");
		if (!$self->vmhost_os->copy_file($source_reference_vmx_file_path, $destination_reference_vmx_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy reference vmx file to vmdk directory: '$source_reference_vmx_file_path' --> '$destination_reference_vmx_file_path'");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "reference vmx file not copied to vmdk directory because it does not exist: '$source_reference_vmx_file_path'");
	}

	# Get the size of the copied vmdk files
	my $search_path = $destination_vmdk_file_path;
	$search_path =~ s/(\.vmdk)$/\*$1/i;
	my $image_size_bytes = $self->vmhost_os->get_file_size($search_path);
	if (!defined($image_size_bytes) || $image_size_bytes !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "copied vmdk on VM host $vmhost_name but failed to retrieve destination file size:\nsource: '$source_vmdk_file_path'\ndestination: '$destination_vmdk_file_path'");
		return 1;
	}
	
	my $image_size_bits = ($image_size_bytes * 8);

	my $image_size_kb = ($image_size_bytes / 1024);
	my $image_size_mb = ($image_size_bytes / 1024 / 1024);
	my $image_size_gb = ($image_size_bytes / 1024 / 1024 / 1024);
	
	my $image_size_kbit = ($image_size_bits / 1024);
	my $image_size_mbit = ($image_size_bits / 1024 / 1024);
	my $image_size_gbit = ($image_size_bits / 1024 / 1024 / 1024);
	
	my $bytes_per_second = ($image_size_bytes / $duration_seconds);
	my $kb_per_second = ($image_size_kb / $duration_seconds);
	my $mb_per_second = ($image_size_mb / $duration_seconds);
	my $gb_per_second = ($image_size_gb / $duration_seconds);
	
	my $bits_per_second = ($image_size_bits / $duration_seconds);
	my $kbit_per_second = ($image_size_kbit / $duration_seconds);
	my $mbit_per_second = ($image_size_mbit / $duration_seconds);
	my $gbit_per_second = ($image_size_gbit / $duration_seconds);
	
	my $bytes_per_minute = ($image_size_bytes / $duration_seconds * 60);
	my $kb_per_minute = ($image_size_kb / $duration_seconds * 60);
	my $mb_per_minute = ($image_size_mb / $duration_seconds * 60);
	my $gb_per_minute = ($image_size_gb / $duration_seconds * 60);
	
	
	notify($ERRORS{'OK'}, 0, "copied vmdk on VM host $vmhost_name:\n" .
		"source: '$source_vmdk_file_path'\n" .
		"destination: '$destination_vmdk_file_path'\n" .
		"time to copy: $minutes:$seconds (" . format_number($duration_seconds) . " seconds)\n" .
		"---\n" .
		"bits copied:  " . format_number($image_size_bits) . " ($image_size_bits)\n" .
		"bytes copied: " . format_number($image_size_bytes) . " ($image_size_bytes)\n" .
		"MB copied:    " . format_number($image_size_mb, 1) . "\n" .
		"GB copied:    " . format_number($image_size_gb, 2) . "\n" .
		"---\n" .
		"B/m:    " . format_number($bytes_per_minute) . "\n" .
		"MB/m:   " . format_number($mb_per_minute, 1) . "\n" .
		"GB/m:   " . format_number($gb_per_minute, 2) . "\n" .
		"---\n" .
		"B/s:    " . format_number($bytes_per_second) . "\n" .
		"MB/s:   " . format_number($mb_per_second, 1) . "\n" .
		"GB/s:   " . format_number($gb_per_second, 2) . "\n" .
		"---\n" .
		"Mbit/s: " . format_number($mbit_per_second, 1) . "\n" .
		"Gbit/s: " . format_number($gbit_per_second, 2)
	);
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 move_vmdk

 Parameters  : $source_vmdk_file_path, $destination_vmdk_file_path
 Returns     : boolean
 Description : Moves or renames a vmdk. The full paths to the source and
               destination vmdk paths are required.

=cut

sub move_vmdk {
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
	
	# Normalize the file paths
	$source_vmdk_file_path = $self->_get_normal_path($source_vmdk_file_path) || return;
	$destination_vmdk_file_path = $self->_get_normal_path($destination_vmdk_file_path) || return;
	
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
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to move vmdk: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
	
	my $source_vmdk_directory_path = $self->_get_parent_directory_normal_path($source_vmdk_file_path);
	
	# Determine the destination vmdk directory path and create the directory
	my $destination_vmdk_directory_path = $self->_get_parent_directory_normal_path($destination_vmdk_file_path);
	if (!$destination_vmdk_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination vmdk directory path from vmdk file path: $destination_vmdk_file_path");
		return;
	}
	$self->vmhost_os->create_directory($destination_vmdk_directory_path) || return;
	
	# Check if the API object has implented a move_virtual_disk subroutine
	if ($self->api->can('move_virtual_disk')) {
		if ($self->api->move_virtual_disk($source_vmdk_file_path, $destination_vmdk_file_path)) {
			notify($ERRORS{'OK'}, 0, "moved vmdk using API's move_virtual_disk subroutine");
			return 1;
		}
	}
	
	# Check if the VM host OS object implements an execute subroutine and attempt to run vmware-vdiskmanager
	if ($self->vmhost_os->can("execute")) {
		# If the source disk is 2gb sparse, make sure multiextent is loaded
		my $source_virtual_disk_type = $self->api->get_virtual_disk_type($source_vmdk_file_path);
		if ($source_virtual_disk_type =~ /sparse/i) {
			$self->check_multiextent();
		}
		
		# Try vmware-vdiskmanager
		notify($ERRORS{'OK'}, 0, "attempting to move vmdk file using vmware-vdiskmanager: $source_vmdk_file_path --> $destination_vmdk_file_path");
		my $vdisk_command = "vmware-vdiskmanager -n \"$source_vmdk_file_path\" \"$destination_vmdk_file_path\"";
		my ($vdisk_exit_status, $vdisk_output) = $self->vmhost_os->execute($vdisk_command, 1, 7200);
		if (!defined($vdisk_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware-vdiskmanager' command on VM host to move vmdk file:\n$vdisk_command");
		}
		elsif (grep(/success/i, @$vdisk_output)) {
			# Check if the source directory still exists and contains files
			my @source_directory_files = $self->find_datastore_files($source_vmdk_directory_path, '*');
			if (@source_directory_files) {
				notify($ERRORS{'DEBUG'}, 0, "source directory will not be deleted, it still contains files: $source_vmdk_directory_path\n" . join("\n", @source_directory_files));
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "source directory is empty, attempting to delete: $source_vmdk_directory_path");
				$self->vmhost_os->delete_file($source_vmdk_directory_path);
			}
			notify($ERRORS{'OK'}, 0, "moved vmdk file by executing 'vmware-vdiskmanager' command on VM host:\ncommand: $vdisk_command\noutput: " . join("\n", @$vdisk_output));
			return 1;
		}
		elsif (grep(/not found/i, @$vdisk_output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to move vmdk using 'vmware-vdiskmanager' because the command is not available on VM host");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmware-vdiskmanager' command on VM host to move vmdk file:\n$vdisk_command\noutput:\n" . join("\n", @$vdisk_output));
		}
		
		# Try vmkfstools
		notify($ERRORS{'DEBUG'}, 0, "attempting to move vmdk file using vmkfstools: $source_vmdk_file_path --> $destination_vmdk_file_path");
		my $vmkfs_command = "vmkfstools -E \"$source_vmdk_file_path\" \"$destination_vmdk_file_path\"";
		my ($vmkfs_exit_status, $vmkfs_output) = $self->vmhost_os->execute($vmkfs_command, 1, 7200);
		
		# There is no output if the command succeeded
		# Check to make sure the source file doesn't exist and the destination file does exist
		if (!defined($vmkfs_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute 'vmkfstools' command on VM host: $vmkfs_command");
		}
		elsif (grep(/command not found/i, @$vmkfs_output)) {
			notify($ERRORS{'DEBUG'}, 0, "unable to move vmdk using 'vmkfstools' because the command is not available on VM host");
		}
		elsif ($self->vmhost_os->file_exists($source_vmdk_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to move vmdk file using vmkfstools, source file still exists: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		}
		elsif (!$self->vmhost_os->file_exists($destination_vmdk_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to move vmdk file using vmkfstools, destination file does not exist: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		}
		else {
			# Check if the source directory still exists and contains files
			my @source_directory_files = $self->find_datastore_files($source_vmdk_directory_path, '*');
			if (@source_directory_files) {
				notify($ERRORS{'DEBUG'}, 0, "source directory will not be deleted, it still contains files: $source_vmdk_directory_path\n" . join("\n", @source_directory_files));
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "source directory is empty, attempting to delete: $source_vmdk_directory_path");
				$self->vmhost_os->delete_file($source_vmdk_directory_path);
			}
			notify($ERRORS{'OK'}, 0, "moved vmdk file using vmkfstools: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
			return 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to execute 'vmware-vdiskmanager' or 'vmkfstools' on VM host because 'execute' subroutine has not been implemented by the VM host OS: " . ref($self->vmhost_os));
	}
	
	# Unable to move vmdk file using any VMware utilities or APIs
	# Attempt to manually move the files
	
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
	my @source_vmdk_file_paths = $self->find_datastore_files($source_vmdk_directory_path, "$source_vmdk_file_prefix*.vmdk");
	if (@source_vmdk_file_paths) {
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@source_vmdk_file_paths) . " source vmdk file paths:\n" . join("\n", sort @source_vmdk_file_paths));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to find source vmdk file paths, source vmdk directory: $source_vmdk_directory_path, source vmdk file pattern: $source_vmdk_file_prefix*.vmdk");
		return;
	}
	
	# Loop through the source vmdk paths, figure out the destination file path, move the file
	my %moved_file_paths;
	my $move_error_occurred = 0;
	for my $source_vmdk_copy_path (@source_vmdk_file_paths) {
		# Determine the extent identifier = "vmwinxp-image-s003.vmdk" --> "s003"
		my ($extent_identifier) = $source_vmdk_copy_path =~ /\/$source_vmdk_file_prefix([^\/]*)\.vmdk$/;
		$extent_identifier = '' if !$extent_identifier;
		
		# Construct the destination vmdk path
		my $destination_vmdk_copy_path = "$destination_vmdk_directory_path/$destination_vmdk_file_prefix$extent_identifier.vmdk";
		
		# Call the VM host OS's move_file subroutine to move the vmdk file
		notify($ERRORS{'DEBUG'}, 0, "attempting to move vmdk file:\n'$source_vmdk_copy_path' --> '$destination_vmdk_copy_path'");
		if (!$self->vmhost_os->move_file($source_vmdk_copy_path, $destination_vmdk_copy_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to move vmdk file: '$source_vmdk_copy_path' --> '$destination_vmdk_copy_path'");
			$move_error_occurred = 1;
			last;
		}
		
		# Add the source and destination vmdk file paths to a hash which will be used in case an error occurs and the files need to be reverted back to their original names
		$moved_file_paths{$source_vmdk_copy_path} = $destination_vmdk_copy_path;

		# Delay next move or else VMware may crash - "[2010-05-24 05:59:01.267 'App' 3083897744 error] Caught signal 11"
		sleep 5;
	}
	
	# If multiple vmdk file paths were found, edit the base vmdk file and update the extents
	# Don't do this if a single vmdk file was found because it will be very large and won't contain the extent information
	# This could happen if a virtual disk is in raw format
	if ($move_error_occurred) {
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
					$move_error_occurred = 1;
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to create temp file to store updated vmdk contents which will be copied to the VM host");
				$move_error_occurred = 1;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve vmdk file contents: '$destination_vmdk_file_path'");
			$move_error_occurred = 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk file extents not updated because a single source vmdk file was found");
	}
	
	# Check if an error occurred, revert the file moves if necessary
	if ($move_error_occurred) {
		for my $destination_vmdk_revert_path (sort keys(%moved_file_paths)) {
			my $source_vmdk_revert_path = $moved_file_paths{$destination_vmdk_revert_path};
			
			# Call the VM host OS's move_file subroutine to move the vmdk file back to what it was originally
			notify($ERRORS{'DEBUG'}, 0, "attempting to revert the vmdk file move:\n'$source_vmdk_revert_path' --> '$destination_vmdk_revert_path'");
			if (!$self->vmhost_os->move_file($source_vmdk_revert_path, $destination_vmdk_revert_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to revert the vmdk file move:\n'$source_vmdk_revert_path' --> '$destination_vmdk_revert_path'");
				last;
			}
			sleep 5;
		}
		
		notify($ERRORS{'WARNING'}, 0, "failed to move vmdk using any available methods: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
		return;
	}
	
	# Check if the source directory still exists and contains files
	my @source_directory_files = $self->find_datastore_files($source_vmdk_directory_path, '*');
	if (@source_directory_files) {
		notify($ERRORS{'DEBUG'}, 0, "source directory will not be deleted, it still contains files: $source_vmdk_directory_path\n" . join("\n", @source_directory_files));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "source directory is empty, attempting to delete: $source_vmdk_directory_path");
		$self->vmhost_os->delete_file($source_vmdk_directory_path);
	}
	
	notify($ERRORS{'OK'}, 0, "moved vmdk file: '$source_vmdk_file_path' --> '$destination_vmdk_file_path'");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_multiextent

 Parameters  : none
 Returns     : boolean
 Description : Checks if the multiextent kernel module is loaded on the VM
               host. This is required to operate on 2GB sparse vmdk files. If
               not loaded, an attempt is made to load it.

=cut

sub check_multiextent {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	# Check if ESXi 6.5 or later is used
	# Should be something like: VMware ESXi 6.5.0 build-5310538
	my $product_version = $self->api->get_vmware_product_version();
	if ($product_version) {
		my ($major_version, $minor_version) = $product_version =~ /^(\d+)\.(\d+)/g;
		if (defined($major_version) && defined($minor_version) && (($major_version == 6 && $minor_version >= 5) || ($major_version > 6))) {	
			notify($ERRORS{'DEBUG'}, 0, "VMware version is at least 6.5: $product_version, skipping multiextent check");
			return 1;
		}
	}
	
	if (!$self->vmhost_os->can("execute")) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if multiextent kernel module needs to be loaded, VM host OS object does not implement an 'execute' method: " . ref($self->vmhost_os));
		return;
	}
	
	my $list_command = 'vmkload_mod -l | grep multiextent';
	my ($list_exit_status, $list_output) = $self->vmhost_os->execute($list_command);
	if (!defined($list_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if multiextent kernel module is loaded on $vmhost_hostname");
		return;
	}
	elsif (grep(/^multiextent/, @$list_output)) {
		notify($ERRORS{'DEBUG'}, 0, "multiextent kernel module is loaded on $vmhost_hostname");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "multiextent kernel module is not loaded on $vmhost_hostname, attempting to load it");
	}
	
	my $load_command = 'vmkload_mod multiextent';
	my ($load_exit_status, $load_output) = $self->vmhost_os->execute($load_command);
	if (!defined($load_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to load multiextent kernel module on $vmhost_hostname");
	}
	elsif (grep(/loaded successfully/, @$load_output)) {
		notify($ERRORS{'DEBUG'}, 0, "loaded multiextent kernel module on $vmhost_hostname");
		return 1;
	}
	elsif (grep(/already loaded/, @$load_output)) {
		notify($ERRORS{'DEBUG'}, 0, "multiextent kernel module already loaded on $vmhost_hostname");
		return 1;
	}
	elsif (grep(/not found/i, @$load_output)) {
		# VMKMod_ComputeModPath(multiextent) failed: Not found
		# vmkload_mod: Can not load module multiextent: not found
		notify($ERRORS{'WARNING'}, 0, "multiextent kernel module is not present on $vmhost_hostname\n" . join("\n", @$load_output));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to load multiextent kernel module on $vmhost_hostname, exit status: $load_exit_status, output:\n" . join("\n", @$load_output));
	}
	
	notify($ERRORS{'CRITICAL'}, 0, "multiextent kernel module is disabled on VM host $vmhost_hostname, operations on 2GB sparse virtual disk files will fail\n" .
		'*' x 100 . "\n" .
		"DO THE FOLLOWING TO FIX THIS PROBLEM:\n" .
		"Enable the module by running the following command on each VMware host: 'vmkload_mod -u multiextent'\n" .
		"Add a line containing 'vmkload_mod -u multiextent' to /etc/rc.local.d/local.sh on each ESXi host\n" .
		'*' x 100
	);
	
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : $vmx_file_path (optional)
 Returns     : boolean
 Description : Powers on the VM.

=cut

sub power_on {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	
	# Get the vmx file path
	# Use the argument if one was supplied
	my $vmx_file_path = shift || $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not specified and default vmx file path could not be determined");
		return;
	}
	$vmx_file_path = normalize_file_path($vmx_file_path);
	
	#my $power_on_throttle_delay_seconds = 2;
	#my $power_on_semaphore_id = "$vmhost_name-power-on";
	#my $power_on_semaphore = $self->get_semaphore($power_on_semaphore_id, (60 * 100), (int(rand(10)))) || return;
	
	if ($self->api->vm_power_on($vmx_file_path)) {
		#notify($ERRORS{'OK'}, 0, "powered on $vmx_file_path, sleeping $power_on_throttle_delay_seconds seconds before releasing $power_on_semaphore_id semaphore to throttle VMs being powered on");
		#sleep $power_on_throttle_delay_seconds;
		return 1;
	}
	else {
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : $vmx_file_path (optional)
 Returns     : boolean
 Description : Powers off the VM.

=cut

sub power_off {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
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
	
	return $self->api->vm_power_off($vmx_file_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : $vmx_file_path (optional)
 Returns     : boolean
 Description : Powers the VM off and then on.

=cut

sub power_reset {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
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
	
	# Power off and then power on the VM
	$self->power_off($vmx_file_path);
	return$self->power_on($vmx_file_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : $vmx_file_path (optional)
 Returns     : string
 Description : Returns a string containing the power state of the VM.

=cut

sub power_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
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
	
	return $self->api->get_vm_power_state($vmx_file_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 snapshot

 Parameters  : $snapshot_name (optional)
 Returns     : boolean
 Description : Creates a snapshot of the VM.

=cut

sub snapshot {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path
	my $vmx_file_path = $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path could not be determined");
		return;
	}
	
	my $snapshot_name = shift || ("VCL: " . convert_to_datetime());
	
	# Make sure the API object implements the create_snapshot subroutine
	if (!$self->api->can('create_snapshot')) {
		notify($ERRORS{'WARNING'}, 0, "unable to create snapshot, " . ref($self->api) . " module does not implement a 'create_snapshot' subroutine");
		return;
	}
	
	return $self->api->create_snapshot($vmx_file_path, $snapshot_name);
}


#//////////////////////////////////////////////////////////////////////////////

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
	
	my $vmhost_computer_name = $self->data->get_vmhost_short_name() || return;
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

#//////////////////////////////////////////////////////////////////////////////

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
	my $vmhost_name = $self->data->get_vmhost_short_name();
	
	# Delete the existing VM from the VM host which were created for the VM assigned to the reservation
	if (!$self->remove_existing_vms()) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete existing VMs on VM host $vmhost_name which were created for VM $computer_short_name");
		return;
	}

	# Set the computer current image in the database to 'noimage'
	if (!update_computer_imagename($computer_id, 'noimage')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set computer $computer_short_name current image to 'noimage'");
	}
	
	if (!switch_vmhost_id($computer_id, 'NULL')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmhostid to NULL for VM $computer_short_name");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_repository_mounted_on_vmhost

 Parameters  : none
 Returns     : boolean
 Description : Checks if the image repository specified for the VM host profile
               is mounted on the VM host.

=cut

sub is_repository_mounted_on_vmhost {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->data->get_vmhost_short_name();
	
	my $repository_vmdk_base_directory_path = $self->get_repository_vmdk_base_directory_path();
	if (!$repository_vmdk_base_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "unable to determine if image repository is mounted on VM host $vmhost_name, repository path is not configured in the VM profile");
		return;
	}
	
	if ($self->vmhost_os->file_exists($repository_vmdk_base_directory_path)) {
		notify($ERRORS{'DEBUG'}, 0, "image repository is mounted on VM host $vmhost_name: $repository_vmdk_base_directory_path");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image repository is NOT mounted on VM host $vmhost_name: $repository_vmdk_base_directory_path");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////



#//////////////////////////////////////////////////////////////////////////////

=head2 get_datastore_info

 Parameters  : $refresh_info
 Returns     : hash reference
 Description : 

=cut

sub get_datastore_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the optional argument
	my $refresh_info = shift;
	
	# Return previously retrieved data if it is defined
	# Datastore information shouldn't change much during a reservation
	if (!$refresh_info && $self->{datastore_info}) {
		return $self->{datastore_info};
	}
	
	my $datastore_info = $self->api->_get_datastore_info();
	
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve datastore info from " . ref($self->api) . " API object");
		return;
	}
	
	for my $datastore_name (keys %$datastore_info) {
		# URL may be in the format: 'ds:///vmfs/volumes/51938b70-d1df1a73-459a-3640b58306bb/'
		# Remove the ds:// from the beginning
		if ($datastore_info->{$datastore_name}{url}) {
			$datastore_info->{$datastore_name}{url} =~ s/^.+\/vmfs/\/vmfs/;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "retrieved datastore info from VM host: " . join(", ", sort keys %$datastore_info));
	$self->{datastore_info} = $datastore_info;
	return $datastore_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_names

 Parameters  : none
 Returns     : array
 Description : Returns an array containing the names of the datastores on the VM
               host.

=cut

sub _get_datastore_names {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the datastore information
	my $datastore_info = $self->get_datastore_info();
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve datastore names, unable to retrieve datastore information from the VM host");
		return;
	}
	
	my @datastore_names = sort keys %{$datastore_info};
	notify($ERRORS{'DEBUG'}, 0, "datastore names: " . join(", ", sort @datastore_names));
	
	return @datastore_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_object

 Parameters  : $datastore_name
 Returns     : vSphere SDK datastore object
 Description : Retrieves a datastore object for the datastore specified by the
               datastore name argument.

=cut

sub _get_datastore_object {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the datastore name argument
	my $datastore_name = shift;
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "datastore name argument was not specified");
		return;
	}
	
	# Get the host view
	my $host_view = VIExt::get_host_view(1);
	
	# Get an array containing datastore managed object references
	my @datastore_mo_refs = @{$host_view->datastore};
	
	# Loop through the datastore managed object references
	# Get a datastore view, add the view's summary to the return hash
	my @datastore_names_found;
	for my $datastore_mo_ref (@datastore_mo_refs) {
		my $datastore = Vim::get_view(mo_ref => $datastore_mo_ref);
		return $datastore if ($datastore_name eq $datastore->summary->name);
		push @datastore_names_found, $datastore->summary->name;
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to find datastore named $datastore_name, datastore names found:\n" . join("\n", @datastore_names_found));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_path

 Parameters  : $path
 Returns     : string
 Description : Converts a normal path to a datastore path. The path returned
               will never have any trailing slashes or spaces.
               '/vmfs/volumes/datastore1/folder/file.txt' --> '[datastore1] folder/file.txt'

=cut

sub _get_datastore_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($path_argument);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine datastore path, failed to determine datastore name: $path_argument");
		return;
	}
	
	my $relative_datastore_path = $self->_get_relative_datastore_path($path_argument);
	if (!defined($relative_datastore_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine datastore path, failed to determine relative datastore path: $path_argument");
		return;
	}
	
	if ($relative_datastore_path) {
		return "[$datastore_name] $relative_datastore_path";
	}
	else {
		return "[$datastore_name]";
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_root_normal_path

 Parameters  : $path
 Returns     : string
 Description : Parses the path argument and determines its datastore root path
               in normal form.
               '/vmfs/volumes/datastore1/folder/file.txt' --> '/vmfs/volumes/datastore1'
               '[datastore1] folder/file.txt' --> '/vmfs/volumes/datastore1'

=cut

sub _get_datastore_root_normal_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($path);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root normal path, unable to determine datastore name: $path");
		return;
	}
	
	# Get the datastore information
	my $datastore_info = $self->get_datastore_info();
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root normal path, unable to retrieve datastore information");
		return;
	}
	
	return $datastore_info->{$datastore_name}{normal_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_root_url_path

 Parameters  : $path
 Returns     : string
 Description : Parses the path argument and determines its datastore root path
               in normal form.
               '/vmfs/volumes/datastore1/folder/file.txt' --> '/vmfs/volumes/895cdc05-11c0ee8f'
               '[datastore1] folder/file.txt' --> '/vmfs/volumes/895cdc05-11c0ee8f'

=cut

sub _get_datastore_root_url_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($path);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root URL path, unable to determine datastore name: $path");
		return;
	}
	
	# Get the datastore information
	my $datastore_info = $self->get_datastore_info();
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root URL path, unable to retrieve datastore information");
		return;
	}
	
	return $datastore_info->{$datastore_name}{url};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_url

 Parameters  : $path
 Returns     : string
 Description : Parses the path argument and determines its datastore root path
               in normal form.
               '/vmfs/volumes/datastore1/folder/file.txt' --> '895cdc05-11c0ee8f'
               '[datastore1] folder/file.txt' --> '895cdc05-11c0ee8f'

=cut

sub _get_datastore_url {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($path);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root URL, unable to determine datastore name: $path");
		return;
	}
	
	# Get the datastore information
	my $datastore_info = $self->get_datastore_info();
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root URL, unable to retrieve datastore information");
		return;
	}
	if (!$datastore_info->{$datastore_name}{url}) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine datastore root URL, datstore info does not contain a 'url' key:\n" . format_data($datastore_info->{$datastore_name}));
		return;
	}
	
	my $url = $datastore_info->{$datastore_name}{url};
	$url =~ s/.*\/([^\/]+)$/$1/g;
	return $url;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_normal_path

 Parameters  : $path
 Returns     : string
 Description : Converts a datastore path to a normal path. The path returned
               will never have any trailing slashes or spaces.
               '[datastore1] folder/file.txt' --> '/vmfs/volumes/datastore1/folder/file.txt'
               '[datastore1]' --> '/vmfs/volumes/datastore1'

=cut

sub _get_normal_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Check if the path is not on a datastore:
	#   has a slash,                  does not contain [xxx],       is not under /vmfs/volumes
	if ($path_argument =~ /[\\\/]/ && $path_argument !~ /\[.+\]/ && $path_argument !~ /\/vmfs\/volumes\//i) {
		return normalize_file_path($path_argument);
	}
	
	my $datastore_root_normal_path = $self->_get_datastore_root_normal_path($path_argument);
	if (!$datastore_root_normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine normal path, failed to determine datastore root normal path: $path_argument");
		return;
	}
	
	my $relative_datastore_path = $self->_get_relative_datastore_path($path_argument);
	if (!defined($relative_datastore_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine normal path, failed to determine relative datastore path: $path_argument");
		return;
	}
	
	if ($relative_datastore_path) {
		return "$datastore_root_normal_path/$relative_datastore_path";
	}
	else {
		return $datastore_root_normal_path;
	}
	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_url_path

 Parameters  : $path
 Returns     : string
 Description : Converts a path which may contain a normal datastore name to a
               path containing the datastore's URL.
               /vmfs/volumes/mydatastore/mypath --> /vmfs/volumes/52fe7333-0ab121b2-0d96-e41f13ca0f14/mypath
               [mydatastore] mypath --> /vmfs/volumes/52fe7333-0ab121b2-0d96-e41f13ca0f14/mypath

=cut

sub _get_url_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $normal_path = $self->_get_normal_path($path_argument);
	if (!$normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine URL path, normal path could not be determined, returning path argument: '$path_argument'");
		return $path_argument;
	}
	
	my $datastore_url = $self->_get_datastore_url($normal_path);
	if (!$datastore_url) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine URL for datastore of path argument: '$path_argument', returning normal path: '$normal_path'");
		return $normal_path;
	}
	
	my $url_path = $normal_path;
	$url_path =~ s/^(\/vmfs\/volumes\/)[^\/]+(\/|$)/$1$datastore_url$2/;
	
	if ($url_path eq $normal_path) {
		notify($ERRORS{'WARNING'}, 0, "URL path is the same as the normal path: $url_path, conversion from normal path to URL path may have failed, returning normal path:\n" .
			"path argument: $path_argument\n" .
			"normal path: $normal_path\n" .
			"datastore URL: $datastore_url"
		);
		return $normal_path;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "converted path to URL path: '$path_argument' --> '$url_path'");
		return $url_path;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_name

 Parameters  : $path
 Returns     : string
 Description : Returns the datastore name from the path argument.
               '/vmfs/volumes/datastore1/folder/file.txt' --> 'datastore1'
					'[datastore1] folder/file.txt' --> 'datastore1'

=cut

sub _get_datastore_name {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	$path = normalize_file_path($path);
	
	# Get the datastore information
	my $datastore_info = $self->get_datastore_info() || return;
	my @datastore_normal_paths;

	# Loop through the datastores, check if the path begins with the datastore path
	for my $datastore_name (keys(%{$datastore_info})) {
		my $datastore_normal_path = $datastore_info->{$datastore_name}{normal_path};
		if (!$datastore_normal_path) {
			notify($ERRORS{'WARNING'}, 0, "normal path is not defined in the datastore info hash for datastore $datastore_name:" . format_data($datastore_info->{$datastore_name}));
			next;
		}
		$datastore_normal_path = normalize_file_path($datastore_normal_path);
		
		my $datastore_url = $datastore_info->{$datastore_name}{url};
		$datastore_url = normalize_file_path($datastore_url) || '';
		
		if ($path =~ /^($datastore_name|\[$datastore_name\]|$datastore_normal_path|$datastore_url)(\s|\/|$)/) {
			return $datastore_name;
		}
		
		# Path does not begin with datastore path, add datastore path to array for warning message
		push @datastore_normal_paths, ("'[$datastore_name]'", "'$datastore_normal_path'", "'$datastore_url'");
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine datastore name from path: '$path', path does not begin with any of the datastore paths:\n" . join("\n", @datastore_normal_paths));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_parent_directory_normal_path

 Parameters  : $path
 Returns     : string
 Description : Returns the parent directory of the path argument in normal form.
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/*.vmdk' --> '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12'
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/' --> '/vmfs/volumes/nfs datastore'

=cut

sub _get_parent_directory_normal_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# If this is a normal path - remove the part after the last '/'
	if ($path_argument !~ /\[.+\]/) {
		$path_argument =~ s/[^\/]*\/?$//g;
		return $self->_get_normal_path($path_argument);
	}
	
	# Datastore path was passed, call datastore sub and return normal path
	my $parent_directory_datastore_path = $self->_get_parent_directory_datastore_path($path_argument);
	if (!$parent_directory_datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory normal path, parent directory datastore path could not be determined on which the normal path is based: '$path_argument'");
		return;
	}
	
	my $parent_directory_normal_path = $self->_get_normal_path($parent_directory_datastore_path);
	if (!$parent_directory_normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory normal path, parent directory datastore path could not be converted to a normal path: '$parent_directory_datastore_path'");
		return;
	}
	
	return $parent_directory_normal_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_parent_directory_datastore_path

 Parameters  : $path
 Returns     : string
 Description : Returns the parent directory path for the path argument in
               datastore format.
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/*.vmdk ' --> '[nfs datastore] vmwarewinxp-base234-v12'

=cut

sub _get_parent_directory_datastore_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_path = $self->_get_datastore_path($path_argument);
	if (!$datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory datastore path, path argument could not be converted to a datastore path: '$path_argument'");
		return;
	}
	
	if ($datastore_path =~ /^\[.+\]$/) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory datastore path, path argument is the root path of a datastore: '$path_argument'");
		return;
	}
	
	# Remove the last component of the path - after the last '/'
	$datastore_path =~ s/[^\/\]]*$//g;
	
	return normalize_file_path($datastore_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_parent_directory_name

 Parameters  : $path
 Returns     : string
 Description : Returns the parent directory name for the path argument.
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/*.vmdk ' --> 'vmwarewinxp-base234-v12'

=cut

sub _get_parent_directory_name {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_path = $self->_get_datastore_path($path_argument);
	if (!$datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory name, path argument could not be converted to a datastore path: '$path_argument'");
		return;
	}
	
	if ($datastore_path =~ /^\[.+\]$/) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory name, path argument is the root path of a datastore: '$path_argument'");
		return;
	}
	
	my ($parent_directory_name) = $datastore_path =~ /[\s\/]([^\/]+)\/[^\/]+$/g;
	if (!$parent_directory_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine parent directory name from path: '$path_argument' ($datastore_path)");
		return;
	}
	
	return $parent_directory_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_file_name

 Parameters  : $path
 Returns     : string
 Description : Returns the file name or leftmost section of the path argument.
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/*.vmdk ' --> '*.vmdk'

=cut

sub _get_file_name {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_path = $self->_get_datastore_path($path_argument);
	if (!$datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine file name, path argument could not be converted to a datastore path: '$path_argument'");
		return;
	}
	
	if ($datastore_path =~ /^\[.+\]$/) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine file name, path argument is the root path of a datastore: '$path_argument'");
		return;
	}
	
	# Extract the last component of the path - after the last '/'
	my ($file_name) = $datastore_path =~ /([^\/\]]+)$/;
	
	return normalize_file_path($file_name);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_file_base_name

 Parameters  : $path
 Returns     : string
 Description : Returns the file name of the path argument without the file
               extension.
               '/vmfs/volumes/nfs datastore/vmwarewinxp-base234-v12/image_55-v0.vmdk ' --> 'image_55-v0'

=cut

sub _get_file_base_name {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $file_name = $self->_get_file_name($path_argument);
	if (!$file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine file base name, file name could not be determined from path argument: '$path_argument'");
		return;
	}
	
	# Remove the file extension - everything before the first '.' in the file name
	my ($file_base_name) = $file_name =~ /^([^\.]*)/;
	
	return $file_base_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_relative_datastore_path

 Parameters  : $path
 Returns     : string
 Description : Returns the relative datastore path for the path argument.
               '/vmfs/volumes/datastore1/folder/file.txt' --> 'folder/file.txt'
               '[datastore1] folder/file.txt' --> 'folder/file.txt'

=cut

sub _get_relative_datastore_path {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $datastore_name = $self->_get_datastore_name($path_argument);
	if (!$datastore_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine relative datastore path, failed to determine datastore name: $path_argument");
		return;
	}
	
	my $datastore_root_normal_path = $self->_get_datastore_root_normal_path($path_argument);
	if (!$datastore_root_normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine relative datastore path, failed to determine the normal root path for the datastore: $path_argument");
		return;
	}
	
	my $datastore_root_url_path = $self->_get_datastore_root_url_path($path_argument);
	if (!$datastore_root_normal_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine relative datastore path, failed to determine the normal root path for the datastore: $path_argument");
		return;
	}
	
	my ($datastore_path, $relative_datastore_path) = $path_argument =~ /^($datastore_name|\[$datastore_name\]|$datastore_root_normal_path|$datastore_root_url_path)(.*)/;
	
	if (!$datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine relative datastore path: '$path_argument', path argument does not begin with any of the following:\n'$datastore_name'\n'[$datastore_name]'\n'$datastore_root_url_path'\n'$datastore_root_normal_path'");
		return;
	}
	
	$relative_datastore_path = '' if !$relative_datastore_path;
	
	# Remove slashes or spaces from the beginning and end of the relative datastore path
	$relative_datastore_path =~ s/(^[\/\s]*|[\/\s]*$)//g;
	
	return $relative_datastore_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_file_path_computer_name

 Parameters  : $file_path
 Returns     : string
 Description : Attempts to determine the computer name from the path argument.
               Undefined is returned if the computer name cannot be determined.
               '/vmfs/volumes/vmpath/ve1-72_1036-v2/ve1-72_1036-v2.vmx' --> 've1-72'
               '/vmfs/volumes/vmpath/ve1-72_1036-v2' --> 've1-72'

=cut

sub _get_file_path_computer_name {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $computer_name;
	my $regex_pattern = '^([\w\-]+)\_\d+-v\d+([_]|$)';
	
	my $file_name = $self->_get_file_name($path_argument);
	if (!$file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine computer name from path '$path_argument', file name could not be determined from path");
		return;
	}
	
	if ($file_name =~ /\./) {
		my $directory_name = $self->_get_parent_directory_name($path_argument);
		if ($directory_name) {
			($computer_name) = $directory_name =~ /$regex_pattern/;
			if ($computer_name) {
				notify($ERRORS{'DEBUG'}, 0, "determined computer name '$computer_name' from directory name: $directory_name, argument: $path_argument");
				return $computer_name;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "directory name '$directory_name' does not appear to contain a computer name, argument: $path_argument");
			}
		}
	}
	
	($computer_name) = $file_name =~ /$regex_pattern/;
	if ($computer_name) {
		notify($ERRORS{'DEBUG'}, 0, "determined computer name '$computer_name' from file/directory name: $file_name, argument: $path_argument");
		return $computer_name;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computer name could not be determined from path: $path_argument");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _clean_vm_name
 Parameters  : $vm_name
 Returns     : string
 Description : VMWare vCenter supports VM Names of up to 80 characters, but if
               the name is greater than 29 characters, it will truncate the 
               corresponding name and enclosing directory of the virtual disks.

=cut

sub _clean_vm_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_name = shift || return;
	
	# if the length of the name is > 29, then truncate it in such a way that
	# the image name remains unique in the VCL database
	my $MAX_VMNAME_LEN = 29;
	if (length $vm_name > $MAX_VMNAME_LEN) {
		notify($ERRORS{'DEBUG'}, 0, "truncating VM name $vm_name");
		my $newname = "";
		if ($vm_name =~ m/^(\w+)-(\w+?)(\d*)-(v\d+)$/) {
			my $base = $1;
			my $name = $2;
			my $imgid = $3;
			my $version = $4;
			my $shortened = substr($name, 0, $MAX_VMNAME_LEN - 2 - length($imgid) - length($base) - length($version));
			$newname = $base . "-" . $shortened . $imgid . "-" . $version; 
		}
		else {
			my ($pre_len, $post_len) = ($MAX_VMNAME_LEN - 10, 10);
			my ($pre, $post) = $vm_name =~ m/^(.{$pre_len}).*(.{$post_len})$/;
			$newname = $pre . $post;
		}
		if (get_image_info($newname, 0, 1)) {
			notify($ERRORS{'WARNING'}, 0, "Naming conflict: $newname already exists in the database");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "Changed image name to: $newname");
			$vm_name = $newname;
		}
	}
	return $vm_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _check_datastore_paths

 Parameters  : @check_paths (optional)
 Returns     : boolean
 Description : Checks each of the vSphere.pm subroutines which parse a file path
               argument. This subroutine returns false if any subroutine returns
               undefined. The file paths passed to each subroutine that is
               checked may be specified as arguments to _check_datastore_paths.
               If no arguments are specified, several default paths will be
               checked.

=cut

sub _check_datastore_paths {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @check_paths = @_;
	
	# Check to make sure all of the vmdk file path components can be retrieved
	my $undefined_string = "<undefined>";
	
	# Assemble a string of all of the components
	my $check_paths_string = "====================\n";
	
	my @datastore_names = $self->_get_datastore_names();
	if (!@datastore_names) {
		notify($ERRORS{'WARNING'}, 0, "datastore names could not be retrieved");
	}
	$check_paths_string .= "datastore names:\n" . join("\n", @datastore_names) . "\n";
	
	my $datastore_info = $self->get_datastore_info();
	if (!$datastore_info) {
		notify($ERRORS{'WARNING'}, 0, "datastore information could not be retrieved");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "datastore information:\n" . format_data($datastore_info));
	
	my @check_subroutines = (
		'_get_datastore_name',
		'_get_datastore_path',
		'_get_normal_path',
		'_get_datastore_root_normal_path',
		'_get_datastore_root_url_path',
		'_get_parent_directory_datastore_path',
		'_get_parent_directory_normal_path',
		'_get_relative_datastore_path',
		'_get_file_name',
		'_get_file_base_name',
	);
	
	my $max_sub_name_length = max (map { length } @check_subroutines);
	
	if (!@check_paths) {
		#for my $datastore_name (sort keys %$datastore_info) {
		#	my $datastore_normal_path = $datastore_info->{$datastore_name}{normal_path};
		#	my $datastore_url_path = $datastore_info->{$datastore_name}{url};
		#	push @check_paths, (
		#		"[$datastore_name] ",
		#		"[$datastore_name] /",
		#		"[$datastore_name] test/test file.txt ",
		#		"$datastore_normal_path/test dir/test file.txt ",
		#		"$datastore_normal_path/test dir/ ",
		#		"$datastore_url_path/test dir/test file.txt ",
		#		"$datastore_url_path/test dir/ ",
		#		"$datastore_url_path/test.txt ",
		#		"[invalid datastore] file.txt",
		#	);
		#}
		
		my @path_subroutines =  (
			'get_vmx_base_directory_path',
			'get_vmx_directory_path',
			'get_vmx_file_path',
			
			'get_vmdk_base_directory_path',
			
			'get_vmdk_directory_path',
			'get_vmdk_file_path',
			
			'get_vmdk_base_directory_path_shared',
			'get_vmdk_directory_path_shared',
			'get_vmdk_file_path_shared',
			
			'get_vmdk_base_directory_path_dedicated',
			'get_vmdk_directory_path_dedicated',
			'get_vmdk_file_path_dedicated',
			
			'get_repository_vmdk_base_directory_path',
			'get_repository_vmdk_directory_path',
			'get_repository_vmdk_file_path',
		);
		
		$max_sub_name_length = max ($max_sub_name_length, map { length } @path_subroutines);
		
		$check_paths_string .= "----------\n";
		for my $path_subroutine (@path_subroutines) {
			my $path_value = eval "\$self->$path_subroutine()";
			$check_paths_string .= "$path_subroutine: ";
			$check_paths_string .= " " x ($max_sub_name_length - length($path_subroutine));
			$check_paths_string .= "'$path_value'\n";
			push @check_paths, $path_value;
		}
	}
	
	for my $check_path (@check_paths) {
		$check_paths_string .= "----------\n";
		$check_paths_string .= "checking path:";
		$check_paths_string .= " " x ($max_sub_name_length - 12);
		$check_paths_string .= "*$check_path*\n";
		
		for my $check_subroutine (@check_subroutines) {
			my $result = eval "\$self->$check_subroutine(\$check_path)";
			
			$check_paths_string .= "$check_subroutine: ";
			$check_paths_string .= " " x ($max_sub_name_length - length($check_subroutine));
			
			if (defined($result)) {
				$check_paths_string .= "'$result'\n";
			}
			else {
				$check_paths_string .= "$undefined_string\n";
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved datastore path components:\n$check_paths_string");
	
	if ($check_paths_string =~ /$undefined_string/) {
		return;
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 configure_vmhost_dedicated_ssh_key

 Parameters  : none
 Returns     : boolean
 Description : VMware ESXi does not retain the /.ssh or authorized_keys file
               when the host is rebooted by default. This subroutine resolves
               this by creating a .tgz file in the /bootbank directory and by
               adding the .tgz filename to the 'modules=' line in
               /bootbank/boot.cfg.

=cut

sub configure_vmhost_dedicated_ssh_key {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vcl_tgz_path = '/bootbank/vcl.tgz';
	my $bootbank_cfg_path = '/bootbank/boot.cfg';
	
	## Check if the bootbank file already exists
	#if ($self->vmhost_os->file_exists($vcl_tgz_path)) {
	#	notify($ERRORS{'DEBUG'}, 0, "persistent SSH identity key is already configured: $vcl_tgz_path");
	#	return 1;
	#}
	
	# Call tar to create a tarfile containing the contents of the /.ssh directory 
	my $tar_command = 'tar -C / -czf bootbank/vcl.tgz .ssh';
	my ($tar_exit_status, $tar_output) = $self->vmhost_os->execute($tar_command);
	if (!defined($tar_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to create $vcl_tgz_path file");
		return;
	}
	elsif ($tar_exit_status != 0 || grep(/^tar:/, @$tar_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create $vcl_tgz_path file, command: '$tar_command', ouptut:\n" . join("\n", @$tar_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "created $vcl_tgz_path file");
	}
	
	# Retrieve the contents of /bootbank/boot.cfg
	my @bootbank_cfg_contents = $self->vmhost_os->get_file_contents($bootbank_cfg_path);
	if (!@bootbank_cfg_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve the contents of $bootbank_cfg_path on VM host");
		return;
	}
	
	# Parse the file contents, add ' --- vcl.tgz' to the end of the 'modules=' line if it hasn't already been added
	# modules=k.z — s.z — c.z — oem.tgz — license.tgz — m.z — state.tgz — vcl.tgz
	my $updated_bootbank_cfg_contents;
	my $bootbank_cfg_changed = 0;
	for my $line (@bootbank_cfg_contents) {
		$line =~ s/\s+$//;
		if ($line =~ /^modules=/ && $line !~ /vcl\.tgz/) {
			$updated_bootbank_cfg_contents .= "$line --- vcl.tgz\n";
			$bootbank_cfg_changed = 1;
		}
		else {
			$updated_bootbank_cfg_contents .= "$line\n";
		}
	}
	
	# Write the updated contents back to boot.cfg
	if (!$bootbank_cfg_changed) {
		notify($ERRORS{'DEBUG'}, 0, "$bootbank_cfg_path does not need to be updated on VM host");
	}
	elsif ($self->vmhost_os->create_text_file($bootbank_cfg_path, $updated_bootbank_cfg_contents)) {
		notify($ERRORS{'OK'}, 0, "updated $bootbank_cfg_path on VM host:\n" . join("\n", @bootbank_cfg_contents));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update $bootbank_cfg_path on VM host:\noriginal contents:\n" . join("\n", @bootbank_cfg_contents) . "\n---\nupdated contents:\n$updated_bootbank_cfg_contents");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_image_repository_permissions

 Parameters  : none
 Returns     : boolean
 Description : Sets file permissions to 0755 on the image repository directory
               and files for the reservation image. The directory may either be
               mounted on the VM host or management node.

=cut

sub set_image_repository_permissions {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	my $repository_directory_path = $self->get_repository_vmdk_directory_path();
	my $repository_mounted_on_vmhost = $self->is_repository_mounted_on_vmhost();
	
	my $mode = '0755';
	
	# Attempt to set permissions on the image repository directory
	# VMware's methods to copy the files will set the permissions to 0700
	# This prevents image retrieval from working when other management nodes attempt to retrieve the image
	# The directory and all vmdk files must have r & x permissions or else image retrieval from another managment node will fail
	
	# Attempt to call the VM host OS's set_file_permissions subroutine if the repository is mounted on the VM host
	if ($repository_mounted_on_vmhost && $self->vmhost_os->can('set_file_permissions')) {
		if ($self->vmhost_os->set_file_permissions($repository_directory_path, '0755', 1)) {
			notify($ERRORS{'OK'}, 0, "set file permissions on image repository directory mounted on the VM host: $repository_directory_path");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "failed to set file permissions on the image repository directory mounted on the VM host: $repository_directory_path");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "repository is either not mounted on the VM host or the VM host OS is unable to set file permissions: $repository_directory_path");
	}
	
	# Attempt to find image files on the management node by searching all paths returned by get_image_repository_search_paths()
	my %repository_image_file_path_hash;
	my @image_repository_search_paths = $self->get_image_repository_search_paths();
	for my $search_path (@image_repository_search_paths) {
		my ($exit_status, $output) = $self->mn_os->execute("ls -1 $search_path", 0);
		
		my @file_paths_found = grep(/^\//, @$output);
		notify($ERRORS{'DEBUG'}, 0, "search path: $search_path, file paths found: " . scalar(@file_paths_found));
		
		for my $file_path (@file_paths_found) {
			$repository_image_file_path_hash{$file_path} = 1;
		}
	}
	if (!%repository_image_file_path_hash) {
		notify($ERRORS{'WARNING'}, 0, "failed to find image files in repository on the management node");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "found image files in repository on the management node:\n" . join("\n", sort keys(%repository_image_file_path_hash)));
		my $error_occurred = 0;
		for my $file_path (sort keys(%repository_image_file_path_hash)) {
			if (!$self->mn_os->set_file_permissions($file_path, $mode)) {
				notify($ERRORS{'WARNING'}, 0, "failed to set permissions to $mode on $file_path on management node");
				$error_occurred = 1;
			}
		}
		if (!$error_occurred) {
			notify($ERRORS{'OK'}, 0, "set permissions on files in image repository for image $image_name to $mode");
			return 1;
		}
	}
	
	# Check if the repository directory path exists on the management node
	if (-d $repository_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "repository directory exists on the management node: $repository_directory_path");
		
		if ($self->mn_os->set_file_permissions($repository_directory_path, $mode, 1)) {
			notify($ERRORS{'OK'}, 0, "set permissions for image repository directory on the management node: $repository_directory_path");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set permissions for image repository directory on the management node: $repository_directory_path");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "repository directory does NOT exist on the management node: $repository_directory_path");
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to set permissions on files in image repository for image $image_name to $mode");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : hash reference
 Description : Defines the menu entries when vcld -setup is invoked for the
               VMware.pm module.

=cut

sub setup_get_menu {
	return {
		'VMware Provisioning Module' => {
			'VM Host Operations' => \&VCL::Module::Provisioning::VMware::VMware::setup_vm_host_operations,
		},
	};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_vm_host_operations

 Parameters  : none
 Returns     : boolean
 Description : Retrieves info for all the VM hosts assigned to the management
               node and displays a menu to select a host. After a host is
               selected, a provisioning object is created so that the host can
               be queried and controlled. A host operations menu is then
               displayed.

=cut

sub setup_vm_host_operations {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Retrieve all VM hosts assigned to managment node and select one from menu
	setup_print_break('.');
	print "Retrieving VMware hosts mapped to $FQDN...\n";
	my $management_node_vmhost_info = get_management_node_vmhost_info();
	if (!$management_node_vmhost_info) {
		print "ERROR: Failed to retrieve VM hosts mapped to $FQDN\n";
		return;
	}
	elsif (!keys %$management_node_vmhost_info) {
		print "No VM hosts are mapped to $FQDN\n";
		return;
	}

	print "Select a VM host:\n";
	#print format_data($management_node_vmhost_info) . "\n\n";
	my $vmhost_id = setup_get_hash_choice($management_node_vmhost_info, 'hostname', 'vmprofile_profilename') || return;
	#For testing:
	#my $vmhost_id = 32;
	
	my $vmhost_computer_name = $management_node_vmhost_info->{$vmhost_id}{computer}{SHORTNAME};
	push @{$ENV{setup_path}}, $vmhost_computer_name;
	
	
	# Get a provisioning object to control the VM host
	my $vmhost_provisioner;
	if ($vmhost_provisioner = $management_node_vmhost_info->{$vmhost_id}{provisioner}) {
		print "Using previously created provisioning object to control $vmhost_computer_name.\n";
	}
	else {
		print "\nCreating provisioning object to control $vmhost_computer_name...";
		$vmhost_provisioner = $self->create_object('VCL::Module::Provisioning::VMware::VMware', {vmhost_identifier => $vmhost_id});
		if (!$vmhost_provisioner) {
			print "\nERROR: Failed to create provisioning object to control $vmhost_computer_name.\n";
			return;
		}
		
		my $vmhost_os = $vmhost_provisioner->create_vmhost_os_object();
		if (!$vmhost_os) {
			print "\nERROR: Failed to create OS object to control $vmhost_computer_name.\n";
			return;
		}
		$vmhost_provisioner->set_vmhost_os($vmhost_os);
		
		if (!$vmhost_provisioner->initialize()) {
			print "\nERROR: Failed to initial provisioning object to control $vmhost_computer_name.\n";
			return;
		}
		print "Success.\n";
		$management_node_vmhost_info->{$vmhost_id}{provisioner} = $vmhost_provisioner;
	}
	
	my $datastore_operations_menu = {
		'Migrate VM to another host' => \&setup_migrate_vm,
		'Purge deleted and unused images from virtual disk datastore' => \&setup_purge_datastore_images,
		'Purge deleted and unused images from repository datastore' => \&setup_purge_repository_images,
	};
	
	while (1) {
		setup_print_break('.');
		print "Select an operation:\n";
		my $datastore_operations_choice = setup_get_menu_choice($datastore_operations_menu);
		last if (!defined($datastore_operations_choice));
		#For testing:
		#my $datastore_operations_choice = {
		#	"name" => "Purge deleted images from datastore",
		#	"parent_menu_names" => [],
		#	"sub_ref" => \&setup_purge_datastore_images,
		#};
		#my $datastore_operations_choice = {
		#	"name" => "Purge deleted images from repository",
		#	"parent_menu_names" => [],
		#	"sub_ref" => \&setup_purge_repository_images,
		#};
		#my $datastore_operations_choice = {
		#	"name" => "Migrate VM to another host",
		#	"parent_menu_names" => [],
		#	"sub_ref" => \&setup_migrate_vm,
		#};
		
		my $datastore_operations_choice_name = $datastore_operations_choice->{name};
		my $datastore_operations_choice_sub_ref = $datastore_operations_choice->{sub_ref};
		&$datastore_operations_choice_sub_ref($vmhost_provisioner);
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_purge_datastore_images

 Parameters  : none
 Returns     : boolean
 Description : Checks all images stored in the virtual disk path location and
               determines if any can be safely purged from the datastore.

=cut

sub setup_purge_datastore_images {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname();
	my $vmhost_profile_datastore_path = $self->data->get_vmhost_profile_datastore_path();
	my $vmhost_profile_repository_path = $self->data->get_vmhost_profile_repository_path();
	
	if (!$vmhost_profile_repository_path) {
		print "WARNING: images not purged because repository path is not configured in the VM host profile\n";
		return;
	}
	
	my $datastore_base_path = $self->_get_normal_path($vmhost_profile_datastore_path);
	if (!$datastore_base_path) {
		print "ERROR: failed to locate virtual disk path configured in the VM host profile on $vmhost_computer_name: $vmhost_profile_datastore_path\n";
		return;
	}
	
	my $repository_base_path = $self->_get_normal_path($vmhost_profile_repository_path);
	if (!$repository_base_path) {
		print "ERROR: failed to locate repository path configured in the VM host profile on $vmhost_computer_name: $vmhost_profile_repository_path\n";
		return;
	}
	
	if ($datastore_base_path eq $repository_base_path) {
		print "WARNING: images not purged because virtual disk path is the same location as the repository path configured in the VM host profile: $datastore_base_path\n";
		return;
	}
	
	setup_print_break('.');
	# Get an array of image names currently stored on the datastore
	my @datastore_imagerevision_names = $self->get_datastore_imagerevision_names($datastore_base_path);
	
	setup_print_break('.');
	# Get an array of image names currently stored on the repository
	my @repository_imagerevision_names = $self->get_datastore_imagerevision_names($repository_base_path);
	
	setup_print_break('.');
	# Get various info about image revisions such as deleted, date created...
	my $imagerevision_cleanup_info = get_imagerevision_cleanup_info();
	
	# Get reservation info for all imagerevisions in datastore
	my $imagerevision_reservation_info = get_imagerevision_reservation_info();
	
	# Get computers on which imagerevisions in datastore are currently loaded according to the database
	my $imagerevision_loaded_info = get_imagerevision_loaded_info();
	
	# Ask the user how many days in the past to check if reservations were made for the image revision
	my $min_reservation_days;
	while (!$min_reservation_days) {
		$min_reservation_days = setup_get_input_string("Enter minimum number of days since last reservation", 120);
		return if !defined($min_reservation_days);
		$min_reservation_days =~ s/\s*//g;
		if ($min_reservation_days !~ /^\d+$/) {
			print "Value must be an integer\n";
			$min_reservation_days = '';
		}
	}
	
	# Ask the user minimum number of days old an image revision must be to be purged
	my $min_imagerevision_age;
	while (!$min_imagerevision_age) {
		$min_imagerevision_age = setup_get_input_string("Enter minimum number of days since image revision was created", 120);
		return if !defined($min_imagerevision_age);
		$min_imagerevision_age =~ s/\s*//g;
		if ($min_imagerevision_age !~ /^\d+$/) {
			print "Value must be an integer\n";
			$min_imagerevision_age = '';
		}
	}
	
	# Retrieve a list of image revisions reserved the the past x number of days selected by the user
	my @imagerevision_names_recently_reserved = get_imagerevision_names_recently_reserved($min_reservation_days);
	
	my @deleted;
	my @not_deleted;
	my @has_reservations;
	my @no_reservations;
	my @loaded;
	my @not_loaded;
	my @in_repository;
	my @not_in_repository;
	my @recently_reserved;
	my @not_recently_reserved;
	my @recently_created;
	my @not_recently_created;
	my @production;
	my @older_than_production;
	my @newer_than_production;
	
	# Build lists of imagerevisions with certain characteristics
	for my $datastore_imagerevision_name (@datastore_imagerevision_names) {
		if (!$imagerevision_cleanup_info->{$datastore_imagerevision_name}) {
			print "WARNING: failed to retrieve cleanup info from database for image revision: $datastore_imagerevision_name\n";
			return;
		}
		
		if ($imagerevision_cleanup_info->{$datastore_imagerevision_name}{deleted}) {
			push @deleted, $datastore_imagerevision_name;
		}
		else {
			push @not_deleted, $datastore_imagerevision_name;
		}
		
		if ($imagerevision_reservation_info->{$datastore_imagerevision_name}) {
			push @has_reservations, $datastore_imagerevision_name;
		}
		else {
			push @no_reservations, $datastore_imagerevision_name;
		}
		
		if ($imagerevision_loaded_info->{$datastore_imagerevision_name}) {
			push @loaded, $datastore_imagerevision_name;
		}
		else {
			push @not_loaded, $datastore_imagerevision_name;
		}
		
		if (grep { $_ eq $datastore_imagerevision_name } @repository_imagerevision_names) {
			push @in_repository, $datastore_imagerevision_name;
		}
		else {
			push @not_in_repository, $datastore_imagerevision_name;
		}
		
		my $revision = $imagerevision_cleanup_info->{$datastore_imagerevision_name}{revision};
		my $production_revision = $imagerevision_cleanup_info->{$datastore_imagerevision_name}{productionrevision};
		if ($revision eq $production_revision) {
			push @production, $datastore_imagerevision_name;
		}
		elsif ($revision < $production_revision) {
			push @older_than_production, $datastore_imagerevision_name;
		}
		else {
			push @newer_than_production, $datastore_imagerevision_name;
		}
		
		if ($imagerevision_cleanup_info->{$datastore_imagerevision_name}{age} <= $min_imagerevision_age) {
			push @recently_created, $datastore_imagerevision_name;
		}
		else {
			push @not_recently_created, $datastore_imagerevision_name;
		}
		
		if (grep { $_ eq $datastore_imagerevision_name } @imagerevision_names_recently_reserved) {
			push @recently_reserved, $datastore_imagerevision_name;
		}
		else {
			push @not_recently_reserved, $datastore_imagerevision_name;
		}
	}
	
	# Find image revisions which have multiple characteristics by finding the intersection of the arrays
	my @deleted_has_reservations              = get_array_intersection(\@deleted, \@has_reservations);
	my @deleted_has_reservations_loaded       = get_array_intersection(\@deleted, \@has_reservations, \@loaded);
	my @deleted_has_reservations_not_loaded   = get_array_intersection(\@deleted, \@has_reservations, \@not_loaded);
	my @deleted_no_reservations               = get_array_intersection(\@deleted, \@no_reservations);
	my @deleted_no_reservations_loaded        = get_array_intersection(\@deleted, \@no_reservations, \@loaded);
	my @deleted_no_reservations_not_loaded    = get_array_intersection(\@deleted, \@no_reservations, \@not_loaded);
	my @not_deleted_has_reservations             = get_array_intersection(\@not_deleted, \@has_reservations);
	my @not_deleted_has_reservations_loaded      = get_array_intersection(\@not_deleted, \@has_reservations, \@loaded);
	my @not_deleted_has_reservations_not_loaded  = get_array_intersection(\@not_deleted, \@has_reservations, \@not_loaded);
	my @not_deleted_no_reservations              = get_array_intersection(\@not_deleted, \@no_reservations);
	my @not_deleted_no_reservations_loaded       = get_array_intersection(\@not_deleted, \@no_reservations, \@loaded);
	my @not_deleted_no_reservations_not_loaded   = get_array_intersection(\@not_deleted, \@no_reservations, \@not_loaded);
	my @not_deleted_candidate                                      = get_array_intersection(\@not_deleted, \@no_reservations, \@not_loaded, \@in_repository);
	my @not_deleted_no_reservations_not_loaded_not_in_repository   = get_array_intersection(\@not_deleted, \@no_reservations, \@not_loaded, \@not_in_repository);
	my @not_deleted_candidate_older_than_production                                  = get_array_intersection(\@not_deleted_candidate, \@older_than_production); # Purgable
	my @not_deleted_candidate_production                                             = get_array_intersection(\@not_deleted_candidate, \@production);
	my @not_deleted_candidate_production_recently_created                            = get_array_intersection(\@not_deleted_candidate, \@production, \@recently_created);
	my @not_deleted_candidate_production_not_recently_created                        = get_array_intersection(\@not_deleted_candidate, \@production, \@not_recently_created);
	my @not_deleted_candidate_production_not_recently_created_recently_reserved      = get_array_intersection(\@not_deleted_candidate, \@production, \@not_recently_created, \@recently_reserved);
	my @not_deleted_candidate_production_not_recently_created_not_recently_reserved  = get_array_intersection(\@not_deleted_candidate, \@production, \@not_recently_created, \@not_recently_reserved); # Purgable
	my @not_deleted_candidate_newer_than_production                                  = get_array_intersection(\@not_deleted_candidate, \@newer_than_production);
	my @not_deleted_candidate_newer_than_production_recently_created                 = get_array_intersection(\@not_deleted_candidate, \@newer_than_production, \@recently_created);
	my @not_deleted_candidate_newer_than_production_not_recently_created             = get_array_intersection(\@not_deleted_candidate, \@newer_than_production, \@not_recently_created); # Purgable
	
	setup_print_break('-');
	print "Analyzed image revisions stored in the virtual disk path datastore:\n";
	print "|- Deleted: "                                                             . scalar(@deleted) . "\n";
	print "   |- Has reservation: "                                                  . scalar(@deleted_has_reservations) . "\n";
	print "      |- No reservations: "                                               . scalar(@deleted_no_reservations) . "\n";
	print "         |- Loaded: "                                                     . scalar(@deleted_no_reservations_loaded) . "\n";
	print "         |- Not loaded: "                                                 . scalar(@deleted_no_reservations_not_loaded) . " (*)\n";
	print "|- Not deleted: "                                                         . scalar(@not_deleted) . "\n";
	print "   |- Has reservation: "                                                  . scalar(@not_deleted_has_reservations) . "\n";
	print "   |- No reservations: "                                                  . scalar(@not_deleted_no_reservations) . "\n";
	print "      |- Loaded: "                                                        . scalar(@not_deleted_no_reservations_loaded) . "\n";
	print "      |- Not loaded: "                                                    . scalar(@not_deleted_no_reservations_not_loaded) . "\n";
	print "         |- Not in_repository: "                                          . scalar(@not_deleted_no_reservations_not_loaded_not_in_repository) . "\n";
	print "         |- In repository: "                                              . scalar(@not_deleted_candidate) . "\n";
	print "            |- Production: "                                              . scalar(@not_deleted_candidate_production) . "\n";
	print "               |- Created in last $min_imagerevision_age days: "          . scalar(@not_deleted_candidate_production_recently_created) . "\n";
	print "               |- Not created in last $min_imagerevision_age days: "      . scalar(@not_deleted_candidate_production_not_recently_created) . "\n";
	print "                  |- Reserved in last $min_reservation_days days: "       . scalar(@not_deleted_candidate_production_not_recently_created_recently_reserved) . "\n";
	print "                  |- Not reserved in last $min_reservation_days days: "   . scalar(@not_deleted_candidate_production_not_recently_created_not_recently_reserved) . " (*)\n";
	print "            |- Older than production: "                                   . scalar(@not_deleted_candidate_older_than_production) . " (*)\n";
	print "            |- Newer than production: "                                   . scalar(@not_deleted_candidate_newer_than_production) . "\n";
	print "               |- Created in last $min_imagerevision_age days: "          . scalar(@not_deleted_candidate_newer_than_production_recently_created) . "\n";
	print "               |- Not created in last $min_imagerevision_age days: "      . scalar(@not_deleted_candidate_newer_than_production_not_recently_created) . " (*)\n";
	print "(*) May be safely purged\n\n";
	
	my @purgable_imagerevisions;
	
	if (@deleted_no_reservations_not_loaded) {
		push @purgable_imagerevisions, @deleted_no_reservations_not_loaded;
		print "Deleted, no reservations, not loaded: " . scalar(@deleted_no_reservations_not_loaded) . "\n";
		print "- " . join("\n- ", @deleted_no_reservations_not_loaded) . "\n\n";
	}
	
	if (@not_deleted_candidate_older_than_production) {
		push @purgable_imagerevisions, @not_deleted_candidate_older_than_production;
		print "Not deleted, no reservations, not loaded, in repository, older than production revision: " . scalar(@not_deleted_candidate_older_than_production) . "\n";
		print "- " . join("\n- ", @not_deleted_candidate_older_than_production) . "\n\n";
	}
	
	if (@not_deleted_candidate_newer_than_production_not_recently_created) {
		push @purgable_imagerevisions, @not_deleted_candidate_newer_than_production_not_recently_created;
		print "Not deleted, no reservations, not loaded, in repository, newer than production revision, not created in last $min_imagerevision_age days: " . scalar(@not_deleted_candidate_newer_than_production_not_recently_created) . "\n";
		print "- " . join("\n- ", @not_deleted_candidate_newer_than_production_not_recently_created) . "\n\n";
	}
	
	if (@not_deleted_candidate_production_not_recently_created_not_recently_reserved) {
		push @purgable_imagerevisions, @not_deleted_candidate_production_not_recently_created_not_recently_reserved;
		print "Not deleted, no reservations, not loaded, in repository, production, not created in last $min_imagerevision_age days, not reserved in last $min_reservation_days days: " . scalar(@not_deleted_candidate_production_not_recently_created_not_recently_reserved) . "\n";
		print "- " . join("\n- ", @not_deleted_candidate_production_not_recently_created_not_recently_reserved) . "\n\n";
	}
	
	
	if (!@purgable_imagerevisions) {
		print "No image revisions were found which can be safely purged from the virtual disk datastore\n";
		return;
	}
	
	return $self->setup_purge_images_helper($datastore_base_path, \@purgable_imagerevisions);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_purge_repository_images

 Parameters  : none
 Returns     : boolean
 Description : Checks all images stored in the repository path location and
               safely purges them.

=cut

sub setup_purge_repository_images {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname();
	my $vmhost_profile_datastore_path = $self->data->get_vmhost_profile_datastore_path();
	my $vmhost_profile_repository_path = $self->data->get_vmhost_profile_repository_path();
	
	if (!$vmhost_profile_repository_path) {
		print "WARNING: images not purged because repository path is not configured in the VM host profile\n";
		return;
	}
	
	my $datastore_base_path = $self->_get_normal_path($vmhost_profile_datastore_path);
	if (!$datastore_base_path) {
		print "ERROR: failed to locate virtual disk path configured in the VM host profile on $vmhost_computer_name: $vmhost_profile_datastore_path\n";
		return;
	}
	
	my $repository_base_path = $self->_get_normal_path($vmhost_profile_repository_path);
	if (!$repository_base_path) {
		print "ERROR: failed to locate repository path configured in the VM host profile on $vmhost_computer_name: $vmhost_profile_repository_path\n";
		return;
	}
	
	if ($datastore_base_path eq $repository_base_path) {
		print "WARNING: images not purged because virtual disk path is the same location as the repository path configured in the VM host profile: $datastore_base_path\n";
		return;
	}
	
	setup_print_break('.');
	# Get an array of image names currently stored on the repository
	my @repository_imagerevision_names = $self->get_datastore_imagerevision_names($repository_base_path);
	
	setup_print_break('.');
	# Get various info about image revisions such as deleted, date created...
	my $imagerevision_cleanup_info = get_imagerevision_cleanup_info();

	# Get reservation info for all imagerevisions in repository
	my $imagerevision_reservation_info = get_imagerevision_reservation_info();
	
	# Get computers on which imagerevisions in datastore are currently loaded according to the database
	my $imagerevision_loaded_info = get_imagerevision_loaded_info();
	
	my @deleted;
	my @not_deleted;
	my @has_reservations;
	my @no_reservations;
	my @loaded;
	my @not_loaded;
	
	# Build lists of imagerevisions with certain characteristics
	for my $repository_imagerevision_name (@repository_imagerevision_names) {
		if (!$imagerevision_cleanup_info->{$repository_imagerevision_name}) {
			print "WARNING: failed to retrieve cleanup info from database for image revision: $repository_imagerevision_name\n";
			return;
		}
		
		if ($imagerevision_cleanup_info->{$repository_imagerevision_name}{deleted}) {
			push @deleted, $repository_imagerevision_name;
		}
		else {
			push @not_deleted, $repository_imagerevision_name;
		}
		
		if ($imagerevision_reservation_info->{$repository_imagerevision_name}) {
			push @has_reservations, $repository_imagerevision_name;
		}
		else {
			push @no_reservations, $repository_imagerevision_name;
		}
		
		if ($imagerevision_loaded_info->{$repository_imagerevision_name}) {
			push @loaded, $repository_imagerevision_name;
		}
		else {
			push @not_loaded, $repository_imagerevision_name;
		}
	}
	
	# Find image revisions which have multiple characteristics by finding the intersection of the arrays
	my @deleted_has_reservations              = get_array_intersection(\@deleted, \@has_reservations);
	my @deleted_has_reservations_loaded       = get_array_intersection(\@deleted, \@has_reservations, \@loaded);
	my @deleted_has_reservations_not_loaded   = get_array_intersection(\@deleted, \@has_reservations, \@not_loaded);
	my @deleted_no_reservations               = get_array_intersection(\@deleted, \@no_reservations);
	my @deleted_no_reservations_loaded        = get_array_intersection(\@deleted, \@no_reservations, \@loaded);
	my @deleted_no_reservations_not_loaded    = get_array_intersection(\@deleted, \@no_reservations, \@not_loaded);
	
	#setup_print_break('-');
	print "Analyzed image revisions stored in the repository datastore:\n";
	print "|- Deleted: "                   . scalar(@deleted) . "\n";
	print "   |- Has reservation: "        . scalar(@deleted_has_reservations) . "\n";
	print "      |- No reservations: "     . scalar(@deleted_no_reservations) . "\n";
	print "         |- Loaded: "           . scalar(@deleted_no_reservations_loaded) . "\n";
	print "         |- Not loaded: "       . scalar(@deleted_no_reservations_not_loaded) . " (*)\n";
	print "|- Not deleted: "               . scalar(@not_deleted) . "\n";
	print "(*) May be safely purged\n\n";
	
	my @purgable_imagerevisions;
	
	if (@deleted_no_reservations_not_loaded) {
		push @purgable_imagerevisions, @deleted_no_reservations_not_loaded;
		print "Deleted, no reservations, not loaded: " . scalar(@deleted_no_reservations_not_loaded) . "\n";
		print "- " . join("\n- ", @deleted_no_reservations_not_loaded) . "\n\n";
	}
	
	if (!@purgable_imagerevisions) {
		setup_print_ok("No image revisions were found which can be safely purged from the repository datastore");
		return 1;
	}
	
	return $self->setup_purge_images_helper($repository_base_path, \@purgable_imagerevisions);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_purge_images_helper

 Parameters  : $datastore_base_path, $purgable_imagerevisions
 Returns     : boolean
 Description : 

=cut

sub setup_purge_images_helper {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($datastore_base_path, $purgable_imagerevisions) = @_;
	if (!defined($datastore_base_path)) {
		notify($ERRORS{'WARNING'}, 0, "datastore base path argument was not supplied");
		return;
	}
	elsif (!defined($purgable_imagerevisions)) {
		notify($ERRORS{'WARNING'}, 0, "purgable image revision array reference argument was not supplied");
		return;
	}
	elsif (!ref($purgable_imagerevisions) || ref($purgable_imagerevisions) ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "purgable image revision argument is not an array reference");
		return;
	}


	my $purgable_hashref = {};
	for (my $i=0; $i < scalar(@$purgable_imagerevisions); $i++) {
		$purgable_hashref->{$i}{imagename} = @$purgable_imagerevisions[$i];
	}
	my @indexes_to_purge = setup_get_hash_multiple_choice($purgable_hashref,
		{
			'title' => "Select image revisions to purge:",
			'display_keys' => ['{imagename}'],
		}
	);
	
	
	my @failed_directory_paths;
	IMAGEREVISION: for my $index (@indexes_to_purge) {
		my $imagerevision_name = @$purgable_imagerevisions[$index];
		
		setup_print_break('.');
		print "Deleting image revision: $imagerevision_name\n";
		
		my $datastore_directory_path = "$datastore_base_path/$imagerevision_name";
		print "Datastore directory path: $datastore_directory_path\n";
		
		my $datastore_directory_name_renamed = "_delete_$imagerevision_name";
		my $datastore_directory_path_renamed = "$datastore_base_path/$datastore_directory_name_renamed";
		
		# Check files in directory, make sure it's safe to delete
		my @file_paths = $self->find_datastore_files($datastore_directory_path, "*", 1);
		
		# Don't delete directories which contain files which shouldn't reside in a datastore direcotry
		my @unsafe_file_paths = ();
		#push @unsafe_file_paths, grep(/-flat\./, @file_paths);
		push @unsafe_file_paths, grep(/\.vmx$/, @file_paths);
		if (@unsafe_file_paths) {
			setup_print_error("Image revision not deleted from datastore: $imagerevision_name");
			print "Directory contains files which normally wouldn't reside in an image datastore directory:\n";
			print join("\n", @unsafe_file_paths) . "\n";
			push @failed_directory_paths, $datastore_directory_path;
			next IMAGEREVISION;
		}
		
		## Make sure directory contains a file name using the 2gbsparse format
		#if (!grep(/-s\d+\.vmdk$/, @file_paths)) {
		#	setup_print_error("Image revision not deleted from datastore: $imagerevision_name");
		#	print "Directory does not contain a 2GB sparse formatted file name (xxx-s001.vmdk):\n";
		#	print join("\n", @file_paths) . "\n";
		#	push @failed_directory_paths, $datastore_directory_path;
		#	next IMAGEREVISION;
		#}
		
		# Attempt to rename the directory before deleting the files
		# This should determine if all of the files can be deleted
		# Otherwise, if some files are locked the delete operation may delete some files but not all and fail
		# This results in a directory which must be deleted manually because subsequent attempts of this subroutine will detect something amiss
		print "Attempting to rename directory: $imagerevision_name --> $datastore_directory_name_renamed\n";
		if (!$self->vmhost_os->move_file($datastore_directory_path, $datastore_directory_path_renamed)) {
			setup_print_error("image revision not deleted from datastore: $imagerevision_name");
			print "Directory could not be renamed prior to deletion, files in the directory may be locked\n";
			push @failed_directory_paths, $datastore_directory_path;
			next IMAGEREVISION;
		}
		
		print "Attempting to delete directory: $datastore_directory_name_renamed\n";
		my $delete_attempt_limit = 5;
		DELETE_ATTEMPT: for (my $delete_attempt = 1; $delete_attempt <= $delete_attempt_limit; $delete_attempt++) {
			if ($self->vmhost_os->delete_file($datastore_directory_path_renamed)) {
				setup_print_ok("Directory deleted: $datastore_directory_path_renamed");
				next IMAGEREVISION;
			}
			else {
				setup_print_warning("Attempt $delete_attempt/$delete_attempt_limit, failed to delete image revision: $imagerevision_name");
				sleep_uninterrupted(3);
			}
		}
		setup_print_error("Failed to delete image revision: $imagerevision_name");
		push @failed_directory_paths, $datastore_directory_path;
		
		print "attempting to revert directory name change: $datastore_directory_name_renamed --> $imagerevision_name\n";
		if (!$self->vmhost_os->move_file($datastore_directory_path_renamed, $datastore_directory_path)) {
			setup_print_error("Failed to revert directory name change: $datastore_directory_name_renamed --> $imagerevision_name");
			print "Directory must be manually deleted: $datastore_directory_path_renamed\n";
			return 0;
		}
		
		next IMAGEREVISION;
	}
	
	if (@failed_directory_paths) {
		setup_print_break('-');
		setup_print_warning("Some directories could not be deleted:");
		print join("\n", @failed_directory_paths) . "\n";
		return 0;
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_datastore_image_names

 Parameters  : $datastore_base_path
 Returns     : array
 Description : Retrieves a list of all image revisions which exist under the
               datastore base path. The directory entries checked to ensure a
               matching image revision exists in the database so that extraneous
               file entries are not returned.

=cut

sub get_datastore_imagerevision_names {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $datastore_base_path = shift;
	if (!$datastore_base_path) {
		notify($ERRORS{'WARNING'}, 0, "datastore base path argument was not supplied");
		return;
	}
	
	print "Retrieving list of all image revisions from database... ";
	my @imagerevision_names = get_imagerevision_names();
	print scalar(@imagerevision_names) . " found\n";
	my %imagerevision_name_hash = map { $_ => 1 } @imagerevision_names;
	
	print "Retrieving list of files and directories in datastore: $datastore_base_path...";
	my @file_paths = $self->find_datastore_files($datastore_base_path, "*.vmdk", 1);
	print " Done\n";
	
	my @datastore_imagerevision_names;
	my @ignored;
	
	my $start = time();
	for my $file_path (@file_paths) {
		$file_path =~ s/\/+$//;
		next if $file_path eq $datastore_base_path;
		
		my ($parent_directory_name) = $file_path =~ m|\/([^\/]+)\/[^\/]+$|;
		next if !defined($parent_directory_name);
		
		if (defined($imagerevision_name_hash{$parent_directory_name})) {
			push @datastore_imagerevision_names, $parent_directory_name;
		}
		else {
			push @ignored, $parent_directory_name;
		}
	}
	
	# Remove duplicates
	my %datastore_imagerevision_name_hash = map { $_ => 1 } @datastore_imagerevision_names;
	@datastore_imagerevision_names = sort keys %datastore_imagerevision_name_hash;
	
	my $datastore_imagerevision_name_count = scalar(@datastore_imagerevision_names);
	
	print "\n";
	if (@ignored) {
		# Remove duplicates
		my %ignored_hash = map { $_ => 1 } @ignored;
		@ignored = sort keys %ignored_hash;
		my $ignored_count = scalar(@ignored);
		print "$ignored_count files and/or directories ignored, image revision not found in database:\n" . join("\n", @ignored) . "\n\n";
	}
	print "$datastore_imagerevision_name_count images found in datastore '$datastore_base_path'\n";

	return @datastore_imagerevision_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 configure_root_ssh_key

 Parameters  : none
 Returns     : boolean
 Description : Creates SSH private and public key files on the VM host to allow
					the root account on the host to authenticate to other hosts. This
					subroutine does not configure SSH keys related to the management
					node. It is used to configure SSH for VM host to VM host
					communication.

=cut

sub configure_root_ssh_key {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_name = $self->data->get_vmhost_short_name();
	
	my $vmhost_private_key_file_path = "/.ssh/id_rsa";
	my $vmhost_public_key_file_path = "$vmhost_private_key_file_path.pub";
	
	my $vmware_product_name = $self->get_vmhost_product_name();
	my $bits;
	if ($vmware_product_name =~ /4\./) {
		$bits = 768;
	}
	else {
		$bits = 1024;
	}
	
	# Check if the private key already exists
	if (!$self->vmhost_os->file_exists($vmhost_private_key_file_path)) {
		# Private key does not exist on VM host
		if ($self->vmhost_os->file_exists($vmhost_public_key_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "public key file exists on $vmhost_name but private key file does not, deleting public key file: $vmhost_public_key_file_path");
			if (!$self->vmhost_os->delete_file($vmhost_public_key_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "failed to delete orphaned public key file on VM host $vmhost_name: $vmhost_public_key_file_path");
				return;
			}
		}
		
		# Create the private key file
		if (!$self->vmhost_os->generate_ssh_private_key_file($vmhost_private_key_file_path, 'rsa', $bits)) {
			return;
		}
	}
	
	# Create the public key file if it wasn't created when the private key was created
	if (!$self->vmhost_os->file_exists($vmhost_public_key_file_path)) {
		if (!$self->vmhost_os->generate_ssh_public_key_file($vmhost_private_key_file_path, $vmhost_public_key_file_path)) {
			return;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "configured SSH key for the root user on VM host $vmhost_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_ssh_root_key_to_authorized_keys

 Parameters  : $destination_vmware_object
 Returns     : boolean
 Description : Retrieves the root user's public SSH key from the VM host
               represented by the object which this subroutine is called from
               ($self) and adds it to the authorized_keys file on the
               destination VM host.
               
               "Destination" means the remote VM host which the source will SSH
               into or send a file to via SCP.

=cut

sub add_ssh_root_key_to_authorized_keys {
	my ($source, $destination) = @_;
	if (!$source) {
		notify($ERRORS{'WARNING'}, 0, "no arguments were provided");
		return;
	}
	elsif (!ref($source) || ref($source) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "1st argument is not a reference to a VMware provisioning object");
		return;
	}
	elsif (!$destination) {
		notify($ERRORS{'WARNING'}, 0, "2nd destination VMware provisioning object argument was not supplied");
		return;
	}
	elsif (!ref($destination) || ref($destination) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "2nd argument is not a reference to a VMware provisioning object");
		return;
	}
	
	my $source_vmhost_computer_name = $source->data->get_vmhost_short_name();
	my $destination_vmhost_computer_name = $destination->vmhost_os->data->get_computer_short_name();
	
	my $source_private_key_file_path = "/.ssh/id_rsa";
	
	# Determine the authorized_keys file location based on the VMware version
	my $destination_vmware_product_name = $destination->get_vmhost_product_name();
	my $destination_authorized_keys_file_path;
	if ($destination_vmware_product_name =~ /4\./) {
		$destination_authorized_keys_file_path = "/.ssh/authorized_keys";
	}
	else {
		$destination_authorized_keys_file_path = "/etc/ssh/keys-root/authorized_keys";
	}
	
	# Get the source VM host's public key string
	my $source_public_key_string = $source->vmhost_os->get_ssh_public_key_string($source_private_key_file_path);
	if ($source_public_key_string) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved source VM host $source_vmhost_computer_name public SSH key:\n$source_public_key_string");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of public SSH key file from source VM host $source_vmhost_computer_name");
		return;
	}
	
	# Get the contents of the destination VM host's authorized_keys file
	my $destination_authorized_keys_file_contents = $destination->vmhost_os->get_file_contents($destination_authorized_keys_file_path);
	if ($destination_authorized_keys_file_contents) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved contents of $destination_authorized_keys_file_path from destination VM host $destination_vmhost_computer_name:\n$destination_authorized_keys_file_contents");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $destination_authorized_keys_file_path from destination VM host $destination_vmhost_computer_name");
		return;
	}
	
	# Remove comments from public key for comparison
	my $source_public_key_string_cleaned = $source_public_key_string;
	$source_public_key_string_cleaned =~ s/^\s*(ssh-\w+\s+[^\s=]+).*/$1/g;
	my @destination_authorized_keys_file_lines = split(/\n+/, $destination_authorized_keys_file_contents);
	for my $destination_authorized_keys_file_line (@destination_authorized_keys_file_lines) {
		$destination_authorized_keys_file_line =~ s/^(ssh-\w+\s+[^\s=]+).*/$1/g;
		if ($destination_authorized_keys_file_line eq $source_public_key_string_cleaned) {
			notify($ERRORS{'DEBUG'}, 0, "$destination_authorized_keys_file_path on destination VM host $destination_vmhost_computer_name already contains the VM host's $source_vmhost_computer_name public SSH key:\n$source_public_key_string");
			return 1;
		}
	}
	
	# Public key was not found in destination's authorized_keys file, attempt to add it
	if ($destination->vmhost_os->append_text_file($destination_authorized_keys_file_path, $source_public_key_string)) {
		notify($ERRORS{'OK'}, 0, "added VM host $source_vmhost_computer_name public SSH key to $destination_authorized_keys_file_path on destination VM host $destination_vmhost_computer_name:\n$source_public_key_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add VM host $source_vmhost_computer_name public SSH key to $destination_authorized_keys_file_path on destination VM host $destination_vmhost_computer_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_ssh_host_key_to_known_hosts

 Parameters  : $destination_vmware_object
 Returns     : boolean
 Description : Retrieves the public SSH host key from the destination VMware
               host and adds and entry to known_hosts on the VM host represented
               by the object which this subroutine is called from ($self).
               
               "Destination" means the remote VM host which the source will SSH
               into or send a file to via SCP. "Destination" does not mean the
               VM host whose known_hosts file will be modified.

=cut

sub add_ssh_host_key_to_known_hosts {
	my ($source, $destination) = @_;
	if (!$source) {
		notify($ERRORS{'WARNING'}, 0, "no arguments were provided");
		return;
	}
	elsif (!ref($source) || ref($source) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "1st argument is not a reference to a VMware provisioning object");
		return;
	}
	elsif (!$destination) {
		notify($ERRORS{'WARNING'}, 0, "2nd destination VMware provisioning object argument was not supplied");
		return;
	}
	elsif (!ref($destination) || ref($destination) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "2nd argument is not a reference to a VMware provisioning object");
		return;
	}
	
	my $source_vmhost_computer_name = $source->vmhost_os->data->get_computer_hostname();
	my $destination_vmhost_computer_name = $destination->vmhost_os->data->get_computer_hostname();
	
	# Add extra checking here - easy for objects to not be created correctly
	if (!$source_vmhost_computer_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to add host SSH key to known_hosts, source VM host computer name could not be determined");
		return;
	}
	if (!$destination_vmhost_computer_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to add host SSH key to known_hosts on $source_vmhost_computer_name, destination VM host computer name could not be determined");
		return;
	}
	
	my $source_known_hosts_file_path = "/.ssh/known_hosts";
	
	# Figure out the IP address to use to connect to the destination
	my $destination_remote_connection_target = determine_remote_connection_target($destination_vmhost_computer_name);
	if (!$destination_remote_connection_target) {
		notify($ERRORS{'WARNING'}, 0, "failed to add host SSH key from $destination_vmhost_computer_name to known_hosts on $source_vmhost_computer_name, failed to determine the remote connection target (IP address) to use for connecting to $destination_vmhost_computer_name");
		return;
	}
	
	# Determine the host SSH key file path based on the VMware version
	my $destination_vmware_product_name = $destination->get_vmhost_product_name();
	my $destination_private_host_key_file_path;
	if ($destination_vmware_product_name =~ /4\./) {
		$destination_private_host_key_file_path = "/etc/dropbear/dropbear_rsa_host_key";
	}
	else {
		$destination_private_host_key_file_path = "/etc/ssh/ssh_host_rsa_key";
	}
	
	# Extract the public key from the destination's private SSH host key
	my $destination_public_key_string = $destination->vmhost_os->get_ssh_public_key_string($destination_private_host_key_file_path);
	if (!$destination_public_key_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to add host SSH key from $destination_vmhost_computer_name to known_hosts on $source_vmhost_computer_name, failed to determine public SSH key from $destination_private_host_key_file_path on $destination_vmhost_computer_name");
		return;
	}
	
	## Make sure there is no comment in the public key or things won't work
	#$destination_public_key_string =~ s/(ssh-\w+\s+[^=\s]+).*/$1/;
	
	# Remove any existing entries from the known_hosts file on the source
	$source->vmhost_os->execute("sed -i -e \"/^$destination_remote_connection_target /d\" $source_known_hosts_file_path");
	
	# Assemble the known_hosts line
	my $source_known_hosts_string = "$destination_remote_connection_target $destination_public_key_string";
	
	if ($source->vmhost_os->append_text_file($source_known_hosts_file_path, $source_known_hosts_string)) {
		notify($ERRORS{'OK'}, 0, "added host SSH key from $destination_vmhost_computer_name to known_hosts on $source_vmhost_computer_name:\n$source_known_hosts_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to append known_hosts on $source_vmhost_computer_name:\n$source_known_hosts_string");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_file_to_another_host

 Parameters  : $source, $source_file_path, $destination, $destination_file_path
 Returns     : boolean
 Description : Copies a file from one VM host to another. The $source and
               $destination arguments should be fully initialized VMware.pm
               objects.

=cut

sub copy_file_to_another_host {
	my ($source, $source_file_path, $destination, $destination_file_path) = @_;
	if (!$source || ref($source) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "source VM host argument is not a VMware module object");
		return;
	}
	elsif (!$source_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source VM host file path argument was not provided");
		return;
	}
	elsif (!$destination || ref($destination) !~ /VMware/i) {
		notify($ERRORS{'WARNING'}, 0, "destination VM host argument is not a VMware module object");
		return;
	}
	elsif (!$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "destination VM host file path argument was not provided");
		return;
	}
	
	my $source_vmhost_computer_name = $source->vmhost_os->data->get_computer_short_name(0);
	my $destination_vmhost_computer_name = $destination->vmhost_os->data->get_computer_short_name(0);
	my $destination_connection_target = determine_remote_connection_target($destination_vmhost_computer_name);
	
	my $command = "scp -i /.ssh/id_rsa $source_file_path $destination_connection_target:$destination_file_path";
	my ($exit_status, $output) = $source->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to copy file from: $source_vmhost_computer_name:$source_file_path --> $destination_vmhost_computer_name:$destination_file_path");
		return;
	}
	elsif ($exit_status ne 0 || grep(/^scp:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file: $source_vmhost_computer_name:$source_file_path --> $destination_vmhost_computer_name:$destination_file_path\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "copied file: $source_vmhost_computer_name:$source_file_path --> $destination_vmhost_computer_name:$destination_file_path\ncommand: $command\noutput:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_migrate_vm

 Parameters  : $source_vmhost_provisioner
 Returns     : boolean
 Description : Presents the vcld -setup menu for migrating a VM from one host to
               another.

=cut

sub setup_migrate_vm {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $source_vmhost_computer_name = $self->data->get_vmhost_short_name();
	my $source_vmhost_id = $self->data->get_vmhost_id();
	
	my $source_assigned_vm_info = get_vmhost_assigned_vm_info($source_vmhost_id, 1);
	if (!keys %$source_assigned_vm_info) {
		print "No VMs are assigned to $source_vmhost_computer_name\n";
		return;
	}
	
	#print "\nSelect VMs to be migrated off of $source_vmhost_computer_name:\n";
	#my $vm_computer_id = setup_get_hash_multiple_choice($source_assigned_vm_info, 'SHORTNAME', 'currentimagerevision-imagename') || return;
	
	my @vm_computer_ids = setup_get_hash_multiple_choice($source_assigned_vm_info,
		{
			'title' => "Select VMs to be migrated off of $source_vmhost_computer_name",
			'display_keys' => ['{SHORTNAME}', ' - ', '{currentimagerevision}{imagename}', ' (', '{state}{name}', ')'],
		}
	);
	return unless @vm_computer_ids;
	
	# Get the list of VM hosts assigned to this management node
	# Create a deep copy clone of the hash reference before deleting source VM host key from hash
	# Otherwise, the result of get_management_node_vmhost_info would be altered for other callers
	my $management_node_vmhost_info = dclone(get_management_node_vmhost_info());
	
	# Display VM hosts other than the source, delete the source VM host ID key from the hash
	delete $management_node_vmhost_info->{$source_vmhost_id};
	
	print "\nSelect the destination VM host:\n";
	my $destination_vmhost_id = setup_get_hash_choice($management_node_vmhost_info, 'hostname', 'vmprofile_profilename') || return;
	my $destination_vmhost_computer_name = $management_node_vmhost_info->{$destination_vmhost_id}{computer}{SHORTNAME};
	print "Destination VM host: $destination_vmhost_computer_name (VM host ID: $destination_vmhost_id)\n";
	
	my $suspend_methods = {
		'vmware'		=> { title => 'VMware-based suspend' },
		'os'  		=> { title => 'Guest OS hibernate' },
		'shutdown'	=> { title => 'Guest OS shutdown' },
	};
	print "\nSelect how the VM will be suspended prior to the migration:\n";
	my $suspend_method = setup_get_hash_choice($suspend_methods, 'title') || return;

	for my $vm_computer_id (@vm_computer_ids) {
		setup_print_break('.');
		my $vm_computer_name = $source_assigned_vm_info->{$vm_computer_id}{SHORTNAME};
		print colored("Attempting to migrate $vm_computer_name from $source_vmhost_computer_name to $destination_vmhost_computer_name", 'BOLD CYAN');
		print "\n";
		if ($self->migrate_vm($vm_computer_id, $destination_vmhost_id, { revert_destination_on_error => 0, suspend_method => $suspend_method })) {
			print colored("Successfully migrated $vm_computer_name from $source_vmhost_computer_name to $destination_vmhost_computer_name", 'BOLD GREEN');
			print "\n";
		}
		else {
			print colored("Failed to migrate $vm_computer_name from $source_vmhost_computer_name to $destination_vmhost_computer_name, check $LOGFILE for more information", 'BOLD YELLOW ON_RED');
			print "\n";
			#return;
		}
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 migrate_vm

 Parameters  : $vm_identifier, $destination_vmhost_identifier, $options (optional)
 Returns     : boolean
 Description : Migrates a VM from the host the VM is assigned to to another
               host. An optional $options hash reference may be supplied which
               may contain the following keys:
               * revert_destination_on_error - Used for development and
                 troubleshooting. If a migration fails, the destination VM is
                 removed by default. If this is set to true the destination VM
                 will be left on the VM host and powered off.

=cut

sub migrate_vm {
	my $self = shift;
	if (ref($self) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my ($vm_identifier, $destination_vmhost_identifier, $options) = @_;
	if (!defined($vm_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "VM identifier argument was not supplied");
		return;
	}
	elsif (!defined($destination_vmhost_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "destination VM host identifier argument was not supplied");
		return;
	}
	
	my $revert_destination_on_error = 0;
	if (defined($options->{revert_destination_on_error})) {
		$revert_destination_on_error = $options->{revert_destination_on_error};
	}
	
	
	# Used to determine how to suspend or power off the source VM
	my $suspend_method = 'vmware';
	if (defined($options->{suspend_method})) {
		$suspend_method = $options->{suspend_method};
		$suspend_method = lc($suspend_method);
		if ($suspend_method !~ /(vmware|os|shutdown)/i) {
			notify($ERRORS{'WARNING'}, 0, "invalid 'suspend_method' argument specified: '$suspend_method', valid values are 'vmware', 'os', or 'shutdown'");
			return;
		}
	}
	else {
		$suspend_method = 'vmware';
	}
	
	if ($SETUP_MODE) {
		no warnings 'redefine';
		*notify = sub {
			my ($type, $log, $message) = @_;
			
			my $calling_subroutine = (caller(1))[3];
			if ($type == $ERRORS{'WARNING'}) {
				print colored("WARNING: $message", 'BOLD YELLOW');
				print "\n";
			}
			elsif ($type == $ERRORS{'CRITICAL'}) {
				print colored("ERROR: $message", 'BOLD YELLOW ON_RED');
				print "\n";
			}
			elsif ($calling_subroutine =~ /migrate_vm/) {
				if ($type == $ERRORS{'DEBUG'}) {
					print colored("$message", 'WHITE');
				}
				elsif ($type == $ERRORS{'OK'}) {
					print colored($message, 'WHITE');
				}
				print "\n";
			}
			VCL::utils::notify($type, $log, $message);
		};
	}

	my $management_node_name = $self->data->get_management_node_short_name();
	my $provisioning_object_type = ref($self);
	
	#...........................................................................
	# Get the computer info for the VM to be migrated
	my $vm_data = $self->create_datastructure_object({computer_identifier => $vm_identifier});
	if (!$vm_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_identifier, failed to create DataStructure object for VM");
		return;
	}
	
	my $vm_computer_id = $vm_data->get_computer_id();
	my $vm_computer_name = $vm_data->get_computer_short_name();
	my $source_vmhost_id = $vm_data->get_vmhost_id(0);
	my $source_vmhost_computer_id = $vm_data->get_vmhost_computer_id(0);
	my $source_vmhost_computer_name = $vm_data->get_vmhost_short_name(0);
	
	# Make sure VM is assigned to a VM host
	if (!$source_vmhost_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, VM host ID is not set for computer");
		return;
	}
	
	# Check if VM is responding
	my $vm_os_perl_package = $vm_data->get_image_os_module_perl_package();
	#my $vm_os_responding_before = $vm_os->is_ssh_responding(); 
	#if ($vm_os_responding_before) {
	#	# Determine the OS perl package to use to control the VM and create an OS object
	#	notify($ERRORS{'DEBUG'}, 0, "attempting to log in to $vm_computer_name and determine OS currently loaded");
	#	$vm_os_perl_package = VCL::Module::OS::get_os_perl_package($vm_computer_name);
	#	if ($vm_os_perl_package) {
	#		notify($ERRORS{'DEBUG'}, 0, "retrieved OS currently loaded on $vm_computer_name, $vm_os_perl_package module will be used");
	#	}
	#	else {
	#		$vm_os_perl_package = $vm_data->get_image_os_module_perl_package();
	#		notify($ERRORS{'WARNING'}, 0, "failed to determine OS currently loaded on $vm_computer_name, using OS currently loaded according to database: $vm_os_perl_package");
	#	}
	#}
	#else {
	#	if ($SETUP_MODE) {
	#		notify($ERRORS{'WARNING'}, 0, "$vm_computer_name is not responding to SSH");
	#		if (!setup_confirm("Continue to migrate the VM?", "N")) {
	#			return;
	#		}
	#	}
	#	$vm_os_perl_package = $vm_data->get_image_os_module_perl_package();
	#}
	
	
	my $vm_os = VCL::Module::create_object($vm_os_perl_package, $vm_data);
	if ($vm_os) {
		notify($ERRORS{'OK'}, 0, "created object to control VM $vm_computer_name (type: $vm_os_perl_package)");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create $vm_os_perl_package object to control VM $vm_computer_name");
		return;
	}
	if ($SETUP_MODE && $vm_os->can("initialize")) {
		if (!$vm_os->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize " . ref($vm_os) . " object for VM $vm_computer_name");
			return;
		}
	}
	
	
	#...........................................................................
	# Create an OS object for the source VM host
	my $source_vmhost_os = $self->create_vmhost_os_object($source_vmhost_id);
	if ($source_vmhost_os) {
		my $source_vmhost_os_type = ref($source_vmhost_os);
		notify($ERRORS{'OK'}, 0, "created OS object to control source VM host: $source_vmhost_computer_name (VM host computer ID: $source_vmhost_computer_id, type: $source_vmhost_os_type)");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to create OS object to control source VM host: $source_vmhost_computer_name (VM host computer ID: $source_vmhost_computer_id)");
		return;
	}
	if ($SETUP_MODE && $source_vmhost_os->can("initialize")) {
		if (!$source_vmhost_os->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize " . ref($source_vmhost_os) . " OS object for source VM host");
			return;
		}
	}
	
	# Create a provisioning object for the source VM host
	my $source = $self->create_object(
		$provisioning_object_type,
		{ computer_identifier => $vm_computer_id, vmhost_identifier => $source_vmhost_id },
		{ vmhost_os => $source_vmhost_os }
	);
	if ($source) {
		notify($ERRORS{'OK'}, 0, "created $provisioning_object_type object for source VM host: $source_vmhost_computer_name (VM host ID: $source_vmhost_id, type: $provisioning_object_type)");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create $provisioning_object_type object for source VM host: $source_vmhost_computer_name (VM host ID: $source_vmhost_id)");
		return;
	}
	if ($SETUP_MODE && $source->can("initialize")) {
		if (!$source->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize " . ref($source) . " provisioning object for source VM host");
			return;
		}
	}

	$source->set_os($vm_os);
	$vm_os->set_provisioner($source);
	
	#...........................................................................
	# Create an OS object for the destination VM host
	my $destination_vmhost_os = $self->create_vmhost_os_object($destination_vmhost_identifier);
	if (!$destination_vmhost_os) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to create OS object to control destination VM host: $destination_vmhost_identifier");
		return;
	}
	if ($SETUP_MODE && $destination_vmhost_os->can("initialize")) {
		if (!$destination_vmhost_os->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize " . ref($destination_vmhost_os) . " OS object for destination VM host");
			return;
		}
	}
	
	my $destination_vmhost_computer_id = $destination_vmhost_os->data->get_computer_id(0);
	my $destination_vmhost_computer_name = $destination_vmhost_os->data->get_computer_short_name(0);
	
	my $destination_vmhost_os_type = ref($destination_vmhost_os);
	notify($ERRORS{'OK'}, 0, "created OS object to control destination VM host: $destination_vmhost_computer_name, type: $destination_vmhost_os_type");
	
	# Create a provisioning object for the destination VM host
	my $destination = $self->create_object(
		$provisioning_object_type,
		{ computer_identifier => $vm_computer_id, vmhost_identifier => $destination_vmhost_identifier },
		{ vmhost_os => $destination_vmhost_os }
	);
	if ($destination) {
		notify($ERRORS{'OK'}, 0, "created $provisioning_object_type object for destination VM host: $destination_vmhost_identifier");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create $provisioning_object_type object for destination VM host: $destination_vmhost_identifier");
		return;
	}
	if ($SETUP_MODE && $destination->can("initialize")) {
		if (!$destination->initialize()) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize " . ref($destination) . " provisioning object for destination VM host");
			return;
		}
	}
	
	my $destination_vmhost_id = $destination->data->get_vmhost_id();

	#...........................................................................
	# Make sure the source and destination VM hosts are different
	if ($source_vmhost_id == $destination_vmhost_id) {
		notify($ERRORS{'WARNING'}, 0, "migration failed, $vm_computer_name is already assigned to VM host identified by the destination argument: $destination_vmhost_identifier (VM host computer name: $destination_vmhost_computer_name, VM host ID: $destination_vmhost_id)");
		return;
	}
	
	#...........................................................................
	# Configure host to host SSH
	if (!($source->configure_root_ssh_key() &&
			$source->add_ssh_root_key_to_authorized_keys($destination) &&
			$source->add_ssh_host_key_to_known_hosts($destination)
		)) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to configure SSH access between $source_vmhost_computer_name and $destination_vmhost_computer_name");
		return;
	}
	
	$source->api->firewall_ruleset_enable('sshClient');
	
	my $source_remote_connection_target = determine_remote_connection_target($source_vmhost_computer_name);
	my $destination_remote_connection_target = determine_remote_connection_target($destination_vmhost_computer_name);
	
	my $source_outbound_22_ruleset_info = $source->api->get_matching_firewall_ruleset_info('out', 22);
	for my $ruleset_name (keys %$source_outbound_22_ruleset_info) {
		if (!$source->api->firewall_ruleset_allow_ip($ruleset_name, $destination_remote_connection_target)) {
			notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to add $destination_remote_connection_target to $ruleset_name on $source_vmhost_computer_name");
			return;
		}
	}
	
	my $destination_inbound_22_ruleset_info = $destination->api->get_matching_firewall_ruleset_info('in', 22);
	for my $ruleset_name (keys %$destination_inbound_22_ruleset_info) {
		if (!$destination->api->firewall_ruleset_allow_ip($ruleset_name, $source_remote_connection_target)) {
			notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to add $source_remote_connection_target to $ruleset_name on $destination_vmhost_computer_name");
			return;
		}
	}
	
	my ($exit_status, $output) = $source->vmhost_os->execute({
		command => "ssh -o ConnectTimeout=5 -o ConnectionAttempts=1 -i /.ssh/id_rsa $destination_remote_connection_target hostname",
		display_output => 1,
		timeout_seconds => 5,
		max_attempts => 1,
	});
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, failed to verify SSH access between $source_vmhost_computer_name and $destination_vmhost_computer_name");
		return;
	}

	# Find the .vmx file on the source VM host
	my @source_vmx_file_paths = $source->api->get_registered_vms();
	my @matching_source_vmx_file_paths = grep(/\/$vm_computer_name\_[^\/]*\.vmx$/i, @source_vmx_file_paths);
	if (!@matching_source_vmx_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, did not find a matching .vmx file on source VM host $source_vmhost_computer_name:\n" . join("\n", @source_vmx_file_paths));
		return;
	}
	elsif (scalar(@matching_source_vmx_file_paths) > 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to migrate VM: $vm_computer_name, found multiple matching .vmx files on source VM host $source_vmhost_computer_name:\n" . join("\n", @matching_source_vmx_file_paths));
		return;
	}
	my $source_vmx_file_path = $matching_source_vmx_file_paths[0];
	notify($ERRORS{'DEBUG'}, 0, "found matching .vmx file on source VM host $source_vmhost_computer_name: $source_vmx_file_path");
	$source->set_vmx_file_path($source_vmx_file_path);
	
	my $source_vmx_file_name = $source->get_vmx_file_name();
	my $source_vmx_directory_name = $source->get_vmx_directory_name();
	my $source_vmx_directory_path = $source->get_vmx_directory_path();
	my $source_vmx_directory_url_path = $source->_get_url_path($source_vmx_directory_path);
	my $source_vmx_base_directory_path = $source->get_vmx_base_directory_path();
	my $source_vmx_base_directory_url_path = $source->_get_url_path($source_vmx_base_directory_path);
	
	
	# Possible TODO: if problems occur using VMware's suspend/resume, try OS's hibernate
	# Figure out if VMware's suspend or the guest OS's hibernate should be used
	# Check if source vmx contains any values known to cause problems with VMware's suspend/resume
	my $source_vmx_info = $source->get_vmx_info($source_vmx_file_path);
	
	
	#...........................................................................
	# Check if the source VM is powered on
	my $vm_power_status_before = $source->power_status($source_vmx_file_path);
	if (!defined($vm_power_status_before)) {
		notify($ERRORS{'WARNING'}, 0, "migration failed, failed to determine power status of source VM $vm_computer_name on $source_vmhost_computer_name");
		return;
	}
	elsif ($vm_power_status_before !~ /on/i) {
		if ($SETUP_MODE) {
			notify($ERRORS{'WARNING'}, 0, "$vm_computer_name power status is not on: $vm_power_status_before");
			#if (!setup_confirm("Continue to migrate the VM?", "N")) {
			#	return;
			#}
		}
	}
	
	# Check if the source VM OS is responding
	my $vm_os_responding_before = $vm_os->is_ssh_responding();
	#if (!$vm_os_responding_before) {
	#	if ($SETUP_MODE) {
	#		notify($ERRORS{'WARNING'}, 0, "$vm_computer_name is not responding to SSH");
	#		if (!setup_confirm("Continue to migrate the VM?", "N")) {
	#			return;
	#		}
	#	}
	#}
	
	#...........................................................................
	# Determine how to suspend or power off the source VM
	if (!$vm_os_responding_before) {
		if ($suspend_method =~ /^(os)$/) {
			notify($ERRORS{'WARNING'}, 0, "'$suspend_method' suspend method is not possible because VM's OS is not responding before migration, VMware suspend method will be used");
			$suspend_method = 'vmware';
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$suspend_method\-based suspend method will be used");
	}
	
	#my $problematic_suspend_parameters = {
	#	'mks.enable3d' => 'true',
	#	'svga.yes3d' => 'true',
	#};
	#for my $problematic_suspend_parameter (sort keys %$problematic_suspend_parameters) {
	#	my $problematic_suspend_value = $problematic_suspend_parameters->{$problematic_suspend_parameter};
	#	my ($source_vmx_parameter) = grep { $_ =~ /$problematic_suspend_parameter/i } sort keys %$source_vmx_info;
	#	if (!$source_vmx_parameter) {
	#		notify($ERRORS{'DEBUG'}, 0, "source vmx file does not contain the parameter: $problematic_suspend_parameter");
	#		next;
	#	}
	#	
	#	my $source_vmx_value = $source_vmx_info->{$source_vmx_parameter};
	#	notify($ERRORS{'DEBUG'}, 0, "source vmx file contains the parameter: $problematic_suspend_parameter = $source_vmx_value");
	#	if ($source_vmx_value =~ /^$problematic_suspend_value$/i) {
	#		notify($ERRORS{'DEBUG'}, 0, "source VM vmx file contains $source_vmx_parameter=$source_vmx_value, computer may not be able to start on destination VM host if VMware's suspend/resume method is used, checking if guest OS's hibernate method may be used");
	#		$suspend_method = 'os';
	#		last;
	#	}
	#}
	# Perform additional checks if VMware's suspend/resume can't be used
	if ($suspend_method eq 'os') {
		# Check if the VM OS object implements a hibernate subroutine
		if (!$vm_os->can('hibernate')) {
			notify($ERRORS{'WARNING'}, 0, "unable to migrate $vm_computer_name, VMware suspend/resume cannot be used and $vm_os_perl_package module does not implement a 'hibernate' subroutine");
			return;
		}
	}
	notify($ERRORS{'DEBUG'}, 0, "source VM suspend/hibernate method: " . ($suspend_method eq 'vmware' ? 'VMware suspend' : 'guest OS hibernate'));
	
	
	# Figure out the destination vmx file path
	my $destination_vmx_directory_name = $source_vmx_directory_name;
	my $destination_vmx_base_directory_path = $destination->get_vmx_base_directory_path();
	my $destination_vmx_base_directory_url_path = $destination->_get_url_path($destination_vmx_base_directory_path);
	
	# Check if source and destination were to use the same vmx directory
	# This causes problems where the destination VM won't power on - not sure why
	# The vmware.log file will contain information related to the VM hosts having different CPU features
	# For some reason, using a different directory seems to solve the problem
	#    015-04-29T18:32:21.581Z| vmx| I120: evcMasksInCpt = 0
	#    015-04-29T18:32:21.581Z| vmx| I120: evcCompatibilityMode = 0
	#    015-04-29T18:32:21.581Z| vmx| I120: Error: This host has a usermode feature set incompatible with the host on which it was suspended.
	#    015-04-29T18:32:21.581Z| vmx| I120: Host: 0x02982203, Checkpoint: 0x00982201
	#    015-04-29T18:32:21.581Z| vmx| I120: CPUID test failed: 1.ecx.
	#    015-04-29T18:32:21.582Z| vmx| I120: Msg_Question:
	#    015-04-29T18:32:21.582Z| vmx| I120: [msg.checkpoint.cpucheck.fail.feature] The features supported by the processors in this machine are different from the features supported by the processors in the machine on which the virtual machine state was saved.
	#    015-04-29T18:32:21.582Z| vmx| I120: [msg.checkpoint.cpucheck.fail.hard] Resume on a machine with similar processors.
	#    015-04-29T18:32:21.582Z| vmx| I120: [msg.checkpoint.restore.cpufail] An error occurred while restoring the CPU state from file "/vmfs/volumes/55410273-6261f90c-8568-00053348d88e/shared/arkvmm194_3081-v5/arkvmm194_3081-v5-9478be0b.vmss".
	#    015-04-29T18:32:21.582Z| vmx| I120: [msg.checkpoint.resume.softError] Your virtual machine did not resume because of a correctable error. Preserve the suspended state and correct the error, or discard the suspended state.
	if ($source_vmx_directory_url_path eq "$destination_vmx_base_directory_url_path/$source_vmx_directory_name") {
		$destination_vmx_directory_name .= "_$destination_vmhost_computer_name";
		notify($ERRORS{'DEBUG'}, 0, "source and destination VM use the same vmx directory: $source_vmx_directory_url_path, changing destination vmx directory name to avoid problems powering on the destination VM: $destination_vmx_directory_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "source and destination VM use different vmx directories:\nsource: $source_vmx_directory_url_path\ndestination: $destination_vmx_base_directory_url_path/$source_vmx_directory_name");
	}
	
	# Construct destination vmx file path
	my $destination_vmx_file_path = "$destination_vmx_base_directory_path/$destination_vmx_directory_name/$source_vmx_file_name";
	$destination->set_vmx_file_path($destination_vmx_file_path);
	
	my $destination_vmx_directory_path = $destination->get_vmx_directory_path();
	my $destination_vmx_directory_url_path = $destination->_get_url_path($destination_vmx_directory_path);
	
	# Check if the source and destination working directories are on the same datastore
	my $source_vmx_datastore_root_url_path = $source->_get_datastore_root_url_path($source_vmx_file_path);
	my $destination_vmx_datastore_root_url_path = $destination->_get_datastore_root_url_path($destination_vmx_file_path);
	my $same_vmx_datastore = ($source_vmx_datastore_root_url_path eq $destination_vmx_datastore_root_url_path ? 1 : 0);
	if ($same_vmx_datastore) {
		notify($ERRORS{'OK'}, 0, "source and destination VM hosts use the same datastore for the VM's working directory: $source_vmx_datastore_root_url_path");
	}
	else {
		notify($ERRORS{'OK'}, 0, "source and destination VM hosts do not use the same datastore for the VM's working directory:\n" .
			"   $source_vmhost_computer_name: $source_vmx_datastore_root_url_path\n" .
			"   $destination_vmhost_computer_name: $destination_vmx_datastore_root_url_path"
		);
	}
	
	#...........................................................................
	# Create a snapshot of the source
	# This is to reduce the amount of data to copy while the VM is hibernating
	notify($ERRORS{'DEBUG'}, 0, "attempting to create snapshot of $vm_computer_name on $source_vmhost_computer_name");
	$source->snapshot() || return;
	notify($ERRORS{'OK'}, 0, "created snapshot of $vm_computer_name on $source_vmhost_computer_name");
	
	# Figure out the parent .vmdk file being used by the source VM
	my @source_vmdk_file_paths = $self->api->get_vm_virtual_disk_file_paths($source_vmx_file_path);
	if (!@source_vmdk_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "failed to migrate VM, source vmdk file paths could not be retrieved");
		return;
	}
	elsif (scalar(@source_vmdk_file_paths) > 1) {
		# Don't allow multiple vmdk's for now
		# TODO: add support for this, need to check if destination has enough space
		# Also need to check if disks are affected by snapshots. If not, need to copy while VM is suspended
		notify($ERRORS{'DEBUG'}, 0, "$vm_computer_name contains multiple virtual disks, only the migration of single virtual disk VMs is currently supported");
	}
	
	# VM may have multiple virtual disks
	my @source_primary_vmdk_file_paths = @{$source_vmdk_file_paths[0]};
	if (!@source_primary_vmdk_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "failed to migrate VM, source primary vmdk file paths could not be determined from virtual disk file path info:\n" . format_data(\@source_primary_vmdk_file_paths));
		return;
	}
	
	# The first file path should be the master/golden vmdk
	my $source_master_vmdk_file_path = $source_primary_vmdk_file_paths[0];
	notify($ERRORS{'DEBUG'}, 0, "determined source master vmdk file path: $source_master_vmdk_file_path");
	
	# Set the vmdk file path in the source VMware object
	$source->set_vmdk_file_path($source_master_vmdk_file_path);
	my $source_vmdk_file_path = $source->get_vmdk_file_path();
	
	# The last file path is actively being used by the VM
	my $source_active_vmdk_file_path = $source_primary_vmdk_file_paths[-1];
	my $source_active_vmdk_file_base_name = $self->_get_file_base_name($source_active_vmdk_file_path);
	notify($ERRORS{'DEBUG'}, 0, "determined source active vmdk file path: $source_active_vmdk_file_path");
	
	# Construct destination vmdk file path
	my $source_vmdk_directory_name = $source->get_vmdk_directory_name();
	my $source_vmdk_file_name = $source->get_vmdk_file_name();
	my $destination_vmdk_base_directory_path = $destination->get_vmdk_base_directory_path();
	my $destination_vmdk_file_path = "$destination_vmdk_base_directory_path/$source_vmdk_directory_name/$source_vmdk_file_name";
	
	# Set the vmdk file path in the destination VMware object
	$destination->set_vmdk_file_path($destination_vmdk_file_path);
	
	# Needed for search/replace
	my $source_vmdk_base_directory_path = $source->get_vmdk_base_directory_path();
	my $source_vmdk_base_directory_url_path = $source->_get_url_path($source_vmdk_base_directory_path);
	my $destination_vmdk_base_directory_url_path = $destination->_get_url_path($destination_vmdk_base_directory_path);
	
	# Check if source and destination vmdk directories are different
	my $source_vmdk_directory_path = $source->get_vmdk_directory_path();
	my $source_vmdk_directory_url_path = $source->_get_url_path($source_vmdk_directory_path);
	my $destination_vmdk_directory_path = $destination->get_vmdk_directory_path();
	my $destination_vmdk_directory_url_path = $destination->_get_url_path($destination_vmdk_directory_path);
	my $same_vmdk_directory = ($source_vmdk_directory_url_path eq $destination_vmdk_directory_url_path ? 1 : 0);
	
	# Check if the source vmdk directory is dedicated to the VM
	my $source_vmdk_directory_path_dedicated = $source->get_vmdk_directory_path_dedicated();
	my $source_vmdk_directory_url_path_dedicated = $source->_get_url_path($source_vmdk_directory_path_dedicated);
	if ($source_vmdk_directory_url_path_dedicated eq $source_vmdk_directory_url_path || $source_vmdk_directory_name =~ /^$vm_computer_name/) {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory is dedicated: $source_vmdk_directory_url_path_dedicated");
		
		# Override the destination vmdk file path
		$destination->set_vmdk_file_path($destination->get_vmdk_file_path_dedicated());
		$destination_vmdk_file_path = $destination->get_vmdk_file_path();
		$destination_vmdk_directory_path = $destination->get_vmdk_directory_path();
		$destination_vmdk_directory_url_path = $destination->_get_url_path($destination_vmdk_directory_path);
		$destination->{vm_dedicated} = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "vmdk directory is NOT dedicated:\n" .
			"source vmdk directory path: $source_vmdk_directory_url_path\n" .
			"source vmdk dedicated path: $source_vmdk_directory_url_path_dedicated"
		);
	}
	
	my $source_vmdk_file_url_path = $source->_get_url_path($source_vmdk_file_path);
	my $destination_vmdk_file_url_path = $destination->_get_url_path($destination_vmdk_file_path);

	# Copy the parent vmdk to the correct location on the destination
	# This may fail if vmdk doesn't exist on destination datastore or repository
	if (!$same_vmdk_directory) {
		notify($ERRORS{'DEBUG'}, 0, "copying destination master vmdk if necessary: $destination_vmdk_file_path");
		if (!$destination->prepare_vmdk()) {
			notify($ERRORS{'WARNING'}, 0, "failed to copy destination master vmdk: $destination_vmdk_file_path");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "copying destination master vmdk not necessary, source and destination VMs will use the same vmdk path");
	}
	
	# Create the destination directory
	if ($destination->vmhost_os->file_exists($destination_vmx_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "directory already exists on destination VM host $destination_vmhost_computer_name: $destination_vmx_directory_path, attempting to delete directory");
		$destination->vmhost_os->delete_file($destination_vmx_directory_path) || return;
	}
	
	if ($destination->vmhost_os->create_directory($destination_vmx_directory_path)) {
		notify($ERRORS{'OK'}, 0, "created directory on destination VM host $destination_vmhost_computer_name: $destination_vmx_directory_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create directory on destination VM host $destination_vmhost_computer_name: $destination_vmx_directory_path");
		return;
	}
	
	# Get a list of all files in the source VM directory
	# Check each file:
	#    build list of files that can only be copied after VM hibernates: @source_active_file_paths
	#    build list of files that need to be modified: @destination_edit_file_paths
	my @source_vmx_directory_file_paths = $source->vmhost_os->find_files($source_vmx_directory_path, '*');
	my @source_active_file_paths;
	my @destination_edit_file_paths;
	if (!@source_vmx_directory_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, no files were found in source vmx directory on $source_vmhost_computer_name: $source_vmx_directory_path");
		$destination->vmhost_os->delete_file($destination_vmx_directory_path);
		return;
	}
	for my $source_file_path (@source_vmx_directory_file_paths) {
		my $source_file_name = $self->_get_file_name($source_file_path);
		my $destination_file_path = "$destination_vmx_directory_path/$source_file_name";
		
		# Ignore these files, they aren't required on the destination in order for the VM to run
		if ($source_file_path =~ /(\.log|vmx~|\.vswp|\.lck|-core\.gz|zdump\.|\.vmss)/) {
			#notify($ERRORS{'DEBUG'}, 0, "file will not be copied: $source_file_name");
			next;
		}
		
		# Keep list of files which contain datastore names/paths specific to the source VM host
		# These will be searched/replaced later on
		if ($source_file_path !~ /(-delta|-flat|\.vmss|Snapshot)/) {
			push @destination_edit_file_paths, $destination_file_path;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "destination file will not be altered: $destination_file_path");
		}
		
		# Keep list of files in use by the source VM which is still running
		# These will be copied after the VM hibernates
		# .vmx file gets updated when VM is suspended
		if ($source_file_path =~ /($source_active_vmdk_file_base_name[\.-].*\.vmdk|\.vmx)/) {
			push @source_active_file_paths, $source_file_path;
			notify($ERRORS{'DEBUG'}, 0, "file is actively being used by the source VM or may change during suspend, will be copied after source VM is suspended: $source_file_name");
			next;
		}
		
		# Attempt to retrieve the source file size - useful info to present because copy may take a long time
		my $source_file_size_bytes = $source->vmhost_os->get_file_size($source_file_path);
		my $file_size_string = '';
		if ($source_file_size_bytes) {
			$file_size_string = ' (' . get_file_size_info_string($source_file_size_bytes) . ')';
		}
		
		notify($ERRORS{'DEBUG'}, 0, "copying file to destination: $destination_vmhost_computer_name:$destination_file_path" . $file_size_string);
		
		if ($same_vmx_datastore && $source->vmhost_os->copy_file($source_file_path, $destination_file_path)) {
			notify($ERRORS{'OK'}, 0, "copied file on source VM host: $source_file_path --> $destination_file_path");
		}
		elsif ($source->copy_file_to_another_host($source_file_path, $destination, $destination_file_path)) {
			#notify($ERRORS{'OK'}, 0, "copied file to destination: $destination_vmhost_computer_name:$destination_file_path");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to copy file from source to destination VM host: $source_vmhost_computer_name:$source_file_path --> $destination_vmhost_computer_name:$destination_file_path");
			$destination->vmhost_os->delete_file($destination_vmx_directory_path);
			return;
		}
	}

	# Suspend/hibernate the source VM - the amount of time the VM is unavailable should be minimized
	# Do as much as possible before this step
	# Keep track of how long the VM is inaccessible
	my $hibernate_start_time = time;
	if ($vm_power_status_before =~ /on/i) {
		if ($suspend_method eq 'vmware') {
			notify($ERRORS{'DEBUG'}, 0, "attempting to suspend $vm_computer_name on source VM host $source_vmhost_computer_name");
			if ($self->api->vm_suspend($source_vmx_file_path)) {
				notify($ERRORS{'OK'}, 0, "suspended $vm_computer_name on source VM host $source_vmhost_computer_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to suspend source VM");
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
				return;
			}
		}
		elsif ($suspend_method eq 'shutdown') {
			notify($ERRORS{'DEBUG'}, 0, "attempting to shutdown guest OS of $vm_computer_name");
			if (!$vm_os->shutdown()) {
				notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to shutdown VM's guest OS");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempting to hibernate guest OS of $vm_computer_name");
			if ($vm_os->hibernate()) {
				notify($ERRORS{'OK'}, 0, "hibernated guest OS of $vm_computer_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to hibernate VM's guest OS");
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
				return;
			}
		}
	}
	
	# Update computer.vmhostid
	# Do this before completing the destination VM - it would be more difficult to revert things if the update were to fail after a successful migration
	if (update_computer_vmhost_id($vm_computer_id, $destination_vmhost_id)) {
		notify($ERRORS{'OK'}, 0, "updated VM host $vm_computer_name is assigned to in the database (VM host ID: $destination_vmhost_id)");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to update computer.vmhostid column in database");
		migrate_revert_source($source, $vm_os);
		$destination->vmhost_os->delete_file($destination_vmx_directory_path);
		return;
	}
	
	# Get the .vmss file path(s) created when the VM was suspended
	my @source_vmss_file_paths = $source->vmhost_os->find_files($source_vmx_directory_path, '*.vmss');
	push @source_active_file_paths, @source_vmss_file_paths;
	@source_active_file_paths = remove_array_duplicates(@source_active_file_paths);
	
	# Copy the files that were actively being used by the source VM
	for my $source_file_path (@source_active_file_paths) {
		my $file_name = $self->_get_file_name($source_file_path);
		my $destination_file_path = "$destination_vmx_directory_path/$file_name";
		
		# Attempt to retrieve the source file size - useful info to present because copy may take a long time
		my $source_file_size_bytes = $source->vmhost_os->get_file_size($source_file_path);
		my $file_size_string = '';
		if ($source_file_size_bytes) {
			$file_size_string = ' (' . get_file_size_info_string($source_file_size_bytes) . ')';
		}
		
		notify($ERRORS{'DEBUG'}, 0, "copying file to destination: $destination_vmhost_computer_name:$destination_file_path" . $file_size_string);
		if ($same_vmx_datastore && $source->vmhost_os->copy_file($source_file_path, $destination_file_path)) {
			notify($ERRORS{'OK'}, 0, "copied file on source VM host: $source_file_path --> $destination_file_path");
		}
		elsif ($source->copy_file_to_another_host($source_file_path, $destination, $destination_file_path)) {
			notify($ERRORS{'OK'}, 0, "copied file to destination VM host: $destination_vmhost_computer_name:$destination_file_path");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to copy file which was actively being used by the VM from source to destination VM host after the VM hibernated: $source_vmhost_computer_name:$source_file_path --> $destination_vmhost_computer_name:$destination_file_path");
			migrate_revert_source($source, $vm_os);
			$destination->vmhost_os->delete_file($destination_vmx_directory_path);
			return;
		}
	}
	
	# Update files on destination which have paths specific to the source VM host
	my @file_replacements;
	
	push @file_replacements, [$source_vmdk_file_path, $destination_vmdk_file_path];
	push @file_replacements, [$source_vmdk_file_url_path, $destination_vmdk_file_url_path];
	
	push @file_replacements, ["$source_vmx_directory_path/", "$destination_vmx_directory_path/"];
	push @file_replacements, ["$source_vmx_directory_url_path/", "$destination_vmx_directory_url_path/"];
	
	push @file_replacements, ["$source_vmdk_directory_path/", "$destination_vmdk_directory_path/"];
	push @file_replacements, ["$source_vmdk_directory_url_path/", "$destination_vmdk_directory_url_path/"];
	
	push @file_replacements, ["$source_vmx_base_directory_path/", "$destination_vmx_base_directory_path/"];
	push @file_replacements, ["$source_vmx_base_directory_url_path/", "$destination_vmx_base_directory_url_path/"];
	
	push @file_replacements, ["$source_vmdk_base_directory_path/", "$destination_vmdk_base_directory_path/"];
	push @file_replacements, ["$source_vmdk_base_directory_url_path/", "$destination_vmdk_base_directory_url_path/"];

	for my $destination_file_path (@destination_edit_file_paths) {
		notify($ERRORS{'DEBUG'}, 0, "updating file on $destination_vmhost_computer_name: $destination_file_path");
		SOURCE_PATTERN: for my $file_replacement (@file_replacements) {
			my ($source_pattern, $destination_pattern) = @$file_replacement;
			next if ($source_pattern eq $destination_pattern);
			
			my $sed_command = "sed -i -e \"s|$source_pattern|$destination_pattern|g\" $destination_file_path";
			my ($sed_exit_status, $sed_output) = $destination->vmhost_os->execute($sed_command, 0);
			if (!defined($sed_output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to execute command on destination VM host $destination_vmhost_computer_name: $sed_command");
				migrate_revert_source($source, $vm_os);
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
				return;
			}
			elsif (grep(/sed:/, @$sed_output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to update file on destination VM host $destination_vmhost_computer_name, exit status: $sed_exit_status\ncommand:\n$sed_command\noutput:\n" . join("\n", @$sed_output));
				migrate_revert_source($source, $vm_os);
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
				return;
			}
			else {
				#notify($ERRORS{'OK'}, 0, "updated file on $destination_vmhost_computer_name: $destination_file_path, pattern: $source_pattern --> $destination_pattern");
			}
		}
		notify($ERRORS{'OK'}, 0, "updated file on $destination_vmhost_computer_name: $destination_file_path");
	}
	
	# Register the VM on the destination VM host
	notify($ERRORS{'DEBUG'}, 0, "registering VM on destination VM host $destination_vmhost_computer_name: $destination_vmx_file_path");
	if ($destination->api->vm_register($destination_vmx_file_path)) {
		notify($ERRORS{'OK'}, 0, "registered VM on destination VM host $destination_vmhost_computer_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to register VM on destination VM host $destination_vmhost_computer_name: $destination_vmx_file_path");
		migrate_revert_source($source, $vm_os);
		if ($revert_destination_on_error) {
			$destination->vmhost_os->delete_file($destination_vmx_directory_path);
		}
		return;
	}
	
	# Power on the VM on the destination VM host
	notify($ERRORS{'DEBUG'}, 0, "powering on $vm_computer_name on destination VM host $destination_vmhost_computer_name: $destination_vmx_file_path");
	
	if ($vm_power_status_before !~ /off/i) {
		if ($destination->api->vm_power_on($destination_vmx_file_path)) {
			notify($ERRORS{'OK'}, 0, "powered on $vm_computer_name on $destination_vmhost_computer_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, failed to power on VM on destination VM host $destination_vmhost_computer_name: $destination_vmx_file_path");
			migrate_revert_source($source, $vm_os);
			if ($revert_destination_on_error) {
				$destination->api->vm_unregister($destination_vmx_file_path);
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
			}
			return;
		}
		
		# Wait for the destination VM to respond
		notify($ERRORS{'DEBUG'}, 0, "waiting for $vm_computer_name to respond to SSH on destination VM host $destination_vmhost_computer_name");
		if ($vm_os->wait_for_ssh(300, 3)) {
			my $hibernate_duration = (time - $hibernate_start_time);
			notify($ERRORS{'OK'}, 0, "$vm_computer_name is responding to SSH on destination VM host $destination_vmhost_computer_name, hibernation duration: $hibernate_duration seconds");
			
			if ($vm_os_responding_before) {
				# Remove the original VM from the source VM host
				notify($ERRORS{'DEBUG'}, 0, "deleting original VM from $source_vmhost_computer_name: $source_vmx_file_path");
				$source->delete_vm($source_vmx_file_path);
				notify($ERRORS{'OK'}, 0, "deleted original VM from $source_vmhost_computer_name: $source_vmx_file_path");
			}
			else {
				# Unregister the original VM from the source VM host -- don't delete in case something went wrong
				notify($ERRORS{'DEBUG'}, 0, "unregistering original VM from $source_vmhost_computer_name: $source_vmx_file_path");
				$source->api->vm_unregister($source_vmx_file_path);
				notify($ERRORS{'OK'}, 0, "unregistered original VM from $source_vmhost_computer_name: $source_vmx_file_path");
			}
		}
		elsif (!$vm_os_responding_before) {
			notify($ERRORS{'WARNING'}, 0, "$vm_computer_name was not responding to SSH prior to migration and never responded on destination VM host $destination_vmhost_computer_name");
			
			# Unregister the original VM from the source VM host -- don't delete in case something went wrong
			notify($ERRORS{'DEBUG'}, 0, "unregistering original VM from $source_vmhost_computer_name: $source_vmx_file_path");
			$source->api->vm_unregister($source_vmx_file_path);
			notify($ERRORS{'OK'}, 0, "unregistered original VM from $source_vmhost_computer_name: $source_vmx_file_path");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to migrate $vm_computer_name, VM never responded on destination VM host $destination_vmhost_computer_name");
			migrate_revert_source($source, $vm_os);
			if ($revert_destination_on_error) {
				$destination->api->vm_unregister($destination_vmx_file_path);
				$destination->vmhost_os->delete_file($destination_vmx_directory_path);
			}
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "skipping power on of $vm_computer_name on $destination_vmhost_computer_name, VM's power status was not 'on' on source VM host $source_vmhost_computer_name: $vm_power_status_before");
	}
	
	notify($ERRORS{'OK'}, 0, "migration of $vm_computer_name complete: $source_vmhost_computer_name --> $destination_vmhost_computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 migrate_revert_source

 Parameters  : $source, $vm_os
 Returns     : boolean
 Description : Called if a VM migration fails. Powers the original VM back on
               and reverts the computer.vmhostid value for the VM.

=cut

sub migrate_revert_source {
	my ($source, $vm_os) = @_;
	if (!$source || !ref($source) || ref($source) !~ /VMware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "first argument is not a VMware object reference");
		return;
	}
	elsif (!$vm_os || !ref($vm_os) || ref($vm_os) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "third argument is not an OS object reference");
		return;
	}
	
	my $vm_computer_id = $vm_os->data->get_computer_id();
	my $vm_computer_name = $vm_os->data->get_computer_short_name();
	my $source_vmhost_computer_name = $source->vmhost_os->data->get_computer_short_name();
	my $source_vmhost_id = $source->data->get_vmhost_id();
	
	my $error_occurred = 0;
	
	# Change computer.vmhostid back to the source VM host
	if (!update_computer_vmhost_id($vm_computer_id, $source_vmhost_id)) {
		notify($ERRORS{'CRITICAL'}, 0, "migration failed, failed to set VM host ID of $vm_computer_name back to source VM host ID: $source_vmhost_id");
		$error_occurred = 1;
	}
	
	# Power the source VM back on
	if (!$source->power_on()) {
		notify($ERRORS{'CRITICAL'}, 0, "migration failed, failed to power $vm_computer_name back on after it hibernated on source VM host $source_vmhost_computer_name");
		$error_occurred = 1;
	}
	
	# Wait for the source VM to respond
	if (!$vm_os->wait_for_ssh(300, 5)) {
		notify($ERRORS{'CRITICAL'}, 0, "migration failed, source VM $vm_computer_name never responded after it was powered back on after hibernation on $source_vmhost_computer_name");
		$error_occurred = 1;
	}
	
	if ($error_occurred) {
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "reverted VM $vm_computer_name on source VM host $source_vmhost_computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_datastore_directory_semaphore

 Parameters  : $path, $total_wait_seconds (optional)
 Returns     : VCL::Module::Semaphore object, false, or undefined
 Description : Obtains a semaphore for exclusive access to the directory on the
               datastore.

=cut

sub get_datastore_directory_semaphore {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($datastore_directory_path, $total_wait_seconds) = @_;
	if (!defined($datastore_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "datastore directory path argument was not supplied");
		return;
	}
	
	$total_wait_seconds = 300 unless $total_wait_seconds;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to obtain semaphore for datastore directory: $datastore_directory_path");
	
	my $datastore_url = $self->_get_datastore_url($datastore_directory_path);
	if (!$datastore_url) {
		notify($ERRORS{'WARNING'}, 0, "failed to obtain semaphore, datastore URL could not be determined for path: $datastore_directory_path");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "determined datastore URL: $datastore_url");
	
	my $directory_name;
	if ($datastore_directory_path =~ /\.[^\/]+$/) {
		# Argument appears to be a file path, use the parent directory name
		$directory_name = $self->_get_parent_directory_name($datastore_directory_path);
		if (!$directory_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to obtain semaphore, argument appears to be a file path: $datastore_directory_path, parent directory name could not be determined");
			return;
		}
		notify($ERRORS{'DEBUG'}, 0, "argument appears to be a file path: $datastore_directory_path, using parent directory name for semaphore ID: $directory_name");
	}
	else {
		$directory_name = $self->_get_file_base_name($datastore_directory_path);
		if (!$directory_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to obtain semaphore, argument appears to be a directory path: $datastore_directory_path, base name could not be determined");
			return;
		}
		notify($ERRORS{'DEBUG'}, 0, "argument appears to be a directory path: $datastore_directory_path, using directory name for semaphore ID: $directory_name");
	}
	
	my $semaphore_identifier = $datastore_url . '/' . $directory_name;
	my $semaphore = $self->get_semaphore($semaphore_identifier, $total_wait_seconds);
	if ($semaphore) {
		notify($ERRORS{'DEBUG'}, 0, "obtained semaphore with identifier '$semaphore_identifier', returning semaphore object");
		return $semaphore;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to obtain semaphore with identifier '$semaphore_identifier', returning 0");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
