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

VCL::Provisioning::xCAT - VCL module to support the xCAT provisioning engine

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for xCAT (Extreme Cluster Administration
 Toolkit).  xCAT is a scalable distributed computing management and
 provisioning tool that provides a unified interface for hardware control,
 discovery, and OS diskful/diskfree deployment.
 http://xcat.sourceforge.net

=cut

##############################################################################
package VCL::Module::Provisioning::xCAT;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);
use File::Copy;

##############################################################################

=head1 CLASS ATTRIBUTES

=cut

=head2 $XCAT_ROOT

 Data type   : scalar
 Description : $XCAT_ROOT stores the location of the xCAT binary files. xCAT
               should set the XCATROOT environment variable. This is used if
					it is set.  If XCATROOT is not set, /opt/xcat is used.

=cut

# Class attributes to store xCAT configuration details
my $XCAT_ROOT;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  :
 Returns     :
 Description :

=cut

sub initialize {
	my $self = shift;

	# Check the XCAT_ROOT environment variable, it should be defined
	if (defined($ENV{XCATROOT}) && $ENV{XCATROOT}) {
		$XCAT_ROOT = $ENV{XCATROOT};
	}
	elsif (defined($ENV{XCATROOT})) {
		notify($ERRORS{'OK'}, 0, "XCATROOT environment variable is not defined, using /opt/xcat");
		$XCAT_ROOT = '/opt/xcat';
	}
	else {
		notify($ERRORS{'OK'}, 0, "XCATROOT environment variable is not set, using /opt/xcat");
		$XCAT_ROOT = '/opt/xcat';
	}

	# Remove trailing / from $XCAT_ROOT if exists
	$XCAT_ROOT =~ s/\/$//;

	# Make sure the xCAT root path is valid
	if (!-d $XCAT_ROOT) {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize xCAT module, $XCAT_ROOT directory does not exist");
		return;
	}

	# Check to make sure one of the expected executables is where it should be
	if (!-x "$XCAT_ROOT/bin/rpower") {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize xCAT module, expected executable was not found: $XCAT_ROOT/bin/rpower");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "xCAT root path found: $XCAT_ROOT");

	notify($ERRORS{'DEBUG'}, 0, "xCAT module initialized");
	return 1;
} ## end sub initialize

#/////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads node with provided image

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get the data
	my $reservation_id       = $self->data->get_reservation_id();
	my $image_name           = $self->data->get_image_name();
	my $image_os_name        = $self->data->get_image_os_name();
	my $image_os_type        = $self->data->get_image_os_type();
	my $image_project        = $self->data->get_image_project();
	my $image_reload_time    = $self->data->get_image_reload_time();
	my $imagemeta_postoption = $self->data->get_imagemeta_postoption();
	my $image_architecture   = $self->data->get_image_architecture();
	my $computer_id          = $self->data->get_computer_id();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $computer_ip_address  = $self->data->get_computer_ip_address();

	notify($ERRORS{'OK'}, 0, "nodename not set")
	  if (!defined($computer_node_name));
	notify($ERRORS{'OK'}, 0, "imagename not set")
	  if (!defined($image_name));
	notify($ERRORS{'OK'}, 0, "project not set")
	  if (!defined($image_project));
	notify($ERRORS{'OK'}, 0, "estimated reload time not set")
	  if (!defined($image_reload_time));
	notify($ERRORS{'OK'}, 0, "osname not set")
	  if (!defined($image_os_name));
	notify($ERRORS{'OK'}, 0, "computerid not set")
	  if (!defined($computer_id));
	notify($ERRORS{'OK'}, 0, "reservationid not set")
	  if (!defined($reservation_id));
	notify($ERRORS{'OK'}, 0, "architecture not set")
	  if (!defined($image_architecture));

	# Initialize some timer variables
	# Do this here in case goto passes over the declaration
	my $sshd_start_time;
	my $sshd_end_time;

	insertloadlog($reservation_id, $computer_id, "startload", "$computer_node_name $image_name");

	#make sure the following services are running on management node
	# dhcpd named xcatd
	# start them if they are not actively running
	$image_project = "vcl" if (!defined($image_project));

	$image_architecture = "x86" if (!defined($image_architecture));

	# Run xCAT's assign2project utility
	if (_assign2project($computer_node_name, $image_project)) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name _assign2project return successful");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$computer_node_name could not _assign2project to $image_project");
		return 0;
	}

	# Make sure dhcpd is started on management node
	if (!(_checknstartservice("dhcpd"))) {
		notify($ERRORS{'CRITICAL'}, 0, "dhcpd is not running or failed to restart");
	}

	# Make sure named is started on management node
	if (!(_checknstartservice("named"))) {
		notify($ERRORS{'CRITICAL'}, 0, "named is not running or failed to restart");
	}

	# Make sure xcatd is started on management node
	if (!(_checknstartservice("xcatd"))) {
		notify($ERRORS{'CRITICAL'}, 0, "xcatd is not running or failed to restart");
	}

	# Make sure atftpd is started on management node
	if (!(_checknstartservice("atftpd"))) {
		notify($ERRORS{'CRITICAL'}, 0, "atftpd is not running or failed to restart");
	}

	# Insert a computerloadlog record and edit nodetype.tab
	insertloadlog($reservation_id, $computer_id, "editnodetype", "updating nodetype file");
	if ($self->_edit_nodetype($computer_node_name, $image_name, $image_os_name, $image_architecture)) {
		notify($ERRORS{'OK'}, 0, "nodetype updated for $computer_node_name with $image_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not edit nodetype for $computer_node_name with $image_name");
	}

	# Begin reinstallation using xCAT's rinstall
	# Loop and continue checking

	# Set flags and counters
	my $rinstall_attempts = 0;
	my $rpower_fixes      = 0;
	my $bootstatus        = 0;
	my $wait_loops        = 0;
	my @status;

	# Check to see if management node throttle is configured
	if ($THROTTLE) {
		notify($ERRORS{'DEBUG'}, 0, "throttle is set to $THROTTLE");

		my $lckloadfile = "/tmp/nodeloading.lockfile";
		notify($ERRORS{'DEBUG'}, 0, "attempting to open node loading lockfile for throttling: $lckloadfile");
		if (sysopen(SEM, $lckloadfile, O_RDONLY | O_CREAT)) {
			notify($ERRORS{'DEBUG'}, 0, "opened lockfile, attempting to obtain lock");

			if (flock(SEM, LOCK_EX)) {
				notify($ERRORS{'DEBUG'}, 0, "obtained exclusive lock on $lckloadfile, checking for concurrent loads");
				my $maxload = 1;
				while ($maxload) {
					notify($ERRORS{'DEBUG'}, 0, "running 'nodeset all stat' to determine number of nodes currently being loaded");
					if (open(NODESET, "$XCAT_ROOT/bin/nodeset all stat \| grep install 2>&1 | ")) {
						my @nodesetout = <NODESET>;
						close(NODESET);
						my $ld = @nodesetout;
						notify($ERRORS{'DEBUG'}, 0, "current number of nodes loading: $ld");

						if ($ld < $THROTTLE) {
							notify($ERRORS{'OK'}, 0, "current nodes loading is less than throttle, ok to proceed");
							$maxload = 0;
						}
						else {
							notify($ERRORS{'OK'}, 0, "current nodes loading=$ld, throttle=$THROTTLE, must wait, sleeping for 10 seconds");
							sleep 10;
						}
					} ## end if (open(NODESET, "$XCAT_ROOT/bin/nodeset all stat \| grep install 2>&1 | "...
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to run 'nodeset all stat' to determine number of nodes currently being loaded");
					}
				} ## end while ($maxload)
			} ## end if (flock(SEM, LOCK_EX))
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to obtain exclusive lock on $lckloadfile");
			}

			notify($ERRORS{'OK'}, 0, "releasing exclusive lock on $lckloadfile, proceeding to install");
			close(SEM);

		} ## end if (sysopen(SEM, $lckloadfile, O_RDONLY | ...
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to open node loading lockfile");
		}

	} ## end if ($THROTTLE)
	else {
		notify($ERRORS{'DEBUG'}, 0, "throttle is NOT set");
	}

	XCATRINSTALL:

	# Reset sshd wait start time, used only for diagnostic purposes
	$sshd_start_time = 0;

	# Make use of semaphore files to control the flow
	# xCAT's rinstall does not handle locking of files
	my $lckfile = "/tmp/rinstall.lockfile";
	notify($ERRORS{'DEBUG'}, 0, "attempting to open rinstall lockfile: $lckfile");
	if (sysopen(SEM, $lckfile, O_RDONLY | O_CREAT)) {
		notify($ERRORS{'DEBUG'}, 0, "opened lockfile, attempting to obtain lock");

		if (flock(SEM, LOCK_EX)) {
			notify($ERRORS{'DEBUG'}, 0, "obtained exclusive lock on $lckfile");

			# Safe to run rinstall command
			insertloadlog($reservation_id, $computer_id, "rinstall", "starting install process");
			notify($ERRORS{'OK'}, 0, "executing rinstall $computer_node_name");
			if (open(RINSTALL, "$XCAT_ROOT/bin/rinstall $computer_node_name 2>&1 |")) {
				$rinstall_attempts++;
				notify($ERRORS{'OK'}, 0, "beginning rinstall attempt $rinstall_attempts");
				while (<RINSTALL>) {
					chomp($_);

					#notify($ERRORS{'OK'},0,"$_");
					if ($_ =~ /not in bay/) {
						notify($ERRORS{'WARNING'}, 0, "rpower not in bay issue, will attempt to correct, calling rinv");
						if (_fix_rpower($computer_node_name)) {

							#try xcatrinstall again
							close(RINSTALL);
							close(SEM);    # remove lock
							               # loop control
							if ($rpower_fixes < 10) {
								$rpower_fixes++;
								sleep 1;
								goto XCATRINSTALL;
							}
							else {
								notify($ERRORS{'CRITCAL'}, 0, "rpower failed $rpower_fixes times on $computer_node_name");
								return 0;
							}
						} ## end if (_fix_rpower($computer_node_name))
					} ## end if ($_ =~ /not in bay/)
					if ($_ =~ /Invalid login|does not exist/) {
						notify($ERRORS{'CRITCAL'}, 0, "failed to initate rinstall on $computer_node_name - $_");
						close(RINSTALL);
						close(SEM);
						insertloadlog($reservation_id, $computer_id, "failed", "failed to start load process on $computer_node_name");
						return 0;
					}

				}    #while RINSTALL
				close(RINSTALL);

				notify($ERRORS{'OK'}, 0, "releasing exclusive lock on $lckfile");
				close(SEM);
			} ## end if (open(RINSTALL, "$XCAT_ROOT/bin/rinstall $computer_node_name 2>&1 |"...
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not execute $XCAT_ROOT/bin/rinstall $computer_node_name $!");
				close(SEM);
				return 0;
			}
		} ## end if (flock(SEM, LOCK_EX))
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to obtain exclusive lock on $lckfile, error: $!, returning");
			return;
		}
	} ## end if (sysopen(SEM, $lckfile, O_RDONLY | O_CREAT...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open node loading lockfile, error: $!, returning");
		return;
	}

	# Check progress, locate MAC and IP address for this node, monitor /var/log/messages for communication from node
	# dhcp req/ack, xcat calls, etc
	my ($eth0MACaddress, $privateIP);
	if (open(MACTAB, "$XCAT_ROOT/etc/mac.tab")) {
		my @mactab = <MACTAB>;
		close(MACTAB);
		foreach my $line (@mactab) {
			if ($line =~ /(^$computer_node_name(-eth[0-9])?)(\s+)([:0-9a-f]*)/) {
				$eth0MACaddress = $4;
				notify($ERRORS{'OK'}, 0, "MAC address for $computer_node_name collected $eth0MACaddress");
			}
		}
	} ## end if (open(MACTAB, "$XCAT_ROOT/etc/mac.tab"))
	if (!defined($eth0MACaddress)) {
		notify($ERRORS{'WARNING'}, 0, "MAC address not found for $computer_node_name , possible issue with regex");
	}

	#should also store/pull private address from the database
	if (open(HOSTS, "/etc/hosts")) {
		my @hosts = <HOSTS>;
		close(HOSTS);
		foreach my $line (@hosts) {
			if ($line =~ /([0-9]*.[0-9]*.[0-9]*.[0-9]*)\s+($computer_node_name)/) {
				$privateIP = $1;
				notify($ERRORS{'OK'}, 0, "PrivateIP address for $computer_node_name collected $privateIP");
				last;
			}
		}
	} ## end if (open(HOSTS, "/etc/hosts"))
	if (!defined($privateIP)) {
		notify($ERRORS{'WARNING'}, 0, "private IP address not found for $computer_node_name, possible issue with regex");
	}
	my ($s1, $s2, $s3, $s4, $s5) = 0;
	my $sloop = 0;

	#insertloadlog($reservation_id,$computer_id,"info","SUCCESS initiated install process");
	#sleep for boot process to happen takes anywhere from 60-90 seconds
	notify($ERRORS{'OK'}, 0, "sleeping 65 to allow bootstrap of $computer_node_name");
	sleep 65;
	my @TAILLOG;
	my $t;

	if ($eth0MACaddress && $privateIP) {
		@TAILLOG = 0;
		$t       = 0;
		if (open(TAIL, "</var/log/messages")) {
			seek TAIL, -1, 2;    #
			for (;;) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name ROUND 1 checks loop $sloop of 45");
				while (<TAIL>) {
					if (!$s1) {
						if ($_ =~ /dhcpd: DHCPDISCOVER from $eth0MACaddress/) {
							$s1 = 1;
							notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 1 set DHCPDISCOVER from $eth0MACaddress");
							insertloadlog($reservation_id, $computer_id, "xcatstage1", "SUCCESS stage1 detected dhcp request for node");
						}
					}
					if (!$s2) {
						if ($_ =~ /dhcpd: DHCPACK on $privateIP to $eth0MACaddress/) {
							$s2 = 1;
							notify($ERRORS{'OK'}, 0, "$computer_node_name  STAGE 2 set DHCPACK on $privateIP to $eth0MACaddress");
							insertloadlog($reservation_id, $computer_id, "xcatstage2", "SUCCESS stage2 detected dhcp ack for node");
						}
					}
					if (!$s3) {
						if ($_ =~ /Serving \/tftpboot\/pxelinux.0 to $privateIP:/) {
							$s3 = 1;
							chomp($_);
							notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 3 set $_");
							insertloadlog($reservation_id, $computer_id, "xcatstage3", "SUCCESS stage3 node received pxe");
						}
					}
					if (!$s4) {
						if ($_ =~ /Serving \/tftpboot\/xcat\/([.-_a-zA-Z0-9]*)\/x86\/install.gz to $privateIP:/) {
							$s4 = 1;
							chomp($_);
							notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 4 set $_");
							insertloadlog($reservation_id, $computer_id, "xcatstage4", "SUCCESS stage4 node received pxe install instructions");
						}
					}

					#stage5 is where images and rhas(KS) are different
					if (!$s5) {

						#here we look for rpc.mountd
						if ($_ =~ /authenticated mount request from ($computer_node_name|$privateIP):(\d+) for/) {
							$s5 = 1;
							chomp($_);
							notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 5 set $_");
							insertloadlog($reservation_id, $computer_id, "xcatstage5", "SUCCESS stage5 node started installing via partimage");
						}

						#in case we miss the above statement
						if ($image_os_type =~ /linux/i) {
							if ($_ =~ /xcat: xcatd: $computer_node_name installing/) {
								$s5 = 1;
								chomp($_);
								notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 5 set $_");
								insertloadlog($reservation_id, $computer_id, "xcatstage5", "SUCCESS stage5 node started installing via kickstart");
							}
						}
					} ## end if (!$s5)
				}    #while
				     #either stages are set or we loop or we rinstall again
				     #check s5 and counter for loop control
				if ($s5) {
					notify($ERRORS{'OK'}, 0, "$computer_node_name ROUND1 stages are set proceeding to next round");
					close(TAIL);
					goto ROUND2;
				}
				elsif ($sloop > 45) {
					insertloadlog($reservation_id, $computer_id, "WARNING", "potential problem started $rinstall_attempts install attempt");

					#hrmm this is taking too long
					#have we been here before? if less than 3 attempts continue on the 3rd try fail
					#whats the problem, chck known locations
					# /tftpboot/xcat/image/x86
					# look for tmpl file (in does_image_exist routine)
					# does the machine need to reboot, premission to reboot issue
					if (_check_pxe_grub_files($image_name)) {
						notify($ERRORS{'OK'}, 0, "checkpxe_grub_file checked");
					}

					if ($rinstall_attempts < 3) {
						close(TAIL);
						insertloadlog($reservation_id, $computer_id, "repeat", "starting install process");
						goto XCATRINSTALL;
					}
					else {

						#fail this one and let whoever called me get another machine
						notify($ERRORS{'CRITICAL'}, 0, "rinstall made $rinstall_attempts in ROUND1 on $computer_node_name with no success, admin needs to check it out");
						insertloadlog($reservation_id, $computer_id, "failed", "FAILED problem made $rinstall_attempts install attempts failing reservation");
						if (_nodeset_option($computer_node_name, "boot")) {
							notify($ERRORS{'OK'}, 0, "due to failure reseting state of blade to boot");
						}
						close(TAIL);
						return 0;
					} ## end else [ if ($rinstall_attempts < 3)
				} ## end elsif ($sloop > 45)  [ if ($s5)
				else {

					#keep checking the messages log
					$sloop++;
					sleep 7;
					seek TAIL, 0, 1;
				}
			}    #for loop
		}    #if Tail
		else {
			notify($ERRORS{'CRITICAL'}, 0, "could open /var/log/messages to  $!");
		}
	} ## end if ($eth0MACaddress && $privateIP)
	else {
		notify($ERRORS{'CRITICAL'}, 0, "eth0MACaddress $eth0MACaddress && privateIP $privateIP  are not set not able to use these checks");
		insertloadlog($reservation_id, $computer_id, "failed", "FAILED could not locate private IP and MAC addresses in XCAT files failing reservation");
		return 0;
	}

	ROUND2:

	#begin second round of checks reset $sX
	($s1, $s2, $s3, $s4, $s5) = 0;
	$sloop = 0;

	# start time for loading
	my $R2starttime = convert_to_epoch_seconds();

	#during loading we need to wait based on some precentage of the estimated reload time (50%?)
	#times range from 4-10 minutes perhaps longer for a large image
	my $TM2waittime = int($image_reload_time / 2);
	insertloadlog($reservation_id, $computer_id, "xcatround2", "starting ROUND2 checks - waiting for boot flag");

	notify($ERRORS{'OK'}, 0, "Round 2 TM2waittime set to $TM2waittime on $computer_node_name");
	if (open(TAIL, "</var/log/messages")) {
		seek TAIL, -1, 2;
		my $gettingclose = 0;
		for (;;) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name round2 log checks 30sec loop count is $sloop of $image_reload_time TM2waittime= $TM2waittime");
			while (<TAIL>) {
				if (!$s1) {
					if ($_ =~ /xcat: xcatd: set boot request from $computer_node_name/) {

						insertloadlog($reservation_id, $computer_id, "bootstate", "node in boot state completed imaging process - proceeding to next round");
						$s1 = 1;
						notify($ERRORS{'OK'}, 0, "Round 2 STAGE 1 set $computer_node_name in boot state");
					}

					#is it even near completion only checking rhel installs
					#not really useful for linux_images
					if ($image_os_type =~ /linux/i) {
						if (!$gettingclose) {
							if ($_ =~ /rpc.mountd: authenticated mount request from $computer_node_name:(\d+) for \/install\/post/) {
								$gettingclose = 1;
								notify($ERRORS{'OK'}, 0, "Round 2 STAGE 1 install nearing completion on node $computer_node_name");
							}
						}
						else {
							if (!$s4) {
								if ($sloop == $image_reload_time) {
									notify($ERRORS{'OK'}, 0, "$computer_node_name Round 2 getting close, loop eq $image_reload_time, substracting 6 from loop count");
									$sloop = ($sloop - 8);
									$s4    = 1;              #loop control, don't set this we loop forever
									notify($ERRORS{'WARNING'}, 0, "ert estimated reload time may be too low\n $computer_node_name\nimagename $image_name\n current ert = $image_reload_time");
								}
							}
						} ## end else [ if (!$gettingclose)
					} ## end if ($image_os_type =~ /linux/i)
				} ## end if (!$s1)
			}    #while
			if ($s1) {

				#good, move on
				close(TAIL);
				goto ROUND3;
			}
			else {
				if ($sloop > $image_reload_time) {
					notify($ERRORS{'OK'}, 0, "exceeded TM2waittime of $TM2waittime minutes sloop= $sloop ert= $image_reload_time");

					# check delta from when we started actual loading till now
					my $rtime = convert_to_epoch_seconds();
					my $delta = $rtime - $R2starttime;
					if ($delta < ($image_reload_time * 60)) {

						#ok  delta is actually less then ert, we don't need to stop it yet.
						notify($ERRORS{'OK'}, 0, "loading delta is less than ert, not stopping yet delta is $delta/60 ");
						sleep 35;
						$sloop = ($sloop - 8);    #decrement loop control
						seek TAIL, 0, 1;

					}
					elsif ($rinstall_attempts < 2) {
						notify($ERRORS{'WARNING'}, 0, "starting rinstall again");
						insertloadlog($reservation_id, $computer_id, "WARNING", "potential problem restarting rinstall current attemp $rinstall_attempts");
						close(TAIL);
						insertloadlog($reservation_id, $computer_id, "repeat", "starting install process");
						goto XCATRINSTALL;
					}
					else {

						#fail this one and let whoever called me get another machine
						notify($ERRORS{'CRITICAL'}, 0, "rinstall made $rinstall_attempts in ROUND2 on $computer_node_name with no success, admin needs to check it out");
						insertloadlog($reservation_id, $computer_id, "failed", "rinstall made $rinstall_attempts failing request");
						close(TAIL);
						return 0;
					}
				} ## end if ($sloop > $image_reload_time)
				else {
					sleep 35;
					$sloop++;    #loop control
					insertloadlog($reservation_id, $computer_id, "info", "node in load process waiting for signal");
					seek TAIL, 0, 1;

					#goto TAILMESSAGES2;
				}
			} ## end else [ if ($s1)
		}    #for
	} ## end if (open(TAIL, "</var/log/messages"))
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could open /var/log/messages to $!");
		return 0;
	}

	ROUND3:

	my $nodeset_status;

	# Round 3 checks, machine has been installed we wait here for boot process which could include sysprep
	# we are checking for the boot state in the OS status
	insertloadlog($reservation_id, $computer_id, "xcatround3", "starting round 3 checks - finishing post configuration");
	$wait_loops = 0;
	while (!$bootstatus) {
		my $nodeset_status = _nodeset($computer_node_name);

		if ($nodeset_status =~ /boot/) {
			$bootstatus = 1;
			notify($ERRORS{'OK'}, 0, "$computer_node_name has been reinstalled with $image_name");
			notify($ERRORS{'OK'}, 0, "xcat has set the boot flag");
			if ($image_os_type =~ /windows/i) {
				notify($ERRORS{'OK'}, 0, "waiting 3 minutes to allow OS to reboot and initialize machine");
				sleep 180;
			}

			elsif ($image_os_type =~ /linux/i) {
				notify($ERRORS{'OK'}, 0, "waiting 65 sec to allow OS to reboot and initialize machine");
				sleep 65;
			}
			else {
				notify($ERRORS{'OK'}, 0, "waiting 3 minutes to allow OS to reboot and initialize machine");
				sleep 180;
			}
			my ($readycount, $ready) = 0;
			READYFLAG:

			#check /var/log/messages file for READY

			# Wait for READY flag
			if (open(TAIL, "</var/log/messages")) {
				seek TAIL, -1, 2;
				for (;;) {
					notify($ERRORS{'OK'}, 0, "$computer_node_name checking for READY FLAG loop count is $readycount of 10");
					while (<TAIL>) {
						if ($_ =~ /READY|ready|Starting firstboot:  succeeded/) {
							$ready = 1 if ($_ =~ /$computer_node_name/);
						}
						if ($image_os_type =~ /linux/i) {
							if ($_ =~ /$computer_node_name|$computer_node_name kernel/) {
								notify($ERRORS{'OK'}, 0, "$computer_node_name booting up");
								sleep 5;
								$ready = 1;
								close(TAIL);
								goto SSHDATTEMPT;
							}
						}
					}    #while

					if ($readycount > 10) {
						notify($ERRORS{'OK'}, 0, "taking longer than expected, readycount==$readycount moving to next set of checks");
						$ready = 1;
						close(TAIL);
						goto SSHDATTEMPT;
					}
					#if ($readycount > 2) {

					#check ssh status just in case we missed the flag
					my $sshd = _sshd_status($computer_node_name, $image_name, $image_os_type);
					if ($sshd eq "on") {
						$ready = 1;
						notify($ERRORS{'OK'}, 0, "we may have missed start flag going next stage");
						close(TAIL);
						goto SSHDATTEMPT;
					}
					#} ## end if ($readycount > 2)
					if (!$ready) {
						notify($ERRORS{'OK'}, 0, "$computer_node_name not ready yet, sleeping for 40 seconds");
						sleep 40;
						seek TAIL, 0, 1;
					}
					else {
						notify($ERRORS{'OK'}, 0, "/var/log/messages reports $computer_node_name is ready");
						insertloadlog($reservation_id, $computer_id, "xcatREADY", "detected ready signal from node - proceeding");
						close(TAIL);
						goto SSHDATTEMPT;
					}

					#placing out side of if statements for loop control
					$readycount++;
				}    #for
			} ## end if (open(TAIL, "</var/log/messages"))
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not open messages at READYFLAG $!");
			}
			notify($ERRORS{'OK'}, 0, "proceeding for sync sshd active");
		} ## end if ($nodeset_status =~ /boot/)
		else {

			# check for strange states

		}
	} ## end while (!$bootstatus)

	# we need to wait for sshd to become active
	my $sshd_attempts = 0;
	SSHDATTEMPT:
	my $sshdstatus = 0;
	$wait_loops = 0;
	$sshd_attempts++;
	my $sshd_status = "off";

	# Set the sshd start time to now if it hasn't been set already
	# This is used to report how long sshd took to become active
	$sshd_start_time = time() if !$sshd_start_time;

	while (!$sshdstatus) {
		my $sshd_status = _sshd_status($computer_node_name, $image_name, $image_os_type);
		if ($sshd_status eq "on") {

			# Set the sshd end time to now to capture how long it took sshd to become active
			$sshd_end_time = time();
			my $sshd_duration = $sshd_end_time - $sshd_start_time;

			$sshdstatus = 1;
			notify($ERRORS{'OK'}, 0, "$computer_node_name sshd has become active, took $sshd_duration secs, ok to proceed to sync ssh keys");
			insertloadlog($reservation_id, $computer_id, "info", "synchronizing keys");
		} ## end if ($sshd_status eq "on")
		else {

			#either sshd is off or N/A, we wait
			if ($wait_loops >= 7) {
				if ($sshd_attempts < 3) {
					goto SSHDATTEMPT;
				}
				else {

					# Waited long enough for sshd to become active

					# Set the sshd end time to now to capture how long process waited for sshd to become active
					$sshd_end_time = time();
					my $sshd_duration = $sshd_end_time - $sshd_start_time;

					notify($ERRORS{'WARNING'}, 0, "$computer_node_name waited acceptable amount of time for sshd to become active, $sshd_duration secs");

					#need to check power, maybe reboot it. for now fail it
					#try to reinstall it once
					if ($rinstall_attempts < 2) {
						my $debugging_message = "*reservation has NOT failed yet*\n";
						$debugging_message .= "this notice is for debugging purposes so that node can be watched during 2nd rinstall attempt\n";
						$debugging_message .= "sshd did not become active on $computer_node_name after first rinstall attempt\n\n";

						$debugging_message .= "management node:     " . $self->data->get_management_node_hostname() . "\n";
						$debugging_message .= "pid:                 " . $PID . "\n";
						$debugging_message .= "request:             " . $self->data->get_request_id() . "\n";
						$debugging_message .= "reservation:         " . $self->data->get_reservation_id() . "\n";
						$debugging_message .= "state/laststate:     " . $self->data->get_request_state_name() . "/" . $self->data->get_request_laststate_name() . "\n";
						$debugging_message .= "computer:            " . $self->data->get_computer_host_name() . " (id: " . $self->data->get_computer_id() . ")\n";
						$debugging_message .= "user:                " . $self->data->get_user_login_id() . " (id: " . $self->data->get_user_id() . ")\n";
						$debugging_message .= "image:               " . $self->data->get_image_name() . " (id: " . $self->data->get_image_id() . ")\n";
						$debugging_message .= "image prettyname:    " . $self->data->get_image_prettyname() . "\n";
						$debugging_message .= "image size:          " . $self->data->get_image_size() . "\n";
						$debugging_message .= "reload time:         " . $self->data->get_image_reload_time() . "\n";

						notify($ERRORS{'CRITICAL'}, 0, "$debugging_message");
						insertloadlog($reservation_id, $computer_id, "repeat", "starting install process");
						close(TAIL);
						goto XCATRINSTALL;
					} ## end if ($rinstall_attempts < 2)
					else {
						notify($ERRORS{'WARNING'}, 0, "$computer_node_name: sshd never became active after 2 rinstall attempts");
						insertloadlog($reservation_id, $computer_id, "failed", "exceeded maximum install attempts");
						return 0;
					}
				} ## end else [ if ($sshd_attempts < 3)
			} ## end if ($wait_loops >= 7)
			else {
				$wait_loops++;

				# to give post config a chance
				notify($ERRORS{'OK'}, 0, "going to sleep 15 seconds, waiting for post config to finish");
				sleep 15;
			}
		}    # else
	}    #while

	# Clear ssh public keys from /root/.ssh/known_hosts
	my $known_hosts = "/root/.ssh/known_hosts";
	my @file;
	if (open(FILE, $known_hosts)) {
		@file = <FILE>;
		close FILE;

		foreach my $line (@file) {
			if ($line =~ s/$computer_node_name.*\n//) {
				notify($ERRORS{'OK'}, 0, "removing $computer_node_name ssh public key from $known_hosts");
			}
		}

		if (open(FILE, ">$known_hosts")) {
			print FILE @file;
			close FILE;
		}
	} ## end if (open(FILE, $known_hosts))
	else {
		notify($ERRORS{'OK'}, 0, "could not open $known_hosts for editing the $computer_node_name public ssh key");
	}

	# Synchronize ssh keys using xCAT's makesshgkh
	my $makessygkh_attempts = 0;
	MAKESSH:
	notify($ERRORS{'OK'}, 0, " resting 1sec before executing makesshgkh");
	sleep 1;
	if (open(MAKESSHGKH, "$XCAT_ROOT/sbin/makesshgkh $computer_node_name |")) {
		$makessygkh_attempts++;
		notify($ERRORS{'OK'}, 0, " makesshgkh attempt $makessygkh_attempts ");
		while (<MAKESSHGKH>) {
			chomp($_);
			if ($_ =~ /Scanning keys/) {
				notify($ERRORS{'OK'}, 0, "$_");
			}
		}
		close MAKESSHGKH;
		my $keysync      = 0;
		my $keysynccheck = 0;

		while (!$keysync) {
			$keysynccheck++;
			my $sshd = _sshd_status($computer_node_name, $image_name, $image_os_type);
			if ($sshd =~ /on/) {
				$keysync = 1;
				notify($ERRORS{'OK'}, 0, "keys synced");
				insertloadlog($reservation_id, $computer_id, "info", "SUCCESS keys synchronized");
				last;
			}
			if ($keysynccheck > 3) {
				if ($makessygkh_attempts < 1) {
					notify($ERRORS{'OK'}, 0, "keysynccheck exceeded 5 minutes, there might be a problem running makesshgkh again");
					goto MAKESSH;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "makesshgkh exceeded 2 attempts to create new ssh keys there appears to be a problem with $computer_node_name moving on");

					#move on-
					$keysync = 1;
					last;
				}
			} ## end if ($keysynccheck > 3)
			notify($ERRORS{'OK'}, 0, "waiting for ssh keys to be updated");
			sleep 5;
		} ## end while (!$keysync)
	} ## end if (open(MAKESSHGKH, "$XCAT_ROOT/sbin/makesshgkh $computer_node_name |"...
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not execute $XCAT_ROOT/sbin/makesshgkh $computer_node_name $!");
	}

	# IP configuration
	if ($IPCONFIGURATION ne "manualDHCP") {
		insertloadlog($reservation_id, $computer_id, "info", "detected change required in IP address configuration on node");

		#not default setting
		if ($IPCONFIGURATION eq "dynamicDHCP") {
			my $assignedIPaddress = getdynamicaddress($computer_node_name, $image_os_name, $image_os_type);
			if ($assignedIPaddress) {

				#update computer table
				if (update_computer_address($computer_id, $assignedIPaddress)) {
					notify($ERRORS{'OK'}, 0, "dynamic address collected $assignedIPaddress -- updated computer table");
					insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "SUCCESS collected dynamicDHCP address");
				}
				else {
					notify($ERRORS{'OK'}, 0, "failed to update dynamic address $assignedIPaddress for$computer_id $computer_node_name ");
					insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "FAILED to update dynamicDHCP address failing reservation");
					return 0;
				}
			} ## end if ($assignedIPaddress)
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not fetch dynamic address from $computer_node_name $image_name");
				insertloadlog($reservation_id, $computer_id, "dynamicDHCPaddress", "FAILED to collected dynamicDHCP address failing reservation");
				return 0;
			}
		} ## end if ($IPCONFIGURATION eq "dynamicDHCP")
		elsif ($IPCONFIGURATION eq "static") {
			insertloadlog($reservation_id, $computer_id, "info", "setting staticIPaddress");

			if (setstaticaddress($computer_node_name, $image_os_name, $computer_ip_address, $image_os_type)) {
				notify($ERRORS{'DEBUG'}, 0, "set static address on $computer_ip_address $computer_node_name ");
				insertloadlog($reservation_id, $computer_id, "staticIPaddress", "SUCCESS set static IP address on public interface");
			}
			else {
				insertloadlog($reservation_id, $computer_id, "staticIPaddress", "failed to set static IP address on public interface");
				return 0;
			}
		} ## end elsif ($IPCONFIGURATION eq "static")  [ if ($IPCONFIGURATION eq "dynamicDHCP")
	} ## end if ($IPCONFIGURATION ne "manualDHCP")

	# Perform post load tasks

	# Windows specific routines
	if ($self->os->can('post_load')) {
		# If post-load has been implemented by the OS module, don't perform these tasks here
		# new.pm calls the Windows module's post_load() subroutine to perform the same tasks as below
		notify($ERRORS{'OK'}, 0, "post_load() has been implemented by the OS module, skipping these tasks in xCAT.pm, returning 1");
		return 1;
	}
	elsif ($image_os_name =~ /winxp|wxp|win2003|winvista/) {

		insertloadlog($reservation_id, $computer_id, "info", "randomizing system level passwords");

		#change passwords for root and administrator account
		#skip changing root password for imageprep loads
		if (changewindowspasswd($computer_node_name, "root")) {
			notify($ERRORS{'OK'}, 0, "Successfully changed password, account $computer_node_name,root");
		}

		if (changewindowspasswd($computer_node_name, "administrator")) {
			notify($ERRORS{'OK'}, 0, "Successfully changed password, account $computer_node_name,administrator");
		}

		#disable remote desktop port
		if (remotedesktopport($computer_node_name, "DISABLE")) {
			notify($ERRORS{'OK'}, 0, "remote desktop disabled on $computer_node_name");
		}
		else {
			notify($ERRORS{'OK'}, 0, "remote desktop not disable on $computer_node_name");
		}

		#due to sysprep sshd is set to manual start
		if (_set_sshd_startmode($computer_node_name, "auto")) {
			notify($ERRORS{'OK'}, 0, "successfully set sshd service on $computer_node_name to start auto");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set sshd service on $computer_node_name to start auto");
		}

		#check for root logged in on console and then logoff
		notify($ERRORS{'OK'}, 0, "checking for any console users $computer_node_name");

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

		#reboot the box  based on options
		if ($imagemeta_postoption =~ /reboot/i) {
			my $rebooted          = 1;
			my $reboot_wait_count = 0;
			my @retarray;
			while ($rebooted) {
				if ($reboot_wait_count > 55) {
					notify($ERRORS{'CRITICAL'}, 0, "waited $reboot_wait_count on reboot after auto_create_image on $computer_node_name");
					$retarray[1] = "waited $reboot_wait_count on reboot after netdom on $computer_node_name";
					return @retarray;
				}
				notify($ERRORS{'OK'}, 0, "$computer_node_name not completed reboot sleeping for 25");
				sleep 25;
				if (_pping($computer_node_name)) {

					#it pingable check if sshd is open
					notify($ERRORS{'OK'}, 0, "$computer_node_name is pingable, checking sshd port");
					my $sshd = _sshd_status($computer_node_name, $image_name, $image_os_type);
					if ($sshd =~ /on/) {
						$rebooted = 0;
						notify($ERRORS{'OK'}, 0, "$computer_node_name sshd is open");
					}
					else {
						notify($ERRORS{'OK'}, 0, "$computer_node_name sshd NOT open yet,sleep 5");
						sleep 5;
					}
				}    #_pping
				$reboot_wait_count++;

			}    #while
		}    #reboot

		#win2003 only - need to set private adapter to static without a gateway
		# win2003 and probably vista zero out one gateway and we only need a gateway on the public adapter
		# so we need to remove the one on the private side
		# downside - we need to reset it to dhcp before making an image.....
		if ($image_os_name =~ /^(win2003)/) {
			insertloadlog($reservation_id, $computer_id, "info", "detected OS which requires network gateway modification");
			notify($ERRORS{'OK'}, 0, "detected win2003 OS, proceeding to change private adapter to static from dhcp on  $computer_node_name");
			my %ip;
			my $myadapter;
			my @ipconfig = run_ssh_command($computer_node_name, $IDENTITY_wxp, "ipconfig -all", "root");

			# build hash of needed info and set the correct private adapter.
			foreach my $a (@{$ipconfig[1]}) {
				$myadapter = $1 if ($a =~ /Ethernet adapter (.*):/);
				$ip{$myadapter}{"private"} = 1
				  if ($a =~ /IP Address([\s.]*): $privateIP/);
				$ip{$myadapter}{"subnetmask"} = $2
				  if ($a =~ /Subnet Mask([\s.]*): ([.0-9]*)/);
			}

			my $privateadapter;
			my $subnetmask;

			foreach my $key (keys %ip) {
				if (defined($ip{$key}{private})) {
					if ($ip{$key}{private}) {
						$privateadapter = "\"$key\"";
						$subnetmask     = $ip{$key}{subnetmask};
					}
				}
			}

			notify($ERRORS{'OK'}, 0, "attempted to convert private adapter on $computer_node_name to static with no gateway");

			#not using run_ssh_command here
			if (open(NETSH, "/usr/bin/ssh -x -i $IDENTITY_wxp $computer_node_name \"netsh interface ip set address name=\\\"$privateadapter\\\" source=static addr=$privateIP mask=$subnetmask\" & 2>&1 |")) {

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
			} ## end if (open(NETSH, "/usr/bin/ssh -x -i $IDENTITY_wxp $computer_node_name \"netsh interface ip set address name=\\\"$privateadapter\\\" source=static addr=$privateIP mask=$subnetmask\" & 2>&1 |"...

			#make sure it came back
			if (_sshd_status($computer_node_name, $image_name, $image_os_type)) {
				notify($ERRORS{'OK'}, 0, "successful $computer_node_name is accessible after static assignment");
				insertloadlog($reservation_id, $computer_id, "info", "SUCCESS network gateway modification successful");
			}
			else {

			}

			#disable NetBios
			notify($ERRORS{'OK'}, 0, "attempted to convert private adapter on $computer_node_name to static with no gateway");
			my $path1 = "$TOOLS/disablenetbios.vbs";
			my $path2 = "$computer_node_name:disablenetbios.vbs";
			if (run_scp_command($path1, $path2, $IDENTITY_wxp)) {
				notify($ERRORS{'DEBUG'}, 0, "copied $path1 to $path2");
				my @DNBIOS = run_ssh_command($computer_node_name, $IDENTITY_wxp, "cscript.exe //Nologo disablenetbios.vbs", "root");
				foreach my $l (@{$DNBIOS[1]}) {
					if ($l =~ /denied|socket/) {
						notify($ERRORS{'WARNING'}, 0, "failed to disablenetbios.vbs @{ $DNBIOS[1] }");
					}
				}

			} ## end if (run_scp_command($path1, $path2, $IDENTITY_wxp...
			else {
				notify($ERRORS{'WARNING'}, 0, "run_scp_command failed to copy  $path1 to $path2");
			}

		} ## end if ($image_os_name =~ /^(win2003)/)
	} ## end elsif ($image_os_name =~ /winxp|wxp|win2003|winvista/) [ if ($self->os->can('post_load'))

	# Linux post-load tasks
	elsif ($image_os_type =~ /linux/i) {

		#linux specfic routines
		#FIXME move to generic post options on per image basis
		if ($image_os_name =~ /^(esx[0-9]*)/) {

			#esx specific post
			my $cmdstring = "/usr/sbin/esxcfg-vswitch -a vSwitch1;/usr/sbin/esxcfg-vswitch -L vmnic1 vSwitch1;/usr/sbin/esxcfg-vswitch -A \"Virtual Machine Public Network\" vSwitch1";

			my @sshd = run_ssh_command($computer_node_name, $IDENTITY_bladerhel, $cmdstring, "root");
			foreach my $l (@{$sshd[1]}) {

				#any response is a potential  problem
				notify($ERRORS{'DEBUG'}, 0, "esxcfg-vswitch output: $l");
			}

			#restart mgmt-vmware
			sleep(8);    # sleep briefly before attemping to restart
			             # restart needs to include "&" for some reason it doesn't return but completes - dunno?
			@sshd = run_ssh_command($computer_node_name, $IDENTITY_bladerhel, "/etc/init.d/mgmt-vmware restart &", "root");
			foreach my $l (@sshd) {
				if ($l =~ /failed/i) {
					notify($ERRORS{'WARNING'}, 0, "failed to restart mgmt-vmware @sshd");
					return 0;
				}
			}
		} ## end if ($image_os_name =~ /^(esx[0-9]*)/)
		                #FIXME - could be an issue for esx servers
		if (changelinuxpassword($computer_node_name, "root")) {
			notify($ERRORS{'OK'}, 0, "successfully changed root password on $computer_node_name");

#insertloadlog($reservation_id, $computer_id, "info", "SUCCESS randomized roots password");
		}
		else {
			notify($ERRORS{'OK'}, 0, "failed to edit root password on $computer_node_name");
		}

		#disable ext_sshd
		my @stopsshd = run_ssh_command($computer_node_name, $IDENTITY_bladerhel, "/etc/init.d/ext_sshd stop", "root");
		foreach my $l (@{$stopsshd[1]}) {
			if ($l =~ /Stopping ext_sshd/) {
				notify($ERRORS{'OK'}, 0, "ext sshd stopped on $computer_node_name");
				last;
			}
		}

		#if an image, clear wtmp and krb token files
		# FIXME - move to createimage
		if ($image_os_type =~ /linux/i) {
			my @cleartmp = run_ssh_command($computer_node_name, $IDENTITY_bladerhel, "/usr/sbin/tmpwatch -f 0 /tmp; /bin/cp /dev/null /var/log/wtmp", "root");
			foreach my $l (@{$cleartmp[1]}) {
				notify($ERRORS{'DEBUG'}, 0, "output from cleartmp post load $computer_node_name $l");
			}
		}

		# clear external_sshd file of any AllowUsers string
		my $path1 = "$computer_node_name:/etc/ssh/external_sshd_config";
		my $path2 = "/tmp/$computer_node_name.sshd";
		if (run_scp_command($path1, $path2, $IDENTITY_bladerhel)) {
			notify($ERRORS{'DEBUG'}, 0, "scp success retrieved $path1");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve $path1");
		}
		#remove from sshd
		if (open(SSHDCFG, "/tmp/$computer_node_name.sshd")) {
			@file = <SSHDCFG>;
			close SSHDCFG;
			foreach my $l (@file) {
				$l = "" if ($l =~ /AllowUsers/);
			}
			if (open(SCP, ">/tmp/$computer_node_name.sshd")) {
				print SCP @file;
				close SCP;
			}
			undef $path1;
			undef $path2;
			$path1 = "/tmp/$computer_node_name.sshd";
			$path2 = "$computer_node_name:/etc/ssh/external_sshd_config";
			if (run_scp_command($path1, $path2, $IDENTITY_bladerhel)) {
				notify($ERRORS{'DEBUG'}, 0, "scp success copied $path1 to $path2");
				unlink $path1;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to copy $path1 to $path2");
			}
		} ## end if (open(SSHDCFG, "/tmp/$computer_node_name.sshd"...


	} ## end elsif ($image_os_type =~ /linux/i)  [ if ($self->os->can('post_load'))

	return 1;
} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  :
 Returns     : 1 if successful, 0 if failed
 Description :

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get required data
	my $image_name          = $self->data->get_image_name();
	my $computer_short_name = $self->data->get_computer_short_name();
	my $computer_node_name  = $self->data->get_computer_node_name();

	# Print some preliminary information
	notify($ERRORS{'OK'}, 0, "xCAT capture beginning: image=$image_name, computer=$computer_short_name");

	# Create currentimage.txt on the node containing information about the new image revision
	if (write_currentimage_txt($self->data)) {
		notify($ERRORS{'OK'}, 0, "currentimage.txt updated on $computer_short_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update currentimage.txt on $computer_short_name");
	}

	# Check if pre_capture() subroutine has been implemented by the OS module
	if ($self->os->can("pre_capture")) {
		# Call OS pre_capture() - it should perform all OS steps necessary to capture an image
		# pre_capture() should shut down the computer when it is done
		notify($ERRORS{'OK'}, 0, "calling OS module's pre_capture() subroutine");
		if (!$self->os->pre_capture({end_state => 'off'})) {
			notify($ERRORS{'WARNING'}, 0, "OS module pre_capture() failed");
			return 0;
		}

		# Get the power status, make sure computer is off
		my $power_status = $self->power_status();
		notify($ERRORS{'DEBUG'}, 0, "retrieved power status: $power_status");
		if ($power_status eq 'off') {
			notify($ERRORS{'OK'}, 0, "verified $computer_node_name power is off");
		}
		elsif ($power_status eq 'on') {
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name power is still on, turning computer off");

			# Attempt to power off computer
			if ($self->power_off()) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name was powered off");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to power off $computer_node_name");
				return 0;
			}
		} ## end elsif ($power_status eq 'on')  [ if ($power_status eq 'off')
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to determine power status of $computer_node_name");
			return 0;
		}
	} ## end if ($self->os->can("pre_capture"))
	elsif ($self->os->can("capture_prepare")) {
		notify($ERRORS{'OK'}, 0, "calling OS module's capture_prepare() subroutine");
		if (!$self->os->capture_prepare()) {
			notify($ERRORS{'WARNING'}, 0, "OS module capture_prepare() failed");
			$self->image_creation_failed();
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "OS module does not have either a pre_capture() or capture_prepare() subroutine");
		$self->image_creation_failed();
	}


	# Create the tmpl file for the image
	if ($self->_create_template()) {
		notify($ERRORS{'OK'}, 0, "created .tmpl file for $image_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create .tmpl file for $image_name");
		return 0;
	}

	# Edit the nodetype.tab file to set the node with the new image name
	if ($self->_edit_nodetype($computer_node_name, $image_name)) {
		notify($ERRORS{'OK'}, 0, "nodetype modified, node $computer_node_name, image name $image_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "could not edit nodetype, node $computer_node_name, image name $image_name");
		return 0;
	}

	# Call xCAT's 'nodeset <nodename> image', configures xCAT to save image on next reboot
	if (_nodeset_option($computer_node_name, "image")) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name set to capture image on next reboot");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set $computer_node_name to capture image on next reboot");
		return 0;
	}


	# Check if pre_capture() subroutine has been implemented by the OS module
	# If so, all that needs to happen is for the computer to be powered on
	if ($self->os->can("pre_capture")) {
		# Turn the computer on
		if ($self->power_on()) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name was powered on");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to turn computer on before monitoring image capture");
			return 0;
		}
	} ## end if ($self->os->can("pre_capture"))
	# If capture_start() is implemented, call it, it will initiate a reboot
	elsif ($self->os->can("capture_start")) {
		notify($ERRORS{'OK'}, 0, "calling OS module's capture_start() subroutine");
		if (!$self->os->capture_start()) {
			notify($ERRORS{'WARNING'}, 0, "OS module capture_start() failed");
			$self->image_creation_failed();
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "OS module does not have either a pre_capture() or capture_start() subroutine");
		$self->image_creation_failed();
	}


	# Monitor the image capture
	if ($self->capture_monitor()) {
		notify($ERRORS{'OK'}, 0, "image capture monitoring is complete");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "problem occurred while monitoring image capture");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "image was successfully captured, returning 1");
	return 1;
} ## end sub capture

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_monitor

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_monitor {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get the required data
	my $computer_node_name = $self->data->get_computer_node_name();
	my $image_name         = $self->data->get_image_name();

	# Get the image repository path
	my $image_repository_path = $self->_get_image_repository_path();
	if (!$image_repository_path) {
		notify($ERRORS{'CRITICAL'}, 0, "xCAT image repository information could not be determined");
		return 0;
	}

	# Wait for node to reboot
	notify($ERRORS{'OK'}, 0, "sleeping for 120 seconds before beginning to monitor image copy process");
	sleep 120;

	# Set variables to control how may attempts are made to wait for capture to finish
	my $capture_loop_attempts = 40;
	my $capture_loop_wait     = 30;

	# Figure out and print how long will wait before timing out
	my $maximum_wait_minutes = ($capture_loop_attempts * $capture_loop_wait) / 60;
	notify($ERRORS{'OK'}, 0, "beginning to wait for image capture to complete, maximum wait time: $maximum_wait_minutes minutes");

	my $image_size = 0;
	my $nodeset_status;
	CAPTURE_LOOP: for (my $capture_loop_count = 0; $capture_loop_count < $capture_loop_attempts; $capture_loop_count++) {
		notify($ERRORS{'OK'}, 0, "image copy not complete, sleeping for $capture_loop_wait seconds");
		if ($capture_loop_attempts > 1) {
			notify($ERRORS{'OK'}, 0, "attempt $capture_loop_count/$capture_loop_attempts: image copy not complete, sleeping for $capture_loop_wait seconds");
		}
		sleep $capture_loop_wait;

		# Get the nodeset status for the node being captured
		$nodeset_status = _nodeset_option($computer_node_name, "stat");
		notify($ERRORS{'DEBUG'}, 0, "nodeset status for $computer_node_name: $nodeset_status");

		# nodeset stat will return 'boot' when image capture (Partimage) is complete
		if ($nodeset_status eq "boot") {
			last CAPTURE_LOOP;
		}

		# Check the image size to see if it's growing
		notify($ERRORS{'OK'}, 0, "checking size of $image_name");
		my $current_image_size = $self->get_image_size($image_name);

		# Check if image size is larger than the last time it was checked
		if ($current_image_size > $image_size) {
			notify($ERRORS{'OK'}, 0, "image size has increased: $image_size -> $current_image_size, still copying");
			$image_size = $current_image_size;
			#reset capture_loop_count
			$capture_loop_count = 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "image size is the same: $image_size=$current_image_size, copy may be complete");
		}
	} ## end for (my $capture_loop_count = 0; $capture_loop_count...

	# Exiting waiting loop, nodeset status should be boot if successful
	if ($nodeset_status eq "boot") {
		# Nodeset 'boot' flag has been set, image copy process is complete
		notify($ERRORS{'OK'}, 0, "image copy complete, nodeset status was set to 'boot' for $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "image copy timed out, waited $maximum_wait_minutes minutes, nodeset status for $computer_node_name never changed to boot: $nodeset_status");
		return 0;
	}

	# Create mbr and sfdisk files
	if (open(LS, "/bin/ls -1s $image_repository_path |")) {
		my @LS = <LS>;
		close(LS);
		foreach my $l (@LS) {
			if ($l =~ /$image_name-hda/) {

				#create hda.mbr and hda.sfdisk
				if (open(CP, "/bin/cp $image_repository_path/$image_name-hda.mbr $image_repository_path/$image_name-sda.mbr |")) {
					close(CP);
					notify($ERRORS{'OK'}, 0, "copied $image_name-hda.mbr to $image_repository_path/$image_name-sda.mbr");

					#create sfdisk modify hardrive type
					if (open(CP, "/bin/cp $image_repository_path/$image_name-hda.sfdisk $image_repository_path/$image_name-sda.sfdisk |")) {
						close(CP);
						notify($ERRORS{'OK'}, 0, "copied $image_name-hda.sfdisk to $image_repository_path/$image_name-sda.sfdisk");

						#read in file
						if (open(FILE, "$image_repository_path/$image_name-sda.sfdisk")) {
							my @lines = <FILE>;
							close(FILE);
							foreach my $l (@lines) {
								if ($l =~ s/hda/sda/g) {

									#editing file
								}
							}

							#print array to file
							if (open(OUTFILE, ">$image_repository_path/$image_name-sda.sfdisk")) {
								print OUTFILE @lines;
								close(OUTFILE);
								notify($ERRORS{'OK'}, 0, "modified drivetype of $image_name-sda.sfdisk");
							}
						} ## end if (open(FILE, "$image_repository_path/$image_name-sda.sfdisk"...
						else {
							notify($ERRORS{'CRITICAL'}, 0, "could not open $image_repository_path/$image_name-sda.mbr for editing $!");
						}
					}    # Close if copy hda.sfdisk command
					else {
						notify($ERRORS{'CRITICAL'}, 0, "could not copy $image_name-hda.sfdisk to $image_repository_path/$image_name-sda.sfdisk $!");
					}
				}    # Close if copy mbr file command
				else {
					notify($ERRORS{'CRITICAL'}, 0, "could not copy $image_name-hda.mbr to $image_repository_path/$image_name-sda.mbr $!");
				}
			}    # Close if imagename-hda

			elsif ($l =~ /$image_name-sda/) {

				#create sda.mbr and sda.sfdisk
				if (open(CP, "/bin/cp $image_repository_path/$image_name-sda.mbr $image_repository_path/$image_name-hda.mbr |")) {
					close(CP);
					notify($ERRORS{'OK'}, 0, "copied $image_name-sda.mbr to $image_repository_path/$image_name-hda.mbr");

					#create sfdisk
					if (open(CP, "/bin/cp $image_repository_path/$image_name-sda.sfdisk $image_repository_path/$image_name-hda.sfdisk |")) {
						close(CP);
						notify($ERRORS{'OK'}, 0, "copied $image_name-sda.sfdisk to $image_repository_path/$image_name-hda.sfdisk");

						#read in file
						if (open(FILE, "$image_repository_path/$image_name-hda.sfdisk")) {
							my @lines = <FILE>;
							close(FILE);
							foreach my $l (@lines) {
								if ($l =~ s/sda/hda/g) {

									#editing file
								}
							}

							#print array to file
							if (open(OUTFILE, ">$image_repository_path/$image_name-hda.sfdisk")) {
								print OUTFILE @lines;
								close(OUTFILE);
								notify($ERRORS{'OK'}, 0, "modified drivetype of $image_name-hda.sfdisk");
							}
						} ## end if (open(FILE, "$image_repository_path/$image_name-hda.sfdisk"...
						else {
							notify($ERRORS{'CRITICAL'}, 0, "could not open $image_repository_path/$image_name-hda.sfdisk for editing $!");
						}
					} ## end if (open(CP, "/bin/cp $image_repository_path/$image_name-sda.sfdisk $image_repository_path/$image_name-hda.sfdisk |"...
					else {
						notify($ERRORS{'OK'}, 0, "could not copy $image_repository_path/$image_name-sda.sfdisk to $image_repository_path/$image_name-hda.sfdisk $!");
					}
				} ## end if (open(CP, "/bin/cp $image_repository_path/$image_name-sda.mbr $image_repository_path/$image_name-hda.mbr |"...
				else {
					notify($ERRORS{'OK'}, 0, "could not copy $image_repository_path/$image_name-sda.mbr to $image_repository_path/$image_name-hda.mbr $!");
				}
			}    # Close if image_name-sda

		}    # Close foreach line returned from the ls imagerepository command
	}    # Close if ls imagerepository

	# Set file premissions on image files to 644
	# Allows other management nodes to retrieve the image if neccessary
	if (open(CHMOD, "/bin/chmod -R 644 $image_repository_path/$image_name\* 2>&1 |")) {
		close(CHMOD);
		notify($ERRORS{'DEBUG'}, 0, "recursive update file permissions 644 on $image_repository_path/$image_name");
	}

	# Image capture complete, return 1
	notify($ERRORS{'OK'}, 0, "image capture complete");
	return 1;

} ## end sub capture_monitor

