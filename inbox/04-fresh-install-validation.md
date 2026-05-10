# 04 - fresh install validation

Ran `_helpers\fresh-install-validation.ps1` from elevated PS 5.1.
**Verdict: PASS.** The patched bootstrap script produces a complete VS Build
Tools install (with C++ compiler) on a real first-time-`install` code path,
not just the `modify`-on-already-extracted-payload path that round 02 covered.

## Verdict line

- vswhere `-products * -requires VC.Tools.x86.x64`: returns the install path. Pass.
- `cl.exe` v19.44.35226.0: present in all four host/target permutations under
  `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Host{x64,x86}\{x86,x64}\cl.exe`. Pass.
- Bootstrap script's own log says `Bootstrap finished successfully.` Pass.
- Exit code 0 from both vs_installer.exe uninstall and the bootstrap. Pass.
- Fresh `_Instances\bebbd951` registered cleanly, no leftover ghosts. Pass.

## Two-attempt history

This took two attempts because of mistakes on my (test-PC Claude) side.

### Attempt 1 (FAIL: re-tested the original bug)

The user's local clone was at `f2fa0e2` and **had not pulled `a3e64ab`**
(the round-03 patch) before the validation script ran. So
`context\bootstrap-prereqs.ps1` on disk was byte-identical to the original
`373cc27` version (modulo CRLF endings) - i.e. the unpatched script.

The wrapper script's step-0 grep for `VC.Tools.x86.x64` found only 3 hits
(comment in `Test-MsvcPresent`, the `-requires` probe, the failure-path
message) instead of the 7 hits the patched version has. I missed that
discrepancy and let the run proceed.

Compounding: my first wrapper had two bugs of its own.

- **`vs_installer.exe --wait` is not a real flag.** The `--wait` flag exists
  on `vs_BuildTools.exe` (the bootstrapper) but not on `vs_installer.exe`
  (the GUI shell). vs_installer.exe rejected the command with exit code 87
  and never started the uninstall. The wrapper then fell into its scrub
  step and `Remove-Item -Recurse -Force`'d the install folder + the ghost
  `_Instances\0240ddbe` directly.
- **Hardcoded `_Instances\0240ddbe`** in the scrub. After my force-scrub
  the failed bootstrap run created a new ghost `_Instances\af62be59`,
  which the wrapper would not have picked up on a re-run.

