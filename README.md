# SYS CTRL

SYS CTRL is a Windows terminal control deck for routine system maintenance. It combines safe temporary-file cleanup, storage inspection, repair tools, application updates, and power controls in a single retro-styled console interface.

Version: 2.0.2

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Administrator approval when SYS CTRL starts
- Internet access only for GitHub update checks and WinGet updates
- WinGet for App Update Run

## Installation and launch

1. Download or clone the repository.
2. Keep `SYS CTRL.bat` and `SystemControl.ps1` in the same folder.
3. Run `SYS CTRL.bat`.
4. Approve the administrator prompt.

The batch file starts the PowerShell interface with UTF-8 support, allowing the terminal artwork to display correctly.

## Included modules

| Module | Purpose |
| --- | --- |
| Cache Sweep | Removes safe temporary files, Windows Update download data, Delivery Optimization data, and application caches while leaving locked files and active browser caches alone. |
| Space Hunter | Lists larger user-profile locations to help identify where storage is being used. |
| Regen Watch | Records cleanup results and identifies cache growth since the previous sweep. |
| Windows Repair | Runs DISM RestoreHealth followed by SFC /scannow. |
| App Update Run | Lists available WinGet upgrades and asks for `Y` or `N` before running the standard WinGet update command. |
| After Action Report | Displays recent SYS CTRL activity. |
| Power Control | Opens Slide to Shut Down or requests a restart to BIOS / UEFI. |

## Updates

SYS CTRL checks the latest [SYS CTRL version tag](https://github.com/SuCH-CHAoS/SYS-CTRL/tags) during its boot sequence. Versions use tags in the form `v2.0.0`. When a newer version is found, the header displays the available version. The check does not download or install updates automatically.

## Release process

1. Update the application version in `SystemControl.ps1`.
2. Commit the release changes.
3. Create and push a matching Git tag, such as `v2.0.0`.
4. Optionally create a GitHub Release from that tag and attach a ZIP archive containing both launch files.

## Safety notes

Cache Sweep targets temporary data and commonly regenerated caches. Files that Windows or another application has locked are skipped. Windows Repair and App Update Run use Microsoft servicing tools and WinGet, so their runtime depends on the condition of the local system and available network sources.

## Copyright

Copyright (c) 2026 SuCH CHAoS. All rights reserved.

You may download and run an unmodified copy for personal evaluation. No permission is granted to copy, modify, redistribute, or use this software beyond that purpose without prior written permission from the copyright holder.
