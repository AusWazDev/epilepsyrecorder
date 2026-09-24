# MER-176-U — variant U fixture evidence (Brief 176 / 181)

⭐ **Start with `PROVENANCE-176.md`.** Its first block, **RESUME HERE**, is where the next session
picks up; its second, **FIXTURE CHECKS**, travels with the fixture and every clone of it.

**Status as at 24 September 2026, 19:16 AEST: seeded, NOT frozen.** (ii) has not run. MER-176-U
is shut down, with the active marker still present in both suites.

## The simulators — three names, and they do not mean the same thing

| Name | UDID | What it is |
|---|---|---|
| `MER-176-U` | `2E364C3F-DA09-4B82-9EAD-21EDE359692D` | **The fixture device**, seeded, not yet frozen. (ii) and the freeze run on THIS one |
| `MER-176-U-POSTINCIDENT-1737-NOT-FROZEN` | `8E484F3D-67D5-4B5A-BA9B-D3E8BD2040F2` | ⛔ **NOT the fixture.** Rollback copy of the state the 17:37 forced logout left, cloned before any boot |
| *(frozen clone — does not exist yet)* | — | Created by the freeze. Must be named so it cannot be confused with the row above |

⚠️ Simulators live on the Mac that made them (`~/Library/Developer/CoreSimulator/Devices/`).
They are not in this repository; this directory holds the evidence about them.

## What is here

| Path | What |
|---|---|
| `PROVENANCE-176.md` | Every action against the simulator, in order, with times; the defect register D1–D4 with read/observed labels |
| `screenshots/` | The three seed-start screenshots and the post-boot pre-launch one. Their sha256 values are quoted in the provenance (16-char prefixes for the first three, as recorded at the time) |
| `payloads/` | The SYNTHETIC `simctl push` payloads. **Our apparatus, not a user path** |
| `manifests/` | Full-device sha256 manifests: source before and after the POSTINCIDENT clone (identical), and the clone |

## Deliberately NOT here, because this repository is public

| Item | Where | sha256 |
|---|---|---|
| 1.0.2 crash report, SIGSEGV 12:06:59 (**OPEN**) | Mac, `~/Library/Logs/DiagnosticReports/Runner-2026-09-24-121920.ips`, and a copy in `~/dev/_rescue/2026-09-24-claude-502-scratchpad/` | `b49b17279f2227c9dbbe6b43f128222332e5a34b9cd9f027de9340c2a2fb8abd` |
| WindowServer watchdog reports, 17:37 (host diagnosis) | Mac, same rescue directory | — (host process list; not published) |
| The session transcripts and the full scratchpad rescue | Mac, same rescue directory | — |

The crash report carries host identifiers (`crashReporterKey`, `sleepWakeUUID`), so it stays off
a public surface. Its facts, as the provenance quotes them: 1.0.2 (3), pid 21814, launched
11:57:51, `EXC_BAD_ACCESS` / `SIGSEGV` `KERN_INVALID_ADDRESS`. **Cause not analysed.**
