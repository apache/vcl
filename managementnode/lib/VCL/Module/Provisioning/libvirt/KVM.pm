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

VCL::Provisioning::libvirt::KVM - Libvirt hypervisor driver module to allow
support for the KVM hypervisor

=head1 DESCRIPTION

 This is a driver module to allow the main libvirt.pm provisioning module to
 support KVM hosts. It performs the KVM-specific tasks not handled by libvirt
 itself.

=cut

##############################################################################
package VCL::Module::Provisioning::libvirt::KVM;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::libvirt);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use File::Basename;

use VCL::utils;
	
##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Checks if the node has KVM installed by checking if /usr/bin/qemu
               exists. Returns true if the file exists, false otherwise.

=cut

sub initialize {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	my ($driver_name) = ref($self) =~ /::([^:]+)$/;
	
	# Check to see if qemu exists on the VM host
	my $test_file_path = '/usr/bin/qemu';
	if ($self->vmhost_os->file_exists($test_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "$driver_name driver module successfully initialized, verified '$test_file_path' exists on $node_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$driver_name driver module not initialized, '$test_file_path' does NOT exist on $node_name");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_domain_type

 Parameters  : none
 Returns     : string
 Description : Returns 'kvm'. This is specified in the domain XML definition:
                  <domain type='kvm'>


=cut

sub get_domain_type {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return 'kvm';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_disk_driver_name

 Parameters  : none
 Returns     : string
 Description : Returns 'qemu'. The disk driver name is specified in the domain
               XML definition:
                  <domain ...>
                     <devices>
                        <disk ...>
                           <driver name='qemu' ...>

=cut

sub get_disk_driver_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return 'qemu';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_disk_format

 Parameters  : none
 Returns     : string
 Description : Returns 'qcow2'. The disk format is specified in the domain XML
               definition:
                  <domain ...>
                     <devices>
                        <disk ...>
                           <driver type='qcow2' ...>

=cut

sub get_disk_format {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return 'qcow2';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_disk_file_extension

 Parameters  : none
 Returns     : string
 Description : Returns 'qcow2'. This is used by libvirt.pm as the file extension
               of the virtual disk file paths.

=cut

sub get_disk_file_extension {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return 'qcow2';
}

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_define

 Parameters  : none
 Returns     : boolean
 Description : Performs the KVM-specific steps prior to defining a domain:
               * Checks if the master image file exists on the node, If it does
                 not exist, attempts to copy image from repository to the node
               * Creates a copy on write image which will be used by the domain
                 being loaded

=cut

sub pre_define {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	my $node_name = $self->data->get_vmhost_short_name();
	my $copy_on_write_file_path = $self->get_copy_on_write_file_path();
	my $master_image_file_path = $self->get_master_image_file_path();

	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "master image file exists in the datastore on $node_name: $master_image_file_path");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "master image file does NOT exist in the datastore on $node_name: $master_image_file_path");
		
		# Check the files found in the repository
		# Attempt to determine which files are actual virtual disk files
		my @repository_image_file_paths = $self->find_repository_image_file_paths();
		if (@repository_image_file_paths) {
			# Attempt to copy the virtual disk from the repository to the datastore
			if ($self->copy_virtual_disk(\@repository_image_file_paths, $master_image_file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "copied master image from repository to datastore");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to prepare virtual disk, failed to copy master image from repository to datastore");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to prepare virtual disk, failed to locate virtual disk file in the repository");
			return;
		}
	}
	
	if (!$self->create_copy_on_write_image($master_image_file_path, $copy_on_write_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to prepare virtual disk, unable to create copy on write image");
		return;
	}
	
	return 1;
}

##############################################################################

=head1 PRIVATE METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_virtual_disk_file_info

 Parameters  : $virtual_disk_file_path
 Returns     : hash reference
 Description : Calls 'qemu-img info' to retrieve the virtual disk information.
               Builds a hash based on the output. Example:
                  "backing_file" => "/var/lib/libvirt/images/vmwarewinxp-base234-v23.qcow2 (actual path: /var/lib/libvirt/images/vmwarewinxp-base234-v23.qcow2)",
                  "backing_file_actual_path" => "/var/lib/libvirt/images/vmwarewinxp-base234-v23.qcow2",
                  "cluster_size" => 65536,
                  "disk_size" => "423M",
                  "disk_size_bytes" => 443547648,
                  "file_format" => "qcow2",
                  "image" => "/var/lib/libvirt/images/vclv99-37_234-v23.qcow2",
                  "snapshot" => {
                    1 => {
                      "date" => "2011-12-07 14:43:12",
                      "tag" => "snap1",
                      "vm_clock" => "00:00:00.000",
                      "vm_size" => 0
                    }
                  },
                  "virtual_size" => "20G (21474836480 bytes)",
                  "virtual_size_bytes" => "21474836480"

=cut

sub get_virtual_disk_file_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $virtual_disk_file_path = shift;
	if (!$virtual_disk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image info, file path argument was not supplied");
		return;
	}
	
	# Return cached copy of virtual disk file info if it exists
	return $self->{virtual_disk_file_info}{$virtual_disk_file_path} if defined($self->{virtual_disk_file_info}{$virtual_disk_file_path});
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $command = "qemu-img info \"$virtual_disk_file_path\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve image info on $node_name");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve image info on $node_name, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved image info, output:\n" . join("\n", @$output));
		
		my $virtual_disk_file_info;
		for my $line (@$output) {
			# Output example:
			#    image: vclv99-37_234-v23.qcow2
			#    file format: qcow2
			#    virtual size: 20G (21474836480 bytes)
			#    disk size: 423M
			#    cluster_size: 65536
			#    backing file: /var/lib/libvirt/images/vmwarewinxp-base234-v23.qcow2 (actual path: /var/lib/libvirt/images/vmwarewinxp-base234-v23.qcow2)
			#    Snapshot list:
			#    ID        TAG                 VM SIZE                DATE       VM CLOCK
			#    1         snap1                     0 2011-12-07 14:43:12   00:00:00.000
			
			# Skip the 'Snapshot list:' and snapshot header lines
			if ($line =~ /^(Snapshot list|ID)/i) {
				next;
			}
			#                  ID      TAG    SIZE    DATE                  CLOCK
			elsif ($line =~ /^(\d+)\s+(.+)\s+(\d+)\s+([\d\-:\.]+ [\d:]+)\s+([\d:\.]+)/g) {
				my $id = $1;
				my $tag = $2;
				my $vm_size = $3;
				my $date = $4;
				my $vm_clock = $5;
				
				# Remove trailing spaces from the tag
				$tag =~ s/\s+$//;
				
				$virtual_disk_file_info->{snapshot}{$id} = {
					'tag' => $tag,
					'vm_size' => $vm_size,
					'date' => $date,
					'vm_clock' => $vm_clock,
				};
			}
			elsif ($line =~ /([\w_ ]+):\s*(.+)/) {
				my $property = $1;
				my $value = $2;
				
				if ($property =~ /disk size/i) {
					# Calculate the number of bytes from the "disk size" line:
					# "disk_size" => "16K",
					# "disk_size" => "2.7M",
					
					my $disk_size_bytes;
					my ($disk_size, $units) = $value =~ /([\d\.]+)(\w)/;
					
					if ($units =~ /K/) {
						$disk_size_bytes = ($disk_size * 1024 ** 1);
					}
					elsif ($units =~ /M/) {
						$disk_size_bytes = ($disk_size * 1024 ** 2);
					}
					elsif ($units =~ /G/) {
						$disk_size_bytes = ($disk_size * 1024 ** 3);
					}
					elsif ($units =~ /T/) {
						$disk_size_bytes = ($disk_size * 1024 ** 4);
					}
					else {
						$disk_size_bytes = $disk_size;
					}
					
					$virtual_disk_file_info->{disk_size_bytes} = int($disk_size_bytes);
				}
				elsif ($property =~ /virtual size/i) {
					# Extract the number of bytes from the "virtual size" line:
					# "virtual_size" => "15M (15728640 bytes)"
					my ($virtual_size_bytes) = $value =~ /(\d+) bytes/;
					$virtual_disk_file_info->{virtual_size_bytes} = $virtual_size_bytes;
				}
				elsif ($property =~ /backing file/i) {
					# Extract the actual path from the "backing file" line:
					my ($actual_path) = $value =~ /actual path: ([^\)]+)/;
					$virtual_disk_file_info->{backing_file_actual_path} = $actual_path;
				}
				
				$property = lc($property);
				$property =~ s/\s+/_/g;
				$virtual_disk_file_info->{$property} = $value;
			}
		}
		
		notify($ERRORS{'DEBUG'}, 0, "retrieved virtual disk file info:\n" . format_data($virtual_disk_file_info));
		$self->{virtual_disk_file_info}{$virtual_disk_file_path} = $virtual_disk_file_info;
		return $virtual_disk_file_info;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2  get_virtual_disk_size_bytes

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Returns the size of the virtual disk in bytes.

