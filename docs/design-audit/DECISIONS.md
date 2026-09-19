# The component vocabulary — decisions, constraints, and what finishing means

**For `docs/design-audit/DECISIONS.md`.** Written 17 September 2026 AEST, at `dbe9086`.

⛔ **This document is not a narrative of the build.** `AUDIT.md` holds the findings; the commit log
holds the work. **This holds the DECISIONS and their reasons**, so that a future reader who disagrees
with one can see what it was weighed against before re-opening it.

---

## ⛔ How to read this, and the one distinction that matters

**Two kinds of statement appear below and they carry different authority.**

| | |
|---|---|
| ⭐ **A DECISION** | What was chosen, and why. **Authoritative.** Change it deliberately, annotate it in place, and quote the old wording. |
| ⚠️ **A CLAIM ABOUT THE CODE** | ⛔ **Always check it. Never inherit it.** Every symbol and figure below was true when written and the repository is the only thing that knows whether it still is. |

⛔ **This distinction is not pedantry — it is the source of nearly every error this build produced.**
**A design decision stated as fact is harmless. A fact about the code stated as a decision ships a
defect.**

---

## What must be TRUE when this is finished

**Not steps. Outcomes. Each one is checkable, and the build is done when all of them hold.**

1. **One colour token per role, and no widget names a colour directly.** A literal outside the token
   set fails a check rather than being noticed.
2. **One type step per element class, and no literal size or weight outside `MERType`.**
3. **One selection idiom.** The form and the wizard do not use different controls for the same field.
4. **One removal model: hidden is a state, reversible, and it is never called a place.**
5. **One destructive treatment, and it is the only red control in the app.**
6. **Every scope statement is true of the file it describes** — the export sheet's count, the
   filename, the banner, and the empty state each say what is actually included.
7. **Nothing that was reversible claims to be permanent, and nothing permanent claims to be
   reversible** — in any dialog, label, semantic string, Help text, or test reason.
8. ⛔ **The 200% pass shows no truncation or overflow that was not there before**, measured with both
   instruments: `RenderFlex OVERFLOWING` cannot see a `Text` that fitted by ellipsising.

---

## ⛔ What must NEVER change, and why each exists

**These are not preferences. Each one has a failure behind it.**

**Capture and the record**

- ⛔ **Nothing ever gates capture, the record, or export.** A standing rule, not a current preference.
- ⛔ **`occurredAt`: a future time is REFUSED rather than clamped, and clearing restores null.**
  ⭐ **Null means "not asked", not "it happened now"** — the difference between an absent observation
  and a fabricated one, in a medical record.
- ⛔ **`timestamp` is when it was logged and is never rewritten on edit.** ⭐ **A record must not
  claim to have been logged at a time it was not.**
- ⛔ **Record ids are compared by EXACT STRING EQUALITY and are never case-folded, anywhere.** Swift
  generates uppercase UUIDs and Dart lowercase; records in the wild carry both. ⚠️ **Folding would
  make the drain and restore disagree and break matching against every backup ever written.**

**Storage and recovery**

- ⛔ **Backup is the preservation path; export is the sharing path.** Restore is merge-by-id,
  add-only, existing-wins — so on a fresh install it is a full reconstruction.
- ⛔ **Anything added to a record travels in the backup payload.** ⚠️ **A field absent from backup is
  destroyed by an uninstall, and retention is FOREVER.**
- ⛔ **Storage keys are immutable once published.** Renaming one orphans every existing user's data.
- ⛔ **Repo names predate both rebrands and are never renamed.**

**Regulatory position**

- 🔴 **SETTLED 17 SEPTEMBER 2026, AND IT IS THE STANDING POSITION RESTORED RATHER THAN A NEW ONE.**
  **MER is positioned as a DATA CAPTURE TOOL ONLY, never diagnostic. Claim wording is
  load-bearing. Anything touching diagnosis, prognosis, monitoring or treatment ROUTES TO THE
  ADVISER rather than being decided in a brief.**

  ⛔ **A statement made in a chat window — `[report]`, source a chat window and not a document —
  withdrew that routing.** Quoted in place rather than deleted, because it was made in good faith
  and was acted on:

  > *"This isn't a medical app, so there is not medical compliance to adhere to"*

  ⚠️ **SUPERSEDED 17 September 2026.** Put to the developer against the standing instruction it
  conflicts with; **the developer's answer was to stay with the project instructions.**

  ⛔ **AND THE CLASS, WHICH IS WHY THIS IS RECORDED HERE RATHER THAN NOTED AND DROPPED: a standing
  instruction was withdrawn in a conversation and the withdrawal reached no document.** For a
  period **nobody can now bound**, the project was operating against an instruction its own
  instructions still stated. ⭐ **A reader who finds only the restoration cannot tell that the
  routing ever lapsed, or for how long.** That is what the quotation above is for.

  **Three consequences, recorded so they are not re-litigated:**

  1. ⛔ **The terms' liability clause** — a cap at *"the amount you paid for the app"*, which
     becomes a cap of **zero** at a free price — **goes to the adviser. It is not drafted in a
     brief.**
  2. **Store and website copy stays on capture-tool wording.** Any claim touching diagnosis,
     prognosis, monitoring or treatment routes out.
  3. ⭐ **The severity relabel at `5e4af17`** — *"Severity"* to *"Compared with the others here"* —
     **is consistent with this position and is not revisited.** It moved the copy AWAY from a
     clinical scale toward a self-relative comparison, which is the direction this position points.


**Process**

- ⛔ **`dart format` is never run on this codebase.** The alignment is hand-maintained.
- ⛔ **Annotate, never rewrite.** A record of what was decided on a past date must stay true; mark
  supersessions in place and quote the old wording.

---

## The decisions

### Colour — C1, C2, C3

**Role-named tokens, 35 of them, built from five role categories: foundation, text, status, identity,
and destructive.** No widget names a colour; nothing assumes `onSurface` equals `primary`; no opacity
on text; accents are never fills.

⭐ **Identity became a fifth category because the event-type palette had no expressible role** — the
escape clause fired and the set grew rather than the values bending. **Severity went the other way
and took the standard chip treatment, which was a subtraction.**

**C2: the destructive control is outlined and its companion is a text button, with no filled button
in those dialogs at all.** ⛔ **The form's discard dialog is deliberately inverted and must not be
normalised** — the test is *did the user come here to do this thing*.

⭐ **`End event` takes `primary`, not the destructive token**, because it and `Record event` render
together 113 apart: two controls, not one in two states.

⚠️ *[Both names recased by Amendment 1.2, which retired Title Case on these two controls. This
sentence previously read* **`End Event` … `Record Event`** *. The colour decision it states is
unchanged — only the labels moved.]*

### Type — T1

**Six steps: 10, 12, 14, 16, 18, 28. Three weights: `w400`, `w600`, and `w700` reserved for
display.** Even values only, which is what retired the half-point sizes.

⭐ **The principle: collapse where the data is a smear, keep where it is already a step.** Nine to
sixteen had no gap wider than a point and two adjacent values held 56 of 122 sites.

