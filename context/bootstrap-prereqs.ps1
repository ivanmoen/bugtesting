# bootstrap-prereqs.ps1 -- install non-Unreal build prerequisites on a clean
# Windows box. Idempotent and safe to re-run: anything already present is
# detected via canonical probes (Get-Command for SVN, vswhere.exe for VS) and
# skipped.
#
# IMPORTANT: this file is ASCII-only on purpose. Windows PowerShell 5.1 reads
# .ps1 files as ANSI/Windows-1252 unless they carry a UTF-8/UTF-16 BOM. Any
# multi-byte UTF-8 glyph (arrows, em-dashes, smart quotes, etc.) gets read as
# garbage and breaks the parser before the script can even start. Stick to
# plain ASCII.
#
# What it installs (in order):
#   1. TortoiseSVN            (~50 MB)  -- for the worker's `svn` shell-outs
#   2. VS Build Tools 2022    (~10 GB)  -- MSVC v143 + Windows SDK + C++ build chain
#                                          required by Unreal RunUAT BuildCookRun
#
# What it does NOT install:
#   - Unreal Engine (Epic Games Launcher needs an account; install separately)
#   - SteamCMD       (only needed for Steam upload, not part of this script)
#   - The worker .exe (handled by the surrounding Inno Setup installer)
#
# Invocation (from the surrounding Inno installer):
#   powershell.exe -ExecutionPolicy Bypass -NoProfile -File bootstrap-prereqs.ps1 ^
#       -VsInstallPath 'D:\BuildTools\VS2022' ^
#       -LogPath        'C:\ProgramData\RPGBuildServer\logs\bootstrap.log'
#
# Direct invocation works too (right-click -> Run as administrator).

[CmdletBinding()]
param(
    # Where to install the VS Build Tools shell + MSVC compiler + libs (~8 GB).
    # The Windows SDK + reference assemblies (~2 GB) always land at fixed
    # %ProgramFiles(x86)%\Windows Kits\10 paths regardless of this setting --
    # not a knob exposed by the VS installer.
    [string] $VsInstallPath = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools",

    # Skip flags for re-runs / partial setups.
    [switch] $SkipSvn,
    [switch] $SkipVs,

    # Log destination. Defaults to %ProgramData%\RPGBuildServer\logs\.
    [string] $LogPath = (Join-Path $env:ProgramData 'RPGBuildServer\logs\bootstrap-prereqs.log')
)

# Default to "throw on cmdlet error", but flip to Continue around native
# command calls so winget's stderr lines (NativeCommandError records) don't
# kill the script. Native exit codes are checked explicitly.
$ErrorActionPreference = 'Stop'

# ---------- Logging --------------------------------------------------------

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
"$(Get-Date -Format o) bootstrap-prereqs starting (PID=$PID, PSVersion=$($PSVersionTable.PSVersion))" |
    Out-File -FilePath $LogPath -Encoding utf8

function Log {
    param([string]$Message, [string]$Level = 'INFO')
    $line = "$(Get-Date -Format o) [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding utf8
}

function Fail {
    param([string]$Message, [int]$ExitCode = 1)
    Log $Message 'ERROR'
    exit $ExitCode
}

# Safe wrapper around native commands.
#
# Builds the command line ourselves with explicit per-arg quoting (an arg
# with whitespace gets wrapped in double quotes; backslashes before a
# closing quote are doubled per Windows CRT argv parsing rules). Then
# launches via System.Diagnostics.ProcessStartInfo with the Arguments
# field set to that single string -- avoids Start-Process's array-join
# quirk in PS 5.1 where elements containing spaces aren't auto-quoted,
# which made vs_BuildTools.exe see "--installPath" "D:\Program" "Files"
# "(x86)\..." as separate args and silently no-op.
#
# Stdout/stderr go to temp files; both are appended to the main log when
# the process exits. ExitCode is the int return value.

