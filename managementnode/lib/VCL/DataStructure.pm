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
# $Id: DataStructure.pm 1945 2008-12-11 20:58:08Z fapeeler $
##############################################################################

=head1 NAME

VCL::DataStructure - VCL data structure module

=head1 SYNOPSIS

 my $data_structure;
 eval {
    $data_structure = new VCL::DataStructure({request_id => 66, reservation_id => 65});
 };
 if (my $e = Exception::Class::Base->caught()) {
    die $e->message;
 }

 # Access data by calling method on the DataStructure object
 my $user_id = $data_structure->get_user_id;

 # Pass the DataStructure object to a module
 my $xcat = new VCL::Module::Provisioning::xCAT({data_structure => $data_structure});

 ...

 # Access data from xCAT.pm
 # Note: the data() subroutine is implented by Provisioning.pm which xCAT.pm is
 #       a subclass of
 #       ->data-> could also be written as ->data()->
 my $management_node_id = $self->data->get_management_node_id;

=head1 DESCRIPTION

 This module retrieves and stores data from the VCL database. It provides
 methods to access the data. The database schema and data structures used by
 core VCL code should not be visible to most modules. This module encapsulates
 the data and provides an interface to access it.

=cut

##############################################################################
package VCL::DataStructure;

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
use English '-no_match_vars';

use Object::InsideOut;
use List::Util qw(min max);
use VCL::utils;

##############################################################################

=head1 CLASS ATTRIBUTES

=cut

=head3 %SUBROUTINE_MAPPINGS

 Data type   : hash
 Description : %SUBROUTINE_MAPPINGS hash maps subroutine names to hash keys.
               It is used by AUTOMETHOD to return the corresponding hash data
					when an undefined subroutine is called on a DataStructure object.

=cut

my %SUBROUTINE_MAPPINGS;

