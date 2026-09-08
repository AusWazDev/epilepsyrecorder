# MER — Design Audit

**Written 31 August 2026, AEST.** A whole-app design audit, from the 430×932 capture set at
`715ca95`, the code as it stands this session, and `DESCRIPTION-430.md`.

**Findings are recorded, not repaired. Nothing here was fixed while writing it.**

> ⚠️ **AMENDED 8 September 2026. The statement above is the ORIGINAL and is quoted here
> verbatim, unchanged — it records what the audit was scoped to when it began, and stays
> readable as written. What follows widens it. It does not replace it.**

## ⭐ SCOPE, AS AMENDED 8 September 2026

### 1. Visual and interaction assessment IS in scope

**It was never declared either way.** Checked 8 September 2026 across all 759 lines of the
original: `out of scope` **0 hits**, `in scope` **0 hits**, `aesthetic` **0**, `UX` **0**; the
three `scope` hits were all `FocusScope` / `PopScope`. **The title said "design audit" and that
was the only signal.** This closes that gap.

⭐ **EASE OF ENTRY IS THE PRIMARY CRITERION. VISUAL QUALITY IS THE SECOND.** In that order,
deliberately. The person using this app is often recording minutes after an event — sometimes
one-handed, sometimes a carer rather than the patient, sometimes under stress. **So "can this be
completed under those conditions" precedes "does this look good", and where the two conflict the
first wins.**

### 2. Accessibility conformance is in scope as a MEASURABLE criterion set

**Not as taste.** Four measurable things: **contrast ratios, target sizes, colour-alone
instances, and flash content.** Each is a number or a count, so a finding about it can be
checked rather than argued.

⚠️ **WHY IT IS A REQUIREMENT AND NOT A PREFERENCE — AND THIS NEEDS VERIFICATION.** The
Disability Discrimination Act 1992 has been interpreted as reaching mobile applications, and
Australian Human Rights Commission guidance references WCAG. ⛔ **THAT IS NOT A LEGAL OPINION AND
NOT A COMPLIANCE DETERMINATION.** It is recorded as the reason to treat accessibility as a
requirement rather than a nicety, and **it rests on summaries rather than on the guidance
itself.** ⛔ **Anything that turns on the legal position routes to the adviser** — see §9 — and
must not be settled here. **Marked as NEEDING VERIFICATION as at 8 September 2026.**

### 3. ⛔ THE CAPTURE BASIS, STATED HONESTLY — INCLUDING WHAT IT DOES NOT COVER

**Inventoried 8 September 2026. 89 PNGs plus `INDEX.md`. Pixel dimensions read from each file's
PNG header, never inferred from its filename.**

| | Count | Scale | What it actually is |
|---|---|---|---|
| **Width proxies** | **66** | 1x | **Android on a Teclast P30 tablet, display overridden to an iPhone logical size.** 30 Aug 2026 |
| Real iOS, simulator | 14 | 2x | `ios-se3-sim`, 7 Sep 2026 |
| Real iOS, device | 9 | 3x | `ios-15promax-device`, 7 Sep 2026 |

⛔ **THE 66 REPRODUCE LOGICAL WIDTH, AND THEREFORE WRAPPING AND LAYOUT. THEY REPRODUCE NOTHING
ABOUT iOS RENDERING** — not fonts, not safe-area insets, not the Dynamic Island, not chrome.
**`DESCRIPTION-430.md` has carried that warning in a READ THIS FIRST block since 30 August 2026**;
it is repeated here because it belongs in the scope statement, not only in the transcription.

⛔ **ZERO WINDOWS DESKTOP CAPTURES. Checked 8 September 2026, both grep controls live** —
`windows|desktop|msix|win32` in filenames: **0**; captures wider than 800 logical px: **0**;
widest logical width present: **800**. Control: `ios` in filenames **23**; known-absent probe
**0**. **The app ships on the Microsoft Store, and content is capped at `maxWidth 520` with no
breakpoints anywhere, so DESKTOP LAYOUT IS UNASSESSED** and no finding in this document speaks
to it.

⚠️ **ANNOTATED 8 September 2026 — the claim above is SCOPED TO
`docs/design-audit/captures/` and stays true as written. But the desktop evidence is FOUR MONTHS
OLD rather than absent.** `assets/screenshots/windows/` holds **four PNGs** — `mer-win-1` to
`mer-win-4`, at **1103x927, 1102x922, 1107x928 and 1106x925**, all dated **3 May 2026**. They are
Microsoft Store listing screenshots, not design-audit captures, and they predate the 30 August
capture set by four months and the current code by far more.

⭐ **So a desktop pass does not start from nothing**, which lowers the cost recorded in
§13(q) — there is a known window size, a known aspect, and a precedent for capturing this
target. **DESKTOP LAYOUT REMAINS UNASSESSED**: four store screenshots at one size, taken before
the audit existed, are not an assessment. ⛔ **And §13(x) has since found a
platform-specific reason it matters** — Flutter's 48x48 tap-target floor does not apply on
Windows.

**State-level gaps, all checked 8 September 2026:**

| Gap | |
|---|---|
| `disclaimer` | 375 only — no 430, no 800 |
| `walkthrough` | **step 1 of 5 only** (4 on Windows), 375 only |
| `wizard-3-beforehand` | no real-iOS capture at any width |
| the discard dialog | **no capture at all** — it was built on 8 Sep 2026, after every capture |

✅ **All 12 screens in `lib/screens/` have at least one capture. Denominator derived from disk,
not from a list of expectations.** So there is no screen nobody has photographed; **the gaps are
at width and state level, and that distinction is deliberate rather than reassuring.**

⭐ **THE CONSEQUENCE, AS A RULE THE ASSESSMENT FOLLOWS, NOT AS A CAVEAT:**

> **A finding about LAYOUT or WRAPPING may rest on the proxy set.**
> **A finding about TYPE RENDERING, SPACING AS IT APPEARS, SAFE-AREA BEHAVIOUR or CHROME MAY
> NOT** — it needs a real capture on the platform concerned.
> **Every visual finding names which basis it rests on.**

⚠️ **The existing evidence marks do not cover this.** `Seen directly` says a capture was read; it
does not say whether that capture was a proxy or the real platform. **Naming the basis is an
addition to the marks, not a restatement of them.**

### 4. ⛔ THE BASIS IS 24 COMMITS STALE

**`715ca95`, 30 August 2026 — "Design-audit capture set: 22 layouts at three widths".** Confirmed
as the captures' origin by `git log --diff-filter=A`, not assumed from the scope line.

**As at 8 September 2026 it sits 24 commits behind origin, with 10 `lib/` files changed since** —
including **`log_event_screen.dart`, `home_screen.dart` and `history_screen.dart`, the three
most-captured screens**, two of them changed on 8 September 2026 by the work recorded in §13.

⛔ **So for those three screens the 1x set no longer depicts the current code.** Whether the set
is refreshed before the visual assessment proceeds is recorded as an open question — **§13(q)** —
and is not decided here.

### 5. `DESCRIPTION-430.md` is NOT a scope source

The original names it as one. **It is a transcription**: 31,862 bytes, 318 lines, 22 numbered
per-layout descriptions of the 30 August 1x set, written — in its own words — *"for a reader who
cannot see the images"*. It also serves as the **provenance record** that carries the width-proxy
warning quoted above.

⭐ **It contributed nothing to §13, and the document's own marks show it: no §13 finding carries
the `Described` mark.** Named here as what it is, rather than left standing as an input that
scopes the audit.

### 6. What is OUT of scope, in content terms

**No document previously said this, which is why a reader consulting one had no signal.**

| Out of scope | Where it goes |
|---|---|
| **Diagnosis, prognosis, monitoring, treatment** — anything asserting clinical meaning | **Routes to the adviser** (§9). MER is a data capture tool only, and claim wording is load-bearing |
| **Store metadata** — pricing, category, keywords, description | **Console state**, not app design. Verified in the platform console, never from a note |

---

## ⛔ HOW TO READ THIS: THE EVIDENCE IS NOT ALL THE SAME QUALITY

Every finding carries one of three marks. **A reader who cannot tell them apart will trust them
equally, and they are not equal.**

| Mark | Means |
|---|---|
| **Code-verified** | Checked against the repository this session. Locations re-derived, not trusted from a note |
| **Seen directly** | Read from the captures — four screens at 375, 430 and 800 |
| **Described** | From `DESCRIPTION-430.md`, which was **one reading with a recount, not a blind second opinion** |

⚠️ **Why this matters, from this audit's own drafting.** An earlier draft recommended *"wrap the
filter sheet's chip row"*, on the strength of a **described** observation that the date-range chips
ran off the right edge. **The description was accurate.** The inference drawn from it — that a chip
was therefore unreachable — was not: the row is a deliberate horizontal `ListView` and the chip is
reached by scrolling. **The observation survived; the recommendation was withdrawn.**

⭐ **That is the whole point of the marks.** A described finding tells you what was on a screen. It
does not tell you why, and the gap between the two is where a recommendation goes wrong.

---

## 1. Diagnosis — the chip wall was a symptom, not the problem

**The app has no component vocabulary.** Twelve screens carry roughly a dozen one-off patterns,
each locally correct and none shared. **Every screen was solved; nothing was solved once.**

⭐ **That is why the bounded-picker fix cost two call sites: there was never one picker.** The same
is true of every fix that follows — each will cost as many implementations as the pattern has
copies, and the count is not knowable from any one screen.

**Described.** Four add affordances: a floating button on Medication, inline text on Conditions, a
pill in the wizard and the form, and a tile inside the form's event-type grid. Event types are
**chips** in the wizard and **bordered cards** on the form. Section labels are **sentence case** in
the wizard and the medication sheet, **small caps** on the form, History and Help. The date control
is a **chip** in the medication sheet and a **card with a "Set" link** everywhere else. Destructive
**Delete** and confirmatory **Save** are both filled blue, with **no red anywhere**. "Cancel" is an
outlined button in two places and a text "Keep editing" in the confirm dialog. Dropdowns exist only
on Conditions, a hero band only on About, an accordion only on Help, a floating button only on
Medication.

⚠️ **Correction to an earlier draft.** Severity is **not** a different control kind between the two
paths. **Seen directly**, it is the same pill idiom at a larger size on the form. **Prominence, not
kind** — and the distinction matters, because "different control for the same job" and "same
control at two sizes" call for different fixes.

⭐ **The app already contains its own answer.** `your-data__default` is **two cards built to one
template** — icon, title, body, action — and it is the most internally consistent screen in the
set. **That template generalises**, and a component vocabulary can be derived from it rather than
invented.

---

## 2. The row bound cuts an unranked list

### ⭐ First, plainly: THE BOUND IS RIGHT. Do not remove it.

**Code-verified.** `BoundedChipWrap` bounds **by rows, not by count**. `_rowsOf` packs chips
sequentially by width in list order, and a chip renders only if
`_expanded || rows[i] < _maxRows || _pinned[i]`.

**So list order decides membership of the visible rows, not merely sequence within them** —
promoting an entry pulls it inside the fold and pushes another out. `_pinned` exempts **selected
chips, orphan values a record already holds, and the add pill**, so a picker grows past three rows
rather than ever hiding what the record contains.

**That architecture is correct.** It is the reason the questions beneath the pickers became
reachable at all. ⛔ **Nobody should read this section and plan to remove the bound. The bound is
not the fault. The ranking beneath it is inert.**

### The ranking is inert on the list where the bound bites hardest

**Code-verified.**

| Mechanism | Beforehand | Afterwards |
|---|---|---|
| **Usage** — rank 1, all-time, per record, snapshot at load | **Active — reorders today** | Active, but **every offerable value scores zero** |
| **Relevance** — rank 2, static `const` map | **Inert** — no trigger mapping, and no `seeded_key` writer | **Inert** — mapping exists, no `seeded_key` writer |

**Usage outranks relevance deliberately**, so an entry recorded twenty times cannot sink below one
never touched. **Relevance was built for cold start**, when every usage count ties and it therefore
decides the whole list.

⛔ **Relevance is dormant on every device that can exist.** `addCondition` writes
`'seeded_key': null` and nothing else assigns it, so `_adoptedKeys` is always empty and
`relevantValues` returns the empty set.

> ⚠️ **ANNOTATED 7 SEPTEMBER 2026 — READ THE THREE STATEMENTS ABOVE WITH THIS ATTACHED.**
>
> **Everything above is still true and is left as written.** But three of those statements name the
> missing `seeded_key` writer as the reason relevance is inert — *"no `seeded_key` writer"* in the
> table, *"relevance was built for cold start… it therefore decides the whole list"*, and
> *"dormant on every device that can exist"* — and together they read as pointing at a fix.
>
> ⛔ **RELEVANCE IS NOT THE FIX. It was measured and it changes nothing.** Setting the key on the
> real device produced **0 differing pixels** on this picker at this width against the real 72
> records, with a 13,199-pixel control proving the key was set and the ordering live. **All seven
> entries the bound displays are already among the twelve, so relevance can only reorder an
> already-relevant head.** Relevance is now dormant **by decision, not by omission** — see §10
> recommendation 3.
>
> ✅ **What survives unchanged, and is the correct diagnosis of this section:** the bound is right
> and must not be removed; usage genuinely reorders the beforehand list and genuinely scores zero
> on the afterwards list; and the cause of that zero is the one this section already names — the
> **retired glyph-bearing legacy values**, filtered out as inactive before sorting.
>
> ⭐ **So the live question is the one in §11: whether those retired values can be mapped forward
> to their current equivalents.** That would restore *usage* ranking, which is the only ranking on
> this list that has ever been shown to do anything. **It is now the only live thread on the
> ordering problem.**

⛔ **Afterwards scores zero** because existing records reference the **retired glyph-bearing legacy
values**, which `offerable` filters out as inactive **before** sorting. **So the afterwards list is
in pure seed order, and the three-row bound is cutting it by seed position and label width.**

### The consequence, seen directly

| | Afterwards | Beforehand |
|---|---|---|
| Wizard, 430 *(described)* | 7 of 34 | 8 of 32 |
| Form, 430 *(described)* | 9 of 34 | 9 of 32 |
| **Form, 800** *(seen directly)* | **12 of 34** | **12 of 32** |

⭐ **At 800 the afterwards row reaches `Anxious`, `Angry` and `Irritable`. At 430 it does not.**

**The psychological and behavioural observations are the ones that fall off a phone.** A carer on a
phone is offered a physical vocabulary; the same person on a tablet is offered an emotional one.
**That is a difference in what the record can contain, decided by device width and label length.**

### A standing property, not an incident

**Append-only retirement and usage ranking are each correct and interact badly.** A user's own
history stops informing what they are offered at **any** vocabulary migration, silently, and the
symptom is **a list quietly reverting to seed order** — no error, nothing missing, just a ranking
that no longer ranks.

⚠️ **Any future relabelling does it again**, to whichever entries it touches, and it will present
identically.

---

## 3. The review step reviews nothing

**Seen directly.** `wizard-5-summary` carries the app-bar title **"Check and save"** and,
immediately beneath it, the page heading **"Check and save"** — printed twice with nothing between.

