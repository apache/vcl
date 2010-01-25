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
our $VERSION = '2.00';

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

=head2 set_provisioner

 Parameters  : None
 Returns     : Process's provisioner object
 Description : Sets the provisioner object for the OS module to access.

=cut

sub set_provisioner {
	my $self = shift;
	my $provisioner = shift;
	$self->{provisioner} = $provisioner;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 provisioner

 Parameters  : None
 Returns     : Process's provisioner object
 Description : Allows OS modules to access the reservation's provisioner
               object.

=cut

sub provisioner {
	my $self = shift;
	
	if (!$self->{provisioner}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return provisioner object, \$self->{provisioner} is not set");
		return;
	}
	else {
		return $self->{provisioner};
	}
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

 Parameters  : None
 Returns     : If computer responds to SSH: 1
               If computer never responds to SSH: 0
 Description : Checks if the reservation computer is responding to SSH.

=cut

sub is_ssh_responding {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Try nmap to see if any of the ssh ports are open before attempting to run a test command
	if (!nmap_port($computer_node_name, 22) && !nmap_port($computer_node_name, 24)) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, port 22 or 24 are not open");
		return 0;
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
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is responding to SSH");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, SSH command failed");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_response

 Parameters  : Initial delay seconds (optional), SSH response timeout seconds (optional)
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $initial_delay_seconds = shift;
	if (!defined $initial_delay_seconds) {
		$initial_delay_seconds = 120;
	}
	
	my $ssh_response_timeout_seconds = shift;
	if (!defined $ssh_response_timeout_seconds) {
		$ssh_response_timeout_seconds = 600;
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
	if (!$self->wait_for_ssh($ssh_response_timeout_seconds)) {
		notify($ERRORS{'WARNING'}, 0, "failed to connect to $computer_node_name via SSH after $ssh_response_timeout_seconds seconds");
		return;
	}
	
	my $end_time = time();
	my $duration = ($end_time - $start_time);
	
	notify($ERRORS{'OK'}, 0, "$computer_node_name is responding to SSH after $duration seconds");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
