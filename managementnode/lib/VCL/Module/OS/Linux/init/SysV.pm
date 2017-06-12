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

VCL::Module::OS::Linux::init::SysV.pm

=head1 DESCRIPTION

 This module provides VCL support for the SysV-style Linux init daemon used in
 distributions such as:
    Red Hat Enterprise Linux 5.x, 6.x
    CentOS 5.x, 6.x

=cut

###############################################################################
package VCL::Module::OS::Linux::init::SysV;

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
 Value       : 50
 Description : Determines the order in which Linux init daemon modules are used
               if an OS supports multiple init daemons. Lower values are used
               first. SysV has a higher value than other init modules because it
               is older than other, newer init daemons. The newer init daemon
               modules should be tried first.

=cut

our $INIT_DAEMON_ORDER = 50;

=head2 @REQUIRED_COMMANDS

 Data type   : array
 Values      : chkconfig, service
 Description : List of commands used within this module to configure and control
               SysV services. This module will not be used if any of these
               commands are unavailable on the computer.

=cut

our @REQUIRED_COMMANDS = ('chkconfig', 'service');

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 get_service_names

 Parameters  : none
 Returns     : array
 Description : Calls 'chkconfig --list' to retrieve the list of services
               controlled by SysV on the computer.

=cut

sub get_service_names {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "chkconfig --list";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to list SysV services on $computer_node_name");
		return;
	}
	
	# Format out chkconfig --list output lines:
	# Note: This output shows SysV services only and does not include native
	#    systemd services. SysV configuration data might be overridden by native
	#    ...
	# sshd            0:off   1:off   2:on    3:on    4:on    5:on    6:off
	my %service_name_hash;
	for my $line (@$output) {
		my ($service_name) = $line =~ /^([^\s\t]+)[\s\t]+\d/;
		$service_name_hash{$service_name} = 1 if $service_name;
	}
	my @service_names = sort(keys %service_name_hash);
	notify($ERRORS{'DEBUG'}, 0, "retrieved SysV service names from $computer_node_name: " . join(", ", @service_names));
	return @service_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig <$service_name> on' to configure the service to
               start automatically. Does not start the service.

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
	my $command = "chkconfig $service_name on";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to enable '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service httpdx: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/(failed|warn|error)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
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
 Description : Calls 'chkconfig <$service_name> off' to prevent the service from
               starting automatically. Does not stop the service.

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
	
	# Disable the service
	my $command = "chkconfig $service_name off";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to disable '$service_name' service on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service httpdx: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/(failed|warn|error)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable '$service_name' service on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "disabled '$service_name' service on $computer_node_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 service_enabled

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig --list <$service_name>' to determine if a
               service is enabled.

=cut

