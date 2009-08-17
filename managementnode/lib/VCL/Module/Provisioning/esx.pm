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

VCL::Provisioning::esx - VCL module to support the vmware esx provisioning engine

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for vmware esx
 http://www.vmware.com

 TODO list:
 Refactor all run_ssh_command calls to check the return code and fail if not 0

=cut

##############################################################################
package VCL::Module::Provisioning::esx;

# Include File Copying for Perl
use File::Copy;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '1.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);

# Used to query for the MAC address once a host has been registered
use VMware::VIRuntime;
use VMware::VILib;



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

our $VMTOOL_ROOT;
our $VMTOOLKIT_VERSION;

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
	# Check for known vmware toolkit paths
	if(-d '/usr/lib/vmware-vcli/apps/vm'){
		$VMTOOL_ROOT = '/usr/lib/vmware-vcli/apps/vm';
		$VMTOOLKIT_VERSION = "vsphere4";
	}
	elsif(-d '/usr/lib/vmware-viperl/apps/vm'){
		$VMTOOL_ROOT = '/usr/lib/vmware-viperl/apps/vm';
		$VMTOOLKIT_VERSION = "vmtoolkit1";
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to initialize esx module, neither of the vmware toolkit paths were found: /usr/lib/vmware-vcli/apps/vm /usr/lib/vmware-viperl/apps/vm");
		return;
	}

	# Check to make sure one of the expected executables is where it should be
	if (!-x "$VMTOOL_ROOT/vmregister.pl") {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize esx module, expected executable was not found: $VMTOOL_ROOT/vmregister.pl");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "esx vmware toolkit root path found: $VMTOOL_ROOT");

	notify($ERRORS{'DEBUG'}, 0, "vmware ESX module initialized");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 provision

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads virtual machine with requested image

=cut

sub load {
	my $self = shift;

	#check to make sure this call is for the esx module
	if (ref($self) !~ /esx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_data = shift;
	my ($package, $filename, $line, $sub) = caller(0);
	notify($ERRORS{'DEBUG'}, 0, "****************************************************");

	# get various useful vars from the database
	my $request_id           = $self->data->get_request_id;
	my $reservation_id       = $self->data->get_reservation_id;
	my $vmhost_hostname      = $self->data->get_vmhost_hostname;
	my $image_name           = $self->data->get_image_name;
	my $computer_shortname   = $self->data->get_computer_short_name;
	my $vmclient_computerid  = $self->data->get_computer_id;
	my $vmclient_imageminram = $self->data->get_image_minram;
	my $image_os_name        = $self->data->get_image_os_name;
	my $image_os_type        = $self->data->get_image_os_type;
	my $image_identity       = $self->data->get_image_identity;

	my $virtualswitch0   = $self->data->get_vmhost_profile_virtualswitch0;
	my $virtualswitch1   = $self->data->get_vmhost_profile_virtualswitch1;
	my $vmclient_eth0MAC = $self->data->get_computer_eth0_mac_address;
	my $vmclient_eth1MAC = $self->data->get_computer_eth1_mac_address;
	my $vmclient_OSname  = $self->data->get_image_os_name;

	my $vmhost_username = $self->data->get_vmhost_profile_username();
	my $vmhost_password = $self->data->get_vmhost_profile_password();

	$vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/;
	my $vmhost_shortname = $1; 


	#Get the config datastore information from the database
	my $datastore_ip;
	my $datastore_share_path;
	($datastore_ip, $datastore_share_path) = split(":", $self->data->get_vmhost_profile_datastore_path());

	notify($ERRORS{'OK'},    0, "DATASTORE IP is $datastore_ip and DATASTORE_SHARE_PATH is $datastore_share_path");
	notify($ERRORS{'OK'},    0, "Entered ESX module, loading $image_name on $computer_shortname (on $vmhost_hostname) for reservation $reservation_id");
	notify($ERRORS{'DEBUG'}, 0, "Datastore: $datastore_ip:$datastore_share_path");

	# path to the inuse vm folder on the datastore (not a local path)
	my $vmpath = "$datastore_share_path/inuse/$computer_shortname";

	# query the host to see if the vm currently exists
	my $vminfo_command = "$VMTOOL_ROOT/vminfo.pl";
	$vminfo_command .= " --server '$vmhost_shortname'";
	$vminfo_command .= " --vmname $computer_shortname";
	$vminfo_command .= " --username $vmhost_username";
	$vminfo_command .= " --password '$vmhost_password'";
	notify($ERRORS{'DEBUG'}, 0, "VM info command: $vminfo_command");
	my $vminfo_output;
	$vminfo_output = `$vminfo_command`;
	notify($ERRORS{'DEBUG'}, 0, "VM info output: $vminfo_output");

	# parse the results from the host and determine if we need to remove an old vm
	if ($vminfo_output =~ /^Information of Virtual Machine $computer_shortname/m) {
		# Power off this vm
		my $poweroff_command = "$VMTOOL_ROOT/vmcontrol.pl";
		$poweroff_command .= " --server '$vmhost_shortname'";
		$poweroff_command .= " --vmname $computer_shortname";
		$poweroff_command .= " --operation poweroff";
		$poweroff_command .= " --username $vmhost_username";
		$poweroff_command .= " --password '$vmhost_password'";
		notify($ERRORS{'DEBUG'}, 0, "Power off command: $poweroff_command");
		my $poweroff_output;
		$poweroff_output = `$poweroff_command`;
		notify($ERRORS{'DEBUG'}, 0, "Powered off: $poweroff_output");

		# unregister old vm from host
		my $unregister_command = "$VMTOOL_ROOT/vmregister.pl";
		$unregister_command .= " --server '$vmhost_shortname'";
		$unregister_command .= " --username $vmhost_username";
		$unregister_command .= " --password '$vmhost_password'";
		$unregister_command .= " --vmxpath '[VCL]/inuse/$computer_shortname/$image_name.vmx'";
		$unregister_command .= " --operation unregister";
		$unregister_command .= " --vmname $computer_shortname";
		$unregister_command .= " --pool Resources";
		$unregister_command .= " --hostname '$vmhost_shortname'";
		$unregister_command .= " --datacenter 'ha-datacenter'";
		notify($ERRORS{'DEBUG'}, 0, "Un-Register Command: $unregister_command");
		my $unregister_output;
		$unregister_output = `$unregister_command`;
		notify($ERRORS{'DEBUG'}, 0, "Un-Registered: $unregister_output");

	} ## end if ($vminfo_output =~ /^Information of Virtual Machine $computer_shortname/m)

	# Remove old vm folder
	run_ssh_command($datastore_ip, $image_identity, "rm -rf $vmpath");
	notify($ERRORS{'DEBUG'}, 0, "Removed old vm folder");

	# Create new folder for this vm
	if (!run_ssh_command($datastore_ip, $image_identity, "mkdir $vmpath")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not create new directory");
		return 0;
	}


	# copy appropriate vmdk file
	my $from = "$datastore_share_path/golden/$image_name/$image_name.vmdk";
	my $to   = "$vmpath/$image_name.vmdk";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy vmdk file!");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "COPIED VMDK SUCCESSFULLY");


	# Copy the (large) -flat.vmdk file
	# This uses ssh to do the copy locally, copying over nfs is too costly
	$from = "$datastore_share_path/golden/$image_name/$image_name-flat.vmdk";
	$to   = "$vmpath/$image_name-flat.vmdk";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy vmdk-flat file!");
		return 0;
	}

	# Author new VMX file, output to temporary file (will scp it below)
	my @vmxfile;
	my $vmxpath = "/tmp/$computer_shortname.vmx";

	my $guestOS = "other";
	$guestOS = "winxppro" if ($image_os_name =~ /(winxp)/i);
	$guestOS = "winnetenterprise"  if ($image_os_name =~ /(win2003|win2008)/i);
	$guestOS = "linux" if ($image_os_name =~ /(fc|centos)/i);
	$guestOS = "linux" if ($image_os_name =~ /(linux)/i);
	$guestOS = "winvista" if ($image_os_name =~ /(vista)/i);

	# FIXME Should add some more entries here

	# determine adapter type by looking at vmdk file
	my $adapter = "lsilogic";    # default
	my @output;
	if (@output = run_ssh_command($datastore_ip, $image_identity, "grep adapterType $vmpath/$image_name.vmdk 2>&1")) {
		my @LIST = @{$output[1]};
		foreach (@LIST) {
			if ($_ =~ /(ide|buslogic|lsilogic)/) {
				$adapter = $1;
				notify($ERRORS{'OK'}, 0, "adapter= $1 ");
			}
		}
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "Could not ssh to grep the vmdk file");
		return 0;
	}

	push(@vmxfile, "#!/usr/bin/vmware\n");
	push(@vmxfile, "config.version = \"8\"\n");
	push(@vmxfile, "virtualHW.version = \"4\"\n");
	push(@vmxfile, "memsize = \"$vmclient_imageminram\"\n");
	push(@vmxfile, "displayName = \"$computer_shortname\"\n");
	push(@vmxfile, "guestOS = \"$guestOS\"\n");
	push(@vmxfile, "uuid.action = \"create\"\n");
	push(@vmxfile, "Ethernet0.present = \"TRUE\"\n");
	push(@vmxfile, "Ethernet1.present = \"TRUE\"\n");

	push(@vmxfile, "Ethernet0.networkName = \"$virtualswitch0\"\n");
	push(@vmxfile, "Ethernet1.networkName = \"$virtualswitch1\"\n");
	push(@vmxfile, "ethernet0.wakeOnPcktRcv = \"false\"\n");
	push(@vmxfile, "ethernet1.wakeOnPcktRcv = \"false\"\n");

	#push(@vmxfile, "ethernet0.address = \"$vmclient_eth0MAC\"\n");
	#push(@vmxfile, "ethernet1.address = \"$vmclient_eth1MAC\"\n");
	push(@vmxfile, "ethernet0.addressType = \"generated\"\n");
	push(@vmxfile, "ethernet1.addressType = \"generated\"\n");
	push(@vmxfile, "gui.exitOnCLIHLT = \"FALSE\"\n");
	push(@vmxfile, "snapshot.disabled = \"TRUE\"\n");
	push(@vmxfile, "floppy0.present = \"FALSE\"\n");
	push(@vmxfile, "priority.grabbed = \"normal\"\n");
	push(@vmxfile, "priority.ungrabbed = \"normal\"\n");
	push(@vmxfile, "checkpoint.vmState = \"\"\n");

	push(@vmxfile, "scsi0.present = \"TRUE\"\n");
	push(@vmxfile, "scsi0.sharedBus = \"none\"\n");
	push(@vmxfile, "scsi0.virtualDev = \"$adapter\"\n");
	push(@vmxfile, "scsi0:0.present = \"TRUE\"\n");
	push(@vmxfile, "scsi0:0.deviceType = \"scsi-hardDisk\"\n");
	push(@vmxfile, "scsi0:0.fileName =\"$image_name.vmdk\"\n");

	# write vmx to temp file
	if (open(TMP, ">$vmxpath")) {
		print TMP @vmxfile;
		close(TMP);
		notify($ERRORS{'OK'}, 0, "wrote vmxarray to $vmxpath");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "could not write vmxarray to $vmxpath");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not write vmx file to local tmp file");
		return 0;
	}

	# scp $vmxpath to $vmpath/$image_name.vmx
	if (!run_scp_command($vmxpath, "$datastore_ip:$vmpath/$image_name.vmx", $image_identity)) {
		notify($ERRORS{'CRITICAL'}, 0, "could not scp vmx file to $datastore_ip");
		return 0;
	}

	# Register new vm on host
	my $register_command = "$VMTOOL_ROOT/vmregister.pl";
	$register_command .= " --server '$vmhost_shortname'";
	$register_command .= " --username $vmhost_username";
	$register_command .= " --password '$vmhost_password'";
	$register_command .= " --vmxpath '[VCL]/inuse/$computer_shortname/$image_name.vmx'";
	$register_command .= " --operation register";
	$register_command .= " --vmname $computer_shortname";
	$register_command .= " --pool Resources";
	$register_command .= " --hostname '$vmhost_shortname'";
	$register_command .= " --datacenter 'ha-datacenter'";
	notify($ERRORS{'DEBUG'}, 0, "Register Command: $register_command");
	my $register_output;
	$register_output = `$register_command`;
	notify($ERRORS{'DEBUG'}, 0, "Registered: $register_output");

	# Turn new vm on
	my $poweron_command = "$VMTOOL_ROOT/vmcontrol.pl";
	$poweron_command .= " --server '$vmhost_shortname'";
	$poweron_command .= " --vmname $computer_shortname";
	$poweron_command .= " --operation poweron";
	$poweron_command .= " --username $vmhost_username";
	$poweron_command .= " --password '$vmhost_password'";
	notify($ERRORS{'DEBUG'}, 0, "Power on command: $poweron_command");
	my $poweron_output;
	$poweron_output = `$poweron_command`;
	notify($ERRORS{'DEBUG'}, 0, "Powered on: $poweron_output");


	# Query the VI Perl toolkit for the mac address of our newly registered
	# machine

	my $url; 

	if($VMTOOLKIT_VERSION =~ /vsphere4/){
		$url = "https://$vmhost_shortname/sdk/vimService";

	}
	elsif($VMTOOLKIT_VERSION =~ /vmtoolkit1/){
		$url = "https://$vmhost_shortname/sdk";
	}
	else{
		notify($ERRORS{'CRITICAL'}, 0, "Could not determine VMTOOLKIT_VERSION $VMTOOLKIT_VERSION");
		return 0;
	}
	
	Vim::login(service_url => "https://$vmhost_shortname/sdk", user_name => $vmhost_username, password => $vmhost_password);
	Vim::login(service_url => $url, user_name => $vmhost_username, password => $vmhost_password);
	my $vm_view = Vim::find_entity_view(view_type => 'VirtualMachine', filter => {'config.name' => "$computer_shortname"});
	if (!$vm_view) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not query for VM in VI PERL API");
		Vim::logout();
		return 0;
	}
	my $devices = $vm_view->config->hardware->device;
	my $mac_addr;
	foreach my $dev (@$devices) {
		next unless ($dev->isa("VirtualEthernetCard"));
		notify($ERRORS{'DEBUG'}, 0, "deviceinfo->summary: $dev->deviceinfo->summary");
		notify($ERRORS{'DEBUG'}, 0, "virtualswitch0: $virtualswitch0");
		if ($dev->deviceInfo->summary eq $virtualswitch0) {
			$mac_addr = $dev->macAddress;
		}
	}
	Vim::logout();
	if (!$mac_addr) {
		notify($ERRORS{'CRITICAL'}, 0, "Failed to find MAC address");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "Queried MAC address is $mac_addr");

	# Query ARP table for $mac_addr to find the IP (waiting for machine to come up if necessary)
	# The DHCP negotiation should add the appropriate ARP entry for us
	my $arpstatus  = 0;
	my $wait_loops = 0;
	my $client_ip;
	while (!$arpstatus) {
		my $arpoutput = `arp -n`;
		if ($arpoutput =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*?$mac_addr/mi) {
			$client_ip = $1;
			$arpstatus = 1;
			notify($ERRORS{'OK'}, 0, "$computer_shortname now has ip $client_ip");
		}
		else {
			if ($wait_loops > 24) {
				notify($ERRORS{'CRITICAL'}, 0, "waited acceptable amount of time for dhcp, please check $computer_shortname on $vmhost_shortname");
				return 0;
			}
			else {
				$wait_loops++;
				notify($ERRORS{'OK'}, 0, "going to sleep 5 seconds, waiting for computer to DHCP. Try $wait_loops");
				sleep 5;
			}
		} ## end else [ if ($arpoutput =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}).*?$mac_addr/mi)
	} ## end while (!$arpstatus)


	notify($ERRORS{'OK'}, 0, "Found IP address $client_ip");

	# Delete existing entry for $computer_shortname in /etc/hosts (if any)
	notify($ERRORS{'OK'}, 0, "Removing old hosts entry");
	my $sedoutput = `sed -i "/.*\\b$computer_shortname\$/d" /etc/hosts`;
	notify($ERRORS{'DEBUG'}, 0, $sedoutput);

	# Add new entry to /etc/hosts for $computer_shortname
	`echo -e "$client_ip\t$computer_shortname" >> /etc/hosts`;

	# Start waiting for SSH to come up
	my $sshdstatus = 0;
	$wait_loops = 0;
	my $sshd_status = "off";
	notify($ERRORS{'DEBUG'}, 0, "Waiting for ssh to come up on $computer_shortname");
	while (!$sshdstatus) {
		my $sshd_status = _sshd_status($computer_shortname, $image_name, $image_os_type);
		if ($sshd_status eq "on") {
			$sshdstatus = 1;
			notify($ERRORS{'OK'}, 0, "$computer_shortname now has active sshd running");
		}
		else {
			#either sshd is off or N/A, we wait
			if ($wait_loops > 24) {
				notify($ERRORS{'CRITICAL'}, 0, "waited acceptable amount of time for sshd to become active, please check $computer_shortname on $vmhost_shortname");
				#need to check power, maybe reboot it. for now fail it
				return 0;
			}
			else {
				$wait_loops++;
				# to give post config a chance
				notify($ERRORS{'OK'}, 0, "going to sleep 5 seconds, waiting for computer to start SSH. Try $wait_loops");
				sleep 5;
			}
		}    # else
	}    #while

	# Set IP info
	if ($IPCONFIGURATION ne "manualDHCP") {
		#not default setting
		if ($IPCONFIGURATION eq "dynamicDHCP") {
			insertloadlog($reservation_id, $vmclient_computerid, "dynamicDHCPaddress", "collecting dynamic IP address for node");
			notify($ERRORS{'DEBUG'}, 0, "Attempting to query vmclient for its public IP...");
			my $assignedIPaddress = getdynamicaddress($computer_shortname, $vmclient_OSname, $image_os_type);
			if ($assignedIPaddress) {
				#update computer table
				notify($ERRORS{'DEBUG'}, 0, " Got dynamic address from vmclient, attempting to update database");
				if (update_computer_address($vmclient_computerid, $assignedIPaddress)) {
					notify($ERRORS{'DEBUG'}, 0, " succesfully updated IPaddress of node $computer_shortname");
				}
				else {
					notify($ERRORS{'CRITICAL'}, 0, "could not update dynamic address $assignedIPaddress for $computer_shortname $image_name");
					return 0;
				}
			} ## end if ($assignedIPaddress)
			else {
				notify($ERRORS{'CRITICAL'}, 0, "could not fetch dynamic address from $computer_shortname $image_name");
				insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not collect dynamic IP address for node");
				return 0;
			}
		} ## end if ($IPCONFIGURATION eq "dynamicDHCP")
		elsif ($IPCONFIGURATION eq "static") {
			notify($ERRORS{'CRITICAL'}, 0, "STATIC ASSIGNMENT NOT SUPPORTED. See vcld.conf");
			return 0;
			#insertloadlog($reservation_id, $vmclient_computerid, "staticIPaddress", "setting static IP address for node");
			#if (setstaticaddress($computer_shortname, $vmclient_OSname, $vmclient_publicIPaddress)) {
			#	# good set static address
			#}
		}
	} ## end if ($IPCONFIGURATION ne "manualDHCP")
	return 1;

} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : $request_data_hash_reference
 Returns     : 1 if sucessful, 0 if failed
 Description : Creates a new vmware image.

