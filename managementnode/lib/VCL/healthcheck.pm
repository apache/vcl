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

###############################################################################
package VCL::healthcheck;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw(-no_match_vars);

use VCL::utils;
use VCL::DataStructure;
#use VCL::Module::Provisioning::xCAT2;
use DBI;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

#----------GLOBALS--------------
our $LOG = "/var/log/healthcheckvcl.log";
our $MYDBH;
set_logfile_path($LOG);

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2  _initialize

  Parameters  : 
  Returns     : 
  Description :

=cut

sub _initialize {
	my ($info) = @_;
	my ($mnid, $managementnodeid, $selh, @row, $rows, $mnresourceid, $resourceid);
	my $date_time = convert_to_datetime;

	notify($ERRORS{'OK'}, 0, "########### healthcheck run $date_time #################");

	$info->{"globalmsg"}->{"header"} = "STATUS SUMMARY of VCL nodes:\n\n";
	$info->{"logfile"} = $LOG;

	if ($info->{managementnode} = get_management_node_info()) {
		notify($ERRORS{'OK'}, 0, "retrieved management node information from database");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve management node information from database");
		exit;
	}

	#2 Collect hash of computers I can control with data
	if ($info->{computertable} = get_computers_controlled_by_mn(%{$info->{managementnode}})) {
		notify($ERRORS{'OK'}, 0, "retrieved management node resource groups from database");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve management node resource groups from database");
		exit;
	}

}    ### end sub _initialize

#//////////////////////////////////////////////////////////////////////////////

=head2  process

  Parameters  : object
  Returns     : 
  Description :

=cut