sub service_enabled {
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
	
	my $command = "chkconfig --list $service_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service is enabled on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service does not exist: 'error reading information on service httpdx: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/^$service_name\s+.*3:on/i, @$output)) {
		# Output if the service is enabled: '<service name>    0:off   1:off   2:on    3:on    4:on    5:on    6:off'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is enabled on $computer_node_name");
		return 1;
	}
	elsif (grep(/^$service_name\s+.*3:off/i, @$output)) {
		# Output if the service is disabled: '<service name>    0:off   1:off   2:off   3:off   4:off   5:off   6:off'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not enabled on $computer_node_name");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if '$service_name' service is enabled on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 service_running

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> status' to determine if a
               service is running.

=cut

sub service_running {
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
	my $command = "service $service_name status";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service is running on $computer_node_name: $command");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service does not exist: 'error reading information on service httpdx: No such file or directory'
		notify($ERRORS{'WARNING'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return;
	}
	elsif (grep(/(is running)/i, @$output)) {
		# Output if the service is running: '<service name> is running'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is running on $computer_node_name, output:\n" . join("\n", @$output));
		return 1;
	}
	elsif (grep(/(is not running|no\s.*process)/i, @$output)) {
		# Output if the service is not running: '<service name> is not running'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not running on $computer_node_name, output:\n" . join("\n", @$output));
		return 0;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "unable to determine if '$service_name' service is running on $computer_node_name based on output but exit status of $command is $exit_status, assuming service is running, output:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to determine if '$service_name' service is running on $computer_node_name based on output but exit status of $command is $exit_status, assuming service is NOT running, output:\n" . join("\n", @$output));
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig --add <$service_name>' to add the service
               specified by the argument. The service file must already reside
               in /etc/rc.d/init.d/.

=cut

sub add_service {
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
	
	# Add the service
	my $command = "chkconfig --add $service_name";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error|No such file)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "added '$service_name' service on $computer_node_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig --del <$service_name>' to delete the service
               specified by the argument. Deletes the service file from
               /etc/rc.d/init.d/.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Delete the service
	my $command = "chkconfig --del $service_name";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service xxx: No such file or directory'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	
	# Delete the service configuration file
	my $service_file_path = "/etc/rc.d/init.d/$service_name";
	if (!$self->os->delete_file($service_file_path)) {
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "deleted '$service_name' service on $computer_node_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> start' to start the service.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name start";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to start '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service xxx: No such file or directory'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
	}
	elsif (grep(/Starting $service_name:.*FAIL/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "started '$service_name' service on $computer_node_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> stop' to start the service.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name status ; service $service_name stop";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service xxx: No such file or directory'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return 1;
	}
	elsif (grep(/is stopped/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is already stopped on $computer_node_name");
		return 1;
	}
	elsif (grep(/Stopping $service_name:.*FAIL/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "stopped '$service_name' service on $computer_node_name, output:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'service <$service_name> restart' to start the service.

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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name restart";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to restart '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service xxx: No such file or directory'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
	}
	elsif (grep(/Starting $service_name:.*FAIL/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart '$service_name' service on $computer_node_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "restarted '$service_name' service on $computer_node_name, output:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_ext_sshd_service

 Parameters  : none
 Returns     : boolean
 Description : Adds the ext_sshd service to the computer. Generates and
               configures /etc/rc.d/init.d/ext_sshd based off of the existing
               /etc/rc.d/init.d/sshd file. Adds the ext_sshd service and
               configures it to start automatically.

=cut

sub add_ext_sshd_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $sshd_service_file_path          = '/etc/rc.d/init.d/sshd';
	my $sshd_service_file_path_original = '/etc/rc.d/init.d/sshd_original';
	my $ext_sshd_service_file_path      = '/etc/rc.d/init.d/ext_sshd';
	my $ext_sshd_config_file_path       = '/etc/ssh/external_sshd_config';
	
	# Get the contents of the sshd service startup file already on the computer
	my @sshd_service_file_lines = $self->os->get_file_contents($sshd_service_file_path);
	if (!@sshd_service_file_lines) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $sshd_service_file_path from $computer_node_name");
		return;
	}
	
	my $sshd_service_file_contents_original = join("\n", @sshd_service_file_lines);
	my $sshd_service_file_contents_updated = $sshd_service_file_contents_original;
	my $ext_sshd_service_file_contents = $sshd_service_file_contents_original;
	
	# Replace: OpenSSH --> externalOpenSSH
	$ext_sshd_service_file_contents =~ s|( OpenSSH)| external$1|g;
	
	# Replace: openssh-daemon --> external-openssh-daemon
	$ext_sshd_service_file_contents =~ s| (openssh-daemon)| external-$1|g;
	
	# Replace: sshd --> ext_sshd, exceptions:
	# /bin/sshd
	# /sshd_config
	# Note: pattern in look-behind assertion (?<!) must all be same length
	$ext_sshd_service_file_contents =~ s*(?<!(bin|pty)/)sshd(?!_config)*ext_sshd*g;
	
	# Replace: sshd_config --> external_sshd_config
	$ext_sshd_service_file_contents =~ s|(?:ext_)?(sshd_config)|external_$1|g;
	
	# Add config file path argument to '$SSHD $OPTIONS'
	$ext_sshd_service_file_contents =~ s|(\$SSHD)\s+(\$OPTIONS)|$1 -f $ext_sshd_config_file_path $2|g;
	
	# Replace:
	#    'pidfileofproc $SSHD' --> 'pidfileofproc $prog'
	#    'killproc $SSHD' --> 'killproc $prog'
	#    'status $SSHD' --> 'status $prog'
	$ext_sshd_service_file_contents =~ s/(pidfileofproc|killproc|status)\s+\$SSHD/$1 \$prog/g;
	
	# Update the sshd file as well or else 'service sshd status' will always report sshd is running if ext_sshd is running
	# The status line has to be: 'status -p $PID_FILE openssh-daemon'
	$sshd_service_file_contents_updated =~ s/(status)\s+.*/$1 -p \$PID_FILE openssh-daemon/g;
	
	# Check if any changes were made to the original sshd file
	if ($sshd_service_file_contents_updated ne $sshd_service_file_contents_original) {
		# Save a copy of the original sshd file if the backup doesn't already exist
		if (!$self->os->file_exists($sshd_service_file_path_original)) {
			$self->os->copy_file($sshd_service_file_path, $sshd_service_file_path_original);
		}
		
		if (!$self->os->create_text_file($sshd_service_file_path, $sshd_service_file_contents_updated)) {
			notify($ERRORS{'WARNING'}, 0, "failed to update sshd service file on $computer_node_name: $sshd_service_file_path");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "sshd service file on $computer_node_name does not need to be updated");
	}
	
	if (!$self->os->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->os->set_file_permissions($ext_sshd_service_file_path, '755')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions on ext_sshd service file to 755 on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	# Add the service
	return unless $self->add_service('ext_sshd');
	
	return $self->enable_service('ext_sshd');
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
