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
use Net::SSH::Expect;

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : $arguments->{end_state}
 Returns     : boolean
 Description : Performs the tasks common to all OS's that must be done to the
               computer prior to capturing an image:
               -Check if the computer is responding to SSH
               -If not responding, check if computer is powered on
               -Power on computer if powered off and wait for SSH to respond
               -Create currentimage.txt file

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
	
	# Create the currentimage.txt file
	if (!$self->create_currentimage_txt()) {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt on $computer_node_name");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "completed common image capture preparation tasks");
	return 1;
}

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

	my $computer_node_name   = $self->data->get_computer_node_name();

	# Attempt to retrieve the contents of currentimage.txt
	my $cat_command = "cat ~/currentimage.txt";
	my ($cat_exit_status, $cat_output) = $self->execute($cat_command);
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
				 respond to SSH $ssh_elapsed_seconds seconds ($ssh_actual_seconds seconds after ping)");
		return 1;
	}
	
	# If loop completed, maximum number of reboot attempts was reached
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name reboot failed");
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
		my ($exit_status, $output) = $self->execute({
			node => $computer_node_name,
			command => "echo \"testing ssh on $computer_node_name\"",
			max_attempts => $max_attempts,
			display_output => 0,
			timeout_seconds => 30,
			ignore_error => 1,
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
	
	# insertloadlog($reservation_id, $computer_id, "osrespond", "$computer_node_name is responding to SSH after $duration seconds");
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
		
		# Update the Datastructure and computer table if the retrieved IP address does not match what is in the database
		if ($computer_ip_address ne $public_ip_address) {
			$self->data->set_computer_ip_address($public_ip_address);
			
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
		if ($check_interface_name =~ /^(lo|sit\d)$/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its name is '$1'");
			next INTERFACE;
		}
		elsif ($check_interface_name =~ /(loopback|vmnet|afs|tunnel|6to4|isatap|teredo)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its name contains '$1'");
			next INTERFACE;
		}
		elsif ($description =~ /(loopback|virtual|afs|tunnel|pseudo|6to4|isatap)/i) {
			notify($ERRORS{'DEBUG'}, 0, "interface '$check_interface_name' ignored because its description contains '$1'");
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
	
	my $private_interface_name = $self->get_private_interface_name();
	if (!$private_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private network configuration, private interface name could not be determined");
		return;
	}
	
	return $self->get_network_configuration()->{$private_interface_name};
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
	
	my $public_interface_name = $self->get_public_interface_name();
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve public network configuration, public interface name could not be determined");
		return;
	}
	
	return $self->get_network_configuration()->{$public_interface_name};
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

 Parameters  : $file_path, $file_contents, $no_correct_line_endings (optional)
 Returns     : boolean
 Description : Creates a text file on the computer. The $file_contents
               string argument is converted to ASCII hex values. These values
               are echo'd on the computer which avoids problems with special
               characters and escaping. If the file already exists it is
               overwritten.
               The line endings within the $file_contents string are corrected
               by default to Windows-style (\r\n) or Linux-style (\n) depending
               on the OS. An optional boolean 3rd argument can be specified to
               prevent the string from being altered.

=cut

sub create_text_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $file_contents_string, $concatenate) = @_;
	if (!$file_contents_string) {
		notify($ERRORS{'WARNING'}, 0, "file contents argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $image_os_type = $self->data->get_image_os_type();
	
	# Attempt to create the parent directory if it does not exist
	if ($self->can('create_directory')) {
		my $parent_directory_path = parent_directory_path($file_path);
		$self->create_directory($parent_directory_path) if $parent_directory_path;
	}
	
	# Remove Windows-style carriage returns if the image OS isn't Windows
	if ($image_os_type =~ /windows/) {
		$file_contents_string =~ s/\r*\n/\r\n/g;
	}
	else {
		$file_contents_string =~ s/\r//g;
	}
	
	# Convert the string to a string containing the hex value of each character
	# This is done to avoid problems with special characters in the file contents
	
	# Split the string up into an array if integers representing each character's ASCII decimal value
	my @decimal_values = unpack("C*", $file_contents_string);
	
	# Convert the ASCII decimal values into hex values and add '\x' before each hex value
	my @hex_values = map { '\x' . sprintf("%x", $_) } @decimal_values;
	
	# Join the hex values together into a string
	my $hex_string = join('', @hex_values);
	
	# Enclose the file path in quotes if it contains any spaces
	if ($file_path =~ / /) {
		$file_path = "\"$file_path\"";
	}
	
	# Create a command to echo the hex string to the file
	# Use -e to enable interpretation of backslash escapes
	my $command .= "echo -n -e \"$hex_string\"";
	if ($concatenate) {
		$command .= " >> $file_path";
	}
	else {
		$command .= " > $file_path";
	}
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to create file on $computer_node_name: $file_path");
		return;
	}
	elsif ($exit_status != 0 || grep(/^\w+:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to create a file on $computer_node_name:\ncommand: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "created file on $computer_node_name: $file_path");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_file_contents

 Parameters  : $file_path
 Returns     : array
 Description : Returns an array containing the contents of the file specified by
               the file path argument. Each array element contains a line from
               the file.

=cut

sub get_file_contents {
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
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Run cat to retrieve the contents of the file
	my $command = "cat \"$path\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to read file on $computer_short_name:\n path: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^cat: /, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to read contents of file on $computer_short_name: '$path', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved " . scalar(@$output) . " lines from file on $computer_short_name: '$path'");
		map { s/[\r\n]+$//g; } (@$output);
		return @$output;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional)
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the computer via SSH.

=cut

sub execute {
return execute_new(@_);
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

=head2 execute_new

 Parameters  : $computer_name (conditional), $command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the computer via SSH.

=cut

sub execute_new {
	my ($argument) = @_;
	my ($computer_name, $command, $display_output, $timeout_seconds, $max_attempts, $port, $user, $password, $identity_key, $ignore_error);
	
	# Check if this subroutine was called as an object method
	if (ref($argument) && ref($argument) =~ /VCL::Module/) {
		# Subroutine was called as an object method ($self->execute)
		my $self = shift;
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
			$timeout_seconds = $argument->{timeout};
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
	
	$display_output = 0 unless $display_output;
	$timeout_seconds = 60 unless $timeout_seconds;
	$max_attempts = 3 unless $max_attempts;
	$port = 22 unless $port;
	$user = 'root' unless $user;
	
	my $ssh_options = '-o StrictHostKeyChecking=no -o ConnectTimeout=30';
	
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
			delete $ENV{net_ssh_expect}{$computer_name};
			
			notify($ERRORS{'DEBUG'}, 0, $attempt_string . "sleeping for $attempt_delay seconds before making next attempt");
			sleep $attempt_delay;
		}
		
		$attempt++;
		$attempt_string = "attempt $attempt/$max_attempts: " if ($attempt > 1);
		
		# Calling 'return' in the EVAL block doesn't exit this subroutine
		# Use a flag to determine if null should be returned without making another attempt
		my $return_null;
		
		if (!$ENV{net_ssh_expect}{$computer_name}) {
			eval {
				$ssh = Net::SSH::Expect->new(
					host => $computer_name,
					user => $user,
					port => $port,
					raw_pty => 1,
					no_terminal => 1,
					ssh_option => $ssh_options,
					#timeout => 5,
				);
				
				if ($ssh) {
					notify($ERRORS{'DEBUG'}, 0, "created " . ref($ssh) . " object to control $computer_name, options: $ssh_options") if ($display_output);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to create Net::SSH::Expect object to control $computer_name, $!");
					next ATTEMPT;
				}
				
				if (!$ssh->run_ssh()) {
					notify($ERRORS{'WARNING'}, 0, ref($ssh) . " object failed to fork SSH process to control $computer_name, $!");
					next ATTEMPT;
				}
				
				#$ssh->exec("stty -echo");
				#$ssh->exec("stty raw -echo");
				
				# Set the timeout counter behaviour:
				# If true, sets the timeout to "inactivity timeout"
				# If false sets it to "absolute timeout"
				#$ssh->restart_timeout_upon_receive(1);
				my $initialization_output = $ssh->read_all();
				if (defined($initialization_output)) {
					notify($ERRORS{'DEBUG'}, 0, "SSH initialization output:\n$initialization_output") if ($display_output);
					if ($initialization_output =~ /password:/i) {
						if (defined($password)) {
							notify($ERRORS{'WARNING'}, 0, "$attempt_string unable to connect to $computer_name, SSH is requesting a password but password authentication is not implemented, password is configured, output:\n$initialization_output");
							
							# In EVAL block here, 'return' won't return from entire subroutine, set flag
							$return_null = 1;
							return;
						}
						else {
							notify($ERRORS{'WARNING'}, 0, "$attempt_string unable to connect to $computer_name, SSH is requesting a password but password authentication is not implemented, password is not configured, output:\n$initialization_output");
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
					notify($ERRORS{'DEBUG'}, 0, $attempt_string . "$1 error occurred initializing Net::SSH::Expect object for $computer_name") if ($display_output);
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, $attempt_string . "$EVAL_ERROR error occurred initializing Net::SSH::Expect object for $computer_name") if ($display_output);
				}
				next ATTEMPT;
			}
		}
		else {
			$ssh = $ENV{net_ssh_expect}{$computer_name};
			
			# Delete the stored SSH object to make sure it isn't saved if the command fails
			# The SSH object will be added back to %ENV if the command completes successfully
			delete $ENV{net_ssh_expect}{$computer_name};
		}
		
		# Set the timeout
		$ssh->timeout($timeout_seconds);
		
		(my $command_formatted = $command) =~ s/\s+(;|&|&&)\s+/\n$1 /g;
		notify($ERRORS{'DEBUG'}, 0, $attempt_string . "executing command on $computer_name (timeout: $timeout_seconds seconds):\n$command_formatted") if ($display_output);
		$ssh->send($command . ' 2>&1 ; echo exitstatus:$?');
		
		my $ssh_wait_status;
		eval {
			$ssh_wait_status = $ssh->waitfor('exitstatus:[0-9]+', $timeout_seconds);
		};
		
		if ($EVAL_ERROR) {
			if ($ignore_error) {
				notify($ERRORS{'DEBUG'}, 0, "executed command on $computer_name: '$command', ignoring error, returning null") if ($display_output);
				return;
			}
			elsif ($EVAL_ERROR =~ /^(\w+) at \//) {
				notify($ERRORS{'WARNING'}, 0, $attempt_string . "$1 error occurred executing command on $computer_name: '$command'") if ($display_output);
			}
			else {
				notify($ERRORS{'WARNING'}, 0, $attempt_string . "error occurred executing command on $computer_name: '$command'\nerror: $EVAL_ERROR") if ($display_output);
			}
			next ATTEMPT;
		}
		elsif (!$ssh_wait_status) {
			notify($ERRORS{'WARNING'}, 0, $attempt_string . "command timed out after $timeout_seconds seconds on $computer_name: '$command'") if ($display_output);
			next ATTEMPT;
		}
		
		my $output = $ssh->before() || '';
		$output =~ s/(^\s+)|(\s+$)//g;
		
		my $exit_status_string = $ssh->match() || '';
		my ($exit_status) = $exit_status_string =~ /(\d+)/;
		if (!$exit_status_string || !defined($exit_status)) {
			my $all_output = $ssh->read_all() || '';
			notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to determine exit status from string: '$exit_status_string', output:\n$all_output");
			next ATTEMPT;
		}
		
		my @output_lines = split(/[\r\n]+/, $output);
		
		notify($ERRORS{'OK'}, 0, "executed command on $computer_name: '$command', exit status: $exit_status, output:\n$output") if ($display_output);
		
		# Save the SSH object for later use
		$ENV{net_ssh_expect}{$computer_name} = $ssh;
		
		return ($exit_status, \@output_lines);
	}
	
	notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to execute command on $computer_name: '$command'") if ($display_output);
	return;
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

=head2 manage_server_access

 Parameters  : None
 Returns     : 
 Description : 

=cut

sub manage_server_access {

	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name          = $self->data->get_computer_node_name() || return;
	my $reservation_id              = $self->data->get_reservation_id();
	my $server_request_id           = $self->data->get_server_request_id();
	my $server_request_admingroupid = $self->data->get_server_request_admingroupid();
	my $server_request_logingroupid = $self->data->get_server_request_logingroupid();
	my $user_login_id_owner         = $self->data->get_user_login_id();
	my $user_id_owner		           = $self->data->get_user_id();
	my $image_os_type 		= $self->data->get_image_os_type();

	# Build list of users.
	# If in admin group set admin flag
	# If in both login and admin group, only use admin setting
	# Check if user is in reserverationaccounts table, add user if needed
	# Check if user exists on server, add if needed
	
	my @userlist_admin;
	my @userlist_login;
	my %user_hash;
	my $allow_list = '';

	if ($server_request_admingroupid) {
		@userlist_admin = getusergroupmembers($server_request_admingroupid);
	}
	if ($server_request_logingroupid) {
		@userlist_login = getusergroupmembers($server_request_logingroupid);
	}	
	
	notify($ERRORS{'OK'}, 0, " admin login list= @userlist_admin");
	notify($ERRORS{'OK'}, 0, " nonadmin login list= @userlist_login");
	
	if (scalar @userlist_admin > 0) {
		foreach my $str (@userlist_admin) {
			my ($username,$uid,$vcl_user_id) = 0;
			($username,$uid,$vcl_user_id) = split(/:/, $str);
			my ($correct_username, $user_domain) = split /@/, $username;
         $user_hash{$vcl_user_id}{"username"} = $correct_username;
			$user_hash{$vcl_user_id}{"uid"} = $uid;
			$user_hash{$vcl_user_id}{"vcl_user_id"} = $vcl_user_id;
			$user_hash{$vcl_user_id}{"rootaccess"} = 1;
			notify($ERRORS{'DEBUG'}, 0, "adding admin vcl_user_id= $vcl_user_id uid= $uid for $username ");
		}
	}		
	if (scalar @userlist_login > 0) {
		foreach my $str (@userlist_login) {
			notify($ERRORS{'OK'}, 0, "nonadmin user str= $str");
			my ($username, $uid,$vcl_user_id) = 0;
			($username, $uid,$vcl_user_id) = split(/:/, $str);
			my ($correct_username, $user_domain) = split /@/, $username;
			if (!exists($user_hash{$uid})) {
				$user_hash{$vcl_user_id}{"username"} = $correct_username;
				$user_hash{$vcl_user_id}{"uid"}	= $uid;
				$user_hash{$vcl_user_id}{"vcl_user_id"}	= $vcl_user_id;
				$user_hash{$vcl_user_id}{"rootaccess"} = 2;
				notify($ERRORS{'DEBUG'}, 0, "adding $vcl_user_id for $username ");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$vcl_user_id for $username exists in user_hash, skipping");
			}
		}
	}	

	# Collect users in reservationaccounts table
	my %res_accounts = get_reservation_accounts($reservation_id);
	my $not_standalone_list = $self->data->get_management_node_not_standalone();

	#Add users
	foreach my $userid (sort keys %user_hash) {
		next if (!($userid));
		#Skip reservation owner, this account is processed in the new and reserved states
		notify($ERRORS{'DEBUG'}, 0, "userid= $userid  user_id_owner= $user_id_owner ");
		if ($userid eq $user_id_owner) {
			$allow_list .= " $user_hash{$userid}{username}";
			next;
		}
		my $standalone = 0;
		if(!exists($res_accounts{$userid})){
			# check affiliation
			notify($ERRORS{'DEBUG'}, 0, "checking affiliation for $userid");
			my $affiliation_name = get_user_affiliation($user_hash{$userid}{vcl_user_id}); 
			if(defined($affiliation_name)) {

				if(!(grep(/$affiliation_name/, split(/,/, $not_standalone_list) ))) {
					$standalone = 1;
				}
			}
			
			$user_hash{$userid}{"passwd"} = 0;
			# Generate password if linux and standalone affiliation
			unless ($image_os_type =~ /linux/ && !$standalone) {
				$user_hash{$userid}{"passwd"} = getpw();
			}
			
			if (update_reservation_accounts($reservation_id,$userid,$user_hash{$userid}{passwd},"add")) {
				notify($ERRORS{'OK'}, 0, "Inserted $reservation_id,$userid,$user_hash{$userid}{passwd} into reservationsaccounts table");
			}
			
			# Create user on the OS
			if($self->create_user($user_hash{$userid}{username},$user_hash{$userid}{passwd},$user_hash{$userid}{uid},$user_hash{$userid}{rootaccess},$standalone)) {
				notify($ERRORS{'OK'}, 0, "Successfully created user $user_hash{$userid}{username} on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "Failed to create user on $computer_node_name ");
			}
			
			$allow_list .= " $user_hash{$userid}{username}";

		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$userid exists in reservationaccounts table, assuming it exists on OS");
		}
			
	}

	#Remove anyone listed in reservationaccounts list that is not in user_hash
	foreach my $res_userid (sort keys %res_accounts) {
		notify($ERRORS{'OK'}, 0, "res_userid= $res_userid username= $res_accounts{$res_userid}{username}");
		#Skip reservation owner, this account is processed in the new and reserved states
      if ($res_userid eq $user_login_id_owner) {
			$allow_list .= " $res_accounts{$res_userid}{username}";
			next;
		}
		if(!exists($user_hash{$res_userid})) {
				 notify($ERRORS{'OK'}, 0, "username= $res_accounts{$res_userid}{username} is not listed in reservationsaccounts, attempting to delete");
				  #Delete from reservationaccounts
				  if (update_reservation_accounts($reservation_id,$res_accounts{$res_userid}{userid},0,"delete")) {
						  notify($ERRORS{'OK'}, 0, "Deleted $reservation_id,$res_accounts{$res_userid}{userid} from reservationsaccounts table");
				  }
				  #Delete from OS
				  if($self->delete_user($res_accounts{$res_userid}{username},0,0)) {
					  notify($ERRORS{'OK'}, 0, "Successfully removed user= $res_accounts{$res_userid}{username}");	
				  }	
				next;
		}
		$allow_list .= " $res_accounts{$res_userid}{username}";
	}
	
	notify($ERRORS{'OK'}, 0, "allow_list= $allow_list");
	
	$self->data->set_server_allow_users($allow_list);
	
	if ($self->can("update_server_access") ) {
		if ( $self->update_server_access($allow_list) ) {
			notify($ERRORS{'OK'}, 0, "updated remote access list");
		}
	}
	
	return 1;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 process_connect_methods

 Parameters  : none
 Returns     : boolean
 Description : Processes the connect methods configured for the image revision.

=cut

sub process_connect_methods {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $imagerevision_id   = $self->data->get_imagerevision_id();
	
	# Retrieve the connect method info hash
	my $connect_method_info = get_connect_method_info($imagerevision_id);
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "no connect methods are configured for image revision $imagerevision_id");
		return;
	}
	
	my $remote_ip = shift;
	if (!$remote_ip) {
		notify($ERRORS{'OK'}, 0, "reservation remote IP address is not defined, connect methods will be available from any IP address");
		$remote_ip = '0.0.0.0/0';
	}
	elsif ($remote_ip =~ /any/i){
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
	
	my $state = $self->data->get_request_state_name();
	notify($ERRORS{'DEBUG'}, 0, "state = $state");
	
	
	CONNECT_METHOD: for my $connect_method_id (sort keys %{$connect_method_info} ) {
		notify($ERRORS{'DEBUG'}, 0, "processing connect method:\n" . format_data($connect_method_info->{$connect_method_id}));
		
		my $name            = $connect_method_info->{$connect_method_id}{name};
		my $description     = $connect_method_info->{$connect_method_id}{description};
		my $protocol        = $connect_method_info->{$connect_method_id}{protocol} || 'TCP';
		my $port            = $connect_method_info->{$connect_method_id}{port};
		my $service_name    = $connect_method_info->{$connect_method_id}{servicename};
		my $startup_script  = $connect_method_info->{$connect_method_id}{startupscript};
		my $install_script  = $connect_method_info->{$connect_method_id}{installscript};
		my $disabled        = $connect_method_info->{$connect_method_id}{connectmethodmap}{disabled};

		if( $state =~ /deleted|timeout/) {
			$disabled = 1;
		}
		
		if ($disabled) {
			if ($self->service_exists($service_name)) {
               notify($ERRORS{'DEBUG'}, 0, "attempting to stop '$service_name' service for '$name' connect method on $computer_node_name");
               if ($self->stop_service($service_name)) {
                  notify($ERRORS{'OK'}, 0, "'$service_name' stop on $computer_node_name");
               }
               else {
                  notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service for '$name' connect method on $computer_node_name");
               }
         }
			
			#Disable firewall port
			if (defined($port)) {
            notify($ERRORS{'DEBUG'}, 0, "attempting to close firewall port $port on $computer_node_name for '$name' connect method");
            if ($self->disable_firewall_port($protocol, $port, $remote_ip, 1)) {
               notify($ERRORS{'OK'}, 0, "closing firewall port $port on $computer_node_name for $remote_ip $name connect method");
            }
            else {
               notify($ERRORS{'WARNING'}, 0, "failed to close firewall port $port on $computer_node_name for $remote_ip $name connect method");
            }
         }
			
		}
		else {
			# Attempt to start and configure the connect method
			my $service_started = 0;
			
			# Attempt to start the service if the service name has been defined for the connect method
			if ($service_name) {
				# Check if service exists
				notify($ERRORS{'DEBUG'}, 0, "checking if '$service_name' service exists for '$name' connect method on $computer_node_name");
				if ($self->service_exists($service_name)) {
					notify($ERRORS{'DEBUG'}, 0, "attempting to start '$service_name' service for '$name' connect method on $computer_node_name");
					if ($self->start_service($service_name)) {
						notify($ERRORS{'OK'}, 0, "'$service_name' started on $computer_node_name");
						$service_started = 1;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service for '$name' connect method on $computer_node_name");
					}
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "'$service_name' service for '$name' connect method does NOT exist on $computer_node_name, connect method install script is not defined");
				}
			}
			
			# Run the startup script if the service is not started
			if (!$service_started && defined($startup_script)) {
				notify($ERRORS{'DEBUG'}, 0, "attempting to run startup script '$startup_script' for '$name' connect method on $computer_node_name");
				my ($startup_exit_status, $startup_output) = $self->execute($startup_script, 1);
				if (!defined($startup_output)) {
					notify($ERRORS{'WARNING'}, 0, "failed to run command to execute startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script'");
				}
				elsif ($startup_exit_status == 0){
					notify($ERRORS{'OK'}, 0, "executed startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script', exit status: $startup_exit_status, output:\n" . join("\n", @$startup_output));	
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to execute startup script '$startup_script' for '$name' connect method on $computer_node_name, command: '$startup_script', exit status: $startup_exit_status, output:\n" . join("\n", @$startup_output));
				}
			}
			
			# Open the firewall port
			if (defined($port)) {
				notify($ERRORS{'DEBUG'}, 0, "attempting to open firewall port $port on $computer_node_name for '$name' connect method");
				if ($self->enable_firewall_port($protocol, $port, $remote_ip, 1)) {
					notify($ERRORS{'OK'}, 0, "opened firewall port $port on $computer_node_name for $remote_ip $name connect method");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to open firewall port $port on $computer_node_name for $remote_ip $name connect method");
				}
			}
		}
	}

	return 1;	
}

#/////////////////////////////////////////////////////////////////////////////

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
	my $time_limit = shift;
	if ( !$time_limit ) {
		notify($ERRORS{'WARNING'}, 0, "time_limit variable not passed as an argument");
		return "failed";
	}

	my $request_id           = $self->data->get_request_id();	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $request_state_name	 = $self->data->get_request_state_name();
	my $user_unityid         = $self->data->get_user_login_id();
	my $connect_methods      = $self->data->get_connect_methods();	
	
	my $start_time    = time();
	my $timeout_time  = ($start_time + ($time_limit * 60));
	my $time_exceeded = 0;
	my $break         = 0;
	my $ret_val       = "no";

	# Figure out number of loops for log messages
	while (!$break) {
		notify($ERRORS{'OK'}, 0, "checking for connection by $user_unityid on $computer_node_name");
		
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "user has deleted request");
			$break   = 1;
			$ret_val = "deleted";
			return $ret_val;
		}
		
		$time_exceeded = time_exceeded($start_time, $time_limit);
		if ($time_exceeded) {
			notify($ERRORS{'OK'}, 0, "$time_limit minute time limit exceeded begin cleanup process");
			# time_exceeded, begin cleanup process
			$break = 1;
			if ($request_state_name =~ /reserved/) {
				notify($ERRORS{'OK'}, 0, "user never logged in returning nologin");
				$ret_val = "nologin";
			}
			else {
				$ret_val = "timeout";
			}
			return $ret_val;
		} ## end if ($time_exceeded)
		else {    # time not exceeded check for connection
			foreach my $CMid (sort keys %{$connect_methods} ) {
				if($self->can("check_connection_on_port")) {
					if(defined($$connect_methods{$CMid}{port}) && $$connect_methods{$CMid}{port}) {
						my $connect_state = $self->check_connection_on_port($$connect_methods{$CMid}{port});
						if($connect_state =~ /(connected|conn_wrong_ip|timeout|failed)/i){
						 	return $connect_state	
						}
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "port not defined for connectMethod id $CMid");
					}
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "OS module does not support check_connection_on_port: " . ref($self));
					return;
				}
			}
		}
		
		my $current_time = time();
		my $seconds_elapsed = ($current_time - $start_time);
		my $seconds_until_timeout = ($timeout_time - $current_time);
		
		notify($ERRORS{'DEBUG'}, 0, "$user_unityid has not connected to $computer_node_name ($seconds_elapsed/$seconds_until_timeout seconds elapsed/remaining), sleeping for 15 seconds");
		sleep 15;
	}
	return $ret_val;
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	# Normalize the source and destination paths
	$source_file_path = normalize_file_path($source_file_path);
	$destination_file_path = normalize_file_path($destination_file_path);
	
	# Escape all spaces in the path
	my $escaped_source_path = escape_file_path($source_file_path);
	my $escaped_destination_path = escape_file_path($destination_file_path);
	
	# Make sure the source and destination paths are different
	if ($escaped_source_path eq $escaped_destination_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy file, source and destination file path arguments are the same: $escaped_source_path");
		return;
	}
	
	# Get the destination parent directory path and create the directory if it does not exist
	my $destination_directory_path = parent_directory_path($destination_file_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_file_path");
		return;
	}
	$self->create_directory($destination_directory_path) || return;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Execute the command to copy the file
	my $command = "cp -fr $escaped_source_path $escaped_destination_path";
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy file on $computer_node_name: '$source_file_path' -> '$destination_file_path'");
	my ($exit_status, $output) = $self->execute($command);
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 find_files

 Parameters  : $base_directory_path, $file_pattern, $search_type (optional)
 Returns     : array
 Description : Finds files under the base directory and any subdirectories path
               matching the file pattern. The search is not case sensitive. An
               array is returned containing matching file paths.
               
               A third argument can be supplied specifying the search type.
               
               If 'regex' is supplied, the $file_pattern argument is assumed to
               be a regular expression.

=cut

sub find_files {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my ($base_directory_path, $file_pattern, $search_type) = @_;
	if (!$base_directory_path || !$file_pattern) {
		notify($ERRORS{'WARNING'}, 0, "base directory path and file pattern arguments were not specified");
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
		my $command = "$find_command \"$base_directory_path\"";
		
		if ($search_type) {
			if ($search_type =~ /regex/i) {
				$command .= " -type f -iregex \"$file_pattern\"";
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "invalid search type argument was specified: '$search_type'");
				return;
			}
		}
		else {
			$command .= " -type f -iname \"$file_pattern\"";
		}
		
		notify($ERRORS{'DEBUG'}, 0, "attempting to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command: $command");
		
		my ($exit_status, $output) = $self->execute($command, 0);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command:\n$command");
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
			notify($ERRORS{'WARNING'}, 0, "error occurred attempting to find files on $computer_node_name\nbase directory path: $base_directory_path\npattern: $file_pattern\ncommand: $command\noutput:\n" . join("\n", @$output));
			return;
		}
		
		my @files;
		LINE: for my $line (@$output) {
			push @files, $line;
		}
		
		my $file_count = scalar(@files);
		
		notify($ERRORS{'DEBUG'}, 0, "files found: $file_count, base directory: '$base_directory_path', pattern: '$file_pattern'\ncommand: '$command', output:\n" . join("\n", @$output));
		return @files;
	}
	
	return;
}

#/////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->execute($command);
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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_tools_file_paths

 Parameters  : $pattern
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

#///////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
