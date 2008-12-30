rem http://support.microsoft.com/kb/939039

rem------------------------------------------------------------------
rem This task defragments the computers hard disk drives.

set TITLE=defragment hard disk drives
set TASK_NAME=\Microsoft\Windows\Defrag\ScheduledDefrag

echo Disabling %TITLE% scheduled task...
"%SystemRoot%\system32\schtasks.exe" /Change /DISABLE /TN "%TASK_NAME%"
if errorlevel 1 goto FAIL
echo.

rem------------------------------------------------------------------
rem This task creates regular system protection points.

set TITLE=system restore
set TASK_NAME=\Microsoft\Windows\SystemRestore\SR

echo Disabling %TITLE% scheduled task...
"%SystemRoot%\system32\schtasks.exe" /Change /DISABLE /TN "%TASK_NAME%"
if errorlevel 1 goto FAIL
echo.


rem------------------------------------------------------------------
rem If the user has consented to participate in the Windows 
rem Customer Experience Improvement Program, this job collects 
rem and sends usage data to Microsoft.

set TITLE=consolidator
set TASK_NAME=\Microsoft\Windows\Customer Experience Improvement Program\Consolidator

echo Disabling %TITLE% scheduled task...
"%SystemRoot%\system32\schtasks.exe" /Change /DISABLE /TN "%TASK_NAME%"
if errorlevel 1 goto FAIL
echo.

rem------------------------------------------------------------------
rem This scheduled task prompts the Microsoft Windows Software 
rem Quality Metrics opt-in notification.

set TITLE=optin notification
set TASK_NAME=\Microsoft\Windows\Customer Experience Improvement Program\OptinNotification

echo Disabling %TITLE% scheduled task...
"%SystemRoot%\system32\schtasks.exe" /Change /DISABLE /TN "%TASK_NAME%"
if errorlevel 1 goto FAIL
echo.


rem------------------------------------------------------------------

:SUCCESS
echo Disable %TITLE% scheduled task: SUCCESS
exit /B 0

:FAIL
echo Disable %TITLE% scheduled task: FAIL
exit /B 1