sub process {
	my ($info, $powerdownstage) = @_;
	#notify($ERRORS{'OK'}, 0, "in processing routine");
	$info->{"globalmsg"}->{"body"} = "Summary of VCL node monitoring system:\n\n";
	
	my $mn_hostname = $info->{managementnode}->{hostname};
	my $last_check;
	
	if ($powerdownstage =~ /^(available|all)$/) {
		notify($ERRORS{'WARNING'}, 0, "ALERT: powerdown stage triggered,placing MN $mn_hostname in maintenance");
		if (set_managementnode_state($info->{managementnode}, "maintenance")) {
			notify($ERRORS{'OK'}, 0, "Successfully set $mn_hostname into maintenance");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "Failed to set $mn_hostname into maintenance");
		}
	}
	elsif ($powerdownstage =~ /^restore/) {
		notify($ERRORS{'WARNING'}, 0, "ALERT: Environment OK: restoring state of MN $mn_hostname in available");
		if (set_managementnode_state($info->{managementnode}, "available")) {
			notify($ERRORS{'OK'}, 0, "Successfully set $mn_hostname into available");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "Failed to set $mn_hostname into available");
		}
	}
	else {
		#proceed standard checks
	}
	
	foreach my $cid (keys %{$info->{computertable}}) {
		#set some local variables
		#notify($ERRORS{'OK'}, 0, " dumping data for computer id $cid\n" . format_data($info->{computertable}->{$cid}));
		# Create a DataStructure object containing data for the computer specified as the argument
		my $data;
		my $self;
		my $computer_id = $cid;
		eval {
			$data= new VCL::DataStructure({computer_identifier => $computer_id});
		};
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, error: $EVAL_ERROR");
			return;
		}
		elsif (!$data) {
			notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object for computer ID: $computer_id, DataStructure object is not defined");
			return;
		}
		else {
			#notify($ERRORS{'OK'}, 0, "created DataStructure object for computer ID: $computer_id\n". format_data($data->get_request_data));
		}
		
		my $computer_state = $data->get_computer_state_name();
		$last_check = $data->get_computer_lastcheck_time();
		my $computer_currentimage_name = $data->get_computer_currentimage_name();
		
		#Only preform actions on available or failed computers
		#skip if is inuse, maintenance, tovmhost, etc.
		if ($computer_state !~ /available|failed/) {
			#notify($ERRORS{'OK'}, 0, "NODE computer_id $computer_id is in computer_state $computer_state skipping");
			$info->{computers}->{$cid}->{"skip"} = 1;
			$info->{"computersskipped"} += 1;
			next;
		}
		
		#check lastcheck timestampe
		if (defined($last_check) && $computer_state !~ /failed/) {
			my $lastcheckepoch  = convert_to_epoch_seconds($last_check);
			my $currentimeepoch = convert_to_epoch_seconds();
			my $delta           = ($currentimeepoch - $lastcheckepoch);
			
			my $delta_minutes = round($delta / 30);
			
			if ($delta_minutes <= (90)) {
				#  notify($ERRORS{'OK'}, 0, "NODE $computer_id recently checked $delta_minutes minutes ago skipping");
				#this node was recently checked
				$info->{computers}->{$cid}->{"skip"} = 1;
				$info->{"computersskipped"} += 1;
				next;
			}
			$info->{"computerschecked"} += 1;
		} ## end if (defined($last_check) && $computer_state !~...
		
		my $computer_hostname = $data->get_computer_host_name();
		my $computer_short_name = $1 if ($computer_hostname =~ /([-_a-zA-Z0-9]*)(\.?)/);
		my $computer_type = $data->get_computer_type(); 
		
		if ($computer_type eq "lab") {
			#next;
			$computer_short_name = $computer_hostname;
		}
		#next if ($computer_type eq "blade");
		#next if ($computer_type eq "virtualmachine");
		
		my %node_status;
		$node_status{"ping"} = 0;
		$node_status{"ssh"} = 0;
		$node_status{"ssh_status"} = "off";
		$node_status{"status"} = "reload";
		$node_status{"imagerevision_id"} = 0;
		$node_status{"currentimage"} = 0;
		$node_status{"vmstate"} = "off";
		$node_status{"rpower"} = "off";
		my $datestring; 
		my $node_status_string = "reload";
		
		notify($ERRORS{'OK'}, 0, "pinging node $computer_short_name ");
		if (_pingnode($computer_short_name)) {
			$node_status{ping} = 1;	 
			# Try nmap to see if any of the ssh ports are open before attempting to run a test command
			my $port_22_status = nmap_port($computer_short_name, 22) ? "open" : "closed";
			my $port_24_status = nmap_port($computer_short_name, 24) ? "open" : "closed";
			
			my $port = 22; 
			if ($port_24_status eq "open") {
				$port = 24;
			}
			
			my $ssh_user= "root";
			$ssh_user = "vclstaff" if ($computer_type eq "lab");
			
			my ($exit_status, $output) = run_ssh_command({
				node => $computer_short_name,
				command => "echo \"testing ssh on $computer_short_name\"",
				max_attempts => 2,
				output_level => 0,
				port => $port,
				user => $ssh_user,
				timeout_seconds => 30,
			});
			
			my $sshd_status = "off";
			
			# The exit status will be 0 if the command succeeded
			if (defined($output) && grep(/testing/, @$output)) {
				notify($ERRORS{'OK'}, 0, "ssh test: Successful");
				$sshd_status = "on";
			}
			else {
				notify($ERRORS{'OK'}, 0, "ssh test: failed. port 22: $port_22_status, port 24: $port_24_status");
			}
			
			if ($sshd_status eq "on") {
				$node_status{"ssh"} = 1;
				if ($computer_type eq "lab") {
					$node_status_string = "ready";
					$node_status{status} = "ready";
					next;
				}
				my @currentimage_txt_contents = get_current_image_contents_no_data_structure($computer_short_name);
				foreach my $l (@currentimage_txt_contents) {
					#notify($ERRORS{'OK'}, 0, "NODE l=$l");
					if ($l =~ /imagerevision_id/i) {
						chomp($l);
						my ($b,$imagerevision_id) = split(/=/,$l);
						$node_status{imagerevision_id} = $imagerevision_id;
						$node_status_string = "post_load";
						$node_status{status} = "post_load";
					}
					if ($l =~ /vcld_post_load/) {
						$node_status_string = "ready";
						$node_status{status} = "ready";
					}
				}
				
				if ($node_status{imagerevision_id}) {
					#Get image info using imagerevision_id as identifier
					my $image_info = get_imagerevision_info($node_status{imagerevision_id},0);
					$node_status{"currentimage"} = $image_info->{imagename};
					$node_status{"current_image_id"} = $image_info->{imageid};
					$node_status{"imagerevision_id"} = $image_info->{id};
					$node_status{"vmstate"} = "on";
					$node_status{"rpower"} = "on";
				}
			}
			
		}
		
		#need to pass some of the management node info to provisioing module node_status
		$info->{computertable}->{$cid}->{"managementnode"} = $info->{managementnode};
		$info->{computertable}->{$cid}->{"logfile"}        = $info->{logfile};
		
		notify($ERRORS{'OK'}, 0, "hostname:$computer_hostname cid:$cid type:$computer_type state:$computer_state");
		notify($ERRORS{'OK'}, 0, "$computer_hostname currentimage:$node_status{currentimage} current_image_id:$node_status{current_image_id}");
		notify($ERRORS{'OK'}, 0, "$computer_hostname imagerevision_id:$node_status{imagerevision_id}");
		notify($ERRORS{'OK'}, 0, "$computer_hostname vmstate:$node_status{vmstate} power:$node_status{rpower} status:$node_status{status}");
		
		# Collect current state of node - it could have changed since we started
		if (my $comp_current_state = get_computer_current_state_name($cid)) {
			$info->{computertable}->{$cid}->{computer}->{state}->{name} = $comp_current_state;
			$computer_state = $comp_current_state;
		}
		else {
			#could not get it, use existing data
			notify($ERRORS{'OK'}, 0, "could not retrieve current computer state cid= $cid, using old data");
		}
		
		#check for powerdownstages
		if ($powerdownstage =~ /^(available|all)$/) {
			$info->{computertable}->{$cid}->{"powerdownstage"} = $powerdownstage;
			if (powerdown_event($info->{computertable}->{$cid})) {
				notify($ERRORS{'OK'}, 0, "Successfully powered down $computer_hostname");
			}
			else {
				#notify($ERRORS{'OK'}, 0, "Could not powerdown $computer_hostname");
			}
			next;
		}
		else {
			#proceed as normal
		}
		
		#count the nodes processed
		$info->{"computercount"} += 1;
		
		if ($node_status_string =~ /(^ready)|(post_load)/i) {
			#proceed
			notify($ERRORS{'OK'}, 0, "nodestatus reports  $node_status_string for $computer_hostname");
			
			#update lastcheck datetime
			$datestring = makedatestring;
			if (update_computer_lastcheck($computer_id, $datestring, 0)) {
				notify($ERRORS{'OK'}, 0, "updated lastcheckin for $computer_hostname");
			}
			
			#udpate state to available if old state is failed
			if ($computer_state =~ /failed/i) {
				if (update_computer_state($computer_id, "available", 0)) {
					notify($ERRORS{'OK'}, 0, "updated state to available for $computer_hostname");
				}
			}
		} ## end if ($node_status_string =~ /^ready/i)
		elsif ($node_status_string =~ /^reload/i) {
			$info->{computertable}->{$cid}->{node_status} = \%node_status;
			$info->{computertable}->{$cid}->{"computer_currentimage_name"} = $computer_currentimage_name;
			$info->{computertable}->{$cid}->{"computer_hostname"} = $computer_hostname;
			
			notify($ERRORS{'OK'}, 0, "nodestatus reports $node_status_string for $computer_hostname");
			
			#additional steps
			my $node_available = 0;
			
			if ($computer_type eq "lab") {
				#no additional checks required for lab type
				#if (lab_investigator($info->{computertable}->{$cid})) {
				$node_available =1;
				#}
			}
			elsif ($computer_type eq "virtualmachine") {
				if (_virtualmachine_investigator($info->{computertable}->{$cid})) {
					$node_available = 1;
				}
			}
			elsif ($computer_type eq "blade") {
				if (_blade_investigator($info->{computertable}->{$cid})) {
					$node_available = 1;
				}
			}
			
			if ($node_available) {
				#update state to available
				if (update_computer_state($computer_id, "available", 0)) {
					notify($ERRORS{'OK'}, 0, "updated state to available for $computer_hostname");
				}
				#update lastcheck datetime
				$datestring = makedatestring;
				if (update_computer_lastcheck($computer_id, $datestring, 0)) {
					notify($ERRORS{'OK'}, 0, "updated lastcheckin for $computer_hostname");
				}
			} ## end if ($node_available)
			else {
				$info->{globalmsg}->{failedbody} .= "$computer_hostname type= $computer_type offline\n";
			}
			
		} ## end elsif ($node_status_string =~ /^reload/i)  [ if ($node_status_string =~ /^ready/i)
		else {
			notify($ERRORS{'OK'}, 0, "node_status reports unknown value for $computer_hostname node_status_string= $node_status_string ");
		}
		
		# 
		sleep 3;
	}
	return 1;
} ## end sub process

