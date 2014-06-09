#!/usr/bin/perl -w
###############################################################################
# $Id: openstack.pm 2012-4-14 
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

VCL::Provisioning::openstack - VCL module to support the Openstack provisioning engine

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

This module provides VCL support for Openstack

=cut

##############################################################################
package VCL::Module::Provisioning::openstack;

# Include File Copying for Perl
use File::Copy;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.2.1';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::DataStructure;
use VCL::utils;

use Fcntl qw(:DEFAULT :flock);

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  :
 Returns     :
 Description :

=cut

sub initialize {
	my $self = shift;
        notify($ERRORS{'DEBUG'}, 0, "OpenStack module initialized");
	
	if($self->_set_openstack_user_conf) {
        	notify($ERRORS{'OK'}, 0, "Success to OpenStack user configuration");
	}
	else {
        	notify($ERRORS{'CRITICAL'}, 0, "Failure to Openstack user configuration");
		return 0;
	}
	
        return 1;
} ## end sub initialize


#/////////////////////////////////////////////////////////////////////////////

=head2 provision

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads virtual machine with requested image

=cut

sub load {
	my $self = shift;

	#check to make sure this call is for the openstack module
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "****************************************************");

	# get various useful vars from the database
	my $image_full_name      = $self->data->get_image_name;
	my $computer_shortname   = $self->data->get_computer_short_name;
	my $request_forimaging   = $self->data->get_request_forimaging();


	notify($ERRORS{'OK'}, 0, "Query the host to see if the $computer_shortname currently exists");

	# power off the old instance if exists 
	if(_pingnode($computer_shortname) || $request_forimaging == 0) 
	{
		if($self->_terminate_instances) {
	                notify($ERRORS{'OK'}, 0, "Terminate the existing computer $computer_shortname");
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "No instance to terminate for $computer_shortname");
		}		
	}

	# Create new instance 
	my $instance_id = $self->_run_instances;
	
	if ($instance_id)
	{
		notify($ERRORS{'OK'}, 0, "The instance $instance_id is created\n");
	}
	else
	{
		notify($ERRORS{'CRITICAL'}, 0, "Fail to run the instance $instance_id");
		return 0;
	}

	# Update the private ip of the instance in /etc/hosts file
	if($self->_update_private_ip($instance_id)) 
	{
		notify($ERRORS{'OK'}, 0, "Update the private ip of instance $instance_id is succeeded\n");
	}
	else
	{
		notify($ERRORS{'CRITICAL'}, 0, "Fail to update private ip of the instance in /etc/hosts");
		return 0;
	}


	# Instances have the ip instantly when it use FlatNetworkManager
	# Need to wait for copying images from repository or cache to instance directory
	# 15G for 3 to 5 minutes (depends on systems)
	#sleep 300;
	sleep 10;

	# Call post_load 
	if ($self->os->can("post_load")) {
		notify($ERRORS{'DEBUG'}, 0, "calling " . ref($self->os) . "->post_load()");
		if ($self->os->post_load()) {
			notify($ERRORS{'DEBUG'}, 0, "successfully ran OS post_load subroutine");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to run OS post_load subroutine");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, ref($self->os) . "::post_load() has not been implemented");
	}

	return 1;

} ## end sub load

#/////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : $request_data_hash_reference
 Returns     : 1 if sucessful, 0 if failed
 Description : Creates a new vmware image.

=cut

