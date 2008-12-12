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


################   Things in this section must be modified #####################

define("BASEURL", "https://vcl.example.org");   // no trailing slash
define("SCRIPT", "/index.php");
define("HELPURL", "https://vcl.example.org/help/");
define("HELPFAQURL", "http://vcl.example.org/help-faq/");
define("HELPEMAIL", "vcl_help@example.org");
define("ERROREMAIL", "webmaster@example.org");
define("ENVELOPESENDER", "webserver@example.org");   // email address for envelope sender of mail messages
                                                     //   if a message gets bounced, it goes to this address
define("COOKIEDOMAIN", ".example.org");       // domain in which cookies are set
define("HOMEURL", "http://vcl.example.org/"); // url to go to when someone clicks HOME or Logout

#######################   end required modifications ###########################





define("DEFAULTGROUP", "adminUsers"); // if a user is in no groups, use reservation
										  //   length attriubtes from this group
define("DEFAULT_AFFILID", 1);
define("DAYSAHEAD", 4);       // number of days after today that can be scheduled
define("DEFAULT_PRIVNODE", 2);
define("MAXVMLIMIT", 100);
define("PRIV_CACHE_TIMEOUT", 15); // time (in minutes) that we cache privileges in a session before reloading them
/// defines the min number of block request machines
define("MIN_BLOCK_MACHINES", 5);
/// defines the max number of block request machines
define("MAX_BLOCK_MACHINES", 70);

$ENABLE_ITECSAUTH = 0;     // use ITECS accounts (also called "Non-NCSU" accounts)

$userlookupUsers = array(1, # admin
);

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

@require_once(".ht-inc/secrets.php");

$authMechs = array(
	"Local Account"    => array("type" => "local",
	                            "affiliationid" => 4,
	                            "help" => "Only use Local Account if there are no other options"),
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
	                           #"middlename" => "middlename",    # ldap field that contains the user's middle name (optional)
	                           "lastname" => "sn",               # ldap field that contains the user's last name
	                           "email" => "mail",                # ldap field that contains the user's email address
	                           "defaultemail" => "@example.com", # if for some reason an email address may not be returned for a user, this is what
	                                                             #    can be added to the user's login id to send mail
	                           "masterlogin" => "vcluser",       # privileged login id for ldap server
	                           "masterpwd" => "*********",       # privileged login password for ldap server
	                           "affiliationid" => 2,             # id from affiliation id this login method is associated with
	                           "help" => "Use EXAMPLE1 LDAP if you are using an EXAMPLE1 account"), # message to be displayed on login page about when
	                                                                                                #   to use this login mechanism*/
);

$affilValFunc = array(1 => create_function('', 'return 0;'),
                      /*2 => "validateLDAPUser",*/
);

$affilValFuncArgs = array(/*2 => 'EXAMPLE1 LDAP',*/
);

$addUserFunc = array(1 => create_function('', 'return 0;'),
                     /*2 => 'addLDAPUser',*/
);

$addUserFuncArgs = array(/*2 => 'EXAMPLE1 LDAP',*/
);

$updateUserFunc = array(1 => create_function('', 'return 0;'),
                        /*2 => 'updateLDAPUser',*/
);

$updateUserFuncArgs = array(/*2 => 'EXAMPLE1 LDAP',*/
);

$findAffilFuncs = array("testGeneralAffiliation");

#require_once(".ht-inc/authmethods/itecsauth.php");
#require_once(".ht-inc/authmethods/ldapauth.php");
?>
