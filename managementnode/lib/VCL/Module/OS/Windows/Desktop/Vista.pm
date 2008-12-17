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
# $Id: Vista.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::OS::Windows::Desktop::Vista.pm - VCL module to support Windows Vista operating system

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows Vista.

=cut

##############################################################################
package VCL::Module::OS::Windows::Desktop::Vista;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows::Desktop);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use VCL::Module::Provisioning::xCAT;
use File::Basename;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $CONFIGURATION_FILES

 Data type   : Scalar
 Description : Location of script/utilty/configuration files needed to
               configure the OS. This is normally the directory under
					the 'tools' directory specific to this OS.

=cut

our $CONFIGURATION_DIRECTORY = "$TOOLS/Sysprep_Vista";

# Node variables
our $NODE_CONFIGURATION_DIRECTORY = 'C:/VCL';

=head2 $ROOT_PASSWORD

 Data type   : Scalar
 Description : Password for the node's root account.

=cut

our $ROOT_PASSWORD = $WINDOWS_ROOT_PASSWORD;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 post_reload

 Parameters  :
 Returns     :
 Description :

=cut

sub post_reload {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys     = $self->data->get_management_node_keys();
	my $image_name               = $self->data->get_image_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	notify($ERRORS{'OK'}, 0, "beginning Windows Vista post-reload preparation tasks: $image_name on $computer_node_name");
	
	# Run NewSID
	if (!$self->run_newsid()) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, unable to run newsid.exe on $computer_node_name");
		return 0;
	}
	
	# Reboot the computer in order for the newsid changes to take effect
	if (!$self->reboot()) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to reboot computer after disabling pagefile");
		return 0;
	}
	
	# Set KMS licensing
	if (!$self->set_kms_licensing()) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to configure node for KMS licensing");
		return 0;
	}
	
	# Activate
	if (!$self->activate_licensing()) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to activate licensing");
		return 0;
	}
	
	## Randomize root password
	#my $root_random_password = getpw();
	#if (!$self->set_password('root', $root_random_password)) {
	#	notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to set random root password");
	#	return 0;
	#}
	
	# Randomize Administrator password
	my $administrator_random_password = getpw();
	if (!$self->set_password('Administrator', $administrator_random_password)) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to set random Administrator password");
		return 0;
	}
	
	# Disable RDP
	if (!$self->firewall_disable_rdp()) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to disable RDP");
		return 0;
	}
	
	# Set sshd service startup to auto
	if (!$self->set_service_startup_mode('sshd', 'auto')) {
		notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration failed, failed to set sshd service startup mode to auto");
		return 0;
	}
	
	notify($ERRORS{'WARNING'}, 0, "OS post-reload configuration successful, returning 1");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_prepare

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_prepare {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $request_id               = $self->data->get_request_id();
	my $reservation_id           = $self->data->get_reservation_id();
	my $image_id                 = $self->data->get_image_id();
	my $image_os_name            = $self->data->get_image_os_name();
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $image_os_type            = $self->data->get_image_os_type();
	my $image_name               = $self->data->get_image_name();
	my $imagemeta_sysprep        = $self->data->get_imagemeta_sysprep();
	my $computer_id              = $self->data->get_computer_id();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $computer_type            = $self->data->get_computer_type();
	my $user_id                  = $self->data->get_user_id();
	my $user_unityid             = $self->data->get_user_login_id();
	my $managementnode_shortname = $self->data->get_management_node_short_name();
	my $computer_private_ip      = $self->data->get_computer_private_ip();
	
	notify($ERRORS{'OK'}, 0, "beginning Windows Vista image capture preparation tasks: $image_name on $computer_short_name");
	
	# Log off all currently logged in users
	if (!$self->logoff_users()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to log off all currently logged in users on $computer_node_name");
		return 0;
	}
	
	# Set root account password to known value
	if (!$self->set_password('root', $ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to set root password");
		return 0;
	}
	
	# Delete the user assigned to this reservation
	if (!$self->delete_user()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to delete user");
		return 0;
	}
	
	# Disable all RDP access by removing firewall exceptions
	if (!$self->firewall_disable_rdp()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to disable RDP");
		return 0;
	}
	
	# Enable RDP access from private IP addresses by adding a firewall exception
	if (!$self->firewall_enable_rdp('10.0.0.0/8')) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to enable RDP from private IP addresses");
		return 0;
	}
	
$self->firewall_enable_rdp('152.14.52.0/24');
	
	# Enable SSH access from private IP addresses by adding a firewall exception
	if (!$self->firewall_enable_ssh_private()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to enable SSH from private IP addresses");
		return 0;
	}
	
	# Enable ping access from private IP addresses by adding a firewall exception
	if (!$self->firewall_enable_ping_private()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to enable ping from private IP addresses");
		return 0;
	}

	# Create startup scheduled task to prepare computer
	if (!$self->create_startup_scheduled_task('VCL Startup Configuration', $NODE_CONFIGURATION_DIRECTORY . '/Scripts/VCLPrepare.cmd  >> ' . $NODE_CONFIGURATION_DIRECTORY . '/Logs/VCLPrepare.log')) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to create startup scheduled task");
		return 0;
	}
	
	# Remove old configuration files if they exist
	notify($ERRORS{'OK'}, 0, "attempting to remove old configuration directory if it exists: $NODE_CONFIGURATION_DIRECTORY");
	my ($remove_old_status, $remove_old_output) = run_ssh_command($computer_node_name, $management_node_keys, "/usr/bin/rm.exe -rf $NODE_CONFIGURATION_DIRECTORY");
	if (defined($remove_old_status) && $remove_old_status == 0) {
		notify($ERRORS{'OK'}, 0, "removed existing configuration directory: $NODE_CONFIGURATION_DIRECTORY");
	}
	elsif (defined($remove_old_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing configuration directory: $NODE_CONFIGURATION_DIRECTORY, exit status: $remove_old_status, output:\n@{$remove_old_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run ssh command to remove existing configuration directory: $NODE_CONFIGURATION_DIRECTORY");
		return 0;
	}

	# Copy configuration files
	notify($ERRORS{'OK'}, 0, "copying image capture configuration files to $computer_short_name");
	if (run_scp_command($CONFIGURATION_DIRECTORY, "$computer_node_name:$NODE_CONFIGURATION_DIRECTORY/", $management_node_keys)) {
		notify($ERRORS{'OK'}, 0, "copied $CONFIGURATION_DIRECTORY directory to $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");

		notify($ERRORS{'OK'}, 0, "attempting to set permissions on $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
		if (run_ssh_command($computer_node_name, $management_node_keys, "/usr/bin/chmod.exe -R 777 $NODE_CONFIGURATION_DIRECTORY")) {
			notify($ERRORS{'OK'}, 0, "chmoded -R 777 $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not chmod -R 777 $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
		}
	} ## end if (run_scp_command($CONFIGURATION_DIRECTORY, "$computer_node_name:C:\/Sysprep"...
	else {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to copy $CONFIGURATION_DIRECTORY to $computer_node_name");
		return 0;
	}
	
	# Disagle autoadminlogon before disabling the pagefile and rebooting
	# There is no need to automatically logon after the reboot
	if (!$self->disable_autoadminlogon()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to disable autoadminlogon");
		return 0;
	}
	
	# Make sure sshd service is set to auto
	if (!_set_sshd_startmode($computer_node_name, "auto")) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to set sshd service startup mode to auto on $computer_node_name");
		return 0;
	}
	
	# Disable IPv6
	if (!$self->disable_ipv6()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to disable IPv6");
		return 0;
	}
	
	# Call script to clean up the hard drive
	my $cleanup_command = $NODE_CONFIGURATION_DIRECTORY . '/Scripts/cleanup_hard_drive.cmd > ' . $NODE_CONFIGURATION_DIRECTORY . '/logs/cleanup_hard_drive.log';
	my ($cleanup_status, $cleanup_output) = run_ssh_command($computer_node_name, $management_node_keys, $cleanup_command);
	if (defined($cleanup_status) && $cleanup_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully ran cleanup script");
	}
	elsif (defined($cleanup_status)) {
		notify($ERRORS{'OK'}, 0, "capture preparation failed, failed to run cleanup script, exit status: $cleanup_status, output:\n@{$cleanup_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run cleanup script");
		return 0;
	}
	
## Defragment the hard drive
#if (!$self->defragment_hard_drive()) {
#	notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to defragment the hard drive");
#	return 0;
#}

	# Disable and delete the pagefile
	# This will set the registry key to disable the pagefile, reboot, then delete pagefile.sys
	if (!$self->disable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to disable pagefile");
		return 0;
	}
	
	# ********* node reboots *********
	
	# Run ipconfig /all
	my ($ipconfig_status, $ipconfig_output) = run_ssh_command($computer_node_name, $management_node_keys, "ipconfig /all");
	if (defined($ipconfig_status) && $ipconfig_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully ran ipconfig /all");
	}
	elsif (defined($ipconfig_status)) {
		notify($ERRORS{'OK'}, 0, "capture preparation failed, failed to run ipconfig /all, exit status: $ipconfig_status, output:\n@{$ipconfig_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run ssh command to execute ipconfig /all");
		return 0;
	}

	# so we don't have conflicts we should set the public adapter back to dhcp
	# this change is immediate
	# figure out  which adapter it public
	my $myadapter;
	my ($privateadapter, $publicadapter);
	
	# build hash of needed info and set the correct private adapter.
	my $id = 1;
	my %ip;
	foreach my $ipconfig_line (@{$ipconfig_output}) {
		#notify($ERRORS{'DEBUG'}, 0, "ipconfig line: $ipconfig_line");
		if ($ipconfig_line =~ /Ethernet adapter (.*):/) {
			$myadapter                 = $1;
			$ip{$myadapter}{"id"}      = $id;
			$ip{$myadapter}{"private"} = 0;
			notify($ERRORS{'DEBUG'}, 0, "adapter found: $myadapter, id: $id");
		}
		if ($ipconfig_line =~ /IP Address([\s.]*): $computer_private_ip/) {
			$ip{$myadapter}{"private"} = 1;
			notify($ERRORS{'DEBUG'}, 0, "$myadapter: private");
		}
		if ($ipconfig_line =~ /Physical Address([\s.]*): ([-0-9]*)/) {
			$ip{$myadapter}{"MACaddress"} = $2;
			notify($ERRORS{'DEBUG'}, 0, "$myadapter MAC address: $2");
		}
		$id++;
	} ## end foreach my $ipconfig_line (@{$sshcmd[1]})

	foreach my $key (keys %ip) {
		if (defined($ip{$key}{private})) {
			if (!($ip{$key}{private})) {
				$publicadapter = $key;
				notify($ERRORS{'DEBUG'}, 0, "public adapter: $key");
			}
		}
	}

	# Use netsh to set the public adapter to use DHCP
	my $set_dhcp_command = '$SYSTEMROOT/System32/netsh.exe interface ip set address name="' . $publicadapter . '" source=dhcp';
	my ($set_dhcp_status, $set_dhcp_output) = run_ssh_command($computer_node_name, $management_node_keys, $set_dhcp_command);
	if (defined($set_dhcp_status) && $set_dhcp_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully set public adapter '$publicadapter' to use dhcp");
	}
	elsif (defined($set_dhcp_status)) {
		notify($ERRORS{'OK'}, 0, "capture preparation failed, unable to set public adapter '$publicadapter' to use dhcp, exit status: $set_dhcp_status, output:\n@{$set_dhcp_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to run ssh command to set public adapter '$publicadapter' to use dhcp");
		return 0;
	}

	# Reenable the pagefile, this will take effect when the saved image boots
	if (!$self->enable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to reenable pagefile");
		return 0;
	}

	## Enable autoadminlogon
	#if (!$self->enable_autoadminlogon()) {
	#	notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to enable autoadminlogon");
	#	return 0;
	#}

	## Add a RunOnce registry key to run VCLprepare.cmd when the captured image comes up
	#if (!$self->add_runonce_registry_value("VCL Prepare", 'C:\\\\VCL\\\\Scripts\\\\VCLprepare.cmd')) {
	#	notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to add runonce registry value to call VCLprepare.cmd");
	#	return 0;
	#}

	# Set sshd service startup mode to manual
	if (!$self->set_service_startup_mode('sshd', 'manual')) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to set sshd service startup mode to manual");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_prepare

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_start

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_start {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $request_id               = $self->data->get_request_id();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $image_name               = $self->data->get_image_name();
	
	notify($ERRORS{'OK'}, 0, "initiating Vista image capture: $image_name on $computer_node_name");
	
	# Attempt to reboot the computer, don't wait after reboot is initiated
	if ($self->reboot(0)) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name was rebooted");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture start failed, unable to initiate reboot");
		return 0;
	}
	
	# Wait for computer to become unresponsive
	if ($self->wait_for_shutdown(5)) {
		notify($ERRORS{'OK'}, 0, "reboot was successful, $computer_node_name is unresponsive");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "capture start failed, reboot was not successful, computer is still responding to ping");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_start

#/////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub user_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the user login id from the arguments
	# If not specified, use DataStructure value
	my $user_login_id = shift;
	if (!defined($user_login_id)) {
		$user_login_id = $self->data->get_user_login_id();
	}

	my ($net_user_exit_status, $net_user_output) = run_ssh_command($computer_node_name, $management_node_keys, "net user $user_login_id");
	if (defined($net_user_exit_status) && $net_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "user $user_login_id exists on $computer_node_name");
		return 1;
	}
	elsif ($net_user_exit_status == 2) {
		notify($ERRORS{'OK'}, 0, "user $user_login_id does NOT exist on $computer_node_name");
		return 0;
	}
	elsif ($net_user_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if user $user_login_id exists on $computer_node_name, exit status: $net_user_exit_status, output:\n@{$net_user_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if user $user_login_id exists on $computer_node_name");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 logoff_users

 Parameters  :
 Returns     :
 Description :

=cut

sub logoff_users {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, "qwinsta.exe");
	if ($exit_status > 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe on $computer_node_name, exit status: $exit_status, output:\n@{$output}");
		return;
	}
	elsif (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe SSH command on $computer_node_name");
		return;
	}
	
	my @active_user_lines = grep(/Active/, @{$output});
	
	notify($ERRORS{'OK'}, 0, "users are currently logged in on $computer_node_name: " . @active_user_lines);
	
	foreach my $active_user_line (@active_user_lines) {
		$active_user_line =~ /\s+(\S+)\s+(.*\w)\s*(\d+)\s+Active.*/;
		my $session_name = $1;
		my $username = $2;
		my $session_id = $3;
		
		notify($ERRORS{'DEBUG'}, 0, "user logged in: $username, session name: $session_name, session id: $session_id");
		
		my ($logoff_exit_status, $logoff_output) = run_ssh_command($computer_node_name, $management_node_keys, "logoff.exe /v $session_id");
		if ($logoff_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "logged off user: $username, exit status: $logoff_exit_status, output:\n@{$logoff_output}");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to log off user: $username, exit status: $logoff_exit_status, output:\n@{$logoff_output}");
		}
		
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  : $node, $user, $type, $osname
 Returns     : 1 success 0 failure
 Description : removes user account and profile directory from specificed node

=cut

sub delete_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!(defined($username))) {
		$username = $self->data->get_user_login_id();
	}
	
	notify($ERRORS{'OK'}, 0, "attempting to delete user $username from $computer_node_name");
	
	# Attempt to delete the user account
	my $delete_user_command = "net user $username /DELETE";
	my ($delete_user_exit_status, $delete_user_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_user_command);
	if (defined($delete_user_exit_status) && $delete_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted user $username from $computer_node_name");
	}
	elsif (defined($delete_user_exit_status) && $delete_user_exit_status == 2) {
		notify($ERRORS{'OK'}, 0, "user $username was not deleted, user does not exist");
		return 1;
	}
	elsif (defined($delete_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete user $username from $computer_node_name, exit status: $delete_user_exit_status, output:\n@{$delete_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command delete user $username from $computer_node_name");
		return;
	}

	# Delete the user's home directory
	my $delete_profile_command = "/bin/rm -rf /cygdrive/c/Users/$username";
	my ($delete_profile_exit_status, $delete_profile_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_profile_command);
	if (defined($delete_profile_exit_status) && $delete_profile_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted profile for user $username from $computer_node_name");
	}
	elsif (defined($delete_profile_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete profile for user $username from $computer_node_name, exit status: $delete_profile_exit_status, output:\n@{$delete_profile_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command delete profile for user $username from $computer_node_name");
		return;
	}
	
	return 1;
} ## end sub del_user

#/////////////////////////////////////////////////////////////////////////////

=head2 set_password

 Parameters  : $username, $password
 Returns     : 
 Description : 

=cut

sub set_password {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	my $username = shift;
	my $password = shift;
	
	# If no argument was supplied, use the user specified in the DataStructure
	if (!defined($username) && !defined($password)) {
		$username = $self->data->get_user_logon_id();
		$password = $self->data->get_reservation_password();
	}
	elsif (defined($username) && !defined($password)) {
		notify($ERRORS{'WARNING'}, 0, "password set failed, username $username was passed as an argument but the password was not");
		return 0;
	}
	
	# Attempt to set the password
	notify($ERRORS{'OK'}, 0, "setting password of $username to $password on $computer_node_name");
	my ($set_password_exit_status, $set_password_output) = run_ssh_command($computer_node_name, $management_node_keys, "net user $username '$password'");
	if ($set_password_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "$username password changed to $password on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set password of $username to $password on $computer_node_name, exit status: $set_password_exit_status, output:\n@{$set_password_output}");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_pagefile

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_pagefile {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management]
"PagingFiles"=""
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully set the registry key to disable the pagefile");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable the pagefile");
		return 0;
	}

	# Attempt to reboot the computer in order to delete the pagefile
	if ($self->reboot()) {
		notify($ERRORS{'OK'}, 0, "computer was rebooted after disabling pagefile in the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reboot computer after disabling pagefile");
		return;
	}
	
	# Attempt to delete the pagefile
	my $delete_pagefile_command = "attrib.exe -S -H -R C:/pagefile.sys";
	$delete_pagefile_command .= " && /usr/bin/rm.exe -rfv C:/pagefile.sys";
	my ($delete_pagefile_exit_status, $delete_pagefile_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_pagefile_command);
	if (defined($delete_pagefile_exit_status) && $delete_pagefile_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "pagefile.sys was deleted");
		return 1;
	}
	elsif ($delete_pagefile_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete pagefile.sys, exit status: $delete_pagefile_exit_status, output:\n@{$delete_pagefile_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete pagefile.sys");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_pagefile

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_pagefile {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management]
"PagingFiles"="?:\\\\pagefile.sys"
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully set the registry key to enable the pagefile");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to enable the pagefile");
		return 0;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_ipv6

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_ipv6 {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

; This registry file contains the entries to disable all IPv6 components 
; http://support.microsoft.com/kb/929852

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters]
"DisabledComponents"=dword:ffffffff
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully set the registry keys to disable IPv6");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry keys to disable IPv6");
		return 0;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 import_registry_file

 Parameters  :
 Returns     :
 Description :

=cut

sub import_registry_file {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_file_path = shift;
	if (!defined($registry_file_path) || !$registry_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	
	my $registry_file_contents = `cat $registry_file_path`;
	notify($ERRORS{'DEBUG'}, 0, "registry file contents:\n$registry_file_contents");
	$registry_file_contents =~ s/([\"])/\\$1/gs;
	
	# Specify where on the node the temporary registry file will reside
	my $temp_registry_file_path = 'C:/Cygwin/tmp/vcl_import.reg';
	
	# Echo the registry string to a file on the node	
	my $echo_registry_command = "/usr/bin/echo.exe -E \"$registry_file_contents\" > " . $temp_registry_file_path;
	my ($echo_registry_exit_status, $echo_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $echo_registry_command, '', '', 1);
	if (defined($echo_registry_exit_status) && $echo_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry file contents echoed to $temp_registry_file_path");
	}
	elsif ($echo_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to echo registry file contents to $temp_registry_file_path, exit status: $echo_registry_exit_status, output:\n@{$echo_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to echo registry file contents to $temp_registry_file_path");
		return;
	}
	
	# Run reg.exe IMPORT
	my $import_registry_command .= '"$SYSTEMROOT/System32/reg.exe" IMPORT ' . $temp_registry_file_path;
	my ($import_registry_exit_status, $import_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $import_registry_command, '', '', 1);
	if (defined($import_registry_exit_status) && $import_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry file contents imported from $temp_registry_file_path");
	}
	elsif ($import_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry file contents from $temp_registry_file_path, exit status: $import_registry_exit_status, output:\n@{$import_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry file contents from $temp_registry_file_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 import_registry_string

 Parameters  :
 Returns     :
 Description :

=cut

sub import_registry_string {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_string = shift;
	if (!defined($registry_string) || !$registry_string) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	
	# Escape special characters with a backslash:
	# \
	# "
	#notify($ERRORS{'DEBUG'}, 0, "registry string:\n$registry_string");
	$registry_string =~ s/([\"])/\\$1/gs;
	
	# Replace regular newlines with Windows newlines
	$registry_string =~ s/\n/\r\n/gs;
	
	# Specify where on the node the temporary registry file will reside
	my $temp_registry_file_path = 'C:/Cygwin/tmp/vcl_import.reg';
	
	# Echo the registry string to a file on the node	
	my $echo_registry_command = "/usr/bin/echo.exe -E \"$registry_string\" > " . $temp_registry_file_path;
	my ($echo_registry_exit_status, $echo_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $echo_registry_command, '', '', 1);
	if (defined($echo_registry_exit_status) && $echo_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry string contents echoed to $temp_registry_file_path");
	}
	elsif ($echo_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to echo registry string contents to $temp_registry_file_path, exit status: $echo_registry_exit_status, output:\n@{$echo_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to echo registry string contents to $temp_registry_file_path");
		return;
	}
	
	# Run reg.exe IMPORT
	my $import_registry_command .= '"$SYSTEMROOT/System32/reg.exe" IMPORT ' . $temp_registry_file_path;
	my ($import_registry_exit_status, $import_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $import_registry_command, '', '', 1);
	if (defined($import_registry_exit_status) && $import_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry string contents imported from $temp_registry_file_path");
	}
	elsif ($import_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry string contents from $temp_registry_file_path, exit status: $import_registry_exit_status, output:\n@{$import_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry string contents from $temp_registry_file_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_runonce_registry_value

 Parameters  :
 Returns     :
 Description :

=cut

sub add_runonce_registry_value {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $command_name = shift;
	my $command = shift;
	
	# Escape backslashes, can never have enough...
	$command =~ s/\\/\\\\/g;
	
	# Make sure arguments were supplied
	if (!defined($command_name) && !defined($command)) {
		notify($ERRORS{'WARNING'}, 0, "runonce registry key not added, arguments were not passed correctly");
		return 0;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\RunOnce]
"$command_name"="$command"
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully added runonce registry value, name: $command_name, command: $command");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add runonce registry value, name: $command_name, command: $command");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_startup_scheduled_task

 Parameters  :
 Returns     :
 Description :

=cut

sub create_startup_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $task_name = shift;
	my $task_command = shift;
	
	# Escape backslashes, can never have enough...
	$task_command =~ s/\\/\\\\/g;
	
	# Replace forward slashes with backslashes
	$task_command =~ s/\//\\\\/g;
	
	# Make sure arguments were supplied
	if (!defined($task_name) && !defined($task_command)) {
		notify($ERRORS{'WARNING'}, 0, "startup scheduled task not added, arguments were not passed correctly");
		return;
	}
	
	#SCHTASKS /Create [/S system [/U username [/P [password]]]]
	#    [/RU username [/RP password]] /SC schedule [/MO modifier] [/D day]
	#    [/M months] [/I idletime] /TN taskname /TR taskrun [/ST starttime]
	#    [/RI interval] [ {/ET endtime | /DU duration} [/K] [/XML xmlfile] [/V1]]
	#    [/SD startdate] [/ED enddate] [/IT | /NP] [/Z] [/F]
	#
	#Description:
	#    Enables an administrator to create scheduled tasks on a local or
	#    remote system.
	#
	#Parameter List:
	#    /S   system        Specifies the remote system to connect to. If omitted
	#                       the system parameter defaults to the local system.
	#
	#    /U   username      Specifies the user context under which SchTasks.exe 
	#                       should execute.
	#
	#    /P   [password]    Specifies the password for the given user context.
	#                       Prompts for input if omitted.
	#
	#    /RU  username      Specifies the "run as" user account (user context)
	#                       under which the task runs. For the system account,
	#                       valid values are "", "NT AUTHORITY\SYSTEM"
	#                       or "SYSTEM".
	#                       For v2 tasks, "NT AUTHORITY\LOCALSERVICE" and 
	#                       "NT AUTHORITY\NETWORKSERVICE" are also available as well 
	#                       as the well known SIDs for all three. 
	#
	#    /RP  [password]    Specifies the password for the "run as" user. 
	#                       To prompt for the password, the value must be either
	#                       "*" or none. This password is ignored for the 
	#                       system account. Must be combined with either /RU or
	#                       /XML switch.
	#
	#    /SC   schedule     Specifies the schedule frequency.
	#                       Valid schedule types: MINUTE, HOURLY, DAILY, WEEKLY, 
	#                       MONTHLY, ONCE, ONSTART, ONLOGON, ONIDLE, ONEVENT.
	#
	#    /MO   modifier     Refines the schedule type to allow finer control over
	#                       schedule recurrence. Valid values are listed in the 
	#                       "Modifiers" section below.
	#
	#    /D    days         Specifies the day of the week to run the task. Valid 
	#                       values: MON, TUE, WED, THU, FRI, SAT, SUN and for
	#                       MONTHLY schedules 1 - 31 (days of the month). 
	#                       Wildcard "*" specifies all days.
	#
	#    /M    months       Specifies month(s) of the year. Defaults to the first 
	#                       day of the month. Valid values: JAN, FEB, MAR, APR, 
	#                       MAY, JUN, JUL, AUG, SEP, OCT, NOV, DEC. Wildcard "*" 
	#                       specifies all months.
	#
	#    /I    idletime     Specifies the amount of idle time to wait before 
	#                       running a scheduled ONIDLE task.
	#                       Valid range: 1 - 999 minutes.
	#
	#    /TN   taskname     Specifies a name which uniquely
	#                       identifies this scheduled task.
	#
	#    /TR   taskrun      Specifies the path and file name of the program to be 
	#                       run at the scheduled time.
	#                       Example: C:\windows\system32\calc.exe
	#
	#    /ST   starttime    Specifies the start time to run the task. The time 
	#                       format is HH:mm (24 hour time) for example, 14:30 for 
	#                       2:30 PM. Defaults to current time if /ST is not 
	#                       specified.  This option is required with /SC ONCE.
	#
	#    /RI   interval     Specifies the repetition interval in minutes. This is 
	#                       not applicable for schedule types: MINUTE, HOURLY,
	#                       ONSTART, ONLOGON, ONIDLE, ONEVENT.
	#                       Valid range: 1 - 599940 minutes.
	#                       If either /ET or /DU is specified, then it defaults to 
	#                       10 minutes.
	#
	#    /ET   endtime      Specifies the end time to run the task. The time format
	#                       is HH:mm (24 hour time) for example, 14:50 for 2:50 PM.
	#                       This is not applicable for schedule types: ONSTART, 
	#                       ONLOGON, ONIDLE, ONEVENT.
	#
	#    /DU   duration     Specifies the duration to run the task. The time 
	#                       format is HH:mm. This is not applicable with /ET and
	#                       for schedule types: ONSTART, ONLOGON, ONIDLE, ONEVENT.
	#                       For /V1 tasks, if /RI is specified, duration defaults 
	#                       to 1 hour.
	#
	#    /K                 Terminates the task at the endtime or duration time. 
	#                       This is not applicable for schedule types: ONSTART, 
	#                       ONLOGON, ONIDLE, ONEVENT. Either /ET or /DU must be
	#                       specified.
	#
	#    /SD   startdate    Specifies the first date on which the task runs. The 
	#                       format is mm/dd/yyyy. Defaults to the current 
	#                       date. This is not applicable for schedule types: ONCE, 
	#                       ONSTART, ONLOGON, ONIDLE, ONEVENT.
	#
	#    /ED   enddate      Specifies the last date when the task should run. The 
	#                       format is mm/dd/yyyy. This is not applicable for 
	#                       schedule types: ONCE, ONSTART, ONLOGON, ONIDLE, ONEVENT.
	#
	#    /EC   ChannelName  Specifies the event channel for OnEvent triggers.
	#
	#    /IT                Enables the task to run interactively only if the /RU 
	#                       user is currently logged on at the time the job runs.
	#                       This task runs only if the user is logged in.
	#
	#    /NP                No password is stored.  The task runs non-interactively
	#                       as the given user.  Only local resources are available.
	#
	#    /Z                 Marks the task for deletion after its final run.
	#
	#    /XML  xmlfile      Creates a task from the task XML specified in a file.
	#                       Can be combined with /RU and /RP switches, or with /RP 
	#                       alone, when task XML already contains the principal.
	#
	#    /V1                Creates a task visible to pre-Vista platforms.
	#                       Not compatible with /XML.
	#
	#    /F                 Forcefully creates the task and suppresses warnings if 
	#                       the specified task already exists.
	#
	#    /RL   level        Sets the Run Level for the job. Valid values are 
	#                       LIMITED and HIGHEST. The default is LIMITED.
	#
	#    /DELAY delaytime   Specifies the wait time to delay the running of the 
	#                       task after the trigger is fired.  The time format is
	#                       mmmm:ss.  This option is only valid for schedule types
	#                       ONSTART, ONLOGON, ONEVENT.
	#
	#    /?                 Displays this help message.
	#
	#Modifiers: Valid values for the /MO switch per schedule type:
	#    MINUTE:  1 - 1439 minutes.
	#    HOURLY:  1 - 23 hours.
	#    DAILY:   1 - 365 days.
	#    WEEKLY:  weeks 1 - 52.
	#    ONCE:    No modifiers.
	#    ONSTART: No modifiers.
	#    ONLOGON: No modifiers.
	#    ONIDLE:  No modifiers.
	#    MONTHLY: 1 - 12, or 
	#             FIRST, SECOND, THIRD, FOURTH, LAST, LASTDAY.
	#
	#    ONEVENT:  XPath event query string.

	# Run schtasks.exe to add the task
	my $create_task_command = 'schtasks.exe /Create /RU SYSTEM /SC ONSTART /TN "' . $task_name . '" /TR "' . $task_command . '" /F';
	my ($create_task_exit_status, $create_task_output) = run_ssh_command($computer_node_name, $management_node_keys, $create_task_command);
	if (defined($create_task_exit_status)  && $create_task_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully created scheduled task on $computer_node_name");
	}
	elsif (defined($create_task_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create scheduled task on $computer_node_name, exit status: $create_task_exit_status, output:\n@{$create_task_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command created scheduled task on $computer_node_name");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_autoadminlogon {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file enables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="1"
"DefaultUserName"="root"
"DefaultPassword"= "$ROOT_PASSWORD"
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully enabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable autoadminlogon");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_autoadminlogon {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

; This file disables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="0"
"DefaultUserName"=""
"DefaultPassword"= ""
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully disabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable autoadminlogon");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_network_location

 Parameters  :
 Returns     :
 Description : 

=cut

sub set_network_location {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	#Category key: Home/Work=00000000, Public=00000001
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList\\Signatures\\FirstNetwork]
"Category"=dword:00000001
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "successfully set network location");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set network location");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_kms_licensing

 Parameters  :
 Returns     :
 Description :

=cut

sub set_kms_licensing {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $kms_server = shift;
	my $kms_port = shift;
	
	# Make sure the KMS server address was passed as an argument
	if (!defined($kms_server)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set kms server, server address was not passed correctly as an argument");
		return 0;
	}
	
	# Set the default KMS port if it wasn't specified.
	$kms_port = 1688 if !$kms_port;
	
	# Run slmgr.vbs -skms
	my $kms_command = '$SYSTEMROOT/System32/cscript.exe $SYSTEMROOT/System32/slmgr.vbs -skms ' . "$kms_server:$kms_port";
	my ($kms_exit_status, $kms_output) = run_ssh_command($computer_node_name, $management_node_keys, $kms_command);
	if (defined($kms_exit_status)  && $kms_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully set kms server to $kms_server:$kms_port on $computer_node_name");
	}
	elsif (defined($kms_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set kms server to $kms_server:$kms_port on $computer_node_name, exit status: $kms_exit_status, output:\n@{$kms_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to set kms server to $kms_server:$kms_port on $computer_node_name");
		return;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 activate_licensing

 Parameters  :
 Returns     :
 Description :

=cut

sub activate_licensing {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Run slmgr.vbs -ato
	my $activate_command = '$SYSTEMROOT/System32/cscript.exe $SYSTEMROOT/System32/slmgr.vbs -ato';
	my ($activate_exit_status, $activate_output) = run_ssh_command($computer_node_name, $management_node_keys, $activate_command);
	if (defined($activate_exit_status)  && $activate_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully activated licensing on $computer_node_name");
	}
	elsif (defined($activate_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to activated licensing on $computer_node_name, exit status: $activate_exit_status, output:\n@{$activate_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to activated licensing on $computer_node_name");
		return;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_eventlog_entry

 Parameters  :
 Returns     :
 Description :

=cut

sub create_eventlog_entry {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $message = shift;
	
	# Make sure the message was passed as an argument
	if (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create eventlog entry, message was passed as an argument");
		return 0;
	}
	
	# Run eventcreate.exe to create an event log entry
	my $eventcreate_command = '$SYSTEMROOT/System32/eventcreate.exe /T INFORMATION /L APPLICATION /SO VCL /ID 555 /D "' . $message . '"';
	my ($eventcreate_exit_status, $eventcreate_output) = run_ssh_command($computer_node_name, $management_node_keys, $eventcreate_command);
	if (defined($eventcreate_exit_status)  && $eventcreate_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully created event log entry on $computer_node_name: $message");
	}
	elsif (defined($eventcreate_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create event log entry on $computer_node_name: $message, exit status: $eventcreate_exit_status, output:\n@{$eventcreate_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to create event log entry on $computer_node_name: $message");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reboot

 Parameters  : $wait_for_reboot
 Returns     : 
 Description : 

=cut

sub reboot {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Check if an argument was supplied
	my $wait_for_reboot = shift;
	if (!defined($wait_for_reboot) || $wait_for_reboot !~ /0/) {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and waiting for ssh to become active");
		$wait_for_reboot = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and NOT waiting");
		$wait_for_reboot = 0;
	}
	
	my $reboot_start_time = time();
	notify($ERRORS{'DEBUG'}, 0, "reboot will be attempted on $computer_node_name");
	
	# Make sure SSH access is enabled from private IP addresses
	if (!$self->firewall_enable_ssh_private()) {
		notify($ERRORS{'WARNING'}, 0, "reboot not attempted, failed to enable ssh from private IP addresses");
		return 0;
	}
	
	# Make sure ping access is enabled from private IP addresses
	if (!$self->firewall_enable_ping_private()) {
		notify($ERRORS{'WARNING'}, 0, "reboot not attempted, failed to enable ping from private IP addresses");
		return 0;
	}
	
	# Initiate the shutdown.exe command to reboot the computer
	my $shutdown_command = "C:/Windows/system32/shutdown.exe -r -t 0 -f";
	my ($shutdown_exit_status, $shutdown_output) = run_ssh_command($computer_node_name, $management_node_keys, $shutdown_command);
	if (defined($shutdown_exit_status)  && $shutdown_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully executed reboot command on $computer_node_name");
	}
	elsif (defined($shutdown_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute reboot command on $computer_node_name, exit status: $shutdown_exit_status, output:\n@{$shutdown_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to reboot $computer_node_name");
		return;
	}
	
	# Check if wait for reboot is set
	if (!$wait_for_reboot) {
		return 1;
	}
	
	# Wait for reboot is true
	notify($ERRORS{'OK'}, 0, "sleeping for 30 seconds while $computer_node_name begins reboot");
	sleep 30;
	
	# Wait maximum of 4 minutes for the computer to go offline then come back up
	if (!$self->wait_for_ping(4)) {
		# Check if the computer was ever offline, it should have been or else reboot never happened
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping, attempting hard power reset");
		
		# Just explicitly call xCAT's _rpower for now
		# TODO: implement public reset() subroutines in all of the provisioning modules
		# TODO: allow provisioning and OS modules access to each other's subroutines
		if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "cycle")) {
			notify($ERRORS{'OK'}, 0, "initiated hard power reset on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate hard power reset on $computer_node_name");
			return 0;
		}
		
		# Wait for computer to respond to ping after initiating hard reset
		# Wait longer than the first attempt
		if (!$self->wait_for_ping(6)) {
			# Check if the computer was ever offline, it should have been or else reboot never happened
			notify($ERRORS{'WARNING'}, 0, "reboot failed, $computer_node_name never responded to ping even after hard power reset");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "sleeping for 15 seconds while $computer_node_name initializes");
	sleep 15;
	
	# Ping successful, try ssh
	notify($ERRORS{'OK'}, 0, "waiting for ssh to respond on $computer_node_name");
	if ($self->wait_for_ssh(3)) {
		my $reboot_end_time = time();
		my $reboot_duration = ($reboot_end_time - $reboot_start_time);
		notify($ERRORS{'OK'}, 0, "reboot succeeded on $computer_node_name, took $reboot_duration seconds");\
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "reboot failed, ssh never became available on $computer_node_name");
		return 0;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ping

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is pingable, 0 otherwise
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
					of minutes. This can be specified by passing the subroutine an
					integer value or the default value of 5 minutes will be used.

=cut

sub wait_for_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of minutes to wait from the command line
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}
	
	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 30;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 2) + 1;
	
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ping, maximum of $total_wait_minutes minutes");
	
	# Loop until computer is online
	my $computer_was_offline = 0;
	my $computer_pingable = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempts: checking if computer is pingable: $computer_node_name");
		$computer_pingable = _pingnode($computer_node_name);
		
		if ($computer_pingable && $computer_was_offline) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is pingable, reboot is nearly complete");
			last;
		}
		elsif ($computer_pingable && !$computer_was_offline) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is still pingable, reboot has not begun");
		}
		else {
			$computer_was_offline = 1;
			notify($ERRORS{'OK'}, 0, "$computer_node_name is not pingable, reboot is not complete");
		}
		
		notify($ERRORS{'OK'}, 0, "sleeping for $attempt_delay seconds before next ping attempt");
		sleep $attempt_delay;
	}
	
	# Check if the computer ever went offline and if it is now pingable
	if ($computer_pingable && $computer_was_offline) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name was offline and is now pingable");
		return 1;
	}
	elsif ($computer_pingable && !$computer_was_offline) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name was never offline and is still pingable");
		return 0;
	}
	else {
		my $total_wait = ($attempts * $attempt_delay);
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not pingable after waiting for $total_wait seconds");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_shutdown

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is not pingable, 0 otherwise
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
					of minutes for ping to fail.

=cut

sub wait_for_shutdown {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of minutes to wait from the command line
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}
	
	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 30;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 2) + 1;
	
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to become unresponsive, maximum of $total_wait_minutes minutes");
	
	# Loop until computer is offline
	my $computer_pingable = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempts: checking if computer is pingable: $computer_node_name");
		$computer_pingable = _pingnode($computer_node_name);
		
		if (!$computer_pingable) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is not pingable, returning 1");
			return 1;
		}
		
		notify($ERRORS{'OK'}, 0, "sleeping for $attempt_delay seconds before next ping attempt");
		sleep $attempt_delay;
	}
	
	# Reached end of wait loop
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is still pingable, returning 0");
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ssh

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if ssh succeeded to computer, 0 otherwise
 Description : Attempts to communicate to the computer specified in the
               DataStructure for the current reservation via SSH. It will wait
					up to a maximum number of minutes. This can be specified by
					passing the subroutine an integer value or the default value
					of 5 minutes will be used.

=cut

sub wait_for_ssh {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of minutes to wait from the arguments
	# If not specified, use default value
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}
	
	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 15;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 4) + 1;
	
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ssh, maximum of $total_wait_minutes minutes");
	
	# Loop until ssh is available
	my $ssh_result = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempts: checking ssh on computer: $computer_node_name");
		
		# Run a test SSH command
		my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, "echo testing ssh on $computer_node_name");

		# The exit status will be 0 if the command succeeded
		if (defined($exit_status) && $exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "test ssh command succeeded on $computer_node_name");
			return 1;
		}
		
		notify($ERRORS{'OK'}, 0, "sleeping for $attempt_delay seconds before next ssh attempt");
		sleep $attempt_delay;
	}
	
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not available via ssh");
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my %firewall_parameters = (
		name => 'VCL: allow ping from private network',
		dir => 'in',
		action => 'allow',
		description => 'Allows incoming ping (ICMP type 8) messages from 10.x.x.x addresses',
		enable => 'yes',
		localip => '10.0.0.0/8',
		remoteip => '10.0.0.0/8',
		protocol => 'icmpv4:8,any',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming ping on private network");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming ping on private network");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my %firewall_parameters = (
		name => 'VCL: allow SSH port 22 from private network',
		dir => 'in',
		action => 'allow',
		description => 'Allows incoming TCP port 22 traffic from 10.x.x.x addresses',
		enable => 'yes',
		localip => '10.0.0.0/8',
		remoteip => '10.0.0.0/8',
		localport => '22',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming ssh via TCP port 22 on private network");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming ssh via TCP port 22 on private network");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if the remote IP was passed correctly as an argument
	my $remote_ip = shift;
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'any';
	}
	
	my %firewall_parameters = (
		name => "VCL: allow RDP port 3389 from $remote_ip",
		dir => 'in',
		action => 'allow',
		description => "Allows incoming TCP port 3389 traffic from $remote_ip",
		enable => 'yes',
		remoteip => $remote_ip,
		localport => '3389',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming RDP via TCP port 3389 from $remote_ip");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming RDP via TCP port 3389 from $remote_ip");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	#"\netsh.exe advfirewall firewall delete rule name=RDP protocol=TCP localport=3389"

	my %firewall_parameters = (
		name => 'all',
		localport => '3389',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_close(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully closed firewall for incoming RDP via TCP port 3389");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to close firewall for incoming RDP via TCP port 3389");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_configure

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_configure {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Check the arguments
	my $firewall_parameters = shift;
	if (!defined($firewall_parameters) || !$firewall_parameters) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, parameters hash reference was not passed");
		return;
	}
	if (!defined($firewall_parameters->{name}) || !$firewall_parameters->{name}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'name' hash key was not passed");
		return;
	}
	if (!defined($firewall_parameters->{dir}) || !$firewall_parameters->{dir}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'dir' hash key was not passed");
		return;
	}
	if (!defined($firewall_parameters->{action}) || !$firewall_parameters->{action}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'action' hash key was not passed");
		return;
	}
	
	# Add quotes around anything with a space in the parameters hash which isn't already enclosed in quotes
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$firewall_parameters->{$rule_property} =~ s/^(.*\s.*)$/\"$1\"/g;
		#notify($ERRORS{'DEBUG'}, 0, "enclosing property in quotes: $firewall_parameters->{$rule_property}");
	}
	
	# Attempt to run the command to set existing firewall rule
	
	# Usage: set rule
	#		group=<string> | name=<string>
	#		[dir=in|out]
	#		[profile=public|private|domain|any[,...]]
	#		[program=<program path>]
	#		[service=service short name|any]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]
	#		new
	#		[name=<string>]
	#		[dir=in|out]
	#		[program=<program path>
	#		[service=<service short name>|any]
	#		[action=allow|block|bypass]
	#		[description=<string>]
	#		[enable=yes|no]
	#		[profile=public|private|domain|any[,...]]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]
	#		[interfacetype=wireless|lan|ras|any]
	#		[rmtcomputergrp=<SDDL string>]
	#		[rmtusrgrp=<SDDL string>]
	#		[edge=yes|no]
	#		[security=authenticate|authenc|notrequired]
	
	# Assemble the command based on the keys populated in the hash
	my $set_rule_command = "netsh.exe advfirewall firewall set rule";
	$set_rule_command .= " name=$firewall_parameters->{name}";
	$set_rule_command .= " new";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		next if $rule_property eq 'name';
		$set_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Attempt to set properties of existing rule
	notify($ERRORS{'DEBUG'}, 0, "attempting to set matching firewall rules on $computer_node_name, command:\n$set_rule_command");
	my ($set_rule_exit_status, $set_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $set_rule_command);
	if (defined($set_rule_exit_status)  && ($set_rule_exit_status == 0)) {
		notify($ERRORS{'OK'}, 0, "successfully set matching firewall rules");
		return 1;
	}
	elsif (defined($set_rule_exit_status)  && ($set_rule_exit_status == 1)) {
		notify($ERRORS{'OK'}, 0, "unable to set matching firewall rules, rule does not exist");
	}
	elsif (defined($set_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set matching firewall rules on $computer_node_name, exit status: $set_rule_exit_status, output:\n@{$set_rule_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set matching firewall rules on $computer_node_name");
	}
	
	
	# Attempt to run the command to add the firewall rule
	
	# Usage: add rule name=<string>
	#      dir=in|out
	#      action=allow|block|bypass
	#      [program=<program path>]
	#      [service=<service short name>|any]
	#      [description=<string>]
	#      [enable=yes|no (default=yes)]
	#      [profile=public|private|domain|any[,...]]
	#      [localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#      [remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#         <IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#      [localport=0-65535|RPC|RPC-EPMap|any[,...] (default=any)]
	#      [remoteport=0-65535|any[,...] (default=any)]
	#      [protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#         tcp|udp|any (default=any)]
	#      [interfacetype=wireless|lan|ras|any]
	#      [rmtcomputergrp=<SDDL string>]
	#      [rmtusrgrp=<SDDL string>]
	#      [edge=yes|no (default=no)]
	#      [security=authenticate|authenc|notrequired (default=notrequired)]
	
	# Assemble the command based on the keys populated in the hash
	my $add_rule_command = "netsh.exe advfirewall firewall add rule";
	$add_rule_command .= " name=$firewall_parameters->{name}";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		next if $rule_property eq 'name';
		$add_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	if (defined($add_rule_exit_status)  && $add_rule_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully added firewall rule");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule on $computer_node_name, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule on $computer_node_name");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_close

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_close {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Make sure firewall parameters hash was passed
	my $firewall_parameters = shift;
	if (!defined($firewall_parameters) || !$firewall_parameters) {
		notify($ERRORS{'WARNING'}, 0, "failed to close firewall on $computer_node_name, parameters hash reference was not passed");
		return;
	}
	
	# Add quotes around anything with a space in the parameters hash which isn't already enclosed in quotes
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$firewall_parameters->{$rule_property} =~ s/^(.*\s.*)$/\"$1\"/g;
		#notify($ERRORS{'DEBUG'}, 0, "enclosing '$rule_property' property in quotes: $firewall_parameters->{$rule_property}");
	}
	
	# Usage: delete rule name=<string>
	#		[dir=in|out]
	#		[profile=public|private|domain|any[,...]]
	#		[program=<program path>]
	#		[service=<service short name>|any]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]

	# Assemble the command based on the keys populated in the hash
	my $delete_rule_command = "netsh.exe advfirewall firewall delete rule";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$delete_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Attempt to delete existing rules
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete matching firewall rules on $computer_node_name, command:\n$delete_rule_command");
	my ($delete_rule_exit_status, $delete_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_rule_command);
	if (defined($delete_rule_exit_status)  && ($delete_rule_exit_status == 0)) {
		notify($ERRORS{'OK'}, 0, "successfully deleted matching firewall rules");
		return 1;
	}
	elsif (defined($delete_rule_exit_status)  && ($delete_rule_exit_status == 1)) {
		notify($ERRORS{'OK'}, 0, "unable to delete matching firewall rules, rule does not exist");
		return 1;
	}
	elsif (defined($delete_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete matching firewall rules on $computer_node_name, exit status: $delete_rule_exit_status, output:\n@{$delete_rule_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to delete matching firewall rules on $computer_node_name");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_service_startup_mode

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub set_service_startup_mode {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Make sure firewall parameters hash was passed
	my $service_name = shift;
	my $startup_mode = shift;
	
	# Make sure both arguments were supplied
	if (!defined($service_name) && !defined($startup_mode)) {
		notify($ERRORS{'WARNING'}, 0, "set service startup mode failed, service name and startup mode arguments were not passed correctly");
		return 0;
	}
	
	# Make sure the startup mode is valid
	if ($startup_mode !~ /boot|system|auto|demand|disabled|delayed-auto|manual/i) {
		notify($ERRORS{'WARNING'}, 0, "set service startup mode failed, invalid startup mode: $startup_mode");
		return 0;
	}
	
	# Set the mode to demand if manual was specified, specific to sc command
	$startup_mode = "demand" if ($startup_mode eq "manual");

	# Use sc.exe to change the start mode
	my $service_startup_command  = '"$SYSTEMROOT/System32/sc.exe" config ' . "$service_name start= $startup_mode";
	my ($service_startup_exit_status, $service_startup_output) = run_ssh_command($computer_node_name, $management_node_keys, $service_startup_command);
	if (defined($service_startup_exit_status) && $service_startup_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "$service_name service startup mode set to $startup_mode");
	}
	elsif ($service_startup_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to set $service_name service startup mode to $startup_mode, exit status: $service_startup_exit_status, output:\n@{$service_startup_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set $service_name service startup mode to $startup_mode, exit status: $service_startup_exit_status, output:\n@{$service_startup_output}");
		return;
	}
	
	return 1;
} ## end sub _set_sshd_startmode

#/////////////////////////////////////////////////////////////////////////////

=head2 defragment_hard_drive

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub defragment_hard_drive {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Defragment the hard drive
	notify($ERRORS{'OK'}, 0, "beginning to defragment the hard drive on $computer_node_name");
	my ($defrag_exit_status, $defrag_output) = run_ssh_command($computer_node_name, $management_node_keys, '$SYSTEMROOT/System32/defrag.exe $SYSTEMDRIVE -v');
	if (defined($defrag_exit_status) && $defrag_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully defragmented the hard drive, exit status: $defrag_exit_status, output:\n@{$defrag_output}");
		return 1;
	}
	elsif (defined($defrag_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to defragment the hard drive, exit status: $defrag_exit_status, output:\n@{$defrag_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run the SSH command to defragment the hard drive");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 run_newsid

 Parameters  : 
 Returns     : 1 success 0 failure
 Description : 

=cut

sub run_newsid {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the computer name from the arguments
	# If no argument was supplied, use the name specified in the DataStructure
	my $computer_name = shift;
	if (!(defined($computer_name))) {
		$computer_name = $self->data->get_computer_short_name();
	}
	
	# Attempt to delete the user account
	my $newsid_command = "start /wait $NODE_CONFIGURATION_DIRECTORY/Utilities/newsid.exe /a /n $computer_name";
	my ($newsid_exit_status, $newsid_output) = run_ssh_command($computer_node_name, $management_node_keys, $newsid_command);
	if (defined($newsid_exit_status) && $newsid_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully ran newsid.exe on $computer_node_name, new computer name: $computer_name");
	}
	elsif (defined($newsid_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run newsid.exe on $computer_node_name, exit status: $newsid_exit_status, output:\n@{$newsid_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run newsid.exe on $computer_node_name");
		return;
	}
	
	return 1;
}

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

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2004-2008 by NC State University. All Rights Reserved.

 Virtual Computing Laboratory
 North Carolina State University
 Raleigh, NC, USA 27695

 For use license and copyright information see LICENSE and COPYRIGHT files
 included in the source files.

=cut
