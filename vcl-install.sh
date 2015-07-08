#!/bin/bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function print_break() {
	echo "------------------------------------------------------------------------------------------"
}

function random_string() {
	local string_length
	if [[ -n $1 ]]; then string_length=$1; else string_length=8; fi
	random_string=</dev/urandom tr -dc A-Za-z0-9 | head -c $string_length
	echo $random_string
}

function help() {
	name=`basename $0`
	echo ""
	echo "$name [-h|--help] [-d|--database] [-w|--web] [-m|--managementnode]"
	echo -e "\t\t[--dbhost <hostname> --dbpass <password>] "
	echo -e "\t\t[--mnhost <hostname>] [--webhost <hostname>]"
	echo ""
	echo -e "\t-d|--database - install database server components"
	echo -e "\t\t--dbpass, --mnhost, --mnip, --webhost, and --adminpass must also be specified"
	echo ""
	echo -e "\t-w|--web - install web server components"
	echo -e "\t\t--dbhost and --dbpass must also be specified"
	echo ""
	echo -e "\t-m|--managementnode - install management node (vcld) components"
	echo -e "\t\t--dbhost, --dbpass, and --adminpass must also be specified"
	echo ""
	echo -e "\t--dbhost <hostname> - hostname of database server (default=localhost)"
	echo ""
	echo -e "\t--dbpass <password> - password VCL will use for accessing"
	echo -e "\t\tdatabase (default=random)"
	echo ""
	echo -e "\t--mnhost <hostname> - hostname of management node (default=localhost)"
	echo ""
	echo -e "\t--webhost <hostname> - hostname of web server (default=localhost)"
	echo ""
	echo -e "\t--adminpass <password> - password for VCL admin user"
	echo ""
	echo "If no arguments supplied, all components will be install and you"
	echo "will be prompted for any required additional information."
	echo ""
	exit 2
}

args=$(getopt -q -o dwmh -l database,web,managementnode,help,dbhost:,dbpass:,mnhost:,mnip:,webhost:,adminpass:,rc: -n $0 -- "$@")

if [ $? -ne 0 ]; then help; fi

eval set -- "$args"

# ------------------------- variables -------------------------------
VCL_VERSION=2.4.2
DB_USERNAME=vcluser
ADMIN_PASSWORD=

DB_HOST=localhost
DB_PASSWORD=`random_string 15`
MN_HOST=localhost
WEB_HOST=localhost
CRYPTKEY=`random_string 20`
PEMKEY=`random_string 20`
ARCHIVE=apache-VCL-$VCL_VERSION.tar.bz2
ARCHIVEURLPATH="http://vcl.apache.org/downloads/download.cgi?action=download&filename=%2Fvcl%2F$VCL_VERSION%2F"
SIGPATH="http://www.apache.org/dist/vcl/"

DODB=0
DOWEB=0
DOMN=0
DOALL=1
dbhostdefault=1
dbpassdefault=1
mnhostdefault=1
mnipdefault=1
adminpassdefault=1
webhostdefault=1
DODHCP=no
dorc=0

while true; do
	case "$1" in
		-d|--database)
			DODB=1
			DOALL=0
			shift
			;;
		-w|--web)
			DOWEB=1
			DOALL=0
			shift
			;;
		-m|--managementnode)
			DOMN=1
			DOALL=0
			shift
			;;
		--dbhost)
			DB_HOST=$2
			dbhostdefault=0
			shift 2
			;;
		--dbpass)
			DB_PASSWORD=$2
			dbpassdefault=0
			shift 2
			;;
		--mnhost)
			MN_HOST=$2
			mnhostdefault=0
			shift 2
			;;
		--mnip)
			PUBIP=$2
			mnipdefault=0
			shift 2
			;;
		--webhost)
			WEB_HOST=$2
			webhostdefault=0
			shift 2
			;;
		--adminpass)
			ADMIN_PASSWORD=$2
			adminpassdefault=0
			shift 2
			;;
		--rc)
			RC=$2
		   dorc=1
			shift 2
			;;
		-h|--help)
			help
			exit 1
			;;
		--)
			shift
			break
			;;
		*)
			echo "unknown option: $1"
			exit 1
			;;
	esac
done

if [[ $dorc -eq 1 ]]; then
	if [[ ! $RC =~ ^[0-9]+$ ]]; then
		echo ""
		echo "Invalid value specified for --rc=, must be a number"
		echo ""
		exit 1
	fi
	VCL_VERSION=${VCL_VERSION}-RC$RC
	ARCHIVE=apache-VCL-$VCL_VERSION.tar.bz2
	ARCHIVEURLPATH="http://people.apache.org/~jfthomps/apache-VCL-${VCL_VERSION}/"
	SIGPATH="http://people.apache.org/~jfthomps/apache-VCL-${VCL_VERSION}/"
fi

if [[ $DOALL -eq 1 ]]; then
	DODB=1
	DOWEB=1
	DOMN=1
fi

if [[ $DODB -eq 1 && $DOWEB -eq 1 && $DOMN -eq 1 ]]; then
	DOALL=1
