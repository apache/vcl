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

VCL::Module::OS::Linux::firewall::firewalld.pm

=head1 DESCRIPTION

 This module provides VCL support for firewalld-based firewalls.

=cut

###############################################################################
package VCL::Module::OS::Linux::firewall::firewalld;

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
	
	if (!$self->os->service_exists('firewalld')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, firewalld service does not exist");
		return 0;
	}
	
	if (!$self->os->is_service_enabled('firewalld')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, firewalld service is not enabled");
		return 0;
	}
	
	if (!$self->os->command_exists('firewall-cmd')) {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object not initialized to control $computer_name, firewall-cmd command does not exist");
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
               * Performs all of the tasks done by
                 iptables.pm::process_post_load except the pre-VCL 2.5 legacy
                 cleanup tasks
               * Removes the ssh protocol from the public zone

=cut

sub process_post_load {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS::Linux::firewall/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "beginning firewalld post-load configuration on $computer_name");
	
	# Call subroutine in iptables.pm
	return unless $self->SUPER::process_post_load();
	
	# Remove ssh from public zone
	return unless $self->remove_service('public', 'ssh');
	
	$self->save_configuration();
	
	notify($ERRORS{'DEBUG'}, 0, "completed firewalld post-load configuration on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_all_direct_rules

 Parameters  : none
 Returns     : array
 Description : Calls 'firewall-cmd --permanent --direct --get-all-rules' and
               returns an array of strings.

=cut

sub get_all_direct_rules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --direct --get-all-rules";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve all firewalld direct rules on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve all firewalld direct rules on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Rules should be in the format:
	# ipv4 filter vcl-pre_capture 0 --jump ACCEPT --protocol tcp --match comment --comment 'VCL: Allow traffic to SSH port 22 from any IP address (2017-04-07 17:19:21)' --match tcp --destination-port 22
	# ipv4 filter INPUT 0 --jump vcl-pre_capture --match comment --comment 'VCL: jump to rules added during the pre-capture stage (2017-04-07 17:19:21)'
	my @rules = grep(/^(ipv4|ipv6|eb)/, @$output);
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved all firewalld direct rules defined on $computer_name:\n" . join("\n", @rules));
	return @rules;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_direct_chain_rules

 Parameters  : $table_name, $chain_name
 Returns     : array
 Description : Calls 'firewall-cmd --permanent --direct --get-rules' and returns
               an array of strings.

=cut

sub get_direct_chain_rules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name) = @_;
	if (!$table_name) {
		notify($ERRORS{'WARNING'}, 0, "table name argument was not specified");
		return;
	}
	elsif (!$chain_name) {
		notify($ERRORS{'WARNING'}, 0, "chain name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --direct --get-rules ipv4 $table_name $chain_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve firewalld direct rules defined for '$chain_name' chain in '$table_name' table on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewalld direct rules defined for '$chain_name' chain in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# All rule lines should begin with an integer:
	#    0 --jump ACCEPT --source 10.25.7.2 --match comment --comment 'VCL: Allow traffic from management node (2017-04-07 15:36:24)'
	#    1 --jump ACCEPT --source 10.25.7.2
	my @rules = grep(/^\d+/, @$output);
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved firewalld direct rules defined for '$chain_name' chain in '$table_name' table on $computer_name:\n" . join("\n", @rules));
	return @rules;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 save_configuration

 Parameters  : none
 Returns     : boolean
 Description : Calls 'firewall-cmd --reload'.

=cut

sub save_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --reload";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to reload firewalld configuration on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to reload firewalld configuration on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "reloaded firewalld configuration on $computer_name");
		return 1;
	}
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
	
	my $command = "firewall-cmd --permanent --direct --add-chain ipv4 $table_name $chain_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
		return;
	}
	elsif (grep(/ALREADY_ENABLED/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "'$chain_name' chain in '$table_name' table already exists on $computer_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to create '$chain_name' chain in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	elsif (!grep(/success/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "potentially failed to create '$chain_name' chain in '$table_name' table on $computer_name, output does not contain 'success', exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "created '$chain_name' chain in '$table_name' table on $computer_name");
		#$self->save_configuration();
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_direct_chain_rules

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Flushes (deletes) rules from the specified chain.

=cut

sub remove_direct_chain_rules {
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
	
	# !!! WARNING !!!
	# DON'T USE --remove-rules
	# With firewall-cmd version 0.4.3.2, this option removes rules from ALL direct chains, not just the one specified
	#my $command = "firewall-cmd --permanent --direct --remove-rules ipv4 $table_name $chain_name";
	
	my @rules = $self->get_direct_chain_rules($table_name, $chain_name);
	for my $rule (@rules) {
		# [--permanent] --direct --remove-rule { ipv4 | ipv6 | eb } table chain priority args
		my $command = "firewall-cmd --permanent --direct --remove-rule ipv4 $table_name $chain_name $rule";
		my ($exit_status, $output) = $self->os->execute($command, 0);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
			return;
		}
		elsif ($exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to remove rule from '$chain_name' chain in '$table_name' table on $computer_name: '$rule', exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "removed direct rule from '$chain_name' chain in '$table_name' table on $computer_name: '$rule'");
		}
	}
	
	notify($ERRORS{'OK'}, 0, "removed all direct rules from '$chain_name' chain in '$table_name' table on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_chain

 Parameters  : $table_name, $chain_name
 Returns     : boolean
 Description : Deletes an existing chain. Returns true if the chain was
               successfully deleted or doesn't exist.

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
		
		# Delete all rules which reference the chain being deleted or else the chain can't be deleted
		# Do this BEFORE checking if the chain exists to clean up leftover references in direct.xml
		if (!$self->delete_chain_references($table_name, $chain_name)) {
			notify($ERRORS{'WARNING'}, 0, "unable to delete '$chain_name' chain from '$table_name' table on $computer_name, failed to delete all rules which reference the chain prior to deletion");
			return;
		}
	
		$self->remove_direct_chain_rules($table_name, $chain_name) || return;
		
		my $command = "firewall-cmd --permanent --direct --remove-chain ipv4 $table_name $chain_name";
		my ($exit_status, $output) = $self->os->execute($command, 0);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command $computer_name: $command");
			return;
		}
		elsif (grep(/NOT_ENABLED/i, @$output)) {
			notify($ERRORS{'OK'}, 0, "'$chain_name' chain in '$table_name' does not exist on $computer_name");
		}
		elsif ($exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to delete '$chain_name' chain in '$table_name' table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return 0;
		}
		elsif (!grep(/success/, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "potentially failed to delete '$chain_name' chain in '$table_name' table on $computer_name, output does not contain 'success', exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		}
		else {
			notify($ERRORS{'OK'}, 0, "deleted '$chain_name' chain in '$table_name' table on $computer_name");
			#$self->save_configuration();
		}
		
		if (!$self->clean_direct_xml($table_name . '.*jump\s+' . $chain_name)) {
			return;
		}
		
		notify($ERRORS{'OK'}, 0, "deleted '$chain_name' chain from '$table_name' table on $computer_name");
		push @chains_deleted, $chain_name;
	}
	
	if (!@chains_deleted) {
		notify($ERRORS{'DEBUG'}, 0, "no chains exist in '$table_name' table on $computer_name matching argument: '$chain_name_argument'");
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 clean_direct_xml

 Parameters  : $regex_pattern
 Returns     : boolean
 Description : 

=cut

sub clean_direct_xml {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $regex_pattern = shift;
	if (!defined($regex_pattern)) {
		notify($ERRORS{'WARNING'}, 0, "regex pattern argument was not supplied");
		return;
	}
	
	$self->os->firewall->save_configuration();
	
	my @keep_lines;
	my @prune_lines;
	my $file_path = '/etc/firewalld/direct.xml';
	my @lines = $self->os->get_file_contents($file_path);
	for my $line (@lines) {
		if ($line =~ /$regex_pattern/i) {
			push @prune_lines, $line;
		}
		else {
			push @keep_lines, $line;
		}
	}
	
	if (@prune_lines) {
		my $updated_contents = join("\n", @keep_lines);
		notify($ERRORS{'DEBUG'}, 0, "pruning the following lines from $file_path matching pattern: '$regex_pattern'\n" . join("\n", @prune_lines) . "\nnew file contents:\n$updated_contents");
		return $self->os->create_text_file($file_path, $updated_contents);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no lines were pruned from $file_path matching pattern: '$regex_pattern'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _insert_rule

 Parameters  : $table_name, $chain_name, $argument_string
 Returns     : boolean
 Description : Executes the command to insert a firewalld direct rule. This is a
               helper subroutine and should only be called by
               iptable.pm::insert_rule.

=cut

sub _insert_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $argument_string) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --direct --add-rule ipv4 $table_name $chain_name 0 $argument_string";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add direct firewalld rule to $chain_name chain in $table_name table on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add direct firewalld rule to $chain_name chain in $table_name table on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "added direct firewalld rule to $chain_name chain in $table_name table on $computer_name, command: $command, output:\n" . join("\n", @$output));
		#$self->save_configuration();
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _delete_rule

 Parameters  : $table_name, $chain_name, $rule_specification_string
 Returns     : boolean
 Description : Deletes a firewalld direct rule. This should only used as a
               helper subroutine.

=cut

sub _delete_rule {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($table_name, $chain_name, $rule_specification_string) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --direct --remove-rule ipv4 $table_name $chain_name 0 $rule_specification_string";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete firewalld direct rule on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete firewalld direct rule on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted firewalld direct rule on $computer_name, command: '$command', output:\n" . join("\n", @$output));
		#$self->save_configuration();
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_service

 Parameters  : $zone_name, $service
 Returns     : boolean
 Description : 

=cut

sub remove_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $service) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($service)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	$service = 'tcp' unless $service;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --remove-service=serviceid[-serviceid]/service
	#            Remove the service from zone. If zone is omitted, default zone will be used. This option can be specified
	#            multiple times.
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --remove-service=$service";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to remove $service service from '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;

	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to remove $service service from '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/NOT_ENABLED/, @$output)) {
		notify($ERRORS{'OK'}, 0, "$service service has not been added to '$zone_name' zone on $computer_name");
	}
	else {
		notify($ERRORS{'OK'}, 0, "removed $service service from '$zone_name' zone on $computer_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_zone

 Parameters  : $zone_name
 Returns     : boolean
 Description : Creates a new firewalld zone on the computer.

=cut

sub create_zone {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --new-zone=$zone_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to create '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if (grep(/NAME_CONFLICT/, @$output)) {
		# Error: NAME_CONFLICT: new_zone(): 'vcl-test'
		notify($ERRORS{'OK'}, 0, "'$zone_name' zone already exists on $computer_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to create '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "created '$zone_name' zone on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_zone

 Parameters  : $zone_name
 Returns     : boolean
 Description : Deletes a firewalld zone from the computer.

=cut

sub delete_zone {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --delete-zone=$zone_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if (grep(/INVALID_ZONE/, @$output)) {
		# Error: INVALID_ZONE: vcl-test
		notify($ERRORS{'OK'}, 0, "'$zone_name' zone does not exist on $computer_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted '$zone_name' zone on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_zone_info

 Parameters  : $zone_name
 Returns     : hash reference
 Description : Retrieves information about a firewalld zone from the computer
               and constructs a hash reference:
                  {
                    "forward-ports" => "",
                    "icmp-block-inversion" => "no",
                    "icmp-blocks" => "",
                    "interfaces" => "",
                    "masquerade" => "no",
                    "ports" => "",
                    "protocols" => "",
                    "rich rules" => "",
                    "services" => "",
                    "sourceports" => "",
                    "sources" => "",
                    "target" => "default"
                  }

=cut

sub get_zone_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name) = @_;
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --info-zone $zone_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0' || grep(/Error:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve info for '$zone_name' zone from $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	
	# vcl-test
	#   target: default
	#   icmp-block-inversion: no
	#   interfaces:
	#   sources:
	#   services:
	#   ports:
	#   protocols:
	#   masquerade: no
	#   forward-ports:
	#   sourceports:
	#   icmp-blocks:
	#   rich rules:

	my $zone_info = {};
	for my $line (@$output) {
		my ($property, $value) = $line =~ /\s*(\S[^:]+)\s*:\s*(.*)/g;
		if (!defined($property)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring line: '$line'") if ($line !~ /^$zone_name/);
			next;
		}
		$zone_info->{$property} = $value;
	}
	
	notify($ERRORS{'OK'}, 0, "retrieved info for '$zone_name' zone on $computer_name:\n" . format_data($zone_info));
	return $zone_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_zone_target

 Parameters  : $zone_name, $target
 Returns     : boolean
 Description : Sets the target for a firewalld zone.

=cut

sub set_zone_target {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $target) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($target)) {
		notify($ERRORS{'WARNING'}, 0, "target argument was not supplied");
		return;
	}
	elsif ($target !~ /^(ACCEPT|DROP|REJECT)$/i) {
		notify($ERRORS{'WARNING'}, 0, "target argument is not valid: $target, it must be 'ACCEPT', 'DROP', or 'REJECT'");
		return;
	}
	$target = uc($target);
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# --permanent [--zone=zone] --set-target=target
	#           Set the target of a permanent zone.  target is one of: default, ACCEPT, DROP, REJECT
	my $command = "firewall-cmd --permanent --zone=$zone_name --set-target=$target";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to set target of '$zone_name' zone to '$target' on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to set target of '$zone_name' zone to '$target' on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "set target of '$zone_name' zone to '$target' on $computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_source

 Parameters  : $zone_name, $source
 Returns     : boolean
 Description : 

=cut

sub add_source {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $source) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($source)) {
		notify($ERRORS{'WARNING'}, 0, "source argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --add-source=source[/mask]|MAC|ipset:ipset
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --add-source=$source";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add '$source' source to '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add source to '$zone_name' zone on $computer_name: $source, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/ALREADY_ENABLED/, @$output)) {
		# Warning: ALREADY_ENABLED: 10.1.2.3
		notify($ERRORS{'OK'}, 0, "source was previously added to '$zone_name' zone on $computer_name: $source");
	}
	else {
		notify($ERRORS{'OK'}, 0, "added source to '$zone_name' zone on $computer_name: $source");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_source

 Parameters  : $zone_name, $source
 Returns     : boolean
 Description : 

=cut

sub remove_source {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $source) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($source)) {
		notify($ERRORS{'WARNING'}, 0, "source argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] --remove-source=source[/mask]|MAC|ipset:ipset
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --remove-source=$source";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to remove '$source' source from '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to remove source from '$zone_name' zone on $computer_name: $source, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/NOT_ENABLED/, @$output)) {
		notify($ERRORS{'OK'}, 0, "source is not specified in '$zone_name' zone on $computer_name: $source");
	}
	else {
		notify($ERRORS{'OK'}, 0, "removed source from '$zone_name' zone on $computer_name: $source");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_interface

 Parameters  : $zone_name, $interface_name
 Returns     : boolean
 Description : 

=cut

sub add_interface {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $interface_name) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($interface_name)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --add-interface=interface
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --add-interface=$interface_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add '$interface_name' interface to '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add interface to '$zone_name' zone on $computer_name: $interface_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/already bound/, @$output)) {
		# The interface is under control of NetworkManager and already bound to 'public'
		notify($ERRORS{'OK'}, 0, "interface is already bound to '$zone_name' zone on $computer_name: $interface_name");
	}
	else {
		notify($ERRORS{'OK'}, 0, "bound interface to '$zone_name' zone on $computer_name: $interface_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_port

 Parameters  : $zone_name, $port, $protocol (optional)
 Returns     : boolean
 Description : 

=cut

sub add_port {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $port, $protocol) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	$protocol = 'tcp' unless $protocol;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --add-port=portid[-portid]/protocol [--timeout=timeval]
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --add-port=$port/$protocol";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add port $port/$protocol to '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add port $port/$protocol to '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/ALREADY_ENABLED/, @$output)) {
		notify($ERRORS{'OK'}, 0, "port $port/$protocol was previously added to '$zone_name' zone on $computer_name");
	}
	else {
		notify($ERRORS{'OK'}, 0, "added port $port/$protocol to '$zone_name' zone on $computer_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_port

 Parameters  : $zone_name, $port, $protocol (optional)
 Returns     : boolean
 Description : 

=cut

sub remove_port {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $port, $protocol) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	$protocol = 'tcp' unless $protocol;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --remove-port=portid[-portid]/protocol
	my $command = "firewall-cmd --permanent --zone=$zone_name --remove-port=$port/$protocol";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to remove port $port/$protocol from '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;

	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to remove port $port/$protocol from '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/NOT_ENABLED/, @$output)) {
		notify($ERRORS{'OK'}, 0, "port $port/$protocol has not been added from '$zone_name' zone on $computer_name");
	}
	else {
		notify($ERRORS{'OK'}, 0, "removed port $port/$protocol from '$zone_name' zone on $computer_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_service

 Parameters  : $zone_name, $service
 Returns     : boolean
 Description : 

=cut

sub add_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $service) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not supplied");
		return;
	}
	elsif (!defined($service)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	$service = 'tcp' unless $service;
	
	my $computer_name = $self->data->get_computer_hostname();
	
	# [--permanent] [--zone=zone] --add-service=service [--timeout=timeval]
	my $command = "firewall-cmd --permanent --zone=$zone_name --add-service=$service";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add $service service to '$zone_name' zone on $computer_name: $command");
		return;
	}
	
	# Remove color controls
	(my $output_string = join("\n", @$output)) =~ s/\e\[\d+m//g;
	
	if ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to add $service service to '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n$output_string");
		return;
	}
	elsif (grep(/ALREADY_ENABLED/, @$output)) {
		notify($ERRORS{'OK'}, 0, "$service service was previously added to '$zone_name' zone on $computer_name");
	}
	else {
		notify($ERRORS{'OK'}, 0, "added $service service to '$zone_name' zone on $computer_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
