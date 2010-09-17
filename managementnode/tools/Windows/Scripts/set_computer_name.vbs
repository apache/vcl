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

' NOTICE: This script relies on the wsname.exe utility which is no longer
' available. This script will be rewritten for the 2.2 release of VCL. In the
' meantime, this script is being left intact in case you have a previously
' released version of wsname.exe or are able to obtain it from another source. You
' should not encounter problems if you do not have wsname.exe, however, computers
' will be given random names. This script only applies to Windows images.

strCurrentImagePath = "C:\Cygwin\home\root\currentimage.txt"
strSetnameLogfile = "C:\Cygwin\home\root\VCL\Logs\sysprep_cmdlines\wsname_output.log"
strWSNamePath = "C:\Cygwin\home\root\VCL\Utilities\WSName\wsname.exe"

Set objShell = WScript.CreateObject("WScript.Shell")

'----------------------------------------------------------------------------
WScript.Echo "Attempting to retrieve image information from currentimage.txt"

' Read the currentimage.txt file and find the prettyname= line
strImagePrettyname = GetKeyValue(strCurrentImagePath, "prettyname", "=")

' If image pretty name wasn't found use the computer name for My Computer
If Len(strImagePrettyname) > 0 Then
   WScript.Echo "Image prettyname found in currentimage.txt: " & strImagePrettyname
	strComputerDescription = strImagePrettyname
Else
   WScript.Echo "Image prettyname could not be retrieved from currentimage.txt"
End If

'----------------------------------------------------------------------------
' Read the currentimage.txt file and get the image name
strImageName = GetImageName(strCurrentImagePath)

' Check if image name was found
If Len(strImageName) > 0 Then
   WScript.Echo "Image name found in currentimage.txt: " & strImageName
	strComputerDescription = strComputerDescription & " (" & strImageName & ")"
Else
   WScript.Echo "Image name could not be retrieved from currentimage.txt"
End If

'----------------------------------------------------------------------------
' Read the currentimage.txt file and find the id= line
strImageID = GetKeyValue(strCurrentImagePath, "id", "=")

' Check if image ID wasn found
If Len(strImageID) > 0 Then
   WScript.Echo "Image ID found in currentimage.txt: " & strImageID
	strComputerName = "$DNS-" & strImageID
Else
   WScript.Echo "Image ID could not be retrieved from currentimage.txt"
	strComputerName = "$DNS"
End If

'----------------------------------------------------------------------------
print_hr

WScript.Echo "Attempting to rename the computer using wsname.exe"

' Execute the wsname.exe utility
' Set the computer name to the hostname ($DNS) followed by the image ID
strWsnameCommand = strWSNamePath & " /N:" & strComputerName & " /LOGFILE:" & strSetnameLogfile & " /IGNOREMEMBERSHIP /ADR /NOSTRICTNAMECHECKING /LONGDNSHOST 2>&1"
WScript.Echo "wsname.exe command: " & strWsnameCommand

On Error Resume Next
objShell.Exec(strWsnameCommand)

if not err.number=0 then 
   WScript.Echo "Error running wsname.exe: " & err.Description
   vbCritical err.clear
else
   WScript.Echo "Successfully ran wsname.exe"
end if

'----------------------------------------------------------------------------
print_hr

WScript.Echo "Attempting to set the computer description to: " & strComputerDescription

' Modify the registry key that controls how My Computer is displayed
' Set it to the image prettyname
strComputerDescriptionReg = "HKLM\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters\"
objShell.RegWrite strComputerDescriptionReg & "srvcomment", strComputerDescription, "REG_SZ"

if not err.number=0 then 
   WScript.Echo "Error occurred setting computer description: " & err.Description
   vbCritical err.clear
else
   WScript.Echo "Successfully set computer description"
end if

WScript.Quit
'----------------------------------------------------------
Function GetKeyValue(strFilePath, strKey, strDeliminator)
   Set objShell = WScript.CreateObject("WScript.Shell")
	strCommand = "%comspec% /c type " & strFilePath
	Set objExecObject = objShell.Exec(strCommand)
	
   if not err.number=0 then 
      WScript.Echo "Error running command: " & strCommand & ", " & err.Description
      vbCritical err.clear
      GetKeyValue = ""
   else
      strPattern = "^" & strKey & strDeliminator & "(.*)$"
		
		Do While Not (objExecObject.StdOut.atEndOfStream) And Len(strValue)=0
			strLine = objExecObject.StdOut.ReadLine()
			strValue = RegExpVal(strPattern, strLine, 0)
		Loop
   
      GetKeyValue = strValue
   end if

End Function

'----------------------------------------------------------
Function GetImageName(strFilePath)
	Set objShell = WScript.CreateObject("WScript.Shell")
	strCommand = "%comspec% /c type " & strFilePath
	Set objExecObject = objShell.Exec(strCommand)

   if not err.number=0 then 
      WScript.Echo "Error running command: " & strCommand & ", " & err.Description
      vbCritical err.clear
      GetKeyValue = ""
   else
	   strLine = objExecObject.StdOut.ReadLine
	   GetImageName = strLine
   end if

End Function

'----------------------------------------------------------
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
'----------------------------------------------------------
Function print_hr
	WScript.Echo "----------------------------------------------------------------------"
End Function
