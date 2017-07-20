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

VCL::Module::OS::OSX.pm - OSX  support module

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for OSX operating systems.

=cut

###############################################################################
package VCL::Module::OS::OSX;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::OS);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';
use VCL::utils;
use File::Basename;
#no warnings 'redefine';

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on the management node of the files specific to this OS
               module which are needed to configure the loaded OS on a computer.
               This is normally the directory under 'tools' named after this OS
               module.
               
               Example:
               /opt/vcl/tools/OSX

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/OSX";

=head2 $NODE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on computer loaded with a VCL image where configuration
               files and scripts reside.

=cut

our $NODE_CONFIGURATION_DIRECTORY = '/var/root/VCL';

###############################################################################

=head1 INTERFACE OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : Hash containing 'end_state' key
 Returns     : 1 - success , 0 - failure
 Description : Performs the steps necessary to prepare a OSX OS before an
               image is captured.
               This subroutine is called by a provisioning module's capture()
               subroutine.
               
               The steps performed are:
               logout and delete users which were created for imaging reservation - done
               set root password - done
               set administrator password - done
               clear tmp files - done
               disable screen saver if VM - not done
               disable RDP access ... off by default --- done
               enable ssh access - done
               enable ping - not done
               start firewall -- done
               shutdown - done

=cut

sub pre_capture {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	my $args = shift;

#	print "*** ".ref($self)."***\n";


	# Check if end_state argument was passed
	if (defined $args->{end_state}) {
		$self->{end_state} = $args->{end_state};
	}
	else {
		$self->{end_state} = 'off';
	}

	notify($ERRORS{'OK'}, 0, "beginning OSX image PRE_CAPTURE() preparation tasks on $computer_node_name");

	# copy pre_capture configuration files to the computer (scripts, etc)
	if (!$self->copy_capture_configuration_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy OSX script files to $computer_node_name");
		return 0;
	}

	# Log off users which were created for the imaging reservation
	if (!$self->logoff_users()) {
		notify($ERRORS{'WARNING'}, 0, "unable to log off all currently logged in users on $computer_node_name");
		return 0;
	}

	# block rdp via firewall
	if (!$self->firewall_disable_rdp(1)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name failed to disable rdp");
		return 0;
	}

	# Delete the user assigned to this reservation
	my $deleted_user = $self->delete_user();
	if (!$deleted_user) {
		notify($ERRORS{'WARNING'}, 0, "pre_capture was unable to delete user");
	}

	# set root account password to known value
	# borrow the WINDOWS_ROOT_PASSW0RD from vcld.conf
	if (!$self->set_password("root", $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root password");
		return 0;
	}

	# set administrator account password to known value
	if (!$self->set_password("administrator", $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root password");
		return 0;
	}

	# Shutdown node
	if (!$self->shutdown()) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name failed to shutdown");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "pre_capture returning 1");
	return 1;

} ## end sub pre_capture

#//////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : None
 Returns     : 1 - success , 0 - failure
 Description : Performs the steps necessary to configure a OSX OS after an
               image has been loaded.
               
               This subroutine is called by a provisioning module's load()
               subroutine.
               
               The steps performed are:
               
               wait for ssh to respond -- done
               wait for root to logout -- not done
               logout all currently logged on users ... hopefully not needed -- not done
               # update known_hosts on management node -- not done
               enable ping on private network -- not done
               sync time -- not done
               # remove root password and other private info from vcl config files -- not done
               randomize root password -- done
               randomize administrator password -- done
               imagemeta postoption reboot is set of image ??? -- not done
               rename computer -- not done
               computer hostname -- done
               add line to currentimage.txt indicating post_load has run -- done

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name    = $self->data->get_computer_node_name();
	my $management_node_keys  = $self->data->get_management_node_keys();
	my $image_name	           = $self->data->get_image_name();
	my $computer_short_name   = $self->data->get_computer_short_name();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	my $imagemeta_postoption  = $self->data->get_imagemeta_postoption();
	
	notify($ERRORS{'OK'}, 0, "beginning OSX POST_LOAD() $image_name on $computer_short_name");
	
	
	# Wait for computer to respond to SSH
	if (!$self->wait_for_response(15, 900, 8)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
		return 0;
	}

   if (!$self->os->update_public_ip_address()) {
      $self->reservation_failed("failed to update public IP address");
   }
	
	my $root_random_password = getpw();
	if ($self->set_password("root", $root_random_password)) {
		notify($ERRORS{'OK'}, 0, "successfully changed root password on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to set root password");
		return 0;
	}
	
	my $administrator_random_password = getpw();
	if ($self->set_password("administrator", $administrator_random_password)) {
		notify($ERRORS{'OK'}, 0, "successfully changed administrator password on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to set administrator password");
		return 0;
	}
	
	# Check if the imagemeta postoption is set to reboot, reboot if necessary
	if ($imagemeta_postoption =~ /reboot/i) {
		notify($ERRORS{'OK'}, 0, "imagemeta postoption reboot is set for image, rebooting computer");
		if (!$self->reboot()) {
			notify($ERRORS{'WARNING'}, 0, "failed to reboot the computer");
			return 0;
		}
	}
	
	$self->activate_irapp();
	
	# arkurth: added for possible future use, don't have a way to test
	# Use the following line to enable execution of stage scripts:
	# return $self->SUPER::post_load();
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub post_load

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     : 1 - success , 0 - failure
 Description : revert the changes made when preparing a resource for a particular reservation
               
               The steps performed are:
               
               if (user logged in)
               exit
               Firewall close RDP access
               delete user

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "beginning OSX SANITIZE() on $computer_node_name");

	# block rdp via firewall
	if (!$self->firewall_disable_rdp()) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name failed to disable rdp");
		return 0;
	}

	# Delete user associated with the reservation
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "users have been deleted from $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete users from $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;

} ## end sub sanitize


