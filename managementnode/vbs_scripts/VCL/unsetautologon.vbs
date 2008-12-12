On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")

' Turn off auto-login
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "0"

WScript.Quit
