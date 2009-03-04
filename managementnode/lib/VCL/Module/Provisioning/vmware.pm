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
# $Id: vmware.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Provisioning::vmware - VCL module to support the vmware provisioning engine

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for vmware server
 http://www.vmware.com

=cut

##############################################################################
package VCL::Module::Provisioning::vmware;

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

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);

##############################################################################

=head1 CLASS ATTRIBUTES

=cut

=head2 %VMWARE_CONFIG

 Data type   : hash
 Description : %VMWARE_CONFIG is a hash containing the general VMWARE configuration
               for the management node this code is running on. Since the data is
					the same for every instance of the VMWARE class, a class attribute
					is used and the hash is shared among all instances. This also
					means that the data only needs to be retrieved from the database
					once.

=cut

#my %VMWARE_CONFIG;

# Class attributes to store VMWWARE configuration details
# This data also resides in the %VMWARE_CONFIG hash
# Extract hash data to scalars for ease of use
my $IMAGE_LIB_ENABLE  = $IMAGELIBENABLE;
my $IMAGE_LIB_USER    = $IMAGELIBUSER;
my $IMAGE_LIB_KEY     = $IMAGELIBKEY;
my $IMAGE_LIB_SERVERS = $IMAGESERVERS;

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
	notify($ERRORS{'DEBUG'}, 0, "vmware module initialized");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 provision

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads node with provided image

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_data = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# preform cleanup
	if ($self->control_VM("remove")) {
	}

	# Store some hash variables into local variables
	my $request_id     = $self->data->get_request_id;
	my $reservation_id = $self->data->get_reservation_id;
	my $persistent     = $self->data->get_request_forimaging;

	my $image_id       = $self->data->get_image_id;
	my $image_os_name  = $self->data->get_image_os_name;
	my $image_identity = $self->data->get_image_identity;
	my $image_os_type  = $self->data->get_image_os_type;

	my $vmclient_computerid = $self->data->get_computer_id;
	my $computer_shortname  = $self->data->get_computer_short_name;
	my $computer_nodename   = $computer_shortname;
	my $computer_hostname   = $self->data->get_computer_hostname;
	my $computer_type       = $self->data->get_computer_type;

	my $vmtype_name       = $self->data->get_vmhost_type_name;
	my $vmhost_vmpath     = $self->data->get_vmhost_profile_vmpath;
	my $vmprofile_vmdisk  = $self->data->get_vmhost_profile_vmdisk;
	my $datastorepath     = $self->data->get_vmhost_profile_datastore_path;
	my $datastorepath4vmx = $self->data->get_vmhost_profile_datastorepath_4vmx;
	my $virtualswitch0    = $self->data->get_vmhost_profile_virtualswitch0;
	my $virtualswitch1    = $self->data->get_vmhost_profile_virtualswitch1;
	my $vmtype            = $vmtype_name;

	my $requestedimagename = $self->data->get_image_name;
	my $shortname          = $computer_shortname;

	my $vmhost_imagename          = $self->data->get_vmhost_image_name;
	my $vmhost_hostname           = $self->data->get_vmhost_hostname;
	my $host_type                 = $self->data->get_vmhost_type;
	my $project                   = $self->data->get_image_project;
	my $vmclient_eth0MAC          = $self->data->get_computer_eth0_mac_address;
	my $vmclient_eth1MAC          = $self->data->get_computer_eth1_mac_address;
	my $vmclient_imageminram      = $self->data->get_image_minram;
	my $vmhost_RAM                = $self->data->get_vmhost_ram;
	my $vmclient_drivetype        = $self->data->get_computer_drive_type;
	my $vmclient_privateIPaddress = $self->data->get_computer_ip_address;
	my $vmclient_publicIPaddress  = $self->data->get_computer_private_ip_address;
	my $vmclient_OSname           = $self->data->get_image_os_name;
	# Assemble a consistent prefix for notify messages
	my $notify_prefix = "req=$request_id, res=$reservation_id:";

	#$VMWARErepository
	#if (!($vm{vmhost}{ok})) {
	#not ok to proceed
	#do we need to provide another resource?
	#fill in code to submit a request for another vmhost
	#}
	my @sshcmd;

	insertloadlog($reservation_id, $vmclient_computerid, "startload", "$computer_shortname $requestedimagename");
	my $starttime = convert_to_epoch_seconds;
	#proceed
	#$vm{"vmclient"}{"project"} = "vcl" if (!defined($vm{"vmclient"}{"project"}));


	my ($hostnode, $identity);
	if ($host_type eq "blade") {
		$hostnode = $1 if ($vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
		$identity = $IDENTITY_bladerhel;

		# assign2project is only for blades - and not all blades
		#if (VCL::Module::Provisioning::xCAT::_assign2project($hostnode, $project)) {
		#	notify($ERRORS{'OK'}, 0, "$hostnode assign2project return successful");
		#}
		#else {
		#	notify($ERRORS{'CRITICAL'}, 0, "$hostnode could not assign2project to $project");
		#	#return to get another machine
		#	return 0;
		#}
	} ## end if ($host_type eq "blade")
	else {
		#using FQHN
		$hostnode = $vmhost_hostname;
		$identity = $IDENTITY_linux_lab if ($vmhost_imagename =~ /^(realmrhel)/);
	}

	if (!(defined($identity))) {
		notify($ERRORS{'CRITICAL'}, 0, "identity variiable not definted, setting to blade identity file vmhost variable set to $vmhost_imagename");
		$identity = $IDENTITY_bladerhel;
	}

	notify($ERRORS{'OK'}, 0, "identity file set $identity  vmhost imagename $vmhost_imagename bladekey $IDENTITY_bladerhel");
	#setup flags
	my $baseexists   = 0;
	my $dirstructure = 0;

	#for convienence
	my ($myimagename, $myvmx, $myvmdir, $mybasedirname, $requestedimagenamebase);
	if ($persistent) {
		#either in imaging mode or special use
		$myvmdir       = "$reservation_id$computer_shortname";
		$myvmx         = "$vmhost_vmpath/$reservation_id$computer_shortname/$reservation_id$computer_shortname.vmx";
		$mybasedirname = "$reservation_id$computer_shortname";

		#if GSX use requested imagename
		$myimagename = $requestedimagename if ($vmtype =~ /(vmware|vmwareGSX)$/);
		#if ESX use requestid+shortname
		$myimagename = "$reservation_id$computer_shortname" if ($vmtype =~ /(vmwareESX3)/);

		#base directory should not exist for image creation
	} ## end if ($persistent)
	else {
		#standard use
		$myvmdir       = "$requestedimagename$computer_shortname";
		$myvmx         = "$vmhost_vmpath/$requestedimagename$computer_shortname/$requestedimagename$computer_shortname.vmx";
		$mybasedirname = $requestedimagename;
		$myimagename   = $requestedimagename;
	}

	notify($ERRORS{'DEBUG'}, 0, "persistent= $persistent");
	notify($ERRORS{'DEBUG'}, 0, "myvmdir= $myvmdir");
	notify($ERRORS{'DEBUG'}, 0, "myvmx= $myvmx");
	notify($ERRORS{'DEBUG'}, 0, "mybasedirname= $mybasedirname");
	notify($ERRORS{'DEBUG'}, 0, "myimagename= $myimagename");

	#does the requested base vmware image files already existed on the vmhost
	notify($ERRORS{'OK'}, 0, "checking for base image $myvmdir on $hostnode ");
	insertloadlog($reservation_id, $vmclient_computerid, "vmround1", "checking host for requested image files");

	#check for lock file - another process might be copying the same image files to the same host server
	my $tmplockfile = "/tmp/$hostnode" . "$requestedimagename" . "lock";
	notify($ERRORS{'OK'}, 0, "trying to create exclusive lock on $tmplockfile while checking if image files exist on host");
	if (sysopen(TMPLOCK, $tmplockfile, O_RDONLY | O_CREAT)) {
		if (flock(TMPLOCK, LOCK_EX)) {
			notify($ERRORS{'OK'}, 0, "owning exclusive lock on $tmplockfile");
			notify($ERRORS{'OK'}, 0, "listing datestore $datastorepath ");
			undef @sshcmd;
			@sshcmd = run_ssh_command($hostnode, $identity, "ls -1 $datastorepath", "root");
			notify($ERRORS{'OK'}, 0, "@{ $sshcmd[1] }");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /denied|No such/) {
					notify($ERRORS{'CRITICAL'}, 0, "node $hostnode output @{ $sshcmd[1] }");
					insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not log into vmhost $hostnode @{ $sshcmd[1] }");
					close(TMPLOCK);
					unlink($tmplockfile);
					return 0;
				}
				if ($l =~ /Warning: Permanently/) {
					#ignore
				}
				if ($l =~ /(\s*?)$mybasedirname$/) {
					notify($ERRORS{'OK'}, 0, "base image exists");
					$baseexists = 1;
				}
				#For persistent images - we rename the mybasedirname
				#If base really does exists and not inuse just rename directory for localdisk
				if ($l =~ /(\s*?)$requestedimagename$/) {
					notify($ERRORS{'OK'}, 0, "requestedimagenamebase image exists") if ($persistent);
					$requestedimagenamebase = 1;
				}
				if ($l eq "$myvmdir") {
					notify($ERRORS{'OK'}, 0, "directory structure $myvmdir image exists");
					$dirstructure = 1;
				}
			} ## end foreach my $l (@{$sshcmd[1]})

			if ($requestedimagenamebase && $persistent) {
				notify($ERRORS{'DEBUG'}, 0, "requestedimagenamebase and persistent are both true, attempting to detect status for move of base image instead of full copy");
				#Confirm base is not inuse then simply rename the directory to match our needs
				my $okforMOVE = 0;
				my @sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd -l", "root");
				foreach my $vm (@{$sshcmd[1]}) {
					chomp($vm);
					next if ($vm =~ /Warning:/);
					notify($ERRORS{'OK'}, 0, "$vm");
					if ($vm =~ /(.*)(\/)(.*)(\/)($requestedimagename[-_a-zA-Z0-9]*.vmx)/) {
						# do within this loop in case there is more than one
						my $localmyvmx   = "$1/$3/$5";
						my $localmyvmdir = "$1/$3";
						$localmyvmx   =~ s/(\s+)/\\ /g;
						$localmyvmdir =~ s/(\s+)/\\ /g;

						notify($ERRORS{'OK'}, 0, "my vmx $localmyvmx");
						my @sshcmd_1 = run_ssh_command($hostnode, $identity, "vmware-cmd $localmyvmx getstate");
						foreach my $l (@{$sshcmd_1[1]}) {
							if ($l =~ /= off/) {
								#Good
								$okforMOVE = 1;
							}
							elsif ($l =~ /= on/) {
								$baseexists = 0;
							}
						}

					} ## end if ($vm =~ /(.*)(\/)(.*)(\/)($requestedimagename[-_a-zA-Z0-9]*.vmx)/)
				} ## end foreach my $vm (@{$sshcmd[1]})
				if ($okforMOVE) {
					#use the mv command to rename the directory of the base image files
					notify($ERRORS{'DEBUG'}, 0, "simulating move of directory cmd= mv $vmhost_vmpath/$requestedimagename  $myvmdir");

				}

			} ## end if ($requestedimagenamebase && $persistent)
			if (!($baseexists)) {
				#check available disk space -- clean up if needed
				#copy vm files from local repository to vmhost
				#this could take a few minutes
				#get size of  vmdl files

				insertloadlog($reservation_id, $vmclient_computerid, "info", "image files do not exist on host server, preparing to copy");
				my $myvmdkfilesize = 0;
				if (open(SIZE, "du -k $VMWAREREPOSITORY/$requestedimagename 2>&1 |")) {
					my @du = <SIZE>;
					close(SIZE);
					foreach my $d (@du) {
						if ($d =~ /No such file or directory/) {
							insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not collect size of local image files");
							notify($ERRORS{'CRITICAL'}, 0, "problem checking local vm file size on $VMWAREREPOSITORY/$requestedimagename");
							close(TMPLOCK);
							unlink($tmplockfile);
							return 0;
						}
						if ($d =~ /^([0-9]*)/) {
							$myvmdkfilesize += $1;
						}
					} ## end foreach my $d (@du)
				} ## end if (open(SIZE, "du -k $VMWAREREPOSITORY/$requestedimagename 2>&1 |"...

				notify($ERRORS{'DEBUG'}, 0, "file size $myvmdkfilesize of $requestedimagename");
				notify($ERRORS{'OK'},    0, "checking space on $hostnode $vmhost_vmpath");
				undef @sshcmd;
				@sshcmd = run_ssh_command($hostnode, $identity, "df -k $vmhost_vmpath", "root");
				foreach my $l (@{$sshcmd[1]}) {
					next if ($l =~ /Warning: Permanently/);
					next if ($l =~ /^Filesystem/);
					if ($l =~ /\/dev\//) {
						#in k blocks
						my ($d, $s, $u, $a, $p, $m) = split(" ", $l);
						notify($ERRORS{'OK'}, 0, "datastore space available on remote machine $a ");
						#lets give ourselves at least double what the image needs for some buffer
						if ($a < ($myvmdkfilesize * 1.5)) {
							#free up space if possible only if $vm{vmhost}{vmware_disk} eq "localdisk"
							if ($vmprofile_vmdisk eq "localdisk") {
								notify($ERRORS{'OK'}, 0, "detected space issue on $hostnode, attempting to free up space");
								#remove stuff
								my %vmlist = ();
								my @sshcmd_1 = run_ssh_command($hostnode, $identity, "vmware-cmd -l", "root");
								my $i;
								foreach my $r (@{$sshcmd_1[1]}) {
									$i++;
									next if ($r =~ /^Warning: /);
									#if($r =~ /\/var\/lib\/vmware/){
									if ($r =~ /.vmx/) {
										chomp($r);
										notify($ERRORS{'OK'}, 0, "disk cleanup - pushing $r on array");
										$vmlist{$i}{"path"} = $r;
									}
								} ## end foreach my $r (@{$sshcmd_1[1]})

								foreach my $v (keys %vmlist) {
									#handle any spaces in the path
									$vmlist{$v}{path} =~ s/(\s+)/\\ /g;
									my @sshcmd_2 = run_ssh_command($hostnode, $identity, "vmware-cmd -q $vmlist{$v}{path} getstate", "root");
									foreach $a (@{$sshcmd_2[1]}) {
										next if ($a =~ /^Warning: /);
										chomp($a);
										if ($a =~ /^(on|off|stuck)/i) {
											$vmlist{$v}{"state"} = $a;
										}
										else{
											notify($ERRORS{'WARNING'}, 0, "unknown state $a for $vmlist{$v}{path} on $hostnode");
											$vmlist{$v}{"state"} = $a;
										}

									}
								} ## end foreach my $v (keys %vmlist)
								notify($ERRORS{'OK'}, 0, "ls datastorepath $datastorepath ");
								my @sshcmd_3 = run_ssh_command($hostnode, $identity, "ls -1 $datastorepath", "root");
								foreach my $d (@{$sshcmd_3[1]}) {
									next if ($d =~ /Warning: /);
									chomp($d);
									my $save = 0;
									foreach my $v (%vmlist) {
										#print "checking if $d is part of a running vm of $v\n";
										if ($vmlist{$v}{path} =~ /$d/) {
											if ($vmlist{$v}{state} eq "on") {
												$save = 1;
											}
											elsif ($vmlist{$v}{state} eq "off") {
												$save = 0;
												if (defined(run_ssh_command($hostnode, $identity, "vmware-cmd -s unregister $vmlist{$v}{path}", "root"))) {
													notify($ERRORS{'DEBUG'}, 0, "unregistered $vmlist{$v}{path}");
												}
											}
											elsif ($vmlist{$v}{state} eq "stuck") {
												$save = 1;
												notify($ERRORS{'DEBUG'}, 0, "vm on $hostnode in stuck state saving $vmlist{$v}{path}");
											}
											else {
												notify($ERRORS{'DEBUG'}, 0, "$vmlist{$v}{path} is in strange state $vmlist{$v}{state}");
											}
										} ## end if ($vmlist{$v}{path} =~ /$d/)
									} ## end foreach my $v (%vmlist)
									if ($save) {
										notify($ERRORS{'OK'}, 0, "disk cleanup - SAVING $datastorepath/$d");
									}
									else {
										notify($ERRORS{'OK'}, 0, "disk cleanup - REMOVING $datastorepath/$d");
										if (defined(run_ssh_command($hostnode, $identity, "/bin/rm -rf $datastorepath/$d\*", "root"))) {
											notify($ERRORS{'DEBUG'}, 0, "disk cleanup - REMOVED $datastorepath/$d\*");
										}
									}    #else not save
								}    #foreach vmdir
							}    #locadisk,
							else {
								notify($ERRORS{'CRITICAL'}, 0, "detected space issues from $hostnode this management node is configured to use network storage, not removing any data");
								return 0;
							}
						}    #start myvmdkfilesize comparsion
					}    # start if /dev
				}    # start foreach df -k
				if ($vmprofile_vmdisk eq "localdisk") {
					notify($ERRORS{'OK'}, 0, "copying base image files $requestedimagename to $hostnode");
					if (run_scp_command("$VMWAREREPOSITORY/$requestedimagename", "$hostnode:\"$datastorepath/$mybasedirname\"", $identity)) {
						#recheck host server for files - the  scp output is not being captured
						undef @sshcmd;
						@sshcmd = run_ssh_command($hostnode, $identity, "ls -1 $datastorepath", "root");
						foreach my $l (@{$sshcmd[1]}) {
							if ($l =~ /denied|No such/) {
								notify($ERRORS{'CRITICAL'}, 0, "node $hostnode output @{ $sshcmd[1] }");
								insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not log into vmhost $hostnode @{ $sshcmd[1] }");
								close(TMPLOCK);
								unlink($tmplockfile);
								return 0;
							}
							if ($l =~ /(\s*?)$mybasedirname$/) {
								notify($ERRORS{'OK'}, 0, "base image exists");
								$baseexists = 1;
								insertloadlog($reservation_id, $vmclient_computerid, "transfervm", "copying base image files");
							}
						} ## end foreach my $l (@{$sshcmd[1]})

					} ## end if (run_scp_command("$VMWAREREPOSITORY/$requestedimagename"...
					else {
						notify($ERRORS{'CRITICAL'}, 0, "problems scp vm files to $hostnode $!");
						close(TMPLOCK);
						unlink($tmplockfile);
						return 0;
					}
				} ## end if ($vmprofile_vmdisk eq "localdisk")
				elsif ($vmprofile_vmdisk eq "networkdisk") {
					if ($persistent) {
						#imaging mode -
						my $srcDisk = "$datastorepath/$requestedimagename/$requestedimagename" . ".vmdk";
						my $dstDisk = "$datastorepath/$mybasedirname/$myimagename" . ".vmdk";
						my $dstDir  = "$datastorepath/$mybasedirname";

						#create a clone -
						if (_vmwareclone($hostnode, $identity, $srcDisk, $dstDisk, $dstDir)) {
							$baseexists = 1;
							insertloadlog($reservation_id, $vmclient_computerid, "transfervm", "cloning base image files");
						}
						else {
							insertloadlog($reservation_id, $vmclient_computerid, "failed", "cloning base image failed");
							notify($ERRORS{'CRITICAL'}, 0, "problem cloning failed $srcDisk to $dstDisk");
							close(TMPLOCK);
							unlink($tmplockfile);
							return 0;
						}
					} ## end if ($persistent)
					else {
						notify($ERRORS{'CRITICAL'}, 0, "problems vmware disk set to network disk can not find image in $datastorepath");
						close(TMPLOCK);
						unlink($tmplockfile);
						return 0;
					}
				} ## end elsif ($vmprofile_vmdisk eq "networkdisk")  [ if ($vmprofile_vmdisk eq "localdisk")
				notify($ERRORS{'OK'}, 0, "confirm image exist process complete removing lock on $tmplockfile");
				close(TMPLOCK);
				unlink($tmplockfile);

			}    # start if base not exists
			else {
				#base exists
				notify($ERRORS{'OK'}, 0, "confirm image exist process complete removing lock on $tmplockfile");
				close(TMPLOCK);
				unlink($tmplockfile);
			}
		}    #flock
	}    #sysopen
	     #ok good base vm files exist on hostnode
	     #if guest dirstructure exists check state of vm, else create sturcture and new vmx file
	if (($dirstructure)) {
		#clean-up
		#make sure vm is off, it should be
		undef @sshcmd;
		@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx getstate", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /= off/) {
				#good
			}
			elsif ($l =~ /= on/) {
				my @sshcmd_1 = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx stop hard", "root");
				foreach my $a (@{$sshcmd_1[1]}) {
					next if ($a =~ /Warning:/);
					if ($a =~ /= 1/) {
						#turn off or killpid -- of course it should be off by  this point but kill
					}
					else {
						# FIX-ME add better error checking
						notify($ERRORS{'OK'}, 0, "@{ $sshcmd[1] }");
					}
				} ## end foreach my $a (@{$sshcmd_1[1]})
			} ## end elsif ($l =~ /= on/)  [ if ($l =~ /= off/)
		} ## end foreach my $l (@{$sshcmd[1]})
		    #if registered -  unregister vm
		undef @sshcmd;
		@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd -s unregister $myvmx", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /No such virtual machine/) {
				#not registered
				notify($ERRORS{'OK'}, 0, "vm $myvmx not registered");
			}
			if ($l =~ /= 1/) {
				notify($ERRORS{'OK'}, 0, "vm $myvmx unregistered");
			}
		}
		#delete directory -- clean slate
		# if in persistent mode - imaging or otherwise we may not want to rm this directory
		if (defined(run_ssh_command($hostnode, $identity, "/bin/rm -rf $vmhost_vmpath/$myvmdir", "root"))) {
			notify($ERRORS{'OK'}, 0, "success rm -rf $vmhost_vmpath/$myvmdir on $hostnode ");
		}

	} ## end if (($dirstructure))

	#setup new vmx file and directory for this request
	#create local directory
	#customize a vmx file
	# copy to vmhost
	# unlink local directory
	if (open(MKDIR, "/bin/mkdir /tmp/$myvmdir 2>&1 |")) {
		my @a = <MKDIR>;
		close(MKDIR);
		for my $l (@a) {
			notify($ERRORS{'OK'}, 0, "possible error @a");
		}
		notify($ERRORS{'OK'}, 0, "created tmp directory /tmp/$myvmdir");
	}
	else {
		notify($ERRORS{'OK'}, 0, "could not create tmp directory $myvmdir $!");
	}

	#check for dependent settings ethX
	if (!(defined($vmclient_eth0MAC))) {
		#complain
		notify($ERRORS{'CRITICAL'}, 0, "eth0MAC is not defined for $computer_shortname can not continue");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "eth0MAC address is not defined");
		return 0;

	}

	#check for memory settings
	my $dynamicmemvalue = "512";
	if (defined($vmclient_imageminram)) {
		#preform some sanity check
		if (($dynamicmemvalue < $vmclient_imageminram) && ($vmclient_imageminram < $vmhost_RAM)) {
			$dynamicmemvalue = $vmclient_imageminram;
			notify($ERRORS{'OK'}, 0, "setting memory to $dynamicmemvalue");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "image memory value $vmclient_imageminram out of the expected range in host machine $vmhost_RAM setting to 512");
		}
	} ## end if (defined($vmclient_imageminram))
	my $adapter = "ide";
	# database could be out of date
	if ($vmclient_drivetype =~ /hda/) {
		$adapter = "ide";
		notify($ERRORS{'OK'}, 0, "hda flag set, setting adapter to ide");
	}
	elsif ($vmclient_drivetype =~ /sda/) {
		$adapter = "buslogic";
		notify($ERRORS{'OK'}, 0, "sda flag set, setting adapter to buslogic");
	}

	my $listedadapter = 0;
	#scan vmdk file
	if (open(RE, "grep adapterType $VMWAREREPOSITORY/$requestedimagename/$requestedimagename.vmdk 2>&1 |")) {
		my @LIST = <RE>;
		close(RE);
		foreach my $a (@LIST) {
			if ($a =~ /(ide|buslogic|lsilogic)/) {
				$listedadapter = $1;
				notify($ERRORS{'OK'}, 0, "listedadapter= $1 ");
			}
		}
	} ## end if (open(RE, "grep adapterType $VMWAREREPOSITORY/$requestedimagename/$requestedimagename.vmdk 2>&1 |"...

	if ($listedadapter) {
		$adapter = $listedadapter;
	}

	notify($ERRORS{'OK'}, 0, "adapter= $adapter drivetype $vmclient_drivetype");
	my $guestOS;
	$guestOS = "winxppro" if ($requestedimagename =~ /(winxp)/i);
	$guestOS = "win2003"  if ($requestedimagename =~ /(win2003)/i);
	$guestOS = "ubuntu"   if ($requestedimagename =~ /(ubuntu)/i);


	my @vmxfile;
	my $tmpfile = "/tmp/$myvmdir/$myvmdir.vmx";
	my $tmpdir  = "/tmp/$myvmdir";

	push(@vmxfile, "#!/usr/bin/vmware\n");
	push(@vmxfile, "config.version = \"8\"\n");
	push(@vmxfile, "virtualHW.version = \"4\"\n");
	push(@vmxfile, "memsize = \"$dynamicmemvalue\"\n");
	push(@vmxfile, "displayName = \"$myvmdir\"\n");
	push(@vmxfile, "guestOS = \"$guestOS\"\n");
	push(@vmxfile, "uuid.location = \"56 4d 25 b7 07 18 f4 b6-25 d1 77 1e 10 bd 9e 99\"\n");
	push(@vmxfile, "uuid.bios = \"56 4d a8 df fb 38 d0 c5-25 73 d4 01 16 06 4e c0\"\n");
	push(@vmxfile, "Ethernet0.present = \"TRUE\"\n");
	push(@vmxfile, "Ethernet1.present = \"TRUE\"\n");

	if ($vmtype eq "vmwareESX3") {
		push(@vmxfile, "Ethernet0.networkName = \"$virtualswitch0\"\n");
		push(@vmxfile, "Ethernet1.networkName = \"$virtualswitch1\"\n");
		push(@vmxfile, "ethernet0.wakeOnPcktRcv = \"false\"\n");
		push(@vmxfile, "ethernet1.wakeOnPcktRcv = \"false\"\n");
	}
	elsif ($vmtype =~ /freeserver|gsx|vmwareGSX/) {
		push(@vmxfile, "Ethernet1.connectionType = \"custom\"\n");
		push(@vmxfile, "Ethernet1.vnet = \"$virtualswitch1\"\n");
	}

	push(@vmxfile, "ethernet0.address = \"$vmclient_eth0MAC\"\n");
	push(@vmxfile, "ethernet1.address = \"$vmclient_eth1MAC\"\n");
	push(@vmxfile, "ethernet0.addressType = \"static\"\n");
	push(@vmxfile, "ethernet1.addressType = \"static\"\n");
	push(@vmxfile, "gui.exitOnCLIHLT = \"FALSE\"\n");
	push(@vmxfile, "uuid.action = \"keep\"\n");
	push(@vmxfile, "snapshot.disabled = \"TRUE\"\n");
	push(@vmxfile, "floppy0.present = \"FALSE\"\n");
	push(@vmxfile, "priority.grabbed = \"normal\"\n");
	push(@vmxfile, "priority.ungrabbed = \"normal\"\n");
	push(@vmxfile, "checkpoint.vmState = \"\"\n");

	if ($adapter eq "ide") {
		push(@vmxfile, "scsi0.present = \"TRUE\"\n");
		push(@vmxfile, "ide0:0.present = \"TRUE\"\n");
		push(@vmxfile, "ide0:0.fileName =\"$datastorepath4vmx/$mybasedirname/$myimagename.vmdk\"\n");
		push(@vmxfile, "ide0:0.mode = \"independent-nonpersistent\"\n") if (!($persistent));
		push(@vmxfile, "ide0:0.mode = \"independent-persistent\"\n") if (($persistent));
		push(@vmxfile, "ide0:0.redo = \"./$myvmdir.vmdk.REDO_Y7VUab\"\n");
		push(@vmxfile, "ide1:0.autodetect = \"TRUE\"\n");
		push(@vmxfile, "ide1:0.startConnected = \"FALSE\"\n");
	} ## end if ($adapter eq "ide")
	elsif ($adapter =~ /buslogic|lsilogic/) {
		push(@vmxfile, "scsi0:0.present = \"TRUE\"\n");
		push(@vmxfile, "scsi0.present = \"TRUE\"\n");
		push(@vmxfile, "scsi0.sharedBus = \"none\"\n");
		push(@vmxfile, "scsi0:0.deviceType = \"scsi-hardDisk\"\n");
		push(@vmxfile, "scsi0.virtualDev = \"$adapter\"\n");
		push(@vmxfile, "scsi0:0.fileName =\"$datastorepath4vmx/$mybasedirname/$myimagename.vmdk\"\n");
		push(@vmxfile, "scsi0:0.mode = \"independent-nonpersistent\"\n") if (!($persistent));
		push(@vmxfile, "scsi0:0.mode = \"independent-persistent\"\n") if (($persistent));
		push(@vmxfile, "scsi0:0.redo = \"./$myvmdir.vmdk.REDO_Y7VUab\"\n");
	} ## end elsif ($adapter =~ /buslogic|lsilogic/)  [ if ($adapter eq "ide")

	#write to tmpfile
	if (open(TMP, ">$tmpfile")) {
		print TMP @vmxfile;
		close(TMP);
		notify($ERRORS{'OK'}, 0, "wrote vmxarray to $tmpfile");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not write vmxarray to $tmpfile");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not write vmx file to local tmp file");
		return 0;
	}

	#scp vmx file to vmdir on vmhost
	insertloadlog($reservation_id, $vmclient_computerid, "vmconfigcopy", "transferring vmx file to $hostnode");
	if (run_scp_command($tmpdir, "$hostnode:\"$vmhost_vmpath\"", $identity)) {
		my $copied = 0;
		undef @sshcmd;
		@sshcmd = run_ssh_command($hostnode, $identity, "ls -1 $vmhost_vmpath/$myvmdir;chmod 755 $myvmx", "root");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /$myvmdir.vmx/) {
				notify($ERRORS{'OK'}, 0, "successfully copied vmx file to $hostnode");
				$copied = 1;
				insertloadlog($reservation_id, $vmclient_computerid, "vmsetupconfig", "setting up vmx file");
			}
		}
		if (!($copied)) {
			#not good
			notify($ERRORS{'CRITICAL'}, 0, "failed to copy $tmpfile to $hostnode \noutput= @{ $sshcmd[1] }");
			insertloadlog($reservation_id, $vmclient_computerid, "failed", "failure to transfer vmx file to $hostnode");
			return 0;
		}

	}    #scp vmx tmpfile to host node
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to copy $tmpfile to $hostnode ");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "failure to transfer vmx file to $hostnode");
		return 0;
	}

	#remove tmpfile and tmpdirectory
	if (unlink($tmpfile)) {
		notify($ERRORS{'OK'}, 0, "successfully removed $tmpfile");
		notify($ERRORS{'OK'}, 0, "successfully removed tmp directory") if (rmdir("$tmpdir"));
	}


	#register vmx on vmhost
	my $registered = 0;
	undef @sshcmd;
	@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd -s register $myvmx", "root");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /No such virtual machine/) {
			#not registered
			notify($ERRORS{'CRITICAL'}, 0, "vm $myvmx vmx does not exist on $hostnode");
		}
		if ($l =~ /= 1/) {
			notify($ERRORS{'OK'}, 0, "vm $myvmx registered");
			$registered = 1;
		}
		if ($l =~ /Virtual machine already exists|VMControl error -999/) {
			notify($ERRORS{'WARNING'}, 0, "vm $myvmx already registered");
			$registered = 1;
		}
	} ## end foreach my $l (@{$sshcmd[1]})
	if (!($registered)) {
		#now what - complain
		notify($ERRORS{'CRITICAL'}, 0, "could not register vm $myvmx on $hostnode\n @{ $sshcmd[1] }");
		return 0;
	}


	#turn on vm
	#set loop control
	my $vmware_starts = 0;

	VMWARESTART:

	$vmware_starts++;
	notify($ERRORS{'OK'}, 0, "starting vm $myvmx - pass $vmware_starts");
	if ($vmware_starts > 2) {
		notify($ERRORS{'CRITICAL'}, 0, "vmware starts exceeded limit vmware_starts= $vmware_starts hostnode= $hostnode vm= $computer_shortname myvmx= $myvmx");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not load machine on $hostnode exceeded attempts");
		return 0;
	}

	undef @sshcmd;
	@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx start", "root");
	for my $l (@{$sshcmd[1]}) {
		next if ($l =~ /Warning:/);
		#if successful -- this cmd does not appear to return any ouput so anything could be a failure
		if ($l =~ /= 1/) {
			notify($ERRORS{'OK'}, 0, "started $myvmx on $hostnode");
		}
		elsif ($l =~ /VMControl error/) {
			notify($ERRORS{'OK'}, 0, "vmware-cmd start failed \n@{ $sshcmd[1] }");
			return 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "vmware-cmd cmd gave this output when trying to start $myvmx on $hostnode \n@{ $sshcmd[1] }");
		}
	} ## end for my $l (@{$sshcmd[1]})
	insertloadlog($reservation_id, $vmclient_computerid, "startvm", "started vm on $hostnode");

	#start monitoring
	# check state of vm
	# check messages log for boot info, DHCP requests, etc.A
	#  s1 = stage1 -- vm turned on
	#  s2 = stage2 -- DHCPDISCOVER on private mac
	#  s3 = stage3 --
	sleep 20;
	my ($s1, $s2, $s3, $s4, $s5) = 0;    #setup stage flags
	undef @sshcmd;
	@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx getstate", "root");
	notify($ERRORS{'OK'}, 0, "checking state of vm $computer_shortname");
	for my $l (@{$sshcmd[1]}) {
		next if ($l =~ /Warning:/);
		if ($l =~ /= on/) {
			#good stage 1
			$s1 = 1;
			insertloadlog($reservation_id, $vmclient_computerid, "vmstage1", "node has been turned on");
			notify($ERRORS{'OK'}, 0, "stage1 completed vm $computer_shortname has been turned on");
			notify($ERRORS{'OK'}, 0, "eth0MAC $vmclient_eth0MAC privateIPaddress $vmclient_privateIPaddress");
		}
	} ## end for my $l (@{$sshcmd[1]})
	my $sloop = 0;
	if ($s1) {
		#stage1 complete monitor local messages log for boot up info
		if (open(TAIL, "</var/log/messages")) {
			seek TAIL, -1, 2;    #
			for (;;) {
				notify($ERRORS{'OK'}, 0, "$computer_shortname ROUND 1 checks loop $sloop of 40");

				# re-check state of vm
				my @vmstate = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx getstate", "root");
				notify($ERRORS{'OK'}, 0, "rechecking state of vm $computer_shortname $myvmx");
				for my $l (@{$vmstate[1]}) {
					next if ($l =~ /Warning:/);
					if ($l =~ /= on/) {
						#good vm still on
						notify($ERRORS{'OK'}, 0, "vm $computer_shortname reports on");
					}
					elsif ($l =~ /= off/) {
						#good vm still on
						notify($ERRORS{'CRITICAL'}, 0, "state of vm $computer_shortname reports off after pass number $sloop attempting to restart: start attempts $vmware_starts");
						close(TAIL);
						goto VMWARESTART;
					}
					elsif ($l =~ /= stuck/) {
						notify($ERRORS{'CRITICAL'}, 0, "vm $computer_shortname reports stuck on pass $sloop attempting to kill pid and restart: restart attempts $vmware_starts");
						close(TAIL);
						#kill stuck process
						#list processes for vmx and kill pid
						notify($ERRORS{'OK'}, 0, "vm reported in stuck state, attempting to kill process");
						my @ssh_pid = run_ssh_command($hostnode, $identity, "vmware-cmd -q $myvmx getpid");
						foreach my $p (@{$ssh_pid[1]}) {
							if ($p =~ /(\D*)(\s*)([0-9]*)/) {
								my $vmpid = $3;
								if (defined(run_ssh_command($hostnode, $identity, "kill -9 $vmpid"))) {
									notify($ERRORS{'OK'}, 0, "killed $vmpid $myvmx");
								}
							}
						}
					} ## end elsif ($l =~ /= stuck/)  [ if ($l =~ /= on/)
				} ## end for my $l (@{$vmstate[1]})

				while (<TAIL>) {
					if ($_ =~ /$vmclient_eth0MAC|$vmclient_privateIPaddress|$computer_shortname/) {
						notify($ERRORS{'DEBUG'}, 0, "DEBUG output for $computer_shortname $_");
					}
					if (!$s2) {
						if ($_ =~ /dhcpd: DHCPDISCOVER from $vmclient_eth0MAC/) {
							$s2 = 1;
							insertloadlog($reservation_id, $vmclient_computerid, "vmstage2", "detected DHCP request for node");
							notify($ERRORS{'OK'}, 0, "$computer_shortname STAGE 2 set DHCPDISCOVER from $vmclient_eth0MAC");
						}
					}
					if (!$s3) {
						if ($_ =~ /dhcpd: DHCPACK on $vmclient_privateIPaddress to $vmclient_eth0MAC/) {
							$s3 = 1;
							insertloadlog($reservation_id, $vmclient_computerid, "vmstage3", "detected DHCPACK for node");
							notify($ERRORS{'OK'}, 0, "$computer_shortname STAGE 3 set DHCPACK on $vmclient_privateIPaddress to $vmclient_eth0MAC}");
						}
					}
					if (!$s4) {
						if ($_ =~ /dhcpd: DHCPACK on $vmclient_privateIPaddress to $vmclient_eth0MAC/) {
							$s4 = 1;
							insertloadlog($reservation_id, $vmclient_computerid, "vmstage4", "detected 2nd DHCPACK for node");
							notify($ERRORS{'OK'}, 0, "$computer_shortname STAGE 4 set another DHCPACK on $vmclient_privateIPaddress to $vmclient_eth0MAC");
						}
					}
					if (!$s5) {
						if ($_ =~ /$computer_shortname (.*) READY/i) {
							$s5 = 1;
							notify($ERRORS{'OK'}, 0, "$computer_shortname STAGE 5 set found READY flag");
							insertloadlog($reservation_id, $vmclient_computerid, "vmstage5", "detected READY flag proceeding to post configuration");
							#speed this up a bit
							close(TAIL);
							goto VMWAREROUND2;
						}

					} ## end if (!$s5)
					if ($sloop > 20) {
						#are we getting close
						if ($_ =~ /DHCPACK on $vmclient_privateIPaddress to $vmclient_eth0MAC}/) {
							#getting close -- extend it a bit
							notify($ERRORS{'OK'}, 0, "$computer_shortname is getting close extending wait time");
							insertloadlog($reservation_id, $vmclient_computerid, "info", "getting close node is booting");
							$sloop = $sloop - 8;
						}
						if ($_ =~ /$computer_shortname sshd/) {
							#getting close -- extend it a bit
							notify($ERRORS{'OK'}, 0, "$computer_shortname is getting close sshd is starting extending wait time");
							insertloadlog($reservation_id, $vmclient_computerid, "info", "getting close services are starting on node");
							$sloop = $sloop - 5;
						}

						my $sshd_status = _sshd_status($computer_shortname, $requestedimagename,$image_os_type);
						if ($sshd_status eq "on") {
							notify($ERRORS{'OK'}, 0, "$computer_shortname now has active sshd running, maybe we missed the READY flag setting STAGE5 flag");
							$s5 = 1;
							#speed this up a bit
							close(TAIL);
							goto VMWAREROUND2;
						}
					} ## end if ($sloop > 20)

				}    #while

				if ($s5) {
					#good
					close(TAIL);
					goto VMWAREROUND2;
				}
				elsif ($sloop > 65) {
					#taken too long -- do something different or fail it

					notify($ERRORS{'CRITICAL'}, 0, "could not load $myvmx on $computer_shortname on host $hostnode");
					insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not load vmx on $hostnode");
					close(TAIL);
					return 0;

				}
				else {
					#keep check the log
					$sloop++;
					sleep 10;
					seek TAIL, 0, 1;
				}
			}    # for loop
		}    #if tail
	}    #if stage1
	else {
		notify($ERRORS{'CRITICAL'}, 0, "stage1 not confirmed, could not determine if $computer_shortname was turned on on host $hostnode");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not determine if node was turned on on $hostnode");
		return 0;
	}
	my $sshd_attempts = 0;

	VMWAREROUND2:

	#READY flag set
	#attempt to login via ssh
	insertloadlog($reservation_id, $vmclient_computerid, "vmround2", "waiting for ssh to become active");
	notify($ERRORS{'OK'}, 0, "READY flag set for $myvmx, proceeding");
	my $sshdstatus = 0;
	my $wait_loops = 0;
	$sshd_attempts++;
	my $sshd_status = "off";
	while (!$sshdstatus) {
		my $sshd_status = _sshd_status($computer_shortname, $requestedimagename,$image_os_type);
		if ($sshd_status eq "on") {
			$sshdstatus = 1;
			notify($ERRORS{'OK'}, 0, "$computer_shortname now has active sshd running, ok to proceed to sync ssh keys");
		}
		else {
			#either sshd is off or N/A, we wait
			if ($wait_loops > 5) {
				if ($sshd_attempts < 3) {
					goto VMWAREROUND2;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "waited acceptable amount of time for sshd to become active, please check $computer_shortname on $hostnode");
					insertloadlog($reservation_id, $vmclient_computerid, "failed", "waited acceptable amout of time for core services to start on $hostnode");
					#need to check power, maybe reboot it. for now fail it
					return 0;
				}
			} ## end if ($wait_loops > 5)
			else {
				$wait_loops++;
				# to give post config a chance
				notify($ERRORS{'OK'}, 0, "going to sleep 5 seconds, waiting for post config to finish");
				sleep 5;
			}
		}    # else
	}    #while

	#clear ssh public keys from /root/.ssh/known_hosts
	my $known_hosts = "/root/.ssh/known_hosts";
	my $ssh_keyscan = "/usr/bin/ssh-keyscan";
	my $port        = "22";
	my @file;
	if (open(FILE, $known_hosts)) {
		@file = <FILE>;
		close FILE;

		foreach my $line (@file) {
			if ($line =~ s/$computer_shortname.*\n//) {
				notify($ERRORS{'OK'}, 0, "removing $computer_shortname ssh public key from $known_hosts");
			}
			if ($line =~ s/$vmclient_privateIPaddress}.*\n//) {
				notify($ERRORS{'OK'}, 0, "removing $vmclient_privateIPaddress ssh public key from $known_hosts");
			}
		}

		if (open(FILE, ">$known_hosts")) {
			print FILE @file;
			close FILE;
		}
		#sync new keys
		if (open(KEYSCAN, "$ssh_keyscan -t rsa -p $port $computer_shortname >> $known_hosts 2>&1 |")) {
			my @ret = <KEYSCAN>;
			close(KEYSCAN);
			foreach my $r (@ret) {
				notify($ERRORS{'OK'}, 0, "$r");
			}
		}
	} ## end if (open(FILE, $known_hosts))
	else {
		notify($ERRORS{'OK'}, 0, "could not open $known_hosts for editing the $computer_shortname public ssh key");
	}

	insertloadlog($reservation_id, $vmclient_computerid, "info", "starting post configurations on node");
	if ($vmclient_OSname =~ /vmwarewin|vmwareesxwin/) {
		if (changewindowspasswd($computer_shortname, "root")) {
			notify($ERRORS{'OK'}, 0, "Successfully changed password, account $computer_shortname,root");
		}

		if (changewindowspasswd($computer_shortname, "administrator")) {
			notify($ERRORS{'OK'}, 0, "Successfully changed password, account $computer_shortname,administrator");
		}
		#disable remote desktop port
		if (remotedesktopport($computer_shortname, "DISABLE")) {
			notify($ERRORS{'OK'}, 0, "remote desktop disabled on $computer_shortname");
		}
		else {
			notify($ERRORS{'OK'}, 0, "remote desktop not disable on $computer_shortname");
		}

		# set sshd to auto
		if (_set_sshd_startmode($computer_shortname, "auto")) {
			notify($ERRORS{'OK'}, 0, "successfully set sshd service on $computer_shortname to start auto");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to set sshd service on $computer_shortname to start auto");
		}

		#check for root logged in on console and then logoff
		notify($ERRORS{'OK'}, 0, "checking for any console users $computer_shortname");
		undef @sshcmd;
		@sshcmd = run_ssh_command($computer_shortname, $IDENTITY_wxp, "cmd /c qwinsta.exe", "root");
		foreach my $r (@{$sshcmd[1]}) {
			if ($r =~ /([>]?)([-a-zA-Z0-9]*)\s+([a-zA-Z0-9]*)\s+ ([0-9]*)\s+([a-zA-Z]*)/) {
				my $state   = $5;
				my $session = $2;
				my $user    = $3;
				if ($5 =~ /Active/) {
					#give it sometime to finish - just in case
					sleep 7;
					notify($ERRORS{'OK'}, 0, "detected $user on $session still logged on $computer_shortname $r");
					if (defined(run_ssh_command($computer_shortname, $IDENTITY_wxp, "cmd /c logoff.exe $session", "root"))) {
						notify($ERRORS{'OK'}, 0, "logged off $user on $session on $computer_shortname $r");
					}
				}
			} ## end if ($r =~ /([>]?)([-a-zA-Z0-9]*)\s+([a-zA-Z0-9]*)\s+ ([0-9]*)\s+([a-zA-Z]*)/)
		} ## end foreach my $r (@{$sshcmd[1]})
	} ## end if ($vmclient_OSname =~ /vmwarewin|vmwareesxwin/)
	    #ipconfiguration
	if ($IPCONFIGURATION ne "manualDHCP") {
		#not default setting
		if ($IPCONFIGURATION eq "dynamicDHCP") {
			insertloadlog($reservation_id, $vmclient_computerid, "dynamicDHCPaddress", "collecting dynamic IP address for node");
			my $assignedIPaddress = getdynamicaddress($computer_shortname, $vmclient_OSname,$image_os_type);
			if ($assignedIPaddress) {
				#update computer table
				if (update_computer_address($vmclient_computerid, $assignedIPaddress)) {
					notify($ERRORS{'DEBUG'}, 0, " succesfully updated IPaddress of node $computer_shortname");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "could not update dynamic address $assignedIPaddress for $computer_shortname $requestedimagename");
					return 0;
				}
			} ## end if ($assignedIPaddress)
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not fetch dynamic address from $computer_shortname $requestedimagename");
				insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not collect dynamic IP address for node");
				return 0;
			}
		} ## end if ($IPCONFIGURATION eq "dynamicDHCP")
		elsif ($IPCONFIGURATION eq "static") {
			insertloadlog($reservation_id, $vmclient_computerid, "staticIPaddress", "setting static IP address for node");
			if (setstaticaddress($computer_shortname, $vmclient_OSname, $vmclient_publicIPaddress,$image_os_type)) {
				# good set static address
			}
		}
	} ## end if ($IPCONFIGURATION ne "manualDHCP")
	    #
	insertloadlog($reservation_id, $vmclient_computerid, "vmwareready", "preformed post config on node");
	return 1;

} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : $request_data_hash_reference
 Returns     : 1 if sucessful, 0 if failed
 Description : Creates a new vmware image.

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my ($package, $filename, $line, $sub) = caller(0);

	# Store some hash variables into local variables
	# to pass to write_current_image routine
	my $request_data = $self->data->get_request_data;

	if (!$request_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve request data hash");
		return 0;
	}

	# Store some hash variables into local variables
	my $request_id     = $self->data->get_request_id;
	my $reservation_id = $self->data->get_reservation_id;

	my $image_id       = $self->data->get_image_id;
	my $image_os_name  = $self->data->get_image_os_name;
	my $image_identity = $self->data->get_image_identity;
	my $image_os_type  = $self->data->get_image_os_type;
	my $image_name          = $self->data->get_image_name();


	my $imagemeta_sysprep = $self->data->get_imagemeta_sysprep;

	my $computer_id        = $self->data->get_computer_id;
	my $computer_shortname = $self->data->get_computer_short_name;
	my $computer_nodename  = $computer_shortname;
	my $computer_hostname  = $self->data->get_computer_hostname;
	my $computer_type      = $self->data->get_computer_type;

	my $vmtype_name             = $self->data->get_vmhost_type_name;
	my $vmhost_vmpath           = $self->data->get_vmhost_profile_vmpath;
	my $vmprofile_vmdisk        = $self->data->get_vmhost_profile_vmdisk;
	my $vmprofile_datastorepath = $self->data->get_vmhost_profile_datastore_path;
	my $vmhost_hostname         = $self->data->get_vmhost_hostname;
	my $host_type               = $self->data->get_vmhost_type;
	my $vmhost_imagename        = $self->data->get_vmhost_image_name;

	my ($hostIdentity, $hostnodename);
	if ($host_type eq "blade") {
		$hostnodename = $1 if ($vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
		$hostIdentity = $IDENTITY_bladerhel;
	}
	else {
		#using FQHN
		$hostnodename = $vmhost_hostname;
		$hostIdentity = $IDENTITY_linux_lab if ($vmhost_imagename =~ /^(realmrhel)/);
	}
	# Assemble a consistent prefix for notify messages
	my $notify_prefix = "req=$request_id, res=$reservation_id:";


	# Print some preliminary information
	notify($ERRORS{'OK'}, 0, "$notify_prefix new name: $image_name");
	notify($ERRORS{'OK'}, 0, "$notify_prefix computer_name: $computer_shortname");
	notify($ERRORS{'OK'}, 0, "$notify_prefix vmhost_hostname: $vmhost_hostname");
	notify($ERRORS{'OK'}, 0, "$notify_prefix vmtype_name: $vmtype_name");

	# Modify currentimage.txt
	if (write_currentimage_txt($self->data)) {
		notify($ERRORS{'OK'}, 0, "$notify_prefix currentimage.txt updated on $computer_shortname");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix unable to update currentimage.txt on $computer_shortname");
	}

	# Set some vm paths and names
	my $vmx_directory  = "$reservation_id$computer_shortname";
	my $vmx_image_name = "$reservation_id$computer_shortname";
	my $vmx_path       = "$vmhost_vmpath/$vmx_directory/$vmx_image_name.vmx";

	my @sshcmd;

	# Check the vm type
	if ($vmtype_name =~ /vmware|vmwareESX/) {

		#if windows
		#set sshd to mode= demand
		# disable pagefile
		# reboot
		# check for and remove pagefile
		# if sysprep-- copy sysprep files and start
		#    delay 15 secs turn vm off
		# if not sysprep i.e. newsid
		#    copy appropriate files, execute and wait for shutdown signal
		#
		# is os windows
		if ($image_name =~ /^(vmwarewinxp|vmwarewin2003|vmwareesxwin)/) {
			#change password of root and sshd service back to default
			# only useful on win platforms
			# changewindowspasswd($node,$account,$passwd)
			# needed only for sshd service on windows OS's
			my $p = $WINDOWS_ROOT_PASSWORD;
			if (changewindowspasswd($computer_shortname, "root", $p)) {
				notify($ERRORS{'OK'}, 0, "$notify_prefix changed windows password $computer_shortname,root,$p");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$notify_prefix failed to change windows password $computer_shortname,root,$p");
				return 0;
			}

			#defrag before removing pagefile
			# we do this to speed up the process
			# defraging without a page file takes a little longer
			notify($ERRORS{'OK'}, 0, "starting defrag on $computer_nodename");
			@sshcmd = run_ssh_command($computer_nodename, $IDENTITY_wxp, "cmd.exe /c defrag C: -f", "root");
			my $defragged = 0;
			foreach my $d (@{$sshcmd[1]}) {
				if ($d =~ /Defragmentation Report/) {
					notify($ERRORS{'OK'}, 0, "successfully defraged $computer_nodename");
					$defragged = 1;
				}
			}
			if (!$defragged) {
				notify($ERRORS{'WARNING'}, 0, "defrag problem @{ $sshcmd[1] }");
			}

			#copy new auto_create_image.vbs and auto_prepare_for_image.vbs
			#this moves(sometimes) the pagefile and reboots the box
			#actually checks for a removes the pagefile.sys
			my @scp;
			if (run_scp_command("$TOOLS/auto_create_image.vbs", "$computer_nodename:auto_create_image.vbs", $IDENTITY_wxp)) {
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to scp $TOOLS/auto_create_image.vbs to $computer_nodename");
				return 0;
			}

			if (_set_sshd_startmode($computer_nodename, "auto")) {
				notify($ERRORS{'OK'}, 0, "successfully set auto mode for sshd start");
			}

			my @list;
			my $l;
#execute the vbs script to disable the pagefil and reboot
			undef @sshcmd;
			@sshcmd = run_ssh_command($computer_nodename, $IDENTITY_wxp, "cscript.exe //Nologo auto_create_image.vbs", "root");
			#starting process
			foreach $l (@{$sshcmd[1]}) {
				if ($l =~ /createimage reboot|rebooting/) {
					notify($ERRORS{'OK'}, 0, "auto_create_image.vbs initiated, $computer_nodename rebooting, sleeping 90");
					sleep 90;
					next;
				}
				elsif ($l =~ /failed error/) {
					notify($ERRORS{'CRITICAL'}, 0, "auto_create_image.vbs failed, @{ $sshcmd[1] }");
					return 0;
				}
			} ## end foreach $l (@{$sshcmd[1]})
			    #wait until the reboot process has started to shutdown services.
			notify($ERRORS{'OK'}, 0, "$computer_nodename rebooting, waiting");
			my $socketflag = 0;
			REBOOTEDVMWARE:
			my $rebooted          = 1;
			my $reboot_wait_count = 0;
			while ($rebooted) {

				if ($reboot_wait_count > 55) {
					notify($ERRORS{'CRITICAL'}, 0, "waited $reboot_wait_count on reboot after auto_create_image on $computer_nodename");
					return 0;
				}
				notify($ERRORS{'OK'}, 0, "$computer_nodename not completed reboot sleeping for 25");
				sleep 15;
				if (_pingnode($computer_nodename)) {
					#it pingable check if sshd is open
					notify($ERRORS{'OK'}, 0, "$computer_nodename is pingable, checking sshd port");
					my $sshd = _sshd_status($computer_nodename, $image_name,$image_os_type);
					if ($sshd =~ /on/) {
						$rebooted = 0;
						notify($ERRORS{'OK'}, 0, "$computer_nodename sshd is open");
					}
					else {
						notify($ERRORS{'OK'}, 0, "$computer_nodename sshd NOT open yet,sleep 5");
						sleep 5;
					}
				} ## end if (_pingnode($computer_nodename))
				$reboot_wait_count++;
			} ## end while ($rebooted)
			    #check for recent bug
			undef @sshcmd;
			@sshcmd = run_ssh_command($computer_nodename, $IDENTITY_wxp, "uname -s", "root");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /^Warning:/) {
				}
				if ($l =~ /^Read from socket failed:/) {
					if ($socketflag) {
						notify($ERRORS{'CRITICAL'}, 0, "could not login $computer_nodename via ssh socket failure");
						return 0;
					}
					notify($ERRORS{'CRITICAL'}, 0, "discovered ssh read from socket failure on $computer_nodename, attempting to repair");
					#power cycle node
					if (defined(run_ssh_command($computer_nodename, $image_identity, "vmware-cmd $vmx_path reset hard", "root"))) {
						notify($ERRORS{'CRITICAL'}, 0, "$computer_nodename reset cycled going to reboot check routine");
						sleep 30;
						$socketflag = 1;
						goto REBOOTEDVMWARE;
					}
				} ## end if ($l =~ /^Read from socket failed:/)
			} ## end foreach my $l (@{$sshcmd[1]})

			#
			#actually remove the pagefile.sys sometimes movefile.exe does not work
			if (defined(run_ssh_command($computer_nodename, $IDENTITY_wxp, "/usr/bin/rm -v C:\/pagefile.sys", "root"))) {
				notify($ERRORS{'OK'}, 0, "removed pagefile.sys");
			}

			# which sysprep to use
			#TODO - store volume license keys in database
			my $sysprep_files;
			if ($image_name =~ /(^vmwarewinxp|vmwareesxwinxp)/) {
				$sysprep_files = "$SYSPREP_VMWARE";
			}
			elsif ($image_name =~ /(^vmwarewin2003|vmwareesxwin2003)/) {
				$sysprep_files = "$SYSPREP_VMWARE2003";
			}

			#cp sysprep to C:
			#chmod C:\Sysprep\*
			if (defined(run_scp_command($sysprep_files, "$computer_nodename:\"C:\/Sysprep\"", $IDENTITY_wxp))) {
				notify($ERRORS{'OK'}, 0, "copied Sysprep directory $sysprep_files to $computer_nodename C:");
				if (defined(run_ssh_command($computer_nodename, $IDENTITY_wxp, "/usr/bin/chmod -R 755 C:\/Sysprep", "root"))) {
					notify($ERRORS{'OK'}, 0, "chmoded -R C:/Sysprep/ files ");
				}
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not copy $sysprep_files to $computer_nodename");
				return 0;
			}

			#set sshd to manual
			if (_set_sshd_startmode($computer_nodename, "manual")) {
				notify($ERRORS{'OK'}, 0, "successfully set manual mode for sshd start");
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to set manual mode for sshd on $computer_nodename");
				return 0;
			}
			#start sysprep
			#after 15 time units -- kill  sysprep process
			# in this case also stop vm using vmware-cmd

			notify($ERRORS{'OK'}, 0, "starting sysprep on $computer_nodename");

			my $vmisoff = 0;

			if (open(SSH, "/usr/bin/ssh -x -i $IDENTITY_wxp $computer_nodename \"C:\/Sysprep\/sysprep.cmd\" 2>&1 |")) {
				my $notstop = 1;
				my $loop    = 0;
				while ($notstop) {
					notify($ERRORS{'DEBUG'}, 0, "$notify_prefix sysprep.cmd loop count: $loop");
					$loop++;
					my $l = <SSH>;
					if ($l =~ /sysprep/) {
						notify($ERRORS{'OK'}, 0, "sysprep started, sleep 45 before disconecting");
						sleep 45;

						notify($ERRORS{'DEBUG'}, 0, "attempting to kill sysprep");
						if (_killsysprep($computer_nodename)) {
							notify($ERRORS{'OK'}, 0, "killed sshd process for sysprep command");
						}

						$notstop = 0;
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

					notify($ERRORS{'DEBUG'}, 0, "sysprep cmd output: $l");

					#avoid infinite loop
					if ($loop > 80) {
						notify($ERRORS{'OK'},    0, "sysprep executed, sleep 20 before disconecting");
						notify($ERRORS{'DEBUG'}, 0, "sysprep executed in loop control condition, exceeded limit");
						sleep 20;
						notify($ERRORS{'DEBUG'}, 0, "attempting to kill sysprep");
						if (_killsysprep($computer_nodename)) {
							notify($ERRORS{'OK'}, 0, "killed sshd process for sysprep command");
						}
						notify($ERRORS{'DEBUG'}, 0, "closing SSH filehandle");
						close(SSH);
						notify($ERRORS{'DEBUG'}, 0, "SSH filehandle closed");

						$notstop = 0;
					} ## end if ($loop > 80)

				} ## end while ($notstop)
				    #stop vm
				    #ping to make sure host is offline
				my $online   = 1;
				my $pingloop = 0;
				notify($ERRORS{'OK'}, 0, "checking for pingable $computer_nodename");
				while ($online) {
					if (!(_pingnode($computer_nodename))) {
						notify($ERRORS{'OK'}, 0, "$computer_nodename is not pingable");
						$online = 0;
					}
					else {
						notify($ERRORS{'OK'}, 0, "$computer_nodename is still pingable");
						sleep 10;
						$pingloop++;
					}
					if ($pingloop > 10) {
						notify($ERRORS{'CRITICAL'}, 0, "failed on sysprep process for $computer_nodename");
						return 0;
					}
				} ## end while ($online)
				    # we have to stop the vm due to sysprep not shutting down the machine -- even with the forceshutdown option
				notify($ERRORS{'OK'},    0, "stopping vm $vmx_path on $hostnodename");
				notify($ERRORS{'DEBUG'}, 0, "stopping vm $vmx_path on hostnodename $hostnodename identity= $hostIdentity ");
				my @vmstop = run_ssh_command($hostnodename, $hostIdentity, "vmware-cmd $vmx_path stop hard", "root");
				foreach my $l (@{$vmstop[1]}) {
					next if ($l =~ /Warning: Permanently/);
					if ($l =~ /= 1/) {
						notify($ERRORS{'OK'}, 0, "SUCCESS vmware-cmd stop worked");
					}
				}
				#sleep a bit to let it shutdown
				sleep 15;
				#confirm
				undef @sshcmd;
				@sshcmd = run_ssh_command($hostnodename, $hostIdentity, "vmware-cmd $vmx_path getstate", "root");

				foreach my $l (@{$sshcmd[1]}) {
					if ($l =~ /= off/) {
						#good
						notify($ERRORS{'OK'}, 0, "SUCCESS turned off $vmx_path");
						$vmisoff = 1;
					}
				}
				if (!$vmisoff) {
					notify($ERRORS{'CRITICAL'}, 0, "$vmx_path still reported on");
					return 0;
				}
			}    #start sysprep command
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to start sysprep on $computer_nodename $!");
				return 0;
			}

		}    #if windows
		     #this only applies to localdisk settings
		if ($vmprofile_vmdisk eq "localdisk") {
			#only copy vmdk files back to management node -- into correct directory
			if (open(MKDIR, "/bin/mkdir $VMWAREREPOSITORY/$image_name 2>&1 |")) {
				my @a = <MKDIR>;
				close(MKDIR);
				for my $l (@a) {
					notify($ERRORS{'OK'}, 0, "possible error @a");
				}
				notify($ERRORS{'OK'}, 0, "created tmp directory $VMWAREREPOSITORY/$image_name");
			}
			if (-d "$VMWAREREPOSITORY/$image_name") {
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not create tmp directory $VMWAREREPOSITORY/$image_name for $vmx_directory $!");
				return 0;
			}
			#copy vmdk files
			# confirm they were copied
			notify($ERRORS{'OK'}, 0, "attemping to copy vmdk files to $VMWAREREPOSITORY");
			if (run_scp_command("$hostnodename:\"$vmhost_vmpath/$vmx_directory/*.vmdk\"", "$VMWAREREPOSITORY/$image_name", $hostIdentity)) {
				if (open(LISTFILES, "ls -s1 $VMWAREREPOSITORY/$image_name |")) {
					my @list = <LISTFILES>;
					close(LISTFILES);
					my $numfiles  = @list;
					my $imagesize = getimagesize($image_name);
					if ($imagesize) {
						notify($ERRORS{'OK'}, 0, "copied $numfiles vmdk files imagesize= $imagesize");
					}
					else {
						notify($ERRORS{'OK'}, 0, "vmdk files are not copied");
						return 0;
					}
					#renaming local vmdk files
					notify($ERRORS{'OK'}, 0, "begin rename local disk image files to newname");
					my $oldname;
					if (open(LISTFILES, "ls -1 $VMWAREREPOSITORY/$image_name 2>&1 |")) {
						my @list = <LISTFILES>;
						close(LISTFILES);
						my $numfiles = @list;
						#figure out old name
						foreach my $a (@list) {
							chomp($a);
							if ($a =~ /([a-z]*)-([_0-9a-zA-Z]*)-(v[0-9]*)\.vmdk/) {
								#print "old name $1-$2-$3\n";
								$oldname = "$1-$2-$3";
								notify($ERRORS{'OK'}, 0, "found previous name= $oldname");
							}
						}
						foreach my $b (@list) {
							chomp($b);
							if ($b =~ /($oldname)-(s[0-9]*)\.vmdk/) {
								notify($ERRORS{'OK'}, 0, "moving $b to $image_name-$2.vmdk");
								if (open(MV, "mv $VMWAREREPOSITORY/$image_name/$b $VMWAREREPOSITORY/$image_name/$image_name-$2.vmdk 2>&1 |")) {
									my @mv = <MV>;
									close(MV);
									if (@mv) {
										notify($ERRORS{'CRITICAL'}, 0, "could not move $b to $VMWAREREPOSITORY/$image_name/$image_name-$2.vmdk \n@mv");
										return 0;
									}
								}
								notify($ERRORS{'OK'}, 0, "moved $b $VMWAREREPOSITORY/$image_name/$image_name-$2.vmdk");
							} ## end if ($b =~ /($oldname)-(s[0-9]*)\.vmdk/)
						} ## end foreach my $b (@list)

						if (open(FILE, "$VMWAREREPOSITORY/$image_name/$oldname.vmdk")) {
							my @file = <FILE>;
							close(FILE);
							for my $l (@file) {
								#RW 4192256 SPARSE "vmwarewinxp-base10009-v1-s001.vmdk"
								if ($l =~ /([0-9A-Z\s]*)\"$oldname-(s[0-9]*).vmdk\"/) {
									#print "$l\n";
									$l = "$1\"$image_name-$2.vmdk\"\n";
									#print "$l\n";
								}
							}

							if (open(FILE, ">$VMWAREREPOSITORY/$image_name/$oldname.vmdk")) {
								print FILE @file;
								close(FILE);
								if (open(MV, "mv $VMWAREREPOSITORY/$image_name/$oldname.vmdk $VMWAREREPOSITORY/$image_name/$image_name.vmdk 2>&1 |")) {
									my @mv = <MV>;
									close(MV);
									if (@mv) {
										notify($ERRORS{'CRITICAL'}, 0, "old $oldname move to new $image_name error: @mv\n");
									}
									notify($ERRORS{'OK'}, 0, "moved $VMWAREREPOSITORY/$image_name/$oldname.vmdk $VMWAREREPOSITORY/$image_name/$image_name.vmdk");
								}
							}    # write file array back to vmdk file
						}    #read main vmdk file
						else {
							notify($ERRORS{'CRITICAL'}, 0, "could not read $VMWAREREPOSITORY/$image_name/$oldname.vmdk $! ");
							return 0;
						}
					} ## end if (open(LISTFILES, "ls -1 $VMWAREREPOSITORY/$image_name 2>&1 |"...
					        #remove dir from vmhost
					        #everything appears to have worked
					        #remove image files from vmhost
					if (defined(run_ssh_command($hostnodename, $hostIdentity, "vmware-cmd -s unregister $vmx_path"))) {
						notify($ERRORS{'OK'}, 0, "unregistered $vmx_path");
					}

					if (defined(run_ssh_command($hostnodename, $hostIdentity, "/bin/rm -rf $vmhost_vmpath/$vmx_directory", "root"))) {
						notify($ERRORS{'OK'}, 0, "removed vmhost_vmpath/$vmx_directory");
					}
					#set file premissions on images to 644
					# to allow for other management nodes to fetch image if neccessary
					# useful in a large distributed framework
					if (open(CHMOD, "/bin/chmod -R 644 $VMWAREREPOSITORY/$image_name/\*.vmdk 2>&1 |")) {
						close(CHMOD);
						notify($ERRORS{'DEBUG'}, 0, "$notify_prefix recursive update file permssions 644 on $VMWAREREPOSITORY/$image_name");
					}

					return 1;
				} ## end if (open(LISTFILES, "ls -s1 $VMWAREREPOSITORY/$image_name |"...
			} ## end if (run_scp_command("$hostnodename:\"$vmhost_vmpath/$vmx_directory/*.vmdk\""...
		} ## end if ($vmprofile_vmdisk eq "localdisk")
		elsif ($vmprofile_vmdisk eq "networkdisk") {
			#rename vmdk files

			#FIXME - making local directory in our repository so does_image_exists succeeds
			#			does_image_exists needs to figure out the datastores and search them
			if (mkdir("$VMWAREREPOSITORY/$image_name")) {
				notify($ERRORS{'OK'}, 0, "creating local dir for $image_name");
			}


			# create directory
			my @mvdir = run_ssh_command($hostnodename, $hostIdentity, "/bin/mv $vmprofile_datastorepath/$vmx_directory $vmprofile_datastorepath/$image_name", "root");
			for my $l (@{$mvdir[1]}) {
				notify($ERRORS{'OK'}, 0, "possible error @{ $mvdir[1] }");
			}
			notify($ERRORS{'OK'}, 0, "renamed directory $vmx_directory to  $image_name");
			#if ESX user vmkfstools to rename the image
			if ($vmtype_name =~ /vmwareESX/) {
				my $cmd = "vmkfstools -E $vmprofile_datastorepath/$image_name/$vmx_directory.vmdk $vmprofile_datastorepath/$image_name/$image_name.vmdk";
				my @retarr = run_ssh_command($hostnodename, $hostIdentity, $cmd, "root");
				foreach my $r (@{$retarr[1]}) {
					#if any output could mean trouble - this command provides no no response if successful
					notify($ERRORS{'OK'}, 0, "possible problem renaming vm @{ $retarr[1] }") if ($r);
				}
			}
			#success
			#TODO add check to confirm
			notify($ERRORS{'OK'}, 0, "looks like vm is renamed");
			#cleanup - unregister, and remove vm dir on vmhost local disk
			my @cleanup = run_ssh_command($hostnodename, $hostIdentity, "vmware-cmd -s unregister $vmx_path", "root");
			foreach my $c (@{$cleanup[1]}) {
				notify($ERRORS{'OK'}, 0, "vm successfully unregistered") if ($c =~ /1/);
			}
			#remove vmx directoy from our local datastore
			if (defined(run_ssh_command($hostnodename, $hostIdentity, "/bin/rm -rf $vmhost_vmpath/$vmx_directory", "root"))) {
				notify($ERRORS{'OK'}, 0, "success removed $vmhost_vmpath/$vmx_directory from $hostnodename");

			}
		} ## end elsif ($vmprofile_vmdisk eq "networkdisk")  [ if ($vmprofile_vmdisk eq "localdisk")
		return 1;

	}    #if vmware
	elsif ($vmtype_name eq "xen") {

	}

} ## end sub capture