⛔ **`MERType` is the SOURCE and the theme is built FROM it**, so a widget with a context reads the
theme, a const widget reads the constants, and divergence is not expressible. ⚠️ **The (step, colour)
pairs are enumerated; a new pair is a decision, not a convenience.**

**Uppercase registers carry letterspacing.** ⚠️ **The register is not detectable by the transform
that applies it** — most uppercase sites are literal capitals, not `.toUpperCase()` calls.

### Removal — R1, R4–R7

⛔ **Hidden is a STATE, not a place. No bin, no destination screen, no place-noun.** The app already
expresses this concept as a state and inventing a second idiom is the defect the vocabulary exists to
remove.

**The complete list stays complete everywhere. One derived view excludes hidden rows. Every read site
is classified deliberately into render, integrity, or reconciling.**

⛔ **The filter cannot live on the stored list.** ⚠️ **Confirm against the repo before relying on it:
the store's write path is a full delete-and-reinsert, list position persists as an ordinal, and at
least one screen's local list reaches that write path — so a filter at read empties the bin on the
next write.**

⭐ **`Show hidden` is a FILTER — the user turns it on, so it joins the clearable set and Clear-all
clears it. Hiding the state never joins. Two different things a boolean was conflating.**

**The scope claim is a COUNT PAIR, not a boolean** — what the export will contain, and the complete
count. ⛔ **The banner and the sheet do NOT share a denominator:** the banner's numbers describe what
its Clear control will do; the sheet's describe a file that leaves the app.

⛔ **Hiding earns no confirmation, and undo replaces it — conditional on the reveal existing.**
⭐ **Without a way to see hidden records, hiding IS deletion**, and a reversible-action argument
applied to an irreversible one is how a false safety claim reaches medical copy.

### Selection — S1, S2, S3

**Three cardinalities: one required, one clearable, any including none.** ⛔ **The third axis is
whether "not asked" survives, not whether the field is boolean.** A yes/no is the clearable kind, not
a fourth.

⭐ **Shorten the question, lengthen the answer.** A bare *Yes* is unreadable away from its label, and
this app separates them routinely — in the CSV, on badges, and in control-only navigation. **Meaning
moves out of the chrome, which is measured and read once, into the content, which travels.**

**S3: the form adopts the idiom the wizard already uses.** ⚠️ **Five behaviours must survive and four
are invisible until their exact case recurs** — pinned selected chips, an offerable-plus-carried
option list, the value-versus-label split, the semantics contract, and the add affordance hiding
where an entry could not persist.

### The rest — V1–V5, H1–H4, A1–A2, U1

- **V1:** the action chip differs in FORM, not only colour. ⭐ **Form carries what colour alone
  cannot** — the same lesson C2 established.
- **V2:** one date control. ⛔ **Its two behaviours are in the constraints above and outrank the
  design.**
- **V3:** drawn icons in chrome, emoji only in content the user chose.
- **V4:** three casing registers — content sentence case, screen furniture uppercase applied at
  render, names keep their own. ⭐ **The rule governs the RENDERED string.** The tagline is a wordmark
  and is not touched.
- **V5:** on reveal, the parent question scrolls to the top of the viewport. ⛔ **Correctness is
  *parent top equals viewport top after reveal* — scale-independent, and it does not rot.** ⚠️ **Any
  fold measurement is diagnostic only and must not be carried between briefs.**
- **H1:** the removal control stays on the History row, and its condition is met because the action
  is now reversible.
- **A1:** no shared app-bar shell; enforcement goes to components and tests.
- **U1:** two edit paths stay, split by completeness — one specification, two renderings.

---

## ⛔ What is the developer's, and not the CLI's

**These are open and none is a coding question.**

1. **The live iOS data-loss mechanism.** ⚠️ A mechanism read from the 1.0.2 source replaces the whole
   event history with a stale mirror; the fix is already in the repo and unreleased. ⛔ **Read, not
   reproduced.** **Hotfix, ship sooner, or accept it dated — all defensible; leaving it undecided is
   not.**
2. **The dedup instrumentation.** Three branches skip a record whose id is already indexed, and
   nothing records that it happened. ⭐ **A count would make the next loss attributable.** ⛔ **If
   taken: a count and nothing else — no id, no timestamp, no content.** The privacy copy promises
   crash reports carry no event data.
3. **The version bump.** ⛔ **This release adds backup, which is a feature, not a refinement.**
4. **The store and website surfaces.** Three claims are correct today and wrong on release day: the
   field list, the date-and-time behaviour, and the absence of backup.
5. **The screenshot set.** ⛔ **Never captured from a device holding real records.**

6. 🔴 **THE SCOPE REVERSAL, RECORDED BECAUSE IT IS THE OPERATIVE DECISION AND IT LIVED NOWHERE.**
   `[report]` — **source: a chat window, not a document.** In order:

   > **"go"** — accepting a launch recommendation
   >
   > *two messages later:* **"I did say I wanted to get everything in if we can speed it up"**

   ⛔ **THE SECOND SUPERSEDES THE FIRST, and only the first was written down.** A reader finding
   the *"go"* alone would conclude a narrowed launch was agreed. **It was not.**

   ⚠️ **AND IT DOES NOT CONFLICT WITH THE iOS RELEASE QUESTION NOW OPEN**, which concerns a
   MINIMAL CUT carrying no design work — not a launch of the full build. ⭐ **Stated explicitly
   because the two look alike at a glance and a reader with only the `"go"` would read them as the
   same decision reversed twice.**


---

## Verification, tiered by what a defect costs

| tier | covers | apparatus |
|---|---|---|
| **Storage** | schema, migration, serialisation, backup, anything a record passes through | ⛔ **Full.** Every check demonstrated capable of failing, controls run, every null result with a control proving the apparatus was live. **The failure mode is a destroyed medical record and it is silent.** |
| **Behaviour** | what the user does and sees happen | Normal tests. ⚠️ **A control only where a test asserts a negative.** |
| **Appearance** | colour, type, spacing, casing, icons | ⭐ **The checker and one capture pass. Nothing per-change.** |

**And four rules about verification itself, each earned:**

- ⛔ **A fixture must be capable of failing too.** An equality guard is live only where the fixture's
  value differs from the default, and a fixture another seed can satisfy is not a control.
- ⛔ **A property test is not a control for the code that is supposed to have the property.** The
  value has to come back from the real path.
- **Order the load-bearing assertion ahead of its positive controls**, or a failure is attributable
  to the wrong claim.
- **A control substitution is a destructive experiment and needs a committed baseline first.**

---

## ⛔ When to stop

**Every brief carries an escape clause and firing one is the process working, not a failure.**
⭐ **Every escape clause that fired during this build caught something real.**

**Stop and report, rather than proceeding, when:**

- **a premise the work rests on turns out to be false** — do not repair it in flight;
- **a stated rule cannot be expressed as written** — the rule is wrong, and rewriting it is a
  decision;
