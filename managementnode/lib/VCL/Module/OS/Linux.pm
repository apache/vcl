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
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use VCL::utils;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $NODE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on computer loaded with a VCL image where configuration
               files and scripts reside.

=cut

our $NODE_CONFIGURATION_DIRECTORY = '/root/VCL';

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

=head2 pre_capture

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub pre_capture {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_id               = $self->data->get_request_id();
	my $reservation_id           = $self->data->get_reservation_id();
	my $image_id                 = $self->data->get_image_id();
	my $image_os_name            = $self->data->get_image_os_name();
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $image_os_type            = $self->data->get_image_os_type();
	my $image_name               = $self->data->get_image_name();
	my $computer_id              = $self->data->get_computer_id();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $computer_type            = $self->data->get_computer_type();
	my $user_id                  = $self->data->get_user_id();
	my $user_unityid             = $self->data->get_user_login_id();
	my $managementnode_shortname = $self->data->get_management_node_short_name();
	my $computer_private_ip      = $self->data->get_computer_private_ip_address();
	my $ip_configuration 	     = $self->data->get_management_node_public_ip_configuration();

	notify($ERRORS{'OK'}, 0, "beginning Linux-specific image capture preparation tasks: $image_name on $computer_short_name");

	my @sshcmd;

	# Force user off computer 
	if ($self->logoff_user()){
		notify($ERRORS{'OK'}, 0, "forced $user_unityid off $computer_node_name");
	}

	# Remove user and clean external ssh file
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "$user_unityid deleted from $computer_node_name");
	}

	# try to clear /tmp
	if (run_ssh_command($computer_node_name, $management_node_keys, "/usr/sbin/tmpwatch -f 0 /tmp; /bin/cp /dev/null /var/log/wtmp", "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleartmp precapture $computer_node_name ");
	}

	# Clear ssh idenity keys from /root/.ssh 
	if (!$self->clear_private_keys()) {
		notify($ERRORS{'WARNING'}, 0, "unable to clear known identity keys");
	}

	if ($ip_configuration eq "static") {
		if ($self->can("set_static_public_address") && $self->set_static_public_address()) {
			notify($ERRORS{'DEBUG'}, 0, "set static public IP address on $computer_node_name using set_static_public_address() method");
		}
	} ## end if ($ip_configuration eq "static")

	# Write /etc/rc.local script
	if(!$self->generate_rc_local()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/rc.local script on $computer_node_name");
		return 0;
	}

	# Generate external_sshd_config
	if(!$self->generate_ext_sshd_config()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/ssh/external_sshd_config on $computer_node_name");
		return 0;
	}

	# Generate ext_sshd init script
	if(!$self->generate_ext_sshd_init()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/init.d/ext_sshd on $computer_node_name");
		return 0;
	}

	# Shutdown node
	notify($ERRORS{'OK'}, 0, "shutting down node for Linux imaging sequence");
	run_ssh_command($computer_node_name, $management_node_keys, "/sbin/shutdown -h now", "root");
	
	# Wait maximum of 5 minutes for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(120, 3, 3);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 1 minute to allow computer time to shutdown");
		sleep 60;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off");
		return;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  :
 Returns     :
 Description :

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $management_node_keys  = $self->data->get_management_node_keys();
	my $image_name            = $self->data->get_image_name();
	my $computer_short_name   = $self->data->get_computer_short_name();
	my $computer_node_name    = $self->data->get_computer_node_name();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	
	notify($ERRORS{'OK'}, 0, "initiating Linux post_load: $image_name on $computer_short_name");

	# Wait for computer to respond to SSH
	if (!$self->wait_for_response(60, 600)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
		return 0;
	}
	
	if ($image_os_install_type eq "kickstart"){
		notify($ERRORS{'OK'}, 0, "detected kickstart install on $computer_short_name, writing current_image.txt");
		if (write_currentimage_txt($self->data)){
			notify($ERRORS{'OK'}, 0, "wrote current_image.txt on $computer_short_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to write current_image.txt on $computer_short_name");
		}
	}
	
	# Change password
	if ($self->changepasswd($computer_node_name, "root")) {
		notify($ERRORS{'OK'}, 0, "successfully changed root password on $computer_node_name");
		#insertloadlog($reservation_id, $computer_id, "info", "SUCCESS randomized roots password");
	}
	else {
		notify($ERRORS{'OK'}, 0, "failed to edit root password on $computer_node_name");
	}
	
	#disable ext_sshd
	my @stopsshd = run_ssh_command($computer_short_name, $management_node_keys, "/etc/init.d/ext_sshd stop", "root");
	foreach my $l (@{$stopsshd[1]}) {
		if ($l =~ /Stopping ext_sshd/) {
			notify($ERRORS{'OK'}, 0, "ext sshd stopped on $computer_node_name");
			last;
		}
	}

	#Clear user from external_sshd_config
	my $clear_extsshd = "sed -i -e \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $management_node_keys, $clear_extsshd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared AllowUsers directive from external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to clear AllowUsers from external_sshd_config");
	}
	
	notify($ERRORS{'DEBUG'}, 0, "calling clear_private_keys");
	#Clear ssh idenity keys from /root/.ssh 
	if ($self->clear_private_keys()) {
		notify($ERRORS{'OK'}, 0, "cleared known identity keys");
	}

	#Update Hostname to match Public assigned name
   if($self->update_public_hostname()){
      notify($ERRORS{'OK'}, 0, "Updated hostname");
   }
	
	# Run the vcl_post_load script if it exists in the image
	my $script_path = '/etc/init.d/vcl_post_load';
	my $result = $self->run_script($script_path);
	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running $script_path");
	}
	elsif ($result == 0) {
		notify($ERRORS{'DEBUG'}, 0, "$script_path does not exist in image: $image_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "ran $script_path");
	}
	
	# Attempt to generate ifcfg-eth* files and ifup any interfaces which the file does not exist
	$self->activate_interfaces();
	
	# Add a line to currentimage.txt indicating post_load has run
	$self->set_vcld_post_load_status();
	
	return 1;

} ## end sub post_load

#/////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

 Parameters  :
 Returns     :
 Description :

=cut

