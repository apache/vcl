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

VCL::Module::OS::Ubuntu.pm - VCL module to support Ubuntu operating systems

=head1 DESCRIPTION

 This module provides VCL support for Ubuntu operating systems.

=cut

###############################################################################
package VCL::Module::OS::Linux::Ubuntu;

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
no warnings 'redefine';

use VCL::utils;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on the management node of the files specific to this OS
               module which are needed to configure the loaded OS on a computer.
               This is normally the directory under 'tools' named after this OS
               module.
               
               Example:
               /usr/local/vcl/tools/Ubuntu

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Ubuntu";

=head2 @CAPTURE_DELETE_FILE_PATHS

 Data type   : Array
 Description : List of files to be deleted during the image capture process.

=cut

our $CAPTURE_DELETE_FILE_PATHS = [
	'/etc/network/interfaces.20*',	# Delete backups VCL makes of /etc/network/interfaces
];

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $command = "echo $username:$password | chpasswd";
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $no_cache = shift;
	
	# Delete previously retrieved data if $no_cache was specified
	delete $self->{network_configuration} if $no_cache;
	
	# Check if the network configuration has already been retrieved and saved in this object
	return $self->{network_configuration} if ($self->{network_configuration});
	
	# Run ipconfig
	my $ifconfig_command = "/sbin/ifconfig -a";
	my ($ifconfig_exit_status, $ifconfig_output) = $self->execute($ifconfig_command);
	if (!defined($ifconfig_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve network configuration: $ifconfig_command");
		return;
	}
	
	# Loop through the ifconfig output lines
	my $network_configuration;
	my $interface_name;
	for my $ifconfig_line (@$ifconfig_output) {
		# Extract the interface name from the Link line:
		# eth2      Link encap:Ethernet  HWaddr 00:0C:29:78:77:AB
		if ($ifconfig_line =~ /^([^\s]+).*Link/) {
			$interface_name = $1;
			$network_configuration->{$interface_name}{name} = $interface_name;
		}
		
		# Skip to the next line if the interface name has not been determined yet
		next if !$interface_name;
		
		# Parse the HWaddr line:
		# eth2      Link encap:Ethernet  HWaddr 00:0C:29:78:77:AB
		if ($ifconfig_line =~ /HWaddr\s+([\w:]+)/) {
			$network_configuration->{$interface_name}{physical_address} = lc($1);
		}
		
	# Parse the IP address line:
		# inet addr:10.10.4.35  Bcast:10.10.15.255  Mask:255.255.240.0
		if ($ifconfig_line =~ /inet addr:([\d\.]+)\s+Bcast:([\d\.]+)\s+Mask:([\d\.]+)/) {
			$network_configuration->{$interface_name}{ip_address}{$1} = $3;
			$network_configuration->{$interface_name}{broadcast_address} = $2;
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
			notify($ERRORS{'DEBUG'}, 0, "route output line does not contain a default gateway: '$route_line'");
		}
		elsif (!defined($network_configuration->{$interface_name})) {
			notify($ERRORS{'WARNING'}, 0, "found default gateway for '$interface_name' interface but the network configuration for '$interface_name' was not previously retrieved, route output:\n" . join("\n", @$route_output) . "\nnetwork configuation:\n" . format_data($network_configuration));
		}
		elsif (defined($network_configuration->{$interface_name}{default_gateway})) {
			notify($ERRORS{'WARNING'}, 0, "multiple default gateway are configured for '$interface_name' interface, route output:\n" . join("\n", @$route_output));
		}
		else {
			$network_configuration->{$interface_name}{default_gateway} = $default_gateway;
			notify($ERRORS{'DEBUG'}, 0, "found default route configured for '$interface_name' interface: $default_gateway");
		}
	}
	
	$self->{network_configuration} = $network_configuration;
	#can produce large output, if you need to monitor the configuration setting uncomment the below output statement
	#notify($ERRORS{'DEBUG'}, 0, "retrieved network configuration:\n" . format_data($self->{network_configuration}));
	return $self->{network_configuration};
		
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_dhcp

 Parameters  : none
 Returns     : boolean
 Description : Configures /etc/network/interfaces file so that DHCP is enabled
               for the public interface.

=cut

sub enable_dhcp {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	
	my $private_interface_name = $self->get_private_interface_name();
	my $public_interface_name = $self->get_public_interface_name();
	
	# Get the current interfaces file contents
	my $interfaces_file_path = '/etc/network/interfaces';
	my @interfaces_lines_original = $self->get_file_contents($interfaces_file_path);
	if (!@interfaces_lines_original) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable DHCP on $computer_name, contents of $interfaces_file_path could not be retrieved");
		return;
	}
	my $interfaces_contents_original = join("\n", @interfaces_lines_original);
	
	# Make a backup of the file
	my $timestamp = POSIX::strftime("%Y-%m-%d_%H-%M-%S", localtime);
	$self->copy_file($interfaces_file_path, "$interfaces_file_path.$timestamp");
	
	
	my @stanza_types = (
		'iface',
		'mapping',
		'auto',
		'allow-',
		'source',
	);
	
	my @interfaces_lines_new;
	my $in_iface_stanza = 0;
	my $iface_stanza_type;
	
	for my $line (@interfaces_lines_original) {
		# Never add hwaddress lines
		if ($line =~ /^\s*(hwaddress)/) {
			notify($ERRORS{'DEBUG'}, 0, "not including hwaddress line: $line");
			next;
		}
		
		if ($line =~ /^\s*iface\s+($private_interface_name|$public_interface_name)\s+(\w+)/) {
			my $matching_interface_name = $1;
			my $address_family = $2;
			$in_iface_stanza = 1;
			$iface_stanza_type = ($matching_interface_name eq $private_interface_name ? 'private' : 'public');
			notify($ERRORS{'DEBUG'}, 0, "found beginning of $iface_stanza_type iface stanza: $line");
			push @interfaces_lines_new, "iface $matching_interface_name $address_family dhcp";
		}
		elsif ($in_iface_stanza) {
			my ($stanza_type) = grep { $line =~ /^\s*$_/ } @stanza_types;
			if ($stanza_type) {
				$in_iface_stanza = 0;
				notify($ERRORS{'DEBUG'}, 0, "found end of $iface_stanza_type iface stanza, line begins new stanza: $line");
				
				# Add line which begins next stanza
				push @interfaces_lines_new, $line;
			}
			else {
				# Check if line should be added or ignored
				if ($line =~ /^\s*(address|netmask|broadcast|gateway|pointopoint)/) {
					my $match = $1;
					notify($ERRORS{'DEBUG'}, 0, "not including '$match' line from $iface_stanza_type iface stanza: $line");
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "including line from $iface_stanza_type iface stanza: $line");
					push @interfaces_lines_new, $line;
				}
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "line is not part of public or private iface stanza: $line");
			push @interfaces_lines_new, $line;
		}
	}
	my $interfaces_contents_new = join("\n", @interfaces_lines_new);
	
	# Check if the interfaces content changed, update file if necessary
	if ($interfaces_contents_new eq $interfaces_contents_original) {
		notify($ERRORS{'OK'}, 0, "update of $interfaces_file_path on $computer_name not necessary, $interfaces_file_path not changed:\n$interfaces_contents_new");
	}
	elsif ($self->create_text_file($interfaces_file_path, $interfaces_contents_new)) {
		notify($ERRORS{'OK'}, 0, "updated $interfaces_file_path to enable public DHCP on $computer_name\n" .
			"original:\n$interfaces_contents_original\n" .
			"---\n" .
			"current:\n$interfaces_contents_new"
		);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update $interfaces_file_path to enable public DHCP on $computer_name");
		return;
	}

	delete $self->{network_configuration};
	
	notify($ERRORS{'DEBUG'}, 0, "enabled public DHCP on $computer_name");
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 set_static_public_address

 Parameters  : none
 Returns     : boolean
 Description : Configures the public interface with a static IP address.