sub capture {
        notify($ERRORS{'DEBUG'}, 0, "**********************************************************");
        notify($ERRORS{'OK'},    0, "Entering Openstack Capture routine");
        my $self = shift;

        if (ref($self) !~ /openstack/i) {
                notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
                return 0;
        }

        my $image_name     = $self->data->get_image_name();
        my $computer_shortname = $self->data->get_computer_short_name;
	my $instance_id;
	
        if(_pingnode($computer_shortname))
        {
		$instance_id = $self->_get_instance_id;
		notify($ERRORS{'OK'}, 0, "instance id: $instance_id is done");
		if(!$instance_id)
		{
			notify($ERRORS{'DEBUG'}, 0, "unable to get instance id for $computer_shortname");
			return 0;
		}
        }
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to ping to $computer_shortname");
		return 0;
	}
		
        if($self->_prepare_capture)
	{
		notify($ERRORS{'OK'}, 0, "Prepare_Capture for $computer_shortname is done");
	}
	
	my $new_image_name = $self->_image_create($instance_id);

	if($new_image_name)
	{
		notify($ERRORS{'OK'}, 0, "Create Image for $computer_shortname is done");
	}

	if($self->_insert_openstack_image_name($new_image_name))
	{
	        notify($ERRORS{'OK'}, 0, "Successfully insert image name");
        }

	if($self->_wait_for_copying_image($instance_id)) 
	{
		notify($ERRORS{'OK'}, 0, "Wait for copying $new_image_name is succeeded\n");
	}

        return 1;
} ## end sub capture

sub _image_create{
	my $self = shift;
	my $instance_id = shift;
	my $imagerevision_comments = $self->data->get_imagerevision_comments(0);
        my $image_name     = $self->data->get_image_name();
	
	my $image_version;
        if($image_name =~ m/(-+)(.+)(-v\d+)/g)
        {
                $image_version = $3;
                notify($ERRORS{'OK'}, 0, "Acquire the Image Version: $image_version");
        }

        my $image_description = $image_name . '-' . $imagerevision_comments;
        my $capture_image = "nova image-create $instance_id $image_description";
        notify($ERRORS{'OK'}, 0, "New Image Capture Command: $capture_image");
        my $capture_image_output = `$capture_image`;

        my $openstack_image_id;
        my $new_image_name;
        my $describe_image = "nova image-list |grep $instance_id";
        my $run_describe_image_output = `$describe_image`;
        notify($ERRORS{'OK'}, 0, "The images: $run_describe_image_output");

	sleep 10;

        if($run_describe_image_output  =~ m/^\|\s(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})/g )
        {
                $openstack_image_id = $1;
                $new_image_name = $openstack_image_id .'-v'. $image_version;
                notify($ERRORS{'OK'}, 0, "The Openstack Image ID:$openstack_image_id");
                notify($ERRORS{'OK'}, 0, "The New Image Name:$new_image_name");
                return $new_image_name;
        }
        else
        {
                notify($ERRORS{'DEBUG'}, 0, "Fail to capture new Image");
                return 0;
        }
}

sub _prepare_capture {
	my $self = shift;
	
        my ($package, $filename, $line, $sub) = caller(0);
        my $request_data = $self->data->get_request_data;

        if (!$request_data) {
                notify($ERRORS{'WARNING'}, 0, "unable to retrieve request data hash");
                return 0;
        }

        my $request_id     = $self->data->get_request_id;
        my $reservation_id = $self->data->get_reservation_id;
        my $management_node_keys     = $self->data->get_management_node_keys();

        my $image_id       = $self->data->get_image_id;
        my $image_os_name  = $self->data->get_image_os_name;
        my $image_identity = $self->data->get_image_identity;
        my $image_os_type  = $self->data->get_image_os_type;
        my $image_name     = $self->data->get_image_name();

        my $computer_id        = $self->data->get_computer_id;
        my $computer_shortname = $self->data->get_computer_short_name;
        my $computer_nodename  = $computer_shortname;
        my $computer_hostname  = $self->data->get_computer_hostname;
        my $computer_type      = $self->data->get_computer_type;

        if (write_currentimage_txt($self->data)) {
                notify($ERRORS{'OK'}, 0, "currentimage.txt updated on $computer_shortname");
        }
        else {
                notify($ERRORS{'DEBUG'}, 0, "unable to update currentimage.txt on $computer_shortname");
                return 0;
        }

        $self->data->set_imagemeta_sysprep(0);
        notify($ERRORS{'OK'}, 0, "Set the imagemeta Sysprep value to 0");

        if ($self->os->can("pre_capture")) {
                notify($ERRORS{'OK'}, 0, "calling OS module's pre_capture() subroutine");

                if (!$self->os->pre_capture({end_state => 'on'})) {
                        notify($ERRORS{'DEBUG'}, 0, "OS module pre_capture() failed");
                        return 0;
                }
        }
	return 1;
}

