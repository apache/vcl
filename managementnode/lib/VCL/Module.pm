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
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use VCL::utils qw($VERBOSE %ERRORS &notify &getnewdbh format_data);
use VCL::DataStructure;

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

	notify($ERRORS{'DEBUG'}, 0, "constructor called, class=$class");

	# Create a variable to store the newly created class object
	my $class_object;

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
	$class_object->{data} = $args->{data_structure};

	# Bless the object as the class which new was called with
	bless $class_object, $class;
	notify($ERRORS{'DEBUG'}, 0, "$class object created");

	# Check if an initialize() subroutine is defined for this module
	if ($class_object->can("initialize")) {
		# Call the initialize() subroutine, if it returns 0, return 0
		# If it doesn't return 0, return the object reference
		return if (!$class_object->initialize($args));
	}

	return $class_object;
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
               my $os = VCL::Module::OS::Windows_mod::Version_5::XP_mod->new({data_structure => $self->data});
               my @packages = $os->get_package_hierarchy();
               
               Example: call as class function:
               my @packages = get_package_hierarchy("VCL::Module::OS::Windows_mod::Version_5::XP_mod");
               
               Both examples return the following array:
               [0] = 'VCL::Module::OS::Windows_mod::Version_5::XP_mod'
               [1] = 'VCL::Module::OS::Windows_mod::Version_5'
               [2] = 'VCL::Module::OS::Windows_mod'
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

1;
__END__

=head1 AUTHOR

 Aaron Peeler <aaron_peeler@ncsu.edu>
 Andy Kurth <andy_kurth@ncsu.edu>

=head1 COPYRIGHT

 Apache VCL incubator project
 Copyright 2009 The Apache Software Foundation
 
 This product includes software developed at
 The Apache Software Foundation (http://www.apache.org/).

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
