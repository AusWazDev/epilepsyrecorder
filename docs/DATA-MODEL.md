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

## 0. What is BUILT — schema v9, verified against the code 7 September 2026

**Derived from the DDL in `lib/models/`, not from memory.**

⛔ **THE REGENERATION TRIGGER WAS WRONG, AND THAT IS THE FINDING UNDERNEATH EVERY
CORRECTION DATED 7 September 2026 BELOW.** This section previously read
*"Regenerate this section at every schema bump."* **The rule was followed. The
section rotted anyway** — `kSqliteSchemaVersion` has stood at **v9** throughout,
while the backup envelope went 2 → 4, the CSV marker v3 → v6, the beforehand
seeds 7 → 32, and an entire conditions UI shipped. **Fourteen defects arrived
without a single schema bump.**

⭐ **A rule that fires on the wrong event is worse than no rule, because
compliance with it reads as maintenance.** Every audit that checked "was this
regenerated at the last schema bump" would have returned clean.

**REGENERATE THIS SECTION WHEN ANY OF THESE MOVES:**

| | Constant | Where |
|---|---|---|
| 1 | `kSqliteSchemaVersion` | `event_store_sqlite.dart` |
| 2 | `kBackupSchemaVersion` | `constants.dart` |
| 3 | `kCsvShapeVersion` | `event_record.dart` |
| 4 | any seed list length — `kSeedEventTypes`, `kSeedObservations`, `kSeedTriggers` | `vocabulary.dart` |

