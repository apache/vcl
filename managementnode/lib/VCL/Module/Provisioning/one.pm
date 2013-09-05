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

VCL::Provisioning::one - VCL module to support OpenNebula Cloud

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for OpenNebula Cloud

=cut

##############################################################################
package VCL::Module::Provisioning::one;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.3.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);
use Frontier::Client;
use XML::Simple;
use Data::Dumper;

my %one;
my $xml;

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
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $one_username = $self->data->get_vmhost_profile_username();
	my $one_password = $self->data->get_vmhost_profile_password();
	my $one_server_url = $self->data->get_vmhost_profile_resource_path();
	
	if (defined($one_username) and defined($one_password) and defined($one_server_url)) {
	
		$one{'server_url'} = $one_server_url;
		$one{'auth'} = "$one_username:$one_password"; 
		$one{'server'} = Frontier::Client->new(url => $one{'server_url'});
		$one{'false'} = $one{'server'}->boolean(0);
		$one{'true'} = $one{'server'}->boolean(1);
	
		$xml = XML::Simple->new();
	
		notify($ERRORS{'DEBUG'}, 0, "Module ONE initialized with following parameters: \n one_server_url -> $one{'server_url'}, one_username:one_password -> $one{'auth'}\n");
	
		return 1;
	} else {
		notify($ERRORS{'CRITICAL'}, 0,"one_username, one_password, one_server_url not defined in VM Host profile. Abort.");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 provision

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads node with provided image

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /one/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $computer_id = $self->data->get_computer_id();
	my $image_name = $self->data->get_image_name();
	my $eth0_ip = $self->data->get_computer_private_ip_address();
	my $image_os_type = $self->data->get_image_os_type();
	my $one_network_0 = $self->data->get_vmhost_profile_virtualswitch0();
	my $one_network_1 = $self->data->get_vmhost_profile_virtualswitch1();
	my $vm_name = $self->data->get_image_prettyname();
	my $cpu_count = $self->data->get_image_minprocnumber() || 1;
	my $image_arch = $self->data->get_image_architecture();
	if ($image_arch ne "x86_64") {$image_arch = "i686";}
	my $memory = $self->data->get_image_minram();
	my $computer_name = $self->data->get_computer_hostname();
	if ($memory < 512) {
		$memory = 512;
		$memory = $cpu_count * 2048;
	}
	my $one_vm_name = "$computer_name ($image_name)";

	
	#delete running VM, if present
	my $one_computer_id = $self->one_get_object_id("computer",$computer_name);
	if ($one_computer_id) {
		$self->one_delete_vm($one_computer_id);
	}
	
	my $one_network_0_id = $self->one_get_object_id("network",$one_network_0);
	my $one_network_1_id = $self->one_get_object_id("network",$one_network_1);
	my $one_image_id = $self->one_get_object_id("image",$image_name);
	my $one_virtio = '';
	$one_virtio = $self->one_get_virtio($one_image_id);
	
	my $one_network = 'NIC=[NETWORK_ID="'.$one_network_0_id.'",IP="'.$eth0_ip.'"'.$one_virtio.']';
	
	if ($self->data->can("get_vNetwork")) {
		my @vNetwork = $self->data->get_vNetwork();
		if (@vNetwork) {
			# yes, add custom network(s);
			notify($ERRORS{'OK'}, 0, "Reservation will be loaded with addition Networks:");
			foreach (@vNetwork) {
				my $one_net_id = $self->one_get_object_id("network",'VLAN_ID='.$_);
				$one_network = $one_network.'NIC=[NETWORK_ID="'.$one_net_id.'"'.$one_virtio.']';
				}
		} else { 
			# no custom networks, add eth1 as default public;
			$one_network = $one_network.'NIC=[NETWORK_ID="'.$one_network_1_id.'"'.$one_virtio.']';
		}
	} else {
		# custom networking is not implemented, add eth1 as default public;
		$one_network = $one_network.'NIC=[NETWORK_ID="'.$one_network_1_id.'"'.$one_virtio.']';
	}
	
	# Check if SWAP disk needed, format: DISK=[DEV_PREFIX="vd",TYPE="swap",SIZE="4096"]
	my $swap_disk = '';
	my $swap_size = $self->get_image_tag_value("SWAP");
	if (defined($swap_size)) {
		if ($self->get_image_tag_value("DEV_PREFIX") eq "vd") {
			$swap_disk = 'DISK=[DEV_PREFIX="vd",TYPE="swap",SIZE="'.$swap_size.'"]';
		} else {
			$swap_disk = 'DISK=[TYPE="swap",SIZE="'.$swap_size.'"]';
		}
	}
	
	my $VM_TEMPLATE = 'OS=[BOOT="hd",ARCH="'.$image_arch.'",ACPI="YES"] 
		NAME="'.$one_vm_name.'"
		CPU="'.$cpu_count.'"
		VCPU="'.$cpu_count.'" 
		INPUT=[BUS="usb",TYPE="tablet"]
		MEMORY="'.$memory.'" 
		GRAPHICS=[TYPE="VNC",LISTEN="0.0.0.0"] 
		DISK=[IMAGE_ID="'.$one_image_id.'"]'.$swap_disk.$one_network;
	
	# create VM
	my @reply = $one{'server'}->call('one.vm.allocate',$one{'auth'},$VM_TEMPLATE,$one{'false'});
	
	if ( $reply[0][0]->value() ) {
		notify($ERRORS{'OK'}, 0, "New VM ".$vm_name." deployed with ID: $reply[0][1] using template: $VM_TEMPLATE");
		insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "defined $computer_name");
		insertloadlog($reservation_id, $computer_id, "startvm", "powered on $computer_name");
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "\n".$VM_TEMPLATE."\n".$reply[0][1]);
		return 0;
	}
	

	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "performed OS post-load tasks for $computer_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on $computer_name");
			return;
		}
	}
	else {
		insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "OS post-load tasks not necessary $computer_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////
=head2 one_get_virtio

 Parameters  : imagename
 Returns     : '' or MODEL="virtio"
 Description : 

=cut

sub one_get_virtio {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	my $one_image_id = shift;
	
	my @reply = $one{'server'}->call('one.image.info',$one{'auth'},$one_image_id);
	
	if ( $reply[0][0]->value() ) {
		my $data = $xml->XMLin($reply[0][1]);
		if ($data->{TEMPLATE}{DEV_PREFIX} eq 'vd' ) {
			return ',MODEL="virtio"';
		}
	} else {
		notify($ERRORS{'WARNING'}, 0, "couldn't get image configuration for image_id $one_image_id, won't use VIRTIO driver.");
		return '';
	}
	
	return '';
}
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

	my $image_name = $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name");
		return;
	}
	
	my $one_image_id = $self->one_get_object_id("image",$image_name);
	if ($one_image_id) {
		notify($ERRORS{'DEBUG'}, 0, "Found image $image_name with id $one_image_id");
		return $one_image_id;
	} 

	notify($ERRORS{'DEBUG'}, 0, "Image $image_name NOT found on ONE");
	return 0;
} 

