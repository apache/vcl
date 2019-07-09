#!/usr/bin/perl -w
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

use Getopt::Long;
use YAML;
use DBI;
use Data::Dumper;

my $getnames = 0;
my $dumpmessage = '';
my $setmessage = '';
my $resetmessage = '';
my $htmlfile = '';
my $subject = '';
my $help = 0;

GetOptions ('getmessagenames' => \$getnames,
            'dumpmessage:s' => \$dumpmessage,
            'resetmessage:s' => \$resetmessage,
            'setmessage:s' => \$setmessage,
            'htmlfile:s' => \$htmlfile,
            'subject:s' => \$subject,
            'help|?' => \$help);

if ($help ||
	($getnames == 1 && ($dumpmessage ne '' || $setmessage ne '' || $resetmessage ne '' || $htmlfile ne '' || $subject ne '')) ||
	($getnames == 0 && $dumpmessage ne '' && ($setmessage ne '' || $resetmessage ne '' || $htmlfile ne '' || $subject ne '')) ||
	($getnames == 0 && $resetmessage ne '' && ($setmessage ne '' || $dumpmessage ne '' || $htmlfile ne '' || $subject ne '')) ||
	($getnames == 0 && $setmessage ne '' && ($dumpmessage ne '' || $resetmessage ne '' || $htmlfile eq '' || $subject eq '')) ||
	($getnames == 0 && $setmessage eq '' && $dumpmessage eq '' && $resetmessage eq ''))
{
	print "Usage:\n\n";
	print "vclmessages.pl --getmessagenames\n";
	print "vclmessages.pl --dumpmessage '<name of message>'\n";
	print "vclmessages.pl --setmessage '<name of message>' --htmlfile <filename> --subject <message subject>\n";
	print "vclmessages.pl --resetmessage '<name of message>'\n\n";
	print "vclmessages.pl --help|-?\n\n";
	print "Where\n\n";
	print "--getmessagenames displays a list of all available names that can be used\n";
	print "--dumpmessage displays the current value of a message\n";
	print "--setmessage sets the value of a message to the contents of the specified file\n";
	print "--resetmessage sets the value of a message back to the original value as distributed with VCL\n\n";
	print "<name of message> = the name of the message from the database (enclose in single quotes)\n";
	print "\tuse --getmessagenames to get a list of message names\n\n";
	print "<filename> = filename (including path) of file containing html contents for email message\n\n";
	print "<message subject> = subject for email message (enclose in single quotes)\n\n";
	exit 0;
}

my $mode = 'getnames';
$mode = 'dumpmessage' if($dumpmessage ne '');
$mode = 'setmessage' if($setmessage ne '');
$mode = 'resetmessage' if($resetmessage ne '');

my $messagename = $dumpmessage;
$messagename = $setmessage if($mode eq 'setmessage');
$messagename = $resetmessage if($mode eq 'resetmessage');

my $database = `grep ^database /etc/vcl/vcld.conf | awk -F '=' '{print \$2}'`;
my $hostname = `grep ^server /etc/vcl/vcld.conf | awk -F '=' '{print \$2}'`;
my $user = `grep ^LockerWrtUser /etc/vcl/vcld.conf | awk -F '=' '{print \$2}'`;
my $password = `grep ^wrtPass /etc/vcl/vcld.conf | awk -F '=' '{print \$2}'`;

chomp $database;
chomp $hostname;
chomp $user;
chomp $password;

my $dsn = "DBI:mysql:database=$database;host=$hostname";
my $dbh = DBI->connect($dsn, $user, $password);

# ================= get names ================
if($mode eq 'getnames')
{
	my $sth = $dbh->prepare(
		"SELECT name FROM variable WHERE name LIKE 'usermessage%' OR name LIKE 'adminmessage%' ORDER BY name")
		or die "Error: Failed to prepare database query: $dbh->errstr()";
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) {
		print "$ref->{'name'}\n";
	}
	$sth->finish;
	$sth->finish;
	$dbh->disconnect;
	exit 0;
}
# ================ dump message ===============
elsif($mode eq 'dumpmessage')
{
	my $sth = $dbh->prepare(
		"SELECT value FROM variable WHERE name = ?")
		or die "Error: Failed to prepare database query: $dbh->errstr()";
	$sth->execute($messagename);
	if($sth->rows == 0)
	{
		print "Error: Failed to find message with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}
	if($sth->rows > 1)
	{
		print "Error: Found multiple messages with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}
	my $ref = $sth->fetchrow_hashref();
	my $data = YAML::Load($ref->{'value'});
	#print Dumper($data);
	print "Subject: $data->{'subject'}\n";
	print "Message:\n";
	print "$data->{'message'}\n";

	$sth->finish;
	$dbh->disconnect;
	exit 0;
}
# ================= reset message ===============
elsif($mode eq 'resetmessage')
{
	my $sth = $dbh->prepare(
		'SELECT value FROM messagereset WHERE name = ?')
		or die "Error: Failed to prepare database query: $dbh->errstr()";
	$sth->execute($messagename) or die "Error: failed to query database: $dbh->errstr()";
	if($sth->rows == 0)
	{
		print "Error: Failed to find message with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}
	if($sth->rows > 1)
	{
		print "Error: Found multiple messages with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}

	my $ref = $sth->fetchrow_hashref();
	my $message = $ref->{'value'};

	$sth = $dbh->prepare(
		"UPDATE variable SET value = ?, setby = 'setemail script', timestamp = NOW() WHERE name = ?")
		or die "Error: Failed to prepare database query: $dbh->errstr()";

	$sth->bind_param(1, $message);
	$sth->bind_param(2, $messagename);
	$sth->execute() or die "Error: Failed to update value for $messagename\n";

	$sth->finish;
	$dbh->disconnect;
	print "Success: Value reset for $messagename\n";
}
# ================= set message ===============
elsif($mode eq 'setmessage')
{
	my $htmlemail;
	open(my $fh, '<', $htmlfile) or die "Error: failed to open $htmlfile for reading";
	{
		local $/;
		$htmlemail = <$fh>;
	}
	close($fh);

	my $sth = $dbh->prepare(
		'SELECT value FROM variable WHERE name = ?')
		or die "Error: Failed to prepare database query: $dbh->errstr()";
	$sth->execute($messagename) or die "Error: failed to query database: $dbh->errstr()";
	if($sth->rows == 0)
	{
		print "Error: Failed to find message with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}
	if($sth->rows > 1)
	{
		print "Error: Found multiple messages with name $messagename\n";
		$sth->finish;
		$dbh->disconnect;
		exit 0;
	}

	my $ref = $sth->fetchrow_hashref();
	my $data = YAML::Load($ref->{'value'});
	$data->{'message'} = $htmlemail;
	$data->{'subject'} = $subject;
	my $yaml = YAML::Dump($data);

	$sth = $dbh->prepare(
		"UPDATE variable SET value = ?, setby = 'setemail script', timestamp = NOW() WHERE name = ?")
		or die "Error: Failed to prepare database query: $dbh->errstr()";

	$sth->bind_param(1, $yaml);
	$sth->bind_param(2, $messagename);
	$sth->execute() or die "Error: Failed to update value for $messagename\n";

	$sth->finish;
	$dbh->disconnect;
	print "Success: Value for $messagename updated from contents of $htmlfile\n";
}
