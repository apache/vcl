echo off
cls

rem Get the name of this batch file and the directory it is running from
set SCRIPT_NAME=%~nx0
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
echo Directory %SCRIPT_NAME% is running from: %SCRIPT_DIR%
echo.

set UTILITIES=%SCRIPT_DIR%\Utilities
set VCL_SCRIPTS=%SCRIPT_DIR%\Scripts
set WINDOWS_SCRIPTS=%SystemRoot%\System32\GroupPolicy\User\Scripts
set WIN_SETUP_SCRIPTS=%SystemRoot%\Setup\Scripts
set DOCS=%SystemDrive%\Users
set RM=C:\Cygwin\bin\rm.exe

echo Utilities directory: %UTILITIES%
echo Scripts directory: %VCL_SCRIPTS%
echo Group policy scripts directory: %WINDOWS_SCRIPTS%
echo Windows setup scripts directory: %WIN_SETUP_SCRIPTS%
echo User profiles directory: %DOCS%

rem Check the argument and set the NEW_COMPUTER_NAME variable
if "%1"=="" (
   set NEW_COMPUTER_NAME=VCL-Computer
) ELSE (
   set NEW_COMPUTER_NAME=%1
)
echo Computer name saved in image will be: %NEW_COMPUTER_NAME%

echo -------------------------------------------------------
echo.

:CLEAN
set DELETE=%TEMP%
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

set DELETE=%TMP%
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

set DELETE=%SystemRoot%\Temp
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

echo Removing "%SystemRoot%\*.tmp" files...
del /A /S /Q /F "%SystemRoot%\*.tmp"
echo.

echo -------------------------------------------------------
echo.

set DELETE=%SystemRoot%\ie7updates
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

set DELETE=%SystemRoot%\ServicePackFiles
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

set DELETE=%SystemRoot%\SoftwareDistribution\Download
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

rem Minidump files are created if an application crashes, used for debugging
set DELETE=%SystemRoot%\Minidump
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%\*" dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo -------------------------------------------------------
echo.

rem $NtUninstall...$ are uninstall files for Windows updates
set DELETE=%SystemRoot%\$NtUninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`if exist "%DELETE%*" dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

echo -------------------------------------------------------
echo.

rem $NtServicePackUninstall...$ are uninstall files for Windows service packs
set DELETE=%SystemRoot%\$NtServicePackUninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

echo -------------------------------------------------------
echo.

rem $MSI*Uninstall...$ are uninstall files for Windows Installer service updates (msiexec.exe)
set DELETE=%SystemRoot%\$MSI*Uninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

echo -------------------------------------------------------
echo.

rem Dr Watson logs and memory dumps
set DELETE=%ALLUSERSPROFILE%\Application Data\Microsoft\Dr Watson
echo Removing directory %DELETE%...
if exist "%DELETE%" rmdir /S /Q "%DELETE%"
echo.

echo -------------------------------------------------------
echo.

echo Setting permissions and removing %SystemRoot%\inf\infcache.1...
if exist "%SystemRoot%\inf\infcache.1" call "%VCL_SCRIPTS%\set_default_permissions.cmd" "%SystemRoot%\inf\infcache.1"
if exist "%SystemRoot%\inf\infcache.1" del /A /S /Q /F "%SystemRoot%\inf\infcache.1"
echo.

rem inf\oem* and infcache.1 files are cached OEM drivers, removal suggested by vernalex.com
echo Removing cached OEM drivers at "%SystemRoot%\inf\oem*.*"...
if exist "%SystemRoot%\inf\oem*.*" del /A /S /Q /F "%SystemRoot%\inf\oem*.*"
echo.

echo -------------------------------------------------------
echo.

echo Emptying Recycle Bin...
"%UTILITIES%\EmptyRecycleBin.exe" /q
echo.

echo.

:PROFILES

FOR /F "usebackq delims=," %%f in ("%SCRIPT_DIR%\delete_profile_files.txt") DO ^
echo ------------------------------------------------------- & ^
echo Cleaning up user profiles: %%f... & ^
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO ^
echo. && ^
echo Checking directory: "%DOCS%\%%u\%%f" && ^
if exist "%DOCS%\%%u\%%f" ^
echo Directory exists: "%DOCS%\%%u\%%f" && ^
echo Removing deny permissions on: "%DOCS%\%%u\%%f" && ^
echo %ICACLS% "%DOCS%\%%u\%%f" /C /T /remove:d Everyone && ^
%ICACLS% "%DOCS%\%%u\%%f" /C /T /remove:d Everyone && ^
FOR /F "usebackq delims==" %%x IN (`dir /b /a "%DOCS%\%%u\%%f\*"`) DO ^
echo Removing attributes: "%DOCS%\%%u\%%f\%%x" && ^
echo Deleting: "%DOCS%\%%u\%%f\%%x" && ^
%RM% -vrf "%DOCS%\%%u\%%f\%%x"

echo.

echo -------------------------------------------------------
echo.

:AFS
echo Stopping AFS client service...
"%SystemRoot%\system32\sc.exe" stop TransarcAFSDaemon
echo Removing AFSCache and afsd_init.log files
if exist "%SystemRoot%\AFSCache" del /A /S /Q /F "%SystemRoot%\AFSCache"
if exist "%SystemRoot%\afsd_init.log" del /A /S /Q /F "%SystemRoot%\afsd_init.log"
echo.

echo -------------------------------------------------------
echo.

:DISK_CLEANUP
echo Running Disk Cleanup...
call "%VCL_SCRIPTS%\disk_cleanup.cmd"

echo -------------------------------------------------------
echo.

:END
echo Done

exit /B 0
