$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SettingsPath = Join-Path $ProjectRoot "settings.json"

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

function Resolve-EnvPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [Environment]::ExpandEnvironmentVariables($Path)
}

function Get-DefaultSettings {
    return [pscustomobject]@{
        ServiceDir = "C:\Tools\WinSW-Rclone"
        ServiceName = "RcloneMountService"
        RemoteName = "remote"
        DriveLetter = "R:"
        CacheDir = "C:\rclone-cache"
        CacheMaxSize = "120G"
        ConfigPath = "%APPDATA%\rclone\rclone.conf"
    }
}

function Get-Settings {
    $defaults = Get-DefaultSettings
    if (-not (Test-Path -LiteralPath $SettingsPath)) {
        Save-Settings -Settings $defaults
        return $defaults
    }

    $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json
    foreach ($property in $defaults.PSObject.Properties.Name) {
        if (-not $settings.PSObject.Properties[$property] -or [string]::IsNullOrWhiteSpace([string]$settings.$property)) {
            $settings | Add-Member -NotePropertyName $property -NotePropertyValue $defaults.$property -Force
        }
    }
    return $settings
}

function Save-Settings {
    param([Parameter(Mandatory = $true)]$Settings)
    $Settings | ConvertTo-Json | Set-Content -LiteralPath $SettingsPath -Encoding UTF8
}

function Get-ServiceExe {
    param([Parameter(Mandatory = $true)]$Settings)
    return Join-Path $Settings.ServiceDir "RcloneService.exe"
}

function Get-RcloneExe {
    param([Parameter(Mandatory = $true)]$Settings)

    $defaultPath = Join-Path $Settings.ServiceDir "rclone\rclone.exe"
    if (Test-Path -LiteralPath $defaultPath) {
        return $defaultPath
    }

    $serviceXml = Join-Path $Settings.ServiceDir "RcloneService.xml"
    if (Test-Path -LiteralPath $serviceXml) {
        try {
            [xml]$xml = Get-Content -LiteralPath $serviceXml
            if ($xml.service.executable -and (Test-Path -LiteralPath $xml.service.executable)) {
                return $xml.service.executable
            }
        } catch {
            Write-Host "Warning: could not read rclone path from service XML."
        }
    }

    $matches = Get-ChildItem -LiteralPath $Settings.ServiceDir -Recurse -Filter "rclone.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($matches) {
        return $matches.FullName
    }

    return $defaultPath
}

function Invoke-ServiceExe {
    param(
        [Parameter(Mandatory = $true)]$Settings,
        [Parameter(Mandatory = $true)][string]$Action
    )

    $serviceExe = Get-ServiceExe -Settings $Settings
    if (Test-Path -LiteralPath $serviceExe) {
        & $serviceExe $Action
        return
    }

    switch ($Action) {
        "start" { Start-Service -Name $Settings.ServiceName }
        "stop" { Stop-Service -Name $Settings.ServiceName }
        "restart" { Restart-Service -Name $Settings.ServiceName }
        "status" { Get-Service -Name $Settings.ServiceName | Select-Object Name, DisplayName, Status, StartType }
        default { throw "RcloneService.exe was not found at '$serviceExe'." }
    }
}

function Stop-ManagedService {
    param([Parameter(Mandatory = $true)]$Settings)

    $service = Get-Service -Name $Settings.ServiceName -ErrorAction SilentlyContinue
    if ($service -and $service.Status -eq "Running") {
        Invoke-ServiceExe -Settings $Settings -Action "stop"
        Start-Sleep -Seconds 2
        return $true
    }
    return $false
}

function Invoke-ProjectScript {
    param([Parameter(Mandatory = $true)][string]$ScriptName)

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Script not found: $scriptPath"
    }

    & $scriptPath
}

function Get-GitHubLatestAssetUrl {
    param(
        [Parameter(Mandatory = $true)][string]$Repo,
        [Parameter(Mandatory = $true)][string]$AssetPattern
    )

    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "winsw-rclone-manager" }
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

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("winsw-rclone-manager-" + [guid]::NewGuid().ToString("N"))
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

