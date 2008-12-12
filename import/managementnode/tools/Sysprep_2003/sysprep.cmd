rem @echo off
cls

set UTILITIES=C:\Sysprep\Utilities
set VCL_SCRIPTS=C:\Documents and Settings\root\Application Data\VCL
set WINDOWS_SCRIPTS=%SystemRoot%\System32\GroupPolicy\User\Scripts
set DOCS=%SystemDrive%\Documents and Settings


:VCL_SCRIPTS
echo Removing old VCL scripts...
rem Delete and recreate the root/AppData/VCL directory to make sure it's clean
if exist "%VCL_SCRIPTS%" rmdir /s /q "%VCL_SCRIPTS%"
mkdir "%VCL_SCRIPTS%"

rem Clear out any old files in the GroupPolicy\User\Scripts directories
if exist "%WINDOWS_SCRIPTS%\Logon\VCLprepare.cmd" del /A /S /Q /F "%WINDOWS_SCRIPTS%\Logon\VCLprepare.cmd"
if exist "%WINDOWS_SCRIPTS%\Logoff\VCLcleanup.cmd" del /A /S /Q /F "%WINDOWS_SCRIPTS%\Logoff\VCLcleanup.cmd"
echo.

echo Copying new VCL scripts...
copy /y "C:\Sysprep\Scripts\*.*" "%VCL_SCRIPTS%\"
copy /y "%VCL_SCRIPTS%\VCLprepare.cmd" "%WINDOWS_SCRIPTS%\Logon\"
echo.


:CLEAN
set DELETE=%TEMP%
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

set DELETE=%TMP%
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

set DELETE=%SystemRoot%\Temp
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

echo Removing "%SystemRoot%\*.tmp" files...
del /A /S /Q /F "%SystemRoot%\*.tmp"
echo.

set DELETE=%SystemRoot%\SoftwareDistribution\Download
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

rem Minidump files are created if an application crashes, used for debugging
set DELETE=%SystemRoot%\Minidump
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DELETE%\*"`) DO rmdir /S /Q "%DELETE%\%%x"
FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DELETE%\*"`) DO del /A /S /Q /F "%DELETE%\%%x"
echo.

rem $NtUninstall...$ are uninstall files for Windows updates
set DELETE=%SystemRoot%\$NtUninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

rem $NtServicePackUninstall...$ are uninstall files for Windows service packs
set DELETE=%SystemRoot%\$NtServicePackUninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

rem $MSI*Uninstall...$ are uninstall files for Windows Installer service updates (msiexec.exe)
set DELETE=%SystemRoot%\$MSI*Uninstall
echo Removing files and subdirectories in %DELETE%...
FOR /F "usebackq delims==" %%x IN (`dir /b "%DELETE%*"`) DO rmdir /S /Q "%SystemRoot%\%%x"
echo.

rem Dr Watson logs and memory dumps
set DELETE=%ALLUSERSPROFILE%\Application Data\Microsoft\Dr Watson
echo Removing directory %DELETE%...
if exist "%DELETE%" rmdir /S /Q "%DELETE%"
echo.

rem Page file should be disabled, try to delete it again
set DELETE=%SystemDrive%\pagefile.sys
echo Removing file %DELETE%...
if exist "%DELETE%" del /A /S /Q /F "%DELETE%"
echo.

rem inf\oem* and infcache.1 files are cached OEM drivers, removal suggested by vernalex.com
echo Removing cached OEM drivers at "%SystemRoot%\inf\oem*.*"...
del /A /S /Q /F "%SystemRoot%\inf\oem*.*"
del /A /S /Q /F "%SystemRoot%\inf\infcache.1"
echo.

echo Emptying Recycle Bin...
"%UTILITIES%\EmptyRecycleBin.exe" /q
echo.


:PROFILES
echo Cleaning up user profiles...
set DELETE=Cookies
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" rmdir /S /Q "%DOCS%\%%u\%DELETE%\%%x"
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" del /A /S /Q /F "%DOCS%\%%u\%DELETE%\%%x"

set DELETE=Local Settings\Temp
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" rmdir /S /Q "%DOCS%\%%u\%DELETE%\%%x"
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" del /A /S /Q /F "%DOCS%\%%u\%DELETE%\%%x"

set DELETE=Recent
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" rmdir /S /Q "%DOCS%\%%u\%DELETE%\%%x"
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" del /A /S /Q /F "%DOCS%\%%u\%DELETE%\%%x"

set DELETE=Local Settings\Recent
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" rmdir /S /Q "%DOCS%\%%u\%DELETE%\%%x"
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" del /A /S /Q /F "%DOCS%\%%u\%DELETE%\%%x"

set DELETE=Local Settings\Temporary Internet Files
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" rmdir /S /Q "%DOCS%\%%u\%DELETE%\%%x"
FOR /F "usebackq delims==" %%u IN (`dir /b /a:d "%DOCS%\*"`) DO if exist "%DOCS%\%%u\%DELETE%" FOR /F "usebackq delims==" %%x IN (`dir /b /a:-d "%DOCS%\%%u\%DELETE%\*"`) DO if exist "%DOCS%\%%u\%DELETE%\%%x" del /A /S /Q /F "%DOCS%\%%u\%DELETE%\%%x"


:AFS
echo Stopping AFS client service...
sc stop TransarcAFSDaemon
echo Removing AFSCache and afsd_init.log files
del /A /S /Q /F "%SystemRoot%\AFSCache"
del /A /S /Q /F "%SystemRoot%\afsd_init.log"
echo.


:DRIVERS
echo Scanning drivers...
"%UTILITIES%\spdrvscn.exe" /p "C:\Sysprep\Drivers" /e inf /f /a /s /q
echo.


:EVENTLOG
echo Clearing the event logs...
"%UTILITIES%\PsTools\psloglist.exe" -accepteula -o null -c Application
"%UTILITIES%\PsTools\psloglist.exe" -accepteula -o null -c "Internet Explorer"
"%UTILITIES%\PsTools\psloglist.exe" -accepteula -o null -c Security
"%UTILITIES%\PsTools\psloglist.exe" -accepteula -o null -c System

:SYSPREP

echo Starting Sysprep...
"C:\Sysprep\sysprep.exe" -quiet -reboot -reseal -mini -activated
echo.

:END
echo Done.
