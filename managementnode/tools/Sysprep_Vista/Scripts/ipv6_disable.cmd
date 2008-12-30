set SCRIPT_DIR=%~dp0

echo Importing registry settings to disable IPv6...
"%SystemRoot%\system32\reg.exe" IMPORT "%SCRIPT_DIR%disable_ipv6.reg"
if errorlevel 1 goto FAIL
echo.

:SUCCESS
echo Disable IPv6: SUCCESS
exit /B 0

:FAIL
echo Disable IPv6: FAIL
exit /B 1
