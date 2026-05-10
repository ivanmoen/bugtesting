# Bootstrap prereqs — investigation log (2026-05-09 → 2026-05-11)

## Resolution (2026-05-11)

**Root cause: the `--add Microsoft.VisualStudio.Workload.VCTools` arg
alone does not pull in `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`
(the actual MSVC `cl.exe` compiler).** The compiler is in the
workload's *recommended* component set, not its *required* set, and
`--passive` installs required-only by default. So every yesterday's
attempts completed successfully (~5 GB on disk) — they just installed
the workload's scaffolding without the compiler the worker needs.

`vswhere -requires VC.Tools.x86.x64` correctly returned nothing, the
script reported failure, and we spent ~6 hours debugging the wrong
hypothesis space.

**Fix (one line in `bootstrap-prereqs.ps1`):**

```diff
             '--add', 'Microsoft.VisualStudio.Workload.VCTools',
+            '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
             '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
```

**Verified 2026-05-11** in two rounds:

- **Round 02 (modify)**: `vs_BuildTools.exe modify` against the test
  PC's existing 0240ddbe instance with the corrected arg list. Result:
  `cl.exe` v19.44.35226.0 landed at
  `<installPath>\VC\Tools\MSVC\14.44.35207\bin\Host{x64,x86}\{x64,x86}\cl.exe`,
  vswhere `-products * -requires VC.Tools.x86.x64` finds the install.
  ~42 s wall clock (because the payload was already on disk from
  yesterday's failed runs).
- **Round 04 (fresh install)**: full uninstall + scrub, then patched
  `bootstrap-prereqs.ps1` ran with `verb=install` against an empty
  state. Result: same `cl.exe` v19.44.35226.0 in the same paths, +3 GB
  on target drive, ~2.27 min wall clock (most of that drawn from the
  package cache; a genuinely-cold cache would be 10-20 min). Confirms
  the engine's required-vs-recommended logic is verb-agnostic — the
  fix lands correctly on both the modify path AND the install path.

`--includeRecommended` would have worked too but pulls in
ATL/MFC/Spectre we don't need; the explicit `--add` is cleaner.

**Diagnostic logs are preserved** in the `bugtesting` repo at
`inbox/logs/dd_installer_elevated_20260510020313.log` (the failed
install) and `inbox/logs/dd_installer_elevated_20260510120236.log`
(the successful modify). Smoking-gun lines in the failed log:
- L144: `InstallationPackages` enumerates planned components — `VC.Tools.x86.x64` is conspicuously absent
- L5913: `Non-installable Package: Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ... PlannedAction: None.`

The hypothesis section below is preserved for posterity, but #1-#5
were all wrong — none were the actual cause. `bootstrap-prereqs.ps1`
is fixed; the rest of this doc is historical record.

Manual GUI install always worked because the GUI defaults to "include
recommended" being checked. We'd have caught this faster if we'd
diffed the GUI's install plan against ours instead of theorizing about
encoding / quoting / OS quirks.

---

## Original investigation (2026-05-09 → 2026-05-10)

Honest accounting of `worker/installer/bootstrap-prereqs.ps1` and what
happened during the first end-to-end test on a clean-ish Windows 11 24H2
box. The auto-install path **does not currently meet its goal**; this doc
captures what works, what doesn't, what we ruled out, and what to try
next.

## What the bootstrap is supposed to do

Triggered by the Inno Setup installer (or runnable directly from
`{app}\bootstrap-prereqs.ps1`). On a clean Windows box, install the
non-Unreal build prerequisites silently:

1. **TortoiseSVN** — the worker's `svn` shell-out target.
2. **VS Build Tools 2022** with the `Microsoft.VisualStudio.Workload.VCTools`
   workload + Windows 11 SDK — required by Unreal's RunUAT BuildCookRun
   for any C++ compilation.

The Inno installer has a custom wizard page that lets the operator pick
the VS Build Tools install folder (the ~8 GB block; the ~2 GB Windows
SDK + reference assemblies always go to fixed `C:\` paths).

## What works (verified on the test PC)

- **TortoiseSVN auto-install** via winget with `--custom 'ADDLOCAL=ALL'`
  + `--force`. The `ADDLOCAL=ALL` is non-negotiable: the MSI's command-
  line client tools (`svn.exe`) feature is **off by default**, and a
  default install gives you the GUI without the CLI we depend on.
  `--force` lets the install proceed even when winget thinks the package
  is already installed but in a no-CLI state.
- **Multi-instance prevention** via `Get-VsBuildToolsPaths` (uses
  `vswhere -products Microsoft.VisualStudio.Product.BuildTools`). When
  any Build Tools instance exists anywhere, the script switches the verb
  from `install` to `modify` and retargets `--installPath` to the
  existing instance. Stops the script from creating a second instance
  if the operator runs it with the default path while a previous run
  put the install on a different drive.
- **ASCII-only enforcement.** PS 5.1 reads `.ps1` files as ANSI/Windows-
  1252 unless they carry a BOM. The original script had `→` and em-dash
  characters in comments and here-strings; PS 5.1 misread the multi-byte
  UTF-8 sequences and the parser failed before any code ran. The script
  now uses pure ASCII; `python -c '...'` checks confirm this on every
  rebuild.
- **Native command argument quoting** via `Format-NativeArg` +
  `System.Diagnostics.ProcessStartInfo`. PS 5.1's `Start-Process
  -ArgumentList` does not auto-quote single elements that contain
  spaces. The script now builds the full Arguments string itself with
  CRT-correct quoting and hands it to `ProcessStartInfo.Arguments`.
  Verified working: paths like `D:\Program Files (x86)\Microsoft Visual
  Studio\2022\BuildTools` are passed through correctly.
- **`--passive` instead of `--quiet`** for VS Build Tools so the
  operator can actually see what the installer is doing.
- **Failure messaging** — when vswhere doesn't find the workload after
  the install, the script logs the recovery options and points at the
  diagnostic log paths.

## What does NOT work

On the test PC (Windows 11 24H2, OS build 26200), `vs_BuildTools.exe
install --passive --wait --norestart --installPath "..." --add
Microsoft.VisualStudio.Workload.VCTools --add
Microsoft.VisualStudio.Component.Windows11SDK.22621` reliably exits
with **code 0 in ~2 minutes** *without ever producing the C++ workload*.
Multiple attempts on both fresh and post-cleanup states reproduce this
exactly.

`vswhere -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64`
returns nothing after the bootstrapper exits "successfully". The
operator-facing wizard registers the worker fine; the very first build
attempt fails because there's no MSVC.

## Diagnostic data (all on the test PC)

The bootstrapper writes several logs into `%TEMP%`. From the latest
failed run:

```
dd_setup_20260510021015.log              7,846  bytes  — package detection only
dd_setup_20260510021015_errors.log           0  bytes  — empty (setup didn't think anything went wrong)
dd_installer_20260510021008.log         19,130  bytes  — actual install activity (THIS IS THE INTERESTING ONE)
```

From an earlier failed run that did more work:

```
dd_installer_elevated_20260510020313.log  ~5 MB  — heaviest log we've seen, but still didn't deliver the workload
```

> **Pull these off the test PC tomorrow** before doing anything else
> with that machine. They get rotated by Windows, and rebooting +
> reinstalling can clobber them. Drop them into the panel-side
> dev box (or anywhere durable) and reference them when working
> on the script.

The `dd_setup_*.log` we *did* see ends mid-package-detection at
`02:10:16`. Setup engine v4.5.35 on Windows NT 10.0.26200.0. It logs
"Loaded existing instance for product
'Microsoft.VisualStudio.Product.BuildTools, version=17.14.37216.2'" —
which is suspicious *after* a nuclear cleanup (uninstall both, delete
`%ProgramData%\Microsoft\VisualStudio\Packages\_Instances\*`, reboot).
Either the cleanup wasn't actually clean, or setup.exe re-registers an
instance from the bootstrap-channel JSON before doing anything.

The setup.exe command line that got logged is also informative:

```
"C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"
  /finalizeInstall install --in "...vs_setup_bootstrapper_*.json"
  install --passive --norestart --installPath "D:\..."
  --add Microsoft.VisualStudio.Workload.VCTools
  --add Microsoft.VisualStudio.Component.Windows11SDK.22621
  --locale en-US --activityId "..." --pipe "..."
```

Notes:
- **Two `install` verbs** (one as the `/finalizeInstall` argument, one
  passed through). Probably normal — `/finalizeInstall` is internal —
  but worth verifying.
- **`--wait` is missing** from the setup.exe invocation. Our script
  passes `--wait` to `vs_BuildTools.exe`, and that's documented to make
  the *bootstrapper* (not setup.exe) wait. Worth checking whether the
  bootstrapper actually does wait on a real install vs. exits when
  setup.exe exits, even if setup.exe spawned/queued an installer that's
  still working.

## Hypotheses ruled out

1. ~~**Encoding**~~ — fixed. Script is pure ASCII.
2. ~~**Native command quoting**~~ — fixed. `ProcessStartInfo.Arguments`
   path with manual quoting works.
3. ~~**Already-installed-elsewhere bypass**~~ — fixed. `Get-VsBuildToolsPaths`
   detects any Build Tools instance and switches verb to `modify`.
4. ~~**Cached / contaminated state**~~ — same failure pattern after
   nuclear cleanup (uninstall both instances + reboot + delete
   `_Instances\*`).
5. ~~**winget-side issue**~~ — the script no longer uses winget for VS;
   it downloads `vs_BuildTools.exe` directly from
   `https://aka.ms/vs/17/release/vs_BuildTools.exe`.
6. ~~**Workload ID typo**~~ — `Microsoft.VisualStudio.Workload.VCTools`
   is the documented Build Tools workload ID per Microsoft (different
   from the IDE's `NativeDesktop`). It's not the wrong name.

## Hypotheses NOT yet ruled out

1. **`--passive` + `--wait` interaction in the new VS Installer (v4.5.35).**
   Bootstrapper might be exiting after delegating to setup.exe, even
   though setup.exe is running async. Possibly fixable by:
   - Switching to `--quiet` (no UI but fully synchronous in some
     readings of the docs)
   - Polling `vswhere` after the bootstrapper exits, with a 10–15 min
     timeout, before declaring failure
   - Watching for the elevated installer process and waiting on it
2. **Stale bootstrapper version cached.** `aka.ms/vs/17/release/vs_BuildTools.exe`
   redirects to a CDN. Maybe the user is getting an old shim. Could
   force a fresh download by appending a cache-bust query param or
   downloading `vs_buildtools.exe` from a versioned URL.
3. **`--installPath` with parens (`(x86)`) in the path being mishandled
   internally** — even though our outer-shell quoting is correct, the
   bootstrapper might re-parse the path and trip on the parens. Could
   test by installing to a parens-free path (`D:\BuildTools\VS2022`).
4. **Win11 24H2 / OS build 26200 specific quirk.** Several "Package
   ... not applicable" lines in the dd_setup log. None of them
   *should* be load-bearing for `VCTools`, but one of them might be
   for an undocumented dependency that causes silent abort.
5. **Pre-existing VS Installer service in a broken state** — the box
   had an older VS install (`17.0.157.0` references in the log) before
   we touched it. Maybe the service registry is stale. Could try
   `"%ProgramData%\Microsoft\VisualStudio\Installer\resources\app\layout\InstallCleanup.exe" -full`
   followed by a fresh start.

## Reproducible manual workaround

This works reliably end-to-end and is what an operator should fall back
to today:

```powershell
$tmp = Join-Path $env:TEMP 'vs_BuildTools_manual.exe'
Invoke-WebRequest -Uri 'https://aka.ms/vs/17/release/vs_BuildTools.exe' `
                  -OutFile $tmp -UseBasicParsing
& $tmp install --installPath 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' `
              --add Microsoft.VisualStudio.Workload.VCTools `
              --add Microsoft.VisualStudio.Component.Windows11SDK.22621
```

(elevated, no `--passive` / `--wait` / `--norestart`). Full GUI opens —
operator clicks Install — real progress bar — workload installed in
~5–15 min. After that, `bootstrap-prereqs.ps1` correctly detects the
workload via vswhere and exits 0 with "VS with C++ workload already
present at … -- skipping."

## Suggested next steps (tomorrow)

In rough order of likelihood-to-fix:

1. **Pull `dd_installer_20260510021008.log`** off the test PC and
   actually read it. That's the file that should tell us what the
   inner install process did/decided. Without it we're guessing.
2. **Reproduce on the dev box** (this F:\ machine). It already has VS
   2022 + workloads installed, so testing fresh-install isn't
   directly reproducible — but we could test `modify` against the
   existing install with the same args and see if it behaves
   differently than the test PC. If the dev box modify works while
   the test PC modify doesn't, the issue is something about the test
   PC's environment.
3. **Try `--quiet` instead of `--passive`** in the script, and a
   post-bootstrapper poll loop watching `vswhere` until either the
   workload appears or a 15-min timeout elapses. If `vs_BuildTools.exe`
   is exiting too early but the install actually does run async, this
   would catch it.
4. **Test with a parens-free install path** (e.g. `D:\BuildTools\VS2022`).
   If that works, the issue is the parens in the default
   `Program Files (x86)` path.
5. **Try `--installWhileDownloading`** (a documented VS bootstrapper
   flag) which forces synchronous install rather than queued
   acquisition.
6. **As a final fallback**, change the script's default for VS Build
   Tools to **detect-only** (verify presence + clear instructions
   pointing the operator at the manual install) rather than
   auto-install. Less ambitious, more reliable.

## Where this lives in the codebase

- `worker/installer/bootstrap-prereqs.ps1` — the script (current state
  on `main` is post-multi-instance-prevention patch).
- `worker/installer/RpgBuildWorker.iss` — the Inno installer with the
  custom wizard page that picks the VS install folder + invokes the
  bootstrap script.
- `docs/BOOTSTRAP_PREREQS_DEBUG.md` — this file.
- `docs/TODO.md` — has an action-item entry pointing here.

## TL;DR

TortoiseSVN auto-install: works.<br>
Multi-instance prevention: works.<br>
**VS Build Tools silent install: does not produce the workload on
Win11 24H2 build 26200**, regardless of fresh or post-cleanup state,
despite the bootstrapper exiting code 0. Diagnostic logs needed to
proceed. Manual GUI install is the documented fallback today.
