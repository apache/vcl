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

VCL::Provisioning::libvirt - VCL provisioning module to support the libvirt toolkit

=head1 SYNOPSIS

 use VCL::Module::Provisioning::libvirt;
 my $provisioner = (VCL::Module::Provisioning::libvirt)->new({data_structure => $self->data});

=head1 DESCRIPTION

 Provides support allowing VCL to provisioning resources supported by the
 libvirt toolkit.
 http://libvirt.org

=cut

###############################################################################
package VCL::Module::Provisioning::libvirt;

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
use File::Basename;

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Enumerates the libvirt driver modules directory:
               lib/VCL/Module/Provisioning/libvirt/
               
               Attempts to create and initialize an object for each hypervisor
               driver module found in this directory. The first driver module
               object successfully initialized is used. This object is made
               accessible within this module via $self->driver. This allows
               libvirt support driver modules to be added without having to
               alter the code in libvirt.pm.

=cut

sub initialize {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_state_name = $self->data->get_request_state_name();
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Get the absolute path of the libvirt drivers directory
	my $driver_directory_path = "$FindBin::Bin/../lib/VCL/Module/Provisioning/libvirt";
	notify($ERRORS{'DEBUG'}, 0, "libvirt driver module directory path: $driver_directory_path");
	
	# Get a list of all *.pm files in the libvirt drivers directory
	my @driver_module_paths = $self->mn_os->find_files($driver_directory_path, '*.pm');

	# Attempt to create an initialize an object for each driver module
	# Use the first driver module successfully initialized
	DRIVER: for my $driver_module_path (sort { lc($a) cmp lc($b) } @driver_module_paths) {
		my $driver_name = fileparse($driver_module_path, qr/\.pm$/i);
		my $driver_perl_package = ref($self) . "::$driver_name";
		
		# Create and initialize the driver object
		eval "use $driver_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "failed to load libvirt $driver_name driver module: $driver_perl_package, error: $EVAL_ERROR");
			next DRIVER;
		}
		my $driver;
		eval { $driver = ($driver_perl_package)->new({data_structure => $self->data, os => $self->os, vmhost_os => $self->vmhost_os}) };
		if ($driver) {
			notify($ERRORS{'OK'}, 0, "libvirt $driver_name driver object created and initialized to control $node_name");
			$self->{driver} = $driver;
			$self->{driver}{driver} = $driver;
			$self->{driver_name} = $driver_name;
			last DRIVER;
		}
		elsif ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "libvirt $driver_name driver object could not be created: type: $driver_perl_package, error:\n$EVAL_ERROR");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "libvirt $driver_name driver object could not be initialized to control $node_name");
		}
	}

	# Make sure the driver module object was successfully initialized
	if (!$self->driver()) {
		notify($ERRORS{'WARNING'}, 0, "failed to initialize libvirt provisioning module, driver object could not be created and initialized");
		return;
	}
	
	# Check if the VM profile virtualswitch0 and virtualswitch1 settings match either a defined network or physical interface on the node
	if ($request_state_name =~ /(new|reload|reinstall|test)/) {
		my $virtualswitch0 = $self->data->get_vmhost_profile_virtualswitch0();
		my $virtualswitch1 = $self->data->get_vmhost_profile_virtualswitch1();
		
		my $network_info = $self->get_node_network_info();
		if (!defined($network_info)) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize libvirt provisioning module, network info could not be retrieved from $node_name");
			return;
		}
		
		my $interface_info = $self->get_node_interface_info();
		if (!defined($interface_info)) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize libvirt provisioning module, interface info could not be retrieved from $node_name");
			return;
		}
		
		my $vm_network_0_found = (defined($network_info->{$virtualswitch0}) || defined($interface_info->{$virtualswitch0}));
		my $vm_network_1_found = (defined($network_info->{$virtualswitch1}) || defined($interface_info->{$virtualswitch1}));
		if (!$vm_network_0_found || !$vm_network_1_found) {
			notify($ERRORS{'WARNING'}, 0, "failed to initialize libvirt provisioning module, VM network settings in VM host profile do not correspond to a network or physical interface on $node_name\n" .
				"VM network 0 setting: $virtualswitch0" . ($vm_network_0_found ? '' : ' <-- MISSING!!!') . "\n" .
				"VM network 1 setting: $virtualswitch1" . ($vm_network_1_found ? '' : ' <-- MISSING!!!') . "\n" .
				"networks: " . join(', ', sort keys %$network_info) . "\n" .
				"physical interfaces: " . join(', ', sort keys %$interface_info)
			);
			return;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " provisioning module initialized");
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : none
 Returns     : boolean
 Description : Unloads the image on the domain:

=over 3

=cut

sub unload {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	if (!$self->delete_existing_domains()) {
		return;
	}

	return 1;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  : none
 Returns     : boolean
 Description : Loads the requested image on the domain:

=over 3

=cut

sub load {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = $self->data->get_reservation_id();
	my $image_name = $self->data->get_image_name();
	my $computer_id = $self->data->get_computer_id();
	my $computer_name = $self->data->get_computer_short_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $domain_name = $self->get_domain_name();
	my $driver_name = $self->get_driver_name();
	my $domain_xml_file_path = $self->get_domain_xml_file_path();
	
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_name $image_name");

=item *

Destroy and delete any domains have already been defined for the computer
assigned to this reservation.

=cut

	$self->delete_existing_domains() || return;

=item *

Construct the default libvirt XML definition for the domain.

=cut

	my $domain_xml_definition = $self->generate_domain_xml();
	if (!$domain_xml_definition) {
		notify($ERRORS{'WARNING'}, 0, "failed to load '$image_name' image on '$computer_name', unable to generate XML definition for '$domain_name' domain");
		return;
	}

=item *

Call the libvirt driver module's 'extend_domain_xml' subroutine if it is
implemented. Pass the default domain XML definition hash reference as an
argument. The 'extend_domain_xml' subroutine may add or modify XML values. This
allows the driver module to customize the XML specific to that driver.

=cut

	if ($self->driver->can('extend_domain_xml')) {
		$domain_xml_definition = $self->driver->extend_domain_xml($domain_xml_definition);
		if (!$domain_xml_definition) {
			notify($ERRORS{'WARNING'}, 0, "failed to load '$image_name' image on '$computer_name', $driver_name libvirt driver module failed to extend XML definition for '$domain_name' domain");
			return;
		}
	}

=item *

Call the driver module's 'pre_define' subroutine if it is implemented. This
subroutine completes any necessary tasks which are specific to the driver being
used prior to defining the domain.

=cut

	if ($self->driver->can('pre_define') && !$self->driver->pre_define()) {
		notify($ERRORS{'WARNING'}, 0, "failed to load '$image_name' image on '$computer_name', $driver_name libvirt driver module failed to complete its steps prior to defining the domain");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "transfervm", "performed libvirt driver tasks before defining domain");

=item *

Create a text file on the node containing the domain XML definition.

=cut
 
	if (!$self->vmhost_os->create_text_file($domain_xml_file_path, $domain_xml_definition)) {
		notify($ERRORS{'WARNING'}, 0, "failed to load '$image_name' image on '$computer_name', unable to create XML file on $node_name: $domain_xml_file_path");
		return;
	}

=item *

Define the domain on the node by calling 'virsh define <XML file>'.

=cut

	if (!$self->define_domain($domain_xml_file_path, 1)) {
		notify($ERRORS{'WARNING'}, 0, "failed to load '$image_name' image on '$computer_name', unable to define domain");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "vmsetupconfig", "defined $computer_name domain node $node_name");

=item *

Power on the domain.

=cut

	if (!$self->power_on($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$domain_name' domain on $node_name");
		return;
	}
	insertloadlog($reservation_id, $computer_id, "startvm", "powered on $computer_name domain node $node_name");

=item *

Call the domain guest OS module's 'post_load' subroutine if implemented.

=cut

	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			notify($ERRORS{'OK'}, 0, "performed OS post-load tasks '$domain_name' domain on $node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on '$domain_name' domain on node $node_name");
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "OS post-load tasks not necessary '$domain_name' domain on $node_name");
	}

=back

=cut

	return 1;
} ## end sub load

#//////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : none
 Returns     : boolean
 Description : Captures the image currently loaded on the computer.

=cut

