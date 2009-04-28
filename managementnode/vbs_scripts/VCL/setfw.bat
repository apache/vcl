@echo off
rem Licensed to the Apache Software Foundation (ASF) under one or more
rem contributor license agreements.  See the NOTICE file distributed with
rem this work for additional information regarding copyright ownership.
rem The ASF licenses this file to You under the Apache License, Version 2.0
rem (the "License"); you may not use this file except in compliance with
rem the License.  You may obtain a copy of the License at
rem
rem     http://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

@echo off

ipconfig /renew

ping 1.1.1.1 -n 1 -w 10000 > NUL

call "%APPDATA%\VCL\networkinfo.bat"

%SystemRoot%\system32\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 %EXTERNAL_GW% %METRIC 2

netsh firewall set icmpsetting type = 8 mode = enable interface = "%INTERNAL_NAME%"

netsh firewall set portopening protocol = TCP port = 3389 mode = enable scope = custom addresses = %INTERNAL_GW%

netsh firewall set portopening protocol = TCP port = 3389 mode = disable interface = "%EXTERNAL_NAME%"

netsh firewall set portopening protocol = TCP port = 22 name = SSHD mode = enable interface = "%INTERNAL_NAME%"
