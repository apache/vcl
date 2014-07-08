#!/usr/bin/perl -w
###############################################################################
# $Id: openstack.pm 2014-6-22 
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

VCL::Provisioning::openstack - VCL module to support the Openstack provisioning engine with REST APIs v2

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
our $VERSION = '2.3.2';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use IO::File;
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw( tempfile );
use List::Util qw( max );
use VCL::utils;
use JSON qw(from_json to_json);
use LWP::UserAgent;

#/////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  :
 Returns     :
 Description :

=cut

sub initialize {
	my $self = shift;
	notify($ERRORS{'DEBUG'}, 0, "OpenStack module initialized");
	
	if($self->_set_openstack_user_conf()) {
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
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $reservation_id = $self->data->get_reservation_id() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;

	insertloadlog($reservation_id, $computer_id, "doesimageexists", "image exists $image_name");
	insertloadlog($reservation_id, $computer_id, "startload", "$computer_name $image_name");

	# Remove existing VMs which were created for the reservation computer
	if (!$self->_terminate_instances()) {
		notify($ERRORS{'WARNING'}, 0, " No instance or failed to remove existing VMs");
	}

	# Create new instance 
	if (!$self->_run_instances()) {
		notify($ERRORS{'WARNING'}, 0, "failed to create VMs for computer $computer_name on VM host: $vmhost_name");
		return;
	}
	my $instance_id = $self->_get_instance_id();
	if (!$instance_id) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the instance id for $computer_name");
		return;
	}

	# Update the private ip of the instance in /etc/hosts file
	if ($self->_update_private_ip($instance_id)) 
	{
		notify($ERRORS{'OK'}, 0, "Update the private ip of instance $instance_id is succeeded\n");
	}
	else
	{
		notify($ERRORS{'CRITICAL'}, 0, "Fail to update private ip of the instance in /etc/hosts");
		return;
	}


	# An instance has an ip instantly when it uses FlatNetworkManager
	# Need to wait for copying images from repository or cache to instance directory
	# 15G for 3 to 5 minutes (depends on network and systems)
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
	my $self = shift;

	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $reservation_id = $self->data->get_reservation_id() || return;
	my $computer_id = $self->data->get_computer_id() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $instance_id;
	insertloadlog($reservation_id, $computer_id, "startcapture", "$computer_name $image_name");
	
	if (_pingnode($computer_name))
	{
		$instance_id = $self->_get_instance_id();
		notify($ERRORS{'OK'}, 0, "instance id: $instance_id is done");
		if (!$instance_id)
		{
			notify($ERRORS{'DEBUG'}, 0, "unable to get instance id for $computer_name");
			return 0;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to ping to $computer_name");
		return 0;
	}
		
	if ($self->_prepare_capture())
	{
		notify($ERRORS{'OK'}, 0, "Prepare_Capture for $computer_name is done");
	}
	
	my $new_image_name = $self->_image_create($instance_id);

	if(defined($new_image_name))
	{
		notify($ERRORS{'OK'}, 0, "Create Image for $computer_name is done");
	}

	if($self->_insert_openstack_image_name($new_image_name))
	{
		notify($ERRORS{'OK'}, 0, "Successfully insert image name");
	}

	if($self->_wait_for_copying_image($new_image_name)) 
	{
		notify($ERRORS{'OK'}, 0, "Wait for copying $new_image_name is succeeded\n");
	}

	return 1;
} ## end sub capture

#/////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : $computer_id or $hash->{computer}{id} (optional)
 Returns     : string -- 'READY', 'POST_LOAD', or 'RELOAD'
 Description : Checks the status of a VM. 'READY' is returned if the VM is
	       accessible via SSH, and the OS module's post-load tasks have 
	       run. 'POST_LOAD' is returned if the VM only needs to have 
	       the OS module's post-load tasks run before it is ready. 
	       'RELOAD' is returned otherwise.

=cut

sub node_status {
	my $self;

	# Get the argument
	my $argument = shift;

	# Check if this subroutine was called an an object method or an argument was passed
	if (ref($argument) =~ /VCL::Module/i) {
		$self = $argument;
	}
	elsif (!ref($argument) || ref($argument) eq 'HASH') {
		# An argument was passed, check its type and determine the computer ID
		my $computer_id;
		if (ref($argument)) {
			# Hash reference was passed
			$computer_id = $argument->{id};
		}
		elsif ($argument =~ /^\d+$/) {
			# Computer ID was passed
			$computer_id = $argument;
		}
		else {
			# Computer name was passed
			($computer_id) = get_computer_ids($argument);
		}

		if ($computer_id) {
			notify($ERRORS{'DEBUG'}, 0, "computer ID: $computer_id");
		}

		else {
			notify($ERRORS{'WARNING'}, 0, "unable to determine computer ID from argument:\n" . format_data($argument));
			return;
		}

		# Create a DataStructure object containing data for the computer specified as the argument
		my $data;
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
			notify($ERRORS{'DEBUG'}, 0, "created DataStructure object  for computer ID: $computer_id");
		}

		# Create a VMware object
		my $object_type = 'VCL::Module::Provisioning::openstack';
		if ($self = ($object_type)->new({data_structure => $data})) {
			notify($ERRORS{'DEBUG'}, 0, "created $object_type object to check the status of computer ID: $computer_id");
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create $object_type object to check the status of computer ID: $computer_id");
			return;
		}

		# Create an OS object for the VMware object to access
		if (!$self->create_os_object()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create OS object");
			return;
		}
	}

	my $reservation_id = $self->data->get_reservation_id();
	my $computer_name = $self->data->get_computer_node_name();
	my $image_name = $self->data->get_image_name();
	my $imagerevision_id = $self->data->get_imagerevision_id();

	notify($ERRORS{'DEBUG'}, 0, "attempting to check the status of computer $computer_name, image: $image_name");

	# Create a hash reference and populate it with the default values
	my $status;
	$status->{currentimage} = '';
	$status->{ssh} = 0;
	$status->{image_match} = 0;
	$status->{status} = 'RELOAD';

	# Check if node is pingable and retrieve the power status if the reservation ID is 0
	# The reservation ID will be 0 is this subroutine was not called as an object method, but with a computer ID argument
	# The reservation ID will be 0 when called from healthcheck.pm
	# The reservation ID will be > 0 if called from a normal VCL reservation
	# Skip the ping and power status checks for a normal reservation to speed things up
	if (!$reservation_id) {
		if (_pingnode($computer_name)) {
			notify($ERRORS{'DEBUG'}, 0, "VM $computer_name is pingable");
			$status->{ping} = 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "VM $computer_name is not pingable");
			$status->{ping} = 0;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "Trying to ssh...");
	# Check if SSH is available
	if ($self->os->is_ssh_responding()) {
		notify($ERRORS{'DEBUG'}, 0, "VM $computer_name is responding to SSH");
		$status->{ssh} = 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "VM $computer_name is not responding to SSH, returning 'RELOAD'");
		$status->{status} = 'RELOAD';
		$status->{ssh} = 0;

		# Skip remaining checks if SSH isn't available
		return $status;
	}

	my $current_image_revision_id = $self->os->get_current_image_info();
	$status->{currentimagerevision_id} = $current_image_revision_id;

	$status->{currentimage} = $self->data->get_computer_currentimage_name();
	my $current_image_name = $status->{currentimage};
	my $vcld_post_load_status = $self->data->get_computer_currentimage_vcld_post_load();

	if (!$current_image_revision_id) {
		notify($ERRORS{'OK'}, 0, "unable to retrieve image name from currentimage.txt on VM $computer_name, returning 'RELOAD'");
		return $status;
	}
	elsif ($current_image_revision_id eq $imagerevision_id) {
		notify($ERRORS{'OK'}, 0, "currentimage.txt image $current_image_revision_id ($current_image_name) matches requested imagerevision_id $imagerevision_id  on VM $computer_name");
		$status->{image_match} = 1;
	}
	else {
		notify($ERRORS{'OK'}, 0, "currentimage.txt imagerevision_id $current_image_revision_id ($current_image_name) does not match requested imagerevision_id $imagerevision_id on VM $computer_name, returning 'RELOAD'");
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

	if ($vcld_post_load_status) {
		notify($ERRORS{'DEBUG'}, 0, "OS module post_load tasks have been completed on VM $computer_name");
		$status->{status} = 'READY';
	}
	else {
		notify($ERRORS{'OK'}, 0, "OS module post_load tasks have not been completed on VM $computer_name, returning 'POST_LOAD'");
		$status->{status} = 'POST_LOAD';
	}

	notify($ERRORS{'DEBUG'}, 0, "returning node status hash reference (\$node_status->{status}=$status->{status})");
	return $status;
} ## end sub node_status