sub _insert_openstack_image_name {

	my $self = shift;
	my $openstack_image_name = shift;
        my $image_name     = $self->data->get_image_name();       

        my $insert_statement = "
        INSERT INTO
        openstackImageNameMap (
          openstackImageNameMap.openstackimagename,
          openstackImageNameMap.vclimagename
        ) VALUES (
          '$openstack_image_name',
          '$image_name')";

        notify($ERRORS{'OK'}, 0, "$insert_statement");

        my $requested_id = database_execute($insert_statement);
        notify($ERRORS{'OK'}, 0, "SQL Insert is first time or requested_id : $requested_id");

        if (!$requested_id) {
                notify($ERRORS{'OK'}, 0, "Successfully insert image name");
		return 1;
        }
        else {
                notify($ERRORS{'DEBUG'}, 0, "unable to insert image name");
                return 0;
        }
}

sub _wait_for_copying_image {
	my $self = shift;
	
	my $instance_id = shift;
	
        my $query_image = "nova image-list | grep $instance_id";
        my $query_image_output = `$query_image`;
        my $loop = 50;

        notify($ERRORS{'OK'}, 0, "The describe image output for $instance_id : $query_image_output");
        while ($loop > 0)
        {
		if($query_image_output  =~ m/\|\s(\w{6})\s\|/g )
		{
                        my $temp = $1;

                        if( $temp eq 'ACTIVE') {
                               notify($ERRORS{'OK'}, 0, "$instance_id is available now");
                               goto RELOAD;
                        }
                        elsif ($temp eq 'SAVING') {
                                notify($ERRORS{'OK'}, 0, "Sleep to capture New Image for 25 secs");
                                sleep 25;
                        }
                        else {
                                notify($ERRORS{'DEBUG'}, 0, "Failure for $instance_id");
				return 0;
                        }
                }
                $query_image_output = `$query_image`;
                notify($ERRORS{'OK'}, 0, "The describe image output of loop #$loop: $query_image_output");
                $loop--;
        }
        RELOAD:
        #notify($ERRORS{'OK'}, 0, "Sleep until image is available");
        sleep 30;
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $nodename, $log
 Returns     : array of related status checks
 Description : checks on sshd, currentimage

=cut

sub node_status {
	my $self = shift;

	my ($package, $filename, $line, $sub) = caller(0);

	my $vmpath             = 0;
	my $datastorepath      = 0;
	my $vcl_requestedimagename = 0;
	my $requestedimagename = 0;
	my $vmhost_type        = 0;
	my $vmhost_hostname    = 0;
	my $vmhost_imagename   = 0;
	my $image_os_type      = 0;
	my $vmclient_shortname = 0;
	my $request_forimaging = 0;
	my $identity_keys      = 0;
	my $log                = 0;
	my $computer_node_name = 0;

	# Set IAAS Environment 
	notify($ERRORS{'OK'}, 0, "Set OpenStack Environment");


	# Check if subroutine was called as a class method
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'OK'}, 0, "subroutine was called as a function");
		if (ref($self) eq 'HASH') {
			$log = $self->{logfile};
			#notify($ERRORS{'DEBUG'}, $log, "self is a hash reference");
			$vcl_requestedimagename = $self->{imagerevision}->{imagename};
			$image_os_type      = $self->{image}->{OS}->{type};
			$computer_node_name = $self->{computer}->{hostname};
			$identity_keys      = $self->{managementnode}->{keys};

		} ## end if (ref($self) eq 'HASH')
		# Check if node_status returned an array ref
		elsif (ref($self) eq 'ARRAY') {
			notify($ERRORS{'DEBUG'}, $log, "self is a array reference");
		}

		$vmclient_shortname = $1 if ($computer_node_name =~ /([-_a-zA-Z0-9]*)(\.?)/);
	} ## end if (ref($self) !~ /esx/i)
	else {
		# try to contact vm
		# $self->data->get_request_data;
		# get state of vm
		$vcl_requestedimagename = $self->data->get_image_name;
		$image_os_type      = $self->data->get_image_os_type;
		$vmclient_shortname = $self->data->get_computer_short_name;
		$request_forimaging = $self->data->get_request_forimaging();
		$identity_keys      = $self->data->get_management_node_keys;
	} ## end else [ if (ref($self) !~ /esx/i)

	notify($ERRORS{'OK'}, 0, "Entering node_status, checking status of $vmclient_shortname");
	notify($ERRORS{'OK'}, 0, "request_for_imaging: $request_forimaging");
	notify($ERRORS{'OK'}, 0, "requeseted image name: $vcl_requestedimagename");

	my ($hostnode);

	# Create a hash to store status components
