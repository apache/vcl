Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
sTempDir = oWshEnvironment("TEMP")
Const ForReading = 1

set fso = CreateObject("Scripting.FileSystemObject")

If fso.FileExists(sTempDir & "\WANname.txt") Then
  set results = fso.GetFile(sTempDir & "\WANname.txt")
  set ts = results.OpenAsTextStream(ForReading)
  do while ts.AtEndOfStream <> True
	retString = ts.ReadLine
  loop
  ts.Close
  sConnectionName = retString
Else
  WScript.Echo "File '" & sTempDir & "\WANname.txt" & "' does NOT exists!"
  WScript.Echo "Cannot continue! Quitting..."
  WScript.Quit
End If

Const ssfCONTROLS = 3

WScript.Echo "Enabling '" & sConnectionName & "' (WAN) connection..."

sEnableVerb = "En&able"
sDisableVerb = "Disa&ble"

set shellApp = createobject("shell.application")
set oControlPanel = shellApp.Namespace(ssfCONTROLS)
'Wscript.Echo "oControlPanel: " & oControlPanel

set oNetConnections = nothing
for each folderitem in oControlPanel.items
'  if folderitem.name  = "Network and Dial-up Connections" then
  if folderitem.name  = "Network Connections" then
    set oNetConnections = folderitem.getfolder: exit for
  end if
next

if oNetConnections is nothing then
'  msgbox "Couldn't find 'Network and Dial-up Connections' folder"
  msgbox "Couldn't find 'Network Connections' folder"
  wscript.quit
end if

set oLanConnection = nothing
for each folderitem in oNetConnections.items
  if lcase(folderitem.name)  = lcase(sConnectionName) then
    set oLanConnection = folderitem: exit for
  end if
next

if oLanConnection is nothing then
  msgbox "Couldn't find '" & sConnectionName & "' item"
  wscript.quit
end if


bEnabled = true
set oEnableVerb = nothing
set oDisableVerb = nothing
s = "Verbs: " & vbcrlf
for each verb in oLanConnection.verbs
  s = s & vbcrlf & verb.name
  if verb.name = sEnableVerb then 
    set oEnableVerb = verb  
    bEnabled = false
  end if
  if verb.name = sDisableVerb then 
    set oDisableVerb = verb  
  end if
next



'debugging displays left just in case...
'
'msgbox s ': wscript.quit
'msgbox "Enabled: " & bEnabled ': wscript.quit

'not sure why, but invokeverb always seemed to work 
'for enable but not disable.  
'
'saving a reference to the appropriate verb object 
'and calling the DoIt method always seems to work.
'

if bEnabled then
'  oLanConnection.invokeverb sDisableVerb
   Wscript.Echo "'" & sConnectionName & "' already enabled!"
'  oDisableVerb.DoIt
else
'  oLanConnection.invokeverb sEnableVerb
   oEnableVerb.DoIt
   wscript.sleep 5000 
   WScript.Echo "Done!"
'   Wscript.Echo sConnectionName & " enabled!"
end if


'adjust the sleep duration below as needed...
'
'if you let the oLanConnection go out of scope
'and be destroyed too soon, the action of the verb
'may not take...
'
'wscript.sleep 5000 
