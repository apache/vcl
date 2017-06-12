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

VCL::Module - VCL base module

=head1 SYNOPSIS

In a derived module:

 use base qw(VCL::Module);

 sub initialize {
    my $self = shift;
    my $image_id = $self->data->get_image_id();
    <perform module initialization tasks...>
    return 1;
 }

=head1 DESCRIPTION

C<VCL::Module> is the base class for the modularized VCL architecture. All VCL
modules should inherit from C<VCL::Module> or from another class which inherits
from C<VCL::Module> (multilevel inheritance).

To inherit directly from C<VCL::Module>:

C<use base qw(VCL::Module);>

To inherit from a class which ultimately inherits from C<VCL::Module>:

C<use base qw(VCL::Module::OS::Windows);>

C<VCL::Module> provides a common constructor which all derived modules should
use. Derived modules should not implement their own constructors. The
constructor provides derived modules the ability to implement an C<initialize()>
subroutine which will be automatically called when a derived module object is
created. This method should be used if a module needs to perform any functions
to initialize a newly created module object.

Modules derived from C<VCL::Module> have access to the common backend
reservation data API to access and set the data for the reservation being
processed via C<< $self->data >>. (C<$self> being a reference to a derived
module object)

=cut

###############################################################################
package VCL::Module;

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

no warnings 'redefine';

use English '-no_match_vars';
use Digest::SHA1 qw(sha1_hex);

use VCL::utils;
use VCL::DataStructure;

###############################################################################

=head1 CONSTRUCTOR

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 new

 Parameters  : Hash reference - hash must contain a key called data_structure.
               The value of this key must be a reference to a VCL::DataStructure
               object.
 Returns     : Success - new object which inherits from VCL::Module
               Failure - undefined
 Description : Constructor for VCL modules. All VCL modules should use this
               constructor. Objects created using this constructor have a base
               class of VCL::Module. A module may have other intermediate
               classes it is derived from if multilevel inheritance is used.
               
               This constructor must be passed a reference to a previously
               created VCL::DataStructure object. Derived objects will have
               access to the data() object method: $self->data->get...()
               
               During object creation, this constructor will attempt to call an
               initialize() subroutine defined in a child class. This allows
               tasks to be automatically performed during object creation.
               Implementing an initialize() subroutine is optional.
               
               Any arguments passed to new() will be passed unchanged to
               initialize().
               
               Example:
               use VCL::Module::TestModule;
               my $test_module = new VCL::Module::TestModule({data_structure => $self->data});

=cut

sub new {
	my $class = shift;
	my $args  = shift;
	
	# Create a variable to store the newly created class object
	my $self;
	
	# Make sure a hash reference argument was passed
	if (!$args) {
		my $data_structure = new VCL::DataStructure();
		if ($data_structure) {
			$args->{data_structure} = $data_structure;
		}
		else {
			notify($ERRORS{'CRITICAL'}, 0, "no argument was passed and default DataStructure object could not be created");
			return;
		}
	}
	elsif (!ref($args) || ref($args) ne 'HASH') {
		notify($ERRORS{'CRITICAL'}, 0, "argument passed is not a hash reference");
		return;
	}
	
	# Make sure the data structure was passed as an argument called 'data_structure'
	if (!defined $args->{data_structure}) {
		notify($ERRORS{'CRITICAL'}, 0, "required 'data_structure' argument was not passed");
		return;
	}

	# Make sure the 'data_structure' argument contains a VCL::DataStructure object
	if (ref $args->{data_structure} ne 'VCL::DataStructure') {
		notify($ERRORS{'CRITICAL'}, 0, "'data_structure' argument passed is not a reference to a VCL::DataStructure object");
		return;
	}
	
	# Add the DataStructure reference to the class object
	$self->{data} = $args->{data_structure};
	
	for my $arg_key (keys %$args) {
		next if ($arg_key eq 'data_structure');
		
		$self->{$arg_key} = $args->{$arg_key};
		#notify($ERRORS{'DEBUG'}, 0, "set '$arg_key' key for $class object from arguments");
	}
	
	# Bless the object as the class which new was called with
	bless $self, $class;
	
	# Get the memory address of this newly created object - useful for debugging object creation problems
	my $address = sprintf('%x', $self);
	
	my $type = ref($self);
	
	# Display a message based on the type of object created
	if ($self->isa('VCL::Module::State')) {
		my $request_state_name = $self->data->get_request_state_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, "$type object created for state $request_state_name, address: $address");
	}
	elsif ($self->isa('VCL::Module::OS') && !$self->isa('VCL::Module::OS::Linux::ManagementNode')) {
		my $image_name = $self->data->get_image_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, "$type object created for image $image_name, address: $address");
	}
	elsif ($self->isa('VCL::Module::Provisioning')) {
		my $computer_name = $self->data->get_computer_short_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, "$type object created for computer $computer_name, address: $address");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "$type object created, address: $address");
	}
	
	# Create a management node OS object
	# Check to make sure the object currently being created is not a MN OS object to avoid endless loop
	if (!$self->isa('VCL::Module::OS::Linux::ManagementNode') && !$self->isa('VCL::Module::State')) {
		my $mn_os;
		# Check if the mn_os argument was provided
		if ($args->{mn_os}) {
			$mn_os = $args->{mn_os};
		}
		elsif ($self->mn_os(0)) {
			$mn_os = $self->mn_os();
		}
		else {
			$mn_os = $self->create_mn_os_object();
		}
		
		if ($mn_os) {
			$self->set_mn_os($mn_os);
			$self->data->set_mn_os($mn_os);
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "failed to create management node OS object");
			return;
		}
	}
	
	# Check if not running in setup mode and if initialize() subroutine is defined for this module
	if (!$SETUP_MODE || $self->isa('VCL::Module::OS::Linux::ManagementNode')) {
		if ($self->can("initialize")) {
			# Call the initialize() subroutine, if it returns 0, return 0
			# If it doesn't return 0, return the object reference
			return if (!$self->initialize($args));
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "initialize not called for $type object ($address) because \$SETUP_MODE is true");
	}

	return $self;
} ## end sub new

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 create_datastructure_object

 Parameters  : $arguments
 Returns     : VCL::DataStructure object
 Description : Creates a DataStructure object. The arguments are the same as
               those passed to the DataStructure constructor.

=cut

sub create_datastructure_object {
	my $arguments = shift;
	
	if (my $type = ref($arguments)) {
		if ($type =~ /VCL::/) {
			# First argument is an object reference, assume this was called as an object method
			$arguments = shift;
		}
		elsif ($type ne 'HASH') {
			# First argument is not a hash reference
			notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module object method and first argument is a $type reference");
			return;
		}
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "no arguments specified, creating default DataStructure object");
		$arguments = {};
	}
	
	my $data;
	eval {
		$data = new VCL::DataStructure($arguments);
	};
	
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object, arguments:\n" . format_data($arguments) . "\nerror:\n" . $EVAL_ERROR);
		return;
	}
	elsif (!$data) {
		notify($ERRORS{'WARNING'}, 0, "failed to create DataStructure object, arguments:\n" . format_data($arguments));
		return;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "created DataStructure object, arguments:\n" . format_data($arguments));
		return $data;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_object

 Parameters  : $perl_package, $data_structure_arguments (optional), $object_argument_hashref (optional)
 Returns     : VCL::Module object reference
 Description : This is a general constructor to create VCL::Module objects. It
               contains the code to call 'use $perl_package', instantiate an
               object, and catch errors.

=cut