#//////////////////////////////////////////////////////////////////////////////

=head2  blade_investigator

  Parameters  : hash
  Returns     : 1,0 
  Description : provides additional checks for blade types

=cut
sub _blade_investigator {
	my ($self) = @_;

	my $retval                  = 0;
	my $computer_hostname           = $self->{computer}->{hostname};
	my $comp_imagename          = $self->{computer_currentimage_name};
	my $computer_id                 = $self->{computer_id};
	my $nodestatus_status       = $self->{node_status}->{status};
	my $nodestatus_nodetype     = $self->{node_status}->{nodetype};
	my $nodestatus_currentimage = $self->{node_status}->{currentimage};
	my $nodestatus_ping         = $self->{node_status}->{ping};
	my $nodestatus_rpower       = $self->{node_status}->{rpower};
	my $nodestatus_nodeset      = $self->{node_status}->{nodeset};
	my $nodestatus_ssh          = $self->{node_status}->{ssh};

	notify($ERRORS{'OK'}, 0, "computer_hostname= $computer_hostname node_status_status= $nodestatus_status");

	#If can ping and can ssh into it, compare loaded image with database imagename
	if ($nodestatus_ping && $nodestatus_ssh) {
		if (_image_revision_check($computer_id, $comp_imagename, $nodestatus_currentimage)) {
			#return success
			notify($ERRORS{'OK'}, 0, "computer_hostname= $computer_hostname imagename updated");
			$retval = 1;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "computer_hostname= $computer_hostname is confirmed down");
	}

	return $retval;

} ## end sub _blade_investigator