#/////////////////////////////////////////////////////////////////////////////

=head2 _vmwareclone

 Parameters  : $hostnode, $identity, $srcDisk, $dstDisk, $dstDir
 Returns     : 1 if successful, 0 if error occurred
 Description : using vm tools clone srcdisk to dstdisk
				  	currently using builtin vmkfstools

=cut

sub _vmwareclone {
	my ($hostnode, $identity, $srcDisk, $dstDisk, $dstDir) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	#TODO - add checks for VI toolkit - then use vmclone.pl instead
	#vmclone.pl would need additional parameters

	my @list = run_ssh_command($hostnode, $identity, "ls -1 $srcDisk", "root");
	my $srcDiskexist = 0;

	foreach my $l (@{$list[1]}) {
		$srcDiskexist = 1 if ($l =~ /($srcDisk)$/);
		$srcDiskexist = 0 if ($l =~ /No such file or directory/);
		notify($ERRORS{'OK'}, 0, "$l");
	}
	my @ssh;
	if ($srcDiskexist) {
		#make dir for dstdisk
		my @mkdir = run_ssh_command($hostnode, $identity, "mkdir -m 755 $dstDir", "root");
		notify($ERRORS{'OK'}, 0, "srcDisk is exists $srcDisk ");
		notify($ERRORS{'OK'}, 0, "starting clone process vmkfstools -d thin -i $srcDisk $dstDisk");
		if (open(SSH, "/usr/bin/ssh -x -q -i $identity -l root $hostnode \"vmkfstools -i $srcDisk -d thin $dstDisk\" 2>&1 |")) {
			#@ssh=<SSH>;
			#close(SSH);
			#foreach my $l (@ssh) {
			#  notify($ERRORS{'OK'},0,"$l");
			#}
			while (<SSH>) {
				notify($ERRORS{'OK'}, 0, "started $_") if ($_ =~ /Destination/);
				notify($ERRORS{'OK'}, 0, "started $_") if ($_ =~ /Cloning disk/);
				notify($ERRORS{'OK'}, 0, "status $_")  if ($_ =~ /Clone:/);
			}
			close(SSH);
		} ## end if (open(SSH, "/usr/bin/ssh -x -q -i $identity -l root $hostnode \"vmkfstools -i $srcDisk -d thin $dstDisk\" 2>&1 |"...
	} ## end if ($srcDiskexist)
	else {
		notify($ERRORS{'OK'}, 0, "srcDisk $srcDisk does not exists");
	}
	#confirm
	@list = 0;
	@list = run_ssh_command($hostnode, $identity, "ls -1 $dstDisk", "root");
	my $dstDiskexist = 0;
	foreach my $l (@{$list[1]}) {
		$dstDiskexist = 1 if ($l =~ /($dstDisk)$/);
		$dstDiskexist = 0 if ($l =~ /No such file or directory/);
	}
	if ($dstDiskexist) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "clone process failed dstDisk $dstDisk does not exist");
		return 0;
	}
} ## end sub _vmwareclone
#/////////////////////////////////////////////////////////////////////////////

