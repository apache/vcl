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

 perl install_perl_libs.pl

=head1 DESCRIPTION

 This script downloads and installs the Perl modules which are required for the
 VCL management node code to run.
 
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
	'http://search.cpan.org/CPAN/authors/id/M/MA/MARKOV/MailTools-2.04.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/T/TM/TMTM/Class-Data-Inheritable-0.08.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Devel-StackTrace-1.22.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Exception-Class-1.29.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/J/JD/JDHEDDEN/Object-InsideOut-3.56.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DA/DAGOLDEN/Module-Build-0.35.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/H/HA/HACKER/Net-XMPP-1.02.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/A/AG/AGROLMS/GSSAPI-0.26.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/Digest-SHA1-2.12.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GB/GBARR/Authen-SASL-2.13.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RE/REATMON/XML-Stream-1.22.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RE/REATMON/Net-Jabber-2.0.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/YAML-0.70.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RJ/RJRAY/RPC-XML-0.69.tar.gz',
	'http://www.cpan.org/modules/by-module/XML/XML-Parser-2.36.tar.gz',
	'http://www.cpan.org/modules/by-module/Crypt/Crypt-SSLeay-0.57.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/Compress-Raw-Zlib-2.021.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/IO-Compress-2.022.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBI-1.609.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/libwww-perl-5.833.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/URI-1.40.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GB/GBARR/Scalar-List-Utils-1.21.tar.gz'
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
	elsif ($module_name =~ /Scalar-List-Utils/) {
		$module_package = "Scalar::Util";
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
