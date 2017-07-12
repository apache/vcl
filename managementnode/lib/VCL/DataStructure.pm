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

###############################################################################
package VCL::DataStructure;

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
use English '-no_match_vars';

use Object::InsideOut;
use JSON qw(to_json);
use List::Util qw(min max);
use YAML;
use Storable qw(dclone);

use VCL::utils;

###############################################################################

=head1 CLASS ATTRIBUTES

=cut

=head3 %SUBROUTINE_MAPPINGS

 Data type   : hash
 Description : %SUBROUTINE_MAPPINGS hash maps subroutine names to hash keys.
               It is used by AUTOMETHOD to return the corresponding hash data
               when an undefined subroutine is called on a DataStructure object.

=cut

my %SUBROUTINE_MAPPINGS;

# TODO: Move all keys which don't come straight from the database to the top
$SUBROUTINE_MAPPINGS{process_pid} = '$self->request_data->{PID}';
$SUBROUTINE_MAPPINGS{process_ppid} = '$self->request_data->{PPID}';
$SUBROUTINE_MAPPINGS{image_capture_type} = '$self->request_data->{IMAGE_CAPTURE_TYPE}';
$SUBROUTINE_MAPPINGS{notice_interval} = '$self->request_data->{NOTICE_INTERVAL}';