=cut

sub get_virtual_disk_size_bytes {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		$image_name = $self->data->get_image_name() || return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Check if the virtual disk image files reside in the repository
	my @virtual_disk_file_paths;
	
	# Check if the virtual disk image resides in the datastore
	my $master_image_file_path = $self->get_master_image_file_path();

	# Check if the virtual disk exists on the VM host
	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		@virtual_disk_file_paths = ($master_image_file_path);
	}
	else {
		@virtual_disk_file_paths = $self->find_repository_image_file_paths();
		
		if (!@virtual_disk_file_paths) {
			notify($ERRORS{'WARNING'}, 0, "virtual disk for image $image_name does not exist in repository or datastore on $node_name");
			return;
		}
	}
	
	my $total_used_bytes;
	my $total_reserved_bytes;
	my $total_virtual_bytes;
	
	for my $virtual_disk_file_path (@virtual_disk_file_paths) {
		# Get the bytes used from the VM host OS's 'du' command
		my ($used_bytes, $reserved_bytes) = $self->vmhost_os->get_file_size($virtual_disk_file_path);
		$total_used_bytes += $used_bytes;
		$total_reserved_bytes += $reserved_bytes;
		
		# Attempt to retrieve the virtual disk file info
		# get_virtual_disk_file_info will return false if it is unable to retrieve info for the file
		my $virtual_disk_file_info = $self->get_virtual_disk_file_info($virtual_disk_file_path);
		
		if ($virtual_disk_file_info) {
			my $virtual_bytes = $virtual_disk_file_info->{virtual_size_bytes};
			$total_virtual_bytes += $virtual_bytes;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine virtual disk size, information could not be retrieved for virtual disk file: $virtual_disk_file_path");
			return;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "size of $image_name image:\n" .
			 "used: " . get_file_size_info_string($total_used_bytes) . "\n" .
			 "reserved: " . get_file_size_info_string($total_reserved_bytes) . "\n" .
			 "virtual: " . get_file_size_info_string($total_virtual_bytes)
			 );
	
	if (wantarray) {
		return ($total_used_bytes, $total_reserved_bytes, $total_virtual_bytes);
	}
	else {
		return $total_reserved_bytes;
	}
	
} ## end sub get_virtual_disk_size_bytes

