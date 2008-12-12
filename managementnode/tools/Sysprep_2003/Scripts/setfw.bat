@echo off

ipconfig /renew

ping 1.1.1.1 -n 1 -w 10000 > NUL

call "%APPDATA%\VCL\networkinfo.bat"

%SystemRoot%\system32\route.exe -p ADD 0.0.0.0 MASK 0.0.0.0 %EXTERNAL_GW% METRIC 2

netsh firewall set icmpsetting type = 8 mode = enable interface = "%INTERNAL_NAME%"

netsh firewall set portopening protocol = TCP port = 3389 mode = enable scope = custom addresses = %INTERNAL_GW%

netsh firewall set portopening protocol = TCP port = 3389 mode = disable interface = "%EXTERNAL_NAME%"

netsh firewall set portopening protocol = TCP port = 22 name = SSHD mode = enable interface = "%INTERNAL_NAME%"
