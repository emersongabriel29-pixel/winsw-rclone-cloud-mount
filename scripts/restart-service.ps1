$ErrorActionPreference = "Stop"

$serviceDir = Split-Path -Parent $PSScriptRoot
$serviceExe = Join-Path $serviceDir "RcloneService.exe"

if (-not (Test-Path -LiteralPath $serviceExe)) {
    throw "RcloneService.exe was not found."
}

& $serviceExe restart

