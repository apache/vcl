On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
Set oFileSystem = CreateObject("Scripting.FileSystemObject")
Set WshNetwork = WScript.CreateObject("WScript.Network")
sTempDir = oWshEnvironment("TEMP")
Dim oExec
Dim GuiAnswer
strComputer = "."

'copy VCLrcboot.cmd to Logon
oFileSystem.CopyFile "C:/cygwin/home/root/VCLrcboot.vbs", "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\",true
WScript.Echo "copied VCLrcboot"

'set autologin
' setup DefaultUserName as root
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultUserName", "root"

' setup DefaultPassword
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultPassword", "cl0udy"

' Turn on auto-login
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "1"

WScript.Echo "set autologin for root account"

'shutdown
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate,(Shutdown)}!\\" & MyName & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery _
    ("Select * from Win32_OperatingSystem")
For Each objOperatingSystem in colOperatingSystems
    intreturn = ObjOperatingSystem.Win32Shutdown(5)
    if intreturn = 0 Then
       WScript.echo "createimage shutdown"
     Else
       Wscript.echo "shutdown failed error code " & intreturn
     End If 
Next

WScript.Quit
