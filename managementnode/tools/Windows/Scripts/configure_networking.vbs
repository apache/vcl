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

Set objShell = CreateObject("WScript.Shell")

WScript.Echo (WScript.ScriptName & " beginning to run: " & Date & " " & Time)

strSystem32="%SystemRoot%\system32"

' Get the Windows version
' This allows the same script to be used for different versions
' Some commands such as setting the firewall differ between versions
Set objWMIService = GetObject("winmgmts:\\.\root\CIMV2")
Set colItems = objWMIService.ExecQuery("SELECT Version FROM Win32_OperatingSystem")
For Each objItem In colItems
	strWindowsVersion = objItem.Version
Next
WScript.Echo "Windows Version: " & strWindowsVersion

'----------------------------------------------------------------------------
' Print the routing table before making any changes
' This is done for troubleshooting purposes
CMD_ROUTE_PRINT=strSystem32 & "\route.exe print"
RunCommand CMD_ROUTE_PRINT, "Printing routing table"

' Renew the DHCP lease to make sure not to retrieve old information
CMD_IPCONFIG_ALL=strSystem32 & "\ipconfig.exe /all"
CMD_IPCONFIG_RELEASE=strSystem32 & "\ipconfig.exe /release"
CMD_IPCONFIG_RENEW=strSystem32 & "\ipconfig.exe /renew"

'RunCommand CMD_IPCONFIG_RELEASE, "Releasing DHCP lease"
'RunCommand CMD_IPCONFIG_RENEW, "Renewing DHCP lease"
RunCommand CMD_IPCONFIG_ALL, "Running ipconfig /all"


'----------------------------------------------------------------------------
' Get the networking configuration
Dim PRIVATE_NAME, PRIVATE_IP, PRIVATE_SUBNET_MASK, PRIVATE_GATEWAY
Dim PUBLIC_NAME, PUBLIC_IP, PUBLIC_SUBNET_MASK, PUBLIC_GATEWAY
get_network_configuration

print_hr

WScript.Echo "PRIVATE_NAME          = " & PRIVATE_NAME
WScript.Echo "PRIVATE_IP            = " & PRIVATE_IP
WScript.Echo "PRIVATE_SUBNET_MASK   = " & PRIVATE_SUBNET_MASK
WScript.Echo "PRIVATE_GATEWAY       = " & PRIVATE_GATEWAY
WScript.Echo
WScript.Echo "PUBLIC_NAME           = " & PUBLIC_NAME
WScript.Echo "PUBLIC_IP             = " & PUBLIC_IP
WScript.Echo "PUBLIC_SUBNET_MASK    = " & PUBLIC_SUBNET_MASK
WScript.Echo "PUBLIC_GATEWAY        = " & PUBLIC_GATEWAY
WScript.Echo

' Check if all the required information was found
If (Len(PRIVATE_NAME) > 0) And (Len(PRIVATE_IP) > 0) _
   And (Len(PUBLIC_NAME) > 0) And (Len(PUBLIC_IP) > 0) And (Len(PUBLIC_GATEWAY) > 0) _
Then
	WScript.Echo "Successfully retrieved private and public network configuration"
Else
	WScript.Echo "Failed to retrieve private and public network configuration, returning exit status 1"
	WScript.Quit 1
End If

'' Set system environment variables
'Set objShell = CreateObject("WScript.Shell")
'Set sysvars = objShell.Environment("SYSTEM")
'sysvars("VCL_PRIVATE_NAME")    = PRIVATE_NAME
'sysvars("VCL_PRIVATE_IP")      = PRIVATE_IP
'sysvars("VCL_PRIVATE_MASK")    = PRIVATE_SUBNET_MASK
'sysvars("VCL_PRIVATE_GATEWAY") = PRIVATE_GATEWAY
'sysvars("VCL_PUBLIC_NAME")     = PUBLIC_NAME
'sysvars("VCL_PUBLIC_IP")       = PUBLIC_IP
'sysvars("VCL_PUBLIC_MASK")       = PUBLIC_SUBNET_MASK
'sysvars("VCL_PUBLIC_GATEWAY")  = PUBLIC_GATEWAY
'
'WScript.Echo
'
'WScript.Echo "Set environment variables:"
'Set sysvars = objShell.Environment("SYSTEM")
'WScript.Echo "VCL_PRIVATE_NAME: " & sysvars("VCL_PRIVATE_NAME")
'WScript.Echo "VCL_PRIVATE_IP: " & sysvars("VCL_PRIVATE_IP")
'WScript.Echo "VCL_PRIVATE_MASK: " & sysvars("VCL_PRIVATE_MASK")
'WScript.Echo "VCL_PRIVATE_GATEWAY: " & sysvars("VCL_PRIVATE_GATEWAY")
'WScript.Echo
'WScript.Echo "VCL_PUBLIC_NAME: " & sysvars("VCL_PUBLIC_NAME")
'WScript.Echo "VCL_PUBLIC_IP: " & sysvars("VCL_PUBLIC_IP")
'WScript.Echo "VCL_PUBLIC_MASK: " & sysvars("VCL_PUBLIC_MASK")
'WScript.Echo "VCL_PUBLIC_GATEWAY: " & sysvars("VCL_PUBLIC_GATEWAY")

