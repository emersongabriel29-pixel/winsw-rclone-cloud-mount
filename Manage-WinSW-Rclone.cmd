@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "MANAGER=%SCRIPT_DIR%scripts\manager.ps1"

if not exist "%MANAGER%" (
  echo Could not find "%MANAGER%".
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%MANAGER%""'"
