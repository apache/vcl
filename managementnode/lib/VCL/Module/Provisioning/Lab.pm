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

VCL::Provisioning::Lab - VCL module to support povisioning of lab machines

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

###############################################################################
package VCL::Module::Provisioning::Lab;

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

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

=head2 load

 Parameters  : none
 Returns     : boolean
 Description : Checks if the lab computer is responding to SSH. If so, true is
               returned indicating the lab computer is ready to be reserved for
               a user. If it is not responding, false is returned. This should
               fail the request before the Connect button is presented to the
               user.

=cut

sub load {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $request_id = $self->data->get_request_id();
	my $request_check_time = $self->data->get_request_check_time();
	my $computer_name = $self->data->get_computer_node_name();
	
	# Check if this is a preload request
	if ($request_check_time eq 'preload') {
		update_preload_flag($request_id, 1) || return 0;
	}
	
	if ($self->os->is_ssh_responding()) {
		notify($ERRORS{'OK'}, 0, "$computer_name is responding to SSH, no additional steps need to be performed to provision lab computer during this stage");
		return 1;
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "unable to provision lab computer, $computer_name is NOT responding to SSH");
		return 0;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 node_status

 Parameters  : none
 Returns     : 'READY' or 'RELOAD'
 Description : Checks if the lab computer is responding to SSH. If so, 'READY'
               is returned. This prevents the need to call load(). If the
               computer is not responding, 'RELOAD' is returned which will
               result in load() being called.

=cut

sub node_status {
	my $self = shift;
	if (ref($self) !~ /VCL::Module/i) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $computer_name = $self->data->get_computer_node_name();
	
	if ($self->os->is_ssh_responding()) {
		notify($ERRORS{'OK'}, 0, "$computer_name is responding to SSH, returning 'READY'");
		return 'READY';
	}
	else {
		notify($ERRORS{'OK'}, 0, "$computer_name is NOT responding to SSH, returning 'RELOAD'");
		return 'RELOAD';
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 power_reset

 Parameters  : none
 Returns     : 1
 Description :

=cut

sub power_reset {
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 unload

 Parameters  : none
 Returns     : 0
 Description :

=cut

sub unload {
	return 0;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