$SUBROUTINE_MAPPINGS{blockrequest_id}                 = '$self->blockrequest_data->{BLOCKREQUEST_ID}{id}';
$SUBROUTINE_MAPPINGS{blockrequest_name}               = '$self->blockrequest_data->{BLOCKREQUEST_ID}{name}';
$SUBROUTINE_MAPPINGS{blockrequest_image_id}           = '$self->blockrequest_data->{BLOCKREQUEST_ID}{imageid}';
$SUBROUTINE_MAPPINGS{blockrequest_number_machines}    = '$self->blockrequest_data->{BLOCKREQUEST_ID}{numMachines}';
$SUBROUTINE_MAPPINGS{blockrequest_group_id}           = '$self->blockrequest_data->{BLOCKREQUEST_ID}{groupid}';
$SUBROUTINE_MAPPINGS{blockrequest_repeating}          = '$self->blockrequest_data->{BLOCKREQUEST_ID}{repeating}';
$SUBROUTINE_MAPPINGS{blockrequest_owner_id}           = '$self->blockrequest_data->{BLOCKREQUEST_ID}{ownerid}';
$SUBROUTINE_MAPPINGS{blockrequest_admin_group_id}     = '$self->blockrequest_data->{BLOCKREQUEST_ID}{admingroupid}';
$SUBROUTINE_MAPPINGS{blockrequest_management_node_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{managementnodeid}';
$SUBROUTINE_MAPPINGS{blockrequest_expire}             = '$self->blockrequest_data->{BLOCKREQUEST_ID}{expireTime}';
$SUBROUTINE_MAPPINGS{blockrequest_processing}         = '$self->blockrequest_data->{BLOCKREQUEST_ID}{processing}';
$SUBROUTINE_MAPPINGS{blockrequest_mode}               = '$self->blockrequest_data->{BLOCKREQUEST_ID}{MODE}';

$SUBROUTINE_MAPPINGS{blocktime_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{id}';
#$SUBROUTINE_MAPPINGS{blocktime_blockrequest_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{blockRequestid}';
$SUBROUTINE_MAPPINGS{blocktime_start}     = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{start}';
$SUBROUTINE_MAPPINGS{blocktime_end}       = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{end}';
$SUBROUTINE_MAPPINGS{blocktime_processed} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{processed}';

$SUBROUTINE_MAPPINGS{request_check_time}        = '$self->request_data->{CHECKTIME}';
$SUBROUTINE_MAPPINGS{request_modified_time}     = '$self->request_data->{datemodified}';
$SUBROUTINE_MAPPINGS{request_requested_time}    = '$self->request_data->{daterequested}';
$SUBROUTINE_MAPPINGS{request_end_time}          = '$self->request_data->{end}';
$SUBROUTINE_MAPPINGS{request_forimaging}        = '$self->request_data->{forimaging}';
$SUBROUTINE_MAPPINGS{request_id}                = '$self->request_data->{id}';
$SUBROUTINE_MAPPINGS{request_laststate_id}      = '$self->request_data->{laststateid}';
$SUBROUTINE_MAPPINGS{request_log_id}            = '$self->request_data->{logid}';
$SUBROUTINE_MAPPINGS{request_notice_interval}   = '$self->request_data->{NOTICEINTERVAL}';
$SUBROUTINE_MAPPINGS{request_is_cluster_parent} = '$self->request_data->{PARENTIMAGE}';
$SUBROUTINE_MAPPINGS{request_pid}               = '$self->request_data->{PID}';
$SUBROUTINE_MAPPINGS{request_ppid}              = '$self->request_data->{PPID}';
$SUBROUTINE_MAPPINGS{request_preload}           = '$self->request_data->{preload}';
$SUBROUTINE_MAPPINGS{request_preload_only}      = '$self->request_data->{PRELOADONLY}';
$SUBROUTINE_MAPPINGS{request_reservation_count} = '$self->request_data->{RESERVATIONCOUNT}';
$SUBROUTINE_MAPPINGS{request_start_time}        = '$self->request_data->{start}';
#$SUBROUTINE_MAPPINGS{request_stateid} = '$self->request_data->{stateid}';
$SUBROUTINE_MAPPINGS{request_is_cluster_child} = '$self->request_data->{SUBIMAGE}';
$SUBROUTINE_MAPPINGS{request_test}             = '$self->request_data->{test}';
$SUBROUTINE_MAPPINGS{request_updated}          = '$self->request_data->{UPDATED}';
#$SUBROUTINE_MAPPINGS{request_userid} = '$self->request_data->{userid}';
$SUBROUTINE_MAPPINGS{request_state_name}     = '$self->request_data->{state}{name}';
$SUBROUTINE_MAPPINGS{request_laststate_name} = '$self->request_data->{laststate}{name}';

#$SUBROUTINE_MAPPINGS{request_reservationid} = '$self->request_data->{RESERVATIONID}';
$SUBROUTINE_MAPPINGS{reservation_id} = '$self->request_data->{RESERVATIONID}';

#$SUBROUTINE_MAPPINGS{reservation_computerid} = '$self->request_data->{reservation}{RESERVATION_ID}{computerid}';
#$SUBROUTINE_MAPPINGS{reservation_id} = '$self->request_data->{reservation}{RESERVATION_ID}{id}';
#$SUBROUTINE_MAPPINGS{reservation_imageid} = '$self->request_data->{reservation}{RESERVATION_ID}{imageid}';
#$SUBROUTINE_MAPPINGS{reservation_imagerevisionid} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevisionid}';
$SUBROUTINE_MAPPINGS{reservation_lastcheck_time} = '$self->request_data->{reservation}{RESERVATION_ID}{lastcheck}';
$SUBROUTINE_MAPPINGS{reservation_machine_ready}  = '$self->request_data->{reservation}{RESERVATION_ID}{MACHINEREADY}';
#$SUBROUTINE_MAPPINGS{reservation_managementnodeid} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnodeid}';
$SUBROUTINE_MAPPINGS{reservation_password}  = '$self->request_data->{reservation}{RESERVATION_ID}{pw}';
$SUBROUTINE_MAPPINGS{reservation_remote_ip} = '$self->request_data->{reservation}{RESERVATION_ID}{remoteIP}';
#$SUBROUTINE_MAPPINGS{reservation_requestid} = '$self->request_data->{reservation}{RESERVATION_ID}{requestid}';
$SUBROUTINE_MAPPINGS{reservation_ready} = '$self->request_data->{reservation}{RESERVATION_ID}{READY}';

$SUBROUTINE_MAPPINGS{computer_current_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimageid}';
$SUBROUTINE_MAPPINGS{computer_deleted}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{deleted}';
$SUBROUTINE_MAPPINGS{computer_department_id}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{deptid}';
$SUBROUTINE_MAPPINGS{computer_drive_type}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{drivetype}';
$SUBROUTINE_MAPPINGS{computer_dsa}              = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dsa}';
$SUBROUTINE_MAPPINGS{computer_dsa_pub}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dsapub}';
$SUBROUTINE_MAPPINGS{computer_eth0_mac_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{eth0macaddress}';
$SUBROUTINE_MAPPINGS{computer_eth1_mac_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{eth1macaddress}';
#$SUBROUTINE_MAPPINGS{computer_host} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{host}';
$SUBROUTINE_MAPPINGS{computer_hostname}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostname}';
$SUBROUTINE_MAPPINGS{computer_host_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostname}';
#$SUBROUTINE_MAPPINGS{computer_hostpub} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostpub}';
$SUBROUTINE_MAPPINGS{computer_id}                 = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{id}';
$SUBROUTINE_MAPPINGS{computer_imagerevision_id}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{imagerevisionid}';
$SUBROUTINE_MAPPINGS{computer_ip_address}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{IPaddress}';
$SUBROUTINE_MAPPINGS{computer_lastcheck_time}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{lastcheck}';
$SUBROUTINE_MAPPINGS{computer_location}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{location}';
$SUBROUTINE_MAPPINGS{computer_networking_speed}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{network}';
$SUBROUTINE_MAPPINGS{computer_node_name}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{NODENAME}';
$SUBROUTINE_MAPPINGS{computer_notes}              = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{notes}';
$SUBROUTINE_MAPPINGS{computer_owner_id}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_platform_id}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{platformid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_id}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimageid}';
$SUBROUTINE_MAPPINGS{computer_private_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{privateIPaddress}';
$SUBROUTINE_MAPPINGS{computer_processor_count}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procnumber}';
$SUBROUTINE_MAPPINGS{computer_processor_speed}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procspeed}';
$SUBROUTINE_MAPPINGS{computer_ram}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{RAM}';
$SUBROUTINE_MAPPINGS{computer_rsa}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsa}';
$SUBROUTINE_MAPPINGS{computer_rsa_pub}            = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsapub}';
$SUBROUTINE_MAPPINGS{computer_schedule_id}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{scheduleid}';
$SUBROUTINE_MAPPINGS{computer_short_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{SHORTNAME}';
#$SUBROUTINE_MAPPINGS{computer_state_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{stateid}';
$SUBROUTINE_MAPPINGS{computer_state_name}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';
$SUBROUTINE_MAPPINGS{computer_type}            = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{type}';
$SUBROUTINE_MAPPINGS{computer_provisioning_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioningid}';
#$SUBROUTINE_MAPPINGS{computer_vmhostid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhostid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_name}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_id}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{moduleid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_module_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_pretty_name}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_description}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{description}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{perlpackage}';

#$SUBROUTINE_MAPPINGS{vm_computerid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computerid}';
$SUBROUTINE_MAPPINGS{vmhost_hostname}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{hostname}';
$SUBROUTINE_MAPPINGS{vmhost_id}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{id}';
$SUBROUTINE_MAPPINGS{vmhost_image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{imagename}';
$SUBROUTINE_MAPPINGS{vmhost_ram}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{RAM}';
$SUBROUTINE_MAPPINGS{vmhost_state}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{state}';
#$SUBROUTINE_MAPPINGS{vmhost_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{type}';
$SUBROUTINE_MAPPINGS{vmhost_kernal_nic} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmkernalnic}';
$SUBROUTINE_MAPPINGS{vmhost_vm_limit}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmlimit}';
$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofileid}';
$SUBROUTINE_MAPPINGS{vmhost_type}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{type}';
#$SUBROUTINE_MAPPINGS{vmhost_type_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmtypeid}';

