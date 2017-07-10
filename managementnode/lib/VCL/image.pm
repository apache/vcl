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

VCL::image - Perl module for the VCL image state

=head1 SYNOPSIS

 use VCL::image;
 use VCL::utils;

 # Set variables containing the IDs of the request and reservation
 my $request_id = 5;
 my $reservation_id = 6;

 # Call the VCL::utils::get_request_info subroutine to populate a hash
 my $request_info = get_request_info($request_id);

 # Set the reservation ID in the hash
 $request_info->{RESERVATIONID} = $reservation_id;

 # Create a new VCL::image object based on the request information
 my $image = VCL::image->new($request_info);

=head1 DESCRIPTION

 This module supports the VCL "image" state.

=cut

###############################################################################
package VCL::image;

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

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 process

 Parameters  : $request_data_hash_reference
 Returns     : 1 if successful, 0 otherwise
 Description : Processes a reservation in the timout state. You must pass this
               method a reference to a hash containing request data.

=cut

sub process {
	my $self = shift;
	
	# Check if image OS needs to be updated
	# Do this before retrieving data because it may change
	if ($self->provisioner->can('check_image_os')) {
		if (!$self->provisioner->check_image_os()) {
			return;
		}
	}
	
	my $request_id                 = $self->data->get_request_id();
	my $request_state_name         = $self->data->get_request_state_name();
	my $reservation_id             = $self->data->get_reservation_id();
	my $user_id                    = $self->data->get_user_id();
	my $user_unityid               = $self->data->get_user_login_id();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_id                   = $self->data->get_image_id();
	my $image_name                 = $self->data->get_image_name();
	my $image_size                 = $self->data->get_image_size();
	my $imagerevision_id           = $self->data->get_imagerevision_id();
	my $imagemeta_sysprep          = $self->data->get_imagemeta_sysprep();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_type              = $self->data->get_computer_type();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $managementnode_shortname   = $self->data->get_management_node_short_name();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email(0);
	
	# Send an email to administrators indicating image capture started
	if ($sysadmin_mail_address) {
		my ($admin_subject, $admin_message) = $self->get_admin_message('image_creation_started');
		if (defined($admin_subject) && defined($admin_message)) {
			mail($sysadmin_mail_address, $admin_subject, $admin_message, $affiliation_helpaddress);
		}
	}

	# Make sure image does not already exist
	my $image_already_exists = $self->provisioner->does_image_exist();
	if ($image_already_exists) {
		notify($ERRORS{'CRITICAL'}, 0, "image $image_name already exists");
		$self->reservation_failed();
	}
	elsif (!defined($image_already_exists)) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to determine if image $image_name already exists");
		$self->reservation_failed();
	}
	else {
		notify($ERRORS{'OK'}, 0, "image $image_name does not exist");
	}
	
	# Get the current timestamp
	# This will be used for image.lastupdate, imagerevision.datecreated and currentimage.txt
	my $timestamp = makedatestring();
	$self->data->set_image_lastupdate($timestamp);
	$self->data->set_imagerevision_date_created($timestamp);
	
	# Check if capture() subroutine has been implemented by the provisioning module
	if (!$self->provisioner->can("capture")) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to capture image, " . ref($self->provisioner) . " provisioning module does not implement a 'capture' subroutine");
		$self->reservation_failed();
	}
	
	# If this was a checkpoint, make sure the provisioning module implements a power_on subroutine
	if ($request_state_name eq 'checkpoint' && !$self->provisioner->can('power_on')) {
		notify($ERRORS{'CRITICAL'}, 0, "failed to create checkpoint of image, " . ref($self->provisioner) . " provisioning module does not implement a 'power_on' subroutine, won't be able to power the computer back on after image is captured in order to return it to a usable state for the user");
		$self->reservation_failed();
	}
	
	# Make sure post_reservation scripts get executed before capturing computer
	# This is normally done by reclaim.pm, but this won't be called in the following capture/reload sequence
	$self->os->post_reservation();
	
	# Call the provisioning modules's capture() subroutine
	# The provisioning module should do everything necessary to capture the image
	notify($ERRORS{'OK'}, 0, "calling provisioning module's capture() subroutine");
	if ($self->provisioner->capture()) {
		notify($ERRORS{'OK'}, 0, "$image_name image was successfully captured by the provisioning module");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "$image_name image failed to be captured by provisioning module");
		$self->reservation_failed();
	}
	
	# If this was a checkpoint, power the computer back on and wait for it to respond
	if ($request_state_name eq 'checkpoint') {
		if (!$self->provisioner->power_on()) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to create checkpoint of image, failed to power $computer_shortname back on after image was captured");
			$self->reservation_failed();
		}
		
		# Check if the OS module implements a post_load subroutine
		if ($self->os->can('post_load')) {
			if ($self->os->post_load()) {
				# Add a line to currentimage.txt indicating post_load has run
				$self->os->set_post_load_status();
			}
			else {
				notify($ERRORS{'CRITICAL'}, 0, "failed to create checkpoint of image, unable to complete OS post-load tasks on $computer_shortname after image was captured and computer was powered on");
				$self->reservation_failed();
			}
		}
		
		if (!$self->os->reserve()) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to create checkpoint of image, unable to complete OS reserve tasks on $computer_shortname");
			$self->reservation_failed();
		}
		
		# Disable user connection checking for this request to prevent timeouts
		update_request_checkuser($request_id, 0);
	}
	
	# Get the new image size
	my $image_size_new;
	if ($image_size_new = $self->provisioner->get_image_size($image_name)) {
		notify($ERRORS{'OK'}, 0, "size of $image_name: $image_size_new");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve size of new revision: $image_name, old size will be used");
		$image_size_new = $image_size;
	}
	$self->data->set_image_size($image_size_new);
	
	# Update image timestamp, image size, clear deleted flag
	my $update_image_statement = <<EOF;
