On Error Resume Next
Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
sCurrentName = oWshEnvironment("COMPUTERNAME")
Const ForAppending = 8
Dim oExec
MYNAME=lcase(sCurrentName)
check = ""

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate,(Shutdown)}!\\" & _ 
      strComputer & "\root\cimv2")
Set colOperatingSystems = objWMIService.ExecQuery _
    ("Select * from Win32_OperatingSystem")
for Each objOperatingSystem in colOperatingSystems
    intret = ObjOperatingSystem.Reboot()
    If intret = 0 Then
         Wscript.echo "Computer rebooted"
    Else
         Wscript.echo "reboot failed error code " & intret
    End If
Next

Set ObjOperatingSystem = Nothing
Set colOperatingSystems = Nothing
Set objWMIService = Nothing
WScript.Quit
