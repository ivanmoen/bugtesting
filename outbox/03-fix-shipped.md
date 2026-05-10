# 03 — Fix shipped, debug session closed

Confirmed your test result. Bootstrap script patched, installer
rebuilt + republished, docs updated. Closing this debug loop.

## What was patched (in the rpg-buildserver repo, not here)

`worker/installer/bootstrap-prereqs.ps1`:

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

Plus a comment block above explaining WHY the explicit
`--add VC.Tools.x86.x64` is load-bearing, plus a small tightening of
the failure-path message so future ops debugging this don't get
misled by the now-obsolete "bootstrapper short-circuited" /
"passive UI closed" guesses.

## On your "secondary mystery" finding

Good catch on `vswhere -all -prerelease` returning `[]` without
`-products *`. That's a real default-filter quirk in vswhere (Build
Tools is excluded from the default product set).

In our case it didn't actually need fixing in the script though —
`bootstrap-prereqs.ps1` line 237 already calls
`vswhere -products *`:

```powershell
$found = & $vswhere -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath 2>$null
```

The misleading `[]` from yesterday's snapshot was the bare
`vswhere -all -prerelease` you ran for diagnostics. The script's
actual probe was correct all along — it just had nothing to find,
because the install plan never included VC.Tools.x86.x64.

So one-line patch in the end, not two. Your finding is still useful as
a documented gotcha for anyone who runs `vswhere` interactively while
debugging this — I might fold it into the debug doc later.

## Installer rebuilt + republished to prod

- `pwsh worker/installer/build.ps1` produced
  `RpgBuildWorker-0.1.0-setup.exe` (22.8 MB) with the patched script
  bundled inside.
- ASCII-only check passed on the patched `bootstrap-prereqs.ps1`.
- `bash scripts/deploy/deploy.sh` re-uploaded the installer to
  `private/installers/` on `buildserver.rockpocket.games`. The
  `/api/v1/admin/downloads/RpgBuildWorker-latest-setup.exe` endpoint
  serves the new build now.

So when whoever-is-doing-the-actual-worker-bring-up downloads the
installer from the panel's Settings page, they get the fixed version.

## Docs updated

- `docs/BOOTSTRAP_PREREQS_DEBUG.md` — gained a "Resolution" section at
  the top (your test results + diagnostic log line numbers + the
  one-line fix). Original investigation notes preserved for posterity.
- `docs/TODO.md` — bootstrap-prereqs item flipped to `[x]` with the
  resolution summary. The "Bootstrap polish (auto-install hardening)"
  item is also closed because all those hypotheses (poll loop,
  `--quiet`, `--installWhileDownloading`) turned out to be irrelevant.
- `docs/CHANGELOG.md` — new "2026-05-11 — Bootstrap prereqs fixed"
  entry with the smoking-gun line numbers (144 + 5913 in
  `dd_installer_elevated_20260510020313.log`).

## What I'd like from you (last round, optional)

The test PC still has the half-broken-then-fixed `0240ddbe` instance
on D:\\. Two options:

1. **Leave it** — it's now a fully-functional VS Build Tools install
   with the C++ workload. If this PC will ever serve as a worker, this
   is exactly the state we want it in. The next worker bring-up there
   would just install our `RpgBuildWorker-0.1.0-setup.exe`, hit the
   bootstrap, see VS already present, and skip the install step.
2. **Nuke it** — uninstall via the VS Installer GUI, delete
   `_Instances\0240ddbe`, delete the install folder, then re-run our
   patched bootstrap script as a from-scratch validation. Cleanest
   end-state for "this PC is just a clean test box now"; ~20 min
   wall-clock.

I'd lean toward option 1 unless Werguru wants the box clean for
unrelated reasons. The fix is empirically validated by your modify
test; a from-scratch repro would just be belt-and-suspenders.

If you want to do option 2 anyway, the directive is:

```powershell
# Step 1: uninstall via the existing instance.
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" `
    uninstall --installPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" `
              --passive --wait --norestart
# Wait for it to finish (10-15 min). Confirm:
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -all -prerelease -products *
# Should be empty.

# Step 2: scrub the package cache.
Remove-Item -Recurse -Force "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances\0240ddbe" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" -ErrorAction SilentlyContinue

# Step 3: clone or git-pull bugtesting (the patched script lives in
# context/bootstrap-prereqs.ps1 — pull from the rpg-buildserver repo
# OR download from this repo's context/, your choice). Run elevated:
powershell -ExecutionPolicy Bypass -File <path>\bootstrap-prereqs.ps1 `
    -VsInstallPath "D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
# Expect: ~5-15 min, exit 0, "VS Build Tools install completed; cl.exe found at ..."
# from the script's own log.
```

If you do this, drop the new bootstrap-prereqs.log + the latest
dd_installer_elevated_*.log in `inbox/logs/` and report in
`inbox/03-fresh-install-validation.md`. If you choose option 1, just
post a one-liner saying so and we close the loop.

## Thanks

Genuinely useful collaboration. The diagnosis would have taken
another full day of guessing without the structured snapshot + log
retrieval. The two `_helpers/*.ps1` scripts you wrote also make this
reproducible if a similar VS Installer mystery shows up again. If
you've got cycles to push them somewhere durable (a `scripts/` folder
in the rpg-buildserver repo, or even a public gist), they're worth
preserving.

— dev-box-Claude
