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

VCL::Provisioning::xCAT - VCL module to support the xCAT provisioning engine

=head1 SYNOPSIS

 From another VCL module instantiated normally for a reservation:
   $self->provisioner->load();
 
 From a script:
   my $xcat = new VCL::Module::Provisioning::xCAT();

=head1 DESCRIPTION

 This module provides VCL support for xCAT (Extreme Cluster Administration
 Toolkit) version 2.x. xCAT is a scalable distributed computing management and
 provisioning tool that provides a unified interface for hardware control,
 discovery, and OS diskful/diskfree deployment. http://xcat.sourceforge.net

=cut

###############################################################################
package VCL::Module::Provisioning::xCAT;

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
use File::Copy;
use IO::Seekable;
use Socket;
use version;

###############################################################################

=head1 CLASS ATTRIBUTES

=cut

=head2 $XCAT_ROOT

 Data type   : scalar
 Description : $XCAT_ROOT stores the location of the xCAT binary files. xCAT
               should set the XCATROOT environment variable. This is used if
               it is set.  If XCATROOT is not set, /opt/xcat is used.

=cut

# Class attributes to store xCAT configuration details
my $XCAT_ROOT;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Checks to make sure xCAT appears to be installed on the
               management node.

=cut

sub initialize {
	my $self = shift;

	# Check the XCAT_ROOT environment variable, it should be defined
	if (defined($ENV{XCATROOT}) && $ENV{XCATROOT}) {
		$XCAT_ROOT = $ENV{XCATROOT};
	}
	elsif (defined($ENV{XCATROOT})) {
		notify($ERRORS{'OK'}, 0, "XCATROOT environment variable is not defined, using /opt/xcat");
		$XCAT_ROOT = '/opt/xcat';
	}
	else {
		notify($ERRORS{'OK'}, 0, "XCATROOT environment variable is not set, using /opt/xcat");
		$XCAT_ROOT = '/opt/xcat';
	}

	# Remove trailing / from $XCAT_ROOT if exists
	$XCAT_ROOT =~ s/\/$//;

	# Make sure the xCAT root path is valid
	if (!-d $XCAT_ROOT) {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize xCAT module, $XCAT_ROOT directory does not exist");
		return;
	}
	
	# Check to make sure one of the expected executables is where it should be
	if (!-x "$XCAT_ROOT/bin/rpower") {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize xCAT module, expected executable was not found: $XCAT_ROOT/bin/rpower");
		return;
	}
	
	# Check to make sure one of the xCAT 2.x executables not included in 1/x exists
	if (!-x "$XCAT_ROOT/bin/lsdef") {
		notify($ERRORS{'WARNING'}, 0, "unable to initialize xCAT module, xCAT version is not supported, expected xCAT 2.x+ executable was not found: $XCAT_ROOT/bin/lsdef");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "xCAT module initialized");
	return 1;
} ## end sub initialize

#//////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : none
 Returns     : boolean
 Description : Powers-off computer with the image defined in the reservation data.

=cut

sub unload {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	if (!$self->power_off()) {
		return 0;
	}

	return 1;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  : none
 Returns     : boolean
 Description : Loads a computer with the image defined in the reservation data.

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the data
	my $reservation_id             = $self->data->get_reservation_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_reload_time_minutes  = $self->data->get_image_reload_time() || 10;
	my $computer_id                = $self->data->get_computer_id();
	my $computer_node_name         = $self->data->get_computer_node_name();
	my $management_node_hostname   = $self->data->get_management_node_hostname();
	
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_node_name $image_name");
	
	# Insert a computerloadlog record and edit nodetype table to set the image information for the computer
	insertloadlog($reservation_id, $computer_id, "editnodetype", "updating nodetype table");
	$self->_edit_nodetype($computer_node_name, $image_name) || return;
	
	# Insert a computerloadlog record and edit nodelist table to set the xCAT groups for the computer
	$self->_edit_nodelist($computer_node_name, $image_name) || return;
	
	# Check to see if management node throttle is configured
	my $throttle_limit = get_variable("xcat|throttle|$management_node_hostname", 0) || get_variable("$management_node_hostname|xcat|throttle", 0) || get_variable("xcat|throttle", 0);
	if (!$throttle_limit || $throttle_limit !~ /^\d+$/) {
		$throttle_limit = 10;
		notify($ERRORS{'DEBUG'}, 0, "xCAT load throttle limit variable is NOT set in database: 'xcat|throttle', using default value: $throttle_limit");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "xCAT load throttle limit variable is set in database: $throttle_limit");
	}
	
	my $throttle_limit_wait_seconds = (30 * 60);
	if (!$self->code_loop_timeout(sub{!$self->_is_throttle_limit_reached(@_)}, [$throttle_limit], 'checking throttle limit', $throttle_limit_wait_seconds, 1, 10)) {
		notify($ERRORS{'WARNING'}, 0, "failed to load image due to throttle limit, waited $throttle_limit_wait_seconds seconds");
		return;
	}
	
	# Set the computer to install on next boot
	$self->_nodeset($computer_node_name, 'install') || return;
	
	# Restart the node
	$self->power_reset($computer_node_name) || return;
	
	# Run lsdef to retrieve the node's configuration including its MAC address
	my $node_info = $self->_lsdef($computer_node_name);
	if (!$node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to monitor loading of $computer_node_name, failed to retrieve node info");
		return;
	}
	my $mac_address = $node_info->{mac};
	if ($mac_address) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved MAC address of $computer_node_name: $mac_address");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to monitor loading of $computer_node_name, node info does not contain the MAC address:\n" . format_data($node_info));
		return;
	}
	
	# nodeset changes xCAT state to 'install'
	# node is power cycled or powered on (nodeset/nodestat status: install/noping)
	# Wait for node to boot from network (may take from 30 seconds to several minutes if node is using UEFI)
	# In /var/log/messages:, node makes DHCP request & requests PXE boot information from DHCP server running on management node:
	#   Apr  1 09:36:39 vclmgt dhcpd: DHCPDISCOVER from xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:36:39 vclmgt dhcpd: DHCPOFFER on 10.yy.yy.yy to xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:36:43 vclmgt dhcpd: DHCPREQUEST for 10.yy.yy.yy (10.mn.mn.mn) from xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:36:43 vclmgt dhcpd: DHCPACK on 10.yy.yy.yy to xx:xx:xx:xx:xx:xx via ethX
	#
	# Node requests PXE boot files from TFTP server running on management node:
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving pxelinux.0 to 10.yy.yy.yy:2070
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving pxelinux.0 to 10.yy.yy.yy:2071
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving pxelinux.cfg/xx-xx-xx-xx-xx-xx to 10.yy.yy.yy:57089
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving pxelinux.cfg/0A0A0132 to 10.yy.yy.yy:57090
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving xcat/rhel6/x86_64/vmlinuz to 10.yy.yy.yy:57091
	#   Apr  1 09:36:43 vclmgt atftpd[27522]: Serving xcat/rhel6/x86_64/initrd.img to 10.yy.yy.yy:57092
	#
	# Node boots using files downloaded from TFTP/PXE server, makes another DHCP request:
	#   Apr  1 09:37:15 vclmgt dhcpd: DHCPDISCOVER from xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:37:15 vclmgt dhcpd: DHCPOFFER on 10.yy.yy.yy to xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:37:15 vclmgt dhcpd: DHCPREQUEST for 10.yy.yy.yy (10.mn.mn.mn) from xx:xx:xx:xx:xx:xx via ethX
	#   Apr  1 09:37:15 vclmgt dhcpd: DHCPACK on 10.yy.yy.yy to xx:xx:xx:xx:xx:xx via ethX
	# OS installation begins (nodeset/nodestat status: install/installing prep)
	# If Kickstart, Linux packages are installed (nodestat status: 'installing <package> (x%)')
	# If Kickstart, postscripts are installed (nodestat status: 'installing post scripts')
	# When installation is complete, xCAT status is changed to 'boot' and node is restarted (nodeset/nodestat status: boot/noping)
	# Node boots from hard drive (nodeset/nodestat status: boot/boot)
	
	# Open the /var/log/messages file for reading
	my $messages_file_path = '/var/log/messages';
	my $log = IO::File->new($messages_file_path, "r");
	if (!$log) {
		my $error = $! || 'none';
		notify($ERRORS{'WARNING'}, 0, "failed to open $messages_file_path for reading, error: $error");
		return;
	}
	# Go to the end of the messages file
	if (!$log->seek(0, SEEK_END)) {
		my $error = $! || 'none';
		notify($ERRORS{'CRITICAL'}, 0, "failed to seek end of $messages_file_path, error: $error");
	}

	insertloadlog($reservation_id, $computer_id, "xcatstage5", "loading image $image_name");
	
	if ($image_reload_time_minutes < 10) {
		$image_reload_time_minutes = 10;
	}
	my $nochange_timeout_seconds = ($image_reload_time_minutes * 60);
	
	my $monitor_start_time = time;
	my $last_change_time = $monitor_start_time;
	my $nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
	
	# Sanity check, timeout the load monitoring after a set amount of time
	# This is done in case there is an endless loop which causes the node status to change over and over again
	# Overall timeout is the lesser of 60 minutes or 2x image reload time
	my $overall_timeout_minutes;
	if ($image_reload_time_minutes < 30) {
		$overall_timeout_minutes = 60;
	}
	else {
		$overall_timeout_minutes = ($image_reload_time_minutes * 2);
	}
	my $overall_timeout_time = ($monitor_start_time + $overall_timeout_minutes * 60);
	
	# Number of seconds to wait between checks
	# Set to a short delay at the beginning of monitoring, this will be increased once installation start is detected
	my $monitor_delay_seconds = 5;
	
	# Keep track of when reservation.lastcheck was last updated
	my $update_lastcheck_interval_seconds = 60;
	my $update_lastcheck_time = time;
	update_reservation_lastcheck($reservation_id);
	
	my $previous_nodestat_status;
	my $previous_nodeset_status;
	my $current_time;
	my $install_started = 0;
	my $dhcp_ack = 0;
	MONITOR_LOADING: while (($current_time = time) < $nochange_timeout_time && $current_time < $overall_timeout_time) {
		my $total_elapsed_seconds = ($current_time - $monitor_start_time);
		my $nochange_elapsed_seconds = ($current_time - $last_change_time);
		my $nochange_remaining_seconds = ($nochange_timeout_time - $current_time);
		my $overall_remaining_seconds = ($overall_timeout_time - $current_time);
		notify($ERRORS{'DEBUG'}, 0, "monitoring $image_name loading on $computer_node_name\n" .
			"seconds since monitor start/until unconditional timeout: $total_elapsed_seconds/$overall_remaining_seconds\n" .
			"seconds since last change/until no change timeout: $nochange_elapsed_seconds/$nochange_remaining_seconds"
		);
		
		# Flag to set if anything changes
		my $reset_timeout = 0;
		
		# Check if any lines have shown in in /var/log/messages for the node
		my @lines = $log->getlines;
		my @dhcp_lines = grep(/dhcpd:.+DHCP.+\s$mac_address\s/i, @lines);
		if (@dhcp_lines) {
			if (grep(/DHCPREQUEST/i, @dhcp_lines)) {
				insertloadlog($reservation_id, $computer_id, "xcatstage1", "requested DHCP lease");
			}
			
			if (my ($dhcpack_line) = grep(/DHCPACK/i, @dhcp_lines)) {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name acquired DHCP lease: '$dhcpack_line'");
				if (!$dhcp_ack) {
					insertloadlog($reservation_id, $computer_id, "xcatstage2", "acquired DHCP lease");
					insertloadlog($reservation_id, $computer_id, "xcatround2", "waiting for boot flag");
					$dhcp_ack=1;
				}
			}
			
			$reset_timeout = 1;
			notify($ERRORS{'DEBUG'}, 0, "DHCP activity detected in $messages_file_path:\n" . join("\n", @dhcp_lines));
		}
		
		# Get the current status of the node
		# Set previous status to current status if this is the first iteration
		my $current_nodestat_status = $self->_nodestat($computer_node_name);
		$previous_nodestat_status = $current_nodestat_status if !defined($previous_nodestat_status);
		
		my $current_nodeset_status = $self->_nodeset($computer_node_name, 'stat');
		$previous_nodeset_status = $current_nodeset_status if !defined($previous_nodeset_status);
		
		if (!$install_started) {
			# Check if the installation has started
			if ($current_nodestat_status =~ /(install|partimage)/i) {
				# Slow down the monitor looping
				$monitor_delay_seconds = 20;
				notify($ERRORS{'DEBUG'}, 0, "installation has started, increasing wait between monitoring checks to $monitor_delay_seconds seconds");
				$install_started = 1;
			}
			
			# If installation start was missed, nodeset will go from install to boot
			if ($previous_nodeset_status =~ /install/i && $current_nodeset_status eq 'boot') {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is finished loading image, nodeset status changed: $previous_nodeset_status --> $current_nodeset_status");
				insertloadlog($reservation_id, $computer_id, "bootstate", "$computer_node_name image load complete: $current_nodestat_status, $current_nodeset_status");
				last MONITOR_LOADING;
			}
		}
		else {
			# nodestat will return 'sshd' if the computer is responding to SSH while it is being installed instead of the more detailed information
			# Try to get the installation status directly using a socket
			if ($current_nodestat_status eq 'sshd') {
				$current_nodestat_status = $self->_get_install_status($computer_node_name) || 'sshd';
			}
			
			# Check if the installation has completed
			if ($current_nodestat_status =~ /^(boot|complete)$/i || $current_nodeset_status =~ /^(boot)$/i) {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is finished loading image, current nodestat status: $current_nodestat_status, nodeset status: $current_nodeset_status");
				insertloadlog($reservation_id, $computer_id, "bootstate", "$computer_node_name image load complete: $current_nodestat_status, $current_nodeset_status");
				last MONITOR_LOADING;
			}
		}
		
		# Check if the nodestat status changed from previous iteration
		if ($current_nodestat_status ne $previous_nodestat_status || $current_nodeset_status ne $previous_nodeset_status) {
			$reset_timeout = 1;
			notify($ERRORS{'DEBUG'}, 0, "status of $computer_node_name changed");
			
			# Set previous status to the current status
			$previous_nodestat_status = $current_nodestat_status;
			$previous_nodeset_status = $current_nodeset_status;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "status of $computer_node_name has not changed: $current_nodestat_status");
		}
		
		# If any changes were detected, reset the nochange timeout
		if ($reset_timeout) {
			$last_change_time = $current_time;
			$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
			
			# Check how long ago reservation.lastcheck was updated
			# Update it occasionally - used by parent reservation in cluster requests to detect that child reservations are still loading
			# Updating reservation.lastcheck prevents the parent from timing out while waiting for children to finish loading
			my $update_lastcheck_elapsed = ($current_time - $update_lastcheck_time);
			if ($update_lastcheck_elapsed >= $update_lastcheck_interval_seconds) {
				update_reservation_lastcheck($reservation_id);
				$update_lastcheck_time = time;
			}
		}
		
		#notify($ERRORS{'DEBUG'}, 0, "sleeping for $monitor_delay_seconds seconds");
		sleep $monitor_delay_seconds;
	}
	
	$log->close;
	
	# Check if timeout was reached
	if ($current_time >= $nochange_timeout_time) {
		notify($ERRORS{'WARNING'}, 0, "failed to load $image_name on $computer_node_name, timed out because no progress was detected for $nochange_timeout_seconds seconds, start of installation detected: " . ($install_started ? 'yes' : 'no'));
		return;
	}
	elsif ($current_time >= $overall_timeout_time) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to load $image_name on $computer_node_name, timed out because loading took longer than $overall_timeout_minutes minutes, start of installation detected: " . ($install_started ? 'yes' : 'no'));
		return;
	}
	
	# Call the OS module's post_load() subroutine if implemented
	insertloadlog($reservation_id, $computer_id, "xcatround3", "initiating OS post-load configuration");
	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			notify($ERRORS{'OK'}, 0,  "performed OS post-load tasks on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on VM $computer_node_name");
			return;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "OS post-load tasks not necessary on $computer_node_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : none
 Returns     : boolean
 Description : Captures the image which is currently loaded on the computer.