- **the correct fix would change a decision in this document** — that is not an implementation
  detail;
- **a verification cannot see the thing it claims to test.** ⚠️ **An approximation that passes is
  worse than no test: it reads as evidence of absence.**

---

## What is deliberately OUT

- **H3, H4, R2.** ⛔ **The line is drawn outside §10 rather than by judgement.** ⚠️ **R2 is an
  accessibility fix and its reason is stated: no screen reader has been run on any platform, so it
  would ship unverified either way. It returns with that pass.**
- **§11**, mapping retired legacy values forward — lossy, and not worth the risk at the live
  population.
- ⛔ **§13(be)'s mechanism set.** **Nothing in this build touches it, and the recycle model protects
  against none of it.** ⚠️ **That is a known exclusion, recorded so it is not later discovered as an
  oversight.**

---

# AMENDMENT 1 to DECISIONS.md — 17 September 2026 AEST

**Append to `docs/design-audit/DECISIONS.md`.** ⛔ **Append — do not rewrite the file.** It is
already committed at `4292288` and this session's copy may have diverged.

**Two design questions raised by the closing brief and not resolved there. Both are decided here.**

---

## 1. ⛔ `MERType.strong` stays reserved, and four sites move off it

**Its own stated role is display and the capture action. Three disclaimer headings and one home site
now use it** — rule-1 compliant, rendered-identical, and ⚠️ **the name has stopped being true of four
of its uses.**

⭐ **That is `textPrimary` byte-identical to `primary` in a new medium**, and this whole build exists
because names that stopped being true shipped defects nobody could see. ⛔ **Widening the role to fit
the uses would make *reserved* mean nothing.**

**Decided: the four sites take the step their element class calls for. `strong` stays reserved.**

⚠️ **This WILL change how those headings render, and that is correct.** ⭐ **The conversion was
rendered-identical by design, so it faithfully preserved a wrongness — which is what a mechanical
pass is supposed to do.** **This is the first deliberate rendering change of the type work and it
should be named as one.**

⭐ **And there is a product argument, not only a naming one: if the disclaimer's headings sit at
display weight, they compete with the capture action for the loudest thing in the app.** **The
capture action should be the loudest thing; a heading should be a heading.** ⛔ **The disclaimer's
force comes from its words and its gate, never from its font weight.**

⚠️ **Gated on a 200% pass like any appearance change.**

---

## 2. ⛔ `Record Event` and `End Event` go to sentence case

**V4 already decided this and the reasoning stands.** Title Case clusters on the app's two
ceremonial moments — the capture action and the consent gate — ⭐ **and casing is the weakest way to
carry weight: invisible to a screen reader, and it does nothing at 200%.** **`Record Event` already
carries its emphasis at 26 px `w700`, white on the capture fill.**

⛔ **The consent-gate half already moved. Leaving the capture half out because the ripple is awkward
is how a rule becomes a preference.**

**Decided: both go to sentence case. The ripple into Help, notifications and tests IS the work.**

⚠️ **One carve-out, and it is V4's own, not a new exception: notification ACTION titles keep
platform convention.** ⭐ **Those are different strings, so nothing collides** — ⛔ **confirm that
before applying rather than inheriting it from this sentence.**

⚠️ **`DECISIONS.md` discusses these two controls by name. Update those references in the same
change**, or the document starts describing an app that no longer exists — **which is the failure it
was written to prevent.**

---

## Two method rules, both earned by the closing brief

### ⛔ A check that lives in a transcript is not installed

**`DECISIONS.md` named a colour checker and a type checker as a pair. Only the colour one existed.**
⚠️ **Rule 1 had been reported satisfied on the strength of its size half — genuinely clean — while
the weight half was violated twenty times and nothing looked.**

⭐ **A rule reported as satisfied and a rule enforced by something that runs are different states,
and only the second survives the next commit.** ⛔ **Where this document names a check, the check
must exist, carry a fixture proving it can fail, and assert its own denominator.**

⚠️ **And an allowlist is keyed on source text, never on a line number.** ⭐ **The colour checker's
one entry has already drifted — 185 to 178 — and its own comment says quoting the source would not
have.**

### ⛔ A literal scanner can report a fragment that inverts the claim

**The copy sweep reported `disclaimer:257` as *"Notiva can recover them."*** ⚠️ **The real sentence
is *"neither you nor Notiva can recover them"*, split across `TextSpan`s.**

⭐ **A scanner that segments on string boundaries cuts a sentence wherever the markup does, and a
negation left on the other side of the cut reverses the meaning.** ⛔ **This matters most for exactly
the work still open — the store and website copy — where a claim read as a fragment could be
corrected into a falsehood.**

**Every copy finding is adjudicated against the RENDERED sentence, never against the matched
string.**

---

# AMENDMENT 2 — the iOS release cut. Decided 17 September 2026.

⛔ **RECORDED HERE BECAUSE IT TRAVELS BY `git push`.** The reasoning chain behind it lives in the
Change Register and in commit messages; **the Register does not travel, and a release decision that
exists only in a chat window is the failure Amendment 1's method rules were written about.**

---

## 🔴 THE CUT IS `956b2d3`

**The rule was stated BEFORE the read, so the read could not be shaped to fit it:**

> **the cut is `824cd16` — the smallest change that works — UNLESS one of the thirteen fixes
> something that would otherwise ship broken.** ⛔ *"Nice to have" does not qualify. "Ships a defect
> without it" does.*

⛔ **ONE QUALIFIED.** `956b2d3`, *"iOS 16.2-16.x: make the End action prompt instead of failing
silently"*, whose own body records a **data** defect:

> *"the record kept its `lt1` default — **wrong data** on the only end path this tier has."*

⭐ **AND THE TIER IT NAMES IS THE MINIMUM SUPPORTED TIER.** `efae60d` is an ancestor of `824cd16`
(`merge-base --is-ancestor`, `[read]`), so **no viable cut avoids the iOS 16.2 floor** — 16.2 to
16.x becomes the lowest supported band on every candidate. **Shipping without `956b2d3` would ship
a build whose lowest supported iOS version writes wrong data on its only end path.** That is the
rule's condition, met exactly.

⚠️ **AND THE DEFECT IS PRE-EXISTING, NOT INTRODUCED BY THE CUT.** `[read]`:
`.authenticationRequired` is absent at `192ae40` **and** at `824cd16`, present at `11d2fda`. **The
cut does not create it; it fails to fix it.**

