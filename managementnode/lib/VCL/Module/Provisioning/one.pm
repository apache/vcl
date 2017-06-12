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

VCL::Provisioning::one - VCL module to support OpenNebula Cloud

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for OpenNebula Cloud

=cut

###############################################################################
package VCL::Module::Provisioning::one;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw(-no_match_vars);

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);
use Frontier::Client;
use XML::Simple;
use Data::Dumper;

my %one;
my $xml;

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

#//////////////////////////////////////////////////////////////////////////////

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
		#$memory = $cpu_count * 2048;
	}
	my $one_vm_name = "$computer_name ($image_name)";

	#delete running VM, if present
	notify($ERRORS{'OK'}, 0, "Checking if computer $computer_name already loaded on ONE...");
	my $one_computer_id = $self->_one_get_object_id("computer",$computer_name);
	if ($one_computer_id) {
		$self->_one_delete_vm($one_computer_id);
		notify($ERRORS{'OK'}, 0, "Computer $computer_name was running on ONE ... deleted.");
		# sleep for 2sec to allow ONE process the request:
		sleep 2;
	}
	
	# check if there is ONE template already exsist for the image
	# and create VM based on the template. If no template create 'manually'
	
	my $one_template_id = $self->_one_get_template_id($image_name);
	if ($one_template_id) {
		my @template_info = $one{'server'}->call('one.template.info',$one{'auth'},$one_template_id);
		if ($template_info[0][0]->value()) {
			my $data = XMLin($template_info[0][1]);
			my $template;
			$template = $data->{TEMPLATE};
			$template->{NAME} = $one_vm_name;
			$template->{NIC}[0]{IP} = $eth0_ip;
			
			my $one_new_vmid = $self->_one_create_vm(XMLout($template,NoAttr => 1,RootName=>'TEMPLATE',));	
			if ($one_new_vmid) {
				notify($ERRORS{'OK'}, 0, "New VM $template->{NAME} deployed with ID $one_new_vmid using template ID $one_template_id");
				insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "defined $computer_name");
				insertloadlog($reservation_id, $computer_id, "startvm", "powered on $computer_name");
			} else {
				notify($ERRORS{'CRITICAL'}, 0, "Could't create requested VM. Abort.");
				return 0;
			}
		} else {
			notify($ERRORS{'CRITICAL'}, 0, "Error while making one.template.info call: $template_info[0][1]");
		}
	} else {
		
		# No template, create VM manually:
		my $template = {};
		my $one_network_0_id = $self->_one_get_object_id("network",$one_network_0);
		my $one_network_1_id = $self->_one_get_object_id("network",$one_network_1);
		my $one_image_id = $self->_one_get_object_id("image",$image_name);
		my $one_virtio = $self->_one_get_virtio($one_image_id);
		my $virtio = 0;
		if ($self->_one_get_image_tag_value($image_name,"DEV_PREFIX") eq "vd") {
			$virtio = 1;
		}
		
		$template->{NAME} = $one_vm_name;
		$template->{CPU} = $cpu_count;
		$template->{VCPU} = $cpu_count;
		$template->{MEMORY} = $memory;
		$template->{OS}{ARCH} = $image_arch; 
		$template->{INPUT}{BUS} = "usb";
		$template->{INPUT}{TYPE} = "tablet";
		$template->{GRAPHICS}{TYPE} = "VNC";
		$template->{GRAPHICS}{LISTEN} = "0.0.0.0";
		$template->{REQUIREMENTS} = "CLUSTER_ID=\"100\"";
		#$template->{REQUIREMENTS} = "CLUSTER_ID=\"100\" | CLUSTER_ID=\"108\"";
		$template->{DISK}[0]{IMAGE_ID} = $one_image_id;
		$template->{NIC}[0]{NETWORK_ID} = $one_network_0_id;
		$template->{NIC}[0]{IP} = $eth0_ip;
		$template->{NIC}[0]{MODEL} = "virtio" if ($virtio);
		$template->{NIC}[1]{NETWORK_ID} = $one_network_1_id;
		$template->{NIC}[1]{MODEL} = "virtio" if ($virtio);
			
		# Check if SWAP disk needed. Does image have SWAP=<size_MB> attribute?
		my $swap_disk = '';
		my $swap_size = $self->_one_get_image_tag_value($image_name,"SWAP");
		if ($swap_size) {
			$template->{DISK}[1]{TYPE} = "swap";
			$template->{DISK}[1]{SIZE} = $swap_size;
			$template->{DISK}[1]{DEV_PREFIX} = "vd" if ($virtio); 
		}
		
		# create VM
		
		my $one_new_vmid = $self->_one_create_vm(XMLout($template,NoAttr => 1,RootName=>'TEMPLATE',));	
		if ($one_new_vmid) {
			notify($ERRORS{'OK'}, 0, "New VM $template->{NAME} deployed with ID $one_new_vmid");
			insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "defined $computer_name");
			insertloadlog($reservation_id, $computer_id, "startvm", "powered on $computer_name");
		}	
	}
	# VM is created and loading, execute "post_load"
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


