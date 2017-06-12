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

VCL::Module::Predictive::Level_1 - VCL predictive loading module for "Level 1" algorithm

=head1 SYNOPSIS

 use base qw(VCL::Module::Predictive::Level_1);

=head1 DESCRIPTION

 Needs to be written.

=cut

###############################################################################
package VCL::Module::Predictive::Level_1;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../../..";

# Configure inheritance
use base qw(VCL::Module::Predictive);

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English '-no_match_vars';

use VCL::utils;

###############################################################################

=head1 OBJECT METHODS

=cut

#//////////////////////////////////////////////////////////////////////////////

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
	
	# Retrieve variables from the DataStructure
	my $request_id           = $self->data->get_request_id();
	my $reservation_id       = $self->data->get_reservation_id();
	my $computer_id          = $self->data->get_computer_id();
	my $computer_short_name  = $self->data->get_computer_short_name();
	my $computer_nextimage_id = $self->data->get_computer_nextimage_id(0);
	
	my @ret_array;
	my $notify_prefix = "predictive_reload_Level_1 :";
	
	notify($ERRORS{'OK'}, 0, "$notify_prefix starting predictive_reload_level_1 for $computer_id");
	
	# Check if node is part of block reservation 
	if (is_inblockrequest($computer_id)) {
		notify($ERRORS{'DEBUG'}, 0, "computer id $computer_id is in blockComputers table");
		my @block_ret_array = get_block_request_image_info($computer_id);
		if (defined($block_ret_array[0]) && $block_ret_array[0]) {
			push(@ret_array, "reload", @block_ret_array);
			return @ret_array;
		}
		else {
			notify($ERRORS{'WARNING'}, 0, "computer $computer_id is part of blockComputers, failed to return image info"); 
		}
	}
	
	# If nextimageid set, set to default 0 and return the imageid
	if (defined($computer_nextimage_id) && $computer_nextimage_id) {
		#Get computer_nextimage_id info
		my $select_nextimage = " 
			SELECT DISTINCT
			imagerevision.imagename AS imagename,
			imagerevision.id AS imagerevisionid,
			image.id AS imageid
			FROM
			image,
			computer,
			imagerevision
			WHERE
			imagerevision.imageid = computer.nextimageid
			AND imagerevision.production = 1
			AND computer.nextimageid = image.id
			AND computer.id = $computer_id
			AND image.name NOT LIKE 'noimage'
		";
		
		
		my @next_selected_rows = database_select($select_nextimage);
		# Check to make sure at least 1 row were returned
		if (scalar @next_selected_rows == 0) {
			notify($ERRORS{'OK'}, 0, "$notify_prefix next image not set for computerid $computer_id");
		}   
		elsif (scalar @next_selected_rows > 1) {
			notify($ERRORS{'WARNING'}, 0, "" . scalar @next_selected_rows . " rows were returned from database select");
		}
		else {
			notify($ERRORS{'OK'}, 0, "$notify_prefix returning nextimage image=$next_selected_rows[0]{imagename} imageid=$next_selected_rows[0]{imageid}");
			my @next_image_ret_array;
			push (@next_image_ret_array, "reload", $next_selected_rows[0]{imagename}, $next_selected_rows[0]{imageid}, $next_selected_rows[0]{imagerevisionid});
			
			#Clear next_imageid
			if (!clear_next_image_id($computer_id)) {
				notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to clear next_image_id for computerid $computer_id");
			}
			return @next_image_ret_array;
		}
	}
	
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
	
	# Check to make sure 1 or more rows were returned
	if (scalar @selected_rows > 0) {
		# Loop through list of upcoming reservations
		# Based on the start time load the next one
		
		my $now = time();
		
		# It contains a hash
		for (@selected_rows) {
			my %reservation_row = %{$_};
			my $epoch_start = convert_to_epoch_seconds($reservation_row{starttime});
			my $diff = $epoch_start - $now;
			
			# If start time is less than 50 minutes from now return this image
			notify($ERRORS{'OK'}, 0, "$notify_prefix diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
			if ($diff < (50 * 60)) {
				notify($ERRORS{'OK'}, 0, "$notify_prefix future reservation detected diff= $diff image= $reservation_row{imagename} imageid=$reservation_row{imageid}");
				push(@ret_array, "reload", $reservation_row{imagename}, $reservation_row{imageid}, $reservation_row{imagerevisionid});
				return @ret_array;
			}
		} ## end for (@selected_rows)
	} ## end if (scalar @selected_rows > 0)
	
	# No upcoming reservations - determine most popular, unloaded image
	
	# determine state of system
	
	# get machine type
	my $select_type = "
		SELECT
		type,provisioningid
		FROM
		computer
		WHERE
		id = $computer_id
	";
	
	my @data = database_select($select_type);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to fetch provisioningid for computer_id $computer_id");
		return 0;
	}
	my $type = $data[0]{type};
	my $provisioningid = $data[0]{provisioningid};
	
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_online");
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_available");
		return 0;
	}
	
	my $avail = $data[0]{cnt};
	
	# check if > X% usage, look at past X days, otherwise, look at past 2 months
	my $timeframe;
	my $notavail = ($online - $avail);
	my $usage = ($notavail / $online);
	if ($usage > 0.40) {
		$timeframe = '1 DAY';
	}
	elsif ($usage > 0.35) {
		$timeframe = '2 DAY';
	}
	elsif ($usage > 0.30) {
		$timeframe = '3 DAY';
	}
	elsif ($usage > 0.25) {
		$timeframe = '4 DAY';
	}
	elsif ($usage > 0.20) {
		$timeframe = '5 DAY';
	}
	elsif ($usage > 0.15) {
		$timeframe = '10 DAY';
	}
	elsif ($usage > 0.10) {
		$timeframe = '20 DAY';
	}
	elsif ($usage > 0.05) {
		$timeframe = '30 DAY';
	}
	else {
		$timeframe = '2 MONTH';
	}
	
	notify($ERRORS{'OK'}, 0, "$notify_prefix computer_short_name= $computer_short_name type= $type");
	notify($ERRORS{'OK'}, 0, "$notify_prefix avail= $avail notavail= $notavail online= $online timeframe= $timeframe");
	
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_mapped_images");
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_compgrps1");
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_imggrps2");
		return 0;
	}
	
	$inlist = join(',', @imggroups);
	my $select_imageids = "
		SELECT
		DISTINCT(r.subid)
		FROM
		image i,
		OS o,
		resource r,
		resourcegroupmembers rgm,
		OSinstalltype osit,
		provisioningOSinstalltype posit
		WHERE
		rgm.resourceid = r.id
		AND r.resourcetypeid = 13
		AND rgm.resourcegroupid IN ($inlist)
		AND r.subid = i.id
		AND i.deleted = 0
		AND i.OSid = o.id
		AND o.installtype = osit.name
		AND osit.id = posit.OSinstalltypeid
		AND posit.provisioningid = $provisioningid
	";
	my @imgids;
	@data = database_select($select_imageids);
	if (scalar @data == 0) {
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_imageids");
		return 0;
	}
	foreach (@data) {
		my %row = %{$_};
		push(@imgids, $row{subid});
	}
	my $numselected_imagids = @imgids;
	notify($ERRORS{'OK'}, 0, "$notify_prefix $numselected_imagids available images can go on $computer_short_name");
	
	# which of those are loaded
	$inlist = join(',', @imgids);
	my $select_loaded = "
		SELECT
		DISTINCT(currentimageid),
		COUNT(currentimageid) AS count
		FROM
		computer
		WHERE
		currentimageid IN ($inlist)
		AND stateid = 2
		GROUP BY currentimageid
		HAVING count > 1
	";
	@data = database_select($select_loaded);
	my @loaded;
	foreach (@data) {
		my %row = %{$_};
		push(@loaded, $row{currentimageid});
	}
	my $already_loaded_once = @loaded;
	notify($ERRORS{'OK'}, 0, "$notify_prefix $already_loaded_once of $numselected_imagids available images loaded at least once");
	
	# which of those are not loaded (find difference of @imagids and @loaded)
	my (@intersection, @notloaded, $element);
	@intersection = @notloaded = ();
	my %count = ();
	foreach $element (@imgids, @loaded) {$count{$element}++}
	foreach $element (keys %count) {
		push @{$count{$element} > 1 ? \@intersection : \@notloaded}, $element;
	}
	
	my $not_loaded = @notloaded;
	notify($ERRORS{'OK'}, 0, "$notify_prefix $not_loaded of $numselected_imagids total images available for selection");
	
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_imageid");
		return 0;
	}
	my $imageid = $data[0]{imageid};
	
	notify($ERRORS{'OK'}, 0, "$notify_prefix  imageid= $imageid is most popular image during last $timeframe");
	
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
		notify($ERRORS{'WARNING'}, 0, "$notify_prefix failed to run query for computer_id $computer_id\n $select_extra");
		return 0;
	}
	
	notify($ERRORS{'OK'}, 0, "$notify_prefix $computer_id $data[0]{name}, $imageid, $data[0]{id}");
	push(@ret_array, "reload", $data[0]{name}, $imageid, $data[0]{id});
	return @ret_array;
} ## end sub get_next_image_revision

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
