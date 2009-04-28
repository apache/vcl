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

VCL::monitor_vcld - VCL monitoring utility

=head1 SYNOPSIS

 perl vcld

=head1 DESCRIPTION

 Needs to be written...

=cut

##############################################################################
package VCL::monitor_vcld;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../lib";

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
use Getopt::Long;

##############################################################################

sub main ();
our $LOG     = "/var/log/monitor_vcld.log";
our $STARTUP = "/etc/init.d/vcld.start";
main();


sub main () {
	my ($managementnodeid, $lci, $lastcheckin, $mnid, $selh, $updhdle, $rows, $timestamp);
	my @hostinfo       = hostname;
	my $MN             = $hostinfo[0];
	my $MNos           = $hostinfo[1];
	my $pidjuststarted = 0;

	#check if local vcld is running
	my $l;
	my $pidliving = 0;
	if (open(TEST, "$STARTUP status 2>&1 |")) {
		my @file = <TEST>;
		close(TEST);
		foreach $l (@file) {
			# Search for a line matching: vcld (pid 28560 26333 17710) is running...
			if ($l =~ /vcld \(pid [\d\s]*\) is running/) {
				$pidliving = 1;
			}
		}
	} ## end if (open(TEST, "$STARTUP status 2>&1 |"))
	if ($pidliving) {
		notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl parent pid is alive");
	}
	else {
		#restart vcld
		notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl parent pid not found, restarting on $MN");
		#on startup vcld sleep 20secs before checking in with db
		$pidjuststarted = 1;
		sleep 25;
	}

	#check on the last checkin time, if older then X, restart vcld core process

	# --- Make connection to DB
	my $dbh = DBI->connect(qq{dbi:mysql:$DATABASE:$SERVER}, $WRTUSER, $WRTPASS, {PrintError => 0});
	$selh = $dbh->prepare("SELECT id,lastcheckin FROM managementnode WHERE hostname = ?") or notify($ERRORS{'WARNING'}, $LOG, "Could not prepare select for management node id" . $dbh->errstr());
	RECHECK:
	$selh->execute($MN) or notify($ERRORS{'WARNING'}, $LOG, "Could not execute management node id" . $dbh->errstr());
	my $dbretval = $selh->bind_columns(\($managementnodeid, $lastcheckin));
	$rows = $selh->rows;
	if ($rows != 0) {
		$selh->fetch;
		$mnid = $managementnodeid;
		$lci  = $lastcheckin;
		notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl managementnodeid $managementnodeid set for $MN");
		$selh->finish;
		$dbh->disconnect;
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOG, "monitor_vcld.pl No management id for $MN.");
		$selh->finish;
		$dbh->disconnect;
		exit;
	}

	my $currenttime = makedatestring;
	my $ctime       = convert_to_epoch_seconds($currenttime);
	my $lchecktime  = convert_to_epoch_seconds($lci);
	my $diff        = $ctime - $lchecktime;
	if ($diff >= (3 * 60)) {
		notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl managementnodeid $managementnodeid checkin time is old currenttime= $currenttime lastcheckintime= $lci");
		#restart kill and start vcld
		if ($pidjuststarted) {
			$pidjuststarted = 0;
			notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl vcld was just restarted waiting a moment before check db");
			#we may not have waited long enough for a fresh checkin
			goto RECHECK;
		}
		else {
			if (open(RESTART, "$STARTUP restart 2>&1 |")) {
				my @restart = <RESTART>;
				close(RESTART);
				notify($ERRORS{'CRITICAL'}, $LOG, "monitor_vcld.pl lastcheckin is to old restarted vcld on $MN\n restart output= @restart");
			}
		}
	} ## end if ($diff >= (3 * 60))
	else {
		notify($ERRORS{'OK'}, $LOG, "monitor_vcld.pl managementnodeid $MN is fresh lastcheckintime= $lci");
	}
} ## end sub main ()