Below that sits the "When it happened" card, then **a single line: "• Duration: not recorded"**,
set as small unstyled text with a literal bullet glyph.

⛔ **That line lists what is missing, not what was entered.** Type, severity, observations,
beforehand and notes are **echoed nowhere before save, in either path.**

The screen is roughly **56 % empty at 430**, **37 % at 375**, and **about three-quarters void at
800** — so the tablet gets the worst version of the app's confirmation screen.

⭐ **The screen titled "Check and save" cannot be used to check, and is the emptiest screen in the
app.** It also carries the least discoverable capability in the app — see §4.

---

## 4. Backdating exists, is well built, and is buried

**Code-verified.** `occurredAt` is set through `showDatePicker` then `showTimePicker`, from
`occurred_at_field.dart`, on **both** paths: inline after Duration on the form, and on the summary
step in the wizard. Range **2020 to now**. It is read by the export, History (six sites), the
backup and the change list.

⭐ **Two implementation decisions are correct and must survive any redesign:**

1. **A future time is refused, not clamped** — *"That time has not happened yet. Nothing was
   changed."* **Clamping would store a time the user did not choose** and show it back as though
   they had.
2. **`Clear` restores null, meaning "not asked"** — not "it happened now".

**Code-verified.** The **iOS native quick-log path writes nothing for it, and that is right** — a
quick-log record is captured as it happens, so "not asked" is the honest value. **The end-drain
rebuild carries the field**, so a backdated record does not lose it when its duration arrives
later.

⛔ **The problem is depth, not presence. The emptiest screen in the app carries the least
discoverable capability in the app.**

---

## 5. The quick-log record is displayed as awaiting repair

**Code-verified.** In `history_screen.dart` the row subtitle is built from:

```dart
if (isIncomplete(r))
  'Needs: ${missingFields(r).join(", ")}',
…
if (r.eventType != null) _EventTypeBadge(type: r.eventType!),
```

`missingFields` is generated **from absent fields** — `duration`, `eventType`, `severity`. So a
timestamp-only record renders as a time, the text **"Needs: duration, type, severity"**, and **no
badge**, where complete records carry one.

That row is the output of the primary action: **one tap, nothing gated, a timestamp and nothing
else.**

### ⚠️ AND THE DESIGN WAS DELIBERATE. THE COUNTER-ARGUMENT IS IN THE CODE

> *"A quick-record shows a timestamp and almost nothing else; in a mixed list that reads as
> variation, but in a FILTERED list of them every row differs only by time and the screen reads as
> broken rather than as a work queue.*
>
> *Naming the gaps turns the list into something a user can ACT on: which row to open, and what it
> will ask. **It is PRESENTATION — the fields are already null and the row already omits them — not
> interpretation.***
>
> *Shown in a mixed list too, deliberately. A row that only explained itself while a filter was on
> would make the filter the only way to understand the list."*

⭐ **That argument is right about the filtered list.** A screen of quick-logs where every row
differs only by time genuinely does read as broken, and the line is what makes it a work queue.

**The disagreement is narrower than an earlier draft of this audit made it.** It is about the
**mixed list** — where the comment itself concedes the rows read as *variation*, and shows the line
anyway to avoid making the filter the only explanation. **The cost of that choice is that a carer
who quick-logs during an event opens History and meets a deficiency notice on the thing they just
did correctly.**

⚠️ **This is a trade between two real failure modes, not an oversight**, and a reader who disagrees
with this audit should be able to see why from the quotation above.

⭐ **A component vocabulary may dissolve the tension rather than resolve it.** A row treatment that
reads as **awaiting detail** rather than **missing fields** would serve the work-queue case without
the deficiency tone — the information is identical and only the register changes. **An observation
about where this might land, not a recommendation.**

---

## 6. Notes is inverted

**Described.** Ranked by depth from the top of its screen:

| | | |
|---|---|---|
| 1 | medication add sheet | two-thirds down, **no scrolling** |
| 2 | wizard step 4 | 78 % down, **no scrolling** |
| 3 | form | **second screen** — a full screen of scrolling first |

**Absent everywhere else, and never echoed before save** in either path.

⛔ **Notes is the only place a carer records what no chip covers.** It is **most reachable in the
secondary feature and least reachable in the primary capture path.**

---

## 7. Home is well composed and loses it with height

**Seen directly.** At **375** this is the best-composed screen in the app: clean hierarchy, one
orange primary, one blue secondary, informational cards descending in weight.

At **430** there is roughly **150 px of void above "Record Event"**. At **800** there is around
**350 px above and 370 px below**, so **the primary action sits below the vertical midpoint** and
**the first thing a tablet user sees on opening MER is empty space.**

⭐ **The content is centred rather than anchored.** A small change with a large effect on first
impression, **and independent of every open decision in this document.**

> ➕ **ADDED 8 September 2026 — a CONSTRAINT on this recommendation, not a replacement of it.**
> **This section's recommendation stands.** §13(e) measures how far `Record Event` MOVES across
> occupancy — `btnTop` 311 → 680, a **369-point range** — and confirms the button is never
> unreachable in any measured state. **This section is about POSITION on an empty screen; §13(e) is
> about MOVEMENT.** Any anchoring change has to hold across that range.
> ⚠️ **The figures are not comparable with the "150 px of void" above** — different measurement
> bases, one a device capture with a status bar, one a widget test without one.

---

## 8. Smaller findings

- **Seen directly.** **Three icon idioms on one screen:** every afterwards chip carries a coloured
  emoji, every beforehand chip carries none, and event-type cards carry line icons. ⚠️ Separately,
  **a tone question never decided explicitly** — the export goes to a neurologist, and the emoji
  are semantically loose (a battery for "Weak" is a metaphor).
- **Seen directly.** **Two selected-states on one screen:** salmon fill with an orange border for
  event type, solid blue fill for severity.
- **Seen directly.** **Orange does three jobs** — the "Record Event" block, the form's selected
  card, and the "62" statistic. On home it means *tap this*; **using it on a figure weakens the
  only strong signal the app has.**
  ➕ **8 Sep 2026 — mechanism now code-verified and the element named: see §13(k).** The "62"
  is the `This month` statistic, orange because
  `valueColor: thisMonth > 0 ? MERColours.alert : MERColours.primary`.
  **This observation stands and gains a cause.**
- **Seen directly.** **Three app-bar patterns:** title plus "Record · Review · Share", title plus
  "Medical Event Recorder", and title alone.
- **Seen directly.** **"Days since" has no referent** — a bare `3` between "Total saved" and
  "Referrals".
- **Seen directly.** **Three product names across the set:** Medical Event Recorder, MER, Notiva.
- **Described.** **"Not set" is internal state used as a group heading**, in wizard step 2 — which
  is also the unbounded picker, and the grouped path a second condition switches on.
- **Described.** **"Show" appears three times with two meanings** on the vocabulary screen in
  selection mode.
- ⚠️ **Code-verified, and a CORRECTION to an earlier draft of this audit.** The filter sheet's
  date-range chips are a **deliberate horizontal `ListView`** (`scrollDirection: Axis.horizontal`),
  **not a clipped row — no chip is unreachable.** What remains is an **inconsistency**: every other
  chip row on that sheet is a `Wrap`, and one of them carries a comment explaining why it was made
  one. **This row alone scrolls.**
  ⭐ **The shape of my error is worth more than the finding.** The description said only that the
  row ran off the edge, which was accurate. **The unreachable chip was an inference I added, and
  the recommendation built on it has been withdrawn.**
- **Code-verified.** **The History delete control has no tooltip, on every row**, so it renders
  `content-desc=""` and a screen reader announces nothing for a destructive action.
  `medication_screen` builds the same control **with** `tooltip: 'Delete'`. ⛔ **An inconsistency,
  not a house style — which is what makes it a defect.** Fixing it also unblocks the one capture
  that could not be taken.
- ✅ **Code-verified, NO DEFECT.** The Help notification card is **Android-only and further gated on
  notifications being allowed**. **Windows gets a replacement section rather than a gap**, with the
  reasoning recorded in the code: *"a Windows user who finds nothing here cannot tell whether the
  section is missing or the feature is absent."* ⭐ **That pattern should be borrowed elsewhere.**
  ⚠️ One real gap: **the switch is hidden when Android notifications are denied**, so the user who
  most needs to discover the setting cannot.

---

## 9. Routed to the adviser, unresolved

- ⛔ **The CSV cannot distinguish a backdated record from a live-logged one.** Seventeen columns,
  all three time columns are `whenHappened`, **no logged-at column**, nothing marking the
  distinction and no way to infer it. `isBackdated` is defined and **has no caller as at 31 August
  2026**. **Recall reliability is clinically material, and the model already holds the fact.**
  ⚠️ **Not resolved by adding a column, because that would be deciding it.**
- **"Days since"** — a derived, unlabelled and emotionally loaded figure, on an app positioned as
  capture-only.

---

## 10. Recommendations, in order

**Decisions first. No code.**

### Three decisions

**1. Does `LogEventScreen` survive?**

**Code-verified, and this replaces an earlier framing of "two capture paths", which was a
mis-description.** They are **two EDIT paths split by record completeness**:

```dart
wantsWizard(r) ? EventWizardScreen(existing: r) : LogEventScreen(existing: r)
wantsWizard(r) => r.detailsCompleted == false || isIncomplete(r)
```

**An incomplete record opens the wizard; a complete one opens the form.** Both call sites pass an
`existing`, so **today it is edit-only by call site, not by construction** — `existing` is
`EventRecord?` with no `required`, so **the screen is one optional argument away from becoming a
genuine second capture path.**

⭐ **The routing itself is the decision worth revisiting.** Whether completeness is the right axis
on which to hand a user two different field orders, two control kinds and two densities is a
question someone should answer deliberately, because **every field added is currently built twice,
in two idioms, for one entity.**

> ✅ **HALF RESOLVED, HALF STILL OPEN — 8 September 2026. The recommendation above is left exactly
> as written; it records what was asked on 31 August.**
>
> ⛔ **THE PREMISE WAS FALSE, AND THAT IS WHY IT RESOLVED THE WAY IT DID.** The question rested on
> *"every field added is currently built twice, in two idioms, for one entity."* **There was never a
> duplicate CREATION path to retire.** As at 8 September 2026, **no production site constructs
> `LogEventScreen` without an existing record** — three call sites, all pass one, and
> `_openLogScreen()` with no argument occurs **0 times**. `_recordWithDetails` routes creation to
> `_openWizard(existing: null)`. See §13(a), §13(m), §13(n).
>
> ✅ **RESOLVED: NOTHING IS RETIRED.** `LogEventScreen` is the deliberate **fast edit path for
> COMPLETE records**, and the code states the reason: *"Stepping a completed record through screens
> to change severity would be worse than the form."* The two screens are two EDIT paths, exactly as
> the text above already says.
>
> ⚠️ **THE DECISION'S HISTORY, RECORDED HONESTLY BECAUSE IT WAS REVERSED.** A decision was taken to
> **RETIRE the form**, on the false premise above. It was **VOIDED — not amended — when the premise
> was disproved by enumerating the call sites.** ⛔ **A record of a decision that was reversed must
> show that it was reversed**, or the next reader inherits the conclusion without the correction.
>
> ⭐ **STILL OPEN, AND SEPARATED OUT SO IT IS NOT BURIED BY THE HALF THAT CLOSED: whether
> COMPLETENESS is the right axis** on which to hand a user two different field orders, two control
> kinds and two densities. **That half was never answered.** It is **DESIGN-TRACK** and belongs with
> the component vocabulary, because the answer decides how many idioms the vocabulary must cover.

**2. How do episode and daily records coexist?** History, the export and the entry point all assume
one kind. **`daily_entry` is not a screen to add** — it is a second record shape that every one of
those surfaces has to accommodate.

> ⏸️ **DEFERRED, NOT OPEN — 8 September 2026. The question above stands as written; only its status
> changes.**
>
> **`daily_entry` is DESIGNED AND DELIBERATELY NOT BUILT**, per `DATA-MODEL.md` §9 — *"Designed for,
> deliberately not built: daily entries"*, checked there 7 September 2026. That section carries a
> **seven-column spec** (`id`, `condition_id`, `date`, `logged_at`, `had_event`, `sleep_hours`,
> `notes`), **three requirements that keep the current design additive**, and the deferral reason:
> *"Daily logging is the most abandoned feature in health apps. It needs its own thinking about
> burden — likely an exceptions-and-prompts design rather than a form."*
>
> ⭐ **So the coexistence question does not need answering until the feature is built.** Requirement
> 2 is already **met**: the CSV carries `record_kind` with two values and interleaves both streams on
> one timeline, so a third value is an addition rather than a break.
>
> ⚠️ **THE GAP THAT IS GENUINELY OPEN, and it is narrower than this decision as written.** Nothing
> addresses **how a third record kind appears in, filters within, or sorts against the History
> list**, and **`medication_note` sets no precedent** because it has its own screen rather than a row
> in History. ⛔ **Already recorded as §13(l) — see it there rather than restated here.**
>
> ⛔ **AND AN ERROR IN REACHING THIS, RECORDED BECAUSE IT IS THE SAME PATTERN THIS DOCUMENT KEEPS
> FINDING.** On 8 September 2026 a conclusion was drawn that `daily_entry` **did not exist**, on a
> single conversational answer, **without checking** — and the opposite error had already been made
> earlier the same day. **The check was queued in a brief and the conclusion was written before it
> ran.** `DATA-MODEL.md` §9 had carried the full spec since before either. See §13(r).

**3. Give `seeded_key` a writer.** ⭐ **This is what conditions adoption was for.** It makes
relevance live, which **fixes cold start and the afterwards list at once**, and it is **smaller
than the layout work.**

⚠️ **And it belongs ahead of the layout work, not after it: a bound cutting a RANKED list is a
different design problem from a bound cutting seed order.** Solving the layout against the current
behaviour would be solving the wrong problem.

> 🔴 **RETIRED 7 SEPTEMBER 2026, ON MEASUREMENT RATHER THAN ARGUMENT.**
>
> **The recommendation above is left exactly as written**, because this document records what was
> recommended on the evidence available on 31 August and **it was sound on that evidence.**
> Rewriting it would make a record of 31 August describe something that did not happen.
>
> **What was measured.** `seeded_key = 'epilepsy'` was set on the device's real condition row and
> the afterwards picker rendered at 430×932 against the real **72 records**, before and after:
> **0 differing pixels.** Same seven entries, same order, pixel-identical.
>
> ⭐ **Against a control that proves the null.** The same build also mapped three
> normally-invisible triggers to `'epilepsy'`; the **beforehand** picker moved **13,199 pixels**
> and those three jumped to positions 2, 3 and 4 — so the key WAS set and ordering WAS live,
> **while the afterwards list moved nothing. 0 against 13,199, same build, same minute.**
>
> **The structural cause.** `kSeededRelevance['epilepsy']` **is** seed positions 1 to 12, and the
> three-row bound displays positions 1 to 7 — so **all seven entries already visible are already
> among the twelve.** Relevance can only reorder an **already-relevant head**, and with every
> usage count at zero the tiebreak is **seed index**, which is the order already on screen.
>
> ⚠️ **This was the GENEROUS case, so the result generalises rather than being specific to this
> device.** Usage is inert on the afterwards list, so relevance decided it **in isolation** with no
> competing signal. **Any real usage history makes relevance matter LESS, not more.**
>
> ⛔ **So the second claim above — "fixes cold start and the afterwards list at once" — is false,
> and the sequencing claim beneath it falls with it: the bound is NOT cutting a rankable list that
> merely lacks a writer.** `seeded_key` gets no writer; `activeConditions()`, the `is_active`
> writer, the deactivate control and the `DATA-MODEL.md:481` migration row are all retired.
> `kSeededRelevance` and the comparator stay in place, **built, correct, tested and deliberately
> unactivated.**
>
> **Full treatment: `STATUS.md`, session of 7 September 2026 (Windows), and the Change Register,
> entry of the same date. The Register does not travel by `git push`.**

