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

VCL::Module::OS::Windows_mod::Version_5::XP_mod.pm - VCL module to support Windows XP operating system

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows XP.

=cut

##############################################################################
package VCL::Module::OS::Windows_mod::Version_5::XP_mod;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows_mod::Version_5);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use File::Basename;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
					directory under the 'tools' directory specific to this OS.

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_XP";

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 pre_capture

 Parameters  :
 Returns     :
 Description :

=cut

sub pre_capture {
	my $self = shift;
	my $args = shift;
	if (ref($self) !~ /windows/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $imagemeta_sysprep = $self->data->get_imagemeta_sysprep();
	
	# Check if end_state argument was passed
	if (defined $args->{end_state}) {
		$self->{end_state} = $args->{end_state};
	}
	else {
		$self->{end_state} = 'off';
	}
	
	notify($ERRORS{'OK'}, 0, "beginning Windows XP image capture preparation tasks, end state: $self->{end_state}");
	
	# Call parent class's pre_capture() subroutine
	notify($ERRORS{'OK'}, 0, "calling parent class pre_capture() subroutine");
	if ($self->SUPER::pre_capture()) {
		notify($ERRORS{'OK'}, 0, "successfully executed parent class pre_capture() subroutine");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return 0;
	}
	
	# Copy the capture configuration files to the computer (scripts, utilities, drivers...)
	if (!$self->copy_capture_configuration_files($SOURCE_CONFIGURATION_DIRECTORY)) {
		notify($ERRORS{'WARNING'}, 0, "capture preparation failed, unable to copy XP-specific capture configuration files");
		return 0;
	}
	
	# Check if Sysprep should be used
	if ($imagemeta_sysprep) {
		# Copy the Sysprep files to C:\Sysprep
		# Call this *AFTER* calling copy_capture_configuration_files
		if (!$self->run_sysprep()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run Sysprep");
			return 0;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub pre_capture

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
