#!/bin/bash
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
# DESCRIPTION
# Configures the Cygwin SSHD service installed on a Windows computer.
# Cygwin and the sshd component must be installed prior to running this script.
# This script must be run as root on the Windows computer. The root account's
# password must be supplied as the 1st and only argument to this script. Enclose
# the password in single quotes if it contains special characters. After this
# script completes successfully, the sshd service should be running on the
# Windows computer. After running this script, gen-node-key.sh must be run on a
# management node with the Windows computer's hostname or IP address specified as the 1st
# argument. This will copy root's public SSH identity key to the
# authorized_hosts file on the Windows computer and disable password
# authentication.
###############################################################################
# Name        : set_config
# Parameters  : [config_file] [keyword] [value]
# Returns     : always 1
# Description : Finds and sets the keyword to the value specified in an SSH
#               configuration file. This function should work with ssh_config
#               and sshd_config files.
#               Example: set_config /etc/ssh_config Compression no
#               This should find the line in ssh_config beginning with either of
#               the following:
#                 # Compression <existing value>
#                 Compression <existing value>
#               And change the line to:
#                 Compression no
function set_config {
	if [ $# -ne 3 ]
	then
	  echo "usage: set_config [config_file] [keyword] [value]"
	  exit 1
	fi

	config_file=$1
	keyword=$2
	value=$3
	
	echo Setting $keyword to $value in $config_file
	sed -i -r -e "s/^[ #]*($keyword).*/\1 $value/" $config_file
	grep -i -r "^[ #]*$keyword" $config_file
	print_hr
	
	return 1;
}

#------------------------------------------------------------------------------
function print_hr {
	echo "----------------------------------------------------------------------"
}

#------------------------------------------------------------------------------
function help {
	print_hr
	echo "Usage: $0 '<root password>'"
	print_hr
	exit 1
}

#------------------------------------------------------------------------------
function die {
   exit_status=$?
	message=$1
	
	print_hr
	echo "ERROR: ($exit_status)"
	
	if [ "$message" != "" ]
	then
		echo $message
	fi
	
	print_hr
	exit 1
}

###############################################################################
# Get the Windows root account password argument
if [ $# -ne 1 ]
then
  help
fi
PASSWORD=$1

print_hr

# Detect Cygwin path
CYGWINDOSPATH=`cygpath -d /`

CYGPATH="$(echo $CYGWINDOSPATH | tr '\\' '/')"

echo $CYGPATH

# Configure Cygwin mount points
# ssh-host-config will fail if the mount points are configured as user instead of system
echo Configuring mount points

$CYGPATH/bin/umount.exe -u /usr/bin 2>/dev/null
$CYGPATH/bin/mount.exe -f $CYGPATH/bin /usr/bin
ls /usr/bin >/dev/null
if [ $? -ne 0 ]; then die "failed to configure /usr/bin mount point"; fi;

$CYGPATH/bin/umount.exe -u /usr/lib 2>/dev/null
$CYGPATH/bin/mount.exe -f $CYGPATH/lib /usr/lib
ls /usr/lib >/dev/null
if [ $? -ne 0 ]; then die "failed to configure /usr/lib mount point"; fi;

$CYGPATH/bin/umount.exe -u / 2>/dev/null
$CYGPATH/bin/mount.exe -f $CYGPATH /
ls / >/dev/null
if [ $? -ne 0 ]; then die "failed to configure / mount point"; fi;

mount
print_hr

# Stop and kill all sshd processes
echo Stopping sshd service if it is running
net stop sshd 2>/dev/null
print_hr

echo Killing any sshd.exe processes
taskkill.exe /IM sshd.exe /F 2>/dev/null
print_hr

echo Killing any cygrunsrv.exe processes
taskkill.exe /IM cygrunsrv.exe /F 2>/dev/null
print_hr

# Delete the sshd service if it already exists
echo Deleting sshd service if it already exists
$SYSTEMROOT/system32/sc.exe delete sshd
print_hr

# Make sure sshd service registry key is gone
# sc.exe may have set a pending deletion registry key under sshd
# This prevents the service from being reinstalled
echo Deleting sshd service registry key
reg.exe DELETE 'HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\sshd' /f
print_hr

# Delete sshd user, a new account will be created
echo Deleting the sshd user if it already exists
net user sshd /DELETE
print_hr

# Delete cyg_server user, a new account will be created
echo Deleting the cyg_server user if it already exists
net user cyg_server /DELETE
print_hr

# Delete any existing ssh configuration or key files
echo Deleting '/etc/ssh*'
rm -fv /etc/ssh*
print_hr

# Delete existing ssh log file
echo Deleting /var/log/sshd.log if it exists
rm -fv /var/log/sshd.log
print_hr

# ssh-host-config requires several permissions to be set in order for it to complete
echo Setting root:Administrators as owner of '/etc' and '/var'
chown -R root:Administrators /etc /var
print_hr

echo Adding ug+rwx permissions to '/etc' and '/var'
chmod -v ug+rwx /etc /var
print_hr

echo Adding read permission on /etc/passwd and /etc/group
chmod -v +r /etc/passwd /etc/group
print_hr

echo Adding ug+w permission on /etc/passwd and /etc/group
chmod -v ug+w /etc/passwd /etc/group
print_hr

# Recreate Cygwin's group and passwd files so they match current computer accounts
echo Recreating /etc/group
mkgroup -l localhost > /etc/group
if [ $? -ne 0 ]; then die "failed to recreate /etc/group"; fi;
print_hr

echo Recreating /etc/passwd
mkpasswd -l localhost > /etc/passwd
if [ $? -ne 0 ]; then die "failed to recreate /etc/passwd"; fi;
print_hr

echo Adding execute permission on /var
chmod -v +x /var
print_hr

# Make sure root owns everything in its home directory
echo Setting root:None as the owner of /home/root
chown -R root:None /home/root
print_hr

# Delete existing SSH settings and files in root's home directory
echo Deleting /home/root/.ssh directory if it exists
rm -rfv /home/root/.ssh
print_hr

# Run ssh-user-config, this creates the .ssh directory in root's home directory
echo Running ssh-user-config
ssh-user-config -n
if [ $? -ne 0 ]; then die "failed to run ssh-user-config"; fi;
print_hr

# Run ssh-host-config, this is the main sshd service configuration utility
echo Running ssh-host-config
ssh-host-config -y -c "nodosfilewarning ntsec" -w "$PASSWORD"
if [ $? -ne 0 ]; then die "failed to run ssh-host-config"; fi;
print_hr

# sshd service requires some directories under /var to be configured as follows in order to start
echo Creating /var/empty directory if it does not exist
mkdir /var/empty 2>/dev/NULL
print_hr

echo Setting root:Administrators as owner of /var/empty
chown -Rv root:Administrators /var/empty
print_hr

echo Setting permissions to 755 on /var/empty
chmod -Rv 755 /var/empty
print_hr

echo Setting permissions to 775 on /var/log
chmod -Rv 775 /var/log
print_hr

echo Creating /var/log/sshd.log
touch /var/log/sshd.log
print_hr

echo Setting root:Administrators as owner of '/etc/ssh*' and /var/log/sshd.log
chown -Rv root:Administrators /etc/ssh* /var/log/sshd.log
print_hr

echo Setting permissions to ug+rw on '/etc/ssh*' and /var/log/sshd.log
chmod -Rv ug+rw /etc/ssh* /var/log/sshd.log
print_hr

# Make sure host key permissions are correct
echo Setting permissions to 600 on '/etc/ssh*key'
chmod -v 600 /etc/ssh*key
print_hr

echo Setting permissions to ug+rwx on /etc
chmod -v ug+rwx /etc
print_hr

# Configure the sshd_config file
echo Configuring /etc/sshd_config
set_config '/etc/sshd_config' 'LogLevel'               'VERBOSE'
set_config '/etc/sshd_config' 'MaxAuthTries'           '12'
set_config '/etc/sshd_config' 'PasswordAuthentication' 'yes'
set_config '/etc/sshd_config' 'Banner'                 'none'
set_config '/etc/sshd_config' 'UsePrivilegeSeparation' 'yes'
set_config '/etc/sshd_config' 'StrictModes'            'no'
set_config '/etc/sshd_config' 'LoginGraceTime'         '30'
set_config '/etc/sshd_config' 'Compression'            'no'
set_config '/etc/sshd_config' 'IgnoreUserKnownHosts'   'yes'
set_config '/etc/sshd_config' 'PrintLastLog'           'no'
set_config '/etc/sshd_config' 'RSAAuthentication'      'no'
set_config '/etc/sshd_config' 'UseDNS'                 'no'
set_config '/etc/sshd_config' 'PermitRootLogin'        'no'

# Add switches to the sshd service startup command so that it logs to a file
echo Configuring the sshd service to log to /var/log/sshd.log
reg.exe ADD "HKLM\SYSTEM\CurrentControlSet\Services\sshd\Parameters" /v AppArgs /d "-D -e" /t REG_SZ /f
print_hr

# Configure the sshd service to run as root
echo Configuring the sshd service to use the root account: $PASSWORD
$SYSTEMROOT/system32/sc.exe config sshd obj= ".\root" password= "$PASSWORD"
print_hr

# Run secedit.exe to grant root the right to logon as a service
# Assemble the paths secedit needs
secedit_exe="C:\\WINDOWS\\system32\\secedit.exe"
secedit_inf='C:\\WINDOWS\\security\\templates\\root_logon_service.inf'
secedit_db="C:\\WINDOWS\\security\\Database\\root_logon_service.sdb"
secedit_log="C:\\WINDOWS\\security\\Logs\\root_logon_service.log"

# Create the security template file
echo Creating the security template to grant root the right to logon as a service
cat >$secedit_inf <<EOF
[Privilege Rights]
SeServiceLogonRight = root
[Version]
signature="\$WINDOWS NT\$"
EOF

# Make sure security .inf file is formatted for DOS
unix2dos $secedit_inf

echo Running secedit.exe to grant root the right to logon as a service
cmd.exe /c $secedit_exe /configure /cfg "$secedit_inf" /db $secedit_db /log $secedit_log /verbose
print_hr

# Get the Windows version
WINDOWS_VERSION=`/cygdrive/c/Windows/system32/cmd.exe /c ver`
[[ $WINDOWS_VERSION =~ ([0-9]+)\. ]]
WINDOWS_VERSION=${BASH_REMATCH[1]}
echo Windows version: $WINDOWS_VERSION

# Create firewall exception for sshd TCP port 22 traffic
if [ $WINDOWS_VERSION -gt 5 ]; then
	echo Configuring sshd firewall port 22 exception for Windows 6.x and later
	netsh.exe advfirewall firewall delete rule name=all dir=in protocol=TCP localport=22
	netsh.exe advfirewall firewall add rule name="VCL: allow SSH port 22 from any address" description="Allows incoming SSH (TCP port 22) traffic from any address" protocol=TCP localport=22 action=allow enable=yes dir=in localip=any remoteip=any
else
	echo Configuring sshd firewall port 22 exception for Windows 5.x and earlier
	netsh.exe firewall set portopening name = "Cygwin SSHD" protocol = TCP port = 22 mode = ENABLE profile = ALL scope = ALL
fi

if [ $? -ne 0 ]; then die "failed to configure sshd firewall port 22 exception"; fi;
print_hr

# Generate a batch file which kills all Cygwin processes and runs rebaseall
# All Cygwin processes must be killed in order to run rebaseall
# The batch file causes the Cygwin bash process running this script to die
REBASEALL_PATH_CYGWIN=/home/root/cygwin-rebaseall.cmd
REBASEALL_PATH_DOS=$CYGWINDOSPATH\\home\\root\\cygwin-rebaseall.cmd

echo Generating $REBASEALL_PATH_CYGWIN
rm -f $REBASEALL_PATH_CYGWIN

(cat -v <<EOF
@echo off

set SCRIPT_NAME=%~n0
set SCRIPT_FILENAME=%~nx0
set SCRIPT_DIR=%~dp0
rem Remove trailing slash from SCRIPT_DIR
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

echo ======================================================================
echo %SCRIPT_FILENAME% beginning to run at: %DATE% %TIME%
echo Directory %SCRIPT_FILENAME% is running from: %SCRIPT_DIR%
echo.

echo Killing Cygwin processes in order to run rebaseall
taskkill.exe /F /FI "IMAGENAME eq cyg*" 2>NUL
taskkill.exe /F /FI "IMAGENAME eq bash*" 2>NUL
taskkill.exe /F /FI "IMAGENAME eq ssh*" 2>NUL
taskkill.exe /F /FI "IMAGENAME eq mintty*" 2>NUL
taskkill.exe /F /FI "IMAGENAME eq sh.exe" 2>NUL
echo.

echo Waiting 3 seconds for processes to die
ping localhost -n 1 -w 30000 >NUL
echo.

echo Running /usr/bin/rebaseall in the ash shell ${CYGWINDOSPATH}\bin\ash.exe
${CYGWINDOSPATH}\bin\ash.exe -c '/usr/bin/rebaseall'
echo rebaseall exit status: %ERRORLEVEL%
IF ERRORLEVEL 1 exit /b %ERRORLEVEL%
echo.

echo Starting Cygwin SSHD service
net start sshd
IF ERRORLEVEL 1 exit /b %ERRORLEVEL%

echo /var/log/sshd.log ending:
${CYGWINDOSPATH}\bin\tail.exe -n 10 /var/log/sshd.log

echo ======================================================================
echo SUCCESS: %SCRIPT_FILENAME% done.
echo.
echo IMPORTANT! Now run gen-node-key.sh on the management node,
echo specify this computer's hostname or IP address as the 1st argument.
EOF
) > $REBASEALL_PATH_CYGWIN

echo Calling $REBASEALL_PATH_DOS
/cygdrive/C/Windows/System32/cmd.exe /k start "$REBASEALL_PATH_DOS"

#exit 0
