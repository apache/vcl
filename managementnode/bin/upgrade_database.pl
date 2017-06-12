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

VCL::vcld - VCL upgrade_database

=head1 SYNOPSIS

 perl ./upgrade_database.pl

=head1 DESCRIPTION
 

=cut

##############################################################################
package VCL::upgrade_database;
use strict;
use warnings;

# Specify the lib path using FindBin
use FindBin;
use lib "$FindBin::Bin/../lib";

# Specify the version of this module
our $VERSION = '2.5';

# Specify the version of Perl to use
use 5.008000;

use Cwd qw(abs_path);
use File::Basename qw(fileparse);
use File::Temp qw(tempfile);
use Getopt::Long;
use Storable qw(store retrieve);

use VCL::utils;
use VCL::Module;


##############################################################################

my $DEBUG = 0;
GetOptions(\%OPTIONS,
	'debug!' => \$DEBUG,
);

$| = 1;

$VERBOSE = 1;
$DAEMON_MODE = 0;

my $DATABASE_SERVER = $SERVER;
my $DATABASE_USERNAME = $WRTUSER;
my $DATABASE_PASSWORD = $WRTPASS;

my $RENAME_COLUMNS = {
	'vmprofile' => {
		'eth0generated' => 'vmware_mac_eth0_generated',
		'eth1generated' => 'vmware_mac_eth1_generated',
	}
};

my $VCL_SCHEMA_PATHS = {
	'vclimport' => 'https://svn.apache.org/repos/asf/vcl/tags/import/mysql/vcl.sql',
	'vcl20'     => 'https://svn.apache.org/repos/asf/vcl/tags/VCL-2.0.0/mysql/vcl.sql',
	'vcl21'     => 'https://svn.apache.org/repos/asf/vcl/tags/release-2.1/mysql/vcl.sql',
	'vcl22'     => 'https://svn.apache.org/repos/asf/vcl/tags/release-2.2/mysql/vcl.sql',
	'vcl23'     => 'https://svn.apache.org/repos/asf/vcl/tags/release-2.3/mysql/vcl.sql',
	'vcl231'    => 'https://svn.apache.org/repos/asf/vcl/tags/release-2.3.1/mysql/vcl.sql',
	'vcltrunk'  => 'https://svn.apache.org/repos/asf/vcl/trunk/mysql/vcl.sql',
};

my $timestamp = convert_to_datetime();
$timestamp =~ s/:/-/g;
$timestamp =~ s/\s/_/g;

#------------------------------------------------------------------------------

# Preliminary checks
if (!get_mn_os()) {
	setup_print_error("Failed to initialize object to interact with this management node's operating system. Check log file for more information:\n" . abs_path($LOGFILE));
	exit 1;
}

setup();

#create_test_databases() || exit;
#upgrade_test_databases() || exit;

exit;

#/////////////////////////////////////////////////////////////////////////////

=head2 get_mn_os

 Parameters  : none
 Returns     : OS module object reference
 Description : Retrieves an OS module object used to interact with the
               management node.

=cut

