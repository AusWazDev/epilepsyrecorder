# MER — Working Agreement

**Approved 10 September 2026, AEST.** How chat (claude.ai), the CLI (Claude Code) and the
developer divide work on this project. The evidence it rests on is the design-audit work of
8 and 9 September 2026, recorded in `docs/design-audit/AUDIT.md` §13; that work keeps its own
dates and is not re-dated by this document.

⭐ **NOT FOR: how the code is shaped — that is `docs/ARCHITECTURE.md`. Not for what is stored —
that is `docs/DATA-MODEL.md`. Not for design, layout or UX findings — that is
`docs/design-audit/AUDIT.md`. Not for session history — that is `STATUS.md`. Not for tech stack,
build commands or gotchas — that is `CLAUDE.md`.** This document says WHO DECIDES WHAT and WHEN
WORK STOPS. It records no finding and proposes no fix.

> **Why this lives in the repository and not in the Change Register.** It must reach both
> machines, and only `git push` does that reliably. `AUDIT.md` §13(r) records, in its 9 September
> addition, a travelling document citing a non-travelling artefact — a finding committed on Windows
> whose evidence sat at a OneDrive path the Mac could not follow. The Register is that kind of
> artefact. A working agreement that reaches one machine is an agreement with one half of the team.

---

## 1. Three tiers

### The CLI acts unasked, once a brief is approved

Reads, measurements, enumerations, verifications, controls, the annotations a brief specifies,
and **every subsequent step of that brief through to completion.** Approval attaches to the
brief, not to each step inside it.

⭐ **A read-only investigation is not a change and never needs approval.** Opening files,
running tests that write nothing, counting, diffing, grepping: none of these wait on anyone.

### Chat acts unasked

Briefing reads, ordering work, recording findings, retracting its own errors, drafting proposals.

⛔ **Chat does not ask permission for anything the evidence already decides.** It decides, acts,
and states what it decided in a form that can be reversed in a line. A question whose answer is
already in the evidence is not a question; it is the developer's attention spent on a formality.

### The developer approves

**Every source change. Every copy change. Every "better way of doing something."** Each is
presented as a **proposal** carrying the solution AND why it is better than what exists.

⚠️ **Copy is a change.** An earlier draft of this policy had copy shipping before review. That was
wrong and is withdrawn. Copy carries claims, and for this app claims are load-bearing (see §3).

---

## 2. Four rules that earned their place

### (a) ⛔ Every brief carries an escape clause

A stated condition under which the CLI **stops and reports instead of proceeding.**

⭐ **Evidence: it stopped two wrong changes on 9 September 2026.**

- **§13(ay)** — a fix for a defect that did not exist. The widget test measured `flutter_test`
  font widths, not device font widths; the title was never clipped. The fix brief carried *"you can
  read the widget and chat cannot. If the evidence says otherwise, say so"*, and the CLI said so.
  §13(ay)'s own process record: *a brief that had merely instructed the fix would have shipped a
  change to `home_screen.dart` to satisfy a number that was never a text width, and every one of
  this document's checks would have passed on it.*
- **§13(bi)** — a check that would not have caught what it was built for. A count check inside
  `save()` was affordable, tested and internally consistent, and every candidate loss path shortens
  the list before `save()` is called. The scoping pass disproved it before anything was built.

The CLI reported both times that a brief which merely instructed would have shipped the change
with every check passing.

### (b) ⛔ Every proposal carries its own disproof

The question that would show the proposal wrong, stated inside the proposal.

⭐ **Evidence: §13(bh) and §13(bj).** Chat called §13(bh) *"the most actionable thing in the
document"* and inferred a fix from it: run the migration's count check on every write. The
question that killed it — **"what would this actually have caught?"** — sat in the scoping brief,
not in the proposal. Had it been in the proposal, the fix would never have been proposed.
§13(bh) itself stands unchanged; what did not follow was that closing it addressed §13(be).

