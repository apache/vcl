On Error Resume Next

strComputer = "."
Set objWMIService = GetObject("winmgmts:\\"& strComputer & "\root\cimv2")
Set colAdapters = objWMIService.ExecQuery _
    ("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")

For Each objAdapter in colAdapters
   ' Use 0 to use the NetBIOS setting from the DHCP server
   ' Use 1 to enable NetBIOS over TCP/IP
   ' Use 2 to disable NetBIOS over TCP/IP
   objAdapter.SetTCPIPNetBIOS(2)
Next