function Format-NativeArg {
    param([string] $Value)
    if (-not $Value) { return '""' }
    if ($Value -notmatch '[\s"]') { return $Value }
    # Per CRT rules, backslashes before a closing quote double up.
    $escaped = $Value -replace '(\\+)("|$)', '$1$1$2'
    # And any embedded literal quotes are backslash-escaped.
    $escaped = $escaped -replace '"', '\"'
    return '"' + $escaped + '"'
}

function Invoke-Native {
    param(
        [string]   $Label,
        [string]   $FilePath,
        [string[]] $ArgumentList
    )
    $stdout = [System.IO.Path]::GetTempFileName()
    $stderr = [System.IO.Path]::GetTempFileName()
    try {
        $argsStr = ($ArgumentList | ForEach-Object { Format-NativeArg $_ }) -join ' '
        Log "$Label invoking: $FilePath $argsStr"

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = $FilePath
        $psi.Arguments              = $argsStr
        $psi.UseShellExecute        = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow         = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null

        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        $code = $proc.ExitCode

        $out = $stdoutTask.GetAwaiter().GetResult()
        $err = $stderrTask.GetAwaiter().GetResult()
        if ($out) { Add-Content -Path $LogPath -Value $out -Encoding utf8 }
        if ($err) { Add-Content -Path $LogPath -Value $err -Encoding utf8 }
        Log "$Label exit code: $code"
        return $code
    }
    finally {
        Remove-Item $stdout, $stderr -ErrorAction SilentlyContinue
    }
}

# ---------- Sanity checks --------------------------------------------------

# Elevation. The VS Build Tools install requires admin, and we've already
# UAC-elevated when invoked from the Inno installer -- so this should always
# pass via that path. Direct manual runs need to right-click -> Run as admin.
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$pr = New-Object Security.Principal.WindowsPrincipal($id)
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Fail 'This script must run elevated (right-click -> Run as administrator).' 2
}

# winget -- preinstalled on Windows 10 1709+ / Windows 11.
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    $msg = @'
winget (the Windows Package Manager) was not found. It is preinstalled on
Windows 10 1709+ and Windows 11. On older systems install the prerequisites
manually:

  1. TortoiseSVN with command-line client tools:
       https://tortoisesvn.net/downloads.html
  2. Visual Studio 2022 Build Tools with the "Desktop development with C++"
     workload:
       https://visualstudio.microsoft.com/downloads/?q=build+tools

Re-run this script once those are installed (or just re-run the main worker
installer; it will pick up what is already present).
'@
    Fail $msg 3
}
Log "winget found at $($winget.Source)"

# ---------- 1. TortoiseSVN -------------------------------------------------

function Test-SvnPresent {
    $cmd = Get-Command svn.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    foreach ($candidate in @(
        (Join-Path $env:ProgramFiles  'TortoiseSVN\bin\svn.exe'),
        (Join-Path $pf86              'TortoiseSVN\bin\svn.exe'),
        (Join-Path $env:ProgramFiles  'Apache Subversion\bin\svn.exe')
    )) {
        if ($candidate -and (Test-Path $candidate)) { return $candidate }
    }
    return $null
}

if ($SkipSvn) {
    Log 'Skipping TortoiseSVN install (-SkipSvn).'
    $svn = Test-SvnPresent
} else {
    $svn = Test-SvnPresent
    if ($svn) {
        Log "TortoiseSVN already present at $svn -- skipping."
    } else {
        Log 'Installing TortoiseSVN via winget (with ADDLOCAL=ALL to ensure CLI tools)...'
        # MSI feature gotcha: TortoiseSVN's MSI ships with the "command line
        # client tools" (svn.exe) feature OFF by default. We pass
        # --custom 'ADDLOCAL=ALL' to force every feature on. --force re-runs
        # the installer even if winget thinks the package is "already
        # installed" -- common case where the operator previously ran the
        # installer interactively without ticking the CLI box. Windows
        # Installer handles this as a modify/repair op; it doesn't disturb
        # the existing GUI install.
        $code = Invoke-Native -Label 'winget(TortoiseSVN)' -FilePath $winget.Source -ArgumentList @(
            'install', '--id', 'TortoiseSVN.TortoiseSVN', '-e',
            '--silent',
            '--force',
            '--accept-source-agreements',
            '--accept-package-agreements',
            '--custom', 'ADDLOCAL=ALL'
        )
        if ($code -ne 0) {
            Log "TortoiseSVN winget install exit code $code -- continuing to verify presence" 'WARN'
        }

        $svn = Test-SvnPresent
        if (-not $svn) {
            Fail @'
TortoiseSVN install reported success but svn.exe is not on PATH or in any
canonical install dir. If TortoiseSVN was previously installed without the
"command line client tools" feature, fix it manually: Settings -> Apps ->
TortoiseSVN -> Modify -> enable "command line client tools" -> Next ->
Modify. Then re-run this script (or just rerun the worker installer).
'@ 4
        }
        Log "TortoiseSVN installed; svn.exe at $svn"
    }
}

