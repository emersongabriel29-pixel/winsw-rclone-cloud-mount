$ErrorActionPreference = "Continue"

function Read-Default {
    param(
        [Parameter(Mandatory = $true)][string]$Prompt,
        [Parameter(Mandatory = $true)][string]$Default
    )

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value.Trim()
}

function Write-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][bool]$Passed,
        [string]$Detail = ""
    )

    if ($Passed) {
        Write-Host "[OK]   $Name $Detail" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $Name $Detail" -ForegroundColor Red
    }
}

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

$defaultServiceDir = "C:\Tools\WinSW-Rclone"
$defaultConfigPath = Join-Path $env:APPDATA "rclone\rclone.conf"

$serviceDir = Read-Default -Prompt "Service folder" -Default $defaultServiceDir
$remoteName = Read-Default -Prompt "Rclone remote name" -Default "remote"
$driveLetter = Read-Default -Prompt "Drive letter" -Default "R:"
$configPath = Read-Default -Prompt "Rclone config path" -Default $defaultConfigPath

$winswExe = Join-Path $serviceDir "RcloneService.exe"
$rcloneExe = Join-Path $serviceDir "rclone\rclone.exe"
$serviceXml = Join-Path $serviceDir "RcloneService.xml"
$logsDir = Join-Path $serviceDir "logs"
$mountPath = "$($driveLetter.TrimEnd(':')):\"

Write-Host ""
Write-Host "WinSW Rclone Verification"
Write-Host "========================="
Write-Host ""

Write-Check -Name "Service folder" -Passed (Test-Path -LiteralPath $serviceDir) -Detail $serviceDir
Write-Check -Name "WinSW executable" -Passed (Test-Path -LiteralPath $winswExe) -Detail $winswExe
Write-Check -Name "rclone executable" -Passed (Test-Path -LiteralPath $rcloneExe) -Detail $rcloneExe
Write-Check -Name "Service XML" -Passed (Test-Path -LiteralPath $serviceXml) -Detail $serviceXml
Write-Check -Name "rclone config" -Passed (Test-Path -LiteralPath $configPath) -Detail $configPath
Write-Check -Name "Logs folder" -Passed (Test-Path -LiteralPath $logsDir) -Detail $logsDir
Write-Check -Name "WinFsp installed" -Passed (Test-WinFspInstalled) -Detail "Required for rclone mount on Windows"

if (Test-Path -LiteralPath $serviceXml) {
    [xml]$xml = Get-Content -LiteralPath $serviceXml
    $xmlExe = $xml.service.executable
    $xmlArgs = $xml.service.arguments
    Write-Check -Name "XML executable path exists" -Passed (Test-Path -LiteralPath $xmlExe) -Detail $xmlExe
    Write-Check -Name "XML references config" -Passed ($xmlArgs -like "*$configPath*") -Detail $configPath
    Write-Check -Name "XML references remote" -Passed ($xmlArgs -like "*mount $remoteName`:*") -Detail "$remoteName`:"
    Write-Check -Name "XML references drive" -Passed ($xmlArgs -like "* $($driveLetter.TrimEnd(':'))`: *" -or $xmlArgs -like "* $($driveLetter.TrimEnd(':'))`:*") -Detail $driveLetter
}

if ((Test-Path -LiteralPath $rcloneExe) -and (Test-Path -LiteralPath $configPath)) {
    $remotes = & $rcloneExe listremotes --config $configPath 2>$null
    Write-Check -Name "Remote exists" -Passed ($remotes -contains "$remoteName`:") -Detail "$remoteName`:"
    if ($remotes -contains "$remoteName`:") {
        & $rcloneExe lsd "$remoteName`:" --config $configPath --max-depth 1 1>$null 2>$null
        Write-Check -Name "Remote responds" -Passed ($LASTEXITCODE -eq 0) -Detail "$remoteName`:"
    }
}

$service = Get-Service -Name "RcloneMountService" -ErrorAction SilentlyContinue
Write-Check -Name "Windows service exists" -Passed ($null -ne $service) -Detail "RcloneMountService"
if ($service) {
    Write-Check -Name "Windows service running" -Passed ($service.Status -eq "Running") -Detail $service.Status.ToString()
}

Write-Check -Name "Drive mount visible" -Passed (Test-Path -LiteralPath $mountPath) -Detail $mountPath

$wrapperLog = Join-Path $logsDir "RcloneService.wrapper.log"
if (Test-Path -LiteralPath $wrapperLog) {
    Write-Host ""
    Write-Host "Recent wrapper log"
    Write-Host "------------------"
    Get-Content -LiteralPath $wrapperLog -Tail 20
}
