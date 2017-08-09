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
 Version 6.x Windows OS's include Windows Vista, Windows Server 2008, and
 Windows 7.

=cut

###############################################################################
package VCL::Module::OS::Windows::Version_6;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use File::Basename;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
               directory under the 'tools' directory specific to this OS.

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_Version_6";

###############################################################################

=head1 INTERFACE OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	
	notify($ERRORS{'OK'}, 0, "beginning Windows version 6 image pre-capture tasks");

=item *

Disable the following scheduled tasks:

 * ScheduledDefrag - This task defragments the computers hard disk drives

 * SR - This task creates regular system protection points

 * Consolidator - If the user has consented to participate in the Windows Customer Experience Improvement Program, this job collects and sends usage data to Microsoft

=cut	

	my @scheduled_tasks = (
		'\Microsoft\Windows\Defrag\ScheduledDefrag',
		'\Microsoft\Windows\SystemRestore\SR',
		'\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
	);
	for my $scheduled_task (@scheduled_tasks) {
		$self->disable_scheduled_task($scheduled_task);
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

#//////////////////////////////////////////////////////////////////////////////

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

=item * Call parent class's post_load() subroutine

=cut

	$self->SUPER::post_load() || return;
	
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Windows version 6 post-load tasks");

=item * Ignore default routes configured for the private interface and use default routes configured for the public interface

=cut

	$self->set_ignore_default_routes();

=item * Activate Windows license

=cut

	$self->activate();

=back

=cut

	notify($ERRORS{'DEBUG'}, 0, "Windows version 6 post-load tasks complete");
	return 1;
}

###############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut


#//////////////////////////////////////////////////////////////////////////////

=head2 activate

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Activates Microsoft Windows. A first attempt is made using a
               MAK key if one has been configured in the winProductKey table
               for the version of Windows installed on the computer. If unable
               to activate using a MAK key, activation is attempting using a
               KMS server configured in the winKMS table.

=cut

