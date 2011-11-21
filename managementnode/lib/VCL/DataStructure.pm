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
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use Object::InsideOut;
use List::Util qw(min max);
use YAML;
use Storable qw(dclone);

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
$SUBROUTINE_MAPPINGS{blockrequest_group_name}         = '$self->blockrequest_data->{BLOCKREQUEST_ID}{groupname}';
$SUBROUTINE_MAPPINGS{blockrequest_repeating}          = '$self->blockrequest_data->{BLOCKREQUEST_ID}{repeating}';
$SUBROUTINE_MAPPINGS{blockrequest_owner_id}           = '$self->blockrequest_data->{BLOCKREQUEST_ID}{ownerid}';
$SUBROUTINE_MAPPINGS{blockrequest_admin_group_id}     = '$self->blockrequest_data->{BLOCKREQUEST_ID}{admingroupid}';
$SUBROUTINE_MAPPINGS{blockrequest_management_node_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{managementnodeid}';
$SUBROUTINE_MAPPINGS{blockrequest_expire}             = '$self->blockrequest_data->{BLOCKREQUEST_ID}{expireTime}';
$SUBROUTINE_MAPPINGS{blockrequest_processing}         = '$self->blockrequest_data->{BLOCKREQUEST_ID}{processing}';
$SUBROUTINE_MAPPINGS{blockrequest_mode}               = '$self->blockrequest_data->{BLOCKREQUEST_ID}{MODE}';

$SUBROUTINE_MAPPINGS{blockrequest_blocktimes_id}       = '$self->blockrequest_data->{BLOCKREQUEST_ID}{BLOCKTIMES_ID}';

$SUBROUTINE_MAPPINGS{blockrequest_owner_email}                   = '$self->blockrequest_data->{BLOCKREQUEST_ID}{owner}{email}';
$SUBROUTINE_MAPPINGS{blockrequest_owner_affiliation_helpaddress} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{owner}{affiliation}{helpaddress}';

$SUBROUTINE_MAPPINGS{blockrequest_image_prettyname} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{image}{prettyname}';

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
$SUBROUTINE_MAPPINGS{request_duration_epoch}    = '$self->request_data->{DURATION}';
$SUBROUTINE_MAPPINGS{request_checkuser} 	= '$self->request_data->{checkuser}';
#$SUBROUTINE_MAPPINGS{request_stateid} 		= '$self->request_data->{stateid}';
$SUBROUTINE_MAPPINGS{request_is_cluster_child} 	= '$self->request_data->{SUBIMAGE}';
$SUBROUTINE_MAPPINGS{request_test}             	= '$self->request_data->{test}';
$SUBROUTINE_MAPPINGS{request_updated}          	= '$self->request_data->{UPDATED}';
#$SUBROUTINE_MAPPINGS{request_userid} 		= '$self->request_data->{userid}';
$SUBROUTINE_MAPPINGS{request_state_name}     	= '$self->request_data->{state}{name}';
$SUBROUTINE_MAPPINGS{request_laststate_name} 	= '$self->request_data->{laststate}{name}';

$SUBROUTINE_MAPPINGS{log_userid} = '$self->request_data->{log}{userid}';
$SUBROUTINE_MAPPINGS{log_nowfuture} = '$self->request_data->{log}{nowfuture}';
$SUBROUTINE_MAPPINGS{log_start} = '$self->request_data->{log}{start}';
$SUBROUTINE_MAPPINGS{log_loaded} = '$self->request_data->{log}{loaded}';
$SUBROUTINE_MAPPINGS{log_initialend} = '$self->request_data->{log}{initialend}';
$SUBROUTINE_MAPPINGS{log_finalend} = '$self->request_data->{log}{finalend}';
$SUBROUTINE_MAPPINGS{log_wasavailable} = '$self->request_data->{log}{wasavailable}';
$SUBROUTINE_MAPPINGS{log_ending} = '$self->request_data->{log}{ending}';
$SUBROUTINE_MAPPINGS{log_requestid} = '$self->request_data->{log}{requestid}';
$SUBROUTINE_MAPPINGS{log_computerid} = '$self->request_data->{log}{computerid}';
$SUBROUTINE_MAPPINGS{log_remoteIP} = '$self->request_data->{log}{remoteIP}';
$SUBROUTINE_MAPPINGS{log_imageid} = '$self->request_data->{log}{imageid}';
$SUBROUTINE_MAPPINGS{log_size} = '$self->request_data->{log}{size}';

$SUBROUTINE_MAPPINGS{sublog_imageid} = '$self->request_data->{log}{imageid}';
$SUBROUTINE_MAPPINGS{sublog_imagerevisionid} = '$self->request_data->{log}{imagerevisionid}';
$SUBROUTINE_MAPPINGS{sublog_computerid} = '$self->request_data->{log}{computerid}';
$SUBROUTINE_MAPPINGS{sublog_IPaddress} = '$self->request_data->{log}{IPaddress}';
$SUBROUTINE_MAPPINGS{sublog_managementnodeid} = '$self->request_data->{log}{managementnodeid}';
$SUBROUTINE_MAPPINGS{sublog_predictivemoduleid} = '$self->request_data->{log}{predictivemoduleid}';

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
#$SUBROUTINE_MAPPINGS{reservation_remote_ip} = '$self->request_data->{reservation}{RESERVATION_ID}{remoteIP}';
#$SUBROUTINE_MAPPINGS{reservation_requestid} = '$self->request_data->{reservation}{RESERVATION_ID}{requestid}';
$SUBROUTINE_MAPPINGS{reservation_ready} = '$self->request_data->{reservation}{RESERVATION_ID}{READY}';
$SUBROUTINE_MAPPINGS{reservation_users} = '$self->request_data->{reservation}{RESERVATION_ID}{users}';

$SUBROUTINE_MAPPINGS{computer_data}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}';
$SUBROUTINE_MAPPINGS{computer_current_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimageid}';
$SUBROUTINE_MAPPINGS{computer_deleted}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{deleted}';
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
$SUBROUTINE_MAPPINGS{computer_nextimage_id}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimageid}';
$SUBROUTINE_MAPPINGS{computer_private_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{privateIPaddress}';
$SUBROUTINE_MAPPINGS{computer_processor_count}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procnumber}';
$SUBROUTINE_MAPPINGS{computer_processor_speed}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procspeed}';
$SUBROUTINE_MAPPINGS{computer_ram}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{RAM}';
$SUBROUTINE_MAPPINGS{computer_rsa}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsa}';
$SUBROUTINE_MAPPINGS{computer_rsa_pub}            = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsapub}';
$SUBROUTINE_MAPPINGS{computer_schedule_id}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{scheduleid}';
$SUBROUTINE_MAPPINGS{computer_short_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{computer_state_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{stateid}';
$SUBROUTINE_MAPPINGS{computer_state_name}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';
$SUBROUTINE_MAPPINGS{computer_type}            = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{type}';
$SUBROUTINE_MAPPINGS{computer_provisioning_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioningid}';
$SUBROUTINE_MAPPINGS{computer_vmhost_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhostid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_name}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_id}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{moduleid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_module_name}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_pretty_name}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_description}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{description}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{perlpackage}';

$SUBROUTINE_MAPPINGS{vmhost_computer_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computerid}';
$SUBROUTINE_MAPPINGS{vmhost_hostname}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{hostname}';
$SUBROUTINE_MAPPINGS{vmhost_short_name}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{vmhost_id}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{id}';
$SUBROUTINE_MAPPINGS{vmhost_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{imageid}';
$SUBROUTINE_MAPPINGS{vmhost_image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{image}{name}';
$SUBROUTINE_MAPPINGS{vmhost_ram}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{RAM}';
$SUBROUTINE_MAPPINGS{vmhost_state}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{state}{name}';
#$SUBROUTINE_MAPPINGS{vmhost_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{type}';
$SUBROUTINE_MAPPINGS{vmhost_kernal_nic} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmkernalnic}';
$SUBROUTINE_MAPPINGS{vmhost_vm_limit}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmlimit}';
$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofileid}';
#$SUBROUTINE_MAPPINGS{vmhost_type_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmtype}{vmtypeid}';

$SUBROUTINE_MAPPINGS{vmhost_profile_repository_path}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{repositorypath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_datastore_path}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{datastorepath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtual_disk_path}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualdiskpath}';
#$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{id}';
$SUBROUTINE_MAPPINGS{vmhost_profile_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{imageid}';
$SUBROUTINE_MAPPINGS{vmhost_profile_name}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{profilename}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch0} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch0}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch1} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch1}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch2} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch2}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch3} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch3}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmdisk}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmdisk}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmpath}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmpath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_username}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{username}';
$SUBROUTINE_MAPPINGS{vmhost_profile_password}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{password}';
$SUBROUTINE_MAPPINGS{vmhost_profile_eth0generated}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{eth0generated}';
$SUBROUTINE_MAPPINGS{vmhost_profile_eth1generated}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{eth1generated}';