=cut

sub capture {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name          = $self->data->get_image_name();
	my $computer_node_name  = $self->data->get_computer_node_name();
	
	# Get the image repository path
	my $image_repository_path = $self->get_image_repository_directory_path($image_name);
	if (!$image_repository_path) {
		notify($ERRORS{'CRITICAL'}, 0, "xCAT image repository information could not be determined");
		return;
	}
	my $capture_done_file_path = "$image_repository_path/$image_name.img.capturedone";
	my $capture_failed_file_path = "$image_repository_path/$image_name.img.capturefailed";
	
	# Print some preliminary information
	notify($ERRORS{'OK'}, 0, "attempting to capture image '$image_name' on $computer_node_name");
	
	# Check if pre_capture() subroutine has been implemented by the OS module
	if ($self->os->can("pre_capture")) {
		# Call OS pre_capture() - it should perform all OS steps necessary to capture an image
		# pre_capture() should shut down the computer when it is done
		if (!$self->os->pre_capture({end_state => 'off'})) {
			notify($ERRORS{'WARNING'}, 0, "OS module pre_capture() failed");
			return;
		}
	
		# The OS module should turn the computer power off
		# Wait up to 2 minutes for the computer's power status to be off
		if ($self->_wait_for_off($computer_node_name, 120)) {
			notify($ERRORS{'OK'}, 0, "computer $computer_node_name power is off");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$computer_node_name power is still on, turning computer off");
	
			# Attempt to power off computer
			if ($self->power_off()) {
				notify($ERRORS{'OK'}, 0, "$computer_node_name was powered off");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to power off $computer_node_name");
				return;
			}
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "OS module does implement a pre_capture() subroutine");
		return;
	}
	
	# Set the xCAT nodetype to the new image for the node
	$self->_edit_nodetype($computer_node_name, $image_name) || return;

	# Create the .tmpl file for the image
	$self->_create_template($image_name) || return;

	# Edit xCAT's nodelist table to set the correct node groups
	$self->_edit_nodelist($computer_node_name, $image_name) || return;

	# Call xCAT's nodeset to configure xCAT to save image on next reboot
	$self->_nodeset($computer_node_name, 'image') || return;
	
	# Power on the node in order to capture the image
	if (!$self->power_on()) {
		notify($ERRORS{'WARNING'}, 0, "failed to power on computer before monitoring image capture");
		return;
	}

	
	my $nochange_timeout_minutes = 20;
	my $nochange_timeout_seconds = ($nochange_timeout_minutes * 60);
	my $monitor_delay_seconds = 30;
	
	my $monitor_start_time = time;
	my $last_change_time = $monitor_start_time;
	my $nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
	
	# Sanity check, timeout the monitoring after 4 hours
	my $overall_timeout_hours = 6;
	my $overall_timeout_minutes = ($overall_timeout_hours * 60);
	my $overall_timeout_time = ($monitor_start_time + $overall_timeout_minutes * 60);
	
	my $previous_status;
	my $previous_image_size = 0;
	my $current_time;
	MONITOR_CAPTURE: while (($current_time = time) < $nochange_timeout_time && $current_time < $overall_timeout_time) {
		my $total_elapsed_seconds = ($current_time - $monitor_start_time);
		my $nochange_elapsed_seconds = ($current_time - $last_change_time);
		my $nochange_remaining_seconds = ($nochange_timeout_time - $current_time);
		my $overall_remaining_seconds = ($overall_timeout_time - $current_time);
		notify($ERRORS{'DEBUG'}, 0, "monitoring capture of $image_name on $computer_node_name:\n" .
			"seconds since monitor start/until unconditional timeout: $total_elapsed_seconds/$overall_remaining_seconds\n" .
			"seconds since last change/until no change timeout: $nochange_elapsed_seconds/$nochange_remaining_seconds"
		);
		
		if ($self->mn_os->file_exists($capture_done_file_path)) {
			notify($ERRORS{'OK'}, 0, "capture of $image_name on $computer_node_name complete, file exists: $capture_done_file_path");
			$self->mn_os->delete_file($capture_done_file_path);
			last MONITOR_CAPTURE;
		}
		elsif ($self->mn_os->file_exists($capture_failed_file_path)) {
			notify($ERRORS{'WARNING'}, 0, "failed to capture $image_name on $computer_node_name, file exists: $capture_failed_file_path");
			$self->mn_os->delete_file($capture_failed_file_path);
			return;
		}
		
		# Check if the image size has changed
		my $current_image_size = $self->get_image_size($image_name);
		if ($current_image_size ne $previous_image_size) {
			notify($ERRORS{'DEBUG'}, 0, "size of $image_name changed: $previous_image_size --> $current_image_size, reset monitoring timeout to $nochange_timeout_seconds seconds");
			
			# Set previous image size to the current image size
			$previous_image_size = $current_image_size;
			
			$last_change_time = $current_time;
			$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
		}
		else {
			# Get the current status of the node
			my $current_status = $self->_nodestat($computer_node_name);
			# Set previous status to current status if this is the first iteration
			$previous_status = $current_status if !defined($previous_status);
			if ($current_status ne $previous_status) {
				
				# If the node status changed to 'boot' and the image size > 0, assume image capture complete
				if ($current_status =~ /boot/ && $current_image_size > 0) {
					notify($ERRORS{'DEBUG'}, 0, "image capture appears to be complete, node status changed: $previous_status --> $current_status, image size > 0: $current_image_size");
					last MONITOR_CAPTURE;
				}
				
				notify($ERRORS{'DEBUG'}, 0, "status of $computer_node_name changed: $previous_status --> $current_status, reset monitoring timeout to $nochange_timeout_seconds seconds");
				
				# Set previous status to the current status
				$previous_status = $current_status;
				
				$last_change_time = $current_time;
				$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
			}
		}
		
		notify($ERRORS{'DEBUG'}, 0, "sleeping for $monitor_delay_seconds seconds");
		sleep $monitor_delay_seconds;
	}
	
	# Check if timeout was reached
	if ($current_time >= $nochange_timeout_time) {
		notify($ERRORS{'WARNING'}, 0, "failed to capture $image_name on $computer_node_name, timed out because no progress was detected for $nochange_timeout_minutes minutes");
		return;
	}
	elsif ($current_time >= $overall_timeout_time) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to capture $image_name on $computer_node_name, timed out because capture took longer than $overall_timeout_hours hours");
		return;
	}
	
	# Set the permissions on the captured image files
	$self->mn_os->set_file_permissions("$image_repository_path/$image_name\*", 644, 1);
	
	notify($ERRORS{'OK'}, 0, "successfully captured $image_name on $computer_node_name");
	return 1;
}
#//////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : $image_name (optional)
 Returns     : boolean
 Description : Checks the management node's local image repository for the
               existence of the requested image and xCAT template (.tmpl) file.
               If the image files exist but the .tmpl file does not, it creates
               the .tmpl file. If a .tmpl file exists but the image files do
               not, it deletetes the orphaned .tmpl file.
               
               This subroutine does not attempt to copy the image from another
               management node. The retrieve_image() subroutine does this.
               Callers of does_image_exist must also call retrieve_image if
               image library retrieval functionality is desired.