=head2 vmrun_cmd

 Parameters  : hostnode, hostnode type,full vmx path,cmd
 Returns     : 0 or 1
 Description : execute specific vmware-cmd cmd

=cut

sub _vmrun_cmd {
	my ($hostnode, $hosttype, $hostidentity, $vmx, $cmd) = @_;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'WARNING'}, 0, "hostnode is not defined")     if (!(defined($hostnode)));
	notify($ERRORS{'WARNING'}, 0, "hosttype is not defined")     if (!(defined($hosttype)));
	notify($ERRORS{'WARNING'}, 0, "hostidentity is not defined") if (!(defined($hostidentity)));
	notify($ERRORS{'WARNING'}, 0, "vmx is not defined")          if (!(defined($vmx)));
	notify($ERRORS{'WARNING'}, 0, "cmd is not defined")          if (!(defined($cmd)));

	if ($hosttype eq "blade") {

		if ($cmd eq "off") {
			notify($ERRORS{'OK'}, 0, "$hostnode,$hosttype,$hostidentity,$vmx,$cmd");
			my @sshcmd = run_ssh_command($hostnode, $hostidentity, "vmware-cmd $vmx stop hard", "root");
			foreach my $l (@{$sshcmd[1]}) {
				next if ($l =~ /Warning: Permanently added/);
				if ($l =~ /Error/) {
					notify($ERRORS{'CRITICAL'}, 0, "$l output for $hostnode,$hosttype,$hostidentity,$vmx,$cmd");
					return 0;
				}
			}
		} ## end if ($cmd eq "off")
	} ## end if ($hosttype eq "blade")
	return 1;
} ## end sub _vmrun_cmd

