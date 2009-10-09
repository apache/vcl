#!/usr/bin/perl -w
###############################################################################
# $Id: esxthin.pm 807191 2009-08-24 12:46:38Z bmbouter $
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

VCL::Provisioning::esxthin - VCL module supporting the vmware esxthin provisioning engine
which works only when supproted with NetApp hardware

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for vmware esx to boot its virtual machines in a
 copy-on-write fashion.

 http://www.vmware.com

 TODO list:
 Refactor all run_ssh_command calls to check the return code and fail if not 0

=cut

##############################################################################
package VCL::Module::Provisioning::esxthin;

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

# Used to interact with the storage system
require 5.6.1;
use lib "$FindBin::Bin/../../../NetApp";  
use lib "$FindBin::Bin/../lib/NetApp";
use NaServer;
use NaElement;

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
	if (-d '/usr/lib/vmware-vcli/apps') {
		$VMTOOL_ROOT       = '/usr/lib/vmware-vcli/apps';
		$VMTOOLKIT_VERSION = "vsphere4";
	}
	elsif (-d '/usr/lib/vmware-viperl/apps') {
		$VMTOOL_ROOT       = '/usr/lib/vmware-viperl/apps';
		$VMTOOLKIT_VERSION = "vmtoolkit1";
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to initialize esxthin module, neither of the vmware toolkit paths were found: /usr/lib/vmware-vcli/apps/vm /usr/lib/vmware-viperl/apps/vm");
		return;
	}

	# Check to make sure one of the expected executables is where it should be
	if (!-x "$VMTOOL_ROOT/vm/vmregister.pl") {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize esxthin module, expected executable was not found: $VMTOOL_ROOT/vmregister.pl");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "esx vmware toolkit root path found: $VMTOOL_ROOT");

	notify($ERRORS{'DEBUG'}, 0, "vmware ESX module initialized");
	return 1;
} ## end sub initialize

#/////////////////////////////////////////////////////////////////////////////

=head2 provision

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads virtual machine with requested image

=cut