$SUBROUTINE_MAPPINGS{vmhost_profile_datastore_path}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{datastorepath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_datastorepath_4vmx} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{datastorepath4vmx}';
#$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{id}';
$SUBROUTINE_MAPPINGS{vmhost_profile_nas_share}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{nasshare}';
$SUBROUTINE_MAPPINGS{vmhost_profile_name}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{profilename}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch0} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch0}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch1} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch1}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmdisk}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmdisk}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmpath}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmpath}';

#$SUBROUTINE_MAPPINGS{vmhost_typeid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtypeid}';
$SUBROUTINE_MAPPINGS{vmhost_type_id}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtype}{id}';
$SUBROUTINE_MAPPINGS{vmhost_type_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtype}{name}';

$SUBROUTINE_MAPPINGS{computer_currentimage_architecture}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_currentimage_deleted}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_currentimage_deptid}              = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{deptid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_forcheckout}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_currentimage_id}                  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{id}';
$SUBROUTINE_MAPPINGS{computer_currentimage_imagemetaid}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_imagetypeid}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{imagetypeid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_lastupdate}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxconcurrent}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxinitialtime}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minnetwork}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocnumber}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocspeed}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minram}              = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_currentimage_name}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{name}';
$SUBROUTINE_MAPPINGS{computer_currentimage_osid}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{OSid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_ownerid}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_platformid}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{platformid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_prettyname}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_currentimage_project}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{project}';
$SUBROUTINE_MAPPINGS{computer_currentimage_reloadtime}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{reloadtime}';
$SUBROUTINE_MAPPINGS{computer_currentimage_size}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{size}';
$SUBROUTINE_MAPPINGS{computer_currentimage_test}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{test}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_comments}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{comments}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_datecreated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_deleted}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_id}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{id}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_imageid}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imageid}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_imagename}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_production}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{production}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_revision}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{revision}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_userid}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{userid}';

$SUBROUTINE_MAPPINGS{computer_dept_name}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dept}{name}';
$SUBROUTINE_MAPPINGS{computer_dept_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dept}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_platform_name}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{platform}{name}';

$SUBROUTINE_MAPPINGS{computer_preferredimage_architecture}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_deleted}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_deptid}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{deptid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_forcheckout}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_id}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{id}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_imagemetaid}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_imagetypeid}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{imagetypeid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_lastupdate}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_maxconcurrent}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_minnetwork}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_minprocnumber}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_minprocspeed}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_minram}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_name}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{name}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_osid}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{OSid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_ownerid}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_platformid}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{platformid}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_prettyname}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_project}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{project}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_reloadtime}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{reloadtime}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_size}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{size}';
$SUBROUTINE_MAPPINGS{computer_preferredimage_test}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimage}{test}';

$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_comments}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{comments}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_datecreated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_deleted}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_id}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{id}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_imageid}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{imageid}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_imagename}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_production}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{production}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_revision}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{revision}';
$SUBROUTINE_MAPPINGS{computer_preferredimagerevision_userid}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{preferredimagerevision}{userid}';

$SUBROUTINE_MAPPINGS{computer_schedule_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{schedule}{name}';
$SUBROUTINE_MAPPINGS{computer_state_name}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';

$SUBROUTINE_MAPPINGS{image_architecture}   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{architecture}';
$SUBROUTINE_MAPPINGS{image_deleted}        = '$self->request_data->{reservation}{RESERVATION_ID}{image}{deleted}';
$SUBROUTINE_MAPPINGS{image_deptid}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{deptid}';
$SUBROUTINE_MAPPINGS{image_forcheckout}    = '$self->request_data->{reservation}{RESERVATION_ID}{image}{forcheckout}';
$SUBROUTINE_MAPPINGS{image_id}             = '$self->request_data->{reservation}{RESERVATION_ID}{image}{id}';
$SUBROUTINE_MAPPINGS{image_identity}       = '$self->request_data->{reservation}{RESERVATION_ID}{image}{IDENTITY}';
$SUBROUTINE_MAPPINGS{image_imagemetaid}    = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemetaid}';
$SUBROUTINE_MAPPINGS{image_lastupdate}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{lastupdate}';
$SUBROUTINE_MAPPINGS{image_maxconcurrent}  = '$self->request_data->{reservation}{RESERVATION_ID}{image}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{image_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{image_minnetwork}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minnetwork}';
$SUBROUTINE_MAPPINGS{image_minprocnumber}  = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minprocnumber}';
$SUBROUTINE_MAPPINGS{image_minprocspeed}   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minprocspeed}';
$SUBROUTINE_MAPPINGS{image_minram}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minram}';
#$SUBROUTINE_MAPPINGS{image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{name}';
#$SUBROUTINE_MAPPINGS{image_osid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OSid}';
$SUBROUTINE_MAPPINGS{image_os_id}           = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OSid}';
$SUBROUTINE_MAPPINGS{image_ownerid}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{ownerid}';
$SUBROUTINE_MAPPINGS{image_platformid}      = '$self->request_data->{reservation}{RESERVATION_ID}{image}{platformid}';
$SUBROUTINE_MAPPINGS{image_prettyname}      = '$self->request_data->{reservation}{RESERVATION_ID}{image}{prettyname}';
$SUBROUTINE_MAPPINGS{image_project}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{project}';
$SUBROUTINE_MAPPINGS{image_reload_time}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{reloadtime}';
$SUBROUTINE_MAPPINGS{image_settestflag}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{SETTESTFLAG}';
$SUBROUTINE_MAPPINGS{image_size}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{size}';
$SUBROUTINE_MAPPINGS{image_test}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{test}';
$SUBROUTINE_MAPPINGS{image_updateimagename} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{UPDATEIMAGENAME}';

