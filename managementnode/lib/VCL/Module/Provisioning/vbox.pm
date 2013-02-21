#!/usr/bin/perl -w
###############################################################################
# $Id: $ 
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

VCL::Provisioning::vbox - VCL module to support SUN Virtual Box Provisioning

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for SUN Virtual Box.

=cut

##############################################################################
package VCL::Module::Provisioning::vbox;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

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

##############################################################################


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
	notify($ERRORS{'DEBUG'}, 0, "module initialized");
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
	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_data = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# Store some hash variables into local variables
	my $request_id     = $self->data->get_request_id;
	my $reservation_id = $self->data->get_reservation_id;
	my $persistent     = $self->data->get_request_forimaging;
	
	my $management_node_keys     = $self->data->get_management_node_keys();

	my $image_os_type  = $self->data->get_image_os_type;

	my $vmclient_computerid = $self->data->get_computer_id;
	my $computer_shortname  = $self->data->get_computer_short_name;
	my $computer_nodename   = $computer_shortname;
	my $computer_hostname   = $self->data->get_computer_hostname;

	my $vmprofile_vmdisk  = $self->data->get_vmhost_profile_vmdisk;
	my $datastorepath     = $self->data->get_vmhost_profile_datastore_path;
	my $virtualswitch0    = $self->data->get_vmhost_profile_virtualswitch0;
	my $virtualswitch1    = $self->data->get_vmhost_profile_virtualswitch1;

	my $requestedimagename = $self->data->get_image_name;
	my $shortname          = $computer_shortname;

	my $vmhost_imagename          = $self->data->get_vmhost_image_name;
	my $vmhost_hostname           = $self->data->get_vmhost_hostname;
	my $vmclient_eth0MAC          = $self->data->get_computer_eth0_mac_address;
	my $vmclient_eth1MAC          = $self->data->get_computer_eth1_mac_address;
	my $vmclient_imageminram      = $self->data->get_image_minram;
	my $vmhost_RAM                = $self->data->get_vmhost_ram;
	my $vmclient_drivetype        = $self->data->get_computer_drive_type;
	my $vmclient_privateIPaddress = $self->data->get_computer_ip_address;
	my $vmclient_publicIPaddress  = $self->data->get_computer_private_ip_address;
	my $vmclient_OSname           = $self->data->get_image_os_name;
	
	my $image_repository_path     = $self->_get_image_repository_path();
	
	# Assemble a consistent prefix for notify messages
	my $notify_prefix = "req=$request_id, res=$reservation_id:";
	my $vm_name;
	my @sshcmd;
	insertloadlog($reservation_id, $vmclient_computerid, "startload", "$computer_shortname $requestedimagename");
	my $starttime = convert_to_epoch_seconds;

	my ($hostnode);
	$hostnode = $vmhost_hostname;
	if (!(defined($management_node_keys))) {
		notify($ERRORS{'CRITICAL'}, 0, "identity variable not defined, setting to blade identity file vmhost variable to $vmhost_imagename");
	}

	notify($ERRORS{'OK'}, 0, "identity file set $management_node_keys  vmhost imagename $vmhost_imagename bladekey ");
	#setup flags
        my $baseisregistered = 0;
	my $baseexists   = 0;
	my $dirstructure = 0;

	#for convienence
	my ($myimagename, $myvmx, $myvmdir, $mybasedirname, $requestedimagenamebase);

	# preform cleanup
	if ($self->control_VM("remove")) {
                notify($ERRORS{'OK'}, 0, "removed node $shortname from vmhost $vmhost_hostname");
        }

        ### FIX-ME: I have no freakin clue how to approach this (imaging mode) at the moment
        ###         For VBox, this would require changing the disk mode from immuatable to normal
        ###         which itself would be easy, the challenge for me is handeling the hypervisors that have this image registered
        ###         where any VMs that are using it will have associated snapshots that will have to be delt with before the image
        ###         could be un-registered and re-registered. so for now, @#$% it... (david.hutchins)
	if ($persistent) {
         $vm_name = "$requestedimagename\_IMAGING\_$shortname"; 
	} ## end if ($persistent)
	else {
         $vm_name = "$requestedimagename\_$shortname";
	}
	
	$myimagename   = $requestedimagename;

	notify($ERRORS{'DEBUG'}, 0, "persistent= NOT IMPLEMENTED");
	notify($ERRORS{'DEBUG'}, 0, "myimagename= $myimagename");

	#does the requested base vbox image files already existed on the vmhost
	notify($ERRORS{'OK'}, 0, "checking for base image $requestedimagename on $hostnode ");
	insertloadlog($reservation_id, $vmclient_computerid, "vmround1", "checking host for requested image files");

	#check for lock file - another process might be copying the same image files to the same host server
	my $tmplockfile = "/tmp/$hostnode" . "$requestedimagename" . "lock";
	notify($ERRORS{'OK'}, 0, "trying to create exclusive lock on $tmplockfile while checking if image files exist on host");
	if (sysopen(TMPLOCK, $tmplockfile, O_RDONLY | O_CREAT)) {
		if (flock(TMPLOCK, LOCK_EX)) {
			notify($ERRORS{'OK'}, 0, "owning exclusive lock on $tmplockfile");
			notify($ERRORS{'OK'}, 0, "listing datestore $datastorepath\/vbox ");

			# Check to see if the baseimage is registered with VirtualBox on this host. 
			undef @sshcmd;
			#@sshcmd = run_ssh_command($hostnode, $management_node_keys, "ls -1 $datastorepath", "root");
			@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list hdds", "root");
			notify($ERRORS{'OK'}, 0, "Hdds in VirtualBox database on vm host:\n@{ $sshcmd[1] }");
			foreach my $l (@{$sshcmd[1]}) {
				if ($l =~ /(\s*?)$datastorepath\/vbox\/$myimagename/) {
                                        # The base is registered, so we will assume it is also present (This may not be the best approach, but for now it will do).
					notify($ERRORS{'OK'}, 0, "base image exists");
					$baseisregistered = 1;
                                        $baseexists = 1;
				}
			} ## end foreach my $l (@{$sshcmd[1]})

                        # If the base is not registered, we will check to see if it exists
                        if (!($baseisregistered)) {
				undef @sshcmd;
				@sshcmd = run_ssh_command($hostnode, $management_node_keys, "ls -1 $datastorepath\/vbox", "root");
				foreach my $l (@{$sshcmd[1]}) {
                                	if ($l =~ /(\s*?)$myimagename/) {
                                        	# The base exists so we just need to register it with VirtualBox.
                                        	notify($ERRORS{'OK'}, 0, "base image exists, registering it with VirtualBox");
                                        	$baseexists = 1;
                                	}
                        	}
			}


			if (!($baseexists)) {
				#check available disk space -- clean up if needed
				#copy vm files from local repository to vmhost
				#this could take a few minutes
				#get size of  vmdl files

				insertloadlog($reservation_id, $vmclient_computerid, "info", "image files do not exist on host server, preparing to copy");
				my $myvmdkfilesize = 0;
				if (open(SIZE, "du -k $image_repository_path\/vbox\/$requestedimagename 2>&1 |")) {
					my @du = <SIZE>;
					close(SIZE);
					foreach my $d (@du) {
						if ($d =~ /No such file or directory/) {
							insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not collect size of local image files");
							notify($ERRORS{'CRITICAL'}, 0, "problem checking local vm file size on $image_repository_path\/vbox\/$requestedimagename");
							close(TMPLOCK);
							unlink($tmplockfile);
							return 0;
						}
						if ($d =~ /^([0-9]*)/) {
							$myvmdkfilesize += $1;
						}
					} ## end foreach my $d (@du)
				} ## end if (open(SIZE, "du -k $image_repository_path/$requestedimagename 2>&1 |"...

				notify($ERRORS{'DEBUG'}, 0, "file size $myvmdkfilesize of $requestedimagename");
				if ($vmprofile_vmdisk =~ /(local|dedicated)/) {
					notify($ERRORS{'OK'}, 0, "copying base image files $requestedimagename to $hostnode");
					if (run_scp_command("$image_repository_path\/vbox\/$requestedimagename", "$hostnode:\"$datastorepath\/vbox\/\"", $management_node_keys)) {
						#recheck host server for files - the  scp output is not being captured
						undef @sshcmd;
						@sshcmd = run_ssh_command($hostnode, $management_node_keys, "ls -1 $datastorepath\/vbox", "root");
						foreach my $l (@{$sshcmd[1]}) {
							if ($l =~ /denied|No such/) {
								notify($ERRORS{'CRITICAL'}, 0, "node $hostnode output @{ $sshcmd[1] }");
								insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not log into vmhost $hostnode @{ $sshcmd[1] }");
								close(TMPLOCK);
								unlink($tmplockfile);
								return 0;
							}
							if ($l =~ /(\s*?)$requestedimagename$/) {
								notify($ERRORS{'OK'}, 0, "base image exists");
								$baseexists = 1;
								insertloadlog($reservation_id, $vmclient_computerid, "transfervm", "copying base image files");
							}
						} ## end foreach my $l (@{$sshcmd[1]})

					} ## end if (run_scp_command("$image_repository_path/$requestedimagename"...
					else {
						notify($ERRORS{'CRITICAL'}, 0, "problems scp vm files to $hostnode $!");
						close(TMPLOCK);
						unlink($tmplockfile);
						return 0;
					}
				} ## end if ($vmprofile_vmdisk =~ /(local|dedicated)/)
				notify($ERRORS{'OK'}, 0, "confirm image exist process complete removing lock on $tmplockfile");
				close(TMPLOCK);
				unlink($tmplockfile);

			}    # start if base not exists
                        # If the base exists but was not registered we just need to register it
			elsif((!($baseisregistered)) && ($baseexists)) {
				undef @sshcmd;
                                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q openmedium disk $datastorepath\/vbox\/$myimagename --type immutable", "root");
	                             foreach my $l (@{$sshcmd[1]}) {
					if ($l =~ /(\s*?)ERROR:/) {
                                                # Registeration failed, manual intervention is probably required, send warning and die.
                                                notify($ERRORS{'CRITICAL'}, 0, "Registeration of image failed, output is: \n@{ $sshcmd[1] }");
                                                close(TMPLOCK);
                                                unlink($tmplockfile);
                                                return 0;
                                        } 
					else {
                                                # Registeration success.
                                                notify($ERRORS{'OK'}, 0, "Image Registered.");
                                                $baseisregistered = 1;
					}
                                        
                                }
			} else {
				#base exists
				notify($ERRORS{'OK'}, 0, "confirm image exist process complete removing lock on $tmplockfile");
				close(TMPLOCK);
				unlink($tmplockfile);
			}
		}    #flock
	}    #sysopen
	     #ok good base vm files exist on hostnode
	     #if guest dirstructure exists check state of vm, else create sturcture and new vmx file
	#check for dependent settings ethX
	if (!(defined($vmclient_eth0MAC))) {
		#complain
		notify($ERRORS{'CRITICAL'}, 0, "eth0MAC is not defined for $computer_shortname can not continue");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "eth0MAC address is not defined");
		return 0;

	}

	#check for memory settings
	my $dynamicmemvalue = "128";
	if (defined($vmclient_imageminram)) {
		#preform some sanity check
		if (($dynamicmemvalue < $vmclient_imageminram) && ($vmclient_imageminram < $vmhost_RAM)) {
			$dynamicmemvalue = $vmclient_imageminram;
			notify($ERRORS{'OK'}, 0, "setting memory to $dynamicmemvalue");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "image memory value $vmclient_imageminram out of the expected range in host machine $vmhost_RAM setting to 128");
		}
	} ## end if (defined($vmclient_imageminram))
	
        VBOXCREATE:

        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q setproperty hdfolder $image_repository_path\/vbox\/SNAPSHOTS", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q setproperty machinefolder  $image_repository_path\/vbox\/MACHINES", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q createvm --name $vm_name --register", "root");
        $vmclient_eth0MAC =~ tr/://d;
        $vmclient_eth1MAC =~ tr/://d;
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q modifyvm $vm_name --memory $dynamicmemvalue", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q modifyvm $vm_name --ioapic on", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q modifyvm $vm_name --nic1 bridged --bridgeadapter1 $virtualswitch0 --macaddress1 $vmclient_eth0MAC --nictype1 82540EM", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q modifyvm $vm_name --nic2 bridged --bridgeadapter2 $virtualswitch1 --macaddress2 $vmclient_eth1MAC --nictype2 82540EM", "root");
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q storagectl $vm_name --name $shortname\_stor --add ide", "root");
        if ($persistent) {
		notify($ERRORS{'OK'}, 0, "Cloning image, this could take a while.");
		undef @sshcmd;
	        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q clonehd $image_repository_path\/vbox\/$requestedimagename $image_repository_path\/vbox\/$requestedimagename\_IMAGING\_$shortname.vdi ", "root");
        	undef @sshcmd;
                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q storageattach $vm_name --storagectl $shortname\_stor --port 0 --device 0 --type hdd --medium $image_repository_path\/vbox\/$requestedimagename\_IMAGING\_$shortname.vdi", "root"); 
        } ## end if ($persistent)
        else {
        	undef @sshcmd;
        	@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q storageattach $vm_name --storagectl $shortname\_stor --port 0 --device 0 --type hdd --medium $image_repository_path\/vbox\/$requestedimagename", "root");
        }
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q modifyvm $vm_name --pae on", "root");

	#turn on vm
	#set loop control
	my $vbox_starts = 0;

	VBOXSTART:

	$vbox_starts++;
	notify($ERRORS{'OK'}, 0, "starting vm $vm_name - pass $vbox_starts");
	if ($vbox_starts > 2) {
		notify($ERRORS{'CRITICAL'}, 0, "VirtualBox starts exceeded limit vbox_starts= $vbox_starts hostnode= $hostnode vm= $computer_shortname");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not load machine on $hostnode exceeded attempts");
		return 0;
	}

	undef @sshcmd;
	@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q startvm $vm_name --type headless", "root");
	for my $l (@{$sshcmd[1]}) {
		next if ($l =~ /Warning:/);
		#if successful -- this cmd does not appear to return any ouput so anything could be a failure
		if ($l =~ /successfully started/) {
			notify($ERRORS{'OK'}, 0, "started $vm_name on $hostnode");
		}
		else {
			notify($ERRORS{'OK'}, 0, "Unknown output when trying to start $vm_name on $hostnode \n@{ $sshcmd[1] }");
		}
	} ## end for my $l (@{$sshcmd[1]})
	insertloadlog($reservation_id, $vmclient_computerid, "startvm", "started vm on $hostnode");

	my $sshd_attempts = 0;

	VBOXROUND2:
	
	insertloadlog($reservation_id, $vmclient_computerid, "vmround2", "waiting for ssh to become active");
	
	if ($self->os->can("post_load")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "->post_load()");
		if ($self->os->post_load()) {
			notify($ERRORS{'DEBUG'}, 0, "successfully ran OS post_load subroutine");
		}
		else {
			my $vm_state = $self->power_status() || 'unknown';
			notify($ERRORS{'WARNING'}, 0, "failed to run OS post_load subroutine, VM state: $vm_state");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, ref($self->os) . "::post_load() has not been implemented");
	}
	
	insertloadlog($reservation_id, $vmclient_computerid, "info", "starting post configurations on node");
	
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

	insertloadlog($reservation_id, $vmclient_computerid, "vboxready", "preformed post config on node");
	return 1;

} ## end sub load