### Then the component vocabulary

One add affordance · one selection control per cardinality · one label case · one date control ·
**one destructive treatment visually distinct from confirmation** · one disclosure · one icon
idiom.

**Built from the `your-data` template**, which already exists and already works.

⭐ **This is the redesign, and it is what makes `injury`, `aura` and `laterality` cheap to add
rather than expensive.**

### Then six fixes that depend on none of the above

1. **Stop rendering quick-log records as deficient** — see §5 for the counter-argument that must be
   answered, not bypassed.
2. **Give the summary step a real summary**, and surface backdating properly on it.
3. **Raise notes, and echo it before save.**
4. **Anchor home rather than centring it.**
5. **Bound wizard step 2**, both the plain and the grouped paths.
6. **Label the delete control.**

*(An earlier draft listed seven. "Wrap the filter sheet's chip row" was withdrawn — the row scrolls
deliberately and nothing is unreachable.)*

### Then the layout work

**With decisions 1 to 3 answered.** ⭐ **Which is why option (b) beat option (a):** the outstanding
features are not small, and building them into a layout already thought messy means reworking them
twice.

---

## 11. Open question, not for this pass

**Whether the retired legacy values can be mapped forward to their current equivalents.**

That would **restore usage ranking on the afterwards list** for this user and for anyone carrying
history across the migration. **Append-only means the old values still exist**, so it may be
tractable.

⚠️ **A question, not a proposal.** It touches stored values in every historical record, which is
the one thing this project has consistently refused to do.

---

## 12. ⭐ What is working, and must survive the redesign

**This document is almost entirely defects, and that is a distorted picture of an app where several
hard things are right.** A redesign that does not know what to preserve will break them.

- ✅ **The future-time refusal.** `OccurredAtField` **refuses** a future time and says so, rather
  than clamping it to now. **Clamping is how a wrong value becomes a plausible one.**
- ✅ **`Clear` means "not asked", not "now".** The distinction between an absent answer and a
  default is carried correctly through the whole model, and it is the reason the export can be
  trusted.
- ✅ **The Windows replacement section.** Rather than hiding the notification help on a platform
  that has none, Windows gets a section saying so — because *"a user who finds nothing here cannot
  tell whether the section is missing or the feature is absent."* **Borrow this pattern.**
- ✅ **`your-data`'s two-card template.** Two parallel cards, one job each, the difference between
  them stated in the body text. **The most internally consistent screen in the app, and the seed of
  the component vocabulary.**
- ✅ **Usage outranking relevance.** Evidence about this person beats a prior about people with the
  condition. **The ordering is right even though it is currently inert on one list.**
- ✅ **The row bound itself.** See §2 — it made the questions beneath the pickers reachable, and
  `_pinned` means it can never hide what a record already contains.
- ✅ **Home at 375.** The best-composed screen in the app. **The composition is right; only its
  behaviour at height is wrong.**

⛔ **None of these is an accident, and several were re-derived after being broken once. The
redesign's first job is to not lose them.**

---

## 13. Session findings — 8 September 2026

**Discovery, not repair.** Nothing below was fixed while writing it, per this document's standing
rule. **Every claim here was CHECKED on 8 September 2026**; the dates are when the check ran, not
when the thing was introduced.

⚠️ **Three of these correct or qualify earlier text. None replaces it.** Where an earlier section
is affected, this one points at it and the earlier wording stands.

### (a) 🔴 `LogEventScreen` discards edits silently — a live defect

**Code-verified, 8 Sep 2026.**

```dart
void _cancel() {
  FocusScope.of(context).unfocus();
  Navigator.pop(context);
}
```

Wired to the app bar's back arrow — `leading: IconButton(icon: Icons.arrow_back, onPressed: _cancel)`.
⛔ **No confirmation, and no `PopScope` on the route, so the OS back gesture and the Android
hardware back do the same thing.**

⚠️ **There IS a confirm dialog, and it fires on the wrong event.** `confirmOnSave && !_isNew` shows
*"Save the following changes?"* — **it protects against saving, not against losing.**

⛔ **THE AFFECTED POPULATION IS EVERY COMPLETE RECORD.** `wantsWizard` routes incomplete records to
the wizard and complete ones here, so this is the edit path for every record a user has finished.

**Recorded as a defect, not a design preference.** The screen offers a Cancel affordance and a Save
affordance; a user who has typed into it and presses back has no signal that the two differ.

> ➕ **ADDED 8 September 2026 — the SIZING above is corrected, and this finding now has a
> prerequisite.**
>
> ⭐ **A complete dirty check ALREADY EXISTS and this finding did not know it.** `_hasChanges`
> (`:213`) compares **eleven** fields against an `_orig*` snapshot taken in `initState` (`:191-202`),
> and it handles all three awkward cases correctly: duration is normalised to an int through
> `_enteredSeconds` before comparing, the two chip sets use an order-independent `_sameSet`, and
> notes is `.trim()`ed on both sides. `occurredAt` compares `DateTime?` directly, so **"not asked"
> stays distinct from a cleared value.**
>
> ⛔ **It is already wired — but to `_save()` (`:301`), not to any exit.** So the finding above
> stands exactly as written; only its COST changes. **The remaining work is a `PopScope` and a
> dialog, not building the check.**
>
> ⚠️ **PREREQUISITE — see §13(m).** `_buildChangeList()`, the natural content for that dialog,
> **omits the three rescue fields.** Reusing it here inherits that gap. **(m) is fixed before or
> with (a).**

✅ **FIXED 8 September 2026, after §13(m). 13 widget tests in `test/log_event_exit_test.dart`,
each mutation-proven.** The finding above stands as written. Shape delivered: a clean exit leaves
immediately with no prompt on either button and on the OS pop; a dirty exit prompts on all three;
`confirmOnSave` is untouched. All three exits now funnel through `_cancel`, and a `PopScope` routes
the OS pop into it.

⭐ **THE FIRST THING THE FIX FOUND, AND IT IS THE DEFECT SURVIVING INSIDE ITS OWN REPAIR.** The
obvious implementation is `canPop: !_isDirty`. **It would have kept the bug.** `canPop` is
evaluated in `build`, and the notes `TextField` **has no `onChanged`** — see §13(o) — so typing a
note changes `_hasChanges` **with no rebuild at all**. A build-time `canPop` would still have read
"clean", and the OS back gesture would have discarded that note silently. **Implementation is
`canPop: false` with dirtiness evaluated at POP time**, which is always current. A re-entrancy
guard came with it, because every OS back now routes through `_cancel`.

⭐ **THE SECOND, AND IT IS AN ARGUMENT ABOUT HOW TO VERIFY, NOT ABOUT THIS SCREEN.** Removing the
`PopScope` and re-running breaks **only** the OS-back test and the storage test. **Every
button-based test still passes.** So a fix verified by tapping the back arrow and the Cancel button
— the natural way to test this — would have reported success with the OS path still completely
unguarded, which is the half of the finding that mattered most. **The test that proves a fix must
exercise the path that was broken, not the paths that were merely nearby.**

⚠️ **`_isNew` is UNREACHABLE IN PRODUCTION** — both constructions pass `existing`, and
`_openLogScreen()` with no argument occurs **0 times**; it is reached only by
`bounded_chip_wrap_test.dart`. Since `_hasChanges` returns true unconditionally when `_isNew`,
reusing it for the exit would have prompted on an untouched blank form. The exit therefore gates on
**`_isDirty = !_isNew && _hasChanges`**. ⛔ **Recorded as a DECISION, not a derivation** — production
cannot reach that branch, so nothing in the code settles what it should do. `_hasChanges` itself is
unchanged.

### (b) Exit behaviour is not uniform, and the wizard already has the right pattern

**Code-verified, 8 Sep 2026.** Exactly one `PopScope` exists in `lib/` — `event_wizard_screen.dart`:

```dart
Future<bool> _onWillPop() async {
  if (_draft != null || _hasAnyInput) _capture();
  Navigator.pop(context, _draft);
  return false;
}
```

⭐ **IT PRESERVES RATHER THAN BLOCKS. Capture and leave — no dialog, nothing obstructed.** Its own
comment records why: backing out previously discarded the current step, and *"the 'needs details'
queue makes it the PRIMARY path rather than an edge."*

⚠️ **And the condition is deliberately narrow:** *"opening the wizard on a NEW event and closing it
without touching anything must still create NOTHING."*

⭐ **THIS IS THE PRECEDENT, AND IT IS THE CORRECT ONE FOR THIS APP.** It satisfies the standing rule
that nothing gates capture, the record, or export — a confirm dialog on exit would gate exactly
that. **Any fix to (a) should follow this pattern rather than introduce a dialog.**

**Seven other top-level screens carry no guard of any kind, checked 8 Sep 2026.** *(A search that
finds the wizard's guard is the control: this is a real absence, not a search that missed the
widgets.)*

### (c) There is no shared navigation shell

**Code-verified, 8 Sep 2026.**

| | Count |
|---|---|
| Screens in `lib/screens/` | **12** |
| `Scaffold(` per screen | **1 each** (home has a second, the splash spinner) |
| `AppBar(` per screen | **1 each** |
| Shared shell / wrapper / scaffold widget | ⛔ **none** — `lib/widgets/` holds `bounded_chip_wrap`, `mer_icon_widget`, `occurred_at_field` |

*Controlled: three non-screen files return 0 Scaffold / 0 AppBar, so the uniform per-screen count
discriminates rather than being a matching artefact.*

**Navigation is imperative throughout** — 11 × `Navigator.of(context).push(MaterialPageRoute(...))`.
**No named routes, no route table, no router package.** The only two `pushReplacement` calls are
gate transitions (disclaimer → home, splash → disclaimer/home).

⛔ **CONSEQUENCE: any control added to every screen is N separate changes with nothing enforcing
consistency.** A control present on eleven screens and absent on the twelfth is worse than one
present only on home, because the absence reads as a dead end rather than as a boundary.

### (d) `_hasUnsavedEvents` is a storage-failure flag — a naming defect

**Code-verified, 8 Sep 2026.**

```dart
/// Whether a previous write of the event list failed and has not since succeeded.
Future<bool> hasUnsavedEvents() async { ... }
/// Records that events are in memory but not in storage.
Future<void> setUnsavedEventsWarning() async { ... }
```

Persisted as `mer_unsaved_events`, so it survives a relaunch. ⛔ **It means a WRITE TO DISK FAILED.
It has nothing to do with unsaved edits in a form or a wizard.**

⭐ **Recorded as a naming defect rather than a code defect, because the code is correct and the word
is not.** Two unrelated mechanisms share "unsaved", and during this session the flag was read as
edit-state protection more than once on the strength of the name alone, by someone who had the code
available. **The behaviour is right; the label invites the wrong inference.**

### (e) Home occupancy — the button MOVES 369 points and is never unreachable

**Code-verified by measurement, 8 Sep 2026. This QUALIFIES §7; it does not replace it.**

⛔ **§7's recommendation stands.** §7 is about the button's POSITION on an empty screen. This is
about its MOVEMENT across occupancy. **Different claims — this one adds a constraint.**

Eight states, **430×932 logical points, `devicePixelRatio 1.0`, one state per process:**

```
state                        occupants                  btnTop  btnBottom  maxScroll
A none                       —                           311.0     424.0      0.0
B backup reminder            backup                      354.0     467.0      0.0
G active event               active                      367.0     480.0      0.0
C storage fallback           storage                     426.5     539.5      0.0
H unsaved write              unsaved                     441.5     554.5      0.0
D storage+unsaved            storage+unsaved             568.0     681.0     22.0
F storage+unsaved+12 recs    storage+unsaved             568.0     681.0    151.0
E storage+unsaved+active     storage+unsaved+active      680.0     793.0    134.0
```

⭐ **`btnTop` ranges 311 → 680 — a 369-point range in a 932-point viewport.** At maximum reachable
occupancy the button ends at **793, leaving 139 points of clearance.**

✅ **THE BUTTON IS NEVER UNREACHABLE AND NEVER REQUIRES SCROLLING, IN ANY MEASURED STATE.** The
layout is `SingleChildScrollView` → `ConstrainedBox(minHeight: viewport − 40)` → `Center`, so
centring is computed against `max(viewport − 40, content)` and the column scrolls once content
exceeds the viewport.

⚠️ **NOT MEASURED, AND NOTHING DEPENDS ON IT.** It was reasoned during this session that centring
*halves* the movement a top anchor would produce. **No top-anchored layout was ever built or
measured, so that is unverified reasoning and is recorded here only so it is not later mistaken for
a result.**

⚠️ **MEASUREMENT GAP.** The harness ran with `Platform.isWindows == true`, which structurally
suppresses **both** `_SettingsNudgeCard` chain members ("Notifications are off" needs
`!Platform.isWindows`; "Show Previews" needs `Platform.isIOS`). **The maximum is established only
among the three chain members reachable on Windows**, and neither nudge card was measured.

⚠️ **The numbers are NOT comparable with §7's "roughly 150 px of void".** §7 measures void above the
button on a device capture with a status bar; these are absolute window coordinates in a widget test
without one. **Different bases — do not subtract one from the other.**

⭐ **HARNESS METHOD, recorded because two configurations produced convincing wrong numbers before
this one.** Seven states in one `testWidgets` reported an identical `btnTop` for all seven. Splitting
into one test per state fixed only the storage case — the prefs-driven states still reported an
identical figure, because **`SharedPreferences.setMockInitialValues` does not take effect once an
instance has been created earlier in the same file.** Only **one state per process** produced
distinct results. **A uniform set of measurements looked exactly as convincing as a correct one.**

### (f) The unsaved banner and the backup reminder cannot co-occur

**Code-verified, 8 Sep 2026.** `!_hasUnsavedEvents` is one of the six conjuncts of
`_showBackupReminder`, so a device with a failed write **never** shows the backup reminder.
Observed in measurement state F above: configured with both, only the unsaved banner rendered.

**Undocumented anywhere as at 8 Sep 2026.** Recorded because the two occupy the same region and a
reader enumerating that region would otherwise expect them to stack.

