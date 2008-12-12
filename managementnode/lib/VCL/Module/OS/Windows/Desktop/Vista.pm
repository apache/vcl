#!/usr/bin/perl -w

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

##############################################################################
# $Id: Vista.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::OS::Windows::Desktop::Vista.pm - VCL module to support Windows Vista operating system

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows Vista.

=cut

##############################################################################
package VCL::Module::OS::Windows::Desktop::Vista;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows::Desktop);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use VCL::Module::Provisioning::xCAT;
use File::Basename;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $CONFIGURATION_FILES

 Data type   : Scalar
 Description : Location of script/utilty/configuration files needed to
               configure the OS. This is normally the directory under
					the 'tools' directory specific to this OS.

=cut

our $CONFIGURATION_DIRECTORY = "$TOOLS/Sysprep_Vista";

=head2 $ROOT_PASSWORD

 Data type   : Scalar
 Description : Password for the node's root account.

=cut

our $ROOT_PASSWORD = $WINDOWS_ROOT_PASSWORD;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_prepare

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_prepare {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
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
	my $imagemeta_sysprep        = $self->data->get_imagemeta_sysprep();
	my $computer_id              = $self->data->get_computer_id();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $computer_type            = $self->data->get_computer_type();
	my $user_id                  = $self->data->get_user_id();
	my $user_unityid             = $self->data->get_user_login_id();
	my $managementnode_shortname = $self->data->get_management_node_short_name();
	my $computer_private_ip      = $self->data->get_computer_private_ip();
	
	notify($ERRORS{'OK'}, 0, "beginning Windows Vista image capture preparation tasks: $image_name on $computer_short_name");
	
	$self->disable_autoadminlogon();
	#$self->import_registry_file("$CONFIGURATION_DIRECTORY/Scripts/test.reg");
	#$self->disable_pagefile();
	#$self->firewall_disable_rdp();
	#$self->firewall_enable_rdp('152.1.0.0/16');
	exit;
	
	# Node variables
	my $local_configuration_directory = 'C:/VCL';
	my $local_scripts_directory = 'C:/VCL/Scripts';
	
	
	# Remove old configuration files if they exist
	notify($ERRORS{'OK'}, 0, "attempting to remove old configuration directory if it exists: $local_configuration_directory");
	my ($remove_old_status, $remove_old_output) = run_ssh_command($computer_node_name, $management_node_keys, "/usr/bin/rm.exe -rf $local_configuration_directory");
	if (defined($remove_old_status) && $remove_old_status == 0) {
		notify($ERRORS{'OK'}, 0, "removed existing configuration directory: $local_configuration_directory");
	}
	elsif (defined($remove_old_status)) {
		notify($ERRORS{'OK'}, 0, "unable to remove existing configuration directory: $local_configuration_directory, exit status: $remove_old_status, output:\n@{$remove_old_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to remove existing configuration directory: $local_configuration_directory");
		return 0;
	}


	# Copy configuration files
	notify($ERRORS{'OK'}, 0, "copying Sysprep and other configuration files to $computer_short_name");
	if (run_scp_command($CONFIGURATION_DIRECTORY, "$computer_node_name:$local_configuration_directory", $IDENTITY_wxp)) {
		notify($ERRORS{'OK'}, 0, "copied $CONFIGURATION_DIRECTORY directory to $computer_node_name:$local_configuration_directory");

		notify($ERRORS{'OK'}, 0, "attempting to set permissions on $computer_node_name:$local_configuration_directory");
		if (run_ssh_command($computer_node_name, $IDENTITY_wxp, "/usr/bin/chmod.exe -R 755 $local_configuration_directory")) {
			notify($ERRORS{'OK'}, 0, "chmoded -R 755 $computer_node_name:$local_configuration_directory");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not chmod -R 755 $computer_node_name:$local_configuration_directory");
		}
	} ## end if (run_scp_command($CONFIGURATION_DIRECTORY, "$computer_node_name:C:\/Sysprep"...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy $CONFIGURATION_DIRECTORY to $computer_node_name");
		return 0;
	}


	# Set root account password
	notify($ERRORS{'OK'}, 0, "changing root password on $computer_short_name");
	my ($root_password_exit_status, $root_password_output) = run_ssh_command($computer_node_name, $management_node_keys, "net user root '$ROOT_PASSWORD'");
	if ($root_password_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "root password changed to $ROOT_PASSWORD");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to change root password to $ROOT_PASSWORD, exit status: $root_password_exit_status, output:\n@{$root_password_output}");
		return 0;
	}

	# Log off all currently logged in users
	notify($ERRORS{'OK'}, 0, "logging off all currently logged in users");
	logoff_users($computer_node_name);
	
	# Wait to allow any files in use by users justed logged out to close
	notify($ERRORS{'OK'}, 0, "waiting for 5 seconds after any users were logged off to allow files to close");
	sleep 5;
	
	# Delete the user assigned to this reservation
	notify($ERRORS{'OK'}, 0, "attempting to delete user $user_unityid from $computer_node_name");
	delete_user($computer_node_name, $user_id);
	
	
	my @sshcmd;
	if ($IPCONFIGURATION eq "static") {
		#so we don't have conflicts we should set the public adapter back to dhcp
		#this change is immediate
		#figure out  which adapter it public
		my $myadapter;
		my %ip;
		my ($privateadapter, $publicadapter);
		undef @sshcmd;
		@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "ipconfig -all", "root");
		# build hash of needed info and set the correct private adapter.
		my $id = 1;
		foreach my $a (@{$sshcmd[1]}) {
			if ($a =~ /Ethernet adapter (.*):/) {
				$myadapter                 = $1;
				$ip{$myadapter}{"id"}      = $id;
				$ip{$myadapter}{"private"} = 0;
			}
			if ($a =~ /IP Address([\s.]*): $computer_private_ip/) {
				$ip{$myadapter}{"private"} = 1;
			}
			if ($a =~ /Physical Address([\s.]*): ([-0-9]*)/) {
				$ip{$myadapter}{"MACaddress"} = $2;
			}
			$id++;
		} ## end foreach my $a (@{$sshcmd[1]})

		foreach my $key (keys %ip) {
			if (defined($ip{$key}{private})) {
				if (!($ip{$key}{private})) {
					$publicadapter = "\"$key\"";
				}
			}
		}

		undef @sshcmd;
		my $netshcmd = "netsh interface ip set address name=\\\"$publicadapter\\\" source=dhcp";
		@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, $netshcmd, "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /Ok/) {
				notify($ERRORS{'OK'}, 0, "successfully set $publicadapter to dhcp");
			}
			else {
				notify($ERRORS{'OK'}, 0, "problem setting $publicadapter to dhcp on $computer_node_name @{ $sshcmd[1] }");
			}
		}
	} ## end if ($IPCONFIGURATION eq "static")

	# Defrag before removing pagefile
	# we do this to speed up the process
	# defraging without a page file takes a little longer
	#DEFRAG: notify($ERRORS{'OK'}, 0, "starting defrag on $computer_node_name");
	#my ($defrag_exit_status, $defrag_output) = run_ssh_command($computer_node_name, $management_node_keys, "defrag.exe C: -v");
	#if (defined($defrag_exit_status)) {
	#	notify($ERRORS{'OK'}, 0, "defrag exit status: $defrag_exit_status, defrag output:\n$defrag_output");
	#}
	#else {
	#	notify($ERRORS{'WARNING'}, 0, "defrag failed");
	#}
	
	

	my @list;
	my $l;
	#execute the vbs script to disable the pagefile and reboot
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "cscript.exe //Nologo $local_scripts_directory/auto_create_image.vbs");
	foreach $l (@{$sshcmd[1]}) {
		if ($l =~ /createimage reboot/) {
			notify($ERRORS{'OK'}, 0, "auto_create_image.vbs initiated, $computer_node_name rebooting, sleeping 50");
			sleep 50;
			next;
		}
		elsif ($l =~ /failed error/) {
			notify($ERRORS{'WARNING'}, 0, "auto_create_image.vbs failed, @{ $sshcmd[1] }");
			#legacy code for a bug in xcat, now fixed
			# force a reboot, or really a power cycle.
			#crap hate to do this.
			notify($ERRORS{'WARNING'}, 0, "forcing a power cycle");
			if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "cycle")) {
				notify($ERRORS{'WARNING'}, 0, "forced power cycle complete");
				next;
			}
		} ## end elsif ($l =~ /failed error/)  [ if ($l =~ /createimage reboot/)
	} ## end foreach $l (@{$sshcmd[1]})


	#Set up simple ping loop to determine if machine is actually rebooting
	my $online   = 1;
	my $pingloop = 0;
	notify($ERRORS{'OK'}, 0, "checking for pingable $computer_node_name");
	while ($online) {
		if (!(_pingnode($computer_node_name))) {
			notify($ERRORS{'OK'}, 0, "Success $computer_node_name is not pingable");
			$online = 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is still pingable - loop $pingloop");
			sleep 10;
			$pingloop++;
		}
		if ($pingloop > 10) {
			notify($ERRORS{'CRITICAL'}, 0, "$computer_node_name should have rebooted by now, trying to force it");
			if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "boot")) {
				notify($ERRORS{'WARNING'}, 0, "forced power cycle complete");
				sleep 25;
				next;
			}
		}
	} ## end while ($online)


	# Wait until the reboot process has started to shutdown services
	notify($ERRORS{'OK'}, 0, "$computer_node_name rebooting, waiting");
	my $socketflag = 0;


	REBOOTED:
	my $rebooted          = 1;
	my $reboot_wait_count = 0;
	while ($rebooted) {
		if ($reboot_wait_count > 55) {
			notify($ERRORS{'CRITICAL'}, 0, "waited $reboot_wait_count on reboot after auto_create_image on $computer_node_name");
			return 0;
		}
		notify($ERRORS{'OK'}, 0, "$computer_node_name not completed reboot sleeping for 25");
		sleep 25;
		if (_pingnode($computer_node_name)) {
			#it pingable check if sshd is open
			notify($ERRORS{'OK'}, 0, "$computer_node_name is pingable, checking sshd port");
			my $sshd = _sshd_status($computer_node_name, $image_name);
			if ($sshd =~ /on/) {
				$rebooted = 0;
				notify($ERRORS{'OK'}, 0, "$computer_node_name sshd is open");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$computer_node_name sshd NOT open yet,sleep 5");
				sleep 5;
			}
		} ## end if (_pingnode($computer_node_name))
		$reboot_wait_count++;
	}    # Close while rebooted


	# Check for recent bug
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $IDENTITY_wxp, "uname -s");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /^Warning:/) {
			#if (makesshgkh($computer_node_name)) {
			#}
		}
		if ($l =~ /^Read from socket failed:/) {
			if ($socketflag) {
				notify($ERRORS{'CRITICAL'}, 0, "could not login $computer_node_name via ssh socket failure");
				return 0;
			}
			notify($ERRORS{'CRITICAL'}, 0, "discovered ssh read from socket failure on $computer_node_name, attempting to repair");
			#power cycle node
			if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "cycle")) {
				notify($ERRORS{'CRITICAL'}, 0, "$computer_node_name power cycled going to reboot check routine");
				sleep 40;
				$socketflag = 1;
				goto REBOOTED;
			}
		} ## end if ($l =~ /^Read from socket failed:/)
	} ## end foreach my $l (@{$sshcmd[1]})

	notify($ERRORS{'OK'}, 0, "proceeding to CIMONITOR");
	#monitor for signal to set node to image and then reboot
	my $sshd_status;
	my ($loop, $rebootsignal, $reboot_copied) = 0;
	CIMONITOR:
	#check ssh port in case we finish above steps before first reboot completes
	# while ssh port is off sleep few seconds then loop
	# this section is useless for linux images
	my $ping_result = _pingnode($computer_node_name);
	#check our loop
	if ($loop > 200) {
		notify($ERRORS{'CRITICAL'}, 0, "CIMONITOR $computer_node_name taking longer to reboot than expected, check it");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "CIMONITOR ping check");
	if (!$ping_result) {
		sleep 5;
		notify($ERRORS{'OK'}, 0, "CIMONITOR ping is off waiting for $computer_node_name to complete reboot");
		$loop++;
		goto CIMONITOR;
	}
	# is port 22 open yet
	if (!nmap_port($computer_node_name, 22)) {
		notify($ERRORS{'OK'}, 0, "port 22 not open on $computer_node_name yet, looping");
		$loop++;
		sleep 3;
		goto CIMONITOR;
	}

	## Set sshd service startup to manual
	#if (_set_sshd_startmode($computer_node_name, "manual")) {
	#	notify($ERRORS{'OK'}, 0, "successfully set manual mode for sshd start");
	#}
	#else {
	#	notify($ERRORS{'CRITICAL'}, 0, "failed to set manual mode for sshd on $computer_node_name");
	#	return 0;
	#}


	#actually remove the pagefile.sys sometimes movefile.exe does not work
	if (run_ssh_command($computer_node_name, $IDENTITY_wxp, "/usr/bin/rm -fv C:\/pagefile.sys")) {
		notify($ERRORS{'OK'}, 0, "removed pagefile.sys ");
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_prepare

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_start

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_start {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
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
	my $imagemeta_sysprep        = $self->data->get_imagemeta_sysprep();
	my $computer_id              = $self->data->get_computer_id();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $computer_type            = $self->data->get_computer_type();
	my $user_id                  = $self->data->get_user_id();
	my $user_unityid             = $self->data->get_user_login_id();
	my $managementnode_shortname = $self->data->get_management_node_short_name();
	my $computer_private_ip      = $self->data->get_computer_private_ip();

	notify($ERRORS{'OK'}, 0, "initiating Windows image capture: $image_name on $computer_short_name");

	my @sshcmd;

	if ($imagemeta_sysprep) {
		notify($ERRORS{'OK'}, 0, "starting sysprep on $computer_node_name");
		if (open(SSH, "/usr/bin/ssh -q -i $IDENTITY_wxp $computer_node_name \"C:\/Sysprep\/sysprep.cmd\" 2>&1 |")) {
			my $notstop = 1;
			my $loop    = 0;
			while ($notstop) {
				my $l = <SSH>;
				$loop++;
				#notify($ERRORS{'DEBUG'}, 0, "sysprep.cmd loop count: $loop");
				#notify($ERRORS{'DEBUG'}, 0, "$l");
				if ($l =~ /sysprep/) {
					notify($ERRORS{'OK'}, 0, "sysprep.exe has started, $l");

					notify($ERRORS{'DEBUG'}, 0, "attempting to kill management node sysprep.cmd SSH process in 60 seconds");
					sleep 60;

					notify($ERRORS{'DEBUG'}, 0, "attempting to kill management node sysprep.cmd SSH process");
					if (_killsysprep($computer_node_name)) {
						notify($ERRORS{'OK'}, 0, "killed sshd process for sysprep command");
					}

					notify($ERRORS{'DEBUG'}, 0, "closing SSH filehandle");
					close(SSH);
					notify($ERRORS{'DEBUG'}, 0, "SSH filehandle closed");

					$notstop = 0;
				} ## end if ($l =~ /sysprep/)
				elsif ($l =~ /sysprep.cmd: Permission denied/) {
					notify($ERRORS{'CRITICAL'}, 0, "chmod 755 failed to correctly set execute on sysprep.cmd output $l");
					close(SSH);
					return 0;
				}

				#avoid infinite loop
				if ($loop > 1000) {
					notify($ERRORS{'DEBUG'}, 0, "sysprep executed in loop control condition, exceeded limit");

					notify($ERRORS{'DEBUG'}, 0, "attempting to kill management node sysprep.cmd SSH process in 60 seconds");
					sleep 60;

					notify($ERRORS{'DEBUG'}, 0, "attempting to kill management node sysprep.cmd SSH process");
					if (_killsysprep($computer_node_name)) {
						notify($ERRORS{'OK'}, 0, "killed sshd process for sysprep command");
					}

					notify($ERRORS{'DEBUG'}, 0, "closing SSH filehandle");
					close(SSH);
					notify($ERRORS{'DEBUG'}, 0, "SSH filehandle closed");

					$notstop = 0;
				} ## end if ($loop > 1000)

			} ## end while ($notstop)
		}    # Close open handle for SSH sysprep.cmd command
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to start sysprep on $computer_node_name $!");
			return 0;
		}    # Close sysprep.cmd could not be launched
	}    # Close if Sysprep

	else {
		#non sysprep option
		#
		#just reboot machine -- future expansion of additional methods newsid, custom scripts, etc.
		notify($ERRORS{'OK'}, 0, "starting custom script VCLprep1.vbs on $computer_node_name");
		if (run_scp_command("$TOOLS/VCLprep1.vbs", "$computer_node_name:VCLprep1.vbs", $IDENTITY_wxp)) {
			undef @sshcmd;
			@sshcmd = run_ssh_command($computer_node_name, $IDENTITY_wxp, "cscript //Nologo VCLprep1.vbs", "root");
			foreach my $s (@{$sshcmd[1]}) {
				chomp($s);
				if ($s =~ /copied VCLprepare/) {
					notify($ERRORS{'OK'}, 0, "$s");
				}
				if ($s =~ /rebooting/) {
					notify($ERRORS{'OK'}, 0, "SUCCESS started image procedure on $computer_node_name");
					last;
				}
			} ## end foreach my $s (@{$sshcmd[1]})
		}    # Close SCP VCLPrep1.vbs
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to copy $TOOLS/VCLprep1.vbs to $computer_node_name ");
			return 0;
		}
	}    # Close if not Sysprep

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_start

