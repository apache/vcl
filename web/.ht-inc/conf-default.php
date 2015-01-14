<?php
/*
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

define("ONLINEDEBUG", 1);     // 1 to display errors to screen, 0 to email errors


################   Things in this section must be modified/reviewed #####################

define("HELPURL", "https://vcl.example.org/help/"); // URL pointed to by the "Help" link in the navigation area
define("HELPEMAIL", "vcl_help@example.org");        // if an unexpected error occurs, users will be prompted that they can email
                                                    //   this address for further assistance
define("ERROREMAIL", "webmaster@example.org");      // if an unexpected error occurs, the code will send an email about it to
                                                    //   to this address
define("ENVELOPESENDER", "webserver@example.org");   // email address for envelope sender of mail messages
                                                     //   if a message gets bounced, it goes to this address

date_default_timezone_set('America/New_York'); // set this to your timezone; a list of available values can
                                               // be found at http://php.net/manual/en/timezones.php

define("DEFAULTLOCALE", "en_US");              // default locale for the site

// Any time someone creates a new image, they will be required to agree to a click through
//   agreement.  This is the text that will be displayed that the user must agree to.
//   Place a '%s' where you want the 'I agree' and 'I do not agree' buttons to be placed.
//   PLEASE NOTE: you at least need to change the email address
$clickThroughText =
"<center><h2>Installer Agreement</h2></center>
<p>As the creator of the VCL image, you are responsible for understanding and 
complying with the terms and conditions of the license agreement(s) for all 
software installed within the VCL image.</p>

<p>Please note that many licenses for instructional use do not allow research 
or other use. You should be familiar with these license terms and 
conditions, and limit the use of your image accordingly.</p>

%s

<p>** If you have software licensing questions or would like assistance 
regarding specific terms and conditions, please contact 
<a href=mailto:software@example.org>software@example.org</a>.</p>";


#######################   end required modifications ###########################

define("BASEURL", "https://{$_SERVER['HTTP_HOST']}/vcl");   // no trailing slash - all of the URL except /index.php
define("SCRIPT", "/index.php");                 // this should only be "/index.php" unless you rename index.php to something else
define("HOMEURL", "https://{$_SERVER['HTTP_HOST']}/vcl/"); // url to go to when someone clicks HOME or Logout
define("COOKIEDOMAIN", "{$_SERVER['HTTP_HOST']}");       // domain in which cookies are set

define("DEFAULTGROUP", "adminUsers"); // if a user is in no groups, use reservation
										  //   length attriubtes from this group
define("DEFAULT_AFFILID", 1);
define("DAYSAHEAD", 4);       // number of days after today that can be scheduled
define("DEFAULT_PRIVNODE", 2);
define("MAXVMLIMIT", 100);
define("SCHEDULER_ALLOCATE_RANDOM_COMPUTER", 0); // set this to 1 to have the scheduler assign a randomly allocated
                                                 // computer of those available; set to 0 to assign the computer with
                                                 // the best combination of specs
define("PRIV_CACHE_TIMEOUT", 15); // time (in minutes) that we cache privileges in a session before reloading them
/// defines the min number of block request machines
define("MIN_BLOCK_MACHINES", 1);
/// defines the max number of block request machines
define("MAX_BLOCK_MACHINES", 70);
/// defines the URL used for the Documentation link in the navigation list
define("DOCUMENTATIONURL", "https://cwiki.apache.org/confluence/display/VCL/Using+VCL");
define("USEFILTERINGSELECT", 1); // set to 1 to use a dojo filteringselects for some of the select boxes
                                 // the filteringselect can be a little slow for a large number of items
define("FILTERINGSELECTTHRESHOLD", 1000); // if USEFILTERINGSELECT = 1, only use them for selects up to this size

define("SEMTIMEOUT", "45");

define("DEFAULTTHEME", 'default'); // this is the theme that will be used for the login screen and when the site is placed in maintenance if $_COOKIE['VCLSKIN'] is not set
define("HELPFAQURL", "http://vcl.example.org/help-faq/");

define("ALLOWADDSHIBUSERS", 0); // this is only related to using Shibboleth authentication for an affiliation that does not
                                // also have LDAP set up (i.e. affiliation.shibonly = 1)
                                // set this to 1 to allow users be manually added to VCL before they have ever logged in
                                // through things such as adding a user to a user group or directly granting a user a
                                // privilege somewhere in the privilege tree. Note that if you enable this and typo
                                // a userid, there is no way to verify that it was entered incorrectly so the user
                                // will be added to the database with the typoed userid

define("MAXINITIALIMAGINGTIME", 720); // for imaging reservations, users will have at least this long as the max selectable duration

define("MAXSUBIMAGES", 5000);  // maximum allowed number for subimages in a config

$ENABLE_ITECSAUTH = 0;     // use ITECS accounts (also called "Non-NCSU" accounts)

# xmlrpcBlockAPIUsers is an array of ids from user table for users that are
# allowed to call XMLRPC functions designed specifically to be called by vcld
$xmlrpcBlockAPIUsers = array(3, # 3 = vclsystem
);

# boolean value of 0 or 1 to enable documentation links on login page and page
#   where authentication method is selected
# 0 = disables; 1 = enabled
define("NOAUTH_HOMENAV", 0);

# boolean value of 0 or 1 to control logging of non SELECT database queries for auditing or debugging purposes; queries are logged to the querylog table
define("QUERYLOGGING", 1);

# boolean value of 0 or 1 to control logging of XMLRPC calls for auditing or debugging purposes; queries are logged to the xmlrpcLog table
define("XMLRPCLOGGING", 1);

# documentation links to display on login page and page
#   where authentication method is selected when NOAUTH_HOMENAV is set to 1
$NOAUTH_HOMENAV = array (
	"What is VCL" => "http://vcl.apache.org/",
	"How to use VCL" => "https://cwiki.apache.org/confluence/display/VCL/Using+VCL",
	"Report a Problem" => "mailto:" . HELPEMAIL,
);

@require_once(".ht-inc/secrets.php");

$authMechs = array(
	"Local Account"    => array("type" => "local",
	                            "affiliationid" => 1,
	                            "help" => "Only use Local Account if there are no other options"),
	/*"Shibboleth (UNC Federation)" => array("type" => "redirect",
	                     "URL" => "https://federation.northcarolina.edu/wayf/wayf_framed.php?fed=FED_SHIB_UNC_DEV&version=dropdown&entityID=https%3A%2F%2Fvcl.ncsu.edu%2Fsp%2Fshibboleth&return=http%3A%2F%2Fvcl.ncsu.edu%2FShibboleth.sso%2FDS%3FSAMLDS%3D1%26target%3Dhttp%3A%2F%2Fvcl.ncsu.edu%2Fscheduling%2Fshibauth%2F",
	                     "affiliationid" => 0, // this should always be 0 for Shibboleth authentication
	                     "help" => "Use Shibboleth (UNC Federation) if you are from a University in the UNC system and do not see another method specifically for your university"),*/
	/*"EXAMPLE1 LDAP" => array("type" => "ldap",
	                           "server" => "ldap.example.com",   # hostname of the ldap server
	                           "binddn" => "dc=example,dc=com",  # base dn for ldap server
	                           "userid" => "%s@example.com",     # this is what we add to the actual login id to authenticate a user via ldap
	                                                             #    use a '%s' where the actual login id will go
	                                                             #    for example1: 'uid=%s,ou=accounts,dc=example,dc=com'
	                                                             #        example2: '%s@example.com'
	                                                             #        example3: '%s@ad.example.com'
	                           "unityid" => "samAccountName",    # ldap field that contains the user's login id
	                           "firstname" => "givenname",       # ldap field that contains the user's first name
	                           "lastname" => "sn",               # ldap field that contains the user's last name
	                           "email" => "mail",                # ldap field that contains the user's email address
	                           "defaultemail" => "@example.com", # if for some reason an email address may not be returned for a user, this is what
	                                                             #    can be added to the user's login id to send mail
	                           "masterlogin" => "vcluser",       # privileged login id for ldap server
	                           "masterpwd" => "*********",       # privileged login password for ldap server
	                           "affiliationid" => 3,             # id from affiliation id this login method is associated with
	                           "lookupuserbeforeauth" => 0,      # set this to 1 to have VCL use masterlogin to lookup the full DN of the user
	                                                             #   and use that for the ldap bind to auth the user instead of just using the userid
	                                                             #   field from above
	                           "lookupuserfield" => '',          # if lookupuserbeforeauth is set to 1, this is the attribute to use to search in ldap
	                                                             #   for the user.  Typically either 'cn', 'uid', or 'samaccountname'
	                           "help" => "Use EXAMPLE1 LDAP if you are using an EXAMPLE1 account"), # message to be displayed on login page about when
	                                                                                                #   to use this login mechanism*/
);

