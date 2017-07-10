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

###############################################################################
package VCL::Module::OS::Linux::ManagementNode;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

use Crypt::CBC;
use Crypt::OpenSSL::RSA;
use Crypt::Rijndael;
use English;
use File::Basename;
use MIME::Base64;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $MN_STAGE_SCRIPTS_DIRECTORY

 Data type   : String
 Description : Location on the management node where scripts reside which are
               executed on the management node at various stages of a
               reservation.
               
               Example:
               /usr/local/vcl/tools/ManagementNode/Scripts

=cut

our $MN_STAGE_SCRIPTS_DIRECTORY = "$TOOLS/ManagementNode/Scripts";

=head2 $MN_PRIVATE_ENCRYPTION_KEY_FILE_PATH

 Data type   : String
 Description : /root/.vcl/<FQDN>.key

=cut

our $MN_PRIVATE_ENCRYPTION_KEY_FILE_PATH = "/root/.vcl/$FQDN.key";

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional), $timeout_seconds (optional)
 Returns     : array
 Description :

=cut

sub execute {
	my ($argument) = @_;
	my ($command, $display_output, $timeout_seconds);
	
	# Check if this subroutine was called as an object method
	if (ref($argument) && ref($argument) =~ /VCL::Module/) {
		# Subroutine was called as an object method ($self->execute)
		my $self = shift;
		($argument) = @_;
	}
	
	# Check the argument type
	if (ref($argument)) {
		if (ref($argument) eq 'HASH') {
			$command = $argument->{command};
			$display_output = $argument->{display_output};
			$timeout_seconds = $argument->{timeout_seconds};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "invalid argument reference type passed: " . ref($argument) . ", if a reference is passed as the argument it may only be a hash or VCL::Module reference");
			return;
		}
	}
	else {
		# Argument is not a reference, get the remaining arguments
		($command, $display_output, $timeout_seconds) = @_;
	}
	
	# Run the command
	my ($exit_status, $output) = run_command($command, 1, $timeout_seconds);
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 create_text_file

 Parameters  : $file_path, $file_contents_string, $append (optional)
 Returns     : boolean
 Description : Creates a text file on the management node.

=cut

