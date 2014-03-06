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

VCL::Module::Semaphore - VCL module to control semaphores

=head1 SYNOPSIS

 my $semaphore = VCL::Module::Semaphore->new({data_structure => $self->data});
 $semaphore->get_lockfile($semaphore_id, $total_wait_seconds, $attempt_delay_seconds);

=head1 DESCRIPTION

 A semaphore is used to ensure that only 1 process performs a particular task at
 a time. An example would be the retrieval of an image from another management
 node. If multiple reservations are being processed for the same image, each
 reservation may attempt to retrieve it via SCP at the same time. A
 VCL::Module::Semaphore can be used to only allow 1 process to retrieve the
 image. The others will wait until the semaphore is released by the retrieving
 process.

=cut

##############################################################################
package VCL::Module::Semaphore;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../..";

# Configure inheritance
use base qw(VCL::Module);

# Specify the version of this module
our $VERSION = '2.3';

# Specify the version of Perl to use
use 5.008000;

use strict;
use warnings;
use diagnostics;
use English qw( -no_match_vars );
use IO::File;
use Fcntl qw(:DEFAULT :flock);

use VCL::utils;

##############################################################################

=head1 CLASS VARIABLES

=cut

=head2 $LOCKFILE_DIRECTORY_PATH

 Data type   : String
 Description : Location on the management node of the lockfiles are stored.

=cut

our $LOCKFILE_DIRECTORY_PATH = "/tmp";

=head2 $LOCKFILE_EXTENSION

 Data type   : String
 Description : File extension to be used for lockfiles.

=cut

our $LOCKFILE_EXTENSION = "semaphore";

##############################################################################

=head1 OBJECT METHODS

=cut

#/////////////////////////////////////////////////////////////////////////////

=head2 get_lockfile

 Parameters  : $semaphore_id, $total_wait_seconds (optional), $attempt_delay_seconds (optional)
 Returns     : filehandle
 Description : Attempts to open and obtain an exclusive lock on the file
               specified by the file path argument. If unable to obtain an
               exclusive lock, it will wait up to the value specified by the
               total wait seconds argument (default: 30 seconds). The number of
               seconds to wait in between retries can be specified (default: 15
               seconds).

=cut

