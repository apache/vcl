strCurrentImagePath = "C:\cygwin\home\root\currentimage.txt"
strSetnameLogfile = "C:\VCL\Logs\setname.log"
strWSNamePath = "C:\VCL\Utilities\wsname.exe"

Set objShell = WScript.CreateObject("WScript.Shell")

' Read the currentimage.txt file and find the id= line
strImageID = GetKeyValue(strCurrentImagePath, "id", "=")

' If image ID wasn't found don't include it
If Len(strImageID) > 0 Then
   WScript.Echo "Image ID found in currentimage.txt: " & strImageID
   strComputerName = "$DNS-" & strImageID
Else
   WScript.Echo "Image ID could not be retrieved from currentimage.txt"
   strComputerName = "$DNS"
End If
WScript.Echo "wsname.exe computer name string: " & strComputerName

' Execute the wsname.exe utility
' Set the computer name to the hostname ($DNS) followed by the image ID
strSetnameCommand = strWSNamePath & " /N:" & strComputerName & " /LOGFILE:" & strSetnameLogfile & " /IGNOREMEMBERSHIP /ADR /NOSTRICTNAMECHECKING /LONGDNSHOST"
WScript.Echo "wsname.exe command: " & strSetnameCommand

On Error Resume Next
objShell.Exec(strSetnameCommand)

if not err.number=0 then 
   WScript.Echo "Error running setname.exe: " & err.Description
   vbCritical err.clear
else
   WScript.Echo "Successfully ran setname.exe"
end if



' Read the currentimage.txt file and find the prettyname= line
strImagePrettyname = GetKeyValue(strCurrentImagePath, "prettyname", "=")

' If image pretty name wasn't found use the computer name for My Computer
If Len(strImagePrettyname) > 0 Then
   WScript.Echo "Image prettyname found in currentimage.txt: " & strImagePrettyname
   strMyComputerName = strImagePrettyname
Else
   WScript.Echo "Image prettyname could not be retrieved from currentimage.txt"
   strMyComputerName = "%COMPUTERNAME%"
End If

' Modify the registry key that controls how My Computer is displayed
' Set it to the image prettyname
strMyComputerReg = "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\"
On Error Resume Next
objShell.RegWrite strMyComputerReg, strMyComputerName, "REG_EXPAND_SZ"
if not err.number=0 then 
   WScript.Echo "Error setting registry key: " & strMyComputerReg & "\Default: " & strMyComputerName
   vbCritical err.clear
else
   WScript.Echo "Set registry key: " & strMyComputerReg & "\Default: " & strMyComputerName
end if

On Error Resume Next
objShell.RegWrite strMyComputerReg & "LocalizedString", strMyComputerName, "REG_EXPAND_SZ"
if not err.number=0 then 
   WScript.Echo "Error setting registry key: " & strMyComputerReg & "\LocalizedString: " & strMyComputerName
   vbCritical err.clear
else
   WScript.Echo "Set registry key: " & strMyComputerReg & "\LocalizedString: " & strMyComputerName
end if

WScript.Quit
'----------------------------------------------------------
Function GetKeyValue(strFilePath, strKey, strDeliminator)

   Set objFSO = CreateObject("Scripting.FileSystemObject")
   On Error Resume Next
   Set objInputFile = objFSO.OpenTextFile(strCurrentImagePath)
   
   if not err.number=0 then 
      WScript.Echo "Error opening " & strCurrentImagePath & ", " & err.Description
      vbCritical err.clear
      GetKeyValue = ""
   else
      WScript.Echo "File opened: " & strCurrentImagePath

      strPattern = "^" & strKey & strDeliminator & "(.*)$"
      Do While Not (objInputFile.atEndOfStream) And Len(strValue)=0
         strLine = objInputFile.ReadLine
         strValue = RegExpVal(strPattern, strLine, 0)
      Loop
   
      objInputFile.Close
   
      GetKeyValue = strValue
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