#/////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : 
 Returns     : 1 or 0
 Description : Checks the existence of an image.

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "does_image_exist() subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $vcl_image_name = $self->data->get_image_name();

	# Match image name between VCL database and openstack Hbase database
	my $openstack_image_id = _match_image_name($vcl_image_name);
	if (!defined($openstack_image_id))
	{
		notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $openstack_image_id");
		return 0;
	}
	my ($token, $compute_url) = $self->_get_token_account_info();
	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$compute_url . "/images/" . $openstack_image_id,
		x_auth_token => $token,
		x_auth_project_id => $ENV{'OS_PROJECT_ID'},
	);

	if(!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute post token: " . join("\n", $resp->content));
		return 0;
	}

	my $output = from_json($resp->content);
	my $image_status = $output->{image}{status};

	if (defined($image_status) && $image_status eq 'ACTIVE') {
		notify($ERRORS{'OK'}, 0, "The openstack image for $vcl_image_name exists");
		return 1;
	}
	else
	{
		notify($ERRORS{'WARNING'}, 0, "The openstack image for $vcl_image_name does NOT exists");
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
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "get_image_size subroutine was called as a function, it must be called as a class method");
		return 0;
	}
 
	notify($ERRORS{'OK'}, 0, "No image size information in Openstack");

	return 0;
} ## end sub get_image_size

