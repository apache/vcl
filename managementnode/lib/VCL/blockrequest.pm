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

###############################################################################
package VCL::blockrequest;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw(VCL::Module::State);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use VCL::utils;
use DBI;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	my $blockrequest_name            = $self->data->get_blockrequest_name();
	my $blockrequest_owner_id        = $self->data->get_blockrequest_owner_id();
	my $block_group_id               = $self->data->get_blockrequest_group_id();
	my $block_group_name             = $self->data->get_blockrequest_group_name();
	
	# Get user info	
	my $user_info;
	my $image_info;
	my $image_prettyname;
	my $owner_affiliation_helpaddress;
	my $owner_email;
	
	if ($user_info = get_user_info($blockrequest_owner_id)) {
		$owner_email = $user_info->{email};
		$owner_affiliation_helpaddress = $user_info->{affiliation}{helpaddress};
	}
	
	#Get image info
	if ($image_info = get_image_info($blockrequest_image_id)) {
		$image_prettyname = $image_info->{prettyname};
	
	}
	
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
	notify($ERRORS{'DEBUG'}, 0, "owner email: $owner_email");
	notify($ERRORS{'DEBUG'}, 0, "help address: $owner_affiliation_helpaddress");
	
	if ($blockrequest_mode eq "start") {
		#update processed flag for request
		if (update_block_times_processing($blocktime_id, 1)) {
			notify($ERRORS{'OK'}, 0, "updated process flag on blocktime_id= $blocktime_id");
		}
		
		my $completed = 0;
		my $loop_control = 0;
		my $xmlcall;
		my ($warningmsg, $errormsg);
		
		my $urla = $XMLRPC_URL;
		my $blockAlloc_URL;
		if ($urla =~ /(.*)(=xmlrpccall)/) {
			$blockAlloc_URL = $1 . "=blockallocations";
		}
		
		my($allocated,$unallocated) = 0;
		
		while (!($completed)) {
			if ($loop_control < 6) {
				$loop_control++;
				notify($ERRORS{'DEBUG'}, 0, "processing blocktime_id= $blocktime_id  pass $loop_control");
				$xmlcall = process_block_time($blocktime_id);
			}
			else {
				$completed=1;
				notify($ERRORS{'DEBUG'}, 0, "attempted $loop_control passes to complete block_request $blockrequest_id\n allocated= $allocated \nblockrequest_number_machines= $blockrequest_number_machines");
				last;
			}
			
			$allocated   = $xmlcall->{allocated}   if (defined($xmlcall->{allocated}));
			$unallocated = $xmlcall->{unallocated} if (defined($xmlcall->{unallocated}));
			
			if ($allocated >= $blockrequest_number_machines) {
				$completed=1;
				notify($ERRORS{'OK'}, 0, "success blockTimes id $blocktime_id processed and allocated $xmlcall->{allocated} nodes \nstatus= $xmlcall->{status}");
				last;
			}
			
			if ($xmlcall->{status} =~ /warning|fault/) {
				$warningmsg  = $xmlcall->{warningmsg}  if (defined($xmlcall->{warningmsg}));
				notify($ERRORS{'DEBUG'}, 0, "xmlrpc warning: $warningmsg allocated= $allocated unallocated= $unallocated");
			}
			if ($xmlcall->{status} =~ /error/) {
				$errormsg = $xmlcall->{errormsg} if (defined($xmlcall->{errormsg}));
				notify($ERRORS{'DEBUG'}, 0, "xmlrpc error on blockrequest_id=$blockrequest_id blocktime_id=$blocktime_id : $errormsg");
			}
			if ($xmlcall->{status} =~ /completed/) {
				$completed=1;
				notify($ERRORS{'OK'}, 0, "success blockTimes id $blocktime_id already processed");
			}
			
			sleep 5 if (!$completed);
		}
		
		my $body;
		my $subject = "VCL Block allocation results for $blockrequest_name";
		my $mailstring;
		
		if (defined($warningmsg) || defined($errormsg) || ($allocated < $blockrequest_number_machines)) {
			$body .= "Problem processing block allocation \n\n";
			$body .= "Block id = $blockrequest_id\n";
			$body .= "Block name = $blockrequest_name\n";
			$body .= "Block start time = $blocktime_start\n";
			$body .= "Block end time = $blocktime_end\n";
			$body .= "Environment name = $image_prettyname\n";
			$body .= "Allocated = $allocated\n"; 
			$body .= "Block requested = $blockrequest_number_machines\n"; 
			$body .= "xmlrpc warn msg = $warningmsg\n" if (defined($warningmsg));
			$body .= "xmlrpc error msg = $errormsg\n" if (defined($errormsg));
			$body .= "\n";
			
			notify($ERRORS{'CRITICAL'}, 0, "$body");
			
			if ($allocated < $blockrequest_number_machines) {
				$subject = "VCL Block allocation warning for $blockrequest_name";
			
				$mailstring .= << "EOF";
WARNING - The block allocation for $blockrequest_name was not successfully processed for the following session.

REASON: machines allocated were less than requested

Block allocation name   = $blockrequest_name
Machines allocated      = $allocated
Machines requested      = $blockrequest_number_machines
Block Start time        = $blocktime_start
Block End time          = $blocktime_end
User Group              = $block_group_name
Environment name        = $image_prettyname


The VCL staff have been notified to attempt to correct the issue.

If you wish to cancel this session or make changes to future sessions. Please visit
the VCL site: $blockAlloc_URL

EOF

				if (defined($owner_email)) {
					mail($owner_email, $subject, $mailstring, $owner_affiliation_helpaddress);
				}
			}
		}
		elsif ($completed) {
			# Notify block request owner for given time slot has been processed.
			my $mailstring .= <<"EOF";
The block allocation for $blockrequest_name was processed successfully with the following results:

Block allocation name    = $blockrequest_name
Machines allocated       = $allocated
Machines requested       = $blockrequest_number_machines
Block Start time         = $blocktime_start
Block End time           = $blocktime_end
User Group               = $block_group_name
Environment name         = $image_prettyname

The machines for this block allocation will be loaded up to an hour before the actual start time. 
Once loaded the users listed in the user group $block_group_name will be able to login 5 minutes before the start time.

PLEASE NOTE: 
The VCL resources are valuable and if you choose not to utilize them during this session, you should make them available for others to use. To skip this session please visit the VCL block allocations page: $blockAlloc_URL 
Select View times and skip the desired session.

Thank You,
VCL Team

EOF
			if (defined($owner_email)) {
				mail($owner_email, $subject, $mailstring, $owner_affiliation_helpaddress);
			}	
		}
		
		sleep 10;
		
	} ## end if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "end") {
		# remove blockTime entry for this request
		if (clear_block_computers($blocktime_id)) {
			notify($ERRORS{'OK'}, 0, "Removed computers from blockComputers table for blocktime_id=$blocktime_id");
		}
		if (clear_block_times($blocktime_id)) {
			notify($ERRORS{'OK'}, 0, "Removed blocktime_id=$blocktime_id from blockTimes table");
		}
		
		#check expire time, if this was the last blockTimes entry then this is likely the expiration time as well
		my $status = check_blockrequest_time($blocktime_start, $blocktime_end, $blockrequest_expire);
		if ($status eq "expire") {
			#fork start processing
			notify($ERRORS{'OK'}, 0, "Block Request $blockrequest_id has expired");
			if (udpate_block_request_status($blockrequest_id,"completed")) {
				notify($ERRORS{'OK'}, 0, "Updated status of blockRequest id $blockrequest_id to completed");
			}
		}
	} ## end elsif ($blockrequest_mode eq "end")  [ if ($blockrequest_mode eq "start")
	elsif ($blockrequest_mode eq "expire") {
		notify($ERRORS{'OK'}, 0, "Block Request $blockrequest_id has expired");
		if (udpate_block_request_status($blockrequest_id,"completed")) {
			notify($ERRORS{'OK'}, 0, "Updated status of blockRequest id $blockrequest_id to completed");
		}
	}
	else {
		#should not of hit this
		notify($ERRORS{'CRITICAL'}, 0, "mode not determined mode= $blockrequest_mode");
	}

	##remove processing flag
	if (update_blockrequest_processing($blockrequest_id, 0)) {
		notify($ERRORS{'OK'}, 0, "Removed processing flag on blockrequest_id $blockrequest_id");
	}

	return 1;

} ## end sub process

