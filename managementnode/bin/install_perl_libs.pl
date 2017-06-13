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
###############################################################################
use strict;

use English;
use Getopt::Long;

#//////////////////////////////////////////////////////////////////////////////

my @LINUX_PACKAGES = (
	'expat-devel',
	'gcc',
	'krb5-devel',
	'krb5-libs',
	'libxml2-devel',
	'make',
	'nmap',
	'openssl-devel',
	'perl-Archive-Tar',
	'perl-CPAN',
	'perl-Crypt-CBC',
	'perl-Crypt-OpenSSL-RSA',
	'perl-Crypt-Rijndael',
	'perl-DBD-MySQL',
	'perl-DBI',
	'perl-Digest-SHA1',
	'perl-IO-String',
	'perl-JSON',
	'perl-MailTools',
	'perl-Net-Jabber',
	'perl-Net-Netmask',
	'perl-Net-SSH-Expect',
	'perl-RPC-XML',
	'perl-Text-CSV_XS',
	'perl-Time-HiRes',
	'perl-XML-Simple',
	'perl-YAML',
	'xmlsec1-openssl',
);

my @PERL_MODULES = (
	'CPAN',
	'DBI',
	'Digest::SHA1',
	'Frontier::Client',
	'LWP::Protocol::https',
	'Mail::Mailer',
	'Mo::builder',
	'Net::SSH::Expect',
	'Object::InsideOut',
	'RPC::XML',
	'Scalar::Util',
	'Term::ANSIColor',
	'Time::HiRes',
	'URI',
	'YAML',
);
	
# Store the command line options in hash
my $AGREE;
my $INSTALL_LINUX_PACKAGES;
my $INSTALL_PERL_MODULES;
my %OPTIONS;
GetOptions(\%OPTIONS,
	'y!' => \$AGREE,
	'linux!' => \$INSTALL_LINUX_PACKAGES,
	'perl!' => \$INSTALL_PERL_MODULES,
	'help' => \&help,
);

show_disclaimer() if !$AGREE;

my $ERRORS = {};

# Check if -l or -y was specified
if (!defined($INSTALL_PERL_MODULES) && !defined($INSTALL_LINUX_PACKAGES)) {
	$INSTALL_PERL_MODULES = 1;
	$INSTALL_LINUX_PACKAGES = 1;
}
elsif (defined($INSTALL_PERL_MODULES) && !defined($INSTALL_LINUX_PACKAGES)) {
	$INSTALL_LINUX_PACKAGES = !$INSTALL_PERL_MODULES;
}
elsif (defined($INSTALL_LINUX_PACKAGES) && !defined($INSTALL_PERL_MODULES)) {
	$INSTALL_PERL_MODULES = !$INSTALL_LINUX_PACKAGES;
}

if ($INSTALL_LINUX_PACKAGES) {
	print_break('=');
	# Check if yum is available
	my ($which_exit_status, $which_output) = run_command("which yum");
	if ($which_exit_status ne '0') {
		print "WARNING: yum is not available on this OS, skipping Linux package installation\n";
		return 0;
	}
	else {
		install_epel();
		print_break('=');
		install_linux_packages();
	}
}

if ($INSTALL_PERL_MODULES) {
	print_break('=');
	install_perl_modules();
}

print_break('=');

my $error_encountered;
for my $key (keys %$ERRORS) {
	for my $component (sort keys %{$ERRORS->{$key}}) {
		print "WARNING: failed to install $key: $component\n";
		$error_encountered++;
	}
}

if (!$error_encountered) {
	print "COMPLETE: installed all components\n";
	exit 0;
}
else {
	exit 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_epel

 Parameters  : none
 Returns     : boolean
 Description : Creates a temporary /etc/yum.repos.d/epel-install.repo file and
               installs the epel-release package.

=cut

sub install_epel {
	my $epel_install_repo_path = '/etc/yum.repos.d/epel-install.repo';
	
	my $epel_install_repo_contents = <<EOF;
[epel-install]
name=EPEL Repository
mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=epel-\$releasever&arch=\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
EOF
	
	unlink $epel_install_repo_path;
	
	print "Creating file: $epel_install_repo_path\n";
	if (!open FILE, ">", $epel_install_repo_path) {
		print "ERROR: failed to create file: $epel_install_repo_path\n";
		exit 1;
	}
	if (!print FILE $epel_install_repo_contents) {
		print "ERROR: failed to write to file: $epel_install_repo_path\n";
		exit 1;
	}
	close FILE;
	
	my $result = yum_install_linux_package('epel-release');
	
	if (unlink $epel_install_repo_path) {
		print "Removed file: $epel_install_repo_path\n";
	}
	else {
		print "WARNING: failed to remove file: $epel_install_repo_path\n";
	}
	
	return $result;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_linux_packages

 Parameters  : none
 Returns     : boolean
 Description : Installs the Linux operating system packages required by the VCL
               managment node components.

=cut

sub install_linux_packages {
	for my $linux_package (@LINUX_PACKAGES) {
		print_break('*');
		if (!yum_install_linux_package($linux_package)) {
			$ERRORS->{'Linux package'}{$linux_package} = 1;
		}
	}
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 yum_install_linux_package

 Parameters  : $linux_package
 Returns     : boolean
 Description : Attempts to install a single Linux package using yum.

=cut

sub yum_install_linux_package {
	my ($linux_package) = @_;
	if (!$linux_package) {
		print "ERROR: package name argument was not provided\n";
		return;
	}
	
	print "Attempting to install Linux package using yum: $linux_package\n";
	
	my $yum_command = "yum install $linux_package -y --nogpgcheck";
	#print "Yum command: $yum_command\n";
	
	my $yum_output = `$yum_command 2>&1 | grep -v '^\\(Load\\|Setting\\|Nothing\\| \\*\\)'`;
	my $yum_exit_status = $? >> 8;
	
	chomp $yum_output;
	print "$yum_output\n\n";
	
	if ($yum_exit_status ne '0') {
		print "WARNING: failed to install Linux package: '$linux_package', exit status: $yum_exit_status\n";
		return 0;
	}
	elsif ($yum_output =~ /$linux_package[^\n]*already installed/i) {
		print "SUCCESS: Linux package is already installed: $linux_package\n";
	}
	elsif ($yum_output =~ /Complete\!/i) {
		print "SUCCESS: installed Linux package: $linux_package\n";
	}
	elsif ($yum_output =~ /No package.*available/i) {
		print "WARNING: Linux package is not available via yum: $linux_package\n";
		return 0;
	}
	else {
		print "WARNING: unexpected output returned while installing Linux package: $linux_package\n";
		return 0;
	}
	
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 configure_cpan

 Parameters  : none
 Returns     : boolean
 Description : Attempts to configure CPAN so that modules can be installed
               without user interaction.

=cut

sub configure_cpan {
	eval {
		require CPAN;
	};
	if ($EVAL_ERROR) {
		print "Unable to install Perl modules, CPAN module could not be loaded.\n";
		exit 1;
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
		"curl" => `echo -n \`which curl\`` || "",
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
		"tar_verbosity" => "",
		"term_ornaments" => "1",
		"trust_test_report_history" => "1",
		"unzip" => `echo -n \`which unzip\`` || "",
		"urllist" => [q[http://cpan-rsync.perl.org/]],
		"use_sqlite" => "0",
		"wget" => `echo -n \`which wget\`` || "",
		"yaml_load_code" => "0",
	};
	
	# Use $CPAN::Config once to avoid warning
	if ($CPAN::Config) {};
	
	eval { CPAN::Config->commit($config_file_path) };
	if ($EVAL_ERROR) {
		print "\nERROR: failed to create CPAN configuration file: $config_file_path\n$EVAL_ERROR\n";
		exit 1;
	}
	else {
		print "Created CPAN configuration file: $config_file_path\n";
	}
	
}

#//////////////////////////////////////////////////////////////////////////////

=head2 install_perl_modules

 Parameters  :
 Returns     :
 Description :

=cut

sub install_perl_modules {
	eval { require CPAN };
	if ($EVAL_ERROR) {
		print "ERROR: failed to install perl modules, CPAN module is not available\n";
		$ERRORS->{'Perl module'}{'ALL'} = 1;
		return;
	}
	print "Running CPAN version: $CPAN::VERSION\n";

	configure_cpan();

	PERL_MODULE: for my $perl_module (@PERL_MODULES) {
		print_break('*');
		
		my $cpan_version = get_perl_module_cpan_version($perl_module);
		if (!$cpan_version) {
			print "ERROR: unable to install $perl_module Perl module, information could not be obtained from CPAN\n";
			$ERRORS->{'Perl module'}{$perl_module} = 1;
			next PERL_MODULE;
		}
		
		# Check if installed version matches what is available from CPAN
		my $installed_version = get_perl_module_installed_version($perl_module);
		if ($installed_version && $installed_version eq $cpan_version) {
			print "$perl_module Perl module is up to date\n";
		}
		else {
		
			# Check if the CPAN module implements the "notest" method
			# This is not available in older versions of CPAN.pm
			if (CPAN::Shell->can('notest')) {
				print "Attempting to install (notest, force) Perl module using CPAN: $perl_module\n";
				eval { CPAN::Shell->rematein("notest", "force", "install", $perl_module) };
				#eval { CPAN::Shell->notest("force install", $perl_module) };
			}
			else {
				print "Attempting to install (force) Perl module using CPAN: $perl_module\n";
				eval { CPAN::Shell->rematein("force", "install", $perl_module) };
				#eval { CPAN::Shell->force("install", $perl_module) };
			}
			
			# Check if the module was successfully installed
			$installed_version = get_perl_module_installed_version($perl_module);
			if (!$installed_version) {
				print "ERROR: failed to install $perl_module Perl module\n";
				$ERRORS->{'Perl module'}{$perl_module} = 1;
				next PERL_MODULE;
			}
		}
		
		# Check if corresponding Linux package failed - remove from %ERRORS
		my $linux_package_name = "perl-$perl_module";
		$linux_package_name =~ s/::/-/g;
		if (defined $ERRORS->{'Linux package'}{$linux_package_name}) {
			print "Removed $linux_package_name from list of failed Linux packages\n";
			delete $ERRORS->{'Linux package'}{$linux_package_name};
		}
	}
	
	print_break("*");
	return 1;
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_perl_module_installed_version

 Parameters  : $perl_module
 Returns     :
 Description :

=cut

sub get_perl_module_installed_version {
	my $perl_module = shift;
	
	my $cpan_module = CPAN::Shell->expand("Module", $perl_module);
	if ($cpan_module) {
		my $cpan_installed_version = $cpan_module->inst_version;
		
		if ($cpan_installed_version) {
			print "$perl_module $cpan_installed_version Perl module is installed\n";
			return $cpan_installed_version;
		}
		else {
			print "$perl_module Perl module is NOT installed\n";
			return;
		}
	}
	else {
		print "$perl_module Perl module information could not be obtained from CPAN, checking if it is installed on local computer\n";
		
		my $command = "perl -e \"eval \\\"use $perl_module\\\"; print \\\$" . $perl_module . "::VERSION\" 2>&1";
		my $output = `$command`;
		my $exit_status = $? >> 8;
		
		if ($output =~ /Can't locate/i) {
			print "$perl_module Perl module is NOT installed\n";
			return;
		}
		
		my ($version) = $output =~ /^(\d[\d\.]+\d)$/;
		if (defined($version)) {
			print "$perl_module Perl module is installed, version: $version\n";
			return $version;
		}
		else {
			print "$perl_module Perl module appears to be installed but the version could not be determined\ncommand: $command\noutput:\n$output\n";
			return;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 get_perl_module_cpan_version

 Parameters  : $perl_module
 Returns     :
 Description :

=cut

sub get_perl_module_cpan_version {
	my $perl_module = shift;
	
	my $cpan_module = CPAN::Shell->expand("Module", $perl_module);
	if ($cpan_module) {
		my $cpan_source_version = $cpan_module->cpan_version;
		
		if ($cpan_source_version) {
			print "$perl_module $cpan_source_version Perl module is available from CPAN\n";
			return $cpan_source_version;
		}
		else {
			print "WARNING: $perl_module Perl module appears to be available from CPAN but version could not be obtained\n";
			return;
		}
	}
	else {
		print "WARNING: $perl_module Perl module is NOT available from CPAN\n";
		return;
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 run_command

 Parameters  : $command
 Returns     : array ($exit_status, $output)
 Description :

=cut

sub run_command {
	my $command = shift;
	
	print "Attempting to execute command: '$command'\n";
	my $output = `$command 2>&1`; 
	my $exit_status = $? >> 8;
	print "Executed command: '$command', exit status: $exit_status\n";
	return ($exit_status, $output);
}

#//////////////////////////////////////////////////////////////////////////////

=head2 show_disclaimer

 Parameters  : none
 Returns     : 
 Description :

=cut

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
			exit 2;
		}
		else {
			next;
		}
	}
}

#//////////////////////////////////////////////////////////////////////////////

=head2 print_break

 Parameters  : $character (optional)
 Returns     :
 Description :

=cut

sub print_break {
	my $character = shift;
	$character = '-' if !defined($character);
	print $character x 100 . "\n";
}

#//////////////////////////////////////////////////////////////////////////////

=head2 help

 Parameters  : none
 Returns     : exits
 Description :

=cut

sub help {
	print <<EOF;
Usage: perl $0 [OPTION]...
Install all of the Linux packages and Perl modules required by the VCL
management node daemon (vcld).

  -y             skip license agreement
  -l, --linux    install Linux packages
  -p, --perl     install Perl modules
  --help         display this help and exit

If no -l or -p option is specified, Linux packages and Perl modules are both
installed.
EOF
	exit 0;
}

#//////////////////////////////////////////////////////////////////////////////

1;
__END__

=head1 SEE ALSO

L<http://cwiki.apache.org/VCL/>

=cut

