#!/bin/bash

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

if [[ -z $1 ]]; then
	echo "Description:"
	echo "$0 copies the relavent parts of dojo's css to a VCL theme's css directory"
	echo
	echo "Usage:"
	echo
	echo "	$0 <name of skin>"
	exit 1
fi

skin=$1
pwd=`pwd`

path=`dirname $pwd/$0`

if [[ ! -d $path/../dojo/dijit/themes/tundra ]]; then
	echo "could not find dojo's tundra theme at $path/../dojo/dijit/themes/tundra"
	exit 2
fi

if [[ ! -d $path/$skin ]]; then
	echo could not find theme \"$skin\" under $path
	exit 3
fi

if [[ ! -d $path/$skin/css ]]; then
	mkdir $path/$skin/css
fi

if ! cp -R $path/../dojo/dijit/themes/tundra $path/$skin/css/dojo; then
	echo failed to copy tundra theme to $path/$skin/css/dojo
	echo "remove $path/$skin/css/dojo before retrying (if it exists)"
	exit 4
fi

cd $path/$skin/css/dojo
mv tundra.css $skin.css
if [[ -r tundra.css.commented.css ]]; then
	mv tundra.css.commented.css $skin.css.commented.css
fi
mv tundra_rtl.css ${skin}_rtl.css
if [[ -r tundra_rtl.css.commented.css ]]; then
	mv tundra_rtl.css.commented.css ${skin}_rtl.css.commented.css
fi

if [[ -r ${skin}_rtl.css ]] && grep -q tundra_rtl.css ${skin}.css; then
	sed -i "s/tundra_rtl/${skin}_rtl/" ${skin}.css
	sed -i "s|\.\./dijit_rtl|../../../../dojo/dijit/themes/dijit_rtl|" ${skin}_rtl.css
	sed -i "s|\.\./\.\./icons/editorIcons_rtl|../../../../dojo/dijit/icons/editorIcons_rtl|" ${skin}_rtl.css
fi

for f in $(grep -l '\.tundra' *.css layout/*.css form/*.css); do
	if ! sed -i "s/\.tundra/\.$skin/g" $f; then
		echo failed to change string \"tundra\" to \"$skin\" in $path/$skin/css/dojo/$f
		echo remove $path/$skin/css/dojo before retrying
		exit 5
	fi
done

cp $skin.css $skin.css.save
if ! sed -i "s/\.\.\/dijit.css/..\/..\/..\/..\/dojo\/dijit\/themes\/dijit.css/" $skin.css; then
	echo failed to change path to dijit.css in $path/$skin/css/dojo/$skin.css
	echo remove $path/$skin/css/dojo before retrying
	exit 6
fi
if ! sed -i "s|\.\./\.\./icons/commonIcons|../../../../dojo/dijit/icons/commonIcons|" $skin.css; then
	echo failed to change path to commonIcons.css in $path/$skin/css/dojo/$skin.css
	echo remove $path/$skin/css/dojo before retrying
	exit 7
fi
if ! sed -i "s|\.\./\.\./icons/editorIcons|../../../../dojo/dijit/icons/editorIcons|" $skin.css; then
	echo failed to change path to commonIcons.css in $path/$skin/css/dojo/$skin.css
	echo remove $path/$skin/css/dojo before retrying
	exit 7
fi

echo Successfully copied dojo css to $skin