'----------------------------------------------------------------------------
' Assemble the external commands

CMD_ROUTE_ADD_PUBLIC_GATEWAY=strSystem32 & "\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 " & PUBLIC_GATEWAY & " METRIC 1"
CMD_ROUTE_ADD_PRIVATE_GATEWAY=strSystem32 & "\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 " & PRIVATE_GATEWAY & " METRIC 2"
CMD_ROUTE_DELETE_GATEWAYS=strSystem32 & "\route.exe DELETE 0.0.0.0 MASK 0.0.0.0 "
CMD_ROUTE_FLUSH=strSystem32 & "\route.exe -f"

CMD_SET_NTSYSLOG_GATEWAY=strSystem32 & "\reg.exe ADD HKLM\SOFTWARE\SaberNet /v syslog /d " & PRIVATE_GATEWAY & " /f"
CMD_START_NTSYSLOG_SERVICE=strSystem32 & "\net.exe start ntsyslog"
CMD_STOP_NTSYSLOG_SERVICE=strSystem32 & "\net.exe stop ntsyslog"

CMD_SET_PRIVATE_STATIC=strSystem32 & "\netsh.exe interface ip set address name=""" & PRIVATE_NAME & """ source=static addr=" & PRIVATE_IP & " mask=" & PRIVATE_SUBNET_MASK & " gateway=none"

CMD_SET_PUBLIC_DNS=strSystem32 & "\netsh.exe interface ip set dns name=""" & PUBLIC_NAME & """ source=dhcp register=none"
CMD_SET_PRIVATE_DNS=strSystem32 & "\netsh.exe interface ip set dns name=""" & PRIVATE_NAME & """ source=dhcp register=none"

CMD_SET_PUBLIC_NAME=strSystem32 & "\netsh.exe interface set interface name=""" & PUBLIC_NAME & """ newname=""Public Interface"""
CMD_SET_PRIVATE_NAME=strSystem32 & "\netsh.exe interface set interface name=""" & PRIVATE_NAME & """ newname=""Private Interface"""

CMD_FIREWALL_ALLOW_PRIVATE_PING=strSystem32 & "\netsh.exe firewall set icmpsetting" & _
" type = 8" & _
" mode = ENABLE" & _
" interface = """ & PRIVATE_NAME & """"

CMD_FIREWALL_ALLOW_PRIVATE_SSH=strSystem32 & "\netsh.exe firewall set portopening" & _
" protocol = TCP" & _
" port = 22" & _
" mode = ENABLE" & _
" name = ""SSHD""" & _
" interface = """ & PRIVATE_NAME & """"

CMD_FIREWALL_ALLOW_PRIVATE_RDP=strSystem32 & "\netsh.exe firewall set portopening" & _
" protocol = TCP" & _
" port = 3389" & _
" mode = ENABLE" & _
" name = ""Remote Desktop""" & _
" interface = """ & PRIVATE_NAME & """"

CMD_ADVFIREWALL_ALLOW_PRIVATE_PING=strSystem32 & "\netsh.exe advfirewall firewall set rule" & _
" name=""VCL: allow ping from private network""" & _
" new" & _
" action=allow" & _
" description=""Allows incoming ping (ICMP type 8) messages from 10.x.x.x addresses""" & _
" dir=in" & _
" enable=yes" & _
" localip=10.0.0.0/8" & _
" protocol=icmpv4:8,any" & _
" remoteip=10.0.0.0/8"

CMD_ADVFIREWALL_ALLOW_PRIVATE_SSH=strSystem32 & "\netsh.exe advfirewall firewall set rule" & _
" name=""VCL: allow SSH port 22 from private network""" & _
" new" & _
" action=allow" & _
" description=""Allows incoming TCP port 22 traffic from 10.x.x.x addresses""" & _
" dir=in" & _
" enable=yes" & _
" localip=10.0.0.0/8" & _
" localport=22" & _
" protocol=TCP" & _
" remoteip=10.0.0.0/8"