#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : $request_data_hash_reference
 Returns     : 1 if sucessful, 0 if failed
 Description : Creates a new vbox image.

=cut

sub capture { ## This is going to need to be implemented before the module is complete, but at the moment the focus is on complete VM provisioning.
	my $self = shift;
	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	my $request_id     = $self->data->get_request_id;
        my $reservation_id = $self->data->get_reservation_id;
        my $management_node_keys     = $self->data->get_management_node_keys();

        my $image_id       = $self->data->get_image_id;
        my $image_os_name  = $self->data->get_image_os_name;
        my $image_identity = $self->data->get_image_identity;
        my $image_os_type  = $self->data->get_image_os_type;
        my $image_name     = $self->data->get_image_name();

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

        my $image_repository_path   = $self->_get_image_repository_path();
	my $hostnodename = $vmhost_hostname;
        # Assemble a consistent prefix for notify messages
        my $notify_prefix = "req=$request_id, res=$reservation_id:";
        my $image_filename;


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
                return 0;
        }
        my @sshcmd;

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
                        notify($ERRORS{'OK'}, 0, "verified $computer_nodename power is off");
                }
                elsif ($power_status eq 'on') {
                        notify($ERRORS{'WARNING'}, 0, "$computer_nodename power is still on, turning computer off");

                        # Attempt to power off computer
                        if ($self->power_off()) {
                                notify($ERRORS{'OK'}, 0, "$computer_nodename was powered off");
                        }
                        else {
                                notify($ERRORS{'WARNING'}, 0, "failed to power off $computer_nodename");
                                return 0;
                        }
                }
                else {
                        notify($ERRORS{'WARNING'}, 0, "failed to determine power status of $computer_nodename");
                        return 0;
                }
        }
	
        if ($vmprofile_vmdisk =~ /(local|dedicated)/) {
                # copy vdi files
                # confirm they were copied
                notify($ERRORS{'OK'}, 0, "Removing VM");
		if ($self->control_VM("remove")) {
        	        notify($ERRORS{'OK'}, 0, "removed node $computer_shortname from vmhost $hostnodename");
	        }

                undef @sshcmd;
        	@sshcmd = run_ssh_command($hostnodename, $management_node_keys, "ls $vmhost_vmpath/*_IMAGING_$computer_shortname.vdi", "root");
	        for my $l (@{$sshcmd[1]}) {
                	if ($l =~ /\/(.*_IMAGING_$computer_shortname\.vdi)/) {
				$image_filename = $1;
                        	notify($ERRORS{'OK'}, 0, "Image filename is: $image_filename");
			}
        	} ## end for my $l (@{$sshcmd[1]})

                notify($ERRORS{'OK'}, 0, "attemping to copy vdi file to $image_repository_path\/vbox");
                if (run_scp_command("$hostnodename:\"$vmhost_vmpath/$image_filename\"", "$image_repository_path\/vbox\/$image_name", $management_node_keys)) {

                # set file premissions on images to 644
                # to allow for other management nodes to fetch image if neccessary
                # useful in a large distributed framework
                if (open(CHMOD, "/bin/chmod -R 644 $image_repository_path\/vbox\/$image_name 2>&1 |")) {
                        close(CHMOD);
                        notify($ERRORS{'DEBUG'}, 0, "$notify_prefix recursive update file permssions 644 on $image_repository_path\/vbox\/$image_name");
                }
		undef @sshcmd;
                @sshcmd = run_ssh_command($hostnodename, $management_node_keys, "VBoxManage closemedium disk $vmhost_vmpath/vbox/$image_filename --delete", "root");
                return 1;
                } ## end if (run_scp_command("$hostnodename:\"$vmhost_vmpath/$vmx_directory/*.vmdk\""...
                else {
                        notify($ERRORS{'CRITICAL'}, 0, "failed to copy .vdi file to image repository");
                        return 0;
                }
        } ## end if ($vmprofile_vmdisk =~ /(local|dedicated)/)


} ## end sub capture

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_snapshots

 Parameters  : n/a
 Returns     : 1 if sucessful, 0 if failed
 Description : removes any unused snapshot hdds from specified host.