#/////////////////////////////////////////////////////////////////////////////

=head2 one_get_object_id

 Parameters  : $o_type, $o_name
 Returns     : ONE Object ID (INT)
 Description : 

=cut

sub one_get_object_id {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $o_type = shift;
	my $o_name = shift;
	
	if ($o_type eq "computer") {
		my @reply = $one{server}->call('one.vmpool.info',$one{'auth'},-3,-1,-1,-1);
		if ( $reply[0][0]->value() ) {
			
			my $data = $xml->XMLin($reply[0][1]);
			if ( (ref($data->{VM})) eq "ARRAY" ){
				foreach (@{$data->{VM}}) {
			    	if ($_->{NAME} =~ /$o_name/i) {
			        	return $_->{ID};
			        }
			  	}
		    } else { #HASH, found only one entry
				if ($data->{VM}{NAME} =~ /$o_name/i) {
			    	return $data->{VM}{ID};
			    }
			}
		} else {
			notify($ERRORS{'CRITICAL'}, 0, $reply[0][1]);
			return 0;
		}	
	} elsif ($o_type eq "image") {
		my @reply = $one{'server'}->call('one.imagepool.info', $one{'auth'},-3,-1,-1);
		if ( $reply[0][0]->value() ) {
			
			my $rs_data = $xml->XMLin($reply[0][1]);
				if ( (ref($rs_data->{IMAGE})) eq "ARRAY" ) {
					foreach (@{$rs_data->{IMAGE}}) {
						if ($_->{NAME} eq $o_name) {
 							return $_->{ID};
						}
					}
					} else { #HASH, only one entry
						if ($rs_data->{IMAGE}{NAME} eq $o_name) {
							return $rs_data->{IMAGE}{ID};
						}
					}
		} else {
			notify($ERRORS{'CRITICAL'}, 0, $reply[0][1]);
			return 0;
		}
	} elsif ($o_type eq "network") {
		my @reply = $one{'server'}->call('one.vnpool.info',$one{'auth'},-1,-1,-1);
		if ($reply[0][0]->value()) {
			my $rs_data = $xml->XMLin($reply[0][1]);
			# don't check if ARRAY or HASH since we always have more then 1 network
			foreach (@{$rs_data->{VNET}}) {
				# if $o_name is in VLAN_ID= then lookup by VLAN_ID, not NAME
				
				if ($o_name =~ /^VLAN_ID=/i) {
					my @vlan_id = split('=',$o_name);
					if ($_->{VLAN_ID} == $vlan_id[1]) {
						return $_->{ID};
					}
				} else {
					if ($_->{NAME} eq $o_name) {
						return $_->{ID};
					}
				}
			}
		} else {
			notify($ERRORS{'CRITICAL'},0,$reply[0][1]);
			return 0;
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "$o_type is UNKNOWN type");
		return 0;
	} 
	
	return 0;	
} 

