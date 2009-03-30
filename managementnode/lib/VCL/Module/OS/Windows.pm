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
# $Id: Windows.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::OS::Windows.pm - VCL module to support Windows operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows operating systems.

=cut

##############################################################################
package VCL::Module::OS::Windows;

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

use VCL::utils;
use VCL::Module::Utils::Logging;
use VCL::Module::Utils::SCP;
use VCL::Module::Utils::SSH;
use File::Basename;
use VCL::Module::Provisioning::xCAT;

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

	notify($ERRORS{'OK'}, 0, "beginning Windows-specific image capture preparation tasks: $image_name on $computer_short_name");

	my @sshcmd;

	# Change password of root and sshd service back to default
	# Needed only for sshd service on windows OS's
	my $p = $WINDOWS_ROOT_PASSWORD;
	if (changewindowspasswd($computer_short_name, "root", $p)) {
		notify($ERRORS{'OK'}, 0, "changed Windows password on $computer_short_name, root, $p");
	}
	else {
		notify($ERRORS{'OK'}, 0, "failed to change windows password $computer_short_name,root,$p");
	}


	# Check for user account and clean out if listed
	if (_is_user_added($computer_node_name, $user_unityid, $computer_type, $image_os_name,$image_os_type)) {
		# Make sure user is logged off
		my @QA = run_ssh_command($computer_node_name, $IDENTITY_wxp, "cmd /c qwinsta.exe", "root");
		foreach my $r (@{$QA[1]}) {
			if ($r =~ /([>]?)([-a-zA-Z0-9]*)\s+([a-zA-Z0-9]*)\s+ ([0-9]*)\s+([a-zA-Z]*)/) {
				my $state   = $5;
				my $session = $2;
				my $user    = $3;
				if ($5 =~ /Active/) {
					notify($ERRORS{'OK'}, 0, "detected $user on $session still logged on $computer_node_name $r, sleeping 7 before logging off");
					sleep 7;
					my @LF = run_ssh_command($computer_node_name, $IDENTITY_wxp, "cmd /c logoff.exe $session");
					foreach my $l (@{$LF[1]}) {
						notify($ERRORS{'OK'}, 0, "output from attempt to logoff $user on $session");
					}

				}
			} ## end if ($r =~ /([>]?)([-a-zA-Z0-9]*)\s+([a-zA-Z0-9]*)\s+ ([0-9]*)\s+([a-zA-Z]*)/)
		} ## end foreach my $r (@{$QA[1]})
		    #delete user
		if (del_user($computer_node_name, $user_unityid, $computer_type, $image_os_name)) {
			notify($ERRORS{'OK'}, 0, "$user_unityid account deleted from $computer_node_name");
		}
	} ## end if (_is_user_added($computer_node_name, $user_unityid...

	# Determine if machine has static private IP address
	# If so we need to change back to DHCP
	if ($image_name =~ /^win2003/) {
		notify($ERRORS{'OK'}, 0, "Windows Server 2003 image detected, private adapter will be changed from DHCP to static on $computer_short_name");

		my %ip;
		my $myadapter;
		undef @sshcmd;
		@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "ipconfig -all", "root");
		# build hash of needed info and set the correct private adapter.
		foreach my $a (@{$sshcmd[1]}) {
			if ($a =~ /Ethernet adapter (.*):/) {
				#print "$1\n";
				$myadapter = $1;
			}
			if ($a =~ /IP Address([\s.]*): $computer_private_ip/) {
				$ip{$myadapter}{"private"} = 1;
				notify($ERRORS{'OK'}, 0, "privateIP found $computer_private_ip");
			}
			if ($a =~ /DHCP Enabled([\s.]*): (No|Yes)/) {
				$ip{$myadapter}{"DHCPenabled"} = $2;
				notify($ERRORS{'OK'}, 0, "DHCP enabled $2");
			}
		} ## end foreach my $a (@{$sshcmd[1]})
		my $privateadapter;
		foreach my $key (keys %ip) {
			if (defined($ip{$key}{private})) {
				if ($ip{$key}{private}) {
					$privateadapter = $key;
				}
			}
		}

		if ($ip{$privateadapter}{"DHCPenabled"} =~ /No/) {
			notify($ERRORS{'OK'}, 0, "DHCP disabled for $privateadapter on $computer_node_name - reseting to dhcp");
			if (open(NETSH, "/usr/bin/ssh -q -i $management_node_keys $computer_node_name \"netsh interface ip set address name=\\\"$privateadapter\\\" source=dhcp\" & 2>&1 |")) {
				#losing connection
				my $go = 1;
				while ($go) {
					#print "hi\n";
					sleep 4;
					if (open(PS, "ps -ef |")) {
						my @ps = <PS>;
						close(PS);
						sleep 4;
						foreach my $p (@ps) {
							if ($p =~ /$computer_node_name netsh interface/) {
								if ($p =~ /(root)\s+([0-9]*)/) {
									if (open(KILLIT, "kill -9 $2 |")) {
										close(KILLIT);
										close(NETSH);
										notify($ERRORS{'OK'}, 0, "killing ssh $computer_node_name netsh process");
									}
								}
							}
						} ## end foreach my $p (@ps)
					} ## end if (open(PS, "ps -ef |"))
					$go = 0;
				} ## end while ($go)
			}    # Close open netsh SSH handle

			#make sure it came back confirm is was reset to dhcp
			sleep 5;
			my $sshd_status = _sshd_status($computer_node_name, $image_name);
			if ($sshd_status eq "on") {
				notify($ERRORS{'OK'}, 0, "successful $computer_node_name is accessible after dhcp assignment");
				my $myadapter;
				undef @sshcmd;
				@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "ipconfig -all", "root");
				# build hash of needed info and set the correct private adapter.
				foreach my $a (@{$sshcmd[1]}) {
					if ($a =~ /Ethernet adapter (.*):/) {
						#print "$1\n";
						$myadapter = $1;
					}
					if ($a =~ /IP Address([\s.]*): $computer_private_ip/) {
						$ip{$myadapter}{"private"} = 1;
					}
					if ($a =~ /DHCP Enabled([\s.]*): (No|Yes)/) {
						$ip{$myadapter}{"DHCPenabled"} = $2;
					}
				} ## end foreach my $a (@{$sshcmd[1]})
				if ($ip{$privateadapter}{"DHCPenabled"} =~ /Yes/) {
					notify($ERRORS{'OK'}, 0, "successful $computer_node_name is correctly assigned to use dhcp");
				}
				elsif ($ip{$privateadapter}{"DHCPenabled"} =~ /No/) {
					notify($ERRORS{'CRITICAL'}, 0, "could not change $privateadapter on $computer_node_name back  to dhcp");

					return 0;
				}
			} ## end if ($sshd_status eq "on")
			else {
				notify($ERRORS{'CRITICAL'}, 0, "sshd_status set to off, can not reconnect to $computer_node_name");
				return 0;
			}
		}    # Close if DHCP == no

		else {
			notify($ERRORS{'OK'}, 0, "dhcp for $privateadapter is set to Yes on $computer_node_name $ip{$privateadapter}{DHCPenabled} - no change needed");
		}
	} ## end if ($image_name =~ /^win2003/)

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
	notify($ERRORS{'OK'}, 0, "starting defrag on $computer_node_name");
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "cmd.exe /c defrag C: -f", "root");
	my $defragged = 0;
	foreach my $d (@{$sshcmd[1]}) {
		if ($d =~ /Defragmentation Report/) {
			notify($ERRORS{'OK'}, 0, "successfully defragmented $computer_node_name");
			$defragged = 1;
		}
	}
	if (!$defragged) {
		notify($ERRORS{'WARNING'}, 0, "problem occurred while defragmenting $computer_node_name: @{ $sshcmd[1] }");
	}


	# Copy new auto_create_image.vbs and auto_prepare_for_image.vbs
	# This moves(sometimes) the pagefile and reboots the box
	# It actually checks for a removes the pagefile.sys
	my @scp;
	if (run_scp_command("$TOOLS/auto_create_image.vbs", "$computer_node_name:auto_create_image.vbs", $management_node_keys)) {
		notify($ERRORS{'OK'}, 0, "successfully copied auto_create_image.vbs to $computer_node_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to copy auto_create_image.vbs to $computer_node_name ");
		return 0;
	}


	# Make sure sshd service is set to auto
	if (_set_sshd_startmode($computer_node_name, "auto")) {
		notify($ERRORS{'OK'}, 0, "successfully set auto mode for sshd start");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to set auto mode for sshd on $computer_node_name");
		return 0;
	}

	my @list;
	my $l;
	#execute the vbs script to disable the pagefile and reboot
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $management_node_keys, "cscript.exe //Nologo auto_create_image.vbs", "root");
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
			if (VCL::Module::Provisioning::xCAT::_rpower($computer_node_name, "boot")) {
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

	# Remove old Sysprep files if they exist
	if (run_ssh_command($computer_node_name, $IDENTITY_wxp, "/usr/bin/rm.exe -rf C:\/Sysprep", "root")) {
		notify($ERRORS{'OK'}, 0, "removed any existing Sysprep files");
	}

	# Copy Sysprep files
	COPY_SYSPREP:
	if ($imagemeta_sysprep) {
		#cp sysprep to C:
		#chmod C:\Sysprep\*
		# which sysprep to use
		my $sysprep_files;
		if ($image_name =~ /^winxp/) {
			$sysprep_files = $SYSPREP;
		}
		elsif ($image_name =~ /^win2003/) {
			$sysprep_files = $SYSPREP_2003;
		}

		notify($ERRORS{'OK'}, 0, "copying Sysprep files to $computer_short_name");
		if (run_scp_command($sysprep_files, "$computer_node_name:C:\/Sysprep", $IDENTITY_wxp)) {
			notify($ERRORS{'OK'}, 0, "copied Sysprep directory $sysprep_files to $computer_node_name C:");

			if (run_ssh_command($computer_node_name, $IDENTITY_wxp, "/usr/bin/chmod.exe -R 755 C:\/Sysprep", "root")) {
				notify($ERRORS{'OK'}, 0, "chmoded -R 755 C:\/Sysprep files ");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not chmod -R 755 on $computer_node_name $!");
			}
		} ## end if (run_scp_command($sysprep_files, "$computer_node_name:C:\/Sysprep"...
		else {
			notify($ERRORS{'CRITICAL'}, 0, "could not copy $sysprep_files to $computer_node_name, $!");
			return 0;
		}
	} ## end if ($imagemeta_sysprep)

	# Set sshd service startup to manual
	if (_set_sshd_startmode($computer_node_name, "manual")) {
		notify($ERRORS{'OK'}, 0, "successfully set manual mode for sshd start");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to set manual mode for sshd on $computer_node_name");
		return 0;
	}


	#actually remove the pagefile.sys sometimes movefile.exe does not work
	if (run_ssh_command($computer_node_name, $IDENTITY_wxp, "/usr/bin/rm -v C:\/pagefile.sys", "root")) {
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


=cut
