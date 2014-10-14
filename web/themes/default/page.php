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

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getHeader($refresh)
///
/// \param $refresh - bool for adding code to refresh page
///
/// \return string of html to go before the main content
///
/// \brief builds the html that goes before the main content
///
////////////////////////////////////////////////////////////////////////////////
function getHeader($refresh) {
	global $user, $mode, $authed, $locale, $VCLversion;
	$v = $VCLversion;
	#$rt  = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Frameset//EN\">\n";
	$rt  = "<!DOCTYPE html>\n";
	$rt .= "<html lang=\"$locale\">\n";
	$rt .= "<head>\n";
	$usenls = 0;
	$usenlsstr = "false";
	if(! preg_match('/^en/', $locale)) {
		$usenls = 1;
		$usenlsstr = "true";
	}
	$rt .= "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">\n";
	$rt .= "<title>VCL :: Virtual Computing Lab</title>\n";
	$rt .= "<link rel=stylesheet type=\"text/css\" href=\"css/vcl.css\">\n";
	$rt .= "<link rel=stylesheet type=\"text/css\" href=\"themes/default/css/vcl.css\">\n";
	$rt .= "<script src=\"js/code.js?v=$v\" type=\"text/javascript\"></script>\n";
	if($usenls)
		$rt .= "<script type=\"text/javascript\" src=\"js/nls/$locale/messages.js?v=$v\"></script>\n";
	$rt .= "<script type=\"text/javascript\">\n";
	$rt .= "var cookiedomain = '" . COOKIEDOMAIN . "';\n";
	$rt .= "usenls = $usenlsstr;\n";
	$rt .= "</script>\n";
	$rt .= getDojoHTML($refresh);
	if($refresh)
		$rt .= "<noscript><META HTTP-EQUIV=REFRESH CONTENT=20></noscript>\n";
	$extracss = getExtraCSS();
	foreach($extracss as $file)
		$rt .= "<link rel=stylesheet type=\"text/css\" href=\"css/$file\">\n";
	$rt .= "</head>\n\n";
	$rt .= "<body class=default>\n\n";
	$rt .= "<a class=hidden href=\"#content\" accesskey=2>Skip to content</a>\n";
	$rt .= "<table class=\"themelayouttable\" summary=\"\">\n";
	$rt .= "  <TR>\n";
	$rt .= "    <TD class=\"themelayoutsidespacer\"></TD>\n";
	$rt .= "    <TD class=\"themelayoutsidetrim\"></TD>\n";
	$rt .= "    <TD class=\"themelayoutsidetrim2\"></TD>\n";
	$rt .= "    <TD class=\"themelayoutcentercell\">\n";
	$rt .= "    <table class=\"themeheadertable\" summary=\"\">\n";
	$rt .= "      <TR style=\"background-color: white;\">\n";
	$rt .= "        <TD class=\"themelayoutsidetrim4\"></TD>\n";
	$rt .= "        <TD class=\"nopadding\"><img src=\"themes/default/images/vclbanner_L.jpg\" alt=\"\"></TD>\n";
	$rt .= "        <TD class=\"themelayoutbannercenter\">\n";
	if($mode != 'inmaintenance')
		$rt .= getSelectLanguagePulldown();
	$rt .= "        </TD>\n";
	$rt .= "        <TD class=\"nopadding\"><img src=\"themes/default/images/vclbanner_R.jpg\" alt=\"\"></TD>\n";
	$rt .= "        <TD class=\"themelayoutsidetrim5\"></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "      <TR>\n";
	$rt .= "        <TD class=\"themelayoutsidetrim4\"></TD>\n";
	$rt .= "        <TD class=\"themelayouttopseparator\" colspan=3></TD>\n";
	$rt .= "        <TD class=\"themelayoutsidetrim5\"></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "    </table>\n";

	$rt .= "    <table class=\"themelayouttable\" summary=\"\">\n";
	$rt .= "      <TR valign=top>\n";
	if($authed || NOAUTH_HOMENAV)
		$rt .= "        <TD class=\"thememenu\">\n";
	else
		$rt .= "        <TD class=\"thememenunoauth\">\n";
	$rt .= "<div id=menulist>\n";
	$rt .= "<h3 class=hidden>Resources</h3>\n";
	if($authed) {
		$rt .= "<ul>\n";
		$rt .= getNavMenu(1, 1);
		$rt .= "</ul>\n";
		$rt .= "<img src=\"themes/default/images/menu_dividerblock.jpg\" border=0 width=\"158px\" height=\"83px\" alt=\"\"><br/>\n";
	}
	elseif(NOAUTH_HOMENAV) {
		$rt .= "<ul>\n";
		$rt .= getUsingVCL();
		$rt .= "</ul>\n";
	}
	$rt .= "</div>\n";
	$rt .= "        </TD>\n";
	$rt .= "        <TD class=\"themecontent\">\n";
	$rt .= "<div id=content>\n";
	return $rt;
}

////////////////////////////////////////////////////////////////////////////////
///
/// \fn getFooter()
///
/// \return string of html to go after the main content
///
/// \brief builds the html that goes after the main content
///
////////////////////////////////////////////////////////////////////////////////
function getFooter() {
	$year = date("Y");
	$rt  = "</div>\n";
	$rt .= "        </TD>\n";
	$rt .= "        <TD class=\"themelayoutsidetrim5\"></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "      <TR>\n";
	$rt .= "        <TD class=\"themebottomleft\"></TD>\n";
	$rt .= "        <TD class=\"themebottomcenter\"></TD>\n";
	$rt .= "        <TD class=\"themebottomright\"></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "    </table>\n";
	$rt .= "<div id=\"footer\">\n";
	$rt .= "<div id=\"footer-box-right\">\n";
	$rt .= "<p>\n";
	$rt .= "Copyright &#169; 2004-$year by Apache Software Foundation, All Rights Reserved.\n";
	$rt .= "</p>\n";
	$rt .= "</div>\n";
	$rt .= "</div>\n";
	$rt .= "</TD>\n";
	$rt .= "<TD class=\"themelayoutsidetrim2\"></TD>\n";
	$rt .= "<TD class=\"themelayoutsidetrim3\"></TD>\n";
	$rt .= "<TD class=\"themelayoutsidespacer\"></TD>\n";
	$rt .= "</TR>\n";
	$rt .= "</table>\n";
	$rt .= "</body>\n";
	$rt .= "</html>\n";
	return $rt;
}
