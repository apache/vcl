#!/usr/bin/perl -w

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

##############################################################################
# $Id: SSH.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::Utils::SSH

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::Utils::SSH;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(
  &ssh
);

use VCL::Module::Utils::Logging;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 ssh

 Parameters  :
 Returns     :
 Description :

=cut


sub ssh {
	my ($node, $identity_path, $command, $user, $port) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($node) || !$node) {
		log_warning("computer node was not specified");
		return 0;
	}
	if (!defined($identity_path) || !$identity_path) {
		log_warning("identity file path was not specified");
		return 0;
	}
	if (!defined($command) || !$command) {
		log_warning("command was not specified");
		return 0;
	}

	# Set default values if not passed as an argument
	$user = "root" if (!defined($user));
	$port = 22     if (!defined($port));


	# TODO: Add ssh path to config file and set global variable
	# Locate the path to the ssh binary
	my @possible_ssh_paths = ('ssh.exe', 'ssh', 'C:/cygwin/bin/ssh.exe', 'D:/cygwin/bin/ssh.exe', '/usr/bin/ssh',);

	my $ssh_path;
	for my $possible_ssh_path (@possible_ssh_paths) {
		if (-x $possible_ssh_path) {
			$ssh_path = $possible_ssh_path;
			last;
		}
	}
	if (!$ssh_path) {
		log_warning("unable to locate the SSH executable");
		return 0;
	}

	# Print the configuration if $VERBOSE
	log_verbose("node: $node, identity file path: $identity_path, user: $user, port: $port caller info $package, $filename, $line, $sub");
	log_verbose("command: $command");

	# Assemble the SSH command
	# -i <identity_file>, Selects the file from which the identity (private key) for RSA authentication is read.
	# -l <login_name>, Specifies the user to log in as on the remote machine.
	# -p <port>, Port to connect to on the remote host.
	# -x, Disables X11 forwarding.
	# Dont use: -q, Quiet mode.  Causes all warning and diagnostic messages to be suppressed.
	my $ssh_command = "$ssh_path -i '$identity_path' -l $user -p $port -x $node \"$command\"";

	# Redirect standard output and error output so all messages are captured
	$ssh_command .= ' 2>&1';

	# Print the command if $VERBOSE
	log_verbose("ssh command: $ssh_command");

	# Execute the command
	my $ssh_output = `$ssh_command` || 'ssh did not produce any output';

	# Save the exit status
	# For some reason the ssh exit status is right-padded with 8 0's
	# Shift right 8 bits to get the real value
	my $ssh_exit_status = $? >> 8;

	# Print the exit status and output if $VERBOSE
	log_verbose("ssh exit status: $ssh_exit_status, output:\n$ssh_output");

	# Check the exit status
	# ssh exits with the exit status of the remote command or with 255 if an error occurred.
	if ($ssh_exit_status == 255) {
		log_warning("failed to execute ssh command, exit status: $ssh_exit_status, ssh exits with the exit status of the remote command or with 255 if an error occurred, output:\n$ssh_output");
		return ();
	}
	elsif ($ssh_exit_status > 0) {
		log_warning("most likely failed to execute ssh command, exit status: $ssh_exit_status, output:\n$ssh_output");
		return ();
	}

	# Split the output up into an array of lines
	my @output_lines = split(/\n/, $ssh_output);

	# Return the exit status and output
	return ($ssh_exit_status, \@output_lines);

} ## end sub ssh

1;
