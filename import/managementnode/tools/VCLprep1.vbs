On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
Set oFileSystem = CreateObject("Scripting.FileSystemObject")
Set WshNetwork = WScript.CreateObject("WScript.Network")
sTempDir = oWshEnvironment("TEMP")
Dim oExec
strComputer = "."

'copy VCLrcboot.cmd to Logon
oFileSystem.CopyFile "C:\Documents and Settings\root\Application Data\VCL\VCLprepare.cmd", "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\",true
WScript.Echo "copied VCLprepare"

'delete any VCL logoff scripts
oWshShell.Run "cmd.exe /C del " & "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCL*\", 0, TRUE

're-enable pagefile
strCommand = "reg.exe add " & Chr(34) & _
  "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" & Chr(34) &_
  " /v PagingFiles /d " & Chr(34) & "c:\pagefile.sys 0 0" & Chr(34) & " /t REG_MULTI_SZ /f"
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
   WScript.Sleep 100
Loop

WScript.Echo "enabling pagefile"

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
    & "{impersonationLevel=impersonate,(Shutdown)}!\\" & strComputer & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery _
    ("Select * from Win32_OperatingSystem")
For Each objOperatingSystem in colOperatingSystems
    intreturn = ObjOperatingSystem.Win32Shutdown(6)
    if intreturn = 0 Then
       WScript.echo "rebooting"
     Else
       Wscript.echo "reboot failed error code " & intreturn
     End If 
Next

WScript.Quit
