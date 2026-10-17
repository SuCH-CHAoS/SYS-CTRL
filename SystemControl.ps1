$ErrorActionPreference = 'SilentlyContinue'

$script:AppName = 'SYS CTRL v2.0'
$script:AppVersion = [version]'2.0.0'
$script:Author = 'Made By SuCH CHAoS'
$script:GitHubRepository = 'SuCH-CHAoS/SYS-CTRL'
$script:UpdateStatus = $null
$script:DataDirectory = Join-Path $env:LOCALAPPDATA 'SYS CTRL v2.0'
$script:ActivityPath = Join-Path $script:DataDirectory 'activity.jsonl'
$script:RegenPath = Join-Path $script:DataDirectory 'regen-watch.json'
$script:LockLimit = 15

function Initialize-SysCtrlStorage {
    if (-not (Test-Path -LiteralPath $script:DataDirectory)) {
        New-Item -ItemType Directory -Path $script:DataDirectory -Force | Out-Null
    }
}

function Format-Bytes {
    param([long]$Bytes)

    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N1} KB' -f ($Bytes / 1KB)) }
    return ('{0} B' -f $Bytes)
}

function Get-SystemDrive {
    $driveName = $env:SystemDrive -replace '[:\\]', ''
    return Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
}

function Get-GitHubRepository {
    return $script:GitHubRepository
}

function Get-GitHubUpdateStatus {
    $repository = Get-GitHubRepository
    if ([string]::IsNullOrWhiteSpace($repository)) {
        return [pscustomobject]@{
            State = 'NotConfigured'
            Text = 'UPDATE CHECK: REPOSITORY NOT CONFIGURED'
            Color = [ConsoleColor]::DarkGray
            Url = $null
        }
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $headers = @{
            'Accept' = 'application/vnd.github+json'
            'User-Agent' = ('SYS-CTRL/{0}' -f $script:AppVersion)
        }
        $tags = Invoke-RestMethod -Uri ('https://api.github.com/repos/{0}/tags?per_page=100' -f $repository) -Headers $headers -TimeoutSec 4 -ErrorAction Stop
        $availableVersions = foreach ($tagRecord in @($tags)) {
            $tag = [string]$tagRecord.name
            $versionText = ($tag -replace '^[vV]', '') -replace '[^0-9.].*$', ''

            try {
                [pscustomobject]@{
                    Version = [version]$versionText
                    Tag = $tag
                    Url = ('https://github.com/{0}/tree/{1}' -f $repository, $tag)
                }
            } catch { }
        }

        $latest = $availableVersions | Sort-Object -Property Version -Descending | Select-Object -First 1
        if ($null -eq $latest) {
            throw 'No version tags are available.'
        }

        $latestVersion = $latest.Version

        if ($latestVersion -gt $script:AppVersion) {
            return [pscustomobject]@{
                State = 'UpdateAvailable'
                Text = ('UPDATE AVAILABLE: v{0}' -f $latestVersion)
                Color = [ConsoleColor]::Yellow
                Url = $latest.Url
            }
        }

        return [pscustomobject]@{
            State = 'Current'
            Text = ('UPDATE CHECK: v{0} IS CURRENT' -f $script:AppVersion)
            Color = [ConsoleColor]::DarkCyan
            Url = $latest.Url
        }
    } catch {
        return [pscustomobject]@{
            State = 'Unavailable'
            Text = 'UPDATE CHECK: GITHUB UNAVAILABLE'
            Color = [ConsoleColor]::DarkGray
            Url = $null
        }
    }
}

function Initialize-GitHubUpdateStatus {
    $script:UpdateStatus = Get-GitHubUpdateStatus
}

function Initialize-TerminalTheme {
    try {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        $Host.UI.RawUI.ForegroundColor = 'Gray'
        Clear-Host
    } catch { }
}

function Set-ConsoleFont {
    param([int16]$Height = 20)

    if ($env:WT_SESSION) { return }

    try {
        if (-not ('SysCtrl.ConsoleFont' -as [type])) {
            $source = @'
using System;
using System.Runtime.InteropServices;

namespace SysCtrl {
    public static class ConsoleFont {
        [StructLayout(LayoutKind.Sequential)]
        struct COORD {
            public short X;
            public short Y;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct CONSOLE_FONT_INFOEX {
            public uint cbSize;
            public uint nFont;
            public COORD dwFontSize;
            public uint FontFamily;
            public uint FontWeight;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string FaceName;
        }

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX info);
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFOEX info);

        public static void SetHeight(short height) {
            IntPtr handle = GetStdHandle(-11);
            CONSOLE_FONT_INFOEX info = new CONSOLE_FONT_INFOEX();
            info.cbSize = (uint)Marshal.SizeOf(typeof(CONSOLE_FONT_INFOEX));
            if (!GetCurrentConsoleFontEx(handle, false, ref info)) return;
            info.dwFontSize.X = 0;
            info.dwFontSize.Y = height;
            SetCurrentConsoleFontEx(handle, false, ref info);
        }
    }
}
'@
            Add-Type -TypeDefinition $source -ErrorAction Stop
        }
        [SysCtrl.ConsoleFont]::SetHeight($Height)
    } catch { }
}