#	my %status;

	# Initialize all hash keys here to make sure they're defined
#	$status{status}       = 0;
#	$status{currentimage} = 0;
#	$status{ping}         = 0;
#	$status{ssh}          = 0;
#	$status{vmstate}      = 0;    #on or off
#	$status{image_match}  = 0;

	# Check if node is pingable
#	notify($ERRORS{'OK'}, 0, "checking if $vmclient_shortname is pingable");
#	if (_pingnode($vmclient_shortname)) {
#		$status{ping} = 1;
#		notify($ERRORS{'OK'}, 0, "$vmclient_shortname is pingable ($status{ping})");
#	}
#	else {
#		notify($ERRORS{'OK'}, 0, "$vmclient_shortname is not pingable ($status{ping})");
#		return $status{status};
#	}

        my $status;
        $status->{currentimage} = '';
        $status->{ssh} = 0;
        $status->{image_match} = 0;
        $status->{status} = 'RELOAD';

        notify($ERRORS{'OK'}, 0, "checking if $vmclient_shortname is pingable");
        if (_pingnode($vmclient_shortname)) {
                $status->{ping} = 1;
                notify($ERRORS{'OK'}, 0, "$vmclient_shortname is pingable ($status->{ping})");
        }
        else {
                notify($ERRORS{'OK'}, 0, "$vmclient_shortname is not pingable ($status->{ping})");
                return $status->{ping}=0;
        }



	notify($ERRORS{'DEBUG'}, 0, "Trying to ssh...");

        if ($self->os->is_ssh_responding()) {
                notify($ERRORS{'DEBUG'}, 0, "VM $computer_node_name is responding to SSH");
                $status->{ssh} = 1;
        }
        else {
                notify($ERRORS{'OK'}, 0, "VM $computer_node_name is not responding to SSH, returning 'RELOAD'");
                $status->{status} = 'RELOAD';
                $status->{ssh} = 0;
	
		return $status;
	}

        my $current_image_revision_id = $self->os->get_current_image_info();
	$status->{currentimagerevision_id} = $current_image_revision_id;

	$status->{currentimage} = $self->data->get_computer_currentimage_name();
        my $current_image_name = $status->{currentimage};
        my $vcld_post_load_status = $self->data->get_computer_currentimage_vcld_post_load();

        if (!$current_image_revision_id) {
                notify($ERRORS{'OK'}, 0, "unable to retrieve image name from currentimage.txt on VM $computer_node_name, returning 'RELOAD'");
                return $status;
        }
        elsif ($current_image_revision_id eq $vcl_requestedimagename) {
                notify($ERRORS{'OK'}, 0, "currentimage.txt image $current_image_revision_id ($current_image_name) matches requested imagerevision_id $vcl_requestedimagename  on VM $computer_node_name");
                $status->{image_match} = 1;
        }
        else {
                notify($ERRORS{'OK'}, 0, "currentimage.txt imagerevision_id $current_image_revision_id ($current_image_name) does not match requested imagerevision_id $vcl_requestedimagename on VM $computer_node_name, returning 'RELOAD'");
                return $status;
        }


	# Determine the overall machine status based on the individual status results
	if ($status->{ssh} && $status->{image_match}) {
		$status->{status} = 'READY';
	}
	else {
		$status->{status} = 'RELOAD';
	}

	notify($ERRORS{'DEBUG'}, 0, "status set to $status->{status}");


	if ($request_forimaging) {
		$status->{status} = 'RELOAD';
		notify($ERRORS{'OK'}, 0, "request_forimaging set, setting status to RELOAD");
	}

	notify($ERRORS{'DEBUG'}, 0, "returning node status hash reference (\$node_status->{status}=$status->{status})");
	#return \%status;
	return $status;

} ## end sub node_status


sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $image_fullname = $self->data->get_image_name();
	my $image_os_type  = $self->data->get_image_os_type;

	# Match image name between VCL database and openstack Hbase database
        my $image_name = _match_image_name($image_fullname);

	if($image_name  =~ m/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})-v/g )
	{
                $image_name = $1;
                notify($ERRORS{'OK'}, 0, "Acquire the Image ID: $image_name");
        }
        else {
                notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $image_name");
                return 0;
        }

	my $describe_images = "nova image-list | grep $image_name";
	my $describe_images_output = `$describe_images`;

	notify($ERRORS{'OK'}, 0, "The describe_image output: $describe_images_output");

	if ($describe_images_output =~ /$image_name/) {
		notify($ERRORS{'OK'}, 0, "The Image $image_name exists");
		return 1;
	}
	else
	{
		notify($ERRORS{'WARNING'}, 0, "The Image $image_name does NOT exists");
		return 0;
	}

} ## end sub does_image_exist

#/////////////////////////////////////////////////////////////////////////////

=head2  getimagesize

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Kilobytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /open/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}
 
        notify($ERRORS{'OK'}, 0, "No image size information in Openstack");

	return;
} ## end sub get_image_size

#/////////////////////////////////////////////////////////////////////////////

=head2 _set_openstack_user_conf 

 Parameters  : None 
 Returns     : 1(success) or 0(failure)
 Description : load environment profile and set global environemnt variables 

example: openstack.conf
"os_tenant_name" => "admin",
"os_username" => "admin",
"os_password" => "adminpassword",
"os_auth_url" => "http://openstack_nova_url:5000/v2.0/",


=cut

sub _set_openstack_user_conf {

	my $self = shift;
        notify($ERRORS{'OK'}, 0, "********* Set OpenStack User Configuration******************");
	my $computer_shortname   = $self->data->get_computer_short_name;
        notify($ERRORS{'OK'}, 0,  "computer_shortname: $computer_shortname");
	# User's environment file
	my $user_config_file = '/etc/vcl/openstack/openstack.conf';
        notify($ERRORS{'OK'}, 0,  "loading $user_config_file");
        my %config = do($user_config_file);
        if (!%config) {
                notify($ERRORS{'CRITICAL'},0, "failure to process $user_config_file");
                return 0;
        }
        $self->{config} = \%config;
        my $os_auth_url = $self->{config}->{os_auth_url};
        my $os_tenant_name = $self->{config}->{os_tenant_name};
        my $os_username = $self->{config}->{os_username};
        my $os_password = $self->{config}->{os_password};

	# Set Environment File
	$ENV{'OS_AUTH_URL'} = $os_auth_url;
	$ENV{'OS_TENANT_NAME'} = $os_tenant_name;
	$ENV{'OS_USERNAME'} = $os_username;
	$ENV{'OS_PASSWORD'} = $os_password;

        return 1;
}# _set_openstack_user_conf close

