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

###############################################################################
package VCL::Module::OS::Linux::init::Upstart;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::init);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

###############################################################################

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

=head2 @PROHIBITED_COMMANDS

 Data type   : array
 Values      : initctl
 Description : List of commands that must not exist on the computer if the
					Upstart.pm module is to be used. This array contains:
					'chkconfig'.

=cut

our @PROHIBITED_COMMANDS = ('chkconfig');

=head2 $SERVICE_NAME_MAPPINGS

 Data type   : hash reference
 Description : Contains a mapping of common service names to the names used by
               Upstart distibutions. Example, sshd is called ssh on Ubuntu.

=cut

our $SERVICE_NAME_MAPPINGS = {
	'sshd' => 'ssh',
	'ext_sshd' => 'ext_ssh',
};

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $service_info = $self->_get_service_info() || {};
	return sort keys %$service_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_service_info

 Parameters  : $use_cache (optional)
 Returns     : hash reference
 Description : Calls 'initctl list' to retrieve the list of services controlled
               by Upstart on the computer. Also calls 'service --status-all' to
               determine SysV-style services controlled by Upstart. A hash
               reference is returned. Hash keys are service names. Values are
               either 'initctl' or 'service' indicating if Upstart's initctl
               command can be used to control the service or the service command
               must be used:
                  {
                    "acpid" => "initctl",
                    "open-vm-tools" => "service",
                    "ssh" => "initctl",
                    "sshd" => "initctl",
                    "xrdp" => "service"
                  }
               By default, the service info is retrieved every time this
               subroutine is called. To use cached info, the $use_cache argument
               must be explicitely set to true.

=cut

