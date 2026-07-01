$ErrorActionPreference = "Continue"

function Test-WinFspInstalled {
    $service = Get-Service -Name "WinFsp.Launcher" -ErrorAction SilentlyContinue
    if ($service) {
        return $true
    }

    $uninstallRoots = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($root in $uninstallRoots) {
        if (Test-Path -LiteralPath $root) {
            $match = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
                Get-ItemProperty -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "WinFsp*" } |
                Select-Object -First 1
            if ($match) {
                return $true
            }
        }
    }

    $paths = @(
        (Join-Path ${env:ProgramFiles(x86)} "WinFsp\bin\winfsp-x64.dll"),
        (Join-Path $env:ProgramFiles "WinFsp\bin\winfsp-x64.dll")
    )

    foreach ($path in $paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            return $true
        }
    }

    return $false
}

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

Write-Host "WinFsp installed: $(Test-WinFspInstalled)"

$rcloneExe = Join-Path $serviceDir "rclone\rclone.exe"
$winswExe = Join-Path $serviceDir "RcloneService.exe"
$serviceXml = Join-Path $serviceDir "RcloneService.xml"
$logsDir = Join-Path $serviceDir "logs"

Write-Host "WinSW executable exists: $(Test-Path -LiteralPath $winswExe)"
Write-Host "rclone executable exists: $(Test-Path -LiteralPath $rcloneExe)"
Write-Host "Service XML exists: $(Test-Path -LiteralPath $serviceXml)"
Write-Host "Logs folder exists: $(Test-Path -LiteralPath $logsDir)"

$wrapperLog = Join-Path $logsDir "RcloneService.wrapper.log"
if (Test-Path -LiteralPath $wrapperLog) {
    Write-Host ""
    Write-Host "Recent wrapper log"
    Write-Host "------------------"
    Get-Content -LiteralPath $wrapperLog -Tail 40
}

$errLog = Join-Path $logsDir "RcloneService.err.log"
if (Test-Path -LiteralPath $errLog) {
    Write-Host ""
    Write-Host "Recent rclone error log"
    Write-Host "-----------------------"
    Get-Content -LiteralPath $errLog -Tail 40
}
