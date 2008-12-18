
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
