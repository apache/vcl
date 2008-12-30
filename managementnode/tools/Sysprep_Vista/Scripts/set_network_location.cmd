rem 0=Private (Home/Work), 1=Public

echo Setting registry key to specify network location...
"%SystemRoot%\System32\reg.exe" add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\FirstNetwork" /v Category /t REG_DWORD /d 00000000 /f
echo.