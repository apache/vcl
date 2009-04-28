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

FOR /f "skip=1 tokens=2,15 " %%a in ('IPCONFIG') do (
  if %%a==Address. (
    SET FIRST_IP=%%b 
    GOTO CONTINUE
  )
)

:CONTINUE

FOR /f "skip=10 tokens=2,15 " %%a in ('IPCONFIG') do (
  if %%a==Address. (
    SET SECOND_IP=%%b 
  )
)

REM echo FIRST_IP = %FIRST_IP%
REM echo SECOND_IP = %SECOND_IP%

FOR /f "skip=1 tokens=1,2* " %%a in ('IPCONFIG') do (
  if %%b==adapter (
    SET FIRST_NAME=%%c
    GOTO CONTINUE2
  )
)

:CONTINUE2

FOR /f "skip=10 tokens=1,2* " %%a in ('IPCONFIG') do (
  if %%b==adapter (
    SET SECOND_NAME=%%c
  )
)

FOR /f "tokens=1 delims=:" %%a in ('echo %FIRST_NAME%') do (
    SET FIRST_NAME=%%a
)

FOR /f "tokens=1 delims=:" %%a in ('echo %SECOND_NAME%') do (
    SET SECOND_NAME=%%a
)

FOR /f "skip=1 tokens=2,13 " %%a in ('IPCONFIG') do (
  if %%a==Gateway (
    SET FIRST_GW=%%b 
    GOTO CONTINUE3
  )
)

:CONTINUE3

FOR /f "skip=10 tokens=2,13 " %%a in ('IPCONFIG') do (
  if %%a==Gateway (
    SET SECOND_GW=%%b 
  )
)

REM echo FIRST_IP = %FIRST_IP%
REM echo FIRST_NAME = %FIRST_NAME%
REM echo SECOND_IP = %SECOND_IP%
REM echo SECOND_NAME = %SECOND_NAME%

FOR /f "tokens=1,5 delims=. " %%a in ('echo %FIRST_IP%%SECOND_IP%') do (
    if %%a==10 (
      if %%b==152 (
        SET INTERNAL_IP=%FIRST_IP%
        SET INTERNAL_NAME=%FIRST_NAME%
        SET INTERNAL_GW=%FIRST_GW%
        SET EXTERNAL_IP=%SECOND_IP%
        SET EXTERNAL_NAME=%SECOND_NAME%
        SET EXTERNAL_GW=%SECOND_GW%
      ) else (
        SET INTERNAL_IP=%FIRST_IP%
        SET INTERNAL_NAME=%FIRST_NAME%
        SET INTERNAL_GW=%FIRST_GW%
        SET EXTERNAL_IP=NA
        SET EXTERNAL_NAME=NA
        SET EXTERNAL_GW=NA
      )
    ) else (
      if %%a==152 (
        if %%b==10 (
          SET EXTERNAL_IP=%FIRST_IP%
          SET EXTERNAL_NAME=%FIRST_NAME%
          SET EXTERNAL_GW=%FIRST_GW%
          SET INTERNAL_IP=%SECOND_IP%
          SET INTERNAL_NAME=%SECOND_NAME%
          SET INTERNAL_GW=%SECOND_GW%
        ) else (
          SET EXTERNAL_IP=%FIRST_IP%
          SET EXTERNAL_NAME=%FIRST_NAME%
          SET EXTERNAL_GW=%FIRST_GW%
          SET INTERNAL_IP=NA
          SET INTERNAL_NAME=NA
          SET INTERNAL_GW=NA
        )
      ) else (
        SET INTERNAL_IP=NA
        SET INTERNAL_NAME=NA
        SET INTERNAL_GW=NA
        SET EXTERNAL_IP=NA
        SET EXTERNAL_NAME=NA
        SET EXTERNAL_GW=NA
      )
    )
)

REM echo INTERNAL_IP = %INTERNAL_IP%
REM echo INTERNAL_NAME = %INTERNAL_NAME%
REM echo INTERNAL_GW = %INTERNAL_GW%

REM echo EXTERNAL_IP = %EXTERNAL_IP%
REM echo EXTERNAL_NAME = %EXTERNAL_NAME%
REM echo EXTERNAL_GW = %EXTERNAL_GW%