#$SUBROUTINE_MAPPINGS{vmhost_typeid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtypeid}';
$SUBROUTINE_MAPPINGS{vmhost_type_id}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtype}{id}';
$SUBROUTINE_MAPPINGS{vmhost_type}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtype}{name}';
$SUBROUTINE_MAPPINGS{vmhost_type_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmtype}{name}';

$SUBROUTINE_MAPPINGS{computer_currentimage_architecture}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_currentimage_deleted}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_currentimage_forcheckout}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_currentimage_id}                  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{id}';
$SUBROUTINE_MAPPINGS{computer_currentimage_imagemetaid}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_lastupdate}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxconcurrent}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxinitialtime}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minnetwork}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocnumber}       = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocspeed}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minram}              = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_currentimage_name}                = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imagename}';
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

$SUBROUTINE_MAPPINGS{computer_platform_name}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{platform}{name}';

$SUBROUTINE_MAPPINGS{computer_nextimage_architecture}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_nextimage_deleted}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_nextimage_forcheckout}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_nextimage_id}             = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{id}';
$SUBROUTINE_MAPPINGS{computer_nextimage_imagemetaid}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_lastupdate}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_nextimage_maxconcurrent}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_nextimage_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minnetwork}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minprocnumber}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minprocspeed}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minram}         = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_nextimage_name}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_nextimage_osid}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{OSid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_ownerid}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_platformid}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{platformid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_prettyname}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_nextimage_project}        = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{project}';
$SUBROUTINE_MAPPINGS{computer_nextimage_reloadtime}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{reloadtime}';
$SUBROUTINE_MAPPINGS{computer_nextimage_size}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{size}';
$SUBROUTINE_MAPPINGS{computer_nextimage_test}           = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{test}';

$SUBROUTINE_MAPPINGS{computer_nextimagerevision_comments}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{comments}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_datecreated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_deleted}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_id}          = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{id}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_imageid}     = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imageid}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_imagename}   = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_production}  = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{production}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_revision}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{revision}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_userid}      = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{userid}';

$SUBROUTINE_MAPPINGS{computer_schedule_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{schedule}{name}';
$SUBROUTINE_MAPPINGS{computer_state_name}    = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';

$SUBROUTINE_MAPPINGS{image_architecture}   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{architecture}';
$SUBROUTINE_MAPPINGS{image_deleted}        = '$self->request_data->{reservation}{RESERVATION_ID}{image}{deleted}';
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


$SUBROUTINE_MAPPINGS{imagemeta_checkuser}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{checkuser}';
$SUBROUTINE_MAPPINGS{imagemeta_id}                   = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{id}';
$SUBROUTINE_MAPPINGS{imagemeta_postoption}           = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{postoption}';
$SUBROUTINE_MAPPINGS{imagemeta_subimages}            = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{subimages}';
$SUBROUTINE_MAPPINGS{imagemeta_sysprep}              = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{sysprep}';
$SUBROUTINE_MAPPINGS{imagemeta_usergroupid}          = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{usergroupid}';
$SUBROUTINE_MAPPINGS{imagemeta_rootaccess}           = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{rootaccess}';
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

$SUBROUTINE_MAPPINGS{server_request_id} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{id}';
$SUBROUTINE_MAPPINGS{server_request_fixedIP} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{fixedIP}';
$SUBROUTINE_MAPPINGS{server_request_fixedMAC} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{fixedMAC}';
$SUBROUTINE_MAPPINGS{server_request_admingroupid} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{admingroupid}';
$SUBROUTINE_MAPPINGS{server_request_logingroupid} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{logingroupid}';
$SUBROUTINE_MAPPINGS{server_request_monitored} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{monitored}';
$SUBROUTINE_MAPPINGS{server_ssh_allow_users} = '$self->request_data->{user}{unityid}';

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

$SUBROUTINE_MAPPINGS{connect_methods}		= '$self->request_data->{reservation}{RESERVATION_ID}{connect_methods}';

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
$SUBROUTINE_MAPPINGS{management_node_ssh_port}             = '$ENV{management_node_info}{sshport}';

$SUBROUTINE_MAPPINGS{management_node_public_ip_configuration} = '$ENV{management_node_info}{PUBLIC_IP_CONFIGURATION}';
$SUBROUTINE_MAPPINGS{management_node_public_subnet_mask}      = '$ENV{management_node_info}{PUBLIC_SUBNET_MASK}';
#$SUBROUTINE_MAPPINGS{management_node_public_default_gateway}  = '$ENV{management_node_info}{PUBLIC_DEFAULT_GATEWAY}';
$SUBROUTINE_MAPPINGS{management_node_public_dns_server}       = '$ENV{management_node_info}{PUBLIC_DNS_SERVER}';

$SUBROUTINE_MAPPINGS{management_node_sysadmin_email}	= '$ENV{management_node_info}{SYSADMIN_EMAIL}';
$SUBROUTINE_MAPPINGS{management_node_shared_email_box}    = '$ENV{management_node_info}{SHARED_EMAIL_BOX}';
$SUBROUTINE_MAPPINGS{management_node_not_standalone}    = '$ENV{management_node_info}{NOT_STANDALONE}';

$SUBROUTINE_MAPPINGS{management_node_predictive_module_name}         = '$ENV{management_node_info}{predictive_name}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_pretty_name}  = '$ENV{management_node_info}{predictive_prettyname}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_description}  = '$ENV{management_node_info}{predictive_description}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_perl_package} = '$ENV{management_node_info}{predictive_perlpackage}';

$SUBROUTINE_MAPPINGS{subroutine_mappings} = '\%SUBROUTINE_MAPPINGS';

##############################################################################

=head1 OBJECT ATTRIBUTES

=cut

=head3 @request_id

 Data type   : array of scalars
 Description :

=cut

my @request_id : Field : Arg('Name' => 'request_id', 'Default' => 0) : Type(scalar) : Get('Name' => 'request_id', 'Private' => 1);

=head3 @reservation_id

 Data type   : array of scalars
 Description :

=cut

my @reservation_id : Field : Arg('Name' => 'reservation_id', 'Default' => 0) : Type(scalar) : Get('Name' => 'reservation_id', 'Private' => 1);

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

my @request_data : Field : Deep : Arg('Name' => 'request_data', 'Default' => {}) : Get('Name' => 'request_data', 'Private' => 1) : Set('Name' => 'refresh_request_data', 'Private' => 1);

=head3 @blockrequest_data

 Data type   : array of hashes
 Description :

=cut

my @blockrequest_data : Field : Arg('Name' => 'blockrequest_data', 'Default' => {}) : Get('Name' => 'blockrequest_data', 'Private' => 1);

=head3 @computer_id

 Data type   : array of scalars
 Description :

=cut

my @computer_id : Field : Arg('Name' => 'computer_id') : Type(scalar) : Get('Name' => 'computer_id', 'Private' => 1);

=head3 @image_id

 Data type   : array of scalars
 Description :

=cut

my @image_id : Field : Arg('Name' => 'image_id') : Type(scalar) : Get('Name' => 'image_id', 'Private' => 1);

=head3 @imagerevision_id

 Data type   : array of scalars
 Description :

=cut

