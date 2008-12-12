Dim UserAccount
Dim UserPasswd
 
If WScript.Arguments.Count = 2 Then
   UserAccount = WScript.Arguments.Item(0)
   UserPasswd = WScript.Arguments.Item(1)
Else
   WScript.Echo "Usage: add_user.vbs <user_name> <user_passwd>"
   WScript.Quit
End If

strComputer = "."
Set colAccounts = GetObject("WinNT://" & strComputer & "")
Set objUser = colAccounts.Create("user", UserAccount)
objUser.SetPassword UserPasswd
objUser.SetInfo

Set net = WScript.CreateObject("WScript.Network") 
local = net.ComputerName 
set group = GetObject("WinNT://"& local &"/Administrators") 
set group1 = GetObject("WinNT://"& local &"/Remote Desktop Users") 
on error resume next 
group.Add "WinNT://"& UserAccount &""
group1.Add "WinNT://"& UserAccount &""
CheckError 

sub CheckError 
  if not err.number=0 then 
    WScript.Echo err.Number
    vbCritical err.clear 
'  else WScript.Echo "Done!" 
  end if 
end sub

WScript.sleep 1000