#//////////////////////////////////////////////////////////////////////////////

=head2 reboot

 Parameters  : $wait_for_reboot
 Returns     : 1 - success , 0 - failure
 Description : The steps performed are:
               
               graceful reboot of OS
               force logout of users
               wait for reboot to complete
               returns after reboot is complete
               
               make sure ssh is enabled
               make sure ping is enabled
               reboot
               wait for ssh to be up

=cut

sub reboot {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "beginning OSX REBOOT() on $computer_node_name");

	# Check if an argument was supplied
	my $wait_for_reboot = shift;
	if (!defined($wait_for_reboot) || $wait_for_reboot !~ /0/) {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and waiting for ssh to become active");
		$wait_for_reboot = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and NOT waiting for ssh to become active");
		$wait_for_reboot = 0;
	}

	my $reboot_start_time = time();
	notify($ERRORS{'DEBUG'}, 0, "reboot will be attempted on $computer_node_name");

	# Check if computer responds to ssh before preparing for reboot

	if ($self->wait_for_ssh(0)) {
		# Make sure SSH access is enabled from private IP addresses
		
		my $reboot_command = "/sbin/shutdown -r now";
		my ($reboot_exit_status, $reboot_output) = $self->execute($reboot_command,1);
		if (!defined($reboot_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to reboot $computer_node_name");
			return 0;
		}
		
		if ($reboot_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "executed reboot command on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to reboot $computer_node_name, attempting power reset, output:\n" . join("\n", @$reboot_output));
			
			# Call provisioning module's power_reset() subroutine
			if ($self->provisioner->power_reset()) {
				notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
				return 0;
			}
		}
	}
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
	
	my $wait_attempt_limit = 2;
	if ($self->wait_for_reboot($wait_attempt_limit)) {
		# Reboot was successful, calculate how long reboot took
		my $reboot_end_time = time();
		my $reboot_duration = ($reboot_end_time - $reboot_start_time);
		notify($ERRORS{'OK'}, 0, "reboot complete on $computer_node_name, took $reboot_duration seconds");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, made $wait_attempt_limit attempts");
		return 0;
	}
} ## end sub reboot

#//////////////////////////////////////////////////////////////////////////////

=head2 shutdown

 Parameters  : 
 Returns     : 1 - success , 0 - failure
 Description : The steps performed are:
               
               graceful shutdown of OS -- done
               force users to logout -- not done
               waits for shutdown to complete -- done
               returns after complete -- done
               
               # pre_capture

=cut

sub shutdown {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "beginning OSX SHUTDOWN() on $computer_node_name");
	
	my $command = '/sbin/shutdown -h now';
	
	my ($exit_status, $output) = $self->execute($command,1);
	
	if (defined $exit_status && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed command to shut down $computer_node_name");
	}
	else {
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to shut down $computer_node_name, attempting power off");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, attempting power off, output:\n" . join("\n", @$output));
		}
		
		# Call provisioning module's power_off() subroutine
		if (!$self->provisioner->power_off()) {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, failed to initiate power off");
			return;
		}
	}
	
	# Wait maximum of 3 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(180)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping after shutdown command was issued");
		return;
	}
	
	# Wait maximum of 5 minutes for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(300);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 1 minute to allow computer time to shutdown");
		sleep 60;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off");
		return;
	}

	return 1;

} ## end sub shutdown

