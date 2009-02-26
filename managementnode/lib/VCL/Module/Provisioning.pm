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
# $Id: Provisioning.pm 1953 2008-12-12 14:23:17Z arkurth $
##############################################################################

=head1 NAME

VCL::Module::Provisioning - VCL provisioning base module

=head1 SYNOPSIS

 use base qw(VCL::Module::Provisioning);

=head1 DESCRIPTION

 Needs to be written.

=cut

##############################################################################
package VCL::Module::Provisioning;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../..";

# Configure inheritance
use base qw(VCL::Module);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 set_os

 Parameters  : None
 Returns     : Process's OS object
 Description : Sets the OS object for the provisioner module to access.

=cut

sub set_os {
	my $self = shift;
	my $os = shift;
	$self->{os} = $os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 os

 Parameters  : None
 Returns     : Process's OS object
 Description : Allows provisioning modules to access the reservation's OS
               object.

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
