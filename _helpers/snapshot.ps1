# _helpers\snapshot.ps1
# Diagnostic snapshot for outbox\01-initial-brief.md.
# Read-only: enumerates state, copies surviving logs into inbox\logs\.
# Does NOT install anything. Safe to run non-elevated; elevated is also fine.
# PS 5.1 compatible. ASCII only.

$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$inbox    = Join-Path $repoRoot 'inbox'
$logsDir  = Join-Path $inbox    'logs'
$rawOut   = Join-Path $inbox    '01-snapshot-raw.txt'

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

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

# --- Identity / handshake info ---
Add-Section 'HOSTNAME' { $env:COMPUTERNAME }
Add-Section 'USERNAME' { $env:USERNAME }
Add-Section 'IS-ELEVATED' {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object System.Security.Principal.WindowsPrincipal($id)
    $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}
Add-Section 'TEMP-PATH' { $env:TEMP }
Add-Section 'USERPROFILE-TEMP' { Join-Path $env:USERPROFILE 'AppData\Local\Temp' }

# --- Step 1: OS / shell ---
Add-Section 'OSVersion.VersionString' {
    [System.Environment]::OSVersion.VersionString
}
Add-Section 'PSVersionTable' {
    $PSVersionTable | Format-List | Out-String -Width 240
}
Add-Section 'Get-ComputerInfo (selected)' {
    Get-ComputerInfo |
      Select-Object OsName, OsVersion, OsBuildNumber, WindowsProductName, OsArchitecture |
      Format-List | Out-String -Width 240
}

# --- Step 1: Disk ---
Add-Section 'Get-PSDrive (FileSystem)' {
    Get-PSDrive -PSProvider FileSystem |
      Select-Object Name,
        @{N='FreeGB';E={[math]::Round($_.Free/1GB,1)}},
        @{N='UsedGB';E={[math]::Round($_.Used/1GB,1)}} |
      Format-Table -AutoSize | Out-String -Width 240
}

# --- Step 1: vswhere ---
Add-Section 'vswhere.exe -all -prerelease -format json' {
    $vsw = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vsw) {
        & $vsw -all -prerelease -format json 2>&1 | Out-String -Width 240
    } else {
        "vswhere.exe NOT PRESENT at $vsw"
    }
}

# --- Step 1: _Instances ghost-instance check ---
Add-Section 'VS Packages _Instances' {
    $p = "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances"
    if (Test-Path $p) {
        $items = Get-ChildItem $p -ErrorAction SilentlyContinue
        if ($items) {
            $items | Format-Table Name, LastWriteTime -AutoSize | Out-String -Width 240
        } else {
            "Path exists but is empty: $p"
        }
    } else {
        "Path does not exist: $p"
    }
}

# --- Step 1: SVN sanity ---
Add-Section 'svn (Get-Command)' {
    $c = Get-Command svn -ErrorAction SilentlyContinue
    if ($c) {
        $c | Select-Object Source, Version | Format-List | Out-String -Width 240
    } else {
        "svn not found on PATH"
    }
}

# --- Step 2: wanted-log presence check ---
$wanted = @(
  'dd_installer_20260510021008.log',
  'dd_installer_elevated_20260510020313.log',
  'dd_setup_20260510021015.log',
  'dd_setup_20260510021015_errors.log'
)
Add-Section 'Wanted log files (in $env:TEMP)' {
    $rows = foreach ($name in $wanted) {
        $p = Join-Path $env:TEMP $name
        if (Test-Path $p) {
            $size = (Get-Item $p).Length
            "FOUND   $name ($size bytes)"
        } else {
            "MISSING $name"
        }
    }
    $rows -join "`n"
}

# --- Step 2: full dd_*.log inventory in $env:TEMP ---
Add-Section 'All dd_*.log in $env:TEMP (newest first)' {
    $files = Get-ChildItem $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue |
              Sort-Object LastWriteTime -Descending
    if ($files) {
        $files | Format-Table Name, LastWriteTime, Length -AutoSize | Out-String -Width 240
    } else {
        "No dd_*.log files in $env:TEMP"
    }
}

# --- Defensive: also check user-profile temp in case elevation moved %TEMP% ---
$userTemp = Join-Path $env:USERPROFILE 'AppData\Local\Temp'
Add-Section 'All dd_*.log in $env:USERPROFILE\AppData\Local\Temp (newest first)' {
    if ($userTemp -ieq $env:TEMP) {
        "Same path as `$env:TEMP, skipped."
    } else {
        $files = Get-ChildItem $userTemp -Filter 'dd_*.log' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending
        if ($files) {
            $files | Format-Table Name, LastWriteTime, Length -AutoSize | Out-String -Width 240
        } else {
            "No dd_*.log files in $userTemp"
        }
    }
}