#/////////////////////////////////////////////////////////////////////////////

=head2  _edit_template

 Parameters  : imagename,drivetype
 Returns     : 0 failed or 1 success
 Description : general routine to edit /opt/xcat/install/image/x86/imagename.tmpl
				  used in imaging process

=cut

sub _edit_template {
	my ($imagename, $drivetype) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'CRITCAL'}, 0, "drivetype is not defined")
	  if (!(defined($drivetype)));
	notify($ERRORS{'CRITCAL'}, 0, "imagename is not defined")
	  if (!(defined($imagename)));

	my $template = "$XCAT_ROOT/install/image/x86/$imagename.tmpl";
	my @lines;
	if (open(FILE, $template)) {
		@lines = <FILE>;
		close FILE;
		my $line;
		for $line (@lines) {
			if ($line =~ /^export DISKS=/) {
				$line = "export DISKS=\"$drivetype\"\n";
				last;
			}
		}

		#dump back to template file
		if (open(FILE, ">$template")) {
			print FILE @lines;
			close FILE;
			return 1;
		}
		else {

			# could not open nodetype file for editing
			notify($ERRORS{'CRITICAL'}, 0, "could not open $template for writing\nerror message: $!");
			return 0;
		}
	} ## end if (open(FILE, $template))
	else {

		# could not open nodetype file for editing
		notify($ERRORS{'CRITICAL'}, 0, "could not open $template for reading\nerror message: $!");
		return 0;
	}
} ## end sub _edit_template

