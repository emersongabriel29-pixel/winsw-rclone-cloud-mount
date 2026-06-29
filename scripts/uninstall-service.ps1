$ErrorActionPreference = "Stop"

$serviceDir = Split-Path -Parent $PSScriptRoot
$serviceExe = Join-Path $serviceDir "RcloneService.exe"

if (-not (Test-Path -LiteralPath $serviceExe)) {
    throw "RcloneService.exe was not found."
}

& $serviceExe stop
if ($LASTEXITCODE -ne 0) {
    Write-Host "Service may already be stopped. Continuing uninstall."
}
& $serviceExe uninstall
