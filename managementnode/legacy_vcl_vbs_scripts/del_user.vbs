Dim UserAccount
 
If WScript.Arguments.Count = 1 Then
   UserAccount = WScript.Arguments.Item(0)
Else
   WScript.Echo "Usage: del_user.vbs <user_name>"
   WScript.Quit
End If

strComputer = "."
Set objComputer = GetObject("WinNT://" & strComputer & ",computer")
objComputer.Delete "user", UserAccount

WScript.sleep 1000