function Get-RetroLayout {
    try {
        $consoleWidth = [int]$Host.UI.RawUI.WindowSize.Width
    } catch {
        $consoleWidth = 84
    }

    $consoleWidth = [math]::Max(52, $consoleWidth)
    $frameWidth = [math]::Max(48, $consoleWidth - 4)
    $innerWidth = $frameWidth - 2
    $indent = [int][math]::Max(0, [math]::Floor(($consoleWidth - $frameWidth) / 2))

    return [pscustomobject]@{
        InnerWidth = [int]$innerWidth
        Indent = $indent
    }
}

function Write-RetroBorder {
    param(
        [ValidateSet('Top', 'Bottom')]
        [string]$Position = 'Top'
    )

    $layout = Get-RetroLayout
    $edge = if ($Position -eq 'Top') { '.' } else { "'" }
    $line = (' ' * $layout.Indent) + $edge + ('-' * $layout.InnerWidth) + $edge
    Write-Host $line -ForegroundColor DarkCyan
}

function Write-RetroFrameLine {
    param(
        [string]$Text = '',
        [ConsoleColor]$Color = [ConsoleColor]::Gray,
        [switch]$Center
    )

    $layout = Get-RetroLayout
    if ($Text.Length -gt $layout.InnerWidth) {
        $Text = $Text.Substring(0, $layout.InnerWidth)
    }

    if ($Center) {
        $leftPadding = [int][math]::Max(0, [math]::Floor(($layout.InnerWidth - $Text.Length) / 2))
        $Text = (' ' * $leftPadding) + $Text
    }

    $line = (' ' * $layout.Indent) + '|' + $Text.PadRight($layout.InnerWidth) + '|'
    Write-Host $line -ForegroundColor $Color
}

function Write-RetroMeter {
    param(
        [string]$Label,
        [int]$Current,
        [int]$Total
    )

    $layout = Get-RetroLayout
    $safeTotal = [math]::Max(1, $Total)
    $percent = [math]::Min(100, [math]::Max(0, [math]::Round(($Current / $safeTotal) * 100)))
    $meterWidth = [math]::Max(16, $layout.InnerWidth - 28)
    $filled = [math]::Min($meterWidth, [math]::Max(0, [math]::Round(($percent / 100) * $meterWidth)))
    $bar = ('=' * $filled).PadRight($meterWidth, '.')
    $line = (' ' * $layout.Indent) + ('{0,-8} [{1}] {2,3}%' -f $Label, $bar, $percent)
    Write-Host ([char]13 + $line) -NoNewline -ForegroundColor Cyan

    if ($Current -ge $Total) {
        Write-Host ''
    }
}

function Show-Header {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "$script:AppName - $script:Author"

    Write-Host ''
    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    $logoArt = @(
        '███████╗██╗   ██╗███████╗     ██████╗████████╗██████╗ ██╗',
        '██╔════╝╚██╗ ██╔╝██╔════╝    ██╔════╝╚══██╔══╝██╔══██╗██║',
        '███████╗ ╚████╔╝ ███████╗    ██║        ██║   ██████╔╝██║',
        '╚════██║  ╚██╔╝  ╚════██║    ██║        ██║   ██╔══██╗██║',
        '███████║   ██║   ███████║    ╚██████╗   ██║   ██║  ██║███████╗',
        '╚══════╝   ╚═╝   ╚══════╝     ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝'
    )
    $logoColors = @(
        [ConsoleColor]::Cyan,
        [ConsoleColor]::DarkCyan,
        [ConsoleColor]::Magenta,
        [ConsoleColor]::DarkMagenta,
        [ConsoleColor]::Cyan,
        [ConsoleColor]::Magenta
    )
    $logoWidth = ($logoArt | Measure-Object -Property Length -Maximum).Maximum
    for ($row = 0; $row -lt $logoArt.Count; $row++) {
        Write-RetroFrameLine $logoArt[$row].PadRight($logoWidth) -Color $logoColors[$row] -Center
    }
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine 'SYS CTRL v2.0  //  MADE BY SUCH CHAOS  //  TERMINAL CONTROL DECK' -Color Magenta -Center
    if ($null -ne $script:UpdateStatus -and $script:UpdateStatus.State -ne 'NotConfigured') {
        Write-RetroFrameLine $script:UpdateStatus.Text -Color $script:UpdateStatus.Color -Center
    }
    Write-RetroFrameLine '' -Color DarkCyan

    $drive = Get-SystemDrive
    if ($null -ne $drive) {
        $total = $drive.Used + $drive.Free
        $percent = if ($total -gt 0) { [math]::Round(($drive.Used / $total) * 100) } else { 0 }
        $layout = Get-RetroLayout
        $barWidth = [math]::Max(16, $layout.InnerWidth - 52)
        $fill = [math]::Min($barWidth, [math]::Max(0, [math]::Round(($percent / 100) * $barWidth)))
        $bar = ('=' * $fill).PadRight($barWidth, '.')
        Write-RetroFrameLine ('SYS DRIVE {0}  {1,3}%  [{2}]  FREE {3}' -f $env:SystemDrive, $percent, $bar, (Format-Bytes $drive.Free)) -Color Yellow -Center
    }

    Write-RetroBorder -Position Bottom
    Write-Host ''
}