### (c) One domain question per brief, non-blocking

Marked as such, answerable in a line, and **the CLI proceeds while it is unanswered.**

⭐ **Evidence, attributed to the briefing party's account rather than to a line in the audit:** the
pivotal catch of the audit — that `LogEventScreen` is the EDIT path, not a duplicate capture
path — came from the developer asking how a record opens from History. Chat never asked. The
audit records the catch and the voided decision it reversed (the §10 "Three decisions" block and
§13(a)); it does not record where the question came from.

⛔ **The question budget exists because domain knowledge is the input chat cannot derive.** On 8
and 9 September it was spent on permission instead. One question per brief, aimed at what only
the developer knows, is the correction.

### (d) Three checkpoints, all condition-triggered

| Checkpoint | Trigger | Action |
|---|---|---|
| **Premise contradicted** | the evidence contradicts a premise the brief rests on | stop and report. Already in force, and the most effective mechanism of the audit |
| **Scope expanded** | a brief produces a finding that outranks its own subject | stop and report. ⭐ The Record Event button flash (§13(ah)) surfaced during a pass on something else and corrected §13(v)'s clean result; a stated rule makes that reliable rather than lucky |
| **Plan check on completion** | a piece of work finishes | one line: what it was expected to cost, what it cost, what changed in the plan. ⚠️ Not a status report and not a request to continue |

⛔ **No periodic status report.** Recorded with its reasoning so it can be revisited: condition-
triggered checkpoints worked across two days; time-triggered reporting was never tried. **This is
an argument from absence and is revisable** if a condition-triggered scheme is later found to have
missed something a clock would have caught.

---

## 3. What always escalates to the developer

- ⛔ **Anything destructive to real records.**
- ⛔ **Any change to the write path.** §13(be) is why: one event record lost on 30 August 2026,
  unrecoverable, and the storage model cannot say how.
- ⛔ **Regulatory or claim wording.** Routes to the adviser, not to chat or the CLI. MER is a data
  capture tool and never diagnostic; wording that touches that line is not ours to settle.
- ⛔ **Anything costing the developer's time, money or hardware.**
- ⛔ **Anything only the developer knows.**
- ⛔ **Any decision the evidence does not actually decide.**

---

## 4. The constraint that is load-bearing

⭐ **Recorded because a future session will be tempted to remove it as friction.**

**CHAT CANNOT READ THE REPOSITORY, AND THAT IS THE MECHANISM, NOT A LIMITATION.** Every correction
across 8 and 9 September 2026 came from chat asserting and the CLI checking. If chat could read,
the check would be chat checking chat — which is the failure mode of every apparatus fault in
§13(aj), §13(az) and §13(bi), where a live instrument pointed at the wrong thing and reported
confidently. Two parties with different inputs disagree when one is wrong. One party with one
input agrees with itself.

⚠️ **The relay overhead is real.** It is fixed by multi-step briefs, internal gates and batched
questions — not by merging the roles.

---

## 5. Where the evidence lives

| Cited here | Where | What it shows |
|---|---|---|
| §13(ay) | `docs/design-audit/AUDIT.md` | escape clause stopped a fix for a non-defect |
| §13(bi), §13(bj) | same | scoping pass disproved a fix before it was built; chat's inference recorded |
| §13(bh) | same | the finding that stands, and the fix that did not follow from it |
| §13(be) | same | the write path's cost of error |
| §13(aj), §13(az) | same | instrument faults that reported confidently |
| §13(ah) | same | a finding that outranked the pass that found it |
| §13(r), 9 Sep addition | same | why this document is in the repository |
| §13(a), §10 "Three decisions" | same | the `LogEventScreen` edit-path catch |

**Where this document and the audit disagree about an event, the audit governs.** This document
summarises; the audit is the record.

---

## 6. Citations — approved 11 September 2026

⛔ **CITE BY SYMBOL. LINE NUMBERS ARE NOT CITATIONS.** `file.dart:symbolName`, not `file.dart:412`.

