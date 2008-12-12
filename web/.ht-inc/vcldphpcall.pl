#!/usr/bin/perl

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


use LWP::Simple;
use lib '/tmp/WDDX-1.02/blib/lib';
use WDDX;

my $function = "getUserResources";
my $arg1 = "imageAdmin:imageCheckOut";
my $arg2 = "available:";
my $arg3 = 0;
my $arg4 = 0;
my $arg5 = 21;

my $doc = get("http://webtest.people.engr.ncsu.edu/jfthomps/vcl/index.php?mode=vcldquery&key=1234&query=$function,$arg1,$arg2,$arg3,$arg4,$arg5");

$doc_id = new WDDX; 
$wddx_obj = $doc_id->deserialize($doc); 
$value = $wddx_obj->as_hashref(); 

@keys = $wddx_obj->keys();

foreach my $key (keys %{ $value->{"data"} }) {
	print "---------------------------------------------\n";
	print "$key\n";
	foreach my $key2 (keys %{ $value->{"data"}->{$key} }) {
		print "\t$key2 => " . $value->{"data"}->{$key}->{$key2} . "\n";
	}
}