CMD_ADVFIREWALL_ALLOW_PRIVATE_RDP=strSystem32 & "\netsh.exe advfirewall firewall set rule" & _
" name=""VCL: allow RDP port 3389 from private network""" & _
" new" & _
" action=allow" & _
" description=""Allows incoming TCP port 3389 traffic from 10.x.x.x addresses""" & _
" dir=in" & _
" enable=yes" & _
" localip=10.0.0.0/8" & _
" localport=3389" & _
" protocol=TCP" & _
" remoteip=10.0.0.0/8"

'----------------------------------------------------------------------------
' Run commands to configure networking
' Keep a total of the exit codes
intExitStatusTotal = 0

' Set the adapters to not register DNS records
intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_SET_PUBLIC_DNS, "Setting the public adapter to not register DNS records")
intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_SET_PRIVATE_DNS, "Setting the private adapter to not register DNS records")

'' Set the private adapter to static and remove the default gateway
'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_SET_PRIVATE_STATIC, "Setting the private adapter to static")

' Configure the routing table default gateways
intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ROUTE_DELETE_GATEWAYS, "Deleting routes to default gateways")
intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ROUTE_ADD_PUBLIC_GATEWAY, "Adding route to public default gateway")
'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ROUTE_ADD_PRIVATE_GATEWAY, "Adding route to private default gateway")

'' Configure the ntsyslog service to use the address of the private default gateway (management node)
'RunCommand CMD_STOP_NTSYSLOG_SERVICE, "Stopping the ntsyslog service"
'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_SET_NTSYSLOG_GATEWAY, "Configuring ntsyslog to use private default gateway")
'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_START_NTSYSLOG_SERVICE, "STARTING the ntsyslog service")

' Configure the firewall to allow ping, RDP and SSH on the private network
'print_hr

'If (Left(strWindowsVersion, 1) < 6) Then
'	WScript.Echo "Windows version is " & strWindowsVersion & ", configuring firewall with netsh firewall"
'	intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_FIREWALL_ALLOW_PRIVATE_PING, "Allowing ping on the private interface")
'	intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_FIREWALL_ALLOW_PRIVATE_SSH, "Allowing SSH on the private interface")
'	'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_FIREWALL_ALLOW_PRIVATE_RDP, "Allowing RDP on the private interface")
'Else
'   WScript.Echo "Windows version is " & strWindowsVersion & ", configuring firewall with netsh advfirewall"
'	intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ADVFIREWALL_ALLOW_PRIVATE_PING, "Allowing ping from private addresses")
'	intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ADVFIREWALL_ALLOW_PRIVATE_SSH, "Allowing SSH from private addresses")
'	'intExitStatusTotal = intExitStatusTotal + RunCommand(CMD_ADVFIREWALL_ALLOW_PRIVATE_RDP, "Allowing RDP from private addresses")
'End If

'' Set the names of the adapters to Public and Private
'RunCommand CMD_SET_PRIVATE_NAME, "Setting the private adapter name to Private"
'RunCommand CMD_SET_PUBLIC_NAME, "Setting the public adapter name to Public"

' Print the routing table
RunCommand CMD_ROUTE_PRINT, "Printing routing table"

' Run ipconfig /all
RunCommand CMD_IPCONFIG_ALL, "Running ipconfig /all"

print_hr

WScript.Echo (WScript.ScriptName & " finished: " & Date & " " & Time)
WScript.Echo "Exit status total: " & intExitStatusTotal
WScript.Quit intExitStatusTotal

