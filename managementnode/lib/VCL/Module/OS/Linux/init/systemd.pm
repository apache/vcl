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

###############################################################################
package VCL::Module::OS::Linux::init::systemd;

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
 Value       : 20
 Description : Determines the order in which Linux init daemon modules are used.
               Lower values are used first.

=cut

our $INIT_DAEMON_ORDER = 20;

=head2 @REQUIRED_COMMANDS

 Data type   : array
 Values      : systemctl
 Description : List of commands used within this module to configure and control
               systemd services. This module will not be used if any of these
               commands are unavailable on the computer.

=cut

our @REQUIRED_COMMANDS = ('systemctl');

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 get_service_names

 Parameters  : none
 Returns     : array
 Description : Calls 'systemctl list-unit-files' to retrieve the list of
               services controlled by systemd on the computer.

=cut

sub get_service_names {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl --no-pager list-unit-files";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve systemd service names on $computer_node_name");
		return;
	}
	
	# Format of systemctl list output lines:
	# ssyslog.target                          static
	# Add to hash then extract keys to remove duplicates
	my %service_name_hash;
	for my $line (@$output) {
		my ($service_name) = $line =~ /^(.+)\.service/;
		$service_name_hash{$service_name} = 1 if $service_name;
	}
	my @service_names = sort(keys %service_name_hash);
	notify($ERRORS{'DEBUG'}, 0, "retrieved systemd service names from $computer_node_name: " . join(", ", @service_names));
	return @service_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 service_running

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl is-active' to determines if a service is
               running.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl is-active $service_name.service";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if $service_name service is running on $computer_node_name");
		return;
	}
	
	# Output should either be 'active' or 'inactive
	if (grep(/inactive/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$service_name service is not running on $computer_node_name");
		return 0;
	}
	elsif (grep(/active/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$service_name service is running on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if $service_name service is running on $computer_node_name, output does not contain 'active' or 'inactive':\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 service_enabled

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'systemctl is-enabled' to determines if a service is
               enabled.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl is-enabled $service_name.service";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if $service_name service is running on $computer_node_name");
		return;
	}
	
	# Output should either be 'enabled' or 'disabled
	if (grep(/disabled/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$service_name service is disabled on $computer_node_name");
		return 0;
	}
	elsif (grep(/enabled/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$service_name service is enabled on $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if $service_name service is enabled on $computer_node_name, output does not contain 'enabled' or 'disabled':\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
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
		notify($ERRORS{'WARNING'}, 0, "failed to enable '$service_name' service on $computer_node_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "enabled '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
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

#//////////////////////////////////////////////////////////////////////////////

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
	$self->stop_service($service_name) || return;
	$self->disable_service($service_name) || return;
	
	# Delete the service configuration file
	my $service_file_path = "/lib/systemd/system/$service_name.service";
	if (!$self->os->delete_file($service_file_path)) {
		return;
	}
	
	$self->_daemon_reload();
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
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

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(Failed to issue method call|No such file)/i, @$output)) {
		# Output if the service doesn't exist
		# Failed to issue method call: Unit httpdx.service failed to load: No such file or directory.
		notify($ERRORS{'DEBUG'}, 0, "unable to stop '$service_name' service because it does not exist on $computer_node_name");
		return 1;
	}
	elsif (grep(/(not loaded)/i, @$output)) {
		# Output if the service isn't loaded
		# Failed to stop ext_ssh.service: Unit ext_ssh.service not loaded.
		notify($ERRORS{'DEBUG'}, 0, "unable to stop '$service_name' service because it is not loaded $computer_node_name");
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

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Get the unit file path for the sshd service
	# Do not automatically assume it is /lib/systemd/system/sshd.service
	# https://issues.apache.org/jira/browse/VCL-989
	my $sshd_service_file_path = $self->_get_service_unit_file_path('sshd');
	if (!$sshd_service_file_path) {
		$sshd_service_file_path = '/lib/systemd/system/sshd.service';
	}
	
	# Hard-code the ext_sshd file path (intentional)
	my $ext_sshd_service_file_path = '/lib/systemd/system/ext_sshd.service';
	
	# Get the contents of the sshd service configuration file already on the computer
	my @sshd_service_file_contents = $self->os->get_file_contents($sshd_service_file_path);
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
	$ext_sshd_service_file_contents =~ s|(?<!bin/)sshd(?!_config\|-keygen)|ext_sshd|g;
	
	# Remove ExecStart options variables
	# ExecStart=/usr/sbin/sshd -D $OPTIONS
	# ExecStart=/usr/sbin/sshd -D $SSHD_OPTS
	$ext_sshd_service_file_contents =~ s/^\s*(ExecStart=.+\S)\s+\$\S*OPT\S*(.*)$/$1$2/gm;
	
	# Remove explicit -f arguments from ExecStart line
	$ext_sshd_service_file_contents =~ s/^\s*(ExecStart=.+\S)\s+-f\s+\S+(.*)$/$1$2/gm;
	
	# Add -f argument to ExecStart line
	$ext_sshd_service_file_contents =~ s|^\s*(ExecStart=.+\S)\s*$|$1 -f /etc/ssh/external_sshd_config|gm;
	
	# Set EnvironmentFile to /dev/null, service won't start if the file doesn't exist
	$ext_sshd_service_file_contents =~ s|(EnvironmentFile)=.*|$1=/dev/null|g;
	
	# Remove Alias= line which may exist in ssh_config:
	# Alias=ext_sshd.service
	# Otherwise, this may occur when attempting to enable the service if the service is named the same as the alias:
	# Failed to execute operation: Too many levels of symbolic links
	$ext_sshd_service_file_contents =~ s/^\s*Alias=.*//gm;
	
	# Add explicit lines, remove first to avoid duplicates:
	$ext_sshd_service_file_contents =~ s/^\s*(Restart|RestartSec|StartLimitInterval)=.*\n?//gm;
	
	# Attempt to restart if the service dies
	$ext_sshd_service_file_contents =~ s/(\[Service\])/$1\nRestart=on-failure/gm;
	$ext_sshd_service_file_contents =~ s/(\[Service\])/$1\nRestartSec=3s/gm;
	
	# (VCL-1027) Add StartLimitInterval=0 under [Service] to prevent:
	#    Job for ext_sshd.service failed because start of the service was attempted too often
	$ext_sshd_service_file_contents =~ s/(\[Service\])/$1\nStartLimitInterval=0/gm;
	
	notify($ERRORS{'DEBUG'}, 0, "$ext_sshd_service_file_path:\n$ext_sshd_service_file_contents");
	
	if (!$self->os->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->os->set_file_permissions($ext_sshd_service_file_path, '644')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions of ext_sshd service file to 644 on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	$self->_daemon_reload();
	
	return $self->enable_service('ext_sshd');
}

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
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

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_service_unit_file_path

 Parameters  : $service_name
 Returns     : string
 Description : Determines the unit file for the service specified by the
               argument. This is needed because the file name is not always
               $service_name.service. This is the case when a service has alias
               names configured such as the ssh and sshd services on Ubuntu 16.
               The file path for the sshd service is ssh.service.

=cut

sub _get_service_unit_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "systemctl show $service_name.service --property=FragmentPath";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve unit file path for $service_name service on $computer_node_name: $command");
		return;
	}
	elsif ($exit_status ne 0 || grep(/(failed)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve unit file path for $service_name service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Expected output:
	# FragmentPath=/lib/systemd/system/ssh.service
	my ($file_path_line) = grep(/FragmentPath=/, @$output);
	if (!$file_path_line) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve unit file path for $service_name service on $computer_node_name, output does not contain a 'FragmentPath=' line, output:\n" . join("\n", @$output));
		return;
	}
	
	my ($file_path) = $file_path_line =~ /FragmentPath=(.+)\s*$/g;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve unit file path for $service_name service on $computer_node_name, failed to parse 'FragmentPath=' line, output:\n" . join("\n", @$output));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved unit file path for $service_name service on $computer_node_name: $file_path");
	return $file_path
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
