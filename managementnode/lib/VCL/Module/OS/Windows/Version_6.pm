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

VCL::Module::OS::Windows::Version_6.pm - VCL module to support Windows 6.x operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows version 6.x operating systems.
 Version 6.x Windows OS's include Windows Vista and Windows Server 2008.

=cut

##############################################################################
package VCL::Module::OS::Windows::Version_6;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use File::Basename;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
               directory under the 'tools' directory specific to this OS.

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_Version_6";

##############################################################################

=head1 INTERFACE OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Performs steps before an image is captured which are specific to
               Windows version 6.x.

=over 3

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module object method");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "beginning Windows version 6 image pre-capture tasks");

=item 1

Disable defrag scheduled task

=cut

	$self->disable_scheduled_task('\Microsoft\Windows\Defrag\ScheduledDefrag');

=item *

Disable system restore scheduled task

=cut

	$self->disable_scheduled_task('\Microsoft\Windows\SystemRestore\SR');

=item *

Disable customer improvement program consolidator scheduled task

=cut

	$self->disable_scheduled_task('\Microsoft\Windows\Customer Experience Improvement Program\Consolidator');

=item *

Disable customer improvement program opt-in notification scheduled task

=cut

	$self->disable_scheduled_task('\Microsoft\Windows\Customer Experience Improvement Program\OptinNotification');

=item *

Call parent class's pre_capture() subroutine

=cut

	notify($ERRORS{'OK'}, 0, "calling parent class pre_capture() subroutine");
	if ($self->SUPER::pre_capture($args)) {
		notify($ERRORS{'OK'}, 0, "successfully executed parent class pre_capture() subroutine");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return 0;
	}

=item *

Deactivate Windows licensing activation

=cut

	if (!$self->deactivate_license()) {
		notify($ERRORS{'WARNING'}, 0, "unable to deactivate Windows licensing activation");
		return 0;
	}

=back

=cut

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub pre_capture

#/////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Performs steps after an image is loaded which are specific to
               Windows version 6.x.

=over 3

=cut

sub post_load {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module object method");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Windows version 6 (Vista, Server 2008) post-load tasks");
	
=item 1

Activate Windows license

=cut

	$self->activate_license();

=item *

Call parent class's post_load() subroutine

=cut

	notify($ERRORS{'DEBUG'}, 0, "calling parent class post_load() subroutine");
	if ($self->SUPER::post_load()) {
		notify($ERRORS{'OK'}, 0, "successfully executed parent class post_load() subroutine");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class post_load() subroutine");
		return;
	}

=back

=cut

	notify($ERRORS{'DEBUG'}, 0, "Windows version 6 (Vista, Server 2008) post-load tasks complete");
	return 1;
}

##############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut


#/////////////////////////////////////////////////////////////////////////////

=head2 activate_license

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs cscript.exe slmgr.vbs -skms to set the KMS server address
               stored on the computer.
               Runs cscript.exe slmgr.vbs -ato to activate licensing on the
               computer.

=cut

