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

	if (!$self->deactivate()) {
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

=item *

Activate Windows license

=cut

	$self->activate();

=back

=cut

	notify($ERRORS{'DEBUG'}, 0, "Windows version 6 (Vista, Server 2008) post-load tasks complete");
	return 1;
}

##############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut


#/////////////////////////////////////////////////////////////////////////////

=head2 activate

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs cscript.exe slmgr.vbs -skms to set the KMS server address
               stored on the computer.
               Runs cscript.exe slmgr.vbs -ato to activate licensing on the
               computer.

=cut

sub activate {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $product_name             = $self->get_product_name();
	
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
			
			# Attempt to install the KMS client product key
			# This must be done or else the slmgr.vbs -skms option won't be available
			if ($self->install_kms_client_product_key()) {
				notify($ERRORS{'DEBUG'}, 0, "installed the KMS client product key");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to install the KMS client product key");
				next;
			}
			
			# Run slmgr.vbs -skms to configure the computer to use the KMS server
			if ($self->set_kms($kms_address, $kms_port)) {
				notify($ERRORS{'DEBUG'}, 0, "set KMS address");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to set KMS address");
				next;
			}
		}
		elsif ($activation_method =~ /mak/i) {
			my $mak_key = $activation_config->{key};
			my $mak_product = $activation_config->{product};
			
			if ($mak_product eq $product_name) {
				notify($ERRORS{'DEBUG'}, 0, "attempting to set install MAK key for $mak_product: $mak_key");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "MAK key product ($mak_product) does not match installed version of Windows ($product_name)");
				next;
			}
			
			# Attempt to install the MAK product key
			if ($self->install_product_key($mak_key)) {
				notify($ERRORS{'DEBUG'}, 0, "installed MAK product key: $mak_key");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to install MAK product key: $mak_key");
				next;
			}
		}
		else  {
			notify($ERRORS{'WARNING'}, 0, "unsupported activation method: $activation_method");
			next;
		}
		
		# Attempt to activate the license
		if ($self->activate_license()) {
			notify($ERRORS{'OK'}, 0, "activated license");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to activate license");
			next;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to activate license on $computer_node_name using any configured method");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 install_kms_client_product_key

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : 

=cut

sub install_kms_client_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Create a hash of KMS setup product keys
	# These are publically available from Microsoft's Volume Activation 2.0 Deployment Guide
	my %kms_product_keys = (
		'Windows Vista (R) Business'                         => 'YFKBB-PQJJV-G996G-VWGXY-2V3X8',
		'Windows Vista (R) Business N'                       => 'HMBQG-8H2RH-C77VX-27R82-VMQBT',
		'Windows Vista (R) Enterprise'                       => 'VKK3X-68KWM-X2YGT-QR4M6-4BWMV',
		'Windows Vista (R) Enterprise N'                     => 'VTC42-BM838-43QHV-84HX6-XJXKV',
		'Windows Server (R) 2008 Datacenter'                 => '7M67G-PC374-GR742-YH8V4-TCBY3',
		'Windows Server (R) 2008 Datacenter without Hyper-V' => '22XQ2-VRXRG-P8D42-K34TD-G3QQC',
		'Windows Server (R) 2008 for Itanium-Based Systems'  => '4DWFP-JF3DJ-B7DTH-78FJB-PDRHK',
		'Windows Server (R) 2008 Enterprise'                 => 'YQGMW-MPWTJ-34KDK-48M3W-X4Q6V',
		'Windows Server (R) 2008 Enterprise without Hyper-V' => '39BXF-X8Q23-P2WWT-38T2F-G3FPG',
		'Windows Server (R) 2008 Standard'                   => 'TM24T-X9RMF-VWXK6-X8JC9-BFGM2',
		'Windows Server (R) 2008 Standard without Hyper-V'   => 'W7VD6-7JFBR-RX26B-YKQ3Y-6FFFJ',
		'Windows Web Server (R) 2008'                        => 'WYR28-R7TFJ-3X2YQ-YCY4H-M249D',
	);
	
	# Get the KMS setup product key from the hash
	my $product_name = $self->get_product_name();
	my $product_key = $kms_product_keys{$product_name};
	if (!$product_key) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve KMS setup key for Windows product: $product_name");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "KMS client setup key for $product_name: $product_key");
	
	# Install the KMS client product key
	if ($self->install_product_key($product_key)) {
		notify($ERRORS{'OK'}, 0, "installed KMS client product key");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to install KMS client product key");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 install_product_key

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : 

=cut

sub install_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the arguments
	my $product_key = shift;
	if (!defined($product_key) || !$product_key) {
		notify($ERRORS{'WARNING'}, 0, "product key was not passed correctly as an argument");
		return;
	}
	
	# Run cscript.exe slmgr.vbs -ipk to install the product key
	my $ipk_command = 'cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -ipk ' . $product_key;
	my ($ipk_exit_status, $ipk_output) = run_ssh_command($computer_node_name, $management_node_keys, $ipk_command);
	if (defined($ipk_exit_status) && $ipk_exit_status == 0 && grep(/successfully/i, @$ipk_output)) {
		notify($ERRORS{'OK'}, 0, "installed product key: $product_key");
	}
	elsif (defined($ipk_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to install product key: $product_key, exit status: $ipk_exit_status, output:\n@{$ipk_output}");
		next;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to install product key: $product_key");
		next;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_kms

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : 

=cut

sub set_kms {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Get the KMS address argument
	my $kms_address = shift;
	if (!$kms_address) {
		notify($ERRORS{'WARNING'}, 0, "KMS address was not passed correctly as an argument");
		return;
	}
	
	# Get the KMS port argument or use the default port
	my $kms_port = shift || 1688;
	
	# Run slmgr.vbs -skms to configure the computer to use the KMS server
	my $skms_command = 'cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -skms ' . "$kms_address:$kms_port";
	my ($skms_exit_status, $skms_output) = run_ssh_command($computer_node_name, $management_node_keys, $skms_command);
	if (defined($skms_exit_status) && $skms_exit_status == 0 && grep(/successfully/i, @$skms_output)) {
		notify($ERRORS{'OK'}, 0, "set kms server to $kms_address:$kms_port");
	}
	elsif (defined($skms_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set kms server to $kms_address:$kms_port, exit status: $skms_exit_status, output:\n@{$skms_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to set kms server to $kms_address:$kms_port");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 activate_license

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : 

=cut

sub activate_license {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Run cscript.exe slmgr.vbs -ato to install the product key
	my $ato_command = 'cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -ato';
	my ($ato_exit_status, $ato_output) = run_ssh_command($computer_node_name, $management_node_keys, $ato_command);
	if (defined($ato_exit_status) && $ato_exit_status == 0 && grep(/successfully/i, @$ato_output)) {
		notify($ERRORS{'OK'}, 0, "activated license");
	}
	elsif (defined($ato_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to activate license, exit status: $ato_exit_status, output:\n@{$ato_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to activate license");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 deactivate

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Deletes existing KMS servers keys from the registry.
               Runs cscript.exe slmgr.vbs -rearm to rearm licensing on the
               computer.

=cut

sub deactivate {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
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
	my $rearm_command = 'cscript.exe //NoLogo $SYSTEMROOT/System32/slmgr.vbs -rearm';
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

=head2 run_sysprep

 Parameters  : None
 Returns     : 1 if successful, 0 otherwise
 Description :

=cut

sub run_sysprep {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path();
	my $system32_path_dos = $system32_path;
	$system32_path_dos =~ s/\//\\/g;
	
	# Delete existing setupapi files (log files generated by Sysprep)
	if (!$self->delete_file('C:/Windows/inf/setupapi*')) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete setupapi log files, Sysprep will proceed");
	}

	# Delete existing Sysprep_succeeded.tag file
	if (!$self->delete_file("$system32_path/sysprep/Sysprep*.tag")) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete Sysprep_succeeded.tag log file, Sysprep will proceed");
	}

	# Delete existing Panther directory, contains Sysprep log files
	if (!$self->delete_file("$system32_path/sysprep/Panther")) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete Sysprep Panther directory, Sysprep will proceed");
	}

	# Delete existing Panther directory, contains Sysprep log files
	if (!$self->delete_file("$system32_path/sysprep/Unattend.xml")) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete Sysprep Unattend.xml file, Sysprep will NOT proceed");
		return;
	}

	# Copy Unattend.xml file to sysprep directory
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $cp_command = "cp -f $node_configuration_directory/Utilities/Sysprep/Unattend.xml $system32_path/sysprep/Unattend.xml";
	my ($cp_status, $cp_output) = run_ssh_command($computer_node_name, $management_node_keys, $cp_command);
	if (defined($cp_status) && $cp_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "copied Unattend.xml to $system32_path/sysprep");
	}
	elsif (defined($cp_status)) {
		notify($ERRORS{'OK'}, 0, "failed to copy copy Unattend.xml to $system32_path/sysprep, exit status: $cp_status, output:\n@{$cp_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to copy Unattend.xml to $system32_path/sysprep");
		return;
	}

	# Run Sysprep.exe, use cygstart to lauch the .exe and return immediately
	my $sysprep_command = '/bin/cygstart.exe cmd.exe /c "' . $system32_path_dos . '\\sysprep\\sysprep.exe /generalize /oobe /shutdown /quiet"';
	my ($sysprep_status, $sysprep_output) = run_ssh_command($computer_node_name, $management_node_keys, $sysprep_command);
	if (defined($sysprep_status) && $sysprep_status == 0) {
		notify($ERRORS{'OK'}, 0, "initiated Sysprep.exe, waiting for $computer_node_name to become unresponsive");
	}
	elsif (defined($sysprep_status)) {
		notify($ERRORS{'OK'}, 0, "failed to initiate Sysprep.exe, exit status: $sysprep_status, output:\n@{$sysprep_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to initiate Sysprep.exe");
		return 0;
	}
	
	# Wait maximum of 5 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(5)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
		return 0;
	}
	
	# Wait for 3 minutes then call provisioning module's power_off() subroutine
	# Sysprep does not always shut down the computer when it is done
	notify($ERRORS{'OK'}, 0, "sleeping for 3 minutes to allow Sysprep.exe to finish");
	sleep 180;

	# Call power_off() to make sure computer is shut down
	if (!$self->provisioner->power_off()) {
		# Computer could not be shut off
		notify($ERRORS{'WARNING'}, 0, "unable to power off $computer_node_name");
		return 0;
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