sub activate {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	## Check if Windows has already been activated
	#my $license_status = $self->get_license_status();
	#if ($license_status && $license_status =~ /licensed/i) {
	#	notify($ERRORS{'OK'}, 0, "Windows has already been activated");
	#	return 1;
	#}
	
	# Attempt to activate first using KMS server
	# Attempt to activate using MAK if KMS fails or is not configured
	if ($self->activate_kms() || $self->activate_mak()) {
		return 1;
	}
	else {
		# Display the computer's current time in vcld.log to help diagnose the problem
		# Activation fails if the client's time is incorrect
		$self->get_current_computer_time('after activation failed');
		
		notify($ERRORS{'CRITICAL'}, 0, "failed to activate Windows using MAK or KMS methods");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 activate_mak

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Attempts to activate Windows using a MAK key stored in the
               winProductKey table.

=cut

sub activate_mak {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the product key stored in the winProductKey table
	# This will return the correct key for the affiliation and version of Windows installed on the computer
	my $product_key = $self->get_product_key();
	if ($product_key) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved MAK product key from the winProductKey table: $product_key");
	}
	else {
		notify($ERRORS{'OK'}, 0, "MAK product key could not be retrieved from the winProductKey table");
		return;
	}
	
	# Attempt to install the MAK product key
	if ($self->run_slmgr_ipk($product_key)) {
		notify($ERRORS{'DEBUG'}, 0, "installed MAK product key: $product_key");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to install MAK product key: $product_key");
		return;
	}
	
	# Attempt to activate the license
	if ($self->run_slmgr_ato()) {
		notify($ERRORS{'OK'}, 0, "activated Windows using MAK product key: $product_key");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to activate Windows using MAK product key: $product_key");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 activate_kms

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Attempts to activate Windows using a KMS server configured in
               the winKMS table.

=cut

sub activate_kms {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the KMS server info from the winKMS table
	my $kms_server_info = $self->get_kms_servers();
	if (!$kms_server_info) {
		notify($ERRORS{'OK'}, 0, "unable to activate because the database does not contain the necessary KMS server information");
		return;
	}
	
	# Attempt to get the KMS client product key
	# This is a publically available key that needs to be installed in order to activate via KMS
	my $product_key = $self->get_kms_client_product_key();
	if ($product_key) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved KMS client product key: $product_key");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "KMS client product key could not be retrieved");
		return;
	}
	
	# Attempt to install the KMS client product key
	if ($self->run_slmgr_ipk($product_key)) {
		notify($ERRORS{'DEBUG'}, 0, "installed KMS client product key: $product_key");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to install KMS client product key: $product_key");
		return;
	}
	
	# Loop through the KMS servers, set KMS server, attempt to activate
	for my $kms_server (@{$kms_server_info}) {
		my $kms_address = $kms_server->{address};
		my $kms_port = $kms_server->{port};
		notify($ERRORS{'DEBUG'}, 0, "attempting to set KMS server: $kms_address:$kms_port");
		
		# Run slmgr.vbs -skms to configure the computer to use the KMS server
		if ($self->run_slmgr_skms($kms_address, $kms_port)) {
			notify($ERRORS{'OK'}, 0, "set KMS server: $kms_address:$kms_port");
			
			# Attempt to activate the license
			if ($self->run_slmgr_ato()) {
				notify($ERRORS{'OK'}, 0, "activated Windows using KMS server: $kms_address:$kms_port");
				return 1;
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to activate Windows using KMS server: $kms_address:$kms_port");
				next;
			}
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to set KMS server: $kms_address:$kms_port");
			next;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to activate Windows using any KMS servers configured in the winKMS table");
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_ipk

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -ipk to install a product key.

=cut

sub run_slmgr_ipk {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $product_key = shift;
	if (!defined($product_key) || !$product_key) {
		notify($ERRORS{'WARNING'}, 0, "product key was not passed correctly as an argument");
		return;
	}
	
	# Run cscript.exe slmgr.vbs -ipk to install the product key
	my $ipk_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -ipk $product_key";
	my ($ipk_exit_status, $ipk_output) = $self->execute({
		command => $ipk_command,
		timeout_seconds => 240,
		display_output => 1
	});
	if (defined($ipk_exit_status) && $ipk_exit_status == 0 && grep(/successfully/i, @$ipk_output)) {
		notify($ERRORS{'OK'}, 0, "installed product key: $product_key");
	}
	elsif (defined($ipk_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to install product key: $product_key, exit status: $ipk_exit_status, output:\n@{$ipk_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to install product key: $product_key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_ckms

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -ckms to clear the KMS server on a Windows client.

=cut

sub run_slmgr_ckms {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run slmgr.vbs -ckms to clear an existing KMS server from a computer
	# slmgr.vbs must be run in a command shell using the correct System32 path or the task it's supposed to do won't really take effect
	my $skms_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -ckms";
	my ($skms_exit_status, $skms_output) = $self->execute({
		command => $skms_command,
		timeout_seconds => 240,
		display_output => 1
	});
	if (defined($skms_exit_status) && $skms_exit_status == 0 && grep(/successfully/i, @$skms_output)) {
		notify($ERRORS{'OK'}, 0, "cleared kms server");
	}
	elsif (defined($skms_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to clear kms server, exit status: $skms_exit_status, output:\n@{$skms_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to clear kms server");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_cpky

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -cpky to clear the KMS server on a Windows client.

=cut

sub run_slmgr_cpky {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run slmgr.vbs -cpky to clear an existing product key from a computer
	# slmgr.vbs must be run in a command shell using the correct System32 path or the task it's supposed to do won't really take effect
	my $skms_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -cpky";
	my ($skms_exit_status, $skms_output) = $self->execute({
		command => $skms_command,
		timeout_seconds => 240,
		display_output => 1
	});
	if (defined($skms_exit_status) && $skms_exit_status == 0 && grep(/successfully/i, @$skms_output)) {
		notify($ERRORS{'OK'}, 0, "cleared product key");
	}
	elsif (defined($skms_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to clear product key, exit status: $skms_exit_status, output:\n@{$skms_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to clear product key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_skms

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -skms to set the KMS server on a Windows client.

=cut

sub run_slmgr_skms {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Get the KMS address argument
	my $kms_address = shift;
	if (!$kms_address) {
		notify($ERRORS{'WARNING'}, 0, "KMS address was not passed correctly as an argument");
		return;
	}
	
	# Get the KMS port argument or use the default port
	my $kms_port = shift || 1688;
	
	# Run slmgr.vbs -skms to configure the computer to use the KMS server
	# slmgr.vbs must be run in a command shell using the correct System32 path or the task it's supposed to do won't really take effect
	my $skms_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -skms $kms_address:$kms_port";
	my ($skms_exit_status, $skms_output) = $self->execute({
		command => $skms_command,
		timeout_seconds => 240,
		display_output => 1
	});
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

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_ato

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -ato to activate Windows.

=cut

sub run_slmgr_ato {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run cscript.exe slmgr.vbs -ato to install the product key
	my $ato_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -ato";
	my ($ato_exit_status, $ato_output) = $self->execute({
		command => $ato_command,
		timeout_seconds => 240,
		display_output => 1
	});
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

#//////////////////////////////////////////////////////////////////////////////

=head2 run_slmgr_dlv

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs slmgr.vbs -dlv to display licensing information.

=cut

sub run_slmgr_dlv {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run cscript.exe slmgr.vbs -dlv to install the product key
	my $dlv_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -dlv";
	my ($dlv_exit_status, $dlv_output) = $self->execute({
		command => $dlv_command,
		timeout_seconds => 120,
		display_output => 1
	});
	if (defined($dlv_exit_status) && $dlv_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "licensing information:\n" . join("\n", @$dlv_output));
	}
	elsif (defined($dlv_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve licensing information, exit status: $dlv_exit_status, output:\n@{$dlv_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to retrieve licensing information");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_license_status

 Parameters  : None
 Returns     : If successful: string
               If failed: false
 Description : Runs slmgr.vbs -dlv to determine the licensing status. The value
               of the "License Status" line is returned.

=cut

sub get_license_status {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run cscript.exe slmgr.vbs -dlv to get the activation status
	my $dlv_command = "$system32_path/cscript.exe //NoLogo \$SYSTEMROOT/System32/slmgr.vbs -dlv";
	my ($dlv_exit_status, $dlv_output) = $self->execute($dlv_command);
	if ($dlv_output && grep(/License Status/i, @$dlv_output)) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved license information");
	}
	elsif (defined($dlv_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve activation status, exit status: $dlv_exit_status, output:\n@{$dlv_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to retrieve activation status");
		return;
	}
	
	my ($license_status_line) = grep(/License Status/i, @$dlv_output);
	my ($license_status) = $license_status_line =~ /: (.+)/;
	notify($ERRORS{'DEBUG'}, 0, "retrieved license status: $license_status");
	return $license_status;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Clear the product key from the registry
	$self->run_slmgr_cpky();
	
	# Clear the KMS address from the registry
	$self->run_slmgr_ckms();
	
	# Set SkipRearm=1 so the rearm count isn't decremented
	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SL]
"SkipRearm"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform]
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
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $system32_path = $self->get_system32_path() || return;
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= $system32_path . '/netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' ; ';
	
	$add_rule_command .= $system32_path . '/netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow ping to/from any address"';
	$add_rule_command .= ' description="Allows incoming ping (ICMP type 8) messages to/from any address"';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=any';
	$add_rule_command .= ' remoteip=any';
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = $self->execute($add_rule_command);
	
	if (defined($add_rule_output) && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Get the computer's private IP address
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
		return;
	}
	
	# First delete any rules which allow ping and then add a new rule
	my $add_rule_command;
	$add_rule_command .= $system32_path . '/netsh.exe advfirewall firewall delete rule';
	$add_rule_command .= ' name=all';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' ; ';
	
	$add_rule_command .= $system32_path . '/netsh.exe advfirewall firewall add rule';
	$add_rule_command .= ' name="VCL: allow ping to ' . $private_ip_address . '"';
	$add_rule_command .= ' description="Allows incoming ping (ICMP type 8) messages to ' . $private_ip_address . '"';
	$add_rule_command .= ' protocol=icmpv4:8,any';
	$add_rule_command .= ' action=allow';
	$add_rule_command .= ' enable=yes';
	$add_rule_command .= ' dir=in';
	$add_rule_command .= ' localip=' . $private_ip_address;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = $self->execute($add_rule_command);
	
	if (defined($add_rule_output) && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $system32_path = $self->get_system32_path() || return;
	
	# First delete any rules which allow ping and then add a new rule
	my $netsh_command;
	$netsh_command .= $system32_path . '/netsh.exe advfirewall firewall delete rule';
	$netsh_command .= ' name=all';
	$netsh_command .= ' dir=in';
	$netsh_command .= ' protocol=icmpv4:8,any';
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output) && @$netsh_output[-1] =~ /Ok/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow ping");
	}
	elsif (defined($netsh_output) && @$netsh_output[-1] =~ /No rules match/i) {
		notify($ERRORS{'OK'}, 0, "no firewall rules exist which enable ping");
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

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  : Remote IP address (optional) or 'private' (optional)
 Returns     : 1 if succeeded, 0 otherwise
 Description : Adds Windows firewall rules to allow RDP traffic. There are 3
               modes:
               1. No argument is passed: RDP is allowed to/from any IP address
               
               2. IP address argument is passed: RDP is allowed from the remote
               IP address specified and to the local private IP address. The
               argument can be a single IP address or in CIDR format.
               
               3. The string 'private' is passed: RDP is allowed only to the
               local private IP address.

=cut

sub firewall_enable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $remote_ip;
	my $rule_name;
	my $rule_description;
	
	# Check if 'private' or IP address argument was passed
	my $argument = shift;
	if ($argument) {
		# Check if argument is an IP address
		if ($argument =~ /^[\d\.\/]+$/) {
			$remote_ip = $argument;
			notify($ERRORS{'DEBUG'}, 0, "opening RDP for remote IP address: $remote_ip");
			$rule_name = "VCL: allow RDP port 3389 from $remote_ip";
			$rule_description = "Allows incoming TCP port 3389 traffic from $remote_ip";
		}
		elsif ($argument eq 'private') {
			notify($ERRORS{'DEBUG'}, 0, "opening RDP for private IP address only");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "argument may only be 'private' or an IP address in the form xxx.xxx.xxx.xxx or xxx.xxx.xxx.xxx/yy");
			return;
		}
	}
	else {
		# No argument was passed, RDP will be opened to/from any address
		notify($ERRORS{'DEBUG'}, 0, "opening RDP to/from any IP address");
		$remote_ip = 'any';
		$rule_name = "VCL: allow RDP port 3389 to/from any address";
		$rule_description = "Allows incoming TCP port 3389 traffic to/from any address";
	}
	
	# Get the computer's private IP address
	my $private_ip_address = $self->get_private_ip_address();
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
		if ($argument && $argument eq 'private') {
			notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable RDP to private IP address");
			return;
		}
	}
	
	my $add_rule_command;
	
	# Set the key to allow remote connections whenever enabling RDP
	$add_rule_command .= $system32_path . '/reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /t REG_DWORD /v fDenyTSConnections /d 0 /f ; ';
	
	# Set the key to allow connections from computers running any version of Remote Desktop
	$add_rule_command .= $system32_path . '/reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp" /t REG_DWORD /v UserAuthentication /d 0 /f ; ';
	
	# First delete any rules which allow ping and then add a new rule
	$add_rule_command .= "$system32_path/netsh.exe advfirewall firewall delete rule";
	$add_rule_command .= " name=all";
	$add_rule_command .= " dir=in";
	$add_rule_command .= " protocol=TCP";
	$add_rule_command .= " localport=3389";
	$add_rule_command .= " ;";
	
	# Add the rule to open RDP for the private IP address if the private IP address was found
	# No need to add the rule if the remote IP is any because it will be opened universally
	if ($private_ip_address && (!$remote_ip || ($remote_ip && $remote_ip ne 'any'))) {
		$add_rule_command .= " $system32_path/netsh.exe advfirewall firewall add rule";
		$add_rule_command .= " name=\"VCL: allow RDP port 3389 to $private_ip_address\"";
		$add_rule_command .= " description=\"Allows incoming RDP (TCP port 3389) traffic to $private_ip_address\"";
		$add_rule_command .= " protocol=TCP";
		$add_rule_command .= " localport=3389";
		$add_rule_command .= " action=allow";
		$add_rule_command .= " enable=yes";
		$add_rule_command .= " dir=in";
		$add_rule_command .= " localip=$private_ip_address";
		$add_rule_command .= " ;";
	}
	
	# Add the rule to open RDP for the remote public IP address
	if ($remote_ip) {
		$add_rule_command .= " $system32_path/netsh.exe advfirewall firewall add rule";
		$add_rule_command .= " name=\"$rule_name\"";
		$add_rule_command .= " description=\"$rule_description\"";
		$add_rule_command .= " protocol=TCP";
		$add_rule_command .= " action=allow";
		$add_rule_command .= " enable=yes";
		$add_rule_command .= " dir=in";
		$add_rule_command .= " localip=any";
		$add_rule_command .= " localport=3389";
		$add_rule_command .= " remoteip=" . $remote_ip;
	}
	
	# Set $remote_ip for output messages if it isn't defined
	$remote_ip = 'private only' if !$remote_ip;
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = $self->execute($add_rule_command);
	if (defined($add_rule_output) && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->firewall_enable_rdp('private');
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $system32_path = $self->get_system32_path() || return;
	
	# First delete any rules which allow ping and then add a new rule
	my $netsh_command;
	$netsh_command .= $system32_path. '/netsh.exe advfirewall firewall delete rule';
	$netsh_command .= ' name=all';
	$netsh_command .= ' dir=in';
	$netsh_command .= ' protocol=TCP';
	$netsh_command .= ' localport=3389';
	
	# Delete the firewall rule
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output) && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "deleted firewall rules which enable RDP");
	}
	elsif (defined($netsh_output) && @$netsh_output[-1] =~ /No rules match/i) {
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Check if 'private' argument was passed
	my $enable_private = shift;
	if ($enable_private && $enable_private !~ /private/i) {
		notify($ERRORS{'WARNING'}, 0, "argument may only be the string 'private': $enable_private");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $rule_name;
	my $rule_description;
	my $rule_localip;
	if ($enable_private) {
		# Get the computer's private IP address
		my $private_ip_address = $self->get_private_ip_address();
		if (!$private_ip_address) {
			notify($ERRORS{'WARNING'}, 0, "unable to retrieve private IP address");
			return;
		}
		
		$rule_name = "VCL: allow SSH port 22 to $private_ip_address";
		$rule_description = "Allows incoming SSH (TCP port 22) traffic to $private_ip_address";
		$rule_localip = $private_ip_address;
	}
	else {
		$rule_name = "VCL: allow SSH port 22 to/from any address";
		$rule_description = "Allows incoming SSH (TCP port 22) traffic to/from any address";
		$rule_localip = "any";
	}
	
	# Assemble a chain of commands
	my $add_rule_command;
	
	# Get the firewall state - "ON" or "OFF"
	# Turn firewall off before altering SSH exceptions or command may hang
	my $firewall_state = $self->get_firewall_state() || 'ON';
	if ($firewall_state eq 'ON') {
		notify($ERRORS{'DEBUG'}, 0, "firewall is on, it will be turned off while SSH port exceptions are altered");
		$add_rule_command .= $system32_path . '/netsh.exe advfirewall set currentprofile state off ; sleep 1 ; ';
	}
	
	# The existing matching rules must be deleted first or they will remain in effect
	$add_rule_command .= "$system32_path/netsh.exe advfirewall firewall delete rule";
	$add_rule_command .= " name=all";
	$add_rule_command .= " dir=in";
	$add_rule_command .= " protocol=TCP";
	$add_rule_command .= " localport=22";
	$add_rule_command .= " ;";
	
	$add_rule_command .= " $system32_path/netsh.exe advfirewall firewall add rule";
	$add_rule_command .= " name=\"$rule_name\"";
	$add_rule_command .= " description=\"$rule_description\"";
	$add_rule_command .= " protocol=TCP";
	$add_rule_command .= " localport=22";
	$add_rule_command .= " action=allow";
	$add_rule_command .= " enable=yes";
	$add_rule_command .= " dir=in";
	$add_rule_command .= " localip=$rule_localip";
	$add_rule_command .= " remoteip=any";
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = $self->execute($add_rule_command);
	
	if (defined($add_rule_output) && @$add_rule_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "added firewall rule to enable SSH to address: $rule_localip");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH to address: $rule_localip, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule to enable SSH to address: $rule_localip");
		return;
	}
	
	# Turn the firewall back on after SSH exceptions are set
	if ($firewall_state eq 'ON') {
		my $firewall_enable_command = "$system32_path/netsh.exe advfirewall set currentprofile state on";
		my ($firewall_enable_exit_status, $firewall_enable_output) = $self->execute($firewall_enable_command);
		if (defined($firewall_enable_output) && @$firewall_enable_output[-1] =~ /Ok/i) {
			notify($ERRORS{'OK'}, 0, "turned on firewall after turning it off to alter SSH port exceptions");
		}
		elsif (defined($firewall_enable_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn on firewall after turning it off to alter SSH port exceptions, exit status: $firewall_enable_exit_status, output:\n@{$firewall_enable_output}");
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to turn on firewall after turning it off to alter SSH port exceptions");
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->firewall_enable_ssh('private');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_firewall_state

 Parameters  : None
 Returns     : If successful: string "ON" or "OFF"
 Description : Determines if the Windows firewall is on or off.  Returns "ON"
               if either the Public or Private firewall profile is on. Returns
               "OFF" only if all current firewall profiles are off.

=cut

sub get_firewall_state {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run netsh.exe to get the state of the current firewall profile
	my $netsh_command = "$system32_path/netsh.exe advfirewall show currentprofile state";
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	if (defined($netsh_output)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved firewall state");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall state, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall state");
		return;
	}
	
	# Get the lines containing 'State'
	# There are multiple for the Private and Public profiles
	my @state_lines = grep(/State/, @$netsh_output);
	if (!@state_lines) {
		notify($ERRORS{'WARNING'}, 0, "unable to find 'State' line in output:\n" . join("\n", @$netsh_output));
		return;
	}
	
	# Loop through lines, if any contain "ON", return "ON"
	for my $state_line (@state_lines) {
		if ($state_line =~ /on/i) {
			notify($ERRORS{'OK'}, 0, "returning firewall state: ON");
			return "ON";
		}
		elsif ($state_line !~ /off/i) {
			notify($ERRORS{'WARNING'}, 0, "firewall state line does not contain ON or OFF");
			return;
		}
	}
	
	# No state lines were found containing "ON", return "OFF"
	notify($ERRORS{'OK'}, 0, "returning firewall state: OFF");
	return "OFF";
}

#//////////////////////////////////////////////////////////////////////////////

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
                   "description" => "VCL: allow ICMP/8 from 10.10.14.14",
                   "local_ip" => "Any",
                   "name" => "VCL: allow ICMP/8 from 10.10.14.14",
                   "scope" => "10.10.14.14/32"
                 }
               },
               "TCP" => {
                 3389 => {
                   "description" => "Allows incoming TCP port 3389 traffic",
                   "local_ip" => "Any",
                   "name" => "VCL: allow RDP port 3389",
                   "scope" => "Any"
                 },
               },

=cut

sub get_firewall_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{firewall_configuration} if $self->{firewall_configuration};
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $firewall_configuration;
	
	my $command = "$system32_path/netsh.exe advfirewall firewall show rule name=all verbose";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to show firewall rules on $computer_node_name");
		return;
	}
	elsif (!grep(/Rule Name:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to show firewall rules on $computer_node_name, command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Execute the netsh.exe command to retrieve firewall rules
	#   Rule Name:                            VCL: allow RDP port 3389
	#   ----------------------------------------------------------------------
	#   Enabled:                              Yes
	#   Direction:                            In
	#   Profiles:                             Domain,Private,Public
	#   Grouping:
	#   LocalIP:                              Any
	#   RemoteIP:                             152.14.53.0/26,10.10.1.2-10.10.2.22
	#   Protocol:                             TCP
	#   LocalPort:                            3389
	#   RemotePort:                           Any
	#   Edge traversal:                       No
	#   Action:                               Allow
	#   Rule Name:                            VCL: allow ping to/from any address
	#   ----------------------------------------------------------------------
	#   Enabled:                              Yes
	#   Direction:                            In
	#   Profiles:                             Domain,Private,Public
	#   Grouping:
	#   LocalIP:                              Any
	#   RemoteIP:                             Any
	#   Protocol:                             ICMPv4
	#                                         Type    Code
	#                                         8       Any
	#   Edge traversal:                       No
	#   Action:                               Allow
	
	# Split the output into rule sections
	my @rule_sections = split(/Rule Name:\s*/, join("\n", @$output));
	
	RULE: for my $rule_section (@rule_sections) {
		my @lines = split(/\n+/, $rule_section);
		
		my $rule_name = shift(@lines);
		
		# The first rule section will probably be blank because of the way split works
		next RULE if (!$rule_name);
		
		my $rule_info;
		for my $line (@lines) {
			if (my ($parameter, $value) = $line =~ /^(\w+):\s*(.*)/g) {
				$rule_info->{$parameter} = $value;
			}
			elsif ($rule_info->{Protocol} && $rule_info->{Protocol} =~ /icmp/i) {
				if (my ($icmp_type, $icmp_code) = $line =~ /^\s*(\d+)\s+(.*)/g) {
					push @{$rule_info->{ICMPTypes}{$icmp_type}}, $icmp_code;
				}
			}
		}
		
		if (!defined($rule_info->{Enabled}) || $rule_info->{Enabled} !~ /yes/i) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring disabled rule: '$rule_name'");
			next RULE;
		}
		if (!defined($rule_info->{Direction}) || $rule_info->{Direction} !~ /in/i) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring outgoing rule: '$rule_name'");
			next RULE;
		}
		elsif (!defined($rule_info->{Action}) || $rule_info->{Action} !~ /allow/i) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule: '$rule_name', Action is NOT allow");
			next RULE;
		}
		elsif (!defined($rule_info->{Protocol})) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring rule: '$rule_name', Protocol is not defined:\n$rule_section");
			next RULE;
		}
		elsif ($rule_info->{Protocol} =~ /v6/i) {
			# Skip IPv6 rules for now
			next RULE;
		}
		
		my @ports;
		
		if ($rule_info->{Protocol} =~ /icmp/i) {
			if (!defined($rule_info->{ICMPTypes})) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring rule: '$rule_name', ICMP type could not be determined:\n$rule_section");
				next RULE;
			}
			@ports = sort keys(%{$rule_info->{ICMPTypes}})
		}
		else {
			if (!defined($rule_info->{LocalPort})) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule: '$rule_name', LocalPort is not defined");
				next RULE;
			}
			elsif ($rule_info->{LocalPort} !~ /^\d+$/) {
				#notify($ERRORS{'DEBUG'}, 0, "ignoring rule: '$rule_name', LocalPort is not an integer");
				next RULE;
			}
			
			@ports = split(",", $rule_info->{LocalPort});
		}
		
		if (!@ports) {
			notify($ERRORS{'WARNING'}, 0, "ignoring rule: '$rule_name', no ports defined:\n" . format_data($rule_info) . "\n$rule_section");
			next RULE;
		}
		
		for my $port (@ports) {
			$firewall_configuration->{$rule_info->{Protocol}}{$port}{name} = $rule_name;
			$firewall_configuration->{$rule_info->{Protocol}}{$port}{description} = $rule_info->{Description};
			$firewall_configuration->{$rule_info->{Protocol}}{$port}{scope} = $rule_info->{RemoteIP};
			$firewall_configuration->{$rule_info->{Protocol}}{$port}{local_ip} = $rule_info->{LocalIP};
		}
	}
	
	# Assemble a string containing all the rule info (don't print_data because it outputs too much to vcld.log)
	my $rules_string;
	for my $protocol (keys %$firewall_configuration) {
		for my $port (sort keys %{$firewall_configuration->{$protocol}}) {
			my $name = $firewall_configuration->{$protocol}{$port}{name};
			my $scope = $firewall_configuration->{$protocol}{$port}{scope};
			my $local_ip = $firewall_configuration->{$protocol}{$port}{local_ip};
			$rules_string .= "$protocol:$port '$name' - local IP: $local_ip, scope: $scope\n";
		}
	}
	
	# Copy the ICMPv4 key to one named ICMP for compatibility
	if (defined($firewall_configuration->{ICMPv4})) {
		$firewall_configuration->{ICMP} = $firewall_configuration->{ICMPv4};
	}
	
	$self->{firewall_configuration} = $firewall_configuration;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved firewall info from $computer_node_name:\n$rules_string");
	return $firewall_configuration;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _enable_firewall_port_helper

 Parameters  : 
 Returns     : boolean
 Description : This subroutine is called by enable_firewall_port. It runs the
               necessary 'netsh advfirewall' command to configure the firewall.

=cut

sub _enable_firewall_port_helper {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($protocol, $port, $scope, $overwrite_existing, $name, $description) = @_;
	if (!defined($protocol) || !defined($port) || !defined($scope) || !defined($name)) {
		notify($ERRORS{'WARNING'}, 0, "protocol, port, scope, and name arguments were not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	$scope = 'any' if $scope eq '0.0.0.0/0.0.0.0';
	
	my $netsh_command;
	
	if ($protocol =~ /icmp/i) {
		$netsh_command .= "$system32_path/netsh.exe advfirewall firewall delete rule";
		$netsh_command .= " name=all";
		$netsh_command .= " dir=in";
		$netsh_command .= " protocol=icmpv4:$port,any";
		$netsh_command .= " ; ";
		
		$netsh_command .= " $system32_path/netsh.exe advfirewall firewall add rule";
		$netsh_command .= " name=\"$name\"";
		$netsh_command .= " description=\"$description\"";
		$netsh_command .= " protocol=icmpv4:$port,any";
		$netsh_command .= " action=allow";
		$netsh_command .= " enable=yes";
		$netsh_command .= " dir=in";
		$netsh_command .= " localip=any";
		$netsh_command .= " remoteip=$scope";
	}
	else {
		$netsh_command .= "$system32_path/netsh.exe advfirewall firewall delete rule";
		$netsh_command .= " name=all";
		$netsh_command .= " dir=in";
		$netsh_command .= " protocol=$protocol";
		$netsh_command .= " localport=$port";
		$netsh_command .= " ;";
		
		$netsh_command .= " $system32_path/netsh.exe advfirewall firewall add rule";
		$netsh_command .= " name=\"$name\"";
		$netsh_command .= " description=\"$description\"";
		$netsh_command .= " protocol=$protocol";
		$netsh_command .= " action=allow";
		$netsh_command .= " enable=yes";
		$netsh_command .= " dir=in";
		$netsh_command .= " localip=any";
		$netsh_command .= " localport=$port";
		$netsh_command .= " remoteip=$scope";
	}

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command, 1);
	
	if (!defined($netsh_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to open firewall on $computer_node_name, command: '$netsh_command'");
		return;
	}
	elsif (@$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "opened firewall on $computer_node_name:\n" .
			"name: '$name'\n" .
			"protocol: $protocol\n" .
			"port/type: $port\n" .
			"scope: $scope"
		);
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name:\n" .
			"name: '$name'\n" .
			"protocol: $protocol\n" .
			"port/type: $port\n" .
			"scope: $scope\n" .
			"command : '$netsh_command'" .
			"exit status: $netsh_exit_status\n" .
			"output:\n" . join("\n", @$netsh_output)
		);
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	my $node_configuration_directory = $self->get_node_configuration_directory();
	
	my $time_zone_name = $self->get_time_zone_name();
	if (!$time_zone_name) {
		notify($ERRORS{'WARNING'}, 0, "time zone name could not be retrieved");
		return;
	}
	
	my $product_key = $self->get_kms_client_product_key();
	if (!$product_key) {
		notify($ERRORS{'WARNING'}, 0, "KMS client product key could not be retrieved");
		return;
	}
	
	# Set the processorArchitecture to either amd64 or x86 in the XML depending on whether or not the OS is 64-bit
	my $architecture = $self->is_64_bit() ? 'amd64' : 'x86';
	
	my $unattend_xml_file_path = "$system32_path/sysprep/Unattend.xml";
	
	my $unattend_xml_contents = <<EOF;
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
	<settings pass="generalize">
		<component name="Microsoft-Windows-PnpSysprep" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<PersistAllDeviceInstalls>false</PersistAllDeviceInstalls>
			<DoNotCleanUpNonPresentDevices>false</DoNotCleanUpNonPresentDevices>
		</component>
		<component name="Microsoft-Windows-Security-SPP" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<SkipRearm>1</SkipRearm>
		</component>
	</settings>
	<settings pass="specialize">
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<Display>
				<ColorDepth>32</ColorDepth>
				<DPI>120</DPI>
				<HorizontalResolution>1024</HorizontalResolution>
				<VerticalResolution>768</VerticalResolution>
				<RefreshRate>72</RefreshRate>
			</Display>
			<ComputerName>*</ComputerName>
			<TimeZone>$time_zone_name</TimeZone>
			<ProductKey>$product_key</ProductKey>
		</component>
		<component name="Microsoft-Windows-Deployment" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<RunSynchronous>
				<RunSynchronousCommand wcm:action="add">
					<Path>C:\\Cygwin\\home\\root\\VCL\\Scripts\\sysprep_cmdlines.cmd &gt; C:\\cygwin\\home\\root\\VCL\\Logs\\sysprep_cmdlines.log 2&gt;&amp;1</Path>
					<Order>1</Order>
				</RunSynchronousCommand>
			</RunSynchronous>
		</component>
		<component name="Microsoft-Windows-Security-SPP-UX" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<SkipAutoActivation>true</SkipAutoActivation>
		</component>
		<component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<Identification>
				<JoinWorkgroup>VCL</JoinWorkgroup>
			</Identification>
		</component>
	</settings>
	<settings pass="auditSystem">
		<component name="Microsoft-Windows-PnpCustomizationsNonWinPE" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<DriverPaths>
				<PathAndCredentials wcm:action="add" wcm:keyValue="1">
					<Path>C:\\Cygwin\\home\\root\\VCL\\Drivers</Path>
				</PathAndCredentials>
			</DriverPaths>
		</component>
	</settings>
	<settings pass="oobeSystem">
		<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<OOBE>
				<HideEULAPage>true</HideEULAPage>
				<NetworkLocation>Work</NetworkLocation>
				<ProtectYourPC>3</ProtectYourPC>
			</OOBE>
			<UserAccounts>
				<AdministratorPassword>
					<Value>$WINDOWS_ROOT_PASSWORD</Value>
					<PlainText>true</PlainText>
				</AdministratorPassword>
				<LocalAccounts>
					<LocalAccount wcm:action="add">
						<Password>
							<Value>$WINDOWS_ROOT_PASSWORD</Value>
							<PlainText>true</PlainText>
						</Password>
						<Group>Administrators</Group>
						<Name>root</Name>
						<DisplayName>root</DisplayName>
						<Description>VCL root account</Description>
					</LocalAccount>
				</LocalAccounts>
			</UserAccounts>
		</component>
		<component name="Microsoft-Windows-International-Core" processorArchitecture="$architecture" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
			<InputLocale>en-US</InputLocale>
			<SystemLocale>en-US</SystemLocale>
			<UILanguage>en-US</UILanguage>
			<UserLocale>en-US</UserLocale>
		</component>
	</settings>
</unattend>
EOF

	notify($ERRORS{'DEBUG'}, 0, "'$unattend_xml_file_path' contents:\n$unattend_xml_contents");
	if (!$self->create_text_file($unattend_xml_file_path, $unattend_xml_contents)) {
		return;
	}
	
	# Delete existing Panther directory, contains Sysprep log files
	$self->delete_file('C:/Windows/Panther');
	
	# Delete existing sysprep/Panther directory, contains Sysprep log files
	$self->delete_file("$system32_path/sysprep/Panther");
	
	# Delete existing setupapi files
	$self->delete_file('C:/Windows/inf/setupapi*');
	
	# Delete existing INFCACHE files
	$self->delete_file('C:/Windows/inf/INFCACHE*');
	
	# Delete existing INFCACHE files
	$self->delete_file('C:/Windows/inf/oem*.inf');
	
	# Delete existing Sysprep_succeeded.tag file
	$self->delete_file("$system32_path/sysprep/Sysprep*.tag");
	
	# Delete existing MSDTC.LOG file
	$self->delete_file("$system32_path/MsDtc/MSTTC.LOG");
	
	# Delete existing VCL log files
	$self->delete_file("C:/Cygwin/home/root/VCL/Logs/*");
	
	# Delete legacy Sysprep directory
	$self->delete_file("C:/Cygwin/home/root/VCL/Utilities/Sysprep");
	
	# Grant permissions to the SYSTEM user - this is needed or else Sysprep fails
	$self->execute("cmd.exe /c \"$system32_path/icacls.exe $node_configuration_directory /grant SYSTEM:(OI)(CI)(F) /C\"");
	
	# Uninstall and reinstall MsDTC
	my $msdtc_command = "$system32_path/msdtc.exe -uninstall ; $system32_path/msdtc.exe -install";
	my ($msdtc_status, $msdtc_output) = $self->execute($msdtc_command);
	if (defined($msdtc_status) && $msdtc_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "reinstalled MsDtc");
	}
	elsif (defined($msdtc_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to reinstall MsDtc, exit status: $msdtc_status, output:\n@{$msdtc_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to reinstall MsDtc");
	}
	
	# Get the node drivers directory and convert it to DOS format
	my $drivers_directory = "$node_configuration_directory/Drivers";
	$drivers_directory =~ s/\//\\\\/g;
	
	# Set the Installation Sources registry key
	# Must use reg_add because the type is REG_MULTI_SZ
	my $setup_key = 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup';
	if ($self->reg_add($setup_key, 'Installation Sources', 'REG_MULTI_SZ', $drivers_directory)) {
		notify($ERRORS{'DEBUG'}, 0, "added Installation Sources registry key");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add Installation Sources registry key");
	}
	
	# Set the DevicePath registry key
	# This is used to locate device drivers
	if (!$self->set_device_path_key()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the DevicePath registry key");
		return;
	}
	
	# Reset the Windows setup registry keys
	# If Sysprep fails it will set keys which make running Sysprep again impossible
	# These keys never get reset, Microsoft instructs you to reinstall the OS
	# Clearing out these keys before running Sysprep allows it to be run again
	# Also enable verbose Sysprep logging
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup]
"LogLevel"=dword:0000FFFF

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State]
"ImageState"="IMAGE_STATE_COMPLETE"

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\Sysprep\\Generalize]
"{82468857-ad9b-1a37-533f-7db889fff253}"=-

[-HKEY_LOCAL_MACHINE\\SYSTEM\\Setup\\Status]
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "reset Windows setup state in the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reset the Windows setup state in the registry");
		return 0;
	}
	
	# Kill the screen saver process, it occasionally prevents reboots and shutdowns from working
	$self->kill_process('logon.scr');
	
	# Run Sysprep.exe, use cygstart to lauch the .exe and return immediately
	my $sysprep_command = "/bin/cygstart.exe \$SYSTEMROOT/system32/cmd.exe /c \"";
	
	# Run Sysprep.exe
	$sysprep_command .= "$system32_path/sysprep/sysprep.exe /generalize /oobe /shutdown /quiet /unattend:\$SYSTEMROOT/System32/sysprep/Unattend.xml";
	
	$sysprep_command .= "\"";
	
	# Run Sysprep.exe, use cygstart to lauch the .exe and return immediately
	my ($sysprep_status, $sysprep_output) = $self->execute($sysprep_command);
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
	
	# Wait maximum of 30 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(1800)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
		return;
	}
	
	# Wait maximum of 15 minutes for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(900);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 5 minutes to allow computer time to shutdown");
		sleep 300;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_ignore_default_routes

 Parameters  : Interface type (public or private), mode (enabled or disabled)
 Returns     : If successful: true
               If failed: false
 Description : Configures the public interface with "ignore default routes =
					disabled" and the private interface with "ignore default routes =
					enabled". This is necessary in order for traffic to be correctly
					routed out of the computer. If default routes are configured for
					both the public and private interfaces and the metric for the
					private default route is equal to or less than the metric for the
					public route, traffic originating from the computer to the
					Internet will fail because it will be routed on the private
					interface.

=cut

sub set_ignore_default_routes {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Get the private interface name
	my $private_interface_name = $self->get_private_interface_name();
	if (!$private_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine private interface name");
		return;	
	}
	
	# Get the public interface name
	my $public_interface_name = $self->get_public_interface_name();
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine public interface name");
		return;	
	}
	
	# Run netsh.exe to configure any default routes configured for the public interface to be used
	my $netsh_command = "$system32_path/netsh.exe interface ip set interface \"$public_interface_name\" ignoredefaultroutes=disabled";
	
	# If multiple interfaces are used, set the private interface to ignore default routes
	if ($private_interface_name ne $public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "computer has multiple network interfaces, configuring ignore default routes:\nprivate interface '$private_interface_name': enabled\npublic interface '$public_interface_name': disabled");
		$netsh_command .= " & $system32_path/netsh.exe interface ip set interface \"$private_interface_name\" ignoredefaultroutes=enabled";
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "computer has a single network interface, configuring ignore default routes:\ninterface '$private_interface_name': enabled");
	}
	
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	if (!defined($netsh_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure ignore default routes");
		return;
	}
	elsif ($netsh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "configured ignore default routes");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure ignore default routes, exit status: $netsh_exit_status\ncommand: '$netsh_command'\noutput:\n" . join("\n", @$netsh_output));
		return;
	}
	
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 defragment_hard_drive

 Parameters  : None
 Returns     : 1
 Description : Hard drive defragmentation is skipped for Windows version 6.x
               (Vista and Server 2008) because it takes a very long time. This
               subroutine always returns 1.

=cut

sub defragment_hard_drive {
	# Skip hard drive defragmentation because it takes a very long time for Windows 6.x (Vista, 2008)
	notify($ERRORS{'OK'}, 0, "skipping hard drive defragmentation for Windows 6.x because it takes too long, returning 1");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_response

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Waits for the reservation computer to respond to SSH after it
               has been loaded.

=cut

sub wait_for_response {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $initial_delay_seconds;
	my $ssh_response_timeout_seconds;
	
	if ($self->data->get_computer_type() eq 'virtualmachine') {
		$initial_delay_seconds = 5;
		$ssh_response_timeout_seconds = 300; 
	}
	elsif ($self->data->get_imagemeta_sysprep()) {
		$initial_delay_seconds = 60;
		$ssh_response_timeout_seconds = 1800; 
	}
	else {
		$initial_delay_seconds = 15;
		$ssh_response_timeout_seconds = 600; 
	}
	
	if ($self->SUPER::wait_for_response($initial_delay_seconds, $ssh_response_timeout_seconds, 5)) {
		return 1;
	}
	
	if ($self->provisioner->can('power_reset')) {
		if ($self->provisioner->power_reset()) {
			return $self->SUPER::wait_for_response(15, 600, 5);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "computer never responded and provisioning module failed to perform a power reset, returning false");
			return;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "computer never responded and provisioning does not implement a power_reset subroutine, returning false");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize_files

 Parameters  : none
 Returns     : boolean
 Description : Removes the Windows root password from files on the computer.

=cut

sub sanitize_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my @file_paths = (
		"$system32_path/sysprep",
		'$SYSTEMROOT/Panther',
	);
	
	# Call the subroutine in Windows.pm
	return $self->SUPER::sanitize_files(@file_paths);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_sleep

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables the sleep power mode.

=cut

sub disable_sleep {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	my $system32_path = $self->get_system32_path() || return;

	# Run powercfg.exe to disable sleep
	my $powercfg_command;
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -monitor-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -monitor-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -disk-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -disk-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -standby-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -standby-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -hibernate-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe -CHANGE -hibernate-timeout-dc 0";
	
	my ($powercfg_exit_status, $powercfg_output) = $self->execute($powercfg_command);
	if (!defined($powercfg_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to disable sleep");
		return;
	}
	elsif (grep(/(error|invalid|not found)/i, @$powercfg_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable sleep, powercfg.exe output:\n" . join("\n", @$powercfg_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "disabled sleep");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 query_event_log

 Parameters  : $event_log_name, $xpath_query, $event_count_limit (optional), $display_output (optional)
 Returns     : array
 Description : Queries the event log on the computer. The $event_log_name
               argument refers to the 'Channel' property of the events to be
               queried. Examples:
                  Security
                  Microsoft-Windows-GroupPolicy/Operational
               
               The $xpath_query argument is an XPath query filter. Examples:
               *
               *[System[Provider[@Name="Microsoft-Windows-Security-Auditing"] and Task=12544 and EventID=4624] and EventData[Data[@Name="LogonType"]="10"]]
               *[System[TimeCreated[timediff(@SystemTime) <= $milliseconds]]]
               *[System[Provider[@Name="Microsoft-Windows-Time-Service"]]]
               
               Constructs an array of hashes based on the XML output from
               wevtutil.exe.

=cut

sub query_event_log {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($event_log_name, $xpath_query, $event_count_limit, $display_output) = @_;
	if (!$event_log_name) {
		notify($ERRORS{'WARNING'}, 0, "event log name argument was not specified");
		return;
	}
	
	$xpath_query = '*' if !$xpath_query;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	# Fix problems with the query - replace all single quotes with double quotes
	# Escape all double quote characters
	$xpath_query =~ s/\\?("|')/\\"/g;
	
	# Remove newlines
	$xpath_query =~ s/\s*\n+\s*/ /g;
	
	# Remove spaces after opening brackets and before closing brackets
	$xpath_query =~ s/(\[)\s+/$1/g;
	$xpath_query =~ s/\s+(\])/$1/g;
	
	# Remove spaces from end
	$xpath_query =~ s/\s+$//g;
	
	# Write the output to a file on 
	my $command = "$system32_path/wevtutil.exe query-events $event_log_name /format:XML /element:Events /query:\"$xpath_query\"";
	if ($event_count_limit) {
		$command .= " /count:$event_count_limit";
	}
	
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to query event log on $computer_node_name: $command");
		return;
	}
	elsif (!grep(/<Events>/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute query event log on $computer_node_name, output does not contain expected '<Events>' text\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Convert the XML output to a hash
	my $xml_hash = xml_string_to_hash($output, ['Event', 'Data']);
	if (!$xml_hash) {
		notify($ERRORS{'WARNING'}, 0, "failed to query event log on $computer_node_name, XML output could not be converted to a hash:\n" . join("\n", @$output));
		return;
	}
	
	# If no events were returned 'Event' key will not be defined
	if (!defined($xml_hash->{Event})) {
		notify($ERRORS{'DEBUG'}, 0, "no events exist in '$event_log_name' event log on $computer_node_name, command:\n$command");
		return {};
	}
	
	$xml_hash = $self->query_event_log_helper($xml_hash);
	
	# Get the array of events
	my @events = @{$xml_hash->{Event}};
	my $event_count = scalar(@events);
	
	my $levels = {
		0 => 'Undefined',
		1 => 'Critical',
		2 => 'Error',
		3 => 'Warning',
		4 => 'Information',
		5 => 'Verbose',
	};
	
	for my $event (@events) {
		my $level = $event->{System}{Level};
		if (defined($level) && $levels->{$level}) {
			$event->{System}{LEVEL_NAME} = $levels->{$level};
		}
		else {
			$event->{System}{LEVEL_NAME} = '<unknown>';
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved $event_count $event_log_name event" . ($event_count == 1 ? '' : 's') . " from $computer_node_name, command:\n$command\n" . format_data(\@events)) if $display_output;
	return @events;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 query_event_log_helper

 Parameters  : $data
 Returns     : varies
 Description : Cleans up the data structure containing the event log
               information. If the data contains an array of hashes and each
               hash only has a 'Name' and 'content' key, the array is replaced
               with a hash whose keys are the 'Name' values and values are the
               'content' values.

=cut

sub query_event_log_helper {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $data = shift;
	if (!defined($data)) {
		return;
	}
	
	my $type = ref($data);
	if (!$type) {
		return $data;
	}
	elsif ($type eq 'HASH') {
		for my $key (keys %$data) {
			$data->{$key} = $self->query_event_log_helper($data->{$key});
		}
		return $data;
	}
	elsif ($type eq 'ARRAY') {
		my $test_element = @{$data}[0];
		my $test_element_type = ref($test_element);
		if ($test_element_type && $test_element_type eq 'HASH' && defined($test_element->{Name}) && defined($test_element->{content})) {
			my %hash;
			for my $element (@$data) {
				if (defined($element->{Name}) && defined($element->{content})) {
					$hash{$element->{Name}} = $element->{content};
				}
			}
			return \%hash;
		}
		
		my @array;
		for my $element (@$data) {
			push @array, $self->query_event_log_helper($element);
		}
		return \@array;
	}
	else {
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_time_service_events

 Parameters  : none
 Returns     : array
 Description : Retrieves event log entries generated by the Windows Time
               (w32time) service. Returns an array of hash references:
                  [
                    {
                      "EventData" => {
                        "Data" => {
                          "TimeSource" => "pool.ntp.org (ntp.m|0x0|0.0.0.0:123-><IP Address>:123)"
                        },
                        "Name" => "TMP_EVENT_TIME_SOURCE_REACHABLE"
                      },
                      "System" => {
                        "Channel" => "System",
                        "Computer" => "win2012r2",
                        "Correlation" => {},
                        "EventID" => 37,
                        "EventRecordID" => 3242,
                        "Execution" => {
                          "ProcessID" => 796,
                          "ThreadID" => 1204
                        },
                        "Keywords" => "0x8000000000000000",
                        "Level" => 4,
                        "Opcode" => 0,
                        "Provider" => {
                          "Guid" => "{06EDCFEB-0FD0-4E53-ACCA-A6F8BBF81BCB}",
                          "Name" => "Microsoft-Windows-Time-Service"
                        },
                        "Security" => {
                          "UserID" => "S-1-5-19"
                        },
                        "Task" => 0,
                        "TimeCreated" => {
                          "SystemTime" => "2017-07-28T12:08:12.195010600Z"
                        },
                        "Version" => 0
                      },
                      "xmlns" => "http://schemas.microsoft.com/win/2004/08/events/event"
                    },
                    {
                      ...
                    },
                  ]

=cut

sub get_time_service_events {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my @events = $self->query_event_log('System', '*[System[Provider[@Name="Microsoft-Windows-Time-Service"]]]', 100, 0);
	
	my $info_string;
	for my $event (@events) {
		my $level = $event->{System}{LEVEL_NAME};
		my $system_time = $event->{System}{TimeCreated}{SystemTime};
		my $event_name = $event->{EventData}{Name};
		my $event_data = $event->{EventData}{Data};
		$info_string .= "($level) $system_time - $event_name\n" . format_data($event_data) . "\n\n";
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved time service entries from event log on $computer_name:\n$info_string");
	return @events;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_logon_events

 Parameters  : $past_minutes (optional)
 Returns     : array
 Description : Queries the event log for logon events in either the Security log
               or Microsoft-Windows-TerminalServices-LocalSessionManager.
               Anonymous logon and service logons are ignored. An array is
               returned sorted by time from oldest to newest. Example:
               [  
                  {
                    "datetime" => "2014-03-18 19:15:25",
                    "description" => "An account was successfully logged on",
                    "epoch" => "1395184525",
                    "event_id" => 4624,
                    "event_record_id" => 2370,
                    "logon_type" => "Interactive",
                    "logon_type_id" => 2,
                    "pid" => 4624,
                    "provider" => "Microsoft-Windows-Security-Auditing",
                    "remote_ip" => "127.0.0.1",
                    "user" => "root"
                  },
                  {
                    "datetime" => "2014-03-19 17:06:37",
                    "description" => "An account was successfully logged on",
                    "epoch" => "1395263197",
                    "event_id" => 4624,
                    "event_record_id" => 2665,
                    "logon_type" => "Network",
                    "logon_type_id" => 3,
                    "pid" => 4624,
                    "provider" => "Microsoft-Windows-Security-Auditing",
                    "user" => "Administrator"
                  },
               ]  

=cut

sub get_logon_events {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($past_minutes) = @_;
	my $offset_minutes = $self->get_timezone_offset_minutes() || 0;
	
	my $logon_type_names = {
		0 => 'System',
		2 => 'Interactive',
		3 => 'Network',
		4 => 'Batch',
		5 => 'Service',
		6 => 'Proxy',
		7 => 'Unlock',
		8 => 'NetworkCleartext',
		9 => 'NewCredentials',
		10 => 'RemoteInteractive',
		11 => 'CachedInteractive',
		12 => 'CachedRemoteInteractive',
		13 => 'CachedUnlock',
	};
	
	my $security_event_log = 'Security';
	my $lsm_event_log = 'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational';
	
	my $event_ids = {
		'Microsoft-Windows-Security-Auditing' => {
			4624 => 'An account was successfully logged on',
		},
		'Microsoft-Windows-TerminalServices-LocalSessionManager' => {
			21 => 'Remote Desktop Services: Session logon succeeded',
			25 => 'Remote Desktop Services: Session reconnection succeeded',
			1101 => 'Remote Desktop Services: Session logon succeeded',
			1105 => 'Remote Desktop Services: Session reconnection succeeded',
		},
	};
	
	my $security_event_id_string = "EventID=" . join(' or EventID=', keys(%{$event_ids->{'Microsoft-Windows-Security-Auditing'}}));
	my $lsm_event_id_string = "EventID=" . join(' or EventID=', keys(%{$event_ids->{'Microsoft-Windows-TerminalServices-LocalSessionManager'}}));
	
	my $time_created_string = '';
	if ($past_minutes) {
		my $milliseconds = ($past_minutes * 60 * 1000);
		$time_created_string = "and TimeCreated[timediff(\@SystemTime) <= $milliseconds]";
	}
	
	my $security_query = <<EOF;
*[
	System[
		Provider[\@Name="Microsoft-Windows-Security-Auditing"]
		and Task=12544
		and ($security_event_id_string)
		$time_created_string
	]
	and
	EventData[
		Data[\@Name="TargetUserName"]!="ANONYMOUS LOGON"
		and Data[\@Name="TargetUserName"]!="SYSTEM"
		and Data[\@Name="IpAddress"]!="127.0.0.1"
		and Data[\@Name="LogonType"]!="5"
	]
]
EOF
	
	my $lsm_query = <<EOF;
*[
	System[
		Provider[\@Name="Microsoft-Windows-TerminalServices-LocalSessionManager"]
		and ($lsm_event_id_string)
		$time_created_string
	]
]
EOF
	
	my (@security_events, @lsm_events);
	@security_events = $self->query_event_log($security_event_log, $security_query);
	@lsm_events = $self->query_event_log($lsm_event_log, $lsm_query);
	
	my $logon_event_hash = {};
	for my $event (@security_events, @lsm_events) {
		my $system = $event->{System} || next;
		
		my $provider_name   = $system->{Provider}{Name};
		my $system_time     = $system->{TimeCreated}{SystemTime};
		my $event_record_id = $system->{EventRecordID};
		my $event_id        = $system->{EventID};
		my $process_pid     = $system->{Execution}{ProcessID};
		
		my $logon_event = {
			event_record_id => $event_record_id,
			event_id        => $event_id,
			provider        => $provider_name,
			pid             => $event_id,
		};
		$logon_event->{description} = $event_ids->{$provider_name}{$event_id} if $event_ids->{$provider_name}{$event_id};
		
		# Convert system time format to datetime: 2014-03-18T19:18:41.421250000Z
		my ($date, $time) = $system_time =~ /^([\d-]+)T([\d:]+)\./;
		next if (!$date || !$time);
		my $datetime = "$date $time";
		
		# The time returned is UTC and not adjusted for the computer's time zone
		my $epoch_seconds = convert_to_epoch_seconds($datetime);
		$epoch_seconds += ($offset_minutes * 60);
		$datetime = convert_to_datetime($epoch_seconds);
		$logon_event->{datetime} = $datetime;
		$logon_event->{epoch} = $epoch_seconds;
		
		if ($provider_name eq 'Microsoft-Windows-Security-Auditing') {
			my $event_data = $event->{EventData}{Data} || next;
			
			$logon_event->{user}          = $event_data->{TargetUserName};
			$logon_event->{remote_ip}     = $event_data->{IpAddress} if $event_data->{IpAddress};
			$logon_event->{remote_port}   = $event_data->{IpPort} if $event_data->{IpPort};
			$logon_event->{logon_type_id} = $event_data->{LogonType} if $event_data->{LogonType};
			
			my $logon_type_id = $event_data->{LogonType};
			if (defined($logon_type_id)) {
				$logon_event->{logon_type_id} = $logon_type_id;
				$logon_event->{logon_type} = $logon_type_names->{$logon_type_id} if $logon_type_names->{$logon_type_id};
			}
		}
		elsif ($provider_name eq 'Microsoft-Windows-TerminalServices-LocalSessionManager') {
			my $user_data = $event->{UserData}{EventXML} || next;;
			
			$logon_event->{user}       = $user_data->{User};
			$logon_event->{remote_ip}  = $user_data->{Address} if $user_data->{Address};
			$logon_event->{session_id} = $user_data->{SessionID} if $user_data->{SessionID};
		}
		
		if (!$logon_event->{user} || ref($logon_event->{user})) {
			next;
		}
		$logon_event->{user} =~ s/.*\\+//g;
		
		if ($logon_event->{remote_ip} && ($logon_event->{remote_ip} eq '0.0.0.0' || $logon_event->{remote_ip} =~ /-/)) {
			delete $logon_event->{remote_ip};
		}
		
		if ($logon_event->{remote_port} && $logon_event->{remote_port} =~ /-/) {
			delete $logon_event->{remote_port};
		}
		
		# Add to the hash - use key containing the provider name and record ID in case events have the same epoch time
		$logon_event_hash->{"$epoch_seconds-$provider_name-$event_record_id"} = $logon_event;
	}
	
	# Convert the hash to an array sorted by the epoch time keys
	my @logon_events = map { $logon_event_hash->{$_} } sort keys %$logon_event_hash;
	
	my $logon_event_count = scalar(@logon_events);
	notify($ERRORS{'DEBUG'}, 0, "retrieved $logon_event_count logon event" . ($logon_event_count == 1 ? '' : 's') . ":\n" . format_data(\@logon_events));
	return @logon_events;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
