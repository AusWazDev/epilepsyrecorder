# MER — First-Run Walkthrough

Specification. **Not built.**

**Rewritten 27 August 2026, from scratch rather than amended.** The previous version was
written on 24 August, corrected inline by a feasibility read the same day, and amended again
on 26 August by appending. Every layer was individually right and the accumulated result had
drifted: its most emphatic correction had been overtaken by work that shipped, and still read
as a live instruction.

> ⚠️ **THE REWRITE IS THE POINT, AND THE REASON IS RECORDED HERE SO IT IS NOT UNDONE.**
> The old spec's corrections were written as **conditionals on future work** — *"this resolves
> when nullable duration lands"*, *"revise when History and the export land"*. Those conditions
> are now satisfied. **A satisfied conditional left in place reads as a standing instruction**:
> step 1 forbade copy the app had since earned.
>
> This is the same failure as the Getting Started card, and as the nine Help defects — text
> that was right when written, never re-read, and now actively misleading. **Amending this
> document by appending is how it happens again.** If a step's screen changes, rewrite the
> step.

**Verified against the running app on 27 August 2026** — `home_screen.dart`,
`history_screen.dart`, `event_wizard_screen.dart`, `help_screen.dart`,
`notification_service.dart`, `your_data_screen.dart`, `constants.dart`. Claims below that
cite a file were checked against it; claims about what a screen *looks like* were checked on
the Teclast P30.

---

## Why it exists

MER's difficulty is not complexity. It is that **the best feature is invisible.**

The notification capture path — one tap from a locked phone, no app, no unlock — is what makes
the app worth using during an event. Nothing tells a new user it exists.

**A second reason has since become as strong as the first.** A quick record now captures a
timestamp and nothing else: no duration, no type, no severity, all NULL meaning *not asked*.
That is the honest design, and it has a cost — **a user who only ever quick-records builds a
history of timestamps and does not find out until they open the export.** Step 5 exists for
that, and it is why this walkthrough is five steps rather than four.

**And a third, specific to a medical diary: learning by exploring creates junk records.**
Someone tapping around to see what happens ends up with fake events, each indistinguishable
from a real seizure until read. A walkthrough that *shows* removes the need to explore.

> ⚠️ **That hazard got worse, not better.** A junk record created today is blank rather than
> claiming "< 1 minute", so it looks exactly like a real deferred capture. It is now harder to
> spot, not easier.

---

## Trigger

**Disclaimer → walkthrough → app.** First launch only.

Before any record can be created, deliberately. The alternative — after the first event —
would turn instruction into reinforcement, which is better pedagogy but arrives after the junk
records have been made.

**Skip visible from step one.** Not buried, not on the last step.

**Re-runnable from Help**, one row under *Getting help* (`help_screen.dart:425`). One entry
point only — not About, not Your data.

**Never gates anything.** Force-quitting mid-walkthrough lands the user in a working app, not
back at step one. Same rule as everything else near the capture path.

> ⛔ **UNRESOLVED, AND IT MUST BE DECIDED BEFORE BUILDING.** The disclaimer gate is
> `acceptedVersion == kDisclaimerVersion` (`constants.dart:11`, currently `'1.1'`), so
> **bumping that string sends every existing user back through the disclaimer.** "First launch
> only" does not say what happens then.
>
> **The flag that records "walkthrough seen" must be independent of the disclaimer version.**
> Re-running a five-step introduction for a user with two years of history would be wrong.
> Carried forward from the previous spec unresolved, and still unresolved.

---

## The steps

**Five.** Each **shows** — do not invite the user to try anything, or the walkthrough causes
the problem it exists to avoid.

> **Why five and not four.** Steps 1 and 5 are two halves of one fact: a quick record captures
> a time, and the guided flow is where the rest goes. Splitting them across "learn it now" and
> "discover it later" would mean **step 1 tells someone their record needs completing and
> nothing tells them what to do about it.**

---

### 1. Record an event the moment it happens

> The red **Record Event** button saves the time instantly. One tap — nothing to choose,
> nothing to type.
>
> That is all it saves: **the time it happened, and nothing guessed.**
>
> The rest — how long it lasted, what it was, how it felt — you add when things are calmer.

**Rationale.** Leads with the primary action and with permission to defer detail, which is the
app's core proposition and the thing users do not expect.

⚠️ **THE PROMISE CHANGED, AND THE COPY MUST CHANGE WITH IT.** "Add the details later" was a
**convenience** when the fields carried defaults. It is now **the only way those fields ever
get a value.** `home_screen.dart` writes `duration: null` and leaves `eventType` and
`severity` unset; `detailsCompleted: false` marks it a partial.

**Three constraints on whoever writes the final copy:**

