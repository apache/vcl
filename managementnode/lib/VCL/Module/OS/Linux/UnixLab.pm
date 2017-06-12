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

VCL::Module::OS::UnixLab.pm - VCL module to support Unix and Linux operating systems on lab computers

=cut

###############################################################################
package VCL::Module::OS::Linux::UnixLab;

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

=head2 initialize

 Parameters  : none
 Returns     : boolean
 Description : Sets keys in the object to override the default SSH username and
               port in order for OS.pm::execute to be able to connect to the
               computer:
               $self->{ssh_port} = 24
               $self->{ssh_user} = 'vclstaff'

=cut

sub initialize {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "initializing " . ref($self) . " module");
	$self->{ssh_port} = 24;
	$self->{ssh_user} = 'vclstaff';
	return 1;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  : none
 Returns     : boolean
 Description : Updates /home/vclstaff/clientdata on the computer to include the
               state 'new', the username, and reservation remote IP.
               
               Triggers the vclclient daemon to read the clientdata file and
               configure the computer.
               
               Waits for port 22 to become open on the computer's public IP
               address.

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $user_login_id = $self->data->get_user_login_id();
	my $reservation_remote_ip = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();
	
	notify($ERRORS{'OK'}, 0, "attempting to grant access to $user_login_id on $computer_node_name");
	
	# Create the clientdata file
	my $clientdata_file_path = "/home/vclstaff/clientdata";
	my $clientdata_contents = <<EOF;
new
$user_login_id
$reservation_remote_ip
EOF
	if (!$self->create_text_file($clientdata_file_path, $clientdata_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $user_login_id on $computer_node_name, file could not be updated: $clientdata_file_path");
		return;
	}
	
	if (!$self->_trigger_vclclient()) {
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $user_login_id on $computer_node_name, flag file could not be updated");
		return;
	}
	
	if (!$self->wait_for_port_open(22, $computer_public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $user_login_id on $computer_node_name, SSH port 22 is closed");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "granted access to $user_login_id on $computer_node_name");
	return 1;
} ## end sub grant_access

#//////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  : none
 Returns     : boolean
 Description : Updates /home/vclstaff/clientdata on the computer to include the
               state 'timeout', the username, and a dummy 127.0.0.1 address.
               
               Triggers the vclclient daemon to read the clientdata file and
               configure the computer.
               
               Waits for port 22 to become closed on the computer's public IP
               address.

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_node_name = $self->data->get_computer_node_name();
	my $user_login_id = $self->data->get_user_login_id();
	my $reservation_remote_ip = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address();
	
	notify($ERRORS{'OK'}, 0, "attempting to sanitize $computer_node_name");
	
	# Create the clientdata file
	my $clientdata_file_path = "/home/vclstaff/clientdata";
	my $clientdata_contents = <<EOF;
timeout
$user_login_id
127.0.0.1
EOF
	if (!$self->create_text_file($clientdata_file_path, $clientdata_contents)) {
		notify($ERRORS{'WARNING'}, 0, "failed to sanitize $computer_node_name, file could not be updated: $clientdata_file_path");
		return;
	}
	
	if (!$self->_trigger_vclclient()) {
		notify($ERRORS{'WARNING'}, 0, "failed to sanitize $computer_node_name, flag file could not be updated");
		return;
	}
	
	if (!$self->wait_for_port_closed(22, $computer_public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "failed to grant access to $user_login_id on $computer_node_name, SSH port 22 is still open");
		return;
	}
	
	notify($ERRORS{'OK'}, 0, "sanitized $computer_node_name");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _trigger_vclclient

 Parameters  : none
 Returns     : boolean
 Description : Sets the contents of /home/vclstaff/flag to '1'. This triggers
               the vclclient daemon on the computer to read the clientdata file
               and configure the computer appropriately.

=cut

sub _trigger_vclclient {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	my $flag_file_path = '/home/vclstaff/flag';
	my $flag_file_contents = '1';
	if ($self->create_text_file($flag_file_path, $flag_file_contents)) {
		notify($ERRORS{'OK'}, 0, "set value in $flag_file_path to $flag_file_contents on $computer_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set value in $flag_file_path to $flag_file_contents on $computer_name");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_public_ip_address

 Parameters  : none
 Returns     : boolean
 Description : Overrides the subroutine in OS.pm because that subroutine fails
               if the lab computer only has a single network interface. This
               returns the computer's public IP address stored in the database.

=cut

sub get_public_ip_address {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	return $self->data->get_computer_public_ip_address();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_current_imagerevision_id

 Parameters  : none
 Returns     : integer
 Description : Returns the reservation imagerevision ID since lab computers
               don't have a currentimage.txt file.

=cut

sub get_current_imagerevision_id {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->data->get_imagerevision_id();
}

###############################################################################

=head1 BYPASSED SUBROUTINES

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 create_reservation_info_json_file

=cut

sub create_reservation_info_json_file { return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_reservation_info_json_file

=cut

sub delete_reservation_info_json_file { return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall

 Parameters  : none
 Returns     : VCL::Module::OS::Linux::firewall object
 Description : Creates and returns a generic VCL::Module::OS::Linux::firewall
               object.

=cut

sub firewall {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	return $self->{firewall} if $self->{firewall};
	
	notify($ERRORS{'DEBUG'}, 0, "creating generic VCL::Module::OS::Linux::firewall object");
	$self->{firewall} = bless {}, 'VCL::Module::OS::Linux::firewall';
	return $self->{firewall};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 firewall_compare_update

=cut

sub firewall_compare_update {	return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

=cut

sub post_reserve { return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 process_connect_methods

=cut

sub process_connect_methods { return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 reserve

=cut

sub reserve { return 1; }

#//////////////////////////////////////////////////////////////////////////////

=head2 run_stage_scripts_on_computer

=cut

sub run_stage_scripts_on_computer { return 1; }

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
