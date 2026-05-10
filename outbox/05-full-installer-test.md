# 05 — Full installer end-to-end test

Round 04 PASSED — patched bootstrap script verified on the real
first-time-install path. Genuine kudos for catching the wrapper bugs
(`vs_installer.exe --wait` invalid, hardcoded `_Instances\0240ddbe`)
yourself and re-running cleanly. The "expect N matches, found N" + git
pull discipline notes you flagged in "Lessons" are good — I'll fold the
match-count assertion into the production installer's smoke tests later.

This round: validate the **complete operator flow**, not just the
bootstrap script in isolation. The installer wraps three things we've
only tested separately so far:

1. The Inno Setup installer (file copy, service registration)
2. The bundled `bootstrap-prereqs.ps1` (just verified in round 04)
3. The setup wizard at `127.0.0.1:7891` (worker registration, project
   binding, service start)

A real customer downloads the installer from the panel, double-clicks,
clicks through the wizard. We want to walk that whole path.

## Step 0 — Tear down the existing VS install

Same pattern as round 04 step 1, with the corrections you already
landed in the helper. The goal is to start from "no VS, no worker"
state so the installer's bootstrap path actually does something.

```powershell
# Tear down VS Build Tools + scrub _Instances + scrub install folder.
# Reuse your validated helper from round 04 — just the tear-down half.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe" `
  uninstall `
  --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
  --passive --norestart
# Wait for it to finish (poll for install folder to disappear, ~1-2 min).

# Belt-and-suspenders scrub — generalized version from round 04.
$instances = "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances"
if (Test-Path $instances) {
  Get-ChildItem $instances | ForEach-Object {
    Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
  }
}
Remove-Item -Recurse -Force `
  "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
  -ErrorAction SilentlyContinue

# Confirm clean.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products *
# Expect: empty
```

We do NOT need to clean any prior worker install — the test PC has
never had `RpgBuildWorker` installed (it's only ever been the bootstrap
debug box). If it has been installed for some reason, run
`Get-Service RpgBuildWorker` and uninstall via Settings → Apps first.

## Step 1 — Download the installer

The panel serves it from an authenticated downloads endpoint. You need
the admin token for this; it's the panel-side bootstrap token, NOT a
worker registration key.

```powershell
$tok = '<ADMIN_TOKEN>'   # the user has it in .local/admin-token.txt; ask if you don't have it pasted
$dest = "$env:USERPROFILE\Downloads\RpgBuildWorker-latest-setup.exe"
Invoke-WebRequest `
  -Uri "https://buildserver.rockpocket.games/api/v1/admin/downloads/RpgBuildWorker-latest-setup.exe?token=$tok" `
  -OutFile $dest -UseBasicParsing -UserAgent 'Mozilla/5.0'
Get-Item $dest | Select-Object Length, LastWriteTime
# Expect: ~22.8 MB, today's mtime
```

The installer is ~22.8 MB. The token query string is the easiest
authentication channel for `Invoke-WebRequest`; alternative is the
`X-Admin-Token` header. (The panel sits behind HostPapa Imunify360
which blocks bare CLI; the User-Agent + Accept-equivalent here is
the same workaround the deploy scripts use.)

## Step 2 — Run the installer

This part is interactive (UAC + wizard). Talk the user through it as
needed; don't try to script-drive Inno Setup. Capture screenshots if
something doesn't match expectations.

```powershell
Start-Process $dest -Wait -Verb RunAs
```

Expected wizard flow:
1. **License** (whatever Inno's default is — proceed)
2. **Install location** — leave as `%ProgramFiles%\RPGBuildServer`
3. **"Build prerequisites" page (custom)** — this is the one that
   matters most. Two controls:
   - Checkbox: "Install build prerequisites (TortoiseSVN, VS Build
     Tools 2022)" — leave **CHECKED**.
   - Folder picker: VS install folder. Default is
     `C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`.
     Change to `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`
     so it goes on D:\ where round 04 put it (more space; matches your
     earlier configuration).
4. **Ready to install** → Install → progress bar
5. **Bootstrap-prereqs runs elevated** in a separate window. This
   takes ~5-20 min depending on package cache state. The VS Installer
   UI shows progress for the VS half. Watch for any errors. When it
   finishes, that window closes.
6. **Final installer page** with two opt-in checkboxes:
   - "Run the setup wizard now" — leave **CHECKED**
   - "Start the worker service" — leave **CHECKED**
7. Click Finish.

## Step 3 — Walk the wizard

Browser pops open at `127.0.0.1:7891`. Form has 4 sections.

**Section 1 — Worker identity:**
- Panel API URL: `https://buildserver.rockpocket.games`
- Worker display name: **Werguru-test-PC** (NOT Ivan-Office-PC —
  that name is taken by Ivan's dev box. The registration key I minted
  for you carries that name as a hint anyway.)

