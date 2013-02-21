#!/usr/bin/perl -w
###############################################################################
# $Id: xCAT2.pm 926747 2010-03-23 19:37:22Z fapeeler $
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

VCL::Provisioning::xCAT21 - VCL module to support the xCAT 2.x provisioning engine

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
package VCL::Module::Provisioning::xCAT2;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::xCAT);

# Specify the version of this module
our $VERSION = '2.3.2';

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

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the xCAT2.pm module and resets node to boot state

=cut

sub DESTROY {
	my $self 	= shift;
	my $address = sprintf('%x', $self);
	my $node		= $self->data->get_computer_node_name();
	my $request_state_name = $self->data->get_request_state_name();

	if($request_state_name =~ /^(new|reload|image)$/) {
		if(_nodeset_option($node, "boot")){
			notify($ERRORS{'DEBUG'}, 0, "set $node to boot state during $request_state_name state");
		} 
	}
	
	# Check for an overridden destructor
   $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");		

} ## end sub DESTROY

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
	my $reservation_id        = $self->data->get_reservation_id();
	my $image_name            = $self->data->get_image_name();
	my $image_os_name         = $self->data->get_image_os_name();
	my $image_os_type         = $self->data->get_image_os_type();
	my $image_project         = $self->data->get_image_project();
	my $image_reload_time     = $self->data->get_image_reload_time();
	my $imagemeta_postoption  = $self->data->get_imagemeta_postoption();
	my $image_architecture    = $self->data->get_image_architecture();
	my $computer_id           = $self->data->get_computer_id();
	my $computer_node_name    = $self->data->get_computer_node_name();
	my $computer_ip_address   = $self->data->get_computer_ip_address();
	my $computer_private_ip_address   = $self->data->get_computer_private_ip_address();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	my $ip_configuration         = $self->data->get_management_node_public_ip_configuration();

	notify($ERRORS{'OK'}, 0, "nodename not set") if (!defined($computer_node_name));
	notify($ERRORS{'OK'}, 0, "imagename not set") if (!defined($image_name));
	notify($ERRORS{'OK'}, 0, "project not set") if (!defined($image_project));
	notify($ERRORS{'OK'}, 0, "estimated reload time not set") if (!defined($image_reload_time));
	notify($ERRORS{'OK'}, 0, "osname not set") if (!defined($image_os_name));
	notify($ERRORS{'OK'}, 0, "computerid not set") if (!defined($computer_id));
	notify($ERRORS{'OK'}, 0, "reservationid not set") if (!defined($reservation_id));
	notify($ERRORS{'OK'}, 0, "architecture not set") if (!defined($image_architecture));

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
	# changes the blade to a predefined VLAN based on the project name
	# if assign2project script or project.tab do not exist then returns

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

	# Insert a computerloadlog record and edit nodetype table
	insertloadlog($reservation_id, $computer_id, "editnodetype", "updating nodetype table");
	if ($self->_edit_nodetype($computer_node_name, $image_name, 0)) {    #FIXME
		notify($ERRORS{'OK'}, 0, "nodetype updated for $computer_node_name with $image_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not edit nodetype for $computer_node_name with $image_name");
	}

	# Insert a computerloadlog record and edit nodelist table
	insertloadlog($reservation_id, $computer_id, "info", "updating nodelist table");
	if ($self->_edit_nodelist($computer_node_name, 0)) {
		notify($ERRORS{'OK'}, 0, "nodelist updated for $computer_node_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not edit nodelist for $computer_node_name");
	}

	# Begin reinstallation using xCAT's rinstall
	# Loop and continue checking

	# Set flags and counters
	my $rinstall_attempts = 0;
	my $rpower_fixes      = 0;
	my $bootstatus        = 0;
	my $wait_loops        = 0;
	my $xcat_throttle     = 0;
	my @status;

	# Check to see if management node throttle is configured
        #get Throttle value from database if set
        my $variable_name = $self->data->get_management_node_hostname() . "|xcat|throttle";
        if($self->data->is_variable_set($variable_name)){
                notify($ERRORS{'DEBUG'}, 0, "throttle is  set for $variable_name");
		#fetch variable
		$xcat_throttle = $self->data->get_variable($variable_name);
        
        }
        else{
                notify($ERRORS{'DEBUG'}, 0, "throttle is not set for $variable_name");
                $xcat_throttle = 0;
        }

	if ($xcat_throttle) {
		notify($ERRORS{'DEBUG'}, 0, "throttle is set to $xcat_throttle");
		my $lckloadfile = "/tmp/nodeloading.lockfile";
		notify($ERRORS{'DEBUG'}, 0, "attempting to open node loading lockfile for throttling: $lckloadfile");
		if (sysopen(SEM, $lckloadfile, O_RDONLY | O_CREAT)) {
			notify($ERRORS{'DEBUG'}, 0, "opened lockfile, attempting to obtain lock");
			if (flock(SEM, LOCK_EX)) {
				notify($ERRORS{'DEBUG'}, 0, "obtained exclusive lock on $lckloadfile, checking for concurrent loads");
				my $maxload = 1;
				while ($maxload) {
					notify($ERRORS{'DEBUG'}, 0, "running 'nodeset all stat' to determine number of nodes currently being loaded");
					if (open(NODESET, "$XCAT_ROOT/sbin/nodeset all stat \| egrep \'install\|image\' 2>&1 | ")) {
						my @nodesetout = <NODESET>;
						close(NODESET);
						my $ld = @nodesetout;
						notify($ERRORS{'DEBUG'}, 0, "current number of nodes loading: $ld");
						if ($ld < $xcat_throttle) {
							notify($ERRORS{'OK'}, 0, "current nodes loading is less than throttle, ok to proceed");
							$maxload = 0;
						}
						else {
							notify($ERRORS{'OK'}, 0, "current nodes loading=$ld, throttle=$xcat_throttle, must wait, sleeping for 10 seconds");
							sleep 10;
						}
					} ## end if (open(NODESET, "$XCAT_ROOT/sbin/nodeset all stat \| grep install 2>&1 | "...
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

	} ## end if ($xcat_throttle)
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
				notify($ERRORS{'OK'}, 0, "beginning rinstall attempt $rinstall_attempts on $computer_node_name");
				while (<RINSTALL>) {
					chomp($_);
					# TODO make sure "not in bay" still exists
					notify($ERRORS{'OK'}, 0, "$_");
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
								notify($ERRORS{'CRITICAL'}, 0, "rpower failed $rpower_fixes times on $computer_node_name");
								return 0;
							}
						} ## end if (_fix_rpower($computer_node_name))
					} ## end if ($_ =~ /not in bay/)
					                     # TODO make sure "Invalid login|does not exist" still exists
					if ($_ =~ /Invalid login|does not exist/) {
						notify($ERRORS{'CRITICAL'}, 0, "failed to initate rinstall on $computer_node_name - $_");
						close(RINSTALL);
						close(SEM);
						insertloadlog($reservation_id, $computer_id, "failed", "failed to start load process on $computer_node_name");
						return 0;
					}
					if ($_ =~ /failure/) {
						my $success = 0;
						notify($ERRORS{'OK'}, 0, "rinstall's nodeset failed - trying nodeset directly: ($_)");
						if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $computer_node_name install 2>&1 |")) {
							while (<NODESET>) {
								chomp($_);
								if ($_ =~ /$computer_node_name: install/) {
									$success = 1;
									notify($ERRORS{'OK'}, 0, "node set to install");
								}
							}
							close(NODESET);
						} ## end if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $computer_node_name install 2>&1 |"...
						else {
							notify($ERRORS{'CRITICAL'}, 0, "failed to open nodeset directly ($XCAT_ROOT/sbin/nodeset)");
							close(RINSTALL);
							close(SEM);
							insertloadlog($reservation_id, $computer_id, "failed", "failed to start load process on $computer_node_name");
							return 0;
						}
						if ($success) {
							$success = 0;
							if($self->power_off()) {
                        $success = 1 if($self->power_on());
                     }
						} ## end if ($success)
						else {
							notify($ERRORS{'CRITICAL'}, 0, "direct call of nodeset failed ($_)");
							close(RINSTALL);
							close(SEM);
							insertloadlog($reservation_id, $computer_id, "failed", "failed to start load process on $computer_node_name");
							return 0;
						}
						if (!$success) {
							notify($ERRORS{'CRITICAL'}, 0, "direct call of rpower failed ($_)");
							close(RINSTALL);
							close(SEM);
							insertloadlog($reservation_id, $computer_id, "failed", "failed to start load process on $computer_node_name");
							return 0;
						}
					} ## end if ($_ =~ /nodeset failure/)

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
	my ($eth0MACaddress);

	# get MAC address
	if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_node_name mac.mac 2>&1 |")) {
		my @file = <NODELS>;
		close(NODELS);
		foreach my $l (@file) {
			if ($l =~ /(^$computer_node_name:)(\s+)([:0-9a-f]*)/i) {
				$eth0MACaddress = $3;
				notify($ERRORS{'OK'}, 0, "MAC address for $computer_node_name collected $eth0MACaddress");
			}
		}
	} ## end if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_node_name mac.mac 2>&1 |"...
	else {
		# could not run nodels command
		notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodels command to get mac address");
		return 1;
	}
	if (!defined($eth0MACaddress)) {
		notify($ERRORS{'WARNING'}, 0, "MAC address not found for $computer_node_name , possible issue with regex");
	}

	my ($s1, $s2, $s3, $s4, $s5) = 0;
	my $sloop = 0;
	#insertloadlog($reservation_id,$computer_id,"info","SUCCESS initiated install process");
	#sleep for boot process to happen takes anywhere from 60-90 seconds
	notify($ERRORS{'OK'}, 0, "sleeping 65 to allow bootstrap of $computer_node_name");
	sleep 65;
	my @TAILLOG;
	my $t;
	my $maxloops = ($image_reload_time * 6);
	$maxloops = 60 if $maxloops < 60;

	if ($eth0MACaddress && $computer_private_ip_address) {
		@TAILLOG = 0;
		$t       = 0;
		if (open(TAIL, "</var/log/messages")) {
			seek TAIL, -1, 2;    #
			for (;;) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name ROUND 1 checks loop $sloop of $maxloops");
				while (<TAIL>) {
					if (!$s1) {
						if ($_ =~ /dhcpd: DHCPDISCOVER from $eth0MACaddress/i) {
							$s1 = 1;
							notify($ERRORS{'OK'}, 0, "$computer_node_name STAGE 1 set DHCPDISCOVER from $eth0MACaddress");
							insertloadlog($reservation_id, $computer_id, "xcatstage1", "SUCCESS stage1 detected dhcp request for node");
						}
					}
					if (!$s2) {
						if ($_ =~ /dhcpd: DHCPACK on $computer_private_ip_address to $eth0MACaddress/i) {
							$s2 = 1;
							notify($ERRORS{'OK'}, 0, "$computer_node_name  STAGE 2 set DHCPACK on $computer_private_ip_address to $eth0MACaddress");
							insertloadlog($reservation_id, $computer_id, "xcatstage2", "SUCCESS stage2 detected dhcp ack for node");
						}
					}


				}    #while
				     #either stages are set or we loop or we rinstall again

				if ($s2) {
					notify($ERRORS{'OK'}, 0, "$computer_node_name ROUND1 stages are set proceeding to next round");
					close(TAIL);
					#Pause before continuing 
					sleep 30;
					goto ROUND2;
				}
				elsif ($sloop > $maxloops) {
					insertloadlog($reservation_id, $computer_id, "WARNING", "potential problem started $rinstall_attempts install attempt");
					# hrmm this is taking too long
					# have we been here before? if less than 3 attempts continue; on the 3rd try fail
					# whats the problem, chck known locations
					# /tftpboot/xcat/image/x86
					# look for tmpl file (in does_image_exist routine)
					# does the machine need to reboot, premission to reboot issue
					# TODO update for v2
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
						close(TAIL);
						return 0;
					}
				} ## end elsif ($sloop > $maxloops)  [ if ($s4)
				else {
					#keep checking the messages log
					$sloop++;
					sleep 10;
					seek TAIL, 0, 1;
				}
			}    #for loop
		}    #if Tail
		else {
			notify($ERRORS{'CRITICAL'}, 0, "could not open /var/log/messages to  $!");
		}
	} ## end if ($eth0MACaddress && $computer_private_ip_address)
	else {
		notify($ERRORS{'CRITICAL'}, 0, "eth0MACaddress $eth0MACaddress && privateIP $computer_private_ip_address  are not set not able to use these checks");
		insertloadlog($reservation_id, $computer_id, "failed", "FAILED could not locate private IP and MAC addresses in XCAT files failing reservation");
		return 0;
	}

	ROUND2:
	#begin second round of checks reset $sX
	($s1, $s2, $s3, $s4, $s5) = 0;
	$sloop = 0;
	my $status     = '';
	my $laststatus = '';
	# start time for loading
	my $R2starttime = convert_to_epoch_seconds();
	#during loading we need to wait based on some precentage of the estimated reload time (50%?)
	#times range from 4-10 minutes perhaps longer for a large image
	my $TM2waittime = int($image_reload_time / 2);
	insertloadlog($reservation_id, $computer_id, "xcatround2", "starting ROUND2 checks - waiting for boot flag");

	notify($ERRORS{'OK'}, 0, "Round 2 TM2waittime set to $TM2waittime on $computer_node_name");
	my $gettingclose = 0;
	my $badoutputcnt = 0;
	for (;;) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name round2 log checks 30sec loop count is $sloop of " . ($image_reload_time * 4) . " TM2waittime= $TM2waittime");
		if (open(NODESTAT, "$XCAT_ROOT/bin/nodestat $computer_node_name stat 2>&1 |")) {
			my @file = <NODESTAT>;
			close(NODESTAT);
			foreach my $l (@file) {
				$laststatus = $status;
				$status     = $l;
				chomp $status;
				if ($status !~ /^$computer_node_name:/) {
					notify($ERRORS{'WARNING'}, 0, "received unexpected output while running nodestat $computer_node_name: $status");
					if ($badoutputcnt > 5) {
						notify($ERRORS{'CRITICAL'}, 0, "failed to receive valid output from nodestat command, failing request");
						insertloadlog($reservation_id, $computer_id, "failed", "failed to get current status of machine");
						return 0;
					}
					$badoutputcnt++;
					sleep 5;
					next;
				} ## end if ($status !~ /^$computer_node_name:/)
				$status =~ s/$computer_node_name: //;
			} ## end foreach my $l (@file)
		} ## end if (open(NODESTAT, "$XCAT_ROOT/bin/nodestat $computer_node_name stat 2>&1 |"...
		else {
			# could not run nodestat command
			notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodestat command");
			insertloadlog($reservation_id, $computer_id, "failed", "failed to get current status of machine");
			return 0;
		}
		# FIXME add check for condition where capture finished and machine reboots before we catch it
		if (!$s1) {
			if ($status =~ /install/) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name is installing: $status");
				insertloadlog($reservation_id, $computer_id, "xcatstage5", "SUCCESS node started installing");
				$s1 = 1;
			}
			elsif ($status =~ /partimage-ng: complete/) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name is finished installing: $status");
				insertloadlog($reservation_id, $computer_id, "bootstate", "node completed imaging process - proceeding to next round");
				$s1 = 1;
				$s2 = 1;
			}
			elsif ($status =~ /partimage-ng:/) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name is installing: $status");
				insertloadlog($reservation_id, $computer_id, "xcatstage5", "SUCCESS node started installing");
				$s1 = 1;
			}
		} ## end if (!$s1)
		if ($s1 && !$s2) {
			my $nodeset_status = _nodeset_option($computer_node_name, "stat");
			if ($status =~ /installing|unknown/ || $nodeset_status =~ /install/){
				notify($ERRORS{'OK'}, 0, "$computer_node_name is still installing, nodestat: $status");
			}
			
			if ($nodeset_status =~ /boot/ || $status =~ /partimage-ng: complete/) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name is finished installing: $status");
				insertloadlog($reservation_id, $computer_id, "bootstate", "node in boot state completed imaging process - proceeding to next round");
				$s2 = 2;
			}
		}


