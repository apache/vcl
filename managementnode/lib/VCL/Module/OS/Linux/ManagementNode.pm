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

VCL::Module::OS::Linux::ManagementNode.pm

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for the management node's Linux operating
 system.

=cut

##############################################################################
package VCL::Module::OS::Linux::ManagementNode;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.4.1';

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

 Parameters  : 
 Returns     : 
 Description :

=cut

sub initialize {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as an object method");
		return;
	}
	
	my $management_node_hostname = $self->data->get_management_node_hostname() || return;
	my $management_node_short_name = $self->data->get_management_node_short_name() || return;
	my $management_node_ip_address = $self->data->get_management_node_ipaddress() || return;
	
	$self->data->set_computer_id(0);
	$self->data->set_computer_hostname($management_node_hostname);
	$self->data->set_computer_node_name($management_node_short_name);
	$self->data->set_computer_short_name($management_node_short_name);
	$self->data->set_computer_public_ip_address($management_node_ip_address);
	
	# TODO: remove all use of management node private IP address
	my $management_node_private_ip_address = hostname_to_ip_address($management_node_hostname);
	if ($management_node_private_ip_address) {
		$self->data->set_computer_private_ip_address($management_node_private_ip_address);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to initialize management node private IP address in DataStructure object, unable to resolve hostname '$management_node_hostname'");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional)
 Returns     : array
 Description :

=cut

sub execute {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as an object method");
		return;
	}
	
	# Get the command argument
	my $command = shift;
	if (!$command) {
		notify($ERRORS{'WARNING'}, 0, "command argument was not specified");
		return;
	}
	
	# Get 2nd display output argument if supplied, or set default value
	my $display_output = shift || '0';
	
	# Run the command
	my ($exit_status, $output) = run_command($command, !$display_output);
	if (defined($exit_status) && defined($output)) {
		if ($display_output) {
			notify($ERRORS{'OK'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output)) if $display_output;
		}
		return ($exit_status, $output);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on management node: $command");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 copy_file_to

 Parameters  : $source, $destination
 Returns     : array
 Description : Copies file(s) from the management node to the Linux computer.

=cut

sub copy_file_to {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the source and destination arguments
	my ($source, $destination) = @_;
	if (!$source || !$destination) {
		notify($ERRORS{'WARNING'}, 0, "source and destination arguments were not specified");
		return;
	}
	
	$destination =~ s/.*://g;
	return $self->copy_file($source, $destination);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_private_ip_addresses

 Parameters  : none
 Returns     : boolean
 Description : Retrieves private IP information for all computers in the
               database assigned to the management node and checks if the
               hostname resolves on the management node. If it resolves to a
               different address than the value stored in the database, the
               database is updated.

=cut

sub check_private_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get computers assigned to this management node
	my @management_node_computer_ids = get_management_node_computer_ids();
	
	# Get private IP addresses from the database for all computers assigned to this managment node
	my $database_private_ip_address_info = get_computer_private_ip_address_info(@management_node_computer_ids);
	
	my @database_no_resolve;
	my @database_resolve_match;
	my @database_resolve_no_match;
	my @no_database_resolve;
	my @no_database_no_resolve;
	
	for my $hostname (sort keys %$database_private_ip_address_info) {
		my $database_private_ip_address = $database_private_ip_address_info->{$hostname};
		my ($hostname) = $hostname =~ /^([^\.]+)/g;
		
		# Attempt to detmine the IP address the hostname resolves to via gethostip
		#my $resolved_ip_address = get_host_ip($hostname) || get_host_ip($hostname);
		my $resolved_ip_address = hostname_to_ip_address($hostname);
		
		if ($database_private_ip_address) {
			if (!$resolved_ip_address) {
				push @database_no_resolve, $hostname;
				#print "private IP address of $hostname set in the database: $database_private_ip_address, hostname does NOT resolve\n";
				#notify($ERRORS{'DEBUG'}, 0, "private IP address of $hostname set in the database: $database_private_ip_address, hostname does NOT resolve");
			}
			elsif ($database_private_ip_address eq $resolved_ip_address) {
				push @database_resolve_match, $hostname;
				print "private IP address of $hostname set in database matches IP address hostname resolves to: $database_private_ip_address\n";
				notify($ERRORS{'DEBUG'}, 0, "private IP address of $hostname set in database matches IP address hostname resolves to: $database_private_ip_address");
			}
			else {
				push @database_resolve_no_match, $hostname;
				print "private IP address $hostname resolves to ($resolved_ip_address) does NOT match database ($database_private_ip_address)\n";
				notify($ERRORS{'DEBUG'}, 0, "private IP address $hostname resolves to ($resolved_ip_address) does NOT match database ($database_private_ip_address)");
				update_computer_private_ip_address($hostname, $resolved_ip_address);
			}
		}
		else {
			# Private IP address is not set in the database
			if ($resolved_ip_address) {
				push @no_database_resolve, $hostname;
				print "private IP address of $hostname NOT set in database, hostname resolves to $resolved_ip_address\n";
				notify($ERRORS{'DEBUG'}, 0, "private IP address of $hostname NOT set in database, hostname resolves to $resolved_ip_address");
				update_computer_private_ip_address($hostname, $resolved_ip_address);
			}
			else {
				push @no_database_no_resolve, $hostname;
				#print "private IP address of $hostname NOT set in database and hostname does NOT resolve\n";
				notify($ERRORS{'DEBUG'}, 0, "private IP address of $hostname NOT set in database and hostname does NOT resolve");
			}
		}
	}
	
	my $database_no_resolve_count = scalar(@database_no_resolve);
	my $database_resolve_match_count = scalar(@database_resolve_match);
	my $database_resolve_no_match_count = scalar(@database_resolve_no_match);
	my $no_database_resolve_count = scalar(@no_database_resolve);
	my $no_database_no_resolve_count = scalar(@no_database_no_resolve);
	
	notify($ERRORS{'DEBUG'}, 0, "private IP address results:\n" .
		"database set, hostname does not resolve: $database_no_resolve_count\n" .
		"database set, hostname resolves to matching address: $database_resolve_match_count\n" .
		"database set, hostname resolves to different address: $database_resolve_no_match_count (" . join(', ', @database_resolve_no_match) . ")\n" .
		"database not set, hostname resolves: $no_database_resolve_count (" . join(', ', @no_database_resolve) . ")\n" .
		"database not set, hostname does not resolve: $no_database_no_resolve_count (" . join(', ', @no_database_no_resolve) . ")"
	);
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : hash reference
 Description : Assembles the MN-related 'vcld -setup' menu items.

=cut

sub setup_get_menu {
	return {
		'Management Node Operations' => {
			'Check private IP addresses' => \&check_private_ip_addresses,
		},
	};
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
