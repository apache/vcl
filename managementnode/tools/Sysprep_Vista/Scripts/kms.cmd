echo Configuring Vista to use a KMS server for activation...
"%SystemRoot%\system32\cscript.exe" //NoLogo "%SystemRoot%\system32\slmgr.vbs" -skms kms.unity.ad.ncsu.edu:1688
if errorlevel 1 goto FAIL
echo.

echo Attempting Microsoft activation...
"%SystemRoot%\system32\cscript.exe" //NoLogo "%SystemRoot%\system32\slmgr.vbs" -ato
if errorlevel 1 goto FAIL
echo.

rem------------------------------------------------------------------

:SUCCESS
echo Disable %TITLE% scheduled task: SUCCESS
exit /B 0

:FAIL
echo Disable %TITLE% scheduled task: FAIL
exit /B 1