### (g) The 2.11 screenful figure lacks provenance

**Code-verified against the documents, 8 Sep 2026.** Recorded at `SESSION-HANDOVER.md:135`
(*"Single-page form, 15 Pro Max | 3.42 | 2.11"*) and `STATUS.md:591`.

| Attribute | Recorded? |
|---|---|
| Platform | ✅ "15 Pro Max" — a device name, implying 430×932 logical points |
| Picker state | ✅ "After bounded pickers" |
| **Rescue expanded or collapsed** | ⛔ **not stated** |
| **Device or widget test** | ⛔ **not stated** |

⛔ **So it cannot be compared against a rescue-expanded figure**, because nobody recorded which one
it is. **Annotated where recorded; not deleted** — it is the only measurement of that screen's height
that exists.

### (h) 🔴 The backup banner frames backup as device transfer

**Seen directly, 8 Sep 2026.** The reminder reads: *"Your events are stored only on this device. A
backup is the only way to get them onto another one."*

⛔ **BACKUP IS THE PRESERVATION PATH, NOT A TRANSFER PATH.** Restore on a fresh install merges
against an empty list and reconstructs what an uninstall destroys — that is what the file is for.

⭐ **A user with one device reads this and concludes it does not apply to them.** That is precisely
the user for whom losing the phone means losing every record. **The copy describes the least
important thing the file does.**

*This corrects an error this document itself made on 31 Aug — see §9's annotation on the
preservation path, where "export is the only preservation path" was recorded and later withdrawn.
The banner's copy carries the same misconception the audit did.*

### (h-ii) Four capture-derived vocabulary items, deferred as one

**Seen directly, 8 Sep 2026. Recorded as ONE item because they share a cause** — no component
vocabulary — **and would be fixed by the same pass rather than four.** They belong with §10's
component-vocabulary work.

- **Yes/No swaps sides between adjacent questions** on the same screen.
- **"Other / custom" sits adjacent to "Add your own"** — two affordances, one job.
- **Three chip vocabularies on one screen.**
- **Emoji render differently across the three platforms shipped to**, and the simulator misrenders
  them again — so the same record looks different on iOS, Android and Windows.

### (i) The drawer request — DESIGN-TRACK, not scheduled

**Code-verified, 8 Sep 2026.** The home overflow holds **seven items, none conditional**
(`itemBuilder` returns a `const` list): History · Medication · What you track · Your lists · Your
data · About · Help. **It appears on home only** — one `PopupMenuButton` in `lib/`.

⛔ **DEPENDS ON (b) AND (c) BEING RESOLVED FIRST.** A drawer adds an exit to every screen it appears
on, and seven of those screens have no exit guard; and with no shared shell it is N changes with
nothing enforcing consistency.

⚠️ **AND TOP-LEVEL RESTRICTION DOES NOT BOUND THE NAVIGATION STACK.** Every destination is
`Navigator.push`, so reaching Help from History via a drawer leaves Home → History → Help. **The
current mechanism offers no protection; it is bounded today only because the menu exists on one
screen.**

### (j) `logged_at` is used where `whenHappened` is arguably meant — one pattern, three sites

**Code-verified, 8 Sep 2026.** The data model defines `whenHappened = occurredAt ?? logged_at`.
**Each of these silently uses the fallback as though it were the value:**

| Site | What it does |
|---|---|
| `eventsSinceLastBackup` | filters on `r.timestamp` — counts by when a record was TYPED |
| `_thisMonthCount` (`home_screen.dart:504`) | filters on `r.timestamp` — same |
| the CSV | ⛔ carries **no logged-at column at all**; all three time columns are `whenHappened` |

⭐ **Recorded as ONE pattern rather than three notes.** A backdated record counts in the month it was
entered, contributes to a backup reminder by entry time, and then exports with only its occurrence
time — **so the value the app COUNTS by is the one value the export does not carry.**

⚠️ **FORWARD-LOOKING RISK, NOT A CURRENT VIOLATION.** `DATA-MODEL.md` §9 requirement 3 — *"Any
'events this month' figure must be written so a denominator can be added later without changing its
meaning"* — **is MET as written**: the figure is a numerator presented as a numerator, and adding
"of 30 days" would not change what the existing number means. **But that denominator would be
days-in-month, an occurrence-time frame, against a logging-time numerator.** Recorded so the
mismatch is visible before the denominator is built, not after.

### (k) "This month" renders in alert colour whenever it is non-zero

**Code-verified, 8 Sep 2026.**

```dart
valueColor: thisMonth > 0 ? MERColours.alert : MERColours.primary,
```

⭐ **THIS IDENTIFIES THE "62" IN §8.** That bullet recorded, seen directly, that *"orange does three
jobs"* and that *"using it on a figure weakens the only strong signal the app has."* **The mechanism
is now code-verified and the element is named: it is the `This month` statistic, orange because the
count exceeded zero.** §8's observation stands and gains a cause.

⚠️ **And there is a second reading, which is why this is recorded separately.** The app is positioned
as a **capture tool and never diagnostic**. A count rendered in alert colour is **an editorial
reading of a statistic** — the app telling the user that a number is bad. One event this month is
orange; zero is not.

**Recorded as a positioning finding, not a defect.** Whether a capture-only tool should colour a
count at all is a claim-wording question of the kind §9 routes to the adviser.

### (l) How a third record kind appears in History is unaddressed — DESIGN-TRACK

**Read from `DATA-MODEL.md` §9, 8 Sep 2026.** Recorded here so the gap is visible from the design
side rather than only the data-model side. ⛔ **Not restated — see §9 of `DATA-MODEL.md` for the
column spec and the three requirements it places on the current design.**

The open half, in that document's words: *"nothing addresses how a third record kind appears in,
filters within, or sorts against the History list"*, and **`medication_note` sets no precedent
because it has its own screen rather than a row in History.**

⭐ **Belongs with the component vocabulary in §10**, not with the layout work: it is a question about
what a row means when the list holds more than one kind of thing.

### (m) 🔴 The save confirmation omits the rescue fields — a live defect

**Code-verified, 8 Sep 2026.** `_hasChanges` (`log_event_screen.dart:213`) checks **eleven** fields.
`_buildChangeList()` (`:233-287`) covers **eight**. **Rescue given, rescue helped and rescue second
dose are absent from the list and present in the check.**

```
rescue mentions in _hasChanges     (213-226):  3
rescue mentions in _buildChangeList (233-287): 0   <- control, same search shape
```

⛔ **THE CONSEQUENCE.** Edit ONLY a rescue field on an existing record and press Save with
`confirmOnSave` true. `_hasChanges` returns true, so the no-op guard passes and the
*"No changes to save."* short-circuit does not fire. The dialog then renders
*"Save the following changes?"* above an **empty list**. **The user confirms a change the dialog
does not name.**

⭐ **THE CLINICAL WEIGHT IS THE POINT, AND IT RUNS THE WRONG WAY.** The three omitted fields record
**whether emergency medication was given, whether it helped, and whether a second dose was
needed.** They are among the most consequential fields in the app, and they are precisely the ones
the confirmation does not name. The eight fields it does name include notes and chip selections.

⚠️ **LIVE IN THE PUBLISHED VERSION. Not introduced by any pending fix**, and not a consequence of
this session's work. `confirmOnSave` and `_buildChangeList` both date from `0de48d1`, 21 March
2026 — a large mixed commit whose message does not mention either.

⚠️ **CONSEQUENCE FOR (a), AND IT ORDERS THE TWO.** `_buildChangeList()` is the obvious content for
the discard prompt (a) needs — it is the only per-field diff renderer in the file. **An exit prompt
reusing it inherits this gap**, and would then omit the rescue fields from a *discard* warning as
well as a save one. **(m) must be fixed before or with (a), not after it.**

⚠️ **INFERRED, NOT REPRODUCED.** The empty-list outcome is **derived from the two functions' field
coverage**, not observed at runtime. The field counts and the zero/three control above are
code-verified; the rendered empty dialog is not. **No device reproduction was attempted** — it
would require editing one of the 72 real records.

✅ **THE MARK ABOVE IS DISCHARGED, NOT DELETED — 8 September 2026. REPRODUCED, then FIXED.**
The inferred mark stands as written because it records what was known when the finding was made,
and the distinction between derived and observed is the point of the marks.

**Reproduced in a widget test, on the unpatched code**, in `test/rescue_change_list_test.dart`:

    Actual: _TextContainingWidgetFinder:<Found 0 widgets with text containing
            Rescue medication: []>
     Which: means none were found but one was expected

⭐ **The dialog OPENED and the list was EMPTY — exactly the two halves the finding predicted.**
`Confirm changes` was found, `No changes to save.` was not, so `_hasChanges` saw the edit and the
no-op guard did not fire. ⛔ **And tests 4 and 5 PASSED on that same unpatched run** — the negative
control and the regression control — so the three failures were the defect and not a dead harness.
Whole run: **`+2 -3` before, `+5` after.**

**FIXED 8 September 2026.** Three entries added to `_buildChangeList`, before the referral block,
matching the form's own order. Coverage now, counted in both functions:

| | fields covered |
|---|---|
| `_hasChanges` | **11** |
| `_buildChangeList` | **11** |

⚠️ **The enum needed its own treatment.** `_rescueHelped` is three-valued, so it renders
through `rescueResponseDisplay(...) ?? 'not recorded'`, the same shape severity and event type
already use. **A boolean rendering would have read `Yes → No` and lost `Partly` entirely.** The two
`bool?` fields use a local `yn` helper rather than `? "Yes" : "No"`, because **null is "not asked"
here, not "No"** — referral is a plain `bool` and these three are not.

### (n) `ARCHITECTURE.md` §3's table membership is wrong for more than one row — OPEN STRUCTURAL QUESTION

**Code-verified, 8 Sep 2026.** The table is titled **"Record creation — sites across three
runtimes"**. At least four of the things in or missing from it are not record creation.

| | Why it is not record creation |
|---|---|
| **Row 2** `log_event_screen.dart` | No production call constructs it without an existing record. Three call sites, all pass one; `_openLogScreen()` bare occurs **0 times**. It is the EDIT path. Recorded in §13(a) and annotated in `ARCHITECTURE.md` itself |
| **Row 6** `handleQuickLogStart` | Posts a START **fact** to the capture inbox — one `mer_inbox_<uuid>` key. Builds no record and reads no list |
| **Row 7** `EndMEREventIntent` | Posts an END **fact**. Its own source comment: *"This extension now has no knowledge of the record list at all"* |
| **absent** `handleQuickLogEnd`, `endActiveEventFromApp` | Post END facts. **In the code, not in the table** |

⭐ **The distinction is real and load-bearing, not pedantry.** A fact is materialised into a
record **later, by the Dart main isolate, using whatever the defaults are at drain time** — not
at the moment the fact is posted. `handleQuickLogStart`'s own comment records that the seven
defaults it used to invent *"are the drain's business now"*. **So the row's Runtime and Writes
columns describe a process that never creates a record, under a heading that says it does.**

⛔ **RECORDED AS OPEN. No answer proposed.** What that table should be titled and scoped is a
structural decision — whether it becomes a write-sites table with a creation column, whether
fact-posting sites belong in it at all, whether the two absent sites are added — and none of
that has been decided. **This finding exists so the question is visible, not to settle it.**

⚠️ **The rows themselves are now correct even though the membership is not.** Rows 6 and 7 were
corrected in place on 8 September 2026 with their superseded wording quoted verbatim beneath the
table; row 2 was annotated on the same date. **Membership is the residue after the factual
errors were fixed** — it is not a restatement of them.

### (o) The notes field triggers no rebuild — OPEN, NOT INVESTIGATED

**Code-verified, 8 Sep 2026.** The notes `TextField` in `log_event_screen.dart` has **no
`onChanged`**, so nothing rebuilds when its content changes. Its two siblings do:

| Field | Rebuilds on typing? |
|---|---|
| duration minutes | ✅ `onChanged: () => setState(() {})` |
| duration seconds | ✅ `onChanged: () => setState(() {})` |
| **notes** | ⛔ **no `onChanged` at all** |

⭐ **Found only because §13(a)'s fix depended on it.** A build-time `canPop: !_isDirty` would have
read "clean" while a note sat unsaved, and the OS back gesture would have discarded it — the same
defect, inside its own repair. **The fix works around this rather than correcting it**, by
evaluating dirtiness at pop time instead of in `build`.

⚠️ **THE OPEN QUESTION, RECORDED AND NOT ANSWERED: does anything else on this screen depend on a
rebuild that a note edit does not trigger?** ⛔ **Not investigated.** The `canPop` case is the one
instance that was looked at, because something else forced it into view. **Nothing here says it is
the only one**, and the asymmetry with the two duration fields is unexplained rather than known to
be deliberate.

---

### (p) `Yes` appears four times on one screen, across three different questions — VOCABULARY, DESIGN-TRACK

**Code-verified, 8 Sep 2026.** `rescueResponseLabel` returns **`Yes` / `Partly` / `No`** — the same
two strings the adjacent boolean rows use. With the rescue children visible, `log_event_screen.dart`
renders:

| Question | Answer set |
|---|---|
| Rescue medication given? | Yes · No |
| Did it help? | **Yes** · Partly · **No** |
| Was a second dose needed? | Yes · No |
| Medical referral required? | Yes · No |

⭐ **So `Yes` is on screen four times, and one of those four sits in a three-valued set.** A user
scanning a column of Yeses across questions that do not share an answer shape has nothing in the
labels to tell them apart — and this screen is read under exactly the conditions where scanning
replaces reading. **The middle question is the one that differs, and it is the one whose answer
carries the clinical weight** (§13(m)).

⚠️ **Recorded as a vocabulary question, not a defect.** The values are correct and the CSV is
unaffected — `rescueResponseCsv` writes the same labels and a blank for unanswered. **What is open
is whether "Did it help?" should answer in its own words** rather than borrowing the yes/no pair.
⛔ **No wording proposed here.** It belongs with the component vocabulary work in §10.

⚠️ **It also had a testing consequence, which is how it surfaced.** `test/rescue_change_list_test.dart`
cannot find a rescue control by its text: only `Partly` is unique. Every finder there is scoped to a
**row** and asserts the expected row count before tapping by index, so a layout change fails loudly
instead of silently tapping a different field. **A label collision that forces tests to navigate by
position is a signal about the labels, not only about the tests.**

### (q) Whether the capture set is refreshed before the visual assessment proceeds — OPEN

**Checked 8 Sep 2026.** The amended scope statement admits three separate weaknesses in the
basis, and this finding exists so the decision about them is visible rather than implicit.

| Weakness | |
|---|---|
| **Staleness** | `715ca95` is **24 commits** behind origin; **10 `lib/` files** changed, including the three most-captured screens |
| **Proxy rendering** | **66 of 89** captures are an Android tablet with a display override, reproducing nothing about iOS rendering |
| **Desktop absent** | **0** Windows captures; widest logical width present is **800** |

**THE COST, recorded so the decision is priced rather than guessed:**