sub get_lockfile {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the semaphore ID argument
	my ($semaphore_id, $total_wait_seconds, $attempt_delay_seconds) = @_;
	if (!$semaphore_id) {
		notify($ERRORS{'WARNING'}, 0, "semaphore ID argument was not supplied");
		return;
	}
	
	$semaphore_id =~ s/\W+/-/g;
	$semaphore_id =~ s/(^-|-$)//g;
	
	my $file_path = "$LOCKFILE_DIRECTORY_PATH/$semaphore_id.$LOCKFILE_EXTENSION";
	
	# Set the wait defaults if not supplied as arguments
	$total_wait_seconds = 30 if !defined($total_wait_seconds);
	$attempt_delay_seconds = 5 if !$attempt_delay_seconds;
	
	# Attempt to lock the file
	my $wait_message = "attempting to open lockfile";
	if ($self->code_loop_timeout(\&open_lockfile, [$self, $file_path], $wait_message, $total_wait_seconds, $attempt_delay_seconds)) {
		return $file_path;
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "failed to open lockfile: $file_path");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 open_lockfile

 Parameters  : $file_path
 Returns     : If successful: IO::File file handle object
               If failed: false
 Description : Opens and obtains an exclusive lock on the file specified by the
               argument.

=cut

sub open_lockfile {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my ($file_path) = @_;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	
	# Attempt to open and lock the file
	if (my $file_handle = new IO::File($file_path, O_WRONLY|O_CREAT)) {
		if (flock($file_handle, LOCK_EX | LOCK_NB)) {
			notify($ERRORS{'DEBUG'}, 0, "opened and obtained an exclusive lock on file: $file_path");
			
			# Truncate and print the process information to the file
			$file_handle->truncate(0);
			print $file_handle "$$ $0\n";
			$file_handle->setpos($file_handle->getpos());
			 
			notify($ERRORS{'DEBUG'}, 0, "wrote to file: $file_path, contents:\n '$$ $0'");
			
			$self->{file_handles}{$file_path} = $file_handle;
			return $file_handle;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "unable to obtain exclusive lock on file: $file_path");
			$file_handle->close;
		}
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to open file: $file_path, error:\n$!");
		return;
	}
	
	# Run lsof to determine which process is locking the file
	my ($exit_status, $output) = run_command("/usr/sbin/lsof -Fp $file_path", 1);
	if (!defined($output)) {
		notify($ERRORS{'WARNING'}, 0, "failed to run losf command to determine which process is locking the file: $file_path");
		return;
	}
	elsif (grep(/no such file/i, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "losf command reports that the file does not exist: $file_path");
		return;
	}
	
	# Parse the lsof output to determine the PID
	my @locking_pids = map { /^p(\d+)/ } @$output;
	if (@locking_pids && grep { $_ eq $PID } @locking_pids) {
		# The current process already has an exclusive lock on the file
		# This could happen if open_lockfile is called more than once for the same file in the same scope
		notify($ERRORS{'WARNING'}, 0, "file is already locked by this process: @locking_pids");
		return;
	}
	elsif (@locking_pids) {
		# Attempt to retrieve the names of the locking process(es)
		my ($ps_exit_status, $ps_output) = run_command("ps -o pid=,cmd= @locking_pids", 1);
		if (defined($ps_output) && !grep(/(ps:)/, @$ps_output)) {
			notify($ERRORS{'DEBUG'}, 0, "file is locked by another process: @locking_pids\n" . join("\n", @$ps_output));
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "file is locked by another process: @locking_pids");
		}
		return;
	}
	elsif (grep(/\w/, @$output)) {
		notify($ERRORS{'WARNING'}, 0, "unable to determine PIDs from lsof output\n:" . join("\n", @$output));
	}
	else {
		notify($ERRORS{'DEBUG'}, 0, "lsof did not return any PIDs of processes which prevented an exclusive lock to be obtained, lock may have been released before lsof command was executed");
	}
	
	return 0;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 release_lockfile

 Parameters  : $file_path
 Returns     : boolean
 Description : Releases the exclusive lock and closes the lockfile handle
               specified by the argument.

=cut

sub release_lockfile {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	# Get the file path argument
	my $file_path = shift;
	if (!$file_path) {
		notify($ERRORS{'WARNING'}, 0, "file path argument was not supplied");
		return;
	}
	
	my $file_handle = $self->{file_handles}{$file_path};
	if (!$file_handle) {
		notify($ERRORS{'WARNING'}, 0, "file handle is not saved in this object for file path: $file_path");
		return;
	}
	
	# Make sure the file handle is opened
	my $fileno = $file_handle->fileno;
	if (!$fileno) {
		notify($ERRORS{'WARNING'}, 0, "file is not opened: $file_path");
	}
	
	# Close the file
	if (!close($file_handle)) {
		notify($ERRORS{'WARNING'}, 0, "failed to close file: $file_path, reason: $!");
	}
	
	# Delete the file
	if (unlink($file_path)) {
		notify($ERRORS{'DEBUG'}, 0, "deleted file: $file_path");
	}
	else {
		notify($ERRORS{'WARNING'}, 0, "failed to delete file: $file_path, reason: $!");
	}
	
	delete $self->{file_handles}{$file_path};
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_reservation_semaphore_ids

 Parameters  : $reservation_id
 Returns     : array
 Description : Returns the Semaphore IDs opened by the reservation specified by
               the argument. An empty list is returned if no Semaphores are
               open.

=cut

sub get_reservation_semaphore_ids {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $reservation_id = shift || $self->data->get_reservation_id();
	if (!$reservation_id) {
		notify($ERRORS{'WARNING'}, 0, "reservation ID argument was not supplied");
		return;
	}
	
	my @lockfile_paths = $self->mn_os->find_files($LOCKFILE_DIRECTORY_PATH, "*.$LOCKFILE_EXTENSION");
	if (!@lockfile_paths) {
		notify($ERRORS{'DEBUG'}, 0, "did not find any lockfiles on this management node");
		return ();
	}
	
	my @reservation_semaphore_ids;
	
	for my $lockfile_path (@lockfile_paths) {
		my ($semaphore_id) = $lockfile_path =~ /([^\/]+)\.$LOCKFILE_EXTENSION/;
		
		my @lockfile_contents = $self->mn_os->get_file_contents($lockfile_path);
		if (!@lockfile_contents) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of lockfile: $lockfile_path");
			next;
		}
		
		my $lockfile_line = $lockfile_contents[0];
		
		# Line should contain a string similar to this:
		# 31862 vclark 2376:3116 tomaintenance vclv1-42>vclh3-12.hpc.ncsu.edu vmwarewinxp-base234-v14 admin
		my ($lockfile_reservation_id) = $lockfile_line =~ / \d+:(\d+) /;
		
		if (!defined($lockfile_reservation_id)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine reservation ID from 1st line in $lockfile_path: '$lockfile_line'");
			next;
		}
		
		if ($lockfile_reservation_id == $reservation_id) {
			notify($ERRORS{'DEBUG'}, 0, "semaphore '$semaphore_id' belongs to reservation $reservation_id");
			push @reservation_semaphore_ids, $semaphore_id;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "semaphore '$semaphore_id' does NOT belong to reservation $reservation_id");
		}
	}
	return @reservation_semaphore_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 get_process_semaphore_ids

 Parameters  : $pid
 Returns     : array
 Description : Returns the Semaphore IDs opened by the process PID specified by
               the argument. An empty list is returned if no Semaphores are
               open.