fi

if [[ $DODB -eq 1 && ($DOWEB -eq 0 || $DOMN -eq 0) && ($dbpassdefault -eq 1 || $mnhostdefault -eq 1 || $mnipdefault -eq 1 || $webhostdefault -eq 1 || $adminpassdefault -eq 1) ]]; then
	echo ""
	echo "Error missing arguments:"
	echo ""
	echo -e "\t-d or --database was specified but one of --dbpass, --mnhost,"
	echo -e "\t--mnip, --webhost, or --adminpass was missing"
	echo ""
	exit 1
fi

if [[ $DOWEB -eq 1 && ($DODB -eq 0 || $DOMN -eq 0) && ($dbhostdefault -eq 1 || $dbpassdefault -eq 1) ]]; then
	echo ""
	echo "Error missing arguments:"
	echo ""
	echo -e "\t-w or --web was specified but one of --dbhost or --dbpass was missing"
	echo ""
	exit 1
fi

if [[ $DOMN -eq 1 && ($DODB -eq 0 || $DOWEB -eq 0) && ($dbhostdefault -eq 1 || $dbpassdefault -eq 1 || $adminpassdefault -eq 1) ]]; then
	echo ""
	echo "Error missing arguments:"
	echo ""
	echo -e "\t-m or --managementnode was specified but one of --dbhost,"
	echo -e "\t--dbpass, or --adminpass was missing"
	echo ""
	exit 1
fi

if [[ $adminpassdefault -eq 0 && ($ADMIN_PASSWORD = ^[[:space:]]+$ || $ADMIN_PASSWORD = "") ]]; then
	echo ""
	echo "Invalid value for admin password. Admin password cannot be empty"
	echo "or contain only whitespace."
	echo ""
	exit 1
fi

# ------------------------- check for being root -----------------------------
who=$(whoami)
if [[ $who != "root" ]]; then
	echo "You must be root to run this script."
	exit 1
fi

WORKPATH=$(pwd)

if [[ -f NOTICE && -f LICENSE && -d managementnode && -d web && -d mysql ]]; then
	WORKPATH=$(dirname `pwd`)
fi

# ------------------- checks for existing installation -----------------------
echo ""
echo "This script will exit if any existing parts of VCL are found. If they exist, you"
echo "must manually clean them up before using this script to install VCL. Checking"
echo "for existing VCL components..."
echo ""
# database
if [[ $DODB -eq 1 ]]; then
	mysql -e "use vcl;" &> /dev/null
	if [ $? -eq 0 ]; then echo "Existing vcl database found, exiting"; exit 1; fi
fi
# web code
if [[ $DOWEB -eq 1 ]]; then
	if [ -d /var/www/html/vcl ]; then echo "Existing web code found at /var/www/html/vcl, exiting"; exit 1; fi
fi
# management code
if [[ $DOMN -eq 1 ]]; then
	if [ -d /usr/local/vcl ]; then echo "Existing management node code found at /usr/local/vcl, exiting"; exit 1; fi
fi
echo "no existing VCL components found"

# ------------------------------ NOTICES -------------------------------------
if [[ $DOMN -eq 1 ]]; then 
	print_break
	echo ""
	echo "NOTICE: Later in this process, you will be prompted to download and install"
	echo "Linux packages and Perl modules. At that time, if you agree with the license"
	echo "terms, enter YES to install them. Otherwise, enter NO to exit and abort the "
	echo "installation."
	echo ""
	echo "(Press Enter to continue)"
	read tmp
fi

# -------------------------- admin password ----------------------------------
if [[ $DOALL -eq 1 ]]; then
	print_break
	echo ""
	echo "Enter the password you would like to use for the VCL admin user. This can be changed"
	echo "later by running '/usr/local/vcl/bin/vcld --setup'"
	echo -n "Admin Password: "
	IFS= read ADMIN_PASSWORD

	while [[ $ADMIN_PASSWORD = ^[[:space:]]+$ || $ADMIN_PASSWORD = "" ]]; do
		echo "Password cannot be empty or contain only whitespace. Please enter the password."
		echo -n "Admin Password: "
		IFS= read ADMIN_PASSWORD
	done
fi