| Pass | What it needs |
|---|---|
| Recapture at three widths | The Teclast P30 with display overrides, plus the rotation discipline that cost six failures on 7 Sep 2026 — `wm size` inherits the rotation in force |
| Windows desktop | Windows, a desktop build, and a capture convention that does not exist yet: **every current filename encodes a logical width and a mobile DPR** |
| Real iOS | **The Mac.** Every real-iOS capture in the set is dated 7 Sep 2026 and came from there |

⭐ **THE WINDOWS GAP IS THE CHEAPEST TO CLOSE, AND IT IS THE ONE NOTHING COVERS AT ALL.** The CLI
runs on Windows and builds the desktop target, so no second machine and no device are involved —
against the iOS pass, which needs the Mac, and the recapture pass, which needs the tablet. **It is
also the only one of the three where the current evidence is not weak but ABSENT**: a proxy
capture is wrong about rendering while still being right about wrapping, and a stale capture was
true of some commit. **There is no Windows capture to be wrong.**

⛔ **RECORDED AS OPEN. No answer proposed.** Whether to refresh, refresh partially, or proceed on
the basis as declared is a decision about how much the visual assessment needs to be trusted, and
nothing in this document settles it.

✅ **DECIDED 8 September 2026. The open framing above is left as written — it records what was true
when the finding was made, and the cost table it carries is what the decision was made against.**

⭐ **REFRESH, IN THREE PASSES, IN THIS ORDER. The order is the decision, not the passes.**

**1. WINDOWS DESKTOP FIRST.** Cheapest to run — **this machine builds the target**, so no second
machine and no device are involved. And it is where the findings pile up: ⛔ **three now converge
on the Windows build** — **zero** design-audit captures at any width, content capped at
`maxWidth: 520` with **no width breakpoints** (verified: both `LayoutBuilder`s use `maxHeight`
only, `MediaQuery...size.width` 0 hits, width-threshold branching 0 hits), and **§13(y)'s missing
padded tap-target floor**, which applies on Android and iOS and **not** on Windows.

⚠️ **The four Microsoft Store screenshots at ~1103x926, dated 3 May 2026, are NOT an assessment** —
one window size, taken four months before the audit existed. They lower the cost; they do not
answer anything.

**2. DISCLAIMER AND WALKTHROUGH, at the widths they lack.** `disclaimer` has **1 capture, 375
only**; `walkthrough` has **step 1 of 5, 375 only**.

⭐ **These are the two screens with ZERO findings in sections 1 to 12 — checked 8 September 2026.**
⛔ **Not screens that passed. Screens nobody assessed.** And **both are first-run gates that every
new user meets before reaching anything else in the app.** The correlation is exact: the two
least-assessed screens are the two least-captured screens, which is what an unexamined surface
looks like from both directions at once.

**3. REAL iOS, for the screens where RENDERING matters and only 1x proxies exist.** Needs the Mac.
Scoped by the rule the amendment already sets: a finding about **layout or wrapping** may rest on
the proxy set; a finding about **type rendering, spacing as it appears, safe-area behaviour or
chrome** may not.

⛔ **NOT DOING: recapturing the 66-image 1x proxy set wholesale.** It is **valid for wrapping and
layout**, which is what most of sections 1 to 8 rest on, and **stale for three screens only**.
Recapturing it would spend the effort **re-deriving findings that already exist** — and §13(r)
records what happens when a fact is re-derived instead of read.

⚠️ **THE OBLIGATION THAT REPLACES IT:** any 1x-based finding about **`log_event_screen`,
`home_screen` or `history_screen`** must **name that it rests on a basis 24 commits old**. Those
are the three files changed since `715ca95`, and two of them were changed by this session's own
work.

⛔ **CORRECTED 8 September 2026, HOURS AFTER THE DECISION ABOVE, WHICH IS LEFT AS WRITTEN.
PASS 2 AS DECIDED IS UNRUNNABLE ON THE LIVE DEVICE.**

**`captures/INDEX.md` has recorded the reason since 30 August 2026, in its "Not captured, and why"
table, verbatim:**

> | **`DisclaimerScreen` and `WalkthroughScreen` (5 steps)** | ⛔ **Unreachable without destroying
> data.** Their gates are `disclaimerAcceptedVersion` and `walkthroughSeenVersion` in
> SharedPreferences. `run-as` is refused on a release build — *"package not debuggable"* — so the
> only way to clear them is `pm clear`, which **wipes all app data including the 72 records** |

⭐ **PASS 2 THEREFORE SPLITS IN TWO:**

| | |
|---|---|
| **2a** | **Reachable on the live device.** The discard dialog, the rescue confirm dialog, and refreshed captures of the three stale screens. Runnable now, and run on 8 Sep 2026 |
| **2b** | **The DISPOSABLE-PROFILE pass — and `INDEX.md` already specifies it.** Disclaimer, walkthrough steps 2 to 5, the empty states for History, Conditions and Medication, the heavy-vocabulary case, and **wizard step 2 with a second condition** — the picker that is still unbounded and whose grouped variant a second condition switches on |

**`INDEX.md`'s own words on 2b:** *"Every one of these is reachable on a disposable profile — which
is also where the heavy-vocabulary case belongs. They should be captured together in that later
pass, where a fresh install has no records and therefore nothing to lose."*

⚠️ **2b IS UNSCOPED AND ITS COST IS NOT KNOWN.** A disposable profile on this device might be a
second user account, a second `applicationId`, an emulator, or a spare handset — **nothing has
established which, or what any of them costs.** ⛔ **Not assumed, not estimated. It is a separate
decision, and the three-pass order above does not price it.**

⚠️ **AND THE COVERAGE FRAMING ABOVE IS CORRECTED.** The decision reasoned that disclaimer and
walkthrough have zero findings in §§1-12 because **nobody assessed them**, and treated the match
with their thin capture coverage as *"what an unexamined surface looks like from both directions at
once."*

⭐ **THE CORRELATION WAS REAL AND THE CAUSATION WAS BACKWARDS.** They are unassessed **because they
are uncapturable without destroying the records** — one cause producing both effects, already
written down, and not a coincidence of two independent omissions. **The observation stands; the
explanation was invented where a recorded one existed.** See §13(r), instance 11.

---

### (r) Correct knowledge existing, written down, and not travelling — ONE PATTERN, AND THE COUNT KEEPS GROWING

**Checked 8 Sep 2026.** ⛔ **Not a finding about the app. A finding about this audit's own
reliability**, recorded here because it has now cost real work more than once and because the
count is the argument.

⭐ **THE SHAPE, IN EVERY CASE: the right answer already existed, in writing, and the party who
needed it did not have it.** Not one instance was caused by the fact being unknown.

| # | The knowledge | Where it sat | What happened anyway |
|---|---|---|---|
| 1 | *"both call sites pass an `existing`, so today it is edit-only by call site"* | **this document, §10, since 31 Aug 2026** | `ARCHITECTURE.md` row 2 listed `LogEventScreen` as a record-creation site, and §13(n) re-derived the same fact from scratch on 8 Sep |
| 2 | Swift posts facts and never writes the record list | `CLAUDE.md`, corrected **29 Aug 2026** | `ARCHITECTURE.md` rows 6 and 7 still claimed the old behaviour on 8 Sep. **The correction reached the deferring document and never reached the authoritative one** |
| 3 | *"CITED BY SYMBOL, NOT LINE NUMBER … three were wrong within days"* | `ARCHITECTURE.md` §3, **twenty lines above** | A `CLAUDE.md:78` pointer was written in that same section on 8 Sep and had rotted by the same day |
| 4 | A pointer is only as good as its target | derived while fixing #3 | The 29 Aug correction being pointed AT was itself imprecise — three write sites named where there are four |
| 5 | The pointer rule | being written, that hour | The repair for #3 cited `:82`, and edits made in the SAME script run pushed the line to `:87`. **Three positions in one day** |
| 6 | *"WIDTH PROXIES, NOT iOS SCREENSHOTS"* | **`DESCRIPTION-430.md`, line 8, in a READ THIS FIRST block, since 30 Aug 2026** | The set was treated as an iOS basis throughout this session, until the basis was inventoried on 8 Sep |
| 7 | *"A count of a container must name the container"* | being written, that minute | The sentence stating it claimed a count over "this document" that the sentence itself falsified, and its first repair said "the table above" while sitting below a different table |

⚠️ **INSTANCE 6 IS THE STARKEST AND IT IS WHY THIS IS FILED HERE.** The warning was not buried,
not stale, and not ambiguous. **It was the first content block of the file, headed `⛔ READ THIS
FIRST`, and it said exactly the thing that needed knowing.** It did not travel. ⛔ **A prominent
warning in the right file is not a mechanism.**

⭐ **INSTANCES 5 AND 7 ARE THE ONES THAT DEFEAT THE OBVIOUS FIX.** Both were committed **while the
rule being violated was being written down**, minutes apart. **So "write it down more clearly" is
not the remedy** — the remedy is a check that runs without being asked, or a citation form that
cannot rot. The pointer case took the second route: it now cites a symbol, because a symbol has
nothing to go stale against.

⛔ **NO REMEDY PROPOSED FOR THE PATTERN AS A WHOLE.** Exactly TWO instances have had their
specific mechanism fixed — pointer-by-symbol, for #3 and #5. ⚠️ **[this read "two of the seven"
and "the other five" when written on 8 Sep 2026; instances 8, 9 and 10 were added the same day,
so the counts are stated relative to the tables now rather than as totals]** **Every other
instance was found by accident, by something else forcing the fact into view**, and this document
has no mechanism that would have found any of them. **That is the finding.**

➕ **THREE FURTHER INSTANCES, 8 September 2026 — the table above stands; these are added
beneath it because the count is the argument.**

| # | The knowledge | Where it sat | What happened anyway |
|---|---|---|---|
| 8 | §10's decisions 1 and 2 were resolved by this session's own work | **this document, §13(a) (m) (n) and `DATA-MODEL.md` §9** | §10 still presented both as **open** until annotated on 8 Sep. ⛔ **In the document that records this pattern** |
| 9 | 11 of 13 numbered sections already carried visual findings | **this document, §§1-8, 10-12** | the visual assessment was asserted to have *"barely started"*. **Reasoned from the absence of its own knowledge rather than from reading the file** |
| 10 | `daily_entry` is designed with a 7-column spec and 3 requirements | **`DATA-MODEL.md` §9, since before 7 Sep 2026** | concluded on 8 Sep that it **did not exist**, from one conversational answer, **with the check queued in a brief and the conclusion written before it ran** |

⭐ **INSTANCE 9 IS A NEW SHAPE AND WORTH SEPARATING.** Instances 1 to 8 and 10 are all *the fact
existed and was not read*. **This one is different: an absence of KNOWLEDGE was treated as evidence
of an absence of WORK.** Nothing was misread — the file was simply never opened, and the gap in
one reader's picture became a claim about the artefact. ⛔ **"I do not know of any" and "there are
none" are different statements**, and the second was made from the first.

⚠️ **AND INSTANCE 10 IS THE SHARPEST ORDERING FAILURE: the check was ALREADY QUEUED.** Not
absent, not forgotten — **written into a brief, and overtaken by a conclusion drawn before it
ran.** The same day had already produced the opposite error about the same feature.

➕ **INSTANCE 11, 8 September 2026 — and it is the first one recorded the same day the pattern's
table was written.**

| # | The knowledge | Where it sat | What happened anyway |
|---|---|---|---|
| 11 | disclaimer and walkthrough are uncapturable without `pm clear`, which destroys the 72 records — **and a disposable-profile pass is the named answer** | **`captures/INDEX.md`, "Not captured, and why", since 30 Aug 2026** | §13(q)'s decision ordered them as **pass 2** without reading the index of the capture set it was extending. **The one pass that cannot be run on the live device was scheduled second** |

⛔ **THE SAME SHAPE AS INSTANCE 9, AND THE SECOND TIME THAT SHAPE HAS APPEARED IN ONE DAY.** An
absence of knowledge was treated as evidence about the artefact: *"screens nobody assessed"* was
inferred from *"screens I found no findings for"*, when a recorded cause explained both the missing
findings and the missing captures at once.

⭐ **AND THE ANSWER WAS WRITTEN BESIDE THE PROBLEM.** `INDEX.md` does not merely record the
obstacle — it **names the remedy in the next sentence**, and specifies what else belongs in that
same pass. **A decision was made about capture coverage without opening the capture set's own
index**, which is the one file whose whole job is to say what is and is not in it.

⚠️ **TWO FURTHER INSTANCES OF THE SAME FAMILY, both checked 8 September 2026, both about
procedure rather than content:**

| | |
|---|---|
| ⛔ **`adb` is not on `PATH`, and its location is recorded nowhere** | **0 hits** for `platform-tools` or `adb.exe` across `STATUS.md`, `CLAUDE.md` and `captures/INDEX.md`; control `adb shell` present in `INDEX.md`, known-absent probe 0. **Every recorded capture command begins `adb shell …` and none of them runs as written.** It is at `C:\Users\wjl25\AppData\Local\Android\Sdk\platform-tools\adb.exe`. ⭐ **A procedure recorded in full, that cannot be executed from the record** |
| ⚠️ **A superseded device claim still reads as current** | `STATUS.md:1693`, session of **26 April 2026**: *"MER will not render in portrait on the Teclast P30… Cause unknown and deliberately not guessed."* **Superseded** — the 30 August and 7 September passes both forced portrait successfully, and `INDEX.md` records *"Orientation: Portrait, forced."* ⛔ **Dated, therefore resolvable — but only by someone who checks the date rather than the claim** |

### (s) 🔴 CONTRAST — 28 of 64 measured pairs fail WCAG 2.2 AA

**Code-verified, 8 Sep 2026.** Every pair derived by reading the source and pairing each
foreground with the background it actually sits on. Ratios computed from the PNG-independent
sRGB relative-luminance formula, **not rounded toward passing.**

⚠️ **THE THRESHOLD CONVERSION, STATED BECAUSE IT DECIDES SEVERAL ROWS.** WCAG's "large text" is
**18pt regular / 14pt bold**. Flutter's `fontSize` is **logical pixels**, and 1pt = 4/3 px, so the
thresholds become **`>= 24` regular** and **`>= 18.67` bold**. `w600` was treated as **bold** —
⭐ **the GENEROUS reading, which LOWERS the bar, so every failure listed below fails either way.**
Consequence worth noting: `titleLarge` at **18px w600 is NOT large text** (18 < 18.67). It passes
anyway at 8.02:1.

⛔ **4.31 against 4.5 IS A FAIL. The threshold is binary and this document does not soften it.**
The apparatus was controlled on the boundary pair before any real number was computed:
`#767676` on white = **4.54 PASS**, `#777777` on white = **4.48 FAIL**. A calculator that rounded
would call both 4.5 and both passing.

**64 pairs · 36 PASS · 28 FAIL. Worst 1.44:1. Best-failing 4.36:1.**

