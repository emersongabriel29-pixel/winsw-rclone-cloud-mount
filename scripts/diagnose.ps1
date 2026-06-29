$ErrorActionPreference = "Continue"

$service = Get-Service -Name "RcloneMountService" -ErrorAction SilentlyContinue
if ($service) {
    $service | Select-Object Name, DisplayName, Status, StartType
} else {
    Write-Host "RcloneMountService service was not found."
}

$drive = Read-Host "Drive letter to check [R:]"
if ([string]::IsNullOrWhiteSpace($drive)) {
    $drive = "R:"
}

$mountPath = "$($drive.TrimEnd(':')):\"
Write-Host "Mount visible: $(Test-Path -LiteralPath $mountPath)"

$defaultServiceDir = "C:\Tools\WinSW-Rclone"
$serviceDir = Read-Host "Service folder [$defaultServiceDir]"
if ([string]::IsNullOrWhiteSpace($serviceDir)) {
    $serviceDir = $defaultServiceDir
}

$logPath = Join-Path $serviceDir "logs\RcloneService.wrapper.log"
if (Test-Path -LiteralPath $logPath) {
    Get-Content -LiteralPath $logPath -Tail 40
}
