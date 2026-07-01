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

function Convert-ToServiceSuffix {
    param([Parameter(Mandatory = $true)][string]$Value)

    $clean = ($Value -replace '[^a-zA-Z0-9]', '')
    if ([string]::IsNullOrWhiteSpace($clean)) {
        return "Mount"
    }

    return (Get-Culture).TextInfo.ToTitleCase($clean.ToLowerInvariant())
}

function Test-WinFspInstalled {
    $service = Get-Service -Name "WinFsp.Launcher" -ErrorAction SilentlyContinue
    if ($service) {
        return $true
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

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Write-Host "Downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

function Expand-ZipSingleRoot {
    param(
        [Parameter(Mandatory = $true)][string]$ZipFile,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("winsw-rclone-add-mount-" + [guid]::NewGuid().ToString("N"))
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

function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$AssetPattern
    )

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "winsw-rclone-add-mount" }
    $asset = $release.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1
    if (-not $asset) {
        throw "Could not find a release asset matching '$AssetPattern' in $Repo."
    }
    return $asset.browser_download_url
}

function Get-RcloneExe {
    param([Parameter(Mandatory = $true)][string]$ServiceDir)

    $preferred = Join-Path $ServiceDir "rclone\rclone.exe"
    if (Test-Path -LiteralPath $preferred) {
        return $preferred
    }

    $existingXml = Get-ChildItem -LiteralPath $ServiceDir -Filter "*.xml" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($existingXml) {
        try {
            [xml]$xml = Get-Content -LiteralPath $existingXml.FullName
            if ($xml.service.executable -and (Test-Path -LiteralPath $xml.service.executable)) {
                return $xml.service.executable
            }
        } catch {
        }
    }

    $found = Get-ChildItem -LiteralPath $ServiceDir -Recurse -Filter "rclone.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return $found.FullName
    }

    $rcloneDir = Join-Path $ServiceDir "rclone"
    New-Item -ItemType Directory -Path $rcloneDir -Force | Out-Null
    $downloadDir = Join-Path $ServiceDir "downloads"
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    $zipPath = Join-Path $downloadDir "rclone-current-windows-amd64.zip"
    Invoke-Download -Url "https://downloads.rclone.org/rclone-current-windows-amd64.zip" -OutFile $zipPath
    Expand-ZipSingleRoot -ZipFile $zipPath -Destination $rcloneDir
    return $preferred
}

function Get-WinSWSourceExe {
    param([Parameter(Mandatory = $true)][string]$ServiceDir)

    $preferred = Join-Path $ServiceDir "RcloneService.exe"
    if (Test-Path -LiteralPath $preferred) {
        return $preferred
    }

    $existing = Get-ChildItem -LiteralPath $ServiceDir -Filter "*.exe" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Rclone*.exe" } |
        Select-Object -First 1
    if ($existing) {
        return $existing.FullName
    }

    New-Item -ItemType Directory -Path $ServiceDir -Force | Out-Null
    $winswUrl = Get-GitHubLatestAssetUrl -Repo "winsw/winsw" -AssetPattern "WinSW-x64\.exe$"
    Invoke-Download -Url $winswUrl -OutFile $preferred
    return $preferred
}

function Get-MountProfile {
    param([Parameter(Mandatory = $true)][string]$Profile)

    switch ($Profile.ToLowerInvariant()) {
        "leve" {
            return [pscustomobject]@{
                CacheMaxSize = "10G"; BufferSize = "64M"; ReadAhead = "256M"; ChunkSize = "32M"; ChunkLimit = "512M"
                Retries = 8; LowLevelRetries = 16; MultiThreadStreams = 2; Transfers = 2; Checkers = 4
                Extra = @()
            }
        }
        "pesado" {
            return [pscustomobject]@{
                CacheMaxSize = "120G"; BufferSize = "512M"; ReadAhead = "2G"; ChunkSize = "256M"; ChunkLimit = "4G"
                Retries = 15; LowLevelRetries = 30; MultiThreadStreams = 8; Transfers = 12; Checkers = 32
                Extra = @("--tpslimit 100", "--tpslimit-burst 24", "--fast-list", "--no-modtime")
            }
        }
        default {
            return [pscustomobject]@{
                CacheMaxSize = "20G"; BufferSize = "128M"; ReadAhead = "512M"; ChunkSize = "64M"; ChunkLimit = "1G"
                Retries = 10; LowLevelRetries = 20; MultiThreadStreams = 4; Transfers = 4; Checkers = 8
                Extra = @()
            }
        }
    }
}

if (-not (Test-IsAdmin)) {
    throw "Run this script as Administrator."
}

Clear-Host
Write-Host "Add Rclone Cloud Mount"
Write-Host "======================"
Write-Host ""
Write-Host "This wizard creates an additional WinSW service for another rclone remote."
Write-Host ""

$defaultServiceDir = "C:\Tools\WinSW-Rclone"
$defaultConfigPath = Join-Path $env:APPDATA "rclone\rclone.conf"

