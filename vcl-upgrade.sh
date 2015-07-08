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
	echo -e "\t\t[--dbhost <hostname>] [--dbadminuser <username>]"
	echo -e "\t\t[--dbadminpass <password>]"
	echo ""
	echo -e "\t-d|--database - upgrade database components"
	echo -e "\t\t--dbhost may optionally be specified if not localhost"
	echo ""
	echo -e "\t-w|--web - upgrade web server components"
	echo ""
	echo -e "\t-m|--managementnode - upgrade management node (vcld) components"
	echo ""
	echo -e "\t--dbhost <hostname> - hostname of database server (default=localhost)"
	echo ""
	echo -e "\t--dbname <name> - name of VCL database on database server (default=vcl)"
	echo ""
	echo -e "\t--dbadminuser <username> - admin username for database; must have access"
	echo -e "\t\tto modify database schema and dump data for backup (default=root)"
	echo ""
	echo -e "\t--dbadminpass <password> - password for dbadminuser (default=[no password])"
	echo ""
	echo "If no arguments supplied, all components will be upgraded using default"
	echo "values for optional arguments."
	echo ""
	exit 2
}

args=$(getopt -q -o dwmh -l database,web,managementnode,help,dbhost:,dbname:,dbadminuser:,dbadminpass:,rc: -n $0 -- "$@")

if [ $? -ne 0 ]; then help; fi

eval set -- "$args"

# ------------------------- variables -------------------------------
VCL_VERSION=2.4.2
OLD_VERSION=""
DB_NAME=vcl
WEB_PATH=/var/www/html/vcl
MN_PATH=/usr/local/vcl
DB_ADMINUSER=root
DB_ADMINPASS=""

DB_HOST=localhost
ARCHIVE=apache-VCL-$VCL_VERSION.tar.bz2
ARCHIVEURLPATH="http://vcl.apache.org/downloads/download.cgi?action=download&filename=%2Fvcl%2F$VCL_VERSION%2F"
SIGPATH="http://www.apache.org/dist/vcl/"

DODB=0
DOWEB=0
DOMN=0
DOALL=1
dbhostdefault=1
dbnamedefault=1
dbadminuserdefault=1
dbadminpassdefault=1
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
		--dbname)
			DB_NAME=$2
			dbnamedefault=0
			shift 2
			;;
		--dbadminuser)
			DB_ADMINUSER=$2
			dbadminuserdefault=0
			shift 2
			;;
		--dbadminpass)
			DB_ADMINPASS=$2
			dbadminpassdefault=0
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

# ------------------------- check for being root -----------------------------
who=$(whoami)
if [[ $who != "root" ]]; then
	echo "You must be root to run this script."
	exit 1
fi

# ----------------------- notify user of defaults ----------------------------
if [[ $DODB -eq 1 ]]; then
	if [[ $dbhostdefault -eq 1 ]]; then
		echo ""
		echo "Database host defaulted to be $DB_HOST"
	fi
	if [[ $dbnamedefault -eq 1 ]]; then
		echo ""
		echo "Database name defaulted to be $DB_NAME"
	fi
	if [[ $dbadminuserdefault -eq 1 ]]; then
		echo ""
		echo "Database username defaulted to be $DB_ADMINUSER"
	fi
	if [[ $dbadminpassdefault -eq 1 ]]; then
		echo ""
		echo "Database password defaulted to be empty."
	fi
fi

WORKPATH=$(pwd)

if [[ -f NOTICE && -f LICENSE && -d managementnode && -d web && -d mysql ]]; then
	WORKPATH=$(dirname `pwd`)
fi

if [[ $DB_ADMINPASS = "" ]]; then
	alias mysql="mysql -u $DB_ADMINUSER -h $DB_HOST"
	alias mysqldump="mysqldump -u $DB_ADMINUSER -h $DB_HOST"
else
	alias mysql="mysql -u $DB_ADMINUSER -p'$DB_ADMINPASS' -h $DB_HOST"
	alias mysqldump="mysqldump -u $DB_ADMINUSER -p'$DB_ADMINPASS' -h $DB_HOST"
