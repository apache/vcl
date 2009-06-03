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

VCL::Module::OS::Windows_mod - Windows OS support module

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::OS::Windows_mod;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
#use base qw(VCL::Module::OS::Windows);
use base qw(VCL::Module::OS);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';
use VCL::utils;
use File::Basename;

# Use Data::Dumper to print variables
use Data::Dumper;
$Data::Dumper::Indent = 0;
$Data::Dumper::Terse  = 1;
$Data::Dumper::Pair   = "=>";


##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on the management node of the files specific to this OS
               module which are needed to configure the loaded OS on a computer.
               This is normally the directory under 'tools' named after this OS
               module.
               
               Example:
               /usr/local/vcl/tools/Windows

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows";


=head2 $NODE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on computer on which an image has been loaded where
               configuration files reside. The files residing on the managment
               node in the directory specified by $NODE_CONFIGURATION_DIRECTORY
               are copied to this directory.
               
               Example:
               C:\Cygwin\home\root\VCL

=cut

our $NODE_CONFIGURATION_DIRECTORY = 'C:/Cygwin/home/root/VCL';

##############################################################################

=head1 INTERFACE OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : Hash containing 'end_state' key
 Returns     : If successful: true
               If failed: false
 Description : Performs the steps necessary to prepare a Windows OS before an
               image is captured.
               This subroutine is called by a provisioning module's capture()
               subroutine.
               
               The steps performed are:

=over 3

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if end_state argument was passed
	if (defined $args->{end_state}) {
		$self->{end_state} = $args->{end_state};
	}
	else {
		$self->{end_state} = 'off';
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "beginning Windows image capture preparation tasks on $computer_node_name");

=item 1

 Log off all currently logged in users

=cut

	if (!$self->logoff_users()) {
		notify($ERRORS{'WARNING'}, 0, "unable to log off all currently logged in users on $computer_node_name");
		return 0;
	}

=item *

 Set root account password to known value

=cut

	if (!$self->set_password('root', $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root password");
		return 0;
	}

=item *

 Delete the users assigned to this reservation

=cut

	if (!$self->delete_users()) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete users");
		return 0;
	}

=item *

 Copy the capture configuration files to the computer (scripts, utilities, drivers...)

=cut

	if (!$self->copy_capture_configuration_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy general Windows capture configuration files to $computer_node_name");
		return 0;
	}

=item *

 Disable autoadminlogon before disabling the pagefile and rebooting

=cut

	if (!$self->disable_autoadminlogon()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable autoadminlogon");
		return 0;
	}

=item *

 Disable IPv6

=cut

	if (!$self->disable_ipv6()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable IPv6");
	}

=item *

 Disable dynamic DNS

=cut

	if (!$self->disable_dynamic_dns()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable dynamic dns");
	}

=item *

 Disable Internet Explorer configuration page

=cut

	if (!$self->disable_ie_configuration_page()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable IE configuration");
	}

=item *

 Disable Windows Defender

=cut

	if (!$self->disable_windows_defender()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable Windows Defender");
	}

=item *

 Disable Automatic Updates

=cut

	if (!$self->disable_automatic_updates()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable automatic updates");
	}

=item *

 Disable Security Center notifications

=cut

	if (!$self->disable_security_center_notifications()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable Security Center notifications");
	}

=item *

 Clean up the hard drive

=cut

	if (!$self->clean_hard_drive()) {
		notify($ERRORS{'WARNING'}, 0, "unable to clean unnecessary files the hard drive");
	}

=item *

 Apply Windows security templates

=cut

	# This find any .inf security template files configured for the OS and run secedit.exe to apply them
	if (!$self->apply_security_templates()) {
		notify($ERRORS{'WARNING'}, 0, "unable to apply security templates");
		return 0;
	}
	
=item *

 Configure the network adapters to use DHCP

=cut

	if (!$self->enable_dhcp()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable DHCP on the public and private interfaces");
		return 0;
	}

=item *

 Disable the pagefile, reboot, and delete pagefile.sys
 
 ********* node reboots *********

=cut

	# This will set the registry key to disable the pagefile, reboot, then delete pagefile.sys
	# Calls the reboot() subroutine, which makes sure ssh service is set to auto and firewall is open for ssh
	if (!$self->disable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable pagefile");
		return 0;
	}

=item *

 Allow users to connect remotely (this does not enable RDP, but allows general remote access)

=cut

	if (!$self->allow_remote_access()) {
		notify($ERRORS{'WARNING'}, 0, "unable to allow users to connect remotely");
	}

=item *

 Disable RDP access from any IP address

=cut

	if (!$self->firewall_disable_rdp()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable RDP from all addresses");
		return 0;
	}

=item *

 Enable SSH access from any IP address

=cut

	if (!$self->firewall_enable_ssh()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable SSH from any IP address");
		return 0;
	}

=item *

 Enable ping from any IP address

=cut

	if (!$self->firewall_enable_ping()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable ping from any IP address");
		return 0;
	}

=item *

 Reenable the pagefile

=cut

	if (!$self->enable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "unable to reenable pagefile");
		return 0;
	}

=item *

 Set the Cygwin SSHD service startup mode to manual

=cut

	if (!$self->set_service_startup_mode('sshd', 'manual')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set sshd service startup mode to manual");
		return 0;
	}

=back

=cut

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub pre_capture

#/////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Performs the steps necessary to configure a Windows OS after an
               image has been loaded.
               
               This subroutine is called by a provisioning module's load()
               subroutine.
               
               The steps performed are:

=over 3

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $imagemeta_postoption = $self->data->get_imagemeta_postoption();

	notify($ERRORS{'OK'}, 0, "beginning Windows post-load tasks");

=item 1

 Log off all currently logged on users

 Do this in case autoadminlogon was enabled during the load process and the user
 account was not properly logged off.

=cut

	if (!$self->logoff_users()) {
		notify($ERRORS{'WARNING'}, 0, "failed to log off all currently logged in users");
	}

=item *

 Set the Cygwin SSHD service startup mode to automatic
 
 The Cygwin SSHD service startup mode should be set to automatic after an image
 has been loaded and is ready to be reserved. Access will be lost if the service
 is not set to automatic and the computer is rebooted.

=cut

	if (!$self->set_service_startup_mode('sshd', 'auto')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set sshd service startup mode to auto");
		return 0;
	}
	
=item *

 Set the computer name

=cut

	if (!$self->set_computer_name()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the computer name");
	}

=item *

 Enable RDP access on the private network interface

=cut

	if (!$self->firewall_enable_rdp_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable RDP on private network");
		return 0;
	}
	
=item *

 Enable SSH access on the private network interface

=cut

	if (!$self->firewall_enable_ssh_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable SSH from private IP address");
	}

=item *

 Enable ping on the private network interface

=cut

	if (!$self->firewall_enable_ping_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable ping from private IP address");
	}
	
=item *

 Set the "My Computer" description to the image pretty name

=cut

	if (!$self->set_my_computer_name()) {
		notify($ERRORS{'WARNING'}, 0, "failed to rename My Computer");
	}

#=item *
#
#Disable NetBIOS
#
#=cut
#
#	if (!$self->disable_netbios()) {
#		notify($ERRORS{'WARNING'}, 0, "failed to disable NetBIOS");
#	}

#=item *
#
#Disable dynamic DNS
#
#=cut
#
#	if (!$self->disable_dynamic_dns()) {
#		notify($ERRORS{'WARNING'}, 0, "failed to disable dynamic DNS");
#	}

=item *

 Randomize the root account password

=cut

	my $root_random_password = getpw();
	if (!$self->set_password('root', $root_random_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set random root password");
	}

=item *

 Randomize the Administrator account password

=cut

	my $administrator_random_password = getpw();
	if (!$self->set_password('Administrator', $administrator_random_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set random Administrator password");
	}

=item *

 Check if the imagemeta postoption is set to reboot, reboot if necessary

=cut

	if ($imagemeta_postoption =~ /reboot/i) {
		notify($ERRORS{'OK'}, 0, "imagemeta postoption reboot is set for image, rebooting computer");
		if (!$self->reboot()) {
			notify($ERRORS{'WARNING'}, 0, "failed to reboot the computer");
			return;
		}
	}

=back

=cut

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub post_load

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  :
 Returns     :
 Description :

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $request_forimaging   = $self->data->get_request_forimaging();
	my $reservation_password = $self->data->get_reservation_password();

	notify($ERRORS{'OK'}, 0, "beginning Windows reserve tasks");

	# Check if this is an imaging request or not
	if ($request_forimaging) {
		# Imaging request, don't create account, set the Administrator password
		if (!$self->set_password('Administrator', $reservation_password)) {
			notify($ERRORS{'WARNING'}, 0, "unable to set password for Administrator account");
			return 0;
		}
	}
	else {
		# Add the users to the computer
		# The add_users() subroutine will add the primary reservation user and any imagemeta group users
		if (!$self->add_users()) {
			notify($ERRORS{'WARNING'}, 0, "unable to add users");
			return 0;
		}
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub reserve

#/////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     :
 Description :

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Revoke access
	if (!$self->revoke_access()) {
		notify($ERRORS{'WARNING'}, 0, "failed to revoke access to $computer_node_name");
		return 0;
	}

	# Delete all users associated with the reservation
	# This includes the primary reservation user and users listed in imagemeta group if it's configured
	if ($self->delete_users()) {
		notify($ERRORS{'OK'}, 0, "users have been deleted from $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete users from $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;
} ## end sub sanitize

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  :
 Returns     :
 Description :

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $remote_ip            = $self->data->get_reservation_remote_ip();
	my $multiple_users       = $self->data->get_imagemeta_usergroupmembercount();
	my $request_forimaging   = $self->data->get_request_forimaging();

	# Check to make sure remote IP is defined
	my $remote_ip_range;
	if (!$remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "reservation remote IP address is not set in the data structure, opening RDP to any address");
	}
	elsif ($multiple_users) {
		notify($ERRORS{'OK'}, 0, "reservation has multiple users, opening RDP to any address");
	}
	elsif ($remote_ip !~ /^(\d{1,3}\.?){4}$/) {
		notify($ERRORS{'WARNING'}, 0, "reservation remote IP address format is invalid: $remote_ip, opening RDP to any address");
	}
	else {
		# Assemble the IP range string in CIDR notation
		$remote_ip_range = "$remote_ip/16";
		notify($ERRORS{'OK'}, 0, "RDP will be allowed from $remote_ip_range on $computer_node_name");
	}

	# Set the $remote_ip_range variable to the string 'all' if it isn't already set (for display purposes)
	$remote_ip_range = 'all' if !$remote_ip_range;

	# Allow RDP connections
	if ($self->firewall_enable_rdp($remote_ip_range)) {
		notify($ERRORS{'OK'}, 0, "firewall was configured to allow RDP access from $remote_ip_range on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "firewall could not be configured to grant RDP access from $remote_ip_range on $computer_node_name");
		return 0;
	}

	# If this is an imaging request, make sure the Administrator account is enabled
	if ($request_forimaging) {
		notify($ERRORS{'DEBUG'}, 0, "imaging request, making sure Administrator account is enabled");
		if ($self->enable_user('Administrator')) {
			notify($ERRORS{'OK'}, 0, "Administrator account is enabled for imaging request");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to enable Administrator account for imaging request");
			return 0;
		}
	} ## end if ($request_forimaging)

	notify($ERRORS{'OK'}, 0, "access has been granted for reservation on $computer_node_name");
	return 1;
} ## end sub grant_access

#/////////////////////////////////////////////////////////////////////////////

=head2 revoke_access

 Parameters  :
 Returns     :
 Description :

=cut

sub revoke_access {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Disallow RDP connections
	if ($self->firewall_disable_rdp()) {
		notify($ERRORS{'OK'}, 0, "firewall was configured to deny RDP access on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "firewall could not be configured to deny RDP access on $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "access has been revoked to $computer_node_name");
	return 1;
} ## end sub revoke_access

##############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 create_directory

 Parameters  :
 Returns     :
 Description :

=cut

sub create_directory {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my @paths;

	# Get 1 or more paths from the subroutine arguments
	while (my $path = shift) {
		push @paths, $path;
	}

	# Make sure at least 1 path was specified
	if (!@paths) {
		notify($ERRORS{'WARNING'}, 0, "directory path was not specified as an argument");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "attempting to create " . scalar @paths . " directories:\n" . join("\n", @paths));

	# Keep a count of paths which couldn't be deleted
	my $directories_not_created = 0;

	# Loop through the paths
	for my $path (@paths) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to create directory: $path");

		# Assemble the Windows shell mkdir command and execute it
		my $mkdir_command = '$SYSTEMROOT/System32/cmd.exe /c "mkdir \\"' . $path . '\\""';
		my ($mkdir_exit_status, $mkdir_output) = run_ssh_command($computer_node_name, $management_node_keys, $mkdir_command, '', '', 1);
		if (defined($mkdir_exit_status) && $mkdir_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "directory created on $computer_node_name: $path, output:\n@{$mkdir_output}");
		}
		elsif (defined($mkdir_exit_status) && $mkdir_exit_status == 1 && grep(/already exists/i, @{$mkdir_output})) {
			notify($ERRORS{'OK'}, 0, "directory already exists on $computer_node_name: $path, exit status: $mkdir_exit_status, output:\n@{$mkdir_output}");
		}
		elsif (defined($mkdir_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create directory on $computer_node_name: $path, exit status: $mkdir_exit_status, output:\n@{$mkdir_output}");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete file on $computer_node_name: $path");
			$directories_not_created++;
			next;
		}

		# Make sure directory was created
		if (!$self->filesystem_entry_exists($path)) {
			notify($ERRORS{'WARNING'}, 0, "filesystem entry does not exist on $computer_node_name: $path");
			$directories_not_created++;
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "verified that filesystem entry exists on $computer_node_name: $path");
		}
	} ## end for my $path (@paths)

	# Check if any paths couldn't be created
	if ($directories_not_created) {
		notify($ERRORS{'WARNING'}, 0, "some paths could not be created");
		return 0;
	}
	else {
		return 1;
	}
} ## end sub create_directory

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_file

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_file {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get file path subroutine argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "file path was not specified as an argument");
		return;
	}
	
	# Replace backslashes with forward slashes
	$path =~ s/\\+/\//gs;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete file: $path");

	# Assemble the Windows shell del command and execute it
	my $rm_command = "rm -rfv \"$path\"";
	my ($rm_exit_status, $rm_output) = run_ssh_command($computer_node_name, $management_node_keys, $rm_command, '', '', 1);
	if ($rm_output && grep(/removed/i, @{$rm_output})) {
		my $files_deleted = grep(/removed \W/i, @{$rm_output});
		my $directories_deleted = grep(/removed directory/i, @{$rm_output});
		notify($ERRORS{'OK'}, 0, "deleted $path using rm, files deleted: $files_deleted, directories deleted: $directories_deleted");
	}
	elsif (defined($rm_exit_status) && $rm_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "file either deleted or does not exist on $computer_node_name: $path, output:\n@{$rm_output}");
	}
	elsif (defined($rm_output) && grep(/Circular directory structure/i, @{$rm_output})) {
		notify($ERRORS{'DEBUG'}, 0, "circular directory structure found, rm can't handle this, attempting next deletion method");
	}
	elsif ($rm_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete file on $computer_node_name: $path, exit status: $rm_exit_status, output:\n@{$rm_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete file on $computer_node_name: $path");
	}

	# Check if file was deleted
	sleep 1;
	if (!$self->filesystem_entry_exists($path)) {
		notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist: $path");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "file still exists: $path, attempting to delete it using cmd.exe /c del");
	
	# rm didn't get rid of the file, try del
	# Assemble the Windows shell del command and execute it
	my $del_command = '$SYSTEMROOT/System32/cmd.exe /c "del /s /q /f /a \\"' . $path . '\\""';
	my ($del_exit_status, $del_output) = run_ssh_command($computer_node_name, $management_node_keys, $del_command, '', '', 1);
	if ($del_output && (my $deleted_count = grep(/deleted file/i, @{$del_output}))) {
		notify($ERRORS{'OK'}, 0, "deleted $path using del, files deleted: $deleted_count");
	}
	elsif (defined($del_exit_status) && $del_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "file does not exist on $computer_node_name: $path, output:\n@{$del_output}");
	}
	elsif ($del_output && grep(/cannot find/, @{$del_output})) {
		notify($ERRORS{'DEBUG'}, 0, "file not found on $computer_node_name: $path, exit status: $del_exit_status, output:\n@{$del_output}");
	}
	elsif ($del_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete file on $computer_node_name: $path, exit status: $del_exit_status, output:\n@{$del_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete file on $computer_node_name: $path");
	}
	
	# Check if file was deleted
	sleep 1;
	if (!$self->filesystem_entry_exists($path)) {
		notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist: $path");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "file still exists: $path, attempting to delete it using cmd.exe /c rmdir");

	# Assemble the Windows shell rmdir command and execute it
	my $rmdir_command = '$SYSTEMROOT/System32/cmd.exe /c "rmdir /s /q \\"' . $path . '\\""';
	my ($rmdir_exit_status, $rmdir_output) = run_ssh_command($computer_node_name, $management_node_keys, $rmdir_command, '', '', 1);
	if (defined($rmdir_exit_status) && $rmdir_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "directory deleted using rmdir on $computer_node_name: $path, output:\n@{$rmdir_output}");
	}
	elsif (defined($rmdir_output) && grep(/cannot find the/, @{$rmdir_output})) {
		# Exit status 2 should mean the directory was not found
		notify($ERRORS{'DEBUG'}, 0, "directory to be deleted was not found on $computer_node_name: $path, exit status: $rmdir_exit_status, output:\n@{$rmdir_output}");
	}
	elsif ($rmdir_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete directory on $computer_node_name: $path, exit status: $rmdir_exit_status, output:\n@{$rmdir_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete directory on $computer_node_name: $path");
	}
	
	# Check if file was deleted
	sleep 1;
	if (!$self->filesystem_entry_exists($path)) {
		notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist: $path");
		return 1;
	}
	
	notify($ERRORS{'WARNING'}, 0, "file could not be deleted, it still exists: $path");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 move_file

 Parameters  :
 Returns     :
 Description :

=cut

sub move_file {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get file path subroutine arguments
	my $source_path = shift;
	my $destination_path = shift;
	if (!$source_path) {
		notify($ERRORS{'WARNING'}, 0, "file source path was not specified as an argument");
		return;
	}
	if (!$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "file destination path was not specified as an argument");
		return;
	}
	
	# Replace backslashes with forward slashes
	$source_path =~ s/\\+/\//gs;
	$destination_path =~ s/\\+/\//gs;

	notify($ERRORS{'DEBUG'}, 0, "attempting to move file: $source_path --> $destination_path");

	# Assemble the Windows shell move command and execute it
	my $move_command = "mv -fv \"$source_path\" \"$destination_path\"";
	my ($move_exit_status, $move_output) = run_ssh_command($computer_node_name, $management_node_keys, $move_command, '', '', 1);
	if (defined($move_exit_status) && $move_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "file moved: $source_path --> $destination_path, output:\n@{$move_output}");
	}
	elsif ($move_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to move file: $source_path --> $destination_path, exit status: $move_exit_status, output:\n@{$move_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to move file: $source_path --> $destination_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_directory_contents

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_files_by_pattern {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $base_directory = shift;
	my $pattern        = shift;
	my $max_depth      = shift || '5';

	# Make sure base directory and pattern were specified
	if (!($base_directory && $pattern)) {
		notify($ERRORS{'WARNING'}, 0, "base directory and pattern must be specified as arguments");
		return;
	}
	
	# Make sure base directory has trailing / or else find will fail
	$base_directory =~ s/[\/\\]*$/\//;

	notify($ERRORS{'DEBUG'}, 0, "attempting to delete files under $base_directory matching pattern $pattern, max depth: $max_depth");
	
	# Assemble command
	# Use find to locate all the files under the base directory matching the pattern specified
	# chmod 777 each file then call rm
	my $command = "/bin/find.exe \"$base_directory\" -mindepth 1 -maxdepth $max_depth -iregex \"$pattern\" -exec chmod 777 {} \\; -exec rm -rvf {} \\;";
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
	if (defined($exit_status)) {
		my @deleted = grep(/removed /, @$output);
		my @not_deleted = grep(/cannot remove/, @$output);
		notify($ERRORS{'OK'}, 0, scalar @deleted . "/" . scalar @not_deleted . " files deleted deleted under '$base_directory' matching '$pattern'");
		notify($ERRORS{'DEBUG'}, 0, "files/directories which were deleted:\n" . join("\n", @deleted)) if @deleted;
		notify($ERRORS{'DEBUG'}, 0, "files/directories which were NOT deleted:\n" . join("\n", @not_deleted)) if @not_deleted;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete files under $base_directory matching pattern $pattern");
		return;
	}

	return 1;
} ## end sub delete_files_by_pattern

#/////////////////////////////////////////////////////////////////////////////

=head2 filesystem_entry_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub filesystem_entry_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get the path from the subroutine arguments and make sure it was passed
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "unable to detmine if file exists, path was not specified as an argument");
		return;
	}
	
	# Replace backslashes with forward slashes
	$path =~ s/\\+/\//;

	# Assemble the ls command and execute it
	my $ls_command = "ls -la \"$path\"";
	my ($ls_exit_status, $ls_output) = run_ssh_command($computer_node_name, $management_node_keys, $ls_command, '', '', 1);
	if (defined($ls_exit_status) && $ls_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "filesystem entry exists on $computer_node_name: $path");
		return 1;
	}
	elsif (defined($ls_exit_status) && $ls_exit_status == 2) {
		notify($ERRORS{'DEBUG'}, 0, "filesystem entry does NOT exist on $computer_node_name: $path\noutput:\n" . join("\n", @$ls_output));
		return 0;
	}
	elsif ($ls_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if filesystem entry exists on $computer_node_name: $path, exit status: $ls_exit_status, output:\n@{$ls_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if filesystem entry exists on $computer_node_name: $path");
		return;
	}
} ## end sub filesystem_entry_exists

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

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

	return 1 if !@active_user_lines;

	notify($ERRORS{'OK'}, 0, "users are currently logged in on $computer_node_name:\n@active_user_lines");
	#>rdp-tcp#1 root 0 Active rdpwd
	foreach my $active_user_line (@active_user_lines) {
		$active_user_line =~ /[\s>]*(\S+)\s+(.*\w)\s*(\d+)\s+Active.*/;
		my $session_name = $1;
		my $username     = $2;
		my $session_id   = $3;

		notify($ERRORS{'DEBUG'}, 0, "user logged in: $username, session name: $session_name, session id: $session_id");
		#$ logoff /?
		#Terminates a session.
		#LOGOFF [sessionname | sessionid] [/SERVER:servername] [/V]
		#  sessionname         The name of the session.
		#  sessionid           The ID of the session.
		#  /SERVER:servername  Specifies the Terminal server containing the user
		#							 session to log off (default is current).
		#  /V                  Displays information about the actions performed.

		# Call logoff.exe, pass it the session name
		# Session ID fails if the ID is 0
		my ($logoff_exit_status, $logoff_output) = run_ssh_command($computer_node_name, $management_node_keys, "logoff.exe $session_name /V");
		if ($logoff_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "logged off user: $username");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to log off user: $username, exit status: $logoff_exit_status, output:\n@{$logoff_output}");
		}
	} ## end foreach my $active_user_line (@active_user_lines)
	return 1;
} ## end sub logoff_users