=cut

sub does_image_exist {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}

	# Get the image name, first try passed argument, then data
	my $image_name = shift || $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image name");
		return;
	}
	
	# Get the image install type
	my $image_os_install_type = $self->data->get_image_os_install_type();
	if (!$image_os_install_type) {
		notify($ERRORS{'WARNING'}, 0, "image OS install type could not be determined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image OS install type: $image_os_install_type");
	}

	# Get the image repository path
	my $image_repository_path = $self->get_image_repository_directory_path($image_name);
	if (!$image_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "image repository path could not be determined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image repository path: $image_repository_path");
	}
	
	# Run du to get the size of the image files if the image exists
	my $du_command;
	if ($image_os_install_type eq 'kickstart') {
		$du_command = "du -c $image_repository_path 2>&1 | grep total 2>&1"
	}
	else {
		$du_command = "du -c $image_repository_path/*$image_name* 2>&1 | grep total 2>&1"
	}

	my ($du_exit_status, $du_output) = $self->mn_os->execute($du_command);
	
	# If the partner doesn't have the image, a "no such file" error should be displayed
	my $image_files_exist;
	if (!defined($du_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command $du_command");
		return;
	}
	elsif (grep(/no such file/i, @$du_output)) {
		notify($ERRORS{'OK'}, 0, "$image_name does NOT exist");
		$image_files_exist = 0;
	}
	elsif (!grep(/\d+\s+total/i, @$du_output)) {
		notify($ERRORS{'WARNING'}, 0, "du output does not contain a total line:\n" . join("\n", @$du_output));
		return;
	}
	
	# Return 1 if the image size > 0
	my ($image_size) = (@$du_output[0] =~ /(\d+)\s+total/);
	if ($image_size && $image_size > 0) {
		my $image_size_mb = int($image_size / 1024);
		notify($ERRORS{'DEBUG'}, 0, "$image_name exists in $image_repository_path, size: $image_size_mb MB");
		$image_files_exist = 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image does NOT exist: $image_name");
		$image_files_exist = 0;
	}

	# Image files exist, make sure template (.tmpl) file exists
	# Get the tmpl repository path
	my $tmpl_repository_path = $self->_get_tmpl_directory_path($image_name);
	if (!$tmpl_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "image template path could not be determined for $image_name");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "template repository path for $image_name: $tmpl_repository_path");
	}
	
	# Check if template file exists for the image
	# -s File has nonzero size
	my $tmpl_file_exists;
	if (-s "$tmpl_repository_path/$image_name.tmpl") {
		$tmpl_file_exists = 1;
		notify($ERRORS{'DEBUG'}, 0, "template file exists: $image_name.tmpl");
	}
	else {
		$tmpl_file_exists = 0;
		notify($ERRORS{'DEBUG'}, 0, "template file does not exist: $tmpl_repository_path/$image_name.tmpl");
	}
	
	# Check if either tmpl file or image files exist, but not both
	# Attempt to correct the situation:
	#    tmpl file exists but not image files: delete tmpl file
	#    image files exist but not tmpl file: create tmpl file
	if ($tmpl_file_exists && !$image_files_exist && $image_os_install_type ne 'kickstart') {
		notify($ERRORS{'WARNING'}, 0, "template file exists but image files do not for $image_name");

		# Attempt to delete the orphaned tmpl file for the image
		if ($self->_delete_template($image_name)) {
			notify($ERRORS{'OK'}, 0, "deleted orphaned template file for image $image_name");
			$tmpl_file_exists = 0;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to delete orphaned template file for image $image_name, returning undefined");
			return;
		}
	} ## end if ($tmpl_file_exists && !$image_files_exist)
	elsif (!$tmpl_file_exists && $image_files_exist && $image_os_install_type ne 'kickstart') {
		notify($ERRORS{'WARNING'}, 0, "image files exist but template file does not for $image_name");

		# Attempt to create the missing tmpl file for the image
		if ($self->_create_template($image_name)) {
			notify($ERRORS{'OK'}, 0, "created missing template file for image $image_name");
			$tmpl_file_exists = 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create missing template file for image $image_name, returning undefined");
			return;
		}
	} ## end elsif (!$tmpl_file_exists && $image_files_exist) [ if ($tmpl_file_exists && !$image_files_exist)

	# Check if both image files and tmpl file were found and return
	if ($tmpl_file_exists && $image_files_exist) {
		notify($ERRORS{'DEBUG'}, 0, "image $image_name exists on this management node");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "image $image_name does NOT exist on this management node");
		return 0;
	}

} ## end sub does_image_exist

#//////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : $image_name (optional)
 Returns     : integer
 Description : Retrieves the image size in megabytes.

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Either use a passed parameter as the image name or use the one stored in this object's DataStructure
	my $image_name = shift || $self->data->get_image_name();
	if (!$image_name) {
		notify($ERRORS{'CRITICAL'}, 0, "image name could not be determined");
		return;
	}
	
	my $image_repository_path = $self->get_image_repository_directory_path($image_name);
	if (!$image_repository_path) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to determine image repository location, returning 0");
		return;
	}

	# Execute the command
	my $du_command = "du -c $image_repository_path/$image_name* 2>&1";
	#notify($ERRORS{'DEBUG'}, 0, "du command: $du_command");
	my $du_output = `$du_command`;

	# Save the exit status
	my $du_exit_status = $? >> 8;
	
	# Make sure du produced output
	if (!defined($du_output) || length($du_output) == 0) {
		notify($ERRORS{'WARNING'}, 0, "du did not product any output, du exit status: $du_exit_status");
		return;
	}
	
	# Check if image doesn't exist
	if ($du_output && $du_output =~ /No such file.*0\s+total/is) {
		notify($ERRORS{'OK'}, 0, "image does not exist: $image_repository_path/$image_name.*, returning 0");
		return 0;
	}
	
	# Check the du command output
	my ($size_bytes) = $du_output =~ /(\d+)\s+total/s;
	if (!defined $size_bytes) {
		notify($ERRORS{'WARNING'}, 0, "du command did not produce expected output, du exit staus: $du_exit_status, output:\n$du_output");
		return;
	}

	# Calculate the size in MB
	my $size_mb = int($size_bytes / 1024);
	notify($ERRORS{'DEBUG'}, 0, "returning image size: $size_mb MB ($size_bytes bytes)");
	return $size_mb;

} ## end sub get_image_size

#//////////////////////////////////////////////////////////////////////////////