# --------------------- public/private address selection ---------------------
if [[ $DOMN -eq 1 ]]; then
	print_break;
	echo ""
	echo "VCL requires two networks to operate (referred to as public and private"
	echo "networks). The following network adapters and addresses were found. Please"
	echo "enter the number next to the adapter/address you would like to use for the"
	echo "specified network."
	echo ""
	netpubpriv=1

	ifcnt=0
	while read line; do
		((ifcnt++))
		addr[$ifcnt]=$(echo $line | awk '{print $2}' | awk -F'/' '{print $1}')
		if [[ ${addr[$ifcnt]} = '' ]]; then echo "Error: Failed to parse network address data"; exit 1; fi
		if[$ifcnt]=$(echo $line | awk '{print $(NF)}')
		if [[ ${if[$ifcnt]} = '' ]]; then echo "Error: Failed to parse network address data"; exit 1; fi
	done < <(ip addr list | grep inet | grep -v inet6)

	i=0
	while [[ $i < $ifcnt ]]; do
		((i++))
		echo "$i: ${if[$i]} ${addr[$i]}"
	done
	echo ""
	echo -n "Private adapter/address: "
	read privnum
	while [[ ! $privnum =~ ^[0-9]+$ || $privnum < 1 || $privnum > $ifcnt ]]; do
		echo "Invalid selection. Please enter the number next to the adapter/address you would"
		echo "like to use for the private network."
		echo -n "Private adapter/address: "
		read privnum
	done
	PRIVIP=${addr[$privnum]}
	echo ""

	i=0
	while [[ $i < $ifcnt ]]; do
		((i++))
		echo "$i: ${if[$i]} ${addr[$i]}"
	done
	echo ""
	echo -n "Public adapter/address: "
	read pubnum
	while [[ ! $pubnum =~ ^[0-9]+$ || $pubnum < 1 || $pubnum > $ifcnt ]]; do
		echo "Invalid selection. Please enter the number next to the adapter/address you would"
		echo "like to use for the public network."
		echo -n "Public adapter/address: "
		read pubnum
	done
	PUBIP=${addr[$pubnum]}
	if [[ $PUBIP = "" || $PRIVIP = "" ]]; then echo "Error: Failed to determine network addresses"; exit 1; fi
	echo ""
	echo "Private address selected: $PRIVIP"
	echo "Public address selected: $PUBIP"
fi

# --------------------- prompt for installing dhcpd ----------------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "This script can install and configure dhcpd for you. VCL requires that VMs"
	echo "always have the same private IP address assigned to them via dhcp. If you prefer"
	echo "to install and configure dhcpd manually, answer NO to the following question."
	echo "If you enter NO, you will have to set up dhcpd *manually* for VCL to work."
	echo ""
	echo -n "Install dhcpd? [yes] "
	read DODHCP
	DODHCP=$(echo $DODHCP | tr '[:upper:]' '[:lower:]')
	if [[ $DODHCP = '' ]]; then DODHCP=yes; fi

	while [[ ! $DODHCP =~ ^(yes|no)$ ]]; do
		echo -n "Please enter 'yes' or 'no': [yes] "
		read DODHCP
		DODHCP=$(echo $DODHCP | tr '[:upper:]' '[:lower:]')
		if [[ $DODHCP = '' ]]; then DODHCP=yes; fi
	done

	if [[ $DODHCP = 'yes' ]] && grep -q $PRIVIP /etc/dhcp/dhcpd.conf &> /dev/null; then
		echo ""
		echo "/etc/dhcp/dhcpd.conf appears to have been configured for VCL already, exiting"
		exit 1
	fi
	if [[ $DODHCP = 'yes' ]] && grep -q ${if[$privnum]} /etc/sysconfig/dhcpd &> /dev/null; then
		echo ""
		echo "/etc/sysconfig/dhcpd appears to have been configured for VCL already, exiting"
		exit 1
	fi
fi

# ------------------------- install basic required packages --------------------
print_break
echo "Installing Linux packages..."
if [[ $DOMN -eq 1 ]]; then
	yum -q -y install openssh-clients wget perl
	if [ $? -ne 0 ]; then "Error: Failed to install required linux packages (openssh-client, wget, and perl)"; exit 1; fi;
else
	yum -q -y install openssh-clients wget
	if [ $? -ne 0 ]; then "Error: Failed to install required linux packages (openssh-client and wget)"; exit 1; fi;
fi

# ------------------------------------ functions -------------------------------

function set_localauth_password() {
	local username=$1
	local password=$2
	
	#echo "Setting localauth password..."
	#echo "Username: $username"
	#echo "Password: $password"
	
	salt=$(random_string 8)
	#echo "Password salt: $salt"
	passhash=$(echo -n $password$salt | sha1sum | awk '{print $1}')
	#echo "Password hash: $passhash"
	mysql -e "UPDATE localauth SET passhash = '$passhash', salt = '$salt', lastupdated = NOW() WHERE localauth.userid = (SELECT id FROM user WHERE unityid = '$username');" vcl
	if [ $? -ne 0 ]; then
		echo "Error: Failed to set $username password to '$password'";
		exit 1;
	else
		echo "Successfully set $username password to '$password'"
		echo
	fi;
}

function download_archive() {
	wget -q "${ARCHIVEURLPATH}${ARCHIVE}" -O $ARCHIVE
	if [ $? -ne 0 ]; then generic_error "failed to download $ARCHIVE from $ARCHIVEURLPATH"; exit 1; fi
}

function validate_archive_sha1() {
	echo "Downloading sha1 file for $VCL_VERSION..."
	/bin/rm -f $ARCHIVE.sha1
	wget -q $SIGPATH$ARCHIVE.sha1
	echo "validating $ARCHIVE"
	sha1sum -c $ARCHIVE.sha1
	return $?
}