#/////////////////////////////////////////////////////////////////////////////

=head2 add_users

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub add_users {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Attempt to get the user array from the arguments
	# If no argument was supplied, use the users specified in the DataStructure
	my $user_array_ref = shift;
	my @users;
	if ($user_array_ref) {
		$user_array_ref = $self->data->get_imagemeta_usergroupmembers();
		@users          = @{$user_array_ref};
	}
	else {
		# User list was not specified as an argument
		# Use the imagemeta group members and the primary reservation user
		my $user_login_id      = $self->data->get_user_login_id();
		my $user_group_members = $self->data->get_imagemeta_usergroupmembers();

		push @users, $user_login_id;

		foreach my $user_group_member_uid (keys(%{$user_group_members})) {
			my $user_group_member_login_id = $user_group_members->{$user_group_member_uid};
			push @users, $user_group_member_login_id;
		}

		# Remove duplicate users
		@users = keys %{{map {$_, 1} @users}};
	}

	notify($ERRORS{'DEBUG'}, 0, "attempting to add " . scalar @users . " users to $computer_node_name: " . join(", ", @users));

	# Attempt to get the password from the arguments
	# If no argument was supplied, use the password specified in the DataStructure
	my $password = shift;
	if (!$password) {
		$password = $self->data->get_reservation_password();
	}

	# Loop through the users in the imagemeta group and attempt to add them
	for my $username (@users) {
		if (!$self->create_user($username, $password)) {
			notify($ERRORS{'WARNING'}, 0, "failed to add users to $computer_node_name");
			return 0;
		}
	}

	notify($ERRORS{'OK'}, 0, "added " . scalar @users . " users to $computer_node_name");
	return 1;
} ## end sub add_users

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_users

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub delete_users {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the user array from the arguments
	# If no argument was supplied, use the users specified in the DataStructure
	my $user_array_ref = shift;
	my @users;
	if ($user_array_ref) {
		$user_array_ref = $self->data->get_imagemeta_usergroupmembers();
		@users          = @{$user_array_ref};
	}
	else {
		# User list was not specified as an argument
		# Use the imagemeta group members and the primary reservation user
		my $user_login_id      = $self->data->get_user_login_id();
		my $user_group_members = $self->data->get_imagemeta_usergroupmembers();

		push @users, $user_login_id;

		foreach my $user_group_member_uid (keys(%{$user_group_members})) {
			my $user_group_member_login_id = $user_group_members->{$user_group_member_uid};
			push @users, $user_group_member_login_id;
		}

		# Remove duplicate users
		@users = keys %{{map {$_, 1} @users}};
	} ## end else [ if ($user_array_ref)

	# Loop through the users and attempt to delete them
	for my $username (@users) {
		if (!$self->delete_user($username)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete user $username from $computer_node_name");
			return 0;
		}
	}

	notify($ERRORS{'OK'}, 0, "deleted " . scalar @users . " users from $computer_node_name");
	return 1;
} ## end sub delete_users

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}

	notify($ERRORS{'DEBUG'}, 0, "checking if user $username exists on $computer_node_name");

	# Attempt to query the user account
	my $query_user_command = "net user \"$username\"";
	my ($query_user_exit_status, $query_user_output) = run_ssh_command($computer_node_name, $management_node_keys, $query_user_command, '', '', '1');
	if (defined($query_user_exit_status) && $query_user_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "user $username exists on $computer_node_name");
		return 1;
	}
	elsif (defined($query_user_exit_status) && $query_user_exit_status == 2) {
		notify($ERRORS{'DEBUG'}, 0, "user $username does not exist on $computer_node_name");
		return 0;
	}
	elsif (defined($query_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if user $username exists on $computer_node_name, exit status: $query_user_exit_status, output:\n@{$query_user_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if user $username exists on $computer_node_name");
		return;
	}
} ## end sub user_exists

#/////////////////////////////////////////////////////////////////////////////

=head2 create_user

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub create_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $imagemeta_rootaccess = $self->data->get_imagemeta_rootaccess();

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	my $password = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}
	if (!$password) {
		$password = $self->data->get_reservation_password();
	}

	# Check if user already exists
	if ($self->user_exists($username)) {
		notify($ERRORS{'OK'}, 0, "user $username already exists on $computer_node_name, attempting to delete user");

		# Attempt to delete the user
		if (!$self->delete_user($username)) {
			notify($ERRORS{'WARNING'}, 0, "failed to add user $username to $computer_node_name, user already exists and could not be deleted");
			return 0;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "attempting to add user $username to $computer_node_name ($password)");

	# Attempt to add the user account
	my $add_user_command = "net user \"$username\" \"$password\" /ADD /EXPIRES:NEVER /COMMENT:\"Account created by VCL\"";
	$add_user_command .= " && net localgroup \"Remote Desktop Users\" \"$username\" /ADD";
	
	# Add the user to the Administrators group if imagemeta.rootaccess isn't 0
	if (defined($imagemeta_rootaccess) && $imagemeta_rootaccess eq '0') {
		notify($ERRORS{'DEBUG'}, 0, "user will NOT be added to the Administrators group");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "user will be added to the Administrators group");
		$add_user_command .= " && net localgroup \"Administrators\" \"$username\" /ADD";
	}

	my ($add_user_exit_status, $add_user_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_user_command, '', '', '1');
	if (defined($add_user_exit_status) && $add_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "added user $username ($password) to $computer_node_name");
	}
	elsif (defined($add_user_exit_status) && $add_user_exit_status == 2) {
		notify($ERRORS{'OK'}, 0, "user $username was not added, user already exists");
		return 1;
	}
	elsif (defined($add_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add user $username to $computer_node_name, exit status: $add_user_exit_status, output:\n@{$add_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command add user $username to $computer_node_name");
		return;
	}

	return 1;
} ## end sub create_user

#/////////////////////////////////////////////////////////////////////////////

=head2 add_user_to_group

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub add_user_to_group {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	my $group    = shift;
	if (!$username || !$group) {
		notify($ERRORS{'WARNING'}, 0, "unable to add user to group, arguments were not passed correctly");
		return;
	}

	# Attempt to add the user to the group using net localgroup
	my $localgroup_user_command = "net localgroup \"$group\" $username /ADD";
	my ($localgroup_user_exit_status, $localgroup_user_output) = run_ssh_command($computer_node_name, $management_node_keys, $localgroup_user_command);
	if (defined($localgroup_user_exit_status) && $localgroup_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "added user $username to \"$group\" group on $computer_node_name");
	}
	elsif (defined($localgroup_user_exit_status) && $localgroup_user_exit_status == 2) {
		# Exit status is 2, this could mean the user is already a member or that the group doesn't exist
		# Check the output to determine what happened
		if (grep(/error 1378/, @{$localgroup_user_output})) {
			# System error 1378 has occurred.
			# The specified account name is already a member of the group.
			notify($ERRORS{'OK'}, 0, "user $username was not added to $group group because user already a member");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to add user $username to $group group on $computer_node_name, exit status: $localgroup_user_exit_status, output:\n@{$localgroup_user_output}");
			return 0;
		}
	} ## end elsif (defined($localgroup_user_exit_status) ... [ if (defined($localgroup_user_exit_status) ...
	elsif (defined($localgroup_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add user $username to $group group on $computer_node_name, exit status: $localgroup_user_exit_status, output:\n@{$localgroup_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to add user $username to $group group on $computer_node_name");
		return;
	}

	return 1;
} ## end sub add_user_to_group

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

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
		notify($ERRORS{'OK'}, 0, "user $username was not deleted because user does not exist");
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
	if ($self->delete_file("C:/Documents and Settings/$username")) {
		notify($ERRORS{'OK'}, 0, "deleted profile for user $username from $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete profile for user $username from $computer_node_name");
		return 0;
	}

	return 1;
} ## end sub delete_user

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
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	my $username = shift;
	my $password = shift;

	# If no argument was supplied, use the user specified in the DataStructure
	if (!defined($username)) {
		$username = $self->data->get_user_logon_id();
	}
	if (!defined($password)) {
		$password = $self->data->get_reservation_password();
	}

	# Make sure both the username and password were determined
	if (!defined($username) || !defined($password)) {
		notify($ERRORS{'WARNING'}, 0, "username and password could not be determined");
		return 0;
	}

	# Attempt to set the password
	notify($ERRORS{'DEBUG'}, 0, "setting password of $username to $password on $computer_node_name");
	my ($set_password_exit_status, $set_password_output) = run_ssh_command($computer_node_name, $management_node_keys, "net user $username '$password'");
	if ($set_password_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "password changed to '$password' for user '$username' on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to change password to '$password' for user '$username' on $computer_node_name, exit status: $set_password_exit_status, output:\n@{$set_password_output}");
		return 0;
	}

	# Check if root user, must set sshd service password too
	if ($username eq 'root') {
		notify($ERRORS{'DEBUG'}, 0, "root account password changed, must also change sshd service credentials");
		if (!$self->set_service_credentials('sshd', $username, $password)) {
			notify($ERRORS{'WARNING'}, 0, "failed to set sshd service credentials to $username ($password)");
			return 0;
		}
	}

	# Attempt to change scheduled task passwords
	notify($ERRORS{'DEBUG'}, 0, "changing passwords for scheduled tasks");
	my ($schtasks_query_exit_status, $schtasks_query_output) = run_ssh_command($computer_node_name, $management_node_keys, "schtasks.exe /Query /V /FO LIST", '', '', 1);
	if (defined($schtasks_query_exit_status) && $schtasks_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried scheduled tasks on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to query scheduled tasks on $computer_node_name, exit status: $schtasks_query_exit_status, output:\n@{$schtasks_query_output}");
		return 0;
	}

	# Find scheduled tasks configured to run as this user
	my $task_name;
	my @task_names_to_update;
	for my $schtasks_output_line (@{$schtasks_query_output}) {
		if ($schtasks_output_line =~ /TaskName:\s+([ \S]+)/i) {
			$task_name = $1;
		}
		if ($schtasks_output_line =~ /Run As User.*\\$username/i) {
			notify($ERRORS{'DEBUG'}, 0, "password needs to be updated for scheduled task: $task_name\n$schtasks_output_line");
			push @task_names_to_update, $task_name;
		}
	} ## end for my $schtasks_output_line (@{$schtasks_query_output...

	# Loop through the scheduled tasks configured to run as the user, update the password
	for my $task_name_to_update (@task_names_to_update) {
		my ($schtasks_change_exit_status, $schtasks_change_output) = run_ssh_command($computer_node_name, $management_node_keys, "schtasks.exe /Change /RP \"$password\" /TN \"$task_name_to_update\"");
		if (defined($schtasks_change_exit_status) && $schtasks_change_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "changed password for scheduled task: $task_name_to_update");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to change password for scheduled task: $task_name_to_update, exit status: $schtasks_change_exit_status, output:\n@{$schtasks_change_output}");
			return 0;
		}
	} ## end for my $task_name_to_update (@task_names_to_update)

	return 1;
} ## end sub set_password

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_user

 Parameters  : $username (optional
 Returns     : 
 Description : 

=cut

sub enable_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	my $username = shift;

	# If no argument was supplied, use the user specified in the DataStructure
	if (!defined($username)) {
		$username = $self->data->get_user_logon_id();
	}

	# Make sure the username was determined
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username could not be determined");
		return 0;
	}

	# Attempt to enable the user account (set ACTIVE=YES)
	notify($ERRORS{'DEBUG'}, 0, "enabling user $username on $computer_node_name");
	my ($enable_exit_status, $enable_output) = run_ssh_command($computer_node_name, $management_node_keys, "net user $username /ACTIVE:YES");
	if ($enable_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "user $username enabled on $computer_node_name");
	}
	elsif ($enable_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable user $username on $computer_node_name, exit status: $enable_exit_status, output:\n@{$enable_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to enable user $username on $computer_node_name");
		return 0;
	}

	return 1;
} ## end sub enable_user

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Set the registry key to blank
	my $memory_management_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';
	my $reg_add_command = '$SYSTEMROOT/System32/reg.exe add "' . $memory_management_key . '" /v PagingFiles /d "" /t REG_MULTI_SZ /f';
	my ($reg_add_exit_status, $reg_add_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_add_command, '', '', 1);
	if (defined($reg_add_exit_status) && $reg_add_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "set registry key to disable pagefile");
	}
	elsif (defined($reg_add_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to disable pagefile, exit status: $reg_add_exit_status, output:\n@{$reg_add_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set registry key to disable pagefile");
		return;
	}

	# Attempt to reboot the computer in order to delete the pagefile
	if ($self->reboot()) {
		notify($ERRORS{'DEBUG'}, 0, "computer was rebooted after disabling pagefile in the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reboot computer after disabling pagefile");
		return;
	}

	# Attempt to delete the pagefile
	if (!$self->delete_file("C:/pagefile.sys")) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete pagefile.sys");
		return;
	}

	return 1;
} ## end sub disable_pagefile

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_pagefile

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $memory_management_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';
	
	my $reg_add_command = '$SYSTEMROOT/System32/reg.exe add "' . $memory_management_key . '" /v PagingFiles /d "$SYSTEMDRIVE\\pagefile.sys 0 0" /t REG_MULTI_SZ /f';
	my ($reg_add_exit_status, $reg_add_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_add_command, '', '', 1);
	if (defined($reg_add_exit_status) && $reg_add_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "set registry key to enable pagefile");
	}
	elsif (defined($reg_add_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to enable pagefile, exit status: $reg_add_exit_status, output:\n@{$reg_add_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set registry key to enable pagefile");
		return;
	}

	return 1;
} ## end sub enable_pagefile

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This registry file contains the entries to disable all IPv6 components 
; http://support.microsoft.com/kb/929852

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters]
"DisabledComponents"=dword:ffffffff
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set registry keys to disable IPv6");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry keys to disable IPv6");
		return 0;
	}

	return 1;
} ## end sub disable_ipv6

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_file_path = shift;
	if (!defined($registry_file_path) || !$registry_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}

	my $registry_file_contents = `cat $registry_file_path`;
	notify($ERRORS{'DEBUG'}, 0, "registry file '$registry_file_path' contents:\n$registry_file_contents");

	$registry_file_contents =~ s/([\"])/\\$1/gs;
	$registry_file_contents =~ s/\\+"/\\"/gs;

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
} ## end sub import_registry_file

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string = shift;
	if (!defined($registry_string) || !$registry_string) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}

	#notify($ERRORS{'DEBUG'}, 0, "registry string:\n" . $registry_string);

	# Escape special characters with a backslash:
	# \
	# "
	#notify($ERRORS{'DEBUG'}, 0, "registry string:\n$registry_string");
	#$registry_string =~ s/\\+/\\\\\\\\/gs;
	$registry_string =~ s/\\/\\\\/gs;
	$registry_string =~ s/"/\\"/gs;

	# Replace \\" with \"
	#$registry_string =~ s/\\+(")/\\\\$1/gs;

	# Replace regular newlines with Windows newlines
	$registry_string =~ s/\r?\n/\r\n/gs;
	
	# Remove spaces from end of file
	$registry_string =~ s/\s+$//;

	# Assemble a temporary registry file path
	# Name the file after the sub which called this so you can tell where the .reg file was generated from
	my @caller = caller(1);
	my ($calling_sub) = $caller[3] =~ /([^:]+)$/;
	my $calling_line = $caller[2];
	my $temp_registry_file_path = "C:/Cygwin/tmp/$calling_sub\_$calling_line.reg";

	# Echo the registry string to a file on the node
	my $echo_registry_command = "rm -f $temp_registry_file_path; /usr/bin/echo.exe -E \"$registry_string\" > " . $temp_registry_file_path;
	my ($echo_registry_exit_status, $echo_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $echo_registry_command, '', '', 1);
	if (defined($echo_registry_exit_status) && $echo_registry_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "registry string contents echoed to $temp_registry_file_path");
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
		notify($ERRORS{'DEBUG'}, 0, "registry string contents imported from $temp_registry_file_path");
	}
	elsif ($import_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry string contents from $temp_registry_file_path, exit status: $import_registry_exit_status, output:\n@{$import_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry string contents from $temp_registry_file_path");
		return;
	}
	
	# Delete the temporary .reg file
	if (!$self->delete_file($temp_registry_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the temporary registry file: $temp_registry_file_path");
	}

	return 1;
} ## end sub import_registry_string

#/////////////////////////////////////////////////////////////////////////////

=head2 add_hklm_run_registry_key

 Parameters  :
 Returns     :
 Description :

=cut

sub add_hklm_run_registry_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $command_name = shift;
	my $command      = shift;

	notify($ERRORS{'DEBUG'}, 0, "command name: " . $command_name);
	notify($ERRORS{'DEBUG'}, 0, "command: " . $command);

	# Replace forward slashes with backslashes, unless a space precedes the forward slash
	$command =~ s/([^ ])\//$1\\/g;
	notify($ERRORS{'DEBUG'}, 0, "forward to backslash: " . $command);

	# Escape backslashes, can never have enough...
	$command =~ s/\\/\\\\/g;
	notify($ERRORS{'DEBUG'}, 0, "escape backslashes: " . $command);

	# Escape quotes
	$command =~ s/"/\\"/g;
	notify($ERRORS{'DEBUG'}, 0, "escaped quotes: " . $command);

	# Make sure arguments were supplied
	if (!defined($command_name) && !defined($command)) {
		notify($ERRORS{'WARNING'}, 0, "HKLM run registry key not added, arguments were not passed correctly");
		return 0;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run]
"$command_name"="$command"
EOF

	notify($ERRORS{'DEBUG'}, 0, "registry string:\n" . $registry_string);

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "added HKLM run registry value, name: $command_name, command: $command");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add HKLM run registry value, name: $command_name, command: $command");
		return 0;
	}
	
	# Attempt to query the registry key to make sure it was added
	my $reg_query_command = '$SYSTEMROOT/System32/reg.exe query "HKLM\\SOFTWARE\\Microsoft\Windows\\\CurrentVersion\\Run"';
	my ($reg_query_exit_status, $reg_query_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_query_command, '', '', 1);
	if (defined($reg_query_exit_status) && $reg_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried '$command_name' registry key:\n" . join("\n", @{$reg_query_output}));
	}
	elsif (defined($reg_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query '$command_name' registry key, exit status: $reg_query_exit_status, output:\n@{$reg_query_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to query '$command_name' registry key");
		return;
	}
	
	return 1;
} ## end sub add_hklm_run_registry_key

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_hklm_run_registry_value

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_hklm_run_registry_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $key_name = shift;
	
	# Make sure argument was supplied
	if (!defined($key_name) && !defined($key_name)) {
		notify($ERRORS{'WARNING'}, 0, "HKLM run registry key not deleted, argument was not passed correctly");
		return 0;
	}
	
	# Attempt to query the registry key to make sure it was added
	my $reg_delete_command = '$SYSTEMROOT/System32/reg.exe delete "HKLM\\SOFTWARE\\Microsoft\Windows\\\CurrentVersion\\Run" /v "' . $key_name . '" /F';
	my ($reg_delete_exit_status, $reg_delete_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_delete_command, '', '', 1);
	if (defined($reg_delete_exit_status) && $reg_delete_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted '$key_name' run registry key:\n" . join("\n", @{$reg_delete_output}));
	}
	elsif (defined($reg_delete_output) && grep(/unable to find/i, @{$reg_delete_output})) {
		notify($ERRORS{'OK'}, 0, "'$key_name' run registry key was not deleted, it does not exist");
	}
	elsif (defined($reg_delete_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$key_name' run registry key, exit status: $reg_delete_exit_status, output:\n@{$reg_delete_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to delete '$key_name' run registry key");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_scheduled_task

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $task_name     = shift;
	
	# Run schtasks.exe to delete any existing task
	my $delete_task_command = 'schtasks.exe /Delete /F /TN "' . $task_name . '"';
	my ($delete_task_exit_status, $delete_task_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_task_command);
	if (defined($delete_task_exit_status) && $delete_task_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted existing scheduled task '$task_name' on $computer_node_name");
	}
	elsif (defined($delete_task_output) && grep(/task.*does not exist/i, @{$delete_task_output})) {
		notify($ERRORS{'DEBUG'}, 0, "scheduled task '$task_name' does not already exist on $computer_node_name");
	}
	elsif (defined($delete_task_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to deleted existing scheduled task '$task_name' on $computer_node_name, exit status: $delete_task_exit_status, output:\n@{$delete_task_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command deleted existing scheduled task '$task_name' on $computer_node_name");
		return;
	}
	
	return 1;
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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $task_name     = shift;
	my $task_command  = shift;
	my $task_user     = shift;
	my $task_password = shift;

	# Escape backslashes, can never have enough...
	$task_command =~ s/\\/\\\\/g;

	# Replace forward slashes with backslashes
	$task_command =~ s/([^\s])\//$1\\\\/g;
	
	# Escape quote characters
	$task_command =~ s/"/\\"/g;

	# Make sure arguments were supplied
	if (!defined($task_name) || !defined($task_command) || !defined($task_user) || !defined($task_password)) {
		notify($ERRORS{'WARNING'}, 0, "startup scheduled task not added, arguments were not passed correctly");
		return;
	}

	# You cannot create a task if one with the same name already exists
	# Vista's version of schtasks.exe has a /F which forces a new task to be created if one with the same name already exists
	# This option isn't supported with XP and other older versions of Windows
	if (!$self->delete_scheduled_task($task_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete existing scheduled task '$task_name' on $computer_node_name");
	}
	
	# Run schtasks.exe to add the task
	# Occasionally see this error even though it schtasks.exe returns exit status 0:
	# WARNING: The Scheduled task "System Startup Script" has been created, but may not run because the account information could not be set.
	my $create_task_command = "schtasks.exe /Create /RU \"$task_user\" /RP \"$task_password\" /SC ONSTART /TN \"$task_name\" /TR \"$task_command\"";
	my ($create_task_exit_status, $create_task_output) = run_ssh_command($computer_node_name, $management_node_keys, $create_task_command);
	if (defined($create_task_output) && grep(/could not be set/i, @{$create_task_output})) {
		notify($ERRORS{'WARNING'}, 0, "created scheduled task '$task_name' on $computer_node_name but error occurred: " . join("\n", @{$create_task_output}));
		return 0;
	}
	elsif (defined($create_task_exit_status) && $create_task_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created scheduled task '$task_name' on $computer_node_name");
	}
	elsif (defined($create_task_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create scheduled task '$task_name' on $computer_node_name, exit status: $create_task_exit_status, output:\n@{$create_task_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command created scheduled task '$task_name' on $computer_node_name");
		return;
	}

	return 1;
} ## end sub create_startup_scheduled_task

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file enables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="1"
"DefaultUserName"="root"
"DefaultPassword"= "$WINDOWS_ROOT_PASSWORD"

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "enabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable autoadminlogon");
		return 0;
	}
} ## end sub enable_autoadminlogon

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

; This file disables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="0"
"AutoLogonCount"="0"
"DefaultPassword"= ""
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable autoadminlogon");
		return 0;
	}
} ## end sub disable_autoadminlogon

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $message = shift;

	# Make sure the message was passed as an argument
	if (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create eventlog entry, message was passed as an argument");
		return 0;
	}

	# Run eventcreate.exe to create an event log entry
	my $eventcreate_command = '$SYSTEMROOT/System32/eventcreate.exe /T INFORMATION /L APPLICATION /SO VCL /ID 555 /D "' . $message . '"';
	my ($eventcreate_exit_status, $eventcreate_output) = run_ssh_command($computer_node_name, $management_node_keys, $eventcreate_command);
	if (defined($eventcreate_exit_status) && $eventcreate_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created event log entry on $computer_node_name: $message");
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
} ## end sub create_eventlog_entry

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

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

	# Check if computer responds to ssh before preparing for reboot
	if ($self->wait_for_ssh(0)) {
		# Make sure SSH access is enabled from private IP addresses
		if (!$self->firewall_enable_ssh_private()) {
			notify($ERRORS{'WARNING'}, 0, "reboot not attempted, failed to enable ssh from private IP addresses");
			return 0;
		}

		# Set sshd service startup mode to auto
		if (!$self->set_service_startup_mode('sshd', 'auto')) {
			notify($ERRORS{'WARNING'}, 0, "reboot not attempted, unable to set sshd service startup mode to auto");
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
		if (defined($shutdown_exit_status) && $shutdown_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "executed reboot command on $computer_node_name");
		}
		elsif (defined($shutdown_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute reboot command on $computer_node_name, exit status: $shutdown_exit_status, output:\n@{$shutdown_output}");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to reboot $computer_node_name");
			return;
		}
	} ## end if ($self->wait_for_ssh(0))
	else {
		# Computer did not respond to ssh
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name did not respond to ssh, graceful reboot cannot be performed, attempting hard reset");

		# Call provisioning module's power_reset() subroutine
		if ($self->provisioner->power_reset()) {
			notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
			return 0;
		}
	} ## end else [ if ($self->wait_for_ssh(0))

	# Check if wait for reboot is set
	if (!$wait_for_reboot) {
		return 1;
	}

	# Wait for reboot is true
	notify($ERRORS{'OK'}, 0, "sleeping for 5 seconds while $computer_node_name begins to reboot");
	sleep 5;

	# Make multiple attempts to wait for the reboot to complete
	my $wait_attempt_limit = 2;
	WAIT_ATTEMPT:
	for (my $wait_attempt = 1; $wait_attempt <= $wait_attempt_limit; $wait_attempt++) {
		if ($wait_attempt > 1) {
			# Computer did not become fully responsive on previous wait attempt
			notify($ERRORS{'OK'}, 0, "$computer_node_name reboot failed to complete on previous attempt, attempting hard power reset");

			# Call provisioning module's power_reset() subroutine
			if ($self->provisioner->power_reset()) {
				notify($ERRORS{'OK'}, 0, "reboot attempt $wait_attempt/$wait_attempt_limit: initiated power reset on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
				return 0;
			}
		} ## end if ($wait_attempt > 1)

		# Wait maximum of 3 minutes for the computer to become unresponsive
		if (!$self->wait_for_no_ping(3)) {
			# Computer never stopped responding to ping
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
			next WAIT_ATTEMPT;
		}

		# Computer is unresponsive, reboot has begun
		# Wait for 15 seconds before beginning to check if computer is back online
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name reboot has begun, sleeping for 15 seconds");
		sleep 15;

		# Wait maximum of 4 minutes for the computer to come back up
		if (!$self->wait_for_ping(4)) {
			# Check if the computer was ever offline, it should have been or else reboot never happened
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping");
			next WAIT_ATTEMPT;
		}

		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is pingable, waiting for ssh to respond");

		# Wait maximum of 3 minutes for ssh to respond
		if (!$self->wait_for_ssh(3)) {
			notify($ERRORS{'WARNING'}, 0, "ssh never responded on $computer_node_name");
			next WAIT_ATTEMPT;
		}

		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name responded to ssh");
		
		## Wait then check ssh again in case initialization scripts are running
		## ssh may be available when the computer first boots, then network configuration scripts may automatically run
		## Make sure ssh is available a short time after it's first available
		#notify($ERRORS{'DEBUG'}, 0, "sleeping for 20 seconds then checking ssh again");
		#sleep 20;
		#
		## Wait maximum of 2 minutes for ssh to respond
		#if (!$self->wait_for_ssh(2)) {
		#	notify($ERRORS{'WARNING'}, 0, "ssh responded then stopped responding on $computer_node_name");
		#	next WAIT_ATTEMPT;
		#}

		# Reboot was successful, calculate how long reboot took
		my $reboot_end_time = time();
		my $reboot_duration = ($reboot_end_time - $reboot_start_time);
		notify($ERRORS{'OK'}, 0, "reboot complete on $computer_node_name, took $reboot_duration seconds");
		return 1;
	} ## end for (my $wait_attempt = 1; $wait_attempt <=...

	# If loop completed, maximum number of reboot attempts was reached
	notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, made $wait_attempt_limit attempts");
	return 0;
} ## end sub reboot

#/////////////////////////////////////////////////////////////////////////////

=head2 shutdown

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub shutdown {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	notify($ERRORS{'DEBUG'}, 0, "$computer_node_name will be shut down");

	# Initiate the shutdown.exe command to reboot the computer
	my $shutdown_command = "C:/Windows/system32/shutdown.exe -s -t 0 -f";
	my ($shutdown_exit_status, $shutdown_output) = run_ssh_command($computer_node_name, $management_node_keys, $shutdown_command);
	if (defined($shutdown_exit_status) && $shutdown_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed shutdown command on $computer_node_name");
		
		# Wait maximum of 3 minutes for the computer to become unresponsive
		if ($self->wait_for_no_ping(3)) {
			notify($ERRORS{'OK'}, 0, "computer has become unresponsive after shutdown command was issued");
			return 1;
		}
		else {
			# Computer never stopped responding to ping
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive after shutdown command was issued, attempting power off");
		}
	}
	elsif (defined($shutdown_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute shutdown command on $computer_node_name, exit status: $shutdown_exit_status, output:\n@{$shutdown_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to shutdown $computer_node_name");
	}
	
	# Call provisioning module's power_off() subroutine
	if ($self->provisioner->power_off()) {
		notify($ERRORS{'OK'}, 0, "powered off $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to power off $computer_node_name");
		return;
	}
	
	return 1;
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
	my $attempt_delay = 5;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 12) + 1;

	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ping, maximum of $total_wait_minutes minutes");

	# Loop until computer is pingable
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $computer_node_name is not pingable, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		if (_pingnode($computer_node_name)) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is pingable");
			return 1;
		}
	} ## end for (my $attempt = 1; $attempt <= $attempts...

	# Calculate how long this waited
	my $total_wait = ($attempts * $attempt_delay);
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is NOT pingable after waiting for $total_wait seconds");
	return 0;
} ## end sub wait_for_ping

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_no_ping

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is not pingable, 0 otherwise
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
					of minutes for ping to fail.

=cut

sub wait_for_no_ping {
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
	my $attempt_delay = 5;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 12) + 1;

	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to become unresponsive, maximum of $total_wait_minutes minutes");

	# Loop until computer is offline
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $computer_node_name is still pingable, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		if (!_pingnode($computer_node_name)) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is not pingable, returning 1");
			return 1;
		}
	} ## end for (my $attempt = 1; $attempt <= $attempts...

	# Calculate how long this waited
	my $total_wait = ($attempts * $attempt_delay);
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is still pingable after waiting for $total_wait seconds");
	return 0;
} ## end sub wait_for_no_ping

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the total number of minutes to wait from the arguments
	# If not specified, use default value
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}

	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 5;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 12) + 1;

	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ssh, maximum of $total_wait_minutes minutes");

	# Loop until ssh is available
	my $ssh_result = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $computer_node_name did not respond to ssh, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		# Try nmap to see if any of the ssh ports are open before attempting to run a test command
		if (!nmap_port($computer_node_name, 22) && !nmap_port($computer_node_name, 24)) {
			notify($ERRORS{'DEBUG'}, 0, "ports 22 and 24 are closed on $computer_node_name according to nmap");
			next;
		}

		# Run a test SSH command
		my ($exit_status, $output) = run_ssh_command({
			node => $computer_node_name,
			command => "echo testing ssh on $computer_node_name",
			max_attempts => 1,
			output_level => 0,
		});
		
		# The exit status will be 0 if the command succeeded
		if (defined($exit_status) && $exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is responding to ssh");
			return 1;
		}
	} ## end for (my $attempt = 1; $attempt <= $attempts...

	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not available via ssh");
	return 0;
} ## end sub wait_for_ssh

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

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
	my $service_startup_command = '"$SYSTEMROOT/System32/sc.exe" config ' . "$service_name start= $startup_mode";
	my ($service_startup_exit_status, $service_startup_output) = run_ssh_command($computer_node_name, $management_node_keys, $service_startup_command);
	if (defined($service_startup_output) && grep(/service does not exist/, @$service_startup_output)) {
		notify($ERRORS{'WARNING'}, 0, "$service_name service startup mode not set because service does not exist");
		return;
	}
	elsif (defined($service_startup_exit_status) && $service_startup_exit_status == 0) {
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
} ## end sub set_service_startup_mode

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Defragment the hard drive
	notify($ERRORS{'OK'}, 0, "beginning to defragment the hard drive on $computer_node_name");
	my ($defrag_exit_status, $defrag_output) = run_ssh_command($computer_node_name, $management_node_keys, '$SYSTEMROOT/System32/defrag.exe $SYSTEMDRIVE -v');
	if (defined($defrag_exit_status) && $defrag_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "hard drive defragmentation complete on $computer_node_name");
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
} ## end sub defragment_hard_drive