function Show-BootSequence {
    Clear-Host
    Write-Host ''
    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine 'SYS CTRL v2.0  //  BOOT SEQUENCE' -Color Magenta -Center
    Write-RetroFrameLine 'MADE BY SUCH CHAOS' -Color Yellow -Center
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroBorder -Position Bottom
    Write-Host ''

    $steps = @('Safe cleanup map', 'Recovery tools', 'GitHub release check', 'Terminal display', 'Control deck')
    foreach ($step in $steps) {
        if ($step -eq 'GitHub release check') {
            Initialize-GitHubUpdateStatus
        }
        $layout = Get-RetroLayout
        $labelWidth = [math]::Min(30, [math]::Max(18, [int]($layout.InnerWidth * 0.32)))
        $meterWidth = [math]::Min(26, [math]::Max(14, $layout.InnerWidth - $labelWidth - 16))
        $prefixFormat = '> {0,-' + $labelWidth + '} ['
        $prefix = (' ' * $layout.Indent) + ($prefixFormat -f $step)
        for ($frame = 0; $frame -le 12; $frame++) {
            $filled = [math]::Round(($frame / 12) * $meterWidth)
            $bar = ('=' * $filled).PadRight($meterWidth, '.')
            $line = $prefix + $bar + ']  READY'
            Write-Host ([char]13 + $line) -NoNewline -ForegroundColor Cyan
            Start-Sleep -Milliseconds 24
        }
        Write-Host ''
        Write-Host ''
    }
    Start-Sleep -Milliseconds 90
}

function Pause-SysCtrl {
    $layout = Get-RetroLayout
    Write-Host ''
    [void](Read-Host ((' ' * $layout.Indent) + 'PRESS ENTER TO RETURN TO SYS CTRL'))
    Show-PageTransition -Text 'RETURNING TO MAIN MENU'
}

function Get-ConsoleSizeKey {
    try {
        $size = $Host.UI.RawUI.WindowSize
        return ('{0}x{1}' -f $size.Width, $size.Height)
    } catch {
        return '84x25'
    }
}

function Show-MainMenu {
    param([string]$Selection = '')

    Show-Header

    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '[ MAINTENANCE MODULES ]' -Color Magenta -Center
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  1  CACHE SWEEP       Clear safe caches and temp files' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  2  SPACE HUNTER      Map your largest profile folders' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  3  REGEN WATCH       Check cache growth since a sweep' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  4  WINDOWS REPAIR    Run DISM RestoreHealth and SFC' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  5  APP UPDATE RUN    Preview and update WinGet apps' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  6  ACTION REPORT     View recent SYS CTRL activity' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroBorder -Position Bottom

    Write-Host ''

    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '[ POWER CONTROL ]' -Color Magenta -Center
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  7  SHUT DOWN' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  8  RESTART TO BIOS / UEFI' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '  0  EXIT' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroBorder -Position Bottom

    $layout = Get-RetroLayout
    Write-Host ''
    Write-Host ((' ' * $layout.Indent) + 'SELECT MODULE  > ') -NoNewline -ForegroundColor Yellow
    if ($Selection) {
        Write-Host $Selection -NoNewline -ForegroundColor Cyan
    }
}

function Show-ModulePanel {
    param(
        [string]$Title,
        [string[]]$Lines = @()
    )

    Show-Header
    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine $Title -Color Magenta -Center
    Write-RetroFrameLine '' -Color DarkCyan
    foreach ($line in $Lines) {
        Write-RetroFrameLine ('  ' + $line) -Color Gray
        Write-RetroFrameLine '' -Color DarkCyan
    }
    Write-RetroBorder -Position Bottom
    Write-Host ''
}

function Show-PageTransition {
    param([string]$Text)

    $layout = Get-RetroLayout
    $prefix = (' ' * $layout.Indent) + '  ' + $Text.PadRight(30) + ' ['

    Write-Host ''
    for ($frame = 0; $frame -lt 6; $frame++) {
        $dots = ('.' * ($frame + 1)).PadRight(6, ' ')
        Write-Host ([char]13 + $prefix + $dots + ']') -NoNewline -ForegroundColor DarkCyan
        Start-Sleep -Milliseconds 125
    }
    Write-Host ''
    Start-Sleep -Milliseconds 180
}

function Read-MainMenuChoice {
    $lastSize = Get-ConsoleSizeKey
    $selection = ''

    while ($true) {
        $currentSize = Get-ConsoleSizeKey
        if ($currentSize -ne $lastSize) {
            Show-MainMenu -Selection $selection
            $lastSize = Get-ConsoleSizeKey
            continue
        }

        try {
            $keyAvailable = [Console]::KeyAvailable
        } catch {
            $keyAvailable = $false
        }

        if ($keyAvailable) {
            $key = [Console]::ReadKey($true)
            $character = [string]$key.KeyChar

            if ($character -match '^[0-8]$') {
                if ($selection) {
                    Write-Host (([string][char]8) + $character) -NoNewline -ForegroundColor Cyan
                } else {
                    Write-Host $character -NoNewline -ForegroundColor Cyan
                }
                $selection = $character
                continue
            }

            if ($key.Key -eq 'Backspace' -and $selection) {
                $selection = ''
                Write-Host (([string][char]8) + ' ' + ([string][char]8)) -NoNewline -ForegroundColor Cyan
                continue
            }

            if ($key.Key -eq 'Enter' -and $selection) {
                Write-Host ''
                return $selection
            }
        }

        Start-Sleep -Milliseconds 45
    }
}

