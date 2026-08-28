# Medical Event Recorder — Target Data Model

⚠️ **"Design only, no code written against this yet" — TRUE WHEN WRITTEN ON
22 AUGUST 2026, FALSE SINCE. THREE SCHEMA VERSIONS HAVE NOW BEEN BUILT AGAINST
IT.** The original line is preserved above because it explains why the document
reads as it does; §0 below states what actually exists. Read this document as a
TARGET, and §0 as the code.

This is the stale-authoritative-label class: a claim that was correct the day it
was written, that nothing re-derives, and that reads as authoritative precisely
because someone once wrote it down deliberately. It was cited as current on
26 August 2026 — four days and three schema versions later — in a brief that
concluded `condition_id` did not exist. It does.

---

## 0. What is BUILT, as at schema v9 — 28 August 2026

**Derived from the DDL in `lib/models/`, not from memory.** Regenerate this
section at every schema bump; a divergence table that is not maintained is worse
than none.

⚠️ **REGENERATED 28 AUGUST 2026 AFTER SITTING AT v5 THROUGH FOUR SCHEMA BUMPS.**
Every row of the divergence table below was false, and the section had begun
contradicting itself — the three `rescue_med_*` columns were listed under BOTH
"columns that exist" and "columns that do NOT exist", because v5 updated one
list and not the other. The rule above is stated in this section's own words and
was not followed; it is restated here rather than quietly satisfied, because the
failure mode is the one this document already names at the top: a claim that was
correct when written, that nothing re-derives, and that reads as authoritative
because someone wrote it down deliberately.

### Tables that exist

| Table | Added | Notes |
|-------|-------|-------|
| `schema_meta` | v1 | key/value. Carries the schema version and the migration markers. |
| `event` | v1 | 17 columns — see below. |
| `event_type` | v2 | The vocabulary. `id, condition_id, value, label, is_seeded, is_active, is_protected, sort_order, emoji`. |
| `observation` | v2 | Identical shape. Shared across conditions by §1 principle 4, so its `condition_id` will never be populated. |
| `event_observation` | v7 | `event_id, observation_id, position`. Normalised link. **`feelings_json` remains authoritative** — this is additive and nothing reads it yet. |
| `medication_note` | v7 | `id, occurred_at, logged_at, kind, notes, condition_id`. The exceptions-only medication stream. `condition_id` added v8. |
| `condition` | v8 | `id, name, seeded_key, is_active, sort_order`. **Created EMPTY and assigned to nothing.** |
| `condition_observation` | v8 | `condition_id, observation_id, sort_order`. Relevance ORDERING, never membership. No rows, and no picker reads it. |
| `trigger_option` | v9 | The beforehand vocabulary. Same shape as `observation`. Seven seeds, all ASCII, none retired. |
| `event_trigger` | v9 | `event_id, trigger_id, position`. **`triggers_json` remains authoritative**, same rule as observations. |

Indexes: `event(id)`, `event(logged_at)`, `medication_note(occurred_at)`,
`event_observation(event_id)`, `event_trigger(event_id)`.

⚠️ **`trigger_option` is deliberately NOT in `kVocabularyTables`.** That constant
is walked by the v4 emoji ALTER, so including it would make a v3 database ALTER a
table that v9 creates.

### `event` columns that exist

`ordinal`, `id`, `logged_at`, `occurred_at`, `duration_bucket`,
`duration_seconds`, `event_type`, `severity`, `feelings_json`, `triggers_json`,
`notes`, `referral_required`, `details_completed`, `condition_id`,
`rescue_med_given`, `rescue_med_helped`, `rescue_med_second_dose`

✅ **The three rescue-medication columns were added in v5, 27 August 2026.**
All nullable, NULL on every existing row. `rescue_med_helped` is TEXT holding
`RescueResponse.name` — deliberately not an integer ordinal like `severity`,
whose integer mapping is load-bearing legacy a new column has no reason to
inherit.