fi

# ------------------- checks for existing installation -----------------------
echo ""
echo "Checking for existing VCL components selected for upgrade..."
# database
if [[ $DODB -eq 1 ]]; then
	mysql -e "use $DB_NAME;" &> /dev/null
	if [ $? -ne 0 ]; then echo "Existing VCL database not found, exiting"; exit 1; fi
fi
echo "Found existing database"
# web code
if [[ $DOWEB -eq 1 ]]; then
	if [ ! -d $WEB_PATH ]; then echo "Existing web code not found at $WEB_PATH, exiting"; exit 1; fi
	if grep 'VCLversion' $WEB_PATH/index.php | grep -q $VCL_VERSION; then
		echo "Web code appears to be at current version, exiting"
		exit 1
	fi
fi
echo "Found existing web code"
# management code
if [[ $DOMN -eq 1 ]]; then
	if [ ! -d $MN_PATH ]; then echo "Existing management node code not found at $MN_PATH, exiting"; exit 1; fi
	if [[ ! -f /etc/vcl/vcld.conf ]]; then echo "/etc/vcl/vcld.conf not found, exiting"; exit 1; fi
	if grep '$VERSION' $MN_PATH/lib/VCL/utils.pm | grep -q $VCL_VERSION; then
		echo "Management node code appears to be at current version, exiting"
		exit 1
	fi
fi
echo "Found existing management node code"

# ------------------------- detemine old version ---------------------
if [[ $DOWEB -eq 1 || $DOMN -eq 1 ]]; then
	print_break
	echo "Determining previous versions of VCL..."
	if [[ $DOWEB -eq 1 ]]; then
		OLD_WEB_VERSION=$(grep 'VCLversion' $WEB_PATH/index.php | awk -F"'" '{print $2}')
		if [[ $OLD_WEB_VERSION = "" ]]; then
			OLD_WEB_VERSION=$(grep '# ASF VCL' $WEB_PATH/index.php | awk '{print $4}' | sed 's/v//')
			if [[ $OLD_WEB_VERSION = "" ]]; then
				echo "Error: Failed to determine previous version of web code, exiting"
				exit 1
			fi
		fi
		echo "Determined previous web code version to be $OLD_WEB_VERSION"
		OLD_VERSION=$OLD_WEB_VERSION
	fi
	if [[ $DOMN -eq 1 ]]; then
		OLD_MN_VERSION=$(grep '$VERSION' $MN_PATH/lib/VCL/utils.pm | awk -F"'" '{print $2}')
		if [[ $DOWEB -eq 1 && $OLD_WEB_VERSION = "2.2.2" && $OLD_MN_VERSION = "2.2.1" ]]; then
			# 2.2.2 release did not include an upgrade to management node code
			OLD_MN_VERSION="2.2.2"
		fi
		if [[ $OLD_MN_VERSION = "" ]]; then echo "Error: Failed to determine previous version of management node code, exiting"; exit 1; fi
		echo "Determined previous management node code version to be $OLD_MN_VERSION"
		OLD_VERSION=$OLD_MN_VERSION
	fi
	if [[ $DOWEB -eq 1 && $DOMN -eq 1 && $OLD_WEB_VERSION != $OLD_MN_VERSION ]]; then
		echo "Error: Previous versions of web code and management node do not match; exiting"
		exit 1
	fi
elif [[ $DODB -eq 1 && $DOWEB -eq 0 && $DOMN -eq 0 ]]; then
	OLD_VERSION=""
fi

if [[ $OLD_VERSION = $VCL_VERSION ]]; then
	echo "Error: The installed version of VCL is the same version this script installs; exiting"
	exit 1
fi

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

# ------------------------- install basic required packages --------------------
print_break
echo "Installing Linux packages..."
yum -q -y install wget
if [ $? -ne 0 ]; then echo "Error: Failed to install required linux package (wget)"; exit 1; fi;

# ------------------------------------ functions -------------------------------