#/////////////////////////////////////////////////////////////////////////////

=head2 copy_virtual_disk

 Parameters  : $source_file_paths, $destination_file_path, $disk_format (optional)
 Returns     : boolean
 Description : Calls qemu-img to copy a virtual disk image. The destination disk
               format can be specified as an argument. If omitted, qcow2 is
               used.

=cut

sub copy_virtual_disk {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($source_file_paths, $destination_file_path, $disk_format) = @_;
	
	if (!$source_file_paths || !$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, source and destination file path arguments were not passed");
		return;
	}
	elsif (ref($source_file_paths)) {
		if (ref($source_file_paths) ne 'ARRAY') {
			notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, source file path argument was passed as a reference by reference type is not ARRAY");
			return;
		}
		else {
			# Join the array of file paths into a string
			$source_file_paths = join('" "', @$source_file_paths);
		}
	}
	
	if (!$disk_format) {
		$disk_format = $self->get_disk_format();
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	my $image_os_type = $self->data->get_image_os_type();
	
	my $source_size_bytes = $self->get_image_size_bytes() || 0;
	
	# Get a semaphore so that multiple processes don't try to copy the image at the same time
	my $semaphore_id = "$node_name:$destination_file_path";
	my $semaphore_timeout_minutes = 60;
	my $semaphore = $self->get_semaphore($semaphore_id, (60 * $semaphore_timeout_minutes), 5) || return;
	
	my $start_time = time;
	my $command = "qemu-img convert -O $disk_format -o preallocation=metadata \"$source_file_paths\" \"$destination_file_path\"";
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy/convert virtual disk:\nsource file path(s):\n" . join("\n", split(/" "/, $source_file_paths)) . "\ndestination file path: $destination_file_path\ndestination disk format: $disk_format\nsource image size: " . get_file_size_info_string($source_size_bytes));
	my ($exit_status, $output) = $self->vmhost_os->execute($command, 0, 1800);
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to convert image $node_name: '$command'");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy/convert virtual disk on $node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "copied/converted virtual disk on $node_name, command: '$command', output:\n" . join("\n", @$output));
	}
	
	# Calculate how long it took to copy
	my $duration_seconds = (time - $start_time);
	my $minutes = ($duration_seconds / 60);
	$minutes =~ s/\..*//g;
	my $seconds = ($duration_seconds - ($minutes * 60));
	if (length($seconds) == 0) {
		$seconds = "00";
	}
	elsif (length($seconds) == 1) {
		$seconds = "0$seconds";
	}
	
	my $image_size_bytes = $self->vmhost_os->get_file_size($destination_file_path);
	
	# Get a string which displays various copy rate information
	my $copy_speed_info_string = get_copy_speed_info_string($image_size_bytes, $duration_seconds);
	notify($ERRORS{'OK'}, 0, "copied image on $node_name: $destination_file_path'\n$copy_speed_info_string");
	
	# Update the registry if this is a Windows image
	if ($image_os_type =~ /windows/i && !$self->update_windows_image($destination_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to make Windows-specific changes to $destination_file_path after it was copied/converted");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_copy_on_write_image

 Parameters  : $master_image_file_path, $copy_on_write_file_path
 Returns     : boolean
 Description : Calls qemu-img to create a copy on write virtual disk image based
               on the master image. The resulting image is written to by the VM
               when it makes changes to its hard disk. Multiple VMs may utilize
               the master image file. Each writes to its own copy on write image
               file. The master image file is not altered.

=cut

sub create_copy_on_write_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($master_image_file_path, $copy_on_write_file_path, $disk_format) = @_;
	
	if (!$master_image_file_path || !$copy_on_write_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to create copy on write image, master and copy on write image file path arguments were not passed");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	if (!$disk_format) {
		$disk_format = $self->get_disk_format();
	}
	
	notify($ERRORS{'DEBUG'}, 0, "creating copy on write image on $node_name\nmaster disk image: $master_image_file_path\ncopy on write image: $copy_on_write_file_path\nformat: $disk_format");
	my $command = "qemu-img create -f $disk_format -b \"$master_image_file_path\" \"$copy_on_write_file_path\"";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to create copy on write image on $node_name: '$command'");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to create copy on write image on $node_name, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "created copy on write image: $copy_on_write_file_path, output:\n" . join("\n", @$output));
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_windows_image

 Parameters  : $virtual_disk_file_path
 Returns     : boolean
 Description : Runs virt-win-reg to update the registry of the image specified
               by the $virtual_disk_file_path argument. The virt-win-reg utility
               is provided by libguestfs-tools. This subroutine returns true if
               virt-win-reg isn't installed.
               
               Adds registry keys to disable VMware services. If the image is
               Windows 5.x, registry keys are added to enable the builtin IDE
               drivers. This allows Windows images converted from VMware using a
               SCSI virtual disk to be loaded on KVM.

=cut

sub update_windows_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	my $virtual_disk_file_path = shift;
	if (!$virtual_disk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "virtual disk file path argument was not supplied");
		return;	
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Construct a string containing .reg file contents
	# Add keys to disable VMware services if they are installed
	my $registry_contents .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\VClone]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\vmci]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\vmmouse]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\vmscsi]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\VMTools]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\vmx_svga]