#//////////////////////////////////////////////////////////////////////////////

=head2 powerdown_event 

  Parameters  : hash
  Returns     : 1,0 
  Description : 

=cut

sub powerdown_event {
	my ($self) = @_;

	my $management_node_keys      = $self->{managementnode}->{keys};
	my $computer_host_name        = $self->{computer}->{hostname};
	my $computer_short_name       = 0;
	my $computer_ip_address       = $self->{computer}->{IPaddress};
	my $image_name                = $self->{imagerevision}->{imagename};
	my $image_os_type             = $self->{image}->{OS}->{type};
	my $provisioning_perl_package = $self->{computer}->{provisioning}->{module}->{perlpackage};
	my $computer_type             = $self->{computer}->{type};
	my $computer_state            = $self->{computer}->{state}->{name};
	my $computer_node_name        = $self->{computer}->{hostname};
	my $power_down_stage          = $self->{powerdownstage};

	$computer_short_name = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);

	#If blade or vm and available|failed|maintenance - simply power-off
	#If blade and vmhostinuse - check vms, if available power-down all

	if (($computer_type =~ /blade/) && ($computer_state =~ /^(available|failed|maintenance)/)) {
		notify($ERRORS{'OK'}, 0, "calling provision module $provisioning_perl_package power_off routine $computer_short_name");
		
		eval "use $provisioning_perl_package";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$provisioning_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      0, "returning 0");
			return 0;
		}
		my $power_off_status = eval "&$provisioning_perl_package" . '::power_off($computer_short_name);';
		notify($ERRORS{'OK'}, 0, "$power_off_status ");
		if ($power_off_status) {
			notify($ERRORS{'OK'}, 0, "SUCCESS powered_off $computer_short_name");
			return 1;
		}
		return 0;
	}
	else {
		notify($ERRORS{'OK'}, 0, "SKIPPING $computer_short_name computer_type= $computer_type in   computer_state= $computer_state");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2  virtualmachine_investigator

  Parameters  : hash
  Returns     : 1,0 
  Description : provides additional checks for virtualmachine types

=cut

sub _virtualmachine_investigator {
	my ($self) = @_;

	my $retval                  = 0;
	my $computer_hostname           = $self->{computer}->{hostname};
	my $comp_imagename          = $self->{computer_currentimage_name};
	my $computer_id                 = $self->{computer_id};
	my $nodestatus_status       = $self->{node_status}->{status};
	my $nodestatus_currentimage = $self->{node_status}->{currentimage};
	my $nodestatus_ping         = $self->{node_status}->{ping};
	my $nodestatus_ssh          = $self->{node_status}->{ssh};
	my $nodestatus_vmstate      = $self->{node_status}->{vmstate};
	my $nodestatus_image_match  = $self->{node_status}->{image_match};

	if ($nodestatus_vmstate =~ /off/) {
		# Ok for node to be off
		$retval =1;
		return $retval;
	}

	if ($nodestatus_currentimage && $nodestatus_ssh) {
		if (_image_revision_check($computer_id, $comp_imagename, $nodestatus_currentimage)) {
			#return success
			notify($ERRORS{'OK'}, 0, "computer_hostname= $computer_hostname imagename updated");
			$retval = 1;
		}
	}
	else {
		notify($ERRORS{'OK'}, 0, "computer_hostname= $computer_hostname is confirmed down nodestatus_vmstate= $nodestatus_vmstate nodestatus_ssh= $nodestatus_ssh");
	}

	return $retval;
} ## end sub _virtualmachine_investigator

#//////////////////////////////////////////////////////////////////////////////

=head2  _image_revision_check

  Parameters  : hash
  Returns     : 1,0 
  Description : compare the input values, if no difference or success
                updated return 1, if can not update return 0
                provides additional checks for virtualmachine types

=cut

sub _image_revision_check {

	my ($computer_id, $comp_imagename, $nodestatus_currentimage) = @_;

	my $retval = 1;
	#Return retval=1 only if update_computer_imagename fails
	if ($comp_imagename !~ /$nodestatus_currentimage/) {
		#update computer entry
		if (update_computer_imagename($computer_id, $nodestatus_currentimage, 0)) {
			notify($ERRORS{'OK'}, 0, "updated computer_id currentimage $nodestatus_currentimage");
			$retval = 1;
		}
		else {
			#failed to update computer image info
			notify($ERRORS{'OK'}, 0, "update_computer_imagename return 0");
			$retval = 0;
		}
	} ## end if ($comp_imagename !~ /$nodestatus_currentimage/)
	else {
		notify($ERRORS{'OK'}, 0, " image revisions match - no update required");
	}

	return $retval;

} ## end sub _image_revision_check

#//////////////////////////////////////////////////////////////////////////////

=head2 send_report

  Parameters  : hash
  Returns     : 1,0 
  Description : 

=cut

sub send_report {
	my ($hck) = @_;
	
	my $management_node_info = get_management_node_info();
	if (!$management_node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to send report, management node information could not be retrieved");
		return;
	}
	
	my $sysadmin_email = $management_node_info->{SYSADMIN_EMAIL};
	if (!$sysadmin_email) {
		notify($ERRORS{'WARNING'}, 0, "unable to send report, management node information does not contain a SYSADMIN_EMAIL value");
		return;
	}

	#notify($ERRORS{'OK'},0,"$hck->{globalmsg}->{body}\n\n $hck->{globalmsg}->{failedbody}\n");
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
	mail($sysadmin_email, "VCL node monitoring report", "$hck->{globalmsg}->{body}");
} ## end sub send_report

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