$affilValFunc = array();
$affilValFuncArgs = array();
$addUserFunc = array();
$addUserFuncArgs = array();
$updateUserFunc = array();
$updateUserFuncArgs = array();
foreach($authMechs as $key => $item) {
	if($item['type'] == 'ldap') {
		$affilValFunc[$item['affiliationid']] = 'validateLDAPUser';
		$affilValFuncArgs[$item['affiliationid']] = $key;
		$addUserFunc[$item['affiliationid']] = 'addLDAPUser';
		$addUserFuncArgs[$item['affiliationid']] = $key;
		$updateUserFunc[$item['affiliationid']] = 'updateLDAPUser';
		$updateUserFuncArgs[$item['affiliationid']] = $key;
	}
	elseif($item['type'] == 'local') {
		$affilValFunc[$item['affiliationid']] = create_function('', 'return 0;');
		$addUserFunc[$item['affiliationid']] = create_function('', 'return NULL;');
		$updateUserFunc[$item['affiliationid']] = create_function('', 'return NULL;');
	}
}

$findAffilFuncs = array("testGeneralAffiliation");

#require_once(".ht-inc/authmethods/itecsauth.php");
#require_once(".ht-inc/authmethods/ldapauth.php");
#require_once(".ht-inc/authmethods/shibauth.php");
?>
