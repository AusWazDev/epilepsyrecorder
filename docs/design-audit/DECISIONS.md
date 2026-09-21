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

   > ⛔ **THE SECOND SENTENCE WAS FALSE WHEN WRITTEN AND STAYED FALSE. Annotated in place
   > 20 September 2026; the wording above is unchanged.** *"A literal outside the token set fails a
   > check rather than being noticed"* asserted an enforcement that **did not exist**.
   > `colour_system_test` verifies the TOKENS' contrast ratios and has never scanned for literals
   > outside the set.
   >
   > ⚠️ **Rule 2 beside it — the type scale — HAS had exactly that scan the whole time**
   > (`type_system_test`, "no literal fontSize outside MERType", with its own can-fail control).
   > ⭐ **So this was not a hard problem left undone. It was a claim nobody checked, sitting one
   > line above a working example of the thing it claimed.**
   >
   > 🔴 **THIRD INSTANCE OF THE `backupShare` CLASS — a comment asserting a compliance that was
   > never achieved — and the first one found IN THE DECISION RECORD ITSELF.** That is the worst
   > place for it: a reader consults the register precisely to avoid re-checking the code.

   > ⛔ **THE ANNOTATION ABOVE IS ITSELF WRONG. Corrected in place 20 September 2026; its wording
   > stays as written because a record of what was concluded must stay true.**
   >
   > ⭐ **RULE 1 WAS ENFORCED ALL ALONG.** `colour_system_test` test 12 — *"rule 2 is enforced
   > over lib/, not described"* — has scanned every non-comment line of `lib/` for hex and named
   > colour literals the whole time. **It is STRONGER than the scan built to replace it:** it
   > separates CHROMATIC literals, which fail outright, from NEUTRAL ones, which are allowlisted
   > **with their measured contrast**, and it enforces shrink-only in BOTH directions — a new
   > literal fails, and a stale allowlist entry fails too.
   >
   > ⚠️ **AND `lib/main.dart:178` WAS NOT AN UNNOTICED VIOLATION.** It was in that allowlist, with
   > its reason and its measurement: *"splash spinner, white 50% on primary — 3.3779, passes as
   > non-text"*. ⛔ **The claim that it "sat in plain sight because nobody looked" was false in
   > every clause: someone looked, measured it, wrote down the figure, and permitted it.**
   >
   > 🔴 **WHY IT WAS MISSED, because the mechanism is the transferable part: the search was
   > KEYWORD-KEYED.** It looked for test names containing *"no literal"* and for the string
   > `Color(0x` inside test files. **Test 12 is named for the RULE it enforces, not for what it
   > scans, and it builds its pattern from a variable** — so neither probe could see it. ⭐ **The
   > workspace rules already name this: a grep keyed on a word misses the class.** ⚠️ **The
   > correct instrument was the one used minutes earlier on `.visible` — enumerate what is
   > THERE and account for all of it, rather than searching for what you expect.**
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

> ⛔ **A FOURTH BUCKET — ROUTING. Annotated in place 20 September 2026; the wording above is
> unchanged and stays as written.**
>
> **The scheme above names THREE kinds of read site:**
>
> > *"Every read site is classified deliberately into **render, integrity, or reconciling**."*
>
> ⚠️ **A fourth was already in use when that was written, and the scheme had no name for it.**
> Three sites in `home_screen` resolved WHICH RECORD TO OPEN from the filtered list — the
> notification-tap path, the resume path, and the Last Event card's `onEdit`. ⛔ **Choosing a
> record to open is not render, not integrity, and not reconciling. Those sites were never
> CLASSIFIABLE, let alone classified.**
>
> 🔴 **AND THE CONSEQUENCE REACHED THE RECORD, NOT THE DISPLAY.** With the newest record hidden,
> a notification about THAT event opened the PREVIOUS one, and details were added to the wrong
> event with no signal. ⭐ **A misrouted write, not a wrong number on a screen.**
>
> ⭐ **ROUTING IS NOW A NAMED BUCKET, AND IT CARRIES ITS OWN RULE:** a routing site resolves a
> record **by identity**, never by position in a list, and never from a filtered population.
> ⚠️ **Position-as-identity is wrong whenever list order changes for ANY reason** — a record
> created between a notification firing and its tap already breaks it, hidden or not.
>
> **Closed at `b5496de` (render sites) and `7c5fae7` (routing by id).** ⛔ **One routing site
> remains position-based and is recorded as an OPEN defect at its own site rather than as
> solved:** `_openLatestEvent`, which the iOS native channel reaches through
> `getPendingOpenLatest` — a BOOL carrying no id. **Closing it needs the id on the Swift side.**
>
> ⚠️ **THE GENERAL POINT, AND IT IS WHY THIS IS ANNOTATED RATHER THAN QUIETLY EXTENDED: a
> classification scheme with no bucket for something that is already happening does not produce
> an unclassified site — it produces a site nobody can see is unclassified.** ⭐ **The manifest
> test added with this annotation is what makes a new unclassified site impossible to add
> silently.**

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

---

## The backup reminder stacks, and its gates go — 19 September 2026

⭐ **The reminder leaves the exclusive chain and its suppressors are removed. The chain itself is
untouched.** ⛔ **Recorded together with a withdrawn remedy, because the withdrawal is the more
transferable half.**

### ⭐ WHAT THE PREDICATE BECAME

`_loaded && !_backupBannerDismissed && _eventsSinceBackup >= 10`

**From six gates to three**, and the three that remain are readiness, an explicit user
preference, and the risk threshold itself.

### ⛔ THE CLASS — A GATE THAT SUPPRESSES A WARNING ON EXACTLY THE POPULATION THE WARNING IS FOR

| gate | who it silenced |
|---|---|
| `!_writeFailed` — **persisted**, from `hasFailedWrite()` at load | 🔴 **devices with PROVEN storage failure**, across restarts, until a write succeeded — the devices most likely to lose data |
| `!_loggedThisSession` | 🔴 **users generating the most unsaved data** |
| `!_openedFromNotification` | users arriving from a completed capture |

⛔ **Each was individually reasoned. Each inverted the prompt against its own purpose.**
⚠️ **Related to "a safeguard implemented only on the path where it was least needed" — and
worse: that one was ABSENT where needed; this one was ACTIVELY SUPPRESSED where needed.**

### 🔴 THE WITHDRAWN REMEDY, AND WHY IT IS THE PART WORTH KEEPING

**Struck, quoted so the record stays true:**

> *"INVERTED — `!_loggedThisSession` and `!_openedFromNotification`. Do not simply delete them.
> Change the trigger: the reminder appears WHEN A CAPTURE COMPLETES… Today capture SUPPRESSES
> the prompt. It should CAUSE it."*

⛔ **The inversion did not close the blind spot. It MOVED it.** Making the flags permit rather
than suppress excludes a different session: **user opens the app, captures nothing, already has
ten or more events at risk.** ⭐ **That is the BETTER session to prompt in** — not mid-task,
attention to spare, risk accumulated from earlier sessions.

⭐ **BOTH ORIGINAL GOALS SURVIVED WITHOUT ANY GATE:** *do not interrupt capture* — nothing
renders during the flow; *capture should cause it* — `_refreshBackupCount()` already runs after
`_persist()`, so a completed capture triggers a RE-CHECK rather than granting permission.

### ⛔ A REMEDY SHAPED BY THE DEFECT'S OWN STRUCTURE

**The finding was "this gate suppresses the wrong population". The proposed remedy was "make
the gate permit instead of suppress" — still a gate.** ⭐ **The correct remedy was that the
category should not exist at all.**

⚠️ **Same family as a principle applied without verifying its precondition: both are failures to
examine the FRAME being reasoned inside.** ⛔ **Here the frame was inherited from the code and
its sign was flipped, which FEELS like a redesign and is not one.**

⭐ **AND IT WAS A TEST THAT CAUGHT IT, NOT THE NAMED CLASS.**
`backup_banner_copy_measure_test` seeds twelve records, no `kLastBackupKey`, and no capture —
**it encodes precisely the user the inversion would have dropped**, and it went red.
🔴 **Second instance in one day of a test catching what a documented class did not. Knowing a
class does not prevent committing it. Only a check does.**

### ⚠️ AND THE JUDGEMENT SITS UNDER A PERMANENT MEASUREMENT GAP

⛔ **No telemetry can ever say whether this prompt works.** `sendDefaultPii = false`, no
analytics package, and all five `Sentry.captureMessage` sites concern storage and capture-inbox
conditions. ⭐ **A banner render is UNOBSERVABLE BY CONSTRUCTION — a property of the privacy
design, not a gap in instrumentation.**

⭐ **Hence the standing bias, stated so it governs later changes too: WHEN IN DOUBT, IT FIRES.**
⛔ **An unobservable safety prompt that errs toward silence cannot be caught erring — nothing
will ever report its absence.**

### ⚠️ ACCEPTED CASES, recorded rather than left to be rediscovered

* **A dismissal followed by ten further captures within one long session stays suppressed.**
  Acceptable: dismissal is per-session and a later cold start shows it again. ⛔ **Do NOT add a
  second threshold rule to cover it.**
* **The counter counts NEW EVENTS ONLY** — `r.timestamp.isAfter(last)`. Adding detail to twenty
  existing records after a backup leaves the count at zero. **Recorded; not fixed here.**
* **A scheduled notification cannot be the remedy.** ⛔ **Windows has no notification path at
  all — `init()` returns before any channel is created.** Recorded so the obvious answer is
  foreclosed before it is proposed.

---

## Two classes from the hidden-semantics divergence — 20 September 2026

⭐ **Checked before writing: neither is already recorded.** The part D correction of 19 September
holds two DIFFERENT classes — *a principle applied without verifying its precondition* and *two
kinds of comment* — and these two are new. ⛔ **Cross-referenced rather than restated, because
one provenance claim in this repo already needed correcting in four files after being
duplicated as prose.**

### 🔴 CLASS — A RULE CAN BE WRITTEN, DATED, COMMITTED, AND DIVERGED FROM THE SAME DAY

**`4292288` and `a69f0a7` are both 17 September 2026.** One recorded *"the complete list stays
complete everywhere; ONE derived view excludes hidden rows"*; the other shipped a hide control
whose consequences were read through a filtered list in fourteen places. ⛔ **Hours apart, in
the same repository, by the same effort.**

⭐ **THE POINT IS NOT THAT SOMEONE WAS CARELESS. It is that writing a rule down does nothing
mechanical.** A document cannot fail. ⚠️ **The divergence was not a decision to ignore the rule
— it was the absence of anything that could notice.**

⛔ **THIS IS THE WHOLE ARGUMENT FOR THE CONTRACT SWEEP, stated from the one case that proves
it:** the rule existed, was current, was correct, was committed, and was violated the same day.
⭐ **Every invariant therefore ends with a TEST or an honest label — never with prose that reads
like enforcement.**

⚠️ **Distinct from, and worse than, a STALE rule.** A stale rule was true once and can be dated.
**This was never true after the commit that stated it.**

### 🔴 CLASS — AN IDIOM BORROWED BETWEEN FEATURES CARRIES NO DECISION WITH IT

**`a69f0a7`, quoted:**

> *"vocabulary's hide already warns about nothing because nothing is destroyed. **Same idiom,
> same app.**"*

⛔ **The idiom transferred. The decision did not.** ⭐ **D6 governs VOCABULARY ENTRIES —
*"Vocabularies are append-only. Entries are hidden, never deleted… Entries MER itself retired
are not the user's to un-hide."*** ⚠️ **It says nothing about event records, and it could not:
they are different objects.**