<!-- emitted from the computed values, not retyped -->
| # | Pair | fg | bg | Ratio | Needs | Size / weight | Location |
|---|---|---|---|---|---|---|---|
| 1 | Divider | `#B5D4F4` | `#F5F8FB` | **1.44:1** | 3.0:1 | non-text UI | `dividerTheme` |
| 2 | Info card (previews) BORDER | `#90CAF9` | `#E3F2FD` | **1.53:1** | 3.0:1 | non-text UI | `home_screen.dart:1070` |
| 3 | Input BORDER (enabled) | `#B5D4F4` | `#FFFFFF` | **1.53:1** | 3.0:1 | non-text UI | `inputDecorationTheme enabledBorder` |
| 4 | Chip BORDER | `#B5D4F4` | `#FFFFFF` | **1.53:1** | 3.0:1 | non-text UI | `chipTheme side` |
| 5 | Card BORDER | `#B5D4F4` | `#FFFFFF` | **1.53:1** | 3.0:1 | non-text UI | `cardTheme side` |
| 6 | Info card (notif off) BORDER | `#FFB74D` | `#FFF3E0` | **1.58:1** | 3.0:1 | non-text UI | `home_screen.dart:1058` |
| 7 | Backup reminder BORDER | `#81C784` | `#E8F5E9` | **1.79:1** | 3.0:1 | non-text UI | `home_screen.dart:1577` |
| 8 | Unsaved banner BORDER | `#EF9A9A` | `#FFEBEE` | **1.88:1** | 3.0:1 | non-text UI | `home_screen.dart:1290` |
| 9 | Fallback banner BORDER | `#FF9800` | `#FFF3E0` | **1.97:1** | 3.0:1 | non-text UI | `home_screen.dart:1391` |
| 10 | Info card (notif off) BODY, alpha .85 | `#F68E22` | `#FFF3E0` | **2.17:1** | 4.5:1 | 12px w400 | `_InfoCard body withValues(alpha: 0.85)` |
| 11 | SnackBar action label | `#1A8FCB` | `#0D4F82` | **2.37:1** | 4.5:1 | 14px w600 | `snackBarTheme actionTextColor` |
| 12 | Info card (notif off) icon | `#F57C00` | `#FFF3E0` | **2.47:1** | 3.0:1 | non-text UI | `home_screen.dart:1054` |
| 13 | Info card (notif off) title | `#F57C00` | `#FFF3E0` | **2.47:1** | 4.5:1 | 13px w700 | `_InfoCard title` |
| 14 | Help status BAD text | `#F57C00` | `#FFFFFF` | **2.70:1** | 4.5:1 | 12px w600 | `help_screen.dart:656` |
| 15 | Help status dot (bad) | `#F57C00` | `#FFFFFF` | **2.70:1** | 3.0:1 | non-text UI | `help_screen _StatusRow dot` |
| 16 | Info card (previews) BODY, alpha .85 | `#3789D8` | `#E3F2FD` | **3.21:1** | 4.5:1 | 12px w400 | `_InfoCard body withValues(alpha: 0.85)` |
| 17 | Fallback banner title | `#E65100` | `#FFF3E0` | **3.46:1** | 4.5:1 | 14px w600 | `home_screen.dart:1408` |
| 18 | Fallback banner body | `#E65100` | `#FFF3E0` | **3.46:1** | 4.5:1 | 13px w400 | `home_screen.dart:1428` |
| 19 | Fallback banner button label | `#FFFFFF` | `#E65100` | **3.79:1** | 4.5:1 | 13px w600 | `home_screen.dart:1437` |
| 20 | Info card (previews) title | `#1976D2` | `#E3F2FD` | **4.03:1** | 4.5:1 | 13px w700 | `_InfoCard title` |
| 21 | bodyMedium (MUTED) on bg | `#4A7FA5` | `#F5F8FB` | **4.05:1** | 4.5:1 | 13px w400 | `textTheme bodyMedium` |
| 22 | bodySmall (MUTED) on bg | `#4A7FA5` | `#F5F8FB` | **4.05:1** | 4.5:1 | 11px w400 | `textTheme bodySmall` |
| 23 | Help status OK text | `#388E3C` | `#FFFFFF` | **4.12:1** | 4.5:1 | 12px w600 | `help_screen.dart:656` |
| 24 | bodyMedium (MUTED) | `#4A7FA5` | `#FFFFFF` | **4.31:1** | 4.5:1 | 13px w400 | `textTheme bodyMedium` |
| 25 | bodySmall (MUTED) | `#4A7FA5` | `#FFFFFF` | **4.31:1** | 4.5:1 | 11px w400 | `textTheme bodySmall` |
| 26 | labelLarge (MUTED) | `#4A7FA5` | `#FFFFFF` | **4.31:1** | 4.5:1 | 11px w600 | `textTheme labelLarge` |
| 27 | Input label / hint | `#4A7FA5` | `#FFFFFF` | **4.31:1** | 4.5:1 | 13px w400 | `inputDecorationTheme` |
| 28 | Unsaved banner body | `#D32F2F` | `#FFEBEE` | **4.36:1** | 4.5:1 | 12px w400 | `home_screen.dart:1319` |

⭐ **THREE LEVERAGE POINTS, and they are why this is 28 rows rather than 28 problems:**

| | |
|---|---|
| **`textMuted` #4A7FA5 at 4.31:1** | ⭐ **SIX failures from ONE palette value** — counted, not estimated: rows 21, 22, 24, 25, 26, 27. It is `bodyMedium`, `bodySmall`, `labelLarge`, and every input label and hint |
| **`border` #B5D4F4 at 1.53:1** | **FOUR failures, and it is every card, chip and input outline in the app** — rows 3, 4, 5 and the divider |
| **`dividerTheme` at 1.44:1** | **The worst ratio measured anywhere**, and the same `border` colour on `background` rather than `surface` |

⛔ **THE FALLBACK BANNER, RECORDED SEPARATELY, BECAUSE IT IS THE MOST INSTRUCTIVE ROW HERE.**
Built and **device-verified on 7 September 2026** — and it **fails all three of its text pairs**:
title 3.46:1, body 3.46:1, button label 3.79:1, against 4.5:1.

⭐ **The render was not wrong. It was answering a different question.** It confirmed the copy did
not overflow, that it wrapped to three clean lines, that spacing against the app bar was right,
and that amber read as **attention rather than alarm** — with frame brightness measured at 202-207
and the stacked-green case captured beside it. **Every one of those was correct.** ⛔ **None of
them could report that the contrast was 3.46:1.**

> **A VISUAL CHECK CANNOT ANSWER A MEASURABLE QUESTION.** The same class as the passing test that
> could not know a sentence was untrue, and the count that read as assurance while measuring
> something adjacent. **Looking at it is not measuring it.**

⚠️ **UNDETERMINED FROM SOURCE, and part 2's input:** the two `_InfoCard` bodies are the only alpha
composites and were computed against their own card fill, which is correct **only if nothing sits
between**; app icons and the splash are images, not colour pairs; and every system-supplied
surface — keyboard, share sheet, date picker, the `PopupMenuButton` menu fill — **is not set in
this codebase at all.**

---

### (t) COLOUR-ALONE — 3 of 14 conditional colours carry meaning by colour alone

**Code-verified, 8 Sep 2026.** WCAG 1.4.1: colour must not be the only visual means of conveying
information.

**⛔ THE THREE:**

| Instance | What colour signifies | Accompanied by |
|---|---|---|
| `home_screen.dart:1762` **"This month"** → `alert` when non-zero | that the count is notable | ⛔ **NOTHING. Already §13(k)** |
| `walkthrough_screen.dart:303` **page dots**, active vs `alpha 0.25` | which step you are on | ⛔ **NOTHING** — same 8x8 size, same `BoxShape.circle`, **opacity only** |
| `log_event_screen.dart:1172` **selection row** | which option is chosen | ⚠️ **border width 0.5 → 1.5 only.** Non-colour, but sub-pixel at 0.5 and no icon, no weight change |

**✅ THE COMPLIANT ELEVEN, with what carries the meaning besides colour:**

| Instance | Also conveyed by |
|---|---|
| `history_screen.dart:903/906/922` "Needs details" chip | **`Icons.check` appears** (`if (selected)`), weight w400→w600, border 0.5→1.5 |
| `history_screen.dart:1069` type filter chip | weight w400→w600, border width change |
| `vocabulary_screen.dart:411` hidden entry | **explanatory text appears** — *"Hidden — still shown on records that use it"* |
| `help_screen.dart:656` OK / BAD status | **a different glyph** — `ok ? okIcon : badIcon` |
| `home_screen.dart:1115`, `mer_theme.dart:156` | button and chip fill states, paired with their own labels |

⭐ **RECORD THE APPARATUS FAULT, because the finding would have been wrong without the control the
brief mandated.** A single-line regex found **4** conditional colours. **The multiline form found
14.** The conditional at `home_screen.dart:1761-1763` wraps across three lines:

```dart
valueColor: thisMonth > 0
    ? MERColours.alert
    : MERColours.primary,
```

⛔ **So the first search missed §13(k) itself — the one instance already known to exist.** The
brief's requirement that the search must find (k) or be considered broken is what caught it. **A
10-instance miss, reported clean.** Same shape as every filter-and-transform failure already in
this codebase: plausible output, nothing erroring.

---

### (u) 🔴 TEXT SCALE IS NEVER READ — and this may outrank (s)

**Code-verified, 8 Sep 2026.**

```
textScaler               0 hits
textScaleFactor          0 hits
MediaQuery.textScalerOf  0 hits
CONTROL, MediaQuery present in lib/ : 4     CONTROL, known-absent probe : 0
```

**The app never reads the platform's text-size setting.** Nothing scales, nothing re-flows in
response to it, nothing tests it.

⭐ **WHY THIS MAY MATTER MORE THAN (s), stated as reasoning rather than as a measurement.** A
contrast failure makes text harder to read. **A text-scale failure can make it unreachable** — the
platform enlarges type, the layout does not adapt, and content clips or overflows off-screen. WCAG
2.1.4's resize criterion asks for 200% without loss of content or functionality.

⛔ **AND IT UNDERMINES EVERY LAYOUT MEASUREMENT IN THIS DOCUMENT.** §7's "roughly 150 px of void",
§13(e)'s `btnTop` range of 311-680, the 2.11-screenful figure, the whole row-bound analysis in §2
— **every one describes the app at ONE text size, the default.** None of them says so.

⚠️ **UNQUANTIFIED, AND DELIBERATELY LEFT SO. Nobody has rendered this app at 200% text scale.**
There is no capture at any scale but the default (§13(q)), so the consequence is **unknown rather
than small**. That is part 2 work. ⛔ **Do not record a severity here; the measurement does not
exist yet.**

---

### (v) ✅ FLASH CONTENT — CLEAN, and recorded as a positive result

> ⛔ **QUALIFIED THE SAME DAY BY §13(ah) — 8 September 2026. The verdict below is left as
> written; it records what this search found, and every individual result in it still holds.**
> But the search MISSED one flash: `Record Event`'s `backgroundColor` swaps to white for 200 ms
> on every tap — a **76.4% luminance change** — and taps spaced 200 to 333 ms apart exceed the
> three-per-second threshold. ⭐ **It was missed because this search enumerated animation
> WIDGETS and TIMERS BY TYPE, and that flash is a `bool` swapped inside a colour expression.**
> See §13(ah).

**Code-verified, 8 Sep 2026.** WCAG 2.3.1 Level A: nothing may flash more than three times per
second. ⭐ **This is an epilepsy app, so a clean pass is worth recording in its own right rather
than noted as an absence.**

**WHAT THE SEARCH RETURNS — recorded in full so a future session re-runs it instead of
re-deriving it:**

```
FOUND (the control that proves the search reached the widgets):
  AnimatedContainer          5   history:899, history:1045, log_event:1007, :1084, :1164
                                 ALL Duration(milliseconds: 150), one-shot on tap
  CircularProgressIndicator  4   main:183, conditions:116, home:2079, medication:129
  LinearProgressIndicator    1   event_wizard_screen:413
  TOTAL animation constructs 10

ZERO, each against the AnimatedContainer = 5 control above:
  .repeat(            0        AnimationController  0        Lottie           0
  .animate(           0        vsync                0        flutter_animate  0
  Ticker              0        Curves.bounce        0        SpinKit          0
  period:             0        Curves.elastic       0        shimmer          0
  animation packages in pubspec.yaml : 0    (CONTROL: sqflite = 3)
  .gif files in repo (excl build)    : 0
  Lottie .json in assets/            : 0
  known-absent probe 'zzz_absent'    : 0
```

⛔ **`repeat` returned 11 and `reverse` returned 6, and EVERY ONE WAS ADJUDICATED INDIVIDUALLY
rather than counted.** All 17 are prose in comments (*"a repeat drain repeats this decision"*,
*"the reverse direction"*) or `items.reversed` on the CSV export loop. **None is an animation.**
⭐ **A raw count would have reported 17 repeating constructs in an epilepsy app.**

⭐ **THE ONE THING THAT GENUINELY REPEATS, and the reason a bare zero would have been dishonest:**
`Timer.periodic(Duration(seconds: 1))` at `home_screen.dart:1266`, rebuilding
`_ActiveEventBanner` **every second, indefinitely, while an event is running.**

**It is not a flash, on two independent grounds:**
1. **Nothing visual changes between frames.** The rebuild recomputes `elapsedStr` only; the
   `#FFEBEE` fill, `#EF9A9A` border and `#D32F2F` dot are all `const`.
2. **1 Hz is below the three-per-second threshold** even if they did change.

**The five `AnimatedContainer`s are one-shot 150 ms tap transitions — no repeat, no reverse.** The
progress indicators animate continuously, but **rotation and advance are not luminance flashing**,
and both are transient boot or load states.

⚠️ **REDUCE-MOTION IS NOT RESPECTED ANYWHERE:**

```
disableAnimations 0   accessibleNavigation 0   reduceMotion 0   AccessibilityFeatures 0
CONTROL, MediaQuery present : 4      known-absent probe : 0
```

⭐ **Recorded here rather than as its own finding because the practical exposure is small: with no
repeating animation and nothing longer than 150 ms, there is very little motion to reduce.** It is
a gap in principle, not a gap a user would feel today.

---

### (w) THE PALETTE IS NOT IN THE PALETTE

**Code-verified, 8 Sep 2026.** `MERColours` defines **10** colours. **Roughly 40 further raw
`Color(0x…)` literals sit outside the theme**, in `home_screen.dart`, `history_screen.dart`,
`disclaimer_screen.dart`, `help_screen.dart` and `event_record.dart`.

**Two facts about the 10 that are worth having on record:**
- ⚠️ **`textPrimary` is byte-identical to `primary`** — both `#0D4F82`. Two names, one colour.
- ⚠️ **`success` and `warning` appear in NO measured pair.** The greens and ambers actually
  rendered are raw literals (`#2E7D32`, `#1B5E20`, `#E65100`, `#F57C00`), not these.

⭐ **THE CONSEQUENCE, AND IT IS THE POINT OF THE FINDING.** The 28 failures in §13(s) split
**11 / 17** — computed, not estimated:

