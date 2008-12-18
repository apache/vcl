
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

Set oWshShell = CreateObject("WScript.Shell")

' create new "passwd" and "group" files for cygwin, because SID was changed 
oWshShell.Run "cmd.exe /C del " & "c:\cygwin\etc\group", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C del " & "c:\cygwin\etc\passwd", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\mkgroup.exe -l" & " > c:\cygwin\etc\group", 0, TRUE
WScript.Sleep 1000
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\mkpasswd.exe -l" & " > c:\cygwin\etc\passwd", 0, TRUE
WScript.Sleep 1000

' restore ownership of files
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\chown.exe root:None /etc/ssh*", 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\chown.exe -R root:None /home/", 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\chown.exe root:None /var/empty", 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\chown.exe root:None /var/log/sshd.log", 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\chown.exe root:None /var/log/lastlog", 0, TRUE
WScript.Sleep 1000

' regenerate ssh keys
' first delete old ones
oWshShell.Run "cmd.exe /C del " & "c:\cygwin\etc\ssh_host_*", 0, TRUE

oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\ssh-keygen.exe -q -t rsa1 -f /etc/ssh_host_key -N " & Chr(34) & Chr(34), 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\ssh-keygen.exe -q -t rsa -f /etc/ssh_host_rsa_key -N " & Chr(34) & Chr(34), 0, TRUE
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\ssh-keygen.exe -q -t dsa -f /etc/ssh_host_dsa_key -N " & Chr(34) & Chr(34), 0, TRUE

' start SSH Daemon
oWshShell.Run "cmd.exe /C " & "c:\cygwin\bin\cygrunsrv.exe -S sshd", 0, TRUE
'WScript.Sleep 1000

WScript.Quit