sub post_reserve {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $image_name           = $self->data->get_image_name();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $script_path = '/etc/init.d/vcl_post_reserve';
	
	notify($ERRORS{'OK'}, 0, "initiating Linux post_reserve: $image_name on $computer_short_name");
	
	# Check if script exists
	if (!$self->file_exists($script_path)) {
		notify($ERRORS{'DEBUG'}, 0, "script does NOT exist: $script_path");
		return 1;
	}
	
	# Run the vcl_post_reserve script if it exists in the image
	my $result = $self->run_script($script_path);
	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running $script_path");
	}
	elsif ($result == 0) {
		notify($ERRORS{'DEBUG'}, 0, "$script_path does not exist in image: $image_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "ran $script_path");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_public_hostname

 Parameters  : none
 Returns     : boolean
 Description : Retrieves the public IP address being used on the Linux computer.
               Runs ipcalc locally on the management node to determine the
               registered hostname for that IP address. If unable to determine
               the hostname by running ipcalc on the management node, an attempt
               is made to run ipcalc on the Linux computer. Once the hostname is
               determined, the hostname command is run to set the hostname on
               the Linux computer.

=cut

sub update_public_hostname {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return; 
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get the IP address of the public adapter
	my $public_ip_address = $self->get_public_ip_address();
	if (!$public_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "hostname cannot be set, unable to determine public IP address");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved public IP address of $computer_node_name: $public_ip_address");
	
	# Get the hostname for the public IP address
	my $ipcalc_command = "/bin/ipcalc --hostname $public_ip_address";
	my ($ipcalc_exit_status, $ipcalc_output) = run_command($ipcalc_command);
	if (!defined($ipcalc_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ipcalc command on management node to determine public hostname of $computer_node_name, command: '$ipcalc_command'");
		return;
	}
	
	my ($public_hostname) = ("@$ipcalc_output" =~ /HOSTNAME=(.*)/i);
	if ($public_hostname) {
		notify($ERRORS{'DEBUG'}, 0, "determined registered public hostname of $computer_node_name ($public_ip_address) by running ipcalc on the management node: '$public_hostname'");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to determine registered public hostname of $computer_node_name ($public_ip_address), command: '$ipcalc_command', output:\n" . join("\n", @$ipcalc_output));
		
		# Attempt to run the ipcalc command on the host
		my ($ipcalc_exit_status, $ipcalc_output) = run_ssh_command($computer_node_name, $management_node_keys, $ipcalc_command);
		if (!defined($ipcalc_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run ipcalc command on $computer_node_name to determine its public hostname, command: '$ipcalc_command'");
			return;
		}
		
		($public_hostname) = ("@$ipcalc_output" =~ /HOSTNAME=(.*)/i);
		if ($public_hostname) {
			notify($ERRORS{'DEBUG'}, 0, "determined registered public hostname of $computer_node_name ($public_ip_address) by running ipcalc on $computer_node_name: '$public_hostname'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to determine registered public hostname of $computer_node_name ($public_ip_address) by running ipcalc on either the management node or $computer_node_name, command: '$ipcalc_command', output:\n" . join("\n", @$ipcalc_output));
			return;
		}
	}
	
	# Set the node's hostname to public hostname
	my $hostname_command = "hostname -v $public_hostname";
	my ($hostname_exit_status, $hostname_output) = run_ssh_command($computer_node_name, $management_node_keys, $hostname_command); 
	if (!defined($hostname_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to SSH command to set hostname on $computer_node_name to $public_hostname, command: '$hostname_command'");
		return;
	}
	elsif ($hostname_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "set public hostname on $computer_node_name to $public_hostname");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set public hostname on $computer_node_name to $public_hostname, exit status: $hostname_exit_status, output:\n" . join("\n", @$hostname_output));
		return 0;
	}
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

	#Clear ssh idenity keys from /root/.ssh 
	my $clear_private_keys = "/bin/rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub";
	if (run_ssh_command($computer_node_name, $management_node_keys, $clear_private_keys, "root")) {
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
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Make sure public IP configuration is static
	my $ip_configuration = $self->data->get_management_node_public_ip_configuration();
	if ($ip_configuration !~ /static/i) {
		notify($ERRORS{'WARNING'}, 0, "static public address can only be set if IP configuration is static, current value: $ip_configuration");
		return;
	}

	# Get the IP configuration
	my $interface_name = $self->get_public_interface_name() || '<undefined>';
	my $ip_address = $self->data->get_computer_ip_address() || '<undefined>';
	my $subnet_mask = $self->data->get_management_node_public_subnet_mask() || '<undefined>';
	my $default_gateway = $self->data->get_management_node_public_default_gateway() || '<undefined>';
	my @dns_servers = $self->data->get_management_node_public_dns_servers();
	
	# Assemble a string containing the static IP configuration
	my $configuration_info_string = <<EOF;
public interface name: $interface_name
public IP address: $ip_address
public subnet mask: $subnet_mask
public default gateway: $default_gateway
public DNS server(s): @dns_servers
EOF
	
	# Make sure required info was retrieved
	if ("$interface_name $ip_address $subnet_mask $default_gateway" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve required network configuration for $computer_name:\n$configuration_info_string");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "attempting to set static public IP address on $computer_name:\n$configuration_info_string");
	}
	
	# Assemble the ifcfg file path
	my $network_scripts_path = "/etc/sysconfig/network-scripts";
	my $ifcfg_file_path = "$network_scripts_path/ifcfg-$interface_name";
	notify($ERRORS{'DEBUG'}, 0, "public interface ifcfg file path: $ifcfg_file_path");
	
	# Assemble the ifcfg file contents
	my $ifcfg_contents = <<EOF;
DEVICE=$interface_name
BOOTPROTO=static
IPADDR=$ip_address
NETMASK=$subnet_mask
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
	notify($ERRORS{'DEBUG'}, 0, "attempting to restart public interface $interface_name on $computer_name");
	my $interface_restart_command = "$network_scripts_path/ifdown $interface_name ; $network_scripts_path/ifup $interface_name";
	my ($interface_restart_exit_status, $interface_restart_output) = $self->execute($interface_restart_command);
	if (!defined($interface_restart_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to restart public interface $interface_name on $computer_name: '$interface_restart_command'");
		return;
	}
	elsif ($interface_restart_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart public interface $interface_name on $computer_name, exit status: $interface_restart_exit_status, command: '$interface_restart_command', output:\n" . join("\n", @$interface_restart_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "restarted public interface $interface_name on $computer_name");
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
	
	# Update the external sshd file
	# Remove existing ListenAddress lines using sed
	# Add ListenAddress line to the end of the file
	my $ext_sshd_command;
	$ext_sshd_command .= "sed -i -e \"/ListenAddress .*/d \" /etc/ssh/external_sshd_config 2>&1";
	$ext_sshd_command .= " && echo \"ListenAddress $ip_address\" >> /etc/ssh/external_sshd_config";
	$ext_sshd_command .= " && tail -n1 /etc/ssh/external_sshd_config";
	my ($ext_sshd_exit_status, $ext_sshd_output) = $self->execute($ext_sshd_command);
	if (!defined($ext_sshd_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to update ListenAddress line in /etc/ssh/external_sshd_config on $computer_name: '$ext_sshd_command'");
		return;
	}
	elsif ($ext_sshd_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to update ListenAddress line in /etc/ssh/external_sshd_config on $computer_name, exit status: $ext_sshd_exit_status\ncommand:\n'$ext_sshd_command'\noutput:\n" . join("\n", @$ext_sshd_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "updated ListenAddress line in /etc/ssh/external_sshd_config on $computer_name, output:\n" . join("\n", @$ext_sshd_output));
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
		map { chomp $_ } @resolv_conf_lines;
		
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
	
	notify($ERRORS{'OK'}, 0, "successfully set static public IP address on $computer_name");
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
	my $user_login_id = shift;
	$user_login_id = $self->data->get_user_login_id() if (!$user_login_id);
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}

	# Make sure the user login ID was passed
	my $computer_node_name = shift;
	$computer_node_name = $self->data->get_computer_node_name() if (!$computer_node_name);
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}

	#Make sure the identity key was passed
	my $image_identity = shift;
	$image_identity = $self->data->get_image_identity() if (!$image_identity);
	if (!$image_identity) {
		notify($ERRORS{'WARNING'}, 0, "image identity keys could not be determined");
		return 0;
	}

	my $logoff_cmd = "pkill -KILL -u $user_login_id";
	if (run_ssh_command($computer_node_name, $image_identity, $logoff_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "logged off $user_login_id from $computer_node_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to log off $user_login_id from $computer_node_name");
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  :
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
	my $user_login_id = shift;
	$user_login_id = $self->data->get_user_login_id() if (!$user_login_id);
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}

	# Make sure the user login ID was passed
	my $computer_node_name = shift;
	$computer_node_name = $self->data->get_computer_node_name() if (!$computer_node_name);
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}

	#Make sure the identity key was passed
	my $image_identity = shift;
	$image_identity = $self->data->get_image_identity() if (!$image_identity);
	if (!$image_identity) {
		notify($ERRORS{'WARNING'}, 0, "image identity keys could not be determined");
		return 0;
	}
	# Use userdel to delete the user
	# Do not use userdel -r, it will affect HPC user storage for HPC installs
	my $user_delete_command = "/usr/sbin/userdel $user_login_id";
	my @user_delete_results = run_ssh_command($computer_node_name, $image_identity, $user_delete_command, "root");
	foreach my $user_delete_line (@{$user_delete_results[1]}) {
		if ($user_delete_line =~ /currently logged in/) {
			notify($ERRORS{'WARNING'}, 0, "user not deleted, $user_login_id currently logged in");
			return 0;
		}
	}

	# Delete the group
	my $user_group_cmd = "/usr/sbin/groupdel $user_login_id";
	if(run_ssh_command($computer_node_name, $image_identity, $user_delete_command, "root")){
		notify($ERRORS{'DEBUG'}, 0, "attempted to delete usergroup for $user_login_id");
	}

	my $imagemeta_rootaccess = $self->data->get_imagemeta_rootaccess();

	#Clear user from external_sshd_config
	#my $clear_extsshd = "perl -pi -e \'s/^AllowUsers .*//\' /etc/ssh/external_sshd_config";
	my $clear_extsshd = "sed -i -e \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $image_identity, $clear_extsshd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared AllowUsers directive from external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user_login_id to external_sshd_config");
	}

	#Clear user from sudoers

	if ($imagemeta_rootaccess) {
		#clear user from sudoers file
		my $clear_cmd = "sed -i -e \"/^$user_login_id .*/d\" /etc/sudoers";
		if (run_ssh_command($computer_node_name, $image_identity, $clear_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "cleared $user_login_id from /etc/sudoers");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to clear $user_login_id from /etc/sudoers");
		}
	} ## end if ($imagemeta_rootaccess)

	return 1;

} ## end sub delete_user

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description : adds user 

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "Enterered reserve() in the Linux OS module");

	my $user_name            = $self->data->get_user_login_id();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $image_identity       = $self->data->get_image_identity;
	my $imagemeta_rootaccess = $self->data->get_imagemeta_rootaccess();
	my $user_uid		 = $self->data->get_user_uid();

	if($self->add_vcl_usergroup()){

	}
	
	if (!$self->create_user()) {
		notify($ERRORS{'CRITICAL'}, 0, "Failed to add user $user_name to $computer_node_name");
	 	return 0;	
	}

	return 1;
} ## end sub reserve

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description :  adds username to external_sshd_config and and starts sshd with custom config

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $user               = $self->data->get_user_login_id();
	my $computer_node_name = $self->data->get_computer_node_name();
	my $identity           = $self->data->get_image_identity;

	notify($ERRORS{'OK'}, 0, "In grant_access routine $user,$computer_node_name");
	my @sshcmd;
	my $clear_extsshd = "sed -i -e \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $identity, $clear_extsshd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared AllowUsers directive from external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user to external_sshd_config");
	}

	my $cmd = "echo \"AllowUsers $user\" >> /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $identity, $cmd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "added AllowUsers $user to external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user to external_sshd_config");
		return 0;
	}

	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $identity, "/etc/init.d/ext_sshd restart", "root");

	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Stopping ext_sshd:/i) {
			#notify($ERRORS{'OK'},0,"stopping sshd on $computer_node_name ");
		}
		if ($l =~ /Starting ext_sshd:[  OK  ]/i) {
			notify($ERRORS{'OK'}, 0, "ext_sshd on $computer_node_name started");
		}
	}    #foreach
	notify($ERRORS{'OK'}, 0, "started ext_sshd on $computer_node_name");
	return 1;
} ## end sub grant_access

