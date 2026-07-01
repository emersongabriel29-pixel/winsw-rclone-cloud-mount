# WinSW Rclone Cloud Mount Service

One-click style installer for running an rclone cloud mount as a Windows service using WinSW.

This project is a sanitized installer/template for mounting any rclone-supported remote as a Windows drive letter, with VFS cache settings suitable for general files, backups, media libraries, and other large-file workflows.

Portuguese documentation:

```text
README.pt-br.md
```

Optional emulation and ROM/game directory guide:

```text
docs\EMULACAO-E-ROMS.md
output\pdf\WinSW-Rclone-Emulation-Guide.pdf
```

## What It Does

- Opens an elevated PowerShell setup wizard.
- Downloads rclone automatically.
- Downloads WinSW automatically.
- Creates the service folder.
- Creates the VFS cache folder.
- Opens `rclone config` when no config exists yet.
- Generates `RcloneService.xml`.
- Installs and starts the Windows service.
- Installs a Windows service with WinSW.
- Starts `rclone mount` automatically on boot.
- Mounts a configured rclone remote such as `remote:` to a drive letter such as `R:`.
- Stores service logs in a local `logs` folder.
- Uses a separate VFS cache directory for better read performance.

## Security Notice

The launcher uses:

```text
PowerShell -ExecutionPolicy Bypass
```

This is used so the local setup wizard can run without requiring a permanent system-wide PowerShell policy change.

Before running any script from the internet, review the files in this repository. The installer should be run from a trusted copy of the project, and it should only request administrator access because Windows services require elevated permissions.

## Does PowerShell Stay Open?

No. PowerShell is only used during setup because the installer is interactive and may need to open `rclone config`.

After installation, the mount runs through WinSW as a Windows service. The rclone process runs in the background, and no PowerShell window needs to stay open for the drive to remain mounted.

At Windows startup, the service starts silently in the background:

```xml
<startmode>Automatic</startmode>
<delayedAutoStart>true</delayedAutoStart>
```

The Windows service does not launch a visible PowerShell or CMD window on every boot. WinSW starts `rclone.exe` directly as a service process, which is why the drive can stay mounted while you play or use the PC without a terminal window on screen.

## PowerShell Or CMD?

Both can be used as launchers, but they are used for different jobs:

- `Install-WinSW-Rclone.cmd` is a small double-click launcher.
- The setup wizard itself is PowerShell because it is better for downloading files, generating XML, checking services, and running verification.
- The fully automatic installer requires Windows PowerShell.
- After setup, neither PowerShell nor CMD is required to keep the mount alive.
- At Windows startup, WinSW starts `rclone.exe` directly and hidden as a Windows service.

CMD can start or stop the service manually:

```cmd
RcloneService.exe start
RcloneService.exe stop
RcloneService.exe restart
```

PowerShell is preferred for the installer and diagnostic scripts. CMD-only setup is possible manually if you download rclone and WinSW yourself, copy or write `RcloneService.xml`, then run `RcloneService.exe install` and `RcloneService.exe start`.

## Linux Support

This project is Windows-only for now.

Linux can run rclone mounts, but it uses different service tooling, such as systemd, instead of WinSW. Linux support is outside the current project scope and has not been tested here.

## Quick Start

Download or clone this repository, then double-click:

```text
Install-WinSW-Rclone.cmd
```

The launcher opens PowerShell as Administrator and starts the setup wizard.

The wizard asks for:

- service folder, default `C:\Tools\WinSW-Rclone`
- rclone remote name, default `remote`
- drive letter, default `R:`
- cache folder, default `C:\rclone-cache`
- cache limit, default `120G`
- rclone config path, default `%APPDATA%\rclone\rclone.conf`

The default paths are examples, not requirements. You can change them in the wizard.

If no rclone config exists yet, the wizard opens:

```powershell
rclone config
```

Create a remote with the same name you entered in the wizard.

## Installation

1. Download this repository as ZIP or clone it.
2. Extract it to any folder, for example:

```text
C:\Tools\winsw-rclone-cloud-mount
```

3. Double-click:

```text
Install-WinSW-Rclone.cmd
```

4. Allow the Administrator prompt.
5. Confirm or change the setup values:

```text
Service folder: C:\Tools\WinSW-Rclone
Remote name: remote
Drive letter: R:
Cache folder: C:\rclone-cache
Cache size: 120G
Config path: %APPDATA%\rclone\rclone.conf
```