function validate_archive_gpg() {
	echo "Downloading GPG file for $VCL_VERSION..."
	/bin/rm -f $ARCHIVE.asc
	wget -q $SIGPATH$ARCHIVE.asc
	echo "Downloading KEYS file for ASF VCL..."
	wget -q https://svn.apache.org/repos/asf/vcl/KEYS
	echo "Importing KEYS..."
	gpg -q --import KEYS
	/bin/rm -f KEYS
	echo "validating $ARCHIVE..."
	gpg -q --verify $ARCHIVE.asc 2>&1 | grep 'Good signature'
	return $?
}

function generic_error() {
	if [[ -n $1 ]]; then
		echo "$1; correct any errors listed above and try again"
	else
		echo "installation failed; correct any errors listed above and try again"
	fi
}

# ------------------- download/validate arvhice ---------------------
print_break
cd $WORKPATH
if [[ ! -f $ARCHIVE ]]; then
	echo "Downloading VCL $VCL_VERSION..."
	download_archive
	validate_archive_sha1
	if [ $? -ne 0 ]; then generic_error "failed to validate $ARCHIVE"; exit 1; fi;
	validate_archive_gpg
	if [ $? -ne 0 ]; then generic_error "failed to validate $ARCHIVE"; exit 1; fi;
else
	dir=`pwd`
	echo "archive for $VCL_VERSION found at $dir/$ARCHIVE"
	validate_archive_sha1
	if [ $? -ne 0 ]; then
		echo "failed to validate $ARCHIVE; downloading again..."
		/bin/mv -f $ARCHIVE $ARCHIVE.old
		download_archive
		validate_archive_sha1
		if [ $? -ne 0 ]; then generic_error "failed to validate $ARCHIVE"; exit 1; fi;
		validate_archive_gpg
		if [ $? -ne 0 ]; then generic_error "failed to validate $ARCHIVE"; exit 1; fi;
	else
		validate_archive_gpg
		if [ $? -ne 0 ]; then generic_error "failed to validate $ARCHIVE"; exit 1; fi;
	fi;
fi

# ------------------------ extract archive ---------------------------
echo "Extracting $ARCHIVE"
tar -xf $ARCHIVE
if [ $? -ne 0 ]; then generic_error "failed to extract $ARCHIVE"; exit 1; fi;

# ------------------- run install_perl_libs.pl ------------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Installing Linux and PERL system requirements (this takes a while)"
	sleep 1
	yum -q -y install perl-CPAN
	if [ $? -ne 0 ]; then echo "Error: Failed to install perl-CPAN"; exit 1; fi;
	perl apache-VCL-$VCL_VERSION/managementnode/bin/install_perl_libs.pl
	rc=$?
	if [ $rc -eq 2 ]; then
		echo "License terms not accepted; aborting installation"
		exit 2
	elif [ $rc -ne 0 ]; then
		generic_error "Failed to install system requirements"
		exit 1
	fi
fi

# ---------------------- install mysql/mariadb -------------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	rpm -q mysql-server &> /dev/null
	if [ $? -ne 0 ]; then
		rpm -q mariadb-server &> /dev/null
		if [ $? -ne 0 ]; then
			echo "Installing MySQL/MariaDB Server..."
			yum -q search mysql-server | grep -q '^mysql-server'
			if [ $? -ne 0 ]; then
				yum -q search mariadb-server | grep -q '^mariadb-server'
				if [ $? -ne 0 ]; then
					echo "No mysql-server or mariadb-server packages found by yum"
					exit 1
				else
					yum -q -y install mariadb-server
					if [ $? -ne 0 ]; then generic_error "Failed to install mariadb-server"; exit 1; fi;
					echo "setting MariaDB to start on boot"
					/sbin/chkconfig mariadb on
					if [ $? -ne 0 ]; then generic_error "Failed to set mariadb-server to start at boot"; exit 1; fi;
					/sbin/service mariadb start
					if [ $? -ne 0 ]; then generic_error "Failed to start mariadb-server"; exit 1; fi;
				fi
			else
				yum -q -y install mysql-server
				if [ $? -ne 0 ]; then generic_error "Failed to install mysql-server"; exit 1; fi;
				echo "setting MySQL to start on boot"
				/sbin/chkconfig mysqld on
				if [ $? -ne 0 ]; then generic_error "Failed to set mysql-server to start at boot"; exit 1; fi;
				/sbin/service mysqld start
				if [ $? -ne 0 ]; then generic_error "Failed to start mysql-server"; exit 1; fi;
			fi
		else
			echo "MariaDB server already installed"
			echo "setting MariaDB to start on boot"
			/sbin/chkconfig mariadb on
			if [ $? -ne 0 ]; then generic_error "Failed to set mariadb-server to start at boot"; exit 1; fi;
			/sbin/service mariadb start
			if [ $? -ne 0 ]; then generic_error "Failed to start mariadb-server"; exit 1; fi;
		fi
	else
		echo "MySQL server already installed"
		echo "setting MySQL to start on boot"
		/sbin/chkconfig mysqld on
		if [ $? -ne 0 ]; then generic_error "Failed to set mysql-server to start at boot"; exit 1; fi;
		/sbin/service mysqld start
		if [ $? -ne 0 ]; then generic_error "Failed to start mysql-server"; exit 1; fi;
	fi