#/////////////////////////////////////////////////////////////////////////////

=head2 changepasswd

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description : changes or sets password for given account

=cut

sub changepasswd {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $management_node_keys = $self->data->get_management_node_keys();

	# change the privileged account passwords on the blade images
	my $node = shift; 
	my $account = shift;  
	my $passwd = shift; 

	notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "account is not defined") if (!(defined($account)));
	
	$passwd = getpw(15) if (!(defined($passwd)));
	
	my ($exit_status, $output) = run_ssh_command($node, $management_node_keys, "echo $passwd \| /usr/bin/passwd -f $account --stdin", "root");
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to set password for account: $account");
		return;
	}
	notify($ERRORS{'OK'}, 0, "changed password for account: $account, output:\n" . join("\n", @$output));
	return 1;
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
		#return false - reclaim will reload
		return 0;
	}

	# Revoke access
	if (!$self->revoke_access()) {
		notify($ERRORS{'WARNING'}, 0, "failed to revoke access to $computer_node_name");
		#relcaim will reload
		return 0;
	}

	# Delete all user associated with the reservation
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "users have been deleted from $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete users from $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;
} ## end sub sanitize

#/////////////////////////////////////////////////////////////////////////////

=head2 revoke_access

 Parameters  :
 Returns     :
 Description :

