# _helpers\fresh-install-validation.ps1
# Implements outbox\04-fresh-install-validation.md.
# 1) Confirm pre-state, then uninstall existing VS Build Tools install on D:\ via vs_installer.exe.
# 2) Scrub leftover _Instances\0240ddbe and the install folder if they survived.
# 3) Run the patched context\bootstrap-prereqs.ps1 (a real install, not modify).
# 4) Verify post-install via vswhere + cl.exe + folder size.
# 5) Capture top-level dd_*.log files + the new bootstrap-prereqs.log.
# Captures everything to inbox\04-validation-raw.txt.
# REQUIRED: elevated PS 5.1.
# DESTRUCTIVE: this uninstalls VS Build Tools 2022 from this machine, then re-installs.
# ASCII only.

$ErrorActionPreference = 'Continue'

# Make sure HTTPS works on the surface (the bootstrap script will re-download vs_BuildTools.exe).
try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch {}

$repoRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$inbox       = Join-Path $repoRoot 'inbox'
$logsDir     = Join-Path $inbox    'logs'
$rawOut      = Join-Path $inbox    '04-validation-raw.txt'

$vswhere     = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstaller = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
$installPath = 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools'
$instRoot    = Join-Path $env:ProgramData 'Microsoft\VisualStudio\Packages\_Instances'
$bootstrap   = Join-Path $repoRoot 'context\bootstrap-prereqs.ps1'
$bsLog       = Join-Path $env:ProgramData 'RPGBuildServer\logs\bootstrap-prereqs.log'

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

# ---------- Step 0: Sanity-check the patched bootstrap script ----------
Write-Host "==[0/6]== Verifying the patched bootstrap script is in place"

Add-Section 'Patched bootstrap script presence + VC.Tools.x86.x64 grep' {
    if (-not (Test-Path $bootstrap)) {
        "MISSING: $bootstrap"
    } else {
        $hash = (Get-FileHash $bootstrap -Algorithm SHA256).Hash
        $size = (Get-Item $bootstrap).Length
        "PATH:   $bootstrap"
        "SIZE:   $size bytes"
        "SHA256: $hash"
        ""
        "--- lines containing 'VC.Tools.x86.x64' (expect at least one in --add args) ---"
        Select-String -Path $bootstrap -Pattern 'VC\.Tools\.x86\.x64' |
            ForEach-Object { "  L{0,4}: {1}" -f $_.LineNumber, $_.Line.Trim() } |
            Out-String -Width 240
    }
}

# ---------- Step 1: Pre-flight ----------
Write-Host "==[1/6]== Pre-flight: confirming current state before tear-down"

Add-Section 'Pre-tear-down: vswhere -all -prerelease -products *' {
    if (Test-Path $vswhere) {
        $out = & $vswhere -all -prerelease -products * -property installationPath 2>&1 | Out-String
        $out.TrimEnd("`r","`n")
    } else {
        "vswhere.exe not present"
    }
}

Add-Section 'Pre-tear-down: install folder + _Instances state' {
    $rows = New-Object System.Collections.Generic.List[string]
    if (Test-Path $installPath) {
        $cnt = (Get-ChildItem -Recurse -Force $installPath -ErrorAction SilentlyContinue | Measure-Object).Count
        $rows.Add("install folder: EXISTS ($installPath, entries=$cnt)")
    } else {
        $rows.Add("install folder: MISSING")
    }
    if (Test-Path $instRoot) {
        $items = Get-ChildItem $instRoot -ErrorAction SilentlyContinue
        if ($items) {
            $rows.Add("_Instances entries: " + (($items.Name) -join ', '))
        } else {
            $rows.Add("_Instances: empty")
        }
    } else {
        $rows.Add("_Instances directory: MISSING")
    }
    $rows -join "`n"
}

# Snapshot the time so we can identify which dd_*.log files are NEW.
$beforeRunTime = Get-Date

# ---------- Step 2: vs_installer uninstall ----------
Write-Host ""
Write-Host "==[2/6]== Running vs_installer.exe uninstall (5-15 min). VS Installer UI will appear."

