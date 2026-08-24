# MER — First-Run Walkthrough

Specification. **Build last**, after the capture-model changes, the History polish and
SQLite — every screen it describes is due to change, so building it now means writing it
twice.

**Feasibility read completed 24 August 2026** against `home_screen.dart`,
`help_screen.dart`, `notification_service.dart`, `main.dart`, `constants.dart` and the
capture model. Five factual errors were found and are corrected inline, each marked
**CORRECTED**. The original wording is kept alongside so a reader can see what changed and
why.

---

## Corrections from the feasibility read

| # | Original claim | Correction |
|---|---|---|
| 1 | Step 2: "start and **end** an event without unlocking or opening anything" | **False on iOS.** Established on hardware the same day. Ending needs an unlocked device on iOS; on Android it does not. See step 2 |
| 2 | The Getting Started card "references a ⋮ menu on event cards that does not exist" | **Wrong.** The card refers to "the ⋮ menu in the top right", which does exist — the AppBar overflow, `home_screen.dart` `PopupMenuButton`. The stale part is where that menu leads, not the menu |
| 3 | The card "duplicates three Help rows, one verbatim" | **Understated.** One is verbatim, one **contradicts** Help's corrected text, one is stale. Worse than duplication |
| 4 | "Nothing that requires a network. **MER has none**" | **Wrong.** MER makes network calls — Sentry is configured with a DSN and `tracesSampleRate = 0.1` in `main.dart`. It has no network *feature*, and no event data leaves the device (`sendDefaultPii = false`), but it is not networkless |
| 5 | Step 1: "One tap, nothing to fill in" | **True as UX, misleading as data.** `_quickRecord` writes `duration: DurationCategory.lt1` — the record is not blank, it asserts "< 1 minute" from birth |

Verified correct and unchanged: the notification instructions being opposite per platform;
Windows having no notification path; step 3's search and filter claims; step 4's data
statements; and the "one verbatim duplicate" part of the card claim.

---

## Why it exists

MER's difficulty is not complexity. It is that **the best feature is invisible.**

The notification capture path — one tap from a locked phone, no app, no unlock — is what
makes the app worth using during an event. Nothing currently tells a new user it exists.
The Getting Started card tries, and it duplicates Help, drifts out of date, and can only
describe.

And there is a second reason, specific to a medical diary: **learning by exploring creates
junk records.** Someone tapping around to see what happens ends up with fake events in
their history, each indistinguishable from a real seizure until read. A walkthrough that
shows rather than invites removes the need to explore.

---

## Trigger

**Disclaimer → walkthrough → app.** First launch only.

Before any record can be created, deliberately. The alternative — after the first event —
would turn instruction into reinforcement, which is better pedagogy but arrives after the
junk records have been made.

**Skip visible from step one.** Not buried, not on the last step.

**Re-runnable from Help**, one row under *Getting help*. One entry point only — not About,
not Your data.

> **Feasibility note.** That section now exists. `help_screen.dart` gained a `GETTING HELP`
> section on 24 August 2026 as part of the Help restructure; before that there was no
> support contact, version or links anywhere in Help. The re-run row has a home.

**Never gates anything.** Force-quitting mid-walkthrough lands the user in a working app,
not back at step one. Same rule as everything else near the capture path.

> **OMISSION — undefined behaviour.** The disclaimer gate is
> `acceptedVersion == kDisclaimerVersion` (`home_screen.dart`, `constants.dart`), so
> **bumping `kDisclaimerVersion` sends every existing user back through the disclaimer.**
> "First launch only" does not say what happens then. Decide before building: re-run the
> walkthrough for an existing user with a full history would be wrong, so the flag that
> records "walkthrough seen" must be independent of the disclaimer version.

---

## The steps

Four. Each **shows** — do not invite the user to try anything, or the walkthrough causes
the problem it exists to avoid.

### 1. Record an event the moment it happens

> The red **Record Event** button timestamps an event instantly. One tap, nothing to fill
> in.
>
> You can add the details later, when things are calmer.

Rationale: leads with the primary action and with the permission to defer detail — which
is the app's core proposition and the thing users do not expect.

