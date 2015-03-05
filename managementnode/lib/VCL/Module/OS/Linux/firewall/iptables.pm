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

##############################################################################
package VCL::Module::OS::Linux::firewall::iptables;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::firewall);

# Specify the version of this module
our $VERSION = '2.4';

our @ISA;

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

#/////////////////////////////////////////////////////////////////////////////

=head2 insert_rule

 Parameters  : hash reference
 Returns     : boolean
 Description : Inserts an iptables rule. The argument must be a properly
               constructed hash reference. Supported top-level hash keys are:
               * {table} => '<string>' (optional)
                    Specifies the name of the table the rule will be added to.
                    If ommitted, the rule will be added to the filter table by
                    default.
               * {chain} => '<string>' (mandatory)
                    Specifies the name of the chain the rule will be added to.
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
               {
                  'table' => 'nat',
                  'chain' => 'PREROUTING',
                  'parameters' => {
                     'protocol' => 'tcp',
                     'in-interface' => 'eth1',
                  },
                  'match_extensions' => {
                     'comment' => {
                        'comment' => "forward: eth1:50443 --> 10.1.2.3.4:443 (tcp)",
                     },
                     $protocol => {
                        'destination-port' => 50443,
                     },
                  },
                  'target_extensions' => {
                     'DNAT' => {
                        'to-destination' => "10.1.2.3.4:443",
                     },
                  },
               }

=cut

sub insert_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $arguments = shift;
	if (!$arguments) {
		notify($ERRORS{'WARNING'}, 0, "argument was not supplied");
		return;
	}
	elsif (!ref($arguments) || ref($arguments) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument is not a hash reference");
		return;
	}
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = '/sbin/iptables';
	
	# Add the table argument if specified
	if ($arguments->{table}) {
		$command .= " -t $arguments->{table}";
	}
	
	# Get the chain argument
	my $chain = $arguments->{chain};
	if (!defined($chain)) {
		notify($ERRORS{'WARNING'}, 0, "chain argument was not specified:\n" . format_data($arguments));
		return;
	}
	$command .= " -I $chain";
	
	# Add the parameters to the command
	for my $parameter (sort keys %{$arguments->{parameters}}) {
		my $value = $arguments->{parameters}{$parameter};
		
		if ($parameter =~ /^\!/) {
			$command .= " !";
			$parameter =~ s/^\!//;
		}
		$command .= " --$parameter $value";
	}
	
	# Add the match extension to the command
	for my $match_extension (sort keys %{$arguments->{match_extensions}}) {
		$command .= " --match $match_extension";
		for my $option (sort keys %{$arguments->{match_extensions}{$match_extension}}) {
			my $value = $arguments->{match_extensions}{$match_extension}{$option};
			
			if ($option =~ /(comment)/) {
				$value = "\"$value\"";
			}
			
			if ($option =~ /^\!/) {
				$command .= " !";
				$option =~ s/^\!//;
			}
			
			$command .= " ";
			$command .= "--$option " if $option;
			$command .= $value;
		}
	}
	
	# Add the target extensions to the command
	for my $target_extension (sort keys %{$arguments->{target_extensions}}) {
		$command .= " --jump $target_extension";
		for my $option (sort keys %{$arguments->{target_extensions}{$target_extension}}) {
			my $value = $arguments->{target_extensions}{$target_extension}{$option};
			$command .= " --$option " if $option;
			$command .= $value;
		}
	}
	
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add iptables rule on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "added iptables rule on $computer_name, command: $command");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_rule

 Parameters  : hash reference
               -or-
               $table_name, $chain_name, $rule_specification
 Returns     : boolean
 Description : Deletes a rule.

=cut