sub get_mn_os {
	if (defined($ENV{mn_os})) {
		return $ENV{mn_os};
	}
	
	# Create an OS object to control this management node
	my $mn_os = VCL::Module::create_mn_os_object();
	if (!$mn_os) {
		setup_print_error("failed to create OS object to control this management node");
		exit 1;
	}
	$ENV{mn_os} = $mn_os;
	return $mn_os;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 verify_vcl_sql_file

 Parameters  : $source_sql_file_path
 Returns     : boolean
 Description : Performs various checks on an SQL file used to upgrade a VCL
               database. The file must:
               - exist
               - be named 'vcl.sql'
               - contain a 'Version:' line
               - the version line must match the $VERSION variable of this
                 script

=cut

sub verify_vcl_sql_file {
	my ($source_sql_file_path) = @_;
	if (!$source_sql_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source VCL SQL file path argument was not supplied");
		return;
	}
	
	my $mn_os = get_mn_os();
	
	if ($source_sql_file_path !~ m|/vcl.sql$|) {
		setup_print_warning("file must be named vcl.sql");
		return;
	}
	
	if (!$mn_os->file_exists($source_sql_file_path)) {
		setup_print_warning("file does not exist: $source_sql_file_path");
		return;
	}
	
	my @lines = $mn_os->get_file_contents($source_sql_file_path);
	if (!@lines) {
		setup_print_error("unable to retrieve contents of file: $source_sql_file_path");
		return;
	}
	
	#-- Version: x.x
	my ($version_line) = grep(/--\s+Version:/, @lines);
	if (!$version_line) {
		setup_print_error("unable to verify file: $source_sql_file_path, it does not contain a 'Version:' line");
		return;
	}
	
	my ($version) = $version_line =~ /Version:\s+([\d\.]+)/s;
	if (!$version) {
		setup_print_error("unable to verify file: $source_sql_file_path, version line could not be parsed:\n$version_line");
		return;
	}
	elsif ($version ne $VERSION) {
		setup_print_error("unable to verify file: $source_sql_file_path, version inside the file '$version' does not match the version of this script '$VERSION'");
		return;
	}
	
	print "verified VCL $VERSION database schema file: $source_sql_file_path\n";
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_database

 Parameters  : $database_name
 Returns     : boolean
 Description : Creates a database using the credentials and database server
               specified in vcld.conf.

=cut

sub create_database {
	my ($database_name) = @_;
	if (!$database_name) {
		notify($ERRORS{'WARNING'}, 0, "database name argument was not specified");
		return;
	}
	
	print "attempting to create '$database_name' database on $DATABASE_SERVER\n";
	
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("unable to create database, failed to retrieve OS object to control this management node");
		return;
	}
	
	my $command = "mysql -h $DATABASE_SERVER -u $DATABASE_USERNAME --password='$DATABASE_PASSWORD' -e 'CREATE DATABASE $database_name;'";
	my ($exit_status, $output) = $mn_os->execute($command);
	if (!defined($output)) {
		setup_print_error("failed to execute command to create database on $DATABASE_SERVER: $command");
		return;
	}
	
	# Check for access denied error:
	# ERROR 1044 (42000) at line 1: Access denied for user '<username>'@'<IP address>' to database '<database name>'
	elsif (my ($access_denied_line) = grep(/Access denied/i, @$output)) {
		setup_print_error("failed to create '$database_name' database on database server $DATABASE_SERVER because the database user does not have the CREATE privilege.");
		my ($username, $source_host) = $access_denied_line =~ /'([^']+)'\@'([^']+)'/;
		if ($username && $source_host) {
			print "\nexecute the following command on the database server:\n";
			print "mysql -e \"GRANT CREATE ON *.* TO '$username'\@'$source_host';\"\n";
		}
		return;
	}
	
	# Check for database already exists error
	# ERROR 1007 (HY000) at line 1: Can't create database '<database name>'; database exists
	elsif (grep(/database exists/i, @$output)) {
		setup_print_error("failed to create '$database_name' database on $DATABASE_SERVER because a database with this name already exists");
		return 0;
	}
	
	elsif ($exit_status != 0 || grep(/ERROR/i, @$output)) {
		setup_print_error("failed to create '$database_name' database on $DATABASE_SERVER, exit status: $exit_status, output:\n" . join("\n", @$output) . "");
		return 0;
	}
	else {
		print "created '$database_name' database on $DATABASE_SERVER\n";
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 drop_database

 Parameters  : $database_name
 Returns     : boolean
 Description : Drops a database using the credentials and database server
               specified in vcld.conf.

=cut

sub drop_database {
	my ($database_name) = @_;
	if (!$database_name) {
		notify($ERRORS{'WARNING'}, 0, "database name argument was not specified");
		return;
	}
	
	print "attempting to drop '$database_name' database on $DATABASE_SERVER\n";
	
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("unable to drop database, failed to retrieve OS object to control this management node");
		return;
	}
	
	my $command = "mysql -h $DATABASE_SERVER -u $DATABASE_USERNAME --password='$DATABASE_PASSWORD' -e 'drop DATABASE $database_name'";
	my ($exit_status, $output) = $mn_os->execute($command);
	if (!defined($output)) {
		setup_print_error("failed to execute command to drop database on $DATABASE_SERVER: $command");
		return;
	}
	# Check for access denied error:
	# ERROR 1044 (42000) at line 1: Access denied for user '<username>'@'<IP address>' to database '<database>'
	elsif (my ($access_denied_line) = grep(/Access denied/i, @$output)) {
		setup_print_error("failed to drop '$database_name' database on database server $DATABASE_SERVER because the database user does not have the DROP privilege.");	
		my ($username, $source_host) = $access_denied_line =~ /'([^']+)'\@'([^']+)'/;
		if ($username && $source_host) {
			print "\nexecute the following command on the database server:\n";
			print "mysql -e \"GRANT DROP ON $database_name.* TO '$username'\@'$source_host';\"\n";
		}
		return;
	}
	#ERROR 1008 (HY000) at line 1: Can't drop database 'vcl_import'; database doesn't exist
	elsif (grep(/ERROR 1008/i, @$output)) {
		print "'$database_name' database does not exist on database server $DATABASE_SERVER\n";
		return 1;
	}
	
	else {
		print "dropped '$database_name' database on $DATABASE_SERVER\n";
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 import_sql_file

 Parameters  : $database_name, $sql_file_path
 Returns     : boolean
 Description : Imports an SQL file into a database.

=cut

sub import_sql_file {
	my ($database_name, $sql_file_path) = @_;
	if (!$database_name || !$sql_file_path) {
		notify($ERRORS{'WARNING'}, 0, "database name and SQL file path arguments were not specified");
		return;
	}
	
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("unable to import SQL file, failed to retrieve OS object to control this management node");
		return;
	}
	
	my $command = "mysql -h $DATABASE_SERVER -u $DATABASE_USERNAME --password='$DATABASE_PASSWORD' $database_name < $sql_file_path";
	print "attempting to import $sql_file_path into '$database_name' database\n";
	my ($exit_status, $output) = $mn_os->execute($command);
	if (!defined($output)) {
		setup_print_error("failed to execute command to import $sql_file_path into '$database_name' database on $DATABASE_SERVER");
		print "command:\n$command\n";
		return;
	}
	elsif ($exit_status != 0 || grep(/ERROR/i, @$output)) {
		setup_print_error("failed to import import $sql_file_path into '$database_name' database on $DATABASE_SERVER, output:");
		print join("\n", @$output) . "\n";
		return 0;
	}
	else {
		print "imported $sql_file_path into '$database_name' database\n";
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 create_test_databases

 Parameters  : @database_keys (optional)
 Returns     : boolean
 Description :

=cut

sub create_test_databases {
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("failed to retrieve OS object to control this management node");
		return;
	}
	
	my @database_keys = @_;
	if (!@database_keys) {
		@database_keys = keys %$VCL_SCHEMA_PATHS
	}
	
	for my $database_name (@database_keys) {
		setup_print_break();
		print "creating test database: $database_name\n\n";
		
		my $sql_file_url = $VCL_SCHEMA_PATHS->{$database_name};
		my $sql_temp_file_path = '/tmp/vcl.sql';
		my $sql_file_path = "/tmp/$database_name.sql";
		
		if ($mn_os->file_exists($sql_file_path)) {
			$mn_os->delete_file($sql_file_path);
		}
		
		print "downloading VCL schema file: $sql_file_url\n";
		
		my $wget_command = "wget -N -P /tmp $sql_file_url";
		my ($wget_exit_status, $wget_output) = $mn_os->execute($wget_command);
		if (!defined($wget_output)) {
			setup_print_error("failed to execute command to download VCL schema file: $wget_command");
			return;
		}
		elsif ($wget_exit_status ne '0') {
			setup_print_error("failed to download VCL schema file, exit status: $wget_exit_status\n");
			print "command: $wget_command\n";
			print "output:\n" . join("\n", @$wget_output) . "\n";
			return;
		}
		else {
			print "downloaded VCL schema file: $sql_file_url --> $sql_temp_file_path\n";
		}
		
		if ($mn_os->move_file($sql_temp_file_path, $sql_file_path)) {
			print "renamed file: $sql_temp_file_path --> $sql_file_path\n";
		}
		else {
			setup_print_error("failed to rename file: $sql_temp_file_path --> $sql_file_path");
			return;
		}
		
		print "\n";
		if (!drop_database($database_name)) {
			return;
		}
		
		print "\n";
		if (!create_database($database_name)) {
			return;
		}
		
		print "\n";
		if (!import_sql_file($database_name, $sql_file_path)) {
			return;
		}
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 upgrade_test_databases

 Parameters  : $reference_sql_file_path, @database_keys (optional)
 Returns     : boolean
 Description :

=cut

sub upgrade_test_databases {
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("failed to retrieve OS object to control this management node");
		return;
	}
	
	my ($reference_sql_file_path, @database_keys) = @_;
	if (!$reference_sql_file_path) {
		setup_print_error("reference SQL file path argument was not provided");
		return;
	}
	
	if (!@database_keys) {
		@database_keys = keys %$VCL_SCHEMA_PATHS
	}
	
	my $dumped_trunk = 0;
	my @diff_commands;
	my @diff_sort_file_paths;
	for my $database_name ('vcltrunk', @database_keys) {
		if ($database_name eq 'vcltrunk' && $dumped_trunk) {
			next;
		}
		
		setup_print_break();
		
		if ($database_name ne 'vcltrunk') {
			print "upgrading test database: $database_name\n";
			setup_upgrade_database($database_name, $reference_sql_file_path) || return;
			print "upgraded test database: $database_name\n";
		}
		
		my $database_dump_sql_file_path = "/tmp/$database_name\_dump.sql";
		dump_database_to_file($database_name, $database_dump_sql_file_path, '--no-data');
		
		# Remove comments from dumped file - makes it easier to diff
		`sed -i 's/\\/\\*.*//' $database_dump_sql_file_path`;
		`sed -i 's/AUTO_INCREMENT=[0-9]* //' $database_dump_sql_file_path`;
		
		`sort $database_dump_sql_file_path > $database_dump_sql_file_path.sort`;
		`sed -i -e 's/,\$//' $database_dump_sql_file_path.sort`;
		`sed -i -e 's/^USE.*//' $database_dump_sql_file_path.sort`;
		`sed -i -e 's/^mysqldump.*//' $database_dump_sql_file_path.sort`;
		
		if ($database_name eq 'vcltrunk') {
			$dumped_trunk = 1;
			next;
		}
		
		my $diff_file_path = "$database_dump_sql_file_path.diff";
		my $diff_command = "diff -W 200 -w -B --side-by-side --suppress-common-lines $database_dump_sql_file_path /tmp/vcltrunk_dump.sql";
		push @diff_commands, $diff_command,
		`$diff_command > $diff_file_path`;
		
		my $sort_diff_command = "diff -W 200 -w -B --side-by-side --suppress-common-lines $database_dump_sql_file_path.sort /tmp/vcltrunk_dump.sql.sort";
		push @diff_commands, $sort_diff_command,
		`$sort_diff_command > $diff_file_path.sort`;
		push @diff_sort_file_paths, "$diff_file_path.sort";
	}
	
	print join("\n", @diff_commands) . "\n\n";
	
	for my $diff_sort_file_path (@diff_sort_file_paths) {
		print "\n$diff_sort_file_path\n";
		print `cat $diff_sort_file_path`;
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_sql_file

 Parameters  : $sql_file_path
 Returns     : hash reference
 Description : Parses the statements in an SQL file and generates a hash.

=cut

sub parse_sql_file {
	my ($sql_file_path) = @_;
	if (!$sql_file_path) {
		notify($ERRORS{'WARNING'}, 0, "source VCL SQL file path argument was not supplied");
		return;
	}
	
	my $mn_os = get_mn_os();
	
	# Get the contents of the .sql file
	my $sql_string = $mn_os->get_file_contents($sql_file_path);
	if (!$sql_string) {
		setup_print_error("Failed to retrieve contents of SQL file: $sql_file_path");
		return;
	}
	
	print "Parsing SQL file: $sql_file_path\n";
	
	# Remove comments
	$sql_string =~ s/^--.*[\r\n]+//mg;
	$sql_string =~ s/^#.*//mg;
	
	my $comment_regex = '
		(
			/\*				(?# Beginning of comment)
				(?:
					[^*]		(?# Match anything other than a *)
					|
					[*][^/]	(?# Match * only if not followed by a /)
				)*
			\*/[\s;]*		(?# End of comment)
		)
	';
	$sql_string =~ s/$comment_regex//sxg;
	
	my $sql_info = {};
	
	my @insert_statements;
	$sql_info->{CREATE_TABLE} = {};
	$sql_info->{ALTER_TABLE} = {};
	$sql_info->{INSERT} = [];
	
	my @statements = split(/;\n/, $sql_string);
	my $statement_count = scalar(@statements);
	for (my $i=0; $i<$statement_count; $i++) {
		my $statement = $statements[$i];
		
		# Collapse statement into a single line
		$statement =~ s/\n/ /gs;
		
		# Remove any spaces from the beginning of the statement and consecutive spaces
		$statement =~ s/(^|\s)\s+/$1/gs;
		
		if ($statement =~ /^CREATE TABLE/ ) {
			my $create_table = parse_create_table_statement($statement) || return;
			$sql_info->{CREATE_TABLE} = {%{$sql_info->{CREATE_TABLE}}, %$create_table};
		}
		elsif ($statement =~ /^ALTER TABLE/ ) {
			my $alter_table_info = parse_alter_table_statement($statement);
			if (!$alter_table_info) {
				setup_print_error("failed to parse ALTER TABLE statement:");
				print "$statement\n";
				return;
			}
			
			#setup_print_break();
			#print format_data($alter_table_info) . "\n\n";
			
			# Merge info with previously retrieved ALTER TABLE info
			for my $table_name (keys %$alter_table_info) {
				for my $statement_type (keys %{$alter_table_info->{$table_name}}) {
					for my $key (keys %{$alter_table_info->{$table_name}{$statement_type}}) {
						if (!defined($sql_info->{ALTER_TABLE}{$table_name}{$statement_type}{$key})) {
							$sql_info->{ALTER_TABLE}{$table_name}{$statement_type}{$key} = $alter_table_info->{$table_name}{$statement_type}{$key};
						}
						else {
							setup_print_error("SQL file contains duplicate ALTER TABLE $statement_type $key statements");
							return;
						}
					}
				}
			}
		}
		elsif ($statement =~ /^INSERT/) {
			$statement =~ s/INSERT INTO/INSERT IGNORE INTO/;
			push @{$sql_info->{INSERT}}, $statement;
		}
		elsif ($statement =~ /^UPDATE/) {
			push @{$sql_info->{UPDATE}}, $statement;
		}
		elsif ($statement =~ /^DROP TABLE/) {
			my $table_name = parse_drop_table_statement($statement);
			push @{$sql_info->{DROP_TABLE}}, $table_name;
		}
		elsif ($statement =~ /^CREATE DATABASE/ ) {
		}
		elsif ($statement =~ /^SET/) {
		}
		else {
			setup_print_warning("SQL statement is not supported:\n$statement");
			return;
		}
	}
	print "Done. (statement count: $statement_count)\n";
	
	for my $table_info ($sql_info->{CREATE_TABLE}, $sql_info->{ALTER_TABLE}) {
		for my $table_name (keys %$table_info) {
			for my $constraint_name (keys %{$table_info->{$table_name}{CONSTRAINT}}) {
				my $constraint = $table_info->{$table_name}{CONSTRAINT}{$constraint_name};
				$constraint->{index_table} = $table_name;
				my $index_column = $constraint->{index_column};
				my $parent_table = $constraint->{parent_table};
				my $parent_column = $constraint->{parent_column};
				
				$sql_info->{CONSTRAINTS}{$constraint_name} = $constraint;
				push @{$sql_info->{REFERENCED_CONSTRAINTS}{$parent_table}{$parent_column}}, $constraint;
				$sql_info->{REFERENCING_CONSTRAINTS}{$table_name}{$index_column} = $constraint;
			}
			
			for my $column_name (keys %{$table_info->{$table_name}{ADD}}) {
				my $column_info = $table_info->{$table_name}{ADD}{$column_name};
				$sql_info->{ADD_COLUMN}{$table_name}{$column_name} = $column_info;
			}
			
			for my $column_name (keys %{$table_info->{$table_name}{DROP}}) {
				my $column_info = $table_info->{$table_name}{DROP}{$column_name};
				$sql_info->{DROP_COLUMN}{$table_name}{$column_name} = $column_info;
				
				###if (defined($sql_info->{ADD_COLUMN}{$table_name}{$column_name})) {
				###	delete $sql_info->{ADD_COLUMN}{$table_name}{$column_name};
				###}
			}
		}
	}
	
	if ($DEBUG) {
		setup_print_break('=');
		print "REFERENCED_CONSTRAINTS:\n\n";
		for my $parent_table (sort { lc($a) cmp lc($b) } keys %{$sql_info->{REFERENCED_CONSTRAINTS}}) {
			for my $parent_column (sort { lc($a) cmp lc($b) } keys %{$sql_info->{REFERENCED_CONSTRAINTS}{$parent_table}}) {
				my @constraints = @{$sql_info->{REFERENCED_CONSTRAINTS}{$parent_table}{$parent_column}};
				
				for my $constraint (@constraints) {
					my $index_table = $constraint->{index_table};
					my $index_column = $constraint->{index_column};
					print "$index_table.$index_column\n";
				}
				print "--> $parent_table.$parent_column\n\n";
			}
		}
		
		setup_print_break('=');
		print "REFERENCING_CONSTRAINTS:\n\n";
		for my $index_table (sort { lc($a) cmp lc($b) } keys %{$sql_info->{REFERENCING_CONSTRAINTS}}) {
			for my $index_column (sort { lc($a) cmp lc($b) } keys %{$sql_info->{REFERENCING_CONSTRAINTS}{$index_table}}) {
				my $parent_table = $sql_info->{REFERENCING_CONSTRAINTS}{$index_table}{$index_column}{parent_table};
				my $parent_column = $sql_info->{REFERENCING_CONSTRAINTS}{$index_table}{$index_column}{parent_column};
				print "$index_table.$index_column --> $parent_table.$parent_column\n";
			}
		}
	}
	
	return $sql_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_create_table_statement

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_create_table_statement {
	my ($statement) = @_;
	if (!$statement) {
		notify($ERRORS{'WARNING'}, 0, "SQL statement argument was not supplied");
		return;
	}
	
	my $table_info = {};
	
	my ($table_name, $table_definition, $table_options) = $statement =~ /CREATE TABLE(?: IF NOT EXISTS)? `?([\w_\$]+)`? \(\s*(.+)\s*\)\s*(.*)\s*$/g;
	if (!$table_name) {
		setup_print_error("failed to determine table name:\n\n$statement\n\n" . string_to_ascii($statement) . "");
		return;
	}
	elsif (!$table_definition) {
		setup_print_error("failed to determine table definition:\n\n$statement\n\n" . string_to_ascii($statement) . "");
		return;
	}
	$table_options = '' if !defined($table_options);
	
	$table_info->{$table_name}{STATEMENT} = $statement;
	
	#..........
	
	# Extract the CONSTRAINT definitions
	my $constraint_regex = '
		\s*					(?# omit leading spaces)
		(
			CONSTRAINT		(?# must contain KEY)
			[^,]+				(?# any character except commas)
		)
		[,\s]*				(?# omit trailing comma and spaces)
	';
	my @constraint_definitions = $table_definition =~ /$constraint_regex/gx;
	my $constraint_definition_count = scalar(@constraint_definitions) || 0;
	
	for (my $i=0; $i<$constraint_definition_count; $i++) {
		my $constraint_definition = $constraint_definitions[$i];
		my $constraint_info = parse_constraint_definition($constraint_definition);
		my $constraint_name = $constraint_info->{name};
		$table_info->{$table_name}{CONSTRAINT}{$constraint_name} = $constraint_info;
	}
	
	# Remove the CONSTRAINT definitions
	$table_definition =~ s/$constraint_regex//gx;
	
	#..........
	
	# Extract the KEY definitions
	my $key_regex = '
		\s*					(?# omit leading spaces)
		(
			[\w\s]*			(?# words preceding key such as PRIMARY, UNIQUE, etc)
			KEY				(?# must contain KEY)
			[^\)]+			(?# any character except closing parenthesis, all key definitions of a set of parenthesis)
			\)					(?# closing parenthesis)
			(?:
				[^,]*[^,\s]	(?# index options may exist after the closing parenthesis, make sure this ends with a non-space character)
			)?
		)
		[,\s]*				(?# omit trailing comma and spaces)
	';
	my @key_definitions = $table_definition =~ /$key_regex/gx;
	my $key_definition_count = scalar(@key_definitions);
	
	for (my $i=0; $i<$key_definition_count; $i++) {
		my $key_definition = $key_definitions[$i];
		
		my $key_definition_regex = '
			(
				\w*			(?# key type: PRIMARY, UNIQUE)
			)?
			\s?
			KEY
			\s
			`?
			(
				[\w_\$]+		(?# key name)
			)?					(?# key name is not set for primary keys)
			`?
			\s*
			\(					(?# opening parenthesis)
				([^\)]+)
			\)					(?# closing parenthesis)
			[,\s]*			(?# omit trailing comma and spaces)
		';
		
		my ($key_type, $key_name, $column_list) = $key_definition =~ /$key_definition_regex/x;
		if (!defined($key_type) && !defined($key_name)) {
			setup_print_error("failed to determine key type or name:\n\n$key_definition\n\n" . string_to_ascii($key_definition) . "");
			return;
		}
		elsif (!defined($column_list)) {
			setup_print_error("failed to determine column list:\n\n$key_definition\n\n" . string_to_ascii($key_definition) . "");
			return;
		}
		$key_type = 'INDEX' if (!$key_type);
		$key_name = 'PRIMARY' if !($key_name);
		
		$column_list =~ s/[`\s]//g;
		my @columns = split(/,/, $column_list);
		
		my $key_info = {};
		$key_info->{STATEMENT} = $key_definition;
		$key_info->{TYPE} = $key_type;
		$key_info->{name} = $key_name;
		%{$key_info->{COLUMNS}} = map { $_ => 1 } @columns;
		
		$table_info->{$table_name}{INDEXES}{$key_name} = $key_info;
	}
	
	# Error check, make sure number of times 'KEY' appears in original statement matches number of keys found
	my @statement_keys = $statement =~ /KEY/g;
	my $statement_key_count = scalar(@statement_keys);
	if ($statement_key_count ne ($key_definition_count + $constraint_definition_count)) {
		setup_print_error("statement KEY count ($statement_key_count) does not match the number of keys parsed ($key_definition_count) + constraints ($constraint_definition_count)");
		return;
	}
	
	# Remove the KEY definitions
	$table_definition =~ s/$key_regex//gx;
	
	#..........
	
	# Retrieve the column definitions
	my $column_regex = '
		\s*					(?# omit leading spaces)
		(
			(?:
				[^,\(]+		(?# any character execept for comma and opening parenthesis)
				|				(?# -or-)
				\(				(?# opening parenthesis)
					[^\)]+	(?# any character execept for closing parenthesis)
				\)				(?# closing parenthesis)
			)+					(?# match either case multiple times because normal charcters can come after the closing parenthesis)
		)
		[,\s]*				(?# omit trailing comma and spaces)
	';
	my @column_definitions = $table_definition =~ /$column_regex/gx;
	
	for (my $i=0; $i<scalar(@column_definitions); $i++) {
		my $column_definition = $column_definitions[$i];
		
		my $column_info = parse_column_definition($column_definition);
		if (!$column_info) {
			setup_print_error("failed to parse $table_name definition, column definition could not be parsed:\n$column_definition");
			return;
		}
		
		my $column_name = $column_info->{name};
		$table_info->{$table_name}{COLUMNS}{$column_name} = $column_info;
		
		push @{$table_info->{$table_name}{COLUMN_ORDER}}, $table_info->{$table_name}{COLUMNS}{$column_name};
	}
	
	#..........
	
	# Parse the table options
	my $table_options_patterns = {
		'AUTO_INCREMENT' => 'AUTO_INCREMENT',
		'(?:DEFAULT\s*)?(?:CHARSET|CHARACTER SET)' => 'CHARSET',
		'CHECKSUM' => 'CHECKSUM',
		'COMMENT' => 'COMMENT',
		'CONNECTION' => 'CONNECTION',
		'(?:DEFAULT\s*)?COLLATE' => 'COLLATE',
		'DATA DIRECTORY' => 'DATA_DIRECTORY',
		'DELAY_KEY_WRITE' => 'DELAY_KEY_WRITE',
		'(ENGINE|TYPE)' => 'ENGINE',
		'INDEX DIRECTORY' => 'INDEX_DIRECTORY',
		'INSERT_METHOD' => 'INSERT_METHOD',
		'KEY_BLOCK_SIZE' => 'KEY_BLOCK_SIZE',
		'MAX_ROWS' => 'MAX_ROWS',
		'MIN_ROWS' => 'MIN_ROWS',
		'PACK_KEYS' => 'PACK_KEYS',
		'PASSWORD' => 'PASSWORD',
		'RAID_TYPE' => 'RAID_TYPE',
		'RAID_CHUNKS' => 'RAID_CHUNKS',
		'RAID_CHUNKSIZE' => 'RAID_CHUNKSIZE',
		'ROW_FORMAT' => 'ROW_FORMAT',
		'TABLESPACE' => 'TABLESPACE',
		'UNION' => 'UNION',
	};
	
	for my $table_option_pattern (keys %$table_options_patterns) {
		my $synonym = $table_options_patterns->{$table_option_pattern};
		my $table_option_regex = $table_option_pattern . '\s*=\s*(\'[^\']+\'|[^\s]+)\s*';
		my ($value) = $table_options =~ /$table_option_regex/gx;
		if ($value) {
			$value =~ s/(^'|'$)//g;
			$table_options =~ s/$table_option_regex//gx;
			$table_info->{$table_name}{OPTIONS}{$synonym} = $value;
		}
	}
	if ($table_options =~ /\S/) {
		print "WARNING: $table_name table options not recognized: '$table_options'\n";
	}
	
	#print "\n" . format_data($table_info) . "\n";
	return $table_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_column_definition

 Parameters  : $table_name, $column_definition
 Returns     : 
 Description :

=cut

sub parse_column_definition {
	my ($column_definition) = @_;
	if (!$column_definition) {
		notify($ERRORS{'WARNING'}, 0, "column definition argument was not provided");
		return;
	}
	
	my $column_definition_regex = '
		^
			`?
				(					(?# begin column name match)
					[\w_\$]+		(?# column name)
				)					(?# end column name match)
			`?
			\s+ 					(?# space after column name)
			(						(?# begin data type match)
				(?:
					\w[^\s\(]+	(?# beginning of data type, must start with a letter, continue until space or opening parenthesis if found)
					|
					\(				(?# opening parenthesis)
						[^\)]+	(?# any character execept for closing parenthesis)
					\)				(?# closing parenthesis)
				)+
			)						(?# end data type match)
			\s*
			(
				.*					(?# column options)
			)
	';
	
	my ($column_name, $data_type, $column_options) = $column_definition =~ /$column_definition_regex/x;
	if (!defined($column_name)) {
		setup_print_error("failed to determine column name from column definition:\n$column_definition\n");
		return;
	}
	elsif (!defined($data_type)) {
		setup_print_error("failed to determine data type from column definition:\n$column_definition");
		return;
	}
	$column_options = '' if !defined($column_options);
	
	my $column_info = {
		'name' => $column_name,
		'STATEMENT' => $column_definition,
		'DATA_TYPE' => $data_type,
		'OPTIONS' => {},
	};
	
	if ($column_options =~ s/unsigned//i) {
		$column_info->{OPTIONS}{unsigned} = 1;
	}
	
	if ($column_options =~ s/AUTO_INCREMENT//i) {
		$column_info->{OPTIONS}{AUTO_INCREMENT} = 1;
	}
	
	my ($comment) = $column_options =~ /COMMENT '([^']+)'/i;
	if (defined($comment)) {
		$column_info->{OPTIONS}{COMMENT} = $comment;
	}
	$column_options =~ s/COMMENT '([^']+)'//i;
	
	# `column` varchar(xx) NOT NULL DEFAULT 'xxx',
	# `column` varchar(xx) DEFAULT NULL,
	# `column` varchar(xx) NULL default NULL,
	# `column` varchar(xx) NULL default 'xxx',a
	
	my ($default) = $column_options =~ /DEFAULT '?(NULL|[^']*)'?/i;
	if (defined($default)) {
		$column_info->{OPTIONS}{DEFAULT} = $default;
	}
	else {
		$default = '';
	}
	$column_options =~ s/DEFAULT '?(NULL|[^']*)'?//i;
	
	my $not_null = $column_options =~ s/NOT NULL//i;
	if ($not_null) {
		$column_info->{OPTIONS}{'NOT_NULL'} = 1;
	}
	else {
		$column_info->{OPTIONS}{'NOT_NULL'} = 0;
	}
	
	# Check if column does not have NOT NULL set and no default value:
	#   `column` text
	if (!$not_null && $default eq '') {
		$default = 'NULL';
		$column_info->{OPTIONS}{DEFAULT} = $default;
	}
	
	# Remove 'NULL' from the column options, it won't get removed from the above statements for this case:
	#    `column` varchar(xx) NULL default NULL
	if (!$not_null || $default =~ /null/i) {
		$column_options =~ s/NULL\s*//i;
	}
	
	if ($column_options =~ /[^\ ]/) {
		setup_print_warning("$column_name column options not recognized: '$column_options'");
	}
	
	return $column_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_alter_table_statement

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_alter_table_statement {
	my ($statement) = @_;
	if (!$statement) {
		notify($ERRORS{'WARNING'}, 0, "SQL statement argument was not supplied");
		return;
	}
	
	my ($table_name, $table_definition) = $statement =~ /ALTER TABLE `?([\w_\$]+)`?\s*(.+)\s*$/g;
	if (!$table_name) {
		setup_print_error("failed to determine table name:\n\n$statement\n\n" . string_to_ascii($statement) . "");
		return;
	}
	elsif (!$table_definition) {
		setup_print_error("failed to determine table definition:\n\n$statement\n\n" . string_to_ascii($statement) . "");
		return;
	}
	
	my $alter_table_info = {};
	
	#..........
	
	# Extract the CONSTRAINT definitions
	my $constraint_regex = '
		\s*						(?# omit leading spaces)
		(
			ADD\sCONSTRAINT
			[^,]+					(?# any character except commas)
		)
		[,\s]*					(?# omit trailing comma and spaces)
	';
	my @constraint_definitions = $table_definition =~ /$constraint_regex/gx;
	my $constraint_definition_count = scalar(@constraint_definitions) || 0;
	
	for (my $i=0; $i<$constraint_definition_count; $i++) {
		my $constraint_definition = $constraint_definitions[$i];
		my $constraint_info = parse_constraint_definition($constraint_definition);
		my $constraint_name = $constraint_info->{name};
		$alter_table_info->{$table_name}{'CONSTRAINT'}{$constraint_name} = $constraint_info;
	}
	
	# Remove the CONSTRAINT definitions
	$table_definition =~ s/$constraint_regex//gx;
	
	#..........
	
	# ADD `<column name>` bit(1) NULL default NULL
	# Extract the ADD definitions
	my $add_regex = '
		\s*					(?# omit leading spaces)
		ADD\s
		(
			[^,]+          (?# any character except commas)
		)
		[,\s]*				(?# omit trailing comma and spaces)
	';
	
	my @add_definitions = $table_definition =~ /$add_regex/gx;
	my $add_definition_count = scalar(@add_definitions) || 0;
	
	for (my $i=0; $i<$add_definition_count; $i++) {
		my $add_definition = $add_definitions[$i];
		my $column_info = parse_column_definition($add_definition);
		if (!$column_info) {
			setup_print_error("failed to parse alter table statement:\n$statement\nADD definition:\n$add_definition");
			return;
		}
		
		my $column_name = $column_info->{name};
		$alter_table_info->{$table_name}{ADD}{$column_name} = $column_info;
	}
	
	$table_definition =~ s/$add_regex//gx;
	
	#..........
	
	# Extract the DROP definitions
	my $drop_regex = '
		\s*					(?# omit leading spaces)
		DROP\s
		`?
		(
			[\w_\$]+          (?# any character except commas)
		)
		`?
		[,\s]*				(?# omit trailing comma and spaces)
	';
	
	my @drop_column_names = $table_definition =~ /$drop_regex/gx;
	my $drop_column_count = scalar(@drop_column_names) || 0;
	
	for (my $i=0; $i<$drop_column_count; $i++) {
		my $drop_column_name = $drop_column_names[$i];
		$alter_table_info->{$table_name}{DROP}{$drop_column_name} = 1;
	}
	
	$table_definition =~ s/$drop_regex//gx;
	
	#..........
	
	if ($table_definition =~ /\S/) {
		setup_print_warning("part of alter $table_name table definition was not handled:");
		print "table definition:\n$table_definition\n\n";
		print "statement:\n$statement\n\n";
		return;
	}
	
	return $alter_table_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_drop_table_statement

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_drop_table_statement {
	my ($statement) = @_;
	if (!$statement) {
		notify($ERRORS{'WARNING'}, 0, "SQL statement argument was not supplied");
		return;
	}
	
	# DROP TABLE IF EXISTS `<table name>`;
	my $drop_table_regex = '
		DROP\sTABLE\s
		(?:IF\sEXISTS\s)?
		`?
			([\w_\$]+)							(?# table name)
		`?
	';
	
	my ($table_name) = $statement =~ /$drop_table_regex/gx;
	if ($table_name) {
		return $table_name;
	}
	else {
		setup_print_error("failed to determine table name from statement: $statement");
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_insert_statements

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_insert_statements {
	my @statements = @_;
	if (!@statements) {
		notify($ERRORS{'WARNING'}, 0, "SQL statement argument was not supplied");
		return;
	}
	
	# INSERT IGNORE INTO `usergroupprivtype` (`id`, `name`, `help`) VALUES (1, 'xxx', 'yyy'),
	my $insert_regex = '
		INSERT\s
		(?:IGNORE\s)?
		(?:INTO\s)?
		`?
			([\w_\$]+)							(?# table name)
		`?\s
	';
	
	my $insert_info = {};
	for my $statement (@statements) {
		my ($table_name) = $statement =~ /$insert_regex/gx;
		if (!$table_name) {
			setup_print_error("failed to determine table name:\n\n$statement");
			return;
		}
		
		if (!defined($insert_info->{$table_name})) {
			$insert_info->{$table_name} = [];
		}
		push @{$insert_info->{$table_name}}, $statement;
	}
	
	return $insert_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_update_statement

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_update_statement {
	my ($statement) = @_;
	if (!$statement) {
		notify($ERRORS{'WARNING'}, 0, "SQL statement argument was not supplied");
		return;
	}
	
	# UPDATE <table_name> SET <column_name> = <value> WHERE ...;
	my $insert_regex = '
		UPDATE\s
		(?:IGNORE\s)?
		`?
			([\w_\$]+)							(?# table name)
		`?\s
		SET\s
		`?
		   ([\w_\$]+)							(?# column name)
		`?
		\s=\s
		   ([\S]+)				   			(?# value)
	';
	
	my ($table_name, $column_name, $value) = $statement =~ /$insert_regex/gx;
	if (!defined($table_name)) {
		setup_print_error("failed to determine table name from statement:\n$statement");
		return;
	}
	
	my $update_info = {
		'table' => $table_name,
		'column' => $column_name,
		'value' => $value,
		'STATEMENT' => $statement,
	};
	
	return $update_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 parse_constraint_definition

 Parameters  : 
 Returns     : 
 Description :

=cut

sub parse_constraint_definition {
	my ($constraint_definition) = @_;
	if (!$constraint_definition) {
		notify($ERRORS{'WARNING'}, 0, "constraint definition argument was not supplied");
		return;
	}
	
	# Remove text before "CONSTRAINT" for consistency
	$constraint_definition =~ s/.*(CONSTRAINT)/$1/;
	
	# CONSTRAINT `constraint_name` FOREIGN KEY (`this_column`) REFERENCES `that_table` (`that_column`) ON DELETE SET NULL ON UPDATE CASCADE
	my $constraint_definition_regex = '
		CONSTRAINT\s
		`?([\w_\$]+)`?\s		(?# constraint name)
		FOREIGN\sKEY\s
		\(							(?# opening parenthesis)
			`?([^\)`]+)`?		(?# column name for this table)
		\)\s						(?# closing parenthesis)
		REFERENCES\s
		`?([^\)`\s]+)`?\s		(?# other table)
		\(							(?# opening parenthesis)
		`?([^\)`\s]+)`?		(?# column name for other table)
		\)\s?						(?# closing parenthesis)
		(?:
			([^,]*[^,\s])?		(?# options)
		)?
	';
	
	my ($constraint_name, $index_column_name, $parent_table_name, $parent_column_name, $constraint_options) = $constraint_definition =~ /$constraint_definition_regex/gx;
	if (!defined($constraint_name)) {
		setup_print_error("failed to parse constraint name");
		return;
	}
	
	#print "name: $constraint_name\n";
	#print "index column: $index_column_name\n";
	#print "parent table: $parent_table_name\n";
	#print "parent column: $parent_column_name\n";
	
	my $constraint_info = {};
	$constraint_info->{name} = $constraint_name;
	$constraint_info->{index_column} = $index_column_name;
	$constraint_info->{parent_table} = $parent_table_name;
	$constraint_info->{parent_column} = $parent_column_name;
	$constraint_info->{STATEMENT} = $constraint_definition;
	
	if ($constraint_options) {
		#print "constraint options: '$constraint_options'\n";
		
		my $on_update_regex = 'ON UPDATE ((?:SET|NO)?\s?[\w]+)';
		my $on_delete_regex = 'ON DELETE ((?:SET|NO)?\s?[\w]+)';
		my ($on_update_value) = $constraint_options =~ /$on_update_regex/ig;
		my ($on_delete_value) = $constraint_options =~ /$on_delete_regex/ig;
		
		if ($on_update_value) {
			#print "ON UPDATE: '$on_update_value'\n" if $on_update_value;
			$constraint_info->{OPTIONS}{ON_UPDATE} = $on_update_value;
		}
		
		if ($on_delete_value) {
			#print "ON DELETE: '$on_delete_value'\n" if $on_delete_value;
			$constraint_info->{OPTIONS}{ON_DELETE} = $on_delete_value;
		}
		
		# Check for remaining constraint options
		$constraint_options =~ s/$on_update_regex//ig;
		$constraint_options =~ s/$on_delete_regex//ig;
		if ($constraint_options =~ /\w/) {
			print "WARNING: $index_column_name --> $parent_table_name.$parent_column_name constraint options not recognized: '$constraint_options'\n";
		}
	}
	
	#print "constraint info:\n" . format_data($constraint_info) . "\n";
	return $constraint_info;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 compare_database_to_reference

 Parameters  : 
 Returns     : 
 Description :

=cut

sub compare_database_to_reference {
	my ($database_info, $reference_info) = @_;
	if (!$database_info || !$reference_info) {
		notify($ERRORS{'WARNING'}, 0, "database and reference schema arguments were not supplied");
		return;
	}
	
	print "comparing schemas\n\n";
	
	my $changes = {
		ADD_COLUMN => [],
		ADD_INDEX => [],
		ADD_FOREIGN_KEY => [],
		ALTER_INDEX => [],
		CHANGE_COLUMN => [],
		CREATE_TABLE => [],
		DROP_COLUMN => [],
		DROP_FOREIGN_KEY => [],
		DROP_TABLE => [],
		INSERT => [],
	};
	
	for my $table_name (keys %$RENAME_COLUMNS) {
		for my $new_column_name (keys %{$RENAME_COLUMNS->{$table_name}}) {
			my $original_column_name = $RENAME_COLUMNS->{$table_name}{$new_column_name};
			if (!defined($database_info->{CREATE_TABLE}{$table_name}{COLUMNS}{$original_column_name})) {
				print "$table_name.$original_column_name won't be renamed to $new_column_name because $original_column_name column does not exist\n" if $DEBUG;
				next;
			}
			elsif (defined($database_info->{CREATE_TABLE}{$table_name}{COLUMNS}{$new_column_name})) {
				setup_print_warning("$table_name.$original_column_name won't be renamed to $new_column_name because $new_column_name column already exists");
				next;
			}
			
			my $reference_column = $reference_info->{CREATE_TABLE}{$table_name}{COLUMNS}{$new_column_name};
			if (!$reference_column) {
				setup_print_error("$table_name.$new_column_name definition does not exist in vcl.sql");
				print format_data($reference_info->{CREATE_TABLE}{$table_name}{COLUMNS});
				next;
			}
			
			print "column will be renamed: $table_name.$original_column_name --> $new_column_name\n";
			push @{$changes->{CHANGE_COLUMN}}, "ALTER TABLE `$table_name` CHANGE `$original_column_name` $reference_column->{STATEMENT};";
		}
	}
	
	my $drop_indexes = {};
	REFERENCE_TABLE: for my $table_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{CREATE_TABLE}}) {
		my $reference_table = $reference_info->{CREATE_TABLE}{$table_name};
		#if ($DEBUG) {
		#	print format_data($reference_table) . "\n";
		#	setup_print_break('.');
		#}
		
		my $database_table = $database_info->{CREATE_TABLE}{$table_name};
		if (!defined($database_table)) {
			print "table exists in reference but not database: $table_name\n" if $DEBUG;
			push @{$changes->{CREATE_TABLE}}, $reference_table->{STATEMENT};
			#$changes->{CREATE_TABLE}{$table_name} = $reference_table;
		}
		else {
			my $reference_columns = $reference_table->{COLUMNS};
			my $database_columns = $database_table->{COLUMNS};
			
			REFERENCE_COLUMN: for my $column_name (sort { lc($a) cmp lc($b) } keys %$reference_columns) {
				my $reference_column = $reference_columns->{$column_name};
				my $database_column = $database_columns->{$column_name};
				if (!defined($database_column)) {
					if (my $original_column_name = $RENAME_COLUMNS->{$table_name}{$column_name}) {
						if ($database_columns->{$original_column_name}) {
							print "column will not be added because it is being renamed: $table_name.$original_column_name --> $column_name\n" if $DEBUG;
							next REFERENCE_COLUMN;
						}
					}
					
					print "column exists in reference but not database: $table_name.$column_name\n" if $DEBUG;
					push @{$changes->{ADD_COLUMN}}, "ALTER TABLE `$table_name` ADD $reference_column->{STATEMENT};";
					#$changes->{ADD_COLUMN}{$table_name}{$column_name} = $reference_column;
					
					next REFERENCE_COLUMN;
				}
				
				my $reference_data_type = $reference_column->{DATA_TYPE};
				my $database_data_type = $database_column->{DATA_TYPE};
				if (lc($reference_data_type) ne lc($database_data_type)) {
					print "$table_name.$column_name data type will be changed: $database_data_type --> $reference_data_type\n";
					push @{$changes->{CHANGE_COLUMN}}, "ALTER TABLE `$table_name` CHANGE `$column_name` $reference_column->{STATEMENT};";
				}
				
				REFERENCE_COLUMN_OPTION: for my $option_name (sort { lc($a) cmp lc($b) } keys %{$reference_column->{OPTIONS}}) {
					my $reference_column_value = $reference_column->{OPTIONS}{$option_name};
					my $database_column_value = $database_column->{OPTIONS}{$option_name};
					
					if (!defined($database_column_value)) {
						print "$table_name.$column_name '$option_name' is set to '$reference_column_value' in reference, undefined in database\n" if $DEBUG;
						print "reference : $reference_column->{STATEMENT}\n";
						print "database  : $database_column->{STATEMENT}\n";
					}
					elsif (lc($reference_column_value) ne lc($database_column_value)) {
						print "$table_name.$column_name '$option_name' different, reference: '$reference_column_value', database: '$database_column_value'\n" if $DEBUG;
					}
					else {
						next REFERENCE_COLUMN_OPTION;
					}
					
					push @{$changes->{CHANGE_COLUMN}}, "ALTER TABLE `$table_name` CHANGE `$column_name` $reference_column->{STATEMENT};";
					#$changes->{CHANGE_COLUMN}{$table_name}{$column_name} = $reference_column;
				}
			}
			
			my $reference_table_indexes = $reference_table->{INDEXES};
			#print format_data($reference_table_indexes) . "\n";
			
			my $database_table_indexes = $database_table->{INDEXES};
			REFERENCE_TABLE_INDEX: for my $reference_index_name (keys %$reference_table_indexes) {
				my $reference_index = $reference_table_indexes->{$reference_index_name};
				my $reference_index_type = $reference_index->{TYPE};
				my @reference_index_column_names = sort { lc($a) cmp lc($b) } keys %{$reference_index->{COLUMNS}};
				my $reference_index_statement = $reference_index->{STATEMENT};
				
				# Check if database table contains an index with the same name
				if (!defined($database_table_indexes->{$reference_index_name})) {
					print "$table_name table '$reference_index_name' index does not exist in database\n" if $DEBUG;
					push @{$changes->{ADD_INDEX}}, "ALTER TABLE `$table_name` ADD $reference_index_statement;";
					#$changes->{ADD_INDEX}{$table_name}{$reference_index_name} = $reference_index;
					next REFERENCE_TABLE_INDEX;
				}
				else {
					#print "$table_name table '$reference_index_name' index exists in database\n" if $DEBUG;
				}
				
				# Index with same name exists, compare them
				my $database_table_index = $database_table_indexes->{$reference_index_name};
				my $database_table_index_type = $database_table_index->{TYPE};
				my @compare_table_index_column_names = sort { lc($a) cmp lc($b) } keys %{$database_table_index->{COLUMNS}};
				my $database_table_index_statement = $database_table_index->{STATEMENT};
				
				
				my $different = 0;
				if ($reference_index_type ne $database_table_index_type) {
					$different = 1;
					if ($DEBUG) {
						print "$table_name table '$reference_index_name' index type is different\n";
						print "reference : $reference_index_type\n";
						print "database  : $database_table_index_type\n";
					}
				}
				elsif (!compare_array_elements(\@reference_index_column_names, \@compare_table_index_column_names)) {
					$different = 1;
					if ($DEBUG) {
						print "$table_name table '$reference_index_name' index contains different columns:\n";
						print "reference : " . join(', ', @reference_index_column_names) . "\n";
						print "database  : " . join(', ', @compare_table_index_column_names) . "\n";
					}
				}
				
				if ($different) {
					$drop_indexes->{$reference_index_name} = 1;
					push @{$changes->{ALTER_INDEX}}, "ALTER TABLE `$table_name` DROP INDEX `$reference_index_name` , ADD $reference_index_statement;";
					#$changes->{ALTER_INDEX}{$table_name}{$reference_index_name} = $reference_index;
				}
			} # reference table index
		}  # database table defined
		
		my @column_order = @{$reference_table->{COLUMN_ORDER}};
		for (my $i=1; $i<scalar(@column_order); $i++) {
			my $column = $column_order[$i];
			my $previous_column = $column_order[$i-1];
			push @{$changes->{MODIFY_COLUMN}}, "ALTER TABLE `$table_name` MODIFY COLUMN $column->{STATEMENT} AFTER `$previous_column->{name}`;";
		}
		
	} # reference table
	
	# Check for explicit "DROP TABLE" statements
	for my $table_name (sort { lc($a) cmp lc($b) } @{$reference_info->{DROP_TABLE}}) {
		if (defined($database_info->{CREATE_TABLE}{$table_name})) {
			push @{$changes->{DROP_TABLE}}, "DROP TABLE IF EXISTS `$table_name`;";
		}
	}
	
	my @insert_statements = @{$reference_info->{INSERT}};
	for my $insert_statement (@insert_statements) {
		push @{$changes->{INSERT}}, $insert_statement;
	}
	
	## Check for explicit "ADD COLUMN" statements
	#my $add_columns = {};
	#for my $table_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{ADD_COLUMN}}) {
	#	for my $column_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{ADD_COLUMN}{$table_name}}) {
	#		if ($database_info->{CREATE_TABLE}{$table_name}{COLUMNS}{$column_name}) {
	#			print "$table_name.$column_name already exists in database\n";
	#			next;
	#		}
	#		else {
	#			print "$table_name.$column_name will be added\n" if $DEBUG;
	#			my $reference_column = $reference_info->{ADD_COLUMN}{$table_name}{$column_name};
	#			push @{$changes->{ADD_COLUMN}}, "ALTER TABLE `$table_name` ADD $reference_column->{STATEMENT}";
	#			$add_columns->{$table_name}{$column_name} = 1;
	#		}
	#	}
	#}
	
	
	
	# Check for explicit "DROP COLUMN" statements
	my $drop_columns = {};
	for my $table_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{DROP_COLUMN}}) {
		for my $column_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{DROP_COLUMN}{$table_name}}) {
			if (defined($database_info->{CREATE_TABLE}{$table_name}{COLUMNS}{$column_name})) {
				print "column exists in database, it will be dropped: $table_name.$column_name\n" if $DEBUG;
			}
			else {
				print "column does not exist in database and won't be added, it won't be dropped: $table_name.$column_name\n" if $DEBUG;
				next;
			}
			
			push @{$changes->{DROP_COLUMN}}, "ALTER TABLE `$table_name` DROP `$column_name`";		
			$drop_columns->{$table_name}{$column_name} = 1;
			
			my $referenced_constraints = $database_info->{REFERENCED_CONSTRAINTS}{$table_name}{$column_name};
			if ($referenced_constraints) {
				#print "referenced constraints:\n" . format_data($referenced_constraints) . "\n";
			}
			
			my $referencing_constraint = $database_info->{REFERENCING_CONSTRAINTS}{$table_name}{$column_name};
			if ($referencing_constraint) {
				#print "referencing constraints:\n" . format_data($referencing_constraint) . "\n";
				push @{$changes->{DROP_FOREIGN_KEY}}, "ALTER TABLE `$table_name` DROP FOREIGN KEY `$referencing_constraint->{name}`;";
			}
			
			my $database_table_indexes = $database_info->{CREATE_TABLE}{$table_name}{INDEXES};
			for my $database_index_name (keys %$database_table_indexes) {
				my $database_index = $database_table_indexes->{$database_index_name};
				my @database_index_column_names = sort { lc($a) cmp lc($b) } keys %{$database_index->{COLUMNS}};
				if (grep { $_ eq $column_name } @database_index_column_names) {
					if (scalar(@database_index_column_names) == 1) {
						print "'$database_index_name' index will be dropped automatically when $table_name.$column_name column is dropped\n" if $DEBUG;
					}
					elsif ($drop_indexes->{$database_index_name}) {
						print "'$database_index_name' index will be replaced\n" if $DEBUG;
					}
					else {
						print "'$database_index_name' index will be dropped\n" if $DEBUG;
						push @{$changes->{ALTER_INDEX}}, "ALTER TABLE `$table_name` DROP INDEX `$database_index_name`;";
					}
				}
			}
			
		}
	}
	
	REFERENCE_CONSTRAINT: for my $constraint_name (sort { lc($a) cmp lc($b) } keys %{$reference_info->{CONSTRAINTS}}) {
		my $reference_constraint = $reference_info->{CONSTRAINTS}{$constraint_name};
		my $reference_index_table          = $reference_constraint->{index_table};
		my $reference_index_column         = $reference_constraint->{index_column};
		my $reference_parent_table         = $reference_constraint->{parent_table};
		my $reference_parent_column        = $reference_constraint->{parent_column};
		my $reference_statement            = $reference_constraint->{STATEMENT};
		my $reference_on_update            = $reference_constraint->{OPTIONS}{ON_UPDATE} || '';
		my $reference_on_delete            = $reference_constraint->{OPTIONS}{ON_DELETE} || '';
		
		my $database_constraint = $database_info->{CONSTRAINTS}{$constraint_name};
		if ($database_constraint) {
			my $database_index_table         = $database_constraint->{index_table};
			my $database_index_column        = $database_constraint->{index_column};
			my $database_parent_table        = $database_constraint->{parent_table};
			my $database_parent_column       = $database_constraint->{parent_column};
			my $database_statement           = $database_constraint->{STATEMENT};
			my $database_on_update           = $database_constraint->{OPTIONS}{ON_UPDATE} || '';
			my $database_on_delete           = $database_constraint->{OPTIONS}{ON_DELETE} || '';
			
			if ($reference_index_table   ne $database_index_table ||
				 $reference_index_column  ne $database_index_column ||
				 $reference_parent_table  ne $database_parent_table ||
				 $reference_parent_column ne $database_parent_column ||
				 $reference_on_update     ne $database_on_update ||
				 $database_on_delete      ne $database_on_delete) {
			  
				if ($DEBUG) {
					print "constraints are different:\n";
					print "reference : $reference_statement\n";
					print "database  : $database_statement\n";
				}
				
				push @{$changes->{DROP_FOREIGN_KEY}}, "ALTER TABLE `$database_index_table` DROP FOREIGN KEY `$constraint_name`;";
				#$changes->{DROP_FOREIGN_KEY}{$database_index_table}{$database_index_column} = $database_constraint;
			}
			else {
				next REFERENCE_CONSTRAINT;
			}
		}
		else {
			print "constraint does not exist in database: $reference_statement\n" if ($DEBUG);
		}
		
		$reference_constraint->{STATEMENT} = "ALTER TABLE `$reference_index_table` ADD $reference_statement;";
		push @{$changes->{ADD_FOREIGN_KEY}}, $reference_constraint;
		#push @{$changes->{ADD_FOREIGN_KEY}}, "ALTER TABLE `$reference_index_table` ADD $reference_statement;";
		#$changes->{ADD_FOREIGN_KEY}{$reference_index_table}{$reference_index_column} = $reference_constraint;
	}
	
	# Check for extra constraints in database not in reference
	for my $constraint_name (sort { lc($a) cmp lc($b) } keys %{$database_info->{CONSTRAINTS}}) {
		my $database_constraint = $database_info->{CONSTRAINTS}{$constraint_name};
		my $database_index_table = $database_constraint->{index_table};
			my $database_index_column = $database_constraint->{index_column};
		if (!defined($reference_info->{CONSTRAINTS}{$constraint_name})) {
			if ($DEBUG) {
				print "constraint exists in database but not reference:\n" . format_data($database_constraint) . "\n" if ($DEBUG);
			}
			#$changes->{DROP_FOREIGN_KEY}{$constraint_name} = 1;
			#$changes->{DROP_FOREIGN_KEY}{$database_index_table}{$database_index_column} = $database_constraint;
			push @{$changes->{DROP_FOREIGN_KEY}}, "ALTER TABLE `$database_index_table` DROP FOREIGN KEY `$constraint_name`;";
		}
	}
	
	## Check compare table for columns not defined in base
	#for my $database_column_name (keys %$database_columns) {
	#	if (!defined($reference_columns->{$database_column_name})) {
	#		
	#		my @referenced_constraints = get_referenced_constraints($reference_database_name, $table_name, $database_column_name);
	#		for my $constraint (@referenced_constraints) {
	#			my $constraint_name = $constraint->{CONSTRAINT_NAME};
	#			#push @{$changes->{DROP_FOREIGN_KEY}}, "ALTER IGNORE TABLE `$table_name` DROP FOREIGN KEY `$constraint_name`;";
	#			$changes->{DROP_FOREIGN_KEY}{$table_name}{$constraint_name} = 1;
	#		}
	#		
	#		my $referencing_constraint = get_referencing_constraint($reference_database_name, $table_name, $database_column_name);
	#		if ($referencing_constraint) {
	#			my $constraint_name = $referencing_constraint->{CONSTRAINT_NAME};
	#			#push @{$changes->{DROP_FOREIGN_KEY}}, "ALTER IGNORE TABLE `$table_name` DROP FOREIGN KEY `$constraint_name`;";
	#			$changes->{DROP_FOREIGN_KEY}{$table_name}{$constraint_name} = 1;
	#		}
	#		
	#		print "$table_name table '$database_column_name' column does not exist in reference\n";
	#		# ALTER TABLE `table_name` DROP `column_name`
	#		push @{$changes->{DROP_COLUMN}}, "ALTER TABLE `$table_name` DROP `$database_column_name`;";
	#	}
	#}
	
	return $changes;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 compare_array_elements

 Parameters  : $array_ref_1, $array_ref_2
 Returns     : boolean (0 if different, 1 if identical, undef if error)
 Description : Compares the elements of 2 arrays. Arrays are considered
               identical if the number of elements in each array is identical
               and each array contains all of the elements of the other array.
               This subroutine does not consider order. It only compares arrays
               containing scalar elements. If an array element is a reference
               undef will be returned.

=cut

sub compare_array_elements {
	my ($array_ref_1, $array_ref_2) = @_;
	if (!defined($array_ref_1) || !defined($array_ref_2)) {
		notify($ERRORS{'WARNING'}, 0, "array reference arguments were not supplied");
		return;
	}
	my $type_1 = ref($array_ref_1);
	my $type_2 = ref($array_ref_2);
	if (!$type_1) {
		notify($ERRORS{'WARNING'}, 0, "both arguments must be array references, 1st argument is not a reference");
	}
	elsif (!$type_2) {
		notify($ERRORS{'WARNING'}, 0, "both arguments must be array references, 2nd argument is not a reference");
	}
	elsif ($type_1 ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "both arguments must be array references, 1st argument reference type: $type_1");
	}
	elsif ($type_2 ne 'ARRAY') {
		notify($ERRORS{'WARNING'}, 0, "both arguments must be array references, 2nd argument reference type: $type_2");
	}
	
	my @array_1 = @$array_ref_1;
	my @array_2 = @$array_ref_2;
	
	my $array_size_1 = scalar(@array_1);
	my $array_size_2 = scalar(@array_2);
	if ($array_size_1 != $array_size_2) {
		notify($ERRORS{'DEBUG'}, 0, "arrays sizes are different, 1st array: $array_size_1, 2nd array: $array_size_2");
		return 0;
	}
	
	if (grep { ref($_) } @array_1) {
		notify($ERRORS{'WARNING'}, 0, "unable to compare arrays, 1st array contains a reference value");
		return;
	}
	elsif (grep { ref($_) } @array_2) {
		notify($ERRORS{'WARNING'}, 0, "unable to compare arrays, 2nd array contains a reference value");
		return;
	}
	
	my %hash_1 = map { $_ => 1 } @array_1;
	my %hash_2 = map { $_ => 1 } @array_2;
	
	for my $key (keys %hash_1) {
		if (!defined($hash_2{$key})) {
			notify($ERRORS{'DEBUG'}, 0, "array elements are different, 1st array has element containing '$key', 2nd array does not");
			return 0;
		}
	}
	
	for my $key (keys %hash_2) {
		if (!defined($hash_1{$key})) {
			notify($ERRORS{'DEBUG'}, 0, "array elements are different, 2nd array has element containing '$key', 1st array does not");
			return 0;
		}
	}
	
	notify($ERRORS{'DEBUG'}, 0, "arrays contain identical elements");
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

=head2 update_database

 Parameters  : 
 Returns     : 
 Description :

=cut

sub update_database {
	my ($database_name, $changes) = @_;
	if (!$database_name || !$changes) {
		notify($ERRORS{'WARNING'}, 0, "database name and schema change hash arguments were not supplied");
		return;
	}
	
	my $mn_os = get_mn_os();
	if (!$mn_os) {
		setup_print_error("unable to create database, failed to retrieve OS object to control this management node");
		return;
	}
	
	# Check for duplicate drop foreign key statements
	my @drop_foreign_key_statements;
	my $foreign_key_hash = {};
	for my $foreign_key_statement (@{$changes->{DROP_FOREIGN_KEY}}) {
		my ($foreign_key) = $foreign_key_statement =~ /FOREIGN KEY `?([\w_\$]+)/;
		if (!$foreign_key) {
			setup_print_warning("failed to parse foreign key statement: $foreign_key_statement\n");
		}
		if (!defined($foreign_key_hash->{$foreign_key})) {
			$foreign_key_hash->{$foreign_key} = 1;
			push @drop_foreign_key_statements, $foreign_key_statement;
		}
		else {
			print "duplicate drop foreign key: $foreign_key\n";
		}
	}
	$changes->{DROP_FOREIGN_KEY} = \@drop_foreign_key_statements;
	
	
	my @operations = (
		'DROP_FOREIGN_KEY',
		'CREATE_TABLE',
		'ADD_COLUMN',
		'CHANGE_COLUMN',
		'INSERT',
		#'UPDATE',
		'DROP_COLUMN',
		'DROP_TABLE',
		'ADD_INDEX',
		'ALTER_INDEX',
		#'MODIFY_COLUMN',
	);
	
	for my $operation (@operations) {
		my $temp_sql_file_path = "/tmp/$database_name\_$timestamp\_$operation.sql";
		
		my $statements = $changes->{$operation};
		next unless $statements;
		
		my $statement_count = scalar(@$statements);
		if (!$statement_count) {
			next;
		}
		
		
		for my $statement (@$statements) {
			if (database_execute($statement, $database_name)) {
				print "executed statement: " . substr($statement, 0, 97);
				if (length($statement) > 97) {
					print "...";
				}
				print "\n";
			}
			else {
				setup_print_warning("failed to execute statement:");
				print "$statement\n\n";
				exit;
			}
		}
	}
	
	my $temp_sql_file_path = "/tmp/$database_name\_$timestamp\_ADD_FOREIGN_KEY.sql";
	my $add_constraint_count = 0;
	CONSTRAINT: for my $constraint (@{$changes->{ADD_FOREIGN_KEY}}) {
		my $index_table = $constraint->{index_table};
		my $index_column = $constraint->{index_column};
		my $parent_table = $constraint->{parent_table};
		my $parent_column = $constraint->{parent_column};
		
		my $select_statement = <<EOF;
SELECT DISTINCT
$index_table.$index_column
FROM
$index_table
WHERE
$index_table.$index_column IS NOT NULL
AND NOT EXISTS (
   SELECT
   $parent_table.$parent_column
   FROM
   $parent_table
   WHERE
   $parent_table.$parent_column = $index_table.$index_column
)
EOF
		
		my @rows = database_select($select_statement, $database_name);
		if (@rows) {
			setup_print_warning("\nunable to add constraint: $index_table.$index_column --> $parent_table.$parent_column");
			setup_print_wrap("$index_table.$index_column contains the following values which do not have a corresponding $parent_table.$parent_column value:");
			
			for my $row (@rows) {
				print "$index_table.$index_column=" . $row->{$index_column} . "\n";
			}
			print "\n";
			#print format_data($constraint) . "\n\n";
			next CONSTRAINT;
		}
		
		my $statement = $constraint->{STATEMENT};
		if (database_execute($statement, $database_name)) {
			print "added constraint: $index_table.$index_column --> $parent_table.$parent_column\n";
		}
		else {
			setup_print_warning("failed to add constraint:");
			print "$statement\n\n";
			exit;
		}
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 dump_database_to_file

 Parameters  : $database_name, $sql_file_path, @mysqldump_options (optional)
 Returns     : boolean
 Description : Uses mysqldump to dump a database to a file.

=cut

sub dump_database_to_file {
	my $database_name = shift;
	my $sql_file_path = shift;
	if (!$database_name || !$sql_file_path) {
		notify($ERRORS{'WARNING'}, 0, "database name and SQL file path arguments were not specified");
		return;
	}
	
	my @mysqldump_options_argument = @_;
	
	my $mn_os = get_mn_os();
	
	my @options = (
		"host=$DATABASE_SERVER",
		"user=$DATABASE_USERNAME",
		"password='$DATABASE_PASSWORD'",
		#"result-file=$sql_file_path",
		"databases $database_name",
		"insert-ignore",
		"order-by-primary",
		"allow-keywords",				# Allow creation of column names that are keywords
		"flush-privileges",			# Emit a FLUSH PRIVILEGES statement after dumping the mysql database
		"skip-lock-tables",			# Do not lock all tables to be dumped before dumping them
		"skip-add-drop-table",		# Do not add a DROP TABLE statement before each CREATE TABLE statement
		"skip-add-locks",				# Do not surround each table dump with LOCK TABLES and UNLOCK TABLES statements
		"skip-comments",				# Do not write additional information in the dump file such as program version, server version, and host
		"skip-disable-keys",			# Do not surround the INSERT statements with /*!40000 ALTER TABLE tbl_name DISABLE KEYS */;
		"skip-set-charset",			# Do not add SET NAMES default_character_set to the output.
		"skip-triggers",				# Do not include triggers for each dumped table in the output
		"skip-extended-insert",		# Use single-row INSERT statements
		"complete-insert",			# Use complete INSERT statements that include column names
	);
	
	my $command = "mysqldump";
	for my $option (@options, @mysqldump_options_argument) {
		$command .= " ";
		if ($option !~ /^-/) {
			$command .= "--";
		}
		$command .= $option;
	}
	$command .= " > $sql_file_path";
	
	print "\ndumping $database_name database to $sql_file_path...";
	my ($exit_status, $output) = $mn_os->execute($command);
	print "\n";
	if (!defined($output)) {
		setup_print_error("failed to execute command to dump $database_name database:\n$command");
		return;
	}
	elsif ($exit_status ne '0') {
		setup_print_error("failed to dump $database_name database to $sql_file_path, exit status: $exit_status\n\ncommand:\n$command\n\noutput:\n" . join("\n", @$output) . "\n");
		
		# Check for access denied error:
		# ERROR 1044 (42000) at line 1: Access denied for user '<username>'@'<IP address>' to database '<database>'
		# mysqldump: Got error: 1044: Access denied for user '<username>'@'<IP address>' to database '<database>' when selecting the database
		if (my ($access_denied_line) = grep(/Access denied/i, @$output)) {
			my ($source_host) = $access_denied_line =~ /\@'([^']+)'/;
			$source_host = '*' if !defined($source_host);
			print "\nexecute the following command on database server $DATABASE_SERVER:\n";
			print "mysql -e \"GRANT SELECT,INSERT,UPDATE,DELETE,CREATE TEMPORARY TABLES ON $database_name.* TO '$DATABASE_USERNAME'\@'$source_host' IDENTIFIED BY '$DATABASE_PASSWORD';\"\n";
		}
		return;
	}
	else {
		print "done.\n";
	}
	
	# Add the command used to the output file
	$mn_os->append_text_file($sql_file_path, "/*\n$command\n*/\n");
	
	print "\n";
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub setup {
	push @{$ENV{setup_path}}, 'Database Management';
	
	while (1) {
		setup_print_break('=');
		my $menu = setup_get_menu();
		my $choice = setup_get_menu_choice($menu);
		last unless defined $choice;
		
		my $choice_name = $choice->{name};
		my $choice_sub_ref = $choice->{sub_ref};
		my $choice_parent_menu_names = $choice->{parent_menu_names};
		
		push @{$ENV{setup_path}}, $choice_name;
		
		my $package_name = get_code_ref_package_name($choice_sub_ref);
		my $subroutine_name = get_code_ref_subroutine_name($choice_sub_ref);
		
		setup_print_break('.');
		&$choice_sub_ref();
		
		pop @{$ENV{setup_path}};
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_get_menu

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub setup_get_menu {
	my $menu = {
		'Database Management' => {
			'Upgrade Database' => \&setup_upgrade_database,
			'Backup Database' => \&setup_backup_database,
		},
	};
	
	return $menu;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_select_database

 Parameters  : $message (optional)
 Returns     : string
 Description : 

=cut

sub setup_select_database {
	my ($message) = @_;
	
	my @database_names = get_database_names();
	if (!@database_names) {
		setup_print_error("failed to retrieve database names from database server");
		return;
	}
	
	# Remove special databases from array
	@database_names = grep(!/^(mysql|information_schema)$/i, @database_names);
	
	if ($message) {
		print "\n$message:\n";
	}
	else {
		print "\nSelect database:\n";
	}
	
	my $choice_index = setup_get_array_choice(@database_names);
	return unless defined($choice_index);
	
	my $database_name = $database_names[$choice_index];
	print "Selected database: $database_name\n";
	
	return $database_name;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_backup_database

 Parameters  : none
 Returns     : 
 Description : 

=cut

sub setup_backup_database {
	my @database_names = get_database_names();
	if (!@database_names) {
		setup_print_error("failed to retrieve database names from database server");
		return;
	}
	
	my $database_name = setup_select_database('Select database to backup') || return;
	
	my $default_backup_file_name = "$database_name\_$timestamp.sql";
	my $default_backup_file_path = "/root/$default_backup_file_name";
	
	my $backup_file_path;
	while (1) {
		$backup_file_path = setup_get_input_file_path("\nEnter database backup file path\n", $default_backup_file_path);
		return unless defined($backup_file_path);
		
		if (!$backup_file_path) {
			$backup_file_path = $default_backup_file_path;
		}
		elsif (-d $backup_file_path) {
			my $backup_directory_path = $backup_file_path;
			$backup_directory_path =~ s/[\/\\]*$//g;
			$backup_file_path = "$backup_directory_path/$default_backup_file_name";
			print "\nPath entered is a directory: $backup_directory_path\n";
			
			if (!setup_confirm("Use default file name? $backup_file_path", 'y')) {
				next;
			}
		}
		elsif (-e $backup_file_path) {
			print "File already exists: $backup_file_path\n";
			next;
		}
		elsif ($backup_file_path !~ /\.sql$/i) {
			if (setup_confirm("Database backup file path does not end with '.sql', append this extension to file path? ($backup_file_path.sql)")) {
				$backup_file_path .= '.sql';
			}
		}
		last;
	}
	
	my @ignored_tables;
	if (setup_confirm("\nDo you want any tables to be ignored?", 'n')) {
		my @database_tables = get_database_table_names($database_name);
		if (!@database_tables) {
			setup_print_error("failed to retrieve table names from $database_name database");
			return;
		}
		
		my %database_table_hash = map { $_ => {'name' => $_, 'ignored' => ''} } @database_tables;
		#print format_data(\%database_table_hash) . "\n";
		
		IGNORE_TABLE: while (1) {
			print "\nSelect tables to ignore:\n";
			my $table_name_choice = setup_get_hash_choice(\%database_table_hash, 'name', 'ignored');
			last IGNORE_TABLE if !defined($table_name_choice);
			
			my $table_ignored = $database_table_hash{$table_name_choice}{ignored};
			if ($table_ignored) {
				$database_table_hash{$table_name_choice}{ignored} = '';
			}
			else {
				$database_table_hash{$table_name_choice}{ignored} = '*';
			}
		}
		
		for my $table_name (sort { lc($a) cmp lc($b) } keys %database_table_hash) {
			if ($database_table_hash{$table_name}{ignored}) {
				push @ignored_tables, $table_name;
			}
		}
	}
	
	print "\n$database_name database will be backed up to $backup_file_path\n";
	print "Tables ignored: " . (@ignored_tables ? "\n   " . join("\n   ", @ignored_tables) : '<none>') . "\n";
	return unless setup_confirm("Confirm");
	
	my @mysqldump_options = map { "--ignore-table=$database_name.$_" } @ignored_tables;
	return dump_database_to_file($database_name, $backup_file_path, @mysqldump_options);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 setup_upgrade_database

 Parameters  :
 Returns     : 
 Description : 

=cut

sub setup_upgrade_database {
	my ($database_name, $reference_sql_file_path) = @_;
	
	if (!$database_name) {
		my @database_names = get_database_names();
		if (!@database_names) {
			setup_print_error("failed to retrieve database names from database server");
			return;
		}
		$database_name = setup_select_database('Select database to upgrade');
		if (!$database_name) {
			print "database not selected\n";
			return;
		}
	}
	
	my ($database_sql_file_handle, $database_sql_file_path) = tempfile(CLEANUP => 1, SUFFIX => '.sql');
	if (!dump_database_to_file($database_name, $database_sql_file_path, '--no-data')) {
		setup_print_error("failed to dump '$database_name' database to file: $database_sql_file_path");
		return;
	}
	
	my $database_info = parse_sql_file($database_sql_file_path);
	if (!$database_info) {
		setup_print_error("failed to parse SQL file: $database_sql_file_path");
		return;
	}
	unlink $database_sql_file_path;
	print "\n";
	
	# Check if it looks like this scripts resides in complete copy of extracted VCL source
	if (!defined($reference_sql_file_path)) {
		# Get the path to this script and its parent directory
		my $current_file_path = abs_path(__FILE__);
		my ($current_file_name, $current_directory_path) = fileparse($current_file_path);
		$current_directory_path =~ s/\/$//g;
		
		if ($current_file_path =~ m|^(.+)/managementnode/bin/$current_file_name$|) {
			my $reference_directory_path = $1;
			$reference_sql_file_path = "$reference_directory_path/mysql/vcl.sql";
			
			if (!verify_vcl_sql_file($reference_sql_file_path)) {
				$reference_sql_file_path = undef;
			}
		}
		if (!$reference_sql_file_path) {
			my $sql_file_location_message;
			$sql_file_location_message .= "Please enter the path to the vcl.sql file which was included with the VCL $VERSION source code.";
			$sql_file_location_message .= " This should be located where you extracted the source code in a directory named 'sql'.";
			$sql_file_location_message .= " The path to this file most likely ends with 'apache-VCL-$VERSION/mysql/vcl.sql'\n";
			setup_print_wrap($sql_file_location_message);
			
			while (!$reference_sql_file_path) {
				$reference_sql_file_path = setup_get_input_file_path("Enter path to vcl.sql file");
				return unless defined($reference_sql_file_path);
				
				print "\n";
				if (!verify_vcl_sql_file($reference_sql_file_path)) {
					$reference_sql_file_path = undef;
					return;
				}
			}
		}
	}
	
	my $reference_info = parse_sql_file($reference_sql_file_path);
	if (!$reference_info) {
		return;
	}
	
	my $changes = compare_database_to_reference($database_info, $reference_info);
	if (!$changes) {
		return;
	}
	
	return update_database($database_name, $changes);
}

#//////////////////////////////////////////////////////////////////////////////

1;
