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

VCL::Module::OS::Ubuntu.pm - VCL module to support Ubuntu operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Ubuntu operating systems.

=cut

##############################################################################
package VCL::Module::OS::Linux::Ubuntu;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Linux);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
no warnings 'redefine';

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

sub clean_iptables {
	my $self = shift;
   if (ref($self) !~ /ubuntu/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	# Check to see if this distro has iptables
   # If not return 1 so it does not fail
   if (!($self->file_exists("/sbin/iptables"))) {
      notify($ERRORS{'WARNING'}, 0, "iptables does not exist on this OS");
      return 1;
   }

   my $computer_node_name = $self->data->get_computer_node_name();
   my $reservation_id                  = $self->data->get_reservation_id();
   my $management_node_keys  = $self->data->get_management_node_keys();
	

   # Retrieve the iptables file to work on locally 
   my $tmpfile = "/tmp/" . $reservation_id . "_iptables";
   my $source_file_path = "/etc/iptables.rules";
   if (run_scp_command("$computer_node_name:\"$source_file_path\"", $tmpfile, $management_node_keys)) {
      my @lines;
      if(open(IPTAB_TMPFILE, $tmpfile)){
         @lines = <IPTAB_TMPFILE>;
         close(IPTAB_TMPFILE);
      }
      foreach my $line (@lines){
         if ($line =~ s/-A INPUT -s .*\n//) {
         }
      }

      #Rewrite array to tmpfile
      if(open(IPTAB_TMPFILE, ">$tmpfile")){
         print IPTAB_TMPFILE @lines;
         close (IPTAB_TMPFILE);
      }

      # Copy iptables file back to node
      if (run_scp_command($tmpfile, "$computer_node_name:\"$source_file_path\"", $management_node_keys)) {
         notify($ERRORS{'DEBUG'}, 0, "copied $tmpfile to $computer_node_name $source_file_path");
      }
   }

   #restart iptables
   my $command = "iptables -P INPUT ACCEPT;iptables -P OUTPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -F; iptables-restore < /etc/iptables.rules";
   my ($status_iptables,$output_iptables) = $self->execute($command);
   if (defined $status_iptables && $status_iptables == 0) {
      notify($ERRORS{'DEBUG'}, 0, "executed command $command on $computer_node_name");
   }
   else {
      notify($ERRORS{'WARNING'}, 0, "output from iptables:" . join("\n", @$output_iptables));
   }

   if ($self->wait_for_ssh(0)) {
      return 1;
   }
   else {
      notify($ERRORS{'CRITICAL'}, 0, "not able to login via ssh after cleaning_iptables");
      return 0;
   }

}

sub capture_start {
	my $self = shift;
	if (ref($self) !~ /ubuntu/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $management_node_keys = $self->data->get_management_node_keys();
	my $image_name           = $self->data->get_image_name();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_node_name   = $self->data->get_computer_node_name();

	notify($ERRORS{'OK'}, 0, "initiating Ubuntu image capture: $image_name on $computer_short_name");

	notify($ERRORS{'OK'}, 0, "initating reboot for Ubuntu imaging sequence");
	run_ssh_command($computer_node_name, $management_node_keys, "/sbin/shutdown -r now", "root");
	notify($ERRORS{'OK'}, 0, "sleeping for 90 seconds while machine shuts down and reboots");
	sleep 90;

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub capture_start


#/////////////////////////////////////////////////////////////////////////////

sub reserve {
	my $self = shift;
	if (ref($self) !~ /ubuntu/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "Enterered reserve() in the Ubuntu OS module");

	my $user_name            = $self->data->get_user_login_id();
	my $computer_node_name   = $self->data->get_computer_node_name();
	my $image_identity       = $self->data->get_image_identity;
	my $reservation_password = $self->data->get_reservation_password();
	my $imagemeta_rootaccess = $self->data->get_imagemeta_rootaccess();

	my $useradd_string = "/usr/sbin/useradd -d /home/$user_name -m -g admin $user_name";

	my @sshcmd = run_ssh_command($computer_node_name, $image_identity, $useradd_string, "root");
	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /user $user_name exists/) {
			notify($ERRORS{'OK'}, 0, "detected user already has account");
		}

	}

	my $encrypted_pass;
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $image_identity, "/usr/bin/mkpasswd $reservation_password", "root");
	foreach my $l (@{$sshcmd[1]}) {
		$encrypted_pass = $l;
		notify($ERRORS{'DEBUG'}, 0, "Found the encrypted password as $encrypted_pass");
	}

	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $image_identity, "usermod -p $encrypted_pass $user_name", "root");
	foreach my $l (@{$sshcmd[1]}) {
		notify($ERRORS{'DEBUG'}, 0, "Updated the user password .... L is $l");
	}

	#Check image profile for allowed root access
	if ($imagemeta_rootaccess) {
		# Add to sudoers file
		#clear user from sudoers file
		my $clear_cmd = "sed -i -e \"/^$user_name .*/d\" /etc/sudoers";
		if (run_ssh_command($computer_node_name, $image_identity, $clear_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "cleared $user_name from /etc/sudoers");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to clear $user_name from /etc/sudoers");
		}
		my $sudoers_cmd = "echo \"$user_name ALL= NOPASSWD: ALL\" >> /etc/sudoers";
		if (run_ssh_command($computer_node_name, $image_identity, $sudoers_cmd, "root")) {
			notify($ERRORS{'DEBUG'}, 0, "added $user_name to /etc/sudoers");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "failed to add $user_name to /etc/sudoers");
		}
	} ## end if ($imagemeta_rootaccess)


	return 1;
} ## end sub reserve