#/////////////////////////////////////////////////////////////////////////////

=head2 controlVM

 Parameters  : control command hash
 Returns     : 0 or 1
 Description : controls VM, stop,remove, etc

=cut

sub control_VM {
	my $self = shift;

	# Check if subroutine was called as a class method
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'DEBUG'}, 0, "subroutine was called as a function, it must be called as a class method");
	}

	my $control = shift;
	#my (%vm) = shift;
	#notify($ERRORS{'CRITICAL'}, 0, "debugging", %vm);

	my ($package, $filename, $line, $sub) = caller(0);

	if (!(defined($control))) {
		notify($ERRORS{'WARNING'}, 0, "control is not defined");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "control $control is defined ");
	}

	# Store hash var into local var

	my $vmpath              = $self->data->get_vmhost_profile_vmpath;
	my $datastorepath       = $self->data->get_vmhost_profile_datastore_path;
	my $currentimage        = $self->data->get_computer_currentimage_name;
	my $reservation_id      = $self->data->get_reservation_id;
	my $vmtype              = $self->data->get_vmhost_type_name;
	my $persistent          = $self->data->get_request_forimaging;
	my $vmclient_shortname  = $self->data->get_computer_short_name;
	my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
	my $vmhost_shortname    = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
	my $vmhost_imagename    = $self->data->get_vmhost_image_name;
	my $vmhost_type         = $self->data->get_vmhost_type;

	my ($myvmdir, $myvmx, $mybasedirname, $myimagename);

	#if persistent flag set -- special case or imaging mode
	if ($persistent) {
		#either in imaging mode or special use
		$myvmdir       = "$reservation_id$vmclient_shortname";
		$myvmx         = "$vmpath/$reservation_id$vmclient_shortname/$reservation_id$vmclient_shortname.vmx";
		$mybasedirname = "$reservation_id$vmclient_shortname";
		$myimagename   = "$reservation_id$vmclient_shortname";
		#base directory will not be  used for image creation
	}
	else {
		#standard use
		$myvmdir       = "$currentimage$vmclient_shortname";
		$myvmx         = "$vmpath/$currentimage$vmclient_shortname/$currentimage$vmclient_shortname.vmx";
		$mybasedirname = $currentimage;
		$myimagename   = $currentimage;
	}

	my ($hostnode, $identity);
	if ($vmhost_type eq "blade") {

		if (defined($vmhost_shortname)) {
			$hostnode = $vmhost_shortname;
		}
		else {
			$hostnode = $1 if ($vmhost_shortname =~ /([-_a-zA-Z0-9]*)(\.?)/);
		}
		$identity = $IDENTITY_bladerhel;
	} ## end if ($vmhost_type eq "blade")
	else {
		#using FQHN
		$hostnode = $vmhost_fullhostname;
		$identity = $IDENTITY_linux_lab if ($vmhost_imagename =~ /^(realmrhel)/);
	}
	if (!$identity) {
		notify($ERRORS{'WARNING'}, 0, "could not set ssh identity variable for image $vmhost_imagename type= $vmhost_type host= $vmhost_fullhostname");
		notify($ERRORS{'OK'},      0, "setting to default identity key");
		$identity = $IDENTITY_bladerhel;
	}
	#setup flags
	my $baseexists   = 0;
	my $dirstructure = 0;
	my $vmison       = 0;
	my @sshcmd;
	if ($vmtype =~ /vmware|vmwareGSX|vmwareESX/) {
		#common checks
		notify($ERRORS{'OK'}, 0, "checking for base image on $hostnode $datastorepath");
		@sshcmd = run_ssh_command($hostnode, $identity, "ls -1 $datastorepath", "root");
		notify($ERRORS{'OK'}, 0, "@{ $sshcmd[1] }");
		foreach my $l (@{$sshcmd[1]}) {
			if ($l =~ /denied|No such/) {
				notify($ERRORS{'CRITICAL'}, 0, "node $hostnode output @{ $sshcmd[1] } $identity $hostnode");
				return 0;
			}
			if ($l =~ /Warning: Permanently/) {
				#ignore
			}
			if ($l =~ /(\s*?)$mybasedirname$/) {
				notify($ERRORS{'OK'}, 0, "base image exists");
				$baseexists = 1;
			}
			if ($l =~ /(\s*?)$myvmdir$/) {
				notify($ERRORS{'OK'}, 0, "directory structure $myvmdir image exists");
				$dirstructure = 1;
			}
		} ## end foreach my $l (@{$sshcmd[1]})

		if (($dirstructure)) {
		}
		else {
			notify($ERRORS{'OK'}, 0, "$myvmx directory structure for $myvmdir did not exist  ");
		}
		if ($control =~ /off|remove/) {
			#simply remove any vm's running on that hostname

			my $l_myvmx   = 0;
			my $l_myvmdir = 0;

			##find the correct vmx file for this node -- if running
			undef @sshcmd;
			@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd -l", "root");
			foreach my $l (@{$sshcmd[1]}) {
				chomp($l);
				next if ($l =~ /Warning:/);
				notify($ERRORS{'OK'}, 0, "$l");
				if ($l =~ /(.*)(\/)([-_a-zA-Z0-9]*$vmclient_shortname)(\/)([-_a-zA-Z0-9\/]*$vmclient_shortname.vmx)/) {
					# do within this loop in case there is more than one
					$l_myvmx   = "$1/$3/$5";
					$l_myvmdir = "$1/$3";
					$l_myvmx   =~ s/(\s+)/\\ /g;
					$l_myvmdir =~ s/(\s+)/\\ /g;

					notify($ERRORS{'OK'}, 0, "my vmx $l_myvmx");
					my @sshcmd_1 = run_ssh_command($hostnode, $identity, "vmware-cmd $l_myvmx getstate");
					foreach my $l (@{$sshcmd_1[1]}) {
						if ($l =~ /= off/) {
							#good - move on
						}
						elsif ($l =~ /= on/) {
							my @sshcmd_2 = run_ssh_command($hostnode, $identity, "vmware-cmd $l_myvmx stop hard");
							foreach my $l (@{$sshcmd_2[1]}) {
								next if ($l =~ /Warning:/);
								if ($l =~ /= 1/) {
									#turn off or killpid -- of course it should be off by  this point but kill
									notify($ERRORS{'OK'}, 0, "turned off $l_myvmx");
								}
								else {
									# FIX-ME add better error checking
									notify($ERRORS{'OK'}, 0, "@{ $sshcmd_2[1] }");
								}
							} ## end foreach my $l (@{$sshcmd_2[1]})
						} ## end elsif ($l =~ /= on/)  [ if ($l =~ /= off/)
						elsif ($l =~ /= stuck/) {
							#list processes for vmx and kill pid
							notify($ERRORS{'OK'}, 0, "vm reported in stuck state, attempting to kill process");
							my @ssh_pid = run_ssh_command($hostnode, $identity, "vmware-cmd -q $l_myvmx getpid");
							foreach my $p (@{$ssh_pid[1]}) {
								if ($p =~ /(\D*)(\s*)([0-9]*)/) {
									notify($ERRORS{'OK'}, 0, "vm pid= $3");
									my $vmpid = $3;
									if (defined(run_ssh_command($hostnode, $identity, "kill -9 $vmpid"))) {
										notify($ERRORS{'OK'}, 0, "killed $vmpid $l_myvmx");
									}
								}
							}
						} ## end elsif ($l =~ /= stuck/)  [ if ($l =~ /= off/)
						else {
							notify($ERRORS{'OK'}, 0, "@{ $sshcmd_1[1] }");
						}
					} ## end foreach my $l (@{$sshcmd_1[1]})
					    #unregister
					undef @sshcmd_1;
					@sshcmd_1 = run_ssh_command($hostnode, $identity, "vmware-cmd -s unregister $l_myvmx ");
					foreach my $l (@{$sshcmd_1[1]}) {
						notify($ERRORS{'OK'}, 0, "vm $l_myvmx unregistered") if ($l =~ /= 1/);
					}
				} ## end if ($l =~ /(.*)(\/)([-_a-zA-Z0-9]*$vmclient_shortname)(\/)([-_a-zA-Z0-9\/]*$vmclient_shortname.vmx)/)
			} ## end foreach my $l (@{$sshcmd[1]})
			if ($control eq "remove") {
				#delete directory -- clean slate
				if (defined(run_ssh_command($hostnode, $identity, "/bin/rm -rf $l_myvmdir", "root"))) {
					notify($ERRORS{'OK'}, 0, "removed $l_myvmdir from $hostnode");
					return 1;
				}

			}
		} ## end if ($control =~ /off|remove/)
		    #restart
		if ($control eq "restart") {
			#turn vm off
			notify($ERRORS{'OK'}, 0, "restarting $myvmx");
			if ($vmison) {
				notify($ERRORS{'OK'}, 0, "turning off $myvmx");
				undef @sshcmd;
				@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx stop hard", "root");
				foreach my $l (@{$sshcmd[1]}) {
					if ($l) {
						notify($ERRORS{'OK'}, 0, "$myvmx strange output $l");
					}
				}
				#sleep a bit to let it shutdown
				sleep 15;
				#confirm
				undef @sshcmd;
				@sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx getstate", "root");
				foreach my $l (@{$sshcmd[1]}) {
					if ($l =~ /= off/) {
						#good
						return 1;
					}
				}
			} ## end if ($vmison)
			else {
				notify($ERRORS{'OK'}, 0, "$myvmx reported off");
				return 1;
			}
		} ## end if ($control eq "restart")
		    #suspend
		if ($control eq "suspend") {
			#suspend machine
			#could copy to managment node storage
			#under different name and store for later use
		}
	} ## end if ($vmtype =~ /vmware|vmwareGSX|vmwareESX/)
	return 1;
} ## end sub control_VM

