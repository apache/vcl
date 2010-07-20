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
our $VERSION = '2.00';

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

	#Clear ssh idenity keys from /root/.ssh 
	if (!$self->clear_private_keys()) {
		notify($ERRORS{'WARNING'}, 0, "unable to clear known identity keys");
	}

	if ($ip_configuration eq "static") {
		#so we don't have conflicts we should set the public adapter back to dhcp
		# reset ifcfg-eth1 back to dhcp
		# when boot strap it will be set to dhcp
		my @ifcfg;
		my $tmpfile = "/tmp/createifcfg$computer_node_name";
		push(@ifcfg, "DEVICE=eth1\n");
		push(@ifcfg, "BOOTPROTO=dhcp\n");
		push(@ifcfg, "STARTMODE=onboot\n");
		push(@ifcfg, "ONBOOT=yes\n");
		#write to tmpfile
		if (open(TMP, ">$tmpfile")) {
			print TMP @ifcfg;
			close(TMP);
		}
		else {
			#print "could not write $tmpfile $!\n";
			notify($ERRORS{'OK'}, 0, "could not write $tmpfile $!");
		}
		#copy to node
		if (run_scp_command($tmpfile, "$computer_node_name:/etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE", $management_node_keys)) {
		}
		if (unlink($tmpfile)) {
		}
	} ## end if ($ip_configuration eq "static")

	#Write /etc/rc.local script
	if(!$self->generate_rc_local()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/rc.local script on $computer_node_name");
		return 0;
	}

	#Generate external_sshd_config
	if(!$self->generate_ext_sshd_config()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/ssh/external_sshd_config on $computer_node_name");
		return 0;
	}

	#Generate ext_sshd init script
	if(!$self->generate_ext_sshd_init()){
		notify($ERRORS{'WARNING'}, 0, "unable to generate /etc/init.d/ext_sshd on $computer_node_name");
		return 0;
	}

	#shutdown node
	notify($ERRORS{'OK'}, 0, "shutting down node for Linux imaging sequence");
	run_ssh_command($computer_node_name, $management_node_keys, "/sbin/shutdown -h now", "root");
	notify($ERRORS{'OK'}, 0, "sleeping for 60 seconds while machine shuts down");
	sleep 60;

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_prepare

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

	my $management_node_keys = $self->data->get_management_node_keys();
	my $image_name           = $self->data->get_image_name();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_node_name   = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "initiating Linux post_load: $image_name on $computer_short_name");

	# Wait for computer to respond to SSH
	if (!$self->wait_for_response(60, 600)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
		return 0;
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
	my $clear_extsshd = "sed -ie \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
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

 Parameters  :
 Returns     : 1,0 success or failure
 Description : To be used for nodes that have both private and public addresses. 
                                        Set hostname to that of the public address.

=cut

sub update_public_hostname {
     my $self = shift;
     unless (ref($self) && $self->isa('VCL::Module')) {
        notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
        return; 
     }
         
     my $management_node_keys = $self->data->get_management_node_keys();
     my $computer_node_name   = $self->data->get_computer_node_name();
     my $image_os_type        = $self->data->get_image_os_type();
     my $image_os_name        = $self->data->get_image_os_name();
     my $computer_short_name             = $self->data->get_computer_short_name();
     my $public_hostname;

        #Get the IP address of the public adapter

 my $public_IP_address = getdynamicaddress($computer_short_name, $image_os_name, $image_os_type);
        if (!($public_IP_address)) {
                notify($ERRORS{'WARNING'}, 0, "Unable to get public IP address");
                return 0;
        }

        #Get the hostname for the public IP address
        my $get_public_hostname = "/bin/ipcalc --hostname $public_IP_address";
        my ($ipcalc_status, $ipcalc_output) = run_ssh_command($computer_short_name, $management_node_keys,$get_public_hostname);
        if (!defined($ipcalc_status)) {
                notify($ERRORS{'WARNING'}, 0, "unable to run ssh cmd $get_public_hostname on $computer_short_name");
                return 0;
        }
        elsif ("@$ipcalc_output" =~ /HOSTNAME=(.*)/i) {
                $public_hostname = $1;
                notify($ERRORS{'DEBUG'}, 0, "collected public hostname= $public_hostname");
        }

        #Set the node's hostname to public hostname
        my ($set_hostname_status, $set_hostname_output) = run_ssh_command($computer_short_name, $management_node_keys,"hostname -v $public_hostname"); 
        unless (defined($set_hostname_status) && $set_hostname_status == 0) {
			notify($ERRORS{'OK'}, 0, "failed to set public_hostname on $computer_short_name output: @${set_hostname_output}");
        }

        notify($ERRORS{'OK'}, 0, "successfully set public_hostname on $computer_short_name output: @${set_hostname_output}");
        return 1;

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

 Parameters  :
 Returns     :
 Description :

=cut

sub set_static_public_address {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	# Make sure public IP configuration is static
	my $ip_configuration = $self->data->get_management_node_public_ip_configuration() || 'undefined';
	unless ($ip_configuration =~ /static/i) {
		notify($ERRORS{'WARNING'}, 0, "static public address can only be set if IP configuration is static, current value: $ip_configuration");
		return;
	}

	# Get the IP configuration
	my $public_interface_name = $self->get_public_interface_name()     || 'undefined';
	my $public_ip_address     = $self->data->get_computer_ip_address() || 'undefined';

	my $subnet_mask     = $self->data->get_management_node_public_subnet_mask() || 'undefined';
	my $default_gateway = $self->get_public_default_gateway()                   || 'undefined';
	my $dns_server      = $self->data->get_management_node_public_dns_server()  || 'undefined';

	# Make sure required info was retrieved
	if ("$public_interface_name $subnet_mask $default_gateway $dns_server" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve required network configuration:\ninterface: $public_interface_name\npublic IP address: $public_ip_address\nsubnet mask=$subnet_mask\ndefault gateway=$default_gateway\ndns server=$dns_server");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $image_name           = $self->data->get_image_name();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_node_name   = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "initiating Linux set_static_public_address on $computer_short_name");
	my @eth1file;
	my $tmpfile = "/tmp/ifcfg-eth_device-$computer_short_name";
	push(@eth1file, "DEVICE=eth1\n");
	push(@eth1file, "BOOTPROTO=static\n");
	push(@eth1file, "IPADDR=$public_ip_address\n");
	push(@eth1file, "NETMASK=$subnet_mask\n");
	push(@eth1file, "STARTMODE=onboot\n");
	push(@eth1file, "ONBOOT=yes\n");

	#write to tmpfile
	if (open(TMP, ">$tmpfile")) {
		print TMP @eth1file;
		close(TMP);
	}
	else {
		#print "could not write $tmpfile $!\n";

	}
	my @sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "/etc/sysconfig/network-scripts/ifdown $public_interface_name", "root");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l) {
			#potential problem
			notify($ERRORS{'OK'}, 0, "sshcmd output ifdown $computer_short_name $l");
		}
	}
	#copy new ifcfg-Device
	if (run_scp_command($tmpfile, "$computer_short_name:/etc/sysconfig/network-scripts/ifcfg-$public_interface_name", $management_node_keys)) {

		#confirm it got there
		undef @sshcmd;
		@sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "cat /etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE", "root");
		my $success = 0;
		foreach my $i (@{$sshcmd[1]}) {
			if ($i =~ /$public_ip_address/) {
				notify($ERRORS{'OK'}, 0, "SUCCESS - copied ifcfg_$public_interface_name\n");
				$success = 1;
			}
		}
		if (unlink($tmpfile)) {
			notify($ERRORS{'OK'}, 0, "unlinking $tmpfile");
		}

		if (!$success) {
			notify($ERRORS{'WARNING'}, 0, "unable to copy $tmpfile to $computer_short_name file ifcfg-$public_interface_name did get updated with $public_ip_address ");
			return 0;
		}
	} ## end if (run_scp_command($tmpfile, "$computer_short_name:/etc/sysconfig/network-scripts/ifcfg-$public_interface_name"...

	#bring device up
	@sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "/etc/sysconfig/network-scripts/ifup $public_interface_name", "root");
	#should be empty
	foreach my $l (@{$sshcmd[1]}) {
		if ($l) {
			#potential problem
			notify($ERRORS{'OK'}, 0, "possible problem with ifup $public_interface_name $l");
		}
	}
	#correct route table - delete old default and add new in same line
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "/sbin/route del default", "root");
	#should be empty
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Usage:/) {
			#potential problem
			notify($ERRORS{'OK'}, 0, "possible problem with route del default $l");
		}
		if ($l =~ /No such process/) {
			notify($ERRORS{'OK'}, 0, "$l - ok  just no default route since we downed eth device");
		}
	}

	notify($ERRORS{'OK'}, 0, "Setting default route");
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "/sbin/route add default gw $default_gateway metric 0 $public_interface_name", "root");
	#should be empty
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Usage:/) {
			#potential problem
			notify($ERRORS{'OK'}, 0, "possible problem with route add default gw $default_gateway metric 0 $public_interface_name");
		}
		if ($l =~ /No such process/) {
			notify($ERRORS{'CRITICAL'}, 0, "problem with $computer_short_name $l add default gw $default_gateway metric 0 $public_interface_name");
			return 0;
		}
	} ## end foreach my $l (@{$sshcmd[1]})

	#correct external sshd file

	if (run_ssh_command($computer_short_name, $management_node_keys, "sed -ie \"/ListenAddress .*/d \" /etc/ssh/external_sshd_config", "root")) {
		notify($ERRORS{'OK'}, 0, "Cleared ListenAddress from external_sshd_config");
	}

	# Add correct ListenAddress
	if (run_ssh_command($computer_short_name, $management_node_keys, "echo \"ListenAddress $public_ip_address\" >> /etc/ssh/external_sshd_config", "root")) {
		notify($ERRORS{'OK'}, 0, "appended ListenAddress $public_ip_address to external_sshd_config");
	}

	#modify /etc/resolve.conf
	my $search;
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_short_name, $management_node_keys, "cat /etc/resolv.conf", "root");
	foreach my $l (@{$sshcmd[1]}) {
		chomp($l);
		if ($l =~ /search/) {
			$search = $l;
		}
	}

	if (defined($search)) {
		my @resolvconf;
		push(@resolvconf, "$search\n");
		my ($s1, $s2, $s3);
		if ($dns_server =~ /,/) {
			($s1, $s2, $s3) = split(/,/, $dns_server);
		}
		else {
			$s1 = $dns_server;
		}
		push(@resolvconf, "nameserver $s1\n");
		push(@resolvconf, "nameserver $s2\n") if (defined($s2));
		push(@resolvconf, "nameserver $s3\n") if (defined($s3));
		my $rtmpfile = "/tmp/resolvconf$computer_short_name";
		if (open(RES, ">$rtmpfile")) {
			print RES @resolvconf;
			close(RES);
		}
		else {
			notify($ERRORS{'OK'}, 0, "could not write to $rtmpfile $!");
		}
		#put resolve.conf  file back on node
		notify($ERRORS{'OK'}, 0, "copying in new resolv.conf");
		if (run_scp_command($rtmpfile, "$computer_short_name:/etc/resolv.conf", $management_node_keys)) {
			notify($ERRORS{'OK'}, 0, "SUCCESS copied new resolv.conf to $computer_short_name");
		}
		else {
			notify($ERRORS{'OK'}, 0, "FALIED to copied new resolv.conf to $computer_short_name");
			return 0;
		}

		if (unlink($rtmpfile)) {
			notify($ERRORS{'OK'}, 0, "unlinking $rtmpfile");
		}
	} ## end if (defined($search))
	else {
		notify($ERRORS{'WARNING'}, 0, "pulling resolve.conf from $computer_short_name failed output= @{ $sshcmd[1] }");
	}


	return 1;
} ## end sub set_static_public_address

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_interface_name

 Parameters  :
 Returns     :
 Description :

