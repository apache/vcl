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
# $Id$
##############################################################################

=head1 NAME

VCL::Module - VCL base module

=head1 SYNOPSIS

 use base qw(VCL::Module);

=head1 DESCRIPTION

 Needs to be written.

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

use VCL::utils qw($VERBOSE %ERRORS &notify &getnewdbh);
use VCL::DataStructure;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 new

 Parameters  : {data_structure} - reference to a VCL::DataStructure object
 Returns     : New object which inherits from VCL::Provisioning
 Description : Constructor for classes of objects derived from
               VCL::Module::Provisioning.

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
		return 0;
	}

	# Make sure the 'data_structure' argument contains a VCL::DataStructure object
	if (ref $args->{data_structure} ne 'VCL::DataStructure') {
		notify($ERRORS{'CRITICAL'}, 0, "'data_structure' argument passed is not a reference to a VCL::DataStructure object");
		return 0;
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
		return 0 if (!$class_object->initialize());
	}

	return $class_object;
} ## end sub new

#/////////////////////////////////////////////////////////////////////////////

=head2 data

 Parameters  : None
 Returns     : Reference to the DataStructure object belonging to the class
               instance
 Description : This data() subroutine allows derived instances to easily
               retrieve data from the DataStructure as follows:
               my $image_id = $self->data->get_image_id;

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
