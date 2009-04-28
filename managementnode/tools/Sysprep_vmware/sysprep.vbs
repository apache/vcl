
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

Set oWshShell = CreateObject("WScript.Shell")
Set oWshEnvironment = oWshShell.Environment("Process")
Set oFileSystem = CreateObject("Scripting.FileSystemObject")
sTempDir = oWshEnvironment("TEMP")
Dim oExec
Dim GuiAnswer
strComputer = "."

oFileSystem.CopyFile "C:\Documents and Settings/root/Application Data\VCL\VCLprepare.cmd", "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\",true

WScript.Echo "copied VCLrcboot"

'delete
Set aFile = oFileSystem.GetFile("C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCLcleanup.cmd")
aFile.Delete
WScript.Echo "Deleted VCLcleanup.cmd"

'start sysprep
oWshShell.run "C:\Sysprep\sysprep.exe -quiet -forceshutdown -reseal -mini -activated", 1, false
WScript.Echo "Executed sysprep.exe"

Set oWshShell = Nothing
WScript.Quit
