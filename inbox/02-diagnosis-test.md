# 02 — diagnosis test

Ran `_helpers\test-fix.ps1` from elevated PS 5.1. The fix in `outbox/02-diagnosis-and-fix-test.md`
**works** for installing the compiler, AND the secondary "vswhere blind to the instance"
mystery is **also solved**: it's an unrelated default-product-filter quirk in vswhere, not a
state.json corruption.

## Verdict

**Outcome 2 (per the brief), but the secondary mystery has a one-line fix.**

`cl.exe` v19.44.35226.0 is on disk under
`D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx{86,64}\x{86,64}\cl.exe`
(four host/target combos). The bootstrap script's existing
`vswhere -all -prerelease -requires VC.Tools.x86.x64` probe
returns empty — but only because **default vswhere doesn't return BuildTools at all**.
With `-products *` added, vswhere finds the install path immediately.

## Recommended bootstrap-script changes (two patches)

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

…plus wherever the script calls `vswhere` to verify the install (the existing `[ERROR] VS Build Tools install did not register the C++ workload...` path):

```diff
- & $vswhere -all -prerelease -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
+ & $vswhere -all -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
```

(`-products *` to include all product instances — Community/Pro/Enterprise are the default,
BuildTools is excluded unless explicitly asked for. `-products Microsoft.VisualStudio.Product.BuildTools`
is more targeted if a wildcard feels too loose.)

With both patches applied, yesterday's failed-install scenario doesn't recur, and the
post-install verification correctly sees the installed instance.

## state.json

```text
===== instance dir listing =====

Name                  Length LastWriteTime      
----                  ------ -------------      
catalog.json        17951979 10.05.2026 02:03:11
components.json      2102474 10.05.2026 02:03:19
plan.xml             1567247 10.05.2026 02:03:19
product.svg             2306 10.05.2026 02:03:19
state.json             12728 10.05.2026 02:05:03
state.packages.json    31930 10.05.2026 02:05:03

===== state.json copy + key fields =====
Copied state.json -> D:\Projects\Bugtesting\Bug testing\bugtesting\inbox\logs\state.json

--- top-level NoteProperty members ---
catalogInfo
channelId
channelResources
channelUri
enginePath
icon
installationName
installationPath
installationVersion
installDate
installedChannelId
installedChannelUri
launchParams
localizedResources
product
properties
releaseNotes
resolvedInstallationPath
seed
selectedPackages
thirdPartyNotices
updateDate

--- selected fields ---
installationVersion = 17.14.37216.2
installationName    = VisualStudio/17.14.31+37216.2.-april.2026-
installationPath    = D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
productId           = 
channelId           = VisualStudio.17.Release
state               = 
selectedPackages count = 13

```

Full file is at [`inbox/logs/state.json`](logs/state.json) (12,728 bytes). The fields
worth flagging:

- **`state` (top-level) is the empty string** in this PRE-modify snapshot. I initially
  thought this was the smoking gun, but the vswhere probe (see below) finds the instance
  fine with `-products *` even though we copied state.json *before* the modify — i.e.
  even with `state=""`, vswhere is happy as long as you ask for the right products.
  Likely vswhere relies on `product.installed=true` (which is set inside the embedded
  `product` object) rather than the top-level `state` field.
- **`productId` is also empty** — same conclusion, doesn't seem to matter for vswhere.
- **`selectedPackages` count is 13** in this pre-modify snapshot, and crucially
  **does not include `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`** — only
  `Microsoft.VisualStudio.Workload.VCTools`, `Component.Windows11SDK.22621`, and 11 implicit
  group-selected dependencies. Confirms dev-box's diagnosis: yesterday's install plan
  literally never had the compiler.
- `properties.includeRecommended = "0"` — confirms `--passive` doesn't flip the
  "include recommended" bit.

Full per-package list from state.json (note: pre-modify, so VC.Tools.x86.x64 not yet here):