#//////////////////////////////////////////////////////////////////////////////

=head2 process_block_time

 Parameters  : $blockTimesid
 Returns     : hash references
 Description : calls xmlrpc_call routine with specificed method and args

=cut

sub process_block_time {
	my $blockTimesid = $_[0];

	if (!$blockTimesid) {
		notify($ERRORS{'WARNING'}, 0, "blockTimesid argument was not passed");
		return 0;
	}

	my $method = "XMLRPCprocessBlockTime";
	my $ignoreprivileges = 1;
	my @argument_string = ($method,$blockTimesid, $ignoreprivileges); 

	my $xml_ret = xmlrpc_call(@argument_string);

	my %info;
	if (ref($xml_ret) =~ /STRUCT/i) {
		$info{status} = $xml_ret->value->{status};
		$info{allocated} = $xml_ret->value->{allocated} if (defined($xml_ret->value->{allocated})) ;
		$info{unallocated} = $xml_ret->value->{unallocated} if (defined($xml_ret->value->{unallocated}));
		#error
		$info{errorcode} = $xml_ret->value->{errorcode} if (defined($xml_ret->value->{errorcode}));
		$info{errormsg} = $xml_ret->value->{errormsg} if (defined($xml_ret->value->{errormsg}));
		#warning
		$info{warningcode} = $xml_ret->value->{warningcode} if (defined($xml_ret->value->{warningcode}));
		$info{warningmsg} = $xml_ret->value->{warningmsg} if (defined($xml_ret->value->{warningmsg}));
		#$info{reqidlists} = $xml_ret->value->{requestids};
		}
	else {
		notify($ERRORS{'WARNING'}, 0, "return argument XMLRPCprocessBlockTime was not a STRUCT as expected" . ref($xml_ret));
		if (ref($xml_ret) =~ /fault/) {
			$info{status} = "fault";
		}
		else {
			$info{status} = ref($xml_ret);
		}
	}

	return \%info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 update_block_times_processing

 Parameters  : $blockTimes_id, $processing
 Returns     : 0 or 1
 Description : Updates the processed flag in blockTimes table

=cut

sub update_block_times_processing {
	my ($blockTimes_id, $processing) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($blockTimes_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockTimes ID was not specified");
		return 0;
	}
	if (!defined($processing)) {
		notify($ERRORS{'WARNING'}, 0, "processing was not specified");
		return 0;
	}

	# Construct the update statement
	my $update_statement = "
      UPDATE
		blockTimes
		SET
		blockTimes.processed = $processing
		WHERE
		blockTimes.id = $blockTimes_id
   ";

	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to update blockTimes table, id=$blockTimes_id, processing=$processing");
		return 0;
	}
} ## end sub update_block_times_processing

