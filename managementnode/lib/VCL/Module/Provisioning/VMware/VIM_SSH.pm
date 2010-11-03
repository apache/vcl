#!/usr/bin/perl -w
###############################################################################
# $Id: VIM_SSH.pm 952366 2010-06-07 18:59:25Z arkurth $
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

VCL::Module::Provisioning::VMware::VIM_SSH;

=head1 SYNOPSIS

 my $vmhost_datastructure = $self->get_vmhost_datastructure();
 my $VIM_SSH = VCL::Module::Provisioning::VMware::VIM_SSH->new({data_structure => $vmhost_datastructure});
 my @registered_vms = $VIM_SSH->get_registered_vms();

=head1 DESCRIPTION

 This module provides support for the vSphere SDK. The vSphere SDK can be used
 to manage VMware Server 2.x, ESX 3.0.x, ESX/ESXi 3.5, ESX/ESXi 4.0, vCenter
 Server 2.5, and vCenter Server 4.0.

=cut

##############################################################################
package VCL::Module::Provisioning::VMware::VIM_SSH;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::VMware::VMware);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 PRIVATE OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Initializes the vSphere SDK object by establishing a connection
               to the VM host.

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $args  = shift;

	# 
	if (!defined $args->{vmhost_os}) {
		notify($ERRORS{'WARNING'}, 0, "required 'vmhost_os' argument was not passed");
		return;
	}

	# 
	if (ref $args->{vmhost_os} !~ /VCL::Module::OS/) {
		notify($ERRORS{'CRITICAL'}, 0, "'vmhost_os' argument passed is not a reference to a VCL::Module::OS object, type: " . ref($args->{vmhost_os}));
		return;
	}

	# 
	$self->{vmhost_os} = $args->{vmhost_os};
	
	if (!$self->vmhost_os) {
		return;
	}
	
	my @required_vmhost_os_subroutines = (
		'execute',
	);
	
	for my $required_vmhost_os_subroutine (@required_vmhost_os_subroutines) {
		if (!$self->vmhost_os->can($required_vmhost_os_subroutine)) {
			notify($ERRORS{'WARNING'}, 0, "required VM host OS subroutine is not implemented: $required_vmhost_os_subroutine");
			return;
		}
	}
	
	# Determine which VIM executable is installed on the VM host
	my $command = 'vim-cmd ; vmware-vim-cmd';
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'OK'}, 0, "VIM executable is not available on the VM host");
		return;
	}
	elsif (!grep(/vmsvc/, @$output)) {
		# String 'vmsvc' does not exist in the output, neither of the commands worked
		notify($ERRORS{'DEBUG'}, 0, "VIM executable is not available on the VM host, output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/: vim-cmd:.*not found/i, @$output)) {
		# Output contains the line: 'vim-cmd: command not found'
		$self->{vim_cmd} = 'vmware-vim-cmd';
	}
	elsif (grep(/: vmware-vim-cmd:.*not found/i, @$output)) {
		# Output contains the line: 'vmware-vim-cmd: command not found'
		$self->{vim_cmd} = 'vim-cmd';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to determine which VIM executable is available on the VM host, output:\n" . join("\n", @$output));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "VIM executable available on VM host: $self->{vim_cmd}");
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " object initialized");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _run_vim_cmd

 Parameters  : $vim_arguments
 Returns     : array ($exit_status, $output)
 Description : Runs VIM command on the VMware host.

=cut

sub _run_vim_cmd {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vim_arguments = shift;
	if (!$vim_arguments) {
		notify($ERRORS{'WARNING'}, 0, "VIM command arguments were not specified");
		return;
	}
	
	my $vmhost_computer_name = $self->vmhost_os->data->get_computer_short_name();
	
	my $command = "$self->{vim_cmd} $vim_arguments";
	
	my $attempt = 0;
	my $attempt_limit = 3;
	my $wait_seconds = 2;
	
	while ($attempt++ < $attempt_limit) {
		if ($attempt > 1) {
			# Wait before making next attempt
			notify($ERRORS{'OK'}, 0, "sleeping $wait_seconds seconds before making attempt $attempt/$attempt_limit");
			sleep $wait_seconds;
		}
		
		my ($exit_status, $output) = $self->vmhost_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to run VIM command on VM host $vmhost_computer_name: $command");
		}
		elsif (grep(/(failed to connect|error connecting)/i, @$output)) {
			notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: failed to connect to VM host $vmhost_computer_name to run command: $command, output:\n" . join("\n", @$output));
		}
		else {
			# VIM command command was executed
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: executed command on VM host $vmhost_computer_name: $command") if ($attempt > 1);
			return ($exit_status, $output);
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to run VIM command on VM host $vmhost_computer_name: '$command', made $attempt_limit attempts");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_list

 Parameters  : none
 Returns     : hash
 Description : Returns an hash with keys containing the IDs of the VMs running
               on the VM host. The values are the vmx file paths.

=cut

sub _get_vm_list {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/getallvms";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Check the vim-cmd output
	# Format of the output from "vim-cmd vmsvc/getallvms":
	# Vmid Name                                                          File                                                              Guest OS        Version Annotation
	# 496  vm-ark-mcnc-9 (nonpersistent: vmwarewinxp-base234-v12)        [nfs-datastore] vm-ark-mcnc-9_234-v12/vm-ark-mcnc-9_234-v12.vmx   winXPProGuest   vmx-04      
	# 512  vm-ark-mcnc-10 (nonpersistent: vmwarelinux-centosbase1617-v1) [nfs-datastore] vm-ark-mcnc-10_1617-v1/vm-ark-mcnc-10_1617-v1.vmx otherLinuxGuest vmx-04
	if (!grep(/Vmid\s+Name/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM IDs, unexpected output returned, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	my %vms;
	for my $line (@$output) {
		my ($vm_id, $vmx_file_path) = $line =~ /^(\d+).*(\[.+\.vmx)/;
		
		# Skip lines that don't begin with a number
		next if !defined($vm_id);
		
		# Make sure the vmx file path was parsed
		if (!$vmx_file_path) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine vmx file path, VIM command arguments: '$vim_cmd_arguments', output line: $line");
			return;
		}
		
		# Get the normal path
		my $vmx_normal_path = $self->_get_normal_path($vmx_file_path);
		if (!$vmx_normal_path) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine normal path: $vmx_file_path");
			return;
		}
		
		$vms{$vm_id} = $vmx_normal_path;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "registered VMs IDs found: " . keys(%vms));
	return \%vms;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_id

 Parameters  : $vmx_file_path
 Returns     : integer
 Description : 

=cut

sub _get_vm_id {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not specified");
		return;
	}
	
	# Get the VM IDs and vmx paths
	my $vm_list = $self->_get_vm_list();
	
	for my $vm_id (keys %$vm_list) {
		return $vm_id if ($vmx_file_path eq $vm_list->{$vm_id});
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine VM ID, vmx file is not registered: $vmx_file_path, registered VMs:\n" . format_data($vm_list));
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_summary

 Parameters  : $vm_id
 Returns     : string
 Description : Runs "vim-cmd vmsvc/get.summary <VM ID>" to retrive a summary
               of the configuration of a VM.

=cut

sub _get_vm_summary {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vm_id = shift;
	if (!$vm_id) {
		notify($ERRORS{'WARNING'}, 0, "VM ID argument was not specified");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/get.summary $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The output should look like this:
	# Listsummary:
	# (vim.vm.Summary) {
	#   dynamicType = <unset>,
	#   vm = 'vim.VirtualMachine:496',
	#   runtime = (vim.vm.RuntimeInfo) {
	#      dynamicType = <unset>,
	#      host = 'vim.HostSystem:ha-host',
	#      connectionState = "connected",
	#      powerState = "poweredOn",
	#      faultToleranceState = "notConfigured",
	#      toolsInstallerMounted = false,
	#      suspendTime = <unset>,
	#      bootTime = "2010-06-08T14:26:48.658743Z",
	#      suspendInterval = 0,
	#      question = (vim.vm.QuestionInfo) null,
	#      memoryOverhead = 119189504,
	#      maxCpuUsage = 2000,
	#      maxMemoryUsage = 1024,
	#      numMksConnections = 0,
	#      recordReplayState = "inactive",
	#      cleanPowerOff = <unset>,
	#      needSecondaryReason = <unset>,
	#   },
	#   guest = (vim.vm.Summary.GuestSummary) {
	#      dynamicType = <unset>,
	#      guestId = "winXPProGuest",
	#      guestFullName = "Microsoft Windows XP Professional (32-bit)",
	#      toolsStatus = "toolsOld",
	#      toolsVersionStatus = "guestToolsNeedUpgrade",
	#      toolsRunningStatus = "guestToolsRunning",
	#      hostName = "APACHE-44896D77.dcs.mcnc.org",
	#      ipAddress = "152.46.16.235",
	#   },
	#   config = (vim.vm.Summary.ConfigSummary) {
	#      dynamicType = <unset>,
	#      name = "vm-ark-mcnc-9 (nonpersistent: vmwarewinxp-base234-v12)",
	#      template = false,
	#      vmPathName = "[nfs-datastore] vm-ark-mcnc-9_234-v12/vm-ark-mcnc-9_234-v12.vmx",
	#      memorySizeMB = 1024,
	#      cpuReservation = <unset>,
	#      memoryReservation = <unset>,
	#      numCpu = 1,
	#      numEthernetCards = 2,
	#      numVirtualDisks = 1,
	#      uuid = "564d36cf-6988-c91d-0f5f-a62628d46553",
	#      instanceUuid = "",
	#      guestId = "winXPProGuest",
	#      guestFullName = "Microsoft Windows XP Professional (32-bit)",
	#      annotation = "",
	#      product = (vim.vApp.ProductInfo) null,
	#      installBootRequired = <unset>,
	#      ftInfo = (vim.vm.FaultToleranceConfigInfo) null,
	#   },
	#   storage = (vim.vm.Summary.StorageSummary) {
	#      dynamicType = <unset>,
	#      committed = 4408509391,
	#      uncommitted = 11697668096,
	#      unshared = 4408509391,
	#      timestamp = "2010-06-08T14:26:30.312473Z",
	#   },
	#   quickStats = (vim.vm.Summary.QuickStats) {
	#      dynamicType = <unset>,
	#      overallCpuUsage = 20,
	#      overallCpuDemand = <unset>,
	#      guestMemoryUsage = 40,
	#      hostMemoryUsage = 652,
	#      guestHeartbeatStatus = "yellow",
	#      distributedCpuEntitlement = <unset>,
	#      distributedMemoryEntitlement = <unset>,
	#      staticCpuEntitlement = <unset>,
	#      staticMemoryEntitlement = <unset>,
	#      privateMemory = <unset>,
	#      sharedMemory = <unset>,
	#      swappedMemory = <unset>,
	#      balloonedMemory = <unset>,
	#      consumedOverheadMemory = <unset>,
	#      ftLogBandwidth = <unset>,
	#      ftSecondaryLatency = <unset>,
	#      ftLatencyStatus = <unset>,
	#   },
	#   overallStatus = "green",
	# }
	if (!grep(/vim\.vm\.Summary/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve VM summary, unexpected output returned, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	return $output;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_datastore_info

 Parameters  : none
 Returns     : hash reference
 Description : 

=cut

sub _get_datastore_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Return previously retrieved datastore name array if it is defined in this object
	if ($self->{datastore}) {
		return $self->{datastore};
	}
	
	my $vim_cmd_arguments = "hostsvc/datastore/listsummary";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The output should look like this:
	# (vim.Datastore.Summary) [
	#	(vim.Datastore.Summary) {
	#		dynamicType = <unset>,
	#		datastore = 'vim.Datastore:4bcf0efe-c426acc4-c7e1-001a644d1cc0',
	#		name = "local-datastore",
	#		url = "/vmfs/volumes/4bcf0efe-c426acc4-c7e1-001a644d1cc0",
	#		capacity = 31138512896,
	#		freeSpace = 26277314560,
	#		uncommitted = 0,
	#		accessible = true,
	#		multipleHostAccess = <unset>,
	#		type = "VMFS",
	#	},
	#	(vim.Datastore.Summary) {
	#		dynamicType = <unset>,
	#		datastore = 'vim.Datastore:10.25.0.245:/vmfs/volumes/nfs-datastore',
	#		name = "nfs-datastore",
	#		url = "/vmfs/volumes/95e378c2-863dd2b4",
	#		capacity = 975027175424,
	#		freeSpace = 108854874112,
	#		uncommitted = 0,
	#		accessible = true,
	#		multipleHostAccess = <unset>,
	#		type = "NFS",
	#	},
	# ]
	if (!grep(/vim\.Datastore\.Summary/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine datastore names, unexpected output returned, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	my $datastore_info;
	
	# Split the output into sections for each datastore
	my @output_sections = split(/vim\.Datastore\.Summary/i, join("\n", @$output));
	
	for my $output_section (@output_sections) {
		my ($datastore_name) = $output_section =~ /name\s*=\s*"(.+)"/;
		next if (!defined($datastore_name));
		
		for my $line (split(/[\r\n]+/, $output_section)) {
			# Skip lines which don't contain a '='
			next if $line !~ /=/;
			
			# Parse the line
			my ($parameter, $value) = $line =~ /^\s*(\w+)\s*=[\s"']*([^"',]+)/g;
			if (defined($parameter) && defined($value)) {
				$datastore_info->{$datastore_name}{$parameter} = $value if ($parameter ne 'name');
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to parse parameter and value from line: '$line'");
			}
		}
		
		# Add a 'normal_path' key to the hash based on the datastore url
		my $datastore_url = $datastore_info->{$datastore_name}{url};
		if (!defined($datastore_url)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine datastore url from 'vim-cmd $vim_cmd_arguments' output section, datastore name: $datastore_name:\n$output_section");
			next;
		}
		
		my $datastore_normal_path;
		if ($datastore_url =~ /^\/vmfs\/volumes/i) {
			$datastore_normal_path = "/vmfs/volumes/$datastore_name";
		}
		else {
			$datastore_normal_path = $datastore_url;
		}
		$datastore_info->{$datastore_name}{normal_path} = $datastore_normal_path;
	}

	return $datastore_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_task_id

 Parameters  : $vmx_file_path, $task_type
 Returns     : string
 Description : Returns the vim.Task string of the most recent task executed on
					the VM indicated by the $vm_id argument. The task type argument
					must be specified. Example task type values:
					powerOn
					powerOff
					registerVm
					unregisterVm

=cut

sub _get_task_id {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	# Get the task type argument
	my $task_type = shift;
	if (!$task_type) {
		notify($ERRORS{'WARNING'}, 0, "task type argument was not supplied");
		return;
	}
	
	my $vm_id = $self->_get_vm_id($vmx_file_path) || return;
	
	my $vim_cmd_arguments = "vmsvc/get.tasklist $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	# (ManagedObjectReference) [
	#   'vim.Task:haTask-512-vim.VirtualMachine.powerOn-2826',
	#   'vim.Task:haTask-512-vim.VirtualMachine.powerOn-2843',
	#   'vim.Task:haTask-512-vim.VirtualMachine.powerOn-2856'
	# ]
	
	if (!grep(/ManagedObjectReference/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to retrieve task list, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "task list output:\n" . join("\n", @$output));
	
	# Reverse the output array so the newest tasks are listed first
	my @reversed_output = reverse(@$output);
	
	#notify($ERRORS{'DEBUG'}, 0, "reversed task list output:\n" . join("\n", @reversed_output));
	
	my ($task_id) = grep(/haTask-$vm_id-.+$task_type-/, @reversed_output);
	
	# Check if a matching task was found
	if (!$task_id) {
		notify($ERRORS{'WARNING'}, 0, "no recent $task_type tasks for VM $vm_id, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	# Remove "vim.Task:" from the beginning of the task ID and the trailing single quote
	# This should not be included when passing the task ID to other vim-cmd functions
	$task_id =~ s/(^.*vim\.Task:|[^\d]*$)//ig;

	#notify($ERRORS{'DEBUG'}, 0, "task id: '$task_id'");
	return $task_id;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_task_info

 Parameters  : $task_id
 Returns     : array
 Description : 

=cut

sub _get_task_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the task ID path argument
	my $task_id = shift;
	if (!$task_id) {
		notify($ERRORS{'WARNING'}, 0, "task ID argument was not supplied");
		return;
	}
	
	my $vim_cmd_arguments = "vimsvc/task_info $task_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	# (vim.TaskInfo) {
	#   dynamicType = <unset>,
	#   key = "haTask-496-vim.VirtualMachine.powerOn-3072",
	#   task = 'vim.Task:haTask-496-vim.VirtualMachine.powerOn-3072',
	#   description = (vmodl.LocalizableMessage) null,
	#   name = "vim.VirtualMachine.powerOn",
	#   descriptionId = "VirtualMachine.powerOn",
	#   entity = 'vim.VirtualMachine:496',
	#   entityName = "vm-ark-mcnc-9 (nonpersistent: vmwarewinxp-base234-v12)",
	#   state = "error",
	#   cancelled = false,
	#   cancelable = false,
	#   error = (vmodl.fault.RequestCanceled) {
	#      dynamicType = <unset>,
	#      faultCause = (vmodl.MethodFault) null,
	#      msg = "The task was canceled by a user.",
	#   },
	#   result = <unset>,
	#   progress = 100,
	#   reason = (vim.TaskReasonUser) {
	#      dynamicType = <unset>,
	#      userName = "root",
	#   },
	#   queueTime = "2010-06-30T08:48:44.187347Z",
	#   startTime = "2010-06-30T08:48:44.187347Z",
	#   completeTime = "2010-06-30T08:49:26.381383Z",
	#   eventChainId = 3072,
	#   changeTag = <unset>,
	#   parentTaskKey = <unset>,
	#   rootTaskKey = <unset>,
	# }
	
	# Expected output if the task is not found:
	# (vmodl.fault.ManagedObjectNotFound) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   obj = 'vim.Task:haTask-496-vim.VirtualMachine.powerOn-3072x',
	#   msg = "The object has already been deleted or has not been completely created",
	# }

	
	if (grep(/ManagedObjectNotFound/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "task was not found: $task_id, output:\n" . join("\n", @$output));
		return;
	}
	elsif (!grep(/vim.TaskInfo/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to retrieve task list, VIM command arguments: '$vim_cmd_arguments' output:\n" . join("\n", @$output));
		return;
	}
	
	return @$output;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _wait_for_task

 Parameters  : $task_id, $timeout_seconds (optional)
 Returns     : boolean
 Description : Waits for the vim task to complete. Returns true if the task
               completes successfully.

=cut

sub _wait_for_task {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the task ID path argument
	my $task_id = shift;
	if (!$task_id) {
		notify($ERRORS{'WARNING'}, 0, "task ID argument was not supplied");
		return;
	}
	
	my $timeout_seconds = shift || 30;
	
	my $start_time = time();
	
	while (time() - $start_time < $timeout_seconds) {
		notify($ERRORS{'DEBUG'}, 0, "checking status of task: $task_id");
		
		(my @task_info_output = $self->_get_task_info($task_id)) || return;
		
		# Parse the output to get the task state and progress
		my ($task_state) = map(/^\s*state\s*=\s*"(.+)"/, @task_info_output);
		
		if (!$task_state) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine task state from task info output:\n" . join("\n", @task_info_output));
			return;
		}
		
		if ($task_state =~ /success/) {
			notify($ERRORS{'DEBUG'}, 0, "task completed successfully: $task_id");
			return 1;
		}
		elsif ($task_state =~ /error|cancelled/) {
			# Get the error message from the task info output
			my ($error_message) = map(/^\s*msg\s*=\s*"(.+)"/, @task_info_output);
			
			# If the error message can't be determined, display all of the task info output
			$error_message = "\n" . join("\n", @task_info_output) if !$error_message;
			
			notify($ERRORS{'WARNING'}, 0, "task $task_id did not complete successfully, state: $task_state, error message: $error_message");
			return;
		}
		elsif ($task_state =~ /running/) {
			my ($progress) = map(/^\s*progress\s*=\s*(\d+)/, @task_info_output);
			$progress = 'unknown' if !defined($progress);
			notify($ERRORS{'DEBUG'}, 0, "task state: $task_state, progress: $progress, sleeping for 3 seconds before checking task state again");
			sleep 3;
		}
		else {
			my ($progress) = map(/^\s*progress\s*=\s*(\d+)/, @task_info_output);
			$progress = 'unknown' if !defined($progress);
			notify($ERRORS{'DEBUG'}, 0, "task state: $task_state, progress: $progress, sleeping for 3 seconds before checking task state again\n" . join("\n", @task_info_output));
			sleep 3;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "timeout was reached: $timeout_seconds seconds, task never completed");
	return;
}

##############################################################################

=head1 API OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_registered_vms

 Parameters  : none
 Returns     : array
 Description : Returns an array containing the vmx file paths of the VMs running
               on the VM host.

=cut

sub get_registered_vms {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the VM IDs
	my $vm_list = $self->_get_vm_list();
	
	# Get the vmx path values for each VM
	my @vmx_paths = values(%$vm_list);
	
	#notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@vmx_paths) . " registered VMs");
	return @vmx_paths;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_vm_power_state

 Parameters  : $vmx_file_path
 Returns     : string
 Description : Returns a string containing the power state of the VM indicated
					by the vmx file path argument. The string returned may be one of
					the following values:
					on
					off
					suspended

=cut

sub get_vm_power_state {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	my $vm_id = $self->_get_vm_id($vmx_file_path) || return;
	
	my $vim_cmd_arguments = "vmsvc/power.getstate $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The output should look like this:
	# Retrieved runtime info
	# Powered on
	
	# Retrieved runtime info
	# Powered off
	
	# Retrieved runtime info
	# Suspended
	
	notify($ERRORS{'DEBUG'}, 0, "$vim_cmd_arguments:\n" . join("\n", @$output));
	
	if (grep(/powered on/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "VM is powered on: $vmx_file_path");
		return 'on';
	}
	elsif (grep(/powered off/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "VM is powered off: $vmx_file_path");
		return 'off';
	}
	elsif (grep(/suspended/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "VM is suspended: $vmx_file_path");
		return 'suspended';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to determine power state of $vmx_file_path, VIM command arguments: '$vim_cmd_arguments' output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_power_on

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Powers on the VM indicated by the vmx file path argument.

=cut

sub vm_power_on {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	# Get the VM ID
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to power on VM because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/power.on $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output if the VM was not previously powered on:
	# Powering on VM:
	
	# Expected output if the VM was previously powered on:
	# Powering on VM:
	# (vim.fault.InvalidPowerState) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   requestedState = "poweredOn",
	#   existingState = "poweredOn",
	#   msg = "The attempted operation cannot be performed in the current state (Powered On).",
	# }
	
	if (grep(/existingState = "poweredOn"/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "VM is already powered on: $vmx_file_path");
		return 1;
	}
	elsif (!grep(/Powering on VM/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to power on VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	# Get the task ID
	my $task_id = $self->_get_task_id($vmx_file_path, 'powerOn');
	if (!$task_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to power on the VM");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_id)) {
		notify($ERRORS{'OK'}, 0, "powered on VM: $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to power on VM: $vmx_file_path, the vim power on task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_power_off

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Powers off the VM indicated by the vmx file path argument.

=cut

sub vm_power_off {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	# Get the VM ID
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to power off VM because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/power.off $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output if the VM was not previously powered off:
	# Powering off VM:
	
	# Expected output if the VM was previously powered off:
	# Powering off VM:
	# (vim.fault.InvalidPowerState) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   requestedState = "poweredOff",
	#   existingState = "poweredOff",
	#   msg = "The attempted operation cannot be performed in the current state (Powered Off).",
	# }
	
	if (grep(/existingState = "poweredOff"/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "VM is already powered off: $vmx_file_path");
		return 1;
	}
	elsif (!grep(/Powering off VM/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to power off VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}

	# Get the task ID
	my $task_id = $self->_get_task_id($vmx_file_path, 'powerOff');
	if (!$task_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to power on the VM");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_id)) {
		notify($ERRORS{'OK'}, 0, "powered off VM: $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to power off VM: $vmx_file_path, the vim power off task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_register

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Registers the VM indicated by the vmx file path argument.

=cut

sub vm_register {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	# Check if the VM is already registered
	if ($self->is_vm_registered($vmx_file_path)) {
		notify($ERRORS{'OK'}, 0, "VM is already registered: $vmx_file_path");
		return 1;
	}
	
	$vmx_file_path =~ s/\\* /\\ /g;
	my $vim_cmd_arguments = "solo/registervm \"$vmx_file_path\"";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Note: registervm does not produce any output if it was successful
	
	# Expected output if the vmx file path does not exist:
	# (vim.fault.NotFound) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   msg = "The object or item referred to could not be found.",
	# }
	
	if (grep(/fault/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM: $vmx_file_path, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
	
	# Check to make sure the VM is registered
	if ($self->is_vm_registered($vmx_file_path)) {
		notify($ERRORS{'OK'}, 0, "registered VM: '$vmx_file_path'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM: '$vmx_file_path'");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_unregister

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Unregisters the VM indicated by the vmx file path argument.

=cut

sub vm_unregister {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift;
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument was not supplied");
		return;
	}
	
	# Check if the VM is not registered
	if (!$self->is_vm_registered($vmx_file_path)) {
		notify($ERRORS{'OK'}, 0, "VM not unregistered because it is not registered: $vmx_file_path");
		return 1;
	}
	
	# Power of the VM if it is powered on or the unregister command will fail
	my $vm_power_state = $self->get_vm_power_state($vmx_file_path);
	if ($vm_power_state && $vm_power_state =~ /on/i) {
		if (!$self->vm_power_off($vmx_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to unregister VM because it could not be powered off: $vmx_file_path");
			return;
		}
	}
	
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'OK'}, 0, "unable to unregister VM because VM ID could not be determined for vmx path: $vmx_file_path");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/unregister $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output if the VM is not registered:
	# (vim.fault.NotFound) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   msg = "Unable to find a VM corresponding to "/vmfs/volumes/nfs-datastore/vm-ark-mcnc-9_234-v12/vm-ark-mcnc-9_234-v12.vmx"",
	# }
	
	if (grep(/fault/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM $vm_id: $vmx_file_path\nVIM command arguments: '$vim_cmd_arguments'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Check to make sure the VM is not registered
	if (!$self->is_vm_registered($vmx_file_path)) {
		notify($ERRORS{'OK'}, 0, "unregistered VM: $vmx_file_path (ID: $vm_id)");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM: $vmx_file_path  (ID: $vm_id), it still appears to be registered");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_virtual_disk_type

 Parameters  : $vmdk_file_path
 Returns     : 
 Description : Retrieves the disk type configured for the virtual disk specified
					by the vmdk file path argument. A string is returned containing
					one of the following values:
               -FlatVer1
               -FlatVer2
               -RawDiskMappingVer1
               -SparseVer1
               -SparseVer2

=cut

sub get_virtual_disk_type {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path argument
	my $vmdk_file_path = shift;
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path argument was not supplied");
		return;
	}
	
	my ($vmdk_directory_path, $vmdk_file_name) = $vmdk_file_path =~ /^(.+)\/([^\/]+\.vmdk)/;
	if (!$vmdk_directory_path || !$vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine directory path and file name from vmdk file path: $vmdk_directory_path");
		return;
	}
	
	my $vmdk_directory_datastore_path = $self->_get_datastore_path($vmdk_directory_path);
	if (!$vmdk_directory_datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmdk directory datastore path from vmdk directory path: $vmdk_directory_path");
		return;
	}
	
	my $vim_cmd_arguments = "hostsvc/datastorebrowser/disksearch \"$vmdk_directory_datastore_path\"";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	# (vim.host.DatastoreBrowser.SearchResults) [
	#   (vim.host.DatastoreBrowser.SearchResults) {
	#      dynamicType = <unset>,
	#      datastore = 'vim.Datastore:10.25.0.245:/vmfs/volumes/nfs-datastore',
	#      folderPath = "[nfs-datastore] vmwarewinxp-base234-v12",
	#      file = (vim.host.DatastoreBrowser.FileInfo) [
	#         (vim.host.DatastoreBrowser.VmDiskInfo) {
	#            dynamicType = <unset>,
	#            path = "vmwarewinxp-base234-v12.vmdk",
	#            fileSize = 4774187008,
	#            modification = <unset>,
	#            owner = <unset>,
	#            diskType = "vim.vm.device.VirtualDisk.SparseVer2BackingInfo",
	#            capacityKb = 14680064,
	#            hardwareVersion = 4,
	#            controllerType = <unset>,
	#            diskExtents = (string) [
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s001.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s002.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s003.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s004.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s005.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s006.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s007.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s008.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s009.vmdk",
	#               "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s010.vmdk"
	#            ],
	#            thin = <unset>,
	#         },
	#         (vim.host.DatastoreBrowser.VmDiskInfo) {
	#            dynamicType = <unset>,
	#            path = "thin_vmwarewinxp-base234-v12.vmdk",
	#            fileSize = 4408459264,
	#            modification = <unset>,
	#            owner = <unset>,
	#            diskType = "vim.vm.device.VirtualDisk.FlatVer2BackingInfo",
	#            capacityKb = 14680064,
	#            hardwareVersion = 4,
	#            controllerType = <unset>,
	#            diskExtents = (string) [
	#               "[nfs-datastore] vmwarewinxp-base234-v12/thin_vmwarewinxp-base234-v12-flat.vmdk"
	#            ],
	#            thin = <unset>,
	#         }
	#      ],
	#   }
	# ]

	my $output_string = join("\n", @$output);
	my (@disk_info_sections) = split(/vim.host.DatastoreBrowser.VmDiskInfo/, $output_string);
	
	for my $disk_info (@disk_info_sections) {
		my ($disk_path) = $disk_info =~ /\spath = "(.+)"/i;
		
		if (!$disk_path || $disk_path ne $vmdk_file_name) {
			next;
		}
		
		my ($disk_type) = $disk_info =~ /\sdiskType = "(.+)"/i;
		if (!$disk_type) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine disk type, disk path: $disk_path, disk info section from vim-cmd $vim_cmd_arguments output:\n$disk_info");
			next;
		}
		
		# Disk type format: vim.vm.device.VirtualDisk.FlatVer2BackingInfo
		# Remove everything but "FlatVer2"
		$disk_type =~ s/(^.*\.|BackingInfo$)//g;
		
		notify($ERRORS{'DEBUG'}, 0, "$disk_path disk type: $disk_type");
		return $disk_type;
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine disk type for disk: $vmdk_file_path, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_virtual_disk_controller_type

 Parameters  : $vmdk_file_path
 Returns     : string
 Description : Retrieves the disk controller type configured for the virtual
					disk specified by the vmdk file path argument. False is returned
					if the controller type cannot be retrieved. A string is returned
					containing one of the following values:
					-IDE
					-lsiLogic
					-busLogic

=cut

sub get_virtual_disk_controller_type {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path argument
	my $vmdk_file_path = shift;
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path argument was not supplied");
		return;
	}
	
	my ($vmdk_directory_path, $vmdk_file_name) = $vmdk_file_path =~ /^(.+)\/([^\/]+\.vmdk)/;
	if (!$vmdk_directory_path || !$vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine directory path and file name from vmdk file path: $vmdk_directory_path");
		return;
	}
	
	my $vmdk_directory_datastore_path = $self->_get_datastore_path($vmdk_directory_path);
	if (!$vmdk_directory_datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmdk directory datastore path from vmdk directory path: $vmdk_directory_path");
		return;
	}
	
	my $vim_cmd_arguments = "hostsvc/datastorebrowser/searchsubfolders 0 \"$vmdk_directory_datastore_path\"";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	# (vim.host.DatastoreBrowser.SearchResults) {
	#   dynamicType = <unset>,
	#   datastore = 'vim.Datastore:10.25.0.245:/vmfs/volumes/nfs-datastore',
	#   folderPath = "[nfs-datastore] vmwarewinxp-base234-v12",
	#   file = (vim.host.DatastoreBrowser.FileInfo) [
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "vmwarewinxp-base234-v12.vmdk",
	#         fileSize = 4774187008,
	#         modification = "2010-06-30T21:03:45Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.SparseVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 4,
	#         controllerType = "vim.vm.device.VirtualBusLogicController",
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s001.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s002.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s003.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s004.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s005.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s006.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s007.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s008.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s009.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s010.vmdk"
	#         ],
	#         thin = false,
	#      },
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "esx_2gb_sparse.vmdk",
	#         fileSize = 4410286080,
	#         modification = "2010-07-01T18:38:04Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.SparseVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 7,
	#         controllerType = "vim.vm.device.VirtualIDEController",
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s001.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s002.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s003.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s004.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s005.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s006.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s007.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s008.vmdk"
	#         ],
	#         thin = true,
	#      },
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "thin_vmwarewinxp-base234-v12.vmdk",
	#         fileSize = 4408459264,
	#         modification = "2010-06-30T20:53:51Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.FlatVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 4,
	#         controllerType = <unset>,
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/thin_vmwarewinxp-base234-v12-flat.vmdk"
	#         ],
	#         thin = true,
	#      }
	#   ],
	# }

	my $output_string = join("\n", @$output);
	my (@disk_info_sections) = split(/vim.host.DatastoreBrowser.VmDiskInfo/, $output_string);
	
	for my $disk_info (@disk_info_sections) {
		my ($disk_path) = $disk_info =~ /\spath = "(.+)"/i;
		
		if (!$disk_path) {
			next;
		}
		elsif ($disk_path ne $vmdk_file_name) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring disk because the file name does not match $vmdk_file_name: $disk_path");
			next;
		}
		
		my ($controller_type) = $disk_info =~ /\scontrollerType\s*=\s*(.+)/i;
		if (!$controller_type) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine disk controller type, disk path: $disk_path, disk info section from vim-cmd $vim_cmd_arguments output:\n$disk_info");
			next;
		}
		
		if ($controller_type =~ /unset/i) {
			notify($ERRORS{'DEBUG'}, 0, "disk controller type is not set in the vmdk file: $disk_path");
			return 0;
		}
		else {
			# Extract just the controller type name from the value: vim.vm.device.VirtualIDEController --> IDE
			$controller_type =~ s/(.*vim.vm.device.Virtual|Controller.*)//ig;
			notify($ERRORS{'DEBUG'}, 0, "retrieved controller type for $disk_path: '$controller_type'");
			return $controller_type;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine disk controller type for disk: $vmdk_file_path, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_virtual_disk_hardware_version

 Parameters  : $vmdk_file_path
 Returns     : integer
 Description : Retrieves the hardware version configured for the virtual
					disk specified by the vmdk file path argument. False is returned
					if the hardware version cannot be retrieved.

=cut

sub get_virtual_disk_hardware_version {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmdk file path argument
	my $vmdk_file_path = shift;
	if (!$vmdk_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmdk file path argument was not supplied");
		return;
	}
	
	my ($vmdk_directory_path, $vmdk_file_name) = $vmdk_file_path =~ /^(.+)\/([^\/]+\.vmdk)/;
	if (!$vmdk_directory_path || !$vmdk_file_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine directory path and file name from vmdk file path: $vmdk_directory_path");
		return;
	}
	
	my $vmdk_directory_datastore_path = $self->_get_datastore_path($vmdk_directory_path);
	if (!$vmdk_directory_datastore_path) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine vmdk directory datastore path from vmdk directory path: $vmdk_directory_path");
		return;
	}
	
	my $vim_cmd_arguments = "hostsvc/datastorebrowser/searchsubfolders 0 \"$vmdk_directory_datastore_path\"";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	# (vim.host.DatastoreBrowser.SearchResults) {
	#   dynamicType = <unset>,
	#   datastore = 'vim.Datastore:10.25.0.245:/vmfs/volumes/nfs-datastore',
	#   folderPath = "[nfs-datastore] vmwarewinxp-base234-v12",
	#   file = (vim.host.DatastoreBrowser.FileInfo) [
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "vmwarewinxp-base234-v12.vmdk",
	#         fileSize = 4774187008,
	#         modification = "2010-06-30T21:03:45Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.SparseVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 4,
	#         controllerType = "vim.vm.device.VirtualBusLogicController",
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s001.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s002.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s003.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s004.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s005.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s006.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s007.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s008.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s009.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/vmwarewinxp-base234-v12-s010.vmdk"
	#         ],
	#         thin = false,
	#      },
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "esx_2gb_sparse.vmdk",
	#         fileSize = 4410286080,
	#         modification = "2010-07-01T18:38:04Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.SparseVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 7,
	#         controllerType = "vim.vm.device.VirtualIDEController",
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s001.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s002.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s003.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s004.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s005.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s006.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s007.vmdk",
	#            "[nfs-datastore] vmwarewinxp-base234-v12/esx_2gb_sparse-s008.vmdk"
	#         ],
	#         thin = true,
	#      },
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "thin_vmwarewinxp-base234-v12.vmdk",
	#         fileSize = 4408459264,
	#         modification = "2010-06-30T20:53:51Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.FlatVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 4,
	#         controllerType = <unset>,
	#         diskExtents = (string) [
	#            "[nfs-datastore] vmwarewinxp-base234-v12/thin_vmwarewinxp-base234-v12-flat.vmdk"
	#         ],
	#         thin = true,
	#      }
	#   ],
	# }

	my $output_string = join("\n", @$output);
	my (@disk_info_sections) = split(/vim.host.DatastoreBrowser.VmDiskInfo/, $output_string);
	
	for my $disk_info (@disk_info_sections) {
		my ($disk_path) = $disk_info =~ /\spath = "(.+)"/i;
		
		if (!$disk_path) {
			next;
		}
		elsif ($disk_path ne $vmdk_file_name) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring disk because the file name does not match $vmdk_file_name: $disk_path");
			next;
		}
		
		my ($hardware_version) = $disk_info =~ /\shardwareVersion\s*=\s*(.+)/i;
		if (!$hardware_version) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine disk hardware version, disk path: $disk_path, disk info section from vim-cmd $vim_cmd_arguments output:\n$disk_info");
			next;
		}
		
		if ($hardware_version =~ /unset/i) {
			notify($ERRORS{'DEBUG'}, 0, "disk hardware version is not set in the vmdk file: $disk_path");
			return 0;
		}
		else {
			# Extract just the hardware version from the value
			$hardware_version =~ s/.*(\d+).*/$1/ig;
			notify($ERRORS{'DEBUG'}, 0, "retrieved hardware version for $disk_path: '$hardware_version'");
			return $hardware_version;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine hardware version for disk: $vmdk_file_path, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_network_names

 Parameters  : none
 Returns     : array
 Description : Retrieves the network names configured on the VM host.

=cut

sub get_network_names {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vim_cmd_arguments = "solo/environment";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The output should contain a network section:
   #network = (vim.vm.NetworkInfo) [
   #   (vim.vm.NetworkInfo) {
   #      dynamicType = <unset>,
   #      name = "Private",
   #      network = (vim.Network.Summary) {
   #         dynamicType = <unset>,
   #         network = 'vim.Network:HaNetwork-Private',
   #         name = "Private",
   #         accessible = true,
   #         ipPoolName = "",
   #      },
   #   },
   #   (vim.vm.NetworkInfo) {
   #      dynamicType = <unset>,
   #      name = "Public",
   #      network = (vim.Network.Summary) {
   #         dynamicType = <unset>,
   #         network = 'vim.Network:HaNetwork-Public',
   #         name = "Public",
   #         accessible = true,
   #         ipPoolName = "",
   #      },
   #   },
   #],
	
	# Convert the output line array to a string then split it by network sections
	my ($network_info) = join("\n", @$output) =~ /(vim\.vm\.NetworkInfo[^\]]+)/;
	notify($ERRORS{'DEBUG'}, 0, "network info:\n$network_info");
	
	my (@network_sections) = split(/vim.vm.NetworkInfo/, $network_info);
	
	# Extract the network names from the network sections
	my @network_names;
	for my $network_info (@network_sections) {
		my ($network_name) = $network_info =~ /\sname = "(.+)"/i;
		next if !$network_name;
		push @network_names, $network_name;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved network names:\n" . join("\n", @network_names));
	return @network_names;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