#/////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub user_exists {
	my ($node, $user)  = @_;
	notify($ERRORS{'WARNING'}, 0, "node is not defined") if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "user is not defined") if (!(defined($user)));

	my ($net_user_exit_status, $net_user_output) = run_ssh_command($node, $IDENTITY_wxp, "net user $user");
	if ($net_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "user $user exists on $node");
		return 1;
	}
	elsif ($net_user_exit_status == 2) {
		notify($ERRORS{'OK'}, 0, "user $user does NOT exist on $node");
		return 0;
	}
	elsif ($net_user_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if user $user exists on $node, exit status: $net_user_exit_status, output:\n@{$net_user_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if user $user exists on $node");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 logoff_users

 Parameters  :
 Returns     :
 Description :

=cut

sub logoff_users {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	
	my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, "qwinsta.exe");
	if ($exit_status > 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe on $computer_node_name, exit status: $exit_status, output:\n@{$output}");
		return;
	}
	elsif (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe SSH command on $computer_node_name");
		return;
	}
	
	my @active_user_lines = grep(/Active/, @{$output});
	
	notify($ERRORS{'OK'}, 0, "users are currently logged in on $computer_node_name: " . @active_user_lines);
	
	foreach my $active_user_line (@active_user_lines) {
		$active_user_line =~ /\s+(\S+)\s+(.*\w)\s*(\d+)\s+Active.*/;
		my $session_name = $1;
		my $username = $2;
		my $session_id = $3;
		
		notify($ERRORS{'DEBUG'}, 0, "user logged in: $username, session name: $session_name, session id: $session_id");
		
		my ($logoff_exit_status, $logoff_output) = run_ssh_command($computer_node_name, $management_node_keys, "logoff.exe /v $session_id");
		if ($logoff_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "logged off user: $username, exit status: $logoff_exit_status, output:\n@{$logoff_output}");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to log off user: $username, exit status: $logoff_exit_status, output:\n@{$logoff_output}");
		}
		
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  : $node, $user, $type, $osname
 Returns     : 1 success 0 failure
 Description : removes user account and profile directory from specificed node

=cut

sub delete_user {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!(defined($username))) {
		$username = $self->data->get_user_logon_id();
	}
	
	notify($ERRORS{'OK'}, 0, "attempting to delete user $username from $computer_node_name");
	
	# Attempt to delete the user account
	my $delete_user_command = "net user $username /DELETE";
	my ($delete_user_exit_status, $delete_user_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_user_command);
	if (defined($delete_user_exit_status) && $delete_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted user $username from $computer_node_name");
	}
	elsif (defined($delete_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete user $username from $computer_node_name, exit status: $delete_user_exit_status, output:\n@{$delete_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command delete user $username from $computer_node_name");
		return;
	}

	# Delete the user's home directory
	my $delete_profile_command = "/bin/rm -rf /cygdrive/c/Users/$username";
	my ($delete_profile_exit_status, $delete_profile_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_profile_command);
	if (defined($delete_profile_exit_status) && $delete_profile_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted profile for user $username from $computer_node_name");
	}
	elsif (defined($delete_profile_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete profile for user $username from $computer_node_name, exit status: $delete_profile_exit_status, output:\n@{$delete_profile_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command delete profile for user $username from $computer_node_name");
		return;
	}
	
	return 1;
} ## end sub del_user

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_pagefile

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_pagefile {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $disable_pagefile_key = "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Memory Management";
	my $disable_pagefile_command = "reg.exe add \"$disable_pagefile_key\" /v \"PagingFiles\" /t REG_SZ /d \"\" /f";
	my ($disable_pagefile_exit_status, $disable_pagefile_output) = run_ssh_command($computer_node_name, $management_node_keys, $disable_pagefile_command);
	if ($disable_pagefile_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry key set to disable pagefile");
	}
	elsif ($disable_pagefile_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to disable pagefile, exit status: $disable_pagefile_exit_status, output:\n@{$disable_pagefile_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to set registry key to disable pagefile");
		return;
	}

	# Attempt to reboot the computer in order to delete the pagefile
	if ($self->reboot()) {
		notify($ERRORS{'OK'}, 0, "computer was rebooted after disabling pagefile in the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reboot computer after disabling pagefile");
		return;
	}
	
	# Attempt to delete the pagefile
	my $delete_pagefile_command = "attrib.exe -S -H -R C:/pagefile.sys";
	$delete_pagefile_command .= " && /usr/bin/rm.exe -rfv C:/pagefile.sys";
	my ($delete_pagefile_exit_status, $delete_pagefile_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_pagefile_command);
	if ($delete_pagefile_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "pagefile.sys was deleted");
		return 1;
	}
	elsif ($delete_pagefile_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete pagefile.sys, exit status: $delete_pagefile_exit_status, output:\n@{$delete_pagefile_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete pagefile.sys");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 import_registry_file

 Parameters  :
 Returns     :
 Description :

=cut

sub import_registry_file {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_file_path = shift;
	if (!defined($registry_file_path) || !$registry_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	
	my $registry_file_contents = `cat $registry_file_path`;
	notify($ERRORS{'DEBUG'}, 0, "registry file contents:\n$registry_file_contents");
	$registry_file_contents =~ s/([\"])/\\$1/gs;
	
	my $import_registry_command = "/usr/bin/echo.exe -E \"$registry_file_contents\" > tmp.reg";
	$import_registry_command .= " && reg.exe IMPORT tmp.reg";
	my ($import_registry_exit_status, $import_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $import_registry_command);
	if ($import_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry file contents imported");
	}
	elsif ($import_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry file contents, exit status: $import_registry_exit_status, output:\n@{$import_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry file contents");
		return;
	}
	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 import_registry_string

 Parameters  :
 Returns     :
 Description :

=cut

sub import_registry_string {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $registry_string = shift;
	if (!defined($registry_string) || !$registry_string) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "registry string:\n$registry_string");
	$registry_string =~ s/([\"])/\\$1/gs;
	
	my $import_registry_command = "/usr/bin/echo.exe -E \"$registry_string\" > tmp.reg";
	$import_registry_command .= " && reg.exe IMPORT tmp.reg";
	my ($import_registry_exit_status, $import_registry_output) = run_ssh_command($computer_node_name, $management_node_keys, $import_registry_command);
	if ($import_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "registry string contents imported");
	}
	elsif ($import_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry string contents, exit status: $import_registry_exit_status, output:\n@{$import_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry string contents");
		return;
	}
	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_autoadminlogon {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file enables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="1"
"DefaultUserName"="root"
"DefaultPassword"= "$ROOT_PASSWORD"
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'WARNING'}, 0, "successfully enabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable autoadminlogon");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 disable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_autoadminlogon {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();

	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

; This file disables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="0"
"DefaultUserName"=""
"DefaultPassword"= ""
EOF
	
	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'WARNING'}, 0, "successfully disabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable autoadminlogon");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 reboot

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub reboot {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	my $reboot_start_time = time();
	notify($ERRORS{'DEBUG'}, 0, "reboot will be attempted on $computer_node_name");
	
	# Make sure sshd service is set to auto
	notify($ERRORS{'DEBUG'}, 0, "attempting to make sure sshd service startup is set to auto");
	if (_set_sshd_startmode($computer_node_name, "auto")) {
		notify($ERRORS{'OK'}, 0, "successfully set sshd service startup mode to auto on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set sshd service startup mode to auto on $computer_node_name");
	}
	
	
	# Initiate the shutdown.exe command to reboot the computer
	my $shutdown_command = "C:/Windows/system32/shutdown.exe -r -t 0 -f";
	my ($shutdown_exit_status, $shutdown_output) = run_ssh_command($computer_node_name, $management_node_keys, $shutdown_command);
	if (defined($shutdown_exit_status)  && $shutdown_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully executed reboot command on $computer_node_name");
	}
	elsif (defined($shutdown_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute reboot command on $computer_node_name, exit status: $shutdown_exit_status, output:\n@{$shutdown_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to reboot $computer_node_name");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "sleeping for 30 seconds while $computer_node_name begins reboot");
	sleep 30;
	
	# Wait maximum of 4 minutes for the computer to go offline then come back up
	if (!$self->wait_for_ping(4)) {
		# Check if the computer was ever offline, it should have been or else reboot never happened
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to ping, attempting hard power reset");
		
		# Just explicitly call xCAT's _rpower for now
		# TODO: implement public reset() subroutines in all of the provisioning modules
		# TODO: allow provisioning and OS modules access to each other's subroutines
		if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "cycle")) {
			notify($ERRORS{'OK'}, 0, "initiated hard power reset on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate hard power reset on $computer_node_name");
			return 0;
		}
		
		# Wait for computer to respond to ping after initiating hard reset
		# Wait longer than the first attempt
		if (!$self->wait_for_ping(6)) {
			# Check if the computer was ever offline, it should have been or else reboot never happened
			notify($ERRORS{'WARNING'}, 0, "reboot failed, $computer_node_name never responded to ping even after hard power reset");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "sleeping for 15 seconds while $computer_node_name initializes");
	sleep 15;
	
	# Ping successful, try ssh
	notify($ERRORS{'OK'}, 0, "waiting for ssh to respond on $computer_node_name");
	if ($self->wait_for_ssh(3)) {
		my $reboot_end_time = time();
		my $reboot_duration = ($reboot_end_time - $reboot_start_time);
		notify($ERRORS{'OK'}, 0, "reboot succeeded on $computer_node_name, took $reboot_duration seconds");\
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "reboot failed, ssh never became available on $computer_node_name");
		return 0;
	}

}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ping

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is pingable, 0 otherwise
 Description : Attempts to ping the computer specified in the DataStructure
               for the current reservation. It will wait up to a maximum number
					of minutes. This can be specified by passing the subroutine an
					integer value or the default value of 5 minutes will be used.

=cut

sub wait_for_ping {
	my $self = shift;
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of minutes to wait from the command line
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}
	
	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 30;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 2) + 1;
	
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ping, maximum of $total_wait_minutes minutes");
	
	# Loop until computer is online
	my $computer_was_offline = 0;
	my $computer_pingable = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempts: checking if computer is pingable: $computer_node_name");
		$computer_pingable = _pingnode($computer_node_name);
		
		if ($computer_pingable && $computer_was_offline) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is pingable, reboot is nearly complete");
			last;
		}
		elsif ($computer_pingable && !$computer_was_offline) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is still pingable, reboot has not begun");
		}
		else {
			$computer_was_offline = 1;
			notify($ERRORS{'OK'}, 0, "$computer_node_name is not pingable, reboot is not complete");
		}
		
		notify($ERRORS{'OK'}, 0, "sleeping for $attempt_delay seconds before next ping attempt");
		sleep $attempt_delay;
	}
	
	# Check if the computer ever went offline and if it is now pingable
	if ($computer_pingable && $computer_was_offline) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name was offline and is now pingable");
		return 1;
	}
	elsif ($computer_pingable && !$computer_was_offline) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name was never offline and is still pingable");
		return 0;
	}
	else {
		my $total_wait = ($attempts * $attempt_delay);
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not pingable after waiting for $total_wait seconds");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_ssh

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if ssh succeeded to computer, 0 otherwise
 Description : Attempts to communicate to the computer specified in the
               DataStructure for the current reservation via SSH. It will wait
					up to a maximum number of minutes. This can be specified by
					passing the subroutine an integer value or the default value
					of 5 minutes will be used.

=cut

sub wait_for_ssh {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Attempt to get the total number of minutes to wait from the arguments
	# If not specified, use default value
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 5;
	}
	
	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 15;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 4) + 1;
	
	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to respond to ssh, maximum of $total_wait_minutes minutes");
	
	# Loop until ssh is available
	my $ssh_result = 0;
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempts: checking ssh on computer: $computer_node_name");
		
		# Run a test SSH command
		my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, "echo testing ssh on $computer_node_name");

		# The exit status will be 0 if the command succeeded
		if (defined($exit_status) && $exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "test ssh command succeeded on $computer_node_name");
			return 1;
		}
		
		notify($ERRORS{'OK'}, 0, "sleeping for $attempt_delay seconds before next ssh attempt");
		sleep $attempt_delay;
	}
	
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is not available via ssh");
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping_private {
	my $self = shift;
	
	my %firewall_parameters = (
		name => 'VCL: allow ping from private network',
		dir => 'in',
		action => 'allow',
		description => 'Allows incoming ping (ICMP type 8) messages from 10.x.x.x addresses',
		enable => 'yes',
		localip => '10.0.0.0/8',
		remoteip => '10.0.0.0/8',
		protocol => 'icmpv4:8,any',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming ping on private network");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming ping on private network");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh_private {
	my $self = shift;
	
	my %firewall_parameters = (
		name => 'VCL: allow ssh port 22 from private network',
		dir => 'in',
		action => 'allow',
		description => 'Allows incoming TCP port 22 traffic from 10.x.x.x addresses',
		enable => 'yes',
		localip => '10.0.0.0/8',
		remoteip => '10.0.0.0/8',
		localport => '22',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming ssh via TCP port 22 on private network");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming ssh via TCP port 22 on private network");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp {
	my $self = shift;
	
	# Check if the remote IP was passed correctly as an argument
	my $remote_ip = shift;
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'any';
	}
	
	my %firewall_parameters = (
		name => "VCL: allow RDP port 3389 from $remote_ip",
		dir => 'in',
		action => 'allow',
		description => "Allows incoming TCP port 3389 traffic from $remote_ip",
		enable => 'yes',
		remoteip => $remote_ip,
		localport => '3389',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_configure(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully opened firewall for incoming RDP via TCP port 3389 from $remote_ip");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall for incoming RDP via TCP port 3389 from $remote_ip");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_rdp {
	my $self = shift;
	
	#"\netsh.exe advfirewall firewall delete rule name=RDP protocol=TCP localport=3389"

	my %firewall_parameters = (
		name => 'all',
		localport => '3389',
		protocol => 'TCP',
	);
	
	# Call the configure firewall subroutine, pass it the necessary parameters
	if ($self->firewall_close(\%firewall_parameters)) {
		notify($ERRORS{'OK'}, 0, "successfully closed firewall for incoming RDP via TCP port 3389");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to close firewall for incoming RDP via TCP port 3389");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_configure

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_configure {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Check the arguments
	my $firewall_parameters = shift;
	if (!defined($firewall_parameters) || !$firewall_parameters) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, parameters hash reference was not passed");
		return;
	}
	if (!defined($firewall_parameters->{name}) || !$firewall_parameters->{name}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'name' hash key was not passed");
		return;
	}
	if (!defined($firewall_parameters->{dir}) || !$firewall_parameters->{dir}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'dir' hash key was not passed");
		return;
	}
	if (!defined($firewall_parameters->{action}) || !$firewall_parameters->{action}) {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name, 'action' hash key was not passed");
		return;
	}
	
	# Add quotes around anything with a space in the parameters hash which isn't already enclosed in quotes
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$firewall_parameters->{$rule_property} =~ s/^(.*\s.*)$/\"$1\"/g;
			notify($ERRORS{'DEBUG'}, 0, "enclosing property in quotes: $firewall_parameters->{$rule_property}");
	}
	
	# Attempt to run the command to set existing firewall rule
	
	# Usage: set rule
	#		group=<string> | name=<string>
	#		[dir=in|out]
	#		[profile=public|private|domain|any[,...]]
	#		[program=<program path>]
	#		[service=service short name|any]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]
	#		new
	#		[name=<string>]
	#		[dir=in|out]
	#		[program=<program path>
	#		[service=<service short name>|any]
	#		[action=allow|block|bypass]
	#		[description=<string>]
	#		[enable=yes|no]
	#		[profile=public|private|domain|any[,...]]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]
	#		[interfacetype=wireless|lan|ras|any]
	#		[rmtcomputergrp=<SDDL string>]
	#		[rmtusrgrp=<SDDL string>]
	#		[edge=yes|no]
	#		[security=authenticate|authenc|notrequired]
	
	# Assemble the command based on the keys populated in the hash
	my $set_rule_command = "netsh.exe advfirewall firewall set rule";
	$set_rule_command .= " name=$firewall_parameters->{name}";
	$set_rule_command .= " new";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		next if $rule_property eq 'name';
		$set_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Attempt to set properties of existing rule
	notify($ERRORS{'DEBUG'}, 0, "attempting to set matching firewall rules on $computer_node_name, command:\n$set_rule_command");
	my ($set_rule_exit_status, $set_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $set_rule_command);
	if (defined($set_rule_exit_status)  && ($set_rule_exit_status == 0)) {
		notify($ERRORS{'OK'}, 0, "successfully set matching firewall rules");
		return 1;
	}
	elsif (defined($set_rule_exit_status)  && ($set_rule_exit_status == 1)) {
		notify($ERRORS{'OK'}, 0, "unable to set matching firewall rules, rule does not exist");
	}
	elsif (defined($set_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set matching firewall rules on $computer_node_name, exit status: $set_rule_exit_status, output:\n@{$set_rule_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set matching firewall rules on $computer_node_name");
	}
	
	
	# Attempt to run the command to add the firewall rule
	
	# Usage: add rule name=<string>
	#      dir=in|out
	#      action=allow|block|bypass
	#      [program=<program path>]
	#      [service=<service short name>|any]
	#      [description=<string>]
	#      [enable=yes|no (default=yes)]
	#      [profile=public|private|domain|any[,...]]
	#      [localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#      [remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#         <IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#      [localport=0-65535|RPC|RPC-EPMap|any[,...] (default=any)]
	#      [remoteport=0-65535|any[,...] (default=any)]
	#      [protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#         tcp|udp|any (default=any)]
	#      [interfacetype=wireless|lan|ras|any]
	#      [rmtcomputergrp=<SDDL string>]
	#      [rmtusrgrp=<SDDL string>]
	#      [edge=yes|no (default=no)]
	#      [security=authenticate|authenc|notrequired (default=notrequired)]
	
	# Assemble the command based on the keys populated in the hash
	my $add_rule_command = "netsh.exe advfirewall firewall add rule";
	$add_rule_command .= " name=$firewall_parameters->{name}";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		next if $rule_property eq 'name';
		$add_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Add the firewall rule
	my ($add_rule_exit_status, $add_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $add_rule_command);
	if (defined($add_rule_exit_status)  && $add_rule_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully added firewall rule");
	}
	elsif (defined($add_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule on $computer_node_name, exit status: $add_rule_exit_status, output:\n@{$add_rule_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add firewall rule on $computer_node_name");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_close

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_close {
	my $self = shift;
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $computer_node_name       = $self->data->get_computer_node_name();
	
	# Make sure firewall parameters hash was passed
	my $firewall_parameters = shift;
	if (!defined($firewall_parameters) || !$firewall_parameters) {
		notify($ERRORS{'WARNING'}, 0, "failed to close firewall on $computer_node_name, parameters hash reference was not passed");
		return;
	}
	
	# Add quotes around anything with a space in the parameters hash which isn't already enclosed in quotes
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$firewall_parameters->{$rule_property} =~ s/^(.*\s.*)$/\"$1\"/g;
		notify($ERRORS{'DEBUG'}, 0, "enclosing '$rule_property' property in quotes: $firewall_parameters->{$rule_property}");
	}
	
	# Usage: delete rule name=<string>
	#		[dir=in|out]
	#		[profile=public|private|domain|any[,...]]
	#		[program=<program path>]
	#		[service=<service short name>|any]
	#		[localip=any|<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[remoteip=any|localsubnet|dns|dhcp|wins|defaultgateway|
	#			<IPv4 address>|<IPv6 address>|<subnet>|<range>|<list>]
	#		[localport=0-65535|RPC|RPC-EPMap|any[,...]]
	#		[remoteport=0-65535|any[,...]]
	#		[protocol=0-255|icmpv4|icmpv6|icmpv4:type,code|icmpv6:type,code|
	#			tcp|udp|any]

	# Assemble the command based on the keys populated in the hash
	my $delete_rule_command = "netsh.exe advfirewall firewall delete rule";
	foreach my $rule_property (sort keys(%{$firewall_parameters})) {
		$delete_rule_command .= " $rule_property=$firewall_parameters->{$rule_property}";
	}
	
	# Attempt to delete existing rules
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete matching firewall rules on $computer_node_name, command:\n$delete_rule_command");
	my ($delete_rule_exit_status, $delete_rule_output) = run_ssh_command($computer_node_name, $management_node_keys, $delete_rule_command);
	if (defined($delete_rule_exit_status)  && ($delete_rule_exit_status == 0)) {
		notify($ERRORS{'OK'}, 0, "successfully deleted matching firewall rules");
		return 1;
	}
	elsif (defined($delete_rule_exit_status)  && ($delete_rule_exit_status == 1)) {
		notify($ERRORS{'OK'}, 0, "unable to delete matching firewall rules, rule does not exist");
		return 1;
	}
	elsif (defined($delete_rule_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete matching firewall rules on $computer_node_name, exit status: $delete_rule_exit_status, output:\n@{$delete_rule_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to delete matching firewall rules on $computer_node_name");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 BUGS and LIMITATIONS

 There are no known bugs in this module.
 Please report problems to the VCL team (vcl_help@ncsu.edu).

=head1 AUTHOR

 Aaron Peeler, aaron_peeler@ncsu.edu
 Andy Kurth, andy_kurth@ncsu.edu

=head1 SEE ALSO

L<http://vcl.ncsu.edu>

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2004-2008 by NC State University. All Rights Reserved.

 Virtual Computing Laboratory
 North Carolina State University
 Raleigh, NC, USA 27695

 For use license and copyright information see LICENSE and COPYRIGHT files
 included in the source files.

=cut