⚠️ **`condition_id` EXISTS, on `event`, on both vocabulary tables and on
`medication_note`.** Nullable, and **never populated on any row** — NULL means
NOT YET SAID. The `condition` table now exists too (v8) and is empty, so there
is still nothing to point at.

### The BACKUP envelope is separately versioned, and is at 2

`kBackupSchemaVersion = 2` since 28 August 2026, when `medicationNoteCount` and
`medicationNotes` were added. Distinct from the SQLite schema version and bumped
on its own cadence. The bump is the safety mechanism: `parseBackup` refuses
`schema > kBackupSchemaVersion`, so an older build refuses a notes-bearing file
rather than restoring the events and silently discarding the notes.

### Tables in this document that do NOT exist

`condition_trigger`, `condition_field`, `event_field_value`, `daily_entry` (§9).

`condition_trigger` is **buildable since v9** made triggers a vocabulary, and is
deliberately not built — relevance mapping is a no-op at one condition. Recorded
as `kConditionTriggerStatus` in `condition.dart` so it is a status rather than an
absence someone rediscovers.

### `event` columns in this document that do NOT exist

`event_type_id` (the FK — `event.event_type` still holds the vocabulary `value`
directly, because a join buys nothing while `condition` is empty),
`awareness_changed`, `aura`, `injury`, `recovery_seconds`, `witnessed_by`.

### Behaviour that diverges from this document

| This document says | The code does |
|---|---|
| §5: quick record writes `condition_id` = the primary condition | Writes NULL. The table exists and is empty; there is still no condition to name, and no screen where anyone names one. |
| §5: `event_type_id` NULL until the wizard confirms it | No FK exists. `event.event_type` holds the vocabulary `value` as a nullable string. **The "live defect" recorded here on 27 August — that `eventType` defaulted to `seizure` and `fromMap` coerced an absent key — was FIXED the same day**: both `eventType` and `severity` are now nullable and `fromMap` returns null for an absent key. |
| §1 principle 2: a user may track several conditions at once | The tables support it; **no UI does.** `ConditionStore`, `loadConditions` and `addCondition` have no caller outside `lib/models/`. |
| §7: `eventType` medication maps to a `medication_note` | **BUILT** (v7). `medication_note` is a separate table and record kind, interleaved with events in the CSV by `record_kind`. `medication` as an event type is retired by `retireMedicationEventType`, which also CLEARS `is_protected` — so nothing on a live database is protected, and `setActive`'s protection refusal is now unreachable in the app. |

### What is BUILT that this document never described

| Thing | Note |
|---|---|
| Vocabulary hide / unhide | `is_active` reachable from a UI for the first time — "Your lists", via the Home overflow. `isShippedHidden` separates MER's own retirements, which a user may not reverse, from entries the user hid, which they may. |
| Mis-decoded observation twins | `mangledLegacyObservations()` — shipped rows so a corrupted stored value resolves to a readable label. Present in the vocabulary, deliberately not rendered on the management screen. |
| The delimited CSV | 16 columns, marker `v4` in the filename, multi-stream by `record_kind`. |
| First-run walkthrough | Five steps, four on Windows. Flag stores a version, written on presentation. |

---

## 1. The four decisions this rests on

| # | Decision |
|---|----------|
| 1 | **A condition is a real entity, not a label.** It owns its event types. |
| 2 | **A user may track several conditions at once.** NOT profiles — one person, several conditions. |
| 3 | **Users name their own OPTIONS; only MER defines new FIELD TYPES.** A user adding "Cluster headache" gets the standard event shape and can name their own triggers and observations. They cannot create a numeric field. Seeded conditions may carry extra typed fields because MER has researched them. |
| 4 | **Vocabularies are SHARED, not per-condition.** One trigger list, one observation list, each condition surfacing its relevant entries first. Someone tracking two conditions does not configure "Poor sleep" twice. |