What happened on this attempt: vs_installer.exe rejected the args, my
force-scrub cleaned the surface state, the unpatched bootstrap ran a real
`install` (verb='install', existing instances=0), and reproduced the
original bug exactly. Bootstrap log shows the install command without
`--add VC.Tools.x86.x64`, exit 0 in 42 s, vswhere empty, no `cl.exe`,
new ghost `_Instances\af62be59` left behind, install folder grown to
1.29 GB / 10,436 entries (same shape as yesterday's failures).

This was effectively **a clean reproduction of the original bug from a
forced-scrubbed state** - useful negative control, but not the validation
we set out to do.

### Attempt 2 (PASS)

After confirming the SHA mismatch and identifying both wrapper bugs, I:

1. **Removed `--wait`** from the vs_installer.exe call and added a poll
   loop (up to 20 min) that watches for the install folder to disappear,
   so we don't fall through into the scrub while the GUI uninstall is
   still working.
2. **Generalized the scrub** to remove every directory under
   `%ProgramData%\Microsoft\VisualStudio\Packages\_Instances\`, not just
   the hardcoded `0240ddbe`.

User then ran `git pull --rebase` (which fast-forwarded the local clone to
`a5fde1b` - bringing in the round-03 patched script and the round-04
directive), confirmed the patched script with a `Select-String` showing
**7 hits** for `VC.Tools.x86.x64`, and re-ran the wrapper.

This time the validation completed cleanly. Detail below.

## Step 0 - patched bootstrap script verification

```text
===== Patched bootstrap script presence + VC.Tools.x86.x64 grep =====
PATH:   D:\Projects\Bugtesting\Bug testing\bugtesting\context\bootstrap-prereqs.ps1
SIZE:   18509 bytes
SHA256: E6A6B475704F75C324526C67FBA9133F7565815B0125B6B98AB032FF7E3A08AE

--- lines containing 'VC.Tools.x86.x64' (expect at least one in --add args) ---
  L 235: # -requires VC.Tools.x86.x64 ensures the C++ workload is actually present
  L 238: -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  L 326: # IMPORTANT -- the explicit '--add VC.Tools.x86.x64' is load-bearing.
  L 339: '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  L 354: exited $code but vswhere can't find Microsoft.VisualStudio.Component.VC.Tools.x86.x64
  L 363: '--add VC.Tools.x86.x64' arg, please capture
  L 378: --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 ``

```

The new lines added by the round-03 patch are visible at L326 (load-bearing
comment) and L339 (the actual `--add` arg), plus L363 / L378 (additions in
the failure-path message and recovery option B).

## Step 1 - pre-tear-down state

```text
===== Pre-tear-down: vswhere -all -prerelease -products * =====
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

===== Pre-tear-down: install folder + _Instances state =====
install folder: EXISTS (D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools, entries=12385)
_Instances entries: e191933d

```

Pre-state: install from attempt 1 was still on disk. `_Instances\e191933d`
ghost present (different from the `af62be59` left by attempt 1, which means
some background reconciliation had already replaced it - VS Installer can
re-mint instance IDs when it sees an inconsistent state). vswhere with
`-products *` finds the install. So we had a legitimate non-empty starting
state to test the uninstall path against.

## Step 2 - vs_installer.exe uninstall

```text
===== vs_installer.exe uninstall result =====
Command line: C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe uninstall --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --passive --norestart
Started:  2026-05-10T12:46:05.7226742+02:00
Ended:    2026-05-10T12:47:39.4002618+02:00
Duration: 1.56 min
Exit code: 0
Polled for install folder removal: 0 s (cap 1200 s)
Install folder still present after wait: False

--- vs_installer stdout/stderr (combined) ---

--- end output ---

```

Uninstall succeeded - exit 0, 1.56 min. The wrapper's poll loop reported
`0 s` because by the time we re-checked Test-Path, the install folder was
already gone - `vs_installer.exe --passive` apparently does block its
caller until UI completion (at least when run with `--norestart` and no
external tasks pending), so the wait-loop wasn't even needed. Worth keeping
the wait-loop as a safety net for cases where it might fork.

`vs_installer.exe` happily accepts `--passive --norestart` together; only
`--wait` was the unrecognized option. If we ever need an "and definitely
block" command line, we'd run `vs_installer.exe` with `--quiet` instead of
`--passive` (silent, no UI) and rely on the same blocking behavior.

## Step 3 - post-uninstall verify + scrub

```text
===== Post-uninstall verify + scrub =====
vswhere after uninstall: empty (good)
scrub _Instances\*: nothing to remove (uninstall handled it)
scrub install folder: not present (uninstall handled it)
clean state: vswhere empty (good)
clean state: _Instances empty (good)
clean state: install folder exists = False

```

Clean state confirmed - vswhere empty, `_Instances\` empty, install folder
gone. The uninstall handled all three; our generalized scrub had nothing to
do, but it would have caught any leftover ghost.

## Step 4 - patched bootstrap-prereqs.ps1 run (the load-bearing test)

```text
===== Patched bootstrap-prereqs.ps1 run =====
Command line: powershell.exe -NoProfile -ExecutionPolicy Bypass -File D:\Projects\Bugtesting\Bug testing\bugtesting\context\bootstrap-prereqs.ps1 -VsInstallPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
Started:  2026-05-10T12:47:39.5304772+02:00
Ended:    2026-05-10T12:49:55.9283197+02:00
Duration: 2.27 min
Exit code: 0

--- bootstrap stdout/stderr (combined) ---
2026-05-10T12:47:39.7371088+02:00 [INFO] winget found at C:\Users\Werguru\AppData\Local\Microsoft\WindowsApps\winget.exe
2026-05-10T12:47:39.7531151+02:00 [INFO] TortoiseSVN already present at C:\Program Files\TortoiseSVN\bin\svn.exe -- skipping.
2026-05-10T12:47:39.8081946+02:00 [INFO] VS install verb: 'install' at 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' (existing instances found: 0)
2026-05-10T12:47:39.8091878+02:00 [INFO] Installing VS Build Tools 2022 (~10 GB) into D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools ...
2026-05-10T12:47:39.8101877+02:00 [INFO] This will take several minutes; the VS Installer UI shows progress.
2026-05-10T12:47:39.8111880+02:00 [INFO] Downloading VS Build Tools bootstrapper: https://aka.ms/vs/17/release/vs_BuildTools.exe
2026-05-10T12:47:42.7214367+02:00 [INFO] vs_BuildTools invoking: C:\Users\Werguru\AppData\Local\Temp\vs_BuildTools_31484.exe install --passive --wait --norestart --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621
2026-05-10T12:49:55.8767660+02:00 [INFO] vs_BuildTools exit code: 0
2026-05-10T12:49:55.8807714+02:00 [INFO] vs_BuildTools final exit code: 0
2026-05-10T12:49:55.9113007+02:00 [INFO] VS Build Tools installed; installation root at D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T12:49:55.9122990+02:00 [INFO] ------ Bootstrap summary ------
2026-05-10T12:49:55.9142966+02:00 [INFO]   svn.exe      : C:\Program Files\TortoiseSVN\bin\svn.exe
2026-05-10T12:49:55.9142966+02:00 [INFO]   VS C++ root  : D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T12:49:55.9152947+02:00 [INFO] Bootstrap finished successfully.
--- end output ---

```

The critical line is the `vs_BuildTools invoking:` invocation at 12:47:42.
**It now contains `--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64`**
in the install plan (round-01's failed runs and round-04 attempt 1 both
lacked this). The rest is housekeeping:

- Verb is `install` (not `modify`), existing instances = 0 - so this is the
  first-time-install code path dev-box wanted validated.
- `vs_BuildTools exit code: 0`.
- Bootstrap's own `Test-MsvcPresent` probe immediately afterwards finds the
  install (no `[ERROR]` block this time, just `Bootstrap finished successfully.`).
- Total bootstrap duration: 2.27 min. Fast because the package cache at
  `%ProgramData%\Microsoft\VisualStudio\Packages\*` already had yesterday's
  payloads (we deliberately did NOT scrub that path, per dev-box's instructions).
  A genuinely-cold-cache install will be 10-20 min instead.

## Step 5 - install verification

### vswhere with the bootstrap script's own probe

```text
===== vswhere -all -prerelease -products * -requires VC.Tools.x86.x64 =====
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

===== vswhere -all -prerelease -products * (no requires filter) =====
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

```

Both probes return the install path. The `-requires VC.Tools.x86.x64`
filter is the load-bearing test - this is what `Test-MsvcPresent` calls
internally, and what would have failed yesterday and on attempt 1.

### cl.exe presence on disk

```text
===== cl.exe search under installPath =====
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe  (FileVersion=19.44.35226.0, Length=677968)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x86\cl.exe  (FileVersion=19.44.35226.0, Length=678000)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx86\x64\cl.exe  (FileVersion=19.44.35226.0, Length=599624)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx86\x86\cl.exe  (FileVersion=19.44.35226.0, Length=598608)

```

MSVC v14.44.35207 (compiler version 19.44.35226.0). Same version round 02's
modify test landed.

### Install folder + _Instances state

```text
===== Install folder summary =====
EXISTS: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
Recursive entries: 12385
Total size: 2.83 GB

===== _Instances state (post-install) =====

Name     LastWriteTime      
----     -------------      
bebbd951 10.05.2026 12:49:52

```

- 12,385 entries / 2.83 GB. (Round 02's modify result was 12,385 entries
  too - same delta because the same plan was applied. Size differs because
  attempt 1 left ~1.29 GB on disk that the modify run extended, vs.
  attempt 2 starting from scratch at 0 bytes.)
- Single fresh `_Instances\bebbd951` entry, mtime 12:49:52, no ghosts.
- System Drive Delta: +3.97 GB; Target Drive Delta: +3.05 GB (both visible
  in the dd_installer_elevated tail).

## Bootstrap-prereqs.log (round-04 attempt 2, full content)

```text
OK   Copied C:\ProgramData\RPGBuildServer\logs\bootstrap-prereqs.log -> D:\Projects\Bugtesting\Bug testing\bugtesting\inbox\logs\bootstrap-prereqs-fresh-install.log (1982 bytes)

--- last 80 lines ---
2026-05-10T12:47:39.7221072+02:00 bootstrap-prereqs starting (PID=31484, PSVersion=5.1.26100.8115)
2026-05-10T12:47:39.7371088+02:00 [INFO] winget found at C:\Users\Werguru\AppData\Local\Microsoft\WindowsApps\winget.exe
2026-05-10T12:47:39.7531151+02:00 [INFO] TortoiseSVN already present at C:\Program Files\TortoiseSVN\bin\svn.exe -- skipping.
2026-05-10T12:47:39.8081946+02:00 [INFO] VS install verb: 'install' at 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' (existing instances found: 0)
2026-05-10T12:47:39.8091878+02:00 [INFO] Installing VS Build Tools 2022 (~10 GB) into D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools ...
2026-05-10T12:47:39.8101877+02:00 [INFO] This will take several minutes; the VS Installer UI shows progress.
2026-05-10T12:47:39.8111880+02:00 [INFO] Downloading VS Build Tools bootstrapper: https://aka.ms/vs/17/release/vs_BuildTools.exe
2026-05-10T12:47:42.7214367+02:00 [INFO] vs_BuildTools invoking: C:\Users\Werguru\AppData\Local\Temp\vs_BuildTools_31484.exe install --passive --wait --norestart --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621
2026-05-10T12:49:55.8767660+02:00 [INFO] vs_BuildTools exit code: 0
2026-05-10T12:49:55.8807714+02:00 [INFO] vs_BuildTools final exit code: 0
2026-05-10T12:49:55.9113007+02:00 [INFO] VS Build Tools installed; installation root at D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T12:49:55.9122990+02:00 [INFO] ------ Bootstrap summary ------
2026-05-10T12:49:55.9142966+02:00 [INFO]   svn.exe      : C:\Program Files\TortoiseSVN\bin\svn.exe
2026-05-10T12:49:55.9142966+02:00 [INFO]   VS C++ root  : D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T12:49:55.9152947+02:00 [INFO] Bootstrap finished successfully.

```

No `[ERROR]` block. The bootstrap summary at the end was new in round 03
(it didn't exist in `373cc27`).

Copied to `inbox/logs/bootstrap-prereqs-fresh-install.log` (the failed
attempt-1 version was overwritten on disk by attempt 2; we have the
attempt-1 evidence in the dd_installer_elevated_20260510122946.log instead).

## What's in inbox/logs/ for this round

Both attempts' logs are present (top-level dd_*.log only - no per-package
_NNN_ files):

**Attempt 1 (failed re-run of original bug, 12:29):**
- dd_bootstrapper_20260510122941.log
- dd_installer_20260510122943.log
- dd_installer_elevated_20260510122946.log (3.6 MB - the install-without-fix)
- dd_setup_20260510122944.log + _errors.log
- dd_setup_20260510122947.log (3.6 MB) + _errors.log
- dd_setup_20260510123015.log + _errors.log

**Attempt 2 - vs_installer uninstall (12:46):**
- dd_installer_20260510124605.log
- dd_installer_elevated_20260510124607.log (3.4 MB - the uninstall log)
- dd_setup_20260510124607.log + _errors.log
- dd_setup_20260510124610.log (3.4 MB) + _errors.log

**Attempt 2 - bootstrap install (12:47-12:49):**
- dd_bootstrapper_20260510124744.log
- dd_installer_20260510124746.log
- dd_installer_elevated_20260510124750.log (5.6 MB - the successful install log)
- dd_setup_20260510124748.log + _errors.log
- dd_setup_20260510124750.log (4.9 MB) + _errors.log
- dd_setup_20260510124952.log + _errors.log
- bootstrap-prereqs-fresh-install.log (the bootstrap script's own log, attempt 2)

Total ~25 MB across both attempts. Direct push, no zip.

## Tail of newest dd_installer_elevated_*.log (attempt 2 install, last ~30 lines)

```text
[2e10:0015][2026-05-10T12:49:52] Removed telemetry property VS.SetupEngine.SharedWillowInstallSessionId
[2e10:0015][2026-05-10T12:49:52] Telemetry property MachineId : 5af82217-2f88-4bc5-9127-97d7c7b7c423
[2e10:0015][2026-05-10T12:49:52] Telemetry property SessionId : 273e38ce-719c-4fa1-beb5-dc2b90a578e5
[2e10:0015][2026-05-10T12:49:52] Removed telemetry property VS.SetupEngine.UserRequestedOperation
[2e10:0015][2026-05-10T12:49:52] Synchronizing read only channels after operation completion.
[2e10:0015][2026-05-10T12:49:52] Warning: Setup expects one or more channel manifest in the repository.
[2e10:0015][2026-05-10T12:49:52] Warning: Setup expects one or more channel manifest in the repository.
[2e10:0015][2026-05-10T12:49:52] Synchronizing readonly channel: https://aka.ms/vs/17/release/channel
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:006e][2026-05-10T12:49:54] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[2e10:0001][2026-05-10T12:49:54] ManifestVerifier Result: Success
[2e10:0001][2026-05-10T12:49:54] Closing the installer with exit code 0
[2e10:0001][2026-05-10T12:49:54] Exit Code: 0
[2e10:0001][2026-05-10T12:49:54] ManifestVerifier Result: Success
[2e10:0001][2026-05-10T12:49:54] ManifestVerifier Result: Success
[2e10:0001][2026-05-10T12:49:54] Releasing singleton lock.
[2e10:0001][2026-05-10T12:49:54] Singleton lock does not exist. Releasing singleton lock skipped.

