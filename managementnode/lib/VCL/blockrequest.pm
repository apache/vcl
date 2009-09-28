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
	my $self = shift;

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

	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;

} ## end sub initialize

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
///         uses xml-rpc to call the web api to process block request
//          event
///        end mode:
///         remove machines from blockComputers table for block request id X
///         reload ?
///        expire mode:
///         delete entries related to blockRequest
///
////////////////////////////////////////////////////////////////////////////////
=cut

sub process {
	my $self = shift;
	my ($package, $filename, $line) = caller;

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

	#Set local timer
	my $localtimer = convert_to_epoch_seconds();

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

		#update processed flag for request
		if (update_blockTimes_processing($blocktime_id, 1)) {
			notify($ERRORS{'OK'}, 0, "updated process flag on blocktime_id= $blocktime_id");
		}

		my $xmlcall = process_block_time($blocktime_id);

		if ($xmlcall->{status} =~ /success/) {
			notify($ERRORS{'OK'}, 0, "success blockTimes id $blocktime_id processed and allocated $xmlcall->{allocated} nodes");
		}
		elsif ($xmlcall->{status} =~ /completed/) {
			notify($ERRORS{'OK'}, 0, "success blockTimes id $blocktime_id already processed");
		}
		elsif ($xmlcall->{status} =~ /warning/) {
			my $warningmsg  = $xmlcall->{warningmsg}  if (defined($xmlcall->{warningmsg}));
			my $allocated   = $xmlcall->{allocated}   if (defined($xmlcall->{allocated}));
			my $unallocated = $xmlcall->{unallocated} if (defined($xmlcall->{unallocated}));
			notify($ERRORS{'CRITICAL'}, 0, "xmlrpc warning: $warningmsg allocated= $allocated unallocated= $unallocated");
		}
		elsif ($xmlcall->{status} =~ /error/) {
			my $errormsg = $xmlcall->{errormsg} if (defined($xmlcall->{errormsg}));
			notify($ERRORS{'CRITICAL'}, 0, "xmlrpc error on blockrequest_id=$blockrequest_id blocktime_id=$blocktime_id : $errormsg");
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "xmlrpc status unknown status=  $xmlcall->{status} blockrequest_id=$blockrequest_id blocktime_id=$blocktime_id");
		}

		#pause
		if (pauseprocessing($localtimer)) {
			notify($ERRORS{'OK'}, 0, "past check window for this request, -- ok to proceed");
		}

		if (update_blockrequest_processing($blockrequest_id, 0)) {
			notify($ERRORS{'OK'}, 0, "Removed processing flag on blockrequest_id $blockrequest_id");
		}

	} ## end if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "end") {
		# remove blockTime entry for this request
		if (clear_blockComputers($blocktime_id)) {
			notify($ERRORS{'OK'}, 0, "Removed computers from blockComputers table for blocktime_id=$blocktime_id");
		}
		if (clear_blockTimes($blocktime_id)) {
			notify($ERRORS{'OK'}, 0, "Removed blocktime_id=$blocktime_id from blockTimes table");
		}

		#check expire time, if this was the last blockTimes entry then this is likely the expiration time as well
		my $status = check_blockrequest_time($blocktime_start, $blocktime_end, $blockrequest_expire);
		if ($status eq "expire") {
			#fork start processing
			notify($ERRORS{'OK'}, 0, "Block Request $blockrequest_id has expired");
			if (delete_block_request($blockrequest_id)) {
				notify($ERRORS{'OK'}, 0, "Removed blockRequest id $blockrequest_id");
			}
			return 1;
		}

		##remove processing flag
		if (update_blockrequest_processing($blockrequest_id, 0)) {
			notify($ERRORS{'OK'}, 0, "Removed processing flag on blockrequest_id $blockrequest_id");
		}

	} ## end elsif ($blockrequest_mode eq "end")  [ if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "expire") {
		notify($ERRORS{'OK'}, 0, "Block Request $blockrequest_id has expired");
		if (delete_block_request($blockrequest_id)) {
			notify($ERRORS{'OK'}, 0, "Removed blockRequest id $blockrequest_id");
		}
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

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
