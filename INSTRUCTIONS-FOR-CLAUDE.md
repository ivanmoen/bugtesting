# Instructions for the test-PC Claude

You are running on Werguru's clean Win11 24H2 box (OS build 26200) via
Parsec. There is another Claude session running on Ivan's main dev box
(F:\Projects\rpg-buildserver). The two of you coordinate through this
git repository — `inbox/` is your outbox to dev-box-Claude, `outbox/` is
where dev-box-Claude posts directives to you.

## Your role

Be the hands on this PC. Run diagnostic commands, capture log files,
upload them to `inbox/`, and wait for dev-box-Claude's response in
`outbox/`. You are NOT expected to debug the rpg-buildserver project on
your own — dev-box-Claude has the full project context. You execute,
observe, report.

## The bug you're investigating

`worker/installer/bootstrap-prereqs.ps1` (a copy is in `context/`) is
supposed to silently install Visual Studio Build Tools 2022 + the
`Microsoft.VisualStudio.Workload.VCTools` workload. On this PC it
exits code 0 in ~2 minutes without producing the workload. Manual GUI
install (no `--passive`) works reliably.

Full investigation history (what's been tried, what's been ruled out,
hypothesis ranking) is in
[context/BOOTSTRAP_PREREQS_DEBUG.md](context/BOOTSTRAP_PREREQS_DEBUG.md).
**Read it before doing anything else** — you'll save us both a lot of
back-and-forth.

## Communication protocol

```bash
# Before reading anything: pull the latest from dev-box-Claude.
git pull

# After writing a file: commit + push so dev-box-Claude can read it.
git add inbox/ && git commit -m "<short note>" && git push
```

Filenames use a `NN-<topic>.md` prefix that matches the directive you're
responding to. Example: dev-box posts `outbox/02-parens-test.md`, you
respond with `inbox/02-parens-test-result.md`.

For binary log files (the dd_installer logs are up to ~5 MB), drop them
in `inbox/logs/` and reference the path in your markdown report. Don't
paste 5 MB of log content into a .md file.

## What to do first

1. `git pull` to make sure you have the latest.
2. Read `outbox/01-initial-brief.md` — that's dev-box-Claude's first
   directive. It tells you exactly which commands to run and which
   files to grab.
3. Execute. Report results in `inbox/01-initial-snapshot.md` (and
   `inbox/logs/` for the binary log files).
4. Commit + push.
5. Wait for `outbox/02-*.md` and continue from there.

## Things to keep in mind

- This PC's PowerShell is **5.1**. The `.ps1` file is read as ANSI; do
  not introduce any non-ASCII characters when you edit scripts here.
- The bootstrap script needs **elevation** to run for real (it installs
  software). For diagnostic commands that don't install anything,
  non-elevated is fine. When you do need elevation, document that in
  your report rather than silently switching consoles.
- VS Build Tools install can be on **C:\\** or **D:\\** on this box —
  check which drive has free space before suggesting a path. The dev
  box has Program Files on D:\\ (per project memory), but on this PC
  the previous attempts were against
  `D:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools`.
- Windows rotates `%TEMP%`. The `dd_installer_*.log` files from
  yesterday may already be gone. If they are, say so explicitly — don't
  fabricate a "log not found, here's what I think happened" response.

## Sanity check

Before you start, confirm:
- `git status` in this repo is clean
- `git pull` works (you can read from the remote)
- A test push works: write a test file in `inbox/00-handshake.md`
  saying "test-PC Claude online, hostname: <hostname>, OS build:
  <build>", commit + push it, then delete it in your next commit.

That confirms the channel works in both directions before we sink
real diagnostic work into it.
