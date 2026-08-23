# Medical Event Recorder — Target Data Model

**Design only, 22 August 2026. No code written against this yet.**

The target model for multi-condition support: what SQLite gets built against,
and what the migration reads toward. Written before any schema exists, because
expansion changes what a record *is* — designing tables against today's nine
fields would mean migrating twice, and the second migration is the harder one.

> **Not clinically validated.** The field set behind this model was drawn from
> patient-facing charity diaries and Seizure Tracker's published field list, not
> from peer-reviewed literature. See the Change Register entry for 22 August
> 2026 for the sources and their limits. Nothing here should be described to a
> user as clinical, standard, or validated.

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
| `id` | Preserved across migration — see §6. |
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
any other way. Its absence from published diaries reflects that those are
clinical instruments, not that it is useless here. Consider labelling it
"Compared with your other events" in the UI so the relative framing is explicit
rather than implied.

### observation / event_observation, trigger / event_trigger

Shared vocabularies with many-to-many joins. Each vocabulary row carries
`is_seeded` and `is_active` — **retire, never delete.**

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

**No drug name field**, decided on burden grounds; `notes` covers it.

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
`medication_note`) and a common timestamp, so sorting interleaves them — which
is what lets a specialist see a missed dose sitting three days before a cluster.

Observations and triggers become **delimited columns**. Emoji stripped from
**values** as well as headers.

This breaks the current 26-column one-hot format, as already accepted. One-hot
columns cannot survive user-defined options.

**MER does not correlate the streams.** Both go in the file on the same
timeline; the specialist does the reading. Charting missed doses against events
would be interpretation.

---

## 7. Migration

Reads **one shape**: the JSON array under `epilepsy_event_records_v1`. The
simplest migration MER will ever have — which is the whole argument for doing it
now rather than after the model expands.

| From | To |
|------|-----|
| — | Creates one condition, "Epilepsy", `seeded_key` `'epilepsy'`, primary |
| `eventType` seizure / absence / other | `event_type` rows |
| `eventType` **medication** | a `medication_note`, **NOT an event** |
| `timestamp` | `logged_at`. **`occurred_at` stays NULL** — the old value was log time, and pretending otherwise fabricates data |
| `duration` buckets | `duration_seconds` NULL, original bucket preserved. **Do not invent a number from a bucket** |
| `feelings[]` / `triggers[]` | vocabulary rows plus joins, emoji stripped |
| `referralRequired` | legacy column or notes |
| `id` | **Preserved.** Restore matches on id; changing them breaks every existing backup file |

### Non-negotiable

- **Leave `epilepsy_event_records_v1` in place permanently this release.**
- **Write a backup file before migrating.**
- **Verify the row count before marking migration complete**, and fall back to
  the old store if it does not match.

---

## 8. Settled, previously open

| Question | Decision |
|----------|----------|
| Severity | **Kept** — see §2. |
| Seeded catalogue | **Epilepsy only** this release. Migraine needs the same research pass; shipping one well beats two thinly. |
| `medication_note` drug name | **No.** |
| Primary condition | Set in **Settings**; the first condition added becomes it by default. Most users will only ever have one. **Nothing at capture time.** |