**Governing constraint:** approximate data that EXISTS beats exact data that
does not. Every field must pass one test — can the patient answer it quickly,
and would they otherwise be unable to reconstruct it later? If not, it does not
go in.

---

## 2. Entities

### condition

| Column | Notes |
|--------|-------|
| `id` | |
| `name` | |
| `seeded_key` | Nullable. What tells the app whether extra typed fields apply. |
| `is_active` | |
| `sort_order` | |

### event_type

⚠️ **CORRECTED 26-Aug-26, when this table was built.** Two things this spec left
unstated turned out to decide the implementation, and a blank cell had been read
as a requirement it never expressed. See the `condition_id` note below and
**§2a**.

| Column | Notes |
|--------|-------|
| `id` | |
| `condition_id` | **NULLABLE, and unpopulated as at v9.** The `condition` table now EXISTS (v8) and is empty — the blocker is no longer the table, it is that no screen exists where someone says what they track. NULL means NOT YET SAID. |
| `value` | **ADDED.** The immutable string a record stores. Never changes, for any reason. |
| `name` | Renamed `label` in code: what a person reads. May change; `value` may not. See §2a. |
| `is_seeded` | Seeded entries refuse rename and delete. |
| `is_active` | **ADDED.** Retire, never delete — the entry stays so records referencing it still render. |
| `is_protected` | **ADDED, and now unreachable.** It guarded `medication` until the medication split landed; `retireMedicationEventType` retires that entry AND clears the flag on both the fresh-install and upgrade paths, so **no row on a live database carries it**. The refusal in `setActive` is kept and tested, and cannot currently fire. |
| `is_primary` | Not built. No consumer yet. |
| `sort_order` | |

### observation

**ADDED 26-Aug-26.** The same shape, minus `condition_id`'s eventual meaning:
observation vocabularies are SHARED across conditions by §1 principle 4, so this
table is never per-condition. Built alongside `event_type` so the
seeded-and-extensible mechanism was designed once rather than twice.

### event

| Column | Notes |
|--------|-------|
| `id` | Preserved across migration — see §7. |
| `condition_id` | **NULLABLE, and unpopulated as at v9.** ⚠️ This cell was BLANK, and the blank was repeatedly read as NOT NULL — which blocked this work for two design reads. The string "NOT NULL" has never appeared anywhere in this document (`grep -c` returns 0), so the requirement was inherited from nowhere. It is stated explicitly now. NULL means NOT YET SAID, the same rule as `occurred_at`, `details_completed`, duration at creation and the legacy buckets. |
| `event_type_id` | **NULLABLE** until the wizard confirms it. Not built as at v9 — `event.event_type` still holds the vocabulary `value` directly, because a join buys nothing while `condition` is empty. |
| `occurred_at` | Nullable. When it happened. |
| `logged_at` | **Never null, never editable.** When it was recorded. |
| `duration_seconds` | Nullable. A **REAL QUANTITY**, not a bucket. |
| `severity` | Nullable. See below. |
| `awareness_changed` | Nullable. |
| `aura` | Nullable. Yes / no / unsure. |
| `injury` | Nullable. |
| `rescue_med_given` | Nullable. |
| `rescue_med_helped` | Nullable. yes / partly / no. |
| `rescue_med_second_dose` | Nullable. |
| `recovery_seconds` | Nullable. |
| `witnessed_by` | Nullable. |
| `notes` | |
| `details_completed` | Routes the UI. See §5. |

**Every optional field is nullable, and NULL means UNKNOWN.** This fixes the
current model's worst property: today `< 1 minute` is indistinguishable from a
duration nobody entered, which is how an abandoned event ends up carrying wrong
data in a medical record rather than absent data.

**Severity is kept**, and the reason is recorded here so it is not re-litigated:
it is a **relative self-assessment** — how this event felt compared with the
person's other events of the same type. That is data a specialist cannot obtain
any other way.