UPDATE
image,
imagerevision
SET
image.lastupdate = '$timestamp',
image.deleted = '0',
image.size = '$image_size_new',
image.name = '$image_name',
imagerevision.deleted = '0',
imagerevision.datecreated = '$timestamp'
WHERE
image.id = $image_id
AND imagerevision.id = $imagerevision_id
EOF
	
	# Execute the image update statement
	if (database_execute($update_image_statement)) {
		notify($ERRORS{'OK'}, 0, "image and imagerevision tables updated for image=$image_id, imagerevision=$imagerevision_id, name=$image_name, lastupdate=$timestamp, deleted=0, size=$image_size_new");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "image table could not be updated for image=$image_id");
	}
	
	# Call the OS module's post_capture subroutine
	# This call might be relocated to each provisioning module's process subroutine like the call to pre_capture
	$self->os->post_capture();
	
	$self->reservation_successful($image_size);
} ## end sub process

#//////////////////////////////////////////////////////////////////////////////

=head2 reservation_successful

 Parameters  : $image_size_old
 Returns     : exits
 Description : Handles final steps when an image capture is successful. Sends
               message to image creator. Inserts reload request into the
               database for the newly captured image revision on the computer
               which was used to capture it.

=cut

sub reservation_successful {
	my $self           = shift;
	my $image_size_old = shift || 0;
	
	my $request_data               = $self->data->get_request_data();
	my $request_state_name         = $self->data->get_request_state_name();
	my $user_email                 = $self->data->get_user_email();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $computer_id                = $self->data->get_computer_id();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email(0);
	
	# Send a capture completed message to the image owner
	my ($user_subject, $user_message);
	if ($request_state_name =~ /(checkpoint)/i) {
		($user_subject, $user_message) = $self->get_user_message('image_checkpoint_success');
	}
	else {
		($user_subject, $user_message) = $self->get_user_message('image_creation_success');
	}
	if (defined($user_subject) && defined($user_message)) {
		mail($user_email, $user_subject, $user_message, $affiliation_helpaddress);
	}
	
	# Send mail to administrators
	if ($sysadmin_mail_address) {
		# Get the administrator email subject and message
		my ($admin_subject, $admin_message) = $self->get_admin_message('image_creation_complete');
		if (defined($admin_subject) && defined($admin_message)) {
			mail($sysadmin_mail_address, $admin_subject, $admin_message, $affiliation_helpaddress);
		}
	}
	
	if ($request_state_name eq 'checkpoint') {
		$self->state_exit('reserved', 'checkpoint');
	}
	else {
		# Insert reload request data into the datbase
		if (!insert_reload_request($request_data)) {
			notify($ERRORS{'CRITICAL'}, 0, "failed to insert reload request into database for computer ID: $computer_id");
		}
		
		# Switch the request state to complete, leave the computer state as is, update log ending to EOR, exit
		$self->state_exit('complete', undef, 'EOR');
	}
} ## end sub reservation_successful

