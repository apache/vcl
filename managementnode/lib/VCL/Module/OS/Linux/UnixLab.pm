#!/usr/bin/perl -w
###############################################################################
# $Id: Linux.pm 795834 2009-07-20 13:37:52Z arkurth $
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

VCL::Module::OS::Linux.pm - VCL module to support Linux operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Linux operating systems.

=cut

##############################################################################
package VCL::Module::OS::Linux::UnixLab;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.4.2';

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

=head2 revoke_access

 Parameters  :
 Returns     :
 Description :

=cut

sub revoke_access {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $computer_public_ip_address = $self->data->get_computer_public_ip_address;
	my $computer_node_name         = $self->data->get_computer_node_name();
	my $user_login_id              = $self->data->get_user_login_id();
	my $identity                   = $self->data->get_image_identity();

	if (!$user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user could not be determined");
		return 0;
	}

	if (!$computer_node_name) {
		notify($ERRORS{'WARNING'}, 0, "computer node name could not be determined");
		return 0;
	}

	if (!$identity) {
		notify($ERRORS{'WARNING'}, 0, "image identity keys could not be determined");
		return 0;
	}

	# Filler for clientdata file
	my $remoteIP = "127.0.0.1";
	my $state    = "timeout";

	my @lines;
	my $l;
	# create clientdata file
	my $clientdata = "/tmp/clientdata.$computer_public_ip_address";
	if (open(CLIENTDATA, ">$clientdata")) {
		print CLIENTDATA "$state\n";
		print CLIENTDATA "$user_login_id\n";
		print CLIENTDATA "$remoteIP\n";
		close CLIENTDATA;

		# scp to hostname
		my $target = "vclstaff\@$computer_public_ip_address:/home/vclstaff/clientdata";
		if (run_scp_command($clientdata, $target, $identity, "24")) {
			notify($ERRORS{'OK'}, 0, "Success copied $clientdata to $target");
			unlink($clientdata);
			
			# send flag to activate changes
			my @sshcmd = run_ssh_command($computer_public_ip_address, $identity, "echo 1 > /home/vclstaff/flag", "vclstaff", "24");
			notify($ERRORS{'OK'}, 0, "setting flag to 1 on $computer_public_ip_address");
			
			my $nmapchecks = 0;
			# return nmap check
			
			NMAPPORT:
			if (!(nmap_port($computer_public_ip_address, 22))) {
				return 1;
			}
			else {
				if ($nmapchecks < 5) {
					$nmapchecks++;
					sleep 1;
					notify($ERRORS{'OK'}, 0, "port 22 not closed yet calling NMAPPORT code block");
					goto NMAPPORT;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "port 22 never closed on client $computer_public_ip_address");
					return 0;
				}
			} ## end else [ if (!(nmap_port($computer_public_ip_address, 22)))
		} ## end if (run_scp_command($clientdata, $target, ...
		else {
			notify($ERRORS{'OK'}, 0, "could not copy src=$clientdata to target=$target");
			return 0;
		}
	} ## end if (open(CLIENTDATA, ">$clientdata"))
	else {
		notify($ERRORS{'WARNING'}, 0, "could not open /tmp/clientdata.$computer_public_ip_address $! ");
		return 0;
	}

	return 1;
} ## end sub revoke_access

#/////////////////////////////////////////////////////////////////////////////

=head2 reserve

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description : adds user 

=cut

sub reserve {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 grant_access

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description :  adds username to external_sshd_config and and starts sshd with custom config

=cut

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $user                       = $self->data->get_user_login_id();
	my $computer_node_name         = $self->data->get_computer_node_name();
	my $computer_public_ip_address = $self->data->get_computer_public_ip_address;
	my $identity                   = $self->data->get_image_identity;
	my $remoteIP                   = $self->data->get_reservation_remote_ip();
	my $state                      = "new";


	notify($ERRORS{'OK'}, 0, "In grant_access routine $user,$computer_node_name");

	my ($package, $filename, $line, $sub) = caller(0);

	# create clientdata file
	my $clientdata = "/tmp/clientdata.$computer_public_ip_address";
	if (open(CLIENTDATA, ">$clientdata")) {
		print CLIENTDATA "$state\n";
		print CLIENTDATA "$user\n";
		print CLIENTDATA "$remoteIP\n";
		close CLIENTDATA;
		
		# scp to hostname
		my $target = "vclstaff\@$computer_public_ip_address:/home/vclstaff/clientdata";
		if (run_scp_command($clientdata, $target, $identity, "24")) {
			notify($ERRORS{'OK'}, 0, "Success copied $clientdata to $target");
			unlink($clientdata);
			
			# send flag to activate changes
			my @sshcmd = run_ssh_command($computer_public_ip_address, $identity, "echo 1 > /home/vclstaff/flag", "vclstaff", "24");
			notify($ERRORS{'OK'}, 0, "setting flag to 1 on $computer_public_ip_address");
			
			my $nmapchecks = 0;
			
			NMAPPORT:
			if (nmap_port($computer_public_ip_address, 22)) {
				notify($ERRORS{'OK'}, 0, "sshd opened");
				return 1;
			}
			else {
				if ($nmapchecks < 6) {
					$nmapchecks++;
					sleep 1;
					#notify($ERRORS{'OK'},0,"calling NMAPPORT code block");
					goto NMAPPORT;
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "port 22 never opened on client $computer_public_ip_address");
					return 0;
				}
			} ## end else [ if (nmap_port($computer_public_ip_address, 22))
		} ## end if (run_scp_command($clientdata, $target, ...
		else {
			notify($ERRORS{'WARNING'}, 0, "could not copy src=$clientdata to target= $target");
			return 0;
		}
	} ## end if (open(CLIENTDATA, ">$clientdata"))
	else {
		notify($ERRORS{'WARNING'}, 0, "could not open /tmp/clientdata.$computer_public_ip_address $! ");
		return 0;
	}

	return 1;
} ## end sub grant_access