> ⚠️ **THE TRADE THE CUT MAKES, RECORDED 17 September 2026 — CONFIRMED BY READING, NOT INFERRED
> FROM ENDPOINTS.** `[read]`: `git log -S ".authenticationRequired" -- ios/` returns **two**
> commits. **`956b2d3` is the one that adds `options: [.authenticationRequired]`.** The other,
> `eb8196e` (27 Aug), adds only a COMMENT mentioning the symbol and is **after** the cut — it adds
> no option, **so the cut is unaffected by it.**
>
> ⛔ **SO THE CHOSEN CUT IS THE COMMIT THAT INTRODUCES THE AUTHENTICATION PROMPT ON 16.2–16.x, AND
> THEREFORE INTRODUCES THE DURATION INFLATION ON THAT TIER.**
>
> ⭐ **BEFORE IT**, ending from a locked device on that tier failed silently and left the `lt1`
> default — **a multi-minute event recorded as under one minute.**
> ⭐ **AFTER IT**, the duration inflates by the authentication delay, because both end paths stamp
> `Date()` **inside the handler**, which iOS runs only once authentication has succeeded
> (`AppDelegate.swift` `handleQuickLogEnd`, `EndMEREventIntent.perform()`).
>
> ⛔ **BOTH ARE WRONG. THE SECOND IS CLOSER TO TRUE AND FAILS LOUDLY.** ⚠️ **The trade was made
> without being seen, and is recorded here so it is not discovered later.**
>
> ⚠️ **AND THE INFLATION IS IN THE DURATION ITSELF, not merely in when the record appears.** The
> same `endTime` supplies both the instruction's `at` and its `seconds`, and `capture_inbox.dart`
> takes `instruction.seconds` straight through to `durationSeconds` without recomputing.
>
> ⚠️ **AND THE CUT INHERITS ONE FURTHER OPEN QUESTION, ADDED 18 September 2026 — `956b2d3` IS A
> DESCENDANT OF `4ba63e1`** (`git merge-base --is-ancestor` true, reverse false), **so the candidate
> carries both the iOS write-path retirement and the now-false rollback guard that justified itself
> by it.** ⛔ **That is an OPEN DATA-SAFETY QUESTION, not a defect in the cut, and it is §13(be)'s
> to settle — see §13(bt).**

> 🔴 **IT CANNOT CURRENTLY BE MARKED, AND THAT IS A SEPARATE FINDING — see the feasibility read of
> 17 September 2026.** `kBtnEnd` carries `.authenticationRequired` **unconditionally**, so it is
> set whether or not the handset was locked; **a flag derived from it would be true for every iOS
> notification end, including the instant ones, and would mark nothing.** ⛔ **Nothing available to
> either handler distinguishes a delayed end from a prompt one.** **The decision to mark the
> duration is therefore not buildable in that form**, and that goes back to the developer rather
> than into a spec.

### What did NOT qualify — recorded so the rule is seen to have DISCRIMINATED

| commit | why not |
|---|---|
| `468fb23` | ⛔ **explicitly disclaims a data effect** — *"Neither affected the record."* A behaviour improvement on the same tier, not a defect fix. **It travels only because it is an ancestor.** |
| `8e0b9ee` | same path, ancestor of `956b2d3`; **travels with it rather than qualifying on its own.** `956b2d3`'s body states the reorder *"is neither the fix nor a regression"* |
| `db2fd38` (Help collapsible sections) · `51fa65e` (History date range, day grouping) | ⛔ **user-facing and substantial, and neither fixes a shipping defect.** Taking them would be choosing SCOPE rather than removing a defect. **Excluded.** |
| the six tooling, docs and test commits | not user-facing; **excluded by being beyond `956b2d3`, not by judgement** |

⭐ **A rule that excluded nothing would not have been a rule.** Two user-facing features and a
same-tier behaviour fix were available and were left out.

---

## ⛔ THE CAVEAT THAT TRAVELS WITH THE DECISION — BOTH SENTENCES, ALWAYS TOGETHER

**1. NO CUT IS A HOTFIX.** `192ae40 → 824cd16` is **1,135 insertions across seven files — six
screens plus a widget** (`[read]`, `git diff --shortstat`). The live build is May; these commits
are late August. ⛔ **Four months of accumulated work ships regardless of which candidate is
chosen.**

**2. WHAT THE CUT AVOIDS IS THIS MONTH'S DESIGN WORK**, which is what the standing rule was written
about. ⛔ **It does not avoid shipping a substantially different app from what is live.**

⚠️ **A reader who finds only the second sentence will believe the cut is a hotfix. It is not.**
⭐ **Both sentences are the record; either alone misrepresents it.**

---

## The upgrade test — LOCATED, and it DOES NOT TRANSFER

**Found in two places:** `STATUS.md:1185` (*"Session: 24 August 2026 — Windows"*) and the Change
Register at line 979 (*"Android inbox — device test, 24 August 2026"*). It records a Teclast P30,
Release build, `adb install -r`, versionCode **3 → 5**, `firstInstallTime` unchanged with a new
`lastUpdateTime`, and *"Data retained across the upgrade."*

⭐ **IT WAS CORRECTLY REMEMBERED AND IT IS REAL EVIDENCE** — about Android, at an unestablished
commit. ⛔ **THREE LIMITS, all of which travel with it:**

1. ⛔ **IT DOES NOT NAME THE COMMIT THE TESTED BUILD WAS MADE FROM.** The only shas in either block
   are an `ios/` subtree hash, two section headings, a fix reference, and — in the Register — a
   **certificate** SHA-256, not a commit.
2. ⭐ **THE VERSION STRING CANNOT SUBSTITUTE FOR ONE.** `1.1.0+5` is carried by **four** commits
   that **straddle the SQLite boundary**: `bc4dc77`, `b7df6f1`, `747a7d7` pre-SQLite, and
   `9461f27` — **which IS SQLite phase one.** ⛔ **So "before or after SQLite" is NOT established,
   and deriving it from a 24 August build date against a 25 August authored commit is an
   INFERENCE, not a reading.** ⚠️ A build date can precede its commit, and a commit authored on the
   25th can have been written on the 24th.
3. 🔴 **IT IS AN ANDROID TEST.** `adb install -r`, `versionCode` and `firstInstallTime` are Android
   mechanics. ⛔ **No iOS in-place upgrade test appears anywhere in `STATUS.md`.** **The release in
   question is iOS.**

⛔ **DO NOT RECORD IT AS EVIDENCE THAT AN iOS UPGRADE PRESERVES DATA. That is the one claim it does
not support**, and it is the claim a reader most wants it to make.

⚠️ **The two harness tests are not a substitute either.** `sqlite_migration_test.dart` and
`sqlite_upgrade_v2_test.dart` cover **v1 → v2** — the latter describes itself as *"run against a
database built the way the device's actually was"* — **not live-build → candidate.**

---

## ⚠️ A correction to Brief 35, recorded where the cut decision is

**Brief 35's FILE carried THREE confirmations.** The upgrade test was a **FOURTH, added in a chat
window and never written into the document.** ⭐ **Recorded here so the brief is not later read as
having asked for it**, and because it is the same class Amendment 1's provenance rules exist for: a
requirement that reached the work without reaching the document.

⛔ **The separation matters beyond bookkeeping.** The three written confirmations returned answers;
the unwritten fourth returned *"the record does not say."* **A reader reconciling the brief against
the report would otherwise find one more answer than the brief has questions, and no way to tell
which was which.**

---

## §10's fourth part is FOUR pieces of work plus two already closed — recorded 18 September 2026