#//////////////////////////////////////////////////////////////////////////////

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
	
	my $one_image_id = $self->_one_get_object_id("image",$image_name);
	if ($one_image_id) {
		notify($ERRORS{'DEBUG'}, 0, "Found image $image_name with id $one_image_id");
		return $one_image_id;
	} 

	notify($ERRORS{'DEBUG'}, 0, "Image $image_name NOT found on ONE");
	return 0;
} 

#//////////////////////////////////////////////////////////////////////////////



#//////////////////////////////////////////////////////////////////////////////

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
	
	my $old_image_name;
	my $image_name = $self->data->get_image_name();
	
	my $image_id = $self->data->get_image_id();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $image_type = $self->data->get_imagetype_name();
	my $computer_name = $self->data->get_computer_hostname();
	my $one_new_image_id = 0;
	
	$self->data->set_imagemeta_sysprep(0);
	
	notify($ERRORS{'OK'}, 0, "ONE module starting image capture.");
	
	my $vmid = $self->_one_get_object_id("computer",$computer_name);
	if ($vmid) {
		# get {TEMPLATE}{DISK}{IMAGE} of $vmid, the name of current image
		
		$old_image_name = $self->_one_get_vm_disk($vmid);
		
		my @savedisk = $one{'server'}->call('one.vm.savedisk', $one{'auth'},$vmid,0,$image_name,'OS',$one{'false'});
		if ($savedisk[0][0]->value()) {
			notify($ERRORS{'OK'}, 0, "VM $vmid will be captured as $image_name");
			
		} else {
			notify($ERRORS{'CRITICAL'}, 0, $savedisk[0][1]);
			return;
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Couldn't find vmid for $computer_name. Abort.");
		return 0;
	}

	# Call the OS module's pre_capture() subroutine (don't shutdown at the end)
	if ($self->os->can("pre_capture")) {
	 	if (!$self->os->pre_capture({end_state => 'on'})) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to complete OS module's pre_capture tasks");
			return;
		} else {
			notify($ERRORS{'OK'}, 0, "OS's pre_capture complited OK.");
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "OS module doesn't implement pre_capture(). Abort.");
		return;
	}
	
	# pre_capture was called with {end_state => 'on'}. Need to shutdown VM via ACPI.
	if (!$self->power_off()) {
		notify($ERRORS{'CRITICAL'}, 0, "Couldn't shutdown $computer_name with power_off()");
		return 0;
	} else {
		# notify($ERRORS{'DEBUG'}, 0, "Sent 'shutdown' to computer $computer_name via provisioning module");
		# make sure VM enters STATE=ACTIVE (3) & LCM_STATE=EPILOG(11)
		# if VM doesn't reach EPILOG, wait for ACTIVE/RUNNING (3/3) and then send 'shutdown-hard', check for EPILOG again.
		my $sleep = 5;
		my $wait_time = 5 * 60; # how long to wait for LCM_STATE = EPILOG
		my $flag = 0;
		my $state;
		my $lcm_state;
		
		notify($ERRORS{'OK'}, 0, "Wait for the VM $vmid to enter ACTIVE/EPILOG (3/11) state...");
		EPILOG: while (1) {
			$state = $self->_one_get_vm_state($vmid);
			notify($ERRORS{'OK'}, 0, "VM $vmid is in $state state");
			if ($state == 3) {
				$lcm_state = $self->_one_get_vm_lcm_state($vmid);
				notify($ERRORS{'OK'}, 0, "VM $vmid is in $lcm_state lcm_state");
				if ($lcm_state == 11) {
					notify($ERRORS{'OK'}, 0, "VM $vmid is in EPILOG state. OK");
					last EPILOG;
				} else {
					notify($ERRORS{'OK'}, 0, "VM $vmid is in $state / $lcm_state state...");
				}
			} else {
				notify($ERRORS{'DEBUG'}, 0, "VM $vmid should be in ACTIVE (3) state, but it's in $state state");
				return 0;
			}
			sleep $sleep;
			$wait_time = $wait_time - $sleep;
			notify($ERRORS{'OK'}, 0, "Waiting for VM $vmid to enter ACTIVE/EPILOG state, $wait_time sec left ...");
			
			if ($wait_time <= $sleep) {
				notify($ERRORS{'DEBUG'}, 0, "VM $vmid never reached EPILOG state. Wait for ACTIVE/RUNNING (3/3) and send 'shutdown-hard'");
				my $sleep = 15;
				my $wait_time = 20 * 60; #how long to wait for ACTIVE/RUNNING (3/3)
				
				while (1) {
					$state = $self->_one_get_vm_state($vmid);
					if ($state == 3) {
						$lcm_state = $self->_one_get_vm_lcm_state($vmid);
						if ($lcm_state == 3) {
							notify($ERRORS{'OK'}, 0, "VM $vmid is in $state / $lcm_state state. Wait $sleep sec and send 'shutdown-hard'");
							sleep $sleep;
							if (!$self->power_off('hard')) {
								notify($ERRORS{'CRITICAL'}, 0, "Couldn't shutdown $computer_name with power_off('hard')");
								return 0;
							} 
							last EPILOG;
						} else {
							notify($ERRORS{'OK'}, 0, "VM $vmid is in $state / $lcm_state state...");
						}
					} else {
						notify($ERRORS{'OK'}, 0, "VM $vmid is in $state state...");
					}
					sleep $sleep if ($wait_time > 0);
					$wait_time = $wait_time - $sleep;
					notify($ERRORS{'OK'}, 0, "Waiting for VM $vmid to enter ACTIVE/RUNNING state, $wait_time sec left ...");
					if ($wait_time <= $sleep) {
						notify($ERRORS{'CRITICAL'}, 0, "VM $vmid is in $state / $lcm_state after $wait_time sec ... Fail!");
						return 0;
					}
				}
			}
		}
	}

	# Check that we have new_image_name created on ONE (it will be in LOCKED state until disk_save is done).
	# just procation, image stub should be created already.
	my $sleep = 5;
	my $wait_time = 20 * 60; # in min * 60 = seconds
	while (1) {
		$one_new_image_id = $self->_one_get_object_id("image",$image_name);
		last if ($one_new_image_id);
		$wait_time = $wait_time - $sleep;
		if ($wait_time <= 0) {
			notify($ERRORS{'CRITICAL'}, 0, "Could not locate new disk id for $image_name. disk_save wasn't successfull.");
			last;
		}
		sleep $sleep;
	}
	
	# wait until disk_save is done
	
	$wait_time = 30 * 60; # in min * 60 = seconds
	while (1) {
		notify($ERRORS{'OK'}, 0, "check status for new image id $one_new_image_id, $wait_time sec left...");
		my $one_image_state = $self->_one_get_image_state($one_new_image_id);
		if ($one_image_state == 4) {
			notify($ERRORS{'OK'}, 0, "disk save in pregress, image id $one_new_image_id is LOCKED");
		}
		if ($one_image_state == 5) {
			notify($ERRORS{'CRITICAL'}, 0, "disk save failed, image id $one_new_image_id is ERROR");
			return 0;
		}
		if ($one_image_state == 1) {
			notify($ERRORS{'OK'}, 0, "disk save OK, image id $one_new_image_id is READY");
			# check if template exists for the old image and create template for the new image.
			my $one_template_id = $self->_one_get_template_id($old_image_name); 
			if ($one_template_id) {
				notify($ERRORS{'OK'}, 0, "Found existing template id $one_template_id for $old_image_name");
				my @template_info = $one{'server'}->call('one.template.info',$one{'auth'},$one_template_id);
				if ($template_info[0][0]->value()) {
					my $data = XMLin($template_info[0][1]);
					my $template = $data->{TEMPLATE};
					$template->{NAME} = $image_name;
					
					if ((ref($template->{DISK})) eq "ARRAY" ) { # template has multiple disks, update [0]
						$template->{DISK}[0]{IMAGE_ID} = $one_new_image_id;
					} else { #template has one disk
						$template->{DISK}{IMAGE_ID} = $one_new_image_id;
					}	
					
					if (!$self->_one_create_template(XMLout($template,NoAttr => 1,RootName=>'TEMPLATE',))) {
						notify($ERRORS{'CRITICAL'}, 0, "Could't create $image_name template. Abort.");
					}
				} else {
					notify($ERRORS{'CRITICAL'}, 0, "Error while making one.template.info call: $template_info[0][1]");
				}
			} else {
				notify($ERRORS{'OK'}, 0, "No template exists for $old_image_name");
			}
			return 1;
		}
		if ($wait_time <= 0) {
			notify($ERRORS{'CRITICAL'}, 0, "disk save failed, image id $one_new_image_id is NOT READY. Fail.");
			return 0;
		}	
		sleep $sleep;
		$wait_time = $wait_time - $sleep;
	}
	
	return 0;
	
}



