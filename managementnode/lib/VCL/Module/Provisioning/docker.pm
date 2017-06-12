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

VCL::Provisioning::docker - VCL module to support povisioning of docker

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::Provisioning::docker;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw(-no_match_vars);

use VCL::utils;

use LWP::UserAgent;
use JSON qw(from_json to_json encode_json decode_json);

##############################################################################

=head1 OBJECT METHODS

=cut

sub initialize {
	my $self = shift;
	notify($ERRORS{'DEBUG'}, 0, "Docker module initialized");
	return 1;
} ## end sub initialize


#/////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  :
 Returns     :
 Description :

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_name = $self->data->get_image_name() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0) || return;
	my $image_os_type = $self->data->get_image_os_type() || return;
 
	# The docker daemon listens on unix:///var/run/docker.sock 
	# but you can Bind Docker to another host/port or a Unix socket
	# set Docker daemon to listen on a specific IP and port
	# set Docker host ip / port (/etc/init/docker.conf in Ubuntu 14.04 )
	# (/usr/lib/systemd/system/docker.service in CentOS 7)
	# e.g.,) docker -H tcp://0.0.0.0:4243 -H unix:///var/run/docker.sock -d &

	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";
	my $nathost_name = $self->data->get_nathost_hostname(0);
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	my $using_nat_host = 0;
	if (defined($nathost_name)) {
		notify($ERRORS{'DEBUG'}, 0, "the VM hostname: $vmhost_name for computer: $computer_name is a nat host: $nathost_name");
		notify($ERRORS{'DEBUG'}, 0, "computer: $computer_name will use random ports for nat");
		$using_nat_host = 1;
	}
	# set ssh port of the vm_host (if not 22)
	my $remote_connection_target = determine_remote_connection_target($vmhost_name);
	# set the specific ssh port for vmhost in the variable table. e.g., 24
	notify($ERRORS{'OK'}, 0, "remote_connection_target: $remote_connection_target");
	my $target_ssh_port = get_variable("vmhost_ssh_port") || 22;
	$ENV{ssh_port}{$remote_connection_target} = $target_ssh_port;
	notify($ERRORS{'OK'}, 0, "vmhost_ssh_port: $target_ssh_port");

	# create a useragent
	my $ua = LWP::UserAgent->new();
	# Using docker inspect to check whether there is any container with the same computer name or not
	# if it exists, unload the previous one 
	my $resp = $ua->get(
		$docker_host_url . "/containers/$computer_name/json",
		content_type => 'application/json',
	);
	my $container_exist = 0;
	eval {
		from_json($resp->content);
		$container_exist = 1;
	} or do {
		notify($ERRORS{'DEBUG'}, 0, "the container id for $computer_name does not exist: " . join("\n", $resp->content));
	};

	if ($container_exist) {
		my $output = from_json($resp->content);
		my $container_id = $output->{'Id'};
		notify($ERRORS{'OK'}, 0, "container_id: [$container_id]");
		if (defined($container_id)) {
			notify($ERRORS{'WARNING'}, 0, "the container id for $computer_name already exists");
			if(!$self->unload()) {
				notify($ERRORS{'WARNING'}, 0, "failed to unload the container for $computer_name");
				return 0;
			}
		}
	}
	
	# set the number of CPUs and memory size for the container
	my $cpu_count = $self->data->get_image_minprocnumber() || 1;
	notify($ERRORS{'OK'}, 0, "cpu_count: [$cpu_count]");
	my $cpus = "0";
	if ($cpu_count == 1) {
		$cpus = "0";
	}
	else {
		$cpu_count = $cpu_count - 1;
		$cpus = "0-$cpu_count";	
	}
	my $memory_mb = $self->data->get_image_minram();
	my $memory_bytes = ($memory_mb * 1024 * 1024);
	$memory_bytes = 0 + $memory_bytes;	
	my $eth0_mac_address = $self->data->get_computer_eth0_mac_address();
	notify($ERRORS{'OK'}, 0, "eth0 mac: $eth0_mac_address, cpus: [$cpus], memory_bytes: [$memory_bytes]");
	if (!defined($eth0_mac_address) || !defined($memory_bytes)) {
		notify($ERRORS{'WARNINGS'}, 0, "eth0 mac address:[$eth0_mac_address] OR memory size: [$memory_bytes] is not defined for $computer_name");
		return;
	}
	
	my $docker_default_ssh_port = get_variable("docker_default_ssh_port") || 22; # set docker container default ssh port in variable table, e.g., 22	
	my $docker_default_public_port = get_default_public_port($image_os_type);
	if (!defined($docker_default_public_port)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get default public port for $computer_name");
		return 0;
	}

	my $container_data;
	# json docker create format of the container
	if ($using_nat_host) {
		# get a random ssh port for the container node for public access
		my $random_ssh_port = $self->get_dockerhost_random_port($docker_default_ssh_port);
		# get a random public port for public access of the applications (e.g., xrdp, lxde, rstudio)
		my $random_public_port = $self->get_dockerhost_random_port($docker_default_public_port);
		#my $random_vnc_port = $self->get_dockerhost_random_port($docker_default_vnc_port);
		notify($ERRORS{'DEBUG'}, 0, "default_ssh_port: $docker_default_ssh_port, random_public_port: $docker_default_public_port");
		notify($ERRORS{'DEBUG'}, 0, "random_ssh_port: $random_ssh_port, random_public_port: $random_public_port");
		if (!defined($random_ssh_port) || !defined($random_public_port)) {
			notify($ERRORS{'WARNING'}, 0, "failed to get ssh: $random_ssh_port, public: $random_public_port port for $computer_name");
			return 0;
		}
		
		$container_data = {
			Image => $image_name,
			# MacAddress => $eth0_mac_address, # It could be used for future DHCP configuration. 
			HostConfig => {
				Privileged => JSON::true, # 0/1 and true/false cause GO Marshall converting error 
				#Memory => 0 + $memory_bytes, # add 0 to avoid JSON format error (GO Marshall converting error)
				# CpusetCpus => "$cpus", # This fixed and biased distribution would reduce the CPU utilization. Need more fair distribution methods.
				# Docker uses all the available CPUs equally(Only set if you have better solutions)
				CapAdd => ["NET_ADMIN"], #// allow to use iptables inside a container
				#PublishAllPorts => JSON::true,
				#NetworkMode => 'none' # default NetworkMode is bridge
				PortBindings => {
					"$docker_default_ssh_port\/tcp" => [{HostPort => $random_ssh_port }],
					"$docker_default_public_port\/tcp" => [{HostPort => $random_public_port }],
					# Examples
					#"8080/tcp" =>  [{ HostPort => "" }],
					#"8088/tcp" =>  [{ HostPort => "" }],
					#"8443/tcp" =>  [{ HostPort => "" }],
					#"18080/tcp" =>  [{ HostPort => "" }],
					#"$docker_default_vnc_port\/tcp" => [{HostPort => $random_vnc_port }]
					#"$docker_default_ssh_port\/tcp" => [{ HostIp => $vmhost_public_ip_address, HostPort => $random_ssh_port }],
					#"$docker_default_public_port\/tcp" => [{ HostIp => $vmhost_public_ip_address, HostPort => $random_public_port }]
				},
			},
		};	
	}
	else {
		$container_data = {
			Image => $image_name,
			# MacAddress => $eth0_mac_address, # It could be used for future DHCP configuration. 
			HostConfig => {
				# Privileged => JSON::true, # 0/1 and true/false cause GO Marshall converting error 
				##Memory => 0 + $memory_bytes, # add 0 to avoid JSON format error (GO Marshall converting error)
				# CpusetCpus => "$cpus", # This fixed and biased distribution would reduce the CPU utilization. Need more fair distribution methods.
				# Docker uses all the available CPUs equally(Only set if you have better solutions)
				CapAdd => ["NET_ADMIN"], #// allow to use iptables inside a container
				NetworkMode => 'none' # default NetworkMode is bridge
			},
		};
	}
	
	# create the container
	$resp =  $ua->post(
		$docker_host_url . "/containers/create?name=$computer_name",
		content_type => 'application/json',
		content => to_json($container_data),
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to create a container for $computer_name: " . join("\n", $resp->content));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "successfully create a container: ". join("\n", $resp->content));

	# start the container
	$resp =  $ua->post(
		$docker_host_url . "/containers/$computer_name/start",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to start the container for $computer_name: " . join("\n", $resp->content));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "successfully start the container: ". join("\n", $resp->content));


	$resp =  $ua->get(
		$docker_host_url . "/containers/$computer_name/json",
		content_type => 'application/json',
	);

	eval {
		from_json($resp->content);
		1;
	} or do {
		notify($ERRORS{'DEBUG'}, 0, "the container id for $computer_name does not exist: " . join("\n", $resp->content));
		return;
	};

	my $output = from_json($resp->content);
	my $container_pid = $output->{State}{Pid};
	if (!defined($container_pid)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get Pid of the container on $computer_name");
		return;
	}
	
	# if docker uses dhcp server to assign IPs to computer
	if ($using_nat_host) {
		my $ua_output = from_json($resp->content);	
		my $private_ip = $ua_output->{NetworkSettings}{IPAddress};
		if (!defined($private_ip)) {
			notify($ERRORS{'WARNINGS'}, 0, "private IP address is not defined for $computer_name");
			return;
		}
		# YOUNG update /etc/hosts
		`sed -i "/.*\\b$computer_name\$/d" /etc/hosts`;
		`echo "$private_ip\t$computer_name" >> /etc/hosts`;
 
		# update the private ip address of the computer
		my $result = update_computer_private_ip_address($computer_id, $private_ip);
		if (!defined($result)) {
			notify($ERRORS{'WARNING'}, 0, "failed to update $private_ip on $computer_name");
			return 0;
		}
		notify($ERRORS{'DEBUG'}, 0, "private IP address is $private_ip for $computer_name");
	} else {
		# add eth0 to the container
		#my $private_nic = get_variable("docker_container_private_nic");
		#my $private_bridge = get_variable("docker_host_privae_bridge");
		my $container_private_nic = "eth0";
		my $private_bridge = 'br0';
		#my $private_bridge = $self->data->get_vmhost_profile_virtualswitch0(0) || 'br0';
		if(!$self->create_eth_inside_container($container_pid, $container_private_nic, $private_bridge)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create eth0 inside the container on $computer_name");
			return;
		}
	
		# add eth1 to the container
		#my $public_nic = get_variable("docker_container_public_nic");
		#my $public_bridge = get_variable("docker_host_public_bridge");
		my $container_public_nic = "eth1";
		my $public_bridge = 'br1';
		#my $public_bridge = $self->data->get_vmhost_profile_virtualswitch1(0) || 'br1';
		if(!$self->create_eth_inside_container($container_pid, $container_public_nic, $public_bridge)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create eth1 inside the container on $computer_name");
			return;
		}
		# sleep to get dhcp
		sleep(20);
	}

	# Call post_load
	if ($self->os->can("post_load")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "->post_load()");
		if ($self->os->post_load()) {
			notify($ERRORS{'DEBUG'}, 0, "successfully ran OS post_load subroutine");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run OS post_load subroutine");
			return;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, ref($self->os) . "::post_load() has not been implemented");
		return;
	}

	return 1;
} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 create_eth_inside_container

 Parameters  : container process id
 Returns     : 1(success) or 0(failure)
 Description :