function Write-Activity {
    param(
        [string]$Action,
        [string]$Result,
        [hashtable]$Details = @{}
    )

    try {
        Initialize-SysCtrlStorage
        $entry = [ordered]@{
            Time = (Get-Date).ToString('o')
            Action = $Action
            Result = $Result
            Details = $Details
        }
        Add-Content -LiteralPath $script:ActivityPath -Value ($entry | ConvertTo-Json -Compress -Depth 4) -Encoding UTF8
    } catch { }
}

function Test-AppsClosed {
    param([string[]]$ProcessNames)

    if (-not $ProcessNames -or $ProcessNames.Count -eq 0) { return $true }
    foreach ($processName in $ProcessNames) {
        if (Get-Process -Name $processName -ErrorAction SilentlyContinue) { return $false }
    }
    return $true
}

function New-CleanupTarget {
    param(
        [string]$Name,
        [string[]]$Paths,
        [string]$Mode = 'Folder',
        [string]$Filter = '*',
        [string[]]$CloseApps = @()
    )

    [pscustomobject]@{
        Name = $Name
        Paths = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        Mode = $Mode
        Filter = $Filter
        CloseApps = $CloseApps
    }
}

function Get-SafeCleanupTargets {
    $localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
    $werLocal = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER'
    $werMachine = Join-Path $env:ProgramData 'Microsoft\Windows\WER'
    $explorerCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
    $internetCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache'
    $legacyWindowsTmp = Join-Path $env:windir 'Tmp'
    $chromeData = Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'
    $edgeData = Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'
    $firefoxProfiles = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    $discordData = Join-Path $env:APPDATA 'discord'

    $chromeCaches = @()
    if (Test-Path -LiteralPath $chromeData) {
        $chromeCaches += Get-ChildItem -LiteralPath $chromeData -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } |
            ForEach-Object { @((Join-Path $_.FullName 'Cache'), (Join-Path $_.FullName 'Code Cache')) }
    }

    $edgeCaches = @()
    if (Test-Path -LiteralPath $edgeData) {
        $edgeCaches += Get-ChildItem -LiteralPath $edgeData -Directory -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } |
            ForEach-Object { @((Join-Path $_.FullName 'Cache'), (Join-Path $_.FullName 'Code Cache')) }
    }

    $firefoxCaches = @()
    if (Test-Path -LiteralPath $firefoxProfiles) {
        $firefoxCaches += Get-ChildItem -LiteralPath $firefoxProfiles -Directory -Force -ErrorAction SilentlyContinue |
            ForEach-Object { @((Join-Path $_.FullName 'cache2'), (Join-Path $_.FullName 'startupCache')) }
    }

    return @(
        (New-CleanupTarget -Name 'User temporary files' -Paths @($env:TEMP, $env:TMP, $localTemp)),
        (New-CleanupTarget -Name 'Windows temporary files' -Paths @(Join-Path $env:windir 'Temp')),
        (New-CleanupTarget -Name 'Windows legacy TMP files' -Paths @($legacyWindowsTmp)),
        (New-CleanupTarget -Name 'Windows error-report cache' -Paths @(
            (Join-Path $werLocal 'ReportArchive'), (Join-Path $werLocal 'ReportQueue'), (Join-Path $werLocal 'Temp'),
            (Join-Path $werMachine 'ReportArchive'), (Join-Path $werMachine 'ReportQueue'), (Join-Path $werMachine 'Temp')
        )),
        (New-CleanupTarget -Name 'Windows internet cache' -Paths @($internetCache)),
        (New-CleanupTarget -Name 'Explorer thumbnail cache' -Paths @($explorerCache) -Mode 'Pattern' -Filter 'thumbcache_*.db'),
        (New-CleanupTarget -Name 'Explorer icon cache' -Paths @($explorerCache) -Mode 'Pattern' -Filter 'iconcache_*.db'),
        (New-CleanupTarget -Name 'Chrome browser cache' -Paths $chromeCaches -CloseApps @('chrome')),
        (New-CleanupTarget -Name 'Microsoft Edge browser cache' -Paths $edgeCaches -CloseApps @('msedge')),
        (New-CleanupTarget -Name 'Firefox browser cache' -Paths $firefoxCaches -CloseApps @('firefox')),
        (New-CleanupTarget -Name 'Discord application cache' -Paths @((Join-Path $discordData 'Cache'), (Join-Path $discordData 'Code Cache')) -CloseApps @('Discord'))
    )
}

function Get-CleanupFiles {
    param($Target)

    $files = New-Object 'System.Collections.Generic.List[object]'
    if (-not (Test-AppsClosed -ProcessNames $Target.CloseApps)) {
        return [pscustomobject]@{ Files = @(); Skipped = 'Close the related app first' }
    }

    foreach ($path in $Target.Paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
        try {
            if ($Target.Mode -eq 'Pattern') {
                $items = Get-ChildItem -LiteralPath $path -File -Force -Filter $Target.Filter -ErrorAction SilentlyContinue
            } else {
                $items = Get-ChildItem -LiteralPath $path -File -Force -Recurse -ErrorAction SilentlyContinue
            }
            foreach ($item in $items) {
                $files.Add([pscustomobject]@{ FullName = $item.FullName; Length = [long]$item.Length; Target = $Target.Name })
            }
        } catch { }
    }
    return [pscustomobject]@{ Files = $files.ToArray(); Skipped = $null }
}

