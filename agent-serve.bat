@echo off
rem Headless opencode server for always-on use. Keeps running until closed.
rem The API key is loaded by opencode itself from .env. This script never prints it.
setlocal
cd /d "%~dp0"
if not exist ".env" (
  echo [ERROR] .env not found. Put GEMINI_API_KEY in .env. 1>&2
  exit /b 2
)
if not exist "logs" mkdir "logs" >nul 2>&1
title opencode serve (127.0.0.1:4096)
echo Serving on http://127.0.0.1:4096, logging to logs\serve.log
opencode serve --hostname 127.0.0.1 --port 4096 >> "logs\serve.log" 2>&1
