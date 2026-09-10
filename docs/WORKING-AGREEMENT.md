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