sub grant_access {
	my $self = shift;
	if (ref($self) !~ /ubuntu/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $user               = $self->data->get_user_login_id();
	my $computer_node_name = $self->data->get_computer_node_name();
	my $identity           = $self->data->get_image_identity;

	notify($ERRORS{'OK'}, 0, "In grant_access routine $user,$computer_node_name");
	my @sshcmd;
	my $clear_extsshd = "sed -i -e \"/^AllowUsers .*/d\" /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $identity, $clear_extsshd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "cleared AllowUsers directive from external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user to external_sshd_config");
	}

	my $cmd = "echo \"AllowUsers $user\" >> /etc/ssh/external_sshd_config";
	if (run_ssh_command($computer_node_name, $identity, $cmd, "root")) {
		notify($ERRORS{'DEBUG'}, 0, "added AllowUsers $user to external_sshd_config");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to add AllowUsers $user to external_sshd_config");
		return 0;
	}
	undef @sshcmd;
	@sshcmd = run_ssh_command($computer_node_name, $identity, "/etc/init.d/ext_sshd restart", "root");

	foreach my $l (@{$sshcmd[1]}) {
		if ($l =~ /Stopping ext_sshd:/i) {
			#notify($ERRORS{'OK'},0,"stopping sshd on $computer_node_name ");
		}
		if ($l =~ /Starting ext_sshd:[  OK  ]/i) {
			notify($ERRORS{'OK'}, 0, "ext_sshd on $computer_node_name started");
		}
	}    #foreach
	notify($ERRORS{'OK'}, 0, "started ext_sshd on $computer_node_name");
	return 1;
} ## end sub grant_access

#/////////////////////////////////////////////////////////////////////////////

=head2 clean_known_files

 Parameters  : 
 Returns     : 1
 Description : Removes or overwrites known files that are not excluded.

=cut