$SUBROUTINE_MAPPINGS{blockrequest_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{id}';
$SUBROUTINE_MAPPINGS{blockrequest_name} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{name}';
$SUBROUTINE_MAPPINGS{blockrequest_image_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{imageid}';
$SUBROUTINE_MAPPINGS{blockrequest_number_machines} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{numMachines}';
$SUBROUTINE_MAPPINGS{blockrequest_group_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{groupid}';
$SUBROUTINE_MAPPINGS{blockrequest_group_name} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{groupname}';
$SUBROUTINE_MAPPINGS{blockrequest_repeating} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{repeating}';
$SUBROUTINE_MAPPINGS{blockrequest_owner_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{ownerid}';
$SUBROUTINE_MAPPINGS{blockrequest_management_node_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{managementnodeid}';
$SUBROUTINE_MAPPINGS{blockrequest_expire} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{expireTime}';
$SUBROUTINE_MAPPINGS{blockrequest_processing} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{processing}';
$SUBROUTINE_MAPPINGS{blockrequest_mode} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{MODE}';

$SUBROUTINE_MAPPINGS{blockrequest_blocktimes_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{BLOCKTIMES_ID}';

$SUBROUTINE_MAPPINGS{blockrequest_owner_email} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{owner}{email}';
$SUBROUTINE_MAPPINGS{blockrequest_owner_affiliation_helpaddress} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{owner}{affiliation}{helpaddress}';

$SUBROUTINE_MAPPINGS{blockrequest_image_prettyname} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{image}{prettyname}';

$SUBROUTINE_MAPPINGS{blocktime_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{id}';
#$SUBROUTINE_MAPPINGS{blocktime_blockrequest_id} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{blockRequestid}';
$SUBROUTINE_MAPPINGS{blocktime_start} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{start}';
$SUBROUTINE_MAPPINGS{blocktime_end} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{end}';
$SUBROUTINE_MAPPINGS{blocktime_processed} = '$self->blockrequest_data->{BLOCKREQUEST_ID}{blockTimes}{BLOCKTIME_ID}{processed}';

$SUBROUTINE_MAPPINGS{request_check_time} = '$self->request_data->{CHECKTIME}';
$SUBROUTINE_MAPPINGS{request_modified_time} = '$self->request_data->{datemodified}';
$SUBROUTINE_MAPPINGS{request_requested_time} = '$self->request_data->{daterequested}';
$SUBROUTINE_MAPPINGS{request_end_time} = '$self->request_data->{end}';
$SUBROUTINE_MAPPINGS{request_forimaging} = '$self->request_data->{forimaging}';
$SUBROUTINE_MAPPINGS{request_id} = '$self->request_data->{id}';
$SUBROUTINE_MAPPINGS{request_laststate_id} = '$self->request_data->{laststateid}';
$SUBROUTINE_MAPPINGS{request_log_id} = '$self->request_data->{logid}';
$SUBROUTINE_MAPPINGS{request_notice_interval} = '$self->request_data->{NOTICEINTERVAL}';
$SUBROUTINE_MAPPINGS{request_preload} = '$self->request_data->{preload}';
$SUBROUTINE_MAPPINGS{request_preload_only} = '$self->request_data->{PRELOADONLY}';
$SUBROUTINE_MAPPINGS{request_reservation_count} = '$self->request_data->{RESERVATIONCOUNT}';
$SUBROUTINE_MAPPINGS{request_start_time} = '$self->request_data->{start}';
$SUBROUTINE_MAPPINGS{request_duration_epoch} = '$self->request_data->{DURATION}';
$SUBROUTINE_MAPPINGS{request_checkuser} = '$self->request_data->{checkuser}';
#$SUBROUTINE_MAPPINGS{request_stateid} = '$self->request_data->{stateid}';
$SUBROUTINE_MAPPINGS{request_test} = '$self->request_data->{test}';
$SUBROUTINE_MAPPINGS{request_updated} = '$self->request_data->{UPDATED}';
#$SUBROUTINE_MAPPINGS{request_userid} = '$self->request_data->{userid}';
$SUBROUTINE_MAPPINGS{request_state_name} = '$self->request_data->{state}{name}';
$SUBROUTINE_MAPPINGS{request_laststate_name} = '$self->request_data->{laststate}{name}';

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
$SUBROUTINE_MAPPINGS{log_remote_ip} = '$self->request_data->{log}{remoteIP}';
$SUBROUTINE_MAPPINGS{log_imageid} = '$self->request_data->{log}{imageid}';
$SUBROUTINE_MAPPINGS{log_size} = '$self->request_data->{log}{size}';

$SUBROUTINE_MAPPINGS{sublog_id} = '$self->request_data->{reservation}{RESERVATION_ID}{SUBLOG_ID}';

#$SUBROUTINE_MAPPINGS{request_reservationid} = '$self->request_data->{RESERVATIONID}';
$SUBROUTINE_MAPPINGS{reservation_id} = '$self->request_data->{RESERVATIONID}';

#$SUBROUTINE_MAPPINGS{reservation_computerid} = '$self->request_data->{reservation}{RESERVATION_ID}{computerid}';
#$SUBROUTINE_MAPPINGS{reservation_id} = '$self->request_data->{reservation}{RESERVATION_ID}{id}';
#$SUBROUTINE_MAPPINGS{reservation_imageid} = '$self->request_data->{reservation}{RESERVATION_ID}{imageid}';
#$SUBROUTINE_MAPPINGS{reservation_imagerevisionid} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevisionid}';
$SUBROUTINE_MAPPINGS{reservation_lastcheck_time} = '$self->request_data->{reservation}{RESERVATION_ID}{lastcheck}';
$SUBROUTINE_MAPPINGS{reservation_machine_ready} = '$self->request_data->{reservation}{RESERVATION_ID}{MACHINEREADY}';
#$SUBROUTINE_MAPPINGS{reservation_managementnodeid} = '$self->request_data->{reservation}{RESERVATION_ID}{managementnodeid}';
$SUBROUTINE_MAPPINGS{reservation_password} = '$self->request_data->{reservation}{RESERVATION_ID}{pw}';
#$SUBROUTINE_MAPPINGS{reservation_remote_ip} = '$self->request_data->{reservation}{RESERVATION_ID}{remoteIP}';
#$SUBROUTINE_MAPPINGS{reservation_requestid} = '$self->request_data->{reservation}{RESERVATION_ID}{requestid}';
$SUBROUTINE_MAPPINGS{reservation_ready} = '$self->request_data->{reservation}{RESERVATION_ID}{READY}';
$SUBROUTINE_MAPPINGS{reservation_users} = '$self->request_data->{reservation}{RESERVATION_ID}{users}';

$SUBROUTINE_MAPPINGS{computer_data} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}';
$SUBROUTINE_MAPPINGS{computer_current_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimageid}';
$SUBROUTINE_MAPPINGS{computer_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{deleted}';
$SUBROUTINE_MAPPINGS{computer_drive_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{drivetype}';
$SUBROUTINE_MAPPINGS{computer_dsa} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dsa}';
$SUBROUTINE_MAPPINGS{computer_dsa_pub} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{dsapub}';
$SUBROUTINE_MAPPINGS{computer_eth0_mac_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{eth0macaddress}';
$SUBROUTINE_MAPPINGS{computer_eth1_mac_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{eth1macaddress}';
#$SUBROUTINE_MAPPINGS{computer_host} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{host}';
$SUBROUTINE_MAPPINGS{computer_hostname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostname}';
$SUBROUTINE_MAPPINGS{computer_host_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostname}';
#$SUBROUTINE_MAPPINGS{computer_hostpub} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{hostpub}';
$SUBROUTINE_MAPPINGS{computer_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{id}';
$SUBROUTINE_MAPPINGS{computer_imagerevision_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{imagerevisionid}';
$SUBROUTINE_MAPPINGS{computer_lastcheck_time} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{lastcheck}';
$SUBROUTINE_MAPPINGS{computer_location} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{location}';
$SUBROUTINE_MAPPINGS{computer_networking_speed} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{network}';
$SUBROUTINE_MAPPINGS{computer_node_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{NODENAME}';
$SUBROUTINE_MAPPINGS{computer_notes} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{notes}';
$SUBROUTINE_MAPPINGS{computer_owner_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_platform_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{platformid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimageid}';
$SUBROUTINE_MAPPINGS{computer_private_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{privateIPaddress}';
$SUBROUTINE_MAPPINGS{computer_public_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{IPaddress}';
$SUBROUTINE_MAPPINGS{computer_processor_count} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procnumber}';
$SUBROUTINE_MAPPINGS{computer_processor_speed} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{procspeed}';
$SUBROUTINE_MAPPINGS{computer_ram} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{RAM}';
$SUBROUTINE_MAPPINGS{computer_rsa} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsa}';
$SUBROUTINE_MAPPINGS{computer_rsa_pub} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{rsapub}';
$SUBROUTINE_MAPPINGS{computer_schedule_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{scheduleid}';
$SUBROUTINE_MAPPINGS{computer_short_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{computer_state_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{stateid}';
$SUBROUTINE_MAPPINGS{computer_state_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';
$SUBROUTINE_MAPPINGS{computer_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{type}';
$SUBROUTINE_MAPPINGS{computer_provisioning_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioningid}';
$SUBROUTINE_MAPPINGS{computer_vmhost_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhostid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{moduleid}';

$SUBROUTINE_MAPPINGS{computer_provisioning_module_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{name}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_description} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{description}';
$SUBROUTINE_MAPPINGS{computer_provisioning_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{provisioning}{module}{perlpackage}';

$SUBROUTINE_MAPPINGS{computer_predictive_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictiveid}';
$SUBROUTINE_MAPPINGS{computer_predictive_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{name}';
$SUBROUTINE_MAPPINGS{computer_predictive_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_predictive_module_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{id}';

$SUBROUTINE_MAPPINGS{computer_predictive_module_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{name}';
$SUBROUTINE_MAPPINGS{computer_predictive_module_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_predictive_module_description} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{description}';
$SUBROUTINE_MAPPINGS{computer_predictive_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{predictive}{module}{perlpackage}';

$SUBROUTINE_MAPPINGS{nathost_info} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}';
$SUBROUTINE_MAPPINGS{nathost_hostname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{HOSTNAME}';
$SUBROUTINE_MAPPINGS{nathost_date_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{datedeleted}';
$SUBROUTINE_MAPPINGS{nathost_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{deleted}';
$SUBROUTINE_MAPPINGS{nathost_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{id}';
$SUBROUTINE_MAPPINGS{nathost_public_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{publicIPaddress}';
$SUBROUTINE_MAPPINGS{nathost_internal_ip_address} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{internalIPaddress}';
$SUBROUTINE_MAPPINGS{nathost_resource_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{resource}{id}';
$SUBROUTINE_MAPPINGS{nathost_resource_subid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{resource}{subid}';
$SUBROUTINE_MAPPINGS{nathost_resourcetype_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{resource}{resourcetype}{id}';
$SUBROUTINE_MAPPINGS{nathost_resource_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nathost}{resource}{resourcetype}{name}';

$SUBROUTINE_MAPPINGS{vmhost_computer_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computerid}';
$SUBROUTINE_MAPPINGS{vmhost_hostname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{hostname}';
$SUBROUTINE_MAPPINGS{vmhost_short_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{vmhost_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{id}';
$SUBROUTINE_MAPPINGS{vmhost_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{imageid}';
$SUBROUTINE_MAPPINGS{vmhost_image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{image}{name}';
$SUBROUTINE_MAPPINGS{vmhost_ram} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{RAM}';
$SUBROUTINE_MAPPINGS{vmhost_state} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{state}{name}';
#$SUBROUTINE_MAPPINGS{vmhost_type} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{computer}{type}';
$SUBROUTINE_MAPPINGS{vmhost_kernal_nic} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmkernalnic}';
$SUBROUTINE_MAPPINGS{vmhost_vm_limit} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmlimit}';
$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofileid}';

$SUBROUTINE_MAPPINGS{vmhost_profile_repository_path} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{repositorypath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_repository_imagetype_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{repositoryimagetypeid}';
$SUBROUTINE_MAPPINGS{vmhost_profile_datastore_path} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{datastorepath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_repository_imagetype_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{datastoreimagetypeid}';
#$SUBROUTINE_MAPPINGS{vmhost_profile_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{id}';
$SUBROUTINE_MAPPINGS{vmhost_profile_image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{imageid}';
$SUBROUTINE_MAPPINGS{vmhost_profile_resource_path} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{resourcepath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_folder_path} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{folderpath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{profilename}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch0} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch0}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch1} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch1}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch2} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch2}';
$SUBROUTINE_MAPPINGS{vmhost_profile_virtualswitch3} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{virtualswitch3}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmdisk} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmdisk}';
$SUBROUTINE_MAPPINGS{vmhost_profile_vmpath} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{vmpath}';
$SUBROUTINE_MAPPINGS{vmhost_profile_username} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{username}';
#$SUBROUTINE_MAPPINGS{vmhost_profile_password} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{password}';
$SUBROUTINE_MAPPINGS{vmhost_profile_eth0generated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{eth0generated}';
$SUBROUTINE_MAPPINGS{vmhost_profile_eth1generated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{eth1generated}';
$SUBROUTINE_MAPPINGS{vmhost_profile_secret_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{vmprofile}{secretid}';

$SUBROUTINE_MAPPINGS{vmhost_repository_imagetype_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{repositoryimagetype}{name}';
$SUBROUTINE_MAPPINGS{vmhost_datastore_imagetype_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{vmhost}{datastoreimagetype}{name}';

$SUBROUTINE_MAPPINGS{computer_currentimage_data} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_data} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}';
$SUBROUTINE_MAPPINGS{computer_currentimage_architecture} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_currentimage_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_currentimage_forcheckout} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_currentimage_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{id}';
$SUBROUTINE_MAPPINGS{computer_currentimage_imagemetaid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_lastupdate} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxconcurrent} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_currentimage_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minnetwork} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocnumber} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minprocspeed} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_currentimage_minram} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_currentimage_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_currentimage_osid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{OSid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_ownerid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_platformid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{platformid}';
$SUBROUTINE_MAPPINGS{computer_currentimage_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_currentimage_project} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{project}';
$SUBROUTINE_MAPPINGS{computer_currentimage_reloadtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{reloadtime}';
$SUBROUTINE_MAPPINGS{computer_currentimage_size} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{size}';
$SUBROUTINE_MAPPINGS{computer_currentimage_test} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimage}{test}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_comments} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{comments}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_datecreated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{id}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_imageid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imageid}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_imagename} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_production} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{production}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_revision} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{revision}';
$SUBROUTINE_MAPPINGS{computer_currentimagerevision_userid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{currentimagerevision}{userid}';

$SUBROUTINE_MAPPINGS{computer_platform_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{platform}{name}';

$SUBROUTINE_MAPPINGS{computer_nextimage_architecture} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{architecture}';
$SUBROUTINE_MAPPINGS{computer_nextimage_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{deleted}';
$SUBROUTINE_MAPPINGS{computer_nextimage_forcheckout} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{forcheckout}';
$SUBROUTINE_MAPPINGS{computer_nextimage_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{id}';
$SUBROUTINE_MAPPINGS{computer_nextimage_imagemetaid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{imagemetaid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_lastupdate} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{lastupdate}';
$SUBROUTINE_MAPPINGS{computer_nextimage_maxconcurrent} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{computer_nextimage_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minnetwork} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minnetwork}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minprocnumber} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minprocnumber}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minprocspeed} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minprocspeed}';
$SUBROUTINE_MAPPINGS{computer_nextimage_minram} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{minram}';
$SUBROUTINE_MAPPINGS{computer_nextimage_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_nextimage_osid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{OSid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_ownerid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{ownerid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_platformid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{platformid}';
$SUBROUTINE_MAPPINGS{computer_nextimage_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{prettyname}';
$SUBROUTINE_MAPPINGS{computer_nextimage_project} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{project}';
$SUBROUTINE_MAPPINGS{computer_nextimage_reloadtime} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{reloadtime}';
$SUBROUTINE_MAPPINGS{computer_nextimage_size} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{size}';
$SUBROUTINE_MAPPINGS{computer_nextimage_test} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimage}{test}';

$SUBROUTINE_MAPPINGS{computer_nextimagerevision_comments} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{comments}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_datecreated} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_id} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{id}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_imageid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imageid}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_imagename} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_production} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{production}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_revision} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{revision}';
$SUBROUTINE_MAPPINGS{computer_nextimagerevision_userid} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{nextimagerevision}{userid}';

$SUBROUTINE_MAPPINGS{computer_schedule_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{schedule}{name}';
$SUBROUTINE_MAPPINGS{computer_state_name} = '$self->request_data->{reservation}{RESERVATION_ID}{computer}{state}{name}';

$SUBROUTINE_MAPPINGS{image_architecture} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{architecture}';
$SUBROUTINE_MAPPINGS{image_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{deleted}';
$SUBROUTINE_MAPPINGS{image_forcheckout} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{forcheckout}';
$SUBROUTINE_MAPPINGS{image_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{id}';
$SUBROUTINE_MAPPINGS{image_identity} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{IDENTITY}';
$SUBROUTINE_MAPPINGS{image_imagemetaid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemetaid}';
$SUBROUTINE_MAPPINGS{image_lastupdate} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{lastupdate}';
$SUBROUTINE_MAPPINGS{image_maxconcurrent} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{maxconcurrent}';
$SUBROUTINE_MAPPINGS{image_maxinitialtime} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{maxinitialtime}';
$SUBROUTINE_MAPPINGS{image_minnetwork} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minnetwork}';
$SUBROUTINE_MAPPINGS{image_minprocnumber} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minprocnumber}';
$SUBROUTINE_MAPPINGS{image_minprocspeed} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minprocspeed}';
#$SUBROUTINE_MAPPINGS{image_minram} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{minram}';
#$SUBROUTINE_MAPPINGS{image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{name}';
#$SUBROUTINE_MAPPINGS{image_osid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OSid}';
$SUBROUTINE_MAPPINGS{image_os_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OSid}';
$SUBROUTINE_MAPPINGS{image_ownerid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{ownerid}';
$SUBROUTINE_MAPPINGS{image_platformid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{platformid}';
$SUBROUTINE_MAPPINGS{image_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{prettyname}';
$SUBROUTINE_MAPPINGS{image_project} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{project}';
$SUBROUTINE_MAPPINGS{image_reload_time} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{reloadtime}';
$SUBROUTINE_MAPPINGS{image_settestflag} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{SETTESTFLAG}';
$SUBROUTINE_MAPPINGS{image_size} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{size}';
$SUBROUTINE_MAPPINGS{image_test} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{test}';
$SUBROUTINE_MAPPINGS{image_updateimagename} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{UPDATEIMAGENAME}';

$SUBROUTINE_MAPPINGS{imagemeta_checkuser} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{checkuser}';
$SUBROUTINE_MAPPINGS{imagemeta_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{id}';
$SUBROUTINE_MAPPINGS{imagemeta_postoption} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{postoption}';
$SUBROUTINE_MAPPINGS{imagemeta_subimages} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{subimages}';
$SUBROUTINE_MAPPINGS{imagemeta_sysprep} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{sysprep}';
$SUBROUTINE_MAPPINGS{imagemeta_rootaccess} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{rootaccess}';
$SUBROUTINE_MAPPINGS{imagemeta_sethostname} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagemeta}{sethostname}';
  
#$SUBROUTINE_MAPPINGS{image_domain_dns_servers} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{dnsServers}'; # Explicit subroutine
$SUBROUTINE_MAPPINGS{image_domain_dns_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{domainDNSName}';
$SUBROUTINE_MAPPINGS{image_domain_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{id}';
$SUBROUTINE_MAPPINGS{image_domain_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{name}';
$SUBROUTINE_MAPPINGS{image_domain_owner_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{ownerid}';
#$SUBROUTINE_MAPPINGS{image_domain_password} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{password}'; # Explicit subroutine
$SUBROUTINE_MAPPINGS{image_domain_secret_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{secretid}';
$SUBROUTINE_MAPPINGS{image_domain_username} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{username}';
$SUBROUTINE_MAPPINGS{image_domain_base_ou} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{imageaddomain}{baseOU}';
$SUBROUTINE_MAPPINGS{image_domain_cryptsecret} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagedomain}{cryptsecret}{cryptsecret}';

$SUBROUTINE_MAPPINGS{image_os_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{name}';
$SUBROUTINE_MAPPINGS{image_os_prettyname} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{prettyname}';
$SUBROUTINE_MAPPINGS{image_os_type} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{type}';
$SUBROUTINE_MAPPINGS{image_os_install_type} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{installtype}';
$SUBROUTINE_MAPPINGS{image_os_minram} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{minram}';
$SUBROUTINE_MAPPINGS{image_os_source_path} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{sourcepath}';
$SUBROUTINE_MAPPINGS{image_os_moduleid} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{moduleid}';

$SUBROUTINE_MAPPINGS{image_os_module_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{name}';
$SUBROUTINE_MAPPINGS{image_os_module_pretty_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{prettyname}';
$SUBROUTINE_MAPPINGS{image_os_module_description} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{description}';
$SUBROUTINE_MAPPINGS{image_os_module_perl_package} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{module}{perlpackage}';

$SUBROUTINE_MAPPINGS{image_os_type_id} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{OStype}{id}';
$SUBROUTINE_MAPPINGS{image_os_type_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{OS}{OStype}{name}';

$SUBROUTINE_MAPPINGS{image_platform_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{platform}{name}';

$SUBROUTINE_MAPPINGS{imagetype_name} = '$self->request_data->{reservation}{RESERVATION_ID}{image}{imagetype}{name}';

$SUBROUTINE_MAPPINGS{server_request_id} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{id}';
$SUBROUTINE_MAPPINGS{server_request_fixed_ip} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{fixedIP}';
$SUBROUTINE_MAPPINGS{server_request_router} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{router}';
$SUBROUTINE_MAPPINGS{server_request_netmask} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{netmask}';
$SUBROUTINE_MAPPINGS{server_request_dns_servers} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{DNSservers}';
$SUBROUTINE_MAPPINGS{server_request_fixed_mac} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{fixedMAC}';
$SUBROUTINE_MAPPINGS{server_request_admingroupid} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{admingroupid}';
$SUBROUTINE_MAPPINGS{server_request_logingroupid} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{logingroupid}';
$SUBROUTINE_MAPPINGS{server_request_monitored} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{monitored}';
$SUBROUTINE_MAPPINGS{server_allow_users} = '$self->request_data->{reservation}{RESERVATION_ID}{serverrequest}{ALLOW_USERS}';

$SUBROUTINE_MAPPINGS{imagerevision_comments} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{comments}';
$SUBROUTINE_MAPPINGS{imagerevision_date_created} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{datecreated}';
$SUBROUTINE_MAPPINGS{imagerevision_deleted} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{deleted}';
$SUBROUTINE_MAPPINGS{imagerevision_id} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{id}';
$SUBROUTINE_MAPPINGS{imagerevision_imageid} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imageid}';
#$SUBROUTINE_MAPPINGS{imagerevision_imagename} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{image_name} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{imagename}';
$SUBROUTINE_MAPPINGS{imagerevision_production} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{production}';
$SUBROUTINE_MAPPINGS{imagerevision_revision} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{revision}';
$SUBROUTINE_MAPPINGS{imagerevision_userid} = '$self->request_data->{reservation}{RESERVATION_ID}{imagerevision}{userid}';

$SUBROUTINE_MAPPINGS{connect_methods} = '$self->request_data->{reservation}{RESERVATION_ID}{connect_methods}';

$SUBROUTINE_MAPPINGS{user_adminlevelid} = '$self->request_data->{user}{adminlevelid}';
$SUBROUTINE_MAPPINGS{user_affiliationid} = '$self->request_data->{user}{affiliationid}';
$SUBROUTINE_MAPPINGS{user_audiomode} = '$self->request_data->{user}{audiomode}';
$SUBROUTINE_MAPPINGS{user_bpp} = '$self->request_data->{user}{bpp}';
$SUBROUTINE_MAPPINGS{user_email} = '$self->request_data->{user}{email}';
$SUBROUTINE_MAPPINGS{user_emailnotices} = '$self->request_data->{user}{emailnotices}';
$SUBROUTINE_MAPPINGS{user_firstname} = '$self->request_data->{user}{firstname}';
$SUBROUTINE_MAPPINGS{user_height} = '$self->request_data->{user}{height}';
$SUBROUTINE_MAPPINGS{user_id} = '$self->request_data->{user}{id}';
$SUBROUTINE_MAPPINGS{user_im_id} = '$self->request_data->{user}{IMid}';
$SUBROUTINE_MAPPINGS{user_imtypeid} = '$self->request_data->{user}{IMtypeid}';
$SUBROUTINE_MAPPINGS{user_lastname} = '$self->request_data->{user}{lastname}';
$SUBROUTINE_MAPPINGS{user_lastupdated} = '$self->request_data->{user}{lastupdated}';
$SUBROUTINE_MAPPINGS{user_mapdrives} = '$self->request_data->{user}{mapdrives}';
$SUBROUTINE_MAPPINGS{user_mapprinters} = '$self->request_data->{user}{mapprinters}';
$SUBROUTINE_MAPPINGS{user_mapserial} = '$self->request_data->{user}{mapserial}';
$SUBROUTINE_MAPPINGS{user_preferred_name} = '$self->request_data->{user}{preferredname}';
$SUBROUTINE_MAPPINGS{user_showallgroups} = '$self->request_data->{user}{showallgroups}';
$SUBROUTINE_MAPPINGS{user_uid} = '$self->request_data->{user}{uid}';
#$SUBROUTINE_MAPPINGS{user_unityid} = '$self->request_data->{user}{unityid}';
$SUBROUTINE_MAPPINGS{user_login_id} = '$self->request_data->{user}{unityid}';
$SUBROUTINE_MAPPINGS{user_width} = '$self->request_data->{user}{width}';
$SUBROUTINE_MAPPINGS{user_adminlevel_name} = '$self->request_data->{user}{adminlevel}{name}';
$SUBROUTINE_MAPPINGS{user_affiliation_dataupdatetext} = '$self->request_data->{user}{affiliation}{dataUpdateText}';
#$SUBROUTINE_MAPPINGS{user_affiliation_helpaddress} = '$self->request_data->{user}{affiliation}{helpaddress}';
$SUBROUTINE_MAPPINGS{user_affiliation_name} = '$self->request_data->{user}{affiliation}{name}';
#$SUBROUTINE_MAPPINGS{user_affiliation_sitewwwaddress} = '$self->request_data->{user}{affiliation}{sitewwwaddress}';
$SUBROUTINE_MAPPINGS{user_imtype_name} = '$self->request_data->{user}{IMtype}{name}';
$SUBROUTINE_MAPPINGS{user_use_public_keys} = '$self->request_data->{user}{usepublickeys}';
$SUBROUTINE_MAPPINGS{user_ssh_public_keys} = '$self->request_data->{user}{sshpublickeys}';

$SUBROUTINE_MAPPINGS{management_node_id} = '$ENV{management_node_info}{id}';
$SUBROUTINE_MAPPINGS{management_node_ipaddress} = '$ENV{management_node_info}{IPaddress}';
$SUBROUTINE_MAPPINGS{management_node_hostname} = '$ENV{management_node_info}{hostname}';
$SUBROUTINE_MAPPINGS{management_node_ownerid} = '$ENV{management_node_info}{ownerid}';
$SUBROUTINE_MAPPINGS{management_node_stateid} = '$ENV{management_node_info}{stateid}';
$SUBROUTINE_MAPPINGS{management_node_lastcheckin} = '$ENV{management_node_info}{lastcheckin}';
$SUBROUTINE_MAPPINGS{management_node_checkininterval} = '$ENV{management_node_info}{checkininterval}';
$SUBROUTINE_MAPPINGS{management_node_install_path} = '$ENV{management_node_info}{installpath}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_enable} = '$ENV{management_node_info}{imagelibenable}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_group_id} = '$ENV{management_node_info}{imagelibgroupid}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_user} = '$ENV{management_node_info}{imagelibuser}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_key} = '$ENV{management_node_info}{imagelibkey}';
$SUBROUTINE_MAPPINGS{management_node_keys} = '$ENV{management_node_info}{keys}';
$SUBROUTINE_MAPPINGS{management_node_image_lib_partners} = '$ENV{management_node_info}{IMAGELIBPARTNERS}';
$SUBROUTINE_MAPPINGS{management_node_short_name} = '$ENV{management_node_info}{SHORTNAME}';
$SUBROUTINE_MAPPINGS{management_node_state_name} = '$ENV{management_node_info}{state}{name}';
$SUBROUTINE_MAPPINGS{management_node_os_name} = '$ENV{management_node_info}{OSNAME}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_id} = '$ENV{management_node_info}{predictivemoduleid}';
$SUBROUTINE_MAPPINGS{management_node_ssh_port} = '$ENV{management_node_info}{sshport}';

$SUBROUTINE_MAPPINGS{management_node_public_ip_configuration} = '$ENV{management_node_info}{PUBLIC_IP_CONFIGURATION}';
$SUBROUTINE_MAPPINGS{management_node_public_subnet_mask} = '$ENV{management_node_info}{PUBLIC_SUBNET_MASK}';
#$SUBROUTINE_MAPPINGS{management_node_public_default_gateway} = '$ENV{management_node_info}{PUBLIC_DEFAULT_GATEWAY}';
$SUBROUTINE_MAPPINGS{management_node_public_dns_server} = '$ENV{management_node_info}{PUBLIC_DNS_SERVER}';

$SUBROUTINE_MAPPINGS{management_node_sysadmin_email}	= '$ENV{management_node_info}{SYSADMIN_EMAIL}';
$SUBROUTINE_MAPPINGS{management_node_shared_email_box} = '$ENV{management_node_info}{SHARED_EMAIL_BOX}';

$SUBROUTINE_MAPPINGS{management_node_predictive_module_name} = '$ENV{management_node_info}{predictive_name}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_pretty_name} = '$ENV{management_node_info}{predictive_prettyname}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_description} = '$ENV{management_node_info}{predictive_description}';
$SUBROUTINE_MAPPINGS{management_node_predictive_module_perl_package} = '$ENV{management_node_info}{predictive_perlpackage}';

$SUBROUTINE_MAPPINGS{subroutine_mappings} = '\%SUBROUTINE_MAPPINGS';

###############################################################################

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

=head3 @computer_identifier

 Data type   : array of scalars
 Description :

=cut

my @computer_identifier : Field : Arg('Name' => 'computer_identifier') : Type(scalar) : Get('Name' => 'computer_identifier', 'Private' => 1);

=head3 @vmhost_identifier

 Data type   : array of scalars
 Description :

=cut

my @vmhost_identifier : Field : Arg('Name' => 'vmhost_identifier') : Type(scalar) : Get('Name' => 'vmhost_identifier', 'Private' => 1);

=head3 @image_identifier

 Data type   : array of scalars
 Description :

=cut

my @image_identifier : Field : Arg('Name' => 'image_identifier') : Type(scalar) : Get('Name' => 'image_identifier', 'Private' => 1);

=head3 @image_identifier

 Data type   : array of scalars
 Description :

=cut

my @imagerevision_identifier : Field : Arg('Name' => 'imagerevision_identifier') : Type(scalar) : Get('Name' => 'imagerevision_identifier', 'Private' => 1);

=head3 @mn_os

 Data type   : array of scalars
 Description :

=cut

my @mn_os : Field : Arg('Name' => 'mn_os') : Get('Name' => 'mn_os', 'Private' => 1) : Set('Name' => 'set_mn_os');


###############################################################################

=head1 PRIVATE OBJECT METHODS

=cut

=head2 initialize

 Parameters  : none
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
	
	# Replace the request data with a deep copy if itself
	# This creates entirely separate copies in case multiple DataStructure objects are used
	# If not deep copied, the separate objects will alter each other's data
	$self->refresh_request_data(dclone($self->request_data)) if $self->request_data;
	
	# Set the request and reservation IDs in the request data hash if they are undefined
	$self->request_data->{id} = ($self->request_id || 0) if (!defined($self->request_data->{id}));
	$self->request_data->{RESERVATIONID} = ($self->reservation_id || 0) if (!defined($self->request_data->{RESERVATIONID}));
	if ($self->request_data->{RESERVATIONID} == 0) {
		$self->request_data->{reservation}{0}{serverrequest}{id} = 0;
		$self->request_data->{forimaging} = 0;
		$self->request_data->{state}{name} = "available";
		
	}

	my $computer_identifier = $self->computer_identifier;
	my $vmhost_identifier = $self->vmhost_identifier;
	my $image_identifier = $self->image_identifier;
	my $imagerevision_identifier = $self->imagerevision_identifier;
	
	# Get the computer info if the computer_identifier argument was specified and add it to this object
	if ($computer_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "computer identifier argument was specified, retrieving data for computer: $computer_identifier");
		my $computer_info = get_computer_info($computer_identifier, 1);
		if (!$computer_info) {
			notify($ERRORS{'WARNING'}, 0, "DataStructure object could not be initialized, failed to retrieve data for computer: $computer_identifier");
			
			# Throw an exception because simply returning undefined (return;) does not result in this DataStructure object being undefined
			Exception::Class::Base->throw(error => "DataStructure object could not be initialized, failed to retrieve data for computer: $computer_identifier");
			return;
		}
		
		$self->request_data->{reservation}{$self->reservation_id}{computer} = $computer_info;
	}
	
	# Get the VM host info if the $vmhost_identifier argument was specified and add it to this object
	if ($vmhost_identifier) {
		notify($ERRORS{'DEBUG'}, 0, "VM host identifier argument was specified, retrieving data for VM host: $vmhost_identifier");
		my $vmhost_info = get_vmhost_info($vmhost_identifier, 1);
		if (!$vmhost_info) {
			notify($ERRORS{'WARNING'}, 0, "DataStructure object could not be initialized, failed to retrieve data for VM host: $vmhost_identifier");
			
			# Throw an exception because simply returning undefined (return;) does not result in this DataStructure object being undefined
			Exception::Class::Base->throw(error => "DataStructure object could not be initialized, failed to retrieve data for VM host: $vmhost_identifier");
			return;
		}
		$self->request_data->{reservation}{$self->reservation_id}{computer}{vmhost} = $vmhost_info;
	}

	# If either the computer, image, or imagerevision identifier arguments are specified, retrieve appropriate image and imagerevision data
	if (defined($imagerevision_identifier) || defined($image_identifier) || defined($computer_identifier)) {
		my $imagerevision_info;
		
		if (defined($imagerevision_identifier)) {
			$imagerevision_identifier = 'noimage' if !$imagerevision_identifier;
			notify($ERRORS{'DEBUG'}, 0, "imagerevision identifier argument was specified: $imagerevision_identifier, DataStructure object will contain image information for this imagerevision: $imagerevision_identifier");
			$imagerevision_info = get_imagerevision_info($imagerevision_identifier);
		}
		elsif (defined($image_identifier)) {
			$image_identifier = 'noimage' if !$image_identifier;
			notify($ERRORS{'DEBUG'}, 0, "image identifier argument was specified: $image_identifier, DataStructure object will contain image information for the production imagerevision of this image");
			$imagerevision_info = get_production_imagerevision_info($image_identifier);
		}
		elsif (defined($computer_identifier)) {
			my $imagerevision_id = $self->get_computer_imagerevision_id();
			if (defined($imagerevision_id)) {
				notify($ERRORS{'DEBUG'}, 0, "computer identifier argument was specified ($computer_identifier) but image and imagerevision ID arguments were not, DataStructure object will contain image information for the computer's current imagerevision ID: $imagerevision_id");
				if (!$imagerevision_id) {
					notify($ERRORS{'DEBUG'}, 0, "computer identifier argument was specified ($computer_identifier) imagerevision_id is set to $imagerevision_id");
					my $image_id = $self->get_computer_currentimage_id();
					if (defined($image_id)) {
						$imagerevision_info = get_production_imagerevision_info($image_id);
					}
					else {
						Exception::Class::Base->throw(error => "DataStructure object could not be initialized, computer's current imagerevision ID could not be retrieved from the current DataStructure data:\n" . format_data($self->get_request_data));
						return;
					}
				}
				else {
					$imagerevision_info = get_imagerevision_info($imagerevision_id);
				}
			}
			else {
				Exception::Class::Base->throw(error => "DataStructure object could not be initialized, computer's current imagerevision ID could not be retrieved from the current DataStructure data:\n" . format_data($self->get_request_data));
				return;
			}
		}
		
		if ($imagerevision_info) {
			my $imagerevision_id = $imagerevision_info->{id};
			notify($ERRORS{'DEBUG'}, 0, "retrieved data for imagerevision ID: $imagerevision_id");
			$self->request_data->{reservation}{$self->reservation_id}{imagerevision} = $imagerevision_info;
		}
		else {
			Exception::Class::Base->throw(error => "DataStructure object could not be initialized, failed to retrieve imagerevision data");
			return;
		}
		
		my $image_id = $imagerevision_info->{imageid};
		if (!defined($image_id)) {
			Exception::Class::Base->throw(error => "DataStructure object could not be initialized, failed to retrieve image ID from the imagerevision data:\n" . format_data($imagerevision_info));
			return;
		}
		
		my $image_info = get_image_info($image_id);
		if ($image_info) {
			notify($ERRORS{'DEBUG'}, 0, "retrieved data for image ID: $image_id");
			$self->request_data->{reservation}{$self->reservation_id}{image} = $image_info;
		}
		else {
			Exception::Class::Base->throw(error => "DataStructure object could not be initialized, failed to retrieve data for image ID: " . $self->image_id);
			return;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 automethod

 Parameters  : $show_warnings (optional)
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
		notify($ERRORS{'WARNING'}, 0, "data structure $method_name function was called without an argument");
		return sub { };
	}
	elsif ($mode =~ /get/ && defined $args[0] && !$args[0]) {
		$show_warnings = 0;
	}
	
	my $calling_subroutine = get_calling_subroutine();

	# Check if the sub name is defined in the subroutine mappings hash
	# Return if it isn't
	if (!defined $SUBROUTINE_MAPPINGS{$data_identifier}) {
		if ($calling_subroutine eq 'VCL::DataStructure::can') {
			return;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "unsupported subroutine name: $method_name");
			return sub { };
		}
	}
	elsif ($calling_subroutine eq 'VCL::DataStructure::can') {
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
				if (eval "defined $hash_path") {
					$return_value = eval $hash_path;
					notify($ERRORS{'DEBUG'}, 0, "log data was retrieved and corresponding data has been initialized for $method_name: $return_value");
				}
				else {
					notify($ERRORS{'WARNING'}, 0, "log data was retrieved but corresponding data has not been initialized for $method_name: $hash_path", $self->request_data) if $show_warnings;
					return sub { };
				}
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "log data could not be retrieved");
				return sub { };
			}
		}
		elsif ($data_identifier =~ /^(management_node)/) {
			# Get the management node info
			# If no argument was specified get_management_node_info will return data for this management node
			my $management_node_info_retrieved = get_management_node_info($args[0]);
			unless ($management_node_info_retrieved) {
				notify($ERRORS{'WARNING'}, 0, "failed to retrieve data for management node");
				return sub { };
			}
			
			# The normal reservation management node data is stored in $ENV{management_node_info}{<identifier>}
			# We don't want to overwrite this, but want to temporarily store the data retrieved
			# This allows the $hash_path mechanism to work without alterations
			# Temporarily overwrite this data by using 'local', and set it to the data just retrieved
			# Once the current scope is exited, $ENV{management_node_info} will return to its original value
			local $ENV{management_node_info} = $management_node_info_retrieved;
			
			# Attempt to retrieve the value from the temporary data: $ENV{management_node_info}{KEY}
			$return_value = eval $hash_path;
		}
		elsif (!$key_defined) {
			if ($show_warnings && $hash_path !~ /(serverrequest|domain)/) {
				notify($ERRORS{'WARNING'}, 0, "corresponding data has not been initialized for $method_name: $hash_path", $self->request_data);
			}
			return sub { };
		}
		else {
			# Just attempt to retrieve the value from the hash path
			$return_value = eval $hash_path;
		}
		
		if (!defined $return_value) {
			if ($show_warnings && $method_name !~ /^(get_management_node_keys)$/) {
				notify($ERRORS{'WARNING'}, 0, "corresponding data is undefined for $method_name: $hash_path");
			}
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
			#notify($ERRORS{'DEBUG'}, 0, "data structure updated, hash path: $hash_path, data identifier: $data_identifier");
			return sub {1;};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "data structure could not be updated, hash path: $hash_path, data identifier: $data_identifier, data:\n" . format_data($set_data));
			return sub {0;};
		}
	} ## end elsif ($mode =~ /set/)  [ if ($mode =~ /get/)
} ## end sub _automethod :

#//////////////////////////////////////////////////////////////////////////////

=head2 get_request_data (deprecated)

 Parameters  : none
 Returns     : scalar
 Description : Returns the request data hash.

=cut

sub get_request_data {
	my $self = shift;
	return $self->request_data;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 can

 Parameters  : $function_name
 Returns     : boolean
 Description : Determines if this module supports a particular function.

=cut

sub can {
	my $self = shift;
	
	my $function_name = shift;
	if (!defined($function_name)) {
		notify($ERRORS{'WARNING'}, 0, "function name argument is not implemented");
		return;
	}
	
	if ($self->SUPER::can($function_name)) {
		#notify($ERRORS{'DEBUG'}, 0, "function is implemented: $function_name");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "function is NOT implemented: $function_name");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 refresh

 Parameters  : none
 Returns     : true
 Description : Retrieves current request info from the database and replaces the
               data contained in this object.

=cut

sub refresh {
	my $self = shift;

	# Save the current state names
	my $request_id             = $self->get_request_id();
	my $request_state_name     = $self->get_request_state_name();
	my $request_laststate_name = $self->get_request_laststate_name();

	# Get the full set of database data for this request
	if (my $request_info = get_request_info($request_id)) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved current request information from database for request $request_id");

		# Set the state names in the newly retrieved hash to their original values
		$request_info->{state}{name}     = $request_state_name;
		$request_info->{laststate}{name} = $request_laststate_name;

		# Replace the request data for this DataStructure object
		$self->refresh_request_data($request_info);
		notify($ERRORS{'DEBUG'}, 0, "updated DataStructure object with current request information from database");

	}
	else {
		notify($ERRORS{'WARNING'}, 0, "could not retrieve current request information from database");
		return;
	}
	
	return 1;
} ## end sub refresh

#//////////////////////////////////////////////////////////////////////////////

=head2 get_blockrequest_data (deprecated)

 Parameters  : none
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_count

 Parameters  : none
 Returns     : scalar
 Description : Returns the number of reservations for the request
               associated with this reservation's DataStructure object.

=cut

sub get_reservation_count {
	my $self = shift;

	my $reservation_count = scalar keys %{$self->request_data->{reservation}};
	return $reservation_count;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_ids

 Parameters  : none
 Returns     : array
 Description : Returns an array containing all reservation IDs for the current
               request sorted from lowest to highest.

=cut

sub get_reservation_ids {
	my $self = shift;
	
	my @reservation_ids = sort {$a <=> $b} keys %{$self->request_data->{reservation}};
	return @reservation_ids;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_child_reservation_ids

 Parameters  : none
 Returns     : array
 Description : Returns an array containing all child reservation IDs for the
               current request sorted from lowest to highest. The parent
               reservation id is omitted.

=cut

sub get_child_reservation_ids {
	my $self = shift;
	my $parent_reservation_id = $self->get_parent_reservation_id();
	my @reservation_ids = $self->get_reservation_ids();
	my @child_reservation_ids = grep { $_ ne $parent_reservation_id } @reservation_ids;
	return @child_reservation_ids;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_parent_reservation_id

 Parameters  : none
 Returns     : integer
 Description : Returns the reservation ID for the parent reservation of a
               cluster request.

=cut

sub get_parent_reservation_id {
	my $self = shift;
	
	# The parent reservation has the lowest ID
	return min $self->get_reservation_ids();
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_parent_reservation

 Parameters  : none
 Returns     : scalar, either 1 or 0
 Description : This subroutine returns 1 if this is the parent reservation for
               the request or if the request has 1 reservation associated with
               it. It returns 0 if there are multiple reservations associated
               with the request and this reservation is a child.

=cut

sub is_parent_reservation {
	my $self = shift;
	
	my $reservation_id  = $self->get_reservation_id();
	my $parent_reservation_id = $self->get_parent_reservation_id();

	if ($reservation_id == $parent_reservation_id) {
		notify($ERRORS{'DEBUG'}, 0, "this is the parent reservation");
		return 1;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "this is a child reservation, parent reservation ID for this request: $parent_reservation_id");
		return 0;
	}
} ## end sub is_parent_reservation

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 set_reservation_remote_ip

 Parameters  : $remote_ip
 Returns     : boolean
 Description : Updates the reservation.remoteIP value in the database.

=cut

sub set_reservation_remote_ip {
	my $self = shift;
	my $reservation_id = $self->get_reservation_id();
	
	my $remote_ip = shift;
	
	# Check to make sure reservation ID was passed
	if (!$remote_ip) {
		notify($ERRORS{'WARNING'}, 0, "remote IP address argument was not specified");
		return 0;
	}
	
	# Set the current value in the request data hash
	$self->request_data->{reservation}{$reservation_id}{remoteIP} = $remote_ip;
	
	my $update_statement = <<EOF;
UPDATE
reservation
SET
remoteIP = '$remote_ip'
WHERE
id = '$reservation_id'
EOF
	
	# Call the database execute subroutine
	if (database_execute($update_statement)) {
		notify($ERRORS{'OK'}, 0, "remote IP updated to $remote_ip for reservation $reservation_id");
		return 1;
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "failed to update remote IP to $remote_ip for reservation $reservation_id");
		return 0;
	}
} ## end sub set_reservation_remote_ip

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_remote_ip

 Parameters  : none
 Returns     : string
 Description : 

=cut

sub get_reservation_remote_ip {
	my $self = shift;
	my $reservation_id = $self->get_reservation_id();

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
		#notify($ERRORS{'OK'}, 0, "reservation remote IP is not defined");
		return 0;
	}
	
	# Make sure we return 0 if remote IP is blank
	elsif ($selected_rows[0]{remoteIP} eq '') {
		#notify($ERRORS{'OK'}, 0, "reservation remote IP is not set");
		return 0;
	}
	
	# Set the current value in the request data hash
	$self->request_data->{reservation}{$reservation_id}{remoteIP} = $selected_rows[0]{remoteIP};

	notify($ERRORS{'DEBUG'}, 0, "retrieved remote IP for reservation $reservation_id: $selected_rows[0]{remoteIP}");
	return $selected_rows[0]{remoteIP};
} ## end sub get_reservation_remote_ip

#//////////////////////////////////////////////////////////////////////////////

=head2 get_state_name

 Parameters  : none
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_next_image_data_structure

 Parameters  : none
 Returns     : array 
 Description : called mainly from reclaim module. Refreshes predictive load 
               module information from database, loads module and calls next_image. 

=cut

sub get_next_image_data_structure {
	my $self = shift;
	
	# Get the current image data in case something goes wrong
	my $image_name = $self->get_image_name();
	my $image_id = $self->get_image_id();
	my $imagerevision_id = $self->get_imagerevision_id();
	
	# Assemble an array with the current image information
	# This will be returned if the predictive method fails
	my @current_image;
	if ($image_name && $image_id && $imagerevision_id) {
		@current_image = ("reload", $image_name, $image_id, $imagerevision_id);
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to obtain current image information");
      @current_image = ();
	}
	
	#collect predictive reload information from database.
	my $computer_predictive_module_id = $self->get_computer_predictive_module_id();
	if (!$computer_predictive_module_id) {
		notify($ERRORS{'CRITICAL'}, 0, "unable to obtain management node info for this node, returning current reservation image information");
      return @current_image;
	}

	#update ENV in case other modules need to know
	my $management_node_info = get_management_node_info();
	
	$management_node_info->{predictivemoduleid} = $self->get_computer_predictive_module_id();
	$management_node_info->{predictive_name} = $self->get_computer_predictive_module_name();
	$management_node_info->{predictive_prettyname} = $self->get_computer_predictive_pretty_name();
	$management_node_info->{predictive_description} = $self->get_computer_predictive_module_description();
	$management_node_info->{predictive_perlpackage} = $self->get_computer_predictive_module_perl_package();

	my $predictive_perl_package = $self->get_computer_predictive_module_perl_package();

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
			@nextimage = $predictor->get_next_image();
			notify($ERRORS{'OK'}, 0, ref($predictor) . " predictive loading object successfully created");
				notify($ERRORS{'OK'}, 0, "predictive loading module retreived image information: @nextimage");
			if (scalar(@nextimage) == 4) {
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
#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_log_data

 Parameters  : none
 Returns     : hash reference
 Description : Retrieves data from the log and sublog tables for the log ID
               either specified via an argument or the log ID for the
               reservation represented by the DataStructure object.

=cut

sub get_log_data {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'WARNING'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $current_reservation_id = $self->get_reservation_id();
	my $request_id = $self->get_request_id();
	my @reservation_ids = $self->get_reservation_ids();
	
	# Retrieve log info for all reservations
	my $log_info = get_request_log_info($request_id) || return;
	
	$self->request_data->{log} = $log_info;
	
	# Get a mapping between computer to reservation IDs
	# TODO: add sublog.reservationid column, this will no longer be necessary
	my $computer_reservation_ids = {};
	for my $reservation_id (@reservation_ids) {
		my $reservation_data;
		if ($reservation_id eq $current_reservation_id) {
			$reservation_data = $self;
		}
		else {
			$reservation_data = $self->get_reservation_data($reservation_id);
		}	
		if (!$reservation_data) {
			notify($ERRORS{'WARNING'}, 0, "DataStructure object could not be retrieved for reservation $reservation_id");
			next;
		}
		
		my $reservation_computer_id = $reservation_data->get_computer_id();
		if (!$reservation_computer_id) {
			notify($ERRORS{'WARNING'}, 0, "computer ID could not be determined for reservation $reservation_id");
			next;
		}
		
		$computer_reservation_ids->{$reservation_computer_id} = $reservation_id;
	}
	
	for my $sublog_id (keys %{$log_info->{sublog}}) {
		my $sublog_computer_id = $log_info->{sublog}{$sublog_id}{computerid};
		if (!$sublog_computer_id) {
			notify($ERRORS{'WARNING'}, 0, "computer ID is not defined for sublog $sublog_id:\n" . format_data($log_info));
			next;
		}
		
		my $reservation_id = $computer_reservation_ids->{$sublog_computer_id};
		if (!$reservation_id) {
			notify($ERRORS{'WARNING'}, 0, "computer ID is set to $sublog_computer_id for sublog ID $sublog_id, no reservation assigned to this request is assigned that computer ID");
			next;
		}
		
		$self->request_data->{reservation}{$reservation_id}{SUBLOG_ID} = $sublog_id;
		$self->request_data->{reservation}{$reservation_id}{sublog} = $log_info->{sublog}{$sublog_id};
	}
	
	notify($ERRORS{'DEBUG'}, 0, "updated DataStructure object with log and sublog data");
	return $self->request_data->{log};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_computer_private_ip_address

 Parameters  : $suppress_warning (optional)
 Returns     : string
 Description : Retrieves the private IP address for a computer. If an address is
               already stored in the DataStructure object, then that address is
               returned. If no address is stored, null is returned and a warning
               message is displayed in the log file. This can be suppressed via
               the argument.

=cut

sub get_computer_private_ip_address {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'WARNING'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $suppress_warning = shift;
	
	my $computer_id = $self->get_computer_id();
	my $computer_hostname = $self->get_computer_hostname();
	if (!defined($computer_id) || !defined($computer_hostname)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID and hostname are not stored in this DataStructure object");
		return;
	}
	
	# Check if the IP address is already stored
	my $data_structure_private_ip_address = $self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress};
	my $env_private_ip_address = $ENV{computer_private_ip_address}{$computer_id};
	
	# Check if private IP adddress is stored in %ENV and differs from this object's data
	if ($data_structure_private_ip_address) {
		if ($env_private_ip_address) {
			if ($env_private_ip_address =~ /null/i) {
				notify($ERRORS{'DEBUG'}, 0, "private IP address for $computer_hostname ($computer_id) is stored in this object $data_structure_private_ip_address, \%ENV is set to null, deleting private IP address from this object");
				delete $self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress};
				return;
			}
			elsif ($data_structure_private_ip_address eq $env_private_ip_address) {
				notify($ERRORS{'DEBUG'}, 0, "private IP address for $computer_hostname ($computer_id) stored in this object matches IP address stored in \%ENV: $data_structure_private_ip_address");
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "private IP address for $computer_hostname ($computer_id) stored in this object $data_structure_private_ip_address does not match IP address stored in \%ENV, updating private IP address stored in this object: $env_private_ip_address");
				$self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress} = $env_private_ip_address;
			}
			return $env_private_ip_address;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "returning private IP address of $computer_hostname ($computer_id) already stored in this DataStructure object: $data_structure_private_ip_address");
			return $data_structure_private_ip_address;
		}
	}
	else {
		if ($env_private_ip_address && $env_private_ip_address !~ /null/i) {
			notify($ERRORS{'DEBUG'}, 0, "private IP address for $computer_hostname ($computer_id) is not stored in this object but is stored in \%ENV, setting private IP address in this object: $env_private_ip_address");
			$self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress} = $env_private_ip_address;
			return $env_private_ip_address;
		}
		else {
			if ($suppress_warning) {
				notify($ERRORS{'DEBUG'}, 0, "private IP address of $computer_hostname ($computer_id) is not set in this object");
			}
			else {
				notify($ERRORS{'WARNING'}, 0, "private IP address of $computer_hostname ($computer_id) is not set in this object")
			}
			return;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_computer_private_ip_address

 Parameters  : $private_ip_address
 Returns     : boolean
 Description : Sets the computer private IP address in the DataStructure. If the
               IP address argument is different than the value currently stored
               in the DataStructure object, the database is updated.

=cut

sub set_computer_private_ip_address {
	my $self = shift;
	
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $private_ip_address_argument = shift;
	if (!$private_ip_address_argument) {
		notify($ERRORS{'WARNING'}, 0, "computer private IP address argument was not supplied");
		return;
	}
	elsif ($private_ip_address_argument !~ /null/i && !is_valid_ip_address($private_ip_address_argument)) {
		notify($ERRORS{'WARNING'}, 0, "computer private IP address argument is not valid: '$private_ip_address_argument'");
		return;
	}
	
	my $computer_id = $self->get_computer_id();
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "computer ID is not stored in this DataStructure object");
		return;
	}
	
	my $computer_hostname = $self->get_computer_hostname();
	if (!$computer_hostname) {
		notify($ERRORS{'WARNING'}, 0, "computer hostname is not stored in this DataStructure object");
		return;
	}
	
	# Update this DataStructure object
	if ($private_ip_address_argument =~ /null/i) {
		delete $self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress};
	}
	else {
		$self->request_data->{reservation}{$self->reservation_id}{computer}{privateIPaddress} = $private_ip_address_argument;
	}
	
	# Update the database
	if ($computer_id && !update_computer_private_ip_address($computer_id, $private_ip_address_argument)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update private IP address of $computer_hostname to $private_ip_address_argument, unable to update the database");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "private IP address of $computer_hostname set to $private_ip_address_argument");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_affiliation_name

 Parameters  : none
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
	my $image_owner_data = get_user_info($image_owner_id);
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_affiliation_id

 Parameters  : none
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
	my $image_owner_data = get_user_info($image_owner_id);
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

#//////////////////////////////////////////////////////////////////////////////

=head2 is_blockrequest

 Parameters  : none
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

#//////////////////////////////////////////////////////////////////////////////

=head2 is_server_request

 Parameters  : none
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_public_default_gateway

 Parameters  : none
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
	my $management_node_info = get_management_node_info();
	if ($management_node_info) {
		$default_gateway = $management_node_info->{PUBLIC_DEFAULT_GATEWAY};
		if ($default_gateway && is_valid_ip_address($default_gateway)) {
			notify($ERRORS{'DEBUG'}, 0, "returning default gateway configured for management node: $default_gateway");
			return $default_gateway;
		}
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_domain_dns_servers

 Parameters  : none
 Returns     : array
 Description : Returns an array containing the addresses of the Active Directory
               domain DNS servers configured for the image.

=cut

sub get_image_domain_dns_servers {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $reservation_id = $self->reservation_id;
	my $dns_servers_array_ref = $self->request_data->{reservation}{$reservation_id}{image}{imagedomain}{dnsServers};
	if (!$dns_servers_array_ref) {
		notify($ERRORS{'DEBUG'}, 0, "no Active Directory domain DNS server addresses are configured for the image");
		return ();
	}
	return @$dns_servers_array_ref
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_public_dns_servers

 Parameters  : none
 Returns     : If successful: array containing IP addresses
               If failed: false
 Description : Returns an array containing the addresses of the public DNS
               servers configured for the management node.

=cut

sub get_management_node_public_dns_servers {
	# Attempt to retrieve the DNS server addresses configured for this management node
	my $management_node_info = get_management_node_info();
	if (!$management_node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine public DNS servers, management node information could not be retrieved");
		return;
	}
	
	my $dns_address_string = $management_node_info->{PUBLIC_DNS_SERVER};
	if (!$dns_address_string) {
		notify($ERRORS{'DEBUG'}, 0, "no public DNS server addresses are configured for the management node");
		return ();
	}
	
	return split(/\s*[,;]\s*/, $dns_address_string);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_management_node_identity_key_paths

 Parameters  : none
 Returns     : If successful: array containing paths to SSH identity keys
               If failed: false
 Description : Returns an array containing the paths to SSH identity keys
               configured for the management node.

=cut

sub get_management_node_identity_key_paths {
	my $management_node_info = get_management_node_info();
	if (!$management_node_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine public management node identity key paths, management node information could not be retrieved");
		return;
	}
	
	my $keys_string = $management_node_info->{keys};
	if (!$keys_string) {
		return ('/etc/vcl/vcl.key');
	}
	
	return split(/\s*[,;]\s*/, $keys_string);
}

#//////////////////////////////////////////////////////////////////////////////

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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_info_string

 Parameters  : none
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
			$string .= "parent reservation: " . (defined($_ = $self->is_parent_reservation(0)) ? ($_ ? 'yes' : 'no') : '<undefined>') . "\n";
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
		$string .= "computer public IP address: " . (defined($_ = $self->get_computer_public_ip_address(0)) ? $_ : '<undefined>') . "\n";
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

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_user_login_ids

 Parameters  : none
 Returns     : array
 Description : Returns an array containing the reservation user login IDs
               (usernames).

=cut


sub get_reservation_user_login_ids {
	my $self = shift;
	
	my $reservation_user_info = $self->get_reservation_users();
	if (!$reservation_user_info) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve reservation user login IDs, reservation user info is not populated in the request data");
		return;
	}
	
	my @reservation_users = map { $reservation_user_info->{$_}{unityid} } keys %$reservation_user_info;
	return @reservation_users;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_minram

 Parameters  : none
 Returns     : integer
 Description : Returns the larger of the image.minram and OS.minram values.

=cut


sub get_image_minram {
	my $self = shift;
	# Check if subroutine was called as an object method
	unless (ref($self) && $self->isa('VCL::DataStructure')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL::DataStructure module object method");
		return;
	}
	
	my $reservation_id = $self->reservation_id;
	my $image_minram = $self->request_data->{reservation}{$reservation_id}{image}{minram};
	my $os_minram = $self->request_data->{reservation}{$reservation_id}{image}{OS}{minram};
	my $minram = max ($image_minram, $os_minram);
	#notify($ERRORS{'DEBUG'}, 0, "image minram: $image_minram, OS minram: $os_minram, result: $minram");
	return $minram;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_info_json_string

 Parameters  : none
 Returns     : string
 Description : Constucts a JSON string based on the reservation data.

=cut

sub get_reservation_info_json_string {
	my $self = shift;
	
	my $reservation_id = $self->reservation_id;
	my $request_data = $self->request_data;
	
	# Clone the hash so that the original isn't altered
	my $request_data_clone = dclone($request_data);
	
	my $json_data = {};
	
	# Remove useless keys
	$request_data_clone = prune_hash_reference($request_data_clone, '.*(resource|current|adminlevel|nextimage|predictive|platform|log|schedule).*');
	
	$json_data->{request} 			= prune_hash_child_references($request_data_clone);
	$json_data->{reservation} 		= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id});
	$json_data->{imagerevision}	= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id}{imagerevision});
	$json_data->{image} 				= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id}{image});
	$json_data->{computer} 			= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id}{computer});
	
	if (defined($request_data_clone->{reservation}{$reservation_id}{computer}{vmhost})) {
		$json_data->{vmhost} 			= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id}{computer}{vmhost});
		$json_data->{vmhost_computer}	= prune_hash_child_references($request_data_clone->{reservation}{$reservation_id}{computer}{vmhost}{computer});
	}
	
	# TODO: figure out how to handle user info, what structure, etc
	#$json_data->{users} 				= $request_data_clone->{reservation}{$reservation_id}{users};
	#$json_data->{user} = $request_data_clone->{user};
	#$json_data->{user}{username} = $json_data->{user}{unityid};
	
	# IMPORTANT: delete vmprofile data and anything else that may contain passwords
	#delete $json_data->{computer}{vmhost}{vmprofile};
	
	# Convert the request data to JSON
	my $json;
	eval {
		$json = to_json($json_data, { pretty => 1 });
	};
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to create convert request data to json, error: $EVAL_ERROR");
		return;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "constructed JSON string based on reservation information:\n$json");
	return $json;
}


#//////////////////////////////////////////////////////////////////////////////

=head2 get_connect_method_info_matching_name

 Parameters  : $regex_pattern
 Returns     : hash reference
 Description : Checks the name of all connect methods mapped to the current
               reservation's image revision. Returns info for all connect
               methods with a connectmethod.name value matching the pattern
               argument. This is useful for finding a particular connect method.
               
               For example:
               $self->data->get_connect_method_info_matching_name('vmware');
               
               A hash reference is returned. The only hash element would be
               information about a "VMwareVNC" connect method.

=cut

sub get_connect_method_info_matching_name {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $regex_pattern = shift;
	if (!defined($regex_pattern)) {
		notify($ERRORS{'WARNING'}, 0, "connect method name regex pattern argument was not supplied");
		return;
	}
	
	my $matching_connect_method_info = {};
	
	my $connect_method_info = $self->get_connect_methods();
	for my $connect_method_id (sort {$a <=> $b} keys %$connect_method_info) {
		my $connect_method = $connect_method_info->{$connect_method_id};
		my $connect_method_name = $connect_method->{name};
		if ($connect_method_name =~ /$regex_pattern/i) {
			$matching_connect_method_info->{$connect_method_id} = $connect_method;
		}
	}
	
	my $matching_count = scalar(keys %$matching_connect_method_info);
	if (!$matching_count) {
		notify($ERRORS{'DEBUG'}, 0, "no connect methods with name matching pattern '$regex_pattern' are mapped to image revision assigned to reservation");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "found $matching_count connect method(s) with name matching pattern '$regex_pattern' mapped to image revision assigned to reservation:\n" . format_data($matching_connect_method_info));
	}
	return $matching_connect_method_info;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_connect_method_protocol_port_array

 Parameters  : none
 Returns     : array
 Description : Processes all of the connect methods assigned to the image
               revision and constructs an simpler array for easier processing.
               An array is returned. Each array element is an array reference
               with exactly 2 elements, a protocol name and port number:
                  (
                     ["tcp", 22],
                     ["tcp", 3389],
                     ["udp", 3389],
                  )

=cut

sub get_connect_method_protocol_port_array {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my @protocol_port_array;
	
	my $connect_method_info = $self->get_connect_methods();
	for my $connect_method_id (sort keys %{$connect_method_info}) {
		for my $connect_method_port_id (keys %{$connect_method_info->{$connect_method_id}{connectmethodport}}) {
			my $protocol = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{protocol};
			my $port = $connect_method_info->{$connect_method_id}{connectmethodport}{$connect_method_port_id}{port};
			push @protocol_port_array, [lc($protocol), $port],
		}
	}
	return @protocol_port_array;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_affiliation_sitewwwaddress

 Parameters  : none
 Returns     : string
 Description : Returns the affiliation.sitewwwaddress for the user's affiliation
               if populated. If not, returns the value for the Global
               affiliation. If that's not populated, returns vcl.apache.org.

=cut

sub get_user_affiliation_sitewwwaddress {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Try to retrieve the value for the user's affiliation
	if ($self->request_data->{user}{affiliation}{sitewwwaddress}) {
		return $self->request_data->{user}{affiliation}{sitewwwaddress};
	}
	
	# Try to retrieve the value for the Global affiliation
	my $affiliation_info = get_affiliation_info('Global');
	if ($affiliation_info && $affiliation_info->{sitewwwaddress}) {
		return $affiliation_info->{sitewwwaddress};
	}
	
	return 'vcl.apache.org';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_affiliation_helpaddress

 Parameters  : none
 Returns     : string
 Description : Returns the affiliation.helpaddress for the user's affiliation
               if populated. If not, returns the value for the Global
               affiliation. If that's not populated, returns
               'help@vcl.example.edu'.

=cut

sub get_user_affiliation_helpaddress {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Try to retrieve the value for the user's affiliation
	if ($self->request_data->{user}{affiliation}{helpaddress}) {
		return $self->request_data->{user}{affiliation}{helpaddress};
	}
	
	# Try to retrieve the value for the Global affiliation
	my $affiliation_info = get_affiliation_info('Global');
	if ($affiliation_info && $affiliation_info->{helpaddress}) {
		return $affiliation_info->{helpaddress};
	}
	
	return 'help@vcl.example.edu';
}

#//////////////////////////////////////////////////////////////////////////////

=head2 is_cluster_request

 Parameters  : none
 Returns     : boolean
 Description : Determines if the current request is a cluster request.

=cut

sub is_cluster_request {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_count = $self->get_request_reservation_count(0) || 0;
	if ($reservation_count > 1) {
		return 1;
	}
	else {
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_other_cluster_computer_public_ip_addresses

 Parameters  : none
 Returns     : array
 Description : Retrieves the public IP addresses of all other computers assigned
               to a cluster request. Returns an empty array if this is not a
               cluster request.

=cut

sub get_other_cluster_computer_public_ip_addresses {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	# Make sure this is a cluster request
	if (!$self->is_cluster_request()) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve cluster computer public IP addresses, this is not a cluster request");
		return ();
	}
	
	my $current_reservation_id = $self->reservation_id;
	my $current_computer_public_ip_address = $self->get_computer_public_ip_address();
	my @reservation_ids = $self->get_reservation_ids();
	
	my @cluster_computer_public_ip_addresses;
	for my $cluster_reservation_id (@reservation_ids) {
		next if $cluster_reservation_id eq $current_reservation_id;
		
		# Get a DataStructure object for each reservation
		my $reservation_data = $self->get_reservation_data($cluster_reservation_id);
		if (!$reservation_data) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve cluster computer public IP addresses, data could not be retrieved for reservation $cluster_reservation_id");
			next;
		}
		
		# Get the public IP address
		my $cluster_computer_public_ip_address = $reservation_data->get_computer_public_ip_address();
		if (!$cluster_computer_public_ip_address) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve cluster computer public IP address for computer assigned to reservation $cluster_reservation_id");
			return;
		}
		elsif ($cluster_computer_public_ip_address eq $current_computer_public_ip_address) {
			notify($ERRORS{'WARNING'}, 0, "computer assigned to reservation $cluster_reservation_id has the same public IP address as the computer assigned to this reservation: $current_computer_public_ip_address");
			next;
		}
		
		push @cluster_computer_public_ip_addresses, $cluster_computer_public_ip_address;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieves public IP addresses of other reservations assigned to this cluster request:\n" . join("\n", @cluster_computer_public_ip_addresses));
	return sort @cluster_computer_public_ip_addresses;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 substitute_string_variables

 Parameters  : $input_string, $variable_identifier_regex (optional)
 Returns     : $string
 Description : Replaces sections of the input string matching
               $variable_identifier_regex with values from the DataStructure
               object. The default pattern used to locate sections to replace
               is:
                  \[[^\]]*\]'
               
               Meaning, all patterns to replace are enclosed in square brackets.
               The text within the brackets must exactly match one of the keys
               of the %SUBROUTINE_MAPPINGS hash defined above. The text must
               begin and end with lowercase letters and contains any number of
               lowercase letters and underscores in between.
               
               Example:
               This is input text for user [user_login_id]'s reservation with
               request/reservation IDs of [request_id]/[reservation_id].
               
               Each section within square brackets gets prepended with 'get_'
               and the resulting string is executed against this DataStructure
               object:
               [user_login_id] --> $self->get_user_login_id(0);
               
               The value returned is substituted in the input text:
               This is input text for user jdoe23's reservation with
               request/reservation IDs of 3118/3265.

=cut

sub substitute_string_variables {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my ($input_string, $variable_identifier_regex) = @_;
	if (!defined($input_string)) {
		notify($ERRORS{'WARNING'}, 0, "input string argument was not supplied");
		return;
	}	
	if (!$variable_identifier_regex) {
		$variable_identifier_regex = '\[[^\]]*\]';
	}
	
	my $output_string = $input_string;
	
	# Extract all sections of input string which should be replaced
	my @input_substitute_sections = $input_string =~ /($variable_identifier_regex)/g;
	if (!@input_substitute_sections) {
		notify($ERRORS{'DEBUG'}, 0, "input string does not contain any sections to replace matching the substitution identifier pattern: '$variable_identifier_regex', returning original input string: '$input_string'");
		return $input_string;
	}
	#notify($ERRORS{'DEBUG'}, 0, "found sections of input string that match the substitution identifier pattern '$variable_identifier_regex', input string:\n$input_string\n\nmatching sections:\n" . join("\n", @input_substitute_sections));
	
	for my $input_substitute_section (remove_array_duplicates(@input_substitute_sections)) {
		# Remove brackets, etc from matching section: '[user_login_id]' --> 'user_login_id'
		my ($subroutine_mapping_key) = $input_substitute_section =~ /\[(.*)\]/;
		if (!defined($subroutine_mapping_key)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to extract subroutine mapping key from section of input string matching substitution identifier pattern '$variable_identifier_regex': '$input_substitute_section'");
			next;
		}
		#notify($ERRORS{'DEBUG'}, 0, "extracted subroutine mapping key from section of input string: '$input_substitute_section' --> '$subroutine_mapping_key'");
		
		# Attempt to retrieve the substitution value from the DataStructure data
		# Check if DataStructure.pm implements a matching 'get_' function
		my $function_name = "get_$subroutine_mapping_key";
		if (!$self->can($function_name)) {
			# Check if implemented without 'get_'
			# This allows explicit subroutines such as is_server_request to be substituted
			if ($self->can($subroutine_mapping_key)) {
				$function_name = $subroutine_mapping_key;
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to determine replacement value for substitution section: '$input_substitute_section', DataStructure does not implement a '$function_name' function");
				next;
			}
		}
		
		# Assemble a code string to retrieve the value from the DataStructure:
		my $eval_code = "\$self->$function_name(0)";
		
		# Evaluate the code string:
		my $substitution_value = eval $eval_code;
		if (!defined($substitution_value)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to determine replacement value for substitution section: '$input_substitute_section', $eval_code returned undefined");
			next;
		}
		notify($ERRORS{'DEBUG'}, 0, "determined replacement value for substitution section: '$input_substitute_section', $eval_code = '$substitution_value'");
		
		# Replace substitution section with the retrieved value
		my $output_string_before = $output_string;
		# Need to escape brackets or else pattern won't match
		my $input_substitute_section_escaped = quotemeta($input_substitute_section);
		$output_string =~ s/$input_substitute_section_escaped/$substitution_value/g;
		
		# Make sure the substitution worked
		if ($output_string_before eq $output_string) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to replace sections of input string: '$input_substitute_section' (escaped: '$input_substitute_section_escaped') --> '$substitution_value', input string did not change:\n$output_string");
		}
		else {
			#notify($ERRORS{'DEBUG'}, 0, "replaced sections of input string: '$input_substitute_section' --> '$substitution_value'\nbefore:\n$output_string_before\nafter:\n$output_string");
		}
	}
	
	notify($ERRORS{'OK'}, 0, "replaced all matching sections of input string with values retrieved from this DataStructure object:\ninput string: '$input_string'\noutput string: '$output_string'");
	return $output_string;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_invalid_substitution_identifiers

 Parameters  : $input_string, $variable_identifier_regex (optional)
 Returns     : array
 Description : Checks the input string for invalid substitution identifiers. A
					substitution identifier is valid if it corresponds to one of the
					keys defined in %SUBROUTINE_MAPPINGS or matches one of the
					subroutines explicitly defined in DataStructure.pm. Examples:
               * [user_id]
               * [computer_short_name]
               * [is_parent_reservation]
               
               An identifier is invalid if it contains a typo or doesn't match
               any keys or subroutine names:
               * [usr_id]
               * [foo_bar]
               
               If any invalid subroutines are found, an array is returned
               containing the strings found in the input string which appear to
               be intended as substitution identifiers but don't correlate:
               ('[usr_id]', '[foo_bar]')
					
					Note: This subroutine does not need to be called as an object
					method via $self->data. It's intended to be called from utils.pm.
=cut

sub get_invalid_substitution_identifiers {
	my $input_string = shift;
	if (ref($input_string)) {
		$input_string = shift;
	}
	if (!defined($input_string)) {
		notify($ERRORS{'WARNING'}, 0, "input string argument was not supplied");
		return;
	}
	elsif (ref($input_string)) {
		notify($ERRORS{'WARNING'}, 0, "input string argument is a reference:\n" . format_data($input_string));
		return;
	}
	
	my $variable_identifier_regex = shift;
	if (!$variable_identifier_regex) {
		$variable_identifier_regex = '\[[^\]]*\]';
	}
	
	my @invalid_string_variable_identifiers;
	
	my @input_string_variable_identifiers = $input_string =~ /($variable_identifier_regex)/g;
	for my $input_string_variable_identifier (remove_array_duplicates(@input_string_variable_identifiers)) {
		my ($subroutine_mapping_key) = $input_string_variable_identifier =~ /\[(.*)\]/;
		if ($subroutine_mapping_key && defined($SUBROUTINE_MAPPINGS{$subroutine_mapping_key})) {
			next;
		}
		elsif (exists(&$subroutine_mapping_key)) {
			notify($ERRORS{'DEBUG'}, 0, "explicit subroutine exists in DataStructure.pm: $subroutine_mapping_key");
			next;
		}
		
		my $get_subroutine_mapping_key = 'get_' . $subroutine_mapping_key;
		if (exists(&$get_subroutine_mapping_key)) {
			notify($ERRORS{'DEBUG'}, 0, "explicit subroutine exists in DataStructure.pm: $get_subroutine_mapping_key");
			next;
		}
		else {
			notify($ERRORS{'OK'}, 0, "neither mapping key not explicit subroutine exists in DataStructure.pm: $subroutine_mapping_key");
			push @invalid_string_variable_identifiers, $input_string_variable_identifier;
		}
	}
	
	if (@invalid_string_variable_identifiers) {
		notify($ERRORS{'OK'}, 0, "input string contains invalid substitution identifiers: " . join(', ', @invalid_string_variable_identifiers));
	}
	return @invalid_string_variable_identifiers;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_image_domain_password

 Parameters  : none
 Returns     : string
 Description : Returns the decrypted Active Directory domain password.

=cut

sub get_image_domain_password {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $reservation_id = $self->reservation_id();
	
	my $secret_id = $self->get_image_domain_secret_id();
	if (!defined($secret_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve decrypted domain password, addomain.secretid is not defined in this DataStructure.pm object");
		return;
	}
	
	my $encrypted_password = $self->request_data->{reservation}{$reservation_id}{image}{imagedomain}{password};
	if (!defined($encrypted_password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve decrypted domain password, imagedomain.password is not defined in this DataStructure.pm object");
		return;
	}
	
	my $image_domain_password = $self->mn_os->decrypt_cryptsecret($secret_id, $encrypted_password);
	#notify($ERRORS{'DEBUG'}, 0, "retrieved Active Directory domain password: '$image_domain_password'");
	return $image_domain_password;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_domain_credentials

 Parameters  : $domain_identifier
 Returns     : array ($username, $domain_password)
 Description : Attempts to determine and decrypt the username and password for
               the domain specified by the argument. 

=cut

sub get_domain_credentials {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $domain_identifier = shift;
	if (!defined($domain_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "domain identifier argument was not supplied");
		return;
	}
	
	my $management_node_id = $self->get_management_node_id();
	
	my ($username, $secret_id, $encrypted_password) = get_management_node_ad_domain_credentials($management_node_id, $domain_identifier);
	return unless $username && $secret_id && $encrypted_password;
	
	my $decrypted_password = $self->mn_os->decrypt_cryptsecret($secret_id, $encrypted_password) || return;
	my $decrypted_password_length = length($decrypted_password);
	my $decrypted_password_hidden = '*' x $decrypted_password_length;
	notify($ERRORS{'DEBUG'}, 0, "retrieved credentials for Active Directory domain: '$decrypted_password_hidden' ($decrypted_password_length characters)");
	return $decrypted_password;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_vmhost_profile_password

 Parameters  : $display_warnings (optional)
 Returns     : string
 Description : Returns the decrypted VM host profile password if both
               vmprofile.password and vmprofile.secretid are set. If
               vmprofile.password is set but vmprofile.secretid is not, assumes
               the password was set prior to VCL 2.5 and returns raw value of
               vmprofile.password.

=cut

sub get_vmhost_profile_password {
	my $self = shift;
	if (ref($self) !~ /VCL::/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
	
	my $display_warnings = shift;
	$display_warnings = 1 unless defined($display_warnings);
	
	my $reservation_id = $self->reservation_id();
	
	my $password = $self->request_data->{reservation}{$reservation_id}{computer}{vmhost}{vmprofile}{password};
	if (!defined($password)) {
		notify($ERRORS{'WARNING'}, 0, "failed to retrieve decrypted VM profile password, vmprofile.password is not defined in this DataStructure.pm object") if $display_warnings;
		return;
	}
	
	my $secret_id = $self->get_vmhost_profile_secret_id(0);
	if (!defined($secret_id)) {
		notify($ERRORS{'DEBUG'}, 0, "vmprofile.password is set but vmprofile.secretid is NOT, assuming vmprofile.password is a pre-VCL 2.5 clear-text password: '$password'");
		return $password;
	}
	
	my $decrypted_password = $self->mn_os->decrypt_cryptsecret($secret_id, $password) || return;
	my $decrypted_password_length = length($decrypted_password);
	my $decrypted_password_hidden = '*' x $decrypted_password_length;
	notify($ERRORS{'DEBUG'}, 0, "decrypted VM host profile password: '$decrypted_password_hidden' ($decrypted_password_length characters)");
	return $decrypted_password;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
