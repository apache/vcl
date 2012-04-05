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
# Configures the root account on a VCL management node to be able to log on to a
# Windows computer via SSH using an identity key. The IP address or hostname of
# the Windows computer must be supplied as the first argument. An SSH private
# key path can optionally be specified as the 2nd argument. If the 2nd argument
# isn't supplied, the SSH identity key file used is /etc/vcl/vcl.key. The SSH
# identity key files will be created if they don't already exist. Enter the
# Windows computer's root accounts password when prompted.
###############################################################################
function print_hr {
	echo "----------------------------------------------------------------------"
}

#------------------------------------------------------------------------------
function help {
	print_hr
	echo "Usage:"
	echo "$0 <IP or hostname> [SSH identity key path]"
	print_hr
	exit 1
}

#------------------------------------------------------------------------------
function die {
	message=$1
	
	print_hr
	echo "ERROR:"
	
	if [ "$message" != "" ]
	then
		echo $message
	fi
	
	print_hr
	exit 1
}

###############################################################################
# Get the arguments
if [ $# == 0 -o $# -gt 2 ];
then
  help
fi
NODE=$1
KEY_PATH=$2

# Make sure root is running this script
if [ `whoami | grep -ic "root"` -ne 1 ];
then
	die "this script must be run as root"
fi

SSH_OPTIONS="-o CheckHostIP=no -o StrictHostKeyChecking=no -o BatchMode=no"

print_hr

# Set the default key path if argument not specified
if [ "$KEY_PATH" == "" ]
then
  KEY_PATH='/etc/vcl/vcl.key'
  echo Using default SSH identity key path: $KEY_PATH
else
  echo Using specified SSH identity key path: $KEY_PATH
fi

# Check if vcl.key already exists, create it if it doesn't
print_hr
if [ -f "$KEY_PATH" ];
then
  echo SSH key already exists on this management node: "$KEY_PATH"
else
  echo Creating SSH keys on management node: "$KEY_PATH"
  ssh-keygen -t rsa -f "$KEY_PATH" -N '' -b 1024 -C 'VCL root account'
  if [ $? -ne 0 ]; then die "failed to generate SSH keys"; fi;
  echo "IdentityFile $KEY_PATH" >> /etc/ssh/ssh_config
fi
print_hr
 
# Remove existing entries for the node from known_hosts for the node specified by the argument
if [ `grep -ic "^$NODE " /root/.ssh/known_hosts` -ne 0 ];
then
  echo Removing $C entries for $NODE from '/root/.ssh/known_hosts'
  sed -i -r -e "s/^$NODE .*//" /root/.ssh/known_hosts
else
  echo Entry does not exist for $NODE in '/root/.ssh/known_hosts'
fi
print_hr

# Add the node's key to the known hosts file
echo Scanning host key for $NODE and adding it to '/root/.ssh/known_hosts'
ssh-keyscan -t rsa $NODE >> /root/.ssh/known_hosts
print_hr

echo Copying public key to authorized_keys on $NODE
scp $SSH_OPTIONS $KEY_PATH.pub root@$NODE:.ssh/authorized_keys
if [ $? -ne 0 ]; then die "failed to copy $KEY_PATH.pub to $NODE:.ssh/authorized_keys"; fi;
print_hr

#Try to determine OS
OS=`ssh $SSH_OPTIONS -i $KEY_PATH root@$NODE "uname -a"`
case $OS in
   *Ubuntu*) 
      echo "detected Ubuntu OS"
      SSHDCONFIG='/etc/ssh/sshd_config'
      SSHSTOP='service ssh stop'
      SSHSTART='service ssh start'
      ;;  

   *Linux*) 
      echo "detected Linux OS"
      SSHDCONFIG='/etc/ssh/sshd_config'
      SSHSTOP='service sshd stop'
      SSHSTART='service sshd start'
      ;;  
   
   *CYGWIN*) 
      echo "detected Windows OS"
      SSHDCONFIG='/etc/sshd_config'
      SSHSTOP='net stop sshd'
      SSHSTART='net start sshd'
      ;;  

   *Darwin*) 
      echo "detected OSX"
      SSHDCONFIG='/etc/sshd_config'
      SSHSTOP='/bin/launchctl unload /System/Library/LaunchDaemons/ssh.plist'
      SSHSTART='/bin/launchctl load -w /System/Library/LaunchDaemons/ssh.plist'
      ;;  
          
   *)  
      die "Unsupported OS found, OS call reported $OS";;
esac

echo Setting PasswordAuthentication to no in sshd_config on $NODE
ssh $SSH_OPTIONS -i $KEY_PATH root@$NODE 'sed -i -r -e "s/^[ #]*(PasswordAuthentication).*/\1 no/"' $SSHDCONFIG
ssh $SSH_OPTIONS -i $KEY_PATH root@$NODE 'grep "^[ #]*PasswordAuthentication"' $SSHDCONFIG
print_hr

echo Restarting the sshd service on $NODE
ssh $SSH_OPTIONS -i $KEY_PATH root@$NODE "$SSHSTOP ; $SSHSTART "
if [ $? -ne 0 ]; then die "failed to restart the sshd service on $NODE"; fi;
print_hr

echo "SUCCESS: $0 done."
echo
echo "Try to run the following command, it should NOT prompt for a password:"
echo "ssh $SSH_OPTIONS -i $KEY_PATH $NODE"

exit 0