#//////////////////////////////////////////////////////////////////////////////

=head2 delete_block_request

 Parameters  : $blockrequest_id
 Returns     : 0 or 1
 Description : removes an expired blockrequest from the blockrequest table 

=cut

sub delete_block_request {
	my ($blockrequest_id) = @_;

	# Check the arguments
	if (!defined($blockrequest_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockrequest ID was not specified");
		return 0;
	}
	# Construct the update statement
	my $delete_statement = "
      DELETE
		blockRequest
		FROM blockRequest
		WHERE
		blockRequest.id = $blockrequest_id
   ";

	# Call the database execute subroutine
	if (database_execute($delete_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to deleted blockrequest $blockrequest_id blockRequest table ");
		return 0;
	}

}

#//////////////////////////////////////////////////////////////////////////////

=head2 udpate_block_request_status

 Parameters  : $blockrequest_id
 Returns     : 0 or 1
 Description : update the status of a blockrequest from the blockrequest table

=cut

sub udpate_block_request_status {
	my ($blockrequest_id,$status) = @_;
	
	# Check the arguments
	if (!defined($blockrequest_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockrequest ID was not specified");
		return 0;
	}
	if (!defined($status)) {
		notify($ERRORS{'WARNING'}, 0, "status was not specified for blockrequest_id $blockrequest_id ");
		return 0;
	}
	
	# Construct the update statement
	my $update_statement = "
		UPDATE
		blockRequest
		SET blockRequest.status = '$status'
		WHERE
		blockRequest.id = $blockrequest_id
	";
	
	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to updated blockrequest $blockrequest_id blockRequest table ");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 clear_block_times

 Parameters  : $blockTimes_id
 Returns     : 0 or 1
 Description : Removes blockTimes id from blockTimes table

=cut

sub clear_block_times {
	my ($blockTimes_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($blockTimes_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockTimes ID was not specified");
		return 0;
	}

	# Construct the update statement
	my $delete_statement = "
      DELETE
		blockTimes
		FROM blockTimes
		WHERE
		blockTimes.id = $blockTimes_id
   ";

	# Call the database execute subroutine
	if (database_execute($delete_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to deleted blockTimes_id $blockTimes_id blockTimes table ");
		return 0;
	}
} ## end sub clear_block_times

#//////////////////////////////////////////////////////////////////////////////

=head2 clear_block_computers

 Parameters  : $blockTimes_id, $processing
 Returns     : 0 or 1
 Description : Clears blockcomputers from an expired BlockTimesid

=cut

sub clear_block_computers {
	my ($blockTimes_id) = @_;

	my ($package, $filename, $line, $sub) = caller(0);

	# Check the arguments
	if (!defined($blockTimes_id)) {
		notify($ERRORS{'WARNING'}, 0, "blockTimes ID was not specified");
		return 0;
	}

	# Construct the update statement
	my $delete_statement = "
      DELETE
		blockComputers
		FROM blockComputers
		WHERE
		blockTimeid = $blockTimes_id
   ";

	# Call the database execute subroutine
	if (database_execute($delete_statement)) {
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to delete blockComputers for id=$blockTimes_id, ");
		return 0;
	}
} ## end sub clear_block_computers

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

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