⛔ **THIS IS AN ANNOTATION. §10's text stands and is not rewritten**, and neither is D2's.

⭐ **The layout work is NOT one design pass.** Brief 46's escape clause fired on a measurement rather
than on an argument, and the grouping below is what the measurement found. ⚠️ **One of the four
items was misfiled and is refiled here BEFORE anything is scheduled**, because filing it under
layout would have put it under the wrong rules.

| # | the work | disposition |
|---|---|---|
| **1 + 2** | **cap coverage and the absent breakpoint** | ⭐ **ONE AXIS, ONE PASS.** ⚠️ **LOWEST PRIORITY: the 520 cap binds only above 560**, so on every phone in the capture set **it does nothing at all.** ⛔ **And it has no recorded provenance** — it arrived inside `af28902`, unrelated work, and was copied twice. **Changing it overturns no decision.** |
| **3** | the horizontal inset population `{0, 14, 16, 20, 24}` | 🔴 **REFILED — NOT LAYOUT WORK.** ⭐ **It is the COMPONENT VOCABULARY's missing axis.** The vocabulary covered colour, type, chips and cardinalities and **never covered SPACING.** ⛔ **A gap in a phase recorded as COMPLETE, and governed by the vocabulary's rules rather than the layout work's.** |
| **4** | the vertical budget | 🔴 **FIRST. The only one users meet on every capture.** |
| **5** | Windows offset and clipping | ⛔ **RETRACTED** — the finding's own text says the offset is a capture-instrument artefact, not an app defect. |
| **6** | the narrow-width floor | ✅ **DECIDED** — D2, prevent rather than support. |

⚠️ **WHY THE REFILING OF ITEM 3 MATTERS MORE THAN ITS PLACE IN A LIST.** ⛔ **The component
vocabulary is recorded as a COMPLETE phase, and a complete phase is one nobody re-opens to check.**
⭐ **The gap was invisible from inside the vocabulary — every axis it DID define was defined well**
— and it surfaced only because a layout measurement enumerated the insets and found five values
where a vocabulary would have had one rule. **A phase is complete against the axes it named, never
against the axes it did not.**

### 🔴 Within item 4, the sharpest measurement, recorded so it is not lost among the others

**On wizard step 4 at 375×667, `Review` and `Back` both sit at 613 against a fold of 591.**
🔴 **BOTH NAVIGATION BUTTONS ARE BELOW THE FOLD ON THE PRIMARY CAPTURE PATH.** ⚠️ **That is the
FORWARD AFFORDANCE, not density — a user mid-capture sees no way to proceed without scrolling.**
⭐ **It outranks the notes overhang that opened this thread.**

> ⛔ **RETRACTED 18 September 2026 — THE CLAIM ABOVE IS FALSE, AND THE FINDING IS WITHDRAWN. Its
> text and its 🔴 are left exactly as written**, per this corpus's annotate-never-rewrite rule: a
> record of what was concluded must stay true, and the reasoning is the transferable part.
>
> **The claim, quoted so it is recognisable wherever it is met:**
>
> > 🔴 *"BOTH NAVIGATION BUTTONS ARE BELOW THE FOLD ON THE PRIMARY CAPTURE PATH."*
>
> ⭐ **MEASURED AT `b9a241d`, at 375×667 under Roboto: `Back` and `Review` occupy 599…647 against a
> screen bottom of 667. FULLY ON SCREEN, AND ALWAYS WERE.** `event_wizard_screen`'s `_footer` is a
> **direct sibling of the `Expanded(SingleChildScrollView(...))`**, not a child of it — **a
> persistent footer already, and no navigation work was ever needed.**
>
> ⛔ **THE CAUSE IS A CLASS, NOT A TYPO, AND THAT IS WHY IT IS WORTH THE SPACE.** ⭐ **The NUMBER
> was right. The QUESTION attached to it was not.** `notes_reachability_test` defines its fold as
> `tester.getRect(scrollable).bottom` — **the SCROLL VIEWPORT's bottom**, which is exactly right for
> the question that test was built to ask: *does raising the notes field bury another field inside
> the scrolling content?* ⚠️ **The word was then carried into a different question — what the user
> can SEE — and a pinned footer sits between the two boundaries by design.**
>
> ⛔ **THE RULE: a metric is defined by the question its instrument was built to answer. Reusing it
> for a different question silently redefines it, and the number carries its old authority into its
> new falsehood.**
>
> ⚠️ **THIRD INSTANCE IN TWO DAYS, recorded together because separately they read as three typos:**
>
> | the term | its home context | where it became false |
> |---|---|---|
> | *without **opening*** | the architecture matrix's own row | read as *without **unlocking***, and reached the store copy draft |
> | *the audit's **fifteen work items*** | the audit | read as *the fifteen **conditions*** |
> | *a **scroll-viewport** fold* | `notes_reachability_test` | read as *a **screen** fold*, producing this retracted 🔴 |
>
> ⭐ **In each case a term correct in its home context became false the moment it travelled**, and
> in none of them was the underlying measurement wrong.
>
> ✅ **THE CONFIRMATION STEP CAUGHT IT BEFORE ANY CODE MOVED.** Brief 49 was a build brief; its
> instruction to confirm the row's location before changing it is the whole reason `lib/` was never
> touched. ⭐ **And `test/wizard_nav_reachability_test.dart` at `b9a241d` now asserts the footer's
> reachability at 100% and 200%, with a control that reproduces the 613-against-591 reading and
> requires it to fire — so the property is PINNED even though it was never broken.**

### ✅ And the figure that was outstanding when this split was written is now measured

**The form's scroll distance at 375×667, `test/form_scroll_distance_test.dart`, under Roboto:**

| scale | scroll distance | content | viewport |
|---|---|---|---|
| **100%** | **1195** | 1806 | 611 |
| **200%** | **1885** | 2496 | 611 |

⛔ **THE CLI'S OWN ESTIMATE WAS 850–900 AND IT WAS WRONG BY 33%, AND THE METHOD IS THE FINDING
RATHER THAN THE GAP.** The estimate anchored on the deepest element it had a measurement for — the
referral label, *"below fold by 783"* — and treated everything past it as small. ⚠️ **Everything
past it was 390 points**: the referral control, the notes label, a four-line notes field, and a
buttons block of 150 that had been READ AND THEN OMITTED. ⭐ **An estimate anchored on the deepest
MEASURED point can only under-report, because what lies beyond it is unmeasured precisely because
nothing looked there.** ⛔ **Same class as the instrument rule of 18 September: an instrument that
can only fail in one direction is not safe by default.**

⚠️ **AND THE TECHNIQUE DID NOT TRANSFER UNCHANGED.** `step4_density_test` measures from
`TextField.last`, which IS the last child on wizard step 4. **On the form it is not** — Save, Cancel
and three spacers follow it. ⛔ **Copied without re-deriving the last child, it under-reports by
134 points at both scales.** The new test prints that gap rather than hiding it.

### Also recorded, not actioned

