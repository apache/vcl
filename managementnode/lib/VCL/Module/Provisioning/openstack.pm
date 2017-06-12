#!/usr/bin/perl -w
###############################################################################
# $Id: openstack.pm 
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

###############################################################################
package VCL::Module::Provisioning::openstack;

# Include File Copying for Perl
use File::Copy;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Provisioning);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw(-no_match_vars);
use IO::File;
use Fcntl qw(:DEFAULT :flock);
use File::Temp qw(tempfile);
use List::Util qw(max);
use VCL::utils;
use JSON qw(from_json to_json);
use LWP::UserAgent;

#//////////////////////////////////////////////////////////////////////////////

=head2 initialize

 Parameters  :
 Returns     :
 Description :

=cut

sub initialize {
	my $self = shift;
	notify($ERRORS{'DEBUG'}, 0, "OpenStack module initialized");
	
	if ($self->_set_os_auth_conf()) {
		notify($ERRORS{'OK'}, 0, "successfully set openStack auth configuration");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to set openstack auth configuration");
		return 0;
	}
	
	return 1;
} ## end sub initialize


#//////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : hash
 Returns     : 1(success) or 0(failure)
 Description : loads virtual machine with requested image

=cut

sub unload {
	my $self = shift;
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $computer_name = $self->data->get_computer_short_name() || return;
	my $vmhost_name = $self->data->get_vmhost_short_name() || return;
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();

	# Remove existing VMs which were created for the reservation computer
	if (_pingnode($computer_private_ip_address)) {
		if (!$self->_terminate_os_instance()) {
			notify($ERRORS{'WARNING'}, 0, "failed to delete VM $computer_name on VM host $vmhost_name");
			return 0;
		}
	}
	# Remove existing openstack id for computer mapping in database 
	# Althought the instance is not pingable (delete it accidently), it should delete the instance from database
	if (!$self->_delete_os_computer_mapping()) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the openstack instance id from openstackcomputermap");
		return 0;
	}

	return 1;

}

#//////////////////////////////////////////////////////////////////////////////

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
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address() || return;

	insertloadlog($reservation_id, $computer_id, "startload", "$computer_name $image_name");
	notify($ERRORS{'DEBUG'}, 0, "computer_private_ip_address = [$computer_private_ip_address]");

	# Remove existing VMs which were created for the reservation computer
	if (_pingnode($computer_private_ip_address)) {
		if (!$self->_terminate_os_instance()) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to delete VM $computer_name on VM host $vmhost_name");
		}
	}
	# Remove existing openstack id for computer mapping in database 
	# Althought the instance is not pingable (delete it accidently), it should delete the instance from database
	if (!$self->_delete_os_computer_mapping()) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete the openstack instance id from openstackcomputermap");
		return;
	}

	# Create new instance 
	my $os_instance_id = $self->_post_os_create_instance();
	if (!defined($os_instance_id)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to create an instance for computer $computer_name on VM host: $vmhost_name");
		return;
	}

	# Update the private ip of the instance in database
	if (!$self->_update_private_ip($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to update private ip of the instance in database");
		return;
	}

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
		notify($ERRORS{'WARNING'}, 0, ref($self->os) . "::post_load() has not been implemented");
		return;
	}

	return 1;

} ## end sub load

#//////////////////////////////////////////////////////////////////////////////

=head2 capture

 Parameters  : None
 Returns     : 1 if sucessful, 0 if failed
 Description : capturing a new OpenStack image.

=cut