$SUBROUTINE_MAPPINGS{image_dept_name}       = '$self->request_data->{reservation}{RESERVATION_ID}{image}{dept}{name}';
$SUBROUTINE_MAPPINGS{image_dept_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{dept}{prettyname}';

$SUBROUTINE_MAPPINGS{imagemeta_checkuser}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{checkuser}';
$SUBROUTINE_MAPPINGS{imagemeta_id}                   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{id}';
$SUBROUTINE_MAPPINGS{imagemeta_postoption}           = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{postoption}';
$SUBROUTINE_MAPPINGS{imagemeta_subimages}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{subimages}';
$SUBROUTINE_MAPPINGS{imagemeta_sysprep}              = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{sysprep}';
$SUBROUTINE_MAPPINGS{imagemeta_usergroupid}          = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{usergroupid}';
$SUBROUTINE_MAPPINGS{imagemeta_usergroupmembercount} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{USERGROUPMEMBERCOUNT}';
$SUBROUTINE_MAPPINGS{imagemeta_usergroupmembers}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{USERGROUPMEMBERS}';

$SUBROUTINE_MAPPINGS{image_os_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{name}';
$SUBROUTINE_MAPPINGS{image_os_prettyname}   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{prettyname}';
$SUBROUTINE_MAPPINGS{image_os_type}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{type}';
$SUBROUTINE_MAPPINGS{image_os_install_type} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{installtype}';
$SUBROUTINE_MAPPINGS{image_os_source_path}  = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{sourcepath}';
$SUBROUTINE_MAPPINGS{image_os_moduleid}     = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{moduleid}';

$SUBROUTINE_MAPPINGS{image_os_module_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{name}';
$SUBROUTINE_MAPPINGS{image_os_module_pretty_name}  = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{image_os_module_description}  = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{description}';
$SUBROUTINE_MAPPINGS{image_os_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{perlpackage}';

$SUBROUTINE_MAPPINGS{image_platform_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{platform}{name}';

$SUBROUTINE_MAPPINGS{imagerevision_comments}     = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{comments}';
$SUBROUTINE_MAPPINGS{imagerevision_date_created} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{imagerevision_deleted}      = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{imagerevision_id}           = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{id}';
$SUBROUTINE_MAPPINGS{imagerevision_imageid}      = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imageid}';
#$SUBROUTINE_MAPPINGS{imagerevision_imagename} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{image_name}               = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{imagerevision_production} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{production}';
$SUBROUTINE_MAPPINGS{imagerevision_revision}   = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{revision}';
$SUBROUTINE_MAPPINGS{imagerevision_userid}     = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{userid}';

#$SUBROUTINE_MAPPINGS{management_node_id} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{id}';
#$SUBROUTINE_MAPPINGS{management_node_ipaddress} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{IPaddress}';
#$SUBROUTINE_MAPPINGS{management_node_hostname} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{hostname}';
#$SUBROUTINE_MAPPINGS{management_node_ownerid} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{ownerid}';
#$SUBROUTINE_MAPPINGS{management_node_stateid} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{stateid}';
#$SUBROUTINE_MAPPINGS{management_node_lastcheckin} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{lastcheckin}';
#$SUBROUTINE_MAPPINGS{management_node_checkininterval} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{checkininterval}';
#$SUBROUTINE_MAPPINGS{management_node_install_path} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{installpath}';
#$SUBROUTINE_MAPPINGS{management_node_image_lib_enable} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{imagelibenable}';
#$SUBROUTINE_MAPPINGS{management_node_image_lib_group_id} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{imagelibgroupid}';
#$SUBROUTINE_MAPPINGS{management_node_image_lib_user} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{imagelibuser}';
#$SUBROUTINE_MAPPINGS{management_node_image_lib_key} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{imagelibkey}';
#$SUBROUTINE_MAPPINGS{management_node_image_lib_partners} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{IMAGELIBPARTNERS}';
#$SUBROUTINE_MAPPINGS{management_node_short_name} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{SHORTNAME}';
#$SUBROUTINE_MAPPINGS{management_node_state_name} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnode}{state}{name}';

$SUBROUTINE_MAPPINGS{user_adminlevelid}   = '$self->request_data->{user}{adminlevelid}';
$SUBROUTINE_MAPPINGS{user_affiliationid}  = '$self->request_data->{user}{affiliationid}';
$SUBROUTINE_MAPPINGS{user_audiomode}      = '$self->request_data->{user}{audiomode}';
$SUBROUTINE_MAPPINGS{user_bpp}            = '$self->request_data->{user}{bpp}';
$SUBROUTINE_MAPPINGS{user_email}          = '$self->request_data->{user}{email}';
$SUBROUTINE_MAPPINGS{user_emailnotices}   = '$self->request_data->{user}{emailnotices}';
$SUBROUTINE_MAPPINGS{user_firstname}      = '$self->request_data->{user}{firstname}';
$SUBROUTINE_MAPPINGS{user_height}         = '$self->request_data->{user}{height}';
$SUBROUTINE_MAPPINGS{user_id}             = '$self->request_data->{user}{id}';
$SUBROUTINE_MAPPINGS{user_im_id}          = '$self->request_data->{user}{IMid}';
$SUBROUTINE_MAPPINGS{user_imtypeid}       = '$self->request_data->{user}{IMtypeid}';
$SUBROUTINE_MAPPINGS{user_lastname}       = '$self->request_data->{user}{lastname}';
$SUBROUTINE_MAPPINGS{user_lastupdated}    = '$self->request_data->{user}{lastupdated}';
$SUBROUTINE_MAPPINGS{user_mapdrives}      = '$self->request_data->{user}{mapdrives}';
$SUBROUTINE_MAPPINGS{user_mapprinters}    = '$self->request_data->{user}{mapprinters}';
$SUBROUTINE_MAPPINGS{user_mapserial}      = '$self->request_data->{user}{mapserial}';
$SUBROUTINE_MAPPINGS{user_middlename}     = '$self->request_data->{user}{middlename}';
$SUBROUTINE_MAPPINGS{user_preferred_name} = '$self->request_data->{user}{preferredname}';
$SUBROUTINE_MAPPINGS{user_showallgroups}  = '$self->request_data->{user}{showallgroups}';
$SUBROUTINE_MAPPINGS{user_standalone}     = '$self->request_data->{user}{STANDALONE}';
$SUBROUTINE_MAPPINGS{user_uid}            = '$self->request_data->{user}{uid}';
#$SUBROUTINE_MAPPINGS{user_unityid} = '$self->request_data->{user}{unityid}';
$SUBROUTINE_MAPPINGS{user_login_id}                   = '$self->request_data->{user}{unityid}';
$SUBROUTINE_MAPPINGS{user_width}                      = '$self->request_data->{user}{width}';
$SUBROUTINE_MAPPINGS{user_adminlevel_name}            = '$self->request_data->{user}{adminlevel}{name}';
$SUBROUTINE_MAPPINGS{user_affiliation_dataupdatetext} = '$self->request_data->{user}{affiliation}{dataUpdateText}';
$SUBROUTINE_MAPPINGS{user_affiliation_helpaddress}    = '$self->request_data->{user}{affiliation}{helpaddress}';
$SUBROUTINE_MAPPINGS{user_affiliation_name}           = '$self->request_data->{user}{affiliation}{name}';
$SUBROUTINE_MAPPINGS{user_affiliation_sitewwwaddress} = '$self->request_data->{user}{affiliation}{sitewwwaddress}';
$SUBROUTINE_MAPPINGS{user_imtype_name}                = '$self->request_data->{user}{IMtype}{name}';


$SUBROUTINE_MAPPINGS{management_node_id}                   = '$ENV{management_node_info}{id}';
$SUBROUTINE_MAPPINGS{management_node_ipaddress}            = '$ENV{management_node_info}{IPaddress}';
$SUBROUTINE_MAPPINGS{management_node_hostname}             = '$ENV{management_node_info}{hostname}';
$SUBROUTINE_MAPPINGS{management_node_ownerid}              = '$ENV{management_node_info}{ownerid}';
$SUBROUTINE_MAPPINGS{management_node_stateid}              = '$ENV{management_node_info}{stateid}';
$SUBROUTINE_MAPPINGS{management_node_lastcheckin}          = '$ENV{management_node_info}{lastcheckin}';
$SUBROUTINE_MAPPINGS{management_node_checkininterval}      = '$ENV{management_node_info}{checkininterval}';
$SUBROUTINE_MAPPINGS{management_node_install_path}         = '$ENV{management_node_info}{installpath}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_enable}     = '$ENV{management_node_info}{imagelibenable}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_group_id}   = '$ENV{management_node_info}{imagelibgroupid}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_user}       = '$ENV{management_node_info}{imagelibuser}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_key}        = '$ENV{management_node_info}{imagelibkey}';
$SUBROUTINE_MAPPINGS{management_node_keys}                 = '$ENV{management_node_info}{keys}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_partners}   = '$ENV{management_node_info}{IMAGELIBPARTNERS}';
$SUBROUTINE_MAPPINGS{management_node_short_name}           = '$ENV{management_node_info}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{management_node_state_name}           = '$ENV{management_node_info}{state}{name}';
$SUBROUTINE_MAPPINGS{management_node_os_name}              = '$ENV{management_node_info}{OSNAME}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_id} = '$ENV{management_node_info}{predictivemoduleid}';

$SUBROUTINE_MAPPINGS{management_node_predictive_module_name}         = '$ENV{management_node_info}{predictive_name}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_pretty_name}  = '$ENV{management_node_info}{predictive_prettyname}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_description}  = '$ENV{management_node_info}{predictive_description}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_perl_package} = '$ENV{management_node_info}{predictive_perlpackage}';

##############################################################################

=head1 OBJECT ATTRIBUTES

=cut

=head3 @request_id

 Data type   : array of scalars
 Description :

=cut

my @request_id : Field : Arg('Name' => 'request_id') : Type(scalar) : Get('Name' => 'request_id', 'Private' => 1);

=head3 @reservation_id

 Data type   : array of scalars
 Description :

=cut

my @reservation_id : Field : Arg('Name' => 'reservation_id') : Type(scalar) : Get('Name' => 'reservation_id', 'Private' => 1);

=head3 @blockrequest_id

 Data type   : array of scalars
 Description :

=cut

my @blockrequest_id : Field : Arg('Name' => 'blockrequest_id') : Type(scalar) : Get('Name' => 'blockrequest_id', 'Private' => 1);

=head3 @blocktime_id

 Data type   : array of scalars
 Description :

=cut

my @blocktime_id : Field : Arg('Name' => 'blocktime_id') : Type(scalar) : Get('Name' => 'blocktime_id', 'Private' => 1);


=head3 @request_data

 Data type   : array of hashes
 Description :

=cut

my @request_data : Field : Arg('Name' => 'request_data') : Get('Name' => 'request_data', 'Private' => 1) : Set('Name' => 'refresh_request_data', 'Private' => 1);

=head3 @blockrequest_data

 Data type   : array of hashes
 Description :

=cut

my @blockrequest_data : Field : Arg('Name' => 'blockrequest_data') : Get('Name' => 'blockrequest_data', 'Private' => 1);

##############################################################################

=head1 PRIVATE OBJECT METHODS

=cut

=head2 initialize

 Parameters  : None
 Returns     : 1 if successful, 0 if failed
 Description : This subroutine initializes the DataStructure object. It
               retrieves the data for the specified request ID from the
               database and adds the data to the object.

=cut

sub _initialize : Init {
	my ($self, $args) = @_;
	my ($package, $filename, $line, $sub) = caller(0);

	if (!defined($ENV{management_node_info}) || !$ENV{management_node_info}) {
		my $management_node_info = get_management_node_info();
		if (!$management_node_info) {
			notify($ERRORS{'WARNING'}, 0, "unable to obtain management node info for this node");
			return 0;
		}
		$ENV{management_node_info} = $management_node_info;
	}

	# TODO: add checks to make sure req data is valid if it was passed and rsvp is set

	#notify($ERRORS{'DEBUG'}, 0, "object initialized");
	return 1;
} ## end sub _initialize :

#/////////////////////////////////////////////////////////////////////////////

=head2 automethod

 Parameters  : None
 Returns     : Data based on the method name, 0 if method was not handled
 Description : This subroutine is automatically invoked when an class method is
               called on a DataStructure object but the method isn't explicitly
               defined. Function names are mapped to data stored in the request
               data hash. This subroutine returns the requested data.

=cut

sub _automethod : Automethod {
	my $self        = shift;
	my @args        = @_;
	my $method_name = $_;

	# Make sure the function name begins with get_ or set_
	my $mode;
	my $data_identifier;
	if ($method_name =~ /^(get|set)_(.*)/) {
		# $mode stores either 'get' or 'set', data stores the requested data
		$mode            = $1;
		$data_identifier = $2;
	}
	else {
		return;
	}

	# If set, make sure an argument was passed
	my $set_data;
	if ($mode =~ /set/ && defined $args[0]) {
		$set_data = $args[0];
	}
	elsif ($mode =~ /set/) {
		notify($ERRORS{'WARNING'}, 0, "data structure set function was called without an argument");
		return;
	}

	# Check if the sub name is defined in the subroutine mappings hash
	# Return if it isn't
	if (!defined $SUBROUTINE_MAPPINGS{$data_identifier}) {
		notify($ERRORS{'WARNING'}, 0, "unsupported subroutine name: $method_name");
		return sub { };
	}

	# Get the hash path out of the subroutine mappings hash
	my $hash_path = $SUBROUTINE_MAPPINGS{$data_identifier};

	# Replace RESERVATION_ID with the actual reservation ID if it exists in the hash path
	my $reservation_id = $self->reservation_id;
	$reservation_id = 'undefined' if !$reservation_id;
	$hash_path =~ s/RESERVATION_ID/$reservation_id/;

	# Replace BLOCKREQUEST_ID with the actual blockrequest ID if it exists in the hash path
	my $blockrequest_id = $self->blockrequest_id;
	$blockrequest_id = 'undefined' if !$blockrequest_id;
	$hash_path =~ s/BLOCKREQUEST_ID/$blockrequest_id/;

	# Replace BLOCKTIME_ID with the actual blocktime ID if it exists in the hash path
	my $blocktime_id = $self->blocktime_id;
	$$blocktime_id = 'undefined' if !$blocktime_id;
	$hash_path =~ s/BLOCKTIME_ID/$blocktime_id/;

	if ($mode =~ /get/) {
		# Get the data from the request_data hash
		# eval is required in order to interpolate the hash path before retrieving the data
		my $key_defined = eval "defined $hash_path";
		if (!$key_defined) {
			notify($ERRORS{'WARNING'}, 0, "corresponding data has not been initialized for $method_name: $hash_path", $self->request_data);
			return sub { };
		}

		my $return_value = eval $hash_path;

		if (!defined $return_value) {
			notify($ERRORS{'WARNING'}, 0, "corresponding data is undefined for $method_name: $hash_path", $self->request_data);
			return sub { };
		}

		# Return the data
		return sub {$return_value;};
	} ## end if ($mode =~ /get/)
	elsif ($mode =~ /set/) {
		eval $hash_path . ' = $set_data';

		# Make sure the value was set in the hash
		my $check_value = eval $hash_path;
		if ($check_value eq $set_data) {
			notify($ERRORS{'DEBUG'}, 0, "data structure updated: $data_identifier = $set_data");
			return sub {1;};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "data structure could not be updated: $data_identifier");
			return sub {0;};
		}
	} ## end elsif ($mode =~ /set/)  [ if ($mode =~ /get/)
} ## end sub _automethod :