=pod
			if ($_ =~ /xcat: xcatd: set boot request from $computer_node_name/) {

				insertloadlog($reservation_id, $computer_id, "bootstate", "node in boot state completed imaging process - proceeding to next round");
				$s1 = 1;
				notify($ERRORS{'OK'}, 0, "Round 2 STAGE 1 set $computer_node_name in boot state");
			}
			#is it even near completion only checking rhel installs
			#not really useful for linux_images
			if ($image_os_type =~ /linux/i) {
				if (!$gettingclose) {
					# TODO update for v2
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
=cut

		if ($s2) {
			#good, move on
			goto ROUND3;
		}
		else {
			if ($sloop >= ($image_reload_time * 4)) {
				notify($ERRORS{'OK'}, 0, "exceeded TM2waittime of $TM2waittime minutes sloop= $sloop ert= $image_reload_time");
				# check delta from when we started actual loading till now
				my $rtime = convert_to_epoch_seconds();
				my $delta = $rtime - $R2starttime;
				if ($laststatus ne $status) {
					# install is progressing, just decrement $sloop
					notify($ERRORS{'DEBUG'}, 0, "sloop > image_reload_time * 4, but install still progressing; decrementing sloop and continuing");
					sleep 15;
					$sloop = ($sloop - 8);
				}
				elsif ($delta < ($image_reload_time * 60)) {
					#ok  delta is actually less then ert, we don't need to stop it yet.
					notify($ERRORS{'OK'}, 0, "loading delta is less than ert, not stopping yet delta is $delta/60 ");
					sleep 15;
					$sloop = ($sloop - 8);    #decrement loop control
				}
				elsif ($rinstall_attempts < 2) {
					notify($ERRORS{'WARNING'}, 0, "starting rinstall again");
					insertloadlog($reservation_id, $computer_id, "WARNING", "potential problem, restarting rinstall current attempt $rinstall_attempts");
					insertloadlog($reservation_id, $computer_id, "repeat",  "starting install process");
					goto XCATRINSTALL;
				}
				else {
					#fail this one and let whoever called me get another machine
					notify($ERRORS{'CRITICAL'}, 0, "rinstall made $rinstall_attempts in ROUND2 on $computer_node_name with no success, admin needs to check it out");
					insertloadlog($reservation_id, $computer_id, "failed", "rinstall made $rinstall_attempts failing request");
					return 0;
				}
			} ## end if ($sloop >= ($image_reload_time * 4))
			else {
				sleep 15;
				$sloop++;    #loop control
				insertloadlog($reservation_id, $computer_id, "info", "node in load process: $status");
			}
		} ## end else [ if ($s2)
	}    #for


	ROUND3:
	
	insertloadlog($reservation_id, $computer_id, "xcatround3", "starting round 3 checks - finishing post configuration");
	
	if ($self->os->can("post_load")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "->post_load()");
		my $post_load_result = $self->os->post_load($rinstall_attempts);
		
		if (!defined $post_load_result) {
			notify($ERRORS{'WARNING'}, 0, "post_load returned undefined");
			return;
		}
		elsif (!$post_load_result) {
			notify($ERRORS{'WARNING'}, 0, "post_load subroutine returned $post_load_result");
			
			if ($rinstall_attempts < 2) {
				my $debugging_message = "*reservation has NOT failed yet*\n";
				$debugging_message .= "this notice is for debugging purposes so that node can be watched during 2nd rinstall attempt\n";
				$debugging_message .= "sshd did not become active on $computer_node_name after first rinstall attempt\n\n";
				$debugging_message .= $self->data->get_reservation_info_string();
				notify($ERRORS{'CRITICAL'}, 0, "$debugging_message");
				
				goto XCATRINSTALL;
			}
			else {
				return;
			}
		}
		else {
			notify($ERRORS{'OK'}, 0, "post_load subroutine returned $post_load_result");
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, ref($self->os) . "::post_load() has not been implemented");
	}

	return 1;
} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  :
 Returns     : 1 if sucessful, 0 if failed
 Description :

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Get data
	my $image_name          = $self->data->get_image_name();
	my $computer_short_name = $self->data->get_computer_short_name();
	my $computer_node_name  = $self->data->get_computer_node_name();

	# Print some preliminary information
	notify($ERRORS{'OK'}, 0, "image=$image_name, computer=$computer_short_name");

	# Modify currentimage.txt
	if (write_currentimage_txt($self->data)) {
		notify($ERRORS{'OK'}, 0, "currentimage.txt updated on $computer_short_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update currentimage.txt on $computer_short_name");
		return 0;
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

		# The OS module should turn the computer power off
		# Wait up to 2 minutes for the computer's power status to be off
		if ($self->wait_for_off(2)) {
			notify($ERRORS{'OK'}, 0, "computer $computer_node_name power is off");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name power is still on, turning computer off");

			# Attempt to power off computer
			if ($self->power_off()) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name was powered off");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to power off $computer_node_name");
				return 0;
			}
		} ## end else [ if ($self->wait_for_off(2))
	} ## end if ($self->os->can("pre_capture"))
	elsif ($self->os->can("capture_prepare")) {
		notify($ERRORS{'OK'}, 0, "calling OS module's capture_prepare() subroutine");
		if (!$self->os->capture_prepare()) {
			notify($ERRORS{'WARNING'}, 0, "OS module capture_prepare() failed");
			return 0;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "OS module does not have either a pre_capture() or capture_prepare() subroutine");
		return 0;
	}

	if ($self->_edit_nodetype($computer_node_name, $image_name, 1)) {
		notify($ERRORS{'OK'}, 0, "nodetype modified, node $computer_node_name, image name $image_name");
	}    # Close if _edit_nodetype
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not edit nodetype, node $computer_node_name, image name $image_name");
		return 0;
	}    # Close _edit_nodetype failed

	# Create the tmpl file for the image
        if ($self->_create_template()) {
                notify($ERRORS{'OK'}, 0, "created .tmpl file for $image_name");
        }
        else {
                notify($ERRORS{'WARNING'}, 0, "failed to create .tmpl file for $image_name");
                return 0;
        }

	# edit nodelist table
	if ($self->_edit_nodelist($computer_node_name, 1)) {
		notify($ERRORS{'OK'}, 0, "nodelist updated for $computer_node_name");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not edit nodelist for $computer_node_name");
	}

	# Call xCAT's nodeset, configure xCAT to save image on next reboot
	if (_nodeset_option($computer_node_name, "image")) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name set to image state");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed $computer_node_name set to image state");
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
			return 0;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "OS module does not have either a pre_capture() or capture_start() subroutine");
		return 0;
	}


	# Monitor the image capture
	if ($self->capture_monitor()) {
		notify($ERRORS{'OK'}, 0, "image capture monitoring is complete");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "problem occurred while monitoring image capture");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
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

	my $fullloopcnt       = 0;
	my $filesize          = 0;
	my $filewatchcnt      = 0;
	my $status            = '';
	my $laststatus        = '';
	my $badoutputcnt      = 0;
	my $nostatuschangecnt = 0;

	CIWAITIMAGE:
	# waiting for imaging process to complete
	# check power or
	# check new image timestamp ? or
	# check /var/log/messages file for node entries or
	# or check nodestat for boot flag

	if ($fullloopcnt > 30) {
		# looped 10 times without seeing a change in file size or
		#   change in output of nodestat, must have failed
		notify($ERRORS{'CRITICAL'}, 0, "reached max loop cnt with no change in image file size and no change in output from nodestat, failing");
		return 0;
	}

	#wait for reboot as not preform useless checks
	notify($ERRORS{'OK'}, 0, "sleeping for 45 seconds");
	sleep 45;

	notify($ERRORS{'DEBUG'}, 0, "checking for $image_repository_path/$image_name.img.capturedone");
	# check for imagename.capturedone or imagename.capturefailed
	if (-e "$image_repository_path/$image_name.img.capturedone") {
		unlink("$image_repository_path/$image_name.img.capturedone");
		# capture complete
		if (open(CHMOD, "/bin/chmod -R 644 $image_repository_path/$image_name\* 2>&1 |")) {
			close(CHMOD);
			notify($ERRORS{'DEBUG'}, 0, "recursive update file permissions 644 on $image_repository_path/$image_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to recursive update file permissions 644 on $image_repository_path/$image_name");
		}
		#complete return success
		notify($ERRORS{'OK'}, 0, "image capture complete, found and removed capturedone file");
		return 1;
	} ## end if (-e "$image_repository_path/$image_name.img.capturedone")
	elsif (-e "$image_repository_path/$image_name.img.capturefailed") {
		unlink("$image_repository_path/$image_name.img.capturefailed");
		notify($ERRORS{'CRITICAL'}, 0, "partimage-ng failed for $image_name on $computer_node_name, failing reservation");
		return 0;
	}

	if (open(NODESTAT, "$XCAT_ROOT/bin/nodestat $computer_node_name stat 2>&1 |")) {
		my @file = <NODESTAT>;
		close(NODESTAT);
		foreach my $l (@file) {
			$laststatus = $status;
			$status     = $l;
			chomp $status;
			if ($status !~ /^$computer_node_name:/) {
				notify($ERRORS{'WARNING'}, 0, "received unexpected output while running nodestat $computer_node_name: $status");
				if ($badoutputcnt > 5) {
					notify($ERRORS{'CRITICAL'}, 0, "failed to receive valid output from nodestat command, failing request");
					return 0;
				}
				$badoutputcnt++;
			}
			$status =~ s/$computer_node_name: //;
		} ## end foreach my $l (@file)
	} ## end if (open(NODESTAT, "$XCAT_ROOT/bin/nodestat $computer_node_name stat 2>&1 |"...

	# could not run nodestat command, fall back to watching image size
	# Check the image size to see if it's growing
	notify($ERRORS{'OK'}, 0, "checking size of image");
	my $size = $self->get_image_size($image_name);
	if (defined $size) {
		notify($ERRORS{'OK'}, 0, "retrieved size of image: $size");

		if ($size > $filesize) {
			notify($ERRORS{'OK'}, 0, "image size has changed: $filesize -> $size, still copying");
			$filesize    = $size;
			$fullloopcnt = 0;
		}
		elsif ($size == $filesize) {
			notify($ERRORS{'OK'}, 0, "image size has NOT changed");
			if ($filewatchcnt > 5) {
				notify($ERRORS{'CRITICAL'}, 0, "waited too long for file size to change for $image_name from $computer_node_name, failing");
				return 0;
			}
			$filewatchcnt++;
		}
	} ## end if (defined $size)
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve current size of image");
	}

	if ($status =~ /partimage-ng: partition/) {
		if ($status eq $laststatus) {
			notify($ERRORS{'DEBUG'}, 0, "nodestat status did not change from last iteration ($status)");
			if ($nostatuschangecnt > 5) {
				notify($ERRORS{'CRITICAL'}, 0, "waited too long for status of $computer_node_name to change - seems to be hung, failing");
				return 0;
			}
			$nostatuschangecnt++;
		}
		else {
			$nostatuschangecnt = 0;
			$fullloopcnt       = 0;
		}
		# report status
		notify($ERRORS{'OK'}, 0, "partimage-ng running on $computer_node_name: $status");
	} ## end if ($status =~ /partimage-ng: partition/)

	$fullloopcnt++;
	goto CIWAITIMAGE;
} ## end sub capture_monitor

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
                notify($ERRORS{'WARNING'}, 0, "xCAT template repository information could not be determined") ;
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

