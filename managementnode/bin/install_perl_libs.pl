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

use English;
use Getopt::Long;
use Data::Dumper;
use POSIX;

#/////////////////////////////////////////////////////////////////////////////

# Store the command line options in hash
my $AGREE;
my %OPTIONS;
GetOptions(\%OPTIONS,
	'y!' => \$AGREE,
);

show_disclaimer() if !$AGREE;

my @ERRORS;

print_break('=');
install_linux_packages();

print_break('=');
install_perl_modules();

print_break('=');

if (@ERRORS) {
	print "WARNING: failed to install the following components:\n" . join("\n", @ERRORS) . "\n";
}
else {
	print "COMPLETE: installed all components\n";
}

exit;

#/////////////////////////////////////////////////////////////////////////////

sub install_linux_packages {
	# Check if yum is available
	my ($which_exit_status, $which_output) = run_command("which yum");
	if ($which_exit_status ne '0') {
		print "yum is not available on this OS, skipping Linux package installation\n";
		return 0;
	}
	
	my @uname = POSIX::uname();
	my $arch = $uname[4];
	my $version = $uname[2];
	
	if (!$arch || !$version) {
		print "WARNING: unable to determine OS architecture and version, skipping Linux package installation\n";
		return;
	}
	
	if ($arch =~ /i686/) {
		$arch = 'i386';
	}
	
	my $rhel_version;
	if ($version =~ /el(\d+)/) {
		$rhel_version = $1;
	}
	
	if ($rhel_version) {
		my $epel_url = "http://download.fedora.redhat.com/pub/epel/$rhel_version/$arch/epel-release-5-4.noarch.rpm";
		print "constructed EPEL URL:\n$epel_url\n\n";
		
		my $rpm_command = "rpm -Uvh $epel_url";
		my $rpm_output = `$rpm_command 2>&1`;
		my $rpm_exit_status = $? >> 8;
		if ($rpm_exit_status ne '0' && $rpm_output !~ /already installed/i) {
			print "WARNING: failed to install EPEL, some Perl modules may not install correctly\nrpm command: $rpm_command\nrpm exit status: $rpm_exit_status\nrpm output:\n$rpm_output\n";
			push @ERRORS, 'EPEL';
		}
		else {
			print "SUCCESS: installed EPEL\n";
		}
	}
	else {
		print "OS version does not appear to be RHEL: $version, skipping EPEL installation\n";
	}
	
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
		'perl-CPAN',
		'perl-DBD-MySQL',
		'perl-DBI',
		'perl-Digest-SHA1',
		'perl-MailTools',
		'perl-Net-Jabber',
		'perl-RPC-XML',
		'perl-YAML',
		'xmlsec1-openssl',
	);
	
	for my $linux_package (@linux_packages) {
		print_break('*');
		print "attempting to install Linux package using yum: $linux_package\n";
		
		my $yum_command = "yum install $linux_package -y";
		print "yum command: $yum_command\n";
		
		my $yum_output = `$yum_command 2>&1`;
		my $yum_exit_status = $? >> 8;
		
		chomp $yum_output;
		print "$yum_output\n\n";
		
		if ($yum_exit_status ne '0') {
			print "WARNING: failed to install Linux package: $linux_package, exit status: $yum_exit_status\n";
			#push @ERRORS, "Linux package: $linux_package";
		}
		elsif ($yum_output =~ /$linux_package[^\n]*already installed/i) {
			print "SUCCESS: Linux package is already installed: $linux_package\n";
		}
		elsif ($yum_output =~ /Complete\!/i) {
			print "SUCCESS: installed Linux package: $linux_package\n";
		}
		else {
			print "WARNING: unexpected output returned while installing Linux package: $linux_package\n";
			#push @ERRORS, "Linux package: $linux_package";
		}
		
	}
	
	return 1;
}

#/////////////////////////////////////////////////////////////////////////////