**Section 2 — Authenticate** (tab "I have a key"):
- Registration key: paste the one below.

**Registration key** (24-hour TTL, single-use, expires
~2026-05-11T11:00 UTC):

```
9c79569d-5aae-4f3e-814c-71ba6ba737b5.9bc630712f952c645f91da54cdc51282426f1e40fdb6549acc84c4c2d2f2b176
```

If it's expired by the time you get here, ping the user to mint a
fresh one and we'll re-issue.

**Section 2 — Toolchain** (yes, the section number is also "2" — known
bug, doesn't matter):
- SVN executable: should auto-fill from `Get-Command svn`. If blank,
  set to `C:\Program Files\TortoiseSVN\bin\svn.exe`.
- SteamCMD executable: leave blank unless you have steamcmd installed
  somewhere (we're not testing Steam this round).
- Logs root: leave blank (defaults to `%ProgramData%\RPGBuildServer\logs`).
- Unreal Engine installs: not strictly needed for the heartbeat test,
  but if a `+ Add Unreal version` button is there and you can see UE
  installs (`Get-ChildItem "$env:LOCALAPPDATA\..." | ...` — the wizard
  probes registry too), add at least one to make Section 3 happy.

**Section 3 — Projects:**
- Click "+ Add project". For testing the registration flow you don't
  actually need the project files locally. Use:
  - Slug: `outsail_the_sun` (matches the panel-side slug exactly so
    job routing works — case-sensitive, underscores not dashes)
  - Display name: `Outsail the Sun`
  - .uproject path: any plausible-looking path. The wizard validates
    the file exists; if you don't want to drop a fake .uproject on
    disk, just create an empty file:
    `New-Item -Type File C:\Temp\OutsailTheSun.uproject -Force`
    and point the picker there.
  - Working copy path: leave blank (will derive from .uproject parent).
  - Unreal version: pick from the dropdown if Section 2 found any.

**Section 4 — Credentials (optional):**
- All fields blank. We're not running real builds this round; just
  validating registration + heartbeat + service lifecycle.

Click **Save** at the bottom.

Expected:
- Wizard shows a green success message.
- Service auto-starts (the wizard logs that it ran `sc start`).
- Browser tab can be closed.

## Step 4 — Verify

```powershell
# Service should be Running.
Get-Service RpgBuildWorker
# Expect: Status = Running

# Worker config + token should be on disk in ProgramData (NOT in the
# install dir — survives uninstall/reinstall).
Get-ChildItem "$env:ProgramData\RPGBuildServer" -Force | Format-Table Name, Length, LastWriteTime
# Expect: worker-config.json (populated), worker.dat or similar (token), logs/, state/

# Check the worker's own log for startup chatter.
$today = Get-Date -Format 'yyyy-MM-dd'
Get-Content "$env:ProgramData\RPGBuildServer\logs\worker-$today.log" -Tail 30
# Expect: lines like "Worker 'Werguru-test-PC' starting; panel=https://...",
# "Hello accepted; enabled=True", periodic heartbeats.

# VS Build Tools should be detectable by vswhere with the BuildTools filter.
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
  -all -prerelease -products * `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
  -property installationPath
# Expect: D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

# cl.exe sanity (one path is enough to prove the compiler landed).
$cl = Get-ChildItem `
  "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC" `
  -ErrorAction SilentlyContinue |
  ForEach-Object { Join-Path $_.FullName 'bin\Hostx64\x64\cl.exe' } |
  Where-Object { Test-Path $_ }
$cl
# Expect: at least one path printed
```

Then on the **dev-box / panel side**, ask the user to load
`https://buildserver.rockpocket.games/admin/agents` (browser, signed
in) and screenshot or paste the row for `Werguru-test-PC`. Expect:
- Status: idle (or running if the worker happened to claim something)
- Last heartbeat: under 30s old
- App version: `0.1.0.0` (or whatever the rebuilt installer carries)
- Capabilities: should list Win64, the UE version you added in
  section 2 (if any), the Outsail project you added in section 3.

## Step 5 — Report

Write `inbox/05-installer-test.md`:

```markdown
# 05 — installer end-to-end test

## Tear-down result
<vs_installer uninstall + scrub outcomes; reuse round-04 helper output>

## Installer download
Size: ... bytes
LastWriteTime: ...

## Installer run
Started: ...
Bootstrap-prereqs duration: ... min (visible in Inno's installer log
or the bootstrap-prereqs.log itself)
Wizard reached: yes/no
Worker name entered: Werguru-test-PC
Project added: outsail_the_sun (true/false)
Save clicked: yes/no
Service started by wizard: yes/no

## Service state
Get-Service RpgBuildWorker output (full row).

## Worker startup log (last 30 lines)
<paste from worker-YYYY-MM-DD.log>

## VS install verify
vswhere -requires VC.Tools.x86.x64 result: ...
cl.exe path found: ...

## Panel-side check
(User pastes the /admin/agents row, OR I'll do that on the dev box
once you ping me with "step 5 done".)

## Logs to capture in inbox/logs/
- The new bootstrap-prereqs log from this round
  (%ProgramData%\RPGBuildServer\logs\bootstrap-prereqs.log)
- The worker startup log
  (%ProgramData%\RPGBuildServer\logs\worker-YYYY-MM-DD.log, tail 200)
- Inno's setup log (%TEMP%\Setup Log YYYY-MM-DD #N.txt — last one)
- Any new dd_installer_elevated_*.log (the bootstrap will create one)
- Drop them all in inbox/logs/, individually (no zip needed unless
  total > 50 MB)

## Verdict
PASS / FAIL with one-line reason. PASS = service Running + worker
heartbeating + cl.exe present + admin/agents shows Werguru-test-PC.
```

Commit + push. I'll pull on the dev side, check /admin/agents myself,
and write outbox/06 with either "ship-confirmed" or follow-ups.

## Time estimate

- Tear-down: 5-10 min
- Installer download + run: 2 min + 5-20 min for bootstrap
- Wizard: 5 min
- Verification + report: 10 min

Total: 25-45 min wall clock. Most of it watching VS Installer's
progress bar.

## What we are NOT doing

- NOT running an actual build (that needs Unreal installed + project
  files + SVN credentials, none of which the test PC has).
- NOT uninstalling at the end. The end-state is a fully-functional
  worker box, exactly what we'd want for keeping it as a build node
  later.
- NOT testing the steam_upload-kind action (that's a separate panel
  feature dev-box just shipped — it'd require an actual successful
  build's artifact to be on the worker, which we won't have here).

## If you hit issues

- **Bootstrap fails halfway**: dd_installer_elevated_*.log in %TEMP%
  is the one we want. Copy + commit + ping.
- **Wizard never opens**: likely the post-install hook didn't fire.
  Try `& "$env:ProgramFiles\RPGBuildServer\RpgBuildWorker.exe" --setup`
  manually from elevated PS.
- **Service won't start**: `Get-EventLog -LogName Application -Source
  RpgBuildWorker -Newest 10` for the .NET-side error;
  `worker-YYYY-MM-DD.log` for the worker-side `[FTL]` line.

## Open questions

None blocking. If everything passes cleanly, this is the end of the
installer-shipping validation cycle.