=head2 get_nodetype_image_os_name

 Parameters  : $image_name
 Returns     : string
 Description : Determines the name of the directory where installation files
               should reside under the management node's install path.
               Examples:
					* image
               * centos5
					* rhels7.2
					* ubuntu16.04.1
               
					The path is determined by first checking if a directory exists
					matching the database values:
					* managementnode.installpath (ex: /install)
					* OS.sourcepath (ex: rhel7)
					* image.architecture (ex: x86_64)
					
					Based on these values, the default path will be:
					/install/rhel7/x86_64
               
               If a directory exactly matching OS.sourcepath cannot be located
               on the managementnode node, an attempt is made to locate an
               alternate suitable directory matching the distribution and major
               version. Example, if OS.sourcepath = 'rhel7' and the default
               directory does not exist:
               /install/rhel7/x86_64
               
               Any of the following paths which exist on the management node may
               be returned:
               /install/rhel7.1/x86_64
               /install/rhels7.2/x86_64
               
               If all of these paths exist, the path with the highest version is
               returned:
               rhels7.2
               
               Note: for 'rhel', both 'rhel' and 'rhels' are checked.

=cut


sub get_nodetype_image_os_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Get the image name argument
	my $image_name = shift || $self->data->get_image_name();
	
	# Check if path has already been determined
	if (defined($self->{xcat_image_os_name}{$image_name})) {
		return $self->{xcat_image_os_name}{$image_name};
	}
	
	my $management_node_hostname = $self->data->get_management_node_hostname();
	my $management_node_install_path = $self->data->get_management_node_install_path() || return;
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	my $os_install_type    = $image_data->get_image_os_install_type() || return;
	my $os_source_path     = $image_data->get_image_os_source_path() || return;
	my $image_architecture = $image_data->get_image_architecture() || return;
	
	if ($os_install_type =~ /image/i) {
		notify($ERRORS{'DEBUG'}, 0, "OS install type for image $image_name is $os_install_type, returning 'image'");
		$self->{xcat_image_os_name}{$image_name} = 'image';
		return 'image';
	}
	elsif ($os_install_type !~ /(kickstart|netboot)/) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine nodetype image OS name for image $image_name, OS install type is not supported: $os_install_type");
		return;
	}
	
	# Remove trailing / from $management_node_install_path if exists
	$management_node_install_path =~ s/\/+$//g;
	
	# Remove leading and trailing slashes from $os_source_path if exists
	$os_source_path =~ s/^\/+//g;
	$os_source_path =~ s/\/+$//g;

	notify($ERRORS{'DEBUG'}, 0, "attempting to determine nodetype OS name for image on $management_node_hostname:\n" .
		"image name      : $image_name\n" .
		"OS install type : $os_install_type\n" .
		"install path    : $management_node_install_path\n" .
		"OS source path  : $os_source_path\n" .
		"architecture    : $image_architecture"
	);
	
	my $installation_repository_directory_path = "$management_node_install_path/$os_source_path/$image_architecture";
	
	# Check if the default path exists - it's often named something different
	# xCAT's copycds command will use something like /install/rhels6.6
	# OS.sourcepath is probably set to rhel6
	# Creating a symlink doesn't work correctly because xCAT fails to parse directory names which don't contain a period correctly
	if ($self->mn_os->file_exists($installation_repository_directory_path)) {
		$self->{xcat_image_os_name}{$image_name} = $os_source_path;
		notify($ERRORS{'DEBUG'}, 0, "default installation repository directory exists: $installation_repository_directory_path, returning '$self->{xcat_image_os_name}{$image_name}'");
		return $self->{xcat_image_os_name}{$image_name};
	}
	
	# Parse the version of the requested OS source path
	my ($os_distribution_name, $os_version_string, $major_os_version_string) = $os_source_path =~ /^([a-z]+)((\d+)[\d\.]*)$/ig;
	if (!defined($os_distribution_name) || !defined($os_version_string) || !defined($major_os_version_string)) {
		$self->{xcat_image_os_name}{$image_name} = $os_source_path;
		notify($ERRORS{'WARNING'}, 0, "failed to determine nodetype OS name for image $image_name, OS.sourcepath could not be parsed: $os_source_path, returning default path: '$self->{xcat_image_os_name}{$image_name}'");
		return $self->{xcat_image_os_name}{$image_name};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "default installation repository directory path does not exist: $installation_repository_directory_path, attempting to locate another suitable path matching distribution: $os_distribution_name, version: $os_version_string, major version: $major_os_version_string");
	
	# Fix regex for 'rhel' and 'rhels'
	my $os_distribution_regex = $os_distribution_name;
	if ($os_distribution_name =~ /rhel/) {
		$os_distribution_regex = 'rhels?';
	}
	
	my $highest_version_string;
	my $highest_version_directory_path;
	my $highest_version_nodetype_os_name;
	
	# Retrieve list of directories under the root management node install path
	my @check_directory_paths = $self->mn_os->find_files($management_node_install_path, "*", 0, 'd');
	for my $check_directory_path (@check_directory_paths) {
		# Remove trailing slash
		$check_directory_path =~ s/\/+$//g;
		
		next if $check_directory_path eq $management_node_install_path;
		
		# Ignore directories that don't contain the Linux OS distribution name
		if ($check_directory_path !~ /$os_distribution_regex/) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring directory: $check_directory_path, it does not match the pattern for the OS distribution: '$os_distribution_regex'");
			next;
		}
		
		my ($check_nodetype_os_name) = $check_directory_path =~ /\/([^\/]+)$/;
		if (!defined($check_nodetype_os_name)) {
			notify($ERRORS{'WARNING'}, 0, "ignoring directory: $check_directory_path, failed to parse directory name (nodetype OS name)");
			next;
		}
		
		# Parse the version and major version from the directory name
		my ($directory_version_string, $directory_major_version_string) = $check_directory_path =~ /$os_distribution_regex((\d+)[\d\.]*)/;
		if (!defined($directory_version_string) || !defined($directory_major_version_string)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring directory: $check_directory_path, version could not be determined");
			next;
		}
		
		# Make sure the major version matches
		if ($directory_major_version_string ne $major_os_version_string) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring directory: $check_directory_path, major version $directory_major_version_string does not match requested major version $major_os_version_string");
			next;
		}
		
		# Make sure the correct architecture subdirectory exists
		my $check_installation_repository_directory_path = "$check_directory_path/$image_architecture";
		if (!$self->mn_os->file_exists($check_installation_repository_directory_path)) {
			notify($ERRORS{'DEBUG'}, 0, "ignoring directory: $check_directory_path, '$image_architecture' subdirectory does not exist");
			next;
		}
		
		if (!$highest_version_string) {
			notify($ERRORS{'DEBUG'}, 0, "1st matching directory is possibly an alternate path: $check_installation_repository_directory_path, version: $directory_version_string");
			$highest_version_string = $directory_version_string;
			$highest_version_directory_path = $check_installation_repository_directory_path;
			$highest_version_nodetype_os_name = $check_nodetype_os_name;
			next;
		}
		
		# Check if the version isn't less than one previously checked
		# Use version->declare->numify to correctly compare versions, otherwise 6.9 > 6.10
		my $matching_version_numified = version->declare("$directory_version_string")->numify;
		my $highest_matching_version_numified = version->declare("$highest_version_string")->numify;
		if ($matching_version_numified <= $highest_matching_version_numified) {
			notify($ERRORS{'DEBUG'}, 0, "directory ignored, version $directory_version_string ($matching_version_numified) is not higher than $highest_version_string ($highest_matching_version_numified): $check_directory_path");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "directory version $directory_version_string ($matching_version_numified) is greater than $highest_version_string ($highest_matching_version_numified): $check_installation_repository_directory_path");
			$highest_version_string = $directory_version_string;
			$highest_version_directory_path = $check_installation_repository_directory_path;
			$highest_version_nodetype_os_name = $check_nodetype_os_name;
			next;
		}
	}
	
	if ($highest_version_nodetype_os_name) {
		$self->{xcat_image_os_name}{$image_name} = $highest_version_nodetype_os_name;
		notify($ERRORS{'OK'}, 0, "located alternate repository directory path on the local management node for kickstart image $image_name: $highest_version_directory_path, returning nodetype OS name: $self->{xcat_image_os_name}{$image_name}");
		return $self->{xcat_image_os_name}{$image_name};
	}
	else {
		$self->{xcat_image_os_name}{$image_name} = $os_source_path;
		notify($ERRORS{'WARNING'}, 0, "failed to locate repository directory path on the local management node for kickstart image $image_name, returning default nodetype OS name: $self->{xcat_image_os_name}{$image_name}");
		return $self->{xcat_image_os_name}{$image_name};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_directory_path

 Parameters  : $image_name, $management_node_identifier (optional)
 Returns     : string
 Description : Determines the path where the image resides on the management
               node. Examples:
               Partimage image: /install/image/x86
               Kickstart image: /install/centos5/x86_64

=cut

sub get_image_repository_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Get the image name argument
	my $image_name = shift || $self->data->get_image_name();
	
	# Check if a management node identifier argument was passed
	my $management_node_identifier = shift;
	my $management_node_hostname;
	if ($management_node_identifier) {
		$management_node_hostname = $self->data->get_management_node_hostname($management_node_identifier);
		if ($management_node_hostname) {
			notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was specified: $management_node_identifier, hostname: $management_node_hostname");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "management node hostname could not be determined from argument: $management_node_identifier");
			return;
		}
	}
	else {
		$management_node_hostname = $self->data->get_management_node_hostname();
	}
	
	# Check if path has already been determined
	if (defined($self->{xcat_image_repository_directory_path}{$image_name}{$management_node_hostname})) {
		return $self->{xcat_image_repository_directory_path}{$image_name}{$management_node_hostname};
	}
	
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier) || return;
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	my $os_install_type = $image_data->get_image_os_install_type() || return;
	my $os_source_path = $image_data->get_image_os_source_path() || return;
	my $image_architecture = $image_data->get_image_architecture() || return;
	
	# Remove trailing / from $management_node_install_path if exists
	$management_node_install_path =~ s/\/+$//;
	
	# Remove trailing / from $os_source_path if exists
	$os_source_path =~ s/\/+$//;

	notify($ERRORS{'DEBUG'}, 0, "attempting to determine repository path for image on $management_node_hostname:\n" .
		"install path    : $management_node_install_path\n" .
		"image name      : $image_name\n" .
		"OS install type : $os_install_type\n" .
		"OS source path  : $os_source_path\n" .
		"architecture    : $image_architecture"
	);
	
	
	my $image_repository_directory_path;
	if ($os_source_path =~ /^\//) {
		# If image OS source path has a leading /, assume it was meant to be absolute
		$image_repository_directory_path = $os_source_path;
	}
	elsif ($os_install_type eq 'kickstart') {
		my $nodetype_image_os_name = $self->get_nodetype_image_os_name($image_name) || $os_source_path;
		$image_repository_directory_path = "$management_node_install_path/$nodetype_image_os_name/$image_architecture";
	}
	else {
		# Partimage
		$image_repository_directory_path = "$management_node_install_path/$os_source_path/$image_architecture";
	}
	
	$self->{xcat_image_repository_directory_path}{$image_name}{$management_node_hostname} = $image_repository_directory_path;
	notify($ERRORS{'DEBUG'}, 0, "determined repository directory path: $self->{xcat_image_repository_directory_path}{$image_name}{$management_node_hostname}");
	return $self->{xcat_image_repository_directory_path}{$image_name}{$management_node_hostname};
} ## end sub get_image_repository_directory_path

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_repository_search_paths

 Parameters  : $management_node_identifier (optional)
 Returns     : array
 Description : Returns an array containing all of the possible paths where an
               image may reside on the management node.

