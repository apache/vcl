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

##############################################################################
package VCL::Module;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';
use Digest::SHA1 qw(sha1_hex);

use VCL::utils;
use VCL::DataStructure;
use VCL::Module::Semaphore;

##############################################################################

=head1 CONSTRUCTOR

=cut

#/////////////////////////////////////////////////////////////////////////////

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
	
	# Create a management node OS object
	if (!$self->isa('VCL::Module::OS::Linux::ManagementNode')) {
		if (!$self->create_mn_os_object()) {
			notify($ERRORS{'WARNING'}, 0, "failed to create management node OS object");
			return;
		}
	}
	
	# Display a message based on the type of object created
	if ($self->isa('VCL::Module::State')) {
		my $request_state_name = $self->data->get_request_state_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object created for state $request_state_name, address: $address");
	}
	elsif ($self->isa('VCL::Module::OS')) {
		my $image_name = $self->data->get_image_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object created for image $image_name, address: $address");
	}
	elsif ($self->isa('VCL::Module::Provisioning')) {
		my $computer_name = $self->data->get_computer_short_name(0) || '<not set>';
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object created for computer $computer_name, address: $address");
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, ref($self) . " object created, address: $address");
	}

	# Check if not running in setup mode and if initialize() subroutine is defined for this module
	if (!$SETUP_MODE && $self->can("initialize")) {
		# Call the initialize() subroutine, if it returns 0, return 0
		# If it doesn't return 0, return the object reference
		return if (!$self->initialize($args));
	}

	return $self;
} ## end sub new

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 data

 Parameters  : None
 Returns     : Reference to the DataStructure object
 Description : This subroutine allows VCL module objects to retrieve data using
               the object's DataStructure object as follows:
               my $image_id = $self->data->get_image_id();

=cut

sub data {
	my $self = shift;

	# If this was called as a class method, return the DataStructure object stored in the class object
	return $self->{data} if ref($self);

	# Not called as a class method, check to see if $ENV{data} is defined
	return $ENV{data} if (defined($ENV{data}) && $ENV{data});

	# $ENV{data} is not set, set it
	$ENV{data} = new VCL::DataStructure();

	# Return the new DataStructure if got created successfully
	return $ENV{data} if (defined($ENV{data}) && $ENV{data});

	notify($ERRORS{'CRITICAL'}, 0, "unable to create DataStructure object");
	return 0;
} ## end sub data

#/////////////////////////////////////////////////////////////////////////////