sub _delete_computer_mapping {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id();

	my $delete_statement = "
	DELETE FROM
	openstackComputerMap
	WHERE
	computerid = '$computer_id'
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

sub _get_flavor_type {
	my $openstack_image_name = shift;
	my $image_disk_size;
	# Change the glance image path based on your confirguration
	my $openstack_image_info = "qemu-img info /var/lib/glance/images/$openstack_image_name";
	my $openstack_image_info_output = qx/$openstack_image_info/;
	if ($openstack_image_info_output =~ m/virtual size:(\s\d{1,4})G/g)
	{
		$image_disk_size = $1;
		notify($ERRORS{'OK'}, 0, "The disk size for $openstack_image_name  is $image_disk_size G");
	} else {
		notify($ERRORS{'WARNING'}, 0, "Unable to find $openstack_image_name in /var/lib/glance/images");
		return 0;
	}
	my @flavor_ids;
	my @flavor_disk_sizes;
	my $openstack_flavor_info = "nova flavor-list";
	my $openstack_flavor_info_output = `$openstack_flavor_info`;
	my @lines = split /\n/, $openstack_flavor_info_output;
	foreach my $line (@lines) {
		if($line =~ m/^\|\s(\d+)\s+\|/g) {
			push(@flavor_ids, $1);
		}
		if($line =~ m/\|\s\d+\s+\|\s(\d{1,4})\s+\|/g) {
			push(@flavor_disk_sizes, $1);
		}
	}
	notify($ERRORS{'OK'}, 0, "OpenStack flavor IDs: @flavor_ids, disk sizes: @flavor_disk_sizes");
	my $num_of_ids = @flavor_ids;
	if (!defined($num_of_ids) || $image_disk_size > $flavor_disk_sizes[$num_of_ids-1]) {
		notify($ERRORS{'WARNING'}, 0, "No flavor information or disk size is greater than the maximum flavor");
		return 0;
	}
	my $flavor_type;
	my $index=0;
	foreach my $x (@flavor_disk_sizes) {
		if ($x >= $image_disk_size) {
			$flavor_type = $flavor_ids[$index];
			last;
		}
		$index = $index + 1;
	}
	notify($ERRORS{'OK'}, 0, "OpenStack flavor type = $flavor_type");
	
	return $flavor_type;
}

sub _get_instance_id {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id();

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
		notify($ERRORS{'WARNING'}, 0, "Unable to find the instance id");
		return 0;
	}

	my $instance_id = $selected_rows[0]{instanceid};
	notify($ERRORS{'OK'}, 0, "Openstack id for $computer_id is $instance_id");

	return $instance_id;
}