$serviceDir = Read-Default -Prompt "Service folder" -Default $defaultServiceDir
$remoteName = Read-Default -Prompt "Rclone remote name" -Default "mega"
$driveLetter = Read-Default -Prompt "Drive letter" -Default "M:"
$profileName = Read-Default -Prompt "Profile: leve, medio, pesado" -Default "medio"
$serviceSuffix = Convert-ToServiceSuffix -Value $remoteName
$serviceName = Read-Default -Prompt "Windows service name" -Default "Rclone$serviceSuffix"
$displayName = Read-Default -Prompt "Service display name" -Default "Rclone $serviceSuffix"
$cacheDir = Read-Default -Prompt "Cache folder" -Default "C:\rclone-cache-$($remoteName.ToLowerInvariant())"
$configPath = Read-Default -Prompt "Rclone config path" -Default $defaultConfigPath

$driveLetter = "$($driveLetter.TrimEnd(':')):"
$profile = Get-MountProfile -Profile $profileName

if (-not (Test-WinFspInstalled)) {
    throw "WinFsp is required before installing an rclone mount service."
}
if (Get-Service -Name $serviceName -ErrorAction SilentlyContinue) {
    throw "Service '$serviceName' already exists."
}
if (Get-PSDrive -Name $driveLetter.TrimEnd(":") -ErrorAction SilentlyContinue) {
    throw "Drive letter '$driveLetter' is already in use."
}
if (-not (Test-Path -LiteralPath $configPath)) {
    throw "rclone config was not found: $configPath"
}

New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null
New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null

$rcloneExe = Get-RcloneExe -ServiceDir $serviceDir
$sourceWinSW = Get-WinSWSourceExe -ServiceDir $serviceDir
$serviceExe = Join-Path $serviceDir "$serviceName.exe"
$serviceXml = Join-Path $serviceDir "$serviceName.xml"
$logDir = Join-Path $serviceDir "logs-$($remoteName.ToLowerInvariant())"
New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$remoteList = & $rcloneExe listremotes --config $configPath
if ($remoteList -notcontains "$remoteName`:") {
    Write-Host ""
    Write-Host "Remote '$remoteName' was not found. Opening rclone config so you can create it."
    & $rcloneExe config --config $configPath
    $remoteList = & $rcloneExe listremotes --config $configPath
}
if ($remoteList -notcontains "$remoteName`:") {
    throw "Remote '$remoteName' was not found after configuration."
}

Write-Host ""
Write-Host "Testing remote '$($remoteName):'..."
& $rcloneExe lsd "$remoteName`:" --config $configPath --max-depth 1 1>$null
if ($LASTEXITCODE -ne 0) {
    throw "Remote test failed for '$($remoteName):'."
}

Copy-Item -LiteralPath $sourceWinSW -Destination $serviceExe -Force

$args = @(
    "--config `"$configPath`"",
    "mount $remoteName`: $driveLetter",
    "--vfs-cache-mode full",
    "--cache-dir `"$cacheDir`"",
    "--vfs-cache-max-size $($profile.CacheMaxSize)",
    "--vfs-cache-max-age 7d",
    "--vfs-cache-poll-interval 30s",
    "--buffer-size $($profile.BufferSize)",
    "--vfs-read-ahead $($profile.ReadAhead)",
    "--vfs-read-chunk-size $($profile.ChunkSize)",
    "--vfs-read-chunk-size-limit $($profile.ChunkLimit)",
    "--dir-cache-time 720h",
    "--poll-interval 30s",
    "--timeout 2h",
    "--contimeout 30s",
    "--retries $($profile.Retries)",
    "--low-level-retries $($profile.LowLevelRetries)",
    "--multi-thread-streams $($profile.MultiThreadStreams)",
    "--transfers $($profile.Transfers)",
    "--checkers $($profile.Checkers)",
    "--network-mode",
    "--links",
    "--log-level ERROR"
) + $profile.Extra

$argumentLine = $args -join " "

$xml = @"
<service>
  <id>$serviceName</id>
  <name>$displayName</name>
  <description>Mounts $remoteName with rclone as drive $driveLetter using WinSW.</description>

  <executable>$rcloneExe</executable>
  <arguments>$argumentLine</arguments>

  <log mode="roll" />
  <logpath>$logDir</logpath>

  <depend>Tcpip</depend>
  <depend>Dnscache</depend>
  <depend>LanmanWorkstation</depend>

  <startmode>Automatic</startmode>
  <delayedAutoStart>true</delayedAutoStart>
</service>
"@

Set-Content -LiteralPath $serviceXml -Value $xml -Encoding UTF8

& $serviceExe install
& $serviceExe start

Start-Sleep -Seconds 8
$service = Get-Service -Name $serviceName -ErrorAction Stop
$mountPath = "$($driveLetter.TrimEnd(':')):\"

Write-Host ""
Write-Host "Result"
Write-Host "======"
Write-Host "Service: $serviceName ($($service.Status))"
Write-Host "Drive: $mountPath"
Write-Host "Mount visible: $(Test-Path -LiteralPath $mountPath)"
Write-Host "Profile: $profileName"
Write-Host "Cache: $cacheDir ($($profile.CacheMaxSize))"
Write-Host ""
Write-Host "Press Enter to close."
Read-Host | Out-Null