sub capture {
	my $self = shift;

	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}

	my $reservation_id = $self->data->get_reservation_id() || return;
	my $current_imagerevision_id = $self->os->get_current_imagerevision_id();
	my $computer_id = $self->data->get_computer_id() || return;
	my $image_name = $self->data->get_image_name() || return;
	my $computer_name = $self->data->get_computer_short_name() || return;
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address() || return;

	insertloadlog($reservation_id, $computer_id, "startcapture", "$computer_name $image_name");
	notify($ERRORS{'DEBUG'}, 0, "computer_private_ip_address = [$computer_private_ip_address]");
	
	# Remove existing VMs which were created for the reservation computer
	if (!_pingnode($computer_private_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "unable to ping to $computer_name");
		return;
	}

	my $os_instance_id = $self->_get_os_instance_id();
	if (!defined($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "unable to get instance id for $computer_name");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "os_instance_id: $os_instance_id");

	my $os_flavor_id = _get_os_flavor_id($current_imagerevision_id);
	notify($ERRORS{'DEBUG'}, 0, "current imagerevision id is $current_imagerevision_id, flavor_id: $os_flavor_id");
	if (!defined($os_flavor_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get current openstack flavor id");
		return;
	}
		
	if (!$self->_prepare_capture()) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute prepare_capture");
		return;
	}
	
	my $os_image_id = $self->_post_os_create_image($os_instance_id);
	if (!defined($os_image_id)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to create image for $computer_name");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "os_image_id: $os_image_id");

	if (!$self->_wait_for_copying_image($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute _wait_for_copying_image for $os_image_id");
		return;
	}

	# insert image details and flavor details, check status is ACTIVE before insert
	if (!$self->_insert_os_image_id($os_image_id, $os_flavor_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to insert openstack image id");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "capturing $os_instance_id into $os_image_id is done");

	return 1;
} ## end sub capture

#//////////////////////////////////////////////////////////////////////////////

=head2 does_image_exist

 Parameters  : 
 Returns     : 1 or 0
 Description : Checks the existence of an image.

=cut

sub does_image_exist {
	my $self = shift;
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return 0;
	}

	my $imagerevision_id = $self->data->get_imagerevision_id() || return 0;
	my $image_name = $self->data->get_image_name() || return 0;
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	if (!defined($os_token) || !defined($os_compute_url) || !defined($os_project_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth info");
		return 0;
	}

	# Get the openstack image id for the corresponding VCL image revision id
	my $os_image_id = _get_os_image_id($imagerevision_id);
	if (!defined($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to acquire the openstack image id : $os_image_id");
		return 0;
	}

	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$os_compute_url . "/images/" . $os_image_id,
		x_auth_token => $os_token,
		x_auth_project_id => $os_project_id,
	);

	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute post token: " . join("\n", $resp->content));
		return 0;
	}

	my $output = from_json($resp->content);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json ouput: $output");
		return 0;
	}

	my $image_status = $output->{image}{status};
	if (defined($image_status) && $image_status eq 'ACTIVE') {
		notify($ERRORS{'OK'}, 0, "The openstack image for $image_name exists");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "The openstack image for $image_name does NOT exists");
		return 0;
	}

} ## end sub does_image_exist

#//////////////////////////////////////////////////////////////////////////////

=head2  get_image_size

 Parameters  : imagename
 Returns     : 0 failure or size of image
 Description : in size of Megabytes

=cut