=cut

sub create_eth_inside_container {
	my $self = shift;
	my $container_pid = shift;
	my $eth_name = shift;
	my $bridge_name = shift;
	notify($ERRORS{'DEBUG'}, 0, "container_pid: $container_pid");
	notify($ERRORS{'DEBUG'}, 0, "ethernet_name: $eth_name");
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_name = $self->data->get_computer_short_name() || return;


	my $veth_eth_name = $eth_name . $container_pid;
	my $veth_name = "v" . $eth_name . $container_pid;

	# PreStep 1
	my $netns_path = "/var/run/netns";
	my $command = "mkdir -p /var/run/netns";
	my ($exit_status, $output);
	if (!$self->vmhost_os->file_exists($netns_path)) {
		#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
		($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create netns on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
			#return 0;
		}
	}

	# PreStep 2
	my $netns_veth_path = "/var/run/netns/$container_pid";
	if (!$self->vmhost_os->file_exists($netns_veth_path)) {
		$command = "ln -s /proc/$container_pid/ns/net /var/run/netns/$container_pid";
		#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
		($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to create netns  on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
			#return 0;
		}
	}

	# Step 1
	$command = "ip link add $veth_name type veth peer name $veth_eth_name";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create veth pair on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	# Step 2
	$command = "brctl addif $bridge_name $veth_name";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add interface to the veth on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}


	my $mac_address;
	if ($eth_name eq 'eth0') {
		$mac_address = $self->data->get_computer_eth0_mac_address();
		notify($ERRORS{'OK'}, 0, "mac address of the eth0: $mac_address");
	}
	elsif ($eth_name eq 'eth1') {
		$mac_address = $self->data->get_computer_eth1_mac_address();
		notify($ERRORS{'OK'}, 0, "mac address of the eth1: $mac_address");
	}
	if (!defined($mac_address)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get mac address: $mac_address");
		#return 0;
	}

	# Step 3
	$command = "ip link set $veth_name up";
	($exit_status, $output) = $self->vmhost_os->execute($command);
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	# Step 4
	$command = "ip link set $veth_eth_name netns $container_pid";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	# Step 5
	$command = "ip netns exec $container_pid ip link set dev $veth_eth_name name $eth_name";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	# Step 6
	$command = "ip netns exec $container_pid ip link set $eth_name address $mac_address";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	$command = "ip netns exec $container_pid ip link set $eth_name up";
	#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
	($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		#return 0;
	}

	if ($eth_name eq 'eth1') {
		$command = "docker exec $computer_name dhclient";
		#$command = "docker exec $computer_name dhclient eth0 eth1";
		#($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
		($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to set the interface up on $container_pid\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
			#return 0;
		}
	}

	return 1;
}


