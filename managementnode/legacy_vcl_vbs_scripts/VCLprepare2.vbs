Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
sCurrentName = oWshEnvironment("COMPUTERNAME")
sTempDir = oWshEnvironment("TEMP")
'WScript.Echo "COMPUTERNAME = " & sCurrentName
'WScript.Echo "Temp directory = " & sTempDir
On Error Resume Next
Dim oExec
Const ForAppending = 8
check = ""

strComputer = "."
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")

' open log file to record all actions taken
set objFSO = CreateObject("Scripting.FileSystemObject")
Set objTextFile = objFSO.OpenTextFile _
    (sTempDir & "\VCLprepare.log", ForAppending, True)
objTextFile.WriteLine("========================================================================")
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : script started")

WScript.Echo "#### This is VCLprepare2.vbs script ####"
WScript.Echo "Waiting for NTsyslog service..."
' Wait until NTsyslog service started
started = 0
Do While started = 0
   Set colRunningServices = objWMIService.ExecQuery ("Select * from Win32_Service")
   For Each objService in colRunningServices 
      If (objService.DisplayName = "NTsyslog") AND (objService.State = "Running") Then
         started = 1
      End If
   Next
   WScript.Sleep 100
Loop
WScript.Sleep 5000
WScript.Echo "NTsyslog service is up."
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : NTsyslog service is up")

' Write what happening along the way to Setup Event Log
strCommand = "eventcreate /T Information /ID 108 /L Setup /SO " & Chr(34) & "VCLprepare2.vbs" & _
             Chr(34) & " /D " & Chr(34) & "VCLprepare2.vbs script started." & Chr(34)
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop
 
' execute one more time to insure it goes to right EventLog
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop

 
' create new "passwd" and "group" files for cygwin, because SID was changed by step1-rename.vbs script
WScript.Echo "Creating new group and passwd files for cygwin..."
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : Create new group and passwd files for cygwin")
oWshShell.Run "cmd.exe /C del " & "c:\cygwin\etc\group", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C del " & "c:\cygwin\etc\passwd", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\mkgroup.exe -l" & " > c:\cygwin\etc\group", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\mkpasswd.exe -l" & " > c:\cygwin\etc\passwd", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "C:\WINDOWS\system32\sc.exe start NSClient", 0, TRUE
WScript.Sleep 1000
WScript.Echo "Done!"

strCommand = "eventcreate /T Information /ID 109 /L Setup /SO " & Chr(34) & "VCLprepare2.vbs" & Chr(34) & _
              " /D " & Chr(34) & "passwd and group files for cygwin were created successfully." & Chr(34)
' Record result in Setup Event Log
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : passwd and group files for cygwin were created successfully")

' Turn off auto-login
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : disable Auto-Logon")
oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "0"

check = oWshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon")

objTextFile.WriteLine(Now & " : CHECK (AutoAdminLogon registry entry): " & check & " (should be 0)")

' Do quick format of volume D:
Set oExec = oWshShell.Exec("cmd.exe /C echo y | C:\WINDOWS\system32\format.com D: /FS:NTFS /V:Storage /Q ")
Do While oExec.Status = 0
     WScript.Sleep 100
Loop

' if D: drive was NTFS volume before - then just delete everything from it
Set oExec = oWshShell.Exec("rm -rf D:/* ")
Do While oExec.Status = 0
     WScript.Sleep 100
Loop

strCommand = "eventcreate /T Information /ID 110 /L Setup /SO " & Chr(34) & "VCLprepare2.vbs" & _
             Chr(34) & " /D " & Chr(34) & "VCLprepare2.vbs script finished." & Chr(34)
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : script finished")

'MYNAME=lcase(sCurrentName)

'strCommand = "eventcreate /T Information /ID 111 /L Setup /SO " & Chr(34) & "VCLprepare2.vbs" & _
'             Chr(34) & " /D " & Chr(34) & MYNAME & " is READY." & Chr(34)
strCommand = "eventcreate /T Information /ID 111 /L Setup /SO " & Chr(34) & "VCLprepare2.vbs" & _
             Chr(34) & " /D " & Chr(34) & lcase(sCurrentName) & " is READY." & Chr(34)
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop
objTextFile.WriteLine(Now & " : VCLprepare2.vbs : " & lcase(sCurrentName) & " is READY.")
objTextFile.WriteLine("========================================================================")
'close log file handler
objTextFile.Close
 
' Just log-off
oWshShell.Exec("C:\WINDOWS\system32\logoff.exe")

WScript.Quit