#/////////////////////////////////////////////////////////////////////////////

=head2  _edit_nodetype

 Parameters  : node, imagename, osname
 Returns     : 0 failed or 1 success
 Description : xCAT specific edits xcat's nodetype file with requested image name

=cut

sub _edit_nodetype {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Use arguments for computer and image if they were passed
	my $computer_node_name = shift;
	my $image_name         = shift;

	# Use the new image name if it is set
	$image_name = $self->data->get_image_name() if !$image_name;

	# Get the rest of the variables
	$computer_node_name = $self->data->get_computer_node_name() if !$computer_node_name;
	my $image_os_name         = $self->data->get_image_os_name();
	my $image_architecture    = $self->data->get_image_architecture();
	my $image_os_source_path  = $self->data->get_image_os_source_path();
	my $image_repository_path = $self->_get_image_repository_path();
	
	# Fix for Linux images using linux_image repository path
	if ($image_os_source_path eq 'image' && $image_repository_path =~ /linux_image/) {
		$image_os_source_path = 'linux_image';
		notify($ERRORS{'DEBUG'}, 0, "fixed Linux image path: image --> linux_image");
	}

	# Check to make sure the variables are populated
	if (!$computer_node_name) {
		notify($ERRORS{'CRITICAL'}, 0, "computer node name is not defined");
		return 0;
	}
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image name is not defined");
		return 0;
	}
	if (!$image_os_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image OS name is not defined");
		return 0;
	}
	if (!$image_architecture) {
		notify($ERRORS{'CRITICAL'}, 0, "image architecture is not defined");
		return 0;
	}
	if (!$image_os_source_path) {
		notify($ERRORS{'CRITICAL'}, 0, "image OS source path is not defined");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "$computer_node_name, image=$image_name, os=$image_os_name, arch=$image_architecture, path=$image_os_source_path");

	# Assemble the nodetype.tab and lock file paths
	my $nodetype_file_path = "$XCAT_ROOT/etc/nodetype.tab";
	my $lock_file_path     = "$nodetype_file_path.lockfile";

	# Open the lock file
	if (sysopen(LOCKFILE, $lock_file_path, O_RDONLY | O_CREAT)) {
		notify($ERRORS{'DEBUG'}, 0, "opened $lock_file_path");

		# Set exclusive lock on lock file
		if (flock(LOCKFILE, LOCK_EX)) {
			notify($ERRORS{'DEBUG'}, 0, "set exclusive lock on $lock_file_path");

			if (open(NODETYPE, $nodetype_file_path)) {    #read file
				notify($ERRORS{'DEBUG'}, 0, "opened $nodetype_file_path");

				# Get the nodetype.tab lines and close the file
				my @nodetype_lines = <NODETYPE>;
				notify($ERRORS{'DEBUG'}, 0, "lines found in nodetype.tab: " . scalar @nodetype_lines);

				# Close the nodetype.tab file
				close(NODETYPE);
				notify($ERRORS{'DEBUG'}, 0, "closed $nodetype_file_path");

				# Loop through the nodetype.tab lines
				for my $line (@nodetype_lines) {

					# Skip over non-matching lines
					next if ($line !~ /^$computer_node_name\s+([,\w]*)/);
					notify($ERRORS{'OK'}, 0, "matching line found: $line");

					# Replace line matching $computer_node_name
					$line = "$computer_node_name\t\t$image_os_source_path,$image_architecture,$image_name\n";
					notify($ERRORS{'OK'}, 0, "line modified: $line");
				} ## end for my $line (@nodetype_lines)

				# Dump modified array to nodetype.tab file
				if (open(NODETYPE, ">$nodetype_file_path")) {
					notify($ERRORS{'OK'}, 0, "nodetype.tab opened");
					print NODETYPE @nodetype_lines;
					notify($ERRORS{'OK'}, 0, "nodetype.tab contents replaced");
					close(NODETYPE);
					notify($ERRORS{'OK'}, 0, "nodetype.tab saved");
					close(LOCKFILE);
					notify($ERRORS{'DEBUG'}, 0, "lock file closed");
					return 1;
				} ## end if (open(NODETYPE, ">$nodetype_file_path"))
				else {

					# Could not open nodetype.tab file for editing
					notify($ERRORS{'CRITICAL'}, 0, "could not open file for writing: $nodetype_file_path, $!");
					close(LOCKFILE);
					notify($ERRORS{'DEBUG'}, 0, "lock file closed");
					return 0;
				}
			} ## end if (open(NODETYPE, $nodetype_file_path))
			else {

				# could not open nodetype file for reading
				notify($ERRORS{'CRITICAL'}, 0, "could not open file for reading: $nodetype_file_path, $!");
				close(LOCKFILE);
				notify($ERRORS{'DEBUG'}, 0, "lock file closed");
				return 0;
			}
		} ## end if (flock(LOCKFILE, LOCK_EX))
		else {

			# Could not open lock
			notify($ERRORS{'CRITICAL'}, 0, "unable to get exclusive lock on $lock_file_path to edit nodetype.tab, $!");
			close(LOCKFILE);
			notify($ERRORS{'DEBUG'}, 0, "lock file closed");
			return 0;
		}
	} ## end if (sysopen(LOCKFILE, $lock_file_path, O_RDONLY...

	else {

		# Could not open lock file
		notify($ERRORS{'CRITICAL'}, 0, "unable to open $lock_file_path to edit nodetype.tab, $!");
		return 0;
	}

} ## end sub _edit_nodetype