=head2 create_os_object

 Parameters  : None
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
		notify($ERRORS{'WARNING'}, 0, "$os_perl_package module could not be loaded, returning 0");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$os_perl_package module loaded");
	
	# Attempt to create the object
	if (my $os = ($os_perl_package)->new({data_structure => $self->data})) {
		my $os_address = sprintf('%x', $os);
		my $os_image_name = $os->data->get_image_name();
		notify($ERRORS{'OK'}, 0, "$os_perl_package OS object created, address: $os_address");
		
		# Store the OS object if an OS Perl package argument wasn't passed
		if (!$os_perl_package_argument) {
			$self->set_os($os);
		}
		
		return $os;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create OS object");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_mn_os_object

 Parameters  : None
 Returns     : boolean
 Description : Creates a management node OS object if one has not already been
               created for the calling object.

=cut

sub create_mn_os_object {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if an OS object has already been stored in the calling object
	if ($ENV{mn_os}) {
		my $address = sprintf('%x', $ENV{mn_os});
		#notify($ERRORS{'DEBUG'}, 0, "management node OS object has already been created, address: $address, returning 1");
		return 1;
	}
	
	# Make sure calling object isn't an OS module to avoid an infinite loop
	if ($self->isa('VCL::Module::OS::Linux::ManagementNode')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing management node OS module: " . ref($self));
		return;
	}
	
	my $request_data = $self->data->get_request_data();
	my $reservation_id = $self->data->get_reservation_id();
	
	# Create a DataStructure object containing computer data for the management node
	my $mn_data;
	eval {
		$mn_data = new VCL::DataStructure('image_id' => 'noimage');
	};
	
	# Attempt to load the OS module
	my $mn_os_perl_package = 'VCL::Module::OS::Linux::ManagementNode';
	eval "use $mn_os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$mn_os_perl_package module could not be loaded, returning 0");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$mn_os_perl_package module loaded");
	
	# Attempt to create the object
	if (my $mn_os = ($mn_os_perl_package)->new({data_structure => $mn_data})) {
		my $address = sprintf('%x', $mn_os);
		notify($ERRORS{'OK'}, 0, "$mn_os_perl_package OS object created, address: $address");
		$self->set_mn_os($mn_os);
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create management node OS object");
		return;
	}
	
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_vmhost_os_object

 Parameters  : None
 Returns     : boolean
 Description : Creates an OS object for the VM host.

=cut

sub create_vmhost_os_object {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Check if an OS object has already been stored in the calling object
	if ($ENV{vmhost_os}) {
		return 1;
	}
	
	# Make sure calling object isn't an OS module to avoid an infinite loop
	if ($self->isa('VCL::Module::OS')) {
		notify($ERRORS{'WARNING'}, 0, "this subroutine cannot be called from an existing OS module: " . ref($self));
		return;
	}
	
	my $request_data = $self->data->get_request_data();
	my $reservation_id = $self->data->get_reservation_id();
	my $vmhost_computer_id = $self->data->get_vmhost_computer_id();
	my $vmhost_profile_image_id = $self->data->get_vmhost_profile_image_id();
	
	# Create a DataStructure object containing computer data for the VM host
	my $vmhost_data;
	eval {
		$vmhost_data = new VCL::DataStructure({
															request_data => $request_data,
															reservation_id => $reservation_id,
															computer_id => $vmhost_computer_id,
															image_id => $vmhost_profile_image_id
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
	
	# Load the VM host OS module
	notify($ERRORS{'DEBUG'}, 0, "attempting to load VM host OS module: $vmhost_os_perl_package (image: $vmhost_profile_image_id)");
	eval "use $vmhost_os_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "VM host OS module could NOT be loaded: $vmhost_os_perl_package, error: $EVAL_ERROR");
		return;
	}
	notify($ERRORS{'DEBUG'}, 0, "VM host OS module loaded: $vmhost_os_perl_package");
	
	# Attempt to create the object
	if (my $vmhost_os = ($vmhost_os_perl_package)->new({data_structure => $vmhost_data})) {
		my $address = sprintf('%x', $vmhost_os);
		notify($ERRORS{'OK'}, 0, "$vmhost_os_perl_package OS object created, address: $address");
		$self->set_vmhost_os($vmhost_os);
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to create VM host OS object");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_provisioning_object

 Parameters  : None
 Returns     : 
 Description : 

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
	my $provisioning_perl_package = $self->data->get_computer_provisioning_module_perl_package();
	if (!$provisioning_perl_package) {
		notify($ERRORS{'WARNING'}, 0, "provisioning object could not be created, provisioning module Perl package could not be retrieved");
		return;
	}
	
	# Attempt to load the computer provisioning module
	eval "use $provisioning_perl_package";
	if ($EVAL_ERROR) {
		notify($ERRORS{'WARNING'}, 0, "$provisioning_perl_package module could not be loaded, returning 0");
		return 0;
	}
	notify($ERRORS{'DEBUG'}, 0, "$provisioning_perl_package module loaded");

	# Create provisioner object
	if (my $provisioner = ($provisioning_perl_package)->new({data_structure => $self->data, os => $self->{os}})) {
		my $provisioner_address = sprintf('%x', $provisioner);
		my $provisioner_computer_name = $provisioner->data->get_computer_short_name();
		notify($ERRORS{'OK'}, 0, "$provisioning_perl_package provisioner object created for $provisioner_computer_name, address: $provisioner_address");
		$self->set_provisioner($provisioner);
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "provisioning object could not be created, returning 0");
		return 0;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 os

 Parameters  : None
 Returns     : Process's OS object
 Description : Allows modules to access the reservation's OS object.

=cut

sub os {
	my $self = shift;
	
	if (!$self->{os}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return OS object, \$self->{os} is not set");
		return;
	}
	else {
		return $self->{os};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 mn_os

 Parameters  : None
 Returns     : Management node's OS object
 Description : Allows modules to access the management node's OS object.

=cut

sub mn_os {
	my $self = shift;
	
	if (!$ENV{mn_os}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return management node OS object, \$ENV{mn_os} is not set");
		return;
	}
	else {
		return $ENV{mn_os};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 vmhost_os

 Parameters  : None
 Returns     : VM hosts's OS object
 Description : Allows modules to access the VM host's OS object.

=cut

sub vmhost_os {
	my $self = shift;
	
	if (!$ENV{vmhost_os}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return VM host OS object, \$self->{vmhost_os} is not set");
		return;
	}
	else {
		return $ENV{vmhost_os};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 provisioner

 Parameters  : None
 Returns     : Process's provisioner object
 Description : Allows OS modules to access the reservation's provisioner
               object.

=cut

sub provisioner {
	my $self = shift;
	
	if (!$self->{provisioner}) {
		notify($ERRORS{'WARNING'}, 0, "unable to return provisioner object, \$self->{provisioner} is not set");
		return;
	}
	else {
		return $self->{provisioner};
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_os

 Parameters  : None
 Returns     : 
 Description : Sets the OS object for the module to access.

=cut

sub set_os {
	my $self = shift;
	my $os = shift;
	$self->{os} = $os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_mn_os

 Parameters  : None
 Returns     : 
 Description : Sets the management node OS object for the module to access.

=cut

sub set_mn_os {
	my $self = shift;
	my $mn_os = shift;
	$ENV{mn_os} = $mn_os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_vmhost_os

 Parameters  : None
 Returns     : 
 Description : Sets the VM host OS object for the module to access.

=cut

sub set_vmhost_os {
	my $self = shift;
	my $vmhost_os = shift;
	$ENV{vmhost_os} = $vmhost_os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 set_provisioner

 Parameters  : None
 Returns     : Process's provisioner object
 Description : Sets the provisioner object for the module to access.

=cut

sub set_provisioner {
	my $self = shift;
	my $provisioner = shift;
	$self->{provisioner} = $provisioner;
}

#/////////////////////////////////////////////////////////////////////////////

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
	notify($ERRORS{'DEBUG'}, 0, "finding package hierarchy for: $package_name");
	
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
		notify($ERRORS{'DEBUG'}, 0, "$package_name has no parent packages");
		return ();
	}
	
	notify($ERRORS{'DEBUG'}, 0, "parent package names for $package_name:\n" . format_data(\@package_isa));
	my $parent_package_name = $package_isa[0];
	
	# Warn if package uses multiple inheritance, only use 1st element of package's @ISA array
	if ($package_isa_count > 1) {
		notify($ERRORS{'WARNING'}, 0, "$package_name has multiple parent packages, only using $parent_package_name");
	}
	
	# Add this package's parent package name to the return array
	push @return_package_names, $parent_package_name;
	
	# Recursively call this sub on the parent package and add the results to the return array
	push @return_package_names, get_package_hierarchy($parent_package_name);
	
	notify($ERRORS{'DEBUG'}, 0, "returning for $package_name:\n" . format_data(\@return_package_names));
	return @return_package_names;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 code_loop_timeout

 Parameters  : 1: code reference
               2: array reference containing arguments to pass to code reference
               3: message to display when attempting to execute code reference
               4: timeout seconds, maximum number of seconds to attempt to execute code until it returns true
               5: seconds to wait in between code execution attempts
 Returns     : If code returns true: 1
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
	
	# Get the start time
	my $start_time = time();
	
	my $computer_node_name = $self->data->get_computer_node_name();
	
	# Check the argument count and get the arguments
	if (scalar(@_) != 5) {
		notify($ERRORS{'WARNING'}, 0, scalar(@_) . " arguments were passed, argument count must be 5");
		return;
	}
	my ($code_ref, $args_array_ref, $message, $total_wait_seconds, $attempt_delay_seconds) = @_;
	
	# Make sure the code reference argument was passed correctly
	if (!defined($code_ref)) {
		notify($ERRORS{'WARNING'}, 0, "code reference argument is undefined");
		return;
	}
	elsif (ref($code_ref) ne 'CODE') {
		notify($ERRORS{'WARNING'}, 0, "1st argument must be a code reference, not " . ref($code_ref));
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
	
	if (!defined($attempt_delay_seconds) || $attempt_delay_seconds !~ /^\d+$/) {
		notify($ERRORS{'WARNING'}, 0, "5th argument (attempt delay) was not passed correctly");
		return;
	}
	
	
	# Calculate total seconds to wait and end time
	my $end_time = $start_time + $total_wait_seconds;
	notify($ERRORS{'OK'}, 0, "$message, maximum of $total_wait_seconds seconds");
	
	# Loop until code returns true
	# Loop once if the wait time is 0
	my $attempt_count = 0;
	my $current_time;
	while (($current_time = time()) < $end_time || ($total_wait_seconds == 0 && $attempt_count == 0)) {
		$attempt_count++;
		
		if ($attempt_count > 1) {
			my $seconds_elapsed = $current_time - $start_time;
			my $seconds_remaining = $end_time - $current_time;
			
			notify($ERRORS{'OK'}, 0, "attempt " . ($attempt_count-1) . ": $message ($seconds_elapsed/$seconds_remaining seconds) sleeping for $attempt_delay_seconds seconds");
			sleep $attempt_delay_seconds;
		}
		
		#notify($ERRORS{'OK'}, 0, "attempt $attempt_count: $message");
		
		if (&$code_ref(@{$args_array_ref})) {
			notify($ERRORS{'OK'}, 0, "$message, code returned true");
			return 1;
		}
	}

	notify($ERRORS{'OK'}, 0, "$message, code did not return true after waiting $total_wait_seconds seconds");
	return 0;
} ## end sub code_loop_timeout

#/////////////////////////////////////////////////////////////////////////////

=head2 get_semaphore

 Parameters  : $semaphore_id, $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : VCL::Module::Semaphore object
 Description : This subroutine is used to ensure that only 1 process performs a
               particular task at a time. An example would be the retrieval of
               an image from another management node. If multiple reservations
               are being processed for the same image, each reservation may
               attempt to retrieve it via SCP at the same time. This subroutine
               can be used to only allow 1 process to retrieve the image. The
               others will wait until the semaphore is released by the
               retrieving process.
               
               Attempts to open and obtain an exclusive lock on the file
               specified by the file path argument. If unable to obtain an
               exclusive lock, it will wait up to the value specified by the
               total wait seconds argument (default: 30 seconds). The number of
               seconds to wait in between retries can be specified (default: 15
               seconds).
               
               A semaphore object is returned. The exclusive lock will be
               retained as long as the semaphore object remains defined. Once
               undefined, the exclusive lock is released and the file is
               deleted.
               
               Examples:
               
               Semaphore is released when it is undefined:
               my $semaphore = $self->get_semaphore('test');
               ... <exclusive lock is in place>
               undef $semaphore;
               ... <exclusive lock released>
               
               Semaphore is released when it goes out of scope:
               if (blah) {
                  my $semaphore = $self->get_semaphore('test');
                  ... <exclusive lock is in place>
               }
               ... <exclusive lock released>

=cut

sub get_semaphore {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my ($semaphore_id, $total_wait_seconds, $attempt_delay_seconds) = @_;
	if (!$semaphore_id) {
		notify($ERRORS{'WARNING'}, 0, "semaphore ID argument was not supplied");
		return;
	}
	
	# Attempt to create a new semaphore object
	my $semaphore = VCL::Module::Semaphore->new({'data_structure' => $self->data});
	if (!$semaphore) {
		notify($ERRORS{'WARNING'}, 0, "failed to create semaphore object");
		return;
	}
	
	# Attempt to open and exclusively lock the file
	if ($semaphore->get_lockfile($semaphore_id, $total_wait_seconds, $attempt_delay_seconds)) {
		# Return the semaphore object
		my $address = sprintf('%x', $semaphore);
		notify($ERRORS{'DEBUG'}, 0, "created '$semaphore_id' Semaphore object, memory address: $address");
		return $semaphore;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to create '$semaphore_id' Semaphore object");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 setup

 Parameters  : none
 Returns     : 
 Description : This subroutine is used when vcld is run in setup mode. It
               presents a menu for overall VCL configuration settings.

=cut

sub setup {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	push @{$ENV{setup_path}}, 'User Accounts';
	
	my @operation_choices = (
		'Add Local VCL User Account',
		'Set Local VCL User Account Password',
		'Test RPC-XML Access',
	);
	
	my @setup_path = @{$ENV{setup_path}};
	OPERATION: while (1) {
		@{$ENV{setup_path}} = @setup_path;
		
		print '-' x 76 . "\n";
		
		print "Choose an operation:\n";
		my $operation_choice_index = setup_get_array_choice(@operation_choices);
		last if (!defined($operation_choice_index));
		my $operation_name = $operation_choices[$operation_choice_index];
		print "\n";
		
		push @{$ENV{setup_path}}, $operation_name;
		
		if ($operation_name =~ /add local/i) {
			$self->setup_add_local_account();
		}
		elsif ($operation_name =~ /rpc/i) {
			$self->setup_test_rpc_xml();
		}
		elsif ($operation_name =~ /password/i) {
			$self->setup_set_local_account_password();
		}
	}
	
	pop @{$ENV{setup_path}};
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

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
		return;
	}
	
	my $xmlrpc_function = 'system.listMethods';
	my @xmlrpc_arguments = (
		$xmlrpc_function,
	);
	
	my $response = xmlrpc_call(@xmlrpc_arguments);
	if ($response && $response->value) {
		print "SUCCESS: RPC-XML access is configured correctly\n" . format_data($response->value) . "\n";
		return;
	}
	
	
	if (!$ENV{rpc_xml_error}) {
		print "FAILURE: RPC-XML access is not configured correctly, view the log file for more information: $LOGFILE\n";
		return;
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
	
	return;
}

#/////////////////////////////////////////////////////////////////////////////

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

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
