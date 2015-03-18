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
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::init);

# Specify the version of this module
our $VERSION = '2.4.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $INIT_DAEMON_ORDER

 Data type   : integer
 Value       : 10
 Description : Determines the order in which Linux init daemon modules are used.
               Lower values are used first.

=cut

our $INIT_DAEMON_ORDER = 10;

=head2 @REQUIRED_COMMANDS

 Data type   : array
 Values      : initctl
 Description : List of commands used within this module to configure and control
               Upstart services. This module will not be used if any of these
               commands are unavailable on the computer.

=cut

our @REQUIRED_COMMANDS = ('initctl');

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

=head2 get_service_names

 Parameters  : none
 Returns     : array
 Description : Calls 'initctl list' to retrieve the list of services controlled
               by Upstart on the computer.

=cut

sub get_service_names {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_info = {};
	
	my $command = "initctl list";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to list Upstart services on $computer_node_name");
		return;
	}
	
	# Format of initctl list output lines:
	# splash-manager stop/waiting
	# Add to hash then extract keys to remove duplicates
	my %service_name_hash;
	my %service_name_mappings_reversed = reverse %$SERVICE_NAME_MAPPINGS;
	for my $line (@$output) {
		my ($service_name) = $line =~ /^([^\s\t]+)/;
		next unless $service_name;
		$service_name_hash{$service_name} = 1 if $service_name;
		if (my $service_name_mapping = $service_name_mappings_reversed{$service_name}) {
			$service_name_hash{$service_name_mapping} = 1;
		}
	}
	my @service_names = sort(keys %service_name_hash);
	notify($ERRORS{'DEBUG'}, 0, "retrieved Upstart service names from $computer_node_name: " . join(", ", @service_names));
	return @service_names;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Stops the service if it is running. Deletes the
               '/etc/init/<$service_name>.conf' file.

=cut

sub delete_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name_argument = shift;
	if (!$service_name_argument) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	# Need to attempt to delete both the service with a name matching the argument as well as the mapped service name
	my @service_names = ($service_name_argument);
	
	# If a mapped service name also exists, attempt to delete it as well
	if ($SERVICE_NAME_MAPPINGS->{$service_name_argument}) {
		push @service_names, $SERVICE_NAME_MAPPINGS->{$service_name_argument};
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	for my $service_name (@service_names) {
		$self->stop_service($service_name) || return;
		
		# Delete the service configuration file
		my $service_file_path = "/etc/init/$service_name.conf";
		$self->os->delete_file($service_file_path) || return;
		
		notify($ERRORS{'DEBUG'}, 0, "deleted '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'initctl start <$service_name>' to start the service.

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
	my ($exit_status, $output) = $self->os->execute($command);
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
	elsif (grep(/running/i, @$output)) {
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
 Description : Calls 'initctl stop <$service_name>' to stop the service.

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name_argument = shift;
	if (!$service_name_argument) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	# Need to attempt to stop both the service with a name matching the argument as well as the mapped service name
	my @service_names = ($service_name_argument);
	
	# If a mapped service name also exists, attempt to stop it as well
	if ($SERVICE_NAME_MAPPINGS->{$service_name_argument}) {
		push @service_names, $SERVICE_NAME_MAPPINGS->{$service_name_argument};
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	for my $service_name (@service_names) {
		my $command = "initctl stop $service_name";
		my ($exit_status, $output) = $self->os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name");
			return;
		}
		elsif (grep(/Unknown job/i, @$output)) {
			# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
			notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
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
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'initctl restart <$service_name>' to restart the service.

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
	my ($exit_status, $output) = $self->os->execute($command);
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
 Description : Generates and configures '/etc/init/ext_ssh.conf' based off of
               the existing '/etc/init/ext_ssh.conf' file. Adds the ext_ssh
               service to the computer.

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
	my @sshd_service_file_contents = $self->os->get_file_contents($sshd_service_file_path);
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
	
	if (!$self->os->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->os->set_file_permissions($ext_sshd_service_file_path, '644')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions on ext_sshd service file to 644 on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 service_running

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'initctl status <$service_name>' to determine if the
               service is running.

=cut

sub service_running {
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
	
	my $command = "initctl status $service_name";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service is enabled on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown job/i, @$output)) {
		# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/running/i, @$output)) {
		# Output if the service is running: '<service name> start/running, process <PID>'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is running on $computer_node_name");
		return 1;
	}
	elsif (grep(/stop/i, @$output)) {
		# Output if the service is not running: '<service name>stop/waiting'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not running $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is running on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 service_enabled

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'initctl show-config <$service_name>' to determine if the
               service is enabled.

=cut

sub service_enabled {
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
	
	# Check if an override file exists and contains 'manual'
	my $service_override_file_path = "/etc/init/$service_name.override";
	if ($self->os->file_exists($service_override_file_path)) {
		my @override_file_contents = $self->os->get_file_contents($service_override_file_path);
		if (!@override_file_contents) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $service_override_file_path from $computer_node_name");
		}
		else {
			if (grep(/manual/i, @override_file_contents)) {
				notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not enabled on $computer_node_name, $service_override_file_path exists and contains 'manual'");
				return 0;
			}
		}
	}
	
	my $command = "initctl show-config $service_name";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service is enabled on $computer_node_name");
		return;
	}
	elsif (grep(/Unknown job/i, @$output)) {
		# Output if the service doesn't exist: 'initctl: Unknown job: <service name>'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/start on/i, @$output)) {
		# Output if the service is enabled:
		# <service name>
		#   start on (filesystem or runlevel [2345])
		#   stop on runlevel [!2345]
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is enabled on $computer_node_name");
		return 1;
	}
	elsif (!grep(/^initctl:/, @$output)) {
		# Output if the service is not enabled:
		# <service name>
		#   stop on runlevel [06]
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not enabled $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is enabled on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub enable_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_override_file_path = "/etc/init/$service_name.override";
	
	if (!$self->os->file_exists($service_override_file_path)) {
		return 1;
	}
	if ($self->os->delete_file($service_override_file_path)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to enable '$service_name' service, unable to delete override file: $service_override_file_path");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub disable_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_override_file_path = "/etc/init/$service_name.override";
	
	if ($self->os->create_text_file($service_override_file_path, "manual\n")) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to disable '$service_name' service, failed to create override file: $service_override_file_path");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
