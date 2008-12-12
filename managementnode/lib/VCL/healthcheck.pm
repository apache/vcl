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
# $Id: healthcheck.pm 1945 2008-12-11 20:58:08Z fapeeler $
##############################################################################

=head1 NAME

VCL::healthcheck

=head1 SYNOPSIS

 use base qw(VCL::healthcheck);

=head1 DESCRIPTION

 Needs to be written.

=cut

##############################################################################
package VCL::healthcheck;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use DBI;
use Net::DNS;
use VCL::Module::Provisioning::xCAT;
use VCL::Module::Provisioning::Lab;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

#----------GLOBALS--------------
our $LOG = "/var/log/healthcheckvcl.log";
our $MYDBH;

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function
///
/// \param
///
/// \return
///
/// \brief
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub new {
	my ($class, %input) = @_;
	my $obj_ref = {%input,};
	bless $obj_ref, $class;    # bless ref to said class
	$obj_ref->_initialize();   # more work to do
	return $obj_ref;

}

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function
///
/// \param
///
/// \return
///
/// \brief
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _initialize {
	my ($hck) = @_;
	my ($mnid, $managementnodeid, $selh, @row, $rows, $mnresourceid, $resourceid);
	my @hostinfo = hostname;
	$hck->{MN}   = $hostinfo[0];
	$hck->{MNos} = $hostinfo[1];
	$hck->{dbh}  = getnewdbh;

	#set global dbh for imagerevision check
	$MYDBH = $hck->{dbh};

	#= DBI->connect(qq{dbi:mysql:$DATABASE:$SERVER}, $WRTUSER,$WRTPASS, {PrintError => 0});
	unless (defined $hck->{dbh}) {    # dbh is an undef on failure
		my $outstring = DBI::errstr();
		notify($ERRORS{'WARNING'}, $LOG, $outstring);
		#goto SLEEP;
		return 0;
	}
	$hck->{"globalmsg"}->{"header"} = "STATUS SUMMARY of VCL nodes:\n\n";

	#1 get management node id and management node's resource id
	$selh = $hck->{dbh}->prepare(
		"SELECT m.id,r.id
                            FROM resource r, resourcetype rt, managementnode m
                            WHERE r.resourcetypeid = rt.id AND r.subid = m.id AND rt.name = ? AND m.hostname = ?") or notify($ERRORS{'WARNING'}, $hck->{LOG}, "Could not prepare select for management node id" . $hck->{dbh}->errstr());

	$selh->execute("managementnode", $hck->{MN}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute management node id" . $hck->{dbh}->errstr());

	my $dbretval = $selh->bind_columns(\($managementnodeid, $resourceid));
	$rows = $selh->rows;
	if ($rows != 0) {
		while ($selh->fetch) {
			$mnid                  = $managementnodeid;
			$mnresourceid          = $resourceid;
			$hck->{"mnid"}         = $managementnodeid;
			$hck->{"mnresourceid"} = $resourceid;
			notify($ERRORS{'OK'}, $LOG, "$hck->{MN} mnid $mnid  resourceid $resourceid");
		}
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOG, "No management id for $hck->{MN}.");
		exit;
	}

	#2 select management node groups I belong to

	$selh = $hck->{dbh}->prepare("SELECT resourcegroupid FROM resourcegroupmembers WHERE resourceid= ?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare select for management node group membership" . $hck->{dbh}->errstr());
	$selh->execute($hck->{mnresourceid}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute statement for collecting my group membership" . $hck->{dbh}->errstr());
	$rows = $selh->rows;
	if ($rows != 0) {
		while (@row = $selh->fetchrow_array) {
			$hck->{"groupmembership"}->{$row[0]} = $row[0];
			notify($ERRORS{'OK'}, $LOG, "$hck->{MN} resourceid $hck->{mnresourceid} is in group $row[0]");
		}
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOG, "Not a member of any groups $hck->{MN} resourceid $hck->{mnresourceid}");
		exit;
	}

	#3 get list of computer groups I have access to control
	$selh = $hck->{dbh}->prepare("SELECT r.resourcegroupid2 FROM resourcemap r, resourcetype rt WHERE r.resourcetypeid2=rt.id AND r.resourcegroupid1=? AND rt.name=?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare computer groups statement:" . $hck->{dbh}->errstr());
	foreach my $grpid (sort keys(%{$hck->{groupmembership}})) {
		$selh->execute($hck->{groupmembership}->{$grpid}, "computer") or notify($ERRORS{'WARNING'}, $LOG, "Could not execute computer goups statement:" . $hck->{dbh}->errstr());
		$rows = $selh->rows;
		if ($rows != 0) {
			while (@row = $selh->fetchrow_array) {
				$hck->{"groupscancrontrol"}->{$row[0]} = $row[0];
				notify($ERRORS{'OK'}, $LOG, "$hck->{MN} resourceid $hck->{mnresourceid} cg= $grpid manages group $row[0]");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, $LOG, "no group to control $hck->{MN} resourceid $hck->{mnresourceid} groupid $grpid ");
		}
	} ## end foreach my $grpid (sort keys(%{$hck->{groupmembership...

	#4 foreach of the groups i can manage get the computer members
	$selh = $hck->{dbh}->prepare(
		"SELECT r.subid,r.id
                                    FROM resourcegroupmembers rm,resourcetype rt,resource r
                                    WHERE rm.resourceid=r.id AND rt.id=r.resourcetypeid AND rt.name=? AND rm.resourcegroupid =?
                                    ") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare computer groups statement:" . $hck->{dbh}->errstr());
	foreach my $rgroupid (sort keys(%{$hck->{groupscancrontrol}})) {
		$selh->execute("computer", $hck->{groupscancrontrol}->{$rgroupid}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute computer goups statement:" . $hck->{dbh}->errstr());
		$rows = $selh->rows;
		#notify($ERRORS{'OK'},$LOG,"rows = $rows for group$hck->{groupscancrontrol}->{$rgroupid}");
		if ($rows != 0) {
			while (@row = $selh->fetchrow_array) {
				$hck->{"computers"}->{$row[0]}->{"id"} = $row[0];
				#  notify($ERRORS{'OK'},$LOG,"$hck->{MN} resourceid $row[1] computerid $row[0] in group $hck->{groupscancrontrol}->{$rgroupid}");
			}
		}
		else {
			notify($ERRORS{'WARNING'}, $LOG, "no group to control $hck->{MN} resourceid $hck->{mnresourceid} groupid $rgroupid ");
		}
	} ## end foreach my $rgroupid (sort keys(%{$hck->{groupscancrontrol...

	#5 based from our hash table of computer ids collect individual computer information
	$selh = $hck->{dbh}->prepare(
		"SELECT c.hostname,c.IPaddress,c.lastcheck,s.name,c.currentimageid,c.preferredimageid,c.imagerevisionid,c.type,c.ownerid,i.name,o.name,c.deleted
                                    FROM computer c,state s, image i, OS o
                                    WHERE s.id=c.stateid AND i.id=c.currentimageid AND o.id=i.OSid AND c.id =?
                                    ") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare computer info statement:" . $hck->{dbh}->errstr());
	foreach my $cid (sort keys(%{$hck->{computers}})) {
		$selh->execute($hck->{computers}->{$cid}->{id}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute computer info statement:" . $hck->{dbh}->errstr());
		$rows = $selh->rows;
		my @crow;
		if ($rows != 0) {
			while (@crow = $selh->fetchrow_array) {
				$hck->{computers}->{$cid}->{"hostname"}         = $crow[0];
				$hck->{computers}->{$cid}->{"IPaddress"}        = $crow[1];
				$hck->{computers}->{$cid}->{"lastcheck"}        = $crow[2] if (defined($crow[2]));
				$hck->{computers}->{$cid}->{"state"}            = $crow[3];
				$hck->{computers}->{$cid}->{"currentimageid"}   = $crow[4];
				$hck->{computers}->{$cid}->{"preferredimageid"} = $crow[5];
				$hck->{computers}->{$cid}->{"imagerevisionid"}  = $crow[6];
				$hck->{computers}->{$cid}->{"type"}             = $crow[7];
				$hck->{computers}->{$cid}->{"ownerid"}          = $crow[8];
				$hck->{computers}->{$cid}->{"dbimagename"}      = $crow[9];
				$hck->{computers}->{$cid}->{"OSname"}           = $crow[10];
				$hck->{computers}->{$cid}->{"shortname"}        = $1 if ($crow[0] =~ /([-_a-zA-Z0-9]*)\./);    #should cover all host
				$hck->{computers}->{$cid}->{"MNos"}             = $hck->{MNos};
				$hck->{computers}->{$cid}->{"deleted"}          = $crow[11];
				$hck->{computers}->{$cid}->{"id"}               = $cid;
			} ## end while (@crow = $selh->fetchrow_array)
		} ## end if ($rows != 0)
		else {
			notify($ERRORS{'WARNING'}, $LOG, "no rows related to computer id $hck->{computers}->{$cid}->{id} reporting no data to pull for computer info statement ");
		}
	} ## end foreach my $cid (sort keys(%{$hck->{computers}}...
} ## end sub _initialize

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function process
///
/// \param
///
/// \return
///
/// \brief check each computer, sort checks by type
///   lab: ssh check,vclclientd running, adduser,deluser
///   blade: ssh check, correct image, adduser,deluser
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub process {
	my ($hck) = @_;
	notify($ERRORS{'OK'}, $LOG, "in processing routine");
	$hck->{"globalmsg"}->{"body"} = "Summary of VCL node monitoring system:\n\n";

	if (!($hck->{dbh}->ping)) {
		$hck->{dbh} = getnewdbh();
	}

	my $checkstate = $hck->{dbh}->prepare(
		"SELECT s.name,c.lastcheck FROM computer c,state s
                                    WHERE s.id=c.stateid AND c.id =?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare state check statement on computer:" . $hck->{dbh}->errstr());

	$hck->{"computercount"}    = 0;
	$hck->{"computerschecked"} = 0;

	foreach my $cid (sort keys(%{$hck->{computers}})) {
		#skipping virtual machines for now
		next if ($hck->{computers}->{$cid}->{type} eq "virtualmachine");

		# check ssh
		# check uptime
		# check vclclientd working
		# reboot if needed
		# update lastcheck timestamp
		# update state if needed
		# add to failed notification summary if needed
		# $hostname,$os,$mnOS,$ipaddress,$log
		# check the current image revision

		#count the node
		$hck->{"computercount"} += 1;
		#recheck state and lastcheck time -- this is important as more machines are checked
		if (!($hck->{dbh}->ping)) {
			#just incase handle and statement are lost
			$hck->{dbh} = getnewdbh();
			$checkstate = $hck->{dbh}->prepare(
				"SELECT s.name FROM computer c,state s
                                   WHERE s.id=c.stateid AND c.id =?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare state check statement on computer:" . $hck->{dbh}->errstr());

		}

		$checkstate->execute($hck->{computers}->{$cid}->{id}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute computer check state for $hck->{computers}->{$cid}->{id}:" . $hck->{dbh}->errstr());
		my $rows = $checkstate->rows;
		if ($rows != 0) {
			my @crow = $checkstate->fetchrow_array;
			$hck->{computers}->{$cid}->{"state"} = $crow[0];
		}
		else {
			notify($ERRORS{'WARNING'}, $LOG, "no rows related to computer id $hck->{computers}->{$cid}->{id} reporting no data to pull for computer info statement ");
			$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname} : UNABLE to pull current state, skipping";
			next;
		}
		if ($hck->{computers}->{$cid}->{state} =~ /inuse|reloading/) {
			next;
			notify($ERRORS{'OK'}, $LOG, "NODE $hck->{computers}->{$cid}->{hostname} inuse skipping");

		}
		if ($hck->{computers}->{$cid}->{state} =~ /^(maintenance|hpc|vmhostinue)/) {
			$hck->{computers}->{$cid}->{"skip"} = 1;
			$hck->{"computersskipped"} += 1;
			next;
		}

		if ($hck->{computers}->{$cid}->{deleted}) {
			#machine deleted but set on a state we monitor
			$hck->{computers}->{$cid}->{"confirmedstate"} = "maintenance";
			goto UPDATESTATE;
		}

		#check lastcheck
		if (defined($hck->{computers}->{$cid}->{"lastcheck"})) {
			my $lastcheckepoch  = convert_to_epoch_seconds($hck->{computers}->{$cid}->{lastcheck});
			my $currentimeepoch = convert_to_epoch_seconds();
			my $delta           = ($currentimeepoch - $lastcheckepoch);
			#if( $delta <= (5*60) ){
			if ($delta <= (1 * 60 * 60 * 24 + 60 * 60)) {
				#if( $delta <= (90*60) ){
				notify($ERRORS{'OK'}, $LOG, "NODE $hck->{computers}->{$cid}->{hostname} recently checked skipping");
				#this node was recently checked
				$hck->{computers}->{$cid}->{"skip"} = 1;
				$hck->{"computersskipped"} += 1;
				next;
			}
			$hck->{"computerschecked"} += 1;
		} ## end if (defined($hck->{computers}->{$cid}->{"lastcheck"...

		#handle the failed machines first
		if ($hck->{computers}->{$cid}->{state} =~ /failed|available/) {

			if (_valid_host($hck->{computers}->{$cid}->{hostname})) {
				$hck->{computers}->{$cid}->{"valid_host"}   = 1;
				$hck->{computers}->{$cid}->{"basechecksok"} = 0;
				notify($ERRORS{'OK'}, $LOG, "process: reports valid host for $hck->{computers}->{$cid}->{hostname}");
			}
			else {
				# for now leave state as to annoy owner to either remove or update the machine
				$hck->{computers}->{$cid}->{"valid_host"} = 0;
				$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname}, $hck->{computers}->{$cid}->{IPaddress} : INVALID HOSTname, remove or update\n";
				next;
			}

			my @basestatus = _baseline_checks($hck->{computers}->{$cid});
			$hck->{computers}->{$cid}->{"ping"}           = $basestatus[0];
			$hck->{computers}->{$cid}->{"sshd"}           = $basestatus[1];
			$hck->{computers}->{$cid}->{"vclclientd"}     = $basestatus[2] if ($hck->{computers}->{$cid}->{type} eq "lab");
			$hck->{computers}->{$cid}->{"localimagename"} = $basestatus[2] if ($hck->{computers}->{$cid}->{type} eq "blade");
			$hck->{computers}->{$cid}->{"uptime"}         = $basestatus[3];
			$hck->{computers}->{$cid}->{"basechecksok"}   = $basestatus[4];
			$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname} : $basestatus[5]\n" if (defined($basestatus[5]));
			#notify($ERRORS{'OK'},$LOG,"status= $basestatus[0],$basestatus[1],$basestatus[2],$basestatus[3],$basestatus[4]");

			if ($hck->{computers}->{$cid}->{basechecksok}) {
				#baseline checks ok, do more checks
				if (_imagerevision_check($hck->{computers}->{$cid})) {

				}

				if ($hck->{computers}->{$cid}->{type} eq "lab") {
					#  if(enablesshd($hck->{computers}->{$cid}->{hostname},"eostest1",$hck->{computers}->{$cid}->{IPaddress},"new",$hck->{computers}->{$cid}->{OSname},$LOG)){
					#good now disable it disable($hostname,$unityname,$remoteIP,$state,$osname,$log
					#   if(disablesshd($hck->{computers}->{$cid}->{hostname},"eostest1",$hck->{computers}->{$cid}->{IPaddress},"timeout",$hck->{computers}->{$cid}->{OSname},$LOG)){
					$hck->{computers}->{$cid}->{"confirmedstate"} = "available";
					$hck->{"labnodesavailable"} += 1;
					$hck->{"globalmsg"}->{"correctedbody"} .= "$hck->{computers}->{$cid}->{hostname} : was failed, now active\n" if ($hck->{computers}->{$cid}->{state} eq "failed");
					#  }
					# else{
					# #failed
					#$hck->{computers}->{$cid}->{"confirmedstate"}="failed";
					# $hck->{"labnodesfailed"} +=1;
					#$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname} : failed could not disablesshd\n";
					#}
					#}
					#else{
					#failed
					#$hck->{computers}->{$cid}->{"confirmedstate"}="failed";
					#$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname} : failed could not enablesshd\n";
					#}
					if ($hck->{computers}->{$cid}->{uptime} >= 10) {
						$hck->{"globalmsg"}->{"failedbody"} .= "$hck->{computers}->{$cid}->{hostname} : UPTIME $hck->{computers}->{$cid}->{uptime} days\n";
					}
				} ## end if ($hck->{computers}->{$cid}->{type} eq "lab")
				elsif ($hck->{computers}->{$cid}->{type} eq "blade") {
					#blade tasks
					#options fork in order to load mulitples simultaneously
					#TASKS:
					# 1) partly completed, basechecks are ok, pingable, sshd running/logins ok,
					# 2) does image name match whats listed
					#
					$hck->{computers}->{$cid}->{"confirmedstate"} = "available";
				}
			} ## end if ($hck->{computers}->{$cid}->{basechecksok...
			else {
				#basechecks failed, reason appended to failedbody already
				if ($hck->{computers}->{$cid}->{type} eq "lab") {
					# can not do much about a lab machine
					$hck->{computers}->{$cid}->{"confirmedstate"} = "failed";
					$hck->{"labnodesfailed"} += 1;
				}
				elsif ($hck->{computers}->{$cid}->{type} eq "blade") {
					$hck->{computers}->{$cid}->{"confirmedstate"} = "failed";
					#dig deeper --
					#if no power turn on and wait
					#if no sshd
				}
			} ## end else [ if ($hck->{computers}->{$cid}->{basechecksok...
			UPDATESTATE:
			if ($hck->{computers}->{$cid}->{"confirmedstate"} ne $hck->{computers}->{$cid}->{"state"}) {
				#different states update db to reflected confirmed state
				#my $stateid;
				#$stateid = 2 if($hck->{computers}->{$cid}->{"confirmedstate"} eq "available");
				#$stateid = 5 if($hck->{computers}->{$cid}->{"confirmedstate"} eq "failed");
				#$stateid = 10 if($hck->{computers}->{$cid}->{"confirmedstate"} eq "maintenance");
				$hck->{computers}->{$cid}->{"state"} = $hck->{computers}->{$cid}->{"confirmedstate"};
				#notify($ERRORS{'OK'}, $LOG, "basestatus check= $hck->{computers}->{$cid}->{basechecksok} setting to $hck->{computers}->{$cid}->{hostname} to $hck->{computers}->{$cid}->{confirmedstate} ") if (updatestate(0, $hck->{computers}->{$cid}->{id}, "computer", $hck->{computers}->{$cid}->{confirmedstate}, 0, $LOG));
				if (update_computer_state($hck->{computers}->{$cid}->{id}, $hck->{computers}->{$cid}->{confirmedstate})) {
					notify($ERRORS{'OK'}, $LOG, "basestatus check= $hck->{computers}->{$cid}->{basechecksok} setting to $hck->{computers}->{$cid}->{hostname} to $hck->{computers}->{$cid}->{confirmedstate} ");
				}

			} ## end if ($hck->{computers}->{$cid}->{"confirmedstate"...
		} ## end if ($hck->{computers}->{$cid}->{state} =~ ...
		if ($hck->{computers}->{$cid}->{skip}) {
			#update lastcheck time
			my $datestring = makedatestring;
			my $update_lc = $hck->{dbh}->prepare("UPDATE computer SET lastcheck=? WHERE id=?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare lastcheck time update" . $hck->{dbh}->errstr());
			$update_lc->execute($datestring, $hck->{computers}->{$cid}->{id}) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute lastcheck time update");
			$update_lc->finish;
		}
	}    #for loop
	$hck->{dbh}->disconnect;
	return 1;
} ## end sub process

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function   _valid_host
///
/// \param
///
/// \return   1,0
///
/// \brief  is this a valid host in dns
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _valid_host {
	my ($node) = @_;
	my @ns     = qw(152.1.1.22 152.1.2.22 152.1.1.161);
	my $rns    = \@ns;
	my $res = Net::DNS::Resolver->new(nameservers => $rns,
												 tcp_timeout => 5,
												 retry       => 2);
	my $q = $res->search($node);
	if ($q) {
		foreach my $rr ($q->answer) {
			next unless $rr->type eq "A";
			next unless $rr->type eq "PTR";
		}
		return 1;
	}
	else {
		return 0;
	}
} ## end sub _valid_host

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function _baseline_checks
///
/// \param
///
/// \return array - ping status(1,0),ssh status(1,0),uptime(1,0)- reboots, basestatus (1,0), failure statement
///
/// \brief  pingable, sshd, uptime
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _baseline_checks {
	my ($cidhash) = @_;
	#based on type and OS
	#ping
	#sshd
	#uptime
	# ? for unix lab machines is vclclientd running
	my @ret;
	my $node = $cidhash->{IPaddress};
	if ($cidhash->{type} eq "blade") {
		$node = $cidhash->{shortname};
	}

	# node_status
	# hashref: reference to hash with keys/values:
	#				         {status} => <"READY","FAIL">
	#					   	{ping} => <0,1>
	#					   	{ssh} => <0,1>
	#						   {rpower} => <0,1>
	#							{nodeset} => <"boot", "install", "image", ...>
	#							{nodetype} => <image name>
	#							{currentimage} => <image name>

	if ($cidhash->{type} eq "lab") {
		my $identity;
		if ($cidhash->{OSname} =~ /sun4x/) {
			$identity = $IDENTITY_solaris_lab;
		}
		elsif ($cidhash->{OSname} =~ /rhel/) {
			$identity = $IDENTITY_linux_lab;
		}
		else {
			notify($ERRORS{'OK'}, $LOG, "os $cidhash->{OSname} set but not something I can handle yet, will attempt the unix identity.");

			$identity = $IDENTITY_linux_lab;
		}

		#my @status = VCL::Module::Provisioning::Lab::node_status($cidhash->{hostname}, $cidhash->{OSname}, $cidhash->{MNos}, $cidhash->{IPaddress}, $identity, $LOG);
		my $node_status = VCL::Module::Provisioning::Lab::node_status($cidhash->{hostname}, $cidhash->{OSname}, $cidhash->{MNos}, $cidhash->{IPaddress}, $identity, $LOG);
		if ($node_status->{ping}) {
			#pingable
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{IPaddress} pingable");
			push(@ret, 1);
		}
		else {
			push(@ret, 0, 0, 0, 0, 0, "NOT pingable");
			return @ret;
		}
		#sshd
		if ($node_status->{ssh}) {
			push(@ret, 1);
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{IPaddress} ssh reponds");
		}
		else {
			push(@ret, 0, 0, 0, 0, "sshd NOT responding");
			return @ret;
		}
		#vclclientd
		if ($node_status->{vcl_client}) {
			push(@ret, 1);
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{IPaddress} vclclientd running");
		}
		else {
			push(@ret, 0, 0, 0, "vclclientd NOT running");
			return @ret;
		}
		#check_uptime ($node,$IPaddress,$OSname,$type)
		my @check_uptime_array = check_uptime($cidhash->{hostname}, $cidhash->{IPaddress}, $cidhash->{OSname}, $cidhash->{type}, $LOG);
		push(@ret, $check_uptime_array[0]);

		#if here then basechecks are ok
		push(@ret, 1);

	} ## end if ($cidhash->{type} eq "lab")
	elsif ($cidhash->{type} eq "blade") {
		#my @status = VCL::Module::Provisioning::xCAT::node_status($cidhash->{shortname}, $LOG);
		my $node_status = VCL::Module::Provisioning::xCAT::node_status($cidhash->{shortname}, $LOG);
		# First see if it returned a hashref
		if (ref($node_status) eq 'HASH') {
			notify($ERRORS{'DEBUG'}, 0, "node_status returned a hash reference");
		}

		# Check if node_status returned an array ref
		elsif (ref($node_status) eq 'ARRAY') {
			notify($ERRORS{'OK'}, $LOG, "node_status returned an array reference");

		}

		# Check if node_status didn't return a reference
		# Assume string was returned
		elsif (!ref($node_status)) {
			# Use scalar value of node_status's return value
		}

		else {
			notify($ERRORS{'OK'}, $LOG, "->node_status() returned an unsupported reference type: " . ref($node_status) . ", returning");
			return;
		}

		#host/power (pingable)
		#if ($status[1] eq "on") {
		if ($node_status->{rpower}) {
			#powered on
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{shortname} power on ");
			push(@ret, 1);
		}
		else {
			push(@ret, 0, 0, 0, 0, 0, "Powered off\n");
			return @ret;
		}
		#sshd
		#if ($status[3] eq "on") {
		if ($node_status->{ssh}) {
			push(@ret, 1);
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{shortname} ssh reponds");
		}
		else {
			push(@ret, 0, 0, 0, 0, "$cidhash->{shortname} sshd NOT responding");
			return @ret;
		}
		#imagename
		#if ($status[7]) {
		if ($node_status->{nodetype}) {
			notify($ERRORS{'OK'}, $LOG, "$cidhash->{shortname} imagename set $node_status->{nodetype}");

			if ($node_status->{currentimage}) {
				if ($node_status->{currentimage} =~ /\r/) {
					chop($node_status->{currentimage});
					#notify($ERRORS{'OK'},$LOG,"$cidhash->{shortname} imagename had carriage return $status[8]");
				}
				if ($node_status->{nodetype} =~ /$node_status->{currentimage}/) {    #do 7 & 8 match
					                                                                  #notify($ERRORS{'OK'},$LOG,"$cidhash->{shortname} nodetype matches imagename on local file");
					push(@ret, $node_status->{nodetype});
				}
				else {
					#notify($ERRORS{'OK'},$LOG,"$cidhash->{shortname} nodetype DO NOT matche imagename on remote file");
					push(@ret, "$node_status->{currentimage}");
				}
			} ## end if ($node_status->{currentimage})
			else {
				#possible linux env
				push(@ret, $node_status->{nodetype});
			}

		} ## end if ($node_status->{nodetype})
		else {
			#very strange imagename for nodetype not defined
			push(@ret, 0, 0, "imagename for nodetype not defined");
			return @ret;
		}
		#uptime not checkable yet for some blades
		#basechecks ok if made it here
		push(@ret, 0, 1);

		notify($ERRORS{'OK'}, $LOG, "$cidhash->{shortname} past basecheck flag ret = @ret");

	} ## end elsif ($cidhash->{type} eq "blade")  [ if ($cidhash->{type} eq "lab")

	return @ret;
} ## end sub _baseline_checks

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function   _reload
///
/// \param
///
/// \return array - [1,0], [string]
///
/// \brief  trys to reload the blade if needed, returns success or reason why could not be done
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _reload {
	my ($cidhash) = @_;

}

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function _imagerevision_check
///
/// \param
///
/// \return array - [1,0], [string]
///
/// \brief  checks image name and revsion number of computer id
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _imagerevision_check {
	my ($cidhash) = @_;

	if (!($MYDBH->ping)) {
		$MYDBH = getnewdbh();
	}

	my %imagerev;

	my $sel = $MYDBH->prepare(
		"SELECT ir.id,ir.imagename,ir.revision,ir.production
                          FROM imagerevision ir
                          WHERE ir.imageid = ?")                                         or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare select for imagerevision check" . $MYDBH->errstr());
	$sel->execute($cidhash->{currentimageid}) or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare select for imagerevision check" . $MYDBH->errstr());

	my $update = $MYDBH->prepare("UPDATE computer SET imagerevisionid =? WHERE id = ?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare update for correct image revision" . $MYDBH->errstr());

	my $rows = $sel->rows;
	if ($rows != 0) {
		while (my @row = $sel->fetchrow_array) {
			$imagerev{"$row[0]"}{"id"}         = $row[0];
			$imagerev{"$row[0]"}{"imagename"}  = $row[1];
			$imagerev{"$row[0]"}{"revision"}   = $row[2];
			$imagerev{"$row[0]"}{"production"} = $row[3];
			if ($row[3]) {
				#check computer version
				if ($row[0] != $cidhash->{imagerevisionid}) {
					$update->execute($row[0], $cidhash->{id}) or notify($ERRORS{'WARNING'}, $LOG, "Could not update for correct image revision" . $MYDBH->errstr());
					notify($ERRORS{'OK'}, $LOG, "imagerevisionid $cidhash->{imagerevisionid} does not match on computer id $cidhash->{id} -- setting to version $row[2] revision id $row[0]");
				}
				else {
					notify($ERRORS{'OK'}, $LOG, "imagerevision matches -- skipping update");
				}
				return 1;
			} ## end if ($row[3])
		} ## end while (my @row = $sel->fetchrow_array)
	} ## end if ($rows != 0)
	else {
		notify($ERRORS{'WARNING'}, $LOG, "imagerevision check -- no rows found for computer id $cidhash->{id}");
		return 0;
	}

} ## end sub _imagerevision_check

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function send_report
///
/// \param
///
/// \return  1,0
///
/// \brief  sends detailed report to owners of possible issues with the boxes
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub send_report {
	my ($hck) = @_;

	#notify($ERRORS{'OK'},$LOG,"$hck->{globalmsg}->{body}\n\n $hck->{globalmsg}->{failedbody}\n");
	if (defined($hck->{computercount})) {
		$hck->{globalmsg}->{body} .= "Number of nodes found for this management node $hck->{MN}: $hck->{computercount}\n";
	}
	if (defined($hck->{"computerschecked"})) {
		$hck->{globalmsg}->{body} .= "Number of nodes checked: $hck->{computerschecked}\n";
	}
	if (defined($hck->{"computersskipped"})) {
		$hck->{globalmsg}->{body} .= "Number of nodes skipped due to recent check: $hck->{computersskipped}\n";
	}
	if (defined($hck->{labnodesfailed})) {
		$hck->{globalmsg}->{body} .= "UNavailable labnodes: $hck->{labnodesfailed}\n";
	}
	if (defined($hck->{labnodesavailable})) {
		$hck->{globalmsg}->{body} .= "Available labnodes: $hck->{labnodesavailable}\n";
	}

	if (defined($hck->{globalmsg}->{correctedbody})) {
		$hck->{globalmsg}->{body} .= "\nCorrected VCL nodes:\n\n$hck->{globalmsg}->{correctedbody}\n";
	}
	if (defined($hck->{globalmsg}->{failedbody})) {
		$hck->{"globalmsg"}->{body} .= "\nProblem VCL nodes:\n\n$hck->{globalmsg}->{failedbody}\n";

	}
	if (!defined($hck->{globalmsg}->{failedbody}) && !defined($hck->{globalmsg}->{correctedbody})) {
		$hck->{globalmsg}->{body} .= "\nAll nodes report ok";

	}
	mail($SYSADMIN, "VCL node monitoring report", "$hck->{globalmsg}->{body}");
} ## end sub send_report
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
