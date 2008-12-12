Dim strUsername
Dim strPassword
 
' Check arguments
If WScript.Arguments.Count = 2 Then
   strUsername = WScript.Arguments.Item(0)
   strPassword = WScript.Arguments.Item(1)
Else
   WScript.Echo "Usage: setpass.vbs <user_name> <password>"
   WScript.Quit
End If


SetPassword

WScript.Echo "Successfully set password for user: " & strUsername
WScript.quit 0

'----------------------------------------------------------------------------
Function UserExists
   WScript.Echo "Checking if user exists: " & strUsername
   
   on error resume next
   Set objUser = GetObject("WinNT://./" & strUsername) 
   
   If IsObject(objUser) Then
      WScript.Echo "OK: User already exists"
      UserExists = 1
   Else
      WScript.Echo "OK: User does not exist"
      UserExists = 0
   End If
End Function

'----------------------------------------------------------------------------
Sub CreateUser
   WScript.Echo "Creating user account: " & strUsername
   
   Set objComputer = GetObject("WinNT://.")
   on error resume next

   Set objUser = objComputer.Create("user", strUsername)
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: user account could not be created, user object could not be obtained"
      Quit
   End If

   objUser.Put "Description", "VCL user account"

   objUser.SetInfo
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: user account could not be created, unable to set info"
      Quit
   End If
      
   WScript.Echo "SUCCESS: User account was created"
End Sub

'----------------------------------------------------------------------------
Sub DeleteUser
   WScript.Echo "Deleting user " & strUsername

   on error resume next

   Set objComputer = GetObject("WinNT://.")
   

   If (CheckError <> 0) Then
      WScript.Echo "ERROR: user object could not be deleted, computer object could not be obtained"
      Quit
   End If

   objComputer.Delete "user", strUsername
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: user object could not be deleted"
      Quit
   End If

   WScript.Echo "SUCCESS: User account was deleted"
End Sub

'----------------------------------------------------------------------------
Sub SetPassword
   WScript.Echo "Setting password for " & strUsername
   
   on error resume next
   
   Set objUser = GetObject("WinNT://./" & strUsername)
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: unable to get user object before setting password"
      Quit
   End If

   objUser.SetPassword strPassword
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: unable to set password"
      Quit
   End If

   WScript.Echo "SUCCESS: Password was set"
End Sub


'----------------------------------------------------------------------------
Sub AddUserToGroup(strGroup)
   WScript.Echo "Adding " & strUsername & " to group: " & strGroup

   on error resume next 
   
   set objGroup = GetObject("WinNT://./" & strGroup) 
   If (CheckError <> 0) Then
      WScript.Echo "ERROR: unable to get group object before adding user"
      Quit
   End If 

   objGroup.Add "WinNT://" & strUsername
   If (Err.Number = "-2147023518") Then 
      WScript.Echo "OK: " & strUsername & " is already a member of " & strGroup
   ElseIf (CheckError <> 0) Then
      WScript.Echo "ERROR: unable to add user to group"
      Quit
   Else
      WScript.Echo "SUCCESS: " & strUsername & " added to " & strGroup
   End If
End Sub

'----------------------------------------------------------------------------
Function CheckError 
   If (Err.number <> 0) Then 
      DisplayErrorInfo
      Err.clear
      CheckError = 1
   Else
      CheckError = 0
   End If 
end Function

'----------------------------------------------------------------------------
Sub DisplayErrorInfo
    WScript.Echo "Error:      : " & Err
    WScript.Echo "Error (hex) : &H" & Hex(Err)
    WScript.Echo "Source      : " & Err.Source
    WScript.Echo "Description : " & Err.Description
    Err.Clear
End Sub

'----------------------------------------------------------------------------
Sub Quit
   WScript.Echo "Script exiting after error"
   WScript.Quit 1
End Sub

'----------------------------------------------------------------------------