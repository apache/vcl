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
# $Id: health_check.pl 1951 2008-12-12 13:48:10Z arkurth $
##############################################################################

=head1 NAME

VCL::health_check - VCL health check utility

=head1 SYNOPSIS

 perl VCL::health_check

=head1 DESCRIPTION

 Needs to be written...

=cut

##############################################################################
package VCL::health_check;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../lib";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;
use VCL::healthcheck;

##############################################################################

# now just do basic monitoring
# ping machine is it accessible by contact means for given type and is the client daemon running

=pod
    1) get my hostname, I should be a management node
    2) get groups associated groups which I (my MNid) can talk to/manage.
    3) from groups get resource members and their information i.e. computer info from the repective group
    
=cut

#----------GLOBALS--------------

#------- Subroutine declarations -------
sub main();

main();

sub main() {

	my $check = new VCL::healthcheck();
	$check->process;
	$check->send_report;

}
