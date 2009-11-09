#!/usr/bin/perl -w
##############################################################################
# $Id$
##############################################################################
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

install_perl_libs.pl - Script to install VCL Perl module dependencies

=head1 SYNOPSIS

Run this script from the command line:
 
 perl install_perl_libs.pl

=head1 DESCRIPTION

 This script downloads and installs the Perl modules which are required for the
 backend VCL management node code. The modules which are automatically
 downloaded and installed by this script are licensed under the Artistic
 license, GPL, and LGPL. A disclaimer is displayed before this script downloads
 any modules notifying you of the modules' licenses. You must type YES in order
 for the script to proceed.
 
 Module source packages (.tar.gz files) are downloaded to /tmp/perl-modules.

=cut

##############################################################################
use strict;
use warnings;
use diagnostics;

my $disclaimer .= <<"EOF";
==============================================================================
*** NOTICE ***

This script will download and install Perl modules distributed under
the following licenses:
- The "Artistic License"
- GNU General Public License (GPL)
- GNU Library or "Lesser" General Public License (LGPL)

See the README file for more information.
==============================================================================
EOF

print $disclaimer;
while (1) {
	print 'Type YES to proceed, type NO to abort: ';
	my $input = <>;
	if ($input =~ /^\s*YES\s*$/i) {
		last;
	}
	elsif ($input =~ /^\s*NO\s*$/i) {
		exit;
	}
	else {
		next;
	}
}

print "==============================================================================\n";

my $download_directory= '/tmp/perl-modules';
mkdir $download_directory;

my @module_urls = (
	# MailTools is used to send email messages
	'http://search.cpan.org/CPAN/authors/id/M/MA/MARKOV/MailTools-2.04.tar.gz',
	
	# Object-InsideOut is used by DataStructure.pm for data encapsulation
	# The other modules listed are dependencies for Object-InsideOut
	'http://search.cpan.org/CPAN/authors/id/T/TM/TMTM/Class-Data-Inheritable-0.08.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Devel-StackTrace-1.20.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Exception-Class-1.26.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/J/JD/JDHEDDEN/Object-InsideOut-3.52.tar.gz',
	
	# YAML is used to serialize data stored in the database
	'http://search.cpan.org/CPAN/authors/id/I/IN/INGY/YAML-0.68.tar.gz',
	
	# RPC-XML is used to interact with the scheduling interface provided by the web frontend
	# The other modules listed are dependencies for RPC-XML
	'http://search.cpan.org/CPAN/authors/id/R/RJ/RJRAY/RPC-XML-0.64.tar.gz',
	'http://www.cpan.org/modules/by-module/XML/XML-Parser-2.36.tar.gz',
	'http://www.cpan.org/modules/by-module/Crypt/Crypt-SSLeay-0.57.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/HTML-Parser-3.64.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/libwww-perl-5.827.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/Compress-Raw-Zlib-2.021.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/IO-Compress-2.022.tar.gz',
	
	# DBI is used to communicate with the database
	'http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBI-1.609.tar.gz',
	
	# Jabber support is optional.  It is used to send IMs to users
	'http://search.cpan.org/CPAN/authors/id/D/DA/DAGOLDEN/Module-Build-0.35.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GB/GBARR/Authen-SASL-2.13.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RE/REATMON/XML-Stream-1.22.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/Digest-SHA1-2.12.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/H/HA/HACKER/Net-XMPP-1.02.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RE/REATMON/Net-Jabber-2.0.tar.gz',
);

# Loop through each URL
for my $url (@module_urls) {
	print "URL: $url\n";
	
	my ($module_filename) = $url =~ /([^\/]+)$/;
	print "Module filename: $module_filename\n";
	
	my ($module_name) = $url =~ /([^\/]+)\.tar\.gz$/;
	print "Module name: $module_name\n";
	
	my ($module_package) = $module_name =~ /([^\/]+)-[\d\.]+$/;
	$module_package =~ s/-/::/g;
	
	# Fix module package names and set arguments as necessary
	if ($module_name =~ /libwww-perl/) {
		$module_package = "Bundle::LWP";
	}
	elsif ($module_name =~ /MailTools/) {
		$module_package = "Mail::Mailer";
	}
	elsif ($module_name =~ /IO-Compress/) {
		$module_package = "Compress::Zlib";
	}
	print "Module package: $module_package\n";
	
	if (!module_installed($module_package)) {
		run_command("rm -rf $download_directory/*$module_name*");
		run_command("wget --directory-prefix=$download_directory $url");
		run_command("tar -xzf $download_directory/$module_filename -C $download_directory");
		run_command("cd $download_directory/$module_name && perl Makefile.PL");
		run_command("cd $download_directory/$module_name && make");
		##run_command("cd $download_directory/$module_name && make test");
		my $install_exit_status = run_command("cd $download_directory/$module_name && make install");
		if ($install_exit_status ne '0') {
			print "$module_name: installation failed, make install exit status is $install_exit_status\n";
			exit 1;
		}
	}
	
	print "==============================================================================\n";
}

exit  0;

sub module_installed {
	my $module_package = shift;
	
	print "Checking if $module_package is installed\n";
	
	my $output = `perl -M$module_package -e '' 2>&1`;
	my $exit_status = $? >> 8;
	#print "Checked if $module_package is installed, output:\n---\n$output\n---\n";
	
	if ($output !~ /Can't locate/) {
		print "Module is already installed: $module_package\n";
		return 1;
	}
	else {
		print "Module is NOT already installed: $module_package\n";
		return 0;
	}
}

sub run_command {
	my $command = shift;
	
	#print "--------------------------------------------------\n";
	print "running command: $command\n";
	system $command; 
	my $exit_status = $? >> 8;
	return $exit_status;
}
