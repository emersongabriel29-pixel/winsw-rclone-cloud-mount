$ErrorActionPreference = "Stop"

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
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

function Convert-SizeToBytes {
    param([Parameter(Mandatory = $true)][string]$Size)

    if ($Size -notmatch '^\s*(\d+(?:\.\d+)?)\s*([KMGT]?)(?:i?B?)?\s*$') {
        return $null
    }

    $number = [double]$matches[1]
    $unit = $matches[2].ToUpperInvariant()
    $multiplier = switch ($unit) {
        "T" { 1TB }
        "G" { 1GB }
        "M" { 1MB }
        "K" { 1KB }
        default { 1 }
    }

    return [int64]($number * $multiplier)
}

function Test-DriveLetterInUse {
    param([Parameter(Mandatory = $true)][string]$DriveLetter)

    $name = $DriveLetter.TrimEnd(":")
    return [bool](Get-PSDrive -Name $name -ErrorAction SilentlyContinue)
}

function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$AssetPattern
    )

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "winsw-rclone-service-installer" }
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find a release asset matching '$AssetPattern' in $Repo."
    }
    return $asset.browser_download_url
}

function Expand-ZipSingleRoot {
    param(
        [Parameter(Mandatory = $true)][string]$ZipFile,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("winsw-rclone-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempDir | Out-Null

    try {
        Expand-Archive -LiteralPath $ZipFile -DestinationPath $tempDir -Force
        $children = Get-ChildItem -LiteralPath $tempDir -Force
        if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
            Copy-Item -Path (Join-Path $children[0].FullName "*") -Destination $Destination -Recurse -Force
        } else {
            Copy-Item -Path (Join-Path $tempDir "*") -Destination $Destination -Recurse -Force
        }
    } finally {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Write-ServiceXml {
    param(
        [Parameter(Mandatory = $true)][string]$ServiceDir,
        [Parameter(Mandatory = $true)][string]$RcloneExe,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$RemoteName,
        [Parameter(Mandatory = $true)][string]$DriveLetter,
        [Parameter(Mandatory = $true)][string]$CacheDir,
        [Parameter(Mandatory = $true)][string]$CacheMaxSize
    )

    $logDir = Join-Path $ServiceDir "logs"
    $xmlPath = Join-Path $ServiceDir "RcloneService.xml"
    if (Test-Path -LiteralPath $xmlPath) {
        $backupPath = "$xmlPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $xmlPath -Destination $backupPath -Force
        Write-Host "Existing service XML backed up to:"
        Write-Host $backupPath
    }

    $mountTarget = "$($DriveLetter.TrimEnd(':')):"
    $args = @(
        "--config `"$ConfigPath`"",
        "mount $RemoteName`: $mountTarget",
        "--vfs-cache-mode full",
        "--cache-dir `"$CacheDir`"",
        "--vfs-cache-max-size $CacheMaxSize",
        "--vfs-cache-max-age 7d",
        "--vfs-cache-poll-interval 30s",
        "--buffer-size 512M",
        "--vfs-read-ahead 2G",
        "--vfs-read-chunk-size 256M",
        "--vfs-read-chunk-size-limit 4G",
        "--dir-cache-time 720h",
        "--poll-interval 30s",
        "--timeout 2h",
        "--contimeout 30s",
        "--retries 15",
        "--low-level-retries 30",
        "--multi-thread-streams 8",
        "--transfers 12",
        "--checkers 32",
        "--tpslimit 100",
        "--tpslimit-burst 24",
        "--fast-list",
        "--no-modtime",
        "--network-mode",
        "--links",
        "--log-level ERROR"
    ) -join " "

    $xml = @"
<service>
  <id>RcloneMountService</id>
  <name>Rclone Cloud Mount</name>
  <description>Mounts an rclone cloud remote as a Windows drive.</description>

  <executable>$RcloneExe</executable>
  <arguments>$args</arguments>

  <log mode="roll" />
  <logpath>$logDir</logpath>

  <depend>Tcpip</depend>
  <depend>Dnscache</depend>
  <depend>LanmanWorkstation</depend>

  <startmode>Automatic</startmode>
  <delayedAutoStart>true</delayedAutoStart>
</service>
"@

    Set-Content -LiteralPath $xmlPath -Value $xml -Encoding UTF8
    return $xmlPath
}

if (-not (Test-IsAdmin)) {
    throw "Run this installer as Administrator."
}

Clear-Host
Write-Host "WinSW Rclone Service Setup"
Write-Host "=========================="
Write-Host ""
Write-Host "This wizard will download rclone and WinSW, configure a Windows service, and mount your remote as a drive."
Write-Host ""

$defaultServiceDir = "C:\Tools\WinSW-Rclone"
$defaultCacheDir = "C:\rclone-cache"
$defaultConfigPath = Join-Path $env:APPDATA "rclone\rclone.conf"

$serviceDir = Read-Default -Prompt "Service folder" -Default $defaultServiceDir
$remoteName = Read-Default -Prompt "Rclone remote name" -Default "remote"
$driveLetter = Read-Default -Prompt "Drive letter" -Default "R:"
$cacheDir = Read-Default -Prompt "Cache folder" -Default $defaultCacheDir
$cacheMaxSize = Read-Default -Prompt "Maximum cache size" -Default "120G"
$configPath = Read-Default -Prompt "Rclone config path" -Default $defaultConfigPath

if (-not (Test-WinFspInstalled)) {
    Write-Host ""
    Write-Host "WinFsp was not detected. rclone mount on Windows requires WinFsp."
    Write-Host "Install WinFsp from: https://winfsp.dev/rel/"
    throw "WinFsp is required before installing the rclone mount service."
}

$existingService = Get-Service -Name "RcloneMountService" -ErrorAction SilentlyContinue
if ((Test-DriveLetterInUse -DriveLetter $driveLetter) -and -not $existingService) {
    throw "Drive letter '$driveLetter' is already in use. Choose another drive letter."
}

New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $serviceDir "logs") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $serviceDir "rclone") -Force | Out-Null
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

$cacheLimitBytes = Convert-SizeToBytes -Size $cacheMaxSize
$cacheRoot = [IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $cacheDir).Path)
if ($cacheLimitBytes -and $cacheRoot) {
    $cacheDrive = Get-PSDrive -Name $cacheRoot.TrimEnd(":\") -ErrorAction SilentlyContinue
    if ($cacheDrive -and $cacheDrive.Free -lt $cacheLimitBytes) {
        Write-Host ""
        Write-Host "Warning: cache drive free space is lower than the requested cache limit."
        Write-Host "Free: $([math]::Round($cacheDrive.Free / 1GB, 2)) GB"
        Write-Host "Requested cache limit: $cacheMaxSize"
        $continue = Read-Host "Continue anyway? [y/N]"
        if ($continue -notin @("y", "Y", "yes", "YES")) {
            throw "Installation canceled because cache free space is too low."
        }
    }
}

$downloadDir = Join-Path $serviceDir "downloads"
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

$rcloneExe = Join-Path $serviceDir "rclone\rclone.exe"
$winswExe = Join-Path $serviceDir "RcloneService.exe"

if (-not (Test-Path -LiteralPath $rcloneExe)) {
    $rcloneZip = Join-Path $downloadDir "rclone-windows-amd64.zip"
    $rcloneUrl = "https://downloads.rclone.org/rclone-current-windows-amd64.zip"
    Invoke-Download -Url $rcloneUrl -OutFile $rcloneZip
    Expand-ZipSingleRoot -ZipFile $rcloneZip -Destination (Join-Path $serviceDir "rclone")
}

if (-not (Test-Path -LiteralPath $winswExe)) {
    $winswUrl = Get-GitHubLatestAssetUrl -Repo "winsw/winsw" -AssetPattern "WinSW-x64\.exe$"
    Invoke-Download -Url $winswUrl -OutFile $winswExe
}

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Host ""
    Write-Host "No rclone config was found at:"
    Write-Host $configPath
    Write-Host ""
    Write-Host "The rclone config wizard will open now. Create a remote named '$remoteName'."
    Write-Host "You can choose any backend supported by rclone, such as Google Drive, OneDrive, Dropbox, MEGA, S3, FTP, or others."
    Write-Host ""
    & $rcloneExe config --config $configPath
}

$remoteList = & $rcloneExe listremotes --config $configPath
if ($remoteList -notcontains "$remoteName`:") {
    Write-Host ""
    Write-Host "Remote '$remoteName' was not found in the config."
    Write-Host "Opening rclone config again so you can create or rename it."
    & $rcloneExe config --config $configPath
}

Write-Host ""
Write-Host "Testing remote '$($remoteName):' before service installation..."
& $rcloneExe lsd "$remoteName`:" --config $configPath --max-depth 1 1>$null
if ($LASTEXITCODE -ne 0) {
    throw "Remote test failed for '$($remoteName):'. Check the rclone config before installing the service."
}

$xmlPath = Write-ServiceXml `
    -ServiceDir $serviceDir `
    -RcloneExe $rcloneExe `
    -ConfigPath $configPath `
    -RemoteName $remoteName `
    -DriveLetter $driveLetter `
    -CacheDir $cacheDir `
    -CacheMaxSize $cacheMaxSize

Write-Host ""
Write-Host "Generated service config:"
Write-Host $xmlPath

if ($existingService) {
    Write-Host "Existing service found. Restarting it with the new configuration."
    & $winswExe stop
    & $winswExe uninstall
}

& $winswExe install
& $winswExe start

Start-Sleep -Seconds 5
$service = Get-Service -Name "RcloneMountService" -ErrorAction SilentlyContinue
$mountPath = "$($driveLetter.TrimEnd(':')):\"

Write-Host ""
Write-Host "Result"
Write-Host "======"
Write-Host "Service: $($service.Status)"
Write-Host "Mount path: $mountPath"
Write-Host "Mount visible: $(Test-Path -LiteralPath $mountPath)"
Write-Host ""
Write-Host "For a full verification, run:"
Write-Host ".\scripts\verify-config.ps1"
Write-Host ""
Write-Host "Press Enter to close."
Read-Host | Out-Null