fi

# ---------------------- install httpd and php -------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Installing httpd and php components..."
	yum -q -y install httpd php mod_ssl php php-gd php-mysql php-xml php-xmlrpc php-ldap sendmail php-mbstring
	if [ $? -ne 0 ]; then generic_error "Failed to install httpd"; exit 1; fi;
	echo "setting httpd to start on boot"
	/sbin/chkconfig httpd on
	if [ $? -ne 0 ]; then generic_error "Failed to set httpd to start at boot"; exit 1; fi;
	/sbin/service httpd start
	if [ $? -ne 0 ]; then generic_error "Failed to start httpd"; exit 1; fi;
fi

# ------------------------- set up firewall ----------------------------
if [[ $DODB -eq 1 || $DOWEB -eq 1 ]]; then
	print_break
	webports=0
	dbport=0
	if [[ $DODB -eq 1 && $DOWEB -eq 1 && $DOMN -eq 0 ]]; then
		echo "Opening TCP ports 80, 443, and 3306..."
		webports=1
		dbport=1
	elif [[ $DOWEB -eq 1 ]]; then
		echo "Opening TCP ports 80 and 443..."
		webports=1
	elif [[ $DODB -eq 1 ]]; then
		echo "Opening TCP port 3306..."
		dbport=1
	fi

	if [[ $webports -eq 1 || $dbport -eq 1 ]]; then
		if [[ -x /bin/firewall-cmd ]] && /bin/firewall-cmd -q --state; then
			if [[ $webports -eq 1 ]]; then
				/bin/firewall-cmd --zone=public --add-service=http --permanent
				if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 80"; exit 1; fi;
				/bin/firewall-cmd --zone=public --add-service=https --permanent
				if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 443"; exit 1; fi;
			fi
			if [[ $dbport -eq 1 ]]; then
				if [[ $DOWEB -eq 0 ]]; then
					/bin/firewall-cmd --zone=public --permanent --add-rich-rule="rule family="ipv4" source address="$WEB_HOST" service name="mysql" accept"
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 3306 for $WEB_HOST"; exit 1; fi;
				fi
				if [[ $DOMN -eq 0 ]]; then
					/bin/firewall-cmd --zone=public --permanent --add-rich-rule="rule family="ipv4" source address="$MN_HOST" service name="mysql" accept"
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 3306 for $MN_HOST"; exit 1; fi;
				fi
			fi
			/bin/firewall-cmd --reload
			if [ $? -ne 0 ]; then echo "Error: Failed reload firewall"; exit 1; fi;
		elif [[ -x /sbin/iptables ]]; then 
			if [[ $webports -eq 1 ]]; then
				if ! /sbin/iptables -nL | grep 80 | grep ACCEPT; then
					/sbin/iptables -I INPUT 1 -m state --state NEW,RELATED,ESTABLISHED -m tcp -p tcp -j ACCEPT --dport 80
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 80"; exit 1; fi;
				fi
				if ! /sbin/iptables -nL | grep 443 | grep ACCEPT; then
					/sbin/iptables -I INPUT 1 -m state --state NEW,RELATED,ESTABLISHED -m tcp -p tcp -j ACCEPT --dport 443
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 443"; exit 1; fi;
				fi
			fi
			if [[ $dbport -eq 1 ]]; then
				if [[ $DOWEB -eq 0 ]] && ! /sbin/iptables -L | grep mysql | grep $WEB_HOST | grep ACCEPT; then
					/sbin/iptables -I INPUT 1 -m state --state NEW,RELATED,ESTABLISHED -s $WEB_HOST -m tcp -p tcp -j ACCEPT --dport 3306
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 3306 for $WEB_HOST"; exit 1; fi;
				fi
				if [[ $DOMN -eq 0 ]] && ! /sbin/iptables -L | grep mysql | grep $MN_HOST | grep ACCEPT; then
					/sbin/iptables -I INPUT 1 -m state --state NEW,RELATED,ESTABLISHED -s $MN_HOST -m tcp -p tcp -j ACCEPT --dport 3306
					if [ $? -ne 0 ]; then echo "Error: Failed to set firewall to allow port 3306 for $MN_HOST"; exit 1; fi;
				fi
			fi
			/sbin/iptables-save > /etc/sysconfig/iptables
			if [ $? -ne 0 ]; then echo "Error: Failed to save iptables configuration"; exit 1; fi;
		else
			echo "Warning: Failed to detect firewall system. You will need to ensure "
			if [[ $DODB -eq 1 && $DOWEB -eq 1 ]]; then
				echo -n "ports 80, 443, and 3306 are "
			elif [[ $DODB -eq 1 ]]; then
				echo -n "port 3306 is "
			elif [[ $DOWEB -eq 1 ]]; then
				echo -n "ports 80 and 443 are "
			fi
			echo "allowed through your firewall."
			echo ""
			echo "(Press ENTER to continue)"
			read tmp
		fi
	fi 
