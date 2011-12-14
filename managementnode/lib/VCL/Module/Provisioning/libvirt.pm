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

##############################################################################
package VCL::Module::Provisioning::libvirt;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use File::Basename;
use XML::Simple qw(:strict);

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

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
	
	my $node_name     = $self->data->get_vmhost_short_name();
	my $vmhost_type     = $self->data->get_vmhost_type_name();
	my $vmhost_username = $self->data->get_vmhost_profile_username();
	my $vmhost_password = $self->data->get_vmhost_profile_password();

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
		eval { $driver = ($driver_perl_package)->new({data_structure => $self->data, os => $self->os}) };
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
	}
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " provisioning module initialized");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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

	my $command = "virsh define \"$domain_xml_file_path\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute virsh command to define '$domain_name' domain on $node_name");
		return;
	}
	elsif ($exit_status eq '0') {
		notify($ERRORS{'OK'}, 0, "defined '$domain_name' domain on $node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to define '$domain_name' domain on $node_name\ncommand: $command\nexit status: $exit_status\noutput:\n" . join("\n", @$output));
		return;
	}

=item *

Power on the domain.

=cut

	if (!$self->power_on($domain_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to start '$domain_name' domain on $node_name");
		return;
	}

=item *

Call the domain guest OS module's 'post_load' subroutine if implemented.

=cut

	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "performed OS post-load tasks '$domain_name' domain on $node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on '$domain_name' domain on node $node_name");
			return;
		}
	}
	else {
		insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "OS post-load tasks not necessary '$domain_name' domain on $node_name");
	}

=back

=cut

	return 1;
} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

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
	
	return 1;
} ## end sub capture

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $computer_id (optional)
 Returns     : string
 Description : Checks the status of the computer in order to determine if the
               computer is ready to be reserved or needs to be reloaded. A
               string is returned depending on the status of the computer:
               'READY':
                  * Computer is ready to be reserved
                  * It is accessible
                  * It is loaded with the correct image
                  * OS module's post-load tasks have run
               'POST_LOAD':
                  * Computer is loaded with the correct image
                  * OS module's post-load tasks have not run
               'RELOAD':
                  * Computer is not accessible or not loaded with the correct
                    image

=cut

sub node_status {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return 'RELOAD';
} ## end sub node_status

#/////////////////////////////////////////////////////////////////////////////

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
	my $semaphore_id = "$node_name:$master_image_file_path";
	my $semaphore_timeout_minutes = 60;
	my $semaphore = $self->get_semaphore($semaphore_id, (60 * $semaphore_timeout_minutes), 5) || return;	
	
	# Check if the master image file exists on the VM host
	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "$image_name image exists on $node_name: $master_image_file_path");
		return 1;
	}
	
	# Attempt to find the image files in the repository
	if ($self->find_repository_image_file_paths($image_name)) {
		notify($ERRORS{'DEBUG'}, 0, "$image_name image exists in the repository mounted on $node_name");
		return 1;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$image_name image does not exist $node_name");
	return 0;
} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_search_paths

 Parameters  : $management_node_identifier (optional)
 Returns     : array
 Description : Returns an array containing paths on the management node where an
               image may reside. The paths may contain wildcards. This is used
               to attempt to locate an image on another managment node in order
               to retrieve it.

=cut

sub get_image_repository_search_paths {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return ();
} ## end sub get_image_repository_search_paths

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2  post_maintenance_action

 Parameters  : none
 Returns     : boolean
 Description : Performs tasks to the computer after it has been put into
               maintenance mode.

=cut

sub post_maintenance_action {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return 1;
} ## end sub post_maintenance_action

##############################################################################

=head1 PRIVATE METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_domain_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the domain. This name is passed to various
               virsh commands. It is also the name displayed in virt-manager.
               Example: 'vclv99-197:vmwarewin7-Windows764bit1846-v3'

=cut