function Clear-EmptyCleanupDirectories {
    param([object[]]$Targets)

    foreach ($target in $Targets) {
        if ($target.Mode -ne 'Folder' -or -not (Test-AppsClosed -ProcessNames $target.CloseApps)) { continue }

        foreach ($path in $target.Paths) {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }

            try {
                Get-ChildItem -LiteralPath $path -Directory -Force -Recurse -ErrorAction SilentlyContinue |
                    Sort-Object { $_.FullName.Length } -Descending |
                    ForEach-Object {
                        try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { }
                    }
            } catch { }
        }
    }
}

function Get-CleanupReport {
    param([switch]$ShowProgress)

    $targets = @(Get-SafeCleanupTargets)
    $report = New-Object 'System.Collections.Generic.List[object]'
    $index = 0
    foreach ($target in $targets) {
        $index++
        if ($ShowProgress) {
            Write-RetroMeter -Label 'SCANNING' -Current $index -Total $targets.Count
        }
        $result = Get-CleanupFiles -Target $target
        $bytes = [long](($result.Files | Measure-Object -Property Length -Sum).Sum)
        $report.Add([pscustomobject]@{
            Name = $target.Name
            Files = @($result.Files)
            Count = @($result.Files).Count
            Bytes = $bytes
            Skipped = $result.Skipped
        })
    }
    return $report.ToArray()
}

function Show-CleanupReport {
    param($Report)

    [long]$totalBytes = 0
    $totalFiles = 0
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in $Report) {
        $totalBytes += $item.Bytes
        $totalFiles += $item.Count
        if ($item.Skipped) {
            $lines.Add(('[ LOCKED ] {0} // {1}' -f $item.Name, $item.Skipped))
        } else {
            $lines.Add(('[ READY  ] {0} // {1} files // {2}' -f $item.Name, $item.Count, (Format-Bytes $item.Bytes)))
        }
    }
    $lines.Add(('[ TOTAL  ] {0} files // {1}' -f $totalFiles, (Format-Bytes $totalBytes)))
    Show-PageTransition -Text 'BUILDING CACHE MAP'
    Show-ModulePanel -Title 'SAFE CACHE MAP' -Lines ($lines.ToArray())
    return [pscustomobject]@{ Count = $totalFiles; Bytes = $totalBytes }
}

function Initialize-LockResolver {
    if ('SysCtrl.LockResolver' -as [type]) { return $true }
    $source = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

namespace SysCtrl {
    public static class LockResolver {
        const int ERROR_MORE_DATA = 234;
        const int CCH_RM_SESSION_KEY = 32;
        const int CCH_RM_MAX_APP_NAME = 255;
        const int CCH_RM_MAX_SVC_NAME = 63;

        [StructLayout(LayoutKind.Sequential)]
        struct RM_UNIQUE_PROCESS {
            public int dwProcessId;
            public System.Runtime.InteropServices.ComTypes.FILETIME ProcessStartTime;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        struct RM_PROCESS_INFO {
            public RM_UNIQUE_PROCESS Process;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_APP_NAME + 1)] public string strAppName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCH_RM_MAX_SVC_NAME + 1)] public string strServiceShortName;
            public uint ApplicationType;
            public uint AppStatus;
            public uint TSSessionId;
            [MarshalAs(UnmanagedType.Bool)] public bool bRestartable;
        }

        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        static extern int RmStartSession(out uint sessionHandle, int sessionFlags, StringBuilder sessionKey);
        [DllImport("rstrtmgr.dll")]
        static extern int RmEndSession(uint sessionHandle);
        [DllImport("rstrtmgr.dll", CharSet = CharSet.Unicode)]
        static extern int RmRegisterResources(uint sessionHandle, uint fileCount, string[] fileNames, uint appCount, IntPtr apps, uint serviceCount, string[] serviceNames);
        [DllImport("rstrtmgr.dll")]
        static extern int RmGetList(uint sessionHandle, out uint needed, ref uint count, [In, Out] RM_PROCESS_INFO[] affectedApps, ref uint rebootReasons);

        public static string[] GetLockingProcesses(string[] fileNames) {
            if (fileNames == null || fileNames.Length == 0) return new string[0];
            uint handle = 0;
            StringBuilder key = new StringBuilder(CCH_RM_SESSION_KEY + 1);
            if (RmStartSession(out handle, 0, key) != 0) return new string[0];
            try {
                if (RmRegisterResources(handle, (uint)fileNames.Length, fileNames, 0, IntPtr.Zero, 0, null) != 0) return new string[0];
                uint needed = 0, count = 0, reasons = 0;
                int result = RmGetList(handle, out needed, ref count, null, ref reasons);
                if (result != ERROR_MORE_DATA || needed == 0) return new string[0];
                RM_PROCESS_INFO[] apps = new RM_PROCESS_INFO[needed];
                count = needed;
                result = RmGetList(handle, out needed, ref count, apps, ref reasons);
                if (result != 0) return new string[0];
                HashSet<string> names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                for (int i = 0; i < count; i++) {
                    try {
                        Process process = Process.GetProcessById(apps[i].Process.dwProcessId);
                        names.Add(process.ProcessName + " (PID " + process.Id + ")");
                    } catch { }
                }
                string[] output = new string[names.Count];
                names.CopyTo(output);
                return output;
            } finally { RmEndSession(handle); }
        }
    }
}
'@
    try {
        Add-Type -TypeDefinition $source -ErrorAction Stop
        return $true
    } catch { return $false }
}