sub load {
	my $self = shift;

	#check to make sure this call is for the esxthin module
	if (ref($self) !~ /esxthin/i) {
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


	#Collect the proper hostname of the ESX server through the vmware tool kit
	notify($ERRORS{'DEBUG'}, 0, "Calling get_vmware_host_info");
	my $vmhost_hostname_value = $self->get_vmware_host_info("hostname");

	if ($vmhost_hostname_value) {
		notify($ERRORS{'DEBUG'}, 0, "Collected $vmhost_hostname_value for vmware host name");
		$vmhost_hostname = $vmhost_hostname_value;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Unable to collect hostname_value for vmware host name using hostname from database");
	}


	#Get the config datastore information from the database
	my $datastore_ip;
	my $datastore_share_path;
	($datastore_ip, $datastore_share_path) = split(":", $self->data->get_vmhost_profile_datastore_path());

	notify($ERRORS{'OK'},    0, "DATASTORE IP is $datastore_ip and DATASTORE_SHARE_PATH is $datastore_share_path");
	notify($ERRORS{'OK'},    0, "Entered ESX module, loading $image_name on $computer_shortname (on $vmhost_hostname) for reservation $reservation_id");
	notify($ERRORS{'DEBUG'}, 0, "Datastore: $datastore_ip:$datastore_share_path");

	# path to the inuse vm folder on the datastore (not a local path)
	my $vmpath = "$datastore_share_path/inuse/$computer_shortname";

	# authenticate with the netapp filer
	my $s = netapp_login();

	# query the host to see if the vm currently exists
	my $vminfo_command = "$VMTOOL_ROOT/vm/vminfo.pl";
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
		my $poweroff_command = "$VMTOOL_ROOT/vm/vmcontrol.pl";
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
		my $unregister_command = "$VMTOOL_ROOT/vm/vmregister.pl";
		$unregister_command .= " --server '$vmhost_shortname'";
		$unregister_command .= " --username $vmhost_username";
		$unregister_command .= " --password '$vmhost_password'";
		$unregister_command .= " --vmxpath '[VCL]/inuse/$computer_shortname/image.vmx'";
		$unregister_command .= " --operation unregister";
		$unregister_command .= " --vmname $computer_shortname";
		$unregister_command .= " --pool Resources";
		$unregister_command .= " --hostname '$vmhost_hostname'";
		$unregister_command .= " --datacenter 'ha-datacenter'";
		notify($ERRORS{'DEBUG'}, 0, "Un-Register Command: $unregister_command");
		my $unregister_output;
		$unregister_output = `$unregister_command`;
		notify($ERRORS{'DEBUG'}, 0, "Un-Registered: $unregister_output");

	} ## end if ($vminfo_output =~ /^Information of Virtual Machine $computer_shortname/m)

	# Remove old vm folder
	# RRRRRRRRRRR
	netapp_delete_dir($s,"/vol/images/inuse/$computer_shortname");

	# Remove old vm folder
	run_ssh_command($datastore_ip, $image_identity, "rm -rf $vmpath");
	notify($ERRORS{'DEBUG'}, 0, "Removed old vm folder");

	# Create new folder for this vm
	if (!run_ssh_command($datastore_ip, $image_identity, "mkdir $vmpath")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not create new directory");
		return 0;
	}

	# Create new folder for this vm
	#RRRRRRR
	netapp_create_dir($s,"/vol/images/inuse/$computer_shortname",'0755');


	# copy appropriate vmdk file
	my $from = "$datastore_share_path/golden/$image_name/image.vmdk";
	my $to   = "$vmpath/image.vmdk";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy vmdk file!");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "COPIED VMDK SUCCESSFULLY");

	# clone vmdk file from golden to inuse
	#RRRRRRRR
	my $from = "/vol/images/golden/$image_name/image.vmdk";
	my $to   = "/vol/images/inuse/$computer_shortname/image.vmdk";
	netapp_fileclone($s,$from,$to);

	# Copy the (large) -flat.vmdk file
	# This uses ssh to do the copy locally, copying over nfs is too costly
	$from = "$datastore_share_path/golden/$image_name/image-flat.vmdk";
	$to   = "$vmpath/image-flat.vmdk";
	if (!run_ssh_command($datastore_ip, $image_identity, "cp $from $to")) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy vmdk-flat file!");
		return 0;
	}

	# Copy the (large) -flat.vmdk file
	#RRRRRRRRR
	$from = "/vol/images/golden/$image_name/image-flat.vmdk";
	$to   = "/vol/images/inuse/$computer_shortname/image-flat.vmdk";
	netapp_fileclone($s,$from,$to);

	# Author new VMX file, output to temporary file (will scp it below)
	my @vmxfile;
	my $vmxpath = "/tmp/$computer_shortname.vmx";

	my $guestOS = "other";
	$guestOS = "winxppro"         if ($image_os_name =~ /(winxp)/i);
	$guestOS = "winnetenterprise" if ($image_os_name =~ /(win2003|win2008)/i);
	$guestOS = "linux"            if ($image_os_name =~ /(fc|centos)/i);
	$guestOS = "linux"            if ($image_os_name =~ /(linux)/i);
	$guestOS = "winvista"         if ($image_os_name =~ /(vista)/i);

	# FIXME Should add some more entries here

	# determine adapter type by looking at vmdk file
	my $adapter = "lsilogic";    # default
	my @output;
	if (@output = run_ssh_command($datastore_ip, $image_identity, "grep adapterType $vmpath/image.vmdk 2>&1")) {
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

	if ($VMWARE_MAC_ETH0_GENERATED) {
		# Let vmware host define the MAC addresses
		notify($ERRORS{'OK'}, 0, "eth0 MAC address set for vmware generated");
		push(@vmxfile, "ethernet0.addressType = \"generated\"\n");
	}
	else {
		# We set a registered MAC
		notify($ERRORS{'OK'}, 0, "eth0 MAC address set for vcl assigned");
		push(@vmxfile, "ethernet0.address = \"$vmclient_eth0MAC\"\n");
		push(@vmxfile, "ethernet0.addressType = \"static\"\n");
	}
	if ($VMWARE_MAC_ETH1_GENERATED) {
		# Let vmware host define the MAC addresses
		notify($ERRORS{'OK'}, 0, "eth1 MAC address set for vmware generated $vmclient_eth0MAC");
		push(@vmxfile, "ethernet1.addressType = \"generated\"\n");
	}
	else {
		# We set a registered MAC
		notify($ERRORS{'OK'}, 0, "eth1 MAC address set for vcl assigned $vmclient_eth1MAC");
		push(@vmxfile, "ethernet1.address = \"$vmclient_eth1MAC\"\n");
		push(@vmxfile, "ethernet1.addressType = \"static\"\n");
	}

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
	push(@vmxfile, "scsi0:0.fileName =\"image.vmdk\"\n");

	my $ascii_vmx_file = '';
	foreach my $vmx_line (@vmxfile) {
		$ascii_vmx_file = $ascii_vmx_file.$vmx_line;
	}

	# Write the VMX file to the NetApp
	#RRRRRR
	netapp_write_file($s,$ascii_vmx_file,"/vol/images/inuse/$computer_shortname/image.vmx");

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

	# scp $vmxpath to $vmpath/image.vmx
	if (!run_scp_command($vmxpath, "$datastore_ip:$vmpath/image.vmx", $image_identity)) {
		notify($ERRORS{'CRITICAL'}, 0, "could not scp vmx file to $datastore_ip");
		return 0;
	}

	# Register new vm on host
	my $register_command = "$VMTOOL_ROOT/vm/vmregister.pl";
	$register_command .= " --server '$vmhost_shortname'";
	$register_command .= " --username $vmhost_username";
	$register_command .= " --password '$vmhost_password'";
	$register_command .= " --vmxpath '[VCL]/inuse/$computer_shortname/image.vmx'";
	$register_command .= " --operation register";
	$register_command .= " --vmname $computer_shortname";
	$register_command .= " --pool Resources";
	$register_command .= " --hostname '$vmhost_hostname'";
	$register_command .= " --datacenter 'ha-datacenter'";
	notify($ERRORS{'DEBUG'}, 0, "Register Command: $register_command");
	my $register_output;
	$register_output = `$register_command`;
	notify($ERRORS{'DEBUG'}, 0, "Registered: $register_output");

	# Turn new vm on
	my $poweron_command = "$VMTOOL_ROOT/vm/vmcontrol.pl";
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

	if ($VMTOOLKIT_VERSION =~ /vsphere4/) {
		$url = "https://$vmhost_shortname/sdk/vimService";

	}
	elsif ($VMTOOLKIT_VERSION =~ /vmtoolkit1/) {
		$url = "https://$vmhost_shortname/sdk";
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "Could not determine VMTOOLKIT_VERSION $VMTOOLKIT_VERSION");
		return 0;
	}

	#Set some variable
	my $wait_loops = 0;
	my $arpstatus  = 0;
	my $client_ip;

	if ($VMWARE_MAC_ETH0_GENERATED) {
		# allowing vmware to generate the MAC address
		# find out what MAC got assigned
		# find out what IP address is assigned to this MAC
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
	} ## end if ($VMWARE_MAC_ETH0_GENERATED)
	else {
		notify($ERRORS{'OK'}, 0, "IP is known for $computer_shortname");
	}
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
			if ($wait_loops > 50) {
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

	# Perform post load tasks

	# Check if OS module has implemented a post_load() subroutine
	if ($self->os->can('post_load')) {
		# If post-load has been implemented by the OS module, don't perform these tasks here
		# new.pm calls the OS module's post_load() subroutine
		notify($ERRORS{'DEBUG'}, 0, "post_load() has been implemented by the OS module, returning 1");
		return 1;
	}

	return 1;

} ## end sub load

