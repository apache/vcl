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

VCL::Module::OS::Windows::Version_10::2016.pm - VCL module to support deployment of Windows Server 2016 operating systems

=head1 DESCRIPTION

 This module provides support for the deployment of Windows Server 2016 operating systems.

=cut

###############################################################################
package VCL::Module::OS::Windows::Version_10::2016;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../../../..";

# Configure inheritance
# Use the Windows 8 module for the time being - no changes are necessary
use base qw(VCL::Module::OS::Windows::Version_6::8);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;

use VCL::utils;

###############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $SOURCE_CONFIGURATION_DIRECTORY

 Data type   : Scalar
 Description : Location on management node of script/utilty/configuration
               files needed to configure the OS. This is normally the
               directory under the 'tools' directory specific to this OS. For
               Windows Server 2016, the directory is:
               tools/Windows_Server_2016

=cut

our $SOURCE_CONFIGURATION_DIRECTORY = "$TOOLS/Windows_Server_2016";

###############################################################################

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
