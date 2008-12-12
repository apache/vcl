On Error Resume Next
Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
sCurrentName = oWshEnvironment("COMPUTERNAME")
sTempDir = oWshEnvironment("TEMP")
'WScript.Echo "COMPUTERNAME = " & sCurrentName
'WScript.Echo "Temp directory = " & sTempDir
Dim MACLASTNUMDEC
Dim MACLASTNUMHEX
Dim oExec
Const ForWriting = 2
Const ForAppending = 8
check = ""

strComputer = "."
Set objWMIService = GetObject("winmgmts:\\"& strComputer & "\root\cimv2")

' open log file to record all actions taken
set objFSO = CreateObject("Scripting.FileSystemObject")
Set objTextFile = objFSO.OpenTextFile _
    (sTempDir & "\VCLprepare.log", ForAppending, True)
objTextFile.WriteLine("========================================================================")
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : script started")



WScript.Echo "#### This is VCLprepare1.vbs script ####"
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
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : NTsyslog service is up")

' Write what happening along the way to Setup Event Log
strCommand = "eventcreate /T Information /ID 101 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
             Chr(34) & " /D " & Chr(34) & "VCLprepare1.vbs script started." & Chr(34)
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop

' execute one more time to insure it goes to right EventLog
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
     WScript.Sleep 100
Loop 
 
Set colAdapters = objWMIService.ExecQuery _
    ("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")

' wait until both network adapters are available
WScript.Echo "Waiting on network adapters:"
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Waiting on network adapters:")

num_adapters = 0
currIndex1 = ""
currIndex2 = ""
n = 5

Do While num_adapters < 2
  Set colItems = objWMIService.ExecQuery("Select * from Win32_NetworkAdapter",,48)
  For Each objItem in colItems
    If Not IsNull(objItem.Index) AND Not IsNull(objItem.MACAddress) AND Not IsNull(objItem.NetConnectionID) Then
'       WScript.Echo "Index = " & objItem.Index
'       WScript.Echo "MACAddress = " & objItem.MACAddress
'       WScript.Echo "NetConnectionID = " & objItem.NetConnectionID
       If Not currIndex1 = objItem.Index Then
         If currIndex1 = "" Then
           currIndex1 = objItem.Index
'           WScript.Echo "currIndex1 = '" & objItem.Index & "'"
           num_adapters = num_adapters + 1
         Else
           currIndex2 = objItem.Index
'           WScript.Echo "currIndex2 = '" & objItem.Index & "'"
           num_adapters = num_adapters + 1
         End If
       End If
    End If
  Next
  If num_adapters < 2 Then
    WScript.Sleep 5000
    WScript.Echo n & "sec"
    n = n + 5
  End If
Loop

WScript.Echo "num_adapters = " & num_adapters
'WScript.Echo "currIndex1 = '" & currIndex1 & "'"
'WScript.Echo "currIndex2 = '" & currIndex2 & "'"
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : num_adapters = " & num_adapters & " (should be 2)")

' determine names for network adapters based on their MAC addresses:
' adapter with even MAC will be FirstAdapter - LAN interface
' adapter with odd MAC will be SecondAdapter - WAN interface

