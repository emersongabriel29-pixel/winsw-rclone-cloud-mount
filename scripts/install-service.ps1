$ErrorActionPreference = "Stop"

$serviceDir = Split-Path -Parent $PSScriptRoot
$serviceExe = Join-Path $serviceDir "RcloneService.exe"
$serviceXml = Join-Path $serviceDir "RcloneService.xml"

if (-not (Test-Path -LiteralPath $serviceExe)) {
    throw "RcloneService.exe was not found. Download WinSW and rename it to RcloneService.exe."
}

if (-not (Test-Path -LiteralPath $serviceXml)) {
    throw "RcloneService.xml was not found. Copy RcloneService.xml.example to RcloneService.xml and edit it first."
}

& $serviceExe install
& $serviceExe start

