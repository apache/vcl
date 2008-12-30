echo Configuring Vista to use a KMS server for activation...
cscript.exe //NoLogo %SystemRoot%\system32\slmgr.vbs -skms kms.unity.ad.ncsu.edu:1688
echo.

echo Attempting to activate Vista...
cscript.exe //NoLogo %SystemRoot%\system32\slmgr.vbs -ato
echo.