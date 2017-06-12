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

VCL::Module::OS::Linux::ESXi.pm

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for the Linux-based VMware ESXi operating
 system.

=cut

###############################################################################
package VCL::Module::OS::Linux::ESXi;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 post_load

 Parameters  :
 Returns     :
 Description :

=cut

sub post_load {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_short_name   = $self->data->get_computer_short_name();
	
	# Wait for computer to respond to SSH
	if (!$self->wait_for_response(60, 600)) {
		notify($ERRORS{'WARNING'}, 0, "$computer_short_name never responded to SSH");
		return 0;
	}
	
	# Create the currentimage.txt file
	if (!$self->OS->create_currentimage_txt()) {
		notify($ERRORS{'WARNING'}, 0, "failed to create currentimage.txt on $computer_short_name");
		return 0;
	}
	
	return $self->SUPER::post_load();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  :
 Returns     :
 Description :

=cut

sub reserve {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return 0;
   }
   notify($ERRORS{'DEBUG'}, 0, "Enterered reserve() in the ESXi OS module");
  
   return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  :
 Returns     :
 Description : this sub called when user clicks Connect button on web GUI

=cut

sub grant_access {
   my $self = shift;
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return 0;
   }

   my $esxi_storage_mount_command;
   my @commands;

   my $computer_short_name   = $self->data->get_computer_short_name();
   my $computer_node_name = $self->data->get_computer_node_name();
   notify($ERRORS{'OK'}, 0, "$computer_short_name: processing with ESXi.pm::grant_access()");

   my $username = $self->data->get_user_login_id();
   my $reservation_password = $self->data->get_reservation_password();
   my $management_node_keys = $self->data->get_management_node_keys();

   my $vcld_config = &local_read_vcld_config("/etc/vcl/vcld.conf");
   my $esxi_storage_name_prefix = $vcld_config->{"ESXI_STORAGE_NAME_PREFIX"};
   my $esxi_storage_address = $vcld_config->{"ESXI_STORAGE_ADDRESS"};
   my $esxi_storage_volume = $vcld_config->{"ESXI_STORAGE_VOLUME"};

   $esxi_storage_mount_command = "esxcfg-nas -a $esxi_storage_name_prefix-$username -o $esxi_storage_address -s $esxi_storage_volume/$username";

   push(@commands,   "chmod +w /etc/pam.d/system-auth");
   push(@commands,   "echo s/min=8,8,8,7,6/min=8,8,8,7,6 enforce=none/g > /tmp/sed");
   push(@commands,   "sed -f /tmp/sed -i /etc/pam.d/system-auth");
   push(@commands,   "rm -f /tmp/sed");
   push(@commands,   "chmod -w /etc/pam.d/system-auth");
   push(@commands,   "useradd -M $username");
   push(@commands,   "groupadd root $username");
   push(@commands,   "echo $reservation_password \| passwd $username --stdin");
   push(@commands,   "vim-cmd vimsvc/auth/entity_permission_add vim.Folder:ha-folder-root root true Admin true");
   push(@commands,   $esxi_storage_mount_command) if ($esxi_storage_mount_command);
   push(@commands, "sleep 3");
   push(@commands, "echo /uuid.action/c > /tmp/sed");
   push(@commands, "echo \\\$ a uuid.action = \\\"keep\\\" >> /tmp/sed");
   push(@commands, "find /vmfs/volumes/$esxi_storage_name_prefix-$username/ -name *.vmx -exec sed -f /tmp/sed -i {} \\;");
   push(@commands, "rm -rf /tmp/sed");
   push(@commands,   "find /vmfs/volumes/$esxi_storage_name_prefix-$username/ -name *.vmx -exec vim-cmd solo/registervm {} \\;");

   foreach my $command (@commands) {
      my ($exit_status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, "root");
      if (!defined($output)) {
         notify($ERRORS{'WARNING'}, 0, "failed to run SSH command: $command");
      return;
      }
   }
   return 1;

}

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     :
 Description : does ESXi need to reload? Check if user ever clicked connect button, if never then don't reload