function Show-LockResolver {
    param([object[]]$Failures)

    if (-not $Failures -or $Failures.Count -eq 0) { return }
    $sample = @($Failures | Select-Object -First $script:LockLimit)
    if (-not (Initialize-LockResolver)) {
        Show-PageTransition -Text 'CHECKING FILE LOCKS'
        Show-ModulePanel -Title 'LOCK RESOLVER' -Lines @(
            'Windows lock analysis could not load.',
            'Skipped files may be in use or protected.'
        )
        return
    }
    $names = [SysCtrl.LockResolver]::GetLockingProcesses(@($sample | ForEach-Object { $_.FullName }))
    if ($names.Count -gt 0) {
        Show-PageTransition -Text 'CHECKING FILE LOCKS'
        Show-ModulePanel -Title 'LOCK RESOLVER' -Lines @(
            ('Open processes: {0}' -f ($names -join ', ')),
            'Close the listed app normally, then run CACHE SWEEP again.'
        )
    } else {
        Show-PageTransition -Text 'CHECKING FILE LOCKS'
        Show-ModulePanel -Title 'LOCK RESOLVER' -Lines @(
            'No app lock was identified.',
            'Skipped files are likely protected or changed during cleanup.'
        )
    }
}

function Save-RegenBaseline {
    $report = Get-CleanupReport
    $baseline = [ordered]@{
        Created = (Get-Date).ToString('o')
        Targets = @($report | ForEach-Object {
            [ordered]@{ Name = $_.Name; Files = $_.Count; Bytes = $_.Bytes; Skipped = $_.Skipped }
        })
    }
    try {
        Initialize-SysCtrlStorage
        Set-Content -LiteralPath $script:RegenPath -Value ($baseline | ConvertTo-Json -Depth 4) -Encoding UTF8
    } catch { }
}

function Invoke-CacheSweep {
    Show-ModulePanel -Title 'CACHE SWEEP' -Lines @(
        'Safe rebuildable data only.',
        'GPU shader caches, cookies, history, and Downloads stay excluded.',
        'Personal files are never included.',
        'Scanning known Windows, browser, and application cache locations...'
    )
    $beforeDrive = Get-SystemDrive
    [long]$freeBefore = if ($beforeDrive) { $beforeDrive.Free } else { 0 }
    $report = @(Get-CleanupReport -ShowProgress)
    $summary = Show-CleanupReport -Report $report

    if ($summary.Count -eq 0) {
        Show-PageTransition -Text 'NO CLEANUP NEEDED'
        Show-ModulePanel -Title 'CACHE SWEEP' -Lines @(
            'Nothing safe to clear right now.'
        )
        Write-Activity -Action 'Cache Sweep' -Result 'No files found'
        return
    }

    $allFiles = @($report | ForEach-Object { $_.Files })
    $removed = 0
    $skipped = New-Object 'System.Collections.Generic.List[object]'
    [long]$bytesRemoved = 0
    for ($index = 0; $index -lt $allFiles.Count; $index++) {
        $file = $allFiles[$index]
        if (($index -eq 0) -or ((($index + 1) % 25) -eq 0) -or (($index + 1) -eq $allFiles.Count)) {
            Write-RetroMeter -Label 'SWEEPING' -Current ($index + 1) -Total $allFiles.Count
        }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed++
            $bytesRemoved += $file.Length
        } catch { $skipped.Add($file) }
    }
    Clear-EmptyCleanupDirectories -Targets @(Get-SafeCleanupTargets)
    Save-RegenBaseline
    $afterDrive = Get-SystemDrive
    [long]$freeAfter = if ($afterDrive) { $afterDrive.Free } else { 0 }
    [long]$spaceChange = $freeAfter - $freeBefore

    Show-PageTransition -Text 'BUILDING ACTION REPORT'
    Show-ModulePanel -Title 'AFTER ACTION REPORT' -Lines @(
        ('Removed: {0} files  //  {1}' -f $removed, (Format-Bytes $bytesRemoved)),
        ('Skipped: {0} files' -f $skipped.Count),
        ('Drive change: {0}' -f (Format-Bytes $spaceChange)),
        'REGEN WATCH baseline saved for future cache-growth checks.'
    )
    Write-Activity -Action 'Cache Sweep' -Result 'Completed' -Details @{ RemovedFiles = $removed; RemovedBytes = $bytesRemoved; SkippedFiles = $skipped.Count; DriveChange = $spaceChange }
    Show-LockResolver -Failures $skipped.ToArray()
}

