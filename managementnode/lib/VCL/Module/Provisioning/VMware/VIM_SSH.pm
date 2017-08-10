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

###############################################################################
package VCL::Module::Provisioning::VMware::VIM_SSH;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning::VMware::VMware);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use English '-no_match_vars';
use VCL::utils;

###############################################################################

=head1 PRIVATE OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 _run_vim_cmd

 Parameters  : $vim_arguments, $timeout_seconds (optional), $attempt_limit (optional)
 Returns     : array ($exit_status, $output)
 Description : Runs vim-cmd command on the VMware host. This was designed to
               allow it to handle most of the error checking.
               
               By default, 5 attempts are made.
               
               If the exit status of the vim-cmd command is 0 after any attempt,
               $exit_status and $output are returned to the calling subroutine.
               
               If the exit $attempt_limit > 1 and the status is not 0 after all
               attempts are made, undefined is returned. This allows the calling
               subroutine to simply check if result is true if it does not care
               about the output.
               
               There is a special condition if the $attempt_limit is 1 and the
               exit status is not 0. $exit_status and $output are always
               returned so calling subroutine can handle the logic.

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
	my $attempt_limit = shift || 5;
	
	my $request_state_name = $self->data->get_request_state_name();
	my $vmhost_computer_name = $self->vmhost_os->data->get_computer_short_name();
	
	my $command = "$self->{vim_cmd} $vim_arguments";
	
	my $attempt = 0;
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
		
		#my $register_semaphore;
		#if ($command =~ /(getallvms|register)/) {
		#	$register_semaphore = $self->get_semaphore($vmhost_computer_name, 120, 1);
		#	if (!$register_semaphore) {
		#		next ATTEMPT;
		#	}
		#}
		
		my ($exit_status, $output) = $self->vmhost_os->execute({
			'command' => $command,
			'display_output' => 0,
			'timeout_seconds' => $timeout_seconds,
			#'max_attempts' => 1
		});
		
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
		elsif (grep(/^(vim-cmd:|Killed|terminate called|Aborted|what\()/i, @$output)) {
			# terminate called after throwing an instance of 'std::bad_alloc'
			# what():  std::bad_alloc
			# Aborted
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: failed to execute command on VM host $vmhost_computer_name: $command, exit status: $exit_status, output:\n" . join("\n", @$output));
			next ATTEMPT;
		}
		elsif ($exit_status != 0) {
			if ($attempt_limit == 1) {
				notify($ERRORS{'DEBUG'}, 0, "command failed on VM host $vmhost_computer_name, not making another attempt because attempt limit argument is set to $attempt_limit, error checking will be done by calling subroutine, command: $command, exit status: $exit_status, output:\n" . join("\n", @$output));
				return ($exit_status, $output);
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "attempt $attempt/$attempt_limit: command failed on VM host $vmhost_computer_name: $command, exit status: $exit_status, output:\n" . join("\n", @$output));
				next ATTEMPT;
			}
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->{vm_id}{$vmx_file_path} if $self->{vm_id}{$vmx_file_path};
	
	# Get the VM IDs and vmx paths
	my $vm_list = $self->_get_vm_list();
	if (!defined($vm_list)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine VM ID, failed to retrieve list of registered VMs and their IDs");
		return;
	}
	
	for my $vm_id (keys %$vm_list) {
		if ($vm_list->{$vm_id} && $vmx_file_path eq $vm_list->{$vm_id}) {
			$self->{vm_id}{$vmx_file_path} = $vm_id;
			return $vm_id;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine VM ID, vmx file is not registered: $vmx_file_path, registered VMs:\n" . format_data($vm_list));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Get the vmx file path argument
	my $vmx_file_path = shift || $self->get_vmx_file_path();
	if (!$vmx_file_path) {
		notify($ERRORS{'WARNING'}, 0, "vmx file path argument could not be determined");
		return;
	}
	
	my $vm_id = $self->_get_vm_id($vmx_file_path) || return;
	
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
	
	my $vm_summary_info = $self->_parse_vim_cmd_output($output);
	if (defined($vm_summary_info->{'vim.vm.Summary'})) {
		return $vm_summary_info->{'vim.vm.Summary'};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve summary of VM: $vmx_file_path, parsed output does not contain a 'vim.vm.Summary' key:\n" . format_data($vm_summary_info));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
			elsif ($error_message =~ /state of the virtual machine has not changed since the last snapshot/i) {
				# Snapshot may fail if VM is suspended and snapshot was already taken after suspension, message will be:
				# message = "An error occurred while taking a snapshot: The state of the virtual machine has not changed since the last snapshot operation."
				notify($ERRORS{'DEBUG'}, 0, "snapshot task is not necessary: $task_id, message: $error_message");
				return 1;
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

###############################################################################

=head1 API OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	my @vmx_paths = sort { lc($a) cmp lc($b) } values(%$vm_list);
	
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@vmx_paths) . " registered VMs");
	return @vmx_paths;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	my ($vmx_file_path, $is_retry_attempt) = @_;
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
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 360, 1);
	return if !$output;
	
	# Expected output if the VM was not previously powered on:
	# Powering on VM:
	
	# Expected output if the VM was previously powered on:
	
	# Old versions of ESXi? (unsure about when the output changed)
	# Powering on VM:
	# (vim.fault.InvalidPowerState) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   requestedState = "poweredOn",
	#   existingState = "poweredOn",
	#   msg = "The attempted operation cannot be performed in the current state (Powered On).",
	# }
	
	# ESXi 6.0, 6.5:
	# Powering on VM:
	# Power on failed
	
	if (grep(/existingState = "poweredOn"/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "VM is already powered on: $vmx_file_path");
		return 1;
	}
	elsif (!grep(/Powering on VM/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to power on VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/failed/i, @$output)) {
		# Power on failed but no indication that VM is already powered on from the output, check the power state
		# Command will occasionally incorrectly report that it failed but the VM is actually powered on
		my $power_state = $self->get_vm_power_state($vmx_file_path);
		if ($power_state && $power_state =~ /on/i) {
			notify($ERRORS{'OK'}, 0, "power on failed because VM is already powered on: $vmx_file_path");
			return 1;
		}
		elsif (!$is_retry_attempt) {
			# Make one more attempt, pass it the $is_retry_attempt argument to avoid an endless loop
			return $self->vm_power_on($vmx_file_path, 1);
		}
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

#//////////////////////////////////////////////////////////////////////////////

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
	
	# ESXi 6.0, 6.5:
	# Powering off VM:
	# Power off failed
	
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

#//////////////////////////////////////////////////////////////////////////////

=head2 vm_suspend

 Parameters  : $vmx_file_path
 Returns     : boolean
 Description : Suspends the VM indicated by the vmx file path argument.

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
	
	notify($ERRORS{'DEBUG'}, 0, "suspending VM: $vmx_file_path ($vm_id)");
	my $start_time = time;
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
		my $duration = (time - $start_time);
		notify($ERRORS{'OK'}, 0, "suspended VM: $vmx_file_path, took $duration seconds");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to suspend VM: $vmx_file_path, the vim power off task did not complete successfully, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 60, 1);
	return if !$output;
	
	# Note: registervm does not produce any output if it was successful
	
	# Expected output if the vmx file path does not exist:
	# (vim.fault.NotFound) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   msg = "The object or item referred to could not be found.",
	# }
	
	if (grep(/vim.fault.NotFound/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM, vmx file was not found: $vmx_file_path, output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/vim.fault.AlreadyExists/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to register VM on the 1st attempt, an existing invalid VM using the same vmx file path may already already be registered, output:\n" . join("\n", @$output));
		
		# If an "invalid" VM exists using the same .vmx path, this fault will be generated:
		#    (vim.fault.AlreadyExists) {
		#    faultCause = (vmodl.MethodFault) null,
		#    name = "51",
		#    msg = "The specified key, name, or identifier '51' already exists."
		my ($vm_id) = join("\n", @$output) =~ /name\s*=\s*"(\d+)"/;
		if ($vm_id) {
			if ($self->vm_unregister($vm_id)) {
				notify($ERRORS{'DEBUG'}, 0, "unregistered existing invalid VM $vm_id, making another attempt to register VM: $vmx_file_path");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to register VM: $vmx_file_path, unable to unregister existing invalid VM $vm_id");
				return;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to register VM: $vmx_file_path, ID of existing invalid VM could not be determined, was expecting a line beginning with 'name = \"<ID>\"' in output:\n" . join("\n", @$output));
			return;
		}
	}
	
	if (grep(/fault/i, @$output)) {
		# Only made 1 attempt so far, try again if fault occurred, allow 4 more attempts
		($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 60, 4);
		return if !$output;
	}
	
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

#//////////////////////////////////////////////////////////////////////////////

=head2 vm_unregister

 Parameters  : $vm_identifier 
 Returns     : boolean
 Description : Unregisters the VM indicated by the argument which may either be
               the .vmx file path or VM ID.

=cut

sub vm_unregister {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Note: allow the VM ID to be passed in case the .vmx file path cannot be determined
	# This allows an invalid VM with a missing .vmx file to be unregistered
	
	my $vm_identifier = shift;
	if (!$vm_identifier) {
		notify($ERRORS{'WARNING'}, 0, "VM identifier argument was not supplied");
		return;
	}
	
	my $vm_id;
	my $vmx_file_path;
	if ($vm_identifier =~ /^\d+$/) {
		$vm_id = $vm_identifier;
	}
	else {
		# Argument should be the vmx file path
		$vmx_file_path = $vm_identifier;
		
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
		
		$vm_id = $self->_get_vm_id($vmx_file_path);
		if (!defined($vm_id)) {
			notify($ERRORS{'OK'}, 0, "unable to unregister VM because VM ID could not be determined for vmx path argument: $vmx_file_path");
			return;
		}
	}
	
	my $vim_cmd_arguments = "vmsvc/unregister $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	
	# Delete cached .vmx - VM ID mapping if previously retrieved
	delete $self->{vm_id}{$vm_identifier};
	
	return if !$output;
	
	# Expected output if the VM is not registered:
	# (vim.fault.NotFound) {
	#   dynamicType = <unset>,
	#   faultCause = (vmodl.MethodFault) null,
	#   msg = "Unable to find a VM corresponding to "/vmfs/volumes/nfs-datastore/vm-ark-mcnc-9_234-v12/vm-ark-mcnc-9_234-v12.vmx"",
	# }
	
	if (grep(/fault/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM, VIM command arguments: '$vim_cmd_arguments'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Check to make sure the VM is not registered
	if ($vmx_file_path && $self->is_vm_registered($vmx_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister VM: $vmx_file_path (ID: $vm_id), it still appears to be registered");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "unregistered VM: $vm_identifier");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
		
		my ($hardware_version) = $disk_info =~ /\shardwareVersion\s*=\s*(\d+)/ig;
		if (!$hardware_version) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine disk hardware version, disk path: $disk_path, disk info section from vim-cmd $vim_cmd_arguments output:\n$disk_info");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "retrieved hardware version for $disk_path: '$hardware_version'");
			return $hardware_version;
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "unable to determine hardware version for disk: $vmdk_file_path, vim-cmd $vim_cmd_arguments output:\n" . join("\n", @$output));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments, 60, 1);
	return if !$output;
	
	notify($ERRORS{'DEBUG'}, 0, "create snapshot output:\n" . join("\n", @$output));
	
	# IMPORTANT: Don't check for 'failed' in the output, it may contain failed but the snapshot is not necessary:
	# Snapshot not taken since the state of the virtual machine has not changed since the last snapshot operation.
	#if (grep(/failed|invalid/i, @$output)) {
	#	notify($ERRORS{'WARNING'}, 0, "failed to create snapshot of VM $vmx_file_path, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
	#	return;
	#}
	
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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->{config_option_descriptor_info} if $self->{config_option_descriptor_info};
	
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
	$self->{config_option_descriptor_info} = $config_option_descriptor_info;
	return $config_option_descriptor_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_highest_vm_hardware_version_key

 Parameters  : none
 Returns     : string
 Description : Each VMware VM has a hardware version. The versions supported on
               the host depends on the version of VMware. This subroutine
               returns the highest supported version and returns an integer. For
               example vmx-11 is returned for ESXi 6.0.

=cut

sub get_highest_vm_hardware_version_key {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{highest_vm_hardware_version_key} if defined($self->{highest_vm_hardware_version_key});
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $config_option_descriptor_info = $self->get_config_option_descriptor_info();
	
	my $highest_vm_hardware_version_number;
	my $highest_vm_hardware_version_key;
	for my $version_key (sort keys %$config_option_descriptor_info) {
		my ($version_number) = $version_key =~ /-(\d+)$/g;
		if (!$highest_vm_hardware_version_number || $highest_vm_hardware_version_number < $version_number) {
			$highest_vm_hardware_version_number = $version_number;
			$highest_vm_hardware_version_key = $version_key;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "determined highest VM hardware version supported on $vmhost_hostname: $highest_vm_hardware_version_key");
	$self->{highest_vm_hardware_version_key} = $highest_vm_hardware_version_key;
	return $highest_vm_hardware_version_key;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_config_option_info

 Parameters  : $key
 Returns     : hash reference
 Description : Retrieves info about the VM configuration options available for a
					particular hardware version key (ex: vmx-09). A hash reference is
					returned with the following keys:
                  {
                     capabilities = {},
                     datastore = {},
                     defaultDevice = [],
                     description = '',
                     guestOSDefaultIndex = '',
                     guestOSDescriptor = [],
                     hardwareOptions = {},
                     supportedMonitorType = [],
                     supportedOvfEnvironmentTransport = '',
                     supportedOvfInstallTransport = '',
                     version = '',
                  },

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
	
	return $self->{config_option_info}{$key} if defined($self->{config_option_info}{$key});
	
	my $vim_cmd_arguments = "solo/querycfgopt $key";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	my $result = $self->_parse_vim_cmd_output($output);
	if (!$result) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option info for $key");
		return;
	}
	
	if (!defined($result->{'vim.vm.ConfigOption'})) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option info for $key, 'vim.vm.ConfigOption' key does not exist:\n" . format_hash_keys($result));
		return;
	}
	
	$self->{config_option_info}{$key} = $result->{'vim.vm.ConfigOption'};
	return $result->{'vim.vm.ConfigOption'};
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	return $self->{config_option_guest_os_info}{$key} if defined($self->{config_option_guest_os_info}{$key});
	
	my $config_option_info = $self->get_config_option_info($key) || return;
	
	my $guest_os_descriptor_array_ref = $config_option_info->{guestOSDescriptor};
	if (!defined($guest_os_descriptor_array_ref)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info, config option info does not contain a 'guestOSDescriptor' key:\n" . format_hash_keys($config_option_info));
		return;
	}
	
	my $type = ref($guest_os_descriptor_array_ref);
	if (!$type || $type ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info for '$key', guestOSDescriptor value is not an array reference:\n" . format_data($guest_os_descriptor_array_ref));
		return;
	}
	
	my $config_option_guest_os_info = {};
	for my $guest_os_descriptor (@$guest_os_descriptor_array_ref) {
		my $id = $guest_os_descriptor->{id};
		if (!defined($id)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info for '$key', guest OS descriptor does not contain an 'id' key:\n" . format_data($guest_os_descriptor));
			return;
		}
		$config_option_guest_os_info->{$id} = $guest_os_descriptor;
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved config option guest OS info:\n" . format_data($config_option_guest_os_info));
	$self->{config_option_guest_os_info}{$key} = $config_option_guest_os_info;
	return $config_option_guest_os_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_supported_guest_os_ids

 Parameters  : $vm_hardware_version_key (optional)
 Returns     : array
 Description : Retrieves the names of the supported guestOS values for the VM
               hardware version specified by the argument (example: vmx-11). If
               no argument is supplied, the host's highest supported hardware
               version is used.

=cut

sub get_supported_guest_os_ids {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $vm_hardware_version_key = shift;
	if (!defined($vm_hardware_version_key)) {
		$vm_hardware_version_key = $self->get_highest_vm_hardware_version_key();
		if (!defined($vm_hardware_version_key)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine supported guest OS names on $vmhost_hostname, VM hardware version key argument was not provided and highest supported VM hardware version could not be determiend");
			return;
		}
	}
	
	return @{$self->{supported_guest_os_ids}{$vm_hardware_version_key}} if defined($self->{supported_guest_os_ids}{$vm_hardware_version_key});
	
	my $config_option_info = $self->get_config_option_info($vm_hardware_version_key) || return;
	
	my $guest_os_descriptor_array_ref = $config_option_info->{guestOSDescriptor};
	if (!defined($guest_os_descriptor_array_ref)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info, config option info does not contain a 'guestOSDescriptor' key:\n" . format_hash_keys($config_option_info));
		return;
	}
	
	my $type = ref($guest_os_descriptor_array_ref);
	if (!$type || $type ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve config option guest OS info for '$vm_hardware_version_key', guestOSDescriptor value is not an array reference:\n" . format_data($guest_os_descriptor_array_ref));
		return;
	}
	
	my @supported_guest_os_ids;
	for my $guest_os_descriptor (@$guest_os_descriptor_array_ref) {
		my $guest_os_id = $guest_os_descriptor->{id};
		
		# Every name includes "Guest" at the end but this is not in the valid guestOS values
		$guest_os_id =~ s/Guest//;
		
		# Windows server OS's: windows7Server --> windows7srv
		$guest_os_id =~ s/(windows.+)Server/$1srv/;
		
		# windows7_64 --> windows7-64
		# windows8srv64 --> windows8srv-64
		$guest_os_id =~ s/_?(64)/-$1/g;
		
		push @supported_guest_os_ids, $guest_os_id;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved supported guest OS names on $vmhost_hostname, VM hardware version: $vm_hardware_version_key: " . join(",", @supported_guest_os_ids));
	$self->{supported_guest_os_ids}{$vm_hardware_version_key} = \@supported_guest_os_ids;
	return @supported_guest_os_ids;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _print_compatible_guest_os_hardware_versions

 Parameters  : $print_code (optional)
 Returns     : true
 Description : Used for development/testing only. Prints list of possible
               guestOS values.
					asianux3                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					asianux3-64                              vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					asianux4                                        vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					asianux4-64                                     vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					asianux7-64                                                                        vmx-13
					centos                                   vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					centos-64                                vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					centos6                                                                            vmx-13
					centos6-64                                                                         vmx-13
					centos7-64                                                                         vmx-13
					coreos-64                                                            vmx-11 vmx-12 vmx-13
					darwin                                   vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin-64                                vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin10                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin10-64                              vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin11                                        vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin11-64                                     vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin12-64                                            vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					darwin13-64                                                   vmx-10 vmx-11 vmx-12 vmx-13
					darwin14-64                                                          vmx-11 vmx-12 vmx-13
					darwin15-64                                                                 vmx-12 vmx-13
					darwin16-64                                                                        vmx-13
					debian10                                                                           vmx-13
					debian10-64                                                                        vmx-13
					debian4                                  vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian4-64                               vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian5                                  vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian5-64                               vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian6                                  vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian6-64                               vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					debian7                                                       vmx-10 vmx-11 vmx-12 vmx-13
					debian7-64                                                    vmx-10 vmx-11 vmx-12 vmx-13
					debian8                                                              vmx-11 vmx-12 vmx-13
					debian8-64                                                           vmx-11 vmx-12 vmx-13
					debian9                                                                            vmx-13
					debian9-64                                                                         vmx-13
					dos                                      vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					eComStation                              vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					eComStation2                                    vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					fedora                                                               vmx-11 vmx-12 vmx-13
					fedora-64                                                            vmx-11 vmx-12 vmx-13
					freebsd                                  vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					freebsd-64                               vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					netware5                   vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					netware6                   vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					oes                               vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					openServer5                              vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					openServer6                                     vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					opensuse                                                             vmx-11 vmx-12 vmx-13
					opensuse-64                                                          vmx-11 vmx-12 vmx-13
					oracleLinux                              vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					oracleLinux-64                           vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					oracleLinux6                                                                       vmx-13
					oracleLinux6-64                                                                    vmx-13
					oracleLinux7-64                                                                    vmx-13
					os2                                      vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other                      vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other-64                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other24xLinux                            vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other24xLinux-64                         vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other26xLinux                            vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other26xLinux-64                         vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					other3xLinux                                                  vmx-10 vmx-11 vmx-12 vmx-13
					other3xLinux-64                                               vmx-10 vmx-11 vmx-12 vmx-13
					otherLinux                 vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					otherLinux-64                     vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel2                             vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel3                             vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel3-64                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel4                             vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel4-64                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel5                             vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel5-64                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel6                                    vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel6-64                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					rhel7                                                  vmx-09 vmx-10
					rhel7-64                                               vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles                              vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles-64                           vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles10                            vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles10-64                         vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles11                            vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles11-64                         vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					sles12                                                 vmx-09 vmx-10
					sles12-64                                              vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					solaris10                         vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					solaris10-64                      vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					solaris11-64                                    vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					solaris8                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					solaris9                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					ubuntu                            vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					ubuntu-64                         vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					unixWare7                                vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					vmkernel                                 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					vmkernel5                                       vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					vmkernel6                                                            vmx-11 vmx-12 vmx-13
					vmkernel65                                                           vmx-11 vmx-12 vmx-13
					vmwarePhoton-64                                                                    vmx-13
					win2000AdvServ             vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					win2000Pro                        vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					win2000Serv                vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					win31                                    vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					win95                                    vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					win98                                    vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows7                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows7-64                       vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows7srv-64                    vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows8                                        vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows8-64                                     vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows8srv-64                                  vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					windows9                                                      vmx-10 vmx-11 vmx-12 vmx-13
					windows9-64                                                   vmx-10 vmx-11 vmx-12 vmx-13
					windows9srv-64                                                vmx-10 vmx-11 vmx-12 vmx-13
					winLonghorn                       vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winLonghorn-64                    vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetBusiness             vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetDatacenter           vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetDatacenter-64               vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetEnterprise           vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetEnterprise-64               vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetStandard             vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetStandard-64                 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNetWeb                  vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winNT                      vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winVista                          vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winVista-64                       vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winXPPro                   vmx-03 vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13
					winXPPro-64                       vmx-04 vmx-07 vmx-08 vmx-09 vmx-10 vmx-11 vmx-12 vmx-13

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
		my @guest_os_ids = $self->get_supported_guest_os_ids($version_key);
		for my $guest_os_id (@guest_os_ids) {
			$guest_os_info->{$guest_os_id}{$version_key} = 1;
		}
	}
	
	my $version_key_count = scalar(keys %$config_option_descriptor_info);
	
	for my $guest_os (sort {lc($a) cmp lc($b)} keys %$guest_os_info) {
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
			my $guest_os_version_key_count = scalar(keys %{$guest_os_info->{$guest_os}});
			print "$guest_os ";
			print (' ' x (25-$length));
			
			for my $version_key (sort keys %$config_option_descriptor_info) {
				print " ";
				if ($guest_os_info->{$guest_os}{$version_key}) {
					print "$version_key";
				}
				else {
					print "      ";
				}
			}
			print "\n";
		}
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_host_capability_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about the capabilities of the VMware host.
               A hash reference is returned similar to:
                  {
                    "bootOptionsSupported" => "true",
                    "bootRetryOptionsSupported" => "true",
                    "canConnectUSBDevices" => "<unset>",
                    "changeTrackingSupported" => "false",
                    "consolePreferencesSupported" => "true",
                    "cpuFeatureMaskSupported" => "true",
                    "disableSnapshotsSupported" => "false",
                    "diskSharesSupported" => "true",
                    "featureRequirementSupported" => "true",
                    "guestAutoLockSupported" => "true",
                    "hostBasedReplicationSupported" => "true",
                    "lockSnapshotsSupported" => "false",
                    "memoryReservationLockSupported" => "true",
                    "memorySnapshotsSupported" => "true",
                    "messageBusSupported" => "true",
                    "multipleCoresPerSocketSupported" => "true",
                    "multipleSnapshotsSupported" => "true",
                    "nestedHVSupported" => "true",
                    "npivWwnOnNonRdmVmSupported" => "true",
                    "perVmEvcSupported" => "<unset>",
                    "poweredOffSnapshotsSupported" => "true",
                    "poweredOnMonitorTypeChangeSupported" => "true",
                    "quiescedSnapshotsSupported" => "true",
                    "recordReplaySupported" => "true",
                    "revertToSnapshotSupported" => "true",
                    "s1AcpiManagementSupported" => "true",
                    "seSparseDiskSupported" => "true",
                    "secureBootSupported" => "<unset>",
                    "settingDisplayTopologyModesSupported" => "true",
                    "settingDisplayTopologySupported" => "false",
                    "settingScreenResolutionSupported" => "true",
                    "settingVideoRamSizeSupported" => "true",
                    "snapshotConfigSupported" => "true",
                    "snapshotOperationsSupported" => "true",
                    "swapPlacementSupported" => "true",
                    "toolsAutoUpdateSupported" => "false",
                    "toolsRebootPredictSupported" => "<unset>",
                    "toolsSyncTimeSupported" => "true",
                    "vPMCSupported" => "true",
                    "virtualMmuUsageSupported" => "true",
                    "vmNpivWwnDisableSupported" => "true",
                    "vmNpivWwnSupported" => "true",
                    "vmNpivWwnUpdateSupported" => "true",
                    "vmfsNativeSnapshotSupported" => "false"
                  }

=cut

sub get_host_capability_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	if (defined($self->{host_capability_info})) {
		return $self->{host_capability_info};
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_short_name();
	
	my $version_key = $self->get_highest_vm_hardware_version_key();
	if (!$version_key) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve host capability info from $vmhost_computer_name, failed to retrieve highest supported virtual machine hardware");
		return;
	}
	
	my $config_option_info = $self->get_config_option_info($version_key);
	if (!$config_option_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve host capability info from $vmhost_computer_name, failed to retrieve host config option info");
		return;
	}
	
	if ($config_option_info->{capabilities}) {
		$self->{host_capability_info} = $config_option_info->{capabilities};
		return $self->{host_capability_info};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve host capability info from $vmhost_computer_name, config option info does not contain a 'capabilities' key:\n" . format_hash_keys($config_option_info));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_nested_virtualization_supported

 Parameters  : none
 Returns     : boolean
 Description : Determines whether or not the VMware host supports nested
               hardware-assisted virtualization.

=cut

sub is_nested_virtualization_supported {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_short_name();
	
	my $host_capability_info = $self->get_host_capability_info();
	if (!$host_capability_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if nested virtualization is supported on $vmhost_computer_name, failed to retrieve host capability info");
		return;
	}
	
	if (!defined($host_capability_info->{nestedHVSupported})) {
		notify($ERRORS{'DEBUG'}, 0, "nested virtualization is NOT supported on $vmhost_computer_name, host capability info does not contain a 'nestedHVSupported' key:\n" . format_hash_keys($host_capability_info));
		return 0;
	}
	elsif ($host_capability_info->{nestedHVSupported} !~ /true/i) {
		notify($ERRORS{'DEBUG'}, 0, "nested virtualization is NOT supported on $vmhost_computer_name, nestedHVSupported value: $host_capability_info->{nestedHVSupported}");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "nested virtualization is supported on $vmhost_computer_name, nestedHVSupported value: $host_capability_info->{nestedHVSupported}");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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
	
	my ($argument, $debug) = @_;
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
		
		# Some commands such as 'vim-cmd vmsvc/get.summary' add this to the beginning:
		# Listsummary:
		if ($line =~ /:$/) {
			notify($ERRORS{'DEBUG'}, 0, "skipping line: $line");
			next;
		}
		
		$line_number++;
		
		my $original_line = $line;
		
		# Remove trailing newlines
		$line =~ s/\n+$//g;
		
		# Remove class names in parenthesis from beginning class name of indented lines
		# '   (vim.vm.device.xxx) {' --> '   {'
		$line =~ s/^(\s+)\([^\)]*\)\s*/$1/g;
		
		# Remove class names at beginning of a line surrounded by parenthesis
		# '(vim.vm.device.VirtualPointingDevice) {' --> 'vim.vm.device.VirtualPointingDevice => {'
		$line =~ s/^\(([^\)]+)\)\s*{/$1 => {/gx;
		
		# Remove class names 
		# '(vim.vm.ConfigOptionDescriptor) ['
		$line =~ s/^\([^\)]+\)\s*(\[)/$1/gx;
		
		# Add comma to lines containing a closing curly bracket
		# '   }' --> '   },'
		$line =~ s/^(\s*)}\s*$/$1},/g;
		
		# Remove class names after an equals sign
		# 'backing = (vim.vm.device.VirtualDevice.BackingInfo) null,' --> 'backing = null'
		$line =~ s/(=\s+)\([^\)]+\)\s*/$1/g;
		
		# Add comma to lines containing = sign which don't end with a comma
		# 'value = xxx' --> 'value = xxx,'
		$line =~ s/(=\s+[^,]+[\w>])$/$1,/g;
		
		# Surround values after equals sign in single quotes
		# value = xxx,   --> value = 'xxx',
		# value = "xxx", --> value = 'xxx',
		$line =~ s/(=\s+)["']?([^"']+)["']?,/$1'$2',/g;
		
		# Surround values before equals sign in single quotes
		$line =~ s/^(\s*)["']?([^\s"']+)["']?(\s*=)/$1'$2'$3/g;
		
		# Change 'null' to undef and add =>
		# 'busSlotOption null,' --> 'busSlotOption => undef,'
		$line =~ s/(\w\s+)null,/$1 => undef,/g;
		
		# Change = to =>
		$line =~ s/=(\s+.+)/=>$1/g;
		
		# Add => before array and hash references
		# 'guestOSDescriptor [' --> 'guestOSDescriptor => ['
		$line =~ s/(\w\s+)([\[{])/$1=>$2/g;
		
		$statement .= "$line\n";
		$numbered_statement .= "$line_number:\n";
		$numbered_statement .= "$original_line\n";
		$numbered_statement .= "$line\n";
	}

	# Enclose the entire statement in curly brackets
	if ($statement =~ /^[^\n]+{/) {
		$statement = "{\n$statement\n}";
	}
	
	if ($debug) {
		print "\n";
		print '.' x 200 . "\n";
		print "Statement:\n$statement\n";
		print '.' x 200 . "\n";
	}
	
	# The statement variable should contain a valid definition
	my $result = eval($statement);
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse vim-cmd output, error:\n$EVAL_ERROR\n$numbered_statement");
		return;
	}
	elsif (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse vim-cmd output:\n$numbered_statement");
		return;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "parsed vim-cmd output:\n" . format_data($result));
		return $result;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_vm_virtual_disk_file_layout

 Parameters  : $vmx_file_path
 Returns     : hash reference
 Description : Retrieves a VM's virtual disk file layout as reported by:
               vim-cmd vmsvc/get.filelayout <VM ID>
               A hash reference is returned:
               {
                 "vim.vm.FileInfo" => {
                   "dynamicType" => "<unset>",
                   "ftMetadataDirectory" => "<unset>",
                   "logDirectory" => "[blade1e1-10-vmpath] arkvmm160_3868-v0",
                   "snapshotDirectory" => "[blade1e1-10-vmpath] arkvmm160_3868-v0",
                   "suspendDirectory" => "[blade1e1-10-vmpath] arkvmm160_3868-v0",
                   "vmPathName" => "[blade1e1-10-vmpath] arkvmm160_3868-v0/arkvmm160_3868-v0.vmx"
                 },
                 "vim.vm.FileLayout" => {
                   "configFile" => [
                     "arkvmm160_3868-v0.vmxf",
                     "nvram",
                     "arkvmm160_3868-v0.vmsd"
                   ],
                   "disk" => [
                     {
                       "diskFile" => [
                         "[datastore-compressed] vmwarewinxp-xpsp33868-v0/vmwarewinxp-xpsp33868-v0.vmdk",
                         "[blade1e1-10-vmpath] arkvmm160_3868-v0/vmwarewinxp-xpsp33868-v0-000001.vmdk"
                       ],
                       "dynamicType" => "<unset>",
                       "key" => 3000
                     },
                     {
                       "diskFile" => [
                         "[blade1e1-10-vmpath] arkvmm160_3868-v0/arkvmm160_3868-v0.vmdk"
                       ],
                       "dynamicType" => "<unset>",
                       "key" => 2000
                     }
                   ],
                   "dynamicType" => "<unset>",
                   "logFile" => [
                     "vmware-1.log",
                     "vmware-2.log",
                     "vmware-3.log",
                     "vmware.log"
                   ],
                   "snapshot" => [
                     {
                       "dynamicType" => "<unset>",
                       "key" => "'vim.vm.Snapshot:576-snapshot-1'",
                       "snapshotFile" => [
                         "[blade1e1-10-vmpath] arkvmm160_3868-v0/arkvmm160_3868-v0-Snapshot1.vmsn",
                         "[datastore-compressed] vmwarewinxp-xpsp33868-v0/vmwarewinxp-xpsp33868-v0.vmdk"
                       ]
                     }
                   ],
                   "swapFile" => "<unset>"
                 }
               }

=cut

sub _get_vm_virtual_disk_file_layout {
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
	
	# Get the VM ID
	my $vm_id = $self->_get_vm_id($vmx_file_path);
	if (!defined($vm_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to power off VM because VM ID could not be determined");
		return;
	}
	
	my $vim_cmd_arguments = "vmsvc/get.filelayout $vm_id";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	my $virtual_disk_file_layout = $self->_parse_vim_cmd_output($output);
	if ($virtual_disk_file_layout) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved virtual disk file layout for VM $vm_id ($vmx_file_path)\n" . format_data($virtual_disk_file_layout));
		return $virtual_disk_file_layout;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve virtual disk file layout for VM $vm_id ($vmx_file_path)");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_virtual_disk_file_paths

 Parameters  : $vmx_file_path
 Returns     : array
 Description : Retrieves a VM's virtual disk file layout and returns an array
               reference. Each top-level array element represent entire virtual
               disk and contains an array reference containing the virtual
               disk's files:
               [
                 [
                   "/vmfs/volumes/datastore/vmwarewin7-bare3844-v1/vmwarewin7-bare3844-v1.vmdk",
                   "/vmfs/volumes/blade-vmpath/vm170_3844-v1/vmwarewin7-bare3844-v1-000001.vmdk",
                   "/vmfs/volumes/blade-vmpath/vm170_3844-v1/vmwarewin7-bare3844-v1-000002.vmdk",
                   "/vmfs/volumes/blade-vmpath/vm170_3844-v1/vmwarewin7-bare3844-v1-000003.vmdk"
                 ],
                 [
                   "/vmfs/volumes/blade-vmpath/vm170_3844-v1/vm170_3844-v1.vmdk"
                 ]
               ]

=cut

sub get_vm_virtual_disk_file_paths {
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
	
	my $virtual_disk_file_layout = $self->_get_vm_virtual_disk_file_layout($vmx_file_path) || return;
	
	my $virtual_disk_array_ref = $virtual_disk_file_layout->{'vim.vm.FileLayout'}{'disk'};
	if (!$virtual_disk_array_ref) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine virtual disk file paths, failed to retrieve {'vim.vm.FileLayout'}{'disk'} array reference from virtual disk file layout:\n" . format_data($virtual_disk_file_layout));
		return;
	}
	elsif (!ref($virtual_disk_array_ref) || ref($virtual_disk_array_ref) ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "unable to determine virtual disk file paths, virtual disk file layout {'vim.vm.FileLayout'}{'disk'} key does not contain an array reference:\n" . format_data($virtual_disk_array_ref));
		return;
	}
	
	my @virtual_disks;
	for my $virtual_disk_ref (@$virtual_disk_array_ref) {
		my $disk_file_array_ref = $virtual_disk_ref->{'diskFile'};
		my @virtual_disk_file_paths;
		for my $virtual_disk_file_path (@$disk_file_array_ref) {
			push @virtual_disk_file_paths, $self->_get_normal_path($virtual_disk_file_path);
		}
		push @virtual_disks, \@virtual_disk_file_paths;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved virtual disk file paths for $vmx_file_path:\n" . format_data(\@virtual_disks));
	return @virtual_disks;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vm_cpu_usage

 Parameters  : $vmx_file_path
 Returns     : integer (percent)
 Description : Retrieves the most recent overall CPU usage for a VM. This is
               calculated based on the values returned from:
               vim-cmd vmsvc/get.summary
               {quickStats}{overallCpuUsage} / {runtime}{maxCpuUsage} = %usage

=cut

sub get_vm_cpu_usage {
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
	
	my $vm_summary = $self->_get_vm_summary($vmx_file_path) || return;
	
	my $max_cpu_usage = $vm_summary->{runtime}{maxCpuUsage};
	if (!defined($max_cpu_usage)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine CPU usage for VM $vmx_file_path, VM summary information does not contain a {runtime}{maxCpuUsage} key:\n" . format_data($vm_summary));
		return;
	}
	elsif ($max_cpu_usage !~ /^\d+$/ || !$max_cpu_usage) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine CPU usage for VM $vmx_file_path, maxCpuUsage value is not valid: $max_cpu_usage");
		return;
	}
	
	my $overall_cpu_usage = $vm_summary->{quickStats}{overallCpuUsage};
	if (!defined($overall_cpu_usage)) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine CPU usage for VM $vmx_file_path, VM summary information does not contain a {quickStats}{overallCpuUsage} key:\n" . format_data($vm_summary));
		return;
	}
	elsif ($overall_cpu_usage !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine CPU usage for VM $vmx_file_path, $overall_cpu_usage value is not valid: $overall_cpu_usage");
		return;
	}
	
	my $cpu_usage_percent = format_number(($overall_cpu_usage / $max_cpu_usage), 2) * 100;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved CPU usage for VM $vmx_file_path: $cpu_usage_percent\% (overall CPU usage: $overall_cpu_usage MHz / max CPU usage: $max_cpu_usage MHz)");
	return $cpu_usage_percent;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_ruleset_allow_ip

 Parameters  : $ruleset_name, $ip_address
 Returns     : boolean
 Description : Adds an IP address to a firewall ruleset to allow traffic.

=cut

sub firewall_ruleset_allow_ip {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($ruleset_name, $ip_address) = @_;
	if (!defined($ruleset_name)) {
		notify($ERRORS{'WARNING'}, 0, "ruleset name argument was not supplied");
		return;
	}
	elsif (!defined($ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "IP address argument was not supplied");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname();
	
	my $command;
	if ($ip_address =~ /all/i) {
		$command = "esxcli network firewall ruleset set --ruleset-id=$ruleset_name --allowed-all true";
	}
	else {
		$command = "esxcli network firewall ruleset allowedip add --ruleset-id=$ruleset_name --ip-address=$ip_address";
	}
	
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on VM host $vmhost_computer_name: $command");
		return;
	}
	elsif (grep(/already (exist|allowed)/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "$ip_address is already allowed for $ruleset_name ruleset on VM host $vmhost_computer_name");
		return 1;
	}
	elsif (grep(/allowed-all/i, @$output)) {
		# Couldn't update allowed ip list when allowed-all flag is true.
		notify($ERRORS{'OK'}, 0, "all IP addresses are already allowed for $ruleset_name ruleset on VM host $vmhost_computer_name");
		return 1;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to add $ip_address to $ruleset_name ruleset on VM host $vmhost_computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "added $ip_address to $ruleset_name ruleset on VM host $vmhost_computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_ruleset_enable

 Parameters  : $ruleset_name
 Returns     : boolean
 Description : Enables a firewall ruleset.

=cut

sub firewall_ruleset_enable {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($ruleset_name) = @_;
	if (!defined($ruleset_name)) {
		notify($ERRORS{'WARNING'}, 0, "ruleset name argument was not supplied");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname();
	
	my $command = "esxcli network firewall ruleset set --ruleset-id=$ruleset_name --enabled true";
	my ($exit_status, $output) = $self->vmhost_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on VM host $vmhost_computer_name: $command");
		return;
	}
	elsif ($exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable $ruleset_name ruleset on VM host $vmhost_computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "enabled $ruleset_name ruleset on VM host $vmhost_computer_name");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_firewall_ruleset_info

 Parameters  : none
 Returns     : array
 Description : Retrieves information about all of the firewall rulesets from the
               VM host. A hash reference is returned. Hash keys are the ruleset
               names:
                  "ipfam" => {
                    "enabled" => 1,
                    "rules" => [
                      {
                        "Direction" => "Inbound",
                        "PortBegin" => 6999,
                        "PortEnd" => 6999,
                        "PortType" => "Dst",
                        "Protocol" => "UDP"
                      },
                      {
                        "Direction" => "Outbound",
                        "PortBegin" => 6999,
                        "PortEnd" => 6999,
                        "PortType" => "Dst",
                        "Protocol" => "UDP"
                      }
                    ]
                  },
                  "nfs41Client" => {
                    "enabled" => 0,
                    "rules" => [
                      {
                        "Direction" => "Outbound",
                        "PortBegin" => 2049,
                        "PortEnd" => 2049,
                        "PortType" => "Dst",
                        "Protocol" => "TCP"
                      }
                    ]
                  },

=cut

sub get_firewall_ruleset_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $ENV{firewall_ruleset_info} if defined($ENV{firewall_ruleset_info});
	
	my $vmhost_computer_name = $self->data->get_vmhost_hostname();
	
	my $ruleset_info = {};
	
	# Get the enabled/disabled status of each ruleset
	my $ruleset_list_command = "esxcli --formatter=csv network firewall ruleset list";
	my ($ruleset_list_exit_status, $ruleset_list_output) = $self->vmhost_os->execute($ruleset_list_command);
	if (!defined($ruleset_list_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on VM host $vmhost_computer_name: $ruleset_list_command");
		return;
	}
	elsif ($ruleset_list_exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall ruleset info from VM host $vmhost_computer_name, exit status: $ruleset_list_exit_status, command:\n$ruleset_list_command\noutput:\n" . join("\n", @$ruleset_list_output));
		return 0;
	}
	
	# Enabled,Name,
	# true,sshServer,
	# true,sshClient,
	# true,nfsClient,
	# false,nfs41Client,
	# ...
	for my $line (@$ruleset_list_output) {
		if ($line !~ /(true|false)/) {
			next;
		}
		my ($enabled, $ruleset_name) = split(/,/, $line);
		if ($enabled =~ /true/i) {
			$ruleset_info->{$ruleset_name}{enabled} = 1;
		}
		else {
			$ruleset_info->{$ruleset_name}{enabled} = 0;
		}
	}
	
	
	
	
	# Get the allowed IPs of each ruleset
	my $ruleset_allowed_ip_command = "esxcli --formatter=csv network firewall ruleset allowedip list";
	my ($ruleset_allowed_ip_exit_status, $ruleset_allowed_ip_output) = $self->vmhost_os->execute($ruleset_allowed_ip_command);
	if (!defined($ruleset_allowed_ip_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on VM host $vmhost_computer_name: $ruleset_allowed_ip_command");
		return;
	}
	elsif ($ruleset_allowed_ip_exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall ruleset allowed IP info from VM host $vmhost_computer_name, exit status: $ruleset_allowed_ip_exit_status, command:\n$ruleset_allowed_ip_command\noutput:\n" . join("\n", @$ruleset_allowed_ip_output));
		return 0;
	}
	
	# AllowedIPAddresses,Ruleset,
	# "152.1.4.152,10.25.7.2,10.25.11.104,10.25.0.241,10.25.0.242,10.25.0.243,10.25.0.244,10.25.0.245,10.25.0.246,10.25.1.178,",sshServer,
	# "All,",sshClient,
	# ...
	for my $line (@$ruleset_allowed_ip_output) {
		if ($line =~ /Ruleset/) {
			next;
		}
		
		my ($ip_address_string, $ruleset_name) = $line =~ /^"?(.+),"?,([^,]+),/g;
		if (!defined($ruleset_name)) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall ruleset allowed IP info from VM host $vmhost_computer_name, failed to parse line:\n$line");
			return;
		}
		
		my @ip_addresses = split(/,/, $ip_address_string);
		$ruleset_info->{$ruleset_name}{allowedip} = \@ip_addresses;
	}
	
	# Get the rule port information
	my $rule_list_command = "esxcli --formatter=csv network firewall ruleset rule list";
	my ($rule_list_exit_status, $rule_list_output) = $self->vmhost_os->execute($rule_list_command);
	if (!defined($rule_list_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on VM host $vmhost_computer_name: $rule_list_command");
		return;
	}
	elsif ($rule_list_exit_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve firewall rule info from VM host $vmhost_computer_name, exit status: $rule_list_exit_status, command:\n$rule_list_command\noutput:\n" . join("\n", @$rule_list_output));
		return 0;
	}
	
	# Parse the header line
	# Direction,PortBegin,PortEnd,PortType,Protocol,Ruleset,
	my $rule_header_line = shift @$rule_list_output;
	my @rule_fields = split(/,/, $rule_header_line);
	my $rule_field_count = scalar(@rule_fields);
	
	# Inbound,22,22,Dst,TCP,sshServer,
	# Outbound,22,22,Dst,TCP,sshClient,
	# Outbound,0,65535,Dst,TCP,nfsClient,
	# Outbound,2049,2049,Dst,TCP,nfs41Client,
	for my $line (@$rule_list_output) {
		if ($line !~ /bound/) {
			next;
		}
		my @values = split(/,/, $line);
		my $rule = {};
		for (my $i = 0; $i < $rule_field_count; $i++) {
			my $field = $rule_fields[$i];
			my $value = $values[$i];
			$rule->{$field} = $value;
		}
		my $ruleset_name = $rule->{Ruleset};
		delete $rule->{Ruleset};
		
		push @{$ruleset_info->{$ruleset_name}{rules}}, $rule;
	}
	
	notify($ERRORS{'OK'}, 0, "retrieved firewall ruleset info from VM host $vmhost_computer_name:\n" . format_data($ruleset_info));
	$ENV{firewall_ruleset_info} = $ruleset_info;
	return $ruleset_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_matching_firewall_ruleset_info

 Parameters  : $port (optional), $direction (optional), $include_disabled (optional)
 Returns     : hash reference
 Description : 

=cut

sub get_matching_firewall_ruleset_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($direction_argument, $port_argument, $exclude_disabled) = @_;
	if ($port_argument) {
		if ($port_argument =~ /^(\*|any)$/) {
			$port_argument = 'any';
		}
		elsif ($port_argument !~ /^\d+$/) {
			notify($ERRORS{'WARNING'}, 0, "port argument was specified but the value is not an integer: $port_argument");
			return;
		}
	}
	else {
		$port_argument = 'any';
	}
	
	if ($direction_argument) {
		if ($direction_argument =~ /^(\*|any)$/) {
			$direction_argument = 'any';
		}
		elsif ($direction_argument =~ /in/i) {
			$direction_argument = 'inbound';
		}
		elsif ($direction_argument =~ /out/i) {
			$direction_argument = 'outbound';
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "direction argument is not valid: $direction_argument");
			return;
		}
	}
	else {
		$direction_argument = 'any';
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_short_name();
	
	my $ruleset_info = $self->get_firewall_ruleset_info() || return;
	
	my $matching_ruleset_info = {};
	
	RULESET: for my $ruleset_name (sort {lc($a) cmp lc($b)} keys %$ruleset_info) {
		my $ruleset = $ruleset_info->{$ruleset_name};
		
		# Ignore disabled rulesets if argument was supplied
		my $enabled = $ruleset->{enabled};
		if (!$enabled && $exclude_disabled) {
			next RULESET;
		}
		
		RULE: for my $rule (@{$ruleset->{rules}}) {
			if ($direction_argument ne 'any') {
				my $direction = $rule->{Direction};
				if ($direction !~ /$direction_argument/i) {
					#notify($ERRORS{'DEBUG'}, 0, "$ruleset_name direction does not match: argument: $direction_argument, rule: $direction");
					next RULE;
				}
			}
			
			if ($port_argument ne 'any') {
				my $port_begin = $rule->{PortBegin};
				my $port_end = $rule->{PortEnd};
				if ($port_argument < $port_begin || $port_argument > $port_end) {
					#notify($ERRORS{'DEBUG'}, 0, "$ruleset_name port does not match: argument: $port_argument, port begin: $port_begin, port end: $port_end");
					next RULE;
				}
			}
			
			$matching_ruleset_info->{$ruleset_name} = $ruleset;
		}
	}
	
	my $ruleset_count = scalar(keys %$matching_ruleset_info);
	notify($ERRORS{'DEBUG'}, 0, "retrieved $ruleset_count matching firewall ruleset from VM host $vmhost_computer_name matching port: $port_argument, direction: $direction_argument, exclude disabled: " . ($exclude_disabled ? 'yes' : 'no') . "\n" . join("\n", sort keys %$matching_ruleset_info));
	return $matching_ruleset_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_firewall_port_allowed

 Parameters  : $direction, $port, $remote_ip_address
 Returns     : boolean
 Description : Checks if an enabled firewall ruleset exists which matches the
               arguments.
 
               *** WARNING ***
               There seems to be no reliable way to determine if a port is truly
               open if a custom rule exists with identical port and definitions
               as a standard service. The IBMIMM is an example. It defines
               outbound port 22 as does sshClient. If both of these services are
               enabled with different allowed IP address lists, the allowed IP
               address list of the service which started last prevails.
               Example:
               * sshClient allows only 10.1.1.1
               * IBMIMM allows only 10.2.2.2
               * Restart sshClient : 10.1.1.1 allowed, 10.2.2.2 blocked
               * Restart IBMIMM    : 10.2.2.2 allowed, 10.1.1.1 blocked

=cut

sub is_firewall_port_allowed {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($direction_argument, $port_argument, $remote_ip_address) = @_;
	
	if (!defined($direction_argument)) {
		notify($ERRORS{'WARNING'}, 0, "direction argument was not specified");
		return;
	}
	elsif ($direction_argument =~ /in/i) {
		$direction_argument = 'inbound';
	}
	elsif ($direction_argument =~ /out/i) {
		$direction_argument = 'outbound';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "direction argument is not valid: $direction_argument");
		return;
	}
	
	if (!defined($remote_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not specified");
		return;
	}
	elsif (!is_valid_ip_address($remote_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument is not valid: $remote_ip_address");
		return;
	}
	
	my $vmhost_computer_name = $self->data->get_vmhost_short_name();
	
	my $ruleset_info = $self->get_firewall_ruleset_info() || return;
	
	my $matching_ruleset_info = {};
	
	RULESET: for my $ruleset_name (keys %$ruleset_info) {
		my $ruleset = $ruleset_info->{$ruleset_name};
		
		# Ignore disabled rulesets
		if (!$ruleset->{enabled}) {
			#notify($ERRORS{'DEBUG'}, 0, "$ruleset_name ruleset ignored because it is not enabled");
			next RULESET;
		}
		
		my $direction_port_match = 0;
		RULE: for my $rule (@{$ruleset->{rules}}) {
			if ($rule->{Direction} !~ /$direction_argument/i) {
				next RULE;
			}
			
			if ($port_argument >= $rule->{PortBegin} && $port_argument <= $rule->{PortEnd}) {
				$direction_port_match = 1;
				#notify($ERRORS{'DEBUG'}, 0, "$ruleset_name ruleset rule matches direction: $direction_argument, port: $port_argument\n" . format_data($rule));
				last RULE;
			}
		}
		if (!$direction_port_match) {
			next RULESET;
		}
		
		my @allowed_ip_addresses = @{$ruleset->{allowedip}};
		if ($allowed_ip_addresses[0] =~ /all/i) {
			notify($ERRORS{'DEBUG'}, 0, "$ruleset_name ruleset on VM host $vmhost_computer_name allows $direction_argument port $port_argument " . ($direction_argument =~ /in/i ? 'from' : 'to') . " all:\n" . format_data($ruleset));
			next RULESET;
			#return 1;
		}
		elsif (grep { $_ eq $remote_ip_address } @allowed_ip_addresses) {
			notify($ERRORS{'DEBUG'}, 0, "$ruleset_name ruleset on VM host $vmhost_computer_name allows $direction_argument port $port_argument " . ($direction_argument =~ /in/i ? 'from' : 'to') . " $remote_ip_address:\n" . format_data($ruleset));
			next RULESET;
			#return 1;
		}
		notify($ERRORS{'DEBUG'}, 0, "$ruleset_name ruleset on VM host $vmhost_computer_name does NOT allow $direction_argument port $port_argument " . ($direction_argument =~ /in/i ? 'from' : 'to') . " $remote_ip_address:\n" . format_data($ruleset));
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$direction_argument firewall port $port_argument is NOT allowed for $remote_ip_address on VM host $vmhost_computer_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_host_summary

 Parameters  : none
 Returns     : hash reference
 Description : Runs "vim-cmd hostsvc/hostsummary" to retrive various information
               about the VMware host.

=cut

sub _get_host_summary {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{host_summary} if $self->{host_summary};
	
	my $vim_cmd_arguments = "hostsvc/hostsummary";
	my ($exit_status, $output) = $self->_run_vim_cmd($vim_cmd_arguments);
	return if !$output;
	
	# The output should look like this:
	#(vim.host.Summary) {
	#   host = 'vim.HostSystem:ha-host',
	#   hardware = (vim.host.Summary.HardwareSummary) {
	#      vendor = "IBM",
	#      model = "BladeCenter HS22 -[7870AC1]-",
	# ...
	
	# The hash keys are:
	# {
	#    config = {
	#       agentVmDatastore = '',
	#       agentVmNetwork = '',
	#       faultToleranceEnabled = '',
	#       featureVersion = '',
	#       name = '',
	#       port = '',
	#       product = {
	#          apiType = '',
	#          apiVersion = '',
	#          build = '',
	#          fullName = '',
	#          instanceUuid = '',
	#          licenseProductName = '',
	#          licenseProductVersion = '',
	#          localeBuild = '',
	#          localeVersion = '',
	#          name = '',
	#          osType = '',
	#          productLineId = '',
	#          vendor = '',
	#          version = '',
	#       },
	#       sslThumbprint = '',
	#       vmotionEnabled = '',
	#    },
	#    currentEVCModeKey = '',
	#    customValue = '',
	#    gateway = '',
	#    hardware = {
	#       cpuMhz = '',
	#       cpuModel = '',
	#       memorySize = '',
	#       model = '',
	#       numCpuCores = '',
	#       numCpuPkgs = '',
	#       numCpuThreads = '',
	#       numHBAs = '',
	#       numNics = '',
	#       otherIdentifyingInfo = '',
	#       uuid = '',
	#       vendor = '',
	#    },
	#    host = '',
	#    managementServerIp = '',
	#    maxEVCModeKey = '',
	#    overallStatus = '',
	#    quickStats = {
	#       distributedCpuFairness = '',
	#       distributedMemoryFairness = '',
	#       overallCpuUsage = '',
	#       overallMemoryUsage = '',
	#       uptime = '',
	#    },
	#    rebootRequired = '',
	#    runtime = {
	#       bootTime = '',
	#       connectionState = '',
	#       cpuCapacityForVm = '',
	#       cryptoKeyId = '',
	#       cryptoState = '',
	#       dasHostState = '',
	#       healthSystemRuntime = {
	#          hardwareStatusInfo = {
	#             cpuStatusInfo => [],
	#             memoryStatusInfo => [],
	#             storageStatusInfo = '',
	#          },
	#          systemHealthInfo = {
	#             numericSensorInfo => [],
	#          },
	#       },
	#       hostMaxVirtualDiskCapacity = '',
	#       inMaintenanceMode = '',
	#       inQuarantineMode = '',
	#       memoryCapacityForVm = '',
	#       networkRuntimeInfo = {
	#          netStackInstanceRuntimeInfo => [],
	#          networkResourceRuntime = '',
	#       },
	#       powerState = '',
	#       standbyMode = '',
	#       tpmPcrValues = '',
	#       vFlashResourceRuntimeInfo = '',
	#       vsanRuntimeInfo = {
	#          accessGenNo = '',
	#          diskIssues = '',
	#          membershipList = '',
	#       },
	#    },
	# }

	
	if (!grep(/vim\.host\.Summary/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve host summary, unexpected output returned, VIM command arguments: '$vim_cmd_arguments', output:\n" . join("\n", @$output));
		return;
	}
	
	my $host_summary_info = $self->_parse_vim_cmd_output($output);
	if (defined($host_summary_info->{'vim.host.Summary'})) {
		$self->{host_summary} = $host_summary_info->{'vim.host.Summary'};
		return $self->{host_summary};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve host summary, parsed output does not contain a 'vim.host.Summary' key:\n" . format_data($host_summary_info));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmware_product_name

 Parameters  : none
 Returns     : string
 Description : Returns the full VMware product name installed on the VM host.
               Examples:
               VMware Server 2.0.2 build-203138
               VMware ESXi 4.0.0 build-208167

=cut

sub get_vmware_product_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{product_name} if $self->{product_name};
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $host_summary = $self->_get_host_summary() || return;
	my $product_name = $host_summary->{config}{product}{fullName};
	if ($product_name) {
		notify($ERRORS{'DEBUG'}, 0, "VMware product being used on VM host $vmhost_hostname: '$product_name'");
		$self->{product_name} = $product_name;
		return $self->{product_name};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve VMware product name being used on VM host $vmhost_hostname");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmware_product_version

 Parameters  : none
 Returns     : string
 Description : Returns the VMware product version installed on the VM host.
               Example:
               6.5.0

=cut

sub get_vmware_product_version {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{product_version} if $self->{product_version};
	
	my $vmhost_hostname = $self->data->get_vmhost_hostname();
	
	my $host_summary = $self->_get_host_summary() || return;
	my $product_version = $host_summary->{config}{product}{version};
	if ($product_version) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved product version for VM host $vmhost_hostname: $product_version");
		$self->{product_version} = $product_version;
		return $self->{product_version};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve product version for VM host $vmhost_hostname");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