#/////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads virtual machine with requested image

=cut

sub unload {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_name = $self->data->get_image_name() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0) || return;
	my $vmhost_internal_ip_address = $self->vmhost_os->data->get_computer_private_ip_address(0) || return;

	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";
	# set ssh port of the vm_host (if not 22)
	my $remote_connection_target = determine_remote_connection_target($vmhost_name);
	# set the specific ssh port for vmhost in the variable table. e.g., 24
	my $target_ssh_port = get_variable("vmhost_ssh_port") || 22;
	$ENV{ssh_port}{$remote_connection_target} = $target_ssh_port;

	# create a useragent
	my $ua = LWP::UserAgent->new();
	# stop the container
	my $resp =  $ua->post(
		$docker_host_url . "/containers/$computer_name/stop",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop the container for $computer_name: " . join("\n", $resp->content));
		return;
	}
	sleep(1);
	$resp =  $ua->delete(
		$docker_host_url . "/containers/$computer_name",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the container for $computer_name: " . join("\n", $resp->content));
		return;
	}

	# delete dangled network namespace ids
	my $nathost_name = $self->data->get_nathost_hostname(0);
	if (!defined($nathost_name)) {
		notify($ERRORS{'DEBUG'}, 0, "docker container $computer_name is not running in a NATHOST");
		my $command = "find -L /var/run/netns -type l -delete";
		#my ($exit_status, $output) = $self->vmhost_os->execute($command,1,10,3,24);
		my ($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "delete dangled veth on $computer_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "docker container $computer_name is completely removed");
	sleep(10);

	return 1;
} ## end sub unload

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : None
 Returns     : 1 if sucessful, 0 if failed
 Description : capturing a new OpenStack image.

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	notify($ERRORS{'OK'}, 0, "Docker Capturing....");

	my $old_image_name = $self->data->get_image_name();
	my $new_image_name = $self->get_new_image_name();
	$self->data->set_image_name($new_image_name);

	my $image_id = $self->data->get_image_id();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $imagerevision_comments = $self->data->get_imagerevision_comments(0);
	my $computer_name = $self->data->get_computer_short_name();
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0);
	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";

	if ($self->os->can("pre_capture")) {
		notify($ERRORS{'OK'}, 0, "calling OS module's pre_capture() subroutine");
		# do not turn the container off to run "docker commit"
		if (!$self->os->pre_capture({end_state => 'on'})) {
			notify($ERRORS{'WARNING'}, 0, "OS module pre_capture() failed");
			return 0;
		}
	}

	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$docker_host_url . "/containers/$computer_name/json",
		content_type => 'application/json',
	);
	eval {
		from_json($resp->content);
		1;
	} or do {
		notify($ERRORS{'DEBUG'}, 0, "the container id for $computer_name does not exist: " . join("\n", $resp->content));
		return 0;
	};

	my $output = from_json($resp->content);
	my $container_id = $output->{'Id'};
	notify($ERRORS{'OK'}, 0, "container_id: [$container_id]");
	if (!defined($container_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the container id for $computer_name");
		return 0;
	}

	$resp =  $ua->post(
		$docker_host_url . "/commit?container=$container_id&comment=$imagerevision_comments&repo=$new_image_name",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to commit the container for $computer_name: " . join("\n", $resp->content));
		return;
	}

	# Update the image name in the database
	if ($old_image_name ne $new_image_name && !update_image_name($image_id, $imagerevision_id, $new_image_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update image name in the database: $old_image_name --> $new_image_name");
		return;
	}

	sleep(10);
	notify($ERRORS{'DEBUG'}, 0, "successfully captured the container for $computer_name");

	if(!$self->unload()) {
		notify($ERRORS{'WARNING'}, 0, "failed to unload the container for $computer_name");
		return 0;
	}
	return 1;
} ## end sub capture

#/////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Megabytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_name = $self->data->get_image_name() || return;
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0);

	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";

	# create a useragent
	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$docker_host_url . "/images/json?filter=$image_name",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get image info: " . join("\n", $resp->content));
		return 0;
	}

	my $output = from_json($resp->content);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return 0;
	}
	my $image_size = $output->[0]{'VirtualSize'};
	if (!defined($image_size)) {
		notify($ERRORS{'WARNING'}, 0, "The docker image size for $image_name does not be defined");
		return 0;
	}
	else
	{
		notify($ERRORS{'OK'}, 0, "The docker image size for $image_name is $image_size");
		return round($image_size); # Mbytes
	}
} ## end sub get_image_size


