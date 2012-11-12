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

##############################################################################
package VCL::Module::OS::Linux::init::SysV;

# Specify the lib path using FindBin
use FindBin;
print "$FindBin::Bin/../../../.." . "\n\n";
exit;

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
 Returns     : true
 Description : 

=cut

sub initialize {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Don't do anything, this is the default init module
	# It should be used if all others can't be initialized
	
	notify($ERRORS{'DEBUG'}, 0, "SysV Linux init module successfully initialized to control $computer_node_name");
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
	my $command = "chkconfig --list";
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

=head2 enable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

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
	my ($exit_status, $output) = $self->execute($command, 0);
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

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

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
	my ($exit_status, $output) = $self->execute($command, 0);
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

#/////////////////////////////////////////////////////////////////////////////

=head2 add_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Calls 'chkconfig --add' to add the service specified by the
               argument. The service file must already reside in
               /etc/rc.d/init.d/.

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
	my ($exit_status, $output) = $self->execute($command);
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Delete the service
	my $command = "chkconfig --del $service_name";
	my ($exit_status, $output) = $self->execute($command);
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
	if (!$self->delete_file($service_file_path)) {
		return;
	}
	
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name start";
	my ($exit_status, $output) = $self->execute($command);
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name stop";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop '$service_name' service on $computer_node_name");
		return;
	}
	elsif (grep(/(error reading information|No such file)/i, @$output)) {
		# Output if the service doesn't exist: 'error reading information on service xxx: No such file or directory'
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
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
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "service $service_name restart";
	my ($exit_status, $output) = $self->execute($command);
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
	
	my $sshd_service_file_path     = '/etc/rc.d/init.d/sshd';
	my $ext_sshd_service_file_path = '/etc/rc.d/init.d/ext_sshd';
	my $ext_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	
	# Get the contents of the sshd service startup file already on the computer
	my @sshd_service_file_contents = $self->get_file_contents($sshd_service_file_path);
	if (!@sshd_service_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $sshd_service_file_path from $computer_node_name");
		return;
	}
	
	my $ext_sshd_service_file_contents = join("\n", @sshd_service_file_contents);
	
	# Replace: OpenSSH --> externalOpenSSH
	$ext_sshd_service_file_contents =~ s|( OpenSSH)| external$1|g;
	
	# Replace: openssh-daemon --> external-openssh-daemon
	$ext_sshd_service_file_contents =~ s| (openssh-daemon)| external-$1|g;
	
	# Replace: sshd --> ext_sshd, exceptions:
	# /bin/sshd
	# /sshd_config
	$ext_sshd_service_file_contents =~ s|(?<!bin/)sshd(?!_config)|ext_sshd|g;
	
	# Replace: sshd_config --> external_sshd_config
	$ext_sshd_service_file_contents =~ s|(?:ext_)?(sshd_config)|external_$1|g;
	
	# Add config file path argument to '$SSHD $OPTIONS'
	$ext_sshd_service_file_contents =~ s|(\$SSHD)\s+(\$OPTIONS)|$1 -f $ext_sshd_config_file_path $2|g;
	
	# Replace 'pidfileofproc $SSHD' and 'killproc $SSHD'
	$ext_sshd_service_file_contents =~ s/(pidfileofproc|killproc)\s+\$SSHD/$1 \$prog/g;
	
	if (!$self->create_text_file($ext_sshd_service_file_path, $ext_sshd_service_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create ext_sshd service file on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	if (!$self->set_file_permissions($ext_sshd_service_file_path, '755')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions on ext_sshd service file to 755 on $computer_node_name: $ext_sshd_service_file_path");
		return;
	}
	
	# Add the service
	return unless $self->add_service('ext_sshd');
	
	return $self->enable_service('ext_sshd');
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
