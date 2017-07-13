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

VCL::Module::OS.pm - VCL base operating system module

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support operating systems.

=cut

###############################################################################
package VCL::Module::OS;

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
use English '-no_match_vars';
use File::Temp qw(tempdir);
use POSIX qw(tmpnam);
use Net::SSH::Expect;
use List::Util qw(min max);

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : $arguments->{end_state}
 Returns     : boolean
 Description : Performs the tasks common to all OS's that must be done to the
               computer prior to capturing an image:
               * Check if the computer is responding to SSH
               * If not responding, check if computer is powered on
               * Power on computer if powered off and wait for SSH to respond
               * Create currentimage.txt file

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	notify($ERRORS{'OK'}, 0, "beginning common image capture preparation tasks");
	
	# Make sure the computer is responding to SSH
	# If it is not, check if it is powered on
	if (!$self->is_ssh_responding()) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name is not responding to SSH, checking if it is powered on");
		my $power_status = $self->provisioner->power_status();
		if (!$power_status) {
			notify($ERRORS{'WARNING'}, 0, "unable to complete capture preparation tasks, $computer_node_name is not responding to SSH and the power status could not be determined");
			return;
		}
		elsif ($power_status =~ /on/i) {
			notify($ERRORS{'WARNING'}, 0, "unable to complete capture preparation tasks, $computer_node_name is powered on but not responding to SSH");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is powered off, attempting to power it on");
			if (!$self->provisioner->power_on()) {
				notify($ERRORS{'WARNING'}, 0, "unable to complete capture preparation tasks, $computer_node_name could not be powered on");
				return;
			}
			
			# Wait for computer to respond to SSH
			if (!$self->wait_for_response(30, 300, 10)) {
				notify($ERRORS{'WARNING'}, 0, "unable to complete capture preparation tasks, $computer_node_name never responded to SSH after it was powered on");
				return;
			}
		}
	}
	
	# Delete an existing node configuration directory to clear out any scripts and log files from a previous image revision
	my $node_configuration_directory = $self->get_node_configuration_directory();
	if ($node_configuration_directory) {
		$self->delete_file($node_configuration_directory);
	}
	
	# Create the currentimage.txt file
	if (!$self->create_currentimage_txt()) {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt on $computer_node_name");
		return 0;
	}
	
	# Run custom pre_capture scripts
	$self->run_stage_scripts('pre_capture');
	
	# Delete reservation_info.json
	my $reservation_info_json_file_path = $self->get_reservation_info_json_file_path();
	if ($reservation_info_json_file_path) {
		$self->delete_file($reservation_info_json_file_path);
	}
	
	notify($ERRORS{'OK'}, 0, "completed common image capture preparation tasks");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_capture

 Parameters  : none
 Returns     : boolean
 Description : Performs the tasks common to all OS's that must be done to the
               computer after capturing an image:
               * Runs post_capture stage scripts on the management node if any
                 exist

=cut

