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

##############################################################################
package VCL::Module::OS;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../..";

# Configure inheritance
use base qw(VCL::Module);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';
use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to retrieve the contents of currentimage.txt
	my $cat_command = "cat ~/currentimage.txt";
	my ($cat_exit_status, $cat_output) = run_ssh_command($computer_node_name, $management_node_keys, $cat_command, '', '', 0);
	if (defined($cat_exit_status) && $cat_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved currentimage.txt contents from $computer_node_name");
	}
	elsif (defined($cat_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve currentimage.txt from $computer_node_name, exit status: $cat_exit_status, output:\n@{$cat_output}");
		return;
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

 Parameters  : None
 Returns     : If successful: string
               If failed: false
 Description : Reads the currentimage.txt file on a computer and returns a
               string containing the name of the loaded image.

=cut

sub get_current_image_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
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

		notify($ERRORS{'DEBUG'}, 0, "name of image currently loaded on $computer_node_name: $current_image_name");
		return $current_image_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "empty array was returned when currentimage.txt contents were retrieved from $computer_node_name");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_reboot

 Parameters  : Maximum number of seconds to wait (optional), delay between attempts (optional)
 Returns     : If computer is pingable before the maximum amount of time has elapsed: 1
 Description : 

=cut

sub wait_for_reboot {
        my $self = shift;
        if (ref($self) !~ /VCL::Module/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }
	
        my $computer_node_name   = $self->data->get_computer_node_name();

	# Make multiple attempts to wait for the reboot to complete
        my $wait_attempt_limit = shift;
	
	if (!defined($wait_attempt_limit)) {
                $wait_attempt_limit = 2;
        }
	
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
                if (!$self->wait_for_no_ping(180, 3)) {
                        # Computer never stopped responding to ping
                        notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
                        next WAIT_ATTEMPT;
                }

                # Computer is unresponsive, reboot has begun
                # Wait for 5 seconds before beginning to check if computer is back online
                notify($ERRORS{'DEBUG'}, 0, "$computer_node_name reboot has begun, sleeping for 5 seconds");
                sleep 5;

                # Wait maximum of 6 minutes for the computer to come back up
                if (!$self->wait_for_ping(360, 5)) {
                        # Check if the computer was ever offline, it should have been or else reboot never happened
                        notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping");
                        next WAIT_ATTEMPT;
                }

                notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is pingable, waiting for ssh to respond");

                # Wait maximum of 3 minutes for ssh to respond
                if (!$self->wait_for_ssh(180, 5)) {
                        notify($ERRORS{'WARNING'}, 0, "ssh never responded on $computer_node_name");
                        next WAIT_ATTEMPT;
                }

                notify($ERRORS{'DEBUG'}, 0, "$computer_node_name responded to ssh");

                return 1;
        } ## end for (my $wait_attempt = 1; $wait_attempt <=...

        # If loop completed, maximum number of reboot attempts was reached
        notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, made $wait_attempt_limit attempts");
        return 0;


}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 is_ssh_responding

 Parameters  : $max_attempts
 Returns     : If computer responds to SSH: 1
               If computer never responds to SSH: 0
 Description : Checks if the computer is responding to SSH. Ports 22 and 24 are
               first checked to see if either is open. If neither is open, 0 is
               returned. If either of the ports is open a test SSH command which
               simply echo's a string is attempted. The default is to only
               attempt to run this command once. This can be changed by
               supplying the $max_attempts argument. If the $max_attempts is
               supplied but set to 0, only the port checks are done.

=cut