=cut

sub get_image_repository_search_paths {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_identifier = shift || $self->data->get_management_node_hostname();
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier) || return;
	my $image_name = $self->data->get_image_name();
	my $image_architecture = $self->data->get_image_architecture();
	
	# Remove trailing slash if it exists
	$management_node_install_path =~ s/[\\\/]+$//;
	
	my @repository_search_directory_paths;
	for my $base_directory_path ($management_node_install_path, '/install') {
		push @repository_search_directory_paths, $base_directory_path;
		push @repository_search_directory_paths, "$base_directory_path/image";
		push @repository_search_directory_paths, "$base_directory_path/images";
		
		for my $directory_name ($image_architecture, "x86", "x86_64") {
			push @repository_search_directory_paths, "$base_directory_path/image/$directory_name";
			push @repository_search_directory_paths, "$base_directory_path/images/$directory_name";
			push @repository_search_directory_paths, "$base_directory_path/$directory_name";
		}
	}
	
	my @repository_search_paths;
	for my $repository_search_directory_path (@repository_search_directory_paths) {
		push @repository_search_paths, "$repository_search_directory_path/$image_name-*";
		push @repository_search_paths, "$repository_search_directory_path/$image_name.*";
	}
	
	my %seen;
	@repository_search_paths = grep { !$seen{$_}++ } @repository_search_paths;
	
	notify($ERRORS{'DEBUG'}, 0, "repository search paths on $management_node_identifier:\n" . join("\n", @repository_search_paths));
	return @repository_search_paths;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : $computer_node_name (optional)
 Returns     : boolean
 Description : Powers off and then powers on the computer.

=cut

sub power_reset {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified and could not be retrieved from \$self->data");
		return;
	}

	# Turn computer off
	my $off_attempts = 0;
	while (!$self->power_off($computer_node_name)) {
		$off_attempts++;
		if ($off_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name off, rpower status not is off after 3 attempts");
			return;
		}
		sleep 2;
	}

	# Turn computer on
	my $on_attempts = 0;
	while (!$self->power_on($computer_node_name)) {
		$on_attempts++;
		if ($on_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name on, rpower status not is on after 3 attempts");
			return;
		}
		sleep 2;
	}

	notify($ERRORS{'OK'}, 0, "successfully reset power on $computer_node_name");
	return 1;
} ## end sub power_reset

#//////////////////////////////////////////////////////////////////////////////

=head2 power_on

 Parameters  : $computer_node_name (optional)
 Returns     : boolean
 Description : Powers on the computer then checks to verify the computer is
               powered on.

=cut

sub power_on {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified and could not be retrieved from \$self->data");
		return;
	}
	
	# Turn computer on
	my $on_attempts  = 0;
	my $power_status = 'unknown';
	while ($power_status !~ /on/) {
		$on_attempts++;
		if ($on_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name on, rpower status not is on after 3 attempts");
			return;
		}
		$self->_rpower($computer_node_name, 'on');
		# Wait up to 1 minute for the computer power status to be on
		if ($self->_wait_for_on($computer_node_name, 60)) {
			last;
		}
		$power_status = $self->power_status($computer_node_name);
	} ## end while ($power_status !~ /on/)

	notify($ERRORS{'OK'}, 0, "successfully powered on $computer_node_name");
	return 1;
} ## end sub power_on

#//////////////////////////////////////////////////////////////////////////////

=head2 power_off

 Parameters  : $computer_node_name (optional)
 Returns     : boolean
 Description : Powers off the computer then checks to verify the computer is
               powered off.

=cut

sub power_off {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified and could not be retrieved from \$self->data");
		return;
	}
	
	# Turn computer off
	my $power_status = 'unknown';
	my $off_attempts = 0;
	while ($power_status !~ /off/) {
		$off_attempts++;
		if ($off_attempts == 3) {
			notify($ERRORS{'WARNING'}, 0, "failed to turn $computer_node_name off, rpower status not is off after 3 attempts");
			return;
		}
		
		# Attempt to run rpower <node> off
		$self->_rpower($computer_node_name, 'off');
		
		# Wait up to 1 minute for the computer power status to be off
		if ($self->_wait_for_off($computer_node_name, 60)) {
			last;
		}
		
		$power_status = $self->power_status($computer_node_name);
		if (!defined($power_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to powered off $computer_node_name, failed to determine power_status");
			return;
		}
	} ## end while ($power_status !~ /off/)

	notify($ERRORS{'OK'}, 0, "successfully powered off $computer_node_name");
	return 1;
} ## end sub power_off

#//////////////////////////////////////////////////////////////////////////////

=head2 power_status

 Parameters  : $computer_node_name (optional)
 Returns     : string
 Description : Retrieves the power status of the computer. The return value will
               either be 'on', 'off', or undefined if an error occurred.

=cut

sub power_status {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified and could not be retrieved from \$self->data");
		return;
	}
	
	# Call rpower to determine power status
	my $rpower_stat = $self->_rpower($computer_node_name, 'stat');
	if (!defined($rpower_stat)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve power status of $computer_node_name");
		return;
	}
	elsif ($rpower_stat =~ /^(on|off)$/i) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved power status of $computer_node_name: $rpower_stat");
		return lc($1);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine power status, unexpected output returned from rpower: $rpower_stat");
		return;
	}
} ## end sub power_status

#//////////////////////////////////////////////////////////////////////////////

=head2 _edit_nodelist

 Parameters  : $computer_node_name, $image_name
 Returns     : boolean
 Description : Edits the nodelist table to assign the xCAT node to the correct
               groups. For image-based images: all,blade,image. Otherwise,
               image.project is checked. If image.project = 'vcl', the groups
               are all,blade,compute. If image.project is something other than
               'vcl', the groups are all,blade,<image.project>.

=cut

