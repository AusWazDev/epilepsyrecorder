# Medical Event Recorder — Target Data Model

**Design only, 22 August 2026. No code written against this yet.**

The target model for multi-condition support: what SQLite gets built against,
and what the migration reads toward. Written before any schema exists, because
expansion changes what a record *is* — designing tables against today's nine
fields would mean migrating twice, and the second migration is the harder one.

> **Not clinically validated.** The field set behind this model was drawn from
> patient-facing charity diaries, Seizure Tracker's published field list, and
> migraine diary guidance from The Migraine Trust, Migraine Canada, the National
> Headache Foundation, the American Migraine Foundation and InformedHealth.org
> (NCBI Bookshelf NBK328459) — not from peer-reviewed literature. See the Change
> Register entries for 22 August 2026 for the sources and their limits. Nothing
> here should be described to a user as clinical, standard, or validated.

**Paper-tested against migraine, 22 August 2026.** The model was checked against
a second condition before any SQLite work, to establish whether it is genuinely
general or epilepsy with extra tables. It mostly held: triggers, duration,
notes, aura and a post-event phase all mapped unchanged, and the before / during
/ after ordering fits migraine better than epilepsy because the phases are more
distinct. Three gaps were found. Two are amended below; the third is recorded in
§9 as designed-for and deferred.

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

| Column | Notes |
|--------|-------|
| `id` | |
| `condition_id` | |
| `name` | |
| `is_seeded` | |
| `is_primary` | |
| `sort_order` | |

### event

| Column | Notes |
|--------|-------|
| `id` | Preserved across migration — see §7. |
| `condition_id` | |
| `event_type_id` | **NULLABLE** until the wizard confirms it. |
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

This breaks the current 26-column one-hot format, as already accepted. One-hot
columns cannot survive user-defined options.

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