fi

# ------------------------- check selinux ----------------------------
if [[ $DOWEB -eq 1 && -x /usr/sbin/getenforce ]]; then
	if /usr/sbin/getenforce | grep -q -i enforcing; then
		print_break
		echo "Configuring SELinux to allow httpd to make network connections..."
		/usr/sbin/setsebool -P httpd_can_network_connect=1
	fi
fi

# ---------------------- create/set up vcl database ------------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	echo "Creating VCL database..."
	mysql -e "DROP DATABASE IF EXISTS vcl;"
	mysql -e "CREATE DATABASE vcl;"
	if [ $? -ne 0 ]; then generic_error "Failed to create VCL database"; exit 1; fi;
	if [[ $DOMN -eq 1 || $DOWEB -eq 1 ]]; then
		mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE TEMPORARY TABLES ON vcl.* TO '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
		if [ $? -ne 0 ]; then generic_error "Failed to create VCL database user"; exit 1; fi;
	fi
	if [[ $MN_HOST != "localhost" ]]; then
		mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE TEMPORARY TABLES ON vcl.* TO '$DB_USERNAME'@'$MN_HOST' IDENTIFIED BY '$DB_PASSWORD';"
		if [ $? -ne 0 ]; then generic_error "Failed to create VCL database user"; exit 1; fi;
	fi
	if [[ $WEB_HOST != "localhost" ]]; then
		mysql -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE TEMPORARY TABLES ON vcl.* TO '$DB_USERNAME'@'$WEB_HOST' IDENTIFIED BY '$DB_PASSWORD';"
		if [ $? -ne 0 ]; then generic_error "Failed to create VCL database user"; exit 1; fi;
	fi
	mysql vcl < $WORKPATH/apache-VCL-$VCL_VERSION/mysql/vcl.sql
	if [ $? -ne 0 ]; then generic_error "Failed to initialize VCL database"; exit 1; fi;
fi

# ------------------------- copy web code in place -------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Installing VCL web code..."
	/bin/cp -r $WORKPATH/apache-VCL-$VCL_VERSION/web/ /var/www/html/vcl-$VCL_VERSION
	if [ $? -ne 0 ]; then generic_error "Failed to install VCL web code"; exit 1; fi;
	ln -s /var/www/html/vcl-$VCL_VERSION /var/www/html/vcl
	if [ $? -ne 0 ]; then generic_error "Failed to install VCL web code"; exit 1; fi;
	chown apache /var/www/html/vcl/.ht-inc/maintenance
fi

# ---------------------------- configure web code --------------------------
if [[ $DOWEB -eq 1 ]]; then
	echo "Configuring secrets.php..."
	/bin/cp -f /var/www/html/vcl/.ht-inc/secrets-default.php /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to create secrets.php"; exit 1; fi;
	sed -i -r -e "s/(vclhost\s+=\s+).*;/\1'$DB_HOST';/" /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure secrets.php"; exit 1; fi;
	sed -i -r -e "s/(vclusername\s+=\s+).*;/\1'$DB_USERNAME';/" /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure secrets.php"; exit 1; fi;
	sed -i -r -e "s/(vclpassword\s+=\s+).*;/\1'$DB_PASSWORD';/" /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure secrets.php"; exit 1; fi;
	sed -i -r -e "s/(cryptkey\s+=\s+).*;/\1'$CRYPTKEY';/" /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure secrets.php"; exit 1; fi;
	sed -i -r -e "s/(pemkey\s+=\s+).*;/\1'$PEMKEY';/" /var/www/html/vcl/.ht-inc/secrets.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure secrets.php"; exit 1; fi;

	echo "Configureing conf.php..."
	/bin/cp -f /var/www/html/vcl/.ht-inc/conf-default.php /var/www/html/vcl/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to configure conf.php"; exit 1; fi;

	echo "Generating keys..."
	cd /var/www/html/vcl/.ht-inc
	./genkeys.sh &> /dev/null
	if [ $? -ne 0 ]; then echo "Error: Failed to generate crypto keys"; exit 1; fi;
fi

# ---------------------------- set passwords ---------------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	echo "Setting passwords..."
	set_localauth_password admin $ADMIN_PASSWORD
	set_localauth_password vclsystem $ADMIN_PASSWORD
fi

# ---------------- copy management node code in place ------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Installing management node components..."
	/bin/cp -r $WORKPATH/apache-VCL-$VCL_VERSION/managementnode/ /usr/local/vcl-$VCL_VERSION
	if [ $? -ne 0 ]; then generic_error "Failed to install VCL management node code"; exit 1; fi;
	ln -s /usr/local/vcl-$VCL_VERSION /usr/local/vcl
	if [ $? -ne 0 ]; then generic_error "Failed to install VCL management node code"; exit 1; fi;
fi