⭐ **The evidence, so this is not read as preference.** The 10 September 2026 sweep of AUDIT.md for
defects of the document found seven defect instances across four categories. **Four of the seven
were stale line numbers** — two in §13(ah), one in §13(j), one in §13(bi) — every one of them a
correct finding pointing at a line that had since moved. `docs/ARCHITECTURE.md` already carries this
rule for itself and records why: an earlier revision had six line citations in the very table
warning about line rot, and three of the six were wrong within days.

⚠️ **The objection, and its answer.** A symbol appearing twice in a file is ambiguous; a line number
is precise. ⭐ **But in the 10 September sweep the CLI resolved every stale citation by symbol** — the
symbol was sufficient in all four cases, and the line number was the part that had rotted. Precision
that decays is not precision.

⛔ **Where a line number genuinely adds something** — a specific line inside a long function, a
particular row of a table — **cite the symbol AND the line, symbol first**, so the citation survives
the line rotting: `home_screen.dart:_thisMonthCount (line 520 at 4a9b0bd)`. A bare line number
without a commit is never enough; a line number with a commit is a measurement, and the symbol beside
it is what lets the next reader find the thing after the measurement has aged.

⚠️ **Scope.** New writes to `AUDIT.md`, `ARCHITECTURE.md`, `DATA-MODEL.md`, `STATUS.md` and the
Change Register. **Existing citations are not retro-fixed under this rule** — they are the sweep's
problem (§7), and a retro-fix pass would itself be a substantial write into a document that is
mostly historical record.

---

## 7. The citation sweep — a cadence, not a mechanism

⭐ **A CITATION SWEEP IS RUN PERIODICALLY, NOT CONTINUOUSLY.** The 10 September sweep cost one pass
and found seven defect instances across four categories — **including two a mechanical checker could
never catch**: an external citation that supported three of the four clauses it was attached to, and
a "correction" of a statement the document had never made.

⛔ **WHY A CHECKER WAS CONSIDERED AND REJECTED.** A verifier for `file.dart:NNN` citations would build
machinery for exactly the class the symbol rule in §6 eliminates outright, and would miss the class
the sweep actually catches. **Clause-level over-attribution and phantom corrections are judgements
about what a sentence claims, not broken pointers.** No tool reads a sentence and asks whether its
source says all of it. The cost of the machinery would buy the cheap half of the problem.

**The sweep's categories, from the 10 September run, with what that run found:**

| | Category | 10 Sep result |
|---|---|---|
| a | citations pointing at a source that does not say what is claimed | 1 (architectural fact 1, over-attributed by one clause) |
| b | internal cross-references to a letter or section not carrying what is claimed | 0 of 57 letters and 12 sections |
| c | prose counts disagreeing with an adjacent table or list | 1 (§13(bm), 41 whole-token vs 51 substring, method unstated) |
| d | line-number citations that no longer point at the cited symbol | 4 of a 13-citation sample |
| e | figures superseded by a later annotation but still stated unqualified earlier, or corrections of statements never made | 1 (the phantom "nine") |

⭐ **Category (d) should shrink to zero under §6, and its size at each sweep is the rule's own
measure.** If it does not shrink, the rule is not being followed, and the sweep is where that shows.

⚠️ **THE COVERAGE LIMIT, HONESTLY.** That sweep sampled **13 of 118 distinct line citations** and
found 4 stale. ⛔ **The unsampled 105 are unmeasured, and the sampled rate suggests more.** The
categories (a), (c) and (e) were checked only for the writes made on 10 September; older text was
not read for them. A sweep reports its denominator or it reports nothing.

**When to run it:** after any substantial writing pass, and before the document is handed to anyone
or taken as context by a fresh session. ⚠️ **Not on a clock.** A sweep on a schedule runs when nothing
has changed and is skipped when everything has; a sweep tied to writing runs when there is something
to find.