=head2  _edit_template

 Parameters  : imagename,drivetype
 Returns     : 0 failed or 1 success
 Description : general routine to edit /opt/xcat/install/image/x86/imagename.tmpl
				  used in imaging process

=cut

sub _edit_template {
	my ($imagename, $drivetype) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'CRITICAL'}, 0, "drivetype is not defined")
	  if (!(defined($drivetype)));
	notify($ERRORS{'CRITICAL'}, 0, "imagename is not defined")
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
 Description : xCAT specific edits xcat's nodetype table with requested image name

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
	my $installmode        = shift;

	# Use the new image name if it is set
	$image_name = $self->data->get_image_name() if !$image_name;

	# Get the rest of the variables
	$computer_node_name = $self->data->get_computer_node_name() if !$computer_node_name;
	my $image_os_name         = $self->data->get_image_os_name();
	my $image_architecture    = $self->data->get_image_architecture();
	my $image_os_source_path  = $self->data->get_image_os_source_path();
	my $image_os_install_type = $self->data->get_image_os_install_type();

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
	if (!$image_os_install_type) {
		notify($ERRORS{'CRITICAL'}, 0, "image OS install type is not defined");
		return 0;
	}

	# set os
	my $osname = $image_os_name;
	# FIXME undo hardcode
	if ($installmode || $image_os_install_type eq 'partimage') {
		$image_os_name = 'image';
	}

	# Assemble the nodetype.tab and lock file paths
	my $lock_file_path = "/tmp/nodetype.lockfile";

	# Open the lock file
	if (sysopen(LOCKFILE, $lock_file_path, O_RDONLY | O_CREAT)) {
		notify($ERRORS{'DEBUG'}, 0, "opened $lock_file_path");

		# Set exclusive lock on lock file
		if (flock(LOCKFILE, LOCK_EX)) {
			notify($ERRORS{'DEBUG'}, 0, "set exclusive lock on $lock_file_path");

			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name, image=$image_name, os=$image_os_name, installtype=$image_os_install_type arch=$image_architecture, path=$image_os_source_path");
			if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.os=$image_os_name 2>&1 |")) {
				my @file = <NODECH>;
				close(NODECH);
				foreach my $l (@file) {
					# no output is good
					chomp $l;
					if ($l =~ /\w/) {
						notify($ERRORS{'WARNING'}, 0, "received output while setting OS for $computer_node_name: $l");
						close(LOCKFILE);
						return 1;
					}
				}
				notify($ERRORS{'OK'}, 0, "nodetype.os set to $image_os_name for $computer_node_name");
			} ## end if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.os=$image_os_name 2>&1 |"...
			else {
				# could not run nodech command
				notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodech command to set nodetype.os");
				close(LOCKFILE);
				return 1;
			}

			# set architecture
			if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.arch=$image_architecture 2>&1 |")) {
				my @file = <NODECH>;
				close(NODECH);
				foreach my $l (@file) {
					# no output is good
					chomp $l;
					if ($l =~ /\w/) {
						notify($ERRORS{'WARNING'}, 0, "received output while setting arch for $computer_node_name: $l");
						close(LOCKFILE);
						return 0;
					}
				}
				notify($ERRORS{'OK'}, 0, "nodetype.arch set to $image_architecture for $computer_node_name");
			} ## end if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.arch=$image_architecture 2>&1 |"...
			else {
				# could not run nodech command
				notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodech command to set nodetype.arch");
				close(LOCKFILE);
				return 0;
			}

			# set profile
			if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.profile=$image_name 2>&1 |")) {
				my @file = <NODECH>;
				close(NODECH);
				foreach my $l (@file) {
					# no output is good
					chomp $l;
					if ($l =~ /\w/) {
						notify($ERRORS{'WARNING'}, 0, "received output while setting profile for $computer_node_name: $l");
						close(LOCKFILE);
						return 0;
					}
				}
				notify($ERRORS{'OK'}, 0, "nodetype.profile set to $image_name for $computer_node_name");
			} ## end if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.profile=$image_name 2>&1 |"...
			else {
				# could not run nodech command
				notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodech command to set nodetype.profile");
				close(LOCKFILE);
				return 0;
			}

			notify($ERRORS{'OK'}, 0, "nodetype successfully updated for $computer_node_name");
			close(LOCKFILE);
			return 1;

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

	close(LOCKFILE);
	return 0;

} ## end sub _edit_nodetype