```text
Microsoft.VisualStudio.Component.Roslyn.Compiler            (Implicit, GroupSelected)
Microsoft.Component.MSBuild                                 (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.CoreBuildTools             (Implicit, GroupSelected)
Microsoft.VisualStudio.Workload.MSBuildTools                (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.Windows10SDK               (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.VC.CoreBuildTools          (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.VC.Redist.14.Latest        (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.TextTemplating             (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.VC.CoreIde                 (Implicit, GroupSelected)
Microsoft.VisualStudio.ComponentGroup.NativeDesktop.Core    (Implicit, GroupSelected)
Microsoft.VisualStudio.Component.Windows11SDK.22621         (Explicit, IndividuallySelected)
Microsoft.VisualStudio.Workload.VCTools                     (Implicit, GroupSelected)
Microsoft.VisualStudio.Product.BuildTools                   (Explicit, IndividuallySelected)
```

`Microsoft.VisualStudio.Workload.VCTools` is `Implicit` because the bootstrapper's
`--add` made it explicit at the command line, but state.json then resolved its
membership through `Microsoft.VisualStudio.Product.BuildTools` and re-tagged it
as Implicit/GroupSelected. Doesn't change behavior; just useful to know if you grep
state.json later.

We did NOT capture state.json post-modify in this round. If dev-box wants to confirm
the modify-applied plan (i.e. that `Component.VC.Tools.x86.x64` is now in
`selectedPackages` and that `state` got populated), I can add a post-modify dump
in round 03.

## modify run

```text
Command line: C:\Users\Werguru\AppData\Local\Temp\vs_BuildTools_test.exe modify --passive --wait --norestart --installPath D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621
Started:  2026-05-10T12:02:29.7232022+02:00
Ended:    2026-05-10T12:03:12.2033401+02:00
Duration: 0.71 min
Exit code: 0

--- exe stdout/stderr (combined) ---

--- end exe output ---

```

**42 seconds wall time** is much shorter than the 5-15 min I warned the user to expect.
That's because yesterday's eight failed `install` attempts had already extracted the
MSVC payload to disk — modify just had to register it (`--installPath` already populated;
package files already extracted). System Drive Delta = +602 MB (mostly the bootstrapper's
own download cache); Target Drive (D:\) Delta = +1.65 GB (the registered payload).

### Tail of `dd_installer_elevated_20260510120236.log` (last ~30 lines)

```text
[3664:0009][2026-05-10T12:03:10] Policy setting: UpdateConfigurationFile, value: C:\ProgramData\Microsoft\VisualStudio\updates.config
[3664:0009][2026-05-10T12:03:10] Policy setting: UpdateNotificationsOptOut, value: False
[3664:0009][2026-05-10T12:03:10] Policy setting: VSthroughMUUpdatesOptOut, value: False
[3664:0009][2026-05-10T12:03:10] Completed install
[3664:0009][2026-05-10T12:03:10] System Measurement for 'InstallOperation': 'System Drive Delta (Before - After)': 602796032
[3664:0009][2026-05-10T12:03:10] System Measurement for 'InstallOperation': 'System Drive Space (After)': 909161299968
[3664:0009][2026-05-10T12:03:10] System Measurement for 'InstallOperation': 'Target Drive Delta (Before - After)': 1649012736
[3664:0009][2026-05-10T12:03:10] System Measurement for 'InstallOperation': 'Target Drive Space (After)': 1951299649536
[3664:0009][2026-05-10T12:03:10] Compatible ProductCode '{F73D5EBA-D2A0-9F65-ADA6-2CCFDF44EA70}' found for package 'Microsoft.Windows.UniversalCRT.Tools.Msi,version=10.0.26624,chip=x64'
[3664:0009][2026-05-10T12:03:10] Releasing singleton lock.
[3664:0009][2026-05-10T12:03:10] Releasing singleton lock succeed.
[3664:0009][2026-05-10T12:03:10] Removed telemetry property VS.SetupEngine.SharedWillowInstallSessionId
[3664:0009][2026-05-10T12:03:10] Telemetry property MachineId : 5af82217-2f88-4bc5-9127-97d7c7b7c423
[3664:0009][2026-05-10T12:03:10] Telemetry property SessionId : 019bf21f-5661-4fc7-b760-fc1fb7dbea5a
[3664:0009][2026-05-10T12:03:10] Removed telemetry property VS.SetupEngine.UserRequestedOperation
[3664:0009][2026-05-10T12:03:10] Completed product modification [installationPath: "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"]
[3664:0009][2026-05-10T12:03:10] Synchronizing read only channels after operation completion.
[3664:0009][2026-05-10T12:03:10] Synchronizing readonly channel: https://aka.ms/vs/17/release/channel
[3664:0015][2026-05-10T12:03:11] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[3664:0015][2026-05-10T12:03:11] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[3664:0015][2026-05-10T12:03:11] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[3664:0015][2026-05-10T12:03:11] RPC Disconnected: RemotePartyTerminated, Description: Reached end of stream.
[3664:0001][2026-05-10T12:03:11] ManifestVerifier Result: Success
[3664:0001][2026-05-10T12:03:11] Closing the installer with exit code 0
[3664:0001][2026-05-10T12:03:11] Exit Code: 0
[3664:0001][2026-05-10T12:03:11] ManifestVerifier Result: Success
[3664:0001][2026-05-10T12:03:11] ManifestVerifier Result: Success
[3664:0001][2026-05-10T12:03:11] Releasing singleton lock.
[3664:0001][2026-05-10T12:03:11] Singleton lock does not exist. Releasing singleton lock skipped.

```

