# _helpers\test-fix.ps1
# Implements outbox\02-diagnosis-and-fix-test.md.
# 1) Dump _Instances\0240ddbe\state.json into inbox\logs\.
# 2) Download vs_BuildTools.exe and run a `modify` adding VC.Tools.x86.x64.
# 3) Verify via vswhere -requires + cl.exe search on disk.
# Captures everything to inbox\02-test-raw.txt.
# REQUIRED: elevated PS 5.1. Modifies system state (installs the missing C++ compiler).
# ASCII only.

$ErrorActionPreference = 'Continue'

# Make sure HTTPS works on a freshly-installed Win11 (TLS 1.2 explicit just in case).
try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$inbox       = Join-Path $repoRoot 'inbox'
$logsDir     = Join-Path $inbox    'logs'
$rawOut      = Join-Path $inbox    '02-test-raw.txt'

$installPath = 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$tmp         = Join-Path $env:TEMP 'vs_BuildTools_test.exe'
$instDir     = Join-Path $env:ProgramData 'Microsoft\VisualStudio\Packages\_Instances\0240ddbe'
$vswhere     = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

# Re-purpose the .gitkeep with a note for this round
$gitkeep = Join-Path $logsDir '.gitkeep'
"Round 02 logs (state.json + new top-level dd_*.log from modify run) follow. Round 01 logs are bundled in inbox/logs.zip (extract to read)." `
    | Out-File $gitkeep -Encoding ascii -Force

$lines = New-Object System.Collections.Generic.List[string]

function Add-Section {
    param([string]$Name, [scriptblock]$Cmd)
    $lines.Add("") | Out-Null
    $lines.Add("===== $Name =====") | Out-Null
    try {
        $output = & $Cmd 2>&1 | Out-String -Width 240
        $lines.Add($output.TrimEnd("`r","`n")) | Out-Null
    } catch {
        $lines.Add("ERROR: " + $_.Exception.Message) | Out-Null
    }
}

# ---------- Step 1: state.json ----------
Write-Host "==[1/5]== Dumping state.json from $instDir"

Add-Section 'instance dir listing' {
    if (Test-Path $instDir) {
        Get-ChildItem $instDir |
            Select-Object Name, Length, LastWriteTime |
            Format-Table -AutoSize | Out-String -Width 240
    } else {
        "MISSING: $instDir"
    }
}

Add-Section 'state.json copy + key fields' {
    $state = Join-Path $instDir 'state.json'
    if (Test-Path $state) {
        Copy-Item $state (Join-Path $logsDir 'state.json') -Force
        $j = Get-Content $state -Raw | ConvertFrom-Json
        $rows = New-Object System.Collections.Generic.List[string]
        $rows.Add("Copied state.json -> $logsDir\state.json")
        $rows.Add("")
        $rows.Add("--- top-level NoteProperty members ---")
        $members = $j | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
        foreach ($m in $members) { $rows.Add($m) | Out-Null }
        $rows.Add("")
        $rows.Add("--- selected fields ---")
        $rows.Add("installationVersion = $($j.installationVersion)")
        $rows.Add("installationName    = $($j.installationName)")
        $rows.Add("installationPath    = $($j.installationPath)")
        $rows.Add("productId           = $($j.productId)")
        $rows.Add("channelId           = $($j.channelId)")
        $rows.Add("state               = $($j.state)")
        $cnt = ($j.selectedPackages | Measure-Object).Count
        $rows.Add("selectedPackages count = $cnt")
        $rows -join "`n"
    } else {
        "No state.json present at $state"
    }
}

# Snapshot the time so we can identify which dd_*.log files are NEW.
$beforeRunTime = Get-Date

# ---------- Step 2: download bootstrapper ----------
Write-Host ""
Write-Host "==[2/5]== Downloading vs_BuildTools.exe to $tmp"

Add-Section 'Download vs_BuildTools.exe' {
    try {
        Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_BuildTools.exe' `
                          -OutFile $tmp -UseBasicParsing
        $size = (Get-Item $tmp).Length
        "OK  $tmp  ($size bytes)"
    } catch {
        "FAIL: $($_.Exception.Message)"
    }
}

# ---------- Step 3: modify ----------
Write-Host ""
Write-Host "==[3/5]== Running vs_BuildTools.exe modify (5-15 min)."
Write-Host "         A VS Installer window will appear; let it finish."

$argList = @(
    'modify',
    '--passive', '--wait', '--norestart',
    '--installPath', $installPath,
    '--add', 'Microsoft.VisualStudio.Workload.VCTools',
    '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
    '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
)

Add-Section 'modify run command + result' {
    $cmdLine = $tmp + ' ' + ($argList -join ' ')
    Write-Host "Running: $cmdLine"
    $startedAt = Get-Date
    $exeOut    = & $tmp @argList 2>&1 | Out-String -Width 240
    $rc        = $LASTEXITCODE
    $endedAt   = Get-Date
    $dur       = [math]::Round(($endedAt - $startedAt).TotalMinutes, 2)
    @"
Command line: $cmdLine
Started:  $($startedAt.ToString('o'))
Ended:    $($endedAt.ToString('o'))
Duration: $dur min
Exit code: $rc

--- exe stdout/stderr (combined) ---
$($exeOut.TrimEnd("`r","`n"))
--- end exe output ---
"@
}

# ---------- Step 4: gather new logs ----------
Write-Host ""
Write-Host "==[4/5]== Collecting new top-level dd_*.log files (since modify started)"