my @imagerevision_id : Field : Arg('Name' => 'imagerevision_id') : Type(scalar) : Get('Name' => 'imagerevision_id', 'Private' => 1);

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
	
	# Get the management node info and add it to %ENV
	my $management_node_info = get_management_node_info();
	if (!$management_node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain management node info for this node");
		return;
	}
	$ENV{management_node_info} = $management_node_info;
	
	# Replace the request data with a deep copy if itself
	# This creates entirely separate copies in case multiple DataStructure objects are used
	# If not deep copied, the separate objects will alter each other's data
	$self->refresh_request_data(dclone($self->request_data)) if $self->request_data;
	
	# Set the request and reservation IDs in the request data hash if they are undefined
	$self->request_data->{id} = ($self->request_id || 0) if (!defined($self->request_data->{id}));
	$self->request_data->{RESERVATIONID} = ($self->reservation_id || 0) if (!defined($self->request_data->{RESERVATIONID}));
	
	my $computer_id = $self->computer_id;
	my $image_id = $self->image_id;
	my $imagerevision_id = $self->imagerevision_id;
	
	# Get the computer info if the computer_id argument was specified and add it to this object
	if ($computer_id) {
		notify($ERRORS{'DEBUG'}, 0, "computer ID argument was specified, retrieving data for computer ID: " . $self->computer_id);
		my $computer_info = get_computer_info($self->computer_id);
		if (!$computer_info) {
			notify($ERRORS{'WARNING'}, 0, "DataStructure object could not be initialized, failed to retrieve data for computer ID: " . $self->computer_id);
			
			# Throw an exception because simply returning undefined (return;) does not result in this DataStructure object being undefined
			Exception::Class::Base->throw( error => "DataStructure object could not be initialized, failed to retrieve data for computer ID: " . $self->computer_id);
			return;
		}
		
		$self->request_data->{reservation}{$self->reservation_id}{computer} = $computer_info;
	}
	
	
	# If either the computer ID, image ID, or imagerevision ID arguments are specified, retrieve appropriate image and imagerevision data
	if ($imagerevision_id || $image_id || $computer_id) {
		my $imagerevision_info;
		
		if ($imagerevision_id) {
			notify($ERRORS{'DEBUG'}, 0, "imagerevision ID argument was specified: $imagerevision_id, DataStructure object will contain image information for this imagerevision ID: $imagerevision_id");
			$imagerevision_info = get_imagerevision_info($imagerevision_id);
		}
		
		elsif ($image_id) {
			notify($ERRORS{'DEBUG'}, 0, "image ID argument was specified: $image_id, DataStructure object will contain image information for the production imagerevision of this image");
			$imagerevision_info = get_production_imagerevision_info($image_id);
		}
		
		elsif ($computer_id) {
			if ($imagerevision_id = $self->get_computer_imagerevision_id()) {
				notify($ERRORS{'DEBUG'}, 0, "computer ID argument was specified ($computer_id) but image and imagerevision ID arguments were not, DataStructure object will contain image information for the computer's current imagerevision ID: $imagerevision_id");
			}
			else {
				Exception::Class::Base->throw( error => "DataStructure object could not be initialized, computer's current imagerevision ID could not be retrieved from the current DataStructure data:\n" . format_data($self->get_request_data));
				return;
			}
			$imagerevision_info = get_imagerevision_info($imagerevision_id);
		}
		
		if ($imagerevision_info) {
			$imagerevision_id = $imagerevision_info->{id};
			notify($ERRORS{'DEBUG'}, 0, "retrieved data for imagerevision ID: $imagerevision_id");
			$self->request_data->{reservation}{$self->reservation_id}{imagerevision} = $imagerevision_info;
		}
		else {
			Exception::Class::Base->throw( error => "DataStructure object could not be initialized, failed to retrieve imagerevision data: ");
			return;
		}
		
		$image_id = $imagerevision_info->{imageid};
		if (!defined($image_id)) {
			Exception::Class::Base->throw( error => "DataStructure object could not be initialized, failed to retrieve image ID from the imagerevision data retrieved for imagerevision ID $imagerevision_id:\n" . format_data($imagerevision_info));
			return;
		}
		
		my $image_info = get_image_info($image_id);
		if ($image_info) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved data for image ID: $image_id");
			$self->request_data->{reservation}{$self->reservation_id}{image} = $image_info;
		}
		else {
			Exception::Class::Base->throw( error => "DataStructure object could not be initialized, failed to retrieve data for image ID: " . $self->image_id);
			return;
		}
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 automethod

 Parameters  : None
 Returns     : Data based on the method name, 0 if method was not handled
 Description : This subroutine is automatically invoked when an class method is
               called on a DataStructure object but the method isn't explicitly
               defined. Function names are mapped to data stored in the request
               data hash. This subroutine returns the requested data. An
               optional argument can be specified with a value of 1 to suppress
               warnings if data is not initialized for the value requested.

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
		notify($ERRORS{'WARNING'}, 0, "illegal subroutine name: $method_name");
		return sub { };
	}
	
	# Determines whether or not warnings are shown if data is not initialized
	my $show_warnings = 1;

	# If set, make sure an argument was passed
	my $set_data;
	if ($mode =~ /set/ && defined $args[0]) {
		$set_data = $args[0];
	}
	elsif ($mode =~ /set/) {
		notify($ERRORS{'WARNING'}, 0, "data structure set function was called without an argument");
		return;
	}
	elsif ($mode =~ /get/ && defined $args[0] && !$args[0]) {
		$show_warnings = 0;
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
	$reservation_id = 'undefined' if !defined($reservation_id);
	$hash_path =~ s/RESERVATION_ID/$reservation_id/;

	# Replace BLOCKREQUEST_ID with the actual blockrequest ID if it exists in the hash path
	my $blockrequest_id = $self->blockrequest_id;
	$blockrequest_id = 'undefined' if !defined($blockrequest_id);
	$hash_path =~ s/BLOCKREQUEST_ID/$blockrequest_id/;

	# Replace BLOCKTIME_ID with the actual blocktime ID if it exists in the hash path
	my $blocktime_id = $self->blocktime_id;
	$blocktime_id = 'undefined' if !defined($blocktime_id);
	$hash_path =~ s/BLOCKTIME_ID/$blocktime_id/;

	if ($mode =~ /get/) {
		# Get the data from the request_data hash
		# eval is required in order to interpolate the hash path before retrieving the data
		my $key_defined = eval "defined $hash_path";
		
		my $return_value;
		
		# If log or sublog data was requested and not yet populated, attempt to retrieve it
		if (!$key_defined && $data_identifier =~ /^(log_|sublog_)/) {
			notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve log data, requested data has not been initialized ($data_identifier)");
			
			if ($self->get_log_data()) {
				# Log data was retrieved, check if requested data is now populated
				if (!eval "defined $hash_path") {
					notify($ERRORS{'WARNING'}, 0, "log data was retrieved but corresponding data has not been initialized for $method_name: $hash_path", $self->request_data) if $show_warnings;
					return sub { };
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "log data could not be retrieved");
				return sub { };
			}
		}
		elsif ($data_identifier =~ /^(management_node)/ && $args[0]) {
			# Data about a specific management node was requested by passing an argument:
			# get_management_node_xxx(<management node identifier>)
			#notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve data for management node identifier: $args[0]");
			
			# Get the management node info hash ref for the management node specified by the argument
			my $management_node_info_retrieved = get_management_node_info($args[0]);
			unless ($management_node_info_retrieved) {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve data for management node: $args[0]");
				return sub { };
			}
			
			my $management_node_id = $management_node_info_retrieved->{id};
			my $management_node_hostname = $management_node_info_retrieved->{hostname};
			#notify($ERRORS{'DEBUG'}, 0, "retrieved data for management node: id=$management_node_id, hostname=$management_node_hostname");
			
			# The normal reservation management node data is stored in $ENV{management_node_info}
			# We don't want to overwrite this, but want to temporarily store the data retrieved for the different management node
			# This allows the $hash_path mechanism to work without alterations
			# Temporarily overwrite this data by using 'local', and set it to the data just retrieved
			# Once the current scope is exited, $ENV{management_node_info} will return to its original value
			local $ENV{management_node_info} = $management_node_info_retrieved;
			
			# Attempt to retrieve the value from the temporary data: $ENV{management_node_info}{KEY}
			$return_value = eval $hash_path;
		}
		elsif (!$key_defined) {
			notify($ERRORS{'WARNING'}, 0, "corresponding data has not been initialized for $method_name: $hash_path", $self->request_data) if $show_warnings;
			return sub { };
		}
		else {
			# Just attempt to retrieve the value from the hash path
			$return_value = eval $hash_path;
		}

		if (!defined $return_value) {
			notify($ERRORS{'WARNING'}, 0, "corresponding data is undefined for $method_name: $hash_path", $self->request_data) if $show_warnings;
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
			#notify($ERRORS{'DEBUG'}, 0, "data structure updated: $hash_path\n$data_identifier = $set_data");
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
	
	return 1;
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

=head2 set_reservation_remote_ip

 Parameters  : None
 Returns     : string
 Description : 

=cut

sub set_reservation_remote_ip {
   my $self = shift;
   my $reservation_id  = $self->get_reservation_id();
	
	my $new_remote_ip = shift;
	
	# Check to make sure reservation ID was passed
   if (!$new_remote_ip) {
        notify($ERRORS{'WARNING'}, 0, "new_remote_ip was not specified, returning self");
        return 0;;
   }

	
	my $update_statement = "
		  UPDATE
		  reservation
		  SET
		  remoteIP = \'$new_remote_ip\'
		  WHERE
		  id = \'$reservation_id\'
			  ";

        # Call the database execute subroutine
        if (database_execute($update_statement)) {
                # Update successful
                notify($ERRORS{'OK'}, 0, "new remoteIP $new_remote_ip for reservation id $reservation_id updated");
                return 1;
        }
        else {
                notify($ERRORS{'CRITICAL'}, 0, "unable to update new remote ip for reservation id $reservation_id");
                return 0;
        }


} ## end sub set_reservation_remote_ip

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
		return;
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "failed to get reservation remote IP for reservation $reservation_id, " . scalar @selected_rows . " rows were returned from database select");
		return;
	}

	# Get the single returned row
	# It contains a hash
	my $remote_ip;

	# Return 0 if the column isn't set
	if (!defined $selected_rows[0]{remoteIP}) {
		notify($ERRORS{'OK'}, 0, "reservation remote IP is not defined");
		return 0;
	}
	
	# Make sure we return 0 if remote IP is blank
	elsif ($selected_rows[0]{remoteIP} eq '') {
		notify($ERRORS{'OK'}, 0, "reservation remote IP is not set");
		return 0;
	}
	
	# Set the current value in the request data hash
	$self->request_data->{reservation}{$reservation_id}{remoteIP} = $selected_rows[0]{remoteIP};

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
	
	# Get the current image data in case something goes wrong
	my $image_name = $self->get_image_name();
	my $image_id = $self->get_image_id();
	my $imagerevision_id = $self->get_imagerevision_id();
	
	# Assemble an array with the current image information
	# This will be returned if the predictive method fails
	my @current_image;
	if ($image_name && $image_id && $imagerevision_id) {
		@current_image = ($image_name, $image_id, $imagerevision_id);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain current image information");
      @current_image = ();
	}

	#collect predictive reload information from database.
	my $management_predictive_info = get_management_predictive_info();
	if(!$management_predictive_info->{predictivemoduleid}){
		notify($ERRORS{'CRITICAL'}, 0, "unable to obtain management node info for this node, returning current reservation image information");
      return @current_image;
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
			notify($ERRORS{'OK'},      0, "returning current reservation image information");
			return @current_image;
		}
		if (my $predictor = ($predictive_perl_package)->new({data_structure => $self})) {
			notify($ERRORS{'OK'}, 0, ref($predictor) . " predictive loading object successfully created");
			@nextimage = $predictor->get_next_image();
			if (scalar(@nextimage) == 3) {
				notify($ERRORS{'OK'}, 0, "predictive loading module retreived image information: @nextimage");
				return @nextimage;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "predictive loading module failed to retrieve image information, returning current reservation image information");
				return @current_image;
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "predictive loading object could not be created, returning current reservation image information");
			return @current_image;
		}
	} ## end if ($predictive_perl_package)
	else {
		notify($ERRORS{'OK'}, 0, "predictive loading module not loaded, Perl package is not defined, returning current reservation image information");
		return @current_image;
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

=head2 retrieve_user_data

 Parameters  : If subroutine is called as a DataStructure object method an no arguments are supplied:
                  -the user ID stored in the DataStructure object is used
						-the user login ID stored in the DataStructure object is used if the user ID is not set
						-if neither the user ID or login ID are set in the object, an error message is generated and null is returned
					If subroutine is NOT called as an object method, either of the following must be passed:
					   -user ID containing all digits (example: retrieve_user_data(2870))
						-user ID containing all digits (example: retrieve_user_data('ibuser'))
						-if an argument is not passed, an error message is generated and null is returned
 Returns     : If successful: hash reference containing user data (evaluates to true)
               If failed: undefined (evaluates to false)
 Description : This subroutine attempts to retrieve data for a user.
               If called as an object method the user data is stored in the DataStructure object.
					If called as a class function, the data can be utilized by accessing the hash reference returned.
					A populated DataStructure object does not need to be created in order to use this subroutine.
					A reservation is not required in order to use this subroutine.
					Examples:
					use VCL::DataStructure;
					
					# Called as a class function
					my $user_data = VCL::DataStructure::retrieve_user_data(2870);
					foreach my $key (sort keys(%{$user_data})) {
						print "key: $key, value: $user_data->{$key}\n";
					}
					
					# Called as an object method
					$self->data->retrieve_user_data('ibuser');
					print $self->data->get_user_id();

=cut

sub retrieve_user_data {
	my $self;
	my $argument = shift;
	
	# Check if subroutine was called as an object method
	if (ref($argument) =~ /DataStructure/) {
		# Subroutine was called as an object method, get next argument
		$self = $argument;
		$argument = shift;
	}
	
	# Get a hash containing all of the tables and columns in the database
	my $database_table_columns = VCL::utils::get_database_table_columns();
	if (!$database_table_columns) {
		notify($ERRORS{'WARNING'}, 0, "database table and column names could not be retrieved");
		return;
	}
	
	# Assemble a hash containing table names and aliases to be used in the select statement
	my %tables_to_join = (
		'user' => 'user',
		'adminlevel' => 'user_adminlevel',
		'affiliation' => 'user_affiliation',
		'IMtype' => 'user_IMtype',
	);
	
	# Assemble the WHERE part of the select statement
	# The user must be specified by either passing an id or login_id argument
	my $where_clause;
	if ($argument && $argument =~ /^\d+$/) {
		# Simple scalar argument was passed containing all digits, assume it's the user id
		$where_clause = "user.id = '$argument'\n";
	}
	elsif ($argument) {
		# Simple scalar argument was passed not consisting of all digits, assume it's the user login id
		$where_clause = "user.unityid = '$argument'\n";
	}
	elsif ($self && (my $user_id = $self->get_user_id())) {
		# Argument was not passed but subroutine was called as a DataStructure object method
		# $self->get_user_id() returned something
		$where_clause = "user.id = '$user_id'\n";
	}
	elsif ($self && (my $user_login_id = $self->get_user_login_id())) {
		# Argument was not passed but subroutine was called as a DataStructure object method
		# $self->get_user_login_id() returned something
		$where_clause = "user.unityid = '$user_login_id'\n";
	}
	elsif (!$self) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine which user to query, subroutine was not called as an object method and id or login id argument was not passed");
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to determine which user to query, subroutine was called as an object method but get_user_id() and get_user_login_id() did not return values");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve and store data for user: $where_clause");
	
	# Add the tables to join to the WHERE clause
	$where_clause .= "AND user.adminlevelid = user_adminlevel.id\n";
	$where_clause .= "AND user.affiliationid = user_affiliation.id\n";
	$where_clause .= "AND user.IMtypeid = user_IMtype.id\n";
	
	# Loop through the tables which will be joined together and assemble the columns part of the select statement
	# Get the column names for each table
	# Assemble a line for each column: tablealias_table.column AS tablealias_column
	my $sql_query_columns;
	foreach my $table_to_join (keys(%tables_to_join)) {
		my $table_alias = $tables_to_join{$table_to_join};
		for my $column (@{$database_table_columns->{$table_to_join}}) {
			$sql_query_columns .= "$table_alias.$column AS $table_alias\_$column,\n";
		}
		$sql_query_columns .= "\n";
	}
	
	# Remove the last comma and trailing newlines from the column names string
	$sql_query_columns =~ s/,\n+$//;
	
	# Use join to put together the FROM part of the select statement
	# This generates a string:
	#    table1 tablealias1,
	#    table2 tablealias2...
	my $from_clause = join(",\n", map ("$_ $tables_to_join{$_}", keys(%tables_to_join)));
	
	# Assemble the select statement
	my $sql_select_statement = "SELECT DISTINCT\n\n$sql_query_columns\n\nFROM\n$from_clause\n\nWHERE\n$where_clause";
	
	# Call database_select() to execute the select statement and make sure 1 row was returned
	my @select_rows = VCL::utils::database_select($sql_select_statement);
	if (!scalar @select_rows == 1) {
		notify($ERRORS{'WARNING'}, 0, "select statement returned " . scalar @select_rows . " rows:\n" . join("\n", $sql_select_statement));
		return;
	}
	
	# $select_rows[0] is a hash reference, the keys are the column names
	# Loop through the column names and add the data to $self->request_data
	my $user_data_row = $select_rows[0];
	my %user_data_hash;
	foreach my $column_name (sort keys(%{$user_data_row})) {
		# Get the data value for the column
		my $user_data_value = $user_data_row->{$column_name};
		
		# The column name is in the format: user_affiliation_name
		# Underscores represent hash depth
		# Transform the column name: user_affiliation_name --> {user}{affiliation}{name}
		(my $hash_path = "{$column_name}") =~ s/_/}{/g;
		
		# Use eval to set the correct data key to the value
		eval '$user_data_hash' . $hash_path . '= $user_data_value';
	}
	
	# Attempt to get the user ID and login ID from the data that was just retrieved
	my $user_id = $user_data_hash{user}{id};
	my $user_login_id = $user_data_hash{user}{unityid};
	if (!$user_id && $user_login_id) {
		notify($ERRORS{'WARNING'}, 0, "user id and login id could not be determined for user data just retrieved");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "data has been retrieved for user: $user_login_id (id: $user_id)");
	
	return $user_data_hash{user};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_log_data

 Parameters  : log ID (optional)
 Returns     : hash reference
 Description : Retrieves data from the log and sublog tables for the log ID
               either specified via an argument or the log ID for the
					reservation represented by the DataStructure object.

=cut

sub get_log_data {
	my $self;
	my $argument = shift;
	my $request_log_id;
	
	# Check if subroutine was called as an object method
	if (ref($argument) =~ /DataStructure/) {
		# Subroutine was called as an object method, get next argument
		$self = $argument;
		$argument = shift;
		
		# If argument wasn't passed, attempt to get the log id from this DataStructure object
		if (!$argument) {
			# Get the log id and make sure it is set
			$request_log_id = $self->get_request_log_id();
			if (!$request_log_id) {
				notify($ERRORS{'WARNING'}, 0, "log id was not passed as an argument and could not be retrieved from the existing DataStructure object");
				return;
			}
		}
		else {
			$request_log_id = $argument;
		}
	}
	else {
		$request_log_id = $argument;
		
		# Make sure log id was determined and is valid
		if (!$request_log_id) {
			notify($ERRORS{'WARNING'}, 0, "log id was not passed as an argument and subroutine was not called as an object method");
			return;
		}
	}
	
	# Make sure log id was determined and is valid
	if (!$request_log_id) {
		notify($ERRORS{'WARNING'}, 0, "log id could not be determined");
		return;
	}
	elsif ($request_log_id !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "log id is not valid: $request_log_id");
		return;
	}
	
	# Construct a select statement 
	my $sql_select_statement = "
	SELECT
	*
	FROM
	log
	LEFT JOIN sublog ON sublog.logid = log.id
	WHERE
	log.id = $request_log_id
	";
	
	# Call database_select() to execute the select statement and make sure 1 row was returned
	my @select_rows = VCL::utils::database_select($sql_select_statement);
	if (!scalar @select_rows == 1) {
		notify($ERRORS{'WARNING'}, 0, "select statement returned " . scalar @select_rows . " rows:\n" . join("\n", $sql_select_statement));
		return;
	}
	
	# $select_rows[0] is a hash reference, the keys are the column names
	# Loop through the column names and add the data to $self->request_data
	my $row = $select_rows[0];
	
	my %data_hash;
	foreach my $column_name (sort keys(%{$row})) {
		# Get the data value for the column
		my $data_value = $row->{$column_name};
		$self->request_data->{log}{$column_name} = $data_value if !defined($self->request_data->{log}{$column_name});
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved log data for log id: $request_log_id");
	return $self->request_data->{log};
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_private_ip_address

 Parameters  : computer name (optional)
 Returns     : If successful: string containing IP address
               If failed: false
 Description : Retrieves the IP address for a computer from the
               management node's local /etc/hosts file.
               
               An optional argument can
               be supplied containing the name of the computer for which the IP
               address will be retrieved.
               
               This subroutine may or may not be called as a DataStructure
               object method. If this subroutine is called as an object method,
               the computer name argument is optional. If it is not called as an
               object method, the computer name argument must be supplied.
               
               The first time this subroutine is called as an object method
               without an argument, the reservation computer's IP address is
               retrieved from the /etc/hosts file and saved in the DataStructure
               object's data. Subsequent calls as an object method without an
               argument will return the IP address retrieved the first time for
               efficiency.

=cut

sub get_computer_private_ip_address {
	my $self;
	my $argument = shift;
	my $computer_name;
	
	# Check if subroutine was called as an object method
	if (ref($argument) && $argument->isa('VCL::DataStructure')) {
		# Subroutine was called as an object method, check if an argument was specified
		$self = $argument;
		$argument = shift;
		if ($argument) {
			# Argument was specified, use this as the computer name
			$computer_name = $argument;
		}
		else {
			# Argument was not specified, check if private IP address for this reservation's computer was already retrieved
			if (defined $self->request_data->{reservation}{$self->reservation_id}{computer}{PRIVATE_IP_ADDRESS}) {
				my $existing_private_ip_address = $self->request_data->{reservation}{$self->reservation_id}{computer}{PRIVATE_IP_ADDRESS};
				
				# This subroutine has already been run for the reservation computer, return IP address retrieved earlier
				notify($ERRORS{'DEBUG'}, 0, "returning private IP address previously retrieved: $existing_private_ip_address");
				return $existing_private_ip_address;
			}
			
			# Argument was not specified and private IP address has not yet been saved in the request data
			# Get the computer short name for this reservation
			$computer_name = $self->get_computer_short_name();
		}
	}
	elsif (ref($argument)) {
		notify($ERRORS{'WARNING'}, 0, "subroutine was called with an illegal argument type: " . ref($argument));
		return;
	}
	else {
		# Subroutine was not called as an object method
		$computer_name = $argument;
	}
	
	# Make sure the computer name was determined either from an argument or the request data
	if (!$computer_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine computer name from argument or request data");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve private IP address for computer: $computer_name");

	# Retrieve the contents of /etc/hosts using cat
	my ($exit_status, $output) = run_command('cat /etc/hosts', 1);
	if (defined $exit_status && $exit_status == 0) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved contents of /etc/hosts on this management node, contains " . scalar @$output . " lines");
	}
	elsif (defined $exit_status) {
		notify($ERRORS{'WARNING'}, 0, "failed to cat /etc/hosts on this management node, exit status: $exit_status, output:\n" . join("\n", @$output));
		return;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to run command to cat /etc/hosts on this management node");
		return;
	}
	
	# Find lines containing the computer name followed by a space or period
	my %matching_computer_ip_addresses;
	
	for my $line (@$output) {
		# Ignore commented lines
		next if ($line =~ /^\s*#/);
		
		# Ignore lines which don't contain the computer name
		next if ($line !~ /$computer_name($|\.|\s)/i);
		
		# Extract the IP address from the matching line
		my ($ip_address) = $line =~ /\s*((?:[0-9]{1,3}\.?){4})\s/i;
	
		if (!$ip_address) {
			notify($ERRORS{'WARNING'}, 0, "unable to extract IP address from line: $line");
			next;
		}
		
		# Add the IP address and line to the hash
		$matching_computer_ip_addresses{$ip_address} = $line;
	}

	# Check the hash, it should contain 1 key
	# Make sure 1 uncommented line was found
	my $found_count = scalar keys %matching_computer_ip_addresses;
	if ($found_count == 0) {
		if (my $database_ip_address = $self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress}) {
			notify($ERRORS{'OK'}, 0, "did not find any lines in /etc/hosts containing '$computer_name', returning private IP address defined in the database: $database_ip_address");
			$self->request_data->{reservation}{$self->reservation_id}{computer}{PRIVATE_IP_ADDRESS} = $database_ip_address;
			return $database_ip_address;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "did not find any lines in /etc/hosts containing '$computer_name' and the private IP address is not defined in the database");
			return;
		}
	}
	elsif ($found_count > 1) {
		notify($ERRORS{'WARNING'}, 0, "found multiple lines in /etc/hosts containing '$computer_name' with different IP addresses:\n" . join("\n", values(%matching_computer_ip_addresses)));
		return;
	}
	
	my $ip_address = (keys %matching_computer_ip_addresses)[0];
	
	# Update the request data if subroutine was called as an object method without an argument
	if ($self && !$argument) {
		$self->request_data->{reservation}{$self->reservation_id}{computer}{PRIVATE_IP_ADDRESS} = $ip_address;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "returning IP address from /etc/hosts file: $ip_address");
	return $ip_address;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_computer_private_ip_address

 Parameters  : $private_ip_address
 Returns     : boolean
 Description : Sets the computer private IP address in the DataStructure.

=cut

sub set_computer_private_ip_address {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $private_ip_address = shift;
	if (!$private_ip_address) {
		notify($ERRORS{'WARNING'}, 0, "computer private IP address argument was not supplied");
		return;
	}
	elsif (!is_valid_ip_address($private_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "computer private IP address argument is not valid: '$private_ip_address'");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "updated computer private IP address: '$private_ip_address'");
	$self->request_data->{reservation}{$self->reservation_id}{computer}{PRIVATE_IP_ADDRESS} = $private_ip_address;
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_variable_set

 Parameters  : variable name
 Returns     : If variable is set: 1
               If variable is not set: 0
               If an error occurred: undefined
 Description : Queries the variable table for the variable with the name
               specified by the argument. Returns true if the variable is set,
               false otherwise.

=cut

sub is_variable_set {
	my $variable_name = shift;
	
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument and call shift again
	if (ref($variable_name)) {
		$variable_name = shift;
	}
	
	# Check the argument
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	
	# Construct the select statement
my $select_statement .= <<"EOF";
SELECT
variable.value
FROM
variable
WHERE
variable.name = '$variable_name'
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make 1 sure row was returned
	if (!@selected_rows){
		notify($ERRORS{'DEBUG'}, 0, "variable is NOT set: $variable_name");
		return 0;
	}
	elsif (@selected_rows > 1){
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', multiple rows exist in the database for variable:\n" . format_data(\@selected_rows));
		return;
	}
	
	# Get the serialized value from the variable row
	my $database_value = $selected_rows[0]{value};
	
	if (defined($database_value)) {
		notify($ERRORS{'DEBUG'}, 0, "variable is set: $variable_name");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', row returned:\n" . format_data(\@selected_rows));
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_variable

 Parameters  : variable name
 Returns     : If successful: data stored in the variable table for the variable name specified
               If failed: false
 Description : Queries the variable table for the variable with the name
					specified by the argument. Returns the data stored for the
					variable. Values are deserialized before being returned if the
					value stored was a reference.
					
					Undefined is returned if the variable name does not exist in the
					variable table.

=cut

sub get_variable {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	# Check the argument
	my $variable_name = shift;
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	
	# Construct the select statement
my $select_statement .= <<"EOF";
SELECT
variable.value,
variable.serialization
FROM
variable
WHERE
variable.name = '$variable_name'
EOF
	
	# Call the database select subroutine
	my @selected_rows = database_select($select_statement);

	# Check to make 1 sure row was returned
	if (!@selected_rows){
		notify($ERRORS{'OK'}, 0, "variable '$variable_name' is not set in the database");
		return 0;
	}
	elsif (@selected_rows > 1){
		notify($ERRORS{'WARNING'}, 0, "unable to get value of variable '$variable_name', multiple rows exist in the database for variable:\n" . format_data(\@selected_rows));
		return;
	}
	
	# Get the serialized value from the variable row
	my $serialization_type = $selected_rows[0]{serialization};
	my $database_value = $selected_rows[0]{value};
	my $deserialized_value;
	
	# Deserialize the variable value if necessary
	if ($serialization_type eq 'none') {
		$deserialized_value = $database_value;
	}
	elsif ($serialization_type eq 'yaml') {
		# Attempt to deserialize the value
		$deserialized_value = yaml_deserialize($database_value);
		if (!defined($deserialized_value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to deserialize variable '$variable_name' using YAML");
			return;
		}
		
		# Display the data type of the value retrieved from the variable table
		if (my $deserialized_data_type = ref($deserialized_value)) {
			notify($ERRORS{'DEBUG'}, 0, "data type of variable '$variable_name': $deserialized_data_type reference");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "data type of variable '$variable_name': scalar");
		}
	}
	elsif ($serialization_type eq 'phpserialize') {
		# TODO: find Perl module to handle PHP serialized data
		# Add module to list of dependencies
		# Add code here to call PHP deserialize function
		notify($ERRORS{'CRITICAL'}, 0, "unable to get value of variable '$variable_name', PHP serialized data is NOT supported yet by the VCL backend, returning null");
		return;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "unable to get value of variable '$variable_name', serialization type '$serialization_type' is NOT supported by the VCL backend, returning null");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved variable '$variable_name', serialization: $serialization_type");
	return $deserialized_value;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_variable

 Parameters  : variable name, variable value
 Returns     : If successful: true
               If failed: false
 Description : Inserts or updates a row in the variable table. The variable name
               and value arguments must be specified.
               
               The value can be a simple scalar such as a string or a reference
               to a complex data structure such as an array of hashes.
               
               Simple scalar values are stored in the variable.value column
               as-is and the variable.serialization column will be set to
               'none'.
               
               References are serialized using YAML before being stored. The
               variable.value column will contain the YAML representation of the
               data and the variable.serialization column will be set to 'yaml'.
               
               This subroutine will also update the variable.timestamp column.
               The variable.setby column is automatically set to the filename
               and line number which called this subroutine.

=cut

sub set_variable {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	my $variable_name = shift;
	
	# Get the 2nd argument containing the variable value
	my $variable_value = shift;
	
	# Check the arguments
	if (!defined($variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "variable name argument was not supplied");
		return;
	}
	elsif (!defined($variable_value)) {
		notify($ERRORS{'WARNING'}, 0, "variable value argument was not supplied");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to set variable: $variable_name");
	
	# Set serialization type to yaml if the value being stored is a reference
	# Otherwise, a simple scalar is being stored and serialization is not necessary
	my $serialization_type;
	if (ref($variable_value)) {
		$serialization_type = 'yaml';
	}
	else {
		$serialization_type = 'none';
	}
	
	# Construct a string indicating where the variable was set from
	my @caller = caller(0);
	(my $calling_file) = $caller[1] =~ /([^\/]*)$/;
	my $calling_line = $caller[2];
	my $caller_string = "$calling_file:$calling_line";
	
	# Attempt to serialize the value if necessary
	my $database_value;
	if ($serialization_type eq 'none') {
		$database_value = $variable_value;
	}
	else {
		# Attempt to serialize the value using YAML
		$database_value = yaml_serialize($variable_value);
		if (!defined($database_value)) {
			notify($ERRORS{'WARNING'}, 0, "unable to serialize variable '$variable_name' using YAML, value:\n" . format_data($variable_value));
			return;
		}
	}
	
	# Escape all backslashes
	$database_value =~ s/\\/\\\\/g;
	
	# Escape all single quote characters with a backslash
	#   or else the SQL statement will fail becuase it is wrapped in single quotes
	$database_value =~ s/'/\\'/g;
	
	# Assemble an insert statement, if the variable already exists, update the existing row
	my $insert_statement .= <<"EOF";
INSERT INTO variable
(
name,
serialization,
value,
setby,
timestamp
)
VALUES
(
'$variable_name',
'$serialization_type',
'$database_value',
'$caller_string',
NOW()
)
ON DUPLICATE KEY UPDATE
name=VALUES(name),
serialization=VALUES(serialization),
value=VALUES(value),
setby=VALUES(setby),
timestamp=VALUES(timestamp)
EOF
	
	# Execute the insert statement, the return value should be the id of the row
	my $inserted_id = database_execute($insert_statement);
	if ($inserted_id) {
		notify($ERRORS{'OK'}, 0, "set variable '$variable_name', variable id: $inserted_id, serialization: $serialization_type");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set variable '$variable_name', serialization: $serialization_type");
		return;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 yaml_serialize

 Parameters  : Data
 Returns     : If successful: string containing serialized representation of data
               If failed: false
 Description : 

=cut

sub yaml_serialize {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument
	shift @_ if ($_[0] && ref($_[0]) && ref($_[0]) =~ /VCL/);
	
	# Check to make sure argument was passed
	my $data_argument = shift;
	if (!defined($data_argument)) {
		notify($ERRORS{'WARNING'}, 0, "data argument was not passed");
		return;
	}
	
	# Attempt to serialize the value using YAML::Dump()
	# Use eval because Dump() will call die() if it encounters an error
	my $serialized_data;
	eval '$serialized_data = YAML::Dump($data_argument)';
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to serialize data using YAML::Dump(), data value: $data_argument");
		return;
	}
	
	# Escape all backslashes
	$serialized_data =~ s/\\/\\\\/g;
	
	# Escape all single quote characters with a backslash
	#   or else the SQL statement will fail becuase it is wrapped in single quotes
	$serialized_data =~ s/'/\\'/g;
	
	return $serialized_data;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 yaml_deserialize

 Parameters  : Data
 Returns     : If successful: data structure
               If failed: false
 Description : 

=cut

sub yaml_deserialize {
	# Check if 1st argument is a reference meaning this was called as an object method
	# If so, ignore 1st reference argument and call shift again
	my $yaml_data_argument = shift;
	if (ref($yaml_data_argument)) {
		$yaml_data_argument = shift;
	}
	
	# Check to make sure argument was passed
	if (!defined($yaml_data_argument)) {
		notify($ERRORS{'WARNING'}, 0, "data argument was not passed");
		return;
	}
	
	my $deserialized_value;
	eval '$deserialized_value = YAML::Load($yaml_data_argument)';
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to deserialize data using YAML::Load(), data value: $yaml_data_argument");
		return;
	}
	
	return $deserialized_value;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_affiliation_name

 Parameters  : None.
 Returns     : If successful: string containing affiliation name
               If failed: false
 Description : This subroutine determines the affiliation name for the image
               assigned to the reservation.
               The image affiliation is based on the affiliation of the image
               owner.

=cut

sub get_image_affiliation_name {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	# Get the image owner id in order to determine the image affiliation
	my $image_owner_id = $self->get_image_ownerid();
	notify($ERRORS{'DEBUG'}, 0, "image owner id: $image_owner_id");
	unless ($image_owner_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image owner id in order to determine image affiliation");
		return;
	}
	
	# Get the data for the user who owns the image
	my $image_owner_data = $self->retrieve_user_data($image_owner_id);
	unless ($image_owner_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image owner data in order to determine image affiliation");
		return;
	}
	
	# Get the affiliation name from the user data hash
	my $image_affiliation_name = $image_owner_data->{affiliation}{name};
	unless ($image_affiliation_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image owner affiliation name");
		return;
	}
	
	return $image_affiliation_name;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_image_affiliation_id

 Parameters  : None.
 Returns     : If successful: string containing affiliation id
               If failed: false
 Description : This subroutine determines the affiliation id for the image
               assigned to the reservation.
               The image affiliation is based on the affiliation of the image
               owner.

=cut

sub get_image_affiliation_id {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	# Get the image owner id in order to determine the image affiliation
	my $image_owner_id = $self->get_image_ownerid();
	notify($ERRORS{'DEBUG'}, 0, "image owner id: $image_owner_id");
	if (!defined($image_owner_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine image owner id in order to determine image affiliation");
		return;
	}
	
	# Get the data for the user who owns the image
	my $image_owner_data = $self->retrieve_user_data($image_owner_id);
	unless ($image_owner_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image owner data in order to determine image affiliation");
		return;
	}
	
	# Get the affiliation id from the user data hash
	my $image_affiliation_id = $image_owner_data->{affiliation}{id};
	unless ($image_affiliation_id) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve image owner affiliation id");
		return;
	}
	
	return $image_affiliation_id;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_blockrequest

 Parameters  : None.
 Returns     : If DataStructure contains blockrequest data: true
               If DataStructure does not contain blockrequest data: false
 Description : This subroutine determines whether or not the DataStructure
               contains data for a blockrequest.

=cut

sub is_blockrequest {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	# Check if reservation_id has been set, return 1 or 0 based on that
	if ($self->blockrequest_id) {
		return 1;
	}
	else {
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 is_server_request

 Parameters  : None.
 Returns     : 
 Description : This subroutine determines whether or not the DataStructure
               contains data for a server request.

=cut

sub is_server_request {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	return $self->get_server_request_id() ? 1 : 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_public_default_gateway

 Parameters  : None
 Returns     : If successful: string containing IP address
               If failed: false
 Description : Returns the management node's default gateway IP address. This
               subroutine will return the address configured on the "GATEWAY="
               line in the vcld.conf file if configured.
               
               Otherwise it uses the "route -n" command and attempts to
               locate a single line beginning with 0.0.0.0.
               
               If it fails to determine the default gateway using the route
               command, the dhcpd.conf file is checked for an "option routers"
               line containing a valid public IP address.

=cut

sub get_management_node_public_default_gateway {
	my $default_gateway;
	
	# Attempt to retrieve the default gateway explicitly configured for this management node
	$default_gateway = $ENV{management_node_info}{PUBLIC_DEFAULT_GATEWAY};
	if ($default_gateway && is_valid_ip_address($default_gateway)) {
		notify($ERRORS{'DEBUG'}, 0, "returning default gateway configured in vcld.conf: $default_gateway");
		return $default_gateway;
	}
	
	# Attempt to retrieve the gateway from the route command
	my ($route_exit_status, $route_output) = run_command('route -n', 1);
	if ($route_output && (my @route_gateway_lines = grep(/^0.0.0.0/, @$route_output))) {
		if (scalar @route_gateway_lines == 1) {
			($default_gateway) = $route_gateway_lines[0] =~ /^[\d\.]+\s+([\d\.]+)/;
			if (is_valid_ip_address($default_gateway)) {
				notify($ERRORS{'DEBUG'}, 0, "returning default gateway from route command: $default_gateway");
				return $default_gateway;
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "unable to determine default gateway valid IP address from route command output:\n" . join("\n", @route_gateway_lines));
			}
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "multiple default gateway lines found in route command output:\n" . join("\n", @route_gateway_lines));
		}
	}
	
	# Attempt to retrieve the gateway from the "option routers" line in dhcpd.conf
	my @dhcpd_conf_lines = read_file_to_array('/etc/dhcpd.conf');
	if (@dhcpd_conf_lines) {
		my @option_routers_lines = grep(/\s*[^#]\s*option\s+routers/, @dhcpd_conf_lines);
		notify($ERRORS{'DEBUG'}, 0, "dhcpd.conf option routers lines:\n" . join("\n", @option_routers_lines));
		
		# Store public IP addresses found on "option routers" lines as hash keys to ignore duplicates
		my %public_option_routers_addresses;
		
		# Loop through any "option routers" lines found in dhcpd.conf
		for my $option_routers_line (@option_routers_lines) {
			# Extract the IP address from the "option routers" line
			my ($option_routers_ip) = $option_routers_line =~ /option\s+routers\s+([\d\.]+)/;
			
			# Check if IP address was found, is valid, and is public
			if (!$option_routers_ip) {
				notify($ERRORS{'DEBUG'}, 0, "option routers line does not contain an IP address: $option_routers_line");
				next;
			}
			if (!is_valid_ip_address($option_routers_ip)) {
				notify($ERRORS{'DEBUG'}, 0, "option routers line does not contain a valid IP address: $option_routers_line");
				next;
			}
			if (!is_public_ip_address($option_routers_ip)) {
				notify($ERRORS{'DEBUG'}, 0, "option routers line contains a non-public address: $option_routers_line");
				next;
			}
			notify($ERRORS{'DEBUG'}, 0, "public option routers IP address found in dhcpd.conf: $option_routers_ip");
			$public_option_routers_addresses{$option_routers_ip} = 1;
		}
		
		# Check if only 1 "option routers" line was found containing a valid public IP address
		if (scalar keys(%public_option_routers_addresses) == 1) {
			my $default_gateway = (keys(%public_option_routers_addresses))[0];
			notify($ERRORS{'DEBUG'}, 0, "returning default gateway found in dhcpd.conf: $default_gateway");
			return $default_gateway;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "multiple public option routers IP addresses found in dhcpd.conf: " . keys(%public_option_routers_addresses));
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve dhcpd.conf contents");
	}
	
	return;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_public_dns_servers

 Parameters  : None
 Returns     : If successful: array containing IP addresses
               If failed: false
 Description : Returns an array containing the addresses of the public DNS
               servers configured for the management node.

=cut

sub get_management_node_public_dns_servers {
	# Attempt to retrieve the DNS server addresses configured for this management node
	my $dns_address_string = $ENV{management_node_info}{PUBLIC_DNS_SERVER};
	if (!$dns_address_string) {
		notify($ERRORS{'DEBUG'}, 0, "no public dns server addresses are configured for the management node");
		return ();
	}
	
	return split(/\s*[,;]\s*/, $dns_address_string);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_identity_key_paths

 Parameters  : None
 Returns     : If successful: array containing paths to SSH identity keys
               If failed: false
 Description : Returns an array containing the paths to SSH identity keys
               configured for the management node.

=cut

sub get_management_node_identity_key_paths {
	my $keys_string = $ENV{management_node_info}{keys};
	if (!$keys_string) {
		notify($ERRORS{'WARNING'}, 0, "no identity key paths are configured for the management node");
		return ();
	}
	
	return split(/\s*[,;]\s*/, $keys_string);
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_computer_state_name

 Parameters  : computer name (optional
 Returns     : String containing state name for a particular computer
 Description : Queries database for current computer state and returns the
               state name. The database is queried rather than simply returning
               the value in the data structure in case the computer state
               changed by some other process after the reservation process
               began. This is mainly done for safety in case the computer state
               gets set to maintenance.

=cut


sub get_computer_state_name {
	my $self;
	my $argument = shift;
	my $computer_name;
	
	# Check if subroutine was called as an object method
	if (ref($argument) && $argument->isa('VCL::DataStructure')) {
		# Subroutine was called as an object method, check if an argument was specified
		$self = $argument;
		$argument = shift;
		if ($argument) {
			# Argument was specified, use this as the computer name
			$computer_name = $argument;
		}
		else {
			# Argument was not specified, get the computer short name for this reservation
			$computer_name = $self->get_computer_short_name();
		}
	}
	elsif (ref($argument)) {
		notify($ERRORS{'WARNING'}, 0, "subroutine was called with an illegal argument type: " . ref($argument));
		return;
	}
	else {
		# Subroutine was not called as an object method
		$computer_name = $argument;
	}
	
	# Make sure the computer name was determined either from an argument or the request data
	if (!$computer_name) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine computer name from argument or request data");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to retrieve current state of computer $computer_name from the database");

	# Create the select statement
	my $select_statement = "
   SELECT DISTINCT
	state.name AS name
	FROM
	state,
	computer
	WHERE
	computer.stateid = state.id
	AND (computer.hostname LIKE '$computer_name.%' OR computer.hostname = '$computer_name')
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);

	# Check to make sure 1 row was returned
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "zero rows were returned from database select");
		return ();
	}
	elsif (scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, scalar @selected_rows . " rows were returned from database select");
		return ();
	}

	# Make sure we return undef if the column wasn't found
	if (defined $selected_rows[0]{name}) {
		my $computer_state_name = $selected_rows[0]{name};
		notify($ERRORS{'DEBUG'}, 0, "retrieved current state of computer $computer_name from the database: $computer_state_name");
		$self->set_computer_state_name($computer_state_name);
		return $computer_state_name;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve current state of computer $computer_name from the database");
		return undef;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_info_string

 Parameters  : None.
 Returns     : String
 Description : Assembles a string containing reservation information for
               debugging purposes.

=cut

sub get_reservation_info_string {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}

	my $string;
	
	$string .= "management node: " . (defined($_ = $self->get_management_node_hostname(0)) ? $_ : '<undefined>') . "\n";
	$string .= "reservation PID: $PID\n";
	$string .= "parent vcld PID: " . (defined($_ = getppid()) ? $_ : '<undefined>') . "\n";
	
	my $request_id = $self->get_request_id(0);
	if ($request_id) {
		$string .= "\n";
		
		$string .= "request ID: $request_id\n";
		$string .= "reservation ID: " . (defined($_ = $self->get_reservation_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "request state/laststate: " . (defined($_ = $self->get_request_state_name(0)) ? $_ : '<undefined>') . "/" . (defined($_ = $self->get_request_laststate_name(0)) ? $_ : '<undefined>') . "\n";
		$string .= "request start time: " . (defined($_ = $self->get_request_start_time(0)) ? $_ : '<undefined>') . "\n";
		$string .= "request end time: " . (defined($_ = $self->get_request_end_time(0)) ? $_ : '<undefined>') . "\n";
		$string .= "for imaging: " . (defined($_ = $self->get_request_forimaging(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		$string .= "log ID: " . (defined($_ = $self->get_request_log_id(0)) ? ($_ eq '0' ? 'none' : $_) : '<undefined>') . "\n";
		
		my $reservation_count = $self->get_request_reservation_count(0);
		if (defined($reservation_count) && $reservation_count > 1) {
			$string .= "cluster reservation: yes\n";
			$string .= "reservation count: $reservation_count\n";
			$string .= "parent reservation: " . (defined($_ = $self->get_request_is_cluster_parent(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		}
	}
	
	my $blockrequest_id = $self->get_blockrequest_id(0);
	if ($blockrequest_id) {
		$string .= "\n";
		
		$string .= "blockrequest: " . (defined($_ = $self->get_blockrequest_name(0)) ? $_ : '<undefined>') . "\n";
		$string .= "block request ID: $blockrequest_id\n";
		$string .= "blockrequest image ID: " . (defined($_ = $self->get_blockrequest_image_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "number of machines: " . (defined($_ = $self->get_blockrequest_number_machines(0)) ? $_ : '<undefined>') . "\n";
		$string .= "owner ID: " . (defined($_ = $self->get_blockrequest_owner_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "management node ID: " . (defined($_ = $self->get_blockrequest_management_node_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "processing flag: " . (defined($_ = $self->get_blockrequest_processing(0)) ? $_ : '<undefined>') . "\n";
		$string .= "mode: " . (defined($_ = $self->get_blockrequest_mode(0)) ? $_ : '<undefined>') . "\n";
		$string .= "blocktime ID: " . (defined($_ = $self->get_blocktime_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "blocktime start: " . (defined($_ = $self->get_blocktime_start(0)) ? $_ : '<undefined>') . "\n";
		$string .= "blocktime end: " . (defined($_ = $self->get_blocktime_end(0)) ? $_ : '<undefined>') . "\n";
		$string .= "blocktime processed flag: " . (defined($_ = $self->get_blocktime_processed(0)) ? $_ : '<undefined>') . "\n";
	}
	
	my $computer_id = $self->get_computer_id(0);
	if (defined($computer_id)) {
		$string .= "\n";
		
		$string .= "computer: " . (defined($_ = $self->get_computer_hostname(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer id: $computer_id\n";
		$string .= "computer type: " . (defined($_ = $self->get_computer_type(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer eth0 MAC address: " . (defined($_ = $self->get_computer_eth0_mac_address(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer eth1 MAC address: " . (defined($_ = $self->get_computer_eth1_mac_address(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer private IP address: " . (defined($_ = $self->get_computer_private_ip_address(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer public IP address: " . (defined($_ = $self->get_computer_ip_address(0)) ? $_ : '<undefined>') . "\n";
		$string .= "computer in block allocation: " . (defined($_ = is_inblockrequest($self->get_computer_id(0))) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		$string .= "provisioning module: " . (defined($_ = $self->get_computer_provisioning_module_perl_package(0)) ? $_ : '<undefined>') . "\n";
	
		if ($self->get_computer_type(0) eq 'virtualmachine') {
			$string .= "\n";
			
			$string .= "vm host: " . (defined($_ = $self->get_vmhost_hostname(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm host ID: " . (defined($_ = $self->get_vmhost_id(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm host computer ID: " . (defined($_ = $self->get_vmhost_computer_id(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm profile: " . (defined($_ = $self->get_vmhost_profile_name(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm profile VM path: " . (defined($_ = $self->get_vmhost_profile_vmpath(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm profile repository path: " . (defined($_ = $self->get_vmhost_profile_repository_path(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm profile datastore path: " . (defined($_ = $self->get_vmhost_profile_datastore_path(0)) ? $_ : '<undefined>') . "\n";
			$string .= "vm profile disk type: " . (defined($_ = $self->get_vmhost_profile_vmdisk(0)) ? $_ : '<undefined>') . "\n";
		}
	}
	
	my $image_id = $self->get_image_id(0);
	if (defined($image_id)) {
		$string .= "\n";
		
		$string .= "image: " . (defined($_ = $self->get_image_name(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image display name: " . (defined($_ = $self->get_image_prettyname(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image ID: $image_id\n";
		$string .= "image revision ID: " . (defined($_ = $self->get_imagerevision_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image size: " . (defined($_ = $self->get_image_size(0)) ? $_ : '<undefined>') . " MB\n";
		$string .= "use Sysprep: " . (defined($_ = $self->get_imagemeta_sysprep(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		$string .= "root access: " . (defined($_ = $self->get_imagemeta_rootaccess(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		$string .= "image owner ID: " . (defined($_ = $self->get_image_ownerid(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image owner affiliation: " . (defined($_ = $self->get_image_affiliation_name(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image revision date created: " . (defined($_ = $self->get_imagerevision_date_created(0)) ? $_ : '<undefined>') . "\n";
		$string .= "image revision production: " . (defined($_ = $self->get_imagerevision_production(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
		$string .= "OS module: " . (defined($_ = $self->get_image_os_module_perl_package(0)) ? $_ : '<undefined>') . "\n";
		
		my $imagerevision_comments = $self->get_imagerevision_comments(0);
		$string .= "image revision comments: $imagerevision_comments\n" if $imagerevision_comments;
	}
	
	my $user_id = $self->get_user_id(0);
	if (defined($user_id)) {
		$string .= "\n";
		
		$string .= "user: " . (defined($_ = $self->get_user_login_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "user name: " . (defined($_ = $self->get_user_firstname(0)) ? $_ : '<undefined>') . " " . (defined($_ = $self->get_user_lastname(0)) ? $_ : '<undefined>') . "\n";
		$string .= "user ID: " . (defined($_ = $self->get_user_id(0)) ? $_ : '<undefined>') . "\n";
		$string .= "user affiliation: " . (defined($_ = $self->get_user_affiliation_name(0)) ? $_ : '<undefined>') . "\n";
	}
	
	return $string;
}

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
