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
rem Runs automatically after an image has be loaded onto the hard drive.
rem Performs tasks necessary to configure the computer so the management
rem node can communicate with it via SSH.
rem This script should do as little as possible and hand off other tasks
rem to the management node where possible to minimize the configuration
rem tasks saved in images.

set /A STATUS=0

rem Get the name of this batch file and the directory it is running from
set SCRIPT_NAME=%~n0
set SCRIPT_FILENAME=%~nx0
set SCRIPT_DIR=%~dp0
rem Remove trailing slash from SCRIPT_DIR
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

set LOGS_DIR=%SCRIPT_DIR%\..\Logs\%SCRIPT_NAME%
if not exist %LOGS_DIR% mkdir %LOGS_DIR%

echo ======================================================================
echo %SCRIPT_FILENAME% beginning to run at: %DATE% %TIME%
echo Directory %SCRIPT_FILENAME% is running from: %SCRIPT_DIR%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Calling %SCRIPT_DIR%\debug_info.cmd...
echo *** %SCRIPT_FILENAME% start: *** >> %LOGS_DIR%\debug_info.log
start "debug_info.cmd" /WAIT cmd.exe /c "%SCRIPT_DIR%\debug_info.cmd >> %LOGS_DIR%\debug_info.log 2>&1"
echo.

echo ----------------------------------------------------------------------

:UPDATE_CYGWIN
echo %TIME%: Calling %SCRIPT_DIR%\update_cygwin.cmd...
start "update_cygwin.cmd" /WAIT cmd.exe /c "%SCRIPT_DIR%\update_cygwin.cmd >> %LOGS_DIR%\update_cygwin.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Generating application event log entry: %COMPUTERNAME% is READY...
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "%COMPUTERNAME% is READY." 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Calling %SCRIPT_DIR%\debug_info.cmd...
echo *** %SCRIPT_FILENAME% end: *** >> %LOGS_DIR%\debug_info.log
start "debug_info.cmd" /WAIT cmd.exe /c "%SCRIPT_DIR%\debug_info.cmd >> %LOGS_DIR%\debug_info.log 2>&1"
echo.

echo ----------------------------------------------------------------------

echo %SCRIPT_FILENAME% finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "exit status: %STATUS%" 2>&1

echo.
echo Logging off %USERNAME%...
"%SystemRoot%\system32\logoff.exe" /V 2>&1
echo.

exit /B %STATUS%