=cut

sub capture {
	notify($ERRORS{'DEBUG'}, 0, "**********************************************************");
	notify($ERRORS{'OK'},    0, "Entering ESX Capture routine");
	my $self = shift;


	#check to make sure this call is for the esx module
	if (ref($self) !~ /esx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_data = shift;
	my ($package, $filename, $line, $sub) = caller(0);
	my $vmhost_hostname    = $self->data->get_vmhost_hostname;
	my $new_imagename      = $self->data->get_image_name;
	my $computer_shortname = $self->data->get_computer_short_name;
	my $image_identity     = $self->data->get_image_identity;
	my $vmhost_username    = $self->data->get_vmhost_profile_username();
	my $vmhost_password    = $self->data->get_vmhost_profile_password();

	$vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/;
	my $vmhost_shortname = $1;

	#Get the config datastore information from the database
	my $datastore_ip;
	my $datastore_share_path;
	($datastore_ip, $datastore_share_path) = split(":", $self->data->get_vmhost_profile_datastore_path());

	my $old_vmpath = "$datastore_share_path/inuse/$computer_shortname";
	my $new_vmpath = "$datastore_share_path/golden/$new_imagename";

	# These four vars are useful:
	# $old_vmpath, $new_vmpath, $old_imagename, $new_imagename


	# Find old image name:
	my $old_imagename;
	#if (open(LISTFILES, "ls -1 $inuse_image 2>&1 |")) {
	my @ssh_output;
	if (@ssh_output = run_ssh_command($datastore_ip, $image_identity, "ls -1 $old_vmpath 2>&1")) {
		my @list = @{$ssh_output[1]};
		#figure out old name
		foreach my $a (@list) {
			chomp($a);
			if ($a =~ /(.*)-(v[0-9]*)\.vmdk/) {
				$old_imagename = "$1-$2";
			}
		}
	} ## end if (@ssh_output = run_ssh_command($datastore_ip...
	else {
		notify($ERRORS{'CRITICAL'}, 0, "LS failed");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "found previous name= $old_imagename");

	notify($ERRORS{'OK'}, 0, "SSHing to node to configure currentimage.txt");
	# XXX SHOULD INSTEAD USE write_currentimage_txt IN utils.pm
	my @sshcmd = run_ssh_command($computer_shortname, $image_identity, "echo $new_imagename > /root/currentimage.txt");

	my $poweroff_command = "$VMTOOL_ROOT/vmcontrol.pl";
	$poweroff_command .= " --server '$vmhost_shortname'";
	$poweroff_command .= " --vmname $computer_shortname";
	$poweroff_command .= " --operation poweroff";
	$poweroff_command .= " --username $vmhost_username";
	$poweroff_command .= " --password '$vmhost_password'";
	notify($ERRORS{'DEBUG'}, 0, "Power off command: $poweroff_command");
	my $poweroff_output;
	$poweroff_output = `$poweroff_command`;
	notify($ERRORS{'DEBUG'}, 0, "Powered off: $poweroff_output");

	notify($ERRORS{'OK'}, 0, "Waiting 5 seconds for power off");
	sleep(5);

	# Make the new golden directory
	if (!run_ssh_command($datastore_ip, $image_identity, "mkdir $new_vmpath")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not create new directory: $!");
		return 0;
	}

	# copy appropriate vmdk file
	my $from = "$old_vmpath/$old_imagename.vmdk";
	my $to   = "$new_vmpath/$new_imagename.vmdk";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy VMDK file! $!");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "COPIED VMDK SUCCESSFULLY");

	# Now copy the vmx file (for debugging, vmx isn't actually used. This code can be taken out)
	$from = "$old_vmpath/$old_imagename.vmx";
	$to   = "$new_vmpath/$new_imagename.vmx";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy VMX file! $!");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "COPIED VMX SUCCESSFULLY");

	my $output;
	notify($ERRORS{'OK'}, 0, "Rewriting VMDK and VMX files with new image name");
	if (!run_ssh_command($datastore_ip, $image_identity, "sed -i \"s/$old_imagename/$new_imagename/\" $new_vmpath/$new_imagename.vmx")) {
		notify($ERRORS{'CRITICAL'}, 0, "Sed error");
		return 0;
	}
	if (!run_ssh_command($datastore_ip, $image_identity, "sed -i \"s/$old_imagename/$new_imagename/\" $new_vmpath/$new_imagename.vmdk")) {
		notify($ERRORS{'CRITICAL'}, 0, "Sed error");
		return 0;
	}

	# Copy the (large) -flat.vmdk file
	# This uses ssh to do the copy locally on the nfs server.
	$from = "$old_vmpath/$old_imagename-flat.vmdk";
	$to   = "$new_vmpath/$new_imagename-flat.vmdk";
	notify($ERRORS{'DEBUG'}, 0, "Preparing to ssh to $datastore_ip copy vmdk-flat from $from to $to");
	notify($ERRORS{'OK'},    0, "SSHing to copy vmdk-flat file");
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy VMDK-flat file!");
		return 0;
	}


	return 1;
} ## end sub capture