1. **"nothing to choose, nothing to type" describes the INTERACTION only.** The previous
   spec's *"nothing to fill in"* was true of the tap and misleading about the record. The next
   line makes the claim about the record explicitly, and separately.
2. **"nothing guessed" is a virtue, not a gap.** It is what separates MER from an app that
   writes "< 1 minute" and means nothing by it. Do not soften it into an apology.
3. **No word may imply deficiency.** Not *incomplete*, not *unfinished*, not *missing*, not
   *you should*. Tapping a button during a seizure and filling the rest in afterwards **is the
   app working as intended.** The record is described, never judged.

*"when things are calmer" carries the reason, and does the work a warning would otherwise do.*

**Names three fields concretely** rather than "the details", so step 5 has something specific
to pick up.

---

### 2. You do not need to open the app

> MER keeps a notification available at all times, so you can start an event without unlocking
> or opening anything.
>
> *(platform-specific instruction row — see below)*

**This is the most important step.** It is the feature nobody discovers.

⚠️ **THE INSTRUCTIONS ARE OPPOSITE ON iOS AND ANDROID AND BOTH ARE CORRECT.**

| | |
|---|---|
| **iOS** | Long-press the MER notification to reveal the action button, then tap **"Log Event Now"** |
| **Android** | Find the MER notification and tap **"Log Event Now"** |

iOS needs the long-press to reveal the action; Android shows it directly.

⛔ **DO NOT UNIFY THEM AND DO NOT WRITE ONE FROM THE OTHER.** The Android build shipped the
wrong one until CR-43. **Take both strings from Help** (`help_screen.dart:316` and `:322`),
which is correct today — re-deriving them is exactly what shipped the defect.

**Starting works on every platform. Ending does not.**

- **iOS 17+** — iOS refuses to run `EndMEREventIntent` on a locked device and demands
  authentication. Ending works, but only after unlocking.
- **iOS 16.2–16.x** — a locked device does not deliver the end action at all. A known
  limitation on a shipping tier, unresolved.
- **Android** — both actions are `SilentAction` and fire without unlocking. Ending from a
  locked device genuinely works.

Help states this in an iOS-only row: *"Ending an event needs your phone unlocked."* **The
walkthrough must not contradict it.**

⚠️ **Windows has no notification path.** `NotificationService.init()` returns at its first line
on Windows and iOS (`notification_service.dart:71`), and no channel is ever created on
Windows. **Skip this step there** rather than describing something absent — see *Platform
counts* below.

> **Two iOS conditions this step depends on and must not overstate.**
>
> 1. **Show Previews.** Starting from the lock screen without a password depends on Show
>    Previews being "Always". That claim is marked *believed, not tested* in the device-test
>    checklist §2 — its only source is the app's own prose, and the action is registered
>    `options: []`, so the app does not decide it. **The walkthrough must not assert the
>    outcome more confidently than Help does.**
> 2. **Notification permission.** If notifications are denied, this step describes something
>    unavailable. See *Open questions*.

---

### 3. Your history, and what to bring to an appointment

> Every event is listed in **History**, grouped by day. Use the filter icon at the top to
> narrow the list — by date, by type, or to the events that still need details.
>
> **What you see is what you export.** A number on the icon means a filter is on.

⚠️ **THE FILTER ICON MUST BE TAUGHT, AND THIS IS THE STEP'S REAL JOB.**

The filter chips and the referral toggle are gone. Search, event type, date range, referral
and **Needs details** now live in a sheet behind an AppBar icon, with a badge showing how many
filters are on.

**Discoverability moved from the UI into the documentation.** A user used to find the filters
by looking at them; nothing on the screen now says filtering exists. Help gained a row for it
the same day — but **Help is where someone goes with a question they already have.** The
walkthrough is the only place a first-time user meets a control they do not yet know to ask
about.

**Step 3 must say, at minimum:**

- filtering exists, and it is behind the icon at the top of History;
- the badge on that icon is how you know a filter is still on;
- **a filtered list means a filtered export.**

⛔ **THE THIRD IS THE ONE TO GET RIGHT.** The hazard the redesign introduced is a user who
forgets a filter is on, exports a partial history, and sends an incomplete record to a
specialist. The badge and the red banner are the app's defences; **this step is where a new
user learns to read them.** Do not reduce it to "you can filter your history".

> **Deliberately NOT led with search**, which is a change from the previous spec's *"searchable
> and filterable"*. **Search is a box a user recognises; filtering is invisible.** Naming both
> equally dilutes the one that needs teaching.
>
> ⚠️ **And search currently has a defect the walkthrough must not inherit.** The hint reads
> `Search notes, feelings, severity, triggers…` (`history_screen.dart:436`), naming two fields
> that no longer exist under those names — they are **observations** and **beforehand**, the
> latter renamed precisely because "triggers" asserts causation. **Fix the hint before writing
> copy that describes it.** A separate, live defect; not blocked on this document.