=cut

sub remove_snapshots { 
	my $self = shift;
	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
        my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
        my $hostnode = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
        my $management_node_keys = $self->data->get_management_node_keys();
        my @sshcmd;
        my @sshcmd2;
        my $is_snapshot = 0;
        my $delete_flag = 0;
        my $current_uuid;
	notify($ERRORS{'OK'}, 0, "Removing unused snapshots");
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list hdds | sed s/^\$/----/g", "root");
	foreach my $l (@{$sshcmd[1]}) {
        	if ($l =~ m/^UUID/) { # UUID line is the start of a section
        	        $l =~ m/(........-....-....-....-............)/;
			$current_uuid = $1;
	        	notify($ERRORS{'OK'}, 0, "Checking hdd with UUID $1");
                        $is_snapshot = 0; # reset this flag
                        $delete_flag = 0; # reset this flag
                }
		if ($l =~ m/^Parent/) {
			if ($l =~ m/Parent UUID: base/) { # This is a base image, not a snapshot
				notify($ERRORS{'OK'}, 0, "UUID $current_uuid is not a snapshot");
                        	$is_snapshot = 0; # Mark as a snapshot.
                        	$delete_flag = 0; # Default is to remove this snapshot, unless it is found to be in use.
			} else { # This is a snapshot
				$l =~ m/(........-....-....-....-............)/;
				notify($ERRORS{'OK'}, 0, "UUID $current_uuid is a snapshot of $1");
                        	$is_snapshot = 1; # Mark as a snapshot.
                        	$delete_flag = 1; # Default is to remove this snapshot, unless it is found to be in use.
			}
		}
		if ($l =~ m/^Usage/) { # This image is still in use
                        notify($ERRORS{'OK'}, 0, "UUID $current_uuid is in use, will not be removed");
                        $delete_flag = 0; #Will not delete as this is still in use 
                }
                if ($l eq '----') { # end of one section, time to remove the image if it is an unused snapshot.
			if ($is_snapshot && $delete_flag) {
                        	notify($ERRORS{'OK'}, 0, "UUID $current_uuid is not in use, will be removed");
        			@sshcmd2 = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q closemedium disk $current_uuid --delete", "root");
			} 
		}
	}
} ## end sub remove_snapshots 