#//////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  : 
 Returns     : 1 - success , 0 - failure
 Description : adds user to image 
               The steps performed are:
               
               if (!administrator !root)
               useradd
               
               set password

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_password = $self->data->get_reservation_password();
	my $username             = $self->data->get_user_login_id();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	notify($ERRORS{'OK'}, 0, "beginning OSX RESERVE() on $computer_node_name");
	
	# Add the users to the computer
	# The add_users() subroutine will add the reservation user
	if ($self->add_user()) {
		notify($ERRORS{'OK'}, 0, "Successfully added useracct: $username on $computer_node_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "Failed to add useracct: $username on $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub reserve

#//////////////////////////////////////////////////////////////////////////////
 
=head2 grant_access

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description : opens port in firewall for external access

#
# gets called by reserved.pm after the user has clicked "Connect"
# the user's IP address is known when called
# opens firewall for RDP
#

=cut
 
sub grant_access {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $user		= $self->data->get_user_login_id();
	my $computer_node_name	= $self->data->get_computer_node_name();
	my $remote_ip		= $self->data->get_reservation_remote_ip();
	my $request_forimaging	= $self->data->get_request_forimaging();
	
	notify($ERRORS{'OK'}, 0, "GRANT_ACCESS() routine $user,$computer_node_name");
	
	# Check to make sure remote IP is defined
	my $remote_ip_range;
	if (!$remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "reservation remote IP address is not set in the data structure, opening RDP to any address");
	}
	elsif ($remote_ip !~ /^(\d{1,3}\.?){4}$/) {
		notify($ERRORS{'WARNING'}, 0, "reservation remote IP address format is invalid: $remote_ip, opening RDP to any address");
	}
	else {
		# Assemble the IP range string in CIDR notation
		$remote_ip_range = "$remote_ip/24";
		notify($ERRORS{'OK'}, 0, "RDP will be allowed from $remote_ip_range on $computer_node_name");
	}
	
	# Set the $remote_ip_range variable to the string 'all' if it isn't already set (for display purposes)
	$remote_ip_range = 'any' if !$remote_ip_range;
	
	# Allow RDP connections
	if ($request_forimaging) {
		if ($self->firewall_enable_rdp($remote_ip_range,1)) {
			notify($ERRORS{'OK'}, 0, "firewall was configured to allow RDP access from $remote_ip_range on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "firewall could not be configured to grant RDP access from $remote_ip_range on $computer_node_name");
			return 0;
		}
	}
	else {
		if ($self->firewall_enable_rdp($remote_ip_range)) {
			notify($ERRORS{'OK'}, 0, "firewall was configured to allow RDP access from $remote_ip_range on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "firewall could not be configured to grant RDP access from $remote_ip_range on $computer_node_name");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "access has been granted for reservation on $computer_node_name");
	
	return 1;

} ## end sub grant_access


#//////////////////////////////////////////////////////////////////////////////

=head2 enable_firewall_port

 Parameters  : $protocol, $port, $scope (optional)
 Returns     : 1 if succeeded, 0 otherwise
 Description : Enables a firewall port on the computer. The protocol and port
               arguments are required. An optional scope argument may supplied.

# called by OS::process_connect_methods()

=cut

sub enable_firewall_port {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, " beginning OSX ENABLE_FIREWALL_PORT()");

	my $protocol = shift;
	if (!$protocol) {
		notify($ERRORS{'WARNING'}, 0, " protocol variable was not passed as an argument");
		return 0;
	}

	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, " port variable was not passed as an argument");
		return 0;
	}

	my $scope = shift;
	if (!$scope) {
		$scope = 'all';
	}

	my $command = "ipfw list";
	my ($status, $output) = $self->execute($command, 1);
	notify($ERRORS{'DEBUG'}, 0, " checking firewall rules on node $computer_node_name");

	my $rule=0;
	my $upper_limit=12300;
	my $found=0;
	while ($rule == 0  &&  $upper_limit > 0) {
		foreach my $line (@{$output}) {
			if ($line =~ /^$upper_limit\s+/) {
				$found=1;
			}
		}
		if ($found) {
			$upper_limit--;
			$found=0;
		} else {
			$rule = $upper_limit;
		}
	}

	$command = "ipfw add $rule allow $protocol from $scope to any dst-port $port";

	($status, $output) = $self->execute($command, 1);
	notify($ERRORS{'DEBUG'}, 0, "checking connections on node $computer_node_name on port $port");

	return 1;

} ## end sub enable_firewall_port


#//////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_core_count

 Parameters  : none
 Returns     : integer
 Description : Retrieves the number of CPU cores the computer has by querying
               the NUMBER_OF_PROCESSORS environment variable.

# called by Provisioning::VMware:VMware.pm
#       Windows.pm only returns value from database
#       return $self->get_environment_variable_value('NUMBER_OF_PROCESSORS');

=cut

sub get_cpu_core_count {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();

	my $num_cpus	= 0;
	my $command	= "/usr/sbin/system_profiler SPHardwareDataType";

# Hardware:
#
#     Hardware Overview:
#
#       Model Name: Mac mini
#       Model Identifier: Macmini2,1
#       Processor Speed: 2.66 GHz
#       Number Of Processors: 2
#       Total Number Of Cores: 2
#       L2 Cache (per processor): 4 MB
#       Memory: 7.88 GB
#       Bus Speed: 367 MHz
#       Boot ROM Version: MM21.009A.B00
#       SMC Version (system): 1.30f3
#       Serial Number (system): SOMESRLNMBR
#       Hardware UUID: 9D002E7C-B39B-590F-B9E7-A7AE1554F9E2

	my ($status, $output) = $self->execute($command, 1);
	notify($ERRORS{'DEBUG'}, 0, " getting cpu count on node $computer_node_name ");

	foreach my $line (@{$output}) {
		if ($line =~ /\s+(Total)\s+(Number)\s+(Of)\s+(Cores:)\s+([0-9]*)/) {
			$num_cpus = $line;
			$num_cpus =~ s/ Total Number Of Cores: //;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, " get_cpu_core_count() is $num_cpus");

	return $num_cpus;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_connection_on_port

 Parameters  : $port
 Returns     : (connected|conn_wrong_ip|timeout|failed)
 Description : uses netstat to see if any thing is connected to the provided port

# called by OS.pm:is_user_connected()

=cut

sub check_connection_on_port {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();

	my $remote_ip                   = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address  = $self->data->get_computer_public_ip_address();

	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
		return "failed";
	}

	my $ret_val = "no";
	my $command = "netstat -an";

	my ($status, $output) = $self->execute($command, 1);
	notify($ERRORS{'DEBUG'}, 0, "checking connections on node $computer_node_name on port $port");


	foreach my $line (@{$output}) {
		if ($line =~ /tcp4\s+([0-9]*)\s+([0-9]*)\s+($computer_public_ip_address.$port)\s+($remote_ip).([0-9]*)(.*)(ESTABLISHED)/) {
			$ret_val = "connected";
		}
	}

	return $ret_val;

}


#//////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub user_exists {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}

	notify($ERRORS{'DEBUG'}, 0, "checking if user $username exists on $computer_node_name");

	# Attempt to query the user account
	my $query_user_command = "id $username";
	my ($query_user_exit_status, $query_user_output) = $self->execute($query_user_command,1);
	if (grep(/uid/, @$query_user_output)) {
		notify($ERRORS{'DEBUG'}, 0, "user $username exists on $computer_node_name");
		return 1;
	}
	elsif (grep(/No such user/i, @$query_user_output)) {
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

}





###############################################################################
#											#
#		END OF GLOBALLY REQUIRED OS MODULE SUBROUTINES				#
#											#
###############################################################################


=head1 AUXILIARY OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_configuration_directory

 Parameters  : none
 Returns     : string
 Description : Retrieves the $NODE_CONFIGURATION_DIRECTORY variable value for
               the OS. This is the path on the computer's hard drive where image
               configuration files and scripts are copied.

=cut

sub get_node_configuration_directory {
	return $NODE_CONFIGURATION_DIRECTORY;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_capture_configuration_files

 Parameters  : $source_configuration_directory
 Returns     :
 Description : Copies all required configuration files to the computer,
               including scripts, needed to capture an image.
               
# from pre_capture

=cut

sub copy_capture_configuration_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL module object method");
		return;	
	}

        my $computer_node_name		= $self->data->get_computer_node_name();
	my $management_node_keys	= $self->data->get_management_node_keys();

	my $command = "/bin/chmod -R 755 $NODE_CONFIGURATION_DIRECTORY";

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
		# Check if source configuration directory exists on this management node
		unless (-d "$source_configuration_directory") {
			notify($ERRORS{'OK'}, 0, "source directory does not exist on this management node: $source_configuration_directory");
			next;
		}
		
		notify($ERRORS{'OK'}, 0, "copying image capture configuration files from $source_configuration_directory to $computer_node_name");
		if (run_scp_command("$source_configuration_directory/*", "$computer_node_name:$NODE_CONFIGURATION_DIRECTORY", $management_node_keys)) {
			notify($ERRORS{'OK'}, 0, "copied $source_configuration_directory directory to $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
			
			notify($ERRORS{'DEBUG'}, 0, "attempting to set permissions on $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
			if ($self->execute($command,1)) {
				notify($ERRORS{'OK'}, 0, "chmoded -R 755 $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
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
	
	return 1;

} ## end sub copy_capture_configuration_files

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_capture_configuration_files

 Parameters  : 
 Returns     :
 Description : Deletes the capture configuration directory.
               
               # copy_capture_configuration_files

=cut

sub delete_capture_configuration_files {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Remove existing configuration files if they exist
	notify($ERRORS{'OK'}, 0, "attempting to remove old configuration directory if it exists: $NODE_CONFIGURATION_DIRECTORY");
	if (!$self->delete_file($NODE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing configuration directory: $NODE_CONFIGURATION_DIRECTORY");
		return 0;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_user {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	# Make sure the user login ID was passed
	my $user_login_id = shift;
	
	$user_login_id = $self->data->get_user_login_id() if (!$user_login_id);
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}
	
	if ($user_login_id eq "root" || $user_login_id eq "administrator" ) {
		notify($ERRORS{'WARNING'}, 0, "$user_login_id MUST not be deleted");
		return 0;
	}

	my $userdel_cmd = $self->get_node_configuration_directory() . "/userdel $user_login_id";
	if ($self->execute($userdel_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "deleted user: $user_login_id from $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to delete user: $user_login_id from $computer_node_name");
	}
	
	return 1;

} ## end sub delete_user


#//////////////////////////////////////////////////////////////////////////////

=head2 set_password

 Parameters  : $username, $password
 Returns     : 1 - success , 0 - failure
 Description : sets password for given username
               
# pre_capture

=cut

sub set_password {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
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
	my $passwd_cmd = "/usr/bin/dscl . -passwd /Users/$username '$password'";
	my ($exit_status1, $output1) = $self->execute($passwd_cmd,1);
	if ($exit_status1 == 0) {
		notify($ERRORS{'OK'}, 0, "password changed to '$password' for user '$username' on $computer_node_name");
	}
	elsif (defined $exit_status1) {
		notify($ERRORS{'WARNING'}, 0, "failed to change password to '$password' for user '$username' on $computer_node_name, exit status: $exit_status1, output:\n@{$output1}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to change password to '$password' for user '$username' on $computer_node_name");
		return 0;
	}
	
	# Attempt to remove the login.keychain
	if ("$username" eq "administrator" || "$username" eq "root") {
		notify($ERRORS{'DEBUG'}, 0, "removing login.keychain of $username on $computer_node_name");
		my $command2 = "find ~$username/Library/Keychains -type f -name login.keychain -exec rm {} \\;";
		#		my $command2 = "/bin/rm /Users/$username/Library/Keychains/login.keychain";
		my ($exit_status2, $output2) = $self->execute($command2,1);
		if ($exit_status2 == 0) {
			notify($ERRORS{'OK'}, 0, "removed login.keychain for user '$username' on $computer_node_name");
		}
		elsif (defined $exit_status2) {
			notify($ERRORS{'WARNING'}, 0, "failed to remove login.keychain for user '$username' on $computer_node_name, exit status: $exit_status2, output:\n@{$output2}");
			return 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to remove login.keychain for user '$username' on $computer_node_name");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "changed password for user: $username");
	return 1;
} ## end sub set_password


#//////////////////////////////////////////////////////////////////////////////

=head2 file_exists

 Parameters  : $path
 Returns     : boolean
 Description : Checks if a file or directory exists on the OSX computer.
               
               # delete_file

=cut

sub file_exists {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path from the subroutine arguments and make sure it was passed
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$path = normalize_file_path($path);
	
	# Escape all spaces in the path
	my $escaped_path = escape_file_path($path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Check if the file or directory exists
	# Do not enclose the path in quotes or else wildcards won't work
	my $command = "stat $escaped_path";
	my ($exit_status, $output) = $self->execute($command,1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if file or directory exists on $computer_short_name:\npath: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "file or directory does not exist on $computer_short_name: '$path'");
		return 0;
	}
	elsif (grep(/stat: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if file or directory exists on $computer_short_name:\npath: '$path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Count the lines beginning with "Size:" and ending with "file", "directory", or "link" to determine how many files and/or directories were found
	my $files_found = grep(/^\s*Size:.*file$/i, @$output);
	my $directories_found = grep(/^\s*Size:.*directory$/i, @$output);
	my $links_found = grep(/^\s*Size:.*link$/i, @$output);
	
	if ($files_found || $directories_found || $links_found) {
		notify($ERRORS{'DEBUG'}, 0, "'$path' exists on $computer_short_name, files: $files_found, directories: $directories_found, links: $links_found");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to determine if file or directory exists on $computer_short_name: '$path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_file

 Parameters  : $path
 Returns     : boolean
 Description : Deletes files or directories on the OSX computer.

=cut

sub delete_file {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument were not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$path = normalize_file_path($path);
	
	# Escape all spaces in the path
	my $escaped_path = escape_file_path($path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Delete the file
	my $command = "rm -rfv $escaped_path";
	my ($exit_status, $output) = $self->execute($command,1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to delete file or directory on $computer_short_name:\npath: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/(cannot access|no such file)/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "file or directory not deleted because it does not exist on $computer_short_name: $path");
	}
	elsif (grep(/rm: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to delete file or directory on $computer_short_name: '$path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted '$path' on $computer_short_name");
	}
	
	# Make sure the path does not exist
	my $file_exists = $self->file_exists($path);
	if (!defined($file_exists)) {
		notify($ERRORS{'WARNING'}, 0, "failed to confirm file doesn't exist on $computer_short_name: '$path'");
		return;
	}
	elsif ($file_exists) {
		notify($ERRORS{'WARNING'}, 0, "file was not deleted, it still exists on $computer_short_name: '$path'");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist on $computer_short_name: '$path'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_directory

 Parameters  : $directory_path, $mode (optional)
 Returns     : boolean
 Description : Creates a directory on the OSX computer as indicated by the
               $directory_path argument.
               
# copy_capture_configuration_files

=cut

sub create_directory {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the directory path argument
	my $directory_path = shift;
	if (!$directory_path) {
		notify($ERRORS{'WARNING'}, 0, "directory path argument was not supplied");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$directory_path = normalize_file_path($directory_path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Attempt to create the directory
	#	my $command = "ls -d --color=never \"$directory_path\" 2>&1 || mkdir -p \"$directory_path\" 2>&1 && ls -d --color=never \"$directory_path\"";
	my $command = "ls -d \"$directory_path\" 2>&1 || mkdir -p \"$directory_path\" 2>&1 && ls -d \"$directory_path\"";
	my ($exit_status, $output) = $self->execute($command,1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create directory on $computer_short_name:\npath: '$directory_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/mkdir:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^\s*$directory_path\s*$/, @$output)) {
		if (grep(/ls:/, @$output)) {
			notify($ERRORS{'OK'}, 0, "directory created on $computer_short_name: '$directory_path'");
		}
		else {
			notify($ERRORS{'OK'}, 0, "directory already exists on $computer_short_name: '$directory_path'");
		}
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output) . "\nlast line:\n" . string_to_ascii(@$output[-1]));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  :
 Returns     : 1 if succeeded, 0 otherwise
 Description : # grant_access

=cut

sub firewall_enable_rdp {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	my $remote_ip_range = shift;
	my $persist = shift;
	my $fw_enable_rdp_cmd = "";
	
	# Make sure the remote ip range was passed
	if (!$remote_ip_range) {
		notify($ERRORS{'CRITICAL'}, 0, "remote IP range could not be determined, failed to open RDP on $computer_node_name");
		return 0;
	}
	
	if ($persist) {
		$fw_enable_rdp_cmd = $self->get_node_configuration_directory() . "/fw_enable_rdp $remote_ip_range $persist";
	}
	else {
		$fw_enable_rdp_cmd = $self->get_node_configuration_directory() . "/fw_enable_rdp $remote_ip_range";
	}
	if ($self->execute($fw_enable_rdp_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "enabled rdp through firewall on $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to enable rdp through firewall on $computer_node_name");
	}
	
	return 1;

} ## end sub firewall_enable_rdp

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_rdp

 Parameters  : optional persistence flag
 Returns     : 1 if succeeded, 0 otherwise
 Description : 
               
               # pre_capture
               # sanitize

=cut

sub firewall_disable_rdp {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
			notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
			return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	my $persist = shift;
	my $fw_disable_rdp_cmd;
	
	if ($persist) {
		$fw_disable_rdp_cmd = $self->get_node_configuration_directory() . "/fw_disable_rdp $persist";
	}
	else {
		$fw_disable_rdp_cmd = $self->get_node_configuration_directory() . "/fw_disable_rdp";
	}
	
	if ($self->execute($fw_disable_rdp_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "disabled rdp through firewall on $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to disable rdp through firewall on $computer_node_name");
	}
	
	return 1;

} ## end sub firewall_disable_rdp


#//////////////////////////////////////////////////////////////////////////////

=head2 logoff_users

 Parameters  :
 Returns     : 1 if succeeded, 0 otherwise
 Description :
               
# pre_capture

=cut

sub logoff_users {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	my $logout_users_cmd = "/usr/bin/killall loginwindow";
	if ($self->execute($logout_users_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "logged off all users on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to log off all users on $computer_node_name");
	}
	
	return 1;

} ## end sub logoff_users


#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_mac_address

 Parameters  : none
 Returns     : string
 Description : Returns the MAC address of the interface assigned the private IP
               address.

=cut

sub get_private_mac_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $private_network_configuration = $self->get_network_configuration('private');
	if (!$private_network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve private network configuration");
		return;
	}
	
	my $private_mac_address = $private_network_configuration->{physical_address};
	if (!$private_mac_address) {
		notify($ERRORS{'WARNING'}, 0, "'physical_address' key is not set in the private network configuration hash:\n" . format_data($private_network_configuration));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved private MAC address: $private_mac_address");
	return $private_mac_address;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_mac_address

 Parameters  : none
 Returns     : string
 Description : Returns the MAC address of the interface assigned the public IP
               address.

=cut

sub get_public_mac_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $public_network_configuration = $self->get_network_configuration('public');
	if (!$public_network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve public network configuration");
		return;
	}
	
	my $public_mac_address = $public_network_configuration->{physical_address};
	if (!$public_mac_address) {
		notify($ERRORS{'WARNING'}, 0, "'physical_address' key is not set in the public network configuration hash:\n" . format_data($public_network_configuration));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved public MAC address: $public_mac_address");
	return $public_mac_address;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_network_configuration

 Parameters  : $network_type (optional)
 Returns     : hash reference
 Description : Retrieves the network configuration on the OSX computer and
               constructs a hash. A $network_type argument can be supplied
               containing either 'private' or 'public'. If the $network_type
               argument is not supplied, the hash keys are the network interface
               names and the hash reference returned is formatted as follows:
               |--%{eth0}
                  |--%{eth0}{ip_address}
                    |--{eth0}{ip_address}{10.10.4.35} = '255.255.240.0'
                  |--{eth0}{name} = 'eth0'
                  |--{eth0}{physical_address} = '00:50:56:08:00:f8'
               |--%{eth1}
                  |--%{eth1}{ip_address}
                    |--{eth1}{ip_address}{152.1.14.200} = '255.255.255.0'
                  |--{eth1}{name} = 'eth1'
                  |--{eth1}{physical_address} = '00:50:56:08:00:f9'
               |--%{eth2}
                  |--%{eth2}{ip_address}
                    |--{eth2}{ip_address}{10.1.2.33} = '255.255.240.0'
                  |--{eth2}{name} = 'eth2'
                  |--{eth2}{physical_address} = '00:0c:29:ba:c1:77'
               |--%{lo}
                  |--%{lo}{ip_address}
                    |--{lo}{ip_address}{127.0.0.1} = '255.0.0.0'
                  |--{lo}{name} = 'lo'
                  
               If the $network_type argument is supplied, a hash reference is
               returned containing only the configuration for the specified
               interface:
               |--%{ip_address}
                  |--{ip_address}{10.1.2.33} = '255.255.240.0'
               |--{name} = 'eth2'
               |--{physical_address} = '00:0c:29:ba:c1:77'

=cut

sub get_network_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	my $network_type = shift;
	$network_type = lc($network_type) if $network_type;
	if ($network_type && $network_type !~ /(public|private)/i) {
		notify($ERRORS{'WARNING'}, 0, "network type argument can only be 'public' or 'private'");
		return;
	}
	
	my %network_configuration;
	
	# Check if the network configuration has already been retrieved and saved in this object
	if (!$self->{network_configuration}) {
		# Run ipconfig
		my $command = "ifconfig -a";
		my ($exit_status, $output) = $self->execute($command,1); 
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve network configuration: $command");
			return;
		}
		
		# Loop through the ifconfig output lines
		my $interface_name;
		for my $line (@$output) {
			# Extract the interface name from the "flags" line:
			# en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
			if ($line =~ /([^\s:]+).*flags/) {
				$interface_name = $1;
			}
			
			# Skip to the next line if the interface name has not been determined yet
			next if !$interface_name;
			
			# Parse the "ether" line:
			# ether 00:0c:29:e0:2c:6f
			if ($line =~ /ether\s+([\w:]+)/) {
				$network_configuration{$interface_name}{name} = $interface_name;
				$network_configuration{$interface_name}{physical_address} = lc($1);
			}
			
			# Parse the IP address line:
			# inet 137.151.131.151 netmask 0xfffff000 broadcast 137.151.143.255
			# converting from hex - nasty
			if ($line =~ /inet ([\d\.]+) netmask 0x([0123456789abcdef]+) broadcast/) {
				$network_configuration{$interface_name}{ip_address}{$1} = hex(substr($2,0,2)).".".hex(substr($2,2,2)).".".hex(substr($2,4,2)).".".hex(substr($2,6,2));
			}
		}
		
		$self->{network_configuration} = \%network_configuration;
		notify($ERRORS{'DEBUG'}, 0, "retrieved network configuration:\n" . format_data(\%network_configuration));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "network configuration has already been retrieved");
		%network_configuration = %{$self->{network_configuration}};
	}
	
	# 'public' or 'private' wasn't specified, return all network interface information
	if (!$network_type) {
		return \%network_configuration;
	}
	
	# Determine either the private or public interface name based on the $network_type argument
	my $interface_name;
	if ($network_type =~ /private/i) {
		$interface_name = $self->get_private_interface_name();
	}
	else {
		$interface_name = $self->get_public_interface_name();
	}
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the $network_type interface name");
		return;
	}
	
	# Extract the network configuration specific to the public or private interface
	my $return_network_configuration = $network_configuration{$interface_name};
	if (!$return_network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "network configuration does not exist for interface: $interface_name, network configuration:\n" . format_data(\%network_configuration));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "returning $network_type network configuration");
	return $return_network_configuration;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_post_load_status

 Parameters  : none
 Returns     : boolean
 Description : Adds a line to currentimage.txt indicating the vcld OS post_load
               tasks have run. The format of the line added is:
               vcld_post_load=success (<time>)
               
               This line is checked when a computer is reserved to make sure the
               post_load tasks have run. A computer may be loaded but the
               post_load tasks may not run if it is loaded manually or by some
               other means not controlled by vcld.

=cut

sub set_post_load_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name	= $self->data->get_computer_node_name();
	my $image_os_type	= $self->data->get_image_os_type();
	
	my $time = localtime;
	my $post_load_line = "vcld_post_load=success ($time)";
	my $command;
	
	# Remove existing lines beginning with vcld_post_load
	$command = "sed -i '' -e \'/vcld_post_load.*/d\' currentimage.txt";
	my ($exit_status, $output) = $self->execute($command, 1);
	if (defined($exit_status) && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "added line to currentimage.txt on $computer_node_name: '$post_load_line'");
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to add line to currentimage.txt on $computer_node_name: '$post_load_line', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to add line to currentimage.txt on $computer_node_name");
		return;
	}
	
	
	# Add a line to the end of currentimage.txt
	$command = "echo \"$post_load_line\" >> currentimage.txt";
	($exit_status, $output) = $self->execute($command, 1);
	if (defined($exit_status) && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "added line to currentimage.txt on $computer_node_name: '$post_load_line'");
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to add line to currentimage.txt on $computer_node_name: '$post_load_line', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to add line to currentimage.txt on $computer_node_name");
		return;
	}
	
	
	# Remove blank lines
	$command .= " && sed -i '' -e \'/^[\\s\\r\\n]*\$/d\' currentimage.txt";
	($exit_status, $output) = $self->execute($command, 1);
	if (defined($exit_status) && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "added line to currentimage.txt on $computer_node_name: '$post_load_line'");
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to add line to currentimage.txt on $computer_node_name: '$post_load_line', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to add line to currentimage.txt on $computer_node_name");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_address

 Parameters  : none
 Returns     : string
 Description : Returns the public IP address assigned to the computer.

=cut

sub get_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $public_network_configuration = $self->get_network_configuration('public');
	if (!$public_network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve public network configuration");
		return;
	}
	
	my $public_ip_address = (keys %{$public_network_configuration->{ip_address}})[0];
	if (!$public_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "'ip_address' key is not set in the public network configuration hash:\n" . format_data($public_network_configuration));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address: $public_ip_address");
	return $public_ip_address;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_user

 Parameters  :
 Returns     :
 Description :
               
# reserve

=cut

sub add_user {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $reservation_password	= $self->data->get_reservation_password();
	
	# Make sure the user login ID was passed
	my $user_login_id = shift;
	$user_login_id = $self->data->get_user_login_id() if (!$user_login_id);
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}
	
	# Make sure the computer node was passed
	my $computer_node_name = shift;
	$computer_node_name = $self->data->get_computer_node_name() if (!$computer_node_name);
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}
	
	my $useradd_cmd = $self->get_node_configuration_directory() . "/useradd $user_login_id $reservation_password";
	if ($self->execute($useradd_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "added user: $user_login_id to $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to add user: $user_login_id to $computer_node_name");
	}
	
	return 1;

} ## end sub add_user

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable

 Parameters  : optional persistence flag
 Returns     : 1 if succeeded, 0 otherwise
 Description :
               
               # pre_capture

=cut

sub firewall_enable {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	my $persist = shift;
	my $fw_enable_cmd = "";
	
	if ($persist) {
		$fw_enable_cmd = $self->get_node_configuration_directory() . "/fw_enable $persist";
	}
	else {
		$fw_enable_cmd = $self->get_node_configuration_directory() . "/fw_enable";
	}
	
	if ($self->execute($fw_enable_cmd,1)) {
		notify($ERRORS{'DEBUG'}, 0, "enabled firewall on $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to enable firewall on $computer_node_name");
	}
	
	return 1;

} ## end sub firewall_enable

#//////////////////////////////////////////////////////////////////////////////

=head2 activate_irapp

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Activates iRAPP license

=cut

sub activate_irapp {
	my $self = shift;
	if (ref($self) !~ /osx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

        my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = '/System/Library/CoreServices/rapserver.app/Contents/Tools/rapliccmd load -q -r -f /var/root/VCL/license.lic';
	
	my ($exit_status, $output) = $self->execute($command,1);
	
	if (defined $exit_status && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed command to load iRAPP license on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to load iRAPP license on $computer_node_name, output:\n" . join("\n", @$output));
	}
	
	return;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__