*Also true and not worth a sentence in the walkthrough: a digits-only search is intercepted by
a duration comparison rather than searching text. "Searchable" is true and has a sharp edge.*

---

### 4. It is on this device, and only here

> There is no account and no cloud copy. Notiva never receives your events and cannot recover
> them.
>
> **A backup file is the only copy you control.** Take one, and keep it somewhere else.

**Rationale.** The safety point, and the one a user most needs early rather than after losing a
phone. **Ending on it leaves the strongest impression of what the app is** — which is why this
step stays fourth of five rather than being displaced by the completion loop.

**Verified 27 August 2026.** No backend, no account, no sync. Three existing texts agree and
**the copy should be taken from them rather than drafted fresh:**

    help_screen.dart:250   'There is no account, no cloud copy, and no server.
                            Notiva never receives your events and cannot recover them for you.'
    help_screen.dart:290   'A backup file is the only copy you control'
    your_data_screen.dart  'A file you have saved somewhere else is the only copy that
                            survives losing this phone.'

**The `your_data_screen` line is the sharpest of the three.**

⚠️ **"Only copy you control" is precise and must stay precise.** Help also states events are
included in a normal device backup — so it is the only copy **you** control, not the only copy
that exists.

---

### 5. Finishing a record

> A quick record saves the time and nothing else. When you are ready, **"Edit details"** on the
> home screen walks you through the rest — one question at a time, and you can stop at any
> point.
>
> Anything you have entered is kept, whether you finish or not.

**This step closes the loop step 1 opens**, and it is the reason the walkthrough is five steps.

**Why "Edit details" and not the Needs details queue.** The Last Event card is on the home
screen the moment a user records anything, and its **Edit details** button routes through
`wantsWizard` (`home_screen.dart:512`) — so an incomplete record opens the guided flow
directly. That is the shortest true path from "I tapped the red button" to "the rest is filled
in".

**Why the queue is excluded.** A first-run user has **no incomplete records — no records at
all.** Teaching a filter for an empty list is teaching something they cannot see. The
mechanism that reaches it is taught in step 3; the specific use is discovered when there is
something to discover.

**Two claims this step must make and must get right:**

1. **"one question at a time, and you can stop at any point."** The wizard has four steps and a
   summary, every step skippable.
2. **"Anything you have entered is kept, whether you finish or not."** True — backing out
   captures a partial. **This is what makes stopping safe to offer**, and it is the sentence
   that prevents a user treating the flow as all-or-nothing.

> **Do not name the wizard's four steps.** The step teaches that a route exists and is safe to
> abandon; enumerating it turns a reassurance into a specification, and the steps have already
> moved once.

---

## Platform counts

| Platform | Steps | Why |
|---|---|---|
| Android | **5** | All apply |
| iOS | **5** | All apply; step 2 uses the iOS instruction and the ending caveat |
| Windows | **4** | Step 2 is skipped — no notification path exists |

⚠️ **State this as a rule, not a number.** The previous spec said "four steps become three",
which was a count of the arrangement at the time. **Skip step 2 on Windows; the count follows.**

---

## What it must not do

- **Not interactive.** No "try tapping Record Event now" — that creates the junk record the
  walkthrough exists to prevent. **More necessary than before**, because such a record is now
  blank and indistinguishable from a real deferred capture.
- **No claim about what the app records beyond what the model supports.** Audit against the
  capture model, not against this document.
- **Not a substitute for the disclaimer.** It comes after, and must not restate or soften it.
- **No progress gate.** Skip works from step one; back works from every step after the first.
- **Nothing that requires a network.**

> **The rule stands; its old justification was wrong and is not repeated.** The previous spec
> said *"MER has none"*. MER does make network calls — `main.dart` configures Sentry with a DSN
> and `tracesSampleRate = 0.1`. What is true is that **no event data leaves the device**:
> `sendDefaultPii = false`, and nothing in the capture or storage path transmits records.

---

## What stays out — considered and excluded

**Recorded so it is not re-litigated.** Each was weighed for a first-run walkthrough and left
out for a stated reason.