#/////////////////////////////////////////////////////////////////////////////

=head2 prepare_newsid

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : This subroutine prepares a computer to automatically run
               newsid.exe the next time it is booted. Newsid.exe is a utility
					which generates a new SID (security identifier) for the computer.
					
					This subroutine enables autoadminlogon so that root automatically
					logs on the next time the computer is booted.
					
					A registry key is created under
					HKLM\Software\Microsoft\Windows\CurrentVersion\Run.
					This key calls the run_newsid.cmd script. This script will run
					as root when it automatically logs on.
					
					The run_newsid.cmd script runs newsid.exe, removes the HKLM...Run
					key which caused itself to be called, and configures another
					HKLM...Run key to call post_load.cmd at next logon. The script
					then reboots the computer.

=cut

sub prepare_newsid {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $end_state = $self->{end_state} || 'off';
	
	# Get the node configuration directory
	my $node_configuration_directory = $self->get_node_configuration_directory();
	unless ($node_configuration_directory) {
		notify($ERRORS{'WARNING'}, 0, "node configuration directory could not be determined");
		return;
	}
	
	# Add HKLM run key to call run_newsid.cmd after the image comes up
	if (!$self->add_hklm_run_registry_key('run_newsid.cmd', $node_configuration_directory . '/Scripts/run_newsid.cmd  >> ' . $node_configuration_directory . '/Logs/run_newsid.log')) {
		notify($ERRORS{'WARNING'}, 0, "unable to create run key to call run_newsid.cmd");
		return;
	}
	
	# Enable autoadminlogon
	if (!$self->enable_autoadminlogon()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable autoadminlogon");
		return 0;
	}
	
	# Shut down computer unless end_state argument was passed with a value other than 'off'
	if ($end_state eq 'off') {
		if (!$self->shutdown()) {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down computer");
			return;
		}
	}
	
	return 1;
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

	my $reservation_id       = $self->data->get_reservation_id();
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $computer_id          = $self->data->get_computer_id();

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

; This registry file contains the entries to bypass the license agreement when newsid.exe is run

[HKEY_CURRENT_USER\Software\Sysinternals\NewSID]
"EulaAccepted"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "added newsid eulaaccepted registry string");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add newsid eulaaccepted registry string");
		return 0;
	}
	
	# Attempt to run newsid.exe
	# newsid.exe should automatically reboot the computer
	# It isn't done when the process exits, newsid.exe starts working and immediately returns
	# NewSid.exe [/a[[/n]|[/d <reboot delay (in seconds)>]]][<new computer name>]
	# /a - run without prompts
	# /n - Don't reboot after automatic run
	my $newsid_command = "\"$NODE_CONFIGURATION_DIRECTORY/Utilities/NewSID/newsid.exe\" /a";
	my $newsid_start_processing_time = time();
	my ($newsid_exit_status, $newsid_output) = run_ssh_command($computer_node_name, $management_node_keys, $newsid_command);
	if (defined($newsid_exit_status) && $newsid_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "newsid.exe has been started on $computer_node_name");
	}
	elsif (defined($newsid_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start newsid.exe on $computer_node_name, exit status: $newsid_exit_status, output:\n@{$newsid_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to start newsid.exe on $computer_node_name");
		return;
	}

	my $newsid_end_processing_time = time();
	my $newsid_processing_duration = ($newsid_end_processing_time - $newsid_start_processing_time);
	notify($ERRORS{'OK'}, 0, "newsid.exe execution took $newsid_processing_duration seconds");
	insertloadlog($reservation_id, $computer_id, "info", "newsid.exe execution took $newsid_processing_duration seconds");

	# After launching newsid.exe, wait for machine to become unresponsive
	if (!$self->wait_for_no_ping(10)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run newsid.exe, $computer_node_name never rebooted after waiting 10 minutes");
		return;
	}

	my $newsid_shutdown_time = time();
	notify($ERRORS{'OK'}, 0, "newsid.exe initiated reboot, $computer_node_name is unresponsive, reboot initialization took " . ($newsid_shutdown_time - $newsid_end_processing_time) . " seconds");

	# Wait maximum of 6 minutes for the computer to come back up
	if (!$self->wait_for_ping(6)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping, it never came back up");
		return 0;
	}

	my $newsid_ping_respond_time = time();
	notify($ERRORS{'OK'}, 0, "reboot nearly complete on $computer_node_name after running newsid.exe, ping response took " . ($newsid_ping_respond_time - $newsid_shutdown_time) . " seconds");

	# Ping successful, try ssh
	notify($ERRORS{'OK'}, 0, "waiting for ssh to respond on $computer_node_name");
	if (!$self->wait_for_ssh(3)) {
		notify($ERRORS{'WARNING'}, 0, "newsid.exe failed, $computer_node_name rebooted but ssh never became available");
		return 0;
	}

	my $newsid_ssh_respond_time = time();
	my $newsid_entire_duration  = ($newsid_ssh_respond_time - $newsid_start_processing_time);
	notify($ERRORS{'OK'}, 0, "newsid.exe succeeded on $computer_node_name, entire process took $newsid_entire_duration seconds");
	insertloadlog($reservation_id, $computer_id, "info", "entire newsid.exe process took $newsid_entire_duration seconds");

	return 1;
} ## end sub run_newsid

#/////////////////////////////////////////////////////////////////////////////

=head2 set_service_credentials

 Parameters  : $service_name, $username, $password
 Returns     : 
 Description : 

=cut

sub set_service_credentials {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	my $service_name = shift;
	my $username     = shift;
	my $password     = shift;

	# Make sure arguments were supplied
	if (!$service_name || !$username || !$password) {
		notify($ERRORS{'WARNING'}, 0, "set service logon failed, service name, username, and password arguments were not passed correctly");
		return 0;
	}

	# Attempt to set the service logon user name and password
	my $service_logon_command = '$SYSTEMROOT/System32/sc.exe config ' . $service_name . ' obj= ".\\' . $username . '" password= "' . $password . '"';
	my ($service_logon_exit_status, $service_logon_output) = run_ssh_command($computer_node_name, $management_node_keys, $service_logon_command);
	if (defined($service_logon_exit_status) && $service_logon_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "changed logon credentials for '$service_name' service to $username ($password) on $computer_node_name");
	}
	elsif (defined($service_logon_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to change $service_name service logon credentials to $username ($password) on $computer_node_name, exit status: $service_logon_exit_status, output:\n@{$service_logon_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to change $service_name service logon credentials to $username ($password) on $computer_node_name");
		return;
	}

	return 1;
} ## end sub set_service_credentials

#/////////////////////////////////////////////////////////////////////////////

=head2 get_service_list

 Parameters  : $service_name, $username, $password
 Returns     : 
 Description : 

=cut

sub get_service_list {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to delete the user account
	my $sc_query_command = "\$SYSTEMROOT/System32/sc.exe query | grep SERVICE_NAME | cut --fields=2 --delimiter=' '";
	my ($sc_query_exit_status, $sc_query_output) = run_ssh_command($computer_node_name, $management_node_keys, $sc_query_command);
	if (defined($sc_query_exit_status) && $sc_query_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "retrieved service list on $computer_node_name");
	}
	elsif (defined($sc_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve service list from $computer_node_name, exit status: $sc_query_exit_status, output:\n@{$sc_query_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to failed to retrieve service list from $computer_node_name");
		return;
	}

	my @service_name_array = split("\n", $sc_query_output);
	notify($ERRORS{'DEBUG'}, 0, "found " . @service_name_array . " services on $computer_node_name");
	return @service_name_array;
} ## end sub get_service_list

#/////////////////////////////////////////////////////////////////////////////

=head2 get_service_login_ids

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_services_using_login_id {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $login_id = shift;
	if (!$login_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to get services using login id, login id argument was not passed correctly");
		return;
	}

	# Get a list of the services on the node
	my @service_list = $self->get_service_list();
	if (!@service_list) {
		notify($ERRORS{'WARNING'}, 0, "unable to get service logon ids, failed to retrieve service name list from $computer_node_name, service credentials cannot be changed");
		return 0;
	}

	my @services_using_login_id;
	for my $service_name (@service_list) {
		# Attempt to get the service start name using sc.exe qc
		my $sc_qc_command = "\$SYSTEMROOT/System32/sc.exe qc $service_name | grep SERVICE_START_NAME | cut --fields=2 --delimiter='\\'";
		my ($sc_qc_exit_status, $sc_qc_output) = run_ssh_command($computer_node_name, $management_node_keys, $sc_qc_command);
		if (defined($sc_qc_exit_status) && $sc_qc_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "retrieved $service_name service start name from $computer_node_name");
		}
		elsif (defined($sc_qc_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve $service_name service start name from $computer_node_name, exit status: $sc_qc_exit_status, output:\n@{$sc_qc_output}");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to failed to retrieve $service_name service start name from $computer_node_name");
			return;
		}

		my $service_logon_id = @{$sc_qc_output}[0];
		if ($service_logon_id =~ /^$login_id$/i) {
			push @services_using_login_id, $service_logon_id;
		}
	} ## end for my $service_name (@service_list)

	return @services_using_login_id;
} ## end sub get_services_using_login_id

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_scheduled_task

 Parameters  : 
 Returns     : 1 success 0 failure
 Description : 

=cut

sub disable_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the task name from the arguments
	my $task_name = shift;
	if (!$task_name) {
		notify($ERRORS{'OK'}, 0, "failed to disable scheduled task, task name argument was not correctly passed");
		return;
	}

	# Attempt to delete the user account
	my $schtasks_command = '$SYSTEMROOT/System32/schtasks.exe /Change /DISABLE /TN "' . $task_name . '"';
	my ($schtasks_exit_status, $schtasks_output) = run_ssh_command($computer_node_name, $management_node_keys, $schtasks_command, '', '', 1);
	if (defined($schtasks_output) && grep(/have been changed/, @$schtasks_output)) {
		notify($ERRORS{'OK'}, 0, "$task_name scheduled task disabled on $computer_node_name");
	}
	elsif (defined($schtasks_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable $task_name scheduled task on $computer_node_name, exit status: $schtasks_exit_status, output:\n@{$schtasks_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to disable $task_name scheduled task on $computer_node_name");
		return;
	}

	return 1;
} ## end sub disable_scheduled_task

#/////////////////////////////////////////////////////////////////////////////

=head2 get_scheduled_tasks

 Parameters  : 
 Returns     : array reference if successful, false if failed
 Description : Queries the scheduled tasks on a computer and returns the
               configuration for each task. An array reference is returned.
					Each array element represents a scheduled task and contains
					a hash reference. The hash contains the schedule task
					configuration.  The hash keys are:
						$scheduled_task_hash{"HostName"},
						$scheduled_task_hash{"TaskName"},
						$scheduled_task_hash{"Next Run Time"},
						$scheduled_task_hash{"Status"},
						$scheduled_task_hash{"Last Run Time"},
						$scheduled_task_hash{"Last Result"},
						$scheduled_task_hash{"Creator"},
						$scheduled_task_hash{"Schedule"},
						$scheduled_task_hash{"Task To Run"},
						$scheduled_task_hash{"Start In"},
						$scheduled_task_hash{"Comment"},
						$scheduled_task_hash{"Scheduled Task State"},
						$scheduled_task_hash{"Scheduled Type"},
						$scheduled_task_hash{"Start Time"},
						$scheduled_task_hash{"Start Date"},
						$scheduled_task_hash{"End Date"},
						$scheduled_task_hash{"Days"},
						$scheduled_task_hash{"Months"},
						$scheduled_task_hash{"Run As User"},
						$scheduled_task_hash{"Delete Task If Not Rescheduled"},
						$scheduled_task_hash{"Stop Task If Runs X Hours and X Mins"},
						$scheduled_task_hash{"Repeat: Every"},
						$scheduled_task_hash{"Repeat: Until: Time"},
						$scheduled_task_hash{"Repeat: Until: Duration"},
						$scheduled_task_hash{"Repeat: Stop If Still Running"},
						$scheduled_task_hash{"Idle Time"},
						$scheduled_task_hash{"Power Management"}

=cut

sub get_scheduled_tasks {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to retrieve scheduled task information
	my $schtasks_command = '$SYSTEMROOT/System32/schtasks.exe /Query /NH /V /FO CSV';
	my ($schtasks_exit_status, $schtasks_output) = run_ssh_command($computer_node_name, $management_node_keys, $schtasks_command);
	if (defined($schtasks_exit_status) && $schtasks_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "retrieved scheduled task information");
	}
	elsif (defined($schtasks_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve scheduled task information, exit status: $schtasks_exit_status, output:\n@{$schtasks_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to retrieve scheduled task information");
		return;
	}
	
	my @scheduled_task_data;
	for my $scheduled_task_line (@{$schtasks_output}) {
		# Remove quotes from the hash values
		$scheduled_task_line =~ s/"//g;
		
		# Split the line up
		my @scheduled_task_fields = split(/,/, $scheduled_task_line);
		
		# Create a hash containing the line data
		my %scheduled_task_hash;
		($scheduled_task_hash{"HostName"},
		$scheduled_task_hash{"TaskName"},
		$scheduled_task_hash{"Next Run Time"},
		$scheduled_task_hash{"Status"},
		$scheduled_task_hash{"Last Run Time"},
		$scheduled_task_hash{"Last Result"},
		$scheduled_task_hash{"Creator"},
		$scheduled_task_hash{"Schedule"},
		$scheduled_task_hash{"Task To Run"},
		$scheduled_task_hash{"Start In"},
		$scheduled_task_hash{"Comment"},
		$scheduled_task_hash{"Scheduled Task State"},
		$scheduled_task_hash{"Scheduled Type"},
		$scheduled_task_hash{"Start Time"},
		$scheduled_task_hash{"Start Date"},
		$scheduled_task_hash{"End Date"},
		$scheduled_task_hash{"Days"},
		$scheduled_task_hash{"Months"},
		$scheduled_task_hash{"Run As User"},
		$scheduled_task_hash{"Delete Task If Not Rescheduled"},
		$scheduled_task_hash{"Stop Task If Runs X Hours and X Mins"},
		$scheduled_task_hash{"Repeat: Every"},
		$scheduled_task_hash{"Repeat: Until: Time"},
		$scheduled_task_hash{"Repeat: Until: Duration"},
		$scheduled_task_hash{"Repeat: Stop If Still Running"},
		$scheduled_task_hash{"Idle Time"},
		$scheduled_task_hash{"Power Management"}) = @scheduled_task_fields;
		
		push @scheduled_task_data, \%scheduled_task_hash;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@scheduled_task_data) . " scheduled tasks");
	
	return \@scheduled_task_data;
} ## end sub disable_scheduled_task

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_dynamic_dns

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_dynamic_dns {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file disables dynamic DNS updates

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableDynamicUpdate"=dword:00000001

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableReverseAddressRegistrations"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled dynamic dns");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable dynamic dns");
		return;
	}

	# Get the network configuration
	my $network_configuration = $self->get_network_configuration();
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	# Get the public and private interface names
	my $public_interface_name = $self->get_public_interface_name();
	my $private_interface_name = $self->get_private_interface_name();
	
	# Assemble netsh.exe commands to disable DNS registration
	my $netsh_command;
	$netsh_command .= "netsh.exe interface ip set dns";
	$netsh_command .= " name = \"$public_interface_name\"";
	$netsh_command .= " source = dhcp";
	$netsh_command .= " register = none";
	$netsh_command .= " ;";
	
	$netsh_command .= "netsh.exe interface ip set dns";
	$netsh_command .= " name = \"$private_interface_name\"";
	$netsh_command .= " source = dhcp";
	$netsh_command .= " register = none";
	$netsh_command .= " ;";
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	if (defined($netsh_exit_status)  && $netsh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "disabled dynamic DNS registration on public and private adapters");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable dynamic DNS registration on public and private adapters, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to disable dynamic DNS registration on public and private adapters");
		return;
	}

	return 1;
} ## end sub disable_dynamic_dns

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_netbios

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_netbios {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to query the registry for the NetBT service parameters
	my $reg_query_command = '$SYSTEMROOT/System32/reg.exe query "HKLM\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" /s';
	my ($reg_query_exit_status, $reg_query_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_query_command, '', '', 1);
	if (defined($reg_query_exit_status) && $reg_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried NetBT parameters registry keys");
	}
	elsif (defined($reg_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query NetBT parameters registry keys, exit status: $reg_query_exit_status, output:\n@{$reg_query_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to query NetBT parameters registry keys");
		return;
	}

	# Loop through the interfaces found, disable NetBIOS for any interface which has a NetbiosOptions key
	my $interface_key;
	for my $query_line (@{$reg_query_output}) {
		# Check if line is an interface key
		if ($query_line =~ /^(HKEY.*Tcpip.*})/i) {
			$interface_key = $1;
			next;
		}

		if ($query_line =~ /NetbiosOptions/i) {
			# Attempt to set the NetbiosOptions key
			my $reg_add_command = '$SYSTEMROOT/System32/reg.exe add "' . $interface_key . '" /v NetbiosOptions /d 2 /t REG_DWORD /f';
			my ($reg_add_exit_status, $reg_add_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_add_command, '', '', 1);
			if (defined($reg_add_exit_status) && $reg_add_exit_status == 0) {
				notify($ERRORS{'OK'}, 0, "disabled NetBIOS under: $interface_key");
			}
			elsif (defined($reg_add_exit_status)) {
				notify($ERRORS{'WARNING'}, 0, "failed to disable NetBIOS under: $interface_key, exit status: $reg_add_exit_status, output:\n@{$reg_add_output}");
				return 0;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to disable NetBIOS under: $interface_key");
				return;
			}
		} ## end if ($query_line =~ /NetbiosOptions/i)
	} ## end for my $query_line (@{$reg_query_output})

	# Attempt to stop the TCP/IP NetBIOS Helper service
	if ($self->stop_service('LmHosts')) {
		notify($ERRORS{'OK'}, 0, "TCP/IP NetBIOS Helper (LmHosts) service is stopped");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to stop the TCP/IP NetBIOS Helper (LmHosts) service");
	}

	# Attempt to disable the TCP/IP NetBIOS Helper service
	if ($self->set_service_startup_mode('LmHosts', 'disabled')) {
		notify($ERRORS{'OK'}, 0, "TCP/IP NetBIOS Helper (LmHosts) service is disabled");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable the TCP/IP NetBIOS Helper (LmHosts) service");
	}

	return 1;
} ## end sub disable_netbios

#/////////////////////////////////////////////////////////////////////////////

=head2 set_computer_description

 Parameters  :
 Returns     :
 Description :

=cut

sub set_computer_description {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to get the description from the arguments
	my $description = shift;
	if (!$description) {
		my $image_name       = $self->data->get_image_name();
		my $image_prettyname = $self->data->get_image_prettyname();
		$description = "$image_prettyname ($image_name)";
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters]
"srvcomment"="$description"
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set computer description to '$description'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set computer description to '$description'");
		return 0;
	}
} ## end sub set_computer_description