#/////////////////////////////////////////////////////////////////////////////

=head2  getimagesize

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
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

	#my $imagename = $_[0];
	#my ($package, $filename, $line, $sub) = caller(0);
	#notify($ERRORS{'WARNING'}, 0, "imagename is not defined") if (!(defined($imagename)));

	#if (!(defined($imagename))) {
	#	return 0;
	#}
	my $IMAGEREPOSITORY = "$VMWAREREPOSITORY/$image_name";

	#list files in image directory, account for main .gz file and any .gz.00X files
	if (open(FILELIST, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1 |")) {
		my @filelist = <FILELIST>;
		close(FILELIST);
		my $size = 0;
		foreach my $f (@filelist) {
			if ($f =~ /$image_name.vmdk/) {
				my ($presize, $blah) = split(" ", $f);
				$size += $presize;
			}
		}
		if ($size == 0) {
			#strange imagename not found
			return 0;
		}
		return int($size / 1024);
	} ## end if (open(FILELIST, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1 |"...

	return 0;
} ## end sub get_image_size



#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $nodename, $log
 Returns     : array of related status checks
 Description : checks on ping,sshd, currentimage, OS

=cut

sub node_status {
	my $self = shift;

	# Check if subroutine was called as a class method
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'DEBUG'}, 0, "subroutine was called as a function, it must be called as a class method");
	}

	#my ($vmhash) = shift;

	my ($package, $filename, $line, $sub) = caller(0);

	# try to contact vm
	# $self->data->get_request_data;
	# get state of vm
	my $vmpath             = $self->data->get_vmhost_profile_vmpath;
	my $datastorepath      = $self->data->get_vmhost_profile_datastore_path;
	my $requestedimagename = $self->data->get_image_name;
	my $vmhost_type        = $self->data->get_vmhost_type;
	my $vmhost_hostname    = $self->data->get_vmhost_hostname;
	my $vmhost_imagename   = $self->data->get_vmhost_image_name;
	my $vmclient_shortname = $self->data->get_computer_short_name;
	my $image_os_type		  = $self->data->get_image_os_type;
	my $request_forimaging              = $self->data->get_request_forimaging();

	my ($hostnode, $identity);

	# Create a hash to store status components
	my %status;

	# Initialize all hash keys here to make sure they're defined
	$status{status}       = 0;
	$status{currentimage} = 0;
	$status{ping}         = 0;
	$status{ssh}          = 0;
	$status{vmstate}      = 0;    #on or off
	$status{image_match}  = 0;

	if ($vmhost_type eq "blade") {
		$hostnode = $1 if ($vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
		$identity = $IDENTITY_bladerhel;    
	}
	else {
		#using FQHN
		$hostnode = $vmhost_hostname;
		$identity = $IDENTITY_linux_lab if ($vmhost_imagename =~ /^(realmrhel)/);
	}

	if (!$identity) {
		notify($ERRORS{'CRITICAL'}, 0, "could not set ssh identity variable for image $vmhost_imagename type= $vmhost_type host= $vmhost_hostname");
	}

	# Check if node is pingable
	notify($ERRORS{'DEBUG'}, 0, "checking if $vmclient_shortname is pingable");
	if (_pingnode($vmclient_shortname)) {
		$status{ping} = 1;
		notify($ERRORS{'OK'}, 0, "$vmclient_shortname is pingable ($status{ping})");
	}
	else {
		notify($ERRORS{'OK'}, 0, "$vmclient_shortname is not pingable ($status{ping})");
		$status{status} = 'RELOAD';
		return $status{status};
	}

	#
	my $vmx_directory = "$requestedimagename$vmclient_shortname";
	my $myvmx         = "$vmpath/$requestedimagename$vmclient_shortname/$requestedimagename$vmclient_shortname.vmx";
	my $mybasedirname = $requestedimagename;
	my $myimagename   = $requestedimagename;


	#can I ssh into it
	my $sshd = _sshd_status($vmclient_shortname, $requestedimagename,$image_os_type);


	#is it running the requested image
	if ($sshd eq "on") {

		$status{ssh}          = 1;
		$status{currentimage} = _getcurrentimage($vmclient_shortname);

		if ($status{currentimage}) {
			chomp($status{currentimage});
			if ($status{currentimage} =~ /$requestedimagename/) {
				$status{image_match} = 1;
				notify($ERRORS{'OK'}, 0, "$vmclient_shortname is loaded with requestedimagename $requestedimagename");
			}
			else {
				notify($ERRORS{'OK'}, 0, "$vmclient_shortname reports current image is currentimage= $status{currentimage} requestedimagename= $requestedimagename");
			}
		} ## end if ($status{currentimage})
	} ## end if ($sshd eq "on")

	# #vm running
	if ($status{image_match}) {
		my @sshcmd = run_ssh_command($hostnode, $identity, "vmware-cmd $myvmx getstate", "root");
		foreach my $l (@{$sshcmd[1]}) {
			notify($ERRORS{'OK'}, 0, "$l");
			$status{vmstate} = 1 if ($l =~ /^getstate\(\) = on/);
			$status{vmstate} = 0 if ($l =~ /= off/);

			if ($l =~ /No such virtual machine/) {
				#ok wait something is using that hostname
				#reset $status{image_match} controlVM will detect and remove it
				$status{image_match} = 0;
			}
		} ## end foreach my $l (@{$sshcmd[1]})
	} ## end if ($status{image_match})

	# Determine the overall machine status based on the individual status results
	if ($status{ssh} && $status{image_match}) {
		$status{status} = 'READY';
	}
	else {
		$status{status} = 'RELOAD';
	}

	if($request_forimaging){
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, 0, "forimaging flag enabled RELOAD machine");
	}

	notify($ERRORS{'OK'}, 0, "returning node status hash reference (\$node_status->{status}=$status{status})");
	return \%status;

} ## end sub node_status