#--------------------- configure management node code ------------------
if [[ $DOMN -eq 1 ]]; then
	echo "Configuring vcld.conf..."
	pkill -9 -f vcld
	if [[ ! -d /etc/vcl ]]; then
		mkdir /etc/vcl
		if [ $? -ne 0 ]; then echo "Error: Failed to create /etc/vcl directory"; exit 1; fi;
	fi
	/bin/cp -f /usr/local/vcl/etc/vcl/vcld.conf /etc/vcl
	if [ $? -ne 0 ]; then echo "Error: Failed to copy vcld.conf file to /etc/vcl"; exit 1; fi;
	if [[ $DODB -eq 0 && $MN_HOST -eq "localhost" ]]; then
		sed -i -r -e "s/(FQDN=).*/\1$PUBIP/" /etc/vcl/vcld.conf
		if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	else
		sed -i -r -e "s/(FQDN=).*/\1$MN_HOST/" /etc/vcl/vcld.conf
		if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	fi
	sed -i -r -e "s/(server=).*/\1$DB_HOST/" /etc/vcl/vcld.conf
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	sed -i -r -e "s/(LockerWrtUser=).*/\1$DB_USERNAME/" /etc/vcl/vcld.conf
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	sed -i -r -e "s/(wrtPass=).*/\1$DB_PASSWORD/" /etc/vcl/vcld.conf
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	sed -i -r -e "s/(xmlrpc_url=).*/\1https:\/\/$WEB_HOST\/vcl\/index.php?mode=xmlrpccall/" /etc/vcl/vcld.conf
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
	sed -i -r -e "s/(xmlrpc_pass=).*/\1$ADMIN_PASSWORD/" /etc/vcl/vcld.conf
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi;
fi

#------------------ configure vcld to start at boot ---------------
if [[ $DOMN -eq 1 ]]; then
	echo "Configuring vcld service..."
	/bin/cp -f /usr/local/vcl/bin/S99vcld.linux /etc/init.d/vcld
	if [ $? -ne 0 ]; then echo "Error: Failed to copy initialization file in place"; exit 1; fi;
	/sbin/chkconfig --add vcld
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld service to start on boot"; exit 1; fi;
	/sbin/chkconfig --level 345 vcld on
	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld service to start on boot"; exit 1; fi;
fi

#----------------------- configure management node in vcl --------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	echo "Adding managment node to database..."
	mysql -e "DELETE FROM vcl.managementnode;"
	mysql -e "INSERT INTO vcl.managementnode (IPaddress, hostname, stateid) VALUES ('$PUBIP', '$MN_HOST', '2');"
	if [ $? -ne 0 ]; then echo "Error: Failed to add management node to database"; exit 1; fi;
	mysql -e "DELETE FROM vcl.resource WHERE resourcetypeid = 16;"
	mysql -e "INSERT INTO vcl.resource (resourcetypeid, subid) VALUES ('16', (SELECT id FROM vcl.managementnode WHERE hostname = '$MN_HOST'));"
	if [ $? -ne 0 ]; then echo "Error: Failed to add management node to database"; exit 1; fi;
	mysql -e "INSERT INTO vcl.resourcegroupmembers (resourceid, resourcegroupid) SELECT vcl.resource.id, vcl.resourcegroup.id FROM vcl.resource, vcl.resourcegroup WHERE vcl.resource.resourcetypeid = 16 AND vcl.resourcegroup.resourcetypeid = 16;"
	if [ $? -ne 0 ]; then echo "Error: Failed to add management node to database"; exit 1; fi;
fi

