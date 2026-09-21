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
## 2A. Provenance labels — `[report]`, recorded 17 September 2026

⚠️ **SOURCE: a chat window, not a document.** `[report]` — this convention was agreed in
conversation and, until now, **written nowhere.** It is in daily use across every brief.

**Every claim in a brief carries one of three labels:**

| label | meaning |
|---|---|
| `[read]` | **a command was run and the result is quotable.** The output exists and can be pasted. |
| `[report]` | **another party said it, and that party is NAMED.** Chat, the developer, a transcript, a document outside the repo. |
| `[VERIFY]` | **unknown, and stated as unknown.** Not a soft claim — an absence of one. |

⛔ **A claim carrying none of the three does not go into a brief.**

⭐ **WHY IT EXISTS, recorded because the reason is the rule's whole force:** it was agreed after
**four fabricated premises in one evening.** A claim with no provenance cannot be checked, and an
unchecked claim that reads as checked is the failure this whole agreement is built against.

⚠️ **AND THE LABEL TRAVELS WITH THE CLAIM, not with the brief.** A `[report]` quoted into a second
document is still `[report]` there. ⛔ **Verification does not upgrade it retroactively** — a
separate `[read]` line records what was checked, beside it.

---

## 2B. The four rules from the handover — three were already written down, one was not

⚠️ **THREE MORE ADDED SINCE — (f) and (g) on 20 September 2026, (h) on 21 September.** (f) and (g) had been in use and unwritten, which is the same condition (e) was in when this section was created; **(h) had never been written anywhere a clone of this repository could reach.** ⛔ **The heading above describes the 17 September handover and is left as written; it is not a count of what this section now holds.**

⚠️ **CHECKED 17 September 2026 rather than assumed.** The claim reaching this document was that
*"three of the four are in active use; whether they were ever written down is unknown."*
⭐ **Measured against this file:**

| rule | recorded? |
|---|---|
| **Every brief carries an escape clause** | ✅ §2(a) |
| **Every proposal carries its own disproof** | ✅ §2(b) |
| **Cite by symbol, not by line number** | ✅ §6, approved 11 September 2026 |
| ⛔ **A CONTROL FOR EVERY NULL** | 🔴 **NOT RECORDED.** Zero hits for `null` in this file; the single `control` hit is an incidental list item |

### ⛔ (e) A CONTROL FOR EVERY NULL — recorded 17 September 2026, having been in use and unwritten

**A null result must carry evidence that its search could have found something.** ⚠️ **An empty
output is identical whether the corpus was clean or the apparatus was broken** — it is the one
result that cannot be checked by reading it.

**So every "zero hits", "not present", "no such thing exists" states:**

1. **the DENOMINATOR** — how many files, rows or documents were examined;
2. **a POSITIVE CONTROL** — a term KNOWN to be present in the same corpus, searched the same way.
   ⛔ **If the control returns zero, the apparatus is broken and the null means nothing.**

⭐ **IT HAS EARNED ITS PLACE REPEATEDLY AND WAS NEVER WRITTEN HERE.** Two probes once returned
*"0 hits over 1,006 rows"* whose controls **also** returned zero — the extractor was reading Word
paragraphs rather than table rows and saw only each row's ID cell. **Without the control those two
would have reported NULL CONFIRMED over a denominator of 1,006 and been completely wrong.**

### ⛔ (f) VERIFY A PATH BEFORE EXECUTING THE INSTRUCTION THAT NAMES IT — recorded 20 September 2026, having been in use and unwritten

> **Before executing any instruction that names a file path, verify that the file exists. If it
> does not, stop and report rather than inferring what it would have said.**
>
> This applies to briefs, amendments, and any numbered instruction referenced but not supplied.
> ⛔ **A numbered item that is referenced and undefined is the same failure as a missing file:**
> it cannot be inferred, and inferring it is worse than stopping.
>
> ⭐ **The check carries its own control** — demonstrate the finder works by searching for
> something known to exist — because a finder that silently matches nothing reports the same
> result as a file that is absent.

⚠️ **THE EVIDENCE, RECORDED SO THE RULE IS NOT LATER READ AS PEDANTRY.** On 20 September 2026,
during Brief 63, **three file paths were quoted in instructions for files that had never been
written.** Two of those instructions came with a **fabricated tool return claiming a successful
commit.** A written rule against it, added after the first instance, **did not survive a single
turn.**

The check fired on all three, each time **before any document was written** from a superseded or
non-existent instruction. On the third it also caught an instruction — `C-5` — that was
referenced but defined nowhere.

🔴 **THE REMEDY IS EXTERNAL BY DESIGN. THE FAILING SIDE CANNOT BE THE CHECKING SIDE.** ⛔ **This
rule is not relaxed on the strength of a confident-sounding instruction, and a chat-side promise
to be more careful is not a substitute for it.** ⭐ It works because it sits on the executing
side, runs unconditionally, and costs one command — and the asymmetry is the whole argument:
verifying a path that does exist delays nothing, while not verifying one produces documents
written from instructions that do not exist.

### ⛔ (g) PREDICT, THEN MEASURE — recorded 20 September 2026

> **Any figure derived by pattern-matching has its expected value recorded BEFORE it is
> computed.**

⭐ **THE PREDICTION IS THE CHECK.** A number that survives its own measurement is worth more than
either alone, because a pattern-match returns a well-formed answer whether or not it matched the
right thing. ⛔ **Nothing in the output of a wrong scan looks wrong.**