#/////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : $computer_node_name (optional)
 Returns     : boolean
 Description : Powers off and then powers on the computer.

=cut

sub power_reset() {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
## To DO (YOUNG)
# restart the docker container remove the veth 
	notify($ERRORS{'OK'}, 0, "Power_reset does NOT support for Docker");
	return 1;

	my $computer_name = $self->data->get_computer_short_name() || return;
	notify($ERRORS{'OK'}, 0, "computer_name: $computer_name");
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0);
	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";

	# create a useragent
	my $ua = LWP::UserAgent->new();
	my $resp =  $ua->post(
		$docker_host_url . "/containers/$computer_name/restart",
		content_type => 'application/json',
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to restart the container for $computer_name: " . join("\n", $resp->content));
		return;
	}
	notify($ERRORS{'OK'}, 0, "The docker container is successfully restarted");
	return 1;

} ## end sub power_reset

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : [0]: computer node name (optional)
	       [1]: log file path (optional)
 Returns     : Depends on the context which node_status was called:
	       default: string containing "READY" or "FAIL"
					boolean: true if ping, SSH, and VCL client checks are successful
						 false if any checks fail
	       list: array, values are 1 for SUCCESS, 0 for FAIL
						 [0]: Node status ("READY" or "FAIL")
							   [1]: Ping status (0 or 1)
							   [2]: SSH status (0 or 1)
							[3]: VCL client daemon status (0 ir 1)
					arrayref: reference to array described above
	       hashref: reference to hash with keys/values:
						 {status} => <"READY","FAIL">
							{ping} => <0,1>
							{ssh} => <0,1>
							   {vcl_client} => <0,1>
 Description : Checks the status of a lab machine.  Checks if the machine is
	       pingable, can be accessed via SSH, and the VCL client is running.

