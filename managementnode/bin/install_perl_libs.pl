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
*** NOTICE ***

This script will download and install Perl modules distributed under
the following licenses:
- The "Artistic License"
- GNU General Public License (GPL)
- GNU Library or "Lesser" General Public License (LGPL)

See the README file for more information.
EOF

print '=' x 76 . "\n";
print $disclaimer;
print '=' x 76 . "\n";

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

print '=' x 76 . "\n";

my $download_directory= '/tmp/perl-modules';
mkdir $download_directory;

my @module_urls = (
	# MailTools is used to send email messages
	'http://search.cpan.org/CPAN/authors/id/M/MA/MARKOV/MailTools-2.06.tar.gz',
	
	# Object-InsideOut is used by DataStructure.pm for data encapsulation
	# The other modules listed are dependencies for Object-InsideOut
	'http://search.cpan.org/CPAN/authors/id/T/TM/TMTM/Class-Data-Inheritable-0.08.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/M/MS/MSCHWERN/Test-Simple-0.96.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/M/MS/MSCHWERN/ExtUtils-MakeMaker-6.56.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Devel-StackTrace-1.25.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/D/DR/DROLSKY/Exception-Class-1.32.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RO/ROBIN/Want-0.18.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/J/JD/JDHEDDEN/Math-Random-MT-Auto-6.15.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/J/JD/JDHEDDEN/Object-InsideOut-3.67.tar.gz',
	
	# YAML is used to serialize data stored in the database
	'http://search.cpan.org/CPAN/authors/id/A/AD/ADAMK/YAML-0.72.tar.gz',
	
	# RPC-XML is used to interact with the scheduling interface provided by the web frontend
	# The other modules listed are dependencies for RPC-XML
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/URI-1.55.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/libwww-perl-5.836.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/R/RJ/RJRAY/RPC-XML-0.73.tar.gz',
	'http://www.cpan.org/modules/by-module/XML/XML-Parser-2.36.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/N/NA/NANIS/Crypt-SSLeay-0.58.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PE/PETDANCE/HTML-Tagset-3.20.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/HTML-Parser-3.68.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/Compress-Raw-Bzip2-2.030.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/Compress-Raw-Zlib-2.030.tar.gz',
	'http://search.cpan.org/CPAN/authors/id/P/PM/PMQS/IO-Compress-2.030.tar.gz',
	
	# DBI is used to communicate with the database
	'http://search.cpan.org/CPAN/authors/id/T/TI/TIMB/DBI-1.613.tar.gz',
	
	# SHA1 is used when creating new local VCL accounts
	'http://search.cpan.org/CPAN/authors/id/G/GA/GAAS/Digest-SHA1-2.13.tar.gz',
);

