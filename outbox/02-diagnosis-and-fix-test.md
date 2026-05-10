# 02 — Diagnosis and a one-line fix to test

Read your snapshot + the four key logs. The bug is found and it's
embarrassingly simple. We've been investigating wrong things for two
days.

## Diagnosis

`Microsoft.VisualStudio.Workload.VCTools` does NOT include the actual
MSVC compiler (`Microsoft.VisualStudio.Component.VC.Tools.x86.x64`)
in its **required** components — only in its **recommended**
components. The default `--passive` install installs only required
components. So the install completed normally, just without the
compiler.

### Evidence (from `inbox/logs/dd_installer_elevated_20260510020313.log`)

**Line 144** — the planned install package list:

```
Property: InstallationPackages, value:
  Microsoft.VisualStudio.Component.Roslyn.Compiler,
  Microsoft.Component.MSBuild,
  Microsoft.VisualStudio.Component.CoreBuildTools,
  Microsoft.VisualStudio.Component.Windows10SDK,
  Microsoft.VisualStudio.Component.VC.CoreBuildTools,
  Microsoft.VisualStudio.Component.VC.Redist.14.Latest,
  Microsoft.VisualStudio.Component.TextTemplating,
  Microsoft.VisualStudio.Component.VC.CoreIde,
  Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core,
  Microsoft.VisualStudio.Component.Windows11SDK.22621
```

`Microsoft.VisualStudio.Component.VC.Tools.x86.x64` is conspicuously
absent.

**Line 5913** — the engine explicitly says it won't install it:

```
Non-installable Package: Microsoft.VisualStudio.Component.VC.Tools.x86.x64,
  version=17.14.36510.44, SelectionState: NotSelected,
  CurrentState: Absent, RequestedState: Absent,
  DetectionState: Absent, PlannedAction: None.
```

**Tail of the log** — install completed successfully:

```
Completed install operation
System Drive Delta (Before - After): 3,797,655,552  (~3.8 GB)
Target Drive Delta (Before - After): 1,408,352,256  (~1.4 GB)
Closing the installer with exit code 0
```

So the installer did exactly what we asked. We just asked for the wrong
thing. `vswhere -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64`
returns nothing because that component literally wasn't installed.

The "ghost instance" `_Instances\0240ddbe` isn't a ghost — it's a real
VS Build Tools install that's missing the C++ compiler. The `vswhere -all`
returning `[]` despite this is a SECONDARY mystery (probably an
incomplete state.json, or a registry-side gap), but it's not what's
blocking us. Even if vswhere saw the instance, our `-requires` filter
would still find it incomplete.

This also explains why **the manual GUI install works**: the GUI
defaults to "include recommended" being checked. The bootstrap script
doesn't set that flag and the install plan changes accordingly.

## The fix

Add one extra `--add` to the script. Verbatim diff against the current
`worker/installer/bootstrap-prereqs.ps1` (lines 325-331):

```diff
         $code = Invoke-Native -Label 'vs_BuildTools' -FilePath $bootstrapper -ArgumentList @(
             $verb,
             '--passive', '--wait', '--norestart',
             '--installPath',  $effectivePath,
             '--add', 'Microsoft.VisualStudio.Workload.VCTools',
+            '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
             '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
         )
```

That's it. We could alternatively pass `--includeRecommended`, but
that pulls in things we don't need (ATL, MFC, spectre-mitigated
libraries, …); the explicit `--add` for the one component we
actually need is cleaner.

## What I want you to do

Test the fix on the existing instance (a `modify` call, not a fresh
install). If `modify` adds the component cleanly, the patched script
will work too. If `modify` fails for instance-state reasons, we need
to handle the secondary mystery first.

### Step 1 — Dump `_Instances\0240ddbe\state.json`

Cheap and we already wanted this. Two minutes.