| | vocabulary entry | event record |
|---|---|---|
| what it is | **a thing the user MAINTAINS** — a list they curate | **a thing that HAPPENED** — a fact about their health |
| what hiding means | retire an option from a picker | withhold a clinical record from a view |
| what a wrong hide costs | one picker entry to un-hide | ⛔ **a record missing from a count a clinician may read** |

⭐ **SAME GESTURE, DIFFERENT OBJECT.** The eye icon, the reversibility argument and the
"nothing is destroyed" copy all crossed over intact; **the reasoning about what the object IS
did not cross with them, because it was never restated.**

⚠️ **SAME FAMILY AS THE TRAVELLING-TERM CLASS, and the third axis on which it has now been
seen:** a term travelling between DOCUMENTS (*without opening* / *without unlocking*), a metric
travelling between QUESTIONS (the scroll-viewport fold; the banner's clearability denominator),
and now **an idiom travelling between FEATURES.**

⛔ **PRACTICAL FORM: when a feature is justified by pointing at another feature, the decision
covering that other feature must be re-read and its SUBJECT checked.** ⭐ **"Same idiom, same
app" is precisely the sentence to stop at** — it asserts a transfer without naming what is being
transferred, and an app is not a unit over which decisions automatically hold.

---

## The sweep closes — and the colour scan found a live violation on its first run

**Recorded 20 September 2026.**

### 🔴 `DECISIONS.md` RULE 1 IS NOW TRUE — third step of three

⭐ **The annotation on rule 1 above records that its second sentence was false. It is now
accurate**, and the sequence is recorded because the ORDER was the point: annotate the false
claim first, build the scan, then annotate again. ⛔ **Between step one and step two the record
was asserting an enforcement that did not exist, and saying so while it was still untrue is what
stops a reader trusting it in the interval.**

**`colour_literal_scan_test`, built 20 September 2026,** scans every non-comment line of `lib/`
for `Color(0x…)` and `Colors.*`, excluding the theme and `Colors.transparent`. **Both exclusions
are enumerated in the file, and one has its own control proving it is load-bearing.**
**Demonstrated failing** by injecting a literal into `about_screen`.

### ⛔ AND IT CAUGHT A REAL VIOLATION IMMEDIATELY — `lib/main.dart:178`

    color: Colors.white.withOpacity(0.5),

**The splash spinner.** ⭐ **The app's FIRST SCREEN.**

⚠️ **This is the proof the rule needed, and the shape of it matters: rule 1 claimed "a literal
outside the token set fails a check rather than being noticed" — and for as long as that claim
stood unchecked, this sat in plain sight.** ⛔ **The claim did not merely fail to catch it. The
claim is why nobody looked.**

> ⛔ **THE PARAGRAPH ABOVE IS FALSE AND IS ANNOTATED, NOT DELETED. 20 September 2026.** Its
> wording stays because a record of what was concluded must stay true.
>
> ⭐ **THE CLAIM "THE CLAIM IS WHY NOBODY LOOKED" MUST NOT BE CARRIED AS A GENERAL NOTE.** It was
> false here in every clause: `colour_system_test` test 12 had scanned `lib/` for colour literals
> the whole time, `lib/main.dart:178` was in its allowlist **with its measured contrast**, and the
> figure recorded there — *3.3779* — is the same one computed independently a month later.
> ⛔ **Someone looked, measured it, wrote it down, and permitted it.**
>
> ⚠️ **THE UNDERLYING POINT IS REAL, AND IT BELONGS TO `backupShare`, WHICH IS AN ACTUAL
> INSTANCE:** a comment asserting a compliance that was never achieved is the thing a reader
> consults INSTEAD of checking the code. ⭐ **That case earned the principle. This one did not,
> and was made to carry it.**
>
> 🔴 **RECORDED AS ITS OWN ERROR: A FINDING WRONGLY ELEVATED INTO A PRINCIPLE.** One vivid case
> was generalised before it was verified, and the generalisation then read as established because
> it sat in the register beside a real instance. ⛔ **A principle drawn from a single unverified
> case is weaker than the case, not stronger.**

🔴 **REPORTED, NOT FIXED**, per the brief. It is enumerated in
`_kKnownViolations` with the set marked **SHRINK-ONLY**: adding a path there is a rule being
weakened and needs a decision. ⭐ **Removing this entry is a one-line change once a token is
chosen for the splash spinner — which is a colour decision, and not the CLI's to make.**

### ⚠️ TWO SELF-INFLICTED ERRORS IN THIS PASS, BOTH CAUGHT BY CONTROLS

**Recorded because both are classes already on the list, committed while building the checks
against them.**

1. ⛔ **A shell string executed three backticked names as commands and wrote the annotation with
   them EMPTY.** `colour_system_test`, `type_system_test` and `backupShare` all vanished from a
   record about false claims. ⭐ **The project rule — multi-paragraph content goes to a file via
   `Write`, never through a shell string — exists precisely for this, and was not followed.**
   Repaired, and verified by scanning the block for residual scars rather than by re-reading it.

2. ⛔ **A CSV column was pinned FROM MEMORY and was wrong.** `updated_at` was written into the
   contract; the real column is `medication_kind`. ⭐ **The test's own CONTROL — "the recorded
   columns really are the header" — caught it on the first run.** ⚠️ **Exactly the
   figure-in-working-memory class: a name that felt certain, was never derived, and was wrong.**

⭐ **BOTH WERE CAUGHT BY APPARATUS, NOT BY CARE.** That is the whole thesis of the sweep,
demonstrated on its own author twice in one pass.

### ⛔ A MIGRATION CONTROL THAT FAILED FOR THE WRONG REASON

**Recorded because a control failing wrongly is indistinguishable, in its output, from a control
working.** The first attempt to demonstrate `migration_contract_test`'s chaining check injected
`} else if` naively and **broke Dart syntax** — the run failed at LOAD time. ⭐ **A compile error
is not the check firing, and reading "Some tests failed" as success would have been a false
discharge.** Redone by chaining two steps validly: `analyze` reports **0 errors** and the test
still fails.

⚠️ **Same family as the sentence-integrity control that reported APPARATUS DEAD twice for its own
reasons.** ⛔ **A control needs its own control — and the cheap form of that is to check the
failure is the one you meant.**

### ⭐ A GUARD THAT FIRED AND WAS ADJUDICATED RATHER THAN BUMPED

`show_hidden_scope_test` asserts `exportScope` appears exactly N times in the source. **The list
header's new read made it N+1 and the guard went red — which is exactly its job**, since a new
read site appearing silently is the mechanism behind the fourteen unclassified `.visible`
readers. ⛔ **It was raised only after the third occurrence was adjudicated a legitimate
consumer, and the site says any FOURTH must be adjudicated the same way rather than absorbed by
bumping again.**

### The classes referenced, not restated

⛔ **Checked against what is already recorded before writing.** Every class listed in Brief 60
part E is already in this register with its own dated entry — the travelling-term family across
three axes, the principle applied without verifying its precondition, the remedy shaped by the
defect's own structure, the relative change read as absolute, the broken composition degrading
every element inside it, the safeguard built only where it was least needed, the gate that
suppresses a warning on exactly its own population, gates individually defensible and
collectively perverse, the correct rule with a wrong classification, the two kinds of comment,
and a rule written and diverged from the same day.

⭐ **Nothing above restates them.** ⚠️ **One provenance claim in this repo already needed
correcting in four files because it was duplicated prose, and an index of classes would acquire
the same defect.** **The new material in this entry is the four incidents above, each of which
is an INSTANCE of a class already named rather than a new class.**

### ⭐ WHERE THE SWEEP LANDED

**Ten of fourteen structures are enforced; four are conventions with their coverage stated.**
`docs/design-audit/CONTRACTS.md` is the index, and it points at tests rather than describing
them — so it cannot drift without something going red.

⛔ **The four conventions are conventions because no available instrument can check them, not
because nobody got round to them** — except `#10` Help rows, where the mechanism was costed at
~30 lines and **declined on the 28 judgements it would require**, with the recommendation that
it attach to the Help accessibility audit already queued.


---

## An absence search keyed to spelling, not to purpose — 20 September 2026

⛔ **`#7` colour was reported as unenforced. It had been enforced all along.** The search that
produced that finding could not have found the thing it was looking for.

### ⭐ WHAT THE SEARCH DID

It looked for **test names containing "no literal"** and for **the string `Color(0x` inside test
files.** ⚠️ **Both probes encode an assumption about how the check would be SPELLED.**

`colour_system_test` test 12 is named **"rule 2 is enforced over lib/, not described"** — named
for the RULE IT ENFORCES rather than for the method it uses — and it builds its pattern from a
variable, so the literal string never appears. ⛔ **Neither probe could see it, and no amount of
re-running would have helped.**

### 🔴 AND THE CONTROL DID NOT COVER THE FAILURE

**A control was run and it passed.** ⛔ **It proved the apparatus could find SOMETHING. It did not
prove the apparatus could find something NAMED UNEXPECTEDLY — which was the only way this search
could fail.**

⭐ **THE RULE: a control must be drawn against the SPECIFIC way the search could fail, not against
the possibility that searching is broken in general.** ⚠️ **A control that confirms the tool runs
is nearly free and nearly worthless; a control that would have failed for the same reason as the
real probe is the one worth building.** **Here that would have been: take a check known to exist,
name it in a way the probe does not expect, and confirm the probe still finds it.**

### ⛔ AND THE WORKING INSTRUMENT WAS ALREADY IN USE, IN THE SAME BRIEF

**`.visible` was settled minutes earlier by enumerating every reference site and accounting for
every one of them** — the manifest. ⭐ **Colour was settled by guessing at spellings.** ⚠️ **Same
session, same author, same kind of question, and the weaker instrument was reached for because
the question felt smaller.**

**PRACTICAL FORM: for any ABSENCE claim, enumerate the population and account for every member.**
⛔ **Do not search for the thing you expect to find and report its absence** — that reports the
absence of your expectation, which is a different claim and is always true when the expectation
is wrong.

⚠️ **Same family as the keyword sweep that missed a stale-state claim because the line never said
"repo", and as the frame that decided the answer before the evidence did.** ⭐ **The distinguishing
feature here is that the SEARCH was wrong while the CONTROL passed, so nothing in the output
looked doubtful.**

---

## Brief 62 — the four that blocked the release, and one accepted cost — 20 September 2026

⛔ **All four came from the Brief 61 C appearance pass on build 58. Every one is fixed, tested,
and carries a control that was demonstrated firing.** The deferred set is at the end and is
recorded, not fixed.

### A — 🔴 `referralRequired` could not say NOT ASKED

**THE GATING READ, ANSWERED: IT WROTE.** The field was a non-nullable `bool`. The wizard wrote
`_referral` into every record, SQLite stored `0`, and `buildCsv` wrote the literal word `No`.
⛔ **A one-tap capture asserted, in a medical export, that no medical referral was needed — from
a user who was shown no such question.** That is the serious branch of the read, not the
display-only one.

⭐ **AND THIS CODEBASE HAD ALREADY FOUND IT TWICE AND COULD NOT FIX IT.** Five places knew:

    §13(bl) finding 1, 10 Sep   "WRITES `No` ON A RECORD THAT WAS NEVER ASKED ... The file
                                states something the app does not know."  Routed to the
                                adviser. NOT DECIDED.
    §13(cd), 11 Sep             costed it: "A non-nullable bool has no absent state at all ...
                                the `No` §13(bl) flagged is not a bad rendering choice - it is
                                the ONLY value the type can hold."
    buildCsv's own comment      "⛔ THE ONE KNOWN EXCEPTION."
    csv_no_blank_test test 2    pinned the exception as correct behaviour
    log_event_screen's `yn`     "these three are bool?, where referral is a plain bool.
                                NULL IS NOT 'No' HERE"

🔴 **THE REASON IT STAYED OPEN FOR TEN DAYS IS THE TRANSFERABLE PART: every one of those five
was looking at the RENDERER, and no renderer change could have fixed it.** The missing state was
in the TYPE. §13(cd) said so explicitly and still filed it as a finding rather than a change,
because "the model cannot express this" reads like a constraint rather than a task.
⭐ **A defect described accurately five times is still open until something changes.**

**WHAT MOVED:** `bool` → `bool?`; `fromMap` absent-key `false` → `null` (matching
`detailsCompleted` eight lines above it, which it had silently contradicted); SQLite write and
read made three-way; the two real quick-log creation sites stopped passing `false`; the wizard
and the form both start unset; `buildCsv` now calls `yesNoCsv`.

⭐ **`yesNoCsv` ALREADY TOOK `bool?` AND HAD NO CALLER.** Its own doc claimed *"STILL USED BY
`referralRequired`"* — untrue when written, because `buildCsv` used an inline ternary. **The
writer the field needed had been sitting unused beside the code that could not use it.**

⚠️ **NOT BACK-FILLED, DELIBERATELY.** A record already holding `false` keeps it. That `false`
means *either* "answered No" *or* "never asked" and the two are not separable after the fact;
splitting them would be reconstruction, not recovery.

⚠️ **THE CSV SHAPE MARKER WENT v7 → v8**, and it had to. The column set is unchanged, so this is
a MEANING change — and the sharpest this file has had: `No` previously meant *either* answer, and
now means only one. ⛔ **A reader cannot tell v7's `No` from v8's `No` by reading the cell.**
`sweep_contracts_test` caught the bump and its own failure message prescribed the edit verbatim:
*"If you bumped the marker WITHOUT changing columns: update `marker` here ... this test cannot
see it, which is why that half stays a convention."* **CONTRACTS.md note D is that half, and it
worked exactly as documented.**

⚠️ **THE FIELD'S WORDING AND ITS PRESENCE REMAIN ADVISER TERRITORY and were NOT touched.** The
default was a consistency defect and needed no adviser; the question it asks still does.

### B — 🔴 the summary reviewed almost nothing

**It showed Duration plus only the fields that happened to have answers — two lines for a
four-step questionnaire.** Seven fields were silently absent.

⛔ **THE FAILURE WAS THAT OMITTED AND UNANSWERED RENDERED IDENTICALLY, AS NOTHING — and only one
of them is recoverable by tapping Back.** This is the review step before a write with **no delete
path**; a user could not tell "I skipped severity" from "severity was never asked".

⚠️ **IT REVERSES A DECISION RECORDED IN THE CODE, AND THE OLD REASON WAS RIGHT ABOUT THE WORD IT
OBJECTED TO.** The comment read *"A summary that said 'Event type: unknown' would read as a
finding."* True — `unknown` is a value in this app's vocabulary. ⭐ **"not recorded" is not a
value, it is the absence of one**, and Duration had rendered it on that very screen since the
summary existed. **The objection does not reach the line that replaced it.** The old comment is
kept in place, not deleted.

⭐ **ONE PLACE "EVERY FIELD" IS NOT LITERAL:** *Did it help* and *Second dose* are gated behind
rescue medication being Yes. Listing them as "not recorded" when they were never on screen would
assert a gap in a question nobody was entitled to be asked — the same defect in the other
direction. §13(cd) calls that Not Applicable.

### C — 🔴 the progress bar was inverted, and absent on the last step

⭐ **THE VALUE WAS NEVER WRONG, AND THAT IS WHY IT SURVIVED.** `(_step + 1) / (_lastStep + 1)` is
.25 / .50 / .75 / **1.00** — correct on every step. Nothing about the arithmetic looks suspicious.

⛔ **THE DEFECT WAS ENTIRELY CHROMATIC.** With no colours given, M3 takes the filled portion from
`colorScheme.primary` — **the same navy as the AppBar one pixel above** — and the track from a
light container. So the portion that GREW was invisible and the portion that SHRANK was the
visible one. At step 4, where the value is a correct 1.0, the strip became a seamless extension
of the AppBar and read as no progress bar at all.

**CONTRAST, MEASURED, and one figure does NOT reach 3:1:**

    filled focusRing #1A8FCB  vs track infoContainer #E3F2FD    3.15:1   ✅ 1.4.11
    filled                    vs the page below      #F4F7F9    3.34:1   ✅
    filled                    vs the AppBar above    #0D4F82    2.37:1   ⛔

⛔ **THE THIRD IS UNREACHABLE, NOT UNATTEMPTED, AND THE ARITHMETIC IS PINNED IN A TEST SO NOBODY
RE-OPENS IT AS AN OVERSIGHT.** Clearing 3:1 against the AppBar needs relative luminance ≥ 0.3187;
clearing 3:1 against any light track needs ≤ 0.2784. **The demands do not overlap, so no colour
whatever satisfies both while the track stays light.** The exits are a dark track — which makes
the REMAINING portion loud again, reinstating the defect — or separating the strip from the
chrome. ⚠️ **That is a design decision and was not taken here.** The boundary that carries the
state information is filled-against-track, and it clears.

### D — 🔴 the selected type chip was carried by colour alone

**Every other selected chip on the form carries a ✓. The type chip changed only `selectedColor`
and its icon's tint — and its unselected siblings carry icons too.** 1.4.1, on the one control
whose value names what the event WAS.

⭐ **THE ALTERNATIVE WAS BUILT AND MEASURED FIRST, THEN REJECTED ON A NUMBER.** Moving the icon
into `label` keeps BOTH carriers:

    avatar icon, no tick        (before)      237.3 x 48.0
    icon moved into the label, tick too       261.3 x 48.0    +24.0 WIDE
    avatar icon + showCheckmark (chosen)      237.3 x 48.0    IDENTICAL

The label form cost 24 logical points per chip, forced an extra wrap row, shifted the whole form
40 points down, stale-d three render baselines captured from unpatched code for an unrelated
contract, **and regressed the form's chip overflow from a clean 175 to 325** until a `Flexible`
was added. ⛔ **The geometry sweep caught that regression on the first run after the change —
not a reading of it.**

⚠️ **ACCEPTED COST: the type icon is hidden while selected.** `RawChip` gives the avatar and the
checkmark one slot and the checkmark wins it, exactly as the screen's own block comment
predicted. The selected chip is the one the user just chose, its label names the type, and the
identity fill still carries the colour; the icon's job is scanning the options, an
unselected-state job.

🔴 **AND THE TICK WAS PROVED TO PAINT, BECAUSE IT HAD TO BE.** *"The avatar wins the slot"* and
*"the checkmark wins the slot"* produce **the same width**, and only one of them is a fix — a
width assertion cannot tell them apart. Pixels compared on an identical canvas: **1,014 bytes
differ** with the checkmark on, and the control pair of two identical renders differs by **0**.
⭐ **Without that control the 1,014 would have proved nothing.**

### E — ✅ ACCEPTED, NOT CHANGED: `updatedAt` moves on a hide/unhide round trip

**Found by the Brief 61 C closing diff:** hiding and then unhiding one record left exactly one
field changed across all 75 — `updatedAt` on that record, moved to the moment of the unhide.

**Defensible: hiding writes the record and the write stamps the field.** It does not reach the
CSV, so it never leaves in an export — verified, `updatedAt` is not among the 17 columns.

⛔ **THE CAVEAT, NAMED RATHER THAN LEFT IMPLICIT: after a hide and unhide, "last updated" no
longer means "the content last changed".** ⚠️ **Someone reading a backup could infer a content
change that did not happen.** Accepted because the alternative — special-casing the write to
preserve the old stamp — costs more than the ambiguity, and because the ambiguity is confined to
a field nothing user-facing renders.

### Deferred — RECORDED, NOT FIXED, and they go to the follow-up release

Two editors styled differently · time format differs between home and history · red carrying four
meanings · three selection idioms on one screen · Help's chevron on QUICK LOG NOTIFICATION · the
large voids in the wizard and Help · the cloud icon beside "Notiva never receives your events" ·
the backup sheet's Cancel against the nav bar · History's transparent pinned count · the hide
dialog not naming the event · chip group alignment · "34 to choose from" / "Show all" · the
SnackBar outliving navigation.

⚠️ **The SnackBar is the strongest of them** — it survived 60 seconds, navigation and a modal
sheet with its Undo behind a scrim. **Promote it if the follow-up slips.**

⛔ **These ship with the menu consolidation and the Help accessibility audit.**

---

## Brief 62 amendment and revision — 20 September 2026

### A3 — 🔴 the default was worse than part A stated, and the intent is what shows it

**The developer's intent for the field, stated:** *"To capture whether further action was taken
— went to a specialist post the event, went to a doctor, went to hospital. Not to capture the
detail, but whether further action happened after/during the event. Reporting only, so the
specialist can see where they can follow up."*

⛔ **Against that intent, a pre-answered "No" asserts NO FURTHER ACTION WAS TAKEN.** An event
where the person went to hospital would carry *"no further action"* into the record a specialist
reads **in order to decide where to follow up** — without anyone choosing it, and on the one
field whose entire purpose is to flag follow-up.

⭐ **SO THE UNSET-BY-DEFAULT FIX IS NOT A CONSISTENCY CHANGE.** Part A justified it by the
rescue-medication idiom sitting six pixels above with neither option selected. That reasoning was
correct and far too weak: **the defaulted value was the exact inverse of the field's purpose,
aimed at the exact reader the field exists to serve.**

⚠️ **AND THE ADVISER ROUTING IS WITHDRAWN, with the reason worth keeping.** The chat read the
LABEL and inferred the field's purpose from it. *"Required?"* asks for a judgement about
necessity; **the field asks what happened.** ⭐ **The wording strays from the regulatory line —
the field does not.** A reword that replaces a judgement with a fact IMPROVES the regulatory
position, so it does not wait on the adviser; the final wording goes into the next batch as a
confirmation, not a gate.

🔴 **THE TRANSFERABLE PART: a label can misrepresent its own field well enough to misroute the
work.** Two passes treated this as adviser territory because the label asked a clinical
question. The stored fact was never clinical.

### R1 — 🔴 A FINDING THAT NAMES A TYPE-LEVEL IMPOSSIBILITY READS AS A CONSTRAINT, NOT A TASK

**Five prior findings saw the referral defect and none fixed it:**

    §13(bl), 10 Sep            "WRITES `No` ON A RECORD THAT WAS NEVER ASKED ... The file
                               states something the app does not know."  Routed to the
                               adviser.  NOT DECIDED.
    §13(cd), 11 Sep            "A non-nullable bool has no absent state at all ... the `No`
                               §13(bl) flagged is not a bad rendering choice - it is the ONLY
                               value the type can hold."
    buildCsv's comment         "⛔ THE ONE KNOWN EXCEPTION."
    csv_no_blank_test test 2   pinned the defect AS CORRECT BEHAVIOUR
    log_event_screen's `yn`    "NULL IS NOT 'No' HERE" - then names referral as the field
                               that could not follow that rule

⭐ **§13(cd) IS A COMPLETE AND CORRECT DIAGNOSIS, AND IT WAS FILED AS A FINDING.** *"The model
cannot express this"* sounds like a fact about the world. **It is a work item.** The sentence
that fully explains a defect is the sentence most likely to end the investigation, because
nothing about it feels unfinished.

⛔ **AND ALL FIVE OBSERVERS WERE LOOKING AT THE SAME LAYER — THE RENDERER.** Each asked what the
CSV should print. No renderer change could have fixed it; the missing state was in the type, one
level down, where nobody was looking because the renderer is where the symptom appears.

⚠️ **PRACTICAL FORM: when a defect survives repeated observation, check whether every observer
was looking at the same layer.** Repetition of a finding is evidence about the observers'
vantage point, not confirmation of the finding. ⭐ **Five independent sightings of one symptom
is not five investigations — it is one investigation performed five times.**

⚠️ **Related but distinct from the stale-authoritative-label class:** nothing here was wrong.
Every one of the five was accurate. **Accuracy is not what was missing.**

### R3 — existing records cannot be repaired, and the marker is the only thing that says so

⛔ **STATED PLAINLY: every record written before 20 September 2026 carries `referralRequired =
false`, and its export reads `No` whether or not anyone was ever asked.** On the tablet that is
**75 of 75 records.**

⭐ **Correctly not back-filled.** An existing `false` is not separable from an answered No — the
information to split them was never recorded. Inventing a split would be reconstruction, which
this corpus's standing rule forbids, and it would put a fabricated distinction into a medical
export.

⭐ **THE v7 → v8 MARKER IS THE ONLY THING THAT TELLS A READER THOSE CELLS ARE AMBIGUOUS.** A
reader who sees `No` in a v8 file cannot tell whether it was answered or defaulted; the marker is
what lets them ask when the file was written. **That is precisely the job a shape marker was
specified for, and this is the first time it has been needed for a value whose meaning changed
underneath a stable column name.**

⚠️ **CONTRACTS note D FIRED FOR THE FIRST TIME AND HELD, 20 September 2026.**
`sweep_contracts_test` went red on the bump and **its own failure message prescribed the repair
verbatim**: *"If you bumped the marker WITHOUT changing columns: update `marker` here. The rule
permits that ... and this test cannot see it, which is why that half stays a convention."*
⭐ **The honest reading: the test did not detect the value change — it cannot, and it says so.
It detected the MARKER MOVING and forced a human to say whether the move was legitimate.** Had
the marker not been bumped, nothing would have gone red and the file's meaning would have changed
in silence.

### R5 — the three remaining non-nullable fields are NOT this defect

**`feelings`, `triggers` and `notes` still cannot express "never asked"** — §13(cd) enumerates
all four together and note H keeps that scoped.

⛔ **THE DIFFERENCE THAT MATTERS: referral wrote the WORD `No` — a positive claim, in a medical
export, about a clinical follow-up that may have happened.** An empty observations cell asserts
nothing; a reader sees a blank and knows only that it is blank.

⚠️ **Do not let the parallel promote them to ship-blocking. Do not let the difference retire
them either.** They remain a real gap — a blank that means both "asked, none" and "never asked"
is still ambiguous — but it is an ambiguity that MISLEADS NOBODY into a false positive, and that
is the axis on which referral was urgent.

⭐ **They are also harder, and the reason is worth recording before someone costs it as "the same
change again": a nullable list and a nullable string are ambiguous in their own right.** Code
throughout treats empty and null alike, so the work is not a type edit but a sweep of every
reader.

### R2 — the progress strip is SEPARATED from the chrome, and one figure was wrong

⭐ **THE CHAT'S 1.4.11 POSITION IS CORRECT AND NO CRITERION BINDS AT THAT BOUNDARY.** The state
information is the filled/track boundary and it clears at **3.15:1**; the component is
identifiable by its own edge against the page at **3.34:1**. The AppBar is a neighbour.

⛔ **BUT THE STATED REASON FOR THE FIX NO LONGER HELD, AND IS CORRECTED HERE.** R2 said the strip
*"merges with the chrome and reads as absent, which is the original defect returning."* **That
was true of the OLD colour and not of the new one.** The original defect was `#0D4F82` on
`#0D4F82` — **1.00:1, literally the same colour.** The replacement is `#1A8FCB`, a hue shift at
2.37:1, which is plainly visible. **The defect had not returned; it had been reduced to a
below-threshold figure.**

⭐ **THE FIX WAS APPLIED ANYWAY, AND FOR A BETTER REASON THAN THE ONE GIVEN.** A 4pt gap of page
background between the AppBar and the strip **removes the AppBar from the adjacency set
entirely** — it does not improve the 2.37:1 figure, it retires it. **Accepting a number and
removing the question are different outcomes**, and only the second one stays true if the palette
changes.

🔴 **AND A FIGURE IN THE 20 September RECORD WAS WRONG. CORRECTED, NOT DELETED.** The entry above
this one reported *"filled vs the page below #F4F7F9 — 8.02:1"*. ⛔ **The true figure is
3.34:1.** 8.02 was `surfaceSunken` TRACK against the APPBAR, read off a neighbouring column of
the same search output and carried into a claim about a different pair. It was corrected in the
code comment, the test's docstring, the test's own failure message and the record.

⚠️ **THE CONCLUSION SURVIVED — 3.34 still clears 3:1 — WHICH IS WHY IT WENT UNCHECKED.** ⭐
**A wrong number that supports the right conclusion is the kind nothing re-derives**, and this
is the same class as the working-memory figures already recorded: *a figure that was correct
about something, reused where it did not apply.* **It was caught only because R2 forced the
boundary to be re-examined, not by any check.**

---

## Brief 62 Revision 3 — the wording, the defaults, and two more classes — 20 September 2026

### 1 — the v1 rationale, in the developer's words, written down at last

▎ **"The default position for the referral question was no. This was decided in version 1 to
▎ minimise the administration work for the patient or carer as most times referral didn't
▎ happen. If it did, they'd select yes."**

▎ **"Remember the default 'No' was on the single form for them to fill out. The wizard did not
▎ exist. The wizard screen will ask and they will select either or."**

⛔ **THIS IS THE POINT OF RECORDING IT: the reasoning was sound, and it existed only in one
person's head.** Five findings and one fix treated the default as a defect — §13(bl), §13(cd),
`buildCsv`'s "ONE KNOWN EXCEPTION", `csv_no_blank_test` test 2, `log_event_screen`'s `yn`
comment, and `c4d5d0a`, which removed it from **both** editors.

⭐ **NOBODY WAS WRONG TO INVESTIGATE.** A preselected clinical answer with no recorded
justification is indistinguishable from an oversight, and every observer correctly reported it
as one. **The cost of the unrecorded decision was not the investigation — it was that the
investigation could not terminate**, because the evidence that would have stopped it was not in
the corpus.

### 2 — 🔴 CLASS: A DECISION SCOPED TO ONE SURFACE, INHERITED BY A SURFACE BUILT LATER

⛔ **The v1 default was decided FOR THE SINGLE FORM, WHEN THE FORM WAS THE ONLY EDITOR.** The
wizard did not exist. When it was built it took the default with it — and the reasoning behind
that default (*"the form shows everything at once and is scanned, so a visible default is
correctable in one tap"*) **does not survive the move to a screen that asks one question at a
time.**

⭐ **NOTHING WAS OVERRULED AND NOTHING DRIFTED.** The rule was true, stayed true, and was
applied to a case it was never tested against. **That is why it is invisible to every check this
corpus has**: a stale-value checker finds no stale value, a contradiction checker finds no
contradiction, and the rule reads as deliberate at both sites because at one of them it is.

⚠️ **SAME SHAPE AS THE BACKUP REMINDER** appended to a banner chain designed for two advisory
nudges, and as the closed-list-versus-rule entry in the workspace rules — *a right rule whose
justification stopped covering it as the corpus grew.*

⛔ **PRACTICAL FORM: WHEN A NEW SURFACE REUSES AN EXISTING RULE, THE RULE'S ORIGINAL SCOPE IS
PART OF WHAT MUST BE CHECKED — not just whether the rule is still true.** ⭐ **Ask what the rule
was decided AGAINST, not only what it says.** A rule carries the shape of the problem it was
made for, and that shape is usually not written down beside it.

⚠️ **AND THE REPAIR IS NOT HARMONISATION.** The two editors now differ ON PURPOSE, and the
reason sits at BOTH call sites so the next reader meets it wherever they arrive. **A future
pass that "tidies" them into agreement would be this same class a third time.**

### 3 — ACCEPTED, not reopened: the form's No has two writers

⛔ **A record edited on the single form cannot distinguish "saw No and agreed" from "saw No and
did not engage with the question".** Both export as `No`.

⭐ **That is ordinary form behaviour and it is NOT the defect that was fixed**, which was a value
written on a path where **nothing was ever displayed** — the quick-log capture, which asserted
an answer to a question the user was never shown.

⚠️ **RECORDED IN THE v8 MARKER NOTE, where an export reader will meet it**: `No` has two writers
— a form default the user saw but may not have touched, and a wizard answer that is always
chosen. **No further CSV bump**: v8 was taken for exactly this meaning change and now describes
the three-state result in full.

### 4 — 🔴 ASSERTING THAT THERE WAS A DIFFERENCE, RATHER THAN WHAT THE DIFFERENCE WAS

⛔ **Brief 62 D's control fired, passed, and proved the wrong proposition.** `type_chip_carrier_test`
test 2 asserted that `showCheckmark: true` **changed the pixels** beside an avatar. It did — by
**1,014 bytes**, with a clean control showing two identical renders differ by 0.

🔴 **SUPERIMPOSITION AND REPLACEMENT ARE INDISTINGUISHABLE TO THAT ASSERTION.** Flutter drew the
checkmark ON TOP of the type icon, and the test could not tell that from the checkmark replacing
it. **The accepted cost recorded beside it — "the type icon is hidden while selected" — was
false, and the test that was supposed to establish it said nothing about it.** It shipped in
build 59 and was caught by a tablet capture.

⭐ **THE TEST WAS NOT WEAK. IT WAS ANSWERING A DIFFERENT QUESTION** — *does the tick paint* —
and it answered correctly. The question that mattered was *does the avatar stop painting*, and
nothing asked it.

⛔ **PRACTICAL FORM: A DIFFERENCE ASSERTION IS ONLY AS STRONG AS THE ALTERNATIVE IT EXCLUDES.**
Before trusting `expect(diff, greaterThan(0))`, name the outcomes that would ALSO satisfy it and
check whether any of them is a defect. ⭐ **The repair here was to assert an IDENTITY instead of
a difference**: the selected chip must render **byte-identically** to a chip that never had an
avatar — the one form of the claim a superimposition cannot satisfy.

⚠️ **Same family as the coverage-versus-consistency and count-versus-diff entries in the
workspace rules: output that reads as assurance while measuring something adjacent to the
question.** ⛔ **The distinguishing feature here is that a CONTROL was present and healthy.**
A control proves the apparatus is live; it says nothing about whether the proposition is the
one you needed.

### 5 — 🔴 A WRONG FIGURE WHOSE CONCLUSION HOLDS IS NEVER RE-DERIVED

⛔ **"filled vs the page below — 8.02:1" was wrong. The true figure is 3.34:1.** 8.02 was
`surfaceSunken` **track** against the **AppBar** — a real number about a different pair, lifted
from a neighbouring column of the same search output.

⭐ **BOTH FIGURES CLEAR 3:1, SO THE CONCLUSION WAS RIGHT EITHER WAY.** It was written into a
code comment, a test docstring, a test's own failure message and the register, and **nothing
re-derived it** — because nothing had cause to. It surfaced only when R2 reopened that boundary
for an unrelated reason.

⚠️ **THE TELL, AND IT IS THE SAME ONE THE WORKING-MEMORY ENTRY ALREADY NAMES: a figure that was
CORRECT ABOUT SOMETHING, reused where it did not apply.** 8.02 did not feel like a guess. It had
been computed, printed, and read off a real table.

⛔ **PRACTICAL FORM: a figure copied from a multi-column result must be re-stated with BOTH of
its operands, at the moment it is copied.** *"8.02"* is unfalsifiable on the page; *"surfaceSunken
track vs AppBar, 8.02:1"* cannot be silently attached to the wrong pair. ⭐ **Where a figure
supports a threshold claim, the operands ARE the claim** — the number alone is not checkable by
any reader, including the one who wrote it.

⚠️ **AND THE HONEST LIMIT: no check would have caught this.** The assertion built on it passed,
because 3.34 clears the same bar. **This is a discipline at the point of writing, not a gate.**

### 6 — the flake: UNREPRODUCED after ten full runs, 20 September 2026

⛔ **`wizard_summary_completeness_test` test 4 — *"an ANSWERED field shows its value, not 'not
recorded'"* — failed ONCE, in a full-suite run on 20 September 2026.** It has not failed since.

**THE CHASE, bounded as specified:**

    full suite, ten consecutive runs   10 PASSED, 0 failed, 876 tests each
    the file in isolation              passed every time it was run
    targeted runs during the pass      passed every time

🔴 **RECORDED AS UNREPRODUCED. NO CAUSE IS SUPPLIED, AND THAT IS DELIBERATE.**
⭐ **The available explanation is not offered as the answer:** the failing run was the first
after `type_chip_carrier_test` was added, and that file is the only one in the suite that
rasterises real images (`toImage()` inside `tester.runAsync`), which is heavy and runs in
parallel with everything else. ⛔ **That is a hypothesis with no evidence attached and it is
named here only so a future reader does not think it went unconsidered.** This corpus already
has the entry about a known defect offered as the cause of a new failure — *a hypothesis to
TEST, not accept* — and ten green runs test nothing about it either way.

⚠️ **WHAT IS ACTUALLY KNOWN: one red run, one test, no reproduction in ten attempts, and no
mechanism identified.** A false OPEN costs a second look; a false CLOSED costs the finding. So
this stays open as an observation rather than being written off.

⛔ **IF IT RECURS, THE FIRST THING TO CAPTURE IS THE FAILING ASSERTION'S OWN MESSAGE, not the
run's verdict** — test 4 makes four separate assertions and "the run went red" says nothing
about which. That is the attributable-control rule in `CLAUDE.md`, applied to a flake.

⭐ **AND THE REASON THIS IS RECORDED AT ALL RATHER THAN SHRUGGED OFF: a suite that can go red
spuriously erodes the one thing this week built** — that green means something. **An unexplained
red is worth less than a red with a cause, and far more than a red that was never written
down.**

---

## Brief 63 — the CSV header rename, and what it exposed — 20 September 2026

### The decision, with its reasoning

⛔ **The CSV export header `referral_required` became `further_attention`.** Position 15 of 17,
column count unchanged, values unchanged, shape marker **not** bumped a second time.

**Three reasons, all of which had to hold:**

1. ⭐ **The capture surfaces stopped asking about a referral and the header did not.** Brief 62
   reworded both editors to *"Further medical attention?"*. Left alone, the export would have
   asked a question **no screen asks**, permanently, in the file a specialist reads.
2. ⭐ **v8 had already moved this cycle and had not shipped.** A rename folded into a bump that
   is already happening costs **nothing**. A rename after release costs a second bump and a
   second round of consumer breakage. ⛔ **The window was open and closing.**
3. ⭐ **The header is not a durable key.** Nothing reads a CSV back — established in Part A with
   a control, **checked 20 September 2026**, and that date is the date of the CHECK, not of the
   property.

⚠️ **NOT bumping to v9 is itself the decision, not an omission.** v8 now carries **two**
changes — the value convention from Brief 62 and this rename — and the marker note says so
explicitly, so its meaning cannot later be reconstructed from only one of them.

### 🔴 THE HAZARD, recorded so the DDL pin is self-explanatory

⛔ **The CSV header string was BYTE-IDENTICAL to the SQLite column name.** Both were
`referral_required`. They were separate literals in separate files — `buildCsv`'s header list,
and `event_store_sqlite.dart`'s DDL, write and read — so the rename was possible.

🔴 **A repository-wide find-and-replace on that string would have renamed the database column
and orphaned every existing user's data.** The SQLite column is the first entry under Brief 63's
own *"What must NOT change"*.

⚠️ **AND THE SAME COLLISION EXISTED IN THE TEST SUITE, where it was quieter and nastier.**
Seventeen test row fixtures and **five test DDL declarations** carry the same string. Renaming
those would not have touched user data at all — the suite would simply have gone green against a
schema production does not have. ⭐ **A suite that has quietly stopped testing the thing is worse
than one that fails**, because nothing announces it.

⭐ **THE REMEDY IS A TEST, NOT A NOTE.** `test/durable_keys_test.dart` pins the DDL column, its
read and write sides, the backup JSON key, the legacy prefs drain, and the fact that the export
header no longer shares a string with the schema. **Demonstrated failing by performing the exact
mistake it exists for.** ⛔ **The CSV header is deliberately NOT pinned there** — it is not
durable, and asserting a permanence it does not have would block the next legitimate rename.

### 🔴 CLASS: A BRIEF THAT NAMED AN IMMUTABLE THING, THEN ASKED A QUESTION INCAPABLE OF DETECTING IT CHANGING

**Observed 20 September 2026.** Brief 63 listed the SQLite column under *"What must NOT change"*
and, in the same document, asked Part A whether a shared **constant** fed both the backup key and
the CSV header. ⛔ **It never asked whether the header's STRING collided with a durable key's
STRING** — which is the only form the danger actually took.

⭐ **NAMING A THING THAT MUST NOT CHANGE IS NOT THE SAME AS AIMING A CHECK AT IT.** The
prohibition and the check were both present, both carefully written, and **pointed at different
things**. The rename was safe because one reader noticed the collision while doing something
else; nothing in the process was arranged to notice it.

⚠️ **PRACTICAL FORM: for every item on a must-not-change list, name the check that would catch it
changing.** If the answer is "someone would spot it", that is the gap. ⛔ **A prohibition with no
detector is a hope.**

### 🔴 CLASS: A FACT RESTATED FROM MEMORY WHEN THE RECORD WAS ONE READ AWAY

**Observed 20 September 2026.** Brief 63 described the CSV values as *"empty for not asked, and
the two written values"*. ⛔ **Both halves were wrong.** There are **three** written values, and
the unasked state is the literal `Not Captured`, never empty:

    String yesNoCsv(bool? v) => v == null ? kCsvNotCaptured : (v ? 'Yes' : 'No');

⚠️ **The convention had been specified one day earlier, in Brief 62, by the same author.** It was
restated from memory rather than read, and the restatement inverted the very property the
previous brief had been written to establish.

⭐ **WHAT STOPPED IT PROPAGATING WAS AN INSTRUCTION, NOT A CHECK**: *"Quote the two written
values from the code rather than from me."* **The brief was wrong and simultaneously carried the
instruction that prevented its own error from landing.** That is worth more than being right:
a brief that says *read it yourself* survives its author misremembering.

⚠️ **Same family as the working-memory entry already recorded here** — a figure that was correct
about something, reused where it did not apply. **The distinguishing feature: the source was in
the same repository, in a file the author had written the day before.** Proximity is not
consultation.

### 🔴 CLASS: CLASSIFIED BY SURFACE FORM RATHER THAN BY ROLE

**Observed 20 September 2026, in my own Part A report.** Five test-side SQLite DDL lines —
`'referral_required INTEGER'` — were classified as **identifier in code** rather than **durable
key**. ⛔ **The classifier keyed on a punctuation shape** (a trailing quote-colon, as in
`'referral_required':`) that a DDL declaration does not have.

⚠️ **THE BUCKET THEY LANDED IN WAS LABELLED internal, not persisted, safe to rename.** They are
schema. Renaming them would have left the test suite asserting against a schema production does
not have, and **passing**.

⭐ **ROLE DOES NOT FOLLOW SHAPE.** Two strings with the same spelling and different punctuation
had opposite consequences; two with different punctuation had the same role. **A classifier that
reads syntax is answering "what does this look like", and the question was "what does this do".**

⚠️ **PRACTICAL FORM: where a classification drives a safety decision, verify the buckets by
sampling their MEMBERS, not by trusting the rule that filled them.** The error surfaced only when
a later pass re-enumerated the same lines with a different splitter and the counts disagreed.

### 🔴 CLASS: A PREDICTED TEST FAILURE, ASSERTED RATHER THAN TESTED

**Observed 20 September 2026.** Amendment 1 stated that `sweep_contracts_test` *"will go red and
hand back its own prescribed repair, as it did at the v7→v8 bump — that is the contract working.
Do not treat it as a defect and do not route around it."*

⛔ **It did not go red.** Measured both ways rather than assumed:

    pin left at the old name          red  — "the pinned column referral_required is not in the source"
    pin updated as B-1 directs        GREEN, with no marker bump

⭐ **THE PREDICTION REASONED BY ANALOGY** with v7→v8, which changed the column **set**. A rename
that updates the pin and the source in one commit is invisible to a test that compares pin
against source. ⚠️ **And the instruction "do not route around it" would have been unfollowable**:
the same brief's B-1 required updating that very pin, which is what made it green.

⚠️ **A claim that a test will fail is a prediction like any other.** ⛔ **The cost of asserting
it: had the pass simply not seen red and moved on, the conclusion would have been "the contract
checked this" when the contract had not.**

### ⚠️ STANDING NOTE: A `git grep` COUNT IS A COUNT OF THE TRACKED SET

**Observed 20 September 2026, twice from opposite directions.** Part A enumerated it as an
exclusion — build artefacts, `.git` internals, three untracked working papers. Part B then met it
as a **defect in its own measurement**: the newly written pin file was invisible to the
post-change count until it was staged, and the reconciliation disagreed with its prediction until
that was noticed.

⭐ **Stage new files before counting**, or the measurement describes a repository that no longer
exists.

### What the rename did NOT touch, proved rather than asserted

**All 14 files containing a durable site are absent from the diff** — checked mechanically
against the diff's own file list, with a control confirming a changed file is detected. That is
4 lib SQLite sites, 5 test DDL declarations and 17 test row fixtures, **26 durable live sites**.

#### ⚠️ The Part A figure, superseded in place — 20 September 2026

⛔ **Part A's own words, quoted so the classification's movement stays visible:**

> **1 · Durable key — 26 lines, immutable**

⭐ **STANDING FIGURE: 26 durable LIVE sites of the snake_case string** — 4 lib SQLite, 5 test
DDL declarations, 17 test row fixtures.

🔴 **AND THE TWO 26s ARE NOT THE SAME SET, WHICH IS WHY THIS NEEDS SPELLING OUT RATHER THAN
CORRECTING.** Part A's 26 counted **both spellings** — 5 camelCase backup and legacy-prefs keys,
4 snake_case lib sites, 17 test fixtures — and put the 5 DDL declarations in the wrong bucket.
The standing 26 counts **the snake_case string only** and includes those 5. **The figure is
unchanged and the set beneath it is different.**

⚠️ **THE `21` NAMED IN AMENDMENT 2 IS NOT A FIGURE PART A STATED.** Part A reported 26. The 21
is the snake-only subset *implied* by Part A's classification — 4 lib + 17 fixtures, with the 5
DDL lines excluded because they had been misfiled — and it was first written down in the Part B
report, as the like-for-like comparison that exposed the error. ⭐ **Recorded this way because
attributing a number to a document that never contained it is the same class of defect as the
misclassification it describes**: a figure carried into a claim about a source that does not
support it.

⛔ **THE TRANSFERABLE PART IS NOT THE COUNT.** It is that a bucket labelled *internal, safe to
rename* held five schema declarations, and that two identical totals can hide a changed set. See
**CLASS: CLASSIFIED BY SURFACE FORM RATHER THAN BY ROLE** above.

### Out of scope, as a decision rather than an oversight

⛔ **The three untracked working documents that carry the retired term stay as they are**
(`MER Refresh Chat content.txt`, two under `scratchpad/`). They are working papers superseded by
the repository. ⭐ **They keep the old word rather than being quietly edited to look consistent**
— a working paper that has been tidied to agree with the present is no longer evidence of what
was thought at the time.

---

## Brief 63 C-5 — three more, dated by observation — 20 September 2026

### 🔴 A FIGURE ATTRIBUTED TO A SOURCE THAT DOES NOT CONTAIN IT

**Observed 20 September 2026.** Amendment 2 instructed: *"The Part A figure of **21** durable
sites is superseded, not corrected away."*

⛔ **Part A never reported 21. It reported 26.** The 21 is the snake-only subset *implied* by
Part A's classification — 4 lib sites plus 17 test fixtures, with 5 misfiled DDL declarations
excluded — and it first appears in the **Part B** report, as the like-for-like comparison that
exposed the misclassification.

⭐ **THE INSTRUCTION WAS TO ANNOTATE A QUOTE THAT DID NOT EXIST.** Following it literally would
have put a fabricated quotation into the register, attributed to a document that never contained
it, inside an entry whose whole subject is figures carried into claims their sources do not
support. **The correction was to quote what Part A actually said and record the provenance of
the 21 separately.**

⚠️ **AND THE FIGURE WAS NEVER IN THE REPOSITORY AT ALL** — it lived only in a chat report. An
instruction to *annotate in place* had no place to annotate. ⭐ **The superseded record was
created rather than the instruction reported unexecutable**, because the transferable content is
the reason, not the number.

### 🔴 TOTALS THAT AGREE ARE NOT EVIDENCE THAT THE SETS AGREE

**Observed 20 September 2026, and this is the durable finding of the three.**

    Part A      26 durable    = 5 camelCase keys + 4 snake lib sites + 17 test fixtures
    standing    26 durable    = 4 snake lib sites + 5 test DDL + 17 test fixtures

⛔ **The same total. Different sets. A misclassification of five lines sitting inside an
unchanged number.** Had the reconciliation compared only totals, it would have reported agreement
and the five DDL declarations would have stayed in the bucket marked *internal, safe to rename*.

⭐ **A COUNT IS A PROJECTION, AND PROJECTIONS LOSE THE THING THAT CHANGED.** Two sets differing
by a swap of five members for five others are indistinguishable by cardinality. **The B-2
reconciliation caught it because it compared spelling-by-spelling and live-versus-comment, not
because it compared totals.**

⚠️ **PRACTICAL FORM: when a count is used as evidence that nothing moved, state what the count
is OVER and compare the same partition on both sides.** ⛔ **Two numbers matching is the weakest
form of agreement there is** — it is one bit of evidence about a set with many members. Where the
claim matters, compare the members.

### ⭐ THE EXISTENCE CHECK, AS STANDING PROCEDURE — NOT AN INCIDENT

⛔ **PROMOTED TO THE WORKING AGREEMENT 20 September 2026 — `docs/WORKING-AGREEMENT.md` §2(f) IS
NOW AUTHORITATIVE FOR THE RULE.** Brief 65 Part A asked for it in the method rules; it was already
here, and a second independent copy is how one provenance claim on this project came to need
correcting in four files at once.

⭐ **WHAT SURVIVES HERE IS THE INCIDENT AND ITS EVIDENCE** — the three firings, the two fabricated
tool returns, and the undefined `C-5`. ⛔ **Do not restate the rule below; it will drift.** The
statement of the rule is in the working agreement, beside (e) and the other lettered rules a
reader goes to for process.

**Recorded as procedure on 20 September 2026, because its value is that it keeps firing.**

> ⛔ **A PATH QUOTED IN AN INSTRUCTION IS VERIFIED TO EXIST BEFORE THE INSTRUCTION IS EXECUTED.**
> Where it does not, the CLI stops and reports rather than proceeding from the instruction it
> already holds. **The check is not relaxed on the strength of a confident-sounding instruction,
> and a stated tool return is not a substitute for looking.**

**IT HAS FIRED THREE TIMES IN THIS BRIEF'S HISTORY**, each time before any document was written
from a superseded or non-existent instruction:

    Amendment 1   asserted by path before it existed
    Amendment 2   asserted by path, WITH a fabricated tool return quoting a commit
    Amendment 3   asserted by path, with a second fabricated tool return — and on this
                  occasion the check also caught C-5 REFERENCED BUT UNDEFINED

🔴 **THE THIRD IS THE INSTRUCTIVE ONE. It caught a missing DEFINITION, not a missing file.**
C-5 was named in an instruction and defined nowhere in the three documents then on disk. ⭐ **A
numbered instruction cannot be inferred**, and inferring it would have produced work that looked
compliant and answered to nothing. **Declining to guess was the finding.**

⚠️ **WHY THIS IS PROCEDURE AND NOT A LESSON LEARNED.** Amendment 1 recorded a rule addressed to
the authoring side — *a path is not quoted unless a commit for it has returned* — and **it did
not survive a single turn.** ⛔ **A rule that depends on the party most likely to breach it
remembering not to is not a control.** The check works because it sits on the executing side, runs
unconditionally, and costs one command.

⭐ **AND IT IS CHEAP ENOUGH THAT ITS FALSE-POSITIVE RATE DOES NOT MATTER.** Verifying a path that
does exist costs nothing and delays nothing. **The asymmetry is the whole argument:** the cost of
checking is one command; the cost of not checking is documents written from instructions that do
not exist, in a register whose value is that it can be trusted.

---

## Brief 63 Part D — the store bullet, and what is still divergent — 20 September 2026

### What changed

**`docs/Store Listing Copy — v1.1 revision.md`, one line.** It read:

> • Whether a medical referral is needed

It now reads:

> • Whether further medical attention happened

⛔ **TWO DEFECTS, NOT ONE.** *"referral"* was the retired term — the capture surfaces stopped
asking about a referral in Brief 62 and now ask *"Further medical attention?"*. *"needed"*
asserted a **clinical judgement the app never makes**; the field records whether something
HAPPENED, not whether it was warranted.

⭐ **THE WORDING CAME FROM THE CODE, NOT FROM A BRIEF**, as Part D required. It is the live label
in declarative form, and it matches the History filter's subtitle word for word — so the store
and the app read the same, and a user meeting both finds no seam.

⚠️ **The old wording is quoted and dated in place, in an HTML comment.** That form was chosen
because this document is a **paste source** for three store consoles: a visible annotation could
be pasted into a listing along with the copy it annotates. The file already used that convention
for the load-bearing platform names, so this follows it rather than inventing a second one.

### 🔴 D-5 · OPEN ITEM, dated by the date CHECKED — 20 September 2026

| surface | state as at 20 September 2026 |
|---|---|
| `docs/Store Listing Copy — v1.1 revision.md` | ✅ **carries the new wording** |
| Apple App Store listing | ⚠️ **UNVERIFIED** — expected still to carry the retired wording |
| Google Play listing | ⚠️ **UNVERIFIED** — expected still to carry the retired wording |
| Microsoft Store listing | ⚠️ **UNVERIFIED** — expected still to carry the retired wording |
| notiva.com.au | ⚠️ **UNVERIFIED** — expected still to carry the retired wording |

⛔ **UNVERIFIED, NOT UNCHANGED.** The four surfaces above are console and website state. They are
**not visible from this repository and nothing here can assert their contents** — neither that
they still carry the old wording nor that they do not. **The expectation stated is an
expectation, not a finding.**

⛔ **UPDATING THEM IS CONSOLE AND WEBSITE WORK, NOT REPOSITORY WORK, AND IT HAS NOT BEEN DONE.**
This release ends with the repo document and the live listings **divergent by design** — the
divergence is recorded here so it is a known open item rather than a discovery.

🔴 **THE WEBSITE IS THE SPECIFIC RISK, AND IT IS NAMED BECAUSE IT HAS HAPPENED BEFORE.** Copy
written from the website rather than from the code is a documented past failure on this app.
⭐ **If notiva.com.au becomes the surviving home of the retired wording, the next person writing
copy has a plausible, findable, wrong source** — and the failure recurs through exactly the route
it took last time. **The repo document is now correct; the website is the one that can still
mislead.**

⚠️ **AND THE STORE CONSOLES CARRY A SECOND, OLDER DIVERGENCE** already recorded at the head of
that document: its character limits *"were NOT verified against the consoles"*. **Anyone opening
a console to fix the wording should confirm the limits in the same visit**, because the two jobs
share their only expensive step, which is getting into the console at all.

---

### ⭐ C-5, further entry — CLASS: WORDING SAFE ON AN EXPLANATORY SURFACE BECOMES A CLAIM ON A DESCRIPTIVE ONE

The helper's first sentence defines what counts as further medical attention. That is legitimate
where it sits, because its job is to explain a question. Placed under a heading reading WHAT IT
RECORDS, the same words imply the app stores which of doctor, hospital or specialist was
involved. It does not: the field holds yes, no, or not asked.

Excluded on data-model grounds. Amendment 3 D-4 excluded only the helper's second sentence, and
on clinical-claim grounds — a different sentence for a different reason. The instruction did not
anticipate the exclusion that mattered.

**Observed 20 September 2026.**

---

## Brief 64 — the Help screen's spacing, and an instrument blind by construction — 20 September 2026

### The defect

⛔ **The gap between the last two Help sections was 0 on Android and iOS, and 12 everywhere else.**
Its whole cause was one guard: `if (Platform.isWindows) const SizedBox(height: 12)`. On the two
platforms that are not Windows the widget was never built.

**MEASURED 20 September 2026**, tablet framebuffer at dpr 1.0 — device pixels, directly
comparable with the Windows logical figures below:

    RECORDING EVENTS -> HISTORY & EXPORT        12
    HISTORY & EXPORT -> YOUR DATA               12
    YOUR DATA        -> QUICK LOG NOTIFICATION  12
    QUICK LOG        -> GETTING HELP             0    <- the defect

⭐ **A PHOTOGRAPH, NOT AN INFERENCE.** Scanning down x=400 through that boundary: card interior
at y=548, **border at y=549, border at y=550**, card interior at y=551. Two 1px card borders on
adjacent rows with **no page background between them**. A healthy boundary shows twelve rows of
`(245,248,251)`.

### 🔴 THE CLASS: AN INSTRUMENT THAT SHARES A PLATFORM WITH ONE BRANCH IS BLIND TO THE OTHER BY CONSTRUCTION

**Observed 20 September 2026.** The CLI host is Windows. `Platform.isWindows` is therefore true
in every widget test, so a widget test rendered **the branch that was already correct**, measured
`12, 12, 12, 12`, and reported the screen uniform.

⛔ **IT DID NOT FAIL. IT REPORTED CONFIDENTLY ON THE BRANCH IT COULD SEE.** No error, no skip, no
signal of any kind that a second code path existed and had not been looked at.

⚠️ **AND THE PROOF IS IN THIS PASS'S OWN CONTROL.** With the guard deliberately re-introduced:

    help_no_platform_gap_test    RED
    help_section_spacing_test    STILL PASSES

⭐ **The branch does not break the spacing test. It makes it IRRELEVANT, silently, while it goes
on passing.** That is why B-3's source scan exists: not to prevent the bug being written again,
but to prevent the spacing test's coverage being removed without anyone noticing.

⚠️ **THIRD INSTANCE IN TWO BRIEFS OF AN APPARATUS RETURNING A WELL-FORMED WRONG ANSWER, AND THE
FIRST WHERE THE CAUSE IS THE ENVIRONMENT RATHER THAN THE CODE.** The other two were a difference
assertion that could not distinguish superimposition from replacement, and a figure carried from
a neighbouring column. **This one no reading of the code would have caught**, because the code
was correct on the host that read it.

### The fix, and why it is one change with its own verifiability

⭐ **REMOVING THE GUARD IS WHAT MAKES THE FIX TESTABLE.** While the conditional existed, no test
on this machine could see the defect. One code path means a widget test here exercises what
Android runs. **The untestability was a property of the guard, and the fix deletes the guard.**

⛔ **AND THE FOUR LITERALS BECAME ONE CONSTANT — `_kSectionGap`.** Four values that must stay
equal were maintained independently, which is what let one diverge. **A shared constant removes
the class, not just the instance**: a fifth section added later takes the value without anyone
deciding it again.

⚠️ **CONFIRMED RATHER THAN ASSUMED, as the brief required.** With the guard removed, Windows
measures `12.0, 12.0, 12.0, 12.0` and **nothing doubled to 24.0** — the escape clause's named
failure did not occur. Part A's reading that the guarded widget *was* the Windows gap holds.

⛔ **NOT VERIFIED BY A RE-CAPTURED BASELINE, DELIBERATELY.** A baseline records what is and
treats it as correct by definition. Had one been taken while the gap was 0 it would now **guard
the defect** — going red on the fix and silent indefinitely while it was wrong. ⭐ **Baselines
catch regressions; they never catch a thing that was born wrong.**

### B-4 and B-5 — both contained, and they had to be one change

**The containment calls, made before acting.** `_Section` is file-private and `vocabulary_screen`'s
identically-named class is an unrelated data class, so the blast radius is `help_screen.dart`
alone — 7 instantiations, exactly 1 with `children: []`. **Neither fix needs a new widget type, an
API change, or a screen restructure.** Both are changes inside `_SectionState.build`.

**B-4 — the headers had no role.** Measured: all five announced as bare `[tappable]`; zero
headers among them; the only `HEADER` on the screen was the app-bar title. Five tappable regions
with no heading structure to navigate by, in a medical app.

**B-5 — a chevron that revealed nothing.** The Windows replacement section is declared
`children: []`, so tapping its header added **18.0 of empty padding** and flipped the glyph with
no content appearing. ⛔ **A control that reveals nothing is worse than no control: a user cannot
tell whether the content is missing or the feature is absent** — the exact failure the
replacement-section pattern exists to prevent.

⭐ **WHY THEY ARE ONE CHANGE AND NOT TWO.** The role depends on whether the thing IS a control.
Announcing `button: true` on a section that does not expand would be **the same lie B-5 removes,
told to a screen reader instead of to the eye.** One predicate, `_expandable`, drives the
chevron, the tap handler and the semantics together.

⚠️ **THE REPLACEMENT-SECTION PATTERN IS UNTOUCHED.** B-5 changed how it presents, never whether
it exists; its content is still visible and still says *"Not available on Windows"*, asserted by
a control in the test.

### B-6 — the passes, dated and with their instrument named

**MEASURED 20 September 2026.** These are the findings most likely to be assumed still true in
six months, so the date and the instrument are part of the record.

| measured | figure | instrument |
|---|---|---|
| header touch target height | **50.0**, all five, identical | widget test, logical px |
| header text and expand icon | **`#447598` on `#FFFFFF` = 4.95:1** | computed from the theme tokens |
| overflow, {1.0x, 2.0x} x {375, 800}, collapsed | **0**, 29 paragraphs, 0 errors | widget test, `FlutterError.onError` intercept |
| overflow, same grid, one section expanded | **0**, 44 paragraphs, 0 errors | as above; at 2.0x/375 the expanded section reaches 4436.0 tall and still does not overflow |
| focus traversal order | **matches visual order** | semantics tree walk |

⚠️ **The contrast figure is one colour doing two jobs**: the header text and the chevron are both
`onSurfaceMuted`. It clears 4.5 for text and 3.0 for the icon, so both pass — **on the same
number**, which means a future change to that token moves both at once.

### B-7 — deferred, with an expiry date on the absence

⛔ **DEFERRED, RECORDED 20 September 2026 so the absence has a date rather than being silent:**
a sweep enumerating **every platform conditional in `lib/`**, stating for each whether any test
can actually see it.

⭐ **THE REACH IS BEYOND HELP, AND MER IS DELIBERATELY PLATFORM-DIVERGENT.** iOS notifications
are native Swift and the iOS capture path posts facts to an inbox rather than passing through the
Dart write path; Windows has no notification path at all; the Android quick-log runs in a
background isolate. **Every one of those branches is invisible to a test on a single host.**

⚠️ **RECORDED NOW SPECIFICALLY SO THAT "we have tests for that" IS NOT LATER READ AS "that branch
is covered".** The Help gap is the proof that those two sentences can both be true of a screen
and still leave a defect shipping.

### The sort, for the record

**Shipped in this release:** the spacing (a value change), the shared constant, the header
semantics, the Windows chevron. **Recorded as dated passes:** touch targets, contrast, overflow,
traversal order. **Deferred:** the platform-conditional sweep.

⭐ **NOTHING SORTED TO THE DEFERRED HELP ACCESSIBILITY AUDIT.** Nothing here required a statement
about what the app does, new or changed copy, or a restructure — **the triage line held without
needing to be softened**, and the audit keeps its claims register and its scope intact.

---

## iOS — two end surfaces, two authentication policies, and one wrong finding — 21 September 2026

### What was asked, and what it settled

**Does the recorded duration include time spent unlocking?** Traced on both platforms rather than
reasoned from the wording.

    ANDROID   _handleEnd()          endTime = DateTime.now(), captured in the background isolate
              ActionType.SilentAction — no app launch, NO AUTHENTICATION
              => no unlock occurs, so no unlock latency can enter the interval

    iOS       handleQuickLogEnd()   endTime = Date(), captured in the delegate callback
              UNNotificationAction options: [.authenticationRequired]
              => the action does not fire until unlocked, so the unlock IS in the interval

⭐ **Both platforms compute `end − start` and both capture the end at the moment the action
fires.** The difference is entirely in what GATES the action. **Help's platform-split wording is
therefore correct**, and the Android paragraph is not missing a true caveat — the caveat does not
apply to it.

### 🔴 THE FINDING I FIRST REPORTED WAS WRONG, AND THE CORRECTION MATTERS MORE THAN THE FINDING

**I reported that the Live Activity ends without an unlock and that the two iOS surfaces
therefore produce different durations.** ⛔ **That is false on iOS 17+**, and the sentence
refuting it sits **twelve lines above** the line I quoted:

> *"On iOS 17+ ActivityKit already refuses to run EndMEREventIntent on a locked device and demands
> Face ID, **ignoring the `.alwaysAllowed` policy the intent requests**."*

⭐ **I READ A DECLARATION AND REPORTED IT AS BEHAVIOUR.** `EndMEREventIntent` declares
`.alwaysAllowed`; the platform does not honour it. ⚠️ **This is `WORKING-AGREEMENT.md`'s
*READING IS NOT VERIFYING* failing in precisely the form it is written down to prevent** — *"a
source read is evidence about the source, not about the world"* — and it failed while I was
reading the very file that contained the correction.

⛔ **THE SHAPE, RECORDED BECAUSE IT WILL RECUR: a declared policy is a REQUEST, not a guarantee.**
`options:`, `authenticationPolicy:`, `locked:` and every other platform-facing flag state what the
app asks for. What the OS does with the request is a separate fact, and on iOS it has changed
between versions. **Quote the declaration and the observed behaviour as two different claims, or
do not claim the behaviour.**

⚠️ **Same family as the `locked: true` note already in this corpus** — MER asks for it and
Android 14+ ignores it. **That precedent existed and did not stop this.**

### What is actually established, by tier

    iOS 17+        BOTH surfaces gate on authentication. ActivityKit enforces it on the intent
                   regardless of the declared policy; the notification action declares it.
                   No divergence. The Help caveat is TRUE of both.

    iOS 16.2-16.x  The notification action prompts, by declaration — that is what 956b2d3 was
                   written for. ⛔ WHAT 16.x ActivityKit DOES WITH `.alwaysAllowed` IS NOT
                   ESTABLISHED. The rationale comment does not say, and it cannot be determined
                   from the Windows CLI host.

🔴 **SO THE DIVERGENCE IS POSSIBLE ONLY ON 16.2-16.x AND IS UNVERIFIED THERE.** ⚠️ **Recorded as
UNKNOWN rather than as absent** — and the date is the date it was checked, 21 September 2026, not
the date the code was written.

> ### ⭐ CLOSED — INAPPLICABLE, NOT UNKNOWN. 21 September 2026, later the same day.
>
> ⛔ **THE PARAGRAPH ABOVE IS SUPERSEDED AND IS ANNOTATED, NOT REWRITTEN.** It was right that the
> question was open and right to refuse to close it on a guess. **It was settled by reading, not
> by a device**, and the deployment target is what made that possible.
>
> **ON 16.2-16.7 THE LIVE ACTIVITY HAS NO END CONTROL AT ALL.** Three gates, none with a
> fallback branch:
>
>     EndMEREventIntent.swift:95   @available(iOS 17.0, *)
>                                  extension EndMEREventIntent: LiveActivityIntent {}
>     MERLiveActivity.swift:45     if #available(iOS 17.0, *) { Button(intent:) ... }   NO else
>     MERLiveActivity.swift:163    if #available(iOS 17.0, *) { Button(intent:) ... }   NO else
>
> ⭐ **`LiveActivityIntent` conformance is 17+ ONLY**, so below 17 nothing in a Live Activity can
> invoke the intent — and both places the widget would draw an end control are gated with no
> 16.x branch. **What renders on 16.x is the timer, "Event in progress", "Started" and the start
> time. Display only.**
>
> ⛔ **SO ON 16.x THERE IS ONE END SURFACE, NOT TWO, AND TWO SURFACES CANNOT DIVERGE WHERE ONLY
> ONE EXISTS.** The notification is the sole end path on that tier — which is also why
> `956b2d3`'s silent-failure fix was described as landing on *"the only end path this tier has"*.
> **That phrase was in the corpus the whole time and is exactly this fact, stated from the other
> direction.**
>
> ⚠️ **AND THE CONTROL CAUGHT A DEAD APPARATUS BEFORE THIS WAS REPORTED.** The first detector
> counted braces per LINE, so `} else {` netted to zero, the block boundary was never seen, and
> it could only ever answer *"no fallback"*. **It returned the right answer for the wrong
> reason.** Injecting an `else` into a scratch copy and watching the detector fail to notice it
> is what exposed that; the rewritten character-wise walk reports `else present` for the injected
> case and `NONE` for the four real ones. ⭐ **A null that happens to be true is still worthless
> until the apparatus is shown capable of the other answer** — and here the true answer and the
> broken answer were the same string.
>
> ⚠️ **WHAT IS NOT CLOSED: the deployment target is `16.2` (`ios/Podfile:2`, and six
> `IPHONEOS_DEPLOYMENT_TARGET = 16.2` across two targets × three configs), so 16.2-16.7 devices
> DO exist in the user base.** They are unaffected by the divergence because they have one end
> surface — **not because there are no users on that tier.**
>
> ⛔ **NO PROCUREMENT IS NEEDED. A 16.x device would have answered a question the source already
> answered**, and the earlier entry's closing line — that settling it needs hardware — is
> withdrawn. ⚠️ **A Mac with Xcode IS available to the developer**, so iOS builds, simulator runs
> and Xcode reads are possible; the earlier assumption that none existed was wrong and is
> corrected here rather than left standing.

### The two policies were set in different passes, by different reasoning

    .alwaysAllowed            4 May 2026   17a0a4b  "CR-42: Live Activity + lock-screen
                                                     consecutive notification actions"
                                                     NO comment beside it
    .authenticationRequired  24 Aug 2026   956b2d3  "iOS 16.2-16.x: make the End action prompt
                                                     instead of failing silently"
                                                     34 lines of stated rationale

⭐ **Sixteen weeks apart, for different problems, and never set against each other.** That is why
they read as an inconsistency now. **The August pass is the one that READ the May declaration**
and concluded it does not do what it says on 17+.

### ⛔ Privacy does not justify the gate, and the gate does not provide it

**Everything the end surfaces expose on a locked screen, enumerated:**

    persistent notification   "Medical Event Recorder" / "Long-press this notification to log an event"
    active notification       "Event in progress · {startTime}" / "Tap \"Event Ended\" when the event is over"
    end confirmation          "Event ended · {elapsed}" / "Open MER to add details"
    Live Activity             "Event in progress", "Started" + start time, a running timer

**No event detail appears anywhere** — no type, no severity, no notes, no observations, no
history. ⛔ **And `.authenticationRequired` gates PERFORMING the action, never DISPLAYING the
notification.** The banner and the elapsed time are on the lock screen before any authentication
and would stay there whatever the option is. ⭐ **Anything a bystander could learn, they can learn
without touching the button.** The rationale never claimed privacy as a reason, and it was right
not to.

### 🔴 THE OPTION THAT LOOKS OBVIOUS IS THE ONE THAT RESTORES A DATA-LOSS DEFECT

**Setting the notification End action to `options: []` — to match the intent — is not a neutral
alternative. It is the PRIOR STATE**, and the comment records what it did:

> *"ending from a locked device did nothing at all, silently: the notification was dismissed by
> the UI, the handler never ran, no end instruction was written, neither notification posted, the
> Live Activity kept counting, and the record kept its `lt1` default. **Wrong data, on the only
> end path this tier has.**"*

⛔ **A user ends an event from the lock screen, watches the notification disappear, and the record
silently keeps a default duration.** In a capture tool that is the worst class available, and
`956b2d3` exists to fix exactly it.

⚠️ **AND IT WOULD NOT EVEN CONVERGE THE SURFACES.** On 17+ the intent still demands Face ID, so
the notification would skip the unlock while the Live Activity enforced it — **inverting the
divergence rather than closing it.**

⭐ **THE GENERAL FORM, AND IT IS THE REASON THIS ENTRY IS LONG: an inconsistency between two
declarations is not evidence that either is wrong.** Here the inconsistency is real, the
declarations genuinely disagree, and **the correct action is to change neither** — because one is
already overridden by the platform and the other is load-bearing against a defect. **A tidy-up
reasoned from the declarations alone would have shipped the bug back.**

### Help's wording, and what is left open

⚠️ **Help tells iOS users the two surfaces are interchangeable** — *"tap 'Event Ended' on the
timer or on the MER notification, whichever your iPhone shows"* — and four rows later carries the
unlock caveat. **On 17+ that is accurate**, because both gate. **On 16.x it is unverified.**

⛔ **NO WORDING WAS CHANGED, AND NO OPTION VALUE WAS CHANGED.** This entry settles a premise; the
wording question exists only after it, and rests on a 16.x fact that needs a Mac, an iPhone and a
16.x tier to establish. **None is available from this machine.**

---

## Rule (h)'s residual gaps — ACCEPTED, not closed — 21 September 2026

⭐ **Rule (h) closes the part of the cross-machine gap a repository can close. These four it does
not, and each is recorded as ACCEPTED WITH ITS REASON rather than left as an open item**, because
an open item with no owner and no route to closure is a gap pretending to be a plan.

### 1 · A pushed row with no build still spends the code

⛔ **A host that writes and pushes a ledger row and then does not build holds a code the ledger
shows as spent.** The amendment of 21 September makes the push the allocation, which is what
closes the collision window — and the cost of that choice is this: **allocation can now happen
without a build ever following it.**

⭐ **ACCEPTED, AND IRREDUCIBLE WITHOUT A SHARED SERVICE.** Closing it needs something both hosts
can ask *"is this code actually spent?"* in one round trip, which a git-tracked markdown file is
not. ⚠️ **The failure it replaces was worse and more likely**: two hosts silently taking the same
code, which is what the reversal removes. **A code lost to an abandoned row costs one integer; a
code used twice costs the ability to tell two builds apart, and that has already happened three
times with code 53.**

### 2 · Global `~/.claude/CLAUDE.md` drift is undetectable from inside either machine

⛔ **Each machine holds its own copy, in no repository, and nothing compares them.** A rule
present on Windows and absent on the Mac — or present in two different versions — produces two
sessions that both believe they are following the standing rules.

⭐ **ACCEPTED BECAUSE (h) IS WRITTEN NOT TO DEPEND ON IT.** That was the drafting constraint and
it is what makes this survivable: the cross-machine rule lives in the repository, reaches every
clone by the mechanism the work itself uses, and cites the global file without relying on it.
⚠️ **The drift is real and remains invisible. What has been removed is its ability to matter to
(h).**

### 3 · Which machine made a past commit is not knowable from git

⛔ **Author is a `git config` value** — set per-clone, surviving being copied, validated by
nothing. **And the `STATUS.md` session labels are a hand-written convention with no detector**: a
session can omit one, or write the wrong one, and nothing objects.

⭐ **ACCEPTED, BECAUSE (h) DOES NOT ASK THE QUESTION.** The rule routes through the FILE'S OWN
HISTORY — fetch, then `git log` that file — and what that answers is **whether the file moved**,
which is the fact the edit actually turns on. ⛔ **Who moved it is a different question and (h)
needs no answer to it.** ⚠️ **The provenance gap stays open and stops being load-bearing**, which
is the most a repository can do about a value nothing validates.

### 4 · Whether (h) was followed has no detector in the repository

⛔ **Nothing checks it.** No test, no hook, no scan — a session that skips every clause of (h)
proceeds exactly as one that follows it, and the file says so in its own text.

⭐ **THE DETECTOR IS EXTERNAL, AND DELIBERATELY SO: the chat side requires the platform, the
current `HEAD` and whether `HEAD` matches `origin` at the top of every report, and treats their
ABSENCE as a finding.** ⚠️ **That is the same shape as rule (f) and it is the reason (f) works —
the remedy sits on the side that is not the one failing.** A repository check would be run by the
session it is checking; a reporting requirement is enforced by the party reading the report.

⛔ **RECORDED AS A LIMIT OF THIS REPOSITORY, NOT AS A SOLVED PROBLEM.** A clone that never reports
to chat has no detector at all. **(h) remains a convention, and the honest claim is that it moved
from ABSENT to STATED, with its check living outside the artefact that states it.**


---

## Brief 68 Part C — the channel catches, and a class about contract wording — 21 September 2026

### What changed

⛔ **Three `_navChannel` call sites had bare `catch (_) {}`**, so a failure on
`au.com.notiva.mer/navigation` was indistinguishable from success on every platform. The channel is
registered in `ios/Runner/AppDelegate.swift` and nowhere else — `MainActivity.kt` is a bare
`FlutterActivity`, `windows/runner` registers nothing — so off iOS every call throws
`MissingPluginException`, and the catch made that look exactly like a working call.

**The fix is NOT a platform guard around the call**, and that distinction is the whole design:

> ⭐ **The platform check moved from *should we call* to *is this failure expected*.**

A guard stopping the call off iOS would also stop **iOS** ever reporting a handler that had gone
missing — a channel or method rename on the Swift side, after which the call silently becomes a
no-op and every test stays green. That is the failure with no other detector, so it is the one the
design protects. `shouldReportNavChannelFailure` in `ios_capture_bridge.dart` now carries the table;
both call sites and a third route through `reportNavChannelFailure` into the existing
`reportCaptureChannelError`. **No second reporting path.**

⚠️ **THE THIRD SITE WAS NOT ON THE BRIEF'S LIST.** The brief named `:374` and `:881`.
`getShowPreviewsSetting` at `:449` had the identical shape, and is the **worse** instance: it sits
inside `if (Platform.isIOS)`, so it only ever ran on the row where everything is meant to be
reported, absorbing any failure into the `previewsAlways = true` default. **Found by deriving the
scope from the artefact rather than from the list** — the same discipline that has now produced a
finding on four consecutive briefs.

### ⛔ THE CLASS — TWO FACTS THAT HOLD FOR DIFFERENT REASONS NEED TWO STATEMENTS

**Recorded 21 September 2026.**

> ⭐ **One sentence covering both will be checked against the mechanism it describes, and will PASS
> while the other silently fails.**

**The instance.** `:881`'s missing reschedule off iOS is harmless because Android's two notification
shapes are save-independent. The proposed contract wording was one sentence:

> *"the Android standing notification's content must remain independent of saved event data"*

**It covers `_showNormal` — whose content is CONSTANT — and would be read as not applying to
`_showActive`**, whose content visibly interpolates `'Event in progress · ${_fmtTime(start)}'`. A
reader checking `_showActive` against that sentence finds the sentence does not appear to be about
them, and moves on. **`_showActive` is save-independent for a different reason: its one variable
comes from the `mer_active_event` marker, never from an `EventRecord`.**

⛔ **So the failure mode is not that the sentence is wrong. It is that the sentence is TRUE, and
verifying it confirms the mechanism it names while telling you nothing about the one it does not.**
A check that passes is read as a check that covered.

⭐ **THE TELL: the two facts have the same CONSEQUENCE and different CAUSES.** Where a single
statement is reached by generalising over outcomes — *"neither one changes, so neither matters"* —
it will describe whichever cause was in mind when it was written. **Write one statement per
mechanism, and name the mechanism in each.** Recorded as contracts `#20` and `#21` and note K, two
rows where one would have read as sufficient.

⚠️ **Same family as the declared-scope class and the closed-list-versus-rule class in the workspace
rules — a correct statement whose coverage is narrower than the reader's use of it.** The difference
worth keeping: those fail when the CORPUS grows. **This one fails immediately, on a corpus of two,
and still reads as complete.**

### ⚠️ AN OBSERVATION — source-level only, NOT this release's work

**Recorded 21 September 2026. Not reached on a device; established by reading the source only.**

⛔ **Nothing excludes an in-progress record from being edited.** `_openDetails` routes any record to
the wizard or `_openLogScreen` with no active-event check, and `_activeEvent` is used only for a
banner (`home_screen.dart:1428`, `:1442`). So editing a running event leaves the notification title
showing the **marker** time, because `_showActive` reads `mer_active_event` and not the record.

**BOTH READINGS ARE RECORDED, because the two are not distinguishable from the code and the choice
between them is a product question, not an engineering one:**

1. ⭐ **They are two different facts and the display is correct.** The notification reports **when
   the event's capture STARTED**; the record reports **when the event is said to have OCCURRED**. A
   user who corrects the occurred-at time has not changed when they pressed start, and the
   notification would be wrong to follow it.
2. ⚠️ **A user sees two times for one event and cannot tell which is which.** Nothing on either
   surface labels the distinction, so the two readings are indistinguishable to the person looking
   at them — which makes reading 1 true and unhelpful at the same time.

⛔ **`#22` does not change this either way, and that is stated so a later reader does not treat the
fix as having addressed it:** a reschedule re-reads the same marker and redraws the same string.

🔴 **Left OPEN. Not a defect claim, not closed by inference, and not in this release.**

### Still open, dated

🔴 **Whether the Swift `restoreNotification` handler can fail in practice — UNESTABLISHED, 21
September 2026, needs the Mac.** ⭐ **Not a blocker: the point of `#22` is that if it ever does
fail, something says so.**
