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

VCL::Provisioning::VIX_API

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for VMWare VIX API
 http://www.vmware.com

=cut

##############################################################################
package VCL::Module::Provisioning::VMware::VIX_API;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::VMware::VMware);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;

use VMware::Vix::Simple;
use VMware::Vix::API::Constants;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 %VIX_PROPERTY_VM

 Data type   : hash
 Description : Contains a mapping between numerical and textual
               VIX_PROPERTY_VM_* properties

=cut

our %VIX_PROPERTY_VM;
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_NUM_VCPUS)}          = 'VM_NUM_VCPUS';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_VMX_PATHNAME)}       = 'VM_VMX_PATHNAME';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_VMTEAM_PATHNAME)}    = 'VM_VMTEAM_PATHNAME';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_MEMORY_SIZE)}        = 'VM_MEMORY_SIZE';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_READ_ONLY)}          = 'VM_READ_ONLY';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_IN_VMTEAM)}          = 'VM_IN_VMTEAM';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_POWER_STATE)}        = 'VM_POWER_STATE';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_TOOLS_STATE)}        = 'VM_TOOLS_STATE';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_IS_RUNNING)}         = 'VM_IS_RUNNING';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_SUPPORTED_FEATURES)} = 'VM_SUPPORTED_FEATURES';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_IS_RECORDING)}       = 'VM_IS_RECORDING';
$VIX_PROPERTY_VM{eval(VIX_PROPERTY_VM_IS_REPLAYING)}       = 'VM_IS_REPLAYING';

=head2 %VIX_POWERSTATE

 Data type   : hash
 Description : Contains a mapping between numerical and textual
               VIX_POWERSTATE_* properties

=cut

our %VIX_POWERSTATE;
$VIX_POWERSTATE{eval(VIX_POWERSTATE_POWERING_OFF)}   = 'POWERING_OFF';   # power off has been called but not completed
$VIX_POWERSTATE{eval(VIX_POWERSTATE_POWERED_OFF)}    = 'POWERED_OFF';    # VM is not running
$VIX_POWERSTATE{eval(VIX_POWERSTATE_POWERING_ON)}    = 'POWERING_ON';    # power on has been called but not completed
$VIX_POWERSTATE{eval(VIX_POWERSTATE_POWERED_ON)}     = 'POWERED_ON';     # VM is running
$VIX_POWERSTATE{eval(VIX_POWERSTATE_SUSPENDING)}     = 'SUSPENDING';     # suspend has been called but not completed
$VIX_POWERSTATE{eval(VIX_POWERSTATE_SUSPENDED)}      = 'SUSPENDED';      # VM is suspended
$VIX_POWERSTATE{eval(VIX_POWERSTATE_TOOLS_RUNNING)}  = 'TOOLS_RUNNING';  # VM is running and the VMware Tools is active
$VIX_POWERSTATE{eval(VIX_POWERSTATE_RESETTING)}      = 'RESETTING';      # reset has been called but not completed
$VIX_POWERSTATE{eval(VIX_POWERSTATE_BLOCKED_ON_MSG)} = 'BLOCKED_ON_MSG'; # VM state change is blocked, waiting for user interaction

##############################################################################

=head1 API OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_power_state

 Parameters  : $vmx_path
 Returns     : string
 Description : Determines the power state of the VM specified by the vmx file
               path argument and returns a string containing one of the
               following values:
               -on
               -off
               -suspended
               -blocked

=cut