> **CORRECTED — copy hazard, not a wording change yet.** "Nothing to fill in" is true of
> the interaction and misleading about the record. `_quickRecord` creates the event with
> `duration: DurationCategory.lt1`, so a quick-recorded event **claims "< 1 minute" from
> the moment it exists** — it is not neutral-until-edited. In a medical diary that
> distinction matters: an unedited quick record is indistinguishable from a genuine short
> event.
>
> Do not write copy implying the record is blank. This resolves when nullable duration
> lands in the expansion, which is the same change the abandonment divergence waits on —
> after which this step can honestly say the duration is unset until you set it.

### 2. You do not need to open the app

> MER keeps a notification available at all times, so you can start an event without
> unlocking or opening anything.
>
> *(platform-specific instruction row — see below)*

**This is the most important step.** It is the feature nobody discovers.

> **CORRECTED — the original said "start and end an event without unlocking".** That is
> false on iOS and was established on hardware on 24 August 2026:
>
> - **iOS 17+** — iOS refuses to run `EndMEREventIntent` on a locked device and demands
>   authentication. Ending works, but only after unlocking.
> - **iOS 16.2–16.x** — a locked device does not deliver the end action at all. Known
>   limitation on a shipping tier, not resolved.
> - **Android** — both notification actions are `ActionType.SilentAction` and fire without
>   unlocking. Ending from a locked device genuinely works.
>
> So the claim holds for **starting** on every platform, and for **ending** only on
> Android. Help states this correctly in an iOS-only row: *"Ending an event needs your
> phone unlocked."* The walkthrough must not contradict it.

⚠️ **The instruction differs by platform and the two are opposite:**
- iOS: long-press the MER notification, then tap "Log Event Now"
- Android: tap "Log Event Now" on the MER notification

**Do not unify them and do not write one from the other.** The Android build shipped the
wrong one until CR-43.

⚠️ **Windows has no notification path.** Skip this step entirely there rather than
describing something absent. Four steps become three.

> Verified: `NotificationService.init()` returns at its first line on Windows and iOS
> (`if (Platform.isWindows || Platform.isIOS) return;`), and no channel is ever created on
> Windows.

> **OMISSION — two iOS conditions the step depends on and does not mention.**
>
> 1. **Show Previews.** On iOS, starting from the lock screen without a password depends on
>    Show Previews being "Always". That claim is itself marked *believed, not tested* in
>    the device-test checklist §2, because its only source is the app's own prose and the
>    action is registered `options: []`, so the app does not decide it. **The walkthrough
>    must not assert the outcome more confidently than Help does.**
> 2. **Notification permission.** If notifications are denied, this entire step describes
>    something unavailable. Listed under *Open* below, unresolved.

### 3. Your history, and what to bring to an appointment

> Every event is listed in **History**, searchable and filterable. Export what you need as
> a spreadsheet to bring to an appointment.

Kept deliberately thin — History and the export are both due to change. Revise when they
land.

> Verified against `history_screen.dart`: search covers event type, duration, severity,
> feelings, triggers, referral, notes and the formatted date; filters are four type chips
> and a referral toggle; and the History share button exports **only the filtered set**,
> with the sheet header stating the count. One caveat for whoever writes the final copy:
> a digits-only search is intercepted by a duration comparison rather than searching text,
> so "searchable" is true but has a sharp edge.

### 4. It is on this device, and only here

> There is no account and no cloud copy. Notiva never receives your events and cannot
> recover them.
>
> **A backup file is the only copy you control.** Take one, and keep it somewhere else.

Rationale: the safety point, and the one a user most needs early rather than after losing
a phone. Ending on it also leaves the strongest impression of what the app is.

> Verified: no backend, no account, no sync. Consistent with Help's *Your data* rows, which
> are the best-written content in the app and should be the source for this copy rather
> than a fresh draft. Note that Help also states events are included in a normal device
> backup, so "only copy you control" is precise: it is the only copy **you** control, not
> the only copy that exists.

---

## What it must not do

- **Not interactive.** No "try tapping Record Event now" — that creates the junk record
  the walkthrough exists to prevent
- **No claim about what the app records** beyond what the model supports. Audit against
  the capture model
- **Not a substitute for the disclaimer.** It comes after, and it must not restate or
  soften it
- **No progress gate.** Skip works from step one; back works from every step after the
  first
- **Nothing that requires a network.**

