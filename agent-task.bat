@echo off
rem Unattended single-shot opencode run. No pauses, exit codes preserved.
rem Usage: agent-task.bat ["message"]  (default: run tasks\heartbeat.md)
rem Env: set OPENCODE_AUTO=1 to add --auto (dangerous, default OFF).
rem The API key is loaded by opencode itself from .env. This script never prints it.
setlocal
cd /d "%~dp0"
if not exist ".env" (
  echo [ERROR] .env not found. Put GEMINI_API_KEY in .env. 1>&2
  exit /b 2
)
if not exist "logs" mkdir "logs" >nul 2>&1
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set D=%%a%%b%%c
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set T=%%a%%b
set LOG=logs\agent-%D%-%T%.log
set MSG=%~1
if "%MSG%"=="" set MSG=tasks/heartbeat.md에 정의된 점검을 수행해줘
echo [%DATE% %TIME%] task start ^> %LOG%
if "%OPENCODE_AUTO%"=="1" (
  echo [WARN] --auto enabled. 1>&2
  opencode run --format default --title "unattended" -f tasks\heartbeat.md --auto "%MSG%" >> "%LOG%" 2>&1
) else (
  opencode run --format default --title "unattended" -f tasks\heartbeat.md "%MSG%" >> "%LOG%" 2>&1
)
set CODE=%ERRORLEVEL%
echo [%DATE% %TIME%] task exit=%CODE% ^>^> %LOG%
echo done exit=%CODE% log=%LOG%
exit /b %CODE%
