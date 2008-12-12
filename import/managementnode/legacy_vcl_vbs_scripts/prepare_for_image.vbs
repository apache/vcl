On Error Resume Next
Set oWshShell = CreateObject("WScript.Shell")

Set oWshEnvironment = oWshShell.Environment("Process")

sCurrentName = oWshEnvironment("COMPUTERNAME")
sTempDir = oWshEnvironment("TEMP")
Const ForAppending = 8
Dim oExec
MYNAME=lcase(sCurrentName)
check = ""

' open log file to record all actions taken
set objFSO = CreateObject("Scripting.FileSystemObject")
Set objTextFile = objFSO.OpenTextFile _
    (sTempDir & "\VCLprepare.log", ForAppending, True)
objTextFile.WriteLine("========================================================================")
objTextFile.WriteLine(Now & " : prepare_for_image.vbs : script started")


' setup to run VCLprepare.vbs script after reboot
objTextFile.WriteLine(Now & " : prepare_for_image.vbs : setup RunOnce 'VCLprepare1.vbs' after reboot")
oWshShell.RegWrite "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step1", "cmd.exe /c cscript.exe " & sTempDir & "\vcl\VCLprepare1.vbs"


check = oWshShell.RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step1")

objTextFile.WriteLine(Now & " : CHECK (RunOnce registry entry): " & check)

' enable AutoLogon after reboot
objTextFile.WriteLine(Now & " : create_image.vbs : enable Auto-Logon after reboot")
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "1"


check = oWshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon")

objTextFile.WriteLine(Now & " : CHECK (AutoAdminLogon registry entry): " & check & " (should be 1)")


'Clear up default Event Logs
strComputer = "."
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
        strComputer & "\root\cimv2")
Set colLogFiles = objWMIService.ExecQuery("Select * from Win32_NTEventLogFile")
For Each objLogfile in colLogFiles
    objLogFile.ClearEventLog()
Next


' ask to setup "image" mode for computer on management node
objTextFile.WriteLine(Now & " : prepare_for_image.vbs : setup 'image' mode for computer on management node")

WScript.StdOut.WriteLine "######################################"
'WScript.StdOut.WriteLine "### Setup 'image' mode for vlca1-5 ###"
WScript.StdOut.WriteLine "### Setup 'image' mode for " & MYNAME & " ###"
WScript.StdOut.WriteLine "### on management node             ###"
WScript.StdOut.WriteLine "###     Is it ready?  (y or n)     ###"
WScript.StdOut.WriteLine "######################################"
answer = WScript.StdIn.ReadLine

If Not answer = "y" Then
   objTextFile.WriteLine(Now & " : prepare_for_image.vbs : script aborted by user request")
   objTextFile.WriteLine("========================================================================")
   WScript.Quit
End If


objTextFile.WriteLine(Now & " : prepare_for_image.vbs : script finished, rebooting computer")
objTextFile.WriteLine("========================================================================")
'close log file handler
objTextFile.Close

'reboot computer to make changes effective

Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate,(Shutdown)}!\\" & strComputer & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery _
    ("Select * from Win32_OperatingSystem")
For Each objOperatingSystem in colOperatingSystems
    ObjOperatingSystem.Reboot()
Next

WScript.Quit

