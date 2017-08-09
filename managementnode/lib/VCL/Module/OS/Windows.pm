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

VCL::Module::OS::Windows - Windows OS support module

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

###############################################################################
package VCL::Module::OS::Windows;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::OS);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use Encode;
use English '-no_match_vars';
use File::Basename;
use MIME::Base64;
use Net::Netmask;
use Text::CSV_XS;

use VCL::utils;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on the management node of the files specific to this OS
               module which are needed to configure the loaded OS on a computer.
               This is normally the directory under 'tools' named after this OS
               module.
               
               Example:
               /usr/local/vcl/tools/Windows

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows";

=head2 $NODE_CONFIGURATION_DIRECTORY

 Data type   : String
 Description : Location on computer on which an image has been loaded where
               configuration files reside. The files residing on the managment
               node in the directory specified by $NODE_CONFIGURATION_DIRECTORY
               are copied to this directory.
               
               Example:
               C:\Cygwin\home\root\VCL

=cut

our $NODE_CONFIGURATION_DIRECTORY = 'C:/Cygwin/home/root/VCL';

=head2 %TIME_ZONE_INFO

 Data type   : Hash
 Description : Windows time zone code information. The hash keys are the
               numerical Windows time zone codes used for things such as
               Sysprep.

=cut

our %TIME_ZONE_INFO = (
	'Afghanistan Standard Time' => {'abbreviation' => 'KAB', 'offset' => '+04:30', 'code' => '175'},
	'Alaskan Standard Time' => {'abbreviation' => 'ALA', 'offset' => '-09:00', 'code' => '3'},
	'Arab Standard Time' => {'abbreviation' => 'BKR', 'offset' => '+03:00', 'code' => '150'},
	'Arabian Standard Time' => {'abbreviation' => 'ABT', 'offset' => '+04:00', 'code' => '165'},
	'Arabic Standard Time' => {'abbreviation' => 'BKR', 'offset' => '+03:00', 'code' => '158'},
	'Atlantic Standard Time' => {'abbreviation' => 'AST', 'offset' => '-04:00', 'code' => '50'},
	'AUS Central Standard Time' => {'abbreviation' => 'ADA', 'offset' => '+09:30', 'code' => '245'},
	'AUS Eastern Standard Time' => {'abbreviation' => 'CMS', 'offset' => '+10:00', 'code' => '255'},
	'Azerbaijan Standard Time' => {'abbreviation' => undef, 'offset' => '+04:00', 'code' => undef},
	'Azores Standard Time' => {'abbreviation' => 'AZO', 'offset' => '-01:00', 'code' => '80'},
	'Canada Central Standard Time' => {'abbreviation' => 'CST', 'offset' => '-06:00', 'code' => '25'},
	'Cape Verde Standard Time' => {'abbreviation' => 'AZO', 'offset' => '-01:00', 'code' => '83'},
	'Caucasus Standard Time' => {'abbreviation' => 'ABT', 'offset' => '+04:00', 'code' => '170'},
	'Cen. Australia Standard Time' => {'abbreviation' => 'ADA', 'offset' => '+09:30', 'code' => '250'},
	'Central America Standard Time' => {'abbreviation' => 'CST', 'offset' => '-06:00', 'code' => '33'},
	'Central Asia Standard Time' => {'abbreviation' => 'ADC', 'offset' => '+06:00', 'code' => '195'},
	'Central Brazilian Standard Time' => {'abbreviation' => undef, 'offset' => '-04:00', 'code' => undef},
	'Central Europe Standard Time' => {'abbreviation' => 'AMS', 'offset' => '+01:00', 'code' => '95'},
	'Central European Standard Time' => {'abbreviation' => 'AMS', 'offset' => '+01:00', 'code' => '100'},
	'Central Pacific Standard Time' => {'abbreviation' => 'MSN', 'offset' => '+11:00', 'code' => '280'},
	'Central Standard Time' => {'abbreviation' => 'CST', 'offset' => '-06:00', 'code' => '20'},
	'Central Standard Time (Mexico)' => {'abbreviation' => 'CST', 'offset' => '-06:00', 'code' => '30'},
	'China Standard Time' => {'abbreviation' => 'SST', 'offset' => '+08:00', 'code' => '210'},
	'Dateline Standard Time' => {'abbreviation' => 'IDLE', 'offset' => '-12:00', 'code' => '0'},
	'E. Africa Standard Time' => {'abbreviation' => 'BKR', 'offset' => '+03:00', 'code' => '155'},
	'E. Australia Standard Time' => {'abbreviation' => 'BGP', 'offset' => '+10:00', 'code' => '260'},
	'E. Europe Standard Time' => {'abbreviation' => 'BCP', 'offset' => '+02:00', 'code' => '115'},
	'E. South America Standard Time' => {'abbreviation' => 'BBA', 'offset' => '-03:00', 'code' => '65'},
	'Eastern Standard Time' => {'abbreviation' => 'EST', 'offset' => '-05:00', 'code' => '35'},
	'Egypt Standard Time' => {'abbreviation' => 'BCP', 'offset' => '+02:00', 'code' => '120'},
	'Ekaterinburg Standard Time' => {'abbreviation' => 'EIK', 'offset' => '+05:00', 'code' => '180'},
	'Fiji Standard Time' => {'abbreviation' => 'FKM', 'offset' => '+12:00', 'code' => '285'},
	'FLE Standard Time' => {'abbreviation' => 'HRI', 'offset' => '+02:00', 'code' => '125'},
	'Georgian Standard Time' => {'abbreviation' => undef, 'offset' => '+04:00', 'code' => undef},
	'GMT Standard Time' => {'abbreviation' => 'GMT', 'offset' => '+00:00', 'code' => '85'},
	'Greenland Standard Time' => {'abbreviation' => 'BBA', 'offset' => '-03:00', 'code' => '73'},
	'Greenwich Standard Time' => {'abbreviation' => 'GMT', 'offset' => '+00:00', 'code' => '90'},
	'GTB Standard Time' => {'abbreviation' => 'AIM', 'offset' => '+02:00', 'code' => '130'},
	'Hawaiian Standard Time' => {'abbreviation' => 'HAW', 'offset' => '-10:00', 'code' => '2'},
	'India Standard Time' => {'abbreviation' => 'BCD', 'offset' => '+05:30', 'code' => '190'},
	'Iran Standard Time' => {'abbreviation' => 'THE', 'offset' => '+03:30', 'code' => '160'},
	'Israel Standard Time' => {'abbreviation' => 'BCP', 'offset' => '+02:00', 'code' => '135'},
	'Korea Standard Time' => {'abbreviation' => 'SYA', 'offset' => '+09:00', 'code' => '230'},
	'Mid-Atlantic Standard Time' => {'abbreviation' => 'MAT', 'offset' => '-02:00', 'code' => '75'},
	'Mountain Standard Time' => {'abbreviation' => 'MST', 'offset' => '-07:00', 'code' => '10'},
	'Mountain Standard Time (Mexico)' => {'abbreviation' => 'MST', 'offset' => '-07:00', 'code' => '13'},
	'Myanmar Standard Time' => {'abbreviation' => 'MMT', 'offset' => '+06:30', 'code' => '203'},
	'N. Central Asia Standard Time' => {'abbreviation' => 'ADC', 'offset' => '+06:00', 'code' => '201'},
	'Namibia Standard Time' => {'abbreviation' => undef, 'offset' => '+02:00', 'code' => undef},
	'Nepal Standard Time' => {'abbreviation' => 'NPT', 'offset' => '+05:45', 'code' => '193'},
	'New Zealand Standard Time' => {'abbreviation' => 'AWE', 'offset' => '+12:00', 'code' => '290'},
	'Newfoundland Standard Time' => {'abbreviation' => 'NWF', 'offset' => '-03:30', 'code' => '60'},
	'North Asia East Standard Time' => {'abbreviation' => 'SST', 'offset' => '+08:00', 'code' => '227'},
	'North Asia Standard Time' => {'abbreviation' => 'BHJ', 'offset' => '+07:00', 'code' => '207'},
	'Pacific SA Standard Time' => {'abbreviation' => 'AST', 'offset' => '-04:00', 'code' => '56'},
	'Pacific Standard Time' => {'abbreviation' => 'PST', 'offset' => '-08:00', 'code' => '4'},
	'Romance Standard Time' => {'abbreviation' => 'AMS', 'offset' => '+01:00', 'code' => '105'},
	'Russian Standard Time' => {'abbreviation' => 'MSV', 'offset' => '+03:00', 'code' => '145'},
	'SA Eastern Standard Time' => {'abbreviation' => 'BBA', 'offset' => '-03:00', 'code' => '70'},
	'SA Pacific Standard Time' => {'abbreviation' => 'EST', 'offset' => '-05:00', 'code' => '45'},
	'SA Western Standard Time' => {'abbreviation' => 'AST', 'offset' => '-04:00', 'code' => '55'},
	'Samoa Standard Time' => {'abbreviation' => 'MIS', 'offset' => '-11:00', 'code' => '1'},
	'SE Asia Standard Time' => {'abbreviation' => 'BHJ', 'offset' => '+07:00', 'code' => '205'},
	'Singapore Standard Time' => {'abbreviation' => 'SST', 'offset' => '+08:00', 'code' => '215'},
	'South Africa Standard Time' => {'abbreviation' => 'BCP', 'offset' => '+02:00', 'code' => '140'},
	'Sri Lanka Standard Time' => {'abbreviation' => 'ADC', 'offset' => '+06:00', 'code' => '200'},
	'Taipei Standard Time' => {'abbreviation' => 'SST', 'offset' => '+08:00', 'code' => '220'},
	'Tasmania Standard Time' => {'abbreviation' => 'HVL', 'offset' => '+10:00', 'code' => '265'},
	'Tokyo Standard Time' => {'abbreviation' => 'OST', 'offset' => '+09:00', 'code' => '235'},
	'Tonga Standard Time' => {'abbreviation' => 'TOT', 'offset' => '+13:00', 'code' => '300'},
	'US Eastern Standard Time' => {'abbreviation' => 'EST', 'offset' => '-05:00', 'code' => '40'},
	'US Mountain Standard Time' => {'abbreviation' => 'MST', 'offset' => '-07:00', 'code' => '15'},
	'Vladivostok Standard Time' => {'abbreviation' => 'HVL', 'offset' => '+10:00', 'code' => '270'},
	'W. Australia Standard Time' => {'abbreviation' => 'SST', 'offset' => '+08:00', 'code' => '225'},
	'W. Central Africa Standard Time' => {'abbreviation' => 'AMS', 'offset' => '+01:00', 'code' => '113'},
	'W. Europe Standard Time' => {'abbreviation' => 'AMS', 'offset' => '+01:00', 'code' => '110'},
	'West Asia Standard Time' => {'abbreviation' => 'EIK', 'offset' => '+05:00', 'code' => '185'},
	'West Pacific Standard Time' => {'abbreviation' => 'BGP', 'offset' => '+10:00', 'code' => '275'},
	'Yakutsk Standard Time' => {'abbreviation' => 'SYA', 'offset' => '+09:00', 'code' => '240'},
);

=head2 $KMS_CLIENT_PRODUCT_KEYS

 Data type   : Hash reference
 Description : Keys used to activate Windows using a KMS server. The key needs
               to be configured before attempting to activate via KMS. Each
               flavor of Windows uses a different KMS client key. These keys are
               public information.

=cut

# These keys are publicly available:
# https://technet.microsoft.com/en-us/library/jj612867(v=ws.11).aspx

our $KMS_CLIENT_PRODUCT_KEYS = {
	'Windows 10 Education'                             => 'NW6C2-QMPVW-D7KKK-3GKT6-VCFB2',
	'Windows 10 Education N'                           => '2WH4N-8QGBV-H22JP-CT43Q-MDWWJ',
	'Windows 10 Enterprise'                            => 'NPPR9-FWDCX-D2C8J-H872K-2YT43',
	'Windows 10 Enterprise 2015 LTSB'                  => 'WNMTR-4C88C-JK8YV-HQ7T2-76DF9',
	'Windows 10 Enterprise 2015 LTSB N'                => '2F77B-TNFGY-69QQF-B8YKP-D69TJ',
	'Windows 10 Enterprise 2016 LTSB'                  => 'DCPHK-NFMTC-H88MJ-PFHPY-QJ4BJ',
	'Windows 10 Enterprise 2016 LTSB N'                => 'QFFDN-GRT3P-VKWWX-X7T3R-8B639',
	'Windows 10 Enterprise N'                          => 'DPH2V-TTNVB-4X9Q3-TJR4H-KHJW4',
	'Windows 10 Professional'                          => 'W269N-WFGWX-YVC9B-4J6C9-T83GX',
	'Windows 10 Professional N'                        => 'MH37W-N47XK-V7XM9-C7227-GCQG9',
	'Windows 7 Enterprise'                             => '33PXH-7Y6KF-2VJC9-XBBR8-HVTHH',
	'Windows 7 Enterprise E'                           => 'C29WB-22CC8-VJ326-GHFJW-H9DH4',
	'Windows 7 Enterprise N'                           => 'YDRBP-3D83W-TY26F-D46B2-XCKRJ',
	'Windows 7 Professional'                           => 'FJ82H-XT6CR-J8D7P-XQJJ2-GPDD4',
	'Windows 7 Professional E'                         => 'W82YF-2Q76Y-63HXB-FGJG9-GF7QX',
	'Windows 7 Professional N'                         => 'MRPKT-YTG23-K7D7T-X2JMM-QY7MG',
	'Windows 8 Enterprise'                             => '32JNW-9KQ84-P47T8-D8GGY-CWCK7',
	'Windows 8 Enterprise N'                           => 'JMNMF-RHW7P-DMY6X-RF3DR-X2BQT',
	'Windows 8 Professional'                           => 'NG4HW-VH26C-733KW-K6F98-J8CK4',
	'Windows 8 Professional N'                         => 'XCVCF-2NXM9-723PB-MHCB7-2RYQQ',
	'Windows 8.1 Enterprise'                           => 'MHF9N-XY6XB-WVXMC-BTDCT-MKKG7',
	'Windows 8.1 Enterprise N'                         => 'TT4HM-HN7YT-62K67-RGRQJ-JFFXW',
	'Windows 8.1 Professional'                         => 'GCRJD-8NW9H-F2CDX-CCM8D-9D6T9',
	'Windows 8.1 Professional N'                       => 'HMCNV-VVBFX-7HMBH-CTY9B-B4FXY',
	'Windows Server 2008 Datacenter'                   => '7M67G-PC374-GR742-YH8V4-TCBY3',
	'Windows Server 2008 Datacenter without Hyper-V'   => '22XQ2-VRXRG-P8D42-K34TD-G3QQC',
	'Windows Server 2008 Enterprise'                   => 'YQGMW-MPWTJ-34KDK-48M3W-X4Q6V',
	'Windows Server 2008 Enterprise without Hyper-V'   => '39BXF-X8Q23-P2WWT-38T2F-G3FPG',
	'Windows Server 2008 for Itanium-Based Systems'    => '4DWFP-JF3DJ-B7DTH-78FJB-PDRHK',
	'Windows Server 2008 HPC'                          => 'RCTX3-KWVHP-BR6TB-RB6DM-6X7HP',
	'Windows Server 2008 R2 Datacenter'                => '74YFP-3QFB3-KQT8W-PMXWJ-7M648',
	'Windows Server 2008 R2 Enterprise'                => '489J6-VHDMP-X63PK-3K798-CPX3Y',
	'Windows Server 2008 R2 for Itanium-based Systems' => 'GT63C-RJFQ3-4GMB6-BRFB9-CB83V',
	'Windows Server 2008 R2 HPC edition'               => 'TT8MH-CG224-D3D7Q-498W2-9QCTX',
	'Windows Server 2008 R2 Standard'                  => 'YC6KT-GKW9T-YTKYR-T4X34-R7VHC',
	'Windows Server 2008 R2 Web'                       => '6TPJF-RBVHG-WBW2R-86QPH-6RTM4',
	'Windows Server 2008 Standard'                     => 'TM24T-X9RMF-VWXK6-X8JC9-BFGM2',
	'Windows Server 2008 Standard without Hyper-V'     => 'W7VD6-7JFBR-RX26B-YKQ3Y-6FFFJ',
	'Windows Server 2012'                              => 'BN3D2-R7TKB-3YPBD-8DRP2-27GG4',
	'Windows Server 2012 Country Specific'             => '4K36P-JN4VD-GDC6V-KDT89-DYFKP',
	'Windows Server 2012 Datacenter'                   => '48HP8-DN98B-MYWDG-T2DCC-8W83P',
	'Windows Server 2012 MultiPoint Premium'           => 'XNH6W-2V9GX-RGJ4K-Y8X6F-QGJ2G',
	'Windows Server 2012 MultiPoint Standard'          => 'HM7DN-YVMH3-46JC3-XYTG7-CYQJJ',
	'Windows Server 2012 N'                            => '8N2M2-HWPGY-7PGT9-HGDD8-GVGGY',
	'Windows Server 2012 R2 Datacenter'                => 'W3GGN-FT8W3-Y4M27-J84CP-Q3VJ9',
	'Windows Server 2012 R2 Essentials'                => 'KNC87-3J2TX-XB4WP-VCPJV-M4FWM',
	'Windows Server 2012 R2 Server Standard'           => 'D2N9P-3P6X9-2R39C-7RTCD-MDVJX',
	'Windows Server 2012 Server Standard'              => 'XC9B7-NBPP2-83J2H-RHMBY-92BT4',
	'Windows Server 2012 Single Language'              => '2WN2H-YGCQR-KFX6K-CD6TF-84YXQ',
	'Windows Server 2016 Datacenter'                   => 'CB7KF-BWN84-R7R2Y-793K2-8XDDG',
	'Windows Server 2016 Essentials'                   => 'JCKRF-N37P4-C2D82-9YXRT-4M63B',
	'Windows Server 2016 Standard'                     => 'WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY',
	'Windows Vista Business'                           => 'YFKBB-PQJJV-G996G-VWGXY-2V3X8',
	'Windows Vista Business N'                         => 'HMBQG-8H2RH-C77VX-27R82-VMQBT',
	'Windows Vista Enterprise'                         => 'VKK3X-68KWM-X2YGT-QR4M6-4BWMV',
	'Windows Vista Enterprise N'                       => 'VTC42-BM838-43QHV-84HX6-XJXKV',
	'Windows Web Server 2008'                          => 'WYR28-R7TFJ-3X2YQ-YCY4H-M249D',
};

###############################################################################

=head1 INTERFACE OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Windows module initialization");
	
	my $request_state = $self->data->get_request_state_name();
	
	# If the request state is reserved, retrieve the firewall configuration now to reduce a delay after the user clicks Connect
	if ($request_state =~ /reserved/) {
		notify($ERRORS{'DEBUG'}, 0, "request state is $request_state, caching firewall configuration to reduce delays later on");
		$self->get_firewall_configuration('TCP');
	}
	
	notify($ERRORS{'DEBUG'}, 0, "Windows module initialization complete");
	
	if ($self->can("SUPER::initialize")) {
		return $self->SUPER::initialize();
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  : Hash containing 'end_state' key
 Returns     : If successful: true
               If failed: false
 Description : Performs the steps necessary to prepare a Windows OS before an
               image is captured.
               This subroutine is called by a provisioning module's capture()
               subroutine.
               
               The steps performed are:

=over 3

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if end_state argument was passed
	if (defined $args->{end_state}) {
		$self->{end_state} = $args->{end_state};
	}
	else {
		$self->{end_state} = 'off';
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $image_os_install_type = $self->data->get_image_os_install_type();
	
	# Call OS::pre_capture to perform the pre-capture tasks common to all OS's
	if (!$self->SUPER::pre_capture($args)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "beginning Windows image capture preparation tasks on $computer_node_name");

=item *

 Disable RDP access from any IP address

=cut

	if (!$self->firewall_disable_rdp()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable RDP from all addresses");
		return 0;
	}

=item *

 Log off all currently logged in users

=cut

	if (!$self->logoff_users()) {
		notify($ERRORS{'WARNING'}, 0, "unable to log off all currently logged in users on $computer_node_name");
		return 0;
	}

=item *

 Apply Windows security templates

=cut

	# This find any .inf security template files configured for the OS and run secedit.exe to apply them
	if (!$self->apply_security_templates()) {
		notify($ERRORS{'WARNING'}, 0, "unable to apply security templates");
		return 0;
	}

=item *

 Set Administrator account password to known value

=cut

	if (!$self->set_password('Administrator', $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set Administrator password");
		return 0;
	}

=item *

 Set root account password to known value

=cut

	if (!$self->set_password('root', $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root password");
		return 0;
	}

=item *

 Delete the user assigned to this reservation

=cut

	my $deleted_user_accounts = $self->delete_user_accounts();
	if (!$deleted_user_accounts) {
		notify($ERRORS{'DEBUG'}, 0, "unable to delete user accounts, will try again after reboot");
	}

=item *

 If computer is part of Active Directory Domain, unjoin it

=cut

	if ($self->ad_get_current_domain()) {
		if (!$self->ad_unjoin()) {
			notify($ERRORS{'WARNING'}, 0, "failed to remove computer from Active Directory domain");
			return 0;
		}
	}

=item *

 Set root as the owner of /home/root

=cut

	if (!$self->set_file_owner('/home/root', 'root')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root as the owner of /home/root");
		return 0;
	}

=item *

 Enable DHCP on the private and public interfaces

=cut

	if (!$self->enable_dhcp('public')) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable DHCP on the public interface");
		return;
	}

=item *

 Copy the capture configuration files to the computer (scripts, utilities, drivers...)

=cut

	if (!$self->copy_capture_configuration_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to copy general Windows capture configuration files to $computer_node_name");
		return 0;
	}

=item *

 Disable autoadminlogon before disabling the pagefile and rebooting

=cut

	if (!$self->disable_autoadminlogon()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable autoadminlogon");
		return 0;
	}

=item *

 Disable Shutdown Event Tracker

=cut

	if (!$self->disable_shutdown_event_tracker()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable shutdown event tracker");
	}

=item *

 Disable System Restore

=cut

	if (!$self->disable_system_restore()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable system restore");
	}

=item *

 Disable hibernation

=cut

	if (!$self->disable_hibernation()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable hibernation");
	}

=item *

 Disable sleep

=cut

	if (!$self->disable_sleep()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable sleep");
	}

=item *

 Disable Windows Customer Experience Improvement program

=cut

	if (!$self->disable_ceip()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable Windows Customer Experience Improvement program");
	}

=item *

 Disable Internet Explorer configuration page

=cut

	if (!$self->disable_ie_configuration_page()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable IE configuration");
	}

=item *

 Disable Automatic Updates

=cut

	if (!$self->disable_automatic_updates()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable automatic updates");
	}

=item *

 Disable Security Center notifications

=cut

	if (!$self->disable_security_center_notifications()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable Security Center notifications");
	}

=item *

 Disable login screensaver if computer is a VM

=cut

	if ($self->data->get_computer_vmhost_id(0)) {
		if (!$self->disable_login_screensaver()) {
			notify($ERRORS{'WARNING'}, 0, "unable to disable login screensaver");
		}
	}

=item *

 Enable audio redirection for RDP sessions

=cut

	if (!$self->enable_rdp_audio()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable RDP audio redirection");
	}
	
=item *

 Enable client-compatible color depth for RDP sessions

=cut

	if (!$self->enable_client_compatible_rdp_color_depth()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable client-compatible color depth for RDP sessions");
	}

=item *

 Clean up the hard drive

=cut

	if (!$self->clean_hard_drive()) {
		notify($ERRORS{'WARNING'}, 0, "unable to clean unnecessary files the hard drive");
	}

=item *

 Disable the pagefile, reboot, and delete pagefile.sys
 
 ********* node reboots *********

=cut

	# This will set the registry key to disable the pagefile, reboot, then delete pagefile.sys
	# Calls the reboot() subroutine, which makes sure ssh service is set to auto and firewall is open for ssh
	if (!$self->disable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable pagefile");
		return 0;
	}

=item *

 Delete the user assigned to this reservation if attempt before reboot failed

=cut

	if (!$deleted_user_accounts && !$self->delete_user_accounts()) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete user accounts after reboot");
		return 0;
	}

=item *

 Enable SSH access from any IP address

=cut

	if (!$self->firewall_enable_ssh()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable SSH from any IP address");
		return 0;
	}

=item *

 Enable ping from any IP address

=cut

	if (!$self->firewall_enable_ping()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable ping from any IP address");
		return 0;
	}

=item *

 Reenable the pagefile

=cut

	if (!$self->enable_pagefile()) {
		notify($ERRORS{'WARNING'}, 0, "unable to reenable pagefile");
		return 0;
	}

=item *

 Delete the 'VCL Update Cygwin' scheduled task if it exists. It could conflict with other post_load scripts.

=cut

	$self->delete_scheduled_task('VCL Update Cygwin');

=item *

 Set the Cygwin SSHD service startup mode to manual

=cut

	if (!$self->set_service_startup_mode('sshd', 'manual')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set sshd service startup mode to manual");
		return 0;
	}
	
=back

=cut

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub pre_capture

#//////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Performs the steps necessary to configure a Windows OS after an
               image has been loaded.
               
               This subroutine is called by a provisioning module's load()
               subroutine.
               
               The steps performed are:

=over 3

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $imagedomain_domaindnsname = $self->data->get_image_domain_dns_name(0);
	
	my $node_configuration_directory = $self->get_node_configuration_directory();
	
	notify($ERRORS{'OK'}, 0, "beginning Windows post-load tasks on $computer_node_name");

=item *

 Wait for computer to respond to SSH

=cut

	if (!$self->wait_for_response(15, 900, 8)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never responded to SSH");
		return 0;
	}

=item *

 Attempt to trigger and fix Cygwin's nodosfilewarning

=cut

	$self->fix_cygwin_nodosfilewarning();

=item *

 Wait for root to log off

=cut

	if (!$self->wait_for_logoff('root', 2)) {
		notify($ERRORS{'WARNING'}, 0, "root account never logged off");
		
		if (!$self->logoff_users()) {
			notify($ERRORS{'WARNING'}, 0, "failed to log off all currently logged in users");
		}
	}

=item *

 Set root as the owner of /home/root

=cut

	if (!$self->set_file_owner('/home/root', 'root')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set root as the owner of /home/root");
	}

=item *

 Set the Cygwin SSHD service startup mode to automatic
 
 The Cygwin SSHD service startup mode should be set to automatic after an image
 has been loaded and is ready to be reserved. Access will be lost if the service
 is not set to automatic and the computer is rebooted.

=cut

	if (!$self->set_service_startup_mode('sshd', 'auto')) {
		notify($ERRORS{'WARNING'}, 0, "unable to set sshd service startup mode to auto");
		return 0;
	}

=item *

 Update the SSH known_hosts file on the management node

=cut

	if (!$self->update_ssh_known_hosts()) {
		notify($ERRORS{'WARNING'}, 0, "unable to update the SSH known_hosts file on the management node");
	}
	
=item *

 Enable RDP access on the private network interface

=cut

	if (!$self->firewall_enable_rdp_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable RDP on private network");
		return 0;
	}
	
=item *

 Enable SSH access on the private network interface

=cut

	if (!$self->firewall_enable_ssh_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable SSH from private IP address");
		return 0;
	}

=item *

 Enable ping on the private network interface

=cut

	if (!$self->firewall_enable_ping_private()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable ping from private IP address");
		return 0;
	}

=item *

 Check the image for user account names known to be bad or easily compromised

=cut

	if (!$self->check_image()) {
		notify($ERRORS{'WARNING'}, 0, "unable to check the image for user accounts known to be bad");
	}

=item *

 Update the public IP address

=cut

	if (!$self->update_public_ip_address()) {
		my $public_ip_configuration = $self->data->get_management_node_public_ip_configuration();
		if ($public_ip_configuration =~ /dhcp/i) {
			notify($ERRORS{'WARNING'}, 0, "computer should have received a public IP address from DHCP but the address could not be determined, attempting to execute 'ipconfig /renew'");
			
			if (!$self->ipconfig_renew()) {
				notify($ERRORS{'WARNING'}, 0, "public IP address from DHCP but the address could not be determined, 'ipconfig /renew' failed");
				return;
			}
			
			# Try to update the public IP address again
			if (!$self->update_public_ip_address()) {
				notify($ERRORS{'WARNING'}, 0, "computer should have received a public IP address from DHCP but the address could not be determined on second attempt after executing 'ipconfig /renew'");
				return;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "computer initially failed to obtain a public IP address from DHCP, executed 'ipconfig /renew', public IP address could then be determined");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "management node failed to set a static public IP address on the computer");
			return;
		}
	}

=item *

 Set persistent public default route

=cut

	if (!$self->set_static_default_gateway()) {
		notify($ERRORS{'WARNING'}, 0, "unable to set persistent public default route");
	}

=item *

 Configure and synchronize time

=cut

	if (!$self->configure_time_synchronization()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure and synchronize time");
	}

=item *

 Set the "My Computer" description to the image pretty name

=cut

	if (!$self->set_my_computer_name()) {
		notify($ERRORS{'WARNING'}, 0, "failed to rename My Computer");
	}

=item *

 Disable the "Select a location for the network" prompt

=cut

	$self->disable_set_network_location_prompt();

=item *

 Check if the RDP port configured on the computer matches the RDP connect method

=cut

	if (!$self->check_rdp_port_configuration()) {
		return 0;
	}

=item *

 Remove the Windows root password and other private information from the VCL configuration files

=cut

	if (!$self->sanitize_files()) {
		notify($ERRORS{'WARNING'}, 0, "failed to sanitize the files on the computer");
		return;
	}

=item *

 Randomize the root account password

=cut

	my $root_random_password = getpw();
	$self->{root_password} = $root_random_password;
	if (!$self->set_password('root', $root_random_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set random root password");
		return 0;
	}

=item *

 Randomize the Administrator account password

=cut

	my $administrator_random_password = getpw();
	if (!$self->set_password('Administrator', $administrator_random_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set random Administrator password");
		return 0;
	}

=item *

 Disable sleep

=cut

	if (!$self->disable_sleep()) {
		notify($ERRORS{'WARNING'}, 0, "unable to disable sleep");
	}

=item *

 Install Windows updates saved under tools on the management node

=cut

	if (!$self->install_updates()) {
		notify($ERRORS{'WARNING'}, 0, "failed to run custom post_load scripts");
	}
	
=item *

 Join Active Directory domain if configured for image

=cut

	if ($imagedomain_domaindnsname) {
		if (!$self->ad_check()) {
			notify($ERRORS{'WARNING'}, 0, "failed to join Active Directory domain");
			return 0;
		}
	}
	elsif ($self->data->get_imagemeta_sethostname(0)) {
		# Image configured to set hostname
		if (!$self->set_computer_hostname()) {
			notify($ERRORS{'WARNING'}, 0, "failed to rename computer");
			return 0;
		}
		push @{$self->{reboot_required}}, 'computer was renamed';
	}

=item *

 Reboot the computer if necessary

=cut
	
	if ($self->{reboot_required}) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to reboot computer, reasons why necessary:\n" . join("\n", @{$self->{reboot_required}}));
		if (!$self->reboot()) {
			notify($ERRORS{'WARNING'}, 0, "failed to reboot after renaming computer");
		}
		delete $self->{reboot_required};
	}

=item *

 Run custom post_load scripts residing in the image

=cut

	my $script_path = '$SYSTEMROOT/vcl_post_load.cmd';
	if (!$self->file_exists($script_path)) {
		notify($ERRORS{'DEBUG'}, 0, "custom post_load script does NOT exist in image: $script_path");
	}
	else {
		$self->run_script($script_path);
	}

=item *

 Delete the VCL Post Load' scheduled task if it exists

=cut

	# Make sure the 'VCL Post Load' task is removed up if it exists to avoid conflicts
	$self->delete_scheduled_task('VCL Post Load');

=item *

 Call OS.pm::post_load

=cut

	return $self->SUPER::post_load();

=back

=cut

}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

 Parameters  : none
 Returns     : boolean
 Description : Runs $SYSTEMROOT/vcl_post_reserve.cmd if it exists in the image.
               Does not check if the actual script succeeded or not.

=cut

sub post_reserve {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Check if custom post_reserve script exists in the image
	my $script_path = '$SYSTEMROOT/vcl_post_reserve.cmd';
	if ($self->file_exists($script_path)) {
		# If post_reserve script exists, assume it does user or reservation-specific actions
		# If the user never connects and the reservation times out, there's no way to revert these actions in order to clean the computer for another user
		# Tag the image as tainted so it is reloaded
		$self->set_tainted_status('post-reserve scripts residing in the image executed');
		
		# Run the post_reserve script
		$self->run_script($script_path);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "custom post_reserve script does NOT exist in image: $script_path");
	}
	
	return $self->SUPER::post_reserve();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 post_reservation

 Parameters  : none
 Returns     : boolean
 Description : Executes $SYSTEMROOT/vcl_post_reservation.cmd if it exists in the
               image. Does not check if the actual script succeeded or not.

=cut

sub post_reservation {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Check if custom post_reservation script exists in image
	my $script_path = '$SYSTEMROOT/vcl_post_reservation.cmd';
	if ($self->file_exists($script_path)) {
		# Run the post_reservation script
		$self->run_script($script_path);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "custom post_reservation script does NOT exist in image: $script_path");
	}
	
	return $self->SUPER::post_reservation();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 pre_reload

 Parameters  : none
 Returns     : true
 Description : Unjoins the computer from an Active Directory domain if
               previously joined. This helps avoid orphaned computer objects.

=cut

sub pre_reload {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	# Check if the computer is joined to any AD domain
	my $computer_current_domain_name = $self->ad_get_current_domain();
	if ($computer_current_domain_name) {
		$self->ad_delete_computer($computer_name, $computer_current_domain_name);
	}
	
	return $self->SUPER::pre_reload();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     :
 Description :

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();

	# Revoke access
	if (!$self->revoke_access()) {
		notify($ERRORS{'WARNING'}, 0, "failed to revoke access to $computer_node_name");
		return 0;
	}

	# Delete the reservation users
	if ($self->delete_user_accounts()) {
		notify($ERRORS{'OK'}, 0, "users deleted from $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete users from $computer_node_name");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;
} ## end sub sanitize

#//////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  :
 Returns     :
 Description :

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path();
	
	if ($self->process_connect_methods("", 1)) {
		notify($ERRORS{'OK'}, 0, "processed connection methods on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to process connection methods on $computer_node_name");
		return;
	}

	notify($ERRORS{'OK'}, 0, "access has been granted for reservation on $computer_node_name");
	return 1;
} ## end sub grant_access

#//////////////////////////////////////////////////////////////////////////////

=head2 revoke_access

 Parameters  :
 Returns     :
 Description :

=cut

sub revoke_access {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();

	# Disallow RDP connections
	if ($self->firewall_disable_rdp()) {
		notify($ERRORS{'OK'}, 0, "firewall was configured to deny RDP access on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "firewall could not be configured to deny RDP access on $computer_node_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "access has been revoked to $computer_node_name");
	return 1;
} ## end sub revoke_access

###############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 create_directory

 Parameters  :
 Returns     :
 Description :

=cut

sub create_directory {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "directory path argument was not specified");
		return;
	}
	
	# If ~ is passed as the directory path, skip directory creation attempt
	# The command will create a /root/~ directory since the path is enclosed in quotes
	return 1 if $path eq '~';

	notify($ERRORS{'DEBUG'}, 0, "attempting to create directory: '$path'");

	# Assemble the Windows shell mkdir command and execute it
	my $mkdir_command = "cmd.exe /c \"mkdir \\\"$path\\\"\"";
	my ($mkdir_exit_status, $mkdir_output) = $self->execute($mkdir_command);
	
	if (!defined($mkdir_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to create directory on $computer_node_name: $path");
		return;
	}
	elsif ($mkdir_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created directory on $computer_node_name: '$path'");
	}
	elsif (grep(/already exists/i, @$mkdir_output)) {
		notify($ERRORS{'OK'}, 0, "directory already exists on $computer_node_name: '$path'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create directory on $computer_node_name: '$path', exit status: $mkdir_exit_status, output:\n" . join("\n", @$mkdir_output));
	}

	# Make sure directory was created
	if (!$self->file_exists($path)) {
		notify($ERRORS{'WARNING'}, 0, "directory does not exist on $computer_node_name: '$path'");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "verified directory exists on $computer_node_name: '$path'");
		return 1;
	}
} ## end sub create_directory

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_file

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_file {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get file path subroutine argument
	my $path_argument = shift;
	if (!$path_argument) {
		notify($ERRORS{'WARNING'}, 0, "file path was not specified as an argument");
		return;
	}
	
	# Check if file exists before attempting to delete it
	if (!$self->file_exists($path_argument)) {
		notify($ERRORS{'OK'}, 0, "file not deleted because it does not exist: '$path_argument'");
		return 1;
	}
	
	my $path_unix = $self->format_path_unix($path_argument);
	my $path_dos = $self->format_path_dos($path_argument);

	notify($ERRORS{'DEBUG'}, 0, "attempting to delete file: '$path_argument'");
	
	# Assemble a set of commands concatenated together
	# Try to take ownership, set the permissions, then delete the file using both Cygwin bash and Windows commands
	# This should allow files to be deleted with restrictive ownership, permissions, and attributes
	
	my $path_unix_directory = parent_directory_path($path_unix);
	my ($path_unix_pattern) = $path_unix =~ /\/?([^\/]+)$/;

	my $command;
	$command .= "echo ---";
	$command .= " ; echo Calling chown.exe to change owner to root...";
	$command .= " ; /usr/bin/chown.exe -Rv root $path_unix 2>&1";
	
	$command .= " ; echo ---";
	$command .= " ; echo Calling chmod.exe to change permissions to 777...";
	$command .= " ; /usr/bin/chmod.exe -Rv 777 $path_unix 2>&1";
	
	$command .= " ; echo ---";
	$command .= " ; echo Calling \\\"rm.exe -rfv $path_unix\\\" to to delete file...";
	$command .= " ; /usr/bin/rm.exe -rfv $path_unix 2>&1";
	
	if ($path_unix_pattern =~ /\*/) {
		$command .= " ; echo ---";
		$command .= " ; echo Calling \\\"rm.exe -rfv $path_unix_directory/.$path_unix_pattern\\\" to to delete file...";
		$command .= " ; /usr/bin/rm.exe -rfv $path_unix_directory/.$path_unix_pattern 2>&1";
	}
	
	# Add call to rmdir if the path does not contain a wildcard
	# rmdir does not accept wildcards
	if ($path_dos !~ /\*/) {
		$command .= " ; echo ---";
		$command .= " ; echo Calling \\\"cmd.exe /c rmdir $path_dos\\\" to to delete directory...";
		$command .= " ; cmd.exe /c \"rmdir /s /q \\\"$path_dos\\\"\" 2>&1";
	}
	
	$command .= " ; echo ---";
	$command .= " ; echo Calling \\\"cmd.exe /c del $path_dos\\\" to to delete file...";
	$command .= " ; cmd.exe /c \"del /s /q /f /a \\\"$path_dos\\\" 2>&1\" 2>&1";
	
	$command .= " ; echo ---";
	$command .= " ; echo Calling \\\"cmd.exe /c dir $path_dos\\\" to to list remaining files...";
	$command .= " ; cmd.exe /c \"dir /a /w \\\"$path_dos\\\"\" 2>&1";
	
	$command .= " ; echo ---";
	$command .= " ; date +%r";
	
	
	# Run the command
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete file: '$path_argument'");
		return;
	}
	
	## Sleep 1 second before checking if file was deleted
	#sleep 1;
	
	# Check if file was deleted
	if ($self->file_exists($path_argument)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete file, it still exists: '$path_argument', command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "deleted file: '$path_argument'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 move_file

 Parameters  :
 Returns     :
 Description :

=cut

sub move_file {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get file path subroutine arguments
	my $source_path = shift;
	my $destination_path = shift;
	if (!$source_path) {
		notify($ERRORS{'WARNING'}, 0, "file source path was not specified as an argument");
		return;
	}
	if (!$destination_path) {
		notify($ERRORS{'WARNING'}, 0, "file destination path was not specified as an argument");
		return;
	}
	
	# Replace backslashes with forward slashes
	$source_path =~ s/\\+/\//gs;
	$destination_path =~ s/\\+/\//gs;

	notify($ERRORS{'DEBUG'}, 0, "attempting to move file: $source_path --> $destination_path");

	# Assemble the Windows shell move command and execute it
	my $move_command = "mv -fv \"$source_path\" \"$destination_path\"";
	my ($move_exit_status, $move_output) = $self->execute($move_command, 1);
	if (defined($move_exit_status) && $move_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "file moved: $source_path --> $destination_path, output:\n@{$move_output}");
	}
	elsif ($move_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to move file: $source_path --> $destination_path, exit status: $move_exit_status, output:\n@{$move_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to move file: $source_path --> $destination_path");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_files_by_pattern

 Parameters  : $base_directory, $regex_pattern, $max_depth (optional)
 Returns     : boolean
 Description : Deletes all files found under the base directory

=cut

sub delete_files_by_pattern {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my ($base_directory, $regex_pattern, $max_depth, $show_deleted) = @_;

	# Make sure base directory and pattern were specified
	if (!($base_directory && $regex_pattern)) {
		notify($ERRORS{'WARNING'}, 0, "base directory and pattern must be specified as arguments");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to delete files on $computer_name, base directory: '$base_directory', pattern: '$regex_pattern', max depth: " . ($max_depth ? $max_depth : 'unlimited'));
	
	# Check if the path begins with an environment variable
	my ($base_directory_variable, $remainder) = $base_directory =~ /(\$[^\/\\]*)(.*)/g;
	if ($base_directory_variable) {
		my $cygpath_command = "/bin/cygpath.exe \"$base_directory_variable\"";
		my ($cygpath_exit_status, $cygpath_output) = $self->execute($cygpath_command, 0);
		if (!defined($cygpath_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if $base_directory_variable environment variable is set on $computer_name: $cygpath_command");
			return;
		}
		elsif (grep(/cygpath:/, @$cygpath_output)) {
			notify($ERRORS{'DEBUG'}, 0, "files not deleted because $base_directory_variable environment variable is not set on $computer_name");
			return;
		}
		elsif (!grep(/\w/, @$cygpath_output)) {
			notify($ERRORS{'DEBUG'}, 0, "files not deleted because $base_directory_variable environment variable is empty on $computer_name");
			return;
		}
		
		my ($base_directory_variable_value) = grep(/\w/, @$cygpath_output);
		$remainder = '' unless defined($remainder);
		
		my $base_directory_new = "$base_directory_variable_value/$remainder";
		$base_directory_new =~ s/[\\\/]+/\//g;
		
		notify($ERRORS{'DEBUG'}, 0, "$base_directory_variable environment variable is set on $computer_name: '$base_directory' --> '$base_directory_new'");
		$base_directory = $base_directory_new;
	}
	
	# Remove trailing slashes from base directory
	$base_directory =~ s/[\/\\]*$/\//;
	
	# Assemble command
	# Use find to locate all the files under the base directory matching the pattern specified
	my $command = "/bin/find.exe \"$base_directory\"";
	$command .= " -mindepth 1";
	$command .= " -maxdepth $max_depth" if $max_depth;
	$command .= " -iregex \"$regex_pattern\"";
	$command .= " -exec chown -R root {} \\;";
	$command .= " -exec chmod -R 777 {} \\;";
	$command .= " -exec rm -rvf {} \\;";

	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete files under $base_directory matching pattern $regex_pattern, command: $command");
		return;
	}
	elsif ($base_directory_variable && grep(/cygpath:/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "files not deleted because environment variable is not set: $base_directory_variable");
		return;
	}
	elsif (grep(/find:.*no such file/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "files not deleted because base directory does not exist: $base_directory, command: '$command'");
		return 1;
	}
	elsif (grep(/(^Usage:)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete files under $base_directory matching pattern $regex_pattern\ncommand: $command\noutput:\n" . join("\n", @$output));
		return;
	}
	else {
		my @deleted = grep(/removed /, @$output);
		my @not_deleted = grep(/cannot remove/, @$output);
		
		my $message;
		$message .= "attempted to delete files:\n";
		$message .= "base directory: $base_directory\n";
		$message .= "regular expression pattern: $regex_pattern\n";
		$message .= "files and directories deleted: " . scalar(@deleted) . "\n";
		$message .= "files and directories NOT deleted: " . scalar(@not_deleted) . "\n";
		$message .= "deleted:\n" . join("\n", @deleted) . "\n" if ($show_deleted && @deleted);
		$message .= "NOT deleted:\n" . join("\n", @not_deleted) if (@not_deleted);
		notify($ERRORS{'OK'}, 0, $message) if (@deleted || @not_deleted);
	}
	
	return 1;
} ## end sub delete_files_by_pattern

#//////////////////////////////////////////////////////////////////////////////

=head2 file_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub file_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get the path from the subroutine arguments and make sure it was passed
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "unable to detmine if file exists, path was not specified as an argument");
		return;
	}
	
	my $path_dos = $self->format_path_dos($path);
	
	# Assemble the dir command and execute it
	my $dir_command = "cmd.exe /c \"dir /a \\\"$path_dos\\\"\"";
	my ($dir_exit_status, $dir_output) = $self->execute($dir_command, 0);
	if (!defined($dir_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to determine if file exists on $computer_node_name: $path");
		return;
	}
	
	# Checking if directory exists, no wildcard: (directory exists)
	# $ cmd.exe /c "dir /a C:\test"
	# Volume in drive C has no label.
	# Volume Serial Number is 4C9E-6C37
	#
	# Directory of C:\test
	#
	#05/16/2012  01:19 PM    <DIR>          .
	#05/16/2012  01:19 PM    <DIR>          ..
	#               0 File(s)              0 bytes
	#               2 Dir(s)  17,999,642,624 bytes free
	
	# Checking if file or directory exists with wildcard: (file exists)
	# $ cmd.exe /c "dir /a C:\te*"
	# Volume in drive C has no label.
	# Volume Serial Number is 4C9E-6C37
	#
	# Directory of C:\
	#
	#05/16/2012  01:19 PM    <DIR>          test
	#               0 File(s)              0 bytes
	#               1 Dir(s)  17,999,642,624 bytes free
	
	# Checking if file exists with wildcard: (file does not exist)
	# $ cmd.exe /c "dir /a C:\test\*"
	# Volume in drive C has no label.
	# Volume Serial Number is 4C9E-6C37
	#
	# Directory of C:\test
	#
	#05/16/2012  01:19 PM    <DIR>          .
	#05/16/2012  01:19 PM    <DIR>          ..
	#               0 File(s)              0 bytes
	#               2 Dir(s)  17,999,642,624 bytes free

	if ($dir_exit_status == 1 || grep(/(file not found|cannot find)/i, @$dir_output)) {
		notify($ERRORS{'DEBUG'}, 0, "file does NOT exist on $computer_node_name: '$path'");
		return 0;
	}
	elsif ($path =~ /\*/ && grep(/\s0 File/, @$dir_output) && grep(/\s2 Dir/, @$dir_output)) {
		#notify($ERRORS{'DEBUG'}, 0, "file does NOT exist on $computer_node_name: '$path', exit status: $dir_exit_status, command: '$dir_command', output:\n" . join("\n", @$dir_output));
		notify($ERRORS{'DEBUG'}, 0, "file does NOT exist on $computer_node_name: '$path'");
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "file exists on $computer_node_name: '$path'");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_file_owner

 Parameters  : file path, owner
 Returns     : If successful: true
               If failed: false
 Description : Recursively sets the owner of the file path.  The file path can
               be a file or directory. The owner must be a valid user account. A
               group can optionally be specified by appending a semicolon and
               the group name to the owner.
               Examples:
               set_file_owner('/home/root', 'root')
               set_file_owner('/home/root', 'root:Administrators')

=cut

sub set_file_owner {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	# Get the owner argument
	my $owner = shift;
	if (!$owner) {
		notify($ERRORS{'WARNING'}, 0, "owner argument was not specified");
		return;
	}

	# Run chown
	my ($chown_exit_status, $chown_output) = $self->execute("/usr/bin/chown.exe -vR \"$owner\" \"$file_path\"", 0);
	
	# Check if exit status is defined - if not, SSH command failed
	if (!defined($chown_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to set $owner as the owner of $file_path");
		return;
	}
	
	# Check if any known error lines exist in the chown output
	my @chown_error_lines = grep(/(chown:|cannot access|no such file|failed to)/ig, @$chown_output);
	if (@chown_error_lines) {
		notify($ERRORS{'WARNING'}, 0, "error occurred setting $owner as the owner of $file_path, error output:\n" . join("\n", @chown_error_lines));
		return;
	}
	
	# Make sure an "ownership of" line exists in the chown output
	my @chown_success_lines = grep(/(ownership of)/ig, @$chown_output);
	if (@chown_success_lines) {
		notify($ERRORS{'OK'}, 0, "set $owner as the owner of $file_path, files and directories modified: " . scalar(@chown_success_lines));
	}
	else {
		notify($ERRORS{'OK'}, 0, "$owner is already the owner of $file_path");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 logoff_users

 Parameters  :
 Returns     :
 Description :

=cut

sub logoff_users {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;

	my ($exit_status, $output) = $self->execute("$system32_path/qwinsta.exe", 1, 60);
	if ($exit_status > 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	elsif (!defined($exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe command on $computer_node_name");
		return;
	}
	
	# Find lines with the state = Active or Disc
	# Disc will occur if the user disconnected the RDP session but didn't logoff
	my @connection_lines = grep(/(Active)/, @$output);
	return 1 if !@connection_lines;
	
	#notify($ERRORS{'OK'}, 0, "connections on $computer_node_name:\n@connection_lines");
	#  SESSIONNAME        USERNAME                 ID  STATE   TYPE        DEVICE
	# '>                  root                      0  Disc    rdpwd               '
	# '>rdp-tcp#24        root                      0  Active  rdpwd               '
	foreach my $connection_line (@connection_lines) {
		$connection_line =~ s/(^\s+|\s+$)//g;
		my ($session_id) = $connection_line =~ /(\d+)\s+(?:Active|Listen|Conn|Disc)/g;
		my ($session_name) = $connection_line =~ /^\s?>?([^ ]+)/g;
		
		# Determine if the session ID or name will be used to kill the session
		# logoff.exe has trouble killing sessions with ID=0
		# Use the ID if it's > 0, otherwise use the session name
		my $session_identifier;
		if ($session_id) {
			$session_identifier = $session_id;
		}
		elsif ($session_name) {
			$session_identifier = $session_name;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "session ID or name could not be determined from line:\n$connection_line");
			next;
		}
		notify($ERRORS{'DEBUG'}, 0, "attempting to kill connection $session_identifier: '$connection_line'");
		
		#LOGOFF [sessionname | sessionid] [/SERVER:servername] [/V]
		#  sessionname         The name of the session.
		#  sessionid           The ID of the session.
		#  /SERVER:servername  Specifies the Terminal server containing the user
		#							 session to log off (default is current).
		#  /V                  Displays information about the actions performed.
		# Call logoff.exe, pass it the session
		my ($logoff_exit_status, $logoff_output) = $self->execute("$system32_path/logoff.exe $session_identifier /V");
		if (!defined($logoff_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to log off session: $session_identifier");
		}
		elsif ($logoff_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "logged off session: $session_identifier, output:\n" . join("\n", @$logoff_output));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to log off session: $session_identifier, exit status: $logoff_exit_status, output:\n" . join("\n", @$logoff_output));
		}
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  : $username (optional)
 Returns     : boolean
 Description : Executes 'net user <username>' to determine whether or not a
               local user exists on the Windows computer.

=cut

sub user_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}

	#notify($ERRORS{'DEBUG'}, 0, "checking if user $username exists on $computer_node_name");

	# Attempt to query the user account
	my $command = "$system32_path/net.exe user \"$username\"";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if user exists on $computer_node_name: $username");
		return;
	}

	# Expected output if user exists:
	# $ net user administrator
	# User name                    Administrator
	# Full Name
	# Comment                      Built-in account for administering the computer/domain
	# ...
	# The command completed successfully.

	# Expected output if user does NOT exist:
	# $ net user foo
	# The user name could not be found.
	#
	# More help is available by typing NET HELPMSG 2221.
	
	# Note: exit status may not be reliable, see VCL-1054
	if ($exit_status == 2 || grep(/not.*found/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "user '$username' does NOT exist on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return 0;
	}
	elsif (my ($username_line) = grep(/User name[\s\t]+$username[\s\t]*$/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "user '$username' exists on $computer_node_name, found matching line in '$command' output:\n$username_line");
		return 1;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'WARNING'}, 0, "returning 1 but unable to reliable determine if user '$username' exists on $computer_node_name, exit status is $exit_status but output does not contain a 'User name <space...> $username' line:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if user '$username' exists on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_user

 Parameters  : hash reference
 Returns     : boolean
 Description : Creates a user on the computer. The argument must be a hash
               reference containing the following keys:
               * username
               * password
               * root_access

=cut

sub create_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	
	my $user_parameters = shift;
	if (!$user_parameters) {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, user parameters argument was not provided");
		return;
	}
	elsif (!ref($user_parameters) || ref($user_parameters) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "unable to create user, argument provided is not a hash reference");
		return;
	}
	
	my $username = $user_parameters->{username};
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'username' key:\n" . format_data($user_parameters));
		return;
	}
	
	my $root_access = $user_parameters->{root_access};
	if (!defined($root_access)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'root_access' key:\n" . format_data($user_parameters));
		return;
	}
	
	my $password = $user_parameters->{password};
	
	# Check if image is configured for Active Directory and a password should NOT be set
	# OS.pm::add_user_accounts should have already called should_set_user_password which checks if AD is configured and if user exists in AD
	# If user exists in AD, password argument should not be set
	# If for some reason it is set, add local user account
	if ($domain_dns_name && !$password) {
		$username .= "@" . $domain_dns_name;
	}
	else {
		if (!defined($password) && !$domain_dns_name) {
			notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name, argument hash does not contain a 'password' key:\n" . format_data($user_parameters));
			return;
		}
		
		# Not an AD image, check if user already exists
		if (!$self->user_exists($username)) {
			# Attempt to create the user account
			my $add_user_command = "$system32_path/net.exe user \"$username\" \"$password\" /ADD /EXPIRES:NEVER /COMMENT:\"Account created by VCL\"";
			my ($add_user_exit_status, $add_user_output) = $self->execute($add_user_command, 0);
			if (!defined($add_user_output)) {
				notify($ERRORS{'WARNING'}, 0, "failed to execute command create user on $computer_node_name: $username");
				return;
			}
			elsif ($add_user_exit_status == 0) {
				notify($ERRORS{'OK'}, 0, "created user on $computer_node_name: $username, password: $password");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to create user on $computer_node_name: $username, exit status: $add_user_exit_status, command: '$add_user_command', output:\n" . join("\n", @$add_user_output));
				return 0;
			}
		}
		else {
			# Account already exists on machine, set password
			if (!$self->set_password($username, $password)) {
				notify($ERRORS{'WARNING'}, 0, "failed to set password of existing user on $computer_node_name: $username");
				return;
			}
		}
	}
	
	if (!$self->add_user_to_group($username, "Remote Desktop Users")) {
		return;
	}
	
	# Add user to Administrators group if necessary
	if ($root_access) {
		if (!$self->add_user_to_group($username, "Administrators")) {
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "existing user NOT added to Administrators group on $computer_node_name: $username");
	}

	return 1;
} ## end sub create_user

#//////////////////////////////////////////////////////////////////////////////

=head2 add_user_to_group

 Parameters  : $username, $group
 Returns     : boolean
 Description : Adds a user to a group on the computer.

=cut

sub add_user_to_group {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	my $group = shift;
	if (!$username || !$group) {
		notify($ERRORS{'WARNING'}, 0, "unable to add user to group, arguments were not passed correctly");
		return;
	}

	# Attempt to add the user to the group using net.exe localgroup
	my $localgroup_user_command = "$system32_path/net.exe localgroup \"$group\" $username /ADD";
	my ($localgroup_user_exit_status, $localgroup_user_output) = $self->execute($localgroup_user_command);
	if (defined($localgroup_user_exit_status) && $localgroup_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "added user to '$group' group on $computer_node_name: $username");
	}
	elsif (defined($localgroup_user_exit_status) && $localgroup_user_exit_status == 2) {
		# Exit status is 2, this could mean the user is already a member or that the group doesn't exist
		# Check the output to determine what happened
		if (grep(/error 1378/, @{$localgroup_user_output})) {
			# System error 1378 has occurred.
			# The specified account name is already a member of the group.
			notify($ERRORS{'OK'}, 0, "user is already a member of '$group' group on $computer_node_name: $username");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to add user to '$group' group on $computer_node_name: $username, exit status: $localgroup_user_exit_status, output:\n@{$localgroup_user_output}");
			return 0;
		}
	} ## end elsif (defined($localgroup_user_exit_status) ... [ if (defined($localgroup_user_exit_status) ...
	elsif (defined($localgroup_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add user to '$group' group on $computer_node_name: $username, exit status: $localgroup_user_exit_status, output:\n@{$localgroup_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add user to '$group' group on $computer_node_name: $username");
		return;
	}

	return 1;
} ## end sub add_user_to_group

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_user_from_group

 Parameters  : $username, $group
 Returns     : boolean
 Description : Removes a user from a local group on the computer. If an AD user
               account and local account exist with the same name, both will be
               removed.

=cut

sub remove_user_from_group {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;

	my $username = shift;
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not supplied");
		return;
	}
	
	my $group = shift;
	if (!defined($group)) {
		notify($ERRORS{'WARNING'}, 0, "local group name argument was not supplied");
		return;
	}
	
	my @group_members = $self->get_group_members($group);
	if (!@group_members) {
		notify($ERRORS{'DEBUG'}, 0, "$username not removed from $group local group on $computer_name, group is either empty or membership could not be retrieved");
		return 1;
	}
	
	my @matching_members = grep(/(^|\\)$username$/i, @group_members);
	if (!@matching_members) {
		notify($ERRORS{'OK'}, 0, "$username is not a member of $group local group on $computer_name");
		return 1;
	}
	for my $matching_member (@matching_members) {
		# Escape backslashes in domain usernames
		$matching_member =~ s/\\/\\\\/;
		my $command = "$system32_path/net.exe localgroup \"$group\" \"$matching_member\" /DELETE";
		my ($exit_status, $output) = $self->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to remove $matching_member from $group local group on $computer_name: $command");
			return;
		}
		elsif (grep(/no such/, @$output)) {
			# There is no such global user or group: admin.
			notify($ERRORS{'OK'}, 0, "$matching_member is not a member of $group local group on $computer_name");
			return 1;
		}
		elsif ($exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to remove $matching_member from $group local group on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "removed $matching_member from $group local group on $computer_name");		
		}
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_group_members

 Parameters  : $group_name
 Returns     : array
 Description : Retrieves the names of users who are members of a local Windows
               group.

=cut

sub get_group_members {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $group = shift;
	if (!defined($group)) {
		notify($ERRORS{'WARNING'}, 0, "local group name argument was not supplied");
		return;
	}
	
	my $command = "$system32_path/net.exe localgroup \"$group\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve members of $group local group on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve members of $group local group on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return 0;
	}
	
	# Alias name     Remote Desktop Users
	# Comment        Members in this group are granted the right to logon remotely
	#
	# Members
	#
	# -------------------------------------------------------------------------------
	# AD\admin
	# admin
	# AD\domainuser
	# admin
	# tester1
	# ...
	# test100
	# The command completed successfully.
	my @group_members;
	my $separator_line_found = 0;
	for my $line (@$output) {
		if (!$separator_line_found) {
			if ($line =~ /---/) {
				$separator_line_found = 1;
			}
			next;
		}
		elsif ($line =~ /The command/) {
			last;
		}
		push @group_members, $line;
	}
	notify($ERRORS{'OK'}, 0, "retrieve members of $group local group on $computer_name: " . join(", ", @group_members));
	return @group_members;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_user

 Parameters  : $node, $user, $type, $osname
 Returns     : 1 success 0 failure
 Description : removes user account and profile directory from specificed node

=cut

sub delete_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;

	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	if (!(defined($username))) {
		$username = $self->data->get_user_login_id();
	}

	notify($ERRORS{'OK'}, 0, "attempting to delete user $username from $computer_node_name");

	# Attempt to delete the user account
	my $delete_user_command = "$system32_path/net.exe user $username /DELETE";
	my ($delete_user_exit_status, $delete_user_output) = $self->execute($delete_user_command);
	if (defined($delete_user_exit_status) && $delete_user_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted user $username from $computer_node_name");
	}
	elsif (defined($delete_user_exit_status) && $delete_user_exit_status == 2) {
		notify($ERRORS{'OK'}, 0, "user $username was not deleted because user does not exist");
		
		# Could be an AD domain user, make sure user is removed from groups
		$self->remove_user_from_group($username, 'Administrators');
		$self->remove_user_from_group($username, 'Remote Desktop Users');
	}
	elsif (defined($delete_user_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete user $username from $computer_node_name, exit status: $delete_user_exit_status, output:\n@{$delete_user_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command delete user $username from $computer_node_name");
		return;
	}

	# Delete the user's home directory
	if ($self->delete_file("C:/Documents and Settings/$username")) {
		notify($ERRORS{'OK'}, 0, "deleted profile for user $username from $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete profile for user $username from $computer_node_name");
		return 0;
	}

	return 1;
} ## end sub delete_user

#//////////////////////////////////////////////////////////////////////////////

=head2 set_password

 Parameters  : $username, $password
 Returns     : 
 Description : 

=cut

sub set_password {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# IMPORTANT: be sure to test passwords containing the following:
	# $!
	# \ (single backslash)
	# '
	# "
	# ~
	# `
	# Special bash/Linux variables: = $0, $1, $#, $*, $@, $-, $!, $_, $?, $$
	# my $test_password = '$0, $1 $# $* $@ $- $! $_ $? $$\ !@#$%^&*()_+-={}[]":;<>?/.,`~' . "'";
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Attempt to get the username from the arguments
	my $username = shift;
	my $password = shift;
	my $user_password_only = shift;

	# If no argument was supplied, use the user specified in the DataStructure
	if (!defined($username)) {
		$username = $self->data->get_user_logon_id();
	}
	if (!defined($password)) {
		$password = $self->data->get_reservation_password();
	}

	# Make sure both the username and password were determined
	if (!defined($username) || !defined($password)) {
		notify($ERRORS{'WARNING'}, 0, "username and password could not be determined");
		return 0;
	}

	# Attempt to set the password
	my $password_escaped = _escape_password($password);
	my $set_password_command = "$system32_path/net.exe user $username \"$password_escaped\"";
	notify($ERRORS{'DEBUG'}, 0, "setting password of $username to '$password' on $computer_node_name, command:\n$set_password_command");
	my ($set_password_exit_status, $set_password_output) = $self->execute($set_password_command);
	if ($set_password_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "password changed to '$password' for user '$username' on $computer_node_name, command: '$set_password_command', output:\n" . join("\n", @$set_password_output));
	}
	elsif (defined $set_password_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to change password to '$password' (escaped: '$password_escaped') for user '$username' on $computer_node_name, exit status: $set_password_exit_status, command: '$set_password_command', output:\n" . join("\n", @$set_password_output));
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to change password to '$password' for user '$username' on $computer_node_name");
		return 0;
	}
	return 1 if $user_password_only;
	
	# Get the list of services
	my @services = $self->get_services_using_login_id($username);
	if ($username eq 'root' && !@services) {
		@services = ('sshd');
	}
	
	for my $service (@services) {
		notify($ERRORS{'DEBUG'}, 0, "$service service is configured to run as $username, updating service credentials");
		if (!$self->set_service_credentials($service, $username, $password)) {
			notify($ERRORS{'WARNING'}, 0, "failed to set $service service credentials to $username ($password)");
		}
	}
	
	# Get the scheduled tasks - check if any are configured to run as the user
	my $scheduled_task_info = $self->get_scheduled_task_info();
	for my $task_name (keys %$scheduled_task_info) {
		my $run_as_user = $scheduled_task_info->{$task_name}{'Run As User'};
		if ($run_as_user && $run_as_user =~ /^(.+\\)?$username$/i) {
			notify($ERRORS{'DEBUG'}, 0, "password needs to be updated for scheduled task '$task_name' set to run as user '$run_as_user'");
			
			# Attempt to update the scheduled task credentials
			# Don't return false if this fails - not extremely vital
			if (!$self->set_scheduled_task_credentials($task_name, $username, $password)) {
				notify($ERRORS{'WARNING'}, 0, "failed to set '$task_name' scheduled task credentials to $username ($password)");
			}
		}
	}
	
	notify($ERRORS{'OK'}, 0, "changed password for user: $username");
	return 1;
} ## end sub set_password

#//////////////////////////////////////////////////////////////////////////////

=head2 should_set_user_password

 Parameters  : $user_id
 Returns     : boolean
 Description : Determines if a random password should be set for a user. This is
               the default behavior. A random password will not be set if:
					* The image is configured for Active Directory
					* The user exists in the domain

=cut

sub should_set_user_password {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_id) = shift;
	if (!$user_id) {
		notify($ERRORS{'WARNING'}, 0, "user ID argument was not supplied");
		return;
	}
	
	if (defined($self->{should_set_user_password}{$user_id})) {
		return $self->{should_set_user_password}{$user_id};
	}
	
	# Check if image is configured for Active Directory
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	if ($domain_dns_name) {
		my $user_info = get_user_info($user_id);
		if (!$user_info) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine if user password should be set, user info could not be retrieved for user ID $user_id");
			return;
		}
		
		my $username = $user_info->{unityid};
		if ($self->ad_user_exists($username)) {
			$self->{should_set_user_password}{$user_id} = 0;
			notify($ERRORS{'DEBUG'}, 0, "verified user exists in $domain_dns_name Active Directory domain: $username (ID: $user_id), random password will NOT be set for user");
		}
		else {
			$self->{should_set_user_password}{$user_id} = 1;
			notify($ERRORS{'WARNING'}, 0, "could not verify user exists in $domain_dns_name Active Directory domain: $username (ID: $user_id), random password will be set");
		}
	}
	else {
		# Not configured for Active Directory, random password should be set
		$self->{should_set_user_password}{$user_id} = 1;
	}
	
	return $self->{should_set_user_password}{$user_id};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_user

 Parameters  : $username (optional
 Returns     : 
 Description : 

=cut

sub enable_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;

	# Attempt to get the username from the arguments
	my $username = shift;

	# If no argument was supplied, use the user specified in the DataStructure
	if (!defined($username)) {
		$username = $self->data->get_user_logon_id();
	}

	# Make sure the username was determined
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username could not be determined");
		return 0;
	}

	# Attempt to enable the user account (set ACTIVE=YES)
	notify($ERRORS{'DEBUG'}, 0, "enabling user $username on $computer_node_name");
	my ($enable_exit_status, $enable_output) = $self->execute("$system32_path/net.exe user $username /ACTIVE:YES");
	if ($enable_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "user $username enabled on $computer_node_name");
	}
	elsif ($enable_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable user $username on $computer_node_name, exit status: $enable_exit_status, output:\n@{$enable_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to enable user $username on $computer_node_name");
		return 0;
	}

	return 1;
} ## end sub enable_user

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_user

 Parameters  : $username
 Returns     : boolean
 Description : Disables the user account specified by the argument.

=cut

sub disable_user {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	my $username = shift;
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not supplied");
		return;
	}

	# Attempt to enable the user account (set ACTIVE=NO)
	notify($ERRORS{'DEBUG'}, 0, "disbling user $username on $computer_node_name");
	my ($exit_status, $output) = $self->execute("net user $username /ACTIVE:NO");
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to disable user $username on $computer_node_name");
		return;
	}
	elsif (grep(/ successfully/, @$output)) {
		notify($ERRORS{'OK'}, 0, "user $username disabled on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable user $username on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_pagefile

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_pagefile {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Set the registry key to blank
	my $memory_management_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';
	my $reg_add_command = $system32_path . '/reg.exe add "' . $memory_management_key . '" /v PagingFiles /d "" /t REG_MULTI_SZ /f';
	my ($reg_add_exit_status, $reg_add_output) = $self->execute($reg_add_command, 1);
	if (defined($reg_add_exit_status) && $reg_add_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "set registry key to disable pagefile");
	}
	elsif (defined($reg_add_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to disable pagefile, exit status: $reg_add_exit_status, output:\n@{$reg_add_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set registry key to disable pagefile");
		return;
	}

	# Attempt to reboot the computer in order to delete the pagefile
	if ($self->reboot()) {
		notify($ERRORS{'DEBUG'}, 0, "computer was rebooted after disabling pagefile in the registry");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to reboot computer after disabling pagefile");
		return;
	}
	
	# Attempt to delete the pagefile from all drives
	# A pagefile may reside on drives other than C: if additional volumes are configured in the image
	my @volume_list = $self->get_volume_list();
	if (!@volume_list || !(grep(/c/, @volume_list))) {
		@volume_list = ('c');
	}
	
	# Loop through the drive letters and attempt to delete pagefile.sys on each drive
	for my $drive_letter (@volume_list) {
		if ($self->delete_file("$drive_letter:/pagefile.sys")) {
			notify($ERRORS{'DEBUG'}, 0, "deleted pagefile.sys on all $drive_letter:");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to delete pagefile.sys on all $drive_letter:");
			return;
		}
	}

	return 1;
} ## end sub disable_pagefile

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_pagefile

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_pagefile {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $memory_management_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management';
	
	my $reg_add_command = $system32_path . '/reg.exe add "' . $memory_management_key . '" /v PagingFiles /d "$SYSTEMDRIVE\\pagefile.sys 0 0" /t REG_MULTI_SZ /f';
	my ($reg_add_exit_status, $reg_add_output) = $self->execute($reg_add_command, 1);
	if (defined($reg_add_exit_status) && $reg_add_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "set registry key to enable pagefile");
	}
	elsif (defined($reg_add_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry key to enable pagefile, exit status: $reg_add_exit_status, output:\n@{$reg_add_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to set registry key to enable pagefile");
		return;
	}

	return 1;
} ## end sub enable_pagefile

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_ipv6

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_ipv6 {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This registry file contains the entries to disable all IPv6 components 
; http://support.microsoft.com/kb/929852

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters]
"DisabledComponents"=dword:00000000
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set registry keys to enable IPv6");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry keys to enable IPv6");
		return 0;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_ipv6

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_ipv6 {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This registry file contains the entries to disable all IPv6 components 
; http://support.microsoft.com/kb/929852

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters]
"DisabledComponents"=dword:ffffffff
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set registry keys to disable IPv6");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry keys to disable IPv6");
		return 0;
	}

	return 1;
} ## end sub disable_ipv6

#//////////////////////////////////////////////////////////////////////////////

=head2 import_registry_string

 Parameters  :
 Returns     :
 Description :

=cut

sub import_registry_string {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $registry_string = shift;
	if (!defined($registry_string) || !$registry_string) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}

	#notify($ERRORS{'DEBUG'}, 0, "registry string:\n" . $registry_string);

	# Escape special characters with a backslash:
	# \
	# "
	#notify($ERRORS{'DEBUG'}, 0, "registry string:\n$registry_string");
	#$registry_string =~ s/\\+/\\\\\\\\/gs;
	$registry_string =~ s/\\/\\\\/gs;
	$registry_string =~ s/"/\\"/gs;

	# Replace \\" with \"
	#$registry_string =~ s/\\+(")/\\\\$1/gs;

	# Replace regular newlines with Windows newlines
	$registry_string =~ s/\r?\n/\r\n/gs;
	
	# Remove spaces from end of file
	$registry_string =~ s/\s+$//;

	# Assemble a temporary registry file path
	# Name the file after the sub which called this so you can tell where the .reg file was generated from
	my @caller = caller(1);
	my ($calling_sub) = $caller[3] =~ /([^:]+)$/;
	my $calling_line = $caller[2];
	my $temp_registry_file_path = "C:/Cygwin/tmp/$calling_sub\_$calling_line.reg";

	# Echo the registry string to a file on the node
	my $echo_registry_command = "rm -f $temp_registry_file_path; /usr/bin/echo.exe -E \"$registry_string\" > " . $temp_registry_file_path;
	my ($echo_registry_exit_status, $echo_registry_output) = $self->execute($echo_registry_command, 0);
	if (defined($echo_registry_exit_status) && $echo_registry_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "registry string contents echoed to $temp_registry_file_path");
	}
	elsif ($echo_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to echo registry string contents to $temp_registry_file_path, exit status: $echo_registry_exit_status, output:\n@{$echo_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to echo registry string contents to $temp_registry_file_path");
		return;
	}

	# Run reg.exe IMPORT
	if (!$self->reg_import($temp_registry_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry string contents from $temp_registry_file_path");
		return;
	}
	
	# Delete the temporary .reg file
	if (!$self->delete_file($temp_registry_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the temporary registry file: $temp_registry_file_path");
	}

	return 1;
} ## end sub import_registry_string

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_query

 Parameters  : $registry_key, $registry_value (optional), $suppress_key_missing_error (optional)
 Returns     : If $registry_value argument is specified: scalar
               If $registry_value argument is specified: hash reference
 Description : Queries the registry on the Windows computer. The $registry_key
               argument is required. The $registry_value argument is optional.
               
               If $registry_value is specified, a scalar containing the value's
               data is returned. The '(Default)' value's data is returned if the
               $registry_value is either an empty string or exactly matches the
               string '(Default)'.
               
               If $registry_value is NOT specified, a hash reference containing
               the keys's subkey names, values, and each value's data is
               returned. The hash has 2 keys: 'subkeys', 'values'.
               
               The 'subkeys' key contains an array reference. This array contains
               the names of the key arguments subkeys.
               
               The 'values' key contain a hash reference. The keys of this hash
               are the names of the values that are set for the key argument.
               Each of theses contains a 'type' and 'data' key containing the
               registry value type and value data.
               
               Example:
               my $registry_data = $self->os->reg_query('HKLM/SYSTEM/CurrentControlSet/Services/NetBT/Parameters');
               @{$registry_data->{subkeys}}[0] = 'Interfaces'
               my @value_names = @{$registry_data->{values}};
               $registry_data->{values}{$value_names[0]}{type} = 'REG_DWORD'
               $registry_data->{values}{$value_names[0]}{data} = '123'

=cut

sub reg_query {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $key_argument = shift;
	if (!defined($key_argument) || !$key_argument) {
		notify($ERRORS{'WARNING'}, 0, "registry key was not passed correctly as an argument");
		return;
	}
	my $value_argument = shift;
	
	my $suppress_key_missing_error = shift;
	
	# Replace forward slashes and double backslashes with a single backslashes
	$key_argument =~ s/[\\\/]+/\\/g;
	
	# Removing trailing slashes
	$key_argument =~ s/\\+$//g;
	
	# Replace abbreviated key names so argument matches reg.exe output
	$key_argument =~ s/^HKLM/HKEY_LOCAL_MACHINE/;
	$key_argument =~ s/^HKCU/HKEY_CURRENT_USER/;
	$key_argument =~ s/^HKCR/HKEY_CLASSES_ROOT/;
	$key_argument =~ s/^HKU/HKEY_USERS/;
	$key_argument =~ s/^HKCC/HKEY_CURRENT_CONFIG/;
	
	# Assemble the reg.exe QUERY command
	my $command .= "$system32_path/reg.exe QUERY \"$key_argument\" ";
	
	if (!defined($value_argument)) {
		# Do not add any switches
		$command .= "/s";
	}
	elsif ($value_argument eq '(Default)') {
		# Add /ve switch to query the default value
		$command .= "/ve";
	}
	else {
		# Escape slashes and double-quotes in the value argument
		(my $value_argument_escaped = $value_argument) =~ s/([\\\"])/\\$1/g;
		
		# Add /v switch to query a specific value
		$command .= "/v \"$value_argument_escaped\"";
	}
	
	# Ignore error lines, it will throw off parsing
	$command .= " 2>/dev/null";
	
	# Run reg.exe QUERY
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to query registry key: $key_argument");
		return;
	}
	elsif (grep(/unable to find the specified registry/, @$output)) {
		my $message = "registry key or value does not exist:\nkey: '$key_argument'\n";
		$message .= "value: '$value_argument'\n" if defined($value_argument);
		$message .= "command: '$command'\n";
		$message .= "exit status: $exit_status\n";
		$message .= "output:\n" . join("\n", @{$output});
		notify($ERRORS{'WARNING'}, 0, $message) unless $suppress_key_missing_error;
		return;
	}
	elsif (!grep(/REG.EXE VERSION|HKEY/, @$output)) {
		my $message = "failed to query registry:\nkey: '$key_argument'\n";
		$message .= "value: '$value_argument'\n" if defined($value_argument);
		$message .= "command: '$command'\n";
		$message .= "exit status: $exit_status\n";
		$message .= "output:\n" . join("\n", @{$output});
		notify($ERRORS{'WARNING'}, 0, $message);
		return;
	}
	
	# If value argument was specified, parse and return the data
	if (defined($value_argument)) {
		# Find the line containing the value information and parse it
		my ($value, $type, $data) = map { $_ =~ /^\s*(.*)\s+(REG_\w+)\s+(.*)/ } @$output;
		$value =~ s/(^\s+|\s+$)//g;
		$type =~ s/(^\s+|\s+$)//g;
		$data =~ s/(^\s+|\s+$)//g;
		
		$value = '(Default)' if $value =~ /NO NAME/;
		
		if ($type && defined($data)) {
			$data = $self->reg_query_convert_data($type, $data);
			notify($ERRORS{'DEBUG'}, 0, "retrieved registry data:\nkey: '$key_argument'\nvalue: '$value'\ntype: $type\ndata: '$data'");
			return $data;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve registry data:\nkey: '$key_argument'\nvalue: '$value'\ncommand: '$command'\noutput:\n" . string_to_ascii(join("\n", @$output)));
			return;
		}
	}
	else {
		# Value argument was not specified, construct a hash containing the contents of the key
		my %registry_hash;
		
		my $key;
		for my $line (@$output) {
			
			if ($line =~ /^HKEY/) {
				$key = $line;
				$registry_hash{$key} = {};
				next;
			}
			elsif ($line =~ /^\s*(.*)\s+(REG_\w+)\s+(.*)/) {
				my ($value, $type, $data) = ($1, $2, $3);
				$value =~ s/(^\s+|\s+$)//g;
				$type =~ s/(^\s+|\s+$)//g;
				$data =~ s/(^\s+|\s+$)//g;
				
				if ($type =~ /binary/i) {
					#notify($ERRORS{'DEBUG'}, 0, "ignoring $type data, key: $key, value: $value");
					next;
				}
				
				$value = '(Default)' if $value =~ /NO NAME/;
				
				$data = $self->reg_query_convert_data($type, $data);
				
				if (!defined($key) || !defined($value) || !defined($data) || !defined($type)) {
					my $message = "some registry data is undefined:\n";
					$message .= "line: '$line'\n";
					$message .= "key: '" . ($key || 'undefined') . "'\n";
					$message .= "value: '" . ($value || 'undefined') . "'\n";
					$message .= "data: '" . ($data || 'undefined') . "'\n";
					$message .= "type: '" . ($type || 'undefined') . "'";
					notify($ERRORS{'WARNING'}, 0, $message);
				}
				else {
					$registry_hash{$key}{$value}{type} = $type;
					$registry_hash{$key}{$value} = $data;
				}
			}
			elsif ($line =~ /^!/) {
				# Ignore lines beginning with '!'
				next;
			}
			elsif ($line =~ /^Error:/) {
				# Ignore lines beginning with 'Error:' -- this is common and probably not a problem
				# Example:
				#    Error:  Access is denied in the key HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\MRxDAV\EncryptedDirectories
				next;
			}
			else {
				# TODO: add support for registry values that span multiple lines. Example:
				#    Comments    REG_SZ  This security update is for Microsoft .NET Framework 3.5 SP1.
				#    If you later install a more recent service pack, this security update will be uninstalled automatically.
				#    For more information, visit http://support.microsoft.com/kb/2416473.
				#notify($ERRORS{'WARNING'}, 0, "unexpected output in line: '" . string_to_ascii($line) . "'\ncommand: '$command'");
			}
		}
		
		my $message = "retrieved registry data:\n";
		$message .= "key: '$key_argument'\n";
		$message .= "value: '$value_argument'\n" if defined($value_argument);
		$message .= "keys found: " . scalar(keys %registry_hash);
		notify($ERRORS{'DEBUG'}, 0, $message);
		
		return \%registry_hash;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_query_convert_data

 Parameters  : $type, $data
 Returns     : scalar
 Description :

=cut

sub reg_query_convert_data {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($type, $data) = @_;
	if (!$type || !defined($data)) {
		notify($ERRORS{'WARNING'}, 0, "registry data type and data value arguments were not specified");
		return;
	}
	
	if ($type =~ /dword/i) {
		if ($data =~ /^[a-fA-F0-9]+$/) {
			$data = "0x$data";
		}
		
		# Make sure a valid hex value was returned
		if ($data !~ /^0x[a-fA-F0-9]+$/) {
			notify($ERRORS{'WARNING'}, 0, "invalid $type value: '$data'");
			return;
		}
		
		# Convert the hex value to decimal
		$data = hex($data);
	}
	elsif ($type eq 'REG_MULTI_SZ') {
		# Split data into an array, data values are separated in the output by '\0'
		my @data_values = split(/\\0/, $data);
		$data = \@data_values;
	}
	elsif ($type =~ /hex/) {
		# Split data into an array, data values are separated in the output by ',00'
		my @hex_values = split(/,00,?/, $data);
		my $string;
		for my $hex_value (@hex_values) {
			my $decimal_value = hex $hex_value;
			$string .= pack("C*", $decimal_value);
		}
		return $string;
	}
	
	return $data;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_add

 Parameters  : $registry_key, $registry_value, $registry_type, $registry_data
 Returns     : If successful: true
               If failed: false
 Description : Adds or sets a registry key.

=cut

sub reg_add {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my ($registry_key, $registry_value, $registry_type, $registry_data) = @_;
	if (!defined($registry_key)) {
		notify($ERRORS{'WARNING'}, 0, "registry key argument was not supplied");
		return;
	}
	
	# Replace forward slashes with backslashes in registry key
	$registry_key =~ s/\//\\\\/g;
	
	if (defined($registry_value)) {
		if (!defined($registry_type)) {
			notify($ERRORS{'WARNING'}, 0, "registry value argument was supplied but type argument was not");
			return;
		}
		
		my $valid_types = 'REG_SZ|REG_MULTI_SZ|REG_DWORD_BIG_ENDIAN|REG_DWORD|REG_BINARY|REG_DWORD_LITTLE_ENDIAN|REG_NONE|REG_EXPAND_SZ';
		if ($registry_type !~ /^($valid_types)$/) {
			notify($ERRORS{'WARNING'}, 0, "invalid registry type was specified: '$registry_type', the following types are supported:\n" . join("\n", sort split(/\|/, $valid_types)));
			return;
		}
		
		if (!defined($registry_data)) {
			notify($ERRORS{'WARNING'}, 0, "registry value argument was supplied but data argument was not");
			return;
		}
	}
	
	# Assemble the reg.exe ADD command
	my $add_registry_command = "$system32_path/reg.exe ADD \"$registry_key\"";
	if ($registry_value) {
		if ($registry_value =~ /^default$/i) {
			$add_registry_command .= " /ve";
		}
		else {
			$add_registry_command .= " /v \"$registry_value\"";
		}
		$add_registry_command .= " /t $registry_type /d \"$registry_data\"";
	}
	$add_registry_command .= " /f";
	
	my ($add_registry_exit_status, $add_registry_output) = $self->execute($add_registry_command, 1);
	if (!defined($add_registry_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add registry key: $registry_key");
		return;
	}
	elsif ($add_registry_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "added registry key, command: $add_registry_command, output:\n" . join("\n", @$add_registry_output));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add registry key: $registry_key, exit status: $add_registry_exit_status, command:\n$add_registry_command\noutput:\n" . join("\n", @$add_registry_output));
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_delete

 Parameters  : registry key, registry value
 Returns     :
 Description :

=cut

sub reg_delete {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $registry_key = shift;
	if (!defined($registry_key) || !$registry_key) {
		notify($ERRORS{'WARNING'}, 0, "registry key was not passed correctly as an argument");
		return;
	}
	my $registry_value = shift;
	
	# Replace forward slashes with backslashes in registry key
	$registry_key =~ s/\//\\\\/g;
	
	# Run reg.exe DELETE
	my $delete_registry_command;
	if ($registry_value) {
		$delete_registry_command = $system32_path . "/reg.exe DELETE \"$registry_key\" /v \"$registry_value\" /f";
	}
	else {
		$delete_registry_command = $system32_path . "/reg.exe DELETE \"$registry_key\" /f";
		$registry_value = '*';
	}
	my ($delete_registry_exit_status, $delete_registry_output) = $self->execute($delete_registry_command, 0);
	if (defined($delete_registry_exit_status) && $delete_registry_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "deleted registry key: $registry_key, value: $registry_value, output:\n" . join("\n", @$delete_registry_output));
	}
	elsif ($delete_registry_output && grep(/unable to find/i, @$delete_registry_output)) {
		# Error: The system was unable to find the specified registry key or value
		notify($ERRORS{'DEBUG'}, 0, "registry key does NOT exist: $registry_key");
	}
	elsif ($delete_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete registry key: $registry_key, value: $registry_value, exit status: $delete_registry_exit_status, output:\n@{$delete_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to delete registry key: $registry_key, value: $registry_value");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_import

 Parameters  :
 Returns     :
 Description :

=cut

sub reg_import {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the registry file path argument
	my $registry_file_path = shift;
	if (!defined($registry_file_path) || !$registry_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	
	# Run reg.exe IMPORT
	my $command .= $system32_path . "/reg.exe IMPORT $registry_file_path";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to import registry file: $registry_file_path");
		return;
	}
	elsif (grep(/completed successfully/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "imported registry file: $registry_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to import registry file: $registry_file_path, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_export

 Parameters  :
 Returns     :
 Description :

=cut

sub reg_export {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $root_key = shift;
	if (!$root_key) {
		notify($ERRORS{'WARNING'}, 0, "registry root key was not passed correctly as an argument");
		return;
	}
	
	# Get the registry file path argument
	my $registry_file_path = shift;
	if (!defined($registry_file_path) || !$registry_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry file path was not passed correctly as an argument");
		return;
	}
	$registry_file_path = $self->format_path_dos($registry_file_path);
	
	# Replace forward slashes with backslashes in registry key
	$root_key =~ s/\//\\\\/g;
	
	# Run reg.exe EXPORT
	my $command .= "cmd.exe /c \"del /Q \\\"$registry_file_path.tmp\\\" 2>NUL & $system32_path/reg.exe EXPORT $root_key \\\"$registry_file_path.tmp\\\" && type \\\"$registry_file_path.tmp\\\" > \\\"$registry_file_path\\\" && del /Q \\\"$registry_file_path.tmp\\\"\"";
	my ($exit_status, $output) = $self->execute($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to export registry key $root_key to file: $registry_file_path");
		return;
	}
	elsif (grep(/completed successfully/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "exported registry key $root_key to file: $registry_file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to export registry key $root_key to file: $registry_file_path, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_load

 Parameters  : $root_key, $hive_file_path
 Returns     :
 Description :

=cut

sub reg_load {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $root_key = shift;
	if (!$root_key) {
		notify($ERRORS{'WARNING'}, 0, "registry root key was not passed correctly as an argument");
		return;
	}
	my $hive_file_path = shift;
	if (!$hive_file_path) {
		notify($ERRORS{'WARNING'}, 0, "registry hive file path was not passed correctly as an argument");
		return;
	}
	$hive_file_path = $self->format_path_unix($hive_file_path);
	
	# Escape backslashes in the root key
	$root_key =~ s/\\+/\\\\/;
	
	# Run reg.exe LOAD
	my $command .= "$system32_path/reg.exe LOAD $root_key $hive_file_path";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to load registry hive file '$hive_file_path' into key $root_key");
		return;
	}
	elsif (grep(/completed successfully/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "loaded registry hive file '$hive_file_path' into key $root_key");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to load registry hive file '$hive_file_path' into key $root_key, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reg_unload

 Parameters  : $root_key
 Returns     :
 Description :

=cut

sub reg_unload {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my $root_key = shift;
	if (!$root_key) {
		notify($ERRORS{'WARNING'}, 0, "registry root key was not passed correctly as an argument");
		return;
	}
	
	# Escape backslashes in the root key
	$root_key =~ s/\\+/\\\\/;
	
	# Run reg.exe UNLOAD
	my $command .= "$system32_path/reg.exe UNLOAD $root_key";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to unload registry hive: $root_key");
		return;
	}
	elsif (grep(/completed successfully/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "unloaded registry hive key: $root_key");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to unload registry hive: $root_key, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_hklm_run_registry_key

 Parameters  :
 Returns     :
 Description :

=cut

sub add_hklm_run_registry_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $command_name = shift;
	my $command      = shift;

	notify($ERRORS{'DEBUG'}, 0, "command name: " . $command_name);
	notify($ERRORS{'DEBUG'}, 0, "command: " . $command);

	# Replace forward slashes with backslashes, unless a space precedes the forward slash
	$command =~ s/([^ ])\//$1\\/g;
	notify($ERRORS{'DEBUG'}, 0, "forward to backslash: " . $command);

	# Escape backslashes, can never have enough...
	$command =~ s/\\/\\\\/g;
	notify($ERRORS{'DEBUG'}, 0, "escape backslashes: " . $command);

	# Escape quotes
	$command =~ s/"/\\"/g;
	notify($ERRORS{'DEBUG'}, 0, "escaped quotes: " . $command);

	# Make sure arguments were supplied
	if (!defined($command_name) && !defined($command)) {
		notify($ERRORS{'WARNING'}, 0, "HKLM run registry key not added, arguments were not passed correctly");
		return 0;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run]
"$command_name"="$command"
EOF

	notify($ERRORS{'DEBUG'}, 0, "registry string:\n" . $registry_string);

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "added HKLM run registry value, name: $command_name, command: $command");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to add HKLM run registry value, name: $command_name, command: $command");
		return 0;
	}
	
	# Attempt to query the registry key to make sure it was added
	my $reg_query_command = $system32_path . '/reg.exe query "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run"';
	my ($reg_query_exit_status, $reg_query_output) = $self->execute($reg_query_command, 1);
	if (defined($reg_query_exit_status) && $reg_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried '$command_name' registry key:\n" . join("\n", @{$reg_query_output}));
	}
	elsif (defined($reg_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query '$command_name' registry key, exit status: $reg_query_exit_status, output:\n@{$reg_query_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to query '$command_name' registry key");
		return;
	}
	
	return 1;
} ## end sub add_hklm_run_registry_key

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_hklm_run_registry_key

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_hklm_run_registry_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $key_name = shift;
	
	# Make sure argument was supplied
	if (!defined($key_name) && !defined($key_name)) {
		notify($ERRORS{'WARNING'}, 0, "HKLM run registry key not deleted, argument was not passed correctly");
		return 0;
	}
	
	# Attempt to query the registry key to make sure it was added
	my $reg_delete_command = $system32_path . '/reg.exe delete "HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run" /v "' . $key_name . '" /F';
	my ($reg_delete_exit_status, $reg_delete_output) = $self->execute($reg_delete_command, 1);
	if (defined($reg_delete_exit_status) && $reg_delete_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted '$key_name' run registry key:\n" . join("\n", @{$reg_delete_output}));
	}
	elsif (defined($reg_delete_output) && grep(/unable to find/i, @{$reg_delete_output})) {
		notify($ERRORS{'OK'}, 0, "'$key_name' run registry key was not deleted, it does not exist");
	}
	elsif (defined($reg_delete_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete '$key_name' run registry key, exit status: $reg_delete_exit_status, output:\n@{$reg_delete_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to delete '$key_name' run registry key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_scheduled_task_credentials

 Parameters  : $task_name, $username, $password
 Returns     : boolean
 Description : Sets the credentials under which a scheduled task runs.

=cut

sub set_scheduled_task_credentials {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($task_name, $username, $password) = @_;
	if (!defined($task_name) || !defined($username) || !defined($password)) {
		notify($ERRORS{'WARNING'}, 0, "scheduled task name, username, and password arguments were not supplied");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $password_escaped = _escape_password($password);
	my $command = "$system32_path/schtasks.exe /Change /RU \"$username\" /RP \"$password_escaped\" /TN \"$task_name\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to change password for scheduled task: $task_name");
		return;
	}
	elsif (grep (/^SUCCESS:/, @$output)) {
		notify($ERRORS{'OK'}, 0, "changed password for scheduled task: $task_name");
		return 1;
	}
	elsif (grep (/The parameter is incorrect/, @$output)) {
		if ($task_name =~ /{/) {
			# Ignore task such as: \User_Feed_Synchronization-{88DE35B9-C115-4DE3-AB5E-B9D2C4A2DB66}
			# This one always fails and is not important
			notify($ERRORS{'DEBUG'}, 0, "unable to change password for scheduled task '$task_name' due to Windows bug\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to change password for scheduled task '$task_name' due to Windows bug\ncommand: '$command'\noutput:\n" . join("\n", @$output));
			# Don't return false - There is a bug in Windows 7
			# If a scheduled task is created using the GUI using a schedule the password cannot be set via schtasks.exe
			# schtasks.exe displays: ERROR: The parameter is incorrect.
			# If the same task is changed to run on an event such as logon it works	
		}
		return 1;
	}
	elsif (grep (/^ERROR:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to change password for scheduled task: $task_name, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned while attempting to change password for scheduled task: $task_name, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_scheduled_task

 Parameters  :
 Returns     :
 Description :

=cut

sub delete_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my $task_name     = shift;
	
	# Run schtasks.exe to delete any existing task
	my $delete_task_command = "$system32_path/schtasks.exe /Delete /F /TN \"$task_name\"";
	my ($delete_task_exit_status, $delete_task_output) = $self->execute($delete_task_command);
	if (defined($delete_task_exit_status) && $delete_task_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted existing scheduled task '$task_name' on $computer_node_name");
	}
	elsif (defined($delete_task_output) && grep(/(task.*does not exist|cannot find the file specified)/i, @{$delete_task_output})) {
		notify($ERRORS{'DEBUG'}, 0, "scheduled task '$task_name' does not exist on $computer_node_name");
	}
	elsif (defined($delete_task_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete existing scheduled task '$task_name' on $computer_node_name, exit status: $delete_task_exit_status, output:\n@{$delete_task_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to delete existing scheduled task '$task_name' on $computer_node_name");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_startup_scheduled_task

 Parameters  : $task_name, $task_command, $task_user, $task_password
 Returns     :
 Description :

=cut

sub create_startup_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my $task_name     = shift;
	my $task_command  = shift;
	my $task_user     = shift;
	my $task_password = shift;

	# Escape backslashes, can never have enough...
	$task_command =~ s/\\/\\\\/g;

	# Replace forward slashes with backslashes
	$task_command =~ s/([^\s])\//$1\\\\/g;
	
	# Escape quote characters
	$task_command =~ s/"/\\"/g;

	# Make sure arguments were supplied
	if (!defined($task_name) || !defined($task_command) || !defined($task_user) || !defined($task_password)) {
		notify($ERRORS{'WARNING'}, 0, "startup scheduled task not added, arguments were not passed correctly");
		return;
	}

	# You cannot create a task if one with the same name already exists
	# Windows 6.x schtasks.exe has a /F which forces a new task to be created if one with the same name already exists
	# This option isn't supported with XP and other older versions of Windows
	if (!$self->delete_scheduled_task($task_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete existing scheduled task '$task_name' on $computer_node_name");
	}
	
	# Run schtasks.exe to add the task
	# Occasionally see this error even though it schtasks.exe returns exit status 0:
	# WARNING: The Scheduled task "System Startup Script" has been created, but may not run because the account information could not be set.
	my $password_escaped = _escape_password($task_password);
	my $command = "$system32_path/schtasks.exe /Create /RU \"$task_user\" /RP \"$password_escaped\" /RL HIGHEST /SC ONSTART /TN \"$task_name\" /TR \"$task_command\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command created scheduled task '$task_name' on $computer_node_name");
		return;
	}
	elsif (grep(/password is incorrect/, @$output)) {
		# ERROR: The user name or password is incorrect.
		notify($ERRORS{'WARNING'}, 0, "failed to create scheduled task '$task_name' on $computer_node_name\n" .
			"username         : '$task_user'\n" .
			"password         : '$task_password'\n" .
			"escaped password : '$password_escaped'\n" .
			"command:\n$command\n" .
			"output:\n" . join("\n", @$output)
		);
		return 0;
	}
	elsif ($exit_status != 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to create scheduled task '$task_name' on $computer_node_name, exit status: $exit_status, command: '$command', output:\n@$output");
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "created scheduled task '$task_name' on $computer_node_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_update_cygwin_startup_scheduled_task

 Parameters  : none
 Returns     : boolean
 Description : Creates a scheduled task that runs on startup named 'VCL Update
               Cygwin' which runs update_cygwin.cmd as root.

=cut

sub create_update_cygwin_startup_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Avoid doing this more than once
	if ($self->{created_update_cygwin_startup_scheduled_task}) {
		return 1;
	}
	
	my $request_state = $self->data->get_request_state_name();
	my $node_configuration_directory = $self->get_node_configuration_directory();
	
	my $root_password;
	if ($request_state =~ /(image|checkpoint)/) {
		$root_password = $WINDOWS_ROOT_PASSWORD;
	}
	else {
		if ($self->{root_password}) {
			$root_password = $self->{root_password};
		}
		else {
			$root_password = getpw();
			$self->{root_password} = $root_password;
		}
	}
	
	if (!$self->set_password('root', $root_password)) {
		notify($ERRORS{'WARNING'}, 0, "unable to create startup scheduled task to update Cygwin, failed to set root password");
		return;
	}
	
	# Make sure the 'VCL Post Load' task doesn't exist or they will conflict
	$self->delete_scheduled_task('VCL Post Load');
	
	# Copy the current version of update_cygwin.cmd to the computer
	$self->copy_file_to("$SOURCE_CONFIGURATION_DIRECTORY/Scripts/update_cygwin.cmd", "$node_configuration_directory/Scripts/update_cygwin.cmd");

	# Create a scheduled task to run post_load.cmd when the image boots
	my $task_command = "$node_configuration_directory/Scripts/update_cygwin.cmd >> $node_configuration_directory/Logs/update_cygwin.log";
	if ($self->create_startup_scheduled_task('VCL Update Cygwin', $task_command, 'root', $root_password)) {
		$self->{created_update_cygwin_startup_scheduled_task} = 1;
		return 1;
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub enable_autoadminlogon {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file enables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="1"
"DefaultUserName"="root"
"DefaultPassword"= "$WINDOWS_ROOT_PASSWORD"

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "enabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable autoadminlogon");
		return 0;
	}
} ## end sub enable_autoadminlogon

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_autoadminlogon

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_autoadminlogon {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

; This file disables autoadminlogon for the root account

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon]
"AutoAdminLogon"="0"
"AutoLogonCount"="0"
"DefaultPassword"= ""
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled autoadminlogon");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable autoadminlogon");
		return 0;
	}
} ## end sub disable_autoadminlogon

#//////////////////////////////////////////////////////////////////////////////

=head2 create_eventlog_entry

 Parameters  :
 Returns     :
 Description :

=cut

sub create_eventlog_entry {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my $message = shift;

	# Make sure the message was passed as an argument
	if (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create eventlog entry, message was passed as an argument");
		return 0;
	}

	# Run eventcreate.exe to create an event log entry
	my $eventcreate_command = $system32_path . '/eventcreate.exe /T INFORMATION /L APPLICATION /SO VCL /ID 555 /D "' . $message . '"';
	my ($eventcreate_exit_status, $eventcreate_output) = $self->execute($eventcreate_command);
	if (defined($eventcreate_exit_status) && $eventcreate_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "created event log entry on $computer_node_name: $message");
	}
	elsif (defined($eventcreate_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create event log entry on $computer_node_name: $message, exit status: $eventcreate_exit_status, output:\n@{$eventcreate_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to create event log entry on $computer_node_name: $message");
		return;
	}

	return 1;
} ## end sub create_eventlog_entry

#//////////////////////////////////////////////////////////////////////////////

=head2 reboot

 Parameters  : $total_wait_seconds, $attempt_delay_seconds, $attempt_limit, $pre_configure
 Returns     : boolean
 Description : 

=cut

sub reboot {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if an arguments were supplied
	
	# Attempt to get the total number of seconds to wait from the arguments
	my $total_wait_seconds = shift;
	if (!defined($total_wait_seconds) || $total_wait_seconds !~ /^\d+$/) {
		$total_wait_seconds = 300;
	}
	
	# Seconds to wait in between loop attempts
	my $attempt_delay_seconds = shift;
	if (!defined($attempt_delay_seconds) || $attempt_delay_seconds !~ /^\d+$/) {
		$attempt_delay_seconds = 15;
	}
	
	# Number of power reset attempts to make if reboot fails
	my $attempt_limit = shift;
	if (!defined($attempt_limit) || $attempt_limit !~ /^\d+$/) {
		$attempt_limit = 2;
	}
	
	my $pre_configure = shift;
	$pre_configure = 1 unless defined $pre_configure;

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path();

	my $reboot_start_time = time();
	notify($ERRORS{'DEBUG'}, 0, "reboot will be attempted on $computer_node_name");

	# Check if computer responds to ssh before preparing for reboot
	if ($system32_path && $self->wait_for_ssh(0)) {
		# Perform pre-reboot configuration tasks unless $pre_configure argument was supplied and is false
		if ($pre_configure) {
			# Make sure SSH access is enabled from private IP addresses
			if (!$self->firewall_enable_ssh_private()) {
				notify($ERRORS{'WARNING'}, 0, "reboot not attempted, failed to enable ssh from private IP addresses");
				return 0;
			}
			
			# Set sshd service startup mode to auto
			if (!$self->set_service_startup_mode('sshd', 'auto')) {
				notify($ERRORS{'WARNING'}, 0, "reboot not attempted, unable to set sshd service startup mode to auto");
				return 0;
			}
			
			# Make sure ping access is enabled from private IP addresses
			if (!$self->firewall_enable_ping_private()) {
				notify($ERRORS{'WARNING'}, 0, "reboot not attempted, failed to enable ping from private IP addresses");
				return 0;
			}
			
			# Kill the screen saver process, it occasionally prevents reboots and shutdowns from working
			$self->kill_process('logon.scr');
			
			# Make sure update_cygwin.cmd runs after the computer is rebooted with the new hostname
			$self->create_update_cygwin_startup_scheduled_task();
		}
		
		# Delete cached network configuration information so it is retrieved next time it is needed
		delete $self->{network_configuration};
		
		# Check if tsshutdn.exe exists on the computer
		# tsshutdn.exe is the preferred utility, shutdown.exe often fails on Windows Server 2003
		my $reboot_command;
		my $windows_product_name = $self->get_product_name() || '';
		if ($windows_product_name =~ /2003/ && $self->file_exists("$system32_path/tsshutdn.exe")) {
			$reboot_command = "$system32_path/tsshutdn.exe 0 /REBOOT /DELAY:0 /V";
		}
		else {
			$reboot_command = "$system32_path/shutdown.exe /r /t 0 /f";
		}
		
		my ($reboot_exit_status, $reboot_output) = $self->execute($reboot_command);
		if (!defined($reboot_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to reboot $computer_node_name");
			return;
		}
		elsif ($reboot_exit_status == 0) {
			notify($ERRORS{'OK'}, 0, "executed reboot command on $computer_node_name");
		}
		else {
			# The following message may be displayed causing the reboot to fail:
			# The computer is processing another action and thus cannot be shut down. Wait until the computer has finished its action, and then try again.(21) 
			notify($ERRORS{'WARNING'}, 0, "failed to reboot $computer_node_name, attempting power reset, output:\n" . join("\n", @$reboot_output));
			
			# Call provisioning module's power_reset() subroutine
			if ($self->provisioner->power_reset()) {
				notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
				return;
			}
		}
	}
	else {
		# Computer did not respond to ssh
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name did not respond to ssh, graceful reboot cannot be performed, attempting hard reset");

		# Call provisioning module's power_reset() subroutine
		if ($self->provisioner->power_reset()) {
			notify($ERRORS{'OK'}, 0, "initiated power reset on $computer_node_name");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "reboot failed, failed to initiate power reset on $computer_node_name");
			return 0;
		}
	} ## end else [ if ($self->wait_for_ssh(0))

	# Wait for the reboot to complete
	my $result = $self->wait_for_reboot($total_wait_seconds, $attempt_delay_seconds, $attempt_limit);
	my $reboot_duration = (time - $reboot_start_time);
	if ($result) {
		# Reboot was successful, calculate how long reboot took
		notify($ERRORS{'OK'}, 0, "reboot complete on $computer_node_name, took $reboot_duration seconds");
		
		# Clear any previous reboot_required reasons to prevent unnecessary reboots
		delete $self->{reboot_required};
		
		# Clear any imagemeta postoption reboot flag
		$self->data->set_imagemeta_postoption('');
		
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "reboot failed on $computer_node_name, waited $reboot_duration seconds for computer to respond");
		return 0;
	}
} ## end sub reboot

#//////////////////////////////////////////////////////////////////////////////

=head2 shutdown

 Parameters  : $enable_dhcp
 Returns     : 
 Description : 

=cut

sub shutdown {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the argument that determines whether or not to disable DHCP before shutting down computer
	my $enable_dhcp = shift;

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Kill the screen saver process, it occasionally prevents reboots and shutdowns from working
	$self->kill_process('logon.scr');
	
	# Clear the event log before shutting down
	$self->clear_event_log();
	
	my $shutdown_command = "/bin/cygstart.exe \$SYSTEMROOT/system32/cmd.exe /c \"";
	
	if ($enable_dhcp) {
		notify($ERRORS{'DEBUG'}, 0, "enabling DHCP and shutting down $computer_node_name");
		
		my $private_interface_name = $self->get_private_interface_name();
		my $public_interface_name = $self->get_public_interface_name();
		if (!$private_interface_name || !$public_interface_name) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine private and public interface names, failed to enable DHCP and shut down $computer_node_name");
			return;
		}
		
		$shutdown_command .= "$system32_path/netsh.exe interface ip set address name=\\\"$private_interface_name\\\" source=dhcp & ";
		$shutdown_command .= "$system32_path/netsh.exe interface ip set dnsservers name=\\\"$private_interface_name\\\" source=dhcp & ";
		$shutdown_command .= "$system32_path/netsh.exe interface ip set address name=\\\"$public_interface_name\\\" source=dhcp & ";
		$shutdown_command .= "$system32_path/netsh.exe interface ip set dnsservers name=\\\"$public_interface_name\\\" source=dhcp & ";
		$shutdown_command .= "$system32_path/netsh.exe interface ip reset $NODE_CONFIGURATION_DIRECTORY/Logs/ipreset.log & ";
		$shutdown_command .= "$system32_path/ipconfig.exe /release & ";
		$shutdown_command .= "$system32_path/ipconfig.exe /flushdns & ";
		$shutdown_command .= "$system32_path/arp.exe -d * & ";
		$shutdown_command .= "$system32_path/route.exe DELETE 0.0.0.0 MASK 0.0.0.0 & ";
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "shutting down $computer_node_name");
	}
	
	# Check if tsshutdn.exe exists on the computer
	# tsshutdn.exe is the preferred utility for Windows 2003, shutdown.exe often fails
	my $windows_product_name = $self->get_product_name() || '';
	if ($windows_product_name =~ /2003/ && $self->file_exists("$system32_path/tsshutdn.exe")) {
		$shutdown_command .= "$system32_path/tsshutdn.exe 0 /POWERDOWN /DELAY:0 /V";
	}
	else {
		$shutdown_command .= "$system32_path/shutdown.exe /s /t 0 /f";
	}
	
	$shutdown_command .= "\"";
	
	my $attempt_count = 0;
	my $attempt_limit = 12;
	while ($attempt_count < $attempt_limit) {
		$attempt_count++;
		if ($attempt_count > 1) {
			notify($ERRORS{'DEBUG'}, 0, "sleeping for 10 seconds before making next shutdown attempt");
			sleep 10;
		}
		
		my ($shutdown_exit_status, $shutdown_output) = $self->execute($shutdown_command);
		if (!defined($shutdown_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute ssh command to shutdown $computer_node_name");
			last;
		}
		elsif (grep(/(processing another action)/i, @$shutdown_output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $attempt_count/$attempt_limit: failed to execute shutdown command on $computer_node_name, exit status: $shutdown_exit_status, output:\n@{$shutdown_output}");
			next;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "attempt $attempt_count/$attempt_limit: executed shutdown command on $computer_node_name");
			last;
		}
	}
	
	# Wait maximum of 3 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(180)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping after shutdown command was issued");
		return;
	}
	
	# Wait maximum of 5 minutes for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(300);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 1 minute to allow computer time to shutdown");
		sleep 60;
	}
	elsif (!$power_off) {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_service_startup_mode

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub set_service_startup_mode {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $service_name = shift;
	my $startup_mode = shift;

	# Make sure both arguments were supplied
	if (!defined($service_name) && !defined($startup_mode)) {
		notify($ERRORS{'WARNING'}, 0, "set service startup mode failed, service name and startup mode arguments were not passed correctly");
		return 0;
	}

	# Make sure the startup mode is valid
	if ($startup_mode !~ /boot|system|auto|demand|disabled|delayed-auto|manual/i) {
		notify($ERRORS{'WARNING'}, 0, "set service startup mode failed, invalid startup mode: $startup_mode");
		return 0;
	}

	# Set the mode to demand if manual was specified, specific to sc command
	$startup_mode = "demand" if ($startup_mode eq "manual");

	# Use sc.exe to change the start mode
	my $service_startup_command = $system32_path . '/sc.exe config ' . "$service_name start= $startup_mode";
	my ($service_startup_exit_status, $service_startup_output) = $self->execute($service_startup_command);
	if (defined($service_startup_output) && grep(/service does not exist/, @$service_startup_output)) {
		notify($ERRORS{'WARNING'}, 0, "$service_name service startup mode not set because service does not exist");
		return;
	}
	elsif (defined($service_startup_exit_status) && $service_startup_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "$service_name service startup mode set to $startup_mode");
	}
	elsif ($service_startup_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to set $service_name service startup mode to $startup_mode, exit status: $service_startup_exit_status, output:\n@{$service_startup_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to set $service_name service startup mode to $startup_mode");
		return;
	}

	return 1;
} ## end sub set_service_startup_mode

#//////////////////////////////////////////////////////////////////////////////

=head2 defragment_hard_drive

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub defragment_hard_drive {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Defragment the hard drive
	notify($ERRORS{'OK'}, 0, "beginning to defragment the hard drive on $computer_node_name");
	my ($defrag_exit_status, $defrag_output) = $self->execute({ command => "$system32_path/defrag.exe \$SYSTEMDRIVE -v", timeout => (15 * 60)});
	if (defined($defrag_exit_status) && $defrag_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "hard drive defragmentation complete on $computer_node_name");
		return 1;
	}
	elsif (defined($defrag_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to defragment the hard drive, exit status: $defrag_exit_status, output:\n@{$defrag_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run the SSH command to defragment the hard drive");
		return;
	}
} ## end sub defragment_hard_drive

#//////////////////////////////////////////////////////////////////////////////

=head2 prepare_post_load

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : This subroutine should be called as the last step before an image
               is captured if Sysprep is not is used. It enables autoadminlogon
               so that root automatically logs on the next time the computer is
               booted and creates a registry key under
               HKLM\Software\Microsoft\Windows\CurrentVersion\Run.
               
               This key causes the post_load.cmd script after the image is
               loaded when root automatically logs on. This script needs to run
               in order to configure networking and the Cygwin SSH service.

=cut

sub prepare_post_load {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $end_state = $self->{end_state} || 'off';
	
	# Set the DevicePath registry key
	# This is used to locate device drivers
	if (!$self->set_device_path_key()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the DevicePath registry key");
		return;
	}
	
	# Get the node configuration directory
	my $node_configuration_directory = $self->get_node_configuration_directory();
	unless ($node_configuration_directory) {
		notify($ERRORS{'WARNING'}, 0, "node configuration directory could not be determined");
		return;
	}
	
	# Add HKLM run key to call post_load.cmd after the image comes up
	if (!$self->add_hklm_run_registry_key('post_load.cmd', $node_configuration_directory . '/Scripts/post_load.cmd  >> ' . $node_configuration_directory . '/Logs/post_load.log')) {
		notify($ERRORS{'WARNING'}, 0, "unable to create run key to call post_load.cmd");
		return;
	}
	
	# Enable autoadminlogon
	if (!$self->enable_autoadminlogon()) {
		notify($ERRORS{'WARNING'}, 0, "unable to enable autoadminlogon");
		return 0;
	}
	
	# Shut down computer unless end_state argument was passed with a value other than 'off'
	if ($end_state eq 'off') {
		if (!$self->shutdown(1)) {
			notify($ERRORS{'WARNING'}, 0, "failed to shut down computer");
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_service_credentials

 Parameters  : $service_name, $username, $password
 Returns     : 
 Description : 

=cut

sub set_service_credentials {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Attempt to get the username from the arguments
	my $service_name = shift;
	my $username     = shift;
	my $password     = shift;

	# Make sure arguments were supplied
	if (!$service_name || !$username || !$password) {
		notify($ERRORS{'WARNING'}, 0, "set service logon failed, service name, username, and password arguments were not passed correctly");
		return 0;
	}

	# Attempt to set the service logon user name and password
	my $password_escaped = _escape_password($password);
	my $service_logon_command = "$system32_path/sc.exe config $service_name obj= \".\\$username\" password= \"$password_escaped\"";
	my ($service_logon_exit_status, $service_logon_output) = $self->execute($service_logon_command);
	if (defined($service_logon_exit_status) && $service_logon_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "changed logon credentials for '$service_name' service to $username ($password) on $computer_node_name");
	}
	elsif (defined($service_logon_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to change $service_name service logon credentials to $username ($password) on $computer_node_name, exit status: $service_logon_exit_status, output:\n@{$service_logon_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to change $service_name service logon credentials to $username ($password) on $computer_node_name");
		return;
	}
	
	return 1;
} ## end sub set_service_credentials

#//////////////////////////////////////////////////////////////////////////////

=head2 get_service_configuration

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves info for all services installed on the computer. A hash
               reference is returned. The hash keys are service names.
               Example:
                  "sshd" => {
                    "SERVICE_START_NAME" => ".\\root",
                  },

=cut

sub get_service_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{service_configuration} if $self->{service_configuration};

	my $computer_node_name   = $self->data->get_computer_node_name();
	
	notify($ERRORS{'DEBUG'}, 0, "retrieving service configuration information from the registry");
	
	my $services_key = 'HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services';
	
	my $cygwin_path = $self->get_cygwin_installation_directory_path();

	my $node_reg_file_path = $cygwin_path . "/tmp/services_$computer_node_name.reg";
	my $mn_reg_file_path = "/tmp/vcl/services_$computer_node_name.reg";
	
	# Export the registry key to the temp directory on the computer
	if (!$self->reg_export($services_key, $node_reg_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve service credential information from the registry on $computer_node_name");
		return;
	}
	
	# Copy the file to the managment node
	if (!$self->copy_file_from($node_reg_file_path, $mn_reg_file_path)) {
		return;
	}
	
	# Get the contents of the file on the managment node
	my @reg_file_contents = $self->mn_os->get_file_contents($mn_reg_file_path);
	if (!@reg_file_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of file on $computer_node_name containing exported service credential information from the registry: $node_reg_file_path");
		return;
	}
	
	# Delete the registry files
	$self->delete_file($node_reg_file_path);
	$self->mn_os->delete_file($mn_reg_file_path);
	
	my $service_configuration;
	my $service_name;
	for my $line (@reg_file_contents) {
		if ($line =~ /Services\\([^\\]+)\]$/i) {
			$service_name = $1;
			$service_configuration->{$service_name} = {};
		}
		elsif ($line =~ /"ObjectName"="(.+)"/i) {
			my $object_name = $1;
			$service_configuration->{$service_name}{SERVICE_START_NAME} = $object_name;
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "retrieved service configuration from $computer_node_name:\n" . format_data($service_configuration));
	$self->{service_configuration} = $service_configuration;
	return $self->{service_configuration};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_service_login_ids

 Parameters  : $login_id
 Returns     : array
 Description : Enumerates the services installed on the computer and returns an
               array containing the names of the services which are configured
               to run using the credentials of the login ID specified as the
               argument.

=cut

sub get_services_using_login_id {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $login_id = shift;
	if (!$login_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to get services using login id, login id argument was not passed correctly");
		return;
	}
	
	# Get configuration for all the services installed on the computer
	my $service_configuration = $self->get_service_configuration();
	
	my @matching_service_names;
	for my $service_name (sort keys %$service_configuration) {
		my $service_start_name = $service_configuration->{$service_name}{SERVICE_START_NAME};
		
		# The service start name may be in any of the following forms:
		#    LocalSystem
		#    NT AUTHORITY\LocalService
		#    .\root
		if ($service_start_name && $service_start_name =~ /^((NT AUTHORITY|\.)\\+)?$login_id$/i) {
			push @matching_service_names, $service_name;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "services found using login ID '$login_id' (" . scalar(@matching_service_names) . "): " . join(", ", @matching_service_names));
	return @matching_service_names;
} ## end sub get_services_using_login_id

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_scheduled_task

 Parameters  : 
 Returns     : 1 success 0 failure
 Description : 

=cut

sub disable_scheduled_task {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Attempt to get the task name from the arguments
	my $task_name = shift;
	if (!$task_name) {
		notify($ERRORS{'OK'}, 0, "failed to disable scheduled task, task name argument was not correctly passed");
		return;
	}

	# Attempt to delete the user account
	my $schtasks_command = $system32_path . '/schtasks.exe /Change /DISABLE /TN "' . $task_name . '"';
	my ($schtasks_exit_status, $schtasks_output) = $self->execute($schtasks_command, 1);
	if (!defined($schtasks_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to disable $task_name scheduled task on $computer_node_name");
		return;
	}
	elsif (grep(/have been changed/, @$schtasks_output)) {
		notify($ERRORS{'OK'}, 0, "$task_name scheduled task disabled on $computer_node_name");
	}
	elsif (grep(/does not exist/, @$schtasks_output)) {
		notify($ERRORS{'OK'}, 0, "$task_name was not disabled on $computer_node_name because it does not exist");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable $task_name scheduled task on $computer_node_name, exit status: $schtasks_exit_status, output:\n@{$schtasks_output}");
		return 0;
	}
	

	return 1;
} ## end sub disable_scheduled_task

#//////////////////////////////////////////////////////////////////////////////

=head2 get_scheduled_task_info

 Parameters  : 
 Returns     : hash reference
 Description : Queries the scheduled tasks on a computer and returns the
               configuration for each task. A hash reference is returned. The
               hash keys are the scheduled task names.
					Example:
               "\\Microsoft\\Windows\\Time Synchronization\\SynchronizeTime" => {
                    "Author" => "Microsoft Corporation",
                    "Comment" => "Maintains date and time synchronization...",
                    "Days" => "1/1/2005",
                    "Delete Task If Not Rescheduled" => "Stop On Battery Mode",
                    "End Date" => "1:00:00 AM",
                    "HostName" => "WIN7-64BIT",
                    "Idle Time" => " any services that explicitly depend on it will fail to start.",
                    "Last Result" => 1056,
                    "Last Run Time" => "9/11/2011 1:00:00 AM",
                    "Logon Mode" => "Interactive/Background",
                    "Months" => "N/A",
                    "Next Run Time" => "9/18/2011 1:00:00 AM",
                    "Power Management" => "Enabled",
                    "Repeat: Every" => "SUN",
                    "Repeat: Stop If Still Running" => "Disabled",
                    "Repeat: Until: Duration" => "Disabled",
                    "Repeat: Until: Time" => "Every 1 week(s)",
                    "Run As User" => "Disabled",
                    "Schedule" => "Enabled",
                    "Schedule Type" => "72:00:00",
                    "Scheduled Task State" => " date and time synchronization will be unavailable. If this service is disabled",
                    "Start Date" => "Weekly",
                    "Start In" => "N/A",
                    "Start Time" => "Scheduling data is not available in this format.",
                    "Status" => "Ready",
                    "Stop Task If Runs X Hours and X Mins" => "LOCAL SERVICE",
                    "Task To Run" => "%windir%\\system32\\sc.exe start w32time task_started"
               },

=cut

sub get_scheduled_task_info {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{scheduled_task_info} if $self->{scheduled_task_info};

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Attempt to retrieve scheduled task information
	my $command = $system32_path . '/schtasks.exe /Query /V /FO CSV';
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve scheduled task information");
		return;
	}
	elsif ($exit_status == 0) {
		#notify($ERRORS{'DEBUG'}, 0, "retrieved scheduled task information, output:\n" . join("\n", @$output));
		
		if (grep(/no scheduled tasks/i, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "there are no scheduled tasks on $computer_node_name, output:\n" . join("\n", @$output));
			return {};
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve scheduled task information, exit status: $exit_status\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my @properties;
	my $scheduled_task_info;
	for my $line (@$output) {
		
		# Split the line into an array and remove quotes from beginning and end of each value
		my @values = split(/\",\"/, $line);
		
		if (grep { $_ eq 'TaskName' } @values) {
			@properties = @values;
			next;
		}
		elsif (!@properties) {
			notify($ERRORS{'WARNING'}, 0, "unable to parse scheduled task info, column definition line containing 'TaskName' was not found before line: '$line'");
			return;
		}
		
		
		if (scalar(@properties) != scalar(@values)) {
			notify($ERRORS{'WARNING'}, 0, "property count (" . scalar(@properties) . ") does not equal value count (" . scalar(@values) . ")\nproperties line: '$line'\nvalues: '" . join(",", @values));
			next;
		}
		
		my $info;
		for (my $i=0; $i<scalar(@values); $i++) {
			$info->{$properties[$i]} = $values[$i];
		}
		
		my $task_name = $info->{TaskName};
		if (defined($task_name)) {
			$scheduled_task_info->{$task_name} = $info;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to determine scheduled task name from line: '$line', info:\n" . format_data($info));
		}
	}
	
	$self->{scheduled_task_info} = $scheduled_task_info;
	notify($ERRORS{'DEBUG'}, 0, "found " . scalar(keys %$scheduled_task_info) . " scheduled tasks");
	return $scheduled_task_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_dynamic_dns

 Parameters  : $interface (private or public or both)
 Returns     :
 Description :

=cut

sub enable_dynamic_dns {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $interface = shift;
	
	if (!defined($interface)) {
		notify($ERRORS{'OK'}, 0, "interface not specified for function enable_dynamic_dns defaulting to public interface");
		$interface = 'public'
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file enables dynamic DNS updates

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableDynamicUpdate"=dword:00000000

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableReverseAddressRegistrations"=dword:00000000
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "enabled dynamic dns");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable dynamic dns");
		return;
	}

	# Get the network configuration
	my $network_configuration = $self->get_network_configuration();
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	# Get the public and private interface names
	my $public_interface_name = $self->get_public_interface_name();
	my $private_interface_name = $self->get_private_interface_name();
	
	# Assemble netsh.exe commands to disable DNS registration
	my $netsh_command;
	
	if ($interface eq 'public') {
		$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
		$netsh_command .= " name = \"$public_interface_name\"";
		$netsh_command .= " source = dhcp";
		$netsh_command .= " register = both";
		$netsh_command .= " ;";
	}
	elsif ($interface eq 'private') {
		$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
		$netsh_command .= " name = \"$private_interface_name\"";
		$netsh_command .= " source = dhcp";
		$netsh_command .= " register = both";
		$netsh_command .= " ;";
	}
	else {
		$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
		$netsh_command .= " name = \"$public_interface_name\"";
		$netsh_command .= " source = dhcp";
		$netsh_command .= " register = both";
		$netsh_command .= " ;";
		
		$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
		$netsh_command .= " name = \"$private_interface_name\"";
		$netsh_command .= " source = dhcp";
		$netsh_command .= " register = both";
		$netsh_command .= " ;";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = run_ssh_command($computer_node_name, $management_node_keys, $netsh_command);
	if (defined($netsh_exit_status)  && $netsh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "enabled dynamic DNS registration on $interface adapters");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to enable dynamic DNS registration on $interface adapters, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to enable dynamic DNS registration on $interface adapters");
		return;
	}

	return 1;
} ## end sub enable_dynamic_dns

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_dynamic_dns

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_dynamic_dns {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

; This file disables dynamic DNS updates

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableDynamicUpdate"=dword:00000001

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters]
"DisableReverseAddressRegistrations"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled dynamic dns");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable dynamic dns");
		return;
	}

	# Get the network configuration
	my $network_configuration = $self->get_network_configuration();
	if (!$network_configuration) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve network configuration");
		return;
	}
	
	# Get the public and private interface names
	my $public_interface_name = $self->get_public_interface_name();
	my $private_interface_name = $self->get_private_interface_name();
	
	# Assemble netsh.exe commands to disable DNS registration
	my $netsh_command;
	$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
	$netsh_command .= " name = \"$public_interface_name\"";
	$netsh_command .= " source = dhcp";
	$netsh_command .= " register = none";
	$netsh_command .= " ;";
	
	$netsh_command .= "$system32_path/netsh.exe interface ip set dns";
	$netsh_command .= " name = \"$private_interface_name\"";
	$netsh_command .= " source = dhcp";
	$netsh_command .= " register = none";
	$netsh_command .= " ;";
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	if (defined($netsh_exit_status)  && $netsh_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "disabled dynamic DNS registration on public and private adapters");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable dynamic DNS registration on public and private adapters, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to disable dynamic DNS registration on public and private adapters");
		return;
	}

	return 1;
} ## end sub disable_dynamic_dns

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_netbios

 Parameters  :
 Returns     :
 Description :

=cut

sub disable_netbios {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Attempt to query the registry for the NetBT service parameters
	my $interface_registry_data = $self->reg_query('HKLM/SYSTEM/CurrentControlSet/Services/NetBT/Parameters/Interfaces');
	if (!$interface_registry_data) {
		notify($ERRORS{'WARNING'}, 0, "failed to query registry to determine NetBT network interface strings");
		return;
	}
	
	my @interface_keys = grep(/Tcpip_/i, keys %{$interface_registry_data});
	notify($ERRORS{'DEBUG'}, 0, "retrieved NetBT interface keys:\n" . join("\n", @interface_keys));
	
	for my $interface_key (@interface_keys) {
		my $netbios_options = $interface_registry_data->{$interface_key}{NetbiosOptions};
		
		if ($self->reg_add($interface_key, 'NetbiosOptions', 'REG_DWORD', 2)) {
			notify($ERRORS{'OK'}, 0, "disabled Netbios for interface: $interface_key");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to disabled Netbios for interface: $interface_key");
			return;
		}
	}

	return 1;
} ## end sub disable_netbios

#//////////////////////////////////////////////////////////////////////////////

=head2 set_computer_description

 Parameters  :
 Returns     :
 Description :

=cut

sub set_computer_description {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Attempt to get the description from the arguments
	my $description = shift;
	if (!$description) {
		my $image_name       = $self->data->get_image_name();
		my $image_prettyname = $self->data->get_image_prettyname();
		$description = "$image_prettyname ($image_name)";
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\LanmanServer\\Parameters]
"srvcomment"="$description"
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set computer description to '$description'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set computer description to '$description'");
		return 0;
	}
} ## end sub set_computer_description

#//////////////////////////////////////////////////////////////////////////////

=head2 set_my_computer_name

 Parameters  :
 Returns     :
 Description :

=cut

sub set_my_computer_name {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path        = $self->get_system32_path() || return;
	my $image_prettyname     = $self->data->get_image_prettyname();
	
	my $value = shift;
	$value = $image_prettyname if !$value;

	my $add_registry_command .= $system32_path . "/reg.exe add \"HKCR\\CLSID\\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\" /v LocalizedString /t REG_EXPAND_SZ /d \"$value\" /f";
	my ($add_registry_exit_status, $add_registry_output) = $self->execute($add_registry_command, 1);
	if (defined($add_registry_exit_status) && $add_registry_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "my computer name changed to '$value'");
	}
	elsif ($add_registry_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to change my computer name to '$value', exit status: $add_registry_exit_status, output:\n@{$add_registry_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to change my computer name to '$value'");
		return;
	}

	return 1;
} ## end sub set_my_computer_name

#//////////////////////////////////////////////////////////////////////////////

=head2 get_firewall_configuration

 Parameters  : $protocol (optional), $no_cache (optional)
 Returns     : hash reference
 Description : Retrieves information about the open firewall ports on the
               computer and constructs a hash. The hash keys are protocol names.
               Each protocol key contains a hash reference. The keys are either
               port numbers or ICMP types.
               
               By default, the firewall configuration is only retrieved from the
               computer the first time this subroutine is called. This data is
               then stored in $self->{firewall_configuration} as a cached copy.
               Subsequent calls return this cached copy by default. An optional
               $no_cache argument may be supplied to override this, forcing the
               firewall configuration to be retrieved from the computer again.
               
               Example:
               
                  "ICMP" => {
                    8 => {
                      "description" => "Allow inbound echo request"
                    }
                  },
                  "TCP" => {
                    22 => {
                      "interface_names" => [
                        "Local Area Connection 3"
                      ],
                      "name" => "sshd"
                    },
                    3389 => {
                      "name" => "Remote Desktop",
                      "scope" => "192.168.53.54/255.255.255.255"
                    },

=cut

sub get_firewall_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $protocol = shift || '*';
	
	my $no_cache = shift;
	
	if (!$no_cache && $self->{firewall_configuration}) {
		notify($ERRORS{'DEBUG'}, 0, "returning previously retrieved firewall configuration");
		return $self->{firewall_configuration};
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $network_configuration = $self->get_network_configuration() || return;
	
	my $firewall_configuration = {};
	
	# Retrieve the normal non-ICMP firewall configuration unless the protocol argument specifically requested ICMP only
	if ($protocol !~ /^icmp$/) {
		notify($ERRORS{'DEBUG'}, 0, "retrieving non-ICMP firewall configuration from $computer_node_name");
		
		my $port_command = "$system32_path/netsh.exe firewall show portopening verbose = ENABLE";
		my ($port_exit_status, $port_output) = $self->execute($port_command);
		if (!defined($port_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to show open firewall ports on $computer_node_name");
			return;
		}
		elsif (!grep(/Port\s+Protocol/i, @$port_output)) {
			notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to show open firewall ports on $computer_node_name, command: '$port_command', exit status: $port_exit_status, output:\n" . join("\n", @$port_output));
			return;
		}
		
		# Execute the netsh.exe command to retrieve firewall port openings
		# Expected output:
		# Port configuration for Local Area Connection 4:
		# Port   Protocol  Mode     Name
		# -------------------------------------------------------------------
		# 443    TCP       Disable  Secure Web Server (HTTPS)
		# 22     TCP       Disable  Cygwin SSHD
		
		my $configuration;
		my $previous_protocol;
		my $previous_port;
		for my $line (@$port_output) {
			if ($line =~ /^Port configuration for (.+):/ig) {
				$configuration = $1;
			}
			elsif ($line =~ /^(\d+)\s+(\w+)\s+(\w+)\s+(.*)/ig) {
				my $port = $1;
				my $protocol = $2;
				my $mode = $3;
				my $name = $4;
				
				$previous_protocol = $protocol;
				$previous_port = $port;
				
				next if ($mode !~ /enable/i);
				
				$firewall_configuration->{$protocol}{$port}{name}= $name;
				
				if ($configuration !~ /\w+ profile/i) {
					push @{$firewall_configuration->{$protocol}{$port}{interface_names}}, $configuration;
				}
			}
			elsif (!defined($previous_protocol) ||
					!defined($previous_port) ||
					!defined($firewall_configuration->{$previous_protocol}) ||
					!defined($firewall_configuration->{$previous_protocol}{$previous_port})
			) {
				next;
			}
			elsif (my ($scope) = $line =~ /Scope:\s+(.+)/ig) {
				$firewall_configuration->{$previous_protocol}{$previous_port}{scope} = $scope;
			}
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "skipping retrieval of non-ICMP firewall configuration from $computer_node_name, protocol argument is '$protocol'");
	}
	
	# Retrieve the ICMP firewall configuration if the protocol argument specifically requested ICMP only or no argument was supplied
	if ($protocol =~ /(icmp|\*)/) {
		notify($ERRORS{'DEBUG'}, 0, "retrieving ICMP firewall configuration from $computer_node_name");
		
		# Execute the netsh.exe ICMP command
		my $icmp_command = "$system32_path/netsh.exe firewall show icmpsetting verbose = ENABLE";
		my ($icmp_exit_status, $icmp_output) = $self->execute($icmp_command);
		if (!defined($icmp_output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run command to show firewall ICMP settings on $computer_node_name");
			return;
		}
		elsif (!grep(/Mode\s+Type/i, @$icmp_output)) {
			notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to show firewall ICMP settings on $computer_node_name, command: '$icmp_command', exit status: $icmp_exit_status, output:\n" . join("\n", @$icmp_output));
			return;
		}
		
		# ICMP configuration for Local Area Connection 4:
		# Mode     Type  Description
		# -------------------------------------------------------------------
		# Disable  3     Allow outbound destination unreachable
		# Disable  4     Allow outbound source quench
		
		my $configuration;
		for my $line (@$icmp_output) {
			if ($line =~ /^ICMP configuration for (.+):/ig) {
				$configuration = $1;
			}
			elsif ($line =~ /^(\w+)\s+(\d+)\s+(.*)/ig) {
				my $mode = $1;
				my $type = $2;
				my $description = $3;
				
				next if ($mode !~ /enable/i);
				
				$firewall_configuration->{ICMP}{$type}{description} = $description || '';
				
				if ($configuration !~ /\w+ profile/i) {
					push @{$firewall_configuration->{ICMP}{$type}{interface_names}}, $configuration;
				}
			}
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "skipping retrieval ICMP firewall configuration from $computer_node_name, protocol argument is '$protocol'");
	}
	
	$self->{firewall_configuration} = $firewall_configuration;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved firewall configuration from $computer_node_name:\n" . format_data($firewall_configuration));
	return $firewall_configuration;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 parse_firewall_scope

 Parameters  : @scope_strings
 Returns     : string
 Description : Parses an array of firewall scope strings and collpases them into
               a simplified scope if possible. A comma-separated string is
               returned. The scope string argument may be in the form:
                  -192.168.53.54/255.255.255.192
                  -192.168.53.54/24
                  -192.168.53.54
                  -*
                  -Any
                  -LocalSubnet

=cut

sub parse_firewall_scope {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @scope_strings = @_;
	if (!@scope_strings) {
		notify($ERRORS{'WARNING'}, 0, "scope array argument was not supplied");
		return;
	}
	
	my @netmask_objects;
	
	for my $scope_string (@scope_strings) {
		if ($scope_string =~ /(\*|Any)/i) {
			my $netmask_object = new Net::Netmask('any');
			push @netmask_objects, $netmask_object;
		}
		elsif ($scope_string =~ /LocalSubnet/i) {
			my $network_configuration = $self->get_network_configuration() || return;
			
			for my $interface_name (sort keys %$network_configuration) {
				for my $ip_address (keys %{$network_configuration->{$interface_name}{ip_address}}) {
					my $subnet_mask = $network_configuration->{$interface_name}{ip_address}{$ip_address};
					
					my $netmask_object = new Net::Netmask("$ip_address/$subnet_mask");
					if ($netmask_object) {
						push @netmask_objects, $netmask_object;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address, subnet mask: $subnet_mask");
						return;
					}
				}
			}
		}
		
		elsif (my @scope_sections = split(/,/, $scope_string)) {
			for my $scope_section (@scope_sections) {
				
				if (my ($start_address, $end_address) = $scope_section =~ /^([\d\.]+)-([\d\.]+)$/) {
					my @netmask_range_objects = Net::Netmask::range2cidrlist($start_address, $end_address);
					if (@netmask_range_objects) {
						push @netmask_objects, @netmask_range_objects;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to call Net::Netmask::range2cidrlist to create an array of objects covering IP range: $start_address-$end_address");
						return;
					}
				}
				
				elsif (my ($ip_address, $subnet_mask) = $scope_section =~ /^([\d\.]+)\/([\d\.]+)$/) {
					my $netmask_object = new Net::Netmask("$ip_address/$subnet_mask");
					if ($netmask_object) {
						push @netmask_objects, $netmask_object;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address, subnet mask: $subnet_mask");
						return;
					}
				}
				
				elsif (($ip_address) = $scope_section =~ /^([\d\.]+)$/) {
					my $netmask_object = new Net::Netmask("$ip_address");
					if ($netmask_object) {
						push @netmask_objects, $netmask_object;
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "failed to create Net::Netmask object, IP address: $ip_address");
						return;
					}
				}
				
				else {
					notify($ERRORS{'WARNING'}, 0, "unable to parse '$scope_section' section of scope: '$scope_string'");
					return;
				}
			}
		}
		
		else {
			notify($ERRORS{'WARNING'}, 0, "unexpected scope format: '$scope_string'");
			return;
		}
	}
	
	my @netmask_objects_collapsed = cidrs2cidrs(@netmask_objects);
	if (@netmask_objects_collapsed) {
		my $scope_result_string;
		my @ip_address_ranges;
		for my $netmask_object (@netmask_objects_collapsed) {
			if ($netmask_object->first() eq $netmask_object->last()) {
				push @ip_address_ranges, $netmask_object->first();
				$scope_result_string .= $netmask_object->base() . ",";
			}
			else {
				push @ip_address_ranges, $netmask_object->first() . "-" . $netmask_object->last();
				$scope_result_string .= $netmask_object->base() . "/" . $netmask_object->mask() . ",";
			}
		}
		
		$scope_result_string =~ s/,+$//;
		my $argument_string = join(",", @scope_strings);
		if ($argument_string ne $scope_result_string) {
			notify($ERRORS{'DEBUG'}, 0, "parsed firewall scope:\n" .
				"argument: '$argument_string'\n" .
				"result: '$scope_result_string'\n" .
				"IP address ranges:\n" . join(", ", @ip_address_ranges)
			);
		}
		return $scope_result_string;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope: '" . join(",", @scope_strings) . "', no Net::Netmask objects were created");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_firewall_port

 Parameters  : $protocol, $port, $scope (optional), $overwrite_existing (optional), $name (optional), $description (optional)
 Returns     : 1 if succeeded, 0 otherwise
 Description : Enables a firewall port on the computer. The protocol and port
               arguments are required. An optional scope argument may supplied.
               A boolean overwrite existing may be supplied following the scope
               argument. The default is false. If false, the existing firewall
               configuration will be retrieved. If an exception already exists
               for the given protocol and port, the existing and new scopes will
               be joined. If set to true, any existing exception matching the
               protocol and port will be removed and a new exception added.

=cut

sub enable_firewall_port {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($protocol, $port, $scope_argument, $overwrite_existing, $name, $description) = @_;
	if (!defined($protocol) || !defined($port)) {
		notify($ERRORS{'WARNING'}, 0, "protocol and port arguments were not supplied");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Make sure the protocol is uppercase
	$protocol = uc($protocol);
	
	$scope_argument = '*' if (!defined($scope_argument));
	my $parsed_scope_argument = $self->parse_firewall_scope($scope_argument);
	if (!$parsed_scope_argument) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse firewall scope argument: '$scope_argument'");
		return;
	}
	$scope_argument = $parsed_scope_argument;
	
	my $new_scope;
	
	my $firewall_configuration;
	if (!$overwrite_existing) {
		# Need to append to firewall, retrieve current configuration
		$firewall_configuration = $self->get_firewall_configuration($protocol) || return;
		my $existing_scope = $firewall_configuration->{$protocol}{$port}{scope};
		my $existing_name = $firewall_configuration->{$protocol}{$port}{name} || '';
		
		# Check if an exception already exists for the protocol/port
		if ($existing_scope) {
			# Exception already exists, parse it
			my $parsed_existing_scope = $self->parse_firewall_scope($existing_scope);
			if (!$parsed_existing_scope) {
				notify($ERRORS{'WARNING'}, 0, "failed to parse existing firewall scope: '$existing_scope'");
				return;
			}
			$existing_scope = $parsed_existing_scope;
			
			$new_scope = $self->parse_firewall_scope("$existing_scope,$scope_argument");
			if (!$new_scope) {
				notify($ERRORS{'WARNING'}, 0, "failed to parse new firewall scope: '$existing_scope,$scope_argument'");
				return;
			}
			
			# Check if existing exception scope matches the scope argument
			if ($new_scope eq $existing_scope) {
				notify($ERRORS{'DEBUG'}, 0, "firewall is already open on $computer_node_name, existing scope includes scope argument:\n" .
					"existing name: '$existing_name'\n" .
					"protocol: $protocol\n" .
					"port/type: $port\n" .
					"existing argument: $existing_scope\n" .
					"scope argument: $scope_argument\n" .
					"overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
				);
				return 1;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "firewall is already open on $computer_node_name, existing scope does NOT include scope argument:\n" .
					"existing name: '$existing_name'\n" .
					"protocol: $protocol\n" .
					"port/type: $port\n" .
					"existing scope: $existing_scope\n" .
					"scope argument: $scope_argument\n" .
					"new scope: $new_scope\n" .
					"overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
				);
			}
		}
		else {
			$new_scope = $scope_argument;
			notify($ERRORS{'DEBUG'}, 0, "firewall exception does not already exist on $computer_node_name:\n" .
				"protocol: $protocol\n" .
				"port/type: $port\n" .
				"scope: $new_scope\n" .
				"overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
			);
		}
	}
	else {
		$new_scope = $scope_argument;
		notify($ERRORS{'DEBUG'}, 0, "configuring firewall exception on $computer_node_name:\n" .
			"protocol: $protocol\n" .
			"port/type: $port\n" .
			"scope: $new_scope\n" .
			"overwrite existing rule: " . ($overwrite_existing ? 'yes' : 'no')
		);
	}
	
	# Make sure the scope was figured out before proceeding
	if (!$new_scope) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall exception on $computer_node_name, scope could not be determined");
		return;
	}
	
	# Construct a name and description if arguments were not supplied
	$name = "VCL: allow $protocol/$port from $new_scope" if !$name;
	$description = "VCL: allow $protocol/$port from $new_scope" if !$description;
	$name = substr($name, 0, 60) . "..." if length($name) > 60;
	
	# Call the helper subroutine, this runs the appropriate netsh commands based on the version of Windows
	if ($self->_enable_firewall_port_helper($protocol, $port, $new_scope, $overwrite_existing, $name, $description)) {
		# Update the stored firewall configuration info if it was retrieved
		if ($firewall_configuration) {
			$firewall_configuration->{$protocol}{$port} = {
				name => $name,
				name => $description,
				scope => $new_scope,
			};
		}
		return 1;
	}
	else {
		return;
	}
}
	
#//////////////////////////////////////////////////////////////////////////////

=head2 _enable_firewall_port_helper

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub _enable_firewall_port_helper {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($protocol, $port, $scope, $overwrite_existing, $name, $description) = @_;
	if (!defined($protocol) || !defined($port) || !defined($scope) || !defined($name)) {
		notify($ERRORS{'WARNING'}, 0, "protocol and port arguments were not supplied");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	if ($protocol =~ /icmp/i) {
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = $port";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " profile = ALL";
	}
	else {
		if ($overwrite_existing) {
			# Get the firewall configuration and check if an exception has been configured on an interface
			my $firewall_configuration = $self->get_firewall_configuration($protocol) || return;
			if (defined($firewall_configuration->{$protocol}{$port}{interface_names})) {
				for my $interface_name (@{$firewall_configuration->{$protocol}{$port}{interface_names}}) {
					notify($ERRORS{'DEBUG'}, 0, "removing existing firewall exception:\n" .
						"protocol: $protocol\n" .
						"port: $port\n" .
						"interface: $interface_name"
					);
					
					$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
					$netsh_command .= " protocol = $protocol";
					$netsh_command .= " port = $port";
					$netsh_command .= " interface = \"$interface_name\"";
					$netsh_command .= " ; ";
				}
			}
		}
		
		$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
		$netsh_command .= " name = \"$name\"";
		$netsh_command .= " protocol = $protocol";
		$netsh_command .= " port = $port";
		$netsh_command .= " mode = ENABLE";
	}
	
	if ($scope eq '0.0.0.0/0.0.0.0') {
		$netsh_command .= " scope = ALL";
	}
	else {
		$netsh_command .= " scope = CUSTOM";
		$netsh_command .= " addresses = $scope";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	if (!defined($netsh_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to open firewall on $computer_node_name, command: '$netsh_command'");
		return;
	}
	elsif (@$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "opened firewall on $computer_node_name:\n" .
				"name: '$name'\n" .
				"protocol: $protocol\n" .
				"port/type: $port\n" .
				"scope: $scope"
		);
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open firewall on $computer_node_name:\n" .
			"name: '$name'\n" .
			"protocol: $protocol\n" .
			"port/type: $port\n" .
			"command : '$netsh_command'\n" .
			"exit status: $netsh_exit_status\n" .
			"output:\n" . join("\n", @$netsh_output)
		);
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
	$netsh_command .= " type = 8";
	$netsh_command .= " mode = ENABLE";
	$netsh_command .= " profile = ALL";

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow ping");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow ping, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow ping");
		return;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ping_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ping_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable ping on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "ping will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "ping will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable ping on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "ping will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, ping will be enabled for all profiles");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow ping on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow ping on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow ping on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ping_private

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_ping

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_ping {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Get the private interface name
	# Add command to disable ping on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved private interface name: $private_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined");
	}
	
	# Get the public interface name
	# Add command to disable ping on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved public interface name: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
		$netsh_command .= " type = 8";
		$netsh_command .= " mode = DISABLE";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "public interface name could not be determined");
	}
	
	# Add command to disable ping for all profiles
	$netsh_command .= "$system32_path/netsh.exe firewall set icmpsetting";
	$netsh_command .= " type = 8";
	$netsh_command .= " mode = DISABLE";
	$netsh_command .= " profile = ALL";
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow ping");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to disallow ping, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to disallow ping");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if the remote IP was passed correctly as an argument
	my $remote_ip = shift;
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable SSH on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to disable SSH on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on private interface: $private_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on private interface because private interface name could not be determined");
	}
	
	$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
	$netsh_command .= " name = \"Cygwin SSHD\"";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 22";
	$netsh_command .= " mode = ENABLE";
	
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'all addresses'; # Set only to display in output
		$netsh_command .= " scope = ALL";
	}
	else {
		$netsh_command .= " scope = CUSTOM";
		$netsh_command .= " addresses = $remote_ip";
	}

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow SSH from $remote_ip");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow SSH from $remote_ip, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow SSH from $remote_ip");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_ssh_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_ssh_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Get the public interface name
	# Add command to disable SSH on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "SSH will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable SSH on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "SSH will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Cygwin SSHD\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, SSH will be enabled for all profiles");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Cygwin SSHD\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 22";
		$netsh_command .= " profile = ALL";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow SSH on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow SSH on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow SSH on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Check if the remote IP was passed correctly as an argument
	my $remote_ip = shift;
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Set the key to allow remote connections whenever enabling RDP
	# Include this in the SSH command along with the netsh.exe commands rather than calling it separately for faster execution
	$netsh_command .= $system32_path . '/reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /t REG_DWORD /v fDenyTSConnections /d 0 /f ; ';
	
	$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
	$netsh_command .= " name = \"Remote Desktop\"";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 3389";
	$netsh_command .= " mode = ENABLE";
	
	if (!defined($remote_ip) || $remote_ip !~ /[\d\.\/]/) {
		$remote_ip = 'all addresses'; # Set only to display in output
		$netsh_command .= " scope = ALL";
	}
	else {
		$netsh_command .= " scope = CUSTOM";
		$netsh_command .= " addresses = $remote_ip";
	}

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow RDP from $remote_ip");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow RDP from $remote_ip, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow RDP from $remote_ip");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_rdp

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_rdp_private

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_rdp_private {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Set the key to allow remote connections whenever enabling RDP
	# Include this in the SSH command along with the netsh.exe commands rather than calling it separately for faster execution
	$netsh_command .= $system32_path . '/reg.exe ADD "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server" /t REG_DWORD /v fDenyTSConnections /d 0 /f ; ';
	
	# Get the public interface name
	# Add command to disable RDP on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "RDP will not be disabled on public interface because public interface name could not be determined");
	}
	
	# Get the private interface name
	# Add command to ensable RDP on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be enabled on private interface: $private_interface_name");
		
		$netsh_command .= "netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " profile = ALL";
		$netsh_command .= ' ;';
		
		$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Remote Desktop\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " mode = ENABLE";
		$netsh_command .= " interface = \"$private_interface_name\"";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined, RDP will be enabled for all profiles");
		
		$netsh_command .= "$system32_path/netsh.exe firewall set portopening";
		$netsh_command .= " name = \"Remote Desktop\"";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " profile = ALL";
	}
	
	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to allow RDP on private interface");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow RDP on private interface, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to allow RDP on private interface");
		return;
	}
	
	return 1;
} ## end sub firewall_enable_ssh_private

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_disable_rdp

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_disable_rdp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $netsh_command;
	
	# Get the private interface name
	# Add command to disable RDP on private interface if its name is found
	my $private_interface_name = $self->get_private_interface_name();
	if ($private_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on private interface: $private_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$private_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "private interface name could not be determined");
	}
	
	# Get the public interface name
	# Add command to disable RDP on public interface if its name is found
	my $public_interface_name = $self->get_public_interface_name();
	if ($public_interface_name) {
		notify($ERRORS{'DEBUG'}, 0, "RDP will be disabled on public interface: $public_interface_name");
		
		$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
		$netsh_command .= " protocol = TCP";
		$netsh_command .= " port = 3389";
		$netsh_command .= " interface = \"$public_interface_name\"";
		$netsh_command .= ' ;';
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "public interface name could not be determined");
	}
	
	# Add command to disable RDP for all profiles
	$netsh_command .= "$system32_path/netsh.exe firewall delete portopening";
	$netsh_command .= " protocol = TCP";
	$netsh_command .= " port = 3389";
	$netsh_command .= " profile = ALL";

	# Execute the netsh.exe command
	my ($netsh_exit_status, $netsh_output) = $self->execute($netsh_command);
	
	if (defined($netsh_output)  && @$netsh_output[-1] =~ /(Ok|The object already exists)/i) {
		notify($ERRORS{'OK'}, 0, "configured firewall to disallow RDP");
	}
	elsif (defined($netsh_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to disallow RDP, exit status: $netsh_exit_status, output:\n@{$netsh_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to configure firewall to disallow RDP");
		return;
	}
	
	return 1;
} ## end sub firewall_disable_rdp

#//////////////////////////////////////////////////////////////////////////////

=head2 get_network_configuration

 Parameters  : $no_cache (optional)
 Returns     :
 Description : Retrieves the network configuration from the computer. Returns
               a hash. The hash keys are the interface names:
					$hash{<interface name>}{dhcp_enabled}
					$hash{<interface name>}{description}
					$hash{<interface name>}{ip_address}
					$hash{<interface name>}{subnet_mask}
					$hash{<interface name>}{default_gateway}
					
					The hash also contains 2 keys containing the names of the
					public and private interfaces:
					$hash{public_name}
					$hash{private_name}

=cut

sub get_network_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift;
	
	if ($no_cache) {
		delete $self->{network_configuration};
	}
	elsif ($self->{network_configuration}) {
		notify($ERRORS{'DEBUG'}, 0, "returning network configuration previously retrieved");
		return $self->{network_configuration};
	}
	
	my $system32_path = $self->get_system32_path();
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve network configuration from $computer_node_name");
	
	# Get the computer private IP address
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();
	if (!$computer_private_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "unable to retrieve computer private IP address from reservation data");
		return;
	}
	
	my $network_configuration;
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve network configuration information from $computer_node_name");
	
	# Run ipconfig /all, try twice in case it fails the first time
	my $ipconfig_attempt = 0;
	my $ipconfig_attempt_limit = 2;
	my $ipconfig_attempt_delay = 5;
	
	my $ipconfig_command = $system32_path . '/ipconfig.exe /all';
	my ($ipconfig_exit_status, $ipconfig_output);
	
	IPCONFIG_ATTEMPT: while (++$ipconfig_attempt) {
		
		
		($ipconfig_exit_status, $ipconfig_output) = $self->execute($ipconfig_command, 0);
		if (!defined($ipconfig_output)) {
			notify($ERRORS{'WARNING'}, 0, "attempt $ipconfig_attempt: failed to run the SSH command to run ipconfig");
		}
		elsif (grep(/Subnet Mask/i, @$ipconfig_output)) {
			# Make sure output was returned
			notify($ERRORS{'DEBUG'}, 0, "ran ipconfig on $computer_node_name:\n" . join("\n", @$ipconfig_output));
			last;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "attempt $ipconfig_attempt: failed to run ipconfig, exit status: $ipconfig_exit_status, output:\n" . join("\n", @$ipconfig_output));
		}
		
		
		if ($ipconfig_attempt >= $ipconfig_attempt_limit) {
			notify($ERRORS{'WARNING'}, 0, "failed to get network configuration, made $ipconfig_attempt attempts to run ipconfig");
			return;
		}
		
		sleep $ipconfig_attempt_delay;
	}

	my $interface_name;
	my $previous_ip = 0;
	my $setting;
	
	for my $line (@{$ipconfig_output}) {
		# Find beginning of interface section
		if ($line =~ /\A[^\s].*adapter (.*):\s*\Z/i) {
			# Get the interface name
			$interface_name = $1;
			if (defined($network_configuration->{$interface_name})) {
				notify($ERRORS{'WARNING'}, 0, "interface with same name has already been found: $interface_name\n" . format_data($network_configuration->{$interface_name}));
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "found interface: $interface_name");
			}
			next;
		}
		
		# Skip line if interface hasn't been found yet
		next if !$interface_name;
		
		# Take apart the line finding the setting name and value with a hideous regex
		my ($line_setting, $value) = $line =~ /^[ ]{1,8}(\w[^\.]*\w)?[ \.:]+([^\r\n]*)/i;
		
		# If the setting was found in the line, use it
		# Otherwise, use the last found setting
		$setting = $line_setting if $line_setting;
		
		# Skip line if value wasn't found
		next if !$value;
		
		# Normalize the setting format, make it lowercase, convert dashes and spaces to underscores
		$setting = lc($setting);
		$setting =~ s/[ -]/_/g;
		
		# Windows 6.x includes a version indicator in IP address lines such as IPv4, remove this
		$setting =~ s/ip(v\d)?_address/ip_address/;
		
		# Autoconfiguration ip address will be displayed as "Autoconfiguration IP Address. . . : 169.x.x.x"
		$setting =~ s/autoconfiguration_ip/ip/;
		
		# Check which setting was found and add to hash
		if ($setting =~ /dns_servers/) {
			push(@{$network_configuration->{$interface_name}{$setting}}, $value);
			notify($ERRORS{'OK'}, 0, "$interface_name:$setting\n" . format_data($network_configuration->{$interface_name}{$setting}));
		}
		elsif ($setting =~ /ip_address/) {
			$value =~ s/[^\.\d]//g;
			$network_configuration->{$interface_name}{$setting}{$value} = '';
			$previous_ip = $value;
		}
		elsif ($setting =~ /subnet_mask/) {
			$network_configuration->{$interface_name}{ip_address}{$previous_ip} = $value;
		}
		elsif ($setting =~ /physical_address/) {
			# Change '-' characters in MAC address to ':' to be consistent with Linux
			$value =~ s/-/:/g;
			$network_configuration->{$interface_name}{physical_address} = $value;
		}
		elsif ($setting) {
			$network_configuration->{$interface_name}{$setting} = $value;
		}
	}
	
	$self->{network_configuration} = $network_configuration;
	
	# Can produce large output, if you need to monitor the configuration setting uncomment the below output statement
	#notify($ERRORS{'DEBUG'}, 0, "retrieved network configuration:\n" . format_data($self->{network_configuration}));
	return $self->{network_configuration};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_dhcp

 Parameters  : 
 Returns     :
 Description : 

=cut

sub enable_dhcp {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $interface_name = shift;
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	elsif ($interface_name =~ /^public$/i) {
		$interface_name = $self->get_public_interface_name() || return;
	}
	elsif ($interface_name =~ /^private$/i) {
		$interface_name = $self->get_private_interface_name() || return;
	}
	
	if ($self->is_dhcp_enabled($interface_name)) {
		notify($ERRORS{'DEBUG'}, 0, "DHCP is already enabled on interface '$interface_name'");
		return 1;
	}
	
	# Delete cached network configuration information so it is retrieved next time it is needed
	delete $self->{network_configuration};
	
	# Use netsh.exe to set the NIC to use DHCP
	my $set_dhcp_command;
	$set_dhcp_command .= "$system32_path/ipconfig.exe /release \"$interface_name\" 2>NUL";
	$set_dhcp_command .= " ; $system32_path/netsh.exe interface ip set address name=\"$interface_name\" source=dhcp 2>&1";
	$set_dhcp_command .= " ; $system32_path/netsh.exe interface ip set dns name=\"$interface_name\" source=dhcp register=none 2>&1";
	$set_dhcp_command .= " ; $system32_path/ipconfig.exe /renew \"$interface_name\"";
	
	# Just execute the command, SSH connection may be terminated while running it
	$self->execute({command => $set_dhcp_command, display_output => 1, timeout => 90, ignore_error => 1});
	
	my $wait_message = "waiting for DHCP to be enabled on $interface_name";
	if ($self->code_loop_timeout(\&is_dhcp_enabled, [$self, $interface_name], $wait_message, 65, 5)) {
		notify($ERRORS{'DEBUG'}, 0, "enabled DHCP on interface '$interface_name'");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable DHCP on interface '$interface_name'");
		return;
	}
} ## end sub enable_dhcp

#//////////////////////////////////////////////////////////////////////////////

=head2 is_dhcp_enabled

 Parameters  : $interface_name
 Returns     : 0, 1, or undefined
 Description : Determines if DHCP is enabled on the interface.

=cut

sub is_dhcp_enabled {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $interface_name = shift;
	if (!$interface_name) {
		notify($ERRORS{'WARNING'}, 0, "interface name argument was not supplied");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $show_dhcp_command = "$system32_path/netsh.exe interface ip show address name=\"$interface_name\"";
	my ($show_dhcp_status, $show_dhcp_output) = $self->execute($show_dhcp_command);
	if (!defined($show_dhcp_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if DHCP is enabled on interface '$interface_name'");
		return;
	}
	elsif (grep(/DHCP enabled.*yes/i, @$show_dhcp_output)) {
		notify($ERRORS{'DEBUG'}, 0, "DHCP is enabled on interface '$interface_name'");
		return 1;
	}
	elsif (grep(/DHCP enabled.*no/i, @$show_dhcp_output)) {
		notify($ERRORS{'DEBUG'}, 0, "DHCP is NOT enabled on interface '$interface_name'");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if DHCP is enabled on interface '$interface_name', command: $show_dhcp_command, output:\n" . join("\n", @$show_dhcp_output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ipconfig_renew

 Parameters  : 
 Returns     :
 Description : 

=cut

sub ipconfig_renew {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Delete cached network configuration information
	delete $self->{network_configuration};
	delete $self->{public_interface_name};
	delete $self->{private_interface_name};
	
	# Assemble the ipconfig command, include the interface name if argument was specified
	my $ipconfig_command = "$system32_path/ipconfig.exe /renew";
	notify($ERRORS{'OK'}, 0, "attempting to renew IP configuration");
	my ($ipconfig_status, $ipconfig_output) = $self->execute({
		command => $ipconfig_command,
		timeout => 65,
		max_attempts => 1,
		ignore_error => 1
	});
	
	if (!defined($ipconfig_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to renew IP configuration");
		return;
	}
	elsif ($ipconfig_status ne 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to renew IP configuration, exit status: $ipconfig_status, output:\n" . join("\n", @$ipconfig_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "renewed IP configuration, output:\n" . join("\n", @$ipconfig_output));
		return 1;
	}
}
	
#//////////////////////////////////////////////////////////////////////////////

=head2 delete_capture_configuration_files

 Parameters  : 
 Returns     :
 Description : Deletes the capture configuration directory.

=cut

sub delete_capture_configuration_files {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;

	# Delete VCL scheduled task if it exists
	$self->delete_scheduled_task('VCL Startup Configuration');
	
	# Remove existing configuration files if they exist
	notify($ERRORS{'OK'}, 0, "attempting to remove old configuration directory if it exists: $NODE_CONFIGURATION_DIRECTORY");
	if (!$self->delete_file($NODE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing configuration directory: $NODE_CONFIGURATION_DIRECTORY");
		return 0;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_group_policy_script_info

 Parameters  : none
 Returns     : hash reference
 Description : Parses the script.ini file and constructs a hash reference:
               {
                 "logoff" => {
                   0 => {
                     "cmdline" => "C:\\logoff.cmd",
                     "parameters" => ">> C:\\logoff.log"
                   },
                   1 => {
                     "cmdline" => "logoff2.cmd",
                     "parameters" => ""
                   },
                 },
                 "logon" => {
                   0 => {
                     "cmdline" => "logon.cmd",
                     "parameters" => ""
                   }
                 }
               }

=cut

sub get_user_group_policy_script_info {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $scripts_ini_file_path = "$system32_path/GroupPolicy/User/Scripts/scripts.ini";
	
	my @lines;
	if ($self->file_exists($scripts_ini_file_path)) {
		@lines = $self->get_file_contents($scripts_ini_file_path);
		notify($ERRORS{'DEBUG'}, 0, "retrieved contents of scripts.ini:\n" . join("\n", @lines));
	}
	
	# Format of scripts.ini
	#     <--- BLANK FIRST LINE
	# [Logon]
	# 0CmdLine=logon.cmd
	# 0Parameters=>> C:\logon.log
	# 1CmdLine=logon1.cmd
	# 1Parameters=
	# [Logoff]
	# 0CmdLine=C:\logoff.cmd
	# 0Parameters=>> C:\logoff.log
	
	my $info = {
		'logon' => {},
		'logoff' => {},
	};
	
	my $current_stage;
	for my $line (@lines) {
		# Ignore blank lines
		next unless $line =~ /\w/;
		
		# Remove Unicode nul and special characters added to beginning of file
		$line =~ s/(\x00|\xFE|\xFF)//g;
		
		# Find script stage section heading: [Logon] or [Logoff]
		if ($line =~ /\[(logon|logoff)\]/i) {
			$current_stage = lc($1);
			next;
		}
		
		# Parse the line, format should be either:
		# 0CmdLine=logon.cmd
		# 0Parameters=>> C:\logon.log
		my ($index, $property, $value) = $line =~ /^\s*(\d+)(\w+)=(.*)$/;
		if (!defined($index)) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse scripts.ini, unable to parse line: '$line'\n" . join("\n", @lines));
			return;
		}
		
		$property = lc($property);
		
		if (defined($info->{$current_stage}{$index}{$property})) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse scripts.ini, multiple [$current_stage] '$property' lines exist for index $index:\n" . join("\n", @lines));
			return;
		}
		
		$info->{$current_stage}{$index}{$property} = $value;
	}
	
	# Guarantee each script index has both a CmdLine and Parameters entry
	for my $check_stage (keys %$info) {
		for my $index (keys %{$info->{$check_stage}}) {
			$info->{$check_stage}{$index}{'cmdline'} = '' unless defined($info->{$check_stage}{$index}{'cmdline'});
			$info->{$check_stage}{$index}{'parameters'} = '' unless defined($info->{$check_stage}{$index}{'parameters'});
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved user group policy info:\n" . format_data($info));
	return $info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 add_user_group_policy_script

 Parameters  : $stage_argument, $cmdline_argument, $parameters_argument
 Returns     : boolean
 Description : Adds a traditional (non-Powershell) user group policy script to
               the computer to be automatically executed at logon or logoff. The
               stage argument must either be 'logon' or 'logoff'.

=cut

sub add_user_group_policy_script {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my ($stage_argument, $cmdline_argument, $parameters_argument) = @_;
	if (!$stage_argument) {
		notify($ERRORS{'WARNING'}, 0, "stage (logon/logoff) argument was not specified");
		return;
	}
	elsif (!$stage_argument || $stage_argument !~ /^(logon|logoff)$/i) {
		notify($ERRORS{'WARNING'}, 0, "stage argument is not valid: $stage_argument, it must be 'logon' or 'logoff'");
		return;
	}
	elsif (!$cmdline_argument) {
		notify($ERRORS{'WARNING'}, 0, "CmdLine argument was not specified");
		return;
	}
	
	# Use lower case for all comparisons
	$stage_argument = lc($stage_argument);
	
	# Replace slashes with double backslashes
	$cmdline_argument =~ s/[\\\/]+/\\/g;
	my $cmdline_argument_escaped = quotemeta($cmdline_argument);
	
	# Construct a hash which will be inserted into the scripts.ini info hash
	my $script_argument = {
		'cmdline' => $cmdline_argument,
		'parameters' => $parameters_argument,
	};
	
	# Path to scripts.ini file
	my $scripts_ini_directory_path = "$system32_path/GroupPolicy/User/Scripts";
	my $scripts_ini_file_path = "$scripts_ini_directory_path/scripts.ini";
	
	my $info = $self->get_user_group_policy_script_info() || return;
	
	# Figure out the index to use
	# Check if a script exists with an idential command line
	my $add_index;
	for my $index (sort {$a <=> $b} keys %{$info->{$stage_argument}}) {
		my $cmdline = $info->{$stage_argument}{$index}{cmdline};
		my $cmdline_escaped = quotemeta($cmdline);
		
		if (lc($cmdline_escaped) eq lc($cmdline_argument_escaped)) {
			$add_index = $index;
			notify($ERRORS{'DEBUG'}, 0, "replacing existing $stage_argument script at index $add_index:\n" .
				"existing script:\n" . format_data($info->{$stage_argument}{$index}) . "\n" .
				"argument:\n" . format_data($script_argument)
			);
			last;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "command line of existing $stage_argument script at index $index does not match argument:\n" .
				"existing: '$cmdline_escaped'\n" .
				"argument: '$cmdline_argument_escaped'"
			);
		}
	}
	if (!defined($add_index)) {
		# Existing matching script not found, add to end
		$add_index = scalar keys %{$info->{$stage_argument}};
		notify($ERRORS{'DEBUG'}, 0, "existing $stage_argument script was not found with command line matching argument, script will be added with index $add_index");
	}
	
	# Add or replace the script defined by the arguments
	$info->{$stage_argument}{$add_index} = $script_argument;
	notify($ERRORS{'DEBUG'}, 0, "updated scripts.ini content:\n" . format_data($info));
	
	# Assemble the updated scripts.ini content
	my $updated_contents;
	for my $stage ('logon', 'logoff') {
		# Capitalize the first letter and add it to the contents
		my $stage_uc = ucfirst($stage);
		$updated_contents .= "[$stage_uc]\n";
		
		for my $index (sort {$a <=> $b} keys %{$info->{$stage}}) {
			my $script = $info->{$stage}{$index};
			$updated_contents .= $index . "CmdLine=" . $script->{cmdline} . "\n";
			$updated_contents .= $index . "Parameters=" . $script->{parameters} . "\n";
		}
	}
	notify($ERRORS{'DEBUG'}, 0, "updated $scripts_ini_file_path contents:\n$updated_contents");
	return $self->create_text_file($scripts_ini_file_path, $updated_contents);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 remove_user_group_policy_script

 Parameters  : $stage_argument, $cmdline_argument
 Returns     : boolean
 Description : Removes a traditional (non-Powershell) user logon or logoff
               script group policy from the computer. The stage argument must
               either be 'logon' or 'logoff'.

=cut

sub remove_user_group_policy_script {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get the arguments
	my ($stage_argument, $cmdline_argument, $parameters_argument) = @_;
	if (!$stage_argument) {
		notify($ERRORS{'WARNING'}, 0, "stage (logon/logoff) argument was not specified");
		return;
	}
	elsif (!$stage_argument || $stage_argument !~ /^(logon|logoff)$/i) {
		notify($ERRORS{'WARNING'}, 0, "stage argument is not valid: $stage_argument, it must be 'logon' or 'logoff'");
		return;
	}
	elsif (!$cmdline_argument) {
		notify($ERRORS{'WARNING'}, 0, "CmdLine argument was not specified");
		return;
	}
	
	# Use lower case for all comparisons
	$stage_argument = lc($stage_argument);
	
	# Replace slashes with double backslashes
	$cmdline_argument =~ s/[\\\/]+/\\/g;
	my $cmdline_argument_escaped = quotemeta($cmdline_argument);
	
	# Extract the last part of the command line if a full path was specified
	my ($cmdline_argument_executable) = $cmdline_argument =~ /([^\\]+)$/;
	
	# Path to scripts.ini file
	my $scripts_ini_directory_path = "$system32_path/GroupPolicy/User/Scripts";
	my $scripts_ini_file_path = "$scripts_ini_directory_path/scripts.ini";
	
	my $info = $self->get_user_group_policy_script_info() || return;
	
	# Attempt to delete batch or script files specified by the argument
	if ($cmdline_argument =~ /\\/) {
		$self->delete_file($cmdline_argument);
	}
	else {
		$self->delete_files_by_pattern("$system32_path/GroupPolicy/User/Scripts", ".*$cmdline_argument.*", 2);
	}
	
	# Find matching scripts, delete from hash if found
	my $found_match = 0;
	for my $index (sort {$a <=> $b} keys %{$info->{$stage_argument}}) {
		my $cmdline = $info->{$stage_argument}{$index}{cmdline};
		my $cmdline_escaped = quotemeta($cmdline);
		
		# Extract the last part of the command line if it contains a full path
		my ($cmdline_executable) = $cmdline =~ /([^\\]+)$/;
		
		if (lc($cmdline_escaped) eq lc($cmdline_argument_escaped)) {
			$found_match = 1;
			notify($ERRORS{'DEBUG'}, 0, "existing command line matches argument, removing $stage_argument script at index $index:\n" .
				"argument: $cmdline_argument\n" .
				"existing script:\n" . format_data($info->{$stage_argument}{$index})
			);
			delete $info->{$stage_argument}{$index};
			next;
		}
		elsif ($cmdline_argument_executable && $cmdline_executable && lc($cmdline_argument_executable) eq lc($cmdline_executable)) {
			$found_match = 1;
			notify($ERRORS{'DEBUG'}, 0, "existing command line executable matches argument executable, removing $stage_argument script at index $index:\n" .
				"argument: $cmdline_argument\n" .
				"argument executable: $cmdline_argument_executable\n" .
				"existing script:\n" . format_data($info->{$stage_argument}{$index})
			);
			delete $info->{$stage_argument}{$index};
			next;
		}
	}
	
	if (!$found_match) {
		notify($ERRORS{'DEBUG'}, 0, "scripts.ini update not necessary, did not find existing script matching command line argument: $cmdline_argument");
		return 1;
	}
	
	# Assemble the updated scripts.ini content
	my $updated_contents;
	for my $stage ('logon', 'logoff') {
		# Capitalize the first letter and add it to the contents
		my $stage_uc = ucfirst($stage);
		$updated_contents .= "[$stage_uc]\n";
		
		# Reindex in case there are now gaps
		my $new_index = 0;
		for my $original_index (sort {$a <=> $b} keys %{$info->{$stage}}) {
			my $script = $info->{$stage}{$original_index};
			$updated_contents .= $new_index . "CmdLine=" . $script->{cmdline} . "\n";
			$updated_contents .= $new_index . "Parameters=" . $script->{parameters} . "\n";
			$new_index++;
		}
	}
	notify($ERRORS{'DEBUG'}, 0, "updated $scripts_ini_file_path contents:\n$updated_contents");
	return $self->create_text_file($scripts_ini_file_path, $updated_contents);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_gpupdate

 Parameters  : 
 Returns     :
 Description : 

=cut

sub run_gpupdate {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $gpupdate_command = "cmd.exe /c $system32_path/gpupdate.exe /Force";
	my ($gpupdate_status, $gpupdate_output) = $self->execute($gpupdate_command);
	if (defined($gpupdate_output) && !grep(/error/i, @{$gpupdate_output})) {
		notify($ERRORS{'OK'}, 0, "ran gpupdate /force");
	}
	elsif (defined($gpupdate_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run gpupdate /force, exit status: $gpupdate_status, output:\n@{$gpupdate_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run gpupdate /force");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 fix_cygwin_nodosfilewarning

 Parameters  : none
 Returns     : boolean
 Description : Cygwin will include a warning message in the output of a command
               such as sed.exe or grep.exe which uses a DOS-style file path.
               This warning is only displayed the first time this is
               encountered, and not for subsequent commands. The extra warning
               output can cause problems for other subroutines which parse the
               output. This subroutine intentionally attempts to trigger the
               warning so that it does not appear in the output for other
               subroutines.

=cut

sub fix_cygwin_nodosfilewarning {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Run useless command with the goal of triggering Cygwin's "nodosfilewarning"
	# This occurs one and only one time when a DOS path is used in a Cygwin command
	# When it occurs, it causes problems for other subroutines which parse the output
	# Example:
	# cygwin warning:
	#    MS-DOS style path detected: C:/foo
	#    Preferred POSIX equivalent is: /cygdrive/c/foo
	#    CYGWIN environment variable option "nodosfilewarning" turns off this warning.
	#    Consult the user's guide for more details about POSIX paths:
	#      http://cygwin.com/cygwin-ug-net/using.html#using-pathnames
	
	my $command = 'grep foo C:/foo';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to trigger Cygwin nodosfilewarning");
		return;
	}
	elsif (grep(/nodosfilewarning/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "intentionally triggered Cygwin nodosfilewarning, output:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Cygwin nodosfilewarning was not triggered, this is not necessarily a problem, command: '$command', output:\n" . join("\n", @$output));
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_text_file_line_endings

 Parameters  : $file_path, $line_ending (optional)
 Returns     : boolean
 Description : Changes the line endings of a text file. This is equivalent to
               running unix2dos or dos2unix. The default line ending type is
               Windows. Unix-style line endings will be applied if the
					$line_ending argument is supplied and does not contain 'win' or
					'r'.

=cut

sub set_text_file_line_endings {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($file_path, $line_ending) = @_;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	$line_ending = 'win' unless $line_ending;
	
	return $self->SUPER::set_text_file_line_endings($file_path, $line_ending);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 search_and_replace_in_files

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub search_and_replace_in_files {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	# Get the arguments
	my $base_directory = shift;
	my $search_pattern = shift;
	my $replace_string = shift;
	if (!$base_directory) {
		notify($ERRORS{'WARNING'}, 0, "base directory was not specified as an argument");
		return;
	}
	if (!$search_pattern) {
		notify($ERRORS{'WARNING'}, 0, "search pattern was not specified as an argument");
		return;
	}
	if (!$replace_string) {
		notify($ERRORS{'WARNING'}, 0, "replace string was not specified as an argument");
		return;
	}
	
	# Replace backslashes with a forward slash in the base directory path
	$base_directory =~ s/\\+/\//g;
	
	# Escape forward slashes in the search pattern and replace string
	$search_pattern =~ s/\//\\\//g;
	$replace_string =~ s/\//\\\//g;
	
	# Escape special characters in the search pattern
	$search_pattern =~ s/([!-])/\\$1/g;
	
	# Run grep to find files matching pattern
	my $grep_command = "/bin/grep -ilr \"$search_pattern\" \"$base_directory\" 2>&1 | grep -Ev \"\.(exe|dll)\"";
	my ($grep_status, $grep_output) = $self->execute($grep_command, 0);
	if (!defined($grep_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run grep on directory: $base_directory, pattern: $search_pattern");
		return;
	}
	elsif (grep(/No such file/i, @$grep_output)) {
		notify($ERRORS{'DEBUG'}, 0, "no files to process, base directory does not exist: $base_directory");
		return 1;
	}
	elsif ("@$grep_output" =~ /(grep|bash):/i) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running command '$grep_command':\n" . join("\n", @$grep_output));
		return;
	}
	elsif ($grep_status == 1) {
		notify($ERRORS{'OK'}, 0, "no files were found matching pattern '$search_pattern' in: $base_directory");
		return 1;
	}
	elsif (grep(/(grep|bash|warning|error):/i, @$grep_output) || $grep_status != 0) {
		notify($ERRORS{'WARNING'}, 0, "error occurred running command: '$grep_command'\noutput:\n" . join("\n", @$grep_output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "found files matching pattern '$search_pattern' in $base_directory:\n" . join("\n", @$grep_output));
	}
	
	# Run sed on each matching file to replace string
	my $sed_error_count = 0;
	for my $matching_file (@$grep_output) {
		$matching_file =~ s/\\+/\//g;
		# Run grep to find files matching pattern
		my $sed_command = "/bin/sed -i -e \"s/$search_pattern/$replace_string/\" \"$matching_file\"";
		my ($sed_status, $sed_output) = $self->execute($sed_command, 0);
		if (!defined($sed_status)) {
			notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to run sed on file: $matching_file");
			$sed_error_count++;
		}
		elsif ("@$sed_output" =~ /No such file/i) {
			notify($ERRORS{'WARNING'}, 0, "file was not found: $matching_file, sed output:\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		elsif ("@$grep_output" =~ /(grep|sed):/i) {
			notify($ERRORS{'WARNING'}, 0, "error occurred running command '$sed_command':\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		elsif ($sed_status != 0) {
			notify($ERRORS{'WARNING'}, 0, "sed exit status is $sed_status, output:\n" . join("\n", @$sed_output));
			$sed_error_count++;
		}
		else {
			notify($ERRORS{'OK'}, 0, "replaced '$search_pattern' with '$replace_string' in $matching_file");
			
			# Apply Windows-style line endings to scripts.ini
			$self->set_text_file_line_endings($matching_file);
		}
	}
	
	# Return false if any errors occurred
	if ($sed_error_count) {
		return;
	}
	
	return 1;
	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 copy_capture_configuration_files

 Parameters  : $source_configuration_directory
 Returns     :
 Description : Copies all required configuration files to the computer,
               including scripts, utilities, drivers needed to capture an
               image.

=cut

sub copy_capture_configuration_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL module object method");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Get an array containing the configuration directory paths on the management node
	# This is made up of all the the $SOURCE_CONFIGURATION_DIRECTORY values for the OS class and it's parent classes
	# The first array element is the value from the top-most class the OS object inherits from
	my @source_configuration_directories = $self->get_source_configuration_directories();
	if (!@source_configuration_directories) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve source configuration directories");
		return;
	}
	
	# Delete existing configuration directory if it exists
	if (!$self->delete_capture_configuration_files()) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete existing capture configuration files");
		return;
	}

	# Attempt to create the configuration directory if it doesn't already exist
	if (!$self->create_directory($NODE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "unable to create directory on $computer_node_name: $NODE_CONFIGURATION_DIRECTORY");
		return;
	}

	# Copy configuration files
	for my $source_configuration_directory (@source_configuration_directories) {
		# Check if source configuration directory exists on this management node
		unless (-d "$source_configuration_directory") {
			notify($ERRORS{'OK'}, 0, "source directory does not exist on this management node: $source_configuration_directory");
			next;
		}
		
		notify($ERRORS{'OK'}, 0, "copying image capture configuration files from $source_configuration_directory to $computer_node_name");
		if (run_scp_command("$source_configuration_directory/*", "$computer_node_name:$NODE_CONFIGURATION_DIRECTORY", $management_node_keys)) {
			notify($ERRORS{'OK'}, 0, "copied $source_configuration_directory directory to $computer_node_name:$NODE_CONFIGURATION_DIRECTORY");
			
			notify($ERRORS{'DEBUG'}, 0, "setting permissions of $NODE_CONFIGURATION_DIRECTORY to 777 on $computer_node_name");
			$self->execute("/usr/bin/chmod.exe -R 777 $NODE_CONFIGURATION_DIRECTORY");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy $source_configuration_directory to $computer_node_name");
			return;
		}
	}
	
	# Delete any Subversion files which may have been copied
	if (!$self->delete_files_by_pattern($NODE_CONFIGURATION_DIRECTORY, '.*\.svn.*')) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete Subversion files under: $NODE_CONFIGURATION_DIRECTORY");
	}
	
	$self->set_file_owner($NODE_CONFIGURATION_DIRECTORY, 'root');
	
	# Find any files containing a 'WINDOWS_ROOT_PASSWORD' string and replace it with the root password
	if ($self->search_and_replace_in_files($NODE_CONFIGURATION_DIRECTORY, 'WINDOWS_ROOT_PASSWORD', $WINDOWS_ROOT_PASSWORD)) {
		notify($ERRORS{'DEBUG'}, 0, "set the Windows root password in configuration files");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the Windows root password in configuration files");
		return;
	}

	return 1;
} ## end sub copy_capture_configuration_files

#//////////////////////////////////////////////////////////////////////////////

=head2 clean_hard_drive

 Parameters  : none
 Returns     : boolean
 Description : Runs dism.exe and cleanmgr.exe to attempt to clean unnecessary
               files from the hard drive.

=cut

sub clean_hard_drive {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	$self->run_dism_cleanup();
	$self->run_cleanmgr();
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_dism_cleanup

 Parameters  : none
 Returns     : boolean
 Description : Runs 'dism.exe /online /cleanup-image /spsuperseded' to clean up
               service pack and update files from the computer's hard drive.

=cut

sub run_dism_cleanup {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_name = $self->data->get_computer_short_name();
	my $system32_path = $self->get_system32_path() || return;
	
	# Run dism.exe
	my $dism_command = "$system32_path/dism.exe /online /cleanup-image /spsuperseded";
	my ($dism_exit_status, $dism_output) = $self->execute($dism_command, 1);
	if (!defined($dism_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to run dism.exe on $computer_name");
		return;
	}
	elsif (grep(/not found|no such file/i, @$dism_output)) {
		# The dism.exe file may not be present
		notify($ERRORS{'OK'}, 0, "dism.exe is not present on $computer_name");
	}
	elsif (grep(/No service pack backup files/i, @$dism_output)) {
		notify($ERRORS{'DEBUG'}, 0, "dism.exe did not find any service pack files to remove on $computer_name");
	}
	elsif (grep(/spsuperseded option is not recognized/i, @$dism_output)) {
		notify($ERRORS{'DEBUG'}, 0, "dism.exe is not able to remove service pack files for the OS version on $computer_name");
	}
	elsif (grep(/operation completed successfully/i, @$dism_output)) {
		notify($ERRORS{'OK'}, 0, "ran dism.exe to clean image on $computer_name, output:\n" . join("\n", @$dism_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from dism.exe on $computer_name:\n" . join("\n", @$dism_output));
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_cleanmgr

 Parameters  : none
 Returns     : boolean
 Description : Runs the cleanmgr.exe utility. This is the utility run by
               selecting the "Disk Cleanup" option when viewing a hard drive's
               properties.

=cut

sub run_cleanmgr {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $volume_caches_key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches';
	
	# Add the cleanmgr.exe settings to the registry
	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00

[$volume_caches_key]

EOF

	# Retrieve the existing VolumeCaches registry settings
	# The cleanmgr.exe options may vary depending on version and which Windows features are installed
	# Dynamically determine all of the options available on the computer
	my $volume_caches_info = $self->reg_query($volume_caches_key);
	for my $key_path (keys %$volume_caches_info) {
		# Get the key name:
		# HKEY_LOCAL_MACHINE\SOFTWARE\...\VolumeCaches\Temporary Setup Files --> 'Temporary Setup Files'
		my ($key) = $key_path =~ /([^\\]+)$/;
		$registry_string .= "[$volume_caches_key\\$key]\n";
		$registry_string .= "\"StateFlags9999\"=dword:00000002\n\n";
	}
	
	# Import the string into the registry
	if (!$self->import_registry_string($registry_string)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry settings to configure the disk cleanup utility");
		return;
	}
	
	# Run cleanmgr.exe
	my $cleanmgr_command = "/bin/cygstart.exe $system32_path/cleanmgr.exe /SAGERUN:9999";
	my ($cleanmgr_exit_status, $cleanmgr_output) = $self->execute($cleanmgr_command);
	if (!defined($cleanmgr_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to run cleanmgr.exe");
		return;
	}
	elsif (grep(/not found/i, @$cleanmgr_output)) {
		# The cleanmgr.exe file may not be present - it is not installed by default on Windows Server 2008 and possibly others
		notify($ERRORS{'OK'}, 0, "cleanmgr.exe is not present on $computer_node_name, this is usually because the Desktop Experience feature is not installed");
		return 1;
	}
	
	# Wait for cleanmgr.exe to finish - may take a long time
	my $message = 'waiting for cleanmgr.exe to finish';
	my $total_wait_seconds = 600;
	notify($ERRORS{'OK'}, 0, "started cleanmgr.exe, waiting up to $total_wait_seconds seconds for it to finish");
	if ($self->code_loop_timeout(sub{!$self->is_process_running(@_)}, ['cleanmgr.exe'], $message, $total_wait_seconds, 15)) {
		notify($ERRORS{'DEBUG'}, 0, "cleanmgr.exe has finished");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "cleanmgr.exe has not finished after waiting $total_wait_seconds seconds, the Recycle Bin may be corrupt");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_process_running

 Parameters  : $process_identifier
 Returns     : boolean
 Description : Determines if a process is running identified by the argument.
               The argument should be the name of an executable. Wildcards (*)
               are allowed.

=cut

sub is_process_running {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method, arguments:\n" . format_data(\@_));
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $process_identifier = shift;
	if (!defined($process_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "process identifier argument was not supplied");
		return;
	}
	
	my $command = "$system32_path/tasklist.exe /FI \"IMAGENAME eq $process_identifier\"";
	my ($status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to determine if process is running: $process_identifier");
		return;
	}
	elsif (grep(/No tasks/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "process is NOT running: $process_identifier");
		return 0;
	}
	elsif (grep(/PID/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "process is running: $process_identifier");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to determine if process is running: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 start_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Starts a service on the computer.

=cut

sub start_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	# The Client for NFS service should be controlled with the nfsadmin.exe utility
	if ($service_name =~ /^NfsClnt$/) {
		if ($self->start_nfs_client_service()) {
			return 1;
		}
	}

	my $command = $system32_path . '/net.exe start "' . $service_name . '"';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to to start service: $service_name");
		return;
	}
	elsif (grep(/already been started/i, @{$output})) {
		notify($ERRORS{'OK'}, 0, "service is already started: $service_name");
		return 1;
	}
	elsif (grep(/(does not exist|service name is invalid)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "service could not be started because it does not exist: $service_name, output:\n" . join("\n", @$output));
		return 0;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to start service: $service_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "started service: $service_name" . join("\n", @$output));
		return 1;
	}
	
} ## end sub start_service

#//////////////////////////////////////////////////////////////////////////////

=head2 stop_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Stops a service on the computer.

=cut

sub stop_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}
	
	# The Client for NFS service should be controlled with the nfsadmin.exe utility
	if ($service_name =~ /^NfsClnt$/) {
		if ($self->stop_nfs_client_service()) {
			return 1;
		}
	}
	
	my $command = $system32_path . '/net.exe stop "' . $service_name . '"';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to to stop service: $service_name");
		return;
	}
	elsif (grep(/is not started/i, @{$output})) {
		notify($ERRORS{'OK'}, 0, "service is not started: $service_name");
		return 1;
	}
	elsif (grep(/(does not exist|service name is invalid)/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "service was not stopped because it does not exist: $service_name, output:\n" . join("\n", @$output));
		return 1;
	}
	elsif ($exit_status || grep(/could not be stopped/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop service: $service_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "stopped service: $service_name" . join("\n", @$output));
	}
	return 1;
} ## end sub stop_service

#//////////////////////////////////////////////////////////////////////////////

=head2 restart_service

 Parameters  : $service_name
 Returns     : boolean
 Description : Restarts the Windows service specified by the argument. The
               service is started if it is not running.

=cut

sub restart_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}

	$self->stop_service($service_name);
	return $self->start_service($service_name);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 service_exists

 Parameters  : $service_name
 Returns     : If service exists: 1
               If service does not exist: 0
               If error occurred: undefined
 Description : Runs sc.exe query to determine if a service exists.

=cut

sub service_exists {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	my $service_name = shift;
	if (!$service_name) {
		notify($ERRORS{'WARNING'}, 0, "service name was not passed as an argument");
		return;
	}

	my $command = $system32_path . '/sc.exe query "' . $service_name . '"';
	my ($status, $output) = $self->execute($command, 1);
	if (defined($output) && grep(/service does not exist/i, @{$output})) {
		notify($ERRORS{'DEBUG'}, 0, "service does not exist: $service_name");
		return 0;
	}
	elsif (defined($status) && $status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "service exists: $service_name");
	}
	elsif (defined($status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if service exists: $service_name, exit status: $status, output:\n@{$output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to determine if service exists");
		return;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 start_nfs_client_service

 Parameters  : none
 Returns     : boolean
 Description : Starts the Client for NFS (NfsClnt) service on the computer using
               the nfsadmin.exe utility.

=cut

sub start_nfs_client_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;

	my $command = $system32_path . '/nfsadmin.exe client start';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to to start Client for NFS service");
		return;
	}
	elsif (grep(/already started/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "Client for NFS service is already started");
		return 1;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "failed to start Client for NFS service using nfsadmin.exe because utility does not exist on computer");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to start Client for NFS service, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "started Client for NFS service, output:\n" . join("\n", @$output));
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 stop_nfs_client_service

 Parameters  : none
 Returns     : boolean
 Description : Stops the Client for NFS (NfsClnt) service on the computer using
               the nfsadmin.exe utility.

=cut

sub stop_nfs_client_service {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;

	my $command = $system32_path . '/nfsadmin.exe client stop';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to to stop Client for NFS service");
		return;
	}
	elsif (grep(/not been started/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "Client for NFS service is not started");
		return 1;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "failed to stop Client for NFS service using nfsadmin.exe because utility does not exist on computer");
		return;
	}
	elsif ($exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to stop Client for NFS service, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "stopped Client for NFS service, output:\n" . join("\n", @$output));
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_installed_applications

 Parameters  :
 Returns     :
 Description : Queries the registry for applications that are installed on the computer.
               Subkeys under the following key contain this information:
					HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall
					
					A reference to a hash is returned. The keys of this hash are the names of the subkeys under the Uninstall key.
					Each subkey contains additional data formatted as follows:
					my $installed_applications = $self->os->get_installed_applications();
					$installed_applications->{pdfFactory Pro}{DisplayName} = 'pdfFactory Pro'
               $installed_applications->{pdfFactory Pro}{UninstallString} = 'C:\WINDOWS\System32\spool\DRIVERS\W32X86\3\fppinst2.exe /uninstall'

=cut

sub get_installed_applications {
	my $self = shift;
	if (!ref($self)) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get an optional regex filter string
	my $regex_filter = shift;
	if ($regex_filter) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve applications installed on $computer_node_name matching filter: $regex_filter");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve all applications installed on $computer_node_name");
	}
	
	my $uninstall_key = 'HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall';
	my $registry_data = $self->reg_query($uninstall_key);
	if (!$registry_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve installed applications, failed to query registry: $uninstall_key");
		return;
	}
	
	if ($self->is_64_bit()) {
		my $uninstall_key_32 = 'HKEY_LOCAL_MACHINE\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall';
		my $registry_data_32 = $self->reg_query($uninstall_key_32);
		if ($registry_data_32) {
			$registry_data = {%$registry_data, %$registry_data_32};
		}
	}
	
	my $installed_products = {};
	my @display_names;
	
	# Loop through registry keys
	REGISTRY_KEY: for my $registry_key (keys %$registry_data) {
		my ($product_key) = $registry_key =~ /Uninstall\\([^\\]+)$/;
		
		if ($registry_key eq $uninstall_key) {
			next REGISTRY_KEY;
		}
		elsif (!$product_key) {
			notify($ERRORS{'WARNING'}, 0, "unable to parse product key from registry key: $registry_key");
			next REGISTRY_KEY;
		}
		elsif (!scalar(keys %{$registry_data->{$registry_key}})) {
			#notify($ERRORS{'DEBUG'}, 0, "registry key does not contain any information: $registry_key");
			next REGISTRY_KEY;
		}
		
		my $display_name = $registry_data->{$registry_key}{DisplayName} || $registry_data->{$registry_key}{'(Default)'};
		if (!$display_name) {
			next REGISTRY_KEY;
		}
		
		if ($regex_filter) {
			if ($product_key =~ /$regex_filter/i) {
				notify($ERRORS{'DEBUG'}, 0, "found product matching filter '$regex_filter':\n$product_key");
				$installed_products->{$product_key} = $registry_data->{$registry_key};
				push @display_names, $display_name;
				next REGISTRY_KEY;
			}
			
			foreach my $info_key (keys %{$registry_data->{$registry_key}}) {
				my $info_value = $registry_data->{$registry_key}{$info_key} || '';
				if ($info_value =~ /$regex_filter/i) {
					#notify($ERRORS{'DEBUG'}, 0, "found value matching filter '$regex_filter':\n{$product_key}{$info_key} = '$info_value'");
					$installed_products->{$product_key} = $registry_data->{$registry_key};
					push @display_names, $display_name;
					next REGISTRY_KEY;
				}
				else {
					#notify($ERRORS{'DEBUG'}, 0, "value does not match filter '$regex_filter':\n{$product_key}{$info_key} = '$info_value'");
				}
			}
		}
		else {
			$installed_products->{$product_key} = $registry_data->{$registry_key};
			push @display_names, $display_name;
		}
	}
	
	my $installed_product_count = scalar(keys(%$installed_products));
	if ($installed_product_count) {
		if ($regex_filter) {
			notify($ERRORS{'DEBUG'}, 0, "found $installed_product_count installed applications matching filter '$regex_filter':\n" . join("\n", sort @display_names));
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "found $installed_product_count installed applications:\n" . join("\n", sort @display_names));
		}
	}
	else {
		if ($regex_filter) {
			notify($ERRORS{'DEBUG'}, 0, "no applications are installed matching filter: '$regex_filter'");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "no applications are installed");
		}
	}
	
	return $installed_products;
} ## end sub get_installed_applications

#//////////////////////////////////////////////////////////////////////////////

=head2 get_task_list

 Parameters  : None, must be called as an object method ($self->os->get_task_list())
 Returns     : If successful: Reference to an array containing the lines of output generated by tasklist.exe
               If failed: false
 Description : Runs tasklist.exe and returns its output. Tasklist.exe displays a list of applications and associated tasks running on the computer.
               The following switches are used when tasklist.exe is executed:
               /NH - specifies the column header should not be displayed in the output
					/V  - specifies that verbose information should be displayed
					The output is formatted as follows (column header is not included):
					Image Name                   PID Session Name     Session#    Mem Usage Status          User Name                                              CPU Time Window Title                                                            
               System Idle Process            0 Console                 0         16 K Running         NT AUTHORITY\SYSTEM           

=cut

sub get_task_list {
	my $self = shift;
	if (!ref($self)) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Attempt to run tasklist.exe with /NH for no header
	my $tasklist_command = $system32_path . '/tasklist.exe /NH /V';
	my ($tasklist_exit_status, $tasklist_output) = $self->execute($tasklist_command, 0);
	if (defined($tasklist_exit_status) && $tasklist_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran tasklist.exe");
	}
	elsif (defined($tasklist_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run tasklist.exe, exit status: $tasklist_exit_status, output:\n@{$tasklist_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run tasklist.exe");
		return;
	}
	
	return $tasklist_output;
} ## end sub get_task_list

#//////////////////////////////////////////////////////////////////////////////

=head2 get_task_info

 Parameters  : $pattern (optional)
 Returns     : hash reference
 Description : Runs tasklist.exe and returns a hash reference containing
               information about the processes running on the computer. The hash
               keys are the process PIDs.

=cut

sub get_task_info {
	my $self = shift;
	if (!ref($self)) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $pattern = shift;
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Attempt to run tasklist.exe with /NH for no header
	my $tasklist_command = $system32_path . '/tasklist.exe /V /FO CSV';
	my ($tasklist_exit_status, $tasklist_output) = $self->execute($tasklist_command, 0);
	if (defined($tasklist_exit_status) && $tasklist_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "ran tasklist.exe");
	}
	elsif (defined($tasklist_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run tasklist.exe, exit status: $tasklist_exit_status, output:\n@{$tasklist_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to run tasklist.exe");
		return;
	}
	
	my $csv = Text::CSV_XS->new();
	
	my $heading_line = shift @$tasklist_output;
	$csv->parse($heading_line);
	
	my @column_names = $csv->fields();
	
	
	notify($ERRORS{'DEBUG'}, 0, "column names: " . join(", ", @column_names));
	$csv->column_names(@column_names);
	
	my $tasklist_io = IO::String->new(join("\n", @$tasklist_output));
	
	my $tasks = $csv->getline_hr_all($tasklist_io);
	
	my $task_info = {};
	for my $task (@$tasks) {
		my $task_pid = $task->{'PID'};
		my $task_name = $task->{'Image Name'};
		
		if ($pattern && $task_name !~ /$pattern/i) {
			next;
		}
		$task_info->{$task_pid} = $task;
	}
	notify($ERRORS{'DEBUG'}, 0, "task info:\n" . format_data($task_info));
	return $task_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 apply_security_templates

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Runs secedit.exe to apply the security template files configured
               for the OS. Windows security template files use the .inf
               extension.
               
               Security templates are always copied from the management node
               rather than using a copy stored locally on the computer. This
               allows templates updated centrally to always be applied to the
               computer. Template files residing locally on the computer are not
               processed.
               
               The template files should reside in a directory named "Security"
               under the OS source configuration directory. An example would be:
               
               /usr/local/vcl/tools/Windows_XP/Security/xp_security.inf
               
               This subroutine supports OS module inheritence meaning that if an
               OS module inherits from another OS module, the security templates
               of both will be applied. The order is from the highest parent
               class down to any template files configured specifically for the
               OS module which was instantiated.
               
               This allows any Windows OS module to inherit from another class
               which has security templates defined and override any settings
               from above.
               
               Multiple .inf security template files may be configured for each
               OS. They will be applied in alphabetical order.
               
               Example: Inheritence is configured as follows, with the XP module
               being the instantiated (lowest) class:
               
               VCL::Module
               ^
               VCL::Module::OS
               ^
               VCL::Module::OS::Windows
               ^
               VCL::Module::OS::Windows::Version_5
               ^
               VCL::Module::OS::Windows::Version_5::XP
               
               The XP and Windows classes each have 2 security template files
               configured in their respective Security directories:
               
               /usr/local/vcl/tools/Windows/Security/eventlog_512.inf
               /usr/local/vcl/tools/Windows/Security/windows_security.inf
               /usr/local/vcl/tools/Windows_XP/Security/xp_eventlog_4096.inf
               /usr/local/vcl/tools/Windows_XP/Security/xp_security.inf
               
               The templates will be applied in the order shown above. The
               Windows templates are applied first because it is a parent class
               of XP. For each class being processed, the files are applied in
               alphabetical order.
               
               Assume in the example above that the Windows module's
               eventlog_512.inf file configures the event log to be a maximum of
               512 KB and that it is desirable under Windows XP to configure a
               larger maximum event log size. In order to achieve this,
               xp_eventlog_4096.inf was placed in XP's Security directory which
               contains settings to set the maximum size to 4,096 KB. The
               xp_eventlog_4096.inf file is applied after the eventlog_512.inf
               file, thus overridding the setting configured in the
               eventlog_512.inf file. The resultant maximum event log size will
               be set to 4,096 KB.

=cut

sub apply_security_templates {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module:: module object method");
		return;
	}
	
	my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# Get an array containing the configuration directory paths on the management node
	# This is made up of all the the $SOURCE_CONFIGURATION_DIRECTORY values for the OS class and it's parent classes
	# The first array element is the value from the top-most class the OS object inherits from
	my @source_configuration_directories = $self->get_source_configuration_directories();
	if (!@source_configuration_directories) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve source configuration directories");
		return;
	}
	
	# Loop through the configuration directories for each OS class on the management node
	# Find any .inf files residing under Security
	my @inf_file_paths;
	for my $source_configuration_directory (@source_configuration_directories) {
		notify($ERRORS{'OK'}, 0, "checking if any security templates exist in: $source_configuration_directory/Security");
		
		# Check each source configuration directory for .inf files under a Security subdirectory
		my $find_command = "find $source_configuration_directory/Security -name \"*.inf\" 2>&1 | sort -f";
		my ($find_exit_status, $find_output) = run_command($find_command);
		if (defined($find_output) && grep(/No such file/i, @$find_output)) {
			notify($ERRORS{'DEBUG'}, 0, "path does not exist: $source_configuration_directory/Security");
		}
		elsif (defined($find_exit_status) && $find_exit_status == 0) {
			notify($ERRORS{'DEBUG'}, 0, "ran find, output:\n" . join("\n", @$find_output));
			push @inf_file_paths, @$find_output;
		}
		elsif (defined($find_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run find, exit status: $find_exit_status, output:\n@{$find_output}");
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run local command to run find");
			return;
		}
	}
	
	# Remove any newlines from the file paths in the array
	chomp(@inf_file_paths);
	notify($ERRORS{'DEBUG'}, 0, "security templates will be applied in this order:\n" . join("\n", @inf_file_paths));
	
	# Make sure the Security directory exists before attempting to copy files or SCP will fail
	if (!$self->create_directory("$NODE_CONFIGURATION_DIRECTORY/Security")) {
		notify($ERRORS{'WARNING'}, 0, "unable to create directory: $NODE_CONFIGURATION_DIRECTORY/Security");
	}
	
	# Loop through the .inf files and apply them to the node using secedit.exe
	my $inf_count = 0;
	my $error_occurred = 0;
	for my $inf_file_path (@inf_file_paths) {
		$inf_count++;
		
		# Get the name of the file
		my ($inf_file_name) = $inf_file_path =~ /.*[\\\/](.*)/g;
		my ($inf_file_root) = $inf_file_path =~ /.*[\\\/](.*).inf/gi;
		
		# Construct the target path, prepend a number to indicate the order the files were processed
		my $inf_target_path = "$NODE_CONFIGURATION_DIRECTORY/Security/$inf_count\_$inf_file_name";
		
		# Copy the file to the node and set the permissions to 644
		notify($ERRORS{'DEBUG'}, 0, "attempting to copy file to: $inf_target_path");
		if (run_scp_command($inf_file_path, "$computer_node_name:$inf_target_path", $management_node_keys)) {
			notify($ERRORS{'DEBUG'}, 0, "copied file: $computer_node_name:$inf_target_path");
	
			# Set permission on the copied file
			if (!$self->execute("/usr/bin/chmod.exe -R 644 $inf_target_path", 0)) {
				notify($ERRORS{'WARNING'}, 0, "could not set permissions on $inf_target_path");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to copy $inf_file_path to $inf_target_path");
			next;
		}
		
		# Assemble the paths secedit needs
		my $secedit_exe = $system32_path . '/secedit.exe';
		my $secedit_db = '$SYSTEMROOT/security/Database/' . "$inf_count\_$inf_file_root.sdb";
		my $secedit_log = '$SYSTEMROOT/security/Logs/' . "$inf_count\_$inf_file_root.log";
		
		# Attempt to delete an existing log file
		$self->delete_file($secedit_log);
		
		# The inf path must use backslashes or secedit.exe will fail
		$inf_target_path =~ s/\//\\\\/g;
		
		# Run secedit.exe
		# Note: secedit.exe returns exit status 3 if a warning occurs, this will appear in the log file:
		# Task is completed. Warnings occurred for some attributes during this operation. It's ok to ignore.
		my $secedit_command = "$secedit_exe /configure /cfg \"$inf_target_path\" /db $secedit_db /log $secedit_log /overwrite /quiet";
		
		my ($secedit_exit_status, $secedit_output) = $self->execute($secedit_command, 0);
		if (defined($secedit_exit_status) && ($secedit_exit_status == 0 || $secedit_exit_status == 3)) {
			notify($ERRORS{'OK'}, 0, "ran secedit.exe to apply $inf_file_name");
		}
		elsif (defined($secedit_exit_status)) {
			notify($ERRORS{'WARNING'}, 0, "failed to run secedit.exe to apply $inf_target_path, exit status: $secedit_exit_status, command: $secedit_command, output:\n" . join("\n", @$secedit_output));
			$error_occurred++;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to run secedit.exe to apply $inf_target_path");
			$error_occurred++;
		}
	}
	
	if ($error_occurred) {
		return 0;
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 kill_process

 Parameters  : String containing task name pattern
 Returns     : If successful: true
               If failed: false
 Description : Runs taskkill.exe to kill processes with names matching a
					pattern. Wildcards can be specified using *, but task name
					patterns cannot begin with a *.
               
               Example pattern: notepad*

=cut

sub kill_process {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Get the task name pattern argument
	my $task_pattern = shift;
	unless ($task_pattern) {
		notify($ERRORS{'WARNING'}, 0, "task name pattern argument was not specified");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Typical output:
	# Task was killed, exit status = 0:
	# SUCCESS: The process with PID 3476 child of PID 5876 has been terminated.
	
	# No tasks match pattern, exit status = 0:
	# INFO: No tasks running with the specified criteria.
	
	# Bad search filter, exit status = 1:
	# ERROR: The search filter cannot be recognized.
	
	# Attempt to kill task
	my $taskkill_command = $system32_path . "/taskkill.exe /F /T /FI \"IMAGENAME eq $task_pattern\"";
	my ($taskkill_exit_status, $taskkill_output) = $self->execute($taskkill_command, '1');
	if (defined($taskkill_exit_status) && $taskkill_exit_status == 0 && (my @killed = grep(/SUCCESS/, @$taskkill_output))) {
		notify($ERRORS{'OK'}, 0, scalar @killed . "processe(s) killed matching pattern: $task_pattern\n" . join("\n", @killed));
	}
	elsif (defined($taskkill_exit_status) && $taskkill_exit_status == 0 && grep(/No tasks running/i, @{$taskkill_output})) {
		notify($ERRORS{'DEBUG'}, 0, "process does not exist matching pattern: $task_pattern");
	}
	elsif (defined($taskkill_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "unable to kill process matching pattern: $task_pattern\n" . join("\n", @{$taskkill_output}));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to kill process matching pattern: $task_pattern");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_ie_configuration_page

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Sets registry keys which prevent Internet Explorer's
					configuration page from appearing the first time a user launches
					it. This subroutine also enables the Internet Explorer Phishing
					Filter and sets it to not display a balloon message.

=cut

sub disable_ie_configuration_page {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}

	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\Main]
"DisableFirstRunCustomize"=dword:00000001
"RunOnceHasShown"=dword:00000001
"RunOnceComplete"=dword:00000001

[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Internet Explorer\\PhishingFilter]
"Enabled"=dword:00000002
"ShownVerifyBalloon"=dword:00000001

[HKEY_LOCAL_MACHINE\\Software\\Policies\\Microsoft\\Internet Explorer\\Main]
"DisableFirstRunCustomize"=dword:00000001

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to disable IE runonce");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable IE runonce");
		return 0;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_rdp_audio

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Sets the registry keys to allow audio redirection via RDP
               sessions. This is disabled by default under Windows Server 2008
               and possibly other versions of Windows. Also sets the Windows
               Audio service to start automatically.

=cut

sub enable_rdp_audio {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Terminal Server\\WinStations\\RDP-Tcp]
"fDisableCam"=dword:00000000

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services]
"fDisableCam"=dword:00000000

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to enable RDP audio");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to enable RDP audio");
		return 0;
	}
	
	# Configure the Windows Audio service to start automatically
	if ($self->set_service_startup_mode('AudioSrv', 'auto')) {
		notify($ERRORS{'DEBUG'}, 0, "set the Windows Audio service startup mode to auto");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the Windows Audio service startup mode to auto");
		return 0;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_client_compatible_rdp_color_depth

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Sets the registry keys to allow clients use 24 or 32-bit color
               depth in the RDP session.

=cut

sub enable_client_compatible_rdp_color_depth {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services]
"ColorDepth"=dword:000003e7

EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to enable client compatible RDP color depth");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to enable client compatible RDP color depth");
		return 0;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_node_configuration_directory

 Parameters  : None.
 Returns     : String containing filesystem path
 Description : Retrieves the $NODE_CONFIGURATION_DIRECTORY variable value the
               OS. This is the path on the computer's hard drive where image
					configuration files and scripts are copied.

=cut

sub get_node_configuration_directory {
	return $NODE_CONFIGURATION_DIRECTORY;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_kms_client_product_keys

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves the $KMS_CLIENT_PRODUCT_KEYS variable.

=cut

sub get_kms_client_product_keys {
	return $KMS_CLIENT_PRODUCT_KEYS;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_kms_client_product_key

 Parameters  : $product_name (optional)
 Returns     : If successful: string
               If failed: false
 Description : Returns a KMS client product key based on the version of Windows
               either specified as an argument or installed on the computer. A
               KMS client product key is a publically shared product key which
               must be installed before activating using a KMS server.

=cut

sub get_kms_client_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the product name
	my $product_name = shift || $self->get_product_name();
	if (!$product_name) {
		notify($ERRORS{'WARNING'}, 0, "product name was not passed as an argument and could not be retrieved from computer");
		return;
	}
	
	# Remove (TM) or (R) from the product name
	$product_name =~ s/ \([tmr]*\)//ig;
	
	# Get the matching product key from the hash for the product name
	my $product_key = $KMS_CLIENT_PRODUCT_KEYS->{$product_name};
	if (!$product_key) {
		notify($ERRORS{'WARNING'}, 0, "unsupported product name: $product_name, KMS client product key is not known");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "returning KMS client setup key for $product_name: $product_key");
	return $product_key;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_security_center_notifications

 Parameters  : None.
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Security Center notifications which are
               displayed in the notification area (system tray).

=cut

sub disable_security_center_notifications {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center]
"AntiSpywareDisableNotify"=dword:00000001
"AntiVirusDisableNotify"=dword:00000001
"FirewallDisableNotify"=dword:00000001
"UacDisableNotify"=dword:00000001
"UpdatesDisableNotify"=dword:00000001
"FirstRunDisabled"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Security Center\Svc]
"AntiVirusOverride"=dword:00000001
"AntiSpywareOverride"=dword:00000001
"FirewallOverride"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "set the registry keys to disable security center notifications");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable security center notifications");
		return 0;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_automatic_updates

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Automatic Updates by configuring a local group
               policy:
               HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\NoAutoUpdate=1
               
               This must be done using a policy in order to prevent
               Windows Security Center will display a warning icon in the
               notification area. Windows Update can be disabled via the GUI
               which configures the following key but a warning will be
               presented to the user:
               HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update

=cut

sub disable_automatic_updates {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU]
"NoAutoUpdate"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled automatic updates");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable automatic updates");
		return 0;
	}
	

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_windows_defender

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables Windows Defender by doing the following:
               -Configures local group policy to disable Windows Defender
               -Removes HKLM...Run registry key to start Windows Defender at logon
               -Stops the Windows Defender service
               -Disables the Windows Defender service

=cut

sub disable_windows_defender {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}

	my $registry_string .= <<'EOF';
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows Defender]
"DisableAntiSpyware"=dword:00000001

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run]
"Windows Defender"=-
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'DEBUG'}, 0, "set the registry keys to disable Windows defender");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the registry key to disable Windows defender");
		return 0;
	}
	
	# Check if WinDefend service exists
	if ($self->service_exists('WinDefend')) {
		# Stop the Windows Defender service
		if ($self->stop_service('WinDefend')) {
			notify($ERRORS{'DEBUG'}, 0, "stopped the Windows Defender service");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to stop the Windows Defender service");
			return 0;
		}
		
		# Disable the Windows Defender service
		if ($self->set_service_startup_mode('WinDefend', 'disabled')) {
			notify($ERRORS{'DEBUG'}, 0, "disabled the Windows Defender service");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to disable the Windows Defender service");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "disabled Windows Defender");

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 registry_query_value

 Parameters  : $key_name (required), $value_name (optional)
 Returns     : If successful: true
               If failed: false
 Description : Queries the registry. If a value name is specified as the 2nd
               argument, the value is returned. If a value name is not
               specified, the output from reg.exe /s is returned containing the
               subkeys and values.

=cut

sub registry_query_value {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}

	my $system32_path = $self->get_system32_path() || return;
	
	# Get and check the arguments
	my $key_name = shift;
	my $value_name = shift;
	if (!$key_name) {
		notify($ERRORS{'WARNING'}, 0, "registry key name argument was not specified");
		return;
	}
	
	# Assemble the query command string
	my $reg_query_command = $system32_path . "/reg.exe QUERY \"$key_name\"";
	
	# Check if the value name argument was specified
	my $query_mode;
	if ($value_name && $value_name eq '(Default)') {
		# Value name argument is (Default), query default value using /ve switch
		$reg_query_command .= " /ve";
		$query_mode = 'default';
	}
	elsif ($value_name) {
		# Value name argument was specified, query it using /v switch
		$reg_query_command .= " /v \"$value_name\"";
		$query_mode = 'value';
	}
	else {
		# Value name argument was not specified, query all subkeys and values
		$reg_query_command .= " /s";
		$query_mode = 'subkeys';
	}
	
	# Attempt to query the registry key
	my ($reg_query_exit_status, $reg_query_output) = $self->execute($reg_query_command, 1);
	if (defined($reg_query_output) && grep(/unable to find the specified registry/i, @$reg_query_output)) {
		notify($ERRORS{'OK'}, 0, "registry key or value does not exist");
		return;
	}
	if (defined($reg_query_exit_status) && $reg_query_exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "queried registry key, output:\n" . join("\n", @{$reg_query_output}));
	}
	elsif (defined($reg_query_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to query registry key, exit status: $reg_query_exit_status, output:\n@{$reg_query_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to query registry key");
		return;
	}
	
	# Check to see if the output appears normal	
	if (@{$reg_query_output}[0] !~ /reg\.exe version/i) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output, 1st line doesn't contain REG.EXE VERSION:\n" . join("\n", @{$reg_query_output}));
	}
	
	# Check what was asked for, if subkeys, return entire query output string joined with newlines
	if ($query_mode eq 'subkeys') {
		return join("\n", @{$reg_query_output});
	}
	
	# Find the array element containing the line with the value
	my ($value_line) =  grep(/($value_name|no name)/i, @{$reg_query_output});
	notify($ERRORS{'DEBUG'}, 0, "value output line: $value_line");
	
	# Split the line up and return the value
	my ($retrieved_key_name, $type, $retrieved_value);
	if ($query_mode eq 'value') {
		($retrieved_key_name, $type, $retrieved_value) = $value_line =~ /\s*([^\s]+)\s+([^\s]+)\s+([^\s]+)/;
	}
	else {
		($retrieved_key_name, $type, $retrieved_value) = $value_line =~ /\s*(<NO NAME>)\s+([^\s]+)\s+([^\s]+)/;
	}
	
	return $retrieved_value;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_static_public_address

 Parameters  : 
 Returns     : If successful: true
               If failed: false
 Description : Sets a static IP address for the public interface. The IP address
               stored in the database for the computer is used. The subnet
					mask, default gateway, and DNS servers configured for the
					management node are used.
					
					A persistent route is added to the routing table to the public
					default gateway.

=cut

sub set_static_public_address {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $computer_name = $self->data->get_computer_short_name();
	my $server_request_id = $self->data->get_server_request_id();
	my $server_request_fixed_ip = $self->data->get_server_request_fixed_ip();
	
	# Make sure public IP configuration is static or this is a server request
	my $ip_configuration = $self->data->get_management_node_public_ip_configuration();
	if ($ip_configuration !~ /static/i) {
		if (!$server_request_fixed_ip) {
			notify($ERRORS{'WARNING'}, 0, "static public address can only be set if IP configuration is static, current value: $ip_configuration \nserver_request_fixed_ip=$server_request_fixed_ip");
			return;
		}
	}

	# Get the IP configuration
	my $interface_name = $self->get_public_interface_name() || '<undefined>';
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address() || '<undefined>';
	my $subnet_mask = $self->data->get_management_node_public_subnet_mask() || '<undefined>';
	my $default_gateway = $self->get_correct_default_gateway() || '<undefined>';

   if ($server_request_fixed_ip) {
      $computer_public_ip_address = $server_request_fixed_ip;
      $subnet_mask = $self->data->get_server_request_netmask();
      $default_gateway = $self->data->get_server_request_router();
   }
	
	# Assemble a string containing the static IP configuration
	my $configuration_info_string = <<EOF;
public interface name: $interface_name
public IP address: $computer_public_ip_address
public subnet mask: $subnet_mask
public default gateway: $default_gateway
EOF
	
	# Make sure required info was retrieved
	if ("$interface_name $computer_public_ip_address $subnet_mask $default_gateway" =~ /undefined/) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve required network configuration for $computer_name:\n$configuration_info_string");
		return;
	}
	
	my $current_public_ip_address = $self->get_public_ip_address();
	my $current_public_subnet_mask = $self->get_public_subnet_mask();
	
	if ($current_public_ip_address eq $computer_public_ip_address) {
		notify($ERRORS{'DEBUG'}, 0, "public IP address of $computer_name is already set to $current_public_ip_address, attempting to set it again in case any parameters changed");
	}
	else {
		# Try to ping the address to make sure it is not in use
		if (_pingnode($computer_public_ip_address)) {
			notify($ERRORS{'WARNING'}, 0, "ip_address $computer_public_ip_address is pingable, can not assign to $computer_name ");
			return;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "attempting to set static public IP address on $computer_name:\n$configuration_info_string");
	
	# Delete any default routes
	$self->delete_default_routes();
	
	# Delete cached network configuration information so it is retrieved next time it is needed
	delete $self->{network_configuration};
	
	# Set the static public IP address
	my $command = "$system32_path/netsh.exe interface ip set address name=\"$interface_name\" source=static addr=$computer_public_ip_address mask=$subnet_mask gateway=$default_gateway gwmetric=0";
	my ($exit_status, $output) = $self->execute($command, 1, 60, 3);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to set static public IP address");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to set static public IP address, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "set static public IP address: $computer_public_ip_address/$subnet_mask, default gateway: $default_gateway");
	}

	$self->set_static_default_gateway() || return;
	
	$self->set_static_dns_servers() || return;
	
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 set_static_dns_servers

 Parameters  : none
 Returns     : boolean
 Description : Configures the computer to use static DNS server addresses rather
               than addresses obtained from DHCP. Static addresses will only be
               used if either of the following conditions is true:
               1. Server request is configured with specific DNS servers
               2. The management node is configured to assign static public IP
                  addresses and the public DNS server list is not empty
               3. The image is configured to use Active Directory authentication
                  and the configured domain's DNS server list is not empty
               
               If multiple conditions are true, only the DNS servers configured
               for the first condition met are used.

=cut

sub set_static_dns_servers {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name	= $self->data->get_computer_short_name();
	my $image_name	= $self->data->get_image_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $mn_public_ip_configuration = $self->data->get_management_node_public_ip_configuration();
	my @mn_dns_servers = $self->data->get_management_node_public_dns_servers();
	
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	my @domain_dns_servers = $self->data->get_image_domain_dns_servers();
	
	my @server_request_dns_servers = $self->data->get_server_request_dns_servers();
	
	my @dns_servers;
	if (@server_request_dns_servers) {
		@dns_servers = @server_request_dns_servers;
		notify($ERRORS{'DEBUG'}, 0, "server request specific DNS servers will be statically set on $computer_name: " . join(", ", @dns_servers));
	}
	elsif ($domain_dns_name && @domain_dns_servers) {
		@dns_servers = @domain_dns_servers;
		notify($ERRORS{'DEBUG'}, 0, "$image_name image is configured for Active Directory, domain DNS servers will be statically set on $computer_name: " . join(", ", @dns_servers));
	}
	elsif ($mn_public_ip_configuration =~ /static/i && @mn_dns_servers) {
		@dns_servers = @mn_dns_servers;
		notify($ERRORS{'DEBUG'}, 0, "management node IP configuration set to $mn_public_ip_configuration, management node DNS servers will be statically set on $computer_name: " . join(", ", @dns_servers));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$computer_name not configured to use static DNS servers:\n" .
			"management node IP configuration               : $mn_public_ip_configuration\n" .
			"management node DNS servers configured         : " . (@mn_dns_servers ? 'yes' : 'no') . "\n" .
			"image configured for Active Directory          : " . ($domain_dns_name ? 'yes' : 'no') . "\n" .
			"Active Directory domain DNS servers configured : " . (@domain_dns_servers ? 'yes' : 'no')
		);
		return;
	}
	
	my $private_interface_name = $self->get_private_interface_name();
	if (!$private_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to set static DNS servers on $computer_name, private interface name could not be retrieved");
		return;
	}
	
	my $public_interface_name = $self->get_public_interface_name();
	if (!$public_interface_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to set static DNS servers on $computer_name, public interface name could not be retrieved");
		return;
	}
	
	for my $interface_name ($private_interface_name, $public_interface_name) {
		# Get the first address from the array - the netsh.exe syntax is different for the first/primary DNS server and others
	
		# netsh interface ipv4 set dnsservers [name=]<string> [source=]dhcp|static [[address=]<IP address>|none] [[register=]none|primary|both] [[validate=]yes|no]
		# name - The name or index of the interface.
		# source - One of the following values:
		#    dhcp: Sets DHCP as the source for configuring DNS servers for the specific interface.
		#    static: Sets the source for configuring DNS servers to local static configuration.
		# address - One of the following values:
		#    <IP address>: An IP address for a DNS server.
		#    none: Clears the list of DNS servers.
		# register - One of the following values:
		#    none: Disables Dynamic DNS registration.
		#    primary: Register under the primary DNS suffix only.
		#    both: Register under both the primary DNS suffix, as well as under the connection-specific suffix.
		# validate - Specifies whether validation of the DNS server setting will be performed. The value is yes by default.
		my $primary_dns_server = $dns_servers[0];
		my $command = "$system32_path/netsh.exe interface ipv4 set dnsservers name=\"$interface_name\" source=static address=$primary_dns_server validate=no";
		
		# netsh interface ipv4 add dnsservers [name=]<string> [address=]<IPv4 address> [[index=]<integer>] [[validate=]yes|no]
		# name         - The name or index of the interface where DNS servers are added.
		# address      - The IP address for the DNS server you are adding.
		# index        - Specifies the index (preference) for the specified DNS server address.
		# validate     - Specifies whether validation of the DNS server setting will be performed. The value is yes by default.
		for (my $i=1; $i<scalar(@dns_servers); $i++) {
			my $secondary_dns_server = $dns_servers[$i];
			$command .= " ; $system32_path/netsh.exe interface ipv4 add dnsservers name=\"$interface_name\" address=$secondary_dns_server validate=no";
		}
		
		my ($exit_status, $output) = $self->execute($command);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute command to configure static DNS servers for $interface_name interface on $computer_name: $command");
			return;
		}
		elsif ($exit_status ne '0') {
			notify($ERRORS{'WARNING'}, 0, "failed to configure static DNS servers for $interface_name interface on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
			return 0;
		}
		else {
			notify($ERRORS{'OK'}, 0, "configured static DNS servers for $interface_name interface on $computer_name: " . join(", ", @dns_servers));
		}
	}
	
	# Flush the DNS cache - not sure if this is necessary but AD computers sometimes have trouble finding things for some reason
	my $command = "$system32_path/ipconfig.exe /flushdns";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to flush DNS resolver cache on $computer_name: $command");
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to flush DNS resolver cache on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "flushed DNS resolver cache on $computer_name");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_default_routes

 Parameters  : 
 Returns     : If successful: true
               If failed: false
 Description : Deletes all default (0.0.0.0) routes.

=cut

sub delete_default_routes {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Delete all default routes
	my $route_delete_command = "route delete 0.0.0.0";
	my ($route_delete_exit_status, $route_delete_output) = $self->execute($route_delete_command);
	if (defined($route_delete_exit_status) && $route_delete_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "deleted all default routes");
	}
	elsif (defined($route_delete_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete all default routes, exit status: $route_delete_exit_status, output:\n@{$route_delete_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run ssh command to delete all default routes");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_static_default_gateway

 Parameters  : $default_gateway (optional)
 Returns     : boolean
 Description : Adds a persistent route to the default gateway for the public
               network.

=cut

sub set_static_default_gateway {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $default_gateway = shift || $self->get_correct_default_gateway();
	if (!$default_gateway) {
		notify($ERRORS{'WARNING'}, 0, "unable to set static default gateway on $computer_name, argument was not supplied and correct default gateway IP address could not be determined");
		return;
	}
	
	# Delete all default routes before adding
	# Do this only after successfully retrieving default gateway address
	if (!$self->delete_default_routes()) {
		notify($ERRORS{'WARNING'}, 0, "unable to delete existing default routes");
		return;
	}
	
	# Add a persistent route to the public default gateway
	my $route_add_command = "route -p ADD 0.0.0.0 MASK 0.0.0.0 $default_gateway METRIC 1";
	my ($route_add_exit_status, $route_add_output) = $self->execute($route_add_command);
	if (!defined($route_add_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to add persistent route to public default gateway: $default_gateway");
		return;
	}
	elsif ($route_add_exit_status ne '0' || grep(/failed/i, @$route_add_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to add persistent route to public default gateway: $default_gateway, exit status: $route_add_exit_status, command: '$route_add_command', output:\n" . join("\n", @$route_add_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "added persistent route to public default gateway: $default_gateway");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_volume_list

 Parameters  : None
 Returns     : If successful: array containing volume drive letters
               If failed: false
 Description : 

=cut

sub get_volume_list {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Echo the diskpart script to a temp file on the node
	my $for_command = 'for i in `ls /cygdrive 2>/dev/null`; do echo $i; done;';
	my ($for_exit_status, $for_output) = $self->execute($for_command, 1);
	if (defined($for_exit_status) && $for_exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "retrieved drive letter list under /cygdrive:\n" . join("\n", @$for_output));
	}
	elsif ($for_exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve drive letter list under /cygdrive, exit status: $for_exit_status, output:\n@{$for_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to retrieve drive letter list under /cygdrive");
		return;
	}
	
	my @drive_letters;
	for my $for_output_line (@$for_output) {
		if ($for_output_line =~ /^[a-z]$/) {
			push @drive_letters, $for_output_line;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unexpected output from for command: $for_output_line");
		}
	}
	
	return @drive_letters;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 configure_time_synchronization

 Parameters  : None
 Returns     : boolean
 Description : Configures the Windows Time service and synchronizes the time.

=cut

sub configure_time_synchronization {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $time_string_before = $self->get_current_computer_time('before configure_time_synchronization');
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name = $self->data->get_computer_node_name();
	
	my $time_source_variable;
	my $variable_name = "timesource|" . $self->data->get_management_node_hostname();
	my $variable_name_global = "timesource|global";
	if (is_variable_set($variable_name)) {
		$time_source_variable = get_variable($variable_name);
	}
	elsif (is_variable_set($variable_name_global)) {
		$time_source_variable = get_variable($variable_name_global);
	}
	else {
		$time_source_variable = 'pool.ntp.org';
	}
	
	my $key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DateTime\Servers';
	
	# Delete existing key
	$self->reg_delete($key);

	# Update the registry
	my $index = 1;
	my @time_sources = split(/[,;\s]/, $time_source_variable);
	my $manual_peer_list;
	for my $time_source (@time_sources) {
		# Remove leading and trailing spaces
		$time_source =~ s/(^\s+|\s+$)//g;
		
		# Make sure it isn't blank
		next unless $time_source =~ /\S/;
		
		$self->reg_add($key, $index, "REG_SZ", $time_source);
		$index++;
		
		$manual_peer_list .= ' ' if $manual_peer_list;
		$manual_peer_list .= $time_source;
	}
	
	# Make sure the service is stopped before calling /unregister or it will fail
	$self->stop_service('w32time');

	# Call /unregister the time service first - calling only /register doesn't seem to reset everything
	# Unexpected results may occur if this isn't done
	$self->get_current_computer_time('before unregister');
	my $unregister_command = "$system32_path/w32tm.exe /unregister";
	my ($unregister_exit_status, $unregister_output) = $self->execute({command => $unregister_command, timeout_seconds => 20, max_attempts => 1, display_output => 0});
	if (!defined($unregister_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to unregister W32Time on $computer_name: $unregister_command");
		return;
	}
	elsif ($unregister_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to unregister W32Time on $computer_name, exit status: $unregister_exit_status, command:\n$unregister_command\noutput:\n" . join("\n", @$unregister_output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "unregistered W32Time on $computer_name");
	}
	
	# Make sure no remnants are leftover
	$self->reg_delete('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time');
	
	# Call /register - registers w32time service and sets default configuration to the registry
	my $register_command = "$system32_path/w32tm.exe /register";
	my ($register_exit_status, $register_output) = $self->execute({command => $register_command, timeout_seconds => 20, max_attempts => 1, display_output => 0});
	if (!defined($register_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to register W32Time on $computer_name: $register_command");
		return;
	}
	elsif ($register_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to register W32Time on $computer_name, exit status: $register_exit_status, command:\n$register_command\noutput:\n" . join("\n", @$register_output));
	}
	else {
		notify($ERRORS{'OK'}, 0, "registered W32Time on $computer_name");
	}
	
	# Uncomment the next few lines for for debugging
	#my $debug_command = "$system32_path/w32tm.exe /debug /enable /file:C:/Windows/Debug/w32tm.log /size:1024000000 /entries:0-300";
	#my ($debug_exit_status, $debug_output) = $self->execute({command => $debug_command, timeout_seconds => 20, max_attempts => 1, display_output => 0});
	#if (!defined($debug_output)) {
	#	notify($ERRORS{'WARNING'}, 0, "failed to execute command to enable W32Time debugging on $computer_name: $debug_command");
	#	return;
	#}
	#elsif ($debug_exit_status ne '0') {
	#	notify($ERRORS{'WARNING'}, 0, "failed to enable W32Time debugging on $computer_name, exit status: $debug_exit_status, command:\n$debug_command\noutput:\n" . join("\n", @$debug_output));
	#}
	#else {
	#	notify($ERRORS{'OK'}, 0, "enabled W32Time debugging on $computer_name, output:\n" . join("\n", @$debug_output));
	#}

	# Only care about w32tm.exe config and sync duration
	my $start_time = time;
	
	# By default, Windows time service will only allow the time to be changes by 15 hours (54,000 seconds) or less
	# Set the following keys to allow any time adjustment
	# This must be done after w32tm.exe /register because that command will reset the values to the defaults
	$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config', 'MaxPosPhaseCorrection', 'REG_DWORD', '0xFFFFFFFF');
	$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config', 'MaxNegPhaseCorrection', 'REG_DWORD', '0xFFFFFFFF');
	
	# Start the service before calling /config or else /config will fail
	$self->start_service('w32time') || return;

	my $config_command = "$system32_path/w32tm.exe /config /manualpeerlist:\"$manual_peer_list\" /syncfromflags:manual";
	# The following argument shouldn't be necessary if the service is later restarted:
	$config_command .= " /update";
	my ($config_exit_status, $config_output) = $self->execute({command => $config_command, timeout_seconds => 20, max_attempts => 1, display_output => 0});
	if (!defined($config_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to configure W32Time on $computer_name: $config_command");
		return;
	}
	elsif ($config_exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to configure W32Time on $computer_name to use time source(s): $manual_peer_list, exit status: $config_exit_status, command:\n$config_command\noutput:\n" . join("\n", @$config_output));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "configured W32Time on $computer_name to use time source(s): $manual_peer_list");
	}
	
	# Restart the service
	# This shouldn't be necessary if the /config command above includes /update
	#$self->restart_service('w32time') || return;
	
	# Call /resync
	my $resync_command = "$system32_path/w32tm.exe /resync";
	$resync_command .= " /force";
	my ($resync_exit_status, $resync_output) = $self->execute({command => $resync_command, timeout_seconds => 20, max_attempts => 1, display_output => 0});
	if (!defined($resync_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to resync W32Time on $computer_name: $resync_command");
		return;
	}
	elsif (grep(/success/, @$resync_output)) {
		notify($ERRORS{'DEBUG'}, 0, "resynchronized W32Time on $computer_name, output:\n" . join("\n", @$resync_output));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "W32Time resynchronization may have failed on $computer_name:\n" . join("\n", @$resync_output));
	}
	
	my $duration = (time - $start_time);
	
	# Set the w32time service startup mode to auto
	if ($self->set_service_startup_mode('w32time', 'auto')) {
		notify($ERRORS{'DEBUG'}, 0, "set w32time service startup mode to auto");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set w32time service startup mode to auto");
		return;
	}
	
	# For debugging:
	#$self->get_time_service_events() if $self->can('get_time_service_events');
	
	# Set the maximum time change parameters back to the defaults for security
	$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config', 'MaxPosPhaseCorrection', 'REG_DWORD', 50000000);
	$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\W32Time\Config', 'MaxNegPhaseCorrection', 'REG_DWORD', 50000000);
	
	my $time_string_after = $self->get_current_computer_time('after configure_time_synchronization');
	
	notify($ERRORS{'DEBUG'}, 0, "configured time synchronization duration: $duration seconds\n" .
		"time before configuration : $time_string_before\n" .
		"time after configuration  : $time_string_after"
	);
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_computer_time

 Parameters  : $message (optional)
 Returns     : string
 Description : Used for debugging and troubleshooting purposes. Simply displays
               the current date, time, and timezone offset according to the
               computer. Example:
               2017-08-02 11:35:32 PDT -07:00

=cut

sub get_current_computer_time {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $message = shift;
	
	my $computer_name = $self->data->get_computer_node_name();
	
	#my $command = 'cmd.exe /c "echo %date% %time%"';
	my $command = 'date +"%Y-%m-%d %H:%M:%S %Z %:z"';
	my ($exit_status, $output) = $self->execute({command => $command, max_attempts => 1, display_output => 0});
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve current time on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current time on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	my ($current_time) = grep(/\d:/, @$output);
	if ($current_time) {
		notify($ERRORS{'OK'}, 0, "retrieved current time on $computer_name: $current_time" . (defined($message) ? " ($message)" : ''));
		return $current_time;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to parse output in order to retrieve current time on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_64_bit

 Parameters  : None
 Returns     : If 64-bit: true
               If 32-bit: false
 Description : Determines if Windows OS is 64 or 32-bit.

=cut

sub is_64_bit {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Check if architecture has previously been determined
	if (defined($self->{OS_ARCHITECTURE}) && $self->{OS_ARCHITECTURE} eq '64') {
		#notify($ERRORS{'DEBUG'}, 0, '64-bit Windows OS previously detected');
		return 1;
	}
	elsif (defined($self->{OS_ARCHITECTURE}) && $self->{OS_ARCHITECTURE} eq '32') {
		#notify($ERRORS{'DEBUG'}, 0, '32-bit Windows OS previously detected');
		return 0;
	}
	
	my $registry_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
	my $registry_value = 'PROCESSOR_IDENTIFIER';
	
	# Run reg.exe QUERY
	my $query_registry_command .= "reg.exe QUERY \"$registry_key\" /v \"$registry_value\"";
	my ($query_registry_exit_status, $query_registry_output) = $self->execute($query_registry_command, 0);
	
	if (!defined($query_registry_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to query registry key: $registry_key, value: $registry_value");
		return;
	}
	
	my ($output_line) = grep(/^\s*$registry_value/i, @$query_registry_output);
	if (!$output_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to find registry value line in reg.exe output:\n" . join("\n", @$query_registry_output));
		return;
	}
	
	my ($registry_data) = $output_line =~ /\s*$registry_value\s+[\w_]+\s+(.*)/;
	
	if ($registry_data && $registry_data =~ /64/) {
		$self->{OS_ARCHITECTURE} = 64;
		notify($ERRORS{'DEBUG'}, 0, "64-bit Windows OS detected, PROCESSOR_IDENTIFIER: $registry_data");
		return 1;
	}
	elsif ($registry_value) {
		$self->{OS_ARCHITECTURE} = 32;
		notify($ERRORS{'DEBUG'}, 0, "32-bit Windows OS detected, PROCESSOR_IDENTIFIER: $registry_data");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if OS is 32 or 64-bit, failed to query PROCESSOR_IDENTIFIER registry key, reg.exe output:\n" . join("\n", @$query_registry_output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_system32

 Parameters  : None
 Returns     : If 64-bit: true
               If 32-bit: false
 Description : 

=cut

sub get_system32_path {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Check if architecture has previously been determined
	return $self->{SYSTEM32_PATH} if $self->{SYSTEM32_PATH};
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $is_64_bit = $self->is_64_bit();
	if (!defined($is_64_bit)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to determine the architecture of the Windows OS installed on $computer_name, unable to determine correct system32 path");
		return;
	}
	elsif ($is_64_bit) {
		$self->{SYSTEM32_PATH} = 'C:/Windows/Sysnative';
		if (!$self->file_exists($self->{SYSTEM32_PATH})) {
			$self->{SYSTEM32_PATH} = 'C:/Windows/System32';
			notify($ERRORS{'DEBUG'}, 0, "64-bit Windows OS installed on $computer_name, C: Windows Sysnative not found, using $self->{SYSTEM32_PATH}");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "64-bit Windows OS installed on $computer_name, using $self->{SYSTEM32_PATH}");
		}
	}
	else {
		$self->{SYSTEM32_PATH} = 'C:/Windows/System32';
		notify($ERRORS{'DEBUG'}, 0, "32-bit Windows OS installed on $computer_name, using $self->{SYSTEM32_PATH}");
	}
	
	return $self->{SYSTEM32_PATH};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_product_name

 Parameters  : None
 Returns     : If successful: string containing Windows product name
               If failed: false
 Description : Retrieves the Windows product name from the registry. This is
               stored at:
               HKLM\Software\Microsoft\Windows NT\CurrentVersion\ProductName
               
               The product name stored in the registry is used in the
               winProductKey table to match a product key up with a product. It
               must match exactly. Known strings for some versions of Windows:
               "Microsoft Windows XP"
               "Microsoft Windows Server 2003"
               "Windows Server (R) 2008 Datacenter"
               "Windows Vista (TM) Enterprise"

=cut

sub get_product_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Check if product name has previously been retrieved from registry
	if ($self->{PRODUCT_NAME}) {
		notify($ERRORS{'DEBUG'}, 0, "Windows product name previously retrieved: $self->{PRODUCT_NAME}");
		return $self->{PRODUCT_NAME};
	}
	
	# Get the Windows product name from the registry
	my $product_name = $self->reg_query('HKLM/Software/Microsoft/Windows NT/CurrentVersion', 'ProductName');
	if ($product_name) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved Windows product name: $product_name");
		$self->{PRODUCT_NAME} = $product_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve Windows product name from registry");
		return;
	}
	
	return $self->{PRODUCT_NAME};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 format_path_unix

 Parameters  : path
 Returns     : If successful: path formatted for Unix
               If failed: false
 Description : 

=cut

sub format_path_unix {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Replace all forward slashes and backslashes with a single forward slash
	$path =~ s/[\/\\]+/\//g;
	
	# Escape all spaces
	$path =~ s/ /\\ /g;
	
	# Change %VARIABLE% to $VARIABLE
	$path =~ s/\%(.+)\%/\$$1/g;
	
	#notify($ERRORS{'DEBUG'}, 0, "formatted path for Unix: $path");
	return $path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 format_path_dos

 Parameters  : path
 Returns     : If successful: path formatted for DOS
               If failed: false
 Description : 

=cut

sub format_path_dos {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	# Get the path argument
	my $path = shift;
	if (!$path) {
		notify($ERRORS{'WARNING'}, 0, "path argument was not specified");
		return;
	}
	
	# Replace all forward slashes with 2 backslashes
	$path =~ s/[\/\\]/\\\\/g;
	
	# Change $VARIABLE to %VARIABLE%
	$path =~ s/\$([^\\]+)/\%$1\%/g;
	
	#notify($ERRORS{'DEBUG'}, 0, "formatted path for DOS: $path");
	return $path;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_system_restore

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Sets registry key to disable Windows System Restore. Disabling
               System Restore helps reduce the image size.

=cut

sub disable_system_restore {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $registry_string .= <<"EOF";
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\SystemRestore]
"DisableConfig"=dword:00000001
"DisableSR"=dword:00000001
EOF

	# Import the string into the registry
	if ($self->import_registry_string($registry_string)) {
		notify($ERRORS{'OK'}, 0, "disabled system restore");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable system restore");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 user_logged_in

 Parameters  : 
 Returns     : 
 Description : 

=cut

sub user_logged_in {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift || $self->data->get_user_login_id();
	
	my @logged_in_users = $self->get_logged_in_users();
	if (grep { $username eq $_ } @logged_in_users) {
		notify($ERRORS{'DEBUG'}, 0, "$username is logged in to $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$username is NOT logged in to $computer_node_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_logged_in_users

 Parameters  : none
 Returns     : array
 Description : Retrieves the names of users logged in to the computer.

=cut

sub get_logged_in_users {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;

	# Run qwinsta.exe to display terminal session information
	# Set command timeout argument because this command occasionally hangs
	my $command = "$system32_path/qwinsta.exe";
	my ($exit_status, $output) = $self->execute({
		command => $command,
		timeout => 60,
	});
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run qwinsta.exe command on $computer_node_name");
		return;
	}
	elsif (!grep(/USERNAME/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve logged in users on $computer_node_name, command: $command, output:\n" . join("\n", @$output));
		return;
	}

	# SESSIONNAME       USERNAME                 ID  STATE   TYPE        DEVICE
	# services                                    0  Disc
	#                   root                      1  Disc
	# console                                     2  Conn
	#>rdp-tcp#1         Administrator             3  Active  rdpwd
	# rdp-tcp#2         test user                 4  Active  rdpwd
	# rdp-tcp                                 65536  Listen
	my @usernames;
	for my $line (@$output) {
		my ($session_name, $username, $session_id, $state) = $line =~ /^[\s>]([^\s]+)?\s+(.+[^\s])?\s+(\d+)\s+(Active)/i;
		push @usernames, $username if defined($username);
	}
	
	my $username_count = scalar(@usernames);
	notify($ERRORS{'DEBUG'}, 0, "$username_count user" . ($username_count == 1 ? '' : 's') . " logged in to $computer_node_name: " . join(', ', @usernames));
	return @usernames;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 wait_for_logoff

 Parameters  : Username (optional), maximum number of minutes to wait (optional)
 Returns     : True if user is not logged in
               False if user is still logged in after waiting
 Description : Waits the specified amount of time for the user to log off. The
               default username is the reservation user and the default time to
               wait is 2 minutes.

=cut

sub wait_for_logoff {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Attempt to get the username from the arguments
	# If no argument was supplied, use the user specified in the DataStructure
	my $username = shift;
	
	# Remove spaces from beginning and end of username argument
	# Fixes problem if string containing only spaces is passed
	$username =~ s/(^\s+|\s+$)//g if $username;
	
	# Check if username argument was passed
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}

	# Attempt to get the total number of minutes to wait from the arguments
	my $total_wait_minutes = shift;
	if (!defined($total_wait_minutes) || $total_wait_minutes !~ /^\d+$/) {
		$total_wait_minutes = 2;
	}

	# Looping configuration variables
	# Seconds to wait in between loop attempts
	my $attempt_delay = 5;
	# Total loop attempts made
	# Add 1 to the number of attempts because if you're waiting for x intervals, you check x+1 times including at 0
	my $attempts = ($total_wait_minutes * 12) + 1;

	notify($ERRORS{'DEBUG'}, 0, "waiting for $username to logoff, maximum of $total_wait_minutes minutes");

	# Loop until computer is user is not logged in
	for (my $attempt = 1; $attempt <= $attempts; $attempt++) {
		if ($attempt > 1) {
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt - 1) . "/" . ($attempts - 1) . ": $username is logged in, sleeping for $attempt_delay seconds");
			sleep $attempt_delay;
		}

		if (!$self->user_logged_in($username)) {
			notify($ERRORS{'OK'}, 0, "$username is NOT logged in to $computer_node_name, returning 1");
			return 1;
		}
	}

	# Calculate how long this waited
	my $total_wait = ($attempts * $attempt_delay);
	notify($ERRORS{'WARNING'}, 0, "$username is still logged in to $computer_node_name after waiting for $total_wait seconds");
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_product_key

 Parameters  : $affiliation_identifier (optional), $product_name (optional)
 Returns     : If successful: string containing product key
               If failed: false
 Description : Retrieves the Windows product key from the database. This is
               stored in the winProductKey table.
               
               Optional affiliation identifier and product name arguments may be
               passed. Either both arguments must be passed or none. The
               affiliation identifier may either be an affiliation ID or name.
               If passed, the only data returned will be the data matching that
               specific identifier. Global affiliation data will not be
               returned.
               
               If the affiliation identifier argument is not passed, the
               affiliation is determined by the affiliation of the owner of the
               image for the reservation. If a product key has not been
               configured for that specific affiliation, the product key
               configured for the Global affiliation is returned.

=cut

sub get_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Remember if this sub was called with arguments
	# Used to determine whether or not Global activation data will be checked
	# If affiliation ID argument is specified, assume caller only wants the data for that affiliation and not the Global data
	my $include_global;
	if (scalar(@_) == 2) {
		$include_global = 0;
		notify($ERRORS{'DEBUG'}, 0, "subroutine was called with arguments, global affiliation data will be ignored");
	}
	elsif (scalar(@_) == 0) {
		$include_global = 1;
		notify($ERRORS{'DEBUG'}, 0, "subroutine was NOT called with arguments, global affiliation data will be included");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "subroutine argument count = " . scalar(@_) . ", it must only be called with 0 or 2 arguments");
		return;
	}
	
	# Get the affiliation identifer, may be ID or name
	my $affiliation_identifier = shift;
	if (!defined($affiliation_identifier)) {
		$affiliation_identifier = $self->data->get_image_affiliation_id();
	}
	if (!defined($affiliation_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation identifier argument was not passed and could not be determined from image");
		return;
	}
	
	# Get the product name from the registry on the computer
	my $product_name = shift || $self->get_product_name();
	if (!$product_name) {
		notify($ERRORS{'WARNING'}, 0, "product name argument was not passed and could not be determined from computer");
		return;
	}
	
	# Normalize the product name string from the registry
	# Remove Microsoft from the beginning - some products have this and some don't
	$product_name =~ s/Microsoft//ig;
	# Remove anything in parenthesis such as (R) or (TM)
	$product_name =~ s/\(.*\)//ig;
	# Replace spaces with %
	$product_name =~ s/\s/%/ig;
	# Add % to the beginning and end
	$product_name = "%$product_name%";
	# Replace multiple % characters with a single %
	$product_name =~ s/%+/%/ig;
	
	# Create the affiliation-specific select statement
	# Check if the affiliation identifier is a number or word
	# If a number, use affiliation.id directly
	# If a word, reference affiliation.name
	my $affiliation_select_statement;
	if ($affiliation_identifier =~ /^\d+$/) {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is a number, retrieving winProductKey.affiliationid=$affiliation_identifier");
		$affiliation_select_statement = <<EOF;
SELECT
winProductKey.*
FROM
winProductKey
WHERE
winProductKey.productname LIKE '$product_name'
AND winProductKey.affiliationid = $affiliation_identifier
EOF
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is NOT a number, retrieving affiliation.name=$affiliation_identifier");
		$affiliation_select_statement = <<EOF;
SELECT
winProductKey.*
FROM
winProductKey,
affiliation
WHERE
winProductKey.productname LIKE '$product_name'
AND winProductKey.affiliationid = affiliation.id
AND affiliation.name LIKE '$affiliation_identifier'
EOF
	}
	
	# Create the select statement
	my $global_select_statement = <<EOF;
SELECT
winProductKey.*
FROM
winProductKey,
affiliation
WHERE
winProductKey.productname LIKE '$product_name'
AND winProductKey.affiliationid = affiliation.id
AND affiliation.name LIKE 'Global'
EOF
	
	# Call the database select subroutine
	my @affiliation_rows = database_select($affiliation_select_statement);
	
	# Get the rows for the Global affiliation if this subroutine wasn't called with arguments
	my @global_rows = ();
	if ($include_global) {
		@global_rows = database_select($global_select_statement);
	}
	
	# Create an array containing the combined rows
	my @combined_rows = (@affiliation_rows, @global_rows);

	# Check to make sure rows were returned
	if (!@combined_rows) {
		notify($ERRORS{'OK'}, 0, "winProductKey table does not contain information for affiliation: $affiliation_identifier, product: '$product_name'");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved rows from winProductKey table for affiliation=$affiliation_identifier, product=$product_name:\n" . format_data(\@combined_rows));
	
	my $product_key = $combined_rows[0]->{productkey};
	notify($ERRORS{'DEBUG'}, 0, "returning product key: $product_key");
	
	return $product_key;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_product_key_info

 Parameters  : none
 Returns     : hash reference
 Description : Returns the contents of the winProductKey table as a hash
               reference. The hash keys are the affiliation IDs.

=cut

sub get_product_key_info {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Create the select statement
	my $select_statement = <<EOF;
SELECT
*
FROM
winProductKey
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	# Transform the array of database rows into a hash
	my %product_key_info;
	map { $product_key_info{$_->{affiliationid}}{$_->{productname}} = $_->{productkey} } @selected_rows;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved product key info:\n" . format_data(\%product_key_info));
	return \%product_key_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_kms_server_info

 Parameters  : none
 Returns     : hash reference
 Description : Returns the contents of the winKMS table as a hash
               reference. The hash keys are the affiliation IDs.

=cut

sub get_kms_server_info {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Create the select statement
	my $select_statement = <<EOF;
SELECT
*
FROM
winKMS
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);
	
	# Transform the array of database rows into a hash
	my %kms_server_info;
	map { $kms_server_info{$_->{affiliationid}}{$_->{address}} = $_->{port} } @selected_rows;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved KMS server info:\n" . format_data(\%kms_server_info));
	return \%kms_server_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_product_key

 Parameters  : $affiliation_id, $product_name, $product_key
 Returns     : If successful: true
               If failed: false
 Description : Inserts or updates a row in the winProductKey table in the
               database.

=cut

sub set_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get and check the arguments
	my ($affiliation_identifier, $product_name, $product_key) = @_;
	if (!defined($affiliation_identifier) || !defined($product_name) || !defined($product_key)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation ID, product name, and product key arguments not passed correctly");
		return;
	}
	
	# Create the insert statement
	# Check if the affiliation identifier is a number or word
	# If a number, set affiliation.id directly
	# If a word, reference affiliation.name
	my $insert_statement;
	if ($affiliation_identifier =~ /^\d+$/) {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is a number, setting winProductKey.affiliationid=$affiliation_identifier");
		$insert_statement = <<"EOF";
INSERT INTO winProductKey
(
affiliationid,
productname,
productkey
)
VALUES
(
'$affiliation_identifier',
'$product_name',
'$product_key'
)
ON DUPLICATE KEY UPDATE
affiliationid=VALUES(affiliationid),
productname=VALUES(productname),
productkey=VALUES(productkey)
EOF
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is NOT a number, setting affiliation.name=$affiliation_identifier");
		$insert_statement = <<"EOF";
INSERT INTO winProductKey
(
affiliationid,
productname,
productkey
)
VALUES
(
(SELECT id FROM affiliation WHERE name='$affiliation_identifier'),
'$product_name',
'$product_key'
)
ON DUPLICATE KEY UPDATE
affiliationid=VALUES(affiliationid),
productname=VALUES(productname),
productkey=VALUES(productkey)
EOF
	}
	
	# Execute the insert statement, the return value should be the id of the row
	my $insert_result = database_execute($insert_statement);
	if (defined($insert_result)) {
		notify($ERRORS{'DEBUG'}, 0, "set product key in database:\naffiliation ID: $affiliation_identifier\nproduct name: $product_name\nproduct key: $product_key");
	
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set product key in database:\naffiliation ID: $affiliation_identifier\nproduct name: $product_name\nproduct key: $product_key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_product_key

 Parameters  : $affiliation_id, $product_name
 Returns     : If successful: true
               If failed: false
 Description : Deletes a row from the winProductKey table in the database.

=cut

sub delete_product_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get and check the arguments
	my ($affiliation_id, $product_name, $product_key) = @_;
	if (!defined($affiliation_id) || !defined($product_name) || !defined($product_key)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation ID, product name, and product key arguments not passed correctly");
		return;
	}
	
	# Construct the delete statement
	my $delete_statement = <<"EOF";
DELETE FROM
winProductKey
WHERE
affiliationid = $affiliation_id
AND productname = '$product_name'
AND productkey = '$product_key'
EOF

	# Execute the delete statement
	my $delete_result = database_execute($delete_statement);
	if (defined($delete_result)) {
		notify($ERRORS{'DEBUG'}, 0, "deleted product key from database:\naffiliation ID: $affiliation_id\nproduct name: $product_name\nproduct key: $product_key, result: $delete_result");
	
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete product key from database:\naffiliation ID: $affiliation_id\nproduct name: $product_name\nproduct key: $product_key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_kms_server

 Parameters  : $affiliation_id, $address
 Returns     : If successful: true
               If failed: false
 Description : Deletes a row from the winKMS table in the database.

=cut

sub delete_kms_server {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get and check the arguments
	my ($affiliation_id, $address) = @_;
	if (!defined($affiliation_id) || !defined($address)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation ID and KMS server address arguments not passed correctly");
		return;
	}
	
	# Construct the delete statement
	my $delete_statement = <<"EOF";
DELETE FROM
winKMS
WHERE
affiliationid = $affiliation_id
AND address = '$address'
EOF

	# Execute the delete statement
	my $delete_result = database_execute($delete_statement);
	if (defined($delete_result)) {
		notify($ERRORS{'DEBUG'}, 0, "deleted KMS server from database:\naffiliation ID: $affiliation_id\naddress: $address, result: $delete_result");
	
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete product key from database:\naffiliation ID: $affiliation_id\naddress: $address");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_kms_servers

 Parameters  : $affiliation_identifier (optional)
 Returns     : If successful: reference to array of hashes
               If failed: false
 Description : Retrieves the KMS server data from the database. This is
               stored in the winKMS table.
               
               An optional affiliation identifier argument may be passed. This
               may either be an affiliation ID or name. If passed, the only data
               returned will be the data matching that specific identifier.
               Global affiliation data will not be returned.
               
               If the affiliation identifier argument is not passed, the
               affiliation is determined by the affiliation of the owner of the
               image for the reservation. If a KMS server has not been
               configured for that specific affiliation, the KMS server
               configured for the Global affiliation is returned.
               
               This subroutine returns an array reference. Each array element
               contains a hash reference representing a row in the winKMS table.
               
               Example of returned data:
               @{$kms_servers}[0] =
                  |--{address} = 'kms.affiliation.edu'
                  |--{affiliationid} = '1'
                  |--{port} = '1688'
               @{$kms_servers}[1] =
                  |--{address} = 'kms.global.edu'
                  |--{affiliationid} = '0'
                  |--{port} = '1688'
                  
               Example usage:
               my $kms_servers = $self->os->get_kms_servers();
               my $kms_address = @{$kms_servers[0]}->{address};

=cut

sub get_kms_servers {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Remember if this sub was called with arguments
	# Used to determine whether or not global affiliation data will be checked
	my $include_global;
	if (scalar(@_) == 1) {
		$include_global = 0;
		notify($ERRORS{'DEBUG'}, 0, "subroutine was called with an affiliation argument, global affiliation data will be ignored");
	}
	elsif (scalar(@_) == 0) {
		$include_global = 1;
		notify($ERRORS{'DEBUG'}, 0, "subroutine was NOT called with arguments, global affiliation data will be included");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "subroutine argument count = " . scalar(@_) . ", it must only be called with 0 or 1 arguments");
		return;
	}
	
	# Get the image affiliation identifier, may be ID or name
	my $affiliation_identifier = shift;
	if (!defined($affiliation_identifier)) {
		$affiliation_identifier = $self->data->get_image_affiliation_id();
	}
	if (!defined($affiliation_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation argument was not passed and could not be determined from image");
		return;
	}
	
	# Create the affiliation-specific select statement
	# Check if the affiliation identifier is a number or word
	# If a number, use affiliation.id directly
	# If a word, reference affiliation.name
	my $affiliation_select_statement;
	if ($affiliation_identifier =~ /^\d+$/) {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is a number, retrieving winKMS.affiliationid=$affiliation_identifier");
		$affiliation_select_statement = <<EOF;
SELECT
winKMS.*
FROM
winKMS
WHERE
winKMS.affiliationid = $affiliation_identifier
EOF
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is NOT a number, retrieving affiliation.name=$affiliation_identifier");
		$affiliation_select_statement .= <<EOF;
SELECT
winKMS.*
FROM
winKMS,
affiliation
WHERE
winKMS.affiliationid = affiliation.id
AND affiliation.name LIKE '$affiliation_identifier'
EOF
	}
	
	# Create the Global affiliation select statement
	my $global_select_statement .= <<EOF;
SELECT
winKMS.*
FROM
winKMS,
affiliation
WHERE
winKMS.affiliationid = affiliation.id
AND affiliation.name LIKE 'Global'
EOF

	# Call the database select subroutine
	my @affiliation_rows = database_select($affiliation_select_statement);
	
	# Get the rows for the Global affiliation if this subroutine wasn't called with arguments
	my @global_rows = ();
	if ($include_global) {
		@global_rows = database_select($global_select_statement);
	}
	
	# Create an array containing the combined rows
	my @combined_rows = (@affiliation_rows, @global_rows);

	# Check to make sure rows were returned
	if (!@combined_rows) {
		notify($ERRORS{'OK'}, 0, "entry does not exist in winKMS table for affiliation=$affiliation_identifier");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "returning row array from winKMS table for affiliation=$affiliation_identifier:\n" . format_data(\@combined_rows));
	return \@combined_rows;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_kms_server

 Parameters  : $affiliation_id, $address, $port (optional)
 Returns     : If successful: true
               If failed: false
 Description : Inserts or updates a row in the winKMS table in the database.

=cut

sub set_kms_server {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get and check the arguments
	my ($affiliation_identifier, $address, $port) = @_;
	if (!defined($affiliation_identifier) || !defined($address)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation ID and KMS address arguments not passed correctly");
		return;
	}
	
	# Set the default port if argument wasn't passed
	if (!defined($port)) {
		$port = 1688;
	}
	
		# Create the insert statement
	# Check if the affiliation identifier is a number or word
	# If a number, set affiliation.id directly
	# If a word, reference affiliation.name
	my $insert_statement;
	if ($affiliation_identifier =~ /^\d+$/) {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is a number, setting winKMS.affiliationid=$affiliation_identifier");
		$insert_statement = <<"EOF";
INSERT INTO winKMS
(
affiliationid,
address,
port
)
VALUES
(
'$affiliation_identifier',
'$address',
'$port'
)
ON DUPLICATE KEY UPDATE
affiliationid=VALUES(affiliationid),
address=VALUES(address),
port=VALUES(port)
EOF
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "affiliation identifier is NOT a number, setting affiliation.name=$affiliation_identifier");
		$insert_statement = <<"EOF";
INSERT INTO winKMS
(
affiliationid,
address,
port
)
VALUES
(
(SELECT id FROM affiliation WHERE name='$affiliation_identifier'),
'$address',
'$port'
)
ON DUPLICATE KEY UPDATE
affiliationid=VALUES(affiliationid),
address=VALUES(address),
port=VALUES(port)
EOF
	}

	# Execute the insert statement, the return value should be the id of the row
	my $insert_result = database_execute($insert_statement);
	if (defined($insert_result)) {
		notify($ERRORS{'OK'}, 0, "set KMS address in database:\naffiliation ID: $affiliation_identifier\naddress: $address\nport: $port");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set KMS address in database:\naffiliation ID: $affiliation_identifier\naddress: $address\nport: $port");
		return;
	}
	
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_driver_inf_paths

 Parameters  : Driver class (optional)
 Returns     : Array containing driver .inf paths
 Description : This subroutine searches the node configuration drivers directory
               on the computer for .inf files and returns an array containing
               the paths of the .inf files. The node configuration drivers
               directory is: C:\cygwin\home\root\VCL\Drivers
               
               An optional driver class argument can be supplied which will
               cause this subroutine to only return drivers matching the class
               specified. Each driver .inf file should have a Class= line which
               specified the type of device the driver is intended for. This
               argument can be a regular expression. For example, to search for
               all storage drivers, pass the following string to this
               subroutine:
               (scsiadapter|hdc)
               
               The driver paths are formatted with forward slashes.

=cut

sub get_driver_inf_paths {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if a driver class argument was specified
	my $driver_class = shift;
	if ($driver_class) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to locate driver .inf paths matching class: $driver_class");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "attempting to locate driver .inf paths matching any class");
	}
	
	my $drivers_directory = $self->get_node_configuration_directory() . '/Drivers';
	
	# Find the paths of .inf files in the drivers directory with a Class=SCSIAdapter or HDC line
	# These are the storage driver .inf files
	my @inf_paths = ();
	my $grep_command .= '/usr/bin/grep.exe -Eirl --include="*.[iI][nN][fF]" ';
	if ($driver_class) {
		$grep_command .= '"class[ ]*=[ ]*' . $driver_class . '" ';
	}
	else {
		$grep_command .= '".*" ';
	}
	$grep_command .= $drivers_directory;
	
	my ($grep_exit_status, $grep_output) = $self->execute($grep_command, 1);
	if (defined($grep_exit_status) && $grep_exit_status > 1) {
		notify($ERRORS{'WARNING'}, 0, "failed to find driver paths, exit status: $grep_exit_status, output:\n@{$grep_output}");
		return;
	}
	elsif (defined($grep_output)) {
		my @inf_paths = grep(/:[\\\/]/, @$grep_output);
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@inf_paths) . " driver .inf paths, grep output:\n". join("\n", @$grep_output));
		return @inf_paths;
	}
	elsif (defined($grep_exit_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to find driver paths, exit status: $grep_exit_status, output:\n@{$grep_output}");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to find driverpaths");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_device_path_key

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Determines the paths to all of the driver .inf files copied to
               the computer and sets the following Windows registry key:
               HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DevicePath
               
               This key contains paths to driver .inf files. Windows searches
               these files when attempting to load a device driver.

=cut

sub set_device_path_key {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $device_path_value;
	
	# Find the paths of .inf files in the drivers directory
	my @inf_paths = $self->get_driver_inf_paths();
	if (!@inf_paths || $inf_paths[0] eq '0') {
		# No driver paths were found, just use the inf path
		$device_path_value = '%SystemRoot%\\inf';
		notify($ERRORS{'DEBUG'}, 0, "no driver .inf paths were found");
	}
	else {
		# Remove the .inf filenames from the paths
		map(s/\/[^\/]*$//, @inf_paths);
		
		# Remove duplicate paths, occurs if a directory has more than 1 .inf file
		my %inf_path_hash;
		my @inf_paths_unique = grep { !$inf_path_hash{$_}++ } @inf_paths;
		notify($ERRORS{'DEBUG'}, 0, "found " . scalar(@inf_paths_unique) . " unique driver .inf paths");
		
		# Assemble the device path value
		$device_path_value = '%SystemRoot%\\inf;' . join(";", @inf_paths_unique);
		
		# Replace forward slashes with backslashes
		$device_path_value =~ s/\//\\/g;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "device path value: $device_path_value");
	
	# Attempt to set the DevicePath key
	my $registry_key = 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion';
	if ($self->reg_add($registry_key, 'DevicePath', 'REG_EXPAND_SZ', $device_path_value)) {
		notify($ERRORS{'OK'}, 0, "set the DevicePath registry key");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the DevicePath registry key");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_hibernation

 Parameters  : none
 Returns     : boolean
 Description : Enables the hibernation feature.

=cut

sub enable_hibernation {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	# Rename disableGuestHibernate.dll if it exists, this can prevent hibernation from working as expected
	my $disable_hibernate_file_path = 'C:\Program Files\VMware\VMware Tools\plugins\vmsvc\disableGuestHibernate.dll';
	if ($self->file_exists($disable_hibernate_file_path)) {
		$self->move_file($disable_hibernate_file_path, "$disable_hibernate_file_path.disabled");
	}
	
	# Run powercfg.exe to enable hibernation
	my $command = "$system32_path/powercfg.exe -HIBERNATE ON";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to enable hibernation on $computer_node_name");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "enabled hibernation on $computer_node_name" . (scalar(@$output) ? ", output:\n" . join("\n", @$output) : ''));
	}
	elsif (grep(/PAE mode/i, @$output)) {
		# The following may be displayed:
		#    Hibernation failed with the following error: The request is not supported.
		#    The following items are preventing hibernation on this system.
		#    The system is running in PAE mode, and hibernation is not allowed in PAE mode.
		notify($ERRORS{'OK'}, 0, "hibernation NOT enabled because $computer_node_name is running in PAE mode");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable hibernation on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_hibernation

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables hibernation mode.

=cut

sub disable_hibernation {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	# Rename disableGuestHibernate.dll if it exists, this can prevent hibernation from working as expected
	my $disable_hibernate_file_path = 'C:\Program Files\VMware\VMware Tools\plugins\vmsvc\disableGuestHibernate.dll';
	if ($self->file_exists($disable_hibernate_file_path)) {
		$self->move_file($disable_hibernate_file_path, "$disable_hibernate_file_path.disabled");
	}
	
	# Run powercfg.exe to disable hibernation
	my $command = "$system32_path/powercfg.exe -HIBERNATE OFF";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to disable hibernation on $computer_node_name");
		return;
	}
	elsif ($exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "disabled hibernation on $computer_node_name" . (scalar(@$output) ? ", output:\n" . join("\n", @$output) : ''));
	}
	elsif (grep(/PAE mode/i, @$output)) {
		# The following may be displayed:
		#    Hibernation failed with the following error: The request is not supported.
		#    The following items are preventing hibernation on this system.
		#    The system is running in PAE mode, and hibernation is not allowed in PAE mode.
		notify($ERRORS{'OK'}, 0, "hibernation NOT disabled because $computer_node_name is running in PAE mode");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to disable hibernation on $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	# Delete hiberfil.sys
	if (!$self->delete_file('$SYSTEMDRIVE/hiberfil.sys')) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable hibernation, hiberfil.sys could not be deleted");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 hibernate

 Parameters  : none
 Returns     : boolean
 Description : Hibernate the computer.

=cut

sub hibernate {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	if (!$self->enable_hibernation()) {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_node_name, hibernation could not be enabled");
		return;
	}
	
	# Run powercfg.exe to enable hibernation
	my $command = "/bin/cygstart.exe \$SYSTEMROOT/system32/cmd.exe /c \"$system32_path/shutdown.exe -h -f\"";
	my $start_time = time;
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to hibernate $computer_node_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "executed command to hibernate $computer_node_name: $command" . (scalar(@$output) ? "\noutput:\n" . join("\n", @$output) : ''));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_node_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	# Wait for the computer to stop responding
	my $wait_seconds = 300;
	if ($self->provisioner->wait_for_power_off($wait_seconds, 3)) {
		my $duration = (time - $start_time);
		notify($ERRORS{'DEBUG'}, 0, "hibernate successful, $computer_node_name stopped responding after $duration seconds");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_node_name, still responding to ping after $wait_seconds seconds");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_ceip

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables the Windows Customer Experience Improvement Program
               features.

=cut

sub disable_ceip {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to set the CEIPEnable key
	my $registry_key_software = 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\\SQMClient\\Windows';
	if ($self->reg_add($registry_key_software, 'CEIPEnable', 'REG_DWORD', 0)) {
		notify($ERRORS{'OK'}, 0, "set the CEIPEnable software registry key to 0");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the CEIPEnable registry key to 0");
		return;
	}
	
	# Attempt to set the CEIPEnable policy key
	my $registry_key_policy = 'HKEY_LOCAL_MACHINE\\Software\\Policies\\Microsoft\\SQMClient\\Windows';
	if ($self->reg_add($registry_key_policy, 'CEIPEnable', 'REG_DWORD', 0)) {
		notify($ERRORS{'OK'}, 0, "set the CEIPEnable policy registry key to 0");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the CEIPEnable policy registry key to 0");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_shutdown_event_tracker

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables the Shutdown Event Tracker. This is enabled by default
					on Windows Server 2003. It is what causes a box to appear which
					asks for a reason when the computer is shutdown or rebooted. The
					box also appears during login if the computer is shut down
					unexpectedly. This causes the autologon sequence to break.

=cut

sub disable_shutdown_event_tracker {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Attempt to set the ShutdownReasonOn key
	my $registry_key_software = 'HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Reliability';
	if ($self->reg_add($registry_key_software, 'ShutdownReasonOn', 'REG_DWORD', 0)) {
		notify($ERRORS{'OK'}, 0, "set the ShutdownReasonOn software registry key to 0");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set the ShutdownReasonOn registry key to 0");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub setup_get_menu {
	my $menu = {
		'Windows Image Configuration' => {
			'Activation' => {
				'Configure Multiple Activation Key (MAK) Activation' => \&setup_product_keys,
				'Configure Key Management Service (KMS) Activation' => \&setup_kms_servers,
			}
		},
	};
	
	return $menu;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_product_keys

 Parameters  : none
 Returns     : nothing
 Description : Used to list, set, and delete product keys from the winProductKey
               table in the database when vcld is run in setup mode.

=cut

sub setup_product_keys {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get a hash containing all of the information from the affiliation table
	my $affiliation_info = get_affiliation_info();
	if (!$affiliation_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve affiliation info");
		return;
	}
	
	my @product_names = sort keys	%$KMS_CLIENT_PRODUCT_KEYS;
	
	push @product_names, (
		'Windows XP',
		'Windows Server 2003',
		'Windows Server 2003 R2',
		'Other',
	);
	
	my @operation_choices = (
		'List Product Keys',
		'Add Product Key',
		'Delete Product Key',
	);
	
	my @setup_path = @{$ENV{setup_path}};
	
	OPERATION: while (1) {
		@{$ENV{setup_path}} = @setup_path;
		
		print '-' x 76 . "\n";
		
		print "Choose an operation:\n";
		my $operation_choice_index = setup_get_array_choice(@operation_choices);
		last if (!defined($operation_choice_index));
		my $operation_name = $operation_choices[$operation_choice_index];
		print "\n";
		
		push @{$ENV{setup_path}}, $operation_name;
		
		if ($operation_name =~ /list/i) {
			$self->setup_display_product_key_info();
			print "\n";
		}
		
		elsif ($operation_name =~ /add/i) {
			print "Choose an affiliation:\n";
			my $affiliation_id = setup_get_hash_choice($affiliation_info, 'name');
			next if (!defined($affiliation_id));
			my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
			print "Selected affiliation: $affiliation_name\n\n";
			
			$self->setup_display_product_key_info($affiliation_id);
			print "\n";
			
			print "Choose a Windows product:\n";
			my $product_choice_index = setup_get_array_choice(@product_names);
			next OPERATION if (!defined($product_choice_index));
			
			my $product_name = $product_names[$product_choice_index];
			if ($product_name eq 'Other') {
				$product_name = setup_get_input_string("Enter a product name");
				next OPERATION if (!defined($product_name));
			}
			print "Windows product: $product_name\n\n";
			
			my $product_key;
			while (!$product_key) {
				$product_key = setup_get_input_string("Enter the product key xxxxx-xxxxx-xxxxx-xxxxx-xxxxx");
				next OPERATION if (!defined($product_key));
				if ($product_key !~ /(\w{5}-?){5}/) {
					print "Product key is not in the correct format: $product_key\n";
					$product_key = 0;
				}
			}
			$product_key = uc($product_key);
			print "\n";
			
			# Attempt to set the product key in the database
			if ($self->set_product_key($affiliation_id, $product_name, $product_key)) {
				print "Product key has been saved to the database:\nAffiliation: $affiliation_name\nProduct name: $product_name\nProduct key: $product_key\n";
			}
			else {
				print "ERROR: failed to save product key to the database:\nAffiliation: $affiliation_name\nProduct name: $product_name\nProduct key: $product_key\n";
			}
		}
		
		elsif ($operation_name =~ /delete/i) {
			# Get the product key information from the database
			my $product_key_info = $self->get_product_key_info();
			if (!defined($product_key_info)) {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve product key information from the database");
				next;
			}
			
			my %product_keys;
			for my $affiliation_id (keys %$product_key_info) {
				my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
				
				for my $product_name (keys %{$product_key_info->{$affiliation_id}}) {
					my $product_key = $product_key_info->{$affiliation_id}{$product_name};
					
					my $product_key_choice_name = "$affiliation_name: '$product_name' ($product_key)";
					
					$product_keys{$product_key_choice_name}{affiliation_id} = $affiliation_id;
					$product_keys{$product_key_choice_name}{product_name} = $product_name;
					$product_keys{$product_key_choice_name}{product_key} = $product_key;
				}
			}
			
			# Choose an affiliation with populated product keys
			print "Choose a product key to delete:\n";
			my $product_key_choice_name = setup_get_hash_choice(\%product_keys);
			next if (!defined($product_key_choice_name));
			print "\n";
			
			my $affiliation_id = $product_keys{$product_key_choice_name}{affiliation_id};
			my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
			my $product_name = $product_keys{$product_key_choice_name}{product_name};
			my $product_key = $product_keys{$product_key_choice_name}{product_key};
			
			# Attempt to delete the product key from the database
			if ($self->delete_product_key($affiliation_id, $product_name, $product_key)) {
				print "Product key for has been deleted from the database:\nAffiliation: $affiliation_name\nProduct name: $product_name\nProduct key: $product_key\n";
			}
			else {
				print "ERROR: failed to delete product key from the database:\nAffiliation: $affiliation_name\nProduct name: $product_name\nProduct key: $product_key\n";
			}
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_display_product_key_info

 Parameters  : $affiliation_id (optional)
 Returns     :
 Description : Displays the product keys configured in the winProductKey table
               in the database. If an affiliation ID argument is specified, only
               the information for that affiliation is displayed.

=cut

sub setup_display_product_key_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get a hash containing all of the information from the affiliation table
	my $affiliation_info = get_affiliation_info();
	if (!$affiliation_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve affiliation info");
		return;
	}
	
	# Get the affiliation ID argument if it was specified
	my $affiliation_id_argument = shift;
	if ($affiliation_id_argument && !defined($affiliation_info->{$affiliation_id_argument})) {
		notify($ERRORS{'WARNING'}, 0, "affiliation does not exist for affiliation ID argument: $affiliation_id_argument");
		return;
	}
	
	# Get the product key information from the database
	my $product_key_info = $self->get_product_key_info();
	if (!defined($product_key_info)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve product key information from the database");
		return;
	}
	
	# Print the title
	if ($affiliation_id_argument) {
		my $affiliation_name = $affiliation_info->{$affiliation_id_argument}{name};
		print "Product key configuration for $affiliation_name ($affiliation_id_argument):\n";
	}
	else {
		print "Product key configuration for all affiliations:\n";
	}
	
	
	my $product_key_info_string;
	for my $affiliation_id (sort { $a <=> $b } keys %$product_key_info) {
		
		if (defined($affiliation_id_argument) && $affiliation_id ne $affiliation_id_argument) {
			next;
		}
		
		my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
		
		$product_key_info_string .= "$affiliation_name ($affiliation_id):\n";
		for my $product_name (keys %{$product_key_info->{$affiliation_id}}) {
			my $product_key = $product_key_info->{$affiliation_id}{$product_name};
			$product_key_info_string .= "   $product_name: $product_key\n";
		}
	}
	
	$product_key_info_string = "<not configured>\n" if !$product_key_info_string;
	print "$product_key_info_string";
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_kms_servers

 Parameters  : none
 Returns     : nothing
 Description : Configures KMS servers in the winKMS table in the database when
               vcld is run in setup mode.

=cut

sub setup_kms_servers {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get a hash containing all of the information from the affiliation table
	my $affiliation_info = get_affiliation_info();
	if (!$affiliation_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve affiliation info");
		return;
	}
	
	my @operation_choices = (
		'List KMS Servers',
		'Add KMS Server',
		'Delete KMS Server',
	);
	
	
	my @setup_path = @{$ENV{setup_path}};
	
	OPERATION: while (1) {
		@{$ENV{setup_path}} = @setup_path;
		print '-' x 76 . "\n";
		
		print "Choose an operation:\n";
		my $operation_choice_index = setup_get_array_choice(@operation_choices);
		last if (!defined($operation_choice_index));
		my $operation_name = $operation_choices[$operation_choice_index];
		print "\n";
		
		push @{$ENV{setup_path}}, $operation_name;
		
		if ($operation_name =~ /list/i) {
			$self->setup_display_kms_server_info();
			print "\n";
		}
		
		elsif ($operation_name =~ /add/i) {
			print "Choose an affiliation:\n";
			my $affiliation_id = setup_get_hash_choice($affiliation_info, 'name');
			next if (!defined($affiliation_id));
			my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
			print "Selected affiliation: $affiliation_name\n\n";
			
			$self->setup_display_kms_server_info($affiliation_id);
			print "\n";
			
			my $address;
			while (!$address) {
				$address = setup_get_input_string("Enter the KMS server host name or address");
				next OPERATION if (!defined($address));
				if (!is_valid_dns_host_name($address) && !is_valid_ip_address($address)) {
					print "Address is not a valid DNS host name or IP address: $address\n";
					$address = '';
				}
			}
			print "\n";
			
			my $port;
			while (!$port) {
				$port = setup_get_input_string("Enter the KMS server port", 1688);
				next OPERATION if (!defined($port));
				if ($port !~ /^\d+$/) {
					print "Port must be an integer: $port\n";
					$port = '';
				}
			}
			
			print "\n";
			
			# Attempt to set the KMS server in the database
			if ($self->set_kms_server($affiliation_id, $address, $port)) {
				print "KMS server added to the database:\nAffiliation: $affiliation_name\nAddress: $address\nPort: $port\n";
			}
			else {
				print "ERROR: failed to save product key to the database:\nAffiliation: $affiliation_name\nAddress: $address\nPort: $port\n";
			}
		}
		
		elsif ($operation_name =~ /delete/i) {
			# Get the KMS server information from the database
			my $kms_server_info = $self->get_kms_server_info();
			if (!defined($kms_server_info)) {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve KMS server information from the database");
				next;
			}
			
			my %kms_servers;
			for my $affiliation_id (keys %$kms_server_info) {
				my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
				
				for my $address (keys %{$kms_server_info->{$affiliation_id}}) {
					my $port = $kms_server_info->{$affiliation_id}{$address};
					
					my $kms_server_choice_name = "$affiliation_name: $address:$port";
					
					$kms_servers{$kms_server_choice_name}{affiliation_id} = $affiliation_id;
					$kms_servers{$kms_server_choice_name}{address} = $address;
					$kms_servers{$kms_server_choice_name}{port} = $port;
				}
			}
			
			# Choose an affiliation populated with a KMS server
			print "Choose a KMS server to delete:\n";
			my $kms_server_choice_name = setup_get_hash_choice(\%kms_servers);
			next if (!defined($kms_server_choice_name));
			print "\n";
			
			my $affiliation_id = $kms_servers{$kms_server_choice_name}{affiliation_id};
			my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
			my $address = $kms_servers{$kms_server_choice_name}{address};
			my $port = $kms_servers{$kms_server_choice_name}{port};
			
			## Attempt to delete the product key from the database
			if ($self->delete_kms_server($affiliation_id, $address)) {
				print "KMS server has been deleted from the database:\nAffiliation: $affiliation_name\nAddress: $address\nPort: $port\n";
			}
			else {
				print "ERROR: failed to delete product key from the database:\nAffiliation: $affiliation_name\nAddress: $address\nPort: $port\n";
			}
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_display_kms_server_info

 Parameters  : $affiliation_id (optional)
 Returns     :
 Description : Displays the KMS server configuration stored in the winKMS table
               in the database to STDOUT.

=cut

sub setup_display_kms_server_info {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get a hash containing all of the information from the affiliation table
	my $affiliation_info = get_affiliation_info();
	if (!$affiliation_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve affiliation info");
		return;
	}
	
	# Get the affiliation ID argument if it was specified
	my $affiliation_id_argument = shift;
	if ($affiliation_id_argument && !defined($affiliation_info->{$affiliation_id_argument})) {
		notify($ERRORS{'WARNING'}, 0, "affiliation does not exist for affiliation ID argument: $affiliation_id_argument");
		return;
	}
	
	# Get the KMS server information from the database
	my $kms_server_info = $self->get_kms_server_info();
	if (!defined($kms_server_info)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve KMS server information from the database");
		return;
	}
	
	# Print the title
	if ($affiliation_id_argument) {
		my $affiliation_name = $affiliation_info->{$affiliation_id_argument}{name};
		print "KMS server configuration for $affiliation_name ($affiliation_id_argument):\n";
	}
	else {
		print "KMS server configuration for all affiliations:\n";
	}
	
	# Print the KMS serer information
	my $kms_server_info_string;
	for my $affiliation_id (sort { $a <=> $b } keys %$kms_server_info) {
		# Ignore non-matching affiliations if the affiliation ID argument was specified
		if (defined($affiliation_id_argument) && $affiliation_id ne $affiliation_id_argument) {
			next;
		}
		
		my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
		
		$kms_server_info_string .= "$affiliation_name ($affiliation_id):\n";
		for my $address (keys %{$kms_server_info->{$affiliation_id}}) {
			my $port = $kms_server_info->{$affiliation_id}{$address};
			$kms_server_info_string .= "   $address:$port\n";
		}
	}
	
	$kms_server_info_string = "<not configured>\n" if !$kms_server_info_string;
	print "$kms_server_info_string";
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_time_zone_name

 Parameters  : none
 Returns     : string
 Description : Returns the name of the time zone configured for the management
               node. The date command is run locally on the management node and
               the time zone abbreviation is parsed from the output. This
               %TIME_ZONE_INFO hash is searched for matching time zone
               information and the time zone name is returned. If a matching
               time zone is not found, 'Eastern Standard Time' is returned.
               Example: 'HVL' returns 'Tasmania Standard Time'

=cut

sub get_time_zone_name {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $default_time_zone_name = 'Eastern Standard Time';
	
	# Call date to determine the time zone abbreviation in use on the management node
	my ($exit_status, $output) = run_command('date +%Z');
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to determine time zone configured for management node, returning '$default_time_zone_name'");
		return $default_time_zone_name;
	}
	
	# Extract the time zone abbreviation from the output
	my ($set_abbreviation) = grep(/^\w{3}$/, @$output);
	if (!$set_abbreviation) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine time zone abbreviation from output, returning '$default_time_zone_name':\n" . join("\n", @$output));
		return $default_time_zone_name;
	}
	
	# Windows time zone codes don't include corresponding daylight time abbreviations, e.g. EDT
	# Convert *DT --> *ST
	if ($set_abbreviation =~ /(.)DT/i) {
		$set_abbreviation = "$1ST";
		notify($ERRORS{'DEBUG'}, 0, "time zone abbreviation converted to standard time: $1DT --> $set_abbreviation");
	}
	
	# Loop through the time zone codes until a matching abbreviation is found
	for my $time_zone_name (sort keys %TIME_ZONE_INFO) {
		my $time_zone_abbreviation = $TIME_ZONE_INFO{$time_zone_name}{abbreviation};
		
		next if (!$time_zone_abbreviation || $set_abbreviation !~ /^$time_zone_abbreviation$/i);
		
		notify($ERRORS{'DEBUG'}, 0, "determined name of time zone configured for management node: '$time_zone_name'");
		return $time_zone_name;
	}
	
	# Return the code for EST if a match was not found
	notify($ERRORS{'WARNING'}, 0, "unable to determine name of time zone configured for management node, abbreviation: $set_abbreviation, returning '$default_time_zone_name'");
	return $default_time_zone_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_time_zone_code

 Parameters  : none
 Returns     : string
 Description : Returns the Windows numerical code of the time zone configured
               for the management node. If a matching time zone is not found, 35
               is returned.
               Example: 'HVL' returns 265

=cut

sub get_time_zone_code {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $time_zone_name = $self->get_time_zone_name() || return;
	
	my $time_zone_code = $TIME_ZONE_INFO{$time_zone_name}{code};
	if ($time_zone_code) {
		notify($ERRORS{'DEBUG'}, 0, "determined Windows code of time zone configured for management node: $time_zone_code");
		return $time_zone_code;
	}
	else {
		my $default = 35;
		notify($ERRORS{'WARNING'}, 0, "time zone code could not be determined for time zone: '$time_zone_name', returning $default");
		return $default;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize_files

 Parameters  : @file_paths (optional)
 Returns     : boolean
 Description : Removes the Windows root password from files on the computer.

=cut

sub sanitize_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @file_paths = @_;
	
	# Get the file path arguments, add the node configuration directory
	my $node_configuration_directory = $self->get_node_configuration_directory();
	push @file_paths, "$node_configuration_directory/Scripts";
	push @file_paths, "$node_configuration_directory/Logs";

	# Attempt to get the existing Windows root password from autologon_enable.cmd
	# This is necessary in case a different password was used when the image was captured
	my $existing_password;
	my $grep_command = "/bin/grep -i \"set PASSWORD\" \"$node_configuration_directory/Scripts/autologon_enable.cmd\" 2>&1";
	my ($grep_status, $grep_output) = $self->execute($grep_command, 0);
	if (!defined($grep_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve Windows root password from autologon_enable.cmd");
	}
	elsif (grep(/No such file/i, @$grep_output)) {
		notify($ERRORS{'DEBUG'}, 0, "existing Windows root password not retrieved from autologon_enable.cmd because the file does not exist");
	}
	else {
		($existing_password) = map { $_ =~ /set PASSWORD=(.+)/; $1;} @$grep_output;
		if ($existing_password) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved password from autologon_enable.cmd: $existing_password");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "password not found in autologon_enable.cmd:\n" . join("\n", @$grep_output));
		}
	}
	
	my $password_pattern;
	if ($existing_password && $existing_password ne $WINDOWS_ROOT_PASSWORD) {
		$password_pattern = "\\\($WINDOWS_ROOT_PASSWORD\\\|$existing_password\\\)";
	}
	else {
		$password_pattern = $WINDOWS_ROOT_PASSWORD;
	}
	
	# Loop through each file path, remove the Windows root password from each
	my $error_occurred = 0;
	for my $file_path (@file_paths) {
		if (!$self->search_and_replace_in_files($file_path, $password_pattern, 'WINDOWS_ROOT_PASSWORD')) {
			notify($ERRORS{'WARNING'}, 0, "failed to remove the Windows root password from: $file_path");
			$error_occurred = 1;
		}
	}
	
	if ($error_occurred) {
		return;
	}
	else {
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 clear_event_log

 Parameters  : @logfile_names (optional)
 Returns     : boolean
 Description : Clears the Windows 'Application', 'Security', 'System' event
               logs. One or more event logfile names may be specified to only
               clear certain event logs.

=cut

sub clear_event_log {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @logfile_names = @_;
	@logfile_names = ('Application', 'Security', 'System') if !@logfile_names;
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Assemble the command
	# Call wmic.exe - the WMI shell
	# wmic.exe will hang if it is called by itself.  It has something to do with TTY/PTY
	# Piping the echo command seems to prevent it from hanging
	my $command;
	for my $logfile_name (@logfile_names) {
		$command .= "echo | $system32_path/Wbem/wmic.exe NTEVENTLOG WHERE LogFileName=\\\"$logfile_name\\\" CALL ClearEventLog ; ";
	}
	
	# Remove the last ' ; ' added to the command
	$command =~ s/[\s;]*$//g;
	
	my ($status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to run SSH command to clear the event log: @logfile_names");
		return;
	}
	elsif (grep(/ERROR/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to clear event log: @logfile_names, output:\n" . join("\n", @$output));
		return;
	}
	elsif (grep(/Method execution successful/i, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "cleared event log: @logfile_names");
		$self->create_eventlog_entry("Event log cleared by VCL");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output while clearing event log: @logfile_names, output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_login_screensaver

 Parameters  : None
 Returns     : 
 Description : Sets the registry keys to disable to login screensaver.

=cut

sub disable_login_screensaver {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $registry_key = 'HKEY_USERS\\.DEFAULT\\Control Panel\\Desktop';
	if ($self->reg_add($registry_key, 'ScreenSaveActive', 'REG_SZ', 0) && $self->reg_add($registry_key, 'ScreenSaveTimeOut', 'REG_SZ', 0)) {
		notify($ERRORS{'DEBUG'}, 0, "set registry keys to disable the login screensaver");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set registry keys to disable the login screensaver");
		return;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 fix_default_profile

 Parameters  : none
 Returns     : boolean
 Description : Attempts to correct common problems with the default user
               profile by loading the default user registry hive from the
               ntuser.dat file into the registry, making changes, then unloading
               the hive.

=cut

sub fix_default_profile {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	my $root_key = 'HKEY_USERS\DEFAULT_USER_PROFILE';
	my $profile_list_key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList';
	
	# Determine the default user profile path
	my $profile_list_registry_info = $self->reg_query($profile_list_key);
	if (!$profile_list_registry_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve profile information from the registry on $computer_node_name");
		return;
	}
	elsif (!$profile_list_registry_info->{$profile_list_key}) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine default profile path, '$profile_list_key' key does not exist in the registry data:\n" . format_data($profile_list_registry_info));
		return;
	}
	
	# The default profile path should either be stored in the 'Default' value or can be assembled from combining the 'ProfilesDirectory' and 'DefaultUserProfile' values
	my $default_profile_path;
	if ($profile_list_registry_info->{$profile_list_key}{Default}) {
		$default_profile_path = $profile_list_registry_info->{$profile_list_key}{Default};
	}
	elsif ($profile_list_registry_info->{$profile_list_key}{ProfilesDirectory} && $profile_list_registry_info->{$profile_list_key}{DefaultUserProfile}) {
		$default_profile_path = "$profile_list_registry_info->{$profile_list_key}{ProfilesDirectory}\\$profile_list_registry_info->{$profile_list_key}{DefaultUserProfile}";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine default profile path from the registry on $computer_node_name:\n" . format_data($profile_list_registry_info->{$profile_list_key}));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "determined default profile path from the registry on $computer_node_name: '$default_profile_path'");
	
	# Load the default profile hive file into the registry
	my $hive_file_path = "$default_profile_path\\ntuser.dat";
	if (!$self->reg_load($root_key, $hive_file_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to load the default profile hive into the registry on $computer_node_name");
		return;
	}
	
	# Fix registry values known to cause problems
	# The "Shell Folders" key may contain paths pointing to a specific user's profile
	# Any paths under "Shell Folders" can be deleted
	my $registry_string .= <<EOF;
Windows Registry Editor Version 5.00
[-$root_key\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders]
[$root_key\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Shell Folders]
EOF

	# Import the string into the registry
	if (!$self->import_registry_string($registry_string)) {
		notify($ERRORS{'WARNING'}, 0, "failed to fix problematic registry settings in the default profile");
		return;
	}
	
	# Unoad the default profile hive
	if (!$self->reg_unload($root_key)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unload the default profile hive from the registry on $computer_node_name");
		return;
	}

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_environment_variable_value

 Parameters  : $environment_variable_name
 Returns     : string
 Description : Retrieves the value of the environment variable specified by the
					argument. An empty string is returned if the variable is not set.

=cut

sub get_environment_variable_value {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	
	# Get the environment variable name argument
	my $environment_variable_name = shift;
	if (!defined($environment_variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "environment variable name argument was not supplied");
		return;
	}
	
	# Determine how the environment variable should be echo'd
	my $command = 'bash --login -c "';
	if ($environment_variable_name =~ /^\$/) {
		# Unix-style environment variable name passed beginning with a '$', echo it from the Cygwin bash shell
		$environment_variable_name = uc($environment_variable_name);
		$command .= "echo \\$environment_variable_name";
	}
	elsif ($environment_variable_name =~ /^\%.*\%$/) {
		# DOS-style environment variable name passed enclosed in '%...%', echo it from a command prompt
		$command .= "cmd.exe /c echo $environment_variable_name";
	}
	else {
		# Plain-word environment variable name passed, enclose it in '%...%' and echo it from a command prompt
		$command .= "cmd.exe /c echo \%$environment_variable_name\%";
	}
	$command .= '"';
	
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve value of '$environment_variable_name' environment variable on $computer_node_name");
		return;
	}
	elsif ($exit_status ne '0' || grep(/bash:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to retrieve value of '$environment_variable_name' environment variable on $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	elsif (scalar @$output > 1) {
		notify($ERRORS{'WARNING'}, 0, "unexpected output returned from command to retrieve value of '$environment_variable_name' environment variable on $computer_node_name\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my $value = @$output[0];
	if (scalar @$output == 0 || $value =~ /^\%.*\%$/) {
		notify($ERRORS{'DEBUG'}, 0, "'$environment_variable_name' environment variable is not set on $computer_node_name");
		return '';
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved value of '$environment_variable_name' environment variable on $computer_node_name: '$value'");
		return $value;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_connection_on_port

 Parameters  : $port
 Returns     : boolean
 Description : Checks if a connection is established to the port specified from
					the reservation remote IP address. If a connection is detected
					from another address and the user is logged in,
					reservation.remoteIP is updated.

=cut

sub check_connection_on_port {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name          = $self->data->get_computer_node_name();
	my $remote_ip                   = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address  = $self->get_public_ip_address();
	my $request_state_name          = $self->data->get_request_state_name();
	
	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
		return "failed";
	}
	
	my $port_connection_info = $self->get_port_connection_info();
	for my $protocol (keys %$port_connection_info) {
		if (!defined($port_connection_info->{$protocol}{$port})) {
			next;
		}
		
		for my $connection (@{$port_connection_info->{$protocol}{$port}}) {
			my $connection_local_ip = $connection->{local_ip};
			my $connection_remote_ip = $connection->{remote_ip};
			
			if ($connection_local_ip ne $computer_public_ip_address) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring connection, not connected to public IP address ($computer_public_ip_address): $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
				next;
			}
			
			if ($connection_remote_ip eq $remote_ip) {
				notify($ERRORS{'DEBUG'}, 0, "connection detected from reservation remote IP: $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
				return 1;
			}
			
			# Connection is not from reservation remote IP address, check if user is logged in
			if ($self->user_logged_in()) {
				notify($ERRORS{'DEBUG'}, 0, "connection detected from different remote IP address than current reservation remote IP ($remote_ip): $connection_remote_ip --> $connection_local_ip:$port ($protocol), updating reservation remote IP to $connection_remote_ip");
				$self->data->set_reservation_remote_ip($connection_remote_ip);
				return 1;
			}
			
			notify($ERRORS{'DEBUG'}, 0, "ignoring connection, user is not logged in and remote IP address does not match current reservation remote IP ($remote_ip): $connection_remote_ip --> $connection_local_ip:$port ($protocol)");
		}
	}
	
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_core_count

 Parameters  : none
 Returns     : integer
 Description : Retrieves the number of CPU cores the computer has by querying
               the NUMBER_OF_PROCESSORS environment variable.

=cut

sub get_cpu_core_count {
	my $self = shift;
	if (ref($self) !~ /module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->get_environment_variable_value('NUMBER_OF_PROCESSORS');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_script

 Parameters  : $script_path, $timeout_seconds (optional)
 Returns     : boolean
 Description : Checks if script exists on the computer and attempts to run it.

=cut

sub run_script {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the script path argument
	my $script_path = shift;
	if (!$script_path) {
		notify($ERRORS{'WARNING'}, 0, "script path argument was not specified");
		return;
	}
	
	my $timeout_seconds = shift || 300;
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	# Check if script exists
	if (!$self->file_exists($script_path)) {
		notify($ERRORS{'WARNING'}, 0, "script does NOT exist on $computer_node_name: $script_path");
		return;
	}
	
	# Determine the script name
	my ($script_name, $script_directory_path, $script_extension) = fileparse($script_path, qr/\.[^.]*/);
	(my $script_path_escaped = $script_path) =~ s/( )/\^$1/g;
	
	# Get the node configuration directory, make sure it exists, create if necessary
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $node_log_directory = "$node_configuration_directory/Logs";
	
	# Assemble the log file path
	my $log_file_path;
	
	# If the script resides in the VCL node configuration directory, append the intermediate directory paths to the logfile path
	if ($script_directory_path =~ /$node_configuration_directory[\\\/](.+)/) {
		$log_file_path = "$node_log_directory/$1$script_name.log";
	}
	else {
		$log_file_path = "$node_log_directory/$script_name.log";
	}
	
	my $timestamp = makedatestring();
	
	# Assemble the command
	my $command;
	if ($script_extension =~ /vbs/i) {
		$command = "cmd.exe /c \"$system32_path/cscript.exe $script_path_escaped & exit %ERRORLEVEL%\"";
	}
	else {
		$command = "cmd.exe /c \"$script_path_escaped & exit %ERRORLEVEL%\"";
	}
	
	# Execute the command
	notify($ERRORS{'DEBUG'}, 0, "executing script on $computer_node_name:\nscript path: $script_path\nlog file path: $log_file_path\nscript timeout: $timeout_seconds seconds");
	my ($exit_status, $output) = $self->execute($command, 1, $timeout_seconds);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute script on $computer_node_name: '$script_path', command: '$command'");
		return;
	}

	# Create a log file containing the output
	my $logfile_contents = "$timestamp - $script_path executed by vcld";
	my $header_line_length = length($logfile_contents);
	$logfile_contents = '=' x $header_line_length . "\r\n$logfile_contents\r\n" . '=' x $header_line_length . "\r\n";
	$logfile_contents .= join("\r\n", @$output) . "\r\n";
	$self->create_text_file($log_file_path, $logfile_contents, 1);

	if ($exit_status == 0) {
		notify($ERRORS{'OK'}, 0, "successfully executed script on $computer_node_name: '$script_path'\nlog file: log_file_path\ncommand: $command, output:\n" . join("\n", @$output));
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "script '$script_path' returned a non-zero exit status: $exit_status\nlog file: $log_file_path\ncommand: '$command'\noutput:\n" . join("\n", @$output));
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_updates

 Parameters  : none
 Returns     : boolean
 Description : Installs Windows update files stored in under the tools directory
					on the management node. Update files which exist on the
					management node but not on the computer are copied. Files which
					are named the same but differ are replaced.

=cut

sub install_updates {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	my $image_name           = $self->data->get_image_name();
	
	# Get the node configuration directory, make sure it exists, create if necessary
	my $node_configuration_directory = $self->get_node_configuration_directory();
	
	my @computer_tools_files = $self->get_tools_file_paths("/Updates/");
	if (@computer_tools_files) {
		notify($ERRORS{'DEBUG'}, 0, scalar(@computer_tools_files) . " updates found which apply to $image_name:\n" . join("\n", @computer_tools_files));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no updates have been saved to the management node which apply to $image_name");
		return 1;
	}
	
	my $logfile_directory_path = "$node_configuration_directory/Logs/Updates";
	$self->create_directory($logfile_directory_path);
	
	my %installed_updates = map { $_ => 1 } $self->get_installed_updates();
	
	my @update_ids;
	
	# Loop through all update files on the computer
	for my $file_path (@computer_tools_files) {
		my ($file_name, $directory_path, $file_extension) = fileparse($file_path, qr/\.[^.]*/);
		
		if ($file_path !~ /\.(msu|exe)$/i) {
			notify($ERRORS{'DEBUG'}, 0, "file on $computer_node_name not installed because file extension is not .exe or .msu: $file_path");
			next;
		}
		
		# Get the update ID (KBxxxxxx) from the file name
		my ($update_id) = uc($file_name) =~ /(kb\d+)/i;
		$update_id = $file_name if !$update_id;
		
		# Check if the update is already installed based on the list returned from the OS
		if ($installed_updates{$update_id}) {
			notify($ERRORS{'DEBUG'}, 0, "update $update_id is already installed on $computer_node_name");
			next;
		}
		else {
			# Add ID to @update_ids array, this list will be checked after all updates are installed to verify update is installed on computer
			push @update_ids, $update_id;
		}
	
		if ($file_path =~ /\.msu$/i) {
			$self->install_msu_update($file_path);
		}
		elsif ($file_path =~ /\.exe$/i) {
			$self->install_exe_update($file_path);
		}
	}
	
	# If any updates were installed, verify they appear on the OS
	if (@update_ids) {
		# Retrieve the installed updated from the OS to check if the update was installed
		%installed_updates = map { $_ => 1 } $self->get_installed_updates(1);
		for my $update_id (@update_ids) {
			if ($installed_updates{$update_id}) {
				notify($ERRORS{'DEBUG'}, 0, "verified update $update_id is installed on $computer_node_name");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "update $update_id does not appear in the list of updates installed on $computer_node_name");
			}
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_exe_update

 Parameters  : $update_file_path
 Returns     : boolean
 Description : Installs a Windows Update .exe update package.

=cut

sub install_exe_update {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "path to .msu update file was not supplied");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my ($file_name, $directory_path, $file_extension) = fileparse($file_path, qr/\.[^.]*/);
	
	my ($update_id) = uc($file_name) =~ /(kb\d+)/i;
	$update_id = $file_name if !$update_id;
	
	# Assemble the log file path
	# wusa.exe creates log files in the Event Log format - not plain text
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $logfile_directory_path = "$node_configuration_directory/Logs/Updates";
	my $log_file_path = "$logfile_directory_path/$file_name.log";
	
	# Delete old log files for the update being installed so log output can be parsed without including old data
	$self->delete_file("$logfile_directory_path/*$update_id*");
	
	my $command;
	$command .= "chmod -Rv 755 \"$file_path\" ; ";
	$command .= "\"$file_path\" /quiet /norestart /log:\"$log_file_path\"";
	
	notify($ERRORS{'DEBUG'}, 0, "installing update on $computer_node_name\ncommand: $command");
	my ($exit_status, $output) = $self->execute($command, 1, 180);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to install update on $computer_node_name: $command");
		return;
	}
	elsif ($exit_status eq '194') {
		# Exit status 194 - installed but reboot required
		notify($ERRORS{'DEBUG'}, 0, "installed update on $computer_node_name, exit status $exit_status indicates a reboot is required");
		push @{$self->{reboot_required}}, "installed update: $file_path, exit status indicates a reboot is required";
		return 1;
	}
	elsif ($exit_status eq '0') {
		notify($ERRORS{'DEBUG'}, 0, "installed update on $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "command to install update on $computer_node_name returned exit status: $exit_status\ncommand: $command\noutput:\n" . join("\n", @$output));
	}
	
	# Check the log file to determine if a reboot is required, skip if exit status was 194
	my @log_file_lines = $self->get_file_contents($log_file_path);
	for my $line (@log_file_lines) {
		if ($line =~ /RebootNecessary = 1|reboot is required/i) {
			push @{$self->{reboot_required}}, "installed update: $file_path, log file indicates a reboot is required: $line";
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_msu_update

 Parameters  : $msu_file_path
 Returns     : boolean
 Description : Installs a Windows Update Stand-alone Installer .msu update
               package.
=cut

sub install_msu_update {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "path to .msu update file was not supplied");
		return;
	}
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	my ($file_name, $directory_path, $file_extension) = fileparse($file_path, qr/\.[^.]*/);
	
	my ($update_id) = uc($file_name) =~ /(kb\d+)/i;
	$update_id = $file_name if !$update_id;
	
	# Assemble the log file path
	# wusa.exe creates log files in the Event Log format - not plain text
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $logfile_directory_path = "$node_configuration_directory/Logs/Updates";
	my $event_log_file_path = "$logfile_directory_path/$file_name.evtx";
	my $log_file_path = "$logfile_directory_path/$file_name.log";
	
	# Delete old log files for the update being installed so log output can be parsed without including old data
	$self->delete_file("$logfile_directory_path/*$update_id*");
	
	my $wusa_command;
	$wusa_command .= "chmod -Rv 755 \"$file_path\" ; ";
	$wusa_command .= "$system32_path/wusa.exe \"$file_path\" /quiet /norestart /log:\"$event_log_file_path\"";
	
	notify($ERRORS{'DEBUG'}, 0, "installing update on $computer_node_name\ncommand: $wusa_command");
	my ($wusa_exit_status, $wusa_output) = $self->execute($wusa_command, 1, 180);
	if (!defined($wusa_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to install update on $computer_node_name: $wusa_command");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "executed command to install update on $computer_node_name, exit status: $wusa_exit_status\ncommand: $wusa_command\noutput:\n" . join("\n", @$wusa_output));
	}
	
	# Convert Event Log format log file to plain text
	# Use the wevtutil.exe - the Windows Events Command Line Utility
	my $wevtutil_command = "$system32_path/wevtutil.exe qe \"$event_log_file_path\" /lf:true /f:XML /e:root > \"$log_file_path\"";
	
	my ($wevtutil_exit_status, $wevtutil_output) = $self->execute($wevtutil_command);
	if (!defined($wevtutil_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to convert event log file to plain text on $computer_node_name: $wevtutil_command");
		return;
	}
	else {
		#notify($ERRORS{'DEBUG'}, 0, "executed command to convert event log file to plain text $computer_node_name, exit status: $wevtutil_exit_status\ncommand: $wevtutil_command\noutput:\n" . join("\n", @$wevtutil_output));
	}
	
	my @log_file_lines = $self->get_file_contents($log_file_path);
	#notify($ERRORS{'DEBUG'}, 0, "log file contents from installation of $file_path:\n" . join("\n", @log_file_lines));
	
	my $log_xml_hash = xml_string_to_hash(@log_file_lines);
	#notify($ERRORS{'DEBUG'}, 0, "XML hash:\n" . format_data($log_xml_hash));
	
	my @events = @{$log_xml_hash->{Event}};
	for my $event (@events) {
		my $event_record_id = $event->{System}[0]->{EventRecordID}[0];
		my %event_data = map { $_->{Name} => $_->{content} } @{$event->{EventData}[0]->{Data}};
		
		#notify($ERRORS{'DEBUG'}, 0, "event $event_record_id:\n" . format_data(\%event_data));
		
		if (my $error_code = $event_data{ErrorCode}) {
			my $error_string = $event_data{ErrorString} || '<none>';
			
			if ($error_code eq '2359302') {
				# Already installed but reboot is required
				notify($ERRORS{'DEBUG'}, 0, "update $update_id is already installed but a reboot is required:\n" . format_data(\%event_data));
				push @{$self->{reboot_required}}, "installed update: $file_path, event log indicates a reboot is required";
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "error occurred installing update $update_id:\n" . format_data(\%event_data));
			}
		}
		elsif (my $debug_message = $event_data{DebugMessage}) {
			if ($debug_message =~ /IsRebootRequired: 1/i) {
				# RebootIfRequested.01446: Reboot is not scheduled. IsRunWizardStarted: 0, IsRebootRequired: 0, RestartMode: 1
				notify($ERRORS{'DEBUG'}, 0, "installed update $update_id, reboot is required:\n$debug_message");
				push @{$self->{reboot_required}}, "installed update: $file_path, event message indicates a reboot is required: $debug_message";
			}
			elsif ($debug_message =~ /Update is already installed/i) {
				# InstallWorker.01051: Update is already installed
				notify($ERRORS{'DEBUG'}, 0, "update $update_id is already installed:\n$debug_message");
			}
			elsif ($debug_message =~ /0X240006/i) {
				# InstallWorker.01051: Update is already installed
				notify($ERRORS{'DEBUG'}, 0, "error 0X240006 indicates that update $update_id is already installed:\n$debug_message");
			}
			elsif ($debug_message =~ /0X80240017/i) {
				notify($ERRORS{'WARNING'}, 0, "update is not intended for OS installed on $computer_node_name:\n$debug_message");
				return;
			}
			elsif ($debug_message !~ /((start|end) of search|Failed to get message for error)/i) {
				notify($ERRORS{'DEBUG'}, 0, "debug message for installation of update $update_id:\n$debug_message");
			}
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "event generated while installing update $update_id:\n" . format_data(\%event_data));
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_installed_updates

 Parameters  : $no_cache (optional)
 Returns     : array
 Description : Retrieves the list of updates installed on the computer.
=cut

sub get_installed_updates {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $no_cache = shift;
	
	return $self->{update_ids} if (!$no_cache && $self->{update_ids});
	
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path() || return;
	
	# wmic.exe will hang if it is called by itself.  It has something to do with TTY/PTY
	# Piping the echo command seems to prevent it from hanging
	my $command = "echo | $system32_path/Wbem/wmic.exe QFE LIST BRIEF";
	notify($ERRORS{'DEBUG'}, 0, "retrieving list of installed updates on $computer_node_name, command: $command");
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to list updates installed on $computer_node_name: $command");
		return;
	}
	
	# Add update IDs found to a hash and then convert it to an array to eliminate duplicates
	my %update_id_hash;
	for my $line (@$output) {
		# Parse the update ID from the line, may be in the form KB000000
		my ($update_id) = $line =~ /(kb\d+)/i;
		$update_id_hash{$update_id} = 1 if $update_id;
	}
	
	my @update_ids = sort keys %update_id_hash;
	$self->{update_ids} = \@update_ids;
	notify($ERRORS{'DEBUG'}, 0, "retrieved list updates installed on $computer_node_name(" . scalar(@update_ids) . "): " . join(", ", @update_ids));
	return @update_ids;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_names

 Parameters  : none
 Returns     : array
 Description : Retrieves the user account names which exist on the computer.

=cut

sub get_user_names {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $image_name = $self->data->get_image_name();
	
	my $command = "net user";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve user info from OS");
		return;
	}
	
	my $found_dash_line;
	my @user_names;
	for my $line (@$output) {
		if ($line =~ /^---/) {
			$found_dash_line = 1;
			next;
		}
		elsif (!$found_dash_line || $line =~ /command completed/) {
			next;
		}
		
		my @line_user_names = split(/[ \t]{2,}/, $line);
		push @user_names, @line_user_names if @line_user_names;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved user names from $image_name: " . join(", ", sort { lc($a) cmp lc($b) } @user_names));
	return @user_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_image

 Parameters  : none
 Returns     : boolean
 Description : Checks the image currently loaded on the computer and updates the
               imagerevisioninfo table if necessary. If the
               windows_disable_users variable is set in the variable table, the
               list of user accounts is retrieved from the computer and compared
               against the variable. Any user accounts listed in the variable
               which reside in the image have a random password set and are
               disabled.

=cut

sub check_image {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	#set_variable('ignore_users', 'Administrator,cyg_server,Guest,root,sshd,HelpAssistant,SUPPORT_388945a0,ASPNET');
	#set_variable('disable_users', 'test');
	
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $image_name = $self->data->get_image_name();
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my @image_user_names_report = ();
	my @image_user_names_reservation = ();
	my @image_user_names_ignore = ();
	
	# Get list of user names which should be disabled in images - known bad, unsafe
	my $disable_user_names_variable = get_variable('windows_disable_users');
	if (!$disable_user_names_variable) {
		notify($ERRORS{'DEBUG'}, 0, "$image_name not being checked for bad user accounts, windows_disable_users is not set in the variable table");
	}
	else {
		my @disable_user_names = sort {lc($a) cmp lc($b)} (split(/[,;]+/, $disable_user_names_variable));
		my $disable_user_names_regex = join("|", @disable_user_names);
		
		# Get list of user names which should be ignored in images (safe, normal users: Administrator, guest...)
		my $ignore_user_names_variable = get_variable('windows_ignore_users') || '';
		my @ignore_user_names = sort {lc($a) cmp lc($b)} (split(/[,;]+/, $ignore_user_names_variable));
		my $ignore_user_names_regex = join("|", @ignore_user_names);
		
		# Get list of user names from loaded image
		my @image_user_names = $self->get_user_names();
		if (!@image_user_names) {
			notify($ERRORS{'DEBUG'}, 0, "skipping image check, unable to retrieve user names from $computer_node_name");
			return;
		}
		
		# Get the list of reservation users - includes imagemeta users and server profile users
		my $reservation_user_hashref = $self->data->get_reservation_users();
		my @reservation_user_names = sort {lc($a) cmp lc($b)} (map { $reservation_user_hashref->{$_}{unityid} } (keys %$reservation_user_hashref));
		my $reservation_user_names_regex = join("|", @reservation_user_names);
		
		notify($ERRORS{'DEBUG'}, 0, "image users:\n" .
			"users on $image_name: " . join(", ", @image_user_names) . "\n" .
			"reservation users: " . join(", ", @reservation_user_names) . "\n" .
			"users which should be disabled for all images: " . join(", ", @disable_user_names) . "\n" .
			"users which can be ignored for all images: " . join(", ", @ignore_user_names) . "\n"
		);
		
		OS_USER_NAME: for my $image_user_name (sort {lc($a) cmp lc($b)} @image_user_names) {
			for my $disable_user_name_pattern (@disable_user_names) {
				if ($image_user_name =~ /$disable_user_name_pattern/i) {
					notify($ERRORS{'DEBUG'}, 0, "found user on $image_name which should be disabled: '$image_user_name' (matches pattern: '$disable_user_name_pattern')");
					
					my $random_password = getpw(11);
					if (!$self->set_password($image_user_name, $random_password, 1)) {
						notify($ERRORS{'WARNING'}, 0, "failed to set random password for user: '$image_user_name'");
					}
					else {
						notify($ERRORS{'OK'}, 0, "set random password for user: '$image_user_name', '$random_password'");
					}
					
					$self->disable_user($image_user_name);
				}
			}
			
			if ($image_user_name =~ /^($reservation_user_names_regex)$/i) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring reservation user in image: '$image_user_name'");
				push @image_user_names_reservation, $image_user_name;
			}
			elsif ($image_user_name =~ /^($ignore_user_names_regex)$/i) {
				notify($ERRORS{'DEBUG'}, 0, "ignoring user in image: '$image_user_name'");
				push @image_user_names_ignore, $image_user_name;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "reporting user in image: '$image_user_name'");
				push @image_user_names_report, $image_user_name;
			}
		}
	}
	
	my $firewall_state = $self->get_firewall_state();
	
	if (scalar(@image_user_names_report) > 0 || !$firewall_state || $firewall_state !~ /(1|yes|on|enabled)/i) {
		notify($ERRORS{'DEBUG'}, 0, "reporting $image_name image to imagerevisioninfo table (imagerevision ID: $imagerevision_id):\n" .
			"firewall state: $firewall_state\n" .
			"reservation users found on image: " . join(", ", @image_user_names_reservation) . "\n" .
			"ignored users found on image: " . join(", ", @image_user_names_ignore) . "\n" .
			"users which might not belong on image: " . join(", ", @image_user_names_report)
		);
		
		$self->update_imagerevision_info($imagerevision_id, join(",", @image_user_names_report), $firewall_state);
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_imagerevision_info

 Parameters  : $imagerevision_id, $usernames, $firewall_enabled
 Returns     : boolean
 Description : Updates the imagerevisioninfo table in the database.

=cut

sub update_imagerevision_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $imagerevision_id = shift;
	my $usernames = shift;
	my $firewall_enabled = shift;
	
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'WARNING'}, 0, "imagerevision ID argument was not specified");
		return;
	}
	elsif (!defined($usernames) && !defined($firewall_enabled)) {
		notify($ERRORS{'WARNING'}, 0, "usernames or firewall_enabled argument was not specified");
		return;
	}
	
	$usernames = '' if !$usernames;
	
	if (!defined($firewall_enabled)) {
		$firewall_enabled = 'unknown';
	}
	elsif ($firewall_enabled =~ /^(1|yes|on|enabled)$/i) {
		$firewall_enabled = 'yes';
	}
	elsif ($firewall_enabled =~ /^(0|no|off|disabled)$/i) {
		$firewall_enabled = 'no';
	}
	else {
		$firewall_enabled = 'unknown';
	}
	
	my $update_statement = <<EOF;
INSERT INTO imagerevisioninfo
(
imagerevisionid,
usernames,
firewallenabled,
timestamp
)
VALUES
(
'$imagerevision_id',
'$usernames',
'$firewall_enabled',
NOW()
)
ON DUPLICATE KEY UPDATE
imagerevisionid=VALUES(imagerevisionid),
usernames=VALUES(usernames),
firewallenabled=VALUES(firewallenabled),
timestamp=VALUES(timestamp)
EOF
	
	return database_execute($update_statement);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_firewall_state

 Parameters  : None
 Returns     : If successful: string "ON" or "OFF"
 Description : Determines if the Windows firewall is on or off.

=cut

sub get_firewall_state {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	# Run netsh.exe to get the state of the current firewall profile
	my $command = "$system32_path/netsh.exe firewall show state";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve firewall state");
		return;
	}
	
	# Get the lines containing 'Operational mode'
	# Operational mode                  = Enable
	my @mode_lines = grep(/Operational mode/i, @$output);
	if (!@mode_lines) {
		notify($ERRORS{'WARNING'}, 0, "unable to find 'Operational mode' line in output:\n" . join("\n", @$output));
		return;
	}
	
	# Loop through lines, if any contain "ON", return "ON"
	for my $mode_line (@mode_lines) {
		if ($mode_line =~ /on/i) {
			notify($ERRORS{'OK'}, 0, "firewall state: ON");
			return "ON";
		}
		elsif ($mode_line =~ /off/i) {
			notify($ERRORS{'OK'}, 0, "firewall state: OFF");
			return "OFF";
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "firewall state line does not contain ON or OFF: '$mode_line'");
		}
	}
	
	# No lines were found containing "ON", return "OFF"
	notify($ERRORS{'WARNING'}, 0, "unable to determine firewall state, output:\n" . join("\n", @$output));
	return;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_rdp_port_configuration

 Parameters  : none
 Returns     : boolean
 Description : Checks if the RDP port number configured in the registry matches
               the port number configured for the RDP connect method. If they
               don't match, the registry is modified and the TermService service
               is restarted.

=cut

sub check_rdp_port_configuration {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_short_name();
	
	my $connect_method_info = $self->data->get_connect_methods();
	if (!$connect_method_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to check RDP port, connect method info could not be retrieved");
		return;
	}
	
	# Find the RDP method, retrieve the port
	my $connect_method;
	for my $connect_method_id (keys %$connect_method_info) {
		my $connect_method_name = $connect_method_info->{$connect_method_id}{name};
		if ($connect_method_name =~ /^rdp$/i) {
			$connect_method = $connect_method_info->{$connect_method_id};
			last;
		}
	}
	if (!defined($connect_method)) {
		notify($ERRORS{'DEBUG'}, 0, "no connect method exists named 'rdp':\n" . format_data($connect_method_info));
		return 1;
	}
	
	# Get the port information
	my $connect_method_port_info = $connect_method->{connectmethodport};
	if (!defined($connect_method_port_info) || scalar keys %$connect_method_port_info == 0) {
		notify($ERRORS{'WARNING'}, 0, "no ports are defined for connect method:\n" . format_data($connect_method_info));
		return;
	}
	
	# Extract the port numbers - multiple ports may be defined, for example TCP/3389 and UDP/3389
	my %connect_method_port_hash;
	for my $connect_method_port_id (keys %$connect_method_port_info) {
		my $port = $connect_method_port_info->{$connect_method_port_id}{port};
		$connect_method_port_hash{$port} = 1;
	}
	
	# Make sure a single port number is defined for the RDP connect method
	my @connect_method_ports = keys(%connect_method_port_hash);
	if (!@connect_method_ports) {
		notify($ERRORS{'WARNING'}, 0, "port is not defined for connect method:\n" . format_data($connect_method_port_info));
		return;
	}
	elsif (scalar(@connect_method_ports) > 1) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine which port is supposed to be used for RDP, multiple ports are defined for connect method:\n" . format_data($connect_method_port_info));
		return;
	}
	
	my $connect_method_rdp_port = $connect_method_ports[0];
	my $rdp_port_key = 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';
	my $rdp_port_value = 'PortNumber';
	
	my $existing_rdp_port = $self->reg_query($rdp_port_key, $rdp_port_value);
	if (!defined($existing_rdp_port)) {
		notify($ERRORS{'WARNING'}, 0, "unable to check RDP port on $computer_name, failed to retrieve existing value from registry");
		return;
	}
	elsif ($existing_rdp_port eq $connect_method_rdp_port) {
		notify($ERRORS{'DEBUG'}, 0, "existing RDP port value in registry matches connect method port: $connect_method_rdp_port");
		return 1;
	}
	notify($ERRORS{'DEBUG'}, 0, "existing RDP port value in registry $existing_rdp_port does NOT match connect method port $connect_method_rdp_port");
	
	# Set the registry key
	if (!$self->reg_add($rdp_port_key, $rdp_port_value, 'REG_DWORD', $connect_method_rdp_port)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set RDP port value in registry");
		return;
	}
	
	# The services that depend on TermService must be stopped first or else the restart will fail
	$self->stop_service('UmRdpService');
	$self->stop_service('Mcx2Svc');
	
	if ($self->restart_service('TermService')) {
		notify($ERRORS{'OK'}, 0, "configured $computer_name to use RDP port $connect_method_rdp_port");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to configure $computer_name to use RDP port $connect_method_rdp_port, failed to restart Remote Desktop Service (TermService)");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_port_connection_info

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves information about established connections from the
               computer. A hash is constructed:
                  {
                    "TCP" => {
                      22 => [
                        {
                          "local_ip" => "10.25.10.197",
                          "pid" => 3648,
                          "remote_ip" => "10.25.0.241",
                          "remote_port" => 54692
                        }
                      ],
                      3389 => [
                        {
                          "local_ip" => "192.168.16.238",
                          "pid" => 332,
                          "remote_ip" => "192.168.53.54",
                          "remote_port" => 55892
                        }
                      ]
                    }
                  }

=cut

sub get_port_connection_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $command = "netstat -ano";
	my ($exit_status, $output) = $self->execute($command, 0);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command: $command");
		return;
	}
	elsif (grep(/^netstat: /, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred executing command: '$command', exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	
	my $connection_info = {};
	for my $line (@$output) {
		# Proto  Local Address          Foreign Address         State           PID
		# TCP    192.168.1.53:3389      192.168.53.54:55892     ESTABLISHED     332
		my ($protocol, $local_ip_address, $local_port, $remote_ip_address, $remote_port, $state, $pid) = $line =~ /^\s*(\w+)\s+([\d\.]+):(\d+)\s+([\d\.]+):(\d+)\s+(\w+)\s+(\d+)/i;
		
		if (!$state) {
			#notify($ERRORS{'DEBUG'}, 0, "connection state could not be determined from line:\n$line");
			next;
		}
		elsif ($state !~ /ESTABLISHED/i) {
			next;
		}
		
		my $connection = {
			local_ip => $local_ip_address,
			remote_ip => $remote_ip_address,
			remote_port => $remote_port,
		};
		$connection->{pid} = $pid if $pid;
		
		push @{$connection_info->{$protocol}{$local_port}}, $connection;
	}
	
	if ($connection_info) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved connection info from $computer_node_name:\n" . format_data($connection_info));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "did not detect any connections on $computer_node_name");
	}
	return $connection_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_timezone_offset_minutes

 Parameters  : none
 Returns     : integer
 Description : Retrieves the number of minutes the system time of the computer
               is offset from UTC. It may be positive or negative. This is used
               to adjust times returned by the computer which are not adjusted
               to the computer's time zone such as from event log entries.

=cut

sub get_timezone_offset_minutes {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{timezone_offset_minutes} if defined($self->{timezone_offset_minutes});
	
	my $system32_path = $self->get_system32_path();
	
	my $command = "$system32_path/Wbem/wmic.exe OS Get CurrentTimeZone";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to retrieve timezone offset");
		return;
	}
	
	my ($offset_minutes) = grep(/^-?\d+$/, @$output);
	if (defined($offset_minutes)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved OS timezone offset minutes: $offset_minutes");
		$self->{timezone_offset_minutes} = $offset_minutes;
		return $self->{timezone_offset_minutes};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve OS timezone offset minutes, command: $command, output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 notify_user_console

 Parameters  : message, username(optional)
 Returns     : boolean
 Description : Send a message to the user on the console

=cut

sub notify_user_console {
	my $self = shift;
	if (ref($self) !~ /Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $message = shift;
	if (!$message) {
		notify($ERRORS{'WARNING'}, 0, "message argument was not supplied");
		return;
	}
	
	my $username = shift || $self->data->get_user_login_id();

	my $computer_node_name = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path();

	my $cmd = "$system32_path/msg.exe $username /TIME:180 '$message'";
	my ($exit_status, $output) = $self->execute($cmd, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if the '$cmd' shell command exists on $computer_node_name");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "executed command to determine if the '$cmd' shell command exists on $computer_node_name");
		return 1;
	}
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_cygwin_installation_directory_path

 Parameters  : none
 Returns     : string
 Description : Retrieves the directory path where Cygwin is installed on the
               computer. 32-bit and 64-bit versions of Cygwin may use different
               paths. 

=cut

sub get_cygwin_installation_directory_path {
	my $self = shift;
	if (ref($self) !~ /Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	return $self->{CYGWIN_PATH} if $self->{CYGWIN_PATH};

	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $default_path = 'C:/cygwin';
	
	my $command = "cygpath.exe -m /";
	my ($exit_status, $output) = $self->execute($command, 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine Cygwin installation directory path on $computer_node_name, returning default path: $default_path");
		$self->{CYGWIN_PATH} = $default_path;
		return $self->{CYGWIN_PATH};
	}
	elsif (grep(/^cygpath:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred determining Cygwin installation directory path on $computer_node_name, returning default path: $default_path, output:\n" . join("\n", @$output));
		$self->{CYGWIN_PATH} = $default_path;
		return $self->{CYGWIN_PATH};
	}
	
	my ($directory_path) = grep(/^[a-z]/i, @$output);
	if ($directory_path) {
		notify($ERRORS{'DEBUG'}, 0, "determined Cygwin installation directory path on $computer_node_name: $directory_path");
		$self->{CYGWIN_PATH} = $directory_path;
		return $self->{CYGWIN_PATH};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "error occurred determining Cygwin installation directory path on $computer_node_name, returning default path: $default_path, did not find a line beginning with a letter in the output:\n" . join("\n", @$output));
		$self->{CYGWIN_PATH} = $default_path;
		return $self->{CYGWIN_PATH};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cygwin_unix_file_path

 Parameters  : $file_path
 Returns     : string
 Description : Converts a Windows-style path to a Cygwin/Unix-style path.
               Example: C:\Windows\file.txt --> /cygdrive/c/Windows/file.txt

=cut

sub get_cygwin_unix_file_path {
	my $self = shift;
	if (ref($self) !~ /Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $file_path_argument = shift;
	if (!$file_path_argument) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not specified");
		return;
	}
	
	if ($file_path_argument =~ /^\//) {
		notify($ERRORS{'DEBUG'}, 0, "file path not converted because it begins with a forward slash: $file_path_argument");
		return $file_path_argument;
	}
	elsif ($file_path_argument !~ /[\/\\:]/) {
		notify($ERRORS{'DEBUG'}, 0, "file path not converted because it does not contain a forward slash, backslash, or colon: $file_path_argument");
		return $file_path_argument;
	}
	
	# Change backslashes to forward slashes
	$file_path_argument =~ s/\\+/\//g;
	
	my $command = "cygpath.exe -u \"$file_path_argument\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine Cygwin/Unix-style path, returning argument: $file_path_argument");
		return $file_path_argument;
	}
	
	my ($unix_file_path) = grep(/^\//, @$output);
	if (!$unix_file_path || grep(/^cygpath:/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "error occurred attempting to determine Cygwin/Unix-style path, returning argument: $file_path_argument, command:\n$command\noutput:\n" . join("\n", @$output));
		return $file_path_argument;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "determined Cygwin/Unix-style path: $file_path_argument --> $unix_file_path");
		return $unix_file_path;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cluster_info_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location where the cluster_info files resides on the
               Windows computer, normally C:/cluster_info.

=cut

sub get_cluster_info_file_path {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{cluster_info_file_path} if $self->{cluster_info_file_path};
	
	my $systemroot_value = $self->get_environment_variable_value('SYSTEMDRIVE') || 'C:';
	$self->{cluster_info_file_path} = "$systemroot_value/cluster_info";
	notify($ERRORS{'DEBUG'}, 0, "determined cluster_info file path for Windows: $self->{cluster_info_file_path}");
	return $self->{cluster_info_file_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_info_json_file_path

 Parameters  : none
 Returns     : string
 Description : Returns the location where the files resides on the computer that
               contains JSON formatted information about the reservation.

=cut

sub get_reservation_info_json_file_path {
	my $self = shift;
	if (ref($self) !~ /VCL::Module::OS/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return $self->{reservation_info_json_file_path} if $self->{reservation_info_json_file_path};
	
	my $systemroot_value = $self->get_environment_variable_value('SYSTEMDRIVE') || 'C:';
	$self->{reservation_info_json_file_path} = "$systemroot_value/Users/Administrator/reservation_info.json";	
	notify($ERRORS{'DEBUG'}, 0, "determined reservation info JSON file path file path for " . ref($self) . " OS module: $self->{reservation_info_json_file_path}");
	return $self->{reservation_info_json_file_path};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_set_network_location_prompt

 Parameters  : none
 Returns     : boolean
 Description : Adds a registry key to disable the "Select a location for the
               'Network' network" -- Home, Work, or Public prompt when users log
               in to Windows.

=cut

sub disable_set_network_location_prompt {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $registry_key = 'HKLM\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff';
	return $self->reg_add($registry_key);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_computer_hostname

 Parameters  : none
 Returns     : string
 Description : Retrieves the current hostname the computer is using. If a
               computer was renamed but not rebooted, this will return the
               previous name.

=cut

sub get_current_computer_hostname {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $command = 'cmd.exe /c "C:/Windows/Sysnative/Wbem/wmic.exe COMPUTERSYSTEM GET Name /Value"';
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current computer hostname from $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	# Output should be:
	# Name=vm-100
	my ($line) = grep(/Name=(.+)/i, @$output);
	if (!$line) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current computer name from $computer_name, output does not contain a 'Name=' line:\n" . join("\n", @$output));
		return;
	}
	
	my ($current_computer_name) = $line =~ /Name=(.+)$/ig;
	if (!$current_computer_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve current computer name from $computer_name, failed to parse line: '$line'");
		return;
	}

	notify($ERRORS{'OK'}, 0, "retrieved current computer hostname from $computer_name: '$current_computer_name'");
	return $current_computer_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_computer_hostname

 Parameters  : $new_computer_name (optional)
 Returns     : boolean
 Description : Changes the computer name. If successful, the postoption flag is
               set to 'reboot' which should trigger a reboot after post_load is
               complete.

=cut

sub set_computer_hostname {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $database_computer_hostname = $self->data->get_computer_hostname();
	my $system32_path = $self->get_system32_path() || return;
	
	my $new_computer_name = shift;
	if ($new_computer_name) {
		notify($ERRORS{'DEBUG'}, 0, "attempting to set computer hostname to specified value: $new_computer_name");
	}
	else {
		# Computer name argument was not specified, get the IP address of the public adapter
		my $public_ip_address = $self->get_public_ip_address();
		if ($public_ip_address) {
			# Get the hostname the public IP address resolves to
			$new_computer_name = ip_address_to_hostname($public_ip_address);
			if ($new_computer_name) {
				notify($ERRORS{'DEBUG'}, 0, "resolved public IP address $public_ip_address, attempting to set computer hostname: $new_computer_name");
			}
			else {
				$new_computer_name = $database_computer_hostname;
				notify($ERRORS{'DEBUG'}, 0, "public IP address $public_ip_address does not resolve, attempting to set computer hostname to value specified in database: $new_computer_name");
			}
		}
		else {
			# IP address of the public adapter could not be determined, use the hostname in the database
			$new_computer_name = $database_computer_hostname;
			notify($ERRORS{'DEBUG'}, 0, "attempting to set computer hostname to value specified in database: $new_computer_name");
		}
	}
	
	# Check if the new computer name contains a period
	# If so, split the computer name and DNS suffix
	my $dns_suffix;
	if ($new_computer_name =~ /^([^\.]+)\.(.+)$/) {
		$new_computer_name = $1;
		$dns_suffix = $2;
	}
	
	# Disable 'Change primary DNS suffix when domain membership changes'
	$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters', 'SyncDomainWithMembership', 'REG_DWORD', 0);
	
	# Assemble the command
	my $command = "echo | cmd.exe /c \"$system32_path/Wbem/wmic.exe COMPUTERSYSTEM WHERE Name=\\\"%COMPUTERNAME%\\\" Rename \\\"$new_computer_name\\\"\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to execute command to set computer name of $database_computer_hostname to $new_computer_name");
		return;
	}
	elsif (grep(/(ReturnValue = 0|Method execution successful)/i, @$output)) {
		notify($ERRORS{'OK'}, 0, "set computer name of $database_computer_hostname to $new_computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		push @{$self->{reboot_required}}, "computer hostname was changed";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set computer name of $database_computer_hostname to $new_computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	
	# Set the DNS suffix registry key
	if ($dns_suffix) {
		$self->reg_add('HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\Tcpip\Parameters', 'NV Domain', 'REG_SZ', $dns_suffix);
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_os_perl_package

 Parameters  : $windows_os
 Returns     : string
 Description : 

=cut

sub _get_os_perl_package {
	my $windows_os = shift;
	unless (ref($windows_os) && $windows_os->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $product_name = $windows_os->get_product_name();
	my $perl_package;
	if (!$product_name) {
		return;
	}
	elsif ($product_name =~ /(XP|2003)/i) {
		$perl_package = "VCL::Module::OS::Windows::Version_5::$1";
	}
	elsif ($product_name =~ /(Vista|2008|2012|7|8)/ig) {
		$perl_package = "VCL::Module::OS::Windows::Version_6::$1";
	}
	elsif ($product_name =~ /(2016|10)/ig) {
		$perl_package = "VCL::Module::OS::Windows::Version_10::$1";
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to determine OS installed on computer, unsupported Windows product name: $product_name");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "perl package to use for '$product_name': $perl_package");
	return $perl_package;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 mount_nfs_windows

 Parameters  : $remote_nfs_share, $drive_letter (optional), $options (optional)
 Returns     : boolean
 Description : Mounts an NFS share on the computer using the Windows NFS client.

=cut

sub mount_nfs_windows {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($remote_nfs_share, $drive_letter, $options) = @_;
	if (!defined($remote_nfs_share)) {
		notify($ERRORS{'WARNING'}, 0, "remote target argument was not supplied");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name = $self->data->get_computer_node_name();

	# Usage:  mount [-o options] [-u:username] [-p:<password | *>] <\\computername\sharename> <devicename | *>
	# 
	# -o rsize=size               To set the size of the read buffer in kilobytes.
	# -o wsize=size               To set the size of the write buffer in kilobytes.
	# -o timeout=time             To set the timeout value in seconds for an RPC call.
	# -o retry=number             To set the number of retries for a soft mount.
	# -o mtype=soft|hard          To set the mount type.
	# -o lang=euc-jp|euc-tw|euc-kr|shift-jis|big5|ksc5601|gb2312-80|ansi
	#                             To specify the encoding used for file and directory
	#                             names.
	# -o fileaccess=mode          To specify the permission mode of the file.
	#                             These are used for new files created on NFS
	#                             servers. Specified using UNIX style mode bits.
	# -o anon                     To mount as an anonymous user.
	# -o nolock                   To disable locking.
	# -o casesensitive=yes|no     To specify case sensitivity of file lookup on server.
	# -o sec=sys|krb5|krb5i

	# These formats work:
	#    mount x.x.x.x:/sharename n:
	#    mount \\x.x.x.x\sharename n:
	
	# Windows can't mount directly to a directory, check if a drive letter was passed
	if (!$drive_letter) {
		$drive_letter = '*';
	}
	elsif ($drive_letter !~ /^[a-z]:?$/i) {
		notify($ERRORS{'WARNING'}, 0, "invalid drive letter argument was specified: $drive_letter, using next available drive letter");
		$drive_letter = '*';
	}
	
	# Add a trailing colon
	$drive_letter =~ s/:*$/:/;
	
	my $command = "$system32_path/mount.exe";
	
	# Figure out which options to use	
	# If using Netapp, see: https://library.netapp.com/ecmdocs/ECMP12365051/html/GUID-B7080A75-610D-46E1-A0EE-6CF1716636A0.html
	# According to doc, must use hard mounts for Netapp
	if ($options) {
		# Check if mtype was specified, don't override
		if ($options !~ /mtype/) {
			$options .= ",mtype=hard";
		}
	}
	else {
		$options = "mtype=hard";
	}
	$command .= " -o $options";
	$command .= " $remote_nfs_share $drive_letter";
	
	# Escape *
	$command =~ s/\*/\\\*/g;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to mount NFS share on $computer_name: '$command'");
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: '$command'");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to mount Windows client NFS share on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "mounted Windows client NFS share on $computer_name: '$command'\noutput:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 unmount_nfs_windows

 Parameters  : none
 Returns     : boolean
 Description : Unmounts all NFS shares on the computer using the Windows NFS
               client.

=cut

sub unmount_nfs_windows {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name = $self->data->get_computer_node_name();

	# Usage:  [-f] <-a | drive_letters | network_mounts>
	# -a      Delete all NFS network mount points
	# -f      Force delete NFS network mount points

	my $command = "$system32_path/umount.exe -a -f";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to unmount Windows client NFS shares on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "unmounted Windows client NFS shares on $computer_name: '$command'\noutput:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_nfs_mounts_windows

 Parameters  : none
 Returns     : 
 Description : Retrieves all currently mounted NFS shares on the computer using
               the Windows NFS client.

=cut

sub get_nfs_mounts_windows {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name = $self->data->get_computer_node_name();
	
	my $command = "$system32_path/mount.exe";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve mounted Windows client NFS shares on $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "retrieved mounted Windows client NFS shares on $computer_name, command: '$command', output:\n" . join("\n", @$output));
		return 1;
	}
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_windows_features

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves a list of all features available on the Windows OS. If
               called in scalar context, a hash reference is returned:
               {
                 "Chess" => {
                   "State" => "Disabled"
                 },
                 "ClientForNFS-Infrastructure" => {
                   "State" => "Enabled"
                 },
                 ...
               }
               
               If called in array context, an array of feature names is
               returned:
               (
                  Chess,
                  ClientForNFS-Infrastructure,
                  ...
               )

=cut

sub get_windows_features {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieving Windows features on $computer_name");
	my $command = "$system32_path/cmd.exe /c \"dism /online /get-features /format:table\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve feature info from $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}
	
	my $feature_info = {};
	for my $line (@$output) {
		# Line format:
		# FreeCell                                    | Disabled
		my ($feature_name, $state) = $line =~ /^(\S+)\s+.*(Enabled|Disabled)\s*$/i;
		if (defined($feature_name) && defined($state)) {
			$feature_info->{$feature_name}{State} = $state;
		}
	}
	
	if (!keys(%$feature_info)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve feature info from $computer_name, failed to parse any feature names and states from output:\n" . join("\n", @$output));
		return;
	}
	
	if (wantarray) {
		my @feature_names = sort { lc($a) cmp lc($b) } keys %$feature_info;
		notify($ERRORS{'DEBUG'}, 0, "retrieved feature info from $computer_name, returning array:\n" . join("\n", @feature_names));
		return $feature_info;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved feature info from $computer_name, returning hash reference:\n" . format_data($feature_info));
		return $feature_info;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_windows_feature_info

 Parameters  : $feature_name
 Returns     : hash reference
 Description : Retrieves info for a single Windows feature and constructs a
               hash:
               {
                  "Description" => "Install the .NET Environment for supporting managed code activation",
                  "Display Name" => ".NET Environment",
                  "Feature Name" => "WAS-NetFxEnvironment",
                  "Restart Required" => "Possible",
                  "State" => "Enabled"
               }

=cut

sub get_windows_feature_info {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $feature_name = shift;
	if (!$feature_name) {
		notify($ERRORS{'WARNING'}, 0, "feature name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	notify($ERRORS{'DEBUG'}, 0, "retrieving info for Windows feature on $computer_name: $feature_name");
	my $command = "$system32_path/cmd.exe /c \"DISM.exe /Online /Get-FeatureInfo /FeatureName=$feature_name\"";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif (grep(/Feature name.*is unknown/, @$output)) {
		# Feature name foo is unknown
		notify($ERRORS{'OK'}, 0, "Windows feature is unknown on $computer_name: $feature_name, returning empty hash reference");
		return {};
	}
	elsif ($exit_status ne '0') {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve feature info from $computer_name, exit status: $exit_status, command:\n$command\noutput:\n" . join("\n", @$output));
		return;
	}

	my $feature_information_line_found = 0;
	my $feature_info = {};
	for my $line (@$output) {
		if ($line !~ /\w/) {
			next;
		}
		elsif (!$feature_information_line_found) {
			# Ignore all lines until a 'Feature Information:' line is found
			if ($line =~ /Feature Information:/) {
				$feature_information_line_found = 1;
			}
			next;
		}
		
		# Line format:
		# Display Name : Windows Media Player
		my ($property, $value) = $line =~ /^(\w.*\S)\s+:\s+(\S.*)$/i;
		if (defined($property) && defined($value)) {
			$feature_info->{$property} = $value;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "line does not contain property:value: '$line'");
		}
	}
	
	if (keys(%$feature_info)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved Windows feature info from $computer_name: $feature_name\n" . format_data($feature_info));
		return $feature_info;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve Windows feature info from $computer_name: $feature_name, failed to parse any properties from output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_windows_feature_enabled

 Parameters  : $feature_name
 Returns     : boolean
 Description : Determines whether or not a Windows feature such as the NFS
               client is enabled.

=cut

sub is_windows_feature_enabled {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $feature_name = shift;
	if (!$feature_name) {
		notify($ERRORS{'WARNING'}, 0, "feature name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $feature_info = $self->get_windows_feature_info($feature_name) || return;
	if (!keys(%$feature_info)) {
		notify($ERRORS{'DEBUG'}, 0, "Windows feature is NOT enabled on $computer_name because the feature is unknown: $feature_name");
		return 0;
	}
	elsif (!defined($feature_info->{State})) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine if Windows feature is enabled on $computer_name: $feature_name, feature info does not contain a 'State' key:\n" . format_data($feature_info));
		return;
	}
	
	my $state = $feature_info->{State};
	if ($state =~ /Enabled/i) {
		notify($ERRORS{'DEBUG'}, 0, "Windows feature is enabled on $computer_name: $feature_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Windows feature is NOT enabled on $computer_name: $feature_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 enable_windows_feature

 Parameters  : $feature_name
 Returns     : boolean
 Description : Enables a Windows feature. This will also recursively enable any
               parent features which must be enabled before the feature
               specified by the argument can be enabled.

=cut

sub enable_windows_feature {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($feature_name, $no_recurse) = @_;
	if (!$feature_name) {
		notify($ERRORS{'WARNING'}, 0, "feature name argument was not specified");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $log_path = "C:/Windows/Logs/DISM/$feature_name.log";

	my $command = "$system32_path/cmd.exe /c \"DISM.exe /Online /Enable-Feature /FeatureName:$feature_name /NoRestart /LogPath=$log_path\"";
	notify($ERRORS{'DEBUG'}, 0, "enabling Windows feature on $computer_name: $feature_name, command:\n$command");
	my ($exit_status, $output) = $self->execute({
		command => $command,
		timeout_seconds => 120,
		display_output => 0,
	});
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command on $computer_name: $command");
		return;
	}
	elsif (grep(/completed successfully/, @$output)) {
		notify($ERRORS{'OK'}, 0, "enabled Windows feature on $computer_name: $feature_name");
		return 1;
	}
	
	my $parent_feature_found = 0;
	if (!$no_recurse) {
		# Check if parent features need to be enabled first, line like this will exist:
		#    Ensure that the following parent feature(s) are enabled first
		#    IIS-Security, IIS-WebServer, IIS-WebServerRole
		my $parent_feature_line_found = 0;
		LINE: for my $line (@$output) {
			if ($line !~ /\w/) {
				next LINE;
			}
			elsif (!$parent_feature_line_found) {
				if ($line =~ /Ensure that the following parent feature.*enabled first/) {
					$parent_feature_line_found = 1;
				}
				next LINE;
			}
			
			# Stop checking if this line is found:
			#    The DISM log file can be found at C:\Windows\Logs\DISM\dism.log
			if ($line =~ /DISM log file/) {
				last LINE;
			}
			
			my @parent_feature_names = split(/,\s+/, $line);
			if (@parent_feature_names) {
				$parent_feature_found = 1;
				notify($ERRORS{'DEBUG'}, 0, "parent Windows feature(s) need to be enabled before $feature_name can be enabled: " . join("\n", @parent_feature_names));
				for my $parent_feature_name (@parent_feature_names) {
					if (!$self->enable_windows_feature($parent_feature_name)) {
						notify($ERRORS{'WARNING'}, 0, "failed to enable Windows feature on $computer_name: $feature_name, failed to enable parent feature: $parent_feature_name");
						return;
					}
				}
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "line does not appear to contain the name of a parent feature: '$line'");
				next LINE;
			}
		}
	}
	
	# Check if any parent features were found which need to be enabled first
	# If not, failed to enable feature for some other reason
	if ($parent_feature_found) {
		# Make one more attempt to enable the feature, do not attempt to install parent features again ($no_recurse = 1)
		return $self->enable_windows_feature($feature_name, 1);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to enable Windows feature on $computer_name: $feature_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output));
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_powershell_command

 Parameters  : $powershell_script_contents, $display_output (optional), $encode_command (optional)
 Returns     : array ($exit_status, $output)
 Description : Runs Powershell code as a command.

=cut

sub run_powershell_command {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($powershell_command_argument, $display_output, $encode_command) = @_;
	if (!$powershell_command_argument) {
		notify($ERRORS{'WARNING'}, 0, "powershell script contents argument was not supplied");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name	= $self->data->get_computer_short_name();
	
	# -Version Starts the specified version of Windows PowerShell 
	# -NoLogo Hides the copyright banner at startup
	# -NoExit Does not exit after running startup commands 
	# -Sta Start the shell using a single-threaded apartment 
	# -NoProfile Does not use the user profile
	# -NonInteractive Does not present an interactive prompt to the user.
	# -InputFormat Valid values are "Text" (text strings) or "XML"
	# -OutputFormat Valid values are "Text" (text strings) or "XML"
	# -EncodedCommand Accepts a base-64-encoded string version of a command
	# -File Execute a script file.
	# -ExecutionPolicy Sets the default execution policy for the session
	# -Command 	Executes the specified commands
	
	#my $command = "$system32_path/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -NonInteractive";
	
	my $command;
	$command .= 'cmd.exe /c "';
	$command .= "$system32_path/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -NonInteractive";
	
	
	if ($encode_command) {
		# Use the -EncodedCommand argument to avoid the need to escape various special characters
		# The 2nd argument to encode_base64 needs to be an empty string or else it will break the encoded string up into 76 character lines
		my $powershell_command_encoded = encode_base64(encode("UTF-16LE", $powershell_command_argument), "");
		
		#$command .= " -InputFormat Text";
		$command .= " -OutputFormat Text";
		$command .= " -EncodedCommand $powershell_command_encoded";
	}
	else {
		# Replace newlines with semicolon
		$powershell_command_argument =~ s/[\n\r]+/ ; /g;
		
		# Clean up semicolons
		$powershell_command_argument =~ s/\s+;[\s;]*/ ; /g;
		
		# Remove semicolons from before and after curly brackets
		$powershell_command_argument =~ s/[\s;]*([{}])[\s;]*/ $1 /g;
		
		#$powershell_command_argument .= ' ; [Environment]::Exit(!\$?)';
		$command .= " -Command \\\"$powershell_command_argument\\\"";
	}
	$command .= ' < NUL"';
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to run PowerShell command on $computer_name:\n$command") if $display_output;
	my ($exit_status, $output) = $self->execute({
		command => $command,
		display_output => 0,
		timeout_seconds => 30,
		#no_persistent_connection => 1,
		max_attempts => 1,
	});
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to run PowerShell command on $computer_name");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "ran PowerShell command on $computer_name, exit status: $exit_status, command: '$command', output:\n" . join("\n", @$output)) if $display_output;
		return ($exit_status, $output);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_powershell_as_script

 Parameters  : $powershell_script_contents, $display_output (optional), $retain_script_file (optional)
 Returns     : array ($exit_status, $output)
 Description : Accepts a string containing the contents of a Powershell script,
               creates the script on the computer under C:\cygwin\VCL\Scripts,
               and executes the script. The script is named after the calling
               subroutine, so ad_join_ps.ps1 would be generated when invoked from
               ad_join_ps().
               
               By default, the script file is deleted after it is executed for
               safety. This can be overridden if the $retain_script_file
               argument is true.
=cut

sub run_powershell_as_script {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($script_contents_argument, $display_output, $retain_script_file) = @_;
	if (!$script_contents_argument) {
		notify($ERRORS{'WARNING'}, 0, "powershell script contents argument was not supplied");
		return;
	}
	
	my $system32_path = $self->get_system32_path() || return;
	my $computer_name	= $self->data->get_computer_short_name();
	
	# Figure out the script location
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $calling_subroutine = get_calling_subroutine();
	$calling_subroutine =~ s/.*:://g;
	my $powershell_script_path = "$node_configuration_directory/Scripts/$calling_subroutine.ps1";
	
	# Remove trailing newlines and blank lines
	$script_contents_argument =~ s/[\r\n]+$//g;
	
	# Create copy of script contents, use this for execution, copied in case transformations need to be made in the future
	my $script_contents = $script_contents_argument;
	
	$self->create_text_file($powershell_script_path, $script_contents);
	
	# Running Powershell scripts/commands via Cygwin has issues because Powershell.exe does screwy things with the terminal
	# If OS.pm::execute_new is used (persistent SSH connection), script hangs if
	# run normally and does not exit with [Environment]::Exit(x)
	# Using run_ssh_command fails to determine the correct exit status but does not hang regardless of how script exits.
	# Wrapping the script in cmd.exe /c "... < NUL" seems to prevent execute_new from hanging and the exit status is correct
	
	my $command;
	$command .= 'cmd.exe /c "';
	$command .= "$system32_path/WindowsPowerShell/v1.0/powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $powershell_script_path";
	$command .= ' < NUL"';
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to execute PowerShell script: $powershell_script_path, contents:\n$script_contents") if $display_output;
	my ($exit_status, $output) = $self->execute({
		command => $command,
		display_output => 1,
		timeout_seconds => 60,
		#no_persistent_connection => 1,
		max_attempts => 1,
	});
	
	# Delete the script file unless retain flag was specified
	if ($retain_script_file) {
		notify($ERRORS{'DEBUG'}, 0, "script NOT deleted because \$retain_script_file argument was specified");
		
		# TODO: add subs to correctly set Windows file permissions
		# Open up permissions so Powershell file can easily be debugged on the Windows computer by users other than root
		$self->execute("chmod -v 777 `cygpath \"$powershell_script_path\"`", 1);
	}
	else {
		$self->delete_file($powershell_script_path);
	}
	
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to run PowerShell commands as script on $computer_name");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "ran PowerShell commands as script on $computer_name, exit status: $exit_status, command: '$command', script contents:\n$script_contents_argument\noutput:\n" . join("\n", @$output)) if $display_output;
		return ($exit_status, $output);
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 powershell_command_exists

 Parameters  : $powershell_command
 Returns     : boolean
 Description : Checks if a PowerShell command or cmdlets exists on the computer.

=cut

sub powershell_command_exists {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $powershell_command_argument = shift;
	if (!$powershell_command_argument) {
		notify($ERRORS{'WARNING'}, 0, "powershell command argument was not supplied");
		return;
	}
	
	my $computer_name	= $self->data->get_computer_short_name();
	
	my $powershell_command = "Get-Command $powershell_command_argument | Format-List Name";
	my ($exit_status, $output) = $self->run_powershell_command($powershell_command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if '$powershell_command' PowerShell command exists on $computer_name");
		return;
	}
	elsif (grep(/(NotFound)/, @$output)) {
		notify($ERRORS{'DEBUG'}, 0, "PowerShell command does NOT exist on $computer_name: $powershell_command_argument, output:\n" . join("\n", @$output));
		return 0;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "PowerShell command exists on $computer_name: $powershell_command_argument, output:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_ad_computer_ou_dn

 Parameters  : none
 Returns     : boolean
 Description : Converts an OU path as displayed on the Object tab when viewing
               an OU's properties in the Active Directory Users and Computers
               tool from:
               my.ad.domain/Org/Unit/ComputerOU
               To:
               OU=ComputerOU,OU=Unit,OU=Org,DC=domain,DC=ad,DC=my

=cut

sub get_ad_computer_ou_dn {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	
	# Accepts a $computer_ou argument but should only be used for testing
	my $computer_ou = shift || $self->data->get_image_domain_base_ou();
	my $computer_ou_original = $computer_ou;
	
	if (!defined($domain_dns_name)) {
		notify($ERRORS{'WARNING'}, 0, "AD domain DNS name is not configured");
		return;
	}
	elsif (!defined($computer_ou)) {
		notify($ERRORS{'DEBUG'}, 0, "AD domain computer OU is not configured");
		return;
	}
	
	# Possible cases:
	#    OU=ComputerOU,OU=VCL,DC=my,DC=ad,DC=domain
	#    OU=ComputerOU,OU=VCL
	#    ComputerOU,VCL
	#    ComputerOU
	#    my.ad.domain/VCL/ComputerOU
	#    VCL/ComputerOU
	
	# OU can either contain commas or slashes but not both - determines which order to put OU parts back together in
	if ($computer_ou =~ /,/ && $computer_ou =~ /\//) {
		notify($ERRORS{'WARNING'}, 0, "invalid AD OU, it can't contain both a comma and slash: $computer_ou");
		return;
	}
	
	# Remove domain DN section if it was specified for the image
	$computer_ou =~ s/,DC=.*//g;
	
	# Strip out OU= parts, will be added later
	$computer_ou =~ s/\s*OU=//g;
	
	# Assemble the domain part of the DN based on the domain DNS name
	my @domain_parts = split(/\./, $domain_dns_name);
	my $domain_section = "DC=" . join(",DC=", @domain_parts);
	
	# Check which order the OU parts should be reassembled in
	my @ou_parts;
	if ($computer_ou =~ /\//) {
		# my.ad.domain/VCL/ComputerOU
		# VCL/ComputerOU
		@ou_parts = reverse split(/\/+/, $computer_ou);
		
		# Check if last part contains a period, if so, strip it
		if ($ou_parts[-1] =~ /\./) {
			pop @ou_parts;
		}
	}
	else {
		@ou_parts = split(/,+/, $computer_ou);
	}
	my $ou_section = "OU=" . join(",OU=", @ou_parts);
	
	my $dn = "$ou_section,$domain_section";
	
	notify($ERRORS{'DEBUG'}, 0, "converted computer OU to DN: $computer_ou_original --> $dn");
	return $dn;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_join_prepare

 Parameters  : none
 Returns     : boolean
 Description : Performs tasks necessary prior to joining a computer to an Active
               Directory domain:
               * Ensures the 'TCP NetBIOS helper' service is started
               * Sets static DNS servers if configured for the domain
               * Deletes existing matching computer objects

=cut

sub ad_join_prepare {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Enable and start the TCP NetBIOS helper service
	$self->set_service_startup_mode('lmhosts', 'auto');
	$self->start_service('lmhosts');
	
	# Set specific DNS servers for private and public interfaces if DNS servers are configured
	$self->set_static_dns_servers();
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 node_status_os_check

 Parameters  : none
 Returns     : boolean
 Description : Called from provisioning module's node_status subroutine. This
               checks if the loaded computer's Active Directory configuration is
               correct if image is configured to join an AD domain.

=cut

sub node_status_os_check {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if computer AD configuration is correct if image is configured for AD
	# Returning false indicates AD configuration could not be corrected and calling subroutine should reload the computer
	return $self->ad_check();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_check

 Parameters  : none
 Returns     : boolean
 Description : Checks if the computer is joined to an Active Directory domain
               and located in the correct OU.

=cut

sub ad_check {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name	= $self->data->get_computer_short_name();
	my $image_domain_dns_name = $self->data->get_image_domain_dns_name();
	
	# Check if the computer is joined to any AD domain
	my $computer_current_domain_name = $self->ad_get_current_domain();
	
	if (!$image_domain_dns_name) {
		# Computer should NOT be joined to an AD domain
		if (!$computer_current_domain_name) {
			notify($ERRORS{'OK'}, 0, "image is not configured for Active Directory and $computer_name is not joined to a domain, returning 1");
			return 1;
		}
		
		# Computer incorrectly joined to an AD domain, attempt to unjoin the domain
		notify($ERRORS{'OK'}, 0, "$computer_name is joined to the $computer_current_domain_name domain but the image is not configured for Active Directory, attempting to unjoin the domain");
		if ($self->ad_unjoin()) {
			notify($ERRORS{'OK'}, 0, "image is not configured for Active Directory, unjoined $computer_name from $computer_current_domain_name domain, returning 1");
			return 1;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "image is not configured for Active Directory, failed to unjoin $computer_name from $computer_current_domain_name domain, returning undefined");
			return;
		}
	}
	
	# Computer should be joined to AD domain
	if (!$computer_current_domain_name) {
		# Computer is not joined to an AD domain, return the result of attempting to join
		notify($ERRORS{'OK'}, 0, "image is configured to join the $image_domain_dns_name domain, $computer_name is not joined to a domain, attempting to join the domain");
		return $self->ad_join_ps();
	}
	
	
	# Computer is joined to an AD domain, check if it's in the correct domain
	if ($computer_current_domain_name ne $image_domain_dns_name) {
		# Computer is not joined to the correct domain, attempt to unjoin and then rejoin
		notify($ERRORS{'DEBUG'}, 0, "$computer_name is joined to the $computer_current_domain_name domain, image is configured to join the $image_domain_dns_name, attempting to unjoin then join the correct domain");
		if (!$self->ad_unjoin()) {
			notify($ERRORS{'WARNING'}, 0, "image is configured to join the $image_domain_dns_name, failed to unjoin $computer_name from the $computer_current_domain_name domain, returning undefined");
			return;
		}
		elsif (!$self->ad_join_ps()) {
			notify($ERRORS{'WARNING'}, 0, "image is configured to join the $image_domain_dns_name, unjoined $computer_name from the incorrect $computer_current_domain_name domain but failed to rejoin the correct $image_domain_dns_name domain, returning undefined");
			return;
		}
		else {
			notify($ERRORS{'OK'}, 0, "unjoined $computer_name from the incorrect $computer_current_domain_name and rejoined to the correct domain: $image_domain_dns_name, returning 1");
			return 1;
		}
	}
	
	# Computer is joined to the correct AD domain, make sure computer object is in the correct OU
	
	# Determine the OU configured for the image
	my $image_ou_dn = $self->get_ad_computer_ou_dn();
	if (!$image_ou_dn) {
		notify($ERRORS{'WARNING'}, 0, "image is configured to join the $image_domain_dns_name domain but proper computer OU DN could not be determined, returning undefined");
		return;
	}
	
	# Get the computer's current OU
	my $computer_current_dn = $self->ad_search_computer();
	if (!$computer_current_dn) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name is joined to the correct $computer_current_domain_name domain but current OU could not be determined, assuming computer object is in the correct OU, returning 1");
		return 1;
	}
	
	# Extract the OU DN from the DN of the computer object
	my ($computer_current_ou_dn) = $computer_current_dn =~ /^[^,]+,(OU=.+)$/;
	if (!$computer_current_ou_dn) {
		notify($ERRORS{'WARNING'}, 0, "$computer_name is joined to the correct $computer_current_domain_name domain but current OU DN could not be parsed from current computer object DN: '$computer_current_dn', assuming computer object is in the correct OU, returning 1");
		return 1;
	}
	
	if ($computer_current_ou_dn =~ /^$image_ou_dn$/i) {
		notify($ERRORS{'OK'}, 0, "$computer_name is joined to the correct domain and in the correct OU, returning 1:\n" .
			"current domain: $computer_current_domain_name\n" .
			"computer object OU: $computer_current_ou_dn"
		);
		return 1;
	}
	
	# Computer is in the wrong OU
	notify($ERRORS{'OK'}, 0, "$computer_name is joined to the correct $computer_current_domain_name domain but located in the wrong OU, attempting to unjoin then rejoin the domain in the correct OU:\n" .
		"OU configured for image    : $image_ou_dn\n" .
		"current computer object OU : $computer_current_ou_dn"
	);
	if (!$self->ad_unjoin()) {
		notify($ERRORS{'WARNING'}, 0, "failed to unjoin $computer_name from the $computer_current_domain_name domain in order to rejoin in the correct OU, returning undefined");
		return;
	}
	elsif (!$self->ad_join_ps()) {
		notify($ERRORS{'WARNING'}, 0, "failed to rejoin $computer_name to the correct OU in the $image_domain_dns_name domain: '$image_ou_dn', returning undefined");
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "rejoined $computer_name to the correct OU in the $image_domain_dns_name domain: '$image_ou_dn', returning 1");
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_join_ps

 Parameters  : none
 Returns     : boolean
 Description : Joins the computer to the Active Directory domain configured for
               the image.

=cut

sub ad_join_ps {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Calculate how long the tasks take
	my $start_time = time;
	my $rename_computer_reboot_duration = 0;
	my $ad_join_reboot_duration = 0;
	
	my $computer_name	= $self->data->get_computer_short_name();
	my $image_name	= $self->data->get_image_name();
	
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	my $domain_username = $self->data->get_image_domain_username();
	my $domain_password = $self->data->get_image_domain_password();
	my $computer_ou_dn = $self->get_ad_computer_ou_dn();
	
	if (!defined($domain_dns_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, image $image_name is not assigned to a domain");
		return;
	}
	elsif (!defined($domain_username)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, user name is not configured for $domain_dns_name domain");
		return;
	}
	elsif (!defined($domain_password)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, password is not configured for $domain_dns_name domain");
		return;
	}
	
	# Figure out/fix the computer OU and assemble optional section to add to PowerShell command
	my $domain_computer_command_section = '';
	if ($computer_ou_dn) {
		$domain_computer_command_section = "-OUPath '$computer_ou_dn'";
	}
	
	my $domain_user_string = "$domain_username\@$domain_dns_name";
	
	# Escape single quotes by doubling them
	(my $domain_password_escaped = $domain_password) =~ s/(['])/$1$1/g;
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to join $computer_name to AD\n" .
		"domain DNS name    : $domain_dns_name\n" .
		"domain user string : $domain_user_string\n" .
		"domain password    : $domain_password (escaped: $domain_password_escaped)\n" .
		"domain computer OU : " . ($computer_ou_dn ? $computer_ou_dn : '<not configured>')
	);
	
	# Perform preparation tasks
	$self->ad_join_prepare() || return;
	
	# Note: commented out because this isn't consistently working
	# The rename occasionally fails with 'The directory service is busy.'
	# Check if the computer needs to be renamed
	#my $current_computer_hostname = $self->get_current_computer_hostname() || '<unknown>';
	#if (lc($current_computer_hostname) ne lc($computer_name)) {
	#	notify($ERRORS{'DEBUG'}, 0, "$computer_name needs to be renamed, current hostname: '$current_computer_hostname'");
	#	
	#	# Check if computer supports PowerShell Rename-Computer cmdlet
	#	# If it does, computer can be renamed and joined to AD in 1 step with 1 reboot
	#	# Otherwise, computer name needs to be changed, rebooted, then added to AD
	#	my $powershell_supports_rename = $self->powershell_command_exists('Rename-Computer');
	#	if ($powershell_supports_rename) {
	#		$ad_powershell_script .= "Start-Sleep -Seconds 10\n";
	#		$ad_powershell_script .= "Rename-Computer -NewName $computer_name -DomainCredential \$ps_credential -Force -Verbose\n";
	#	}
	#	else {
	#		notify($ERRORS{'DEBUG'}, 0, "PowerShell version on $computer_name does NOT support Rename-Computer, renaming computer");
			if (!$self->set_computer_hostname()) {
				notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, PowerShell version does NOT support Rename-Computer, failed to rename using traditional method");
				return;
			}
			
			my $rename_computer_reboot_start = time;
			if (!$self->reboot(300, 3, 1)) {
				notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, failed to reboot computer after it was renamed");
				return;
			}
			$rename_computer_reboot_duration = (time - $rename_computer_reboot_start);
	#	}
	#}
	
	# Need to make sure computer object with same name doesn't already exist
	# If object exists in different OU, the following error will occur when attempting to join the domain:
	#    This command cannot be executed on target computer('<name>') due to following error: The account already exists.
	# Don't bother moving existing objects
	$self->ad_delete_computer();
	
	# Assemble the PowerShell script
	my $ad_powershell_script = <<EOF;
\$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(5000, 500)
Clear-Host
\$username = '$domain_user_string'
\$password = '$domain_password_escaped'
Write-Host "username (between >*<): `n>\$username<`n"
Write-Host "password (between >*<): `n>\$password<`n"
\$ps_credential = New-Object System.Management.Automation.PsCredential(\$username, (ConvertTo-SecureString \$password -AsPlainText -Force))
Add-Computer -DomainName '$domain_dns_name' -Credential \$ps_credential $domain_computer_command_section -Verbose -ErrorAction Stop
EOF
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to join $computer_name to $domain_dns_name domain using PowerShell script:\n$ad_powershell_script");
	my ($exit_status, $output) = $self->run_powershell_as_script($ad_powershell_script, 0, 0); # (path, show output, retain file)
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute PowerShell script to join $computer_name to Active Directory domain");
		return;
	}
	
	# Success:
	# WARNING: The changes will take effect after you restart the computer
	# VCLV98-248.
	
	# Possible errors:
	
	# File C:\Users\Administrator\Desktop\ad_join_ps.ps1 cannot be loaded because
	# the execution of scripts is disabled on this system. Please see "get-help
	# about_signing" for more details.
	
	# OU doesn't exist:
	# Add-Computer : This command cannot be executed on target
	# computer('VCLV98-248') due to following error: The system cannot find the
	# file specified.
	
	# Could happen if DNS isn't properly configured:
	# This command cannot be executed on target computer('WIN7') due to following
	# error: The specified domain either does not exist or could not be
	# contacted.
	
	# Computer already added to AD in another OU:
	# Add-Computer : This command cannot be executed on target
	# computer('VCLV98-247') due to following error: The account already exists.
	
	my $reboot_after_join = 1;
	if (grep(/(failed to join|error:|does not exist|cannot be loaded)/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, output:\n" . join("\n", @$output));
		return 0;
	}
	elsif (grep(/already in that domain/i, @$output)) {
		# Add-Computer : Cannot add computer '<hostname>' to domain '<domain DNS name>' because it is already in that domain.
		notify($ERRORS{'OK'}, 0, "$computer_name is already joined to Active Directory domain, output:\n" . join("\n", @$output));
		$reboot_after_join = 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "executed PowerShell script to join $computer_name to Active Directory domain, output:\n" . join("\n", @$output));
	}
	
	if ($reboot_after_join) {
		# Reboot, computer should be joined to AD with the correct hostname
		# If computer had to be rebooted to be renamed, certain tasks in reboot() don't need to be performed again
		# Set reboot()'s last $pre_configure flag accordingly
		my $ad_join_reboot_pre_configure = ($rename_computer_reboot_duration ? 0 : 1);
		
		my $ad_join_reboot_start = time;
		if (!$self->reboot(300, 3, 1, $ad_join_reboot_pre_configure)) {
			notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, failed to reboot computer after it joined the domain");
			return;
		}
		$ad_join_reboot_duration = (time - $ad_join_reboot_start);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name does NOT need to be rebooted because it was already joined to the domain");
	}
	
	my $total_duration = (time - $start_time);
	my $other_tasks_duration = ($total_duration - $rename_computer_reboot_duration - $ad_join_reboot_duration);
	
	# Verify computer is now in the correct AD domain
	my $current_domain = $self->ad_get_current_domain();
	if (!$current_domain) {
		notify($ERRORS{'WARNING'}, 0, "attempted to join $computer_name to $domain_dns_name domain but name of domain computer is currently joined to could not be retrieved, PowerShell script execution output:\n" . join("\n", @$output));
		return;
	}
	elsif ($domain_dns_name !~ /^$current_domain/) {
		notify($ERRORS{'WARNING'}, 0, "attempted to join $computer_name to $domain_dns_name domain but computer is currently joined to $current_domain domain, PowerShell script execution output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "successfully joined $computer_name to Active Directory domain: $domain_dns_name, time statistics:\n" .
			"computer rename reboot : $rename_computer_reboot_duration seconds\n" .
			"AD join reboot         : $ad_join_reboot_duration seconds\n" .
			"other tasks            : $other_tasks_duration seconds\n" .
			"-------------------------------------\n" .
			"total                  : $total_duration seconds"
		);
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_join_wmic

 Parameters  : none
 Returns     : boolean
 Description : Joins the computer to the Active Directory domain configured for
               the image using the wmic.exe utility as opposed to a PowerShell
               script.

=cut

sub ad_join_wmic {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Calculate how long the tasks take
	my $start_time = time;
	my $rename_computer_reboot_duration = 0;
	my $ad_join_reboot_duration = 0;
	
	my $computer_name	= $self->data->get_computer_node_name();
	my $image_name	= $self->data->get_image_name();
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	my $domain_username = $self->data->get_image_domain_username();
	my $domain_password = $self->data->get_image_domain_password();
	my $computer_ou_dn = $self->get_ad_computer_ou_dn();
	
	if (!defined($domain_dns_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, image $image_name is not assigned to a domain");
		return;
	}
	elsif (!defined($domain_username)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, user name is not configured for $domain_dns_name domain");
		return;
	}
	elsif (!defined($domain_password)) {
		notify($ERRORS{'WARNING'}, 0, "unable to add $computer_name to AD, password is not configured for $domain_dns_name domain");
		return;
	}
	
	if ($computer_ou_dn) {
		# OU=testOU,DC=domain,DC=Domain,DC=com --> OU=testOU; DC=domain; DC=Domain; DC=com
		$computer_ou_dn =~ s/\s*,\s*/; /g;
	}
	
	my $domain_password_escaped = quotemeta($domain_password);
	
	# Check if the computer needs to be renamed
	my $current_computer_hostname = $self->get_current_computer_hostname() || '<unknown>';
	if (lc($current_computer_hostname) ne lc($computer_name)) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name needs to be renamed, current hostname: '$current_computer_hostname'");
		
		if (!$self->set_computer_hostname()) {
			notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, PowerShell version does NOT support Rename-Computer, failed to rename using traditional method");
			return;
		}
			
		my $rename_computer_reboot_start = time;
		if (!$self->reboot(300, 3, 1)) {
			notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, failed to reboot computer after it was renamed");
			return;
		}
		$rename_computer_reboot_duration = (time - $rename_computer_reboot_start);
	}
	
	$self->ad_delete_computer();
	
	my $error_messages = {
		5    => 'Access is denied',
		53   => 'Network path not found',
		87   => 'The parameter is incorrect',
		110  => 'The system cannot open the specified object',
		1323 => 'Unable to update the password',
		1332 =>'No mapping between account names and security IDs was done',
		1326 => 'Logon failure: unknown username or bad password',
		1355 => 'The specified domain either does not exist or could not be contacted',
		1909 => 'User account locked out',
		2224 => 'The account already exists',
		2691 => 'The machine is already joined to the domain',
		2692 => 'The machine is not currently joined to a domain',
		2695 => 'The specified workgroup name is invalid',
		2697 => 'The specified computer account could not be found',
		8206 => 'The directory service is busy',
	};

	# Perform preparation tasks
	$self->ad_join_prepare() || return;
	
	# NETSETUP_JOIN_DOMAIN                      1 (0x00000001) - Join domain. If not specified, joins workgroup.
	# NETSETUP_ACCT_CREATE                      2 (0x00000002) - Create domain computer account
	# NETSETUP_DOMAIN_JOIN_IF_JOINED           32 (0x00000020) - Join domain if computer is already joined to a domain.
	# NETSETUP_DEFER_SPN_SET                  256 (0x00000100) - Don't update service principal name (SPN) and the DnsHostName properties on the computer. They should be updated in a subsequent call to Rename
	# NETSETUP_JOIN_WITH_NEW_NAME             512 (0x00000400) - 
	my $join_options = 0;
	$join_options += 1;
	$join_options += 2;
	#$join_options += 32;
	#$join_options += 256;
	#$join_options += 512;
	
	# Assemble the join command
	#    Name - domain or workgroup to join
	#    Password
	#    UserName - NetBIOS name Domain\sAMAccountName or user principal name: username@domain.
	#    AccountOU - format: "OU=testOU; DC=domain; DC=Domain; DC=com"
	#    FJoinOptions - join option bit flags, (0) Default. No join options.
	my $join_command = 'echo | cmd.exe /c "';
	$join_command .= "$system32_path/Wbem/wmic.exe /INTERACTIVE:OFF ComputerSystem WHERE Name=\\\"%COMPUTERNAME%\\\" Call JoinDomainOrWorkgroup";
	$join_command .= " Name=$domain_dns_name";
	$join_command .= " UserName=\\\"$domain_username\@$domain_dns_name\\\"";
	$join_command .= " Password=\"$domain_password_escaped\"";
	$join_command .= " AccountOU=\\\"$computer_ou_dn\\\"" if ($computer_ou_dn);
	$join_command .= " FjoinOptions=$join_options";
	$join_command .= '"';
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to join $computer_name to Active Directory domain $domain_dns_name using wmic.exe, command:\n$join_command");
	my ($join_exit_status, $join_output) = $self->execute($join_command);
	if (!defined($join_output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to execute command to join $computer_name to Active Directory domain $domain_dns_name using wmic.exe");
		return;
	}
	# Executing (\\WIN7\ROOT\CIMV2:Win32_ComputerSystem.Name="WIN7")->JoinDomainOrWorkgroup()
	# Method execution successful.
	# Out Parameters:
	# instance of __PARAMETERS
	# {
	#    ReturnValue = 0;
	# };
	my $join_output_string = join("\n", @$join_output);
	my ($join_return_value) = $join_output_string =~ /ReturnValue = (\d+);/;
	if (!defined($join_return_value)) {
		notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain $domain_dns_name using wmic.exe, output does not contain 'ReturnValue =':\n$join_output_string");
		return;
	}
	elsif ($join_return_value == 0) {
		notify($ERRORS{'OK'}, 0, "joined $computer_name to Active Directory domain $domain_dns_name using wmic.exe");
	}
	elsif (my $error_message = $error_messages->{$join_return_value}) {
		notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain $domain_dns_name using wmic.exe, reason: $error_message\noutput:\n$join_output_string");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain $domain_dns_name using wmic.exe for an unknown reason, to troubleshoot, search the web for 'wmic.exe ComputerSystem JoinDomainOrWorkgroup ReturnValue $join_return_value', output:\n$join_output_string");
		return;
	}
	
	# Reboot, computer should be joined to AD with the correct hostname
	# If computer had to be rebooted to be renamed, certain tasks in reboot() don't need to be performed again
	# Set reboot()'s last $pre_configure flag accordingly
	my $ad_join_reboot_pre_configure = ($rename_computer_reboot_duration ? 0 : 1);
	
	my $ad_join_reboot_start = time;
	if (!$self->reboot(300, 3, 1, $ad_join_reboot_pre_configure)) {
		notify($ERRORS{'WARNING'}, 0, "failed to join $computer_name to Active Directory domain, failed to reboot computer after it joined the domain");
		return;
	}
	$ad_join_reboot_duration = (time - $ad_join_reboot_start);
	
	my $total_duration = (time - $start_time);
	my $other_tasks_duration = ($total_duration - $rename_computer_reboot_duration - $ad_join_reboot_duration);
	
	notify($ERRORS{'DEBUG'}, 0, "successfully joined $computer_name to Active Directory domain: $domain_dns_name, time statistics:\n" .
		"computer rename reboot : $rename_computer_reboot_duration seconds\n" .
		"AD join reboot         : $ad_join_reboot_duration seconds\n" .
		"other tasks            : $other_tasks_duration seconds\n" .
		"total                  : $total_duration seconds"
	);
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_unjoin

 Parameters  : none
 Returns     : boolean
 Description : Unjoins the computer from the Active Directory domain by
               attempting to add the computer to a workgroup named 'VCL'. If
               successful, the computer object is deleted from the domain.

=cut

sub ad_unjoin {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name	= $self->data->get_computer_short_name();
	my $image_name	= $self->data->get_image_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $computer_current_domain = $self->ad_get_current_domain();
	if (!$computer_current_domain) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name does not need to be removed from AD because it is not currently joined to a domain");
		return 1;
	}
	
	# Expected output:
	# Executing (\\<COMPUTERNAME>\ROOT\CIMV2:Win32_ComputerSystem.Name="<COMPUTERNAME>")->UnJoinDomainOrWorkgroup()
	# Method execution successful.s
	# Out Parameters:
	# instance of __PARAMETERS
	# {
	#       ReturnValue = 0;
	# };
	
	# Assemble the unjoin command
	my $unjoin_command = "echo | cmd.exe /c \"$system32_path/Wbem/wmic.exe /INTERACTIVE:OFF COMPUTERSYSTEM WHERE Name=\\\"%COMPUTERNAME%\\\" Call UnJoinDomainOrWorkgroup FUnjoinOptions=0\"";
	notify($ERRORS{'DEBUG'}, 0, "attempting to unjoin $computer_name from $computer_current_domain Active Directory domain");
	my ($unjoin_exit_status, $unjoin_output) = $self->execute($unjoin_command);
	if (!defined($unjoin_output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to execute command to unjoin the $computer_current_domain Active Directory domain");
		return;
	}
	elsif (grep(/ERROR/i, @$unjoin_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unjoin $computer_current_domain Active Directory domain, output:\n" . join("\n", @$unjoin_output));
		return;
	}
	elsif (grep(/ReturnValue\s+=\s+[1-9]/i, @$unjoin_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unjoin $computer_current_domain Active Directory domain, return value is not 0, output:\n" . join("\n", @$unjoin_output));
		return;
	}
	elsif (grep(/Method execution successful/i, @$unjoin_output)) {
		notify($ERRORS{'OK'}, 0, "unjoined $computer_current_domain Active Directory domain, output:\n" . join("\n", @$unjoin_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output unjoining $computer_current_domain Active Directory domain, output:\n" . join("\n", @$unjoin_output));
	}
	
	
	# Assemble the join workgroup command
	my $join_workgroup_command = "echo | cmd.exe /c \"$system32_path/Wbem/wmic.exe /INTERACTIVE:OFF COMPUTERSYSTEM WHERE Name=\\\"%COMPUTERNAME%\\\" Call JoinDomainOrWorkgroup name=VCL\"";
	my ($join_workgroup_exit_status, $join_workgroup_output) = $self->execute($join_workgroup_command);
	if (!defined($join_workgroup_output)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to execute command to join workgroup");
		return;
	}
	elsif (grep(/ERROR/i, @$join_workgroup_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to join workgroup, output:\n" . join("\n", @$join_workgroup_output));
	}
	elsif (grep(/ReturnValue\s+=\s+[1-9]/i, @$join_workgroup_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to join workgroup, return value is not 0, output:\n" . join("\n", @$join_workgroup_output));
	}
	elsif (grep(/Method execution successful/i, @$join_workgroup_output)) {
		notify($ERRORS{'OK'}, 0, "joined workgroup, output:\n" . join("\n", @$join_workgroup_output));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unexpected output joining workgroup, output:\n" . join("\n", @$join_workgroup_output));
	}

	if (!$self->reboot(300, 3, 1)) {
		notify($ERRORS{'WARNING'}, 0, "failed to unjoin $computer_name from Active Directory domain, failed to reboot computer after unjoining domain");
		return;
	}
	
	# Verify the computer no longer is joined to a domain
	my $new_computer_current_domain = $self->ad_get_current_domain();
	if ($new_computer_current_domain) {
		notify($ERRORS{'WARNING'}, 0, "failed to unjoin $computer_name from Active Directory domain, it appears to still be a member of the $new_computer_current_domain domain");
		return;
	}
	
	#if (!defined($domain_dns_name)) {
	#	notify($ERRORS{'WARNING'}, 0, "unable to remove $computer_name from AD, image $image_name is not assigned to a domain");
	#	return;
	#}
	#elsif (!defined($domain_username)) {
	#	notify($ERRORS{'WARNING'}, 0, "unable to remove $computer_name from AD, user name is not configured for $domain_dns_name domain");
	#	return;
	#}
	#elsif (!defined($domain_password)) {
	#	notify($ERRORS{'WARNING'}, 0, "unable to remove $computer_name from AD, password is not configured for $domain_dns_name domain");
	#	return;
	#}
	#	# Assemble the PowerShell script
	#	my $ad_powershell_script = <<EOF;
	#\$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(5000, 500)
	#\$ps_credential = New-Object System.Management.Automation.PsCredential("$domain_username\@$domain_dns_name", (ConvertTo-SecureString "$domain_password" -AsPlainText -Force))
	#try {
	#   Add-Computer -WorkgroupName VCL -Credential \$ps_credential -ErrorAction Stop
	#}
	#catch {
	#   Write-Host "ERROR: failed to add computer to workgroup, error: \$(\$_.Exception.Message)"
	#   exit 1
	#}
	#EOF
	#
	#	my ($exit_status, $output) = $self->run_powershell_as_script($ad_powershell_script, 0, 0);
	#	if (!defined($output)) {
	#		notify($ERRORS{'WARNING'}, 0, "failed to execute PowerShell script to remove $computer_name from Active Directory domain");
	#		return;
	#	}
	#	elsif (grep(/ERROR/, @$output)) {
	#		# Computer object was already or deleted or can't be found for some reason:
	#		#   This command cannot be executed on target computer('') due to following error: No mapping between account names and security IDs was done.
	#		if (grep(/No mapping between account names/, @$output)) {
	#			notify($ERRORS{'WARNING'}, 0, "failed to remove $computer_name from Active Directory domain, the computer object may have been deleted from the domain, output:\n" . join("\n", @$output));
	#		}
	#		else {
	#			notify($ERRORS{'WARNING'}, 0, "failed to remove $computer_name from Active Directory domain, output:\n" . join("\n", @$output));
	#		}
	#		return 0;
	#	}
	#	
	#	notify($ERRORS{'OK'}, 0, "removed $computer_name from Active Directory domain, output:\n" . join("\n", @$output));
	
	$self->ad_delete_computer($computer_name, $computer_current_domain);
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_get_current_domain

 Parameters  : none
 Returns     : boolean
 Description : Checks if the computer is joined to any Active Directory domain.
               Returns the following:
               * undefined - Error occurred, unable to determine if computer is
                 joined to a domain.
               * 0 - Computer is not joined to a domain.
               * string - Computer is joined to a domain. The domain name is
                 returned.
               * 1 - Computer is joined to a domain but the domain name could
                 not be determined.

=cut

sub ad_get_current_domain {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name	= $self->data->get_computer_short_name();
	my $system32_path = $self->get_system32_path() || return;
	
	my $command = "echo | $system32_path/Wbem/wmic.exe COMPUTERSYSTEM GET PartOfDomain,Domain /FORMAT:LIST";
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if $computer_name is joined to a domain: $command");
		return;
	}
	
	my ($part_of_domain_line) = grep(/^PartOfDomain/i, @$output);
	if (!$part_of_domain_line) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if $computer_name is joined to a domain, output does not contain a 'PartOfDomain' line:\n" . join("\n", @$output));
		return;
	}
	elsif ($part_of_domain_line =~ /FALSE/i) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name is NOT joined to a domain, output:\n" . join("\n", @$output));
		return 0;
	}
	
	my ($domain_line) = grep(/^Domain/i, @$output);
	my ($domain_name) = $domain_line =~ /Domain=(.+)/;
	if ($domain_name) {
		notify($ERRORS{'DEBUG'}, 0, "$computer_name is joined to a domain, returning '$domain_name'\n" . join("\n", @$output));
		return $domain_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$computer_name is joined to a domain but 'Domain=' line could not be parsed from the output, returning 1:\n" . join("\n", @$output));
		return 1;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_search

 Parameters  : $ldap_filter_argument, $attempt_limit (optional)
 Returns     : array
 Description : Searches for a contain or object in Active Directory based on the
               argument hash reference. The keys of the argument represent LDAP
               attributes.
					
					By default, up to 3 attempts will be made if the search fails.
					This is mainly done to overcome an issue during the reserve()
					sequence if static IP addresses are used. After the static IP is
					set on the AD-joined computer, there is a brief delay before DNS
					resolution works properly. As a result, the first AD search often
					fails.

=cut

sub ad_search {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $arguments = shift;
	
	my $computer_name	= $self->data->get_computer_short_name();
	
	my $ldap_filter_argument = $arguments->{ldap_filter};
	if (!defined($ldap_filter_argument)) {
		notify($ERRORS{'WARNING'}, 0, "LDAP filter hash reference argument was not supplied");
		return;
	}
	elsif (!ref($ldap_filter_argument) || ref($ldap_filter_argument) ne 'HASH') {
		notify($ERRORS{'WARNING'}, 0, "LDAP filter argument is not a hash reference:\n" . format_data($ldap_filter_argument));
		return;
	}
	elsif (!scalar(keys %$ldap_filter_argument)) {
		notify($ERRORS{'WARNING'}, 0, "empty LDAP FILTER hash reference argument was supplied");
		return;
	}
	elsif (!defined($ldap_filter_argument->{objectClass})) {
		# Make sure objectClass was specified
		notify($ERRORS{'WARNING'}, 0, "LDAP FILTER hash reference argument does not contain an objectClass value:\n" . format_data($ldap_filter_argument));
		return;
	}
	elsif ($ldap_filter_argument->{objectClass} !~ /^(computer|organizationalUnit|user)$/) {
		notify($ERRORS{'WARNING'}, 0, "LDAP FILTER objectClass value not allowed: " . $ldap_filter_argument->{objectClass});
		return;
	}
	
	my $domain_dns_name;
	my $domain_username;
	my $domain_password;
	my $image_domain_dns_name = $self->data->get_image_domain_dns_name(0) || '';
	if (defined($arguments->{domain_dns_name}) && $arguments->{domain_dns_name} ne $image_domain_dns_name) {
		$domain_dns_name = $arguments->{domain_dns_name};
		($domain_username, $domain_password) = $self->data->get_domain_credentials($domain_dns_name);
		if (!defined($domain_username) || !defined($domain_password)) {
			notify($ERRORS{'WARNING'}, 0, "unable to search domain: $domain_dns_name, domain DNS name argument was specified but credentials could not be determined from existing 'addomain' table entries");
			return;
		}
	}
	else {
		$domain_dns_name = $self->data->get_image_domain_dns_name();
		$domain_username = $self->data->get_image_domain_username();
		$domain_password = $self->data->get_image_domain_password();
	}
	if (!defined($domain_dns_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if AD object exists on $computer_name, domain DNS name is not configured for the image and was not passed as an argument");
		return;
	}
	elsif (!defined($domain_username)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if AD object exists on $computer_name, user name is not configured for $domain_dns_name domain");
		return;
	}
	elsif (!defined($domain_password)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if AD object exists on $computer_name, password is not configured for $domain_dns_name domain");
		return;
	}
	
	my $attempt_limit = $arguments->{attempt_limit} || 3;
	
	# This sub handles both search and delete under very strict conditions
	# This is somewhat ugly but was done to reduce code duplication - especially with the Powershell below
	my $operation;
	my $calling_subroutine = get_calling_subroutine();
	if ($calling_subroutine =~ /(ad_delete_computer)/) {
		$operation = 'delete';
	}
	else {
		$operation = 'search for';
	}
	
	my $search_attribute_count = scalar(keys %$ldap_filter_argument);
	
	my $ldap_filter;
	$ldap_filter .= '(&' if ($search_attribute_count > 1);
	for my $attribute (keys %$ldap_filter_argument) {
		my $value = $ldap_filter_argument->{$attribute};
		$ldap_filter .= "($attribute=$value)";
	}
	$ldap_filter .= ')' if ($search_attribute_count > 1);
	notify($ERRORS{'DEBUG'}, 0, "assembled LDAP filter: '$ldap_filter'");
	
	my $domain_user_string = "$domain_username\@$domain_dns_name";
	
	# Escape single quotes by doubling them
	(my $domain_password_escaped = $domain_password) =~ s/(['])/$1$1/g;
	
	my $delete = ($operation eq 'delete' ? 1 : 0);
	
	# Assemble the PowerShell script
	my $powershell_script_contents = <<EOF;
\$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(5000, 500)
Clear-Host

\$domain_dns_name = '$domain_dns_name'
\$domain_username = '$domain_user_string'
\$domain_password = '$domain_password_escaped'
\$ldap_filter = '$ldap_filter'
\$delete = '$delete'

Write-Host "domain: $domain_dns_name"
Write-Host "domain username (between >*<): >\$domain_username<"
Write-Host "domain password (between >*<): >\$domain_password<"

EOF

	$powershell_script_contents .= <<'EOF';
$type = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]"Domain"
$directory_context = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext($type, $domain_dns_name, $domain_username, $domain_password)
try {
   $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($directory_context)
}
catch {
   if ($_.Exception.InnerException) {
      $exception_message = $_.Exception.InnerException.Message
   }
   else {
      $exception_message = $_.Exception.Message
   }
   Write-Host "ERROR: failed to connect to $domain_dns_name domain, username: $domain_username, password: $domain_password, error: $exception_message"
   exit
}

$searcher = New-Object System.DirectoryServices.DirectorySearcher($domain.GetDirectoryEntry())
$searcher.filter = "$ldap_filter"
try {
   $results = $searcher.FindAll()
   # Try to output the results to catch this exception:
   # An error occurred while enumerating through a collection: The <...> search filter is invalid.
   $results | Out-Null
}
catch {
   Write-Host "ERROR: failed to search for entries matching LDAP filter: --> '$ldap_filter', error: $($_.Exception.Message)"
   exit 1
}


if ($delete -eq 1) {
Write-Host "delete true : $delete"
   if ($results.Count -eq 0) {
      Write-Host "no entries found to delete matching LDAP filter: '$ldap_filter'"
      exit 0
   }
   elseif ($results.Count -gt 1) {
      Write-Host "ERROR: delete not performed for safety, multiple entries found to delete matching LDAP filter: '$ldap_filter'`n$($results | Select -ExpandProperty Path | Out-String)"
      exit 1
   }
}

ForEach($result in $results) {
   $entry = $result.GetDirectoryEntry();
   $dn = $entry.distinguishedName
   if ($delete -eq 1) {
      Write-Host "attempting to delete entry: $dn"
      try {
         $entry.DeleteTree();
         Write-Host "deleted entry: $dn"
      }
      catch {
         Write-Host "ERROR: failed to delete entry: $dn, error: $($_.Exception.Message)"
         exit 1
      }
   }
   else {
      Write-Host $dn
   }
}
EOF

	my ($exit_status, $output);
	for (my $attempt=1; $attempt<=$attempt_limit; $attempt++) {
		($exit_status, $output) = $self->run_powershell_as_script($powershell_script_contents, 0, 0);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute PowerShell script on $computer_name to $operation objects in $domain_dns_name AD domain matching LDAP filter: '$ldap_filter'");
			return;
		}
		elsif (grep(/(WARNING:|ERROR:|exception)/i, @$output)) {
			# Only display a warning on the last attempt
			# Known issue, see comment in sub header
			my $notify_type = ($attempt < $attempt_limit ? $ERRORS{'DEBUG'} : $ERRORS{'WARNING'});
			notify($notify_type, 0, "attempt $attempt/$attempt_limit: failed to $operation objects on $computer_name in $domain_dns_name AD domain matching LDAP filter: '$ldap_filter', error occurred:\n" . join("\n", @$output));
		}
		else {
			last;
		}
		return if $attempt == $attempt_limit;
	}
	
	if ($operation eq 'delete') {
		notify($ERRORS{'OK'}, 0, "deleted objects on $computer_name in $domain_dns_name AD domain matching LDAP filter: '$ldap_filter', output:\n" . join("\n", @$output));
		return 1;
	}
	
	my @matching_dns;
	for my $line (@$output) {
		next if ($line !~ /\w/);
		
		# Remove leading and trailing spaces
		$line =~ s/(^\s+|\s+$)//g;
		if ($line =~ /^[A-Z]{2}=.+/i) {
			push @matching_dns, $line;
		}
		elsif ($line !~ /^domain.*:/) {
			notify($ERRORS{'WARNING'}, 0, "unexpected output found $operation objects on $computer_name in $domain_dns_name AD domain matching LDAP filter: '$ldap_filter':\n$line");
		}
	}
	
	my $matching_count = scalar(@matching_dns);
	if ($matching_count) {
		notify($ERRORS{'OK'}, 0, "found $matching_count object" . ($matching_count > 1 ? 's' : '') . " matching LDAP filter in $domain_dns_name AD domain on $computer_name: '$ldap_filter'\n" . join("\n", sort @matching_dns));
	}
	else {
		notify($ERRORS{'OK'}, 0, "object NOT found matching LDAP filter in $domain_dns_name AD domain on $computer_name: '$ldap_filter'");
	}
	return @matching_dns;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_delete_computer

 Parameters  : $computer_samaccountname (optional), $domain_dns_name (optional)
 Returns     : boolean
 Description : Deletes a computer object from the active directory domain with a
               sAMAccountName attribute matching the argument. If no argument is
               provided, the short name of the reservation computer is used.
               
               The sAMAccountName attribute for computers in Active Directory
               always end with a dollar sign. The trailing dollar sign does not
               need to be included in the argumenat. One will be added to the
               LDAP filter used to search for the object to delete.

=cut

sub ad_delete_computer {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($computer_samaccountname, $domain_dns_name) = @_;
	
	$computer_samaccountname = $self->data->get_computer_short_name() unless $computer_samaccountname;
	
	# Make sure computer samAccountName does not contain a trailing dollar sign
	# A dollar sign will be present if retrieved directly from AD
	$computer_samaccountname =~ s/\$*$/\$/g;
	
	my $ad_search_arguments = {
		'ldap_filter' => {
			'objectClass' => 'computer',
			'sAMAccountName' => $computer_samaccountname,
		}
	};
	
	# If a specific domain was specified, retrieve the username and password for that domain
	if ($domain_dns_name) {
		$ad_search_arguments->{domain_dns_name} = $domain_dns_name;
	}
	
	return $self->ad_search($ad_search_arguments);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_search_computer

 Parameters  : $computer_samaccountname (optional), $domain_dns_name (optional)
 Returns     : string
 Description : Checks if a computer exists in the Active Directory domain with a
               sAMAccountName attribute matching the argument. If found, a
               string containing the computer DN is returned.

=cut

sub ad_search_computer {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($computer_samaccountname, $domain_dns_name, $ad_search_arguments) = @_;
	
	$computer_samaccountname = $self->data->get_computer_short_name() unless $computer_samaccountname;
	
	# Make sure computer samAccountName does not contain a trailing dollar sign
	# A dollar sign will be present if retrieved directly from AD
	$computer_samaccountname =~ s/\$*$/\$/g;
	
	$ad_search_arguments->{ldap_filter}{objectClass} = 'computer';
	$ad_search_arguments->{ldap_filter}{sAMAccountName} = $computer_samaccountname;
	
	# If a specific domain was specified, retrieve the username and password for that domain
	if ($domain_dns_name) {
		$ad_search_arguments->{domain_dns_name} = $domain_dns_name;
	}
	
	my @computer_dns = $self->ad_search($ad_search_arguments);
	if (@computer_dns) {
		return $computer_dns[0];
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_search_ou

 Parameters  : $ou_identifier
 Returns     : array
 Description : Checks if an OU exists in the Active Directory domain with a
               matching the identifier argument. The identifier may either be
               the short name of an OU:
               'Test VMs'
               Or the full distinguished name:
               OU=Test VMs,OU=VCL,DC=ad,DC=example,DC=edu'
               
               An array of matching DNs is returned.

=cut

sub ad_search_ou {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $ou_identifier = shift;
	if (!defined($ou_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "OU identifier argument was not supplied");
		return;
	}
	
	# Check if a DN or single name was provided
	my $attribute_name;
	if ($ou_identifier =~ /^OU=/i) {
		$attribute_name = 'distinguishedName';
	}
	else {
		$attribute_name = 'ou';
	}
	
	return $self->ad_search(
		{
			'ldap_filter' => {
				'objectClass' => 'organizationalUnit',
				$attribute_name => $ou_identifier,
			}
		}
	);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 ad_user_exists

 Parameters  : $user_samaccountname
 Returns     : boolean
 Description : Checks if a user exists in the Active Directory domain with a
               matching sAMAccountName.

=cut

sub ad_user_exists {
	my $self = shift;	
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_samaccountname, $no_cache) = @_;
	if (!defined($user_samaccountname)) {
		notify($ERRORS{'WARNING'}, 0, "user sAMAccountName argument was not supplied");
		return;
	}
	
	my $domain_dns_name = $self->data->get_image_domain_dns_name();
	if (!defined($domain_dns_name)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine if user exists in Active Directory, domain DNS name is not configured");
		return;
	}
	
	if (!$no_cache && defined($self->{ad_user_exists}{$user_samaccountname})) {
		return $self->{ad_user_exists}{$user_samaccountname};
	}
	
	my @user_dns = $self->ad_search(
		{
			'ldap_filter' => {
				'objectClass' => 'user',
				'sAMAccountName' => $user_samaccountname,
			}
		}
	);
	
	if (@user_dns) {
		$self->{ad_user_exists}{$user_samaccountname} = 1;
		notify($ERRORS{'DEBUG'}, 0, "user exists in Active Directory domain: $user_samaccountname");
		
	}
	else {
		$self->{ad_user_exists}{$user_samaccountname} = 0;
		notify($ERRORS{'DEBUG'}, 0, "user does NOT exist in Active Directory domain: $user_samaccountname");
	}
	return $self->{ad_user_exists}{$user_samaccountname};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 grant_administrative_access

 Parameters  : $username
 Returns     : boolean
 Description : Adds the user to the local Administrators group.

=cut

sub grant_administrative_access {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $username = shift;
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not supplied");
		return;
	}
	
	return $self->add_user_to_group($username, "Administrators");
}

#//////////////////////////////////////////////////////////////////////////////

=head2 revoke_administrative_access

 Parameters  : $username
 Returns     : boolean
 Description : Removes the user to the local Administrators group.

=cut

sub revoke_administrative_access {
	my $self = shift;
	if (ref($self) !~ /Windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $username = shift;
	if (!defined($username)) {
		notify($ERRORS{'WARNING'}, 0, "username argument was not supplied");
		return;
	}
	
	return $self->remove_user_from_group($username, 'Administrators');
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _escape_password

 Parameters  : $password
 Returns     : string
 Description : Adds a backslash before all of the following characters in a
               password:
                  * " (double quote)
                  * $ (dollar sign)
                  * \ (backslash)
                  * ` (backtick)

=cut

sub _escape_password {
	my $password_argument = shift;
	my $password_escaped = $password_argument;
	$password_escaped =~ s/(["\$\\`])/\\$1/gx;
	
	#notify($ERRORS{'DEBUG'}, 0, "escaped password:\n" .
	#	"original : '$password_argument'\n" .
	#	"escaped  : '$password_escaped'"
	#);
	return $password_escaped;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
