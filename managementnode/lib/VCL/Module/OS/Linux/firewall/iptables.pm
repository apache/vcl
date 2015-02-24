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

 This module provides VCL support for iptables-based firewalls.

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
 Description : 

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

 Parameters  : none
 Returns     : boolean
 Description : 

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
 Description : 

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
			notify($ERRORS{'DEBUG'}, 0, "parsing iptables append rule command:\n" .
				"iptables command: $line\n" .
				"iptables rule specification: $rule_specification_string"
			);
			
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
						notify($ERRORS{'DEBUG'}, 0, "located $target_parameter target extension option: $target_extension_option_name");
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
				notify($ERRORS{'DEBUG'}, 0, "parsed iptables target parameter:\n" .
					"target parameter: $target_parameter_match\n" .
					"target: $target\n" .
					"target specification removal regex: $target_parameter_regex\n" .
					"rule specification before: $rule_specification_string_before\n" .
					"rule specification after:  $rule_specification_string"
				);
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
						notify($ERRORS{'DEBUG'}, 0, "located match extension module name: $match_extension_module_name");
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
					notify($ERRORS{'DEBUG'}, 0, "match extension module name: $match_extension_module_name, located match extension option: $match_extension_option");
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
 Description : 

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
		if ($rule =~ /MASQUERADE/) {
			notify($ERRORS{'DEBUG'}, 0, "POSTROUTING chain in nat table contains a MASQUERADE rule, assuming NAT has already been configured: $rule");
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
	
	my $chain_name = "$PROCESSNAME-$reservation_id";
	
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
		if ($rule =~ /-j $chain_name(\s|$)/) {
			notify($ERRORS{'DEBUG'}, 0, "PREROUTING chain in nat table on $computer_name already contains a rule to jump to '$chain_name' chain: $rule");
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
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_nat_port_forward

 Parameters  : $protocol, $source_port, $destination_ip_address, $destination_port, $chain_name (optional)
 Returns     : boolean
 Description : 

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
	$chain_name = 'PREROUTING' unless defined $chain_name;
	
	$protocol = lc($protocol);
	
	my $public_interface_name = $self->os->get_public_interface_name();
	my $public_ip_address = $self->os->get_public_ip_address();
	
	if ($self->insert_rule({
		'table' => 'nat',
		'chain' => $chain_name,
		'parameters' => {
			'protocol' => $protocol,
			'in-interface' => $public_interface_name,
			#'destination' => $public_ip_address,
		},
		'match_extensions' => {
			'comment' => {
				'comment' => "forward: $public_ip_address:$source_port --> $destination_ip_address:$destination_port ($protocol)",
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

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
