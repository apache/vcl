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

 This script downloads and installs the Linux packages and Perl modules which
 are required for the backend VCL management node code. The yum utility is used
 to download and install the Linux packages. The CPAN.pm Perl module is used to
 download and install the required Perl modules. A disclaimer is displayed
 before this script downloads any files notifying you of the licenses used by
 the dependencies. You must type YES in order for the script to proceed.

=cut

##############################################################################
use strict;
use warnings;
use diagnostics;

use Getopt::Long;
use Data::Dumper;
use CPAN;

#/////////////////////////////////////////////////////////////////////////////

# Store the command line options in hash
my $AGREE;
my %OPTIONS;
GetOptions(\%OPTIONS,
			'y!' => \$AGREE,
);

show_disclaimer() if !$AGREE;

print_break('=');
install_linux_packages();

print_break('=');
install_perl_modules();

print_break('=');
exit;

#/////////////////////////////////////////////////////////////////////////////

sub install_linux_packages {
	my @linux_packages = (
		'expat',
		'expat-devel',
		'gcc',
		'krb5-libs',
		'krb5-devel',
		'libxml2',
		'libxml2-devel',
		'nmap',
		'openssl',
		'openssl-devel',
		'perl-DBD-MySQL',
		'xmlsec1-openssl',
	);
	
	my $which_exit_status = run_command("which yum");
	if ($which_exit_status ne '0') {
		print "yum is not available on this OS, skipping Linux package installation\n";
		return 0;
	}
	
	my $yum_exit_status = run_command("yum install -y " . join(" ", @linux_packages));
	print "yum installation exit status: $yum_exit_status\n";
	if ($yum_exit_status ne '0') {
		print "failed to install all Linux packages using yum, exit status: $yum_exit_status\n";
		exit 1;
	}
	
	print "successfully installed Linux packages using yum\n";
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

sub install_perl_modules {
	$ENV{PERL_MM_USE_DEFAULT} = 1; 
	$ENV{PERL_MM_NONINTERACTIVE} = 1; 
	$ENV{AUTOMATED_TESTING} = 1;
	$ENV{FTP_PASSIVE} = 1;
	
	my $cpan_directory = '/tmp/cpan';
	`rm -rf $cpan_directory`;
	
	$CPAN::Config = {
		"applypatch" => "",
		"auto_commit" => "1",
		"build_cache" => "0",
		"build_dir" => "$cpan_directory/build",
		"build_requires_install_policy" => "yes",
		"bzip2" => `echo -n \`which bzip2\``,
		"cache_metadata" => "1",
		"check_sigs" => "0",
		"connect_to_internet_ok" => "1",
		"cpan_home" => "$cpan_directory",
		"curl" => `echo -n \`which curl\``,
		"force" => "1",
		"ftp" => `echo -n \`which ftp\``,
		"ftp_passive" => "1",
		"ftp_proxy" => "",
		"getcwd" => "cwd",
		"gpg" => `echo -n \`which gpg\``,
		"gzip" => `echo -n \`which gzip\``,
		"halt_on_failure" => "0",
		"histfile" => "$cpan_directory/histfile",
		"histsize" => "1000",
		"http_proxy" => "",
		"inactivity_timeout" => "60",
		"index_expire" => "1",
		"inhibit_startup_message" => "1",
		"keep_source_where" => "$cpan_directory/sources",
		"links" => `echo -n \`which links\``,
		"load_module_verbosity" => "0",
		"make" => `echo -n \`which make\``,
		"make_arg" => "",
		"make_install_arg" => "",
		"make_install_make_command" => `echo -n \`which make\``,
		"makepl_arg" => "",
		"mbuild_arg" => "",
		"mbuild_install_arg" => "",
		"mbuild_install_build_command" => "./Build",
		"mbuildpl_arg" => "",
		"ncftp" => "",
		"ncftpget" => "",
		"no_proxy" => "",
		"pager" => `echo -n \`which less\``,
		"perl5lib_verbosity" => "",
		"prefer_installer" => "MB",
		"prefs_dir" => "$cpan_directory/prefs",
		"prerequisites_policy" => "follow",
		"proxy_user" => "",
		"randomize_urllist" => "1",
		"scan_cache" => "never",
		"shell" => `echo -n \`which bash\``,
		"show_upload_date" => "0",
		"tar" => `echo -n \`which tar\``,
		"tar_verbosity" => "0",
		"term_ornaments" => "1",
		"trust_test_report_history" => "1",
		"unzip" => `echo -n \`which unzip\``,
		"urllist" => "",
		"use_sqlite" => "0",
		"wget" => `echo -n \`which wget\``,
		"yaml_load_code" => "0",
	};
	
	print Dumper($CPAN::Config);
	
	my @perl_modules = (
		'DBI',
		'Digest::SHA1',
		'Mail::Mailer',
		'Net::Jabber',
		'Object::InsideOut',
		'RPC::XML',
		'YAML',
	);
	
	for my $perl_module (@perl_modules) {
		print_break('-');
		print "attempting to install Perl module using CPAN: $perl_module\n";
		CPAN::install($perl_module);
		
		if (!is_perl_module_installed($perl_module)) {
			exit 1;
		}
		
	}
	
	print_break("*");
	print "successfully installed required Perl modules\n";
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

sub is_perl_module_installed {
	my $module_package = shift;
	
	print "checking if $module_package Perl module is installed...\n";
	
	my $command = "perl -e \"eval \\\"use $module_package\\\"; print \\\$" . $module_package . "::VERSION\" 2>&1";
	my $output = `$command`;
	
	my $exit_status = $? >> 8;
	#print "checked if $module_package is installed, version check output:\n$output\n";
	
	if ($output =~ /Can't locate/i) {
		print "$module_package Perl module is NOT installed\n";
		return;
	}
	
	my ($version) = $output =~ /^(\d[\d\.]+\d)$/;
	if (defined($version)) {
		print "$module_package $version Perl module is installed\n";
		return $version;
	}
	else {
		print "$module_package Perl module is installed but the version could not be determined, output:\n$output";
		return 1;
	}
}

#/////////////////////////////////////////////////////////////////////////////

sub run_command {
	my $command = shift;
	
	print "attempting to run command: $command\n";
	system $command; 
	my $exit_status = $? >> 8;
	print "ran command: $command, exit status: $exit_status\n";
	return $exit_status;
}

#/////////////////////////////////////////////////////////////////////////////

sub show_disclaimer {
	my $disclaimer .= <<"EOF";
*** NOTICE ***

This script will download and install Linux packages and Perl modules
distributed under the following licenses:
- The "Artistic License"
- BSD License
- GNU General Public License (GPL)
- GNU Library or "Lesser" General Public License (LGPL)
- MIT License

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
}

#/////////////////////////////////////////////////////////////////////////////

sub print_break {
	my $character = shift;
	$character = '-' if !defined($character);
	print $character x 80 . "\n";
}