> **CORRECTED.** The original read "Nothing that requires a network. **MER has none.**" MER
> does make network calls: `main.dart` configures Sentry with a DSN and
> `tracesSampleRate = 0.1`. What is true is that **no event data leaves the device** —
> `sendDefaultPii = false`, and nothing in the capture or storage path transmits records.
> The rule for the walkthrough stands; the justification was wrong.

---

## What goes away

**The Getting Started card on the home screen.**

> **CORRECTED — the card is worse than "duplicates three Help rows".** Verified row by row:
>
> | Card row | Status |
> |---|---|
> | *Quick record* | **Verbatim identical** to Help's row |
> | *Record with details* — "Add notes, duration, triggers, and severity using the blue button." | **Contradicts Help.** That is four of the seven fields. Help's row was corrected on 24 August to name all seven; the card still carries the uncorrected version |
> | *History & export* — "Use the ⋮ menu in the top right to view your event history or export as CSV." | **Stale in one half.** The ⋮ menu reference is CORRECT — it is the AppBar overflow and it exists. What is stale is where it leads: export moved behind *Your data* in `098821c` |
>
> The original claim that it "references a ⋮ menu on event cards that does not exist" is
> wrong. No per-event ⋮ menu exists anywhere — the only `PopupMenuButton` in the app is the
> AppBar overflow — but the card does not claim otherwise. `Icons.more_vert` on that row is
> decoration.

**Remove it when the walkthrough lands.** Otherwise the same facts live in three places —
walkthrough, Help, card — and the drift problem is worse than before.

**One source of truth per job:** the walkthrough introduces, Help answers questions.

> **Until then, the card and Help contradict each other on two of three rows.** That is a
> live inconsistency, not a future one.

---

## Sequencing — why this is last

Every screen it describes is changing:

- **Step 1** — the wizard replaces the log screen; "add the details later" becomes the
  wizard's own path. Also waits on nullable duration, per the correction above
- **Step 2** — stable for **starting**. The ending half is not: it waits on the sub-17
  locked-device limitation, which is a known limitation on a shipping tier
- **Step 3** — History gains a date range and day grouping; the CSV becomes multi-stream
- **Step 4** — stable. This is the durable step

Build it after the model changes, the History polish and SQLite. Anything written before
those is work done twice.

---

## Open

- **Visual treatment.** Full-screen pages with a pager, or a sheet? Full-screen suits four
  steps and reads as deliberate; a sheet is lighter but feels dismissible in a way the
  data-safety step should not
- **Does step 4 offer to take a backup there and then?** It is the one action worth
  offering — but a new user has nothing to back up, so it would be an empty file. Probably
  better as a prompt the first time they have real data, which is what the backup reminder
  banner already does
- **Should the walkthrough know the platform's notification permission state?** If
  notifications are denied, step 2 describes something unavailable. The Help status band
  already surfaces this; the walkthrough could either check it or ignore it

### Added by the feasibility read

- **What marks the walkthrough as seen, and where does it live?** It must be independent of
  `disclaimerAcceptedVersion`, or a disclaimer bump re-runs the walkthrough for
  long-standing users. See the trigger section.
- **First launch after a restore.** A user moving to a new phone restores a device backup,
  or restores a MER backup file, and reaches first launch **with a full history**. The
  walkthrough would introduce an app they already know, and step 4's "take a backup" advice
  is redundant to someone who just used one. Decide whether an existing record count
  suppresses it.
- **Text scaling and accessibility.** Four full-screen pages of fixed copy is the layout
  most likely to break at large accessibility text sizes. Nothing else in the app is
  full-screen fixed copy, so there is no existing pattern to inherit.
- **The Windows re-run entry point.** `GETTING HELP` renders on Windows, so a "replay the
  walkthrough" row there would offer the three-step version. Fine, but state it rather than
  leaving it to fall out of a platform conditional.
- **Nothing in this document is testable.** No test asserts that walkthrough copy matches
  Help, or that the platform instructions stay opposite. `test/checklist_citations_test.dart`
  guards the device-test checklist's symbols the same way; consider whether the walkthrough
  copy, once written, should be checked against Help's strings rather than kept in sync by
  hand — that hand-sync is precisely what produced the Getting Started card.