sub delete_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $argument = shift;
	if (!$argument) {
		notify($ERRORS{'WARNING'}, 0, "argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = '/sbin/iptables';
	
	
	if (ref($argument) && ref($argument) eq 'HASH') {
		# Add the table argument if specified
		if ($argument->{table}) {
			$command .= " -t $argument->{table}";
		}
		
		# Get the chain argument
		my $chain = $argument->{chain};
		if (!defined($chain)) {
			notify($ERRORS{'WARNING'}, 0, "chain argument was not specified:\n" . format_data($argument));
			return;
		}
		$command .= " -D $chain";
		
		# Add the parameters to the command
		for my $parameter (sort keys %{$argument->{parameters}}) {
			my $value = $argument->{parameters}{$parameter};
			$command .= " --$parameter $value";
		}
		
		# Add the match extension to the command
		for my $match_extension (sort keys %{$argument->{match_extensions}}) {
			$command .= " --match $match_extension";
			for my $option (sort keys %{$argument->{match_extensions}{$match_extension}}) {
				my $value = $argument->{match_extensions}{$match_extension}{$option};
				
				if ($option =~ /(comment)/) {
					$value = "\"$value\"";
				}
				
				$command .= " --$option $value";
			}
		}
		
		# Add the target extensions to the command
		for my $target_extension (sort keys %{$argument->{target_extensions}}) {
			$command .= " --jump $target_extension";
			for my $option (sort keys %{$argument->{target_extensions}{$target_extension}}) {
				my $value = $argument->{target_extensions}{$target_extension}{$option};
				$command .= " --$option $value";
			}
		}
	}
	elsif (my $type = ref($argument)) {
		notify($ERRORS{'WARNING'}, 0, "argument $type reference not supported, argument must only be a HASH reference or scalar");
		return;
	}
	else {
		my $table_name = $argument;
		my ($chain_name, $specification) = @_;
		if (!defined($chain_name) || !defined($specification)) {
			notify($ERRORS{'WARNING'}, 0, "1st argument is a scalar, 2nd chain name and 3rd rule specification arguments not provided");
			return;
		}
		$command .= " -D $chain_name -t $table_name $specification";
	}
	
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete iptables rule on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted iptables rule on $computer_name, command: $command");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	my $command = "/sbin/iptables --new-chain $chain_name --table $table_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
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

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_chain

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Deletes the specified chain from the specified table. All rules
               which exist in the chain or reference the chain are deleted prior
               to deletion of the chain.

=cut

sub delete_chain {
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
	if (!defined($table_info->{$chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "'$chain_name' chain in '$table_name' table does not exist on $computer_name");
		return 1;
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
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif (grep(/Too many links/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete '$chain_name' chain from '$table_name' table on $computer_name, the chain is referenced by another rule");
		return 0;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$chain_name' chain from '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted '$chain_name' chain from '$table_name' table on $computer_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sanitize_reservation

 Parameters  : $reservation_id (optional)
 Returns     : boolean
 Description : Deletes the chains created for the reservation. Saves the
               iptables configuration.

=cut

sub sanitize_reservation {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = shift || $self->data->get_reservation_id();
	my $reservation_chain_name = $self->get_reservation_chain_name($reservation_id);
	
	if (!$self->delete_chain('nat', $reservation_chain_name)) {
		return;
	}
	
	$self->save_configuration();
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_chain_references

 Parameters  : $table_name, $referenced_chain_name
 Returns     : boolean
 Description : Checks all chains in the specified table for references to the
               $referenced_chain_name argument. If found, the referencing rules
               are deleted.

=cut

sub delete_chain_references {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $referenced_chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!defined($referenced_chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "referenced chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $table_info = $self->get_table_info($table_name);
	for my $referencing_chain_name (keys %$table_info) {
		for my $rule (@{$table_info->{$referencing_chain_name}{rules}}) {
			my $rule_specification = $rule->{rule_specification};
			if ($rule_specification =~ /-j $referenced_chain_name(\s|$)/) {
				notify($ERRORS{'DEBUG'}, 0, "rule in '$table_name' table references '$referenced_chain_name' chain, referencing chain: $referencing_chain_name, rule specification: $rule_specification");
				if (!$self->delete_rule($table_name, $referencing_chain_name, $rule_specification)) {
					return;
				}
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "deleted all rules in '$table_name' table referencing '$referenced_chain_name' chain on $computer_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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
	
	my $command = "/sbin/iptables --flush";
	my $chain_text = 'all chains';
	if ($chain_name ne '*') {
		$chain_text = "'$chain_name' chain";
		$command .= " $chain_name";
	}
	$command .= " --table $table_name";
	
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to flush $chain_text in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "flushed $chain_text in '$table_name' table on $computer_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_table_info

 Parameters  : $table_name, $chain_name (optional)
 Returns     : boolean
 Description : Retrieves the configuration of an iptables table and constructs a
               hash reference. Example:
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
	
	my ($table_name, $chain_name) = @_;
	if (!defined($table_name)) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	
	$ENV{iptables_get_table_info_count}{$table_name}++;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "/sbin/iptables --list-rules";
	my $chain_text = '';
	if (defined($chain_name)) {
		$command .= " $chain_name";
		$chain_text = "of '$chain_name' chain ";
	}
	$command .= " --table $table_name";
	
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list rules " . $chain_text . "from '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}

	my $table_info = {};
	LINE: for my $line (@$output) {
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
			my $parameters = {
				'protocol'      => '\s*(\!?)\s*(-p|--protocol)\s+([^\s]+)',
				'source'        => '\s*(\!?)\s*(-s|--source)\s+([\d\.\/]+)',
				'destination'   => '\s*(\!?)\s*(-d|--destination)\s+([\d\.\/]+)',
				'in-interface'  => '\s*(\!?)\s*(-i|--in-interface)\s+([^\s]+)',
				'out-interface' => '\s*(\!?)\s*(-o|--out-interface)\s+([^\s]+)',
				'fragment'      => '\s*(\!?)\s*(-f|--fragment)',
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
				$rule_specification_string =~ s/(^\s+|$pattern|\s+$)//ig;
			}
			
			# Parse the target rule parameters
			my $target_parameters = {
				'jump' => '\s*(-j|--jump)\s+([^\s]+)\s*(.*)',
				'goto' => '\s*(-g|--goto)\s+([^\s]+)\s*(.*)',
			};
			
			# Parse the parameters which specify targets
			TARGET_PARAMETER: for my $target_parameter (keys %$target_parameters) {
				my $pattern = $target_parameters->{$target_parameter};
				my ($target_parameter_match, $target, $target_extension_option_string) = $rule_specification_string =~ /$pattern/ig;
				next TARGET_PARAMETER unless $target_parameter_match;
				
				# Assemble a regex to remove the target specification from the overall specification
				my $target_parameter_regex = "\\s*$target_parameter_match\\s+$target\\s*";
				
				$rule->{parameters}{$target_parameter}{target} = $target;
				
				my $target_extension_option_name;
				my @target_extension_option_sections = split(/\s+/, $target_extension_option_string);
				TARGET_OPTION_SECTION: for my $target_extension_option_section (@target_extension_option_sections) {
					# Stop parsing if the start of a match extension specification if found
					if ($target_extension_option_section =~ /^(-m|--match)$/) {
						last TARGET_OPTION_SECTION;
					}
					
					# Check if this is the beginning of a target extension option
					if ($target_extension_option_section =~ /^[-]+(\w[\w-]+)/) {
						$target_extension_option_name = $1;
						#notify($ERRORS{'DEBUG'}, 0, "located $target_parameter target extension option: $target_extension_option_name");
						$rule->{parameters}{$target_parameter}{$target_extension_option_name} = undef;
					}
					elsif (!$target_extension_option_name) {
						# If here, the section should be a target extension option value
						notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule, target extension option name was not detected before this section: '$target_extension_option_section'\n" .
							"iptables command: $line\n" .
							"preceeding target parameter: $target_parameter --> $target"
						);
						next LINE;
					}
					else {
						# Found target extension option value
						$rule->{parameters}{$target_parameter}{$target_extension_option_name} = $target_extension_option_section;
						$target_extension_option_name = undef;
					}
					
					# Add the section to the regex so it will be removed
					$target_parameter_regex .= "$target_extension_option_section\\s*";
				}  # TARGET_OPTION_SECTION
				
				my $rule_specification_string_before = $rule_specification_string;
				$rule_specification_string =~ s/$target_parameter_regex//g;
				#notify($ERRORS{'DEBUG'}, 0, "parsed iptables target parameter:\n" .
				#	"target parameter: $target_parameter_match\n" .
				#	"target: $target\n" .
				#	"target specification removal regex: $target_parameter_regex\n" .
				#	"rule specification before: $rule_specification_string_before\n" .
				#	"rule specification after:  $rule_specification_string"
				#);
			}  # TARGET_PARAMETER
			
			
			# The only text remaining in $rule_specification_string should be match extension information
			# Split the remaining string by spaces
			my @match_extension_sections = split(/\s+/, $rule_specification_string);
			
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
						notify($ERRORS{'WARNING'}, 0, "failed to parse iptables rule, match extension module name was not detected before this section: '$match_extension_section'\n" .
							"iptables rule specification: $rule_specification_string\n" .
							"iptables command: $line"
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
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved rules " . $chain_text . "from iptables $table_name table from $computer_name:\n" . format_data($table_info));
	return $table_info;
}


#/////////////////////////////////////////////////////////////////////////////

=head2 configure_nat

 Parameters  : $public_ip_address, $internal_ip_address
 Returns     : boolean
 Description : Configures the iptables firewall to pass NAT traffic.

=cut

sub configure_nat {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my ($public_ip_address, $internal_ip_address) = @_;
	if (!$public_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to automatically configure NAT, nathost public IP address argument was not specified");
		return;
	}
	if (!$internal_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to automatically configure NAT, nathost internal IP address argument was not specified");
		return;
	}
	
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
	for my $rule (@{$nat_table_info->{POSTROUTING}{rules}}) {
		my $rule_specification = $rule->{rule_specification};
		if ($rule_specification =~ /MASQUERADE/) {
			notify($ERRORS{'DEBUG'}, 0, "POSTROUTING chain in nat table contains a MASQUERADE rule, assuming NAT has already been configured: $rule_specification");
			return 1;
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
	
	if (!$self->insert_rule({
		'table' => 'nat',
		'chain' => 'POSTROUTING',
		'parameters' => {
			'out-interface' => $public_interface_name,
			'!destination' => "$internal_network_address/$internal_network_bits",
			'jump' => 'MASQUERADE',
		},
		'match_extensions' => {
			'comment' => {
				'comment' => "change IP of outbound $public_interface_name packets to NAT host IP address $public_ip_address",
			},
		},
	})) {
		return;
	}
	
	if (!$self->insert_rule({
		'chain' => 'INPUT',
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
		},
	})) {
		return;
	}
	
	if (!$self->insert_rule({
		'chain' => 'INPUT',
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
		},
	})) {
		return;
	}
	
	if (!$self->insert_rule({
		'chain' => 'FORWARD',
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
				'comment' => "forward inbound packets from public $public_interface_name to internal $internal_interface_name",
			},
		},	
	})) {
		return;
	}
	
	if (!$self->insert_rule({
		'chain' => 'FORWARD',
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
				'comment' => "forward outbound packets from internal $internal_interface_name to public $public_interface_name",
			},
		},
	})) {
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "successfully configured NAT on $computer_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_nat_reservation

 Parameters  : none
 Returns     : boolean
 Description : Adds a chain named after the reservation ID to the nat table.
               Adds a rule to the PREROUTING table to jump to the reservation
               chain.

=cut

sub configure_nat_reservation {
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
	
	my $chain_name = $self->get_reservation_chain_name();
	
	# Check if chain for reservation has already been created
	if (defined($nat_table_info->{$chain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "'$chain_name' chain already exists in nat table on $computer_name");
	}
	elsif (!$self->create_chain('nat', $chain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name for reservation, failed to add '$chain_name' chain to nat table");
		return;
	}
	
	# Check if rule to jump to reservation's chain already exists in the PREROUTING table
	for my $rule (@{$nat_table_info->{PREROUTING}{rules}}) {
		my $rule_specification = $rule->{rule_specification};
		if ($rule_specification =~ /-j $chain_name(\s|$)/) {
			notify($ERRORS{'DEBUG'}, 0, "PREROUTING chain in nat table on $computer_name already contains a rule to jump to '$chain_name' chain: $rule_specification");
			return 1;;
		}
	}
	
	# Add a rule to the nat PREROUTING chain
	if (!$self->insert_rule({
		'table' => 'nat',
		'chain' => 'PREROUTING',
		'parameters' => {
			'jump' => $chain_name,
		},
	})) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure NAT host $computer_name for reservation, failed to create rule in PREROUTING chain in nat table to jump to '$chain_name' chain");
		return;
	}
	
	$self->save_configuration();
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_nat_port_forward

 Parameters  : $protocol, $source_port, $destination_ip_address, $destination_port, $chain_name (optional)
 Returns     : boolean
 Description : Forwards a port via DNAT.

=cut

sub add_nat_port_forward {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_name = $self->data->get_computer_hostname();
	
	my ($protocol, $source_port, $destination_ip_address, $destination_port, $chain_name) = @_;
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
	$chain_name = $self->get_reservation_chain_name() unless defined $chain_name;
	
	$protocol = lc($protocol);
	
	my $public_interface_name = $self->os->get_public_interface_name();
	
	my $nat_table_info = $self->get_table_info('nat');
	if (!$nat_table_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to add NAT port forward on $computer_name, nat table information could not be retrieved");
		return;
	}
	
	# Check if rule has previously been added
	for my $rule (@{$nat_table_info->{$chain_name}{rules}}) {
		my $rule_target = $rule->{parameters}{jump}{target} || '<not set>';
		if ($rule_target ne 'DNAT') {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, target is not DNAT: $rule_target");
			next;
		}
		
		my $rule_protocol = $rule->{parameters}{protocol} || '<not set>';
		if (lc($rule_protocol) ne $protocol) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, protocol '$rule_protocol' does not match protocol argument: '$protocol'");
			next;
		}
		
		my $rule_source_port = $rule->{match_extensions}{$protocol}{dport} || '<not set>';
		if ($rule_source_port ne $source_port) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, source port $rule_source_port does not match argument: $source_port");
			next;
		}
		
		my $rule_destination = $rule->{parameters}{jump}{'to-destination'} || '<not set>';
		if ($rule_destination ne "$destination_ip_address:$destination_port") {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, destination $rule_destination does not match argument: $destination_ip_address:$destination_port");
			next;
		}
		
		my $rule_specification = $rule->{'rule_specification'};
		notify($ERRORS{'DEBUG'}, 0, "NAT port forwared rule already exists, chain: $chain_name, protocol: $protocol, source port: $source_port, destination: $destination_ip_address:$destination_port\nrule specification:\n$rule_specification");
		return 1;
	}
	
	if ($self->insert_rule({
		'table' => 'nat',
		'chain' => $chain_name,
		'parameters' => {
			'protocol' => $protocol,
			'in-interface' => $public_interface_name,
		},
		'match_extensions' => {
			'comment' => {
				'comment' => "forward: $public_interface_name:$source_port --> $destination_ip_address:$destination_port ($protocol)",
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
	})) {
		notify($ERRORS{'OK'}, 0, "added NAT port forward on $computer_name: $public_interface_name:$source_port --> $destination_ip_address:$destination_port");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add NAT port forward on $computer_name: $public_interface_name:$source_port --> $destination_ip_address:$destination_port");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_chain_name

 Parameters  : $reservation_id (optional)
 Returns     : string
 Description : Returns the name of the iptables chain containing rules for a
               single VCL reservation.

=cut

sub get_reservation_chain_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = shift || $self->data->get_reservation_id();
	return "$PROCESSNAME-$reservation_id";
}

#/////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to save iptables configuration on $computer_name");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	my $file_exists = $self->os->file_exists($file_path);
	
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
	elsif (!grep(/^-A/, @$output) && ($file_exists || $file_path eq '/etc/sysconfig/iptables')) {
		notify($ERRORS{'WARNING'}, 0, "iptables configuration not saved to $file_path on $computer_name for safety, iptables service may not be running, output of $command does not contain any lines beginning with '-A':\n" . join("\n", @$output));
		return 0;
	}
	
	# Attempt to get a semaphore if the file already exists
	my $semaphore;
	if ($file_exists) {
		$semaphore = $self->get_semaphore("iptables-save_configuration-$computer_id", (30 * 1));
		if (!$semaphore) {
			notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_name, $file_path already exists and semaphore could not be obtained to avoid multiple processes writing to the file at the same time");
			return;
		}
	}
	
	return $self->os->create_text_file($file_path, join("\n", @$output));
}

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : true
 Description : 

=cut

sub DESTROY {
	my $self = shift || return;
	
	my $address = sprintf('%x', $self);
	my $table_count_string;
	if ($ENV{iptables_get_table_info_count}) {
		for my $table_name (keys $ENV{iptables_get_table_info_count}) {
			my $table_count = $ENV{iptables_get_table_info_count}{$table_name};
			$table_count_string .= "$table_name: $table_count\n";
		}
		notify($ERRORS{'DEBUG'}, 0, "get_table_info calls:\n$table_count_string");
	}
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