# ----------------- install and configure dhcpd ------------------------
if [[ $DODHCP = 'yes' ]]; then
	print_break
	echo "Installing dhcp..."
	yum -q -y install dhcp
	if [ $? -ne 0 ]; then echo "Error: Failed to install dhcp"; exit 1; fi;

	echo "Configuring dhcp..."
	if ifconfig ${if[$privnum]} | grep $PRIVIP | grep -q 'Mask:'; then
		privmask=$(ifconfig ${if[$privnum]} | grep $PRIVIP | awk '{print $4}' | awk -F: '{print $2}')
	elif ifconfig ${if[$privnum]} | grep $PRIVIP | grep -q 'netmask '; then 
		privmask=$(ifconfig ${if[$privnum]} | grep $PRIVIP | awk '{print $4}')
	fi
	if [[ ! $privmask =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		echo "Error: Failed to determine netmask for private address"
		exit 1
	fi
	IFS=. read pr1 pr2 pr3 pr4 <<<"$PRIVIP"
	IFS=. read prm1 prm2 prm3 prm4 <<<"$privmask"
	privnet="$((pr1 & prm1)).$((pr2 & prm2)).$((pr3 & prm3)).$((pr4 & prm4))"
	if [[ ! $privnet =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		echo "Error: Failed to determine network for private address"
		exit 1
	fi

	echo "Private address: $PRIVIP"
	echo "Private netmask: $privmask"
	echo "Private network: $privnet"

	echo "Configuring /etc/dhcp/dhcpd.conf..."
(
cat <<'EOF'
#
# DHCP Server Configuration file.
#   see /usr/share/doc/dhcp*/dhcpd.conf.sample
#   see 'man 5 dhcpd.conf'
#
ddns-update-style none;
shared-network eth0 {
	subnet PRIVNET netmask PRIVMASK {
		ignore unknown-clients;
	}
	# ----------- add computers from VCL web site below here ------------
}
EOF
) > /etc/dhcp/dhcpd.conf
	sed -i "s/PRIVNET/$privnet/" /etc/dhcp/dhcpd.conf
	sed -i "s/PRIVMASK/$privmask/" /etc/dhcp/dhcpd.conf
	if ! grep -q $privmask /etc/dhcp/dhcpd.conf; then
		echo "Error: Failed to configure /etc/dhcp/dhcpd.conf"
		exit 1
	fi

	if [[ -f /etc/sysconfig/dhcpd ]] && grep -q DHCPDARGS /etc/sysconfig/dhcpd; then
		sed -i -r -e "s/(DHCPDARGS=).*/\1${if[$privnum]}/" /etc/sysconfig/dhcpd
	else
		echo "DHCPDARGS=\"${if[$privnum]}\"" > /etc/sysconfig/dhcpd
	fi
	if ! grep -q ${if[$privnum]} /etc/sysconfig/dhcpd; then
		echo "Error: Failed to configure /etc/sysconfig/dhcpd"
		exit 1
	fi

	/sbin/chkconfig dhcpd on
	if [ $? -ne 0 ]; then echo "Error: Failed to configure dhcpd service to start on boot"; exit 1; fi;

	echo "Starting dhcpd service..."
	/sbin/service dhcpd start
	if [ $? -ne 0 ]; then generic_error "Failed to start dhcpd service"; exit 1; fi;
fi

# -------------------- create ssh identity key ---------------------
if [[ $DOMN -eq 1 && ! -r /etc/vcl/vcl.key ]]; then
	print_break
	echo "Creating SSH identity key file at /etc/vcl/vcl.key"
	ssh-keygen -t rsa -f "/etc/vcl/vcl.key" -N '' -b 1024 -C 'VCL root account'
	if [ $? -ne 0 ]; then echo "Error: Failed to create ssh identity key for connecting to managed VMs"; exit 1; fi;
	echo "IdentityFile /etc/vcl/vcl.key" >> /etc/ssh/ssh_config
	if [ $? -ne 0 ]; then echo "Error: Failed to add ssh identity key to /etc/ssh/ssh_config"; exit 1; fi;
fi

# ---------------------------- start vcld ----------------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Starting vcld service..."
	/sbin/service vcld stop &> /dev/null
	sleep 1
	/sbin/service vcld start
	if [ $? -ne 0 ]; then echo "Error: Failed to start vcld service"; exit 1; fi;
fi

echo ""
if [[ $DOALL -eq 1 ]]; then
	echo "VCL installation complete"
	echo ""
	echo "Your VCL system now needs to be configured. Follow online instructions to"
elif [[ $DODB -eq 1 && $DOWEB -eq 1 ]]; then
	echo "VCL installation of database and web components complete. If you have not"
	echo "already done so, install management node components to complete your VCL"
	echo "installation. After all components are installed, your VCL system will need"
	echo "to be configured. Follow online instructions to"
elif [[ $DODB -eq 1 && $DOMN -eq 1 ]]; then
	 echo "VCL installation of database and management node components complete. If you"
	 echo "have not already done so, install web components to complete your VCL"
	 echo "installation. After all components are installed, your VCL system will need to"
	 echo "be configured. Follow online instructions to"
elif [[ $DOWEB -eq 1 && $DOMN -eq 1 ]]; then
	 echo "VCL installation of web and management node components complete. If you have"
	 echo "not already done so, install database components to complete your VCL"
	 echo "installation. After all components are installed, your VCL system will need to"
	 echo "be configured. Follow online instructions to"
elif [[ $DODB -eq 1 ]]; then
	 echo "VCL installation of database components complete. If you have not already done"
	 echo "so, install web and management node components to complete your VCL"
	 echo "installation. After all components are installed, your VCL system will need to"
	 echo "be configured. Follow online instructions to"
elif [[ $DOWEB -eq 1 ]]; then
	 echo "VCL installation of web components complete. If you have not already done so,"
	 echo "install database and management node components to complete your VCL"
	 echo "installation. After all components are installed, your VCL system will need to"
	 echo "be configured. Follow online instructions to"
elif [[ $DOMN -eq 1 ]]; then
	 echo "VCL installation of management node components complete. If you have not already"
	 echo "done so, install database and web components to complete your VCL installation."
	 echo "After all components are installed, your VCL system will need to be configured."
	 echo "Follow online instructions to"
fi

echo ""
echo "1) Set up a VM Host Profile"
echo "2) Add a Virtual Host"
echo "3) Add VMs"
echo "4) export dhcpd data for the VMS and add that to /etc/dhcp/dhcpd.conf"
echo "5) Assign VMs to your VM Host(s)"
echo "6) create base images"
echo ""

if [[ $DOALL -eq 1 ]]; then
	echo "Your VCL system can be accessed at https://$PUBIP/vcl" 
fi