sub _edit_nodelist {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	# Get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	my $image_os_install_type = $image_data->get_image_os_install_type() || return;
	my $image_project = $image_data->get_image_project() || return;
	
	my $request_state_name = $self->data->get_request_state_name();
	
	# Determine the postscript group name
	# If image project is 'vcl', postscript group = 'compute'
	# Otherwise postscript group is the same as the image project
	# For HPC, use image project = vclhpc. There should be an xCAT postscript group named 'vclhpc' configured with specific HPC postscripts
	
	my $groups;
	if ($request_state_name =~ /(image|checkpoint)/) {
		# Image-based install or capture
		$groups = "all,blade,image";
	}
	elsif ($image_project eq "vcl") {
		$groups = "all,blade,compute";
	}
	else {
		# Likely a Kickstart based install
		$groups = "all,blade,$image_project";
	}
	
	my $command = "$XCAT_ROOT/bin/nodech $computer_node_name nodelist.groups=$groups";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to set xCAT groups for $computer_node_name");
		return;
	}
	elsif (grep(/Error/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set xCAT groups for $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/\w/, @$output)) {
		# nodech normally doesn't produce any output if successful, display a warning if the output is not blank
		notify($ERRORS{'WARNING'}, 0, "unexpected output encountered attempting to set xCAT groups for $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "set xCAT groups for $computer_node_name, command: '$command'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _edit_nodetype

 Parameters  : $computer_node_name, $image_name
 Returns     : boolean
 Description : Edits the nodetype table for the computer to set nodetype.os,
               nodetype.arch, and nodetype.profile to the image.

=cut

sub _edit_nodetype {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	# Get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	
	my $image_architecture		= $image_data->get_image_architecture();
	my $image_os_install_type	= $image_data->get_image_os_install_type();
	my $image_os_name				= $image_data->get_image_os_name();
	
	my $request_state_name = $self->data->get_request_state_name();
	
	my $nodetype_os;
	if ($request_state_name =~ /(image|checkpoint)/ || $image_os_install_type =~ /image/) {
		$nodetype_os = 'image';
	}
	elsif ($image_os_install_type =~ /kickstart/i) {
		# Try to dynamically determine the value for nodetype.os
		$nodetype_os = $self->get_nodetype_image_os_name($image_name);
	}
	else {
		$nodetype_os = $image_os_name;
	}
	
	my $command = "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.os=$nodetype_os nodetype.arch=$image_architecture nodetype.profile=$image_name";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to edit xCAT configuration of $computer_node_name: $command");
		return;
	}
	elsif (grep(/Error/i, @$output)) {
		# If an error occurs the output will look like this:
		# Error: Invalid nodes and/or groups in noderange: vclh3-00
		notify($ERRORS{'WARNING'}, 0, "failed to edit xCAT configuration of $computer_node_name, command: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/\w/, @$output)) {
		# nodech normally doesn't produce any output if successful, display a warning if the output is not blank
		notify($ERRORS{'WARNING'}, 0, "unexpected output encountered attempting to edit xCAT configuration of $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "edited xCAT configuration of $computer_node_name, command: '$command'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _lsdef

 Parameters  : $computer_node_name
 Returns     : hash reference
 Description : Runs lsdef to retrieve the xCAT object definition of the node.

=cut

sub _lsdef {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}

	my $command = "$XCAT_ROOT/bin/lsdef $computer_node_name";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute lsdef command for $computer_node_name");
		return;
	}
	
	# Expected output:
	# Object name: vclh3-4
	#    arch=x86_64
	#    cons=blade
	#    currchain=boot
	#    currstate=install centos5-x86_64-centos5-base641008-v0
	#    installnic=eth0
	#    kernel=xcat/centos5/x86_64/vmlinuz
	#    mac=xx:xx:xx:xx:xx:xx
	#    ...
	
	my $node_info = {};
	for my $line (@$output) {
		my ($property, $value) = $line =~ /^[\s\t]+(\w[^=]+)=(.+)$/;
		if (defined($property) && defined($value)) {
			$node_info->{$property} = $value;
		}
	}
	
	if (grep(/Error:/i, @$output) || !keys(%$node_info)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run lsdef for $computer_node_name, output:\n" . join("\n", @$output));
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved xCAT object definition for $computer_node_name:\n" . format_data($node_info));
	return $node_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2  _nodestat

 Parameters  : $computer_name
 Returns     : string
 Description : 

=cut

sub _nodestat {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $command = "$XCAT_ROOT/bin/nodestat $computer_node_name";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute nodestat command for $computer_node_name");
		return;
	}
	
	# Expected output:
	#   vclh3-4: installing prep
	for my $line (@$output) {
		my ($status) = $line =~ /^$computer_node_name:\s+(.+)$/;
		if ($status) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved nodestat status of $computer_node_name: '$status'");
			return $status;
		}
	}
	
	# Line containing node name was not found
	notify($ERRORS{'WARNING'}, 0, "failed to retrieve nodestat status of $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _nodeset

 Parameters  : $computer_name, $nodeset_option
 Returns     : boolean or string
 Description : Runs nodeset to set the boot state of the node.

=cut

sub _nodeset {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	# Get the nodeset option argument
	my $nodeset_option = shift;
	if (!$nodeset_option) {
		notify($ERRORS{'WARNING'}, 0, "nodeset option argument was not specified");
		return;
	}

	my $command = "$XCAT_ROOT/sbin/nodeset $computer_node_name $nodeset_option";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute nodeset command for $computer_node_name");
		return;
	}
	elsif (grep(/(Error:|nodeset failure)/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute nodeset command for $computer_node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Expected output:
	#   $ nodeset vclh3-4 boot
	#   vclh3-4: boot
	#   $ nodeset vclh3-4 image
	#   vclh3-4: image image-x86-centos5image-arktest-v0
	# Find the line containing the node name
	for my $line (@$output) {
		my ($status) = $line =~ /^$computer_node_name:\s+(.+)$/;
		if ($status) {
			if ($nodeset_option eq 'stat') {
				notify($ERRORS{'DEBUG'}, 0, "retrieved nodeset status of $computer_node_name: '$status'");
				return $status;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "set nodeset status of $computer_node_name to $nodeset_option, output:\n" . join("\n", @$output));
				return 1;
			}
		}
	}
	
	# Line containing node name was not found
	if ($nodeset_option eq 'stat') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve nodeset status of $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set nodeset status of $computer_node_name to $nodeset_option\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	}
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2  _get_nodeset_all_stat_info

 Parameters  : none
 Returns     : hash reference
 Description : Calls 'nodeset all stat' to retrieve the status of all nodes. A
               hash is constructed. The keys are the node names. The values are
               the status.

=cut

sub _get_nodeset_all_stat_info {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $command = "$XCAT_ROOT/sbin/nodeset all stat";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve xCAT nodeset status for all nodes");
		return;
	}
	elsif (grep(/^Error:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve xCAT nodeset status for all nodes\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my $nodeset_stat_info = {};
	for my $line (@$output) {
		my ($node, $status) = $line =~ /^([^:]+):\s+(.+)$/;
		if ($node && $status) {
			$nodeset_stat_info->{$node} = $status;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to parse nodeset stat output line: '$line'");
		}
	}
	
	return $nodeset_stat_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _wait_for_on

 Parameters  : $computer_node_name, $total_wait_seconds (optional)
 Returns     : boolean
 Description : Loops until the computer's power status is 'on'. The default wait
               time is 1 minute.

=cut

sub _wait_for_on {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $total_wait_seconds = shift || 60;
	
	return $self->code_loop_timeout(
		sub {
			my $power_status = $self->power_status(@_) || '';
			$power_status =~ /on/i ? 1 : 0;
		},
		[$computer_node_name], "waiting for $computer_node_name to power on", $total_wait_seconds, 5
	);
} ## end sub _wait_for_on

#//////////////////////////////////////////////////////////////////////////////

=head2 _wait_for_off

 Parameters  : $computer_node_name, $total_wait_seconds (optional)
 Returns     : boolean
 Description : Loops until the computer's power status is 'off'. The default
               wait time is 1 minute.

=cut

sub _wait_for_off {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $total_wait_seconds = shift || 60;
	
	return $self->code_loop_timeout(
		sub {
			my $power_status = $self->power_status(@_) || '';
			$power_status =~ /off/i ? 1 : 0;
		},
		[$computer_node_name], "waiting for $computer_node_name to power off", $total_wait_seconds, 5
	);
} ## end sub _wait_for_off

#//////////////////////////////////////////////////////////////////////////////

=head2 _rpower

 Parameters  : $computer_name, $rpower_option
 Returns     : string
 Description : Controls the power of the node by running the xCAT rpower
               command. Options:
                  on           - Turn power on
                  off          - Turn power off
                  stat | state - Return the current power state
                  reset        - Send a hardware reset
                  boot         - If off, then power on. If on, then hard reset.
                  cycle        - Power off, then on
               
               Multiple rpower attempts will be attempted if an error is
               detected. For non-timeout errors, the default number of attempts
               is 3. This can be overridden if either of the following variables
               exist in the variable table in the database:
                  xcat|rpower_error_limit|<management node hostname>
                  xcat|rpower_error_limit
               
               Timeout errors are counted separately and do not count towards
               the general error limit. The default number of timeout errors
               which may be encountered is 5. This can be overridden if either
               of the following variables exist in the variable table in the
               database:
                  xcat|timeout_error_limit|<management node hostname>
                  xcat|timeout_error_limit

=cut

sub _rpower {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $rpower_option = shift;
	if (!$rpower_option) {
		notify($ERRORS{'WARNING'}, 0, "rpower option argument was not specified");
		return;
	}
	
	my $management_node_hostname = $self->data->get_management_node_hostname();
	
	my $command = "$XCAT_ROOT/bin/rpower $computer_node_name $rpower_option";
	
	my $rpower_attempt = 0;
	my $rpower_error_limit = get_variable("xcat|rpower_error_limit|$management_node_hostname", 0) || get_variable("xcat|rpower_error_limit", 0);
	if (!$rpower_error_limit || $rpower_error_limit !~ /^\d+$/) {
		$rpower_error_limit = 3;
	}
	
	my $timeout_error_count = 0;
	my $timeout_error_limit = get_variable("xcat|timeout_error_limit|$management_node_hostname", 0) || get_variable("xcat|timeout_error_limit", 0);
	if (!$timeout_error_limit || $timeout_error_limit !~ /^\d+$/) {
		$timeout_error_limit = 5;
	}
	
	my $rinv_attempted = 0;
	RPOWER_ATTEMPT: while ($rpower_attempt <= ($rpower_error_limit+$timeout_error_count)) {
		$rpower_attempt++;
		
		if ($rpower_attempt > 1) {
			# Wait a random amount of time to prevent several cluster reservations from reattempting at the same time
			my $rpower_attempt_delay = int(rand($rpower_attempt*2))+1;
			
			my $notify_string = "attempt $rpower_attempt/$rpower_error_limit";
			if ($timeout_error_count) {
				$notify_string .= "+$timeout_error_count (timeout errors: $timeout_error_count/$timeout_error_limit)";
			}
			$notify_string .= ": waiting $rpower_attempt_delay before issuing rpower $rpower_option command for $computer_node_name";
			notify($ERRORS{'DEBUG'}, 0, $notify_string);
			sleep $rpower_attempt_delay;
		}
		
		my ($exit_status, $output) = $self->mn_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute rpower command for $computer_node_name");
			return;
		}
		elsif (grep(/Error: Timeout/, @$output)) {
			# blade2f3-14: Error: Timeout
			$timeout_error_count++;
			if ($timeout_error_count >= $timeout_error_limit) {
				notify($ERRORS{'WARNING'}, 0, "attempt $rpower_attempt: failed to issue rpower $rpower_option command for $computer_node_name, timeout error limit reached: $timeout_error_count");
				return;
			}
			else {
				# Wait a random amount of time to prevent several cluster reservations from reattempting at the same time
				my $timeout_error_delay = int(rand($timeout_error_count*3))+1;
				notify($ERRORS{'DEBUG'}, 0, "attempt $rpower_attempt: encountered timeout error $timeout_error_count/$timeout_error_limit");
				next RPOWER_ATTEMPT;
			}
		}
		elsif (grep(/Error:/, @$output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $rpower_attempt: failed to issue rpower command for $computer_node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
			
			# Attempt to run rinv once if an error was detected, it may fix the following error:
			#    Error: Invalid nodes and/or groups in noderange: bladex
			if (!$rinv_attempted) {
				# Attempt to run rinv to fix any inventory problems with the blade
				notify($ERRORS{'DEBUG'}, 0, "attempt $rpower_attempt: failed to initiate rpower for $computer_node_name, attempting to run rinv");
				$self->_rinv($computer_node_name);
				$rinv_attempted = 1;
			}
			
			next RPOWER_ATTEMPT;
		}
		
		# Expected output:
		# Invalid node is specified (exit status = 0):
		#    [root@managementnode]# rpower vclb2-8x stat
		#    invalid node, group, or range: vclb2-8x
		# Successful off (exit status = 0):
		#    [root@managementnode]# rpower vclb2-8 off
		#    vclb2-8: off
		# Successful reset (exit status = 0):
		#    [root@managementnode test]# rpower vclb2-8 reset
		#    vclb2-8: reset
		# Successful stat (exit status = 0):
		#    [root@managementnode test]# rpower vclb2-8 stat
		#    vclb2-8: on
		# Successful cycle (exit status = 0):
		#	  [root@managementnode test]# rpower vclb2-8 cycle
		#    vclb2-8: off on
		
		# Find the line containing the node name
		for my $line (@$output) {
			my ($status) = $line =~ /^$computer_node_name:.*\s([^\s]+)$/;
			if ($status) {
				notify($ERRORS{'DEBUG'}, 0, "issued rpower $rpower_option command for $computer_node_name, status line: '$line', returning '$status'");
				return $status;
			}
		}
		
		notify($ERRORS{'WARNING'}, 0, "failed to parse rpower output\ncommand: $command\noutput:\n" . join("\n", @$output));
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to issue rpower command for $computer_node_name, made $rpower_attempt attempts");
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _rinv

 Parameters  : $computer_name
 Returns     : hash reference
 Description : Retrieves the hardware inventory of the node. A hash is returned,
               usually containing the following parameters:
               {
                 "BIOS" => "1.14 (MJE133AUS 03/13/2009)",
                 "BMC/Mgt processor" => "1.30 (MJBT30A)",
                 "Diagnostics" => "1.03 (MJYT17AUS 03/07/2008)",
                 "MAC Address 1" => "xx:xx:xx:xx:xx:xx",
                 "MAC Address 2" => "yy:yy:yy:yy:yy:yy",
                 "Machine Type/Model" => 7995,
                 "Management Module firmware" => "50 (BPET50P 03/26/2010)",
                 "Serial Number" => "wwwwwww"
               }

=cut

sub _rinv {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $command = "$XCAT_ROOT/bin/rinv $computer_node_name";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute rinv command for $computer_node_name");
		return;
	}
	elsif (grep(/Error:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to issue rinv command for $computer_node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Expected output:
	# vclh3-4: Machine Type/Model: 7995
	# vclh3-4: Serial Number: wwwww
	# vclh3-4: MAC Address 1: xx:xx:xx:xx:xx:xx
	# vclh3-4: MAC Address 2: yy:yy:yy:yy:yy:yy
	# vclh3-4: BIOS: 1.14 (MJE133AUS 03/13/2009)
	# vclh3-4: Diagnostics: 1.03 (MJYT17AUS 03/07/2008)
	# vclh3-4: BMC/Mgt processor: 1.30 (MJBT30A)
	# vclh3-4: Management Module firmware: 50 (BPET50P 03/26/2010)

	# Find the line containing the node name
	my $rinv_info;
	for my $line (@$output) {
		my ($parameter, $value) = $line =~ /^$computer_node_name:\s+([^:]+):\s+(.+)$/;
		if (defined($parameter) && defined($value)) {
			$rinv_info->{$parameter} = $value;
		}
	}
	
	if ($rinv_info) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved inventory of $computer_node_name:\n" . format_data($rinv_info));
		return $rinv_info;
	}
	else {
		# Line containing node name was not found
		notify($ERRORS{'WARNING'}, 0, "failed to issue rinv command for $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_tmpl_directory_path

 Parameters  : $image_name, $management_node_identifier (optional)
 Returns     : string
 Description : Determines the directory where the image template file resides
               for the image. Example:
               /opt/xcat/share/xcat/install/rh

=cut

sub _get_tmpl_directory_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	# Get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}
	
	# Check if a management node identifier argument was passed
	my $management_node_identifier = shift;
	if ($management_node_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was specified: $management_node_identifier");
	}
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	my $image_os_source_path = $image_data->get_image_os_source_path() || return;
	my $image_os_install_type = $image_data->get_image_os_install_type() || return;
	
	# Remove trailing / from $XCAT_ROOT if exists
	(my $xcat_root = $XCAT_ROOT) =~ s/\/$//;
	
	# Remove trailing / from $image_os_source_path if exists
	$image_os_source_path =~ s/\/$//;
	
	# Fix the image OS source path for xCAT 2.x
	my $xcat2_image_os_source_path = $image_os_source_path;
	# Remove periods
	$xcat2_image_os_source_path =~ s/\.//g;
	# centos5 --> centos
	$xcat2_image_os_source_path =~ s/\d+$//g;
	# rhas5 --> rh
	$xcat2_image_os_source_path =~ s/^rh.*/rh/;
	# esxi --> esx
	$xcat2_image_os_source_path =~ s/^esx.*/esx/i;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to determine template path for image:
      image name:               $image_name
		OS install type:          $image_os_install_type
		OS source path:           $image_os_source_path
		xCAT 2.x OS source path:  $xcat2_image_os_source_path
	");

	my $image_template_path = "$xcat_root/share/xcat/install/$xcat2_image_os_source_path";
	notify($ERRORS{'DEBUG'}, 0, "returning: $image_template_path");
	return $image_template_path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _create_template

 Parameters  : $image_name
 Returns     : boolean
 Description : Creates a template file (.tmpl) for the image.

=cut

sub _create_template {
	my $self = shift;        
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}
	
	# Create a DataStructure object containing info about the image
	my $image_data = $self->create_datastructure_object({image_identifier => $image_name}) || return;
	my $image_os_name = $image_data->get_image_os_name() || return;
	my $image_os_type = $image_data->get_image_os_type_name() || return;
	
	# Get the image template directory path
	my $template_directory_path = $self->_get_tmpl_directory_path($image_name);
	if (!$template_directory_path) {
		notify($ERRORS{'WARNING'}, 0, "template directory path could not be determined") ;
		return;
	}
	
	# Determine the base template filename
	# Find the template file to use, from most specific to least
	# Try OS-specific: <OS name>.tmpl
	my $base_template_file_name;
	if ($self->mn_os->file_exists("$template_directory_path/$image_os_name.tmpl")) {
		$base_template_file_name = "$image_os_name.tmpl";
		notify($ERRORS{'DEBUG'}, 0, "OS specific base image template file found: $template_directory_path/$image_os_name.tmpl");
	}
	elsif ($self->mn_os->file_exists("$template_directory_path/$image_os_type.tmpl")) {
		$base_template_file_name = "$image_os_type.tmpl";
		notify($ERRORS{'DEBUG'}, 0, "OS type specific base image template file found: $template_directory_path/$image_os_type.tmpl");
	}
	elsif ($self->mn_os->file_exists("$template_directory_path/default.tmpl")) {
		$base_template_file_name = "default.tmpl";
		notify($ERRORS{'DEBUG'}, 0, "default base image template file found: $template_directory_path/default.tmpl");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to find suitable base image template file in $template_directory_path");
		return;
	}
	
	my $base_template_file_path = "$template_directory_path/$base_template_file_name";
	my $image_template_file_path = "$template_directory_path/$image_name.tmpl";
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to create template file for image: $image_name\n" .
		"base template file: $base_template_file_path\n" .
		"image template file: $image_template_file_path"
	);
	
	# Create a copy of the base template file
	if (!$self->mn_os->copy_file($base_template_file_path, $image_template_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create template file: $base_template_file_path --> $image_template_file_path");                
		return;
	}
	
	my $template_file_size_bytes = $self->mn_os->get_file_size($image_template_file_path);
	if ($template_file_size_bytes) {
		notify($ERRORS{'DEBUG'}, 0, "verified image template file exists and is not blank: $image_template_file_path, size: $template_file_size_bytes bytes");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve size of new image template file: $image_template_file_path");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "created image template file: $image_template_file_path");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _delete_template

 Parameters  : $image_name
 Returns     : boolean
 Description : Deletes a template file (.tmpl) for the image.

=cut

sub _delete_template {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the image name argument
	my $image_name = shift;
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}

	notify($ERRORS{'OK'}, 0, "attempting to delete tmpl file for image: $image_name");

	# Get the image template repository path
	my $tmpl_repository_path = $self->_get_tmpl_directory_path($image_name);
	if (!$tmpl_repository_path) {
		notify($ERRORS{'WARNING'}, 0, "xCAT template repository information could not be determined");
		return;
	}

	# Delete the template file
	my $rm_output      = `/bin/rm -fv  $tmpl_repository_path/$image_name.tmpl 2>&1`;
	my $rm_exit_status = $? >> 8;

	# Check if $? = -1, this likely means a Perl CHLD signal bug was encountered
	if ($? == -1) {
		notify($ERRORS{'OK'}, 0, "\$? is set to $?, setting exit status to 0, Perl bug likely encountered");
		$rm_exit_status = 0;
	}

	if ($rm_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "deleted $tmpl_repository_path/$image_name.tmpl, output:\n$rm_output");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete $tmpl_repository_path/$image_name.tmpl, returning undefined, exit status: $rm_exit_status, output:\n$rm_output");
		return;
	}

	# Make sure template file was deleted
	# -s File has nonzero size
	my $tmpl_file_exists;
	if (-s "$tmpl_repository_path/$image_name.tmpl") {
		notify($ERRORS{'WARNING'}, 0, "template file should have been deleted but still exists: $tmpl_repository_path/$image_name.tmpl, returning undefined");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "confirmed template file was deleted: $tmpl_repository_path/$image_name.tmpl");
	}

	notify($ERRORS{'OK'}, 0, "successfully deleted template file: $tmpl_repository_path/$image_name.tmpl");
	return 1;
} ## end sub _delete_template

#//////////////////////////////////////////////////////////////////////////////

=head2 _is_throttle_limit_reached

 Parameters  : $throttle_limit
 Returns     : boolean
 Description : Checks the status of all nodes and counts how many are currently
               installing or capturing an image (nodeset status is either
               'install' or 'image'). The processes running on the management
               node are then checked to determine if a vcld process is actually
               running for each of the active nodes reported by nodeset. Nodes
               only count against the throttle limit if a process is running.

=cut

sub _is_throttle_limit_reached {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the throttle limit argument
	my $throttle_limit = shift;
	if (!defined($throttle_limit)) {
		notify($ERRORS{'WARNING'}, 0, "throttle limit argument was not supplied");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Get the nodeset status for all nodes
	my $nodeset_all_stat_info = $self->_get_nodeset_all_stat_info();
	if (!defined($nodeset_all_stat_info)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if throttle limit is reached, failed to retrieve nodeset status of all nodes");
		return;
	}
	#notify($ERRORS{'DEBUG'}, 0, "retrieved nodeset status of all nodes:\n" . format_data($nodeset_all_stat_info));
	
	my @nodeset_active_nodes;
	for my $node_name (keys %$nodeset_all_stat_info) {
		my $node_status = $nodeset_all_stat_info->{$node_name};
		
		# Ignore this computer
		if ($node_name eq $computer_node_name) {
			next;
		}
		
		if ($node_status =~ /^(install|image)/i) {
			push @nodeset_active_nodes, $node_name;
		}
	}
	
	# Check if throttle limit has been reached according to nodeset
	my $nodeset_active_node_count = scalar(@nodeset_active_nodes);
	if ($nodeset_active_node_count < $throttle_limit) {
		notify($ERRORS{'DEBUG'}, 0, "throttle limit has NOT been reached according to nodeset:\nnodes currently being installed or captured: $nodeset_active_node_count\nthrottle limit: $throttle_limit");
		return 0;
	}
	
	# nodeset reports that the throttle limit has been reached
	# This doesn't necessarily mean all those nodes are really being installed or captured
	# If problems occur, a vcld process may die and leave nodes in the install or image state
	# Verify that a running process exists for each node
	notify($ERRORS{'DEBUG'}, 0, "throttle limit has been reached according to nodestat:\nnodes currently being installed or captured: $nodeset_active_node_count\nthrottle limit: $throttle_limit");
	
	# Get the list of all vcld processes running on the management node
	my $process_identifier = $PROCESSNAME;
	if ($PROCESSNAME ne 'vcld') {
		$process_identifier .= "|vcld";
	}
	my $vcld_processes = is_management_node_process_running($process_identifier);
	if (!$vcld_processes) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if nodes are actively being loaded or captured, failed to retrieve names of any running vcld processes");
		return;
	}
	
	my @vcld_process_names = values(%$vcld_processes);
	notify($ERRORS{'DEBUG'}, 0, "vcld process names:\n" . join("\n", @vcld_process_names));
	
	my $active_process_node_count = 0;
	for my $node_name (sort { $a cmp $b } @nodeset_active_nodes) {
		my $nodeset_status = $nodeset_all_stat_info->{$node_name};
		
		my @node_process_names = grep(/\s$node_name\s/, @vcld_process_names);
		my $node_process_count = scalar(@node_process_names);
		if (!$node_process_count) {
			#notify($ERRORS{'DEBUG'}, 0, "ignoring $node_name from throttle limit consideration, nodeset status is '$nodeset_status' but running vcld process NOT detected");
		}
		elsif ($node_process_count == 1) {
			notify($ERRORS{'DEBUG'}, 0, "including $node_name in throttle limit consideration, nodeset status is '$nodeset_status' and 1 running vcld process detected: " . $node_process_names[0]);
			$active_process_node_count++;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "including $node_name in throttle limit consideration, nodeset status is '$nodeset_status', multiple running vcld processes detected: $node_process_count\n" . join("\n", @node_process_names));
			$active_process_node_count++;
		}
	}
	
	if ($active_process_node_count < $throttle_limit) {
		notify($ERRORS{'DEBUG'}, 0, "throttle limit has NOT been reached according to number of processes running:\nnodes currently being installed or captured: $active_process_node_count\nthrottle limit: $throttle_limit");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "throttle limit has been reached according to number of processes running:\nnodes currently being installed or captured: $active_process_node_count\nthrottle limit: $throttle_limit");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_install_status

 Parameters  : $computer_node_name
 Returns     : string
 Description : Attempts to connect to TCP port 3001 on a node to retrieve the
               installation status. This is done to overcome a problem which
               occurs if the node is responding to SSH while it is being
               installed and nodestat returns 'sshd' instead of the more
               detailed status.

=cut

sub _get_install_status {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift;
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	
	my $protocol = 'tcp';
	my $port = 3001;
	
	my $socket;
	if (!socket($socket, PF_INET, SOCK_STREAM, getprotobyname($protocol))) {
		return;
	}
	
	my $host_by_name = gethostbyname($computer_node_name);
	my $sockaddr_in = sockaddr_in($port, $host_by_name);
	if (!connect($socket, $sockaddr_in)) {
		return;
	}
	
	print $socket "stat \n";
	$socket->flush;
	
	my $status;
	while (<$socket>) {
		$status .= $_;
	}
	close($socket);
	
	if ($status =~ /\w/) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved install status from $computer_node_name: '$status'");
		return $status;
	}
	else {
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_image_os

 Parameters  : none
 Returns     : boolean
 Description : For image captures, checks the OS in the VCL database of the
               image to be captured. If capturing a Kickstart-based image, the
               image OS needs to be changed to from the Kickstart OS entry to
               the corresponding image OS entry.

=cut

sub check_image_os {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_state_name = $self->data->get_request_state_name();
	my $image_id           = $self->data->get_image_id();
	my $image_name         = $self->data->get_image_name();
	my $image_os_name      = $self->data->get_image_os_name();
	my $imagerevision_id   = $self->data->get_imagerevision_id();
	my $image_architecture = $self->data->get_image_architecture();
	
	my $image_os_name_new;
	if ($image_os_name =~ /^(rh)el[s]?([0-9])/ || $image_os_name =~ /^rh(fc)([0-9])/) {
		# Change rhelX --> rhXimage, rhfcX --> fcXimage
		$image_os_name_new = "$1$2image";
	}
	elsif ($image_os_name =~ /^(centos)([0-9])/) {
		# Change rhelX --> rhXimage, rhfcX --> fcXimage
		$image_os_name_new = "$1$2image";
	}
	elsif ($image_os_name =~ /^(fedora)([0-9])/) {
		# Change fedoraX --> fcXimage
		$image_os_name_new = "fc$1image"
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no corrections need to be made to image OS: $image_os_name");
		return 1;
	}
	
	# Change the image name
	$image_name =~ /^[^-]+-(.*)/;
	my $image_name_new = "$image_os_name_new-$1";
	
	my $new_architecture = $image_architecture;
	if ($image_architecture eq "x86_64" ) {
		$new_architecture = "x86";
	}
	
	notify($ERRORS{'OK'}, 0, "Kickstart image OS needs to be changed: $image_os_name -> $image_os_name_new, image name: $image_name -> $image_name_new");
	
	# Update the image table, change the OS for this image
	my $sql_statement = <<EOF;
UPDATE
OS,
image,
imagerevision
SET
image.OSid = OS.id,
image.architecture = '$new_architecture',
image.name = '$image_name_new',
imagerevision.imagename = '$image_name_new'
WHERE
image.id = $image_id
AND imagerevision.id = $imagerevision_id
AND OS.name = '$image_os_name_new'
EOF
	
	# Update the image and imagerevision tables
	if (database_execute($sql_statement)) {
		notify($ERRORS{'OK'}, 0, "image ($image_id) and imagerevision ($imagerevision_id) tables updated: $image_name -> $image_name_new");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to update image and imagerevision tables: $image_name -> $image_name_new, returning 0");
		return 0;
	}
	
	if (!$self->data->refresh()) {
		notify($ERRORS{'WARNING'}, 0, "failed to update DataStructure updated correcting image OS");
		return 0;
	}
	
	return 1;
} ## end sub check_image_os

#//////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the xCAT.pm module and resets node to the boot state.

=cut

sub DESTROY {
	my $self = shift;
	if (!defined($self)) {
		notify($ERRORS{'DEBUG'}, 0, "skipping xCAT DESTROY tasks, \$self is not defined");
		return;
	}
	
	my $address = sprintf('%x', $self);
	my $type = ref($self);
	notify($ERRORS{'DEBUG'}, 0, "destroying $type object, address: $address");
	
	if (!$self->data(0)) {
		notify($ERRORS{'DEBUG'}, 0, "skipping xCAT DESTROY tasks, \$self->data is not defined");
	}
	elsif (!$self->mn_os(0)) {
		notify($ERRORS{'DEBUG'}, 0, "skipping xCAT DESTROY tasks, \$self->mn_os is not defined");
	}
	else {
		my $node = $self->data->get_computer_node_name(0);
		my $request_state_name = $self->data->get_request_state_name(0);
		
		if (!defined($node) || !defined($request_state_name)) {
			notify($ERRORS{'DEBUG'}, 0, "skipping xCAT DESTROY tasks, unable to retrieve node name and request state name from DataStructure");
		}
		elsif ($request_state_name =~ /^(new|reload|image|checkpoint)$/) {
			notify($ERRORS{'DEBUG'}, 0, "request state is '$request_state_name', attempting to set nodeset state of $node to 'boot'");
			$self->_nodeset($node, 'boot');
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "request state is '$request_state_name', skipping setting nodeset state of $node to 'boot'");
		}
	}
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
} ## end sub DESTROY

#//////////////////////////////////////////////////////////////////////////////

initialize() if (!$XCAT_ROOT);

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
