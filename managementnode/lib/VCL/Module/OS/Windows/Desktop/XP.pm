#!/usr/bin/perl -w
##############################################################################
# $Id$
##############################################################################

=head1 NAME

VCL::Module::OS::Windows::Desktop::XP

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::OS::Windows::Desktop::XP;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows::Desktop);

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

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2004-2008 by NC State University. All Rights Reserved.

 Virtual Computing Laboratory
 North Carolina State University
 Raleigh, NC, USA 27695

 For use license and copyright information see LICENSE and COPYRIGHT files
 included in the source files.

=cut
