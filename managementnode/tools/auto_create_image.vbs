
' Licensed to the Apache Software Foundation (ASF) under one or more
' contributor license agreements.  See the NOTICE file distributed with
' this work for additional information regarding copyright ownership.
' The ASF licenses this file to You under the Apache License, Version 2.0
' (the "License"); you may not use this file except in compliance with
' the License.  You may obtain a copy of the License at
'
'     http://www.apache.org/licenses/LICENSE-2.0
'
' Unless required by applicable law or agreed to in writing, software
' distributed under the License is distributed on an "AS IS" BASIS,
' WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
' See the License for the specific language governing permissions and
' limitations under the License.

On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
Set oFileSystem = CreateObject("Scripting.FileSystemObject")
Set WshNetwork = WScript.CreateObject("WScript.Network")
sTempDir = oWshEnvironment("TEMP")
Dim oExec
Dim GuiAnswer
strComputer = "."
MyName = lcase(WshNetwork.ComputerName)

Const ForAppending = 8


' clean up %TEMP% directory from .log files
oWshShell.Run "cmd.exe /C del /Q " & sTempDir & "\*.log", 0, TRUE

' open log file to record all actions taken
set objFSO = CreateObject("Scripting.FileSystemObject")
Set objTextFile = objFSO.OpenTextFile _
    (sTempDir & "\VCLprepare.log", ForAppending, True)
objTextFile.WriteLine("========================================================================")
objTextFile.WriteLine(Now & " : auto_create_image.vbs : script started")

objTextFile.WriteLine(Now & " : auto_create_image.vbs : cleaned up " & sTempDir & " directory from .log files")


' check that WAN network interface is enabled, if not - enable it
WScript.Echo "Enabling WAN interface..."
objTextFile.WriteLine(Now & " : auto_create_image.vbs : Enable WAN interface")
oWshShell.Run "cscript.exe " & sTempDir & "\vcl\enWAN.vbs", 0, TRUE
WScript.Echo "Done!"
objTextFile.WriteLine(Now & " : auto_create_image.vbs : WAN interface enabled")


' setup to run prepare_for_image.vbs script after reboot
'objTextFile.WriteLine(Now & " : auto_create_image.vbs : setup RunOnce 'auto_prepare_for_image.vbs' after reboot")
'oWshShell.RegWrite "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step0", "cmd.exe /c cscript.exe " & sTempDir & "\vcl\auto_prepare_for_image.vbs"

'check = oWshShell.RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step0")
'objTextFile.WriteLine(Now & " : CHECK (RunOnce registry entry): " & check)

' enable AutoLogon after reboot
'objTextFile.WriteLine(Now & " : auto_create_image.vbs : enable Auto-Logon after reboot")
'oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "1"
'oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DefaultUserName", "root"

'check = oWshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon")
'objTextFile.WriteLine(Now & " : CHECK (AutoAdminLogon registry entry): " & check & " (should be 1)")


' disable pagefile
objTextFile.WriteLine(Now & " : auto_create_image.vbs : disable page file")
strCommand = "reg.exe add " & Chr(34) & _
  "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" & Chr(34) &_
  " /v PagingFiles /d " & Chr(34) & "" & Chr(34) & " /t REG_MULTI_SZ /f"
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
   WScript.Sleep 100
Loop
strCommand = sTempDir & "\vcl\movefile.exe " & Chr(34) & "c:\pagefile.sys" & Chr(34) & " " & Chr(34) & Chr(34)
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
   WScript.Sleep 100
Loop


'check = oWshShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PagingFiles")
'objTextFile.WriteLine(Now & " : CHECK (PagingFiles registry entry): '" & check(0) & "' (should be empty)")


objTextFile.WriteLine(Now & " : auto_create_image.vbs : script finished, rebooting computer")
objTextFile.WriteLine("========================================================================")
'close log file handler
objTextFile.Close


'reboot computer to make changes effective

Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate,(Shutdown)}!\\" & MyName & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery _
    ("Select * from Win32_OperatingSystem")
For Each objOperatingSystem in colOperatingSystems
    intreturn = ObjOperatingSystem.Win32Shutdown(6)
    if intreturn = 0 Then
      WScript.echo "createimage reboot"
    Else
      Wscript.echo "reboot failed error code " & intreturn
    End If 
Next

WScript.Quit