**`log_event_screen`'s `LayoutBuilder` is dead** — `constraints.` is used **0 times** in its body.
It wraps the whole screen and provides nothing.

⛔ **`occurredAt`'s two placements are BOTH DELIBERATE, with their reasoning in the code** — the
form's *"AFTER DURATION, NOT AT THE TOP — moved there on evidence"*, the wizard's *"ON THE SUMMARY,
NOT ON STEP 1, AND THAT IS THE DESIGN"*. ⚠️ **Difference 3 is two decisions that disagree, not a
drift. Unifying it would overturn one. NOT to be reconciled.**

### ⛔ A second-order effect the status table has, found by the marker sweep of 18 September 2026

**§13's heading markers are HISTORICAL BY CONVENTION, and the status table reads them as CURRENT.**
`(al)` states it outright: *"Its text and its 🔴 are left exactly as written, because a record of
what was concluded that day must stay true."* ⭐ **So a retracted finding KEEPS its 🔴 on purpose,
and that is the annotate-never-rewrite rule working correctly, not a defect in the document.**

⛔ **THE DEFECT IS IN THE TABLE, WHICH DERIVES A LIVE STATUS FROM A FROZEN RECORD.** ⚠️ **No amount
of re-marking fixes it** — re-marking would destroy the historical record the convention exists to
protect. **The table needs a different INPUT: the dated annotations, not the heading glyph.**
**Nothing was re-marked.**

---

## The tablet migration test — two corrections and one unreadable number, 18 September 2026

⛔ **RECORDED DURING BRIEF 52, WHICH STOPPED AT ITS OWN VERSION-CODE GATE BEFORE INSTALLING
ANYTHING.** The tablet's records are untouched.

### ⚠️ CORRECTION — the backup path's durability, and where the incomplete claim actually lives

⛔ **THE BRIEF ASKED FOR AN IN-PLACE ANNOTATION OF A CLAIM IN THIS DESIGN RECORD. THE CLAIM IS
NOT HERE.** `[read]`, with a control: `backupShare` returns **0 hits** across `docs/` and the
project `CLAUDE.md`, while the same search returns **5 hits** in `lib/` — so the apparatus was
live and the null is real. ⭐ **Recorded as a new dated entry rather than dressed up as an
annotation of something that does not exist**, because an in-place annotation implies a prior
claim a later reader would go looking for.

**THE INCOMPLETE CLAIM IS IN THE PROJECT `CLAUDE.md`, under CSV export, and it is FLAGGED HERE
AND DELIBERATELY NOT EDITED:**

> *"No file path dependencies — uses system share sheet"*

⚠️ **It is a function-level fact stated as a feature-level one** — the travelling-term class
already recorded on 18 September for the scroll-viewport fold. **Measured on the device this
morning, both surfaces offer a DURABLE save, and neither depends on the share sheet completing:**

| surface | durable option | what happened |
|---|---|---|
| **Back up your history** | **`Save to a file`** | wrote straight to `Downloads`, with an on-screen confirmation naming the file: *"Backup saved to Downloads/mer_backup_20260918_020715.json"* |
| **Export a spreadsheet** | **`Save to device`** — subtitle *"Choose location and file name"* | wrote `medical_event_recorder_all_20260918_020750.v7.csv` to `Downloads` |

⭐ **Both files were pulled to the PC and verified there** — 74 records / 74 distinct ids in the
backup, 75 CSV data rows over 17 columns — **so durability is established by the filesystem, not
inferred from a toast.**

### ⛔ AND THE CODE ASSERTS A CONSISTENCY IT DOES NOT HAVE

`backup_service.dart` carries, beside its sheet:

> *"Same wording as the export sheet for the same action. Two labels for one thing read as two
> different features."*

⛔ **THE WORDING IS NOT THE SAME.** `[read]`: backup renders `'Save to a file'` with no subtitle;
export renders `'Save to device'` with the subtitle *'Choose location and file name'*.
⭐ **The comment states the rule correctly and then records compliance that was never achieved**
— which is worse than no comment, because it is the exact thing a reader would check the comment
to avoid checking. ⚠️ **REPORTED, NOT FIXED — this brief authorises no code change.**

### 🔴 THE NUMBER THAT CANNOT BE READ, AND WHAT THAT COSTS

⛔ **AS AT 18 SEPTEMBER 2026 THE ON-DEVICE SQLite `user_version` IS UNREADABLE.** The installed
build is not debuggable — `run-as: package not debuggable` — so the database file cannot be
reached, and **nothing in the app surfaces the schema version.**

⚠️ **"SCHEMA VERSION" NAMES TWO DIFFERENT NUMBERS AND ONLY THE WRONG ONE IS AVAILABLE:**

| | source | value | is it the migration's schema? |
|---|---|---|---|
| `kBackupSchemaVersion` | the backup envelope, `backup.dart:31` | **4** on the device | ⛔ **NO** — it versions the backup FILE FORMAT |
| `kSqliteSchemaVersion` | `event_store_sqlite.dart:66` | **11** in source at `b777fc3` | ✅ yes — and it cannot be read from the device |

⛔ **SO THE FIRST SQLite MIGRATION AGAINST A POPULATED DATABASE IS VERIFIABLE BY CONTENT ONLY.**
⭐ **Substituting the envelope number for it would be the travelling-term failure a third time in
one day** — a real number, correctly read, answering a question nobody asked.

⚠️ **A WANT AROSE FROM THIS AND IS RECORDED AS A WANT, NOT AS WORK:** surface `user_version` on a
user-visible screen, so a migration can be verified without a debuggable build. **It is not in
this brief and nothing has been built for it.**

### ⭐ The standing rule this test produced

⛔ **ANY FIGURE USED AS A PASS/FAIL GATE IS RE-READ AT THE TIME OF THE TEST AND NEVER CARRIED
FROM A PRIOR REPORT.** The gate said *"it must be 72"*, which was a true reading of **29 August**.
The device held **74** this morning. ⚠️ **Had the migration lost two records, the app would have
reported 72 and the stale gate would have scored it a PASS** — ⭐ **a stale criterion does not
merely fail to catch a fault, it converts the fault into a confirmation.** **Second instance of
the dated-observation-as-live-status class, after the §13 status table deriving current state
from a frozen heading marker.**

---

## Part C closed — three of four items needed no change at all, 18 September 2026

⛔ **FOUR ITEMS WERE RAISED. ONE REQUIRED WORK.** ⭐ **That one, C1, was the developer's own
complaint. The other three were the chat's, raised from screenshots, and all three closed
without a change.**

| item | origin | outcome |
|---|---|---|
| **C1** — the centred composition | ⭐ **the developer** | ✅ **BUILT.** Restored at `4bf2786`; reason 3 withdrawn and struck at `d1905cb` |
| **C2** — the hint inside the orange card | the chat | ⛔ **DROPPED.** No colour change, no type step, no spacing change |
| **C3** — the *This month* accent | the chat | ⛔ **DROPPED.** Left exactly as it is |
| **C4** — the orange card's height | the chat | ⛔ **NOTHING TO DO.** The premise was false |

