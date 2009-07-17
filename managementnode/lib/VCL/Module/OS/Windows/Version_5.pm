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

VCL::Module::OS::Windows::Version_5.pm - VCL module to support Windows 5.x operating systems

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides VCL support for Windows version 5.x operating systems.
 Version 5.x Windows OS's include Windows XP and Windows Server 2003.

=cut

##############################################################################
package VCL::Module::OS::Windows::Version_5;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../..";

# Configure inheritance
use base qw(VCL::Module::OS::Windows);

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

=head1 INTERFACE OBJECT METHODS

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
	
	notify($ERRORS{'OK'}, 0, "beginning Windows version 5 image capture preparation tasks");
	
	# Defragment the hard drive
	# Do this in Version_5.pm because defrag works well enough on XP and 2003
	# Version 6 OS's (Vista) take a very long time to run defrag
	if (!$self->defragment_hard_drive()) {
		notify($ERRORS{'WARNING'}, 0, "unable to defragment the hard drive");
	}

	# Call parent class's pre_capture() subroutine
	notify($ERRORS{'OK'}, 0, "calling parent class pre_capture() subroutine");
	if ($self->SUPER::pre_capture($args)) {
		notify($ERRORS{'OK'}, 0, "successfully executed parent class pre_capture() subroutine");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to execute parent class pre_capture() subroutine");
		return 0;
	}
	
	# Check if Sysprep should be used
	if ($self->data->get_imagemeta_sysprep()) {
		if (!$self->run_sysprep()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run Sysprep");
			return;
		}
	}
	else {
		if (!$self->prepare_post_load()) {
			notify($ERRORS{'WARNING'}, 0, "capture preparation failed, failed to run prepare post_load");
			return;
		}
	}
	
	notify($ERRORS{'OK'}, 0, "returning 1");
	return 1;
} ## end sub pre_capture

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
