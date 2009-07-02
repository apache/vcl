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
# Configures a VCL management node to be able to control a remote node using SSH
# keys. The IP address or hostname of a remote node which has already been
# configured to respond to SSH must be supplied as an argument. This script does
# the following:
# * Generates an 1024 bit RSA SSH public/private key pair if it doesn't already
#   exist. Location:
#   Private key: /etc/vcl/vcl.key
#   Public key: /etc/vcl/vcl.key.pub
# * Configures the ssh_config file on the management node to use the following
#   options:
#   StrictHostKeyChecking=no
# * Removes any existing entries in the known_hosts file for the node specified
# * Adds the current host key of the node specified to the known_hosts file
# * Adds the vcl.key.pub public key to the authorized_keys file on the specified
#   host
# * Configures the sshd_config file on the specified host with the following
#   options:
#   PermitRootLogin=no
#   PasswordAuthentication=no
# * Restarts the sshd service on the specified node

if [ $# -ne 1 ]
then
  echo "Usage: $0 <node>"
  exit 1
fi
NODE=$1

# Check if vcl.key already exists, create it if it doesn't
echo ----------
if [ -f '/etc/vcl/vcl.key' ];
then
  echo SSH key already exists on this management node: '/etc/vcl/vcl.key'
else
  echo Creating SSH keys on management node: '/etc/vcl/vcl.key(.pub)'
  mkdir -p /etc/vcl
  ssh-keygen -t rsa -f /etc/vcl/vcl.key -N '' -b 1024 -C 'root on VCL management node'
  echo "IdentityFile /etc/vcl/vcl.key" >> /etc/ssh/ssh_config
fi
echo ----------

echo Setting StrictHostKeyChecking to no in ssh_config on this management node
sed -i -r -e "s/^[ #]*(StrictHostKeyChecking).*/\1 no/" /etc/ssh/ssh_config
grep -i -r "^[ #]*StrictHostKeyChecking" /etc/ssh/ssh_config
echo ----------
 
# Remove existing entries for the node from known_hosts for the node specified by the argument
if [ `grep -ic $NODE /root/.ssh/known_hosts` -ne 0 ];
then
  echo Removing $C entries for $NODE from '/root/.ssh/known_hosts'
  sed -i -r -e "s/.*$NODE.*//" /root/.ssh/known_hosts
else
  echo Entry does not exist for $NODE in '/root/.ssh/known_hosts'
fi
echo ----------

echo Scanning host key for $NODE and adding it to '/root/.ssh/known_hosts'
ssh-keyscan -t rsa $NODE >> /root/.ssh/known_hosts

echo Copying public key to authorized_keys on $NODE
ssh-copy-id -i /etc/vcl/vcl.key.pub $NODE
echo ----------

echo Setting PermitRootLogin to no in sshd_config on $NODE
ssh -i /etc/vcl/vcl.key root@$NODE 'sed -i -r -e "s/^[ #]*(PermitRootLogin).*/\1 no/" /etc/sshd_config'
ssh -i /etc/vcl/vcl.key root@$NODE 'grep "^[ #]*PermitRootLogin" /etc/sshd_config'
echo ----------

echo Setting PasswordAuthentication to no in sshd_config on $NODE
ssh -i /etc/vcl/vcl.key root@$NODE 'sed -i -r -e "s/^[ #]*(PasswordAuthentication).*/\1 no/" /etc/sshd_config'
ssh -i /etc/vcl/vcl.key root@$NODE 'grep "^[ #]*PasswordAuthentication" /etc/sshd_config'
echo ----------

echo Restarting the sshd service on $NODE
ssh -i /etc/vcl/vcl.key root@$NODE 'net stop sshd ; net start sshd'
echo ----------

echo Done, the following command should work:
echo "ssh -i /etc/vcl/vcl.key $NODE"

exit 0