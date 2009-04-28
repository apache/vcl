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

copy "C:\Documents and Settings\root\Application Data\VCL\VCLprepare.cmd" C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\

del C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCLcleanup.cmd

cd %APPDATA%/vcl

%SystemRoot%\system32\cmd.exe /c C:\WINDOWS\regedit.exe /s nodyndns.reg

%SystemRoot%\system32\cmd.exe /c wsname.exe /N:$DNS /MCN

%SystemRoot%\system32\cscript.exe enablepagefile.vbs

%SystemRoot%\system32\cmd.exe /c C:\WINDOWS\system32\ping.exe 1.1.1.1 %-n 1 -w 2000 > NUL

%SystemRoot%\system32\cmd.exe /c newsid.exe /a /d 6

del C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\VCLrcboot.cmd 