'-----------------------------------------------------------------------------
function get_network_configuration
	' Connect to local computer via WMI
	Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

	' Get a list of network adapters
	' NetConnectionStatus: 0 = Disconnected, 1 = Connecting, 2 = Connected
	Set wmi_NAs = wmi.ExecQuery("SELECT * FROM Win32_NetworkAdapter WHERE " & _
											"NetConnectionStatus = 2 " & _
											"AND NOT ServiceName LIKE '%loop%'")

	' Loop through neteork adapters
	If (wmi_NAs.count = 0) Then
		WScript.Echo "No network adapters were found"
		WScript.Quit 1
	End If
	
	' Regular expression to ignore certain network connection names
	strPatternIgnoredAdapterNames = "(loopback|vmnet|afs)"
	
	' Regular expression to ignore certain network connection descriptions
	strPatternIgnoredAdapterDescriptions = "(loopback|virtual|afs)"
	
	' Regular expression to make sure the address is in the correct format
	strPatternIPAddress = "((\d{1,3}\.?){4})"

	' Use a regular expression to check if the IP address is private
	strPatternPrivate = "^(10)\."

	' Use a regular expression to check if the IP address is not public
	' 10.0.0.0 – 10.255.255.255
	' 127.0.0.0 - 127.255.255.255
	' 172.16.0.0 – 172.31.255.255
	' 192.168.0.0 – 192.168.255.255
	strPatternNotPublic = "^(10|127|192\.168|172\.(1[6-9]|2[0-9]|3[0-1]))\."
	
	'intCheckAdapters = 1
	'intLoopCount = 0
	'Do While (intCheckAdapters <> 0 And intLoopCount < 3)
	'	intLoopCount = intLoopCount + 1
	'	intCheckAdapters = 0
		
		' Renew the DHCP lease if not the first iteration
		' This means DHCP was enabled on an adapter
		If (intLoopCount > 1) Then
			RunCommand CMD_IPCONFIG_RENEW, "Renewing DHCP lease"
		End If
		
		' Loop through network adapters
		For Each NA in wmi_NAs
			WScript.Echo "----------------------------------------------------------------------"
			WScript.Echo "*** " & NA.Description & " (Index: " & NA.Index & ") ***"
			'WScript.Echo
	
			'' Print all of the the Win32_NetworkAdapter properties
			'For Each NA_property in NA.Properties_
			'	If Not IsNull(NA_property.Value) Then
			'		print_variable NA_property.Value, "NA:" & NA_property.Name
			'	End If
			'Next
	
			' Get a list of network adapter configurations matching the index of the network adapter
			Set wmi_NACs = wmi.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE Index = '" & NA.Index & "'")
			For Each NAC in wmi_NACs
				WScript.Echo
	
				'' Print all of the the Win32_NetworkAdapterConfiguration properties
				'For Each NAC_property in NAC.Properties_
				'	If Not IsNull(NAC_property.Value) Then
				'		print_variable NAC_property.Value, "NAC:" & NAC_property.Name
				'	End If
				'Next
	
				' Evaluate the regular expressions
				strIgnoredAdapterName = RegExpVal(strPatternIgnoredAdapterNames, NA.Name, 0)
				strIgnoredAdapterDescription = RegExpVal(strPatternIgnoredAdapterDescriptions, NA.Description, 0)
				strIPAddress = RegExpVal(strPatternIPAddress, Join(NAC.IPAddress), 0)
				strIPAddressMatchPrivate = RegExpVal(strPatternPrivate, strIPAddress, 0)
				strIPAddressMatchNotPublic = RegExpVal(strPatternNotPublic, strIPAddress, 0)
	
				WScript.Echo "Adpater name: " & NA.Name
				WScript.Echo "Ignored adpater name section: " & strIgnoredAdapterName
				WScript.Echo "Ignored adpater description section: " & strIgnoredAdapterDescription
				WScript.Echo "IP address: " & strIPAddress
				WScript.Echo "Matching VCL private address section: " & strIPAddressMatchPrivate
				WScript.Echo "Matching non-public address section: " & strIPAddressMatchNotPublic
	
				' Check if adapter should be ignored
				If Len(strIgnoredAdapterName) > 0 Then
					WScript.Echo "Network adapter " & NA.Name & " is being ignored because the name contains: " & strIgnoredAdapterName
				
				' Check if adapter should be ignored
				Elseif Len(strIgnoredAdapterDescription) > 0 Then
					WScript.Echo "Network adapter " & NA.Name & " is being ignored because the description contains: " & strIgnoredAdapterDescription
				
				' Check to make sure a valid IP address was found
				Elseif Len(strIPAddress) = 0 Then
					WScript.Echo "IP address is either blank or not in the correct format: " & NAC.IPAddress
				
				' Check if address is a valid VCL private address (10.*)
				Elseif Len(strIPAddressMatchPrivate) > 0 Then
					PRIVATE_NAME = NA.NetConnectionID
					WScript.Echo "* PRIVATE_NAME          = " & PRIVATE_NAME
					WScript.Echo "* DHCP enabled          = " & NAC.DHCPEnabled
					'If (NAC.DHCPEnabled = "False") Then
					'	CMD_PRIVATE_ENABLE_DHCP=strSystem32 & "\netsh.exe interface ip set address name=""" & PRIVATE_NAME & """ source=dhcp"
					'	RunCommand CMD_PRIVATE_ENABLE_DHCP, "Enabling DHCP on the private adapter"
					'	intCheckAdapters = 1
					'Else
						PRIVATE_IP = strIPAddress
						PRIVATE_SUBNET_MASK = Join(NAC.IPSubnet)
						PRIVATE_DESCRIPTION = NA.Description
						If Not IsNull(NAC.DefaultIPGateway) Then
						   PRIVATE_GATEWAY = Join(NAC.DefaultIPGateway)
						End If
						WScript.Echo "* PRIVATE_IP            = " & PRIVATE_IP
						WScript.Echo "* PRIVATE_SUBNET_MASK   = " & PRIVATE_SUBNET_MASK
						WScript.Echo "* PRIVATE_GATEWAY       = " & PRIVATE_GATEWAY
						WScript.Echo "* PRIVATE_DESCRIPTION   = " & PRIVATE_DESCRIPTION
					'End If
				' Address is not a valid VCL private address (10.*) but may still be private (192.168.* ...)
				' Check if address is private
				Elseif Len(strIPAddressMatchNotPublic) > 0 Then
					WScript.Echo "IP address is not a public nor valid VCL private address: " & strIPAddress
				
				' Address is not private, it's a valid public address
				Else
					PUBLIC_NAME = NA.NetConnectionID
					WScript.Echo "* PUBLIC_NAME          = " & PUBLIC_NAME
					WScript.Echo "* DHCP enabled         = " & NAC.DHCPEnabled
					'If (NAC.DHCPEnabled = "False") Then
					'	CMD_PUBLIC_ENABLE_DHCP=strSystem32 & "\netsh.exe interface ip set address name=""" & PUBLIC_NAME & """ source=dhcp"
					'	RunCommand CMD_PUBLIC_ENABLE_DHCP, "Enabling DHCP on the public adapter"
					'	intCheckAdapters = 1
					'Else
						PUBLIC_IP = strIPAddress
						PUBLIC_SUBNET_MASK = Join(NAC.IPSubnet)
						PUBLIC_DESCRIPTION = NA.Description
						If Not IsNull(NAC.DefaultIPGateway) Then
						   PUBLIC_GATEWAY = Join(NAC.DefaultIPGateway)
						End If
						WScript.Echo "* PUBLIC_IP            = " & PUBLIC_IP
						WScript.Echo "* PUBLIC_SUBNET_MASK   = " & PUBLIC_SUBNET_MASK
						WScript.Echo "* PUBLIC_GATEWAY       = " & PUBLIC_GATEWAY
						WScript.Echo "* PUBLIC_DESCRIPTION   = " & PUBLIC_DESCRIPTION
					'End If
				End If
			Next
		Next
		
	'Loop
