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
use Net::Netmask;

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
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name       = $self->data->get_computer_node_name();
	notify($ERRORS{'OK'}, 0, "beginning Linux-specific image capture preparation tasks");
	

	if (!$self->file_exists("/root/.vclcontrol/vcl_exclude_list.sample")) {
      notify($ERRORS{'DEBUG'}, 0, "/root/.vclcontrol/vcl_exclude_list.sample does not exists");
		if(!$self->generate_vclcontrol_sample_files() ){
      	notify($ERRORS{'DEBUG'}, 0, "could not create /root/.vclcontrol/vcl_exclude_list.sample");
		}
   }
	
	# Force user off computer 
	if (!$self->logoff_user()) {
		notify($ERRORS{'WARNING'}, 0, "unable to log user off $computer_node_name");
	}

	# Remove user and clean external ssh file
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "deleted user from $computer_node_name");
	}

	#Clean up connection methods
	if($self->process_connect_methods("any", 1) ){
		notify($ERRORS{'OK'}, 0, "processed connection methods on $computer_node_name");
	}
	
	if(!$self->clean_iptables()) {
		return 0;
	}

	# Try to clear /tmp
	if ($self->execute("/usr/sbin/tmpwatch -f 0 /tmp; /bin/cp /dev/null /var/log/wtmp")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared /tmp on $computer_node_name");
	}

	# Clear SSH idenity keys from /root/.ssh 
	if (!$self->clear_private_keys()) {
	  notify($ERRORS{'WARNING'}, 0, "unable to clear known identity keys");
	}

	#Fetch exclude_list
	my @exclude_list = $self->get_exclude_list();

	if (@exclude_list ) {
		notify($ERRORS{'DEBUG'}, 0, "skipping files listed in exclude_list\n" . join("\n", @exclude_list));
	}
	
	#Remove files
	if(!(grep( /70-persistent-net.rules/ , @exclude_list ) ) ){
		if(!$self->delete_file("/etc/udev/rules.d/70-persistent-net.rules")){
			notify($ERRORS{'WARNING'}, 0, "unable to remove /etc/udev/rules.d/70-persistent-net.rules");
		}
	}
	
	if(!(grep( /\/var\/log\/secure/ , @exclude_list ) ) ){
		if(!$self->delete_file("/var/log/secure")){
			notify($ERRORS{'WARNING'}, 0, "unable to remove /var/log/secure");
		}
	}
	
	if(!(grep( /\/var\/log\/messages/ , @exclude_list ) ) ){
		if(!$self->delete_file("/var/log/messages")){
			notify($ERRORS{'WARNING'}, 0, "unable to remove /var/log/secure");
		}
	}
	
	# Write /etc/rc.local script
	if(!(grep( /rc.local/ , @exclude_list ) ) ){
		if (!$self->generate_rc_local()){
			notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/rc.local script on $computer_node_name");
			return;
		}
	}

	# Generate external_sshd_config
	if(!(grep( /\/etc\/ssh\/external_sshd_config/ , @exclude_list ) ) ){
		if(!$self->generate_ext_sshd_config()){
			notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/ssh/external_sshd_config on $computer_node_name");
			return;
		}
	}

	# Generate ext_sshd init script
	if(!(grep( /init.d\/ext_sshd/ , @exclude_list ) ) ){
		if(!$self->generate_ext_sshd_init()){
			notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/init.d/ext_sshd on $computer_node_name");
			return;
		}
	}

	# Configure the private and public interfaces to use DHCP
	if (!$self->enable_dhcp()) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable DHCP on the public and private interfaces");
		return 0;
	}
	
	# Shut the computer down
	if (!$self->shutdown()) {
		notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "Linux pre-capture steps complete");
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
	my $management_node_ip	  = $self->data->get_management_node_ipaddress();
	my $mn_private_ip 		  = $self->mn_os->get_private_ip_address();
	
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
	
	if($self->enable_firewall_port("tcp", "any", $mn_private_ip, 1) ){
      notify($ERRORS{'OK'}, 0, "added MN_Priv_IP $mn_private_ip to firewall on $computer_short_name");
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

=head2 restart_network_interface

 Parameters  : $interface_name
 Returns     :
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
	my $network_scripts_path = "/etc/sysconfig/network-scripts";
	
	# Restart the interface
	notify($ERRORS{'DEBUG'}, 0, "attempting to restart network interface $interface_name on $computer_name");
	my $interface_restart_command = "$network_scripts_path/ifdown $interface_name ; $network_scripts_path/ifup $interface_name";
	my ($interface_restart_exit_status, $interface_restart_output) = $self->execute($interface_restart_command);
	if (!defined($interface_restart_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to restart interface $interface_name on $computer_name: '$interface_restart_command'");
		return;
	}
	elsif ($interface_restart_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart network interface $interface_name on $computer_name, exit status: $interface_restart_exit_status, command: '$interface_restart_command', output:\n" . join("\n", @$interface_restart_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "restarted network interface $interface_name on $computer_name");
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
	my $server_request_id	  = $self->data->get_server_request_id();

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
	
	notify($ERRORS{'OK'}, 0, "server_request_id= $server_request_id");

	if ( $server_request_id ) {
		my $server_allow_user_list = $self->data->get_server_ssh_allow_users();
		notify($ERRORS{'OK'}, 0, "server_allow_user_list= $server_allow_user_list");
		if ( $server_allow_user_list ) {

			$cmd = "echo \"AllowUsers $server_allow_user_list\" >> /etc/ssh/external_sshd_config";
			if (run_ssh_command($computer_node_name, $identity, $cmd, "root")) {
				notify($ERRORS{'DEBUG'}, 0, "added AllowUsers $server_allow_user_list to external_sshd_config");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $server_allow_user_list to external_sshd_config");
			}
		}
	}

	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $identity, "/etc/init.d/ext_sshd stop; /etc/init.d/ext_sshd start", "root");

	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Stopping ext_sshd:/i) {
			#notify($ERRORS{'OK'},0,"stopping sshd on $computer_node_name ");
		}
		if ($l =~ /Starting ext_sshd:[  OK  ]/i) {
			notify($ERRORS{'OK'}, 0, "ext_sshd on $computer_node_name started");
		}
	}    #foreach
	notify($ERRORS{'OK'}, 0, "started ext_sshd on $computer_node_name");

	if($self->process_connect_methods("", 1) ){
		notify($ERRORS{'OK'}, 0, "processed connection methods on $computer_node_name setting 0.0.0.0 for all allowed ports");
	}

	
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
	my $mn_private_ip         = $self->mn_os->get_private_ip_address();

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
	
	#Clean up connection methods
   if($self->process_connect_methods($mn_private_ip, 1) ){
      notify($ERRORS{'OK'}, 0, "processed connection methods on $computer_node_name");
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
        push(@array2print, "#Use the /root/.vclcontrol/vcl_exclude_list to prevent vcld from updating this file.");
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
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
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
	
	my $wait_attempt_limit = 2;
	if ($self->wait_for_reboot($wait_attempt_limit)){
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
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
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
		
		my ($exit_status, $output) = $self->execute($command);
		
		if (defined $exit_status && $exit_status == 0) {
			notify($ERRORS{'DEBUG'}, 0, "executed command to shut down $computer_node_name");
		}
		else {
			if (!defined($output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to execute command to shut down $computer_node_name, attempting power off");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to shut down $computer_node_name, attempting power off, output:\n" . join("\n", @$output));
			}
			
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
                        if ($self->delete_user($username)) {
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
	
	my ($self) = shift;

	if (ref($self) !~ /linux/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }

	my ($server_allow_user_list) = shift;

        my $computer_node_name = $self->data->get_computer_node_name();
        my $identity           = $self->data->get_image_identity;


	if ( !$server_allow_user_list ) {
		my $server_allow_user_list = $self->data->get_server_ssh_allow_users();
	}
	
        notify($ERRORS{'OK'}, 0, "server_allow_user_list= $server_allow_user_list");
        if ( $server_allow_user_list ) {

             my $cmd = "echo \"AllowUsers $server_allow_user_list\" >> /etc/ssh/external_sshd_config";
             if (run_ssh_command($computer_node_name, $identity, $cmd, "root")) {
                 notify($ERRORS{'DEBUG'}, 0, "added AllowUsers $server_allow_user_list to external_sshd_config");
             }
             else {
                 notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $server_allow_user_list to external_sshd_config");
             }

				if ($self->execute("/etc/init.d/ext_sshd stop; sleep 2; /etc/init.d/ext_sshd start")) {
					notify($ERRORS{'DEBUG'}, 0, "restarted ext_sshd");
				}
        }
	
	return 1;

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
 Returns     : If service exists: 1
               If service does not exist: 0
               If error occurred: undefined
 Description : 

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	my $command = "/sbin/chkconfig --list $service_name";
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$service_name' service exists on $computer_node_name");
		return;
	}
	elsif (grep(/error reading information on service/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service does not exist on $computer_node_name");
		return 0;
	}
	elsif (defined($exit_status) && $exit_status == 0 ) {
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists");
		return 1;
	}
	elsif (defined($exit_status) && grep(/not referenced in any runlevel/i, @$output)) {
		# chkconfig may display the following if the service exists but has not been added:
		# service ext_sshd supports chkconfig, but is not referenced in any runlevel (run 'chkconfig --add ext_sshd')
		notify($ERRORS{'DEBUG'}, 0, "'$service_name' service exists but is not referenced in any runlevel: output:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$service_name' service exists, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : If service started: 1
               If service not started: 0
               If error occurred: undefined
 Description : 

=cut

sub start_service {
        my $self = shift;
        if (ref($self) !~ /linux/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }

        my $management_node_keys = $self->data->get_management_node_keys();
        my $computer_node_name   = $self->data->get_computer_node_name();

        my $service_name = shift;
        if (!$service_name) {
                notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
                return;
        }

	my $command = "/sbin/service $service_name start";
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
        if (defined($output) && grep(/failed/i, @{$output})) {
                notify($ERRORS{'DEBUG'}, 0, "service does not exist: $service_name");
                return 0;
        }
        elsif (defined($status) && $status == 0) {
                notify($ERRORS{'DEBUG'}, 0, "service exists: $service_name");
        }
        elsif (defined($status)) {
                notify($ERRORS{'WARNING'}, 0, "unable to determine if service exists: $service_name, exit status: $status, output:\n@{$output}");
                return;
        }
        else {
                notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to determine if service exists");
                return;
        }

        return 1;
	

}

#/////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : If service started: 1
               If service not started: 0
               If error occurred: undefined
 Description : 

=cut

sub stop_service {
        my $self = shift;
        if (ref($self) !~ /linux/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return;
        }

        my $management_node_keys = $self->data->get_management_node_keys();
        my $computer_node_name   = $self->data->get_computer_node_name();

        my $service_name = shift;
        if (!$service_name) {
                notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
                return;
        }

        my $command = "/sbin/service $service_name stop";
        my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
        if (defined($output) && grep(/failed/i, @{$output})) {
                notify($ERRORS{'DEBUG'}, 0, "service does not exist: $service_name");
                return 0;
        }
        elsif (defined($status) && $status == 0) {
                notify($ERRORS{'DEBUG'}, 0, "service exists: $service_name");
        }
        elsif (defined($status)) {
                notify($ERRORS{'WARNING'}, 0, "unable to determine if service exists: $service_name, exit status: $status, output:\n@{$output}");
                return;
        }
        else {
                notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to determine if service exists");
                return;
        }

        return 1;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_connection

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

	my $management_node_keys 	= $self->data->get_management_node_keys();
	my $computer_node_name   	= $self->data->get_computer_node_name();
	my $remote_ip 			= $self->data->get_reservation_remote_ip();
	my $computer_ip_address   	= $self->data->get_computer_ip_address();
	my $request_state_name   	= $self->data->get_request_state_name();
	my $username = $self->data->get_user_login_id();

	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
		return "failed";
	}
	
	my $ret_val = "no";	
	my $command = "netstat -an";
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, '', '', 1);
	notify($ERRORS{'DEBUG'}, 0, "checking connections on node $computer_node_name on port $port");
	foreach my $line (@{$output}) {
		if ($line =~ /Connection refused|Permission denied/) {
                    chomp($line);
                    notify($ERRORS{'WARNING'}, 0, "$line");
                    if ($request_state_name =~ /reserved/) {
                        $ret_val = "failed";
                    }
                    else {
                         $ret_val = "timeout";
                    }
                    return $ret_val;
                 } ## end if ($line =~ /Connection refused|Permission denied/)
                 if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($computer_ip_address:$port)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
                     if ($4 eq $remote_ip) {
                         $ret_val = "connected";
                         return $ret_val;
                     }
                     else {
							  my $new_remote_ip = $4;
                    	  #this isn't the defined remoteIP
								# Confirm the user is logged in
								# Is user logged in
                        if (!$self->user_logged_in()) {
                           notify($ERRORS{'OK'}, 0, "Detected $new_remote_ip is connected. $username is not logged in yet. Returning no connection");
                           $ret_val = "no";
                           return $ret_val;
                        }
                        else {	
										  $self->data->set_reservation_remote_ip($new_remote_ip);	
										  notify($ERRORS{'OK'}, 0, "Updating reservation remote_ip with $new_remote_ip");
										  $ret_val = "conn_wrong_ip";
										  return $ret_val;
								}
                     }
                 }    # tcp check
	}
	return $ret_val;
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
	my ($cpu_cores) = map { $_ =~ /cpu cores\s*:\s*(\d+)/ } @$output;
	$cpu_cores = 1 unless $cpu_cores;
	
	my ($siblings) = map { $_ =~ /siblings\s*:\s*(\d+)/ } @$output;
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
			 hyperthreading enabled: $hyperthreading_enabled");
	
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
	
	my ($mhz) = map { $_ =~ /cpu MHz\s*:\s*(\d+)/ } @$output;
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
	my ($memory_kb) = map { $_ =~ /Memory:.*\/(\d+)k available/ } @$output;
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

=head2 sanitize_firewall
 
  Parameters  : $scope (optional), 
  Returns     : boolean
  Description : Removes all entries for INUPT chain and Sets iptables firewall for private management node IP
 
=cut

sub sanitize_firewall {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	my $scope = shift;
	if(!defined($scope)) {
		notify($ERRORS{'CRITICAL'}, 0, "scope variable was not passed in as an arguement");
      return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
   my $mn_private_ip = $self->mn_os->get_private_ip_address();
	
	my $firewall_configuration = $self->get_firewall_configuration() || return;
   my $chain;
   my $iptables_del_cmd;
	my $INPUT_CHAIN = "INPUT";

   for my $num (sort keys %{$firewall_configuration->{$INPUT_CHAIN}} ) {

	
	}


}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_firewall_port
 
  Parameters  : $protocol, $port, $scope (optional), $overwrite_existing (optional), $name (optional), $description (optional)
  Returns     : boolean
  Description : Updates iptables for given port for collect IPaddress range and mode
 
=cut

sub enable_firewall_port {
	my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }
	
	# Check to see if this distro has iptables
	# If not return 1 so it does not fail
	if (!($self->service_exists("iptables"))) {
		notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");	
		return 1;
	}
	
	my ($protocol, $port, $scope_argument, $overwrite_existing, $name, $description) = @_;
	if (!defined($protocol) || !defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "protocol and port arguments were not supplied");
		return;
	}
	
   my $computer_node_name = $self->data->get_computer_node_name();
	my $mn_private_ip = $self->mn_os->get_private_ip_address();
	
	$protocol = lc($protocol);
	
	$scope_argument = '' if (!defined($scope_argument));

   $name = '' if !$name;
   $description = '' if !$description;

   my $scope;

	my $INPUT_CHAIN = "INPUT";

	
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	my $chain;
	my $iptables_del_cmd;

	for my $num (sort keys %{$firewall_configuration->{$INPUT_CHAIN}} ) {
   	my $existing_scope = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{scope} || '';
   	my $existing_name = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{name} || '';
   	my $existing_description = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{name} || '';
	
   	if ($existing_scope) {
			notify($ERRORS{'DEBUG'}, 0, " num= $num protocol= $protocol port= $port existing_scope= $existing_scope existing_name= $existing_name existing_description= $existing_description ");

			if ($overwrite_existing) {
         	$scope = $self->parse_firewall_scope($scope_argument);
				$iptables_del_cmd = "iptables -D $INPUT_CHAIN $num";
         	if (!$scope) {
            	notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument: '$scope_argument'");
            	return;
         	}

         	notify($ERRORS{'DEBUG'}, 0, "existing firewall opening on $computer_node_name will be replaced:\n" .
            "name: '$existing_name'\n" .
				"num: '$num'\n" .
            "protocol: $protocol\n" .
				"port/type: $port\n" .
            "existing scope: '$existing_scope'\n" .
            "new scope: $scope\n" .
            "overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
         	);
      	}
			else {
         	my $parsed_existing_scope = $self->parse_firewall_scope($existing_scope);
         	if (!$parsed_existing_scope) {
            	notify($ERRORS{'WARNING'}, 0, "failed to parse existing firewall scope: '$existing_scope'");
           	 return;
         	}

         	$scope = $self->parse_firewall_scope("$scope_argument,$existing_scope");
         	if (!$scope) {
            	notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument appended with existing scope: '$scope_argument,$existing_scope'");
            	return;
         	}

         	if ($scope eq $parsed_existing_scope) {
            	notify($ERRORS{'DEBUG'}, 0, "firewall is already open on $computer_node_name, existing scope matches scope argument:\n" .
               "name: '$existing_name'\n" .
               "protocol: $protocol\n" .
               "port/type: $port\n" .
               "scope: $scope\n" .
               "overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
            	);
            	return 1;
         	}
      	}
		}
		else {
			next;
   	}
	}

     	if(!$scope) {
			$scope = $self->parse_firewall_scope($scope_argument);
     		if (!$scope) {
        		notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument: '$scope_argument'");
        		return;
     		}
		}

  
   	$name = "VCL: allow $protocol/$port from $scope" if !$name;

   	$name = substr($name, 0, 60) . "..." if length($name) > 60;

		my $command;

		if ($iptables_del_cmd ){
			$command = "$iptables_del_cmd ; ";
		
		}

		$command .= "/sbin/iptables -I INPUT 1 -m state --state NEW,RELATED,ESTABLISHED -m $protocol -p $protocol -j ACCEPT";
	
		if ($port =~ /\d+/){
			$command .= " --dport $port";
		}

		if ($scope_argument) {
		#	if($scope_argument eq '0.0.0.0') {
		#		$scope_argument .= "/0";
		#	}
		#	else {
		#		$scope_argument .= "/24";	
		#	}	
	
		$command .= " -s $scope_argument";
	}

	# Make backup copy of original iptables configuration
	my $iptables_backup_file_path = "/etc/sysconfig/iptables_pre_$port";
	if ($self->copy_file("/etc/sysconfig/iptables", $iptables_backup_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "backed up original iptables file to: '$iptables_backup_file_path'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to back up original iptables file to: '$iptables_backup_file_path'");
	}
	
	# Add rule
	notify($ERRORS{'DEBUG'}, 0, "attempting to execute command on $computer_node_name: '$command'");
	my ($status, $output) = $self->execute($command);	
	if (defined $status && $status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed command on $computer_node_name: '$command'");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "output from iptables:\n" . join("\n", @$output));
	}
	
	# Save rules to sysconfig/iptables -- incase of reboot
	my $iptables_save_cmd = "/sbin/iptables-save > /etc/sysconfig/iptables";
	my ($status_save, $output_save) = $self->execute($iptables_save_cmd);	
	if (defined $status_save && $status_save == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed command $iptables_save_cmd on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_firewall_port
 
  Parameters  : none
  Returns     : 1 successful, 0 failed
  Description : updates iptables for given port for collect IPaddress range and mode
 
=cut

sub disable_firewall_port {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	# Check to see if this distro has iptables
   # If not return 1 so it does not fail
   if (!($self->service_exists("iptables"))) {
      notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
      return 1;
   }
	
	my ($protocol, $port, $scope_argument, $overwrite_existing, $name, $description) = @_;
	if (!defined($protocol) || !defined($port)) {
     notify($ERRORS{'WARNING'}, 0, "protocol and port arguments were not supplied");
     return;
	}

   my $computer_node_name = $self->data->get_computer_node_name();
	my $mn_private_ip = $self->mn_os->get_private_ip_address();

   $protocol = lc($protocol);

   $scope_argument = '' if (!defined($scope_argument));

   $name = '' if !$name;
   $description = '' if !$description;

   my $scope;

   my $INPUT_CHAIN = "INPUT";

   my $firewall_configuration = $self->get_firewall_configuration() || return;
   my $chain;
   my $command;

   for my $num (sort keys %{$firewall_configuration->{$INPUT_CHAIN}} ) {
		my $existing_scope = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{scope} || '';
		my $existing_name = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{name} || '';
		if($existing_scope) {
			$command = "iptables -D $INPUT_CHAIN $num";

			notify($ERRORS{'DEBUG'}, 0, "attempting to execute command on $computer_node_name: '$command'");
   		my ($status, $output) = $self->execute($command);
   		if (defined $status && $status == 0) {
       		notify($ERRORS{'DEBUG'}, 0, "executed command on $computer_node_name: '$command'");
   		}
   		else {
       		notify($ERRORS{'WARNING'}, 0, "output from iptables:\n" . join("\n", @$output));
   		}

   		# Save rules to sysconfig/iptables -- incase of reboot
   		my $iptables_save_cmd = "/sbin/iptables-save > /etc/sysconfig/iptables";
   		my ($status_save, $output_save) = $self->execute($iptables_save_cmd);
   		if (defined $status_save && $status_save == 0) {
       		notify($ERRORS{'DEBUG'}, 0, "executed command $iptables_save_cmd on $computer_node_name");
   		}
		}
	}
   return 1;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_exclude_list
 
  Parameters  : none
  Returns     : array, empty or contents of exclude list
  Description : 
 
=cut

sub get_exclude_list {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Does /etc/vcl_exclude_list exists
	my $filename = "/root/.vclcontrol/vcl_exclude_list";
	if(!$self->file_exists($filename) ) {
		return;
	}
	
	#Get the list
	my $command = "cat $filename";	
	my ($status,$output) = $self->execute($command);
	
	if (!defined($output)) {
      notify($ERRORS{'DEBUG'}, 0, "empty exclude_list from $computer_node_name");
      return;
   }
	
	return @$output;		

}

#/////////////////////////////////////////////////////////////////////////////

=head2 generate_exclude_list_sample
 
  Parameters  : none
  Returns     :boolean
  Description : Generates sample exclude list for users to assist in customizing
 
=cut

sub generate_vclcontrol_sample_files {

	my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	my $request_id               = $self->data->get_request_id();
   my $management_node_keys     = $self->data->get_management_node_keys();
   my $computer_short_name      = $self->data->get_computer_short_name();
   my $computer_node_name       = $self->data->get_computer_node_name();
	
	my @array2print;

   push(@array2print, '#' . "\n");
   push(@array2print, '# /root/.vclcontrol/vcl_exclude_list' . "\n");
   push(@array2print, '# List any files here that vcld should exclude updating  during the capture process' . "\n");
   push(@array2print, "# Format is one file per line including the full path name". "\n");
   push(@array2print, "\n");

   #write to tmpfile
   my $tmpfile = "/tmp/$request_id.vcl_exclude_list.sample";
   if (open(TMP, ">$tmpfile")) {
      print TMP @array2print;
      close(TMP);
   }
   else {
      #print "could not write $tmpfile $!\n";
      notify($ERRORS{'OK'}, 0, "could not write $tmpfile $!");
      return 0;
   }
	
	# Make directory
	my $mkdir = "mkdir /root/.vclcontrol";
	
	if($self->execute($mkdir)) {
		notify($ERRORS{'DEBUG'}, 0, "created /root/.vclcontrol directory");
	}
	
   #copy to node
   if (run_scp_command($tmpfile, "$computer_node_name:/root/.vclcontrol/vcl_exclude_list.sample", $management_node_keys)) {
   }
   else{
      return 0;
   }

	return 1;	

}

=head2 get_firewall_configuration

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about the open firewall ports on the
               computer and constructs a hash. The hash keys are protocol names.
               Each protocol key contains a hash reference. The keys are either
               port numbers or ICMP types.
               Example:
               
                  "ICMP" => {
                    8 => {
                      "description" => "Allow inbound echo request"
                    }
                  },
                  "TCP" => {
                    22 => {
                      "interface_names" => [
                        "Local Area Connection 3"
                      ],
                      "name" => "sshd"
                    },
                    3389 => {
                      "name" => "Remote Desktop",
                      "scope" => "192.168.53.54/255.255.255.255"
                    },

=cut

sub get_firewall_configuration {
   my $self = shift;
   if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	my $computer_node_name = $self->data->get_computer_node_name();	
	my $firewall_configuration = {};

	# Check to see if this distro has iptables
   # If not return 1 so it does not fail
   if (!($self->service_exists("iptables"))) {
      notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
      return 1;
   }
	
	my $port_command = "iptables -L --line-number -n";
	my ($iptables_exit_status, $output_iptables) = $self->execute($port_command);
   if (!defined($output_iptables)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run command to show open firewall ports on $computer_node_name");
      return;
   }

	#notify($ERRORS{'DEBUG'}, 0, "output from iptables:\n" . join("\n", @$output_iptables));
	

	# Execute the iptables -L --line-number -n command to retrieve firewall port openings
   # Expected output:
	#Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
	#num  target     prot opt source               destination         
	#1    RH-Firewall-1-INPUT  all  --  0.0.0.0/0            0.0.0.0/0           

	#Chain FORWARD (policy ACCEPT)
	#num  target     prot opt source               destination         
	#1    RH-Firewall-1-INPUT  all  --  0.0.0.0/0            0.0.0.0/0           

	#Chain OUTPUT (policy ACCEPT)
	#num  target     prot opt source               destination         

	#Chain RH-Firewall-1-INPUT (2 references)
	#num  target     prot opt source               destination         
	#1    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           
	#2    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           
	#3    ACCEPT     icmp --  0.0.0.0/0            0.0.0.0/0           icmp type 255 
	#4    ACCEPT     esp  --  0.0.0.0/0            0.0.0.0/0           
	#5    ACCEPT     ah   --  0.0.0.0/0            0.0.0.0/0           
	#6    ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED 
	#7    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:22 
	#8    ACCEPT     tcp  --  0.0.0.0/0            0.0.0.0/0           state NEW tcp dpt:3389 
	#9    REJECT     all  --  0.0.0.0/0            0.0.0.0/0           reject-with icmp-host-prohibited


   my $chain;
   my $previous_protocol;
   my $previous_port;

	for my $line (@$output_iptables) {
		if ($line =~ /^Chain\s+(\S+)\s+(.*)/ig) {
         $chain = $1;
			notify($ERRORS{'DEBUG'}, 0, "output Chain = $chain");
      }
		elsif($line =~ /^(\d+)\s+([A-Z]*)\s+([a-z]*)\s+(--)\s+(\S+)\s+(\S+)\s+(.*)/ig ) {
		
			my $num = $1;
			my $target = $2;
			my $protocol = $3;
			my $scope = $5;
			my $destination =$6;
			my $port_string = $7 if (defined($7));
			my $port = ''; 
			my $name;
		
		
			if (defined($port_string) && ($port_string =~ /([\s(a-zA-Z)]*)(dpt:)(\d+)/ig )){
				$port = $3;	
				notify($ERRORS{'DEBUG'}, 0, "output rule: $num, $target, $protocol, $scope, $destination, $port ");
			}

			if (!$port) {
				$port = "any";
			}
			
			my $services_cmd = "cat /etc/services";
			my ($services_status, $service_output) = $self->execute($services_cmd);
			if (!defined($service_output)) {
      		notify($ERRORS{'DEBUG'}, 0, "failed to get /etc/services");
   		}
   		else {
				for my $sline (@$service_output) {
					if ( $sline =~ /(^[_-a-zA-Z1-9]+)\s+($port\/$protocol)\s+(.*) /ig ){
						$name = $1;
					} 
				}
				
			}		
			
			$name = $port if (!$name);

			$firewall_configuration->{$chain}->{$num}{$protocol}{$port}{name}= $name;
			$firewall_configuration->{$chain}->{$num}{$protocol}{$port}{number}= $num;
			$firewall_configuration->{$chain}->{$num}{$protocol}{$port}{scope}= $scope;
			$firewall_configuration->{$chain}->{$num}{$protocol}{$port}{target}= $target;
			$firewall_configuration->{$chain}->{$num}{$protocol}{$port}{destination}= $destination;
			

			if (!defined($previous_protocol) ||
             !defined($previous_port) ||
             !defined($firewall_configuration->{$previous_protocol}) ||
             !defined($firewall_configuration->{$previous_protocol}{$previous_port})
             ) {
         	next;
      	}
			elsif ($scope !~ /0.0.0.0\/0/) {
				$firewall_configuration->{$previous_protocol}{$previous_port}{scope} = $scope;
			}
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved firewall configuration from $computer_node_name:\n" . format_data($firewall_configuration));
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
   if (!@scope_strings) {
      notify($ERRORS{'WARNING'}, 0, "scope array argument was not supplied");
      return;
   }

   my @netmask_objects;

   for my $scope_string (@scope_strings) {
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
         notify($ERRORS{'DEBUG'}, 0, "parsed firewall scope:\n" .
            "argument: '$argument_string'\n" .
            "result: '$scope_result_string'\n" .
            "IP address ranges:\n" . join(", ", @ip_address_ranges)
         );
      }
      return $scope_result_string;
   }
   else {
      notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope: '" . join(",", @scope_strings) . "', no Net::Netmask objects were created");
      return;
   }
}


#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_compare_update

 Parameters  : @scope_strings
 Returns     : 0 , 1
 Description : Compare iptables for listed remote IP address in reservation

=cut

sub firewall_compare_update  {
	my $self = shift;
   if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }
	
	# Check to see if this distro has iptables
   # If not return 1 so it does not fail
   if (!($self->service_exists("iptables"))) {
      notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
      return 1;
   }
	
	my $computer_node_name = $self->data->get_computer_node_name();
   my $imagerevision_id   = $self->data->get_imagerevision_id();
	my $remote_ip 			  = $self->data->get_reservation_remote_ip();
	
	#collect connection_methods
	#collect firewall_config
	#For each port defined in connection_methods
	#compare rule source address with remote_IP address
	
   # Retrieve the connect method info hash
   my $connect_method_info = get_connect_method_info($imagerevision_id);
   if (!$connect_method_info) {
      notify($ERRORS{'WARNING'}, 0, "no connect methods are configured for image revision $imagerevision_id");
      return;
   }

	# Retrieve the firewall configuration
   my $INPUT_CHAIN = "INPUT";
   my $firewall_configuration = $self->get_firewall_configuration() || return;	
		
	for my $connect_method_id (sort keys %{$connect_method_info} ) {
             
      my $name            = $connect_method_info->{$connect_method_id}{name};
      my $description     = $connect_method_info->{$connect_method_id}{description};
      my $protocol        = $connect_method_info->{$connect_method_id}{protocol} || 'TCP';
      my $port            = $connect_method_info->{$connect_method_id}{port};
		my $scope;
	
		$protocol = lc($protocol);
		
		for my $num (sort keys %{$firewall_configuration->{$INPUT_CHAIN}} ) {
			my $existing_scope = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{scope} || '';
			if(!$existing_scope ) {

			}
			else {
				my $parsed_existing_scope = $self->parse_firewall_scope($existing_scope);
				if (!$parsed_existing_scope) {
                notify($ERRORS{'WARNING'}, 0, "failed to parse existing firewall scope: '$existing_scope'");
                return;
            }	
				$scope = $self->parse_firewall_scope("$remote_ip,$existing_scope");
            if (!$scope) {
                notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument appended with existing scope: '$remote_ip,$existing_scope'");
                return;
            }
			
				if ($scope eq $parsed_existing_scope) {
                notify($ERRORS{'DEBUG'}, 0, "firewall is already open on $computer_node_name, existing scope matches scope argument:\n" .
               "name: '$name'\n" .
               "protocol: $protocol\n" .
               "port/type: $port\n" .
               "scope: $scope\n");
                return 1;
            }
				else {
					if ($self->enable_firewall_port($protocol, $port, "$remote_ip/24", 0)) {
                   notify($ERRORS{'OK'}, 0, "opened firewall port $port on $computer_node_name for $remote_ip $name connect method");
               }
				}
				

			}			
		}
	}

	return 1;	

}

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_iptables

 Parameters  : 
 Returns     : 0 , 1
 Description : Deletes rules with any leftover -s addresses 

=cut

sub clean_iptables {
	my $self = shift;
   if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }
	
	# Check to see if this distro has iptables
   # If not return 1 so it does not fail
   if (!($self->service_exists("iptables"))) {
      notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
      return 1;
   }
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $reservation_id                  = $self->data->get_reservation_id();
	my $management_node_keys  = $self->data->get_management_node_keys();

   # Retrieve the firewall configuration
   my $INPUT_CHAIN = "INPUT";
	
	# Retrieve the iptables file to work on locally	
	my $tmpfile = "/tmp/" . $reservation_id . "_iptables";
	my $source_file_path = "/etc/sysconfig/iptables";
	if (run_scp_command("$computer_node_name:\"$source_file_path\"", $tmpfile, $management_node_keys)) {
		my @lines;
		if(open(IPTAB_TMPFILE, $tmpfile)){
			@lines = <IPTAB_TMPFILE>;
			close(IPTAB_TMPFILE);	
		}
		foreach my $line (@lines){
			if ($line =~ s/-A INPUT -s .*\n//) {
         }
		}
	
		#Rewrite array to tmpfile
		if(open(IPTAB_TMPFILE, ">$tmpfile")){
			print IPTAB_TMPFILE @lines;
			close (IPTAB_TMPFILE);
		}
	
		# Copy iptables file back to node
		if (run_scp_command($tmpfile, "$computer_node_name:\"$source_file_path\"", $management_node_keys)) {
			notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $computer_node_name $source_file_path");
		}
	}	
	

	#my $command = "sed -i -e '/-A INPUT -s */d' /etc/sysconfig/iptables";
   #my ($status, $output) = $self->execute($command);	
	
	#if (defined $status && $status == 0) {
   #   notify($ERRORS{'DEBUG'}, 0, "executed command $command on $computer_node_name");
   #}
   #else {
   #   notify($ERRORS{'WARNING'}, 0, "output from iptables:" . join("\n", @$output));
   #}
        
	#restart iptables
   my $command = "/etc/init.d/iptables restart";
   my ($status_iptables,$output_iptables) = $self->execute($command);
   if (defined $status_iptables && $status_iptables == 0) {
		notify($ERRORS{'DEBUG'}, 0, "executed command $command on $computer_node_name");
   }
   else {
      notify($ERRORS{'WARNING'}, 0, "output from iptables:" . join("\n", @$output_iptables));
   }
	
	if ($self->wait_for_ssh(0)) {
   	return 1;
	}
	else { 
		notify($ERRORS{'CRITICAL'}, 0, "not able to login via ssh after cleaning_iptables");
		return 0;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 user_logged_in

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub user_logged_in {
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

   # Remove spaces from beginning and end of username argument
   # Fixes problem if string containing only spaces is passed
   $username =~ s/(^\s+|\s+$)//g if $username;

   # Check if username argument was passed
   if (!$username) {
      $username = $self->data->get_user_login_id();
   }
   notify($ERRORS{'DEBUG'}, 0, "checking if $username is logged in to $computer_node_name");

	my $cmd = "users";
	my ($logged_in_status, $logged_in_output) = $self->execute($cmd);
   if (!defined($logged_in_output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run who command ");
      return;
   }
   elsif (grep(/$username/i, @$logged_in_output)) {
		notify($ERRORS{'DEBUG'}, 0, "username $username is logged into $computer_node_name\n" . join("\n", @$logged_in_output));
		return 1;
	
	}
	
	
	return 0;	

}


##/////////////////////////////////////////////////////////////////////////////
1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