sub get_image_size {
	my $self = shift;
	if (ref($self) !~ /openstack/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
 
	# Attempt to get the image name argument
	my $image_name = shift;
	my $imagerevision_id = $self->data->get_imagerevision_id() || return;
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	if (!defined($os_token) || !defined($os_compute_url) || !defined($os_project_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth info");
		return;
	}
	my $os_image_id = _get_os_image_id($imagerevision_id);
	if (!defined($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to acquire the openstack image id : $os_image_id for $image_name");
		return;
	}

	my $ua = LWP::UserAgent->new();
	my $resp = $ua->get(
		$os_compute_url . "/images/" . $os_image_id,
		x_auth_token => $os_token,
		x_auth_project_id => $os_project_id,
	);

	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute post token: " . join("\n", $resp->content));
		return;
	}

	my $output = from_json($resp->content);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json ouput: $output");
		return;
	}

	my $os_image_size_bytes = $output->{'image'}{'OS-EXT-IMG-SIZE:size'};
	if (!defined($os_image_size_bytes)) {
		notify($ERRORS{'WARNING'}, 0, "The openstack image size for $image_name does NOT exists");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "os_image_size_bytes: $os_image_size_bytes for $image_name");
	return round($os_image_size_bytes / 1024 / 1024);
} ## end sub get_image_size

#//////////////////////////////////////////////////////////////////////////////

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
	my $request_forimaging = $self->data->get_request_forimaging();
	my $imagerevision_id = $self->data->get_imagerevision_id();
	my $computer_private_ip_address = $self->data->get_computer_private_ip_address();


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
		if (_pingnode($computer_private_ip_address)) {
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

	my $current_image_revision_id = $self->os->get_current_imagerevision_id();
	$status->{currentimagerevision_id} = $current_image_revision_id;

	$status->{currentimage} = $self->data->get_computer_currentimage_name();
	my $current_image_name = $status->{currentimage};
	my $vcld_post_load_status = $self->os->get_post_load_status();

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


	if ($request_forimaging) {
		$status->{status} = 'RELOAD';
		notify($ERRORS{'OK'}, 0, "request_forimaging set, setting status to RELOAD");
	}

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

											       
#//////////////////////////////////////////////////////////////////////////////

=head2 _delete_os_computer_mapping

 Parameters  : computer id
 Returns     : 1 or 0
 Description : delete match VCL computer id with OpenStack instance id

=cut

sub _delete_os_computer_mapping {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id();
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get computer id");
		return 0;
	}

	my $sql_statement = <<EOF;
SELECT
computerid
FROM
openstackcomputermap
WHERE
computerid = '$computer_id'
EOF

	#notify($ERRORS{'DEBUG'}, 0, "delete_os_computer_mapping: $sql_statement");
	my @selected_rows = database_select($sql_statement);
	if (scalar @selected_rows == 0) {
		notify($ERRORS{'OK'}, 0, "no instance for $computer_id");
		return 1;
	}

	$sql_statement = <<EOF;
DELETE FROM
openstackcomputermap
WHERE
computerid = '$computer_id'
EOF
	#notify($ERRORS{'DEBUG'}, 0, "$sql_statement");
	my $result = database_execute($sql_statement);

	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to delete computer mapping");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "successfully deleted computer mapping");
	sleep 5;
	return 1;
} ## end sub _delete_os_computer_mapping

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_os_flavor_id

 Parameters  : image revision id 
 Returns     : OpenStack image id or 0
 Description : match VCL image revision id with OpenStack image id 

=cut

sub _get_os_flavor_id {
	my $imagerevision_id = shift;
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get image revision id");
		return;
	}

	my $sql_statement = <<EOF;
SELECT
flavordetails as flavor
FROM
openstackimagerevision 
WHERE
imagerevisionid = '$imagerevision_id'
EOF

	#notify($ERRORS{'DEBUG'}, 0, "get_os_flavor_id: $sql_statement");
	my @selected_rows = database_select($sql_statement);
	if (scalar @selected_rows == 0 || scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return;
	}
	my $os_flavor_detail  = from_json($selected_rows[0]{flavor});
	if (!defined($os_flavor_detail)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack flavor detail");
		return;
	}
	my $os_flavor_id = $os_flavor_detail->{flavor}{id};
	if (!defined($os_flavor_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack flavor id");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "os_flavor_id: $os_flavor_id");
	return $os_flavor_id;
} ## end sub _get_os_flavor_id

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_os_image_id

 Parameters  : image revision id 
 Returns     : OpenStack image id or 0
 Description : Get the OpenStack image id corresponding to the VCL image revision id  

=cut

sub _get_os_image_id {
	my $imagerevision_id = shift;
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to get image revision id");
		return 0;
	}

	my $sql_statement = <<EOF;
SELECT
imagedetails as image
FROM
openstackimagerevision 
WHERE
imagerevisionid = '$imagerevision_id'
EOF

	notify($ERRORS{'DEBUG'}, 0, "get_os_image_id: $sql_statement");
	my @selected_rows = database_select($sql_statement);
	if (scalar @selected_rows == 0 || scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return 0;
	}
	my $os_image_detail = from_json($selected_rows[0]{image});
	if (!defined($os_image_detail)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack image detail");
		return 0;
	}

	my $os_image_id = $os_image_detail->{image}{id};
	if (!defined($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack image id");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "openstack image_id: $os_image_id");

	return $os_image_id;
} ## end sub _get_os_image_id

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_os_instance_id

 Parameters  : None
 Returns     : OpenStack instance id or 0
 Description : Checks the existence of an OpenStack instance.

=cut
sub _get_os_instance_id {
	my $self = shift;
	my $computer_id = $self->data->get_computer_id();
	if (!defined($computer_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get computer id");
		return;
	}

	my $sql_statement = <<EOF;
SELECT
instanceid as id
FROM
openstackcomputermap
WHERE
computerid = '$computer_id'
EOF

	#notify($ERRORS{'DEBUG'}, 0, "$sql_statement");
	my @selected_rows = database_select($sql_statement);
	if (scalar @selected_rows == 0 || scalar @selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @selected_rows . " rows were returned from database select");
		return;
	}

	my $os_instance_id = $selected_rows[0]{id};
	if (!defined($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack instance id");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "Openstack instance id for $computer_id is $os_instance_id");
	return $os_instance_id;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_os_token_computer_url

 Parameters  : None 
 Returns     : Openstack auth (token, compute url) or 0
 Description : Get the OpenStack auth token and compute url   

=cut

sub _get_os_token_compute_url {
	my $self = shift;

	my $os_auth_url = $ENV{'OS_AUTH_URL'};
	my $os_tenant_name = $ENV{'OS_TENANT_NAME'};
	my $os_user_name = $ENV{'OS_USERNAME'};
	my $os_user_password = $ENV{'OS_PASSWORD'};
	my $os_service_name = $ENV{'OS_SERVICE_NAME'};
	if (!defined($os_auth_url) || !defined($os_tenant_name) 
		|| !defined($os_user_name) || !defined($os_user_password) || !defined($os_service_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth information from environment");
		return 0;
	}

	my $os_auth_data = {
		auth =>  {
			tenantName => $os_tenant_name,
			passwordCredentials => {
				username => $os_user_name,
				password => $os_user_password,
			}
		}
	};

	my $ua = LWP::UserAgent->new();
	my $resp =  $ua->post(
		$os_auth_url . "/tokens",
		content_type => 'application/json', 
		content => to_json($os_auth_data)
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack token: " . join("\n", $resp->content));
		return 0;
	}
	
	my $output = from_json($resp->content);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return 0;
	}

	my $os_token = $output->{access}{token}{id};
	if (!defined($os_token)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get token");
		return 0;
	}

	my @serviceCatalog = @{ $output->{access}{serviceCatalog} };
	@serviceCatalog = grep { $_->{type} eq 'compute' } @serviceCatalog;
	if (!@serviceCatalog) {
		notify($ERRORS{'WARNING'}, 0, "failed to get compute service catalog");
		return 0;
	}

	@serviceCatalog = grep { $_->{name} eq $os_service_name } @serviceCatalog;
	my $serviceCatalog = $serviceCatalog[0];
	if (!defined($serviceCatalog)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get service name: $os_service_name");
		return 0;
	}

	my $os_compute_url = $serviceCatalog->{endpoints}[0]{publicURL};
	if (!defined($os_compute_url)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get compute server url");
		return 0;
	}

	#notify($ERRORS{'DEBUG'}, 0, "token: $os_token, compute_url: $os_compute_url");
	return ($os_token, $os_compute_url);
} ## end sub get_os_token_compute_url

#//////////////////////////////////////////////////////////////////////////////

=head2 _insert_os_image_id

 Parameters  : OpenStack image id
 Returns     : 1 or 0
 Description : insert OpenStack image id and corresponding imagerevision id     

=cut

sub _insert_os_image_id {
	my $self = shift;
	my ($os_image_id, $os_flavor_id) = @_;
	notify($ERRORS{'DEBUG'}, 0, "the openstack id: $os_image_id,  flavor id: $os_flavor_id");
	if (!defined($os_image_id) || !defined($os_flavor_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack id: $os_image_id or flavor id: $os_flavor_id");
		return 0;
	}
	my $imagerevision_id = $self->data->get_imagerevision_id();
	if (!defined($imagerevision_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the imagerevision id");
		return 0;
	}
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	if (!defined($os_token) || !defined($os_compute_url) || !defined($os_project_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack auth info");
		return 0;
	}

	my $ua = LWP::UserAgent->new();
	my $res = $ua->get(
		$os_compute_url . "/images/" . $os_image_id,
		x_auth_token => $os_token,
		x_auth_project_id => $os_project_id,
	);
	if (!$res->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack image info: " . join("\n", $res->content));
		return 0;
	}
	my $os_image_details = $res->content;
	if (!defined($os_image_details)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return 0;
	}

	my $resp = $ua->get(
		$os_compute_url . "/flavors/". $os_flavor_id,
		x_auth_token => $os_token,
		x_auth_project_id => $os_project_id,
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack flavor info: " . join("\n", $resp->content));
		return 0;
	}
	my $os_flavor_details = $resp->content;
	if (!defined($os_flavor_details)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return 0;
	}

	my $sql_statement = <<EOF;
INSERT INTO
openstackimagerevision (
imagerevisionid, 
imagedetails,
flavordetails) 
VALUES ( 
	'$imagerevision_id',
	'$os_image_details',
	'$os_flavor_details')
EOF

	#notify($ERRORS{'DEBUG'}, 0, "$sql_statement");
	my $result = database_execute($sql_statement);

	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to insert openstack image id");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "successfully insert openstack image id");
	sleep 5;
	return 1;
} ## end sub _insert_os_image_id

#//////////////////////////////////////////////////////////////////////////////

=head2 _insert_os_instance_id

 Parameters  : OpenStack instance id
 Returns     : 1 or 0
 Description : insert OpenStack instance id and corresponding computer id

=cut

sub _insert_os_instance_id {
	my $self = shift;
	my $os_instance_id = shift;
	my $computer_id = $self->data->get_computer_id();
	if (!defined($os_instance_id) || !defined($computer_id)) {
		notify($ERRORS{'DEBUG'}, 0, "failed to get the openstack instance id: $os_instance_id or computer id: $computer_id");
		return 0;
	}

	my $sql_statement = <<EOF;
INSERT INTO
openstackcomputermap (
instanceid,
computerid)
VALUES
('$os_instance_id', '$computer_id')
EOF

	#notify($ERRORS{'DEBUG'}, 0, "$sql_statement");
	my $result = database_execute($sql_statement);
	if (!defined($result)) {
		notify($ERRORS{'WARNING'}, 0, "failed to insert openstack instance id");
		return 0;
	}

	notify($ERRORS{'DEBUG'}, 0, "successfully insert openstack instance id and comptuer id");
	sleep 5;
	return 1;
} ## end sub_insert_os_instance_id

#//////////////////////////////////////////////////////////////////////////////

=head2 _post_os_create_image

 Parameters  : OpenStack instance id
 Returns     : 1 or 0
 Description : capture OpenStack instance    

=cut

sub _post_os_create_image{
	my $self = shift;
	my $os_instance_id = shift;
	if (!defined($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack instance id");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "os_instance_id: $os_instance_id in sub _post_os_create_image");
	my $image_name = $self->data->get_image_name();
	if (!defined($image_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth information from environment");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "os_image_name: $image_name in sub _post_os_create_image");
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	if (!defined($os_token) || !defined($os_compute_url) || !defined($os_project_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth information from environment");
		return;
	}

	my $ua = LWP::UserAgent->new();
	my $server_data = {
		createImage =>  {
			name => $image_name,
		}
	};

	my $res =  $ua->post(
		$os_compute_url . "/servers/" . $os_instance_id . "/action",
		content_type => 'application/json',
		x_auth_token => $os_token,
		content => to_json($server_data)
	);

	if (!$res->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute capture image: " . join("\n", $res->content));
		return;
	}

	my $resp =  $ua->get(
		$os_compute_url . "/images/detail", 
		server => $os_instance_id,
		content_type => 'application/json',
		x_auth_project_id => $os_project_id,
		x_auth_token => $os_token
	);

	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to get image info: " . join("\n", $resp->content));
		return;
	}

	my $output = from_json($resp->content);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return;
	}
	my $os_image_id = $output->{images}[0]{id};
	if (!defined($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to capture instance of $os_instance_id");
		return;
	}

	notify($ERRORS{'DEBUG'}, 0, "openstack image id for caputed instance of $os_instance_id is $os_image_id");
	return $os_image_id;
} ## end sub _post_os_create_image

#//////////////////////////////////////////////////////////////////////////////

=head2 _post_os_create_instance

 Parameters  : None
 Returns     : 1 or 0
 Description : create an OpenStack instance    

=cut

sub _post_os_create_instance {
	my $self = shift;
	
	my $imagerevision_id = $self->data->get_imagerevision_id() || return;
	my $computer_name  = $self->data->get_computer_short_name() || return;
	my $image_os_type  = $self->data->get_image_os_type() || return;
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	my $os_key_name = $ENV{'VCL_LINUX_KEY'}; 	
	if (!defined($os_project_id) || !defined($os_key_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack project id or key name");
		return;
	}
	if ($image_os_type eq 'linux') {
		$os_key_name =  $ENV{'VCL_LINUX_KEY'}; 	
		notify($ERRORS{'OK'}, 0, "The $os_key_name is the key for Linux (default)");
	} 
	elsif ($image_os_type eq 'windows') {
		$os_key_name =  $ENV{'VCL_WINDOWS_KEY'}; 	
		notify($ERRORS{'OK'}, 0, "The $os_key_name is the key for Windows");
	}

	my $os_image_id = _get_os_image_id($imagerevision_id);
	if (!defined($os_image_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack image id");
		return;
	}

	my $os_flavor_id = _get_os_flavor_id($imagerevision_id);
	if (!$os_flavor_id) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack flavor id");
		return;
	}

	my $ua = LWP::UserAgent->new();
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $server_data = {
		server =>  {
			name => $computer_name,
			imageRef => $os_image_id,
			key_name => $os_key_name,
			flavorRef => $os_flavor_id
		}
	};

	my $resp =  $ua->post(
		$os_compute_url . "/servers",
		content_type => 'application/json',
		x_auth_token => $os_token,
		x_auth_project_id => $os_project_id,
		content => to_json($server_data)
	);

	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute run instance: " . join("\n", $resp->content));
		return;
	}

	my $output = from_json($resp->content);
	notify($ERRORS{'DEBUG'}, 0, "create_instance output: $output");
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
		return;
	}
	my $os_instance_id = $output->{'server'}{'id'};
	if (!defined($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute command to get the instance id on $computer_name");
		return;
	}

	if (!$self->_insert_os_instance_id($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to insert the instance id : $os_instance_id");
		return; 
	}

	notify($ERRORS{'DEBUG'}, 0, "The create_instance: $os_instance_id\n");
	return $os_instance_id;
} ## end sub _post_os_create_instance

#//////////////////////////////////////////////////////////////////////////////

=head2 _prepare_capture

 Parameters  : None
 Returns     : 1 or 0
 Description : prepare capturing instance     

=cut

sub _prepare_capture {
	my $self = shift;
	
	my ($package, $filename, $line, $sub) = caller(0);
	my $request_data = $self->data->get_request_data();
	if (!$request_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve request data hash");
		return 0;
	}
	my $computer_name = $self->data->get_computer_short_name();
	if (!defined($computer_name)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get computer name");
		return 0;
	}

	if (!$self->data->set_imagemeta_sysprep(0)) {
		notify($ERRORS{'WARNING'}, 0, "failed to set the imagemeta Sysprep value to 0");
		return 0;
	}

	if ($self->os->can("pre_capture")) {
		notify($ERRORS{'OK'}, 0, "calling OS module's pre_capture() subroutine");

		if (!$self->os->pre_capture({end_state => 'on'})) {
			notify($ERRORS{'WARNING'}, 0, "OS module pre_capture() failed");
			return 0;
		}
	}

	notify($ERRORS{'DEBUG'}, 0, "pre_capture() is done");
	return 1;
} ## end sub _prepare_capture

#//////////////////////////////////////////////////////////////////////////////

=head2 _set_os_auth_conf 

 Parameters  : None 
 Returns     : 1(success) or 0(failure)
 Description : load openstack environment profile and set global environemnt variables 

example: openstack.conf
"os_tenant_name" => "admin",
"os_username" => "admin",
"os_password" => "adminpassword",
"os_auth_url" => "http://openstack_nova_url:5000/v2.0",
"os_service_name" => "nova",
"vcl_windows_key" => "vcl_windows_key",
"vcl_linux_key" => "vcl_linux_key",

=cut

sub _set_os_auth_conf {
	my $self = shift;
	# User's environment file
	my $user_config_file = '/etc/vcl/openstack/openstack.conf';
	my %config = do($user_config_file);
	if (!%config) {
		notify($ERRORS{'WARNING'},0, "failure to process $user_config_file");
		return;
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
}# end sub _set_os_auth_conf

#//////////////////////////////////////////////////////////////////////////////

=head2 _terminate_os_instance

 Parameters  : None
 Returns     : 1 or 0
 Description : terminate an OpenStack instance    

=cut

sub _terminate_os_instance {
	my $self = shift;

	my $computer_name = $self->data->get_computer_short_name() || return 0;
		
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	my $os_instance_id = $self->_get_os_instance_id();
	if (!defined($os_token) || !defined($os_compute_url) || !defined($os_project_id) || !defined($os_instance_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack auth info");
		return 0;
	}

	my $ua = LWP::UserAgent->new();
	my $resp =  $ua->delete(
		$os_compute_url . "/servers/" . $os_instance_id,
		x_auth_token => $os_token
	);
	if (!$resp->is_success) {
		notify($ERRORS{'WARNING'}, 0, "failed to execute terminate instance: " . join("\n", $resp->content));
		return 0;
	}

	sleep 30;
	return 1;
} ## end sub _terminate_os_instance

#//////////////////////////////////////////////////////////////////////////////

=head2 _update_os_instance

 Parameters  : OpenStack instance id
 Returns     : 1 or 0
 Description : update the private ip address of the OpenStack instance in database 

=cut

sub _update_private_ip {
	my $self = shift;
	
	my $os_instance_id = shift;
	my $computer_id = $self->data->get_computer_id() || return 0;
	my $computer_name  = $self->data->get_computer_short_name() || return 0;
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	if (!defined($os_instance_id) || !defined($os_token) || !defined($os_compute_url)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get the openstack auth info");
		return 0;
	}
	my $ua = LWP::UserAgent->new();
	my ($private_ip, $output, $resp);
	my $main_loop = 60;

	# Find the correct instance among running instances using the private IP
	while ($main_loop > 0) {
		notify($ERRORS{'DEBUG'}, 0, "try to fetch the private IP address for $computer_name, loop of $main_loop");	
		$resp =  $ua->get(
			$os_compute_url . "/servers/" . $os_instance_id,
			x_auth_token => $os_token
		);
		if (!$resp->is_success) {
			notify($ERRORS{'WARNING'}, 0, "failed to execute instance detail: " . join("\n", $resp->content));
			return 0;
		}

		$output = from_json($resp->content);
		if (!defined($output)) {
			notify($ERRORS{'WARNING'}, 0, "failed to parse json output");
			return 0;
		}
		$private_ip = $output->{'server'}{'addresses'}{'private'}[0]->{'addr'};

		if (defined($private_ip)) {
			my $result = update_computer_private_ip_address($computer_id, $private_ip);
			if (!defined($result)) {
				notify($ERRORS{'WARNING'}, 0, "The $private_ip on Computer $computer_name is NOT updated");
				return 0;
			}
			notify($ERRORS{'DEBUG'}, 0, "private IP address is $private_ip for $computer_name");
			sleep 10;
			return 1;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "waiting for assinging private IP address to $computer_name");
		}
		
		sleep 20;
		$main_loop--;
	}

	notify($ERRORS{'DEBUG'}, 0, "private IP address for $computer_name is not determined");
	return 0;
} ## end sub _update_private_ip

#//////////////////////////////////////////////////////////////////////////////

=head2 _wait_for_copying_image

 Parameters  : OpenStack image id
 Returns     : 1 or 0
 Description : wait for copying the OpenStack image to repository

=cut

sub _wait_for_copying_image {
	my $self = shift;
	
	my $os_image_id = shift;
	my ($os_token, $os_compute_url) = $self->_get_os_token_compute_url();
	my $os_project_id = $ENV{'OS_PROJECT_ID'};
	if (!defined($os_image_id) || !defined($os_token) || !defined($os_compute_url) || !defined($os_project_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to get openstack auth info or image id: $os_image_id");
		return 0;
	}
	my $ua = LWP::UserAgent->new();
	my ($resp, $output, $image_status);

	my $main_loop = 100;
	while ($main_loop > 0) {
		$resp =  $ua->get(
			$os_compute_url . "/images/" . $os_image_id,
			content_type => 'application/json',
			x_auth_project_id => $os_project_id,
			x_auth_token => $os_token
		);

		if (!$resp->is_success) {
			notify($ERRORS{'WARNING'}, 0, "failed to get image info: " . join("\n", $resp->content));
			return 0;
		}

		$output = from_json($resp->content);
		$image_status = $output->{'image'}{'status'};
		if (defined($image_status)) {
			notify($ERRORS{'DEBUG'}, 0, "image status: $image_status for loop #$main_loop");
			if ($image_status eq 'ACTIVE') {
				notify($ERRORS{'OK'}, 0, "$os_image_id is available now");
				return 1;
			}
			elsif ($image_status eq 'SAVING') {
				notify($ERRORS{'DEBUG'}, 0, "wait 25 seconds for capturing instance");
				sleep 25;
			}
			else {
				notify($ERRORS{'DEBUG'}, 0, "failed to capture image for $os_image_id");
				return 0;
			}
		}
		sleep 10;
		$main_loop--;
	}

	return 0;
} ## end sub _wait_for_copying_image

sub power_reset {

	return 1;

}

#//////////////////////////////////////////////////////////////////////////////
1;
__END__
