@echo off
rem Run opencode from this project folder.
rem The API key is loaded by opencode itself from .env in this folder.
rem This script never contains or prints the key.
cd /d "%~dp0"
if not exist ".env" (
  echo [WARN] .env not found. Put a .env file with GEMINI_API_KEY in this folder.
  pause
)
title opencode (gemini)
opencode