#/////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : imagename
 Returns     : 0 or 1
 Description : scans  our image local image library for requested image
					returns 1 if found or 0 if not
					attempts to scp image files from peer management nodes

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_name = $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine if image exists, unable to determine image name");
		return 0;
	}

	my $IMAGEREPOSITORY;

	if ($image_name =~ /^(vmware)/) {
		$IMAGEREPOSITORY = "$VMWAREREPOSITORY";
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine if image exists, image name is not vmware image_name= $image_name");
		return 0;
	}

	if (open(IMAGES, "/bin/ls -1 $IMAGEREPOSITORY 2>&1 |")) {
		my @images = <IMAGES>;
		close(IMAGES);
		foreach my $i (@images) {
			if ($i =~ /$image_name/) {
				notify($ERRORS{'OK'}, 0, "image $image_name exists");
				return 1;
			}
		}
	} ## end if (open(IMAGES, "/bin/ls -1 $IMAGEREPOSITORY 2>&1 |"...

	notify($ERRORS{'WARNING'}, 0, "image $IMAGEREPOSITORY/$image_name does NOT exists");
	return 0;

} ## end sub does_image_exist
#/////////////////////////////////////////////////////////////////////////////

=head2 retrieve_image

 Parameters  :
 Returns     :
 Description : Attempts to retrieve an image from an image library partner