#/////////////////////////////////////////////////////////////////////////////

=head2  _edit_nodelist

 Parameters  : node
 Returns     : 0 failed or 1 success
 Description : xCAT specific edits xcat's nodelist table to have correct groups

=cut

sub _edit_nodelist {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Use arguments for computer and image if they were passed
	my $computer_node_name = shift;
	my $installmode        = shift;

	# Get the rest of the variables
	$computer_node_name = $self->data->get_computer_node_name() if !$computer_node_name;
	my $image_os_install_type = $self->data->get_image_os_install_type();
	my $image_project         = $self->data->get_image_project();

	# FIXME undo hardcode
	if ($installmode) {
		$image_os_install_type = 'partimage';
	}
		
	# Set postscript group name.
	# vcl = compute
	# vclhpc = vclhpc, should have xCAT group for specific postscripts
	my $postscript_project = $image_project;
	if($image_project eq "vcl"){
		$postscript_project = "compute";
	}

	# Check to make sure the variables are populated
	if (!$computer_node_name) {
		notify($ERRORS{'CRITICAL'}, 0, "computer node name is not defined");
		return 0;
	}
	if (!$image_os_install_type) {
		notify($ERRORS{'CRITICAL'}, 0, "image OS install type is not defined");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "$computer_node_name, installtype=$image_os_install_type");
	notify($ERRORS{'DEBUG'}, 0, "$computer_node_name, postscript_project=$postscript_project");

	my $oldlist = '';
	my $newlist = '';
	# get groups
	if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_node_name nodelist.groups 2>&1 |")) {
		my @file = <NODELS>;
		close(NODELS);
		foreach my $l (@file) {
			chomp $l;
			$l =~ s/$computer_node_name: //;
			$newlist = $l;
			$oldlist = $l;
			notify($ERRORS{'DEBUG'}, 0, "l is $l");
			if ($image_os_install_type eq 'partimage') {
				#this is a partimage based install
				$newlist = "all,blade,image";
			} ## end if ($image_os_install_type eq 'partimage')
			else {
				# this is a kickstart based install
				$newlist = "all,blade,$postscript_project";
			} ## end else [ if ($image_os_install_type eq 'partimage')
		} ## end foreach my $l (@file)
		notify($ERRORS{'DEBUG'}, 0, "old nodelist.groups=$oldlist, new nodelist.groups=$newlist");
	} ## end if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_node_name nodelist.groups 2>&1 |"...
	else {
		# could not run nodels command
		notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodels command to get nodelist.groups");
		return 1;
	}

	# set groups
	# Need to create a lockfile
	my $lock_file_path = "/tmp/nodelist.lockfile";

	# Open the lock file
	if (sysopen(LOCKFILE, $lock_file_path, O_RDONLY | O_CREAT)) {
		notify($ERRORS{'DEBUG'}, 0, "opened $lock_file_path");

		# Set exclusive lock on lock file
		if (flock(LOCKFILE, LOCK_EX)) {
			notify($ERRORS{'DEBUG'}, 0, "set exclusive lock on $lock_file_path");

			if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodelist.groups=$newlist 2>&1 |")) {
				my @file = <NODECH>;
				close(NODECH);
				foreach my $l (@file) {
					# no output is good
					chomp $l;
					if ($l =~ /\w/) {
						notify($ERRORS{'WARNING'}, 0, "received output while setting nodelist.groups for $computer_node_name: $l");
						close(LOCKFILE);
						return 0;
					}
				}

				notify($ERRORS{'OK'}, 0, "nodelist.groups set to $newlist for $computer_node_name");
				close(LOCKFILE);
				return 1;

			} ## end if (open(NODECH, "$XCAT_ROOT/bin/nodech $computer_node_name nodelist.groups=$newlist 2>&1 |"...
			else {
				# could not run nodech command
				notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodech command to set nodelist.groups");
				close(LOCKFILE);
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
} ## end sub _edit_nodelist
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
	if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $node stat |")) {
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
	} ## end if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $node stat |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute $XCAT_ROOT/bin/nodeset $node stat");
		return 0;
	}
} ## end sub _nodeset

