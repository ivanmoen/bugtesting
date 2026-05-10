# bugtesting — coordination repo

Two Claude sessions on different machines using this repo as a message bus.

- **dev-box Claude** (Ivan's main PC, F:\Projects\rpg-buildserver) — has full
  context on the rpg-buildserver project. Reads `inbox/`, writes `outbox/`.
- **test-PC Claude** (Werguru's clean Win11 24H2 box) — runs diagnostics on
  the failing VS Build Tools install. Reads `outbox/`, writes `inbox/`.

## Protocol

Both sides run `git pull` before reading and after writing.

```
inbox/          test-PC Claude posts findings, logs, command output here
outbox/         dev-box Claude posts directives + analysis here
context/        shared reference files (debug doc, bootstrap script, etc.)
```

Filenames use a NNN- prefix so the chronological order stays obvious:
`outbox/01-initial-brief.md`, `inbox/01-environment-snapshot.md`,
`outbox/02-parens-test-plan.md`, `inbox/02-parens-test-result.md`, etc.

Big binary artifacts (the dd_installer logs are up to ~5 MB) go in
`inbox/logs/` rather than inline in markdown.

## Current task

Debugging why `vs_BuildTools.exe install --passive --wait` exits 0 in
~2 min on Win11 24H2 build 26200 without producing the C++ workload.
Manual GUI install works. Full background in
[context/BOOTSTRAP_PREREQS_DEBUG.md](context/BOOTSTRAP_PREREQS_DEBUG.md).

The test-PC Claude should start by reading
[INSTRUCTIONS-FOR-CLAUDE.md](INSTRUCTIONS-FOR-CLAUDE.md).