=cut

sub retrieve_image {
	my $self = shift;
	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Make sure imag library functions are enabled
	my $image_lib_enable = $self->data->get_management_node_image_lib_enable();
	if (!$image_lib_enable) {
		notify($ERRORS{'OK'}, 0, "image library functions are disabled");
		return;
	}

	# Get the image name
	my $image_name = shift;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name");
		return;
	}

	# Get the other image library variables
	my $image_lib_user     = $self->data->get_management_node_image_lib_user()     || 'undefined';
	my $image_lib_key      = $self->data->get_management_node_image_lib_key()      || 'undefined';
	my $image_lib_partners = $self->data->get_management_node_image_lib_partners() || 'undefined';
	if ("$image_lib_user $image_lib_key $image_lib_partners" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "image library configuration data is missing: user=$image_lib_user, key=$image_lib_key, partners=$image_lib_partners");
		return;
	}

	# Get the image repository path
	my $image_repository_path = $self->_get_image_repository_path();
	if (!$image_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "image repository path could not be determined");
		return;
	}

	# Attempt to copy image from other management nodes
	notify($ERRORS{'OK'}, 0, "attempting to copy $image_name from other management nodes");

	# Split up the partner list
	my @partner_list = split(/,/, $image_lib_partners);
	if ((scalar @partner_list) == 0) {
		notify($ERRORS{'WARNING'}, 0, "image lib partners variable is not listed correctly or does not contain any information: $image_lib_partners");
		return;
	}

	# Loop through the partners, attempt to copy
	foreach my $partner (@partner_list) {
		notify($ERRORS{'OK'}, 0, "checking if $partner has $image_name");

		# Use ssh to call ls on the partner management node
		my ($ls_exit_status, $ls_output_array_ref) = run_ssh_command($partner, $image_lib_key, "ls -1 $image_repository_path", $image_lib_user);

		# Check if the ssh command failed
		if (!$ls_output_array_ref) {
			notify($ERRORS{'WARNING'}, 0, "unable to run ls command via ssh on $partner");
			next;
		}

		# Convert the output array to a string
		my $ls_output = join("\n", @{$ls_output_array_ref});

		# Check the ls output for permission denied
		if ($ls_output =~ /permission denied/i) {
			notify($ERRORS{'CRITICAL'}, 0, "permission denied when checking if $partner has $image_name, exit status=$ls_exit_status, output:\n$ls_output");
			next;
		}

		# Check the ls output for the image name
		if ($ls_output !~ /$image_name/i) {
			notify($ERRORS{'OK'}, 0, "$image_name does not exist on $partner");
			next;
		}

		# Image exists
		notify($ERRORS{'OK'}, 0, "$image_name exists on $partner, attempting to copy");

		#set lockfile - prevent process from loading while a copy is in progress

		my $lock = "$image_repository_path/$image_name.copylock";
		if (sysopen(SEM, $lock, O_RDONLY | O_CREAT)) {
			if (flock(SEM, LOCK_EX)) {
				notify($ERRORS{'OK'}, 0, "set Exclusive lock on $lock");
				# Attempt copy
				if (run_scp_command("$image_lib_user\@$partner:$image_repository_path/$image_name*", $image_repository_path, $image_lib_key)) {
					notify($ERRORS{'OK'}, 0, "$image_name files copied via SCP");
					close(SEM);
					notify($ERRORS{'OK'}, 0, "releasing exclusive lock on $lock, proceeding");
					unlink($lock);
					last;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to copy $image_name files via SCP");
					close(SEM);
					notify($ERRORS{'OK'}, 0, "releasing exclusive lock on $lock, proceeding");
					unlink($lock);
					next;
				}
			} ## end if (flock(SEM, LOCK_EX))
		} ## end if (sysopen(SEM, $lock, O_RDONLY | O_CREAT...


	} ## end foreach my $partner (@partner_list)

	# Make sure image was copied
	if ($self->does_image_exist($image_name)) {
		notify($ERRORS{'OK'}, 0, "$image_name was copied to this management node");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$image_name was not copied to this management node");
		return 0;
	}
} ## end sub retrieve_image

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_image_repository_path

 Parameters  : none, must be called as an object method
 Returns     :
 Description :

=cut

sub _get_image_repository_path {
	my $self = shift;

	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $return_path = "/install/vmware_images";
	return $return_path;
} ## end sub _get_image_repository_path

#/////////////////////////////////////////////////////////////////////////////

#/////////////////////////////////////////////////////////////////////////////

=head2 put_node_in_maintenance

 Parameters  : none, must be called as an object method
 Returns     :  1,0
 Description : preforms any actions on node before putting in maintenance state

=cut

sub post_maintenance_action {
	my $self = shift;

	if (ref($self) !~ /vmware/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	#steps putting vm into maintenance
	# check state of vm
	# turn off if needed
	# unregister
	# remove vm machine directory from vmx path
	# set vmhostid to null in computer table - handled in new.pm

	my $computer_name   = $self->data->get_computer_short_name;
	my $vmhost_hostname = $self->data->get_vmhost_hostname;

	if ($self->control_VM("remove")) {
		notify($ERRORS{'OK'}, 0, "removed node $computer_name from vmhost $vmhost_hostname");
	}

	return 1;

} ## end sub post_maintenance_action


#////////////////////////

1;

#/////////////////////
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

