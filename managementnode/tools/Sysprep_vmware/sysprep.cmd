copy "C:\Documents and Settings/root/Application Data\VCL\VCLprepare.cmd" C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logon\
del "C:\WINDOWS\system32\GroupPolicy\User\Scripts\Logoff\VCLcleanup.cmd"
C:\Sysprep\sysprep -quiet -reseal -mini -activated -shutdown