#/////////////////////////////////////////////////////////////////////////////

=head2 _pping

 Parameters  : $node
 Returns     : 1 or 0
 Description : using xcat pping cmd to ping blade, xcat specific

=cut

sub _pping {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "_pping: node is not defined")
	  if (!(defined($node)));
	if (open(PPING, "$XCAT_ROOT/bin/pping $node 2>&1 |")) {
		my @file = <PPING>;
		close(PPING);
		foreach my $l (@file) {
			chomp $l;
			notify($ERRORS{'OK'}, 0, "pinging $l");
			if ($l =~ /noping/) {
				return 0;
			}
			if ($l =~ /$node: ping/) {
				return 1;
			}
		} ## end foreach my $l (@file)
		return 1;
	} ## end if (open(PPING, "$XCAT_ROOT/bin/pping $node 2>&1 |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "could not execute $XCAT_ROOT/bin/pping $node");
		return 0;
	}
} ## end sub _pping

#/////////////////////////////////////////////////////////////////////////////

=head2 _nodeset

 Parameters  : $node
 Returns     : xcat state of node or 0
 Description : using xcat nodeset cmd to retrieve state of blade, xcat specific

=cut

sub _nodeset {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "_nodeset: node is not defined")
	  if (!(defined($node)));
	return 0 if (!(defined($node)));

	my ($blah, $case);
	my @file;
	my $l;
	if (open(NODESET, "$XCAT_ROOT/bin/nodeset $node stat |")) {

		#notify($ERRORS{'OK'},0,"executing $XCAT_ROOT/bin/nodeset $node stat ");
		@file = <NODESET>;
		close NODESET;
		foreach $l (@file) {
			chomp($l);
			($blah, $case) = split(/:\s/, $l);
		}
		if ($case) {

			#notify($ERRORS{'OK'},0,"$node in $case state ");
			return $case;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "case for $node is empty");
			return 0;
		}
	} ## end if (open(NODESET, "$XCAT_ROOT/bin/nodeset $node stat |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute $XCAT_ROOT/bin/nodeset $node stat");
		return 0;
	}
} ## end sub _nodeset