### C2 — dropped, and what the attempt established is worth keeping

⭐ **The measurement is the durable part.** `[read]`: all **35** colour tokens in
`mer_theme.dart` were measured against `captureFill` `#E05B3A`. ⛔ **NOT ONE CLEARS 4.5:1.**
The palette's maximum on that fill is **3.67:1** — the four white tokens — and the fill sits at
mid-luminance, so nothing escapes it in *either* direction; the dark end is worse than the
light end, not better.

⚠️ **SO THE ORIGINAL STATE WAS NON-COMPLIANT, WHICH IS WHY "RESTORE IT" WAS NEVER AVAILABLE.**
White at 11px inside that card is **2.38:1** at 65% opacity and **3.67:1** solid, against
1.4.3's 4.5:1. ⭐ **Restoring it exactly would have reintroduced a defect.**

⛔ **AND A NEAR-MISS RECORDED AS ITS OWN FINDING: a proposed value was measured correctly and
attributed to a token that does not exist.** `#1A1A1A` was reported as *"onSurface"* at
4.75:1. The real `onSurface` is `#0D4F82` at **2.33:1** — a clear fail. The ratio was right; the
name was not. ⭐ **It was caught only because the decision required an EXISTING TOKEN rather
than a value.** Without that constraint an invented hex would have shipped, and it would have
measured correctly forever while belonging to nothing.

### C3 — dropped on the regulatory position, and the refusal is recorded so it is not re-litigated

**The accent's removal rests on D2, 13 September 2026:** *"a count rendered in alarm colour is
the app having an opinion about how many events you had, on a tool positioned as
capture-only."*

⚠️ **A hierarchy-by-weight-or-size alternative was proposed and DECLINED**, and the reason is
recorded rather than the outcome alone: **emphasis by weight is defensible but sits near a
regulatory boundary for a cosmetic gain, and getting it subtly wrong there costs more than a
flat stat row.** ⛔ **Do not re-open this from a screenshot.**

### C4 — the premise was false

`[read]`: the orange card's `vertical: 36` padding is from `0de48d1`, **21 March 2026**, and has
**never changed**. ⭐ **It did not lose height. Its neighbours moved, and the settings-nudge
banner is absent because the notification permission is granted.**

---

## ⛔ THE CLASS — A BROKEN COMPOSITION DEGRADES EVERY ELEMENT INSIDE IT, AND THE READER BLAMES THE ELEMENTS

**Recorded 18 September 2026, from three premises that failed the same way in one sitting.**

⭐ **All three were raised from screenshots of the TOP-ALIGNED home screen** — the one state the
developer had already called unacceptable. **All three were false. Every one of them was false
IN THE APP'S FAVOUR:**

| the premise | what was actually true |
|---|---|
| the hint had been moved out and should go back | it was moved out for **1.4.3**, and putting it back as it was would reintroduce a contrast failure |
| the *This month* accent had been dropped, presumably for contrast | it was dropped for the **regulatory position**, deliberately, with reasoning |
| the orange card had lost height | its padding has been unchanged since **21 March** |

⛔ **THE MECHANISM: when a composition is wrong, everything inside it looks wrong too, and the
eye attributes the wrongness to whatever it happens to be looking at.** ⚠️ **The elements were
never the problem. The arrangement was — and fixing the arrangement dissolved all three.**

⭐ **SAME ERROR AS RELATIVE-READ-AS-ABSOLUTE, AT SCREEN SCALE.** That class says: two captures
differ, and the difference is attributed to the element rather than to its surroundings. **This
is the whole-screen form of it** — one arrangement is wrong, and the badness is distributed
across every component in view.

**PRACTICAL FORM: when a composition is under complaint, FIX THE COMPOSITION FIRST AND RE-LOOK
BEFORE RAISING ANYTHING INSIDE IT.** ⛔ **A defect list generated from a broken layout is
mostly a list of symptoms of that layout**, and each item will arrive with its own plausible
explanation attached. ⭐ **The tell is the direction: three independent premises, all wrong, all
favouring the app, is not three coincidences — it is one cause.**

---

## Two classes from the part D correction — 19 September 2026

⭐ **Both came out of one exchange in which a real defect was found, a false one was invented
beside it, and the false one was ranked HIGHER.** ⛔ **The record keeps the false claim rather
than deleting it, because the reasoning is the transferable part.**

**Struck, and quoted so the record stays true:**

> 🔴 *"Banner: a MISSTATEMENT. It says 'Showing 12 of 71' when 74 exist. That is a false claim
> rendered on screen, not a missing one."*
> *"If the two are ever separated — by cost, by risk, by anything — the banner goes first."*

⛔ **FALSE. The banner is correct.** Its denominator is `_scopePopulation.length`, and the code
says why in a comment written BEFORE the misreading: *"the banner is a CLEARABILITY claim, so
its denominator must describe what the clear control returns the user to — never the complete
set, which clearing cannot reach."* **Clearing the filters returns the user to 71. 74 is
unreachable from there.**

⚠️ **PROVENANCE, RECORDED RATHER THAN SMOOTHED OVER.** The CLI's part D report said the banner
*"under-reports"* — a clearability number judged against a completeness question. The chat then
built a severity ranking on that report **without checking whether the two surfaces answer the
same question.** ⭐ **Two errors, one shape, and the second was downstream of the first.**

### ⛔ CLASS 1 — A PRINCIPLE APPLIED WITHOUT VERIFYING ITS PRECONDITION

**"Four surfaces independently computing the same pair is duplication" is SOUND.** It required
exactly one prior fact: **that they compute the same pair.** ⛔ **They do not — two
denominators, by design, for two different questions.**

⭐ **A principle is an instrument, and an instrument used outside its conditions returns a
confident wrong answer rather than an error.** ⚠️ **The tell is that the principle was correct,
the reasoning from it was valid, and the conclusion was still false** — so nothing in the
argument itself could have caught it. **Only the precondition could.**

**PRACTICAL FORM: before applying a consolidation argument, establish that the things being
consolidated answer the SAME QUESTION.** ⛔ **Same computation is not the same question.** Same
family as reusing a metric across a question boundary — the third instance of that family in
two days, after *without opening* / *without unlocking* and the scroll-viewport fold.

### ⛔ CLASS 2 — TWO KINDS OF COMMENT, AND ONLY ONE EARNS ITS PLACE

| | what it does | what happened |
|---|---|---|
| the **banner** comment | **EXPLAINS A DISTINCTION** and pre-empts a specific misreading | ⭐ **It did its job.** The misreading happened only because nobody read it |
| the **`backupShare`** comment | **ASSERTS A COMPLIANCE** that was never achieved | ⛔ **It stopped readers checking** — it is the thing a reader consults INSTEAD of the thing itself |

