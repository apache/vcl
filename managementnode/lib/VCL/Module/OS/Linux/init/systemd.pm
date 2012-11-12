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

VCL::Module::OS::Linux::init::systemd.pm

=head1 DESCRIPTION

 This module provides VCL support for the systemd Linux init daemon used in
 distributions such as:
 Fedora 15+
 openSUSE 12.1+

=cut

##############################################################################
package VCL::Module::OS::Linux::init::systemd;

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
		'systemctl',
	);
	
	my @missing_commands;
	for my $command (@required_commands) {
		if (!$self->command_exists($command)) {
			push @missing_commands, $command;
		}
	}
	
	if (@missing_commands) {
		notify($ERRORS{'DEBUG'}, 0, "unable to initialize systemd Linux init module to control $computer_node_name, the following commands are not available:\n" . join("\n", @missing_commands));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "systemd Linux init module successfully initialized to control $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 service_exists

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl list-unit-files' the output is parsed to
               determine if the service exists.

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	my $command = "systemctl --no-pager list-unit-files";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service exists on $computer_node_name");
		return;
	}
	
	if (grep(/^$service_name\.service/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists on $computer_node_name");
		return 1;
	}
	elsif (grep(/\.service/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service exists, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl enable' to enable the service specified by the
               argument.

=cut

sub enable_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Enable the service
	my $command = "systemctl --no-reload enable $service_name.service";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to enable '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'Failed to issue method call: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "unable to enable '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "enabled '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl disable' to disable the service specified by the
					argument.

=cut

sub disable_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl --no-reload disable $service_name.service";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to disable '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'Failed to issue method call: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "unable to disable '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "disabled '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Disables the service and deletes the service file from
               /lib/systemd/system/.

=cut

sub delete_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Disable the service before deleting it
	if ($self->service_exists($service_name)) {
		$self->stop_service($service_name) || return;
		$self->disable_service($service_name) || return;
	}
	
	# Delete the service configuration file
	my $service_file_path = "/lib/systemd/system/$service_name.service";
	if (!$self->delete_file($service_file_path)) {
		return;
	}
	
	$self->_daemon_reload();
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl start' to start the service specified by the
               argument.

=cut

sub start_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# start the service
	my $command = "systemctl start $service_name.service";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to start '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist
		# Failed to issue method call: Unit httpdx.service failed to load: No such file or directory.
		notify($ERRORS{'WARNING'}, 0, "unable to start '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "started '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl stop' to stop the service specified by the
               argument.

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# stop the service
	my $command = "systemctl stop $service_name.service";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist
		# Failed to issue method call: Unit httpdx.service failed to load: No such file or directory.
		notify($ERRORS{'WARNING'}, 0, "unable to stop '$service_name' service because it does not exist on $computer_node_name");
		return 1;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "stopped '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl restart' to restart the service specified by the
               argument.

=cut

sub restart_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Restart the service
	my $command = "systemctl restart $service_name.service";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to restart '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist
		# Failed to issue method call: Unit httpdx.service failed to load: No such file or directory.
		notify($ERRORS{'WARNING'}, 0, "unable to restart '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "restarted '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_ext_sshd_service

 Parameters  : none
 Returns     : boolean
 Description : Constructs the ext_sshd service configuration file:
               /lib/systemd/system/ext_sshd.service

=cut

sub add_ext_sshd_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $sshd_service_file_path     = '/lib/systemd/system/sshd.service';
	my $ext_sshd_service_file_path = '/lib/systemd/system/ext_sshd.service';
	
	# Get the contents of the sshd service configuration file already on the computer
	my @sshd_service_file_contents = $self->get_file_contents($sshd_service_file_path);
	if (!@sshd_service_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $sshd_service_file_path from $computer_node_name");
		return;
	}
	
	my $ext_sshd_service_file_contents = join("\n", @sshd_service_file_contents);
	
	# Replace: OpenSSH --> External OpenSSH
	$ext_sshd_service_file_contents =~ s|(OpenSSH)|external $1|g;
	
	# Replace: sshd --> ext_sshd, exceptions:
	# /bin/sshd
	# /sshd_config
	$ext_sshd_service_file_contents =~ s|(?<!bin/)sshd(?!_config)|ext_sshd|g;
	
	# Replace: $OPTIONS --> -f /etc/ssh/external_sshd_config
	$ext_sshd_service_file_contents =~ s|(ExecStart=.+)\s+\$OPTIONS|$1 -f /etc/ssh/external_sshd_config|g;
	
	# Set EnvironmentFile to /dev/null, service won't start if the file doesn't exist
	$ext_sshd_service_file_contents =~ s|(EnvironmentFile)=.*|$1=/dev/null|g;
	
	$ext_sshd_service_file_contents .= "\n";
	
	if (!$self->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->set_file_permissions($ext_sshd_service_file_path, '644')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions of ext_sshd service file to 644 on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	$self->_daemon_reload();
	
	return $self->enable_service('ext_sshd');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _daemon_reload

 Parameters  : none
 Returns     : boolean
 Description : Runs 'systemctl --system daemon-reload'. This is necessary when
               adding or deleting services or else systemctl will complain:
               Warning: Unit file changed on disk, 'systemctl --system daemon-reload' recommended.

=cut

sub _daemon_reload {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl --system daemon-reload";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to reload systemd manager configuration on $computer_node_name: $command");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to reload systemd manager configuration on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "reloaded systemd manager configuration on $computer_node_name");
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
