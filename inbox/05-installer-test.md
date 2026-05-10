# 05 - installer end-to-end test (FAIL: wizard JS has a syntax error; cannot complete registration)

Ran the production Inno installer end-to-end on the test PC. **Verdict: FAIL.**
The build prerequisites half (Inno -> bundled bootstrap-prereqs.ps1 -> VS Build
Tools 2022) works correctly. The setup wizard at `127.0.0.1:7891` loads its
HTML, but **the wizard's JavaScript fails to parse** with `Uncaught SyntaxError:
Unexpected identifier 's'`. Because the JS never executes, every auto-fill
(computer name, SVN path) is empty and the project dropdown is non-functional.
PS-side probing found that all `/api/*` endpoints also return 403 Forbidden,
which is a secondary issue the JS would have hit eventually anyway, but isn't
what the user sees first.

The user observed the symptoms first: form fields that should be auto-populated
(hostname, SVN executable path) were empty, and the project dropdown was
non-functional. After capturing diagnostic state we opened the browser's
DevTools - the JS parse error is the actual smoking gun.

## Verdict line

- VS Build Tools install via bundled bootstrap-prereqs.ps1: **PASS**
  (vswhere finds the install with `-products * -requires VC.Tools.x86.x64`,
  cl.exe v19.44.35226.0 present, bootstrap log says "Bootstrap finished
  successfully." in 2.3 min)
- Inno installer file copy: **PASS** (Setup Log "Installation process succeeded.")
- TortoiseSVN detection by bootstrap: **PASS** (already on PATH from prior runs)
- RpgBuildWorker service `sc start`: **PASS** (Inno reports exit code 0)
- RpgBuildWorker service running state: **stopped** (likely because no
  worker-config.json yet; expected pre-wizard, but worth flagging)
- Setup wizard HTML at `127.0.0.1:7891`: **PASS** (HTTP 200, 30,429 bytes)
- **Setup wizard JavaScript parse: FAIL** (`Uncaught SyntaxError: Unexpected identifier 's'` - JS never runs)
- Setup wizard `/api/*` endpoints: **FAIL** (every probed path returns 403; secondary)
- Wizard usable to complete worker registration: **NO**

## Root cause

The wizard's JavaScript bundle (inline or external on the 30 KB page) has a
**syntax error** that prevents the entire script from parsing. Browser
console reports:

```
Uncaught SyntaxError: Unexpected identifier 's'
:7891/favicon.ico:1  Failed to load resource: the server responded with a status of 403 (Forbidden)
```

The "Unexpected identifier 's'" shape is almost always **an unescaped
apostrophe inside a single-quoted JS string literal** - the parser closes
the string at the apostrophe, then sees the next letter (`s`) as a bare
identifier and errors. Three plausible sources in the installer's bundled
wizard:

1. A template substitution that injected a value containing `'` into a
   single-quoted JS string literal without escaping (e.g., a default
   display name, a Windows user "Full Name" pulled from the OS, an
   environment variable that contains an apostrophe).
2. A hardcoded English string with a contraction ("won't", "can't",
   "let's") in a single-quoted literal that wasn't backslash-escaped.
3. A JSON-encoded value embedded into JS via the wrong quote style.

Because the JS never runs, the wizard:
- Cannot fetch hostname / SVN path / Unreal installs / project list from
  any API endpoint -> all auto-fills are blank.
- Cannot bind change handlers on dropdowns -> project picker doesn't work.
- Cannot send a Save POST -> the wizard is dead-end.

The DevTools **Network tab confirms this**: the only failed (red) request
visible there is `/favicon.ico` (403). **No `/api/*` requests appear at
all** because the JS that would have made them never executed. The 403s
my PS Phase-C probes hit are real but secondary - they wouldn't be the
user-visible symptom even if the JS were fixed.

### The exact line (found via `node --check` against the dumped wizard HTML)

The full 30,429-byte wizard page was dumped to
[`inbox/logs/wizard-index.html`](logs/wizard-index.html). Running
`node --check` on the inline `<script>` body points to **JS body line 122
(HTML line 483)**:

```js
title: 'Select the project\\'s .uproject file',
```

Surrounding context (HTML lines 480-486):

```js
n: NONCE,
filter: '*.uproject',
label: 'Unreal projects (*.uproject)',
title: 'Select the project\\'s .uproject file',   // <-- broken
});
if (dir) params.set('dir', dir);
const res = await fetch('/api/browse-file?' + params.toString(), { method: 'POST' });
```

The `\\` is a **double-escaped backslash**, which produces a literal `\`
in the string. That literal backslash makes the next character (`'`)
**terminate** the string instead of being treated as the escaped
apostrophe the original author wanted. Parser then hits `s`, errors.

Almost certainly a build-pipeline bug: the wizard HTML/JS is probably
embedded as a resource string in the worker .NET assembly, and an
escape pass somewhere is double-escaping `\`. The original source was
likely `'Select the project\'s .uproject file'` and got mangled to
`'Select the project\\\'s .uproject file'` then collapsed to
`'Select the project\\'s .uproject file'` on the way to the wire.

### Three possible fixes (any one works)

```js
// Fix A: remove the double escape (single-quoted, single backslash before ')
title: 'Select the project\'s .uproject file',

// Fix B: switch to double-quoted (no escape needed)
title: "Select the project's .uproject file",

// Fix C: template literal (no escape needed)
title: `Select the project's .uproject file`,
```

Whichever way the `s build pipeline` likes best. **Fix B** is probably
the cleanest because it matches how the rest of the script's labels
seem to be written (e.g., `label: 'Unreal projects (*.uproject)'` two
lines above, no escaping needed).

### Why I think this is the only such error

`node --check` only reports the first parse error it hits, so there
could be more after this one. But: this string is in a function that
the page calls only when the user clicks the .uproject "browse" button,
not at page-load. If there were *more* parse errors at module-top,
the JS would fail before *this* line. That suggests this is the
single offender. Worth dev-box doing a quick `grep -n "\\\\'"` (or
equivalent) over the whole wizard HTML/JS to be sure no other
double-escape leaked through.

## What this means for shipping

The compiler-fix work shipped in rounds 02-04 is **independent and still good**
- the bootstrap-prereqs.ps1 inside the installer ran correctly here, on a
fully-clean tear-down state, and produced a valid VS install. The blocker is
on the wizard backend, not on anything the bootstrap script touches.

Anyone who downloads the installer from the panel right now will hit this
same wall: VS install succeeds, then they're stuck at a wizard that won't let
them save.

## Step 0 - tear-down (before this round)

User uninstalled the round-04 VS install via `vs_installer.exe uninstall
--passive --norestart`. The uninstall took ~40 min wall clock (longer than
round-04's 1.6 min because round 04 was tearing down a half-broken instance
of ~1.3 GB; this one was a complete ~2.83 GB install). One detail to note:
the uninstaller's PS console hung after vs_installer.exe itself had exited
cleanly - install folder gone, `_Instances\` empty, vswhere empty. We killed
the hung console (no on-disk damage) and continued in a fresh shell. Likely
a stuck child-process handle inside PowerShell; cosmetic.

Final pre-installer state: vswhere empty, no `_Instances\*`, no install
folder. Confirmed in the second PS window before phase A.

## Phase A - installer download

```text
﻿
===== date + host =====
now: 2026-05-10T14:16:51.1645514+02:00
computer: BMM-PC
user: Werguru

===== VS install (vswhere) =====
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools

===== cl.exe =====
D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe  exists=True

```

Download was clean: 22.77 MB, today's mtime, MZ header, 21.5 s wall time.
SHA256 `E2A1994DF2FC959C038C8C7CF442A0CF08EC196CF0172F88CE57DA179259ADA3`.

## Phase B - Inno installer + bundled bootstrap

Ran via `Start-Process ...exe -Verb RunAs`. User clicked through:

1. License - accepted.
2. Install location - left default. Resolved to `D:\Program Files\RPGBuildServer`
   on this machine. (Whether that's the Inno installer's default or because
   the user picked it doesn't change the diagnosis here, but flagging because
   dev-box's brief expected `%ProgramFiles%` to be `C:\Program Files\` -
   either the brief is wrong about the default, or this PC has a non-default
   `%ProgramFiles%` env var.)
3. Build prerequisites page - checkbox CHECKED, VS install path changed to
   `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools` per the brief.
4. Ready -> Install.
5. Bootstrap-prereqs ran in elevated child window (~2 min - package cache hit
   from previous rounds).
6. Final page - "Run setup wizard now" + "Start service" both checked.
7. Finish -> wizard tab opened at `127.0.0.1:7891`.

### Bootstrap-prereqs.log from this run

Full log is at [`inbox/logs/bootstrap-prereqs-installer-run.log`](logs/bootstrap-prereqs-installer-run.log).
Key lines:

```text
2026-05-10T14:05:59.4972648+02:00 bootstrap-prereqs starting (PID=32712, PSVersion=5.1.26100.8115)
2026-05-10T14:05:59.5142812+02:00 [INFO] winget found at C:\Users\Werguru\AppData\Local\Microsoft\WindowsApps\winget.exe
2026-05-10T14:05:59.5289123+02:00 [INFO] TortoiseSVN already present at C:\Program Files\TortoiseSVN\bin\svn.exe -- skipping.
2026-05-10T14:05:59.5846918+02:00 [INFO] VS install verb: 'install' at 'D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools' (existing instances found: 0)
2026-05-10T14:05:59.5866848+02:00 [INFO] Installing VS Build Tools 2022 (~10 GB) into D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools ...
2026-05-10T14:05:59.5896842+02:00 [INFO] This will take several minutes; the VS Installer UI shows progress.
2026-05-10T14:05:59.5907286+02:00 [INFO] Downloading VS Build Tools bootstrapper: https://aka.ms/vs/17/release/vs_BuildTools.exe
2026-05-10T14:06:02.4119383+02:00 [INFO] vs_BuildTools invoking: C:\Users\Werguru\AppData\Local\Temp\vs_BuildTools_32712.exe install --passive --wait --norestart --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.Windows11SDK.22621
2026-05-10T14:08:19.6654610+02:00 [INFO] vs_BuildTools exit code: 0
2026-05-10T14:08:19.6694646+02:00 [INFO] vs_BuildTools final exit code: 0
2026-05-10T14:08:19.7033131+02:00 [INFO] VS Build Tools installed; installation root at D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T14:08:19.7043386+02:00 [INFO] ------ Bootstrap summary ------
2026-05-10T14:08:19.7053471+02:00 [INFO]   svn.exe      : C:\Program Files\TortoiseSVN\bin\svn.exe
2026-05-10T14:08:19.7063428+02:00 [INFO]   VS C++ root  : D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools
2026-05-10T14:08:19.7073420+02:00 [INFO] Bootstrap finished successfully.

```

Same shape as round-04 attempt 2: verb=install, existing instances=0, the
install command line includes `--add Microsoft.VisualStudio.Component.VC.Tools.x86.x64`,
exit 0, "Bootstrap finished successfully." Confirms the patched
bootstrap-prereqs.ps1 is what's bundled into the installer.

### Inno setup log (last ~50 lines)

Full log copied to [`inbox/logs/inno-setup.log`](logs/inno-setup.log).
Pertinent excerpt - the `Run entries` at the bottom show the two
post-install hooks that fired:

```text
2026-05-10 14:05:59.018   Dest filename: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\RPG Build Worker\Worker Service Status.lnk
2026-05-10 14:05:59.019   Creating the icon.
2026-05-10 14:05:59.022   Successfully created the icon.
2026-05-10 14:05:59.025   -- Icon entry --
2026-05-10 14:05:59.025   Dest filename: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\RPG Build Worker\Uninstall RPG Build Worker.lnk
2026-05-10 14:05:59.025   Creating the icon.
2026-05-10 14:05:59.038   Successfully created the icon.
2026-05-10 14:05:59.041   Saving uninstall information.
2026-05-10 14:05:59.041   Creating new uninstall key: HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E504FC05-28BD-43DF-ACC2-0D70AA50202D}_is1
2026-05-10 14:05:59.042   Writing uninstall key values.
2026-05-10 14:05:59.042   Detected previous non administrative install? No
2026-05-10 14:05:59.042   Detected previous administrative 32-bit install? No
2026-05-10 14:05:59.164   Installation process succeeded.
2026-05-10 14:08:19.721   Need to restart Windows? No
2026-05-10 14:08:24.352   -- Run entry --
2026-05-10 14:08:24.352   Run as: Original user
2026-05-10 14:08:24.352   Type: Exec
2026-05-10 14:08:24.352   Filename: D:\Program Files\RPGBuildServer\RpgBuildWorker.exe
2026-05-10 14:08:24.352   Parameters: --setup
2026-05-10 14:08:32.713   -- Run entry --
2026-05-10 14:08:32.713   Run as: Original user
2026-05-10 14:08:32.713   Type: Exec
2026-05-10 14:08:32.713   Filename: C:\Windows\system32\sc.exe
2026-05-10 14:08:32.713   Parameters: start RpgBuildWorker
2026-05-10 14:08:33.305   Process exit code: 0
2026-05-10 14:08:33.308   Deinitializing Setup.
2026-05-10 14:08:33.312   Stopping 64-bit helper process. (PID: 32340)
2026-05-10 14:08:33.314   Helper process exited.
2026-05-10 14:08:33.322   Log closed.

```

Both post-install hooks ran. The setup wizard process was started (PID
captured as 30716 in the diagnostic snapshot below), and `sc start
RpgBuildWorker` returned exit 0. So there's no Inno-side error here -
the failure is purely on the wizard backend's HTTP layer.

## Phase C - state diagnostic (where the failure shows up)

### Build environment - all green

```text
===== svn (Get-Command) =====


Source  : C:\Program Files\TortoiseSVN\bin\svn.exe
Version : 1.14.5.21638

```

Both vswhere probes find the install. cl.exe v19.44 on disk. SVN on PATH.
None of these would be the reason the wizard's auto-fill fails - they're
all the data sources `--setup` would query if it could reach them through
its own HTTP API.

### Service + process state

```text
===== RpgBuildWorker service =====


Name              : RpgBuildWorker
Status            : Stopped
StartType         : Automatic
DisplayName       : RPG Build Worker
DependentServices : {}

===== RpgBuildWorker process(es) =====

   Id ProcessName    StartTime           Path                                              
   -- -----------    ---------           ----                                              
30716 RpgBuildWorker 10.05.2026 14:08:32 D:\Program Files\RPGBuildServer\RpgBuildWorker.exe
```

The **service is Stopped** despite Inno's `sc start RpgBuildWorker` reporting
exit 0. Likely the service started briefly, found no `worker-config.json`
(which the wizard would write), and exited. Worth verifying with the Event
Log on dev-box's side to confirm the exit reason. Whether this is expected
pre-wizard-completion is a separate question; either way it's not what's
breaking the wizard right now.

The **wizard process is alive at PID 30716** (started 14:08:32, the second
the Inno post-install hook fired), running
`D:\Program Files\RPGBuildServer\RpgBuildWorker.exe --setup`. So the wizard
HTTP server IS running.

### ProgramData state

```text
===== ProgramData\RPGBuildServer listing (recursive, depth 2) =====

FullName                                                 Length LastWriteTime      
--------                                                 ------ -------------      
C:\ProgramData\RPGBuildServer\logs                              10.05.2026 14:08:33
C:\ProgramData\RPGBuildServer\state                             10.05.2026 14:05:56
C:\ProgramData\RPGBuildServer\logs\bootstrap-prereqs.log 1982   10.05.2026 14:08:19
C:\ProgramData\RPGBuildServer\logs\worker-20260510.log   23532  10.05.2026 14:16:06

===== worker-config.json (if any) =====
MISSING: C:\ProgramData\RPGBuildServer\worker-config.json

```

Note `worker-config.json` is **MISSING** - the wizard couldn't have written
it because we couldn't complete the form. `state\` exists but is empty.
The bootstrap-prereqs.log copy ended up there; that's normal.

`worker-2026-05-10.log` ALSO MISSING (my capture script grepped for the
wrong filename pattern - the actual file is `worker-20260510.log` per
`Get-ChildItem` output above, no dashes in the date). Filename mismatch
is in my capture script, not the worker - the file IS there, 23,532 bytes.
Worth grabbing and including in `inbox/logs/` in a follow-up.

### Wizard HTTP probes (PS-side, secondary to the JS error)

```text
===== wizard HTTP probe (127.0.0.1:7891) =====
HTTP 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 30429
first 500 chars of body:
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>RPG Build Worker — setup</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root {
    color-scheme: light;
    --bg:#f5f6f7; --card:#fff; --border:#e5e7eb; --border-strong:#d1d5db;
    --fg:#111827; --muted:#6b7280; --muted-2:#9ca3af;
    --accent:#3b5bdb; --accent-bg:#eef2ff;
    --ok:#16a34a; --ok-bg:#dcfce7; --fail:#dc2626; --fail-bg:#fee2e2;
    --shadow:0 1px 2px rgba(0,0,0,.04);
  }

===== wizard API probes (likely autofill endpoints) =====
GET /api/host -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/probe -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/autofill -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/hello -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/projects -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/tools -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/svn -> Den eksterne serveren returnerte feilen (403) Forbudt.
GET /api/state -> Den eksterne serveren returnerte feilen (403) Forbudt.

```

- `GET /` returns **HTTP 200**, content-type `text/html`, 30,429 bytes.
  HTML page loads. So the wizard's static-file path through http.sys works.
- **Every `/api/*` probe returns 403 Forbidden.** All eight endpoints
  (`/api/host`, `/api/probe`, `/api/autofill`, `/api/hello`, `/api/projects`,
  `/api/tools`, `/api/svn`, `/api/state` - some of these are guesses at the
  endpoint names; the wizard's actual JS calls might be slightly different,
  but the pattern is consistent across all).

The 403 messages came back in Norwegian
("Den eksterne serveren returnerte feilen (403) Forbudt") because Invoke-WebRequest
on this `nb-NO` PS host localizes the WebException message. The status code
itself is universal: 403.

### Port 7891 ownership

```text
===== TCP listeners on 7891 =====
127.0.0.1:7891  pid=4 (System)

```

Listener owned by `pid=4 (System)` - that's http.sys (the Windows kernel
HTTP server). RpgBuildWorker.exe is registering URL prefixes via http.sys
rather than binding the socket directly, which is normal for ASP.NET Core /
HttpListener-based apps. Means the **403 could be coming from one of two
places**:

1. **http.sys URL ACL or authentication policy.** If the installer needs to
   run a `netsh http add urlacl url=http://+:7891/ user=<sid>` (or similar)
   for the wizard's URL prefix and that step was missed, http.sys will return
   403 even before the request reaches the .NET app. The fact that `/`
   returns 200 but `/api/*` returns 403 makes this less likely to be a
   pure URL-ACL issue (URL ACLs are usually prefix-wide), but it's still
   worth ruling out.
2. **The .NET-side HTTP pipeline.** More likely: an authorization filter,
   antiforgery middleware, CORS preflight rejection, or path-based
   `[Authorize]` attribute is rejecting unauthenticated requests to
   `/api/*`. That'd explain why `/` (static HTML) is fine but `/api/*` isn't.
   The wizard's JS may be expected to send a setup-session cookie or token
   in a header, and isn't.

A focused dev-box check: open the wizard's .NET source and look at what
sits in front of `/api/*`. If there's an `[Authorize]` attribute or an
auth middleware that requires something the static page doesn't establish,
that's the bug. Alternatively, run the worker setup on dev-box manually,
hit `/api/host` from a `curl --include`, and see what the WWW-Authenticate
or Set-Cookie response headers say (if any).

## Open questions for dev-box-Claude

1. **Find the apostrophe.** Whatever produced "Unexpected identifier 's'"
   is the actual blocker. If you don't see it instantly via View Source,
   ping me and I'll dump the full wizard HTML+JS to `inbox/logs/` in a
   follow-up commit (one-line `Invoke-WebRequest`).
2. **Why are `/api/*` and `/favicon.ico` returning 403 while `/` returns
   200?** Could be authorization middleware, could be that the wizard's
   HTTP server only registers the root path with http.sys and 403s
   anything outside its prefix list. Worth a sanity check once the JS
   is fixed - if /api/* still 403s with a working browser session, that's
   a second bug.
3. **Is the service supposed to be Stopped before wizard completion?** It
   is Stopped right now. Inno started it (exit 0) but it's not running. If
   the service auto-stops when there's no `worker-config.json`, that's by
   design and we just need to confirm. If it's supposed to be Running, that's
   a second bug.
4. **Is `D:\Program Files\RPGBuildServer\` the expected install location?**
   Brief said `%ProgramFiles%\RPGBuildServer`. The user reports they did NOT
   intentionally change the location to D:\, but this PC's `%ProgramFiles%`
   appears to resolve to `D:\Program Files\` (we'd need a `[Environment]::GetFolderPath('ProgramFiles')`
   to confirm). Not a blocker; flagging.

## Repro environment

- Hostname: BMM-PC
- OS: Win11 Home build 26200
- PS: 5.1.26100.8115 elevated
- Locale: nb-NO (explains the Norwegian 403 message text)
- Installer: `RpgBuildWorker-latest-setup.exe` 22.77 MB, SHA256
  `E2A1994DF2FC959C038C8C7CF442A0CF08EC196CF0172F88CE57DA179259ADA3`,
  downloaded from the admin downloads endpoint at 14:04 today.

## Files in this commit

- `inbox/05-installer-test.md` (this file)
- `inbox/05-test-raw.txt` (verbatim PS output, 187 lines)
- `inbox/logs/bootstrap-prereqs-installer-run.log` (the bootstrap script's
  own log from the installer's bundled run)
- `inbox/logs/inno-setup.log` (Inno's setup log, full content)

I did NOT capture the running wizard's worker log
(`worker-20260510.log`, 23,532 bytes) due to a filename-pattern bug in my
capture script. If you want it for the 403 debug, ping me and I'll grab it
in a follow-up commit (it's just one Get-Content + Copy-Item).

I also did NOT capture the wizard's HTML body in full (just the first 500
chars - the rest of the 30,429-byte page is the form markup and inline JS
that the user can browse via View Source in DevTools). If the JS source
matters for diagnosis, ping me and I'll dump it.

Sources:
- [`inbox/05-test-raw.txt`](05-test-raw.txt) - verbatim output of every section above.
- [`inbox/logs/bootstrap-prereqs-installer-run.log`](logs/bootstrap-prereqs-installer-run.log) - bootstrap from the installer.
- [`inbox/logs/inno-setup.log`](logs/inno-setup.log) - Inno installer log.
