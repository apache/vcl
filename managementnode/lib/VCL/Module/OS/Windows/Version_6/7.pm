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

VCL::Module::OS::Windows::Version_6::7.pm - VCL module to support Windows 7 operating system

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows 7.

=cut

###############################################################################
package VCL::Module::OS::Windows::Version_6::7;

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
					directory under the 'tools' directory specific to this OS.

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_7";

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  :
 Returns     :
 Description :

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Call parent class's pre_capture() subroutine
	notify($ERRORS{'OK'}, 0, "calling parent class pre_capture() subroutine");
	if ($self->SUPER::pre_capture($args)) {
		notify($ERRORS{'OK'}, 0, "successfully executed parent class pre_capture() subroutine");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "beginning Windows 7 image capture preparation tasks");

=item *

Disable the following scheduled tasks:

 * WinSAT - Measures a system's performance and capabilities
 * RacTask - Microsoft Reliability Analysis task to process system reliability data
 * ProgramDataUpdater - Collects program telemetry information if opted-in to the Microsoft Customer Experience Improvement Program
 * AitAgent - Aggregates and uploads Application Telemetry information if opted-in to the Microsoft Customer Experience Improvement Program
 * KernelCeipTask - The Kernel CEIP (Customer Experience Improvement Program) task collects additional information about the system and sends this data to Microsoft
 * UsbCeip - The USB CEIP (Customer Experience Improvement Program) task collects Universal Serial Bus related statistics and information about your machine and sends it to the Windows Device Connectivity engineering group at Microsoft
 * Proxy - This task collects and uploads autochk SQM data if opted-in to the Microsoft Customer Experience Improvement Program
 * ConfigNotification - This scheduled task notifies the user that Windows Backup has not been configured
 * Microsoft-Windows-DiskDiagnosticDataCollector - The Windows Disk Diagnostic reports general disk and system information to Microsoft for users participating in the Customer Experience Program
 * Scheduled - The Windows Scheduled Maintenance Task performs periodic maintenance of the computer system by fixing problems automatically or reporting them through the Action Center
 * RegIdleBackup - Registry Idle Backup Task
 * AnalyzeSystem - This job analyzes the system looking for conditions that may cause high energy use.
 * LPRemove - Launch language cleanup tool

=cut	

	my @scheduled_tasks = (
		'\Microsoft\Windows\Maintenance\WinSAT',
		'\Microsoft\Windows\RAC\RacTask',
		'\Microsoft\Windows\Application Experience\ProgramDataUpdater',
		'\Microsoft\Windows\Application Experience\AitAgent',
		'\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask',
		'\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
		'\Microsoft\Windows\Autochk\Proxy',
		'\Microsoft\Windows\WindowsBackup\ConfigNotification',
		'\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
		'\Microsoft\Windows\Diagnosis\Scheduled',
		'\Microsoft\Windows\Registry\RegIdleBackup',
		'\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
		'\Microsoft\Windows\MUI\LPRemove',
	);
	for my $scheduled_task (@scheduled_tasks) {
		$self->disable_scheduled_task($scheduled_task);
	}

=item *

Disable the following services:

 * Function Discovery Resource Publication (FDResPub) - Publishes this computer and resources attached to this computer so they can be discovered over the network.  If this service is stopped, network resources will no longer be published and they will not be discovered by other computers on the network.

=cut	

	my @services = (
		'FDResPub',
	);
	for my $service (@services) {
		$self->set_service_startup_mode($service, 'disabled');
	}
	
=item *

Prepare the computer for Sysprep or prepare the non-Sysprep post_load steps

=cut

	if ($self->data->get_imagemeta_sysprep()) {
		if (!$self->run_sysprep()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run Sysprep");
			return;
		}
	}
	else {
		if (!$self->prepare_post_load()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run prepare post_load");
			return;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub pre_capture

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
