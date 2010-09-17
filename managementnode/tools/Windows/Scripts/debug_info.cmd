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

rem DESCRIPTION:
rem Displays various debugging information helpful in troubleshooting
rem Windows image problems.

set /A STATUS=0

rem Get the name of this batch file and the directory it is running from
set SCRIPT_NAME=%~n0
set SCRIPT_FILENAME=%~nx0
set SCRIPT_DIR=%~dp0
rem Remove trailing slash from SCRIPT_DIR
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

set PROFILELIST_KEY=HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList
set GREP=C:\Cygwin\bin\grep.exe
set SED=C:\Cygwin\bin\sed.exe

echo ======================================================================
echo %SCRIPT_FILENAME% beginning to run at: %DATE% %TIME%
echo Directory %SCRIPT_FILENAME% is running from: %SCRIPT_DIR%
echo.

echo ----------------------------------------------------------------------

echo Querying registry for computer's SID...
"%SystemRoot%\system32\reg.exe" QUERY "%PROFILELIST_KEY%" | %GREP% "500" | %SED% -r -e 's/.*\\\\//' | %SED% -r -e 's/-500$//'
echo.

echo ----------------------------------------------------------------------

echo Environment:
set
echo.

echo ----------------------------------------------------------------------

echo Querying HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DevicePath registry key...
"%SystemRoot%\system32\reg.exe" query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion /v DevicePath 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Querying HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run registry key...
"%SystemRoot%\system32\reg.exe" query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Displaying contents of scripts.ini...
type "%SYSTEMROOT%\system32\GroupPolicy\User\Scripts\scripts.ini" 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %SCRIPT_FILENAME% finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "exit status: %STATUS%" 2>&1

echo.
echo.
exit /B %STATUS%