6. If the rclone configuration screen opens, create your cloud remote.
7. Sign in or authorize the selected provider in the browser window opened by rclone, when that provider requires it.
8. Wait for the service installation to finish.
9. Confirm that the selected drive letter, such as `R:`, appears in Windows.

To verify the installation later, run:

```powershell
.\scripts\verify-config.ps1
```

## Where Do I Put My Cloud Account?

You do not paste your cloud account, password, token, or OAuth data into this project.

Provider login happens inside:

```powershell
rclone config
```

rclone opens a browser when the selected provider requires it. You sign in with that provider, and rclone saves the authorization locally in:

```text
%APPDATA%\rclone\rclone.conf
```

The Windows service XML only points to that config file. It should not contain private tokens.

For a step-by-step configuration map, read:

```text
docs\CONFIGURATION.md
```

## Folder Layout

Recommended layout:

```text
C:\Tools\WinSW-Rclone
├─ RcloneService.exe
├─ RcloneService.xml
├─ scripts
├─ logs
└─ rclone
   └─ rclone.exe
```

`RcloneService.exe` is the WinSW executable renamed to match the XML file.

## Requirements

- Windows 10 or Windows 11.
- Windows PowerShell, included by default on supported Windows versions.
- Administrator access to install/start/stop a Windows service.
- [WinFsp](https://winfsp.dev/rel/), required by `rclone mount` on Windows.
- [rclone](https://rclone.org/downloads/).
- [WinSW](https://github.com/winsw/winsw).
- A configured rclone remote, for example `remote`.

Supported providers include anything supported by rclone, such as Google Drive, OneDrive, Dropbox, MEGA, Box, pCloud, S3-compatible storage, FTP, SFTP, WebDAV, SMB, and many others.

The default mount options are tuned for large-file workflows such as media libraries, games, emulation libraries, ROM folders, backups, and other read-heavy use cases. For small documents only, the defaults may be more aggressive than necessary.

Official external links:

- rclone downloads: <https://rclone.org/downloads/>
- rclone install docs: <https://rclone.org/install/>
- rclone supported providers: <https://rclone.org/overview/>
- WinFsp downloads: <https://winfsp.dev/rel/>
- rclone GitHub releases: <https://github.com/rclone/rclone/releases>
- WinSW project: <https://github.com/winsw/winsw>
- WinSW releases: <https://github.com/winsw/winsw/releases>

## Configure Rclone

Create or edit your rclone remote:

```powershell
rclone config
```

By default, rclone stores config at:

```text
%APPDATA%\rclone\rclone.conf
```

Do not commit `rclone.conf`. It may contain OAuth tokens or other secrets.

## Automatic Install

Use:

```text
Install-WinSW-Rclone.cmd
```

Or run the wizard directly from an elevated PowerShell:

```powershell
.\scripts\setup-wizard.ps1
```

## Manager Menu

After the first setup, you can use the PowerShell manager:

```text
Manage-WinSW-Rclone.cmd
```

It opens an elevated menu for common maintenance tasks:

```text
1  - Install or reconfigure service
2  - Verify configuration
3  - Diagnose problem
4  - Start service
5  - Stop service
6  - Restart service
7  - Recreate XML / change remote, drive, or cache
8  - Edit manager settings
9  - Update rclone
10 - Update WinSW
11 - Open logs folder
12 - Remove service
0  - Exit
```

The manager stores local preferences in:

```text
settings.json
```

That file is ignored by Git because it may contain personal paths. A safe template is available at:

```text
settings.example.json
```

## Configure The Service

Copy `RcloneService.xml.example` to `RcloneService.xml`, then edit:

- `executable`: path to your `rclone.exe`.
- `--config`: path to your `rclone.conf`.
- `mount remote: R:`: change `remote` and `R:` if needed.
- `--cache-dir`: local cache location.
- `--vfs-cache-max-size`: cache size limit.

Example:

```xml
<executable>C:\Tools\WinSW-Rclone\rclone\rclone.exe</executable>
```

Paths in `RcloneService.xml.example` use `C:\Tools\...` only as a safe default example. If you choose a different service folder in the wizard, the generated `RcloneService.xml` will use your selected path.

## Manual Install

Open PowerShell as Administrator inside the service folder:

```powershell
.\RcloneService.exe install
.\RcloneService.exe start
```

Or use the helper script:

```powershell
.\scripts\install-service.ps1
```

## Full Manual Setup

Use this if you do not want to use the automatic installer.

1. Download rclone for Windows 64-bit:

```text
https://rclone.org/downloads/
```

2. Extract `rclone.exe` into:

```text
C:\Tools\WinSW-Rclone\rclone\rclone.exe
```

3. Download WinSW x64 from:

```text
https://github.com/winsw/winsw/releases
```

4. Rename the downloaded WinSW executable to:

```text
RcloneService.exe
```

5. Place it here:

```text
C:\Tools\WinSW-Rclone\RcloneService.exe
```

6. Configure your cloud remote:

```powershell
C:\Tools\WinSW-Rclone\rclone\rclone.exe config
```

Create a remote named:

```text
remote
```

7. Copy `RcloneService.xml.example` to:

```text
C:\Tools\WinSW-Rclone\RcloneService.xml
```

8. Edit paths, remote name, drive letter, and cache size if needed.

9. Install and start the service from an Administrator PowerShell:

```powershell
cd C:\Tools\WinSW-Rclone
.\RcloneService.exe install
.\RcloneService.exe start
```

10. Verify:

```powershell
.\scripts\verify-config.ps1
```

## Diagnose

Run:

```powershell
.\scripts\diagnose.ps1
```

It checks the service status, mount visibility, and recent wrapper logs.

## Verify Configuration

After install, run:

```powershell
.\scripts\verify-config.ps1
```

It verifies:

- service folder
- WinSW executable
- rclone executable
- service XML
- rclone config
- configured remote
- Windows service status
- mounted drive visibility
- recent logs

## Common Issues

### The drive letter does not appear

Run:

```powershell
.\scripts\verify-config.ps1
```

Then check whether the service is running and whether the selected drive letter is already in use.

### rclone config opens but no remote is found

Make sure the remote name created in `rclone config` exactly matches the remote name entered in the setup wizard. For example, `remote` and `remote:` refer to the same rclone remote, but the wizard asks for the name without the colon.

### The service installs but fails to start

Check:

```powershell
.\scripts\diagnose.ps1
```

Also verify that `rclone.exe`, `RcloneService.exe`, and `RcloneService.xml` exist in the selected service folder.

### The service runs but the drive does not mount

Make sure WinFsp is installed:

```text
https://winfsp.dev/rel/
```

WinFsp is required for `rclone mount` on Windows. Without it, the service may start but no drive letter will appear.

### Downloads fail

The wizard downloads rclone and WinSW from their official release locations. If the VM or network blocks downloads, download them manually from:

```text
https://rclone.org/downloads/
https://github.com/winsw/winsw/releases
```

Then follow the manual setup section.

### Cache fills the local disk

Reduce:

```text
--vfs-cache-max-size
```

or choose a cache folder on a drive with more free space.

## Manage The Service

```powershell
.\RcloneService.exe status
.\RcloneService.exe stop
.\RcloneService.exe start
.\RcloneService.exe restart
.\RcloneService.exe uninstall
```

Or use the manager menu:

```text
Manage-WinSW-Rclone.cmd
```

## Cache Size Notes

This template uses `--vfs-cache-mode full`. That gives better compatibility for applications that expect normal disk behavior, but it uses local storage.

For large files, media libraries, game directories, or other heavy read workloads, set:

```text
--vfs-cache-max-size
```

to at least the size of the largest file or game you expect to use heavily, with extra room if possible.

## Optional Emulation Guide

This project is not specific to Ryujinx, emulation, or game libraries. Those are optional use cases.

For separate guides focused on emulator folders and game directories, see:

```text
docs\EMULACAO-E-ROMS.md
output\pdf\WinSW-Rclone-Emulation-Guide.pdf
```

## Security

Never commit:

- `rclone.conf`
- OAuth tokens
- personal Windows usernames
- private drive names
- logs that contain sensitive paths or filenames
- service XML files containing personal paths

Use the `.example` files in this repository as clean templates.

## Roadmap

The current project is focused on a reliable Windows service installer and PowerShell manager.

Possible future versions:

- V3: simple Windows graphical interface.
- V4: multiple mounts, one service per remote.
- V5: polished installer, tray icon, notifications, import/export settings, and recovery tools.

These are roadmap ideas. The current release stays focused on a single stable mount with clear verification and diagnostics.