=cut

sub set_static_public_address {
	my $self = shift;
	if (ref($self) !~ /ubuntu/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name           = $self->data->get_computer_short_name();
	my $public_ip_configuration = $self->data->get_management_node_public_ip_configuration();
	my $public_ip_address       = $self->data->get_computer_public_ip_address();
	my $public_subnet_mask      = $self->data->get_management_node_public_subnet_mask();
	my @public_dns_servers      = $self->data->get_management_node_public_dns_servers();
	
	my $public_default_gateway  = $self->get_correct_default_gateway();
	
	my $server_request_fixed_ip = $self->data->get_server_request_fixed_ip();
	if ($server_request_fixed_ip) {
		$public_ip_address = $server_request_fixed_ip;
		$public_subnet_mask     = $self->data->get_server_request_netmask();
		$public_default_gateway = $self->data->get_server_request_router();
		@public_dns_servers     = $self->data->get_server_request_dns_servers();
		
		if (!$public_subnet_mask) {
			notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address to $public_ip_address on $computer_name, server request fixed IP is set but server request subnet mask could not be retrieved");
			return;
		}
		elsif (!@public_dns_servers) {
			notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address to $public_ip_address on $computer_name, server request fixed IP is set but server request DNS servers could not be retrieved");
			return;
		}
	}
	else {
		if ($public_ip_configuration !~ /static/i) {	
			notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address to $public_ip_address on $computer_name, management node's IP configuration is set to $public_ip_configuration");
			return;
		}
	}
	
	# Get the public interface name
	my $public_interface_name = $self->get_public_interface_name();
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to set static public IP address to $public_ip_address on $computer_name, failed to determine public interface name");
		return;
	}
	
	# Stop the interface in case it is already assigned the static IP otherwise ping will respond
	$self->stop_network_interface($public_interface_name);
	
	# Attempt to ping the public IP address to make sure it's available
	if (_pingnode($public_ip_address)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to set static public IP address to $public_ip_address on $computer_name, IP address is pingable");
		return;
	}
	
	# Get the current interfaces file contents
	my $interfaces_file_path = '/etc/network/interfaces';
	my @interfaces_lines_original = $self->get_file_contents($interfaces_file_path);
	if (!@interfaces_lines_original) {
		notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address to $public_ip_address on $computer_name, $interfaces_file_path contents could not be retrieved");
		return;
	}
	my $interfaces_contents_original = join("\n", @interfaces_lines_original);
	notify($ERRORS{'DEBUG'}, 0, "retreived contents of '$interfaces_file_path' from $computer_name:\n$interfaces_contents_original");
	
	# Make a backup of the file
	my $timestamp = POSIX::strftime("%Y-%m-%d_%H-%M-%S", localtime);
	$self->copy_file($interfaces_file_path, "$interfaces_file_path.$timestamp");
	
	# Examples:
	# auto eth0
	# iface eth0 inet dhcp
	
	# auto br1
	# iface br1 inet dhcp
	#    bridge_ports eth1
	#    bridge_stp off
	#    bridge_fd 0
	
	# iface eth1 inet static
	#    address 192.168.1.1
	#    netmask 255.255.255.0
	
	my @stanza_types = (
		'iface',
		'mapping',
		'auto',
		'allow-',
		'source',
	);
	
	my @interfaces_lines_new;
	my $in_public_iface_stanza = 0;
	
	my @lines_to_add = (
		"   address $public_ip_address",
		"   netmask $public_subnet_mask",
		"   gateway $public_default_gateway",
	);
	
	for my $line (@interfaces_lines_original) {
		
		if ($line =~ /^\s*iface\s+$public_interface_name\s+(\w+)/) {
			my $address_family = $1;
			$in_public_iface_stanza = 1;
			notify($ERRORS{'DEBUG'}, 0, "found beginning of public iface stanza: $line");
			push @interfaces_lines_new, "iface $public_interface_name $address_family static";
			
			# Add static IP information
			push @interfaces_lines_new, @lines_to_add;
			notify($ERRORS{'DEBUG'}, 0, "adding lines:\n" . join("\n", @lines_to_add));
		}
		elsif ($in_public_iface_stanza) {
			my ($stanza_type) = grep { $line =~ /^\s*$_/ } @stanza_types;
			if ($stanza_type) {
				$in_public_iface_stanza = 0;
				notify($ERRORS{'DEBUG'}, 0, "found end of public iface stanza, line begins new stanza: $line");
				
				# Add line which begins next stanza
				push @interfaces_lines_new, $line;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "line in public iface stanza: $line");
				
				# Check if line should be added or ignored
				if ($line =~ /^\s*(bridge|bond|vlan)/) {
					my $match = $1;
					notify($ERRORS{'DEBUG'}, 0, "including '$match' line from public iface stanza: $line");
					push @interfaces_lines_new, $line;
				}
				else {
					notify($ERRORS{'DEBUG'}, 0, "not including line from public iface stanza: $line");
				}
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "line is not part of public iface stanza: $line");
			push @interfaces_lines_new, $line;
		}
	}
	my $interfaces_contents_new = join("\n", @interfaces_lines_new);
	
	
	# Check if the interfaces content changed, update file if necessary
	if ($interfaces_contents_new eq $interfaces_contents_original) {
		notify($ERRORS{'OK'}, 0, "update of $interfaces_file_path on $computer_name not necessary, $interfaces_file_path not changed:\n$interfaces_contents_new");
	}
	elsif ($self->create_text_file($interfaces_file_path, $interfaces_contents_new)) {
		notify($ERRORS{'OK'}, 0, "updated $interfaces_file_path to set static public IP address to $public_ip_address on $computer_name\n" .
			"original:\n$interfaces_contents_original\n" .
			"---\n" .
			"new:\n$interfaces_contents_new"
		);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update $interfaces_file_path to set static public IP address to $public_ip_address on $computer_name");
		return;
	}
	
	# Restart the public interface
	if (!$self->restart_network_interface($public_interface_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address to $public_ip_address on $computer_name, failed to restart public interface $public_interface_name");
		return;
	}
	
	# Set the default gateway
	if (!$self->set_static_default_gateway()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address to $public_ip_address on $computer_name, failed to set the default gateway");
		return;
	}
	
	# Update resolv.conf
	if (!$self->update_resolv_conf()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address to $public_ip_address on $computer_name, failed to update resolv.conf");
		return;
	}
	
	# Delete cached network configuration info - forces next call to get_network_configuration to retrieve changed network info from computer
	delete $self->{network_configuration};
	
	notify($ERRORS{'DEBUG'}, 0, "set static public IP address to $public_ip_address on $computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 activate_interfaces

 Parameters  : 
 Returns     :
 Description : 

=cut

sub activate_interfaces {
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Notes (ARK): Ubuntu 14+ seems to have issues hibernating. The machine's
	# console may turn into a black screen with a blinking cursor if the GUI
	# isn't running and SSH access may become unavailable. I haven't found a way
	# to recover from this when it happens without a hard reset.

	my $computer_name = $self->data->get_computer_node_name();
	
	# Make sure pm-hibernate command exists
	if (!$self->command_exists('pm-hibernate')) {
		if (!$self->install_package('pm-utils')) {
			notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_name, pm-hibernate command does not exist and pm-utils could not be installed");
			return;
		}
	}
	
	# Ubuntu seems to have problems hibernating if a display manager isn't running
	# If it is not running, attempt to install and start lightdm
	if (!$self->is_display_manager_running()) {
		#if (!$self->install_package('xfce4')) {
		#	notify($ERRORS{'WARNING'}, 0, "hibernation of $computer_name not attempted, display manager/GUI is not running, failed to install xfce4");
		#	return;
		#}
		if (!$self->install_package('lightdm')) {
			notify($ERRORS{'WARNING'}, 0, "hibernation of $computer_name not attempted, display manager/GUI is not running, failed to install xfce4");
			return;
		}
		if (!$self->start_service('lightdm')) {
			notify($ERRORS{'WARNING'}, 0, "hibernation of $computer_name not attempted, display manager/GUI is not running, failed to start lightdm service");
			return;
		}
		if (!$self->is_display_manager_running()) {
			notify($ERRORS{'WARNING'}, 0, "hibernation of $computer_name not attempted, unable to verify display manager/GUI is running, hibernate may fail to shut down the computer unless GUI is running");
			return;
		}
	}
	
	# Delete old log files
	$self->delete_file('/var/log/pm-*');
	
	# Try to determine if NetworkManager or network service is being used
	my $network_service_name = 'network';
	if ($self->service_exists('network-manager')) {
		$network_service_name = 'network-manager';
	}
	
	my $private_interface_name = $self->get_private_interface_name() || 'eth0';
	my $public_interface_name = $self->get_public_interface_name() || 'eth1';
	
	# Some versions of Ubuntu fail to respond after resuming from hibernation
	# Networking is up but not responding
	# Add script to restart networking service
	my $fix_network_script_path = '/etc/pm/sleep.d/50_restart_networking';
	my $fix_network_log_path = '/var/log/50_restart_networking.log';
	
	$self->delete_file($fix_network_log_path);
	
	my $fix_network_script_contents = <<"EOF";
#!/bin/sh
echo >> /var/log/50_restart_networking.log
date -R >> /var/log/50_restart_networking.log
echo "\$1: begin" >> /var/log/50_restart_networking.log

case "\$1" in
   hibernate)
      ifdown $private_interface_name 2>&1 >> /var/log/50_restart_networking.log
      ifdown $public_interface_name 2>&1 >> /var/log/50_restart_networking.log
      initctl stop $network_service_name 2>&1 >> /var/log/50_restart_networking.log
      modprobe -r vmxnet3 2>&1 >> /var/log/50_restart_networking.log
      ;;
   thaw)
      modprobe vmxnet3 2>&1 >> /var/log/50_restart_networking.log
      initctl restart $network_service_name 2>&1 >> /var/log/50_restart_networking.log
      ifup $private_interface_name 2>&1 >> /var/log/50_restart_networking.log
      ifup $public_interface_name 2>&1 >> /var/log/50_restart_networking.log
      ;;
esac

echo "\$1: done" >> $fix_network_log_path
date -R >> /var/log/50_restart_networking.log
EOF
	if (!$self->create_text_file($fix_network_script_path, $fix_network_script_contents)) {
		notify($ERRORS{'WARNING'}, 0, "hibernate not attempted, failed to create $fix_network_script_path on $computer_name in order to prevent networking problems after computer is powered back on");
		return;
	}
	if (!$self->set_file_permissions($fix_network_script_path, '755')) {
		notify($ERRORS{'WARNING'}, 0, "hibernate not attempted, failed to set file permissions on $fix_network_script_path on $computer_name, networking problems may occur after computer is powered back on");
		return;
	}
	
	# Make sure the grubenv recordfail flag is not set
	if (!$self->unset_grubenv_recordfail()) {
		notify($ERRORS{'WARNING'}, 0, "hibernate not attempted, failed to unset grubenv recordfail flag, computer may hang on grub boot screen after it is powered back on");
		return;
	}
	
	my $command = 'pm-hibernate';
	#$command .= ' --quirk-dpms-on' 				if ($computer_name =~ /32$/);
	#$command .= ' --quirk-dpms-suspend' 		if ($computer_name =~ /33$/);
	#$command .= ' --quirk-radeon-off' 			if ($computer_name =~ /34$/);
	#$command .= ' --quirk-s3-bios' 				if ($computer_name =~ /35$/);
	#$command .= ' --quirk-s3-mode' 				if ($computer_name =~ /36$/);
	#$command .= ' --quirk-vbe-post' 				if ($computer_name =~ /37$/);
	#$command .= ' --quirk-vbemode-restore' 	if ($computer_name =~ /38$/);
	#$command .= ' --quirk-vbestate-restore' 	if ($computer_name =~ /39$/);
	#$command .= ' --quirk-vga-mode-3' 			if ($computer_name =~ /40$/);
	#$command .= ' --quirk-save-pci' 				if ($computer_name =~ /41$/);
	#$command .= ' --store-quirks-as-lkw' 		if ($computer_name =~ /42$/);
	$command .= ' &';
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to hibernate $computer_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "executed command to hibernate $computer_name: $command" . (scalar(@$output) ? "\noutput:\n" . join("\n", @$output) : ''));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Wait for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(300, 5);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_name from provisioning module, sleeping 1 minute to allow computer time to hibernate");
		sleep 60;
		return 1;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name never powered off after executing hibernate command: $command");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name powered off after executing hibernate command");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 grubenv_unset_recordfail

 Parameters  : none
 Returns     : boolean
 Description : Unsets the grub "recordfail" flag. If this is set, the computer
               may hang at the grub boot screen when rebooted.

