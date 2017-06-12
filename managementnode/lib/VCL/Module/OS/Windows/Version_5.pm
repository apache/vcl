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

VCL::Module::OS::Windows::Version_5.pm - VCL module to support Windows 5.x operating systems

=head1 DESCRIPTION

 This module provides VCL support for Windows version 5.x operating systems.
 Version 5.x Windows OS's include Windows XP and Windows Server 2003.

=cut

###############################################################################
package VCL::Module::OS::Windows::Version_5;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use File::Basename;

use IO::File;
use POSIX qw(tmpnam);

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
               directory under the 'tools' directory specific to this OS.

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_Version_5";

###############################################################################

=head1 INTERFACE OBJECT METHODS

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
	
	notify($ERRORS{'OK'}, 0, "beginning Windows version 5 image capture preparation tasks");

	# Check if Sysprep should be used
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

=head2 post_load

 Parameters  : none
 Returns     : boolean
 Description : Performs steps after an image is loaded which are specific to
               Windows version 5.x.

=over 3

=cut

sub post_load {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module object method");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "beginning Windows version 5.x post-load tasks");

=item * Call Windows.pm::post_load()

=cut

	return $self->SUPER::post_load();

=back

=cut

}

###############################################################################

=head1 AUXILIARY OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 run_sysprep

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Prepares and runs Sysprep on a Windows XP or Server 2003
               computer:
               -generates sysprep.inf file
               -copies Sysprep files to C:\Sysprep
               -cleans up old Sysprep log files
               -sets the DevicePath registry key
               -runs sysprep.exe
               -waits for computer to become unresponsive
               -shuts down computer

=cut

