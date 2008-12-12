strCurrentImagePath = "C:\cygwin\home\root\currentimage.txt"
strSetnameLogfile = "C:\cygwin\home\root\setname.log"

Set objShell = WScript.CreateObject("WScript.Shell")

' Read the currentimage.txt file and find the id= line
strImageID = GetKeyValue(strCurrentImagePath, "id", "=")

' If image ID wasn't found don't include it
If Len(strImageID) > 0 Then
   strComputerName = "$DNS-" & strImageID
Else
   strComputerName = "$DNS"
End If

' Execute the wsname.exe utility
' Set the computer name to the hostname ($DNS) followed by the image ID
strSetnameCommand = "wsname.exe /N:" & strComputerName & " /LOGFILE:" & strSetnameLogfile & " /IGNOREMEMBERSHIP /ADR /NOSTRICTNAMECHECKING /LONGDNSHOST"
objShell.Exec(strSetnameCommand)

' Read the currentimage.txt file and find the prettyname= line
strImagePrettyname = GetKeyValue(strCurrentImagePath, "prettyname", "=")

' If image pretty name wasn't found use the computer name for My Computer
If Len(strImagePrettyname) > 0 Then
   strMyComputerName = strImagePrettyname
Else
   strMyComputerName = "%COMPUTERNAME%"
End If

' Modify the registry key that controls how My Computer is displayed
' Set it to the image prettyname
strMyComputerReg = "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\"
objShell.RegWrite strMyComputerReg, strMyComputerName, "REG_EXPAND_SZ"
objShell.RegWrite strMyComputerReg & "LocalizedString", strMyComputerName, "REG_EXPAND_SZ"

WScript.Quit
'----------------------------------------------------------
Function GetKeyValue(strFilePath, strKey, strDeliminator)
   Set objFSO = CreateObject("Scripting.FileSystemObject")
   Set objInputFile = objFSO.OpenTextFile(strFilePath)

   strPattern = "^" & strKey & strDeliminator & "(.*)$"
   Do While Not (objInputFile.atEndOfStream) And Len(strValue)=0
      strLine = objInputFile.ReadLine
      strValue = RegExpVal(strPattern, strLine, 0)
   Loop
   
   objInputFile.Close
   
   GetKeyValue = strValue
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