=cut

sub revoke_access {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();

	if ($self->stop_external_sshd()) {
		notify($ERRORS{'OK'}, 0, "stopped external sshd");
	}

	notify($ERRORS{'OK'}, 0, "access has been revoked to $computer_node_name");
	return 1;
} ## end sub revoke_access

#/////////////////////////////////////////////////////////////////////////////

=head2 stop_external_sshd

 Parameters  :
 Returns     :
 Description :

=cut

sub stop_external_sshd {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $identity             = $self->data->get_image_identity;

	my @sshcmd = run_ssh_command($computer_node_name, $identity, "pkill -fx \"/usr/sbin/sshd -f /etc/ssh/external_sshd_config\"", "root");

	foreach my $l (@{$sshcmd[1]}) {
		if ($l) {
			notify($ERRORS{'DEBUG'}, 0, "output detected: $l");
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "ext_sshd on $computer_node_name stopped");
	return 1;

} ## end sub stop_external_sshd
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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $identity             = $self->data->get_image_identity;

	if(run_ssh_command($computer_node_name, $identity, "groupadd vcl", "root")){
		notify($ERRORS{'DEBUG'}, 0, "successfully added the vcl user group");
	}

	return 1;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_connected

 Parameters  :
 Returns     :
 Description :

=cut

sub is_connected {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $identity           = $self->data->get_image_identity;
	my $remote_ip          = $self->data->get_reservation_remote_ip();
	my $computer_ipaddress = $self->data->get_computer_ip_address();

	my @SSHCMD = run_ssh_command($computer_node_name, $identity, "netstat -an", "root", 22, 1);
	foreach my $line (@{$SSHCMD[1]}) {
		chomp($line);
		next if ($line =~ /Warning/);

		if ($line =~ /Connection refused/) {
			notify($ERRORS{'WARNING'}, 0, "$line");
			return 1;
		}
		if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($computer_ipaddress:22)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
			return 1;
		}
	} ## end foreach my $line (@{$SSHCMD[1]})

	return 0;

} ## end sub is_connected

#/////////////////////////////////////////////////////////////////////////////

=head2 call_post_load_custom

 Parameters  : none
 Returns     : If successfully ran post_load_custom script: 1
               If post_load_custom script does not exist: 1
               If error occurred: false
 Description : Checks if /etc/init.d/post_load_custom script exists on the
               Linux node and attempts to run it. This script can be created by
					the image creator and will run when the image is loaded.

=cut