Key signals:
- `Completed install`
- `Completed product modification [installationPath: "D:\Program Files (x86)\..."]`
- `ManifestVerifier Result: Success`
- `Closing the installer with exit code 0`
- Target drive +1.65 GB

So the modify completed cleanly — same surface "exit 0" as yesterday's install attempts,
but this time the resulting install IS complete (cl.exe present, vswhere -products * sees
it). Yesterday's attempts also "completed" — the difference is that they completed an
install plan that didn't include VC.Tools.x86.x64.

### Tail of `dd_setup_20260510120310.log` (last 60 lines)

Captured but not pasted inline — it's a long list of "Package X is not applicable: The
current OS Version '10.0.26200.0' is not in the supported version range '[Y, Z]'"
messages for old Win7/8/8.1-targeted redistributables, which is harmless and expected
on Win11. See section `Tail of newest top-level dd_setup_*.log (last 60 lines)` in
[`02-test-raw.txt`](02-test-raw.txt).

## vswhere checks

### As the bootstrap script currently calls it (`-all -prerelease -requires ...`)

```text
(empty output - vswhere did not find an instance with VC.Tools.x86.x64)

```

Empty. Same result as yesterday's snapshot. **This is what's been misleading us** —
the bootstrap script's verification is using vswhere with the default product filter,
which excludes BuildTools.

### `vswhere -all -prerelease -format json` (no requires filter)

```text
[]

```

Also empty — same reason.

### With `-products *` added (the fix)

Three follow-up vswhere invocations run live in the user's PS after the script finished:

```text
--- vswhere -all -prerelease -products * -property installationPath ---
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

--- vswhere -all -prerelease -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath ---
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

--- vswhere -all -prerelease -products Microsoft.VisualStudio.Product.BuildTools -property installationPath ---
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
```

All three return the install path. So the modify successfully:

- Registered `Microsoft.VisualStudio.Component.VC.Tools.x86.x64` against the existing instance.
- Wrote a vswhere-readable instance record (despite top-level `state` being empty in the
  pre-modify state.json — either the modify updated state.json, or vswhere doesn't
  consult that field, or both).

## cl.exe presence on disk

```text
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe  (FileVersion=19.44.35226.0, Length=677968)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x86\cl.exe  (FileVersion=19.44.35226.0, Length=678000)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx86\x64\cl.exe  (FileVersion=19.44.35226.0, Length=599624)
FOUND  D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx86\x86\cl.exe  (FileVersion=19.44.35226.0, Length=598608)

```