#/////////////////////////////////////////////////////////////////////////////

=head2 set_my_computer_name

 Parameters  :
 Returns     :
 Description :

=cut

sub set_my_computer_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $image_prettyname     = $self->data->get_image_prettyname();

	my $value = shift;
	$value = $image_prettyname if !$value;

	my $add_registry_command .= "\"\$SYSTEMROOT/System32/reg.exe\" add \"HKCR\\CLSID\\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\" /v LocalizedString /t REG_EXPAND_SZ /d \"$value\" /f";
	my ($add_registry_exit_status, $add_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_registry_command, '', '', 1);
	if (defined($add_registry_exit_status) && $add_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "my computer name changed to '$value'");
	}
	elsif ($add_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to change my computer name to '$value', exit status: $add_registry_exit_status, output:\n@{$add_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to change my computer name to '$value'");
		return;
	}

	return 1;
} ## end sub set_my_computer_name

#/////////////////////////////////////////////////////////////////////////////

=head2 get_currentimage_txt_contents

 Parameters  : 
 Returns     : array containing lines in currentimage.txt
 Description : 

=cut

sub get_currentimage_txt_contents {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to retrieve the contents of currentimage.txt
	my $cat_command = "cat ~/currentimage.txt";
	my ($cat_exit_status, $cat_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_command);
	if (defined($cat_exit_status) && $cat_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved currentimage.txt from $computer_node_name");
	}
	elsif (defined($cat_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve currentimage.txt from $computer_node_name, exit status: $cat_exit_status, output:\n@{$cat_output}");
		return ();
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to failed to retrieve currentimage.txt from $computer_node_name");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "found " . @{$cat_output} . " lines in currentimage.txt on $computer_node_name");

	return @{$cat_output};
} ## end sub get_currentimage_txt_contents

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_name

 Parameters  : 
 Returns     : string containing image name loaded on computer
 Description : 

=cut

sub get_current_image_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Get the contents of the currentimage.txt file
	my @current_image_txt_contents;
	if (@current_image_txt_contents = $self->get_currentimage_txt_contents()) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved currentimage.txt contents from $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve currentimage.txt contents from $computer_node_name");
		return;
	}

	# Make sure an empty array wasn't returned
	if (defined $current_image_txt_contents[0]) {
		my $current_image_name = $current_image_txt_contents[0];

		# Remove any line break characters
		$current_image_name =~ s/[\r\n]*//g;

		notify($ERRORS{'DEBUG'}, 0, "returning name of image currently loaded on $computer_node_name: $current_image_name");
		return $current_image_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "empty array was returned when currentimage.txt contents were retrieved from $computer_node_name");
		return;
	}
} ## end sub get_current_image_name

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	$netsh_command .= "netsh.exe firewall set icmpsetting";
	$netsh_command .= " type = 8";
	$netsh_command .= " mode = ENABLE";
	$netsh_command .= " profile = ALL";

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow ping");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow ping, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow ping");
		return;
	}

	return 1;
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
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable ping on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "ping will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "ping will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable ping on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "ping will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, ping will be enabled for all profiles");
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow ping on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow ping on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow ping on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ping_private

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	
	# Get the private interface name
	# Add command to disable ping on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved private interface name: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined");
	}
	
	# Get the public interface name
	# Add command to disable ping on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved public interface name: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "public interface name could not be determined");
	}
	
	# Add command to disable ping for all profiles
	$netsh_command .= "netsh.exe firewall set icmpsetting";
	$netsh_command .= " type = 8";
	$netsh_command .= " mode = DISABLE";
	$netsh_command .= " profile = ALL";
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow ping");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to disallow ping, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to disallow ping");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if the remote IP was passed correctly as an argument
	my $remote_ip = shift;
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable SSH on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to disable SSH on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on private interface because private interface name could not be determined");
	}
	
	$netsh_command .= "netsh.exe firewall set portopening";
	$netsh_command .= " name = \"Cygwin SSHD\"";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 22";
	$netsh_command .= " mode = ENABLE";
	
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'all addresses'; # Set only to display in output
		$netsh_command .= " scope = ALL";
	}
	else {
		$netsh_command .= " scope = CUSTOM";
		$netsh_command .= " addresses = $remote_ip";
	}

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow SSH from $remote_ip");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow SSH from $remote_ip, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow SSH from $remote_ip");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

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
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable SSH on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable SSH on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Cygwin SSHD\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, SSH will be enabled for all profiles");
		
		$netsh_command .= "netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Cygwin SSHD\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " profile = ALL";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow SSH on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow SSH on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow SSH on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_sessmgr

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_sessmgr {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Configure the firewall to allow the sessmgr.exe program
	my $netsh_command = "netsh firewall set allowedprogram name = \"Microsoft Remote Desktop Help Session Manager\" mode = ENABLE scope = ALL profile = ALL program = \"\$SYSTEMROOT\\system32\\sessmgr.exe\"";
	my ($netsh_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	if (defined($netsh_status) && $netsh_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "configured firewall to allow sessmgr.exe");
	}
	elsif (defined($netsh_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow sessmgr.exe, exit status: $netsh_status, output:\n@{$netsh_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to configure firewall to allow sessmgr.exe");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 allow_remote_access

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub allow_remote_access {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Set the registry key that allows users to connect remotely
	# This key is configured by the "Allow users to connect remotely to this computer" checkbox
	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server]
"fDenyTSConnections"=dword:00000000
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set registry key to allow users to connect remotely");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to allow users to connect remotely");
		return;
	}
	
	return 1;
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
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $netsh_command;
	$netsh_command .= "netsh.exe firewall set portopening";
	$netsh_command .= " name = \"Remote Desktop\"";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 3389";
	$netsh_command .= " mode = ENABLE";
	
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'all addresses'; # Set only to display in output
		$netsh_command .= " scope = ALL";
	}
	else {
		$netsh_command .= " scope = CUSTOM";
		$netsh_command .= " addresses = $remote_ip";
	}

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow RDP from $remote_ip");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow RDP from $remote_ip, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow RDP from $remote_ip");
		return;
	}
} ## end sub firewall_enable_rdp

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable RDP on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "RDP will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable RDP on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Remote Desktop\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, RDP will be enabled for all profiles");
		
		$netsh_command .= "netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Remote Desktop\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " profile = ALL";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow RDP on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow RDP on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow RDP on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

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
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $netsh_command;
	
	# Get the private interface name
	# Add command to disable RDP on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined");
	}
	
	# Get the public interface name
	# Add command to disable RDP on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "public interface name could not be determined");
	}
	
	# Add command to disable RDP for all profiles
	$netsh_command .= "netsh.exe firewall delete portopening";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 3389";
	$netsh_command .= " profile = ALL";

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /Ok\./i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow RDP");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to disallow RDP, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to disallow RDP");
		return;
	}
	
	return 1;
} ## end sub firewall_disable_rdp

