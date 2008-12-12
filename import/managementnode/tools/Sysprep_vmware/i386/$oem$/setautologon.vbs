On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")

' setup DefaultUserName as root
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultUserName", "root"

' setup DefaultPassword
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultPassword", "cl0udy"

' Turn on auto-login
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "1"

WScript.Quit