The migraine paper test **independently supports this**, and corrects an earlier
claim. Severity is a standard field in migraine diaries and is recorded
explicitly by The Migraine Trust. An earlier note said severity "appears in NO
published diary"; that was drawn from seizure diaries only and stated too
broadly. Its absence from *seizure* diaries reflects that those are clinical
instruments, not that self-rated severity is without value.

Consider labelling it "Compared with your other events" in the UI so the
relative framing is explicit rather than implied.

Open, not solved: migraine severity is often a **0-10 scale** rather than three
points, so severity's VALUE TYPE may need to vary by condition. Not solved now.
`condition_field` already exists for exactly this kind of variance if it turns
out to be needed, and severity's presentation may become condition-defined.

### observation / event_observation, trigger / event_trigger

Shared vocabularies with many-to-many joins. Each vocabulary row carries
`is_seeded` and `is_active` — **retire, never delete.**

**`event_observation` carries a PHASE** — during / after. Nullable.

MER's current observation list is entirely postictal: how the person was
*afterwards*. Migraine diaries record symptoms DURING the attack — sensitivity
to light, sound and smell, nausea, vomiting, dizziness, blurred vision, neck
stiffness, tingling — and separately a postdrome. The model as first drafted had
one observation set with no sense of when.

**Do NOT split this into two vocabularies.** Several observations occur in both
phases — nausea, confusion, fatigue — so duplicating them would double the list
and break the shared-vocabulary decision in §1. One vocabulary; the phase is
recorded on the join.

**This replaces storing option strings inside each record**, which is the
current model's most dangerous property: option strings are stored verbatim in
every record and matched by `contains` at export, so renaming an option orphans
it across all history and its CSV column reads empty forever. With a join,
renaming a label updates everywhere and history survives.

### condition_observation / condition_trigger

Relevance mapping only. Absence sorts an entry lower; **it does not hide it.**

### medication_note

| Column | Notes |
|--------|-------|
| `id` | |
| `condition_id` | Nullable. |
| `occurred_at` | |
| `logged_at` | |
| `kind` | missed / late / changed |
| `notes` | |

**Exceptions only.** Not an event. Do not ask the user to log every dose —
daily logging is the most abandoned feature in health apps, and a specialist
does not need 340 confirmations of adherence, they need the 25 deviations.

**No drug name field**, decided on burden grounds; `notes` covers it. That
applies to the rescue-medication fields on `event` too.

**Rescue medication is three fields, not one.** A single bool captures none of
what migraine sources consistently record: The Migraine Trust records medication
taken INCLUDING whether a second dose was needed, and another source states
plainly that response can matter as much as which medication was used. Hence
`rescue_med_given`, `rescue_med_helped` and `rescue_med_second_dose`.

This is at most three taps, all optional, all nullable, all skippable — and it
passes the burden test in §1, because each is answerable in a second and none can
be reconstructed at an appointment weeks later. It supersedes the earlier
"one tap each" framing for this field specifically.

### condition_field / event_field_value

For seeded conditions needing something the standard shape lacks — glucose,
peak flow. `key`, `label`, `value_type`, `unit`, `sort_order`.

**Only MER creates `condition_field` rows.** Store and display only: no ranges,
no thresholds, no colour coding. Recording "glucose 3.2" is a record; flagging
it as low is monitoring.

---

## 2a. Vocabulary entries: `value` versus `label`

**ADDED 26-Aug-26. The property every safety rule here follows from.**

A vocabulary entry has a `value` and a `label` and they are NOT the same thing.
`value` is what gets written into a record and is **immutable**. `label` is what
a person reads and **may change**. From that split:

- **renaming** touches `label` only, so no record is ever orphaned;
- **retiring** sets `is_active = 0`, so the entry leaves pickers while records
  referencing it still render;
- **nothing is deleted**, so no record can point at a row that is gone.

