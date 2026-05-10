# 06 — Wizard JS escape fix shipped

Diagnosis confirmed, one-line fix landed, installer rebuilt + republished.

## Root cause

`worker/src/Worker.Service/Setup/SetupAssets.cs` embeds the wizard's
HTML/JS in a C# **raw string literal** (`"""..."""`). Raw string
literals do NOT process escape sequences — what you write is what
goes on the wire.

L492 had:

```
title: 'Select the project\\'s .uproject file',
```

Two backslashes were intended as "C# escape produces one backslash, JS
sees `\'` and treats it as escaped apostrophe." But raw strings don't
do that escape pass — the served HTML carried the literal `\\'`,
which JS reads as backslash-character + string-terminator apostrophe.
Result: every line after L492 in the script became syntactically invalid
("Unexpected identifier `s`"). No JS executed → no NONCE extraction →
every `/api/*` returned 403 (which, as you correctly diagnosed, was
the secondary symptom, not a separate bug).

## Fix

One line. Single-backslash escape:

```diff
-          title: 'Select the project\\'s .uproject file',
+          title: 'Select the project\'s .uproject file',
```

Verified that L485's `'\\\\'` (looking for `\\` in Windows paths) is
the only OTHER `\\'` in the file and is intentional — that one's
checking for a literal pair of backslashes in a path string, not
attempting to escape a quote.

## What's shipped

- `bootstrap-prereqs.ps1` — already had the round-03 fix; this round
  also includes the **modify-existing-IDE** behaviour I added between
  rounds. Means a future test PC with VS Community/Pro/Enterprise
  installed but no C++ workload would have the workload added to the
  IDE rather than getting a parallel BuildTools install. New
  `-PreferFreshBuildTools` switch opts out. Code's at lines ~245-360;
  full notes in `context/bootstrap-prereqs.ps1`. Untested in the wild
  (your test PC went the bootstrap route from a clean state, so this
  branch wasn't exercised). I'm logging it as a "validate in a future
  round" item rather than blocking on it.
- C# wizard with the JS fix (this round).
- Steam-upload-as-an-action on the panel (orthogonal change Ivan asked
  for between rounds — adds a `kind` column to build_jobs, a "Re-upload
  to Steam" button on successful build detail pages, and a worker code
  path that skips SVN/UAT and just runs SteamUploader. Doesn't touch
  the wizard or installer flow.).

The installer artifact at
`https://buildserver.rockpocket.games/api/v1/admin/downloads/RpgBuildWorker-latest-setup.exe`
is the rebuilt one (22.8 MB, deployed 2026-05-10 ~12:35 UTC).

## What I want you to do

Re-run round 05 from phase A onward.

You don't need to tear down VS this time — the BuildTools install from
the previous attempt is still good (cl.exe v19.44 verified, vswhere
finds it). The bootstrap-prereqs step in the new installer will detect
"VS with C++ workload already present at D:\..." and skip immediately.
That alone is a useful regression test for the modify-existing-instance
path.

So your sequence:

1. **Uninstall the previous attempt's worker** (the Inno installer ran
   round 05 attempt 1 and left a partial install — service registered
   but never started because the wizard never saved):

   ```powershell
   # If the installer left an entry in Apps & Features, uninstall via that.
   # OR run the unins000.exe directly:
   $unins = "$env:ProgramFiles\RPGBuildServer\unins000.exe"
   if (Test-Path $unins) {
     & $unins /SILENT /NORESTART
     # waits ~10-30 s, no prompts
   }

   # Sanity: service should be gone, install dir empty.
   Get-Service RpgBuildWorker -ErrorAction SilentlyContinue
   Test-Path "$env:ProgramFiles\RPGBuildServer\RpgBuildWorker.exe"
   # Both: gone / False expected
   ```

   `%ProgramData%\RPGBuildServer\` (the worker config + token from any
   prior wizard save) survives uninstall — that's by design. Since the
   previous wizard never reached Save, there should be nothing useful
   in there anyway, but if `worker-config.json` exists from a prior
   attempt, you can leave it; the wizard will reconfigure-mode against
   it OR overwrite on Save. (Your call.)

2. **Re-download the installer** from the same URL as round 05 step 1
   (admin token unchanged):

   ```powershell
   $tok = '<ADMIN_TOKEN>'
   $dest = "$env:USERPROFILE\Downloads\RpgBuildWorker-latest-setup.exe"
   Invoke-WebRequest `
     -Uri "https://buildserver.rockpocket.games/api/v1/admin/downloads/RpgBuildWorker-latest-setup.exe?token=$tok" `
     -OutFile $dest -UseBasicParsing -UserAgent 'Mozilla/5.0'
   (Get-Item $dest).LastWriteTime
   # Expect: today, ~12:30 UTC or later
   ```

3. **Run the installer** (steps 2-3 of `outbox/05-full-installer-test.md`,
   unchanged). On the "Build prerequisites" page, **uncheck** "Install
   build prerequisites" — VS is already installed and we don't need to
   exercise the bootstrap again. This also proves the installer works
   with that checkbox off.

4. **The wizard should now work end-to-end.** Walk through the same
   sections (worker name `Werguru-test-PC`, paste the registration key
   below, add the Outsail project with the stub .uproject from before),
   click Save.

   Fresh registration key (24h TTL, since the previous one is consumed
   or expired):

   ```
   <NEW KEY — Ivan, mint via curl when he's ready, OR I can mint and
   paste here if you confirm you want to start round 06 right now>
   ```

5. **Verify** (step 4 of outbox/05, unchanged): service Running,
   worker heartbeat in log, /admin/agents shows Werguru-test-PC.

6. **Bonus regression check** — the previous bug was specifically the
   .uproject Browse button being unreachable because the JS hadn't
   parsed. Even though our test setup uses a stub .uproject path,
   click the **Browse** button next to it just to prove the native
   file dialog now opens. Cancel out — we don't actually need to pick
   anything since the path is already filled in. If it opens (and the
   dialog title says "Select the project's .uproject file" with a
   correct apostrophe), the fix is empirically validated.

## Report

Same structure as `inbox/05-installer-test.md`. The interesting new
sections are:
- "Browse button regression check" — yes/no and a screenshot if you
  can grab one
- "/api/* paths after the fix" — should be 200, not 403, when the JS
  attaches the nonce. Easy verify: the wizard's "probing local
  installs..." text in section 2 should clear and SVN/SteamCMD paths
  should auto-populate from `Get-Command`.

## Key minting

Either:
- (Faster) Ivan posts a fresh key in this thread / mints via curl and
  edits this file before you start; OR
- (Self-serve) you run the same `curl -X POST` against
  `/api/v1/admin/registration-keys` that the round-05 prep used, with
  the admin token Ivan pasted earlier. The endpoint takes
  `{"displayNameHint":"Werguru-test-PC"}` as the body and returns
  `{"plaintext":"<key>"}`.

## What's NOT in this round

- No clean-from-scratch VS install — already tested in round 04, the
  modify-existing path is what we want to exercise here.
- No steam-upload action testing — that needs an actual successful
  build's artifact on the worker, which we don't have on the test PC.
- No bootstrap-prereqs.ps1 modify-existing-IDE path testing —
  separately TODO'd for a later round on a box with VS Community
  installed.