sub _get_token_account_info {
	my $self = shift;

	my $ua = LWP::UserAgent->new();
	my $url = $ENV{'OS_AUTH_URL'};
	my $auth_data = {
		auth =>  {
		tenantName => $ENV{'OS_TENANT_NAME'},
		passwordCredentials => {
			username => $ENV{'OS_USERNAME'},
			password => $ENV{'OS_PASSWORD'},
		}
		}
	};
	my $resp =  $ua->post(
		$url . "/tokens",
		content_type => 'application/json', 
		content => to_json($auth_data)
	);
	notify($ERRORS{'OK'}, 0, "resp->request: " . join("\n", $resp->request));

	if(!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute post token: " . join("\n", $resp->content));
		return;
	}
	
	my $output = from_json($resp->content);
	my $token = $output->{access}{token}{id};

	my @serviceCatalog = @{ $output->{access}{serviceCatalog} };
	@serviceCatalog = grep { $_->{type} eq 'compute' } @serviceCatalog;
	if(!@serviceCatalog) {
		notify($ERRORS{'WARNING'}, 0, "failed to get compute serviceCatalog");
		return;
	}

	my $service_name = $ENV{'OS_SERVICE_NAME'};
	if ($service_name) {
		@serviceCatalog = grep { $_->{name} eq $service_name } @serviceCatalog;
		if(!@serviceCatalog) {
			notify($ERRORS{'WARNING'}, 0, "failed to get service name: $service_name");
			return;
		}
	}
	my $serviceCatalog = $serviceCatalog[0];
	my $compute_url = $serviceCatalog->{endpoints}[0]{publicURL};

	if(!defined($token) || !defined($compute_url)) {
		notify($ERRORS{'WARNING'}, 0, "Unable to get token or tenant account information");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "compute_url: $compute_url");
	return ($token, $compute_url);
}

sub _image_create{
	my $self = shift;
	my $instance_id = shift;
	my $imagerevision_comments = $self->data->get_imagerevision_comments(0);
	my $image_name     = $self->data->get_image_name();
	
	my $image_version;
	if ($image_name =~ m/(-+)(.+)(-v\d+)/g)
	{
		$image_version = $3;
		notify($ERRORS{'OK'}, 0, "Acquire the Image Version: $image_version");
	}
	my $openstack_image_name = $image_name . $imagerevision_comments;

	my $ua = LWP::UserAgent->new();
	my ($token, $compute_url) = $self->_get_token_account_info();
	my $server_data = {
		createImage =>  {
			name => $openstack_image_name,
			metadata => {
				version => $image_version,
			}
		}
	};

	my $res =  $ua->post(
		$compute_url . "/servers/" . $instance_id . "/action",
		content_type => 'application/json',
		x_auth_token => $token,
		content => to_json($server_data)
	);

	if(!$res->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute capture image: " . join("\n", $res->content));
		return;
	}
	notify($ERRORS{'OK'}, 0, "Capturing an image of $instance_id");

	my $resp =  $ua->get(
		$compute_url . "/images/detail", 
		server => $instance_id,
		content_type => 'application/json',
		x_auth_project_id => $ENV{'OS_PROJECT_ID'},
		x_auth_token => $token
	);

	if(!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get image info: " . join("\n", $resp->content));
		return 0;
	}

	my $output = from_json($resp->content);
	my $openstack_image_id = $output->{images}[0]{id};
	if (!defined($openstack_image_id)) {
		notify($ERRORS{'OK'}, 0, "No image name for new captured instance of $instance_id");
		return 0;
	}
	else {
		my $new_image_name = $openstack_image_id . $image_version;
		notify($ERRORS{'OK'}, 0, "New openstack image name is $new_image_name");
		return $new_image_name;
	}
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
		notify($ERRORS{'DEBUG'}, 0, "unable to insert image name");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "Successfully insert image name");
	return 1;
}

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
	if (scalar @selected_rows == 0 || scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return 0;
	}
	my $openstack_image_name = $selected_rows[0]{openstack_name};
	my $vcl_imagename  = $selected_rows[0]{vcl_name};
	if ($openstack_image_name  =~ m/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})-v/g )
	{
		$openstack_image_name = $1;
		notify($ERRORS{'OK'}, 0, "Acquire the Image ID: $openstack_image_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $openstack_image_name");
		return 0;
	}

	notify($ERRORS{'OK'}, 0, "The OpenStack image name $openstack_image_name is matched to $vcl_imagename");

	return $openstack_image_name;
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
	my $computer_name = $self->data->get_computer_short_name;
	my $computer_nodename  = $computer_name;
	my $computer_hostname  = $self->data->get_computer_hostname;
	my $computer_type      = $self->data->get_computer_type;

	if (write_currentimage_txt($self->data)) {
		notify($ERRORS{'OK'}, 0, "currentimage.txt updated on $computer_name");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "unable to update currentimage.txt on $computer_name");
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