| Origin | Failures |
|---|---|
| both colours are `MERColours` values (or white) | **11** — the five `textMuted` text styles, the input label, and the four `border` outlines plus the divider, and the SnackBar action label |
| **at least one RAW literal** | **17** — every banner, both info cards including their alpha-composited bodies, and the three help-status rows |

⛔ **So a palette-level fix applied to `MERColours` alone would LOOK complete** — one file, all
named colours corrected, a tidy diff — **and would leave 17 of 28 failures untouched**, including
every banner and every info card. **Any contrast fix must reach BOTH, and the raw literals are the
larger half.**

⚠️ **This figure was ASSERTED as 8/20 in drafting and computed as 11/17.** Recorded because the
draft number was plausible and wrong, and nothing but the computation would have caught it.
**A second draft error in the same pass said "Five failures from ONE palette value" above a list
of SIX rows** — computed as 6 for `textMuted` and 4 for `border`.

⛔ **THE COUNTERMEASURE BOTH ERRORS POINT AT: SUMMARY FIGURES MUST BE COMPUTED, NOT READ OFF A
COMPUTED TABLE.** The failure table above was emitted from the calculator precisely to keep 28
measured ratios out of hand-transcription — and both errors then landed in the PROSE AROUND IT,
where a number was derived by eye from the very table that could have produced it. **A prose
figure read off a table is hand-transcription with extra steps**, and ⛔ **no check in this
repository catches it**: the whole-sentence verifier confirms a sentence survived, never that its
arithmetic is right.

---

### (x) TARGET SIZES — all pass 24x24; four fall short of 44 and 48

**Code-verified, 8 Sep 2026. 108 interactive constructions, 114 `onTap`/`onPressed`/`onSelected`
callbacks.**

⭐ **The Flutter default was VERIFIED IN THE SDK rather than assumed, and it is PLATFORM-SPLIT —
which the brief's framing did not anticipate.** `theme_data.dart:400-407`:

```dart
case TargetPlatform.android:
case TargetPlatform.fuchsia:
case TargetPlatform.iOS:
  materialTapTargetSize ??= MaterialTapTargetSize.padded;
case TargetPlatform.linux:
case TargetPlatform.macOS:
case TargetPlatform.windows:
  materialTapTargetSize ??= MaterialTapTargetSize.shrinkWrap;
```

with `kMinInteractiveDimension = 48.0` in `material/constants.dart:27`. **This app sets neither
`materialTapTargetSize` (0 hits) nor `platform` (0 hits)** — controls: `useMaterial3` = 1 in the
same file, known-absent probe = 0.

⛔ **APPARATUS FAULT, RECORDED BECAUSE ONE BROKEN AGGREGATION INVALIDATED TWO NUMBERS AND ONLY
ONE OF THEM LOOKED WRONG.** The first pass counted with
`grep -rcF <term> <file> | awk -F: '{s+=$2}'`. With a single explicit file, `grep -c` emits a bare
count and no `filename:` prefix, so `$2` is empty and the sum is **always 0**. Reproduced side by
side, 8 Sep 2026:

    broken form   grep -rcF 'useMaterial3' lib/theme/mer_theme.dart | awk -F: '{s+=$2}'  ->  0
    correct form  grep -cF  'useMaterial3' lib/theme/mer_theme.dart                      ->  1

⭐ **`useMaterial3 = 0` was VISIBLY wrong** — that line had been read directly minutes
earlier — **and `platform: = 0`, produced by the same pipeline in the same command, was not.**
It happened to be true. ⛔ **A control that fails tells you nothing about which of the numbers
beside it are also wrong; every figure from that pipeline had to be re-derived, and was.**

⛔ **SO THE 48x48 FLOOR APPLIES ON ANDROID AND iOS AND DOES NOT APPLY ON WINDOWS** — promoted
to its own finding, **§13(y)**, because it is a platform difference rather than a detail of this
table.

⚠️ **THE TABLE BELOW THEREFORE DESCRIBES MOBILE ONLY.** Every "48" in it is the `padded`
minimum, which the Windows build does not get. **The desktop figures are UNMEASURED — see
§13(y); do not read them off this table.**

| Element | Effective target | 24 | 44 | 48 |
|---|---|---|---|---|
| `TextButton` (20), `FilledButton` (18), `IconButton` (8), `OutlinedButton` (5), `ListTile` (8) | **48** on mobile via `padded` | ✅ | ✅ | ✅ |
| `SizedBox(height: 52)` — `disclaimer:331`, `log_event:826` | **52** | ✅ | ✅ | ✅ |
| **Cancel button** — `log_event_screen.dart:838` | **44** | ✅ | ✅ | ⛔ |
| `history_screen.dart:1381` | **38** | ✅ | ⛔ | ⛔ |
| `home_screen.dart:1830`, `your_data_screen.dart:200` | **36** | ✅ | ⛔ | ⛔ |
| chips — `chipTheme` padding v10 + 13px label | **≈ 38** | ✅ | ⛔ | ⛔ |
| selection rows — `AnimatedContainer` padding v10 | **≈ 38** | ✅ | ⛔ | ⛔ |
| `GestureDetector` chip — `history:897`, padding v8 + 12px label | **≈ 30** | ✅ | ⛔ | ⛔ |

⛔ **Nothing measured falls below WCAG 2.2 AA's 24x24.**

⚠️ **`VisualDensity.compact` is applied at four sites** — `history:992`, `history:1401`,
`home:1439`, `home:1602`. **Compact subtracts from the minimum interactive dimension**, so those
four are smaller than the table implies and **the amount is UNDETERMINED FROM SOURCE.** Two of the
four are banner buttons.

⚠️ **Chip and button WIDTH depends on rendered label length**, which source cannot give. Both that
and the `compact` reduction are part 2's input, alongside the 7 `InkWell` sites whose target is
whatever their child measures.

### (y) 🔴 THE 48x48 TAP-TARGET FLOOR DOES NOT APPLY ON WINDOWS

**Code-verified in the Flutter SDK, 8 Sep 2026.** Promoted out of §13(x) because it is a
**platform-specific accessibility difference**, not a detail of the target-size table, and it
needs to be findable on its own.

**`flutter/packages/flutter/lib/src/material/theme_data.dart:399-407`:**

```dart
platform ??= defaultTargetPlatform;
switch (platform) {
  case TargetPlatform.android:
  case TargetPlatform.fuchsia:
  case TargetPlatform.iOS:
    materialTapTargetSize ??= MaterialTapTargetSize.padded;
  case TargetPlatform.linux:
  case TargetPlatform.macOS:
  case TargetPlatform.windows:
    materialTapTargetSize ??= MaterialTapTargetSize.shrinkWrap;
```

with **`const double kMinInteractiveDimension = 48.0;`** at `material/constants.dart:27`.

**This app sets NEITHER, re-verified 8 Sep 2026 without the broken aggregation described below:**

```
materialTapTargetSize  0 hits      platform:  0 hits      TargetPlatform  0 hits
CONTROLS  useMaterial3 in mer_theme.dart = 1     ThemeData tree-wide = 8 hits
          zzz_absent tree-wide = 0 hits
```

⛔ **SO EVERY MATERIAL BUTTON ON THE WINDOWS BUILD FALLS BACK TO `shrinkWrap` AND LOSES THE 48x48
PADDED MINIMUM.** The same widget, the same code, a smaller target — decided entirely by
`defaultTargetPlatform`.

⭐ **THREE FINDINGS NOW CONVERGE ON THE WINDOWS BUILD AS THE LEAST-EXAMINED SURFACE OF THIS APP**,
and none of the three was looking for the other two:

| | |
|---|---|
| **No design-audit captures at all** | widest logical width present is 800; the only Windows evidence is four Microsoft Store screenshots from 3 May 2026 — see the scope amendment |
| **Content capped at `maxWidth: 520`, no width breakpoints** | verified: both `LayoutBuilder`s use `maxHeight` only, `MediaQuery...size.width` 0 hits, width-threshold branching 0 hits |
| **No padded tap-target minimum** | this finding |

**It ships on the Microsoft Store.**

⚠️ **UNQUANTIFIED. NOBODY HAS MEASURED THE EFFECTIVE TARGET SIZES ON THE DESKTOP BUILD.**
§13(x)'s table describes **mobile only**. What `shrinkWrap` yields for each of the 108 interactive
constructions in this app is **unknown**, not estimated — it depends on each widget's intrinsic
content, and there is no desktop capture to measure against. ⛔ **Do not infer a number from
(x)'s table; it does not apply here.**

⭐ **HOW IT WAS FOUND, RECORDED BECAUSE THE METHOD IS THE TRANSFERABLE PART.** The brief asked for
`MaterialTapTargetSize.padded` to be recorded as **an unverified assumption**. The Flutter SDK is
on this machine, so it was read instead — and reading it produced **a finding rather than a
caveat**, because the real default is platform-split and the assumption had been platform-blind.
**An assumption worth flagging is often an assumption worth checking; the check cost one `sed`.**

### (z) 🔴 SCREEN-READER SEMANTICS WERE NEVER MEASURED — and the checklist that missed them was written today

**Checked 8 Sep 2026.** The part-1 accessibility pass scoped itself to **four criteria**: contrast
ratios, colour-alone instances, target sizes, and flash content. ⛔ **It omitted screen-reader
semantics entirely** — and semantics is the criterion under which a defect **already recorded in
this document** sits.

**§8 has carried it since 31 August 2026:**

> **Code-verified.** **The History delete control has no tooltip, on every row**, so it renders
> `content-desc=""` and a screen reader announces nothing for a destructive action.
> `medication_screen` builds the same control **with** `tooltip: 'Delete'`. ⛔ **An inconsistency,
> not a house style — which is what makes it a defect.**

⭐ **SO THE DEFECT WAS IN THE DOCUMENT AND THE CHECKLIST DID NOT REACH IT.** The four criteria were
chosen before the document was read end to end, and they were chosen well enough to produce §13(s)
through §13(y) — **which is what makes the omission worth recording rather than just correcting.**
A criterion set assembled from what seemed measurable missed the one criterion whose defect was
already written down. **See §13(r).**

⛔ **RECORDED AS UNMEASURED, NOT AS ONE DEFECT.** The tooltip is a single instance. **Nothing has
audited `Semantics`, `semanticLabel`, `tooltip` or `excludeSemantics` across the app** — not their
presence, not their coverage, not whether any icon-only control other than that one announces
itself, not whether the reading order of any screen makes sense, not whether the two colour-alone
instances in §13(t) are reachable by a screen reader at all.

⚠️ **Scope for part 2**, and it is a larger surface than the four criteria already measured: 108
interactive constructions were enumerated for §13(x), and **how many of them announce themselves is
unknown.** ⛔ **Do not infer a count from the one known instance.**

---

### ⛔ NAMING FROM HERE: (aa), (ab), (ac) …

**Section 13 reached (z) on 8 September 2026 and the alphabet ran out.** Continuing as **doubled
letters** — `(aa)` through `(az)`, then `(ba)` — because it is unambiguous, sorts correctly, and
does not renumber anything already written. ⛔ **The alternative considered and rejected was
restarting at (a) in a new section 14**, which would have created two findings called (a) in one
document. **Recorded rather than chosen silently.**

⚠️ **EVERY FINDING BELOW RESTS ON 1x ANDROID PROXIES, and the scope amendment's rule applies:
layout and wrapping only, NOT rendering.** Where a finding is measured from source or from a
widget test rather than from a capture, it says so. **No finding here rests on how anything looked
on iOS, because nothing here was seen on iOS.**

---

### (aa) 🔴 THE WIDTH STRATEGY IS INCONSISTENT, NOT ABSENT

**Code-verified, 8 Sep 2026.** ⛔ **An earlier claim in this session — that content is capped at
`maxWidth: 520` app-wide — IS WRONG.** The inventory, derived from every file in `lib/screens/`:

| CAPPED at `maxWidth: 520` | UNCAPPED — full-bleed |
|---|---|
| `home_screen.dart:1003` | `history_screen.dart` |
| `log_event_screen.dart:555` | `event_wizard_screen.dart` |
| `your_data_screen.dart:62` | `about_screen.dart` · `conditions_screen.dart` · `disclaimer_screen.dart` · `help_screen.dart` · `medication_screen.dart` · `vocabulary_screen.dart` · `walkthrough_screen.dart` |
| **3 screens** | **9 screens** |

⚠️ **`medication_screen`'s bare `Center` at `:144` is an empty-state message, not a width cap** —
checked, because it looks like one in a grep.

⭐ **MEASURED, not inferred: the cap binds only above 560.** At 800 the content region is **520 px
wide inside a 760 px viewport**; at 430 it is **390 px, the full padded width**, so the cap is
inert on a phone. Both figures from a widget test, not a capture.

⛔ **THE INCONSISTENCY IS WORSE THAN ABSENCE, AND THAT IS THE FINDING.** A user moving from Home
(520, centred) to History (full-bleed 760) sees **the content region change width by 240 px with
no change of context**. Absence would at least be uniform. **Neither behaviour is declared
anywhere** — there is no breakpoint, no documented rule, and no comment in any of the three capped
screens explaining why those three.

⚠️ **§13(y) AND THE SCOPE AMENDMENT BOTH OVERSTATE THIS, and are corrected here rather than
rewritten.** Both describe *"content capped at `maxWidth 520` with no breakpoints"* as an app-wide
property. **It is true of 3 screens of 12.** The "no breakpoints" half stands unchanged and was
verified: `MediaQuery...size.width` **0 hits**, width-threshold branching **0 hits**, and both
`LayoutBuilder`s use `maxHeight` only.

---

### (ab) 🔴 DESTRUCTIVE AFFORDANCE DENSITY ON HISTORY

**Measured in a widget test, 8 Sep 2026** — `test/history_delete_geometry_test.dart`, twelve
same-shaped complete records.

| | 375x667 | 430x932 | 800x1280 |
|---|---|---|---|
| **delete controls on screen at once** | **7** | **11** | **12** |
| icon glyph | 24x24 | 24x24 | 24x24 |
| **tap target** | **48x48** | **48x48** | **48x48** |
| centre-to-centre, consecutive targets | 85 | **73** | **73** |
| **vertical GAP between targets** | 37 | **25** | **25** |

⛔ **Every row carries an unlabelled destructive control, and at 430 there are eleven of them on
one screen, 25 px apart.** The tap target is a correct 48x48 — ⭐ **the crowding is not the target
size, it is the density**: eleven adjacent 48 px destructive targets in a 932 px viewport.

⚠️ **THE TEXT-TO-ICON DISTANCE IS UNDETERMINED FROM THIS HARNESS, and that is recorded rather than
estimated.** The finder used to locate a row's title reported a left edge that **moved by the full
width delta** across the three cases (258 → 313 → 683 as width went 375 → 430 → 800). A
left-aligned `ListTile` title cannot do that, so the finder was matching something else and the
element could not be identified with confidence. ⛔ **A number whose subject is unknown is worse
than no number.** The claim that at 800 an icon sits closer to the next row's icon than to its own
row's text is therefore **NEITHER CONFIRMED NOR CONTRADICTED.**

