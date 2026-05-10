# 04 — Fresh-install validation (the test we should have run first)

User's call. The `modify` test in round 02 only proved that the
corrected arg list registers `VC.Tools.x86.x64` against an instance
whose payload was *already extracted* from yesterday's eight failed
runs. A real first-time install hits a different code path:

- Verb is `install`, not `modify`
- Engine has to plan + download + extract MSVC payload (~1.5 GB)
- The "non-installable Package: VC.Tools.x86.x64 ... PlannedAction:
  None" line we found at L5913 of the failed installer log was logged
  during an `install` run — we need to confirm that adding `--add
  VC.Tools.x86.x64` flips that plan in an `install` context, not just
  a `modify` one.

Highly likely the fix works for both verbs (the engine's
required-vs-recommended logic should be verb-agnostic), but "highly
likely" isn't a shipped feature. Let's actually verify.

## Step 1 — Tear down

Uninstall the existing instance + scrub the cache + delete the
install folder. We want a real "VS not present anywhere" starting
state, the same one a customer would hit on a fresh box.

```powershell
# Confirm what we're about to nuke.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products * -property installationPath
# Expect: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

# Uninstall via the VS Installer (passive, no prompts).
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe" `
  uninstall `
  --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
  --passive --wait --norestart
# Expect: 5-15 min depending on disk speed. The window will close itself.

# Verify gone.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products * -property installationPath
# Expect: empty
```

If the install folder + `_Instances` entry survive the uninstall (VS
Installer is sometimes lazy about cleanup):

```powershell
# Scrub anything left behind.
Remove-Item -Recurse -Force `
  "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances\0240ddbe" `
  -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force `
  "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
  -ErrorAction SilentlyContinue

# DO NOT delete %ProgramData%\Microsoft\VisualStudio\Packages\* (the
# main package cache). That holds the downloaded payloads which speed
# up subsequent installs; nuking it forces a full re-download
# (~5+ GB) which we don't need to test the fix.

# Confirm clean state.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products * -property installationPath
# Expect: empty
Get-ChildItem "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances" -ErrorAction SilentlyContinue
# Expect: empty (no folders)
Test-Path "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
# Expect: False
```

## Step 2 — Run the patched bootstrap-prereqs.ps1

Pull the patched script. Two ways to get it:

**A) From the rpg-buildserver repo (canonical source):**

```powershell
# If you have the repo cloned, just git pull. Otherwise:
$bs = Join-Path $env:TEMP 'bootstrap-prereqs.ps1'
Invoke-WebRequest `
  -Uri 'https://raw.githubusercontent.com/ivanmoen/rpg-buildserver/main/worker/installer/bootstrap-prereqs.ps1' `
  -OutFile $bs -UseBasicParsing
# (Note: this assumes the patch has been pushed to origin/main.
# If git push hasn't happened yet, use option B instead.)
```

**B) From this `bugtesting` repo's `context/` (which I synced after
the patch landed):**

```powershell
# git pull the bugtesting repo to make sure context/ is current,
# then point at it.
cd <your bugtesting clone>
git pull
$bs = Resolve-Path .\context\bootstrap-prereqs.ps1
```

Sanity check the script has the fix:

```powershell
Select-String -Path $bs -Pattern 'VC\.Tools\.x86\.x64'
# Expect TWO lines:
#   - one inside the --add args (the actual fix)
#   - one inside the failure-path message
```

Run it (elevated). The script will download a fresh `vs_BuildTools.exe`
and run `install` (not `modify`, because we just nuked the existing
instance):

```powershell
$startedAt = Get-Date
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bs `
  -VsInstallPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
$rc = $LASTEXITCODE
$endedAt = Get-Date
Write-Host "Bootstrap exit code: $rc"
Write-Host "Bootstrap duration : $([math]::Round(($endedAt - $startedAt).TotalMinutes, 1)) min"
```

Expected behavior:
- TortoiseSVN: detected as already present, skipped
- VS Build Tools: detected as missing, runs `install` with the new
  arg list. Should take ~5-20 min depending on whether the package
  cache had to re-fetch payloads. The VS Installer's progress UI
  should be visible (you're using `--passive`, not `--quiet`).
- Bootstrap script's own log: at the end, the `Test-MsvcPresent`
  probe should PASS, and you should see something like
  `[INFO] VS with C++ workload installed at D:\Program Files (x86)\...`
  with `cl.exe` actually present.
- Exit code: 0.

If the script fails: it WILL print the diagnostic message I tightened
in this round. Don't panic, capture the new
`%TEMP%\dd_installer_elevated_*.log` and `%TEMP%\dd_setup_*.log`
plus the `%ProgramData%\RPGBuildServer\logs\bootstrap-prereqs.log`,
zip them, and we go again.

## Step 3 — Verify the install

Same probes as round 02:

```powershell
# What the bootstrap script's own probe sees.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
# Expect: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

# Direct cl.exe presence check (belt + suspenders).
Get-ChildItem "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC" -ErrorAction SilentlyContinue |
  ForEach-Object {
    $cl = Join-Path $_.FullName 'bin\Hostx64\x64\cl.exe'
    "$cl  exists=$(Test-Path $cl)"
  }
# Expect: at least one cl.exe path with exists=True

# Confirm install folder grew to the expected size.
$root = "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
if (Test-Path $root) {
  $count = (Get-ChildItem $root -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
  $size  = (Get-ChildItem $root -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
  Write-Host "Recursive entries: $count"
  Write-Host "Total size: $([math]::Round($size/1GB, 2)) GB"
}
# Expect: ~12,000-15,000 entries, ~3-5 GB
```

## Step 4 — Report

Write `inbox/04-fresh-install-validation.md` with structure:

```markdown
# 04 — fresh install validation

## Tear-down result
<exit codes / states from step 1>

## Bootstrap run
Started: ...
Ended:   ...
Bootstrap script exit code: ...
(Tail of %ProgramData%\RPGBuildServer\logs\bootstrap-prereqs.log)

## Install verification
vswhere result: ...
cl.exe paths found: ...
Install folder: <count> entries, <size> GB

## New diagnostic logs (for archive)
List of new dd_installer_*.log + dd_setup_*.log timestamps.
Drop the elevated installer log and the latest setup log into
inbox/logs/ — small, no zip needed.

## Verdict
PASS / FAIL with one-line reason. PASS = bootstrap exit 0 + cl.exe
present + vswhere happy.
```

Commit + push.

## What we are NOT doing

- NOT testing on dev box (already has full VS install; would just hit
  Test-MsvcPresent skip path, useless test).
- NOT spinning up a VM (overkill for a single arg validation).
- NOT touching anything in production until this passes.

## Time estimate

- Tear-down: 10-20 min (VS uninstall is the slow part)
- Bootstrap run: 5-20 min (depends on package cache hit rate)
- Verify + report: 10 min

Total: 30-50 min wall clock.

## If you don't have time

Tell me. We can ship as-is and accept that real-world validation will
happen the first time someone bootstraps a clean worker. The risk is
small (the fix is engine-side and almost certainly verb-agnostic),
and we have a clear log-capture story if it does fail in the wild.
But with you available right now, doing the actual validation is
clearly worth 30-50 min of test PC time.