sub _run_instances {
	my $self = shift;
	

	my $image_full_name = $self->data->get_image_name;
	my $computer_name  = $self->data->get_computer_short_name;

	my $openstack_image_id = _match_image_name($image_full_name);
	if (!defined($openstack_image_id))
	{
		notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $openstack_image_id");
		return 0;
	}

	my $flavor_type = _get_flavor_type($openstack_image_id);
	if(!$flavor_type) {
		notify($ERRORS{'DEBUG'}, 0, "Fail to acquire openstack flavor type for $openstack_image_id");
		return 0;
	}

	my $openstack_key;
	my $image_os_type  = $self->data->get_image_os_type;
	if ($image_os_type eq 'linux') {
		$openstack_key =  $ENV{'VCL_LINUX_KEY'}; 	
		notify($ERRORS{'OK'}, 0, "VCL Linux key is $openstack_key");
	} 
	elsif ($image_os_type eq 'windows') {
		$openstack_key =  $ENV{'VCL_WINDOWS_KEY'}; 	
		notify($ERRORS{'OK'}, 0, "VCL Windows key is $openstack_key");
	}
	else {
		notify($ERRORS{'OK'}, 0, "No available openstack keys for $image_full_name");
		return;
	}
	my $ua = LWP::UserAgent->new();
	my ($token, $compute_url) = $self->_get_token_account_info();
	my $server_data = {
		server =>  {
			name => $computer_name,
			imageRef => $openstack_image_id,
			key_name => $openstack_key,
			flavorRef => $flavor_type
		}
	};

	my $resp =  $ua->post(
		$compute_url . "/servers",
		content_type => 'application/json',
		x_auth_token => $token,
		x_auth_project_id => $ENV{'OS_PROJECT_ID'},
		content => to_json($server_data)
	);

	if(!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute run instance: " . join("\n", $resp->content));
		return;
	}

	my $output = from_json($resp->content);
	my $instance_id = $output->{'server'}{'id'};
	if (!defined($instance_id)){
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to get the instance id on $computer_name");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "The run_instance: $instance_id\n");
	
	if (!$self->_insert_instance_id($instance_id)) {
		notify($ERRORS{'OK'}, 0, "Failed to insert the instance id : $instance_id");
		return 0;
	}

	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 _set_openstack_user_conf 

 Parameters  : None 
 Returns     : 1(success) or 0(failure)
 Description : load environment profile and set global environemnt variables 

example: openstack.conf
"os_tenant_name" => "admin",
"os_username" => "admin",
"os_password" => "adminpassword",
"os_auth_url" => "http://openstack_nova_url:5000/v2.0",
"os_service_name" => "nova",
"vcl_windows_key" => "vcl_windows_key",
"vcl_linux_key" => "vcl_linux_key",

=cut

sub _set_openstack_user_conf {
	my $self = shift;
	my $computer_name   = $self->data->get_computer_short_name;
	# User's environment file
	my $user_config_file = '/etc/vcl/openstack/openstack.conf';
	notify($ERRORS{'OK'}, 0, "********* Set OpenStack User Configuration******************");
	notify($ERRORS{'OK'}, 0,  "computer_name: $computer_name");
	notify($ERRORS{'OK'}, 0,  "loading $user_config_file");
	my %config = do($user_config_file);
	if (!%config) {
		notify($ERRORS{'CRITICAL'},0, "failure to process $user_config_file");
		return 0;
	}
	$self->{config} = \%config;
	my $os_auth_url = $self->{config}->{os_auth_url};
	my $os_service_name = $self->{config}->{os_service_name};
	my $os_project_id = $self->{config}->{os_project_id};
	my $os_tenant_name = $self->{config}->{os_tenant_name};
	my $os_username = $self->{config}->{os_username};
	my $os_password = $self->{config}->{os_password};
	my $vcl_windows_key = $self->{config}->{vcl_windows_key};
	my $vcl_linux_key = $self->{config}->{vcl_linux_key};

	# Set Environment File
	$ENV{'OS_AUTH_URL'} = $os_auth_url;
	$ENV{'OS_SERVICE_NAME'} = $os_service_name;
	$ENV{'OS_PROJECT_ID'} = $os_project_id;
	$ENV{'OS_TENANT_NAME'} = $os_tenant_name;
	$ENV{'OS_USERNAME'} = $os_username;
	$ENV{'OS_PASSWORD'} = $os_password;
	$ENV{'VCL_WINDOWS_KEY'} = $vcl_windows_key;
	$ENV{'VCL_LINUX_KEY'} = $vcl_linux_key;

	return 1;
}# _set_openstack_user_conf close

sub _terminate_instances {
	my $self = shift;

	my $instance_id = $self->_get_instance_id();
	my $computer_name = $self->data->get_computer_short_name();
	if (!$instance_id) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the instance id for $computer_name");
		return 0;
	}

	$self->_delete_computer_mapping;

	my ($token, $compute_url) = $self->_get_token_account_info();

	my $ua = LWP::UserAgent->new();
	my $resp =  $ua->delete(
		$compute_url . "/servers/" . $instance_id,
		x_auth_token => $token
	);
	if(!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute terminate instance: " . join("\n", $resp->content));
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "successfully terminate the instance for $computer_name");
	sleep 30;

	return 1;
}

sub _update_private_ip {
	my $self = shift;
	
	my $instance_id = shift;
	my $main_loop = 60;
	my $private_ip;
	my $describe_instance_output;
	my $computer_id = $self->data->get_computer_id;
	my $computer_name  = $self->data->get_computer_short_name;

	my ($token, $compute_url) = $self->_get_token_account_info();
	my $ua = LWP::UserAgent->new();
	my $output;	
	my $resp;


	# Find the correct instance among running instances using the private IP
	while ($main_loop > 0)
	{
		notify($ERRORS{'OK'}, 0, "Try to fetch the Private IP on Computer $computer_name: Number $main_loop");	
		$resp =  $ua->get(
			$compute_url . "/servers/" . $instance_id,
			x_auth_token => $token
		);
		if(!$resp->is_success) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute instance detail: " . join("\n", $resp->content));
			return;
		}

		$output = from_json($resp->content);
		$private_ip = $output->{'server'}{'addresses'}{'private'}[0]->{'addr'};

		if (defined($private_ip) && $private_ip ne "") {
			my $new_private_ip = update_computer_private_ip_address($computer_id, $private_ip);
			if (!defined($new_private_ip)) {
				notify($ERRORS{'OK'}, 0, "The $private_ip on Computer $computer_name is NOT updated");
				return 0;
			}
			notify($ERRORS{'OK'}, 0, "Private IP is $new_private_ip for $computer_name");
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "Waiting for assinging private ip address to $computer_name");
		}

		sleep 20;
		$main_loop--;
	}
	notify($ERRORS{'DEBUG'}, 0, "Private IP for $computer_name is not determined");
	return 0;
}