sub get_domain_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_short_name = $self->data->get_computer_short_name();
	my $image_id = $self->data->get_image_id();
	my $image_name = $self->data->get_image_name();
	my $image_revision = $self->data->get_imagerevision_revision();
	
	return "$computer_short_name:$image_name";
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 get_master_image_directory_path

 Parameters  : none
 Returns     : string
 Description : Returns the directory path on the node where the master image
               files reside. Example: '/var/lib/libvirt/images'

=cut

sub get_master_image_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $datastore_path = $self->data->get_vmhost_profile_datastore_path();
	return $datastore_path;
}

#/////////////////////////////////////////////////////////////////////////////

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
	if (@master_image_files_found == 1) {
		$self->{master_image_file_path} = $master_image_files_found[0];
		notify($ERRORS{'DEBUG'}, 0, "found master image file on $node_name: $self->{master_image_file_path}");
		return $self->{master_image_file_path};
	}
	
	# File was not found, construct it
	my $vmdisk_format = $self->data->get_vmhost_profile_vmdisk_format();
	return "$master_image_directory_path/$image_name.$vmdisk_format";
}

#/////////////////////////////////////////////////////////////////////////////

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
	my $vmdisk_format       = $self->data->get_vmhost_profile_vmdisk_format();
	
	return "$vmhost_vmpath/$domain_file_name.$vmdisk_format";
}

#/////////////////////////////////////////////////////////////////////////////

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
		next if ($domain_name !~ /^$computer_name:/);
		
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

#/////////////////////////////////////////////////////////////////////////////

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
	
	# Delete volumes assigned to to domain
	my $domain_xml = $self->get_domain_xml($domain_name);
	my $disks = $domain_xml->{devices}->[0]->{disk};
	for my $disk (@$disks) {
		my $volume_path = $disk->{source}->[0]->{file};
		notify($ERRORS{'DEBUG'}, 0, "deleting volume assigned to domain: " . $disk->{source}->[0]->{file});
		
		if (!$self->vmhost_os->delete_file($volume_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete '$domain_name' domain on $node_name, '$volume_path' volume could not be deleted");
			return;
		}
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

#/////////////////////////////////////////////////////////////////////////////

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
	
	my $image_name = $self->data->get_image_name();
	my $image_display_name = $self->data->get_image_prettyname();
	my $image_os_type = $self->data->get_image_os_type();
	my $computer_name = $self->data->get_computer_short_name();
	
	my $domain_name = $self->get_domain_name();
	my $domain_type = $self->driver->get_domain_type();
	
	my $copy_on_write_file_path = $self->get_copy_on_write_file_path();
	my $disk_format = $self->data->get_vmhost_profile_vmdisk_format();
	my $disk_driver_name = $self->driver->get_disk_driver_name();
	
	my $eth0_source_device = $self->data->get_vmhost_profile_virtualswitch0();
	my $eth1_source_device = $self->data->get_vmhost_profile_virtualswitch1();
	
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
	
	my $cpu_count = $self->data->get_image_minprocnumber() || 1;
	
	my $memory_mb = $self->data->get_image_minram();
	if ($memory_mb < 512) {
		$memory_mb = 512;
	}
	my $memory_kb = ($memory_mb * 1024);
	
	# Per libvirt documentation:
	#   "The guest clock is typically initialized from the host clock.
	#    Most operating systems expect the hardware clock to be kept in UTC, and this is the default.
	#    Windows, however, expects it to be in so called 'localtime'."
	my $clock_offset = ($image_os_type =~ /windows/) ? 'localtime' : 'utc';

	my $xml = {
		'type' => $domain_type,
		'description' => [$image_display_name],
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
				'topology' => [
					{
						'sockets' => $cpu_count,
						'cores' => '2',
						'threads' => '2',
					}
				],
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
							'type' => $disk_format,
							'cache' => 'none',
						},
						'source' => {
							'file' => $copy_on_write_file_path,
						},
						'target' => {
							'bus' => 'ide',
							'dev' => 'vda'
						},
					}
				],
				'interface' => [
					{
						'type' => 'bridge',
						'mac' => {
							'address' => $eth0_mac_address,
						},
						'source' => {
							'bridge' => $eth0_source_device,
						},
						'target' => {
							'dev' => 'vnet0',
						},
						'model' => {
							#'type' => 'rtl8139',
						},
					},
					{
						'type' => 'bridge',	
						'mac' => {
							'address' => $eth1_mac_address,
						},
						'source' => {
							'bridge' => $eth1_source_device,
						},
						'target' => {
							'dev' => 'vnet1',
						},
						'model' => {
							#'type' => 'rtl8139',
						},
					}
				],
				'graphics' => [
					{
						'type' => 'vnc',
					}
				],
				'video' => [
					{
						'model' => {
							'type' => 'cirrus',
						}
					}
				],
			}
		]
	};
	
	my $domain_xml_definition = XMLout($xml,
		'RootName' => 'domain',
		'KeyAttr' => []
	);

	return $domain_xml_definition;
}

