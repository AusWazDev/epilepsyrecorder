# Pass 2 — per-sentence verdicts, 26 September 2026

The 30 sentences are in `sample30.txt` (numbered to match). Each was searched in the repo's
tracked files and commit messages, for its FACT in plausible repo wording, not its phrasing.
The raw probe hits are in `pass2_probe_output.txt`. **A hit is a candidate, not a verdict**:
each was read in context before being counted.

**Verdict key.** FILES: the fact is in a tracked file. LOG: only in a commit message. ONLY: in
neither, under any wording tried. ⚠️ ONLY can mean "not found by my probes", so this pass can
still OVER-count the Register-only share. It cannot under-count it.

| # | Verdict | Where the fact was found, or what was tried |
|---|---|---|
| 1 | ONLY | Doc-integrity checks for a ClickUp write (heading, row, fence counts). "code-fence count", "heading counts", "fence", "numbered-row": nothing |
| 2 | FILES | `wm size` rotation: `STATUS.md`, `AUDIT.md`, `DESCRIPTION-430.md` |
| 3 | FILES | `#447598`, `3.38:1`: `AUDIT.md`, `DECISIONS.md`, `lib/main.dart` |
| 4 | FILES | `AUDIT.md`: *"every offerable value scores zero"*; `ARCHITECTURE.md` |
| 5 | FILES | *"any future relabelling does this again"*: `STATUS.md`, `AUDIT.md` |
| 6 | LOG | `find.byType(BoundedWrap).first` meaning the observation picker: commit `5e4af17` (the test file carries the code, not the finding) |
| 7 | FILES | `lib/models/vocabulary.dart`, beside the `Dizzy or spinning` seed. ⭐ **The repo holds NEWER reasoning**: *"Nothing had ever been recorded against this entry … but that is not why the label could move."* |
| 8 | FILES | *"documentation accuracy on a provable fact"*: `AUDIT.md` |
| 9 | FILES | *"same chassis, 375×667, 20 pt status bar, no bottom inset"*: `captures/INDEX.md` |
| 10 | FILES | *"permission-asking of the day against … the working agreement's own tiers"*: `AUDIT.md` |
| 11 | FILES | D2's minimum not set: `AUDIT.md` (*"the 416 figure must not be used as D2's minimum"*) |
| 12 | LOG | A real past state with the wrong cause: commit `69df959` |
| 13 | ONLY | What ClickUp normalises on every write. "ClickUp" with normalise/escape/rewrite: nothing in this repo |
| 14 | ONLY | *"leg 3 is no longer true"*, the post-ictal-set argument. "post-ictal", "leg 3", "three legs", "EXPIRING": nothing |
| 15 | FILES | The banner in the exclusive chain, captured at zero data risk: `STATUS.md`, `CONTRACTS.md`, `DECISIONS.md` |
| 16 | ONLY | Commentary on two 7 September verification findings. "louder than it was", "under-described", "measured two things": nothing |
| 17 | FILES | `AUDIT.md`: *"The ranking is inert on the list where the bound bites hardest"* |
| 18 | FILES | `Total saved: 0` beside the fallback banner: `STATUS.md` |
| 19 | ONLY | Commentary linking backlog item 24 to the stale-status class. The class itself is in `C:\dev\CLAUDE.md`, outside this repo; the linkage is nowhere |
| 20 | FILES | `AUDIT.md`: *"Dynamic Type is non-linear per text style, and Android's font-size setting is capped per OEM"* |
| 21 | FILES | Second proposed fix disproved on scoping: `AUDIT.md` |
| 22 | FILES | *"a guess dressed as a constant"*: `AUDIT.md` |
| 23 | ONLY | Panic's somatic entries serving syncope as a PRODROME, so they would be needed in the beforehand vocabulary too. `ARCHITECTURE.md` names panic and presyncope MATERIAL, not this reasoning |
| 24 | LOG | The migration duplicating entries because ICHD-3 names them in both prodromal and postdromal lists: commit `156501e` |
| 25 | FILES | *"is never touched, by anything, ever"*: `AUDIT.md`, `lib/models/vocabulary.dart` |
| 26 | FILES | What the export REPRESENTS: `STATUS.md` |
| 27 | FILES | An instrument that can only under-report: `CLAUDE.md`, `DECISIONS.md` |
| 28 | FILES | `renameEntry` with no caller: `STATUS.md`, `ARCHITECTURE.md` |
| 29 | FILES | Pallor. ⭐ **The Register's version is SUPERSEDED**: it says pallor was *"deliberately NOT added"*; `lib/models/vocabulary.dart` now seeds it as beforehand-only, with the reason |
| 30 | FILES | *"COMPLETENESS IS THE RIGHT AXIS"*: `AUDIT.md` |

**Totals: FILES 21 · LOG 3 · ONLY 6**, of 30.

**The six ONLY, by kind:** research reasoning (14, 23), ClickUp handoff-write mechanics (1, 13),
process commentary (16, 19).
