@echo off
rem Licensed to the Apache Software Foundation (ASF) under one or more
rem contributor license agreements.  See the NOTICE file distributed with
rem this work for additional information regarding copyright ownership.
rem The ASF licenses this file to You under the Apache License, Version 2.0
rem (the "License"); you may not use this file except in compliance with
rem the License.  You may obtain a copy of the License at
rem
rem     http://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

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