# Loop through each URL
URL: for my $url (@module_urls) {
	print '-' x 76 . "\n";
	#print "URL: $url\n";
	
	my ($module_filename) = $url =~ /([^\/]+)$/;
	#print "Module filename: $module_filename\n";
	
	my ($module_name) = $url =~ /([^\/]+)\.tar\.gz$/;
	#print "Module name: $module_name\n";
	
	my ($module_package) = $module_name =~ /([^\/]+)-[\d\.]+$/;
	$module_package =~ s/-/::/g;
	
	# Fix module package names and set arguments as necessary
	if ($module_name =~ /libwww-perl/) {
		$module_package = "LWP";
	}
	elsif ($module_name =~ /MailTools/) {
		$module_package = "Mail::Mailer";
	}
	elsif ($module_name =~ /IO-Compress/) {
		$module_package = "Compress::Zlib";
	}
	elsif ($module_name =~ /InsideOut/) {
		$module_package = "Object::InsideOut::Util";
	}
	#print "Module package: $module_package\n";
	
	my ($module_version) = $url =~ /(\d[\d\.]+\d)/;
	print "Perl module: $module_package $module_version\n";
	
	#print "Module version: $module_version\n";
	
	my $install_module = 0;
	
	my $installed_version = module_installed($module_package);
	if ($installed_version) {
		print "$module_package $installed_version is installed\n";
		
		my @module_version_sections = split(/\./, $module_version);
		#print "Module version sections:    @module_version_sections\n";
		
		my @installed_version_sections = split(/\./, $installed_version);
		#print "Installed version sections: @installed_version_sections\n";
		
		for (my $i=0; $i<scalar(@module_version_sections); $i++) {
			if (!defined($installed_version_sections[$i])) {
				print "Module installed appears to be a newer sub version: $installed_version > $module_version\n";
				next URL;
			}
			
			my $module_version_section = $module_version_sections[$i];
			my $installed_version_section = $installed_version_sections[$i];
			
			if ($module_version_section !~ /^\d+$/ || $installed_version_section !~ /^\d+$/) {
				print "Unable to compare versions: '$installed_version' '$module_version'\n";
				last;
			}
			
			$module_version_section =~ s/0+$//g;
			$installed_version_section =~ s/0+$//g;
			
			#print "Module version section: $module_version_section\n";
			#print "Installed version section: $installed_version_section\n";
			
			$module_version_section = 0 if !$module_version_section;
			$installed_version_section = 0 if !$installed_version_section;
			
			if ($module_version_section < $installed_version_section) {
				print "Module installed appears to be a newer version: $installed_version > $module_version\n";
				$install_module = 0;
				last;
			}
			
			if ($module_version_section > $installed_version_section) {
				print "Module installed appears to be an older version: $installed_version < $module_version\n";
				$install_module = 1;
				last;
			}
		}
	}
	
	if ($installed_version && !$install_module) {
		print "$module_package $module_version does not need to be installed\n";
		next;
	}
	
	print "Attempting to install module: $module_package $module_version\n";
	
	run_command("rm -rf $download_directory/*$module_name*");
	
	my ($wget_exit_status, $wget_output) = run_command("wget --directory-prefix=$download_directory $url");
	if ($wget_exit_status ne '0') {
		print "$module_name installation failed, unable to download module: $module_package\nURL: $url\noutput:\n---\n$wget_output\n---\n";
		exit 1;
	}
	
	run_command("tar -xzf $download_directory/$module_filename -C $download_directory");
	
	my ($makefile_exit_status, $makefile_output) = run_command("cd $download_directory/$module_name && perl Makefile.PL");
	if ($makefile_exit_status ne '0') {
		print "failed to create makefile for $module_name, output:\n---\n$makefile_output\n---\n";
		exit 1;
	}
	
	run_command("cd $download_directory/$module_name && make");
	##run_command("cd $download_directory/$module_name && make test");
	
	my ($install_exit_status, $install_output) = run_command("cd $download_directory/$module_name && make install");
	if ($install_exit_status ne '0') {
		print "output:\n---\n$install_output\n---\n$module_name installation failed, make install exit status is $install_exit_status, output is above\n";
		exit 1;
	}
	print "Installed $module_package $module_version\n";
}

print '=' x 76 . "\n";
exit  0;

sub module_installed {
	my $module_package = shift;
	
	#print "Checking if $module_package is installed\n";
	
	my $command = "perl -M$module_package -e \"print \\\$" . $module_package . "::VERSION\" 2>&1";
	#print "Command: $command\n";
	my $output = `$command`;
	
	#my $output = `perl -M$module_package -e '$command' 2>&1`;
	my $exit_status = $? >> 8;
	#print "Checked if $module_package is installed, output:\n---\n$output\n---\n";
	
	if ($output =~ /Can't locate/i) {
		print "Module is NOT already installed: $module_package\n";
		return;
	}
	
	my ($version) = $output =~ /^(\d[\d\.]+\d)$/;
	if (defined($version)) {
		return $version;
	}
	else {
		print "$module_package is installed but the version could not be determined\n";
		return 0;
	}
}

sub run_command {
	my $command = shift;
	
	#print "--------------------------------------------------\n";
	print "Running command: $command\n";
	my $output = `$command 2>&1`; 
	my $exit_status = $? >> 8;
	return ($exit_status, $output);
}
