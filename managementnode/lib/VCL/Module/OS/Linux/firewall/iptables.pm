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

VCL::Module::OS::Linux::firewall::iptables.pm

=head1 DESCRIPTION

 This module provides support for configuring iptables-based firewalls.

=cut

###############################################################################
package VCL::Module::OS::Linux::firewall::iptables;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::firewall);

# Specify the version of this module
our $VERSION = '2.5';

our @ISA;

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use English '-no_match_vars';

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Returns true if the iptables command exists on the computer.
               Returns false if the command does not exist.

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
	
	if (!$self->os->command_exists('iptables')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, iptables command does not exist");
		return 0;
	}
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " object initialized to control $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_post_load

 Parameters  : none
 Returns     : boolean
 Description : Performs the initial iptables firewall configuration after an
               image is loaded:
               * A vcl-post_load chain is created in the filter table with a
                 rule is added to this chain to allow traffic on any port from
                 the management node's IP address.
               * All existing rules explicitly allowing traffic to TCP/22 are
                 deleted.
               * All other chains in the filter table named vcl-* are deleted to
                 clean up any possible remnants.

=cut

sub process_post_load {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "beginning firewall post-load configuration on $computer_name");
	
	my $timestamp = makedatestring();
	my $post_load_chain_name = $self->get_post_load_chain_name();
	
	# Try to determine the IP address the management node uses to connect to remote hosts
	# managementnode.IPaddress is not necessarily the private IP used to connect to computers being loaded
	my @mn_ip_addresses = $self->os->get_management_node_connected_ip_address();
	
	# If unable to determine the connecting IP, open up access to all MN IP's
	if (!@mn_ip_addresses) {
		# Get all of the IP addresses in use on the management node
		@mn_ip_addresses = $self->mn_os->get_ip_addresses();
		if (!@mn_ip_addresses) {
			notify($ERRORS{'WARNING'}, 0, "failed to complete firewall post-load configuration on $computer_name, management node IP addresses could not be determined");
			return;
		}
	}
	
	# Create a chain and add a jump rule to INPUT chain
	$self->create_chain('filter', $post_load_chain_name);
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $post_load_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump to rules added during the post-load stage ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall post-load configuration on $computer_name, failed to create rule in INPUT chain to jump to '$post_load_chain_name' chain");
		return;
	}

	# Allow traffic from any of the management node IP addresses
	if (!$self->insert_rule('filter', $post_load_chain_name,
		{
			'parameters' => {
				'source' => join(',', @mn_ip_addresses),
				'jump' => 'ACCEPT',
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: allow traffic from management node ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall post-load configuration on $computer_name, failed to add rule allowing traffic from management node IP addresses to $post_load_chain_name chain");
		return;
	}

	# Delete other vcl-* chains added by vcld
	my $table_info = $self->get_table_info();
	for my $chain_name (keys %$table_info) {
		if ($chain_name ne $post_load_chain_name && $chain_name =~ /^vcl-/) {
			$self->delete_chain('filter', $chain_name);
		}
	}
	
	if (!$self->isa('VCL::Module::OS::Linux::firewall::firewalld')) {
		# Legacy code may have been used previously for a reservation, before an upgrade
		# Clean up old connect method rules from the INPUT chain
		# Delete all rules from INPUT chain matching connect method protocols and ports
		$self->delete_connect_method_rules();
		
		# Delete all TCP/22 rules
		# Images captured prior to VCL 2.5 are saved with an expicit TCP/22 allow rule from any address
		$self->delete_rules('filter', 'INPUT',
			{
				"match_extensions" => {
					"tcp" => {
						"dport" => 22,
					},
				},
				"parameters" => {
					"jump" => "ACCEPT",
				},
			}
		);
		
		$self->save_configuration();
	}
	
	notify($ERRORS{'DEBUG'}, 0, "completed firewall post-load configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_reserved

 Parameters  : none
 Returns     : boolean
 Description : Configures the iptables firewall for the reserved state:
               * A vcl-reserved chain is created with rules allowing traffic to
                 the connect method ports from any IP address.

=cut

sub process_reserved {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure the post-load steps were done
	if (!$self->chain_exists('filter', $self->get_post_load_chain_name())) {
		$self->process_post_load();
	}
	
	my $timestamp = makedatestring();
	
	notify($ERRORS{'DEBUG'}, 0, "beginning firewall configuration on $computer_name for reserved state");
	
	my $reserved_chain_name = $self->get_reserved_chain_name();
	
	# Delete existing chain if one exists to prevent inconsistent results
	# Create a chain and add a jump rule to INPUT chain
	$self->create_chain('filter', $reserved_chain_name);
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $reserved_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump to rules added during the reserved stage of reservation $reservation_id ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall reserved configuration on $computer_name, failed to create rule in INPUT chain to jump to '$reserved_chain_name' chain");
		return;
	}
	
	my @protocol_ports = $self->data->get_connect_method_protocol_port_array();
	for my $protocol_port (@protocol_ports) {
		my ($protocol, $port) = @$protocol_port;
		if (!$self->insert_rule('filter', $reserved_chain_name,
			{
				'parameters' => {
					'protocol' => $protocol,
					'jump' => 'ACCEPT',
				},
				'match_extensions' => {
					$protocol => {
						'dport' => $port,
					},
					'comment' => {
						'comment' => "VCL: allow traffic from any IP address to connect method ports during reserved stage of reservation $reservation_id ($timestamp)",
					},
				},
			}
		)) {
			notify($ERRORS{'WARNING'}, 0, "failed to complete firewall reserved configuration on $computer_name, failed to add rule to allow traffic to '$reserved_chain_name' chain, protocol: $protocol, port: $port");
			return;
		}
	}
	
	$self->save_configuration();

	notify($ERRORS{'DEBUG'}, 0, "completed firewall reserved configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_inuse

 Parameters  : $remote_ip_address (optional)
 Returns     : boolean
 Description : Configures the iptables firewall for the inuse state:
               * A vcl-inuse chain is created if it does not already exist.
               * Rules are added to the vcl-inuse chain allowing to allow
                 traffic to the connect method ports from the end user's
                 specific IP address.
               * The vcl-reserved chain is deleted if it exists.
               
               This subroutine can be called over and over again. It will not
               remove rules previously added to the vcl-inuse chain. If a user's
               remote IP address changes, this subroutine will add a new rule to
               the vcl-inuse chain.

=cut

sub process_inuse {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure the post-load steps were done
	if (!$self->chain_exists('filter', $self->get_post_load_chain_name())) {
		$self->process_post_load();
	}
	
	my $timestamp = makedatestring();
	
	my $remote_ip_address = shift || $self->data->get_reservation_remote_ip();
	if (!$remote_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall inuse configuration on $computer_name, remote IP could not be retrieved for reservation");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning firewall configuration on $computer_name for inuse state");
	
	my $inuse_chain_name = $self->get_inuse_chain_name();
	my $reserved_chain_name = $self->get_reserved_chain_name();
	
	# Delete existing chain if one exists to prevent inconsistent results
	# Create a chain and add a jump rule to INPUT chain
	$self->create_chain('filter', $inuse_chain_name);
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $inuse_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump to rules added during the inuse stage of reservation $reservation_id ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall inuse configuration on $computer_name, failed to create rule in INPUT chain to jump to '$inuse_chain_name' chain");
		return;
	}
	
	my @protocol_ports = $self->data->get_connect_method_protocol_port_array();
	for my $protocol_port (@protocol_ports) {
		my ($protocol, $port) = @$protocol_port;
		if (!$self->insert_rule('filter', $inuse_chain_name,
			{
				'parameters' => {
					'protocol' => $protocol,
					'source' => "$remote_ip_address",
					'jump' => 'ACCEPT',
				},
				'match_extensions' => {
					$protocol => {
						'dport' => $port,
					},
					'comment' => {
						'comment' => "VCL: allow traffic from $remote_ip_address to $protocol/$port during the inuse stage of reservation $reservation_id ($timestamp)",
					},
				},
			}
		)) {
			notify($ERRORS{'WARNING'}, 0, "failed to complete firewall inuse configuration on $computer_name, failed to add rule to allow traffic to '$inuse_chain_name' chain, protocol: $protocol, port: $port");
			return;
		}
	}
	
	# Delete the reserved chain which allows traffic from any address
	$self->delete_chain('filter', $reserved_chain_name);
	
	$self->save_configuration();

	notify($ERRORS{'DEBUG'}, 0, "completed firewall inuse configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_sanitize

 Parameters  : none
 Returns     : boolean
 Description : Performs the same iptables firewall configuration steps as
               process_post_load.

=cut

sub process_sanitize {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	return $self->process_post_load();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_pre_capture

 Parameters  : none
 Returns     : boolean
 Description : Performs the iptables firewall configuration prior to capturing
               an image:
               * A vcl-pre_capture chain is added to the filter table
                 with a rule allowing TCP/22 traffic from any IP address.
               * Rules matching any of the management node's IP addresses are
                 deleted.
               * Any other chains named vcl-* are flushed and deleted.

=cut

sub process_pre_capture {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $timestamp = makedatestring();
	my $computer_name = $self->data->get_computer_short_name();
	notify($ERRORS{'DEBUG'}, 0, "beginning firewall pre-capture configuration on $computer_name");
	
	my $pre_capture_chain_name = $self->get_pre_capture_chain_name();
	
	# Create a chain and add a jump rule to INPUT chain
	if (!$self->create_chain('filter', $pre_capture_chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall pre-capture configuration on $computer_name, failed to create '$pre_capture_chain_name' chain");
		return;
	}
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $pre_capture_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump to rules added during the pre-capture stage ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall pre-capture configuration on $computer_name, failed to create rule in INPUT chain to jump to '$pre_capture_chain_name' chain");
		return;
	}
	
	# Allow unrestricted SSH traffic
	if (!$self->insert_rule('filter', $pre_capture_chain_name,
		{
			'parameters' => {
				'jump' => 'ACCEPT',
				'protocol' => 'tcp',
			},
			'match_extensions' => {
				'tcp' => {
					'destination-port' => 22,
				},
				'comment' => {
					'comment' => "VCL: allow traffic to SSH port 22 from any IP address ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall pre-capture configuration on $computer_name, failed to add rule to allow traffic on port 22 to $pre_capture_chain_name chain");
		return;
	}
	
	if (!$self->isa('VCL::Module::OS::Linux::firewall::firewalld')) {
		# Delete all rules explicitly defined for any of the management node IP addresses
		# Legacy firewall code would add rules directly to the filter/INPUT table for each management node address
		my @mn_ip_addresses = $self->mn_os->get_ip_addresses();
		for my $mn_ip_address (@mn_ip_addresses) {
			$self->delete_rules('filter', 'INPUT',
				{
					'parameters' => {
						'source' => $mn_ip_address,
					},
				}
			);
		}
		
		# Legacy code may have been used previously for a reservation, before an upgrade
		# Clean up old connect method rules from the INPUT chain
		# Delete all rules from INPUT chain matching connect method protocols and ports
		$self->delete_connect_method_rules();
	}
	
	# Delete other vcl-* chains added by vcld
	my $table_info = $self->get_table_info();
	for my $chain_name (keys %$table_info) {
		if ($chain_name ne $pre_capture_chain_name && $chain_name =~ /^vcl-/) {
			$self->delete_chain('filter', $chain_name);
		}
	}
	
	$self->save_configuration();
	
	notify($ERRORS{'DEBUG'}, 0, "completed firewall pre-capture configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 process_cluster

 Parameters  : none
 Returns     : boolean
 Description : Performs the iptables firewall configuration to allow all traffic
               from other computers assigned to a cluster request.

=cut

sub process_cluster {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $timestamp = makedatestring();
	my $request_id = $self->data->get_request_id();
	my $computer_name = $self->data->get_computer_short_name();
	notify($ERRORS{'DEBUG'}, 0, "beginning firewall cluster configuration on $computer_name");
	
	my $cluster_chain_name = $self->get_cluster_chain_name();
	
	my @cluster_computer_public_ip_addresses = $self->data->get_other_cluster_computer_public_ip_addresses();
	
	# Delete existing chain or else duplicate rules will be added
	# This subroutine really should only need to be called once
	$self->delete_chain('filter', $cluster_chain_name);
	
	# Create a chain and add a jump rule to INPUT chain
	if (!$self->create_chain('filter', $cluster_chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall cluster configuration on $computer_name, failed to create '$cluster_chain_name' chain");
		return;
	}
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $cluster_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump to rules added during for cluster reservation ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall cluster configuration on $computer_name, failed to create rule in INPUT chain to jump to '$cluster_chain_name' chain");
		return;
	}
	
	# Allow all traffic from other cluster computer public IP addresses
	if (!$self->insert_rule('filter', $cluster_chain_name,
		{
			'parameters' => {
				'source' => join(',', @cluster_computer_public_ip_addresses),
				'jump' => 'ACCEPT',
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: allow all traffic from other computers assigned to cluster request $request_id ($timestamp)",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete firewall cluster configuration on $computer_name, failed to add rule allowing traffic from cluster computer public IP addresses to $cluster_chain_name chain");
		return;
	}
	
	$self->save_configuration();
	
	notify($ERRORS{'DEBUG'}, 0, "completed firewall cluster configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_iptables_semaphore

 Parameters  : none
 Returns     : true or VCL::Semaphore object reference
 Description : Obtains and returns a VCL::Semaphore object if called from a
               subroutine containing 'nat' in the name. This should always be
               called prior to executing iptables commands on a host this could
               potentially be controlled by multiple vcld processes at the same
               time. If multiple iptables commands are attempted at the same
               time, the following error is generated:
                  iptables: Resource temporarily unavailable.

=cut

sub get_iptables_semaphore {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Check if the calling subroutine contains 'nat'
	my $calling_subroutine = get_calling_subroutine();
	if ($calling_subroutine !~ /(nat)/) {
		return 1;
	}
	
	my $computer_id = $self->data->get_computer_id();
	
	return $self->get_semaphore("iptables-$computer_id", 120, 1);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 insert_rule

 Parameters  : $table_name, $chain_name, $rule_specification_hashref
 Returns     : boolean
 Description : Inserts an iptables rule. The argument must be a properly
               constructed hash reference. Supported top-level hash keys are:
               * {parameters} => {<hash reference>} (optional)
                    Allows any of the options under the iptables man page
                    "PARAMETERS" section to be specified. Full parameter names
                    should be used such as "protocol" instead of "-p".
                    Parameters can be negated by adding an exclaimation point
                    before the parameter name.
               * {match_extensions} => {<hash reference>} (optional)
                    Allows any of the options under the iptables man page
                    "MATCH EXTENSIONS" section to be specified. Each key should
                    be a match extension module name such as "state". The value
                    should be a hash reference whose key names should be the
                    names of the supported options for that match extension
                    module.
               * {target_extensions} => {<hash reference>} (optional)
                    Allows any of the options under the iptables man page
                    "TARGET EXTENSIONS" section to be specified. Each key should
                    be a target extension module name such as "DNAT". The value
                    should be a hash reference whose key names should be the
                    names of the supported options for that target extension
                    module.
               
               Example:
               $self->os->firewall->create_chain('nat', 'test');
               $self->os->firewall->insert_rule('nat', 'test',
                  {
                     'parameters' => {
                        'protocol' => 'tcp',
                        'in-interface' => 'eth1',
                     },
                     'match_extensions' => {
                        'comment' => {
                           'comment' => "forward: eth1:50443 --> 10.1.2.3:443 (tcp)",
                        },
                        'tcp' => {
                           'destination-port' => 50443,
                        },
                     },
                     'target_extensions' => {
                        'DNAT' => {
                           'to-destination' => "10.1.2.3:443",
                        },
                     },
                  }
               );

=cut

sub insert_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $rule_specification_hashref, $check_already_exists) = @_;
	if (!$table_name) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!$chain_name) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	elsif (!$rule_specification_hashref) {
		notify($ERRORS{'WARNING'}, 0, "rule specification hash reference argument was not specified");
		return;
	}
	elsif (!ref($rule_specification_hashref) || ref($rule_specification_hashref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument is not a hash reference:\n" . format_data($rule_specification_hashref));
		return;
	}
	elsif (!scalar(keys(%$rule_specification_hashref))) {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument does not contain any keys");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# Avoid duplicate/redundant rules
	my @matching_rules = $self->get_matching_rules($table_name, $chain_name, $rule_specification_hashref);
	if (@matching_rules) {
		my @specification_strings = map { $_->{"rule_specification"} } @matching_rules;
		notify($ERRORS{'OK'}, 0, "$chain_name chain rule in $table_name table already exists on $computer_name:\n" . join("\n", @specification_strings));
		return 1;
	}
	
	# Convert the specification into valid iptables command arguments
	my $argument_string = $self->get_insert_rule_argument_string($rule_specification_hashref);
	if (!$argument_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to add iptables rule to $chain_name chain in $table_name table on $computer_name, rule specification hash reference could not be converted into an iptables command argument string:\n" . format_data($rule_specification_hashref));
		return;
	}
	
	my $semaphore = $self->get_iptables_semaphore();
	return $self->_insert_rule($table_name, $chain_name, $argument_string);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _insert_rule

 Parameters  : $table_name, $chain_name, $argument_string
 Returns     : boolean
 Description : Executes the command to insert a rule. This is a helper
               subroutine and should only be called by insert_rule.

=cut

sub _insert_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $argument_string) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "/sbin/iptables --insert $chain_name --table $table_name $argument_string";
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add iptables rule to $chain_name chain in $table_name table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "added iptables rule to $chain_name chain in $table_name table on $computer_name, command: $command");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_insert_rule_argument_string

 Parameters  : $rule_specification_hashref
 Returns     : string
 Description : 

=cut

sub get_insert_rule_argument_string {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($rule_specification_hashref) = @_;
	if (!$rule_specification_hashref) {
		notify($ERRORS{'WARNING'}, 0, "rule specification hash reference argument was not specified");
		return;
	}
	elsif (!ref($rule_specification_hashref) || ref($rule_specification_hashref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument is not a hash reference:\n" . format_data($rule_specification_hashref));
		return;
	}
	elsif (!scalar(keys(%$rule_specification_hashref))) {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument does not contain any keys");
		return;
	}
	
	my $argument_string;
	
	# Add the parameters to the arguments string
	for my $parameter (sort keys %{$rule_specification_hashref->{parameters}}) {
		my $value = $rule_specification_hashref->{parameters}{$parameter};
		
		if ($parameter =~ /^\!/) {
			$argument_string .= "! ";
			$parameter =~ s/^\!//;
		}
		$argument_string .= "--$parameter $value ";
	}
	
	# Add the match extension to the arguments string
	for my $match_extension (sort keys %{$rule_specification_hashref->{match_extensions}}) {
		$argument_string .= "--match $match_extension ";
		for my $option (sort keys %{$rule_specification_hashref->{match_extensions}{$match_extension}}) {
			my $value = $rule_specification_hashref->{match_extensions}{$match_extension}{$option};
			
			if ($option =~ /(comment)/) {
				$value = "\"$value\"";
			}
			
			if ($option =~ /^\!/) {
				$argument_string .= "! ";
				$option =~ s/^\!//;
			}
			
			$argument_string .= "--$option " if $option;
			$argument_string .= "$value ";
		}
	}
	
	# Add the target extensions to the arguments string
	for my $target_extension (sort keys %{$rule_specification_hashref->{target_extensions}}) {
		$argument_string .= "--jump $target_extension ";
		for my $option (sort keys %{$rule_specification_hashref->{target_extensions}{$target_extension}}) {
			my $value = $rule_specification_hashref->{target_extensions}{$target_extension}{$option};
			$argument_string .= "--$option " if $option;
			$argument_string .= "$value ";
		}
	}
	
	$argument_string =~ s/\s+$//g;
	
	return $argument_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_matching_rules

 Parameters  : $table_name, $chain_name, $rule_specification_hashref
 Returns     : array
 Description : Checks the chain for any rules that match all parameters
               specified in the $rule_specification_hashref argument. For
               example, to find all TCP/22 rules:
                  $self->os->firewall->get_matching_rules('filter', 'INPUT',
                     {
                        'parameters' => {
                           'protocol' => 'tcp',
                        },
                        'match_extensions' => {
                           'tcp' => {
                              'dport' => 22,
                           },
                        },
                     }
                  );

=cut

sub get_matching_rules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $rule_specification_hashref) = @_;
	if (!$table_name) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!$chain_name) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	elsif (!$rule_specification_hashref) {
		notify($ERRORS{'WARNING'}, 0, "rule specification hash reference argument was not specified");
		return;
	}
	elsif (!ref($rule_specification_hashref) || ref($rule_specification_hashref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument is not a hash reference:\n" . format_data($rule_specification_hashref));
		return;
	}
	elsif (!scalar(keys(%$rule_specification_hashref))) {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument does not contain any keys");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my @matching_rules;
	
	my $table_info = $self->get_table_info($table_name) || return;
	if (!defined($table_info->{$chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "no rules match on $computer_name, $table_name table does not contain a '$chain_name' chain");
		return @matching_rules;
	}
	elsif (!defined($table_info->{$chain_name}{rules})) {
		notify($ERRORS{'DEBUG'}, 0, "no rules match on $computer_name, $chain_name chain in $table_name table contains no rules") if ($self->{debug});
		return @matching_rules;
	}

	# This sub was designed to accept a hash reference argument to match other
	# parts of this module. However, we need to compare the hash reference
	# argument to the hash reference which contains current rule info. Comparing
	# the two as-is is extremely difficult and would require complex recursion.
	# Instead, get_collapsed_hash_reference takes the input multi-level hash
	# reference, finds all of the keys which contain a scalar value, and
	# constucts concatenated key names containing the values. The key names can
	# used in an eval statement to compare another hash reference.
	
	my $collapsed_specification = get_collapsed_hash_reference($rule_specification_hashref);
	if (!$collapsed_specification) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if any rules match on $computer_name, failed to parse rule specification hash reference argument:\n" . format_data($rule_specification_hashref));
		return;
	}
	elsif (!scalar keys(%$collapsed_specification)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if any rules match on $computer_name, attempt to collapse the rule specification hash reference argument produced a result with no keys:\n" . format_data($rule_specification_hashref));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "checking if $chain_name chain in $table_name table on $computer_name has any rules matching specifications:\n" . format_data($collapsed_specification)) if ($self->{debug});
	
	# Some iptables options may take multiple forms
	# Attempt to try all forms
	my $alternate_option_names = {
		'destination-port' => 'dport',
		'source-port' => 'sport',
	};
	
	RULE: for my $rule (@{$table_info->{$chain_name}{rules}}) {
		my $rule_specification = $rule->{rule_specification};
		
		for my $specification_key (keys %$collapsed_specification) {
			# Ignore comments when comparing
			if ($specification_key =~ /(comment)/i) {
				next;
			}
			
			my $specification_value = $collapsed_specification->{$specification_key};
			
			# Check if matches known alternate ('source-port' <--> 'sport')
			my $alternate_specification_key;
			for my $original_name (keys %$alternate_option_names) {
				if ($specification_key =~ /$original_name/i) {
					my $alternate_name = $alternate_option_names->{$original_name};
					$alternate_specification_key = $specification_key;
					$alternate_specification_key =~ s/$original_name/$alternate_name/i;
				}
			}
			
			# $specification_key will contain a string such as:
			#    "{'match_extensions'}{'tcp'}{'dport'}"
			# Use this in an eval block to check if the current rule has a matching key and the same value
			my $rule_value;
			my $eval_string;
			if ($alternate_specification_key) {
				$eval_string = "\$rule_value = (\$rule->$specification_key || \$rule->$alternate_specification_key)";
			}
			else {
				$eval_string = "\$rule_value = \$rule->$specification_key";
			}
			eval($eval_string);
			if ($EVAL_ERROR) {
				notify($ERRORS{'WARNING'}, 0, "failed to determine value of $specification_key key from rule on $computer_name, code evaluated: '$eval_string', error: $EVAL_ERROR, rule:\n" . format_data($rule));
				return;
			}
			elsif (!defined($rule_value)) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring rule on $computer_name, it does not contain a $specification_key value, rule specification: '$rule_specification'") if ($self->{debug});
				next RULE;
			}
			
			if ($rule_value ne $specification_value && $rule_value !~ /^$specification_value(\/32)?$/i) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule on $computer_name:\n" .
				#	"rule_specification : '$rule_specification'\n" .
				#	"specification key  : '$specification_key'\n" .
				#	"argument value     : '$specification_value'\n" .
				#	"rule value         : '$rule_value'"
				#);
				next RULE;
			}
		}
		
		notify($ERRORS{'DEBUG'}, 0, "rule matches: $rule_specification");
		push @matching_rules, $rule;
	}
	
	my $matching_rule_count = scalar(@matching_rules);
	#notify($ERRORS{'DEBUG'}, 0, "found $matching_rule_count matching rule" . ($matching_rule_count == 1 ? '' : 's')) if $matching_rule_count;
	return @matching_rules;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_rules

 Parameters  : $table_name, $chain_name, $rule_specification_hashref
 Returns     : boolean
 Description : Deletes all rules matching the table, chain, and specification
               hash reference. The hash must be in the same format that is
               returned by get_table_info, such as:
                  {
                     "match_extensions" => {
                        "tcp" => {
                           "dport" => 22,
                        },
                     },
                     "parameters" => {
                        "jump" => {
                           "target" => "ACCEPT",
                           },
                        "protocol" => "tcp",
                     },
                  }
               
               An existing rule will be deleted if and only if it contains
               exactly all of the keys defined in the argument, case sensitive.
               The actual value must match but is checked case insensitive.

=cut

sub delete_rules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $rule_specification_hashref) = @_;
	if (!$table_name) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!$chain_name) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	elsif (!$rule_specification_hashref) {
		notify($ERRORS{'WARNING'}, 0, "rule specification hash reference argument was not specified");
		return;
	}
	elsif (!ref($rule_specification_hashref) || ref($rule_specification_hashref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument is not a hash reference:\n" . format_data($rule_specification_hashref));
		return;
	}
	elsif (!scalar(keys(%$rule_specification_hashref))) {
		notify($ERRORS{'WARNING'}, 0, "rule specification argument does not contain any keys");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my @matching_rules = $self->get_matching_rules($table_name, $chain_name, $rule_specification_hashref);
	for my $rule (@matching_rules) {
		# Make sure rule has a 'rule_specification' value or else it can't be deleted
		my $rule_specification_string = $rule->{rule_specification};
		if (!$rule_specification_string) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule on $computer_name because it does not contain a 'rule_specification' key:\n" . format_data($rule));
			next RULE;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "attempting to delete rule on $computer_name: $rule_specification_string");
		my $semaphore = $self->get_iptables_semaphore();
		$self->_delete_rule($table_name, $chain_name, $rule_specification_string) || return;
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _delete_rule

 Parameters  : $table_name, $chain_name, $rule_specification_string
 Returns     : boolean
 Description : Executes the command to delete a rule. This is a helper
               subroutine and should only be called by delete_rules.

=cut

sub _delete_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $rule_specification_string) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "/sbin/iptables --delete $chain_name -t $table_name $rule_specification_string";
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete rule on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted rule on $computer_name with specification: '$rule_specification_string'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_connect_method_rules

 Parameters  : none
 Returns     : boolean
 Description : Deletes all rules from the INPUT chain in the filter table
               matching any connect method ports.

=cut

sub delete_connect_method_rules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my @protocol_ports = $self->data->get_connect_method_protocol_port_array();
	for my $protocol_port (@protocol_ports) {
		my ($protocol, $port) = @$protocol_port;
		$self->delete_rules('filter', 'INPUT',
			{
				'parameters' => {
					'protocol' => $protocol,
				},
				'match_extensions' => {
					$protocol => {
						'dport' => $port,
					},
				},
			}
		);
	}
	
	notify($ERRORS{'DEBUG'}, 0, "deleted explicit rules from INPUT chain in filter table for all connect method ports");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_chain

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Creates a new chain. Returns true if the chain was successfully
               created or already exists.

=cut

sub create_chain {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $semaphore = $self->get_iptables_semaphore();
	
	my $command = "/sbin/iptables --new-chain $chain_name --table $table_name";
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif (grep(/already exists/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "'$chain_name' chain in '$table_name' table already exists on $computer_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to create '$chain_name' chain in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "created '$chain_name' chain in '$table_name' table on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_chain

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Deletes the specified chain from the table. All rules
               which exist in the chain or reference the chain are deleted prior
               to deletion of the chain.

=cut

sub delete_chain {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name_argument) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($chain_name_argument)) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my @chains_deleted;
	my @chain_names = $self->get_table_chain_names($table_name);
	for my $chain_name (@chain_names) {
		if ($chain_name !~ /^$chain_name_argument$/) {
			next;
		}
		
		# Flush the chain first - delete will fail if the chain still contains rules
		if (!$self->flush_chain($table_name, $chain_name)) {
			notify($ERRORS{'WARNING'}, 0, "unable to delete '$chain_name' chain from '$table_name' table on $computer_name, failed to flush chain prior to deletion");
			return;
		}
		
		# Delete all rules which reference the chain being deleted or else the chain can't be deleted
		if (!$self->delete_chain_references($table_name, $chain_name)) {
			notify($ERRORS{'WARNING'}, 0, "unable to delete '$chain_name' chain from '$table_name' table on $computer_name, failed to delete all rules which reference the chain prior to deletion");
			return;
		}
		
		my $command = "/sbin/iptables --delete-chain $chain_name --table $table_name";
		
		my $semaphore = $self->get_iptables_semaphore();
		my ($exit_status, $output) = $self->_execute_iptables($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
			return;
		}
		elsif (grep(/Too many links/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "unable to delete '$chain_name' chain from '$table_name' table on $computer_name, the chain is referenced by another rule");
			return;
		}
		elsif ($exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to delete '$chain_name' chain from '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return;
		}
		else {
			notify($ERRORS{'OK'}, 0, "deleted '$chain_name' chain from '$table_name' table on $computer_name");
			push @chains_deleted, $chain_name;
		}
	}
	
	if (!@chains_deleted) {
		notify($ERRORS{'DEBUG'}, 0, "no chains exist in '$table_name' table on $computer_name matching argument: '$chain_name_argument'");
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_chain_references

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Checks all chains in the specified table for references to the
               $chain_name argument. If found, the referencing rules are
               deleted.

=cut

sub delete_chain_references {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $table_info = $self->get_table_info($table_name);
	for my $referencing_chain_name (keys %$table_info) {
		
		$self->delete_rules($table_name, $referencing_chain_name,
			{
				"parameters" => {
					"jump" => $chain_name,
				},
			}
		);
	}
	
	notify($ERRORS{'DEBUG'}, 0, "deleted all rules in '$table_name' table referencing '$chain_name' chain on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 chain_exists

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Determines if an iptables chain exists in the table specified.

=cut

sub chain_exists {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $table_info = $self->get_table_info($table_name) || return;
	if (defined($table_info->{$chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "$chain_name chain exists in $table_name table on $computer_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'$chain_name' chain does NOT exist in '$table_name' table on $computer_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_table_chain_names

 Parameters  : $table_name
 Returns     : array
 Description : Returns an array containing the chain names defined for a table.

=cut

sub get_table_chain_names {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $table_info = $self->get_table_info($table_name, 1) || return;
	my @table_chain_names = sort keys %$table_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved chain names defined in $table_name table on $computer_name: " . join(', ', @table_chain_names)) if ($self->{debug});
	return @table_chain_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 nat_sanitize_reservation

 Parameters  : $reservation_id (optional)
 Returns     : boolean
 Description : Deletes the chains created for a reservation on a NAT host. Saves
               the iptables configuration.

=cut

sub nat_sanitize_reservation {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = shift || $self->data->get_reservation_id();
	my $reservation_chain_name = $self->get_nat_reservation_chain_name($reservation_id);
	
	if (!$self->delete_chain('nat', $reservation_chain_name)) {
		return;
	}
	
	$self->save_configuration();
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 flush_chain

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Flushes (deletes) rules from the specified chain.

=cut

sub flush_chain {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "/sbin/iptables --flush $chain_name --table $table_name";
	
	my $semaphore = $self->get_iptables_semaphore();
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to flush '$chain_name' chain in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "flushed '$chain_name' chain in '$table_name' table on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_table_info

 Parameters  : $table_name
 Returns     : boolean
 Description : Retrieves the configuration of an iptables table and constructs a
               hash reference. Information from the 'filter' table is returned
               if the $table_name argument is not specified. Example:
					{
                 "OUTPUT" => {
                   "policy" => "ACCEPT"
                 },
                 "PREROUTING" => {
                   "policy" => "ACCEPT",
                   "rules" => [
                     {
                       "parameters" => {
                         "jump" => {
                           "target" => "vcld-3116"
                         }
                       },
                       "rule_specification" => "-j vcld-3116"
                     }
                   ]
                 },
                 "vcld-3116" => {
                   "rules" => [
                     {
                       "match_extensions" => {
                         "comment" => {
                           "comment" => "forward: eth1:18892 --> 192.168.110.201:53 (tcp)"
                         },
                         "tcp" => {
                           "dport" => 18892
                         }
                       },
                       "parameters" => {
                         "in-interface" => "eth1",
                         "jump" => {
                           "target" => "DNAT",
                           "to-destination" => "192.168.110.201:53"
                         },
                         "protocol" => "tcp"
                       },
                       "rule_specification" => "-i eth1 -p tcp -m comment --comment \"forward: eth1:18892 --> 192.168.110.201:53 (tcp)\" -m tcp --dport 18892 -j DNAT --to-destination 192.168.110.201:53"
                     }
                   ]
                 }
               }

=cut

sub get_table_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name) = @_;
	$table_name = 'filter' unless $table_name;
	
	$ENV{iptables_get_table_info_count}{$table_name}++;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my @lines;
	
	my $command = "/sbin/iptables --list-rules --table $table_name";
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif (grep(/Unknown arg/i, @$output)) {
		# Older versions of iptables don't support --list-rules
		# Error output:
		#    iptables v1.3.5: Unknown arg `--list-rules'
		# Try iptables-save
		notify($ERRORS{'DEBUG'}, 0, "version of iptables installed on $computer_name does NOT support the --list-rules option, trying iptables-save");
		
		my $iptables_save_command = "/sbin/iptables-save";
		my ($iptables_save_exit_status, $iptables_save_output) = $self->os->execute($iptables_save_command, 0);
		if (!defined($iptables_save_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $iptables_save_command");
			return;
		}
		elsif ($iptables_save_exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to list rules from '$table_name' table on $computer_name, iptables does not support the --list-rules option and iptables-save returned exit status: $iptables_save_exit_status, command:\n$iptables_save_command\noutput:\n" . join("\n", @$iptables_save_output));
			return 0;
		}
		else {
			# Extract lines like:
			# -A INPUT -p tcp...
			@lines = grep(/^-[A-Z]\s/, @$iptables_save_output);
			#notify($ERRORS{'DEBUG'}, 0, "parsed iptables-save output for command lines, output:\n" . join("\n", @$iptables_save_output) . "\ncommand lines:\n" . join("\n", @lines));
		}
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list rules from '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		@lines = @$output;
	}
	
	if ($self->can('get_all_direct_rules')) {
		# Convert:
		#    ipv4 filter vcl-pre_capture 0 --jump ACCEPT --protocol tcp --match comment --comment 'VCL: ...' --match tcp --destination-port 22
		#    ipv4 nat POSTROUTING 0 '!' --destination 10.0.0.0/20 --jump MASQUERADE --out-interface eth1 --match comment --comment 'blah... blah'
		# To:
		#    -A vcl-pre_capture -p tcp -m comment --comment "VCL: ..." -m tcp --dport 22 -j ACCEPT
		DIRECT_RULE: for my $direct_rule ($self->get_all_direct_rules()) {
			my ($rule_protocol, $rule_table, $rule_chain, $rule_priority, $rule_specification) = $direct_rule =~
				/^
				(\S+)\s+
				(\S+)\s+
				(\S+)\s+
				(\d+)\s+
				(\S.*)
				$/x
			;
			if (!defined($rule_specification)) {
				notify($ERRORS{'WARNING'}, 0, "failed to parse firewalld direct rule: $direct_rule");
				next DIRECT_RULE;
			}
			elsif ($rule_table ne $table_name) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, table does not match '$table_name': $direct_rule");
				next DIRECT_RULE;
			}
			
			my $converted_rule = "-A $rule_chain $rule_specification";
			#notify($ERRORS{'DEBUG'}, 0, "converted iptables direct rule to iptables format:\n" .
			#	"direct rule     : $direct_rule\n" .
			#	"iptables format : $converted_rule"
			#);
			push @lines, $converted_rule;
		}
	}
	
	my $table_info = {};
	LINE: for my $line (@lines) {
		# Split the rule, samples:
		#    -P OUTPUT ACCEPT
		#    -N vcld-3115
		#    -A PREROUTING -j vclark-3115
		#    -A POSTROUTING ! -d 192.168.96.0/20 -o eth1
		#    -A INPUT -d 192.168.96.0/32 -i eth1 -p udp -m multiport --dports 5700:6500,9696:9701,49152:65535 -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
		my ($iptables_command, $chain_name, $rule_specification_string) = $line =~
		/
			^
			(--?[a-z\-]+)	# command: -A, -N, etc
			\s+				# space after command
			([^ ]+)			# chain name
			\s*				# space after chain name
			(.*)				# remainder of rule
			\s*				# trailing spaces
			$
		/ixg;
		
		if (!defined($iptables_command)) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule, iptables command type (ex. '-A') could not be parsed from beginning of line:\n$line");
			next LINE;
		}
		elsif (!defined($chain_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule, iptables chain name could not be parsed from line:\n$line");
			next LINE;
		}
		
		# Make sure the rule specification isn't null to avoid warnings
		$rule_specification_string = '' unless defined($rule_specification_string);
		
		# Remove spaces from end of rule specification
		$rule_specification_string =~ s/\s+$//;
		
		#notify($ERRORS{'DEBUG'}, 0, "split iptables line:\n" .
		#	"line          : '$line'\n" .
		#	"command       : '$iptables_command'\n" .
		#	"chain         : '$chain_name'\n" .
		#	"specification : '$rule_specification_string'"
		#);
		
		if ($iptables_command =~ /^(-P|--policy)/) {
			# -P, --policy chain target (Set  the policy for the chain to the given target)
			$table_info->{$chain_name}{policy} = $rule_specification_string;
		}
		elsif ($iptables_command =~ /^(-N|--new-chain)/) {
			# -N, --new-chain chain
			$table_info->{$chain_name} = {} unless defined($table_info->{$chain_name});
		}
		elsif ($iptables_command =~ /^(-A|--append chain)/) {
			# -A, --append chain rule-specification
			#notify($ERRORS{'DEBUG'}, 0, "parsing iptables append rule command:\n" .
			#	"iptables command: $line\n" .
			#	"iptables rule specification: $rule_specification_string"
			#);
			
			my $rule = {};
			$rule->{rule_specification} = $rule_specification_string;
			
			# Parse the rule parameters
			# Be sure to check for ! enclosed in quotes:
			#    -A POSTROUTING '!' --destination 10.10.0.0/20 --jump MASQUERADE
			my $parameters = {
				'protocol'      => '(?:\'?(\!?)\'?\s)?(-p|--protocol)\s+([^\s]+)',
				'source'        => '(?:\'?(\!?)\'?\s)?(-s|--source)\s+([\d\.\/]+)',
				'destination'   => '(?:\'?(\!?)\'?\s)?(-d|--destination)\s+([\d\.\/]+)',
				'in-interface'  => '(?:\'?(\!?)\'?\s)?(-i|--in-interface)\s+([^\s]+)',
				'out-interface' => '(?:\'?(\!?)\'?\s)?(-o|--out-interface)\s+([^\s]+)',
				'fragment'      => '(?:\'?(\!?)\'?\s)?(-f|--fragment)',
			};
			
			PARAMETER: for my $parameter (keys %$parameters) {
				my $pattern = $parameters->{$parameter};
				my ($inverted, $parameter_match, $value) = $rule_specification_string =~ /$pattern/ig;
				next PARAMETER unless $parameter_match;
				
				if ($inverted) {
					$rule->{parameters}{"!$parameter"} = $value;
				}
				else {
					$rule->{parameters}{$parameter} = $value;
				}
				
				# Remove the matching pattern from the rule specification string
				# This is done to make it easier to parse the match extension parts of the specification later on
				my $rule_specification_string_before = $rule_specification_string;
				$rule_specification_string =~ s/(^\s+|$pattern|\s+$)//igx;
				#notify($ERRORS{'DEBUG'}, 0, "trimmed $parameter parameter:\n" .
				#	"before : '$rule_specification_string_before'\n" .
				#	"after  : '$rule_specification_string'"
				#);
			}

			# -j ACCEPT
			# -j REJECT --reject-with icmp-host-prohibited
			# -j LOG --log-prefix "[UFW BLOCK] "
			
			my $target_section_regex = <<'EOF';
(
	(-[jg]|--(?:jump|goto))
	\s+
	([^\s]+)
	(
		(?:
			(?!\s+(?:-m|--match)\s+)
			.
		)*
	)
)
EOF
			my ($target_section_match, $target_parameter_match, $target, $target_extension_option_string) = $rule_specification_string =~ /$target_section_regex/ix;
			if ($target_parameter_match) {
				my $target_parameter_type = ($target_parameter_match =~ /j/ ? 'jump' : 'goto');
				$rule->{parameters}{$target_parameter_type} = $target;
				
				my $target_extension_option_name;
				
				# Need to split line not just by spaces, but also find sections enclosed in quotes:
				#    -j REJECT --reject-with icmp-host-prohibited
				#    -j LOG --log-prefix "IN_public_DROP: "
				my @target_extension_option_sections = $target_extension_option_string =~
				/
					(
						['"][^'"]*['"]
						|
						[^\s]+
					)
				/gx;
				
				TARGET_OPTION_SECTION: for my $target_extension_option_section (@target_extension_option_sections) {
					# Check if this is the beginning of a target extension option
					if ($target_extension_option_section =~ /^[-]+(\w[\w-]+)/) {
						$target_extension_option_name = $1;
						#notify($ERRORS{'DEBUG'}, 0, "located $target_parameter/$target target extension option: $target_extension_option_name");
						$rule->{target_extensions}{$target}{$target_extension_option_name} = undef;
					}
					elsif (!$target_extension_option_name) {
						# If here, the section should be a target extension option value
						notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule on $computer_name, target extension option name was not detected before this section: '$target_extension_option_section'\n" .
							"output line: $line\n" .
							"target section: $target_section_match"
						);
						next LINE;
					}
					else {
						# Found target extension option value
						$rule->{target_extensions}{$target}{$target_extension_option_name} = $target_extension_option_section;
						$target_extension_option_name = undef;
					}
				}  # TARGET_OPTION_SECTION
				
				my $rule_specification_string_before = $rule_specification_string;
				$rule_specification_string =~ s/(^\s+|$target_section_regex|\s+$)//igx;
				if ($rule_specification_string_before ne $rule_specification_string) {
					#notify($ERRORS{'DEBUG'}, 0, "trimmed $target_parameter_type target section:\n" .
					#	"before : '$rule_specification_string_before'\n" .
					#	"after  : '$rule_specification_string'"
					#);
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "regex failed to remove target section from rule specification:\n" .
						"line                                : $line\n" .
						"remaining rule specification before : $rule_specification_string_before\n" .
						"remaining rule specification after  : $rule_specification_string\n" .
						"target section regex:\n$target_section_regex"
					);
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "target section was not found in rule specification: '$rule_specification_string', line: '$line'");
			}
			
			# The only text remaining in $rule_specification_string should be match extension information
			
			# Make sure space exists between match extension module name (comment) and the option
			# --match comment--comment 'my comment'
			# --match tcp--destination-port
			$rule_specification_string =~ s/(--match [^\s-]+)--/$1 --/g;

			# Split the remaining string by spaces or sections enclosed in quotes
			my @match_extension_sections = $rule_specification_string =~
				/
					(
						['"][^'"]*['"]
						|
						[^\s]+
					)
				/gx;
			
			# Match extensions will be in the form:
			# -m,--match <module> [!] -<x>,--<option> <value> [[!] -<x>,--<option> <value>...]
			my $match_extension_module_name;
			my $match_extension_option;
			my $match_extension_option_inverted = 0;
			my $comment;
			
			MATCH_EXTENSION_SECTION: for my $match_extension_section (@match_extension_sections) {
				next MATCH_EXTENSION_SECTION if !$match_extension_section;
				
				# Check if the section is the beginning of a match extension specification
				if ($match_extension_section =~ /^(-m|--match)$/) {
					$match_extension_module_name = undef;
					$match_extension_option = undef;
					$match_extension_option_inverted = 0;
					next MATCH_EXTENSION_SECTION;
				}
				
				# Parse match extension module name
				if (!$match_extension_module_name) {
					# Haven't found module name for this match extension specification
					# If section begins with a letter it should be the match extension module name
					if ($match_extension_section =~ /^[a-z]/i) {
						$match_extension_module_name = $match_extension_section;
						#notify($ERRORS{'DEBUG'}, 0, "located match extension module name: $match_extension_module_name");
						next MATCH_EXTENSION_SECTION;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule in $table_name table on $computer_name\n" .
							"match extension module name was not detected before this section: '$match_extension_section'\n" .
							"iptables rule specification: '$rule_specification_string'\n" .
							"iptables command: '$line'"
						);
						next LINE;
					}
				}
				
				# Check if this is the beginning of a match extension option
				if ($match_extension_section =~ /^[-]+(\w[\w-]+)/) {
					$match_extension_option = $1;
					if ($match_extension_option_inverted) {
						$match_extension_option = "!$match_extension_option";
						$match_extension_option_inverted = 0;
					}
					#notify($ERRORS{'DEBUG'}, 0, "match extension module name: $match_extension_module_name, located match extension option: $match_extension_option");
					next MATCH_EXTENSION_SECTION;
				}
				elsif ($match_extension_section =~ /^!/) {
					$match_extension_option_inverted = 1;
					next MATCH_EXTENSION_SECTION;
				}
				
				# If here, the section should be (part of) a match extension option value
				if (!$match_extension_option) {
					notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule, match extension option name was not detected before this section: '$match_extension_section'\n" .
						"iptables command: $line\n" .
						"iptables rule specification: $rule_specification_string\n" .
						"preceeding match extension module name: $match_extension_module_name"
					);
					next LINE;
				}
				
				# Check if this is part of a comment
				if ($match_extension_module_name =~ /(comment)/) {
					$comment .= "$match_extension_section ";
					next MATCH_EXTENSION_SECTION;
				}
				
				$rule->{match_extensions}{$match_extension_module_name}{$match_extension_option} = $match_extension_section;
			}
			
			if ($comment) {
				# Remove quotes from beginning and end of comment
				$comment =~ s/(^[\\\"]+|[\s\\\"]+$)//g;
				$rule->{match_extensions}{comment}{comment} = $comment;
				$comment = undef;
			}
			
			push @{$table_info->{$chain_name}{rules}}, $rule;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "iptables '$iptables_command' command is not supported: $line");
			next LINE;
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved rules from iptables $table_name table from $computer_name:\n" . format_data($table_info));
	return $table_info;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 nat_configure_host

 Parameters  : none
 Returns     : boolean
 Description : Configures the iptables firewall to pass NAT traffic.

=cut

sub nat_configure_host {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	my $public_ip_address = $self->data->get_nathost_public_ip_address();
	my $internal_ip_address = $self->data->get_nathost_internal_ip_address();
	
	my $nat_host_chain_name = $self->get_nat_host_chain_name();
	
	# Enable IP port forwarding
	if (!$self->os->enable_ip_forwarding()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure NAT host $computer_name, failed to enable IP forwarding");
		return;
	}
	
	my $nat_table_info = $self->get_table_info('nat');
	if (!$nat_table_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT on $computer_name, nat table info could not be retrieved");
		return;
	}
	elsif (!defined($nat_table_info->{PREROUTING})) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure NAT on $computer_name, nat table does not contain a PREROUTING chain:\n" . format_data($nat_table_info));
		return;
	}
	elsif (!defined($nat_table_info->{POSTROUTING})) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure NAT on $computer_name, nat table does not contain a POSTROUTING chain:\n" . format_data($nat_table_info));
		return;
	}
	
	# Check if NAT has previously been configured
	if (defined($nat_table_info->{$nat_host_chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "NAT has already been configured on $computer_name, '$nat_host_chain_name' chain exists in nat table");
		return 1;
	}
	else {
		# Before VCL 2.5, dedicated NAT host chain wasn't created, check if MASQUERADE rule exists
		for my $rule (@{$nat_table_info->{POSTROUTING}{rules}}) {
			my $rule_specification_string = $rule->{rule_specification};
			if ($rule_specification_string =~ /MASQUERADE/) {
				notify($ERRORS{'DEBUG'}, 0, "POSTROUTING chain in nat table contains a MASQUERADE rule, assuming NAT has already been configured: $rule_specification_string");
				return 1;
			}
		}
	}
	
	# Figure out the public and internal interface names
	my $public_interface_name;
	my $internal_interface_name;
	my $public_subnet_mask;
	my $internal_subnet_mask;
	
	my $network_configuration = $self->os->get_network_configuration();
	for my $interface_name (keys %$network_configuration) {
		my @ip_addresses = keys %{$network_configuration->{$interface_name}{ip_address}};
		
		# Check if the interface is assigned the nathost.publicIPaddress
		if (grep { $_ eq $public_ip_address } @ip_addresses) {
			$public_interface_name = $interface_name;
			$public_subnet_mask = $network_configuration->{$interface_name}{ip_address}{$public_ip_address};
		}
		
		# If nathost.internalIPaddress is set, check if interface is assigned matching IP address
		if (grep { $_ eq $internal_ip_address } @ip_addresses) {
			$internal_interface_name = $interface_name;
			$internal_subnet_mask = $network_configuration->{$interface_name}{ip_address}{$internal_ip_address};
		}
	}
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name, no interface is assigned the public IP address configured in the nathost table: $public_ip_address\n" . format_data($network_configuration));
		return;
	}
	if (!$internal_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name, no interface is assigned the internal IP address configured in the nathost table: $internal_ip_address\n" . format_data($network_configuration));
		return;
	}
	my ($public_network_address, $public_network_bits) = ip_address_to_network_address($public_ip_address, $public_subnet_mask);
	my ($internal_network_address, $internal_network_bits) = ip_address_to_network_address($internal_ip_address, $internal_subnet_mask);
	notify($ERRORS{'DEBUG'}, 0, "determined NAT host interfaces:\n" .
		"public - interface: $public_interface_name, IP address: $public_ip_address/$public_subnet_mask, network: $public_network_address/$public_network_bits\n" .
		"internal - interface: $internal_interface_name, IP address: $internal_ip_address/$internal_subnet_mask, network: $internal_network_address/$internal_network_bits"
	);
	
	my @natport_ranges = get_natport_ranges();
	my $destination_ports = '';
	for my $natport_range (@natport_ranges) {
		my ($start_port, $end_port) = @$natport_range;
		if (!defined($start_port)) {
			notify($ERRORS{'WARNING'}, 0, "unable to parse NAT port range: '$natport_range'");
			next;
		}
		$destination_ports .= "," if ($destination_ports);
		$destination_ports .= "$start_port:$end_port";
	}
	
	
	$self->create_chain('filter', $nat_host_chain_name);
	$self->create_chain('nat', $nat_host_chain_name);
	if (!$self->insert_rule('filter', 'INPUT',
		{
			'parameters' => {
				'jump' => $nat_host_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump from filter table INPUT chain to NAT host $nat_host_chain_name chain",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('filter', 'FORWARD',
		{
			'parameters' => {
				'jump' => $nat_host_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump from filter table FORWARD chain to NAT host $nat_host_chain_name chain",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('nat', 'POSTROUTING',
		{
			'parameters' => {
				'jump' => $nat_host_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump from nat table POSTROUTING chain to NAT host $nat_host_chain_name chain",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('nat', $nat_host_chain_name,
		{
			'parameters' => {
				'out-interface' => $public_interface_name,
				'!destination' => "$internal_network_address/$internal_network_bits",
				'jump' => 'MASQUERADE',
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: change IP of outbound $public_interface_name packets to NAT host IP address $public_ip_address",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('filter', $nat_host_chain_name,
		{
			'parameters' => {
				'in-interface' => $public_interface_name,
				'destination' => $public_ip_address,
				'jump' => 'ACCEPT',
				'protocol' => 'tcp',
			},
			'match_extensions' => {
				'state' => {
					'state' => 'NEW,RELATED,ESTABLISHED',
				},
				'multiport' => {
					'destination-ports' => $destination_ports,
				},
				'comment' => {
					'comment' => "VCL: allow inbound TCP traffic on the NAT port ranges to public $public_interface_name",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('filter', $nat_host_chain_name,
		{
			'parameters' => {
				'in-interface' => $public_interface_name,
				'destination' => $public_ip_address,
				'jump' => 'ACCEPT',
				'protocol' => 'udp',
			},
			'match_extensions' => {
				'state' => {
					'state' => 'NEW,RELATED,ESTABLISHED',
				},
				'multiport' => {
					'destination-ports' => $destination_ports,
				},
				'comment' => {
					'comment' => "VCL: allow inbound UDP traffic on the NAT port ranges to public $public_interface_name",
				},
			},
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('filter', $nat_host_chain_name,
		{
			'parameters' => {
				'in-interface' => $public_interface_name,
				'out-interface' => $internal_interface_name,
				'jump' => 'ACCEPT',
			},
			'match_extensions' => {
				'state' => {
					'state' => 'NEW,RELATED,ESTABLISHED',
				},
				'comment' => {
					'comment' => "VCL: forward inbound packets from public $public_interface_name to internal $internal_interface_name",
				},
			},	
		}
	)) {
		return;
	}
	
	if (!$self->insert_rule('filter', $nat_host_chain_name,
		{
			'parameters' => {
				'in-interface' => $internal_interface_name,
				'out-interface' => $public_interface_name,
				'jump' => 'ACCEPT',
			},
			'match_extensions' => {
				'state' => {
					'state' => 'NEW,RELATED,ESTABLISHED',
				},
				'comment' => {
					'comment' => "VCL: forward outbound packets from internal $internal_interface_name to public $public_interface_name",
				},
			},
		}
	)) {
		return;
	}

	
	$self->save_configuration();
	notify($ERRORS{'DEBUG'}, 0, "successfully configured NAT on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 nat_configure_reservation

 Parameters  : none
 Returns     : boolean
 Description : Adds a chain named after the reservation ID to the nat table.
               Adds a rule to the PREROUTING table to jump to the reservation
               chain.

=cut

sub nat_configure_reservation {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_name = $self->data->get_computer_hostname();
	
	my $nat_table_info = $self->get_table_info('nat');
	if (!$nat_table_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name for reservation, nat table information could not be retrieved");
		return;
	}
	
	my $reservation_nat_chain_name = $self->get_nat_reservation_chain_name();
	
	# Check if chain for reservation has already been created
	if (defined($nat_table_info->{$reservation_nat_chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "'$reservation_nat_chain_name' chain already exists in nat table on $computer_name");
	}
	elsif (!$self->create_chain('nat', $reservation_nat_chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name for reservation, failed to add '$reservation_nat_chain_name' chain to nat table");
		return;
	}
	
	# Check if rule to jump to reservation's chain already exists in the PREROUTING table
	for my $rule (@{$nat_table_info->{PREROUTING}{rules}}) {
		my $rule_specification_string = $rule->{rule_specification};
		if ($rule_specification_string =~ /-j $reservation_nat_chain_name(\s|$)/) {
			notify($ERRORS{'DEBUG'}, 0, "PREROUTING chain in nat table on $computer_name already contains a rule to jump to '$reservation_nat_chain_name' chain: $rule_specification_string");
			return 1;;
		}
	}
	
	# Add a rule to the nat PREROUTING chain
	if (!$self->insert_rule('nat', 'PREROUTING',
		{
			'parameters' => {
				'jump' => $reservation_nat_chain_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: jump from nat table PREROUTING chain to reservation NAT chain $reservation_nat_chain_name",
				},
			},
		}
	)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name for reservation, failed to create rule in PREROUTING chain in nat table to jump to '$reservation_nat_chain_name' chain");
		return;
	}
	
	$self->save_configuration();
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 nat_add_port_forward

 Parameters  : $protocol, $source_port, $destination_ip_address, $destination_port
 Returns     : boolean
 Description : Forwards a port via DNAT.

=cut

sub nat_add_port_forward {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_name = $self->data->get_computer_hostname();
	
	my ($protocol, $source_port, $destination_ip_address, $destination_port) = @_;
	if (!defined($protocol)) {
		notify($ERRORS{'WARNING'}, 0, "protocol argument was not provided");
		return;
	}
	elsif (!defined($source_port)) {
		notify($ERRORS{'WARNING'}, 0, "source port argument was not provided");
		return;
	}
	elsif (!defined($destination_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "destination IP address argument was not provided");
		return;
	}
	elsif (!defined($destination_port)) {
		notify($ERRORS{'WARNING'}, 0, "destination port argument was not provided");
		return;
	}
	
	my $chain_name = $self->get_nat_reservation_chain_name();
	
	$protocol = lc($protocol);
	
	my $public_interface_name = $self->os->get_public_interface_name();
	
	my $nat_table_info = $self->get_table_info('nat');
	if (!$nat_table_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to add NAT port forward on $computer_name, nat table information could not be retrieved");
		return;
	}
	
	# Check if rule has previously been added
	for my $rule (@{$nat_table_info->{$chain_name}{rules}}) {
		my $rule_target = $rule->{parameters}{jump} || '<not set>';
		if ($rule_target ne 'DNAT') {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule, target is not DNAT: $rule_target");
			next;
		}
		
		my $rule_protocol = $rule->{parameters}{protocol} || '<not set>';
		if (lc($rule_protocol) ne $protocol) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule, protocol '$rule_protocol' does not match protocol argument: '$protocol'");
			next;
		}
		
		my $rule_source_port = $rule->{match_extensions}{$protocol}{dport} || '<not set>';
		if ($rule_source_port ne $source_port) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule, source port $rule_source_port does not match argument: $source_port");
			next;
		}
		
		my $rule_destination = $rule->{target_extensions}{DNAT}{'to-destination'} || '<not set>';
		if ($rule_destination ne "$destination_ip_address:$destination_port") {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule, destination $rule_destination does not match argument: $destination_ip_address:$destination_port");
			next;
		}
		
		my $rule_specification_string = $rule->{'rule_specification'};
		notify($ERRORS{'DEBUG'}, 0, "NAT port forwared rule already exists, chain: $chain_name, protocol: $protocol, source port: $source_port, destination: $destination_ip_address:$destination_port\nrule specification:\n$rule_specification_string");
		return 1;
	}
	
	if ($self->insert_rule('nat', $chain_name,
		{
			'parameters' => {
				'protocol' => $protocol,
				'in-interface' => $public_interface_name,
			},
			'match_extensions' => {
				'comment' => {
					'comment' => "VCL: forward $public_interface_name:$protocol/$source_port --> $destination_ip_address:$destination_port",
				},
				$protocol => {
					'destination-port' => $source_port,
				},
			},
			'target_extensions' => {
				'DNAT' => {
					'to-destination' => "$destination_ip_address:$destination_port",
				},
			},
		}
	)) {
		notify($ERRORS{'OK'}, 0, "added NAT port forward on $computer_name: $public_interface_name:$source_port --> $destination_ip_address:$destination_port");
		$self->save_configuration();
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add NAT port forward on $computer_name: $public_interface_name:$source_port --> $destination_ip_address:$destination_port");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 save_configuration

 Parameters  : $file_path (optional)
 Returns     : boolean
 Description : Saves the current iptables configuration by running
               iptables-save. If no file path argument is provided, the output
               is saved to /etc/sysconfig/iptables.

=cut

sub save_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $file_path = shift || '/etc/sysconfig/iptables';
	
	my $computer_id = $self->data->get_computer_id();
	my $computer_name = $self->data->get_computer_hostname();
	
	# Get the output of iptables-save
	# IMPORTANT: don't simply redirect the output to the file
	# If iptables is stopped or else the previously saved configuration will be overwritten
	my $command = '/sbin/iptables-save';
	my ($exit_status, $output) = $self->_execute_iptables($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to save iptables configuration on $computer_name");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	# Make sure output contains at least 1 line beginning with "-A"
	# If the iptables service is stopped the output will be blank
	# If the iptables service is stopped but "iptables -L" is executed the output may contain something like:
	# #Generated by iptables-save v1.4.7 on Thu Mar  5 13:36:51 2015
	# *filter
	# :INPUT ACCEPT [40:4736]
	# :FORWARD ACCEPT [0:0]
	# :OUTPUT ACCEPT [8:1200]
	# COMMIT
	# #Completed on Thu Mar  5 13:36:51 2015
	if (!grep(/\w/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_name, iptables service may not be running, no output was returned from $command");
		return 0;
	}
	elsif (!grep(/^-A/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "iptables configuration not saved to $file_path on $computer_name for safety, iptables service may not be running, output of $command does not contain any lines beginning with '-A':\n" . join("\n", @$output));
		return 0;
	}
	
	my $semaphore = $self->get_iptables_semaphore();
	if (!$semaphore) {
		notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_name, $file_path already exists and semaphore could not be obtained to avoid multiple processes writing to the file at the same time");
		return;
	}
	
	return $self->os->create_text_file($file_path, join("\n", @$output));
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_pre_capture_chain_name

 Parameters  : none
 Returns     : string
 Description : Returns 'vcl-pre_capture'.

=cut

sub get_pre_capture_chain_name {
	return 'vcl-pre_capture';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_post_load_chain_name

 Parameters  : none
 Returns     : string
 Description : Returns 'vcl-post_load'.

=cut

sub get_post_load_chain_name {
	return 'vcl-post_load';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reserved_chain_name

 Parameters  : none
 Returns     : string
 Description : Returns 'vcl-reserved'.

=cut

sub get_reserved_chain_name {
	return 'vcl-reserved';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_nat_host_chain_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the iptables chain on the NAT host containing
               rules for NAT to function. Returns 'vcl-nat_host'.

=cut

sub get_nat_host_chain_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	return 'vcl-nat_host';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_nat_reservation_chain_name

 Parameters  : $reservation_id (optional)
 Returns     : string
 Description : Returns the name of the iptables chain containing rules for a
               VCL reservation: '<vcld process name>-<reservation ID>'

=cut

sub get_nat_reservation_chain_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = shift || $self->data->get_reservation_id();
	return "$PROCESSNAME-$reservation_id";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_inuse_chain_name

 Parameters  : $reservation_id (optional)
 Returns     : string
 Description : Returns the name of the iptables chain containing rules added
               during the inuse state for a VCL reservation.

=cut

sub get_inuse_chain_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	return 'vcl-inuse';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cluster_chain_name

 Parameters  : none
 Returns     : string
 Description : Returns 'vcl-cluster'.

=cut

sub get_cluster_chain_name {
	return 'vcl-cluster';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 nat_delete_orphaned_reservation_chains

 Parameters  : none
 Returns     : boolean
 Description : Checks all of the chains that exist in the nat table on a NAT
               host. Chains which don't begin with the vcld process name
               followed by a hyphen (ex. 'vcld-') are ignored. Retrieves list of
               all reservation IDs currently in the database. If a chain exists
               but a corresponding reservation does not, the chain is deleted.

=cut

sub nat_delete_orphaned_reservation_chains {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my @reservation_ids = get_all_reservation_ids();
	if (!@reservation_ids) {
		notify($ERRORS{'WARNING'}, 0, "not deleting orphaned reservation chains on $computer_name, failed to retrieve all reservation IDs from the database");
		return;
	}
	my %reservation_id_hash = map { $_ => 1 } @reservation_ids;
	
	my @chain_names = $self->get_table_chain_names('nat');
	my @chains_ignored;
	my @chains_with_reservation;
	my @chains_deleted;
	
	for my $chain_name (@chain_names) {
		if ($chain_name !~ /^$PROCESSNAME-/) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring chain in nat table on $computer_name: $chain_name, name does not begin with '$PROCESSNAME-'");
			push @chains_ignored, $chain_name;
			next;
		}
		my ($chain_reservation_id) = $chain_name =~ /^$PROCESSNAME-(\d+)$/;
		if (!defined($chain_reservation_id)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring chain in nat table on $computer_name: $chain_name, reservation ID could not be determined from chain name, pattern: '$PROCESSNAME-<reservation ID>'");
			push @chains_ignored, $chain_name;
			next;
		}
		elsif (defined($reservation_id_hash{$chain_reservation_id})) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring chain in nat table on $computer_name: $chain_name, reservation $chain_reservation_id exists");
			push @chains_with_reservation, $chain_name;
			next;
		}
		
		notify($ERRORS{'OK'}, 0, "deleting orphaned chain in nat table on $computer_name: $chain_name, reservation $chain_reservation_id does NOT exist");
		if ($self->delete_chain('nat', $chain_name)) {
			push @chains_deleted, $chain_name;
		}
		else {
			return;
		}
	}
	
	if (scalar(@chains_deleted)) {
		$self->save_configuration();
	}
	
	notify($ERRORS{'DEBUG'}, 0, "checked for orphaned reservation chains on NAT host $computer_name:\n" .
		"chains ignored (" . scalar(@chains_ignored) . "): " . join(', ', @chains_ignored) . "\n" .
		"chains with a current reservation (" . scalar(@chains_with_reservation) . "): " . join(', ', @chains_with_reservation) . "\n" .
		"chains deleted (" . scalar(@chains_deleted) . "): " . join(', ', @chains_deleted)
	);
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _execute_iptables

 Parameters  : $iptables_command, $display_output (optional)
 Returns     : ($exit_status, $output)
 Description : Wrapper subroutine to execute iptables commands. This executes an
               iptables command and checks the output for the following error:
               "Another app is currently holding the xtables lock."
               
               If ancountered, up to 6 attempts is made to execute the iptables
               command. A progressive delay occurs between each attempt. The
               delay is 5 seconds longer for each attempt.

=cut

sub _execute_iptables {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($iptables_command, $display_output) = @_;
	if (!defined($iptables_command)) {
		notify($ERRORS{'WARNING'}, 0, "iptables command argument was not supplied");
		return;
	}
	
	$display_output = 0 unless defined($display_output);
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $attempt_limit = 6;
	for (my $attempt = 1; $attempt <= $attempt_limit; $attempt++) {
		my ($exit_status, $output) = $self->os->execute($iptables_command, $display_output);
		if (defined($output) && $attempt < $attempt_limit) {
			# Another app is currently holding the xtables lock. Perhaps you want to use the -w option?
			if ($exit_status ne 0 && grep(/xtables lock/, @$output)) {
				my $sleep_seconds = ($attempt * 5);
				notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: unable to execute iptables command on $computer_name becuase another process is holding an xtables lock, waiting for $sleep_seconds seconds before attempting command again, command: '$iptables_command', output:" . (scalar(@$output) > 1 ? "\n" . join("\n", @$output) : " '" . join("\n", @$output) . "'"));
				sleep_uninterrupted($sleep_seconds);
				next;
			}
		}
		return ($exit_status, $output);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : true
 Description : Prints the number of calls to get_table_info.

=cut

sub DESTROY {
	my $self = shift || return;
	
	my $address = sprintf('%x', $self);
	my $table_count_string;
	if ($ENV{iptables_get_table_info_count}) {
		for my $table_name (keys %{$ENV{iptables_get_table_info_count}}) {
			my $table_count = $ENV{iptables_get_table_info_count}{$table_name};
			$table_count_string .= "$table_name: $table_count\n";
		}
		notify($ERRORS{'DEBUG'}, 0, "get_table_info calls ($address):\n$table_count_string");
	}
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