#//////////////////////////////////////////////////////////////////////////////

=head2 reservation_failed

 Parameters  : $message (optional)
 Returns     : exits
 Description : Handles final steps when a request in the image state fails. Sets
               the request and computer states to maintenance. Sends "processing
               delayed" message to image creator.

=cut

sub reservation_failed {
	my $self = shift;
	
	my $request_id                 = $self->data->get_request_id();
	my $request_state_name         = $self->data->get_request_state_name();
	my $request_laststate_name     = $self->data->get_request_laststate_name();
	my $user_email                 = $self->data->get_user_email();
	my $affiliation_helpaddress    = $self->data->get_user_affiliation_helpaddress();
	my $image_name                 = $self->data->get_image_name();
	my $computer_id                = $self->data->get_computer_id();
	my $computer_shortname         = $self->data->get_computer_short_name();
	my $sysadmin_mail_address      = $self->data->get_management_node_sysadmin_email(0);
	my $image_capture_type         = $self->data->get_image_capture_type();
	
	# Image process failed
	my $message = shift;
	if ($message) {
		notify($ERRORS{'CRITICAL'}, 0, "$image_name Image $image_capture_type Failed - $message");
	}
	else {
		notify($ERRORS{'CRITICAL'}, 0, "$image_name Image $image_capture_type Failed");
	}
	
	# Send a capture delayed message to the image owner
	my $user_message_key = 'image_creation_delayed';
	my ($user_subject, $user_message) = $self->get_user_message($user_message_key);
	if ($request_laststate_name ne "maintenance" && defined($user_subject) && defined($user_message)) {
		mail($user_email, $user_subject, $user_message, $affiliation_helpaddress);
	}
	
	# Send mail to administrators
	if ($sysadmin_mail_address) {
		# Get the administrator email subject and message
		# Pass a hash containing an IMAGE_CAPTURE_TYPE key - this gets replaced in the subject of the message
		my $admin_message_key = 'image_creation_failed';
		my ($admin_subject, $admin_message) = $self->get_admin_message($admin_message_key);
		if (defined($admin_subject) && defined($admin_message)) {
			mail($sysadmin_mail_address, $admin_subject, $admin_message, $affiliation_helpaddress);
		}
	}
	
	$self->state_exit('maintenance', 'maintenance');
} ## end sub reservation_failed

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : hash reference
 Description : Assembles the image-related 'vcld -setup' menu items.

=cut