=cut

sub node_status{
	my $self;

	# Get the argument
	my $argument = shift;

	# Check if this subroutine was called an an object method or an argument was passed
	if (ref($argument) =~ /VCL::Module/i) {
		$self = $argument;
	}
	elsif (!ref($argument) || ref($argument) eq 'HASH') {
		# An argument was passed, check its type and determine the computer ID
		my $computer_id;
		if (ref($argument)) {
			# Hash reference was passed
			$computer_id = $argument->{id};
		}
		elsif ($argument =~ /^\d+$/) {
			# Computer ID was passed
			$computer_id = $argument;
		}
		else {
			# Computer name was passed
			($computer_id) = get_computer_ids($argument);
		}

		if ($computer_id) {
			notify($ERRORS{'DEBUG'}, 0, "computer ID: $computer_id");
		}

		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine computer ID from argument:\n" . format_data($argument));
			return;
		}

		# Create a DataStructure object containing data for the computer specified as the argument
		my $data;
		eval {
			$data= new VCL::DataStructure({computer_identifier => $computer_id});
		};
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, error: $EVAL_ERROR");
			return;
		}
		elsif (!$data) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, DataStructure object is not defined");
			return;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "created DataStructure object  for computer ID: $computer_id");
		}

		# Create a VMware object
		my $object_type = 'VCL::Module::Provisioning::docker';
		if ($self = ($object_type)->new({data_structure => $data})) {
			notify($ERRORS{'DEBUG'}, 0, "created $object_type object to check the status of computer ID: $computer_id");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create $object_type object to check the status of computer ID: $computer_id");
			return;
		}

		# Create an OS object for the VMware object to access
		if (!$self->create_os_object()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create OS object");
			return;
		}
	}

	# Create a hash reference and populate it with the default values
	my $status;
	$status->{currentimage} = '';
	$status->{ssh} = 0;
	$status->{image_match} = 0;
	$status->{status} = 'RELOAD';

	return $status;
} ## end sub node_status