#/////////////////////////////////////////////////////////////////////////////

=head2 one_delete_vm

 Parameters  : $vmid
 Returns     : 
 Description : one.vm.action

=cut

sub one_delete_vm {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my $vmid = shift;
	my @reply;
	
	@reply = $one{'server'}->call('one.vm.action', $one{'auth'},'delete',$vmid);
	if ( $reply[0][0]->value() ) {
		notify($ERRORS{'OK'}, 0, "ONE VM $vmid deleted");
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $reply[0][1]);
	}
	
} 


#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub capture {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	
	my $image_id = $self->data->get_image_id();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $image_type = $self->data->get_imagetype_name();
	my $computer_name = $self->data->get_computer_hostname();
	my $one_new_image_id = 0;
	
	$self->data->set_imagemeta_sysprep(0);
	
	notify($ERRORS{'OK'}, 0, "ONE module starting image capture.");
	
	my $vmid = $self->one_get_object_id("computer",$computer_name);
	if ($vmid) {
		my @savedisk = $one{'server'}->call('one.vm.savedisk', $one{'auth'},$vmid,0,$image_name,'OS',$one{'false'});
		if ( $savedisk[0][0]->value() ) {
			notify($ERRORS{'OK'}, 0, "VM $vmid will be captured as $image_name");
			
		} else {
			notify($ERRORS{'CRITICAL'}, 0, $savedisk[0][1]);
			return;
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Couldn't find vmid for $computer_name. Abort.");
		return 0;
	}
	# check for new image to be READY (1)

	# Call the OS module's pre_capture() subroutine, this will shutdown the VM at the end
	if ($self->os->can("pre_capture")) {
	 	if (!$self->os->pre_capture({end_state => 'off'})) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to complete OS module's pre_capture tasks");
			return;
		} else {
			notify($ERRORS{'OK'}, 0, "OS's pre_capture complited OK.");
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "OS module doesn't implement pre_capture(). Abort.");
		return;
	}

	my $attempt = 0;
	my $sleep = 15;
	while (1) {
		$attempt++;
		$one_new_image_id = $self->one_get_object_id("image",$image_name);
		last if ($one_new_image_id);
		if ($attempt > 20) {
			notify($ERRORS{'CRITICAL'}, 0, "ONE could not locate new disk id for $image_name");
			last;
		}
		sleep $sleep;
	}
	
	$attempt = 0;
	my $total_attempts = 120;
	while (1) {
		$attempt++;
		notify($ERRORS{'OK'}, 0, "check status for new image id $one_new_image_id, attempt $attempt / $total_attempts");
		my $one_image_state = $self->one_get_image_state($one_new_image_id);
		if ($one_image_state == 4) {
			notify($ERRORS{'OK'}, 0, "disk save in pregress, image id $one_new_image_id is LOCKED");
		}
		if ($one_image_state == 5) {
			notify($ERRORS{'CRITICAL'}, 0, "disk save failed, image id $one_new_image_id is ERROR");
			return 0;
		}
		if ($one_image_state == 1) {
			notify($ERRORS{'OK'}, 0, "disk save OK, image id $one_new_image_id is READY");
			return 1;
		}
		if ( $attempt > $total_attempts ) {
			notify($ERRORS{'CRITICAL'}, 0, "disk save failed, image id $one_new_image_id is not READY after $total_attempts attempts");
			return 0;
		}	
		sleep $sleep;
	}
	
	return 0;
	
}

sub one_get_image_state {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_id = shift;
	
	my @status = $one{'server'}->call('one.image.info',$one{'auth'},$image_id);
	if ( $status[0][0]->value() ) {
		my $data = $xml->XMLin($status[0][1]);
		return $data->{STATE};
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $status[0][1]);
	}
	
}

=head2 opennebula
 Description : returns 1. Yes, it's opennebula module.
=cut
sub opennebula {
	return 1;
}

=head2 power_off

 Parameters  : 
 Returns     : 
 Description : send 'shutdown' to VM via controller.
				* need to add check if VM is OFF. Sometimes VM won't power off *

=cut

sub power_off {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	my $vmid = $self->one_get_object_id("computer",$computer_name);
	my @poweroff = $one{'server'}->call('one.vm.action', $one{'auth'},'shutdown',$vmid);
	
	if ( $poweroff[0][0]->value() ) {
		notify($ERRORS{'OK'}, 0, "Sent shutdown signal to VM $vmid");
		return 1;
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $poweroff[0][1]);
		return 0;
	}
	
} ## end sub power_off