This is what makes a vocabulary REVISION possible without a data migration.
Collapsing "Just tired" into "Tired" retires the old entry and seeds the new one;
a record carrying `😴 Tired and weary` keeps that exact string forever and keeps
rendering.

**The alternative was considered and rejected**: rewriting stored values would
have changed what a person recorded, in a medical record, to suit a later
editorial decision. Legacy duration buckets were handled the same way and it
worked.

⚠️ **Emoji are part of the stored value, not decoration.** `😵 Confused` is the
string in the record. That is why the legacy entries cannot simply be dropped,
and why §6's "emoji stripped from values" is implemented by exporting the
**label** rather than by a regex over the value.

---

## 3. Sections are presentation, not schema

Standard fields are **typed columns on `event`**, grouped by section in the UI
only. Before / during / after is a presentation ordering, taken from Seizure
Tracker's four-section structure.

Putting sections in the schema would make this a form builder — flexibility
nobody asked for, at the cost of typed columns, simple queries and a simple CSV.
`condition_field` handles the genuine exceptions. Two mechanisms, each doing one
job.

---

## 4. What must not regress

The capture path. Everything below is unchanged by multi-condition support, and
any schema decision that would alter it is wrong.

---

## 5. Capture path

**Quick record** — one tap, no decision. Creates an event with `logged_at`,
`condition_id` = the user's primary condition, `event_type_id` NULL,
`details_completed` false, everything else null.

**Notification** — the same, plus a real `duration_seconds` from the elapsed
timer.

**The wizard** confirms event type first, then before / during / after. A
completed record opens the existing single page instead.

**Nothing is gated.** Abandoning the wizard keeps whatever record exists.
`details_completed` only **routes**; it never blocks.

---

## 6. CSV

Multi-stream, one file, with a `record_kind` column (`event` /
`medication_note`, and `daily_entry` when §9 lands) and a common timestamp, so
sorting interleaves them — which is what lets a specialist see a missed dose
sitting three days before a cluster.

**`record_kind` must accommodate a third value from the outset.** Writing it as
a two-valued flag would make §9 a breaking change to the export rather than an
addition.

Observations and triggers become **delimited columns**. Emoji stripped from
**values** as well as headers.

✅ **BOTH HALVES ARE BUILT, 26 August 2026.** Eleven observation columns
collapsed when observations became user-extensible; the seven trigger columns
collapsed in the same shape a stage later. **26 → 17 → 11 → 14 columns.** Order
is unchanged: the delimited column sits where its one-hot block sat, and the
three rescue-medication columns added on 27 August sit between `beforehand` and
`referral_required`.

⛔ **THE MARKER TRACKS THE HEADER ROW. Any change to the column set bumps it
— added, removed, renamed or reordered. No judgement about whether a change is
"real".** Recorded at `kCsvShapeVersion` in `event_record.dart`, which is
authoritative; this is a copy.

The temptation is to bump only for changes that break something, and that
requires predicting what a consumer does. Consumers here are hand-built
spreadsheets: a template written against eleven columns breaks on fourteen
exactly as surely as on a reshape, because every formula after the insertion
point now points one column left. A mechanical rule also makes the filename a
reliable statement about the file — `v2` and `v3` are guaranteed to differ,
and two `v3` files are guaranteed to match.

    v1   the original one-hot export                          26 columns
    v2   observations and beforehand became delimited          11
    v3   rescue medication added three columns                 14

| | |
|---|---|
| Delimiter | `; ` — `kCsvListDelimiter` |
| A value containing it | Quoted, with its own quotes doubled: `"Dizzy; unsteady"; Stress`. The same convention CSV uses, one level down. **The value is never altered** |
| Empty set | **Blank.** Not `none`, which would be a value indistinguishable from a user-defined observation called "None" |
| Emoji | Stripped by LOOKUP, never by position. `Vocabularies.labelFor` |
| Shape marker | A **filename suffix**, `..._20260827_154500.v3.csv`. Not a column |
| Ordering | Beforehand in picker order, preserving what the one-hot columns did. Observations in storage order, unchanged from before |