#/////////////////////////////////////////////////////////////////////////////

=head2 get_request_data (deprecated)

 Parameters  : None
 Returns     : scalar
 Description : Returns the request data hash.

=cut

sub get_request_data {
	my $self = shift;
	return $self->request_data;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 refresh

 Parameters  : None
 Returns     : 
 Description : 

=cut

sub refresh {
	my $self = shift;

	# Save the current state names
	my $request_id             = $self->get_request_id();
	my $request_state_name     = $self->get_request_state_name();
	my $request_laststate_name = $self->get_request_laststate_name();

	# Get the full set of database data for this request
	if (my %request_info = get_request_info($request_id)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved current request information from database for request $request_id");

		# Set the state names in the newly retrieved hash to their original values
		$request_info{state}{name}     = $request_state_name;
		$request_info{laststate}{name} = $request_laststate_name;

		# Replace the request data for this DataStructure object
		$self->refresh_request_data(\%request_info);
		notify($ERRORS{'DEBUG'}, 0, "updated DataStructure object with current request information from database");

	} ## end if (my %request_info = get_request_info($request_id...
	else {
		notify($ERRORS{'WARNING'}, 0, "could not retrieve current request information from database");
		return;
	}
} ## end sub refresh

#/////////////////////////////////////////////////////////////////////////////

=head2 get_blockrequest_data (deprecated)

 Parameters  : None
 Returns     : scalar
 Description : Returns the block request data hash.

=cut

sub get_blockrequest_data {
	my $self = shift;

	# Check to make sure block request ID is defined
	if (!$self->blockrequest_id) {
		notify($ERRORS{'WARNING'}, 0, "failed to return block request data hash, block request ID is not defined");
		return;
	}

	# Check to make sure block request ID is defined
	if (!$self->blockrequest_data) {
		notify($ERRORS{'WARNING'}, 0, "block request data hash is not defined");
		return;
	}

	# Check to make sure block request data is defined for the ID
	if (!$self->blockrequest_data->{$self->blockrequest_id}) {
		notify($ERRORS{'WARNING'}, 0, "block request data hash is not defined for block request $self->blockrequest_id");
		return;
	}

	# Data is there, return it
	return $self->blockrequest_data->{$self->blockrequest_id};
} ## end sub get_blockrequest_data

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_count

 Parameters  : None
 Returns     : scalar
 Description : Returns the number of reservations for the request
               associated with this reservation's DataStructure object.

=cut

sub get_reservation_count {
	my $self = shift;

	my $reservation_count = scalar keys %{$self->request_data->{reservation}};
	return $reservation_count;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_ids

 Parameters  : None
 Returns     : array containing reservation IDs for the request
 Description : Returns an array containing the reservation IDs for the current request.

=cut

sub get_reservation_ids {
	my $self = shift;

	my @reservation_ids = sort keys %{$self->request_data->{reservation}};
	return @reservation_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_parent_reservation

 Parameters  : None
 Returns     : scalar, either 1 or 0
 Description : This subroutine returns 1 if this is the parent reservation for
               the request or if the request has 1 reservation associated with
					it. It returns 0 if there are multiple reservations associated
					with the request and this reservation is a child.

=cut

sub is_parent_reservation {
	my $self = shift;

	my $reservation_id  = $self->get_reservation_id();
	my @reservation_ids = $self->get_reservation_ids();

	# The parent reservation has the lowest ID
	my $parent_reservation_id = min @reservation_ids;

	if ($reservation_id == $parent_reservation_id) {
		notify($ERRORS{'DEBUG'}, 0, "returning true: parent reservation ID for this request: $parent_reservation_id");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "returning false: parent reservation ID for this request: $parent_reservation_id");
		return 0;
	}
} ## end sub is_parent_reservation

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_data

 Parameters  : reservation id
 Returns     : DataStructure object of specific reservation
 Description : 

=cut

sub get_reservation_data {
	my $self           = shift;
	my $reservation_id = shift;

	# Check to make sure reservation ID was passed
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID was not specified, useless use of this subroutine, returning self");
		return $self;
	}

	# Make sure reservation ID is an integer
	if ($reservation_id !~ /^\d+$/) {
		notify($ERRORS{'CRITICAL'}, 0, "reservation ID must be an integer, invalid value was passed: $reservation_id");
		return;
	}

	# Check if the reservation ID is the same as the one for this object
	if ($reservation_id == $self->reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID the same as this object's, useless use of this subroutine, returning self");
		return $self;
	}

	# Make sure reservation ID exists for this request
	my @reservation_ids = $self->get_reservation_ids();
	if (!grep($reservation_id, @reservation_ids)) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID does not exist for this request: $reservation_id");
		return;
	}

	# Get a new data structure object
	my $sibling_data_structure;
	eval {$sibling_data_structure = new VCL::DataStructure({request_data => $self->request_data, reservation_id => $reservation_id});};
	if (my $e = Exception::Class::Base->caught()) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to create sibling DataStructure object" . $e->message);
		return;
	}

	return $sibling_data_structure;
} ## end sub get_reservation_data

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_private_ip

 Parameters  : None
 Returns     : IP address string if successful, 0 if failed
 Description :