=cut

sub unset_grubenv_recordfail {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	if (!$self->command_exists('grub-editenv')) {
		return 1;
	}
	
	my $command = "grub-editenv /boot/grub/grubenv unset recordfail";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to unset grubenv recordfail on $computer_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "unset grubenv recordfail on $computer_name, command: '$command'" . (scalar(@$output) ? "\noutput:\n" . join("\n", @$output) : ''));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to unset grubenv recordfail on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_package

 Parameters  : $package_name
 Returns     : boolean
 Description : Installs a Linux package using apt-get.

=cut

sub install_package {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($package_name) = @_;
	if (!$package_name) {
		notify($ERRORS{'WARNING'}, 0, "package name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	# Delete service info in case package adds a service that was previously detected as not existing
	$self->_delete_cached_service_info();
	
	# Run apt-get update before installing package - only do this once
	$self->apt_get_update();
	
	# Some packages are known to cause debconf database errors
	# Check if package being installed will also install/update a package with known problems
	# Attempt to fix the debconf database if any are found
	my @simulate_lines = $self->simulate_install_package($package_name);
	if (@simulate_lines) {
		my @problematic_packages = grep { $_ =~ /(dictionaries-common)/; $_ = $1; } @simulate_lines;
		if (@problematic_packages) {
			@problematic_packages = remove_array_duplicates(@problematic_packages);
			notify($ERRORS{'DEBUG'}, 0, "installing $package_name requires the following packages to be installed which are known to have problems with the debconf database, attempting to fix the debconf database first:\n" . join("\n", @problematic_packages));
			for my $problematic_package (@problematic_packages) {
				$self->fix_debconf_db();
				$self->_install_package_helper($problematic_package);
			}
			$self->fix_debconf_db();
		}
	}
	
	my $attempt = 0;
	my $attempt_limit = 2;
	for (my $attempt = 1; $attempt <= $attempt_limit; $attempt++) {
		my $attempt_string = ($attempt > 1 ? "attempt $attempt/$attempt_limit: " : '');
		if ($self->_install_package_helper($package_name, $attempt_string)) {
			return 1;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to install $package_name on $computer_name, made $attempt_limit attempts");
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _install_package_helper

 Parameters  : $package_name, $attempt_string (optional)
 Returns     : boolean
 Description : Helper subroutine to install_package. Executes command to
               installs a Linux package using apt-get.

=cut

sub _install_package_helper {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($package_name, $attempt_string) = @_;
	if (!$package_name) {
		notify($ERRORS{'WARNING'}, 0, "package name argument was not supplied");
		return;
	}
	$attempt_string = '' unless defined($attempt_string);
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $command = "apt-get -qq -y install $package_name";
	notify($ERRORS{'DEBUG'}, 0, $attempt_string . "installing package on $computer_name: $package_name");
	my ($exit_status, $output) = $self->execute($command, 0, 300);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to execute command to install $package_name on $computer_name");
		return;
	}
	elsif ($exit_status eq 0) {
		if (grep(/$package_name is already/, @$output)) {
			notify($ERRORS{'OK'}, 0, $attempt_string . "$package_name is already installed on $computer_name");
		}
		else {
			notify($ERRORS{'OK'}, 0, $attempt_string . "installed $package_name on $computer_name");
		}
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, $attempt_string . "failed to install $package_name on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 simulate_install_package

 Parameters  : $package_name
 Returns     : array
 Description : Simulates the installation of a Linux package using apt-get.
               Returns the output lines as an array.

=cut

sub simulate_install_package {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($package_name) = @_;
	if (!$package_name) {
		notify($ERRORS{'WARNING'}, 0, "package name argument was not supplied");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $command = "apt-get -s install $package_name";
	notify($ERRORS{'DEBUG'}, 0, "attempting to simulate the installation of $package_name on $computer_name");
	my ($exit_status, $output) = $self->execute($command, 0, 300);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to simulate the installation of $package_name on $computer_name");
		return;
	}
	elsif ($exit_status eq 0) {
		#notify($ERRORS{'DEBUG'}, 0, "simulated the installation of $package_name on $computer_name, output:\n" . join("\n", @$output));
		return @$output;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to simulate the installation of $package_name on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 apt_get_update

 Parameters  : $force (optional)
 Returns     : boolean
 Description : Runs 'apt-get update' to resynchronize package index files from
               their sources. By default, this will only be executed once. The
               $force argument will cause apt-get update to be executed even if
               it was previously executed.

=cut

sub apt_get_update {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($force) = @_;
	
	return 1 if (!$force && $self->{apt_get_update});
	
	my $computer_name = $self->data->get_computer_node_name();
	
	# Clear out the files under lists to try to avoid these errors:
	#    W: Failed to fetch http://us.archive.ubuntu.com/ubuntu/dists/trusty-updates/universe/i18n/Translation-en  Hash Sum mismatch
	#    E: Some index files failed to download. They have been ignored, or old ones used instead.
	$self->delete_file('/var/lib/apt/lists/*');
	
	notify($ERRORS{'DEBUG'}, 0, "executing 'apt-get update' on $computer_name");
	my $command = "apt-get -qq update";
	my ($exit_status, $output) = $self->execute($command, 0, 300);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute 'apt-get update' on $computer_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "executed 'apt-get update' on $computer_name");
		$self->{apt_get_update} = 1;
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute 'apt-get update' on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 fix_debconf_db

 Parameters  : none
 Returns     : boolean
 Description : Executes /usr/share/debconf/fix_db.pl to attempt to fix problems
               installing packages via apt-get.

=cut

sub fix_debconf_db {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();

	# Setting up dictionaries-common (1.20.5) ...
	# debconf: unable to initialize frontend: Dialog
	# debconf: (TERM is not set, so the dialog frontend is not usable.)
	# debconf: falling back to frontend: Readline
	# debconf: unable to initialize frontend: Readline
	# debconf: (This frontend requires a controlling tty.)
	# debconf: falling back to frontend: Teletype
	# update-default-wordlist: Question empty but elements installed for class "wordlist"
	# dictionaries-common/default-wordlist: return code: "0", value: ""
	# Choices: , Manual symlink setting
	# shared/packages-wordlist: return code: "10" owners/error: "shared/packages-wordlist doesn't exist"
	# Installed elements: english (Webster's Second International English wordlist)
	# Please see "/usr/share/doc/dictionaries-common/README.problems", section
	# "Debconf database corruption" for recovery info.
	# update-default-wordlist: Selected wordlist ""
	# does not correspond to any installed package in the system
	# and no alternative wordlist could be selected.
	# dpkg: error processing package dictionaries-common (--configure):
	# subprocess installed post-installation script returned error exit status 255

	my $command = "/usr/share/debconf/fix_db.pl";
	my $attempt = 0;
	my $attempt_limit = 5;
	while ($attempt < $attempt_limit) {
		$attempt++;
		
		my ($exit_status, $output) = $self->execute($command, 0, 60);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to attempt to fix debconf database on $computer_name: $command");
			return;
		}
		
		# This command occasionally needs to be run multiple times to fix all problems
		# If output contains a line such as the following, run it again:
		#    debconf: template "base-passwd/user-change-uid" has no owners; removing it.
		if ($exit_status == 0) {
			my @lines = grep(/^debconf: /, @$output);
			my $line_count = scalar(@lines);
			if ($line_count) {
				notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: executed command to fix debconf database on $computer_name, $line_count problems were detected and/or fixed, another attempt will be made");
				next;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: no debconf database problems were detected on $computer_name");
				return 1;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to execute command to fix debconf database on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_product_name

 Parameters  : none
 Returns     : string
 Description : Retrieves the name of the Ubuntu distribution from
               'lsb_release --description'.

=cut

sub get_product_name {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{product_name} if defined($self->{product_name});
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $command = 'lsb_release --description';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine Ubuntu distribution name installed on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to determine Ubuntu distribution name installed on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	# Line should be in the form:
	# Description:    Ubuntu 14.04.2 LTS
	my ($product_name_line) = grep(/(Description|Ubuntu)/i, @$output);
	if (!$product_name_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine Ubuntu distribution name installed on $computer_name, output does not contain a line with 'Description' or 'Ubuntu':\n" . join("\n", @$output));
		return;
	}
	
	# Remove Description: from line
	$product_name_line =~ s/.*Description:\s*//g;
	
	$self->{product_name} = $product_name_line;
	notify($ERRORS{'OK'}, 0, "determined Ubuntu distribution name installed on $computer_name: '$self->{product_name}'");
	return $self->{product_name};
}

#//////////////////////////////////////////////////////////////////////////////
1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