=head2 power_reset
=cut

sub power_reset() {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	my $vmid = $self->one_get_object_id("computer",$computer_name);
	my @poweroff = $one{'server'}->call('one.vm.action', $one{'auth'},'reboot',$vmid);
	
	if ( $poweroff[0][0]->value() ) {
		notify($ERRORS{'OK'}, 0, "Sent reboot signal to VM $vmid");
		return 1;
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $poweroff[0][1]);
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 one_wait_for_vm_status

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub one_wait_for_vm_state {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmid = shift;
	my $state = shift;
	my $wait = shift;
	my $sleep = 15;
	my $num_state = 0;
	
	# 6 - POWEROFF
	
	$num_state = 6 if ($state eq "SHUTDOWN");
	
	
	if (!$num_state) {
		notify($ERRORS{'CRITICAL'}, 0, "Unknown vm_state: $state requested");
		return 0;
	}
	
	while (1) {
		notify($ERRORS{'OK'}, 0, "Check state of VM $vmid ...");
		my $ttime;
		my $one_vm_state = $self->one_get_vm_state($vmid);
		if ( $self->one_get_vm_state($vmid) == $num_state ) {
			notify($ERRORS{'OK'}, 0, "VM $vmid is in $state state");
			return 1;
		} else {
			notify($ERRORS{'OK'}, 0, "VM $vmid is NOT in $state state. Waiting $sleep sec...");
			sleep $sleep;
			$ttime = $ttime + $sleep;
			if ($ttime >= $wait) {
				notify($ERRORS{'CRITICAL'}, 0, "VM $vmid is still NOT in $state state after $wait sec, abort");
				last;
			}
		}
	}
	
	return 0;
	
} ## end sub one_wait_for_vm_status

sub one_get_vm_state {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	# one.vm.info
	my $vmid = shift;
	
	my @result = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ( $result[0][0]->value() ) {
		my $data = $xml->XMLin($result[0][1]);
		return $data->{STATE}; 
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : $domain_name (optional)
 Returns     : string
 Description : Determines the power state of the domain. A string is returned
               containing one of the following values:
                  * 'on'
                  * 'off'
                  * 'suspended'
=cut

sub power_status {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_hostname();
	my $vmid = $self->one_get_object_id("computer",$computer_name);
	
	my @result = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ( $result[0][0]->value() ) {
		my $data = $xml->XMLin($result[0][1]);
		if ($data->{STATE} == 3) {
			if ($data->{LCM_STATE} == 3) {
				notify($ERRORS{'OK'}, 0, "vm $vmid is RUNNING, STATE=3 and LCM_STATE=3");
				return 'on';
			}
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
		return 0;
	}

	return 'off';
	
} ## end sub power_status

=head2 power_on

 Parameters  : $domain_name (optional)
 Returns     : string
 Description : powers on VM
=cut

sub power_on {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my $computer_name = $self->data->get_computer_hostname();
	my $vmid = $self->one_get_object_id("computer",$computer_name);
	#later
	return 1;
	
} ## end sub power_on
#/////////////////////////////////////////////////////////////////////////////

=head2 new

 Parameters  : 
 Returns     : 
 Description : 
=cut


sub get_image_size {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_image_tag_value("SIZE");
#	
#	my $image_name = $self->data->get_image_name();
#	
#	my $imid = $self->one_get_object_id("image",$image_name);
#	my @result = $one{server}->call('one.image.info',$one{'auth'},$imid);
#	if ( $result[0][0]->value() ) {
#		my $data = $xml->XMLin($result[0][1]);
#		return $data->{SIZE}; 
#	} else {
#		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
#		return 0;
#	}
}

sub get_image_tag_value {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $tag = shift;
	
	my $image_name = $self->data->get_image_name();
	
	my $imid = $self->one_get_object_id("image",$image_name);
	my @result = $one{server}->call('one.image.info',$one{'auth'},$imid);
	if ( $result[0][0]->value() ) {
		my $data = $xml->XMLin($result[0][1]);
		
		if ($tag eq 'SIZE') {
			if (defined($data->{$tag})) {
				return $data->{$tag};
			} else {
				return;
			}
		}
		
		if ($tag eq 'SWAP') {
			if (defined($data->{TEMPLATE}{$tag})) {
				return $data->{TEMPLATE}{$tag};
			} else {
				return;
			}
		}
		
		if ($tag eq 'DEV_PREFIX') {
			if (defined($data->{TEMPLATE}{$tag})) {
				return $data->{TEMPLATE}{$tag};
			} else {
				return;
			}
		}
		
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
		return 0;
	}
	notify($ERRORS{'CRITICAL'},0,"requested tag = $tag, don't know how to get it...");
	return 0;
}


1;
__END__