=head2 power_off

 Parameters  : 'hard' (optional), execute shutdown-hard
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
	
	my $action = shift;
	my $computer_name = $self->data->get_computer_hostname();
	my $vmid = $self->_one_get_object_id("computer",$computer_name);
	my @poweroff;
	
	if (defined($action) and $action eq 'hard') {
		@poweroff = $one{'server'}->call('one.vm.action', $one{'auth'},'shutdown-hard',$vmid);
	} else {
		@poweroff = $one{'server'}->call('one.vm.action', $one{'auth'},'shutdown',$vmid);
	}
	
	if ($poweroff[0][0]->value()) {
		notify($ERRORS{'OK'}, 0, "Sent shutdown signal to VM $vmid");
		return 1;
	} else {
		notify($ERRORS{'DEBUG'}, 0, $poweroff[0][1]);
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
	my $vmid = $self->_one_get_object_id("computer",$computer_name);
	my @poweroff = $one{'server'}->call('one.vm.action', $one{'auth'},'reboot',$vmid);
	
	if ($poweroff[0][0]->value()) {
		notify($ERRORS{'OK'}, 0, "Sent reboot signal to VM $vmid");
		return 1;
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $poweroff[0][1]);
		return 0;
	}
}



#//////////////////////////////////////////////////////////////////////////////

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
	my $vmid = $self->_one_get_object_id("computer",$computer_name);
	
	my @result = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ($result[0][0]->value()) {
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
	my $vmid = $self->_one_get_object_id("computer",$computer_name);
	#later
	return 1;
	
} ## end sub power_on
#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->_one_get_image_tag_value($self->data->get_image_name(),"SIZE");

}