⛔ **AND WHEN A SCREEN OR UI SURFACE IS ADDED OR REMOVED — no version constant
covers that, and it is what let the two false rows below stand, unnoticed from 28 August
until 7 September 2026.** Both were UI
claims (*"no screen where anyone names one"*, *"no caller outside
`lib/models/`"*), and no constant in the table above would ever have caught
them.

⚠️ **A divergence table that is not maintained is worse than none** — it is read
as authoritative precisely because someone wrote it down deliberately.

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
| `event_type` | **v3** | The vocabulary. `id, condition_id, value, label, is_seeded, is_active, is_protected, sort_order, emoji`. ⚠️ *[This row read **v2** until 7 September 2026. `createAndSeedVocabularies` is called only from the `from < 3` upgrade step, and the comment beside it reads "the v3 step above creates these tables". The v2 step adds `details_completed` and nothing else.]* |
| `observation` | **v3** | Identical shape, created in the same step as `event_type` — *[this row read **v2** until 7 September 2026; see the note on that row]*. Shared across conditions by §1 principle 4, so its `condition_id` is **not populated, checked 7 September 2026**, and by that principle is not intended to be. ⚠️ **Relevance for observations is carried by the `kSeededRelevance` const map, not by this column** — see §2 `condition_observation`. |
| `event_observation` | v7 | `event_id, observation_id, position`. Normalised link. **`feelings_json` remains authoritative** — this is additive and **nothing reads it as at 7 September 2026**. ⚠️ **No `phase` column exists** — see the designed-not-built list below. |
| `medication_note` | **v6** | `id, occurred_at, logged_at, kind, notes, condition_id`. The exceptions-only medication stream. `condition_id` added v8. ⚠️ *[This row read **v7** until 7 September 2026. `createMedicationNoteSql` runs in the `from < 6` step; v7 is `event_observation`.]* |
| `condition` | v8 | `id, name, seeded_key, is_active, sort_order`. Created empty. **As at 7 September 2026: rows are created only by `addCondition`, which writes `seeded_key` NULL and `is_active` 1 literally; nothing writes either field otherwise, and there is no deactivate or delete path.** |
| `condition_observation` | v8 | `condition_id, observation_id, sort_order`. Relevance ORDERING, never membership. **As at 7 September 2026: no rows, no writer, no reader.** ⭐ **Relevance ordering IS implemented — from the `kSeededRelevance` const map in `vocabulary.dart`, not from this table. That is a DECISION, not a gap — see §2.** |
| `trigger_option` | v9 | The beforehand vocabulary. Same shape as `observation`. **32 seeds as at 7 September 2026** — *[this cell read "Seven seeds" until then; the count moved with the migraine and sixteen-observation passes and nothing re-derived it]*. **All ASCII, none retired** — both verified 7 September 2026. |
| `event_trigger` | v9 | `event_id, trigger_id, position`. **`triggers_json` remains authoritative**, same rule as observations. |

Indexes: `event(id)`, `event(logged_at)`, `medication_note(occurred_at)`,
`event_observation(event_id)`, `event_trigger(event_id)`.

⚠️ **EVERY "Added" VERSION ABOVE WAS RE-DERIVED FROM `upgradeSchema` ON 7 September 2026,
AND THREE WERE WRONG.** `event_type` and `observation` read v2 and are v3;
`medication_note` read v7 and is v6. The true map:

    v2  event.details_completed
    v3  event.condition_id, and event_type + observation created and seeded
    v5  the three rescue_med_* columns
    v6  medication_note
    v7  event_observation
    v8  condition, condition_observation, medication_note.condition_id
    v9  trigger_option, event_trigger

⭐ **Two of the three were found only because a correction elsewhere in this pass
asserted a version and that assertion was checked.** The "Added" column had never
been audited against the migration; it was written from memory alongside each
change. **Re-derive it, do not carry it forward.**

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
`medication_note`.** Nullable. **Checked 7 September 2026: `event.condition_id`,
`observation.condition_id` and `medication_note.condition_id` are unpopulated on
every row** — NULL means NOT YET SAID.

⭐ **`event_type.condition_id` IS THE EXCEPTION AND IS NOW WRITABLE.**
`ConditionsScreen` assigns a condition to an event type through
`Vocabularies.setCondition`, so a record's condition is **DERIVED from its event
type** rather than stored on the record. `setConditionFor` **throws
`VocabularyRuleError` for observations and triggers by design**, which is why
those two columns cannot be populated at all.

### The BACKUP envelope is separately versioned, and is at 4

**`kBackupSchemaVersion = 4` as at 7 September 2026** — *[this section read
"is at 2" until then, and named the 28 August medication-notes bump as the
latest; two further bumps had happened]*. Distinct from the SQLite schema
version and bumped on its own cadence.

| | Bump | What entered the envelope |
|---|---|---|
| 1 → 2 | 28 Aug 2026 | `medicationNoteCount`, `medicationNotes` |
| 2 → 3 | | `conditions` and `eventTypeConditions` — the type-to-condition mapping |
| 3 → 4 | | `occurredAt`. ⚠️ **No top-level key changed** — records serialise through `EventRecord.toMap`. The bump was made on the RULE rather than the wording |

**The bump is the safety mechanism:** `parseBackup` refuses
`schema > kBackupSchemaVersion`, so an older build **refuses the whole file**
rather than restoring the events and silently discarding what it does not
understand. ⛔ **A refusal restores nothing at all — not the records with the new
field quietly missing.**

⚠️ **`seededKey` and `isActive` ARE written into the envelope and the restore
loop reads neither** — it takes `name` only. Verified 7 September 2026. Adoption
state therefore does not survive a backup-and-restore round trip. Recorded here
as a known gap, not fixed by this pass.

### Tables in this document that do NOT exist — checked 7 September 2026

**Checked 7 September 2026:** `condition_trigger`, `condition_field`,
`event_field_value`, `daily_entry` (§9).

`condition_trigger` is **buildable since v9** made triggers a vocabulary, and is
**deliberately not built as at 7 September 2026** — relevance mapping is a no-op
at one condition. Recorded as `kConditionTriggerStatus` in `condition.dart` so it
is a status rather than an absence someone rediscovers.

⚠️ **A second reason it cannot be built, stronger than the first — checked 7 September 2026:**
`setConditionFor` **throws `VocabularyRuleError` for triggers by design**, so
there is no writer for the rows even if the table existed. Relevance for
triggers is not carried by the const map either — see §2.

### Columns, fields and surfaces in this document that do NOT exist — checked 7 September 2026

⛔ **HEADING WIDENED 7 September 2026. It read "`event` columns in this document
that do NOT exist", and that scope let `event_observation.phase` fall straight
through — a designed column on a different table, recorded nowhere as unbuilt.**
Widened rather than given a `phase` exception, so the next unbuilt column on the
next table cannot repeat it. **Checked 7 September 2026.**

**On `event`:** `event_type_id` (the FK — `event.event_type` still holds the
vocabulary `value` directly, because a join buys nothing while every
`event.condition_id` is NULL), `awareness_changed`, `aura`, `injury`,
`recovery_seconds`, `witnessed_by`.

**On `event_observation`:** `phase`. **Checked 7 September 2026.** ⛔ **§2 states "`event_observation` carries
a PHASE — during / after" and §7's migration table writes `phase` = `'after'`.
Neither is built: no `phase` column exists anywhere in `lib/`.** The
during/after distinction is therefore **not recorded on any row**, and MER's
observation set remains entirely postictal by convention rather than by data.

**Screens and surfaces:** a **Settings screen**. **Checked 7 September 2026.** §8 settles *"Primary condition
— set in Settings; the first condition added becomes it by default"*. **No
Settings screen exists**, and `event_type.is_primary` is not built either
(§2), so **no condition is primary and nothing selects one.** `ConditionsScreen`
names conditions and assigns types; it does not nominate a primary.

**Migration steps, checked 7 September 2026:** §7's initial-conversion table opens with *"Creates one
condition, 'Epilepsy', `seeded_key` `'epilepsy'`, primary"*. ⛔ **That row is not
built.** The only insert into the `condition` table anywhere in `lib/` is
`addCondition`, which writes `seeded_key` NULL. **So no device has ever carried
a `seeded_key`, and the relevance mapping has never been active on one.**

### Behaviour that diverges from this document

| This document says | The code does |
|---|---|
| §5: quick record writes `condition_id` = the primary condition | Writes NULL. **Checked 7 September 2026: the `condition` table is empty and `event.condition_id` is NULL on every row.** 🔴 **This cell previously ended "there is still no condition to name, and no screen where anyone names one" and that was FALSE — `ConditionsScreen` exists and carries a "Name a condition" affordance.** The capture path genuinely does write NULL, which is why the row survives at all; the justification attached to it had rotted. |
| §5: `event_type_id` NULL until the wizard confirms it | No FK exists. `event.event_type` holds the vocabulary `value` as a nullable string. **The "live defect" recorded here on 27 August — that `eventType` defaulted to `seizure` and `fromMap` coerced an absent key — was FIXED the same day**: both `eventType` and `severity` are now nullable and `fromMap` returns null for an absent key. |
| §1 principle 2: a user may track several conditions at once | 🔴 **THIS ROW WAS FALSE AND IS CORRECTED 7 September 2026.** It read: *"The tables support it; **no UI does.** `ConditionStore`, `loadConditions` and `addCondition` have no caller outside `lib/models/`."* **There are six such callers**: `conditions_screen.dart:46`, `event_wizard_screen.dart:888`, and `home_screen.dart:685`, `:701`, `:745`, `:900`. **A UI does exist** — `ConditionsScreen` names conditions and assigns event types to them. What remains true is narrower: **as at 7 September 2026 no condition carries a `seeded_key`, and `loadConditions` does not filter on `is_active`, so adoption is not yet reversible.** |
| §7: `eventType` medication maps to a `medication_note` | **BUILT** (**v6** — *[read v7 until 7 September 2026]*). `medication_note` is a separate table and record kind, interleaved with events in the CSV by `record_kind`. `medication` as an event type is retired by `retireMedicationEventType`, which also CLEARS `is_protected` — so nothing on a live database is protected, and `setActive`'s protection refusal is now unreachable in the app. |

### What is BUILT that this document never described

**Complete as at 7 September 2026.** ⚠️ **The first four rows were written 28
August 2026 and the section was not revisited; the six below them shipped
afterwards and were absent until now** — which is the same rot the regeneration
trigger above was widened to catch.

| Thing | Note |
|---|---|
| Vocabulary hide / unhide | `is_active` reachable from a UI for the first time — "Your lists", via the Home overflow. `isShippedHidden` separates MER's own retirements, which a user may not reverse, from entries the user hid, which they may. |
| Mis-decoded observation twins | `mangledLegacyObservations()` — shipped rows so a corrupted stored value resolves to a readable label. Present in the vocabulary, deliberately not rendered on the management screen. |
| The delimited CSV | **17 columns, marker `v6`** as at 7 September 2026, multi-stream by `record_kind`. *[This row read "16 columns, marker `v4`" until then. §6 separately read v3 / 14 columns, so the document stated the shape three different ways at once.]* |
| First-run walkthrough | Five steps, four on Windows. Flag stores a version, written on presentation. |
| **`ConditionsScreen`** | Names conditions and assigns each event type to ONE of them, so a record's condition is **derived from its event type** rather than stored. Reached from the Home overflow. ⛔ **This is the surface whose absence two §0 divergence rows asserted.** |
| **`BoundedChipWrap` and the row bound** | Pickers bound by **rows**, not by count — `kCollapsedChipRows = 3` — with a `Show all` / `Show fewer` disclosure. Selected chips, orphans and the add pill are `_pinned` and exempt, **so the bound can never hide what a record already contains.** One picker, wizard step 2, is still unbounded. |
| **Bulk hide and show** | Selection mode on "Your lists": checkboxes, a count, and `Hide selected` / `Show selected`. **Selection spans sections.** Show is deliberately as cheap as hide. |
| **The standing-notification switch** | `kStandingNotificationKey`, default TRUE so no existing install loses the notification. Enforced in `_showNormal` only, **so the active-event notification cannot inherit it.** |
| **Usage-and-relevance ordering** | Pickers order by usage, then relevance, then seed index. See §2 `condition_observation` for the two decisions this embodies. |
| **`occurredAt` backdating** | A nullable "when it happened" on `event`, set through a date then time picker on both capture paths. **A future time is refused, not clamped**; `Clear` restores NULL, meaning *not asked*. `whenHappened` = `occurredAt ?? logged_at`. |

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
| `condition_id` | **NULLABLE. Present since v3, when the vocabulary tables were created; checked 7 September 2026 and now WRITABLE.** ⚠️ *[This cell read "unpopulated as at v9" until 7 September 2026. `v9` dates the SCHEMA, not the check — and that conflation is what let two §0 rows sit false. Both are kept below because they answer different questions: v2 says when the column arrived, the check date says when its contents were last looked at.]* ⭐ **This is the ONE `condition_id` that is populated in practice**: `ConditionsScreen` assigns a condition to an event type through `Vocabularies.setCondition`, which is how a record's condition is DERIVED rather than stored. NULL still means NOT YET SAID. |
| `value` | **ADDED.** The immutable string a record stores. Never changes, for any reason. |
| `name` | Renamed `label` in code: what a person reads. May change; `value` may not. See §2a. |
| `is_seeded` | Seeded entries refuse rename and delete. |
| `is_active` | **ADDED.** Retire, never delete — the entry stays so records referencing it still render. |
| `is_protected` | **ADDED, and now unreachable.** It guarded `medication` until the medication split landed; `retireMedicationEventType` retires that entry AND clears the flag on both the fresh-install and upgrade paths, so **no row on a live database carries it — checked 7 September 2026**. The refusal in `setActive` is kept and tested, and **cannot fire as at 7 September 2026**. |
| `is_primary` | **Not built as at 7 September 2026. No consumer yet** — and no Settings screen in which to nominate one; see §0. |
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
| `condition_id` | **NULLABLE. Present since v3; NULL on every row, checked 7 September 2026.** ⚠️ *[This cell read "unpopulated as at v9" until 7 September 2026, which dated the schema rather than the check; both are kept now.]* ⛔ **And it stays NULL by design** — a record's condition is a function of its event type, which is what let the existing records attribute themselves from one user statement instead of a migration. ⚠️ This cell was BLANK, and the blank was repeatedly read as NOT NULL — which blocked this work for two design reads. The string "NOT NULL" has never appeared anywhere in this document (`grep -c` returns 0, checked 7 September 2026), so the requirement was inherited from nowhere. It is stated explicitly now. NULL means NOT YET SAID, the same rule as `occurred_at`, `details_completed`, duration at creation and the legacy buckets. |
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

⚠️ **Shipped as "Compared with the others here"**, not as recommended below. The
relative framing is the load-bearing part and it survives; "your other events"
named the patient, which the observer-voice pass removed on 29 Aug 2026.
"In this record" was considered and rejected — a record is ONE event, so it
implies a record holds several.

Consider labelling it "Compared with your other events" in the UI so the
relative framing is explicit rather than implied.

Open, not solved: migraine severity is often a **0-10 scale** rather than three
points, so severity's VALUE TYPE may need to vary by condition. Not solved now.
`condition_field` already exists for exactly this kind of variance if it turns
out to be needed, and severity's presentation may become condition-defined.

### observation / event_observation, trigger / event_trigger

Shared vocabularies with many-to-many joins. Each vocabulary row carries
`is_seeded` and `is_active` — **retire, never delete.**

**`event_observation` carries a PHASE** — during / after. Nullable. ⛔ **NOT BUILT as at 7 September 2026: no `phase` column exists anywhere in `lib/`.** The design intent below stands; the column does not. See §0's designed-not-built list.

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

#### ⭐ RELEVANCE SHIPPED AS A CONST MAP, NOT AS ROWS IN THESE TABLES — A DECISION, NOT A GAP

**Recorded 7 September 2026; this document described only the tables until then.**
Relevance ordering is implemented from **`kSeededRelevance`** in
`vocabulary.dart` — a `const Map` keyed on `condition.seeded_key` — and **not**
from `condition_observation` or `condition_trigger`.

⛔ **THE REASON IS THAT NEITHER TABLE CAN BE POPULATED.**

1. **`setConditionFor` throws `VocabularyRuleError` for observations and
   triggers, by design.** There is no writer for the rows. **Checked 7 September 2026.**
2. **No screen assigns them.** `ConditionsScreen` assigns conditions to *event
   types* only.
3. **Nothing carries a `seeded_key`**, so there would be no key to hang a
   relevance row on.

**The reasoning is in the Change Register at L4170 and L4459, built in commit
`ce76d5a`.** The register states it plainly: *"I recommended building
`condition_observation` / `condition_trigger` ordering before seeding. Those
tables cannot be populated."* ⚠️ **`condition.dart` had documented the same
conclusion since v9 and the recommendation was made anyway** — recorded because
the failure was not reading a note that already said so.

**The tables are NOT retired.** They remain the target shape for the day a
condition carries a key and a writer exists; the const map is what serves until
then.

#### ⭐ SECOND DECISION IN THE SAME COMMIT: USAGE OUTRANKS RELEVANCE

**The brief specified relevance first, then usage. It was implemented the other
way round**, and that reversal is deliberate. Ordering is **usage → relevance →
seed index**.

**Why:** relevance-first regresses an established user — an entry they had
recorded twenty times but which is not in their condition's mapping would sink
below entries they had never touched. ⭐ **Usage is evidence about THIS person;
relevance is a prior about people with that condition, and evidence should
outrank a prior.**

**Cold start is unaffected, which is the case relevance exists for:** with no
records every usage count ties, so relevance decides the whole list.

#### ⚠️ WHAT THE MAPPING IS, AND WHAT IT IS NOT

**As at 7 September 2026 `kSeededRelevance` holds ONE key — `'epilepsy'` — mapping
**twelve observation values**, and **no trigger entry at all.** The absence of a
trigger mapping is deliberate: the sourced material covers observations for
epilepsy and sources nothing for the original triggers, and **inventing one from
the entry names is what the sourcing rule forbids.** So the beforehand picker
keeps usage-then-seed order regardless of adoption.

⛔ **THE MAPPING RECORDS ITSELF AS NOT CLINICALLY VALIDATED, AND NO VALIDATION
IS RECORDED ANYWHERE.** The twelve are the *"Proposed epilepsy default"* from
the sourced field-set pass, and that entry says of itself: *"NOT clinically
validated — to be checked against the sourced sets in item 7."* **No such check
exists in any artefact.** Best available; not validated. **Stated here so a later
reader does not upgrade it by forgetting.**

⚠️ **AND IT HAS NEVER RUN ON A DEVICE.** No condition has ever carried a
`seeded_key`, so `relevantFor` has returned an empty set on every install to
date. **Relevance is proved in tests only.**

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
collapsed in the same shape a stage later. **26 → 17 → 11 → 14 → 16 → 17 columns, the last figure being the live one as at 7 September 2026** *[this trail stopped at 14 until then]*. Order
is unchanged: the delimited column sits where its one-hot block sat, and the
three rescue-medication columns added on 27 August sit between `beforehand` and
`referral_required`.

⛔ **THE MARKER TRACKS THE HEADER ROW. Any change to the column set bumps it
— added, removed, renamed or reordered. No judgement about whether a change is
"real".** ⛔ **`kCsvShapeVersion` IN `event_record.dart` IS AUTHORITATIVE. EVERYTHING
IN THIS SECTION ABOUT THE COLUMN SET AND THE MARKER IS A COPY, AND A COPY IS
EXPECTED TO DRIFT.** Read the constant, not this section, whenever the answer
matters.

⚠️ **This is stated because the copy DID drift and said so nowhere.** Until
7 September 2026 this section read *v3 / 14 columns* while the constant read
**v6 / 17**, and §0 read *v4 / 16* — **three different answers in one document,
none of which announced itself as second-hand.** A copy that does not declare
itself is the same failure as an undated absence claim: nothing tells the reader
the statement has a shelf life.

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
    v4   multi-stream: record_kind and medication_kind         16
    v5   condition, derived from the event type                17
    v6   the three time columns mean WHEN IT HAPPENED on       17
         BOTH record kinds. No column added or removed - a
         MEANING change, which is exactly what a shape marker
         is for: a reader computing on column 1 gets a
         different answer, and nothing in the header says so

⚠️ **v4, v5 and v6 were absent from this table until 7 September 2026, which
stopped at v3 / 14 columns. The live marker is `v6` at 17 columns.**

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
| — | Creates one condition, "Epilepsy", `seeded_key` `'epilepsy'`, primary. ⛔ **NOT BUILT as at 7 September 2026, and now entered in §0's designed-not-built list.** The only insert into the `condition` table anywhere in `lib/` is `addCondition`, which writes `seeded_key` NULL. **So no device has ever carried a key, no condition is primary, and the relevance mapping has never been active outside tests.** This row is the mechanism that would have made it live |
| `eventType` seizure / absence / other | `event_type` rows |
| `eventType` **medication** | a `medication_note`, **NOT an event** |
| `timestamp` | `logged_at`. **`occurred_at` stays NULL** — the old value was log time, and pretending otherwise fabricates data |
| `duration` buckets | `duration_seconds` NULL, original bucket preserved. **Do not invent a number from a bucket** |
| `feelings[]` | observation vocabulary rows plus joins, emoji stripped, **`phase` = `'after'`** — every existing entry is postictal, so the mapping is unambiguous. ⛔ **The `phase` half is NOT BUILT as at 7 September 2026** — no such column exists, so the during/after distinction is recorded on no row |
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
| Seeded catalogue | **Epilepsy only** this release. Migraine needs the same research pass; shipping one well beats two thinly. ⚠️ **Superseded in part: the observation vocabulary now carries migraine, panic, presyncope, Ménière's and vertigo entries as at 7 September 2026, while the CATALOGUE — a published list of conditions a user picks from — remains refused.** The two were one decision when this row was written and are now two |
| `medication_note` drug name | **No.** |
| Primary condition | Set in **Settings**; the first condition added becomes it by default. Most users will only ever have one. **Nothing at capture time.** ⛔ **SETTLED BUT NOT BUILT as at 7 September 2026: there is no Settings screen and `event_type.is_primary` does not exist, so no condition is primary and nothing selects one.** Entered in §0's designed-not-built list |

### ⛔ COLD START IS STILL UNANSWERED, AND THE GATE AGAINST SEEDING WAS LIFTED RATHER THAN MET

**Recorded 7 September 2026.** The question is: **what tells MER which of ~34
observations matter to someone who has recorded nothing yet?**

**Nothing derivable answers it.** Usage ordering needs records; relevance
ordering needs a `seeded_key` no device carries. **Only seeded knowledge answers
cold start, and the catalogue that would supply it is refused.**

⛔ **A GATE WAS SET AND THEN LIFTED WITHOUT THE QUESTION BEING ANSWERED.** The
Change Register set it explicitly — *"Nothing from 2 onward should be seeded
until cold start is answered"* — and the sixteen observations were seeded anyway,
**because bulk hide reduced trimming from about sixteen taps to about three and
so changed what a long list COSTS.**

⭐ **That is a real argument and it is not the same as an answer.** The gate
existed because a long unordered list is expensive for a new user; making the
list cheaper to trim lowers the cost of being wrong without making the ordering
right. **Cold start remains open, and the vocabulary is now larger than when it
was named.** Anyone revisiting it should know the gate was moved, not cleared.


---

## 9. Designed for, deliberately not built: daily entries — checked 7 September 2026

⛔ **STILL NOT BUILT as at 7 September 2026.** No `daily_entry` table, no third
record kind, no surface. The genuine structural gap found by the migraine paper
test. Recorded because it is deferred, not rejected.

⚠️ **One requirement below is only PARTLY discharged, and the gap is History.**
Requirement 2 is met — the CSV already carries `record_kind` with two values and
interleaves both streams on one timeline, so a third value is an addition rather
than a break. **But nothing addresses how a third record kind appears in, filters
within, or sorts against the History list**, and `medication_note` sets no
precedent there because it has its own screen rather than a row in History.
**Checked 7 September 2026.**

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