#/////////////////////////////////////////////////////////////////////////////

=head2 _nodeset

 Parameters  : $node $option
 Returns     : xcat state of node or 0
 Description : using xcat nodeset cmd to use the input option of blade, xcat specific

=cut

sub _nodeset_option {
	my ($node, $option) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "_nodeset_option: node is not defined")
	  if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "_nodeset_option: option is not defined")
	  if (!(defined($option)));
	my ($blah, $case);
	my @file;
	my $l;
	if (open(NODESET, "$XCAT_ROOT/bin/nodeset $node $option |")) {

		#notify($ERRORS{'OK'},0,"executing $XCAT_ROOT/bin/nodeset $node $option");
		@file = <NODESET>;
		close NODESET;
		foreach $l (@file) {
			chomp($l);
			($blah, $case) = split(/:\s/, $l);
		}
		if ($case) {
			notify($ERRORS{'OK'}, 0, "$node in $case state ");
			return $case;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "case for $node is empty");
			return 0;
		}
	} ## end if (open(NODESET, "$XCAT_ROOT/bin/nodeset $node $option |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute $XCAT_ROOT/bin/nodeset $node $option");
		return 0;
	}

} ## end sub _nodeset_option

#/////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : $computer_node_name (optional)
 Returns     : 
 Description : 

=cut

sub power_reset {
	my $argument_1 = shift;
	my $argument_2 = shift;

	my $computer_node_name;

	# Check if subroutine was called as an object method
	if (ref($argument_1) =~ /xcat/i) {
		my $self = $argument_1;

		$computer_node_name = $argument_2;

		# Check if computer argument was specified
		# If not, use computer node name in the data object
		if (!$computer_node_name) {
			$computer_node_name = $self->data->get_computer_node_name();
		}
	} ## end if (ref($argument_1) =~ /xcat/i)
	else {
		# Subroutine was not called as an object method, 2 arguments must be specified
		$computer_node_name = $argument_1;
	}

	# Check if computer was determined
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer could not be determined from arguments");
		return;
	}

	# Turn computer off
	my $off_attempts = 0;
	while (!power_off($computer_node_name)) {
		$off_attempts++;

		if ($off_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name off, rpower status not is off after 3 attempts");
			return;
		}

		sleep 2;
	} ## end while (!power_off($computer_node_name))

	# Turn computer on
	my $on_attempts = 0;
	while (!power_on($computer_node_name)) {
		$on_attempts++;

		if ($on_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name on, rpower status not is on after 3 attempts");
			return;
		}

		sleep 2;
	} ## end while (!power_on($computer_node_name))

	notify($ERRORS{'OK'}, 0, "successfully reset power on $computer_node_name");
	return 1;
} ## end sub power_reset

#/////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : $computer_node_name (optional)
 Returns     : 
 Description : 

=cut

sub power_on {
	my $argument_1 = shift;
	my $argument_2 = shift;

	my $computer_node_name;

	# Check if subroutine was called as an object method
	if (ref($argument_1) =~ /xcat/i) {
		my $self = $argument_1;

		$computer_node_name = $argument_2;

		# Check if computer argument was specified
		# If not, use computer node name in the data object
		if (!$computer_node_name) {
			$computer_node_name = $self->data->get_computer_node_name();
		}
	} ## end if (ref($argument_1) =~ /xcat/i)
	else {
		# Subroutine was not called as an object method, 2 arguments must be specified
		$computer_node_name = $argument_1;
	}

	# Check if computer was determined
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer could not be determined from arguments");
		return;
	}

	# Turn computer on
	my $on_attempts  = 0;
	my $power_status = 'unknown';
	while ($power_status !~ /on/) {
		$on_attempts++;

		if ($on_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name on, rpower status not is on after 3 attempts");
			return;
		}

		_rpower($computer_node_name, 'on');
		sleep 2;

		$power_status = power_status($computer_node_name);
	} ## end while ($power_status !~ /on/)

	notify($ERRORS{'OK'}, 0, "successfully powered on $computer_node_name");
	return 1;
} ## end sub power_on

#/////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : $computer_node_name (optional)
 Returns     : 
 Description : 

=cut

sub power_off {
	my $argument_1 = shift;
	my $argument_2 = shift;

	my $computer_node_name;

	# Check if subroutine was called as an object method
	if (ref($argument_1) =~ /xcat/i) {
		my $self = $argument_1;

		$computer_node_name = $argument_2;

		# Check if computer argument was specified
		# If not, use computer node name in the data object
		if (!$computer_node_name) {
			$computer_node_name = $self->data->get_computer_node_name();
		}
	} ## end if (ref($argument_1) =~ /xcat/i)
	else {
		# Subroutine was not called as an object method, 2 arguments must be specified
		$computer_node_name = $argument_1;
	}

	# Check if computer was determined
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer could not be determined from arguments");
		return;
	}

	# Turn computer off
	my $power_status = 'unknown';
	my $off_attempts = 0;
	while ($power_status !~ /off/) {
		$off_attempts++;

		if ($off_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name off, rpower status not is off after 3 attempts");
			return;
		}

		_rpower($computer_node_name, 'off');
		sleep 2;

		$power_status = power_status($computer_node_name);
	} ## end while ($power_status !~ /off/)

	notify($ERRORS{'OK'}, 0, "successfully powered off $computer_node_name");
	return 1;
} ## end sub power_off

#/////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : $computer_node_name (optional)
 Returns     : 
 Description : 

=cut

sub power_status {
	my $argument_1 = shift;
	my $argument_2 = shift;

	my $computer_node_name;

	# Check if subroutine was called as an object method
	if (ref($argument_1) =~ /xcat/i) {
		my $self = $argument_1;

		$computer_node_name = $argument_2;

		# Check if computer argument was specified
		# If not, use computer node name in the data object
		if (!$computer_node_name) {
			$computer_node_name = $self->data->get_computer_node_name();
		}
	} ## end if (ref($argument_1) =~ /xcat/i)
	else {
		# Subroutine was not called as an object method, 2 arguments must be specified
		$computer_node_name = $argument_1;
	}

	# Check if computer was determined
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer could not be determined from arguments");
		return;
	}

	# Call rpower to determine power status
	my $rpower_stat = _rpower($computer_node_name, 'stat');
	notify($ERRORS{'DEBUG'}, 0, "retrieved power status of $computer_node_name: $rpower_stat");

	if (!$rpower_stat) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine power status, rpower subroutine returned $rpower_stat");
		return;
	}
	elsif ($rpower_stat =~ /^(on|off)$/i) {
		return lc($1);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine power status, unexpected output returned from rpower: $rpower_stat");
		return;
	}
} ## end sub power_status

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_on

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is on, 0 otherwise
 Description : 

=cut

sub wait_for_on {
	my $self = shift;
	if (ref($self) !~ /xcat/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Attempt to get the total number of minutes to wait from the arguments
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

	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to turn on, maximum of $total_wait_minutes minutes");

	# Loop until computer is on
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $computer_node_name is not on, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		if ($self->power_status() =~ /on/i) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is on");
			return 1;
		}
	} ## end for (my $attempt = 1; $attempt <= $attempts...

	# Calculate how long this waited
	my $total_wait = ($attempts * $attempt_delay);
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is NOT on after waiting for $total_wait seconds");
	return 0;
} ## end sub wait_for_on

