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
# $Id: Level_0.pm 1945 2008-12-11 20:58:08Z fapeeler $
##############################################################################

=head1 NAME

VCL::Module::Predictive::Level_0 - VCL predictive loading module for "Level 0" algorithm

=head1 SYNOPSIS

 use base qw(VCL::Module::Predictive::Level_0);

=head1 DESCRIPTION

 Needs to be written.

=cut

##############################################################################
package VCL::Module::Predictive::Level_0;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Predictive);

# Specify the version of this module
our $VERSION = '2.00';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use VCL::utils;

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_next_image

 Parameters  : None. Must be called as an object method.
 Returns     :
 Description :

=cut

sub get_next_image {
	my $self = shift;
	if (ref($self) !~ /Level_0/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method, process exiting");
		exit 1;
	}
	#notify($ERRORS{'WARNING'}, 0, "get_next_image_revision works!");

	# Retrieve variables from the DataStructure
	my $request_id          = $self->data->get_request_id();
	my $reservation_id      = $self->data->get_reservation_id();
	my $computer_id         = $self->data->get_computer_id();
	my $computer_short_name = $self->data->get_computer_short_name();

	my $notify_prefix = "predictive_reload_Level_0: ";

	notify($ERRORS{'OK'}, 0, "$notify_prefix for $computer_id");

	my $select_statement = "
	SELECT DISTINCT
	req.start AS starttime,
	ir.imagename AS imagename,
	res.imagerevisionid AS imagerevisionid,
	res.imageid AS imageid
	FROM
	reservation res,
	request req,
	image i,
	state s,
	imagerevision ir
   WHERE
	res.requestid = req.id
	AND req.stateid = s.id
	AND i.id = res.imageid
	AND ir.id = res.imagerevisionid
	AND res.computerid = $computer_id
	AND (s.name = \'new\' OR s.name = \'reload\' OR s.name = \'imageprep\')
   ";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @selected_rows = database_select($select_statement);
	my @ret_array;

	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows > 0) {
		# Loop through list of upcoming reservations
		# Based on the start time load the next one

		my $now = time();

		# It contains a hash
		for (@selected_rows) {
			my %reservation_row = %{$_};
			# $reservation_row{starttime}
			# $reservation_row{imagename}
			# $reservation_row{imagerevisionid}
			# $reservation_row{imageid}
			my $epoch_start = convert_to_epoch_seconds($reservation_row{starttime});
			my $diff        = $epoch_start - $now;
			# If start time is less than 50 minutes from now return this image
			notify($ERRORS{'OK'}, 0, "$notify_prefix diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
			if ($diff < (50 * 60)) {
				notify($ERRORS{'OK'}, 0, "$notify_prefix future reservation detected diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
				push(@ret_array, $reservation_row{imagename}, $reservation_row{imageid}, $reservation_row{imagerevisionid});
				return @ret_array;
			}
		} ## end for (@selected_rows)
	} ## end if (scalar @selected_rows > 0)

	# No upcoming reservations - fetch preferred image information
	my $select_preferredimage = "
	SELECT DISTINCT
	imagerevision.imagename AS imagename,
	imagerevision.id AS imagerevisionid,
	image.id AS imageid
	FROM
	image,
	computer,
	imagerevision
   WHERE
	imagerevision.imageid = computer.preferredimageid
	AND imagerevision.production = 1
	AND computer.preferredimageid = image.id
	AND computer.id = $computer_id
	";

	# Call the database select subroutine
	# This will return an array of one or more rows based on the select statement
	my @preferred_selected_rows = database_select($select_preferredimage);

	# Check to make sure at least 1 row were returned
	if (scalar @preferred_selected_rows == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computerid $computer_id");
		return 0;
	}
	elsif (scalar @preferred_selected_rows > 1) {
		notify($ERRORS{'WARNING'}, 0, "" . scalar @preferred_selected_rows . " rows were returned from database select");
		return 0;
	}
	notify($ERRORS{'OK'}, 0, "$notify_prefix returning preferredimage image=$preferred_selected_rows[0]{imagename} imageid=$preferred_selected_rows[0]{imageid}");
	push(@ret_array, $preferred_selected_rows[0]{imagename}, $preferred_selected_rows[0]{imageid}, $preferred_selected_rows[0]{imagerevisionid});
	return @ret_array;

} ## end sub get_next_image_revision

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