function download_archive() {
	wget -q "$ARCHIVEURLPATH$ARCHIVE" -O $ARCHIVE
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

function confUpgradeFrom22() {
	sed -i 's|https://cwiki.apache.org/VCLDOCS/|https://cwiki.apache.org/confluence/display/VCL/Using+VCL|' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	sed -i 's|^\$blockNotifyUsers|#\$blockNotifyUsers|' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	sed -i '/^\$userlookupUsers = array(.*);/d' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	sed -i '/^\$userlookupUsers = array/,/);/d' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi

	if ! grep -q '$NOAUTH_HOMENAV' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/a );' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"Report a Problem" => "mailto:" . HELPEMAIL,                ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"How to use VCL" => "https://cwiki.apache.org/confluence/display/VCL/Using+VCL",' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"What is VCL" => "http://vcl.apache.org/",                  ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a $NOAUTH_HOMENAV = array (                                      ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a #   where authentication method is selected when NOAUTH_HOMENAV is set to 1' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # documentation links to display on login page and page' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q XMLRPCLOGGING $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("XMLRPCLOGGING", 1);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to control logging of XMLRPC calls for auditing or debugging purposes; queries are logged to the xmlrpcLog table' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q QUERYLOGGING $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("QUERYLOGGING", 1);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to control logging of non SELECT database queries for auditing or debugging purposes; queries are logged to the querylog table' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q 'define..NOAUTH_HOMENAV' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("NOAUTH_HOMENAV", 0);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # 0 = disables; 1 = enabled' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a #   where authentication method is selected' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to enable documentation links on login page and page' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q MAXSUBIMAGES $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("MAXSUBIMAGES", 5000);  // maximum allowed number for subimages in a config' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q MAXINITIALIMAGINGTIME $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("MAXINITIALIMAGINGTIME", 720); // for imaging reservations, users will have at least this long as the max selectable duration' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q ALLOWADDSHIBUSERS $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // will be added to the database with the typoed userid' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // a userid, there is no way to verify that it was entered incorrectly so the user' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // privilege somewhere in the privilege tree. Note that if you enable this and typo' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // through things such as adding a user to a user group or directly granting a user a' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // set this to 1 to allow users be manually added to VCL before they have ever logged in' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \                                // also have LDAP set up (i.e. affiliation.shibonly = 1)' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("ALLOWADDSHIBUSERS", 0); // this is only related to using Shibboleth authentication for an affiliation that does not' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q SEMTIMEOUT $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("SEMTIMEOUT", "45");' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q DEFAULTLOCALE $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("DEFAULTLOCALE", "en_US");              // default locale for the site' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
}

function confUpgradeFrom221() {
	confUpgradeFrom22
	sed -i "s/\$addUserFunc\[\$item\['affiliationid'\]\] = create_function('', 'return 0;');/\$addUserFunc[\$item['affiliationid']] = create_function('', 'return NULL;');/" $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	sed -i "s/\$updateUserFunc\[\$item\['affiliationid'\]\] = create_function('', 'return 0;');/\$updateUserFunc[\$item['affiliationid']] = create_function('', 'return NULL;');/" $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
}

function confUpgradeFrom222() {
	confUpgradeFrom221
}

function confUpgradeFrom23() {
	sed -i 's|https://cwiki.apache.org/VCLDOCS/|https://cwiki.apache.org/confluence/display/VCL/Using+VCL|' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi

	if ! grep -q '$NOAUTH_HOMENAV' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/a );' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"Report a Problem" => "mailto:" . HELPEMAIL,                ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"How to use VCL" => "https://cwiki.apache.org/confluence/display/VCL/Using+VCL",' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a \\t"What is VCL" => "http://vcl.apache.org/",                  ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a $NOAUTH_HOMENAV = array (                                      ' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a #   where authentication method is selected when NOAUTH_HOMENAV is set to 1' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # documentation links to display on login page and page' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q XMLRPCLOGGING $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("XMLRPCLOGGING", 1);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to control logging of XMLRPC calls for auditing or debugging purposes; queries are logged to the xmlrpcLog table' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q QUERYLOGGING $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("QUERYLOGGING", 1);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to control logging of non SELECT database queries for auditing or debugging purposes; queries are logged to the querylog table' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q 'define..NOAUTH_HOMENAV' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("NOAUTH_HOMENAV", 0);' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # 0 = disables; 1 = enabled' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a #   where authentication method is selected' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a # boolean value of 0 or 1 to enable documentation links on login page and page' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q MAXSUBIMAGES $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("MAXSUBIMAGES", 5000);  // maximum allowed number for subimages in a config' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q MAXINITIALIMAGINGTIME $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("MAXINITIALIMAGINGTIME", 720); // for imaging reservations, users will have at least this long as the max selectable duration' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	if ! grep -q SEMTIMEOUT $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php; then
		sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
		sed -i '/ENABLE_ITECSAUTH/a define("SEMTIMEOUT", "45");' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
		if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
	fi

	sed -i '/ENABLE_ITECSAUTH/G' $WEB_PATH-$VCL_VERSION/.ht-inc/conf.php
	if [ $? -ne 0 ]; then echo "Error: Failed to update conf.php"; exit 1; fi
}

function confUpgradeFrom231() {
	confUpgradeFrom23
}

function confUpgradeFrom232() {
	confUpgradeFrom23
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

# ------------------------- stop httpd --------------------------------
if [[ $DOWEB -eq 1 ]]; then
	echo "Stopping httpd service..."
	/sbin/service httpd stop
	if [ $? -ne 0 ]; then generic_error "Failed to stop httpd service"; exit 1; fi;
fi

# ---------------------------- stop vcld ----------------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Stopping vcld service..."
	/sbin/service vcld stop
	if [ $? -ne 0 ]; then generic_error "Failed to stop vcld service"; exit 1; fi;
fi

# -------------------------- backup database -------------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	echo "Backing up $DB_NAME database..."
	if [[ ! -x /bin/mysqldump && ! -x /usr/bin/mysqldump ]]; then
		echo "mysqldump command not found; cannot backup database; exiting..."
		exit 1
	fi
	if [[ $OLD_VERSION = "" ]]; then
		mysqldump $DB_NAME > $WORKPATH/vcl-pre${VCL_VERSION}-backup.sql
		if [ $? -ne 0 ]; then generic_error "Failed to create backup of $DB_NAME database"; exit 1; fi;
		gzip $WORKPATH/vcl-pre${VCL_VERSION}-backup.sql
	else
		mysqldump $DB_NAME > $WORKPATH/vcl-${OLD_VERSION}-backup.sql
		if [ $? -ne 0 ]; then generic_error "Failed to create backup of $DB_NAME database"; exit 1; fi;
		gzip $WORKPATH/vcl-${OLD_VERSION}-backup.sql
	fi
fi

# -------------------------- backup web code -------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Backing up web code..."
	tar czf $WORKPATH/web-${OLD_VERSION}-backup.tar.gz $WEB_PATH
	if [ $? -ne 0 ]; then generic_error "Failed to create backup of web code at $WEB_PATH"; exit 1; fi;
fi

# -------------------------- backup web code -------------------------
if [[ $DOMN -eq 1 ]]; then
	echo "Backing up management node code..."
	tar czf $WORKPATH/managmentnode-${OLD_VERSION}-backup.tar.gz $MN_PATH
	if [ $? -ne 0 ]; then generic_error "Failed to create backup of management node code at $MN_PATH"; exit 1; fi;
fi

# -------------------------- install php -----------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Ensuring required php components are installed..."
	missing=
	for pkg in php php-gd php-mysql php-xml php-xmlrpc php-ldap php-mbstring; do
		alt=$(echo $pkg | sed 's/php/php53/')
		if ! (rpm --quiet -q $pkg || rpm --quiet -q $alt); then
			missing="$missing $pkg"
		fi
		if rpm -qa | grep -q php53; then
			missing=$(echo $missing | sed 's/php/php53/g')
		fi
		if [[ $missing != "" ]]; then
			echo "yum -q -y install $missing"
			yum -q -y install $missing
			if [ $? -ne 0 ]; then generic_error "Failed to install php components"; exit 1;
			else echo "php components successfully installed"; fi
		fi
	done
fi

# ------------------------- copy web code in place -------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Installing new VCL web code..."
	/bin/cp -r $WORKPATH/apache-VCL-$VCL_VERSION/web/ ${WEB_PATH}-$VCL_VERSION
	if [ $? -ne 0 ]; then generic_error "Failed to install new VCL web code"; exit 1; fi;
	chown apache ${WEB_PATH}-$VCL_VERSION/.ht-inc/maintenance
fi

# ---------------------------- configure web code --------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Copying in web configuration files from previous version"
	/bin/cp -f ${WEB_PATH}/.ht-inc/secrets.php ${WEB_PATH}-$VCL_VERSION/.ht-inc/
	if [ $? -ne 0 ]; then echo "Error: Failed to copy secrets.php"; exit 1; fi;
	/bin/cp -f ${WEB_PATH}/.ht-inc/conf.php ${WEB_PATH}-$VCL_VERSION/.ht-inc/
	if [ $? -ne 0 ]; then echo "Error: Failed to copy conf.php"; exit 1; fi;

	if [[ $OLD_VERSION = '2.2' ]]; then confUpgradeFrom22; fi
	if [[ $OLD_VERSION = '2.2.1' ]]; then confUpgradeFrom221; fi
	if [[ $OLD_VERSION = '2.2.2' ]]; then confUpgradeFrom222; fi
	if [[ $OLD_VERSION = '2.3' ]]; then confUpgradeFrom23; fi
	if [[ $OLD_VERSION = '2.3.1' ]]; then confUpgradeFrom231; fi
	if [[ $OLD_VERSION = '2.3.2' ]]; then confUpgradeFrom232; fi

	/bin/cp -f ${WEB_PATH}/.ht-inc/pubkey.pem ${WEB_PATH}-$VCL_VERSION/.ht-inc/
	if [ $? -ne 0 ]; then echo "Error: Failed to copy pubkey.pem"; exit 1; fi;
	/bin/cp -f ${WEB_PATH}/.ht-inc/keys.pem ${WEB_PATH}-$VCL_VERSION/.ht-inc/
	if [ $? -ne 0 ]; then echo "Error: Failed to copy keys.pem"; exit 1; fi;
fi

# ---------------- copy management node code in place ------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Installing management node components..."
	if [[ ! -d ${MN_PATH}-$OLD_VERSION ]]; then
		/bin/cp -r ${MN_PATH} ${MN_PATH}-$VCL_VERSION
		if [ $? -ne 0 ]; then generic_error "Failed to install new VCL management node code (1)"; exit 1; fi;
	fi
	/bin/cp -r ${MN_PATH}-$OLD_VERSION ${MN_PATH}-$VCL_VERSION
	/bin/cp -r $WORKPATH/apache-VCL-$VCL_VERSION/managementnode/* ${MN_PATH}-$VCL_VERSION
	if [ $? -ne 0 ]; then generic_error "Failed to install new VCL management node code (2)"; exit 1; fi;
fi

# -------------------- configure management node code ------------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Configuring vcld.conf..."

	if [ $? -ne 0 ]; then echo "Error: Failed to configure vcld.conf"; exit 1; fi
fi

# -------------------- rename old web code directory ---------------------
if [[ $DOWEB -eq 1 ]]; then
	if [[ ! -h $WEB_PATH && -d $WEB_PATH && -d ${WEB_PATH}-$OLD_VERSION ]]; then
		print_break
		echo "Moving ${WEB_PATH}-$OLD_VERSION to ${WEB_PATH}-${OLD_VERSION}.old"
		mv -f ${WEB_PATH}-$OLD_VERSION ${WEB_PATH}-${OLD_VERSION}.old
		if [ $? -ne 0 ]; then echo "Error: Failed to move old web code (1)"; exit 1; fi
	fi
	if [[ ! -d ${WEB_PATH}-$OLD_VERSION ]]; then
		print_break
		echo "Moving ${WEB_PATH} to ${WEB_PATH}-$OLD_VERSION"
		mv -f ${WEB_PATH} ${WEB_PATH}-$OLD_VERSION
		if [ $? -ne 0 ]; then echo "Error: Failed to move old web code (2)"; exit 1; fi
	fi
fi

# -------------- rename old management node code directory ---------------
if [[ $DOMN -eq 1 ]]; then
	if [[ ! -h $MN_PATH && -d $MN_PATH && -d ${MN_PATH}-$OLD_VERSION ]]; then
		print_break
		echo "Moving ${MN_PATH}-$OLD_VERSION to ${MN_PATH}-${OLD_VERSION}.old"
		mv -f ${MN_PATH}-$OLD_VERSION ${MN_PATH}-${OLD_VERSION}.old
		if [ $? -ne 0 ]; then echo "Error: Failed to move old management node code (1)"; exit 1; fi
	fi
	if [[ ! -d ${MN_PATH}-$OLD_VERSION ]]; then
		print_break
		echo "Moving ${MN_PATH} to ${MN_PATH}-$OLD_VERSION"
		mv -f ${MN_PATH} ${MN_PATH}-$OLD_VERSION
		if [ $? -ne 0 ]; then echo "Error: Failed to move old management node code (2)"; exit 1; fi
	fi
fi

# ---------------------- create/update web symlink -----------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Setting $WEB_PATH as a link to ${WEB_PATH}-$VCL_VERSION"
	ln -n -s -f ${WEB_PATH}-$VCL_VERSION $WEB_PATH
	if [ $? -ne 0 ]; then echo "Error: Failed to create/update link to ${WEB_PATH}-$VCL_VERSION"; exit 1; fi
fi

# ---------------- create/update management node symlink -----------------
if [[ $DOMN -eq 1 ]]; then
	print_break
	echo "Setting $MN_PATH as a link to ${MN_PATH}-$VCL_VERSION"
	ln -n -s -f ${MN_PATH}-$VCL_VERSION $MN_PATH
	if [ $? -ne 0 ]; then echo "Error: Failed to create/update link to ${MN_PATH}-$VCL_VERSION"; exit 1; fi
fi

# ----------------- disabling web access to old web code -----------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Disabling web access to ${WEB_PATH}-$OLD_VERSION"
	if [[ -f ${WEB_PATH}-$OLD_VERSION/.htaccess ]]; then
		mv -f ${WEB_PATH}-$OLD_VERSION/.htaccess ${WEB_PATH}-$OLD_VERSION/.htaccess.preupgrade
	fi
	echo "Deny from all" > ${WEB_PATH}-$OLD_VERSION/.htaccess
	if [ $? -ne 0 ]; then echo "Error: Failed to create new ${WEB_PATH}-$OLD_VERSION/.htaccess file"; exit 1; fi
fi

# ------------------------ upgrade vcl database --------------------------
if [[ $DODB -eq 1 ]]; then
	print_break
	echo "Upgrading VCL database..."
	mysql $DB_NAME < $WORKPATH/apache-VCL-$VCL_VERSION/mysql/update-vcl.sql
	if [ $? -ne 0 ]; then generic_error "Failed to upgrade VCL database"; exit 1; fi;
fi

# ------------------------- start httpd --------------------------------
if [[ $DOWEB -eq 1 ]]; then
	print_break
	echo "Starting httpd service..."
	/sbin/service httpd start
	if [ $? -ne 0 ]; then generic_error "Failed to start httpd"; exit 1; fi;
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
	echo "VCL upgrade complete"
elif [[ $DODB -eq 1 && $DOWEB -eq 1 ]]; then
	echo "VCL upgrade of database and web components complete."
elif [[ $DODB -eq 1 && $DOMN -eq 1 ]]; then
	 echo "VCL upgrade of database and management node components complete."
elif [[ $DOWEB -eq 1 && $DOMN -eq 1 ]]; then
	 echo "VCL upgrade of web and management node components complete."
elif [[ $DODB -eq 1 ]]; then
	 echo "VCL upgrade of database components complete."
elif [[ $DOWEB -eq 1 ]]; then
	 echo "VCL upgrade of web components complete."
elif [[ $DOMN -eq 1 ]]; then
	 echo "VCL upgrade of management node components complete."
fi
echo ""