function Update-Rclone {
    param([Parameter(Mandatory = $true)]$Settings)

    $wasRunning = Stop-ManagedService -Settings $Settings
    $currentRcloneExe = Get-RcloneExe -Settings $Settings
    $rcloneDir = Split-Path -Parent $currentRcloneExe
    $rcloneExe = Join-Path $rcloneDir "rclone.exe"
    $downloadDir = Join-Path $Settings.ServiceDir "downloads"
    New-Item -ItemType Directory -Path $rcloneDir -Force | Out-Null
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

    if (Test-Path -LiteralPath $rcloneExe) {
        Copy-Item -LiteralPath $rcloneExe -Destination "$rcloneExe.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    }

    $zipPath = Join-Path $downloadDir "rclone-current-windows-amd64.zip"
    Invoke-WebRequest -Uri "https://downloads.rclone.org/rclone-current-windows-amd64.zip" -OutFile $zipPath -UseBasicParsing
    Expand-ZipSingleRoot -ZipFile $zipPath -Destination $rcloneDir
    & $rcloneExe version

    if ($wasRunning) {
        Invoke-ServiceExe -Settings $Settings -Action "start"
    }
}

function Update-WinSW {
    param([Parameter(Mandatory = $true)]$Settings)

    $wasRunning = Stop-ManagedService -Settings $Settings
    $serviceExe = Get-ServiceExe -Settings $Settings
    New-Item -ItemType Directory -Path $Settings.ServiceDir -Force | Out-Null

    if (Test-Path -LiteralPath $serviceExe) {
        Copy-Item -LiteralPath $serviceExe -Destination "$serviceExe.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
    }

    $winswUrl = Get-GitHubLatestAssetUrl -Repo "winsw/winsw" -AssetPattern "WinSW-x64\.exe$"
    Invoke-WebRequest -Uri $winswUrl -OutFile $serviceExe -UseBasicParsing
    Write-Host "WinSW updated at $serviceExe"

    if ($wasRunning) {
        Invoke-ServiceExe -Settings $Settings -Action "start"
    }
}

function Edit-Settings {
    $settings = Get-Settings
    $settings.ServiceDir = Read-Default -Prompt "Service folder" -Default $settings.ServiceDir
    $settings.ServiceName = Read-Default -Prompt "Windows service name" -Default $settings.ServiceName
    $settings.RemoteName = Read-Default -Prompt "Rclone remote name" -Default $settings.RemoteName
    $settings.DriveLetter = Read-Default -Prompt "Drive letter" -Default $settings.DriveLetter
    $settings.CacheDir = Read-Default -Prompt "Cache folder" -Default $settings.CacheDir
    $settings.CacheMaxSize = Read-Default -Prompt "Maximum cache size" -Default $settings.CacheMaxSize
    $settings.ConfigPath = Read-Default -Prompt "Rclone config path" -Default $settings.ConfigPath
    Save-Settings -Settings $settings
    Write-Host "Settings saved to $SettingsPath"
}

function Show-Status {
    param([Parameter(Mandatory = $true)]$Settings)

    $service = Get-Service -Name $Settings.ServiceName -ErrorAction SilentlyContinue
    $mountPath = "$($Settings.DriveLetter.TrimEnd(':')):\"
    $rcloneExe = Get-RcloneExe -Settings $Settings
    $winswExe = Get-ServiceExe -Settings $Settings
    $serviceXml = Join-Path $Settings.ServiceDir "RcloneService.xml"

    Write-Host ""
    Write-Host "Current settings"
    Write-Host "----------------"
    Write-Host "Service folder: $($Settings.ServiceDir)"
    Write-Host "Service name:   $($Settings.ServiceName)"
    Write-Host "Remote:         $($Settings.RemoteName):"
    Write-Host "Drive:          $($Settings.DriveLetter)"
    Write-Host "Cache:          $($Settings.CacheDir)"
    Write-Host "Cache max:      $($Settings.CacheMaxSize)"
    Write-Host "Config:         $(Resolve-EnvPath -Path $Settings.ConfigPath)"
    Write-Host ""
    Write-Host "Detected state"
    Write-Host "--------------"
    Write-Host "Service:        $(if ($service) { $service.Status } else { 'Not installed' })"
    Write-Host "Mount visible:  $(Test-Path -LiteralPath $mountPath) ($mountPath)"
    Write-Host "rclone.exe:     $(Test-Path -LiteralPath $rcloneExe)"
    Write-Host "rclone path:    $rcloneExe"
    Write-Host "WinSW exe:      $(Test-Path -LiteralPath $winswExe)"
    Write-Host "Service XML:    $(Test-Path -LiteralPath $serviceXml)"
}

function Open-Logs {
    param([Parameter(Mandatory = $true)]$Settings)

    $logsDir = Join-Path $Settings.ServiceDir "logs"
    if (-not (Test-Path -LiteralPath $logsDir)) {
        Write-Host "Logs folder not found: $logsDir"
        return
    }
    Start-Process explorer.exe $logsDir
}

function Show-Menu {
    Clear-Host
    $settings = Get-Settings
    Show-Status -Settings $settings
    Write-Host ""
    Write-Host "WinSW Rclone Cloud Mount Manager"
    Write-Host "================================"
    Write-Host "1  - Install or reconfigure service"
    Write-Host "2  - Verify configuration"
    Write-Host "3  - Diagnose problem"
    Write-Host "4  - Start service"
    Write-Host "5  - Stop service"
    Write-Host "6  - Restart service"
    Write-Host "7  - Recreate XML / change remote, drive, or cache"
    Write-Host "8  - Edit manager settings"
    Write-Host "9  - Update rclone"
    Write-Host "10 - Update WinSW"
    Write-Host "11 - Open logs folder"
    Write-Host "12 - Remove service"
    Write-Host "0  - Exit"
    Write-Host ""
    return Read-Host "Choose an option"
}

if (-not (Test-IsAdmin)) {
    Write-Host "Warning: service actions usually require Administrator permissions." -ForegroundColor Yellow
    Write-Host "Use Manage-WinSW-Rclone.cmd for the elevated launcher."
    Write-Host ""
}

do {
    $choice = Show-Menu
    $settings = Get-Settings
    try {
        switch ($choice) {
            "1" { Invoke-ProjectScript -ScriptName "setup-wizard.ps1" }
            "2" { Invoke-ProjectScript -ScriptName "verify-config.ps1" }
            "3" { Invoke-ProjectScript -ScriptName "diagnose.ps1" }
            "4" { Invoke-ServiceExe -Settings $settings -Action "start" }
            "5" { Invoke-ServiceExe -Settings $settings -Action "stop" }
            "6" { Invoke-ServiceExe -Settings $settings -Action "restart" }
            "7" { Invoke-ProjectScript -ScriptName "setup-wizard.ps1" }
            "8" { Edit-Settings }
            "9" { Update-Rclone -Settings $settings }
            "10" { Update-WinSW -Settings $settings }
            "11" { Open-Logs -Settings $settings }
            "12" { Invoke-ServiceExe -Settings $settings -Action "stop"; Invoke-ServiceExe -Settings $settings -Action "uninstall" }
            "0" { break }
            default { Write-Host "Unknown option." }
        }
    } catch {
        Write-Host ""
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }

    if ($choice -ne "0") {
        Write-Host ""
        Read-Host "Press Enter to return to the menu" | Out-Null
    }
} while ($choice -ne "0")