#/////////////////////////////////////////////////////////////////////////////

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
		notify($ERRORS{'DEBUG'}, 0, "retrieved list of defined domains on $node_name:\n" . join("\n", @$output));
	}
	
	# [root@vclh3-10 images]# virsh list --all
	#  Id Name                 State
	# ----------------------------------
	#  14 test-name            running
	#   - test-2gb             shut off
	#   - vclv99-197: vmwarelinux-RHEL54Small2251-v1 shut off

	my $defined_domains = {};
	for my $line (@$output) {
		my ($id, $name, $state) = $line =~ /^\s*([\d\-]+)\s(.+?)\s+(\w+|shut off)$/g;
		next if (!defined($id));
		
		$defined_domains->{$name}{state} = $state;
		$defined_domains->{$name}{id} = $id if ($id =~ /\d/);
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved domain info:\n" . format_data($defined_domains));
	return $defined_domains;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_domain_xml

 Parameters  : $domain_name
 Returns     : hash reference
 Description : Retrieves the XML definition of a domain already defined on the
               node. Generates a hash using XML::Simple::XMLin.

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
	
	# Convert the XML to a hash using XML::Simple
	my $xml = XMLin(join("\n", @$output), 'ForceArray' => 1, 'KeyAttr' => []);
	if ($xml) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$domain_name' domain on $node_name");
		notify($ERRORS{'DEBUG'}, 0, "retrieved XML definition for '$domain_name' domain on $node_name:\n" . format_data($xml));
		return $xml;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to convert XML definition for '$domain_name' domain to hash:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
		my $semaphore_id = "$node_name:$master_image_file_path";
		my $semaphore_timeout_minutes = 60;
		my $semaphore = $self->get_semaphore($semaphore_id, (60 * $semaphore_timeout_minutes), 5) || return;
		
		$image_size_bytes = $self->vmhost_os->get_file_size($master_image_file_path)
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

#/////////////////////////////////////////////////////////////////////////////

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
	my $vmhost_repository_directory_path = $self->data->get_vmhost_profile_repository_path();
	
	if (!$vmhost_repository_directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "repository path is not configured in the VM host profile for $node_name");
		return;
	}
	
	# Get a semaphore in case another process is currently copying the image to the repository
	my $semaphore_id = "$node_name:$vmhost_repository_directory_path";
	my $semaphore_timeout_minutes = 60;
	my $semaphore = $self->get_semaphore($semaphore_id, (60 * $semaphore_timeout_minutes), 5) || return;
	
	# Attempt to locate files in the repository matching the image name
	my @matching_repository_file_paths = $self->vmhost_os->find_files($vmhost_repository_directory_path, "$image_name*.*");
	if (!@matching_repository_file_paths) {
		notify($ERRORS{'DEBUG'}, 0, "image $image_name does NOT exist in the repository on $node_name");
		return ();
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
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved " . scalar(@virtual_disk_repository_file_paths) . " repository file paths for image $image_name on $node_name");
	return @virtual_disk_repository_file_paths
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
