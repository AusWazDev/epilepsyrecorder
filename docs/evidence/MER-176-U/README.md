# MER-176-U — variant U fixture evidence (Brief 176 / 181)

⭐ **Start with `PROVENANCE-176.md`.** Its first block, **RESUME HERE**, is where the next session
picks up; its second, **FIXTURE CHECKS**, travels with the fixture and every clone of it.

**Status as at 24 September 2026, 20:05 AEST: FROZEN.** (ii) ran at 20:01 and matched the prediction (markers
cleared in both suites; 6 records untouched). The frozen fixture is `MER-176-U-FROZEN-FIXTURE-20260924`.
Its must-match and expected-to-change lists are in `manifests/MER-176-U-FROZEN-FIXTURE-20260924.MANIFEST.md`.
*(Superseded: "as at 19:16 AEST: seeded, NOT frozen. (ii) has not run.")*

## The simulators — three names, and they do not mean the same thing

| Name | UDID | What it is |
|---|---|---|
| `MER-176-U` | `2E364C3F-DA09-4B82-9EAD-21EDE359692D` | The source device. (ii) and the freeze ran on it; it is left in the same frozen state, shut down. **Start 180b from the frozen clone, not from this device** |
| `MER-176-U-POSTINCIDENT-1737-NOT-FROZEN` | `8E484F3D-67D5-4B5A-BA9B-D3E8BD2040F2` | ⛔ **NOT the fixture.** Pre-(ii) rollback: the state the 17:37 forced logout left, markers still present, cloned before any boot |
| ⭐ `MER-176-U-FROZEN-FIXTURE-20260924` | `427DB6D1-65C0-4B86-88E9-95DE770CD88E` | ⭐ **THE FROZEN FIXTURE**, post-(ii), cloned 24 Sep 20:05 |

⚠️ Simulators live on the Mac that made them (`~/Library/Developer/CoreSimulator/Devices/`).
They are not in this repository; this directory holds the evidence about them.

## What is here

| Path | What |
|---|---|
| `PROVENANCE-176.md` | Every action against the simulator, in order, with times; the defect register D1–D4 with read/observed labels |
| `screenshots/` | The three seed-start screenshots and the two post-boot pre-launch ones (19:06 and 20:01). Their sha256 values are quoted in the provenance (16-char prefixes for the first three, as recorded at the time) |
| `payloads/` | The SYNTHETIC `simctl push` payloads. **Our apparatus, not a user path** |
| `manifests/` | Full-device sha256 manifests for both clones (source before and after each clone, and the clone), plus the frozen fixture's MANIFEST with both lists |
| `frozen/` | Host copies of the three frozen plists, with `host-copies.sha256` |

## Deliberately NOT here, because this repository is public

| Item | Where | sha256 |
|---|---|---|
| 1.0.2 crash report, SIGSEGV 12:06:59 (**OPEN**) | Mac, `~/Library/Logs/DiagnosticReports/Runner-2026-09-24-121920.ips`, and a copy in `~/dev/_rescue/2026-09-24-claude-502-scratchpad/` | `b49b17279f2227c9dbbe6b43f128222332e5a34b9cd9f027de9340c2a2fb8abd` |
| WindowServer watchdog reports, 17:37 (host diagnosis) | Mac, same rescue directory | — (host process list; not published) |
| The session transcripts and the full scratchpad rescue | Mac, same rescue directory | — |

The crash report carries host identifiers (`crashReporterKey`, `sleepWakeUUID`), so it stays off
a public surface. Its facts, as the provenance quotes them: 1.0.2 (3), pid 21814, launched
11:57:51, `EXC_BAD_ACCESS` / `SIGSEGV` `KERN_INVALID_ADDRESS`. **Cause not analysed.**