#/////////////////////////////////////////////////////////////////////////////

=head2 _match_image_name 

 Parameters  : None 
 Returns     : image_name of Openstack 
 Description : match VCL image name with Openstack image name and set the image_name

=cut

sub _match_image_name {

	# Set image name
	my $vcl_image_name = shift;

	my $select_statement = "
	SELECT
	openstackImageNameMap.openstackimagename as openstack_name, 
	openstackImageNameMap.vclimagename as vcl_name 
	FROM
	openstackImageNameMap
	WHERE
	openstackImageNameMap.vclimagename = '$vcl_image_name'
	";

	notify($ERRORS{'OK'}, 0, "$select_statement");
        # Call the database select subroutine
        # This will return an array of one or more rows based on the select statement
        my @selected_rows = database_select($select_statement);
	# Check to make sure 1 row was returned
        if (scalar @selected_rows == 0) {
                return 1;
        }
        elsif (scalar @selected_rows > 1) {
                notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
                return 0;
        }
        my $openstack_image_name = $selected_rows[0]{openstack_name};
        my $vcl_imagename  = $selected_rows[0]{vcl_name};

        notify($ERRORS{'OK'}, 0, "new image name (openstack_image_name) =$openstack_image_name");
        notify($ERRORS{'OK'}, 0, "new image name (vcl_image_name) =$vcl_imagename");
	
	return $openstack_image_name;

}# _match_image_name close

sub _terminate_instances {
	my $self = shift;

	my $computer_shortname = $self->data->get_computer_short_name;
	my $instance_private_ip = $self->data->get_computer_private_ip_address();
	my $instance_id = $self->_get_instance_id;
	$self->_delete_computer_mapping;
	my $terminate_instances;
	my $run_terminate_instances;
	my $nova_db_sync;
	my $run_nova_db_sync;

	if ($instance_id) {
		notify($ERRORS{'OK'}, 0, "Terminate the existing instance");
		$terminate_instances = "nova delete $instance_id";
		$run_terminate_instances = `$terminate_instances`;
		notify($ERRORS{'OK'}, 0, "The nova delete : $run_terminate_instances is terminated");
		# nova.conf, set force_dhcp_release=true
		sleep 30; # wait for completely removing from nova list
		#$nova_db_sync = "nova-manage db sync";
		#$run_nova_db_sync = `$nova_db_sync`;
		# Check if terminate instance is okay
	}
	else {
		notify($ERRORS{'OK'}, 0, "No instance found for $computer_shortname");
	}

	return 1;
}

sub _run_instances {
	my $self = shift;
	
	my $flavor_type = '3';
	my $key_name = 'newkey';
	#my $key_name = 'OpenStack_Root';
	#my $key_name = 'vclkey';
	my $image_full_name = $self->data->get_image_name;
	my $computer_shortname  = $self->data->get_computer_short_name;

        my $image_name = _match_image_name($image_full_name);
	if($image_name  =~ m/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})-v/g )
	{
                $image_name = $1;
                notify($ERRORS{'OK'}, 0, "Acquire the Image ID: $image_name");
        }
        else {
                notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $image_name");
                return 0;
        }
	my $run_instance = "nova boot --flavor $flavor_type --image $image_name --key_name $key_name $computer_shortname";
	notify($ERRORS{'OK'}, 0, "The run_instance: $run_instance\n");
	
	my $run_instance_output = `$run_instance`;
	my $instance_id;
	my $insert_success;
	
	notify($ERRORS{'OK'}, 0, "The run_instance Output: $run_instance_output\n");
	if($run_instance_output  =~ m/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})/g )
	{
		$instance_id = $&;
		notify($ERRORS{'OK'}, 0, "The indstance_id: $instance_id\n");
	}
	else {
		notify($ERRORS{'OK'}, 0, "Fail to run the instance");
		return 0;
	}

	$insert_success = $self->_insert_instance_id($instance_id);

	if (!$insert_success) {
		return 0;
	}

	return $instance_id;
}