sub run_sysprep {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name   = $self->data->get_computer_node_name();
	my $system32_path        = $self->get_system32_path();
	
	# Specify where on the node the sysprep.inf file will reside
	my $node_configuration_directory = $self->get_node_configuration_directory();
	my $node_configuration_sysprep_directory = "$node_configuration_directory/Utilities/Sysprep";
	my $node_configuration_sysprep_inf_path = "$node_configuration_sysprep_directory/sysprep.inf";
	my $node_working_sysprep_directory = 'C:/Sysprep';
	my $node_working_sysprep_exe_path = 'C:\\Sysprep\\sysprep.exe';
	
	# Get the sysprep.inf file contents
	my $sysprep_contents = $self->get_sysprep_inf_contents();
	if (!$sysprep_contents) {
		notify($ERRORS{'WARNING'}, 0, "failed to get sysprep.inf contents");
		return;
	}
	
	# Create a tempfile on the management node to store the sysprep.inf contents
	my $tmp_sysprep_inf_path;
	my $tmp_sysprep_inf_fh;
	do {
		$tmp_sysprep_inf_path = tmpnam();
	}
	until $tmp_sysprep_inf_fh = IO::File->new($tmp_sysprep_inf_path, O_RDWR|O_CREAT|O_EXCL);
	notify($ERRORS{'DEBUG'}, 0, "created tempfile: $tmp_sysprep_inf_path");
	
	# Print the sysprep.inf contents to the tempfile
	if (print $tmp_sysprep_inf_fh $sysprep_contents) {
		notify($ERRORS{'DEBUG'}, 0, "printed sysprep.inf contents to tempfile: $tmp_sysprep_inf_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to print sysprep.inf contents to tempfile: $tmp_sysprep_inf_path");
		return;
	}
	
	# SCP the sysprep.inf tempfile to the computer
	if (!$self->copy_file_to($tmp_sysprep_inf_path, $node_configuration_sysprep_inf_path)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy $tmp_sysprep_inf_path to $computer_node_name:$node_configuration_sysprep_inf_path");
		return;
	}
	
	# Delete the sysprep.inf tempfile from the management node
	if (unlink $tmp_sysprep_inf_path) {
		notify($ERRORS{'DEBUG'}, 0, "deleted sysprep.inf tempfile: $tmp_sysprep_inf_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete sysprep.inf tempfile: $tmp_sysprep_inf_path, $!");
	}

	
	# Remove old C:\Sysprep directory if it exists
	notify($ERRORS{'DEBUG'}, 0, "attempting to remove old $node_working_sysprep_directory directory if it exists");
	if (!$self->delete_file($node_working_sysprep_directory)) {
		notify($ERRORS{'WARNING'}, 0, "unable to remove existing $node_working_sysprep_directory directory");
		return 0;
	}
	
	# Copy Sysprep files to C:\Sysprep
	my $xcopy_command = "cp -rvf \"$node_configuration_sysprep_directory\" \"$node_working_sysprep_directory\"";
	my ($xcopy_status, $xcopy_output) = $self->execute($xcopy_command);
	if (defined($xcopy_status) && $xcopy_status == 0) {
		notify($ERRORS{'OK'}, 0, "copied Sysprep files to $node_working_sysprep_directory");
	}
	elsif (defined($xcopy_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to copy Sysprep files to $node_working_sysprep_directory, exit status: $xcopy_status, output:\n@{$xcopy_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to copy Sysprep files to $node_working_sysprep_directory");
		return 0;
	}
	
	
	# Set the DevicePath registry key
	# This is used to locate device drivers
	if (!$self->set_device_path_key()) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the DevicePath registry key");
		return;
	}
	
	# Delete driver cache files
	$self->delete_files_by_pattern('$SYSTEMROOT/inf', '.*INFCACHE.*', 1);
	$self->delete_files_by_pattern('$SYSTEMROOT/inf', '.*oem[0-9]+\\..*', 1);
	
	# Delete setupapi.log - this is the main log file for troubleshooting Sysprep
	# Contains device & driver changes, major system changes, service pack installations, hotfix installations
	$self->delete_files_by_pattern('$SYSTEMROOT', '.*\/setupapi.*', 1);
	
	# Delete Windows setup log files
	$self->delete_files_by_pattern('$SYSTEMROOT', '.*\/setuperr\\..*', 1);
	$self->delete_files_by_pattern('$SYSTEMROOT', '.*\/setuplog\\..*', 1);
	$self->delete_files_by_pattern('$SYSTEMROOT', '.*\/setupact\\..*', 1);
	
	# Configure the firewall to allow the sessmgr.exe program
	# Sysprep may hang with a dialog box asking to allow this program
	if (!$self->firewall_enable_sessmgr()) {
		notify($ERRORS{'WARNING'}, 0, "unable to configure firewall to allow sessmgr.exe program, Sysprep may hang");
	}
	
	# Kill the screen saver process, it occasionally prevents reboots and shutdowns from working
	$self->kill_process('logon.scr');
	
	# Assemble the Sysprep command
	# Run Sysprep.exe, use cygstart to lauch the .exe and return immediately
	my $sysprep_command = "/bin/cygstart.exe \$SYSTEMROOT/system32/cmd.exe /c \"";
	
	# Run Sysprep.exe
	$sysprep_command .= "C:/Sysprep/sysprep.exe /quiet /reseal /mini /forceshutdown & ";
	
	# Shutdown the computer - Sysprep does not always shut the computer down automatically
	# Check if tsshutdn.exe exists on the computer
	# tsshutdn.exe is the preferred utility, shutdown.exe often fails on Windows Server 2003
	my $windows_product_name = $self->get_product_name() || '';
	if ($windows_product_name =~ /2003/ && $self->file_exists("$system32_path/tsshutdn.exe")) {
		$sysprep_command .= "$system32_path/tsshutdn.exe 0 /POWERDOWN /DELAY:0 /V";
	}
	else {
		$sysprep_command .= "$system32_path/shutdown.exe /s /t 0 /f";
	}
	
	$sysprep_command .= "\"";
	
	my ($sysprep_status, $sysprep_output) = $self->execute($sysprep_command);
	if (defined($sysprep_status) && $sysprep_status == 0) {
		notify($ERRORS{'OK'}, 0, "initiated Sysprep.exe, waiting for $computer_node_name to become unresponsive");
	}
	elsif (defined($sysprep_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to initiate Sysprep.exe, exit status: $sysprep_status, output:\n@{$sysprep_output}");
		return 0;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to initiate Sysprep.exe");
		return 0;
	}

	# Wait maximum of 10 minutes for the computer to become unresponsive
	if (!$self->wait_for_no_ping(600)) {
		# Computer never stopped responding to ping
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never became unresponsive to ping");
		return 0;
	}
	
	# Wait maximum of 10 minutes for computer to power off
	my $power_off = $self->provisioner->wait_for_power_off(600);
	if (!defined($power_off)) {
		# wait_for_power_off result will be undefined if the provisioning module doesn't implement a power_status subroutine
		notify($ERRORS{'OK'}, 0, "unable to determine power status of $computer_node_name from provisioning module, sleeping 5 minutes to allow computer time to power off");
		sleep 300;
	}
	elsif ($power_off) {
		notify($ERRORS{'OK'}, 0, "$computer_node_name powered off after running Sysprep.exe");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$computer_node_name never powered off after running sysprep.exe");
	}
	
	# Computer never powered off, check if provisioning module can forcefully power off the computer
	if (!$self->provisioner->can('power_off')) {
		notify($ERRORS{'OK'}, 0, "provisioning module does not implement a power_off subroutine");
		return 1;
	}
	elsif ($self->provisioner->power_off()) {
		notify($ERRORS{'OK'}, 0, "forcefully powered off $computer_node_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to forcefully power off $computer_node_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_sysprep_inf_contents

 Parameters  : None
 Returns     : If successful: string containing the contents of a sysprep.inf file
               If failed: false
 Description : Generates the contents of a sysprep.inf file. The product key is
               retrieved from the winProductKey table in the database. The
               SysprepMassStorage section is dynamically generated based on the
               mass storage drivers copied to the computer.

=cut

sub get_sysprep_inf_contents {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the product key
	my $product_key = $self->get_product_key();
	if (!$product_key) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine the product key");
		return;
	}
	
	# Get the image affiliation name or use ASF as the default
	my $image_affiliation_name = $self->data->get_image_affiliation_name() || "Apache Software Foundation";
	
	# Get the Windows time zone code based on the time zone configured for the management node
	my $time_zone_code = $self->get_time_zone_code();
	
	my %sysprep_inf_hash;
	
	# [Unattended] - Setup/Sysprep execution configuration
	$sysprep_inf_hash{Unattended}{DriverSigningPolicy} = 'Ignore';         # Specifies how to process unsigned drivers during unattended Setup
	$sysprep_inf_hash{Unattended}{ExtendOemPartition} = 'No';              # Specifies whether to extend the partition on which you install the Microsoft® Windows® operating system
	#$sysprep_inf_hash{Unattended}{Hibernation} = 'No';                    # Specifies whether to enable the hibernation option in the Power Options control panel
	$sysprep_inf_hash{Unattended}{InstallFilesPath} = 'C:\Sysprep\i386';   # Specifies the location of files necessary for installation during Mini-Setup
	#$sysprep_inf_hash{Unattended}{KeepPageFile} = '';                     # Specifies whether to regenerate the page file
	#$sysprep_inf_hash{Unattended}{OemPnPDriversPath} = '';                # Specifies the path to one or more folders that contain Plug and Play drivers not distributed with Drivers.cab on the Windows product CD
	$sysprep_inf_hash{Unattended}{OemPreinstall} = 'Yes';                  # Specifies whether Setup installs its files from distribution folders
	$sysprep_inf_hash{Unattended}{OemSkipEula} = 'Yes';                    # Specifies whether the end user accepts the End-User License Agreement (EULA) included with Windows
	#$sysprep_inf_hash{Unattended}{ResetSourcePath} = '';                  # Specifies whether to change the registry setting of the source path for the Setup files
	#$sysprep_inf_hash{Unattended}{TapiConfigured} = '';                   # Specifies whether to preconfigure telephony application programming interface (TAPI) settings on the installation
	$sysprep_inf_hash{Unattended}{TargetPath} = '\\Windows';               # Determines the installation folder in which you install Windows
	#$sysprep_inf_hash{Unattended}{UpdateHAL} = '';                        # Loads the multiprocessor hardware abstraction layer (HAL) on the destination computer, regardless of whether it is a uniprocessor or an multiprocessor computer
	$sysprep_inf_hash{Unattended}{UpdateInstalledDrivers} = 'Yes';         # Specifies whether to call Plug and Play after Mini-Setup, to re-enumerate all the installed drivers, and to install any updated drivers in the driver path
	#$sysprep_inf_hash{Unattended}{UpdateUPHAL} = '';                      # Identifies the processor type and loads the appropriate kernel
	
	# [GuiUnattended] - configuration for the GUI stage of Setup/Sysprep
	$sysprep_inf_hash{GuiUnattended}{AdminPassword} = '*';                 # Sets the Administrator account password
	#$sysprep_inf_hash{GuiUnattended}{AutoLogon} = '';                     # Configures the computer to log on automatically with the Administrator account on the first reboot
	#$sysprep_inf_hash{GuiUnattended}{AutoLogonCount} = '';                # Specifies the number of times that the computer automatically logs on using the specified Administrator account and password
	$sysprep_inf_hash{GuiUnattended}{EncryptedAdminPassword} = 'No';       # Enables Setup to install encrypted passwords for the Administrator account
	$sysprep_inf_hash{GuiUnattended}{OEMDuplicatorString} = 'VCL';         # Specifies a description of the duplication utility used, as well as any other information that an OEM or administrator wants to store in the registry
	$sysprep_inf_hash{GuiUnattended}{OemSkipRegional} = '1';               # Specifies whether unattended Setup skips the Regional and Language Options page in GUI-mode Setup and Mini-Setup
	$sysprep_inf_hash{GuiUnattended}{OemSkipWelcome} = '1';                # Specifies whether unattended Setup skips the Welcome page in GUI-mode Setup and Mini-Setup
	$sysprep_inf_hash{GuiUnattended}{TimeZone} = $time_zone_code;          # Specifies the time zone of the computer's location
	
	# [Display] - display/graphics settings
	$sysprep_inf_hash{Display}{BitsPerPel} = '32';                         # Specifies the valid bits per pixel for the graphics device
	$sysprep_inf_hash{Display}{Vrefresh} = '75';                           # Specifies a valid refresh rate for the graphics de
	$sysprep_inf_hash{Display}{Xresolution} = '800';                       # Specifies a valid x resolution for the graphics device
	$sysprep_inf_hash{Display}{Yresolution} = '600';                       # Specifies a valid y resolution for the graphics device
	
	# [GuiRunOnce] - commands to execute the first time an end user logs on to the computer after GUI stage completes
	# Commands called in the [GuiRunOnce] section process synchronously
	# Each application runs in the order listed in this section
	# Each command must finish before you run the next command
	#$sysprep_inf_hash{GuiRunOnce} = [];
	
	# [Identification] - computer network identification
	# If these entries are not present, Setup adds the computer to the default workgroup
	#$sysprep_inf_hash{Identification}{DomainAdmin} = '';                  # Specifies the name of the user account in the domain that has permission to create a computer account in that domain
	#$sysprep_inf_hash{Identification}{DomainAdminPassword} = '';          # Specifies the password of the user account as defined by the DomainAdmin entry
	#$sysprep_inf_hash{Identification}{JoinDomain} = '';                   # Specifies the name of the domain in which the computer participates
	$sysprep_inf_hash{Identification}{JoinWorkgroup} = 'VCL';              # Specifies the name of the workgroup in which the computer participates
	#$sysprep_inf_hash{Identification}{MachineObjectOU} = '';              # Specifies the full LDAP path name of the OU in which the computer belongs
	
	# 
	#$sysprep_inf_hash{IEHardening}{LocalIntranetSites} = '';              # Local intranet sites whose content you trust
	#$sysprep_inf_hash{IEHardening}{TrustedSites} = '';                    # Internet sites whose content you trust
	
	# [IEPopupBlocker] - IE pop-up blocker settings
	#$sysprep_inf_hash{IEPopupBlocker}{AllowedSites} = '';                 # Specifies the sites allowed by Pop-up Blocker
	#$sysprep_inf_hash{IEPopupBlocker}{BlockPopups} = '';                  # Specifies whether or not to block pop-ups
	#$sysprep_inf_hash{IEPopupBlocker}{FilterLevel} = '';                  # Specifies the level of Pop-up Blocker filtering
	#$sysprep_inf_hash{IEPopupBlocker}{ShowInformationBar} = '';           # Specifies whether or not to show the Information Bar when pop-ups are blocked
	
	# [LicenseFilePrintData] - licensing configuration for the Windows Server 2003
	$sysprep_inf_hash{LicenseFilePrintData}{AutoMode} = 'PerSeat';         # Determines per-seat or a per-server license mode
	#$sysprep_inf_hash{LicenseFilePrintData}{AutoUsers} = '';              # Indicates the number of client licenses purchased for the server
	
	# [Networking] - contains no entries
	# To use Sysprep you must include the [Networking] section name in your answer file
	$sysprep_inf_hash{Networking}{InstallDefaultComponents} = 'Yes';
	
	# [RegionalSettings] - regional/international settings
	#$sysprep_inf_hash{RegionalSettings}{InputLocale} = '';                # Specifies the input locale and keyboard layout combinations to install
	#$sysprep_inf_hash{RegionalSettings}{InputLocale_DefaultUser} = '';    # Specifies the input locale and keyboard layout combination for the default user
	#$sysprep_inf_hash{RegionalSettings}{Language} = '';                   # Specifies the language/locale to install
	#$sysprep_inf_hash{RegionalSettings}{LanguageGroup} = '';              # Specifies the language group for this installation
	#$sysprep_inf_hash{RegionalSettings}{SystemLocale} = '';               # Specifies the system locale to install
	#$sysprep_inf_hash{RegionalSettings}{UserLocale} = '';                 # Specifies the user locale to install
	#$sysprep_inf_hash{RegionalSettings}{UserLocale_DefaultUser} = '';     # Specifies the user locale for the default user
	
	# [TapiLocation] - telephony API (TAPI) settings
	# It is valid only if a modem is present on the computer
	#$sysprep_inf_hash{TapiLocation}{AreaCode} = '';                       # Specifies the area code for the computer's location
	#$sysprep_inf_hash{TapiLocation}{CountryCode} = '';                    # Specifies the country/region code to use for telephony
	#$sysprep_inf_hash{TapiLocation}{Dialing} = '';                        # Specifies the type of dialing to use for the telephony device in the computer
	#$sysprep_inf_hash{TapiLocation}{LongDistanceAccess} = '';             # Specifies the number to dial to gain access to an outside line, such as 9
	
	# [UserData] - user identification settings
	$sysprep_inf_hash{UserData}{ComputerName} = '*';                       # Specifies the computer name
	$sysprep_inf_hash{UserData}{FullName} = 'Virtual Computing Lab';       # Specifies the end user’s full name
	$sysprep_inf_hash{UserData}{OrgName} = $image_affiliation_name;        # Specifies an organization’s name
	$sysprep_inf_hash{UserData}{ProductKey} = $product_key;                # Specifies the Product Key for each unique installation of Windows
	
	# [Sysprep] section contains an entry for automatically generating the entries in the pre-existing [SysprepMassStorage] section and then installing those mass-storage controllers
	#$sysprep_inf_hash{Sysprep}{BuildMassStorageSection} = '';             # Generates the entries in the [SysprepMassStorage] section
	#
	# [SysprepMassStorage] contains an entry for identifying the different mass-storage controllers
	# Sysprep prepopulates the necessary driver information based on the entries that you provide
	# Required so that the correct drivers will be loaded when the operating system starts on a computer that uses one of the predefined mass-storage controllers
	#$sysprep_inf_hash{SysprepMassStorage} = [];
	
	my $sysprep_contents;
	$sysprep_contents .= "; sysprep.inf file automatically generated by VCL\r\n";
	$sysprep_contents .= "; " . localtime() . "\r\n";
	
	foreach my $sysprep_section (keys %sysprep_inf_hash) {
		$sysprep_contents .= "[$sysprep_section]\n";
		
		foreach my $sysprep_property (keys %{$sysprep_inf_hash{$sysprep_section}}) {
			my $sysprep_value = $sysprep_inf_hash{$sysprep_section}{$sysprep_property};
			$sysprep_contents .= "$sysprep_property=$sysprep_value\n" if $sysprep_value;
		}
		
		$sysprep_contents .= "\n";
	}
	
	# Add the SysprepMassStorage section
	my $mass_storage_section = $self->get_sysprep_inf_mass_storage_section();
	if ($mass_storage_section) {
		$sysprep_contents .= "[SysprepMassStorage]\n$mass_storage_section";
	}
	elsif (!defined($mass_storage_section)) {
		notify($ERRORS{'WARNING'}, 0, "unable to build sysprep.inf SysprepMassStorage section");
		return;
	}
	
	
	# Replace Unix\Linux newlines with Windows newlines
	$sysprep_contents =~ s/\n/\r\n/g;
	
	notify($ERRORS{'DEBUG'}, 0, "sysprep.inf contents:\n$sysprep_contents");
	return $sysprep_contents;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_sysprep_inf_mass_storage_section

 Parameters  : None
 Returns     : If successful: string containing the contents of a sysprep.inf
                              SysprepMassStorage section
               If failed: false
 Description : Generates the SysprepMassStorage section of a sysprep.inf file.
               Storage driver .inf files are first located and read. The storage
               hardware IDs are retrieved from the .inf files and the
               SysprepMassStorage section is created dynamically.

=cut

sub get_sysprep_inf_mass_storage_section {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $drivers_directory = $self->get_node_configuration_directory() . '/Drivers';
	
	# Find the paths of .inf files in the drivers directory with a Class=SCSIAdapter or HDC line
	# These are the storage driver .inf files
	my @storage_inf_paths = $self->get_driver_inf_paths('scsiadapter');
	#my @storage_inf_paths = $self->get_driver_inf_paths('(scsiadapter|hdc)');
	if (!@storage_inf_paths) {
		notify($ERRORS{'OK'}, 0, "no storage driver .inf paths were found");
		return '';
	}
	
	# Extract hardware IDs from each storage driver .inf file 
	# Looking for lines like this:
	#    %MyDev% = mydevInstall,mydevHwid
	#    %DevDescD2% = SYMMPI_Inst, PCI\VEN_1000&DEV_0054&SUBSYS_1F051028
	# Assemble the lines to be inserted in the the sysprep.inf [SysprepMassStorage] section
	# Format:
	#    mydevHwid = "<.inf path>"
	my $mass_storage_section;
	for my $storage_inf_path (@storage_inf_paths) {
		my @hwid_lines;
		my $grep_hwid_command .= '/usr/bin/grep -E ",[ ]*PCI.VEN[^\s]*" ' . $storage_inf_path;
		my ($grep_hwid_exit_status, $grep_hwid_output) = $self->execute($grep_hwid_command, 1);
		if (defined($grep_hwid_exit_status) && $grep_hwid_exit_status == 0) {
			@hwid_lines = @$grep_hwid_output;
			notify($ERRORS{'DEBUG'}, 0, "found hardware ID lines in $storage_inf_path:\n" . join("\n", @hwid_lines));
		}
		elsif ($grep_hwid_exit_status) {
			notify($ERRORS{'WARNING'}, 0, "failed to find hardware ID lines in $storage_inf_path, exit status: $grep_hwid_exit_status, output:\n@{$grep_hwid_output}");
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to find hardware ID lines in $storage_inf_path");
			return;
		}
		
		# Convert the .inf path to DOS format with backslashes
		(my $storage_inf_path_dos = $storage_inf_path) =~ s/\//\\/g;
		
		# Loop through the hardware IDs, assemble a mass storage section line for each
		for my $hwid_line (@hwid_lines) {
			# Extract the hardware ID section from the line
			$hwid_line =~ /,\s*(PCI.*)/;
			my $hwid = $1;
			
			# Remove spaces from the beginning and end of the hardware ID
			# Cygwin grep doesn't catch \r as being included in \s
			$hwid =~ s/(^\s*|\s*$)//g;
			
			# Assemble the mass storage line and add it to the section, put .inf path in quotes
			$mass_storage_section .= "$hwid = \"$storage_inf_path_dos\"\n";
		}
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "built sysprep.inf SysprepMassStorage section:\n$mass_storage_section");
	return $mass_storage_section;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_enable_sessmgr

 Parameters  : 
 Returns     : 1 if succeeded, 0 otherwise
 Description : 

=cut

sub firewall_enable_sessmgr {
	my $self = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $system32_path = $self->get_system32_path();
	
	# Configure the firewall to allow the sessmgr.exe program
	my $netsh_command = "$system32_path/netsh.exe firewall set allowedprogram name = \"Microsoft Remote Desktop Help Session Manager\" mode = ENABLE scope = ALL profile = ALL program = \"$system32_path/sessmgr.exe\"";
	my ($netsh_status, $netsh_output) = $self->execute($netsh_command);
	if (defined($netsh_status) && $netsh_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "configured firewall to allow sessmgr.exe");
	}
	elsif (defined($netsh_status)) {
		notify($ERRORS{'WARNING'}, 0, "failed to configure firewall to allow sessmgr.exe, exit status: $netsh_status, output:\n@{$netsh_output}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to run ssh command to configure firewall to allow sessmgr.exe");
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize_files

 Parameters  : none
 Returns     : boolean
 Description : Removes the Windows root password from files on the computer.

=cut

sub sanitize_files {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my @file_paths = (
		'$SYSTEMDRIVE/Sysprep',
	);
	
	# Call the subroutine in Windows.pm
	return $self->SUPER::sanitize_files(@file_paths);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 disable_sleep

 Parameters  : None
 Returns     : If successful: true
               If failed: false
 Description : Disables the sleep power mode.

=cut

sub disable_sleep {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::Module module object method");
		return;	
	}
	
	my $system32_path = $self->get_system32_path() || return;
	
	my $query_command = "$system32_path/powercfg.exe /QUERY";
	my ($query_exit_status, $query_output) = $self->execute($query_command, 1);
	if (!defined($query_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to retrieve power scheme name");
		return;
	}
	
	# Join the powercfg.exe output lines into a string then parse the line beginning with 'Name '
	join("\n", @$query_output) =~ /Name\s+(.*)/;
	my $scheme_name = $1;
	if (!$scheme_name) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve power scheme name from powercfg.exe query output:\n" . join("\n", @$query_output));
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "retrieved power scheme name: '$scheme_name'");
	
	# Run powercfg.exe to disable sleep
	my $powercfg_command;
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /monitor-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /monitor-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /disk-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /disk-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /standby-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /standby-timeout-dc 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /hibernate-timeout-ac 0 ; ";
	$powercfg_command .= "$system32_path/powercfg.exe /CHANGE \"$scheme_name\" /hibernate-timeout-dc 0";
	
	my ($powercfg_exit_status, $powercfg_output) = $self->execute($powercfg_command, 1);
	if (!defined($powercfg_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run SSH command to disable sleep");
		return;
	}
	elsif (grep(/(error|invalid|not found)/i, @$powercfg_output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to disable sleep, powercfg.exe output:\n" . join("\n", @$powercfg_output));
		return;
	}
	else {
		notify($ERRORS{'OK'}, 0, "disabled sleep");
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
	my $command = "/bin/cygstart.exe \$SYSTEMROOT/system32/cmd.exe /c \"$system32_path/rundll32.exe powrprof.dll,SetSuspendState\"";
	my $start_time = time;
	my ($exit_status, $output) = $self->execute($command);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to hibernate $computer_node_name");
		return;
	}
	elsif ($exit_status eq 0) {
		notify($ERRORS{'OK'}, 0, "executed command to hibernate $computer_node_name:\n$command" . (scalar(@$output) ? "\noutput:\n" . join("\n", @$output) : ''));
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to hibernate $computer_node_name, exit status: $exit_status, output:\n" . join("\n", @$output));
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

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