#/////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  :
 Returns     : 1 or 0
 Description : Checks the existence of an image.

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_name = $self->data->get_image_name();
	my $vmhost_public_ip_address = $self->vmhost_os->data->get_computer_public_ip_address(0);
 
	my $docker_host_port = get_variable("docker_host_port"); # set docker host port in variable table, e.g., 4243
	my $docker_host_url = "http://$vmhost_public_ip_address:$docker_host_port";
	notify($ERRORS{'DEBUG'}, 0, "find image name: $image_name in docker host: $docker_host_url");

	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$docker_host_url . "/images/$image_name/json",
		content_type => 'application/json',
	);
	eval {
		from_json($resp->content);
		1;
	} or do {
		notify($ERRORS{'DEBUG'}, 0, "the image id for $image_name does not exist: " . join("\n", $resp->content));
		return 0;
	};
	my $output = from_json($resp->content);
	my $image_id = $output->{'Id'};
	notify($ERRORS{'OK'}, 0, "image_id: [$image_id]");

	if (!defined($image_id)) {
		notify($ERRORS{'WARNING'}, 0, "The docker image for $image_name does not exist");
		return 0;
	}
	else
	{
		notify($ERRORS{'OK'}, 0, "The docker image for $image_name exists");
		return 1;
	}


} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////
=head2 get_default_public_port

 Parameters  :
 Returns     : string
 Description : Find the default public port for the image based on the connect method 

