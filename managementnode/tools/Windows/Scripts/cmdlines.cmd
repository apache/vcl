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

rem This script reconfigures the Cygwin sshd service. 
rem It regenerates the computer's host keys. This is necessary
rem when Sysprep is run and a new SID is generated.
rem This script MUST be run by the root account or else the 
rem sshd service will not start.
set /A STATUS=0

echo ======================================================================
echo %~nx0 beginning to run at: %DATE% %TIME%
echo.

echo Sleeping for 5 seconds to allow networking to initialize...
C:\Cygwin\bin\sleep.exe 5 2>&1
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing C:\Cygwin\home\root\VCL\Scripts\query_registry.cmd...
echo %~nx0 start: >> C:\Cygwin\home\root\VCL\Logs\query_registry.log
start "query_registry.cmd" /WAIT cmd.exe /c "C:\Cygwin\home\root\VCL\Scripts\query_registry.cmd >> C:\Cygwin\home\root\VCL\Logs\query_registry.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing set_computer_name.vbs...
start "set_computer_name.vbs" /WAIT cmd.exe /c "C:\Windows\system32\cscript.exe //NoLogo C:\Cygwin\home\root\VCL\Scripts\set_computer_name.vbs >> C:\Cygwin\home\root\VCL\Logs\set_computer_name.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing autologon_enable.cmd...
start "autologon_enable.cmd" /WAIT cmd.exe /c "C:\Cygwin\home\root\VCL\Scripts\autologon_enable.cmd >> C:\Cygwin\home\root\VCL\Logs\autologon_enable.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing query_registry.cmd...
echo %~nx0 end: >> C:\Cygwin\home\root\VCL\Logs\query_registry.log
start "query_registry.cmd" /WAIT cmd.exe /c "C:\Cygwin\home\root\VCL\Scripts\query_registry.cmd >> C:\Cygwin\home\root\VCL\Logs\query_registry.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %~nx0 finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
exit /B %STATUS%