function Get-FolderBytes {
    param([string]$Path)

    [long]$total = 0
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return $total }
    $stack = New-Object 'System.Collections.Generic.Stack[System.IO.DirectoryInfo]'
    try { $stack.Push((Get-Item -LiteralPath $Path -Force -ErrorAction Stop)) } catch { return $total }
    while ($stack.Count -gt 0) {
        $directory = $stack.Pop()
        $children = Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction SilentlyContinue
        foreach ($child in $children) {
            if ($child.PSIsContainer) {
                if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $stack.Push($child) }
            } else {
                $total += [long]$child.Length
            }
        }
    }
    return $total
}

function Invoke-SpaceHunter {
    Show-ModulePanel -Title 'SPACE HUNTER // PROFILE STORAGE MAP' -Lines @(
        'Mapping the largest areas of your user profile. This can take a moment.'
    )
    $roots = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'AppData' })
    $appData = Get-Item -LiteralPath (Join-Path $env:USERPROFILE 'AppData') -Force -ErrorAction SilentlyContinue
    if ($appData) { $roots += $appData }
    $stats = New-Object 'System.Collections.Generic.List[object]'
    $counter = 0
    foreach ($root in $roots) {
        $counter++
        Write-RetroMeter -Label 'MAPPING' -Current $counter -Total $roots.Count
        $stats.Add([pscustomobject]@{ Name = $root.Name; Path = $root.FullName; Bytes = (Get-FolderBytes -Path $root.FullName) })
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $rank = 0
    foreach ($stat in ($stats | Sort-Object Bytes -Descending | Select-Object -First 12)) {
        $rank++
        $lines.Add(('# {0}  //  {1}  //  {2}' -f $rank, $stat.Name, (Format-Bytes $stat.Bytes)))
    }
    $lines.Add('Map only: SPACE HUNTER never deletes personal folders.')
    Show-PageTransition -Text 'BUILDING STORAGE MAP'
    Show-ModulePanel -Title 'SPACE HUNTER // LARGEST PROFILE AREAS' -Lines ($lines.ToArray())
    Write-Activity -Action 'Space Hunter' -Result 'Completed' -Details @{ AreasScanned = $stats.Count }
}

function Invoke-RegenWatch {
    if (-not (Test-Path -LiteralPath $script:RegenPath)) {
        Show-ModulePanel -Title 'REGEN WATCH' -Lines @(
            'No baseline exists yet. Run CACHE SWEEP once to begin tracking cache growth.'
        )
        return
    }
    try { $baseline = Get-Content -LiteralPath $script:RegenPath -Raw | ConvertFrom-Json } catch { $baseline = $null }
    if (-not $baseline) {
        Show-ModulePanel -Title 'REGEN WATCH' -Lines @(
            'The saved baseline could not be read. Run CACHE SWEEP to create a new one.'
        )
        return
    }
    $current = @(Get-CleanupReport -ShowProgress)
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add(('Baseline: {0}' -f ([datetime]$baseline.Created).ToLocalTime().ToString('yyyy-MM-dd HH:mm')))
    foreach ($item in $current) {
        $before = @($baseline.Targets | Where-Object { $_.Name -eq $item.Name } | Select-Object -First 1)[0]
        [long]$beforeBytes = if ($before) { $before.Bytes } else { 0 }
        [long]$growth = $item.Bytes - $beforeBytes
        if ($item.Skipped) {
            $lines.Add(('[ PAUSED ] {0} // close the related app to measure' -f $item.Name))
        } elseif ($growth -gt 0) {
            $lines.Add(('[ GREW   ] {0} // +{1}' -f $item.Name, (Format-Bytes $growth)))
        } else {
            $lines.Add(('[ CLEAR  ] {0} // {1}' -f $item.Name, (Format-Bytes $item.Bytes)))
        }
    }
    Show-PageTransition -Text 'BUILDING GROWTH REPORT'
    Show-ModulePanel -Title 'REGEN WATCH // CACHE GROWTH' -Lines ($lines.ToArray())
    Write-Activity -Action 'Regen Watch' -Result 'Completed'
}

function Invoke-WindowsRepair {
    Show-ModulePanel -Title 'WINDOWS REPAIR RUN' -Lines @(
        'Sequence: DISM RestoreHealth, then SFC /scannow.',
        'This can take a while. Keep the PC connected to power and online.',
        'Starting repair run...'
    )

    Show-PageTransition -Text 'STARTING DISM'
    Show-ModulePanel -Title '[ 1 / 2 ]  DISM RESTOREHEALTH'
    & DISM.exe /Online /Cleanup-Image /RestoreHealth
    $dismExit = $LASTEXITCODE
    Show-PageTransition -Text 'STARTING SFC'
    Show-ModulePanel -Title '[ 2 / 2 ]  SFC /SCANNOW'
    & sfc.exe /scannow
    $sfcExit = $LASTEXITCODE
    Show-PageTransition -Text 'BUILDING REPAIR REPORT'
    Show-ModulePanel -Title 'WINDOWS REPAIR RUN // COMPLETE' -Lines @(
        ('DISM exit code: {0}' -f $dismExit),
        ('SFC exit code: {0}' -f $sfcExit)
    )
    Write-Activity -Action 'Windows Repair Run' -Result 'Completed' -Details @{ DismExit = $dismExit; SfcExit = $sfcExit }
}