sub get_vm_power_state {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	my $attempt = 0;
	my $attempt_limit = 3;
	my $attempt_delay = 5;
	my @power_states;
	while ($attempt < $attempt_limit) {
		$attempt++;
		(@power_states = $self->_get_vm_power_states($vix_vmx_path)) || return;
		my $return_state;
		if (grep(/POWERED_OFF/, @power_states)) {
			$return_state = "off";
		}
		elsif (grep(/POWERED_ON/, @power_states)) {
			$return_state = "on";
		}
		elsif (grep(/SUSPENDED/, @power_states)) {
			$return_state = "suspended";
		}
		elsif (grep(/BLOCKED_ON_MSG/, @power_states)) {
			$return_state = "blocked";
		}
		else {
			notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: VM $vix_vmx_path in a transition power state (@power_states), sleeping for $attempt_delay");
			sleep $attempt_delay;
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "VM $vix_vmx_path power state: $return_state");
		return $return_state;
	}
	
	notify($ERRORS{'WARNING'}, 0, "VM $vix_vmx_path is still in a transition power state (@power_states)");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_registered_vms

 Parameters  : none
 Returns     : array
 Description : Retrieves a list of the running VMs on the VM host. Returns an
               array containing the vmx file paths of the running VMs.

=cut

sub get_registered_vms {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_base_directory_path = $self->get_vmx_base_directory_path() || return;
	(my @registered_vms = $self->_find_items(VIX_FIND_REGISTERED_VMS)) || return;
	
	# Convert the vmx paths back to the normal non-VIX format
	for (my $i=0; $i<scalar(@registered_vms); $i++) {
		$registered_vms[$i] =~ s/\s*\[.+\]\s*/$vmx_base_directory_path\//ig;
	}
	return @registered_vms;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_power_off

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Powers off the VM specified by the vmx file path argument.

=cut

sub vm_power_off {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the VM handle
	my $vm_handle = $self->_get_vm_handle($vix_vmx_path) || return;
	
	# Call VMPowerOff
	notify($ERRORS{'DEBUG'}, 0, "attempting to power off VM: $vix_vmx_path");
	my ($error) = VMPowerOff($vm_handle, VIX_VMPOWEROP_NORMAL);
	if ($error == VIX_OK) {
		notify($ERRORS{'DEBUG'}, 0, "powered off VM: $vix_vmx_path");
		return 1;
	}
	elsif ($error == VIX_E_VM_NOT_RUNNING) {
		notify($ERRORS{'DEBUG'}, 0, "VM is not running: $vix_vmx_path");
		return 1;
	}
	else {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to power off VM: $vix_vmx_path, error: $error, $error_text");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_power_on

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Powers on the VM specified by the vmx file path argument.

=cut

sub vm_power_on {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the VM handle
	my $vm_handle = $self->_get_vm_handle($vix_vmx_path) || return;
	
	# Call VMPowerOn
	notify($ERRORS{'DEBUG'}, 0, "attempting to power on VM: $vix_vmx_path");
	my ($error) = VMPowerOn($vm_handle, VIX_VMPOWEROP_NORMAL, VIX_INVALID_HANDLE);
	if ($error == VIX_OK) {
		notify($ERRORS{'DEBUG'}, 0, "powered on VM: $vix_vmx_path");
		return 1;
	}
	else {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to power on VM: $vix_vmx_path, error: $error, $error_text");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_vm_registered

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Determines if the VM specified by the vmx file path argument is
               registered.

=cut

sub is_vm_registered {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Make sure the VM is registered
	my @registered_vms = $self->get_registered_vms();
	if (!@registered_vms) {
		notify($ERRORS{'DEBUG'}, 0, "there are no registered VMs");
		return 0;
	}
	
	# Loop through the registered VMs and try to find a match
	# Can't use grep because the vmx paths contain square brackets
	for my $registered_vmx_path (@registered_vms) {
		my $registered_vix_vmx_path = $self->_get_datastore_path($registered_vmx_path);
		if ($vix_vmx_path eq $registered_vix_vmx_path) {
			notify($ERRORS{'DEBUG'}, 0, "VM is registered: $vix_vmx_path");
			return 1;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "VM is not registered: $vix_vmx_path");
	
	if (defined($self->{vm_handle}{$vix_vmx_path})) {
		ReleaseHandle($self->{vm_handle}{$vix_vmx_path});
	}
	
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_register

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Registers the VM specified by the vmx file path argument. Returns
               true if the VM is successfully registered or if it is already
               registered.

=cut

sub vm_register {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the VM host handle
	my $host_handle = $self->_get_host_handle() || return;
	
	# Make sure the VM is not already registered
	if ($self->is_vm_registered($vix_vmx_path)) {
		notify($ERRORS{'OK'}, 0, "VM is already registered: $vix_vmx_path");
		return 1;
	}
	
	# Call RegisterVM
	notify($ERRORS{'DEBUG'}, 0, "attempting to register VM: $vix_vmx_path");
	my ($error) = RegisterVM($host_handle, $vix_vmx_path);
	if ($error != VIX_OK) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to register VM: $vix_vmx_path, error: $error, $error_text");
		return;
	}
	
	# Make sure the VM was successfully registered
	if ($self->is_vm_registered($vix_vmx_path)) {
		notify($ERRORS{'OK'}, 0, "registered VM: $vix_vmx_path");
		return 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "VM is NOT registered, VIX did not return an error");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_unregister

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Unregisters the VM specified by the vmx file path argument.
               Returns true if the VM is successfully unregistered or if it was
               not registered to begin with.

=cut

sub vm_unregister {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the VM host handle
	my $host_handle = $self->_get_host_handle() || return;
	
	# Make sure the VM is registered
	if (!$self->is_vm_registered($vix_vmx_path)) {
		notify($ERRORS{'OK'}, 0, "VM is not registered: $vix_vmx_path");
		return 1;
	}
	
	# Make sure the VM is powered off
	# If the VM is on and unregistered, the unregister command will succeed but the VM remains registered
	my $power_state = $self->get_vm_power_state($vix_vmx_path) || return;
	if ($power_state ne 'off') {
		$self->vm_power_off($vix_vmx_path) || return;
	}
	
	# Call RegisterVM
	notify($ERRORS{'DEBUG'}, 0, "attempting to unregister VM: $vix_vmx_path");
	my ($error) = UnregisterVM($host_handle, $vix_vmx_path);
	if ($error != VIX_OK) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM: $vix_vmx_path, error: $error, $error_text");
		return;
	}
	
	# Make sure the VM was unregistered
	if (!$self->is_vm_registered($vix_vmx_path)) {
		notify($ERRORS{'OK'}, 0, "unregistered VM: $vix_vmx_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "VM is still registered, VIX did not return an error");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_restricted

 Parameters  : none
 Returns     : boolean
 Description : Determines if remote access to the VM host via the VIX API is
               restricted due to the type of VMware license being used on the
               host. 0 is returned if remote access is not restricted. 1 is
               returned if remote access is restricted and the access to the VM
               host is read-only.

=cut

sub is_restricted {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the VM host handle
	my $host_handle = $self->_get_host_handle() || return;
	
	# Call RegisterVM
	notify($ERRORS{'DEBUG'}, 0, "checking if access to the VM host via the VIX API is restricted due to the license");
	my ($error) = RegisterVM($host_handle, '');
	
	if ($error == VIX_E_LICENSE) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'DEBUG'}, 0, "access to the VM host via the VIX API is restricted due to the license, result of attempting to register a VM: $error_text");
		return 1;
	}
	else {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'DEBUG'}, 0, "access to the VM host via the VIX API is NOT restricted due to the license");
		return 0;
	}
}

##############################################################################

=head1 PRIVATE API OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Initialized the VMware VIX API object by obtaining a VM host
               handle. False is returned if a host handle cannot be obtained.

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	$self->_get_host_handle() || return;
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _find_items

 Parameters  : $search_type, $timeout_seconds (optional)
 Returns     : array
 Description : Exposes the VMware VIX API FindItems function. It searches for
               VMs matching the search type argument. The search type values:
               -VIX_FIND_RUNNING_VMS (1)
               -VIX_FIND_REGISTERED_VMS (4)

=cut

sub _find_items {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the VM host handle argument
	my $host_handle = $self->_get_host_handle() || return;
	
	# Get the search type argument
	my $search_type = shift;
	if (!defined($search_type)) {
		notify($ERRORS{'WARNING'}, 0, "search type argument was not supplied");
		return;
	}
	
	# Get the optional timeout seconds argument
	my $timeout_seconds = shift || 15;
	
	# Check if the search type is valid and set a string
	my $search_type_string;
	if ($search_type == VIX_FIND_RUNNING_VMS) {
		$search_type_string = 'running VMs';
	}
	elsif ($search_type == VIX_FIND_REGISTERED_VMS) {
		$search_type_string = 'registered VMs';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unsupported search type specified: search_type");
	}
	notify($ERRORS{'DEBUG'}, 0, "attempting to find $search_type_string");
	
	# Call FindItems
	my ($error, @vm_list) = FindItems($host_handle, $search_type, $timeout_seconds);
	if ($error) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to find VMs, error: $error, $error_text");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@vm_list) . " $search_type_string:\n" . join("\n", @vm_list));
		return @vm_list;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_host_handle

 Parameters  : none
 Returns     : boolean
 Description : Obtains a VM host handle and stores it in the VIX API object.

=cut

sub _get_host_handle {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if the host handle has already been obtained
	if (defined($self->{host_handle}) || $self->{host_handle}) {
		return $self->{host_handle};
	}
	
	my $host_hostname = $self->data->get_vmhost_hostname();
	my $host_username = $self->data->get_vmhost_profile_username();
	my $host_password = $self->data->get_vmhost_profile_password();
	my $host_port = '8333';
	my $host_service_provider = $self->_get_vix_service_provider();

	# Assemble the URLs to try
	my @host_url_possibilities = (
		"https://$host_hostname/sdk",
		"https://$host_hostname:$host_port/sdk",
		"http://$host_hostname/sdk",
		"http://$host_hostname:$host_port/sdk",
	);
	
	# Call HostConnect, check how long it takes to connect
	for my $host_url (@host_url_possibilities) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to connect to VM host: $host_url");
		my ($error, $host_handle) = HostConnect(VIX_API_VERSION,
															 $host_service_provider,
															 $host_url,
															 $host_port,
															 $host_username,
															 $host_password,
															 0,
															 VIX_INVALID_HANDLE);
		
		# Check if an error occurred
		if ($error == VIX_OK) {
			notify($ERRORS{'DEBUG'}, 0, "connected to VM host $host_url");
			$self->{host_handle} = $host_handle;
			return $self->{host_handle};
		}
		else {
			my $error_text = GetErrorText($error);
			notify($ERRORS{'DEBUG'}, 0, "unable to connect to VM host using URL: $host_url, error: $error, $error_text");
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to connect to VM host using any of the possible URLs");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_handle

 Parameters  : $vmx_file_path
 Returns     : VIX VM handle object
 Description : Obtains a VM handle for the VM specified by the vmx path
               argument.

=cut

sub _get_vm_handle {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path formatted for VIX
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# If a VM handle was previously obtained, release it
	if ($self->{vm_handle}{$vix_vmx_path}) {
		ReleaseHandle($self->{vm_handle}{$vix_vmx_path});
	}
	
	# Get the host handle
	my $host_handle = $self->_get_host_handle() || return;
	
	# Call HostOpenVM
	notify($ERRORS{'DEBUG'}, 0, "attempting to obtain VM handle: $vix_vmx_path");
	my ($error, $vm_handle) = HostOpenVM($host_handle,
	                                     $vix_vmx_path,
	                                     VIX_VMOPEN_NORMAL,
	                                     VIX_INVALID_HANDLE);
	
	# Check if error occurred
	if ($error != VIX_OK) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to obtain VM handle: $vix_vmx_path, error: $error, $error_text");
		return;
	}
	else {
		$self->{vm_handle}{$vix_vmx_path} = $vm_handle;
		return $self->{vm_handle}{$vix_vmx_path};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_power_states

 Parameters  : $vmx_path
 Returns     : array
 Description : Retrieves the power state names for the VM specified by the vmx
               path argument. An array containing the names is returned. Valid
               power state names are:
               -POWERING_OFF
               -POWERED_OFF
               -POWERING_ON
               -POWERED_ON
               -SUSPENDING
               -SUSPENDED
               -TOOLS_RUNNING
               -RESETTING
               -BLOCKED_ON_MSG


=cut

sub _get_vm_power_states {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the power state property
	my ($power_state_id) = $self->_get_properties($vix_vmx_path, VIX_PROPERTY_VM_POWER_STATE);
	if (!$power_state_id) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve power state property for VM: $vix_vmx_path");
		return;
	}
	
	# There may be multiple power states in effect, the value returned must be evaluated bitwise against the valid power state IDs
	my @powerstate_names;
	my $powerstate_string;
	for my $vix_powerstate_id (keys %VIX_POWERSTATE) {
		if ($power_state_id & $vix_powerstate_id) {
			unshift @powerstate_names, $VIX_POWERSTATE{$vix_powerstate_id};
			$powerstate_string .= "$VIX_POWERSTATE{$vix_powerstate_id} ($vix_powerstate_id), ";
		}
	}
	$powerstate_string =~ s/, $//;
	
	notify($ERRORS{'DEBUG'}, 0, "power states for VM: $vix_vmx_path:\n" . join("\n", @powerstate_names));
	return @powerstate_names;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_properties

 Parameters  : $vm_handle, $property_id_1, $property_id_2...
 Returns     : array
 Description : Exposes the VIX GetProperties function to retrieve the properties
               of a handle.

=cut

sub _get_properties {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx path and format it for the VIX API
	my $vix_vmx_path = $self->_get_datastore_path(shift) || return;
	
	# Get the VM handle argument
	my $vm_handle = $self->_get_vm_handle($vix_vmx_path) || return;
	
	# Get the property ID argument
	my @property_ids = @_;
	if (!@property_ids) {
		notify($ERRORS{'WARNING'}, 0, "property ID arguments were not supplied");
		return;
	}
	
	# Make sure the property IDs are valid
	my $property_name_string;
	for my $property_id (@property_ids) {
		if (!defined($VIX_PROPERTY_VM{$property_id})) {
			notify($ERRORS{'WARNING'}, 0, "unsupported property ID was passed as an argument: $property_id");
			return;
		}
		$property_name_string .= "$VIX_PROPERTY_VM{$property_id} ($property_id), ";
	}
	$property_name_string =~ s/, $//;
	
	# Call GetProperties
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve values of properties: $property_name_string");
	my ($error, @property_values) = GetProperties($vm_handle, @property_ids);
	if ($error) {
		my $error_text = GetErrorText($error);
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve values of properties: $property_name_string, error: $error, $error_text");
		return;
	}
	
	# Make sure the property ID array is the same size as the value array
	if (scalar(@property_ids) != scalar(@property_values)) {
		notify($ERRORS{'WARNING'}, 0, "property ID count " . scalar(@property_ids) . " does not match the number of properties returned by GetProperties " . scalar(@property_values));
		return;
	}
	
	# Assemble a string showing the names and values of the properties retrieved
	my $property_value_string;
	for (my $i=0; $i<scalar(@property_ids); $i++) {
		my $property_id = $property_ids[$i];
		my $property_name = $VIX_PROPERTY_VM{$property_id};
		my $property_value = $property_values[$i];
		$property_value_string .= "$property_name ($property_id) = $property_value\n"
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved properties:\n$property_value_string");
	
	return @property_values;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_path

 Parameters  : $file_path
 Returns     : string
 Description : Converts the file path argument to a datastore path.

=cut

sub _get_datastore_path {
	my ($self) = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not supplied");
		return;
	}
	
	# Per the VIX documentation:
	# For VMware Server 1.x, supply the full path name instead of the datastore path
	# Also, if the path already contains a '[' assume it's a datastore path and return it unaltered
	my $host_service_provider = $self->_get_vix_service_provider() || return;
	if ($host_service_provider == VIX_SERVICEPROVIDER_VMWARE_SERVER || $path =~ /\[/) {
		return $path;
	}
	
	my $datastore_name;
	my $relative_datastore_path;
	
	if ($path =~ /^\/vmfs\/volumes\//) {
		($datastore_name) = $path =~ /\/vmfs\/volumes\/([^\/]+)/;
		($relative_datastore_path) = $path =~ /$datastore_name\/(.*)/;
	}
	else {
		$datastore_name = 'standard';
		
		my $vmx_base_directory_path = $self->get_vmx_base_directory_path() || return;
		($relative_datastore_path) = $path =~ /$vmx_base_directory_path\/(.*)/;
	}
	
	$relative_datastore_path =~ s/(^[\s\/]+|[\s\/]+$)//g if $relative_datastore_path;
	
	if (!$datastore_name || !$relative_datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine datastore name and relative datastore path from path: $path");
		return;
	}
	
	return "[$datastore_name] $relative_datastore_path";
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vix_service_provider

 Parameters  : none
 Returns     : integer
 Description : Determines the appropriate VIX_SERVICEPROVIDER value to use
               depending on the VMware product being used. Per the VMware VIX
               documentation:
               vCenter Server, ESX/ESXi hosts, VMware Server 2.0: VIX_SERVICEPROVIDER_VMWARE_VI_SERVER
               VMware Workstation:                                VIX_SERVICEPROVIDER_VMWARE_WORKSTATION
               VMware Player:                                     VIX_SERVICEPROVIDER_VMWARE_PLAYER
               VMware Server 1.0.x:                               VIX_SERVICEPROVIDER_VMWARE_SERVER

=cut

sub _get_vix_service_provider {
	my ($self) = @_;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Return the value stored in this object if it has already been determined
	return $self->{service_provider} if $self->{service_provider};
	
	# Check the VM host type name, figure out which VMware product is being used and set the object's service_provider key
	# Use VIX_SERVICEPROVIDER_VMWARE_VI_SERVER as the default value since it's most common
	my $vmhost_type_name = $self->data->get_vmhost_type_name();
	if ($vmhost_type_name =~ /(workstation)/i) {
		$self->{service_provider} = VIX_SERVICEPROVIDER_VMWARE_WORKSTATION;
		notify($ERRORS{'DEBUG'}, 0, "VM type is $vmhost_type_name, using service provider: VIX_SERVICEPROVIDER_VMWARE_WORKSTATION");
	}
	elsif ($vmhost_type_name =~ /(player)/i) {
		$self->{service_provider} = VIX_SERVICEPROVIDER_VMWARE_PLAYER;
		notify($ERRORS{'DEBUG'}, 0, "VM host type is $vmhost_type_name, using service provider: VIX_SERVICEPROVIDER_VMWARE_PLAYER");
	}
	elsif ($vmhost_type_name =~ /^(vmwareGSX|vmwarefreeserver|.*1\..*)$/i) {
		$self->{service_provider} = VIX_SERVICEPROVIDER_VMWARE_SERVER;
		notify($ERRORS{'DEBUG'}, 0, "VM host type is $vmhost_type_name, using service provider: VIX_SERVICEPROVIDER_VMWARE_SERVER");
	}
	else {
		$self->{service_provider} = VIX_SERVICEPROVIDER_VMWARE_VI_SERVER;
		notify($ERRORS{'DEBUG'}, 0, "VM host type is $vmhost_type_name, using service provider: VIX_SERVICEPROVIDER_VMWARE_VI_SERVER");
	}
	
	return $self->{service_provider};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : true
 Description : Called when the VIX API object is destroyed. Disconnects the host
               handle.

=cut

sub DESTROY {
	my $self = shift;
	notify($ERRORS{'DEBUG'}, 0, "destructor called, ref(\$self)=" . ref($self));
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	# Disconnect from the VM host if connected
	HostDisconnect($self->{host_handle}) if $self->{host_handle};
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