#/////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $nodename, $log
 Returns     : array of related status checks
 Description : checks on sshd, currentimage

=cut

sub node_status {
	my $self = shift;

	my ($package, $filename, $line, $sub) = caller(0);

	my $vmpath             = 0;
	my $datastorepath      = 0;
	my $requestedimagename = 0;
	my $vmhost_type        = 0;
	my $vmhost_hostname    = 0;
	my $vmhost_imagename   = 0;
	my $image_os_type      = 0;
	my $vmclient_shortname = 0;
	my $request_forimaging = 0;
	my $identity_keys      = 0;
	my $log                = 0;
	my $computer_node_name = 0;


	# Check if subroutine was called as a class method
	if (ref($self) !~ /esx/i) {
		notify($ERRORS{'OK'}, 0, "subroutine was called as a function");
		if (ref($self) eq 'HASH') {
			$log = $self->{logfile};
			#notify($ERRORS{'DEBUG'}, $log, "self is a hash reference");

			$vmpath             = $self->{vmhost}->{vmprofile}->{vmpath};
			$datastorepath      = $self->{vmhost}->{vmprofile}->{datastorepath};
			$requestedimagename = $self->{imagerevision}->{imagename};
			$vmhost_type        = $self->{vmhost}->{vmprofile}->{vmtype}->{name};
			$vmhost_hostname    = $self->{vmhost}->{hostname};
			$vmhost_imagename   = $self->{vmhost}->{imagename};
			$image_os_type      = $self->{image}->{OS}->{type};
			$computer_node_name = $self->{computer}->{hostname};
			$identity_keys      = $self->{managementnode}->{keys};

		} ## end if (ref($self) eq 'HASH')
		    # Check if node_status returned an array ref
		elsif (ref($self) eq 'ARRAY') {
			notify($ERRORS{'DEBUG'}, $log, "self is a array reference");
		}

		$vmclient_shortname = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);
	} ## end if (ref($self) !~ /esx/i)
	else {

		# try to contact vm
		# $self->data->get_request_data;
		# get state of vm
		$vmpath             = $self->data->get_vmhost_profile_vmpath;
		$datastorepath      = $self->data->get_vmhost_profile_datastore_path;
		$requestedimagename = $self->data->get_image_name;
		$vmhost_type        = $self->data->get_vmhost_type;
		$vmhost_hostname    = $self->data->get_vmhost_hostname;
		$vmhost_imagename   = $self->data->get_vmhost_image_name;
		$image_os_type      = $self->data->get_image_os_type;
		$vmclient_shortname = $self->data->get_computer_short_name;
		$request_forimaging = $self->data->get_request_forimaging();
	} ## end else [ if (ref($self) !~ /esx/i)

	notify($ERRORS{'OK'},    0, "Entering node_status, checking status of $vmclient_shortname");
	notify($ERRORS{'DEBUG'}, 0, "request_for_imaging: $request_forimaging");
	notify($ERRORS{'DEBUG'}, 0, "requeseted image name: $requestedimagename");

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
		$identity = $IDENTITY_bladerhel;    #if($vm{vmhost}{imagename} =~ /^(rhel|rh3image|rh4image|fc|rhfc)/);
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
	#my $vmx_directory = "$requestedimagename$vmclient_shortname";
	#my $myvmx         = "$vmpath/$requestedimagename$vmclient_shortname/$requestedimagename$vmclient_shortname.vmx";
	#my $mybasedirname = $requestedimagename;
	#my $myimagename   = $requestedimagename;

	notify($ERRORS{'DEBUG'}, 0, "Trying to ssh...");

	#can I ssh into it
	my $sshd = _sshd_status($vmclient_shortname, $requestedimagename, $image_os_type);


	#is it running the requested image
	if ($sshd eq "on") {

		notify($ERRORS{'DEBUG'}, 0, "SSH good, trying to query image name");

		$status{ssh} = 1;
		my $identity = $IDENTITY_bladerhel;
		my @sshcmd = run_ssh_command($vmclient_shortname, $identity, "cat currentimage.txt");
		$status{currentimage} = $sshcmd[1][0];

		notify($ERRORS{'DEBUG'}, 0, "Image name: $status{currentimage}");

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

	# Determine the overall machine status based on the individual status results
	if ($status{ssh} && $status{image_match}) {
		$status{status} = 'READY';
	}
	else {
		$status{status} = 'RELOAD';
	}

	notify($ERRORS{'DEBUG'}, 0, "status set to $status{status}");


	if ($request_forimaging) {
		$status{status} = 'RELOAD';
		notify($ERRORS{'OK'}, 0, "request_forimaging set, setting status to RELOAD");
	}

	notify($ERRORS{'DEBUG'}, 0, "returning node status hash reference (\$node_status->{status}=$status{status})");
	return \%status;

} ## end sub node_status

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /esx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_identity = $self->data->get_image_identity;
	my $image_name     = $self->data->get_image_name();

	#Get the config datastore information from the database
	my $datastore_ip;
	my $datastore_share_path;
	($datastore_ip, $datastore_share_path) = split(":", $self->data->get_vmhost_profile_datastore_path());

	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine if image exists, unable to determine image name");
		return 0;
	}

	my $goldenpath = "$datastore_share_path/golden";

	my @ssh_output;
	if (@ssh_output = run_ssh_command($datastore_ip, $image_identity, "ls -1 $goldenpath 2>&1")) {
		my @list = @{$ssh_output[1]};
		#figure out old name
		foreach my $a (@list) {
			chomp($a);
			if ($a =~ /$image_name/) {
				notify($ERRORS{'OK'}, 0, "image $image_name exists");
				return 1;
			}
		}
	} ## end if (@ssh_output = run_ssh_command($datastore_ip...
	else {
		notify($ERRORS{'CRITICAL'}, 0, "LS failed");
		return 0;
	}

	notify($ERRORS{'WARNING'}, 0, "image $goldenpath/$image_name does NOT exists");
	return 0;

} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////