sub _one_get_image_tag_value {
	my $self = shift;
	my $image_name = shift;
	my $tag = shift;
	
	my $imid = $self->_one_get_object_id("image",$image_name);
	my @result = $one{server}->call('one.image.info',$one{'auth'},$imid);
	if ($result[0][0]->value()) {
		my $data = $xml->XMLin($result[0][1]);
		
		if ($tag eq 'SIZE') {
			if (defined($data->{$tag})) {
				return $data->{$tag};
			} else {
				return 0;
			}
		}
		
		if ($tag eq 'SWAP') {
			if (defined($data->{TEMPLATE}{$tag})) {
				return $data->{TEMPLATE}{$tag};
			} else {
				return 0;
			}
		}
		
		if ($tag eq 'DEV_PREFIX') {
			if (defined($data->{TEMPLATE}{$tag})) {
				return $data->{TEMPLATE}{$tag};
			} else {
				return 0;
			}
		}
		
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Error while making one.image.info call: $result[0][1]");
		return 0;
	}
	notify($ERRORS{'CRITICAL'},0,"requested tag = $tag, don't know how to get it...");
	return 0;
}

sub _one_get_template_id {
	# in: $template_name
	# out: $template_id or 0
	my $self = shift;
	my $template_name = shift;
	
	my @templatepool_info = $one{'server'}->call('one.templatepool.info',$one{'auth'},-1,-1,-1);
	if ($templatepool_info[0][0]->value()) {
		my $data = XMLin($templatepool_info[0][1]);
		
		#print Dumper($data);
		
		if (ref($data->{VMTEMPLATE}) eq "ARRAY") {
			foreach (@{$data->{VMTEMPLATE}}) {
				notify($ERRORS{'OK'}, 0, "Looking for template $template_name in template ID ".$_->{ID}.", name ".$_->{NAME}."...");
				if ($_->{NAME} eq $template_name) {
					notify($ERRORS{'OK'}, 0, "Found template ".$template_name." with ID ".$_->{ID});
					return $_->{ID};
				}
			}
		} else { #HASH, single entry
			
			unless (defined($data->{VMTEMPLATE}{NAME})) {
				notify($ERRORS{'WARNING'}, 0, "Template not found: $template_name");
				return 0;
			}
			
			if ($data->{VMTEMPLATE}{NAME} eq $template_name) {
				notify($ERRORS{'OK'}, 0, "Found template ".$template_name." with ID ".$data->{VMTEMPLATE}{ID});
				return $data->{VMTEMPLATE}{ID};
			}
		}
	} else {
		notify($ERRORS{'WARNING'}, 0, "Error while making one.templatepool.info call: $templatepool_info[0][1]");
	}
	notify($ERRORS{'WARNING'}, 0, "No value found after one.templatepool.info call for template $template_name");
	return 0;
}