#/////////////////////////////////////////////////////////////////////////////

=head2 wait_for_off

 Parameters  : Maximum number of minutes to wait (optional)
 Returns     : 1 if computer is off, 0 otherwise
 Description : 

=cut

sub wait_for_off {
	my $self = shift;
	if (ref($self) !~ /xcat/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Attempt to get the total number of minutes to wait from the arguments
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

	notify($ERRORS{'OK'}, 0, "waiting for $computer_node_name to turn off, maximum of $total_wait_minutes minutes");

	# Loop until computer is off
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $computer_node_name is not off, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		if ($self->power_status() =~ /off/i) {
			notify($ERRORS{'OK'}, 0, "$computer_node_name is off");
			return 1;
		}
	} ## end for (my $attempt = 1; $attempt <= $attempts...

	# Calculate how long this waited
	my $total_wait = ($attempts * $attempt_delay);
	notify($ERRORS{'WARNING'}, 0, "$computer_node_name is NOT off after waiting for $total_wait seconds");
	return 0;
} ## end sub wait_for_off

#/////////////////////////////////////////////////////////////////////////////

=head2 makesshgkh

 Parameters  : imagename
 Returns     : 0 or 1
 Description : xCAT specific scans node for public ssh key

=cut

sub makesshgkh {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")
	  if (!(defined($node)));
	if (!(defined($node))) {
		return 0;
	}
	if (open(MAKESSHGKH, "$XCAT_ROOT/sbin/makesshgkh $node 2>&1 |")) {
		while (<MAKESSHGKH>) {
			chomp($_);
			if ($_ =~ /Scanning keys/) {

				#notify($ERRORS{'OK'},0,"$_");
			}
			else {

				#possible error
				#notify($ERRORS{'OK'},0,"possible error in $_ ");
			}
		} ## end while (<MAKESSHGKH>)
		close(MAKESSHGKH);
		return 1;
	} ## end if (open(MAKESSHGKH, "$XCAT_ROOT/sbin/makesshgkh $node 2>&1 |"...
	return 0;
} ## end sub makesshgkh

#/////////////////////////////////////////////////////////////////////////////

=head2 _rpower

 Parameters  : $node, $option
 Returns     : 1 connected 0 not connected
 Description : xCAT specific command -  hard power cycle the blade

=cut

sub _rpower {
	my $argument_1 = shift;
	my $argument_2 = shift;
	my $argument_3 = shift;

	my $computer_node_name;
	my $mode;

	# Check if subroutine was called as an object method
	if (ref($argument_1) =~ /xcat/i) {
		my $self = $argument_1;

		# Check if 1 or 2 arguments were specified
		if ($argument_3) {
			$computer_node_name = $argument_2;
			$mode               = $argument_3;
		}
		else {
			$computer_node_name = $self->data->get_computer_node_name();
			$mode               = $argument_2;
		}
	} ## end if (ref($argument_1) =~ /xcat/i)
	else {
		# Subroutine was not called as an object method, 2 arguments must be specified
		$computer_node_name = $argument_1;
		$mode               = $argument_2;
	}

	# Check the arguments
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "rpower was not executed, computer was not specified");
		return;
	}
	if (!$mode) {
		notify($ERRORS{'WARNING'}, 0, "rpower mode was not specified, setting mode to cycle");
		$mode = 'cycle';
	}
	if ($mode !~ /^on|off|stat|state|reset|boot|cycle$/i) {
		notify($ERRORS{'WARNING'}, 0, "rpower was not executed, mode is not valid: $mode");
		return;
	}

	# If one of the reset modes was specified, call power_reset()
	# It attempts to turn off then on, and makes sure attempts were successful
	if ($mode =~ /^reset|boot|cycle$/i) {
		return power_reset($computer_node_name);
	}

	notify($ERRORS{'DEBUG'}, 0, "attempting to execute rpower for computer: $computer_node_name, mode: $mode");

	# Assemble the rpower command
	my $command = "$XCAT_ROOT/bin/rpower $computer_node_name $mode";

	# Run the command
	my ($exit_status, $output) = run_command($command);

	# rpower options:
	# on           - Turn power on
	# off          - Turn power off
	# stat | state - Return the current power state
	# reset        - Send a hardware reset
	# boot         - If off, then power on. If on, then hard reset. This option is recommended over cycle.
	# cycle        - Power off, then on

	# Typical output:
	# Invalid node is specified (exit status = 0):
	#    [root@managementnode]# rpower vclb2-8x stat
	#    invalid node, group, or range: vclb2-8x
	# Successful off (exit status = 0):
	#    [root@managementnode]# rpower vclb2-8 off
	#    vclb2-8: off
	# Successful reset (exit status = 0):
	#    [root@managementnode test]# rpower vclb2-8 reset
	#    vclb2-8: reset
	# Successful stat (exit status = 0):
	#    [root@managementnode test]# rpower vclb2-8 stat
	#    vclb2-8: on
	# Successful cycle (exit status = 0):
	#	  [root@managementnode test]# rpower vclb2-8 cycle
	#    vclb2-8: off on

	foreach my $output_line (@{$output}) {
		# Check for 'invalid node'
		if ($output_line =~ /invalid node/) {
			notify($ERRORS{'WARNING'}, 0, "rpower reported invalid node: @{$output}");
			return;
		}

		# Check for known 'not in bay' problem
		if ($output_line =~ /not in bay/) {
			if (_fix_rpower($computer_node_name)) {
				return _rpower($computer_node_name, $mode);
			}
		}

		# Check for successful output line
		if ($output_line =~ /$computer_node_name:\s+(.*)/) {
			return $1;
		}
	} ## end foreach my $output_line (@{$output})

	notify($ERRORS{'WARNING'}, 0, "unexpected output returned from rpower: @{$output}");
	return 0;

} ## end sub _rpower

#/////////////////////////////////////////////////////////////////////////////

=head2 _fix_rpower

 Parameters  : nodename
 Returns     : 1(success) or 0(failure)
 Description : due to a bug in a previous firmware version.
               it's belived to be fixed in previous versions

=cut

sub _fix_rpower {
	my $node = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node not set") if (!defined($node));

	# this function kicks the management this is a known xcat bug, the
	# workaround is to run rinv nodename all twice
	my $notfixed = 1;
	my $tries    = 0;
	while ($notfixed) {
		$tries++;
		if ($tries > 10) {
			notify($ERRORS{'CRITICAL'}, 0, "_fix_rpower failed $tries on $node");
			return 0;
		}

		#notify($ERRORS{'OK'},0,"executing $XCAT_ROOT/bin/rinv $node all");
		if (open(RINV, "$XCAT_ROOT/bin/rinv $node all |")) {
			my @rinv = <RINV>;
			my $line;
			close RINV;
			foreach $line (@rinv) {
				next if ($line =~ /HTTP login failed/);    #expected
				if ($line =~ /Machine Type/) {
					notify($ERRORS{'OK'}, 0, "rinv succeded for $node");
					return 1;
				}
			}
		} ## end if (open(RINV, "$XCAT_ROOT/bin/rinv $node all |"...
		else {
			notify($ERRORS{'OK'}, 0, "could not execute $XCAT_ROOT/bin/rinv $node all $!");
		}
	} ## end while ($notfixed)

} ## end sub _fix_rpower

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : [0]: computer node name (optional)
               [1]: log file path (optional)
 Returns     : If called in scalar or boolean context:
                        1: node is down or needs to be reloaded
								0: node is up and does not need to be reloaded
								undefined: error occurred while checking node status

               hashref: reference to hash with keys/values:
					         {status} => <"READY","FAIL">
						   	{ping} => <0,1>
						   	{ssh} => <0,1>
							   {rpower} => <0,1>
								{nodeset} => <"boot", "install", "image", ...>
								{nodetype} => <image name>
								{currentimage} => <image name>
 Description : Checks the status of an xCAT-provisioned machine.  If no
               arguments are supplied, the node and image for the current
					reservation will be used.

=cut

sub node_status {
	my $self = shift;
	my ($computer_node_name, $log);

	my $management_node_os_name = 0;
	my $management_node_keys    = 0;
	my $computer_host_name      = 0;
	my $computer_short_name     = 0;
	my $computer_ip_address     = 0;
	my $image_os_name           = 0;
	my $image_name              = 0;
	my $image_os_type           = 0;

	# Check if subroutine was called as a class method
	if (ref($self) !~ /xcat/i) {

		if (ref($self) eq 'HASH') {
			$log = $self->{logfile};
			notify($ERRORS{'DEBUG'}, $log, "self is a hash reference");

			$computer_node_name      = $self->{computer}->{hostname};
			$management_node_os_name = $self->{managementnode}->{OSNAME};
			$management_node_keys    = $self->{managementnode}->{keys};
			$computer_host_name      = $self->{computer}->{hostname};
			$computer_ip_address     = $self->{computer}->{IPaddress};
			$image_os_name           = $self->{image}->{OS}->{name};
			$image_name              = $self->{imagerevision}->{imagename};
			$image_os_type           = $self->{image}->{OS}->{type};

		} ## end if (ref($self) eq 'HASH')
		# Check if node_status returned an array ref
		elsif (ref($self) eq 'ARRAY') {
			notify($ERRORS{'DEBUG'}, 0, "self is a array reference");
		}

		$log = 0 if !$log;
		$computer_short_name = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);

	} ## end if (ref($self) !~ /xcat/i)
	else {

		# Get the computer name from the DataStructure
		$computer_node_name = $self->data->get_computer_node_name();

		# Check if this was called as a class method, but a node name was also specified as an argument
		my $node_name_argument = shift;
		$computer_node_name  = $node_name_argument if $node_name_argument;
		$computer_host_name  = $self->data->get_computer_host_name();
		$computer_short_name = $self->data->get_computer_short_name();
		$image_name          = $self->data->get_image_name();
		$image_os_type       = $self->data->get_image_os_type();
		$log                 = 0;
	} ## end else [ if (ref($self) !~ /xcat/i)

	# Check the node name variable
	if (!defined($computer_node_name) || !$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "node name could not be determined");
		return;
	}
	notify($ERRORS{'DEBUG'}, $log, "checking status of node: $computer_node_name");
	notify($ERRORS{'DEBUG'}, $log, "computer_short_name= $computer_short_name ");
	notify($ERRORS{'DEBUG'}, $log, "computer_node_name= $computer_node_name ");
	notify($ERRORS{'DEBUG'}, $log, "image_os_name= $image_os_name");
	notify($ERRORS{'DEBUG'}, $log, "management_node_os_name= $management_node_os_name");
	notify($ERRORS{'DEBUG'}, $log, "computer_ip_address= $computer_ip_address");
	notify($ERRORS{'DEBUG'}, $log, "management_node_keys= $management_node_keys");
	notify($ERRORS{'DEBUG'}, $log, "image_name=  $image_name");
	notify($ERRORS{'DEBUG'}, $log, "image_os_type=  $image_os_type");


	# Create a hash to store status components
	my %status;

	# Initialize all hash keys here to make sure they're defined
	$status{status}       = 0;
	$status{nodetype}     = 0;
	$status{currentimage} = 0;
	$status{ping}         = 0;
	$status{rpower}       = 0;
	$status{nodeset}      = 0;
	$status{ssh}          = 0;

	# Check the nodetype.tab file
	notify($ERRORS{'DEBUG'}, $log, "checking the current image listed in nodetype.tab for $computer_short_name");
	my $nodetype_file_path = "$XCAT_ROOT/etc/nodetype.tab";
	if (open(NODETYPE, $nodetype_file_path)) {
		notify($ERRORS{'OK'}, $log, "opened $nodetype_file_path for reading");

		# Get all the lines in nodetype.tab
		my @nodetype_lines = <NODETYPE>;

		# Close the nodetype.tab file
		close NODETYPE;

		# Find the nodetype.tab line for the computer
		# Example line: vcln1-1         image,x86,winxp-base1-v21
		#               vclb2-8         rhas5,x86,rhel5-base587-v0
		my $nodetype_contents = join("\n", @nodetype_lines);
		if ($nodetype_contents =~ /^$computer_short_name\s+(\w+),(\w+),(.+)$/xm, $nodetype_contents) {
			my $nodetype_install_path       = $1;
			my $nodetype_image_architecture = $2;
			my $nodetype_image_name         = $3;

			# Remove any spaces from the beginning and end of the $nodetype_image_name string
			$nodetype_image_name =~ s/^\s+//;
			$nodetype_image_name =~ s/\s+$//;

			notify($ERRORS{'OK'}, $log, "found nodetype.tab line: path=$nodetype_install_path, arch=$nodetype_image_architecture, image=$nodetype_image_name");
			$status{nodetype} = $nodetype_image_name;
		} ## end if ($nodetype_contents =~ /^$computer_short_name\s+(\w+),(\w+),(.+)$/xm...
		else {
			notify($ERRORS{'WARNING'}, $log, "unable to find line in nodetype.tab for computer: $computer_short_name");
			return;
		}
	} ## end if (open(NODETYPE, $nodetype_file_path))
	else {
		notify($ERRORS{'WARNING'}, $log, "could not open $nodetype_file_path for reading");
		return;
	}

	# Check if node is pingable
	notify($ERRORS{'DEBUG'}, $log, "checking if $computer_host_name is pingable");
	if (_pingnode($computer_host_name)) {
		$status{ping} = 1;
		notify($ERRORS{'OK'}, $log, "$computer_host_name is pingable ($status{ping})");
	}
	else {
		$status{ping} = 0;
		notify($ERRORS{'OK'}, $log, "$computer_host_name is not pingable ($status{ping})");
	}

	# Check the rpower status
	notify($ERRORS{'DEBUG'}, $log, "checking $computer_short_name xCAT rpower status");
	my $rpower_status = _rpower($computer_short_name, "stat");
	if ($rpower_status =~ /on/i) {
		$status{rpower} = 1;
	}
	else {
		$status{rpower} = 0;
	}
	notify($ERRORS{'DEBUG'}, $log, "$computer_short_name rpower status: $rpower_status ($status{rpower})");

	# Check the xCAT nodeset status
	notify($ERRORS{'DEBUG'}, $log, "checking $computer_short_name xCAT nodeset status");
	my $nodeset_status = _nodeset($computer_short_name);
	notify($ERRORS{'OK'}, $log, "$computer_short_name nodeset status: $nodeset_status");
	$status{nodeset} = $nodeset_status;

	# Check the sshd status
	notify($ERRORS{'DEBUG'}, $log, "checking if $computer_short_name sshd service is accessible");
	my $sshd_status = _sshd_status($computer_short_name, $status{nodetype}, $image_os_type, $log);

	# If sshd is accessible, perform sshd-dependent checks
	if ($sshd_status =~ /on/) {
		$status{ssh} = 1;
		notify($ERRORS{'DEBUG'}, $log, "$computer_short_name sshd service is accessible, performing dependent checks");

		# Check the currentimage.txt file on the node
		notify($ERRORS{'DEBUG'}, $log, "checking image specified in currentimage.txt file on $computer_short_name");
		if ($status{nodetype} =~ /win|image/) {
			my $status_currentimage = _getcurrentimage($computer_short_name);
			if ($status_currentimage) {
				notify($ERRORS{'OK'}, $log, "$computer_short_name currentimage.txt has: $status_currentimage");
				$status{currentimage} = $status_currentimage;
			}
			else {
				notify($ERRORS{'WARNING'}, $log, "$computer_short_name currentimage.txt could not be checked");
			}
		} ## end if ($status{nodetype} =~ /win|image/)
		else {
			notify($ERRORS{'OK'}, $log, "currentimage.txt can not be checked for image type: $status{nodetype}");
		}
	} ## end if ($sshd_status =~ /on/)
	else {
		$status{ssh} = 0;
	}
	notify($ERRORS{'OK'}, $log, "$computer_short_name sshd status: $sshd_status ($status{ssh})");

	# Check if nodetype.tab matches reservation image name
	my $nodetype_image_match = 0;
	if ($status{nodetype} eq $image_name) {
		notify($ERRORS{'OK'}, $log, "nodetype.tab ($status{nodetype}) matches reservation image ($image_name)");
		$nodetype_image_match = 1;
	}
	else {
		notify($ERRORS{'OK'}, $log, "nodetype.tab ($status{nodetype}) does not match reservation image ($image_name)");
	}

	# Check if nodetype.tab matches currentimage.txt
	my $nodetype_currentimage_match = 0;
	if ($status{nodetype} eq $status{currentimage}) {
		notify($ERRORS{'OK'}, $log, "nodetype.tab ($status{nodetype}) matches currentimage.txt ($status{currentimage})");
		$nodetype_currentimage_match = 1;
	}
	else {
		notify($ERRORS{'OK'}, $log, "nodetype.tab ($status{nodetype}) does not match currentimage.txt ($status{currentimage}), assuming nodetype.tab is correct");
	}

	# Determine the overall machine status based on the individual status results
	$status{status} = 'READY';
	if (!$status{rpower}) {
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, $log, "rpower status is not on, node needs to be reloaded");
	}
	if (!$status{ssh}) {
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, $log, "sshd is not accessible, node needs to be reloaded");
	}
	if (!$nodetype_image_match) {
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, $log, "nodetype.tab does not match requested image, node needs to be reloaded");
	}

	# Node is up and doesn't need to be reloaded
	if ($status{status} =~ /ready/i) {
		notify($ERRORS{'OK'}, $log, "node is up and does not need to be reloaded");
	}
	else {
		notify($ERRORS{'OK'}, $log, "node is either down or needs to be reloaded");
	}

	notify($ERRORS{'OK'}, $log, "returning node status hash reference with {status}=$status{status}");
	return \%status;
} ## end sub node_status

