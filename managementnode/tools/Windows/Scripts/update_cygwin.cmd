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
rem This script reconfigures the Cygwin sshd service. It regenerates the
rem computer's SSH host keys. This is necessary when Sysprep is run and
rem new SIDs are generated.  This script MUST be run by the root account
rem or else the sshd service will not start.

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

echo %TIME%: Killing any cyg* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq cyg*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any ssh* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq ssh*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any bash* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq bash*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Deleting old /etc/group file...
del /F /S /Q /A C:\Cygwin\etc\group
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Deleting old /etc/passwd file...
del /F /S /Q /A C:\Cygwin\etc\passwd
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Creating new "group" file...
C:\Cygwin\bin\mkgroup.exe -l > C:\Cygwin\etc\group
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Creating new "passwd" file
C:\Cygwin\bin\mkpasswd.exe -l > C:\Cygwin\etc\passwd
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

rem Remove leading computer name: VCLV98-249+root: --> root:
C:\Cygwin\bin\sed.exe -i -e "s/^[^:]\++//" /etc/group
C:\Cygwin\bin\sed.exe -i -e "s/^[^:]\++//" /etc/passwd

rem Change root's primary group from 'None' to 'Administrators'
C:\Cygwin\bin\sed.exe -i -e "s/\(^root:.*:\)\(513\|197121\)\(:.*\)/\1544\3/" /etc/passwd

echo ----------------------------------------------------------------------

echo %TIME%: Restoring ownership of /etc/ssh* files...
C:\Cygwin\bin\chown.exe -v root:None /etc/ssh* 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Restoring ownership of /home/root/.ssh...
C:\Cygwin\bin\chown.exe -v -R root:None /home/root/.ssh  2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Restoring ownership of /var/empty...
C:\Cygwin\bin\chown.exe -v root:None /var/empty 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Restoring ownership of /var/log/sshd.log...
C:\Cygwin\bin\chown.exe -v root:None /var/log/sshd.log 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Restoring ownership of /var/log/lastlog...
C:\Cygwin\bin\chown.exe -v root:None /var/log/lastlog 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Deleting old SSH keys...
del /F /S /Q /A "C:\Cygwin\etc\ssh_host_*"
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Regenerating /etc/ssh_host_key...
C:\Cygwin\bin\bash.exe -c 'C:/Cygwin/bin/ssh-keygen.exe -f /etc/ssh_host_key -N ""' 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Regenerating /etc/ssh_host_rsa_key...
C:\Cygwin\bin\bash.exe -c 'C:/Cygwin/bin/ssh-keygen.exe -t rsa -f /etc/ssh_host_rsa_key -N ""' 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Regenerating /etc/ssh_host_dsa_key...
C:\Cygwin\bin\bash.exe -c 'C:/Cygwin/bin/ssh-keygen.exe -t dsa -f /etc/ssh_host_dsa_key -N ""' 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Killing any cyg* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq cyg*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any ssh* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq ssh*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any bash* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq bash*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any ash* processes...
"%SystemRoot%\System32\taskkill.exe" /F /FI "IMAGENAME eq ash*" 2>NUL
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Tasks running before attempting to executing rebaseall:
"%SystemRoot%\System32\tasklist.exe" /V

echo %TIME%: Running /usr/bin/rebaseall in the ash.exe shell
C:\cygwin\bin\ash.exe -c '/usr/bin/rebaseall' 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Setting sshd service startup mode to auto...
"%SystemRoot%\System32\sc.exe" config sshd start= auto 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Starting the sshd service...
"%SystemRoot%\System32\net.exe" start sshd 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %TIME%: Deleting 'VCL Update Cygwin' scheduled task...
"%SystemRoot%\system32\schtasks.exe" /Delete /F /TN "VCL Update Cygwin"
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo ----------------------------------------------------------------------

echo %SCRIPT_FILENAME% finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_FILENAME% /ID 555 /D "exit status: %STATUS%" 2>&1

exit /B %STATUS%
