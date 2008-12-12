@echo off

call "%APPDATA%\VCL\networkinfo.bat"

sc stop ntsyslog

:WAIT
FOR /f "skip=1 tokens=1,4 " %%a in ('sc query ntsyslog') do (
  if %%a==STATE (
    if %%b==STOPPED (
      GOTO CONTINUE
    ) else (
      ping 1.1.1.1 -n 1 -w 1000 > NUL
      GOTO WAIT
    )
  )
)

:CONTINUE

reg add HKLM\SOFTWARE\SaberNet /v Syslog /d %INTERNAL_GW% /f

sc start ntsyslog

:WAIT2
FOR /f "skip=1 tokens=1,4 " %%a in ('sc query ntsyslog') do (
  if %%a==STATE (
    if %%b==RUNNING (
      GOTO END
    ) else (
      ping 1.1.1.1 -n 1 -w 1000 > NUL
      GOTO WAIT2
    )
  )
)

:END