sub install_perl_modules {
	
	eval "use CPAN";
	if ($EVAL_ERROR) {
		print "ERROR: CPAN Perl module is not installed, unable to install other Perl module dependencies\n";
		exit;
	}
	
	$ENV{PERL_MM_USE_DEFAULT} = 1; 
	$ENV{PERL_MM_NONINTERACTIVE} = 1; 
	$ENV{AUTOMATED_TESTING} = 1;
	$ENV{FTP_PASSIVE} = 1;
	
	my $cpan_directory = $ENV{HOME} . '/.cpan';
	my $config_file_path = "$cpan_directory/CPAN/MyConfig.pm";
	`mkdir -p $cpan_directory/CPAN`;
	
	$CPAN::Config = {
		"applypatch" => "",
		"auto_commit" => "1",
		"build_cache" => "1",
		"build_dir" => "$cpan_directory/build",
		"build_requires_install_policy" => "yes",
		"bzip2" => `echo -n \`which bzip2\`` || "",
		"cache_metadata" => "1",
		"check_sigs" => "0",
		"connect_to_internet_ok" => "1",
		"cpan_home" => "$cpan_directory",
		"debug" => "all",
		"curl" => `echo -n \`which curl\`` || "",
		"force" => "1",
		"ftp" => `echo -n \`which ftp\`` || "",
		"ftp_passive" => "1",
		"ftp_proxy" => "",
		"getcwd" => "cwd",
		"gpg" => `echo -n \`which gpg\`` || "",
		"gzip" => `echo -n \`which gzip\`` || "",
		"halt_on_failure" => "0",
		"histfile" => "$cpan_directory/histfile",
		"histsize" => "1000",
		"http_proxy" => "",
		"inactivity_timeout" => "60",
		"index_expire" => "10",
		"inhibit_startup_message" => "1",
		"keep_source_where" => "$cpan_directory/sources",
		"links" => `echo -n \`which links\`` || "",
		"load_module_verbosity" => "1",
		"make" => `echo -n \`which make\`` || "",
		"make_arg" => "",
		"make_install_arg" => "",
		"make_install_make_command" => `echo -n \`which make\`` || "",
		"makepl_arg" => "",
		"mbuild_arg" => "",
		"mbuild_install_arg" => "",
		"mbuild_install_build_command" => "./Build",
		"mbuildpl_arg" => "",
		"ncftp" => "",
		"ncftpget" => "",
		"no_proxy" => "",
		"pager" => `echo -n \`which less\`` || "",
		"perl5lib_verbosity" => "",
		"prefer_installer" => "MB",
		"prefs_dir" => "$cpan_directory/prefs",
		"prerequisites_policy" => "follow",
		"proxy_user" => "",
		"randomize_urllist" => "1",
		"scan_cache" => "never",
		"shell" => `echo -n \`which bash\`` || "",
		"show_upload_date" => "0",
		"tar" => `echo -n \`which tar\`` || "",
		"tar_verbosity" => "0",
		"term_ornaments" => "1",
		"trust_test_report_history" => "1",
		"unzip" => `echo -n \`which unzip\`` || "",
		"urllist" => [q[http://www.perl.com/CPAN/]],
		"use_sqlite" => "0",
		"wget" => `echo -n \`which wget\`` || "",
		"yaml_load_code" => "0",
	};
	
	eval { CPAN::Config->commit($config_file_path) };
	if ($EVAL_ERROR) {
		print "CPAN configuration:\n";
		print Dumper($CPAN::Config) . "\n";
	
		print "\nERROR: failed to create CPAN configuration file: $config_file_path\n";
		exit 1;
	}
	else {
		print "created CPAN configuration file: $config_file_path\n";
	}
	
	print_cpan_configuration();
	
	my @perl_modules = (
		'DBI',
		'Digest::SHA1',
		'Mail::Mailer',
		'Object::InsideOut',
		'RPC::XML',
		'YAML',
	);
	
	for my $perl_module (@perl_modules) {
		print_break('-');
		print "attempting to install Perl module using CPAN: $perl_module\n";
		
		eval { CPAN::Shell->install($perl_module) };
		
		if (!is_perl_module_installed($perl_module)) {
			print "ERROR: failed to install Perl module: $perl_module\n";
			push @ERRORS, "Perl module: $perl_module";
		}
	}
	
	print_break("*");
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
		print "Perl module $module_package appears to be installed but the version could not be determined\ncommand: $command\noutput:\n$output";
		return;
	}
}

#/////////////////////////////////////////////////////////////////////////////

sub run_command {
	my $command = shift;
	
	print "attempting to run command: $command\n";
	my $output = `$command 2>&1`; 
	my $exit_status = $? >> 8;
	print "ran command: $command, exit status: $exit_status\n";
	return ($exit_status, $output);
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
	print $character x 100 . "\n";
}

#/////////////////////////////////////////////////////////////////////////////

sub print_cpan_configuration {
	$Data::Dumper::Sortkeys = 1;
	print "CPAN configuration:\n" . Dumper($CPAN::Config) . "\n";
}
