On Error Resume Next

Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
Set oFileSystem = CreateObject("Scripting.FileSystemObject")
sTempDir = oWshEnvironment("TEMP")
Dim oExec
Dim GuiAnswer
strComputer = "."

oFileSystem.CopyFile "C:\Documents and Settings/root/Application Data\VCL\VCLprepare.cmd", "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\",true

WScript.Echo "copied VCLrcboot"

'delete
Set aFile = oFileSystem.GetFile("C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCLcleanup.cmd")
aFile.Delete
WScript.Echo "Deleted VCLcleanup.cmd"

'start sysprep
oWshShell.run "C:\Sysprep\sysprep.exe -quiet -forceshutdown -reseal -mini -activated", 1, false
WScript.Echo "Executed sysprep.exe"

Set oWshShell = Nothing
WScript.Quit
