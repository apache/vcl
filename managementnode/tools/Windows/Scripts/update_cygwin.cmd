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

echo ----------------------------------------------------------------------

echo %TIME%: Killing any cygrunsrv.exe processes...
"%SystemRoot%\System32\taskkill.exe" /F /IM cygrunsrv.exe 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Killing any sshd.exe processes...
"%SystemRoot%\System32\taskkill.exe" /F /IM sshd.exe 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %TIME%: Stopping the Cygwin sshd service...
"%SystemRoot%\System32\net.exe" stop sshd  2>&1
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

echo %TIME%: Creating new "passwd" file and changing root's primary group from 'None' to 'None'
C:\Cygwin\bin\mkpasswd.exe -l | C:\Cygwin\bin\sed.exe -e 's/\(^root.*:\)513\(:.*\)/\1544\2/' > C:\Cygwin\etc\passwd
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

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
C:\Cygwin\bin\ssh-keygen.exe -t rsa1 -f /etc/ssh_host_key -N "" 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Regenerating /etc/ssh_host_rsa_key...
C:\Cygwin\bin\ssh-keygen.exe -t rsa -f /etc/ssh_host_rsa_key -N "" 2>&1
echo ERRORLEVEL: %ERRORLEVEL%
set /A STATUS+=%ERRORLEVEL%
echo.

echo %TIME%: Regenerating /etc/ssh_host_dsa_key...
C:\Cygwin\bin\ssh-keygen.exe -t dsa -f /etc/ssh_host_dsa_key -N "" 2>&1
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

echo %~nx0 finished at: %DATE% %TIME%
echo exiting with status: %STATUS%
exit /B %STATUS%
