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
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );

use VCL::utils;
use VCL::healthcheck;
use Getopt::Long;

#------- Subroutine declarations -------
sub main();
sub help_healthcheck();
sub print_usage(); 

#----------GLOBALS--------------
# Store the command line options in this hash
our %OPTIONS;

our $STAGE = 0;
our $HELP = 0;


#GetOptions(\%OPTIONS, 'help', 'powerdown=s');


# Get the remaining command line parameters
#$HELP = $OPTIONS{help} if (defined($OPTIONS{help} && $OPTIONS{help}));
#$STAGE = $OPTIONS{powerdown} if (defined($OPTIONS{powerdown} && $OPTIONS{powerdown}));

if ($STAGE) {

	unless($STAGE =~ /available|all/) {
		print "\nInvalid powerdown option\n\n";
		help;
		exit;
	}

}
if ($HELP) {
	help_healthcheck();
	exit;
}
##############################################################################

# now just do basic monitoring
# ping machine is it accessible by contact means for given type and is the client daemon running

=pod
    1) get my hostname, I should be a management node
    2) get groups associated groups which I (my MNid) can talk to/manage.
    3) from groups get resource members and their information i.e. computer info from the repective group
    
=cut


main();

sub main() {

	my $check = new VCL::healthcheck();
	$check->process($STAGE);
	#$check->send_report;

}
#/////////////////////////////////////////////////////////////////////////////

=head2 print_usage

 Parameters  : 
 Returns     : 
 Description :

=cut

sub print_usage() {

	my $text = sprintf("    %s \n", "Usage: healthcheck.pl  [options]" );
	$text .= sprintf("    %s \n"," ");
	$text .= sprintf("    %s \n", "healthcheck.pl  : without options scans nodes and" );
	$text .= sprintf("             %s \n", "resets data in database if needed" );
	$text .= sprintf("    %s \n"," ");
	$text .= sprintf("    %s \n","Valid options:");
	$text .= sprintf("    %s \n"," ");
	$text .= sprintf("    %s \n","-powerdown=ARG  : A power down argument can be one of");
	$text .= sprintf("           %s \n","available	shutdown available or idle blades");
	$text .= sprintf("           %s \n","all		shutdown all nodes, notify users of pending shutdown");

	print "$text\n";

} ## end sub help

#/////////////////////////////////////////////////////////////////////////////

=head2 help_healthcheck

 Parameters  : 
 Returns     : 
 Description :

=cut

sub help_healthcheck() {
	my $message = <<"END";
--------------------------------------------

health_check.pl is intented to as a cmdline script or via cron

END

	print $message;
	print_usage();
	exit;
} ## end sub help_healthcheck
#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
