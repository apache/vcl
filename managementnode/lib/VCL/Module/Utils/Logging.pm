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

VCL::Module::Utils::Logging

=head1 SYNOPSIS

 Needs to be written

=head1 DESCRIPTION

 This module provides...

=cut

##############################################################################
package VCL::Module::Utils::Logging;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw();

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(
  &log_info
  &log_verbose
  &log_warning
  &log_critical
);

use VCL::utils qw(
  %ERRORS
  &notify
);

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2  log_info

 Parameters  :
 Returns     :
 Description :

=cut

sub log_info {
	my ($message, $data) = @_;
	notify($ERRORS{'OK'}, 0, $message, $data);
}

#/////////////////////////////////////////////////////////////////////////////

=head2  log_verbose

 Parameters  :
 Returns     :
 Description :

=cut

sub log_verbose {
	my ($message, $data) = @_;
	notify($ERRORS{'DEBUG'}, 0, $message, $data);
}

#/////////////////////////////////////////////////////////////////////////////

=head2  log_warning

 Parameters  :
 Returns     :
 Description :

=cut

sub log_warning {
	my ($message, $data) = @_;
	notify($ERRORS{'WARNING'}, 0, $message, $data);
}

#/////////////////////////////////////////////////////////////////////////////

=head2  log_critical

 Parameters  :
 Returns     :
 Description :

=cut

sub log_critical {
	my ($message, $data) = @_;
	notify($ERRORS{'CRITICAL'}, 0, $message, $data);
}

1;
