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

###############################################################################
package VCL::Module::Provisioning::libvirt::KVM;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::libvirt);

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
	
	# Check to see if required commands exist on the VM host
	my @test_commands = (
		'virsh',
		'qemu-img',
		'virt-win-reg',
	);
	
	my @missing_commands;
	for my $command (@test_commands) {
		my ($exit_status, $output) = $self->vmhost_os->execute("which $command");
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "unable to initialize $driver_name driver module to control $node_name, failed to execute command to determine if the '$command' command is available");
			return;
		}
		elsif (grep(/(which:|no $command)/, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "'$command' command is NOT available on $node_name");
			push @missing_commands, $command;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "verified '$command' command is available on $node_name");
		}
	}
	
	if (@missing_commands) {
		notify($ERRORS{'DEBUG'}, 0, "unable to initialize $driver_name driver module to control $node_name, the following commands are not available:\n" . join("\n", @missing_commands));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$driver_name driver module successfully initialized to control $node_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	my $image_os_type = $self->data->get_image_os_type();
	my $node_name = $self->data->get_vmhost_short_name();
	my $copy_on_write_file_path = $self->get_copy_on_write_file_path();
	my $master_image_file_path = $self->get_master_image_file_path();
	my $datastore_image_type = $self->data->get_vmhost_datastore_imagetype_name();

	if ($self->vmhost_os->file_exists($master_image_file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "master image file exists in the datastore on $node_name: $master_image_file_path");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "master image file does NOT exist in the datastore on $node_name: $master_image_file_path");
		
		# Check the files found in the repository
		# Attempt to determine which files are actual virtual disk files
		my @repository_image_file_paths = $self->find_repository_image_file_paths();
		if (@repository_image_file_paths) {
			# Get a semaphore so that no other process can access this master image until the copy is complete
			# Don't need a repository image semaphore - impossible that another process is copying it to the repository
			# find_repository_image_file_paths must have successfully obtained one
			if (my $semaphore = $self->get_master_image_semaphore()) {
				# Attempt to copy the virtual disk from the repository to the datastore
				if ($self->copy_virtual_disk(\@repository_image_file_paths, $master_image_file_path, $datastore_image_type)) {
					notify($ERRORS{'DEBUG'}, 0, "copied master image from repository to datastore");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "failed to copy master image from repository:\n" . join("\n", @repository_image_file_paths) . " --> $master_image_file_path");
					return;
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to prepare virtual disk, failed to obtain repository image semaphore before creating master image from repository image:\n" . join("\n", @repository_image_file_paths) . " --> $master_image_file_path");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to prepare virtual disk, master image file could NOT be located, it does not exist in the datastore and node $node_name is not configured to use an image repository");
			return;
		}
		
		# Update the registry if this is a Windows image
		# This allows VMware images to run on KVM using an IDE disk
		if ($image_os_type =~ /windows/i && !$self->update_windows_image($master_image_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to make Windows-specific changes to $master_image_file_path after it was copied/converted");
			return;
		}
	}
	
	
	if ($datastore_image_type =~ /^qcow2?$/) {
		# Create a copy on write image which will be used by the VM being loaded
		# This effectively makes the master image read only, all changes are written to the copy on write image
		if (!$self->create_copy_on_write_image($master_image_file_path, $copy_on_write_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to prepare virtual disk, unable to create copy on write image");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "copy on write virtual disk is not supported for the datastore image type: $datastore_image_type, creating full copy of master image file");
		if (!$self->copy_virtual_disk($master_image_file_path, $copy_on_write_file_path, $datastore_image_type)) {
			notify($ERRORS{'WARNING'}, 0, "failed to prepare virtual disk, unable to create $datastore_image_type copy of master image: $master_image_file_path --> $copy_on_write_file_path");
			return;
		}
	}
	
	return 1;
}

###############################################################################

=head1 PRIVATE METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
		#notify($ERRORS{'DEBUG'}, 0, "retrieved image info, output:\n" . join("\n", @$output));
		
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
		
		#notify($ERRORS{'DEBUG'}, 0, "retrieved virtual disk file info:\n" . format_data($virtual_disk_file_info));
		$self->{virtual_disk_file_info}{$virtual_disk_file_path} = $virtual_disk_file_info;
		return $virtual_disk_file_info;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2  get_virtual_disk_size_bytes

 Parameters  : @virtual_disk_file_paths
 Returns     : integer
 Description : Returns the size of the virtual disk in bytes.

=cut

sub get_virtual_disk_size_bytes {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to get the argument
	my @virtual_disk_file_paths = @_;
	if (!@virtual_disk_file_paths) {
		notify($ERRORS{'WARNING'}, 0, "virtual disk file paths argument was not supplied");
		return;
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	my $virtual_disk_size_bytes = 0;
	for my $virtual_disk_file_path (@virtual_disk_file_paths) {
		# Attempt to retrieve the virtual disk file info
		my $virtual_disk_file_info = $self->get_virtual_disk_file_info($virtual_disk_file_path);
		if (!$virtual_disk_file_info) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine virtual disk size, information could not be retrieved for virtual disk file: $virtual_disk_file_path");
			return;
		}
		
		$virtual_disk_size_bytes += $virtual_disk_file_info->{disk_size_bytes};
		
		# Check if virtual disk has a backing file, size of both must be added
		if ($virtual_disk_file_info->{backing_file_actual_path}) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve size of virtual disk backing file: $virtual_disk_file_info->{backing_file_actual_path}");		
			my $backing_file_size_bytes = $self->get_virtual_disk_size_bytes($virtual_disk_file_info->{backing_file_actual_path});
			if (!$backing_file_size_bytes) {
				notify($ERRORS{'WARNING'}, 0, "unable to determine size of virtual disk: $virtual_disk_file_path, failed to determine size of backing file: $virtual_disk_file_info->{backing_file_actual_path}");
				return;
			}
			
			# Note: added total size is not accurate, it is larger than the actual size
			$virtual_disk_size_bytes += $backing_file_size_bytes;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved size of virtual disk:\n" . join("\n", @virtual_disk_file_paths) . "\n" . get_file_size_info_string($virtual_disk_size_bytes));
	return $virtual_disk_size_bytes;
} ## end sub get_virtual_disk_size_bytes

#//////////////////////////////////////////////////////////////////////////////

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
	
	my $source_file_path_argument = shift;
	my $destination_file_path = shift;
	if (!$source_file_path_argument || !$destination_file_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, source and destination file path arguments were not passed");
		return;
	}
	
	my @source_file_paths;
	if (!ref($source_file_path_argument)) {
		push @source_file_paths, $source_file_path_argument;
	}
	elsif (ref($source_file_path_argument) eq 'ARRAY') {
		@source_file_paths = @$source_file_path_argument;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, source file path argument was passed as a reference and type is not ARRAY");
		return;
	}
	
	# Get the disk format argument
	my $disk_format = shift || $self->data->get_vmhost_datastore_imagetype_name();
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# Get the size of all of the source files
	my $source_size_bytes = $self->get_virtual_disk_size_bytes(@source_file_paths) || 0;
	
	# Make sure the destination file extension matches the disk format
	my ($destination_file_name, $destination_directory_path, $destination_file_extension) = fileparse($destination_file_path, qr/\.[^.]*/);
	if (!$destination_file_extension) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, file extension could not be determined from destination file path: $destination_file_path");
		return;
	}
	elsif ($destination_file_extension !~ /^\.?$disk_format$/i) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, extension of destination file '$destination_file_extension' is not '$disk_format': $destination_file_path");
		return;
	}
	
	# Remove trailing space from directory path
	$destination_directory_path =~ s/\/+$//;
	
	# Attempt to create the parent directory
	if (!$self->vmhost_os->create_directory($destination_directory_path)) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, failed to create destination parent directory: $destination_directory_path");
		return;
	}
	
	# Copy the XML file if it exists (saved 'virsh dumpxml' from image capture)
	my ($source_file_name, $source_directory_path, $source_file_extension) = fileparse($source_file_paths[0], qr/\.[^.]*/);
	my $source_xml_file_path = "$source_directory_path/$source_file_name.xml";
	if ($self->vmhost_os->file_exists($source_xml_file_path)) {
		my $destination_xml_file_path = "$destination_directory_path/$destination_file_name.xml";
		$self->vmhost_os->copy_file($source_xml_file_path, $destination_xml_file_path)
	}
	
	my $source_file_count = scalar(@source_file_paths);
	my $source_file_paths_string;
	my $raw_file_directory_path;
	
	# Check if the source file paths appear to be in the 2GB sparse vmdk format
	# qemu-img included in anything earlier than Fedora 16 doesn't handle this properly
	#if ($source_file_count > 1 && $source_file_paths[0] =~ /-s\d+\.vmdk$/i) {
	#	my $image_name = $self->data->get_image_name();
	#	$raw_file_directory_path = "$destination_directory_path/raw_$image_name";
	#	
	#	# Attempt to create the directory where the raw files will be stored
	#	if (!$self->vmhost_os->create_directory($raw_file_directory_path)) {
	#		notify($ERRORS{'WARNING'}, 0, "unable to copy virtual disk, failed to create temporary directory to store raw files: $raw_file_directory_path");
	#		return;
	#	}
	#	
	#	for my $source_file_path (@source_file_paths) {
	#		my ($source_file_name, $source_directory_path, $source_file_extension) = fileparse($source_file_path, qr/\.[^.]*/);
	#		
	#		my $raw_file_path = "$raw_file_directory_path/$source_file_name.raw";
	#		$source_file_paths_string .= "\"$raw_file_path\" ";
	#		
	#		## Convert from raw to raw
	#		## There seems to be a bug in qemu-img if you specify "-f vmdk", it results in a empty file
	#		## Leaving the -f option off also results in an empty file
	#		#my $command = "qemu-img convert -f raw \"$source_file_path\" -O raw \"$raw_file_path\" && qemu-img info \"$raw_file_path\"";
	#		#notify($ERRORS{'DEBUG'}, 0, "attempting to convert vmdk file to raw format: $source_file_path --> $raw_file_path, command:\n$command");
	#		#my ($exit_status, $output) = $self->vmhost_os->execute($command, 0, 7200);
	#		#if (!defined($exit_status)) {
	#		#	notify($ERRORS{'WARNING'}, 0, "failed to execute command to convert vmdk file to raw format:\n$command");
	#		#	return;
	#		#}
	#		#elsif ($exit_status) {
	#		#	notify($ERRORS{'WARNING'}, 0, "failed to convert vmdk file to raw format on $node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	#		#	return;
	#		#}
	#		#else {
	#		#	notify($ERRORS{'DEBUG'}, 0, "converted vmdk file to raw format on $node_name: $source_file_path --> $raw_file_path\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	#		#}
	#	}
	#	
	#	# Remove trailing last space
	#	$source_file_paths_string =~ s/\s+$//;
	#	
	#	#my $raw_file_path_merged = "$raw_file_directory_path/$image_name.raw";
	#	#my $cat_command = "cat $source_file_paths_string > \"$raw_file_path_merged\"";
	#	#notify($ERRORS{'DEBUG'}, 0, "attempting to merge split raw files into $raw_file_path_merged, command:\n$cat_command");
	#	#my ($cat_exit_status, $cat_output) = $self->vmhost_os->execute($cat_command, 0, 7200);
	#	#if (!defined($cat_exit_status)) {
	#	#	notify($ERRORS{'WARNING'}, 0, "failed to execute command to merge split raw files into $raw_file_path_merged, command: $cat_command");
	#	#	return;
	#	#}
	#	#elsif ($cat_exit_status) {
	#	#	notify($ERRORS{'WARNING'}, 0, "failed to convert merge split raw files into $raw_file_path_merged\ncommand: '$cat_command'\noutput:\n" . join("\n", @$cat_output));
	#	#	return;
	#	#}
	#	#else {
	#	#	notify($ERRORS{'DEBUG'}, 0, "merged split raw files into $raw_file_path_merged\ncommand: '$cat_command'\noutput:\n" . join("\n", @$cat_output));
	#	#	$source_file_paths_string = "\"$raw_file_path_merged\"";
	#	#}
	#}
	#else {
		# Join the array of file paths into a string
		$source_file_paths_string = '"' . join('" "', @source_file_paths) . '"';
	#}
	
	my $options = '';
	# VCL-911: If copying to the repository, save the image qcow2 version 0.10, the traditional image format that can be read by any QEMU since 0.10
	my $repository_image_file_path = $self->get_repository_image_file_path();
	if ($destination_file_path eq $repository_image_file_path) {
		$options .= ' -o compat=0.10';
	}
	
	#my $command = "qemu-img convert -f vmdk -O $disk_format $source_file_paths_string \"$destination_file_path\" && qemu-img info \"$destination_file_path\"";
	my $command = "qemu-img convert $source_file_paths_string -O $disk_format";
	$command .= $options;
	$command .= " \"$destination_file_path\"";
	$command .= " && qemu-img info \"$destination_file_path\"";

	## If the image had to be converted to raw format first, add command to delete raw files
	#if ($raw_file_directory_path) {
	#	$command .= " ; rm -f $raw_file_directory_path";
	#}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to copy/convert virtual disk to $disk_format format --> $destination_file_path, command:\n$command");
	
	my $start_time = time;
	my ($exit_status, $output) = $self->vmhost_os->execute($command, 0, 7200);
	if (defined($output && grep(/Unknown option.*compat/, @$output))) {
		# Check for older versions which don't support '-o compat=':
		#    Unknown option 'compat'
		#    qemu-img: Invalid options for file format 'qcow2'.
		# Remove the option from the command and try again
		$command =~ s/ -o compat=0.10//;
		notify($ERRORS{'DEBUG'}, 0, "version of qemu-img on $node_name does not appear to support the '-o compat=' option, trying again without it, output from first attempt:\n" . join("\n", @$output));
		($exit_status, $output) = $self->vmhost_os->execute($command, 0, 7200);
	}
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to copy/convert virtual disk on $node_name:\n$command");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy/convert virtual disk on $node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
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
	
	my $destination_size_bytes = $self->get_virtual_disk_size_bytes($destination_file_path) || 0;
	
	# Get a string which displays various copy rate information
	my $copy_speed_info_string = get_copy_speed_info_string($destination_size_bytes, $duration_seconds);
	
	notify($ERRORS{'OK'}, 0, "copied virtual disk on $node_name, output:\n" . join("\n", @$output) . "\n---\n$copy_speed_info_string");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

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
		$disk_format = $self->data->get_vmhost_datastore_imagetype_name();
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