sub activate_license {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the image affiliation name
	my $image_affiliation_name = $self->data->get_image_affiliation_name();
	if ($image_affiliation_name) {
		notify($ERRORS{'DEBUG'}, 0, "image affiliation name: $image_affiliation_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "image affiliation name could not be retrieved, using default licensing configuration");
		$image_affiliation_name = 'default';
	}
	
	# Get the Windows activation data from the windows-activation variable
	my $activation_data = $self->data->get_variable('windows-activation');
	if ($activation_data) {
		notify($ERRORS{'DEBUG'}, 0, "activation data:\n" . format_data($activation_data));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "activation data could not be retrieved");
		return;
	}
	
	# Get the activation data specific to the image affiliation
	my $affiliation_config = $activation_data->{$image_affiliation_name};
	if ($affiliation_config) {
		notify($ERRORS{'DEBUG'}, 0, "$image_affiliation_name affiliation activation configuration:\n" . format_data($affiliation_config));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "activation configuration does not exist for affiliation: $image_affiliation_name, attempting to retrieve default configuration");
		
		$affiliation_config = $activation_data->{'default'};
		if ($affiliation_config) {
			notify($ERRORS{'DEBUG'}, 0, "default activation configuration:\n" . format_data($affiliation_config));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "default activation configuration does not exist");
			return;
		}
	}
	
	
	# Loop through the activation methods for the affiliation
	for my $activation_config (@$affiliation_config) {
		my $activation_method = $activation_config->{method};
		
		if ($activation_method =~ /kms/i) {
			my $kms_address = $activation_config->{address};
			my $kms_port = $activation_config->{port} || 1688;
			notify($ERRORS{'DEBUG'}, 0, "attempting to set kms server: $kms_address, port: $kms_port");
			
			# Run slmgr.vbs -skms
			my $kms_command = '$SYSTEMROOT/System32/cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -skms ' . "$kms_address:$kms_port";
			my ($kms_exit_status, $kms_output) = run_ssh_command($computer_node_name, $management_node_keys, $kms_command);
			if (defined($kms_exit_status) && $kms_exit_status == 0 && grep(/successfully/i, @$kms_output)) {
				notify($ERRORS{'OK'}, 0, "set kms server to $kms_address:$kms_port");
			}
			elsif (defined($kms_exit_status)) {
				notify($ERRORS{'WARNING'}, 0, "failed to set kms server to $kms_address:$kms_port, exit status: $kms_exit_status, output:\n@{$kms_output}");
				next;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to set kms server to $kms_address:$kms_port");
				next;
			}
			
			# KMS server successfully set, run slmgr.vbs -ato
			my $activate_command = '$SYSTEMROOT/System32/cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -ato';
			my ($activate_exit_status, $activate_output) = run_ssh_command($computer_node_name, $management_node_keys, $activate_command);
			if (defined($activate_exit_status)  && $activate_exit_status == 0 && grep(/successfully/i, @$activate_output)) {
				notify($ERRORS{'OK'}, 0, "license activated using kms server: $kms_address");
				return 1;
			}
			elsif (defined($activate_exit_status)) {
				notify($ERRORS{'WARNING'}, 0, "failed to activate license using kms server: $kms_address, exit status: $activate_exit_status, output:\n@{$activate_output}");
				next;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to activate license using kms server: $kms_address");
				next;
			}
		}
		
		elsif ($activation_method =~ /mak/i) {
			notify($ERRORS{'WARNING'}, 0, "MAK activation method is not supported yet");
			next;
		}
		
		else  {
			notify($ERRORS{'WARNING'}, 0, "unsupported activation method: $activation_method");
			next;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to activate license on $computer_node_name using any configured kms servers");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 deactivate_license

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs cscript.exe slmgr.vbs -ckms to clear the KMS server address
               stored on the computer.
               Deletes existing KMS servers keys from the registry.
               Runs cscript.exe slmgr.vbs -rearm to rearm licensing on the
               computer.

=cut

sub deactivate_license {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Run slmgr.vbs -ckms
	my $ckms_command = '$SYSTEMROOT/System32/cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -ckms';
	my ($ckms_exit_status, $ckms_output) = run_ssh_command($computer_node_name, $management_node_keys, $ckms_command);
	if (defined($ckms_exit_status) && $ckms_exit_status == 0 && grep(/successfully/i, @$ckms_output)) {
		notify($ERRORS{'OK'}, 0, "cleared kms address");
	}
	elsif (defined($ckms_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to clear kms address, exit status: $ckms_exit_status, output:\n@{$ckms_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to clear kms address");
		return;
	}
	
	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL]
"KeyManagementServicePort"=-
"KeyManagementServiceName"=-
"SkipRearm"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "removed kms keys from the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to remove kms keys from the registry");
		return 0;
	}
	
	# Run slmgr.vbs -rearm
	my $rearm_command = '$SYSTEMROOT/System32/cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -rearm';
	my ($rearm_exit_status, $rearm_output) = run_ssh_command($computer_node_name, $management_node_keys, $rearm_command);
	if (defined($rearm_exit_status) && $rearm_exit_status == 0 && grep(/successfully/i, @$rearm_output)) {
		notify($ERRORS{'OK'}, 0, "rearmed licensing");
	}
	elsif (defined($rearm_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to rearm licensing, exit status: $rearm_exit_status, output:\n@{$rearm_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to rearm licensing");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_network_location

 Parameters  :
 Returns     :
 Description : 

=cut

sub set_network_location {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	#Category key: Home/Work=00000000, Public=00000001
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList\\Signatures\\FirstNetwork]
"Category"=dword:00000001
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "set network location");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set network location");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow ping from any address"';
	$add_rule_command .= ' description="Allows incoming ping (ICMP type 8) messages from any address"';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=any';
	$add_rule_command .= ' remoteip=any';
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable ping from any address");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable ping from any address, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable ping from any address");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the computer's private IP address
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
		return;
	}
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow incoming ping to: ' . $private_ip_address . '"';
	$add_rule_command .= ' description="Allows incoming ping (ICMP type 8) messages to: ' . $private_ip_address . '"';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=' . $private_ip_address;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to allow incoming ping to: $private_ip_address");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to allow incoming ping to: $private_ip_address, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to allow incoming ping to: $private_ip_address");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# First delete any rules which allow ping and then add a new rule
	my $netsh_command;
	$netsh_command .= 'netsh.exe advfirewall firewall delete rule';
	$netsh_command .= ' name=all';
	$netsh_command .= ' dir=in';
	$netsh_command .= ' protocol=icmpv4:8,any';
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow ping");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to disallow ping, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to disallow ping");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if the remote IP was passed as an argument
	my $remote_ip = shift;
	if (!defined($remote_ip)) {
		$remote_ip = 'any';
	}
	elsif ($remote_ip !~ /[\d\.\/]/) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument is not a valid IP address: $remote_ip");
		$remote_ip = 'any';
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	
	# Set the key to allow remote connections whenever enabling RDP
	$add_rule_command .= 'reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /t REG_DWORD /v fDenyTSConnections /d 0 /f ; ';
	
	# Set the key to allow connections from computers running any version of Remote Desktop
	$add_rule_command .= 'reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp" /t REG_DWORD /v UserAuthentication /d 0 /f ; ';
	
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=3389';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow RDP from address: ' . $remote_ip . '"';
	$add_rule_command .= ' description="Allows incoming TCP port 3389 traffic from address: ' . $remote_ip . '"';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=any';
	$add_rule_command .= ' localport=3389';
	$add_rule_command .= ' remoteip=' . $remote_ip;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable RDP from $remote_ip");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable RDP from $remote_ip, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable RDP from $remote_ip");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the computer's private IP address
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
		return;
	}
	
	# First delete any rules which allow RDP and then add a new rule
	my $add_rule_command;
	
	# Set the key to allow remote connections whenever enabling RDP
	$add_rule_command .= 'reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /t REG_DWORD /v fDenyTSConnections /d 0 /f ; ';
	
	# Set the key to allow connections from computers running any version of Remote Desktop
	$add_rule_command .= 'reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp" /t REG_DWORD /v UserAuthentication /d 0 /f ; ';
	
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=3389';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow RDP port 3389 to: ' . $private_ip_address . '"';
	$add_rule_command .= ' description="Allows incoming RDP (TCP port 3389) traffic to: ' . $private_ip_address . '"';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=3389';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=' . $private_ip_address;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable RDP to: $private_ip_address");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable RDP to: $private_ip_address, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable RDP to: $private_ip_address");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# First delete any rules which allow ping and then add a new rule
	my $netsh_command;
	$netsh_command .= 'netsh.exe advfirewall firewall delete rule';
	$netsh_command .= ' name=all';
	$netsh_command .= ' dir=in';
	$netsh_command .= ' protocol=TCP';
	$netsh_command .= ' localport=3389';
	
	# Delete the firewall rule
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "deleted firewall rules which enable RDP");
	}
	elsif (defined($netsh_output)  && @$netsh_output[-1] =~ /No rules match/i) {
		notify($ERRORS{'OK'}, 0, "no firewall rules exist which enable RDP");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete firewall rules which enable RDP, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to delete firewall rules which enable RDP");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=22';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow SSH port 22 from any address"';
	$add_rule_command .= ' description="Allows incoming SSH (TCP port 22) traffic from any address"';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=22';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=any';
	$add_rule_command .= ' remoteip=any';
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable SSH from any address");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH from any address, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH from any address");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the computer's private IP address
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
		return;
	}
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= 'netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=22';
	$add_rule_command .= ' ;';
	
	$add_rule_command .= ' netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow SSH port 22 to: ' . $private_ip_address . '"';
	$add_rule_command .= ' description="Allows incoming SSH (TCP port 22) traffic to: ' . $private_ip_address . '"';
	$add_rule_command .= ' protocol=TCP';
	$add_rule_command .= ' localport=22';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=' . $private_ip_address;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	
	if (defined($add_rule_output)  && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable SSH to: $private_ip_address");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH to: $private_ip_address, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH to: $private_ip_address");
		return;
	}
	
	return 1;
}