⭐ **THE DIFFERENCE IS NOT LENGTH OR CARE. It is whether the comment states something a reader
can VERIFY AGAINST THE CODE IN FRONT OF THEM, or something they must take on trust.** The
banner comment names a distinction and the reason for it; the `backupShare` comment names a
state of the world elsewhere in the file.

⛔ **GUIDANCE FOR THE BRIEF 57 SWEEP, and this is the operative part:** wherever a contract
comes back **"convention, not enforced"**, its prose must look like the BANNER comment — naming
the distinction and the misreading it guards against — and **never** like the `backupShare`
one. ⚠️ **An unenforced contract that asserts compliance is strictly worse than no contract:
it is a claim with nothing behind it, sitting where a reader looks for assurance.**

### ⭐ And the reason this was caught at all, recorded because it generalises

**`ExportScope` got it right, and one of three surfaces being correct is what exposed the other
two.** ⛔ **Care arrives where the consequence is VISIBLE.** Export is a data-out path where
completeness is obviously load-bearing, so someone thought about it. **The header and the banner
looked cosmetic, and were not thought about** — and of those two, one turned out to be fine by
accident of a different rule and the other was the real defect.

⚠️ **Same shape as the withheld-count disclosure built only into the EMPTY state** — the one
case where the user can already tell something is missing. ⭐ **The dangerous cases are
consistently the ones that look harmless, which makes "does this look important" a bad filter
for where to apply rigour.**

### The remaining defect, and what closed it

⛔ **ONE defect: the header, an OMISSION.** It read `'71 events'` with three withheld and named
neither the 74 nor the 3. ⭐ **An omission and a misstatement are different classes and a review
that lumps them together will mis-prioritise** — which is exactly what happened here, in the
direction of ranking the non-defect first.

**Closed by `listCountLabel`,** a third top-level function of the same pair, in the same form as
`exportSheetTitle`. **The rule widened from two consumers to three, with the banner's exclusion
ENUMERATED in the doc comment** — because an enumerated exclusion is what stops the next reader
repeating the misreading.

---

## The backup reminder: no notification exists, and the banner is gated nine ways

**Finding established 18 September 2026; recorded 19 September 2026.**

### ⛔ THE ABSENCE, WITH ITS CONTROL

🔴 **THERE IS NO BACKUP REMINDER NOTIFICATION, AND THERE NEVER HAS BEEN.**

⚠️ **An absence claim is the one result whose output is identical whether the search was
exhaustive or never ran, so the control is recorded with it:**

| probe | result |
|---|---|
| `NotificationInterval`, `NotificationCalendar`, `schedule:`, `repeats` across `lib/` | **0 scheduled notifications** — the two `repeat` hits are unrelated prose in comments |
| **CONTROL** — `NotificationContent` in `notification_service.dart` | **3** |

⭐ **The control establishes the apparatus finds notifications when they exist.** The zero is a
fact about the app, not about the search.

**What exists instead is an in-app BANNER:** `_BackupReminderBanner`, gated by
`_showBackupReminder`, with `kBackupReminderThreshold = 10`. ⛔ **Nothing schedules it. It is a
render-time condition, not a reminder in the notification sense.**

### ⛔ AND A SCHEDULED NOTIFICATION COULD NEVER BE THE UNIVERSAL ANSWER

| platform | notification path |
|---|---|
| Android | `awesome_notifications`, used **only** for the live quick-log notification |
| iOS | native Swift, quick-log and Live Activity **only** |
| **Windows** | ⛔ **NONE. `init()` returns before any channel is created.** |

🔴 **So even if a scheduled reminder were built, Windows could not receive it. THE BANNER HAS TO
WORK.** ⭐ **Recorded because it forecloses the obvious remedy before anyone proposes it.**

### 🔴 WHY THE BANNER IS SUPPRESSED — AND IT IS NOT AN OVERSIGHT

**The chain's exclusivity has a stated origin.** `55e3354`, 6 May 2026:

> *"Settings nudge card **replaces banner slot** with **priority order**: 1. Notifications off
> 2. Show Previews not set 3. Active event in progress"*

⭐ **So it is a deliberate priority order over ONE REPURPOSED SLOT.** ⛔ **NOT vertical space and
NOT banner stacking** — which matters, because it means this is **not** the same decision as
`6fd3f1c` (the home composition) wearing two hats. **They are unrelated.**

⚠️ **AND THE HARM IS ALREADY DOCUMENTED IN THE CODE, BY THE PEOPLE WHO ESCAPED IT.** Two banners
sit ABOVE the chain rather than in it, and the comment says why:

> ⛔ *"The chain is exclusive, so putting this in it would hide whichever banner it displaced —
> including the active-event banner, whose End button is the only way to end an event on
> Android. Data at risk and an event in progress are both worth showing, so this stacks.
> **The advisory backup reminder yields to it instead.**"*

🔴 **SO THE BACKUP REMINDER WAS REASONED ABOUT AND DELIBERATELY LEFT IN.** The escape hatch was
used twice — storage-fallback and unsaved-write both stack — **and not a third time, because the
reminder was classified as ADVISORY.**

⭐ **THE ERROR IS THE CLASSIFICATION, NOT THE CHAIN.** ⛔ **In an app with no backend, no account
and no sync, where an uninstall destroys everything, a backup prompt is not advisory — it is the
only preservation path there is.** ⚠️ **Every other banner it yields to describes a condition
the user can still act on afterwards. This one describes the window in which acting is still
possible at all.**

### ⚠️ AND THE BANNER IS GATED NINE WAYS

**Six in its own predicate:** `_loaded` · `!_writeFailed` · `!_openedFromNotification` ·
`!_loggedThisSession` · `!_backupBannerDismissed` · `_eventsSinceBackup >= 10`.
**Three more by chain position:** the notifications nudge, the iOS previews nudge, the
active-event banner.

🔴 **`!_loggedThisSession` IS THE ONE TO LOOK AT TWICE.** ⛔ **Logging an event suppresses the
reminder — so the more the app is used, the less likely its only preservation prompt appears.**
⭐ **Defensible per-session as "do not interrupt capture", and perverse in aggregate: the user
generating the most unsaved data is the one least likely to be told.**

⚠️ **Reported, not fixed. The remedy is a decision and it is not this brief's.**

### ⭐ THE COUNTER ITSELF IS SOUND, AND ONE GAP SITS BESIDE IT

`eventsSinceLastBackup` is **derived on every refresh** from the record list against
`kLastBackupKey` — there is no stored counter, so there is no increment to miss and no drift to
accumulate. **That class of defect cannot occur here.**

⛔ **But it counts `r.timestamp.isAfter(last)` — NEW EVENTS ONLY.** ⚠️ **Add substantial detail
to twenty existing records after a backup and the count stays at zero. Edits are invisible to
the reminder.**

⛔ **NOT VERIFIED ON THE DEVICE, AND DELIBERATELY.** Firing the threshold requires creating ten
events, which changes the developer's records. ⭐ **What the device does support: the last backup
was 04:33 on 18 September, no events since, so the count is 0 and no banner should show — and
none did.** **Consistent, but not a threshold test.**
