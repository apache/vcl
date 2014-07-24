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
our $VERSION = '2.3';

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

# The below variable indicates the full path to the NetApp config file
my $NETAPP_CONFIG_PATH = "$FindBin::Bin/../lib/VCL/Module/Provisioning/esxthin.conf";

##############################################################################

=head1 LOCAL GLOBAL VARIABLES

=cut


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
	
	my $vmhost_eth0generated = $self->data->get_vmhost_profile_eth0generated();
        my $vmhost_eth1generated = $self->data->get_vmhost_profile_eth1generated();

	my $ip_configuration         = $self->data->get_management_node_public_ip_configuration();


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

	notify($ERRORS{'OK'},    0, "Entered ESX module, loading $image_name on $computer_shortname (on $vmhost_hostname) for reservation $reservation_id");

	#Get the config datastore information from the database
	my $volume_path = $self->data->get_vmhost_profile_datastore_path();
	notify($ERRORS{'OK'},    0, "Current image library is hosted at $volume_path");

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

	
	# Read the config file for configs used in the density calculation
	my $storage_admin_email;
	my $density_limit = 14293651161088;
	my $density_alert_threshold = 0.9;
	my $block_copy_limit = 0;

        open(NETAPPCONF, $NETAPP_CONFIG_PATH);
	while (<NETAPPCONF>)
	{
		chomp($_);
		if ($_ =~ /^admin_email=(.*)/) {
			$storage_admin_email = $1;
		} elsif ($_ =~ /^density_limit=(.*)/) { 
			$density_limit = int $1;
		} elsif ($_ =~ /^density_alert_threshold=(.*)/) { 
			$density_alert_threshold = $1;
		} elsif ($_ =~ /^block_copy_limit=(.*)/) { 
			$block_copy_limit = int $1;
		}
	}
	close(NETAPPCONF);

	my $dense_blocks = netapp_get_vol_density($s,$volume_path);
	my $density_percentage = $dense_blocks / $density_limit;
	if ($density_percentage >= $density_alert_threshold) {
		notify($ERRORS{'CRITICAL'}, 0, "The image library volume $volume_path is too dense, and requires administrative attention IMMEDIATELY!!!");
		notify($ERRORS{'CRITICAL'}, 0, "The image library volume $volume_path is $density_percentage % dense");
		my $netapp_ip = $s->{server};
		my $mailmessage = "The Volume $volume_path on NetApp at $netapp_ip is dangerously dense with $density_percentage above the set alert threshold.  A VCL installation relies on this volume.  ACTION REQUIRED: administrativly create and configure another VCL image library volume to distribute the density demands of the VCL installation.";
		mail($storage_admin_email,"Volume $volume_path on NetApp at $netapp_ip Dangerously Dense: Administrative Action Required!!!",$mailmessage, "vcl\@localhost.com");
	} else {
		notify($ERRORS{'DEBUG'}, 0, "The image library volume $volume_path is $density_percentage % dense");
	}

	# Remove old vm folder
	netapp_delete_dir($s,"$volume_path/inuse/$computer_shortname");

	# Create new folder for this vm
	netapp_create_dir($s,"$volume_path/inuse/$computer_shortname",'0755');

	# clone vmdk file from golden to inuse
	my $from = "$volume_path/golden/$image_name/image.vmdk";
	my $to   = "$volume_path/inuse/$computer_shortname/image.vmdk";
	# Call the fileclone.  The 1 at the end tells the function to ignore a slow, thick copy (should it need to be a thick copy)
	netapp_fileclone($s,$from,$to,1,$block_copy_limit);

	# Copy the (large) -flat.vmdk file
	# See esxthin.README for some explanation of the logic implemented in this section
	$to   = "$volume_path/inuse/$computer_shortname/image-flat.vmdk";
	my $continue = "true";
	for (my $count = 0; $continue eq "true"; $count++) {
		# Setup the $from to try to pack the clones densely from the parent goldens
		if ($count == 0) {
			$from = "$volume_path/golden/$image_name/image-flat.vmdk";
			# Call the fileclone.
			# The 0 at the end will cause the clone opeartion to stop with a -1 return code if the clone becomes thick.
			my $clone_status = netapp_fileclone($s,$from,$to,0,$block_copy_limit);
			if ($clone_status == 0) {
				# A Clone error occured.  Provisioning cannot continue
				return 0;
			} elsif ($clone_status == -1) {
				# The original vmdk parent is fully saturated
				notify($ERRORS{'DEBUG'}, 0, "The original vmdk parent $from is saturated in its ability to produce new clones");
			} elsif ($clone_status == 1) {
				# The thin-clone has been successfully completed
				notify($ERRORS{'DEBUG'}, 0, "$to has been thinly cloned successfully");
				$continue = "false";
			}
		} else {
			my $parent = "$volume_path/golden/$image_name/image-flat1.vmdk/image-flat.vmdk";
			# Determine if parent file exists
			if (netapp_is_file($s,$parent) != 1) {
				# The next clone parent file needs to be created
				# TODO: Fix the race condition on this copy if multiple threads do an ndmpcopy over each other
				notify($ERRORS{'DEBUG'}, 0, "Thick copying $from to $parent");
				my $ndmpcopy_to = "$volume_path/golden/$image_name/image-flat1.vmdk";
				netapp_copy($s,$from,$ndmpcopy_to,$image_identity);
			}
			# Call the fileclone.
			# The 0 at the end will cause the clone opeartion to stop with a -1 return code if the clone becomes thick.
			my $clone_status = netapp_fileclone($s,$parent,$to,0,$block_copy_limit);
			if ($clone_status == 0) {
				# A Clone error occured.  Provisioning cannot continue
				return 0;
			} elsif ($clone_status == -1) {
				# Clones of this $parent are coming out thick.  The parent needs to be removed
				notify($ERRORS{'DEBUG'}, 0, "The thick, temporary cloning parent $parent is saturated in its ability to produce new thin clones");
				notify($ERRORS{'DEBUG'}, 0, "$parent must be deleted");
				netapp_delete_dir($s,"$volume_path/golden/$image_name/image-flat1.vmdk");
			} elsif ($clone_status == 1) {
				# The thin-clone has been successfully completed
				notify($ERRORS{'DEBUG'}, 0, "$to has been thinly cloned successfully");
				$continue = "false";
			}
		}
	}

	# Author new VMX file, output to temporary file (will file-write-file it below)
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
	my $vmdk_meta = netapp_read_file($s,"$volume_path/golden/$image_name/image.vmdk");
	if ($vmdk_meta =~ /(ide|buslogic|lsilogic)/) {
		$adapter = $1;
		notify($ERRORS{'OK'}, 0, "adapter= $1 ");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "Could not determine ssh to grep the vmdk file");
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

	if ($vmhost_eth0generated) {
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
	if ($vmhost_eth1generated) {
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
	if (netapp_write_file($s,$ascii_vmx_file,"$volume_path/inuse/$computer_shortname/image.vmx")) {
		notify($ERRORS{'OK'}, 0, "Successfully wrote VMX file");
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Could not write VMX file");
		insertloadlog($reservation_id, $vmclient_computerid, "failed", "could not write vmx file to netapp");
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

	if ($vmhost_eth0generated) {
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
	} ## end if ($vmhost_eth0generated)
	else {
		notify($ERRORS{'OK'}, 0, "IP is known for $computer_shortname");
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
		## Convert each ASCII character to a two-digit hex number
		(my $str = shift) =~ s/(.|\n)/sprintf("%02lx", ord $1)/eg;
		return $str;
	}

#/////////////////////////////////////////////////////////////////////////

=head2 hex_to_ascii

 Parameters  : a single hex string
 Returns     : a single ASCII string
 Description : Converts hex to ASCII

=cut

sub hex_to_ascii ($)
	{
		## Convert each two-digit hex character to an ascii character
		(my $str = shift) =~ s/([a-fA-F0-9]{2})/chr(hex $1)/eg;
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
	my $username = 'root';
	my $password;
	my $ip;
	my $use_https = 'off';

        open(NETAPPCONF, $NETAPP_CONFIG_PATH);
	while (<NETAPPCONF>)
	{
		chomp($_);
		if ($_ =~ /^ip=(.*)/) {
			$ip = $1;
		} elsif ($_ =~ /^user=(.*)/) { 
			$username = $1;
		} elsif ($_ =~ /^pass=(.*)/) { 
			$password = $1;
		} elsif ($_ =~ /^https=(.*)/) { 
			$use_https = $1;
		}
	}
	close(NETAPPCONF);

	my $s = NaServer->new ($ip,1,3);
	my $resp = $s->set_style("LOGIN");
	if (ref ($resp) eq "NaElement" && $resp->results_errno != 0) {
		my $r = $resp->results_reason();
		notify($ERRORS{'CRITICAL'}, 0, "Failed to set authentication style $r\n");
		exit 2;
	}
	$s->set_admin_user($username, $password);

	# Use https if the config file says to do so
	if ($use_https eq 'on') {
		$resp = $s->set_transport_type("HTTPS");
		if (ref ($resp) eq "NaElement" && $resp->results_errno != 0) {
			my $r = $resp->results_reason();
			notify($ERRORS{'CRITICAL'}, 0, "Unable to set HTTPS transport $r\n");
			exit 2;
		}
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

=head2 netapp_read_file

 Parameters  : $s, $path
 Returns     : $ascii_data
 Description : return the contents of $path on the NetApp backing $s in
               ASCII format.

=cut

sub netapp_read_file
{
	my $s = $_[0];
	my $path = $_[1];

	#my $hex_data = ascii_to_hex($ascii_data);
	my $out = $s->invoke( "file-read-file","length",1048576,"offset",0,"path",$path );
 	
	if($out->results_status() eq "failed") {
		notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		notify($ERRORS{'DEBUG'}, 0, "Read ASCII data from file $path on netapp");
		return hex_to_ascii($out->child_get_string("data"));
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
		notify($ERRORS{'DEBUG'}, 0, $out->results_reason() ."\n");
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

=head2 netapp_is_file

 Parameters  : $s, $file_path
 Returns     : 1($file_path exists) or 0($file_path doesn't exist)
 Description : Determines if the file $file_path exists on the NetApp
               backed by $s.  Note, $file_path must begin with /vol and
               should no contain a trailing slash.

=cut

sub netapp_is_file
{
	my $s = $_[0];
	my $file_path = $_[1];

	# Check if $file_path a directory or a file
	my $in = NaElement->new("file-get-file-info");
	$in->child_add_string("path",$file_path);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		#notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		my $file_type = $out->child_get("file-info")->child_get_string("file-type");
		# Is this a file?
		if ($file_type eq "file") {
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

=head2 netapp_get_vol_density

 Parameters  : $s, $vol
 Returns     : The number of dense blocks currently on the volume
 Description : Reports the number of dense blocks volume $vol already has on
               the NetApp backed by $s.  This function calculates density
               according to the formula:
               density = <volume-info><size-used> + <volume-info><sis><size-shared>
               NOTE: $vol must start with /vol/ and must not contain a trailing slash.

=cut

sub netapp_get_vol_density
{
	my $s = $_[0];
	my $vol = $_[1];

	# Check if $path a directory or a file
	my $in = NaElement->new("volume-list-info");
	$in->child_add_string("volume",$vol);
	my $out = $s->invoke_elem($in);
	if($out->results_status() eq "failed") {
		#notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
		return 0;
	} else {
		my $size_used = $out->child_get("volumes")->child_get("volume-info")->child_get_string("size-used");
		my $sis_size_shared = $out->child_get("volumes")->child_get("volume-info")->child_get("sis")->child_get("sis-info")->child_get_string("size-shared");
		return $size_used + $sis_size_shared;
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

=head2 netapp_copy

 Parameters  : $s, $from_path, $to_path, $netapp_identity_file
 Returns     : 1(success) or 0(failure)
 Description : copies the item at $from_path to $to_path on the NetApp
               backing $s.  The identity_file should be passed in from above
               and likelky comes from $self->data->get_image_identity
               NOTE:  The to_path actually names the directory for the thick
               copy to live in.  The file is located inside this directory
               by its same name.

=cut

sub netapp_copy
{
	my $s = $_[0];
	my $from_path = $_[1];
	my $to_path = $_[2];
	my $netapp_identity_file = $_[3];

	my $user = $s->{user};
	my $netapp_ip = $s->{server};
	
	notify($ERRORS{'DEBUG'}, 0, "Doing an ndmpcopy on NetApp ($netapp_ip) of $from_path to $to_path");
	if (!run_ssh_command($netapp_ip, $netapp_identity_file, "ndmpcopy $from_path $to_path", $user)) {
		notify($ERRORS{'CRITICAL'}, 0, "Could not copy file on NetApp via SSH!");
		return 0;
	}
	return 1;

}

#/////////////////////////////////////////////////////////////////////////

=head2 netapp_fileclone

 Parameters  : $s, $source_path, $dest_path, $ignore_thick (boolean),
               $block_copy_limit (int)
 Returns     : 1(success), 0(general failure), or -1 (clone was cancelled
               because it was thick)
 Description : clones the file $source_path to $dest_path on a NetApp
               storage system backing $s.  This is a blocking call, it waits
               for the clone operation to indicate the clone is 'complete'
               before returning '1'  Also, while $ignore_thick is true
               if the clone copies at least $block_copy_limit number of
               thick blocks then the function stops the clone operation and
               returns '-1'  Note: $ignore_thick is optional and 0 by default
               making the function cancel thick file copies the default
               behavior. $block_copy_limit is 0 by defualt, and sets the threshold
               of thick blocks copied before a thin clone is considered thick to 0.

=cut

sub netapp_fileclone
{
	my $s = $_[0];
	my $source_path = $_[1];
	my $dest_path = $_[2];
	my $ignore_thick = 0;
	if (defined($_[3])) {
		$ignore_thick = $_[3];
	}
	my $block_copy_limit = 0;
	if (defined($_[4])) {
		$block_copy_limit = $_[4];
	}

	#The number of seconds to sleep before retrying if there are too many clones occurring
	my $retry = 5;

	my $too_many_clones_occurring = 0;
	do {
		my $in = NaElement->new("clone-start");
		$in->child_add_string("source-path",$source_path);
		$in->child_add_string("destination-path",$dest_path);
		$in->child_add_string("no-snap","false");

		my $out = $s->invoke_elem($in);
		
		if($out->results_status() eq "failed") {
			if ($out->results_errno() == 14611) {
				notify($ERRORS{'DEBUG'}, 0, "Too Many Clones Currently Occuring ... will try again in $retry seconds");
				sleep($retry);
				$too_many_clones_occurring = 1;
			} else {
				notify($ERRORS{'CRITICAL'}, 0, $out->results_reason() ."\n");
				return 0;
			}
		} else {
			# The clone operation has begun
			my $clone_status = "";
			# Grab the volume uuid and clone_op_id specifying this clone operation
			my $volume_uuid = $out->child_get("clone-id")->child_get("clone-id-info")->child_get_string("volume-uuid");
			my $clone_op_id = $out->child_get("clone-id")->child_get("clone-id-info")->child_get_string("clone-op-id");

			# Bundle a new clone-list-status request about the current clone operation
			my $in = NaElement->new("clone-list-status");
			my $clone_id = NaElement->new("clone-id");
			my $clone_id_info = NaElement->new("clone-id-info");
			$clone_id_info->child_add_string("clone-op-id",$clone_op_id);
			$clone_id_info->child_add_string("volume-uuid",$volume_uuid);
			$clone_id->child_add($clone_id_info);
			$in->child_add($clone_id);
			# send the clone-list-status request
			my $out = $s->invoke_elem($in);
			while($out->child_get("status")->child_get("ops-info")->child_get_string("clone-state") ne "completed") {
				notify($ERRORS{'DEBUG'}, 0, "Waiting for clone $dest_path to finish...");
				if($ignore_thick == 0 && $out->child_get("status")->child_get("ops-info")->child_get_string("blocks-copied") > $block_copy_limit) {
					if($out->child_get("status")->child_get("ops-info")->child_get_string("percent-done") < 99) {
						#cancel clone operation
						notify($ERRORS{'DEBUG'}, 0, "The clone $dest_path is being inneficiently copied instead of being cloned...");
						notify($ERRORS{'DEBUG'}, 0, "The clone for $dest_path will now be cancelled");
						# Bundle a new clone-stop request to stop the current clone operation
						my $stop_in = NaElement->new("clone-stop");
						my $stop_clone_id = NaElement->new("clone-id");
						my $stop_clone_id_info = NaElement->new("clone-id-info");
						$stop_clone_id_info->child_add_string("clone-op-id",$clone_op_id);
						$stop_clone_id_info->child_add_string("volume-uuid",$volume_uuid);
						$stop_clone_id->child_add($stop_clone_id_info);
						$stop_in->child_add($stop_clone_id);
						# send the clone-stop request
						my $stop_output = $s->invoke_elem($stop_in);
						if($stop_output->results_status() eq "failed") {
							notify($ERRORS{'CRITICAL'}, 0, $stop_output->results_reason() ."\n");
							return 0;
						} else {
							notify($ERRORS{'DEBUG'}, 0, "The clone for $dest_path has successfully been cancelled");
							return -1;
						}
					}
				}
				sleep(2);
				$out = $s->invoke_elem($in);
			}
			return 1;
		}
	} while($too_many_clones_occurring);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : $request_data_hash_reference
 Returns     : 1 if sucessful, 0 if failed
 Description : Creates a new vmware image.

=cut

sub capture {
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
	my $volume_path = $self->data->get_vmhost_profile_datastore_path();
	notify($ERRORS{'OK'},    0, "Current image library is hosted at $volume_path");

	my $old_vmpath = "$volume_path/inuse/$computer_shortname";
	my $new_vmpath = "$volume_path/golden/$new_imagename";

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

	my $s = netapp_login();
	netapp_rename_dir($s,$old_vmpath,$new_vmpath);

	return 1;
} ## end sub capture


#/////////////////////////////////////////////////////////////////////////

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /esxthin/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_identity = $self->data->get_image_identity;
	my $image_name     = $self->data->get_image_name();

	#Get the config datastore information from the database
	my $volume_path = $self->data->get_vmhost_profile_datastore_path();
	notify($ERRORS{'OK'},    0, "Current image library is hosted at $volume_path");

	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine if image exists, unable to determine image name");
		return 0;
	}

	my $s = netapp_login();

	if (netapp_is_dir($s,"$volume_path/golden/$image_name") == 1) {
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
	my $volume_path = $self->data->get_vmhost_profile_datastore_path();
	notify($ERRORS{'OK'},    0, "Current image library is hosted at $volume_path");

	my $IMAGEREPOSITORY = "$volume_path/golden/$image_name/image-flat.vmdk";
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

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
