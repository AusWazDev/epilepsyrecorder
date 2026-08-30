# MER — Session Handover

**Written 30 August 2026, AEST.** For a fresh session picking MER up cold.

> **The artefacts are the record. This document carries only what is not in them.**
> It states where things stand, what was decided and not written down elsewhere, and what a
> new session would otherwise have to rediscover. Where it disagrees with an artefact, the
> artefact wins — except where this document says an artefact is wrong and shows the evidence.

## The artefact map — it is not uniform

| Artefact | Where | How it travels |
|---|---|---|
| `docs/ARCHITECTURE.md` | in the repo | **`git push`** |
| `docs/DATA-MODEL.md` | in the repo | **`git push`** |
| `STATUS.md` | repo root | **`git push`** |
| **Change Register** | `OneDrive\Projects\App Dev\Claude\` | ⚠️ **OneDrive sync. Not a repo path.** Reaches the Mac only if OneDrive is signed in there |

⚠️ **The Register is the largest of the four and the only one outside the repo.** A session that
has the repo does not necessarily have the Register. Check before assuming a decision is
retrievable.

---

## 1. The current task, and its framing

**A design audit of the whole app.**

**The app has never been designed.** It was built feature by feature, each one measured and
correct in isolation, and **the layout was never examined at phone width** until the chip wall
was measured. Nineteen chip rows was not a decision. It is what accumulated.

The developer looked at it on a phone, called it messy from a UI and UX aspect, and asked whether
it warranted a professional design audit.

**Two options were weighed:**

- **(a)** finish the remaining features, then redesign
- **(b)** fix the design now, so the outstanding items are built into the new framework

⭐ **(b) was chosen.** The remainder is not small — `daily_entry` is a whole record kind with its
own screen, plus the unbuilt fields, conditions adoption, monetisation and the release. **Building
that into a layout already thought messy means reworking it twice.**

**The chip wall is the demonstration:** fine on a tablet, invisible until measured at phone width.

**Stated priority: getting it right before deploying matters more than time, without
dilly-dallying.**

### ⛔ Immediate next step — and the capture set does not exist yet

**The tablet screen capture has not run.** `assets/screenshots/` holds five store-listing folders
dated **May 2026** — `app_store_ipad`, `app_store_iphone`, `google_play`, `google_play_phone`,
`windows`. **No capture directory exists**, and nothing under `OneDrive\Projects\App Dev` is newer
than 29 August.

⚠️ **The 323 PNGs in the prior session's scratchpad are NOT the capture set.** They are adb
verification shots taken during that session, in a temp directory — **unreachable from the Mac and
not durable.** Do not treat them as the tablet captures and do not point anyone at them.

**Order of work:** capture every screen on the tablet, then the developer supplies manual iPhone
shots of the screens where width is the point. **The open design decision in section 3 depends on
those captures**, so this is the gate, not a preliminary.

---

## 2. The constraints any design must hold

**These are not preferences.** Each was arrived at and tested, and several were re-derived after
being broken.

- **Capture stays one tap.** Quick-record writes a timestamp and nothing else. **No decision at
  capture time, ever.**
- **Nothing gates a record** — not the wizard, not a condition, not a required field.
- **The vocabulary is unbounded by design.** A layout that works below some entry count is broken
  at every count. Six user entries cost three rows, measured.
- ⛔ **No interpretation.** MER captures, the specialist reads. No charts, no correlation, no
  analysis. **This is the regulatory position and it is load-bearing.**
- **Relevance orders, never filters.** Refused three times. **Hiding a true observation is the
  failure.**
- **The two questions and notes must be reachable** — rescue medication, referral, notes.
  ⚠️ **Notes is the only place a carer records what no chip covers, and it is structurally the
  least reachable field in the app.**
- **Patient-first, carer-capable.**
- **Append-only vocabularies:** values permanent, labels propagate.

---

## 3. Where the chip-wall work stands

**Committed and pushed.**

```
c2f6d80  30 Aug 2026 17:07 AEST  Bound the chip pickers, so the questions under them are reachable
                                 lib/widgets/bounded_chip_wrap.dart   +460
                                 test/bounded_chip_wrap_test.dart     +269
