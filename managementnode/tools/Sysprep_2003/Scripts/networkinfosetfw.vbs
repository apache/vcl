
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
 
Dim objWMIService, objItem, objService
Dim colListOfServices, strComputer, strService, intSleep
Dim colNicConfigs,colNicAdapter,strDescription,strMAC
Dim strIPAddresses,strGWAddress

strComputer = "."
 
Set objWMIService = GetObject("winmgmts:" _
 & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set colNicConfigs = objWMIService.ExecQuery _
 ("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
Set colNicAdapter = objWMIService.ExecQuery _
 ("SELECT * FROM Win32_NetworkAdapter")
 
For Each objNicConfig In colNicConfigs
   strDescription = objNicConfig.Description
   strMAC = objNicConfig.MACAddress
 If InStr(strDescription, "Broadcom") Then
   strIPAddresses = ""
   If Not IsNull(objNicConfig.IPAddress) Then
      For Each strIPAddress In objNicConfig.IPAddress
          If Not strIPAddress = "" Then
               strIPAddresses = strIPAddresses & strIPAddress
          End If
      Next
   End If
   strGWAddresses = ""
   If Not IsNull(objNicConfig.DefaultIPGateway) Then
      For Each strGWAddress In objNicConfig.DefaultIPGateway
          If Not strGWAddress = "" Then
               strGWAddresses = strGWAddresses & strGWAddress
          End If
      Next
   End If


' WScript.Echo "IP Address  : " & strIPAddresses & VbCrLf & _
'              "MAC Address : " & strMAC & VbCrLf & _
'              "GW Address  : " & strGWAddresses
 For Each objNicAdapter In colNicAdapter
   If strMAC = objNicAdapter.MACAddress Then
     strNetConnectionID = objNicAdapter.NetConnectionID
     If Not strNetConnectionID = "" Then
       'WScript.Echo "Name: " & strNetConnectionID & VbCrLf
 If Left(strIPAddresses,3) = "10." Then
    INTERNAL_IP = strIPAddresses
    INTERNAL_NAME = strNetConnectionID
    INTERNAL_GW = strGWAddresses
 End If

 If Left(strIPAddresses,4) = "152." Then
    EXTERNAL_IP = strIPAddresses
    EXTERNAL_NAME = strNetConnectionID
    EXTERNAL_GW = strGWAddresses
 End If
     End If
   End If
 Next


 Else
   strIPAddresses = ""
   strGWAddresses = ""
 End If

Next



'WScript.Echo "INTERNAL_IP = " & INTERNAL_IP
'WScript.Echo "INTERNAL_NAME = " & INTERNAL_NAME
'WScript.Echo "INTERNAL_GW = " & INTERNAL_GW

'WScript.Echo "EXTERNAL_IP = " & EXTERNAL_IP
'WScript.Echo "EXTERNAL_NAME = " & EXTERNAL_NAME
'WScript.Echo "EXTERNAL_GW = " & EXTERNAL_GW

Set oWshShell = CreateObject("WScript.Shell")

Dim strCMD1,routeCMD,strCMD2,strCMD3

strCMD1 = "netsh firewall set icmpsetting type = 8 mode = enable interface = " & Chr(34) & INTERNAL_NAME & Chr(34)
'oWshShell.run "%SystemRoot%\system32\route.exe -f -p ADD 0.0.0.0 MASK 0.0.0.0 EXTERNAL_GW METRIC 2",,true
routeCMD = "route.exe -f -p ADD 0.0.0.0 MASK 0.0.0.0 " & EXTERNAL_GW & " METRIC 2"
'WScript.Echo "setting route" & routeCMD
oWshShell.run routeCMD,,true
'WScript.Echo "setting icmpsetting " & strCMD1
oWshShell.run strCMD1,,true
strCMD2 = "netsh firewall set portopening protocol = TCP port = 3389 mode = disable interface = " & Chr(34) & EXTERNAL_NAME & Chr(34)
'WScript.Echo "closing 3389 " & strCMD2
oWshShell.run strCMD2,,true
strCMD3 = "netsh firewall set portopening protocol = TCP port = 22 name = SSHD mode = enable interface = " & Chr(34) & INTERNAL_NAME & Chr(34)
'WScript.Echo "opening 22 " & strCMD3
oWshShell.run strCMD3,,true

objWMIService=""
' update syslog - stop and restart service

strComputer = "."
intSleep = 1500

'On Error Resume Next
' NB strService is case sensitive.
strService = " 'ntsyslog' "
Set objWMIService = GetObject("winmgmts:" _
& "{impersonationLevel=impersonate}!\\" _
& strComputer & "\root\cimv2")
Set colListOfServices = objWMIService.ExecQuery _
("Select * from Win32_Service Where Name ="_
& strService & " ")
For Each objService in colListOfServices
objService.StopService()
WSCript.Sleep intSleep
oWshShell.run """reg add HKLM\SOFTWARE\SaberNet /v syslog /d INTERNAL_GW /f""",,true
objService.StartService()
Next
'WScript.Echo "Your "& strService & " service has Started"
WScript.Quit
