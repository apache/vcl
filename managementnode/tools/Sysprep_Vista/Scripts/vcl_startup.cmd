@echo off

rem Get the name of this batch file and the directory it is running from
set SCRIPT_NAME=%~nx0
set SCRIPT_DIR=%~dp0
rem Remove trailing slash from SCRIPT_DIR
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

echo -------------------------------------------------------
echo.

echo Directory %SCRIPT_NAME% is running from: %SCRIPT_DIR%
echo.

echo %SCRIPT_NAME% beginning to run at:
time /T
echo.

echo Stopping ntsyslog service...
net stop ntsyslog
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo Calling %SCRIPT_DIR%\configure_networking.vbs...
cscript.exe //NoLogo "%SCRIPT_DIR%\configure_networking.vbs"
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo Starting ntsyslog service...
net start ntsyslog
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo Calling %SCRIPT_DIR%\update_cygwin.cmd...
call "%SCRIPT_DIR%\update_cygwin.cmd"
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo Calling %SCRIPT_DIR%\vcl_startup_firewall.cmd...
call "%SCRIPT_DIR%\vcl_startup_firewall.cmd"
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo Generating application event log entry: %COMPUTERNAME% is READY...
"%SystemRoot%\system32\eventcreate.exe" /T INFORMATION /L APPLICATION /SO %SCRIPT_NAME% /ID 555 /D "%COMPUTERNAME% is READY."
echo ERRORLEVEL: %ERRORLEVEL%
echo.

echo %SCRIPT_NAME% finished at:
time /T

exit /B 0