sub call_post_load_custom {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if post_load_custom exists
	my $post_load_custom_path = '/etc/init.d/post_load_custom';
	if ($self->file_exists($post_load_custom_path)) {
		notify($ERRORS{'DEBUG'}, 0, "post_load_custom script exists: $post_load_custom_path");
	}
	else {
		notify($ERRORS{'OK'}, 0, "post_load_custom script does NOT exist: $post_load_custom_path");
		return 1;
	}
	
	# Get the node configuration directory, make sure it exists, create if necessary
	my $node_log_directory = $self->get_node_configuration_directory() . '/Logs';
	if (!$self->create_directory($node_log_directory)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create node log file directory: $node_log_directory");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Assemble the log file path
	my $post_load_custom_log_path = $node_log_directory . "/post_load_custom.log";
	
	# Assemble the command
	my $post_load_custom_command;
	# Make sure the script is readable and executable
	$post_load_custom_command .= "chmod +rx \"$post_load_custom_path\"";
	# Redirect the script output to the log file path
	$post_load_custom_command .= " && \"$post_load_custom_path\" >> \"$post_load_custom_log_path\" 2>&1";
	
	# Execute the command
	my ($post_load_custom_exit_status, $post_load_custom_output) = run_ssh_command($computer_node_name, $management_node_keys, $post_load_custom_command, '', '', 1);
	if (defined($post_load_custom_exit_status) && $post_load_custom_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "executed $post_load_custom_path, exit status: $post_load_custom_exit_status");
	}
	elsif (defined($post_load_custom_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "$post_load_custom_path returned a non-zero exit status: $post_load_custom_exit_status, output:\n@{$post_load_custom_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to execute $post_load_custom_path");
		return;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 execute

 Parameters  : $command, $display_output (optional)
 Returns     : array ($exit_status, $output)
 Description : Executes a command on the Linux computer via SSH.

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
	
	# Get the computer node name
	my $computer_name = $self->data->get_computer_node_name() || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the command via SSH
	my ($exit_status, $output) = run_ssh_command($computer_name, $management_node_keys, $command, '', '', $display_output);
	if (defined($exit_status) && defined($output)) {
		if ($display_output) {
			notify($ERRORS{'OK'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		}
		return ($exit_status, $output);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on $computer_name: $command");
		return;
	}
}

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
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
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

 Parameters  : $path
 Returns     : boolean
 Description : Checks if a file or directory exists on the Linux computer.

=cut

sub file_exists {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path from the subroutine arguments and make sure it was passed
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$path = normalize_file_path($path);
	
	# Escape all spaces in the path
	my $escaped_path = escape_file_path($path);
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Check if the file or directory exists
	# Do not enclose the path in quotes or else wildcards won't work
	my $command = "stat $escaped_path";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine if file or directory exists on $computer_short_name:\npath: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "file or directory does not exist on $computer_short_name: '$path'");
		return 0;
	}
	elsif (grep(/stat: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if file or directory exists on $computer_short_name:\npath: '$path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Count the lines beginning with "Size:" and ending with "file", "directory", or "link" to determine how many files and/or directories were found
	my $files_found = grep(/^\s*Size:.*file$/i, @$output);
	my $directories_found = grep(/^\s*Size:.*directory$/i, @$output);
	my $links_found = grep(/^\s*Size:.*link$/i, @$output);
	
	if ($files_found || $directories_found || $links_found) {
		notify($ERRORS{'DEBUG'}, 0, "'$path' exists on $computer_short_name, files: $files_found, directories: $directories_found, links: $links_found");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to determine if file or directory exists on $computer_short_name: '$path'\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
		return;
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
	my $file_exists = $self->file_exists($path);
	if (!defined($file_exists)) {
		notify($ERRORS{'WARNING'}, 0, "failed to confirm file doesn't exist on $computer_short_name: '$path'");
		return;
	}
	elsif ($file_exists) {
		notify($ERRORS{'WARNING'}, 0, "file was not deleted, it still exists on $computer_short_name: '$path'");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "confirmed file does not exist on $computer_short_name: '$path'");
		return 1;
	}
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
	
	my $computer_short_name = $self->data->get_computer_short_name();
	
	# Attempt to create the directory
	my $command = "ls -d --color=never \"$directory_path\" 2>&1 || mkdir -p \"$directory_path\" 2>&1 && ls -d --color=never \"$directory_path\"";
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
			notify($ERRORS{'OK'}, 0, "directory already exists on $computer_short_name: '$directory_path'");
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
	my $source_path = shift;
	my $destination_path = shift;
	if (!$source_path || !$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination path arguments were not specified");
		return;
	}
	
	# Remove any quotes from the beginning and end of the path
	$source_path = normalize_file_path($source_path);
	$destination_path = normalize_file_path($destination_path);
	
	# Escape all spaces in the path
	my $escaped_source_path = escape_file_path($source_path);
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

=head2 get_file_contents

 Parameters  : $file_path
 Returns     : array
 Description : Returns an array containing the contents of the file specified by
               the file path argument. Each array element contains a line from
               the file.

=cut

sub get_file_contents {
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
	
	# Run cat to retrieve the contents of the file
	my $command = "cat \"$path\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to read file on $computer_short_name:\n path: '$path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^cat: /, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to read contents of file on $computer_short_name: '$path', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved " . scalar(@$output) . " lines from file on $computer_short_name: '$path'");
		return @$output;
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
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine available space on $computer_short_name:\ncommand: $command\noutput:\n" . join("\n", @$output));
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
	my ($block_size) = $output_string =~ /Block size: (\d+)/;
	if (!$block_size) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate 'Block size:' value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
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
	my $mb_available = format_number(($bytes_available / 1024 / 1024), 2);
	my $gb_available = format_number(($bytes_available / 1024 / 1024 / 1024), 1);
	
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
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine available space on $computer_short_name:\ncommand: $command\noutput:\n" . join("\n", @$output));
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
	my ($block_size) = $output_string =~ /Block size: (\d+)/;
	if (!$block_size) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate 'Block size:' value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
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
	my $mb_total = format_number(($bytes_total / 1024 / 1024), 2);
	my $gb_total = format_number(($bytes_total / 1024 / 1024 / 1024), 1);
	
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

=head2 copy_file_to

 Parameters  : $source_path, $destination_path
 Returns     : boolean
 Description : Copies file(s) from the management node to the Linux computer.
               Wildcards are allowed in the source path.

=cut

sub copy_file_to {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the source and destination arguments
	my ($source_path, $destination_path) = @_;
	if (!$source_path || !$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination path arguments were not specified");
		return;
	}
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	# Get the destination parent directory path and create the directory
	my $destination_directory_path = parent_directory_path($destination_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_path");
		return;
	}
	$self->create_directory($destination_directory_path) || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the SCP command
	if (run_scp_command($source_path, "$computer_node_name:\"$destination_path\"", $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied file from management node to $computer_node_name: '$source_path' --> $computer_node_name:'$destination_path'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file from management node to $computer_node_name: '$source_path' --> $computer_node_name:'$destination_path'");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 copy_file

 Parameters  : $source_file_path, $destination_file_path
 Returns     : boolean
 Description : Copies a single file on the Linux computer to another location on
               the computer. The source and destination file path arguments may
               not be directory paths nor may they contain wildcards. 

=cut

sub copy_file {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the path arguments
	my $source_file_path = shift;
	my $destination_file_path = shift;
	if (!$source_file_path || !$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source and destination file path arguments were not specified");
		return;
	}
	
	# Normalize the source and destination paths
	$source_file_path = normalize_file_path($source_file_path);
	$destination_file_path = normalize_file_path($destination_file_path);
	
	# Escape all spaces in the path
	my $escaped_source_path = escape_file_path($source_file_path);
	my $escaped_destination_path = escape_file_path($destination_file_path);
	
	# Make sure the source and destination paths are different
	if ($escaped_source_path eq $escaped_destination_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy file, source and destination file path arguments are the same: $escaped_source_path");
		return;
	}
	
	# Get the destination parent directory path and create the directory if it does not exist
	my $destination_directory_path = parent_directory_path($destination_file_path);
	if (!$destination_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine destination parent directory path: $destination_file_path");
		return;
	}
	$self->create_directory($destination_directory_path) || return;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Execute the command to copy the file
	my $command = "cp -fr $escaped_source_path $escaped_destination_path";
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy file on $computer_node_name: '$source_file_path' -> '$destination_file_path'");
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/^cp: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (!@$output || grep(/->/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "copied file on $computer_node_name: '$source_file_path' --> '$destination_file_path'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to copy file on $computer_node_name:\nsource path: '$source_file_path'\ndestination path: '$destination_file_path'\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_file_size

 Parameters  : $file_path
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
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Normalize the file path
	$file_path = normalize_file_path($file_path);
	
	# Escape all spaces in the path
	my $escaped_file_path = escape_file_path($file_path);
	
	# Get the computer name
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
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
	my $file_count = 0;
	my $total_bytes_reserved = 0;
	my $total_bytes_used = 0;
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
			
			$total_bytes_used += $file_bytes_allocated;
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
			
			$file_count += $subdirectory_file_count;
			$total_bytes_reserved += $subdirectory_bytes_used;
			$total_bytes_used += $subdirectory_bytes_allocated;
		}
	}
	
	if ($calling_sub !~ /get_file_size/) {
		notify($ERRORS{'DEBUG'}, 0, "size of '$file_path' on $computer_node_name:\n" .
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

=head2 find_files

 Parameters  : $base_directory_path, $file_pattern
 Returns     : array
 Description : Finds files under the base directory and any subdirectories path
               matching the file pattern. The search is not case sensitive. An
               array is returned containing matching file paths.

=cut

sub find_files {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the arguments
	my ($base_directory_path, $file_pattern) = @_;
	if (!$base_directory_path || !$file_pattern) {
		notify($ERRORS{'WARNING'}, 0, "base directory path and file pattern arguments were not specified");
		return;
	}
	
	# Normalize the arguments
	$base_directory_path = normalize_file_path($base_directory_path);
	$file_pattern = normalize_file_path($file_pattern);
	
	# The base directory path must have a trailing slash or find won't work
	$base_directory_path .= '/';
	
	# Get the computer short and hostname
	my $computer_node_name = $self->data->get_computer_node_name() || return;
	
	# Run the find command
	my $command = "find \"$base_directory_path\" -iname \"$file_pattern\"";
	notify($ERRORS{'DEBUG'}, 0, "attempting to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command: $command");
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command:\n$command");
		return;
	}
	elsif (grep(/^find:.*No such file or directory/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "base directory does not exist on $computer_node_name: $base_directory_path");
		@$output = ();
	}
	elsif (grep(/^find: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to find files on $computer_node_name\nbase directory path: $base_directory_path\npattern: $file_pattern\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Return the file list
	my @file_paths = @$output;
	notify($ERRORS{'DEBUG'}, 0, "matching file count: " . scalar(@file_paths));
	return sort @file_paths;
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
	
	my $recursive = shift;
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

=head2 generate_rc_local

 Parameters  : none
 Returns     : boolean
 Description : Generate a rc.local file locally, copy to node and make executable.

=cut

sub generate_rc_local {
        my $self = shift;
        if (ref($self) !~ /linux/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return 0;
        }
	
	my $request_id               = $self->data->get_request_id();
        my $management_node_keys     = $self->data->get_management_node_keys();
        my $computer_short_name      = $self->data->get_computer_short_name();
        my $computer_node_name       = $self->data->get_computer_node_name();
	
	my @array2print;

	push(@array2print, '#!/bin/sh' . "\n");
	push(@array2print, '#' . "\n");
        push(@array2print, '# This script will be executed after all the other init scripts.' . "\n");
	push(@array2print, '#' . "\n");
        push(@array2print, '# WARNING --- VCL IMAGE CREATORS --- WARNING' . "\n");
	push(@array2print, '#' . "\n");
        push(@array2print, '# This file will get overwritten during image capture. Any customizations' . "\n");
        push(@array2print, '# should be put into /etc/init.d/vcl_post_reserve or /etc/init.d/vcl_post_load' . "\n");
        push(@array2print, '# Note these files do not exist by default.' . "\n");
        push(@array2print, "\n");
        push(@array2print, 'touch /var/lock/subsys/local' . "\n");
        push(@array2print, "\n");
        push(@array2print, 'IP0=$(ifconfig eth0 | grep inet | awk \'{print $2}\' | awk -F: \'{print $2}\')' . "\n");
        push(@array2print, 'IP1=$(ifconfig eth1 | grep inet | awk \'{print $2}\' | awk -F: \'{print $2}\')' . "\n");
        push(@array2print, 'sed -i -e \'/.*AllowUsers .*$/d\' /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'sed -i -e \'/.*ListenAddress .*/d\' /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'sed -i -e \'/.*ListenAddress .*/d\' /etc/ssh/external_sshd_config' . "\n");
        push(@array2print, 'echo "AllowUsers root" >> /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'echo "ListenAddress $IP0" >> /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'echo "ListenAddress $IP1" >> /etc/ssh/external_sshd_config' . "\n");
        push(@array2print, '/etc/rc.d/init.d/ext_sshd stop' . "\n");
        push(@array2print, '/etc/rc.d/init.d/sshd stop' . "\n");
        push(@array2print, 'sleep 2' . "\n");
        push(@array2print, '/etc/rc.d/init.d/sshd start' . "\n");
        push(@array2print, '/etc/rc.d/init.d/ext_sshd start' . "\n");

	#write to tmpfile
	my $tmpfile = "/tmp/$request_id.rc.local";
	if (open(TMP, ">$tmpfile")) {
		print TMP @array2print;
		close(TMP);
	}
	else {
		#print "could not write $tmpfile $!\n";
		notify($ERRORS{'OK'}, 0, "could not write $tmpfile $!");
		return 0;
	}
	#copy to node
	if (run_scp_command($tmpfile, "$computer_node_name:/etc/rc.local", $management_node_keys)) {
	}
	else{
		return 0;
	}
	
	# Assemble the command
	my $command = "chmod +rx /etc/rc.local";
	
	# Execute the command
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
	if (defined($exit_status) && $exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "executed $command, exit status: $exit_status");
	}
	elsif (defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "setting rx on /etc/rc.local returned a non-zero exit status: $exit_status");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to execute script_path");
		return 0;
	}
	
	unlink($tmpfile);

	return 1;
	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_ext_sshd_config

 Parameters  : none
 Returns     : boolean
 Description : Copy default sshd config and edit key values

=cut

sub generate_ext_sshd_config {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $request_id               = $self->data->get_request_id();
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	#check for and copy /etc/ssh/sshd_config file
	
	#Copy node's /etc/ssh/sshd_config to local /tmp for processing
	my $tmpfile = "/tmp/$request_id.external_sshd_config";
	if (run_scp_command("$computer_node_name:/etc/ssh/sshd_config", $tmpfile, $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied sshd_config from $computer_node_name for local processing");
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to copied sshd_config from $computer_node_name for local processing");
		return 0;
	}
	
	my @ext_sshd_config = read_file_to_array($tmpfile);	
	
	foreach my $l (@ext_sshd_config) {
		#clear any unwanted lines - could be multiples
		if($l =~ /^(.)?PidFile/ ){
			$l = "";
		}
		if($l =~ /^(.)?PermitRootLogin/){
			$l = "";
		} 
		if($l =~ /^(.)?AllowUsers root/){
			$l = "";
		}
		if($l =~ /^(.)?UseDNS/){
			$l = "";
		}
		if($l =~ /^(.)?X11Forwarding/){
			$l = "";
		}
		if($l =~ /^(.)?PasswordAuthentication/){
			$l = "";
		}
	}
	
	push(@ext_sshd_config, "PidFile /var/run/ext_sshd.pid\n");
	push(@ext_sshd_config, "PermitRootLogin no\n");
	push(@ext_sshd_config, "UseDNS no\n");
	push(@ext_sshd_config, "X11Forwarding yes\n");
	push(@ext_sshd_config, "PasswordAuthentication yes\n");
	
	#clear temp file
	unlink($tmpfile);
	
	#write_array to file
	if(open(FILE, ">$tmpfile")){
		print FILE @ext_sshd_config;
		close FILE;
	}
	
	#copy temp file to node
	if (run_scp_command($tmpfile, "$computer_node_name:/etc/ssh/external_sshd_config", $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $computer_node_name:/etc/ssh/external_sshd_config");
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to copied $tmpfile to $computer_node_name:/etc/ssh/external_sshd_config");
		return 0;
	}	
	unlink($tmpfile);
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_ext_sshd_init

 Parameters  : none
 Returns     : boolean
 Description :

=cut

sub generate_ext_sshd_init {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $request_id               = $self->data->get_request_id();
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	#copy /etc/init.d/sshd to local /tmp for processing
	my $tmpfile = "/tmp/$request_id.ext_sshd";
	if (run_scp_command("$computer_node_name:/etc/init.d/sshd", $tmpfile, $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied sshd init script from $computer_node_name for local processing");
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to copied sshd init script from $computer_node_name for local processing");
		return 0;
	}
	
	my @ext_sshd_init = read_file_to_array($tmpfile);
	
	notify($ERRORS{'DEBUG'}, 0, "read file $tmpfile into array ");
	
	foreach my $l (@ext_sshd_init) {
		if($l =~ /PID_FILE=/){
			$l = "PID_FILE=/var/run/ext_sshd.pid" . "\n" . "OPTIONS=\'-f /etc/ssh/external_sshd_config\'\n";
		}	
		if($l =~ /prog=/){
			$l="prog=\"ext_sshd\"" . "\n";
		}
		
		my $string = '\[ "\$RETVAL" = 0 \] && touch \/var\/lock\/subsys\/sshd';	
		if($l =~ /$string/){
			$l = "[ \"\$RETVAL\" = 0 ] && touch /var/lock/subsys/ext_sshd" . "\n";
		}
		if($l =~ /if \[ -f \/var\/lock\/subsys\/sshd \] ; then/){
			$l = "if [ -f /var/lock/subsys/ext_sshd ] ; then" . "\n";
		}
	}
	
	#clear temp file
	unlink($tmpfile);
	
	#write_array to file
	if(open(FILE, ">$tmpfile")){
		print FILE @ext_sshd_init;
		close(FILE);
	}
	
	#slurp/read the file to scalar
	my $sshd_data = do { local( @ARGV, $/ ) = $tmpfile ; <> } ;
	
	#notify($ERRORS{'DEBUG'}, 0, "sshd_data after read= $sshd_data");
	
	#write new stop block
	my $new_stop_block = "stop()\n";
	$new_stop_block .= "{\n";
	$new_stop_block .= "        echo -n \$\"Stopping \$prog:\"\n";
	$new_stop_block .= "        killproc \$prog -TERM\n";
	$new_stop_block .= "        RETVAL=$?\n";
	$new_stop_block .= "        [ \"\$RETVAL\" = 0 ] && rm -f /var/lock/subsys/ext_sshd\n";
	$new_stop_block .= "        echo\n";	
	$new_stop_block .= "}\n";	
	
	
	#edit the stop block
	$sshd_data =~ s/stop\(\).*?\}/$new_stop_block/s;
	
	
	#save to file
	if(open(WRITEFILE,">$tmpfile")){
		print WRITEFILE $sshd_data;
		close(WRITEFILE);
	}
	
	#copy temp file to node
	if (run_scp_command($tmpfile, "$computer_node_name:/etc/init.d/ext_sshd", $management_node_keys)) {
		notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $computer_node_name:/etc/init.d/ext_sshd");
		if(run_ssh_command($computer_node_name, $management_node_keys, "chmod +rx /etc/init.d/ext_sshd", '', '', 1)){
			notify($ERRORS{'DEBUG'}, 0, "setting  $computer_node_name:/etc/init.d/ext_sshd executable");
		}
	}
	else{
		notify($ERRORS{'WARNING'}, 0, "failed to copied $tmpfile to $computer_node_name:/etc/init.d/ext_sshd");
		return 0;
	}
	
	#delete local tmpfile
	unlink($tmpfile);
	
	return 1;

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
	my @interface_names = grep { /^\d+:\s+(eth\d+)/ ; $_ = $1 } @$output;
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
		
		# Create the ifcfg-eth* file and attempt to call ifup on the interface
		my $echo_command = "echo \E \"$ifcfg_contents\" > $ifcfg_path && ifup $interface_name";
		notify($ERRORS{'DEBUG'}, 0, "attempting to echo contents to $ifcfg_path:\n$ifcfg_contents");
		my ($echo_exit_status, $echo_output) = $self->execute($echo_command, 1);
		if (!defined($echo_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to echo contents to $ifcfg_path");
			return;
		}
		elsif (grep(/done\./, @$echo_output)) {
			notify($ERRORS{'OK'}, 0, "created $ifcfg_path and enabled interface: $interface_name, output:\n" . join("\n", @$echo_output));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create $ifcfg_path and enable interface: $interface_name, output:\n" . join("\n", @$echo_output));
		}
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_network_configuration

 Parameters  : 
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

        my $management_node_keys = $self->data->get_management_node_keys();
        my $computer_node_name   = $self->data->get_computer_node_name();

        # Check if an argument was supplied
        my $wait_for_reboot = shift;
        if (!defined($wait_for_reboot) || $wait_for_reboot !~ /0/) {
                notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and waiting for ssh to become active");
                $wait_for_reboot = 1;
        }
        else {
                notify($ERRORS{'DEBUG'}, 0, "rebooting $computer_node_name and NOT waiting");
                $wait_for_reboot = 0;
        }

        my $reboot_start_time = time();
        notify($ERRORS{'DEBUG'}, 0, "reboot will be attempted on $computer_node_name");

        # Check if computer responds to ssh before preparing for reboot
        if ($self->wait_for_ssh(0)) {

                # Check if shutdown exists on the computer
                my $reboot_command;
                if ( $self->file_exists("/sbin/shutdown")) {
                        $reboot_command = "/sbin/shutdown -r now";
                }
                else {
                        notify($ERRORS{'WARNING'}, 0, "reboot not attempted, /sbin/shutdown did not exists on OS");
                        return 0;
                }

                my ($reboot_exit_status, $reboot_output) = run_ssh_command($computer_node_name, $management_node_keys, $reboot_command);
                if (!defined($reboot_output)) {
                        notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to reboot $computer_node_name");
                        return;
                }

                if ($reboot_exit_status == 0) {
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
                # Computer did not respond to ssh
                notify($ERRORS{'WARNING'}, 0, "$computer_node_name did not respond to ssh, graceful reboot cannot be performed, attempting hard reset");

                # Call provisioning module's power_reset() subroutine
                if ($self->provisioner->power_reset()) {
                        notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
                }
                else {
                        notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
                        return 0;
                }
        } ## end else [ if ($self->wait_for_ssh(0))
	
	my $wait_attempt_limit = 2;
        # Check if wait for reboot is set
        if (!$wait_for_reboot) {
                return 1;
        }
	else {
		if($self->wait_for_reboot($wait_attempt_limit)){
			# Reboot was successful, calculate how long reboot took
                	my $reboot_end_time = time();
                	my $reboot_duration = ($reboot_end_time - $reboot_start_time);
                	notify($ERRORS{'OK'}, 0, "reboot complete on $computer_node_name, took $reboot_duration seconds");
			return 1;
		}
		else {
        		notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, made $wait_attempt_limit attempts");
			return 0;
		}
	}

} ## end sub reboot

#/////////////////////////////////////////////////////////////////////////////

=head2 create_user

 Parameters  : username,password,adminoverride(0,1,2),user_uid
 Returns     : 1
 Description : 

=cut

sub create_user {
        my $self = shift;
        if (ref($self) !~ /linux/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }

        my $management_node_keys = $self->data->get_management_node_keys();
        my $computer_node_name   = $self->data->get_computer_node_name();
        my $imagemeta_rootaccess = $self->data->get_imagemeta_rootaccess();

        # Attempt to get the username from the arguments
        # If no argument was supplied, use the user specified in the DataStructure
        my $username = shift;
        my $password = shift;
	my $user_uid = shift;
	my $adminoverride = shift;
	my $user_standalone = shift;
	
        if (!$username) {
                $username = $self->data->get_user_login_id();
        }
        if (!$password) {
                $password = $self->data->get_reservation_password();
        }
	if (!$adminoverride) {
		$adminoverride = 0;	
	}
	if (!$user_uid) {
		$user_uid = $self->data->get_user_uid();	
	}
	
	if (!$user_standalone) {
		$user_standalone      = $self->data->get_user_standalone();
	}

	#adminoverride, if 0 use value from database for $imagemeta_rootaccess
	# if 1 or 2 override database
	# 1 - allow admin access, set $imagemeta_rootaccess=1
	# 2 - disallow admin access, set $imagemeta_rootaccess=0
	if ($adminoverride eq '1') {
		$imagemeta_rootaccess = 1;
	}
	elsif ($adminoverride eq '2') {
                $imagemeta_rootaccess = 0;
	}
	else {
		#no override detected, do not change database value
	}

	my $useradd_string;
        if(defined($user_uid) && $user_uid != 0){
                $useradd_string = "/usr/sbin/useradd -u $user_uid -d /home/$username -m $username -g vcl";
        }
        else{
                $useradd_string = "/usr/sbin/useradd -d /home/$username -m $username -g vcl";
        }


        my @sshcmd = run_ssh_command($computer_node_name, $management_node_keys, $useradd_string, "root");
        foreach my $l (@{$sshcmd[1]}) {
                if ($l =~ /$username exists/) {
                        notify($ERRORS{'OK'}, 0, "detected user already has account");
                        if ($self->delete_user()) {
                                notify($ERRORS{'OK'}, 0, "user has been deleted from $computer_node_name");
                                @sshcmd = run_ssh_command($computer_node_name, $management_node_keys, $useradd_string, "root");
                        }
                }
        }

        if ($user_standalone) {
                notify($ERRORS{'DEBUG'}, 0, "Standalone user setting single-use password");

                #Set password
                if ($self->changepasswd($computer_node_name, $username, $password)) {
                        notify($ERRORS{'OK'}, 0, "Successfully set password on useracct: $username on $computer_node_name");
                }
                else {
                        notify($ERRORS{'CRITICAL'}, 0, "Failed to set password on useracct: $username on $computer_node_name");
                        return 0;
                }
        } ## end if ($user_standalone)


        #Check image profile for allowed root access
        if ($imagemeta_rootaccess) {
                # Add to sudoers file
                #clear user from sudoers file to prevent dups
                my $clear_cmd = "sed -i -e \"/^$username .*/d\" /etc/sudoers";
                if (run_ssh_command($computer_node_name, $management_node_keys, $clear_cmd, "root")) {
                        notify($ERRORS{'DEBUG'}, 0, "cleared $username from /etc/sudoers");
                }
                else {
                        notify($ERRORS{'CRITICAL'}, 0, "failed to clear $username from /etc/sudoers");
                }
                my $sudoers_cmd = "echo \"$username ALL= NOPASSWD: ALL\" >> /etc/sudoers";
                if (run_ssh_command($computer_node_name, $management_node_keys, $sudoers_cmd, "root")) {
                        notify($ERRORS{'DEBUG'}, 0, "added $username to /etc/sudoers");
                }
                else {
                        notify($ERRORS{'CRITICAL'}, 0, "failed to add $username to /etc/sudoers");
                }
        } ## end if ($imagemeta_rootaccess)

        return 1;	
} ## end sub create_user

#/////////////////////////////////////////////////////////////////////////////

=head2 update_server_access

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub update_server_access {


}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