sub post_capture {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Run custom post_capture scripts
	$self->run_stage_scripts('post_capture');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps after an image is loaded.

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Run custom post_load scripts
	$self->run_stage_scripts('post_load');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps to reserve the computer for a user:
               * The public IP address is updated if necessary
					* If the computer is mapped to a NAT host:
					** General NAT host configuration is performed if not previously
					   done.
					** The NAT host is prepared for the reservation but specific port
					   forwardings are not added.
					* User accounts are added
					
					Note: The 'reserve' subroutine should never open the firewall for
					a connection. This is done by the 'grant_access' subroutine.

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $nathost_hostname = $self->data->get_nathost_hostname(0);
	
	# Make sure the public IP address assigned to the computer matches the database
	if (!$self->update_public_ip_address()) {
		notify($ERRORS{'WARNING'}, 0, "unable to reserve computer, failed to update IP address");
		return;
	}
	
	
	# Check if the computer is mapped to a NAT host
	if ($nathost_hostname) {
		# Perform general NAT host configuration - this only needs to be done once, nat_configure_host checks if it was already done 
		if (!$self->nathost_os->firewall->nat_configure_host()) {
			notify($ERRORS{'WARNING'}, 0, "unable to reserve $computer_node_name, failed to configure NAT on $nathost_hostname");
			return;
		}
		
		# Perform reservation-specific NAT configuration
		if (!$self->nathost_os->firewall->nat_configure_reservation()) {
			notify($ERRORS{'WARNING'}, 0, "unable to reserve $computer_node_name, failed to configure NAT on $nathost_hostname for this reservation");
			return;
		}
	}
	
	
	# Add user accounts to the computer
	if (!$self->add_user_accounts()) {
		notify($ERRORS{'WARNING'}, 0, "unable to reserve computer, failed add user accounts");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps after an image is loaded.

=cut

sub post_reserve {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Run custom post_reserve scripts
	$self->run_stage_scripts('post_reserve');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_initial_connection

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps after a user makes an initial
               connection.

=cut

sub post_initial_connection {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Run custom post_initial_connection scripts
	$self->run_stage_scripts('post_initial_connection');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_reservation

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps after a user's reservation is over.

=cut

sub post_reservation {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Run custom post_reservation scripts
	$self->run_stage_scripts('post_reservation');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_reload

 Parameters  : none
 Returns     : boolean
 Description : Performs common OS steps prior to a computer being reloaded.

=cut

sub pre_reload {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Run custom pre_reload scripts
	$self->run_stage_scripts('pre_reload');
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_user_accounts

 Parameters  : none
 Returns     : boolean
 Description : Adds all user accounts to the computer for a reservation. The
               reservationaccounts table is checked. If the user already exists
               in the table, it is assumed the user was previously created and
               nothing is done. If the user doesn't exist in the table it is
               added. If an entry for a user exists in the reservationaccounts
               table but the user is not assigned to the reservation, the user
               is deleted from the computer.

=cut

sub add_user_accounts {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_user_id  = $self->data->get_user_id();
	my $request_state_name  = $self->data->get_request_state_name();
	my $reservation_id = $self->data->get_reservation_id();
	my $reservation_users = $self->data->get_reservation_users();
	my $reservation_password = $self->data->get_reservation_password(0);
	my $computer_node_name = $self->data->get_computer_node_name();

	# Collect users in reservationaccounts table
	my $reservation_accounts = get_reservation_accounts($reservation_id);
	
	# Add users
	RESERVATION_USER: foreach my $user_id (sort keys %$reservation_users) {
		my $username        = $reservation_users->{$user_id}{unityid};
		my $uid             = $reservation_users->{$user_id}{uid};
		my $root_access     = $reservation_users->{$user_id}{ROOTACCESS};
		my $use_public_keys = $reservation_users->{$user_id}{usepublickeys};
		
		# If the $use_public_keys flag is set, retrieve the keys
		my $ssh_public_keys;
		if ($use_public_keys) {
			$ssh_public_keys = $reservation_users->{$user_id}{sshpublickeys};
		}
		
		my $password;
		
		# Check if entry needs to be added to the useraccounts table
		if (defined($reservation_accounts->{$user_id}) && ($request_state_name =~ /servermodified/)) {
			# Entry already exists in useraccounts table and is servermodified, assume everything is correct skip to next user
			notify($ERRORS{'DEBUG'}, 0, "entry already exists in useraccounts table for $username (ID: $user_id) and request_state_name = $request_state_name");
			
			# Make sure user's root access is correct - may have been moved from admin to access group, and vice versa
			if ($root_access) {
				$self->grant_administrative_access($username) if ($self->can('grant_administrative_access'));
			}
			else {
				$self->revoke_administrative_access($username) if ($self->can('revoke_administrative_access'));
			}
			
			next RESERVATION_USER;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "entry does not already exist in useraccounts table for $username (ID: $user_id)");
			
			# Determine whether or not the user account's password should be set
			my $should_set_user_password = 1;
			if ($self->can('should_set_user_password')) {
				$should_set_user_password = $self->should_set_user_password($user_id);
				if (!defined($should_set_user_password)) {
					notify($ERRORS{'CRITICAL'}, 0, "failed to determine if user account password should be set, user ID $user_id, assuming password should be set");
					$should_set_user_password = 1;
				}
			}
			
			if ($should_set_user_password) {
				# Check if this is the request owner user ID and the reservation password has already been set
				if ($user_id eq $request_user_id) {
					if ($reservation_password) {
						$password = $reservation_password;
						notify($ERRORS{'DEBUG'}, 0, "user $username (ID: $user_id) is request owner, using existing reservation password: $password");
					}
					else {
						# Generate a new random password
						$password = getpw();
						$self->data->set_reservation_password($password);
						notify($ERRORS{'DEBUG'}, 0, "user $username (ID: $user_id) is request owner, generated new password: $password");
						
						# Update the password in the reservation table
						if (!update_reservation_password($reservation_id, $password)) {
							$self->reservation_failed("failed to update password in the reservation table");
							return;
						}
					}
				}
				else {
					# Generate a new random password
					$password = getpw();
					notify($ERRORS{'DEBUG'}, 0, "user $username (ID: $user_id) is not the request owner, generated new password: $password");
				}
			}
			
			# Add an entry to the useraccounts table
			if (!add_reservation_account($reservation_id, $user_id, $password)) {
				notify($ERRORS{'CRITICAL'}, 0, "failed to add entry to reservationaccounts table for $username (ID: $user_id)");
				return;
			}

			# Create user on the OS
			if (!$self->create_user({
					username => $username,
					password => $password,
					root_access => $root_access,
					uid => $uid,
					ssh_public_keys => $ssh_public_keys,
			})) {
				notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, removing entry added to reservationaccounts table");
				
				# Delete entry to the useraccounts table
				if (!delete_reservation_account($reservation_id, $user_id)) {
					notify($ERRORS{'CRITICAL'}, 0, "failed to delete entry from reservationaccounts table for $username (ID: $user_id)");
				}
				
				return;
			}
		}
	}
	
	# Remove anyone listed in reservationaccounts that is not a reservation user
	foreach my $user_id (sort keys %$reservation_accounts) {
		if (defined($reservation_users->{$user_id})) {
			next;
		}
		
		my $username = $reservation_accounts->{$user_id}{username};
		
		notify($ERRORS{'OK'}, 0, "user $username (ID: $user_id) exists in reservationsaccounts table but is not assigned to this reservation, attempting to delete user");
		
		# Delete the user from OS
		if (!$self->delete_user($username)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete user $username (ID: $user_id) from $computer_node_name");
			next;
		}
		
		# Delete entry from reservationaccounts
		if (!delete_reservation_account($reservation_id, $user_id)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to delete entry from reservationaccounts table for user $username (ID: $user_id)");
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_user_accounts

 Parameters  : none
 Returns     : boolean
 Description : Deletes all user accounts from the computer which are assigned to
               the reservation or an entry exists in the reservationaccounts
               table.

=cut

sub delete_user_accounts {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my %username_hash;
	
	my $reservation_users = $self->data->get_reservation_users();
	foreach my $user_id (sort keys %$reservation_users) {
		my $username = $reservation_users->{$user_id}{unityid};
		$username_hash{$username} = $user_id;
	}

	# Collect users in reservationaccounts table
	my $reservation_accounts = get_reservation_accounts($reservation_id);
	foreach my $user_id (sort keys %$reservation_accounts) {
		my $username = $reservation_accounts->{$user_id}{username};
		$username_hash{$username} = $user_id;
	}
	
	my $error_encountered = 0;
	
	# Delete users
	foreach my $username (sort keys %username_hash) {
		my $user_id = $username_hash{$username};
		
		# Delete user on the OS
		if (!$self->delete_user($username)) {
			$error_encountered = 1;
			notify($ERRORS{'WARNING'}, 0, "failed to delete user on $computer_node_name");
		}
		
		# Delete entry to the useraccounts table
		delete_reservation_account($reservation_id, $user_id);
	}
	
	return !$error_encountered;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_source_configuration_directories

 Parameters  : None
 Returns     : Array containing filesystem path strings
 Description : Retrieves the $SOURCE_CONFIGURATION_DIRECTORY variable value for
               the classes which the OS object is a member of and returns an
               array containing these values.
               
               The first element of the array contains the value from the
               top-most class where the $SOURCE_CONFIGURATION_DIRECTORY variable
               was defined. The last element contains the value from the
               bottom-most class, which is probably the class which was
               instantiated.
               
               Example: An Windows XP OS object is instantiated from the XP
               class, which is a subclass of the Version_5 class, which is a
               subclass of the Windows class:
               
               VCL::Module::OS::Windows
               ^
               VCL::Module::OS::Windows::Version_5
               ^
               VCL::Module::OS::Windows::Version_5::XP
               
               The XP and Windows classes each
               have a $SOURCE_CONFIGURATION_DIRECTORY variable defined but the
               Version_5 class does not. The array returned will be:
               
               [0] = '/usr/local/vcldev/current/bin/../tools/Windows'
               [1] = '/usr/local/vcldev/current/bin/../tools/Windows_XP'

=cut

sub get_source_configuration_directories {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL module object method");
		return;	
	}
	
	# Get an array containing the names of the Perl packages the OS object is a class of
	my @package_hierarchy = $self->get_package_hierarchy();
	
	# Loop through each classes, retrieve any which have a $SOURCE_CONFIGURATION_DIRECTORY variable defined
	my @directories = ();
	for my $package_name (@package_hierarchy) {
		my $source_configuration_directory = eval '$' . $package_name . '::SOURCE_CONFIGURATION_DIRECTORY';
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine source configuration directory for $package_name, error:\n$EVAL_ERROR");
			next;	
		}
		elsif (!$source_configuration_directory) {
			notify($ERRORS{'DEBUG'}, 0, "source configuration directory is not defined for $package_name");
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "package source configuration directory: $source_configuration_directory");
		
		# Add the directory path to the return array
		# Use unshift to add to the beginning to the array
		unshift @directories, $source_configuration_directory; 
	}
	
	return @directories;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_currentimage_txt

 Parameters  : None
 Returns     : boolean
 Description : Creates the currentimage.txt file on the computer.

=cut

sub create_currentimage_txt {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_id                   = $self->data->get_image_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_prettyname           = $self->data->get_image_prettyname();
	my $imagerevision_id           = $self->data->get_imagerevision_id();
	my $imagerevision_date_created = $self->data->get_imagerevision_date_created();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_host_name         = $self->data->get_computer_host_name();
	
	my $file_contents = <<EOF;
$image_name
id=$image_id
prettyname=$image_prettyname
imagerevision_id=$imagerevision_id
imagerevision_datecreated=$imagerevision_date_created
computer_id=$computer_id
computer_hostname=$computer_host_name
EOF
	
	# Create the file
	if ($self->create_text_file('~/currentimage.txt', $file_contents)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt file on $computer_host_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_currentimage_txt_contents

 Parameters  : None
 Returns     : If successful: array
               If failed: false
 Description : Reads the currentimage.txt file on a computer and returns its
               contents as an array. Each array element represents a line in
               the file.

=cut

sub get_currentimage_txt_contents {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Attempt to retrieve the contents of currentimage.txt
	my $cat_command = "cat ~/currentimage.txt";
	my ($cat_exit_status, $cat_output) = $self->execute($cat_command,1);
	if (!defined($cat_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to failed to retrieve currentimage.txt from $computer_node_name");
		return;
	}
	elsif ($cat_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve currentimage.txt from $computer_node_name, exit status: $cat_exit_status, output:\n@{$cat_output}");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved currentimage.txt contents from $computer_node_name:\n" . join("\n", @$cat_output));
	}

	my %output;
	my @current_image_txt_contents = @{$cat_output};

	my $current_image_name; 
	if (defined $current_image_txt_contents[0]) {
		$output{"current_image_name"} = $current_image_txt_contents[0];
	}
	
	foreach my $l (@current_image_txt_contents) {
		#remove any line break characters
		$l =~ s/[\r\n]*//g;
		my ($a, $b) = split(/=/, $l);
		if (defined $b) {
			$output{$a} = $b; 
		}   
	}
	
	return %output;
} ## end sub get_currentimage_txt_contents

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_imagerevision_id

 Parameters  : none
 Returns     : integer
 Description : Retrieves the imagerevision ID value from currentimage.txt.

=cut

sub get_current_imagerevision_id {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_current_image_tag('imagerevision_id');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_reboot

 Parameters  : $total_wait_seconds, $attempt_delay_seconds, $attempt_limit
 Returns     : boolean
 Description : Waits for the computer to become unresponsive, respond to ping,
               then respond to SSH.

=cut

sub wait_for_reboot {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of seconds to wait from the arguments
	my $total_wait_seconds_argument = shift;
	if (!defined($total_wait_seconds_argument) || $total_wait_seconds_argument !~ /^\d+$/) {
		$total_wait_seconds_argument = 300;
	}
	
	# Seconds to wait in between loop attempts
	my $attempt_delay_seconds_argument = shift;
	if (!defined($attempt_delay_seconds_argument) || $attempt_delay_seconds_argument !~ /^\d+$/) {
		$attempt_delay_seconds_argument = 15;
	}
	
	# Number of power reset attempts to make if reboot fails
	my $attempt_limit = shift;
	if (!defined($attempt_limit) || $attempt_limit !~ /^\d+$/) {
		$attempt_limit = 2;
	}
	elsif (!$attempt_limit) {
		$attempt_limit = 1;
	}
	
	ATTEMPT:
	for (my $attempt = 1; $attempt <= $attempt_limit; $attempt++) {
		my $total_wait_seconds = $total_wait_seconds_argument;
		my $attempt_delay_seconds = $attempt_delay_seconds_argument;
		
		if ($attempt > 1) {
			# Computer did not become responsive on previous attempt
			notify($ERRORS{'OK'}, 0, "$computer_node_name reboot failed to complete on previous attempt, attempting hard power reset");
			
			# Call provisioning module's power_reset() subroutine
			if ($self->provisioner->power_reset()) {
				notify($ERRORS{'OK'}, 0, "reboot attempt $attempt/$attempt_limit: initiated power reset on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
				return 0;
			}
			
			# Add 2 minutes for each attempt to $total_wait_seconds in case argument supplied wasn't long enough
			$total_wait_seconds += (120 * $attempt);
		}
		
		my $start_time = time;
		
		notify($ERRORS{'DEBUG'}, 0, "waiting for $computer_node_name to reboot:
				attempt: $attempt/$attempt_limit
				maximum wait time: $total_wait_seconds seconds
				wait delay: $attempt_delay_seconds");
		
		# Wait for the computer to become unresponsive to ping
		if (!$self->wait_for_no_ping($total_wait_seconds, 5)) {
			# Computer never stopped responding to ping
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
			next ATTEMPT;
		}
		
		# Decrease $total_wait_seconds by the amount of time elapsed so far
		my $no_ping_elapsed_seconds = (time - $start_time);
		$total_wait_seconds -= $no_ping_elapsed_seconds;
		
		# Computer is unresponsive, reboot has begun
		# Wait 5 seconds before beginning to check if computer is back online
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name reboot has begun, sleeping for 5 seconds");
		sleep 5;
		
		# Wait for the computer to respond to ping
		if (!$self->wait_for_ping($total_wait_seconds, $attempt_delay_seconds)) {
			# Check if the computer was ever offline, it should have been or else reboot never happened
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping");
			next ATTEMPT;
		}
		
		# Decrease $total_wait_seconds by the amount of time elapsed so far
		my $ping_elapsed_seconds = (time - $start_time);
		my $ping_actual_seconds = ($ping_elapsed_seconds - $no_ping_elapsed_seconds);
		$total_wait_seconds -= $ping_elapsed_seconds;
		
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is pingable, waiting for SSH to respond");
		
		# Wait maximum of 3 minutes for ssh to respond
		if (!$self->wait_for_ssh($total_wait_seconds, $attempt_delay_seconds)) {
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
			next ATTEMPT;
		}
		
		# Decrease $total_wait_seconds by the amount of time elapsed so far
		my $ssh_elapsed_seconds = (time - $start_time);
		my $ssh_actual_seconds = ($ssh_elapsed_seconds - $ping_elapsed_seconds);
		
		notify($ERRORS{'OK'}, 0, "$computer_node_name responded to SSH:
			unresponsive: $no_ping_elapsed_seconds seconds
			respond to ping: $ping_elapsed_seconds seconds ($ping_actual_seconds seconds after unresponsive)
			respond to SSH $ssh_elapsed_seconds seconds ($ssh_actual_seconds seconds after ping)"
		);
		return 1;
	}
	
	# If loop completed, maximum number of reboot attempts was reached
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name reboot failed");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ping

 Parameters  : Maximum number of seconds to wait (optional), delay between attempts (optional)
 Returns     : If computer is pingable before the maximum amount of time has elapsed: 1
               If computer never responds to ping before the maximum amount of time has elapsed: 0
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
               of seconds. This can be specified by passing the subroutine an
               integer value or the default value of 300 seconds will be used. The
               delay between attempts can be specified as the 2nd argument in
               seconds. The default value is 15 seconds.

=cut

sub wait_for_ping {
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $message = "waiting for $computer_node_name to respond to ping";
	
	# Call code_loop_timeout, specifify that it should call _pingnode with the computer name as the argument
	return $self->code_loop_timeout(\&_pingnode, [$computer_node_name], $message, $total_wait_seconds, $attempt_delay_seconds);
} ## end sub wait_for_ping

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_no_ping

 Parameters  : Maximum number of seconds to wait (optional), seconds to delay between attempts (optional)
 Returns     : 1 if computer is not pingable, 0 otherwise
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
               of seconds for ping to fail. The delay between attempts can be
               specified as the 2nd argument in seconds. The default value is 15
               seconds.

=cut

sub wait_for_no_ping {
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $message = "waiting for $computer_node_name to NOT respond to ping";
	
	# Call code_loop_timeout and invert the result, specifify that it should call _pingnode with the computer name as the argument
	return $self->code_loop_timeout(sub{return !_pingnode(@_)}, [$computer_node_name], $message, $total_wait_seconds, $attempt_delay_seconds);
} ## end sub wait_for_no_ping

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ssh

 Parameters  : Seconds to wait (optional), seconds to delay between attempts (optional)
 Returns     : 
 Description : Attempts to communicate to the reservation computer via SSH.
               SSH attempts are made until the maximum number of seconds has
               elapsed. The maximum number of seconds can be specified as the
               first argument. If an argument isn't supplied, a default value of
               300 seconds will be used.
               
               A delay occurs between attempts. This can be specified by passing
               a 2nd argument. If a 2nd argument isn't supplied, a default value
               of 15 seconds will be used.

=cut

sub wait_for_ssh {
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Call the "can" function, it returns a code reference to the subroutine specified
	# This is passed to code_loop_timeout which will then execute the code until it returns true
	my $sub_ref = $self->can("is_ssh_responding");
	
	my $message = "waiting for $computer_node_name to respond to SSH";

	return $self->code_loop_timeout($sub_ref, [$self], $message, $total_wait_seconds, $attempt_delay_seconds);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_ssh_responding

 Parameters  : $computer_name (optional), $max_attempts (optional)
 Returns     : boolean
 Description : Checks if the computer is responding to SSH. The SSH port is
					first checked. If not open, 0 is returned. If the port is open a
					test SSH command which simply echo's a string is attempted. The
					default is to only attempt to run this command once. This can be
					changed by supplying the $max_attempts argument. If the
					$max_attempts is supplied but set to 0, only the port checks are
					done.

=cut

sub is_ssh_responding {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name;
	my $max_attempts = 1;

	my $argument_1 = shift;
	my $argument_2 = shift;
	if ($argument_1) {
		# Check if the argument is an integer
		if ($argument_1 =~ /^\d+$/) {
			$max_attempts = $argument_1;
		}
		else {
			$computer_node_name = $argument_1;
			if ($argument_2 && $argument_2 =~ /^\d+$/) {
				$max_attempts = $argument_2;
			}
		}
	}
	
	if (!$computer_node_name) {
		$computer_node_name = $self->data->get_computer_node_name();
	}
	
	# If 'ssh_port' key is set in this object use it
	my $port =  $self->{ssh_port} || 22;
	
	# Try nmap to see if any of the ssh ports are open before attempting to run a test command
	my $nmap_status = nmap_port($computer_node_name, $port) ? "open" : "closed";
	if ($nmap_status ne 'open') {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, port $port is closed");
		return 0;
	}
	
	if ($max_attempts) {
		# Run a test SSH command
		#my ($exit_status, $output) = $self->execute({
		#	node => $computer_node_name,
		#	command => "echo \"testing ssh on $computer_node_name\"",
		#	max_attempts => $max_attempts,
		#	display_output => 0,
		#	timeout_seconds => 30,
		#	ignore_error => 1,
		#});
		
		my ($exit_status, $output) = $self->execute({
			node => $computer_node_name,
			command => "echo \"testing ssh on $computer_node_name\"",
			max_attempts => $max_attempts,
			display_output => 0,
			timeout_seconds => 15,
		});
		
		# The exit status will be 0 if the command succeeded
		if (defined($output) && grep(/testing/, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is responding to SSH, port $port: $nmap_status");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, SSH command failed, port $port: $nmap_status");
			return 0;
		}
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_response

 Parameters  : Initial delay seconds (optional), SSH response timeout seconds (optional), SSH attempt delay seconds (optional)
 Returns     : If successful: true
               If failed: false
 Description : Waits for the reservation computer to respond to SSH after it
               has been loaded.

=cut

sub wait_for_response {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $start_time = time();
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_id = $self->data->get_computer_id();
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $initial_delay_seconds = shift;
	if (!defined $initial_delay_seconds) {
		$initial_delay_seconds = 120;
	}
	
	my $ssh_response_timeout_seconds = shift;
	if (!defined $ssh_response_timeout_seconds) {
		$ssh_response_timeout_seconds = 600;
	}
	
	my $ssh_attempt_delay_seconds = shift;
	if (!defined $ssh_attempt_delay_seconds) {
		$ssh_attempt_delay_seconds = 15;
	}
	
	# Sleep for the initial delay value if it has been set
	# Check SSH once to bypass the initial delay if SSH is already responding
	if ($initial_delay_seconds && !$self->is_ssh_responding()) {
		notify($ERRORS{'OK'}, 0, "waiting $initial_delay_seconds seconds for $computer_node_name to boot");
		sleep $initial_delay_seconds;
		notify($ERRORS{'OK'}, 0, "waited $initial_delay_seconds seconds for $computer_node_name to boot");
	}
	
	# Wait for SSH to respond, loop until timeout is reached
	if (!$self->wait_for_ssh($ssh_response_timeout_seconds, $ssh_attempt_delay_seconds)) {
		notify($ERRORS{'WARNING'}, 0, "failed to connect to $computer_node_name via SSH after $ssh_response_timeout_seconds seconds");
		return;
	}
	
	my $end_time = time();
	my $duration = ($end_time - $start_time);
	
	insertloadlog($reservation_id, $computer_id, "machinebooted", "$computer_node_name is responding to SSH after $duration seconds");
	notify($ERRORS{'OK'}, 0, "$computer_node_name is responding to SSH after $duration seconds");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_port_open

 Parameters  : $port_number, $connection_target (optional), $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Uses nmap to check if the port specified is open. Loops until the
               port is open or $total_wait_seconds is reached.

=cut

sub wait_for_port_open {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $calling_subroutine = get_calling_subroutine();
	
	my $port_number = shift;
	if (!defined($port_number)) {
		notify($ERRORS{'WARNING'}, 0, "port number argument was not supplied");
		return;
	}
	
	my $connection_target = shift || $computer_node_name;
	my $total_wait_seconds = shift || 60;
	my $attempt_delay_seconds = shift || 5;
	
	my $mode = ($calling_subroutine =~ /wait_for_port_closed/ ? 'closed' : 'open');
	
	my $message = "waiting for port $port_number to be $mode on $connection_target";
	$message .= " ($computer_node_name)" if ($connection_target ne $computer_node_name);
	
	# Essentially perform xnor on nmap_port result and $mode eq open
	# Both either need to be true or false
	# $mode eq open:true, nmap_port:true, result:true
	# $mode eq open:false, nmap_port:true, result:false
	# $mode eq open:true, nmap_port:false, result:false
	# $mode eq open:false, nmap_port:false, result:true
	my $sub_ref = sub{
		my $nmap_result = nmap_port(@_) || 0;
		return $mode =~ /open/ == $nmap_result;
	};
	return $self->code_loop_timeout($sub_ref, [$connection_target, $port_number], $message, $total_wait_seconds, $attempt_delay_seconds);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_port_closed

 Parameters  : $port_number, $connection_target (optional), $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Uses nmap to check if the port specified is closed. Loops until
               the port is open or $total_wait_seconds is reached.

=cut

sub wait_for_port_closed {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return wait_for_port_open($self, @_);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_ssh_known_hosts

 Parameters  : $known_hosts_path (optional)
 Returns     : boolean
 Description : Removes lines from the known_hosts file matching the computer
               name or private IP address, then runs ssh-keyscan to add the
               current keys to the known_hosts file.

=cut

sub update_ssh_known_hosts {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $known_hosts_path = shift || "/root/.ssh/known_hosts";
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Get the computer private IP address
	my $computer_private_ip_address;
	if ($self->can("get_private_ip_address") && ($computer_private_ip_address = $self->get_private_ip_address())) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved private IP address for $computer_short_name using OS module: $computer_private_ip_address");
	}
	elsif ($computer_private_ip_address = $self->data->get_computer_private_ip_address()) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved private IP address for $computer_short_name from database: $computer_private_ip_address");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address for $computer_short_name using OS module or from database");
	}
	
	# Open the file, read the contents into an array, then close it
	my @known_hosts_lines_original;
	if (open FILE, "<", $known_hosts_path) {
		@known_hosts_lines_original = <FILE>;
		close FILE;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to open file for reading: $known_hosts_path");
		return;
	}
	
	
	# Loop through the lines
	my @known_hosts_lines_modified;
	for my $line (@known_hosts_lines_original) {
		chomp $line;
		next if (!$line);
		
		# Check if line matches the computer name or private IP address
		if ($line =~ /(^|[\s,])$computer_short_name[\s,]/i) {
			# Don't add the line to the array which will be added back to the file
			notify($ERRORS{'DEBUG'}, 0, "removing line from $known_hosts_path matching computer name: $computer_short_name\n$line");
			next;
		}
		elsif ($line =~ /(^|[\s,])$computer_private_ip_address[\s,]/i) {
			notify($ERRORS{'DEBUG'}, 0, "removing line from $known_hosts_path matching computer private IP address:$computer_private_ip_address\n$line");
			next;
		}
		
		# Line doesn't match, add it to the array of lines for the new file
		push @known_hosts_lines_modified, "$line\n";
	}
	
	
	# Write the modified contents to the file
	if (open FILE, ">", "$known_hosts_path") {
		print FILE @known_hosts_lines_modified;
		close FILE;
		notify($ERRORS{'DEBUG'}, 0, "removed lines from $known_hosts_path matching $computer_short_name or $computer_private_ip_address");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to open file for writing: $known_hosts_path");
		return;
	}
	
	# Run ssh-keyscan
	run_command("ssh-keyscan -t rsa '$computer_short_name' '$computer_private_ip_address' 2>&1 | grep -v '^#' >> $known_hosts_path");
	
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 server_request_set_fixed_ip

 Parameters  : none
 Returns     : If successful: true
               If failed: false
 Description : 

=cut

sub server_request_set_fixed_ip {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }
   
	my $reservation_id             = $self->data->get_reservation_id() || return;
	my $computer_id                = $self->data->get_computer_id() || return;
	my $computer_node_name         = $self->data->get_computer_node_name() || return;   
	my $image_os_name              = $self->data->get_image_os_name() || return;
	my $image_os_type              = $self->data->get_image_os_type() || return;   
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();   
	my $public_ip_configuration    = $self->data->get_management_node_public_ip_configuration() || return;
	my $server_request_id          = $self->data->get_server_request_id();
	my $server_request_fixed_ip    = $self->data->get_server_request_fixed_ip(); 

	if ($server_request_id) {
		if ($server_request_fixed_ip) {
			#Update the info related to fixedIP
			if (!$self->update_fixed_ip_info()) {
				notify($ERRORS{'WARNING'}, 0, "Unable to update information related fixedIP for server_request $server_request_id");
			}    
			
			#Confirm requested IP is not being used
			if (!$self->confirm_fixed_ip_is_available()) {
				#failed, insert into loadlog, fail reservation	
				insertloadlog($reservation_id, $computer_id, "failed","$server_request_fixed_ip is NOT available");
				return 0;
			}
			
			#if set for static IPs, save the old address to restore
			if ($public_ip_configuration =~ /static/i) {
				notify($ERRORS{'DEBUG'}, 0, "saving original IP for restore on post reseration");
				my $original_IPvalue = "originalIPaddr_" . $server_request_id;
				set_variable($original_IPvalue, $computer_public_ip_address);
			}
			
			# Try to set the static public IP address using the OS module
			if ($self->can("set_static_public_address")) {
				if ($self->set_static_public_address()) {
					notify($ERRORS{'DEBUG'}, 0, "set static public IP address on $computer_node_name using OS module's set_static_public_address() method");                
					$self->data->set_computer_public_ip_address($server_request_fixed_ip);
					
					# Delete cached network configuration information so it is retrieved next time it is needed
					delete $self->{network_configuration};
					
					if (update_computer_public_ip_address($computer_id, $server_request_fixed_ip)) {
						notify($ERRORS{'OK'}, 0, "updated public IP address in computer table for $computer_node_name, $server_request_fixed_ip");
					}
					
					#Update Hostname to match Public assigned name
					if ($self->can("update_public_hostname")) {
						if ($self->update_public_hostname()) {
							notify($ERRORS{'OK'}, 0, "Updated hostname based on fixedIP $server_request_fixed_ip");
						}
					}
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address on $computer_node_name");
					insertloadlog($reservation_id, $computer_id, "failed"," Not able to assigne IPaddress $server_request_fixed_ip");
					return 0;
				}
			}
			else {
			notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address on $computer_node_name, " . ref($self) . " module does not implement a set_static_public_address subroutine");
			}
		}
	}

	return 1;

}


#//////////////////////////////////////////////////////////////////////////////

=head2 confirm_fixed_ip_is_available

 Parameters  : none
 Returns     : If successful: true
					If failed: 0
 Description : Preforms checks to confirm the requested IP is not being used
					-- Check VCL database computer table for IP
					-- try to ping the IP
					-- future; good to check with upstream network switch or control

=cut

sub confirm_fixed_ip_is_available {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $reservation_id = $self->data->get_reservation_id() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $computer_node_name = $self->data->get_computer_node_name() || return;   
	my $server_request_id = $self->data->get_server_request_id();
	my $server_request_fixed_ip = $self->data->get_server_request_fixed_ip(); 
	
	#check VCL computer table
	if (is_ip_assigned_query($server_request_fixed_ip)) {
		notify($ERRORS{'WARNING'}, 0, "$server_request_fixed_ip is already assigned");
		insertloadlog($reservation_id, $computer_id, "failed","$server_request_fixed_ip is already assigned");
		return 0;
	}

	#Is IP pingable	
	if (_pingnode($server_request_fixed_ip)) {
		notify($ERRORS{'WARNING'}, 0, "$server_request_fixed_ip is answering ping test");
		insertloadlog($reservation_id, $computer_id, "failed","$server_request_fixed_ip is answering ping test, but is not assigned in VCL database");
		return 0;	
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_public_ip_address

 Parameters  : none
 Returns     : If successful: true
               If failed: false
 Description : Checks the IP configuration mode for the management node -
               dynamic DHCP, manual DHCP, or static.  If DHCP is used, the
               public IP address is retrieved from the computer and the IP
               address in the computer table is updated if necessary.  If
               static public IP addresses are used, the computer is configured
               to use the public IP address stored in the computer table.

=cut

sub update_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = $self->data->get_reservation_id() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	my $image_os_name = $self->data->get_image_os_name() || return;
	my $image_os_type = $self->data->get_image_os_type() || return;
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();
	my $public_ip_configuration = $self->data->get_management_node_public_ip_configuration() || return;
	my $nathost_hostname = $self->data->get_nathost_hostname(0);
	my $nathost_internal_ip_address = $self->data->get_nathost_internal_ip_address(0);
	
	if ($public_ip_configuration =~ /dhcp/i) {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, attempting to retrieve dynamic public IP address from $computer_node_name");
		
		# Wait for the computer to be assigned a public IP address
		# There is sometimes a delay
		if (!$self->wait_for_public_ip_address()) {
			notify($ERRORS{'WARNING'}, 0, "unable to update public IP address, $computer_node_name did not receive a public IP address via DHCP");
			return;
		}
		
		# Retrieve the public IP address from the OS module
		my $retrieved_public_ip_address = $self->get_public_ip_address();
		if ($retrieved_public_ip_address) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address from $computer_node_name using the OS module: $retrieved_public_ip_address");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve dynamic public IP address from $computer_node_name");
			insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "failed to retrieve dynamic public IP address from $computer_node_name");
			return;
		}
		
		# Update the Datastructure and computer table if the retrieved IP address does not match what is in the database
		if ($computer_public_ip_address ne $retrieved_public_ip_address) {
			$self->data->set_computer_public_ip_address($retrieved_public_ip_address);
			
			if (update_computer_public_ip_address($computer_id, $retrieved_public_ip_address)) {
				notify($ERRORS{'OK'}, 0, "updated dynamic public IP address in computer table for $computer_node_name, $retrieved_public_ip_address");
				insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "updated dynamic public IP address in computer table for $computer_node_name, $retrieved_public_ip_address");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to update dynamic public IP address in computer table for $computer_node_name, $retrieved_public_ip_address");
				insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "failed to update dynamic public IP address in computer table for $computer_node_name, $retrieved_public_ip_address");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "public IP address in computer table is already correct for $computer_node_name: $computer_public_ip_address");
		}
		
		# If the computer is assigned to a NAT host, make sure default gateway is correct
		if ($nathost_hostname && $nathost_internal_ip_address) {
			my $current_default_gateway = $self->get_default_gateway();
			if ($current_default_gateway) {
				if ($current_default_gateway eq $nathost_internal_ip_address) {
					notify($ERRORS{'DEBUG'}, 0, "static default gateway does NOT need to be set on $computer_node_name, default gateway assigned by DHCP matches NAT host internal IP address: $current_default_gateway");
				}
				else {
					notify($ERRORS{'OK'}, 0, "static default gateway needs to be set on $computer_node_name, default gateway assigned by DHCP ($current_default_gateway) does NOT match NAT host internal IP address: $nathost_internal_ip_address");
					$self->set_static_default_gateway();
				}
			}
		}
	}
	elsif ($public_ip_configuration =~ /static/i) {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, attempting to set public IP address");
		
		# Try to set the static public IP address using the OS module
		if ($self->can("set_static_public_address")) {
			if ($self->set_static_public_address()) {
				notify($ERRORS{'DEBUG'}, 0, "set static public IP address on $computer_node_name using OS module's set_static_public_address() method");
				insertloadlog($reservation_id, $computer_id, "staticIPaddress", "set static public IP address on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address on $computer_node_name");
				insertloadlog($reservation_id, $computer_id, "staticIPaddress", "failed to set static public IP address on $computer_node_name");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address on $computer_node_name, " . ref($self) . " module does not implement a set_static_public_address subroutine");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, no public IP address updates necessary");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_correct_default_gateway

 Parameters  : none
 Returns     : boolean
 Description : Determines which IP address should be used for the computer's
               default gateway:
               * If the computer is configured to use a NAT host, the computer's
                 default gateway should be set to the NAT host's internal IP
                 address
               * If NAT is not used and the management node profile is
                 configured to use static public IP addresses, the computer's
                 default gateway should be set to the management node profile's
                 "Public Gateway" setting
               * If NAT is not used and the management node profile is
                 configured to use DHCP-assigned public IP addresses, the
                 computer's current default gateway should continue to be used

=cut

sub get_correct_default_gateway {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	my $nathost_hostname = $self->data->get_nathost_hostname(0);
	my $nathost_internal_ip_address = $self->data->get_nathost_internal_ip_address(0);
	my $management_node_ip_configuration = $self->data->get_management_node_public_ip_configuration();
	
	if ($nathost_internal_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name is configured to use NAT host $nathost_hostname, default gateway should be set to NAT host's internal IP address: $nathost_internal_ip_address");
		return $nathost_internal_ip_address;
	}
	elsif ($management_node_ip_configuration =~ /static/i) {
		my $management_node_public_default_gateway = $self->data->get_management_node_public_default_gateway();
		if ($management_node_public_default_gateway) {
			notify($ERRORS{'DEBUG'}, 0, "management node public IP mode is set to $management_node_ip_configuration, default gateway should be set to management node profile's default gateway setting: $management_node_public_default_gateway");
			return $management_node_public_default_gateway;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine correct default gateway to use on $computer_name, management node public IP mode is set to $management_node_ip_configuration but management node profile's default gateway setting could not be determined");
			return;
		}
	}
	else {
		# Management node configured to use DHCP for public IP addresses
		# Get default gateway address assigned to computer
		my $current_default_gateway = $self->get_public_default_gateway();
		if ($current_default_gateway) {
			notify($ERRORS{'DEBUG'}, 0, "management node public IP mode is set to $management_node_ip_configuration, default gateway currently configured on $computer_name should be used: $current_default_gateway");
			return $current_default_gateway;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine correct default gateway to use on $computer_name, management node public IP mode is set to $management_node_ip_configuration but default gateway currently configured on $computer_name could not be determined");
			return;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_tag

 Parameters  : $tag_name
 Returns     : string
 Description : Reads currentimage.txt and attempts to locate a line beginning
               with the tag name specified by the argument.
               If found, the tag value following the = sign is returned.
               Null is returned if a line with the tag name doesn't exist.

=cut

sub get_current_image_tag {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($tag_name) = @_;
	if (!defined($tag_name)) {
		notify($ERRORS{'WARNING'}, 0, "property argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $current_image_file_path = 'currentimage.txt';
	
	my @lines = $self->get_file_contents($current_image_file_path);
	for my $line (@lines) {
		my ($tag_value) = $line =~ /^$tag_name=(.*)$/gx;
		if (defined($tag_value)) {
			$tag_value = '' unless length($tag_value);
			notify($ERRORS{'DEBUG'}, 0, "found '$tag_name' tag line in $current_image_file_path: '$line', returning tag value: '$tag_value'");
			return $tag_value;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "'$tag_name' tag is not set in $current_image_file_path, returning null");
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_current_image_tag

 Parameters  : $tag_name, $tag_value
 Returns     : boolean
 Description : Adds a line to currentimage.txt in the format:
               <tag name>=<tag value> (timestamp)
					
					The tag value must be a non-empty string and may be the integer
					0. Example:
					set_current_image_tag('mytag');
					
					Line added:
					mytag=0 (Wed Jun 29 17:47:36 2016)
					
					Any lines which already exist beginning with an identical tag
					name are removed.
               
					indicating a loaded computer is
					tainted and must be reloaded for any subsequent reservations. The
					format of the line added is:
               vcld_tainted=true (<time>)
               
					This line is added as a safety measure to prevent a computer
					which was used for one reservation to ever be reserved for
					another reservation without being reloaded.
					
					This line should be added whenever a user has been given the
					connection information and had a chance to connect. It's assumed
					a user connected and the computer is tainted whether or not an
					actual logged in connection was detected. This is done for
					safety. The connection/logged in checking mechanisms of different
					OS's may not be perfect.
					
               This line is checked when a computer is reserved to make sure the
               post_load tasks have run. A computer may be loaded but the
               post_load tasks may not run if it is loaded manually or by some
               other means not controlled by vcld.

=cut

sub set_current_image_tag {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($tag_name, $tag_value) = @_;
	if (!$tag_name) {
		notify($ERRORS{'WARNING'}, 0, "tag name argument was not specified");
		return;
	}
	elsif (!defined($tag_value)) {
		notify($ERRORS{'WARNING'}, 0, "tag value argument was not specified");
		return;
	}
	elsif (!length($tag_value)) {
		notify($ERRORS{'WARNING'}, 0, "tag value argument specified is an empty string");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $current_image_file_path = 'currentimage.txt';
	my $timestamp = makedatestring();
	my $tag_line = "$tag_name=$tag_value ($timestamp)";
	my $updated_contents = '';
	
	my @existing_lines = $self->get_file_contents($current_image_file_path);
	for my $existing_line (@existing_lines) {
		# Skip blank lines and lines matching the tag name
		if ($existing_line !~ /\w/ || $existing_line =~ /^$tag_name=/) {
			next;
		}
		$updated_contents .= "$existing_line\n";
	}
	$updated_contents .= $tag_line;
	
	if ($self->create_text_file($current_image_file_path, $updated_contents)) {
		notify($ERRORS{'DEBUG'}, 0, "set '$tag_name' tag in $current_image_file_path on $computer_name:\n$updated_contents");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set '$tag_name' tag in $current_image_file_path on $computer_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_post_load_status

 Parameters  : none
 Returns     : boolean
 Description : Adds a line to currentimage.txt indicating the post-load tasks
               have successfully been completed on a loaded computer. The
               format of the line is:
               tainted=true (Wed Jun 29 18:00:55 2016)

=cut

sub set_post_load_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->set_current_image_tag('vcld_post_load', 'success');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_post_load_status

 Parameters  : none
 Returns     : boolean
 Description : Checks if a 'vcld_post_load' line exists in currentimage.txt.

=cut

sub get_post_load_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my ($post_load_status) = $self->get_current_image_tag('vcld_post_load');
	if (defined($post_load_status)) {
		notify($ERRORS{'DEBUG'}, 0, "post-load tasks have been completed on $computer_name: $post_load_status");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "post-load tasks have NOT been completed on $computer_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_tainted_status

 Parameters  : $reason (optional)
 Returns     : boolean
 Description : Adds a line to currentimage.txt indicating a loaded computer is
               tainted and must be reloaded for any subsequent reservations.
               
               This line is added as a safety measure to prevent a computer
               which was used for one reservation to ever be reserved for
               another reservation without being reloaded.
               
               This line should be added whenever a user has been given the
               connection information and had a chance to connect. It's assumed
               a user connected and the computer is tainted whether or not an
               actual logged in connection was detected. This is done for
               safety. The connection/logged in checking mechanisms of different
               OS's may not be perfect.
               
               This line is checked when a computer is reserved to make sure the
               post_load tasks have run. A computer may be loaded but the
               post_load tasks may not run if it is loaded manually or by some
               other means not controlled by vcld.

=cut

sub set_tainted_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reason = shift || 'no reason given';
	
	# This may be called multiple times for a reservation
	# It's useful to append concatenate the status rather than overwriting it so you know all of the reasons a computer may be tainted
	my $previous_tained_status = $self->get_tainted_status();
	if ($previous_tained_status) {
		$reason = "$previous_tained_status, $reason";
	}
	
	return $self->set_current_image_tag('vcld_tainted', $reason);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_tainted_status

 Parameters  : none
 Returns     : string
 Description : Checks if a line exists in currentimage.txt indicated a user may
               have logged in.

=cut

sub get_tainted_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $tainted_status = $self->get_current_image_tag('vcld_tainted');
	if (defined($tainted_status)) {
		notify($ERRORS{'DEBUG'}, 0, "image currently loaded on $computer_name has been tainted: $tainted_status");
		return $tainted_status;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image currently loaded on $computer_name has NOT been tainted");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_interface_name

 Parameters  : none
 Returns     : string
 Description : Determines the private interface name based on the information in
               the network configuration hash returned by
               get_network_configuration. The interface which is assigned the
               private IP address for the reservation computer is returned.

=cut

sub get_private_interface_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{private_interface_name} if defined $self->{private_interface_name};
	
	# Get the network configuration hash reference
	my $network_configuration = $self->get_network_configuration();
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine private interface name, failed to retrieve network configuration");
		return;
	}
	
	# Get the computer private IP address
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
	if (!$computer_private_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
		return;
	}
	
	# Loop through all of the network interfaces found
	foreach my $interface_name (sort keys %$network_configuration) {
		# Get the interface IP addresses and make sure an IP address was found
		my @ip_addresses  = keys %{$network_configuration->{$interface_name}{ip_address}};
		if (!@ip_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "interface is not assigned an IP address: $interface_name");
			next;
		}
		
		# Check if interface has the private IP address assigned to it
		if (grep { $_ eq $computer_private_ip_address } @ip_addresses) {
			$self->{private_interface_name} = $interface_name;
			notify($ERRORS{'DEBUG'}, 0, "determined private interface name: $self->{private_interface_name} (" . join (", ", @ip_addresses) . ")");
			return $self->{private_interface_name};
		}
	}

	notify($ERRORS{'WARNING'}, 0, "failed to determine private interface name, no interface is assigned the private IP address for the reservation: $computer_private_ip_address\n" . format_data($network_configuration));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_interface_name

 Parameters  : $no_cache (optional), $ignore_error (optional)
 Returns     : string
 Description : Determines the public interface name based on the information in
               the network configuration hash returned by
               get_network_configuration.

=cut

sub get_public_interface_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift || 0;
	my $ignore_error = shift || 0;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to determine public interface name, no cache: $no_cache, ignore error: $ignore_error");
	
	if ($no_cache) {
		delete $self->{public_interface_name};
	}
	elsif ($self->{public_interface_name}) {
		#notify($ERRORS{'DEBUG'}, 0, "returning public interface name previously retrieved: $self->{public_interface_name}");
		return $self->{public_interface_name};
	}
	
	# Get the network configuration hash reference
	my $network_configuration = $self->get_network_configuration($no_cache);
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine public interface name, failed to retrieve network configuration");
		return;
	}
	
	# Get the computer private IP address
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
	if (!$computer_private_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
		return;
	}
	
	my $public_interface_name;
	
	# Loop through all of the network interfaces found
	INTERFACE: for my $check_interface_name (sort keys %$network_configuration) {
		
		my $description = $network_configuration->{$check_interface_name}{description} || '';
		my $master = $network_configuration->{$check_interface_name}{master};
		
		# Check if the interface should be ignored based on the name or description
		if ($check_interface_name =~ /^(lo|sit\d)$/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its name is '$1'");
			next INTERFACE;
		}
		elsif ($check_interface_name =~ /(loopback|vmnet|afs|tunnel|6to4|isatap|teredo)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its name contains '$1'");
			next INTERFACE;
		}
		elsif ($description =~ /(loopback|afs|tunnel|pseudo|6to4|isatap)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its description contains '$1'");
			next INTERFACE;
		}
		elsif ($master) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because it is a slave to $master");
			next INTERFACE;
		}
		
		# If $public_interface_name hasn't been set yet, set it and continue checking the next interface
		if (!$public_interface_name) {
			my @check_ip_addresses = keys %{$network_configuration->{$check_interface_name}{ip_address}};
			my $matches_private = (grep { $_ eq $computer_private_ip_address } @check_ip_addresses) ? 1 : 0;
			
			if ($matches_private) {
				if (scalar(@check_ip_addresses) == 1) {
					notify($ERRORS{'DEBUG'}, 0, "'$check_interface_name' could not be the public interface, it is only assigned the private IP address");
					next INTERFACE;
				}
				
				notify($ERRORS{'DEBUG'}, 0, "'$check_interface_name' is assigned private IP address, checking if other assigned IP addresses could potentially be public");
				CHECK_IP_ADDRESS: for my $check_ip_address (@check_ip_addresses) {
					
					if ($check_ip_address eq $computer_private_ip_address) {
						notify($ERRORS{'DEBUG'}, 0, "ignoring private IP address ($check_ip_address) assigned to interface '$check_interface_name'");
						next CHECK_IP_ADDRESS;
					}
					elsif ($check_ip_address =~ /^(169\.254|0\.0\.0\.0)/) {
						notify($ERRORS{'DEBUG'}, 0, "ignoring invalid IP address ($check_ip_address) assigned to interface '$check_interface_name'");
						next CHECK_IP_ADDRESS;
					}
					else {
						notify($ERRORS{'DEBUG'}, 0, "'$check_interface_name' could potententially be public interface, assigned IP address: $check_ip_address");
						$public_interface_name = $check_interface_name;
						last CHECK_IP_ADDRESS;
					}
				}
			}
			else {
				# Does not match private IP address
				notify($ERRORS{'DEBUG'}, 0, "'$check_interface_name' could potentially be public interface, not assigned private IP address");
				$public_interface_name = $check_interface_name;
			}
			
			next INTERFACE;
		}
		
		# Call the helper subroutine
		# It uses recursion to avoid large/duplicated if-else blocks
		$public_interface_name = $self->_get_public_interface_name_helper($check_interface_name, $public_interface_name);
		if (!$public_interface_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine if '$check_interface_name' or '$public_interface_name' is more likely the public interface");
			next INTERFACE;
		}
	}
	
	if ($public_interface_name) {
		$self->{public_interface_name} = $public_interface_name;
		notify($ERRORS{'OK'}, 0, "determined the public interface name: '$self->{public_interface_name}'");
		return $self->{public_interface_name};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the public interface name:\n" . format_data($network_configuration)) unless $ignore_error;
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_public_interface_name_helper

 Parameters  : $interface_name_1, $interface_name_2
 Returns     : string
 Description : Compares the network configuration of the interfaces passed as
               the arguments. Returns the name of the interface more likely to
               be the public interface. It checks the following:
               1. Is either interface assigned a public IP address?
                  - If only 1 interface is assigned a public IP address then that interface name is returned.
                  - If neither or both are assigned a public IP address:
               2. Is either interface assigned a default gateway?
                  - If only 1 interface is assigned a default gateway then that interface name is returned.
                  - If neither or both are assigned a default gateway:
               3. Is either interface assigned the private IP address?
                  - If only 1 interface is assigned the private IP address, then the other interface name is returned.
                  - If neither or both are assigned the private IP address, the first interface argument is returned

=cut

sub _get_public_interface_name_helper {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($interface_name_1, $interface_name_2, $condition) = @_;
	
	if (!$interface_name_1 || !$interface_name_2) {
		notify($ERRORS{'WARNING'}, 0, "\$network_configuration, \$interface_name_1, and \$interface_name_2 arguments were not specified");
		return;
	}
	
	my $network_configuration = $self->get_network_configuration();
	my @ip_addresses_1 = keys %{$network_configuration->{$interface_name_1}{ip_address}};
	my @ip_addresses_2 = keys %{$network_configuration->{$interface_name_2}{ip_address}};
	
	if (!$condition || $condition eq 'matches_private') {
		# Get the computer private IP address
		my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
		if (!$computer_private_ip_address) {
			notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
			return;
		}
		
		my $matches_private_1 = (grep { $_ eq $computer_private_ip_address } @ip_addresses_1) ? 1 : 0;
		my $matches_private_2 = (grep { $_ eq $computer_private_ip_address } @ip_addresses_2) ? 1 : 0;
		
		if ($matches_private_1 eq $matches_private_2) {
			notify($ERRORS{'DEBUG'}, 0, "tie: both interfaces are/are not assigned the private IP address: $computer_private_ip_address, proceeding to check if either interface is assigned a public IP address");
			return $self->_get_public_interface_name_helper($interface_name_1, $interface_name_2, 'assigned_public');
		}
		elsif ($matches_private_1) {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_2' is more likely the public interface, it is NOT assigned the private IP address: $computer_private_ip_address");
			return $interface_name_2;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_1' is more likely the public interface, it is NOT assigned the private IP address: $computer_private_ip_address");
			return $interface_name_1;
		}
	}
	elsif ($condition eq 'assigned_public') {
		my $assigned_public_1 = (grep { is_public_ip_address($_) } @ip_addresses_1) ? 1 : 0;
		my $assigned_public_2 = (grep { is_public_ip_address($_) } @ip_addresses_2) ? 1 : 0;
		
		if ($assigned_public_1 eq $assigned_public_2) {
			notify($ERRORS{'DEBUG'}, 0, "tie: both interfaces are/are not assigned public IP addresses, proceeding to check default gateways");
			return $self->_get_public_interface_name_helper($interface_name_1, $interface_name_2, 'assigned_gateway');
		}
		elsif ($assigned_public_1) {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_1' is more likely the public interface, it is assigned a public IP address, '$interface_name_2' is not");
			return $interface_name_1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_2' is more likely the public interface, it is assigned a public IP address, '$interface_name_1' is not");
			return $interface_name_2;
		}
	}
	elsif ($condition eq 'assigned_gateway') {
		my $assigned_default_gateway_1 = defined($network_configuration->{$interface_name_1}{default_gateway}) ? 1 : 0;
		my $assigned_default_gateway_2 = defined($network_configuration->{$interface_name_2}{default_gateway}) ? 1 : 0;
		
		if ($assigned_default_gateway_1 eq $assigned_default_gateway_2) {
			notify($ERRORS{'DEBUG'}, 0, "tie: both interfaces are/are not assigned a default gateway, returning '$interface_name_2'");
			return $interface_name_2;
		}
		elsif ($assigned_default_gateway_1) {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_1' is more likely the public interface, it is assigned a default gateway, '$interface_name_2' is not");
			return $interface_name_1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$interface_name_2' is more likely the public interface, it is assigned a default gateway, '$interface_name_1' is not");
			return $interface_name_2;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine which interface is more likely the public interface, invalid \$condition argument: '$condition'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_public_ip_address

 Parameters  : $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : boolean
 Description : Loops until the computer's public interface name can be retrieved
               or the timeout is reached. The public interface name can only be
               retrieved if an IP address is assigned to it. The default maximum
               wait time is 60 seconds.

=cut

sub wait_for_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the total number of seconds to wait from the arguments
	my $total_wait_seconds = shift;
	if (!defined($total_wait_seconds) || $total_wait_seconds !~ /^\d+$/) {
		$total_wait_seconds = 60;
	}
	
	# Seconds to wait in between loop attempts
	my $attempt_delay_seconds = shift;
	if (!defined($attempt_delay_seconds) || $attempt_delay_seconds !~ /^\d+$/) {
		$attempt_delay_seconds = 2;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check if the public IP address was already retrieved
	# Use cached data if available (0), ignore errors (1)
	my $public_ip_address = $self->get_public_ip_address(0, 1);
	if ($public_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is already assigned a public IP address: $public_ip_address");
		return 1;
	}
	
	my $sub_ref = $self->can("get_public_ip_address");
	notify($ERRORS{'DEBUG'}, 0, "");
	my $message = "waiting for $computer_node_name to get public IP address";
	
	return $self->code_loop_timeout(
		sub {
			my $public_ip_address = $self->get_public_ip_address(1, 1);
			if (!defined($public_ip_address)) {
				return;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name was assigned a public IP address: $public_ip_address");
				return 1;
			}
		},
		[$self, 1],
		$message,
		$total_wait_seconds,
		$attempt_delay_seconds
	);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_network_configuration

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub get_private_network_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $private_interface_name = $self->get_private_interface_name();
	if (!$private_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private network configuration, private interface name could not be determined");
		return;
	}
	
	return $self->get_network_configuration()->{$private_interface_name};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_network_configuration

 Parameters  : $no_cache (optional), $ignore_error (optional)
 Returns     : hash reference
 Description : 

=cut

sub get_public_network_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift || 0;
	my $ignore_error = shift || 0;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve public network configuration, no cache: $no_cache, ignore error: $ignore_error");
	
	my $public_interface_name = $self->get_public_interface_name($no_cache, $ignore_error);
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve public network configuration, public interface name could not be determined") unless $ignore_error;
		return;
	}
	
	return $self->get_network_configuration()->{$public_interface_name};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_mac_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_mac_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	# Assume 'public' if not specified
	my $network_type = shift || 'public';
	$network_type = lc($network_type) if $network_type;
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}

	# Get the public or private network configuration
	# Use 'eval' to construct the appropriate subroutine name
	my $network_configuration = eval "\$self->get_$network_type\_network_configuration()";
	if ($EVAL_ERROR || !$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $network_type network configuration");
		return;
	}

	my $mac_address = $network_configuration->{physical_address};
	if ($mac_address) {
		notify($ERRORS{'DEBUG'}, 0, "returning $network_type MAC address: $mac_address");
		return $mac_address;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type MAC address, 'physical_address' key does not exist in the network configuration info: \n" . format_data($network_configuration));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_mac_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_mac_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_mac_address('private');
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_mac_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_mac_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_mac_address('public');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_ip_address

 Parameters  : $network_type (optional), $no_cache (optional), $ignore_error (optional)
 Returns     : string
 Description : Returns the IP address of the computer. The $network_type
               argument may either be 'public' or 'private'. If not supplied,
               the default is to return the public IP address.

=cut

sub get_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	# Assume 'public' if not specified
	my $network_type = shift || 'public';
	$network_type = lc($network_type) if $network_type;
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}
	
	my $no_cache = shift || 0;
	my $ignore_error = shift || 0;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve IP address, type: $network_type, no cache: $no_cache, ignore error: $ignore_error");
	
	# Get the public or private network configuration
	# Use 'eval' to construct the appropriate subroutine name
	my $network_configuration = eval "\$self->get_$network_type\_network_configuration($no_cache, $ignore_error)";
	if ($EVAL_ERROR || !$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $network_type network configuration") unless $ignore_error;
		return;
	}
	
	my $ip_address_info = $network_configuration->{ip_address};
	if (!defined($ip_address_info)) {
		notify($ERRORS{'WARNING'}, 0, "$network_type network configuration info does not contain an 'ip_address' key") unless $ignore_error;
		return;
	}
	
	# Return the first valid IP address found
	my $ip_address;
	my @ip_addresses = keys %$ip_address_info;
	if (!@ip_addresses) {
		if (!$ignore_error) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type IP address, 'ip_address' value is not set in the network configuration info: \n" . format_data($network_configuration));
		}
		return;
	}
	
	# Interface has multiple IP addresses, try to find a valid one
	for $ip_address (@ip_addresses) {
		if ($ip_address !~ /(0\.0\.0\.0|169\.254\.)/) {
			#notify($ERRORS{'DEBUG'}, 0, "returning $network_type IP address: $ip_address");
			return $ip_address;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "skipping invalid IP address assigned to $network_type interface: $ip_address, checking if another valid IP address is assigned");
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "$network_type interface not assigned a valid IP address: " . join(", ", @ip_addresses));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_ip_addresses

 Parameters  : $no_cache (optional)
 Returns     : array
 Description : Returns all of the IP addresses of the computer.

=cut

sub get_ip_addresses {
	my ($self, $no_cache) = @_;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Get the network configuration hash reference
	my $network_configuration = $self->get_network_configuration($no_cache);
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve IP addresses from $computer_name, failed to retrieve network configuration");
		return;
	}
	
	# Loop through all of the network interfaces found
	my @ip_addresses;
	for my $interface_name (sort keys %$network_configuration) {
		if ($network_configuration->{$interface_name}{ip_address}) {
			push @ip_addresses, keys %{$network_configuration->{$interface_name}{ip_address}};
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved IP addresses bound on $computer_name:\n" . join("\n", @ip_addresses));
	return @ip_addresses;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_ip_address

 Parameters  : $no_cache (optional), $ignore_error (optional)
 Returns     : string
 Description : Returns the computer's private IP address.

=cut

sub get_private_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift;
	my $ignore_error = shift;
	
	return $self->get_ip_address('private', $no_cache, $ignore_error);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_address

 Parameters  : $no_cache (optional), $ignore_error (optional)
 Returns     : string
 Description : Returns the computer's public IP address.

=cut

sub get_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my $no_cache = shift || 0;
	my $ignore_error = shift || 0;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve public IP address, no cache: $no_cache, ignore error: $ignore_error");
	return $self->get_ip_address('public', $no_cache, $ignore_error);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_subnet_mask

 Parameters  : 
 Returns     : $ip_address
 Description : 

=cut

sub get_subnet_mask {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the IP address argument
	my $ip_address = shift;
	if (!$ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine subnet mask, IP address argument was not specified");
		return;
	}

	# Make sure network configuration was retrieved
	my $network_configuration = $self->get_network_configuration();
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	for my $interface_name (keys(%$network_configuration)) {
		my $ip_address_info = $network_configuration->{$interface_name}{ip_address};
		
		if (!defined($ip_address_info->{$ip_address})) {
			next;
		}
		
		my $subnet_mask = $ip_address_info->{$ip_address};
		if ($subnet_mask) {
			return $subnet_mask;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "subnet mask is not set for interface '$interface_name' IP address $ip_address in network configuration:\n" . format_data($network_configuration));
			return;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "interface with IP address $ip_address does not exist in the network configuration:\n" . format_data($network_configuration));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_subnet_mask

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_subnet_mask {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_subnet_mask($self->get_private_ip_address());
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_subnet_mask

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_subnet_mask {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_subnet_mask($self->get_public_ip_address());
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_default_gateway

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_default_gateway {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	# Assume 'public' if not specified
	my $network_type = shift || 'public';
	$network_type = lc($network_type) if $network_type;
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}

	# Get the public or private network configuration
	# Use 'eval' to construct the appropriate subroutine name
	my $network_configuration = eval "\$self->get_$network_type\_network_configuration()";
	if ($EVAL_ERROR || !$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $network_type network configuration");
		return;
	}
	
	my $default_gateway = $network_configuration->{default_gateway};
	if ($default_gateway) {
		notify($ERRORS{'DEBUG'}, 0, "returning $network_type default gateway: $default_gateway");
		return $default_gateway;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type default gateway, 'default_gateway' key does not exist in the network configuration info: \n" . format_data($network_configuration));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_default_gateway

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_default_gateway {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_default_gateway('private');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_default_gateway

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_default_gateway {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_default_gateway('public');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_dns_servers

 Parameters  : $network_type
 Returns     : array
 Description : Retrieves a list of DNS servers currently configured on the
               computer. The $network_type argument may either be 'private' or
               'public'. The default is to retrieve the DNS servers configured
               for the public interface.

=cut

sub get_dns_servers {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	# Assume 'public' if not specified
	my $network_type = shift || 'public';
	$network_type = lc($network_type) if $network_type;
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}

	# Get the public or private network configuration
	# Use 'eval' to construct the appropriate subroutine name
	my $network_configuration = eval "\$self->get_$network_type\_network_configuration()";
	if ($EVAL_ERROR || !$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $network_type network configuration");
		return;
	}
	
	if (!defined($network_configuration->{dns_servers})) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type DNS servers, 'dns_servers' key does not exist in the network configuration info: \n" . format_data($network_configuration));
		return;
	}
	elsif (!ref($network_configuration->{dns_servers}) || ref($network_configuration->{dns_servers}) ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type DNS servers, 'dns_servers' key is not an array reference in the network configuration info: \n" . format_data($network_configuration));
		return;
	}
	
	my @dns_servers = @{$network_configuration->{dns_servers}};
	notify($ERRORS{'DEBUG'}, 0, "returning $network_type DNS servers: " . join(", ", @dns_servers));
	return @dns_servers;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_dns_servers

 Parameters  : none
 Returns     : array
 Description : Retrieves a list of DNS servers currently configured for the
               private interface on the computer. 

=cut

sub get_private_dns_servers {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_dns_servers('private');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_dns_servers

 Parameters  : none
 Returns     : array
 Description : Retrieves a list of DNS servers currently configured for the
               public interface on the computer. 

=cut

sub get_public_dns_servers {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_dns_servers('public');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_text_file

 Parameters  : $file_path, $file_contents, $append
 Returns     : boolean
 Description : Creates a text file on the computer or appends to an existing
               file.
               
               A trailing newline character is added to the end of the
               file if one is not present in the $file_contents argument.
               
               It is assumed that when appending to an existing file, the value
               of $file_contents is intended to be added on a new line at the
               end of the file. The contents of the existing file are first
               retrieved. If the existing file does not contain a trailing
               newline, one is added before appending to the file.

=cut

sub create_text_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $file_contents_string, $append) = @_;
	if (!defined($file_path)) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	elsif (!defined($file_contents_string)) {
		notify($ERRORS{'WARNING'}, 0, "file contents argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $image_os_type = $self->data->get_image_os_type();
	my $newline;
	if ($image_os_type =~ /win/i) {
		$newline = "\r\n";
	}
	else {
		$newline = "\n";
	}
	
	# Used only to format notify messages
	my $mode_string;
	if ($append) {
		$mode_string = 'append';
		
		# Retrieve the contents of the existing file if necessary
		if ($self->file_exists($file_path)) {
			my $existing_file_contents = $self->get_file_contents($file_path);
			if (!defined($existing_file_contents)) {
				# Do not proceed if any problem occurred retrieving the existing file contents
				# Otherwise, it would be overwritten and data would be lost
				notify($ERRORS{'WARNING'}, 0, "failed to $mode_string text file on $computer_node_name, append argument was specified but contents of the existing file could not be retrieved: $file_path");
				return;
			}
			elsif ($existing_file_contents && $existing_file_contents !~ /\n$/) {
				# Add a newline to the end of the existing contents if one isn't present
				$existing_file_contents .= $newline;
				$file_contents_string = $existing_file_contents . $file_contents_string;
			}
			
		}
	}
	else {
		$mode_string = 'create';
	}

	# Make sure the file contents ends with a newline
	# This is helpful to prevent problems with files such as sshd_config and sudoers where a line might be echo'd to the end of it
	# Without the newline, the last line could wind up being a merged line if a simple echo is used to add a line
	if (length($file_contents_string) && $file_contents_string !~ /\n$/) {
		$file_contents_string .= $newline;
	}
	
	# Make line endings consistent
	$file_contents_string =~ s/\r*\n/$newline/g;

	# Attempt to create the parent directory if it does not exist
	if ($file_path =~ /[\\\/]/ && $self->can('create_directory')) {
		my $parent_directory_path = parent_directory_path($file_path);
		$self->create_directory($parent_directory_path) if $parent_directory_path;
	}
	
	# The echo method will fail of the file contents are too large
	# An "Argument list too long" error will be displayed
	my $file_contents_length = length($file_contents_string);
	if ($file_contents_length < 32000) {
		# Create a command to echo the string and another to echo the hex string to the file
		# The hex string command is preferred because it will handle special characters including single quotes
		# Use -e to enable interpretation of backslash escapes
		# Use -n to prevent trailing newline from being added
		# However, the command may become very long and fail
		# Convert the string to a string containing the hex value of each character
		# This is done to avoid problems with special characters in the file contents
		# Split the string up into an array if integers representing each character's ASCII decimal value
		my @decimal_values = unpack("C*", $file_contents_string);
		
		# Convert the ASCII decimal values into hex values and add '\x' before each hex value
		my @hex_values = map { '\x' . sprintf("%x", $_) } @decimal_values;
		
		# Join the hex values together into a string
		my $hex_string = join('', @hex_values);
		
		# Enclose the file path in quotes if it contains a space
		if ($file_path =~ /[\s]/) {
			$file_path = "\"$file_path\"";
		}
		
		# Attempt to create the file using the hex string
		my $command = "echo -n -e \"$hex_string\" > $file_path";
		my ($exit_status, $output) = $self->execute($command, 0, 15, 1);
		if (!defined($output)) {
			notify($ERRORS{'DEBUG'}, 0, "failed to execute command to $mode_string file on $computer_node_name, attempting to create file on management node and copy it to $computer_node_name");
		}
		elsif ($exit_status != 0 || grep(/^\w+:/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to $mode_string a file on $computer_node_name, command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output) . "\nattempting to create file on management node and copy it to $computer_node_name");
		}
		elsif ($append) {
			notify($ERRORS{'DEBUG'}, 0, $mode_string . ($append ? 'ed' : 'd') . " text file on $computer_node_name: $file_path");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, $mode_string . ($append ? 'ed' : 'd') . " text file on $computer_node_name: $file_path");
			return 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "skipping attempt to $mode_string on $computer_node_name using echo, file content string length: $file_contents_length");
	}
	
	# File was not created using the quicker echo method
	# Create a temporary file on the management node, copy it to the computer, then delete temporary file from management node
	my $mn_temp_file_path = tmpnam();
	if (!$self->mn_os->create_text_file($mn_temp_file_path, $file_contents_string, $append)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create text file on $computer_node_name, temporary file could not be created on the management node");
		return;
	}
	if (!$self->copy_file_to($mn_temp_file_path, $file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create text file, temporary file could not be dopied from management node to $computer_node_name: $mn_temp_file_path --> $file_path");
		return;
	}
	$self->mn_os->delete_file($mn_temp_file_path);
	notify($ERRORS{'DEBUG'}, 0, "created text file on $computer_node_name by copying a file created on management node");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 append_text_file

 Parameters  : $file_path, $file_contents
 Returns     : boolean
 Description : Appends to a text file on the computer.

=cut

sub append_text_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $file_contents_string) = @_;
	if (!$file_path || !defined($file_contents_string)) {
		notify($ERRORS{'WARNING'}, 0, "file path and contents arguments were not supplied");
		return;
	}
	
	return $self->create_text_file($file_path, $file_contents_string, 1);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_text_file_line_endings

 Parameters  : $file_path, $line_ending (optional)
 Returns     : boolean
 Description : Changes the line endings of a text file. This is equivalent to
               running unix2dos or dos2unix. The default line ending type is
               unix. Windows-style line endings will be applied if the
               $line_ending argument is supplied and contains 'win' or 'r'.

=cut

sub set_text_file_line_endings {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $line_ending) = @_;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $file_contents_original = $self->get_file_contents($file_path);
	if (!defined($file_contents_original)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set line endings for $file_path on $computer_name, failed to retrieve file contents");
		return;
	}
	my $file_contents_updated = $file_contents_original;
	
	my $line_ending_type;
	if ($line_ending && $line_ending =~ /(r|win)/i) {
		$file_contents_updated =~ s/\r?\n/\r\n/g;
		$line_ending_type = 'Windows';
	}
	else {
		$file_contents_updated =~ s/\r//g;
		$line_ending_type = 'Unix';
	}
	
	if ($file_contents_updated eq $file_contents_original) {
		notify($ERRORS{'DEBUG'}, 0, "$line_ending_type-style line endings already set for $file_path on $computer_name");
		return 1;
	}
	elsif ($self->create_text_file($file_path, $file_contents_updated)) {
		notify($ERRORS{'DEBUG'}, 0, "set $line_ending_type-style line endings for $file_path on $computer_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set $line_ending_type-style line endings for $file_path on $computer_name, unable to overwrite file");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_file_contents

 Parameters  : $file_path
 Returns     : array or string
 Description : Returns the contents of the file specified by the file path
               argument.
               
               If the expected return value is an array, each array element
               contains a string for each line from the file. Newlines and
               carriage returns are not included.
               
               If the expected return value is a scalar, a string is returned.

=cut

sub get_file_contents {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Run cat to retrieve the contents of the file
	my $command = "cat \"$file_path\"";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to read file on $computer_short_name: '$file_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^cat: /, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to read contents of file on $computer_short_name: '$file_path', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved " . scalar(@$output) . " lines from file on $computer_short_name: '$file_path'");
		if (wantarray) {
			return @$output;
		}
		else {
			return join("\n", @$output);
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_lines_from_file

 Parameters  : $file_path, $pattern
 Returns     : integer or undefined
 Description : Removes all lines containing the pattern from the file. The
               pattern must be a regular expression. Returns the number of lines
               removed from the file which may be 0. Returns undefined if an
               error occurred.

=cut

sub remove_lines_from_file {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $pattern) = @_;
	if (!$file_path || !$pattern) {
		notify($ERRORS{'WARNING'}, 0, "file path and pattern arguments were not specified");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	my @lines_removed;
	my @lines_retained;
	
	if (!$self->file_exists($file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "lines containing '$pattern' not removed because file does NOT exist: $file_path");
		return 0;
	}
	
	my @lines = $self->get_file_contents($file_path);
	for my $line (@lines) {
		if ($line =~ /$pattern/) {
			push @lines_removed, $line;
		}
		else {
			push @lines_retained, $line;
		}
	}
	
	if (@lines_removed) {
		my $lines_removed_count = scalar(@lines_removed);
		my $new_file_contents = join("\n", @lines_retained) || '';
		notify($ERRORS{'DEBUG'}, 0, "removed $lines_removed_count line" . ($lines_removed_count > 1 ? 's' : '') . " from $file_path matching pattern: '$pattern'\n" . join("\n", @lines_removed));
		$self->create_text_file($file_path, $new_file_contents) || return;	
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$file_path does NOT contain any lines matching pattern: '$pattern'");
	}
	return scalar(@lines_removed);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional)
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the computer via SSH.

=cut

sub execute {
	my @original_arguments = @_;
	my ($argument) = @_;
	my ($computer_name, $command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password, $identity_key, $ignore_error);
	
	my $self;
	
	# Check if this subroutine was called as an object method
	if (ref($argument) && ref($argument) =~ /VCL::Module/) {
		# Subroutine was called as an object method ($self->execute)
		$self = shift;
		($argument) = @_;
		
		#notify($ERRORS{'DEBUG'}, 0, "called as an object method: " . ref($self));
		
		# Get the computer name from the reservation data
		$computer_name = $self->data->get_computer_node_name();
		if (!$computer_name) {
			notify($ERRORS{'WARNING'}, 0, "called as an object method, failed to retrieve computer name from reservation data");
			return;
		}
		#notify($ERRORS{'DEBUG'}, 0, "retrieved computer name from reservation data: $computer_name");
	}
	
	my $no_persistent_connection = 0;
	
	# Check the argument type
	if (ref($argument)) {
		if (ref($argument) eq 'HASH') {
			#notify($ERRORS{'DEBUG'}, 0, "first argument is a hash reference:\n" . format_data($argument));
			
			$computer_name = $argument->{node} if (!$computer_name);
			$command = $argument->{command};
			$display_output = $argument->{display_output};
			$timeout_seconds = $argument->{timeout_seconds};
			$max_attempts = $argument->{max_attempts};
			$port = $argument->{port};
			$user = $argument->{user};
			$password = $argument->{password};
			$identity_key = $argument->{identity_key};
			$ignore_error = $argument->{ignore_error};
			$no_persistent_connection = $argument->{no_persistent_connection};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "invalid argument reference type passed: " . ref($argument) . ", if a reference is passed as the argument it may only be a hash or VCL::Module reference");
			return;
		}
	}
	else {
		# Argument is not a reference, computer name must be the first argument unless this subroutine was called as an object method
		# If called as an object method, $computer_name will already be populated
		if (!$computer_name) {
			$computer_name = shift;
			#notify($ERRORS{'DEBUG'}, 0, "first argument is a scalar, should be the computer name: $computer_name, remaining arguments:\n" . format_data(\@_));
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "first argument should be the command:\n" . format_data(\@_));
		}
		
		# Get the remaining arguments
		($command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password, $identity_key, $ignore_error) = @_;
	}
	
	if (!$computer_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name could not be determined");
		return;
	}
	if (!$command) {
		notify($ERRORS{'WARNING'}, 0, "command argument was not specified");
		return;
	}
	
	# TESTING: use the new subroutine if $ENV{execute_new} is set and the command isn't one that's known to fail with the new subroutine
	if ($ENV{execute_new} && !$no_persistent_connection) {
		my @excluded_commands = $command =~ /(vmkfstools|qemu-img|Convert-VHD|scp|shutdown|reboot)/i;
		if (@excluded_commands) {
			notify($ERRORS{'DEBUG'}, 0, "not using execute_new, command: $command\nexcluded commands matched:\n" . join("\n", @excluded_commands));
		}
		else {
			return execute_new(@original_arguments);
		}
	}
	
	# If 'ssh_user' key is set in this object, use it
	# This allows OS modules to specify the username to use
	if ($self && $self->{ssh_user}) {
		#notify($ERRORS{'DEBUG'}, 0, "\$self->{ssh_user} is defined: $self->{ssh_user}");
		$user = $self->{ssh_user};
	}
	elsif (!$port) {
		$user = 'root';
	}
	
	# If 'ssh_port' key is set in this object, use it
	# This allows OS modules to specify the port to use
	if ($self && $self->{ssh_port}) {
		#notify($ERRORS{'DEBUG'}, 0, "\$self->{ssh_port} is defined: $self->{ssh_port}");
		$port = $self->{ssh_port};
	}
	elsif (!$port) {
		$port = 22;
	}
	
	my $arguments = {
		node => $computer_name,
		command => $command,
		identity_paths => $identity_key,
		user => $user,
		port => $port,
		output_level => $display_output,
		max_attempts => $max_attempts,
		timeout_seconds => $timeout_seconds,
	};
	
	# Run the command via SSH
	my ($exit_status, $output) = run_ssh_command($arguments);
	if (defined($exit_status) && defined($output)) {
		if ($display_output) {
			notify($ERRORS{'DEBUG'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		}
		return ($exit_status, $output);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on $computer_name: $command") if $display_output;
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 execute_new

 Parameters  : $computer_name (conditional), $command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the computer via SSH.

=cut

sub execute_new {
	my ($argument) = @_;
	my ($computer_name, $command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password, $identity_key, $ignore_error);
	
	my $self;
	
	# Check if this subroutine was called as an object method
	if (ref($argument) && ref($argument) =~ /VCL::Module/) {
		# Subroutine was called as an object method ($self->execute)
		$self = shift;
		($argument) = @_;
		
		#notify($ERRORS{'DEBUG'}, 0, "called as an object method: " . ref($self));
		
		# Get the computer name from the reservation data
		$computer_name = $self->data->get_computer_node_name();
		if (!$computer_name) {
			notify($ERRORS{'WARNING'}, 0, "called as an object method, failed to retrieve computer name from reservation data");
			return;
		}
		#notify($ERRORS{'DEBUG'}, 0, "retrieved computer name from reservation data: $computer_name");
	}
	
	# Check the argument type
	if (ref($argument)) {
		if (ref($argument) eq 'HASH') {
			#notify($ERRORS{'DEBUG'}, 0, "first argument is a hash reference:\n" . format_data($argument));
			
			$computer_name = $argument->{node} if (!$computer_name);
			$command = $argument->{command};
			$display_output = $argument->{display_output};
			$timeout_seconds = $argument->{timeout_seconds};
			$max_attempts = $argument->{max_attempts};
			$port = $argument->{port};
			$user = $argument->{user};
			$password = $argument->{password};
			$identity_key = $argument->{identity_key};
			$ignore_error = $argument->{ignore_error};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "invalid argument reference type passed: " . ref($argument) . ", if a reference is passed as the argument it may only be a hash or VCL::Module reference");
			return;
		}
	}
	else {
		# Argument is not a reference, computer name must be the first argument unless this subroutine was called as an object method
		# If called as an object method, $computer_name will already be populated
		if (!$computer_name) {
			$computer_name = shift;
			#notify($ERRORS{'DEBUG'}, 0, "first argument is a scalar, should be the computer name: $computer_name, remaining arguments:\n" . format_data(\@_));
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "first argument should be the command:\n" . format_data(\@_));
		}
		
		# Get the remaining arguments
		($command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password, $identity_key, $ignore_error) = @_;
	}
	
	if (!$computer_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name could not be determined");
		return;
	}
	if (!$command) {
		notify($ERRORS{'WARNING'}, 0, "command argument was not specified");
		return;
	}
	
	# Determine which string to use as the connection target
	my $remote_connection_target = determine_remote_connection_target($computer_name);
	my $computer_string = $computer_name;
	$computer_string .= " ($remote_connection_target)" if ($remote_connection_target ne $computer_name);
	
	$display_output = 0 unless $display_output;
	$timeout_seconds = 60 unless $timeout_seconds;
	$max_attempts = 3 unless $max_attempts;
	
	# If 'ssh_user' key is set in this object, use it
	# This allows OS modules to specify the username to use
	if ($self && $self->{ssh_user}) {
		#notify($ERRORS{'DEBUG'}, 0, "\$self->{ssh_user} is defined: $self->{ssh_user}");
		$user = $self->{ssh_user};
	}
	elsif (!$port) {
		$user = 'root';
	}
	
	# If 'ssh_port' key is set in this object, use it
	# This allows OS modules to specify the port to use
	if ($self && $self->{ssh_port}) {
		#notify($ERRORS{'DEBUG'}, 0, "\$self->{ssh_port} is defined: $self->{ssh_port}");
		$port = $self->{ssh_port};
	}
	elsif (!$port) {
		$port = 22;
	}
	
	my $ssh_options = '-o StrictHostKeyChecking=no -o ConnectTimeout=30 -x';
	
	# Figure out which identity key to use
	# If identity key argument was supplied, it may be a single path or a comma-separated list
	# If argument was not supplied, get the default management node paths
	my @identity_key_paths;
	if ($identity_key) {
		@identity_key_paths = split(/\s*[,;]\s*/, $identity_key);
	}
	else {
		@identity_key_paths = VCL::DataStructure::get_management_node_identity_key_paths();
	}
	for my $identity_key_path (@identity_key_paths) {
		$ssh_options .= " -i $identity_key_path";
	}
	
	# Override the die handler
	local $SIG{__DIE__} = sub{};
	
	my $ssh;
	my $attempt = 0;
	my $attempt_delay = 5;
	my $attempt_string = '';
	
	ATTEMPT: while ($attempt < $max_attempts) {
		if ($attempt > 0) {
			$attempt_string = "attempt $attempt/$max_attempts: ";
			$ssh->close() if $ssh;
			delete $ENV{net_ssh_expect}{$remote_connection_target};
			
			notify($ERRORS{'DEBUG'}, 0, $attempt_string . "sleeping for $attempt_delay seconds before making next attempt");
			sleep $attempt_delay;
		}
		
		$attempt++;
		$attempt_string = "attempt $attempt/$max_attempts: " if ($attempt > 1);
		
		# Calling 'return' in the EVAL block doesn't exit this subroutine
		# Use a flag to determine if null should be returned without making another attempt
		my $return_null;
		
		if (!$ENV{net_ssh_expect}{$remote_connection_target}) {
			eval {
				my $expect_options = {
					host => $remote_connection_target,
					user => $user,
					port => $port,
					raw_pty => 1,
					no_terminal => 1,
					ssh_option => $ssh_options,
					#timeout => 5,
				};
				
				$ssh = Net::SSH::Expect->new(%$expect_options);
				if ($ssh) {
					notify($ERRORS{'DEBUG'}, 0, "created " . ref($ssh) . " object to control $computer_string, options:\n" . format_data($expect_options));
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to create Net::SSH::Expect object to control $computer_string, $!, options:\n" . format_data($expect_options));
					next ATTEMPT;
				}
				
				if (!$ssh->run_ssh()) {
					notify($ERRORS{'WARNING'}, 0, ref($ssh) . " object failed to fork SSH process to control $computer_string, $!, options:\n" . format_data($expect_options));
					next ATTEMPT;
				}
				
				#sleep_uninterrupted(1);
				
				#$ssh->exec("stty -echo");
				#$ssh->exec("stty raw -echo");
				
				# Set the timeout counter behaviour:
				# If true, sets the timeout to "inactivity timeout"
				# If false sets it to "absolute timeout"
				$ssh->restart_timeout_upon_receive(1);
				my $initialization_output = $ssh->read_all();
				if (defined($initialization_output)) {
					notify($ERRORS{'DEBUG'}, 0, "SSH initialization output:\n$initialization_output") if ($display_output);
					if ($initialization_output =~ /password:/i) {
						if (defined($password)) {
							notify($ERRORS{'WARNING'}, 0, "$attempt_string unable to connect to $computer_string, SSH is requesting a password but password authentication is not implemented, password is configured, output:\n$initialization_output");
							
							# In EVAL block here, 'return' won't return from entire subroutine, set flag
							$return_null = 1;
							return;
						}
						else {
							notify($ERRORS{'WARNING'}, 0, "$attempt_string unable to connect to $computer_string, SSH is requesting a password but password authentication is not implemented, password is not configured, output:\n$initialization_output");
							$return_null = 1;
							return;
						}
					}
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, $attempt_string . "SSH initialization output is undefined") if ($display_output);
				}
			};
			
			return if ($return_null);
			if ($EVAL_ERROR) {
				if ($EVAL_ERROR =~ /^(\w+) at \//) {
					notify($ERRORS{'DEBUG'}, 0, $attempt_string . "$1 error occurred initializing Net::SSH::Expect object for $computer_string") if ($display_output);
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, $attempt_string . "$EVAL_ERROR error occurred initializing Net::SSH::Expect object for $computer_string") if ($display_output);
				}
				next ATTEMPT;
			}
		}
		else {
			$ssh = $ENV{net_ssh_expect}{$remote_connection_target};
			
			# Delete the stored SSH object to make sure it isn't saved if the command fails
			# The SSH object will be added back to %ENV if the command completes successfully
			delete $ENV{net_ssh_expect}{$remote_connection_target};
		}
		
		# Set the timeout
		$ssh->timeout($timeout_seconds);
		
		(my $command_formatted = $command) =~ s/\s+(;|&|&&)\s+/\n$1 /g;
		notify($ERRORS{'DEBUG'}, 0, $attempt_string . "executing command on $computer_string (timeout: $timeout_seconds seconds):\n$command_formatted") if ($display_output);
		my $command_start_time = time;
		$ssh->send($command . ' 2>&1 ; echo exitstatus:$?');
		
		my $ssh_wait_status;
		eval {
			$ssh_wait_status = $ssh->waitfor('exitstatus:[0-9]+', $timeout_seconds);
		};
		
		if ($EVAL_ERROR) {
			if ($ignore_error) {
				notify($ERRORS{'DEBUG'}, 0, "executed command on $computer_string: '$command', ignoring error, returning null") if ($display_output);
				return;
			}
			elsif ($EVAL_ERROR =~ /^(\w+) at \//) {
				notify($ERRORS{'WARNING'}, 0, $attempt_string . "$1 error occurred executing command on $computer_string: '$command'") if ($display_output);
			}
			else {
				notify($ERRORS{'WARNING'}, 0, $attempt_string . "error occurred executing command on $computer_string: '$command'\nerror: $EVAL_ERROR") if ($display_output);
			}
			next ATTEMPT;
		}
		elsif (!$ssh_wait_status) {
			notify($ERRORS{'WARNING'}, 0, $attempt_string . "command timed out after $timeout_seconds seconds on $computer_string: '$command'") if ($display_output);
			next ATTEMPT;
		}
		
		# Need to fix this:
		#2012-09-25 16:15:57|executing command on blade1a3-2 (timeout: 7200 seconds):
		#2012-09-25 16:16:24|23464|1915857:2002452|image|OS.pm:execute_new(2243)|error
		#SSHConnectionError Reading error type 4 found: 4:Interrupted system call at /usr/local/vcl/bin/../lib/VCL/Module/OS.pm line 2231
		
		my $output = $ssh->before() || '';
		$output =~ s/(^\s+)|(\s+$)//g;
		
		my $exit_status_string = $ssh->match() || '';
		my ($exit_status) = $exit_status_string =~ /(\d+)/;
		if (!$exit_status_string || !defined($exit_status)) {
			my $all_output = $ssh->read_all() || '';
			notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to determine exit status from string: '$exit_status_string', output:\n$all_output");
			next ATTEMPT;
		}
		
		my @output_lines = split(/\n/, $output);
		map { s/[\r]+//g; } (@output_lines);
		
		notify($ERRORS{'OK'}, 0, "executed command on $computer_string: '$command', exit status: $exit_status, output:\n$output") if ($display_output);
		
		# Save the SSH object for later use
		$ENV{net_ssh_expect}{$remote_connection_target} = $ssh;
		
		return ($exit_status, \@output_lines);
	}
	
	notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to execute command on $computer_string: '$command'") if ($display_output);
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_os_type

 Parameters  : None
 Returns     : If successful: string
               If failed: false
 Description : Determines the OS type currently installed on the computer. It
               returns 'windows', 'linux', or 'linux-ubuntu'.

=cut

sub get_os_type {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer node name
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	my $command = 'uname -a';
	my ($exit_status, $output) = $self->execute($command,0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine OS type currently installed on $computer_node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine OS type currently installed on $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/ubuntu/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "Ubuntu Linux OS is currently installed on $computer_node_name, output:\n" . join("\n", @$output));
		return 'linux-ubuntu';
	}
	elsif (grep(/linux/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "Linux OS is currently installed on $computer_node_name, output:\n" . join("\n", @$output));
		return 'linux';
	}
	elsif (grep(/win/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "Windows OS is currently installed on $computer_node_name, output:\n" . join("\n", @$output));
		return 'windows';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine OS type currently installed on $computer_node_name, the '$command' output does not contain 'win' or 'linux':\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_os_perl_package

 Parameters  : $computer_identifier (optional), $suppress_warning (optional)
 Returns     : string
 Description : Attempts to determine the Perl package which should be used to
               control the computer.

=cut

sub get_os_perl_package {
	my $argument = shift;
	
	my $self;
	my $computer_identifier;
	
	my $argument_type = ref($argument);
	if ($argument_type) {
		if ($argument->isa('VCL::Module')) {
			$self = $argument;
			$computer_identifier = shift || $self->data->get_computer_id();
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "invalid first argument type: $argument_type, it must either be a reference to a VCL::Module object or a scalar representing the computer identifier");
			return;
		}
	}
	else {
		$computer_identifier = $argument;
	}
	if (!$computer_identifier) {
		notify($ERRORS{'WARNING'}, 0, "computer identifier argument not specified");
		return;
	}
	
	my $suppress_warning = shift;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to determine Perl package name to use for OS currently loaded on computer: $computer_identifier");
	
	my $os;
	
	# Try to avoid creating a separate OS object
	# Check if called by $self-> and if $self's DataStructure matches computer identifier
	if ($self && $self->isa('VCL::Module::OS') && $self->data()) {
		my $self_computer_short_name = $self->data->get_computer_short_name();
		if ($self->data->get_computer_id() eq $computer_identifier || $computer_identifier =~ /^$self_computer_short_name/) {
			$os = $self;
		}
	}
	if (!$os) {
		$os = VCL::Module::create_object('VCL::Module::OS::Windows', { computer_identifier => $computer_identifier});
		if (!$os) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine perl package to use for OS installed on $computer_identifier, OS object could not be created");
			return;
		}
	}
	
	my $command = "uname -a";
	my ($exit_status, $output) = $os->execute({
		command => $command,
		max_attempts => 1,
		display_output => 0,
	});
	if (!defined($output)) {
		if ($suppress_warning) {
			notify($ERRORS{'DEBUG'}, 0, "unable to determine OS installed on computer $computer_identifier, computer may not be responding");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine OS installed on $computer_identifier");
		}
		return;
	}
	
	my $os_perl_package;
	if (grep(/Cygwin/i, @$output)) {
		my $windows_os;
		if ($os->isa('VCL::Module::OS::Windows')) {
			$windows_os = $os;
		}
		else {
			$windows_os = VCL::Module::create_object('VCL::Module::OS::Windows', { computer_identifier => $computer_identifier});
			if (!$windows_os) {
				notify($ERRORS{'WARNING'}, 0, "unable to determine perl package to use for OS installed on $computer_identifier, Windows OS object could not be created");
				return;
			}
		}
		$os_perl_package = $windows_os->_get_os_perl_package($os) || return;
	}
	elsif (grep(/Ubuntu/i, @$output)) {
		$os_perl_package = "VCL::Module::OS::Linux::Ubuntu"
	}
	elsif (grep(/Linux/i, @$output)) {
		$os_perl_package = "VCL::Module::OS::Linux"
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine OS installed on $computer_identifier, unsupported output returned from '$command':\n" . join("\n", @$output));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "determined OS Perl package to use for OS installed on computer $computer_identifier: $os_perl_package");
	return $os_perl_package;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_connect_methods

 Parameters  : $remote_ip (optional), $overwrite
 Returns     : boolean
 Description : Processes the connect methods configured for the image revision.

=cut

sub process_connect_methods {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $request_state = $self->data->get_request_state_name();
	my $computer_node_name = $self->data->get_computer_node_name();
	my $nathost_hostname = $self->data->get_nathost_hostname(0);
	my $nathost_public_ip_address = $self->data->get_nathost_public_ip_address(0);
	my $nathost_internal_ip_address = $self->data->get_nathost_internal_ip_address(0);
	
	# Retrieve the connect method info hash
	my $connect_method_info = $self->data->get_connect_methods();
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve connect method info");
		return;
	}
	
	my $remote_ip = shift;
	if (!$remote_ip) {
		notify($ERRORS{'OK'}, 0, "reservation remote IP address is not defined, connect methods will be available from any IP address");
		$remote_ip = '0.0.0.0/0';
	}
	elsif ($remote_ip =~ /any/i) {
		notify($ERRORS{'OK'}, 0, "reservation remote IP address is set to ANY, connect methods will be available from any IP address");
		$remote_ip = '0.0.0.0/0';
	}
	else {
		$remote_ip .= "/24";
	}
	
	my $overwrite = shift;
	if (!$overwrite) {
		notify($ERRORS{'DEBUG'}, 0, "overwrite value was not passed as an argument setting to 0");
		$overwrite = 0;
	}
	
	my $computer_ip_address = $self->get_public_ip_address();
	
	CONNECT_METHOD: for my $connect_method_id (sort keys %{$connect_method_info} ) {
		my $connect_method = $connect_method_info->{$connect_method_id};
		
		my $name            = $connect_method->{name};
		my $description     = $connect_method->{description};
		my $service_name    = $connect_method->{servicename};
		my $startup_script  = $connect_method->{startupscript};
		my $install_script  = $connect_method->{installscript};
		my $disabled        = $connect_method->{connectmethodmap}{disabled};
		
		if ($disabled || $request_state =~ /deleted|timeout/) {
			if ($self->service_exists($service_name)) {
				if (!$self->stop_service($service_name)) {
					notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service for '$name' connect method on $computer_node_name");
				}
			}
			
			# Close the firewall ports
			if ($self->can('disable_firewall_port')) {
				for my $connect_method_port_id (keys %{$connect_method->{connectmethodport}}) {
					my $protocol = $connect_method->{connectmethodport}{$connect_method_port_id}{protocol};
					my $port = $connect_method->{connectmethodport}{$connect_method_port_id}{port};
					if (!$self->disable_firewall_port($protocol, $port, $remote_ip, 1)) {
						notify($ERRORS{'WARNING'}, 0, "failed to close firewall port $protocol/$port on $computer_node_name for $remote_ip $name connect method");
						return;
					}
				}
			}
		}
		else {
			# Attempt to start and configure the connect method
			my $service_started = 0;
			
			# Attempt to start the service if the service name has been defined for the connect method
			if ($service_name) {
				if ($self->service_exists($service_name)) {
					if ($self->start_service($service_name)) {
						$service_started = 1;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service for '$name' connect method on $computer_node_name");
					}
				}
				else {
					notify($ERRORS{'OK'}, 0, "'$service_name' service for '$name' connect method does NOT exist on $computer_node_name, connect method install script is not defined");
				}
			}
			
			# Run the startup script if the service is not started
			if (!$service_started && defined($startup_script)) {
				if (!$self->file_exists($startup_script)) {
					notify($ERRORS{'OK'}, 0, "'$service_name' service startup script for '$name' connect method does not exist on $computer_node_name: $startup_script");
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "attempting to run startup script '$startup_script' for '$name' connect method on $computer_node_name");
					my ($startup_exit_status, $startup_output) = $self->execute($startup_script, 1);
					if (!defined($startup_output)) {
						notify($ERRORS{'WARNING'}, 0, "failed to run command to execute startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script'");
					}
					elsif ($startup_exit_status == 0) {
						notify($ERRORS{'OK'}, 0, "executed startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script', exit status: $startup_exit_status, output:\n" . join("\n", @$startup_output));	
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to execute startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script', exit status: $startup_exit_status, output:\n" . join("\n", @$startup_output));
					}
				}
			}
			
			for my $connect_method_port_id (keys %{$connect_method->{connectmethodport}}) {
				my $protocol = $connect_method->{connectmethodport}{$connect_method_port_id}{protocol};
				my $port = $connect_method->{connectmethodport}{$connect_method_port_id}{port};
				
				# Open the firewall port
				if ($self->can('enable_firewall_port')) {
					if (!$self->enable_firewall_port($protocol, $port, $remote_ip, 1)) {
						notify($ERRORS{'WARNING'}, 0, "failed to open firewall port $protocol/$port on $computer_node_name for $remote_ip $name connect method");
					}
				}
				
				# Configure NAT port forwarding if NAT is being used
				if ($nathost_hostname) {
					my $nat_public_port = $connect_method->{connectmethodport}{$connect_method_port_id}{natport}{publicport};
					if (!defined($nat_public_port)) {
						notify($ERRORS{'WARNING'}, 0, "$computer_node_name is assigned to NAT host $nathost_hostname but connect method info does not contain NAT port information:\n" . format_data($connect_method));
						return;
					}
					elsif (!$self->nathost_os->firewall->nat_add_port_forward($protocol, $nat_public_port, $computer_ip_address, $port)) {
						notify($ERRORS{'WARNING'}, 0, "failed to configure NAT port forwarding on $nathost_hostname for '$name' connect method: $nathost_public_ip_address:$nat_public_port --> $computer_ip_address:$port ($protocol)");
						return;
					}
				}
			}
		}
	}

	return 1;	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_user_connected

 Parameters  : None
 Returns     : If successful: string
               If failed: false
 Description : Determines is user is connected.

=cut

sub is_user_connected {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $user_login_id      = $self->data->get_user_login_id();
	my $connect_methods    = $self->data->get_connect_methods();
	
	if (!$self->can("check_connection_on_port")) {
		notify($ERRORS{'CRITICAL'}, 0, ref($self) . " OS module does not implement check_connection_on_port subroutine");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "checking for connection by $user_login_id on $computer_node_name");
	
	foreach my $connect_method_id (keys %$connect_methods) {
		my $connect_method = $connect_methods->{$connect_method_id};
		my $name = $connect_method->{name};
		
		for my $connect_method_port_id (keys %{$connect_method->{connectmethodport}}) {
			my $protocol = $connect_method->{connectmethodport}{$connect_method_port_id}{protocol};
			my $port = $connect_method->{connectmethodport}{$connect_method_port_id}{port};
			
			notify($ERRORS{'DEBUG'}, 0, "checking '$name' connect method, protocol: $protocol, port: $port");
			my $result = $self->check_connection_on_port($port);
			if ($result && $result !~ /no/i) {
				notify($ERRORS{'OK'}, 0, "$user_login_id is connected to $computer_node_name using $name connect method, result: $result");
				return 1;
			}
		}
	}
	
	notify($ERRORS{'OK'}, 0, "$user_login_id is not connected to $computer_node_name");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_file

 Parameters  : $source_file_path, $destination_file_path
 Returns     : boolean
 Description : Copies a file or directory on the computer to another location on
               the computer.

=cut

sub copy_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path arguments
	my $source_file_path = shift;
	my $destination_file_path = shift;
	if (!$source_file_path || !$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination file path arguments were not specified");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Normalize the source and destination paths
	$source_file_path = normalize_file_path($source_file_path);
	$destination_file_path = normalize_file_path($destination_file_path);
	
	# Escape all spaces in the path
	my $escaped_source_path = escape_file_path($source_file_path);
	my $escaped_destination_path = escape_file_path($destination_file_path);
	
	# Make sure the source and destination paths are different
	if ($escaped_source_path eq $escaped_destination_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy file on $computer_node_name, source and destination file path arguments are the same: $escaped_source_path");
		return;
	}
	
	# Create the destination parent directory if it does not exist
	if ($destination_file_path =~ /[\\\/]/ && $self->can('create_directory')) {
		my $destination_directory_path = parent_directory_path($destination_file_path);
		if ($destination_directory_path) {
			$self->create_directory($destination_directory_path);
		}
	}
	
	# Execute the command to copy the file
	my $command = "cp -fr $escaped_source_path $escaped_destination_path";
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy file on $computer_node_name: '$source_file_path' -> '$destination_file_path'");
	my ($exit_status, $output) = $self->execute($command,0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^cp: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (!@$output || grep(/->/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "copied file on $computer_node_name: '$source_file_path' --> '$destination_file_path'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_file_to

 Parameters  : $source_path, $destination_path
 Returns     : boolean
 Description : Copies file(s) from the management node to the computer.
               Wildcards are allowed in the source path.

=cut

sub copy_file_to {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the source and destination arguments
	my ($source_path, $destination_path) = @_;
	if (!$source_path || !$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination path arguments were not specified");
		return;
	}
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	# Get the destination parent directory path and create the directory
	my $destination_directory_path = parent_directory_path($destination_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_path");
		return;
	}
	$self->create_directory($destination_directory_path) || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the SCP command
	if (run_scp_command($source_path, "$computer_node_name:\"$destination_path\"", $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied file from management node to $computer_node_name: '$source_path' --> $computer_node_name:'$destination_path'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file from management node to $computer_node_name: '$source_path' --> $computer_node_name:'$destination_path'");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_file_from

 Parameters  : $source_path, $destination_path
 Returns     : boolean
 Description : Copies file(s) from the computer to the management node.

=cut

sub copy_file_from {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the source and destination arguments
	my ($source_path, $destination_path) = @_;
	if (!$source_path || !$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination path arguments were not specified");
		return;
	}
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	# Get the destination parent directory path and create the directory
	my $destination_directory_path = parent_directory_path($destination_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_path");
		return;
	}
	$self->mn_os->create_directory($destination_directory_path) || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the SCP command
	if (run_scp_command("$computer_node_name:\"$source_path\"", $destination_path, $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied file from $computer_node_name to management node: $computer_node_name:'$source_path' --> '$destination_path'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file from $computer_node_name to management node: $computer_node_name:'$source_path' --> '$destination_path'");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 find_files

 Parameters  : $base_directory_path, $file_pattern, $search_subdirectories (optional), $type (optional)
 Returns     : array
 Description : Finds files under the base directory and any subdirectories path
               matching the file pattern. The search is not case sensitive. An
               array is returned containing matching file paths.
               
               Subdirectories will be searched if the $search_subdirectories
               argument is true or not supplied.
               
               If the $type argument is supplied, it must be one of the
               following:
                  f - Only search for files (default behavior)
                  d - Only search for directories
                  * - Search for files and directories

=cut

sub find_files {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my ($base_directory_path, $file_pattern, $search_subdirectories, $type) = @_;
	if (!$base_directory_path || !$file_pattern) {
		notify($ERRORS{'WARNING'}, 0, "base directory path and file pattern arguments were not specified");
		return;
	}
	
	$search_subdirectories = 1 if !defined($search_subdirectories);
	
	my $type_string;
	$type = 'f' unless defined $type;
	if ($type =~ /^f$/i) {
		$type = 'f';
		$type_string = 'files';
	}
	elsif ($type =~ /^d$/i) {
		$type = 'd';
		$type_string = 'directories';
	}
	elsif ($type =~ /^\*$/i) {
		$type = undef;
		$type_string = 'files and directories';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unsupported type argument: '$type'");
		return;
	}
	
	# Normalize the arguments
	$base_directory_path = normalize_file_path($base_directory_path);
	$file_pattern = normalize_file_path($file_pattern);
	
	# The base directory path must have a trailing slash or find won't work
	$base_directory_path .= '/';
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	my @find_commands = (
		'/usr/bin/find',
		'find',
	);
	
	COMMAND: for my $find_command (@find_commands) {
		# Run the find command
		my $command = "$find_command \"$base_directory_path\" -iname \"$file_pattern\"";
		$command .= " -type $type" if $type;
		
		if (!$search_subdirectories) {
			$command .= " -maxdepth 1";
		}
		
		#notify($ERRORS{'DEBUG'}, 0, "attempting to find $type_string on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command: $command");
		my ($exit_status, $output) = $self->execute($command, 0);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to find $type_string on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command:\n$command");
			return;
		}
		elsif (grep(/find:.*No such file or directory/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "base directory does not exist on $computer_node_name: $base_directory_path");
			@$output = ();
		}
		elsif (grep(/find: not found/i, @$output)) {
			# /usr/bin/find doesn't exist, try command without the full path
			notify($ERRORS{'DEBUG'}, 0, "'$find_command' command is not present on $computer_node_name");
			next;
		}
		elsif (grep(/find: /i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "error occurred attempting to find $type_string on $computer_node_name\nbase directory path: $base_directory_path\npattern: $file_pattern\ncommand: $command\noutput:\n" . join("\n", @$output));
			return;
		}
		
		my @files;
		LINE: for my $line (@$output) {
			push @files, $line;
		}
		
		my $file_count = scalar(@files);
		
		notify($ERRORS{'DEBUG'}, 0, "$type_string found under $base_directory_path matching pattern '$file_pattern': $file_count");
		#notify($ERRORS{'DEBUG'}, 0, "$type_string found: $file_count, base directory: '$base_directory_path', pattern: '$file_pattern'\ncommand: '$command', output:\n" . join("\n", @$output));
		return @files;
	}
	
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_file_checksum

 Parameters  : $file_path
 Returns     : integer
 Description : Runs chsum on the file specified by the argument and returns the
               checksum of the file.

=cut

sub get_file_checksum {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	
	# Escape $ characters
	$file_path =~ s/([\$])/\\$1/g;
	
	my $command = "cksum \"$file_path\"";
	my ($exit_status, $output) = $self->execute($command,1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine checksum of file: $file_path");
		return;
	}
	elsif (my ($checksum_line) = grep(/^\d+\s+/, @$output)) {
		my ($checksum) = $checksum_line =~ /^(\d+)/;
		#notify($ERRORS{'DEBUG'}, 0, "determined checksum of file '$file_path': $checksum");
		return $checksum;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output in cksum output, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_tools_file_paths

 Parameters  : $pattern (optional)
 Returns     : boolean
 Description : Scans the tools directory on the management node for any files
               which are intended for the OS of the reservation image. The OS
               name and architecture are considered. A list of file paths on the
               reservation computer is returned.
               
               Files intended for the reservation image are synchronized from
               the management node. Any files which don't exist on the
               reservation computer are copied. Files which exist on the
               computer but are different than the file on the management node
               are replaced. Files which exist on the computer but not on the
               management node are ignored.
               
               A pattern argument can be supplied to limit the results. For
               example, to only return driver files supply '/Drivers/' as the
               argument. To only return script files intended to for the
               post_load stage, supply '/Scripts/post_load' as the argument.
               
               The list of files returned is sorted by the names of the files,
               regardless of the directory where they reside. Files can be named
               beginning with a number. This list returned is sorted numerically
               from the lowest number to the highest:
               -1.cmd
               -50.cmd
               -100.cmd
               
               File names which do not begin with a number are sorted
               alphabetically and listed after any files beginning with a
               number:
               -1.cmd
               -50.cmd
               -100.cmd
               -Blah.cmd
               -foo.cmd

=cut

sub get_tools_file_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module:: module object method");
		return;
	}
	
	my $pattern = shift || '.*';
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my @source_configuration_directories = $self->get_source_configuration_directories();
	if (!@source_configuration_directories) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve source configuration directories");
		return;
	}
	
	my $architecture = $self->is_64_bit() ? 'x86_64' : 'x86';
	my $other_architecture = $self->is_64_bit() ? 'x86' : 'x86_64';
	
	notify($ERRORS{'DEBUG'}, 0, "attempting for find tools files:\npattern: $pattern\narchitecture: $architecture\nother architecture: $other_architecture");
	
	# Find files already on the computer
	my $computer_directory_path = $self->get_node_configuration_directory();
	my @existing_computer_file_array = $self->find_files($computer_directory_path, '*');
	my %existing_computer_files = map { $_ => 1 } @existing_computer_file_array;

	my %computer_tools_file_paths;
	
	# Loop through the directories on the management node
	DIRECTORY: for my $source_configuration_directory (@source_configuration_directories) {
		# Find script files on the managment node intended for the computer
		my $mn_directory_path = "$source_configuration_directory";
		my @mn_directory_files = $self->mn_os->find_files($mn_directory_path, '*');
		
		# Loop through the files found on the management node
		MN_FILE: for my $mn_file_path (@mn_directory_files) {
			
			# Ignore files not matching the pattern argument, Subversion files, and files intended for another architecture
			if ($pattern && $mn_file_path !~ /$pattern/i) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring file, it does not match pattern '$pattern': $mn_file_path");
				next MN_FILE;
			}
			elsif ($mn_file_path =~ /\/\.svn\//i) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring Subversion file: $mn_file_path");
				next MN_FILE;
			}
			elsif ($mn_file_path =~ /\/$other_architecture\//) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring file intended for different computer architecture: $mn_file_path");
				next MN_FILE;
			}
			
			my ($relative_file_path) = $mn_file_path =~ /$mn_directory_path\/(.+)/;
			my $computer_file_path = "$computer_directory_path/$relative_file_path";
			
			# Add the computer file path to the list that will be returned
			$computer_tools_file_paths{$computer_file_path} = 1;
			
			# Check if the file already exists on the computer
			notify($ERRORS{'DEBUG'}, 0, "checking if file on management node needs to be copied to $computer_node_name: $mn_file_path");
			if ($existing_computer_files{$computer_file_path}) {
				
				# Check if existing file on computer is identical to file on managment node
				# Retrieve the checksums
				my $mn_file_checksum = $self->mn_os->get_file_checksum($mn_file_path);
				my $computer_file_checksum = $self->get_file_checksum($computer_file_path);
				
				# Check if the file already on the computer is exactly the same as the one on the MN by comparing checksums
				if ($mn_file_checksum && $computer_file_checksum && $computer_file_checksum eq $mn_file_checksum) {
					notify($ERRORS{'DEBUG'}, 0, "identical file exists on $computer_node_name: $computer_file_path");
					next MN_FILE;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "file exists on $computer_node_name but checksum is different: $computer_file_path\n" .
						"MN file checksum: " . ($mn_file_checksum || '<unknown>') . "\n" .
						"computer file checksum: " . ($computer_file_checksum || '<unknown>')
					);
				}
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "file does not exist on $computer_node_name: $computer_file_path");
			}
			
			# File either doesn't already exist on the computer or file on computer is different than file on MN
			if (!$self->copy_file_to($mn_file_path, $computer_file_path)) {
				notify($ERRORS{'WARNING'}, 0, "file could not be copied from management node to $computer_node_name: $mn_file_path --> $computer_file_path");
				return;
			}
		}
	}

	my @return_files = sort_by_file_name(keys %computer_tools_file_paths);
	notify($ERRORS{'DEBUG'}, 0, "determined list of tools files intended for $computer_node_name, pattern: $pattern, architecture: $architecture:\n" . join("\n", @return_files));
	return @return_files;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_fixed_ip_info

 Parameters  : 
 Returns     : 1, 0 
 Description : checks for variables in variable table related to fixedIP information for server reservations

=cut

sub update_fixed_ip_info {

	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
	  notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module:: module object method");
	  return;
	}
	
	my $server_request_id           = $self->data->get_server_request_id();
	if (!$server_request_id) {
		notify($ERRORS{'WARNING'}, 0, "Server request id not set.");
		return;
	}

	my $variable_name = "fixedIPsr" . $server_request_id; 	
	my $server_variable_data;

	if (is_variable_set($variable_name)) {
		#fetch variable
		$server_variable_data  = get_variable($variable_name);
		
		notify($ERRORS{'DEBUG'}, 0, "data is set for $variable_name" . format_data($server_variable_data));
		
		my $router = $server_variable_data->{router};
		my $netmask = $server_variable_data->{netmask};
		my @dns = @{$server_variable_data->{dns}};
		
		notify($ERRORS{'OK'}, 0, "updated data server request router info") if ($self->data->set_server_request_router($server_variable_data->{router}));
		notify($ERRORS{'OK'}, 0, "updated data server request netmask info") if ($self->data->set_server_request_netmask($server_variable_data->{netmask}));
		notify($ERRORS{'OK'}, 0, "updated data server request dns info") if ($self->data->set_server_request_dns_servers(@{$server_variable_data->{dns}}));
		notify($ERRORS{'DEBUG'}, 0, "router= $router, netmask= $netmask, dns= @dns");
		
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "data is not set for $variable_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////
=head2 get_timings

   Parameters  : $self
   Returns     : integer
   Description : Check for cached information or pulls from variable table
   Acceptable variables are:
      acknowledgetimeout
      initialconnecttimeout
      reconnecttimeout
      general_inuse_check
      server_inuse_check
      general_end_notice_first
      general_end_notice_second
      ignore_connections_gte

=cut

sub get_timings {
	my $self = shift;
	my $variable = shift;
	my $affiliation_name = $self->data->get_user_affiliation_name(0);

	my %timing_defaults = (
		acknowledgetimeout => '900',
		initialconnecttimeout => '900',
		reconnecttimeout => '900',
		general_inuse_check => '300',
		server_inuse_check => '900',
		cluster_inuse_check => '900',
		general_end_notice_first => '600',
		general_end_notice_second => '300',
		ignore_connections_gte => '1440'
	);
	
	if (!defined($variable)) {
		notify($ERRORS{'WARNING'}, 0, "input variable argument was not supplied, returning default value: 900");
		return '900';
	}
	elsif (!defined($timing_defaults{$variable})) {
		notify($ERRORS{'WARNING'}, 0, "input variable '$variable' is not supported, returning default value: 900");
		return '900';
	}
	
	my $db_timing_variable_value;
	if ($db_timing_variable_value = get_variable("$variable|$affiliation_name", 0)) {
		notify($ERRORS{'DEBUG'}, 0, "retreived $affiliation_name affiliation specific $variable variable: $db_timing_variable_value");
	}
	elsif ($db_timing_variable_value = get_variable("$variable", 0)) {
		notify($ERRORS{'DEBUG'}, 0, "retreived non-affiliation specific $variable variable: $db_timing_variable_value");
	}
	else {
		$db_timing_variable_value = $timing_defaults{$variable};
		notify($ERRORS{'DEBUG'}, 0, "$variable is not defined in the database, returning default value: $db_timing_variable_value");
	}
	return $db_timing_variable_value;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_stage_scripts

Parameters  : $stage
 Returns     : boolean
 Description : Runs scripts on both the management node and computer intended
               for the reservation stage specified by the argument. Management
               node scripts are executed first.

=cut

sub run_stage_scripts {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the stage argument
	my $stage = shift;
	if (!$stage) {
		notify($ERRORS{'WARNING'}, 0, "stage argument was not supplied");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to execute custom scripts for '$stage' stage if any exist");
	
	my $computer_result = $self->run_stage_scripts_on_computer($stage);
	my $management_node_result = $self->mn_os->run_stage_scripts_on_management_node($stage);
	return $computer_result && $management_node_result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_stage_scripts_on_computer

 Parameters  : $stage
 Returns     : boolean
 Description : Runs scripts on the computer intended for the state specified by
               the argument. The stage argument may be any of the following:
               * post_load
					* post_reserve
					* post_initial_connection
					* post_reservation
					* pre_reload
					* pre_capture
               
               Scripts are stored in various directories under tools matching
               the OS of the image being loaded. For example, scripts residing
               in any of the following directories would be executed if the
               stage argument is 'post_load' and the OS of the image being
               loaded is Windows XP 32-bit:
               * tools/Windows/Scripts/post_load
               * tools/Windows/Scripts/post_load/x86
               * tools/Windows_Version_5/Scripts/post_load
               * tools/Windows_Version_5/Scripts/post_load/x86
               * tools/Windows_XP/Scripts/post_load
               * tools/Windows_XP/Scripts/post_load/x86
               
               The order the scripts are executed is determined by the script
               file names. The directory where the script resides has no affect
               on the order. Script files can be named beginning with a number.
               The scripts sorted numerically and processed from the lowest
               number to the highest:
               * 1.cmd
               * 50.cmd
               * 100.cmd
               
               Scripts which do not begin with a number are sorted
               alphabetically and processed after any scripts which begin with a
               number:
               * 1.cmd
               * 50.cmd
               * 100.cmd
               * Blah.cmd
               * foo.cmd

=cut

sub run_stage_scripts_on_computer {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the stage argument
	my $stage = shift;
	if (!$stage) {
		notify($ERRORS{'WARNING'}, 0, "stage argument was not supplied");
		return;
	}
	
	my $computer_stages = {
		'post_capture' => 0,
		'post_initial_connection' => 1,
		'post_load' => 1,
		'post_reservation' => 1,
		'post_reserve' => 1,
		'pre_capture' => 1,
		'pre_reload' => 1,
	};
	
	if (!defined($computer_stages->{$stage})) {
		notify($ERRORS{'WARNING'}, 0, "invalid stage argument was supplied: $stage");
		return;
	}
	elsif (!$computer_stages->{$stage}) {
		notify($ERRORS{'DEBUG'}, 0, "'$stage' stage scripts are not supported to be run on a computer");
		return 1;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $image_name = $self->data->get_image_name();
	
	if (!$self->can('run_script')) {
		notify($ERRORS{'DEBUG'}, 0, "custom $stage scripts not executed on $computer_node_name, " . ref($self) . " module does not implement a 'run_script' subroutine");
		return 1;
	}
	
	# Loop through all tools files on the computer
	my @failed_file_paths;
	my @computer_tools_files = $self->get_tools_file_paths("/Scripts/$stage/");
	if (!@computer_tools_files) {
		notify($ERRORS{'DEBUG'}, 0, "no custom scripts reside on this management node for $image_name");
		return 1;
	}
	
	# If post_reserve script exists, assume it does user or reservation-specific actions
	# If the user never connects and the reservation times out, there's no way to revert these actions in order to clean the computer for another user
	# Tag the image as tainted so it is reloaded
	if ($stage =~ /(post_reserve)/) {
		$self->set_tainted_status('post-reserve scripts residing on the management node executed');
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to execute custom scripts residing on the management node for $image_name on $computer_node_name:\n" . join("\n", @computer_tools_files));
	for my $computer_tools_file_path (@computer_tools_files) {
		notify($ERRORS{'DEBUG'}, 0, "executing script on $computer_node_name: $computer_tools_file_path");
		if (!$self->run_script($computer_tools_file_path)) {
			push @failed_file_paths, $computer_tools_file_path;
		}
	}
	
	# Check if any scripts failed
	if (@failed_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "failed to run the following scripts on $computer_node_name, stage: $stage\n" . join("\n", @failed_file_paths));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_connect_method_remote_ip_addresses

 Parameters  : none
 Returns     : array
 Description : Retrieves the current connection information from the computer
               and compares it to the connect methods configured for the
               reservation image revision. An array is returned containing the
               remote IP addresses for connections which match any of the
               protocols and ports configured for any connect method.
               
               Remote connections which match the management node's private or
               public IP address are ignored.
               
               The ignored_remote_ip_addresses variable may be configured in the
               database. This list should contain IP addresses or regular
               expressions and may be deliminated by commas, semicolons, or
               spaces. Any remote connections from an IP address in this list
               will also be ignored. This may be used to exclude hosts other
               than those a user may connect from which may have periodic
               or a persistent connection -- such as a monitoring host.

=cut

sub get_connect_method_remote_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Make sure a get_connection_info subroutine is implemented
	if (!$self->can('get_port_connection_info')) {
		notify($ERRORS{'WARNING'}, 0, "OS module does not implement a get_port_connection_info subroutine");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Get the management node's IP addresses - these will be ignored
	# TODO: change to get_ip_addresses
	my $mn_private_ip_address = $self->mn_os->get_private_ip_address();
	my $mn_public_ip_address = $self->mn_os->get_public_ip_address();
	
	# Get the ignored remote IP address variable from the database if it is configured
	my $ignored_remote_ip_address_string = get_variable('ignored_remote_ip_addresses') || '';
	my @ignored_remote_ip_addresses = split(/[,; ]+/, $ignored_remote_ip_address_string);
	notify($ERRORS{'DEBUG'}, 0, "connections to $computer_node_name from any of the following IP addresses will be ignored: " . join(', ', @ignored_remote_ip_addresses)) if (@ignored_remote_ip_addresses);
	
	my $connection_info = $self->get_port_connection_info();
	if (!defined($connection_info)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve connection info from $computer_node_name");
		return;
	}
	
	my @remote_ip_addresses = ();
	
	my $connect_method_info = $self->data->get_connect_methods();
	for my $connect_method_id (keys %$connect_method_info) {
		my $connect_method_name = $connect_method_info->{$connect_method_id}{name};
		
		for my $connect_method_port_id (sort keys %{$connect_method_info->{$connect_method_id}{connectmethodport}}) {
			my $connect_method_protocol = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{protocol};
			my $connect_method_port = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{port};
			
			notify($ERRORS{'DEBUG'}, 0, "checking connect method: '$connect_method_name', protocol: $connect_method_protocol, port: $connect_method_port");
			
			CONNECTION_PROTOCOL: for my $connection_protocol (keys %$connection_info) {
				# Check if the protocol defined for the connect method matches the established connection
				if (!$connect_method_protocol || $connect_method_protocol =~ /(\*|any|all)/i) {
					#notify($ERRORS{'DEBUG'}, 0, "skipping validation of connect method protocol: $connect_method_protocol");
				}
				else {
					if ($connect_method_protocol =~ /$connection_protocol/i || $connection_protocol =~ /$connect_method_protocol/i) {
						notify($ERRORS{'DEBUG'}, 0, "connect method protocol matches established connection protocol: $connection_protocol");
					}
					else {
						notify($ERRORS{'DEBUG'}, 0, "connect method protocol $connect_method_protocol does NOT match established connection protocol $connection_protocol");
						next CONNECTION_PROTOCOL;
					}
				}
				
				CONNECTION_PORT: for my $connection_port (keys %{$connection_info->{$connection_protocol}}) {
					# Check if the port defined for the connect method matches the established connection
					if ($connect_method_port eq $connection_port) {
						notify($ERRORS{'DEBUG'}, 0, "connect method port matches established connection port: $connection_port");
						
						for my $connection (@{$connection_info->{$connection_protocol}{$connection_port}}) {
							my $remote_ip_address = $connection->{remote_ip};
							if (!$remote_ip_address) {
								notify($ERRORS{'WARNING'}, 0, "connection does NOT contain remote IP address (remote_ip) key:\n" . format_data($connection));
							}
							elsif ($remote_ip_address eq $mn_private_ip_address || $remote_ip_address eq $mn_public_ip_address) {
								notify($ERRORS{'DEBUG'}, 0, "ignoring connection to port $connection_port from management node: $remote_ip_address");
							}
							elsif (my ($ignored_remote_ip_address) = grep { $remote_ip_address =~ /($_)/ } @ignored_remote_ip_addresses) {
								notify($ERRORS{'DEBUG'}, 0, "ignoring connection to port $connection_port from ignored remote IP address ($ignored_remote_ip_address): $remote_ip_address");
							}
							else {
								push @remote_ip_addresses, $remote_ip_address;
							}
						}
					}
					else {
						notify($ERRORS{'DEBUG'}, 0, "connect method port $connect_method_port does NOT match established connection port $connection_port");
						next CONNECTION_PORT;
					}
				}
			}
		}
	}
	
	if (@remote_ip_addresses) {
		@remote_ip_addresses = remove_array_duplicates(@remote_ip_addresses);
		notify($ERRORS{'OK'}, 0, "detected connection to $computer_node_name using the ports and protocols configured for the connect methods, remote IP address(es): " . join(', ', @remote_ip_addresses));
		return @remote_ip_addresses;
	}
	else {
		notify($ERRORS{'OK'}, 0, "connection NOT established to $computer_node_name using the ports and protocols configured for the connect methods");
		return ();
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_compare_update

 Parameters  : none
 Returns     : boolean
 Description : Updates the firewall to allow traffic to the address stored in
               reservation remoteIP for each connection method.

=cut

sub firewall_compare_update {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $remote_ip = $self->data->get_reservation_remote_ip();
	if (!$remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "unable to update firewall on $computer_node_name, remote IP could not be retrieved for reservation");
		return;
	}
	
	if ($self->can('firewall') && $self->firewall->can('process_inuse')) {
		return $self->firewall->process_inuse($remote_ip);
	}
	
	# Make sure the OS module implements get_firewall_configuration and enable_firewall_port subroutine
	unless ($self->can('enable_firewall_port') && $self->can('get_firewall_configuration')) {
		return 1;
	}
	
	# Retrieve the connect method info
	my $connect_method_info = $self->data->get_connect_methods();
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve connect method info");
		return;
	}
	
	# Retrieve the firewall configuration from the computer
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	
	# Loop through the connect methods, check to make sure firewall is open for remote IP
	my $error_encountered = 0;
	for my $connect_method_id (sort keys %$connect_method_info) {
		my $connect_method_name = $connect_method_info->{$connect_method_id}{name};
		
		for my $connect_method_port_id (sort keys %{$connect_method_info->{$connect_method_id}{connectmethodport}}) {
			my $connect_method_port = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id};
			my $protocol = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{protocol};
			my $port = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{port};
			
			if ($self->enable_firewall_port($protocol, $port, $remote_ip, 0)) {
				notify($ERRORS{'DEBUG'}, 0, "$connect_method_name: processed firewall port $protocol $port on $computer_node_name for remote IP address: $remote_ip");
			}
			else {
				$error_encountered = 1;
				notify($ERRORS{'WARNING'}, 0, "$connect_method_name: failed to process firewall port $protocol $port on $computer_node_name for remote IP address: $remote_ip");
			}
		}
	}
	return !$error_encountered;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_cluster

 Parameters  :data hash 
 Returns     : 0 or 1
 Description : creates or updates the cluster_info file
               updates firewall so each node can communicate

=cut

sub update_cluster {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $current_reservation_id = $self->data->get_reservation_id();
	my @reservation_ids = $self->data->get_reservation_ids();
	my @child_reservation_ids = $self->data->get_child_reservation_ids();
	my $parent_reservation_id = $self->data->get_parent_reservation_id();
	my $computer_short_name = $self->data->get_computer_short_name();
	
	my $cluster_info_file_path = $self->get_cluster_info_file_path();
	my $cluster_info_string = '';
	
	my @public_ip_addresses;
	
	for my $cluster_reservation_id (@reservation_ids) {
		# Get a DataStructure object for each reservation
		my $reservation_data;
		if ($cluster_reservation_id eq $current_reservation_id) {
			$reservation_data = $self->data();
		}
		else {
			$reservation_data = $self->data->get_reservation_data($cluster_reservation_id);
		}
		if (!$reservation_data) {
			notify($ERRORS{'WARNING'}, 0, "failed to update cluster request, data could not be retrieved for reservation $cluster_reservation_id");
			return;
		}
		
		# Get the computer IP address
		my $cluster_computer_public_ip_address = $reservation_data->get_computer_public_ip_address();
		if (!$cluster_computer_public_ip_address) {
			notify($ERRORS{'WARNING'}, 0, "failed to update cluster request, public IP address could not be retrieved for computer assigned to reservation $cluster_reservation_id");
			return;
		}
		
		# Add the public IP address to the array for reservations not matching the reservation ID currently being processed
		if ($cluster_reservation_id ne $current_reservation_id) {
			push @public_ip_addresses, $cluster_computer_public_ip_address;
		}
		
		# Add a line to cluster_info string for each reservation
		if ($cluster_reservation_id eq $parent_reservation_id) {
			$cluster_info_string .= "parent= ";
		}
		else {
			$cluster_info_string .= "child= ";
		}
		$cluster_info_string .= "$cluster_computer_public_ip_address\n";
	}
	
	# Create the cluster_info file on the computer
	if ($self->create_text_file($cluster_info_file_path, $cluster_info_string)) {
		notify($ERRORS{'DEBUG'}, 0, "created $cluster_info_file_path on $computer_short_name:\n$cluster_info_string");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create $cluster_info_file_path on $computer_short_name");
		return;
	}
	
	# Call the OS firewall module's process_cluster if available
	if ($self->can('firewall') && $self->firewall->can('process_cluster')) {
		return $self->firewall->process_cluster();
	}
	
	# Open the firewall allowing other cluster reservations computers access
	if (@public_ip_addresses && $self->can('enable_firewall_port')) {
		my $firewall_scope = join(",", @public_ip_addresses);
		notify($ERRORS{'DEBUG'}, 0, "attempting to open the firewall on $computer_short_name to allow access from other cluster reservation computers: $firewall_scope");
		
		if (!$self->enable_firewall_port("tcp", "any", $firewall_scope, 0)) {
			notify($ERRORS{'WARNING'}, 0, "failed to open the firewall on $computer_short_name to allow access from other cluster reservation computers via TCP: $firewall_scope");
		}
		
		if (!$self->enable_firewall_port("udp", "any", $firewall_scope, 0)) {
			notify($ERRORS{'WARNING'}, 0, "failed to open the firewall on $computer_short_name to allow access from other cluster reservation computers via UDP: $firewall_scope");
		}
	}

	return 1;
} ## end sub update_cluster_info

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cluster_info_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location where the cluster_info files resides on the
               computer: /etc/cluster_info. OS modules such as Windows which use
               a different location should override this subroutine.

=cut

sub get_cluster_info_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return $self->{cluster_info_file_path} if $self->{cluster_info_file_path};
	$self->{cluster_info_file_path} = '/etc/cluster_info';
	notify($ERRORS{'DEBUG'}, 0, "determined cluster_info file path for " . ref($self) . " OS module: $self->{cluster_info_file_path}");
	return $self->{cluster_info_file_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_info_json_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location where the files resides on the computer that
               contains JSON formatted information about the reservation. For
               Linux computers, the location is /root/reservation_info.json.

=cut

sub get_reservation_info_json_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return $self->{reservation_info_json_file_path} if $self->{reservation_info_json_file_path};
	$self->{reservation_info_json_file_path} = '/root/reservation_info.json';
	notify($ERRORS{'DEBUG'}, 0, "determined reservation info JSON file path file path for " . ref($self) . " OS module: $self->{reservation_info_json_file_path}");
	return $self->{reservation_info_json_file_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_reservation_info_json_file

 Parameters  : none
 Returns     : boolean
 Description : Creates a text file on the computer containing reservation data
               in JSON format.

=cut

sub create_reservation_info_json_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $json_file_path = $self->get_reservation_info_json_file_path() || return;
	my $json_string = $self->data->get_reservation_info_json_string() || return;
	$self->create_text_file($json_file_path, $json_string) || return;
	
	if ($self->can('set_file_permissions')) {
		$self->set_file_permissions($json_file_path, '600');
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_reservation_info_json_file

 Parameters  : none
 Returns     : boolean
 Description : Deletes the text file on the computer containing reservation data
					in JSON format. This is important when sanitizing a computer.

=cut

sub delete_reservation_info_json_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $json_file_path = $self->get_reservation_info_json_file_path() || return;
	return $self->delete_file($json_file_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 mount_nfs_shares

 Parameters  : none
 Returns     : boolean
 Description : Checks if a 'nfsmount|<managementnode.id>' variable exists in the
               database. If so, it parses the value and attempts to mount one or
               more shares on the reservation computer. There variable value may
               contain substitution components enclosed in square brackets such
               as:
               [user_login_id]
               
               See DataStructure.pm::substitute_string_variables for more
               information.
               
               If the last part of a remote directory specification contains a
               substitution value and the directory could not be mounted on the
               computer because it doesn't exist, the parent remote directory is
               temporarily mounted on the management node in a subdirectory with
               a random name under /tmp. If successfully mounted, a subdirectory
               with a name containing substituted values based on the
               reservation data is created. For example, if the nfsmount
               variable contains:
               /user_data/share/user-[user_login_id]-[user-uid]
               
               A directory should be mounted on the reservation computer named
               something like:
               /user_data/share/user-jdoe-3459
               
               If the user-jdoe-3459 directory does not exist, this subroutine
               will:
               * Attempt to mount /user_data/share on the management node under
                 /tmp
               * Create a subdirectory named 'user-jdoe-3459'
               * If any part of the directory name specification contains a
                 substitution component that includes '[user_*]', the newly
                 created directory's owner is set to the user.uid value in the
                 database and the directory permissions are set to 0700.
               * The directory is unmounted from the management node.
               * The directory under /tmp is deleted
               * The share is mounted on the reservation computer.
               
               This subroutine will currently only attempt to automatically
               create directories if the last component contains a substitution
               component. Substitution components are allowed in the
               intermediate directory path such as:
               /schools/[affiliation_name]/share
               
               However, no attempt will be made to create the
               <[affiliation_name]> directory. It must exist prior to the
               reservation.

=cut

sub mount_nfs_shares {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_id = $self->data->get_management_node_id();
	my $computer_name = $self->data->get_computer_short_name();
	my $user_uid = $self->data->get_user_uid();
	
	# Get the NFS mount information configured for the management node from the variable table
	my $nfsmount_variable_name = "nfsmount|$management_node_id";
	my $nfsmount_variable_value = get_variable($nfsmount_variable_name);
	if (!$nfsmount_variable_value) {
		notify($ERRORS{'DEBUG'}, 0, "'$nfsmount_variable_name' variable is NOT configured for management node $management_node_id");
		return 1;
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved '$nfsmount_variable_name' variable configured for management node: '$nfsmount_variable_value'");
	
	my $error_encountered = 0;
	
	MOUNT_SPECIFICATION: for my $mount_specification (split(/;/, $nfsmount_variable_value)) {
		# Format:
		#    <IP/hostname>:<remote directory>,<local directory>
		# Example:
		#    10.0.0.12:/users/home/[username],/home/[username]
		my ($remote_host, $remote_specification, $local_specification) = $mount_specification =~
			/
				^\s*
				([^:\s]+)             # $remote_host
				\s*:\s*               # :
				(\/[^,]*[^,\s\/])\/?  # $remote_specification
				\s*,\s*               # ,
				(\/.*[^\s\/])\/?      # $local_specification
				\s*$
			/gx;
		if (!defined($remote_host) || !defined($remote_specification) || !defined($local_specification)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to parse mount specification: '$mount_specification'");
			$error_encountered = 1;
			next MOUNT_SPECIFICATION;
		}
		
		# Replace variables in local and remote directory paths
		my $local_substituted = $self->data->substitute_string_variables($local_specification);
		my $remote_substituted = $self->data->substitute_string_variables($remote_specification);
		my $remote_target = "$remote_host:$remote_substituted";
		
		notify($ERRORS{'DEBUG'}, 0, "parsed mount definition: '$mount_specification'\n" .
			"remote storage target : $remote_target" . ($remote_specification ne $remote_substituted ? " (specification: $remote_specification)" : '') . "\n" .
			"local mount directory : $local_substituted " . ($local_specification ne $local_substituted ? " (specification: $local_specification)" : '')
		);
		
		# Specify ignore error option to prevent warnings on first attempt
		my $mount_result = $self->nfs_mount_share($remote_target, $local_substituted, 1);
		# If successful or failed and returned undefined, stop processing this share
		if (!defined($mount_result)) {
			# Unrepairable error encountered
			$error_encountered = 1;
			next MOUNT_SPECIFICATION;
		}
		elsif ($mount_result == 1) {
			# Successfully mounted share
			next MOUNT_SPECIFICATION;
		}
		
		# nfs_mount_share() returned 0 indicating the remote directory does not exist
		notify($ERRORS{'OK'}, 0, "unable to mount $remote_target on $computer_name on first attempt, checking if directories need to be created");
		
		# Get the last component of the remote directory specification following the last forward slash
		my ($remote_directory_name_specification) = $remote_specification =~
			/
				\/
				(
					[^
						\/
					]+
				)
				$
			/gx;
		if (!$remote_directory_name_specification) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount share on $computer_name: $remote_target --> $local_substituted, no attempt made to create user/reservation-specific directory on share because the remote directory name specification could not be determined: $remote_specification");
			return;
		}
		elsif ($remote_directory_name_specification !~
			/
				\[
				[^
					\]
				]+
				\]
			/gx) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount share on $computer_name: $remote_target --> $local_substituted, no attempt made to create user/reservation-specific directory on share because the remote directory name specification does not contain a substitution value: $remote_directory_name_specification");
			return;
		}
		
		# Get the remote directory name and its parent directory path
		my ($remote_parent_directory_path, $remote_directory_name) = $remote_substituted =~
			/
				^
				(
					\/.+
				)
				\/
				(
					[^
						\/
					]+
				)
				$
			/gx;
		if (!defined($remote_directory_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount share on $computer_name: $remote_target --> $local_substituted, no attempt made to create user/reservation-specific directory on share because the remote directory name and its parent directory path could not be determined: $remote_substituted");
			return;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "attempting to create user/reservation-specific directory on share, remote directory name specification contains a substitution value: $remote_directory_name_specification --> $remote_directory_name");
		
		# Attempt to mount the remote parent directory on the management node
		my $mn_temp_remote_target = "$remote_host:$remote_parent_directory_path";
		my $mn_temp_mount_directory_path = tempdir(CLEANUP => 1);
		my $mn_temp_create_directory_path = "$mn_temp_mount_directory_path/$remote_directory_name";
		if (!$self->mn_os->nfs_mount_share($mn_temp_remote_target, $mn_temp_mount_directory_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount share on $computer_name: $remote_target --> $local_substituted, failed to temporarily mount remote parent directory share on management node: $mn_temp_remote_target --> $mn_temp_mount_directory_path");
			return;
		}
		
		# Try to create the directory containing the substitution value
		if (!$self->mn_os->create_directory($mn_temp_create_directory_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount share on $computer_name: $remote_target --> $local_substituted, mounted temporary remote parent directory share on management node ($mn_temp_remote_target) but failed to create '$remote_directory_name' subdirectory under it");
			$self->mn_os->nfs_unmount_share($mn_temp_mount_directory_path);
			return;
		}
		
		# Check if the directory name contains a substitution for user-specific data
		if ($remote_directory_name_specification =~ /\[user/) {
			$self->mn_os->set_file_owner($mn_temp_create_directory_path, $user_uid);
			
			# Set the permissions on the directory to 700 so other users can't read contents
			$self->mn_os->set_file_permissions($mn_temp_create_directory_path, '700');
		}
		
		
		$self->mn_os->nfs_unmount_share($mn_temp_mount_directory_path);
		
		# Try to mount the share on the computer again
		$self->nfs_mount_share($remote_target, $local_substituted) || $error_encountered++;
	}
	return !$error_encountered
}

#//////////////////////////////////////////////////////////////////////////////

=head2 unmount_nfs_shares

 Parameters  : none
 Returns     : boolean
 Description : Unmounts any shares that were added by mount_nfs_shares.

=cut

sub unmount_nfs_shares {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_id = $self->data->get_management_node_id();
	my $computer_name = $self->data->get_computer_short_name();
	my $user_uid = $self->data->get_user_uid();
	
	# Get the NFS mount information configured for the management node from the variable table
	my $nfsmount_variable_name = "nfsmount|$management_node_id";
	my $nfsmount_variable_value = get_variable($nfsmount_variable_name);
	if (!$nfsmount_variable_value) {
		notify($ERRORS{'DEBUG'}, 0, "'$nfsmount_variable_name' variable is NOT configured for management node $management_node_id");
		return 1;
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved '$nfsmount_variable_name' variable configured for management node: '$nfsmount_variable_value'");
	
	my $error_encountered = 0;
	
	MOUNT_SPECIFICATION: for my $mount_specification (split(/;/, $nfsmount_variable_value)) {
		# Format:
		#    <IP/hostname>:<remote directory>,<local directory>
		# Example:
		#    10.0.0.12:/users/home/[username],/home/[username]
		my ($remote_host, $remote_specification, $local_specification) = $mount_specification =~
			/
				^\s*
				([^:\s]+)             # $remote_host
				\s*:\s*               # :
				(\/[^,]*[^,\s\/])\/?  # $remote_specification
				\s*,\s*               # ,
				(\/.*[^\s\/])\/?      # $local_specification
				\s*$
			/gx;
		if (!defined($remote_host) || !defined($remote_specification) || !defined($local_specification)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to parse mount specification: '$mount_specification'");
			$error_encountered = 1;
			next MOUNT_SPECIFICATION;
		}
		
		# Replace variables in local and remote directory paths
		my $local_substituted = $self->data->substitute_string_variables($local_specification);
		
		# Specify ignore error option to prevent warnings on first attempt
		my $unmount_result = $self->nfs_unmount_share($local_substituted);
		if (!$unmount_result) {
			$error_encountered = 1;
		}
	}
	return !$error_encountered
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_config_file_parameter

 Parameters  : $file_path, $parameter_name_argument, $delimiter, $parameter_value_argument
 Returns     : boolean
 Description : Adds a parameter/value line to a text-based config file. If a
               line already exists that matches the parameter name, it will be
               modified if the value is different. If no line already exists
               that matches the parameter name, a line will be added to the end
               of the file.
               
               The $delimiter argument may contain spaces if a line should be
               formatted such as: myParam = myValue
               
               For this example, the $delimiter argument should be ' = '.

=cut

sub set_config_file_parameter {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($file_path, $parameter_name_argument, $delimiter, $parameter_value_argument) = @_;
	if (!defined($file_path)) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	elsif (!defined($parameter_name_argument)) {
		notify($ERRORS{'WARNING'}, 0, "parameter name argument was not supplied");
		return;
	}
	elsif (!defined($delimiter)) {
		notify($ERRORS{'WARNING'}, 0, "$delimiter character argument was not supplied");
		return;
	}
	elsif (!defined($parameter_value_argument)) {
		notify($ERRORS{'WARNING'}, 0, "parameter value argument was not supplied");
		return;
	}
	
	(my $delimiter_cleaned = $delimiter) =~ s/(^\s+|\s+$)//g;
	
	my @original_lines = $self->get_file_contents($file_path);
	my @updated_lines;
	my $parameter_found = 0;
	for my $original_line (@original_lines) {
		if ($original_line =~ /^\s*$parameter_name_argument\s*$delimiter_cleaned/i) {
			if (!$parameter_found) {
				$parameter_found = 1;
				my $updated_line = $parameter_name_argument . $delimiter . $parameter_value_argument;
				if ($original_line ne $updated_line) {
					notify($ERRORS{'DEBUG'}, 0, "updating line in $file_path: '$original_line' --> '$updated_line'");
					push @updated_lines, $updated_line;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "existing line in $file_path does not need to be modified: '$original_line'");
					push @updated_lines, $original_line;
				}
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "omitting duplicate '$parameter_name_argument' line in $file_path: '$original_line'");
			}
			next;
		}
		else {
			push @updated_lines, $original_line;
		}
	}
	
	if (!$parameter_found) {
		push @updated_lines, $parameter_name_argument . $delimiter . $parameter_value_argument;
	}
	
	return $self->create_text_file($file_path, join("\n", @updated_lines));
}

#//////////////////////////////////////////////////////////////////////////////
1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