sub create_object {
	my $argument = shift;
	
	# Check if called as an object method
	my $self;
	if ($argument && ref($argument)) {
		$self = $argument;
		$argument = shift;
	}
	
	if (!$argument) {
		notify($ERRORS{'WARNING'}, 0, "Perl package path argument was not specified");
		return;
	}
	elsif (my $type = ref($argument)) {
		notify($ERRORS{'WARNING'}, 0, "first argument must be the Perl package path scalar, not a $type reference");
		return;
	}
	
	my $perl_package = $argument;
	
	my $data;
	my $data_structure_arguments = shift;
	if ($data_structure_arguments) {
		if (ref($data_structure_arguments) && ref($data_structure_arguments) =~ /DataStructure/) {
			notify($ERRORS{'DEBUG'}, 0, "DataStructure object argument will be passed to the new $perl_package object");
			$data = $data_structure_arguments;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "new DataStructure object will be created for the $perl_package object, data structure arguments passed:\n" . format_data($data_structure_arguments));
			$data = create_datastructure_object($data_structure_arguments);
		}
	}
	elsif (!$self) {
		notify($ERRORS{'DEBUG'}, 0, "new DataStructure object will be created for the $perl_package object, data structure arguments not passed and not called as an object reference");
		$data = create_datastructure_object();
	}
	elsif ($self) {
		notify($ERRORS{'DEBUG'}, 0, "existing DataStructure object will be passed to the new $perl_package object");
		$data = $self->data;
	}
	
	my $object_argument_hashref = shift;
	if ($object_argument_hashref) {
		my $type = ref($object_argument_hashref);
		if (!$type) {
			notify($ERRORS{'WARNING'}, 0, "3rd argument is not a reference, it must be a hash reference: $object_argument_hashref");
			return;
		}
		elsif ($type ne 'HASH') {
			notify($ERRORS{'WARNING'}, 0, "3rd argument is a $type reference, it must be a hash reference");
			return;
		}
	}
	$object_argument_hashref->{data_structure} = $data;

	# Attempt to load the module
	eval "use $perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$perl_package module could not be loaded, error:\n" . $EVAL_ERROR);
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "$perl_package module loaded");
	
	# Attempt to create the object
	my $object;
	eval {
		$object = ($perl_package)->new($object_argument_hashref)
	};
	
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "failed to create $perl_package object, error: $EVAL_ERROR");
		return;
	}
	elsif (!$object) {
		notify($ERRORS{'WARNING'}, 0, "failed to create $perl_package object");
		return;
	}
	else {
		my $address = sprintf('%x', $object);
		notify($ERRORS{'DEBUG'}, 0, "$perl_package object created, address: $address");
		return $object;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_os_object

 Parameters  : none
 Returns     : boolean
 Description : Creates an OS object if one has not already been created for the
               calling object.

=cut

sub create_os_object {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Make sure calling object isn't an OS module to avoid an infinite loop
	if ($self->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing OS module");
		return;
	}
	
	my $os_perl_package_argument = shift;
	my $os_perl_package;
	
	if ($os_perl_package_argument) {
		$os_perl_package = $os_perl_package_argument;
	}
	else {
		# Get the Perl package for the OS
		$os_perl_package = $self->data->get_image_os_module_perl_package();
	}
	
	if (!$os_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "OS object could not be created, OS module Perl package could not be retrieved");
		return;
	}
	
	# Check if an OS object has already been stored in the calling object
	# Return this object if a Perl package argument wasn't passed
	if (!$os_perl_package_argument && $self->{os}) {
		my $os_address = sprintf('%x', $self->{os});
		my $os_image_name = $self->{os}->data->get_image_name();
		notify($ERRORS{'DEBUG'}, 0, "OS object has already been created for $os_image_name, address: $os_address, returning 1");
		return 1;
	}
	
	# Attempt to load the OS module
	eval "use $os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$os_perl_package module could not be loaded, error:\n" . $EVAL_ERROR);
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$os_perl_package module loaded");
	
	# Attempt to create the object, pass it the mn_os object if it has already been created
	my $os;
	if (my $mn_os = $self->mn_os(0)) {
		$os = ($os_perl_package)->new({data_structure => $self->data, mn_os => $mn_os});
	}
	else {
		$os = ($os_perl_package)->new({data_structure => $self->data})
	}
	
	if ($os) {
		my $os_address = sprintf('%x', $os);
		notify($ERRORS{'DEBUG'}, 0, "$os_perl_package OS object created, address: $os_address");
		return $os;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create OS object");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_current_os_object

 Parameters  : $computer_identifier (optional)
 Returns     : string
 Description : Attempts to determine the Perl package which should be used to
               control the computer.

=cut

sub create_current_os_object {
	my ($self, $computer_identifier, $suppress_warning) = @_;
	
	my $os_perl_package = VCL::Module::OS::get_os_perl_package(@_);
	if (!$os_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "failed to create object for OS currently loaded on computer, correct Perl package path could not be determined") unless $suppress_warning;
		return;
	}
	
	if (ref($self) && ref($self) eq $os_perl_package) {
		notify($ERRORS{'DEBUG'}, 0, "returning object used to call this subroutine becuase it is the correct module type: " . ref($self));
		return $self;
	}
	
	return $self->create_os_object($os_perl_package);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_mn_os_object

 Parameters  : none
 Returns     : boolean
 Description : Creates a management node OS object if one has not already been
               created for the calling object.

=cut

sub create_mn_os_object {
	my $self = shift;
	
	my $datastructure_arguments = {
		'image_identifier' => 'noimage'
	};
	
	# Check if called as an object reference
	if ($self && ref($self) =~ /VCL/) {
		# Add the reservation ID to the DataStructure arguments
		# Otherwise, get_reservation_id won't be available
		my $reservation_id = $self->data->get_reservation_id();
		$datastructure_arguments->{reservation_id} = $reservation_id;
	}
	
	# Create a DataStructure object containing computer data for the management node
	my $mn_data;
	eval {
		$mn_data = new VCL::DataStructure($datastructure_arguments);
	};
	
	# Attempt to load the OS module
	my $mn_os_perl_package = 'VCL::Module::OS::Linux::ManagementNode';
	eval "use $mn_os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$mn_os_perl_package module could not be loaded, error:\n" . $EVAL_ERROR);
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$mn_os_perl_package module loaded");
	
	# Attempt to create the object
	if (my $mn_os = ($mn_os_perl_package)->new({data_structure => $mn_data})) {
		my $address = sprintf('%x', $mn_os);
		notify($ERRORS{'DEBUG'}, 0, "$mn_os_perl_package OS object created, address: $address");
		
		# Allow $mn_os->data to access $mn_os
		$mn_data->set_mn_os($mn_os);
		
		return $mn_os;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create management node OS object");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_vmhost_os_object

 Parameters  : $vmhost_identifier (optional)
 Returns     : boolean
 Description : Creates an OS object for the VM host.

=cut

sub create_vmhost_os_object {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $vmhost_identifier = shift;
	
	if (!$vmhost_identifier) {
		# Check if an OS object has already been stored in the calling object
		if (my $vmhost_os = $self->vmhost_os(0)) {
			my $address = sprintf('%x', $vmhost_os);
			notify($ERRORS{'DEBUG'}, 0, "returning existing VM host OS object ($address)");
			return $vmhost_os;
		}
	}
	
	# Make sure calling object isn't an OS module to avoid an infinite loop
	if ($self->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing OS module: " . ref($self));
		return;
	}
	
	my $request_data = $self->data->get_request_data();
	my $reservation_id = $self->data->get_reservation_id();
	
	my $vmhost_computer_id;
	my $vmhost_hostname;
	my $vmhost_profile_image_id;
	if ($vmhost_identifier) {
		my $vmhost_info = get_vmhost_info($vmhost_identifier);
		if (!$vmhost_info) {
			notify($ERRORS{'WARNING'}, 0, "unable to create VM host OS object for host specified by argument: $vmhost_identifier, VM host info could not be retrieved");
			return;
		}
		
		$vmhost_computer_id = $vmhost_info->{computerid};
		if (!$vmhost_computer_id) {
			notify($ERRORS{'WARNING'}, 0, "unable to create VM host OS object for host specified by argument: $vmhost_identifier, VM host computer ID could not be determined from VM host info:\n" . format_data($vmhost_info));
			return;
		}
		
		$vmhost_hostname = $vmhost_info->{computer}{hostname};
		if (!$vmhost_hostname) {
			notify($ERRORS{'WARNING'}, 0, "unable to create VM host OS object for host specified by argument: $vmhost_identifier, VM host computer hostname could not be determined from VM host info:\n" . format_data($vmhost_info));
			return;
		}
		
		$vmhost_profile_image_id = $vmhost_info->{vmprofile}{imageid};
		if (!$vmhost_profile_image_id) {
			notify($ERRORS{'WARNING'}, 0, "unable to create VM host OS object for host specified by argument: $vmhost_identifier, VM host profile image ID could not be determined from VM host info:\n" . format_data($vmhost_info));
			return;
		}
	}
	else {
		# Argument was not supplied, use reservation data
		$vmhost_computer_id = $self->data->get_vmhost_computer_id();
		$vmhost_hostname = $self->data->get_vmhost_hostname();
		$vmhost_profile_image_id = $self->data->get_vmhost_profile_image_id();
		if (!$vmhost_computer_id || !$vmhost_hostname || !defined($vmhost_profile_image_id)) {
			notify($ERRORS{'WARNING'}, 0, "unable to create VM host OS object, VM host computer ID, hostname, and profile image ID could not be determined from reservation data");
			return;
		}
	}
	
	# Create a DataStructure object containing computer data for the VM host
	my $vmhost_data;
	eval {
		$vmhost_data = new VCL::DataStructure({
			request_data => $request_data,
			reservation_id => $reservation_id,
			computer_identifier => $vmhost_computer_id,
			image_identifier => $vmhost_profile_image_id
			}
		);
	};
	
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure object for VM host, error: $EVAL_ERROR");
		return;
	}
	elsif (!$vmhost_data) {
		notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure object for VM host, DataStructure object is not defined");
		return;
	}
	
	# Get the VM host OS module Perl package name
	my $vmhost_os_perl_package = $vmhost_data->get_image_os_module_perl_package();
	if (!$vmhost_os_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "unable to create DataStructure or OS object for VM host, failed to retrieve VM host image OS module Perl package name");
		return;
	}
	
	# Do not try to load the UnixLab module for VM hosts -- most likely not the intended OS module
	# TODO: add additional checks here, VM host image may be something like XP
	if ($vmhost_os_perl_package =~ /(UnixLab|2003|XP|Vista)/i || $vmhost_os_perl_package =~ /^VCL::Module::OS$/) {
		my $vmhost_os_perl_package_override = 'VCL::Module::OS::Linux';
		notify($ERRORS{'OK'}, 0, "VM host OS image Perl package is $vmhost_os_perl_package, most likely will not work correctly, changing to Linux");
		$vmhost_os_perl_package = $vmhost_os_perl_package_override;
	}
	
	# Load the VM host OS module
	notify($ERRORS{'DEBUG'}, 0, "attempting to load VM host OS module: $vmhost_os_perl_package (image: $vmhost_profile_image_id)");
	eval "use $vmhost_os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "VM host OS module could NOT be loaded: $vmhost_os_perl_package, error: $EVAL_ERROR");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "VM host OS module loaded: $vmhost_os_perl_package");
	
	# Attempt to create the object
	my $vmhost_os;
	if (my $mn_os = $self->mn_os(0)) {
		$vmhost_os = ($vmhost_os_perl_package)->new({data_structure => $vmhost_data, mn_os => $mn_os});
	}
	else {
		$vmhost_os = ($vmhost_os_perl_package)->new({data_structure => $vmhost_data})
	}
	
	if ($vmhost_os) {
		my $address = sprintf('%x', $vmhost_os);
		notify($ERRORS{'DEBUG'}, 0, "$vmhost_os_perl_package OS object created, address: $address");
		return $vmhost_os;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create VM host OS object");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_nathost_os_object

 Parameters  : none
 Returns     : VCL::Module::OS object reference
 Description : Creates an OS module object to control the reservation computer's
               NAT host.

=cut

sub create_nathost_os_object {
my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if an OS object has already been stored in the calling object
	if (my $nathost_os = $self->nathost_os(0)) {
		return $nathost_os;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "attempting to create NAT host OS object");
	
	# Make sure calling object isn't an OS module to avoid an infinite loop
	if ($self->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing OS module: " . ref($self));
		return;
	}
	
	my $request_data = $self->data->get_request_data();
	my $reservation_id = $self->data->get_reservation_id();
	
	my $nathost_id = $self->data->get_nathost_id();
	my $nathost_hostname = $self->data->get_nathost_hostname();
	my $nathost_public_ip_address = $self->data->get_nathost_public_ip_address(0);
	my $nathost_internal_ip_address = $self->data->get_nathost_internal_ip_address(0);
	my $nathost_resource_subid = $self->data->get_nathost_resource_subid();
	my $nathost_resource_type = $self->data->get_nathost_resource_type();
	
	# Make sure computer is mapped to a NAT host and all the required variables are set
	if (!defined($nathost_id)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object, NAT host ID is not defined");
		return;
	}
	elsif (!defined($nathost_hostname)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object, NAT host hostname is not defined");
		return;
	}
	elsif (!defined($nathost_public_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object, NAT host public IP address is not defined");
		return;
	}
	elsif (!defined($nathost_internal_ip_address)) {
		notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object, NAT host internal IP address is not defined");
		return;
	}
	
	my $nathost_os;
	
	if ($nathost_resource_type eq 'managementnode') {
		notify($ERRORS{'DEBUG'}, 0, "NAT host resource type is $nathost_resource_type, returning management node OS object to control $nathost_hostname");
		$nathost_os = $self->mn_os();
	}
	elsif ($nathost_resource_type eq 'computer') {
		# Get the computer info in order to determine the OS module to use
		my $computer_info = get_computer_info($nathost_resource_subid);
		if (!$computer_info) {
			notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object, failed to retrieve info for computer ID: $nathost_resource_subid, NAT host info:\n" . format_data($self->data->get_nathost_info()));
		}
		my $computer_os_package = $computer_info->{currentimagerevision}{image}{OS}{module}{perlpackage};
		
		# Make sure the OS module for NAT host computer.currentimagerevision is Linux and not UnixLab
		# UnixLab.pm overrides the firewall initialization step and will have a generic VCL::Module::OS::Linux::firewall object which doesn't implement nat_configure_reservation
		if ($computer_os_package !~ /VCL::Module::OS::Linux/ || $computer_os_package =~ /UnixLab/) {
			notify($ERRORS{'DEBUG'}, 0, "NAT host resource type is $nathost_resource_type, OS module that controls $nathost_hostname\'s current computer.currentimagerevision value is $computer_os_package, overriding to VCL::Module::OS::Linux");
			$computer_os_package = 'VCL::Module::OS::Linux';
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "NAT host resource type is $nathost_resource_type, creating $computer_os_package OS object to control $nathost_hostname based its current computer.currentimagerevision value");
		}
		
		$nathost_os = $self->create_object($computer_os_package, {
			#request_data => $request_data,
			reservation_id => $reservation_id,
			computer_identifier => $nathost_resource_subid
		});
		if (!$nathost_os) {
			notify($ERRORS{'WARNING'}, 0, "failed to create NAT host OS object to control $nathost_hostname");
			return;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to create NAT host OS object to control $nathost_hostname, NAT host resource type is not supported: $nathost_resource_type, NAT host info:\n" . format_data($self->data->get_nathost_info()));
		return;
	}
	
	# All of the following should always be configured
	my $nathost_os_type = ref($nathost_os);
	if (!$nathost_os->firewall()) {
		notify($ERRORS{'WARNING'}, 0, "created $nathost_os_type NAT host OS object but firewall object is not available");
		return;
	}
	
	my $firewall_type = ref($nathost_os->firewall());
	if (!$nathost_os->firewall->can('nat_configure_host')) {
		notify($ERRORS{'WARNING'}, 0, "created $nathost_os_type NAT host OS object but NAT host OS's $firewall_type firewall object does NOT implement a 'nat_configure_host' method");
		return;
	}
	elsif (!$nathost_os->firewall->can('nat_configure_reservation')) {
		notify($ERRORS{'WARNING'}, 0, "created $nathost_os_type NAT host OS object but NAT host OS's $firewall_type firewall object does NOT implement a 'nat_configure_reservation' method");
		return;
	}
	
	# Set NAT host DataStructure values so they can be accessed from $self->nathost_os and $self->nathost_os->firewall
	$nathost_os->data->set_nathost_public_ip_address($nathost_public_ip_address);
	$nathost_os->data->set_nathost_internal_ip_address($nathost_internal_ip_address);
	
	return $nathost_os
}

#//////////////////////////////////////////////////////////////////////////////

=head2 create_provisioning_object

 Parameters  : $provisioning_perl_package (optional)
 Returns     : VCL::Module::Provisioning object reference
 Description : Creates an provisioning module object if one has not already been
               created for the calling object.

=cut

sub create_provisioning_object {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Make sure calling object isn't a provisioning module to avoid an infinite loop
	if ($self->isa('VCL::Module::Provisioning')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing provisioning module");
		return;
	}
	
	# Check if an OS object has already been stored in the calling object
	if ($self->{provisioner}) {
		my $address = sprintf('%x', $self->{provisioner});
		my $provisioner_computer_name = $self->{provisioner}->data->get_computer_short_name();
		notify($ERRORS{'DEBUG'}, 0, "provisioning object has already been created, address: $address, returning 1");
		return 1;
	}
	
	# Get the Perl package for the provisioning module
	my $provisioning_perl_package = shift || $self->data->get_computer_provisioning_module_perl_package();
	if (!$provisioning_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "provisioning object could not be created, provisioning module Perl package could not be retrieved");
		return;
	}
	
	# Attempt to load the computer provisioning module
	eval "use $provisioning_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$provisioning_perl_package module could not be loaded, error:\n" . $EVAL_ERROR);
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$provisioning_perl_package module loaded");
	
	# Attempt to provisioner the object, pass it the mn_os object if it has already been created
	my $constructor_arguments = {};
	$constructor_arguments->{data_structure} = $self->data();
	$constructor_arguments->{os} = $self->os(0) if $self->os(0);
	$constructor_arguments->{mn_os} = $self->mn_os(0) if $self->mn_os(0);
	$constructor_arguments->{vmhost_os} = $self->vmhost_os(0) if $self->vmhost_os(0);
	my $provisioner = ($provisioning_perl_package)->new($constructor_arguments);
	
	if ($provisioner) {
		my $provisioner_address = sprintf('%x', $provisioner);
		my $provisioner_computer_name = $provisioner->data->get_computer_short_name();
		notify($ERRORS{'DEBUG'}, 0, "$provisioning_perl_package provisioning object created for $provisioner_computer_name, address: $provisioner_address");
		return $provisioner;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "provisioning object could not be created, returning 0");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 data

 Parameters  : $display_warning (optional)
 Returns     : Reference to the DataStructure object
 Description : This subroutine allows VCL module objects to retrieve data using
               the object's DataStructure object as follows:
               my $image_id = $self->data->get_image_id();

=cut

sub data {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$self->{data}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return DataStructure object, \$self->{data} is not set");
		}
		return;
	}
	else {
		return $self->{data};
	}
} ## end sub data