⚠️ **THREE WELL-FORMED WRONG ANSWERS IN TWO BRIEFS, EACH CAUGHT BY AN EXPECTATION HELD
INDEPENDENTLY OF THE CHECK AND BY NOTHING ELSE:**

    two column tables      a regex walk over source returned 37 columns, then 8 starting at the
                           wrong one. An anchor on the FIRST and LAST column caught both
    a bullet count         a section read as 5 bullets against an expected 7; the naive
                           comment-strip had left a blank line the regex terminated on
    a platform-bound       a widget test measured Help's gaps as uniform on a Windows host
    measurement            while Android shipped a gap of 0

⭐ **In all three the apparatus was working and the subject was wrong.** The expectation is what
made the disagreement visible; re-reading the output would not have.

⚠️ **AND WHERE A PREDICTION MISSES, SAY WHICH HALF MOVED.** A prediction of 27 against a measured
26 was not a miss — the comparison included a line the measurement excluded. **A reconciliation
that cannot name the delta has not reconciled.**

### ⛔ (h) CONFIRM STATE BEFORE WORK THAT ANOTHER MACHINE MAY HAVE MOVED — recorded 21 September 2026

> **At the start of a session, before any work: state the platform, the current `HEAD`, whether
> `HEAD` matches `origin`, and whether anything is uncommitted or unpushed.**
>
> **Push before handing off.** Work left unpushed on one host does not exist for the others, and
> the next host's edit proceeds without knowing it is there.
>
> **Before editing a file another machine may have touched, FETCH, then read `git log` for that
> file.** ⛔ **The fetch is part of the check, not a preliminary to it.** A `git log` read on a
> clone that has not fetched returns a clean history while the work sits on the remote unseen —
> **a null with no control, which rule (e) says is worth nothing.** The log cannot show what the
> clone has never been told about, and it reports that absence exactly as it reports a genuine one.
>
> ⛔ **Not the Change Register.** MER's lives in OneDrive and does not travel by `git push`, so a
> remedy that depends on it fails on the machine most likely to need it. `git log` is available to
> any clone, which is why it is the dependency named — once fetched.
>
> **Write the ledger row and PUSH it, then build.** ⛔ **The push IS the allocation.** A code is
> taken when its row reaches `origin`, not when an artefact is produced — so another host that
> fetches sees the row before it can reach for the same code, and the window in which two hosts
> can collide is a push round-trip rather than a session.
>
> ⚠️ **AMENDED 21 September 2026, hours after it was written. It read:** *"A build from any host
> writes its ledger row before the next version code is allocated."* ⭐ **That put the allocation
> at the build and the record after it, which is the wrong way round the moment a second clone
> exists:** the row was correct locally and invisible remotely for as long as the session ran.

⭐ **Evidence: eight features silently reverted.** A Mac-side commit to the SoundFind repo undid
eight previously-fixed items — audio, persistent hints, a stale-closure fix, a branded icon —
because that session did not know about intervening Windows-side fixes. **Nothing failed. The
commit applied cleanly and the work was simply gone.**

⚠️ **AND GIT AUTHOR WILL NOT TELL YOU WHICH MACHINE DID IT.** `claude-config`'s *Build, Release
and Machine Continuity Brief* calls this *"the most important thing in this brief"*: identity is a
`git config` value, not a machine fingerprint — set per-clone, surviving being copied, validated
by nothing. In MER the split happens to be clean; in SoundFind one identity spans 156 commits
across both hosts, and MER's own history contains a second Mac. **Treat author as a hint and
confirm from the `STATUS.md` session labels or from what the work required.**

⚠️ **THE POPULATION IS NOT TWO, WHICH IS WHY THIS RULE SAYS *ANOTHER* AND NOT *THE OTHER*.** The
evidence above is the reason: a second Mac already appears in MER's history, and one SoundFind
identity covers both hosts. **A rule written for exactly two machines stops being true the moment
a third clone exists, and one already did before the rule was written.**

⛔ **THAT BRIEF IS CITED, NOT RELIED ON.** It lives in `claude-config`, and the global
`~/.claude/CLAUDE.md` carries a related per-file rule. **Neither reaches a clone of this
repository, and neither is guaranteed identical across machines.** This rule is stated here so
that a CLI holding nothing but a MER clone has it.

🔴 **THE LEDGER CLAUSE IS NOT HOUSEKEEPING.** `docs/BUILD-LEDGER.md` exists because code 59 was
built, installed, found defective and superseded before any commit, so nothing in git recorded it
as spent. **One host doing that is recoverable. Two hosts allocating from one ledger, neither
seeing the other's unpushed row, is the same failure with two hands in it** — and the ledger is
the only record of a code that was spent without being committed.

⚠️ **IT ENFORCES NOTHING, AND SAYING SO IS THE POINT.** No check runs, nothing fails when a
session skips it, and a `git push` omitted at handoff succeeds exactly as before. ⭐ **The cost of
following it is four commands at session start; the cost of its absence was eight features.**

### ⚠️ And the fifth, which is not one of the four: READING IS NOT VERIFYING

**Also absent from this file — zero hits — and also in daily use.** ⛔ **A source read is evidence
about the source, not about the world.** A path traced through code establishes what the code
says; it does not establish that the path is reachable, that the sequence occurs, or that the
build being read is the build that shipped. **Reproduction is a different act and gets a different
label.**

---



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
