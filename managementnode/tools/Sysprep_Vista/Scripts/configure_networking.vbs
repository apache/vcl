strSystem32="%SystemRoot%\system32"

' Assemble the networking commands
CMD_ROUTE_FLUSH=strSystem32 & "\route.exe -f"
CMD_ROUTE_PRINT=strSystem32 & "\route.exe print"
CMD_IPCONFIG_RENEW=strSystem32 & "\ipconfig.exe /renew"
CMD_IPCONFIG_RELEASE=strSystem32 & "\ipconfig.exe /release"

' Renew the DHCP lease to make sure not to retrieve old information
RunCommand CMD_IPCONFIG_RELEASE, "Releasing DHCP lease"
RunCommand CMD_IPCONFIG_RENEW, "Renewing DHCP lease"

Dim PRIVATE_NAME, PRIVATE_IP, PRIVATE_GATEWAY
Dim PUBLIC_NAME, PUBLIC_IP, PUBLIC_GATEWAY

' Use WMI to retrieve the networking configuration
get_network_configuration
print_hr

WScript.Echo "PRIVATE_NAME          = " & PRIVATE_NAME
WScript.Echo "PRIVATE_IP            = " & PRIVATE_IP
WScript.Echo "PRIVATE_GATEWAY       = " & PRIVATE_GATEWAY
WScript.Echo "PUBLIC_NAME           = " & PUBLIC_NAME
WScript.Echo "PUBLIC_IP             = " & PUBLIC_IP
WScript.Echo "PUBLIC_GATEWAY        = " & PUBLIC_GATEWAY

' Check if all the required information was found
If Len(PRIVATE_GATEWAY) > 0 And Len(PUBLIC_GATEWAY) > 0 Then
	WScript.Echo "Successfully retrieved network configuration"
Else
	WScript.Echo "Failed to retrieve network configuration, returning exit status 1"
	WScript.Quit 1
End If

' Assemble the networking commands which need other information
CMD_ROUTE_ADD_PUBLIC_GATEWAY=strSystem32 & "\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 " & PUBLIC_GATEWAY & " METRIC 1"
CMD_ROUTE_ADD_PRIVATE_GATEWAY=strSystem32 & "\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 " & PRIVATE_GATEWAY & " METRIC 2"
CMD_ROUTE_DELETE_PUBLIC_GATEWAY=strSystem32 & "\route.exe DELETE 0.0.0.0 MASK 0.0.0.0 " & PUBLIC_GATEWAY
CMD_ROUTE_DELETE_PRIVATE_GATEWAY=strSystem32 & "\route.exe DELETE 0.0.0.0 MASK 0.0.0.0 " & PRIVATE_GATEWAY
CMD_SET_NTSYSLOG_GATEWAY=strSystem32 & "\reg.exe ADD HKLM\SOFTWARE\SaberNet /v syslog /d " & PRIVATE_GATEWAY & " /f"

' Run commands to configure networking
' Keep a total of the exit codes
intExitCodeTotal = 0
intExitCodeTotal = intExitCodeTotal + RunCommand(CMD_ROUTE_DELETE_PUBLIC_GATEWAY, "Deleting route to public default gateway")
intExitCodeTotal = intExitCodeTotal + RunCommand(CMD_ROUTE_DELETE_PRIVATE_GATEWAY, "Deleting route to private default gateway")
intExitCodeTotal = intExitCodeTotal + RunCommand(CMD_ROUTE_ADD_PUBLIC_GATEWAY, "Adding route to public default gateway")
intExitCodeTotal = intExitCodeTotal + RunCommand(CMD_ROUTE_ADD_PRIVATE_GATEWAY, "Adding route to private default gateway")
intExitCodeTotal = intExitCodeTotal + RunCommand(CMD_SET_NTSYSLOG_GATEWAY, "Configuring SyslogNT to use private default gateway")
RunCommand CMD_ROUTE_PRINT, "Printing routing table"

print_hr

' Update syslog - stop and restart service
objWMIService = ""
intSleep = 1500

WScript.Echo strService & " service has Started"
WScript.Quit 0

WScript.Quit intExitCodeTotal