function Invoke-AppUpdateRun {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        Show-PageTransition -Text 'CHECKING WINGET'
        Show-ModulePanel -Title 'APP UPDATE RUN' -Lines @(
            'WinGet is not available on this Windows installation.'
        )
        Write-Activity -Action 'App Update Run' -Result 'WinGet unavailable'
        return
    }
    Show-ModulePanel -Title 'APP UPDATE RUN // PACKAGE PREVIEW' -Lines @(
        'Checking installed packages for updates...'
    )
    & winget.exe upgrade --include-unknown --include-pinned --accept-source-agreements
    $previewExit = $LASTEXITCODE
    Write-Host ''
    Write-RetroBorder
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '[ UPDATE ALL ]  Install every package shown above?' -Color Yellow
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroFrameLine '[Y] Yes     [N] No' -Color Gray
    Write-RetroFrameLine '' -Color DarkCyan
    Write-RetroBorder -Position Bottom

    do {
        $answer = (Read-Host '  INSTALL UPDATES [Y/N]').Trim().ToUpperInvariant()
    } until ($answer -eq 'Y' -or $answer -eq 'N')

    if ($answer -eq 'N') {
        Show-PageTransition -Text 'CANCELLING UPDATE RUN'
        Show-ModulePanel -Title 'APP UPDATE RUN' -Lines @(
            'Update run cancelled. The package preview was not changed.'
        )
        return
    }
    Show-PageTransition -Text 'STARTING APP UPDATES'
    Show-ModulePanel -Title 'APP UPDATE RUN // INSTALLING AVAILABLE UPDATES'
    & winget.exe upgrade --all --include-unknown --include-pinned --accept-source-agreements --accept-package-agreements --disable-interactivity --silent --force
    $updateExit = $LASTEXITCODE
    Show-PageTransition -Text 'BUILDING UPDATE REPORT'
    Show-ModulePanel -Title 'APP UPDATE RUN // COMPLETE' -Lines @(
        ('Update command finished with exit code {0}.' -f $updateExit)
    )
    Write-Activity -Action 'App Update Run' -Result 'Completed' -Details @{ PreviewExit = $previewExit; UpdateExit = $updateExit }
}

function Show-ActivityLog {
    if (-not (Test-Path -LiteralPath $script:ActivityPath)) {
        Show-ModulePanel -Title 'AFTER ACTION REPORT // RECENT ACTIVITY' -Lines @(
            'No SYS CTRL operations have been recorded yet.'
        )
        return
    }
    $entries = Get-Content -LiteralPath $script:ActivityPath -Tail 12 | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($entry in $entries) {
        $when = ([datetime]$entry.Time).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
        $lines.Add(('[{0}]  //  {1}  //  {2}' -f $when, $entry.Action, $entry.Result))
    }
    Show-ModulePanel -Title 'AFTER ACTION REPORT // RECENT ACTIVITY' -Lines ($lines.ToArray())
}

function Invoke-Shutdown {
    Show-ModulePanel -Title 'POWER CONTROL // SLIDE TO SHUT DOWN' -Lines @(
        'Opening the Windows slide-to-shutdown screen.'
    )
    Write-Activity -Action 'Slide To Shut Down' -Result 'Opened'
    Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\SlideToShutDown.exe')
}

function Invoke-FirmwareRestart {
    Show-ModulePanel -Title 'POWER CONTROL // RESTART TO BIOS / UEFI' -Lines @(
        'Firmware restart requested. Windows will restart in five seconds.'
    )
    Write-Activity -Action 'Firmware Restart' -Result 'Requested'
    & shutdown.exe /r /fw /t 5 /c 'SYS CTRL v2.0 requested firmware restart.'
}

Initialize-TerminalTheme
Set-ConsoleFont -Height 12
Initialize-SysCtrlStorage
Show-BootSequence

$running = $true
while ($running) {
    Show-MainMenu
    $choice = Read-MainMenuChoice
    switch ($choice) {
        '1' { Show-PageTransition -Text 'OPENING CACHE SWEEP'; Invoke-CacheSweep; Pause-SysCtrl }
        '2' { Show-PageTransition -Text 'OPENING SPACE HUNTER'; Invoke-SpaceHunter; Pause-SysCtrl }
        '3' { Show-PageTransition -Text 'OPENING REGEN WATCH'; Invoke-RegenWatch; Pause-SysCtrl }
        '4' { Show-PageTransition -Text 'OPENING REPAIR RUN'; Invoke-WindowsRepair; Pause-SysCtrl }
        '5' { Show-PageTransition -Text 'OPENING APP UPDATE RUN'; Invoke-AppUpdateRun; Pause-SysCtrl }
        '6' { Show-PageTransition -Text 'OPENING ACTION REPORT'; Show-ActivityLog; Pause-SysCtrl }
        '7' { Show-PageTransition -Text 'OPENING SHUT DOWN'; Invoke-Shutdown }
        '8' { Show-PageTransition -Text 'OPENING BIOS RESTART'; Invoke-FirmwareRestart }
        '0' { Show-PageTransition -Text 'CLOSING SYS CTRL'; $running = $false }
    }
}
