# 01 — Initial brief: snapshot + log retrieval

Goal of this round: capture the current state of the test PC and grab
any surviving diagnostic logs from yesterday's failed runs. We're NOT
running an install in this round — just gathering data.

## Step 1 — Environment snapshot

Run each command, capture the output verbatim. Don't summarize, don't
trim — copy the full output into the report. If a command errors,
include the error text.

```powershell
# OS / shell
[System.Environment]::OSVersion.VersionString
$PSVersionTable
Get-ComputerInfo | Select-Object OsName, OsVersion, OsBuildNumber, WindowsProductName, OsArchitecture | Format-List

# Free disk space on each drive
Get-PSDrive -PSProvider FileSystem | Select-Object Name, @{N='FreeGB';E={[math]::Round($_.Free/1GB,1)}}, @{N='UsedGB';E={[math]::Round($_.Used/1GB,1)}} | Format-Table

# Anything VS-related on the box
& "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -all -prerelease -format json 2>&1
# (paste the JSON; if vswhere isn't installed, just say so)

# Existing _Instances entries (the "ghost instance" hypothesis)
Get-ChildItem "$env:ProgramData\Microsoft\VisualStudio\Packages\_Instances" -ErrorAction SilentlyContinue | Format-Table Name, LastWriteTime

# SVN status (sanity — TortoiseSVN should already be installed)
Get-Command svn -ErrorAction SilentlyContinue | Select-Object Source, Version
```

## Step 2 — Pull yesterday's diagnostic logs

These may already be rotated by Windows. Check explicitly and report
what survives. **Do not fabricate.** If a file is missing, say so.

```powershell
# Yesterday's logs (the ones we wanted most)
$wanted = @(
  'dd_installer_20260510021008.log',
  'dd_installer_elevated_20260510020313.log',
  'dd_setup_20260510021015.log',
  'dd_setup_20260510021015_errors.log'
)
foreach ($name in $wanted) {
  $p = Join-Path $env:TEMP $name
  if (Test-Path $p) {
    $size = (Get-Item $p).Length
    Write-Host "FOUND $name ($size bytes)"
  } else {
    Write-Host "MISSING $name"
  }
}

# Also enumerate everything dd_*.log in TEMP, sorted newest-first.
Get-ChildItem $env:TEMP -Filter 'dd_*.log' -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Format-Table Name, LastWriteTime, Length
```

For every dd_*.log file that exists, copy it into this repo:

```powershell
$repoRoot = '<absolute path to your local clone of the bugtesting repo>'
$logsDir  = Join-Path $repoRoot 'inbox\logs'
Get-ChildItem $env:TEMP -Filter 'dd_*.log' | ForEach-Object {
  Copy-Item $_.FullName -Destination $logsDir -Force
  Write-Host "Copied $($_.Name) -> $logsDir"
}
```

## Step 3 — Bootstrap log (if it exists)

```powershell
$bs = "$env:ProgramData\RPGBuildServer\logs\bootstrap-prereqs.log"
if (Test-Path $bs) {
  Copy-Item $bs (Join-Path '<repoRoot>' 'inbox\logs\bootstrap-prereqs.log') -Force
  Write-Host "Copied bootstrap-prereqs.log"
} else {
  Write-Host "No bootstrap-prereqs.log present"
}
```

## Step 4 — Write your report

Create `inbox/01-initial-snapshot.md` with this structure:

```markdown
# 01 — Initial snapshot

## Environment
<paste of the snapshot commands' output, in fenced blocks>

## Surviving diagnostic logs
<list of files: name, size, mtime, copied to inbox/logs/?>

## Bootstrap log
<present? path? truncated tail of the last 50 lines if present>

## Notes / observations
<anything you noticed that the commands above didn't capture — e.g.
"the install folder D:\... still exists with N files in it" or
"there's a half-open VS Installer window in the taskbar from yesterday">
```

## Step 5 — Commit + push

```bash
git add inbox/
git commit -m "01: initial environment snapshot + log retrieval"
git push
```

Then wait. Dev-box-Claude will read your report and respond in
`outbox/02-*.md` with the next concrete test.

## What we are NOT doing in this round

- NOT running `vs_BuildTools.exe` again (don't want to clobber yesterday's
  state before we read the logs).
- NOT modifying the bootstrap script.
- NOT installing anything new.

Pure data-gathering. Once we know what the logs say, we'll plan the
next test (likely the parens-free path hypothesis from the debug doc).