Set colAdapters = objWMIService.ExecQuery _
    ("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
For Each objAdapter in colAdapters
   If objAdapter.Index = currIndex1 OR objAdapter.Index = currIndex2 Then
'     WScript.Echo "Index = " & objAdapter.Index
     AdapterMAC = objAdapter.MACAddress
'     WScript.Echo "MAC = " & AdapterMAC
     MACArray = Split(AdapterMAC, ":")
     MACLASTNUMHEX = Trim(MACArray(5))
'     WScript.Echo "Last MAC number (HEX) = " & MACLASTNUMHEX
     MACLASTNUMDEC = CInt("&H" & MACLASTNUMHEX)
'     WScript.Echo "Last MAC number (DEC) = " & MACLASTNUMDEC
     reminder = MACLASTNUMDEC Mod 2
'     WScript.Echo "Reminder of last MAC number = " & reminder
     If reminder = 0 Then
       FirstAdapterIndex = objAdapter.Index
       If Not IsNull(objAdapter.IPAddress) Then
         For i = 0 To UBound(objAdapter.IPAddress)
           FirstAdapterIP = objAdapter.IPAddress(i)
         Next
       End If
     Else
       SecondAdapterIndex = objAdapter.Index
       If Not IsNull(objAdapter.IPAddress) Then
         For i = 0 To UBound(objAdapter.IPAddress)
           SecondAdapterIP = objAdapter.IPAddress(i)
         Next
       End If
     End If
'     WScript.Echo "============================" 
   End If
Next

Set colItems = objWMIService.ExecQuery("Select * from Win32_NetworkAdapter",,48)
For Each objItem in colItems
  If objItem.Index = FirstAdapterIndex Then
    FirstAdapterName = objItem.NetConnectionID
  End If
  If objItem.Index = SecondAdapterIndex Then
    SecondAdapterName = objItem.NetConnectionID
  End If

Next
WScript.Echo "First Adapter Name  (LAN): " & FirstAdapterName
WScript.Echo "First Adapter Index (LAN): " & FirstAdapterIndex
WScript.Echo "First Adapter IP    (LAN): " & FirstAdapterIP
WScript.Echo "Second Adapter Name  (WAN): " & SecondAdapterName
WScript.Echo "Second Adapter Index (WAN): " & SecondAdapterIndex
WScript.Echo "Second Adapter IP    (WAN): " & SecondAdapterIP
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : First Adapter Name  (LAN): " & FirstAdapterName)
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : First Adapter Index (LAN): " & FirstAdapterIndex)
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : First Adapter IP    (LAN): " & FirstAdapterIP)
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Second Adapter Name  (WAN): " & SecondAdapterName)
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Second Adapter Index (WAN): " & SecondAdapterIndex)
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Second Adapter IP    (WAN): " & SecondAdapterIP)

' Write Second Adapter Name (WAN) to file in %TEMP% directory
set objFSO1 = CreateObject("Scripting.FileSystemObject")
Set objTextFile1 = objFSO1.OpenTextFile _
    (sTempDir & "\WANname.txt", ForWriting, True)
objTextFile1.WriteLine(SecondAdapterName)
objTextFile1.Close


' Assign new IP address to "WAN" adapter

IPArray = Split(FirstAdapterIP, ".")
MYWANIP = Array("152.1.14." & IPArray(3))
WScript.Echo "MYWANIP = " & MYWANIP(0)
MYWANSubnetMask = Array("255.255.255.0")
MYWANGateway = Array("152.1.14.1")
MYWANGatewayMetric = Array(1)

' Setup static IP address for "WAN" adapter

Set colNetAdapters = objWMIService.ExecQuery _
    ("Select * from Win32_NetworkAdapterConfiguration where IPEnabled=TRUE")

For Each objNetAdapter in colNetAdapters
 If objNetAdapter.Index = SecondAdapterIndex Then
    errEnable = objNetAdapter.EnableStatic(MYWANIP, MYWANSubnetMask)
    errGateways = objNetAdapter.SetGateways(MYWANGateway, MYWANGatewaymetric)
    arrDNSServers = Array("152.1.1.161", "152.1.1.248")
    errDNS = objNetAdapter.SetDNSServerSearchOrder(arrDNSServers)

    If errEnable = 0 Then
       WScript.Echo "The IP address has been changed."
       objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WAN interface was configured successfully.")
       strCommand = "eventcreate /T Information /ID 102 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                    Chr(34) & " /D " & Chr(34) & "WAN interface was configured successfully." & Chr(34)
    Else
       WScript.Echo "The IP address could not be changed."
       WScript.Echo "Error = " & errEnable
       objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WAN interface could not be configured. Error: " & errEnable)
       strCommand = "eventcreate /T Error /ID 103 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                    Chr(34) & " /D " & Chr(34) & "WAN interface could not be configured. Error: " & errEnable & Chr(34)
    End If
 ' Record result in Setup Event Log
    Set oExec = oWshShell.Exec(strcommand)
    Do While oExec.Status = 0
       WScript.Sleep 100
    Loop
 
 End If
Next
WScript.Sleep 1000

' turn back on pagefile
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : enable page file")
strCommand = "reg.exe add " & Chr(34) & _
  "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" & Chr(34) &_
  " /v PagingFiles /d " & Chr(34) & "c:\pagefile.sys 2046 4092" & Chr(34) & " /t REG_MULTI_SZ /f"
Set oExec = oWshShell.Exec(strcommand)
Do While oExec.Status = 0
   WScript.Sleep 100
Loop
check = oWshShell.RegRead("HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PagingFiles")

objTextFile.WriteLine(Now & " : CHECK (PagingFiles registry entry): '" & check(0) & "' (should be ... 2046 4092)")


' to insure proper rename procedure disable WAN interface (adapter with odd MAC address)
WScript.Echo "Disabling WAN interface..."
oWshShell.Run "cscript.exe " & sTempDir & "\vcl\disWAN.vbs", 0, TRUE
WScript.Echo "Done!"

WScript.Echo "Renaming computer... "
objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Renaming computer using WSName.exe")

Set oExec = oWshShell.Exec(sTempDir & "\vcl\WSName.exe /N:%DNS /MCN /NOREBOOT")
Do While oExec.Status = 0
     WScript.Sleep 100
Loop

If oExec.ExitCode <> 0 Then
' Could not rename computer - better stop here
' it could be not bad - simply old and new names match or
' it could be bad - something else went wrong
   WScript.Echo "Warning: Non-zero exit code"
   objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WSName.exe : non-zero exit code")

   If oExec.ExitCode = 7 Then
     WScript.Echo "Computer's new and old names match! Rename aborted!"
     strCommand = "eventcreate /T Warning /ID 105 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                Chr(34) & " /D " & Chr(34) & "Computer's name doesn't need to be changed." & Chr(34)
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WSName.exe : new and old names match. Rename aborted.")
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Most likely it's the same computer after creating image")
' ' Turn off auto-login
'     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : disable Auto-Logon")
'     oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon", "0"

'     check = oWshShell.RegRead("HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoAdminLogon")

'     objTextFile.WriteLine(Now & " : CHECK (AutoAdminLogon registry entry): " & check & " (should be 0)")
 ' Record result in Setup Event Log
     Set oExec = oWshShell.Exec(strcommand)
     Do While oExec.Status = 0
       WScript.Sleep 100
     Loop

 ' Setup to run finish.vbs script after reboot
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : setup RunOnce 'finish.vbs' after reboot")

     oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step2", "cmd.exe /c cscript.exe " & sTempDir & "\vcl\finish.vbs"

     WScript.Sleep 1000

     check = oWshShell.RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step2")

     objTextFile.WriteLine(Now & " : CHECK (RunOnce registry entry): " & check)

     strCommand = "eventcreate /T Information /ID 107 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                Chr(34) & " /D " & Chr(34) & "VCLprepare1.vbs script finished." & Chr(34)
     Set oExec = oWshShell.Exec(strcommand)
     Do While oExec.Status = 0
       WScript.Sleep 100
     Loop
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : script finished")
     objTextFile.WriteLine("========================================================================")
 'close log file handler
     objTextFile.Close

 'reboot computer to activate page file

     Set objWMIService = GetObject("winmgmts:" _
        & "{impersonationLevel=impersonate,(Shutdown)}!\\" & strComputer & "\root\cimv2")
     Set colOperatingSystems = objWMIService.ExecQuery _
        ("Select * from Win32_OperatingSystem")
     For Each objOperatingSystem in colOperatingSystems
        ObjOperatingSystem.Reboot()
     Next

     WScript.Quit

'     strCommand = "eventcreate /T Information /ID 111 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
'             Chr(34) & " /D " & Chr(34) & lcase(sCurrentName) & " is READY." & Chr(34)
'     Set oExec = oWshShell.Exec(strcommand)
'     Do While oExec.Status = 0
'       WScript.Sleep 100
'     Loop
'     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : " & lcase(sCurrentName) & " is READY.")
'     objTextFile.WriteLine("========================================================================")

   Else
     WScript.Echo "Something went wrong while renaming computer!"
     WScript.Echo "Exit code: " & oExec.ExitCode
     WScript.Echo "Check WSName.log in %TEMP% directory for details."
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WSName.exe : something went wrong while renaming computer.")
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WSName.exe : Exit code: " & oExec.ExitCode)
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : WSName.exe : Check WSName.log in %TEMP% directory for details.")
     strCommand = "eventcreate /T Error /ID 106 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & Chr(34) & _
                " /D " & Chr(34) & "Computer's name could not be changed. WSName.exe Exit code: " & _
                oExec.ExitCode & " Check WSName.log in %TEMP% directory for details." & Chr(34)
 ' Record result in Setup Event Log
     Set oExec = oWshShell.Exec(strcommand)
     Do While oExec.Status = 0
       WScript.Sleep 100
     Loop

     strCommand = "eventcreate /T Information /ID 107 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                Chr(34) & " /D " & Chr(34) & "VCLprepare1.vbs script finished." & Chr(34)
     Set oExec = oWshShell.Exec(strcommand)
     Do While oExec.Status = 0
       WScript.Sleep 100
     Loop
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : script finished")
     strCommand = "eventcreate /T Error /ID 111 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
             Chr(34) & " /D " & Chr(34) & lcase(sCurrentName) & " : rename ERROR." & Chr(34)
     Set oExec = oWshShell.Exec(strcommand)
     Do While oExec.Status = 0
       WScript.Sleep 100
     Loop
     objTextFile.WriteLine(Now & " : VCLprepare1.vbs : " & lcase(sCurrentName) & " : rename ERROR.")
     objTextFile.WriteLine("========================================================================")
   End If

 'close log file handler
   objTextFile.Close

  ' log-off
   oWshShell.Run "cmd.exe /C " & "C:\WINDOWS\system32\logoff.exe ", 0, TRUE
   WScript.Quit

Else
' computer renamed OK - continue with remaining steps
   strCommand = "eventcreate /T Information /ID 104 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                Chr(34) & " /D " & Chr(34) & "Computer's name changed successfully." & Chr(34)
 ' Record result in Setup Event Log
   Set oExec = oWshShell.Exec(strcommand)
   Do While oExec.Status = 0
     WScript.Sleep 100
   Loop
   WScript.Echo "Computer's name changed successfully!"
   objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Computer's name changed successfully")


 ' Setup to run step2-setup.vbs script after reboot
   objTextFile.WriteLine(Now & " : VCLprepare1.vbs : setup RunOnce 'VCLprepare2.vbs' after reboot")

   oWshShell.RegWrite "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step2", "cmd.exe /c cscript.exe " & sTempDir & "\vcl\VCLprepare2.vbs"

   WScript.Sleep 1000

   check = oWshShell.RegRead("HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\step2")

   objTextFile.WriteLine(Now & " : CHECK (RunOnce registry entry): " & check)


 ' Assign new unique SID
   WScript.Echo "Assigning new SID... "
   objTextFile.WriteLine(Now & " : VCLprepare1.vbs : Assigning new SID using newsid.exe")
   Set oExec = oWshShell.Exec(sTempDir & "\vcl\newsid.exe /a /d 5")
   Do While oExec.Status = 0
     WScript.Sleep 100
   Loop
   objTextFile.WriteLine(Now & " : VCLprepare1.vbs : script finished, rebooting computer")
   objTextFile.WriteLine("========================================================================")
 'close log file handler
   objTextFile.Close

   strCommand = "eventcreate /T Information /ID 107 /L Setup /SO " & Chr(34) & "VCLprepare1.vbs" & _
                Chr(34) & " /D " & Chr(34) & "VCLprepare1.vbs script finished." & Chr(34)
   Set oExec = oWshShell.Exec(strcommand)
   Do While oExec.Status = 0
     WScript.Sleep 100
   Loop
   WScript.Echo "Done!"
End If

WScript.Quit

