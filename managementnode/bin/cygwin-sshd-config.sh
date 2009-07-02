##############################################################################
# $Id: $
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
# DESCRIPTION
# Configures the Cygwin SSHD service installed in a Windows image.
# Cygwin and the sshd component must be installed prior to running this script.
# This script should be run on a node which has been installed with a base
# image. After running this script, gen-node-key.sh should be run on a
# management node.
# This script does the following:
# * Stops any running sshd processes and servicies
# * Deletes an existing sshd user account if it exists
# * Deletes existing /etc/ssh* files
# * Sets the correct owner and permissions on several files and directories
# * Recreates the /etc/passwd and /etc/group files
# * Configures the correct system mount points
# * Runs ssh-host-config
# * Sets the following options in /etc/sshd_config:
#   LogLevel=VERBOSE
#   MaxAuthTries=12
#   PasswordAuthentication=yes
#   Banner=none
#   UsePrivilegeSeparation=yes
#   StrictModes=no
#   LoginGraceTime=10
#   Compression=no
# * Configures the sshd service to log to /var/log/sshd.log
# * Grants the log on as a service permission to root
# * Configures the sshd service to run as root
# * Configures the firewall to allow port 22
# * Starts the sshd service

# -----------------------------------------------------------------------------
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
	echo ----------
	
	return 1;
}

# -----------------------------------------------------------------------------

if [ $# -ne 1 ]
then
  echo "Usage: $0 '<root password>'"
  exit 1
fi
PASSWORD=$1

echo Stopping sshd service if it is running
net stop sshd 2>/dev/null
echo ----------

echo Deleting sshd service if it already exists
$SYSTEMROOT/system32/sc.exe delete sshd
echo ----------

echo Deleting the sshd user if it already exists
net user sshd /DELETE
echo ----------

echo Deleting '/etc/ssh*'
rm -fv /etc/ssh*
echo ----------

echo Deleting /var/log/sshd.log if it exists
rm -fv /var/log/sshd.log
echo ----------

echo Setting root:Administrators as owner of '/etc' and '/var'
chown -R root:Administrators /etc /var
echo ----------

echo Adding ug+rwx permissions to '/etc' and '/var'
chmod -v ug+rwx /etc /var
echo ----------

echo Adding read permission on /etc/passwd and /etc/group
chmod -v +r /etc/passwd /etc/group
echo ----------

echo Adding ug+w permission on /etc/passwd and /etc/group
chmod -v ug+w /etc/passwd /etc/group
echo ----------

echo Recreating /etc/group
mkgroup -l > /etc/group
echo ----------

echo Recreating /etc/passwd
mkpasswd -l > /etc/passwd
echo ----------

echo Configuring mount points
umount -u /usr/bin 2>/dev/nul
mount -f -s -b C:/cygwin/bin /usr/bin
umount -u /usr/lib 2>/dev/nul
mount -f -s -b C:/cygwin/lib /usr/lib
umount -u / 2>/dev/nul
mount -f -s -b C:/cygwin /
echo ----------

echo Adding execute permission on /var
chmod -v +x /var
echo ----------

echo Running ssh-host-config
ssh-host-config -y
echo ----------

echo Creating /var/empty directory if it does not exist
mkdir /var/empty 2>/dev/NULL
echo ----------

echo Setting root:Administrators as owner of /var/empty
chown -Rv root:Administrators /var/empty
echo ----------

echo Setting permissions to 755 on /var/empty
chmod -Rv 755 /var/empty
echo ----------

echo Setting permissions to 775 on /var/log
chmod -Rv 775 /var/log
echo ----------

echo Creating /var/log/sshd.log file if it does not exist
touch /var/log/sshd.log
echo ----------

echo Setting root:Administrators as owner of '/etc/ssh*' and /var/log/sshd.log
chown -Rv root:Administrators /etc/ssh* /var/log/sshd.log
echo ----------

echo Setting permissions to ug+rw on '/etc/ssh*' and /var/log/sshd.log
chmod -Rv ug+rw /etc/ssh* /var/log/sshd.log
echo ----------

echo Setting permissions to 600 on '/etc/ssh*key'
chmod -v 600 /etc/ssh*key
echo ----------

echo Setting permissions to ug+rwx on /etc
chmod -v ug+rwx /etc
echo ----------

echo Configuring /etc/sshd_config
set_config '/etc/sshd_config' 'LogLevel'               'VERBOSE'
set_config '/etc/sshd_config' 'MaxAuthTries'           '12'
set_config '/etc/sshd_config' 'PasswordAuthentication' 'yes'
set_config '/etc/sshd_config' 'Banner'                 'none'
set_config '/etc/sshd_config' 'UsePrivilegeSeparation' 'yes'
set_config '/etc/sshd_config' 'StrictModes'            'no'
set_config '/etc/sshd_config' 'LoginGraceTime'         '10'
set_config '/etc/sshd_config' 'Compression'            'no'

echo Configuring the sshd service to log to /var/log/sshd.log
reg.exe ADD "HKLM\SYSTEM\CurrentControlSet\Services\sshd\Parameters" /v AppArgs /d "-D -e" /t REG_SZ /f
echo ----------

echo Configuring the sshd service to use the root account: $PASSWORD
$SYSTEMROOT/system32/sc.exe config sshd obj= ".\root" password= "$PASSWORD"
echo ----------

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

unix2dos $secedit_inf

echo Running secedit.exe to grant root the right to logon as a service
cmd.exe /c $secedit_exe /configure /cfg "$secedit_inf" /db $secedit_db /log $secedit_log /verbose
echo ----------

echo Configuring firewall port 22 exception
netsh firewall set portopening name = "Cygwin SSHD" protocol = TCP port = 22 mode = ENABLE profile = ALL scope = ALL
echo ----------

echo Starting the sshd service
net start sshd
echo ----------

echo /var/log/sshd.log ending:
tail -n 10 /var/log/sshd.log
echo ----------

echo Done
