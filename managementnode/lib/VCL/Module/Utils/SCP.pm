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
# $Id: SCP.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::Utils::SCP

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::Utils::SCP;

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
  &scp
);

use File::Basename;
use VCL::Module::Utils::Logging;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 scp

 Parameters  :
 Returns     :
 Description :

=cut


sub scp {
	my $options_hashref = shift;

	my $options       = $options_hashref->{options};
	my $cipher        = $options_hashref->{cipter};
	my $ssh_config    = $options_hashref->{ssh_config};
	my $identity_file = $options_hashref->{identity_file};
	my $limit         = $options_hashref->{limit};
	my $ssh_option    = $options_hashref->{ssh_option};
	my $port          = $options_hashref->{port};
	my $program       = $options_hashref->{program};

	my $source_user = $options_hashref->{source_user};
	my $source_host = $options_hashref->{source_host};
	my $source_path = $options_hashref->{source_path};

	my $destination_user = $options_hashref->{destination_user};
	my $destination_host = $options_hashref->{destination_host};
	my $destination_path = $options_hashref->{destination_path};

	if (!$source_path || !$destination_host || !$destination_path) {
		log_warning("missing at least 1 of the required parameters: source_path, destination_host, destination_path");
		return 0;
	}

	# TODO: Add ssh path to config file and set global variable
	# Locate the path to the scp binary
	my @possible_scp_paths = ('scp.exe', 'scp', 'C:/cygwin/bin/scp.exe', 'D:/cygwin/bin/scp.exe', '/usr/bin/scp',);

	my $scp_path;
	for my $possible_scp_path (@possible_scp_paths) {
		if (-x $possible_scp_path) {
			$scp_path = $possible_scp_path;
			last;
		}
	}
	if (!$scp_path) {
		log_warning("unable to locate the SCP executable");
		return 0;
	}

	# Fix the options
	$options = '' if !$options;

	# -B, Selects batch mode (prevents asking for passwords or passphrases).
	$options .= 'B' if ($options !~ /B/);

	# -p, Preserves modification times, access times, and modes from the original file.
	$options .= 'p' if ($options !~ /p/);

	# -r, Recursively copy entire directories.
	$options .= 'r' if ($options !~ /r/);

	# Don't use -q, Disables the progress meter. Error messages are more descriptive without it
	$options =~ s/q//g if ($options =~ /q/);

	# Remove all dashes and spaces from the options string
	$options =~ s/[-\s]//g;

	# Replace 'x' with ' -x'
	$options =~ s/(\w)/ -$1/gx;

	# Remove leading space
	$options =~ s/^\s//;

	# Fix some things if pscp.exe is being used


	# Set the default destination user
	$destination_user = 'root' if !$destination_user;

	# Set the default port
	$port = '22' if !$port;

	# Create a variable to store the entire SCP command
	my $scp_command;

	# Check if source path contains a colon (likely a Windows machine)
	# SCP can't handle Windows-style paths like C:\...
	# cd to the directory then run SCP on the local file name
	if ($source_path =~ /:/) {
		# Take the source path apart
		my ($source_filename, $source_directory) = fileparse($source_path);

		# Add the cd command to the beginning of the SCP command
		# Use the /D switch to change drives if necessary
		$scp_command .= "cd /D \"$source_directory\" && ";

		# Change the source file path to the file name
		$source_path = $source_filename;
	} ## end if ($source_path =~ /:/)

	# Assemble the SCP command
	$scp_command .= "\"$scp_path\" ";
	$scp_command .= "$options ";
	$scp_command .= "-c $cipher " if $cipher;
	$scp_command .= "-F \"$ssh_config\" " if $ssh_config;
	$scp_command .= "-i \"$identity_file\" " if $identity_file;
	$scp_command .= "-l $limit " if $limit;
	$scp_command .= "-o $ssh_option " if $ssh_option;
	$scp_command .= "-P $port ";
	$scp_command .= "-S \"$program\" " if $program;
	$scp_command .= "$source_user@" if $source_user;
	$scp_command .= "$source_host:" if $source_host;
	$scp_command .= "\"$source_path\" ";
	$scp_command .= "$destination_user@";
	$scp_command .= "$destination_host:";
	$scp_command .= "\"$destination_path\" ";

	# Redirect standard output and error output so all messages are captured
	$scp_command .= ' 2>&1';

	# Print the configuration if $VERBOSE
	log_verbose("SCP command: $scp_command");

	# Execute the command
	my $scp_output = `$scp_command` || 'scp did not produce any output';

	# Save the exit status
	my $scp_exit_status = $?;

	# Strip out the key warning message
	$scp_output =~ s/\@{10,}.*man-in-the-middle attacks\.//igs;
	chomp $scp_output;

	# Check the exit status
	# scp exits with 0 on success or >0 if an error occurred
	if ($scp_exit_status <= 0) {
		# Success
		log_verbose("scp exit status: $scp_exit_status (success), output: $scp_output");
		log_info("successfully copied files using scp");
		return 1;
	}
	else {
		# Failure
		log_verbose("failed to copy files using scp, exit status: $scp_exit_status, output: $scp_output");
		return 0;
	}
} ## end sub scp

1;
