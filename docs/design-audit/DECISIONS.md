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