```powershell
$instDir = "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances\0240ddbe"
Get-ChildItem $instDir | Select-Object Name, Length, LastWriteTime
$state = Join-Path $instDir 'state.json'
if (Test-Path $state) {
  $repo = '<absolute path to your bugtesting clone>'
  Copy-Item $state (Join-Path $repo 'inbox\logs\state.json') -Force
  # Also surface the structurally-interesting top-level keys inline:
  $j = Get-Content $state -Raw | ConvertFrom-Json
  $j | Get-Member -MemberType NoteProperty | Select-Object Name | Format-Table -Auto
  $j.installationVersion
  $j.installationName
  $j.installationPath
  ($j.selectedPackages | Measure-Object).Count
} else {
  Write-Host "No state.json present"
}
```

Drop the file in `inbox/logs/state.json` and paste the inline output
into `inbox/02-diagnosis-test.md`.

### Step 2 — Run a `modify` against the existing instance with the fix

This is the actual test of the fix. We're using `modify` against the
existing `0240ddbe` install path so we don't have to download +
re-extract from scratch (saves ~15-20 min).

```powershell
$tmp = Join-Path $env:TEMP 'vs_BuildTools_test.exe'
Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_BuildTools.exe' `
                  -OutFile $tmp -UseBasicParsing

# Same args as the patched bootstrap script would use, but verb=modify.
$args = @(
  'modify',
  '--passive', '--wait', '--norestart',
  '--installPath', 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools',
  '--add', 'Microsoft.VisualStudio.Workload.VCTools',
  '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',  # the new one
  '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
)
Write-Host "Running: $tmp $($args -join ' ')"
$startedAt = Get-Date
& $tmp @args
$rc = $LASTEXITCODE
$endedAt = Get-Date
Write-Host "Exit code: $rc"
Write-Host "Duration: $([math]::Round(($endedAt - $startedAt).TotalMinutes, 1)) min"
```

Then verify with vswhere (the same probe the bootstrap script uses):

```powershell
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
```

Three possible outcomes:

1. **vswhere prints the install path** → fix works, we're done. Patch
   the bootstrap script and ship.
2. **vswhere prints nothing but `cl.exe` exists on disk under
   `<installPath>\VC\Tools\MSVC\<ver>\bin\Hostx64\x64\cl.exe`** → C++
   compiler installed, but the secondary "vswhere doesn't see this
   instance" mystery is real. We'll need to patch the bootstrap script
   AND solve that. Drop a `Get-ChildItem` of the cl.exe path to
   confirm.
3. **vswhere prints nothing AND no `cl.exe` on disk** → the fix is
   wrong or there's a deeper issue. Worst case; we'd need a fresh
   install run.

### Step 3 — Report

Put the results in `inbox/02-diagnosis-test.md` with structure:

```markdown
# 02 — diagnosis test

## state.json
<inline keys + reference to inbox/logs/state.json>

## modify run
Started: …
Ended:   …
Exit code: …
(Tail any new dd_installer_*.log)

## vswhere check
Output:

## cl.exe check
Path tested: <installPath>\VC\Tools\MSVC\…\bin\Hostx64\x64\cl.exe
Exists: yes/no

## Verdict
Outcome 1 / 2 / 3 from the brief above. Optional notes.
```

Commit + push. I'll patch the bootstrap script and write
`outbox/03-*.md` with deployment instructions, OR follow up on the
secondary mystery if outcome was 2.

## Estimated time

- state.json dump: 2 min
- modify run: ~5-15 min depending on what needs downloading
  (recommended C++ compiler is ~1.5 GB). The existing install is at
  D:\, free space there is plenty (1.8 TB).
- vswhere + cl.exe checks + report: 5 min

Total: ~15-20 min wall clock.

## What we are NOT doing

- NOT touching the bootstrap script yet — I'll patch it on the dev
  box once your test confirms the fix.
- NOT trying parens-free path or `--quiet` — those hypotheses are
  irrelevant given the actual bug.
- NOT cleaning up the existing 0240ddbe instance — we want the
  `modify` to mutate it in place.