'-----------------------------------------------------------------------------
function get_network_configuration
	' Connect to local computer via WMI
	Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

	' Get a list of network adapters
	' NetConnectionStatus: 0 = Disconnected, 1 = Connecting, 2 = Connected
	Set wmi_NAs = wmi.ExecQuery("SELECT * FROM Win32_NetworkAdapter WHERE " & _
											"NetConnectionStatus = 2 " & _
											"AND Name LIKE '%Broadcom%'" & _
											"AND NOT ServiceName LIKE '%loop%'")

	' Loop through neteork adapters
	If (wmi_NAs.count = 0) Then
		WScript.Echo "No network adapters were found"
		WScript.Quit 1
	End If

	' Loop through neteork adapters
	For Each NA in wmi_NAs
		WScript.Echo "----------------------------------------------------------------------"
		WScript.Echo "*** " & NA.Description & " ***"
		WScript.Echo

		'' Print all of the the Win32_NetworkAdapter properties
		'For Each NA_property in NA.Properties_
		'	If Not IsNull(NA_property.Value) Then
		'		print_variable NA_property.Value, "NA:" & NA_property.Name
		'	End If
		'Next

		' Get a list of network adapter configurations matching the index of the network adapter
		Set wmi_NACs = wmi.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE Index = '" & NA.Index & "'")
		If (wmi_NACs.count > 0) Then
			For Each NAC in wmi_NACs
				WScript.Echo

				'' Print all of the the Win32_NetworkAdapterConfiguration properties
				'For Each NAC_property in NAC.Properties_
				'	If Not IsNull(NAC_property.Value) Then
				'		print_variable NAC_property.Value, "NAC:" & NAC_property.Name
				'	End If
				'Next

				' Use a regular expression to check if the IP address is private
				strPatternPrivate = "(10\.[\d\.]+)"
				strIPAddressMatchPrivate = RegExpVal(strPatternPrivate, Join(NAC.IPAddress), 0)
				If Len(strIPAddressMatchPrivate) > 0 Then
					PRIVATE_IP = strIPAddressMatchPrivate
					PRIVATE_NAME = NA.NetConnectionID
					PRIVATE_DESCRIPTION = NA.Description
					PRIVATE_GATEWAY = Join(NAC.DefaultIPGateway)

					WScript.Echo "* PRIVATE_NAME          = " & PRIVATE_NAME
					WScript.Echo "* PRIVATE_IP            = " & PRIVATE_IP
					WScript.Echo "* PRIVATE_GATEWAY       = " & PRIVATE_GATEWAY
				End If

				' Use a regular expression to check if the IP address is public
				strPatternPublic = "(152\.[\d\.]+)"
				strIPAddressMatchPublic = RegExpVal(strPatternPublic, Join(NAC.IPAddress), 0)
				If Len(strIPAddressMatchPublic) > 0 Then
					PUBLIC_IP = strIPAddressMatchPublic
					PUBLIC_NAME = NA.NetConnectionID
					PUBLIC_DESCRIPTION = NA.Description
					PUBLIC_GATEWAY = Join(NAC.DefaultIPGateway)

					WScript.Echo "* PUBLIC_NAME          = " & PUBLIC_NAME
					WScript.Echo "* PUBLIC_IP            = " & PUBLIC_IP
					WScript.Echo "* PUBLIC_GATEWAY       = " & PUBLIC_GATEWAY
				End If

			Next
		End if
	Next
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
	WScript.Echo strDescription & ", command: " & strCommand
	Set objShell = CreateObject("WScript.Shell")
	Set objExecResult = objShell.Exec(strCommand)

	If objExecResult.ProcessID = 0 And objExecResult.Status = 1 Then
		WScript.Echo strDescription & " failed: " & err.Description
		WScript.Quit 1
	End If

	Do
		intStatus = objExecResult.Status
		WScript.StdOut.Write objExecResult.StdOut.ReadAll()
		WScript.StdErr.Write objExecResult.StdErr.ReadAll()
		If intStatus <> 0 Then Exit Do
		WScript.Sleep 10
	Loop

	If objExecResult.ExitCode > 0 Then
		WScript.Echo strDescription & " failed, exit code: " & objExecResult.ExitCode
	Else
		WScript.Echo strDescription & " successful, exit code: " & objExecResult.ExitCode
	End If

	RunCommand = objExecResult.ExitCode
End Function

'-----------------------------------------------------------------------------
Function print_hr
	WScript.Echo "----------------------------------------------------------------------"
End Function