0b8830c  30 Aug 2026 17:10 AEST  Re-measure the form baseline with a database, and correct STATUS.md
```

`git merge-base --is-ancestor HEAD origin` confirms the local branch is **strictly behind origin
with nothing unpushed.**

⚠️ **`git status` read "up to date with origin" before the fetch, and that was false.** See
section 5 — it is the tenth measurement artefact.

### Two call sites, four bounded pickers, one picker unbounded

`BoundedChipWrap` is instantiated in two places: inside `_vocabMultiChips` in
`lib/screens/event_wizard_screen.dart`, and inside `_SelectionWrap` in
`lib/screens/log_event_screen.dart`.

⚠️ **Locate every occurrence rather than trusting a line number.** At the time of writing they sat
at `event_wizard_screen.dart:1000` and `log_event_screen.dart:1086`. **Line numbers rot; the
symbol names are what to search for.**

**Bounded — four pickers:**

- wizard step 3, *"What was happening beforehand?"*
- wizard step 4, *"How were things afterwards?"*
- the single-page form, observations
- the single-page form, beforehand

⛔ **NOT bounded — wizard step 2, "What happened?"** Event types go through `_vocabChips`, which
returns a **plain `Wrap`**, and the grouped variant `_groupedVocabChips` uses a plain `Wrap`
twice. **Four entries today, so it is invisible — and the grouped path is exactly the one a
second condition switches on.**

### Measurements — recorded from the prior session, not re-measured here

| | Before | After bounded pickers |
|---|---|---|
| Wizard step 4, 15 Pro Max | 2.24 screens | **1.03 — solved** |
| Wizard step 4, iPhone 8 | 3.41 | **1.41** |
| Wizard step 3 | 1.37 / 2.27 | **1.00 on both** |
| Single-page form, 15 Pro Max | 3.42 | **2.11** |
| Single-page form, iPhone 8 | 4.97 | **2.75** |

⚠️ **The form's "before" figures are the CORRECTED ones.** An earlier run reported 3.21 and 4.71.
**The form gates its add pill on `Vocabularies.canPersist`, a widget test has no database, so the
pill was absent from the screen being measured — the run reported a layout the device never
renders.** With a database the form's event-type grid also gains an "Add your own" tile, a third
grid row the earlier run never drew. **The fault contaminated the baseline as well as the
projection, and a before/after pair taken under different conditions is not a comparison.**

**The wizard figures were unaffected throughout**, because its add row is not gated on
`canPersist`.

### The state, and the open decision

**The wizard is solved outright.** The form is bounded and structurally sound, **but the rescue
question sits 377pt (15 Pro Max) and 543pt (iPhone 8) below the fold.**

⭐ **OPEN: whether A-on-the-form follows** — moving the two questions above the chips, **on the
form only**.

The standing argument against A is that it **inverts a narrative sequence**. That argument is
**weakest on the form, which is not a narrative** — it is a single page of fields, not a guided
flow. **The developer wanted to look before deciding, and the look depends on the captures, which
have not run.**

---

## 4. What is outstanding

### Built, not designed for

- **`daily_entry`** — IBS is a **daily-diary** condition per Rome IV and does not fit the episode
  model. A whole record kind with its own screen. `record_kind` was deliberately written as a
  three-valued column from the outset so this lands as an addition rather than a breaking change.

### Designed, unbuilt

- **`injury`** — syncope, where falls from standing height are why it matters
- **`aura`** — migraine and epilepsy
- **`laterality`** — Ménière's. ⚠️ **A field, not entries.** "Left ear" as an observation would be
  wrong: laterality is an attribute of a symptom, not a symptom

### Unbounded picker

- **wizard step 2 and the grouped variant**, per section 3

### Conditions adoption — irreversible, for reasons that have changed

**`seeded_key` has no writer.** `condition.dart` writes `'seeded_key': null` inside
`addCondition`, and nothing else assigns it. So a condition a user typed carries no key, and a
relevance mapping cannot attach to it.

⚠️ **`Condition.isActive` IS now read** — in `vocabulary_store.dart`, at
`if (c.isActive && c.seededKey != null)`. **Commit `ce76d5a` made it a reader, correcting the
earlier "parsed and read by nothing" claim**, which was true when it was written and is not true
now.

⛔ **But it is inert in both directions.** `condition.dart` always writes `'is_active': 1`,
`loadConditions` does not filter on it, and the file contains **only `loadConditions` and
`addCondition` — there is no deactivate.** **Adoption remains irreversible.**

**The history, so it is not re-litigated:** the published catalogue was refused, silent matching
was refused, **bulk hide was built instead**, and **the discovery link is unbuilt** — "Your lists"
is still reachable only from the overflow menu, so the person looking at a long picker is the one
person never told they can trim it.

### Excluded, with reasons recorded

- **Cataplexy** — the vocabulary is **actively wrong** for it. Consciousness and memory are
  preserved, so offering `Confused` and `Memory gap` invites a mis-record
- **NEAD** — the label is **contested across five names**, and MER choosing one is not neutral

### Monetisation — untouched

**Free plus optional donation, decided 20 August 2026**, superseding the June freemium plan.
**Nothing is built** — no purchase or donation package anywhere in the repo. **The donation-rule
check has never been done.**

### ⛔ Terms — three references to payment, not two

`notiva-site/src/pages/medical-event-recorder/terms/index.astro`, 103 lines:

| Line | Text |
|---|---|
| `:18` | *"Medical Event Recorder is a paid, one-time purchase app"* |
| `:38` | *"The app is a one-time paid purchase. No subscription or ongoing fee applies."* |
| `:81` | *"limited to the amount you paid for the app"* |

**CLAUDE.md records only the first two.** The third is a **liability cap**, not a promise, which is
probably why it was not counted.

⛔ **It is routed to the adviser and is not a copy edit.** Whether a cap referencing a payment that
never occurred reads as **a cap at zero** or as **inoperative** is a legal question. **This
handover does not resolve it in either direction. Nobody edits that file without the adviser's
answer.**

### Mac only — and these are console state, never assertions

- **Five App Store listing claims** to correct
- **Three empty ASO fields**
- **`availableInNewTerritories: true`**, which nobody chose

⚠️ **Check the console; do not assert any of these from memory or from this document.** They are
what a console said at a point in time.

---

## 5. How this project works

**Chat writes briefs; the CLI executes.** Chat **cannot read the repo, run anything, or verify.**

⛔ **Every claim about the code is a thing to verify, not a fact.** Chat has been wrong about this
codebase repeatedly — including **six invented commit hashes**, and **three findings asserted from
screenshots and disproved by reading**.

⚠️ **In this handover's own verification pass, four of chat's premises were disproved:**

1. the call-site count — three claimed, **two instantiation sites and four bounded pickers found**,
   plus one picker left unbounded
2. `is_active` being read by nothing — **it is read now**
3. the Terms count — two claimed, **three found**
4. the form baseline figures — **superseded by a re-measurement in the same commit series**

### The measurement artefacts

**Nine in the prior session, every one caught by a control and none by reading output:**

- a grep counting lines rather than what it was asked to count
- a staleness check that passed **because it was an ancestor test**
- a shared fixture that **read 32 rows where it had created 2**
- a partial `uiautomator` dump that **read exactly like an ordering failure**
- a widget test **measuring a screen the device never shows**

⛔ **A verification must be capable of failing, and that capability must be demonstrated.**

**The tenth, from this pass:** **`git status` reported the branch up to date with origin, and that
was false until `git fetch` ran.** ⭐ **A status check that has not fetched cannot fail in the
direction it is being trusted to fail in.**

### Two rules that earned their place

⭐ **Device over test, image over dump.** **Every real defect in the prior session was found by
rendering a screen** — not by a passing test and not by an accessibility dump.

⛔ **The register is the record.** A decision that lives only in conversation **reads as done and
is irrecoverable** — which is how the fifteen conditions were lost.
