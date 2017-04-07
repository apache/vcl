#!/usr/bin/perl -w
###############################################################################
# $Id:  $
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

##############################################################################
package VCL::Module::OS::Linux::firewall::firewalld;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux::firewall::iptables);

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

#/////////////////////////////////////////////////////////////////////////////

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
	
#### Remove ssh from public zone
###return unless $self->remove_service('public', 'ssh');
	
	$self->save_configuration();
	
	notify($ERRORS{'DEBUG'}, 0, "completed firewalld post-load configuration on $computer_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_service

 Parameters  : $zone_name, $service_name
 Returns     : boolean
 Description : Removes a service from a firewalld zone.

=cut

sub remove_service {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($zone_name, $service_name) = @_;
	if (!defined($zone_name)) {
		notify($ERRORS{'WARNING'}, 0, "zone name argument was not specified");
		return;
	}
	elsif (!defined($service_name)) {
		notify($ERRORS{'WARNING'}, 0, "service name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	
	my $command = "firewall-cmd --permanent --zone=$zone_name --remove-service=$service_name";
	my ($exit_status, $output) = $self->os->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to remove '$service_name' service from '$zone_name' zone on $computer_name: $command");
		return;
	}
	elsif (grep(/NOT_ENABLED/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not enabled in '$zone_name' zone on $computer_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to remove '$service_name' service from '$zone_name' zone on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "removed '$service_name' service from '$zone_name' zone on $computer_name, output:\n" . join("\n", @$output));
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	
	return $self->clean_direct_xml($table_name . '.*jump\s+' . $chain_name);
	#$self->delete_chain_references($table_name, $chain_name);
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
