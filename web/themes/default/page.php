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
	global $user, $mode, $authed;
	$rt  = "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\">\n";
	$rt .= "<html lang=\"en\">\n";
	$rt .= "<head>\n";
	$rt .= "<title>VCL :: Virtual Computing Lab</title>\n";
	$rt .= "<link rel=stylesheet type=\"text/css\" href=\"css/vcl.css\">\n";
	$rt .= "<link rel=stylesheet type=\"text/css\" href=\"themes/default/css/vcl.css\">\n";
	if($mode == 'viewdocs')
		$rt .= "<link rel=stylesheet type=\"text/css\" href=\"css/doxygen.css\" />\n";
	$rt .= "<script src=\"js/code.js\" type=\"text/javascript\"></script>\n";
	$rt .= "<script type=\"text/javascript\">\n";
	$rt .= "var cookiedomain = '" . COOKIEDOMAIN . "';\n";
	$rt .= "</script>\n";
	$rt .= getDojoHTML($refresh);
	if($refresh)
		$rt .= "<noscript><META HTTP-EQUIV=REFRESH CONTENT=20></noscript>\n";
	$rt .= "</head>\n\n";
	$rt .= "<body>\n\n";
	$rt .= "<a class=hidden href=\"#content\" accesskey=2>Skip to content</a>\n";
	$rt .= "<table border=0 cellpadding=0 cellspacing=0 summary=\"\">\n";
	$rt .= "  <TR>\n";
	$rt .= "    <TD width=80px nowrap></TD>\n";
	$rt .= "    <TD width=6px background=\"themes/default/images/background_L.png\" nowrap></TD>\n";
	$rt .= "    <TD width=8px background=\"themes/default/images/background_gradient.gif\" nowrap></TD>\n";
	$rt .= "    <TD background=\"themes/default/images/background_gradient.gif\" width=\"100%\">\n";
	$rt .= "    <table border=0 cellpadding=0 cellspacing=0 width=\"100%\" summary=\"\">\n";
	$rt .= "      <TR>\n";
	$rt .= "        <TD width=1px background=\"themes/default/images/black.jpg\" nowrap></TD>\n";
	$rt .= "        <TD width=215px nowrap><img src=\"themes/default/images/vclbanner_L.jpg\" alt=\"\"></TD>\n";
	$rt .= "        <TD background=\"themes/default/images/vclbanner_C.jpg\" width=\"100%\"></TD>\n";
	$rt .= "        <TD width=198px nowrap><img src=\"themes/default/images/vclbanner_R.jpg\" alt=\"\"></TD>\n";
	$rt .= "        <TD width=3px background=\"themes/default/images/content_border_R.jpg\" nowrap></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "      <TR>\n";
	$rt .= "        <TD width=1px background=\"themes/default/images/black.jpg\" nowrap></TD>\n";
	$rt .= "        <TD background=\"themes/default/images/bar_bg.jpg\" width=\"100%\" colspan=3 height=23px></TD>\n";
	$rt .= "        <TD width=3px background=\"themes/default/images/content_border_R.jpg\" nowrap></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "    </table>\n";
	$rt .= "    <table border=0 cellpadding=0 cellspacing=0 width=\"100%\" summary=\"\">\n";
	$rt .= "      <TR valign=top>\n";
	$rt .= "        <TD width=160px background=\"themes/default/images/menu_bg.jpg\" nowrap>\n";
	$rt .= "<div id=menulist>\n";
	$rt .= "<h3 class=hidden>Resources</h3>\n";
	$rt .= "<ul>\n";
	if($authed)
		$rt .= getNavMenu(1, 1);
	/*else
		$rt .= "<img src=\"themes/default/images/belltower.jpg\" height=200 width=160 alt=\"\">\n";*/
	$rt .= "</ul>\n";
	if($authed)
		$rt .= "<img src=\"themes/default/images/menu_dividerblock.jpg\" border=0 width=158 height=83 alt=\"\"><br/>\n";
	$rt .= "</div>\n";
	$rt .= "        </TD>\n";
	$rt .= "        <TD width=\"100%\" style=\"align: left; background: #ffffff;\">\n";
	$rt .= "<div id=content class=default>\n";
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
	$rt .= "        <TD width=3px background=\"themes/default/images/content_border_R.jpg\" nowrap></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "      <TR>\n";
	$rt .= "        <TD width=160px nowrap><img src=\"themes/default/images/background_bottom_L.jpg\" alt=\"\"></TD>\n";
	$rt .= "        <TD background=\"themes/default/images/background_bottom_C.jpg\" width=\"100%\"></TD>\n";
	$rt .= "        <TD width=3px nowrap><img src=\"themes/default/images/background_bottom_R.jpg\" alt=\"\"></TD>\n";
	$rt .= "      </TR>\n";
	$rt .= "    </table>\n";
	$rt .= "<div id=\"footer\">\n";
	$rt .= "<div id=\"footer-box-right\">\n";
	$rt .= "<p>\n";
	$rt .= "Copyright &#169; 2004-$year by Apache Software Foundation, All Rights Reserved.\n";
	$rt .= "</p>\n";
	$rt .= "</div>\n";
	$rt .= "</div>\n";
	$rt .= "<!-- end footer -->\n";
	$rt .= "</TD>\n";
	$rt .= "<TD width=8px background=\"themes/default/images/background_gradient.gif\" nowrap></TD>\n";
	$rt .= "<TD width=6px background=\"themes/default/images/background_R.png\" nowrap></TD>\n";
	$rt .= "<TD width=80px nowrap></TD>\n";
	$rt .= "</TR>\n";
	$rt .= "</table>\n";
	$rt .= "</body>\n";
	$rt .= "</html>\n";
	return $rt;
}
