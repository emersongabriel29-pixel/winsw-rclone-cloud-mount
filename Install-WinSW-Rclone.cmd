@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SETUP_SCRIPT=%SCRIPT_DIR%scripts\setup-wizard.ps1"

if not exist "%SETUP_SCRIPT%" (
  echo setup-wizard.ps1 was not found.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process PowerShell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%SETUP_SCRIPT%""'"

endlocal

