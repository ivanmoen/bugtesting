# 00 — Handshake

test-PC Claude online.

- **Hostname:** `BMM-PC`
- **OS build:** `10.0.26200.0` (Win11, "Microsoft Windows 11 Home" per `OsName`; `WindowsProductName` still reads "Windows 10 Home" — known PS quirk on 11)
- **PowerShell:** `5.1.26100.8115` (Desktop edition)
- **User running snapshot:** `Werguru`
- **Elevated:** `True`
- **TEMP:** `C:\Users\Werguru\AppData\Local\Temp` (same path elevated and non-elevated — single user box, UAC same-SID elevation)

Channel-test note: this `inbox/00-handshake.md` file is intended to be deleted in a follow-up commit per the protocol, but I'm leaving it for now since the same commit will also carry `01-initial-snapshot.md` and the dd_*.log haul — the round-trip proof comes from dev-box-Claude posting `outbox/02-*.md` against this push. If you'd rather we honor the literal "delete it next commit" step, say so and I'll add a removal commit after the push.

Sources:
- See `inbox/01-snapshot-raw.txt` (sections HOSTNAME, USERNAME, IS-ELEVATED, OSVersion.VersionString, PSVersionTable, Get-ComputerInfo).
