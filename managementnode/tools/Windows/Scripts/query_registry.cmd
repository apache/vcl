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

echo Environment:
set
echo.

echo ----------------------------------------------------------------------

echo Querying HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DevicePath registry key...
"%SystemRoot%\system32\reg.exe" query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion /v DevicePath 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Querying HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run registry key...
"%SystemRoot%\system32\reg.exe" query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Querying HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run registry key...
"%SystemRoot%\system32\reg.exe" query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %~nx0 finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
exit /B %STATUS%
