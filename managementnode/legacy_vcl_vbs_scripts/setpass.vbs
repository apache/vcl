    Option Explicit
    Dim WshNetwork, strPass, oAdminAcct
    Dim UserAccount

    If WScript.Arguments.Count = 2 Then
       UserAccount = WScript.Arguments.Item(0)
       strPass = WScript.Arguments.Item(1)
    Else
       WScript.Echo "Usage: RandPass.wsf <user_account> <password>"
       WScript.Quit
    End If

    Set WshNetwork = WScript.CreateObject("WScript.Network")
    Set oAdminAcct = GetObject("WinNT://" & WshNetwork.ComputerName & "/" & UserAccount)

    oAdminAcct.SetPassword strPass
