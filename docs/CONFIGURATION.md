# Configuration Guide

This project does not ask anyone to paste Google tokens, passwords, or private account data into the service XML.

The Google account is connected through the official `rclone config` login flow. rclone opens a browser, the user signs in to Google, and rclone stores the OAuth token in the local `rclone.conf`.

## Where Each Setting Goes

| Setting | Where It Is Configured | Example |
| --- | --- | --- |
| Cloud account | `rclone config` provider login | Sign in with Google, Microsoft, Dropbox, MEGA, or another provider |
| rclone remote name | setup wizard and `rclone config` | `remote` |
| Windows service folder | setup wizard | `C:\Tools\WinSW-Rclone` |
| rclone config path | setup wizard | `%APPDATA%\rclone\rclone.conf` |
| drive letter | setup wizard | `R:` |
| cache folder | setup wizard | `C:\rclone-cache` |
| cache size | setup wizard | `120G`, `200G`, `300G` |
| manager settings | local `settings.json` | copied from `settings.example.json` |

This setup is generic. It can be used for documents, backups, media, project files, large archives, or game libraries. Emulation-specific guidance is kept in a separate PDF so the main installer is not tied to any emulator.

## Quick Install

For the automatic install, download or clone the repository and run:

```text
Install-WinSW-Rclone.cmd
```

The launcher opens the PowerShell setup wizard as Administrator. The wizard downloads rclone and WinSW, checks WinFsp, asks for the remote, drive letter and cache settings, generates `RcloneService.xml`, installs the service, and starts the mount.

After the first setup, use the manager menu for maintenance:

```text
Manage-WinSW-Rclone.cmd
```

The manager can verify the configuration, diagnose problems, start, stop or restart the service, update rclone or WinSW, open logs, edit local manager settings, add another cloud mount, and remove the service.

To add another cloud as another drive, choose:

```text
2 - Add another cloud mount
```

That wizard creates a separate WinSW service and XML file. For example:

```text
gdrive: -> R: through RcloneGDrive
mega:   -> M: through RcloneMega
```

It supports three mount profiles:

```text
leve   - lower RAM and disk usage
medio  - balanced profile
pesado - larger cache and more aggressive read settings
```

The manager stores local preferences in:

```text
settings.json
```

That file is intentionally ignored by Git because it can contain personal paths. Use `settings.example.json` as the public template.

## Windows Mount Requirement

`rclone mount` on Windows requires WinFsp.

Install it from:

```text
https://winfsp.dev/rel/
```

The setup wizard checks for WinFsp before installing the service. If WinFsp is missing, the installer stops with a clear message instead of creating a service that cannot mount a drive.

## Cloud Account Setup

When the wizard asks for the remote name, choose a simple name such as:

```text
remote
```

If there is no rclone config yet, the wizard opens:

```powershell
rclone config
```

Use this flow:

```text
n) New remote
name> remote
Storage> choose your provider
client_id> leave blank unless your provider setup requires your own
client_secret> leave blank unless your provider setup requires your own
advanced config> usually no
auto config> usually yes for browser-based providers
```

Then sign in or authorize the selected provider in the browser window that opens, if rclone asks for browser authorization.

For Google Drive Shared Drives, rclone may ask if you want to configure a Team Drive. Choose the Shared Drive only if that is what you want to mount.

Supported providers include anything supported by rclone, such as Google Drive, OneDrive, Dropbox, MEGA, Box, pCloud, S3-compatible storage, FTP, SFTP, WebDAV, SMB, and many others.

## Manual Download Links

Use the automatic installer if you want the easiest setup. Use these official links if you want to download and place each tool manually:

- rclone downloads: <https://rclone.org/downloads/>
- rclone install docs: <https://rclone.org/install/>
- rclone supported providers: <https://rclone.org/overview/>
- rclone GitHub releases: <https://github.com/rclone/rclone/releases>
- WinSW project: <https://github.com/winsw/winsw>
- WinSW releases: <https://github.com/winsw/winsw/releases>

## Manual Setup

1. Create the service folder:

```text
C:\Tools\WinSW-Rclone
```

2. Create the rclone folder:

```text
C:\Tools\WinSW-Rclone\rclone
```

3. Download rclone for Windows 64-bit and place `rclone.exe` here:

```text
C:\Tools\WinSW-Rclone\rclone\rclone.exe
```

4. Download WinSW x64, rename it to `RcloneService.exe`, and place it here:

```text
C:\Tools\WinSW-Rclone\RcloneService.exe
```

5. Configure the cloud remote:

```powershell
C:\Tools\WinSW-Rclone\rclone\rclone.exe config
```

6. Copy `RcloneService.xml.example` to:

```text
C:\Tools\WinSW-Rclone\RcloneService.xml
```

7. Edit `RcloneService.xml` if you use a different:

- service folder
- rclone config path
- remote name
- drive letter
- cache folder
- cache size

8. Install and start the service from an Administrator PowerShell:

```powershell
cd C:\Tools\WinSW-Rclone
.\RcloneService.exe install
.\RcloneService.exe start
```

9. Verify the setup:

```powershell
.\scripts\verify-config.ps1
```

## Windows User Notes

The default config path:

```text
%APPDATA%\rclone\rclone.conf
```

belongs to the Windows user running the setup wizard.

If the service later runs under a different Windows account, it may not see the same `%APPDATA%`. The generated XML stores the expanded absolute path to avoid ambiguity.

## Manager Checklist

After installing, run:

```text
Manage-WinSW-Rclone.cmd
```

Then use:

```text
2  - Add another cloud mount
3  - Verify configuration
4  - Diagnose problem
12 - Open logs folder
```

Use start, stop and restart only when you intentionally want to change the service state.

## Verification Checklist

After setup, verify:

```powershell
.\scripts\verify-config.ps1
```

The verification checks:

- service folder exists
- `RcloneService.exe` exists
- `rclone.exe` exists
- WinFsp is installed
- `RcloneService.xml` exists
- `rclone.conf` exists
- selected remote exists in `rclone.conf`
- selected remote responds to `rclone lsd`
- cache folder exists
- Windows service exists
- Windows service is running
- drive letter is visible
- recent logs are available

## Hidden Startup Behavior

The setup wizard uses PowerShell only during installation and verification.

After installation, Windows starts the mount through WinSW:

```xml
<startmode>Automatic</startmode>
<delayedAutoStart>true</delayedAutoStart>
```

WinSW starts `rclone.exe` directly as a Windows service. It does not need a visible PowerShell or CMD window at startup.

## Platform Scope

This project targets Windows only.

The automatic installer depends on Windows PowerShell and WinSW. Linux rclone mounts are possible, but they should use Linux-native service tooling such as systemd. Linux support is not included or tested in this project.

## Files That Must Not Be Published

Never publish:

```text
rclone.conf
RcloneService.xml
settings.json
logs
downloads
rclone binaries
```

Publish only templates and scripts.
