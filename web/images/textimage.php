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

$face = "fonts/DroidSans-Bold.ttf";

function vectordist($a, $b){
	if($a < 0 && $b < 0) return abs($a - $b);
	else if( $a < 0 || $b < 0) return abs($a) + abs($b);
	else return abs($a - $b);
}

// create a filename safe version of the provided text for the button
$text = $_GET["text"];
$lowertext = strtolower($_GET["text"]);
$pattern = "/\W/";
$replacement = "";
$lowertext = preg_replace($pattern, $replacement, $lowertext);
//if($_GET["style"] == "off") $lowertext .= "_off";
//else $lowertext .= "_on";

// these headers are needed so the browser knows what it is getting
header('Content-Type: image/gif');
header('Content-Disposition: inline; filename=$lowertext.gif');

// calculate the size the text will fill
$size = imagettfbbox( 14, 90, $face, $text);
$height = vectordist($size[1], $size[3]);
$width = vectordist($size[0], $size[4]) + 2;
#print "<pre>\n";
#print_r($size);
#print "</pre>\nwidth - $width<br>height - $height<br>\n";

// create an "image resource" big enough to show the text and have some padding.
// set the background color, the text color, and make the background color the
// transparency color.
$image = imagecreate($width, $height);
#imagecolorallocate($image, 0xDD, 0xDD, 0xDD);
#imagefill($image, 0, 0, 0xDDDDDD);
$background = imagecolorallocate($image, 0xFF, 0xFF, 0xFF);
$textcolor = imagecolorallocate($image, 0, 0, 0);
imagecolortransparent($image, $background);

// this line inserts the text into the image, I have noticed that the font sizes
// that GD uses do not really match point sizes. 11 below roughly matches 15 points.
// 90 is the angle the text is rotated at, 5 is the horizontal displacement (right) of the text,
// $height + 2 is the vertical displacement (down) of the text.
imagettftext( $image, 13, 90, 13, $height - 5, $textcolor, $face, $text);

// output the image, destroy the resource (not really needed in this case), and terminate       
imagegif($image);       
imagedestroy($image);           
?>