##############################################################################

=head1 UTILITY FUNCTIONS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 add_kms_server

 Parameters  : $affiliation_name, $kms_address, $kms_port
 Returns     : If successful: true
               If failed: false
 Description : Adds a kms server to the windows-activation variable for the
               specified affiliation name.
               If a KMS server with the same address is already saved in the
               windows-activation variable, it is deleted and the KMS server
               specified in the subroutine arguments is added to the end of the
               configuration list.

=cut

sub add_kms_server {
	my ($affiliation_name, $kms_address, $kms_port) = @_;
	
	# Check the arguments
	unless ($affiliation_name && $kms_address) {
		notify($ERRORS{'WARNING'}, 0, "affiliation name and kms server address must be specified as arguments");
		return;
	}
	
	# Set the default KMS port to 1688 if the argument was not specified
	$kms_port = 1688 unless $kms_port;
	
	# Get a new DataStructure object
	my $data = VCL::DataStructure->new();
	if ($data) {
		notify($ERRORS{'DEBUG'}, 0, "created new DataStructure object");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to create new DataStructure object");
		return;
	}
	
	# Get the Windows activation data from the windows-activation variable
	my $activation_data = $data->get_variable('windows-activation');
	if ($activation_data) {
		notify($ERRORS{'DEBUG'}, 0, "existing activation data:\n" . format_data($activation_data));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "activation data could not be retrieved, hopefully this is the first entry being added");
	}
	
	# Loop through the existing configurations for the affiliation
	for (my $i=0; $i<(@{$activation_data->{$affiliation_name}}); $i++) {
		my $affiliation_configuration = @{$activation_data->{$affiliation_name}}[$i];
		
		# Remove the configuration if it's not defined
		if (!defined $affiliation_configuration) {
			splice @{$activation_data->{$affiliation_name}}, $i--, 1;
			next;
		}
		
		# Check if an identical existing address already exists, if so, delete it
		my $existing_affiliation_kms_address = $affiliation_configuration->{address};
		if ($existing_affiliation_kms_address eq $kms_address) {
			splice @{$activation_data->{$affiliation_name}}, $i--, 1;
			notify($ERRORS{'DEBUG'}, 0, "deleted identical existing address for $affiliation_name: $existing_affiliation_kms_address");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found existing address for $affiliation_name: $existing_affiliation_kms_address");
		}
	}
	
	# Add the KMS configuration to the activation data
	push @{$activation_data->{$affiliation_name}}, {
																method => 'kms',
																address => $kms_address,
																port => $kms_port,
															  };
	
	# Set the variable with the updated data
	$data->set_variable('windows-activation', $activation_data);
	
	# Retrieve the updated configuration data
	$activation_data = $data->get_variable('windows-activation');
	if ($activation_data) {
		notify($ERRORS{'DEBUG'}, 0, "updated activation data:\n" . format_data($activation_data));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "updated activation data could not be retrieved");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 AUTHOR

 Aaron Peeler <aaron_peeler@ncsu.edu>
 Andy Kurth <andy_kurth@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
