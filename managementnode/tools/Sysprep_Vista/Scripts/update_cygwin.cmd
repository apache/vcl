rem This script reconfigures the Cygwin sshd service. 
rem It regenerates the computer's host keys. This is necessary
rem when Sysprep is run and a new SID is generated.

@echo off

echo Stopping the Cygwin sshd service...
net stop sshd
echo ERRORLEVEL: %ERRORLEVEL%

echo.
echo Deleting old "passwd" and "group" files...
del /q c:\cygwin\etc\group
del /q c:\cygwin\etc\passwd
c:\cygwin\bin\sleep.exe 1

echo.
echo Creating new "group" file...
c:\cygwin\bin\mkgroup.exe -l > c:\cygwin\etc\group

echo.
echo Creating new "passwd" file and changing root's primary group from 'None' to 'Administrators'
c:\cygwin\bin\mkpasswd.exe -l | c:\cygwin\bin\sed.exe -e 's/\(^root.*:\)513\(:.*\)/\1544\2/' > c:\cygwin\etc\passwd
echo ERRORLEVEL: %ERRORLEVEL%

echo.
echo Restoring ownership of files...
c:\cygwin\bin\chown.exe -v root:None /etc/ssh*
c:\cygwin\bin\chown.exe -v -R root:None /home/
c:\cygwin\bin\chown.exe -v root:None /var/empty
c:\cygwin\bin\chown.exe -v root:None /var/log/sshd.log
c:\cygwin\bin\chown.exe -v root:None /var/log/lastlog
c:\cygwin\bin\sleep.exe 2

echo.
echo Delete old SSH keys...
del /q c:\cygwin\etc\ssh_host_*

echo.
echo Regenerating SSH keys...
c:\cygwin\bin\ssh-keygen.exe -t rsa1 -f /etc/ssh_host_key -N ""
c:\cygwin\bin\ssh-keygen.exe -t rsa -f /etc/ssh_host_rsa_key -N ""
c:\cygwin\bin\ssh-keygen.exe -t dsa -f /etc/ssh_host_dsa_key -N ""
c:\cygwin\bin\sleep.exe 1

echo.
echo Setting sshd service startup mode to auto...
"%SystemRoot%\System32\sc.exe" config sshd start= auto
echo ERRORLEVEL: %ERRORLEVEL%

echo.
echo Starting the Cygwin sshd service...
net start sshd
echo ERRORLEVEL: %ERRORLEVEL%

exit /B %ERRORLEVEL%