#/////////////////////////////////////////////////////////////////////////////

=head2 _assign2project

 Parameters  : $node, $project
 Returns     : 0 or 1
 Description : xCAT specific changes the networking to capable switch modules to either vcl,hpc or vclhpc project

=cut

sub _assign2project {
	my ($node, $project) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	notify($ERRORS{'CRITICAL'}, 0, "node is not defined")
	  if (!(defined($node)));
	notify($ERRORS{'CRITICAL'}, 0, "project is not defined")
	  if (!(defined($project)));
	my $PROJECTtab     = "$XCAT_ROOT/etc/project.tab";
	my $assign2project = "$XCAT_ROOT/sbin/assign2project";
	my $LCK            = $PROJECTtab . "lockfile";

	#make sure this management node can make assignments

	if (-r $PROJECTtab) {    #do we have a project.tab file to work with

		#read project tab
		if (open(PT, "<$PROJECTtab")) {
			my @pt = <PT>;
			close(PT);
			my $p;
			foreach $p (@pt) {
				if ($p =~ /^$node\s+/) {
					if ($p =~ /^$node\s*$project$/i) {
						notify($ERRORS{'OK'}, 0, "$node is set correctly to $project");
						return 1;
					}
					else {
						notify($ERRORS{'OK'}, 0, "starting to set exclusive lock on $LCK");
						if (sysopen(LF, $LCK, O_RDONLY | O_CREAT)) {
							if (flock(LF, LOCK_EX)) {    #set exclusive lock on LF
								notify($ERRORS{'OK'}, 0, "setting exclusive lock on $LCK");
								notify($ERRORS{'OK'}, 0, "$node is set incorrectly changing to $project project");
								if (open(AP, "$assign2project $node $project 2>&1 |")) {
									my @file = <AP>;
									close(AP);
									foreach my $l (@file) {
										notify($ERRORS{'OK'}, 0, "output @file");
										if ($l =~ /configurations are already correct! Nothing done/) {
											notify($ERRORS{'OK'}, 0, "$node is currently assigned to $project - releasing lock");
											close(LF);
											return 1;
										}
										if ($l =~ /Done!/) {
											notify($ERRORS{'OK'}, 0, "$node is successfully assigned to $project - releasing lock");
											close(LF);
											return 1;
										}

									}    #foreach
									notify($ERRORS{'CRITICAL'}, 0, "provided unexpected output $node $project - output= @file");
									close(LF);
									return 0;

								}    #if AP
							}    #flock
						}    #sysopen
					}    #else
				}    #if node
			}    #foreach
		}    #if open
		else {
			notify($ERRORS{'WARNING'}, 0, "could not open $PROJECTtab for reading $!");
			close(LF);
			return 0;
		}
	}    #if tabfile readable
	else {
		notify($ERRORS{'OK'}, 0, "project.tab does not exist on this Management node");
		return 1;

	}

} ## end sub _assign2project

#/////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : optional: image name
 Returns     : 1 if image exists, 0 if it doesn't
 Description : Checks the management node's local image repository for the
               existence of the requested image. This subroutine does not
					attempt to copy the image from another management node. The
					retrieve_image() subroutine does this. Callers of
					does_image_exist must also call retrieve_image if image library
					retrieval functionality is desired.

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get the image name, first try passed argument, then data
	my $image_name = shift;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name");
		return;
	}

	# Get the image repository path
	my $image_repository_path = $self->_get_image_repository_path();
	if (!$image_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "image repository path could not be determined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image repository path: $image_repository_path");
	}

	# Get the tmpl repository path
	my $tmpl_repository_path = $self->_get_image_template_path();
	if (!$tmpl_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "image template path could not be determined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "template repository path: $tmpl_repository_path");
	}

	# Check if template file exists for the image
	# -s File has nonzero size
	my $tmpl_file_exists;
	if (-s "$tmpl_repository_path/$image_name.tmpl") {
		$tmpl_file_exists = 1;
		notify($ERRORS{'DEBUG'}, 0, "template file exists: $image_name.tmpl");
	}
	else {
		$tmpl_file_exists = 0;
		notify($ERRORS{'DEBUG'}, 0, "template file does not exist: $tmpl_repository_path/$image_name.tmpl");
	}

	# Check if image files exist (Partimage files)
	# Open the repository directory
	if (!opendir(REPOSITORY, $image_repository_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to open the image repository directory: $image_repository_path");
		return;
	}

	# Get the list of files in the repository and close the directory
	my @repository_files = readdir(REPOSITORY);
	closedir(REPOSITORY);

	# Check if any files exist for the image
	my $image_files_exist;
	if (my @image_files = grep(/$image_name/, @repository_files)) {
		$image_files_exist = 1;
		my $image_file_list = join(@image_files, "\n");
		notify($ERRORS{'DEBUG'}, 0, "image files exist in repository:\n$image_file_list");
	}
	else {
		$image_files_exist = 0;
		notify($ERRORS{'DEBUG'}, 0, "image files do not exist in repository: $image_repository_path/$image_name");
	}

	# Check if either tmpl file or image files exist, but not both
	# Attempt to correct the situation:
	#    tmpl file exists but not image files: delete tmpl file
	#    image files exist but not tmpl file: create tmpl file
	if ($tmpl_file_exists && !$image_files_exist) {
		notify($ERRORS{'WARNING'}, 0, "template file exists but image files do not for $image_name");

		# Attempt to delete the orphaned tmpl file for the image
		if ($self->_delete_template($image_name)) {
			notify($ERRORS{'OK'}, 0, "deleted orphaned template file for image $image_name");
			$tmpl_file_exists = 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to delete orphaned template file for image $image_name, returning undefined");
			return;
		}
	} ## end if ($tmpl_file_exists && !$image_files_exist)
	elsif (!$tmpl_file_exists && $image_files_exist) {
		notify($ERRORS{'WARNING'}, 0, "image files exist but template file does not for $image_name");

		# Attempt to create the missing tmpl file for the image
		if ($self->_create_template($image_name)) {
			notify($ERRORS{'OK'}, 0, "created missing template file for image $image_name");
			$tmpl_file_exists = 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create missing template file for image $image_name, returning undefined");
			return;
		}
	} ## end elsif (!$tmpl_file_exists && $image_files_exist) [ if ($tmpl_file_exists && !$image_files_exist)

	# Check if both image files and tmpl file were found and return
	if ($tmpl_file_exists && $image_files_exist) {
		notify($ERRORS{'DEBUG'}, 0, "image $image_name exists on this management node");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image $image_name does not exist on this management node");
		return 0;
	}

} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////

=head2 retrieve_image

 Parameters  : Image name (optional)
 Returns     :
 Description : Attempts to retrieve an image from an image library partner

=cut

sub retrieve_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	# Make sure image library functions are enabled
	my $image_lib_enable = $self->data->get_management_node_image_lib_enable();
	if (!$image_lib_enable) {
		notify($ERRORS{'OK'}, 0, "image library functions are disabled");
		return;
	}

	# Get the image name
	my $image_name = shift || $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name from argument or reservation data");
		return;
	}
	
	# Make sure image does not already exist on this management node
	if ($self->does_image_exist($image_name)) {
		notify($ERRORS{'WARNING'}, 0, "image $image_name already exists on this management node");
		return 1;
	}

	# Get the other image library variables
	my $image_repository_path_local = $self->_get_image_repository_path()          || 'undefined';
	my $image_lib_partners = $self->data->get_management_node_image_lib_partners() || 'undefined';
	
	if ("$image_repository_path_local $image_lib_partners" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "image library configuration data is missing:
			local image repository path=$image_repository_path_local
			partners=$image_lib_partners
		");
		return;
	}

	# Attempt to copy image from other management nodes
	notify($ERRORS{'OK'}, 0, "attempting to retrieve image $image_name from another management node");

	# Split up the partner list
	my @partner_list = split(/,/, $image_lib_partners);
	if ((scalar @partner_list) == 0) {
		notify($ERRORS{'WARNING'}, 0, "image lib partners variable is not listed correctly or does not contain any information: $image_lib_partners");
		return;
	}

	# Loop through the partners, attempt to copy
	foreach my $partner (@partner_list) {
		# If another management node's repo path was requested, run find via ssh
		my $management_node_hostname = $self->data->get_management_node_hostname($partner) || '';
		my $management_node_image_lib_user = $self->data->get_management_node_image_lib_user($partner) || '';
		my $management_node_image_lib_key = $self->data->get_management_node_image_lib_key($partner) || '';
		my $management_node_ssh_port = $self->data->get_management_node_ssh_port($partner) || '';
		my $image_repository_path_remote = $self->_get_image_repository_path($partner);
		
		notify($ERRORS{'OK'}, 0, "checking if $management_node_hostname has image $image_name");
		notify($ERRORS{'DEBUG'}, 0, "remote image repository path on $partner: $image_repository_path_remote");
		
		# Use ssh to call ls on the partner management node
		my ($ls_exit_status, $ls_output) = run_ssh_command($partner, $management_node_image_lib_key, "ls -lh $image_repository_path_remote", $management_node_image_lib_user, $management_node_ssh_port, 1);
		if (defined($ls_output) && grep(/$image_name/, @$ls_output)) {
			notify($ERRORS{'OK'}, 0, "image $image_name exists on $management_node_hostname");
		}
		elsif (defined($ls_exit_status) && $ls_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "image $image_name does NOT exist on $management_node_hostname");
			next;
		}
		elsif (defined($ls_output) && grep(/No such file or directory/, @$ls_output)) {
			notify($ERRORS{'OK'}, 0, "image repository path '$image_repository_path_remote' does not exist on $management_node_hostname");
			next;
		}
		elsif (defined($ls_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine if image $image_name exists on $management_node_hostname, exit status: $ls_exit_status, output:\n" . join("\n", @$ls_output));
			next;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if image $image_name exists on $management_node_hostname");
			next;
		}
		
		# Attempt copy
		notify($ERRORS{'OK'}, 0, "copying image $image_name from $management_node_hostname");
		if (run_scp_command("$management_node_image_lib_user\@$partner:$image_repository_path_remote/$image_name*", $image_repository_path_local, $management_node_image_lib_key, $management_node_ssh_port)) {
			notify($ERRORS{'OK'}, 0, "image $image_name was copied from $management_node_hostname");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy image $image_name from $management_node_hostname");
			next;
		}
		
		# Create the template file for the image
		if (!$self->_create_template()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create template file for image $image_name");
			return;
		}
		
		last;
	}
	
	# Make sure image was copied
	if (!$self->does_image_exist($image_name)) {
		notify($ERRORS{'WARNING'}, 0, "$image_name was not copied to this management node");
		return 0;
	}

	return 1;
} ## end sub retrieve_image

#/////////////////////////////////////////////////////////////////////////////

=head2 _check_pxe_grub_file

 Parameters  : imagename
 Returns     : 0 failed or 1 success
 Description : checks the pxe and grub files for xCAT management nodes
				  if file size is equal to 0 delete the file and return true
				  return true if file not empty
				 only return false if failure to execute or delete files

=cut