=cut

sub get_process_semaphore_ids {
	my $self = shift;
	unless (ref($self) && $self->isa('VCL::Module')) {
		notify($ERRORS{'CRITICAL'}, 0, "subroutine was called as a function, it must be called as a class method");
		return;
	}
	
	my $pid = shift;
	if (!$pid) {
		notify($ERRORS{'WARNING'}, 0, "process PID argument was not supplied");
		return;
	}
	
	my @lockfile_paths = $self->mn_os->find_files($LOCKFILE_DIRECTORY_PATH, "*.$LOCKFILE_EXTENSION");
	if (!@lockfile_paths) {
		notify($ERRORS{'DEBUG'}, 0, "did not find any lockfiles on this management node");
		return ();
	}
	
	my @process_semaphore_ids;
	
	for my $lockfile_path (@lockfile_paths) {
		my ($semaphore_id) = $lockfile_path =~ /([^\/]+)\.$LOCKFILE_EXTENSION/;
		
		my @lockfile_contents = $self->mn_os->get_file_contents($lockfile_path);
		if (!@lockfile_contents) {
			notify($ERRORS{'WARNING'}, 0, "failed to retrieve contents of lockfile: $lockfile_path");
			next;
		}
		
		my $lockfile_line = $lockfile_contents[0];
		
		# Line should contain a string similar to this:
		# 31862 vclark 2376:3116 tomaintenance vclv1-42>vclh3-12.hpc.ncsu.edu vmwarewinxp-base234-v14 admin
		my ($lockfile_pid) = $lockfile_line =~ /^(\d+) /;
		
		if (!defined($lockfile_pid)) {
			notify($ERRORS{'WARNING'}, 0, "failed to determine PID from 1st line in $lockfile_path: '$lockfile_line'");
			next;
		}
		
		if ($lockfile_pid == $pid) {
			notify($ERRORS{'DEBUG'}, 0, "semaphore '$semaphore_id' belongs to process $pid");
			push @process_semaphore_ids, $semaphore_id;
		}
		else {
			notify($ERRORS{'DEBUG'}, 0, "semaphore '$semaphore_id' does NOT belong to process $pid");
		}
	}
	return @process_semaphore_ids;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 DESTROY

 Parameters  : none
 Returns     : nothing
 Description : Destroys the semaphore object. The files opened and exclusively
               locked by the semaphore object are closed and deleted.

=cut

sub DESTROY {
	my $self = shift;
	my $address = sprintf('%x', $self);
	
	for my $file_path (keys %{$self->{file_handles}}) {
		$self->release_lockfile($file_path);
	}
	
	# Check for an overridden destructor
	$self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
	
	notify($ERRORS{'DEBUG'}, 0, "destroyed Semaphore object, memory address: $address");
} ## end sub DESTROY

#/////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut
