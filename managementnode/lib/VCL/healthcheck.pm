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
use English qw( -no_match_vars );

use VCL::utils;
use DBI;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

#----------GLOBALS--------------
our $LOG = "/var/log/healthcheckvcl.log";
our $MYDBH;

#////////////////////////////////////////////////////////////////////////////////

=head2  new

  Parameters  : 
  Returns     : 
  Description :

=cut

sub new {
	my ($class, %input) = @_;
	my $obj_ref = {%input,};
	bless $obj_ref, $class;    # bless ref to said class
	$obj_ref->_initialize();   # more work to do
	return $obj_ref;

}

#////////////////////////////////////////////////////////////////////////////////

=head2  _initialize

  Parameters  : 
  Returns     : 
  Description :

=cut

sub _initialize {
	my ($info) = @_;
	my ($mnid, $managementnodeid, $selh, @row, $rows, $mnresourceid, $resourceid);
	my $date_time = convert_to_datetime;

	notify($ERRORS{'OK'}, $LOG, "########### healthcheck run $date_time #################");

	$info->{"globalmsg"}->{"header"} = "STATUS SUMMARY of VCL nodes:\n\n";
	$info->{"logfile"} = $LOG;

	if ($info->{managementnode} = get_management_node_info()) {
		notify($ERRORS{'OK'}, $LOG, "retrieved management node information from database");
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOG, "unable to retrieve management node information from database");
		exit;
	}

	#2 Collect hash of computers I can control with data
	if ($info->{computertable} = get_computers_controlled_by_MN(%{$info->{managementnode}})) {
		notify($ERRORS{'OK'}, $LOG, "retrieved management node resource groups from database");
	}
	else {
		notify($ERRORS{'CRITICAL'}, $LOG, "unable to retrieve management node resource groups from database");
		exit;
	}

	foreach my $cid (keys %{$info->{computertable}}) {
		#notify($ERRORS{'OK'}, $LOGFILE, "computer_id= $info->{computertable}->{$cid}->{computer_id}");
		#get computer information
		if ($info->{computertable}->{$cid} = get_computer_info($cid)) {

		}
		else {
			delete $info->{computertable}->{$cid};
		}
	} ## end foreach my $cid (keys %{$info->{computertable}})

}    ### end sub _initialize

#////////////////////////////////////////////////////////////////////////////////

=head2  process

  Parameters  : object
  Returns     : 
  Description :

=cut

sub process {
	my ($info) = @_;
	notify($ERRORS{'OK'}, $LOG, "in processing routine");
	$info->{"globalmsg"}->{"body"} = "Summary of VCL node monitoring system:\n\n";

	foreach my $cid (keys %{$info->{computertable}}) {
		#set some local variables
		my $comp_hostname             = $info->{computertable}->{$cid}->{computer}->{hostname};
		my $comp_type                 = $info->{computertable}->{$cid}->{computer}->{type};
		my $comp_state                = $info->{computertable}->{$cid}->{computer}->{state}->{name};
		my $provisioning_perl_package = $info->{computertable}->{$cid}->{computer}->{provisioning}->{module}->{perlpackage};
		my $last_check                = $info->{computertable}->{$cid}->{computer}->{lastcheck};
		my $image_os_name             = $info->{computertable}->{$cid}->{image}->{OS}->{name};
		my $comp_id                   = $cid;

		#next if ($comp_type eq "lab");
		#next if($comp_type eq "blade");
		#next if ($comp_type eq "virtualmachine");
		#need to pass some of the management node info to provisioing module node_status
		$info->{computertable}->{$cid}->{"managementnode"} = $info->{managementnode};
		$info->{computertable}->{$cid}->{"logfile"}        = $info->{logfile};

		notify($ERRORS{'DEBUG'}, $LOG, "cid= $cid");
		notify($ERRORS{'DEBUG'}, $LOG, "comp_hostname= $comp_hostname");
		notify($ERRORS{'DEBUG'}, $LOG, "comp_type= $comp_type");
		notify($ERRORS{'DEBUG'}, $LOG, "comp_state= $comp_state");
		notify($ERRORS{'DEBUG'}, $LOG, "provisioning_perl_package= $provisioning_perl_package");
		notify($ERRORS{'DEBUG'}, $LOG, "image_os_name= $image_os_name");

		my ($datestring, $node_status_string);

		# Collect current state of node - it could have changed since we started
		if (my $comp_current_state = get_computer_current_state_name($cid)) {
			$comp_state = $comp_current_state;
		}
		else {
			#could not get it, use existing data
			notify($ERRORS{'OK'}, $LOG, "could not retrieve current computer state cid= $cid, using old data");
		}

		#Only preform actions on these available or failed computer states
		#skip if is inuse, maintenance, tovmhost, etc.
		if ($comp_state !~ /available|failed/) {

			notify($ERRORS{'OK'}, $LOG, "NODE $comp_hostname $comp_state skipping");
			$info->{computers}->{$cid}->{"skip"} = 1;
			$info->{"computersskipped"} += 1;
			next;
		}

		#check lastcheck
		if (defined($last_check) && $comp_state !~ /failed/) {
			my $lastcheckepoch  = convert_to_epoch_seconds($last_check);
			my $currentimeepoch = convert_to_epoch_seconds();
			my $delta           = ($currentimeepoch - $lastcheckepoch);

			my $delta_minutes = round($delta / 60);

			if ($delta_minutes <= (60)) {
				notify($ERRORS{'OK'}, $LOG, "NODE $comp_hostname recently checked $delta_minutes minutes ago skipping");
				#this node was recently checked
				$info->{computers}->{$cid}->{"skip"} = 1;
				$info->{"computersskipped"} += 1;
				next;
			}
			$info->{"computerschecked"} += 1;
		} ## end if (defined($last_check) && $comp_state !~...

		#count the nodes processed
		$info->{"computercount"} += 1;
		eval "use $provisioning_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, $LOG, "$provisioning_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      $LOG, "returning 0");
			return 0;
		}

		my $node_status = eval "&$provisioning_perl_package" . '::node_status($info->{computertable}->{$cid});';
		if (!$EVAL_ERROR) {
			notify($ERRORS{'OK'}, $LOG, "loaded $provisioning_perl_package");
		}
		else {
			notify($ERRORS{'WARNING'}, $LOG, "$provisioning_perl_package module could not be loaded $@");
		}

		if (defined $node_status->{status}) {
			$node_status_string = $node_status->{status};
			notify($ERRORS{'DEBUG'}, $LOG, "node_status hash reference contains key {status}=$node_status_string");
		}
		else {
			notify($ERRORS{'DEBUG'}, $LOG, "node_status hash reference does not contain a key called 'status'");
		}

		if ($node_status_string =~ /^ready/i) {
			#proceed
			notify($ERRORS{'OK'}, $LOG, "nodestatus reports  $node_status_string for $comp_hostname");

			#update lastcheck datetime
			$datestring = makedatestring;
			if (update_computer_lastcheck($comp_id, $datestring, $LOG)) {
				notify($ERRORS{'OK'}, $LOG, "updated lastcheckin for $comp_hostname");
			}

			#udpate state to available if old state is failed
			if ($comp_state =~ /failed/i) {
				if (update_computer_state($comp_id, "available", $LOG)) {
					notify($ERRORS{'OK'}, $LOG, "updated state to available for $comp_hostname");
				}
			}
		} ## end if ($node_status_string =~ /^ready/i)
		elsif ($node_status_string =~ /^reload/i) {

			$info->{computertable}->{$cid}->{node_status} = \%{$node_status};

			notify($ERRORS{'OK'}, $LOG, "nodestatus reports $node_status_string for $comp_hostname");

			#additional steps
			my $node_available = 0;

			if ($comp_type eq "lab") {
				#no additional checks required for lab type
				#if(lab_investigator($info->{computertable}->{$cid})){
				#	$node_available =1;
				#}
			}
			elsif ($comp_type eq "virtualmachine") {
				if (_virtualmachine_investigator($info->{computertable}->{$cid})) {
					$node_available = 1;
				}
			}
			elsif ($comp_type eq "blade") {
				if (_blade_investigator($info->{computertable}->{$cid})) {
					$node_available = 1;
				}
			}

			if ($node_available) {
				#update state to available
				if (update_computer_state($comp_id, "available", $LOG)) {
					notify($ERRORS{'OK'}, $LOG, "updated state to available for $comp_hostname");
				}
				#update lastcheck datetime
				$datestring = makedatestring;
				if (update_computer_lastcheck($comp_id, $datestring, $LOG)) {
					notify($ERRORS{'OK'}, $LOG, "updated lastcheckin for $comp_hostname");
				}
			} ## end if ($node_available)
			else{
				$info->{globalmsg}->{failedbody} .= "$comp_hostname type= $comp_type offline\n";
			}

		} ## end elsif ($node_status_string =~ /^reload/i)  [ if ($node_status_string =~ /^ready/i)
		else {
			notify($ERRORS{'OK'}, $LOG, "node_status reports unknown value for $comp_hostname node_status_string= $node_status_string ");

		}


		if ($info->{computers}->{$cid}->{skip}) {
			#update lastcheck time
			$datestring = makedatestring;
		}

	}    #for loop
	return 1;
} ## end sub process

#////////////////////////////////////////////////////////////////////////////////

=head2  blade_investigator

  Parameters  : hash
  Returns     : 1,0 
  Description : provides additional checks for blade types

=cut
sub _blade_investigator {
	my ($self) = @_;

	my $retval                  = 0;
	my $comp_hostname           = $self->{computer}->{hostname};
	my $comp_imagename          = $self->{imagerevision}->{imagename};
	my $comp_id                 = $self->{computer}->{id};
	my $nodestatus_status       = $self->{node_status}->{status};
	my $nodestatus_nodetype     = $self->{node_status}->{nodetype};
	my $nodestatus_currentimage = $self->{node_status}->{currentimage};
	my $nodestatus_ping         = $self->{node_status}->{ping};
	my $nodestatus_rpower       = $self->{node_status}->{rpower};
	my $nodestatus_nodeset      = $self->{node_status}->{nodeset};
	my $nodestatus_ssh          = $self->{node_status}->{ssh};

	notify($ERRORS{'OK'}, $LOG, "comp_hostname= $comp_hostname node_status_status= $nodestatus_status");

	#If can ping and can ssh into it, compare loaded image with database imagename
	if ($nodestatus_ping && $nodestatus_ssh) {
		if (_image_revision_check($comp_id, $comp_imagename, $nodestatus_currentimage)) {
			#return success
			notify($ERRORS{'OK'}, $LOG, "comp_hostname= $comp_hostname imagename updated");
			$retval = 1;
		}
	}
	else {
		notify($ERRORS{'OK'}, $LOG, "comp_hostname= $comp_hostname is confirmed down");
	}

	return $retval;

} ## end sub _blade_investigator

#////////////////////////////////////////////////////////////////////////////////

=head2  virtualmachine_investigator

  Parameters  : hash
  Returns     : 1,0 
  Description : provides additional checks for virtualmachine types

=cut

sub _virtualmachine_investigator {
	my ($self) = @_;

	my $retval                  = 0;
	my $comp_hostname           = $self->{computer}->{hostname};
	my $comp_imagename          = $self->{imagerevision}->{imagename};
	my $comp_id                 = $self->{computer}->{id};
	my $nodestatus_status       = $self->{node_status}->{status};
	my $nodestatus_currentimage = $self->{node_status}->{currentimage};
	my $nodestatus_ping         = $self->{node_status}->{ping};
	my $nodestatus_ssh          = $self->{node_status}->{ssh};
	my $nodestatus_vmstate      = $self->{node_status}->{vmstate};
	my $nodestatus_image_match  = $self->{node_status}->{image_match};

	if($nodestatus_vmstate =~ /off/){
		# Ok for node to be off
		$retval =1;
		return $retval;
	}

	if ($nodestatus_currentimage && $nodestatus_ssh) {
		if (_image_revision_check($comp_id, $comp_imagename, $nodestatus_currentimage)) {
			#return success
			notify($ERRORS{'OK'}, $LOG, "comp_hostname= $comp_hostname imagename updated");
			$retval = 1;
		}
	}
	else {
		notify($ERRORS{'OK'}, $LOG, "comp_hostname= $comp_hostname is confirmed down nodestatus_vmstate= $nodestatus_vmstate nodestatus_ssh= $nodestatus_ssh");
	}

	return $retval;
} ## end sub _virtualmachine_investigator

#////////////////////////////////////////////////////////////////////////////////

=head2  _image_revision_check

  Parameters  : hash
  Returns     : 1,0 
  Description : compare the input values, if no difference or success
					 updated return 1, if can not update return 0
					 provides additional checks for virtualmachine types

=cut

sub _image_revision_check {

	my ($comp_id, $comp_imagename, $nodestatus_currentimage) = @_;

	my $retval = 1;
	#Return retval=1 only if update_computer_imagename fails
	if ($comp_imagename !~ /$nodestatus_currentimage/) {
		#update computer entry
		if (update_computer_imagename($comp_id, $nodestatus_currentimage, $LOG)) {
			$retval = 1;
		}
		else {
			#failed to update computer image info
			notify($ERRORS{'OK'}, $LOG, "update_computer_imagename return 0");
			$retval = 0;
		}
	} ## end if ($comp_imagename !~ /$nodestatus_currentimage/)

	return $retval;

} ## end sub _image_revision_check

#////////////////////////////////////////////////////////////////////////////////

=head2 send_report

  Parameters  : hash
  Returns     : 1,0 
  Description : 

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

=head1 AUTHOR

 Aaron Peeler <aaron_peeler@ncsu.edu>
 Andy Kurth <andy_kurth@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