| Excluded | Why |
|---|---|
| **The Needs details queue** | Empty on first run. Step 3 teaches the mechanism that reaches it |
| **User-defined event types, and hiding one** | Discovered when needed. There is no hide affordance yet either |
| **Rescue medication fields** | Three optional fields inside a step the walkthrough does not enter |
| **Restore** | The backup half is taught. Restore is used once, under stress — Help is the right place |
| **Duration as minutes and seconds** | Self-evident on screen, with its own hint. Step 1 says "how long it lasted"; the mechanics are Help's |
| **Search** | See step 3. Recognisable without teaching, and naming it dilutes the filter icon, which is not |
| **The CSV's shape, and the `.v3` filename marker** | Step 3 says "export". Nobody needs the schema on day one |
| **Editing and deleting a record** | Ordinary list behaviour with visible affordances |
| **The wizard's four step names** | See step 5. A reassurance, not a specification |

---

## What goes away

**The Getting Started card on the home screen** — `home_screen.dart:929`, rendered
`if (_loaded && _records.isEmpty)`.

**Remove it when the walkthrough lands.** Otherwise the same facts live in three places —
walkthrough, Help, card — and the drift is worse than before. **One source of truth per job:
the walkthrough introduces, Help answers questions.**

⚠️ **It is still there and still stale, and the staleness has itself drifted since the last
audit.** Verified row by row on 27 August 2026:

| Card row | State |
|---|---|
| *Quick record* | **A truncated prefix of Help's row.** It drops *"nothing else is recorded and nothing is guessed. Add the details whenever you are ready…"* — exactly the half the nullable work added. The card now says **less** than Help |
| *Record with details* | Enumerates four fields for a button that opens a **four-step wizard**. Help deliberately stopped enumerating |
| *History & export* | ⋮ → History is correct. The **export** half is stale — it moved behind *Your data*. It also misses "All history" on the Last Event card, which Help now names first |

⛔ **"The card points at a ⋮ menu that does not exist" is FALSE and has now been asserted three
times.** The ⋮ menu is the AppBar `PopupMenuButton` and it exists — History, Your data, About,
Help. **What is stale is where export lives, not the menu.** Recorded here in the hope of
retiring the claim.

⚠️ **AND THE PART THAT MATTERS MOST: the card renders only when there are no records.** A
device with history never shows it. **Every one of these defects is invisible to the developer
and lands exclusively on a first-time user — the walkthrough's exact audience.**

> **If the walkthrough is not built soon, remove or fix the card on its own merits.** It
> currently says less than Help and contradicts it on two rows of three.

---

## Open questions

- **What marks the walkthrough as seen, and where does it live?** Must be independent of
  `disclaimerAcceptedVersion`. See *Trigger*. **Decide before building.**
- **First launch after a restore.** A user moving to a new phone reaches first launch **with a
  full history**. The walkthrough would introduce an app they already know, and step 4's advice
  is redundant to someone who just used a backup. Decide whether a non-zero record count
  suppresses it. *Note this is the same condition the Getting Started card already uses.*
- **Visual treatment.** Full-screen pages with a pager, or a sheet? Full-screen suits five
  steps and reads as deliberate; a sheet is lighter but feels dismissible in a way the
  data-safety step should not.
- **Text scaling and accessibility.** Five full-screen pages of fixed copy is the layout most
  likely to break at large accessibility text sizes. **Nothing else in the app is full-screen
  fixed copy**, so there is no existing pattern to inherit.
- **Should the walkthrough know the notification permission state?** If notifications are
  denied, step 2 describes something unavailable. The Help status band already surfaces this.
- **The Windows re-run entry point.** `GETTING HELP` renders on Windows, so a replay row there
  offers the four-step version. Fine — but state it rather than leaving it to fall out of a
  platform conditional.
- **Does step 4 offer to take a backup there and then?** The one action worth offering — but a
  new user has nothing to back up, so it would be an empty file. Probably better as a prompt
  the first time they have real data, which the backup reminder banner already does.

---

## ⛔ Nothing in this document is testable, and that is the defect that produced it

No test asserts that walkthrough copy matches Help, or that the platform instructions stay
opposite.

**Hand-syncing is what produced the Getting Started card**, and it is what produced the nine
Help defects: three separate texts describing the same features, drifting independently, with
the one nobody can see being the worst.

`test/checklist_citations_test.dart` already guards the device-test checklist's symbols this
way. **When the walkthrough is built, its copy should be checked against Help's strings rather
than kept in step by hand** — at minimum the platform instruction pair, which has shipped
wrong once already.

---

## Sequencing

**The screens this describes have now landed.** The capture-model changes, the wizard, the
History rebuild, SQLite and the delimited export are all in. The reasons this was deferred no
longer apply.

**Two live defects should be fixed first**, because the walkthrough would otherwise teach
around them:

1. **The search hint** — names *feelings* and *triggers*, which are now *observations* and
   *beforehand*.
2. **The Getting Started card** — fix or remove.

Neither is spec work and neither blocks writing the copy.