sub capture {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $old_image_name = $self->data->get_image_name();
	
	# Construct the new image name
	my $new_image_name = $self->get_new_image_name();
	$self->data->set_image_name($new_image_name);
	
	my $request_state_name = $self->data->get_request_state_name();
	my $image_id = $self->data->get_image_id();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $image_type = $self->data->get_imagetype_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $computer_name = $self->data->get_computer_short_name();
	my $master_image_directory_path = $self->get_master_image_directory_path();
	my $master_image_file_path = $self->get_master_image_file_path();
	my $datastore_image_type = $self->data->get_vmhost_datastore_imagetype_name();
	my $repository_image_directory_path = $self->get_repository_image_directory_path();
	my $repository_image_file_path = $self->get_repository_image_file_path();
	my $repository_image_type = $self->data->get_vmhost_repository_imagetype_name();
	
	# Set the imagemeta Sysprep value to 0 to prevent Sysprep from being used
	$self->data->set_imagemeta_sysprep(0);
	
	# Get the domain name
	my $domain_name = $self->get_domain_name();
	if (!$domain_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to capture image on $node_name, domain name could not be determined");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning image capture:\n" . <<EOF
image id: $image_id
imagerevision id: $imagerevision_id
old image name: $old_image_name
new image name: $new_image_name
---
host node: $node_name
computer: $computer_name
---
master image directory path: $master_image_directory_path
master image file path: $master_image_file_path
---
old image type: $image_type
datastore image type: $datastore_image_type
---
repository image type: $repository_image_type
repository image directory path: $repository_image_directory_path
repository image file path: $repository_image_file_path
EOF
);
	
	# Call the OS module's pre_capture() subroutine
	if ($self->os->can("pre_capture") && !$self->os->pre_capture({end_state => 'on'})) {
		notify($ERRORS{'WARNING'}, 0, "failed to complete OS module's pre_capture tasks");
		return;
	}

	# Check the power status before proceeding
	my $power_status = $self->power_status();
	if (!$power_status) {
		notify($ERRORS{'WARNING'}, 0, "unable to capture image on $node_name, power status of '$domain_name' domain could not be determined");
		return;
	}
	elsif ($power_status !~ /on/i) {
		notify($ERRORS{'WARNING'}, 0, "unable to capture image on $node_name, power status of '$domain_name' domain is $power_status");
		return;
	}
	
	# Make sure the master image file doesn't already exist
	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "master image file already exists on $node_name: $master_image_file_path");
		return;
	}
	
	# Make sure the repository image file doesn't already exist if the repository path is configured
	if ($repository_image_file_path && $self->vmhost_os->file_exists($repository_image_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "repository image file already exists on $node_name: $repository_image_file_path");
		return;
	}
	
	# Get the domain XML definition
	my $domain_xml_string = $self->get_domain_xml_string($domain_name);
	if (!$domain_xml_string) {
		notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to retrieve domain XML definition: $domain_name");
		return;
	}
	
	# Delete existing XML definition files
	$self->os->delete_file("~/*-v*.xml");
	
	# Save the domain XML definition to a file in the image
	my $image_xml_file_path = "~/$new_image_name.xml";
	if ($self->os->create_text_file($image_xml_file_path, $domain_xml_string)) {
		notify($ERRORS{'OK'}, 0, "saved domain XML definition text file in image: $image_xml_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to save domain XML definition text file in image: $image_xml_file_path, contents:\n$domain_xml_string");
		return;
	}
	
	# Save the domain XML definition to a file in the master image directory
	my $master_xml_file_path = $self->get_master_xml_file_path();
	if ($self->vmhost_os->create_text_file($master_xml_file_path, $domain_xml_string)) {
		notify($ERRORS{'OK'}, 0, "saved domain XML definition text file to master image directory: $master_xml_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to save domain XML definition text file: $master_xml_file_path");
		return;
	}

	# Update the image name in the database
	if ($old_image_name ne $new_image_name && !update_image_name($image_id, $imagerevision_id, $new_image_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update image name in the database: $old_image_name --> $new_image_name");
		return;
	}
	
	# Update the image type in the database to the datastore image type
	if ($image_type ne $datastore_image_type && !update_image_type($image_id, $datastore_image_type)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update image type in the database: $image_type --> $datastore_image_type");
		return;
	}
	
	# Shutdown domain 
	if (!$self->os->shutdown()) {
		notify($ERRORS{'WARNING'}, 0, "$domain_name has not powered off after the OS module's pre_capture tasks were completed, powering off forcefully");
		if (!$self->power_off($domain_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to power off $domain_name after the OS module's pre_capture tasks were completed");
			return;
		}
	}
	
	# Get the disk file paths from the domain definition
	my @disk_file_paths = $self->get_domain_disk_file_paths($domain_name);
	if (scalar @disk_file_paths == 0) {
		notify($ERRORS{'WARNING'}, 0, "did not find any disks defined in the XML definition for $domain_name:\n" . format_data($domain_name));
		return;
	}
	elsif (scalar @disk_file_paths > 1) {
		notify($ERRORS{'WARNING'}, 0, "found multiple disks defined in the XML definition for $domain_name, only the first disk will be captured:\n" . format_data(\@disk_file_paths));
	}

	# Copy the linked clone to create a new master image file
	my $linked_clone_file_path = $disk_file_paths[0];
	notify($ERRORS{'DEBUG'}, 0, "retrieved linked clone file path from domain $domain_name: $linked_clone_file_path");
	if ($self->driver->can('copy_virtual_disk')) {
		# Get a semaphore so that multiple processes don't try to copy/access the image at the same time
		# Since this is a new image, should get semaphore on 1st try
		if (my $semaphore = $self->get_master_image_semaphore()) {
			if ($self->driver->copy_virtual_disk($linked_clone_file_path, $master_image_file_path, $datastore_image_type)) {
				notify($ERRORS{'DEBUG'}, 0, "created master image from linked clone: $linked_clone_file_path --> $master_image_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to create master image from linked clone: $linked_clone_file_path --> $master_image_file_path");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to obtain semaphore before creating master image from linked clone: $linked_clone_file_path --> $master_image_file_path");
			return;
		}
		
		# Copy the master image to the repository if the repository path is configured in the VM host profile
		if ($repository_image_file_path) {
			if (my $semaphore = $self->get_repository_image_semaphore()) {
				if ($self->driver->copy_virtual_disk($master_image_file_path, $repository_image_file_path, $repository_image_type)) {
					notify($ERRORS{'DEBUG'}, 0, "created repository image from master image: $master_image_file_path --> $repository_image_file_path");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to create repository image from master image: $master_image_file_path --> $repository_image_file_path");
					return;
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to obtain semaphore before copying master image to repository mounted on $node_name: $master_image_file_path --> $repository_image_file_path");
				return;
			}
			
			# Save the domain XML definition to a file in the repository image directory
			my $repository_xml_file_path = $self->get_repository_xml_file_path();
			if ($self->vmhost_os->create_text_file($repository_xml_file_path, $domain_xml_string)) {
				notify($ERRORS{'OK'}, 0, "saved domain XML definition text file to repository image directory: $master_xml_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to capture image on $node_name, unable to save domain XML definition text file to repository image directory: $master_xml_file_path");
				return;
			}
		}
	}
	
	if ($request_state_name !~ /^(image)$/) {
		notify($ERRORS{'OK'}, 0, "domain will NOT be deleted because the request state is '$request_state_name'");
	}
	else {
		# Image has been captured, delete the domain
		$self->delete_domain($domain_name);
	}
	
	return 1;
} ## end sub capture

#//////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : $image_name (optional)
 Returns     : array (boolean)
 Description : Checks if the requested image exists on the node or in the
               repository. If the image exists, an array containing the image
               file paths is returned. A boolean evaluation can be done on the
               return value to simply determine if an image exists.

=cut

sub does_image_exist {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $master_image_file_path = $self->get_master_image_file_path($image_name);
	
	# Get a semaphore in case another process is currently copying to create the master image
	if (my $semaphore = $self->get_master_image_semaphore()) {
		# Check if the master image file exists on the VM host
		if ($self->vmhost_os->file_exists($master_image_file_path)) {
			notify($ERRORS{'DEBUG'}, 0, "$image_name image exists on $node_name: $master_image_file_path");
			return 1;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if $image_name exists on $node_name: $master_image_file_path, unable to obtain semaphore");
		return;
	}
	
	# Attempt to find the image files in the repository
	if ($self->find_repository_image_file_paths($image_name)) {
		notify($ERRORS{'DEBUG'}, 0, "$image_name image exists in the repository mounted on $node_name");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$image_name image does not exist $node_name");
	return 0;
} ## end sub does_image_exist

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_size

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the image in megabytes.

=cut

sub get_image_size {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	
	my $image_size_bytes = $self->get_image_size_bytes($image_name) || return;
	
	# Convert bytes to MB
	return int($image_size_bytes / 1024 ** 2);
} ## end sub get_image_size

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
	
	my $domain_name = shift || $self->get_domain_name();
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Get the domain info hash, make sure domain is defined
	my $domain_info = $self->get_domain_info();
	if (!defined($domain_info->{$domain_name})) {
		notify($ERRORS{'DEBUG'}, 0, "unable to determine power status of '$domain_name' domain, it is not defined on $node_name");
		return;
	}
	
	# enum virDomainState {
	#  VIR_DOMAIN_NOSTATE   =  0  : no state
	#  VIR_DOMAIN_RUNNING   =  1  : the domain is running
	#  VIR_DOMAIN_BLOCKED   =  2  : the domain is blocked on resource
	#  VIR_DOMAIN_PAUSED    =  3  : the domain is paused by user
	#  VIR_DOMAIN_SHUTDOWN  =  4  : the domain is being shut down
	#  VIR_DOMAIN_SHUTOFF   =  5  : the domain is shut off
	#  VIR_DOMAIN_CRASHED   =  6  : 
	#  VIR_DOMAIN_LAST      =  7  
	# }
	
	my $domain_state = $domain_info->{$domain_name}{state};
	if (!defined($domain_state)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine power status of '$domain_name' domain, the state attribute is not set");
		return;
	}
	elsif ($domain_state =~ /running/i) {
		return 'on';
	}
	elsif ($domain_state =~ /blocked/i) {
		return 'blocked';
	}
	elsif ($domain_state =~ /paused/i) {
		return 'suspended';
	}
	elsif ($domain_state =~ /(shutdown|off)/i) {
		return 'off';
	}
	elsif ($domain_state =~ /crashed/i) {
		return 'crashed';
	}
	else {
		return $domain_state;
	}
	
} ## end sub power_status

#//////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : $domain_name (optional)
 Returns     : boolean
 Description : Powers on the domain. Returns true if the domain was successfully
               powered on or was already powered on.

=cut

sub power_on {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift || $self->get_domain_name();
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Start the domain
	my $command = "virsh start \"$domain_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to start '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status eq '0') {
		notify($ERRORS{'OK'}, 0, "started '$domain_name' domain on $node_name");
		return 1;
	}
	elsif (grep(/domain is already active/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$domain_name' domain is already running on $node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
} ## end sub power_on

#//////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : $domain_name
 Returns     : boolean
 Description : Powers off the domain. Returns true if the domain was
               successfully powered off or was already powered off.

=cut

sub power_off {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift || $self->get_domain_name();
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Start the domain
	my $command = "virsh destroy \"$domain_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to destroy '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status eq '0') {
		notify($ERRORS{'OK'}, 0, "destroyed '$domain_name' domain on $node_name");
		return 1;
	}
	elsif (grep(/domain is not running/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "'$domain_name' domain is not running on $node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to destroy '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
} ## end sub power_off

#//////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : $domain_name (optional)
 Returns     : boolean
 Description : Resets the power of the domain by powering it off and then back
               on.

=cut

sub power_reset {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift || $self->get_domain_name();
	my $node_name = $self->data->get_vmhost_short_name();
	
	if (!$self->power_off()) {
		notify($ERRORS{'WARNING'}, 0, "failed to reset power of '$domain_name' domain on $node_name, domain could not be powered off");
		return;
	}
	
	if (!$self->power_on()) {
		notify($ERRORS{'WARNING'}, 0, "failed to reset power of '$domain_name' domain on $node_name, domain could not be powered on");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "reset power of '$domain_name' domain on $node_name");
	return 1;
} ## end sub power_reset

#//////////////////////////////////////////////////////////////////////////////

=head2  post_maintenance_action

 Parameters  : none
 Returns     : boolean
 Description : Performs tasks when a VM is unassigned from a host:
               -Deletes domain from node
               -Unassigns VM from VM host (sets computer.vmhostid to NULL)

=cut

sub post_maintenance_action {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift || $self->get_domain_name();
	my $computer_id = $self->data->get_computer_id();
	my $computer_short_name = $self->data->get_computer_short_name();
	my $vmhost_name = $self->data->get_vmhost_short_name();
	
	# Delete the domains on the node which were created for the computer being put into maintenance
	if (!$self->delete_existing_domains()) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete existing $domain_name domains on $vmhost_name");
		return;
	}

	# Set the computer current image in the database to 'noimage'
	if (!update_computer_imagename($computer_id, 'noimage')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set computer $computer_short_name current image to 'noimage'");
	}
	
	# Unassign the VM from the VM host, change computer.vmhostid to NULL
	if (!switch_vmhost_id($computer_id, 'NULL')) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the vmhostid to NULL for $domain_name");
		return;
	}
	
	return 1;
} ## end sub post_maintenance_action

###############################################################################

=head1 PRIVATE METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 driver

 Parameters  : none
 Returns     : Libvirt driver object
 Description : Returns a reference to the libvirt driver object which is created
               when this libvirt.pm module is initialized.

=cut

sub driver {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (!$self->{driver}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return libvirt driver object, \$self->{driver} is not set");
		return;
	}
	else {
		return $self->{driver};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_driver_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the libvirt driver being used to control the
               node. Example: 'KVM'

=cut

sub get_driver_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (!$self->{driver_name}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return libvirt driver name, \$self->{driver_name} is not set");
		return;
	}
	else {
		return $self->{driver_name};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the domain. This name is passed to various
               virsh commands. It is also the name displayed in virt-manager.
               
               If the request state is 'image', the domain name is retrieved
               from the list of defined domains on the node because the name
               will vary based on the base image used.
               
               If the request state is anything other than 'image', the domain
               name is constructed from the computer name, image display name
               pruned of non-alphanumeric characters, image ID, and revision
               number:
               <computer name>_<image display name>_<image ID>-v<revision number>'
               
               Example:
               'vm4-22_CentOS7Base64bitVM_3081-v5'
               
               Parts of the name may be omitted if the overall length exceeds
               the maximum domain name length on some early versions of
               libvirt/KVM - 48 characters.

=cut

sub get_domain_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Only use argument for testing different lengths
	my $max_length = shift;
	if (!$max_length) {
		return $self->{domain_name} if defined $self->{domain_name};
		$max_length = 48;
	}
	
	my $request_state_name = $self->data->get_request_state_name();
	my $computer_id = $self->data->get_computer_id();
	my $computer_name = $self->data->get_computer_short_name();
	my $image_id = $self->data->get_image_id();
	my $image_pretty_name = $self->data->get_image_prettyname();
	my $revision_number = $self->data->get_imagerevision_revision();
	
	# If request state is image the domain name will be that of the image used as the base image, not the image being created
	# Must find existing loaded domain on node in order to determine name
	if ($request_state_name =~ /(image|checkpoint)/) {
		if (my $active_domain_name = $self->get_active_domain_name()) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved name of domain being captured: '$active_domain_name'");
			$self->{domain_name} = $active_domain_name;
			return $active_domain_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine name of domain to be captured");
			return;
		}
	}
	
	# Request state is not image, construct the domain name
	# Make sure the computer name by itself isn't too long
	# This shouldn't ever happen unless very long computer names are used
	my $computer_name_length = length($computer_name);
	if ($computer_name_length > $max_length) {
		$self->{domain_name} = $computer_id;
		notify($ERRORS{'WARNING'}, 0, "computer name '$computer_name' is longer ($computer_name_length characters) than the maximum domain name length ($max_length characters), domain name will be the computer ID: '$self->{domain_name}'");
		return $self->{domain_name};
	}
	
	my $prefix = "$computer_name\_";
	my $prefix_length = length($prefix);
	
	my $suffix = "$image_id-v$revision_number";
	my $suffix_length = length($suffix);
	
	my $prefix_suffix_length = ($prefix_length + $suffix_length);
	
	# Make sure computer name prefix + revision suffix don't exceed the maximum length
	# If so, just use the computer name
	if ($prefix_suffix_length > $max_length) {
		$self->{domain_name} = $computer_name;
		notify($ERRORS{'DEBUG'}, 0, "length of domain name prefix '$prefix' and suffix '$suffix' ($prefix_suffix_length characters) exceeds the maximum domain name length ($max_length characters), domain name will only contain the computer name: '$self->{domain_name}'");
		return $self->{domain_name};
	}
	elsif ($prefix_suffix_length == $max_length) {
		$self->{domain_name} = $prefix . $suffix;
		notify($ERRORS{'DEBUG'}, 0, "length of domain name prefix '$prefix' and suffix '$suffix' ($prefix_suffix_length characters) equals the maximum domain name length ($max_length characters), domain name will only contain these components: '$self->{domain_name}'");
		return $self->{domain_name};
	}
	
	# Figure out the maximum number of characters to include in the middle section
	# Subtract 1 for the separator character
	my $max_middle_length = ($max_length - $prefix_suffix_length - 1);
	if ($max_middle_length < 5) {
		# Don't bother adding if middle section would be less than 5 characters
		$self->{domain_name} = $prefix . $suffix;
		notify($ERRORS{'DEBUG'}, 0, "length of domain name prefix '$prefix' and suffix '$suffix' ($prefix_suffix_length characters) is close to the maximum domain name length ($max_length characters), domain name will only contain these components: '$self->{domain_name}'");
		return$self->{domain_name};
	}
	
	my $middle_section = '';
	
	# Remove all characters except letters and numbers
	(my $image_pretty_name_reduced = $image_pretty_name) =~ s/[^a-z0-9]+//ig;
	my $image_pretty_name_reduced_length = length($image_pretty_name_reduced);
	if (length($image_pretty_name_reduced) <= $max_middle_length) {
		$middle_section = $image_pretty_name_reduced;
	}
	else {
		$middle_section = substr($image_pretty_name_reduced, 0, $max_middle_length);
		notify($ERRORS{'DEBUG'}, 0, "truncating middle section of domain name so overall length is $max_length characters: '$image_pretty_name_reduced' --> '$middle_section'");
	}
	
	$self->{domain_name} = $prefix . $middle_section . '_' . $suffix;
	my $domain_name_length = length($self->{domain_name});
	notify($ERRORS{'DEBUG'}, 0, "constructed domain name: '$self->{domain_name}', length: $domain_name_length characters");
	return $self->{domain_name};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_active_domain_name

 Parameters  : none
 Returns     : string
 Description : Determines the name of the domain assigned to the reservation.
               This subroutine is mainly used when capturing base images. The
               name of the domain is chosen by the person capturing it and may
               not contain the name of the VCL computer.

=cut

sub get_active_domain_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $os_type = $self->data->get_image_os_type();
	my $computer_name = $self->data->get_computer_short_name();
	my $computer_eth0_mac_address = $self->data->get_computer_eth0_mac_address();
	my $computer_eth1_mac_address = $self->data->get_computer_eth1_mac_address();

	my @domain_mac_addresses;

	if (!$self->os->is_ssh_responding()) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name is not responding, unable to verify MAC addresses reported by OS match MAC addresses in vmx file")     ;
		@domain_mac_addresses = ($computer_eth0_mac_address, $computer_eth1_mac_address);
	}
	else {
		my $active_os;
		my $active_os_type = $self->os->get_os_type();
		if (!$active_os_type) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine active domain, OS type currently installed on $computer_name could not be determined");
		}
		elsif ($active_os_type ne $os_type) {
			notify($ERRORS{'DEBUG'}, 0, "OS type currently installed on $computer_name does not match the OS type of the reservation image:\nOS type installed on $computer_name: $active_os_type\nreservation image OS type: $os_type");
			
			my $active_os_perl_package;
			if ($active_os_type =~ /linux/i) {
				$active_os_perl_package = 'VCL::Module::OS::Linux';
			}
			else {
				$active_os_perl_package = 'VCL::Module::OS::Windows';
			}
			
			if ($active_os = $self->create_os_object($active_os_perl_package)) {
				notify($ERRORS{'DEBUG'}, 0, "created a '$active_os_perl_package' OS object for the '$active_os_type' OS type currently installed on $computer_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to determine active domain name, failed to create a '$active_os_perl_package' OS object for the '$active_os_type' OS type currently installed on $computer_name");
				return;
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "'$active_os_type' OS type currently installed on $computer_name matches the OS type of the image assigned to this reservation");
			$active_os = $self->os;
		}
		
		# Make sure the active OS object implements the required subroutines called below
		if (!$active_os->can('get_private_mac_address') || !$active_os->can('get_public_mac_address')) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine active domain name, " . ref($active_os) . " OS object does not implement 'get_private_mac_address' and 'get_public_mac_address' subroutines");
			@domain_mac_addresses = ($computer_eth0_mac_address, $computer_eth1_mac_address);
		}
		else {	
			# Get the MAC addresses being used by the running VM for this reservation
			my $active_private_mac_address = $active_os->get_private_mac_address();
			my $active_public_mac_address = $active_os->get_public_mac_address();
			push @domain_mac_addresses, $active_private_mac_address if $active_private_mac_address;
			push @domain_mac_addresses, $active_public_mac_address if $active_public_mac_address;
		}
	}	
	# Remove the colons from the MAC addresses and convert to lower case so they can be compared
	map { s/[^\w]//g; $_ = lc($_) } (@domain_mac_addresses);
	
	my @matching_domain_names;
	my $domain_info = $self->get_domain_info();
	for my $domain_name (keys %$domain_info) {
		my @check_mac_addresses = $self->get_domain_mac_addresses($domain_name);
		map { s/[^\w]//g; $_ = lc($_) } (@check_mac_addresses);
		
		my @matching_mac_addresses = map { my $domain_mac_address = $_; grep(/$domain_mac_address/i, @check_mac_addresses) } @domain_mac_addresses;
		if (!@matching_mac_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring domain '$domain_name' because MAC address does not match any being used by $computer_name");
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "found matching MAC address between $computer_name and domain '$domain_name':\n" . join("\n", sort(@matching_mac_addresses)));
		push @matching_domain_names, $domain_name;
	}
	
	if (!@matching_domain_names) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine active domain name, did not find any domains configured to use MAC address currently being used by $computer_name:\n" . join("\n", sort(@domain_mac_addresses)));
		return;
	}
	elsif (scalar(@matching_domain_names) == 1) {
		my $active_domain_name = $matching_domain_names[0];
		notify($ERRORS{'DEBUG'}, 0, "determined active domain name: $active_domain_name");
		return $active_domain_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine active domain name, multiple domains (" . join(', ', @matching_domain_names) . ") are configured to use MAC address currently being used by $computer_name:\n" . join("\n", sort(@domain_mac_addresses)));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_file_base_name

 Parameters  : none
 Returns     : string
 Description : Returns the base name for files created for the current
               reservation. A file extension is not included. This file name is
               used for the domain's XML definition file and it's copy on write
               image file. Example: 'vclv99-37_234-v23'

=cut

sub get_domain_file_base_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	my $image_id = $self->data->get_image_id();
	my $image_revision = $self->data->get_imagerevision_revision();
	
	return "$computer_short_name\_$image_id-v$image_revision";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_xml_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the directory path on the node where domain definition
               XML files reside. The directory used is: '/tmp/vcl'

=cut

sub get_domain_xml_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return "/tmp/vcl";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_xml_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the domain XML definition file path on the node.
               Example: '/tmp/vcl/vclv99-37_234-v23.xml'

=cut

sub get_domain_xml_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_xml_directory_path = $self->get_domain_xml_directory_path();
	my $domain_file_name = $self->get_domain_file_base_name();
	
	return "$domain_xml_directory_path/$domain_file_name.xml";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_image_base_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the directory path on the node where all master images
               reside. Example: '/var/lib/libvirt/images'

=cut

sub get_master_image_base_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $datastore_path = $self->data->get_vmhost_profile_datastore_path();
	return $datastore_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_image_directory_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the directory path on the node where the master image
               files reside. Example:
               '/var/lib/libvirt/images/win7-Windows7Base64bitVM-1846-v3'

=cut

sub get_master_image_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $master_image_base_directory_path = $self->get_master_image_base_directory_path();
	
	#return "$master_image_base_directory_path/$image_name";
	return $master_image_base_directory_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_image_file_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the path on the node where the master image file resides.
               Example:
               '/var/lib/libvirt/images/vmwarelinux-RHEL54Small2251-v1.qcow2'

=cut

sub get_master_image_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{master_image_file_path} if $self->{master_image_file_path};
	
	my $image_name = shift || $self->data->get_image_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $master_image_directory_path = $self->get_master_image_directory_path();
	
	# Check if the master image file exists on the VM host
	my @master_image_files_found = $self->vmhost_os->find_files($master_image_directory_path, "$image_name.*");
	
	# Prune known metadata files - otherwise if only a .xml file exists for the image, the .xml path will be returned
	@master_image_files_found = grep(!/\.(xml|reference)$/i, @master_image_files_found);
	
	if (@master_image_files_found == 1) {
		$self->{master_image_file_path} = $master_image_files_found[0];
		notify($ERRORS{'DEBUG'}, 0, "found master image file on $node_name: $self->{master_image_file_path}");
		return $self->{master_image_file_path};
	}
	
	# File was not found, construct it
	my $datastore_imagetype = $self->data->get_vmhost_datastore_imagetype_name();
	my $master_image_file_path = "$master_image_directory_path/$image_name.$datastore_imagetype";
	notify($ERRORS{'DEBUG'}, 0, "constructed master image file path: $master_image_file_path");
	return $master_image_file_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_xml_file_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the path on the node where the master (reference) XML
 file resides. This file is a dump of the domain XML which was used to capture
               the image.
               Example:
               '/var/lib/libvirt/images/vmwarelinux-RHEL54Small2251-v1.xml'

=cut

sub get_master_xml_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $master_image_directory_path = $self->get_master_image_directory_path();
	
	return "$master_image_directory_path/$image_name.xml";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_copy_on_write_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the path on the node where the copy on write file for the
               domain resides. Example:
               '/var/lib/libvirt/images/vclv99-197_2251-v1.qcow2'

=cut

sub get_copy_on_write_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_vmpath       = $self->data->get_vmhost_profile_vmpath();
	my $domain_file_name    = $self->get_domain_file_base_name();
	my $datastore_imagetype = $self->data->get_vmhost_datastore_imagetype_name();
	
	return "$vmhost_vmpath/$domain_file_name.$datastore_imagetype";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_repository_image_directory_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the path of the directory in the repository mounted on
               the node where the image file resides. Returns 0 if the
               repository path is not configured in the VM host profile.
               Example:
               '/mnt/repository/win7-Windows7Base64bitVM-1846-v3'

=cut

sub get_repository_image_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $vmhost_repository_directory_path = $self->data->get_vmhost_profile_repository_path(0);
	
	if ($vmhost_repository_directory_path) {
		return "$vmhost_repository_directory_path/$image_name";
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_repository_image_file_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the path in the repository mounted on the node where the
               repository image file resides. Returns 0 if the repository path
               is not configured in the VM host profile.
               Example:
               '/mnt/repository/win7-Windows7Base64bitVM-1846-v3/win7-Windows7Base64bitVM-1846-v3.qcow2'

=cut

sub get_repository_image_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $repository_image_directory_path = $self->get_repository_image_directory_path();
	
	if ($repository_image_directory_path) {
		my $repository_imagetype = $self->data->get_vmhost_repository_imagetype_name();
		return "$repository_image_directory_path/$image_name.$repository_imagetype";
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_repository_xml_file_path

 Parameters  : $image_name (optional)
 Returns     : string
 Description : Returns the path on the node where the repository (reference) XML
 file resides. This file is a dump of the domain XML which was used to capture
               the image.
               Example:
               '/mnt/repository/vmwarelinux-RHEL54Small2251-v1.xml'

=cut

sub get_repository_xml_file_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $repository_image_directory_path = $self->get_repository_image_directory_path();
	
	return "$repository_image_directory_path/$image_name.xml";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_new_image_name

 Parameters  : 
 Returns     : string
 Description : Constructs a new image name for images being captured. This is
					used instead of the name in the database in case an image is
					converted. The new image name shouldn't contain vmware.

=cut

sub get_new_image_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_id = $self->data->get_image_id();
	my $image_os_name = $self->data->get_image_os_name();
	my $image_prettyname = $self->data->get_image_prettyname();
	my $imagerevision_revision = $self->data->get_imagerevision_revision();
	
	# Clean up the OS name
	$image_os_name =~ s/(vmware|image)*//g;
	
	# Remove non-word characters and underscores from the image prettyname
	$image_prettyname =~ s/[\W\_]+//ig;
	
	return "$image_os_name\-$image_prettyname\-$image_id\-v$imagerevision_revision"; 
}

#//////////////////////////////////////////////////////////////////////////////

=head2 define_domain

 Parameters  : $domain_xml_file_path, $autostart (optional)
 Returns     : boolean
 Description : Defines a domain on the node.

=cut

sub define_domain {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_xml_file_path = shift;
	if (!defined($domain_xml_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "domain XML file path argument was not specified");
		return;
	}
	
	my $autostart = shift;
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $define_command = "virsh define \"$domain_xml_file_path\"";
	my ($define_exit_status, $define_output) = $self->vmhost_os->execute($define_command);
	if (!defined($define_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to define domain on $node_name: $domain_xml_file_path");
		return;
	}
	elsif ($define_exit_status eq '0') {
		notify($ERRORS{'OK'}, 0, "defined domain on $node_name, output:\n" . join("\n", @$define_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to define domain on $node_name\ncommand: $define_command\nexit status: $define_exit_status\noutput:\n" . join("\n", @$define_output));
		return;
	}
	
	if ($autostart) {
		# Parse the domain name from the 'virsh define' output, should look like this:
		# Domain vclv11:linux-kvmimage-2935-v0 defined from /tmp/vcl/vcl11_2935-v0.xml
		my ($domain_name) = join("\n", @$define_output) =~ /Domain\s+(.+)\s+defined/;
		if ($domain_name) {
			notify($ERRORS{'DEBUG'}, 0, "parsed domain name from 'virsh define' output: '$domain_name'");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to parse domain name from 'virsh define' output:\n" . join("\n", @$define_output));
			return 1;
		}
		
		my $autostart_command = "virsh autostart \"$domain_name\"";
		my ($autostart_exit_status, $autostart_output) = $self->vmhost_os->execute($autostart_command);
		if (!defined($autostart_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to configure '$domain_name' domain to autostart on $node_name");
		}
		elsif ($autostart_exit_status eq '0') {
			notify($ERRORS{'OK'}, 0, "configured '$domain_name' domain to autostart on $node_name, output:\n" . join("\n", @$autostart_output));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to configure '$domain_name' domain to autostart on $node_name\ncommand: $autostart_command\nexit status: $autostart_exit_status\noutput:\n" . join("\n", @$autostart_output));
		}
	}
	
	return 1;
}
	
#//////////////////////////////////////////////////////////////////////////////

=head2 delete_existing_domains

 Parameters  : none
 Returns     : boolean
 Description : Deletes existing domains which were previously created for the
               computer assigned to the current reservation.

=cut

sub delete_existing_domains {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	my $computer_name = $self->data->get_computer_short_name();
	
	my $domain_info = $self->get_domain_info();
	
	for my $domain_name (keys %$domain_info) {
		my $pattern = '^' . $computer_name . '[:_]';
		if ($domain_name !~ /$pattern/) {
			# Display a message only if the existing domain name contains the computer name but does not match the pattern
			if ($domain_name =~ /$computer_name/i) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring domain: '$domain_name', it does not match computer name pattern: '$pattern'");
			}
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "deleting domain: '$domain_name', it matches computer name pattern: '$pattern'");
		if (!$self->delete_domain($domain_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete existing domains created for $computer_name on $node_name, '$domain_name' domain could not be deleted");
			return;
		}
	}
	
	# Delete existing XML files
	my $domain_xml_directory_path = $self->get_domain_xml_directory_path();
	$self->vmhost_os->delete_file("$domain_xml_directory_path/$computer_name\_*.xml");
	
	notify($ERRORS{'OK'}, 0, "deleted existing domains created for $computer_name on $node_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_domain

 Parameters  : $domain_name
 Returns     : boolean
 Description : Deletes a domain from the node.

=cut

sub delete_domain {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	my $request_state_name = $self->data->get_request_state_name();
	
	# Make sure domain is defined
	if (!$self->domain_exists($domain_name)) {
		notify($ERRORS{'OK'}, 0, "'$domain_name' domain not deleted, it is not defined on $node_name");
		return 1;
	}
	
	# Power off the domain
	if ($self->power_status($domain_name) !~ /off/) {
		if (!$self->power_off($domain_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete '$domain_name' domain on $node_name, failed to power off domain");
			return;
		}
	}
	
	# Delete all snapshots created for the domain
	my $snapshot_info = $self->get_snapshot_info($domain_name);
	for my $snapshot_name (keys %$snapshot_info) {
		if (!$self->delete_snapshot($domain_name, $snapshot_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete '$domain_name' domain on $node_name, its '$snapshot_name' snapshot could not be deleted");
			return;
		}
	}
	
	my ($computer_name) = $domain_name =~ /^([^:_]+)[:_]/;
	if ($request_state_name eq 'image' || $computer_name) {
		# Delete disks assigned to to domain
		my @disk_file_paths = $self->get_domain_disk_file_paths($domain_name);
		for my $disk_file_path (@disk_file_paths) {
			# For safety, make sure the disk being deleted begins with the domain's computer name
			my $disk_file_name = fileparse($disk_file_path, qr/\.[^\/]+$/i);
			if ($request_state_name ne 'image' && $disk_file_name !~ /^$computer_name\_/) {
				notify($ERRORS{'WARNING'}, 0, "disk assigned to domain NOT deleted because the file name does not begin with '$computer_name\_':\nfile name: $disk_file_name\nfile path: $disk_file_path");
				next;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "deleting disk assigned to domain: $disk_file_path");
				if (!$self->vmhost_os->delete_file($disk_file_path)) {
					notify($ERRORS{'WARNING'}, 0, "failed to delete '$domain_name' domain on $node_name, '$disk_file_path' disk could not be deleted");
				}
			}
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine computer name from domain name '$domain_name' on $node_name, disks assigned domain will NOT be deleted for safety");
	}

	# Undefine the domain
	my $command = "virsh undefine \"$domain_name\" --managed-save --snapshots-metadata";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to undefine '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to undefine '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "undefined '$domain_name' domain on $node_name");
	}
	
	notify($ERRORS{'OK'}, 0, "deleted '$domain_name' domain from $node_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 generate_domain_xml

 Parameters  : none
 Returns     : string
 Description : Generates a string containing the XML definition for the domain.

=cut

sub generate_domain_xml {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_id = $self->data->get_request_id();
	my $reservation_id = $self->data->get_reservation_id();
	my $image_name = $self->data->get_image_name();
	my $image_display_name = $self->data->get_image_prettyname();
	my $image_os_type = $self->data->get_image_os_type();
	my $computer_name = $self->data->get_computer_short_name();
	my $management_node_name = $self->data->get_management_node_short_name();
	
	my $timestamp = makedatestring();
	
	my $domain_name = $self->get_domain_name();
	my $domain_type = $self->driver->get_domain_type();
	
	my $copy_on_write_file_path = $self->get_copy_on_write_file_path();
	my $image_type = $self->data->get_vmhost_datastore_imagetype_name();
	my $disk_driver_name = $self->driver->get_disk_driver_name();
	my $disk_bus_type = $self->get_master_xml_disk_bus_type();
	
	my $eth0_source_device = $self->data->get_vmhost_profile_virtualswitch0();
	my $eth1_source_device = $self->data->get_vmhost_profile_virtualswitch1();
	
	my $network_info = $self->get_node_network_info();
	
	my $eth0_interface_type = 'bridge';
	if (defined($network_info->{$eth0_source_device})) {
		$eth0_interface_type = 'network';
	}
	
	my $eth1_interface_type = 'bridge';
	if (defined($network_info->{$eth1_source_device})) {
		$eth1_interface_type = 'network';
	}

	my $eth0_mac_address;
	my $is_eth0_mac_address_random = $self->data->get_vmhost_profile_eth0generated(0);
	if ($is_eth0_mac_address_random) {
		$eth0_mac_address = get_random_mac_address();
		$self->data->set_computer_eth0_mac_address($eth0_mac_address);
	}
	else {
		$eth0_mac_address = $self->data->get_computer_eth0_mac_address();
	}
	
	my $eth1_mac_address;
	my $is_eth1_mac_address_random = $self->data->get_vmhost_profile_eth1generated(0);
	if ($is_eth1_mac_address_random) {
		$eth1_mac_address = get_random_mac_address();
		$self->data->set_computer_eth1_mac_address($eth1_mac_address);
	}
	else {
		$eth1_mac_address = $self->data->get_computer_eth1_mac_address();
	}
	
	my $interface_model_type = $self->get_master_xml_interface_model_type();
	
	my $cpu_count = $self->data->get_image_minprocnumber() || 1;
	
	my $memory_mb = $self->data->get_image_minram();
	if ($memory_mb < 512) {
		$memory_mb = 512;
	}
	my $memory_kb = ($memory_mb * 1024);
	
	my $description = <<EOF;
image: $image_display_name
revision: $image_name
load time: $timestamp
management node: $management_node_name
request ID: $request_id
reservation ID: $reservation_id
EOF

	# Per libvirt documentation:
	#   "The guest clock is typically initialized from the host clock.
	#    Most operating systems expect the hardware clock to be kept in UTC, and this is the default.
	#    Windows, however, expects it to be in so called 'localtime'."
	my $clock_offset = ($image_os_type =~ /windows/) ? 'localtime' : 'utc';
	
	my $xml_hashref = {
		'type' => $domain_type,
		'description' => [$description],
		'name' => [$domain_name],
		'on_poweroff' => ['preserve'],
		'on_reboot' => ['restart'],
		'on_crash' => ['preserve'],
		'os' => [
			{
				'type' => {
					'content' => 'hvm'
				}
			}
		],
		'features' => [
			{
				'acpi' => [{}],
				'apic' => [{}],
			}
		],
		'memory' => [$memory_kb],
		'vcpu'   => [$cpu_count],
		'cpu' => [
			
			{
				mode => 'host-model',		# Required, some images won't boot on different hosts without
				model => {
					'fallback' => 'allow',
				},
				#'topology' => [
				#	{
				#		'sockets' => $cpu_count,
				#		'cores' => '2',
				#		'threads' => '2',
				#	}
				#],
				
			}
		],
		'clock' => [
			{
				'offset' => $clock_offset,
			}
		],
		'devices' => [
			{
				'disk' => [
					{
						'device' => 'disk',
						'type' => 'file',
						'driver' => {
							'name' => $disk_driver_name,
							'type' => $image_type,
							#'cache' => 'none',
						},
						'source' => {
							'file' => $copy_on_write_file_path,
						},
						'target' => {
							'bus' => $disk_bus_type,
							'dev' => 'vda',	# Required
						},
					}
				],
				'interface' => [
					{
						'type' => $eth0_interface_type,
						'mac' => {
							'address' => $eth0_mac_address,
						},
						'source' => {
							$eth0_interface_type => $eth0_source_device,
						},
						#'target' => {
						#	'dev' => 'vnet0',
						#},
						'model' => {
							'type' => $interface_model_type,
						},
					},
					{
						'type' => $eth1_interface_type,	
						'mac' => {
							'address' => $eth1_mac_address,
						},
						'source' => {
							$eth1_interface_type => $eth1_source_device,
						},
						#'target' => {
						#	'dev' => 'vnet1',
						#},
						'model' => {
							'type' => $interface_model_type,
						},
					}
				],
				'graphics' => [
					{
						'type' => 'vnc',
						#'type' => 'spice',
						#'autoport' => 'yes',
						#'port' => '-1',
						#'tlsPort' => '-1',
						
					}
				],
			}
		]
	};
	
	notify($ERRORS{'DEBUG'}, 0, "generated domain XML:\n" . format_data($xml_hashref));
	return hash_to_xml_string($xml_hashref, 'domain');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about all of the domains defined on the
               node and constructs a hash containing the information. Example:
                  "vclv99-197:vmwarewin7-Windows764bit1846-v3" => {
                     "id" => 135,
                     "state" => "paused"
                  },
                  "vclv99-37:vmwarewinxp-base234-v23" => {
                     "state" => "shut off"
                  }

=cut

sub get_domain_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh list --all";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to list defined domains on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list defined domains on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "listed defined domains on $node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
	}
	
	# [root@vclh3-10 images]# virsh list --all
	#  Id Name                 State
	# ----------------------------------
	#  14 test-name            running
	#   - test-2gb             shut off
	#   - vclv99-197: vmwarelinux-RHEL54Small2251-v1 shut off

	my $defined_domains = {};
	my $domain_info_string = '';
	for my $line (@$output) {
		my ($id, $name, $state) = $line =~ /^\s*([\d\-]+)\s+(.+?)\s+(\w+|shut off)$/g;
		next if (!defined($id));
		
		$defined_domains->{$name}{state} = $state;
		$defined_domains->{$name}{id} = $id if ($id =~ /\d/);
		
		$domain_info_string .= "$id. $name ($state)\n";
	}
	
	if ($defined_domains) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved domain info from $node_name:\n$domain_info_string");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no domains are defined on $node_name");
	}
	
	return $defined_domains;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_xml_string

 Parameters  : $domain_name
 Returns     : string
 Description : Retrieves the XML definition of a domain already defined on the
               node.

=cut

sub get_domain_xml_string {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh dumpxml \"$domain_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to retrieve XML definition for '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve XML definition for '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	
	return join("\n", @$output);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_xml

 Parameters  : $domain_name
 Returns     : hash reference
 Description : Retrieves the XML definition of a domain already defined on the
               node. Generates a hash.

=cut

sub get_domain_xml {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $domain_xml_string = $self->get_domain_xml_string($domain_name) || return;
	if (my $xml_hash = xml_string_to_hash($domain_xml_string)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$domain_name' domain on $node_name");
		#notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$domain_name' domain on $node_name:\n" . format_data($xml_hash));
		return $xml_hash;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML definition for '$domain_name' domain to hash:\n$domain_xml_string");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_disk_file_paths

 Parameters  : $domain_name
 Returns     : array
 Description : Retrieves the XML definition for the domain and extracts the disk
               file paths. An array containing the paths is returned.

=cut

sub get_domain_disk_file_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	# Get the domain XML definition
	my $domain_xml = $self->get_domain_xml($domain_name);
	
	# Get the disk array ref section from the XML
	my $disks = $domain_xml->{devices}->[0]->{disk};
	
	my @disk_file_paths = ();
	for my $disk (@$disks) {
		# Make sure device type is 'disk'
		if (!$disk->{device}) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk definition, 'device' key is not present:\n" . format_data($disk));
			next;
		}
		elsif ($disk->{device} !~ /^disk$/i) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk definition, 'device' key value is not 'disk', value: '$disk->{device}'\n" . format_data($disk));
			next;
		}
		
		# Make sure $disk->{source}->[0]->{file}
		if (!defined($disk->{source}->[0]->{file})) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk definition, '{source}->[0]->{file}' key is not present\n" . format_data($disk));
			next;
		}
		
		push @disk_file_paths, $disk->{source}->[0]->{file};
	}
	
	return @disk_file_paths;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_mac_addresses

 Parameters  : $domain_name
 Returns     : array
 Description : Retrieves the XML definition for the domain and extracts the MAC
               addresses. An array containing the addresses is returned.

=cut

sub get_domain_mac_addresses {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	# Get the domain XML definition
	my $domain_xml = $self->get_domain_xml($domain_name);
	
	# Get the interface array ref section from the XML
	my $interfaces = $domain_xml->{devices}->[0]->{interface};
	
	my @mac_addresses = ();
	for my $interface (@$interfaces) {
		#notify($ERRORS{'DEBUG'}, 0, "interface configured for domain '$domain_name':\n" . format_data($interface));
		push @mac_addresses, $interface->{mac}->[0]->{address};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved MAC addresses assigned to domain '$domain_name':\n" . join("\n", @mac_addresses));
	return @mac_addresses;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 domain_exists

 Parameters  : $domain_name
 Returns     : boolean
 Description : Determines if the domain is defined on the node.

=cut

sub domain_exists {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_name = shift;
	if (!defined($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Get the domain info hash, make sure domain is defined
	my $domain_info = $self->get_domain_info();
	if (!defined($domain_info)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if '$domain_name' domain exists, domain information could not be retrieved from $node_name");
		return;
	}
	elsif (!$domain_info) {
		notify($ERRORS{'DEBUG'}, 0, "'$domain_name' domain does not exist, no domains are defined on $node_name");
		return 0;
	}
	elsif (!defined($domain_info->{$domain_name})) {
		notify($ERRORS{'OK'}, 0, "'$domain_name' is not defined on $node_name");
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "'$domain_name' exists on $node_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_snapshot_info

 Parameters  : $domain_name
 Returns     : hash reference
 Description : Retrieves snapshot information for the domain specified by the
               argument and constructs a hash. The hash keys are the snapshot
               names. Example:
                  "VCL snapshot" => {
                     "creation_time" => "2011-12-07 16:05:50 -0500",
                     "state" => "shutoff"
                  }

=cut

sub get_snapshot_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $domain_name = shift;
	if (!$domain_name) {
		notify($ERRORS{'WARNING'}, 0, "domain name argument was not supplied");
		return;
	}
	
	my $command = "virsh snapshot-list \"$domain_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to list snapshots of '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list snapshots of '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "listed snapshots of '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
	}
	
	#virsh # snapshot-list 'vclv99-197:vmwarelinux-RHEL54Small2251-v1'
	# Name                 Creation Time             State
	#------------------------------------------------------------
	# VCL snapshot         2011-11-21 17:10:05 -0500 shutoff

	my $shapshot_info = {};
	for my $line (@$output) {
		my ($name, $creation_time, $state) = $line =~ /^\s*(.+?)\s+(\d{4}-\d{2}-\d{2} [^a-z]+)\s+(\w+)$/g;
		next if (!defined($name));
		
		$shapshot_info->{$name}{creation_time} = $creation_time;
		$shapshot_info->{$name}{state} = $state;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved snapshot info for '$domain_name' domain on $node_name:\n" . format_data($shapshot_info));
	return $shapshot_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_snapshot

 Parameters  : $domain_name, $description
 Returns     : boolean
 Description : Creates a snapshot of the domain specified by the argument.

=cut

sub create_snapshot {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $domain_name = shift;
	if (!$domain_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to create snapshot on $node_name, domain argument was not supplied");
		return;
	}
	
	my $description = shift || $self->get_domain_name();
	
	my $command = "virsh snapshot-create-as \"$domain_name\" \"$description\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to create snapshot of domain '$domain_name' on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to create snapshot of domain '$domain_name' on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "created snapshot of domain '$domain_name' on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_snapshot

 Parameters  : $domain_name, $snapshot
 Returns     : boolean
 Description : Deletes a snapshot created of the domain specified by the
               argument.

=cut

sub delete_snapshot {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $domain_name = shift;
	my $snapshot = shift;
	if (!defined($domain_name) || !defined($snapshot)) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete snapshot on $node_name, domain and snapshot arguments not supplied");
		return;
	}
	
	my $command = "virsh snapshot-delete \"$domain_name\" \"$snapshot\" --children";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to delete '$snapshot' snapshot of domain '$domain_name' on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$snapshot' snapshot of domain '$domain_name' on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "deleted '$snapshot' snapshot of domain '$domain_name' on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_size_bytes

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the image in bytes.

=cut

sub get_image_size_bytes {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = shift || $self->data->get_image_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $master_image_file_path = $self->get_master_image_file_path($image_name);
	
	my $image_size_bytes;
	
	# Check if the master image file exists on the VM host
	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		# Get a semaphore in case another process is currently copying to create the master image
		if (my $semaphore = $self->get_master_image_semaphore()) {
			$image_size_bytes = $self->vmhost_os->get_file_size($master_image_file_path);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to determine size of $image_name on $node_name: $master_image_file_path, unable to obtain semaphore");
			return;
		}
	}
	
	# Check the repository if the master image does not exist on the VM host or if failed to determine size
	if (!$image_size_bytes) {
		my @repository_image_file_paths = $self->find_repository_image_file_paths();
		if (!@repository_image_file_paths) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieved size of $image_name image, size could not be determined from $node_name and image files were not found in the repository");
			return;
		}
		
		# Note - don't need semaphore because find_repository_image_file_paths gets one while it's checking
		$image_size_bytes = $self->vmhost_os->get_file_size(@repository_image_file_paths);
		if (!$image_size_bytes) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieved size of $image_name image from the repository mounted on $node_name");
			return;
		}
	}
	
	if (!$image_size_bytes) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieved size of $image_name image on $node_name");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved size of $image_name image on $node_name:\n" . get_file_size_info_string($image_size_bytes));
	return $image_size_bytes;
} ## end sub get_image_size_bytes

#//////////////////////////////////////////////////////////////////////////////

=head2  find_repository_image_file_paths

 Parameters  : $image_name (optional)
 Returns     : array
 Description : Locates valid image files stored in the image repository.
               Searches for all files beginning with the image name and then
               checks the results to remove any files which should not be
               included. File extensions which are excluded: vmx, txt, xml
               If multiple vmdk files are found it is assumed that the image is
               one of the split vmdk formats and the <image name>.vmdk contains
               the descriptor information. This file is excluded because it
               causes qemu-img to fail.

=cut

sub find_repository_image_file_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the image name argument
	my $image_name = shift || $self->data->get_image_name();
	
	# Return previosly retrieved result if defined
	return @{$self->{repository_file_paths}{$image_name}} if $self->{repository_file_paths}{$image_name};
	
	my $node_name = $self->data->get_vmhost_short_name();
	my $vmhost_repository_directory_path = $self->data->get_vmhost_profile_repository_path(0);
	
	if (!$vmhost_repository_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "repository path is not configured in the VM host profile for $node_name");
		return;
	}
	
	# Get a semaphore in case another process is currently copying the image to the repository
	my @matching_repository_file_paths;
	if (my $semaphore = $self->get_repository_image_semaphore()) {
		# Attempt to locate files in the repository matching the image name
		@matching_repository_file_paths = $self->vmhost_os->find_files($vmhost_repository_directory_path, "$image_name*.*");
		if (!@matching_repository_file_paths) {
			notify($ERRORS{'DEBUG'}, 0, "image $image_name does NOT exist in the repository mounted on $node_name");
			return ();
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if $image_name exists on in the repository mounted on $node_name, unable to obtain semaphore");
		return;
	}
	
	# Check the files found in the repository
	# Attempt to determine which files are actual virtual disk files
	my @virtual_disk_repository_file_paths;
	for my $virtual_disk_repository_file_path (sort @matching_repository_file_paths) {
		# Skip files which match known extensions which should be excluded
		if ($virtual_disk_repository_file_path =~ /\.(vmx|txt|xml)/i) {
			notify($ERRORS{'DEBUG'}, 0, "not including matching file because its extension is '$1': $virtual_disk_repository_file_path");
			next;
		}
		elsif ($virtual_disk_repository_file_path !~ /\/[^\/]*\.[^\/]*$/i) {
			notify($ERRORS{'DEBUG'}, 0, "not including matching directory: $virtual_disk_repository_file_path");
			next;
		}
		
		push @virtual_disk_repository_file_paths, $virtual_disk_repository_file_path;
	}
	
	if (!@virtual_disk_repository_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "failed to locate any valid virtual disk files for image $image_name in repository on $node_name");
		return;
	}
	
	# Check if a multi-file vmdk was found
	# Remove the descriptor file - <image name>.vmdk
	if (@virtual_disk_repository_file_paths > 1 && $virtual_disk_repository_file_paths[0] =~ /\.vmdk$/i) {
		my @corrected_virtual_disk_repository_file_paths;
		for my $virtual_disk_repository_file_path (@virtual_disk_repository_file_paths) {
			if ($virtual_disk_repository_file_path =~ /$image_name\.vmdk$/) {
				notify($ERRORS{'DEBUG'}, 0, "excluding file because it appears to be a vmdk descriptor file: $virtual_disk_repository_file_path");
				next;
			}
			else {
				push @corrected_virtual_disk_repository_file_paths, $virtual_disk_repository_file_path;
			}
			
		}
		@virtual_disk_repository_file_paths = @corrected_virtual_disk_repository_file_paths;
	}
	
	# Save the result so this doesn't have to be done again
	$self->{repository_file_paths}{$image_name} = \@virtual_disk_repository_file_paths;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved " . scalar(@virtual_disk_repository_file_paths) . " repository file paths for image $image_name on $node_name:\n" . join("\n", @virtual_disk_repository_file_paths));
	return @virtual_disk_repository_file_paths
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_master_image_semaphore

 Parameters  : $image_name (optional)
 Returns     : Semaphore object
 Description : Obtains a semaphore to be used to ensure that only a single
					process is copying or querying the attributes of the master image
					file at a time.

=cut

sub get_master_image_semaphore {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the image name argument
	my $image_name = shift || $self->data->get_image_name();
	
	my $semaphore_id = "master:$image_name";
	my $semaphore = $self->get_semaphore($semaphore_id, (60 * 120), 15);
	if ($semaphore) {
		return $semaphore;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain semaphore for master image: $image_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_repository_image_semaphore

 Parameters  : $image_name (optional)
 Returns     : Semaphore object
 Description : Obtains a semaphore to be used to ensure that only a single
					process is copying or querying the attributes of the repository image
					file at a time.

=cut

sub get_repository_image_semaphore {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the image name argument
	my $image_name = shift || $self->data->get_image_name();
	
	my $semaphore_id = "repository:$image_name";
	my $semaphore = $self->get_semaphore($semaphore_id, (60 * 120), 15);
	if ($semaphore) {
		return $semaphore;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain semaphore for repository image: $image_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_network_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about all of the networks defined on the
               node and constructs a hash containing the information. Example:
               {
                 "private" => {
                   "autostart" => "yes",
                   "persistent" => "yes",
                   "state" => "active"
                 },
                 "public" => {
                   "autostart" => "yes",
                   "persistent" => "yes",
                   "state" => "active"
                 }
               }

=cut

sub get_node_network_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh net-list --all";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to list networks on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list networks on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "listed networks on $node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
	}

	# root@bn17-231:/pools# virsh net-list --all
	#  Name                 State      Autostart     Persistent
	# ----------------------------------------------------------
	#  private              active     yes           yes
	#  public               active     yes           yes


	my $info = {};
	for my $line (@$output) {
		my ($name, $state, $autostart, $persistent) = $line =~ /^\s*([\w_]+)\s+(\w+)\s+(\w+)\s+(\w+)$/g;
		next if (!defined($name) || $name =~ /Name/);
		
		$info->{$name}{state} = $state;
		$info->{$name}{autostart} = $autostart;
		$info->{$name}{persistent} = $persistent;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved network info from $node_name:\n" . format_data($info));
	return $info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_network_xml_string

 Parameters  : $network_name
 Returns     : string
 Description : Retrieves the XML definition of a network defined on the node.

=cut

sub get_node_network_xml_string {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $network_name = shift;
	if (!defined($network_name)) {
		notify($ERRORS{'WARNING'}, 0, "network name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh net-dumpxml --network \"$network_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to retrieve XML definition for '$network_name' network on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve XML definition for '$network_name' network on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		my $xml_string = join("\n", @$output);
		notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$network_name' network on $node_name\n$xml_string");
		return $xml_string;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_interface_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about all of the physical host interfaces
               on the node and constructs a hash containing the information.
               Example:
               {
                 "br0" => {
                   "mac_address" => "00:50:56:23:00:1c",
                   "state" => "active"
                 },
                 "br1" => {
                   "mac_address" => "00:50:56:23:00:1d",
                   "state" => "active"
                 },
                 "lo" => {
                   "mac_address" => "00:00:00:00:00:00",
                   "state" => "active"
                 }
               }

=cut

sub get_node_interface_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh iface-list --all";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to list physical interfaces on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to list physical interfaces on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "listed physical interfaces on $node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
	}

	# root@bn17-231:/pools# virsh iface-list --all
	#  Name                 State      MAC Address
	# ---------------------------------------------------
	#  br0                  active     00:50:56:23:00:1c
	#  br1                  active     00:50:56:23:00:1d

	my $info = {};
	for my $line (@$output) {
		my ($name, $state, $mac_address) = $line =~ /^\s*(\w+)\s+(\w+)\s+([\w\:]+)$/g;
		next if (!defined($name) || $name =~ /^(Name|lo)/);
		
		$info->{$name}{state} = $state;
		$info->{$name}{mac_address} = $mac_address;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved physical interface info from $node_name:\n" . format_data($info));
	return $info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_interface_xml_string

 Parameters  : $interface_name
 Returns     : string
 Description : Retrieves the XML definition of a network defined on the node.

=cut

sub get_node_interface_xml_string {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $interface_name = shift;
	if (!defined($interface_name)) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not specified");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "virsh iface-dumpxml --interface \"$interface_name\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to retrieve XML definition for '$interface_name' interface on $node_name");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve XML definition for '$interface_name' interface on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		my $xml_string = join("\n", @$output);
		notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$interface_name' interface on $node_name\n$xml_string");
		return $xml_string;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_xml_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves the XML definition from the file saved when the image
               was captured.

=cut

sub get_master_xml_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (defined($self->{master_xml_info})) {
		return $self->{master_xml_info};
	}
	
	# Save the domain XML definition to a file in the master image directory
	my $master_xml_file_path = $self->get_master_xml_file_path() || return;
	if (!$self->vmhost_os->file_exists($master_xml_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "master XML file does not exist: $master_xml_file_path");
		$self->{master_xml_info} = {};
		return $self->{master_xml_info};
	}
	
	my $master_xml_file_contents = $self->vmhost_os->get_file_contents($master_xml_file_path);
	if (!$master_xml_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "master XML file contents could not be retrieved");
		$self->{master_xml_info} = {};
		return $self->{master_xml_info};
	}
	
	my $master_xml_hashref = xml_string_to_hash($master_xml_file_contents);
	if ($master_xml_hashref) {
		$self->{master_xml_info} = $master_xml_hashref;
		notify($ERRORS{'DEBUG'}, 0, "retrieved master XML info from $master_xml_file_path");
		#notify($ERRORS{'DEBUG'}, 0, "retrieved master XML info from $master_xml_file_path:\n" . format_data($self->{master_xml_info}));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "retrieved master XML info could not be parsed");
		$self->{master_xml_info} = {};
	}
	return $self->{master_xml_info};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_xml_device_info

 Parameters  : $device_name (optional)
 Returns     : hash reference
 Description : Retrieves the device portion of the XML definition from the file
               saved when the image was captured.
               
               If $device_name is specified, an array reference containing info
               for the specific device is returned.
               
               If $device_name is not specified, a hash reference is returned.
               Each key represents a device name.

=cut

sub get_master_xml_device_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $device_name = shift;
	
	my $master_xml_file_path = $self->get_master_xml_file_path();
	
	if (!defined($self->{master_xml_device_info})) {
		my $master_xml_info = $self->get_master_xml_info() || return;
		if (scalar(keys %$master_xml_info) == 0) {
			return;
		}
		
		# Should always be a 'devices' key which contains an array ref with a single array value: $master_xml_info->{devices}->[0]
		my $devices_array_ref = $master_xml_info->{devices};
		if (!$devices_array_ref) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve device info from master XML file: $master_xml_file_path, 'devices' key is missing:\n" . format_data($master_xml_info));
			return;
		}
		elsif (!ref($devices_array_ref) || ref($devices_array_ref) ne 'ARRAY') {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve device info from master XML file: $master_xml_file_path, 'devices' key is not an array reference:\n" . format_data($master_xml_info));
			return;
		}
		elsif (scalar(@$devices_array_ref) == 0) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve device info from master XML file: $master_xml_file_path, 'devices' array reference is empty:\n" . format_data($master_xml_info));
			return;
		}
		elsif (scalar(@$devices_array_ref) > 1) {
			notify($ERRORS{'WARNING'}, 0, "retrieved device info from master XML file: $master_xml_file_path, 'devices' array reference contains multiple values:\n" . format_data($devices_array_ref));
		}
		
		$self->{master_xml_device_info} = @$devices_array_ref[0];
		notify($ERRORS{'DEBUG'}, 0, "retrieved device info from master XML file: $master_xml_file_path, hash reference keys:\n" . format_hash_keys($self->{master_xml_device_info}));	
	}
	
	if ($device_name) {
		if (defined($self->{master_xml_device_info}{$device_name})) {
			## Only display the info once to reduce vcld.log noise
			#if (!defined($self->{master_xml_device_info_displayed}{$device_name})) {
			#	notify($ERRORS{'DEBUG'}, 0, "retrieved '$device_name' device info from master XML file: $master_xml_file_path:\n" . format_data($self->{master_xml_device_info}{$device_name}));
			#	$self->{master_xml_device_info_displayed}{$device_name} = 1;
			#}
			return $self->{master_xml_device_info}{$device_name};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "'$device_name' key does not exist in device info from master XML file: $master_xml_file_path:\n" . format_hash_keys($self->{master_xml_device_info}));
			return;
		}
	}
	else {
		return $self->{master_xml_device_info};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_xml_disk_bus_type

 Parameters  : none
 Returns     : string
 Description : Retrieves the disk bus type from the master XML file saved when
               the image was captured. If unable to determine from master XML,
               'ide' is returned.

=cut

sub get_master_xml_disk_bus_type {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{master_xml_disk_bus_type} if defined($self->{master_xml_disk_bus_type});
	
	$self->{master_xml_disk_bus_type} = 'ide';
	
	my $disk_array_ref = $self->get_master_xml_device_info('disk') || return $self->{master_xml_disk_bus_type};
	
	for my $disk (@$disk_array_ref) {
		# Make sure the device type is 'disk', ignore others such as 'cdrom'
		my $device_type = $disk->{device} || '<unknown>';
		if ($device_type ne 'disk') {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk, type is $device_type:\n" . format_data($disk));
			next;
		}
		
		unless (defined($disk->{target}) && defined($disk->{target}->[0]) && defined($disk->{target}->[0]->{bus})) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk, '->{target}->[0]->{bus}' value is missing:\n" . format_data($disk));
			next;
		}
		$self->{master_xml_disk_bus_type} = $disk->{target}->[0]->{bus};
		notify($ERRORS{'DEBUG'}, 0, "retrieved disk bus type from master XML info: $self->{master_xml_disk_bus_type}");
		return $self->{master_xml_disk_bus_type};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "unable to determine disk bus type from master XML info, returning default value: $self->{master_xml_disk_bus_type}");
	$self->{master_xml_disk_bus_type};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_master_xml_interface_model_type

 Parameters  : none
 Returns     : string
 Description : Retrieves the interface model type from the master XML file saved
               when the image was captured. If unable to determine from master
               XML, 'rtl8139' is returned.

=cut

sub get_master_xml_interface_model_type {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{master_xml_interface_model_type} if defined($self->{master_xml_interface_model_type});
	
	$self->{master_xml_interface_model_type} = 'rtl8139';
	
	my $interface_array_ref = $self->get_master_xml_device_info('interface') || return $self->{master_xml_interface_model_type};
	
	for my $interface (@$interface_array_ref) {
		unless (defined($interface->{model}) && defined($interface->{model}->[0]) && defined($interface->{model}->[0]->{type})) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring interface, '->{model}->[0]->{type}' value is missing:\n" . format_data($interface));
			next;
		}
		$self->{master_xml_interface_model_type} = $interface->{model}->[0]->{type};
		notify($ERRORS{'DEBUG'}, 0, "retrieved interface model type from master XML info: $self->{master_xml_interface_model_type}");
		return $self->{master_xml_interface_model_type};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "unable to determine interface model type from master XML info, returning default value: $self->{master_xml_interface_model_type}");
	$self->{master_xml_interface_model_type};
}


#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