MSVC v14.44.35207 (compiler version 19.44.35226.0) installed in all four host/target
permutations. Same version that's available through the GUI install of VS 2022 17.14.

## BuildTools install folder summary

```text
EXISTS: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
Recursive entry count: 12385
```

Up from yesterday's **10,436** entries to **12,385** — +1,949 entries, which lines up
with the +1.65 GB target-drive delta the installer reported.

## Verdict

**Outcome 2 from your brief, but with the secondary mystery fully resolved.** The
diagnosis was correct (workload doesn't include the compiler in required components),
the proposed `--add` fix works, and the `vswhere blind` symptom is just
`-products *` missing from the verification call.

Two-line patch to the bootstrap script and we're done:
1. `--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64` to the install args.
2. `-products *` (or explicit `-products Microsoft.VisualStudio.Product.BuildTools`)
   to whatever the script's vswhere verification probe is.

I haven't touched the bootstrap script itself this round (per your "NOT touching the
bootstrap script yet" instruction). Patch on your end and write `outbox/03-*.md` with
deployment instructions when you're ready. If you want one more empirical pass before
shipping (e.g. a clean uninstall + fresh `install --passive` with the patched args, or
a post-modify state.json dump for completeness), I can run that.

## Open observations / nice-to-knows

1. **The `dd_setup_*.log` "not applicable" warnings** are NOT failure signals —
   they're the setup engine correctly skipping packages that don't apply to Win11
   build 26200 (mostly Win7/8/8.1-targeted UCRT MSUs and old .NET full redists).
   Worth knowing in case future debugging makes them look suspicious.
2. **`includeRecommended = "0"`** in state.json `properties` — confirms that `--passive`
   does NOT flip the recommended-components bit. If we ever wanted the GUI behavior
   without enumerating all components manually, we'd pass `--includeRecommended` instead
   of more `--add`s, but the explicit `--add VC.Tools.x86.x64` approach is cleaner
   (avoids ATL/MFC/Spectre libs we don't use).
3. **The 42-second modify run is artifact of yesterday's failures.** A clean install
   from scratch will still take 5-15 min (most of that is download). Worth flagging
   for whoever inherits this so they don't expect 42-sec installs in the wild.
4. **Pre-modify state.json's empty `state`/`productId` fields** are interesting but
   apparently not load-bearing for vswhere. I'd capture a post-modify state.json in
   the next round if you want certainty about whether they ever get populated; not
   required to ship the fix.

## Files in this commit

- `inbox/02-diagnosis-test.md` (this file)
- `inbox/02-test-raw.txt` (verbatim test output, 229 lines)
- `inbox/logs/state.json` (pre-modify, 12,728 bytes)
- `inbox/logs/dd_bootstrapper_20260510120231.log`
- `inbox/logs/dd_installer_20260510120233.log`
- `inbox/logs/dd_installer_elevated_20260510120236.log` (3.4 MB — the modify-run installer log)
- `inbox/logs/dd_setup_20260510120234.log` + `_errors.log`
- `inbox/logs/dd_setup_20260510120237.log` (3.3 MB) + `_errors.log`
- `inbox/logs/dd_setup_20260510120310.log` + `_errors.log`
- `_helpers/test-fix.ps1` (the script that captured all of the above)

Total payload added this round: ~7 MB (raw, not zipped — small enough that zipping
isn't worth it). The big logs are the two per-run dd_installer_elevated and dd_setup
files, which between them have all the per-package install/modify activity. No need
for a `logs.zip` like round 01 — these can go in directly.

Sources:
- [`inbox/02-test-raw.txt`](02-test-raw.txt) — verbatim output of every section.
- [`inbox/logs/state.json`](logs/state.json) — pre-modify state.
- [`inbox/logs/dd_installer_elevated_20260510120236.log`](logs/dd_installer_elevated_20260510120236.log) — modify-run installer log.
