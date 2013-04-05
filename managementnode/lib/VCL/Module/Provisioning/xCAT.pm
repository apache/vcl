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
   my $status = $self->provisioner->node_status();
 
 From a script:
   my $xcat = new VCL::Module::Provisioning::xCAT();
   my $status = $xcat->node_status('node1a2-3');

=head1 DESCRIPTION

 This module provides VCL support for xCAT (Extreme Cluster Administration
 Toolkit) version 2.x. xCAT is a scalable distributed computing management and
 provisioning tool that provides a unified interface for hardware control,
 discovery, and OS diskful/diskfree deployment. http://xcat.sourceforge.net

=cut

##############################################################################
package VCL::Module::Provisioning::xCAT;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;
use Fcntl qw(:DEFAULT :flock);
use File::Copy;
use IO::Seekable;

##############################################################################

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

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_node_name $image_name");
	
	# Insert a computerloadlog record and edit nodetype table to set the image information for the computer
	insertloadlog($reservation_id, $computer_id, "editnodetype", "updating nodetype table");
	$self->_edit_nodetype($computer_node_name, $image_name) || return;
	
	# Insert a computerloadlog record and edit nodelist table to set the xCAT groups for the computer
	$self->_edit_nodelist($computer_node_name, $image_name) || return;
	
	# Check to see if management node throttle is configured
	my $throttle_limit;
	my $variable_name = $self->data->get_management_node_hostname() . "|xcat|throttle";
	if ($self->data->is_variable_set($variable_name) && ($throttle_limit = $self->data->get_variable($variable_name))) {
		notify($ERRORS{'DEBUG'}, 0, "'$variable_name' xCAT load throttle limit variable is set in database: $throttle_limit");
		
		my $throttle_limit_wait_seconds = (30 * 60);
		if (!$self->code_loop_timeout(sub{!$self->_is_throttle_limit_reached(@_)}, [$throttle_limit], 'checking throttle limit', $throttle_limit_wait_seconds, 1, 10)) {
			notify($ERRORS{'WARNING'}, 0, "failed to load image due to throttle limit, waited $throttle_limit_wait_seconds seconds");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "'$variable_name' xCAT load throttle limit variable is NOT set in database");
	}
	
	# Run rinstall to initiate the installation
	$self->_rinstall($computer_node_name) || return;
	
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
	
	# rinstall initiated
	#   nodeset changes xCAT state to 'install'
	#   node is power cycled or powered on (nodeset/nodestat status: install/noping)
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
	my $monitor_delay_seconds = 20;
	
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
	
	my $previous_status;
	my $current_time;
	MONITOR_LOADING: while (($current_time = time) < $nochange_timeout_time && $current_time < $overall_timeout_time) {
		my $total_elapsed_seconds = ($current_time - $monitor_start_time);
		my $nochange_elapsed_seconds = ($current_time - $last_change_time);
		my $nochange_remaining_seconds = ($nochange_timeout_time - $current_time);
		my $overall_remaining_seconds = ($overall_timeout_time - $current_time);
		notify($ERRORS{'DEBUG'}, 0, "monitoring $image_name loading on $computer_node_name/$overall_remaining_seconds\n" .
			"seconds since monitor start/until unconditional timeout: $total_elapsed_seconds/$overall_remaining_seconds\n" .
			"seconds since last change/until no change timeout: $nochange_elapsed_seconds/$nochange_remaining_seconds"
		);
		
		
		# Check if any lines have shown in in /var/log/messages for the node
		my @lines = $log->getlines;
		my @dhcp_lines = grep(/dhcpd:.+DHCP.+\s$mac_address\s/i, @lines);
		if (@dhcp_lines) {
			if (grep(/DHCPREQUEST/i, @dhcp_lines)) {
				insertloadlog($reservation_id, $computer_id, "xcatstage1", "requested DHCP lease");
			}
			
			if (my ($dhcpack_line) = grep(/DHCPACK/i, @dhcp_lines)) {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name acquired DHCP lease: '$dhcpack_line'");
				insertloadlog($reservation_id, $computer_id, "xcatstage2", "acquired DHCP lease");
				insertloadlog($reservation_id, $computer_id, "xcatround2", "waiting for boot flag");
			}
			
			notify($ERRORS{'DEBUG'}, 0, "reset no change timeout, DHCP activity detected in $messages_file_path:\n" . join("\n", @dhcp_lines));
			
			# Reset the nochange timeout
			$last_change_time = $current_time;
			$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
		}
		else {
			# Get the current status of the node
			my $current_status = $self->_nodestat($computer_node_name);
			
			# Set previous status to current status if this is the first iteration
			$previous_status = $current_status if !defined($previous_status);
			
			if ($current_status =~ /(boot|complete)/) {
				notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is finished loading image, current status: $current_status");
				insertloadlog($reservation_id, $computer_id, "bootstate", "$computer_node_name image load complete: $current_status");
				last MONITOR_LOADING;
			}
			
			if ($current_status ne $previous_status) {
				notify($ERRORS{'DEBUG'}, 0, "reset no change timeout, status of $computer_node_name changed: $previous_status --> $current_status");
				
				# Set previous status to the current status
				$previous_status = $current_status;
				
				# Reset the nochange timeout
				$last_change_time = $current_time;
				$nochange_timeout_time = ($last_change_time + $nochange_timeout_seconds);
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "status of $computer_node_name has not changed: $current_status");
			}
		}
		
		#notify($ERRORS{'DEBUG'}, 0, "sleeping for $monitor_delay_seconds seconds");
		sleep $monitor_delay_seconds;
	}
	
	$log->close;
	
	# Check if timeout was reached
	if ($current_time >= $nochange_timeout_time) {
		notify($ERRORS{'WARNING'}, 0, "failed to load $image_name on $computer_node_name, timed out because no progress was detected for $nochange_timeout_seconds seconds");
		return;
	}
	elsif ($current_time >= $overall_timeout_time) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to load $image_name on $computer_node_name, timed out because loading took longer than $overall_timeout_minutes minutes");
		return;
	}
	
	# Call the OS module's post_load() subroutine if implemented
	insertloadlog($reservation_id, $computer_id, "xcatround3", "initiating OS post-load configuration");
	if ($self->os->can("post_load")) {
		if ($self->os->post_load()) {
			insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "performed OS post-load tasks on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to perform OS post-load tasks on VM $computer_node_name");
			return;
		}
	}
	else {
		insertloadlog($reservation_id, $computer_id, "loadimagecomplete", "OS post-load tasks not necessary on $computer_node_name");
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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

	# Make sure the computer is powered on
	my $power_status = $self->power_status();
	if (!$power_status || $power_status !~ /on/i) {
		if (!$self->power_on()) {
			notify($ERRORS{'WARNING'}, 0, "failed to power on computer before monitoring image capture");
			return;
		}
	}
	
	# Modify currentimage.txt
	if (!write_currentimage_txt($self->data)) {
		notify($ERRORS{'WARNING'}, 0, "unable to update currentimage.txt on $computer_node_name");
		return;
	}
	
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

#/////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $computer_node_name (optional)
 Returns     : string
 Description : Checks the status of an xCAT-provisioned machine.  If no
               arguments are supplied, the node and image for the current
               reservation will be used. The return value will be one of the
               following:
               
               READY
               If $self->data contains image information:
               - The computer is responding to SSH
               - nodetype.profile is set to the image defined in $self->data
               - Current image retrieved from computer's OS matches $self->data
               If $self->data does not contain image:
               - The computer is responding to SSH
               - Current image retrieved from computer's OS matches
                 nodetype.profile
               
               RELOAD
               - Only returned if $self->data contains image information
               - Either nodetype.profile does not match $self->data or the
                 current image retrieved from computer's OS does not match
                 $self->data
               
               UNRESPONSIVE
               - The computer is not responding to SSH
               
               INCONSISTENT
               - nodetype.profile does not match the current image retrieved
                 from computer's OS

=cut

sub node_status {
	my $self = shift;
	if (ref($self) !~ /xCAT/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the computer name argument
	my $computer_node_name = shift || $self->data->get_computer_node_name();
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer name argument was not specified");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "checking status of node: $computer_node_name");
	
	my $image_name = $self->data->get_image_name(0);
	
	# Check if the node is powered on
	my $power_status = $self->power_status($computer_node_name);
	if (!defined($power_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, failed to retrieve power status");
		return;
	}
	elsif ($power_status !~ /on/) {
		my $return_value = uc($power_status);
		notify($ERRORS{'DEBUG'}, 0, "power status of $computer_node_name is '$power_status', returning '$return_value'");
		return $return_value;
	}
	
	# Get the xCAT definition for the node
	my $node_info = $self->_lsdef($computer_node_name);
	if (!$node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, failed to retrieve xCAT object definition using lsdef utility");
		return;
	}
	
	# Make sure node.profile is configured
	my $node_profile = $node_info->{profile};
	if (!$node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, node.profile is not configured:\n" . format_data($node_info));
		return;
	}
	
	# Check if node.profile matches the reservation image name
	if ($image_name) {
		if ($node_profile eq $image_name) {
			notify($ERRORS{'DEBUG'}, 0, "nodetype.profile matches the reservation image name: $image_name");
		}
		else {
			my $return_value = 'RELOAD';
			notify($ERRORS{'DEBUG'}, 0, "nodetype.profile '$node_profile' does NOT match the reservation image name: '$image_name', returning '$return_value'"); 
			return $return_value;
		}
	}
	
	# Check if $self->os is defined, it may not be if xCAT.pm object is created from a monitoring script
	my $os = $self->os(0);
	if (!$os) {
		my $data;
		eval { $data = new VCL::DataStructure({computer_identifier => $computer_node_name, image_identifier => $node_profile}) };
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, failed to create DataStructure object for image set as nodetype.profile: '$node_profile', error:\n$EVAL_ERROR");
			return;
		}
		elsif (!$data) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, \$self->os is not defined, failed to create DataStructure object for image set as nodetype.profile: '$node_profile'");
			return;
		}
		
		# Set the data, create_os_object copies the data from the calling object to the new OS object
		$self->set_data($data);
		
		my $image_os_module_perl_package = $data->get_image_os_module_perl_package();
		
		$os = $self->create_os_object($image_os_module_perl_package);
		if (!$os) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, failed to create OS object for image set as nodetype.profile: '$node_profile'");
			return;
		}
	}
	
	# Check if the node is responding to SSH
	my $ssh_responding = $os->is_ssh_responding();
	if (!$ssh_responding) {
		my $return_value = 'UNRESPONSIVE';
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, returning '$return_value'");
		return $return_value;
	}
	
	# Check image name reported from OS
	my $current_image_name = $os->get_current_image_info('current_image_name');
	if (!defined($current_image_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine status of $computer_node_name, failed to retrieve current image name from OS");
		return;
	}
	
	# Check if OS's current image matches the reservation image name
	if ($image_name) {
		if ($current_image_name eq $image_name) {
			notify($ERRORS{'DEBUG'}, 0, "current image reported by OS matches the reservation image name: $image_name");
		}
		else {
			my $return_value = 'RELOAD';
			notify($ERRORS{'DEBUG'}, 0, "current image reported by OS '$current_image_name' does NOT match the reservation image name: '$image_name', returning '$return_value'"); 
			return $return_value;
		}
	}
	
	# Check if the OS matches xCAT
	if ($current_image_name eq $node_profile) {
		notify($ERRORS{'DEBUG'}, 0, "nodetype.profile matches current image reported by OS: '$current_image_name'"); 
	}
	else {
		my $return_value = 'INCONSISTENT';
		notify($ERRORS{'DEBUG'}, 0, "nodetype.profile '$node_profile' does NOT match current image reported by OS: '$current_image_name', returning '$return_value'"); 
		return $return_value;
	}
	
	my $return_value = 'READY';
	notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is loaded with the correct image: $current_image_name, returning '$return_value'"); 
	return $return_value;
} ## end sub node_status

#/////////////////////////////////////////////////////////////////////////////

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
	my ($du_exit_status, $du_output) = run_command($du_command);
	
	# If the partner doesn't have the image, a "no such file" error should be displayed
	my $image_files_exist;
	if (defined(@$du_output) && grep(/no such file/i, @$du_output)) {
		notify($ERRORS{'OK'}, 0, "$image_name does NOT exist");
		$image_files_exist = 0;
	}
	elsif (defined(@$du_output) && !grep(/\d+\s+total/i, @$du_output)) {
		notify($ERRORS{'WARNING'}, 0, "du output does not contain a total line:\n" . join("\n", @$du_output));
		return;
	}
	elsif (!defined($du_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if image $image_name exists");
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

#/////////////////////////////////////////////////////////////////////////////

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


#/////////////////////////////////////////////////////////////////////////////

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
	if (!$image_name) {
		notify($ERRORS{'WARNING'}, 0, "image name argument was not specified");
		return;
	}

	# Check if a management node identifier argument was passed
	my $management_node_identifier = shift;
	if ($management_node_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "management node identifier argument was specified: $management_node_identifier");
	}
	
	my $management_node_hostname = $self->data->get_management_node_hostname($management_node_identifier) || '';
	return $self->{image_repository_path}{$image_name}{$management_node_hostname} if defined($self->{image_repository_path}{$image_name}{$management_node_hostname});
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	
	# Create a DataStructure object containing info about the image
	my $image_data = new VCL::DataStructure({image_identifier => $image_name}) || return;
	my $image_id = $image_data->get_image_id() || return;
	my $image_os_name = $image_data->get_image_os_name() || return;
	my $image_os_type = $image_data->get_image_os_type() || return;
	my $image_os_install_type = $image_data->get_image_os_install_type() || return;
	my $image_os_source_path = $image_data->get_image_os_source_path() || return;
	my $image_architecture = $image_data->get_image_architecture() || return;
	
	# Remove trailing / from $image_os_source_path if exists
	$image_os_source_path =~ s/\/$//;
	
	#notify($ERRORS{'DEBUG'}, 0, "attempting to determine repository path for image on $management_node_hostname:
	#	image id:        $image_id
	#	OS name:         $image_os_name
	#	OS type:         $image_os_type
	#	OS install type: $image_os_install_type
	#	OS source path:  $image_os_source_path\n
	#	architecture:    $image_architecture
	#");
	
	# If image OS source path has a leading /, assume it was meant to be absolute
	# Otherwise, prepend the install path
	my $image_install_path;
	if ($image_os_source_path =~ /^\//) {
		$image_install_path = $image_os_source_path;
	}
	else {
		$image_install_path = "$management_node_install_path/$image_os_source_path";
	}

	# Note: $XCAT_ROOT has a leading /
	# Note: $image_install_path has a leading /
	if ($image_os_install_type eq 'kickstart') {
		# Kickstart installs use the xCAT path for both repo and tmpl paths
		my $kickstart_repo_path = "$image_install_path/$image_architecture";
		$self->{image_repository_path}{$management_node_hostname} = $kickstart_repo_path;
		notify($ERRORS{'DEBUG'}, 0, "kickstart install type, returning $kickstart_repo_path");
		return $kickstart_repo_path;
	}
	
	my $repo_path = "$image_install_path/$image_architecture";
	$self->{image_repository_path}{$image_name}{$management_node_hostname} = $repo_path;
	notify($ERRORS{'DEBUG'}, 0, "returning repository path for $management_node_hostname: $repo_path");
	return $repo_path;
} ## end sub get_image_repository_directory_path

#/////////////////////////////////////////////////////////////////////////////

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
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	my $image_data = new VCL::DataStructure({image_identifier => $image_name}) || return;
	my $image_os_install_type = $image_data->get_image_os_install_type() || return;
	my $image_project = $image_data->get_image_project() || return;
	my $image_os_name = $image_data->get_image_os_name() || return;
	
	my $request_state_name = $self->data->get_request_state_name();
	
	# Determine the postscript group name
	# If image project is 'vcl', postscript group = 'compute'
	# Otherwise postscript group is the same as the image project
	# For HPC, use image project = vclhpc. There should be an xCAT postscript group named 'vclhpc' configured with specific HPC postscripts
	
	my $groups;
	if ($request_state_name eq 'image' || $image_os_install_type =~ /image/i) {
		# Image-based install or capture
		$groups = "all,blade,image";
	}
	elsif ($image_project eq "vcl"){
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

#/////////////////////////////////////////////////////////////////////////////

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
	my $image_data = new VCL::DataStructure({image_identifier => $image_name}) || return;
	my $image_architecture = $image_data->get_image_architecture();
	my $image_os_install_type = $image_data->get_image_os_install_type();
	my $image_os_name = $image_data->get_image_os_name();
	
	my $request_state_name = $self->data->get_request_state_name();
	
	if ($request_state_name eq 'image' || $image_os_install_type =~ /image/) {
		$image_os_name = 'image';
	}
	
	my $command = "$XCAT_ROOT/bin/nodech $computer_node_name nodetype.os=$image_os_name nodetype.arch=$image_architecture nodetype.profile=$image_name";
	my ($exit_status, $output) = $self->mn_os->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to edit xCAT configuration of $computer_node_name");
		return;
	}
	elsif (grep(/Error/i, @$output)) {
		# If an error occurs the output will look like this:
		# Error: Invalid nodes and/or groups in noderange: vclh3-00
		notify($ERRORS{'WARNING'}, 0, "failed to edit xCAT configuration of $computer_node_name, output:\n" . join("\n", @$output));
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

#/////////////////////////////////////////////////////////////////////////////

=head2 _rinstall

 Parameters  : $computer_node_name
 Returns     : boolean
 Description : Runs xCAT's rinstall command to initiate the installation of the
               computer.

=cut

sub _rinstall {
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
	
	# Output if blade is already powered on:
	#   vclh3-4: install centos5-x86_64-centos5-base641008-v0
	#   vclh3-4: on reset
	# Output if blade is powered off:
	#   vclh3-4: install centos5-x86_64-centos5-base641008-v0
	#   vclh3-4: off on
	# Output if error occurs:
	#   vclh3-4: install centos5-x86_64-centos5-base641008-v0
	#   vclh3-4: Error: resourceUnavailable (This is likely a out-of-memory failure within the agent)
	#   rpower failure at /opt/xcat/bin/rinstall line 55.
	# Output if entry for blade doens't exist in xCAT mac table
	#   vclh3-4: Error: Unable to find requested mac from mac, with node=vclh3-4
	#   Error: Some nodes failed to set up install resources, aborting
	#   nodeset failure at /opt/xcat/bin/rinstall line 53.
	
	my $command = "$XCAT_ROOT/bin/rinstall $computer_node_name";
	
	my $rinstall_attempt_limit = 5;
	my $rinstall_attempt_delay = 3;
	my $rinstall_attempt = 0;
	
	RINSTALL_ATTEMPT: while ($rinstall_attempt++ < $rinstall_attempt_limit) {
		if ($rinstall_attempt > 1) {
			# Attempt to run rinv to fix any inventory problems with the blade
			notify($ERRORS{'DEBUG'}, 0, "attempt $rinstall_attempt/$rinstall_attempt_limit: failed to initiate rinstall for $computer_node_name, running rinv then sleeping for $rinstall_attempt_delay seconds");
			$self->_rinv($computer_node_name);
			sleep $rinstall_attempt_delay;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "attempt $rinstall_attempt/$rinstall_attempt_limit: issuing rinstall command for $computer_node_name");
		
		my ($exit_status, $output) = $self->mn_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute rinstall command for $computer_node_name");
			return;
		}
		elsif (grep(/(Error:|rpower failure|nodeset failure)/i, $output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to issue rinstall command for $computer_node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
			next RINSTALL_ATTEMPT;
		}
		
		# Find the line containing the node name
		for my $line (@$output) {
			my ($status) = $line =~ /^$computer_node_name:\s+(.+)$/;
			if ($status) {
				notify($ERRORS{'DEBUG'}, 0, "issued rinstall command for $computer_node_name, status line: '$line'");
				return 1;
			}
		}
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to issue rinstall command for $computer_node_name, made $rinstall_attempt_limit attempts");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

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
	elsif (grep(/Error:/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run lsdef for $computer_node_name, output:\n" . join("\n", @$output));
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
	notify($ERRORS{'DEBUG'}, 0, "retrieved xCAT object definition for $computer_node_name:\n" . format_data($node_info));
	return $node_info;
}

#/////////////////////////////////////////////////////////////////////////////

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
			notify($ERRORS{'DEBUG'}, 0, "retrieved nodestat status of $computer_node_name: $status");
			return $status;
		}
	}
	
	# Line containing node name was not found
	notify($ERRORS{'WARNING'}, 0, "failed to retrieve nodestat status of $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
	return;
}

#/////////////////////////////////////////////////////////////////////////////

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
	elsif (grep(/(Error:|nodeset failure)/, $output)) {
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
				notify($ERRORS{'DEBUG'}, 0, "retrieved nodeset status of $computer_node_name: $status");
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
	
	my $command = "$XCAT_ROOT/bin/rpower $computer_node_name $rpower_option";
	
	my $rpower_attempt_limit = 5;
	my $rpower_attempt_delay = 3;
	my $rpower_attempt = 0;
	
	RPOWER_ATTEMPT: while ($rpower_attempt++ < $rpower_attempt_limit) {
		if ($rpower_attempt > 1) {
			# Attempt to run rinv to fix any inventory problems with the blade
			notify($ERRORS{'DEBUG'}, 0, "attempt $rpower_attempt/$rpower_attempt_limit: failed to initiate rpower for $computer_node_name, running rinv then sleeping for $rpower_attempt_delay seconds");
			$self->_rinv($computer_node_name);
			sleep $rpower_attempt_delay;
			notify($ERRORS{'DEBUG'}, 0, "attempt $rpower_attempt/$rpower_attempt_limit: issuing rpower command for $computer_node_name, option: $rpower_option");
		}
		
		my ($exit_status, $output) = $self->mn_os->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute rpower command for $computer_node_name");
			return;
		}
		elsif (grep(/Error:/, $output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to issue rpower command for $computer_node_name\ncommand: $command\noutput:\n" . join("\n", @$output));
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
				notify($ERRORS{'DEBUG'}, 0, "issued rpower command for $computer_node_name, option: $rpower_option, status line: '$line'");
				return $status;
			}
		}
		
		notify($ERRORS{'WARNING'}, 0, "failed to parse rpower output\ncommand: $command\noutput:\n" . join("\n", @$output));
	}
	
	notify($ERRORS{'WARNING'}, 0, "failed to issue rpower command for $computer_node_name, made $rpower_attempt_limit attempts");
	return;
}

#/////////////////////////////////////////////////////////////////////////////

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
	elsif (grep(/Error:/, $output)) {
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

#/////////////////////////////////////////////////////////////////////////////

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
	my $management_node_install_path = $self->data->get_management_node_install_path($management_node_identifier);
	
	# Create a DataStructure object containing info about the image
	my $image_data = new VCL::DataStructure({image_identifier => $image_name}) || return;
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

#/////////////////////////////////////////////////////////////////////////////

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
	my $image_data = new VCL::DataStructure({image_identifier => $image_name}) || return;
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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the xCAT2.pm module and resets node to the boot state.

=cut

sub DESTROY {
	my $self = shift;
	my $type = ref($self);
	if ($type =~ /xCAT/) {
		my $node = $self->data->get_computer_node_name(0);
		my $request_state_name = $self->data->get_request_state_name(0);
		
		if ($request_state_name && $node && $request_state_name =~ /^(new|reload|image)$/) {
			$self->_nodeset($node, 'boot');
		}
		
		# Check for an overridden destructor
		$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	}
} ## end sub DESTROY

#/////////////////////////////////////////////////////////////////////////////

initialize() if (!$XCAT_ROOT);

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