=head2  getimagesize

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /esx/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Either use a passed parameter as the image name or use the one stored in this object's DataStructure
	my $image_name     = shift;
	my $image_identity = $self->data->get_image_identity;
	$image_name = $self->data->get_image_name() if !$image_name;
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image name could not be determined");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "getting size of image: $image_name");

	#Get the config datastore information from the database
	my $datastore_ip;
	my $datastore_share_path;
	($datastore_ip, $datastore_share_path) = split(":", $self->data->get_vmhost_profile_datastore_path());

	my $IMAGEREPOSITORY = "$datastore_share_path/golden/$image_name";

	#list files in image directory, account for main .gz file and any .gz.00X files
	my @output;
	if (@output = run_ssh_command($datastore_ip, $image_identity, "/bin/ls -s1 $IMAGEREPOSITORY 2>&1")) {
		my @filelist = @{$output[1]};
		my $size     = 0;
		foreach my $f (@filelist) {
			if ($f =~ /$image_name-flat.vmdk/) {
				my ($presize, $blah) = split(" ", $f);
				$size += $presize;
			}
		}
		if ($size == 0) {
			#strange imagename not found
			return 0;
		}
		return int($size / 1024);
	} ## end if (@output = run_ssh_command($datastore_ip...

	return 0;
} ## end sub get_image_size

initialize();

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 AUTHOR

 Andrew Brown <ambrown4@ncsu.edu>
 Brian Bouterse <bmbouter@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
