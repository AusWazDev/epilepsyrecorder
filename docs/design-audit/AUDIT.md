# MER — Design Audit

**Written 31 August 2026, AEST.** A whole-app design audit, from the 430×932 capture set at
`715ca95`, the code as it stands this session, and `DESCRIPTION-430.md`.

**Findings are recorded, not repaired. Nothing here was fixed while writing it.**

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

**2. How do episode and daily records coexist?** History, the export and the entry point all assume
one kind. **`daily_entry` is not a screen to add** — it is a second record shape that every one of
those surfaces has to accommodate.

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
