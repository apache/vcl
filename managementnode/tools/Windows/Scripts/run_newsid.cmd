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
rem This script runs after an image which is configured to use NewSID is booted.
rem It enables autologon, configures a HKLM run key which causes post_load.cmd to
rem automatically run for the next user who logs on, sets the computer name, and
rem then runs newsid.exe, which reboots the computer.

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

echo Sleeping for 5 seconds to allow networking to initialize...
C:\Cygwin\bin\sleep.exe 5 2>&1
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing %SCRIPT_DIR%\autologon_enable.cmd...
start "autologon_enable.cmd" /WAIT cmd.exe /c "%SCRIPT_DIR%\autologon_enable.cmd >> %LOGS_DIR%\autologon_enable.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing %SCRIPT_DIR%\add_post_load_run_key.cmd...
start "add_post_load_run_key.cmd" /WAIT cmd.exe /c "%SCRIPT_DIR%\add_post_load_run_key.cmd >> %LOGS_DIR%\add_post_load_run_key.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Executing %SCRIPT_DIR%\set_computer_name.vbs...
start "set_computer_name.vbs" /WAIT cmd.exe /c "C:\Windows\system32\cscript.exe //NoLogo %SCRIPT_DIR%\set_computer_name.vbs >> %LOGS_DIR%\set_computer_name.log 2>&1"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Deleting registry HKLM-Run command to run %SCRIPT_FILENAME%...
"%SystemRoot%\system32\reg.exe" DELETE "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SCRIPT_FILENAME%" /f
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo Adding EulaAccepted registry key so newsid.exe doesn't hang...
"%SystemRoot%\system32\reg.exe" ADD "HKEY_CURRENT_USER\Software\Sysinternals\NewSID" /v EulaAccepted /d 1 /t REG_DWORD /f
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%

echo ----------------------------------------------------------------------

echo %TIME%: Executing newsid.exe, this should reboot the computer...
start "newsid.exe" /WAIT cmd.exe /c "%SCRIPT_DIR%\..\Utilities\NewSID\newsid.exe /a"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%

echo ----------------------------------------------------------------------

echo %SCRIPT_FILENAME% finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "exit status: %STATUS%" 2>&1

exit /B %STATUS%