#/////////////////////////////////////////////////////////////////////////

=head2 ascii_to_hex

 Parameters  : a single ASCII string
 Returns     : a single hex string
 Description : Converts ASCII to Hex

=cut

sub ascii_to_hex ($)
	{
		## Convert each ASCII character to a two-digit hex number.
		(my $str = shift) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
			return $str;
	}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_login

 Parameters  : None
 Returns     : an authenticated NaServer object
 Description : authenticates with a netapp filer

=cut

sub netapp_login
{
	my $s = NaServer->new ('10.4.0.20',1,3);
#TODO: make the ip not hardcoded
	my $resp = $s->set_style("LOGIN");
	if (ref ($resp) eq "NaElement" && $resp->results_errno != 0) {
		my $r = $resp->results_reason();
		notify($ERRORS{'CRITICAL'}, 0, "Failed to set authentication style $r\n");
		exit 2;
	}
	$s->set_admin_user('vcltestuser', 'd8k3hg6g8s9h');
#TODO: make the user/pass not hardcoded
    
	$resp = $s->set_transport_type("HTTP");
	if (ref ($resp) eq "NaElement" && $resp->results_errno != 0) {
		my $r = $resp->results_reason();
		notify($ERRORS{'CRITICAL'}, 0, "Unable to set HTTP transport $r\n");
		exit 2;
	}
	return $s
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_rename_dir

 Parameters  : $s, $from_path, $to_path
 Returns     : 1(success) or 0(failure)
 Description : Renames the directory at $from_path to $to_path  on the NetApp
               backing $s.  Note that this API cannot be used to rename a
               directory to a different volume.

=cut

sub netapp_rename_dir
{
	my $s = $_[0];
	my $from_path = $_[1];
	my $to_path = $_[2];

	my $in = NaElement->new("file-rename-directory");
	$in->child_add_string("from-path",$from_path);
	$in->child_add_string("to-path",$to_path);

	my $out = $s->invoke_elem($in);
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Renamed directory $from_path to $to_path on netapp");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_create_dir

 Parameters  : $s, $dir_path, $dir_perm
 Returns     : 1(success) or 0(failure)
 Description : creates a directory at the path $dir_path with permissions
               $dir_perm on the NetApp backing $s.  $dir_path should not contain
               a trailing slash


=cut

sub netapp_create_dir
{
	my $s = $_[0];
	my $dir_path = $_[1];
	my $dir_perm = $_[2];

	my $in = NaElement->new("file-create-directory");
	$in->child_add_string("path",$dir_path);
	$in->child_add_string("perm",$dir_perm);

	my $out = $s->invoke_elem($in);
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Created directory $dir_path on netapp");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_write_file

 Parameters  : $s, $ascii_data, $path
 Returns     : 1(success) or 0(failure)
 Description : writes the contents of $ascii_data to $path on the NetApp
               backing $s.  Note: $ascii_data should contain valid ASCII data.

=cut

sub netapp_write_file
{
	my $s = $_[0];
	my $ascii_data = $_[1];
	my $path = $_[2];

	my $hex_data = ascii_to_hex($ascii_data);
	my $out = $s->invoke( "file-write-file","data",$hex_data,"offset",0,"overwrite",0,"path",$path );
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Wrote ASCII data to file $path on netapp");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_delete_dir

 Parameters  : $s, $dir_path
 Returns     : 1(success) or 0(failure)
 Description : deletes a directory at the path $dir_path on the NetApp
               backing $s.  NOTE:  This function will also delete all files
               inside the directory.  Also, if $dir_path is a file it will
               delete that file only.

=cut

sub netapp_delete_dir
{
	my $s = $_[0];
	my $dir_path = $_[1];

	# Check if $dir_path a directory or a file
	my $in = NaElement->new("file-get-file-info");
	$in->child_add_string("path",$dir_path);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		my $file_type = $out->child_get("file-info")->child_get_string("file-type");
		# Is this a file?
		if ($file_type eq "file") {
			netapp_delete_file($s,$dir_path);
			return 1;
		}
	}


	# Start a directory iteration
	my $in = NaElement->new("file-list-directory-iter-start");
	$in->child_add_string("path",$dir_path);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		my $tag_id = $out->child_get_string("tag");
		my $records_num = $out->child_get_int("records");
		
		# Have the NetApp provide a list of all files in the directory
		my $file_request = NaElement->new("file-list-directory-iter-next");
		$file_request->child_add_string("maximum",$records_num);
		$file_request->child_add_string("tag",$tag_id);

		my $file_response = $s->invoke_elem($file_request);
		if($file_response->results_status() eq "failed") {
			notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
			return 0;
		} else {
			my @result = $file_response->child_get("files")->children_get();
			foreach my $file_entry (@result) {
				my $file_type = $file_entry->child_get_string("file-type");
				my $file_name = $file_entry->child_get_string("name");
				# Check if it is a directory or file
				if ($file_type eq "directory") {
					# Make sure '..' and '.' are ignored
					if ($file_name ne ".." and $file_name ne ".") {
						# Recurisly calling netapp_delete_dir with $dir_path/$file_name
						netapp_delete_dir($s,$dir_path.'/'.$file_name);
					}
				} else {
					# Deleting the file at $dir_path/$file_name
					netapp_delete_file($s,"$dir_path/$file_name");
				}
			}
			# Removing empty directory $dir_path
			netapp_delete_empty_dir($s,$dir_path);
		}
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_is_dir

 Parameters  : $s, $dir_path
 Returns     : 1($dir_path exists) or 0($dir_path doesn't exist)
 Description : Determines if the directory $dir_path exists on the NetApp
               backed by $s.  Note, $dir_path should no contain a trailing
               slash.

=cut

sub netapp_is_dir
{
	my $s = $_[0];
	my $dir_path = $_[1];

	# Check if $dir_path a directory or a file
	my $in = NaElement->new("file-get-file-info");
	$in->child_add_string("path",$dir_path);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		#notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		my $file_type = $out->child_get("file-info")->child_get_string("file-type");
		# Is this a dir?
		if ($file_type eq "directory") {
			return 1;
		}
	}
	return 0;
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_get_size

 Parameters  : $s, $path
 Returns     : Size in Bytes
 Description : Determines the size of the directory or file at $path on the
               NetApp backed by $s.  Note: directories should not use a
               trailing slash.

=cut

sub netapp_get_size
{
	my $s = $_[0];
	my $path = $_[1];

	# Check if $path a directory or a file
	my $in = NaElement->new("file-get-file-info");
	$in->child_add_string("path",$path);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		#notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		return $out->child_get("file-info")->child_get_string("file-size");
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_delete_empty_dir

 Parameters  : $s, $dir_path
 Returns     : 1(success) or 0(failure)
 Description : Deletes an empty directory located at $dir_path on the NetApp
               backing $s.

=cut

sub netapp_delete_empty_dir
{
	my $s = $_[0];
	my $dir_path = $_[1];

	my $in = NaElement->new("file-delete-directory");
	$in->child_add_string("path",$dir_path);

	my $out = $s->invoke_elem($in);
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Deleted directory $dir_path on netapp");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_delete_file

 Parameters  : $s, $file_path
 Returns     : 1(success) or 0(failure)
 Description : deletes a file at the path $file_path on the NetApp
               backing $s.

=cut

sub netapp_delete_file
{
	my $s = $_[0];
	my $file_path = $_[1];

	my $in = NaElement->new("file-delete-file");
	$in->child_add_string("path",$file_path);

	my $out = $s->invoke_elem($in);
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Deleted file $file_path on netapp");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_fileclone

 Parameters  : $s, $source_path, $dest_path
 Returns     : 1(success) or 0(failure)
 Description : clones the file $source_path to $dest_path on a NetApp
               storage system backing $s

=cut

sub netapp_fileclone
{
	my $s = $_[0];
	my $source_path = $_[1];
	my $dest_path = $_[2];

	my $in = NaElement->new("clone-start");
	$in->child_add_string("source-path",$source_path);
	$in->child_add_string("destination-path",$dest_path);
	$in->child_add_string("no-snap","false");

	# 
    # Invoke clone-start API
	# 
	my $out = $s->invoke_elem($in);
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		return 1;
	}
}

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


	#check to make sure this call is for the esxthin module
	if (ref($self) !~ /esxthin/i) {
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

	#RRRRRRRRR
	my $old_vmpath = "/vol/images/inuse/$computer_shortname";
	my $new_vmpath = "/vol/images/golden/$new_imagename";

	# These three vars are useful:
	# $old_vmpath, $new_vmpath, $new_imagename

	notify($ERRORS{'OK'}, 0, "SSHing to node to configure currentimage.txt");
	# XXX SHOULD INSTEAD USE write_currentimage_txt IN utils.pm
	my @sshcmd = run_ssh_command($computer_shortname, $image_identity, "echo $new_imagename > /root/currentimage.txt");

	my $poweroff_command = "$VMTOOL_ROOT/vm/vmcontrol.pl";
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

	my $s = netapp_login();
	netapp_rename_dir($s,$old_vmpath,$new_vmpath);

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
	if (ref($self) !~ /esxthin/i) {
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
	} ## end if (ref($self) !~ /esxthin/i)
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
	} ## end else [ if (ref($self) !~ /esxthin/i)

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
	if (ref($self) !~ /esxthin/i) {
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

	my $s = netapp_login();

	#RRRRRRRRR
	if (netapp_is_dir($s,"/vol/images/golden/$image_name") == 1) {
		notify($ERRORS{'DEBUG'}, 0, "Image $image_name exists");
		return 1;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Image $image_name DOES NOT exists");
		return 0;
	}
} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /esxthin/i) {
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

	#RRRRRRRRRRRR
	my $IMAGEREPOSITORY = "/vol/images/golden/$image_name/image-flat.vmdk";
	my $s = netapp_login();
	return int(netapp_get_size($s,$IMAGEREPOSITORY) / 1024);
} ## end sub get_image_size

sub get_vmware_host_info {
	my $self = shift;


	#check to make sure this call is for the esxthin module
	if (ref($self) !~ /esxthin/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	#Get passed arguement
	my $field = shift;
	if (!$field) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine passed field arguement");
		return 0;
	}

	# Get additional information
	my $vmhost_hostname = $self->data->get_vmhost_hostname;
	my $vmhost_username = $self->data->get_vmhost_profile_username();
	my $vmhost_password = $self->data->get_vmhost_profile_password();

	$vmhost_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/;
	my $vmhost_shortname = $1;


	my $vmhost_info_cmd = "$VMTOOL_ROOT/host/hostinfo.pl --username $vmhost_username --password $vmhost_password --server $vmhost_shortname --fields $field";
	my @info_output     = `$vmhost_info_cmd`;
	notify($ERRORS{'DEBUG'}, 0, "host info output for $vmhost_shortname @info_output");

	#Parse output

	foreach my $l (@info_output) {
		if ($l =~ /([a-zA-Z1-9]*):\s*([-_.a-zA-Z1-9]*)/) {
			notify($ERRORS{'DEBUG'}, 0, "found hostname_value= $2");
			return $2;
		}
	}

	notify($ERRORS{'WARNING'}, 0, "no value found for $field output= @info_output");
	return 0;

} ## end sub get_vmware_host_info

initialize();

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 AUTHOR

 Brian Bouterse <bmbouter@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