sub is_ssh_responding {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the max attempts argument if supplied, default to 1
	my $max_attempts = shift || 1;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Try nmap to see if any of the ssh ports are open before attempting to run a test command
	my $port_22_status = nmap_port($computer_node_name, 22) ? "open" : "closed";
	my $port_24_status = nmap_port($computer_node_name, 24) ? "open" : "closed";
	if ($port_22_status ne 'open' && $port_24_status ne 'open') {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, ports 22 or 24 are both closed");
		return 0;
	}
	
	if ($max_attempts) {
		# Run a test SSH command
		my ($exit_status, $output) = run_ssh_command({
			node => $computer_node_name,
			command => "echo testing ssh on $computer_node_name",
			max_attempts => $max_attempts,
			output_level => 0,
		});
		
		# The exit status will be 0 if the command succeeded
		if (defined($output) && grep(/testing/, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is responding to SSH, port 22: $port_22_status, port 24: $port_24_status");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, SSH command failed, port 22: $port_22_status, port 24: $port_24_status");
			return 0;
		}
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

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
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to SSH, maximum of $ssh_response_timeout_seconds seconds");
	if (!$self->wait_for_ssh($ssh_response_timeout_seconds, $ssh_attempt_delay_seconds)) {
		notify($ERRORS{'WARNING'}, 0, "failed to connect to $computer_node_name via SSH after $ssh_response_timeout_seconds seconds");
		return;
	}
	
	my $end_time = time();
	my $duration = ($end_time - $start_time);
	
	#insertloadlog($reservation_id, $computer_id, "osrespond", "$computer_node_name is responding to SSH after $duration seconds");
	notify($ERRORS{'OK'}, 0, "$computer_node_name is responding to SSH after $duration seconds");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	my $computer_ip_address = $self->data->get_computer_ip_address();
	my $public_ip_configuration = $self->data->get_management_node_public_ip_configuration() || return;
	
	if ($public_ip_configuration =~ /dhcp/i) {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, attempting to retrieve dynamic public IP address from $computer_node_name");
		
		my $public_ip_address;
		
		# Try to retrieve the public IP address from the OS module
		if (!$self->can("get_public_ip_address")) {
			notify($ERRORS{'WARNING'}, 0, "unable to retrieve public IP address from $computer_node_name, OS module " . ref($self) . " does not implement a 'get_public_ip_address' subroutine");
			return;
		}
		elsif ($public_ip_address = $self->get_public_ip_address()) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address from $computer_node_name using the OS module: $public_ip_address");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve dynamic public IP address from $computer_node_name");
			insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "failed to retrieve dynamic public IP address from $computer_node_name");
			return;
		}
		
		# Update the computer table if the retrieved IP address does not match what is in the database
		if ($computer_ip_address ne $public_ip_address) {
			if (update_computer_address($computer_id, $public_ip_address)) {
				notify($ERRORS{'OK'}, 0, "updated dynamic public IP address in computer table for $computer_node_name, $public_ip_address");
				insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "updated dynamic public IP address in computer table for $computer_node_name, $public_ip_address");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to update dynamic public IP address in computer table for $computer_node_name, $public_ip_address");
				insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "failed to update dynamic public IP address in computer table for $computer_node_name, $public_ip_address");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "public IP address in computer table is already correct for $computer_node_name: $computer_ip_address");
		}
		
	}
	
	elsif ($public_ip_configuration =~ /static/i) {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, attempting to set public IP address");
		
		# Try to set the static public IP address using the OS module
		if ($self->can("set_static_public_address") && $self->set_static_public_address()) {
			notify($ERRORS{'DEBUG'}, 0, "set static public IP address on $computer_node_name using OS module's set_static_public_address() method");
		}
		else {
			# Unable to set the static address using the OS module, try using utils.pm
			if (setstaticaddress($computer_node_name, $image_os_name, $computer_ip_address, $image_os_type)) {
				notify($ERRORS{'DEBUG'}, 0, "set static public IP address on $computer_node_name using utils.pm::setstaticaddress()");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address on $computer_node_name");
				insertloadlog($reservation_id, $computer_id, "staticIPaddress", "failed to set static public IP address on $computer_node_name");
				return;
			}
		}
		insertloadlog($reservation_id, $computer_id, "staticIPaddress", "set static public IP address on $computer_node_name");
	}
	
	else {
		notify($ERRORS{'DEBUG'}, 0, "IP configuration is set to $public_ip_configuration, no public IP address updates necessary");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vcld_post_load_status

 Parameters  : None
 Returns     : If vcld_post_load line exists: 1
               If vcld_post_load line exists: 0
               If an error occurred: undefined
 Description : Checks the currentimage.txt file on the computer for a line
               beginning with 'vcld_post_load='. Returns 1 if this line is found
               indicating that the OS module's post_load tasks have successfully
               run. Returns 0 if the line is not found, and undefined if an
               error occurred.

=cut

sub get_vcld_post_load_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Make sure the OS module implements a post load subroutine
	if (!$self->can('post_load')) {
		notify($ERRORS{'DEBUG'}, 0, "OS module " . ref($self) . " does not implement a post_load subroutine, returning 1");
		return 1;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Add a line to the end of currentimage.txt
	my $command = "grep vcld_post_load= currentimage.txt";
	
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 0);
	if (defined($output)) {
		if (my ($status_line) = grep(/vcld_post_load=/, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "vcld post load tasks have run on $computer_node_name: $status_line");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "vcld post load tasks have NOT run on $computer_node_name");
			return 0;
		}
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve vcld_post_load status line from currentimage.txt on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to retrieve vcld_post_load status line from currentimage.txt on $computer_node_name");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_vcld_post_load_status

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

sub set_vcld_post_load_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_os_type = $self->data->get_image_os_type();
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $time = localtime;
	
	my $post_load_line = "vcld_post_load=success ($time)";
	
	# Assemble the command
	my $command;
	
	# Remove existing lines beginning with vcld_post_load
	$command .= "sed -i -e \'/vcld_post_load.*/d\' currentimage.txt";

	# Add a line to the end of currentimage.txt
	$command .= " && echo >> currentimage.txt";
	$command .= " && echo \"$post_load_line\" >> currentimage.txt";
	
	# Remove blank lines
	$command .= ' && sed -i -e \'/^[\\s\\r\\n]*$/d\' currentimage.txt';

	if ($image_os_type =~ /windows/i) {
		$command .= " && unix2dos currentimage.txt";
	}
	else {
		$command .= " && dos2unix currentimage.txt";
	}
	
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_interface_name

 Parameters  : none
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
	
	return $self->{public_interface_name} if defined $self->{public_interface_name};
	
	# Get the network configuration hash reference
	my $network_configuration = $self->get_network_configuration();
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
		
		# Check if the interface should be ignored based on the name or description
		if ($check_interface_name =~ /(loopback|vmnet|afs|tunnel|6to4|isatap|teredo)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its name contains '$1'");
			next INTERFACE;
		}
		elsif ($description =~ /(loopback|virtual|afs|tunnel|pseudo|6to4|isatap)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its description contains '$1'");
			next INTERFACE;
		}
		
		# Get the IP addresses assigned to the interface
		my @check_ip_addresses  = keys %{$network_configuration->{$check_interface_name}{ip_address}};
		
		# Ignore interface if it doesn't have an IP address
		if (!@check_ip_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because it is not assigned an IP address");
			next INTERFACE;
		}
		
		# If $public_interface_name hasn't been set yet, set it and continue checking the next interface
		if (!$public_interface_name) {
			$public_interface_name = $check_interface_name;
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
		notify($ERRORS{'OK'}, 0, "determined the public interface name: '$self->{public_interface_name}'\n" . format_data($network_configuration->{$self->{public_interface_name}}));
		return $self->{public_interface_name};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine the public interface name:\n" . format_data($network_configuration));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	if (!$condition || $condition eq 'assigned_public') {
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
			notify($ERRORS{'DEBUG'}, 0, "tie: both interfaces are/are not assigned a default gateway, proceeding to check if either is assigned the private IP address");
			return $self->_get_public_interface_name_helper($interface_name_1, $interface_name_2, 'matches_private');
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
	elsif ($condition eq 'matches_private') {
		# Get the computer private IP address
		my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
		if (!$computer_private_ip_address) {
			notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
			return;
		}
		
		my $matches_private_1 = (grep { $_ eq $computer_private_ip_address } @ip_addresses_1) ? 1 : 0;
		my $matches_private_2 = (grep { $_ eq $computer_private_ip_address } @ip_addresses_2) ? 1 : 0;
		
		if ($matches_private_1 eq $matches_private_2) {
			notify($ERRORS{'DEBUG'}, 0, "tie: both interfaces are/are not assigned the private IP address: $computer_private_ip_address, returning '$interface_name_1'");
			return $interface_name_1;
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
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine which interface is more likely the public interface, invalid \$condition argument: '$condition'");
		return;
	}
	
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	return $self->get_network_configuration()->{$self->get_private_interface_name()};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_network_configuration

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub get_public_network_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_network_configuration()->{$self->get_public_interface_name()};
}

#/////////////////////////////////////////////////////////////////////////////

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
	my $network_type = lc(shift()) || 'public';
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

#/////////////////////////////////////////////////////////////////////////////

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


#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_ip_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a 'public' or 'private' network type argument was specified
	# Assume 'public' if not specified
	my $network_type = lc(shift()) || 'public';
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
	
	my $ip_address_info = $network_configuration->{ip_address};
	if (!defined($ip_address_info)) {
		notify($ERRORS{'WARNING'}, 0, "$network_type network configuration info does not contain an 'ip_address' key");
		return;
	}
	
	# Return the first IP address listed
	my $ip_address = (sort keys(%$ip_address_info))[0];
	if ($ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "returning $network_type IP address: $ip_address");
		return $ip_address;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $network_type IP address, 'ip_address' value is not set in the network configuration info: \n" . format_data($network_configuration));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_private_ip_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_private_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_ip_address('private');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_address

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub get_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_ip_address('public');
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	my $network_type = lc(shift()) || 'public';
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 create_text_file

 Parameters  : $file_path, $file_contents
 Returns     : boolean
 Description : Creates a text file on the computer. The $file_contents
               string argument is converted to ASCII hex values. These values
               are echo'd on the computer which avoids problems with special
               characters and escaping. If the file already exists it is
               overwritten.

=cut

sub create_text_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $file_contents_string) = @_;
	if (!$file_contents_string) {
		notify($ERRORS{'WARNING'}, 0, "file contents argument was not supplied");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Replace Unix newlines with DOS/Windows newlines: \n --> \r\n
	$file_contents_string =~ s/\r?\n/\r\n/g;
	
	# Convert the string to a string containing the hex value of each character
	# This is done to avoid problems with special characters in the file contents
	
	# Split the string up into an array if integers representing each character's ASCII decimal value
	my @decimal_values = unpack("C*", $file_contents_string);
	
	# Convert the ASCII decimal values into hex values and add '\x' before each hex value
	my @hex_values = map { '\x' . sprintf("%x", $_) } @decimal_values;
	
	# Join the hex values together into a string
	my $hex_string = join('', @hex_values);
	
	# Create a command to echo the hex string to the file
	# Use -e to enable interpretation of backslash escapes
	my $command .= "echo -e \"$hex_string\" > $file_path";
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to create file on $computer_node_name: $file_path");
		return;
	}
	elsif ($exit_status != 0 || grep(/^\w+:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to create a file on $computer_node_name: $file_path, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "created file on $computer_node_name: $file_path");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional)
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the computer via SSH.

=cut

sub execute {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as an object method");
		return;
	}
	
	# Get the command argument
	my $command = shift;
	if (!$command) {
		notify($ERRORS{'WARNING'}, 0, "command argument was not specified");
		return;
	}
	
	# Get 2nd display output argument if supplied, or set default value
	my $display_output = shift || '0';
	
	# Get the computer node name
	my $computer_name = $self->data->get_computer_node_name() || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the command via SSH
	my ($exit_status, $output) = run_ssh_command($computer_name, $management_node_keys, $command, '', '', $display_output);
	if (defined($exit_status) && defined($output)) {
		if ($display_output) {
			notify($ERRORS{'OK'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		}
		return ($exit_status, $output);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on $computer_name: $command");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_os_type

 Parameters  : None
 Returns     : If successful: string
               If failed: false
 Description : Determines the OS type currently installed on the computer. It
               returns 'windows' or 'linux'.

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
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine OS type currently installed on $computer_node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine OS type currently installed on $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
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

#/////////////////////////////////////////////////////////////////////////////

sub manage_server_access {

	my $self = shift;
        if (ref($self) !~ /VCL::Module/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }

        my $computer_node_name = $self->data->get_computer_node_name() || return;
	my $reservation_id        = $self->data->get_reservation_id();
	my $server_request_id     = $self->data->get_server_request_id();
        my $server_request_admingroupid = $self->data->get_server_request_admingroupid();
        my $server_request_logingroupid = $self->data->get_server_request_logingroupid();

	#Build list of users.
	#If in admin group set admin flag
	#If in both login and admin group, only use admin setting
	#Check if user is in reserverationaccounts table, add user if needed
	#Check if user exists on server, add if needed
	
	my @userlist_admin;
	my @userlist_login;
	my %user_hash;
	my $ssh_allow_list;

	if ( $server_request_admingroupid ) {
		@userlist_admin = getusergroupmembers($server_request_admingroupid);
	}
	if ( $server_request_logingroupid ) {
		@userlist_login = getusergroupmembers($server_request_logingroupid);
	}	
	
	notify($ERRORS{'OK'}, 0, " admin list= @userlist_admin");
	notify($ERRORS{'OK'}, 0, " login list= @userlist_login");

	
	if ( scalar @userlist_admin > 0 ) {
		foreach my $str (@userlist_admin) {
			my ($username,$uid,$vcl_user_id) = split(/:/, $str);
			$user_hash{$uid}{"username"} = $username;
			$user_hash{$uid}{"uid"}	= $uid;
			$user_hash{$uid}{"vcl_user_id"}	= $vcl_user_id;
			$user_hash{$uid}{"rootaccess"} = 1;
			notify($ERRORS{'OK'}, 0, "adding admin $uid for $username ");
		}
	}		
	if ( scalar @userlist_login > 0 ) {
		foreach my $str (@userlist_login) {
			notify($ERRORS{'OK'}, 0, "admin str= $str");
			my ($username, $uid,$vcl_user_id) = split(/:/, $str);
			if (!exists($user_hash{$uid})) {
				$user_hash{$uid}{"username"} = $username;
				$user_hash{$uid}{"uid"}	= $uid;
				$user_hash{$uid}{"vcl_user_id"}	= $vcl_user_id;
				$user_hash{$uid}{"rootaccess"} = 2;
				notify($ERRORS{'OK'}, 0, "adding $uid for $username ");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$uid for $username exists in user_hash, skipping");
			}
		}
	}	

	#Collect users in reservationaccounts table
	my %res_accounts = get_reservation_accounts($reservation_id);
	my $not_standalone_list = "";
	my $standalone = 0;
	if(defined($ENV{management_node_info}{NOT_STANDALONE}) && $ENV{management_node_info}{NOT_STANDALONE}){
                $not_standalone_list = $ENV{management_node_info}{NOT_STANDALONE};
        }

	foreach my $userid (sort keys %user_hash) {
		next if (!($userid));
		if(!exists($res_accounts{$userid})){
			#check affiliation
			notify($ERRORS{'OK'}, 0, "checking affiliation for $userid");
			my $affiliation_name = get_user_affiliation($user_hash{$userid}{vcl_user_id}); 
			if(defined($affiliation_name)) {

				if(!(grep(/$affiliation_name/, split(/,/, $not_standalone_list) ))) {
					$standalone = 1;
				}
			}
			#IF standalone - generate password
			if($standalone) {
				$user_hash{$userid}{"passwd"} = getpw();
			}
			else {
				$user_hash{$userid}{"passwd"} = 0;
			}
			
			if (update_reservation_accounts($reservation_id,$user_hash{$userid}{vcl_user_id},$user_hash{$userid}{passwd})) {
				notify($ERRORS{'OK'}, 0, "Inserted $reservation_id,$user_hash{$userid}{vcl_user_id},$user_hash{$userid}{passwd} into reservationsaccounts table");
			
			}
			
			# Create user on the OS
			if($self->create_user($user_hash{$userid}{username},$user_hash{passwd},$userid,$user_hash{$userid}{rootaccess},$standalone)) {
				notify($ERRORS{'OK'}, 0, "Successfully created user $user_hash{$userid}{username} on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "Failed to create user on $computer_node_name ");
			}
			
			$ssh_allow_list .= " $user_hash{$userid}{username}";

		
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$userid exists in reservationaccounts table, assuming it exists on OS");
		}
			
	}
	notify($ERRORS{'OK'}, 0, "ssh_allow_list= $ssh_allow_list");

	$self->data->set_server_ssh_allow_users($ssh_allow_list);
	
	if ( $self->can("update_server_access") ) {
		if ( $self->update_server_access($ssh_allow_list) ) {
			notify($ERRORS{'OK'}, 0, "updated remote access list");
		}
	}
	
	return 1;

}

#///////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