#/////////////////////////////////////////////////////////////////////////////

=head2 get_network_configuration

 Parameters  : 
 Returns     :
 Description : Retrieves the network configuration from the computer. Returns
               a hash. The hash keys are the interface names:
					$hash{<interface name>}{dhcp_enabled}
					$hash{<interface name>}{description}
					$hash{<interface name>}{ip_address}
					$hash{<interface name>}{subnet_mask}
					$hash{<interface name>}{default_gateway}
					
					The hash also contains 2 keys containing the names of the
					public and private interfaces:
					$hash{public_name}
					$hash{private_name}

=cut

sub get_network_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Check if a 'public' or 'private' network type argument was specified
	my $network_type = lc(shift());
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}
	
	my %network_configuration;
	if (!$self->{network_configuration}) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve network configuration");
		
		# Run ipconfig /all
		my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, '$SYSTEMROOT/System32/ipconfig.exe /all', '', '', 1);
		if (defined($exit_status) && $exit_status == 0) {
			notify($ERRORS{'DEBUG'}, 0, "ran ipconfig");
		}
		elsif (defined($exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run ipconfig, exit status: $exit_status, output:\n@{$output}");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run the SSH command to run ipconfig");
			return;
		}
	
		my $interface_name;
		my $previous_ip = 0;
		my $setting;
		
		for my $line (@{$output}) {
			# Find beginning of interface section
			if ($line =~ /ethernet adapter (.*):/i) {
				# Get the interface name
				$interface_name = $1;
				next;
			}
			
			# Skip line if interface hasn't been found yet
			next if !$interface_name;
			
			# Take apart the line finding the setting name and value with a hideous regex
			my ($line_setting, $value) = $line =~ /^[ ]{1,8}(\w[^\.]*\w)?[ \.:]+([^\r\n]*)/i;
			
			# If the setting was found in the line, use it
			# Otherwise, use the last found setting
			$setting = $line_setting if $line_setting;
			
			# Skip line if value wasn't found
			next if !$value;
			
			# Normalize the setting format, make it lowercase, convert dashes and spaces to underscores
			$setting = lc($setting);
			$setting =~ s/[ -]/_/;
			
			# Windows 6.x includes a version indicator in IP address lines such as IPv4, remove this
			$setting =~ s/ip(v\d)?_address/ip_address/;
			
			# Remove the trailing s from dns_servers
			$setting =~ s/dns_servers/dns_server/;
			
			# Check which setting was found and add to hash
			if ($setting =~ /dns_servers/) {
				push(@{$network_configuration{$interface_name}{$setting}}, $value);
				#notify($ERRORS{'OK'}, 0, "$interface_name:$setting = @{$network_configuration{$interface_name}{$setting}}");
			}
			elsif ($setting =~ /ip_address/) {
				$value =~ s/[^\.\d]//g;
				$network_configuration{$interface_name}{$setting}{$value} = '';
				$previous_ip = $value;
				#notify($ERRORS{'OK'}, 0, "$interface_name:$setting = $network_configuration{$interface_name}{$setting}{$value}");
			}
			elsif ($setting =~ /subnet_mask/) {
				$network_configuration{$interface_name}{ip_address}{$previous_ip} = $value;
				#notify($ERRORS{'OK'}, 0, "$interface_name:$setting($previous_ip) = $network_configuration{$interface_name}{ip_address}{$previous_ip}");
			}
			else {
				$network_configuration{$interface_name}{$setting} = $value;
				#notify($ERRORS{'OK'}, 0, "$interface_name:$setting = $network_configuration{$interface_name}{$setting}");
			}
		}
		
		notify($ERRORS{'DEBUG'}, 0, 'saving network configuration in $self->{network_configuration}');
		$self->{network_configuration} = \%network_configuration;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "network configuration has already been retrieved");
		%network_configuration = %{$self->{network_configuration}};
	}

#print "\n\n" . format_data(\%network_configuration) . "\n\n";	

	# 'public' or 'private' wasn't specified, return all network interface information
	if (!$network_type) {
		return \%network_configuration;
	}
	
	# Get the computer private IP address
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
	if (!$computer_private_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
		return;
	}
	
	my $computer_public_ip_address;
	
	my %public_interface;
	
	# Loop through all of the network interfaces found
	foreach my $interface_name (sort keys %network_configuration) {
		my @ip_addresses  = keys %{$network_configuration{$interface_name}{ip_address}};
		my $description = $network_configuration{$interface_name}{description};
		$description = '' if !$description;

		# Make sure an IP address was found
		if (!@ip_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "interface does not have an ip address: $interface_name");
			next;
		}
		elsif (grep(/$computer_private_ip_address/, @ip_addresses)) {
			# If private interface information was requested, return a hash containing only this interface
			notify($ERRORS{'DEBUG'}, 0, "private interface found: $interface_name, description: $description, address(es): " . join (", ", @ip_addresses));
			if ($network_type =~ /private/i) {
				my %return_hash = ($interface_name => $network_configuration{$interface_name});
				notify($ERRORS{'DEBUG'}, 0, "returning data for private interface: $interface_name (" . join (", ", @ip_addresses) . ")");
				return \%return_hash;
			}
			else {
				next;
			}
		}
		
		# Check if the interface should be ignored based on the name or description
		if ($interface_name =~ /loopback|vmnet|afs/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface ignored because of name: $interface_name, description: $description, address(es): " . join (", ", @ip_addresses));
			next;
		}
		elsif ($description =~ /loopback|virtual|afs/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface ignored because of description: $interface_name, description: $description, address(es): " . join (", ", @ip_addresses));
			next;
		}
		
		# Loop through the IP addresses for the interface
		# Once a public address is found, return the data for that interface
		for my $ip_address (@ip_addresses) {
			# Split up the IP address being checked into its octets
			my @octets = split(/\./, $ip_address);
			
			# Determine if this is a private or public address
			# Private:
			#   10.0.0.0    - 10.255.255.255
			#   172.16.0.0  - 172.16.31.255.255
			#   192.168.0.0 - 192.168.255.255
			if (($octets[0] == 10) ||
				 ($octets[0] != 172 && ($octets[1] >= 16 && $octets[1] <= 31)) ||
				 ($octets[0] == 192 && $octets[1] == 168)
				) {
				notify($ERRORS{'DEBUG'}, 0, "interface found with private address not matching private address for reservation: $interface_name, description: $description, address(es): " . join (", ", @ip_addresses));
				
				if (keys(%public_interface)) {
					notify($ERRORS{'DEBUG'}, 0, "already found another interface with a private address not matching private address for reservation, this one will be used if a public address isn't found");
					next;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "interface will be returned if another with a public address isn't found");
					$public_interface{$interface_name} = $network_configuration{$interface_name};
				}
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "public interface found: $interface_name, description: $description, address(es): " . join (", ", @ip_addresses));
				my %return_hash = ($interface_name => $network_configuration{$interface_name});
				notify($ERRORS{'DEBUG'}, 0, "returning data for public interface: $interface_name (" . join (", ", @ip_addresses) . ")");
				return \%return_hash;
			}
		}
	}

	if ($network_type =~ /private/i) {
		notify($ERRORS{'WARNING'}, 0, "did not find an interface using the private IP address for the reservation: $computer_private_ip_address\n" . format_data(\%network_configuration));
		return;
	}
	elsif (keys(%public_interface)) {
		notify($ERRORS{'OK'}, 0, "did not find a public interface using a public IP address, but found interface using private IP address not matching reservation private IP address, returning data for public interface:\n" . format_data(\%public_interface));
		return \%public_interface;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the public interface:\n" . format_data(\%network_configuration));
		return;
	}
	
} ## end sub get_network_configuration

#/////////////////////////////////////////////////////////////////////////////

=head2 get_private_interface_name

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_interface_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Make sure network configuration was retrieved
	my $network_configuration = $self->get_network_configuration('private');
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	my $interface_name = (keys(%{$network_configuration}))[0];
	notify($ERRORS{'DEBUG'}, 0, "returning private interface name: $interface_name");
	
	return $interface_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_interface_name

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_interface_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Make sure network configuration was retrieved
	my $network_configuration = $self->get_network_configuration('public');
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	my $interface_name = (keys(%{$network_configuration}))[0];
	notify($ERRORS{'DEBUG'}, 0, "returning public interface name: $interface_name");
	
	return $interface_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_private_ip_addresses

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Make sure network configuration was retrieved
	my $network_configuration = $self->get_network_configuration('private');
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	my $interface_name = (keys(%{$network_configuration}))[0];
	
	my $ip_address = $network_configuration->{$interface_name}{ip_address};
	notify($ERRORS{'DEBUG'}, 0, "returning IP address: $ip_address");
	
	return $ip_address;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_addresses

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Make sure network configuration was retrieved
	my $network_configuration = $self->get_network_configuration('public');
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	my $interface_name = (keys(%{$network_configuration}))[0];
	
	my $ip_address = $network_configuration->{$interface_name}{ip_address};
	notify($ERRORS{'DEBUG'}, 0, "returning IP address: $ip_address");
	
	return $ip_address;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_dhcp

 Parameters  : 
 Returns     :
 Description : 

=cut

sub enable_dhcp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $interface_name_argument = shift;
	my @interface_names;
	if (!$interface_name_argument) {
		push(@interface_names, $self->get_public_interface_name());
		push(@interface_names, $self->get_private_interface_name());
	}
	elsif ($interface_name_argument =~ /public/i) {
		push(@interface_names, $self->get_public_interface_name());
	}
	elsif ($interface_name_argument =~ /private/i) {
		push(@interface_names, $self->get_private_interface_name());
	}
	else {
		push(@interface_names, $interface_name_argument);
	}

	for my $interface_name (@interface_names) {
		# Use netsh to set the NIC to use DHCP
		my $set_dhcp_command = '$SYSTEMROOT/System32/netsh.exe interface ip set address name="' . $interface_name . '" source=dhcp';
		my ($set_dhcp_status, $set_dhcp_output) = run_ssh_command($computer_node_name, $management_node_keys, $set_dhcp_command);
		if (defined($set_dhcp_status) && $set_dhcp_status == 0) {
			notify($ERRORS{'OK'}, 0, "set interface '$interface_name' to use dhcp");
		}
		elsif (defined($set_dhcp_output) && grep(/dhcp is already enabled/i, @{$set_dhcp_output})) {
			notify($ERRORS{'OK'}, 0, "dhcp is already enabled on interface '$interface_name'");
		}
		elsif (defined($set_dhcp_status)) {
			notify($ERRORS{'WARNING'}, 0, "unable to set interface '$interface_name' to use dhcp, exit status: $set_dhcp_status, output:\n@{$set_dhcp_output}");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to set interface '$interface_name' to use dhcp");
			return 0;
		}
	} ## end for my $interface_name (@interface_names)
	
	# Run ipconfig /renew after setting the adapters to use DHCP
	# The default gateway gets lost otherwise
	return $self->ipconfig_renew();
} ## end sub enable_dhcp

#/////////////////////////////////////////////////////////////////////////////

=head2 ipconfig_renew

 Parameters  : 
 Returns     :
 Description : 

=cut