⚠️ **THE COLUMN IS `beforehand`, NOT `triggers`.** The seven one-hot columns
were the OPTION NAMES with no group heading over them, so the export never had
to name this field — and that is the only reason the causal-wording work never
reached it. Collapsing to one column forces a heading, and `triggers` asserts
that what is listed CAUSED the event. `beforehand_wording_test` caught it on the
run that introduced it.

**Read as a standing example:** a property that holds because of how something
is SHAPED stops holding when the shape changes, and nothing announces that. The
check has to outlive the structure it was written against.

**NO compatibility mode, NO second export option, NO version negotiation** —
the standing decision of 26 August 2026. One user, known to the developer;
amending the spreadsheet by hand once is acceptable. Nothing reads the `v2`
marker. **That decision is void the day there is a second user, and no test can
catch it turning false.**

**MER does not correlate the streams.** Both go in the file on the same
timeline; the specialist does the reading. Charting missed doses against events
would be interpretation.

---

## 7. Migration, and the inbox that does not go away

> **CORRECTED, 22 August 2026.** This section originally opened:
>
> > "Reads **one shape**: the JSON array under `epilepsy_event_records_v1`. The
> > simplest migration MER will ever have — which is the whole argument for
> > doing it now rather than after the model expands."
>
> **That premise was wrong, and it will never become true.** The one-shape claim
> holds for the INITIAL conversion only. A SQLite feasibility pass established
> that `shared_preferences` and the iOS App Group cannot be retired, because two
> writers live outside Dart — `AppDelegate` and `EndMEREventIntent`, the latter
> in a separate widget extension process — and neither can reasonably speak
> SQLite. They change job from store to **inbox**, permanently. The original
> wording is kept above rather than deleted, because it was the stated basis for
> the do-it-now argument and that basis has narrowed.

**SQLite is the system of record.** `shared_preferences` and the App Group are a
**drained inbox**, not legacy storage awaiting removal.

**The property is single-writer, and it is not iOS-specific.** Dart's main
isolate becomes the only writer of the record list; every other capture path
posts a fact. The inbox is the mechanism, not the property — a cross-platform
check established that framing this as "the App Group becomes an inbox" misses a
loss window that exists on Android too, and that the Android one is reachable
through ordinary use rather than across a process boundary.

**One reconciliation pattern on both platforms:** the native or background-isolate
writer APPENDS to the inbox and never reads or rewrites the record list; the main
isolate drains the inbox into the store, verifies, and only then clears it. One
writer per store, and no read-modify-write anywhere but the main isolate.

One design, two transports — the transport differs for a hard platform reason:

| | Transport |
|---|---|
| **Android** | `flutter.`-prefixed inbox keys in the same store, written by the notification background isolate, drained directly in Dart. Also satisfies the sqflite constraint: `sqflite` documents that access "should be done in the main isolate" and that its "transaction mechanism is not cross-isolate safe", so the background isolate stays off SQLite entirely. |
| **iOS** | App Group keys, written by Swift in two processes, drained via method channel — **because Dart cannot read the App Group.** Also removes the native writers' treatment of `UserDefaults.standard` as a source of truth. |
| **Windows** | Nothing. There is no second writer: no notification path, so no background isolate. The only platform already correct. |

**Sequence the single-writer work BEFORE this migration, Android first.** Migrating
on top of a lossy handoff bakes the loss into the new schema. Android comes first
because it is Dart-only, so the instruction schema and the apply logic are proven
where they are testable, before a process boundary is added. See the Change
Register entry for 22 August 2026 for the loss windows on each platform and the
three non-negotiable conditions.

### The initial conversion

Reads one shape: the JSON array under `epilepsy_event_records_v1`.

