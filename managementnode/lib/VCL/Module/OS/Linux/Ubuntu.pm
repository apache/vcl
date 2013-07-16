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

##############################################################################
package VCL::Module::OS::Linux::Ubuntu;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_iptables

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub clean_iptables {
	my $self = shift;
   if (ref($self) !~ /ubuntu/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	# Check to see if this distro has iptables
   if (!$self->service_exists("iptables")) {
      notify($ERRORS{'WARNING'}, 0, "iptables service does not exist on this OS");
      return 1;
   }
	

   my $computer_node_name = $self->data->get_computer_node_name();
   my $reservation_id = $self->data->get_reservation_id();
   my $management_node_keys = $self->data->get_management_node_keys();
	

   # Retrieve the iptables file to work on locally 
   my $tmpfile = "/tmp/" . $reservation_id . "_iptables";
   my $source_file_path = "/etc/iptables.rules";
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

   #restart iptables
   my $command = "iptables -P INPUT ACCEPT;iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -F; iptables-restore < /etc/iptables.rules";
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

=head2 clean_known_files

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub clean_known_files {
	my $self = shift;
    if (ref($self) !~ /ubuntu/i) {
       notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
       return 0;
    }	
	
	my $computer_node_name = $self->data->get_computer_node_name();

	# Clear SSH idenity keys from /root/.ssh 
   if (!$self->clear_private_keys()) {
     notify($ERRORS{'WARNING'}, 0, "unable to clear known identity keys");
   }
	
	# Try to clear /tmp
   if ($self->execute("/bin/cp /dev/null /var/log/wtmp")) {
      notify($ERRORS{'DEBUG'}, 0, "cleared /var/log/wtmp on $computer_node_name");
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
   
   if(!(grep( /\/var\/log\/auth/ , @exclude_list ) ) ){ 
      if(!$self->execute("cp /dev/null /var/log/auth.log")){
         notify($ERRORS{'WARNING'}, 0, "unable to overwrite  /var/log/auth.log");
      }    
   }
   
   if(!(grep( /\/var\/log\/lastlog/ , @exclude_list ) ) ){ 
      if(!$self->execute("cp /dev/null /var/log/lastlog")){
         notify($ERRORS{'WARNING'}, 0, "unable to overwrite /var/log/lastlog");
      }    
   }

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_dhcp

 Parameters  : $interface_name (optional)
 Returns     : boolean
 Description : Configures /etc/network/interfaces file so that DHCP is enabled
               for the interface. If no argument is supplied, DHCP is enabled
               for the public and private interfaces.

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
	
	my $interfaces_file_path = '/etc/network/interfaces';
	for my $interface_name (@interface_names) {
		# Remove existing lines from the interfaces file which contain the interface name
		$self->remove_lines_from_file($interfaces_file_path, $interface_name) || return;
		
		# Add line to end of interfaces file
		my $interface_string = "auto $interface_name\n";
		$interface_string .= "iface $interface_name inet dhcp\n";
		$self->append_text_file($interfaces_file_path, $interface_string) || return;
	}
	
	return 1;
}

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

   # change the privileged account passwords on the blade images
	my $computer_short_name = shift;
   my $account = shift;
   my $passwd = shift;

   my $management_node_keys = $self->data->get_management_node_keys();
	
	if($computer_short_name) {
		$computer_short_name = $self->data->get_computer_short_name();
	}


	if(!defined($account)) {
		$account = $self->data->get_user_login_id();
	}
	
	
   $passwd = getpw(15) if (!(defined($passwd)));

	my $command = "echo $account:$passwd | chpasswd";
	
	my ($exit_status, $output) = $self->execute($command);
   if (!defined($output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run command to determine if file or directory exists on $computer_short_name:\ncommand: '$command'");
      return;
   }
   elsif (grep(/token manipulation error/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to change password fro $account on $computer_short_name:\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
      return;
   }
   elsif (grep(/stat: /i, @$output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to determine if file or directory exists on $computer_short_name:\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
      return;
   }	

	notify($ERRORS{'OK'}, 0, "changed password for account: $account");	
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
	#can produce large output, if you need to monitor the configuration setting uncomment the below output statement
   #notify($ERRORS{'DEBUG'}, 0, "retrieved network configuration:\n" . format_data($self->{network_configuration}));
   return $self->{network_configuration};
		
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
   if (!$self->service_exists("iptables")) {
      notify($ERRORS{'WARNING'}, 0, "iptables service does not exist on this OS");
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

	my $scope;
	
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
   if (!$self->service_exists("iptables")) {
      notify($ERRORS{'WARNING'}, 0, "iptables service does not exist on this OS");
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

	return 1;

}

#/////////////////////////////////////////////////////////////////////////////

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
   if (!$self->service_exists("iptables")) {
      notify($ERRORS{'WARNING'}, 0, "iptables service does not exist on this OS");
      return {};
   }
   
   my $port_command = "ufw status numbered";
   my ($iptables_exit_status, $output_iptables) = $self->execute($port_command);
   if (!defined($output_iptables)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run command to show open firewall ports on $computer_node_name");
      return;
   }

	my $status;
	my $chain = "INPUT";
   my $previous_protocol;
   my $previous_port;

   for my $line (@$output_iptables) {
      if ($line =~ /^Status: (inactive|active)/ig) {
         $status = $1;
         notify($ERRORS{'DEBUG'}, 0, "output Chain = $chain");
			if ($status =~ /inactive/i) {
				return;	
			}
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

   my $computer_name = $self->data->get_computer_short_name();
	my $request_id            = $self->data->get_request_id();
	my $server_request_id     = $self->data->get_server_request_id();
	my $management_node_keys     = $self->data->get_management_node_keys();

   my $server_request_fixedIP       = $self->data->get_server_request_fixedIP();

	
  	# Make sure public IP configuration is static or this is a server request
   my $ip_configuration = $self->data->get_management_node_public_ip_configuration();
   
   if ($ip_configuration !~ /static/i) {
      if( !$server_request_fixedIP ) {
         notify($ERRORS{'WARNING'}, 0, "static public address can only be set if IP configuration is static or is a server request, current value: $ip_configuration \nserver_request_fixedIP=$server_request_fixedIP");
         return;
      }    
   }

   # Get the IP configuration
   my $interface_name = $self->get_public_interface_name() || '<undefined>';
   my $ip_address = $self->data->get_computer_ip_address() || '<undefined>';
   my $subnet_mask = $self->data->get_management_node_public_subnet_mask() || '<undefined>';
   my $default_gateway = $self->data->get_management_node_public_default_gateway() || '<undefined>';
   my @dns_servers = $self->data->get_management_node_public_dns_servers();

   if ($server_request_fixedIP) {
      $ip_address = $server_request_fixedIP;
      $subnet_mask = $self->data->get_server_request_netmask();
      $default_gateway = $self->data->get_server_request_router();
      @dns_servers = $self->data->get_server_request_DNSservers();
   }

   # Make sure required info was retrieved
   if ("$interface_name $ip_address $subnet_mask $default_gateway" =~ /undefined/) {
      notify($ERRORS{'WARNING'}, 0, "failed to retrieve required network configuration for $computer_name");
      return;
   }
   else {
      notify($ERRORS{'OK'}, 0, "attempting to set static public IP address on $computer_name");
   }
	
	#Try to ping address to make sure it's available
   #FIXME  -- need to add other tests for checking ip_address is or is not available.
   if(_pingnode($ip_address)) {
      notify($ERRORS{'WARNING'}, 0, "ip_address $ip_address is pingable, can not assign to $computer_name ");
      return;
   }

   # Assemble the ifcfg file path
   my $network_interfaces_file = "/etc/network/interfaces";
	my $network_interfaces_file_default = "/etc/network/interfaces";
   notify($ERRORS{'DEBUG'}, 0, "interface file path: $network_interfaces_file");
	
	if($self->execute("cp network_interfaces_file /etc/network/interfaces_orig")) {
		notify($ERRORS{'OK'}, 0, "Created backup of $network_interfaces_file");
	}
		
	#Get interfaces file
	my $tmpfile = "/tmp/$request_id.interfaces";
   if (run_scp_command("$computer_name:$network_interfaces_file", $tmpfile, $management_node_keys)) {
      notify($ERRORS{'DEBUG'}, 0, "copied sshd init script from $computer_name for local processing");
   }
   else{
      notify($ERRORS{'WARNING'}, 0, "failed to copied ssh init script from $computer_name for local processing");
      return 0;
   }

	my @interfaces = read_file_to_array($tmpfile);
	#Build new interfaces file
	my @new_interfaces_file;

	foreach my $l (@interfaces) {
		push(@new_interfaces_file, $l) if($l =~ /^(#.*)/ );
		push(@new_interfaces_file, $l) if($l =~ /^auto lo/);
		push(@new_interfaces_file, $l) if($l =~ /^\n$/);

		if($l =~ /^iface/) {
			push(@new_interfaces_file, $l) if($l !~ /$interface_name/ );
		}	
	
		if($l =~ /^iface $interface_name/) {
			push(@new_interfaces_file, "iface $interface_name inet static\n");
			push(@new_interfaces_file, "address $ip_address\n");
			push(@new_interfaces_file, "netmask $subnet_mask\n");
			push(@new_interfaces_file, "gateway $default_gateway\n");
		}
	
	}
	
	notify($ERRORS{'OK'}, 0, "output:\n" . format_data(@new_interfaces_file));
	#Clear temp file
	unlink($tmpfile);
	#Write array to file	
	if(open(FILE, ">$tmpfile")){
      print FILE @new_interfaces_file;
      close FILE;
   }

   #copy temp file to node
   if (run_scp_command($tmpfile, "$computer_name:/etc/network/interfaces", $management_node_keys)) {
      notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $computer_name:/etc/network/interfaces");
   }
   else{
      notify($ERRORS{'WARNING'}, 0, "failed to copied $tmpfile to $computer_name:/etc/network/interfaces");
      return 0;
   }
   unlink($tmpfile);
	

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

   my $ext_sshd_config_file_path = '/etc/ssh/external_sshd_config';
	
	# Remove existing ListenAddress lines from external_sshd_config
	$self->remove_lines_from_file($ext_sshd_config_file_path, 'ListenAddress') || return;
	
	# Add ListenAddress line to the end of the file
	$self->append_text_file($ext_sshd_config_file_path, "ListenAddress $ip_address\n") || return;

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
  
   # Restart the interface
   notify($ERRORS{'DEBUG'}, 0, "attempting to restart network interface $interface_name on $computer_name");
   my $interface_restart_command = "/sbin/ifdown $interface_name ; /sbin/ifup $interface_name";
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

=head2 firewall_compare_update

 Parameters  : @scope_strings
 Returns     : 0 , 1
 Description : Compare iptables for listed remote IP address in reservation

=cut

sub firewall_compare_update {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check to see if this distro has iptables
	# If not return 1 so it does not fail
	if (!($self->service_exists("ufw"))) {
		notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
		return 1;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $imagerevision_id   = $self->data->get_imagerevision_id();
	my $remote_ip          = $self->data->get_reservation_remote_ip();
	
	# collect connection_methods
	# collect firewall_config
	# For each port defined in connection_methods
	# compare rule source address with remote_IP address
	
	# Retrieve the connect method info hash
	my $connect_method_info = get_connect_method_info($imagerevision_id);
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "no connect methods are configured for image revision $imagerevision_id");
		return;
	}
	
	# Retrieve the firewall configuration
	my $INPUT_CHAIN = "INPUT";
	my $firewall_configuration = $self->get_firewall_configuration() || return;
	
	for my $connect_method_id (sort keys %{$connect_method_info}) {
		
		my $name        = $connect_method_info->{$connect_method_id}{name};
		my $description = $connect_method_info->{$connect_method_id}{description};
		my $protocol    = $connect_method_info->{$connect_method_id}{protocol} || 'TCP';
		my $port        = $connect_method_info->{$connect_method_id}{port};
		my $scope;
		
		$protocol = lc($protocol);
		
		for my $num (sort keys %{$firewall_configuration->{$INPUT_CHAIN}}) {
			my $existing_scope = $firewall_configuration->{$INPUT_CHAIN}{$num}{$protocol}{$port}{scope} || '';
			if (!$existing_scope) {
			
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
						"scope: $scope\n"
					);
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

=head2 activate_interfaces

 Parameters  : 
 Returns     :
 Description : 

=cut

sub activate_interfaces {
	return 1;

}

#/////////////////////////////////////////////////////////////////////////////
1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