sub ipconfig_renew {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $interface_name_argument = shift;
	
	# Assemble the ipconfig command, include the interface name if argument was specified
	my $ipconfig_command = '$SYSTEMROOT/System32/ipconfig.exe /renew';
	if ($interface_name_argument) {
		$ipconfig_command .= " \"$interface_name_argument\"";
	}
	
	# Run ipconfig
	my ($ipconfig_status, $ipconfig_output) = run_ssh_command($computer_node_name, $management_node_keys, $ipconfig_command);
	if (defined($ipconfig_status) && $ipconfig_status == 0) {
		notify($ERRORS{'OK'}, 0, "ran ipconfig /renew");
	}
	elsif (defined($ipconfig_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to run ipconfig /renew, exit status: $ipconfig_status, output:\n@{$ipconfig_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to to run ipconfig /renew");
		return 0;
	}
	
	return 1;
} 

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_capture_configuration_files

 Parameters  : 
 Returns     :
 Description : Deletes the capture configuration directory.

=cut

sub delete_capture_configuration_files {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Remove old logon and logoff scripts
	$self->delete_files_by_pattern('$SYSTEMROOT/system32/GroupPolicy/User/Scripts', '.*\(Prepare\|prepare\|Cleanup\|cleanup\|post_load\).*');

	# Remove old scripts and utilities
	$self->delete_files_by_pattern('C:/Cygwin/home/root', '.*\(vbs\|exe\|cmd\|bat\|log\)');
	
	# Remove old C:\VCL directory if it exists
	$self->delete_file('C:/VCL');
	
	# Delete VCL scheduled task if it exists
	$self->delete_scheduled_task('VCL Startup Configuration');
	
	## Remove VCLprepare.cmd and VCLcleanup.cmd lines from scripts.ini file
	$self->remove_group_policy_script('logon', 'VCLprepare.cmd');
	$self->remove_group_policy_script('logoff', 'VCLcleanup.cmd');
	
	# Remove old root Application Data/VCL directory
	$self->delete_file('$SYSTEMDRIVE/Documents and Settings/root/Application Data/VCL');

	# Remove existing configuration files if they exist
	notify($ERRORS{'OK'}, 0, "attempting to remove old configuration directory if it exists: $NODE_CONFIGURATION_DIRECTORY");
	if (!$self->delete_file($NODE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing configuration directory: $NODE_CONFIGURATION_DIRECTORY");
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_group_policy_script

 Parameters  : 
 Returns     :
 Description : 

=cut

sub add_group_policy_script {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get the arguments
	my $stage_argument = shift;
	my $cmdline_argument = shift;
	my $parameters_argument = shift;
	if (!$stage_argument || $stage_argument !~ /^(logon|logoff)$/i) {
		notify($ERRORS{'WARNING'}, 0, "stage (logon/logoff) argument was not specified");
		return;
	}	
	if (!$cmdline_argument) {
		notify($ERRORS{'WARNING'}, 0, "CmdLine argument was not specified");
		return;
	}
	if (!$parameters_argument) {
		$parameters_argument = '';
	}
	
	# Capitalize the first letter of logon/logoff
	$stage_argument = lc($stage_argument);
	$stage_argument = "L" . substr($stage_argument, 1);
	
	# Store the stage name (logon/logoff) not being modified
	my $opposite_stage_argument;
	if ($stage_argument =~ /logon/i) {
		$opposite_stage_argument = 'Logoff';
	}
	else {
		$opposite_stage_argument = 'Logon';
	}

	# Path to scripts.ini file
	my $scripts_ini = '$SYSTEMROOT/system32/GroupPolicy/User/Scripts/scripts.ini';
	
	# Set the owner of scripts.ini to root
	my $chown_command = "touch $scripts_ini && chown root $scripts_ini";
	my ($chown_status, $chown_output) = run_ssh_command($computer_node_name, $management_node_keys, $chown_command);
	if (defined($chown_status) && $chown_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "set root as owner of scripts.ini");
	}
	elsif (defined($chown_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set root as owner of scripts.ini, exit status: $chown_status, output:\n@{$chown_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to set root as owner of scripts.ini");
	}
	
	# Set the permissions of scripts.ini to 664
	my $chmod_command = "chmod 664 $scripts_ini";
	my ($chmod_status, $chmod_output) = run_ssh_command($computer_node_name, $management_node_keys, $chmod_command);
	if (defined($chmod_status) && $chmod_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran chmod on scripts.ini");
	}
	elsif (defined($chmod_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run chmod 664 on scripts.ini, exit status: $chmod_status, output:\n@{$chmod_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run chmod 664 on scripts.ini");
	}
	
	# Clear hidden, system, and readonly flags on scripts.ini
	my $attrib_command = "attrib -H -S -R $scripts_ini";
	my ($attrib_status, $attrib_output) = run_ssh_command($computer_node_name, $management_node_keys, $attrib_command);
	if (defined($attrib_status) && $attrib_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran attrib -H -S -R on scripts.ini");
	}
	elsif (defined($attrib_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run attrib -H -S -R on scripts.ini, exit status: $attrib_status, output:\n@{$attrib_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run attrib -H -S -R on scripts.ini");
	}
	
	# Get the contents of scripts.ini
	my $cat_command = "cat $scripts_ini";
	my ($cat_status, $cat_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_command, '', '', 1);
	if (defined($cat_status) && $cat_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved scripts.ini contents:\n" . join("\n", @{$cat_output}));
	}
	elsif (defined($cat_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to cat scripts.ini contents");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to scripts.ini contents");
	}
	
	# Create a string containing all of the lines in scripts.ini
	my $scripts_ini_string = join("\n", @{$cat_output}) || '';
	
	# Remove any carriage returns to make pattern matching easier
	$scripts_ini_string =~ s/\r//gs;
	
	# Get a string containing just the section being modified (logon/logoff)
	my ($section_string) = $scripts_ini_string =~ /(\[$stage_argument\][^\[\]]*)/is;
	$section_string = "[$stage_argument]" if !$section_string;
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $stage_argument section:\n" . string_to_ascii($section_string));
	
	my ($opposite_section_string) = $scripts_ini_string =~ /(\[$opposite_stage_argument\][^\[\]]*)/is;
	$opposite_section_string = "[$opposite_stage_argument]" if !$opposite_section_string;
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $opposite_stage_argument section:\n" . string_to_ascii($opposite_section_string));
	
	my @section_lines = split(/[\r\n]+/, $section_string);
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $stage_argument section line count: " . scalar @section_lines);
	
	my %scripts_original;
	for my $section_line (@section_lines) {
		if ($section_line =~ /(\d+)Parameters\s*=(.*)/i) {
			my $index = $1;
			my $parameters = $2;
			if (!defined $scripts_original{$index}{Parameters}) {
				$scripts_original{$index}{Parameters} = $parameters;
				#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument parameters:\nline: '$section_line'\nparameters: '$parameters'\nindex: $index");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "found duplicate $stage_argument parameters line for index $index");
			}
		}
		elsif ($section_line =~ /(\d+)CmdLine\s*=(.*)/i) {
			my $index = $1;
			my $cmdline = $2;
			if (!defined $scripts_original{$index}{CmdLine}) {
				$scripts_original{$index}{CmdLine} = $cmdline;
				#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument cmdline:\nline: '$section_line'\ncmdline: '$cmdline'\nindex: $index");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "found duplicate $stage_argument CmdLine line for index $index");
			}
		}
		elsif ($section_line =~ /\[$stage_argument\]/i) {
			#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument heading:\nline: '$section_line'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "found unexpected line: '$section_line'");
		}
	}
	
	my %scripts_modified;
	my $index_modified = 0;
	foreach my $index (sort keys %scripts_original) {
		if (!defined $scripts_original{$index}{CmdLine}) {
			notify($ERRORS{'WARNING'}, 0, "CmdLine not specified for index $index");
			next;
		}
		elsif ($scripts_original{$index}{CmdLine} =~ /^\s*$/) {
			notify($ERRORS{'WARNING'}, 0, "CmdLine blank for index $index");
			next;
		}
		if (!defined $scripts_original{$index}{Parameters}) {
			notify($ERRORS{'WARNING'}, 0, "Parameters not specified for index $index");
			$scripts_original{$index}{Parameters} = '';
		}
		
		if ($scripts_original{$index}{CmdLine} =~ /$cmdline_argument/i && $scripts_original{$index}{Parameters} =~ /$parameters_argument/i) {
			notify($ERRORS{'DEBUG'}, 0, "replacing existing $stage_argument script at index $index:\ncmdline: $scripts_original{$index}{CmdLine}\nparameters: $scripts_original{$index}{Parameters}");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retaining existing $stage_argument script at index $index:\ncmdline: $scripts_original{$index}{CmdLine}\nparameters: $scripts_original{$index}{Parameters}");
			$scripts_modified{$index_modified}{CmdLine} = $scripts_original{$index}{CmdLine};
			$scripts_modified{$index_modified}{Parameters} = $scripts_original{$index}{Parameters};
			$index_modified++;
		}
	}
	
	# Add the argument script to the hash
	$scripts_modified{$index_modified}{CmdLine} = $cmdline_argument;
	$scripts_modified{$index_modified}{Parameters} = $parameters_argument;
	$index_modified++;
	
	#notify($ERRORS{'DEBUG'}, 0, "arguments:\ncmdline: $cmdline_argument\nparameters: $parameters_argument");
	#notify($ERRORS{'DEBUG'}, 0, "original $stage_argument scripts data:\n" . format_data(\%scripts_original));
	#notify($ERRORS{'DEBUG'}, 0, "modified $stage_argument scripts data:\n" . format_data(\%scripts_modified));
	
	my $section_string_new = "[$stage_argument]\n";
	foreach my $index_new (sort keys(%scripts_modified)) {
		$section_string_new .= $index_new . "CmdLine=$scripts_modified{$index_new}{CmdLine}\n";
		$section_string_new .= $index_new . "Parameters=$scripts_modified{$index_new}{Parameters}\n";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "original $stage_argument scripts section:\n$section_string");
	notify($ERRORS{'DEBUG'}, 0, "modified $stage_argument scripts section:\n$section_string_new");
	
	my $scripts_ini_modified;
	if ($stage_argument =~ /logon/i) {
		$scripts_ini_modified = "$section_string_new\n$opposite_section_string";
	}
	else {
		$scripts_ini_modified = "$opposite_section_string\n$section_string_new";
	}
	notify($ERRORS{'DEBUG'}, 0, "modified scripts.ini contents:\n$scripts_ini_modified");
	
	# Escape quote characters
	$scripts_ini_modified =~ s/"/\\"/gs;
	
	# Echo the modified contents to scripts.ini
	my $echo_command = "echo \"$scripts_ini_modified\" > $scripts_ini";
	my ($echo_status, $echo_output) = run_ssh_command($computer_node_name, $management_node_keys, $echo_command);
	if (defined($echo_status) && $echo_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "echo'd modified contents to scripts.ini");
	}
	elsif (defined($echo_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to echo modified contents to scripts.ini, exit status: $echo_status, output:\n@{$echo_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to echo modified contents to scripts.ini");
		return;
	}
	
	# Run unix2dos on scripts.ini
	$self->run_unix2dos($scripts_ini);
	
	# Get the modified contents of scripts.ini
	my $cat_modified_command = "cat $scripts_ini";
	my ($cat_modified_status, $cat_modified_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_modified_command, '', '', 1);
	if (defined($cat_modified_status) && $cat_modified_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved modified scripts.ini contents");
	}
	elsif (defined($cat_modified_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to cat scripts.ini contents");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to scripts.ini contents");
	}
	
	## Run gpupdate so the new settings take effect immediately
	#$self->run_gpupdate();
	
	notify($ERRORS{'OK'}, 0, "added '$cmdline_argument' $stage_argument script to scripts.ini\noriginal contents:\n$scripts_ini_string\n-----\nnew contents:\n" . join("\n", @{$cat_modified_output}));
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_group_policy_script

 Parameters  : 
 Returns     :
 Description : 

=cut

sub remove_group_policy_script {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get the arguments
	my $stage_argument = shift;
	my $cmdline_argument = shift;
	if (!$stage_argument || $stage_argument !~ /^(logon|logoff)$/i) {
		notify($ERRORS{'WARNING'}, 0, "stage (logon/logoff) argument was not specified");
		return;
	}	
	if (!$cmdline_argument) {
		notify($ERRORS{'WARNING'}, 0, "CmdLine argument was not specified");
		return;
	}
	
	# Capitalize the first letter of logon/logoff
	$stage_argument = lc($stage_argument);
	$stage_argument = "L" . substr($stage_argument, 1);
	
	# Store the stage name (logon/logoff) not being modified
	my $opposite_stage_argument;
	if ($stage_argument =~ /logon/i) {
		$opposite_stage_argument = 'Logoff';
	}
	else {
		$opposite_stage_argument = 'Logon';
	}

	# Path to scripts.ini file
	my $scripts_ini = '$SYSTEMROOT/system32/GroupPolicy/User/Scripts/scripts.ini';
	
	# Set the owner of scripts.ini to root
	my $chown_command = "touch $scripts_ini && chown root $scripts_ini";
	my ($chown_status, $chown_output) = run_ssh_command($computer_node_name, $management_node_keys, $chown_command);
	if (defined($chown_output) && grep(/no such file/i, @$chown_output)) {
		notify($ERRORS{'DEBUG'}, 0, "scripts.ini file does not exist, nothing to remove");
		return 1;
	}
	elsif (defined($chown_status) && $chown_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "set root as owner of scripts.ini");
	}
	elsif (defined($chown_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set root as owner of scripts.ini, exit status: $chown_status, output:\n@{$chown_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to set root as owner of scripts.ini");
	}
	
	# Set the permissions of scripts.ini to 664
	my $chmod_command = "chmod 664 $scripts_ini";
	my ($chmod_status, $chmod_output) = run_ssh_command($computer_node_name, $management_node_keys, $chmod_command);
	if (defined($chmod_status) && $chmod_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran chmod on scripts.ini");
	}
	elsif (defined($chmod_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run chmod 664 on scripts.ini, exit status: $chmod_status, output:\n@{$chmod_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run chmod 664 on scripts.ini");
	}
	
	# Clear hidden, system, and readonly flags on scripts.ini
	my $attrib_command = "attrib -H -S -R $scripts_ini";
	my ($attrib_status, $attrib_output) = run_ssh_command($computer_node_name, $management_node_keys, $attrib_command);
	if (defined($attrib_status) && $attrib_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran attrib -H -S -R on scripts.ini");
	}
	elsif (defined($attrib_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run attrib -H -S -R on scripts.ini, exit status: $attrib_status, output:\n@{$attrib_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run attrib -H -S -R on scripts.ini");
	}
	
	# Get the contents of scripts.ini
	my $cat_command = "cat $scripts_ini";
	my ($cat_status, $cat_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_command, '', '', 1);
	if (defined($cat_status) && $cat_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved scripts.ini contents:\n" . join("\n", @{$cat_output}));
	}
	elsif (defined($cat_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to cat scripts.ini contents");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to scripts.ini contents");
	}
	
	# Create a string containing all of the lines in scripts.ini
	my $scripts_ini_string = join("\n", @{$cat_output}) || '';
	
	# Remove any carriage returns to make pattern matching easier
	$scripts_ini_string =~ s/\r//gs;
	
	# Get a string containing just the section being modified (logon/logoff)
	my ($section_string) = $scripts_ini_string =~ /(\[$stage_argument\][^\[\]]*)/is;
	$section_string = "[$stage_argument]" if !$section_string;
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $stage_argument section:\n" . string_to_ascii($section_string));
	
	my ($opposite_section_string) = $scripts_ini_string =~ /(\[$opposite_stage_argument\][^\[\]]*)/is;
	$opposite_section_string = "[$opposite_stage_argument]" if !$opposite_section_string;
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $opposite_stage_argument section:\n" . string_to_ascii($opposite_section_string));
	
	my @section_lines = split(/[\r\n]+/, $section_string);
	notify($ERRORS{'DEBUG'}, 0, "scripts.ini $stage_argument section line count: " . scalar @section_lines);
	
	my %scripts_original;
	for my $section_line (@section_lines) {
		if ($section_line =~ /(\d+)Parameters\s*=(.*)/i) {
			my $index = $1;
			my $parameters = $2;
			if (!defined $scripts_original{$index}{Parameters}) {
				$scripts_original{$index}{Parameters} = $parameters;
				#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument parameters:\nline: '$section_line'\nparameters: '$parameters'\nindex: $index");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "found duplicate $stage_argument parameters line for index $index");
			}
		}
		elsif ($section_line =~ /(\d+)CmdLine\s*=(.*)/i) {
			my $index = $1;
			my $cmdline = $2;
			if (!defined $scripts_original{$index}{CmdLine}) {
				$scripts_original{$index}{CmdLine} = $cmdline;
				#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument cmdline:\nline: '$section_line'\ncmdline: '$cmdline'\nindex: $index");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "found duplicate $stage_argument CmdLine line for index $index");
			}
		}
		elsif ($section_line =~ /\[$stage_argument\]/i) {
			#notify($ERRORS{'DEBUG'}, 0, "found $stage_argument heading:\nline: '$section_line'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "found unexpected line: '$section_line'");
		}
	}
	
	my %scripts_modified;
	my $index_modified = 0;
	foreach my $index (sort keys %scripts_original) {
		if (!defined $scripts_original{$index}{CmdLine}) {
			notify($ERRORS{'WARNING'}, 0, "CmdLine not specified for index $index");
			next;
		}
		elsif ($scripts_original{$index}{CmdLine} =~ /^\s*$/) {
			notify($ERRORS{'WARNING'}, 0, "CmdLine blank for index $index");
			next;
		}
		if (!defined $scripts_original{$index}{Parameters}) {
			notify($ERRORS{'WARNING'}, 0, "Parameters not specified for index $index");
			$scripts_original{$index}{Parameters} = '';
		}
		
		if ($scripts_original{$index}{CmdLine} =~ /$cmdline_argument/i) {
			notify($ERRORS{'DEBUG'}, 0, "removing $stage_argument script at index $index:\ncmdline: $scripts_original{$index}{CmdLine}\nparameters: $scripts_original{$index}{Parameters}");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retaining existing $stage_argument script at index $index:\ncmdline: $scripts_original{$index}{CmdLine}\nparameters: $scripts_original{$index}{Parameters}");
			$scripts_modified{$index_modified}{CmdLine} = $scripts_original{$index}{CmdLine};
			$scripts_modified{$index_modified}{Parameters} = $scripts_original{$index}{Parameters};
			$index_modified++;
		}
	}
	
	my $section_string_new = "[$stage_argument]\n";
	foreach my $index_new (sort keys(%scripts_modified)) {
		$section_string_new .= $index_new . "CmdLine=$scripts_modified{$index_new}{CmdLine}\n";
		$section_string_new .= $index_new . "Parameters=$scripts_modified{$index_new}{Parameters}\n";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "original $stage_argument scripts section:\n$section_string");
	notify($ERRORS{'DEBUG'}, 0, "modified $stage_argument scripts section:\n$section_string_new");
	
	my $scripts_ini_modified;
	if ($stage_argument =~ /logon/i) {
		$scripts_ini_modified = "$section_string_new\n$opposite_section_string";
	}
	else {
		$scripts_ini_modified = "$opposite_section_string\n$section_string_new";
	}
	notify($ERRORS{'DEBUG'}, 0, "modified scripts.ini contents:\n$scripts_ini_modified");
	
	$scripts_ini_modified =~ s/"/\\"/gs;
	
	# Echo the modified contents to scripts.ini
	my $echo_command = "echo \"$scripts_ini_modified\" > $scripts_ini";
	my ($echo_status, $echo_output) = run_ssh_command($computer_node_name, $management_node_keys, $echo_command);
	if (defined($echo_status) && $echo_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "echo'd modified contents to scripts.ini");
	}
	elsif (defined($echo_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to echo modified contents to scripts.ini, exit status: $echo_status, output:\n@{$echo_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to echo modified contents to scripts.ini");
		return;
	}
	
	# Run unix2dos on scripts.ini
	$self->run_unix2dos($scripts_ini);
	
	# Get the modified contents of scripts.ini
	my $cat_modified_command = "cat $scripts_ini";
	my ($cat_modified_status, $cat_modified_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_modified_command, '', '', 1);
	if (defined($cat_modified_status) && $cat_modified_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved modified scripts.ini contents");
	}
	elsif (defined($cat_modified_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to cat scripts.ini contents");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to scripts.ini contents");
	}
	
	notify($ERRORS{'OK'}, 0, "removed '$cmdline_argument' $stage_argument script from scripts.ini\noriginal contents:\n$scripts_ini_string\n-----\nnew contents:\n" . join("\n", @{$cat_modified_output}));
	
	## Run gpupdate so the new settings take effect immediately
	#$self->run_gpupdate();
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 run_gpupdate

 Parameters  : 
 Returns     :
 Description : 

=cut

sub run_gpupdate {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Set the owner of scripts.ini to root
	my $gpupdate_command = 'cmd.exe /c $SYSTEMROOT/system32/gpupdate.exe /Force';
	my ($gpupdate_status, $gpupdate_output) = run_ssh_command($computer_node_name, $management_node_keys, $gpupdate_command);
	if (defined($gpupdate_output) && !grep(/error/i, @{$gpupdate_output})) {
		notify($ERRORS{'OK'}, 0, "ran gpupdate /force");
	}
	elsif (defined($gpupdate_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run gpupdate /force, exit status: $gpupdate_status, output:\n@{$gpupdate_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run gpupdate /force");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 run_unix2dos

 Parameters  : 
 Returns     :
 Description : 

=cut

sub run_unix2dos {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get the arguments
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path was not specified as an argument");
		return;
	}

	# Run unix2dos on scripts.ini
	my $unix2dos_command = "unix2dos $file_path";
	my ($unix2dos_status, $unix2dos_output) = run_ssh_command($computer_node_name, $management_node_keys, $unix2dos_command);
	if (defined($unix2dos_status) && $unix2dos_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran unix2dos on $file_path");
	}
	elsif (defined($unix2dos_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run unix2dos on $file_path, exit status: $unix2dos_status, output:\n@{$unix2dos_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run unix2dos on $file_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 search_and_replace_in_files

 Parameters  : 
 Returns     :
 Description : 

=cut

sub search_and_replace_in_files {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get the arguments
	my $base_directory = shift;
	my $search_pattern = shift;
	my $replace_string = shift;
	if (!$base_directory) {
		notify($ERRORS{'WARNING'}, 0, "base directory was not specified as an argument");
		return;
	}
	if (!$search_pattern) {
		notify($ERRORS{'WARNING'}, 0, "search pattern was not specified as an argument");
		return;
	}
	if (!$replace_string) {
		notify($ERRORS{'WARNING'}, 0, "replace string was not specified as an argument");
		return;
	}
	
	# Run grep to find files matching pattern
	my $grep_command = "/bin/grep -ilr \"$search_pattern\" \"$base_directory\"";
	my ($grep_status, $grep_output) = run_ssh_command($computer_node_name, $management_node_keys, $grep_command);
	if (!defined($grep_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run grep on directory: $base_directory, pattern: $search_pattern");
		return;
	}
	elsif ("@$grep_output" =~ /$base_directory: No such file/i) {
		notify($ERRORS{'WARNING'}, 0, "base directory does not exist: $base_directory");
		return;
	}
	elsif ("@$grep_output" =~ /grep:/i) {
		notify($ERRORS{'WARNING'}, 0, "grep output contains 'grep:', unexpected:\n" . join("\n", @$grep_output));
		return;
	}
	elsif ($grep_status == 1) {
		notify($ERRORS{'OK'}, 0, "no files were found matching pattern '$search_pattern' in: $base_directory");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "found files matching pattern '$search_pattern' in $base_directory:\n" . join("\n", @$grep_output));
	}
	
	# Run sed on each matching file to replace string
	my $sed_error_count = 0;
	for my $matching_file (@$grep_output) {
		# Run grep to find files matching pattern
		my $sed_command = "/bin/sed -i -e \"s/$search_pattern/$replace_string/\" \"$matching_file\"";
		my ($sed_status, $sed_output) = run_ssh_command($computer_node_name, $management_node_keys, $sed_command);
		if (!defined($sed_status)) {
			notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run sed on file: $matching_file");
			$sed_error_count++;
		}
		elsif ("@$sed_output" =~ /No such file/i) {
			notify($ERRORS{'WARNING'}, 0, "file was not found: $matching_file, sed output:\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		elsif ("@$sed_output" =~ /sed:/i) {
			notify($ERRORS{'WARNING'}, 0, "sed output contains 'sed:', unexpected output:\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		elsif ($sed_status != 0) {
			notify($ERRORS{'WARNING'}, 0, "sed exit status is $sed_status, output:\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		else {
			notify($ERRORS{'OK'}, 0, "replaced '$search_pattern' with '$replace_string' in $matching_file");
			
			# sed replaces Windows newlines with \n
			$self->run_unix2dos($matching_file);
		}
	}
	
	# Return false if any errors occurred
	if ($sed_error_count) {
		return;
	}
	
	return 1;
	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 copy_capture_configuration_files

 Parameters  : $source_configuration_directory
 Returns     :
 Description : Copies all required configuration files to the computer,
               including scripts, utilities, drivers needed to capture an
				   image.

=cut

sub copy_capture_configuration_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get an array containing the configuration directory paths on the management node
	# This is made up of all the the $SOURCE_CONFIGURATION_DIRECTORY values for the OS class and it's parent classes
	# The first array element is the value from the top-most class the OS object inherits from
	my @source_configuration_directories = $self->get_source_configuration_directories();
	if (!@source_configuration_directories) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve source configuration directories");
		return;
	}
	
	# Delete existing configuration directory if it exists
	if (!$self->delete_capture_configuration_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete existing capture configuration files");
		return;
	}

	# Attempt to create the configuration directory if it doesn't already exist
	if (!$self->create_directory($NODE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "unable to create directory on $computer_node_name: $NODE_CONFIGURATION_DIRECTORY");
		return;
	}

	# Copy configuration files
	for my $source_configuration_directory (@source_configuration_directories) {
		notify($ERRORS{'OK'}, 0, "copying image capture configuration files from $source_configuration_directory to $computer_node_name");
		if (run_scp_command("$source_configuration_directory/*", "$computer_node_name:$NODE_CONFIGURATION_DIRECTORY", $management_node_keys)) {
			notify($ERRORS{'OK'}, 0, "copied $source_configuration_directory directory to $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
	
			notify($ERRORS{'DEBUG'}, 0, "attempting to set permissions on $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
			if (run_ssh_command($computer_node_name, $management_node_keys, "/usr/bin/chmod.exe -R 777 $NODE_CONFIGURATION_DIRECTORY")) {
				notify($ERRORS{'OK'}, 0, "chmoded -R 777 $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "could not chmod -R 777 $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
				return;
			}
		} ## end if (run_scp_command("$source_configuration_directory/*"...
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy $source_configuration_directory to $computer_node_name");
			return;
		}
	}
	
	# Delete any Subversion files which may have been copied
	if (!$self->delete_files_by_pattern($NODE_CONFIGURATION_DIRECTORY, '.*\.svn.*')) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete Subversion files under: $NODE_CONFIGURATION_DIRECTORY");
	}
	
	# Find any files containing a 'WINDOWS_ROOT_PASSWORD' string and replace it with the root password
	if ($self->search_and_replace_in_files($NODE_CONFIGURATION_DIRECTORY, 'WINDOWS_ROOT_PASSWORD', $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'DEBUG'}, 0, "set the Windows root password in configuration files");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the Windows root password in configuration files");
		return;
	}

	return 1;
} ## end sub copy_capture_configuration_files

#/////////////////////////////////////////////////////////////////////////////

=head2 run_sysprep

 Parameters  : None
 Returns     : 1 if successful, 0 otherwise
 Description : -Calls subroutine to prepare the hardware drivers
               -Copies Sysprep files to C:\Sysprep
					-Clears out the setupapi.log file
					-Calls Sysprep.exe with the options to seal and shutdown the computer
					-Waits for computer to become unresponsive
					-Waits 3 additional minutes
					-Calls provisioning module's power_off() subroutine to make sure the computer is powered off

=cut

sub run_sysprep {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Remove old C:\Sysprep directory if it exists
	notify($ERRORS{'DEBUG'}, 0, "attempting to remove old C:/Sysprep directory if it exists");
	if (!$self->delete_file('C:/Sysprep')) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing C:/Sysprep directory");
		return 0;
	}

	# Fix the path, xcopy.exe requires backslashes
	(my $node_configuration_directory = $NODE_CONFIGURATION_DIRECTORY) =~ s/\//\\/g;

	# Copy Sysprep files to C:\Sysprep
	my $xcopy_command = "xcopy.exe /E /C /I /Q /H /K /O /Y \"$node_configuration_directory\\Utilities\\Sysprep\" \"C:\\Sysprep\"";
	my ($xcopy_status, $xcopy_output) = run_ssh_command($computer_node_name, $management_node_keys, $xcopy_command);
	if (defined($xcopy_status) && $xcopy_status == 0) {
		notify($ERRORS{'OK'}, 0, "copied Sysprep files to C:/Sysprep");
	}
	elsif (defined($xcopy_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy Sysprep files to C:/Sysprep, exit status: $xcopy_status, output:\n@{$xcopy_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to copy Sysprep files to C:/Sysprep");
		return 0;
	}
	
	# Copy and scan drivers
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy and scan drivers");
	if (!$self->prepare_drivers()) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy and scan drivers");
		return 0;
	}
	
	# Configure the firewall to allow the sessmgr.exe program
	# Sysprep may hang with a dialog box asking to allow this program
	if (!$self->firewall_enable_sessmgr()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure firewall to allow sessmgr.exe program, Sysprep may hang");
		return 0;
	}

	# Clear out setupapi.log
	my $setupapi_command = "/bin/cat C:/Windows/setupapi.log >> C:/Windows/setupapi_save.log && /bin/cp /dev/null C:/Windows/setupapi.log";
	my ($setupapi_status, $setupapi_output) = run_ssh_command($computer_node_name, $management_node_keys, $setupapi_command);
	if (defined($setupapi_status) && $setupapi_status == 0) {
		notify($ERRORS{'OK'}, 0, "cleared out setupapi.log");
	}
	elsif (defined($setupapi_status)) {
		notify($ERRORS{'OK'}, 0, "failed to clear out setupapi.log, exit status: $setupapi_status, output:\n@{$setupapi_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to clear out setupapi.log");
		return 0;
	}
	
	# Run Sysprep.exe, use cygstart to lauch the .exe and return immediately
	my $sysprep_command = '/bin/cygstart.exe cmd.exe /c "C:/Sysprep/sysprep.exe /forceshutdown /quiet /reseal /mini"';
	my ($sysprep_status, $sysprep_output) = run_ssh_command($computer_node_name, $management_node_keys, $sysprep_command);
	if (defined($sysprep_status) && $sysprep_status == 0) {
		notify($ERRORS{'OK'}, 0, "initiated Sysprep.exe, waiting for $computer_node_name to become unresponsive");
	}
	elsif (defined($sysprep_status)) {
		notify($ERRORS{'OK'}, 0, "failed to initiate Sysprep.exe, exit status: $sysprep_status, output:\n@{$sysprep_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to initiate Sysprep.exe");
		return 0;
	}

	# Wait maximum of 5 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(5)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
		return 0;
	}

	# Wait for 3 minutes then call provisioning module's power_off() subroutine
	# Sysprep does not always shut down the computer when it is done
	notify($ERRORS{'OK'}, 0, "sleeping for 3 minutes to allow Sysprep.exe to finish");
	sleep 180;

	# Call power_off() to make sure computer is shut down
	if (!$self->provisioner->power_off()) {
		# Computer could not be shut off
		notify($ERRORS{'WARNING'}, 0, "unable to power off $computer_node_name");
		return 0;
	}

	return 1;
} ## end sub run_sysprep

#/////////////////////////////////////////////////////////////////////////////

=head2 prepare_drivers

 Parameters  : 
 Returns     :
 Description : 

=cut

sub prepare_drivers {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $imagemeta_sysprep = $self->data->get_imagemeta_sysprep();
	
	my $driver_directory;
	if ($imagemeta_sysprep) {
		$driver_directory = 'C:/Sysprep/Drivers';
	}
	else {
		$driver_directory = 'C:/Drivers';
	}
	

	# Remove old driver directories if they exists
	notify($ERRORS{'DEBUG'}, 0, "attempting to remove old C:/Sysprep\\Drivers directory if it exists");
	if (!$self->delete_file("C:/Sysprep/Drivers")) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing C:/Sysprep/Drivers directory");
	}
	notify($ERRORS{'DEBUG'}, 0, "attempting to remove old C:/Drivers directory if it exists");
	if (!$self->delete_file("C:/Drivers")) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing C:/Drivers directory");
	}
	
	# Copy driver files to C:/Drivers
	my $cp_command = "cp -rf \"$NODE_CONFIGURATION_DIRECTORY/Drivers\" \"$driver_directory\"";
	my ($cp_status, $cp_output) = run_ssh_command($computer_node_name, $management_node_keys, $cp_command);
	if (defined($cp_status) && $cp_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "copied driver files to $driver_directory");
	}
	elsif (defined($cp_status)) {
		notify($ERRORS{'OK'}, 0, "failed to copy driver files to $driver_directory, exit status: $cp_status, output:\n@{$cp_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to drivers files to $driver_directory");
		return 0;
	}

	# Run spdrvscn.exe
	my $spdrvscn_command = "$NODE_CONFIGURATION_DIRECTORY/Utilities/SPDrvScn/spdrvscn.exe /p \"$driver_directory\" /e inf /d \$SYSTEMROOT\\\\inf /a /s /q";
	my ($spdrvscn_status, $spdrvscn_output) = run_ssh_command($computer_node_name, $management_node_keys, $spdrvscn_command);
	if (defined($spdrvscn_status) && $spdrvscn_status == 0) {
		notify($ERRORS{'OK'}, 0, "executed spdrvscn.exe");
	}
	elsif (defined($spdrvscn_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute spdrvscn.exe, exit status: $spdrvscn_status, output:\n@{$spdrvscn_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to execute spdrvscn.exe");
		return 0;
	}
	
	# Query the DevicePath registry value in order to save it in the log for troubleshooting
	my $reg_query_command = '$SYSTEMROOT/System32/reg.exe QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion" /v DevicePath';
	my ($reg_query_status, $reg_query_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_query_command, '', '', 1);
	if (defined($reg_query_status) && $reg_query_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried DevicePath registry key:\n" . join("\n", @{$reg_query_output}));
	}
	elsif (defined($reg_query_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query DevicePath registry key, exit status: $reg_query_status, output:\n@{$reg_query_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to query DevicePath registry key");
		return 0;
	}
	
	# Format the string for the log output
	my ($device_path_string) = grep(/devicepath\s+(reg_.*sz)/i, @{$reg_query_output});
	$device_path_string =~ s/.*(devicepath\s+reg_.*sz)\s*/$1\n/i;
	$device_path_string =~ s/;/\n/g;
	notify($ERRORS{'OK'}, 0, "device path string: $device_path_string");
	
	return 1;
} ## end sub prepare_drivers

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_hard_drive

 Parameters  : 
 Returns     :
 Description : Removed unnecessary files from the hard drive. This is done
               before capturing an image. Examples of unnecessary files:
					-temp files and temp directories
					-cache files
					-downloaded patch files

=cut

sub clean_hard_drive {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Note: attempt to delete everything under C:\RECYCLER before running cleanmgr.exe
	# The Recycle Bin occasionally becomes corrupted
	# cleanmgr.exe will hang with an "OK/Cancel" box on the screen if this happens
	my @patterns_to_delete = (
		'$SYSTEMDRIVE/RECYCLER,.*',
		'$TEMP,.*',
		'$TMP,.*',
		'$SYSTEMDRIVE/cygwin/tmp,.*',
		'$SYSTEMDRIVE/Temp,.*',
		'$SYSTEMROOT/Temp,.*',
		'$SYSTEMROOT/ie7updates,.*',
		'$SYSTEMROOT/ServicePackFiles,.*',
		'$SYSTEMROOT/SoftwareDistribution/Download,.*',
		'$SYSTEMROOT/Minidump,.*',
		'$ALLUSERSPROFILE/Application Data/Microsoft/Dr Watson,.*',
		'$SYSTEMROOT,.*\\.tmp,1',
		'$SYSTEMROOT,.*\\$hf_mig\\$.*,1',
		'$SYSTEMROOT,.*\\$NtUninstall.*,1',
		'$SYSTEMROOT,.*\\$NtServicePackUninstall.*,1',
		'$SYSTEMROOT,.*\\$MSI.*Uninstall.*,1',
		'$SYSTEMROOT/inf,.*INFCACHE\\.1',
		'$SYSTEMROOT/inf,.*[\\\\\\/]oem.*\\..*',
		'$SYSTEMROOT,.*AFSCache,1',
		'$SYSTEMROOT,.*afsd_init\\.log,1',
		'$SYSTEMDRIVE/Documents and Settings,.*\\.log,10',
		'$SYSTEMDRIVE/Documents and Settings,.*Recent\\/.*,10',
		'$SYSTEMDRIVE/Documents and Settings,.*Cookies\\/.*,10',
		'$SYSTEMDRIVE/Documents and Settings,.*Temp\\/.*,10',
		'$SYSTEMDRIVE/Documents and Settings,.*Temporary Internet Files\\/Content.*\\/.*,10',
		'$SYSTEMDRIVE,.*pagefile\\.sys,1',
	);

	# Attempt to stop the AFS service, needed to delete AFS files
	$self->stop_service('TransarcAFSDaemon');

	# Loop through the directories to empty
	# Don't care if they aren't emptied
	for my $base_pattern (@patterns_to_delete) {
		my ($base_directory, $pattern, $max_depth) = split(',', $base_pattern);
		notify($ERRORS{'DEBUG'}, 0, "attempting to delete files under $base_directory matching pattern $pattern");
		$self->delete_files_by_pattern($base_directory, $pattern, $max_depth);
	}

	# Add the cleanmgr.exe settings to the registry
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This registry file contains the entries to turn on all cleanmgr options 
; The state flags below are set to 1, so use the command: 'CLEANMGR /sagerun:1'

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches]

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Active Setup Temp Folders]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Content Indexer Cleaner]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Downloaded Program Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Hibernation File]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Internet Cache Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Memory Dump Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Offline Pages Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Old ChkDsk Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Previous Installations]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Recycle Bin]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Setup Log Files]
"StateFlags0001"=dword:00000000

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\System error memory dump files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\System error minidump files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Temporary Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Temporary Setup Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Temporary Sync Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Thumbnail Cache]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Upgrade Discarded Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Windows Error Reporting Archive Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Windows Error Reporting Queue Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Windows Error Reporting System Archive Files]
"StateFlags0001"=dword:00000002

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\explorer\\VolumeCaches\\Windows Error Reporting System Queue Files]
"StateFlags0001"=dword:00000002

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "set registry settings to configure the disk cleanup utility");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry settings to configure the disk cleanup utility");
	}

	# Run cleanmgr.exe
	my $command = '$SYSTEMROOT/System32/cleanmgr.exe /SAGERUN:01';
	my ($status_cleanmgr, $output_cleanmgr) = run_ssh_command($computer_node_name, $management_node_keys, $command);
	if (defined($status_cleanmgr) && $status_cleanmgr == 0) {
		notify($ERRORS{'OK'}, 0, "ran cleanmgr.exe");
	}
	elsif (defined($status_cleanmgr)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run cleanmgr.exe, exit status: $status_cleanmgr, output:\n@{$output_cleanmgr}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run cleanmgr.exe");
		return 0;
	}

	return 1;
} ## end sub clean_hard_drive

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : 
 Returns     :
 Description : 

=cut

sub start_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}

	my $command = '$SYSTEMROOT/System32/net.exe start "' . $service_name . '"';
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command);
	if (defined($status) && $status == 0) {
		notify($ERRORS{'OK'}, 0, "started service: $service_name");
	}
	elsif (defined($output) && grep(/already been started/i, @{$output})) {
		notify($ERRORS{'OK'}, 0, "service has already been started: $service_name");
	}
	elsif (defined($status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to start service: $service_name, exit status: $status, output:\n@{$output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to to start service: $service_name");
		return 0;
	}

	return 1;
} ## end sub start_service

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : 
 Returns     :
 Description : 

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}

	my $command = '$SYSTEMROOT/System32/net.exe stop "' . $service_name . '"';
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command);
	if (defined($status) && $status == 0) {
		notify($ERRORS{'OK'}, 0, "stopped service: $service_name");
	}
	elsif (defined($output) && grep(/is not started/i, @{$output})) {
		notify($ERRORS{'OK'}, 0, "service is not started: $service_name");
	}
	elsif (defined($output) && grep(/does not exist/i, @{$output})) {
		notify($ERRORS{'WARNING'}, 0, "service was not stopped because it does not exist: $service_name");
		return;
	}
	elsif (defined($status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to stop service: $service_name, exit status: $status, output:\n@{$output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to to stop service: $service_name");
		return 0;
	}

	return 1;
} ## end sub stop_service

#/////////////////////////////////////////////////////////////////////////////

=head2 service_exists

 Parameters  : $service_name
 Returns     : If service exists: 1
               If service does not exist: 0
               If error occurred: undefined
 Description : Runs sc.exe query to determine if a service exists.

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}

	my $command = '$SYSTEMROOT/System32/sc.exe query "' . $service_name . '"';
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
	if (defined($output) && grep(/service does not exist/i, @{$output})) {
		notify($ERRORS{'DEBUG'}, 0, "service does not exist: $service_name");
		return 0;
	}
	elsif (defined($status) && $status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "service exists: $service_name");
	}
	elsif (defined($status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if service exists: $service_name, exit status: $status, output:\n@{$output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to determine if service exists");
		return;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_installed_applications

 Parameters  :
 Returns     :
 Description : Queries the registry for applications that are installed on the computer.
               Subkeys under the following key contain this information:
					HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall
					
					A reference to a hash is returned. The keys of this hash are the names of the subkeys under the Uninstall key.
					Each subkey contains additional data formatted as follows:
					my $installed_applications = $self->os->get_installed_applications();
					$installed_applications->{pdfFactory Pro}{DisplayName} = 'pdfFactory Pro'
               $installed_applications->{pdfFactory Pro}{UninstallString} = 'C:\WINDOWS\System32\spool\DRIVERS\W32X86\3\fppinst2.exe /uninstall'

=cut

sub get_installed_applications {
	my $self = shift;
	if (!ref($self)) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Get an optional regex filter string
	my $regex_filter = shift;
	if ($regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve applications installed on $computer_node_name matching filter: $regex_filter");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve all applications installed on $computer_node_name");
	}

	# Attempt to query the registry for installed applications
	my $reg_query_command = '$SYSTEMROOT/System32/reg.exe QUERY "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s';
	my ($reg_query_exit_status, $reg_query_output) = run_ssh_command($computer_node_name, $management_node_keys, $reg_query_command, '', '', 1);
	if (defined($reg_query_exit_status) && $reg_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried Uninstall registry keys");
	}
	elsif (defined($reg_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query Uninstall registry keys, exit status: $reg_query_exit_status, output:\n@{$reg_query_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to query Uninstall registry keys");
		return;
	}

	# Make sure output was retrieved
	if (!$reg_query_output || scalar @{$reg_query_output} == 0) {
		notify($ERRORS{'WARNING'}, 0, "registry query did not product any output");
		return;
	}

	#notify($ERRORS{'DEBUG'}, 0, "reg.exe query output: " . join("\n", @{$reg_query_output}));

	# Loop through the lines of output
	my $product_key;
	my %installed_products;
	for my $query_output_line (@{$reg_query_output}) {
		#notify($ERRORS{'DEBUG'}, 0, "reg.exe query output line: '" . string_to_ascii($query_output_line) . "'");

		# Remove spaces from beginning and end of line
		$query_output_line =~ s/(^\s+)|(\s+$)//g;

		# Skip lines which don't contain a word character and lines starting with ! like this one:
		#    ! REG.EXE VERSION 3.0
		if ($query_output_line =~ /^!/ || $query_output_line !~ /\w/) {
			next;
		}

		# Check if line starts with HKEY, as in:
		#    HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\ATI Display Driver
		if ($query_output_line =~ /^HKEY.*\\(.*)\s*/) {
			# Skip first line showing the base key that was searched for:
			#    HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall
			next if ($1 eq 'Uninstall');

			$product_key = $1;
			#notify($ERRORS{'DEBUG'}, 0, "found product key: '" . string_to_ascii($product_key) . "'");
			next;
		}

		# Line is a child key of one of the products, take apart the line, looks like this:
		#    <NO NAME>       REG_SZ
		#    DisplayName     REG_SZ  F-Secure SSH Client
		my ($info_key, $info_value) = ($query_output_line =~ /\s*([^\t]+)\s+\w+\s*([^\r\n]*)/);

		# Make sure the regex found the registry key name, if not, regex needs improvement
		if (!$info_key) {
			notify($ERRORS{'WARNING'}, 0, "regex didn't work correctly finding key name and value, line:\n" . string_to_ascii($query_output_line));
			next;
		}

		# Make sure the product key was found by this point, it should have been
		if (!$product_key) {
			notify($ERRORS{'WARNING'}, 0, "product key was not determined by the time the following line was processed, line:\n$query_output_line\nreg.exe query output: @{$reg_query_output}");
			next;
		}

		# Add the key and value to the hash
		$installed_products{$product_key}{$info_key} = $info_value;
	} ## end for my $query_output_line (@{$reg_query_output...

	# If filter was specified, remove keys not matching filter
	if ($regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "finding applications matching filter: $regex_filter");
		my %matching_products;
		foreach my $product_key (sort keys %installed_products) {
			#notify($ERRORS{'DEBUG'}, 0, "checking product key: $product_key");
			if (eval "\$product_key =~ $regex_filter") {
				notify($ERRORS{'DEBUG'}, 0, "found matching product key:\n$product_key");
				$matching_products{$product_key} = $installed_products{$product_key};
				next;
			}

			foreach my $info_key (sort keys %{$installed_products{$product_key}}) {
				my $info_value = $installed_products{$product_key}{$info_key};
				#notify($ERRORS{'DEBUG'}, 0, "checking value of {$info_key}: $info_value");
				if (eval "\$info_value =~ $regex_filter") {
					notify($ERRORS{'DEBUG'}, 0, "found matching value:\n{$product_key}{$info_key} = '$info_value'");
					$matching_products{$product_key} = $installed_products{$product_key};
					last;
				}
				else {
					next;
				}
			} ## end foreach my $info_key (sort keys %{$installed_products...
		} ## end foreach my $product_key (sort keys %installed_products)
		%installed_products = %matching_products;
	} ## end if ($regex_filter)

	if (%installed_products && $regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "found the following installed applications matching filter:\n$regex_filter\n" . format_data(\%installed_products));
		return \%installed_products;
	}
	elsif (%installed_products && !$regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "found the following installed applications:\n" . format_data(\%installed_products));
		return \%installed_products;
	}
	if (!%installed_products && $regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "did not find any installed applications matching filter:\n$regex_filter");
		return 0;
	}
	elsif (!%installed_products && !$regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "did not find any installed applications");
		return 0;
	}
} ## end sub get_installed_applications

#/////////////////////////////////////////////////////////////////////////////

=head2 get_task_list

 Parameters  : None, must be called as an object method ($self->os->get_task_list())
 Returns     : If successful: Reference to an array containing the lines of output generated by tasklist.exe
               If failed: false
 Description : Runs tasklist.exe and returns its output. Tasklist.exe displays a list of applications and associated tasks running on the computer.
               The following switches are used when tasklist.exe is executed:
               /NH - specifies the column header should not be displayed in the output
					/V  - specifies that verbose information should be displayed
					The output is formatted as follows (column header is not included):
					Image Name                   PID Session Name     Session#    Mem Usage Status          User Name                                              CPU Time Window Title                                                            
               System Idle Process            0 Console                 0         16 K Running         NT AUTHORITY\SYSTEM           

=cut

sub get_task_list {
	my $self = shift;
	if (!ref($self)) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to run tasklist.exe with /NH for no header
	my $tasklist_command = '$SYSTEMROOT/System32/tasklist.exe /NH /V';
	my ($tasklist_exit_status, $tasklist_output) = run_ssh_command($computer_node_name, $management_node_keys, $tasklist_command, '', '', 1);
	if (defined($tasklist_exit_status) && $tasklist_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran tasklist.exe");
	}
	elsif (defined($tasklist_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run tasklist.exe, exit status: $tasklist_exit_status, output:\n@{$tasklist_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run tasklist.exe");
		return;
	}

	return $tasklist_output;
} ## end sub get_task_list

#/////////////////////////////////////////////////////////////////////////////

=head2 apply_security_templates

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs secedit.exe to apply the security template files configured
               for the OS. Windows security template files use the .inf
               extension.
               
               Security templates are always copied from the management node
               rather than using a copy stored locally on the computer. This
               allows templates updated centrally to always be applied to the
               computer. Template files residing locally on the computer are not
               processed.
               
               The template files should reside in a directory named "Security"
               under the OS source configuration directory. An example would be:
               
               /usr/local/vcl/tools/Windows_XP/Security/xp_security.inf
               
               This subroutine supports OS module inheritence meaning that if an
               OS module inherits from another OS module, the security templates
               of both will be applied. The order is from the highest parent
               class down to any template files configured specifically for the
               OS module which was instantiated.
               
               This allows any Windows OS module to inherit from another class
               which has security templates defined and override any settings
               from above.
               
               Multiple .inf security template files may be configured for each
               OS. They will be applied in alphabetical order.
               
               Example: Inheritence is configured as follows, with the XP module
               being the instantiated (lowest) class:
               
               VCL::Module
               ^
               VCL::Module::OS
               ^
               VCL::Module::OS::Windows
               ^
               VCL::Module::OS::Windows::Version_5
               ^
               VCL::Module::OS::Windows::Version_5::XP
               
               The XP and Windows classes each have 2 security template files
               configured in their respective Security directories:
               
               /usr/local/vcl/tools/Windows/Security/eventlog_512.inf
               /usr/local/vcl/tools/Windows/Security/windows_security.inf
               /usr/local/vcl/tools/Windows_XP/Security/xp_eventlog_4096.inf
               /usr/local/vcl/tools/Windows_XP/Security/xp_security.inf
               
               The templates will be applied in the order shown above. The
               Windows templates are applied first because it is a parent class
               of XP. For each class being processed, the files are applied in
               alphabetical order.
               
               Assume in the example above that the Windows module's
               eventlog_512.inf file configures the event log to be a maximum of
               512 KB and that it is desirable under Windows XP to configure a
               larger maximum event log size. In order to achieve this,
               xp_eventlog_4096.inf was placed in XP's Security directory which
               contains settings to set the maximum size to 4,096 KB. The
               xp_eventlog_4096.inf file is applied after the eventlog_512.inf
               file, thus overridding the setting configured in the
               eventlog_512.inf file. The resultant maximum event log size will
               be set to 4,096 KB.

=cut

sub apply_security_templates {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module:: module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get an array containing the configuration directory paths on the management node
	# This is made up of all the the $SOURCE_CONFIGURATION_DIRECTORY values for the OS class and it's parent classes
	# The first array element is the value from the top-most class the OS object inherits from
	my @source_configuration_directories = $self->get_source_configuration_directories();
	if (!@source_configuration_directories) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve source configuration directories");
		return;
	}
	
	# Loop through the configuration directories for each OS class on the management node
	# Find any .inf files residing under Security
	my @inf_file_paths;
	for my $source_configuration_directory (@source_configuration_directories) {
		notify($ERRORS{'OK'}, 0, "checking if any security templates exist in: $source_configuration_directory/Security");
		
		# Check each source configuration directory for .inf files under a Security subdirectory
		my $find_command = "find $source_configuration_directory/Security -name \"*.inf\" | sort -f";
		my ($find_exit_status, $find_output) = run_command($find_command);
		if (defined($find_exit_status) && $find_exit_status == 0) {
			notify($ERRORS{'DEBUG'}, 0, "ran find, output:\n" . join("\n", @$find_output));
			push @inf_file_paths, @$find_output;
		}
		elsif (defined($find_output) && grep(/No such file/i, @$find_output)) {
			notify($ERRORS{'DEBUG'}, 0, "path does not exist: $source_configuration_directory/Security, output:\n@{$find_output}");
		}
		elsif (defined($find_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run find, exit status: $find_exit_status, output:\n@{$find_output}");
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run find");
			return;
		}
	}
	
	# Remove any newlines from the file paths in the array
	chomp(@inf_file_paths);
	notify($ERRORS{'DEBUG'}, 0, "security templates will be applied in this order:\n" . join("\n", @inf_file_paths));
	
	# Make sure the Security directory exists before attempting to copy files or SCP will fail
	if (!$self->create_directory("$NODE_CONFIGURATION_DIRECTORY/Security")) {
		notify($ERRORS{'WARNING'}, 0, "unable to create directory: $NODE_CONFIGURATION_DIRECTORY/Security");
	}
	
	# Loop through the .inf files and apply them to the node using secedit.exe
	my $inf_count = 0;
	my $error_occurred = 0;
	for my $inf_file_path (@inf_file_paths) {
		$inf_count++;
		
		# Get the name of the file
		my ($inf_file_name) = $inf_file_path =~ /.*[\\\/](.*)/g;
		my ($inf_file_root) = $inf_file_path =~ /.*[\\\/](.*).inf/gi;
		
		# Construct the target path, prepend a number to indicate the order the files were processed
		my $inf_target_path = "$NODE_CONFIGURATION_DIRECTORY/Security/$inf_count\_$inf_file_name";
		
		# Copy the file to the node and set the permissions to 644
		notify($ERRORS{'DEBUG'}, 0, "attempting to copy file to: $inf_target_path");
		if (run_scp_command($inf_file_path, "$computer_node_name:$inf_target_path", $management_node_keys)) {
			notify($ERRORS{'DEBUG'}, 0, "copied file: $computer_node_name:$inf_target_path");
	
			# Set permission on the copied file
			if (!run_ssh_command($computer_node_name, $management_node_keys, "/usr/bin/chmod.exe -R 644 $inf_target_path", '', '', 1)) {
				notify($ERRORS{'WARNING'}, 0, "could not set permissions on $inf_target_path");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy $inf_file_path to $inf_target_path");
			next;
		}
		
		# Assemble the paths secedit needs
		my $secedit_exe = '$SYSTEMROOT/System32/secedit.exe';
		my $secedit_db = '$SYSTEMROOT/security/Database/' . "$inf_count\_$inf_file_root.sdb";
		my $secedit_log = '$SYSTEMROOT/security/Logs/' . "$inf_count\_$inf_file_root.log";
		
		# The inf path must use backslashes or secedit.exe will fail
		$inf_target_path =~ s/\//\\\\/g;
		
		my $secedit_command = "$secedit_exe /configure /cfg \"$inf_target_path\" /db $secedit_db /log $secedit_log /verbose";
		my ($secedit_exit_status, $secedit_output) = run_ssh_command($computer_node_name, $management_node_keys, $secedit_command, '', '', 0);
		if (defined($secedit_exit_status) && $secedit_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "ran secedit.exe to apply $inf_file_name");
		}
		elsif (defined($secedit_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run secedit.exe to apply $inf_target_path, exit status: $secedit_exit_status, output:\n@{$secedit_output}");
			$error_occurred++;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to run secedit.exe to apply $inf_target_path");
			$error_occurred++;
		}
	}
	
	if ($error_occurred) {
		return 0;
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 kill_process

 Parameters  : String containing task name pattern
 Returns     : If successful: true
               If failed: false
 Description : Runs taskkill.exe to kill processes with names matching a
					pattern. Wildcards can be specified using *, but task name
					patterns cannot begin with a *.
               
               Example pattern: notepad*

=cut

sub kill_process {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Get the task name pattern argument
	my $task_pattern = shift;
	unless ($task_pattern) {
		notify($ERRORS{'WARNING'}, 0, "task name pattern argument was not specified");
		return;	
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Typical output:
	# Task was killed, exit status = 0:
	# SUCCESS: The process with PID 3476 child of PID 5876 has been terminated.
	
	# No tasks match pattern, exit status = 0:
	# INFO: No tasks running with the specified criteria.
	
	# Bad search filter, exit status = 1:
	# ERROR: The search filter cannot be recognized.
	
	# Attempt to kill task
	my $taskkill_command = "\$SYSTEMROOT/system32/taskkill.exe /F /T /FI \"IMAGENAME eq $task_pattern\"";
	my ($taskkill_exit_status, $taskkill_output) = run_ssh_command($computer_node_name, $management_node_keys, $taskkill_command, '', '', '1');
	if (defined($taskkill_exit_status) && $taskkill_exit_status == 0 && (my @killed = grep(/SUCCESS/, @$taskkill_output))) {
		notify($ERRORS{'OK'}, 0, scalar @killed . "processe(s) killed matching pattern: $task_pattern\n" . join("\n", @killed));
	}
	elsif (defined($taskkill_exit_status) && $taskkill_exit_status == 0 && grep(/No tasks running/i, @{$taskkill_output})) {
		notify($ERRORS{'DEBUG'}, 0, "process does not exist matching patterh: $task_pattern");
	}
	elsif (defined($taskkill_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to kill process matching $task_pattern\n" . join("\n", @{$taskkill_output}));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to kill process matching $task_pattern");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_ie_configuration_page

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Sets registry keys which prevent Internet Explorer's
					configuration page from appearing the first time a user launches
					it. This subroutine also enables the Internet Explorer Phishing
					Filter and sets it to not display a balloon message.

=cut

sub disable_ie_configuration_page {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\Main]
"DisableFirstRunCustomize"=dword:00000001
"RunOnceHasShown"=dword:00000001
"RunOnceComplete"=dword:00000001

[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\PhishingFilter]
"Enabled"=dword:00000002
"ShownVerifyBalloon"=dword:00000001

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to disable IE runonce");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable IE runonce");
		return 0;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_node_configuration_directory

 Parameters  : None.
 Returns     : String containing filesystem path
 Description : Retrieves the $NODE_CONFIGURATION_DIRECTORY variable value the
               OS. This is the path on the computer's hard drive where image
					configuration files and scripts are copied.

=cut

sub get_node_configuration_directory {
	return $NODE_CONFIGURATION_DIRECTORY;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_computer_name

 Parameters  : $computer_name (optional)
 Returns     : If successful: true
               If failed: false
 Description : Sets the registry keys to set the computer name. This subroutine
               does not attempt to reboot the computer.
               The computer name argument is optional. If not supplied, the
               computer's short name stored in the database will be used,
               followed by a hyphen and the image ID that is loaded.

=cut

sub set_computer_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name
	my $computer_name = shift;
	if (!$computer_name) {
		$computer_name = $self->data->get_computer_short_name();
		if (!$computer_name) {
			notify($ERRORS{'WARNING'}, 0, "computer name argument was not supplied and could not be retrieved from the reservation data");
			return;
		}
		
		# Append the image ID to the computer name
		my $image_id = $self->data->get_image_id();
		$computer_name .= "-$image_id" if $image_id;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\ComputerName\\ComputerName]
"ComputerName"="$computer_name"

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"NV Hostname"="$computer_name"
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set registry keys to change the computer name to $computer_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry keys to change the computer name to $computer_name");
		return;
	}

	return 1;
} ## end sub disable_ipv6

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_security_center_notifications

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Security Center notifications which are
               displayed in the notification area (system tray).

=cut

sub disable_security_center_notifications {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center]
"AntiSpywareDisableNotify"=dword:00000001
"AntiVirusDisableNotify"=dword:00000001
"FirewallDisableNotify"=dword:00000001
"UacDisableNotify"=dword:00000001
"UpdatesDisableNotify"=dword:00000001
"FirstRunDisabled"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center\Svc]
"AntiVirusOverride"=dword:00000001
"AntiSpywareOverride"=dword:00000001
"FirewallOverride"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to disable security center notifications");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable security center notifications");
		return 0;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_automatic_updates

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Automatic Updates by configuring a local group
               policy:
               HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate=1
               
               This must be done using a policy in order to prevent
               Windows Security Center will display a warning icon in the
               notification area. Windows Update can be disabled via the GUI
               which configures the following key but a warning will be
               presented to the user:
               HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update

=cut

sub disable_automatic_updates {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
"NoAutoUpdate"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled automatic updates");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable automatic updates");
		return 0;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_windows_defender

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Defender by doing the following:
               -Configures local group policy to disable Windows Defender
               -Removes HKLM...Run registry key to start Windows Defender at logon
               -Stops the Windows Defender service
               -Disables the Windows Defender service

=cut

sub disable_windows_defender {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender]
"DisableAntiSpyware"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run]
"Windows Defender"=-
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "set the registry keys to disable Windows defender");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable Windows defender");
		return 0;
	}
	
	# Check if WinDefend service exists
	if ($self->service_exists('WinDefend')) {	
		# Stop the Windows Defender service
		if ($self->stop_service('WinDefend')) {
			notify($ERRORS{'DEBUG'}, 0, "stopped the Windows Defender service");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to stop the Windows Defender service");
			return 0;
		}
		
		# Disable the Windows Defender service
		if ($self->set_service_startup_mode('WinDefend', 'disabled')) {
			notify($ERRORS{'DEBUG'}, 0, "disabled the Windows Defender service");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to disable the Windows Defender service");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "disabled Windows Defender");

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 AUTHOR

 Aaron Peeler <aaron_peeler@ncsu.edu>
 Andy Kurth <andy_kurth@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