sub setup_get_menu {
	return {
		'Image Management' => {
			'Capture a Base Image' => \&setup_capture_base_image,
		},
	};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_capture_base_image

 Parameters  : none
 Returns     : true
 Description : This subroutine is used when vcld is run in setup mode. It
               inserts the database entries necessary to capture a base image.
               Several questions are presented to the user via the command line.

=cut

sub setup_capture_base_image {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the management node id, needed to insert a reservation row later on
	my $management_node_id = $self->data->get_management_node_id();
	if (!$management_node_id) {
		print "ERROR: failed to determine the management node ID\n";
		return;
	}
	
	my ($request_id, $reservation_id) = 0;
	my $image_is_virtual = 0;
	
	print "\nTesting api call\n";
	if ($self->setup_test_rpc_xml(0)) {
		print "VCL API call successful\n\n";
	}
	
	# Is vcld service running
	if (!run_command('service vcld restart')) {
		print "ERROR: Unable to confirm vcld is running, Attempted to use service vcld restart\n";
		return;
	}
	
	
	# Get the user who the reservation and image will belong to
	my $user_id;
	my $username;
	while (!$user_id) {
		my $user_identifier = setup_get_input_string("Enter the VCL login name or ID of the user who will own the image:", 'admin');
		return if (!defined($user_identifier));
		my $user_info = get_user_info($user_identifier);
		if (!$user_info) {
			print "User was not found: $user_identifier\n";
		}
		else {
			$user_id = $user_info->{id};
			$username = $user_info->{unityid};
		}
	}
	print "\nUser who will own the image: $username (ID: $user_id)\n\n";
	
	# Determine the computer ID
	my $computer_id;
	my %computer_info;
	while (!$computer_id) {
		my $computer_identifier = setup_get_input_string("Enter the hostname or IP address of the computer to be captured:");
		return if (!defined($computer_identifier));
		
		# Search the computer table for a match
		my @computer_ids = get_computer_ids($computer_identifier);
		if (!@computer_ids) {
			print "No VCL computers were found with the name or IP address: $computer_identifier\n";
			next;
		}
		
		# Get information from the database for all of the computers found
		for my $computer_id (@computer_ids) {
			$computer_info{$computer_id} = get_computer_info($computer_id);
			if (!$computer_info{$computer_id}) {
				print "ERROR: unable to retrieve information for computer ID: $computer_id\n";
				return;
			}
		}
	
		if (scalar(@computer_ids) > 1) {
			print "Multiple VCL computers were found with the name or IP address: '$computer_identifier' (@computer_ids)\n\n";
			print "Choose a computer:\n";
			$computer_id = setup_get_hash_choice(\%computer_info, 'hostname');
			return if (!defined($computer_id));
		}
		else {
			$computer_id = (keys %computer_info)[0];
		}
		
	}
	
	my $computer_hostname = $computer_info{$computer_id}{hostname};
	my $computer_state_name = $computer_info{$computer_id}{state}{name};
	my $computer_provisioning_id = $computer_info{$computer_id}{provisioning}{id};
	my $computer_provisioning_module_name = $computer_info{$computer_id}{provisioning}{module}{name};
	my $computer_provisioning_module_pretty_name = $computer_info{$computer_id}{provisioning}{module}{prettyname};
	my $computer_provisioning_pretty_name = $computer_info{$computer_id}{provisioning}{prettyname};
	my $computer_provisioning_name = $computer_info{$computer_id}{provisioning}{name};
	my $computer_node_name = $computer_info{$computer_id}{SHORTNAME};
	
	my $osinstalltype_info = get_provisioning_osinstalltype_info($computer_provisioning_id);
	my @provisioning_osinstalltype_names = map { $osinstalltype_info->{$_}{name} } keys %$osinstalltype_info;
	
	print "\nComputer to be captured: $computer_hostname (ID: $computer_id)\n";
	print "Computer shortname: $computer_node_name\n";
	print "Computer State: $computer_state_name\n";
	print "Provisioning module: $computer_provisioning_module_pretty_name\n";
	print "OS install types: " . join(", ", sort @provisioning_osinstalltype_names) . "\n";
	
	my $vmhost_name;
	if ($computer_provisioning_module_name !~ /xcat/i) {
		$image_is_virtual = 1;
		#should have a vmhost assigned
		if ($computer_info{$computer_id}{vmhostid}) {
			$vmhost_name = $computer_info{$computer_id}{vmhost}{computer}{SHORTNAME};
			print "VM host name: $vmhost_name\n";
			print "VM host profile: $computer_info{$computer_id}{vmhost}{vmprofile}{profilename}\n";
			print "\n";
		}
		else {
			print "ERROR: Install type is vmware, $computer_node_name is NOT assigned to a vmhost\n";
			print "ERROR: Assign $computer_node_name to a vmhost before proceeding.\n";
			print "\n";
			return;
		}
	}
	
	print "Testing ssh access to $computer_hostname\n";
	
	# Node Checks
	# is the node up and accessible through ssh pki
	# If it is a vm, is it assigned to a vmhost
	# Try nmap to see if any of the ssh ports are open before attempting to run a test command
	my $port_22_status = nmap_port($computer_node_name, 22) ? "open" : "closed";
	my $port_24_status = nmap_port($computer_node_name, 24) ? "open" : "closed";
	if ($port_22_status ne 'open' && $port_24_status ne 'open') {
		print "Error: ssh port on $computer_node_name is NOT responding to SSH, ports 22 or 24 are both closed\n";
		return;
	}
	
	my ($exit_status, $output) = run_ssh_command({
		node => $computer_node_name,
		command => "echo \"testing ssh on $computer_node_name\"",
		max_attempts => 2,
		output_level => 0,
		timeout_seconds => 30,
	});
	
	# The exit status will be 0 if the command succeeded
	if (defined($output) && grep(/testing/, @$output)) {
		print "$computer_node_name is responding to SSH, port 22: $port_22_status, port 24: $port_24_status\n";
		print "\n";
	}
	else {
		print "ERROR: $computer_node_name is NOT responding to SSH, SSH command failed, port 22: $port_22_status, port 24: $port_24_status\n";
		print "Make sure you can login using ssh PKI on $computer_node_name before continuing\n"; 
		print "\n";
		return;
	}
	
	# Check if computer id is in an existing or failed imaging reservation
	my $computer_requests = get_request_by_computerid($computer_id);
	my %existing_requests_array_choices;
	if (keys(%$computer_requests)) {
		$existing_requests_array_choices{0}{"prettyname"} = "Delete all existing reservations for $computer_node_name";
		for my $competing_request_id (sort keys %$computer_requests) {
			my $competing_reservation_id = $computer_requests->{$competing_request_id}{data}->get_reservation_id();
			my $competing_imagerevision_id = $computer_requests->{$competing_request_id}{data}->get_imagerevision_id();
			my $competing_image_id = $computer_requests->{$competing_request_id}{data}->get_image_id();
			my $competing_prettyimage_name = $computer_requests->{$competing_request_id}{data}->get_image_prettyname();
			my $competing_image_name = $computer_requests->{$competing_request_id}{data}->get_image_name();
			my $competing_request_state = $computer_requests->{$competing_request_id}{data}->get_request_state_name();
			
			$existing_requests_array_choices{$competing_request_id}{"prettyname"} = $competing_prettyimage_name;
			$existing_requests_array_choices{$competing_request_id}{"name"} = $competing_image_name;
			$existing_requests_array_choices{$competing_request_id}{"image_id"} = $competing_image_id;
			$existing_requests_array_choices{$competing_request_id}{"image_revision_id"} = $competing_imagerevision_id;
			$existing_requests_array_choices{$competing_request_id}{"current_state"} = $competing_request_state;
			$existing_requests_array_choices{$competing_request_id}{"reservation_id"} = $competing_reservation_id;
		}
		
		my $num_computer_requests = keys(%$computer_requests);
		print "WARNING: Image capture reservation exists for $computer_node_name.\n"; 
		print "Either choose the image name to restart image capture for that request or choose none to delete the previous reservations:\n"; 
		
		my $chosen_request_id = setup_get_hash_choice(\%existing_requests_array_choices, 'prettyname');
		return if (!defined($chosen_request_id));
		my $chosen_prettyname = $existing_requests_array_choices{$chosen_request_id}{prettyname};
		print "\nSelected reservation: $chosen_request_id $chosen_prettyname\n\n";
		
		# if 0 selected, delete all reservations related to $computer_node_name
		# Set $computer_node_name to available, proceed with questions
		my $epoch_time = convert_to_epoch_seconds;
		if ($chosen_request_id == 0) {
			delete $existing_requests_array_choices{0};
			
			foreach my $request_id_del (sort keys %existing_requests_array_choices) {
				my $del_reservation_id = $existing_requests_array_choices{$request_id_del}{reservation_id};
				my $del_image_id = $existing_requests_array_choices{$request_id_del}{image_id};
				my $del_imagerevision_id = $existing_requests_array_choices{$request_id_del}{image_revision_id};
				my $del_image_name = $existing_requests_array_choices{$request_id_del}{name};
				print "del_image_name= $del_image_name\n";
				my $new_image_name = $del_image_name . $epoch_time;
				my $new_prettyimage_name = $existing_requests_array_choices{$request_id_del}{prettyname} . $epoch_time;
				
				if (reservation_being_processed($del_reservation_id)) {
					print "WARNING: The selected reservation is currently being processed. You must wait until it has completed.\n";
					print "Reservation id: $del_reservation_id\n";
					print "\n";
					next;
				}
				
				if (delete_request($request_id_del)) {
					print "Removed reservation id $request_id_del for $del_image_name\n";
					if (update_image_name($del_image_id, $del_imagerevision_id, $new_image_name, $new_prettyimage_name)) {
					}
					if (update_computer_state($computer_id, "available")) {
						print "Set $computer_node_name to available state\n";
					}
				}
			}
		}
		# Elseif a request id is choosen. set $computer_node_name to available, test ssh access, restart image capture
		if ($chosen_request_id) {
			$request_id = $chosen_request_id;
			$reservation_id = $existing_requests_array_choices{$chosen_request_id}{reservation_id};
			if (reservation_being_processed($chosen_request_id)) {
				print "WARNING: The selected reservation is currently being processed. You must wait until it has completed.\n";
				print "Reservation id: $chosen_request_id\n";
				print "\n";
				my @yes_no_choices = (
					'Yes',
					'No',
				);
				
				print "Monitor vcld.log for completion?:\n";
				my $monitor_choice_index = setup_get_array_choice(@yes_no_choices);
				last if (!defined($monitor_choice_index));
				my $monitor_choice = $yes_no_choices[$monitor_choice_index];
				if ($monitor_choice =~ /yes/i) {
					print ".\n";	
					goto MONITOR_LOG_OUTPUT;
				}
				else {
					return;
				}
			}
			if (update_computer_state($computer_id, "available")) {
				print "Set $computer_node_name to available state\n";
			}
			$chosen_prettyname = $existing_requests_array_choices{$chosen_request_id}{prettyname};
			print "Restarting image capture for: \nRequest id= $chosen_request_id \nImage Name: $chosen_prettyname \nNode Name: $computer_node_name\n";
			
			if (update_request_state($chosen_request_id, "image", "image", 1)) {
				print "Set request_id= $chosen_request_id to image state\n\n";
				print "Starting monitor process:\n\n";
				
				goto MONITOR_LOG_OUTPUT;
			}
			else {
				print "ERROR: failed to update request state for $chosen_request_id, state_name= image, last_state: image\n";
			}
		}
	}
	
	# Make sure the computer state is valid
	if ($computer_state_name =~ /(maintenance|deleted)/i) {
		print "ERROR: state of $computer_node_name is $computer_state_name\n";
		print "\n";
		return;
	}
	
	# Get the OS table contents from the database
	my $os_info = get_os_info();
	if (!$os_info) {
		print "ERROR: failed to retrieve OS info from the database\n";
		return;
	}
	
	# Loop through the OS table info
	OS_ID: for my $os_id (keys %$os_info) {
		my $osinstalltype_name = $os_info->{$os_id}{installtype};
		
		# Remove keys where the name begins with esx - deprecated OS type
		if ($osinstalltype_name =~ /^vmwareesx/i) {
			delete $os_info->{$os_id};
			next;
		}
		
		# Remove keys which don't match the selected computer type
		for my $provisioning_osinstalltype_name (@provisioning_osinstalltype_names) {
			if ($provisioning_osinstalltype_name eq $osinstalltype_name) {
				next OS_ID;
			}
		}
		
		delete $os_info->{$os_id};
	}
	
	print "Select the OS to be captured (install type: " . join(', ', sort @provisioning_osinstalltype_names) . "):\n";
	my $os_id = setup_get_hash_choice($os_info, 'prettyname');
	return if (!defined($os_id));
	my $os_prettyname = $os_info->{$os_id}{prettyname};
	my $os_module_perl_package = $os_info->{$os_id}{module}{perlpackage};
	my $os_type = $os_info->{$os_id}{type};
	print "\nSelected OS: $os_prettyname\n\n";
	
	my @architecture_choices = (
		'x86',
		'x86_64',
	);
	print "Image architecture:\n";
	my $architecture_choice_index = setup_get_array_choice(@architecture_choices);
	last if (!defined($architecture_choice_index));
	my $architecture_choice = $architecture_choices[$architecture_choice_index];
	print "\nImage architecture: $architecture_choice\n\n";
	
	# If Windows, ask if Sysprep should be used
	my $use_sysprep = 1;
	if ($os_type =~ /windows/i) {
		my @yes_no_choices = (
			'Yes',
			'No',
		);
		
		print "Use Sysprep:\n";
		my $sysprep_choice_index = setup_get_array_choice(@yes_no_choices);
		last if (!defined($sysprep_choice_index));
		my $use_sysprep_choice = $yes_no_choices[$sysprep_choice_index];
		print "\nUse Sysprep: $use_sysprep_choice\n\n";
		
		if ($use_sysprep_choice =~ /no/i) {
			$use_sysprep = 0;
		}
	}
	
	my $image_prettyname;
	while (!$image_prettyname) {
		$image_prettyname = setup_get_input_string("Enter the name of the image to be captured:");
		return if (!defined($image_prettyname));
		#if ($image_prettyname =~ //) {
		#	print "Image name is not valid: $image_prettyname\n";
		#	$image_prettyname = 0;
		#}
	}
	
	my $image_name = $image_prettyname;
	$image_name =~ s/[\s\W]//g;
	$image_name = $os_info->{$os_id}{name} . "-$image_name-v0";
	
	my $insert_imagemeta_statement = <<EOF;
INSERT INTO imagemeta
(sysprep)
VALUES
('$use_sysprep')
EOF
	
	my $imagemeta_id = database_execute($insert_imagemeta_statement);
	if (!defined($imagemeta_id)) {
		print "ERROR: failed to insert into imagemeta table.\n";
		return;
	}
	
	
	my $insert_image_statement = <<EOF;
INSERT INTO image
(name, prettyname, ownerid, platformid, OSid, imagemetaid, deleted, lastupdate, size, architecture, basedoffrevisionid)
VALUES
(
'$image_name',
'$image_prettyname',
'$user_id',
'1',
$os_id,
$imagemeta_id,
'1',
NOW(),
'1',
'$architecture_choice',
(SELECT id FROM imagerevision WHERE imagename = 'noimage')
)
EOF
	
	my $image_id = database_execute($insert_image_statement);
	if (!defined($image_id)) {
		print "ERROR: failed to insert into image table. Please choose another name.\n";
		return;
	}
	
	# Add the newly inserted image ID to the image name
	$image_name =~ s/-v0$/$image_id-v0/;
	
	# Upadate the name in the image table
	my $update_image_statement = <<EOF;
UPDATE image
SET name = '$image_name'
WHERE
id = $image_id
EOF
	if (!database_execute($update_image_statement)) {
		print "ERROR: failed to update the image table with the correct image name: $image_name\n";
		return;
	}
	
	
	my $insert_imagerevision_statement = <<EOF;
INSERT INTO imagerevision
(imageid, revision, userid, datecreated, deleted, production, imagename)
VALUES
($image_id, '0', '$user_id', NOW(), '1', '1', '$image_name')
EOF

	my $imagerevision_id = database_execute($insert_imagerevision_statement);
	if (!defined($imagerevision_id)) {
		print "ERROR: failed to insert into imagerevision table\n";
		return;
	}
	
	my $insert_resource_statement = <<EOF;
INSERT INTO resource
(resourcetypeid, subid)
VALUES ('13', '$image_id')
EOF
	
	my $resource_id = database_execute($insert_resource_statement);
	if (!defined($resource_id)) {
		print "ERROR: failed to insert into resource table\n";
		return;
	}
	
	# Add image resource_id to users' new image group
	if (!add_imageid_to_newimages($user_id, $resource_id, $image_is_virtual)) {
		print "\nWARNING: Failed to add image to user's new images group\n";
		print "You might need to add manually to the new images or all images image groups\n";
		print "Continuing to with image capture\n\n";
	}
	
	print "\nAdded new image to database: '$image_prettyname'\n";
	print "   image.name: $image_name\n";
	print "   image.id: $image_id\n";
	print "   imagerevision.id: $imagerevision_id\n";
	print "   imagemeta.id: $imagemeta_id\n";
	print "   resource.id: $resource_id\n\n";
	
	
	($request_id, $reservation_id) = insert_request($management_node_id, 'image', 'image', $username, $computer_id, $image_id, $imagerevision_id, 0, 60);
	if (!defined($request_id) || !defined($reservation_id)) {
		print "ERROR: failed to insert new imaging request\n";
		return;
	}
	
	my $process_regex = get_reservation_vcld_process_name_regex($reservation_id) || $reservation_id;
	$process_regex =~ s/^\w+\s//;
	
	my $message = <<EOF;
Inserted imaging request to the database:
request ID: $request_id
reservation ID: $reservation_id

This process will now display the contents of the vcld.log file if the vcld
daemon is running. If you do not see many lines of additional output, exit this
process, start the vcld daemon, and monitor the image capture process by running
the command:
tail -f $LOGFILE | grep -P '$process_regex'

EOF
	
	print '-' x 76 . "\n";
	print "$message";
	print '-' x 76 . "\n";
	
	MONITOR_LOG_OUTPUT:
	# Pipe the command output to a file handle
	# The open function returns the pid of the process
	if (open(COMMAND, "tail -f $LOGFILE 2>&1 |")) {
		# Capture the output of the command
		while (my $output = <COMMAND>) {
			if ($output =~ /$reservation_id/) {
				print $output;
				if ($output =~ /complete/i) {
					last;
				}
			}
		}
	}
	
	exit;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
