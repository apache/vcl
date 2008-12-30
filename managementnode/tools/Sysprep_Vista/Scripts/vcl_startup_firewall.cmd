echo Enabling SSH port 22 traffic from the private network...

"%SystemRoot%\System32\netsh.exe" advfirewall firewall set rule ^
name="VCL: allow SSH port 22 from private network" ^
new ^
action=allow ^
description="Allows incoming TCP port 22 traffic from 10.x.x.x addresses" ^
dir=in ^
enable=yes ^
localip=10.0.0.0/8 ^
localport=22 ^
protocol=TCP ^
remoteip=10.0.0.0/8

echo ERRORLEVEL: %ERRORLEVEL%
echo.


echo Enabling ping traffic from the private network...

"%SystemRoot%\System32\netsh.exe" advfirewall firewall set rule ^
name="VCL: allow ping from private network" ^
new ^
action=allow ^
description="Allows incoming ping (ICMP type 8) messages from 10.x.x.x addresses" ^
dir=in ^
enable=yes ^
localip=10.0.0.0/8 ^
protocol=icmpv4:8,any ^
remoteip=10.0.0.0/8

echo ERRORLEVEL: %ERRORLEVEL%
echo.

exit /B 0