Add-Section 'vs_installer.exe uninstall result' {
    # NOTE: vs_installer.exe accepts --passive and --norestart but NOT --wait.
    # That's a vs_BuildTools.exe-only flag; the GUI shell doesn't recognize it
    # (exit code 87 = "Option 'wait' is unknown.").
    if (-not (Test-Path $vsInstaller)) {
        "vs_installer.exe NOT PRESENT at $vsInstaller (cannot uninstall via passive flow)"
    } elseif (-not (Test-Path $installPath)) {
        "Install folder already gone, skipping uninstall step"
    } else {
        $cmdLine = "$vsInstaller uninstall --installPath `"$installPath`" --passive --norestart"
        Write-Host "Running: $cmdLine"
        $startedAt = Get-Date
        $exeOut    = & $vsInstaller uninstall `
                        --installPath $installPath `
                        --passive --norestart 2>&1 | Out-String -Width 240
        $rc        = $LASTEXITCODE
        $endedAt   = Get-Date
        $dur       = [math]::Round(($endedAt - $startedAt).TotalMinutes, 2)
        # Even with --passive, vs_installer.exe forks a UI process and returns
        # before that UI finishes. Poll the install folder so we don't fall
        # through into our scrub step while the uninstaller is still working.
        $waited = 0
        while ((Test-Path $installPath) -and ($waited -lt 1200)) {
            Start-Sleep -Seconds 5
            $waited += 5
        }
        @"
Command line: $cmdLine
Started:  $($startedAt.ToString('o'))
Ended:    $($endedAt.ToString('o'))
Duration: $dur min
Exit code: $rc
Polled for install folder removal: $waited s (cap 1200 s)
Install folder still present after wait: $(Test-Path $installPath)

--- vs_installer stdout/stderr (combined) ---
$($exeOut.TrimEnd("`r","`n"))
--- end output ---
"@
    }
}

# ---------- Step 3: Scrub leftovers ----------
Write-Host ""
Write-Host "==[3/6]== Scrubbing leftovers (instance dir, install folder)"

Add-Section 'Post-uninstall verify + scrub' {
    $rows = New-Object System.Collections.Generic.List[string]

    # Check vswhere
    if (Test-Path $vswhere) {
        $found = & $vswhere -all -prerelease -products * -property installationPath 2>&1 | Out-String
        $found = $found.TrimEnd("`r","`n")
        if ([string]::IsNullOrWhiteSpace($found)) {
            $rows.Add("vswhere after uninstall: empty (good)")
        } else {
            $rows.Add("vswhere after uninstall: still finds: $found")
        }
    }

    # Scrub EVERY surviving _Instances\* entry (handles whatever ghost
    # is there, not just the one from yesterday).
    if (Test-Path $instRoot) {
        $ghosts = Get-ChildItem $instRoot -Directory -ErrorAction SilentlyContinue
        if ($ghosts) {
            foreach ($g in $ghosts) {
                try {
                    Remove-Item -Recurse -Force $g.FullName -ErrorAction Stop
                    $rows.Add("scrub _Instances\$($g.Name): OK (was present, now removed)")
                } catch {
                    $rows.Add("scrub _Instances\$($g.Name): FAIL ($($_.Exception.Message))")
                }
            }
        } else {
            $rows.Add("scrub _Instances\*: nothing to remove (uninstall handled it)")
        }
    } else {
        $rows.Add("scrub _Instances\*: directory not present")
    }

    # Scrub install folder if it survived
    if (Test-Path $installPath) {
        try {
            Remove-Item -Recurse -Force $installPath -ErrorAction Stop
            $rows.Add("scrub install folder: OK (was present, now removed)")
        } catch {
            $rows.Add("scrub install folder: FAIL ($($_.Exception.Message))")
        }
    } else {
        $rows.Add("scrub install folder: not present (uninstall handled it)")
    }

    # Confirm clean state
    if (Test-Path $vswhere) {
        $found = & $vswhere -all -prerelease -products * -property installationPath 2>&1 | Out-String
        $found = $found.TrimEnd("`r","`n")
        if ([string]::IsNullOrWhiteSpace($found)) {
            $rows.Add("clean state: vswhere empty (good)")
        } else {
            $rows.Add("clean state: vswhere still finds: $found (BAD)")
        }
    }

    if (Test-Path $instRoot) {
        $remaining = Get-ChildItem $instRoot -ErrorAction SilentlyContinue
        if ($remaining) {
            $rows.Add("clean state: _Instances has folders: " + (($remaining.Name) -join ', '))
        } else {
            $rows.Add("clean state: _Instances empty (good)")
        }
    } else {
        $rows.Add("clean state: _Instances directory not present (good)")
    }

    $rows.Add("clean state: install folder exists = $(Test-Path $installPath)")

    $rows -join "`n"
}

# ---------- Step 4: Run the patched bootstrap script ----------
Write-Host ""
Write-Host "==[4/6]== Running patched bootstrap-prereqs.ps1 (5-20 min, fresh install)"
Write-Host "         A VS Installer window will appear; let it finish."

Add-Section 'Patched bootstrap-prereqs.ps1 run' {
    $cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap -VsInstallPath `"$installPath`""
    Write-Host "Running: $cmdLine"
    $startedAt = Get-Date
    $exeOut    = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap `
                    -VsInstallPath $installPath 2>&1 | Out-String -Width 240
    $rc        = $LASTEXITCODE
    $endedAt   = Get-Date
    $dur       = [math]::Round(($endedAt - $startedAt).TotalMinutes, 2)
    @"
Command line: $cmdLine
Started:  $($startedAt.ToString('o'))
Ended:    $($endedAt.ToString('o'))
Duration: $dur min
Exit code: $rc

--- bootstrap stdout/stderr (combined) ---
$($exeOut.TrimEnd("`r","`n"))
--- end output ---
"@
}

# ---------- Step 5: Verify ----------
Write-Host ""
Write-Host "==[5/6]== Verifying install via vswhere + cl.exe + folder size"

Add-Section 'vswhere -all -prerelease -products * -requires VC.Tools.x86.x64' {
    if (Test-Path $vswhere) {
        $out = & $vswhere -all -prerelease -products * `
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
            -property installationPath 2>&1 | Out-String
        $out = $out.TrimEnd("`r","`n")
        if ([string]::IsNullOrWhiteSpace($out)) {
            "(empty - vswhere did not find an instance with VC.Tools.x86.x64)"
        } else {
            $out
        }
    } else {
        "vswhere.exe not present"
    }
}