sub _insert_instance_id {
	my $self = shift;
	my $instance_id = shift;
	my $computer_id = $self->data->get_computer_id;

	my $insert_statement = "
	INSERT INTO
	openstackComputerMap (
	instanceid,
	computerid
	) VALUES (
		'$instance_id',
		'$computer_id'
	)";

	notify($ERRORS{'OK'}, 0, "$insert_statement");
	my $success = database_execute($insert_statement);

	if ($success) {
		notify($ERRORS{'OK'}, 0, "Successfully inserted instance id");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "Unable to insert instance id");
		return 0;
	}
}

sub _get_instance_id {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id;

	my $select_statement = "
	SELECT
	instanceid
	FROM
	openstackComputerMap
	WHERE
	computerid = '$computer_id'
	";

	notify($ERRORS{'OK'}, 0, "$select_statement");
	my @selected_rows = database_select($select_statement);

	if (scalar @selected_rows == 0) {
		return 0;
	}

	my $instance_id = $selected_rows[0]{instanceid};
	notify($ERRORS{'OK'}, 0, "Openstack id for $computer_id is $instance_id");

	return $instance_id;
}

sub _delete_computer_mapping {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id;

	my $delete_statement = "
	DELETE FROM
	openstackComputerMap
	WHERE
	computerid='$computer_id'
	";

	notify($ERRORS{'OK'}, 0, "$delete_statement");
	my $success = database_execute($delete_statement);

	if ($success) {
		notify($ERRORS{'OK'}, 0, "Successfully deleted computer mapping");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "Unable to delete computer mapping");
		return 0;
	}
}



sub _update_private_ip {
	my $self = shift;
	
	my $instance_id = shift;
	my $main_loop = 60;
	my $private_ip;
	my $describe_instance_output;
	my $computer_shortname  = $self->data->get_computer_short_name;
	my $describe_instance = "nova list |grep  $instance_id";
	notify($ERRORS{'OK'}, 0, "Describe Instance: $describe_instance");

	# Find the correct instance among running instances using the private IP
	while($main_loop > 0 && !defined($private_ip))
	{
		notify($ERRORS{'OK'}, 0, "Try to fetch the Private IP on Computer $computer_shortname: Number $main_loop");	
		$describe_instance_output = `$describe_instance`;
		notify($ERRORS{'OK'}, 0, "Describe Instance: $describe_instance_output");

		if($describe_instance_output =~ m/(10.25.6.\d{1,3})/g)
		{
			$private_ip = $&;
			notify($ERRORS{'OK'}, 0, "The instance private IP on Computer $computer_shortname: $private_ip");
			if (defined($private_ip) && $private_ip ne "") {
				notify($ERRORS{'OK'}, 0, "Removing old hosts entry");
				my $sedoutput = `sed -i "/.*\\b$computer_shortname\$/d" /etc/hosts`;
				notify($ERRORS{'DEBUG'}, 0, $sedoutput);
				`echo -e "$private_ip\t$computer_shortname" >> /etc/hosts`;
				my $new_private_ip = $self->data->set_computer_private_ip_address($private_ip);
				if(!$new_private_ip) {
					notify($ERRORS{'OK'}, 0, "The $private_ip on Computer $computer_shortname is NOT updated");
					return 0;
				}
				goto EXIT_WHILELOOP;
			}
		}
		else {
				notify($ERRORS{'DEBUG'}, 0, "Private IP for $computer_shortname is not determined");
		}

		sleep 20;
		$main_loop--;
	}
	EXIT_WHILELOOP:
	
	return 1;
}
#/////////////////////////////////////////////////////////////////////////////

1;
__END__
