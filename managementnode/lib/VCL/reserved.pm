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
# $Id: reserved.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::reserved - Perl module for the VCL reserved state

=head1 SYNOPSIS

 use VCL::reserved;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my %request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info{RESERVATIONID} = $reservation_id;

 # Create a new VCL::reserved object based on the request information
 my $reserved = VCL::reserved->new(%request_info);

=head1 DESCRIPTION

 This module supports the VCL "reserved" state. The reserved state is reached
 after a user creates a reservation from the VCL web page. This module checks
 whether or not the user has acknowledged the reservation and connected to
 the machine. Once connected, the reservation will be put into the "inuse"
 state and the reserved process exits.

=cut

##############################################################################
package VCL::reserved;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

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

=head2 process

 Parameters  : Reference to current reserved object is automatically passed
               when invoked as a class method.
 Returns     : 1 if successful, 0 otherwise
 Description : Processes a reservation in the reserved state. Waits for user
               acknowledgement and connection.

=cut

sub process {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# Store hash variables into local variables
	my $request_data = $self->data->get_request_data;

	my $request_id           = $request_data->{id};
	my $request_logid        = $request_data->{logid};
	my $reservation_id       = $request_data->{RESERVATIONID};
	my $reservation_password = $request_data->{reservation}{$reservation_id}{pw};
	my $computer_id          = $request_data->{reservation}{$reservation_id}{computer}{id};
	my $computer_hostname    = $request_data->{reservation}{$reservation_id}{computer}{hostname};
	my $computer_short_name  = $request_data->{reservation}{$reservation_id}{computer}{SHORTNAME};
	my $computer_type        = $request_data->{reservation}{$reservation_id}{computer}{type};
	my $computer_ip_address  = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};
	my $image_os_name        = $request_data->{reservation}{$reservation_id}{image}{OS}{name};
	my $request_forimaging   = $request_data->{forimaging};
	my $image_name           = $request_data->{reservation}{$reservation_id}{imagerevision}{imagename};
	my $user_uid             = $request_data->{user}{uid};
	my $user_unityid         = $request_data->{user}{unityid};
	my $user_standalone      = $request_data->{user}{STANDALONE};
	my $imagemeta_checkuser  = $request_data->{reservation}{$reservation_id}{image}{imagemeta}{checkuser};
	my $reservation_count     = $self->data->get_reservation_count();
	

	# Update the log table, set the loaded time to now for this request
	if (update_log_loaded_time($request_logid)) {
		notify($ERRORS{'OK'}, 0, "updated log table, set loaded time to now for id:$request_logid");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update log table while attempting to set id:$request_logid loaded time to now");
	}

	# Figure out if image has usergroupid set in meta data and how many members it has
	my $imagemeta_usergroupid = '';
	my @user_group_members;
	my $user_group_member_count = 0;
	if (defined $request_data->{reservation}{$reservation_id}{image}{imagemeta}{usergroupid}) {
		notify($ERRORS{'OK'}, 0, "imagemeta user group defined $request_data->{reservation}{$reservation_id}{image}{imagemeta}{usergroupid}");
		$imagemeta_usergroupid   = $request_data->{reservation}{$reservation_id}{image}{imagemeta}{usergroupid};
		@user_group_members      = getusergroupmembers($imagemeta_usergroupid);
		$user_group_member_count = scalar @user_group_members;
	}
	notify($ERRORS{'OK'}, 0, "imagemeta user group membership count = $user_group_member_count");

	my $nodename;
	my $retval_conn;

	# Figure out the node name based on the type of computer
	if ($computer_type eq "blade") {
		$nodename = $computer_short_name;
	}
	elsif ($computer_type eq "lab") {
		$nodename = $computer_hostname;
	}
	elsif ($computer_type eq "virtualmachine") {
		$nodename = $computer_short_name;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "computer id=$computer_id did not have a type, exiting");
		exit;
	}

	notify($ERRORS{'OK'}, 0, "computer info: id=$computer_id, type=$computer_type, hostname=$nodename");
	notify($ERRORS{'OK'}, 0, "user info: uid=$user_uid, unity id=$user_unityid, standalone=$user_standalone");
	notify($ERRORS{'OK'}, 0, "imagemeta checkuser set to: $imagemeta_checkuser");
	notify($ERRORS{'OK'}, 0, "formimaging set to: $request_forimaging");

	my $connected     = 0;
	my $curr_time     = time();
	my $time_limit    = 15;
	my $time_exceeded = 0;
	my $break         = 0;

	# Create limit to keep our magic under control
	my $acknowledge_attempts = 0;

	notify($ERRORS{'OK'}, 0, "begin checking for user acknowledgement");
	insertloadlog($reservation_id, $computer_id, "info", "reserved: waiting for user acknowledgement");

	ACKNOWLEDGE:
	$acknowledge_attempts++;

	# Try to get the remote IP again and update the data hash
	my $remote_ip = $self->data->get_reservation_remote_ip();

	# 0 should be returned if remoteIP isn't set, undefined if an error occurred
	if (!defined $remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "failed to determine remote IP");
		return;
	}

	# Check if remoteIP is defined yet (user has acknowledged)
	elsif ($remote_ip ne '0') {
		# User has acknowledged
		notify($ERRORS{'OK'}, 0, "user acknowledged, remote IP: $remote_ip");

		# Attempt to call modularized OS module's grant_access() subroutine
		if ($self->os->can("grant_access")) {
			# If grant_access() has been implemented by OS module,
			# don't check for remote IP and open RDP firewall port directly in this module
			# OS module's grant_access() subroutine to perform the same tasks as below
			notify($ERRORS{'OK'}, 0, "calling " . ref($self->os) . "::grant_access() subroutine");
			if ($self->os->grant_access()) {
				notify($ERRORS{'OK'}, 0, "OS access has been granted on $nodename");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "failed to grant OS access on $nodename");
			}
		}
		
		# Older style code, remove below once all OS's have been modularized
		# Check if computer type is blade
		elsif ($computer_type =~ /blade|virtualmachine/) {
			notify($ERRORS{'OK'}, 0, "blade or virtual machine detected: $computer_type");
			# different senerios
			# standard -- 1-1-1 with connection checks
			# group access M-N-K -- multiple users need access
			# standard with no connection checks
			
			if ($image_os_name =~ /win|vmwarewin/) {
				notify($ERRORS{'OK'}, 0, "Windows image detected: $image_os_name");
				
				# Determine whether to open RDP port for single IP or group access
				if ($user_group_member_count > 0) {
					# Imagemeta user group defined and member count is > 0
					notify($ERRORS{'OK'}, 0, "group set in imagemeta has members");
					if (remotedesktopport($nodename, "ENABLE")) {
						notify($ERRORS{'OK'}, 0, "remote desktop enabled on $nodename for group access");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "remote desktop not group enabled on $nodename");
						$retval_conn = "failed";
						goto RETVALCONN;
					}
				}    # Close imagemeta user group defined and member count is > 0
				else {
					# Imagemeta user group undefined or member count is 0
					notify($ERRORS{'OK'}, 0, "either group not set in imagemeta or has 0 members");
					if (remotedesktopport($nodename, "ENABLE", $remote_ip)) {
						insertloadlog($reservation_id, $computer_id, "info", "reserved: opening remote access port for $remote_ip");
						notify($ERRORS{'OK'}, 0, "remote desktop enabled on $nodename");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "remote desktop not enabled on $nodename");
						$retval_conn = "failed";
						goto RETVALCONN;
					}
				}    # Close imagemeta user group undefined or member count is 0

				# Check if forimaging is set on the request
				if (!$request_forimaging) {
					## Don't care to monitor any imaging reservations
					#notify($ERRORS{'OK'}, 0, "this is not a forimaging request, check for ITM monitoring");
					#if (system_monitoring($nodename, $image_name, "start", "ITM")) {
					#	notify($ERRORS{'OK'}, 0, "ITM monitoring enabled");
					#	insertloadlog($reservation_id, $computer_id, "info", "reserved: ITM detected starting system monitoring");
					#}
					#else {
					#	# Don't care at this time
					#	notify($ERRORS{'OK'}, 0, "ITM monitoring is not enabled");
					#}
				}    # Close if request forimaging

			}    # Close if OS name is win or vmware

			# Check if linux image
			elsif ($image_os_name =~ /^(rh[0-9]image|rhel[0-9]|fc[0-9]image|rhfc[0-9]|rhas[0-9])/) {
				notify($ERRORS{'OK'}, 0, "Linux image detected: $image_os_name");

				# adduser ; this adds user and restarts sshd
				# check for group access

				my $grpflag = 0;
				my @group;

				if ($imagemeta_usergroupid ne '') {
					notify($ERRORS{'OK'}, 0, "group access groupid $imagemeta_usergroupid");

					# Check group membership count
					if ($user_group_member_count > 0) {
						# Good, at least something is listed
						notify($ERRORS{'OK'}, 0, "imagemeta group acess membership is $user_group_member_count");
						$grpflag = $user_group_member_count;
						@group   = @user_group_members;
					}
					else {
						notify($ERRORS{'OK'}, 0, "image claims group access but membership is 0, usergrouid: $imagemeta_usergroupid, only adding requester");
					}

				}    # Close imagemeta user group defined and member count is > 0

				# Try to add the user account to the linux computer
				if (add_user($computer_short_name, $user_unityid, $user_uid, 0, $computer_hostname, $image_os_name, $remote_ip, $grpflag, @group)) {
					notify($ERRORS{'OK'}, 0, "user $user_unityid added to $computer_short_name");
					insertloadlog($reservation_id, $computer_id, "info", "reserved: adding user and opening remote access port for $remote_ip");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "could not add user $user_unityid to $computer_short_name");
					insertloadlog($reservation_id, $computer_id, "failed", "reserved: could not add user to node");
					$retval_conn = "failed";
					goto RETVALCONN;
				}

				# Check if user was set to standalone
				# Occurs if affiliation is not NCSU or if vcladmin is the user
				if ($user_standalone) {
					if (changelinuxpassword($computer_short_name, $user_unityid, $reservation_password)) {
						# Password successfully changed
						notify($ERRORS{'OK'}, 0, "password changed on $computer_short_name for standalone user $user_unityid");
					}
					else {
						notify($ERRORS{'WARNING'}, 0, "could not change linux password for $user_unityid on $computer_short_name");
						insertloadlog($reservation_id, $computer_id, "failed", "reserved: could not change user password on node");
						$retval_conn = "failed";
						goto RETVALCONN;
					}
				}    # Close if standalone
				else {
					notify($ERRORS{'OK'}, 0, "password not changed on $computer_short_name for non-standalone user $user_unityid");
				}

				#if cluster reservation - populate parent node with child node information
				if ($request_data->{RESERVATIONCOUNT} > 1) {
					notify($ERRORS{'OK'}, 0, "cluster reservation, attempting to populate nodes with cluster_info data");
					if (update_cluster_info($request_data)) {
						notify($ERRORS{'OK'}, 0, "updated cluster nodes with cluster infomation");
					}
				}

			}    # Close elseif linux computer

		}    # Close if computer type is blade

		# Check if computer type is lab
		elsif ($computer_type eq "lab") {
			notify($ERRORS{'OK'}, 0, "lab computer detected");

			# Check if Solaris or RHEL
			if ($image_os_name =~ /sun4x_|rhel/) {
				notify($ERRORS{'OK'}, 0, "Sun or RHEL lab computer detected");
				if (enablesshd($computer_ip_address, $user_unityid, $remote_ip, "new", $image_os_name)) {
					notify($ERRORS{'OK'}, 0, "SSHD enabled on $computer_hostname $computer_ip_address");
				}
				else {
					# Could not enable SSHD
					# Add code to better handle this such as fetch another machine
					notify($ERRORS{'WARNING'}, 0, "could not enable SSHD on $computer_hostname");

					# Update the computer state to failed
					if (update_computer_state($computer_id, "failed", "new")) {
						notify($ERRORS{'OK'}, 0, "setting computer ID $computer_id into failed state");
					}

					insertloadlog($reservation_id, $computer_id, "failed", "reserved: could not enable access port on remote machine");
					$retval_conn = "failed";
					goto RETVALCONN;
				} ## end else [ if (enablesshd($computer_ip_address, $user_unityid...
			}    # Close if Solaris or RHEL

		}    # Close elsif computer type is lab

	}    # close if defined remoteIP

	elsif ($acknowledge_attempts < 180) {
		# User has approximately 15 minutes to acknowledge (5 seconds * 180 attempts)

		# Print a status message every tenth attempt
		if (($acknowledge_attempts % 10) == 0) {
			# Print message every tenth attempt
			notify($ERRORS{'OK'}, 0, "attempt $acknowledge_attempts of 180, user has not acknowleged");
		}

		sleep 5;

		# Check if user deleted the request
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "user has deleted the request, exiting");
			exit;
		}

		# Going back to check for user acknowledgment again
		goto ACKNOWLEDGE;

	}    # Close acknowledge attempts < 120


	else {
		# Acknowledge attemtps >= 120
		# User never acknowledged reques, return noack
		notify($ERRORS{'OK'}, 0, "user never acknowleged request, proceed to timeout");

		# Check if user deleted the request
		if (is_request_deleted($request_id)) {
			notify($ERRORS{'OK'}, 0, "user has deleted the request, exiting");
			exit;
		}

		$retval_conn = "noack";

		# Skipping check_connection code
		goto RETVALCONN;
	} ## end else [ if (defined $remote_ip && $remote_ip eq '0') [... [elsif ($acknowledge_attempts < 180)


	# Determine if connection needs to be checked based on imagemeta checkuser flag
	if (!$imagemeta_checkuser) {
		# If checkuser = 1, check for a user connection
		# If checkuser = 0, set as inuse and return
		notify($ERRORS{'OK'}, 0, "checkuser flag set to 0, skipping user connection");
		$retval_conn = "connected";
		goto RETVALCONN;
	}
	# Check if cluster request
	elsif ($reservation_count > 1) {
		notify($ERRORS{'OK'}, 0, "reservation count is $reservation_count, skipping user connection check");
		$retval_conn = "connected";
		goto RETVALCONN;
	}
	else {
		# Check for user connection
		notify($ERRORS{'OK'}, 0, "checkuser flag is set to 1, checking user connection");
		# Check for the normal user ID if this isn't an imaging request
		# Check for "administrator" if this is an imaging request
		if ($request_forimaging) {
			notify($ERRORS{'OK'}, 0, "forimaging flag is set to 1, checking for connection by administrator");
			$retval_conn = check_connection($nodename, $computer_ip_address, $computer_type, $remote_ip, $time_limit, $image_os_name, 0, $request_id, "administrator");
		}
		else {
			notify($ERRORS{'OK'}, 0, "forimaging flag is set to 0, checking for connection by $user_unityid");
			$retval_conn = check_connection($nodename, $computer_ip_address, $computer_type, $remote_ip, $time_limit, $image_os_name, 0, $request_id, $user_unityid);
		}
	} ## end else [ if (!$imagemeta_checkuser)

	RETVALCONN:
	notify($ERRORS{'OK'}, 0, "retval_conn = $retval_conn");

	# Check the return value and perform some actions
	if ($retval_conn eq "deleted") {
		notify($ERRORS{'OK'}, 0, "user deleted request, exiting");
		exit;
	}

	elsif ($retval_conn eq "connected") {
		# User is connected, update state of the request, computer and set lastcheck time to current time
		notify($ERRORS{'OK'}, 0, "$remote_ip connected to $nodename");

		insertloadlog($reservation_id, $computer_id, "connected", "reserved: user connected to remote machine");

		# Update the request state to either inuse or imageinuse
		if (update_request_state($request_id, "inuse", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into inuse state");
		}

		# Update the computer state to inuse
		if (update_computer_state($computer_id, "inuse")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into inuse state");
		}

		# Update the lastcheck value for this reservation to now
		if (update_reservation_lastcheck($reservation_id)) {
			notify($ERRORS{'OK'}, 0, "updated lastcheck time for reservation $reservation_id");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to update lastcheck time for reservation $reservation_id");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "connected")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "conn_wrong_ip") {
		# does the same as above, until we make a firm decision as to how to handle this

		# Update the request state to inuse
		if (update_request_state($request_id, "inuse", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into inuse state");
		}

		# Update the computer state to inuse
		if (update_computer_state($computer_id, "inuse")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into inuse state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into inuse state");
		}

		# Update the lastcheck value for this reservation to now
		if (update_reservation_lastcheck($reservation_id)) {
			notify($ERRORS{'OK'}, 0, "updated lastcheck time for reservation $reservation_id");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "unable to update lastcheck time for reservation $reservation_id");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "conn_wrong_ip")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "nologin") {
		#user ack'd but did not login
		notify($ERRORS{'OK'}, 0, "user acknowledged but did not log in");

		# Update the request state to timeout
		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		$self->_notify_user_timeout($request_data);

		# Update the entry in the log table with the current finalend time and ending set to nologin
		if (update_log_ending($request_logid, "nologin")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to nologin");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to nologin");
		}

		insertloadlog($reservation_id, $computer_id, "info", "reserved: timing out user not connected to remote machine");

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "nologin")  [ if ($retval_conn eq "deleted")
	elsif ($retval_conn eq "noack") {
		# set to timeout state
		#user never ack'd
		notify($ERRORS{'OK'}, 0, "user never acknowledged");

		# Update the request state to timeout
		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		$self->_notify_user_timeout($request_data);

		# Update the entry in the log table with the current finalend time and ending set to noack
		if (update_log_ending($request_logid, "noack")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to noack");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to noack");
		}

		insertloadlog($reservation_id, $computer_id, "info", "reserved: timing out user not acknowledged reservation");

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "noack")  [ if ($retval_conn eq "deleted")
	elsif ($retval_conn eq "failed") {
		# Update the request state to failed
		notify($ERRORS{'OK'}, 0, "failed to reserve machine");

		if (update_request_state($request_id, "failed", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into failed state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into failed state");
		}

		# Update the computer state to failed
		if (update_computer_state($computer_id, "failed")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into failed state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into failed state");
		}

		# Update the entry in the log table with the current finalend time and ending set to noack
		if (update_log_ending($request_logid, "failed")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to failed");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to failed");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "failed")  [ if ($retval_conn eq "deleted")

	elsif ($retval_conn eq "timeout") {
		# Update the request state to timeout
		notify($ERRORS{'OK'}, 0, "reservation timed out");

		if (update_request_state($request_id, "timeout", "reserved")) {
			notify($ERRORS{'OK'}, 0, "setting request into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set request into timeout state");
		}

		# Update the computer state to timeout
		if (update_computer_state($computer_id, "timeout")) {
			notify($ERRORS{'OK'}, 0, "setting computerid $computer_id into timeout state");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unable to set computerid $computer_id into timeout state");
		}

		# Update the entry in the log table with the current finalend time and ending set to timeout
		if (update_log_ending($request_logid, "timeout")) {
			notify($ERRORS{'OK'}, 0, "log id $request_logid was updated and ending set to timeout");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "log id $request_logid could not be updated and ending set to timeout");
		}

		notify($ERRORS{'OK'}, 0, "exiting");
		exit;
	} ## end elsif ($retval_conn eq "timeout")  [ if ($retval_conn eq "deleted")
} ## end sub process
#/////////////////////////////////////////////////////////////////////////////

=head2 _notify_user_timeout

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Notifies the user that the request has timed out becuase no
               initial connection was made. An e-mail and/or IM message will
               be sent to the user.

=cut

sub _notify_user_timeout {
	my $self = shift;
	my ($package, $filename, $line, $sub) = caller(0);

	# Store hash variables into local variables
	my $request_data = $self->data->get_request_data;

	my $request_id                 = $request_data->{id};
	my $reservation_id             = $request_data->{RESERVATIONID};
	my $user_preferredname         = $request_data->{user}{preferredname};
	my $user_email                 = $request_data->{user}{email};
	my $user_emailnotices          = $request_data->{user}{emailnotices};
	my $user_im_name               = $request_data->{user}{IMtype}{name};
	my $user_im_id                 = $request_data->{user}{IMid};
	my $affiliation_sitewwwaddress = $request_data->{user}{affiliation}{sitewwwaddress};
	my $affiliation_helpaddress    = $request_data->{user}{affiliation}{helpaddress};
	my $image_prettyname           = $request_data->{reservation}{$reservation_id}{image}{prettyname};
	my $computer_ip_address        = $request_data->{reservation}{$reservation_id}{computer}{IPaddress};

	#my ($emailaddress,$firstname,$type,$ipaddress,$imagename,$url,$IMname,$IMid) = @_;
	my $message = <<"EOF";
$user_preferredname,
Your reservation has timed out for image $image_prettyname at address $computer_ip_address because no initial connection was made.

To make another reservation, please revisit $affiliation_sitewwwaddress.

Thank You,
VCL Team
EOF

	my $subject = "VCL -- Reservation Timeout";

	if ($user_emailnotices) {
		#if  "0" user does not care to get additional notices
		mail($user_email, $subject, $message, $affiliation_helpaddress);
		notify($ERRORS{'OK'}, 0, "sent reservation timeout e-mail to $user_email");
	}
	if ($user_im_name ne "none") {
		notify_via_IM($user_im_name, $user_im_id, $message);
		notify($ERRORS{'OK'}, 0, "sent reservation timeout IM to $user_im_name");
	}
	return 1;
} ## end sub _notify_user_timeout
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