sub clean_known_files {
	my $self = shift;
    if (ref($self) !~ /ubuntu/i) {
       notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
       return 0;
    }	
	
	my $computer_node_name = $self->data->get_computer_node_name();

	# Clear SSH idenity keys from /root/.ssh 
   if (!$self->clear_private_keys()) {
     notify($ERRORS{'WARNING'}, 0, "unable to clear known identity keys");
   }
	
	# Try to clear /tmp
   if ($self->execute("/bin/cp /dev/null /var/log/wtmp")) {
      notify($ERRORS{'DEBUG'}, 0, "cleared /var/log/wtmp on $computer_node_name");
   }

	#Fetch exclude_list
   my @exclude_list = $self->get_exclude_list();
	
	if (@exclude_list ) {
      notify($ERRORS{'DEBUG'}, 0, "skipping files listed in exclude_list\n" . join("\n", @exclude_list));
   }
   
   #Remove files
   if(!(grep( /70-persistent-net.rules/ , @exclude_list ) ) ){ 
      if(!$self->delete_file("/etc/udev/rules.d/70-persistent-net.rules")){
         notify($ERRORS{'WARNING'}, 0, "unable to remove /etc/udev/rules.d/70-persistent-net.rules");
      }    
   }
   
   if(!(grep( /\/var\/log\/auth/ , @exclude_list ) ) ){ 
      if(!$self->execute("cp /dev/null /var/log/auth.log")){
         notify($ERRORS{'WARNING'}, 0, "unable to overwrite  /var/log/auth.log");
      }    
   }
   
   if(!(grep( /\/var\/log\/lastlog/ , @exclude_list ) ) ){ 
      if(!$self->execute("cp /dev/null /var/log/lastlog")){
         notify($ERRORS{'WARNING'}, 0, "unable to overwrite /var/log/lastlog");
      }    
   }

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 enable_dhcp

 Parameters  : 
 Returns     : boolean
 Description : Overwrites interfaces file setting both to dhcp

=cut

#/////////////////////////////////////////////////////////////////////////////

sub enable_dhcp {
   if (ref($self) !~ /VCL::Module/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return;
   }

	my $request_id               = $self->data->get_request_id();
   my $computer_node_name = $self->data->get_computer_node_name();
	my $management_node_keys     = $self->data->get_management_node_keys();
   
   my $interface_name_argument = shift;
   my @interface_names;
  # if (!$interface_name_argument) {
  #    push(@interface_names, $self->get_private_interface_name());
  #    push(@interface_names, $self->get_public_interface_name());
  # }
  # elsif ($interface_name_argument =~ /private/i) {
  #    push(@interface_names, $self->get_private_interface_name());
  # }
  # elsif ($interface_name_argument =~ /public/i) {
  #    push(@interface_names, $self->get_public_interface_name());
  # }
  # else {
  #    push(@interface_names, $interface_name_argument);
  # }

	my @array2print;
	
	push(@array2print, '# This file describes the network interfaces available on your system'. "\n");
	push(@array2print, '# and how to activate them. For more information, see interfaces(5).'. "\n");
	push(@array2print, "\n");
	push(@array2print, '# The loopback network interface'. "\n");
	push(@array2print, 'auto lo'. "\n");
	push(@array2print, 'iface lo inet loopback'. "\n");
	push(@array2print, "\n");
	push(@array2print, '# The primary network interface'. "\n");
	push(@array2print, 'auto eth0 eth1'. "\n");
	push(@array2print, 'iface eth0 inet dhcp'. "\n");
	push(@array2print, 'iface eth1 inet dhcp'. "\n");

	   #write to tmpfile
   my $tmpfile = "/tmp/$request_id.interfaces";
   if (open(TMP, ">$tmpfile")) {
      print TMP @array2print;
      close(TMP);
   }
   else {
      notify($ERRORS{'OK'}, 0, "could not write $tmpfile $!");
      return 0;
   }

   #copy to node
   if (run_scp_command($tmpfile, "$computer_node_name:/etc/network/interfaces", $management_node_keys)) {
   }
   else{
		unlink($tmpfile);
      return 0;
   }
	
	unlink($tmpfile);
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 changepasswd

 Parameters  : called as an object
 Returns     : 1 - success , 0 - failure
 Description : changes or sets password for given account

=cut

sub changepasswd {
   my $self = shift;
   if (ref($self) !~ /linux/i) {
      notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
      return 0;
   }

   my $management_node_keys = $self->data->get_management_node_keys();
	my $computer_short_name = $self->data->get_computer_short_name();

   # change the privileged account passwords on the blade images
   my $node = shift;
   my $account = shift;
   my $passwd = shift;

   notify($ERRORS{'WARNING'}, 0, "node is not defined")    if (!(defined($node)));
   notify($ERRORS{'WARNING'}, 0, "account is not defined") if (!(defined($account)));

   $passwd = getpw(15) if (!(defined($passwd)));

	my $command = "echo $account:$passwd | chpasswd";
	
	my ($exit_status, $output) = $self->execute($command);
   if (!defined($output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to run command to determine if file or directory exists on $computer_short_name:\ncommand: '$command'");
      return;
   }
   elsif (grep(/no such file/i, @$output)) {
      #notify($ERRORS{'DEBUG'}, 0, "file or directory does not exist on $computer_short_name: '$path'");
      return 0;
   }
   elsif (grep(/stat: /i, @$output)) {
      notify($ERRORS{'WARNING'}, 0, "failed to determine if file or directory exists on $computer_short_name:\ncommand: '$command'\nexit status: $exit_status, output:\n" . join("\n", @$output));
      return;
   }	

	notify($ERRORS{'OK'}, 0, "changed password for account: $account");	
	return 1;
}


1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
