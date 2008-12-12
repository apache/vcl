@echo off

cd %APPDATA%/vcl

%SystemRoot%\system32\cscript.exe unsetautologon.vbs

%SystemRoot%\system32\cscript.exe updatecygwin.vbs

%SystemRoot%\system32\cscript.exe postconfig.vbs

copy VCLcleanup.cmd C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\

%SystemRoot%\system32\eventcreate.exe /T INFORMATION /L APPLICATION /SO VCLprepare.cmd /ID 555 /D "%COMPUTERNAME% is READY."

%SystemRoot%\system32\logoff.exe