#//////////////////////////////////////////////////////////////////////////////
=head2 _one_get_virtio

 Parameters  : imagename
 Returns     : '' or MODEL="virtio"
 Description : 

=cut

sub _one_get_virtio {
	my $self = shift;
	my $one_image_id = shift;
	
	my @reply = $one{'server'}->call('one.image.info',$one{'auth'},$one_image_id);
	
	if ($reply[0][0]->value()) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 one_wait_for_vm_status

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub _one_wait_for_vm_state {
	my $self = shift;
	my $vmid = shift;
	my $state = shift;
	my $wait = shift;
	my $sleep = 15;
	my $num_state = 0;
	
	# 6 - POWEROFF
	
	$num_state = 6 if ($state eq "SHUTDOWN");
	
	
	if (!$num_state) {
		notify($ERRORS{'CRITICAL'}, 0, "Unknown vm_state $state requested");
		return 0;
	}
	
	while (1) {
		notify($ERRORS{'OK'}, 0, "Check state of VM $vmid ...");
		my $ttime;
		my $one_vm_state = $self->_one_get_vm_state($vmid);
		if ($self->_one_get_vm_state($vmid) == $num_state) {
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

# 
sub _one_get_vm_state {
	my $self = shift;
	my $vmid = shift;
	
	my @result = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ($result[0][0]->value()) {
		my $data = $xml->XMLin($result[0][1]);
		return $data->{STATE}; 
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
		return 0;
	}
}

# gets LCM_STATE values, this sub-state is relevant only when STATE is ACTIVE (3)
sub _one_get_vm_lcm_state {
	my $self = shift;
	my $vmid = shift;
	
	my @result = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ($result[0][0]->value()) {
		my $data = $xml->XMLin($result[0][1]);
		if ($data->{STATE} == 3) {
			return $data->{LCM_STATE}; 
		} else {
			notify($ERRORS{'DEBUG'}, 0, "Cannot return LCM_STATE of VM $vmid, VM's STATE is not ACTIVE");
			return;
		}
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $result[0][1]);
		return 0;
	}
}

sub _one_get_image_state {
	my $self = shift;
	my $image_id = shift;
	
	my @status = $one{'server'}->call('one.image.info',$one{'auth'},$image_id);
	if ($status[0][0]->value()) {
		my $data = $xml->XMLin($status[0][1]);
		return $data->{STATE};
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $status[0][1]);
	}
	
}

=head2 _one_get_object_id

 Parameters  : $o_type, $o_name
 Returns     : ONE Object ID (INT)
 Description : 

=cut

sub _one_get_object_id {
	my $self = shift;	
	my $o_type = shift;
	my $o_name = shift;
	
	if ($o_type eq "computer") {
		notify($ERRORS{'OK'}, 0, "Searching for running VM $o_name ...");
		my @reply = $one{'server'}->call('one.vmpool.info',$one{'auth'},-3,-1,-1,-1);
		if ($reply[0][0]->value()) {
			
			my $data = $xml->XMLin($reply[0][1]);
			
			if ((ref($data->{VM})) eq "ARRAY") {
				foreach (@{$data->{VM}}) {
					if ($_->{NAME} =~ /^$o_name\s/) {
						notify($ERRORS{'OK'}, 0, "Found ".$_->{NAME}." matching $o_name in ARRAY");
						return $_->{ID};
					}
			  	}
			} else { #HASH, found only one entry
				unless (defined($data->{VM}{NAME})) {return 0;}
				
				if ($data->{VM}{NAME} =~ /^$o_name\s/) {
					notify($ERRORS{'OK'}, 0, "Found ".$data->{VM}{NAME}." matching $o_name in HASH");
					return $data->{VM}{ID};
			    }
			}
		} else {
			notify($ERRORS{'CRITICAL'}, 0, $reply[0][1]);
			return 0;
		}	
	} elsif ($o_type eq "image") {
		my @reply = $one{'server'}->call('one.imagepool.info', $one{'auth'},-3,-1,-1);
		if ($reply[0][0]->value()) {
			
			my $rs_data = $xml->XMLin($reply[0][1]);
				if ((ref($rs_data->{IMAGE})) eq "ARRAY" ) {
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

#//////////////////////////////////////////////////////////////////////////////

=head2 _one_delete_vm

 Parameters  : $vmid
 Returns     : 
 Description : one.vm.action

=cut

sub _one_delete_vm {
	my $self = shift;
	my $vmid = shift;
	my @reply;
	
	@reply = $one{'server'}->call('one.vm.action', $one{'auth'},'delete',$vmid);
	if ($reply[0][0]->value()) {
		notify($ERRORS{'OK'}, 0, "ONE VM $vmid deleted");
	} else {
		notify($ERRORS{'CRITICAL'}, 0, $reply[0][1]);
	}
	
} 

sub _one_create_vm {
	# in: $VM_TEMPLATE in XML
	# out: new VM ID | 0
	my $self = shift;
	my $VM_TEMPLATE = shift;
	my @vm_allocate = $one{'server'}->call('one.vm.allocate',$one{'auth'},$VM_TEMPLATE,$one{'false'});
	if ($vm_allocate[0][0]->value()) {	
		return $vm_allocate[0][1];
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Error while making one.vm.allocate call : $vm_allocate[0][1]");
		return 0;
	}

}

sub _one_create_template {
	# in: VM_TEMPLATE
	# OUT: template_id | 0
	# http://opennebula.org/documentation:rel4.2:api#onetemplateallocate
	my $self = shift;
	my $VM_TEMPLATE = shift;
	
	my @template_allocate = $one{'server'}->call('one.template.allocate',$one{'auth'},$VM_TEMPLATE);
	if ($template_allocate[0][0]->value()) {
		notify($ERRORS{'OK'}, 0, "New template created with id $template_allocate[0][1]");
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Error while making one.template.allocate call : $template_allocate[0][1]");
	}	
}

sub _one_get_vm_disk {
	my $self = shift;
	my $vmid = shift;
	
	my @vm_info = $one{'server'}->call('one.vm.info', $one{'auth'},$vmid);
	if ($vm_info[0][0]->value()) {
		my $data = $xml->XMLin($vm_info[0][1]);
		
		if ((ref($data->{TEMPLATE}{DISK})) eq "ARRAY" ) { # template has multiple disks, return [0]
			return $data->{TEMPLATE}{DISK}[0]{IMAGE};
		} else { #template has one disk
			return $data->{TEMPLATE}{DISK}{IMAGE};
		}
		
		
		
	} else {
		notify($ERRORS{'CRITICAL'}, 0, "Error while making one.vm.info call : $vm_info[0][1]");
	}
}
1;
__END__