sub _get_service_info {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $use_cache = shift;
	if ($use_cache && defined($self->{service_info})) {
		return $self->{service_info};
	}
	else {
		$self->{service_info} = {};
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my %service_name_mappings_reversed = reverse %$SERVICE_NAME_MAPPINGS;
	
	my $initctl_command = "initctl list";
	my ($initctl_exit_status, $initctl_output) = $self->os->execute($initctl_command, 0);
	if (!defined($initctl_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to list Upstart services on $computer_node_name");
		return;
	}
	elsif (grep(/Connection refused/i, @$initctl_output)) {
		# Ubuntu 16 and later display the following:
		#    initctl: Unable to connect to Upstart: Failed to connect to socket /com/ubuntu/upstart: Connection refused
		notify($ERRORS{'DEBUG'}, 0, "initctl command cannot be used to retrieve list of all services on $computer_node_name, command: '$initctl_command', output:\n" . join("\n", @$initctl_output));
	}
	elsif ($initctl_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve list of all services on $computer_node_name using the initctl command, exit status: $initctl_exit_status, command:\n$initctl_command\noutput:\n" . join("\n", @$initctl_output));
		return;
	}
	else {
		# Format of initctl list output lines:
		#    splash-manager stop/waiting
		#    network-interface-security (network-interface/eth1) start/running
		#    tty1 start/running, process 1400
		for my $line (@$initctl_output) {
			my ($service_name) = $line =~ /^([^\s\t]+)/;
			if ($service_name) {
				#notify($ERRORS{'DEBUG'}, 0, "found '$service_name' service via '$initctl_command', line: '$line'");
				$self->{service_info}{$service_name} = 'initctl';
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to parse service name on $computer_node_name, command: '$initctl_command', line: '$line', output:\n" . join("\n", @$initctl_output));
			}
		}
	}
	
	# VCL-966
	# Legacy SysV-style services are not reported by 'initctl list'
	# The SysV.pm module cannot control these services becuase the chkconfig command is not available on Ubuntu
	
	my $service_command = "service --status-all";
	my ($service_exit_status, $service_output) = $self->os->execute($service_command);
	if (!defined($service_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve list of all services on $computer_node_name using the service command: $service_command");
		return;
	}
	elsif ($service_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve list of all services on $computer_node_name using the service command, exit status: $service_exit_status, command:\n$service_command\noutput:\n" . join("\n", @$service_output));
	}
	else {
		# Lines should be formatted as:
		#    [ + ]  acpid
		#    [ ? ]  apport
		#    [ - ]  dbus
		for my $line (@$service_output) {
			my ($service_name) = $line =~ /\]\s*(\S+)\s*$/;
			if ($service_name) {
				# The service utility method of controlling services is a fallback
				# Don't add if previously found by initctl list
				if (!defined($self->{service_info}{$service_name})) {
					#notify($ERRORS{'DEBUG'}, 0, "found '$service_name' service via '$service_command', line: '$line'");
					$self->{service_info}{$service_name} = 'service';
				}
			}
			else {
				#notify($ERRORS{'WARNING'}, 0, "failed to parse service name on $computer_node_name, command: '$service_command', line: '" . string_to_ascii($line) . "'\noutput:\n" . join("\n", @$service_output));
			}
		}
	}
	
	for my $service_name (keys %{$self->{service_info}}) {
		my $service_name_mapping = $service_name_mappings_reversed{$service_name};
		if ($service_name_mapping) {
			$self->{service_info}{$service_name_mapping} = $self->{service_info}{$service_name};
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved services info from $computer_node_name:\n" . format_data($self->{service_info}));
	return $self->{service_info};
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Check if initctl cannot be used to control service
	if ($self->_controlled_by_service_command($service_name)) {
		return $self->_call_service_start($service_name);
	}
	
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	$service_name = $SERVICE_NAME_MAPPINGS->{$service_name} || $service_name;
	
	# Check if initctl cannot be used to control service
	if ($self->_controlled_by_service_command($service_name)) {
		return $self->_call_service_stop($service_name);
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
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
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Check if initctl cannot be used to control service
	if ($self->_controlled_by_service_command($service_name)) {
		return $self->_call_service_restart($service_name);
	}
	
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Check if initctl cannot be used to control service
	if ($self->_controlled_by_service_command($service_name)) {
		return $self->_call_service_status($service_name);
	}
	
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 _controlled_by_service_command

 Parameters  : $service_name
 Returns     : boolean
 Description : Returns true if the service exists but cannot be controlled by
               the 'initctl' command. The 'service' command must be used for
               basic service control.

=cut

sub _controlled_by_service_command {
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
	
	my $service_info = $self->_get_service_info(1) || return;
	if ($service_info->{$service_name} && $service_info->{$service_name} eq 'service') {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service cannot be controlled by the initctl command, the service command will be used");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service will be controlled by the initctl command");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _call_service_start

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> start' to start a service that
               can't be controlled by initctl.

=cut

sub _call_service_start {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_command = "service $service_name start";
	my ($service_exit_status, $service_output) = $self->os->execute($service_command);
	if (!defined($service_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to start '$service_name' service on $computer_node_name using the service command: $service_command");
		return;
	}
	elsif ($service_exit_status eq '0' || grep(/done/, @$service_output)) {
		notify($ERRORS{'OK'}, 0, "started '$service_name' service on $computer_node_name using the service command: '$service_command', output:\n" . join("\n", @$service_output));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service on $computer_node_name using the service command, exit status: $service_exit_status, command:\n$service_command\noutput:\n" . join("\n", @$service_output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _call_service_stop

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> stop' to stop a service that
               can't be controlled by initctl.

=cut

sub _call_service_stop {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_command = "service $service_name stop";
	my ($service_exit_status, $service_output) = $self->os->execute($service_command);
	if (!defined($service_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name using the service command: $service_command");
		return;
	}
	elsif ($service_exit_status eq '0' || grep(/done/, @$service_output)) {
		notify($ERRORS{'OK'}, 0, "stopped '$service_name' service on $computer_node_name using the service command: '$service_command', output:\n" . join("\n", @$service_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service on $computer_node_name using the service command, exit status: $service_exit_status, command:\n$service_command\noutput:\n" . join("\n", @$service_output));
		return;
	}
	
	# Try to fix common xRDP bug on Ubuntu, service start/stop/restart often leaves behind the .pid file
	# Service can't be completly restarted until file is manually deleted
	my @pid_files = $self->os->find_files('/var/run', "$service_name.pid", 1, 'f');
	if (scalar(@pid_files) == 1) {
		my $pid_file = $pid_files[0];
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' may not have cleaned up .pid file when service was stopped, attempting to delete file: $pid_file");
		$self->os->delete_file($pid_file)
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _call_service_restart

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> stop' and then
					'service <$service_name> start' to restart a service that can't
					be controlled by initctl.

=cut

sub _call_service_restart {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_command = "service $service_name restart";
	my ($service_exit_status, $service_output) = $self->os->execute($service_command);
	if (!defined($service_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to restart '$service_name' service on $computer_node_name using the service command: $service_command");
		return;
	}
	elsif ($service_exit_status eq '0' || grep(/done/, @$service_output)) {
		notify($ERRORS{'OK'}, 0, "restarted '$service_name' service on $computer_node_name using the service command: '$service_command', output:\n" . join("\n", @$service_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to restart '$service_name' service on $computer_node_name using the service command, exit status: $service_exit_status, command:\n$service_command\noutput:\n" . join("\n", @$service_output));
		return;
	}
	
	if ($self->_call_service_status($service_name)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not seem to be running after restarting it, attempting to stop and start service");
		$self->_call_service_stop($service_name);
		$self->_call_service_start($service_name);
		return $self->_call_service_status($service_name);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _call_service_status

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> status' to get the status of a
               service that can't be controlled by initctl.

=cut

sub _call_service_status {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $service_command = "service $service_name status";
	my ($service_exit_status, $service_output) = $self->os->execute($service_command);
	if (!defined($service_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve status of '$service_name' service on $computer_node_name using the service command: $service_command");
		return;
	}
	
	# Output if service is running:
	# * Checking status of Remote Desktop Protocol server xrdp
	#   ...done.
	# * Checking status of RDP Session Manager sesman
	#   ...done.
	
	# Output if service is stopped:
	# * Checking status of Remote Desktop Protocol server xrdp
	#   ...fail!
	# * Checking status of RDP Session Manager sesman
	#   ...fail!
	
	if (grep(/done/, @$service_output) && !grep(/fail/, @$service_output)) {
		notify($ERRORS{'OK'}, 0, "'$service_name' service is running on $computer_node_name, output of '$service_command':\n" . join("\n", @$service_output));
		return 1;
	}
	elsif (grep(/fail/, @$service_output)) {
		notify($ERRORS{'OK'}, 0, "'$service_name' service is NOT running on $computer_node_name, output of '$service_command':\n" . join("\n", @$service_output));
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if '$service_name' service is running on $computer_node_name using the service command, output does not contain 'done' or 'fail', exit status: $service_exit_status, command:\n$service_command\noutput:\n" . join("\n", @$service_output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