=cut

sub get_computer_private_ip {
	my $self = shift;

	# Get the computer short name from this DataStructure
	my $computer_short_name = $self->get_computer_short_name();
	if (!$computer_short_name) {
		notify($ERRORS{'WARNING'}, 0, "computer short name could not be retrieved");
		return 0;
	}

	# Get the node's private IP address from the hosts file
	if (my $computer_private_ip = get_ip_address_from_hosts($computer_short_name)) {
		return $computer_private_ip;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to locate private IP address for $computer_short_name in hosts file");
		return 0;
	}
} ## end sub get_computer_private_ip

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_remote_ip

 Parameters  : None
 Returns     : string
 Description : 

=cut

sub get_reservation_remote_ip {
	my $self = shift;
	my $reservation_id  = $self->get_reservation_id();

	# Create the select statement
	my $select_statement = "
	SELECT
	remoteIP
	FROM
	reservation
	WHERE
	id = $reservation_id
	";

	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "failed to get reservation remote IP for reservation $reservation_id, zero rows were returned from database select");
		return 0;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "failed to get reservation remote IP for reservation $reservation_id, " . scalar @selected_rows . " rows were returned from database select");
		return 0;
	}

	# Get the single returned row
	# It contains a hash
	my $remote_ip;

	# Make sure we return undef if the column wasn't found
	if (!defined $selected_rows[0]{remoteIP}) {
		notify($ERRORS{'WARNING'}, 0, "failed to get reservation remote IP for reservation $reservation_id, remoteIP value is undefined");
		return;
	}
	# Make sure we return undef if remote IP is blank
	elsif ($selected_rows[0]{remoteIP} eq '') {
		notify($ERRORS{'WARNING'}, 0, "failed to get reservation remote IP for reservation $reservation_id, remoteIP value is blank");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "retrieved remote IP for reservation $reservation_id: $selected_rows[0]{remoteIP}");
	return $selected_rows[0]{remoteIP};
} ## end sub get_reservation_remote_ip

