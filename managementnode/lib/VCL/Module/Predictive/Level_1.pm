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
# $Id: Level_1.pm 1945 2008-12-11 20:58:08Z fapeeler $
##############################################################################

=head1 NAME

VCL::Module::Predictive::Level_1 - VCL predictive loading module for "Level 1" algorithm

=head1 SYNOPSIS

 use base qw(VCL::Module::Predictive::Level_1);

=head1 DESCRIPTION

 Needs to be written.

=cut

##############################################################################
package VCL::Module::Predictive::Level_1;

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
	if (ref($self) !~ /Level_1/) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method, process exiting");
		exit 1;
	}
	#notify($ERRORS{'WARNING'}, 0, "get_next_image_revision works!");

	# Retrieve variables from the DataStructure
	my $request_id          = $self->data->get_request_id();
	my $reservation_id      = $self->data->get_reservation_id();
	my $computer_id         = $self->data->get_computer_id();
	my $computer_short_name = $self->data->get_computer_short_name();

	my $notify_prefix = "predictive_reload_Level_1 :";

	notify($ERRORS{'OK'}, 0, "$notify_prefix starting predictive_reload_level_1 for $computer_id");

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

	# No upcoming reservations - determine most popular, unloaded image

	# determine state of system

	# get machine type
	my $select_type = "
    SELECT
    type
	 FROM
	  computer
	  WHERE
	  id = $computer_id
		 ";
	my @data = database_select($select_type);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my $type = $data[0]{type};

	# online machines
	my $select_online = "
	  SELECT
	  COUNT(id) as cnt
	  FROM
	  computer
	  WHERE
	  stateid IN (2, 3, 6, 8, 11)
	  AND type = '$type'
		  ";
	@data = database_select($select_online);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my $online = $data[0]{cnt};

	# available machines
	my $select_available = "
        SELECT
        COUNT(id) AS cnt
        FROM
        computer
        WHERE
        stateid = 2
        AND type = '$type'
        ";
	@data = database_select($select_available);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my $avail = $data[0]{cnt};

	# check if > 75% usage, look at past 2 days, otherwise, look at past 6 months
	my $timeframe;
	if (($avail / $online) > 0.75) {
		$timeframe = '2 DAY';
	}
	else {
		$timeframe = '6 MONTH';
	}

	# what images map to this computer
	my $select_mapped_images = "
        SELECT
        id
        FROM
        resource
        WHERE
        resourcetypeid = 12
        AND subid = $computer_id
        ";
	@data = database_select($select_mapped_images);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my $resourceid = $data[0]{id};

	my $select_compgrps1 = "
        SELECT
        resourcegroupid
        FROM
        resourcegroupmembers
        WHERE
        resourceid = $resourceid
        ";
	@data = database_select($select_compgrps1);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my @compgroups;
	foreach (@data) {
		my %row = %{$_};
		push(@compgroups, $row{resourcegroupid});
	}

	my $inlist = join(',', @compgroups);
	my $select_imggrps1 = "
        SELECT
        resourcegroupid2
        FROM
        resourcemap
        WHERE
        resourcetypeid1 = 12
        AND resourcegroupid1 IN ($inlist)
        AND resourcetypeid2 = 13
        ";
	@data = database_select($select_imggrps1);
	my @imggroups;
	foreach (@data) {
		my %row = %{$_};
		push(@imggroups, $row{resourcegroupid2});
	}
	my $select_imggrps2 = "
        SELECT
        resourcegroupid1
        FROM
        resourcemap
        WHERE
        resourcetypeid2 = 12
        AND resourcegroupid2 IN ($inlist)
        AND resourcetypeid1 = 13
        ";
	@data = database_select($select_imggrps2);
	foreach (@data) {
		my %row = %{$_};
		push(@imggroups, $row{resourcegroupid1});
	}
	if (scalar @imggroups == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}

	$inlist = join(',', @imggroups);
	my $select_imageids = "
        SELECT
        DISTINCT(r.subid)
        FROM
        image i,
        resource r,
        resourcegroupmembers rgm
        WHERE
        rgm.resourceid = r.id
        AND r.resourcetypeid = 13
        AND rgm.resourcegroupid IN ($inlist)
        AND r.subid = i.id
        AND i.deleted = 0
        ";
	my @imgids;
	@data = database_select($select_imageids);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	foreach (@data) {
		my %row = %{$_};
		push(@imgids, $row{subid});
	}

	# which of those are loaded
	$inlist = join(',', @imgids);
	my $select_loaded = "
        SELECT
        DISTINCT(currentimageid)
        FROM
        computer
        WHERE
        currentimageid IN ($inlist)
        AND stateid = 2";
	@data = database_select($select_loaded);
	my @loaded;
	foreach (@data) {
		my %row = %{$_};
		push(@loaded, $row{currentimageid});
	}

	# which of those are not loaded (find difference of @imagids and @loaded)
	my (@intersection, @notloaded, $element);
	@intersection = @notloaded = ();
	my %count = ();
	foreach $element (@imgids, @loaded) {$count{$element}++}
	foreach $element (keys %count) {
		push @{$count{$element} > 1 ? \@intersection : \@notloaded}, $element;
	}

	# get the most popular in $timeframe
	$inlist = join(',', @notloaded);
	my $select_imageid = "
        SELECT
        COUNT(imageid) AS cnt,
        imageid
        FROM
        log
        WHERE
        imageid IN ($inlist)
        AND start > (NOW() - INTERVAL $timeframe)
        GROUP BY imageid
        ORDER BY cnt DESC
        LIMIT 1
        ";
	@data = database_select($select_imageid);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}
	my $imageid = $data[0]{imageid};

	# get extra data about the image
	my $select_extra = "
        SELECT
        i.name,
        r.id
        FROM
        image i,
        imagerevision r
        WHERE
        i.id = $imageid
        AND r.imageid = $imageid
        AND r.production = 1
        ";
	@data = database_select($select_extra);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch preferred image for computer_id $computer_id");
		return 0;
	}


	notify($ERRORS{'OK'}, 0, "$notify_prefix $computer_id $data[0]{name}, $imageid, $data[0]{id}");
	push(@ret_array, $data[0]{name}, $imageid, $data[0]{id});
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