# ---------- 2. VS Build Tools 2022 -----------------------------------------

$pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
$vswhere = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'

function Test-MsvcPresent {
    if (-not (Test-Path $vswhere)) { return $null }
    # -products * matches Build Tools, Community, Pro, Enterprise.
    # -requires VC.Tools.x86.x64 ensures the C++ workload is actually present
    # (a bare VS install without the workload does not count).
    $found = & $vswhere -products * `
        -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
        -property installationPath 2>$null
    if ($found) { return ($found | Select-Object -First 1).Trim() }
    return $null
}

# Find every VS Build Tools 2022 instance the system knows about. We
# explicitly filter to the BuildTools product so a Community / Pro install
# (which the operator might have for unrelated dev work) doesn't get
# modified or counted. Returns a list of installation paths, possibly
# empty.
#
# Why we don't just check the target path: VS supports multiple
# side-by-side instances at different paths, named "(2)", "(3)" etc.
# If we run `install` while a Build Tools instance already exists
# elsewhere, the bootstrapper happily adds a second one. We've now
# discovered this the hard way; this helper is here to prevent it.
function Get-VsBuildToolsPaths {
    if (-not (Test-Path $vswhere)) { return @() }
    $paths = & $vswhere -products Microsoft.VisualStudio.Product.BuildTools `
        -property installationPath 2>$null
    if (-not $paths) { return @() }
    return @($paths | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if ($SkipVs) {
    Log 'Skipping VS Build Tools install (-SkipVs).'
    $vs = Test-MsvcPresent
} else {
    $vs = Test-MsvcPresent
    if ($vs) {
        Log "VS with C++ workload already present at $vs -- skipping."
    } else {
        # Path + verb resolution. If ANY VS Build Tools 2022 instance is
        # already registered (anywhere), use `modify` against THAT instance's
        # path -- never spawn a parallel one. Multi-instance is supported
        # by the VS Installer ("(2)", "(3)" suffixes) but it's never what we
        # actually want from a build worker bootstrap.
        $existing = Get-VsBuildToolsPaths
        $effectivePath = $VsInstallPath
        $verb          = 'install'
        if ($existing.Count -gt 0) {
            $verb = 'modify'
            # Prefer the one matching the operator's chosen path; fall back
            # to the first one if there's no match.
            $match = $existing | Where-Object {
                ($_.TrimEnd('\') + '\').ToLowerInvariant() -eq
                ($VsInstallPath.TrimEnd('\') + '\').ToLowerInvariant()
            } | Select-Object -First 1
            if ($match) {
                $effectivePath = $match
            } else {
                $effectivePath = $existing[0]
                Log "Existing VS Build Tools install found at '$effectivePath'; ignoring requested path '$VsInstallPath' to avoid creating a parallel instance." 'WARN'
            }
            if ($existing.Count -gt 1) {
                Log "Multiple VS Build Tools 2022 instances detected: $($existing -join ', '). Modifying '$effectivePath'. Consider uninstalling the others." 'WARN'
            }
        }
        Log "VS install verb: '$verb' at '$effectivePath' (existing instances found: $($existing.Count))"
        Log "Installing VS Build Tools 2022 (~10 GB) into $effectivePath ..."
        Log 'This will take several minutes; the VS Installer UI shows progress.'

        # Skip winget here. winget's --override would be ideal but PS 5.1's
        # native-command argv quoting is unreliable with spaced paths. Calling
        # the Microsoft-hosted bootstrapper directly is more deterministic.
        $bootstrapperUri = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
        $bootstrapper    = Join-Path $env:TEMP "vs_BuildTools_$($PID).exe"

        Log "Downloading VS Build Tools bootstrapper: $bootstrapperUri"
        try {
            # Default to TLS 1.2; older PS 5.1 boxes may still negotiate 1.0
            # which Microsoft's CDN refuses.
            [Net.ServicePointManager]::SecurityProtocol =
                [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            # -UseBasicParsing: avoids the IE-engine load on first run
            # (PS 5.1 trips on "IE not configured" otherwise).
            Invoke-WebRequest -Uri $bootstrapperUri -OutFile $bootstrapper -UseBasicParsing
        }
        catch {
            Fail "Could not download VS Build Tools bootstrapper: $($_.Exception.Message)" 6
        }

        # --passive: progress UI shown, no user prompts, fails are visible.
        # We deliberately use this rather than --quiet so the operator can
        # see the actual install activity (silent failures are too easy
        # to miss otherwise).
        $code = Invoke-Native -Label 'vs_BuildTools' -FilePath $bootstrapper -ArgumentList @(
            $verb,
            '--passive', '--wait', '--norestart',
            '--installPath',  $effectivePath,
            '--add', 'Microsoft.VisualStudio.Workload.VCTools',
            '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
        )
        Remove-Item -Path $bootstrapper -ErrorAction SilentlyContinue
        Log "vs_BuildTools final exit code: $code"

        # VS Build Tools occasionally returns nonzero (e.g. 3010 = success +
        # reboot required, 1602 = user cancelled). Probe via vswhere rather
        # than trusting the exit code alone.
        $vs = Test-MsvcPresent
        if (-not $vs) {
            $bootstrapLogs = Join-Path $env:TEMP 'dd_setup_*.log'
            $instancesDir  = Join-Path $env:ProgramData 'Microsoft\VisualStudio\Packages\_Instances'
            Fail @"
VS Build Tools install did not register the C++ workload. vs_BuildTools.exe
exited $code but vswhere can't find Microsoft.VisualStudio.Component.VC.Tools.x86.x64
under any installed instance.

Likely causes:
  - Bootstrapper short-circuited because of leftover VS Installer state
  - --passive UI was closed before the install completed
  - VS Installer hit an error it couldn't recover from silently

Recovery options (any one works):
  A) Open 'Visual Studio Installer' from the Start menu, find
     'Visual Studio Build Tools 2022', click Modify, check
     'Desktop development with C++', and let it finish. Then re-run this
     script (or just rerun the worker installer; it will detect the
     completed install and skip the bootstrap).
  B) Run vs_BuildTools.exe manually with --passive replaced by --normal
     so you can see the full GUI:
       https://aka.ms/vs/17/release/vs_BuildTools.exe modify ``
         --installPath "$VsInstallPath" ``
         --add Microsoft.VisualStudio.Workload.VCTools ``
         --add Microsoft.VisualStudio.Component.Windows11SDK.22621

Diagnostic logs:
  - $bootstrapLogs       (bootstrapper download + handoff)
  - $instancesDir        (one folder per installed instance, with state.json)
"@ 5
        }
        Log "VS Build Tools installed; installation root at $vs"
        if ($code -eq 3010) {
            Log 'Note: VS installer requested a reboot (exit 3010). Builds will work; reboot at your convenience.' 'WARN'
        }
    }
}

# ---------- Summary --------------------------------------------------------

Log '------ Bootstrap summary ------'
$svnSummary = if ($svn) { $svn } else { '(not installed)' }
$vsSummary  = if ($vs)  { $vs }  else { '(not installed)' }
Log "  svn.exe      : $svnSummary"
Log "  VS C++ root  : $vsSummary"
Log 'Bootstrap finished successfully.'
exit 0