#/////////////////////////////////////////////////////////////////////////////

=head2 post_reserve

 Parameters  : 
 Returns     : 0,1
 Description : currently empty to prevent Linux.pm form trying to login 
		different user

=cut
sub post_reserve {
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 sanitize

 Parameters  :
 Returns     :
 Description :

=cut

sub sanitize {
	my $self = shift;
	if (ref($self) !~ /unixlab/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Delete all user associated with the reservation
	if ($self->revoke_access()) {
		notify($ERRORS{'OK'}, 0, "access has been disabled for $computer_node_name");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete users from $computer_node_name");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "$computer_node_name has been sanitized");
	return 1;
} ## end sub sanitize

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_name

 Parameters  : None
 Returns     : If successful: string
               If failed: 0
 Description : Returns the name of the reservation image. This is used in
               reclaim.pm to determine if a computer needs to be reloaded or
					sanitized. Lab machines should always be sanitized.

=cut

sub get_current_image_name {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $image_name = $self->data->get_image_name();
	if ($image_name) {
		notify($ERRORS{'DEBUG'}, 0, "returning reservation image name: $image_name");
		return $image_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve reservation image name");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 check_connection_on_port

 Parameters  : $port
 Returns     : (connected|conn_wrong_ip|timeout|failed)
 Description : uses netstat to see if any thing is connected to the provided port
 
=cut

sub check_connection_on_port {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $management_node_keys        = $self->data->get_management_node_keys();
	my $computer_node_name          = $self->data->get_computer_node_name();
	my $remote_ip                   = $self->data->get_reservation_remote_ip();
	my $computer_public_ip_address  = $self->data->get_computer_public_ip_address();
	my $request_state_name          = $self->data->get_request_state_name();
	
	my $port = shift;
	if (!$port) {
		notify($ERRORS{'WARNING'}, 0, "port variable was not passed as an argument");
		return "failed";
	}
	
	my $ret_val = "no";
	my $command = "netstat -an";
	my ($status, $output) = run_ssh_command($computer_node_name, $management_node_keys, $command, 'vclstaff', 24, 1);
	notify($ERRORS{'DEBUG'}, 0, "checking connections on node $computer_node_name on port $port");
	foreach my $line (@{$output}) {
		if ($line =~ /Connection refused|Permission denied/) {
			chomp($line);
			notify($ERRORS{'WARNING'}, 0, "$line");
			if ($request_state_name =~ /reserved/) {
				$ret_val = "failed";
			}
			else {
				$ret_val = "timeout";
			}
			return $ret_val;
		} ## end if ($line =~ /Connection refused|Permission denied/)
		if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s($computer_public_ip_address:$port)\s+([.0-9]*):([0-9]*)(.*)(ESTABLISHED)/) {
			if ($4 eq $remote_ip) {
				$ret_val = "connected";
				return $ret_val;
			}
			else {
				#this isn't the remoteIP
				$ret_val = "conn_wrong_ip";
				return $ret_val;
			}
		}    # Linux
		if ($line =~ /tcp\s+([0-9]*)\s+([0-9]*)\s::ffff:($computer_public_ip_address:$port)\s+::ffff:([.0-9]*):([0-9]*)(.*)(ESTABLISHED) /) {
			if ($4 eq $remote_ip) {
				$ret_val = "connected";
				return $ret_val;
			}
			else {
				#this isn't the remoteIP
				$ret_val = "conn_wrong_ip";
				return $ret_val;
			}
		} ##
		if ($line =~ /\s*($computer_public_ip_address\.$port)\s+([.0-9]*)\.([0-9]*)(.*)(ESTABLISHED)/) {
			if ($4 eq $remote_ip) {
				$ret_val = "connected";
				return $ret_val;                       
			}
			else {
				#this isn't the remoteIP
				$ret_val = "conn_wrong_ip";
				return $ret_val;
			}
		} ##	
	}
	return $ret_val;
}
#/////////////////////////////////////////////////////////////////////////////

=head2 is_ssh_responding

 Parameters  : $computer_name (optional), $max_attempts (optional)
 Returns     : If computer responds to SSH: 1
               If computer never responds to SSH: 0
               Description : Checks if the computer is responding to SSH. Ports 22 and 24 are
               first checked to see if either is open. If neither is open, 0 is
               returned. If either of the ports is open a test SSH command which
              simply echo's a string is attempted. The default is to only
               attempt to run this command once. This can be changed by
               supplying the $max_attempts argument. If the $max_attempts is
               supplied but set to 0, only the port checks are done.

=cut

sub is_ssh_responding {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_node_name;
	my $max_attempts = 1;
	
	my $argument_1 = shift;
	my $argument_2 = shift;
	
	if ($argument_1) {
		# Check if the argument is an integer
		if ($argument_1 =~ /^\d+$/) {
			$max_attempts = $argument_1;
		}
		else {
			$computer_node_name = $argument_1;
			if ($argument_2 && $argument_2 =~ /^\d+$/) {
				$max_attempts = $argument_2;
			}
		}
	}

	if (!$computer_node_name) {
		$computer_node_name = $self->data->get_computer_node_name();
	}

	# Try nmap to see if any of the ssh ports are open before attempting to run a test command
	my $port_22_status = nmap_port($computer_node_name, 22) ? "open" : "closed";
	my $port_24_status = nmap_port($computer_node_name, 24) ? "open" : "closed";
	if ($port_22_status ne 'open' && $port_24_status ne 'open') {
		notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, ports 22 or 24 are both closed");
		return 0;
	}

	if ($max_attempts) {
		my ($exit_status, $output) = run_ssh_command({
			node => $computer_node_name,
			command => "echo \"testing ssh on $computer_node_name\"",
			max_attempts => $max_attempts,
			output_level => 0,
			timeout_seconds => 30,
			port => 24,
			user => "vclstaff",
		});

		# The exit status will be 0 if the command succeeded
		if (defined($output) && grep(/testing/, @$output)) {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is responding to SSH, port 22: $port_22_status, port 24: $port_24_status");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "$computer_node_name is NOT responding to SSH, SSH command failed, port 22: $port_22_status, port 24: $port_24_status");
			return 0;
		}
	}
	else {
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 firewall_compare_update

 Parameters  : $computer_name (optional), $max_attempts (optional)
 Returns     : returns true.
               Since the vclstaff user doesn't have root on the lab machines, there is not much this routine can do.

=cut 

sub firewall_compare_update {
	return 1;
}


#/////////////////////////////////////////////////////////////////////////////

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
	
	my $username = shift;
	if (!$username) {
		$username = $self->data->get_user_login_id();
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	my $cmd = "echo \"$message\" \| write $username";
	my ($exit_status, $output) = $self->execute({
		node => $computer_node_name,
		command => $cmd,
		display_output => 0,
		timeout => 30,
		max_attempts => 2,
		port => 24,
		user => "vclstaff",
	});
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to determine if the '$cmd' shell command exists on $computer_node_name");
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "executed command to determine if the '$cmd' shell command exists on $computer_node_name");
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_current_image_info

 Parameters  : optional 
					id,computer_hostname,computer_id,current_image_name,imagerevision_datecreated,imagerevision_id,prettyname,vcld_post_load 
 Returns     : If successful: 
					if no parameter return the imagerevision_id
					return the value of parameter input
               If failed: false
 Description : Collects currentimage hash on a computer and returns a
               value containing of the input paramter or the imagerevision_id if no inputs.
					This also updates the DataStructure.pm so data matches what is currently loaded.
=cut

sub get_current_image_info {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $input = shift;
	
	if (!defined $input) {
		$input = "imagerevision_id";
	}
	
	my $computer_node_name = $self->data->get_computer_node_name();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	
	#The Lab machine image does have a currentimage.txt file.
	#Predefine matching variables so it doesn't fail.
	
	my %current_image_txt_contents;
	$current_image_txt_contents{"imagerevision_id"} = $imagerevision_id;
	my $time = localtime;
	$current_image_txt_contents{"vcld_post_load"} = "vcld_post_load=success ($time)";
	
	# Make sure an empty hash wasn't returned
	if (defined $current_image_txt_contents{imagerevision_id}) {
		notify($ERRORS{'DEBUG'}, 0, "user selected content of image currently loaded on $computer_node_name: $current_image_txt_contents{current_image_name}");
	
		if (my $imagerevision_info = get_imagerevision_info($current_image_txt_contents{imagerevision_id})) {
			$self->data->set_computer_currentimage_data($imagerevision_info->{image});
			$self->data->set_computer_currentimagerevision_data($imagerevision_info);
			
			if (defined $current_image_txt_contents{"vcld_post_load"}) {
				$self->data->set_computer_currentimage_vcld_post_load($current_image_txt_contents{vcld_post_load});
			}
		}
		
		if (defined($current_image_txt_contents{$input})) {
			return $current_image_txt_contents{$input};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "$input was not defined in current_image_txt");	
			return;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "empty hash was returned when currentimage.txt contents were retrieved from $computer_node_name");
		return;
	}
}
#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