#//////////////////////////////////////////////////////////////////////////////

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
	my $command = "virt-win-reg --merge $virtual_disk_file_path $temp_reg_file_path";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to merge $temp_reg_file_path into $virtual_disk_file_path");
		return;
	}
	elsif (grep(/command not found/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "unable to merge $temp_reg_file_path into $virtual_disk_file_path, virt-win-reg is not installed on $node_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to merge $temp_reg_file_path into $virtual_disk_file_path, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "merged $temp_reg_file_path into $virtual_disk_file_path");
	}
	
	# Delete the temporary registry file on the VM host
	$self->vmhost_os->delete_file($temp_reg_file_path);
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 query_windows_image_registry

 Parameters  : $virtual_disk_file_path
 Returns     : boolean
 Description : 

=cut

sub query_windows_image_registry {
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
	
	my $registry_key = shift;
	if (!$registry_key) {
		notify($ERRORS{'WARNING'}, 0, "registry key argument was not supplied");
		return;	
	}
	
	my $node_name = $self->data->get_vmhost_short_name();
	
	# 
	notify($ERRORS{'DEBUG'}, 0, "attempting to query registry key '$registry_key' in image '$virtual_disk_file_path'");
	my $command = "virt-win-reg $virtual_disk_file_path \"$registry_key\"";
	my ($exit_status, $output) = $self->vmhost_os->execute("virt-win-reg $virtual_disk_file_path \"$registry_key\"");
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to query registry key '$registry_key' in image '$virtual_disk_file_path'");
		return;
	}
	elsif (grep(/command not found/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "unable to query registry key in $virtual_disk_file_path, virt-win-reg is not installed on $node_name");
		return 1;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to query registry key '$registry_key' in image '$virtual_disk_file_path', exit status: $exit_status\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my $registry_data = {};
	my $current_key;
	LINE: for my $line (@$output) {
		if ($line =~ /^\[(.+)\]$/) {
			$current_key = $1;
			next LINE;
		}
		elsif ($line =~ /^"([^"]+)"=([^:]+):(.*)$/) {
			my $value = $1;
			my $type = $2;
			my $data = $3;
			
			my $converted_data = $self->os->reg_query_convert_data($type, $data);

			$registry_data->{$current_key}{$value} = $converted_data;
			next LINE;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to parse virt-win-reg registry query output line: '$line'");
		}
	}
	
	notify($ERRORS{'OK'}, 0, "queried registry key '$registry_key' in image '$virtual_disk_file_path':\n" . format_data($registry_data));
	return $registry_data;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