# --- Step 2 cont.: copy dd_*.log into inbox\logs ---
Add-Section 'Copy dd_*.log -> inbox\logs (from both temp dirs)' {
    $sources = @($env:TEMP)
    if ($userTemp -ine $env:TEMP) { $sources += $userTemp }
    $rows = New-Object System.Collections.Generic.List[string]
    foreach ($src in $sources) {
        $files = Get-ChildItem $src -Filter 'dd_*.log' -ErrorAction SilentlyContinue
        if (-not $files) {
            $rows.Add("(no dd_*.log in $src)")
            continue
        }
        foreach ($f in $files) {
            try {
                Copy-Item $f.FullName -Destination $logsDir -Force
                $rows.Add("OK   $($f.Name)  ($($f.Length) bytes)  from $src")
            } catch {
                $rows.Add("FAIL $($f.Name): $($_.Exception.Message)")
            }
        }
    }
    $rows -join "`n"
}

# --- Step 3: bootstrap log ---
Add-Section 'Bootstrap log presence + tail' {
    $bs = "$env:ProgramData\RPGBuildServer\logs\bootstrap-prereqs.log"
    if (Test-Path $bs) {
        $size = (Get-Item $bs).Length
        Copy-Item $bs (Join-Path $logsDir 'bootstrap-prereqs.log') -Force
        $tail = (Get-Content $bs -Tail 50 | Out-String).TrimEnd("`r","`n")
        "FOUND ($size bytes), copied to inbox\logs\bootstrap-prereqs.log`n--- last 50 lines ---`n$tail`n--- end tail ---"
    } else {
        "MISSING: $bs"
    }
}

# --- Bonus observations: BuildTools install folders (the brief hints at this) ---
Add-Section 'BuildTools install folder D:\Program Files (x86)\...\BuildTools' {
    $p = 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
    if (Test-Path $p) {
        $count = (Get-ChildItem -Recurse -Force $p -ErrorAction SilentlyContinue | Measure-Object).Count
        $top   = Get-ChildItem $p -ErrorAction SilentlyContinue | Format-Table Name, Mode, LastWriteTime -AutoSize | Out-String -Width 240
        "EXISTS: $p`nRecursive entry count: $count`nTop-level:`n$top"
    } else {
        "MISSING: $p"
    }
}
Add-Section 'BuildTools install folder C:\Program Files (x86)\...\BuildTools' {
    $p = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools"
    if (Test-Path $p) {
        $count = (Get-ChildItem -Recurse -Force $p -ErrorAction SilentlyContinue | Measure-Object).Count
        $top   = Get-ChildItem $p -ErrorAction SilentlyContinue | Format-Table Name, Mode, LastWriteTime -AutoSize | Out-String -Width 240
        "EXISTS: $p`nRecursive entry count: $count`nTop-level:`n$top"
    } else {
        "MISSING: $p"
    }
}

# --- Bonus: any orphan VS installer processes ---
Add-Section 'VS-related processes' {
    $procs = Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -match 'vs_|setup\.|Microsoft\.VisualStudio|VSInstaller|Installer' }
    if ($procs) {
        $procs | Select-Object Id, ProcessName, StartTime, Path |
            Format-Table -AutoSize | Out-String -Width 240
    } else {
        "(no matching processes)"
    }
}

# --- Header + write ---
$header = @()
$header += "# Snapshot raw output (outbox/01)"
$header += "# Generated: $(Get-Date -Format o)"
$header += "# Repo root: $repoRoot"
$header += "# Script:    $($MyInvocation.MyCommand.Path)"
$header += ""

$body = ($header -join "`n") + ($lines -join "`n") + "`n"

# UTF-8 with BOM is the default for Out-File -Encoding utf8 on PS 5.1; that's fine.
$body | Out-File -FilePath $rawOut -Encoding utf8

# --- Console summary ---
""
"==============================================="
"Snapshot complete."
"  Raw output:  $rawOut"
"  Logs dir:    $logsDir"
"  Files in logs dir:"
$inLogs = Get-ChildItem $logsDir -ErrorAction SilentlyContinue
if ($inLogs) {
    $inLogs | Format-Table Name, Length, LastWriteTime -AutoSize
} else {
    "  (none)"
}
"==============================================="
