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

VCL::Module::OS::Windows::Version_6::8.pm - VCL module to support deployment of Windows 8.x operating systems

=head1 DESCRIPTION

 This module provides support for the deployment of Windows 8.x operating systems.

=cut

###############################################################################
package VCL::Module::OS::Windows::Version_6::8;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows::Version_6);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
               directory under the 'tools' directory specific to this OS. For
               Windows 8, the directory is:
               tools/Windows_8

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_8";

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : Hash containing 'end_state' key (optional)
 Returns     : boolean
 Description : Performs the steps necessary before a Windows 8.x image is
               captured.

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Call parent class's pre_capture subroutine
	notify($ERRORS{'OK'}, 0, "calling parent class pre_capture() subroutine");
	if (!$self->SUPER::pre_capture($args)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return;
	}
	
	my $end_state = $self->{end_state} || 'off';
	
	notify($ERRORS{'OK'}, 0, "beginning Windows 8 image capture preparation tasks, end state: $end_state");
	
	# Get the node configuration directory
	my $node_configuration_directory = $self->get_node_configuration_directory();
	if (!$node_configuration_directory) {
		notify($ERRORS{'WARNING'}, 0, "node configuration directory could not be determined");
		return;
	}
	
	# Set the DevicePath registry key
	# This is used to locate device drivers
	if (!$self->set_device_path_key()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the DevicePath registry key");
		return;
	}
	
	# Make sure the 'VCL Update Cygwin' task doesn't exist or they will conflict
	$self->delete_scheduled_task('VCL Update Cygwin');
	
	# Create a scheduled task to run post_load.cmd when the image boots
	my $task_command  = "$node_configuration_directory/Scripts/post_load.cmd > $node_configuration_directory/Logs/post_load.log";
	my $task_user     = 'root';
	my $task_password = $WINDOWS_ROOT_PASSWORD;
	if (!$self->create_startup_scheduled_task('VCL Post Load', $task_command, $task_user, $task_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create 'VCL Post Load' scheduled task");
		return;
	}
	
	# Set the sshd service startup mode to disabled so that it does not start up until properly configured
	if (!$self->set_service_startup_mode('sshd', 'disabled')) {
		notify($ERRORS{'WARNING'}, 0, "sshd service could not be disabled before shutting down computer");
		return;
	}
	
	# Prepare the computer for Sysprep or prepare the non-Sysprep post_load steps
	if ($self->data->get_imagemeta_sysprep()) {
		if (!$self->run_sysprep()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run Sysprep");
			return;
		}
	}
	else {
		if ($end_state eq 'off') {
			if (!$self->shutdown(1)) {
				notify($ERRORS{'WARNING'}, 0, "failed to shut down computer");
				return;
			}
		}
	}

	notify($ERRORS{'OK'}, 0, "completed Windows 8 image capture preparation tasks");
	return 1;
} ## end sub pre_capture

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