#/////////////////////////////////////////////////////////////////////////////

=head2 get_state_name

 Parameters  : None
 Returns     : string
 Description : Returns either the request state name or 'blockrequest'. Useful
               for vcld when make_new_child needs to figure out which module
					to call.  Without this subroutine, it would need to include
					if statement and then call get_request_state_name or hack the
					name if it's processing a block request;

=cut

sub get_state_name {
	my $self = shift;

	if ($self->blockrequest_id) {
		return 'blockrequest';
	}
	elsif ($self->request_data->{state}{name}) {
		return $self->request_data->{state}{name};
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "blockrequest ID is not set and request state name is undefined");
		return;
	}
} ## end sub get_state_name

#/////////////////////////////////////////////////////////////////////////////

=head2 get_next_image

 Parameters  : none
 Returns     : array 
 Description : called mainly from reclaim module. Refreshes predictive load 
					module information from database, loads module and calls next_image. 

=cut

sub get_next_image_dataStructure {
	my $self = shift;

	#collect predictive reload information from database.
	my $management_predictive_info = get_management_predictive_info();
	if(!$management_predictive_info->{predictivemoduleid}){
		notify($ERRORS{'CRITICAL'}, 0, "unable to obtain management node info for this node");
      return 0;
	}

	#update ENV in case other modules need to know
	$ENV{management_node_info}{predictivemoduleid} = $management_predictive_info->{predictivemoduleid};
	$ENV{management_node_info}{predictive_name} = $management_predictive_info->{predictive_name};
	$ENV{management_node_info}{predictive_prettyname} = $management_predictive_info->{predictive_prettyname};
	$ENV{management_node_info}{predictive_description} = $management_predictive_info->{predictive_description};
	$ENV{management_node_info}{predictive_perlpackage} = $management_predictive_info->{predictive_perlpackage};

	my $predictive_perl_package = $management_predictive_info->{predictive_perlpackage};
	my @nextimage;

	if ($predictive_perl_package) {
		notify($ERRORS{'OK'}, 0, "attempting to load predictive loading module: $predictive_perl_package");

		eval "use $predictive_perl_package";

		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "$predictive_perl_package module could not be loaded");
			notify($ERRORS{'OK'},      0, "returning 0");
			return 0;
		}
		if (my $predictor = ($predictive_perl_package)->new({data_structure => $self})) {
			notify($ERRORS{'OK'}, 0, ref($predictor) . " predictive loading object successfully created");
			@nextimage = $predictor->get_next_image();
			return @nextimage;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "predictive loading object could not be created, returning 0");
			return 0;
		}
	} ## end if ($predictive_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "predictive loading module not loaded, Perl package is not defined");
		return 0
	}

}
#/////////////////////////////////////////////////////////////////////////////

=head2 print_data

 Parameters  :
 Returns     :
 Description :

=cut

sub print_data {
	my $self = shift;

	my $request_data         = format_data($self->request_data,        'request');
	my $management_node_info = format_data($ENV{management_node_info}, 'management_node');

	notify($ERRORS{'OK'}, 0, "request data:\n$request_data\n\nmanagement node info:\n$management_node_info");
}

#/////////////////////////////////////////////////////////////////////////////

=head2 print_subroutines

 Parameters  :
 Returns     :
 Description :

=cut

sub print_subroutines {
	my $self = shift;

	my $output;
	foreach my $mapping_key (sort keys %SUBROUTINE_MAPPINGS) {
		my $mapping_value = $SUBROUTINE_MAPPINGS{$mapping_key};
		$mapping_value =~ s/^\$self->request_data->/\%request/;
		$mapping_value =~ s/^\$ENV{management_node_info}/\%management_node/;
		$output .= "get_$mapping_key() : $mapping_value\n";
	}

	notify($ERRORS{'OK'}, 0, "valid subroutines:\n$output");
} ## end sub print_subroutines
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