#/////////////////////////////////////////////////////////////////////////////

=head2 _nodeset_option

 Parameters  : $node $option
 Returns     : xcat state of node or 0
 Description : using xcat nodeset cmd to use the input option of blade, xcat specific

=cut

sub _nodeset_option {
	# TODO check $option from all callers to make sure supported in v2
	my ($node, $option) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "_nodeset_option: node is not defined")
	  if (!(defined($node)));
	notify($ERRORS{'WARNING'}, 0, "_nodeset_option: option is not defined")
	  if (!(defined($option)));
	my ($blah, $case);
	my @file;
	my $l;

	if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $node $option |")) {
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
	} ## end if (open(NODESET, "$XCAT_ROOT/sbin/nodeset $node $option |"...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute $XCAT_ROOT/bin/nodeset $node $option");
		return 0;
	}

} ## end sub _nodeset_option

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
			notify($ERRORS{'OK'}, $log, "self is a hash reference");

			$computer_node_name      = $self->{hostname};
			$management_node_os_name = $self->{managementnode}->{OSNAME};
			$management_node_keys    = $self->{managementnode}->{keys};
			$computer_host_name      = $self->{hostname};
			$computer_ip_address     = $self->{IPaddress};
			$image_os_name           = $self->{currentimage}->{OS}->{name};
			$image_name              = $self->{currentimagerevision}->{imagename};
			$image_os_type           = $self->{currentimage}->{OS}->{type};

		} ## end if (ref($self) eq 'HASH')
		    # Check if node_status returned an array ref
		elsif (ref($self) eq 'ARRAY') {
			notify($ERRORS{'OK'}, 0, "self is a array reference");
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
		$log                 = 0;
	} ## end else [ if (ref($self) !~ /xcat/i)

	# Check the node name variable
	if (!defined($computer_node_name) || !$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "node name could not be determined");
		return;
	}
	notify($ERRORS{'OK'}, 0, "checking status of node: $computer_node_name");



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

	# Check the profile in the nodetype table
	notify($ERRORS{'OK'}, $log, "checking the current image listed in nodetype table for $computer_short_name");
	if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_short_name nodetype.profile 2>&1 |")) {
		my @file = <NODELS>;
		close(NODELS);
		foreach my $l (@file) {
			if ($l =~ /^$computer_short_name:\s+(.+)/) {
				my $nodetype_image_name = $1;
				notify($ERRORS{'OK'}, 0, "found image for $computer_short_name in nodetype table: $nodetype_image_name");
				$status{nodetype} = $nodetype_image_name;
			}
		}
	} ## end if (open(NODELS, "$XCAT_ROOT/bin/nodels $computer_short_name nodetype.profile 2>&1 |"...
	else {
		# could not run nodels command
		notify($ERRORS{'CRITICAL'}, 0, "could not run $XCAT_ROOT/bin/nodels command to get current image");
	}

	# Check if node is pingable
	notify($ERRORS{'OK'}, $log, "checking if $computer_short_name is pingable");
	if (_pingnode($computer_short_name)) {
		$status{ping} = 1;
		notify($ERRORS{'OK'}, $log, "$computer_short_name is pingable ($status{ping})");
	}
	else {
		$status{ping} = 0;
		notify($ERRORS{'OK'}, $log, "$computer_short_name is not pingable ($status{ping})");
	}

	# Check the rpower status
	notify($ERRORS{'OK'}, $log, "checking $computer_short_name xCAT rpower status");
	my $rpower_status = $self->_rpower($computer_short_name, "stat");
	if ($rpower_status =~ /on/i) {
		$status{rpower} = 1;
	}
	else {
		$status{rpower} = 0;
		
	}
	notify($ERRORS{'OK'}, $log, "$computer_short_name rpower status: $rpower_status ($status{rpower})");

	# Check the xCAT nodeset status
	notify($ERRORS{'OK'}, $log, "checking $computer_short_name xCAT nodeset status");
	my $nodeset_status = _nodeset($computer_short_name);
	notify($ERRORS{'OK'}, $log, "$computer_short_name nodeset status: $nodeset_status");
	$status{nodeset} = $nodeset_status;

	# Check the sshd status
	notify($ERRORS{'OK'}, $log, "checking if $computer_short_name sshd service is accessible");
	my $sshd_status = _sshd_status($computer_short_name, $status{nodetype}, $log);

	# If sshd is accessible, perform sshd-dependent checks
	if ($sshd_status =~ /on/) {
		$status{ssh} = 1;
		notify($ERRORS{'OK'}, $log, "$computer_short_name sshd service is accessible, performing dependent checks");

		# Check the currentimage.txt file on the node
		notify($ERRORS{'OK'}, $log, "checking image specified in currentimage.txt file on $computer_short_name");
		my $status_currentimage = $self->os->get_current_image_info("current_image_name");
		if ($status_currentimage) {
			notify($ERRORS{'OK'}, $log, "$computer_short_name currentimage.txt has: $status_currentimage");
			$status{currentimage} = $status_currentimage;
		}
		else {
			notify($ERRORS{'WARNING'}, $log, "$computer_short_name currentimage.txt could not be checked");
		}
	} ## end if ($sshd_status =~ /on/)
	else {
		$status{ssh} = 0;
		$status{status} = 'RELOAD';
		return \%status;
	}
	notify($ERRORS{'OK'}, $log, "$computer_short_name sshd status: $sshd_status ($status{ssh})");

	# Check if nodetype table matches reservation image name
	my $nodetype_image_match = 0;
	if ($status{nodetype} eq $image_name) {
		notify($ERRORS{'OK'}, $log, "nodetype table ($status{nodetype}) matches reservation image ($image_name)");
		$nodetype_image_match = 1;
	}
	else {
		notify($ERRORS{'OK'}, $log, "nodetype table ($status{nodetype}) does not match reservation image ($image_name)");
	}

	# Check if nodetype table matches currentimage.txt
	my $nodetype_currentimage_match = 0;
	if ($status{nodetype} eq $status{currentimage}) {
		notify($ERRORS{'OK'}, $log, "nodetype table ($status{nodetype}) matches currentimage.txt ($status{currentimage})");
		$nodetype_currentimage_match = 1;
	}
	else {
		notify($ERRORS{'OK'}, $log, "nodetype table ($status{nodetype}) does not match currentimage.txt ($status{currentimage}), assuming nodetype.tab is correct");
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
	if (!$nodetype_currentimage_match) {
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, $log, "currentimage.txt does not match requested image, node needs to be reloaded");
	}
	
	my $vcld_post_load_status = $self->data->get_computer_currentimage_vcld_post_load();

	# Node is up and doesn't need to be reloaded
	if ($status{status} =~ /ready/i) {
		notify($ERRORS{'OK'}, $log, "node is up and does not need to be reloaded");
		
		# Check if the OS post_load tasks have run
		if ($vcld_post_load_status) {
			notify($ERRORS{'OK'}, 0, "OS module post_load tasks have been completed on $computer_short_name");
			$status{status} = 'READY';
		}
		else {
			notify($ERRORS{'OK'}, 0, "OS module post_load tasks have not been completed on $computer_short_name, returning 'POST_LOAD'");
			$status{status} = 'POST_LOAD';
		}
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
	
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	
	# Get required image data
	my $image_name = $self->data->get_image_name();
	my $image_os_source_path = $self->data->get_image_os_source_path();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	if (!$image_name || !$image_os_source_path || !$image_os_install_type) {
		notify($ERRORS{'WARNING'}, 0, "required image data could not be retrieved");
		return;
	}
	
	# Remove trailing / from $XCAT_ROOT if exists
	(my $xcat_root = $XCAT_ROOT) =~ s/\/$//;
	
	# Remove trailing / from $image_os_source_path if exists
	$image_os_source_path =~ s/\/$//;
	
	# Fix the image OS source path for xCAT 2.x
	my $xcat2_image_os_source_path = $image_os_source_path;
	# Remove periods
	$xcat2_image_os_source_path =~ s/\.//g;
	# centos5 --> centos
	$xcat2_image_os_source_path =~ s/\d+$//g;
	# rhas5 --> rh
	$xcat2_image_os_source_path =~ s/^rh.*/rh/;
	# esxi --> esx
	$xcat2_image_os_source_path =~ s/^esx.*/esx/i;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to determine template path for image:
      image name:               $image_name
		OS install type:          $image_os_install_type
		OS source path:           $image_os_source_path
		xCAT 2.x OS source path:  $xcat2_image_os_source_path
	");

	my $image_template_path = "$xcat_root/share/xcat/install/$xcat2_image_os_source_path";
	notify($ERRORS{'DEBUG'}, 0, "returning: $image_template_path");
	return $image_template_path;
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

initialize() if (!$XCAT_ROOT);

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
