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

VCL::Module::OS::Linux::firewall::ufw.pm

=head1 DESCRIPTION

 This module provides support for configuring ufw-based firewalls.

=cut

###############################################################################
package VCL::Module::OS::Linux::firewall::ufw;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::firewall::iptables);

# Specify the version of this module
our $VERSION = '2.5';

our @ISA;

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Returns true if the ufw and iptables-save commands exist on the
               computer. Returns false if the command does not exist.

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $arguments = shift || {};
	
	my $computer_name = $self->data->get_computer_hostname();
	
	notify($ERRORS{'DEBUG'}, 0, "initializing " . ref($self) . " object to control $computer_name");
	
	if (!$self->os->command_exists('ufw')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, ufw command does not exist");
		return 0;
	}
	elsif (!$self->os->command_exists('iptables-save')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, iptables-save command does not exist");
		return 0;
	}
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " object initialized to control $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 save_configuration

 Parameters  : none
 Returns     : boolean
 Description : Executes iptables-save and writes all lines containing 'vcl-' to
               the end of /etc/ufw/after.rules. A comment beginning with
               "DISCLAIMER" along with user instructions is added before the
               section added by VCL. If this exists prior to the execution of
               this subroutine, the "DISCLAIMER" line and everything underneath
               it are first removed.
               
               "ufw enable" is executed after the .rules file is modified. This
               reloads the configuration and ensures the firewall is enabled.

=cut

sub save_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $rules_file_path = '/etc/ufw/after.rules';
	
	# Make a backup copy of after.rules
	my $timestamp = makedatestring();
	my $file_timestamp = $timestamp;
	$file_timestamp =~ s/:+/-/g;
	$file_timestamp =~ s/\s+/_/g;
	my $backup_rules_file_path = "/tmp/ufw-after.rules.$file_timestamp";
	$self->os->copy_file($rules_file_path, $backup_rules_file_path);
	
	my @original_lines = $self->os->get_file_contents($rules_file_path);
	if (!@original_lines) {
		notify($ERRORS{'WARNING'}, 0, "failed to save ufw firewall configuration on $computer_name, contents of $rules_file_path could not be retrieved");
		return;
	}
	
	my @updated_lines;
	for my $original_line (@original_lines) {
		if ($original_line !~ /#.*(VCL|DISCLAIMER)/) {
			push @updated_lines, $original_line;
		}
		else {
			# Ignore all lines after the first line containing '# VCL' is found
			last;
		}
	}
	
	# Call iptables-save
	# All lines added by vcl should contain a 'vcl-'
	my $command = "iptables-save";
	my ($exit_status, $output) = $self->os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve iptables rules containing 'vcl-' from $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve iptables rules containing 'vcl-' from $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "retrieved iptables rules containing 'vcl-' from $computer_name on $computer_name:\n" . join("\n", @$output));
	}
	
	# Note: Do not use "WARNING" in the message or else it will show up in vcld.log, creating noise when searching for WARNING messages
	push @updated_lines, <<EOF;

# DISCLAIMER: The remainder of this file has been automatically configured by VCL ($timestamp)
# Do not modify this line or any lines below
# Custom firewall configuration lines may be added to this file but must be located above this line
EOF
	
	my @vcl_lines;
	my $current_table;
	my $last_table_written = '';
	LINE: for my $line (@$output) {
		# Find lines that specify a table name:
		# *nat
		# *filter
		if ($line =~ /^\s*\*(.+)$/) {
			$current_table = $1;
		}
		elsif ($line =~ /(vcl|$PROCESSNAME)-/) {
			if ($last_table_written ne $current_table) {
				if ($last_table_written) {
					push @vcl_lines, "COMMIT\n";
				}
				
				push @vcl_lines, "*$current_table";
				$last_table_written = $current_table;
			}
			
			push @vcl_lines, $line;
		}
	}
	push @vcl_lines, 'COMMIT';
	my $vcl_string = join("\n", @vcl_lines);
	
	push @updated_lines, @vcl_lines;
	my $updated_string = join("\n", @updated_lines);
	
	if ($self->os->create_text_file($rules_file_path, $updated_string)) {
		notify($ERRORS{'OK'}, 0, "added VCL-specific lines to $rules_file_path on $computer_name:\n$vcl_string");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to save ufw firewall configuration on $computer_name, $rules_file_path could not be updated");
		return;
	}
	
	return $self->enable();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable

 Parameters  : none
 Returns     : boolean
 Description : Calls "ufw --force enable" to reload the ufw firewall and enable
               it on boot.

=cut

sub enable {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command = 'ufw --force enable';
	my ($exit_status, $output) = $self->os->execute($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to enable ufw on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "enabled ufw on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