#//////////////////////////////////////////////////////////////////////////////

=head2 provisioner

 Parameters  : $display_warning (optional)
 Returns     : Process's provisioner object
 Description : Allows OS modules to access the reservation's provisioner
               object.

=cut

sub provisioner {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$self->{provisioner}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return provisioner object, \$self->{provisioner} is not set");
		}
		return;
	}
	else {
		return $self->{provisioner};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 os

 Parameters  : $display_warning (optional)
 Returns     : Process's OS object
 Description : Allows modules to access the reservation's OS object.

=cut

sub os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$self->{os}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return OS object, \$self->{os} is not set");
		}
		return;
	}
	else {
		return $self->{os};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 mn_os

 Parameters  : $display_warning (optional)
 Returns     : Management node's OS object
 Description : Allows modules to access the management node's OS object.

=cut

sub mn_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$ENV{mn_os}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return management node OS object, \$ENV{mn_os} is not set");
		}
		return;
	}
	else {
		return $ENV{mn_os};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 vmhost_os

 Parameters  : $display_warning (optional)
 Returns     : VM hosts's OS object
 Description : Allows modules to access the VM host's OS object.

=cut

sub vmhost_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$self->{vmhost_os}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return VM host OS object, \$self->{vmhost_os} is not set");
		}
		return;
	}
	else {
		return $self->{vmhost_os};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 nathost_os

 Parameters  : $display_warning (optional)
 Returns     : NAT hosts's OS object
 Description : Allows modules to access the NAT host's OS object.

=cut

sub nathost_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module or VCL::DataStructure class method");
		return;
	}
	
	my $display_warning = shift;
	if (!defined($display_warning)) {
		$display_warning = 1;
	}
	
	if (!$self->{nathost_os}) {
		if ($display_warning) {
			notify($ERRORS{'WARNING'}, 0, "unable to return NAT host OS object, \$self->{nathost_os} is not set");
		}
		return;
	}
	else {
		return $self->{nathost_os};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_data

 Parameters  : $data
 Returns     : boolean
 Description : Sets the DataStructure object for the module to access.

=cut

sub set_data {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $data = shift;
	if (!defined($data)) {
		notify($ERRORS{'WARNING'}, 0, "DataStructure object reference argument not supplied");
		return;
	}
	elsif (!ref($data) || !$data->isa('VCL::DataStructure')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a DataStructure object reference:\n" . format_data($data));
		return;
	}
	$self->{data} = $data;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_os

 Parameters  : $os
 Returns     : boolean
 Description : Sets the OS object for the module to access.

=cut

sub set_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $os = shift;
	if (!defined($os)) {
		notify($ERRORS{'WARNING'}, 0, "OS object reference argument not supplied");
		return;
	}
	elsif (!ref($os) || !$os->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a VCL::Module::OS object reference:\n" . format_data($os));
		return;
	}
	$self->{os} = $os;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_mn_os

 Parameters  : $mn_os
 Returns     : boolean
 Description : Sets the management node OS object for the module to access.

=cut

sub set_mn_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $mn_os = shift;
	if (!defined($mn_os)) {
		notify($ERRORS{'WARNING'}, 0, "OS object reference argument not supplied");
		return;
	}
	elsif (!ref($mn_os) || !$mn_os->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a VCL::Module::OS object reference:\n" . format_data($mn_os));
		return;
	}
	
	my $address = sprintf('%x', $self);
	my $type = ref($self);
	my $mn_os_address = sprintf('%x', $mn_os);
	notify($ERRORS{'DEBUG'}, 0, "storing reference to managment node OS object (address: $mn_os_address) in this $type object (address: $address)");
	$ENV{mn_os} = $mn_os;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_vmhost_os

 Parameters  : $vmhost_os
 Returns     : boolean
 Description : Sets the VM host OS object for the module to access.

=cut

sub set_vmhost_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $vmhost_os = shift;
	if (!defined($vmhost_os)) {
		notify($ERRORS{'WARNING'}, 0, "OS object reference argument not supplied");
		return;
	}
	elsif (!ref($vmhost_os) || !$vmhost_os->isa('VCL::Module')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a VCL::Module object reference:\n" . format_data($vmhost_os));
		return;
	}
	
	my $address = sprintf('%x', $self);
	my $type = ref($self);
	my $vmhost_os_address = sprintf('%x', $vmhost_os);
	notify($ERRORS{'DEBUG'}, 0, "storing reference to VM host OS object (address: $vmhost_os_address) in this $type object (address: $address)");
	$self->{vmhost_os} = $vmhost_os;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_nathost_os

 Parameters  : $nathost_os
 Returns     : boolean
 Description : Sets the NAT host OS object for the module to access.

=cut

sub set_nathost_os {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $nathost_os = shift;
	if (!defined($nathost_os)) {
		notify($ERRORS{'WARNING'}, 0, "OS object reference argument not supplied");
		return;
	}
	elsif (!ref($nathost_os) || !$nathost_os->isa('VCL::Module')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a VCL::Module object reference:\n" . format_data($nathost_os));
		return;
	}
	
	my $address = sprintf('%x', $self);
	my $type = ref($self);
	my $nathost_os_address = sprintf('%x', $nathost_os);
	notify($ERRORS{'DEBUG'}, 0, "storing reference to NAT host OS object (address: $nathost_os_address) in this $type object (address: $address)");
	$self->{nathost_os} = $nathost_os;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_provisioner

 Parameters  : $provisioner
 Returns     : boolean
 Description : Sets the provisioner object for the module to access.

=cut

sub set_provisioner {
	my $self = shift;
	if (!ref($self) || !$self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was not called as a VCL::Module class method");
		return;
	}
	
	my $provisioner = shift;
	if (!defined($provisioner)) {
		notify($ERRORS{'WARNING'}, 0, "provisioner object reference argument not supplied");
		return;
	}
	elsif (!ref($provisioner) || !$provisioner->isa('VCL::Module::Provisioning')) {
		notify($ERRORS{'WARNING'}, 0, "supplied argument is not a VCL::Module::Provisioning object reference:\n" . format_data($provisioner));
		return;
	}
	$self->{provisioner} = $provisioner;
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_package_hierarchy

 Parameters  : String containing the name of a Perl package
               (note: parameter is optional if called as an object method,
               required if called as a class function
 Returns     : Array containing class package names
 Description : Determines the Perl package inheritance hierarchy given a
               package name or object reference.
               
               Returns an array containing the names of the originating
               Perl package and any parent packages it inherits from.
               
               This subroutine does not support multiple inheritance.
               If any package up the chain inherits from multiple classes,
               only the first class listed in the package's @ISA array is
               used.
               
               The package name on which this subroutine is called is the
               lowest in the hierarchy and has the lowest index in the
               array.
               
               If the package on which this subroutine is called does not
               explicitly inherit from any other packages, the array
               returned will only contain 1 element which is the calling
               package name.
               
               Example: call as object method:
               my $os = VCL::Module::OS::Windows::Version_5::XP->new({data_structure => $self->data});
               my @packages = $os->get_package_hierarchy();
               
               Example: call as class function:
               my @packages = get_package_hierarchy("VCL::Module::OS::Windows::Version_5::XP");
               
               Both examples return the following array:
               [0] = 'VCL::Module::OS::Windows::Version_5::XP'
               [1] = 'VCL::Module::OS::Windows::Version_5'
               [2] = 'VCL::Module::OS::Windows'
               [3] = 'VCL::Module::OS'
               [4] = 'VCL::Module'


=cut

sub get_package_hierarchy {
	my $argument = shift;
	if (!$argument) {
		notify($ERRORS{'WARNING'}, 0, "subroutine was not called as an object method and argument was not passed");
		return;
	}
	
	my @return_package_names;
	my $package_name;
	
	# Check if this was called as an object method
	# If it was, check if an argument was supplied
	if (ref($argument) && $argument->isa('VCL::Module')) {
		my $argument2 = shift;
		# If called as object method and argument was supplied, use the argument
		$argument = $argument2 if defined($argument2);
	}
	
	# Check if argument is an object reference or a package name string
	if (ref($argument)) {
		# Argument is a reference, get package hierarchy of object type which called this
		# Add the calling package name as the first element of the return array
		$package_name = ref($argument);
		push @return_package_names, $package_name;
	}
	else {
		# Argument is not a reference, assume argument is a string containing a package name
		$package_name = $argument;
	}
	#notify($ERRORS{'DEBUG'}, 0, "finding package hierarchy for: $package_name");
	
	# Use eval to retrieve the package name's @ISA array
	my @package_isa = eval '@' . $package_name . '::ISA';
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine \@ISA array for package: $package_name, error:\n$EVAL_ERROR");
		return;
	}
	
	# Get the number of elements in the package's @ISA array
	my $package_isa_count = scalar @package_isa;
	
	# Check if @ISA is empty
	if ($package_isa_count == 0) {
		#notify($ERRORS{'DEBUG'}, 0, "$package_name has no parent packages");
		return ();
	}
	
	#notify($ERRORS{'DEBUG'}, 0, "parent package names for $package_name:\n" . format_data(\@package_isa));
	my $parent_package_name = $package_isa[0];
	
	# Warn if package uses multiple inheritance, only use 1st element of package's @ISA array
	if ($package_isa_count > 1) {
		notify($ERRORS{'WARNING'}, 0, "$package_name has multiple parent packages, only using $parent_package_name");
	}
	
	# Add this package's parent package name to the return array
	push @return_package_names, $parent_package_name;
	
	# Recursively call this sub on the parent package and add the results to the return array
	push @return_package_names, get_package_hierarchy($parent_package_name);
	
	# Print the package names only for the original argument, not for recursive packages
	my $calling_subroutine = get_calling_subroutine();
	if ($calling_subroutine !~ /get_package_hierarchy/) {
		notify($ERRORS{'DEBUG'}, 0, "returning for $package_name:\n" . join("\n", @return_package_names));
	}
	return @return_package_names;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_class_variable_hierarchy

 Parameters  : $class_variable
 Returns     : array
 Description : VCL objects inherit from multiple parent classes:
               Ubuntu > Linux > OS > Module
               
               This subroutine allows a class variable which is defined in
               multiple parent class levels to be retrieved for each level. It
               traverse the object's parent classes from highest to lowest and
               return an array containing the value of the variable for each
               level. For example,
               
               Linux.pm defines this array reference:
               our $CAPTURE_DELETE_FILE_PATHS = [
                  '/root/.ssh/id_rsa',
                  '/root/.ssh/id_rsa.pub',
                  '/etc/udev/rules.d/70-persistent-net.rules',
               ];
               
               Ubuntu.pm defines this array reference with the same name:
               our $CAPTURE_DELETE_FILE_PATHS = [
                  '/etc/network/interfaces.20*',
               ];
               
               $self->os->get_class_variable_hierarchy('CAPTURE_DELETE_FILE_PATHS') =
               (
                  [
                     "/root/.ssh/id_rsa",
                     "/root/.ssh/id_rsa.pub",
                     "/etc/udev/rules.d/70-persistent-net.rules"
                  ],
                  [
                     "/etc/network/interfaces.20*"
                  ]
               )

=cut

sub get_class_variable_hierarchy {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine can only be called as a VCL module object method");
		return;	
	}
	
	my $class_variable_name = shift;
	if (!defined($class_variable_name)) {
		notify($ERRORS{'WARNING'}, 0, "class variable name argument was not supplied");
		return;
	}
	
	# Get an array containing the names of the Perl packages the OS object is a class of
	my @package_hierarchy = $self->get_package_hierarchy();
	
	# Loop through each classes, retrieve any which have a matching variable defined
	my @values = ();
	for my $package_name (@package_hierarchy) {
		my $value = eval '$' . $package_name . "::$class_variable_name";
		if ($EVAL_ERROR) {
			notify($ERRORS{'WARNING'}, 0, "unable to determine value of \$$class_variable_name for $package_name, error:\n$EVAL_ERROR");
			next;	
		}
		elsif (!$value) {
			notify($ERRORS{'DEBUG'}, 0, "\$$class_variable_name is not defined for $package_name");
			next;
		}
		
		notify($ERRORS{'DEBUG'}, 0, "\$$class_variable_name for $package_name: " . format_data($value));
		
		# Add the value to the return array
		# Use unshift to add to the beginning to the array
		unshift @values, $value; 
	}
	
	notify($ERRORS{'DEBUG'}, 0, "retrieved class variable hierarchy for '$class_variable_name':\n" . format_data(\@values));
	return @values;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 code_loop_timeout

 Parameters  : 1: code reference
               2: array reference containing arguments to pass to code reference
               3: message to display when attempting to execute code reference
               4: timeout seconds, maximum number of seconds to attempt to execute code until it returns true
               5: seconds to wait in between code execution attempts (optional)
               6: message interval seconds (optional)
 Returns     : If code returns true: returns result returned by code reference
               If code never returns true: 0
 Description : Executes the code contained in the code reference argument until
               it returns true or until the timeout is reached.
               
               Example:
               Call the _pingnode subroutine, pass it a single argument,
               continue calling _pingnode until 20 seconds have passed, wait 4
               seconds in between attempts:
               $self->os->code_loop_timeout(\&_pingnode, ['vclh3-8'], 'checking ping', 20, 4);

=cut

sub code_loop_timeout {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($code_ref, $args_array_ref, $message, $total_wait_seconds, $attempt_delay_seconds, $message_interval_seconds) = @_;
	
	# Make sure the code reference argument was passed correctly
	if (!defined($code_ref)) {
		notify($ERRORS{'WARNING'}, 0, "code reference argument is undefined");
		return;
	}
	elsif (ref($code_ref) ne 'CODE') {
		notify($ERRORS{'WARNING'}, 0, "1st argument must be a code reference, not " . format_data($code_ref));
		return;
	}
	
	if (!defined($args_array_ref)) {
		notify($ERRORS{'WARNING'}, 0, "2nd argument (arguments to pass to code reference) is undefined");
		return;
	}
	elsif (!ref($args_array_ref) || ref($args_array_ref) ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "2nd argument (arguments to pass to code reference) is not an array reference");
		return;
	}
	
	if (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "3nd argument (message to display) is undefined");
		return;
	}
	elsif (!$message) {
		$message = 'executing code reference';
	}
	
	if (!defined($total_wait_seconds) || $total_wait_seconds !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "4th argument (total wait seconds) was not passed correctly");
		return;
	}
	
	if (!$attempt_delay_seconds) {
		$attempt_delay_seconds = 15;
	}
	elsif (defined($attempt_delay_seconds) && $attempt_delay_seconds !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "5th argument (attempt delay) was not passed correctly: $attempt_delay_seconds");
		return;
	}
	
	if ($message_interval_seconds) {
		if ($message_interval_seconds !~ /^\d+$/) {
			notify($ERRORS{'WARNING'}, 0, "6th argument (message interval) was not passed correctly");
			return;
		}
		
		# Message interval is pointless if it's set to a value less than $attempt_delay_seconds
		if ($message_interval_seconds < $attempt_delay_seconds) {
			$message_interval_seconds = 0;
		}
	}
	else {
		$message_interval_seconds = 0;
	}
	
	notify($ERRORS{'DEBUG'}, 0, "$message, maximum of $total_wait_seconds seconds");
	
	my $start_time = time();
	my $current_time = $start_time;
	my $end_time = ($start_time + $total_wait_seconds);
	
	# Loop until code returns true
	my $attempt = 0;
	while (($current_time = time) <= $end_time) {
		$attempt++;
		
		# Execute the code reference
		if (my $result = &$code_ref(@{$args_array_ref})) {
			notify($ERRORS{'OK'}, 0, "$message, code returned true");
			return $result;
		}
		
		$current_time = time;
		my $seconds_elapsed = ($current_time - $start_time);
		my $seconds_remaining = ($end_time > $current_time) ? ($end_time - $current_time) : 0;
		my $sleep_seconds = ($seconds_remaining < $attempt_delay_seconds) ? $seconds_remaining : $attempt_delay_seconds;
		
		if (!$message_interval_seconds) {
			notify($ERRORS{'OK'}, 0, "attempt $attempt: $message ($seconds_elapsed/$seconds_remaining elapsed/remaining seconds), sleeping for $sleep_seconds seconds");
		}
		elsif ($attempt == 1 || ($seconds_remaining <= $attempt_delay_seconds) || ($seconds_elapsed % $message_interval_seconds) < $attempt_delay_seconds) {
			notify($ERRORS{'OK'}, 0, "attempt $attempt: $message ($seconds_elapsed/$seconds_remaining elapsed/remaining seconds)");
		}
		
		if (!$sleep_seconds) {
			last;
		}
		
		sleep $sleep_seconds;
	}

	notify($ERRORS{'OK'}, 0, "$message, code did not return true after waiting $total_wait_seconds seconds");
	return 0;
} ## end sub code_loop_timeout

#//////////////////////////////////////////////////////////////////////////////

=head2 get_semaphore

 Parameters  : $semaphore_identifier, $semaphore_expire_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : VCL::Module::Semaphore object
 Description : This subroutine is used to ensure that only 1 process performs a
               particular task at a time. An example would be the retrieval of
               an image from another management node. If multiple reservations
               are being processed for the same image, each reservation may
               attempt to retrieve it via SCP at the same time. This subroutine
               can be used to only allow 1 process to retrieve the image. The
               others will wait until the semaphore is released by the
               retrieving process.
               
               A semaphore object is returned. The semaphore will be retained as
               long as the semaphore object remains defined. Once undefined, the
               semaphore is released.
               
               Examples:
               
               Semaphore is released when it is undefined:
               my $semaphore = $self->get_semaphore('test');
               ... <semaphore in place>
               undef $semaphore;
               ... <semaphore released>
               
               Semaphore is released when it goes out of scope:
               if (blah) {
                  my $semaphore = $self->get_semaphore('test');
                  ... <semaphore in place>
               }
               ... <semaphore released>

=cut

sub get_semaphore {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my ($semaphore_identifier, $semaphore_expire_seconds, $attempt_delay_seconds) = @_;
	if (!$semaphore_identifier) {
		notify($ERRORS{'WARNING'}, 0, "semaphore identifier argument was not supplied");
		return;
	}
	
	# Attempt to create a new semaphore object
	# Load Semaphore.pm here instead of calling use
	# This prevents "Subroutine ... redefined" warnings
	eval {
		require "VCL/Module/Semaphore.pm";
		import VCL::Module::Semaphore;
	};
	my $semaphore = VCL::Module::Semaphore->new({'data_structure' => $self->data, mn_os => $self->mn_os});
	if (!$semaphore) {
		notify($ERRORS{'WARNING'}, 0, "failed to create semaphore object");
		return;
	}
	
	my $semaphore_object_address = sprintf('%x', $semaphore);
	
	if ($semaphore->obtain($semaphore_identifier, $semaphore_expire_seconds, $attempt_delay_seconds)) {
		notify($ERRORS{'DEBUG'}, 0, "obtained semaphore with identifier: '$semaphore_identifier', memory address: $semaphore_object_address");
		return $semaphore;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to obtain semaphore with identifier: '$semaphore_identifier'");
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_admin_message_variable

 Parameters  : $admin_message_key, $subject, $message
 Returns     : boolean
 Description : Sets an administrative message variable in the database.

=cut

sub set_admin_message_variable {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($admin_message_key, $subject, $message) = @_;
	if (!defined($admin_message_key)) {
		notify($ERRORS{'WARNING'}, 0, "message key argument was not supplied");
		return;
	}
	elsif (!defined($subject)) {
		notify($ERRORS{'WARNING'}, 0, "subject argument was not supplied\n" . format_data(\@_));
		return;
	}
	elsif (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "message argument was not supplied");
		return;
	}
	
	my $variable_name = "adminmessage|$admin_message_key";
	
	my $variable_value = {
		subject => $subject,
		message => $message,
	};
	
	if (!set_variable($variable_name, $variable_value)) {
		return;
	}
	
	# Test retrieving the variable
	return $self->get_admin_message($admin_message_key);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 set_user_message_variable

 Parameters  : $user_message_key, $affiliation_identifier, $subject, $message, $short_message (optional)
 Returns     : boolean
 Description : Sets a user message variable in the database.

=cut

sub set_user_message_variable {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_message_key, $affiliation_identifier, $subject, $message, $short_message) = @_;
	if (!defined($user_message_key)) {
		notify($ERRORS{'WARNING'}, 0, "key argument was not supplied");
		return;
	}
	elsif (!defined($affiliation_identifier)) {
		notify($ERRORS{'WARNING'}, 0, "affiliation identifier argument was not supplied");
		return;
	}
	elsif (!defined($subject)) {
		notify($ERRORS{'WARNING'}, 0, "subject argument was not supplied\n" . format_data(\@_));
		return;
	}
	elsif (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "message argument was not supplied");
		return;
	}
	
	
	# Determine the affiliation name from the $affiliation_identifier argument
	my $affiliation_info = get_affiliation_info($affiliation_identifier);
	if (!$affiliation_info) {
		notify($ERRORS{'WARNING'}, 0, "failed to set user message variable, affiliation info could not be retrieved for identifier argument: '$affiliation_identifier'");
		return;
	}
	my $affiliation_name = $affiliation_info->{name};
	
	my $variable_name = "usermessage|$user_message_key|$affiliation_name";
	
	my $variable_value = {
		subject => $subject,
		message => $message,
		short_message => $short_message,
	};
	
	if (!set_variable($variable_name, $variable_value)) {
		return;
	}
	
	# Test retrieving the variable
	return $self->_get_message_variable($user_message_key);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 _get_message_variable

 Parameters  : $message_key, $return_short_message (optional), $admin_message (optional)
 Returns     : array context, array: ($subject, $message)
               scalar context, string: $message
 Description : Retrieves message components from the variable table in the
               database. This is a helper subroutine and should not be called
               directly from outside this module file.
               
               The composition of the variable.name field varies based on
               whether the message is intended for end users or for
               administrators of the VCL system. variable.name will begin with
               either of the following:
               usermessage|
               adminmessage|
               
               The $message_key argument is a string that identifies the
               message to retrieve. It is treated the same for both user and
               admin-intended messages.
               
               Admin-intended messages cannot be customized per affiliation. The
               composition of variable.name is as follows:
               adminmessage|<Message Key>
               
               Example:
               adminmessage|image_creation_failed
               
               User-intended messages may be customized based on the user's
               affiliation and the variable.name field contains an additional
               affiliation name component:
               usermessage|<Message Key>|<Affiliation Name>
               
               Example:
               usermessage|timeout_inactivity|Global
               
               The database schema contains default message entries for the
               'Global' affiliation. For user-intended messages, if there is an
               entry that matches the user's affiliation name, that message will
               be returned. If not, the Global affiliation message will be
               returned by default.
               
               The variable.value field contains a YAML-encoded hash data
               structure. The following hash keys are recognized:
               * subject (required)
               * message (required)
               * short_message (optional)
               
               The subject and message values will be used when sending email
               messages. The short_message key is optional and will be used when
               sending console, desktop, or IM messages to users.
               
               The $return_short_message argument controls whether to return the
               value of message (default) or short_message.
               
               The $admin_message argument controls whether to retrieve
               messages with a variable.name beginning with 'usermessage'
               (default) or 'adminmessage'.

=cut

sub _get_message_variable {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($message_key, $return_short_message, $admin_message) = @_;
	if (!defined($message_key)) {
		notify($ERRORS{'WARNING'}, 0, "key argument was not supplied");
		return;
	}
	
	my $message_type = ($admin_message ? 'admin' : 'user');
	
	# Assemble the variable name
	my $variable_name;
	if ($admin_message) {
		# Assemble admin message variable name
		$variable_name= "adminmessage|$message_key";
	}
	else {
		# Assemble user message variable name
		my $user_affiliation_name = $self->data->get_user_affiliation_name();
		$variable_name= "usermessage|$message_key|$user_affiliation_name";
		
		# Check if the affiliation-specific variable is set, if not revert to Global
		if (!is_variable_set($variable_name)) {
			notify($ERRORS{'DEBUG'}, 0, "affiliation-specific variable is NOT set in database: $variable_name");
			$variable_name = "usermessage|$message_key|Global";
		}
	}
	
	# Retrieve the variable from the database
	my $variable = get_variable($variable_name);
	if (!defined($variable)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $message_type message variable, failed to retieve variable matching name: '$variable_name'");
		return;
	}
	
	# Make sure the variable contains subject key
	my $subject = $variable->{subject};
	if (!defined($subject)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $message_type message variable: '$variable_name', variable stored in database does not contain a {subject} key:\n" . format_data($variable));
		return;
	}
	
	# Check if supposed to return short message, return long message if not defined
	my $message;
	if ($return_short_message) {
		if ($variable->{short_message}) {
			$message = $variable->{short_message};
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "short message was requested but not defined in '$variable_name' variable");
		}
	}
	$message = $variable->{message} if !defined($message);
	
	# Make sure message was determined
	if (!defined($message)) {
		notify($ERRORS{'WARNING'}, 0, "unable to retrieve $message_type message variable: '$variable_name', variable stored in database does not contain a {message} key:\n" . format_data($variable));
		return;
	}
	
	my $subject_substituted = $self->data->substitute_string_variables($subject);
	my $message_substituted = $self->data->substitute_string_variables($message);
	if (!defined($subject_substituted) || !defined($message_substituted)) {
		notify($ERRORS{'WARNING'}, 0, "retrieved $message_type message variable '$variable_name' but failed to substitute text");
		return;
	}
	
	# Remove leading and trailing newlines from message
	$message_substituted =~ s/(^\n+|\n+$)//g;
	
	if (wantarray) {
		notify($ERRORS{'DEBUG'}, 0, "retrieved $message_type message variable: $variable_name, returning array:\n" .
			"subject: $subject_substituted\n" .
			"message:\n$message_substituted"
		);
		return ($subject_substituted, $message_substituted);
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "retrieved $message_type message variable: '$variable_name', returning message string:\n$message_substituted");
		return $message_substituted;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_message

 Parameters  : $user_message_key
 Returns     : array context, array: ($subject, $message)
               scalar context, string: $message
 Description : Retrieves user messages.

=cut

sub get_user_message {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_message_key) = @_;
	return $self->_get_message_variable($user_message_key);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_user_short_message

 Parameters  : $user_message_key
 Returns     : array context, array: ($subject, $short_message)
               scalar context, string: $short_message
 Description : Retrieves user short messages.

=cut

sub get_user_short_message {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($user_message_key) = @_;
	return $self->_get_message_variable($user_message_key, 1);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_admin_message

 Parameters  : $admin_message_key
 Returns     : array context, array: ($subject, $message)
               scalar context, string: $message
 Description : Retrieves administrative messages.

=cut

sub get_admin_message {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my ($admin_message_key) = @_;
	return $self->_get_message_variable($admin_message_key, 0, 1);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : hash reference
 Description : Constructs the general menu items used when 'vcld -setup' is
               invoked.

=cut

sub setup_get_menu {
	return {
		'User Accounts' => {
			'Add Local VCL User Account' => \&setup_add_local_account,
			'Set Local VCL User Account Password' => \&setup_set_local_account_password,
		},
		'Management Node Configuration' => {
			'Test RPC-XML Access' => \&setup_test_rpc_xml,
		}
	};
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_add_local_account

 Parameters  : none
 Returns     : boolean
 Description : Presents an interface to create a local VCL user account. This
               subroutine is executed when vcld is run with the -setup argument.

=cut

sub setup_add_local_account {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	#myusername', 'myfirstname', 'mylastname', 'myemailaddr',
	
	# Get the username (user.unityid)
	my $username;
	while (!$username) {
		$username = setup_get_input_string("Enter the user login name");
		return if (!defined($username));
		
		# Check format of username
		if ($username !~ /^[\w\-_]+$/i) {
			print "User name is not valid: '$username'\n\n";
			$username = undef;
		}
		
		# Make sure username does not already exist
		my $user_info = get_user_info($username, 'Local');
		if ($user_info && $user_info->{unityid} eq $username) {
			print "Local VCL user account already exists: $username\n\n";
			$username = undef;
		}
	}
	print "\n";
	
	# Get the other required information
	my $first_name;
	while (!$first_name) {
		$first_name = setup_get_input_string("Enter the first name");
		return if (!defined($first_name));
	}
	print "\n";
	
	my $last_name;
	while (!$last_name) {
		$last_name = setup_get_input_string("Enter the last name");
		return if (!defined($last_name));
	}
	print "\n";
	
	my $email_address;
	while (!defined($email_address)) {
		$email_address = setup_get_input_string("Enter the email address", 'not set');
		return if (!defined($email_address));
		
		# Check format of the email address
		if ($email_address eq 'not set') {
			$email_address = '';
		}
		elsif ($email_address !~ /^([A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}(,?))+$/i) {
			print "Email address is not valid: '$email_address'\n\n";
			$email_address = undef;
		}
	}
	print "\n";
	
	my $password;
	while (!$password) {
		$password = setup_get_input_string("Enter the password");
		return if (!defined($password));
	}
	print "\n";
	
	# Generate an 8-character random string
	my @characters = ("a" .. "z", "A" .. "Z", "0" .. "9");
	my $random_string;
	srand;
	for (1 .. 8) {
		$random_string .= $characters[rand((scalar(@characters) - 1))];
	}
	
	# Get an SHA1 hex digest from the password and random string
	my $digest = sha1_hex("$password$random_string");
	
	# Insert a row into the user table
	my $insert_user_statement = <<EOF;
INSERT INTO user
(unityid, affiliationid, firstname, lastname, email, lastupdated)
VALUES
('$username', (SELECT id FROM affiliation WHERE name LIKE 'Local'), '$first_name', '$last_name', '$email_address', NOW())
EOF
	
	my $user_id = database_execute($insert_user_statement);
	if (!defined($user_id)) {
		print "ERROR: failed to insert into user table\n";
		return;
	}
	
	# Insert a row into the localauth table
	my $insert_localauth_statement = <<EOF;
INSERT INTO localauth
(userid, passhash, salt, lastupdated)
VALUES
($user_id, '$digest', '$random_string', NOW())
EOF
	
	my $localauth_id = database_execute($insert_localauth_statement);
	if (!defined($localauth_id)) {
		print "ERROR: failed to insert into localauth table\n";
		return;
	}
	
	print "Local VCL user account successfully created: $username\n";
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_add_local_account

 Parameters  : none
 Returns     : boolean
 Description : Presents an interface to create a local VCL user account. This
               subroutine is executed when vcld is run with the -setup argument.

=cut

sub setup_test_rpc_xml {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	my $verbose = shift;
	if (!defined($verbose)) {
		$verbose = 1;
	}

	my $error_count = 0;
	my $user_id;
	
	if (!$XMLRPC_URL) {
		print "PROBLEM: xmlrpc_url is not configured in $CONF_FILE_PATH\n";
		$error_count++;
	}
	
	if (!$XMLRPC_USER) {
		print "PROBLEM: xmlrpc_username is not configured in $CONF_FILE_PATH\n";
		$error_count++;
	}
	elsif ($XMLRPC_USER !~ /.@./) {
		print "PROBLEM: xmlrpc_username value is not valid: '$XMLRPC_USER', the format must be 'username" . '@' . "affiliation_name'\n";
		$error_count++;
	}
	else {
		my ($username, $user_affiliation_name) = $XMLRPC_USER =~ /(.+)@(.+)/;
		
		my $affiliation_ok = 0;
		
		my $affiliation_info = get_affiliation_info();
		if (!$affiliation_info) {
			print "WARNING: unable to retrieve affiliation info from the database, unable to determine if affilation '$user_affiliation_name' is valid\n";
		}
		else {
			for my $affiliation_id (keys(%$affiliation_info)) {
				my $affiliation_name = $affiliation_info->{$affiliation_id}{name};
				if ($user_affiliation_name =~ /^$affiliation_name$/i) {
					print "OK: verified user affiliation exists in the database: '$affiliation_name'\n";
					$affiliation_ok = 1;
					last;
				}
			}
			if (!$affiliation_ok) {
				print "PROBLEM: user affiliation '$user_affiliation_name' does not exist in the database\n";
				$error_count++;
			}
		}
		
		if ($affiliation_ok) {
			my $user_info = get_user_info($username, $user_affiliation_name);
			if ($user_info) {
				print "OK: verified user exists in the database: '$XMLRPC_USER'\n";
				$user_id = $user_info->{id};
			}
			else {
				print "PROBLEM: user does not exist in the database database: username: '$username', affiliation: '$user_affiliation_name'\n";
				$error_count++;
			}
			
			if (!$XMLRPC_PASS) {
				print "not verifying user password because xmlrpc_pass is not set in $CONF_FILE_PATH\n";
			}
			elsif ($user_affiliation_name !~ /^local$/i) {
				print "not verifying user password because $XMLRPC_USER is not a local account\n";
			}
			elsif (!$user_info->{localauth}) {
				print "WARNING: not verifying user password because localauth information could not be retrieved from the database\n";
			}
			else {
				my $passhash = $user_info->{localauth}{passhash};
				my $salt = $user_info->{localauth}{salt};
				
				#print "verifying user password: '$XMLRPC_PASS':'$salt' =? '$passhash'\n";
				
				# Get an SHA1 hex digest from the password and random string
				my $digest = sha1_hex("$XMLRPC_PASS$salt");
				
				if ($passhash eq $digest) {
					print "OK: verfied xmlrpc_pass value is the correct password for $XMLRPC_USER\n";
				}
				else {
					print "PROBLEM: xmlrpc_pass value configured in $CONF_FILE_PATH is not correct\n";
					#print "localauth.passhash: $passhash\n";
					#print "localauth.salt: $salt\n";
					#print "xmlrpc_pass: $XMLRPC_PASS\n";
					#print "calculated SHA1 digest ('$XMLRPC_PASS$salt'): $digest\n";
					#print "'$digest' != '$passhash'";
					$error_count++;
				}
			}
		}
	}

	if (!$XMLRPC_PASS) {
		print "PROBLEM: xmlrpc_pass is not configured in $CONF_FILE_PATH\n";
		$error_count++;
	}
	
	print "\n";
	
	if ($error_count) {
		print "FAILURE: RPC-XML access is not configured correctly, errors encountered: $error_count\n";
		return 0;
	}
	
	my $xmlrpc_function = 'system.listMethods';
	my @xmlrpc_arguments = (
		$xmlrpc_function,
	);
	
	my $response = xmlrpc_call(@xmlrpc_arguments);
	if ($response && $response->value) {
		print "SUCCESS: RPC-XML access is configured correctly\n" . format_data($response->value) . "\n" if ($verbose == 1);
		return 1;
	}
	
	
	if (!$ENV{rpc_xml_error}) {
		print "FAILURE: RPC-XML access is not configured correctly, view the log file for more information: $LOGFILE\n";
		return 0;
	}
	
	print "FAILURE: RPC-XML access is not configured correctly, error message:\n$ENV{rpc_xml_error}\n\n";
	
	if ($ENV{rpc_xml_error} =~ /access denied/i) {
		# Affiliation not correct
		# Affiliation not included, default affiliation isn't Local
		# Incorrect password
		print "SUGGESTION: make sure the xmlrpc_username and xmlrpc_pass values are correct in $CONF_FILE_PATH\n";
	}
	if ($ENV{rpc_xml_error} =~ /internal server error/i) {
		# Affiliation not included in username
		# User doesn't exist but affiliation does
		# Affiliation does not exist
		print "SUGGESTION:  make sure the xmlrpc_username is correct in $CONF_FILE_PATH, current value: '$XMLRPC_USER'\n";
	}
	if ($ENV{rpc_xml_error} =~ /internal error while processing/i) {
		# Affiliation not included in username
		# User doesn't exist but affiliation does
		# Affiliation does not exist
		print "SUGGESTION: make sure user ID $user_id has been added to the \$xmlrpcBlockAPIUsers line in the conf.php file on the web server\n";
	}
	
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_set_local_account_password

 Parameters  : none
 Returns     : boolean
 Description : 

=cut

sub setup_set_local_account_password {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $local_user_info = get_local_user_info();
	
	print "Select a local VCL user account:\n";
	my $user_id = setup_get_hash_choice($local_user_info, 'unityid');
	return if (!defined($user_id));
	
	my $user_login_name = $local_user_info->{$user_id}{unityid};
	
	print "Selected user: $user_login_name (id: $user_id)\n";
	
	my $password;
	while (!$password) {
		$password = setup_get_input_string("Enter the new password");
		return if (!defined($password));
	}
	
	
	# Generate an 8-character random string
	my @characters = ("a" .. "z", "A" .. "Z", "0" .. "9");
	my $random_string;
	srand;
	for (1 .. 8) {
		$random_string .= $characters[rand((scalar(@characters) - 1))];
	}
	
	# Get an SHA1 hex digest from the password and random string
	my $digest = sha1_hex("$password$random_string");
	
	# Insert a row into the localauth table
	my $insert_localauth_statement = <<EOF;
UPDATE localauth SET
passhash = '$digest',
salt = '$random_string'
WHERE
userid = $user_id
EOF
	
	if (database_execute($insert_localauth_statement)) {
		print "Reset password for local '$user_login_name' account to '$password'\n";
	}
	else {
		print "ERROR: failed to update localauth table\n";
		return;
	}
	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Displays the module objects address and calls the super class
               destroy method if available.

=cut

sub DESTROY {
	my $self = shift;
	if (!defined($self)) {
		notify($ERRORS{'DEBUG'}, 0, "skipping VCL::Module DESTROY tasks, \$self is not defined");
		return;
	}
	
	my $address = sprintf('%x', $self);
	my $type = ref($self);
	notify($ERRORS{'DEBUG'}, 0, "destroying $type object, address: $address");
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
} ## end sub DESTROY

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