**Semantics, re-confirmed 8 Sep 2026.** `history_screen.dart:1248` is
`IconButton(icon: Icon(Icons.delete_outline), onPressed: onDelete)` — **no `tooltip`, no
`semanticLabel`.** ⭐ **And the app-wide sweep is worse than §8 states: `tooltip:` appears exactly
FOUR times in all of `lib/`** — `history:670` Filters, `history:703` Export CSV, `home:1604`
Dismiss, `medication:171` Delete. **History labels its two app-bar actions and not the destructive
control on every one of its rows.** See §13(z) — semantics scope arriving with a visual case.

⭐ **THE DESIGN QUESTION, RECORDED AND NOT ANSWERED: does a destructive control belong on every
row at all?** ⚠️ **And the premise offered for asking it does not hold.** History has **no
selection mode** — the `__selection-mode` captures are `vocabulary__selection-mode`, not
`history__`, checked 8 Sep 2026. `history_screen.dart`'s nine `selection`/`_selected` hits are
filter-chip state. ⛔ **So "given selection mode exists" is false for this screen**, and the
question has to be asked without it.

---

### (ac) HOME'S VOID IS BELOW AS WELL AS ABOVE — and it is exactly symmetric

**Measured in widget tests, 8 Sep 2026**, one width per PROCESS —
`test/home_void_430_test.dart` and `test/home_void_800_test.dart` — because
`setMockInitialValues` does not take effect twice in one file.

| | 430x932 | 800x1280 |
|---|---|---|
| viewport height | 876 | 1224 |
| content height | 383 | **370** |
| **void ABOVE** | **246.5** | **427** |
| **void BELOW** | **246.5** | **427** |
| content as % of viewport | **43.7%** | **30.2%** |
| **void each side as %** | **28.1%** | **34.9%** |

⭐ **THE VOIDS ARE EXACTLY EQUAL AT BOTH WIDTHS — 246.5 / 246.5 and 427 / 427.** That is the
centring, measured rather than described, and it is why the two halves cannot be discussed
separately.

⛔ **AT 800 THERE IS MORE EMPTY SPACE ABOVE THE CONTENT THAN THERE IS CONTENT (34.9% against
30.2%), AND THE SAME AGAIN BELOW.** Content occupies under a third of the window.

⚠️ **Content is SHORTER at 800 than at 430** — 370 against 383 — because the 520 cap lets text wrap
less. **So widening the window shrinks the content and doubles the void.**

⭐ **A READING, MARKED AS A READING AND NOT A CONCLUSION.** The void **below** may be the more
serious half: space above a primary action reads as breathing room, while space below it reads as
a page that has ended, and at 800 there is 427 px of it beneath `Record Event`. ⚠️ **This runs
CONTRARY to §7 and §13(e), which both treat the void above as the problem.** ⛔ **Neither is
superseded. Both stand.** §7's recommendation to anchor rather than centre addresses both halves
at once, and this finding does not change it — it says only that the case for it may be stronger
below than above.

⚠️ **The figures are not comparable with §7's "roughly 150 px of void" or "around 350 above and
370 below"** — §7 measured a device capture including a status bar; these are widget tests without
one. **§13(e) already records that basis difference.**

---

### (ad) HISTORY IS UNSCANNABLE WHEN RECORDS RESEMBLE EACH OTHER

**Read from the device's accessibility tree AND seen in
`history__default__430x932__2026-09-08.png`, 8 Sep 2026 — so the ROW CONTENT is code-level
evidence, not a proxy reading, and only the visual density rests on the 1x capture.**

**Counted from the device's own accessibility tree, 8 Sep 2026, not from the image:** the visible
list runs

    4:41 PM   Add details: duration, type, severity
    10:17 PM  Seizure / fit   1m 45s · Mild
    10:03 PM  Seizure / fit   Mild   Add details: duration
    4:07 PM   Seizure / fit   1-5 minutes · Mild
    3:27 PM   Seizure / fit   < 1 minute · Mild
    1:54 PM   Seizure / fit   < 1 minute · Mild
    3:07 AM   Seizure / fit   < 1 minute · Mild
    3:05 AM   Seizure / fit   < 1 minute · Mild
    3:01 AM   Seizure / fit   < 1 minute · Mild      <-- and SIX more, byte-identical
    ...

⛔ **SEVEN rows are BYTE-IDENTICAL — `3:01 AM · Seizure / fit · < 1 minute · Mild` — and TEN
consecutive rows read `< 1 minute · Mild`.** ⭐ **On the seven identical rows even the timestamp
stops distinguishing them**, so nothing on the row identifies which record it is. A reader cannot
tell them apart, and neither can a reader who has just deleted one.

⚠️ **THIS IS TEST DATA AND THE DENSITY IS NOT REPRESENTATIVE.** Seven identical events at the same
minute is not a real history. ⛔ **But the failure mode is real and does not depend on the data
being synthetic**: any user whose events genuinely resemble one another — the same type, the same
severity, the same duration bucket, which is the common case for a single well-characterised
condition — gets the same wall. **A row that distinguishes records only by fields that repeat
distinguishes nothing.**

⭐ **Cross-reference §13(l): the screen already struggles to say how ONE record kind should appear
in it.** This finding is about the same list before a second kind is added.

---

### (ae) THE NEWEST RECORD PRESENTS AS INCOMPLETE, AT THE TOP OF THE LIST

**Seen directly, 8 Sep 2026, 1x proxy.** The first row of History reads
**`4:41 PM · Add details: duration, type, severity`** — the most recent record, at the top, framed
by what it lacks.

⛔ **§5 IS THE FINDING AND IS NOT RESTATED HERE.** It records the trade in full, including the
code's own counter-argument that a filtered list of quick-logs *"reads as broken rather than as a
work queue"* without the gap list. ⚠️ **What this adds is only WHERE it lands: at the top, on the
default screen, on the newest record** — so the first thing a reader sees in History is a
deficiency notice on the thing they did most recently.

⭐ **Fix 1A is visible and working in the same capture** — the copy reads `Add details:` and not
`Needs:`, on the real device. ⛔ **The open question in §5 is not answered here, and this finding
does not answer it.**

---

### (af) THE BOUNDED-CHIP LABEL COUNTS WHAT EXISTS, NOT WHAT IS HIDDEN

**Seen directly, 8 Sep 2026, 1x proxy, and confirmed against the device's own accessibility tree:
`32 to choose from · Show all`.**

The label sits beside a picker showing roughly ten chips out of 32 or 34. ⛔ **It names the size of
the VOCABULARY, not how many are shown and not how many are hidden** — so the number a reader most
needs, *how much is behind "Show all"*, is the one arithmetic they have to do themselves.

⚠️ **Minor, and vocabulary-track.** ⭐ **It belongs with the component-vocabulary work in §10
rather than with the layout work**, because it is a question about what a count means, and the same
label appears on every bounded picker in the app.

---

### (ag) THE FILLED-BUTTON PALETTE — one fill, four opposite meanings

**Code-verified, 8 Sep 2026.** Every `FilledButton` and `ElevatedButton` in `lib/screens/`, by
fill:

| Fill | Distinct buttons | Labels it carries |
|---|---|---|
| **navy #0D4F82** — 14 from the theme default, 1 explicit `MERColours.primary` | **15** | `I Understand and Agree` · `Add` (wizard) · `Next` (wizard) · **`Delete`** (history:576) · **`Reset`** (home:845) · `Record with details` · `Back up now` · `Add` (form) · **`Save`** · **`Go back`** · **`Cancel`** · **`Delete`** (medication:94) · `Save` (medication) · `Next` (walkthrough) · your-data action |
| **`MERColours.alert` #E05B3A** | **1** | **`Record Event`** — the primary capture action, and it FLASHES: see §13(ah) |
| **#D32F2F red** | **1** | `End Event` |
| **#E65100 amber** | **1** | `Retrying` (storage-fallback banner) |
| | **18 total** | |

⚠️ **The counts are DISTINCT CONSTRUCTOR SITES, computed rather than read off a grep.** A first
pass reported 17 navy by double-counting multi-line constructors and by misparsing `Record Event`'s
`_buttonFlash ? … : …` ternary as the theme default — **which would have hidden §13(ah) entirely.**

⛔ **NAVY FILLS `Delete`, `Save`, `Go back` AND `Cancel`** — a destructive confirmation, an
affirmative confirmation, a stay-here and a leave-here, in one colour. ⭐ **§1 already records this
as *"Destructive Delete and confirmatory Save are both filled blue, with no red anywhere"* — this
quantifies it: 15 of 18 filled buttons share one fill, and four of those fifteen have mutually
opposite consequences.**

⚠️ **And there IS red, in two shades, contradicting §1's "no red anywhere"** — `#D32F2F` on
`End Event` and `#E65100` on the fallback banner. ⛔ **Neither is on a destructive control.** The
one red-filled button ends an event; the two destructive `Delete` buttons are navy. **So red exists
and is spent on something else**, which is a stronger version of §8's *"orange does three jobs"*.

---

### (ah) 🔴 THE RECORD EVENT BUTTON FLASHES, AND §13(v) MUST BE QUALIFIED

⛔ **THIS CORRECTS §13(v), WHICH RECORDED FLASH CONTENT AS CLEAN ON 8 SEPTEMBER 2026. (v)'s search
did not find this, and the reason is worth recording: it enumerated ANIMATION WIDGETS and TIMERS
BY TYPE, and this is neither** — it is a `bool` swapped in a `backgroundColor`, driven by a
`Timer` that (v) did examine and classified by the *other* thing it drives.

**Code-verified, `home_screen.dart`:**

```dart
backgroundColor: _buttonFlash ? Colors.white : MERColours.alert,   // :1114

_buttonFlash = true;                                               // :563
// Decorative only. Restarted on each tap so a run of taps keeps flashing.
_flashTimer?.cancel();
_flashTimer = Timer(const Duration(milliseconds: 200), () {
  if (mounted) setState(() => _buttonFlash = false);               // :577
});
```

**MEASURED against WCAG 2.3.1's general flash threshold, both conditions:**

| | |
|---|---|
| `#E05B3A` relative luminance | **0.2363** |
| `#FFFFFF` relative luminance | **1.0000** |
| luminance change | **76.4% of full scale** — threshold is 10% → **MET** |
| darker state below 0.80 | **0.2363** → **MET** |
| **so a single transition IS a "flash" by the luminance test** | **YES** |

⭐ **AND THE RATE IS WHERE IT RESOLVES — the cancel-and-restart is a genuine safety property.**
Taps closer together than 200 ms **hold the button white continuously** rather than strobing,
because each tap cancels the pending timer. So fast tapping is *safer* than moderate tapping:

    tap spacing   white   orange   flashes/sec   over 3/sec?
      150 ms       --      --         0.00       no flashing at all, stays white
      200 ms       --      --         0.00       no flashing at all, stays white
      250 ms      200ms    50ms       4.00       ⛔ EXCEEDS
      300 ms      200ms   100ms       3.33       ⛔ EXCEEDS
      350 ms      200ms   150ms       2.86       under
      500 ms      200ms   300ms       2.00       under

⛔ **THE EXPOSED BAND IS TAPS SPACED 200-333 ms APART — 3 to 5 Hz — where the threshold is
exceeded.** Outside it, below 3 Hz or above 5 Hz, it is not.

⚠️ **WHETHER A USER REACHES THAT BAND IS UNMEASURED AND IS NOT GUESSED HERE.** It requires
deliberate repeated tapping of the primary capture button at a sustained 3 to 5 taps per second.
⭐ **But this is an epilepsy app, the flashing element is the largest button on the home screen,
and the code comment says the behaviour is intentional — *"a run of taps keeps flashing"* — so the
run-of-taps case was designed for rather than overlooked.**

⛔ **RECORDED, NOT FIXED, and no fix proposed.** ⚠️ **§13(v)'s other conclusions stand**: no
repeating animation, no controller, no Lottie, no GIF, no animation package, and the 1 Hz
`_ActiveEventBanner` timer changes no colour. **What (v) got wrong was the scope of its search, not
any of its individual results.**

---

### (ai) THE DISCARD DIALOG, ASSESSED ON THE DEVICE

**Seen directly at all three widths, 8 Sep 2026, 1x proxies** —
`form__discard-dialog__{375x667,430x932,800x1280}__2026-09-08.png`.

**✅ WHAT HOLDS:**

- **It does not read as the save dialog.** Different title, different verbs, different button
  arrangement.
- **The change list is legible at all three widths**, and wraps rather than truncating.
- ⭐ **The field-name prefix defeats the `Yes`/`Partly`/`No` collision recorded in §13(p).**
  `• Rescue medication: not recorded → Yes` and `• Did it help: Yes → Partly` are unambiguous
  precisely because the field is named before the value. **A finding in one place turning out to be
  already mitigated in another.**
- **`Go back` and `Discard` are visually distinguishable** — one filled, one not.
- ⭐ **`not recorded` rather than `No`, confirmed on a real record**, which is the nullable-bool
  distinction surviving all the way to the screen.

**⛔ WHAT DOES NOT:**

- **At 800 the dialog is phone-sized and sits low in the window.** It is not scaled to the
  viewport, so on a tablet it reads as a phone dialog on a large surface.
- ⛔ **It obscures the control the user just changed, and this is DERIVED FROM MEASURED
  COORDINATES rather than eyeballed.** At 800 the severity pills sit at y **548-592**
  (`Mild [140,547][305,593]`, `Severe [487,548][652,592]`), and the dialog's own buttons sit at y
  **692-740**, putting the dialog body across roughly y 500-740. **The two overlap: the dialog
  covers the severity row, which is the field named in the list beneath it.**
  ⚠️ **And WHICH control it obscures VARIES BY WIDTH** — at 430 the same pills are at y **509-555**
  while the dialog's buttons are at y **500-548**, a different overlap again. The dialog's position
  is fixed relative to the window; the content behind it is not, because the form scrolls
  differently at each width. **So there is no single answer to "what does it hide", and that is
  itself the finding.**

**Discard's tap target, measured on the device's accessibility tree at each width:**

| Width | `Discard` bounds | Target |
|---|---|---|
| 375x667 | `[244,367][311,415]` | **67 x 48** |
| 430x932 | `[299,500][366,548]` | **67 x 48** |
| 800x1280 | `[490,692][557,740]` | **67 x 48** |

⭐ **48 high at every width, so it meets WCAG 2.2 AA's 24x24 and Material's 48 — and the visual
affordance is smaller than the target, which is correct rather than a defect.** ⚠️ **A tap at
`(620,690)` — 63 px right of the target's right edge — hit the dialog barrier and dismissed it**,
which is how the divergence was noticed and is also the correct behaviour for a barrier tap.

⛔ **AND §13(y) APPLIES DIRECTLY HERE: on Windows there is no padded default at all.** These 48 px
targets come from `MaterialTapTargetSize.padded`, which `theme_data.dart` selects for Android,
Fuchsia and iOS and **not** for Windows. **The desktop build's discard buttons are unmeasured, and
this table does not describe them.**