End function

'-----------------------------------------------------------------------------
function print_variable(arr, strTitle)
	If Not IsNull(arr) Then
		If IsArray(arr) Then
			For Each element In arr
				WScript.Echo strTitle & " = " & element
			Next
		Else
			WScript.Echo strTitle & " = " & arr
		End If
	Else
		WScript.Echo strTitle & " = NULL"
	End If
End function

'-----------------------------------------------------------------------------
Function RegExpVal(strPattern, strString, idx)
	On Error Resume Next
	Dim regEx, Match, Matches, RetStr
	Set regEx        = New RegExp
	regEx.Pattern    = strPattern
	regEx.IgnoreCase = True
	regEx.Global     = True
	Set Matches      = regEx.Execute( strString )
	RegExpVal        = Matches( 0 ).SubMatches( idx )
End Function

'-----------------------------------------------------------------------------
Function RunCommand (strCommand, strDescription)
	print_hr
	strCommand = "cmd.exe /c " & strCommand
	WScript.Echo strDescription & ", command: " & strCommand
	Set objExecResult = objShell.Exec(strCommand & " 2>&1")

	If objExecResult.ProcessID = 0 And objExecResult.Status = 1 Then
		WScript.Echo strDescription & " failed: " & err.Description
		WScript.Quit 1
	End If

	Do
		intStatus = objExecResult.Status
		WScript.StdOut.Write objExecResult.StdOut.ReadAll()
		WScript.StdErr.Write objExecResult.StdErr.ReadAll()
		If intStatus <> 0 Then Exit Do
		'WScript.Sleep 10
	Loop

	If objExecResult.ExitCode > 0 Then
		WScript.Echo strDescription & " failed, exit code: " & objExecResult.ExitCode
	Else
		WScript.Echo strDescription & " successful, exit code: " & objExecResult.ExitCode
	End If

	RunCommand = objExecResult.ExitCode
	WScript.Echo (Time)
End Function

'-----------------------------------------------------------------------------
Function print_hr
	WScript.Echo "---------------------------------------------------------------------------"
	WScript.Echo (Time)
	WScript.Echo "---------------------------------------------------------------------------"
End Function