sub create_text_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $file_contents_string, $append) = @_;
	if (!defined($file_path)) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	elsif (!defined($file_contents_string)) {
		notify($ERRORS{'WARNING'}, 0, "file contents argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to create the parent directory if it does not exist
	my $parent_directory_path = parent_directory_path($file_path);
	if (!$self->file_exists($parent_directory_path)) {
		$self->create_directory($parent_directory_path);
	}
	
	
	my $mode;
	my $mode_string;
	if ($append) {
		$mode = '>>';
		$mode_string = 'append';
	}
	else {
		$mode = '>';
		$mode_string = 'create';
	}
	
	if (!open FILE, $mode, $file_path) {
		notify($ERRORS{'WARNING'}, 0, "failed to $mode_string text file on $computer_node_name, file path could not be opened: $file_path");
		return;
	}
	
	if (!print FILE $file_contents_string) {
		close FILE;
		notify($ERRORS{'WARNING'}, 0, "failed to $mode_string text file on $computer_node_name: $file_path, contents could not be written to the file");
		return;
	}
	
	close FILE;
	notify($ERRORS{'DEBUG'}, 0, $mode_string . ($append ? 'ed' : 'd') . " text file on $computer_node_name: $file_path");
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_file_contents

 Parameters  : $file_path, $display_warnings (optional)
 Returns     : array or string
 Description : Retrieves the contents of a file on the management node.

=cut

sub get_file_contents {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $display_warnings) = @_;
	if (!defined($file_path)) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	$display_warnings = 1 unless defined($display_warnings);
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	if (!open FILE, '<', $file_path) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of file on $computer_node_name, file could not be opened: $file_path") if $display_warnings;
		return;
	}
	my @lines = <FILE>;
	close FILE;
	
	my $line_count = scalar(@lines);
	notify($ERRORS{'DEBUG'}, 0, "retrieved contents of file on $computer_node_name: $file_path ($line_count lines)");
	if (wantarray) {		
		map { s/[\r\n]+$//g; } (@lines);
		return @lines;
	}
	else {
		return join('', @lines);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_reservation_info_json_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location where the files resides on the management
               node that contains JSON formatted information about the
               reservation. For Linux computers, the location is:
               /tmp/<reservation ID>.json.

=cut

sub get_management_node_reservation_info_json_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my $reservation_id = $self->data->get_reservation_id();
	return "/tmp/$reservation_id.json";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_management_node_reservation_info_json_file

 Parameters  : none
 Returns     : boolean
 Description : Creates a text file on the the management node containing
               reservation data in JSON format.

=cut

sub create_management_node_reservation_info_json_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $json_file_path = $self->get_management_node_reservation_info_json_file_path();
	
	# IMPORTANT: Use $self->os->data here to retrieve DataStructure info for the computer being loaded
	# If $self->data->get_reservation_info_json_string is used, the computer info will be that of the management node, not the computer being loaded
	my $json_string = $self->os->data->get_reservation_info_json_string() || return;
	
	return $self->create_text_file($json_file_path, $json_string);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_management_node_reservation_info_json_file

 Parameters  : none
 Returns     : boolean
 Description : Deletes the text file on the management node containing
               reservation data in JSON format.

=cut

sub delete_management_node_reservation_info_json_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $json_file_path = $self->get_management_node_reservation_info_json_file_path();
	return $self->delete_file($json_file_path);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_stage_scripts_on_management_node

 Parameters  : $stage
 Returns     : boolean
 Description : Runs scripts on the management node intended for the state
               specified by the argument. This is useful if you need to
               configure something such as a storage unit or firewall device
               specifically for each reservation.
               
               The stage argument may be any of the following:
					* post_capture
					* post_initial_connection
					* post_load
					* post_reservation
					* post_reserve
					* pre_capture
					* pre_reload
               
               The scripts are stored on the management node under:
               /usr/local/vcl/tools/ManagementNode/Scripts
               
               No scripts exist by default. When the vcld process reaches the
               stage specified by the argument, it will check the subdirectory
               with a name that matches the stage name. For example:
               /usr/local/vcl/tools/ManagementNode/Scripts/post_capture
               
               It will attempt to execute any files under this directory.
               
               Prior to executing the scripts, a JSON file is created under /tmp
               with information regarding the reservation. The actual file path
               will be:
               /tmp/<reservation ID>.json
               
               Information about the reservation can be retrieved within the
               script by simply using grep or using something to parse JSON such
               as jsawk. Sample script:
               
               JSON_FILE="$1"
               echo "JSON file: ${JSON_FILE}"
               PRIVATE_IP=`cat ${JSON_FILE} | jsawk 'return this.computer.privateIPaddress'`
               echo "computer private IP: ${PRIVATE_IP}"

=cut

sub run_stage_scripts_on_management_node {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the stage argument
	my $stage = shift;
	if (!$stage) {
		notify($ERRORS{'WARNING'}, 0, "stage argument was not supplied");
		return;
	}
	
	my $management_node_stages = {
		'post_capture' => 1,
		'post_initial_connection' => 1,
		'post_load' => 1,
		'post_reservation' => 1,
		'post_reserve' => 1,
		'pre_capture' => 1,
		'pre_reload' => 1,
	};
	
	if (!defined($management_node_stages->{$stage})) {
		notify($ERRORS{'WARNING'}, 0, "invalid stage argument was supplied: $stage");
		return;
	}
	elsif (!$management_node_stages->{$stage}) {
		# Note: Not currently used, could someday if a particular stage is defined for computer scripts but not MN scripts
		notify($ERRORS{'DEBUG'}, 0, "'$stage' stage scripts are not supported to be run on a managment node");
		return 1;
	}
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	my $reservation_id = $self->data->get_reservation_id();
	my $management_node_short_name = $self->data->get_management_node_short_name();
	
	my $scripts_directory_path = "$MN_STAGE_SCRIPTS_DIRECTORY/$stage";
	my @script_file_paths = $self->find_files($scripts_directory_path, '*');
	if (!@script_file_paths) {
		notify($ERRORS{'DEBUG'}, 0, "no files exist in directory: $scripts_directory_path");
		return 1;
	}
	
	# Sort the files so they can be executed in a known order
	@script_file_paths = sort_by_file_name(@script_file_paths);
	
	my $script_count = scalar(@script_file_paths);
	notify($ERRORS{'DEBUG'}, 0, "found $script_count files under $scripts_directory_path:\n" . join("\n", @script_file_paths));
	
	# Create a JSON file on the management node containing reservation info
	$self->create_management_node_reservation_info_json_file();
	
	my $mn_json_file_path = $self->get_management_node_reservation_info_json_file_path();
	
	# Execute the scripts
	for my $script_file_path (@script_file_paths) {
		# Ignore certain intermediate directory paths
		if ($script_file_path =~ /\/(\.svn|\.git)\//i) {
			my $matching_section = $1;
			notify($ERRORS{'DEBUG'}, 0, "ignoring file on management node because it resides under intermediate directory '$matching_section': $script_file_path");
			next;
		}
		
		my $command = "chmod +x $script_file_path && $script_file_path $mn_json_file_path";
		my ($exit_status, $output) = $self->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute script on management node: $command");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "executed script on management node $management_node_short_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		}
	}
	
	#$self->delete_management_node_reservation_info_json_file();
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_private_key_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location on the management node where the private key
               resides that is used to decrypt secrets: /root/.vcl/<FQDN>.key

=cut

sub get_private_key_file_path {
	return $MN_PRIVATE_ENCRYPTION_KEY_FILE_PATH;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_private_key_object_from_file

 Parameters  : none
 Returns     : string
 Description : Retrieves the private key string from the file on the management
               node and creates a Crypt::OpenSSL::RSA object based on it.

=cut

sub _get_private_key_object_from_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{private_key_object_from_file} if defined($self->{private_key_object_from_file});
	
	my $management_node_short_name = $self->data->get_management_node_short_name() || return;
	
	my $private_key_file_path = $self->get_private_key_file_path();
	if (!$self->file_exists($private_key_file_path)) {
		notify($ERRORS{'OK'}, 0, "unable to retrieve private key from file on $management_node_short_name because file does NOT exist: $private_key_file_path");
		return;
	}
	
	my $private_key_file_string = $self->get_file_contents($private_key_file_path);
	if (!$private_key_file_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve private key from file on $management_node_short_name: $private_key_file_path");
		return;
	}
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Create an RSA object based on the existing private key contained in the file
	my $rsa_private;
	eval {
		$rsa_private = Crypt::OpenSSL::RSA->new_private_key($private_key_file_string);
	};
	if ($EVAL_ERROR || !$rsa_private) {
		notify($ERRORS{'WARNING'}, 0, "failed to create Crypt::OpenSSL::RSA object from $private_key_file_path on $management_node_short_name" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}
	
	$self->{private_key_object_from_file} = $rsa_private;
	return $rsa_private;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 extract_public_key_from_private_key_file

 Parameters  : none
 Returns     : string
 Description : Retrieves the private key from the file on the management node
               and extracts the public key from the private key. The public key
               string is returned.

=cut

sub extract_public_key_from_private_key_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $rsa_private = $self->_get_private_key_object_from_file() || return;
	
	my $management_node_short_name = $self->data->get_management_node_short_name();
	my $private_key_file_path = $self->get_private_key_file_path();
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Retrieve the public key string from the RSA object
	my $public_key_string;
	eval {
		$public_key_string = $rsa_private->get_public_key_x509_string();
	};
	if ($EVAL_ERROR || !$public_key_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to extract public key from private key file $private_key_file_path on $management_node_short_name, failed to retrieve public key from private key contained in the file" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}
	
	return $public_key_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 generate_private_key_file

 Parameters  : none
 Returns     : boolean
 Description : Creates a 4096 bit RSA private key file on the management node
               at /root/.vcl/<FQDN>.key.

=cut

sub generate_private_key_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $arguments_hash_ref = shift;
	if (defined($arguments_hash_ref) && !ref($arguments_hash_ref) || ref($arguments_hash_ref) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "argument was supplied but is not a hash reference:\n" . format_data($arguments_hash_ref));
		return;
	}
	
	my $private_key_file_path = $self->get_private_key_file_path();
	my $bits = 4096;
	
	# If provided and true, existing private key file will be deleted if it exists
	my $force = $arguments_hash_ref->{force};
	
	my $management_node_id = $self->data->get_management_node_id() || return;
	my $management_node_short_name = $self->data->get_management_node_short_name() || return;
	my $reservation_id = $self->data->get_reservation_id();
	
	notify($ERRORS{'DEBUG'}, 0, "*** attempting to generate a new private key file on $management_node_short_name: $private_key_file_path ***");
	
	# Make sure the private key file does not already exist
	if ($self->file_exists($private_key_file_path)) {
		if ($force) {
			(my $timestamp = makedatestring()) =~ s/\s+/_/g;
			my $backup_private_key_file_path = $private_key_file_path . "_$timestamp";
			if ($self->copy_file($private_key_file_path, $backup_private_key_file_path)) {
				notify($ERRORS{'OK'}, 0, "force argument was specified, existing private key file will be overwritten, created backup copy: $private_key_file_path --> $backup_private_key_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to generate encryption keys, force argument was specified, existing private key file exists but failed to create backup copy: $private_key_file_path --> $backup_private_key_file_path");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to generate encryption keys, private key file already exists: $private_key_file_path");
			return;
		}
	}
	
	# Delete cached RSA object
	if ($self->{private_key_object_from_file}) {
		notify($ERRORS{'DEBUG'}, 0, "deleting cached RSA private key object");
		delete $self->{private_key_object_from_file};
	}
	
	# Delete all existing cryptsecret entries for the management node
	# The website's API won't delete any that may have been created with an earlier key
	delete_management_node_cryptsecret($management_node_id);
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};
	
	# Create a new RSA object containing a private/public key pair
	# Create an RSA object based on the existing private key contained in the file
	my $rsa_generate;
	eval {
		$rsa_generate = Crypt::OpenSSL::RSA->generate_key($bits);
	};
	if ($EVAL_ERROR || !$rsa_generate) {
		notify($ERRORS{'WARNING'}, 0, "failed to create private key file on management node $management_node_short_name: $private_key_file_path, RSA object could not be created" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}

	my $private_key_string;
	eval {
		$private_key_string = $rsa_generate->get_private_key_string();
	};
	if ($EVAL_ERROR || !$private_key_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to create private key file on management node $management_node_short_name: $private_key_file_path, private key string could not be retireved from RSA object" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}
	
	my $public_key_string;
	eval {
		$public_key_string = $rsa_generate->get_public_key_x509_string();
	};
	if ($EVAL_ERROR ||  !$public_key_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to create private key file on management node $management_node_short_name: $private_key_file_path, public key string could not be retireved from RSA object" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}
	
	$self->create_text_file($private_key_file_path, $private_key_string) || return;
	
	# Update cryptkey table with the public key string
	if (!set_management_node_cryptkey_pubkey($management_node_id, $public_key_string)) {
		notify($ERRORS{'WARNING'}, 0, "created private key file on management node $management_node_short_name: $private_key_file_path, failed to update cryptkey table in database, attempting to delete private key file just created: $private_key_file_path");
		$self->delete_file($private_key_file_path);
		return;
	}
	
	# Call the XML-RPC API to create a new cryptsecret entry for this reservation
	call_check_crypt_secrets($reservation_id);
	
	notify($ERRORS{'OK'}, 0, "created private key file on management node $management_node_short_name: $private_key_file_path, updated cryptkey.pubkey value in database");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 decrypt_cryptsecret

 Parameters  : $secret_id, $encrypted_string
 Returns     : string
 Description : Decrypts an encrypted string stored in the database such as
               addomain.password.
               
               The $secret_id argument must match a cryptsecret.secretid value
               in the database. The corresponding cryptsecret.cryptsecret value
               is a base64-encoded string that is encrypted using the management
               node's public key stored in cryptkey.pubkey. The management
               node's private key is used to decrypt it.

=cut

sub decrypt_cryptsecret {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($secret_id, $encrypted_string, $recreate_key) = @_;
	if (!defined($secret_id)) {
		notify($ERRORS{'WARNING'}, 0, "secret ID argument was not supplied");
		return;
	}
	if (!defined($encrypted_string)) {
		notify($ERRORS{'WARNING'}, 0, "encrypted string argument was not supplied");
		return;
	}
	
	my $management_node_id = $self->data->get_management_node_id() || return;
	my $management_node_short_name = $self->data->get_management_node_short_name() || return;
	
	my $private_key_file_path = $self->get_private_key_file_path();
	
	if ($recreate_key) {
		notify($ERRORS{'DEBUG'}, 0, "previous attempt to decrypt cryptsecret failed, attempting to regenerate private key and cryptsecret entries");
		if (!$self->generate_private_key_file({force => 1})) {
			notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, failed to verify private key stored in file on management node is valid and its public key matches the cryptkey.pubkey value in the database");
			return;
		}
	}
	
	# Pass opposite of $recreate_key as $suppress_warning argument
	my $cryptsecret = get_management_node_cryptsecret_value($management_node_id, $secret_id, !$recreate_key);
	if (!$cryptsecret) {
		#notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, failed to retrieve cryptsecret.cryptsecret value for management node ID $management_node_id");
		$recreate_key ? return : return $self->decrypt_cryptsecret($secret_id, $encrypted_string, 1);
	}
	
	# The encrypted string (addomain.password, etc) and cryptsecret.cryptsecret should ALWAYS be base64 encoded
	# They must be decoded to binary before being passed to decrypt functions
	my $encrypted_string_decoded = decode_base64($encrypted_string);
	my $cryptsecret_decoded = decode_base64($cryptsecret);
	
	my $rsa_private = $self->_get_private_key_object_from_file();
	if (!$rsa_private) {
		#notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, failed to create RSA object based on management node's private key");
		$recreate_key ? return : return $self->decrypt_cryptsecret($secret_id, $encrypted_string, 1);
	}
	
	# Override the die handler 
	local $SIG{__DIE__} = sub{};

	my $key;
	eval {
		$key = $rsa_private->decrypt($cryptsecret_decoded);
	};
	if ($EVAL_ERROR || !$key) {
		# Wrong key error:
		# RSA.xs:202: OpenSSL error: oaep decoding error
		notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, failed to decrypt cryptsecret using RSA object based on management node's private key file: $private_key_file_path" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		$recreate_key ? return : return $self->decrypt_cryptsecret($secret_id, $encrypted_string, 1);
	}
	
	my $encrypted_string_length = length($encrypted_string_decoded);
	if ($encrypted_string_length < 32) {
		# This should always be at least 32 bytes
		# If less than 16, the next 2 substr commands may fail with 'substr outside of string' errors
		notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, encrypted string length: $encrypted_string_length bytes, it must be 32 bytes or more:\n$encrypted_string\n\n" . decode_base64($encrypted_string));
		return;
	}
	
	my $iv = substr($encrypted_string_decoded, 0, 16);
	my $ciphered_string = substr($encrypted_string_decoded, 16);
	
	my $cipher;
	eval {
		$cipher = Crypt::CBC->new(
			{
				'key'				=> $key,
				'cipher'			=> 'Crypt::Rijndael',
				'iv'				=> $iv,
				'header'			=> 'none',
				'literal_key'	=> 1,
			}
		);
	};
	if (!$cipher || $EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to decrypt secret ID $secret_id, failed to create Crypt::CBC object" . ($EVAL_ERROR ? ", error:\n" . $EVAL_ERROR : ''));
		return;
	}
	
	my $decrypted_string = $cipher->decrypt($ciphered_string);
	if (defined($decrypted_string)) {
		notify($ERRORS{'OK'}, 0, "decrypted secret ID $secret_id");
		return $decrypted_string;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to decrypt secret ID $secret_id");
		$recreate_key ? return : return $self->decrypt_cryptsecret($secret_id, $encrypted_string, 1);
	}
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
