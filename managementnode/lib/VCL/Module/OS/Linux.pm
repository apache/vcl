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

VCL::Module::OS::Linux.pm - VCL module to support Linux operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Linux operating systems.

=cut

##############################################################################
package VCL::Module::OS::Linux;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::OS);

# Specify the version of this module
our $VERSION = '2.4.2';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use VCL::utils;
use English qw( -no_match_vars );
use Net::Netmask;
use File::Basename;
use File::Temp qw( tempfile mktemp );

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on the management node of the files specific to this OS
               module which are needed to configure the loaded OS on a computer.
               This is normally the directory under 'tools' named after this OS
               module.
               
               Example:
               /usr/local/vcl/tools/Linux

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Linux";

=head2 $NODE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on computer loaded with a VCL image where configuration
               files and scripts reside.

=cut

our $NODE_CONFIGURATION_DIRECTORY = '/root/VCL';

=head2 $CAPTURE_DELETE_FILE_PATHS

 Data type   : Array
 Description : List of files to be deleted during the image capture process.

=cut

our $CAPTURE_DELETE_FILE_PATHS = [
	'/root/.ssh/id_rsa',
	'/root/.ssh/id_rsa.pub',
	'/etc/sysconfig/iptables*old*',
	'/etc/sysconfig/iptables_pre*',
	'/etc/udev/rules.d/70-persistent-net.rules',
	'/var/log/*.0',
	'/var/log/*.gz',
];

=head2 $CAPTURE_CLEAR_FILE_PATHS

 Data type   : Array
 Description : List of files to be cleared during the image capture process.

=cut

our $CAPTURE_CLEAR_FILE_PATHS = [
	'/etc/hostname',
	'/var/log/auth.log*',
	'/var/log/boot.log*',
	'/var/log/lastlog',
	'/var/log/messages',
	'/var/log/secure',
	'/var/log/udev',
	'/var/log/wtmp',
];

#/////////////////////////////////////////////////////////////////////////////

=head2 get_node_configuration_directory

 Parameters  : none
 Returns     : string
 Description : Retrieves the $NODE_CONFIGURATION_DIRECTORY variable value for
               the OS. This is the path on the computer's hard drive where image
               configuration files and scripts are copied.

=cut

sub get_node_configuration_directory {
	return $NODE_CONFIGURATION_DIRECTORY;
}

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_init_modules

 Parameters  : none
 Returns     : Linux init module reference
 Description : Determines the Linux init daemon being used by the computer
               (SysV, systemd, etc.) and creates an object. The default is SysV
               if no other modules in the lib/VCL/Module/OS/Linux/init directory
               match the init daemon on the computer. The init module is mainly
               used to control services on the computer.

=cut

sub get_init_modules {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	return @{$self->{init_modules}} if $self->{init_modules};
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Linux init daemon module initialization");
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Get the absolute path of the init module directory
	my $init_directory_path = "$FindBin::Bin/../lib/VCL/Module/OS/Linux/init";
	notify($ERRORS{'DEBUG'}, 0, "Linux init module directory path: $init_directory_path");
	
	# Get a list of all *.pm files in the init module directory
	my @init_module_paths = $self->mn_os->find_files($init_directory_path, '*.pm');
	
	# Attempt to create an initialize an object for each init module
	my %init_module_hash;
	INIT_MODULE: for my $init_module_path (@init_module_paths) {
		my $init_name = fileparse($init_module_path, qr/\.pm$/i);
		my $init_perl_package = "VCL::Module::OS::Linux::init::$init_name";
		
		# Attempt to load the init module
		notify($ERRORS{'DEBUG'}, 0, "attempting to load $init_name init module: $init_perl_package");
		eval "use $init_perl_package";
		if ($EVAL_ERROR || $@) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to load $init_name init module: $init_perl_package, error: $EVAL_ERROR");
			next INIT_MODULE;
		}
		
		# Attempt to create an init module object
		# The 'new' constructor will automatically call the module's initialize subroutine
		# initialize will check the computer to determine if it contains the corresponding Linux init daemon installed
		# If not installed, the constructor will return false
		my $init;
		eval { $init = ($init_perl_package)->new({
					data_structure => $self->data,
					os => $self,
					mn_os => $self->mn_os,
					init_modules => $self->{init_modules},
		}) };
		if ($init) {
			my @required_commands = eval "@" . $init_perl_package . "::REQUIRED_COMMANDS";
			if ($EVAL_ERROR) {
				notify($ERRORS{'CRITICAL'}, 0, "\@REQUIRED_COMMANDS variable is not defined in the $init_perl_package Linux init daemon module");
				next INIT_MODULE;
			}
			
			for my $command (@required_commands) {
				if (!$self->command_exists($command)) {
					next INIT_MODULE;
				}
			}
			
			# init object successfully created, retrieve the module's $INIT_DAEMON_ORDER variable
			# An OS may have/support multiple Linux init daemons, services may be registered under different init daemons
			# In some cases, need to try multple init modules to control a service
			# This $INIT_DAEMON_ORDER integer determines the order in which the modules are tried
			my $init_daemon_order = eval '$' . $init_perl_package . '::INIT_DAEMON_ORDER';
			if ($EVAL_ERROR) {
				notify($ERRORS{'CRITICAL'}, 0, "\$INIT_DAEMON_ORDER variable is not defined in the $init_perl_package Linux init daemon module");
				next INIT_MODULE;
			}
			elsif ($init_module_hash{$init_daemon_order}) {
				notify($ERRORS{'CRITICAL'}, 0, "multiple Linux init daemon modules are configured to use \$INIT_DAEMON_ORDER=$init_daemon_order: " . ref($init_module_hash{$init_daemon_order}) . ", " . ref($init) . ", the value of this variable must be unique");
				next INIT_MODULE;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "$init_name init object created and initialized to control $computer_node_name, order: $init_daemon_order");
				$init_module_hash{$init_daemon_order} = $init;
			}
		}
		elsif ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$init_perl_package init object could not be created, error:\n$EVAL_ERROR");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$init_name init object could not be initialized to control $computer_node_name");
		}
	}
	
	# Make sure at least 1 init module object was successfully initialized
	if (!%init_module_hash) {
		notify($ERRORS{'WARNING'}, 0, "failed to create Linux init daemon module");
		return;
	}
	
	# Construct an array of init module objects from highest to lowest $INIT_DAEMON_ORDER
	$self->{init_modules} = [];
	my $init_module_order_string;
	for my $init_daemon_order (sort {$a <=> $b} keys %init_module_hash) {
		push @{$self->{init_modules}}, $init_module_hash{$init_daemon_order};
		$init_module_order_string .= "$init_daemon_order: " . ref($init_module_hash{$init_daemon_order}) . "\n";
	}
	notify($ERRORS{'DEBUG'}, 0, "constructed array containing init module objects which may be used to control $computer_node_name:\n$init_module_order_string");
	return @{$self->{init_modules}};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall

 Parameters  : none
 Returns     : Linux firewall module reference
 Description : Determines the Linux firewall module to use and creates an
               object.

=cut

sub firewall {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	return $self->{firewall} if $self->{firewall};
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Linux firewall daemon module initialization");
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Get the absolute path of the init module directory
	my $firewall_directory_path = "$FindBin::Bin/../lib/VCL/Module/OS/Linux/firewall";
	notify($ERRORS{'DEBUG'}, 0, "Linux firewall module directory path: $firewall_directory_path");
	
	# Get a list of all *.pm files in the firewall module directory
	my @firewall_module_paths = $self->mn_os->find_files($firewall_directory_path, '*.pm');
	
	# Attempt to create an initialize an object for each firewall module
	my %firewall_module_hash;
	FIREWALL_MODULE: for my $firewall_module_path (@firewall_module_paths) {
		my $firewall_name = fileparse($firewall_module_path, qr/\.pm$/i);
		my $firewall_perl_package = "VCL::Module::OS::Linux::firewall::$firewall_name";
		
		# Attempt to load the module
		eval "use $firewall_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$firewall_perl_package module could not be loaded, error:\n" . $EVAL_ERROR);
			return;
		}
		notify($ERRORS{'DEBUG'}, 0, "$firewall_perl_package module loaded");
		
		# Attempt to create the object
		my $firewall_object;
		eval {
			$firewall_object = ($firewall_perl_package)->new({
				data_structure => $self->data,
				os => $self,
				mn_os => $self->mn_os,
			})
		};
		
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "failed to create $firewall_perl_package object, error: $EVAL_ERROR");
		}
		elsif (!$firewall_object) {
			notify($ERRORS{'DEBUG'}, 0, "$firewall_perl_package object could not be initialized");
		}
		else {
			my $address = sprintf('%x', $firewall_object);
			notify($ERRORS{'DEBUG'}, 0, "$firewall_perl_package object created, address: $address");
			$self->{firewall} = $firewall_object;
			return $firewall_object;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to create firewall object to control $computer_node_name");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if end_state argument was passed
	if (defined $args->{end_state}) {
		$self->{end_state} = $args->{end_state};
	}
	else {
		$self->{end_state} = 'off';
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Call OS::pre_capture to perform the pre-capture tasks common to all OS's
	if (!$self->SUPER::pre_capture($args)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "beginning Linux-specific image capture preparation tasks");
	
	if (!$self->generate_exclude_list_sample()) {
		notify($ERRORS{'DEBUG'}, 0, "could not create /root/.vclcontrol/vcl_exclude_list.sample");
	}
	
	# Force user off computer
	if (!$self->logoff_user()) {
		notify($ERRORS{'WARNING'}, 0, "unable to log user off $computer_node_name");
	}
	
	# Remove user and clean external ssh file
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "deleted user from $computer_node_name");
	}
	
	# Attempt to set the root password to a known value
	# This is useful for troubleshooting image problems
	$self->set_password("root", $WINDOWS_ROOT_PASSWORD);
	
	if (!$self->configure_default_sshd()) {
		return;
	}
	
	if (!$self->configure_rc_local()) {
		return;
	}
	
	if (!$self->clean_iptables()) {
		return;
	}
	
	if (!$self->clean_known_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to clean known files");
	}
	
	# Configure the private and public interfaces to use DHCP
	if (!$self->enable_dhcp()) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable DHCP on the public and private interfaces");
		return;
	}
	
	# Shut the computer down
	if ($self->{end_state} =~ /off/i) {
		notify($ERRORS{'DEBUG'}, 0, "shutting down $computer_node_name, provisioning module specified end state: $self->{end_state}");
		if (!$self->shutdown()) {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name not shut down, provisioning module specified end state: $self->{end_state}");
	}
	
	notify($ERRORS{'OK'}, 0, "Linux pre-capture steps complete");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name            = $self->data->get_image_name();
	my $computer_node_name    = $self->data->get_computer_node_name();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	
	notify($ERRORS{'OK'}, 0, "beginning Linux post_load tasks, image: $image_name, computer: $computer_node_name");

	# Wait for computer to respond to SSH
	if (!$self->wait_for_response(5, 600, 5)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
		return;
	}
	
	# Make sure the public IP address assigned to the computer matches the database
	if (!$self->update_public_ip_address()) {
		notify($ERRORS{'WARNING'}, 0, "failed to update public IP address");
		return;
	}
	
	# Configure sshd to only listen on the private interface and add ext_sshd service listening on the public interface
	# This locks down sshd so that it isn't listening on the public interface -- ext_sshd isn't started yet
	if (!$self->configure_ext_sshd()) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure ext_sshd on $computer_node_name");
		return 0;
	}
	
	# Remove commands from rc.local added by previous versions of VCL
	$self->configure_rc_local();
	
	# Kickstart installations likely won't have currentimage.txt, generate it
	if ($image_os_install_type eq "kickstart") {
		notify($ERRORS{'OK'}, 0, "detected kickstart install on $computer_node_name, writing current_image.txt");
		if (!$self->create_currentimage_txt()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt on $computer_node_name");
		}
	}
	
	# Update time and ntpservers
	if (!$self->synchronize_time()) {
		notify($ERRORS{'WARNING'}, 0, "unable to synchroinze date and time on $computer_node_name");
	}
	
	# Change password
	if (!$self->set_password("root")) {
		notify($ERRORS{'OK'}, 0, "failed to edit root password on $computer_node_name");
	}
	
	# Clear ssh idenity keys from /root/.ssh
	if (!$self->clear_private_keys()) {
		notify($ERRORS{'WARNING'}, 0, "failed to clear known identity keys");
	}
	
	# Disable access to TCP/22 from any IP address
	# This causes grant_management_node_access to be called which allows access from any of the management node's IP addresses
	$self->disable_firewall_port('tcp', 22);
	
	# Attempt to generate ifcfg-eth* files and ifup any interfaces which the file does not exist
	$self->activate_interfaces();
	
	# Update computer hostname if imagemeta.sethostname is not set to 0
	my $set_hostname = $self->data->get_imagemeta_sethostname(0);
	if (defined($set_hostname) && $set_hostname =~ /0/) {
		notify($ERRORS{'DEBUG'}, 0, "not setting computer hostname, imagemeta.sethostname = $set_hostname");
	}
	else {
		$self->update_public_hostname();
	}
	
	# Run custom post_load scripts residing on the management node
	$self->run_management_node_tools_scripts('post_load');
	
	# Run the vcl_post_load script if it exists in the image
	my @post_load_script_paths = ('/usr/local/vcl/vcl_post_load', '/etc/init.d/vcl_post_load');	

	foreach my $script_path (@post_load_script_paths) {
		notify($ERRORS{'DEBUG'}, 0, "script_path $script_path");
		if ($self->file_exists($script_path)) {
			my $result = $self->run_script($script_path, '1', '300', '1');
			if (!defined($result)) {
				notify($ERRORS{'WARNING'}, 0, "error occurred running $script_path");
			}
			elsif ($result == 0) {
				notify($ERRORS{'DEBUG'}, 0, "$script_path does not exist in image: $image_name");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "ran $script_path");
			}
		}
	}
	
	# Add a line to currentimage.txt indicating post_load has run
	$self->set_vcld_post_load_status();
	
	return 1;
} ## end sub post_load

