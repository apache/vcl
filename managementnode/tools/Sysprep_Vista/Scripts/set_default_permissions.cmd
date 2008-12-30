rem Check the argument and set the TARGET_PATH variable
if %1=="" goto USAGE
set TARGET_PATH=%1

rem Check if the target is a file or directory
rem Necessary because icacls.exe dies if you use the /T (traverse subdirectories) switch on a file
set LAST_CHARACTER=%TARGET_PATH:~-2,-1%
IF "%LAST_CHARACTER%"=="\" (
   echo %TARGET_PATH% appears to be a directory
   set T=/T
) ELSE IF "%~x1"=="" (
   echo %TARGET_PATH% appears to be a directory
   set T=/T
) ELSE (
   echo %TARGET_PATH% appears to be a file
   set T=
)

set ICACLS=%SystemRoot%\system32\icacls.exe
set CHMOD=C:\Cygwin\bin\chmod.exe
set CHOWN=C:\Cygwin\bin\chown.exe
set CHGRP=C:\Cygwin\bin\chgrp.exe
set LS=C:\Cygwin\bin\ls.exe

if not exist "%TARGET_PATH%" goto TARGET_NOT_EXIST
if not exist "%ICACLS%" goto ICACLS_NOT_EXIST
rem if not exist "%CHMOD%" goto CHMOD_NOT_EXIST
if not exist "%CHOWN%" goto CHOWN_NOT_EXIST
rem if not exist "%CHGRP%" goto CHGRP_NOT_EXIST


echo Setting default permissions on %TARGET_PATH%...
echo.

:UNIX_PERMISSIONS
rem Don't set unix permissions, Windows permissions will override them
rem echo Setting Unix permissions to 755...
rem "%CHMOD%" -R -v 755 %TARGET_PATH%
rem if errorlevel 1 goto FAILED
rem echo.

rem echo Setting Unix owner to root...
rem "%CHOWN%" -R -v root %TARGET_PATH%
rem if errorlevel 1 goto FAILED
rem echo.

echo Setting Unix ownership to root:None...
"%CHOWN%" -R -v root:None %TARGET_PATH%
if errorlevel 1 goto FAILED
echo.


:WINDOWS_PERMISSIONS
echo Setting Windows owner to root...
"%ICACLS%" "%TARGET_PATH%" %T% /C /setowner root
if errorlevel 1 goto FAILED
echo.

echo Resetting existing NTFS permissions and enabling inherited permissions...
"%ICACLS%" "%TARGET_PATH%" %T% /C /reset
if errorlevel 1 goto FAILED
echo.

echo Setting NTFS permissions...
"%ICACLS%" "%TARGET_PATH%" /C /grant:r root:(OI)(CI)(F) Administrators:(OI)(CI)(F) Everyone:(OI)(CI)(RX)

if errorlevel 1 goto FAILED
echo.


:RESULTS
echo New Unix permissions...
"%LS%" -la %TARGET_PATH%
echo.

echo New Windows permissions...
"%ICACLS%" "%TARGET_PATH%"
echo.


:SUCCESS
echo Successfully set default permissions on "%TARGET_PATH%"
exit /B 0

:USAGE
echo Usage: set_default_permissions.cmd [TARGET_PATH]
exit /B 1

:TARGET_NOT_EXIST
echo Failed to set default permissions, file or directory does not exist: "%TARGET_PATH%"
exit /B 1

:ICACLS_NOT_EXIST
echo Failed to set default permissions, icacls.exe does not exist
exit /B 1

:CHMOD_NOT_EXIST
echo Failed to set default permissions, chmod.exe does not exist
exit /B 1

:CHOWN_NOT_EXIST
echo Failed to set default permissions, chown.exe does not exist
exit /B 1

:CHGRP_NOT_EXIST
echo Failed to set default permissions, chgrp.exe does not exist
exit /B 1

:FAILED
echo Failed to set default permissions on %TARGET_PATH%
exit /B 1
