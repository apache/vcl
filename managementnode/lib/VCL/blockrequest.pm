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
# $Id$
##############################################################################

=head1 NAME

VCL::blockrequest

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for...

=cut

##############################################################################
package VCL::blockrequest;

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
use English '-no_match_vars';

use VCL::utils;
use DBI;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  : Reference to current inuse object is automatically passed when
               invoked as a class method.
 Returns     : 1 if successful, 0 otherwise
 Description : Prepares the delete object to process a reservation. Renames the
               process.

=cut

sub initialize {
	my $self                    = shift;

	# Initialize the database handle count
	$ENV{dbh_count} = 0;

	# Attempt to get a database handle
	if ($ENV{dbh} = getnewdbh()) {
		notify($ERRORS{'OK'}, 0, "obtained a database handle for this state process, stored as \$ENV{dbh}");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain a database handle for this state process");
	}


	# Store the name of this class in an environment variable
	$ENV{class_name} = ref($self);

	# Rename this process to include some request info
	rename_vcld_process($self->data);

	# Call the old _initialize subroutine
	if (!$self->_initialize()) {
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub initialize

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn function _initialize
///
/// \param hash data structure of the referenced object
///
/// \return
///
/// \brief  collects data based this modules goals, sets up data structure
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub _initialize {
	my $self    = shift;
	my $request = $self->data->get_blockrequest_data();
	my ($package, $filename, $line) = caller;

	# Create a new database handler
	my $dbh = getnewdbh();

	# Retrieve data from the data structure
	my $blockrequest_id              = $self->data->get_blockrequest_id();
	my $blockrequest_mode            = $self->data->get_blockrequest_mode();
	my $blockrequest_image_id        = $self->data->get_blockrequest_image_id();
	my $blockrequest_number_machines = $self->data->get_blockrequest_number_machines();
	my $blockrequest_expire          = $self->data->get_blockrequest_expire();
	my $blocktime_id                 = $self->data->get_blocktime_id();
	my $blocktime_processed          = $self->data->get_blocktime_processed();
	my $blocktime_start              = $self->data->get_blocktime_start();
	my $blocktime_end                = $self->data->get_blocktime_end();

	notify($ERRORS{'DEBUG'}, 0, "blockrequest id: $blockrequest_id");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest mode: $blockrequest_mode");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest image id: $blockrequest_image_id");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest number machines: $blockrequest_number_machines");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest expire: $blockrequest_expire");
	notify($ERRORS{'DEBUG'}, 0, "blocktime id: $blocktime_id");
	notify($ERRORS{'DEBUG'}, 0, "blocktime processed: $blocktime_processed");
	notify($ERRORS{'DEBUG'}, 0, "blocktime start: $blocktime_start");
	notify($ERRORS{'DEBUG'}, 0, "blocktime end: $blocktime_end");

	sleep 2;

	#record my process start time
	$request->{"myprocessStart"} = convert_to_epoch_seconds();


	# active db handle ?
	if (!($dbh->ping)) {
		notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
		$dbh = getnewdbh();
		notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
		notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
	}

	#get the production imagerevision
	my $imageselh = $dbh->prepare(
		"SELECT ir.imagename,ir.id
                                              FROM imagerevision ir
                                              WHERE ir.production = 1 AND ir.imageid = ?") or notify($ERRORS{'WARNING'}, 0, "block request Could not prepare selecting production image from imagerevision" . $dbh->errstr());

	$imageselh->execute($blockrequest_image_id) or notify($ERRORS{'WARNING'}, 0, "block request Could not execute selecting production image from imagerevision " . $dbh->errstr());
	my $imagerows = $imageselh->rows;
	my @imagerow;
	if ($imagerows != 0) {
		@imagerow                     = $imageselh->fetchrow_array;
		$request->{"imagename"}       = $imagerow[0];
		$request->{"imagerevisionid"} = $imagerow[1];
		notify($ERRORS{'OK'}, 0, "collected production imagename imagerevisionid @imagerow $blockrequest_image_id");
	}
	else {
		#warning no data for imageid
		notify($ERRORS{'CRITICAL'}, 0, "no data from imagerevision table $blockrequest_image_id");
		#preform more steps to prevent looping
		return 0;
	}

	if ($blockrequest_mode eq "start") {
		# find all nodes that can load/run requested image including those under other management nodes
		# collect resourceid for this imageid
		my $selh = $dbh->prepare(
			"SELECT r.id
                                            FROM resource r, resourcetype rt
                                            WHERE r.resourcetypeid = rt.id AND rt.name = ? AND r.subid = ?") or notify($ERRORS{'WARNING'}, 0, "block request Could not prepare select imageid resourceid" . $dbh->errstr());
		$selh->execute("image", $blockrequest_image_id) or notify($ERRORS{'WARNING'}, 0, "block request Could not execute select imageid resourceid" . $dbh->errstr());
		my $rows = $selh->rows;
		my @row;
		if ($rows != 0) {
			@row = $selh->fetchrow_array;
			$request->{"imageresourceid"} = $row[0];
			notify($ERRORS{'OK'}, 0, "collected resourceid $row[0] for imageid $blockrequest_image_id");
		}
		else {
			#warning no data for imageid
			notify($ERRORS{'CRITICAL'}, 0, "no resource id associated with imageid $blockrequest_image_id");
			#preform more steps to prevent looping
			return 0;
		}
		# collect resource groups this image is a member of
		$selh = $dbh->prepare(
			"SELECT resourcegroupid
                                          FROM resourcegroupmembers
                                         WHERE resourceid = ?")                                           or notify($ERRORS{'WARNING'}, 0, "Could not prepare select resource group membership resourceid" . $dbh->errstr());
		$selh->execute($request->{imageresourceid}) or notify($ERRORS{'WARNING'}, 0, "Could not execute select resource group membership resourceid" . $dbh->errstr());
		$rows = $selh->rows;
		if ($rows != 0) {
			while (@row = $selh->fetchrow_array) {
				push(@{$request->{resourcegroups}}, $row[0]);
				notify($ERRORS{'OK'}, 0, "pushing image resource group $row[0] on list");
			}
			notify($ERRORS{'OK'}, 0, "complete list of image resource groups @{ $request->{resourcegroups} }");
		}
		else {
			#warning no data for imageid
			notify($ERRORS{'CRITICAL'}, 0, "image resource id $request->{imageresourceid} is not in any groups");
			#preform more steps to prevent looping
			return 0;
		}

		# active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}

		#find mapping between image resource groups and computer groups
		$selh = $dbh->prepare(
			"SELECT r.resourcegroupid2,r.resourcetypeid2
                                             FROM resourcemap r, resourcetype rt
                                             WHERE r.resourcetypeid1 = rt.id AND rt.name = ? AND r.resourcegroupid1 = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare resource to computer group mapping" . $dbh->errstr());
		foreach my $rgroupid (@{$request->{resourcegroups}}) {
			notify($ERRORS{'OK'}, 0, "fetching list of groups mapped to image resource group $rgroupid");
			$selh->execute("image", $rgroupid) or notify($ERRORS{'WARNING'}, 0, "Could not execute select resource group membership resourceid" . $dbh->errstr());
			$rows = $selh->rows;
			if ($rows != 0) {
				while (@row = $selh->fetchrow_array) {
					$request->{"computergroups"}->{$row[0]}->{"resourceid"}     = $row[0];
					$request->{"computergroups"}->{$row[0]}->{"resourcetypeid"} = $row[1];
					notify($ERRORS{'OK'}, 0, "computer group= $row[0] can run image grpid= $rgroupid");
				}
			}
			else {
				#warning no data for mapped resources on resourcegroupid
				notify($ERRORS{'WARNING'}, 0, "no computer groups found for image resource groupid $rgroupid");
				#preform more steps to prevent looping
				#check next one

			}
		} ## end foreach my $rgroupid (@{$request->{resourcegroups...
		    # active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}
		#who(Management Node) can control these computer group(s)
		$selh = $dbh->prepare(
			"SELECT rg.resourceid
                                          FROM resourcemap rm, resourcegroupmembers rg, resourcetype rt
                                          WHERE rg.resourcegroupid = rm.resourcegroupid1 AND rm.resourcetypeid1 = rt.id AND rt.name = ? AND rm.resourcegroupid2 = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare managment node owner of computer group" . $dbh->errstr());
		#seperating statement about management node information
		my $selhmn = $dbh->prepare(
			"SELECT r.subid,m.IPaddress,m.hostname,m.ownerid,s.name,m.lastcheckin
                                                FROM resource r,managementnode m,resourcetype rt,state s
                                              WHERE m.id = r.subid AND r.resourcetypeid = rt.id AND s.id = m.stateid AND rt.name = ? AND r.id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare managment node info statement" . $dbh->errstr());

		foreach my $computergrpid (keys %{$request->{computergroups}}) {
			$selh->execute("managementnode", $computergrpid) or notify($ERRORS{'WARNING'}, 0, "Could not execute select resource group membership resourceid" . $dbh->errstr());
			$rows = $selh->rows;
			if ($rows != 0) {
				while (@row = $selh->fetchrow_array) {
					$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$row[0]}->{"resourceid"} = $row[0];
					notify($ERRORS{'OK'}, 0, "management node resourceid @row can control this computer grp $computergrpid");
					$selhmn->execute("managementnode", $row[0]) or notify($ERRORS{'WARNING'}, 0, "Could not execute select management node info" . $dbh->errstr());
					my $mrows = $selhmn->rows;
					if ($mrows != 0) {
						while (my @mrow = $selhmn->fetchrow_array) {
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"IPaddress"}        = $mrow[1];
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"hostname"}         = $mrow[2];
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"ownerid"}          = $mrow[3];
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"state"}            = $mrow[4];
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"lastcheckin"}      = $mrow[5];
							$request->{"computergroups"}->{$computergrpid}->{"controllingmnids"}->{$mrow[0]}->{"managementnodeid"} = $mrow[0];
							notify($ERRORS{'OK'}, 0, "management node $mrow[2] can control computergroup $computergrpid");
						}
					} ## end if ($mrows != 0)
					else {
						#warning no data for mapped resources on resourcegroupid
						notify($ERRORS{'CRITICAL'}, 0, "no management nodes listed controlling computer groupid $row[0] skipping this group");
						#preform more steps to prevent looping
					}
				} ## end while (@row = $selh->fetchrow_array)
			} ## end if ($rows != 0)
			else {
				#warning no data for mapped resources on resourcegroupid
				notify($ERRORS{'CRITICAL'}, 0, "no management nodes listed to control computer group id $computergrpid, attempting to remove from our local hash");
				#preform more steps to prevent looping
				#delete computergroupid from hash
				delete($request->{computergroups}->{$computergrpid});
				if (!(exists($request->{computergroups}->{$computergrpid}))) {
					notify($ERRORS{'OK'}, 0, "SUCCESSFULLY removed problem computer groupid from list");
				}
			} ## end else [ if ($rows != 0)
		} ## end foreach my $computergrpid (keys %{$request->{computergroups...
		    # active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}
		#collect computer members of associated computer groups
		$selh = $dbh->prepare(
			"SELECT c.id,c.hostname,c.IPaddress,s.name,c.currentimageid,c.type
                                          FROM resourcetype rt, resource r,resourcegroupmembers rg,computer c,state s
                                         WHERE s.id = c.stateid AND rg.resourceid = r.id AND r.subid = c.id AND r.resourcetypeid = rt.id AND rt.name = ? AND rg.resourcegroupid = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement collect members of related computer groups" . $dbh->errstr());

		#collect list of computers already in the blockcomputers table for this start time
		my $bcselh = $dbh->prepare(
			"SELECT bc.computerid FROM blockComputers bc, blockTimes bt
                                          WHERE bc.blockTimeid = bt.id AND bt.id != ? AND bt.start < ? AND bt.end > ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement collect members of related computer groups" . $dbh->errstr());
		$bcselh->execute($blocktime_id, $blocktime_end, $blocktime_start) or notify($ERRORS{'WARNING'}, 0, "Could not execute blockcomputer lookup " . $dbh->errstr());
		my $bcrows = $bcselh->rows;
		if ($bcrows != 0) {
			my @bclist;
			while (@bclist = $bcselh->fetchrow_array) {
				$request->{"blockcomputerslist"}->{$bclist[0]} = 1;
			}
		}

		#collect OSname for image id
		my $selhOS = $dbh->prepare(
			"SELECT o.name FROM OS o,image i
                                              WHERE i.id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement for OS " . $dbh->errstr());
		#sort through list of computers
		foreach my $grpid (keys %{$request->{computergroups}}) {
			$selh->execute("computer", $grpid) or notify($ERRORS{'WARNING'}, 0, "Could not execute select computer members of group ids" . $dbh->errstr());
			$rows = $selh->rows;
			if ($rows != 0) {
				while (@row = $selh->fetchrow_array) {
					$request->{"computergroups"}->{computercount}++;
					$request->{"computergroups"}->{$grpid}->{"members"}->{$row[0]}->{"id"}        = $row[0];
					$request->{"computergroups"}->{$grpid}->{"members"}->{$row[0]}->{"hostname"}  = $row[1];
					$request->{"computergroups"}->{$grpid}->{"members"}->{$row[0]}->{"IPaddress"} = $row[2];
					$request->{"computergroups"}->{$grpid}->{"members"}->{$row[0]}->{"state"}     = $row[3];
					if (exists($request->{"blockcomputerslist"}->{$row[0]})) {
						notify($ERRORS{'OK'}, 0, "computer id $row[0] hostname $row[1] is in another block reservation");
						$row[3] = "inuse";
						$request->{"computergroups"}->{$grpid}->{"members"}->{$row[0]}->{"state"} = $row[3];
					}
					if ($row[3] eq "available") {
						notify($ERRORS{'OK'}, 0, "available machineid $row[0] hostname $row[1]");
						$request->{"availablemachines"}->{$row[0]}->{"id"}             = $row[0];
						$request->{"availablemachines"}->{$row[0]}->{"hostname"}       = $row[1];
						$request->{"availablemachines"}->{$row[0]}->{"IPaddress"}      = $row[2];
						$request->{"availablemachines"}->{$row[0]}->{"state"}          = $row[3];
						$request->{"availablemachines"}->{$row[0]}->{"currentimageid"} = $row[4];
						$request->{"availablemachines"}->{$row[0]}->{"type"}           = $row[5];
						$request->{"availablemachines"}->{$row[0]}->{"shortname"}      = $1 if ($row[1] =~ /([-_a-zA-Z0-9]*)\./);
						#which management node should handle this -- in case there are more than one
						my $mncount = 0;
						foreach my $mnid (keys %{$request->{computergroups}->{$grpid}->{controllingmnids}}) {
							if ($request->{computergroups}->{$grpid}->{controllingmnids}->{$mnid}->{managementnodeid}) {
								$mncount++;
								notify($ERRORS{'OK'}, 0, "setting MN to $request->{computergroups}->{$grpid}->{controllingmnids}->{$mnid}->{managementnodeid} for computerid $row[0]");
								$request->{"availablemachines"}->{$row[0]}->{"managementnodeid"} = $request->{computergroups}->{$grpid}->{controllingmnids}->{$mnid}->{managementnodeid};

								if ($mncount > 1) {
									#need to figure out which one has less load
								}
							}
						} ## end foreach my $mnid (keys %{$request->{computergroups...

						if ($row[4] eq $blockrequest_image_id) {
							push(@{$request->{preloadedlist}}, $row[0]);
							$request->{"availablemachines"}->{$row[0]}->{"preloaded"} = 1;
						}
						else {
							$request->{"availablemachines"}->{$row[0]}->{"preloaded"} = 0;
						}
						if ($row[5] =~ /lab/) {
							$selhOS->execute($row[4]) or notify($ERRORS{'WARNING'}, 0, "Could not execute statement to collect OS info" . $dbh->errstr());
							my $OS;
							my $dbretval = $selhOS->bind_columns(\($OS));
							if ($selhOS->fetch) {
								$request->{"availablemachines"}->{$row[0]}->{"OS"} = $OS;
							}
						}
					} ## end if ($row[3] eq "available")
				} ## end while (@row = $selh->fetchrow_array)
			} ## end if ($rows != 0)
			else {
				notify($ERRORS{'WARNING'}, 0, "possible empty group for groupid $grpid");
			}
		} ## end foreach my $grpid (keys %{$request->{computergroups...
		    #collect id for reload state and vclreload user
		$selh = $dbh->prepare("SELECT s.id,u.id FROM state s,user u WHERE s.name= ? AND u.unityid=?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement to find reload state" . $dbh->errstr());
		$selh->execute("reload", "vclreload") or notify($ERRORS{'WARNING'}, 0, "Could not execute reload stateid fetch" . $dbh->errstr());
		$rows = $selh->rows;
		if ($rows != 0) {
			if (@row = $selh->fetchrow_array) {
				$request->{"reloadstateid"} = $row[0];
				$request->{"vclreloaduid"}  = $row[1];
			}
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "reload state id or vclreload user id not found");
		}
	} ## end if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "end") {
		#collect machines assigned for this blockRequest
		my $selhandle = $dbh->prepare("SELECT computerid FROM blockComputers WHERE blockTimeid = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement to collect computerids under blockTimesid" . $dbh->errstr());
		$selhandle->execute($blocktime_id);
		if (!$dbh->err) {
			notify($ERRORS{'OK'}, 0, "collected computer ids for block time $blocktime_id");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "could not execute statement collect computerid under blockTimesid" . $dbh->errstr());
		}

		my $rows = $selhandle->rows;
		if (!$rows == 0) {
			while (my @row = $selhandle->fetchrow_array) {
				$request->{"blockComputers"}->{$row[0]}->{"id"} = $row[0];
			}
		}
		else {
			#strange -- no machines
			notify($ERRORS{'WARNING'}, 0, "mode= $blockrequest_mode no machines found for blockRequest $blockrequest_id blockTimesid $blocktime_id in blockTimes table");
		}
	} ## end elsif ($blockrequest_mode eq "end")  [ if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "expire") {
		#just remove request entry from table

	}
	else {
		#mode not set or mode
		notify($ERRORS{'CRITICAL'}, 0, "mode not determined mode= $blockrequest_mode");
	}

	return 1;
} ## end sub _initialize

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn sub process
///
/// \param  hash
///
/// \return  1, 0
///
/// \brief start mode:
///         sorts through list of computers, pull out machines that are not
///         available or are inuse or already scheduled to be used
///         based on the number of machines needed put machines into blockcomputers
///         table and insert reload requests
///        end mode:
///         remove machines from blockComputers table for block request id X
///         reload ?
///        expire mode:
///         delete entries related to blockRequest
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub process {
	my $self    = shift;
	my $request = $self->data->get_blockrequest_data();
	my ($package, $filename, $line) = caller;

	# Create a new database handler
	my $dbh = getnewdbh();

	# Retrieve data from the data structure
	my $blockrequest_id              = $self->data->get_blockrequest_id();
	my $blockrequest_mode            = $self->data->get_blockrequest_mode();
	my $blockrequest_image_id        = $self->data->get_blockrequest_image_id();
	my $blockrequest_number_machines = $self->data->get_blockrequest_number_machines();
	my $blockrequest_expire          = $self->data->get_blockrequest_expire();
	my $blocktime_id                 = $self->data->get_blocktime_id();
	my $blocktime_processed          = $self->data->get_blocktime_processed();
	my $blocktime_start              = $self->data->get_blocktime_start();
	my $blocktime_end                = $self->data->get_blocktime_end();

	notify($ERRORS{'DEBUG'}, 0, "blockrequest id: $blockrequest_id");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest mode: $blockrequest_mode");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest image id: $blockrequest_image_id");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest number machines: $blockrequest_number_machines");
	notify($ERRORS{'DEBUG'}, 0, "blockrequest expire: $blockrequest_expire");
	notify($ERRORS{'DEBUG'}, 0, "blocktime id: $blocktime_id");
	notify($ERRORS{'DEBUG'}, 0, "blocktime processed: $blocktime_processed");
	notify($ERRORS{'DEBUG'}, 0, "blocktime start: $blocktime_start");
	notify($ERRORS{'DEBUG'}, 0, "blocktime end: $blocktime_end");

	if ($blockrequest_mode eq "start") {
		#confirm preloaded list
		if ($blocktime_processed) {

			notify($ERRORS{'WARNING'}, 0, "id $blockrequest_id has already been processed, pausing 60 seconds before reseting the processing flag");
			##remove processing flag
			sleep 60;
			my $updatehdle = $dbh->prepare("UPDATE blockRequest SET processing = ? WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare update processing statement for end mode" . $dbh->errstr());
			$updatehdle->execute(0, $blockrequest_id) or notify($ERRORS{'WARNING'}, 0, "Could not execute update processing statement for end mode" . $dbh->errstr());
			notify($ERRORS{'OK'}, 0, "removed processing flag from blockrequest id $blockrequest_id");
			return 1;
		} ## end if ($blocktime_processed)
		$request->{"availmachinecount"} = 0;
		# active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}

		my $selh = $dbh->prepare(
			"SELECT r.id,r.start,r.end,s.name
                                            FROM request r, reservation rs, state s
                                            WHERE r.stateid = s.id AND rs.computerid = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare statement for furture reservations checks of computer id " . $dbh->errstr());
		#sort hash based on preloaded flag
		foreach my $computerid (sort {$request->{availablemachines}->{$b}->{preloaded} eq '1'} keys %{$request->{availablemachines}}) {
			#confirm status of available machines
			notify($ERRORS{'OK'}, 0, "$computerid preload flag= $request->{availablemachines}->{$computerid}->{preloaded}");

			#can only check the machines under this MN control
			$request->{availablemachines}->{$computerid}->{"ok"} = 0;
			my @status;
			if ($request->{availablemachines}->{$computerid}->{type} =~ /blade/) {
				$request->{availablemachines}->{$computerid}->{"on"} = 1;
			}
			elsif ($request->{availablemachines}->{$computerid}->{type} =~ /lab/) {
				@status = virtual_status_unix($request->{availablemachines}->{$computerid}->{hostname}, $request->{availablemachines}->{$computerid}->{OS}, "linux", $request->{availablemachines}->{$computerid}->{IPaddress});
				if ($status[2]) {
					$request->{availablemachines}->{$computerid}->{"on"} = 1;
				}
			}
			elsif ($request->{availablemachines}->{$computerid}->{type} =~ /virtualmachine/) {
				$request->{availablemachines}->{$computerid}->{"on"} = 1;
			}
			notify($ERRORS{'OK'}, 0, "checking for future reservations for computerid $computerid");
			#check for future reservations
			$selh->execute($computerid) or notify($ERRORS{'WARNING'}, 0, "Could not execute statement for furture reservations checks of computer id $computerid" . $dbh->errstr());
			my $rows = $selh->rows;
			if (!$rows == 0) {
				my @row = $selh->fetchrow_array;
				#does blockrequest end time end before this reservations start time
				if ($row[3] =~ /new/) {
					my $furture_start = convert_to_epoch_seconds($row[1]);
					my $BRend         = convert_to_epoch_seconds($blocktime_end);
					#is start greater than end by at least 35 minutes -- to be safe?
					if ((($furture_start - (35 * 60)) > $BRend)) {
						#this one is ok
						$request->{availablemachines}->{$computerid}->{"ok"} = 1;
						notify($ERRORS{'OK'}, 0, "setting ok flag for computerid $computerid");
					}
					else {
						notify($ERRORS{'OK'}, 0, "$computerid not ok to use deleting from hash");
						my $d = ($furture_start - (35 * 60));
						notify($ERRORS{'OK'}, 0, "furture_start $furture_start : BRend $BRend : delta $d");
						#skip and remove from our list
						#my $a = delete($request->{availablemachines}->{$computerid});
						#next;
						$request->{availablemachines}->{$computerid}->{"ok"} = 0;
					}
				} ## end if ($row[3] =~ /new/)
				else {
					$request->{availablemachines}->{$computerid}->{"ok"} = 0;
					notify($ERRORS{'OK'}, 0, "NOT setting ok flag for computerid $computerid : listed in request $row[0] with state $row[3]");
				}
			} ## end if (!$rows == 0)
			else {
				#nothing scheduled for this computer id
				$request->{availablemachines}->{$computerid}->{"ok"} = 1;
				notify($ERRORS{'OK'}, 0, " setting ok flag for computerid $computerid");
			}

			if ($request->{availablemachines}->{$computerid}->{on} && $request->{availablemachines}->{$computerid}->{ok}) {
				# add to our master list
				$request->{"masterlist"}->{$computerid}->{"id"}              = $computerid;
				$request->{"masterlist"}->{$computerid}->{"controllingMNid"} = $request->{availablemachines}->{$computerid}->{managementnodeid};
				#increment our count
				$request->{availmachinecount}++;
			}

			if ($request->{availmachinecount} > $blockrequest_number_machines) {
				#should end up with one extra machine
				last;
			}

		} ## end foreach my $computerid (sort {$request->{availablemachines...

		#insert machines into Block computers
		# insert reload request for machine
		#one sanity check
		if (!$request->{availmachinecount}) {
			#nothing  -- not good, complain
			notify($ERRORS{'CRITICAL'}, 0, "no machines where found or allocated for block request $blockrequest_id");

		}
		if ($request->{availmachinecount} >= $blockrequest_number_machines) {
			#good they can get what they requested
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "Could not allocate number of requested machines for block request id $blockrequest_id . Only $request->{availmachinecount} are available, will give them those.");
		}
		# active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}
		my $insertBC = $dbh->prepare("INSERT INTO blockComputers (blockTimeid,computerid) VALUES(?,?)") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of blockcomputer table for start mode" . $dbh->errstr());

		my $insertlog = $dbh->prepare("INSERT INTO log (userid,start,initialend,wasavailable,computerid,imageid) VALUES(?,?,?,?,?,?)") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT log entry " . $dbh->errstr());
		my $lastinsertid;
		my $insertsublog = $dbh->prepare("INSERT INTO sublog (logid,imageid,computerid) VALUES(?,?,?)") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of sublog for reload mode" . $dbh->errstr());

		my $insertrequest     = $dbh->prepare("INSERT INTO request (stateid,userid,laststateid,logid,start,end,daterequested) VALUES(?,?,?,?,?,?,?)")       or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of request for reload mode" . $dbh->errstr());
		my $insertreservation = $dbh->prepare("INSERT INTO reservation (requestid,computerid,imageid,imagerevisionid,managementnodeid) VALUES (?,?,?,?,?)") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of reservation for reload mode" . $dbh->errstr());


		# $request->masterlist should contain a list of machines we can allocate
		notify($ERRORS{'OK'}, 0, "number of available machines= $request->{availmachinecount}");

		#do this in two or more loops
		foreach my $computerid (keys %{$request->{masterlist}}) {
			$insertBC->execute($blocktime_id, $request->{masterlist}->{$computerid}->{id}) or notify($ERRORS{'WARNING'}, 0, "Could not execute blockcomputers INSERT statement for computerid $computerid under blockrequest id $blockrequest_id" . $dbh->errstr());
			notify($ERRORS{'OK'}, 0, "Inserted computerid $computerid blockTimesid $blocktime_id into blockcomputers table for block request $blockrequest_id");
		}

		foreach my $compid (keys %{$request->{masterlist}}) {
			# set start to be 35 minutes prior to start time
			# convert to epoch time
			my $starttimeepoch = convert_to_epoch_seconds($blocktime_start);
			#subtract 35 minutes from start time
			$starttimeepoch = ($starttimeepoch - (35 * 60));
			#convert back to datetime
			my $starttime = convert_to_datetime($starttimeepoch);
			#set to nearest 15 minute mark
			my $start = timefloor15interval($starttime);
			#set end time
			my $Eend = ($starttimeepoch + (15 * 60));
			my $end = convert_to_datetime($Eend);
			notify($ERRORS{'OK'}, 0, "blockstart= $blocktime_start reloadstart= $start reloadend= $end");
			#insert into log and sublog
			$insertlog->execute($request->{vclreloaduid}, $start, $end, 1, $compid, $blockrequest_image_id) or notify($ERRORS{'WARNING'}, 0, "Could not execute log entry" . $dbh->errstr());
			#get last insertid
			$lastinsertid = $dbh->{'mysql_insertid'};
			notify($ERRORS{'OK'}, 0, "lastinsertid for log entry is $lastinsertid");
			$request->{masterlist}->{$compid}->{"logid"} = $lastinsertid;
			#insert sublog entry
			$insertsublog->execute($lastinsertid, $blockrequest_image_id, $request->{masterlist}->{$compid}->{id}) or notify($ERRORS{'WARNING'}, 0, "Could not execute sublog entry" . $dbh->errstr());
			$lastinsertid = 0;
			#insert reload request
			$insertrequest->execute($request->{reloadstateid}, $request->{vclreloaduid}, $request->{reloadstateid}, $request->{masterlist}->{$compid}->{logid}, $start, $end, $start) or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of request for reload mode" . $dbh->errstr());
			#fetch request insert id
			$lastinsertid = $dbh->{'mysql_insertid'};
			notify($ERRORS{'OK'}, 0, "lastinsertid for request entry is $lastinsertid");
			$request->{masterlist}->{$compid}->{"requestid"} = $lastinsertid;
			#insert reservation
			$insertreservation->execute($lastinsertid, $request->{masterlist}->{$compid}->{id}, $blockrequest_image_id, $request->{imagerevisionid}, $request->{masterlist}->{$compid}->{controllingMNid}) or notify($ERRORS{'WARNING'}, 0, "Could not execute reservation entry" . $dbh->errstr());
		} ## end foreach my $compid (keys %{$request->{masterlist...

		#update processed flag for request
		my $updatetimes = $dbh->prepare("UPDATE blockTimes SET processed=? WHERE id =?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of blockcomputer table for start mode " . $dbh->errstr());
		$updatetimes->execute(1, $blocktime_id) or notify($ERRORS{'WARNING'}, 0, "could not execute update processing flag on blockRequest id $blockrequest_id " . $dbh->errstr());


		#pause
		if (pauseprocessing($request->{myprocessStart})) {
			notify($ERRORS{'OK'}, 0, "past check window for this request, -- ok to proceed");
		}
		# active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}

		#remove processing flag
		my $update = $dbh->prepare("UPDATE blockRequest SET processing = ? WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare INSERT of blockcomputer table for start mode " . $dbh->errstr());
		$update->execute(0, $blockrequest_id);
		if (!$dbh->errstr()) {
			notify($ERRORS{'OK'}, 0, "updated processing flag on blockRequest $blockrequest_id to 0");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to update processing flag on blockRequest $blockrequest_id to 0: " . $dbh->errstr());
		}

	} ## end if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "end") {
		# active db handle ?
		if (!($dbh->ping)) {
			notify($ERRORS{'WARNING'}, 0, "database handle died, trying to create another one");
			$dbh = getnewdbh();
			notify($ERRORS{'OK'},      0, "database handle re-est")     if ($dbh->ping);
			notify($ERRORS{'WARNING'}, 0, "database handle NOT re-set") if (!($dbh->ping));
		}

		# remove blockTime entry for this request
		#
		my $delhandle = $dbh->prepare("DELETE blockTimes FROM blockTimes WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockTimes under id $blockrequest_id" . $dbh->errstr());
		$delhandle->execute($blocktime_id) or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockcomputers under id $blockrequest_id" . $dbh->errstr());
		notify($ERRORS{'OK'}, 0, "removed blockTimes id $blocktime_id from blockTimes table");

		$delhandle = $dbh->prepare("DELETE blockComputers FROM blockComputers WHERE blockTimeid = ? AND computerid = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockcomputers under id $blockrequest_id" . $dbh->errstr());
		# remove each computer in order to reload blades
		foreach my $computerid (keys %{$request->{"blockComputers"}}) {
			#remove machines from blockComputers table for block request id X
			$delhandle->execute($blocktime_id, $request->{blockComputers}->{$computerid}->{id}) or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockcomputers under id $blockrequest_id" . $dbh->errstr());
			notify($ERRORS{'OK'}, 0, "removed block computerid $computerid from blockComputers table for blockTimeid $blocktime_id");

			#reload blades
			#call get next image -- placeholder

		}
		#check expire time also, if this was the last blockTimes entry then this is likely the expiration time as well
		my $status = check_blockrequest_time($blocktime_start, $blocktime_end, $blockrequest_expire);
		if ($status eq "expire") {
			#fork start processing
			notify($ERRORS{'OK'}, 0, "this is expire time also");
			#just remove blockRequest entry from BlockRequest table
			my $delhandle = $dbh->prepare("DELETE blockRequest FROM blockRequest WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockRequest id $blockrequest_id " . $dbh->errstr());
			$delhandle->execute($blockrequest_id) or notify($ERRORS{'WARNING'}, 0, "Could not execute DELETE blcokRequest id $blockrequest_id " . $dbh->errstr());
			notify($ERRORS{'OK'}, 0, "blockRequest id $blockrequest_id has expired and was removed from the database");
			return 1;
		}

		##remove processing flag
		my $updatehdle = $dbh->prepare("UPDATE blockRequest SET processing = ? WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare update processing statement for end mode" . $dbh->errstr());
		$updatehdle->execute(0, $blockrequest_id) or notify($ERRORS{'WARNING'}, 0, "Could not execute update processing statement for end mode" . $dbh->errstr());
		notify($ERRORS{'OK'}, 0, "removed processing flag from blockrequest id $blockrequest_id");

	} ## end elsif ($blockrequest_mode eq "end")  [ if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "expire") {
		#there should not be any blockTimes entries for this request
		#just remove blockRequest entry from BlockRequest table
		my $delhandle = $dbh->prepare("DELETE blockRequest FROM blockRequest WHERE id = ?") or notify($ERRORS{'WARNING'}, 0, "Could not prepare DELETE blockRequest id $blockrequest_id " . $dbh->errstr());
		$delhandle->execute($blockrequest_id) or notify($ERRORS{'WARNING'}, 0, "Could not execute DELETE blcokRequest id $blockrequest_id " . $dbh->errstr());
		notify($ERRORS{'OK'}, 0, "blockRequest id $blockrequest_id has expired and was removed from the database");
		return 1;
	}
	else {
		#should not of hit this
		notify($ERRORS{'CRITICAL'}, 0, "mode not determined mode= $blockrequest_mode");
	}
	return 1;

} ## end sub process

=pod
////////////////////////////////////////////////////////////////////////////////
///
/// \fn sub pauseprocessing
///
/// \param  process start time
///
/// \return  1, 0
///
/// \brief rest until our window for checking request has closed
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub pauseprocessing {
	my $myStartTime = shift;
	# set timer to 8 minutes
	my $wait_minutes = (8 * 60);
	my $delta        = (convert_to_epoch_seconds() - $myStartTime);
	while ($delta < $wait_minutes) {
		#continue to loop
		notify($ERRORS{'OK'}, 0, "going to sleep for 30 seconds, delta=$delta (until delta >= $wait_minutes)");
		sleep 30;
		$delta = (convert_to_epoch_seconds() - $myStartTime);
	}
	return 1;
} ## end sub pauseprocessing
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