#/////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub post_reserve {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $image_name = $self->data->get_image_name();
	my $computer_short_name = $self->data->get_computer_short_name();
	my @post_reserve_script_paths = ('/usr/local/vcl/vcl_post_reserve', '/etc/init.d/vcl_post_reserve');
	
	notify($ERRORS{'OK'}, 0, "initiating Linux post_reserve: $image_name on $computer_short_name");
	
	# Run custom post_reserve scripts residing on the management node
	$self->run_management_node_tools_scripts('post_reserve');

	# User supplied data
	#check if variable is set
	#get variable from variable table related to server reservation id ‘userdata|<reservation id>’
	# write contents to local temp file /tmp/resrvationid_post_reserve_userdata
	# scp tmpfile to ‘/root/.vclcontrol/post_reserve_userdata’
	# assumes the image has the call in vcl_post_reserve to import/read the user data file
	
	my $reservation_id = $self->data->get_reservation_id();
	my $variable_name = "userdata|$reservation_id"; 
	my $variable_data;
	my $target_location = "/root/.vclcontrol/post_reserve_userdata";

	if ($self->data->is_variable_set($variable_name)) {
		$variable_data = $self->data->get_variable($variable_name);
		
		#write to local temp file
		my $tmpfile = "/tmp/$reservation_id" ."_post_reserve_userdata";
		if (open(TMP, ">$tmpfile")) {
			print TMP $variable_data;
			close(TMP);

			if ($self->copy_file_to($tmpfile, $target_location)) {
				notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $target_location on $computer_short_name");	
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to open $tmpfile for writing userdata");
		}
		#Clean variable from variable table
		if (delete_variable($variable_name)) {
			notify($ERRORS{'DEBUG'}, 0, "deleted variable_name $variable_name from variable table");
		}
	}
	
	# Check if script exists
	foreach my $script_path (@post_reserve_script_paths) {
			notify($ERRORS{'DEBUG'}, 0, "script_path $script_path");
		if ($self->file_exists($script_path)) {
			# Run the vcl_post_reserve script if it exists in the image
			my $result = $self->run_script($script_path, '1', '300', '1');
			if (!defined($result)) {
				notify($ERRORS{'WARNING'}, 0, "error occurred running $script_path");
			}
			elsif ($result == 0) {
				notify($ERRORS{'DEBUG'}, 0, "$script_path does not exist in image: $image_name");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "ran $script_path");
			}
		}
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 post_reservation

 Parameters  : none
 Returns     : boolean
 Description : Checks for and runs vcl_post_reservation script at the end of a
               reservation.

=cut

sub post_reservation {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Run custom post_reservation scripts residing on the management node
	$self->run_management_node_tools_scripts('post_reservation');
	
	my $script_path = '/usr/local/vcl/vcl_post_reservation';
	
	# Check if script exists
	if (!$self->file_exists($script_path)) {
		notify($ERRORS{'DEBUG'}, 0, "script does NOT exist: $script_path");
		return 1;
	}
	
	# Run the vcl_post_reserve script if it exists in the image
	my $result = $self->run_script($script_path, '1', '300', '1');
	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred executing $script_path");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "executed $script_path");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_public_hostname

 Parameters  : none
 Returns     : boolean
 Description : Retrieves the public IP address being used on the Linux computer.
               Determines the hostname the IP address resolves to. Sets the
               hostname on the Linux computer.

=cut

sub update_public_hostname {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $public_hostname = shift;
	if (!$public_hostname) {
		# Get the IP address of the public adapter
		my $public_ip_address = $self->get_public_ip_address();
		if (!$public_ip_address) {
			notify($ERRORS{'WARNING'}, 0, "hostname cannot be set, unable to determine public IP address");
			return;
		}
		notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address of $computer_node_name: $public_ip_address");
		
		# Get the hostname for the public IP address
		$public_hostname = ip_address_to_hostname($public_ip_address) || $computer_node_name;
	}
	
	my $error_occurred = 0;
	
	# Check if hostname file exists and update if necessary
	my $hostname_file_path = '/etc/hostname';
	if ($self->file_exists($hostname_file_path)) {
		if ($self->create_text_file($hostname_file_path, $public_hostname)) {
			notify($ERRORS{'DEBUG'}, 0, "updated $hostname_file_path on $computer_node_name with hostname '$public_hostname'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update $hostname_file_path on $computer_node_name with '$public_hostname'");
			$error_occurred = 1;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$hostname_file_path not updated on $computer_node_name because the file does not exist");
	}
	
	
	# Check if network file exists and update if necessary
	my $network_file_path = '/etc/sysconfig/network';
	if ($self->file_exists($network_file_path)) {
		my $sed_command = "sed -i -e \"/^HOSTNAME=/d\" $network_file_path; echo \"HOSTNAME=$public_hostname\" >> $network_file_path";
		my ($sed_exit_status, $sed_output) = $self->execute($sed_command);
		if (!defined($sed_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to update hostname in $network_file_path on $computer_node_name");
			return;
		}
		elsif ($sed_exit_status != 0) {
			notify($ERRORS{'WARNING'}, 0, "failed to update hostname in $network_file_path on $computer_node_name, exit status: $sed_exit_status, output:\n" . join("\n", @$sed_output));
			$error_occurred = 1;
		}
		else {
			notify($ERRORS{'OK'}, 0, "updated hostname in $network_file_path on $computer_node_name to '$public_hostname'");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$network_file_path not updated on $computer_node_name because the file does not exist");
	}
	
	# Check if hostnamectl exists, this is provided by systemd on CentOS/RHEL 7+
	if ($self->command_exists('hostnamectl')) {
		my $hostnamectl_command = "hostnamectl set-hostname $public_hostname";
		my ($hostnamectl_exit_status, $hostnamectl_output) = $self->execute($hostnamectl_command);
		if (!defined($hostnamectl_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to set hostname using hostnamectl command on $computer_node_name to $public_hostname");
			return;
		}
		elsif ($hostnamectl_exit_status != 0) {
			notify($ERRORS{'WARNING'}, 0, "failed to set hostname using hostnamectl command on $computer_node_name to $public_hostname, exit status: $hostnamectl_exit_status, command: '$hostnamectl_command', output:\n" . join("\n", @$hostnamectl_output));
			$error_occurred = 1;
		}
		else {
			notify($ERRORS{'OK'}, 0, "set hostname using hostnamectl command on $computer_node_name to $public_hostname");
		}
	}
	else {
		my $hostname_command = "hostname $public_hostname";
		my ($hostname_exit_status, $hostname_output) = $self->execute($hostname_command);
		if (!defined($hostname_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to set hostname using hostname command on $computer_node_name to $public_hostname");
			return;
		}
		elsif ($hostname_exit_status != 0) {
			notify($ERRORS{'WARNING'}, 0, "failed to set hostname using hostname command on $computer_node_name to $public_hostname, exit status: $hostname_exit_status, command: '$hostname_command', output:\n" . join("\n", @$hostname_output));
			$error_occurred = 1;
		}
		else {
			notify($ERRORS{'OK'}, 0, "set hostname using hostname command on $computer_node_name to $public_hostname");
		}
	}
	
	return !$error_occurred;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 clear_private_keys

 Parameters  :
 Returns     :
 Description :

=cut

sub clear_private_keys {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "perparing to clear known identity keys");
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Clear ssh idenity keys from /root/.ssh
	my $clear_private_keys = "/bin/rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub";
	if ($self->execute($clear_private_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "cleared any id_rsa keys from /root/.ssh");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to clear any id_rsa keys from /root/.ssh");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_static_public_address

 Parameters  : none
 Returns     : boolean
 Description : Configures the public interface with a static IP address.

=cut

sub set_static_public_address {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name           = $self->data->get_computer_short_name();
	my $server_request_id       = $self->data->get_server_request_id();
	my $server_request_fixed_ip = $self->data->get_server_request_fixed_ip();
	
	# Make sure public IP configuration is static or this is a server request
	
	my $ip_configuration = $self->data->get_management_node_public_ip_configuration();
	if ($ip_configuration !~ /static/i) {
		if (!$server_request_fixed_ip) {
			notify($ERRORS{'WARNING'}, 0, "static public address can only be set if IP configuration is static or is a server request, current value: $ip_configuration \nserver_request_fixed_ip=$server_request_fixed_ip");
			return;
		}
	}
	
	# Get the IP configuration
	my $interface_name  = $self->get_public_interface_name();
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address, public interface name could not be determined");
		return;
	}
	
	my $computer_public_ip_address  = $self->data->get_computer_public_ip_address()             || '<undefined>';
	my $subnet_mask                 = $self->data->get_management_node_public_subnet_mask()     || '<undefined>';
	my $default_gateway             = $self->data->get_management_node_public_default_gateway() || '<undefined>';
	my @dns_servers                 = $self->data->get_management_node_public_dns_servers();
	
	if ($server_request_fixed_ip) {
		$computer_public_ip_address  = $server_request_fixed_ip;
		$subnet_mask                 = $self->data->get_server_request_netmask();
		$default_gateway             = $self->data->get_server_request_router();
		@dns_servers                 = $self->data->get_server_request_dns_servers();
	}
	
	# Assemble a string containing the static IP configuration
	my $configuration_info_string = <<EOF;
public IP address: $computer_public_ip_address
public subnet mask: $subnet_mask
public default gateway: $default_gateway
public DNS server(s): @dns_servers
EOF
	
	# Get the current public IP address being used by the computer
	# Use cached data if available (0), ignore errors (1)
	my $current_public_ip_address = $self->get_public_ip_address(0, 1);
	if ($current_public_ip_address && $current_public_ip_address eq $computer_public_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "static public IP address does not need to be set, $computer_name is already configured to use $current_public_ip_address");
	}
	else {
		if ($current_public_ip_address) {
			notify($ERRORS{'DEBUG'}, 0, "static public IP address needs to be set, public IP address currently being used by $computer_name $current_public_ip_address does NOT match correct public IP address: $computer_public_ip_address");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "static public IP address needs to be set, unable to determine public IP address currently in use on $computer_name");
		}
		
		# Make sure required info was retrieved
		if ("$computer_public_ip_address $subnet_mask $default_gateway" =~ /undefined/) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve required network configuration for $computer_name:\n$configuration_info_string");
			return;
		}
		else {
			notify($ERRORS{'OK'}, 0, "attempting to set static public IP address on $computer_name:\n$configuration_info_string");
		}
		
		# Try to ping address to make sure it's available
		# FIXME  -- need to add other tests for checking ip_address is or is not available.
		if ((_pingnode($computer_public_ip_address))) {
			notify($ERRORS{'WARNING'}, 0, "ip_address $computer_public_ip_address is pingable, can not assign to $computer_name ");
			return;
		}
		
		# Assemble the ifcfg file path
		my $network_scripts_path = "/etc/sysconfig/network-scripts";
		my $ifcfg_file_path      = "$network_scripts_path/ifcfg-$interface_name";
		notify($ERRORS{'DEBUG'}, 0, "public interface ifcfg file path: $ifcfg_file_path");
		
		# Assemble the ifcfg file contents
		my $ifcfg_contents = <<EOF;
DEVICE=$interface_name
BOOTPROTO=static
IPADDR=$computer_public_ip_address
NETMASK=$subnet_mask
GATEWAY=$default_gateway
STARTMODE=onboot
ONBOOT=yes
EOF
	
		# Echo the contents to the ifcfg file
		my $echo_ifcfg_command = "echo \"$ifcfg_contents\" > $ifcfg_file_path";
		my ($echo_ifcfg_exit_status, $echo_ifcfg_output) = $self->execute($echo_ifcfg_command);
		if (!defined($echo_ifcfg_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to recreate $ifcfg_file_path on $computer_name: '$echo_ifcfg_command'");
			return;
		}
		elsif ($echo_ifcfg_exit_status || grep(/echo:/i, @$echo_ifcfg_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to recreate $ifcfg_file_path on $computer_name, exit status: $echo_ifcfg_exit_status, command: '$echo_ifcfg_command', output:\n" . join("\n", @$echo_ifcfg_output));
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "recreated $ifcfg_file_path on $computer_name:\n$ifcfg_contents");
		}
		
		# Restart the interface
		if (!$self->restart_network_interface($interface_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to restart public interface $interface_name on $computer_name");
			return;
		}
		
		my $ext_sshd_config_file_path = '/etc/ssh/external_sshd_config';
		if ($self->file_exists($ext_sshd_config_file_path)) {
			# Remove existing ListenAddress lines from external_sshd_config
			$self->remove_lines_from_file($ext_sshd_config_file_path, 'ListenAddress') || return;
			
			# Add ListenAddress line to the end of the file
			$self->append_text_file($ext_sshd_config_file_path, "ListenAddress $computer_public_ip_address\n") || return;
		}
	}
	
	# Delete existing default route
	my $route_del_command = "/sbin/route del default";
	my ($route_del_exit_status, $route_del_output) = $self->execute($route_del_command);
	if (!defined($route_del_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to delete the existing default route on $computer_name: '$route_del_command'");
		return;
	}
	elsif (grep(/No such process/i, @$route_del_output)) {
		notify($ERRORS{'DEBUG'}, 0, "existing default route is not set");
	}
	elsif ($route_del_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete existing default route on $computer_name, exit status: $route_del_exit_status, command: '$route_del_command', output:\n" . join("\n", @$route_del_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "deleted existing default route on $computer_name, output:\n" . join("\n", @$route_del_output));
	}
	
	# Set default route
	my $route_add_command = "/sbin/route add default gw $default_gateway metric 0 $interface_name 2>&1 && /sbin/route -n";
	my ($route_add_exit_status, $route_add_output) = $self->execute($route_add_command);
	if (!defined($route_add_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to add default route to $default_gateway on public interface $interface_name on $computer_name: '$route_add_command'");
		return;
	}
	elsif ($route_add_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to add default route to $default_gateway on public interface $interface_name on $computer_name, exit status: $route_add_exit_status, command: '$route_add_command', output:\n" . join("\n", @$route_add_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "added default route to $default_gateway on public interface $interface_name on $computer_name, output:\n" . format_data($route_add_output));
	}
	
	# Update resolv.conf if DNS server address is configured for the management node
	my $resolv_conf_path = "/etc/resolv.conf";
	if (@dns_servers) {
		# Get the resolve.conf contents
		my $cat_resolve_command = "cat $resolv_conf_path";
		my ($cat_resolve_exit_status, $cat_resolve_output) = $self->execute($cat_resolve_command);
		if (!defined($cat_resolve_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve existing $resolv_conf_path contents from $computer_name");
			return;
		}
		elsif ($cat_resolve_exit_status || grep(/^(bash:|cat:)/, @$cat_resolve_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve existing $resolv_conf_path contents from $computer_name, exit status: $cat_resolve_exit_status, command: '$cat_resolve_command', output:\n" . join("\n", @$cat_resolve_output));
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieved existing $resolv_conf_path contents from $computer_name:\n" . join("\n", @$cat_resolve_output));
		}
		
		# Remove lines containing nameserver
		my @resolv_conf_lines = grep(!/nameserver/i, @$cat_resolve_output);
		
		# Add a nameserver line for each configured DNS server
		for my $dns_server_address (@dns_servers) {
			push @resolv_conf_lines, "nameserver $dns_server_address";
		}
		
		# Remove newlines for consistency
		map {chomp $_} @resolv_conf_lines;
		
		# Assemble the lines into an array
		my $resolv_conf_contents = join("\n", @resolv_conf_lines);
		
		# Echo the updated contents to resolv.conf
		my $echo_resolve_command = "echo \"$resolv_conf_contents\" > $resolv_conf_path 2>&1 && cat $resolv_conf_path";
		my ($echo_resolve_exit_status, $echo_resolve_output) = $self->execute($echo_resolve_command);
		if (!defined($echo_resolve_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to update $resolv_conf_path on $computer_name:\n$echo_resolve_command");
			return;
		}
		elsif ($echo_resolve_exit_status) {
			notify($ERRORS{'WARNING'}, 0, "failed to update $resolv_conf_path on $computer_name, exit status: $echo_resolve_exit_status\ncommand:\n$echo_resolve_command\noutput:\n" . join("\n", @$echo_resolve_output));
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "updated $resolv_conf_path on $computer_name:\n" . join("\n", @$echo_resolve_output));
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$resolv_conf_path not updated  on $computer_name because DNS server address is not configured for the management node");
	}
	
	# Delete cached network configuration info - forces next call to get_network_configuration to retrieve changed network info from computer
	delete $self->{network_configuration};
	
	notify($ERRORS{'OK'}, 0, "successfully set static public IP address on $computer_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_network_interface

 Parameters  : $interface_name
 Returns     : boolean
 Description : Calls ifup on the network interface.

=cut

sub start_network_interface {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $interface_name = shift;
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to start network interface, interface name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to start network interface $interface_name on $computer_name");
	
	my $command = "/sbin/ifup $interface_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to start $interface_name interface on $computer_name");
		return;
	}
	elsif (grep(/already configured/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$interface_name interface on $computer_name is already started, output:\n" . join("\n", @$output));
		return 1;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to start $interface_name interface on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "started $interface_name interface on $computer_name, output:\n" . join("\n", @$output));
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_network_interface

 Parameters  : $interface_name
 Returns     : boolean
 Description : Calls ifdown on the network interface.

=cut

sub stop_network_interface {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $interface_name = shift;
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to stop network interface, interface name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to stop network interface $interface_name on $computer_name");
	
	my $command = "/sbin/ifdown $interface_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to stop $interface_name interface on $computer_name");
		return;
	}
	elsif (grep(/not configured/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$interface_name interface on $computer_name is already stopped, output:\n" . join("\n", @$output));
		return 1;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop $interface_name interface on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "stopped $interface_name interface on $computer_name, output:\n" . join("\n", @$output));
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 restart_network_interface

 Parameters  : $interface_name
 Returns     : boolean
 Description : Calls ifdown and then ifup on the network interface.

=cut

sub restart_network_interface {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $interface_name = shift;
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to restart network interface, interface name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to restart network interface $interface_name on $computer_name");
	
	my $command = "/sbin/ifdown $interface_name ; /sbin/ifup $interface_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to restart $interface_name interface on $computer_name");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart $interface_name interface on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "restarted $interface_name interface on $computer_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_default_gateway

 Parameters  : none
 Returns     : boolean
 Description : Deletes the existing default gateway from the routing table.

=cut

sub delete_default_gateway {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command = "/sbin/route del default";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete default gateway on $computer_name: $command");
		return;
	}
	elsif (grep(/No such process/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "default gateway not set on $computer_name");
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete default gateway on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted default gateway on $computer_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_default_gateway

 Parameters  : $default_gateway, $interface_name (optional)
 Returns     : boolean
 Description : Sets the default route. If no interface argument is supplied, the
               public interface is used.

=cut

sub set_default_gateway {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $default_gateway = shift;
	if (!defined($default_gateway)) {
		notify($ERRORS{'WARNING'}, 0, "default gateway argument not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $interface_name = shift;
	if (!defined($interface_name)) {
		$interface_name = $self->get_public_interface_name();
		if (!$interface_name) {
			notify($ERRORS{'WARNING'}, 0, "unable to set static default gateway on $computer_name, interface name argument was not supplied and public interface name could not be determined");
			return;
		}
	}
	
	# Delete existing default gateway or else error will occur: SIOCADDRT: File exists
	$self->delete_default_gateway();

	my $command = "/sbin/route add default gw $default_gateway metric 0 $interface_name";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to set default gateway on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to set default gateway on $computer_name to $default_gateway, interface: $interface_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "set default gateway on $computer_name to $default_gateway, interface: $interface_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 logoff_user

 Parameters  :
 Returns     :
 Description :

=cut

sub logoff_user {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Make sure the user login ID was passed
	my $user_login_id = shift || $self->data->get_user_login_id();
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}
	
	# Make sure the user login ID was passed
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}
	
	my $logoff_cmd = "pkill -KILL -u $user_login_id";
	my ($exit_status, $output) = $self->execute($logoff_cmd);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to log off $user_login_id from $computer_node_name");
		return;
	}
	elsif (grep(/invalid user name/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "user $user_login_id does not exist on $computer_node_name");
		return 1;
	}
	elsif ($exit_status ne '0' && $exit_status ne '1') {
		# pkill will exit with status = 1 if one or more processes were killed, and 1 if no processes matched
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to log off $user_login_id from $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "logged off $user_login_id from $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  : none
 Returns     : boolean
 Description : Performs the steps necessary to reserve a computer for a user.
               A "vcl" user group is added to the.

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "beginning Linux reserve tasks");
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Configure sshd to only listen on the private interface and add ext_sshd service listening on the public interface
	# This needs to be done after update_public_ip_address is called
	if (!$self->configure_ext_sshd()) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure ext_sshd on $computer_node_name");
		return 0;
	}
	
	if (!$self->add_vcl_usergroup()) {
		notify($ERRORS{'WARNING'}, 0, "failed to add vcl user group to $computer_node_name");
	}
	
	notify($ERRORS{'OK'}, 0, "Linux reserve tasks complete");
	
	# Call OS.pm's reserve subroutine
	return unless $self->SUPER::reserve();
} ## end sub reserve

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  : none
 Returns     : boolean
 Description : adds username to external_sshd_config and and starts sshd with
               custom config

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Process the connection methods, allow firewall access from any address
	if ($self->process_connect_methods("", 1)) {
		notify($ERRORS{'DEBUG'}, 0, "granted access to $computer_node_name by processing the connection methods");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $computer_node_name by processing the connection methods");
		return;
	}
} ## end sub grant_access

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_management_node_access

 Parameters  : $overwrite (optional)
 Returns     : boolean
 Description : Grants firewall access to all protocols and ports from all of the
               management node's IP addresses.

=cut

sub grant_management_node_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $overwrite = shift;
	
	my $port = 'any';
	my $protocol = 'tcp';
	
	my $computer_name = $self->data->get_computer_short_name();
	my $management_node_name = $self->data->get_management_node_short_name();
	
	# Allow traffic to any port from any of the managment node's IP addresses
	my @mn_ip_addresses = $self->mn_os->get_ip_addresses();
	if (!@mn_ip_addresses) {
		notify($ERRORS{'WARNING'}, 0, "unable to grant access to $computer_name from management node $management_node_name on " . ($port eq 'any' ? 'any port' : "port $port") . ", failed to retrieve management node IP addresses");
		return;
	}
	
	my $error_occurred = 0;
	
	my $mn_ip_address_1 = shift @mn_ip_addresses;
	# Allow all traffic from the management node
	# Set the overwrite flag, this removes existing rules which allow traffic from any IP address
	if (!$self->enable_firewall_port($protocol, $port, $mn_ip_address_1, $overwrite)) {
		$error_occurred = 1;
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $computer_name from management node $management_node_name IP address: $mn_ip_address_1");
	}
	
	for my $mn_ip_address (@mn_ip_addresses) {
		# Allow all traffic from the management node's other IP addresses
		# Don't specify the overwrite flag
		if (!$self->enable_firewall_port($protocol, $port, $mn_ip_address, 0)) {
			$error_occurred = 1;
			notify($ERRORS{'WARNING'}, 0, "failed to grant access to $computer_name from management node $management_node_name IP address: $mn_ip_address");
		}
	}
	
	return !$error_occurred;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 synchronize_time

 Parameters  : none
 Returns     : boolean
 Description : 

=cut

sub synchronize_time {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $management_node_hostname = $self->data->get_management_node_hostname();
	
	my $variable_name = "timesource|$management_node_hostname";
	my $variable_name_global = "timesource|global";
	
	my $time_source_variable;
	if (is_variable_set($variable_name)) {
		$time_source_variable = get_variable($variable_name);
		notify($ERRORS{'DEBUG'}, 0, "retrieved time source variable '$variable_name': $time_source_variable");
	}
	elsif (is_variable_set($variable_name_global)) {
		$time_source_variable = get_variable($variable_name_global);
		notify($ERRORS{'DEBUG'}, 0, "retrieved global time source variable '$variable_name_global': $time_source_variable");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to sync time, neither '$variable_name' or '$variable_name_global' time source variable is set in database");
		return;
	}
	
	# Split the time source variable into an array
	my @time_sources = split(/[,; ]+/, $time_source_variable);
	
	# Assemble the rdate command
	# Ubuntu doesn't accept multiple servers in a single command
	my $rdate_command;
	for my $time_source (@time_sources) {
		$rdate_command .= "rdate -t 3 -s $time_source || ";
	}
	$rdate_command =~ s/[ \|]+$//g;
	my ($rdate_exit_status, $rdate_output) = $self->execute($rdate_command, 0, 180);
	if (!defined($rdate_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute rdate command to synchronize time on $computer_node_name");
		return;
	}
	elsif (grep(/not found/i, @$rdate_output)) {
		notify($ERRORS{'DEBUG'}, 0, "unable to synchronize time on $computer_node_name, rdate is not installed");
	}
	elsif ($rdate_exit_status > 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to synchronize time on $computer_node_name using rdate, exit status: $rdate_exit_status, command:\n$rdate_command\noutput:\n" . join("\n", @$rdate_output));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "synchronized time on $computer_node_name using rdate");
	}
	
	# Check if the ntpd service exists before attempting to configure it
	if (!$self->service_exists('ntpd')) {
		notify($ERRORS{'DEBUG'}, 0, "skipping ntpd configuration, ntpd service does not exist");
		return 1;
	}
	
	# Update ntpservers file
	my $ntpservers_contents = join("\n", @time_sources);
	if (!$self->create_text_file('/etc/ntp/ntpservers', $ntpservers_contents)) {
		return;
	}
	
	return $self->restart_service('ntpd');
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_password

 Parameters  : $username, $password (optional)
 Returns     : boolean
 Description : Sets password for the account specified by the username argument.
               If no password argument is supplied, a random password is
               generated.

=cut

sub set_password {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $username = shift;
	my $password  = shift;
	
	if (!$username) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not provided");
		return;
	}
	
	if (!$password) {
		$password = getpw(15);
	}
	
	my $command = "echo -e '";
	$command .= qq[$password];
	$command .= "' \| /usr/bin/passwd -f $username --stdin";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to set password for $username");
		return;
	}
	elsif (grep(/(unknown user|warning|error)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to change password for $username to '$password', command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "changed password for $username to '$password', output:\n" . join("\n", @$output));
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     :
 Description :

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Make sure user is not connected
	if ($self->is_connected()) {
		notify($ERRORS{'WARNING'}, 0, "user is connected to $computer_node_name, computer will be reloaded");
		# return false - reclaim will reload
		return 0;
	}
	
	# Call process_connect_methods with the overwrite flag to remove firewall exceptions
	if (!$self->process_connect_methods('127.0.0.1', 1)) {
		notify($ERRORS{'WARNING'}, 0, "failed to sanitize $computer_node_name, failed to overwrite existing connect method firewall exceptions");
		return 0;
	}

	# Delete all user associated with the reservation
	if (!$self->delete_user_accounts()) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete all users from $computer_node_name");
		return 0;
	}
	
	# Make sure ext_sshd is stopped
	if (!$self->stop_external_sshd()) {
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;
} ## end sub sanitize

#/////////////////////////////////////////////////////////////////////////////

=head2 add_vcl_usergroup

 Parameters  : 
 Returns     : 1
 Description : step to add a user group to avoid group errors from useradd cmd 

=cut

sub add_vcl_usergroup {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	if ($self->execute("groupadd vcl")) {
		notify($ERRORS{'DEBUG'}, 0, "successfully added the vcl user group to $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_connected

 Parameters  : none
 Returns     : boolean, undefined if error occurred
 Description : Checks if a connection on port 22 is established to the
               computer's public IP address.

=cut

sub is_connected {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();
	if (!$computer_public_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if connection exists to $computer_node_name, public IP address could not be determined");
		return;
	}

	my $command = "netstat -an | grep ESTABLISHED";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_node_name: $command");
		return;
	}
	
	if (grep(/(Warning|Connection refused)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if connection exists to $computer_public_ip_address on $computer_node_name, output:\n" . join("\n", @$output));
		return;
	}
	elsif (my ($line) = grep(/tcp\s+([0-9]*)\s+([0-9]*)\s($computer_public_ip_address:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "connection exists to $computer_public_ip_address on $computer_node_name:\n$line");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "connection does not exist to $computer_public_ip_address on $computer_node_name");
		return 0;
	}
} ## end sub is_connected

#/////////////////////////////////////////////////////////////////////////////

=head2 run_script

 Parameters  : script path
 Returns     : boolean
 Description : Checks if script exists on the Linux node and attempts to run it.

=cut

sub run_script {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the script path argument
	my $script_path = shift;
	if (!$script_path) {
		notify($ERRORS{'WARNING'}, 0, "script path argument was not specified");
		return;
	}
	my $display_output  = shift || 0;
	my $timeout_seconds = shift || 60;
	my $max_attempts    = shift || 3;
	
	# Check if script exists
	if ($self->file_exists($script_path)) {
		notify($ERRORS{'DEBUG'}, 0, "script exists: $script_path");
	}
	else {
		notify($ERRORS{'OK'}, 0, "script does NOT exist: $script_path");
		return 0;
	}
	
	# Determine the script name
	my ($script_name) = $script_path =~ /\/([^\/]+)$/;
	notify($ERRORS{'DEBUG'}, 0, "script name: $script_name");
	
	# Get the node configuration directory, make sure it exists, create if necessary
	my $node_log_directory = $self->get_node_configuration_directory() . '/Logs';
	if (!$self->create_directory($node_log_directory)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create node log file directory: $node_log_directory");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Assemble the log file path
	my $log_file_path = $node_log_directory . "/$script_name.log";
	notify($ERRORS{'DEBUG'}, 0, "script log file path: $log_file_path");
	
	# Assemble the command
	my $command = "chmod +rx \"$script_path\" && \"$script_path\" >> \"$log_file_path\" 2>&1";
	
	# Execute the command
	my ($exit_status, $output) = $self->execute($command, $display_output, $timeout_seconds, $max_attempts);
	if (defined($exit_status) && $exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "executed $script_path, exit status: $exit_status");
	}
	elsif (defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "$script_path returned a non-zero exit status: $exit_status");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to execute $script_path");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 file_exists

 Parameters  : $file_path, $display_output (optional)
 Returns     : boolean
 Description : Checks if a file or directory exists on the Linux computer.

=cut

sub file_exists {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Get the path from the subroutine arguments and make sure it was passed
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return 0;
	}
	
	my $display_output = shift;
	if (!defined($display_output)) {
		$display_output = 1;
	}
	
	# Remove any quotes from the beginning and end of the path
	$file_path = normalize_file_path($file_path);
	
	# Escape all spaces in the path
	my $escaped_path = escape_file_path($file_path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Check if the file or directory exists
	# Do not enclose the path in quotes or else wildcards won't work
	my $command = "stat $escaped_path";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to run command to determine if file or directory exists on $computer_short_name:\npath: '$file_path'\ncommand: '$command'");
		return 0;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "file or directory does not exist on $computer_short_name: '$file_path'") if $display_output;
		return 0;
	}
	elsif (grep(/stat: /i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to determine if file or directory exists on $computer_short_name:\npath: '$file_path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return 0;
	}
	
	# Count the lines beginning with "Size:" and ending with "file", "directory", or "link" to determine how many files and/or directories were found
	my $files_found       = grep(/^\s*Size:.*file$/i,      @$output);
	my $directories_found = grep(/^\s*Size:.*directory$/i, @$output);
	my $links_found       = grep(/^\s*Size:.*link$/i,      @$output);
	
	if ($files_found || $directories_found || $links_found) {
		notify($ERRORS{'DEBUG'}, 0, "'$file_path' exists on $computer_short_name, files: $files_found, directories: $directories_found, links: $links_found") if $display_output;
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unexpected output returned while attempting to determine if file or directory exists on $computer_short_name: '$file_path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_file

 Parameters  : $path
 Returns     : boolean
 Description : Deletes files or directories on the Linux computer.

=cut

sub delete_file {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument were not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$path = normalize_file_path($path);
	
	# Escape all spaces in the path
	my $escaped_path = escape_file_path($path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Delete the file
	my $command = "rm -rfv $escaped_path";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to delete file or directory on $computer_short_name:\npath: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/(cannot access|no such file)/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "file or directory not deleted because it does not exist on $computer_short_name: $path");
	}
	elsif (grep(/rm: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to delete file or directory on $computer_short_name: '$path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted '$path' on $computer_short_name");
	}
	
	# Make sure the path does not exist
	my $file_exists = $self->file_exists($path, 0);
	if (!defined($file_exists)) {
		notify($ERRORS{'WARNING'}, 0, "failed to confirm file doesn't exist on $computer_short_name: '$path'");
		return;
	}
	elsif ($file_exists) {
		notify($ERRORS{'WARNING'}, 0, "file was not deleted, it still exists on $computer_short_name: '$path'");
		return;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist on $computer_short_name: '$path'");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 clear_file

 Parameters  : $file_path
 Returns     : boolean
 Description : Clears a file on the computer via 'cat /dev/null'. If the file
               doesn't exist it is not created and true is returned.

=cut

sub clear_file {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Check if the file exists
	if (!$self->file_exists($file_path, 0)) {
		notify($ERRORS{'DEBUG'}, 0, "file not cleared on $computer_short_name because it doesn't exist: $file_path");
		return 1;
	}
	
	# Remove any quotes from the beginning and end of the path
	$file_path = normalize_file_path($file_path);
	
	# Escape all spaces in the path
	my $escaped_file_path = escape_file_path($file_path);
	
	# Clear the file
	my $command = "cat /dev/null > $escaped_file_path";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to clear file on $computer_short_name: '$file_path'");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to clear file on $computer_short_name: '$file_path', exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "cleared file on $computer_short_name: '$file_path'");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_directory

 Parameters  : $directory_path, $mode (optional)
 Returns     : boolean
 Description : Creates a directory on the Linux computer as indicated by the
               $directory_path argument.

=cut

sub create_directory {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the directory path argument
	my $directory_path = shift;
	if (!$directory_path) {
		notify($ERRORS{'WARNING'}, 0, "directory path argument was not supplied");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$directory_path = normalize_file_path($directory_path);
	
	# If ~ is passed as the directory path, skip directory creation attempt
	# The command will create a /root/~ directory since the path is enclosed in quotes
	return 1 if $directory_path eq '~';
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Attempt to create the directory
	my $command = "ls -d --color=never \"$directory_path\" 2>/dev/null || (mkdir -p \"$directory_path\" 2>&1 && ls -d --color=never \"$directory_path\")";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create directory on $computer_short_name:\npath: '$directory_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/mkdir:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^\s*$directory_path\s*$/, @$output)) {
		if (grep(/ls:/, @$output)) {
			notify($ERRORS{'OK'}, 0, "directory created on $computer_short_name: '$directory_path'");
		}
		else {
			#notify($ERRORS{'OK'}, 0, "directory already exists on $computer_short_name: '$directory_path'");
		}
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output) . "\nlast line:\n" . string_to_ascii(@$output[-1]));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 move_file

 Parameters  : $source_path, $destination_path
 Returns     : boolean
 Description : Moves or renames a file on a Linux computer.

=cut

sub move_file {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path arguments
	my $source_path      = shift;
	my $destination_path = shift;
	if (!$source_path || !$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination path arguments were not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$source_path      = normalize_file_path($source_path);
	$destination_path = normalize_file_path($destination_path);
	
	# Escape all spaces in the path
	my $escaped_source_path      = escape_file_path($source_path);
	my $escaped_destination_path = escape_file_path($destination_path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Execute the command to move the file
	my $command = "mv -f $escaped_source_path $escaped_destination_path";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to move file on $computer_short_name:\nsource path: '$source_path'\ndestination path: '$destination_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^mv: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to move file on $computer_short_name:\nsource path: '$source_path'\ndestination path: '$destination_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "moved file on $computer_short_name:\n'$source_path' --> '$destination_path'");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_available_space

 Parameters  : $path
 Returns     : If successful: integer
               If failed: undefined
 Description : Returns the bytes available in the path specified by the
               argument. 0 is returned if no space is available. Undefined is
               returned if an error occurred.

=cut

sub get_available_space {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Run stat -f specifying the path as an argument
	# Don't use df because you can't specify a path under ESX and parsing would be difficult
	my $command = "stat -f \"$path\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine available space on $computer_short_name, command: $command");
		return;
	}
	elsif (grep(/^stat: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running command to determine available space on $computer_short_name\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Create an output string from the array of lines for easier regex parsing
	my $output_string = join("\n", @$output);
	
	# Extract the block size value
	# Search case sensitive for 'Block size:' because the line may also contain "Fundamental block size:"
	# Some versions of Linux may not display a "Size:" value instead of "Block size:"
	# Blocks: Total: 8720776    Free: 8288943    Available: 7845951    Size: 4096
	my ($block_size) = $output_string =~ /(?:Block size|Size): (\d+)/;
	if (!$block_size) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate 'Block size:' or 'Size:' value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Extract the blocks free value
	my ($blocks_available) = $output_string =~ /Blocks:[^\n]*Available: (\d+)/;
	if (!defined($blocks_available)) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate blocks available value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Calculate the bytes available
	my $bytes_available = ($block_size * $blocks_available);
	my $mb_available    = format_number(($bytes_available / 1024 / 1024), 2);
	my $gb_available    = format_number(($bytes_available / 1024 / 1024 / 1024), 1);
	
	notify($ERRORS{'DEBUG'}, 0, "space available on volume on $computer_short_name containing '$path': " . get_file_size_info_string($bytes_available));
	return $bytes_available;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_total_space

 Parameters  : $path
 Returns     : If successful: integer
               If failed: undefined
 Description : Returns the total size in bytes of the volume where the path
               resides specified by the argument. Undefined is returned if an
               error occurred.

=cut

sub get_total_space {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Run stat -f specifying the path as an argument
	# Don't use df because you can't specify a path under ESX and parsing would be difficult
	my $command = "stat -f \"$path\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine available space on $computer_short_name, command: $command");
		return;
	}
	elsif (grep(/^stat: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running command to determine available space on $computer_short_name\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Create an output string from the array of lines for easier regex parsing
	my $output_string = join("\n", @$output);
	
	# Extract the block size value
	# Search case sensitive for 'Block size:' because the line may also contain "Fundamental block size:"
	# Some versions of Linux may not display a "Size:" value instead of "Block size:"
	# Blocks: Total: 8720776    Free: 8288943    Available: 7845951    Size: 4096
	my ($block_size) = $output_string =~ /(?:Block size|Size): (\d+)/;
	if (!$block_size) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate 'Block size:' or 'Size:' value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Extract the blocks total value
	my ($blocks_total) = $output_string =~ /Blocks:[^\n]*Total: (\d+)/;
	if (!defined($blocks_total)) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate blocks total value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Calculate the bytes free
	my $bytes_total = ($block_size * $blocks_total);
	my $mb_total    = format_number(($bytes_total / 1024 / 1024), 2);
	my $gb_total    = format_number(($bytes_total / 1024 / 1024 / 1024), 1);
	
	notify($ERRORS{'DEBUG'}, 0, "total size of volume on $computer_short_name containing '$path': " . get_file_size_info_string($bytes_total));
	return $bytes_total;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 copy_file_from

 Parameters  : $source_file_path, $destination_file_path
 Returns     : boolean
 Description : Copies file(s) from the Linux computer to the management node.

=cut

sub copy_file_from {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the source and destination arguments
	my ($source_file_path, $destination_file_path) = @_;
	if (!$source_file_path || !$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination file path arguments were not specified");
		return;
	}
	
	# Get the computer name
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	# Get the destination parent directory path and create the directory on the management node
	my $destination_directory_path = parent_directory_path($destination_file_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_file_path");
		return;
	}
	create_management_node_directory($destination_directory_path) || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the SCP command
	if (run_scp_command("$computer_node_name:\"$source_file_path\"", $destination_file_path, $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied file from $computer_node_name to management node: $computer_node_name:'$source_file_path' --> '$destination_file_path'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file from $computer_node_name to management node: $computer_node_name:'$source_file_path' --> '$destination_file_path'");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_file_size

 Parameters  : @file_paths
 Returns     : integer or array
 Description : Determines the size of the file specified by the file path
               argument in bytes. The file path argument may be a directory or
               contain wildcards. Directories are processed recursively.
               
               When called in sclar context, the actual bytes used on the disk by the file
               is returned. This correlates to the size reported by the `du`
               command. This value is not the same as what is reported by the `ls`
               command. This is important when determining the size of
               compressed files or thinly-provisioned virtual disk images.
               
               When called in array context, 3 values are returned:
               [0] bytes used (`du` size)
               [1] bytes reserved (`ls` size)
               [2] file count

=cut

sub get_file_size {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $calling_sub = (caller(1))[3] || '';
	
	# Get the path argument
	my @file_paths = @_;
	if (!@file_paths) {
		notify($ERRORS{'WARNING'}, 0, "file paths argument was not specified");
		return;
	}
	
	# Get the computer name
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	my $file_count           = 0;
	my $total_bytes_reserved = 0;
	my $total_bytes_used     = 0;
	
	for my $file_path (@file_paths) {
		# Normalize the file path
		$file_path = normalize_file_path($file_path);
		
		# Escape all spaces in the path
		my $escaped_file_path = escape_file_path($file_path);
		
		# Run stat rather than du because du is not available on VMware ESX
		# -L     Dereference links
		# %F     File type
		# %n     File name
		# %b     Number of blocks allocated (see %B)
		# %B     The size in bytes of each block reported by %b
		# %s     Total size, in bytes
		
		my $command = 'stat -L -c "%F:%n:%s:%b:%B" ' . $escaped_file_path;
		my ($exit_status, $output) = $self->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to determine file size on $computer_node_name: $file_path\ncommand: '$command'");
			return;
		}
		elsif (grep(/no such file/i, @$output)) {
			if ($calling_sub !~ /get_file_size/) {
				notify($ERRORS{'DEBUG'}, 0, "unable to determine size of file on $computer_node_name because it does not exist: $file_path\ncommand: '$command'");
			}
			return;
		}
		elsif (grep(/^stat:/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine file size on $computer_node_name: $file_path\ncommand: $command\noutput:\n" . join("\n", @$output));
			return;
		}
		
		# Loop through the stat output lines
		for my $line (@$output) {
			# Take the stat output line apart
			my ($type, $path, $file_bytes, $file_blocks, $block_size) = split(/:/, $line);
			if (!defined($type) || !defined($file_bytes) || !defined($file_blocks) || !defined($block_size) || !defined($path)) {
				notify($ERRORS{'WARNING'}, 0, "unexpected output returned from stat, line: $line\ncommand: $command\noutput:\n" . join("\n", @$output));
				return;
			}
			
			# Add the size to the total if the type is file
			if ($type =~ /file/) {
				$file_count++;
				
				my $file_bytes_allocated = ($file_blocks * $block_size);
				
				$total_bytes_used     += $file_bytes_allocated;
				$total_bytes_reserved += $file_bytes;
			}
			elsif ($type =~ /directory/) {
				$path =~ s/[\\\/\*]+$//g;
				#notify($ERRORS{'DEBUG'}, 0, "recursively retrieving size of files under directory: '$path'");
				my ($subdirectory_bytes_allocated, $subdirectory_bytes_used, $subdirectory_file_count) = $self->get_file_size("$path/*");
				
				# Values will be null if there are no files under the subdirectory
				if (!defined($subdirectory_bytes_allocated)) {
					next;
				}
				
				$file_count           += $subdirectory_file_count;
				$total_bytes_reserved += $subdirectory_bytes_used;
				$total_bytes_used     += $subdirectory_bytes_allocated;
			}
		}
	}
	
	if ($calling_sub !~ /get_file_size/) {
		notify($ERRORS{'DEBUG'}, 0, "size of " . join(", ", @file_paths) . " on $computer_node_name:\n" .
		"file count: $file_count\n" .
		"reserved: " . get_file_size_info_string($total_bytes_reserved) . "\n" .
		"used: " . get_file_size_info_string($total_bytes_used));
	}
	
	if (wantarray) {
		return ($total_bytes_used, $total_bytes_reserved, $file_count);
	}
	else {
		return $total_bytes_used;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_file_permissions

 Parameters  : $file_path, $chmod_mode, $recursive (optional)
 Returns     : boolean
 Description : Calls chmod to set the file permissions on the Linux computer.
               The $chmod_mode argument may be any valid chmod mode (+rw, 0755,
               etc). The $recursive argument is optional. The default is false.

=cut

sub set_file_permissions {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my $path = shift;
	if (!defined($path)) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Escape the file path in case it contains spaces
	$path = escape_file_path($path);
	
	my $chmod_mode = shift;
	if (!defined($chmod_mode)) {
		notify($ERRORS{'WARNING'}, 0, "chmod mode argument was not specified");
		return;
	}
	
	my $recursive        = shift;
	my $recursive_string = '';
	$recursive_string = "recursively " if $recursive;
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Run the chmod command
	my $command = "chmod ";
	$command .= "-R " if $recursive;
	$command .= "$chmod_mode $path";
	
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to " . $recursive_string . "set file permissions on $computer_node_name: '$command'");
		return;
	}
	elsif (grep(/No such file or directory/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to " . $recursive_string . "set permissions of '$path' to '$chmod_mode' on $computer_node_name because the file does not exist, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^chmod:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to " . $recursive_string . "set permissions of '$path' to '$chmod_mode' on $computer_node_name, command: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, $recursive_string . "set permissions of '$path' to '$chmod_mode' on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_file_owner

 Parameters  : $file_path, $owner, $group, $recursive (optional)
 Returns     : boolean
 Description : Calls chown to set the owner of a file or directory.

=cut

sub set_file_owner {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my $path = shift;
	if (!defined($path)) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Escape the file path in case it contains spaces
	$path = escape_file_path($path);
	
	my $owner = shift;
	if (!defined($owner)) {
		notify($ERRORS{'WARNING'}, 0, "owner argument was not specified");
		return;
	}
	
	my $group = shift;
	$owner .= ":$group" if $group;
	
	my $recursive = shift;
	$recursive = 1 if !defined($recursive);
	
	my $recursive_string = '';
	$recursive_string = "recursively " if $recursive;
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Run the chown command
	my $command = "chown ";
	$command .= "-R " if $recursive;
	$command .= "$owner $path";
	
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to " . $recursive_string . "set file owner on $computer_node_name: '$command'");
		return;
	}
	elsif (grep(/No such file or directory/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to " . $recursive_string . "set owner of '$path' to '$owner' on $computer_node_name because the file does not exist, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^chown:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to " . $recursive_string . "set owner of '$path' to '$owner' on $computer_node_name, command: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, $recursive_string . "set owner of '$path' to '$owner' on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 activate_interfaces

 Parameters  : none
 Returns     : true
 Description : Finds all networking interfaces with an active link. Checks if an
               ifcfg-eth* file exists for the interface. An ifcfg-eth* file is
               generated if it does not exist using DHCP and the interface is
               brought up via ifup. This is useful if additional interfaces are
               added by the provisioning module when an image is loaded. 

=cut

sub activate_interfaces {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Run 'ip link' to find all interfaces with links
	my $command = "ip link";
	notify($ERRORS{'DEBUG'}, 0, "attempting to find network interfaces with an active link");
	my ($exit_status, $output) = $self->execute($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to find network interfaces with an active link:\n$command");
		return;
	}
	
	# Extract the interface names from the 'ip link' output
	my @interface_names = grep {/^\d+:\s+(eth\d+)/; $_ = $1} @$output;
	notify($ERRORS{'DEBUG'}, 0, "found interface names:\n" . join("\n", @interface_names));
	
	# Find existing ifcfg-eth* files
	my $ifcfg_directory = '/etc/sysconfig/network-scripts';
	my @ifcfg_paths = $self->find_files($ifcfg_directory, 'ifcfg-eth*');
	notify($ERRORS{'DEBUG'}, 0, "found existing ifcfg-eth* files:\n" . join("\n", @ifcfg_paths));
	
	# Loop through the linked interfaces
	for my $interface_name (@interface_names) {
		my $ifcfg_path = "$ifcfg_directory/ifcfg-$interface_name";
		
		# Check if an ifcfg-eth* file already exists for the interface
		if (grep(/$ifcfg_path/, @ifcfg_paths)) {
			notify($ERRORS{'DEBUG'}, 0, "ifcfg file already exists for $interface_name");
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "ifcfg file does not exist for $interface_name");
		
		# Assemble the contents of the ifcfg-eth* file for the interface
		my $ifcfg_contents = <<EOF;
DEVICE=$interface_name
BOOTPROTO=dhcp
STARTMODE=onboot
ONBOOT=yes
EOF
		
		# Create the ifcfg file
		if (!$self->create_text_file($ifcfg_path, $ifcfg_contents)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create $ifcfg_path for interface: $interface_name");
			return;
		}
		
		# Call ifup on the interface
		my $command = "ifup $interface_name";
		my ($exit_status, $output) = $self->execute($command, 1);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to activate $interface_name interface: $command");
			return;
		}
		elsif ($exit_status eq '0' || grep(/done\./, @$output)) {
			notify($ERRORS{'OK'}, 0, "activated $interface_name interface, output:\n" . join("\n", @$output));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to activate $interface_name interface, exit status: $exit_status, output:\n" . join("\n", @$output));
			return;
		}
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_network_configuration

 Parameters  : $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves the network configuration on the Linux computer and
               constructs a hash. The hash reference returned is formatted as
               follows:
               |--%{eth0}
                  |--%{eth0}{default_gateway} '10.10.4.1'
                  |--%{eth0}{ip_address}
                     |--{eth0}{ip_address}{10.10.4.3} = '255.255.240.0'
                  |--{eth0}{name} = 'eth0'
                  |--{eth0}{physical_address} = '00:50:56:08:00:f8'

=cut

sub get_network_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift || 0;
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve network configuration, no cache: $no_cache");
	
	# Delete previously retrieved data if $no_cache was specified
	if ($no_cache) {
		delete $self->{network_configuration};
	}
	elsif ($self->{network_configuration}) {
		return $self->{network_configuration}
	}
	
	# Run ipconfig
	my $ifconfig_command = "/sbin/ifconfig -a";
	my ($ifconfig_exit_status, $ifconfig_output) = $self->execute($ifconfig_command);
	if (!defined($ifconfig_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve network configuration: $ifconfig_command");
		return;
	}
	#notify($ERRORS{'DEBUG'}, 0, "ifconfig output:\n" . join("\n", @$ifconfig_output));
	
	# Loop through the ifconfig output lines
	my $network_configuration;
	my $interface_name;
	for my $ifconfig_line (@$ifconfig_output) {
		# Extract the interface name from the Link line:
		# eth2      Link encap:Ethernet  HWaddr 00:0C:29:78:77:AB
		#eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
		#if ($ifconfig_line =~ /^([^\s]+).*Link/) {
		if ($ifconfig_line =~ /^([^\s:]+).*(Link|flags)/) {
			$interface_name = $1;
			$network_configuration->{$interface_name}{name} = $interface_name;
		}
		
		# Skip to the next line if the interface name has not been determined yet
		next if !$interface_name;
		
		# Parse the HWaddr line:
		# eth2      Link encap:Ethernet  HWaddr 00:0C:29:78:77:AB
		#if ($ifconfig_line =~ /HWaddr\s+([\w:]+)/) {
		if ($ifconfig_line =~ /(ether|HWaddr)\s+([\w:]+)/) {
			$network_configuration->{$interface_name}{physical_address} = lc($2);
		}
		
		# Parse the IP address line:
		# inet addr:10.10.4.35  Bcast:10.10.15.255  Mask:255.255.240.0
		if ($ifconfig_line =~ /inet addr:([\d\.]+)\s+Bcast:([\d\.]+)\s+Mask:([\d\.]+)/) {
			$network_configuration->{$interface_name}{ip_address}{$1} = $3;
			$network_configuration->{$interface_name}{broadcast_address} = $2;
		}
      
		# inet 10.25.14.3  netmask 255.255.240.0  broadcast 10.25.15.255
      if ($ifconfig_line =~ /inet\s+([\d\.]+)\s+netmask\s+([\d\.]+)\s+broadcast\s+([\d\.]+)/) {
			$network_configuration->{$interface_name}{ip_address}{$1} = $2;
			$network_configuration->{$interface_name}{broadcast_address} = $3;
		}

	}
	
	# Run route
	my $route_command = "/sbin/route -n";
	my ($route_exit_status, $route_output) = $self->execute($route_command);
	if (!defined($route_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve routing configuration: $route_command");
		return;
	}
	
	# Loop through the route output lines
	for my $route_line (@$route_output) {
		my ($default_gateway, $interface_name) = $route_line =~ /^0\.0\.0\.0\s+([\d\.]+).*\s([^\s]+)$/g;
		
		if (!defined($interface_name) || !defined($default_gateway)) {
			#notify($ERRORS{'DEBUG'}, 0, "route output line does not contain a default gateway: '$route_line'");
		}
		elsif (!defined($network_configuration->{$interface_name})) {
			notify($ERRORS{'WARNING'}, 0, "found default gateway for '$interface_name' interface but the network configuration for '$interface_name' was not previously retrieved, route output:\n" . join("\n", @$route_output) . "\nnetwork configuation:\n" . format_data($network_configuration));
		}
		elsif (defined($network_configuration->{$interface_name}{default_gateway}) && $default_gateway ne $network_configuration->{$interface_name}{default_gateway}) {
			notify($ERRORS{'WARNING'}, 0, "multiple default gateways are configured for '$interface_name' interface, route output:\n" . join("\n", @$route_output));
		}
		else {
			$network_configuration->{$interface_name}{default_gateway} = $default_gateway;
			notify($ERRORS{'DEBUG'}, 0, "found default route configured for '$interface_name' interface: $default_gateway");
		}
	}
	
	$self->{network_configuration} = $network_configuration;
	#can produce large output, if you need to monitor the configuration setting uncomment the below output statement
	notify($ERRORS{'DEBUG'}, 0, "retrieved network configuration:\n" . format_data($self->{network_configuration}));
	return $self->{network_configuration};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reboot

 Parameters  : $wait_for_reboot
 Returns     : 
 Description : 

=cut

sub reboot {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check if an argument was supplied
	my $wait_for_reboot = shift || 1;
	if ($wait_for_reboot) {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and waiting for SSH to become active");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and NOT waiting");
	}
	
	my $reboot_start_time = time();
	
	# Check if computer responds to ssh before preparing for reboot
	if ($self->wait_for_ssh(0)) {
		# Check if shutdown exists on the computer
		my $reboot_command;
		if ($self->file_exists("/sbin/shutdown")) {
			$reboot_command = "/sbin/shutdown -r now";
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot not attempted, /sbin/shutdown did not exists on $computer_node_name");
			return;
		}
		
		my ($reboot_exit_status, $reboot_output) = $self->execute($reboot_command);
		if (!defined($reboot_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to reboot $computer_node_name");
			return;
		}
		elsif ($reboot_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "executed reboot command on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to reboot $computer_node_name, attempting power reset, output:\n" . join("\n", @$reboot_output));
			
			# Call provisioning module's power_reset() subroutine
			if ($self->provisioner->power_reset()) {
				notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
				return;
			}
		}
	}
	else {
		# Computer did not respond to SSH
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not responding to SSH, graceful reboot cannot be performed, attempting hard reset");
		
		# Call provisioning module's power_reset() subroutine
		if ($self->provisioner->power_reset()) {
			notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
			return;
		}
	}
	
	# Check if wait for reboot is set
	if (!$wait_for_reboot) {
		return 1;
	}
	
	if ($self->wait_for_reboot()) {
		# Reboot was successful, calculate how long reboot took
		my $reboot_end_time = time();
		my $reboot_duration = ($reboot_end_time - $reboot_start_time);
		notify($ERRORS{'OK'}, 0, "reboot complete on $computer_node_name, took $reboot_duration seconds");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, made default wait_attempt_limit attempts");
		return 0;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 shutdown

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub shutdown {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check if an argument was supplied
	my $wait_for_power_off = shift || 1;
	if ($wait_for_power_off) {
		notify($ERRORS{'DEBUG'}, 0, "shutting down $computer_node_name and waiting for power off");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "shutting down $computer_node_name and NOT waiting for power off");
	}
	
	# Check if computer responds to ssh before preparing for shut down
	if ($self->wait_for_ssh(0)) {
		my $command = '/sbin/shutdown -h now';
		
		my ($exit_status, $output) = $self->execute({command => $command, timeout => 90, ignore_error => 1});
		
		# Wait maximum of 5 minutes for computer to power off
		my $power_off = $self->provisioner->wait_for_power_off(300);
		if (!defined($power_off)) {
			# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
			notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 1 minute to allow computer time to shutdown");
			sleep 60;
		}
		elsif (!$power_off) {
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off");
			# Call provisioning module's power_off() subroutine
			if (!$self->provisioner->power_off()) {
				notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, failed to initiate power off");
				return;
			}
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is not responding to SSH, attempting power off");
		
		# Call provisioning module's power_off() subroutine
		if (!$self->provisioner->power_off()) {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, failed to initiate power off");
			return;
		}
	}
	
	if (!$wait_for_power_off || $self->provisioner->wait_for_power_off(300, 10)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, computer never powered off");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 hibernate

 Parameters  : none
 Returns     : boolean
 Description : Hibernates the computer.

=cut

sub hibernate {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = 'echo disk > /sys/power/state &';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to hibernate $computer_node_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "executed command to hibernate $computer_node_name: $command" . (scalar(@$output) ? "\noutput:\n" . join("\n", @$output) : ''));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_node_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Wait for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(300, 5);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 1 minute to allow computer time to hibernate");
		sleep 60;
		return 1;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off after executing hibernate command: $command");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name powered off after executing hibernate command");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_user

 Parameters  : $argument_hash_ref
 Returns     : boolean
 Description : Creates a user on the computer. The argument hash reference
               should be constructed as follows:
					{
						username => $username,
						password => $password, (optional)
						root_access => $root_access,
						uid => $uid, (optional)
						ssh_public_keys => $ssh_public_keys, (optional)
					});

=cut

sub create_user {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $user_parameters = shift;
	if (!$user_parameters) {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, user parameters argument was not provided");
		return;
	}
	elsif (!ref($user_parameters) || ref($user_parameters) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, argument provided is not a hash reference");
		return;
	}
	
	my $username = $user_parameters->{username};
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'username' key:\n" . format_data($user_parameters));
		return;
	}
	
	my $root_access = $user_parameters->{root_access};
	if (!defined($root_access)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'root_access' key:\n" . format_data($user_parameters));
		return;
	}
	
	my $password = $user_parameters->{password};
	my $uid = $user_parameters->{uid};
	my $ssh_public_keys = $user_parameters->{ssh_public_keys};
	
	# If user account does not already exist - create it, then
	# -- Set password if using local authentication
	# -- update sudoers file if root access allowed
	# -- process connect_methods_access

	if (!$self->user_exists($username)) {
	
		notify($ERRORS{'DEBUG'}, 0, "creating user on $computer_node_name:\n" .
			"username: $username\n" .
			"password: " . (defined($password) ? $password : '<not set>') . "\n" .
			"UID: " . ($uid ? $uid : '<not set>') . "\n" .
			"root access: " . ($root_access ? 'yes' : 'no') . "\n" .
			"SSH public keys: " . (defined($ssh_public_keys) ? $ssh_public_keys : '<not set>')
		);
		
		my $home_directory_root = "/home";
		my $home_directory_path = "$home_directory_root/$username";
		my $home_directory_on_local_disk = $self->is_file_on_local_disk($home_directory_root);
		if ($home_directory_on_local_disk ) {
			my $useradd_command = "/usr/sbin/useradd -s /bin/bash -m -d /home/$username -g vcl";
			$useradd_command .= " -u $uid" if ($uid);
			$useradd_command .= " $username";
			
			my ($useradd_exit_status, $useradd_output) = $self->execute($useradd_command);
			if (!defined($useradd_output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to execute command to add user '$username' to $computer_node_name: '$useradd_command'");
				return;
			}
			elsif (grep(/^useradd: /, @$useradd_output)) {
				notify($ERRORS{'WARNING'}, 0, "warning detected on add user '$username' to $computer_node_name\ncommand: '$useradd_command'\noutput:\n" . join("\n", @$useradd_output));
			}
			else {
				notify($ERRORS{'OK'}, 0, "added user '$username' to $computer_node_name, output:" . (scalar(@$useradd_output) ? "\n" . join("\n", @$useradd_output) : ' <none>'));
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "$home_directory_path is NOT on local disk, skipping useradd attempt");	
		}
	}
	
	# Set the password
	if ($password) {
		# Set password
		if (!$self->set_password($username, $password)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to set password of user '$username' on $computer_node_name");
			return;
		}
	}

	# Process connect_methods
	if($self->can("grant_connect_method_access")) {
		if(!$self->grant_connect_method_access({
			username => $username,
			uid => $uid,
			ssh_public_keys => $ssh_public_keys,
			})) {
			notify($ERRORS{'WARNING'}, 0, "failed to process grant_connect_method_access for $username");
		}
	}
	
	# Add user to sudoers if necessary
	if ($root_access && !$self->grant_root_access($username)) {
		notify($ERRORS{'WARNING'}, 0, "failed to process grant_root_access for $username");
		return;
	}
	
	return 1;
} ## end sub create_user


#/////////////////////////////////////////////////////////////////////////////

=head2 grant_root_access

 Parameters  : $username
 Returns     : boolean
 Description : Adds the user to the sudoers file.

=cut

sub grant_root_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $username = shift;
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not supplied");
		return;
	}
	
	my $sudoers_file_path = '/etc/sudoers';
	my $sudoers_line = "$username ALL= NOPASSWD: ALL";
	if ($self->append_text_file($sudoers_file_path, $sudoers_line)) {
		notify($ERRORS{'DEBUG'}, 0, "appended line to $sudoers_file_path: '$sudoers_line'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to append line to $sudoers_file_path: '$sudoers_line'");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  : $username
 Returns     :
 Description :

=cut

sub delete_user {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Make sure the user login ID was passed
	my $username = shift;
	$username = $self->data->get_user_login_id() if (!$username);
	if (!$username) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Make sure the user exists
	if (!$self->user_exists($username)) {
		notify($ERRORS{'DEBUG'}, 0, "user NOT deleted from $computer_node_name because it does not exist: $username");
		return 1;
	}
	
	# Check if the user is logged in
	if ($self->user_logged_in($username)) {
		if (!$self->logoff_user($username)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete user $username from $computer_node_name, user appears to be logged in but could NOT be logged off");
			return;
		}
	}
	
	# Determine if home directory is on a local device or network share
	my $home_directory_path = "/home/$username";
	my $home_directory_on_local_disk = $self->is_file_on_local_disk($home_directory_path);
	
	# Assemble the userdel command
	my $userdel_command = "/usr/sbin/userdel";
	
	if ($home_directory_on_local_disk) {
		# Fetch exclude_list

		my @exclude_list = $self->get_exclude_list();

		if (!(grep(/\/home\/$username/, @exclude_list))) {
		notify($ERRORS{'DEBUG'}, 0, "home directory will be deleted: $home_directory_path");
		$userdel_command .= ' -r';
	}
	}
	$userdel_command .= " $username";
	
	# Call userdel to delete the user
	my ($userdel_exit_status, $userdel_output) = $self->execute($userdel_command);
	if (!defined($userdel_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete user from $computer_node_name: $username");
		return;
	}
	elsif (grep(/does not exist/i, @$userdel_output)) {
		notify($ERRORS{'DEBUG'}, 0, "user '$username' NOT deleted from $computer_node_name because it does not exist");
	}
	elsif (grep(/not found/i, @$userdel_output)) {
		notify($ERRORS{'DEBUG'}, 0, "userdel warning '$username' $computer_node_name :\n" . join("\n", @$userdel_output));
	}
	elsif (grep(/userdel: /i, @$userdel_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete user '$username' from $computer_node_name, command: '$userdel_command', exit status: $userdel_exit_status, output:\n" . join("\n", @$userdel_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted user '$username' from $computer_node_name");
	}
	
	# Call groupdel to delete the user's group
	my $groupdel_command = "/usr/sbin/groupdel $username";
	my ($groupdel_exit_status, $groupdel_output) = $self->execute($groupdel_command);
	if (!defined($groupdel_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to delete group from $computer_node_name: $username");
		return;
	}
	elsif (grep(/does not exist/i, @$groupdel_output)) {
		notify($ERRORS{'DEBUG'}, 0, "group '$username' NOT deleted from $computer_node_name because it does not exist");
	}
	elsif (grep(/groupdel: /i, @$groupdel_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete group '$username' from $computer_node_name, command: '$groupdel_command', output:\n" . join("\n", @$groupdel_output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "deleted group '$username' from $computer_node_name");
	}
	
	# Remove username from AllowUsers lines in ssh/external_sshd_config
	my $external_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	my @original_lines = $self->get_file_contents($external_sshd_config_file_path);
	my @modified_lines;
	my $new_file_contents;
	for my $line (@original_lines) {
		if ($line =~ /AllowUsers.*\s$username(\s|$)/) {
			push @modified_lines, $line;
			$line =~ s/\s*$username//g;
			# If user was only username listed on line, don't add empty AllowUsers line back to file
			if ($line !~ /AllowUsers\s+\w/) {
				next;
			}
		}
		$new_file_contents .= "$line\n";
	}
	if (@modified_lines) {
		notify($ERRORS{'OK'}, 0, "removing or modifying AllowUsers lines in $external_sshd_config_file_path:\n" . join("\n", @modified_lines));
		$self->create_text_file($external_sshd_config_file_path, $new_file_contents) || return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no AllowUsers lines were found in $external_sshd_config_file_path containing '$username'");
	}
	
	# Remove lines from sudoers
	$self->remove_lines_from_file('/etc/sudoers', "^\\s*$username\\s+") || return;
	
	return 1;
} ## end sub delete_user

#/////////////////////////////////////////////////////////////////////////////

=head2 is_file_on_local_disk

 Parameters  : $file_path
 Returns     : boolean
 Description : Determines if the file or directory is located on a local disk or
               network share.

=cut

sub is_file_on_local_disk {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Run df to determine if file is on a local device or network share
	my $df_command = "df -T -P $file_path";
	my ($df_exit_status, $df_output) = $self->execute($df_command);
	if (!defined($df_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if file is on a local disk");
		return;
	}
	elsif (grep(/(no such file|no file system)/i, @$df_output)) {
		notify($ERRORS{'DEBUG'}, 0, "file does NOT exist on $computer_name: $file_path");
		return;
	}
	elsif (grep(m|/dev/|i, @$df_output) && !grep(/ (nfs|afs) /i, @$df_output)) {
		notify($ERRORS{'DEBUG'}, 0, "file is on a local disk: $file_path, output:\n" . join("\n", @$df_output));
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "file is NOT on a local disk: $file_path, output:\n" . join("\n", @$df_output));
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////
=head2 enable_dhcp

 Parameters  : $interface_name (optional)
 Returns     : boolean
 Description : Configures the ifcfg-* file(s) to use DHCP. If an interface name
               argument is specified, only the ifcfg file for that interface
               will be configured. If no argument is specified, the files for
               the public and private interfaces will be configured.

=cut

sub enable_dhcp {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $interface_name_argument = shift;
	my @interface_names;
	if (!$interface_name_argument) {
		push(@interface_names, $self->get_private_interface_name());
		push(@interface_names, $self->get_public_interface_name());
	}
	elsif ($interface_name_argument =~ /private/i) {
		push(@interface_names, $self->get_private_interface_name());
	}
	elsif ($interface_name_argument =~ /public/i) {
		push(@interface_names, $self->get_public_interface_name());
	}
	else {
		push(@interface_names, $interface_name_argument);
	}
	
	for my $interface_name (@interface_names) {
		my $ifcfg_file_path = "/etc/sysconfig/network-scripts/ifcfg-$interface_name";
		notify($ERRORS{'DEBUG'}, 0, "attempting to enable DHCP on interface: $interface_name\nifcfg file path: $ifcfg_file_path");
		
		my $ifcfg_file_contents = <<EOF;
DEVICE=$interface_name
BOOTPROTO=dhcp
ONBOOT=yes
EOF
		
		# Remove any Windows carriage returns
		$ifcfg_file_contents =~ s/\r//g;
		
		# Remove the last newline
		$ifcfg_file_contents =~ s/\n$//s;
		
		# Write the contents to the ifcfg file
		if ($self->create_text_file($ifcfg_file_path, $ifcfg_file_contents)) {
			notify($ERRORS{'DEBUG'}, 0, "updated $ifcfg_file_path:\n" . string_to_ascii($ifcfg_file_contents));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update $ifcfg_file_path");
			return;
		}
		
		# Remove any leftover ifcfg-*.bak files
		$self->delete_file('/etc/sysconfig/network-scripts/ifcfg-eth*.bak');
		
		# Remove dhclient lease files
		$self->delete_file('/var/lib/dhclient/*.leases');
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 service_exists

 Parameters  : $service_name
 Returns     : If called in scalar/boolean context: boolean
               If called in array context: array
 Description : Checks if the service exists on the computer. The return value
               differs depending on if this subroutine was called in
               scalar/boolean or array context.
               
               Scalar/boolean context returns either '0' or '1':
               if ($self->service_exists('xxx'))
               
               Array context returns an array with a single, integer element.
               The value of this integer is the index of the init module
               returned by get_init_modules which controls the service. This is
               done so the calling subroutine doesn't need to perform the same
               steps to determine which init module to use when controlling
               services. The value of the array element may be 0, meaning the
               service exists and is controlled by the first init module
               returned by get_init_modules. Therefore, be sure to check if the
               return value is defined and not whether it is true/false when
               called in array context.
               
               my ($init_module_index) = $self->service_exists('xxx');
               
               if (defined($init_module_index))... means service exists,
               $init_module_index may be 0 or another positive integer.
               
               if ($init_module_index)... WRONG! This will evaluate to false if
               the service does not exist or if it does exist and the first init
               module controls it.

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	# Check if this service has already been checked
	if (defined($self->{service_init_module}{$service_name})) {
		my $init_module_index = $self->{service_init_module}{$service_name}{init_module_index};
		my $init_module_name = $self->{service_init_module}{$service_name}{init_module_name};
		
		if (defined($init_module_index)) {
			#notify($ERRORS{'DEBUG'}, 0, "'$service_name' service has already been checked and exists, contolled by $init_module_name init module ($init_module_index)");
			return (wantarray) ? ($init_module_index) : 1;
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "'$service_name' service has already been checked and does NOT exist");
			return (wantarray) ? () : 0;
		}
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my @init_modules = $self->get_init_modules();
	my $init_module_index = 0;
	for my $init (@init_modules) {
		my ($init_module_name) = ref($init) =~ /([^:]+)$/;
		
		# Check if the service names have already been retrieved by this particular init module object
		my @service_names;
		if ($init->{service_names}) {
			@service_names = @{$init->{service_names}};
		}
		else {
			@service_names = $init->get_service_names();
			$init->{service_names} = \@service_names;
		}
		
		if (grep(/^$service_name$/, @service_names)) {
			$self->{service_init_module}{$service_name} = {
				init_module_index => $init_module_index,
				init_module_name => $init_module_name,
			};
			
			if (wantarray) {
				notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists on $computer_node_name, controlled by $init_module_name init module ($init_module_index), returning array: ($init_module_index)");
				return $init_module_index;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists on $computer_node_name, controlled by $init_module_name init module ($init_module_index), returning scalar: 1");
				return 1;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$service_name' service is not controlled by $init_module_name init module ($init_module_index)");
		}
		$init_module_index++;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
	$self->{service_init_module}{$service_name} = {};
	return (wantarray) ? () : 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_service_enabled

 Parameters  : $service_name
 Returns     : boolean
 Description : Determines if a service is enabled on the computer.

=cut

sub is_service_enabled {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is enabled, it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	if (!$init_module->can('service_enabled')) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is enabled on $computer_node_name, " . ref($init_module) . " module does not implement a 'service_running' subroutine");
		return;
	}
	return $init_module->service_enabled($service_name);
}


#/////////////////////////////////////////////////////////////////////////////

=head2 is_service_running

 Parameters  : $service_name
 Returns     : boolean
 Description : Determines if a service is running on the computer.

=cut

sub is_service_running {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is running, it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	if (!$init_module->can('service_running')) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service is running on $computer_node_name, " . ref($init_module) . " module does not implement a 'service_running' subroutine");
		return;
	}
	return $init_module->service_running($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Enables a service on the computer.

=cut

sub enable_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable '$service_name' service, it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	if (!$init_module->can('enable_service')) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable '$service_name' service on $computer_node_name, " . ref($init_module) . " module does not implement an 'enable_service' subroutine");
		return;
	}
	return $init_module->enable_service($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_service

 Parameters  : $service_name
 Returns     : boolean
 Description : disables a service on the computer.

=cut

sub disable_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable '$service_name' service, it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	if (!$init_module->can('disable_service')) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable '$service_name' service on $computer_node_name, " . ref($init_module) . " module does not implement an 'disable_service' subroutine");
		return;
	}
	return $init_module->disable_service($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub start_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to start '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	return $init_module->start_service($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'DEBUG'}, 0, "unable to stop '$service_name' service because it does not exist on $computer_node_name");
		return 1;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	return $init_module->stop_service($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub restart_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to restart '$service_name' service because it does not exist on $computer_node_name");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	return $init_module->restart_service($service_name);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_service

 Parameters  : $service_name
 Returns     : boolean
 Description : 

=cut

sub delete_service {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($init_module_index) = $self->service_exists($service_name);
	if (!defined($init_module_index)) {
		notify($ERRORS{'DEBUG'}, 0, "unable to delete '$service_name' service because it does not exist on $computer_node_name");
		return 1;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	if ($init_module->delete_service($service_name)) {
		# Delete the cached service name array
		delete $self->{service_init_module}{$service_name};
		delete $init_module->{service_names};
	}
	else {
		return;
	}
	
	# Delete external_sshd_config if deleting the ext_sshd service
	if ($service_name =~ /ext_ssh/) {
		$self->delete_file('/etc/ssh/external_sshd_config');
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_connection_on_port

 Parameters  : $port
 Returns     : (connected|conn_wrong_ip|timeout|failed)
 Description : uses netstat to see if any thing is connected to the provided port

=cut

sub check_connection_on_port {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name          = $self->data->get_computer_node_name();
	my $remote_ip                   = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address  = $self->get_public_ip_address();
	my $request_state_name          = $self->data->get_request_state_name();
	
	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
		return "failed";
	}
	
	my $port_connection_info = $self->get_port_connection_info();
	for my $protocol (keys %$port_connection_info) {
		if (!defined($port_connection_info->{$protocol}{$port})) {
			next;
		}
		
		for my $connection (@{$port_connection_info->{$protocol}{$port}}) {
			my $connection_local_ip = $connection->{local_ip};
			my $connection_remote_ip = $connection->{remote_ip};
			
			if ($connection_local_ip ne $computer_public_ip_address) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring connection, not connected to public IP address ($computer_public_ip_address): $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
				next;
			}
			
			if ($connection_remote_ip eq $remote_ip) {
				notify($ERRORS{'DEBUG'}, 0, "connection detected from reservation remote IP: $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
				return 1;
			}
			
			# Connection is not from reservation remote IP address, check if user is logged in
			if ($self->user_logged_in()) {
				notify($ERRORS{'DEBUG'}, 0, "connection detected from different remote IP address than current reservation remote IP ($remote_ip): $connection_remote_ip --> $connection_local_ip:$port ($protocol), updating reservation remote IP to $connection_remote_ip");
				$self->data->set_reservation_remote_ip($connection_remote_ip);
				return 1;
			}
			
			notify($ERRORS{'DEBUG'}, 0, "ignoring connection, user is not logged in and remote IP address does not match current reservation remote IP ($remote_ip): $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
		}
	}
	
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_core_count

 Parameters  : none
 Returns     : integer
 Description : Retrieves the quantitiy of CPU cores the computer has.

=cut

sub get_cpu_core_count {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "cat /proc/cpuinfo";
	my ($exit_status, $output) = $self->execute($command);
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve CPU info from $computer_node_name");
		return;
	}
	
	# Get the number of 'processor :' lines and the 'cpu cores :' and 'siblings :' values from the cpuinfo output
	my $processor_count = scalar(grep(/^processor\s*:/, @$output));
	if (!$processor_count) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine $computer_node_name CPU core count, output does not contain any 'processor :' lines:\n" . join("\n", @$output));
		return;
	}
	my ($cpu_cores) = map {$_ =~ /cpu cores\s*:\s*(\d+)/} @$output;
	$cpu_cores = 1 unless $cpu_cores;
	
	my ($siblings) = map {$_ =~ /siblings\s*:\s*(\d+)/} @$output;
	$siblings = 1 unless $siblings;
	
	# The actual CPU core count can be determined by the equation:
	my $cpu_core_count = ($processor_count * $cpu_cores / $siblings);
	
	# If hyperthreading is enabled, siblings will be greater than CPU cores
	# If hyperthreading is not enabled, they will be equal
	my $hyperthreading_enabled = ($siblings > $cpu_cores) ? 'yes' : 'no';
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved $computer_node_name CPU core count: $cpu_core_count
		cpuinfo 'processor' line count: $processor_count
		cpuinfo 'cpu cores': $cpu_cores
		cpuinfo 'siblings': $siblings
		hyperthreading enabled: $hyperthreading_enabled"
	);
	
	return $cpu_core_count;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_speed

 Parameters  : none
 Returns     : integer
 Description : Retrieves the speed of the computer's CPUs in MHz.

=cut

sub get_cpu_speed {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "cat /proc/cpuinfo";
	my ($exit_status, $output) = $self->execute($command);
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve CPU info from $computer_node_name");
		return;
	}
	
	my ($mhz) = map {$_ =~ /cpu MHz\s*:\s*(\d+)/} @$output;
	if ($mhz) {
		$mhz = int($mhz);
		notify($ERRORS{'DEBUG'}, 0, "retrieved $computer_node_name CPU speed: $mhz MHz");
		return $mhz;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine $computer_node_name CPU speed CPU speed, 'cpu MHz :' line does not exist in the cpuinfo output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_total_memory

 Parameters  : none
 Returns     : integer
 Description : Retrieves the computer's total memory capacity in MB.

=cut

sub get_total_memory {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "dmesg | grep Memory:";
	my ($exit_status, $output) = $self->execute($command);
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve memory info from $computer_node_name");
		return;
	}
	
	# Output should look like this:
	# Memory: 1024016k/1048576k available (2547k kernel code, 24044k reserved, 1289k data, 208k init)
	my ($memory_kb) = map {$_ =~ /Memory:.*\/(\d+)k available/} @$output;
	if ($memory_kb) {
		my $memory_mb = int($memory_kb / 1024);
		notify($ERRORS{'DEBUG'}, 0, "retrieved $computer_node_name total memory capacity: $memory_mb MB");
		return $memory_mb;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine $computer_node_name total memory capacity from command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_firewall_port
 
 Parameters  : $protocol, $port, $scope (optional), $overwrite_existing (optional)
 Returns     : boolean
 Description : Enables an iptables firewall port. The protocol and port
               arguments must be supplied. Port may be an integer, '*', or
               'any'.
               
               If protocol is '*' or 'any' and the protocol is anything other
               than ICMP, the scope argument must be specified otherwise the
               firewall would be opened to any port from any address.
               
               If supplied, the scope argument must be in one of the following
               forms:
               x.x.x.x (10.1.1.1)
               x.x.x.x/y (10.1.1.1/24)
               x.x.x.x/y.y.y.y (10.1.1.1/255.255.255.0)
               
               If the $overwrite_existing argument is supplied, all existing
               rules matching the protocol and port will be removed and
               replaced.
 
=cut

sub enable_firewall_port {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($protocol, $port, $scope_argument, $overwrite_existing) = @_;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check to see if this OS has iptables
	return 1 unless $self->service_exists("iptables");
	
	# Check the protocol argument
	if (!defined($protocol)) {
		notify($ERRORS{'WARNING'}, 0, "protocol argument was not supplied");
		return;
	}
	elsif ($protocol !~ /^\w+$/i) {
		notify($ERRORS{'WARNING'}, 0, "protocol argument is not valid: '$protocol'");
		return;
	}
	$protocol = lc($protocol);
	
	# Check the port argument
	if (!defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "port argument was not supplied");
		return;
	}
	elsif ($port =~ /^(any|\*)$/i) {
		# If the port argument is unrestricted, the scope argument must be specified
		if ($protocol !~ /icmp/i && !$scope_argument) {
			notify($ERRORS{'WARNING'}, 0, "firewall not modified, port argument is not restricted to a certain port: '$port', scope argument was not supplied, it must be restricted to certain IP addresses if the port argument is unrestricted");
			return;
		}
		
		# Check if icmp/* was specified, change the port to 255 (all ICMP types)
		if ($protocol =~ /icmp/i) {
			$port = 255;
		}
		else {
			$port = 'any';
		}
	}
	elsif ($port !~ /^\d+$/i) {
		notify($ERRORS{'WARNING'}, 0, "port argument is not valid: '$port', it must be an integer, '*', or 'any'");
		return;
	}
	
	# Check the scope argument
	if (!$scope_argument) {
		$scope_argument = 'any';
	}
	my $parsed_scope_argument = $self->parse_firewall_scope($scope_argument);
	if (!$parsed_scope_argument) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument: '$scope_argument'");
		return;
	}
	
	# Make sure the management node is not cut off by overwriting port 22
	if ($overwrite_existing && $port eq '22' && $parsed_scope_argument !~ /0\.0\.0\.0/) {
		if (!$self->grant_management_node_access()) {
			notify($ERRORS{'WARNING'}, 0, "firewall port $port not enabled because access could be cut off from the management node");
			return;
		}
	}
	
	my $chain = "INPUT";
	my @commands;
	my $new_scope = '';
	my $existing_scope_string = '';
	
	# Loop through the rules
	# Important: reverse sort the rules because some rules may be deleted
	# They must be deleted in order from highest rule number to lowest
	# Otherwise, unintended rules will be deleted unless the rule numbers are adjusted
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	RULE: for my $rule_number (reverse sort keys %{$firewall_configuration->{$chain}}) {
		my $rule = $firewall_configuration->{$chain}{$rule_number};
		
		# Check if the rule matches the protocol and port arguments
		if (!defined($rule->{$protocol}{$port})) {
			next RULE;
		}
		
		# Ignore rule is existing scope isn't defined
		my $existing_scope = $rule->{$protocol}{$port}{scope};
		if (!defined($existing_scope)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring rule $rule_number, existing scope is NOT specified:\n" . format_data($rule->{$protocol}{$port}));
			next RULE;
		}
		$existing_scope_string .= "$existing_scope,";
		
		# Existing rules will be replaced with new rules which consolidate overlapping scopes
		# This helps reduce duplicate rules and the number of individual rules
		push @commands, "iptables -D $chain $rule_number";
		
		notify($ERRORS{'DEBUG'}, 0, "existing $chain chain rule $rule_number matches:\n" . format_data($firewall_configuration->{$chain}{$rule_number}));
	}
	
	# Combine all of the existing scopes matching the protocol/port
	my $parsed_existing_scope;
	if ($existing_scope_string) {
		$parsed_existing_scope = $self->parse_firewall_scope($existing_scope_string);
		if (!$parsed_existing_scope) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse existing firewall scope: '$existing_scope_string'");
			return;
		}
	}
	
	if (!$parsed_existing_scope) {
		$new_scope = $parsed_scope_argument;
		notify($ERRORS{'DEBUG'}, 0, "existing $protocol/$port firewall rule does not exist, new rule will be added, scope: $new_scope");
	}
	elsif ($overwrite_existing) {
		if ($parsed_existing_scope eq $parsed_scope_argument) {
			notify($ERRORS{'DEBUG'}, 0, "firewall modification for $protocol/$port not necessary, existing scope matches scope argument: $parsed_scope_argument");
			return 1;
		}
		else {
			$new_scope = $parsed_scope_argument;
			notify($ERRORS{'DEBUG'}, 0, "overwrite existing argument specified, existing $protocol/$port firewall rule(s) will be replaced:\n" .
				"existing scope: $parsed_existing_scope\n" .
				"new scope: $new_scope"
			);
		}
	}
	else {
		# Combine the existing matching scopes and the scope argument, then check if anything needs to be done
		my $appended_scope = $self->parse_firewall_scope("$parsed_scope_argument,$parsed_existing_scope");
		if (!$appended_scope) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument appended with existing scope: '$parsed_scope_argument,$parsed_existing_scope'");
			return;
		}
		
		if ($parsed_existing_scope eq $appended_scope) {
			notify($ERRORS{'DEBUG'}, 0, "firewall modification for $protocol/$port not necessary, existing scope includes entire scope argument:\n" .
				"scope argument: $parsed_scope_argument\n" .
				"existing scope: $parsed_existing_scope"
			);
			return 1;
		}
		else {
			$new_scope = $appended_scope;
			if ($parsed_scope_argument eq $appended_scope) {
				notify($ERRORS{'DEBUG'}, 0, "existing $protocol/$port rule(s) will be replaced, scope argument includes entire existing scope:\n" .
					"scope argument: $parsed_scope_argument\n" .
					"existing scope: $parsed_existing_scope\n" .
					"new scope: $new_scope"
				);
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "new $protocol/$port rule will be added, existing scope does NOT intersect scope argument:\n" .
					"scope argument: $parsed_scope_argument\n" .
					"existing scope: $parsed_existing_scope\n" .
					"new scope: $new_scope"
				);
			}
		}
	}
	
	my @new_scope_list = split(/,/,$new_scope);
	
	for my $scope_string (@new_scope_list) {
		# Add the new rule to the array of iptables commands
		my $new_rule_command;
		$new_rule_command .= "/sbin/iptables -v -I INPUT 1";
		$new_rule_command .= " -p $protocol";
		$new_rule_command .= " -j ACCEPT";
		$new_rule_command .= " -s $scope_string";
	
		if ($protocol =~ /icmp/i) {
			if ($port ne '255') {
				$new_rule_command .= "  --icmp-type $port";
			}
		}
		else {
			$new_rule_command .= " -m state --state NEW,RELATED,ESTABLISHED";
		
			if ($port =~ /^\d+$/) {
				$new_rule_command .= " -m $protocol --dport $port";
			}
		}
	
		push @commands, $new_rule_command;
	}
	
	# Join the iptables commands together with ' && '
	my $command = join(' && ', @commands);
	
	# Make backup copy of original iptables configuration
	my $iptables_backup_file_path = "/etc/sysconfig/iptables_pre_$protocol-$port";
	if (!$self->copy_file("/etc/sysconfig/iptables", $iptables_backup_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to back up original iptables file to: '$iptables_backup_file_path'");
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "attempting to execute iptables commands on $computer_node_name:\n" . join("\n", @commands));
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined $exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute iptables commands to enable firewall port on $computer_node_name, protocol: $protocol, port: $port, scope: $new_scope");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "enabled firewall port on $computer_node_name, protocol: $protocol, port: $port, scope: $new_scope, command:\n$command");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable firewall port on $computer_node_name, protocol: $protocol, port: $port, scope: $new_scope, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Save rules to /etc/sysconfig/iptables so changes persist across reboots
	$self->save_firewall_configuration();
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_firewall_port
 
 Parameters  : $protocol, $port
 Returns     : boolean
 Description : 
 
=cut

sub disable_firewall_port {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($protocol, $port) = @_;

	# Check to see if this distro has iptables
	# If not return 1 so it does not fail
	if (!($self->service_exists("iptables"))) {
		notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
		return 1;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check the protocol argument
	if (!defined($protocol)) {
		notify($ERRORS{'WARNING'}, 0, "protocol argument was not supplied");
		return;
	}
	elsif ($protocol !~ /^\w+$/i) {
		notify($ERRORS{'WARNING'}, 0, "protocol argument is not valid: '$protocol'");
		return;
	}
	$protocol = lc($protocol);
	
	# Check the port argument
	if (!defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "port argument was not supplied");
		return;
	}
	elsif (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port argument is not valid: '$port'");
		return;
	}
	elsif ($port =~ /^(any|\*)$/) {
		if ($protocol =~ /icmp/i) {
			$port = 255;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "port argument invalid: '$port', protocol argument: '$protocol', port must be an integer");
			return;
		}
	}
	elsif ($port !~ /^\d+$/i) {
		notify($ERRORS{'WARNING'}, 0, "port argument is not valid: '$port'");
		return;
	}
	elsif ($port eq '22') {
		if (!$self->grant_management_node_access()) {
			notify($ERRORS{'WARNING'}, 0, "firewall port not disabled 22 because firewall could not be opened to any port from the management node");
			return;
		}
	}
	
	my $chain = "INPUT";
	my @commands;
	my $new_scope;
	my $existing_scope_string;
	
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	RULE: for my $rule_number (reverse sort keys %{$firewall_configuration->{$chain}}) {
		my $rule = $firewall_configuration->{$chain}{$rule_number};
		
		# Check if the rule matches the protocol and port arguments
		if ($protocol =~ /icmp/i && $port eq 255) {
			if (!defined($rule->{$protocol})) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule $rule_number, protocol is not $protocol:\n" . format_data($rule));
				next;
			}
		}
		elsif (!defined($rule->{$protocol}{$port})) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule $rule_number, does not match protocol/port $protocol/$port:\n" . format_data($rule));
			next RULE;
		}
		else {
			# Only remove if target is 'ACCEPT'
			my $target = $rule->{$protocol}{$port}{target};
			if (!defined($target)) {
				#notify($ERRORS{'WARNING'}, 0, "ignoring rule $rule_number, 'target' is not defined:\n" . format_data($rule));
				next RULE;
			}
			elsif ($target !~ /ACCEPT/i) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule $rule_number, 'target' is not 'ACCEPT':\n" . format_data($rule));
				next RULE;
			}
		}
		
		push @commands, "iptables -D $chain $rule_number";
	}
	
	# If no existing rules were found, nothing needs to be done
	if (!@commands) {
		notify($ERRORS{'DEBUG'}, 0, "firewall port $protocol/$port is not open on $computer_node_name");
		return 1;
	}
	
	# Join the iptables commands together with ' && '
	my $command = join(' && ', @commands);
	#notify($ERRORS{'DEBUG'}, 0, "attempting to execute iptables commands on $computer_node_name:\n" . join("\n", @commands));
	my ($exit_status, $output) = $self->execute($command);
	if (!defined $exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute iptables commands to disable firewall port $protocol/$port on $computer_node_name");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "disabled firewall port $protocol/$port on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable firewall port $protocol/$port on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Save rules to /etc/sysconfig/iptables so changes persist across reboots
	$self->save_firewall_configuration();
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 save_firewall_configuration
 
 Parameters  : none
 Returns     : boolean
 Description : Calls iptables-save to save the current iptables firewall
               configuration to /etc/sysconfig/iptables.
 
=cut

sub save_firewall_configuration {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $iptables_file_path = '/etc/sysconfig/iptables';
	my $command = "/sbin/iptables-save > $iptables_file_path";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined $output) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to save iptables configuration on $computer_node_name:\n$command");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "saved iptables configuration on $computer_node_name: $iptables_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to save iptables configuration on $computer_node_name, exit status: $exit_status, command: $command, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_exclude_list
 
 Parameters  : none
 Returns     : array
 Description : Retrieves /root/.vclcontrol/vcl_exclude_list from the computer
               and constructs an array. Blank lines are ommitted. Spaces at the
               beginning or end of lines are removed.
 
=cut

sub get_exclude_list {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	# Check if previously retrieved
	if (defined($self->{exclude_list_lines})) {
		#notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved exclude list from $computer_name:\n" . join("\n", @{$self->{exclude_list_lines}}));
		return @{$self->{exclude_list_lines}};
	}
	
	my $exclude_file_path = "/root/.vclcontrol/vcl_exclude_list";
	
	if (!$self->file_exists($exclude_file_path)) {
		$self->{exclude_list_lines} = [];
		return ();
	}
	
	# Retrieve the contents of vcl_exclude_list
	my @exclude_lines = $self->get_file_contents($exclude_file_path);
	
	# Check for blank lines and other problems
	my @exclude_lines_cleaned;
	my $exclude_lines_cleaned_string = '';
	for my $exclude_line (@exclude_lines) {
		# Ignore blank lines
		if ($exclude_line !~ /\w/) {
			next;
		}
		
		# Remove leading and trailing spaces
		$exclude_line =~ s/(^\s+|\s+$)//g;
		
		push @exclude_lines_cleaned, $exclude_line;
		$exclude_lines_cleaned_string .= "'$exclude_line'\n";
	}
	
	$self->{exclude_list_lines} = \@exclude_lines_cleaned;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved and parsed $exclude_file_path on $computer_name:\n$exclude_lines_cleaned_string");
	return @exclude_lines_cleaned;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_exclude_regex_list
 
 Parameters  : none
 Returns     : array
 Description : Assembles a regular expression string based on the contents of
               each line in /root/.vclcontrol/vcl_exclude_list on the computer.
               If the file doesn't exist or is empty, an empty array is
               returned.

=cut

sub get_exclude_regex_list {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	# Check if previously retrieved
	if (defined($self->{exclude_regex_list})) {
		#notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved exclude list regex from $computer_name:\n" . join("\n", @{$self->{exclude_regex_list}}));
		return @{$self->{exclude_regex_list}};
	}
	
	# Retrieve exclude_list
	my @exclude_files = $self->get_exclude_list();
	if (!@exclude_files) {
		$self->{exclude_regex_list} = [];
		return ();
	}
	
	my @exclude_regex_list;
	my $exclude_regex_list_string;
	for my $exclude_file (@exclude_files) {
		my $exclude_regex = $exclude_file;
		
		# Add ^ to the beginning, remove any leading spaces
		$exclude_regex =~ s/^[\s\^]*/\^/g;
		
		# Add $ to the end, remove any trailing spaces
		$exclude_regex =~ s/[\s\$]*$/\$/g;
		
		# Escape forward slashes and periods
		$exclude_regex =~ s/\\*([\/\.])/\\$1/g;
		
		# Change asterisk to regex: * --> .*
		$exclude_regex =~ s/\*+/\.\*/g;
		
		push @exclude_regex_list, $exclude_regex;
		$exclude_regex_list_string .= $exclude_regex . "\n";
	}
	chop($exclude_regex_list_string);
	
	$self->{exclude_regex_list} = \@exclude_regex_list;
	
	notify($ERRORS{'DEBUG'}, 0, "assembled regex list from vcl_exclude_list:\n$exclude_regex_list_string");
	return @exclude_regex_list;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_file_in_exclude_list
 
 Parameters  : $file_path
 Returns     : boolean
 Description : Checks if the file matches any lines in
               /root/.vclcontrol/vcl_exclude_list on the computer. If it
               matches, true is returned meaning the file should not be altered.

 
=cut

sub is_file_in_exclude_list {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	my @exclude_regex_list = $self->get_exclude_regex_list();
	return 0 unless @exclude_regex_list;
	
	for my $exclude_regex (@exclude_regex_list) {
		if ($file_path =~ /$exclude_regex/i) {
			my $match = $1;
			notify($ERRORS{'DEBUG'}, 0, "file matches line in vcl_exclude_list:\nfile path: $file_path\nmatching regex: $exclude_regex");
			return 1;
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "file does NOT match any lines in vcl_exclude_list: $file_path");
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_exclude_list_sample
 
 Parameters  : none
 Returns     : boolean
 Description : Generates /root/.vclcontrol/vcl_exclude_list.sample to help image
               creators utilize the file.
 
=cut

sub generate_exclude_list_sample {
	
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $exclude_file_name = "vcl_exclude_list";
	my $exclude_file_path = "/root/.vclcontrol/$exclude_file_name";
	my $sample_file_path  = "/root/.vclcontrol/$exclude_file_name.sample";
	
	my $sample_file_contents = <<"EOF";
When creating an image, you may create a $exclude_file_path file to prevent VCL from altering certain files during the image capture or load processes. Files listed within $exclude_file_name will not be altered. The $exclude_file_name file does not exist by default. You must create it if you wish to utilize this feature. You can specify full, exact file paths or use asterisk characters as wildcards within $exclude_file_name.

Examples:
/root/.ssh/id_rsa
This would only match the file with the exact path:
/root/.ssh/id_rsa

/root/.ssh/id_rsa*
This would match all files in the '/root/.ssh' directory with names beginning with 'id_rsa' including:
/root/.ssh/id_rsa
/root/.ssh/id_rsa.pub

/root/.ssh/id_rsa.*
This would match all files in the '/root/.ssh' directory with names beginning with 'id_rsa.' (including the period) including:
/root/.ssh/id_rsa.pub

In the previous example, '/root/.ssh/id_rsa' would not match because it does not contain a period after 'id_rsa'.
EOF
	
	# Format the string and add comment characters to the beginning of each line
	$sample_file_contents = wrap_string($sample_file_contents, 80, '# ');
	
	return $self->create_text_file($sample_file_path, $sample_file_contents);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_firewall_configuration

 Parameters  : $chain (optional)
 Returns     : hash reference
 Description : Retrieves information about the open firewall ports on the
               computer and constructs a hash. The hash keys are protocol names.
               Each protocol key contains a hash reference. The keys are either
               port numbers or ICMP types.

=cut

sub get_firewall_configuration {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $chain = shift;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check to see if iptables service exists
	if (!($self->service_exists("iptables"))) {
		notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
		return 1;
	}
	
	my $port_command = "iptables --line-number -n -L";
	$port_command .= " $chain" if $chain;
	my ($exit_status, $output) = $self->execute($port_command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to show open firewall ports on $computer_node_name");
		return;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "iptables output:\n" . join("\n", @$output));
	
	# Execute the iptables -L --line-number -n command to retrieve firewall port openings
	# Expected output:
	# Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
	# num  target     prot opt source               destination
	# 1    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
	# 2    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
	# 3    ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0           icmp type 255
	# 4    ACCEPT     esp  --  0.0.0.0/0            0.0.0.0/0
	# 5    ACCEPT     ah   --  0.0.0.0/0            0.0.0.0/0
	# 6    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED
	# 7    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:22
	# 8    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:3389
	# 9    REJECT     all  --  0.0.0.0/0            0.0.0.0/0           reject-with icmp-host-prohibited
	
	my $firewall_configuration = {};
	LINE: for my $line (@$output) {
		if ($line =~ /^Chain\s+(\S+)\s+(.*)/ig) {
			$chain = $1;
			#notify($ERRORS{'DEBUG'}, 0, "processing chain: $chain");
			next LINE;
		}
		
		#                  1       2          3          4      5       6       7
		elsif ($line =~ /^(\d+)\s+([A-Z]*)\s+([a-z]*)\s+(--)\s+(\S+)\s+(\S+)\s+(.*)/ig) {
			my $rule_number      = $1;
			my $target           = $2;
			my $protocol         = $3;
			my $option           = $4;
			my $scope            = $5;
			my $destination      = $6;
			my $other_parameters = $7 || '';
			
			# Check if line was parsed properly
			if (!$destination) {
				next LINE;
			}
			
			# Ignore multiport rules - VCL code does not configure any such rules
			# This can cause the management node to be locked out
			# See https://issues.apache.org/jira/browse/VCL-875
			if ($other_parameters =~ /(multiport|dpts:)/) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring multiport rule: $line");
				next LINE;
			}
			
			my ($state) = $other_parameters =~ /state\s+([\w,]+)/i;
			$state = '' if !defined($state);
			
			my $port;
			if ($protocol =~ /icmp/i) {
				($port) = $other_parameters =~ /icmp\s+type\s+(\d+)/;
				$port = '255' if !defined($port);
			}
			else {
				($port) = $other_parameters =~ /dpt:(\d+)/;
				$port = 'any' if !defined($port);
			}
			
			$firewall_configuration->{$chain}->{$rule_number}{$protocol}{$port} = {
				target => $target,
				scope => $scope,
				destination  => $destination,
				state  => $state,
				port  => $port,
			};
		}
	}
	
	#The below notify statement can produce large amounts of output over time, if needed to debug a reservation, uncomment the line
	#notify($ERRORS{'DEBUG'}, 0, "retrieved firewall configuration from $computer_node_name:\n" . format_data($firewall_configuration));
	return $firewall_configuration;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_firewall_scope

 Parameters  : @scope_strings
 Returns     : string
 Description : Parses an array of firewall scope strings and collpases them into
               a simplified scope if possible. A comma-separated string is
               returned. The scope string argument may be in the form:
                  -192.168.53.54/255.255.255.192
                  -192.168.53.54/24
                  -192.168.53.54
                  -*
                  -Any
                  -LocalSubnet

=cut

sub parse_firewall_scope {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @scope_strings = @_;
	if (!@scope_strings || !defined($scope_strings[0])) {
		notify($ERRORS{'WARNING'}, 0, "scope array argument was not supplied");
		return;
	}
	
	my @netmask_objects;
	
	for my $scope_string (@scope_strings) {
		if (!$scope_string) {
			notify($ERRORS{'WARNING'}, 0, "invalid scope string:\n" . join("\n", @scope_strings));
			return;
		}
		
		if ($scope_string =~ /(\*|Any)/i) {
			my $netmask_object = new Net::Netmask('any');
			push @netmask_objects, $netmask_object;
		}
		
		elsif ($scope_string =~ /LocalSubnet/i) {
			my $network_configuration = $self->get_network_configuration() || return;
			
			for my $interface_name (sort keys %$network_configuration) {
				for my $ip_address (keys %{$network_configuration->{$interface_name}{ip_address}}) {
					my $subnet_mask = $network_configuration->{$interface_name}{ip_address}{$ip_address};
					
					my $netmask_object_1 = new Net::Netmask("$ip_address/$subnet_mask");
					if ($netmask_object_1) {
						push @netmask_objects, $netmask_object_1;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address, subnet mask: $subnet_mask");
						return;
					}
				}
			}
		}
		
		elsif (my @scope_sections = split(/,/, $scope_string)) {
			for my $scope_section (@scope_sections) {
				
				if (my ($start_address, $end_address) = $scope_section =~ /^([\d\.]+)-([\d\.]+)$/) {
					my @netmask_range_objects = Net::Netmask::range2cidrlist($start_address, $end_address);
					if (@netmask_range_objects) {
						push @netmask_objects, @netmask_range_objects;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to call Net::Netmask::range2cidrlist to create an array of objects covering IP range: $start_address-$end_address");
						return;
					}
				}
				
				elsif (my ($ip_address, $subnet_mask) = $scope_section =~ /^([\d\.]+)\/([\d\.]+)$/) {
					my $netmask_object = new Net::Netmask("$ip_address/$subnet_mask");
					if ($netmask_object) {
						push @netmask_objects, $netmask_object;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address, subnet mask: $subnet_mask");
						return;
					}
				}
				
				elsif (($ip_address) = $scope_section =~ /^([\d\.]+)$/) {
					my $netmask_object = new Net::Netmask("$ip_address");
					if ($netmask_object) {
						push @netmask_objects, $netmask_object;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address");
						return;
					}
				}
				
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to parse '$scope_section' section of scope: '$scope_string'");
					return;
				}
			}
		}
		
		else {
			notify($ERRORS{'WARNING'}, 0, "unexpected scope format: '$scope_string'");
			return
		}
	}
	
	my @netmask_objects_collapsed = cidrs2cidrs(@netmask_objects);
	if (@netmask_objects_collapsed) {
		my $scope_result_string;
		my @ip_address_ranges;
		for my $netmask_object (@netmask_objects_collapsed) {
			
			if ($netmask_object->first() eq $netmask_object->last()) {
				push @ip_address_ranges, $netmask_object->first();
				$scope_result_string .= $netmask_object->base() . ",";
			}
			else {
				push @ip_address_ranges, $netmask_object->first() . "-" . $netmask_object->last();
				$scope_result_string .= $netmask_object->base() . "/" . $netmask_object->mask() . ",";
			}
		}
		
		$scope_result_string =~ s/,+$//;
		my $argument_string = join(",", @scope_strings);
		if ($argument_string ne $scope_result_string) {
			#notify($ERRORS{'DEBUG'}, 0, "parsed firewall scope:\n" .
			#	"argument: '$argument_string'\n" .
			#	"result: '$scope_result_string'\n" .
			#	"IP address ranges:\n" . join(", ", @ip_address_ranges)
			#);
		}
		return $scope_result_string;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope: '" . join(",", @scope_strings) . "', no Net::Netmask objects were created");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_iptables

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub clean_iptables {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if iptables service exists
	return 1 unless $self->service_exists("iptables");
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Open SSH port 22 to any address before cleaning existing rules to prevent SSH access from being cut off
	if (!$self->enable_firewall_port("tcp", 22, 'any', 1)) {
		notify($ERRORS{'WARNING'}, 0, "iptables firewall rules not sanitized because SSH port 22 could not be opened from any address");
		return;
	}
	
	my $chain = "INPUT";
	my @commands;
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	RULE: for my $rule_number (reverse sort {$a<=>$b} keys %{$firewall_configuration->{$chain}}) {
		my $rule = $firewall_configuration->{$chain}{$rule_number};
		
		for my $protocol (keys %$rule) {
			for my $port (keys %{$rule->{$protocol}}) {
				my $scope = $rule->{$protocol}{$port}{scope} || '';
				my $target = $rule->{$protocol}{$port}{target} || '';
				my $state = $rule->{$protocol}{$port}{state} || '';
				
				if (!$scope || $scope =~ /0\.0\.0\.0/) {
					#notify($ERRORS{'DEBUG'}, 0, "ignoring rule, scope not specified: protocol/port: $protocol/$port, scope: $scope, target: $target, state: $state");
					next RULE;
				}
				
				notify($ERRORS{'DEBUG'}, 0, "existing iptables rule will be removed: protocol/port: $protocol/$port, scope: $scope, target: $target, state: $state");
				push @commands, "iptables -D $chain $rule_number";
			}
		}
	}
	
	# If no rules were found, nothing needs to be done
	if (!@commands) {
		notify($ERRORS{'DEBUG'}, 0, "no iptables firewall rules need to be cleaned from $computer_node_name");
		return 1;
	}
	
	# Join the iptables commands together with ' && '
	my $command = join(' && ', @commands);
	notify($ERRORS{'DEBUG'}, 0, "attempting to execute commands to sanitize iptables rules on $computer_node_name:\n" . join("\n", @commands));
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined $exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute commands to sanitize iptables rules on $computer_node_name");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "sanitized iptables rules on $computer_node_name, command:\n$command\noutput:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to sanitized iptables rules on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Save rules to /etc/sysconfig/iptables so changes persist across reboots
	$self->save_firewall_configuration();
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 user_logged_in

 Parameters  : $username (optional)
 Returns     : boolean
 Description : Determines if the user is currently logged in to the computer.

=cut

sub user_logged_in {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift || $self->data->get_user_login_id();
	
	my @logged_in_users = $self->get_logged_in_users();
	if (grep { $username eq $_ } @logged_in_users) {
		notify($ERRORS{'DEBUG'}, 0, "$username is logged in to $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$username is NOT logged in to $computer_node_name");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_logged_in_users

 Parameters  : none
 Returns     : array
 Description : Retrieves the names of users logged in to the computer.

=cut

sub get_logged_in_users {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "users";
	my ($exit_status, $output) = $self->execute($command);
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine logged in users on $computer_node_name: $command");
		return;
	}
	elsif (grep(/^users:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine logged in users on $computer_node_name, command: $command, output:\n" . join("\n", @$output));
		return;
	}
	
	my @usernames;
	for my $line (@$output) {
		my @line_usernames = split(/[\s+]/, $line);
		push @usernames, @line_usernames if @line_usernames;
	}
	
	my $username_count = scalar(@usernames);
	if ($username_count) {
		notify($ERRORS{'DEBUG'}, 0, "$username_count user" . ($username_count == 1 ? '' : 's') . " logged in to $computer_node_name: " . join(', ', @usernames));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no users logged in to $computer_node_name");
	}
	return @usernames;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_known_files

 Parameters  : none
 Returns     : boolean
 Description : Clears and deletes files defined for the Linux OS module in the
               $CAPTURE_CLEAR_FILE_PATHS and $CAPTURE_DELETE_FILE_PATHS class
               variables.

=cut

sub clean_known_files {
	my $self = shift;
	if (ref($self) !~ /Linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}	
	
	my $error_count = 0;
	
	# Clear files
	my @class_clear_file_path_array_refs = $self->get_class_variable_hierarchy('CAPTURE_CLEAR_FILE_PATHS');
	for my $class_clear_file_path_array_ref (@class_clear_file_path_array_refs) {
		for my $file_path (@$class_clear_file_path_array_ref) {
			if ($self->is_file_in_exclude_list($file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "file not cleared because it is in the exclude list: $file_path");
				next;
			}
			$self->clear_file($file_path) || $error_count++;
		}
	}
	
	# Delete files
	my @class_delete_file_path_array_refs = $self->get_class_variable_hierarchy('CAPTURE_DELETE_FILE_PATHS');
	for my $class_delete_file_path_array_ref (@class_delete_file_path_array_refs) {
		for my $file_path (@$class_delete_file_path_array_ref) {
			if ($self->is_file_in_exclude_list($file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "file not deleted because it is in the exclude list: $file_path");
				next;
			}
			$self->delete_file($file_path) || $error_count++;
		}
	}
	
	if ($error_count) {
		notify($ERRORS{'WARNING'}, 0, "encountered $error_count error" . ($error_count > 1 ? 's' : '') . " clearing and deleting files");
		return;
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  : $username (optional)
 Returns     : boolean
 Description : 

=cut

sub user_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}
	
	notify($ERRORS{'DEBUG'}, 0, "checking if user exists on $computer_node_name: $username");
	
	# Attempt to query the user account
	my $query_user_command = "id $username";
	my ($query_user_exit_status, $query_user_output) = $self->execute($query_user_command, 0);
	
	if (grep(/uid/, @$query_user_output)) {
		notify($ERRORS{'DEBUG'}, 0, "user exists on $computer_node_name: $username");
		return 1;
	}
	elsif (grep(/No such user/i, @$query_user_output)) {
		notify($ERRORS{'DEBUG'}, 0, "user does not exist on $computer_node_name: $username");
		return 0;
	}
	elsif (defined($query_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if user exists on $computer_node_name: $username, exit status: $query_user_exit_status, output:\n@{$query_user_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if user exists on $computer_node_name: $username");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_external_sshd

 Parameters  : none
 Returns     : boolean
 Description : Kills the external sshd process.

=cut

sub stop_external_sshd {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	$self->stop_service('ext_sshd');
	
	# Run pkill to kill all external sshd processes
	# Exit status may be:
	# 0 - One or more processes matched the criteria.
	# 1 - No processes matched.
	my $pkill_command = "pkill -9 -f ext.*sshd";
	my ($pkill_exit_status, $pkill_output) = $self->execute($pkill_command);
	if (!defined($pkill_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to kill external sshd process on $computer_node_name");
		return;
	}
	elsif ($pkill_exit_status eq '0') {
		notify($ERRORS{'DEBUG'}, 0, "killed external sshd process on $computer_node_name");
	}
	elsif ($pkill_exit_status eq '1') {
		notify($ERRORS{'DEBUG'}, 0, "external sshd process is not running on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to kill external sshd process on $computer_node_name, exit status: $pkill_exit_status, output:\n" . join("\n", @$pkill_output));
		return;
	}
	
	$self->delete_file('/var/run/ext_sshd.pid');
	
	return 1;
} ## end sub stop_external_sshd

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_sshd_config_file

 Parameters  : $custom_parameters (optional), $output_file_path (optional)
 Returns     : boolean
 Description : Configures and generates an output file based
               on the /etc/ssh/sshd_config currently residing on the computer.
               This is used to configure both the sshd_config and
               external_sshd_config files. If no arguments are supplied,
               /etc/ssh/sshd_config is configured to its stock, default state.
               This is done prior to image capture. sshd_config is configured to
               listen on all interfaces.
               
               By default, all of the settings which exist in
               /etc/ssh/sshd_config are retained in the output file except for
               the following:
               StrictModes no
               UseDNS no
               PasswordAuthentication no
               PermitRootLogin without-password
               AllowUsers root
					Banner none
               
               In addition, any ListenAddress lines are not included in the
               output file.
               
               An optional $custom_parameters hash reference argument may be
               supplied. The key/values in this hash will result in the values
               being set in the output file. If a parameter is included with an
               empty value in the hash reference, all lines containing that
               parameter will be removed from the the resulting output file.
               Example:
               $self->configure_sshd_config_file({
                  ListenAddress =>'10.10.0.33',
                  AllowUsers => '',
               });
               
               The output file will be /etc/ssh/sshd_config since the 2nd
               argument was not specified. This file will be based off itself
               except a ListenAddress line will be added and all AllowUsers
               lines will be omitted.

=cut

sub configure_sshd_config_file {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my ($custom_parameters, $output_file_path) = @_;
	
	my $sshd_config_file_path = '/etc/ssh/sshd_config';
	
	# If output file path argument wasn't specified, write back to sshd_config
	$output_file_path = $sshd_config_file_path if !$output_file_path;
	
	# Check if the output file is in the exclude list before proceeding
	my @exclude_list = $self->get_exclude_list();
	if (@exclude_list && grep(m|$output_file_path|, @exclude_list)) {
		notify($ERRORS{'OK'}, 0, "skipping reconfiguration of $output_file_path because it is in the exclude file list");
		return 1;
	}
	
	# Get the contents of the sshd_config file already on the computer
	my @sshd_config_file_lines = $self->get_file_contents($sshd_config_file_path);
	if (!@sshd_config_file_lines) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $sshd_config_file_path from $computer_node_name");
		return;
	}
	
	# Add the following parameters to the end of the sshd_config file
	# Any existing lines containing these parameters will be discarded
	my $parameters = {
		StrictModes => 'no',
		UseDNS => 'no',
		PasswordAuthentication => 'no',
		PermitRootLogin => 'without-password',
		AllowUsers => 'root',
		ListenAddress => '',
		Banner => 'none',
	};
	
	if ($custom_parameters) {
		$parameters = {%$parameters, %$custom_parameters};
	}
	notify($ERRORS{'DEBUG'}, 0, "generating sshd config file: $output_file_path, custom parameters:\n" . format_data($parameters));
	
	my $custom_tag = 'VCL Settings';
	
	# Loop through the lines from the existing sshd_config file
	my $output_file_contents;
	LINE: for my $line (@sshd_config_file_lines) {
		# Ignore lines already in the file which will be added later with custom values
		if ((map { $line =~ /$_/ } ($custom_tag, keys %$parameters))) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring line in $sshd_config_file_path: '$line'");
			next LINE;
		}
		$output_file_contents .= "$line\n";
	}
	
	# Remove extra blank lines from the end of the file
	$output_file_contents =~ s/[\s\n]*$//gs;
	
	# Add each of the custom parameters to the file
	$output_file_contents .= "\n\n#" . ('-' x 20) . " $custom_tag " . ('-' x 20) . "\n";
	for my $custom_parameter (sort keys %$parameters) {
		my $custom_value = $parameters->{$custom_parameter};
		
		# Add the custom parameter of the value is set
		if (defined($custom_value) && length($custom_value) > 0) {
			$output_file_contents .= "$custom_parameter $custom_value\n";
		}
	}
	
	if (!$self->create_text_file($output_file_path, $output_file_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create file on $computer_node_name: $output_file_path");
		return;
	}
	
	if (!$self->set_file_permissions($output_file_path, '600')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set permissions of $output_file_path on $computer_node_name");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_ext_sshd_config_file

 Parameters  : none
 Returns     : boolean
 Description : Generates /etc/ssh/external_sshd_config based off of
               /etc/ssh/sshd_config currently residing on the computer with the
               following parameters overridden:
               PidFile /var/run/ext_sshd.pid
               PermitRootLogin no
               X11Forwarding yes
               PasswordAuthentication yes
               AllowUsers 
               ListenAddress => <public IP aaddress>

=cut

sub configure_ext_sshd_config_file {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $ext_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	
	my $public_ip_address = $self->get_public_ip_address();
	if (!$public_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "failed to generate $ext_sshd_config_file_path on $computer_node_name, public IP address could not be determined");
		return;
	}
	
	my $custom_ext_sshd_parameters = {
		PidFile => '/var/run/ext_sshd.pid',
		PermitRootLogin => 'no',
		X11Forwarding => 'yes',
		PasswordAuthentication => 'yes',
		AllowUsers => '',
		ListenAddress => $public_ip_address,
	};
	
	return $self->configure_sshd_config_file($custom_ext_sshd_parameters, $ext_sshd_config_file_path);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_default_sshd

 Parameters  : none
 Returns     : boolean
 Description : Configures the sshd daemon back to a mostly default state.
               Removes the ext_sshd service from the computer. Reconfigures
               sshd to listen on all interfaces. Restarts sshd.
               
               This is called prior to image
               capture. The purpose is to configure the captured image so that
               it responds to SSH after it is loaded from any interface.

=cut

sub configure_default_sshd {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	if (!$self->service_exists('sshd')) {
		notify($ERRORS{'DEBUG'}, 0, "skipping default sshd configuation, sshd service does not exist");
		return 1;
	}
	
	# Stop existing external sshd process if it is running
	if (!$self->stop_external_sshd()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure default sshd state, problem occurred attempting to kill external sshd process");
		return;
	}
	
	# Delete the ext_sshd service
	$self->delete_service('ext_sshd') || return;
	
	# Delete the external sshd configuration file
	$self->delete_file('/etc/ssh/ext*ssh*');
	
	# Reconfigure sshd_config back to its default state
	$self->configure_sshd_config_file() || return;
	
	# Restart the sshd service
	$self->restart_service('sshd') || return;
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_ext_sshd

 Parameters  : none
 Returns     : boolean
 Description : Adds the external_sshd_config file configured to listen on the
               public network and adds the ext_sshd service to the computer.
               Reconfigures the existing sshd service to only listen on the
               private network and restarts sshd. Stops the ext_sshd service if
               it is started.

=cut

sub configure_ext_sshd {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, failed to retrieve private IP address of $computer_node_name, necessary to configure sshd to only listen on private network");
		return;
	}
	
	if (!$self->service_exists('sshd')) {
		notify($ERRORS{'DEBUG'}, 0, "skipping ext_sshd configuation, sshd service does not exist");
		return 1;
	}
	
	# Recreate the sshd_config file, set ListenAddress to the private IP address
	if (!$self->configure_sshd_config_file({ListenAddress => $private_ip_address})) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, failed to reconfigure sshd_config to only listen on private network on $computer_node_name");
		return;
	}
	
	# Restart sshd to enact the changes
	if (!$self->restart_service('sshd')) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, failed to restart sshd on $computer_node_name after reconfiguring sshd_config to only listen on private network");
		return;
	}

	# Create and configure the ext_sshd service
	if (!$self->configure_ext_sshd_config_file()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, failed to configure external_sshd_config file on $computer_node_name");
		return;
	}
	
	# Deterine which init module is currently controlling sshd, use the same module to control ext_sshd
	my ($init_module_index) = $self->service_exists('sshd');
	if (!defined($init_module_index)) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, init module controlling sshd could not be determined");
		return;
	}
	
	my $init_module = ($self->get_init_modules())[$init_module_index];
	
	# Delete the cached service name array
	delete $init_module->{service_names};
	delete $self->{service_init_module}{ext_sshd};
	
	# Add the ext_sshd service
	if (!$init_module->add_ext_sshd_service()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure ext_sshd, failed to add the ext_sshd service to $computer_node_name");
		return;
	}
	
	# Stop ext_sshd if it is running
	$self->stop_service('ext_sshd');
	
	notify($ERRORS{'OK'}, 0, "configured ext_sshd on $computer_node_name");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 configure_rc_local

 Parameters  : none
 Returns     : boolean
 Description : Checks if /etc/rc.local was configured by a previous version of
               VCL. If so, returns file to its default state. Previous versions
               of VCL had been adding commands to rc.local to configure
               networking. This is now done by this backend code.

=cut

sub configure_rc_local {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	
	# Check if rc.local is in the exclude list before proceeding
	my @exclude_list = $self->get_exclude_list();
	if (@exclude_list && grep(m|rc.local|, @exclude_list)) {
		notify($ERRORS{'OK'}, 0, "skipping reconfiguration of rc.local because it is in the exclude file list");
		return 1;
	}
	
	my $rc_local_contents = <<EOF;
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.

touch /var/lock/subsys/local
EOF

	for my $rc_local_file_path ('/etc/rc.d/rc.local', '/etc/rc.local') {
		# Check if the file exists or else get_file_contents will complain
		if (!$self->file_exists($rc_local_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "skipping $rc_local_file_path reconfiguration, file does not exist on $computer_node_name");
			next;
		}
		
		my @rc_local_lines = $self->get_file_contents($rc_local_file_path);
		if (!@rc_local_lines) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $rc_local_file_path on $computer_node_name");
			next;
		}
		elsif (!grep(/ListenAddress \$IP0/, @rc_local_lines)) {
			notify($ERRORS{'DEBUG'}, 0, "skipping $rc_local_file_path reconfiguration, it does not appear to be configured by a previous version of VCL");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$rc_local_file_path will be returned to its default state, it appears to have been configured by a previous version of VCL");
		}
		
		if (!$self->create_text_file($rc_local_file_path, $rc_local_contents)) {
			return;
		}
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 command_exists

 Parameters  : $shell_command
 Returns     : boolean
 Description : Determines if a shell command exists on the computer by executing
               'which <command>'.

=cut

sub command_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $shell_command = shift;
	if (!$shell_command) {
		notify($ERRORS{'WARNING'}, 0, "shell command argument was not supplied");
		return;
	}
	
	if ($self->{command_exists}{$shell_command}) {
		return 1;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "which $shell_command";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if the '$shell_command' shell command exists on $computer_node_name");
		return;
	}
	elsif (my ($command_line) = grep(/\/$shell_command$/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "verified '$shell_command' command exists on $computer_node_name: $command_line");
		$self->{command_exists}{$shell_command} = 1;
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'$shell_command' command does NOT exist on $computer_node_name, command: $command\noutput:\n" . join("\n", @$output));
		$self->{command_exists}{$shell_command} = 0;
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 notify_user_console

 Parameters  : message, username(optional)
 Returns     : boolean
 Description : Send a message to the user on the console

=cut

sub notify_user_console {
	my $self = shift;
	if (ref($self) !~ /Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $message = shift;
	if (!$message) {
		notify($ERRORS{'WARNING'}, 0, "message argument was not supplied");
		return;
	}

	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	my $cmd = "echo $message \| write $username";
	my ($exit_status, $output) = $self->execute($cmd, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if the '$cmd' shell command exists on $computer_node_name");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "executed command to determine if the '$cmd' shell command exists on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_64_bit

 Parameters  : none
 Returns     : boolean
 Description : Determines if the OS is 64-bit or not.

=cut

sub is_64_bit {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = 'uname -m';
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute '$command' command to determine if $computer_node_name contains a 64-bit Linux OS");
		return;
	}
	elsif (grep(/uname:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if $computer_node_name contains a 64-bit Linux OS, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/64/, @$output)) {
		#notify($ERRORS{'DEBUG'}, 0, "$computer_node_name contains a 64-bit Linux OS, output:\n" . join("\n", @$output));
		return 1;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "$computer_node_name does NOT contain a 64-bit Linux OS, output:\n" . join("\n", @$output));
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_user_remote_ip_addresses

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves info regarding users connected to the computer. A hash
               reference is returned. The hash keys are the usernames logged in.
               The value of each username key is an array reference containing
               the remote IP addresses that user is connected from. Example:
                  {
                    "admin" => [
                      "152.1.1.1"
                    ],
                    "root" => [
                      "10.1.1.1"
                    ]
                  }

=cut

sub get_user_remote_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $who_command = 'who -u';
	my ($who_exit_status, $who_output) = $self->execute($who_command, 0);
	if (!defined($who_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute '$who_command' command to determine users connected to $computer_node_name");
		return;
	}
	elsif (grep(/who:/, @$who_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine users connected to $computer_node_name, exit status: $who_exit_status, command: '$who_command', output:\n" . join("\n", @$who_output));
		return;
	}
	
	my $connected_user_info = {};
	for my $line (@$who_output) {
		# NAME     LINE         TIME             IDLE          PID COMMENT
		# root     pts/0        2014-03-12 11:32   .          5403 (10.1.0.1)
		# admin    pts/1        2014-03-11 13:34 22:01        4336 (152.1.1.1)
		
		my ($username, $remote_ip) = $line =~ /^([^\s]+).+\(([\d\.]+)\)/;
		if ($username && $remote_ip) {
			if (!defined($connected_user_info->{$username})) {
				$connected_user_info->{$username} = [];
			}
			push @{$connected_user_info->{$username}}, $remote_ip;
		}
	}
	
	if ($connected_user_info) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved user connection info using the 'who' command from $computer_node_name:\n" . format_data($connected_user_info));
		return $connected_user_info;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "did not detect any users connected to $computer_node_name using the 'who' command, attempting to call 'last'");
	}
	
	my $last_command = 'last';
	my ($last_exit_status, $last_output) = $self->execute($last_command, 0);
	if (!defined($last_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute '$last_command' command to determine users connected to $computer_node_name");
		return;
	}
	elsif (grep(/last:/, @$last_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine users connected to $computer_node_name, exit status: $last_exit_status, command: '$last_command', output:\n" . join("\n", @$last_output));
		return;
	}
	
	for my $line (@$last_output) {
		# root     pts/0        10.1.0.1      Wed Mar 12 11:32   still logged in
		# admin    pts/1        152.1.1.1     Tue Mar 11 13:34   still logged in
		# root     pts/0        10.1.0.1      Tue Mar 11 13:23 - 10:47  (21:24)
		
		my ($username, $remote_ip) = $line =~ /^([^\s]+).+[\s\t](\d+\.\d+\.\d+\.\d+)[\s\t].*logged\s+in/i;
		if ($username && $remote_ip) {
			if (!defined($connected_user_info->{$username})) {
				$connected_user_info->{$username} = [];
			}
			push @{$connected_user_info->{$username}}, $remote_ip;
		}
	}
	
	if ($connected_user_info) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved user connection info using the 'last' command from $computer_node_name:\n" . format_data($connected_user_info));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "did not detect any users connected to $computer_node_name");
	}
	return $connected_user_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_port_connection_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about established connections from the
               computer. A hash is constructed:
               {
                 "tcp" => {
                   22 => [
                     {
                       "local_ip" => "10.25.10.194",
                       "pid" => 5400,
                       "program" => "sshd",
                       "remote_ip" => "10.25.0.241"
                     },
                     {
                       "local_ip" => "192.168.18.135",
                       "pid" => 5689,
                       "program" => "sshd",
                       "remote_ip" => "192.168.53.54"
                     },
                   ],
                   3389 => [
                     {
                       "local_ip" => "192.168.18.135",
                       "pid" => 6767,
                       "program" => "xrdp",
                       "remote_ip" => "192.168.53.54"
                     }
                   ]
                 }
               }

=cut

sub get_port_connection_info {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "netstat -anp";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command: $command");
		return;
	}
	elsif (grep(/^netstat: /, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred executing command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	my $connection_info = {};
	for my $line (@$output) {
		# Proto Recv-Q Send-Q Local Address      Foreign Address     State        PID/Program name
		# tcp        0      0 192.168.13.220:22  152.1.1.100:63497   ESTABLISHED  6199/sshd
		# tcp        0      0 10.10.3.220:22     10.10.14.13:52239   ESTABLISHED  5189/sshd
		my ($protocol, $local_ip_address, $port, $remote_ip_address, $state, $pid, $program) = $line =~ /^(\w+).+\s([\d\.]+):(\d+)\s+([\d\.]+):\d*\s+(\w+)\s+(\d+)?\/?(\w+)?/i;
		if (!$state || $state !~ /ESTABLISHED/i) {
			next;
		}
		
		my $connection = {
			remote_ip => $remote_ip_address,
			local_ip => $local_ip_address,
		};
		$connection->{pid} = $pid if $pid;
		$connection->{program} = $program if $program;
		
		push @{$connection_info->{$protocol}{$port}}, $connection;
	}
	
	if ($connection_info) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved connection info from $computer_node_name:\n" . format_data($connection_info));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "did not detect any connections on $computer_node_name");
	}
	return $connection_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_ip_forwarding

 Parameters  : none
 Returns     : boolean
 Description : Enables IP forwarding by executing:
               echo 1 > /proc/sys/net/ipv4/ip_forward

=cut

sub enable_ip_forwarding {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "echo 1 > /proc/sys/net/ipv4/ip_forward";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to enable IP forwarding on $computer_node_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to enable IP forwarding on $computer_node_name, command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "verified IP forwarding is enabled on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 should_set_user_password

 Parameters  : $user_id
 Returns     : boolean
 Description : Determines whether or not a user account's password should be set
               on the computer being loaded. The "STANDALONE" flag is used to
               determine this.

=cut

sub should_set_user_password {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_id) = shift;
	if (!$user_id) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not supplied");
		return;
	}
	
	my $user_info = get_user_info($user_id);
	if (!$user_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if user password should be set, user info could not be retrieved for user ID $user_id");
		return;
	}
	
	my $user_standalone = $user_info->{STANDALONE};
	
	# Generate a reservation password if "standalone" (not using Kerberos authentication)
	if ($user_standalone) {
		return 1;
	}
	else {
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_connect_method_access

 Parameters  : user login id 
 Returns     : boolean
 Description : Edits the external_sshd_config. 
 					TODO - in next release pull this out into connect method modules.

=cut

sub grant_connect_method_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $user_parameters = shift;

	if (!$user_parameters) {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, user parameters argument was not provided");
		return;
	}
	elsif (!ref($user_parameters) || ref($user_parameters) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, argument provided is not a hash reference");
		return;
	}

	my $username = $user_parameters->{username};
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'username' key:\n" . format_data($user_parameters));
		return;
	}

	my $uid = $user_parameters->{uid};
	if (!defined($uid)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'uid' key:\n" . format_data($user_parameters));
		return;
	}

	my $ssh_public_keys = $user_parameters->{ssh_public_keys};
	if (!defined($ssh_public_keys)) {
		notify($ERRORS{'OK'}, 0, "argument hash does not contain a 'ssh_public_keys' key:\n" . format_data($user_parameters));
	}

	my $home_directory_root = "/home";
	my $home_directory_path = "$home_directory_root/$username";
	my $home_directory_on_local_disk = $self->is_file_on_local_disk($home_directory_root);
	# Add user's public ssh identity keys if exists
	if ($ssh_public_keys) {
		my $ssh_directory_path = "$home_directory_path/.ssh";
		my $authorized_keys_file_path = "$ssh_directory_path/authorized_keys";
		
		# Determine if home directory is on a local device or network share
		# Only add keys to home directories that are local,
		# Don't add keys to network mounted filesystems
		if ($home_directory_on_local_disk) {
			# Create the .ssh directory
			$self->create_directory($ssh_directory_path);
			
			if ($self->append_text_file($authorized_keys_file_path, "$ssh_public_keys\n")) {
				notify($ERRORS{'DEBUG'}, 0, "added user's public SSH keys to $authorized_keys_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to add user's public SSH keys to $authorized_keys_file_path");
			}

			if (!$self->set_file_owner($home_directory_path, $username, 'vcl', 1)) {
				notify($ERRORS{'WARNING'}, 0, "failed to set owner of user's home directory: $home_directory_path");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "user's public SSH keys not added to $authorized_keys_file_path, home directory is on a network share");
		}
	}


	# Append AllowUsers line to the end of the file
	my $external_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	my $allow_users_line = "AllowUsers $username";
	if ($self->append_text_file($external_sshd_config_file_path, $allow_users_line)) {
		notify($ERRORS{'DEBUG'}, 0, "added line to $external_sshd_config_file_path: '$allow_users_line'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add line to $external_sshd_config_file_path: '$allow_users_line'");
		return;
	}
	
	$self->restart_service('ext_sshd') || return;

	# If ssh_public_keys add to authorized_keys

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 kill_process

 Parameters  : $pid, $signal (optional)
 Returns     : boolean
 Description : Kills a process on the computer.

=cut

sub kill_process {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($pid_argument, $signal) = @_;
	if (!defined($pid_argument)) {
		notify($ERRORS{'WARNING'}, 0, "PID argument was not specified");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Suicide prevention
	if ($pid_argument eq $PID) {
		notify($ERRORS{'WARNING'}, 0, "process $pid_argument not killed, it is the currently running process");
		return;
	}
	
	$signal = '9' unless defined $signal;
	$signal =~ s/^-+//g;
	
	my $command = "kill -$signal $pid_argument";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to kill process $pid_argument on $computer_node_name");
		return;
	}
	elsif ($exit_status == 1 || grep(/no such process/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "process $pid_argument not running on $computer_node_name");
		return 1;
	}
	elsif ($exit_status != 0 || grep(/^kill:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to kill process $pid_argument with signal $signal on $computer_node_name, command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "killed process $pid_argument with signal $signal on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_process_running

 Parameters  : $process_regex
 Returns     : array or hash reference
 Description : Determines if any processes matching the $process_regex
               argument are running on the computer. The $process_regex must be
               a valid Perl regular expression.
               
               The following command is used to determine if a process is
               running:
               ps -e -o pid,args | grep -P "$process_regex"
               
               The behavior is different than if the -P argument is not used.
               The following characters must be escaped with a backslash in
               order for a literal match to be found:
               | ( ) [ ] . +
               
               If these are not escaped, grep will interpret them as the
               corresponing regular expression operational character. For
               example:
               
               To match this literal string:
               |(foo)|
               Pass this:
               \|\(foo\)\|
               
               To match 'foo' or 'bar, pass this:
               (foo|bar)
               
               To match a pipe character ('|'), followed by either 'foo' or
               'bar, followed by another pipe character:
               |foo|
               Pass this:
               \|(foo|bar)\|
               
               The return value differs based on how this subroutine is called.
               If called in scalar context, a hash reference is returned. The
               hash keys are PIDs and the values are the full name of the
               process. If called in list context, an array is returned
               containing the PIDs.

=cut

sub is_process_running {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check the arguments
	my ($process_regex) = @_;
	if (!defined($process_regex)) {
		notify($ERRORS{'WARNING'}, 0, "process regex pattern argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command = "ps -e -o pid,args | grep -P \"$process_regex\"";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name to determine if process is running: $command");
		return;
	}
	
	my $processes_running = {};
	for my $line (@$output) {
		my ($pid, $process_name) = $line =~ /^\s*(\d+)\s*(.*[^\s])\s*/g;
		
		if (!defined($pid)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring line, it does not begin with a number: '$line'");
			next;
		}
		elsif ($pid eq $PID) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring line for the currently running process: $line");
			next;
		}
		elsif ($line =~ /grep -P/) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring line containing for this command: $line");
			next;
		}
		elsif ($line =~ /sh -c/) {
			# Ignore lines containing 'sh -c', probably indicating a duplicate process of a command run remotely
			#notify($ERRORS{'DEBUG'}, 0, "ignoring containing 'sh -c': $line");
			next;
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "found matching process: $line");
			$processes_running->{$pid} = $process_name;
		}
	}
	
	my $process_count = scalar(keys %$processes_running);
	if ($process_count) {
		if (wantarray) {
			my @process_ids = sort keys %$processes_running;
			notify($ERRORS{'DEBUG'}, 0, "process is running on $computer_name, identifier: '$process_regex', returning array containing PIDs: @process_ids");
			return @process_ids;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "process is running on $computer_name, identifier: '$process_regex', returning hash reference:\n" . format_data($processes_running));
			return $processes_running;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "process is NOT running on $computer_name, identifier: '$process_regex', command: $command");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_display_manager_running

 Parameters  : none
 Returns     : boolean
 Description : Checks if a display manager (GUI) is running on the computer.

=cut

sub is_display_manager_running {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Note: runlevel isn't reliable for all distros
	# On Ubuntu, it displays 2 even if the GUI is running
	
	my $process_pattern;
	
	# CentOS "Welcome" screen
	#  1700 /usr/bin/Xorg :9 -ac -nolisten tcp vt6 -br
	
	# ' 416 lightdm'
	# '2955 lightdm --session-child 12 21'
	$process_pattern .= '^\s*\d+\s+(kdm|lightdm)(\s|$)';
	
	# Gnome
	# 1870 /usr/sbin/gdm-binary -nodaemon
	# 1898 /usr/libexec/gdm-simple-slave --display-id /org/gnome/DisplayManager/Display1
	# 1901 /usr/bin/Xorg :0 -br -verbose -audit 4 -auth /var/run/gdm/auth-for-gdm-laIZj5/database -nolisten tcp vt1
	# 1989 /usr/bin/gnome-session --autostart=/usr/share/gdm/autostart/LoginWindow/
	$process_pattern .= '|(gnome-session|gdm-binary)';
	
	# ' 2891 /usr/bin/X -core :0 -seat seat0 -auth /var/run/lightdm/root/:0 -nolisten tcp vt7 -novtswitch'
	$process_pattern .= '|bin\/X';
	
	$process_pattern = "($process_pattern)";
	
	my $process_info = $self->is_process_running($process_pattern);
	if ($process_info) {
		notify($ERRORS{'DEBUG'}, 0, "display manager is running on $computer_name:\n" . format_data($process_info));
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "display manager is not running on $computer_name");
		return 0
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_ssh_private_key_file

 Parameters  : $private_key_file_path, $type (optional), $bits (optional), $comment (optional), $passphrase, $options (optional)
 Returns     : boolean
 Description : Calls ssh-keygen or dropbearkey to generate an SSH private key
               file.

=cut

sub generate_ssh_private_key_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($private_key_file_path, $type, $bits, $comment, $passphrase, $options) = @_;
	if (!$private_key_file_path) {
		notify($ERRORS{'WARNING'}, 0, "private key file path argument was not specified");
		return;
	}
	$type = 'rsa' unless $type;
	$passphrase = '' unless $passphrase;
	
	if (defined($comment)) {
		$comment =~ s/\\*(["])/\\"$1/g;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure the file does not already exist
	if ($self->file_exists($private_key_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to generate SSH key, file already exists on $computer_name: $private_key_file_path");
		return;
	}
	
	if ($self->command_exists('ssh-keygen')) {
		if ($self->_generate_ssh_private_key_file_helper($private_key_file_path, $type, $bits, $comment, $passphrase, $options, 'ssh-keygen')) {
			return 1;
		}
	}
	if ($self->command_exists('dropbearkey')) {
		if ($self->_generate_ssh_private_key_file_helper($private_key_file_path, $type, $bits, $comment, $passphrase, $options, 'dropbearkey')) {
			return 1;
		}
	}
	
	if (ref($self) =~ /ManagementNode/) {
		notify($ERRORS{'WARNING'}, 0, "failed to generate SSH key on $computer_name: $private_key_file_path");
		return;
	}
	
	my $mn_temp_file_path = mktemp($computer_name . 'XXXXXX');
	notify($ERRORS{'DEBUG'}, 0, "attempting to create SSH private key file on this management node ($mn_temp_file_path) and copy it to $computer_name ($private_key_file_path)");
	my $result = $self->mn_os->generate_ssh_private_key_file($mn_temp_file_path, $type, $bits, $comment, $passphrase, $options);
	if (!$result) {
		notify($ERRORS{'WARNING'}, 0, "failed to create SSH private key file on this management node and copy it to $private_key_file_path on $computer_name");
		$self->mn_os->delete_file($mn_temp_file_path);
		return;
	}
	
	if (!$self->copy_file_to($mn_temp_file_path, $private_key_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "create SSH private key file on this management node but failed to copy it to $private_key_file_path on $computer_name");
		$self->mn_os->delete_file($mn_temp_file_path);
		return;
	}
	else {
		$self->mn_os->delete_file($mn_temp_file_path);
		notify($ERRORS{'OK'}, 0, "created SSH private key file on this management and copied it to $private_key_file_path on $computer_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _generate_ssh_private_key_file_helper

 Parameters  : $private_key_file_path, $type, $bits, $comment, $passphrase, $options, $utility
 Returns     : boolean
 Description : Calls ssh-keygen to generate an SSH private key file.

=cut

sub _generate_ssh_private_key_file_helper {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($private_key_file_path, $type, $bits, $comment, $passphrase, $options, $utility) = @_;
	if (!defined($utility)) {
		notify($ERRORS{'WARNING'}, 0, "utility argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command;
	if ($utility eq 'ssh-keygen') {
		$command = "ssh-keygen -t $type -f \"$private_key_file_path\" -N \"$passphrase\"";
		$command .= " -b $bits" if (defined($bits) && length($bits));
		$command .= " $options" if (defined($options) && length($options));
		$command .= " -C \"$comment\"" if (defined($comment) && length($comment));
	}
	elsif ($utility eq 'dropbearkey') {
		$command = "dropbearkey -t $type -f \"$private_key_file_path\"";
		$command .= " -s $bits" if (defined($bits) && length($bits));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "invalid utility argument provided: '$utility', it must either be 'ssh-keygen' or 'dropbearkey'");
		return;
	}
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to generate SSH key using $utility on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to generate SSH key using $utility on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "generated SSH key using $utility on $computer_name: $private_key_file_path, command: $command");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_ssh_public_key_file

 Parameters  : $private_key_file_path, $public_key_file_path, $comment (optional)
 Returns     : boolean
 Description : Calls ssh-keygen to retrieve the corresponding SSH public key
               from a private key file and generates a file containing the
               public key.

=cut

sub generate_ssh_public_key_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($private_key_file_path, $public_key_file_path, $comment) = @_;
	if (!$private_key_file_path) {
		notify($ERRORS{'WARNING'}, 0, "private key file path argument was not specified");
		return;
	}
	if (!$public_key_file_path) {
		notify($ERRORS{'WARNING'}, 0, "public key file path argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure the private key file exists
	if (!$self->file_exists($private_key_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to generate SSH public key file, private key file does not exist on $computer_name: $private_key_file_path");
		return;
	}
	
	# Make sure the public key file does not exist
	if ($self->file_exists($public_key_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create SSH public key file, public key file already exists on $computer_name: $public_key_file_path");
		return;
	}
	
	my $public_key_string = $self->get_ssh_public_key_string($private_key_file_path, $comment);
	if (!$public_key_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to create SSH public key file: $public_key_file_path, public key string could not be retrieved from private key file: $private_key_file_path");
		return;
	}
	
	if ($self->create_text_file($public_key_file_path, $public_key_string)) {
		notify($ERRORS{'DEBUG'}, 0, "created SSH public key file: $public_key_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create SSH public key file: $public_key_file_path");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_ssh_public_key_string

 Parameters  : $private_key_file_path, $comment (optional)
 Returns     : boolean
 Description : Extracts the SSH public key from a private key file.

=cut

sub get_ssh_public_key_string {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($private_key_file_path, $comment) = @_;
	if (!$private_key_file_path) {
		notify($ERRORS{'WARNING'}, 0, "private key file path argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure the private key file exists
	if (!$self->file_exists($private_key_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve SSH public key, private key file does not exist on $computer_name: $private_key_file_path");
		return;
	}
	
	my $public_key_string;
	if ($self->command_exists('ssh-keygen')) {
		$public_key_string = $self->_get_ssh_public_key_string_helper($private_key_file_path, 'ssh-keygen');
	}
	if (!$public_key_string && $self->command_exists('dropbearkey')) {
		$public_key_string = $self->_get_ssh_public_key_string_helper($private_key_file_path, 'dropbearkey');
	}
	if ($public_key_string) {
		#if ($comment) {
		#	$public_key_string =~ s/(ssh-[^\s]+\s[^\s=]+).*$/$1 $comment/g;
		#}
		return $public_key_string;
	}
	
	if (ref($self) =~ /ManagementNode/) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve SSH public key from private key file on $computer_name: $private_key_file_path");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "attempting to copy SSH private key file $private_key_file_path from $computer_name and extract the public key on this management node");
	}
	
	my ($mn_temp_file_handle, $mn_temp_file_path) = tempfile(SUFFIX => '.key', UNLINK => 1);
	if (!$self->copy_file_from($private_key_file_path, $mn_temp_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve SSH public key from private key file on $computer_name: $private_key_file_path, failed to copy temp file to management node");
		$self->mn_os->delete_file($mn_temp_file_path);
		return;
	}
	$self->mn_os->set_file_permissions($mn_temp_file_path, '0400');
	
	$public_key_string = $self->mn_os->get_ssh_public_key_string($mn_temp_file_path, $comment);
	$self->mn_os->delete_file($mn_temp_file_path);
	return $public_key_string;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_ssh_public_key_string_helper

 Parameters  : $private_key_file_path, $utility
 Returns     : boolean
 Description : 

=cut

sub _get_ssh_public_key_string_helper {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($private_key_file_path, $utility) = @_;
	if (!$private_key_file_path) {
		notify($ERRORS{'WARNING'}, 0, "private key file path argument was not specified");
		return;
	}
	elsif (!$utility) {
		notify($ERRORS{'WARNING'}, 0, "utility argument (ssh-keygen or dropbearkey) was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command;
	if ($utility eq 'ssh-keygen') {
		$command = "ssh-keygen -y -f \"$private_key_file_path\"";
	}
	elsif ($utility eq 'dropbearkey') {
		$command = "/bin/dropbearkey -f \"$private_key_file_path\" -y";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "invalid utility argument provided: '$utility', it must either be 'ssh-keygen' or 'dropbearkey'");
		return;
	}
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve SSH public key string using $utility from $private_key_file_path on $computer_name");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve SSH public key string using $utility from $private_key_file_path on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my ($ssh_public_key_string) = grep(/^ssh-.*/, @$output);
	if ($ssh_public_key_string) {
		notify($ERRORS{'OK'}, 0, "retrieved SSH public key string using $utility from $private_key_file_path on $computer_name:\n$ssh_public_key_string");
		return $ssh_public_key_string;
	}
	else {
		notify($ERRORS{'OK'}, 0, "failed to retrieved SSH public key string using $utility from $private_key_file_path on $computer_name, output does not contain a line beginning with 'ssh-', command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 install_package

 Parameters  : $package_name, $timeout_seconds (optional)
 Returns     : boolean
 Description : Installs a Linux package using yum.

=cut

sub install_package {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($package_name, $timeout_seconds) = @_;
	if (!$package_name) {
		notify($ERRORS{'WARNING'}, 0, "package name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	if (!$self->command_exists('yum')) {
		notify($ERRORS{'WARNING'}, 0, "failed to install $package_name on $computer_name, yum command is not available");
		return;
	}
	
	$timeout_seconds = 120 unless $timeout_seconds;
	
	my $command = "yum install -q -y $package_name";
	notify($ERRORS{'DEBUG'}, 0, "attempting to install $package_name using yum on $computer_name, timeout seconds: $timeout_seconds");
	my ($exit_status, $output) = $self->execute({
		'command' => $command,
		'display_output' => 0,
		'timeout_seconds' => $timeout_seconds,
	});
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to install $package_name using yum on $computer_name");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to install $package_name using yum on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return 0;
	}
	elsif (grep(/$package_name.+already installed/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "$package_name is already installed on $computer_name, command: '$command', output:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "installed $package_name using yum on $computer_name, command: '$command', output:\n" . join("\n", @$output));
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 mount_nfs_share

 Parameters  : $remote_nfs_share, $local_mount_directory, $options
 Returns     : boolean
 Description : Mounts an NFS share on the computer. The $remote_nfs_share
               argument must be in the for used by the mount command:
               <hostname|IP>:/path-to-share
               
               The $local_mount_directory argument must specify a directory.
               This directory will be created if it does not already exist.
               
               The $options argument allows NFS mount options to be specified
               such as:
               rsize=1048576,wsize=1048576,vers=3
               
               The $options string must be formatted correctly and is passed
               directly to the mount command.

=cut

sub mount_nfs_share {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($remote_nfs_share, $local_mount_directory, $options, $is_retry_attempt) = @_;
	if (!defined($remote_nfs_share)) {
		notify($ERRORS{'WARNING'}, 0, "remote target argument was not supplied");
		return;
	}
	elsif (!defined($local_mount_directory)) {
		notify($ERRORS{'WARNING'}, 0, "local directory path argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	# Try to repair NFS client if 1st attempt failed
	if ($is_retry_attempt) {
		# Check if nfs-utils is installed, if not, try to install it
		# Error looks like this if nfs-utils is not installed:
		#    mount: wrong fs type, bad option, bad superblock on 10.1.2.3:/nfs,
		#    missing codepage or helper program, or other error
		#    (for several filesystems (e.g. nfs, cifs) you might
		#    need a /sbin/mount.<type> helper program)
		#    In some cases useful info is found in syslog - try
		#    dmesg | tail  or so
		if (!$self->command_exists('mount.nfs')) {
			$self->install_package('nfs-utils');
		}
		
		# Check if the rpcbind service exists, if not, try to install it
		# Mount may fail if rpcbind service is not installed and running:
		#    mount.nfs: rpc.statd is not running but is required for remote locking.
		#    mount.nfs: Either use '-o nolock' to keep locks local, or start statd.
		#    mount.nfs: an incorrect mount option was specified
		if (!$self->service_exists('rpcbind')) {
			$self->install_package('rpcbind');
		}
		
		# Try to start the service
		$self->start_service('rpcbind');
	}
	else {
		# Create the local mount point directory if it does not exist
		if (!$self->create_directory($local_mount_directory)) {
			notify($ERRORS{'WARNING'}, 0, "unable to mount $remote_nfs_share on $computer_name, failed to create directory: $local_mount_directory");
			return;
		}
	}
	
	my $mount_command = "mount -t nfs $remote_nfs_share \"$local_mount_directory\" -v";
	if ($options) {
		$mount_command .= " -o $options";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to mount NFS share on $computer_name: $mount_command");
	my ($mount_exit_status, $mount_output) = $self->execute({
		command => $mount_command,
		timeout_seconds => 10,
		max_attempts => 2,
	});
	if (!defined($mount_exit_status)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to execute command to mount NFS share on $computer_name: $mount_command");
		return;
	}
	elsif ($mount_exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "mounted NFS share on $computer_name: $remote_nfs_share --> $local_mount_directory");
		return 1;
	}
	elsif (grep(/already mounted/, @$mount_output)) {
		# mount.nfs: /mnt/mymountpoint is busy or already mounted
		if ($self->is_nfs_share_mounted($remote_nfs_share, $local_mount_directory)) {
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to mount NFS share on $computer_name: $remote_nfs_share --> $local_mount_directory, mount command output indicates 'already mounted' but failed to verify mount in /proc/mounts, mount command: '$mount_command', exit status: $mount_exit_status, mount output:\n" . join("\n", @$mount_output));
			return;
		}
	}
	elsif (grep(/(Invalid argument|incorrect mount option|Usage:)/, @$mount_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to mount NFS share on $computer_name: $remote_nfs_share --> $local_mount_directory, command: '$mount_command', exit status: $mount_exit_status, output:\n" . join("\n", @$mount_output));
		return;
	}
	else {
		if ($is_retry_attempt) {
			notify($ERRORS{'WARNING'}, 0, "failed to mount NFS share on $computer_name on 2nd attempt: $remote_nfs_share --> $local_mount_directory, command: '$mount_command', exit status: $mount_exit_status, output:\n" . join("\n", @$mount_output));
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to mount NFS share on $computer_name on 1st attempt: $remote_nfs_share --> $local_mount_directory, command: '$mount_command', exit status: $mount_exit_status, output:\n" . join("\n", @$mount_output));
			
			# Try to mount the NFS share again, set retry flag to avoid endless loop
			return $self->mount_nfs_share($remote_nfs_share, $local_mount_directory, $options, 1);
		}
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 unmount_nfs_share

 Parameters  : $local_mount_directory
 Returns     : boolean
 Description : Unmounts an NFS share on the computer.

=cut

sub unmount_nfs_share {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($local_mount_directory) = @_;
	if (!defined($local_mount_directory)) {
		notify($ERRORS{'WARNING'}, 0, "local directory path argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $umount_command = "umount -v \"$local_mount_directory\" -v";
	my ($umount_exit_status, $umount_output) = $self->execute({
		command => $umount_command,
		timeout_seconds => 30,
		max_attempts => 2,
	});
	if (!defined($umount_exit_status)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to execute command to umount NFS share on $computer_name: $umount_command");
		return;
	}
	elsif ($umount_exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "unmounted NFS share on $computer_name: $local_mount_directory, output:\n" . join("\n", @$umount_output));
		return 1;
	}
	elsif (grep(/not mounted/, @$umount_output)) {
		notify($ERRORS{'OK'}, 0, "NFS share is not mounted on $computer_name: $local_mount_directory");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to unmount NFS share on $computer_name: $local_mount_directory, command: '$umount_command', exit status: $umount_exit_status, output:\n" . join("\n", @$umount_output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_nfs_share_mounted

 Parameters  : $remote_nfs_share, $local_mount_directory
 Returns     : boolean
 Description : Checks if an NFS share is mounted on the computer matching both
               the remote NFS share path and local mount point directory
               arguments.

=cut

sub is_nfs_share_mounted {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($remote_nfs_share, $local_mount_directory) = @_;
	if (!defined($remote_nfs_share)) {
		notify($ERRORS{'WARNING'}, 0, "remote target argument was not supplied");
		return;
	}
	elsif (!defined($local_mount_directory)) {
		notify($ERRORS{'WARNING'}, 0, "local directory path argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	if ($self->get_nfs_mount_string($remote_nfs_share, $local_mount_directory)) {
		notify($ERRORS{'DEBUG'}, 0, "NFS share is mounted on $computer_name: $remote_nfs_share --> $local_mount_directory");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "NFS share is NOT mounted on $computer_name: $remote_nfs_share --> $local_mount_directory");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_nfs_mount_string

 Parameters  : $remote_nfs_share, $local_mount_directory
 Returns     : string
 Description : Examines the contents of /proc/mounts and attempts to locate a
               line matching the arguments. If found, the line is returned which
               may be used in /etc/fstab. If not found, 0 is returned. Undefined
               is returned if an error occurs.

=cut

sub get_nfs_mount_string {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($remote_nfs_share, $local_mount_directory) = @_;
	if (!defined($remote_nfs_share)) {
		notify($ERRORS{'WARNING'}, 0, "remote target argument was not supplied");
		return;
	}
	elsif (!defined($local_mount_directory)) {
		notify($ERRORS{'WARNING'}, 0, "local directory path argument was not supplied");
		return;
	}
	
	# Remove trailing slashes for consistent comparison
	$remote_nfs_share =~ s/\/+$//;
	$local_mount_directory =~ s/\/+$//;
	
	# If the NFS share or local directory contain a space, the octal value will appear in /proc/mounts
	$remote_nfs_share =~ s/ /\\\\040/g;
	$local_mount_directory =~ s/ /\\\\040/g;
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $command = "cat /proc/mounts | grep ' nfs'";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	
	for my $line (@$output) {
		if ($line =~ m|^$remote_nfs_share\/?\s+$local_mount_directory\/?\s|) {
			notify($ERRORS{'DEBUG'}, 0, "found NFS share line in /proc/mounts on $computer_name: $remote_nfs_share --> $local_mount_directory\n$line");
			return $line;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "/proc/mounts on $computer_name does NOT contain a line matching NFS share: $remote_nfs_share --> $local_mount_directory\n" . join("\n", @$output));
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 add_fstab_nfs_mount

 Parameters  : $remote_nfs_share, $local_mount_directory
 Returns     : boolean
 Description : Adds a line to /etc/fstab for an existing NFS mount. The share
               must be mounted prior to calling this subroutine.

=cut

sub add_fstab_nfs_mount {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($remote_nfs_share, $local_mount_directory) = @_;
	if (!defined($remote_nfs_share)) {
		notify($ERRORS{'WARNING'}, 0, "remote target argument was not supplied");
		return;
	}
	elsif (!defined($local_mount_directory)) {
		notify($ERRORS{'WARNING'}, 0, "local directory path argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $nfs_mount_string = $self->get_nfs_mount_string($remote_nfs_share, $local_mount_directory);
	if (!$nfs_mount_string) {
		notify($ERRORS{'WARNING'}, 0, "unable to add NFS mount line to /etc/fstab, NFS share is not mounted: $remote_nfs_share --> $local_mount_directory");
		return;
	}
	
	# Remove existing line matching the local mount directory followed by "nfs" to avoid duplicate lines
	$self->remove_matching_fstab_lines("$local_mount_directory nfs");
	
	my @fstab_lines = $self->get_file_contents('/etc/fstab');
	push @fstab_lines, $nfs_mount_string;
	my $new_fstab_contents = join("\n", @fstab_lines);
	
	my $timestamp = POSIX::strftime("%Y-%m-%d_%H-%M-%S\n", localtime);
	$self->copy_file('/etc/fstab', "/tmp/fstab.$timestamp");
	
	if ($self->create_text_file('/etc/fstab', $new_fstab_contents)) {
		notify($ERRORS{'OK'}, 0, "added line to /etc/fstab on $computer_name:\n$nfs_mount_string");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add line to /etc/fstab on $computer_name:\n$nfs_mount_string");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_matching_fstab_lines

 Parameters  : $regex_pattern
 Returns     : boolean
 Description : Removes all lines from /etc/fstab matching the pattern.

=cut

sub remove_matching_fstab_lines {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($regex_pattern) = @_;
	if (!defined($regex_pattern)) {
		notify($ERRORS{'WARNING'}, 0, "pattern argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $updated_fstab_contents;
	
	my @matching_lines;
	my @fstab_lines = $self->get_file_contents('/etc/fstab');
	for my $fstab_line (@fstab_lines) {
		(my $fstab_line_cleaned = $fstab_line) =~ s/\\040/ /g;
		
		if ($fstab_line =~ m|$regex_pattern| || $fstab_line_cleaned =~ m|$regex_pattern|) {
			push @matching_lines, $fstab_line;
			notify($ERRORS{'DEBUG'}, 0, "removing line in /etc/fstab matching pattern: $regex_pattern\n$fstab_line");
			next;
		}
		$updated_fstab_contents .= "$fstab_line\n";
	}
	
	if (!@matching_lines) {
		notify($ERRORS{'DEBUG'}, 0, "/etc/fstab does not contain any lines matching pattern: $regex_pattern");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "removing " . scalar(@matching_lines) . " lines from /etc/fstab on $computer_name:\n" . join("\n", @matching_lines));
	
	# Save a backup
	my $timestamp = POSIX::strftime("%Y-%m-%d_%H-%M-%S\n", localtime);
	$self->copy_file('/etc/fstab', "/tmp/fstab.$timestamp");
	
	return $self->create_text_file('/etc/fstab', $updated_fstab_contents);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_resolv_conf

 Parameters  : none
 Returns     : boolean
 Description : Updates /etc/resolv.conf on the computer. Existing nameserver
               lines are removed and new nameserver lines are added based on the
               public DNS servers configured for the management node.

=cut

sub update_resolv_conf {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	my $public_ip_configuration = $self->data->get_management_node_public_ip_configuration();
	my @public_dns_servers = $self->data->get_management_node_public_dns_servers();
	
	if ($public_ip_configuration !~ /static/i) {	
		notify($ERRORS{'WARNING'}, 0, "unable to update resolv.conf on $computer_name, management node's IP configuration is set to $public_ip_configuration");
		return;
	}
	elsif (!@public_dns_servers) {
		notify($ERRORS{'WARNING'}, 0, "unable to update resolv.conf on $computer_name, management node's public DNS server is not configured");
		return;
	}
	
	my $resolv_conf_path = "/etc/resolv.conf";
	
	my @resolv_conf_lines_existing = $self->get_file_contents($resolv_conf_path);
	my @resolv_conf_lines_new;
	for my $line (@resolv_conf_lines_existing) {
		if ($line =~ /\sVCL/) {
			last;
		}
		elsif ($line !~ /^\s*nameserver/) {
			push @resolv_conf_lines_new, $line;
		}
	}
	
	# Add a comment marking what was added by VCL
	my $timestamp = POSIX::strftime("%m-%d-%Y %H:%M:%S", localtime);
	push @resolv_conf_lines_new, "# $timestamp: The following was added by VCL";
	
	# Add a nameserver line for each configured DNS server
	for my $public_dns_server (@public_dns_servers) {
		push @resolv_conf_lines_new, "nameserver $public_dns_server";
	}
	
	my $resolv_conf_contents_new = join("\n", @resolv_conf_lines_new);
	return $self->create_text_file($resolv_conf_path, $resolv_conf_contents_new);
}

##/////////////////////////////////////////////////////////////////////////////
1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