sub _check_pxe_grub_files {
	my $imagename = $_[0];
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "node is not defined")
	  if (!(defined($imagename)));
	if (!(defined($imagename))) {
		return 0;
	}
	my $path      = "/tftpboot/xcat/image/x86/";
	my $ide_grub  = "$path" . "$imagename" . "-ide.grub";
	my $scsi_grub = "$path" . "$imagename" . "-scsi.grub";
	my $ide_pxe   = "$path" . "$imagename" . "-ide.pxe";
	my $scsi_pxe  = "$path" . "$imagename" . "-scsi.pxe";
	my @errors;
	if (-e "$ide_grub") {

		#file exists
		my $fs = -s "$ide_grub";
		if ($fs == 0) {
			notify($ERRORS{'CRITICAL'}, 0, "filesize for $ide_grub is zero, deleted ");
			unlink $ide_grub;
		}
	}
	else {

		#notify($ERRORS{'OK'},0,"skipping $ide_grub file does not exist");
	}
	if (-e "$scsi_grub") {

		#file exists
		my $fs = -s "$scsi_grub";
		if ($fs == 0) {
			notify($ERRORS{'CRITICAL'}, 0, "filesize for $scsi_grub is zero, deleted ");
			unlink $scsi_grub;
		}
	}
	else {

		#notify($ERRORS{'OK'},0,"skipping  $scsi_grub file does not exist");
	}
	if (-e "$ide_pxe") {

		#file exists
		my $fs = -s "$ide_pxe";
		if ($fs == 0) {
			notify($ERRORS{'CRITICAL'}, 0, "filesize for $ide_pxe is zero, deleted ");
			unlink $ide_pxe;
		}
	}
	else {

		#notify($ERRORS{'OK'},0,"skipping $ide_pxe file does not exist");
	}
	if (-e "$scsi_pxe") {

		#file exists
		my $fs = -s "$scsi_pxe";
		if ($fs == 0) {
			notify($ERRORS{'CRITICAL'}, 0, "filesize for $scsi_grub is zero, deleted ");
			unlink $scsi_pxe;
		}
	}
	else {

		#notify($ERRORS{'OK'},0,"skipping  file $scsi_pxe does not exist");
	}

	return 1;

} ## end sub _check_pxe_grub_files

#/////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : $image_name (optional)
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Either use a passed parameter as the image name or use the one stored in this object's DataStructure
	my $image_name = shift;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image name could not be determined");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "getting size of image: $image_name");

	my $image_repository_path = $self->_get_image_repository_path();
	if (!$image_repository_path) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine image repository location, returning 0");
		return 0;
	}

	# Execute the command
	my $du_command = "du -c $image_repository_path/$image_name* 2>&1";
	notify($ERRORS{'DEBUG'}, 0, "du command: $du_command");
	my $du_output = `$du_command`;

	# Save the exit status
	my $du_exit_status = $? >> 8;

	# Check if $? = -1, this likely means a Perl CHLD signal bug was encountered
	if ($? == -1) {
		notify($ERRORS{'OK'}, 0, "\$? is set to $?, setting exit status to 0, Perl bug likely encountered");
		$du_exit_status = 0;
	}

	# Check the du command output
	if ($du_exit_status > 0) {
		notify($ERRORS{'WARNING'}, 0, "du exit status > 0: $du_exit_status, output:\n$du_output");
		return 0;
	}
	elsif ($du_output !~ /total/s) {
		notify($ERRORS{'WARNING'}, 0, "du command did not produce expected output, du exit staus: $du_exit_status, output:\n$du_output");
		return 0;
	}

	# Find the du output line containing 'total'
	$du_output =~ /(\d+)\s+total/s;
	my $size_bytes = $1;

	# Check the du command output
	if (!$size_bytes) {
		notify($ERRORS{'WARNING'}, 0, "du produced unexpected output: $du_exit_status, output:\n$du_output");
		return 0;
	}

	# Calculate the size in MB
	my $size_mb = int($size_bytes / 1024);
	notify($ERRORS{'DEBUG'}, 0, "returning image size: $size_mb MB ($size_bytes bytes)");
	return $size_mb;

} ## end sub get_image_size

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_image_repository_path

 Parameters  : management node identifier (optional)
 Returns     : Successful: string containing filesystem path
               Failed:     false
 Description :

=cut

sub _get_image_repository_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Check if a management node identifier argument was passed
	my $management_node_identifier = shift;
	if ($management_node_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was specified: $management_node_identifier");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was not specified");
	}
	
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	
	# Get required image data
	my $image_id            = $self->data->get_image_id() || 'undefined';
	my $image_os_name            = $self->data->get_image_os_name() || 'undefined';
	my $image_os_type            = $self->data->get_image_os_type() || 'undefined';
	my $image_os_install_type    = $self->data->get_image_os_install_type() || 'undefined';
	my $image_os_source_path     = $self->data->get_image_os_source_path() || 'undefined';
	my $image_architecture       = $self->data->get_image_architecture() || 'undefined';
	if ("$image_os_name $image_os_type $image_os_install_type $image_os_source_path $image_architecture" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "some of the required data could not be retrieved: OS name=$image_os_name, OS type=$image_os_type, OS install type=$image_os_install_type, OS source path=$image_os_source_path, architecture=$image_architecture");
		return;
	}
	
	# Remove trailing / from $image_os_source_path if exists
	$image_os_source_path =~ s/\/$//;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to determine repository path for image:
		image id:        $image_id
		OS name:         $image_os_name
		OS type:         $image_os_type
		OS install type: $image_os_install_type
		OS source path:  $image_os_source_path\n
		architecture:    $image_architecture
	");
	
	# If image OS source path has a leading /, assume it was meant to be absolute
	# Otherwise, prepend the install path
	my $image_install_path;
	if ($image_os_source_path =~ /^\//) {
		$image_install_path = $image_os_source_path;
	}
	else {
		$image_install_path = "$management_node_install_path/$image_os_source_path";
	}

	# Note: $XCAT_ROOT has a leading /
	# Note: $image_install_path has a leading /
	if ($image_os_install_type eq 'kickstart') {
		# Kickstart installs use the xCAT path for both repo and tmpl paths
		my $kickstart_repo_path = "$XCAT_ROOT$image_install_path/$image_architecture";
		notify($ERRORS{'DEBUG'}, 0, "kickstart install type, returning $kickstart_repo_path");
		return $kickstart_repo_path;
	}
	
	elsif ($image_os_type eq 'linux' && $image_os_source_path eq 'image') {
		my $linux_image_repo_path = "$management_node_install_path/linux_image/$image_architecture";
		
		# Use the find command to check if any .gz files exist under a linux_image directory on the management node being checked
		my ($find_exit_status, $find_output);
		my $find_command = "find $linux_image_repo_path -name \"$image_os_name-*.gz\"";
		
		# Check if the repo path for this management node or another management node was requested
		if (!$management_node_identifier) {
			# If this management node's repo path was requested, just run find directly
			($find_exit_status, $find_output) = run_command($find_command, '1');
		}
		else {
			# If another management node's repo path was requested, run find via ssh
			my $management_node_hostname = $self->data->get_management_node_hostname($management_node_identifier) || '';
			my $management_node_image_lib_user = $self->data->get_management_node_image_lib_user($management_node_identifier) || '';
			my $management_node_image_lib_key = $self->data->get_management_node_image_lib_key($management_node_identifier) || '';
			my $management_node_ssh_port = $self->data->get_management_node_ssh_port($management_node_identifier) || '';
			
			notify($ERRORS{'DEBUG'}, 0, "attempting to find linux images under '$linux_image_repo_path' on management node:
					 hostname=$management_node_hostname
					 user=$management_node_image_lib_user
					 key=$management_node_image_lib_key
					 port=$management_node_ssh_port
			");
			
			($find_exit_status, $find_output) = run_ssh_command($management_node_hostname, $management_node_image_lib_key, $find_command, $management_node_image_lib_user, $management_node_ssh_port, 1);
		}
		
		# Check the output of the find command for any .gz files
		# If a .gz file was found, assume linux_image should be used
		if ($find_output) {
			my $linux_images_found = grep(/\.gz/, @$find_output);
			if ($linux_images_found) {
				notify($ERRORS{'DEBUG'}, 0, "found $linux_images_found images, returning $linux_image_repo_path");
				return $linux_image_repo_path;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "did not find any images under $linux_image_repo_path");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run find");
		}
		
	}
	
	my $repo_path = "$image_install_path/$image_architecture";
	notify($ERRORS{'DEBUG'}, 0, "returning: $repo_path");
	return $repo_path;
} ## end sub _get_image_repository_path

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_image_template_path

 Parameters  : management node identifier (optional)
 Returns     : Successful: string containing filesystem path
               Failed:     false
 Description :

=cut

sub _get_image_template_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Check if a management node identifier argument was passed
	my $management_node_identifier = shift;
	if ($management_node_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was specified: $management_node_identifier");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was not specified");
	}
	
	# Get required image data
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	my $image_os_source_path     = $self->data->get_image_os_source_path() || 'undefined';
	my $image_architecture       = $self->data->get_image_architecture() || 'undefined';
	if ("$image_os_source_path $image_architecture" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "some of the required data could not be retrieved:
			OS source path=$image_os_source_path
			architecture=$image_architecture
		");
		return;
	}
	
	# Remove trailing / from $image_os_source_path if exists
	$image_os_source_path =~ s/\/$//;
	
	# If image OS source path has a leading /, assume it was meant to be absolute
	# Otherwise, prepend the install path
	my $image_install_path;
	if ($image_os_source_path =~ /^\//) {
		$image_install_path = $image_os_source_path;
	}
	else {
		$image_install_path = "$management_node_install_path/$image_os_source_path";
	}
	
	my $template_path = "$XCAT_ROOT$image_install_path/$image_architecture";
	notify($ERRORS{'DEBUG'}, 0, "template path: $template_path");
	return $template_path;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_base_template_filename

 Parameters  : none, must be called as an xCAT object method
 Returns     :
 Description :

=cut

sub _get_base_template_filename {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get some variables
	my $image_os_name = $self->data->get_image_os_name();
	my $image_os_type = $self->data->get_image_os_type();

	# Get the image template directory path
	my $image_template_path = $self->_get_image_template_path();
	if (!$image_template_path) {
		notify($ERRORS{'CRITICAL'}, 0, "image template path could not be determined");
		return 0;
	}

	# Find the template file to use, from most specific to least
	# Try OS-specific: <OS name>.tmpl
	if (-e "$image_template_path/$image_os_name.tmpl") {
		notify($ERRORS{'DEBUG'}, 0, "OS specific base image template file found: $image_template_path/$image_os_name.tmpl");
		return "$image_os_name.tmpl";
	}
	elsif (-e "$image_template_path/$image_os_type.tmpl") {
		notify($ERRORS{'DEBUG'}, 0, "OS type specific base image template file found: $image_template_path/$image_os_type.tmpl");
		return "$image_os_type.tmpl";
	}
	elsif (-e "$image_template_path/default.tmpl") {
		notify($ERRORS{'DEBUG'}, 0, "default base image template file found: $image_template_path/default.tmpl");
		return "default.tmpl";
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to find suitable base image template file in $image_template_path");
		return 0;
	}
} ## end sub _get_base_template_filename

#/////////////////////////////////////////////////////////////////////////////

=head2 _create_template

 Parameters  : image name (optional)
 Returns     : true if successful, false if failed
 Description : Creates a template file for the image specified for the reservation.

=cut

sub _create_template {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the image name
	my $image_name = shift;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to create template file, image name could not be retrieved");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "attempting to create tmpl file for image: $image_name");

	# Get the image template repository path
	my $tmpl_repository_path = $self->_get_image_template_path();
	if (!$tmpl_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "xCAT template repository information could not be determined");
		return 0;
	}

	# Get the base template filename
	my $basetmpl = $self->_get_base_template_filename();
	if (!$basetmpl) {
		notify($ERRORS{'WARNING'}, 0, "base template filename could not be determined");
		return 0;
	}

	# Make a copy of the base template file
	my $cp_output      = `/bin/cp -fv  $tmpl_repository_path/$basetmpl $tmpl_repository_path/$image_name.tmpl 2>&1`;
	my $cp_exit_status = $? >> 8;

	# Check if $? = -1, this likely means a Perl CHLD signal bug was encountered
	if ($? == -1) {
		notify($ERRORS{'OK'}, 0, "\$? is set to $?, setting exit status to 0, Perl bug likely encountered");
		$cp_exit_status = 0;
	}

	if ($cp_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "copied $basetmpl to $tmpl_repository_path/$image_name.tmpl, output:\n$cp_output");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy $basetmpl to $tmpl_repository_path/$image_name.tmpl, returning undefined, exit status: $cp_exit_status, output:\n$cp_output");
		return;
	}

	# Make sure template file was created
	# -s File has nonzero size
	my $tmpl_file_exists;
	if (-s "$tmpl_repository_path/$image_name.tmpl") {
		notify($ERRORS{'DEBUG'}, 0, "confirmed template file exists: $tmpl_repository_path/$image_name.tmpl");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "template file should have been copied but does not exist: $tmpl_repository_path/$image_name.tmpl, returning undefined");
		return;
	}

	notify($ERRORS{'OK'}, 0, "successfully created template file: $image_name.tmpl");
	return 1;
} ## end sub _create_template

#/////////////////////////////////////////////////////////////////////////////

=head2 _delete_template

 Parameters  : image name (optional)
 Returns     : true if successful, false if failed
 Description : Deletes a template file for the image specified for the reservation.

=cut

sub _delete_template {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the image name
	my $image_name = shift;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete template file, image name could not be retrieved");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "attempting to delete tmpl file for image: $image_name");

	# Get the image template repository path
	my $tmpl_repository_path = $self->_get_image_template_path();
	if (!$tmpl_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "xCAT template repository information could not be determined");
		return 0;
	}

	# Delete the template file
	my $rm_output      = `/bin/rm -fv  $tmpl_repository_path/$image_name.tmpl 2>&1`;
	my $rm_exit_status = $? >> 8;

	# Check if $? = -1, this likely means a Perl CHLD signal bug was encountered
	if ($? == -1) {
		notify($ERRORS{'OK'}, 0, "\$? is set to $?, setting exit status to 0, Perl bug likely encountered");
		$rm_exit_status = 0;
	}

	if ($rm_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "deleted $tmpl_repository_path/$image_name.tmpl, output:\n$rm_output");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete $tmpl_repository_path/$image_name.tmpl, returning undefined, exit status: $rm_exit_status, output:\n$rm_output");
		return;
	}

	# Make sure template file was deleted
	# -s File has nonzero size
	my $tmpl_file_exists;
	if (-s "$tmpl_repository_path/$image_name.tmpl") {
		notify($ERRORS{'WARNING'}, 0, "template file should have been deleted but still exists: $tmpl_repository_path/$image_name.tmpl, returning undefined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "confirmed template file was deleted: $tmpl_repository_path/$image_name.tmpl");
	}

	notify($ERRORS{'OK'}, 0, "successfully deleted template file: $tmpl_repository_path/$image_name.tmpl");
	return 1;
} ## end sub _delete_template

#/////////////////////////////////////////////////////////////////////////////

initialize() if (!$XCAT_ROOT);

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
