Set objNetwork = CreateObject("Wscript.Network")
strComputer = objNetwork.ComputerName
Set colAccounts = GetObject("WinNT://" & strComputer & "")
colAccounts.Filter = Array("user")
For Each objUser In colAccounts
    Wscript.Echo objUser.Name
Next