echo Disabling hibernation...
"%SystemRoot%\system32\powercfg.exe" /hibernate off
if errorlevel 1 goto FAIL

:SUCCESS
echo Disable hibernation: SUCCESS
exit /B 0

:FAIL
echo Disable hibernation: FAIL
exit /B 1