| From | To |
|------|-----|
| — | Creates one condition, "Epilepsy", `seeded_key` `'epilepsy'`, primary |
| `eventType` seizure / absence / other | `event_type` rows |
| `eventType` **medication** | a `medication_note`, **NOT an event** |
| `timestamp` | `logged_at`. **`occurred_at` stays NULL** — the old value was log time, and pretending otherwise fabricates data |
| `duration` buckets | `duration_seconds` NULL, original bucket preserved. **Do not invent a number from a bucket** |
| `feelings[]` | observation vocabulary rows plus joins, emoji stripped, **`phase` = `'after'`** — every existing entry is postictal, so the mapping is unambiguous |
| `triggers[]` | trigger vocabulary rows plus joins, emoji stripped |
| `referralRequired` | legacy column or notes |
| `id` | **Preserved.** Restore matches on id; changing them breaks every existing backup file |

### Non-negotiable

- **Leave `epilepsy_event_records_v1` in place permanently this release.** Note
  this is no longer only a safety net: it is the inbox, and it stays for good.
- **Write a backup file before migrating.**
- **Verify the row count before marking migration complete**, and fall back to
  the old store if it does not match.
- **Drain, then clear.** The inbox must be emptied only after the SQLite write
  for those records has succeeded, or a foreground that fails mid-drain loses
  them.

---

## 8. Settled, previously open

| Question | Decision |
|----------|----------|
| Severity | **Kept** — see §2. |
| Seeded catalogue | **Epilepsy only** this release. Migraine needs the same research pass; shipping one well beats two thinly. |
| `medication_note` drug name | **No.** |
| Primary condition | Set in **Settings**; the first condition added becomes it by default. Most users will only ever have one. **Nothing at capture time.** |

---

## 9. Designed for, deliberately not built: daily entries

The genuine structural gap found by the migraine paper test. Recorded because it
is deferred, not rejected.

Migraine diaries record days when **nothing happened**. One source puts it
directly: a diary that only records bad days cannot show you a rate. Non-attack
days carry a tick and a sleep figure. Clinicians ask for migraine days PER
MONTH — which needs a denominator MER cannot currently produce, because MER is
entirely event-driven and has no way to record an absence.

Planned as a **third record kind** alongside `event` and `medication_note`:

| Column | Notes |
|--------|-------|
| `id` | |
| `condition_id` | Nullable. |
| `date` | |
| `logged_at` | |
| `had_event` | bool |
| `sleep_hours` | Nullable. |
| `notes` | |

### Requirements on the CURRENT design, so this stays additive

| # | Requirement |
|---|-------------|
| 1 | Nothing about `event` or `medication_note` may assume events are the only record kind. |
| 2 | The CSV's `record_kind` column must already accommodate a third value — see §6. |
| 3 | Any "events this month" figure must be written so a denominator can be added later **without changing its meaning**. |

### Why deferred

Daily logging is the most abandoned feature in health apps. It needs its own
thinking about burden — likely an exceptions-and-prompts design rather than a
form — and bolting it onto this release would compromise both it and the
release.

---

## 10. Recorded, no action

| # | Item |
|---|------|
| 1 | **Severity value type may become condition-defined.** Migraine severity is often 0-10 rather than three points. `condition_field` already covers this kind of variance if needed. Not solved now — see §2. |
| 2 | **Pain LOCATION does not fit the standard shape at all.** Migraine templates use a head diagram, which is neither text nor numeric. `condition_field` territory if ever wanted; out of scope. |
| 3 | **Wizard copy, for the copy pass.** Multiple migraine sources warn that a recorded "trigger" is often the attack already starting — food cravings, thirst, neck stiffness and light sensitivity commonly occur in the hours BEFORE pain, and one source calls this the main reason trigger hunting frustrates people. MER must NOT interpret this; that would cross the capture-only line. But the wizard's trigger step can be worded so it does not imply causation: **"What was happening beforehand?"** rather than "What caused this?". No action now. |