=cut

sub sanitize {
   my $self = shift;
   if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

   my $computer_short_name = $self->data->get_computer_short_name();
   my $computer_state_name = $self->data->get_computer_state_name();

   if ($computer_state_name =~ /^(inuse)$/) {
      notify($ERRORS{'OK'}, 0, "$computer_short_name : need to reload.");
      return 0;
   } else {
      notify($ERRORS{'OK'}, 0, "$computer_short_name : user never connected. No need to reload.");
      return 1;
   }
}
#//////////////////////////////////////////////////////////////////////////////
=head2 local_read_vcld_config

 Parameters  : full path to vcld.conf
 Returns     : vcld_config array with all vcld.conf values
 Description : this is local sub to read vcld.conf file

=cut

sub local_read_vcld_config {
   my ($value,$config_file,$vcld_config);
   ($config_file) = @_;
   open (CONFIG,$config_file) or die "cannot open vcld.conf file";
   while (<CONFIG>) {
      chomp;
      s/#.*//;
      s/^\s+//;
      s/\s+$//;
      next unless length;
      my ($var,$value) = split(/\s*=\s*/,$_, 2);
      $vcld_config->{$var} = $value;
   }
   return $vcld_config;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_address

 Parameters  :
 Returns     : public IP address (IP address on interface vmk1)
 Description : retrive Public IP address from ESXi server. This should be vmk1 interface

=cut

sub get_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }
   my $public_ip_address;

   my $command = "esxcfg-vmknic -l";
   my ($exit_status, $output) = $self->execute($command);
   if (!defined($output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run command to retrieve network configuration: $command");
      return;
   }
   for my $line (@$output) {
      if ($line =~ /vmk1/) {
         my @vmk1 = split(/ +/,$line);
         for my $vmk1_line (@vmk1) {
            if ($vmk1_line =~ /(\d+)(\.\d+){3}/) {
               $public_ip_address = $vmk1_line;
               last;
            }
         }
      }
   }

   return $public_ip_address;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 enable_firewall_port

 Parameters  : $protocol, $port, $scope (optional)
 Returns     : 1 if succeeded, 0 otherwise
 Description : Enables a firewall port on the computer. The protocol and port
               arguments are required. An optional scope argument may supplied.

# called by OS::process_connect_methods()

=cut

sub enable_firewall_port {

	#TODO
   my $self = shift;
   if (ref($self) !~ /osx/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_cpu_core_count

 Parameters  : none
 Returns     : integer
 Description : Retrieves the number of CPU cores the computer has by querying
               the NUMBER_OF_PROCESSORS environment variable.

# called by Provisioning::VMware:VMware.pm
#       Windows.pm only returns value from database
#       return $self->get_environment_variable_value('NUMBER_OF_PROCESSORS');

=cut

sub get_cpu_core_count {
	#TODO
   my $self = shift;
   if (ref($self) !~ /osx/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

        my $computer_node_name = $self->data->get_computer_node_name();
			return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 check_connection_on_port

 Parameters  : $port
 Returns     : (connected|conn_wrong_ip|timeout|failed)
 Description : uses netstat to see if any thing is connected to the provided port

# called by OS.pm:is_user_connected()

=cut

sub check_connection_on_port {
	#TODO
   my $self = shift;
   if (ref($self) !~ /osx/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

   my $computer_node_name = $self->data->get_computer_node_name();

   my $remote_ip                   = $self->data->get_reservation_remote_ip();
   my $computer_public_ip_address  = $self->data->get_computer_public_ip_address();

   my $port = shift;
   if (!$port) {
      notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
      return "failed";
   }
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 user_exists

 Parameters  :
 Returns     :
 Description :

=cut

sub user_exists {
	#TODO
   my $self = shift;
   if (ref($self) !~ /osx/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

        my $computer_node_name = $self->data->get_computer_node_name();
	return 1;
}
#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