sub _wait_for_copying_image {
	my $self = shift;
	
	my $openstack_image_id = shift;
	if ($openstack_image_id  =~ m/(\w{8}-\w{4}-\w{4}-\w{4}-\w{12})-v/g )
	{
		$openstack_image_id = $1;
		notify($ERRORS{'OK'}, 0, "Acquire the Image ID: $openstack_image_id");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "Fail to acquire the Image ID: $openstack_image_id");
		return 0;
	}
	my ($token, $compute_url) = $self->_get_token_account_info();
	my $ua = LWP::UserAgent->new();
	my $resp;

	my $output;
	my $image_status;
 
	my $loop = 100;
	while ($loop > 0)
	{
		$resp =  $ua->get(
			$compute_url . "/images/" . $openstack_image_id,
			content_type => 'application/json',
			x_auth_project_id => $ENV{'OS_PROJECT_ID'},
			x_auth_token => $token
		);

		if(!$resp->is_success) {
			notify($ERRORS{'WARNING'}, 0, "failed to get image info: " . join("\n", $resp->content));
			return;
		}

		$output = from_json($resp->content);
		$image_status = $output->{'image'}{'status'};
		if (defined($image_status)) {
			notify($ERRORS{'OK'}, 0, "The describe image output of loop #$loop: $image_status");
			if($image_status eq 'ACTIVE') {
				notify($ERRORS{'OK'}, 0, "$openstack_image_id is available now");
				last;
			}
			elsif ($image_status eq 'SAVING') {
				notify($ERRORS{'OK'}, 0, "Sleep to capture New Image for 25 secs");
				sleep 25;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "Failure for $openstack_image_id");
				return 0;
			}
		}
		sleep 10;
		$loop--;
	}

	return 1;
}


#/////////////////////////////////////////////////////////////////////////////

1;
__END__
