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
rem This script is called during the Sysprep minisetup stage and adds a
rem registry entry to HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run.
rem The added key causes post_load.cmd to be executed automatically when
rem the root account automatically logs in after Windows boots for the
rem first time.

set /A STATUS=0

rem Get the name of this batch file and the directory it is running from
set SCRIPT_NAME=%~n0
set SCRIPT_FILENAME=%~nx0
set SCRIPT_DIR=%~dp0
rem Remove trailing slash from SCRIPT_DIR
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

echo ======================================================================
echo %SCRIPT_FILENAME% beginning to run at: %DATE% %TIME%
echo Directory %SCRIPT_FILENAME% is running from: %SCRIPT_DIR%
echo.

echo ----------------------------------------------------------------------

echo Adding registry HKLM-Run command to run post_load.cmd...
"%SystemRoot%\system32\reg.exe" ADD "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /t REG_SZ /v "post_load.cmd" /d "%SCRIPT_DIR%\post_load.cmd >> %SCRIPT_DIR%\..\Logs\post_load.log" /f
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %SCRIPT_FILENAME% finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "exit status: %STATUS%" 2>&1

exit /B %STATUS%