=cut

sub get_public_interface_name {

	#global varible pulled from vcld.conf
	return $ETHDEVICE;

}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_public_default_gateway

 Parameters  :
 Returns     :
 Description :

=cut

sub get_public_default_gateway {

	#global varible pulled from vcld.conf
	return $GATEWAY;
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
	my $clear_extsshd = "sed -ie \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $image_identity, $clear_extsshd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared AllowUsers directive from external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user_login_id to external_sshd_config");
	}

	#Clear user from sudoers

	if ($imagemeta_rootaccess) {
		#clear user from sudoers file
		my $clear_cmd = "sed -ie \"/^$user_login_id .*/d\" /etc/sudoers";
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
	my $user_standalone      = $self->data->get_user_standalone();
	my $user_uid				 = $self->data->get_user_uid();

	if($self->add_vcl_usergroup()){

	}

	my $useradd_string; 
	if(defined($user_uid) && $user_uid != 0){
		$useradd_string = "/usr/sbin/useradd -u $user_uid -d /home/$user_name -m $user_name -g vcl";
	}
	else{
		$useradd_string = "/usr/sbin/useradd -d /home/$user_name -m $user_name -g vcl";
	}


	my @sshcmd = run_ssh_command($computer_node_name, $image_identity, $useradd_string, "root");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /$user_name exists/) {
			notify($ERRORS{'OK'}, 0, "detected user already has account");
			if ($self->delete_user()) {
				notify($ERRORS{'OK'}, 0, "user has been deleted from $computer_node_name");
				@sshcmd = run_ssh_command($computer_node_name, $image_identity, $useradd_string, "root");
			}
		}
	}


	if ($user_standalone) {
		notify($ERRORS{'DEBUG'}, 0, "Standalone user setting single-use password");
		my $reservation_password = $self->data->get_reservation_password();

		#Set password
		if ($self->changepasswd($computer_node_name, $user_name, $reservation_password)) {
			notify($ERRORS{'OK'}, 0, "Successfully set password on useracct: $user_name on $computer_node_name");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "Failed to set password on useracct: $user_name on $computer_node_name");
			return 0;
		}
	} ## end if ($user_standalone)


	#Check image profile for allowed root access
	if ($imagemeta_rootaccess) {
		# Add to sudoers file
		#clear user from sudoers file to prevent dups
		my $clear_cmd = "sed -ie \"/^$user_name .*/d\" /etc/sudoers";
		if (run_ssh_command($computer_node_name, $image_identity, $clear_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "cleared $user_name from /etc/sudoers");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to clear $user_name from /etc/sudoers");
		}
		my $sudoers_cmd = "echo \"$user_name ALL= NOPASSWD: ALL\" >> /etc/sudoers";
		if (run_ssh_command($computer_node_name, $image_identity, $sudoers_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "added $user_name to /etc/sudoers");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to add $user_name to /etc/sudoers");
		}
	} ## end if ($imagemeta_rootaccess)


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
	my $clear_extsshd = "sed -ie \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
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

	my @ssh;
	my $l;
	if ($account eq "root") {

		#if not a predefined password, get one!
		$passwd = getpw(15) if (!(defined($passwd)));
		notify($ERRORS{'OK'}, 0, "password for $node is $passwd");

		if (open(OPENSSL, "openssl passwd -1 $passwd 2>&1 |")) {
			$passwd = <OPENSSL>;
			chomp $passwd;
			close(OPENSSL);
			if ($passwd =~ /command not found/) {
				notify($ERRORS{'CRITICAL'}, 0, "failed $passwd ");
				return 0;
			}
			my $tmpfile = "/tmp/shadow.$node";
			if (open(TMP, ">$tmpfile")) {
				print TMP "$account:$passwd:13061:0:99999:7:::\n";
				close(TMP);
				if (run_ssh_command($node, $management_node_keys, "cat /etc/shadow \|grep -v $account >> $tmpfile", "root")) {
					notify($ERRORS{'DEBUG'}, 0, "collected /etc/shadow file from $node");
					if (run_scp_command($tmpfile, "$node:/etc/shadow", $management_node_keys)) {
						notify($ERRORS{'DEBUG'}, 0, "copied updated /etc/shadow file to $node");
						if (run_ssh_command($node, $management_node_keys, "chmod 600 /etc/shadow", "root")) {
							notify($ERRORS{'DEBUG'}, 0, "updated permissions to 600 on /etc/shadow file on $node");
							unlink $tmpfile;
							return 1;
						}
						else {
							notify($ERRORS{'WARNING'}, 0, "failed to change file permissions on $node /etc/shadow");
							unlink $tmpfile;
							return 0;
						}
					} ## end if (run_scp_command($tmpfile, "$node:/etc/shadow"...
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to copy contents of shadow file on $node ");
					}
				} ## end if (run_ssh_command($node, $identity_key, ...
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy contents of shadow file on $node ");
					unlink $tmpfile;
					return 0;
				}
			} ## end if (open(TMP, ">$tmpfile"))
			else {
				notify($ERRORS{'OK'}, 0, "failed could open $tmpfile $!");
			}
		} ## end if (open(OPENSSL, "openssl passwd -1 $passwd 2>&1 |"...
		return 0;
	} ## end if ($account eq "root")
	else {
		#actual user
		#push it through passwd cmd stdin
		# not all distros' passwd command support stdin
		my @sshcmd = run_ssh_command($node, $management_node_keys, "echo $passwd \| /usr/bin/passwd -f $account --stdin", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /authentication tokens updated successfully/) {
				notify($ERRORS{'OK'}, 0, "successfully changed local password account $account");
				return 1;
			}
		}

	} ## end else [ if ($account eq "root")

} ## end sub changepasswd

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
	
	# Get the computer hostname
	my $computer_hostname = $self->data->get_computer_hostname() || return;
	
	# Get the identity keys used by the management node
	my $management_node_keys = $self->data->get_management_node_keys() || '';
	
	# Run the command via SSH
	my ($exit_status, $output) = run_ssh_command($computer_hostname, $management_node_keys, $command, '', '', $display_output);
	if (defined($exit_status) && defined($output)) {
		if ($display_output) {
			notify($ERRORS{'OK'}, 0, "executed command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		}
		return ($exit_status, $output);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on $computer_hostname: $command");
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
	my $command = "rm -rv $escaped_path";
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
	my $command = "mkdir -p \"$directory_path\" 2>&1 && ls -1d \"$directory_path\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to create directory on $computer_short_name:\npath: '$directory_path'\ncommand: '$command'");
		return;
	}
	elsif (grep(/created directory/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "created directory on $computer_short_name: '$directory_path'");
		return 1;
	}
	elsif (grep(/(mkdir|ls):/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/^$directory_path/, @$output)) {
		notify($ERRORS{'OK'}, 0, "directory either created or already exists on $computer_short_name: '$directory_path'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to create directory on $computer_short_name: '$directory_path':\ncommand: '$command'\nexit status: $exit_status\noutput:\n" . join("\n", @$output) . "\nlast line:\n" . @$output[-1]);
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

 Parameters  : none
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
	my ($blocks_free) = $output_string =~ /Blocks:[^\n]*Free: (\d+)/;
	if (!$blocks_free) {
		notify($ERRORS{'WARNING'}, 0, "unable to locate blocks free value in stat output:\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Calculate the bytes free
	my $bytes_free = ($block_size * $blocks_free);
	my $mb_free = format_number(($bytes_free / 1024 / 1024), 2);
	my $gb_free = format_number(($bytes_free / 1024 / 1024 / 1024), 1);
	
	notify($ERRORS{'DEBUG'}, 0, "bytes free in '$path' on $computer_short_name: " . format_number($bytes_free) . " bytes ($mb_free MB, $gb_free GB)");
	return $bytes_free;
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
 Returns     : integer
 Description : Determines the size of the file specified by the file path
               argument in bytes. The file path argument may contain wildcards.
					If the path argument is a directory, 0 will be returned.

=cut

sub get_file_size {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
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
	my $command = 'stat -c "%F:%s:%n" ' . $escaped_file_path;
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine file size on $computer_node_name: $file_path\ncommand: $command");
		return;
	}
	elsif (grep(/^stat:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine file size on $computer_node_name: $file_path\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Loop through the stat output lines
	my $total_bytes = 0;
	for my $line (@$output) {
		# Take the stat output line apart
		my ($type, $file_bytes, $path) = split(/:/, $line);
		if (!defined($type) || !defined($file_bytes) || !defined($path)) {
			notify($ERRORS{'WARNING'}, 0, "unexpected output returned from stat, line: $line\ncommand: $command\noutput:\n" . join("\n", @$output));
			return;
		}
		
		# Add the size to the total if the type is file
		if ($type =~ /file/) {
			$total_bytes += $file_bytes;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "size of $file_path on $computer_node_name: " . format_number($total_bytes) . " bytes");
	return $total_bytes;
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
	my $command = "find \"$base_directory_path\" -type f -iname \"$file_pattern\"";
	notify($ERRORS{'DEBUG'}, 0, "attempting to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command: $command");
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to find files on $computer_node_name, base directory path: '$base_directory_path', pattern: $file_pattern, command:\n$command");
		return;
	}
	elsif (grep(/^find: /i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to find files on $computer_node_name\nbase directory path:\n$base_directory_path\npattern: $file_pattern\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Return the file list
	my @file_paths = @$output;
	notify($ERRORS{'DEBUG'}, 0, "matching file count: " . scalar(@file_paths));
	return @file_paths;
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
        push(@array2print, 'sed -i \'/.*AllowUsers .*$/d\' /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'sed -i \'/.*ListenAddress .*/d\' /etc/ssh/sshd_config' . "\n");
        push(@array2print, 'sed -i \'/.*ListenAddress .*/d\' /etc/ssh/external_sshd_config' . "\n");
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
	}

	push(@ext_sshd_config, "PidFile /var/run/ext_sshd.pid\n");
	push(@ext_sshd_config, "PermitRootLogin no\n");
	push(@ext_sshd_config, "UseDNS no\n");
	push(@ext_sshd_config, "X11Forwarding yes\n");
	
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

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