=cut

sub get_default_public_port {
	my $image_os_type = shift;
	if (!defined($image_os_type)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get image os type");
		return;
	}

	my $sql_statement = <<EOF;
SELECT 
port  
FROM 
connectmethodport 
WHERE 
connectmethodid = (
SELECT id 
FROM 
connectmethod 
WHERE 
name = '$image_os_type')
EOF

	notify($ERRORS{'DEBUG'}, 0, "$sql_statement");
	my @selected_rows = database_select($sql_statement);
	if (scalar @selected_rows == 0 || scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return;
	}

	my $default_public_port = $selected_rows[0]{port};
	if (!defined($default_public_port)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get default public port");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "default public port for $image_os_type is $default_public_port");
	return $default_public_port;
}


#/////////////////////////////////////////////////////////////////////////////

=head2 get_new_image_name

 Parameters  :
 Returns     : string
 Description : Constructs a new image name for images being captured. This is
					used instead of the name in the database in case an image is
					converted. The new image name shouldn't contain vmware.

=cut

sub get_new_image_name {
	my $self = shift;
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_id = $self->data->get_image_id();
	my $image_os_name = $self->data->get_image_os_name();
	my $image_prettyname = $self->data->get_image_prettyname();
	my $imagerevision_revision = $self->data->get_imagerevision_revision();

	# Clean up the OS name
	$image_os_name = "docker";

	# Remove non-word characters and underscores from the image prettyname
	$image_prettyname =~ s/[\W\_]+//ig;

	my $new_image_name = "$image_os_name\-$image_prettyname"."$image_id\-v$imagerevision_revision";
	notify($ERRORS{'DEBUG'}, 0, "new_image_name: [$new_image_name]");
	return $new_image_name;
} ## end sub get_new_image_name

#/////////////////////////////////////////////////////////////////////////////

=head2 get_dockerhost_random_port

 Parameters  : $remote_ip (optional), $overwrite
 Returns     : ssh_port or public_port
 Description : Processes the random port for the connect methods configured for the image revision.

=cut

sub get_dockerhost_random_port{
	my $self = shift;
	my $default_port = shift;
	notify($ERRORS{'DEBUG'}, 0, "default_port: $default_port");
	if (ref($self) !~ /docker/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_name = $self->data->get_image_name();
	my $computer_node_name = $self->data->get_computer_node_name();
	my $nathost_hostname = $self->data->get_nathost_hostname(0);
	my $nathost_public_ip_address = $self->data->get_nathost_public_ip_address(0);

	# Retrieve the connect method info hash
	my $connect_method_info = $self->data->get_connect_methods();
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve connect method info");
		return;
	}

	CONNECT_METHOD: for my $connect_method_id (sort keys %{$connect_method_info} ) {
		my $connect_method = $connect_method_info->{$connect_method_id};

		for my $connect_method_port_id (keys %{$connect_method->{connectmethodport}}) {
			my $protocol = $connect_method->{connectmethodport}{$connect_method_port_id}{protocol};
			my $port = $connect_method->{connectmethodport}{$connect_method_port_id}{port};

			if ($port == $default_port) {
				my $random_port = $connect_method->{connectmethodport}{$connect_method_port_id}{natport}{publicport};
				if (!defined($random_port)) {
					notify($ERRORS{'WARNING'}, 0, "$computer_node_name is assigned to NAT host $nathost_hostname but connect method info does not contain NAT port information:\n" . format_data($connect_method));
					return;
				}
				else {
					return $random_port;
				}
			}
			# notify($ERRORS{'WARNING'}, 0, "$computer_node_name is assigned to NAT host $nathost_hostname but connect method info does not contain NAT port information:\n" . format_data($connect_method));
		}
	}
	return;
} ## end sub get_dockerhost_random_port

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