Add-Section 'vswhere -all -prerelease -products * (no requires filter)' {
    if (Test-Path $vswhere) {
        $out = & $vswhere -all -prerelease -products * -property installationPath 2>&1 | Out-String
        $out.TrimEnd("`r","`n")
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

Add-Section 'Install folder summary' {
    if (Test-Path $installPath) {
        $items = Get-ChildItem $installPath -Recurse -Force -ErrorAction SilentlyContinue
        $cnt = ($items | Measure-Object).Count
        $size = ($items | Measure-Object Length -Sum).Sum
        $sizeGB = [math]::Round($size/1GB, 2)
        @"
EXISTS: $installPath
Recursive entries: $cnt
Total size: $sizeGB GB
"@
    } else {
        "MISSING: $installPath"
    }
}

Add-Section '_Instances state (post-install)' {
    if (Test-Path $instRoot) {
        $items = Get-ChildItem $instRoot -ErrorAction SilentlyContinue
        if ($items) {
            $items | Format-Table Name, LastWriteTime -AutoSize | Out-String -Width 240
        } else {
            "Path exists but empty: $instRoot"
        }
    } else {
        "MISSING: $instRoot"
    }
}

# ---------- Step 6: Gather logs ----------
Write-Host ""
Write-Host "==[6/6]== Collecting new top-level dd_*.log files + bootstrap-prereqs.log"

Add-Section 'Copy new top-level dd_*.log files to inbox\logs' {
    $files = Get-ChildItem $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.LastWriteTime -ge $beforeRunTime -and
                    $_.Name -notmatch '_\d{3}_'
                } |
                Sort-Object LastWriteTime -Descending
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

Add-Section 'Copy bootstrap-prereqs.log (renamed to *-fresh-install.log)' {
    if (Test-Path $bsLog) {
        $size = (Get-Item $bsLog).Length
        $dest = Join-Path $logsDir 'bootstrap-prereqs-fresh-install.log'
        Copy-Item $bsLog $dest -Force
        @"
OK   Copied $bsLog -> $dest ($size bytes)

--- last 80 lines ---
$((Get-Content $bsLog -Tail 80 | Out-String -Width 240).TrimEnd("`r","`n"))
"@
    } else {
        "MISSING: $bsLog (bootstrap script did not write its log)"
    }
}

Add-Section 'Tail of newest dd_installer_elevated_*.log (last 60 lines)' {
    $f = Get-ChildItem $env:TEMP -Filter 'dd_installer_elevated_*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -ge $beforeRunTime } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
    if ($f) {
        "FROM: $($f.FullName)`n"
        Get-Content $f.FullName -Tail 60 | Out-String -Width 240
    } else {
        "No new dd_installer_elevated_*.log since $beforeRunTime"
    }
}

# ---------- Header + write ----------
$header = @()
$header += "# Snapshot raw output (outbox/04 fresh-install validation)"
$header += "# Generated: $(Get-Date -Format o)"
$header += "# Repo root: $repoRoot"
$header += "# Script:    $($MyInvocation.MyCommand.Path)"
$header += ""

$body = ($header -join "`n") + ($lines -join "`n") + "`n"
$body | Out-File -FilePath $rawOut -Encoding utf8

Write-Host ""
Write-Host "==============================================="
Write-Host "Validation run complete."
Write-Host "  Raw output:  $rawOut"
Write-Host "  Logs dir:    $logsDir"
Write-Host "==============================================="
