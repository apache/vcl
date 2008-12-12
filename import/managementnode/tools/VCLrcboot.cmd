@echo off

copy "C:\Documents and Settings\root\Application Data\VCL\VCLprepare.cmd" C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\

del C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCLcleanup.cmd

cd %APPDATA%/vcl

%SystemRoot%\system32\cmd.exe /c C:\WINDOWS\regedit.exe /s nodyndns.reg

%SystemRoot%\system32\cmd.exe /c wsname.exe /N:$DNS /MCN

%SystemRoot%\system32\cscript.exe enablepagefile.vbs

%SystemRoot%\system32\cmd.exe /c C:\WINDOWS\system32\ping.exe 1.1.1.1 %-n 1 -w 2000 > NUL

%SystemRoot%\system32\cmd.exe /c newsid.exe /a /d 6

del C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\VCLrcboot.cmd 