"Start"=dword:00000004

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\vmxnet]
"Start"=dword:00000004
EOF
	
	# Check if the guest OS module is for Windows 5.x
	# Add registry entries to enable the Windows IDE drivers
	if ($self->os->isa('VCL::Module::OS::Windows::Version_5')) {
		notify($ERRORS{'DEBUG'}, 0, "guest OS is Windows 5.x, adding registry keys to enable IDE drivers");
		$registry_contents .= <<'EOF';

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\primary_ide_channel]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="atapi"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\secondary_ide_channel]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="atapi"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\*pnp0600]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="atapi"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\gendisk]
"ClassGUID"="{4D36E967-E325-11CE-BFC1-08002BE10318}"
"Service"="disk"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#cc_0101]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_0e11&dev_ae33]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1039&dev_0601]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1039&dev_5513]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1042&dev_1000]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_105a&dev_4d33]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0640]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0646]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0646&REV_05]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0646&REV_07]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0648]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1095&dev_0649]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1097&dev_0038]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_10ad&dev_0001]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_10ad&dev_0150]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_10b9&dev_5215]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_10b9&dev_5219]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_10b9&dev_5229]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="pciide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_1106&dev_0571]
"Service"="pciide"
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_1222]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_1230]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_2411]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_2421]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_7010]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_7111]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\CriticalDeviceDatabase\pci#ven_8086&dev_7199]
"ClassGUID"="{4D36E96A-E325-11CE-BFC1-08002BE10318}"
"Service"="intelide"

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\atapi]
"ErrorControl"=dword:00000001
"Group"="SCSI miniport"
"Start"=dword:00000000
"Tag"=dword:00000019
"Type"=dword:00000001
"DisplayName"="Standard IDE/ESDI Hard Disk Controller"
"ImagePath"=hex(2):53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,44,00,\ 
  52,00,49,00,56,00,45,00,52,00,53,00,5c,00,61,00,74,00,61,00,70,00,69,00,2e,\ 
  00,73,00,79,00,73,00,00,00

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\IntelIde]
"ErrorControl"=dword:00000001
"Group"="System Bus Extender"
"Start"=dword:00000000
"Tag"=dword:00000004
"Type"=dword:00000001
"ImagePath"=hex(2):53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,44,00,\ 
  52,00,49,00,56,00,45,00,52,00,53,00,5c,00,69,00,6e,00,74,00,65,00,6c,00,69,\ 
  00,64,00,65,00,2e,00,73,00,79,00,73,00,00,00

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\PCIIde]
"ErrorControl"=dword:00000001
"Group"="System Bus Extender"
"Start"=dword:00000000
"Tag"=dword:00000003
"Type"=dword:00000001
"ImagePath"=hex(2):53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,44,00,\ 
  52,00,49,00,56,00,45,00,52,00,53,00,5c,00,70,00,63,00,69,00,69,00,64,00,65,\ 
  00,2e,00,73,00,79,00,73,00,00,00
EOF
	}
	
	# Create a text file on the VM host containing the registry contents
	my $virtual_disk_file_base_name = fileparse($virtual_disk_file_path, qr/\.[^\.]*$/i);
	my $temp_reg_file_path = "/tmp/$virtual_disk_file_base_name.reg";
	if (!$self->vmhost_os->create_text_file($temp_reg_file_path, $registry_contents)) {
		return;
	}
	
	# Attempt to run virt-win-reg to merge the registry contents into the registry on the virtual disk
	notify($ERRORS{'DEBUG'}, 0, "attempting to merge $temp_reg_file_path into $virtual_disk_file_path");
	my ($exit_status, $output) = $self->vmhost_os->execute("virt-win-reg --merge $virtual_disk_file_path $temp_reg_file_path");
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to merge $temp_reg_file_path into $virtual_disk_file_path");
		return;
	}
	elsif (grep(/command not found/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "unable to merge $temp_reg_file_path into $virtual_disk_file_path, virt-win-reg is not installed on $node_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to merge $temp_reg_file_path into $virtual_disk_file_path, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "merged $temp_reg_file_path into $virtual_disk_file_path");
	}
	
	# Delete the temporary registry file on the VM host
	$self->vmhost_os->delete_file($temp_reg_file_path);
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
