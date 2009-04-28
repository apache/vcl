#!/usr/bin/perl -w

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

##############################################################################
# $Id$
##############################################################################

=head1 NAME

VCL::Module::OS::Linux.pm - VCL module to support Linux operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Linux operating systems.

=cut

##############################################################################
package VCL::Module::OS::Linux;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::OS);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_prepare

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_prepare {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $request_id               = $self->data->get_request_id();
	my $reservation_id           = $self->data->get_reservation_id();
	my $image_id                 = $self->data->get_image_id();
	my $image_os_name            = $self->data->get_image_os_name();
	my $management_node_keys     = $self->data->get_management_node_keys();
	my $image_os_type            = $self->data->get_image_os_type();
	my $image_name               = $self->data->get_image_name();
	my $imagemeta_sysprep        = $self->data->get_imagemeta_sysprep();
	my $computer_id              = $self->data->get_computer_id();
	my $computer_short_name      = $self->data->get_computer_short_name();
	my $computer_node_name       = $self->data->get_computer_node_name();
	my $computer_type            = $self->data->get_computer_type();
	my $user_id                  = $self->data->get_user_id();
	my $user_unityid             = $self->data->get_user_login_id();
	my $managementnode_shortname = $self->data->get_management_node_short_name();
	my $computer_private_ip      = $self->data->get_computer_private_ip();

	notify($ERRORS{'OK'}, 0, "beginning Linux-specific image capture preparation tasks: $image_name on $computer_short_name");

	my @sshcmd;

	# Remove user and clean external ssh file
	if ($self->delete_user()) {
		notify($ERRORS{'OK'}, 0, "$user_unityid deleted from $computer_node_name");
	}
	if ($IPCONFIGURATION eq "static") {
		#so we don't have conflicts we should set the public adapter back to dhcp
		# reset ifcfg-eth1 back to dhcp
		# when boot strap it will be set to dhcp
		my @ifcfg;
		my $tmpfile = "/tmp/createifcfg$computer_node_name";
		push(@ifcfg, "DEVICE=eth1\n");
		push(@ifcfg, "BOOTPROTO=dhcp\n");
		push(@ifcfg, "STARTMODE=onboot\n");
		push(@ifcfg, "ONBOOT=yes\n");
		#write to tmpfile
		if (open(TMP, ">$tmpfile")) {
			print TMP @ifcfg;
			close(TMP);
		}
		else {
			#print "could not write $tmpfile $!\n";
			notify($ERRORS{'OK'}, 0, "could not write $tmpfile $!");
		}
		#copy to node
		if (run_scp_command($tmpfile, "$computer_node_name:/etc/sysconfig/network-scripts/ifcfg-$ETHDEVICE", $management_node_keys)) {
		}
		if (unlink($tmpfile)) {
		}
	} ## end if ($IPCONFIGURATION eq "static")

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_prepare

#/////////////////////////////////////////////////////////////////////////////

=head2 capture_start

 Parameters  :
 Returns     :
 Description :

=cut

sub capture_start {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $image_name           = $self->data->get_image_name();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_node_name   = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "initiating Linux image capture: $image_name on $computer_short_name");

	notify($ERRORS{'OK'}, 0, "initating reboot for Linux imaging sequence");
	run_ssh_command($computer_node_name, $management_node_keys, "/sbin/shutdown -r now", "root");
	notify($ERRORS{'OK'}, 0, "sleeping for 90 seconds while machine shuts down and reboots");
	sleep 90;

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_start


#/////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_user {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	# Make sure the user login ID was passed
	my $user_login_id = shift;
	$user_login_id = $self->data->get_user_login_id() if (!$user_login_id);
	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}

	# Make sure the user login ID was passed
	my $computer_node_name = shift;
	$computer_node_name = $self->data->get_computer_node_name() if (!$computer_node_name);
	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}

	# Use userdel to delete the user
	# Do not use userdel -r, it will affect HPC user storage for HPC installs
	my $user_delete_command = "/usr/sbin/userdel $user_login_id";
	my @user_delete_results = run_ssh_command($computer_node_name, $IDENTITY_bladerhel, $user_delete_command, "root");
	foreach my $user_delete_line (@{$user_delete_results[1]}) {
		if ($user_delete_line =~ /currently logged in/) {
			notify($ERRORS{'WARNING'}, 0, "user not deleted, $user_login_id currently logged in");
			return 0;
		}
	}

	# User successfully deleted
	# Remove user from sshd config
	my $external_sshd_config_path      = "$computer_node_name:/etc/ssh/external_sshd_config";
	my $external_sshd_config_temp_path = "/tmp/$computer_node_name.sshd";

	# Retrieve the node's external_sshd_config file
	if (run_scp_command($external_sshd_config_path, $external_sshd_config_temp_path, $IDENTITY_bladerhel)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved $external_sshd_config_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "sshd config not cleaned up, failed to retrieve $external_sshd_config_path");
		return 0;
	}

	# Remove user from sshd config file
	# Get the contents of the sshd config file
	if (open(SSHD_CFG_TEMP, $external_sshd_config_temp_path)) {
		my @external_sshd_config_lines = <SSHD_CFG_TEMP>;
		close SSHD_CFG_TEMP;

		# Loop through the lines, clear out AllowUsers lines
		foreach my $external_sshd_config_line (@external_sshd_config_lines) {
			$external_sshd_config_line = "" if ($external_sshd_config_line =~ /AllowUsers/);
		}

		# Rewrite the temp sshd config file with the modified contents
		if (open(SSHD_CFG_TEMP, ">$external_sshd_config_temp_path")) {
			print SSHD_CFG_TEMP @external_sshd_config_lines;
			close SSHD_CFG_TEMP;
		}

		# Copy the modified file back to the node
		if (run_scp_command($external_sshd_config_temp_path, $external_sshd_config_path, $IDENTITY_bladerhel)) {
			notify($ERRORS{'DEBUG'}, 0, "modified file copied back to node: $external_sshd_config_path");

			# Delete the temp file
			unlink $external_sshd_config_temp_path;

			# Restart external sshd
			if (run_ssh_command($computer_node_name, $IDENTITY_bladerhel, "/etc/init.d/ext_sshd restart")) {
				notify($ERRORS{'DEBUG'}, 0, "restarted ext_sshd on $computer_node_name");
			}

			return 1;
		} ## end if (run_scp_command($external_sshd_config_temp_path...
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy modified file back to node: $external_sshd_config_path");

			# Delete the temp file
			unlink $external_sshd_config_temp_path;

			return 0;
		}
	} ## end if (open(SSHD_CFG_TEMP, $external_sshd_config_temp_path...
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open temporary sshd config file: $external_sshd_config_temp_path");
		return 0;
	}
} ## end sub delete_user

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 BUGS and LIMITATIONS

 There are no known bugs in this module.
 Please report problems to the VCL team (vcl_help@ncsu.edu).

=head1 AUTHOR

 Aaron Peeler, aaron_peeler@ncsu.edu
 Andy Kurth, andy_kurth@ncsu.edu

=head1 SEE ALSO

L<http://vcl.ncsu.edu>


=cut
