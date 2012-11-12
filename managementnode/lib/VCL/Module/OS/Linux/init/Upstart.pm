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

VCL::Module::OS::Linux::init::Upstart.pm

=head1 DESCRIPTION

 This module provides VCL support for the Upstart Linux init daemon used in
 distributions including:
 Ubuntu 6.10+

=cut

##############################################################################
package VCL::Module::OS::Linux::init::Upstart;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SERVICE_NAME_MAPPINGS

 Data type   : hash reference
 Description : Contains a mapping of common service names to the names used by
					Upstart distibutions. Example, sshd is called ssh on Ubuntu.

=cut

our $SERVICE_NAME_MAPPINGS = {
	'sshd' => 'ssh',
	'ext_sshd' => 'ext_ssh',
};

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : 

=cut

sub initialize {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check to see if required commands exist
	my @required_commands = (
		'initctl',
	);
	
	my @missing_commands;
	for my $command (@required_commands) {
		if (!$self->command_exists($command)) {
			push @missing_commands, $command;
		}
	}
	
	if (@missing_commands) {
		notify($ERRORS{'DEBUG'}, 0, "unable to initialize Upstart Linux init module to control $computer_node_name, the following commands are not available:\n" . join("\n", @missing_commands));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Upstart Linux init module successfully initialized to control $computer_node_name");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "Upstart Linux init module successfully initialized to control $computer_node_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 service_exists

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $command = "initctl list";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service exists on $computer_node_name");
		return;
	}
	elsif (grep(/^$service_name[\s\t]/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig --del' to delete the service specified by the
               argument. Deletes the service file from /etc/rc.d/init.d/.

=cut

sub delete_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	$self->stop_service($service_name) || return;
	
	# Delete the service configuration file
	my $service_file_path = "/etc/init/$service_name.conf";
	$self->delete_file($service_file_path) || return;
	
	notify($ERRORS{'DEBUG'}, 0, "deleted '$service_name' service on $computer_node_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub start_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "initctl start $service_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to start '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown job/i, @$output)) {
		# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/already running/i, @$output)) {
		# Output if the service is already running: 'initctl: Job is already running: <service name>'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' is already running on $computer_node_name");
		return 1;
	}
	elsif (grep(/process \d+/i, @$output)) {
		# Output if the service was started: '<service name> start/running, process <PID>'
		notify($ERRORS{'DEBUG'}, 0, "started '$service_name' service on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "initctl stop $service_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown job/i, @$output)) {
		# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return 1;
	}
	elsif (grep(/Unknown instance/i, @$output)) {
		# Output if the service is not running: 'initctl: Unknown instance:'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' is already stopped on $computer_node_name");
		return 1;
	}
	elsif (grep(/ stop\//i, @$output)) {
		# Output if the service was stopped: '<service name> stop/waiting'
		notify($ERRORS{'DEBUG'}, 0, "stopped '$service_name' service on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub restart_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "initctl restart $service_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to restart '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown job/i, @$output)) {
		# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown instance/i, @$output)) {
		# Output if the service is not running: 'initctl: Unknown instance:'
		return $self->start_service($service_name);
	}
	elsif (grep(/process \d+/i, @$output)) {
		# Output if the service was restarted: '<service name> start/running, process <PID>'
		notify($ERRORS{'DEBUG'}, 0, "restarted '$service_name' service on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to restart '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_ext_sshd_service

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub add_ext_sshd_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $sshd_service_file_path     = '/etc/init/ssh.conf';
	my $ext_sshd_service_file_path = '/etc/init/ext_ssh.conf';
	my $ext_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	
	# Get the contents of the sshd service startup file already on the computer
	my @sshd_service_file_contents = $self->get_file_contents($sshd_service_file_path);
	if (!@sshd_service_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $sshd_service_file_path from $computer_node_name");
		return;
	}
	
	my $ext_sshd_service_file_contents = join("\n", @sshd_service_file_contents);
	
	# Replace: OpenSSH --> external OpenSSH
	$ext_sshd_service_file_contents =~ s|(OpenSSH)|external $1|g;
	
	# Replace: ' ssh ' --> ' ext_ssh '
	$ext_sshd_service_file_contents =~ s| ssh | ext_ssh |g;
	
	# Add config file path argument
	$ext_sshd_service_file_contents =~ s|(exec.*/sshd .*)|$1 -f $ext_sshd_config_file_path|g;
	
	# Replace /var/run/sshd --> /var/run/ext_sshd
	$ext_sshd_service_file_contents =~ s|(/var/run/)sshd|$1ext_sshd|g;
	
	if (!$self->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->set_file_permissions($ext_sshd_service_file_path, '644')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions on ext_sshd service file to 644 on $computer_node_name: $ext_sshd_service_file_path");
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