#/////////////////////////////////////////////////////////////////////////////

=head2 controlVM

 Parameters  : control command hash
 Returns     : 0 or 1
 Description : controls VM, stop,remove, etc

=cut

### This section will be next.

sub control_VM {
	my $self = shift;
        my $ret = 0;

	# Check if subroutine was called as a class method
	if (ref($self) !~ /vbox/i) {
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

	my $shortname  = $self->data->get_computer_short_name;
	my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
	my $hostnode    = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
	my $management_node_keys     = $self->data->get_management_node_keys();
        my @sshcmd;

	if ($control =~ /off|remove/) {
        	undef @sshcmd;
        	@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
        	foreach my $l (@{$sshcmd[1]}) {
                	if ($l =~ m/\_$shortname\"/) {
                        	$l =~ m/{(.*)}/;         
                        	notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                        	notify($ERRORS{'OK'}, 0, "UUID  $1 - POWER OFF");
                        	undef @sshcmd;
                        	@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q controlvm $1 poweroff", "root");
                                if ($control eq 'remove') {
                        		notify($ERRORS{'OK'}, 0, "UUID  $1 - REMOVE");
                        		undef @sshcmd;
                        		@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q storagectl $1 --name $shortname\_stor --remove", "root");
                        		undef @sshcmd;
                        		@sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q unregistervm $1 --delete", "root");
					$self->remove_snapshots();
                                }
                                $ret = 1;
                	}
        	}
		
	}
        if ($control eq 'pause') {
		undef @sshcmd;
                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
                foreach my $l (@{$sshcmd[1]}) {
                        if ($l =~ m/\_$shortname\"/) {
                                $l =~ m/{(.*)}/;
                                notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                                notify($ERRORS{'OK'}, 0, "UUID  $1 - PAUSE");
                                undef @sshcmd;
                                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q controlvm $1 pause", "root");
			}
		}
	}
        if ($control eq 'resume') {
		undef @sshcmd;
                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
                foreach my $l (@{$sshcmd[1]}) {
                        if ($l =~ m/\_$shortname\"/) {
                                $l =~ m/{(.*)}/;
                                notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                                notify($ERRORS{'OK'}, 0, "UUID  $1 - RESUME");
                                undef @sshcmd;
                                @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q controlvm $1 resume", "root");
			}
		}
	}

	my $baseexists   = 0;
	my $dirstructure = 0;
	my $vmison       = 0;
	return $ret;
} ## end sub control_VM

#/////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Either use a passed parameter as the image name or use the one stored in this object's DataStructure
	my $image_name = shift;
	my $image_repository_path = $self->_get_image_repository_path();
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image name could not be determined");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "getting size of image: $image_name");
	

	my $IMAGEREPOSITORY = "$image_repository_path\/vbox\/$image_name";

	#list files in image directory, account for main .gz file and any .gz.00X files
	if (open(FILELIST, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1 |")) {
		my @filelist = <FILELIST>;
		close(FILELIST);
		my $size = 0;
		foreach my $f (@filelist) {
			if ($f =~ /$image_name.*vmdk/) {
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

# This is where VBoxManage will need to be called, and the output parsed into useable data, currently always returning RELOAD to force the code into creating a new VM.

sub node_status {
        my $self = shift;

        my $vmpath             = 0;
        my $datastorepath      = 0;
        my $requestedimagename = 0;
        my $vmhost_type        = 0;
        my $log                = 0;
        my $vmhost_hostname    = 0;
        my $vmhost_imagename   = 0;
        my $vmclient_shortname = 0;
        my $image_os_type      = 0;
        my $request_forimaging = 0;
        my $computer_node_name = 0;
        my $identity_keys      = 0;
		  my $imagerevision_id 	 = 0;

	# Check if subroutine was called as a class method
        if (ref($self) !~ /vbox/i) {
                if (ref($self) eq 'HASH') {
                        $log = $self->{logfile};
                        #notify($ERRORS{'DEBUG'}, $log, "self is a hash reference");

                        $computer_node_name = $self->{computer}->{hostname};
                        $identity_keys      = $self->{managementnode}->{keys};
                        $requestedimagename = $self->{imagerevision}->{imagename};
                        $image_os_type      = $self->{image}->{OS}->{type};
                        $vmhost_type        = $self->{vmhost}->{vmprofile}->{vmtype}->{name};
                        $vmhost_imagename   = $self->{vmhost}->{imagename};
                        $vmpath             = $self->{vmhost}->{vmprofile}->{vmpath};
                        $datastorepath      = $self->{vmhost}->{vmprofile}->{datastorepath};
                        $vmhost_hostname    = $self->{vmhost}->{hostname};

                } ## end if (ref($self) eq 'HASH')
                # Check if node_status returned an array ref
                elsif (ref($self) eq 'ARRAY') {
                        notify($ERRORS{'DEBUG'}, $log, "self is a array reference");
                }

                $vmclient_shortname = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);

        } ## end if (ref($self) !~ /vbox/i)
        else {
                # called as an object
                # Collect local variables from DataStructure

                $vmpath             = $self->data->get_vmhost_profile_vmpath;
                $datastorepath      = $self->data->get_vmhost_profile_datastore_path;
                $requestedimagename = $self->data->get_image_name;
                $vmhost_type        = $self->data->get_vmhost_type;
                $vmhost_hostname    = $self->data->get_vmhost_hostname;
                $vmhost_imagename   = $self->data->get_vmhost_image_name;
                $vmclient_shortname = $self->data->get_computer_short_name;
                $image_os_type      = $self->data->get_image_os_type;
                $request_forimaging = $self->data->get_request_forimaging();
                $identity_keys      = $self->data->get_management_node_keys;
					 $imagerevision_id 	= $self->data->get_imagerevision_id();
					 
        } ## end else [ if (ref($self) !~ /vbox/i)

        notify($ERRORS{'DEBUG'}, $log, "identity_keys= $identity_keys");
        notify($ERRORS{'DEBUG'}, $log, "requestedimagename= $requestedimagename");
        notify($ERRORS{'DEBUG'}, $log, "image_os_type= $image_os_type");
        notify($ERRORS{'DEBUG'}, $log, "request_forimaging= $request_forimaging");
        notify($ERRORS{'DEBUG'}, $log, "vmpath= $vmpath");
        notify($ERRORS{'DEBUG'}, $log, "datastorepath= $datastorepath");

        # Create a hash to store status components
        my %status;

        # Initialize all hash keys here to make sure they're defined
        $status{status}       = 0;
        $status{currentimage} = 0;
        $status{ping}         = 0;
        $status{ssh}          = 0;
        $status{vmstate}      = 0;    #on or off
        $status{image_match}  = 0;

        if (!$identity_keys) {
                notify($ERRORS{'CRITICAL'}, $log, "could not set ssh identity variable for image $vmhost_imagename type= $vmhost_type host= $vmhost_hostname");
        }

        # Check if node is pingable
        notify($ERRORS{'DEBUG'}, $log, "checking if $vmclient_shortname is pingable");
        if (_pingnode($vmclient_shortname)) {
                $status{ping} = 1;
                notify($ERRORS{'OK'}, $log, "$vmclient_shortname is pingable ($status{ping})");
        }
        else {
                notify($ERRORS{'OK'}, $log, "$vmclient_shortname is not pingable ($status{ping})");
                $status{ping}         = 0;
        }

        my $mybasedirname = $requestedimagename;
        my $myimagename   = $requestedimagename;

        # #vm running
        my @sshcmd = run_ssh_command($vmhost_hostname, $identity_keys, "VBoxManage -q showvminfo $requestedimagename\_$vmclient_shortname --machinereadable | grep VMState=", "root");
        foreach my $l (@{$sshcmd[1]}) {
                notify($ERRORS{'OK'}, $log, "$l");
                $status{vmstate} = "on"    if ($l =~ /running/);
                $status{vmstate} = "off"   if ($l =~ /poweroff/);
                $status{vmstate} = "stuck" if ($l =~ /paused/);
                ##if ($l =~ /No such virtual machine/) {
                ##        #ok wait something is using that hostname
                ##        #reset $status{image_match} controlVM will detect and remove it
                ##        $status{image_match} = 0;
                ##}
        } ## end foreach my $l (@{$sshcmd[1]})
        notify($ERRORS{'OK'}, $log, "$vmclient_shortname vmstate reports $status{vmstate}");

        #can I ssh into it
        my $sshd = _sshd_status($vmclient_shortname, $requestedimagename, $image_os_type);

        #is it running the requested image
        if ($sshd eq "on") {

                $status{ssh} = 1;

					 $status{currentimage} = $self->os->get_current_image_info("current_image_name");
					 $status{currentimagerevisionid} = $self->os->get_current_image_info();

                if ($status{currentimagerevisionid}) {
                        chomp($status{currentimagerevisionid});
                        if ($status{currentimagerevisionid} eq $imagerevision_id) {
                                $status{image_match} = 1;
                                notify($ERRORS{'OK'}, $log, "$vmclient_shortname is loaded with requestedimagename imagerevision_id=$imagerevision_id $requestedimagename");
                        }
                        else {
                                notify($ERRORS{'OK'}, $log, "$vmclient_shortname reports current image is currentimage= $status{currentimage} requestedimagename= $requestedimagename");
                        }
                } ## end if ($status{currentimage})
        } ## end if ($sshd eq "on")


        # Determine the overall machine status based on the individual status results
        if ($status{ssh} && $status{image_match}) {
                $status{status} = 'READY';
        }
        else {
                $status{status} = 'RELOAD';
        }

        if ($request_forimaging) {
                $status{status} = 'RELOAD';
                notify($ERRORS{'OK'}, $log, "forimaging flag enabled RELOAD machine");
        }

        notify($ERRORS{'OK'}, $log, "returning node status hash reference (\$node_status->{status}=$status{status})");
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
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
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
	
	# Run du to get the size of the image files if the image exists
	my $du_command = "du -c $image_repository_path\/vbox\/*$image_name* 2>&1 | grep total 2>&1";
	my ($du_exit_status, $du_output) = run_command($du_command);
        notify($ERRORS{'OK'}, 0, "$du_command");
	
	# If the partner doesn't have the image, a "no such file" error should be displayed
	my $image_files_exist;
	if (defined(@$du_output) && grep(/no such file/i, @$du_output)) {
		notify($ERRORS{'OK'}, 0, "$image_name does NOT exist");
		$image_files_exist = 0;
	}
	elsif (defined(@$du_output) && !grep(/\d+\s+total/i, @$du_output)) {
		notify($ERRORS{'WARNING'}, 0, "du output does not contain a total line:\n" . join("\n", @$du_output));
		return;
	}
	elsif (!defined($du_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if image $image_name exists");
		return;
	}
	
	# Return 1 if the image size > 0
	my ($image_size) = (@$du_output[0] =~ /(\d+)\s+total/);
	if ($image_size && $image_size > 0) {
		my $image_size_mb = int($image_size / 1024);
		notify($ERRORS{'DEBUG'}, 0, "$image_name exists in $image_repository_path\/vbox, size: $image_size_mb MB");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does NOT exist: $image_name");
		return 0;
	}

} ## end sub does_image_exist
	
#/////////////////////////////////////////////////////////////////////////////

=head2 retrieve_image

 Parameters  :
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

	# If an argument was specified, use it as the image name
	# If not, get the image name from the reservation data
	my $image_name = shift || $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name from argument or reservation data");
		return;
	}
	
	# Get the last digit of the reservation ID and sleep that number of seconds
	# This is done in case 2 reservations for the same image were started at the same time
	# Both may attempt to retrieve an image and execute the SCP command at nearly the same time
	# does_image_exist() may not catch this and allow 2 SCP retrieval processes to start
	# It's likely that the reservation IDs are consecutive and the the last digits will be different
	my ($pre_retrieval_sleep) = $self->data->get_reservation_id() =~ /(\d)$/;
	notify($ERRORS{'DEBUG'}, 0, "sleeping for $pre_retrieval_sleep seconds to prevent multiple SCP image retrieval processes");
	sleep $pre_retrieval_sleep;
	
	# Make sure image does not already exist on this management node
	if ($self->does_image_exist($image_name)) {
		notify($ERRORS{'OK'}, 0, "$image_name already exists on this management node");
		return 1;
	}

	# Get the image library partner string
	my $image_lib_partners = $self->data->get_management_node_image_lib_partners();
	if (!$image_lib_partners) {
		notify($ERRORS{'WARNING'}, 0, "image library partners could not be determined");
		return;
	}
	
	# Split up the partner list
	my @partner_list = split(/,/, $image_lib_partners);
	if ((scalar @partner_list) == 0) {
		notify($ERRORS{'WARNING'}, 0, "image lib partners variable is not listed correctly or does not contain any information: $image_lib_partners");
		return;
	}
	
	# Get the local image repository path
	my $image_repository_path_local = $self->_get_image_repository_path();
	if (!$image_repository_path_local) {
		notify($ERRORS{'WARNING'}, 0, "image repository path could not be determined");
		return;
	}
	
	# Loop through the partners
	# Find partners which have the image
	# Check size for each partner
	# Retrieve image from partner with largest image
	# It's possible that another partner (management node) is currently copying the image from another managment node
	# This should prevent copying a partial image
	my $largest_partner;
	my $largest_partner_hostname;
	my $largest_partner_image_lib_user;
	my $largest_partner_image_lib_key;
	my $largest_partner_ssh_port;
	my $largest_partner_path;
	my $largest_partner_size = 0;
	
	notify($ERRORS{'OK'}, 0, "attempting to find another management node that contains $image_name");
	foreach my $partner (@partner_list) {
		# Get the connection information for the partner management node
		my $partner_hostname = $self->data->get_management_node_hostname($partner) || '';
		my $partner_image_lib_user = $self->data->get_management_node_image_lib_user($partner) || '';
		my $partner_image_lib_key = $self->data->get_management_node_image_lib_key($partner) || '';
		my $partner_ssh_port = $self->data->get_management_node_ssh_port($partner) || '';
		my $image_repository_path_remote = $self->_get_image_repository_path($partner);
		
		notify($ERRORS{'OK'}, 0, "checking if $partner_hostname has image $image_name");
		notify($ERRORS{'DEBUG'}, 0, "remote image repository path on $partner: $image_repository_path_remote");
		
		# Run du to get the size of the image files on the partner if the image exists
		my ($du_exit_status, $du_output) = run_ssh_command($partner, $partner_image_lib_key, "du -c $image_repository_path_remote\/vbox\/*$image_name* | grep total", $partner_image_lib_user, $partner_ssh_port, 1);
		
		# If the partner doesn't have the image, a "no such file" error should be displayed
		if (defined(@$du_output) && grep(/no such file/i, @$du_output)) {
			notify($ERRORS{'OK'}, 0, "$image_name does NOT exist on $partner_hostname");
			next;
		}
		elsif (defined(@$du_output) && !grep(/\d+\s+total/i, @$du_output)) {
			notify($ERRORS{'WARNING'}, 0, "du output does not contain a total line:\n" . join("\n", @$du_output));
			next;
		}
		elsif (!defined($du_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if image $image_name exists on $partner_hostname");
			next;
		}
		
		# Extract the image size in bytes from the du total output line
		my ($partner_image_size) = (@$du_output[0] =~ /(\d+)\s+total/);
		notify($ERRORS{'OK'}, 0, "$image_name exists on $partner_hostname, size: $partner_image_size bytes");
		
		# Check if the image size is larger than any previously found, if so, save the partner info
		if ($partner_image_size > $largest_partner_size) {
			$largest_partner = $partner;
			$largest_partner_hostname = $partner_hostname;
			$largest_partner_size = $partner_image_size;
			$largest_partner_image_lib_user = $partner_image_lib_user;
			$largest_partner_image_lib_key = $partner_image_lib_key;
			$largest_partner_ssh_port = $partner_ssh_port;
			$largest_partner_path = $image_repository_path_remote;
		}
	}
	
	# Check if any partner was found
	if (!$largest_partner) {
		notify($ERRORS{'WARNING'}, 0, "unable to find $image_name on other management nodes");
		return;
	}
	
	# Attempt copy
	notify($ERRORS{'OK'}, 0, "attempting to retrieve $image_name from $largest_partner_hostname");
	if (run_scp_command("$largest_partner_image_lib_user\@$largest_partner:$largest_partner_path/$image_name*", $image_repository_path_local, $largest_partner_image_lib_key, $largest_partner_ssh_port)) {
		notify($ERRORS{'OK'}, 0, "image $image_name was copied from $largest_partner_hostname");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to copy image $image_name from $largest_partner_hostname");
		return 0;
	}
	
	# Make sure image was copied
	if (!$self->does_image_exist($image_name)) {
		notify($ERRORS{'WARNING'}, 0, "$image_name was not copied to this management node");
		return 0;
	}

	return 1;
} ## end sub retrieve_image

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_image_repository_path

 Parameters  : none, must be called as an object method
 Returns     :
 Description :

=cut

sub _get_image_repository_path {
	my $self = shift;

	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $return_path = "/install";
	return $return_path;
} ## end sub _get_image_repository_path

#/////////////////////////////////////////////////////////////////////////////

=head2 put_node_in_maintenance

 Parameters  : none, must be called as an object method
 Returns     :  1,0
 Description : preforms any actions on node before putting in maintenance state

=cut

sub post_maintenance_action {
	my $self = shift;

	if (ref($self) !~ /vbox/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	#steps putting vm into maintenance
	# check state of vm
	# turn off if needed
	# unregister
	# remove vm machine directory from vmx path
	# set vmhostid to null in computer table - handled in new.pm

	my $computer_short_name   = $self->data->get_computer_short_name;
	my $computer_id = $self->data->get_computer_id();
	my $vmhost_hostname = $self->data->get_vmhost_hostname;

	if ($self->control_VM("remove")) {
		notify($ERRORS{'OK'}, 0, "removed node $computer_short_name from vmhost $vmhost_hostname");
	}

	if (switch_vmhost_id($computer_id, 'NULL')) {
                notify($ERRORS{'OK'}, 0, "set vmhostid to NULL for for VM $computer_short_name");
        }
        else {
                notify($ERRORS{'WARNING'}, 0, "failed to set the vmhostid to NULL for VM $computer_short_name");
                return;
        }

	return 1;

} ## end sub post_maintenance_action

#/////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub power_on {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	## Get necessary data
        my $shortname  = $self->data->get_computer_short_name;
        my $vmhost_hostname    = $self->data->get_vmhost_hostname();
        my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
        my $hostnode = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
        my $management_node_keys = $self->data->get_management_node_keys();
        my @sshcmd;
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
        foreach my $l (@{$sshcmd[1]}) {
                if ($l =~ m/\_$shortname\"/) {
                        $l =~ m/{(.*)}/;
                        notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                        notify($ERRORS{'OK'}, 0, "UUID  $1 - POWERON");
                        undef @sshcmd;
                        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q  startvm $1 --type headless", "root");
                }
        }
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub power_off {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	## Get necessary data
        my $shortname  = $self->data->get_computer_short_name;
	my $vmhost_hostname    = $self->data->get_vmhost_hostname();
        my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
        my $hostnode = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
        my $management_node_keys = $self->data->get_management_node_keys();
        my @sshcmd;
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
        foreach my $l (@{$sshcmd[1]}) {
       		if ($l =~ m/\_$shortname\"/) {
                	$l =~ m/{(.*)}/;
                        notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                        notify($ERRORS{'OK'}, 0, "UUID  $1 - POWEROFF");
                        undef @sshcmd;
                        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q controlvm $1 poweroff", "root");
                }
        }
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub power_reset {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	## Get necessary data
	my $shortname  = $self->data->get_computer_short_name;
        my $vmhost_hostname    = $self->data->get_vmhost_hostname();
        my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
        my $hostnode = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
        my $management_node_keys = $self->data->get_management_node_keys();
        my @sshcmd;
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
        foreach my $l (@{$sshcmd[1]}) {
                if ($l =~ m/\_$shortname\"/) {
                        $l =~ m/{(.*)}/;
                        notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                        notify($ERRORS{'OK'}, 0, "UUID  $1 - RESET");
                        undef @sshcmd;
                        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q controlvm $1 reset", "root");
                }
        }
        

        return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : 
 Returns     : If successful: string containing "on", "off", "suspended", or "stuck"
               If failed: undefined
 Description : 
 

=cut

sub power_status {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	## Get necessary data
        my $shortname  = $self->data->get_computer_short_name;
        my $vmhost_hostname    = $self->data->get_vmhost_hostname();
        my $vmhost_fullhostname = $self->data->get_vmhost_hostname;
        my $hostnode = $1 if ($vmhost_fullhostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
        my $management_node_keys = $self->data->get_management_node_keys();
        my @sshcmd;
        my $vm_uuid;
        my $vm_status = "UNKNOWN";
        undef @sshcmd;
        @sshcmd = run_ssh_command($hostnode, $management_node_keys, "VBoxManage -q list vms", "root");
        foreach my $l (@{$sshcmd[1]}) {
                if ($l =~ m/\_$shortname\"/) {
                        $l =~ m/{(.*)}/;
                        notify($ERRORS{'OK'}, 0, "VM $shortname has UUID  $1");
                        $vm_uuid = $1;
                }
        }

	undef @sshcmd;
	@sshcmd = run_ssh_command($vmhost_hostname, $management_node_keys, "VBoxManage -q showvminfo $vm_uuid --machinereadable | grep VMState=", "root");
        foreach my $l (@{$sshcmd[1]}) {
                $vm_status = "on"    if ($l =~ /running/);
                $vm_status = "off"   if ($l =~ /poweroff/);
                $vm_status = "stuck" if ($l =~ /paused/);
        } ## end foreach my $l (@{$sshcmd[1]})
        notify($ERRORS{'OK'}, 0, "$shortname vmstate reports $vm_status");
	
        return $vm_status;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
