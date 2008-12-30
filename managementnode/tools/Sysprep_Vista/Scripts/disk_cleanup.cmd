set SCRIPT_DIR=%~dp0

echo Importing Disk Cleanup registry settings...
"%SystemRoot%\system32\reg.exe" IMPORT "%SCRIPT_DIR%disk_cleanup.reg"
if errorlevel 1 goto FAIL
echo.

echo Running Disk Cleanup...
"%SystemRoot%\system32\cleanmgr.exe" /SAGERUN:01
if errorlevel 1 goto FAIL
echo.

:SUCCESS
echo Disk Cleanup: SUCCESS
exit /B 0

:FAIL
echo Disk Cleanup: FAIL
exit /B 1