# Filter: same %TEMP% as round 01, only files modified since the modify started,
# and only top-level dd_*.log (no per-package _NNN_ files - those would be ~200
# per attempt and we don't want to balloon the repo again).
function Get-NewTopLevelLogs {
    Get-ChildItem $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTime -ge $beforeRunTime -and
            $_.Name -notmatch '_\d{3}_'
        } |
        Sort-Object LastWriteTime -Descending
}

Add-Section 'New top-level dd_*.log files (copied to inbox\logs)' {
    $files = Get-NewTopLevelLogs
    if (-not $files) {
        "No new top-level dd_*.log files since $beforeRunTime"
    } else {
        $rows = New-Object System.Collections.Generic.List[string]
        foreach ($f in $files) {
            try {
                Copy-Item $f.FullName -Destination $logsDir -Force
                $rows.Add(("OK   {0}  ({1} bytes)" -f $f.Name, $f.Length))
            } catch {
                $rows.Add(("FAIL {0}: {1}" -f $f.Name, $_.Exception.Message))
            }
        }
        $rows -join "`n"
    }
}

Add-Section 'Tail of newest dd_installer_elevated_*.log (last 80 lines)' {
    $f = Get-ChildItem $env:TEMP -Filter 'dd_installer_elevated_*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $beforeRunTime } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($f) {
        "FROM: $($f.FullName)`n"
        Get-Content $f.FullName -Tail 80 | Out-String -Width 240
    } else {
        "No new dd_installer_elevated_*.log found since $beforeRunTime"
    }
}

Add-Section 'Tail of newest top-level dd_setup_*.log (last 60 lines)' {
    $f = Get-ChildItem $env:TEMP -Filter 'dd_setup_*.log' -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -ge $beforeRunTime -and
                $_.Name -notmatch '_\d{3}_'
            } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($f) {
        "FROM: $($f.FullName)`n"
        Get-Content $f.FullName -Tail 60 | Out-String -Width 240
    } else {
        "No new top-level dd_setup_*.log found since $beforeRunTime"
    }
}

# ---------- Step 5: verify ----------
Write-Host ""
Write-Host "==[5/5]== Verifying via vswhere + cl.exe presence"

Add-Section 'vswhere -requires VC.Tools.x86.x64 (the bootstrap-script probe)' {
    if (Test-Path $vswhere) {
        $out = & $vswhere -all -prerelease `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>&1 | Out-String
        $out = $out.TrimEnd("`r","`n")
        if ([string]::IsNullOrWhiteSpace($out)) {
            "(empty output - vswhere did not find an instance with VC.Tools.x86.x64)"
        } else {
            $out
        }
    } else {
        "vswhere.exe not present at $vswhere"
    }
}

Add-Section 'vswhere -all (full JSON, for context)' {
    if (Test-Path $vswhere) {
        & $vswhere -all -prerelease -format json 2>&1 | Out-String -Width 240
    } else {
        "vswhere.exe not present"
    }
}

Add-Section 'cl.exe search under installPath' {
    $msvcRoot = Join-Path $installPath 'VC\Tools\MSVC'
    if (Test-Path $msvcRoot) {
        $clExes = Get-ChildItem $msvcRoot -Filter 'cl.exe' -Recurse -ErrorAction SilentlyContinue
        if ($clExes) {
            $rows = New-Object System.Collections.Generic.List[string]
            foreach ($cl in $clExes) {
                $ver = (Get-Item $cl.FullName).VersionInfo.FileVersion
                $rows.Add("FOUND  $($cl.FullName)  (FileVersion=$ver, Length=$($cl.Length))")
            }
            $rows -join "`n"
        } else {
            "MSVC root exists but no cl.exe found under: $msvcRoot"
        }
    } else {
        "MSVC root does not exist: $msvcRoot"
    }
}

Add-Section 'BuildTools install folder summary (D:\)' {
    if (Test-Path $installPath) {
        $count = (Get-ChildItem -Recurse -Force $installPath -ErrorAction SilentlyContinue | Measure-Object).Count
        "EXISTS: $installPath`nRecursive entry count: $count"
    } else {
        "MISSING: $installPath"
    }
}

Add-Section 'VS-related processes (post-modify)' {
    $procs = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'vs_|setup\.|Microsoft\.VisualStudio|VSInstaller|Installer' }
    if ($procs) {
        $procs | Select-Object Id, ProcessName, StartTime, Path |
            Format-Table -AutoSize | Out-String -Width 240
    } else {
        "(no matching processes)"
    }
}

# ---------- Header + write ----------
$header = @()
$header += "# Snapshot raw output (outbox/02 fix test)"
$header += "# Generated: $(Get-Date -Format o)"
$header += "# Repo root: $repoRoot"
$header += "# Script:    $($MyInvocation.MyCommand.Path)"
$header += ""

$body = ($header -join "`n") + ($lines -join "`n") + "`n"
$body | Out-File -FilePath $rawOut -Encoding utf8

Write-Host ""
Write-Host "==============================================="
Write-Host "Test complete."
Write-Host "  Raw output:  $rawOut"
Write-Host "  Logs dir:    $logsDir"
Write-Host "  Files in logs dir:"
$inLogs = Get-ChildItem $logsDir -ErrorAction SilentlyContinue
if ($inLogs) {
    $inLogs | Format-Table Name, Length, LastWriteTime -AutoSize
} else {
    "  (none)"
}
Write-Host "==============================================="