```

"Completed install", "ManifestVerifier Result: Success", exit code 0,
+3.97 GB system drive delta, +3.05 GB target drive delta. Same shape as
round 02 modify, but the larger delta makes sense because this was a
from-scratch install rather than a modify on an already-half-extracted
folder.

## Differences from round 02 modify test

| Aspect                | Round 02 (modify) | Round 04 attempt 2 (install) |
|-----------------------|------------------:|------------------------------:|
| Verb                  | modify            | install                        |
| Existing instances    | 1 (0240ddbe)      | 0                              |
| Payload extraction    | Already on disk   | Drawn from package cache       |
| Duration              | 0.71 min          | 2.27 min                       |
| System drive delta    | +0.6 GB           | +4.0 GB                        |
| Target drive delta    | +1.6 GB           | +3.0 GB                        |
| `--add VC.Tools.x86.x64` in plan | Yes (manual)  | Yes (via patched script)      |
| `cl.exe` on disk      | Yes               | Yes                            |
| vswhere finds it      | Yes               | Yes                            |

Both produce a valid install. The fact that both pass means the engine's
required-vs-recommended logic IS verb-agnostic (as dev-box expected),
and the fix lands correctly regardless of code path.

## Verdict

**PASS.** Patched bootstrap script verified end-to-end on the real
first-time-install code path, on a clean force-scrubbed state. Fix is
ready to ship in the wild. No additional rounds needed unless dev-box
wants the failed-attempt-1 evidence preserved as a regression test
artifact.

## Lessons for next time

Two process improvements I'd take into a future similar exercise:

1. **`git pull` before invoking any in-repo helper.** The wrapper script
   should have done `git -C $repoRoot pull --ff-only` (or at least warned
   if `git status` showed `behind origin/main`) before reading `context/`.
   Easy to miss when the user's clone has been working through multiple
   rebase paths.
2. **Verify the file under test is what we think it is.** A simple
   "expect N matches, found N" assertion in step 0 of the wrapper would
   have caught attempt 1 before it ran. Worth adding to future helpers.

## Files in this commit

- `inbox/04-fresh-install-validation.md` (this file)
- `inbox/04-validation-raw.txt` (verbatim PS output, 195 lines)
- `inbox/logs/dd_*.log` from both attempts (~25 MB total, listed above)
- `inbox/logs/bootstrap-prereqs-fresh-install.log` (attempt 2)
- `_helpers/fresh-install-validation.ps1` (with the post-attempt-1 fixes:
  no `--wait`, generalized scrub, poll loop after vs_installer.exe)

## Open questions for dev-box-Claude

None blocking. Optional follow-ups if you want them:

- Capture the post-install `_Instances\bebbd951\state.json` so we have
  a known-good shape to compare against future broken instances.
- Wire the `Select-String` count assertion I mentioned in "Lessons" into
  the production worker installer's smoke tests.

Otherwise this debug loop is properly closed. The test PC is now in the
"fully-functional VS Build Tools install" state - same end state as if
someone had just installed our patched RpgBuildWorker installer fresh.

Sources:
- [`inbox/04-validation-raw.txt`](04-validation-raw.txt) - verbatim PS output for every section above.
- [`inbox/logs/bootstrap-prereqs-fresh-install.log`](logs/bootstrap-prereqs-fresh-install.log) - bootstrap script's own log.
- [`inbox/logs/dd_installer_elevated_20260510124750.log`](logs/dd_installer_elevated_20260510124750.log) - attempt 2 install (5.6 MB).
- [`inbox/logs/dd_installer_elevated_20260510122946.log`](logs/dd_installer_elevated_20260510122946.log) - attempt 1 install (the unpatched-script reproduction of original bug).
