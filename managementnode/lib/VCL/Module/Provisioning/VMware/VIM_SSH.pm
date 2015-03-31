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
our $VERSION = '2.4.2';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use English '-no_match_vars';
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
	
	if (!defined($self->{vmhost_os})) {
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
	}
	
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
	else {
		# Output contains the line: 'vmware-vim-cmd: command not found'
		# Note: VMware ESX 4.1 has BOTH vim-cmd and vmware-vim-cmd
		$self->{vim_cmd} = 'vim-cmd';
	}
	notify($ERRORS{'DEBUG'}, 0, "VIM executable available on VM host: $self->{vim_cmd}");
	
	notify($ERRORS{'DEBUG'}, 0, ref($self) . " object initialized");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _run_vim_cmd

 Parameters  : $vim_arguments, $timeout_seconds (optional)
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
	
	my $timeout_seconds = shift || 60;
	
	my $request_state_name = $self->data->get_request_state_name();
	my $vmhost_computer_name = $self->vmhost_os->data->get_computer_short_name();
	
	my $command = "$self->{vim_cmd} $vim_arguments";
	
	my $attempt = 0;
	my $attempt_limit = 5;
	my $wait_seconds = 5;
	
	my $connection_reset_errors = 0;
	
	ATTEMPT: while ($attempt++ < $attempt_limit) {
		
		my $semaphore;
		if ($attempt > 1) {
			# Wait before making next attempt
			notify($ERRORS{'OK'}, 0, "sleeping $wait_seconds seconds before making attempt $attempt/$attempt_limit");
			sleep_uninterrupted($wait_seconds);
			$semaphore = $self->get_semaphore($vmhost_computer_name, 120, 1) || next ATTEMPT;
		}
		
		#	my $semaphore_id = "$vmhost_computer_name";
		#	if ($self->does_semaphore_exist($semaphore_id)) {
		#		
		#		notify($ERRORS{'DEBUG'}, 0, "blocked by another process controlling $vmhost_computer_name, sleeping for 10 seconds");
		#		sleep_uninterrupted(10);
		#		my $wait_message = "blocked by another process controlling $vmhost_computer_name";
		#		$self->code_loop_timeout(sub{!$self->does_semaphore_exist(@_)}, [$semaphore_id], $wait_message, 140, 5);
		#	}
		#}
		
		# The following error is somewhat common if several processes are adding/removing VMs at the same time:
		# (vmodl.fault.ManagedObjectNotFound) {
		#	 dynamicType = <unset>,
		#	 faultCause = (vmodl.MethodFault) null,
		# 	 obj = 'vim.VirtualMachine:672',
		# 	 msg = "The object has already been deleted or has not been completely created",
		# }
		
		# Keep a count of the number of times vim-cmd is executed for the entire vcld state process
		# This will be used to improve performance by reducing the number of calls necessary
		$self->{vim_cmd_calls}++;
		#notify($ERRORS{'DEBUG'}, 0, "vim-cmd call count: $self->{vim_cmd_calls} ($vim_arguments)");
		
		my ($exit_status, $output) = $self->vmhost_os->execute($command, 0, $timeout_seconds);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to run VIM command on VM host $vmhost_computer_name: $command");
		}
		elsif (grep(/already been deleted/i, @$output)) {
			notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: fault occurred attempting to run command on VM host $vmhost_computer_name: $command, output:\n" . join("\n", @$output));
		}
		elsif (grep(/(Failed to login|connection reset|SSL Exception)/i, @$output)) {
			# Try to catch these errors:
			# Failed to login: Connection reset by peer
			# Failed to login: SSL Exception: The SSL handshake timed out local: 127.0.0.1:52713 peer: 127.0.0.1:443.
			$connection_reset_errors++;
			notify($ERRORS{'OK'}, 0, "attempt $attempt/$attempt_limit: connection reset while attempting to run command on VM host $vmhost_computer_name: $command, output:\n" . join("\n", @$output));
			
			# If 2 connection reset errors occured, attempt to run services.sh restart
			if ($connection_reset_errors == 2) {
				if ($self->{services_restarted}) {
					notify($ERRORS{'WARNING'}, 0, "encountered $connection_reset_errors connection reset errors on VM host $vmhost_computer_name, not calling 'services.sh restart', it was already attempted");
				}
				else {
					notify($ERRORS{'OK'}, 0, "calling 'services.sh restart', encountered $connection_reset_errors connection reset errors on VM host $vmhost_computer_name");
					$self->_services_restart();
					$self->{services_restarted} = 1;
					next ATTEMPT;
				}
			}
			elsif ($connection_reset_errors > 2) {
				notify($ERRORS{'WARNING'}, 0, "encountered $connection_reset_errors connection reset errors on VM host $vmhost_computer_name");
			}
			else {
				next ATTEMPT;
			}
			
			# Problem probably won't correct itself
			# If request state is 'inuse', set the reservation.lastcheck value to 20 minutes before request.end
			# This avoids 'inuse' processes from being created over and over again which will fail
			if ($request_state_name eq 'inuse') {
				my $reservation_id = $self->data->get_reservation_id();
				my $request_end_time_epoch = convert_to_epoch_seconds($self->data->get_request_end_time());
				my $current_time_epoch = time;
				my $reservation_lastcheck_epoch = ($request_end_time_epoch-(20*60));
				set_reservation_lastcheck($reservation_lastcheck_epoch, $reservation_id);
			}
			return;
		}
		elsif ($exit_status != 0 || grep(/^(vim-cmd:|Killed|terminate called|Aborted|what\()/i, @$output)) {
			# terminate called after throwing an instance of 'std::bad_alloc'
			# what():  std::bad_alloc
			# Aborted
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to execute command on VM host $vmhost_computer_name: $command, exit status: $exit_status, output:\n" . join("\n", @$output));
			next ATTEMPT;
		}
		else {
			# VIM command command was executed
			if ($attempt > 1) {
				notify($ERRORS{'DEBUG'}, 0, "attempt $attempt/$attempt_limit: executed command on VM host $vmhost_computer_name: $command, exit status: $exit_status");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "executed command on VM host $vmhost_computer_name: $command, exit status: $exit_status");
			}
			return ($exit_status, $output);
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to run VIM command on VM host $vmhost_computer_name: '$command', made $attempt_limit attempts");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _services_restart

 Parameters  : none
 Returns     : boolean
 Description : Calls 'services.sh restart' on the VM host. This may resolve
               problems where the host is not responding due to a problem with
               one or more services. This should rarely be called.

=cut

sub _services_restart {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_computer_name = $self->vmhost_os->data->get_computer_short_name();
	
	my $semaphore = $self->get_semaphore("$vmhost_computer_name-vmware_services_restart", 0);
	if (!$semaphore) {
		notify($ERRORS{'OK'}, 0, "unable to obtain semaphore, another process is likely restarting services on $vmhost_computer_name, sleeping for 30 seconds and then proceeding");
		sleep_uninterrupted(30);
		return 1;
	}
	
	my $check_services = {
		'hostd-worker' => '/var/run/vmware/vmware-hostd.PID',
		'sfcb-vmware_bas' => '/var/run/vmware/vicimprovider.PID',
		'vmkdevmgr' => '/var/run/vmware/vmkdevmgr.pid',
		'vmkeventd' => '/var/run/vmware/vmkeventd.pid',
		'vmsyslogd' => '/var/run/vmware/vmsyslogd.pid',
		'rhttpproxy-work' => '/var/run/vmware/vmware-rhttpproxy.PID',
		'vpxa-worker' => '/var/run/vmware/vmware-vpxa.PID',
	};
	
	# Check if the PID files for the following services are correct
	for my $service_name (keys %$check_services) {
		my $pid_file_path = $check_services->{$service_name};
		$self->_check_service_pid($service_name, $pid_file_path);
	}
	
	my $services_command = "services.sh restart";
	notify($ERRORS{'DEBUG'}, 0, "restarting VMware services on $vmhost_computer_name");
	my ($services_exit_status, $services_output) = $self->vmhost_os->execute($services_command, 0, 120);
	if (!defined($services_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command on VM host $vmhost_computer_name: $services_command");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "executed command to restart VMware services on $vmhost_computer_name, command: '$services_command', output:\n" . join("\n", @$services_output));
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _check_service_pid

 Parameters  : $process_name, $pid_file_path
 Returns     : boolean
 Description : Checks if the PID stored in the PID file matches the parent PID
               of the running service process. Problems occur if the file does
               not match the running process PID. Most often, vim-cmd commands
               fail with an error such as:
               Connect to localhost failed: Connection failure
               
               The PID file is updated with the correct PID if the PID file
               contents cannot be retrieved and parsed or if the PID stored in
               the file does not match the running process.

=cut

sub _check_service_pid {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($process_name, $pid_file_path) = @_;
	if (!defined($process_name) || !defined($pid_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "process name and PID file path arguments were not supplied");
		return;
	}
	
	my $vmhost_computer_name = $self->vmhost_os->data->get_computer_short_name();
	
	# Retrieve the running PID
	my $running_pid;
	my $ps_command = "ps |grep $process_name |awk '{print \$2}'";
	my ($ps_exit_status, $ps_output) = $self->vmhost_os->execute($ps_command);
	if (!defined($ps_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine main $process_name PID on $vmhost_computer_name");
	}
	else {
		($running_pid) = "@$ps_output" =~ /(\d+)/g;
		if ($running_pid && $running_pid > 1) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved parent $process_name PID: $running_pid");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "parent $process_name process is not running");
		}
	}
	
	# Check if the .pid file exists
	my $pid_file_exists = $self->vmhost_os->file_exists($pid_file_path);
	if (!$running_pid) {
		if ($pid_file_exists) {
			notify($ERRORS{'DEBUG'}, 0, "running $process_name process was not detected but PID file exists: $pid_file_path, deleting file");
			if ($self->vmhost_os->delete_file($pid_file_path)) {
				notify($ERRORS{'DEBUG'}, 0, "deleted file on $vmhost_computer_name: $pid_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to delete file on $vmhost_computer_name: $pid_file_path");
			}
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "running $process_name process was not detected and PID file does not exist: $pid_file_path");
			return 1;
		}
	}
	else {
		if ($pid_file_exists) {
			# Retrieve the PID stored in the PID file
			my @pid_file_contents = $self->vmhost_os->get_file_contents($pid_file_path);
			if (@pid_file_contents) {
				my ($file_pid) = "@pid_file_contents" =~ /(\d+)/g;
				if ($file_pid) {
					notify($ERRORS{'DEBUG'}, 0, "retrieved PID stored in $pid_file_path: $file_pid");
					if ($file_pid eq $running_pid) {
						notify($ERRORS{'OK'}, 0, "PID in $pid_file_path ($file_pid) matches PID of parent $process_name process ($running_pid), update not necessary");
						return 1;
					}
					else {
						notify($ERRORS{'OK'}, 0, "PID in $pid_file_path ($file_pid) does not match PID of parent $process_name process ($running_pid), updating $pid_file_path to contain $running_pid");
					}
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to determine PID stored in $pid_file_path, contents:\n" . join("\n", @pid_file_contents));
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of $pid_file_path");
			}
		}
		
		# Update the PID file with the correct PID
		my $echo_command = "echo -n $running_pid > $pid_file_path";
		my ($echo_exit_status, $echo_output) = $self->vmhost_os->execute($echo_command);
		if (!defined($echo_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to update $pid_file_path on $vmhost_computer_name");
			return;
		}
		elsif (grep(/(ash:|echo:)/, @$echo_output)) {
			notify($ERRORS{'WARNING'}, 0, "error occurred updating $pid_file_path on $vmhost_computer_name, command: '$echo_command', output:\n" . joini("\n", @$echo_output));
			return;
		}
		else {
			notify($ERRORS{'OK'}, 0, "updated $pid_file_path on $vmhost_computer_name to contain the correct PID: $running_pid");
		}
	}
	
	return 1;
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
			#return;
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
	if (!defined($vm_list)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM ID, failed to retrieve list of registered VMs and their IDs");
		return;
	}
	
	for my $vm_id (keys %$vm_list) {
		return $vm_id if ($vm_list->{$vm_id} && $vmx_file_path eq $vm_list->{$vm_id});
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
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
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
		
		# Check if the accessible value was retrieved and is not false
		my $datastore_accessible = $datastore_info->{$datastore_name}{accessible};
		if (!$datastore_accessible || $datastore_accessible =~ /false/i) {
			notify($ERRORS{'DEBUG'}, 0, "datastore '$datastore_name' is mounted on $vmhost_hostname but not accessible");
			delete $datastore_info->{$datastore_name};
			next;
		}
		
		# Add a 'normal_path' key to the hash based on the datastore url
		my $datastore_url = $datastore_info->{$datastore_name}{url};
		if (!defined($datastore_url)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine datastore url from 'vim-cmd $vim_cmd_arguments' output section, datastore name: $datastore_name:\n$output_section");
			delete $datastore_info->{$datastore_name};
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

=head2 _get_task_ids

 Parameters  : $vmx_file_path, $task_type
 Returns     : array
 Description : Returns an array containing the task IDs recently executed on
               the VM indicated by the $vm_id argument. The task type argument
               must be specified. Example task type values:
               powerOn
               powerOff
               registerVm
               unregisterVm

=cut

sub _get_task_ids {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the vmx file path argument
	my $vmx_file_path = shift || $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument could not be determined");
		return;
	}
	
	# Get the task type argument
	my $task_type = shift;
	
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
	
	# Expected output if there are no recent tasks:
	# (ManagedObjectReference) []
	
	if (!grep(/ManagedObjectReference/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to retrieve task list, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/\(ManagedObjectReference\)\s*\[\]/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "there are no recent tasks for VM $vm_id");
		return ();
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "task list output:\n" . join("\n", @$output));
	
	# Reverse the output array so the newest tasks are listed first
	my @reversed_output = reverse(@$output);
	
	#notify($ERRORS{'DEBUG'}, 0, "reversed task list output:\n" . join("\n", @reversed_output));
	
	#my (@task_ids) = grep(/haTask-$vm_id-.+$task_type-/, @reversed_output);
	my @task_ids;
	if ($task_type) {
		@task_ids = map { /(haTask-$vm_id-.+$task_type-\d+)/ } @reversed_output;
	}
	else {
		@task_ids = map { /(haTask-$vm_id-.+-\d+)/ } @reversed_output;
		$task_type = 'all';
	}
	
	# Check if a matching task was found
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine task IDs from output for VM $vm_id, task type: $task_type, output:\n" . join("\n", @$output));
		return;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved task IDs for VM $vm_id, task type: $task_type:\n" . join("\n", @task_ids));
	return @task_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _get_task_info

 Parameters  : $task_id
 Returns     : hash reference
 Description : 

=cut

sub _get_task_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the task ID path argument
	my (@task_ids) = @_;
	@task_ids = $self->_get_task_ids() if (!@task_ids);
	
	my $task_info = {};
	
	for my $task_id (@task_ids) {
		my $vim_cmd_arguments = "vimsvc/task_info $task_id";
		my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
		
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
		
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve info for task ID: $task_id");
			next;
		}
		elsif (grep(/ManagedObjectNotFound/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "task was not found, task ID: $task_id, output:\n" . join("\n", @$output));
			next;
		}
		elsif (!grep(/vim.TaskInfo/i, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to retrieve task list, VIM command arguments: '$vim_cmd_arguments' output:\n" . join("\n", @$output));
			next;
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "retrieved info for task $task_id");	
			$task_info->{$task_id} = join("\n", @$output);
		}
	}
	
	return $task_info;
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
		
		# Get the task info
		my $task_info = $self->_get_task_info($task_id);
		my $task_info_output = $task_info->{$task_id};
		if (!$task_info || !$task_info_output) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine if task $task_id has completed, task info could not be retrieved");
			return;
		}
		
		# Parse the output to get the task state and progress
		my ($task_state) = $task_info_output =~ /state\s*=\s*"([^"]+)/is;
		if (!$task_state) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine task state from task info output:\n$task_info_output");
			return;
		}
		
		my ($error_message) = $task_info_output =~ /msg\s*=\s*"([^"]+)/;
		$error_message = $task_info_output if !$error_message;
		
		my ($progress)= $task_info_output =~ /progress\s*=\s*(\d+)/;
		$progress = 'unknown' if !defined($progress);
		
		if ($task_state =~ /success/) {
			notify($ERRORS{'DEBUG'}, 0, "task completed successfully: $task_id");
			return 1;
		}
		elsif ($task_state =~ /error|cancelled/) {
			
			# Check if the task failed with the message: 'Operation failed since another task is in progress.'
			if ($error_message =~ /another task is in progress/i) {
				# Retrieve info for all of the VMs recent tasks
				my $task_info_all = $self->_get_task_info();
				notify($ERRORS{'WARNING'}, 0, "task $task_id did not complete successfully, state: $task_state, error message: $error_message, task info:\n" . format_data($task_info_all));
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "task $task_id did not complete successfully, state: $task_state, error message: $error_message");
			}
			return;
		}
		elsif ($task_state =~ /running/) {
			notify($ERRORS{'DEBUG'}, 0, "task state: $task_state, progress: $progress, sleeping for 3 seconds before checking task state again");
			sleep 3;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "task state: $task_state, progress: $progress, sleeping for 3 seconds before checking task state again, output:\n$task_info_output");
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
	if (!defined($vm_list)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve registered VMs, failed to retrieve list of registered VMs and their IDs");
		return;
	}
	
	# Get the vmx path values for each VM
	my @vmx_paths = values(%$vm_list);
	
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@vmx_paths) . " registered VMs");
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
	my @task_ids = $self->_get_task_ids($vmx_file_path, 'powerOn');
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to power on the VM");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_ids[0])) {
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
	
	# Check if the VM is already powered off
	my $vm_power_state = $self->get_vm_power_state($vmx_file_path);
	if ($vm_power_state && $vm_power_state =~ /off/i) {
		notify($ERRORS{'DEBUG'}, 0, "VM is already powered off: $vmx_file_path");
		return 1;
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
	my @task_ids = $self->_get_task_ids($vmx_file_path, 'powerOff');
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to power off the VM");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_ids[0])) {
		notify($ERRORS{'OK'}, 0, "powered off VM: $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to power off VM: $vmx_file_path, the vim power off task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vm_suspend

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Powers off the VM indicated by the vmx file path argument.

=cut

sub vm_suspend {
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
	
	# Check if the VM is already powered off
	my $vm_power_state = $self->get_vm_power_state($vmx_file_path);
	if ($vm_power_state) {
		if ($vm_power_state =~ /off/i) {
			notify($ERRORS{'DEBUG'}, 0, "VM is already powered off: $vmx_file_path");
			return 1;
		}
		elsif ($vm_power_state =~ /suspend/i) {
			notify($ERRORS{'DEBUG'}, 0, "VM is already suspended: $vmx_file_path");
			return 1;
		}
	}
	
	# Get the VM ID
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to power off VM because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/power.suspend $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 400);
	return if !$output;
	
	# Expected output if the VM was not previously suspended:
	# Suspending VM:
	
	# Expected output if the VM was previously suspended or powered off:
	# Suspending VM:
	# Suspend failed
	
	if (!grep(/Suspending VM/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to suspend VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}

	# Get the task ID
	my @task_ids = $self->_get_task_ids($vmx_file_path, 'suspend');
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to suspend the VM");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_ids[0])) {
		notify($ERRORS{'OK'}, 0, "suspended VM: $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to suspend VM: $vmx_file_path, the vim power off task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
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
	
	# The output of 'vim-cmd hostsvc/datastorebrowser/disksearch' differs for VMware Server 2.x and ESXi
	# The value of 'thin' is not returned if disksearch is run under ESXi
	my $vmware_product_name = $self->get_vmhost_product_name();
	my $vim_cmd_arguments;
	if ($vmware_product_name =~ /esx/i) {
		$vim_cmd_arguments = "hostsvc/datastorebrowser/search 0 \"$vmdk_directory_datastore_path\"";
	}
	else {
		$vim_cmd_arguments = "hostsvc/datastorebrowser/disksearch \"$vmdk_directory_datastore_path\"";
	}
	
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Expected output:
	#(vim.host.DatastoreBrowser.SearchResults) {
	#   dynamicType = <unset>,
	#   datastore = 'vim.Datastore:10.10.14.20:/nfs-datastore1',
	#   folderPath = "[nfs-datastore1] vclv17-149_234-v14",
	#   file = (vim.host.DatastoreBrowser.FileInfo) [
	#      (vim.host.DatastoreBrowser.VmDiskInfo) {
	#         dynamicType = <unset>,
	#         path = "vmwarewinxp-base234-v14.vmdk",
	#         fileSize = 5926510592,
	#         modification = "2010-11-24T17:06:44Z",
	#         owner = <unset>,
	#         diskType = "vim.vm.device.VirtualDisk.FlatVer2BackingInfo",
	#         capacityKb = 14680064,
	#         hardwareVersion = 4,
	#         controllerType = "vim.vm.device.VirtualIDEController",
	#         diskExtents = (string) [
	#            "[nfs-datastore1] vclv17-149_234-v14/vmwarewinxp-base234-v14-flat.vmdk"
	#         ],
	#         thin = true,
	#      }
	#   ],
	#}


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
		
		# Return 'thin' if thin is set to true
		my ($thin) = $disk_info =~ /\sthin\s*=\s*(.+)/i;
		if (defined($thin) && $thin =~ /true/) {
			$disk_type = 'thin';
		}
		
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
	if ($network_info) {
		notify($ERRORS{'DEBUG'}, 0, "network info:\n$network_info");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve network info, vim-cmd arguments: '$vim_cmd_arguments', $exit_status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
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

=head2 create_snapshot

 Parameters  : $vmx_file_path, $name (optional)
 Returns     : boolean
 Description : Creates a snapshot of the VM.

=cut

sub create_snapshot {
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
	
	my $snapshot_name = shift || ("VCL: " . convert_to_datetime());
	
	# Get the VM ID
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to create snapshot because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/snapshot.create $vm_id '$snapshot_name'";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	notify($ERRORS{'DEBUG'}, 0, "create snapshot output:\n" . join("\n", @$output));
	
	if (grep(/failed|invalid/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create snapshot of VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	# Get the task ID
	my @task_ids = $self->_get_task_ids($vmx_file_path, 'createSnapshot');
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to create snapshot");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_ids[0])) {
		notify($ERRORS{'OK'}, 0, "created snapshot of VM: $vmx_file_path, snapshot name: $snapshot_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create snapshot VM: $vmx_file_path, the vim task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 remove_snapshots

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Removes all snapshots for a VM.

=cut

sub remove_snapshots {
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
		notify($ERRORS{'WARNING'}, 0, "unable to create snapshot because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/snapshot.removeall $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 7200);
	return if !$output;
	
	notify($ERRORS{'DEBUG'}, 0, "remove snapshots output:\n" . join("\n", @$output));
	
	if (grep(/failed|invalid/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to remove snapshots for VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	# Get the task ID
	my @task_ids = $self->_get_task_ids($vmx_file_path, 'removeAllSnapshots');
	if (!@task_ids) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve the ID of the task created to remove snapshots");
		return;
	}
	
	# Wait for the task to complete
	if ($self->_wait_for_task($task_ids[0], 7200)) {
		notify($ERRORS{'OK'}, 0, "removed snapshots for VM: $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to remove snapshots for VM: $vmx_file_path, the vim task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 snapshot_exists

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Determines if a snapshot exists for the VM.

=cut

sub snapshot_exists {
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
		notify($ERRORS{'WARNING'}, 0, "unable to determine if snapshot exists because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/snapshot.get $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	notify($ERRORS{'DEBUG'}, 0, "snapshot.get output:\n" . join("\n", @$output));
	
	if (grep(/failed|invalid/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if snapshot exists for VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	# Expected output if shapshot exists:
	# Get Snapshot:
	# |-ROOT
	# --Snapshot Name        : 1311966951
	# --Snapshot Desciption  :
	# --Snapshot Created On  : 7/29/2011 19:15:59
	# --Snapshot State       : powered off
	
	# Expected output if snapshot does not exist:
	# Get Snapshot:

	if (grep(/-ROOT/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "snapshot exists for VM $vmx_file_path");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "snapshot does NOT exist for VM $vmx_file_path");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_core_count

 Parameters  : none
 Returns     : integer
 Description : Retrieves the quantitiy of CPU cores the VM host has.

=cut

sub get_cpu_core_count {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vim_cmd_arguments = "hostsvc/hosthardware";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The CPU info should be contained in the output:
	#	cpuInfo = (vim.host.CpuInfo) {
	#      dynamicType = <unset>,
	#      numCpuPackages = 2,
	#      numCpuCores = 8,
	#      numCpuThreads = 8,
	#      hz = 2000070804,
	#   },
	
	my ($cpu_cores_line) = grep(/^\s*numCpuCores\s*=/i, @$output);
	if (!$cpu_cores_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host $vmhost_hostname CPU core count, output does not contain a 'numCpuCores =' line:\n" . join("\n", @$output));
		return;
	}
	elsif ($cpu_cores_line =~ /(\d+)/) {
		my $cpu_core_count = $1;
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM host $vmhost_hostname CPU core count: $cpu_core_count");
		return $cpu_core_count;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine VM host $vmhost_hostname CPU core count from line: $cpu_cores_line");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_speed

 Parameters  : none
 Returns     : integer
 Description : Retrieves the speed of the VM host's CPUs in MHz.

=cut

sub get_cpu_speed {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vim_cmd_arguments = "hostsvc/hosthardware";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The CPU info should be contained in the output:
	#	cpuInfo = (vim.host.CpuInfo) {
	#      dynamicType = <unset>,
	#      numCpuPackages = 2,
	#      numCpuCores = 8,
	#      numCpuThreads = 8,
	#      hz = 2000070804,
	#   },
	
	my ($hz_line) = grep(/^\s*hz\s*=/i, @$output);
	if (!$hz_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host $vmhost_hostname CPU speed, output does not contain a 'hz =' line:\n" . join("\n", @$output));
		return;
	}
	elsif ($hz_line =~ /(\d+)/) {
		my $mhz = int($1 / 1000000);
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM host $vmhost_hostname CPU speed: $mhz MHz");
		return $mhz;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine VM host $vmhost_hostname CPU speed from line: $hz_line");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_total_memory

 Parameters  : none
 Returns     : integer
 Description : Retrieves the VM host's total memory capacity in MB.

=cut

sub get_total_memory {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vim_cmd_arguments = "hostsvc/hosthardware";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The following line should be contained in the output:
	#	 memorySize = 17178869760,
	
	my ($memory_size_line) = grep(/^\s*memorySize\s*=/i, @$output);
	if (!$memory_size_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM host $vmhost_hostname total memory capacity, output does not contain a 'memorySize =' line:\n" . join("\n", @$output));
		return;
	}
	elsif ($memory_size_line =~ /(\d+)/) {
		my $memory_mb = int($1 / 1024 / 1024);
		notify($ERRORS{'DEBUG'}, 0, "retrieved VM host $vmhost_hostname total memory capacity: $memory_mb MB");
		return $memory_mb;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine VM host $vmhost_hostname total memory capacity from line: $memory_size_line");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_license_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves the license information from the host. A hash reference
               is returned:
               {
                 "name" => "vSphere 4 Hypervisor",
                 "properties" => {
                   "FileVersion" => "4.1.1.0",
                   "LicenseFilePath" => [
                     "/usr/lib/vmware/licenses/site/license-esx-40-e1-4core-200803",
                     ...
                     "/usr/lib/vmware/licenses/site/license-esx-40-e9-vm-200803"
                   ],
                   "ProductName" => "VMware ESX Server",
                   "ProductVersion" => "4.0",
                   "count_disabled" => "This license is unlimited",
                   "feature" => {
                     "maxRAM:256g" => "Up to 256 GB of memory",
                     "vsmp:4" => "Up to 4-way virtual SMP"
                   }
                 },
                 "serial" => "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX",
                 "total" => 0,
                 "unit" => "cpuPackage:6core",
                 "used" => 2
               }

=cut

sub get_license_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{license_info} if $self->{license_info};
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vim_cmd_arguments = "vimsvc/license --show";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# Typical output:
	# [200] Sending request for installed licenses...[200] Complete, result is:
	#   serial: XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
	#   vmodl key: esxBasic
	#   name: vSphere 4 Hypervisor
	#   total: 0
	#   used:  2
	#   unit: cpuPackage:6core
	#   Properties:
	#     [ProductName] = VMware ESX Server
	#     [ProductVersion] = 4.0
	#     [count_disabled] = This license is unlimited
	#     [feature] = maxRAM:256g ("Up to 256 GB of memory")
	#     [feature] = vsmp:4 ("Up to 4-way virtual SMP")
	#     [FileVersion] = 4.1.1.0
	#     [LicenseFilePath] = /usr/lib/vmware/licenses/site/license-esx-40-e1-4core-200803
	#	  ...
	# [200] End of report.
	
	my $license_info;
	for my $line (@$output) {
		
		# Find lines formatted as 'property: value'
		if ($line =~ /^\s*(\w+):\s+(.+)$/) {
			$license_info->{$1} = $2;
			next;
		}
		
		# Find '[feature] = ' lines
		elsif ($line =~ /\[feature\]\s*=\s*([^\s]+)\s+\(\"(.+)\"\)/) {
			my $feature_name = $1;
			my $feature_description = $2;
			$license_info->{properties}{feature}{$feature_name} = $feature_description;
		}
		
		# Find '[LicenseFilePath] = ' lines
		elsif ($line =~ /\[LicenseFilePath\]\s*=\s*(.+)/) {
			# Leave this out of data for now, not used anywhere, clutters display of license info
			#push @{$license_info->{properties}{LicenseFilePath}}, $1;
		}
		
		# Find '[xxx] = ' lines
		elsif ($line =~ /\[(\w+)\]\s*=\s*(.+)$/) {
			my $property = $1;
			my $value = $2;
			$license_info->{properties}{$property} = $value;
		}
	}
	
	# Make sure something was found
	if (!$license_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse 'vim-cmd $vim_cmd_arguments' output:\n" . join("\n", @$output));
		return;
	}
	
	$self->{license_info} = $license_info;
	notify($ERRORS{'DEBUG'}, 0, "retrieved VM host license info:\n" . format_data($license_info));
	return $license_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_config_option_descriptor_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about the VM configuration options that are
               supported on the host.
               }
                  "vmx-09" => {
                    "createSupported" => "true",
                    "defaultConfigOption" => "false",
                    "description" => "ESXi 5.1 virtual machine",
                    "dynamicType" => "<unset>",
                    "key" => "vmx-09",
                    "runSupported" => "true",
                    "upgradeSupported" => "true"
                  },
                  "vmx-10" => {
                    "createSupported" => "true",
                    "defaultConfigOption" => "true",
                    "description" => "ESXi 5.5 virtual machine",
                    "dynamicType" => "<unset>",
                    "key" => "vmx-10",
                    "runSupported" => "true",
                    "upgradeSupported" => "true"
                  }
               }

=cut

sub get_config_option_descriptor_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vim_cmd_arguments = "solo/querycfgoptdesc";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	my $result = $self->_parse_vim_cmd_output($output);
	if (!$result) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option descriptor info");
		return;
	}
	
	my $type = ref($result);
	if (!$type) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option descriptor info, parsed result is not a reference:\n" . $result);
		return;
	}
	
	# If a single entry is returned a hash reference may be returned instead of an array, convert it to an array
	if ($type eq 'HASH') {
		$result = [$result];
	}
	
	my $config_option_descriptor_info = {};
	for my $config_option_descriptor (@$result) {
		my $key = $config_option_descriptor->{key};
		if (!defined($key)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option descriptor info, result does not contain a 'key' element:\n" . format_data($config_option_descriptor));
			return;
		}
		$config_option_descriptor_info->{$key} = $config_option_descriptor;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved config option descriptor info:\n" . format_data($config_option_descriptor_info));
	return $config_option_descriptor_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_config_option_info

 Parameters  : $key
 Returns     : hash reference
 Description : Retrieves info about the VM configuration options available for a
               particular hardware version key (ex: vmx-09).

=cut

sub get_config_option_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($key) = @_;
	if (!defined($key)) {
		notify($ERRORS{'WARNING'}, 0, "key argument was not provided");
		return;
	}
	
	my $vim_cmd_arguments = "solo/querycfgopt $key";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	my $result = $self->_parse_vim_cmd_output($output);
	if (!$result) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option info for $key");
		return;
	}
	
	return $result;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_config_option_guest_os_info

 Parameters  : $key
 Returns     : hash reference
 Description : Retrieves info about the guest OS's supported for the given key
               (ex: vmx-09).
					{
					  "windows8_64Guest" => {
						 "family" => "windowsGuest",
						 "fullName" => "Microsoft Windows 8 (64-bit)",
						 "id" => "windows8_64Guest",
						 ...
					  },
					  "windows8Server64Guest" => {
					  ...
					  },
					  ...
					}

=cut

sub get_config_option_guest_os_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($key) = @_;
	if (!defined($key)) {
		notify($ERRORS{'WARNING'}, 0, "key argument was not provided");
		return;
	}
	
	my $config_option_info = $self->get_config_option_info($key) || return;
	
	my $guest_os_descriptor_array_ref = $config_option_info->{guestOSDescriptor};
	if (!defined($guest_os_descriptor_array_ref)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info, config option info does not contain a 'guestOSDescriptor' key:\n" . format_data($config_option_info));
		return;
	}
	
	my $type = ref($guest_os_descriptor_array_ref);
	if (!$type || $type ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info, guestOSDescriptor value is not an array reference:\n" . format_data($guest_os_descriptor_array_ref));
		return;
	}
	
	my $config_option_guest_os_info = {};
	for my $guest_os_descriptor (@$guest_os_descriptor_array_ref) {
		my $id = $guest_os_descriptor->{id};
		if (!defined($id)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info, guest OS descriptor does not contain an 'id' key:\n" . format_data($guest_os_descriptor));
			return;
		}
		$config_option_guest_os_info->{$id} = $guest_os_descriptor;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved config option guest OS info:\n" . format_data($config_option_guest_os_info));
	return $config_option_guest_os_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _print_compatible_guest_os_hardware_versions

 Parameters  : $print_code (optional)
 Returns     : true
 Description : Used for development/testing only. Prints list of possible
               guestOS values.

=cut

sub _print_compatible_guest_os_hardware_versions {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $print_code = shift;
	
	my $guest_os_info = {};
	my $config_option_descriptor_info = $self->get_config_option_descriptor_info();
	for my $version_key (sort keys %$config_option_descriptor_info) {
		my $config_option_guest_os_info = $self->get_config_option_guest_os_info($version_key);
		for my $guest_os (keys %$config_option_guest_os_info) {
			$guest_os_info->{$guest_os}{$version_key} = 1;
		}
	}
	
	for my $guest_os (sort keys %$guest_os_info) {
		if ($print_code) {
			print "'$guest_os' => { ";
			for my $version_key (sort keys %{$guest_os_info->{$guest_os}}) {
				$version_key =~ s/vmx-0?//;
				print "$version_key => 1, ";
			}
			print "},\n";
		}
		else {
			my $length = length($guest_os);
			print "$guest_os ";
			print (' ' x (25-$length));
			print (' ' x (50-scalar(@{$guest_os_info->{$guest_os}})*8));
			print join(", ", sort keys %{$guest_os_info->{$guest_os}});
			print "\n";
		}
	}
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _parse_vim_cmd_output

 Parameters  : $vim_cmd_output
 Returns     : varies
 Description : Parses the Data::Dumper-like output returned for some vim-cmd
               commands and attempts to parse the output into a data structure.

=cut

sub _parse_vim_cmd_output {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($argument) = @_;
	if (!defined($argument)) {
		notify($ERRORS{'WARNING'}, 0, "vim-cmd output argument was not supplied");
		return;
	}
	my @lines;
	if (my $type = ref($argument)) {
		if ($type eq 'ARRAY') {
			@lines = @$argument;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "argument is a $type reference, only an ARRAY reference or string are supported");
			return;
		}
	}
	elsif (scalar(@_) > 1) {
		@lines = @_;
	}
	else {
		@lines = split("\n", $argument);
	}
	
	my $statement;
	my $numbered_statement;
	my $line_number = 0;
	for my $line (@lines) {
		# Skip blank lines
		if ($line !~ /\S/) {
			next;
		}
		
		$line_number++;
		
		# Remove trailing newlines
		$line =~ s/\n+$//g;
		
		# Remove class names at beginning of line surrounded by parenthesis
		# '(vim.vm.device.VirtualPointingDevice) {' --> '{'
		$line =~ s/^(\s*)\([^\)]*\)\s*/$1/g;
		
		# Remove class names after an equals sign
		# 'backing = (vim.vm.device.VirtualDevice.BackingInfo) null,' --> 'backing = null'
		$line =~ s/(=\s+)\([^\)]+\)\s*//g;
		
		# Surround values after equals sign in quotes
		# 'value = xxx,' --> 'value = "xxx",'
		$line =~ s/(=\s+)([^"].+),/$1"$2",/g;
		
		# Change 'null' to undef and add =>
		# 'busSlotOption null,' --> 'busSlotOption => undef,'
		$line =~ s/(\w\s+)null,/$1 => undef,/g;
		
		# Change = to =>
		$line =~ s/=(\s+.+),/=>$1,/g;
		
		# Add => before array and hash references
		# 'guestOSDescriptor [' --> 'guestOSDescriptor => ['
		$line =~ s/(\w\s+)([\[{])/$1=>$2/g;
		
		$statement .= "$line\n";
		$numbered_statement .= "$line_number:$line\n";
	}
	
	# The statement variable should contain a valid definition
	my $result = eval($statement);
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse vim-cmd output, error:\n$EVAL_ERROR\n$numbered_statement");
		return;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "parsed vim-cmd output:\n" . format_data($result));
		return $result;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the VIM_SSH object. Displays the number of times vim-cmd
               was called for performance tuning/debugging purposes.

=cut

sub DESTROY {
	my $self = shift;
	my $address = sprintf('%x', $self);
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	notify($ERRORS{'DEBUG'}, 0, "vim-cmd call count: $self->{vim_cmd_calls}") if ($self->{vim_cmd_calls});
} ## end sub DESTROY

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
