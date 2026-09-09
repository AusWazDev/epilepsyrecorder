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

> ⚠️ **ANNOTATED 8 September 2026 (evening) — THE THREE PERCENTAGES ARE APPEARANCE-DERIVED AND
> UNVERIFIED. The finding stands; the figures are not measurements.**
>
> **Instrument: tablet `adb screencap` frames, DPR 1.0, read by eye.** ⭐ **That instrument is
> geometry-faithful** — framebuffer, no compositing, no DPI translation, 1 logical px = 1 stored px
> — so **this is NOT the §13(al) class**, where the instrument itself was unfaithful. The defect
> available here is precision, not fidelity.
>
> ⛔ **AND PRECISION HAS ALREADY FAILED ONCE ON THE SAME FRAMES, THE SAME EYE AND THE SAME DAY.**
> §7's void figures, read the same way, were found **57 to 105 px out** when widget tests measured
> the same quantities. **These three figures inherit that error rate**, and *"roughly"* and
> *"about three-quarters"* are doing real work in the sentence.
>
> ⚠️ **NOT RE-MEASURED, AND THE REASON IS NAMED: §13(ac) measured HOME, not `wizard-5-summary`.**
> No widget test has ever rendered the review step. **So these figures are neither confirmed nor
> contradicted** — unlike §7's, which are corrected. ⛔ **Do not cite them as measurements.**
>
> ✅ **WHAT DOES NOT DEPEND ON THEM: the review step echoes type, severity, observations,
> beforehand and notes NOWHERE, which is code-verified**, and the ordering — that this is the
> emptiest screen in the app — survives any plausible correction to three figures that are 37, 56
> and ~75. **The conclusion is a ranking, and the ranking is not close.**

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

> ⚠️ **ANNOTATED 8 September 2026 (evening) — `78 %` AND `two-thirds` ARE DESCRIBED, NOT MEASURED,
> AND NOTHING IN THIS SECTION RESTS ON THEM.**
>
> ⛔ **Instrument: neither a widget test NOR a capture.** This section's own basis line reads
> **Described** — the depths were reasoned about, not read off a frame and not measured. ⭐ **That
> is a weaker basis than §3's and §7's, not a stronger one**, and it is stated here so the two
> percentages are never mistaken for the widget-test figures elsewhere in §13.
>
> ✅ **THE FINDING IS A RANKING, AND A RANKING IS WHAT THIS BASIS CAN CARRY.** Notes is
> **absent** from every other surface and **never echoed before save** — both code-verified — and
> its depth ordering across the three surfaces where it exists does not turn on whether step 4's
> position is 78 % or 70 %. ⛔ **The inversion is the finding: most reachable in the secondary
> feature, least reachable in the primary capture path.** That is a comparison, and it holds under
> any correction either figure could take.
>
> ⚠️ **Re-measurable by widget test and NOT DONE.** The two figures are open, not wrong.

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
> ⛔ **CORRECTED 8 September 2026 (evening) — THE RECONCILIATION ABOVE RUNS IN THE WRONG DIRECTION,
> and it appears in three places in this document.** [The sentence it corrects reads that the bases
> differ because *"§7 measured a device capture including a status bar"* while these are *"widget
> tests without one"*. **It stays readable above; it does not explain the gap.**]
>
> ⚠️ **A status bar makes the void above the content LARGER in frame coordinates, never smaller** —
> it pushes everything down. §7's figures are **smaller** than the widget tests', so a status bar is
> the wrong sign. **And every non-empty occupancy state in §13(e) raises `btnTop` further**, so no
> occupancy explains it either. ⛔ **The bases are not incommensurable. §7's numbers are simply out
> by 57 to 105 px, and §7 now records that** — an explanation was offered where a measurement was
> available.
>
> ⭐ **THE LESSON IS ABOUT THE EXPLANATION, NOT THE NUMBERS: a plausible reconciliation closed a
> question that a re-run of an existing test would have settled.** Both widget tests already existed
> when that sentence was written. **Where two figures for the same quantity disagree, re-measure
> before reconciling** — a reconciliation that is never checked is indistinguishable from one that
> is right, and this one survived three separate writings.

> ⛔ **CORRECTED 8 September 2026 (evening) — THE FIGURES IN THIS SECTION ARE WITHDRAWN AND THE
> MIDPOINT CLAIM IS RETRACTED. THE RECOMMENDATION IS CONFIRMED BY MEASUREMENT AND STANDS.**
>
> **The instrument.** These figures were read by eye off tablet `adb screencap` frames. ⭐ **That
> instrument is geometry-FAITHFUL** — `screencap` reads the framebuffer, so there is no window
> manager, no per-window compositing and no DPI translation between the layout and the file, and
> with the display override 1 logical px = 1 stored px. ⛔ **It is NOT the instrument that produced
> §13(al).** What failed here is not fidelity, it is **PRECISION**: the numbers were estimated by
> eye and hedged as *"roughly"* and *"around"*, and measurement now puts them 57 to 105 px out.
>
> **Measured in widget tests, 430x932 and 800x1280, DPR 1.0** — `test/home_void_430_test.dart`
> and `test/home_void_800_test.dart`, re-run 8 September 2026:
>
> | | claimed here | measured | out by |
> |---|---|---|---|
> | void above the primary action, 430 | **≈150** | **246.5** above the content block; **255** above the button block per §13(e) | **97 to 105** |
> | void above, 800 | **≈350** | **427** | **77** |
> | void below, 800 | **≈370** | **427** | **57** |
>
> ⛔ **AND THE MIDPOINT CLAIM IS FALSE BY MEASUREMENT.** At 800 the viewport spans y **56 to
> 1280**, so its midpoint is **668**. `Record Event` measures `btnTop=519.0 btnBottom=556.0`
> — **the primary action sits 112 px ABOVE the midpoint, entirely above it**, not below.
>
> ⭐ **AND IT NEVER FOLLOWED FROM THIS SECTION'S OWN FIGURES, which is the part worth keeping.**
> *"350 px above and 370 px below"* places the content **above** centre by 10 px, because less
> space above than below means the block sits high. **The stated conclusion contradicts the stated
> premise**, and no instrument is responsible for that — it was available to a reader of this
> section from the day it was written. ⚠️ **Read the arithmetic of a claim, not only its
> instrument.** A figure can be imprecise and a conclusion can be invalid, and these are two
> separate defects that happened to appear in one sentence.
>
> ✅ **WHAT STANDS, AND IT IS NOW MEASUREMENT-BACKED RATHER THAN EYEBALLED:**
> **the content is centred rather than anchored** — §13(ac) measured the voids **exactly equal at
> both widths**, 246.5/246.5 and 427/427, which is what centring means; **the first thing a tablet
> user sees is empty space** — 427 px of void above content in a 1224 px viewport, more void than
> content; and **at 375 this is the best-composed screen in the app**, which is an APPEARANCE
> reading and is exactly what a capture is for.
>
> ⛔ **THE RECOMMENDATION TO ANCHOR RATHER THAN CENTRE IS UNAFFECTED.** Every withdrawn figure was
> too SMALL. The measured voids are larger than the ones that motivated the recommendation, so
> correcting them strengthens it. ⚠️ **The recommendation was never load-bearing on the numbers**
> — it rests on the layout being `Center`, which is code-verified.

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
>
> ➕ **EVIDENCE ADDED 9 September 2026 — THE OPEN HALF IS NOT RESOLVED. This records a consequence
> of the completeness axis that nobody knew about when the question was framed, and it is not an
> answer to it.**
>
> ⛔ **THE AXIS DECIDED ACCESSIBILITY, AND NOBODY CHOSE THAT.**
>
> The two paths did not merely differ in field order, control kind and density — the three things
> this decision already names. **They differed in whether a medical record could be read back at
> all by a non-visual user.**
>
> | | control kind | announced its selected state? |
> |---|---|---|
> | **the wizard** (`event_wizard_screen.dart`) | real Flutter chips — `ChoiceChip` ×5, `FilterChip` ×2, `ActionChip` | ✅ **yes, free**, from `RawChip`'s own `Semantics(selected:)` |
> | **the form** (`log_event_screen.dart`) | hand-rolled `GestureDetector`s — `_SelectionRow`, `_SelectionWrap` | ⛔ **nothing** |
>
> ⛔ **AND `wantsWizard` ROUTES ON COMPLETENESS.** An incomplete record opens the wizard; a complete
> one opens the form. ⭐ **So a screen-reader user could read back the severity of a record they had
> NOT finished, and could not read back the severity of one they HAD.** The more complete the
> record, the less of it was legible.
>
> ⚠️ **FIXED 9 September 2026 — see §13(t) — so the consequence no longer holds.** `_SelectionRow`
> and `_SelectionWrap` now carry the same `RawChip` semantics the wizard's chips carry.
> ⛔ **BUT IT HELD FROM WHENEVER THE TWO PATHS DIVERGED UNTIL THEN, AND NOBODY KNEW.** No finding
> in this document records it; §13(z)'s own accessibility pass scoped itself to contrast,
> colour-alone, target size and flash and would not have found it either.
>
> ⭐ **WHY IT BELONGS HERE RATHER THAN ONLY IN §13(t): IT IS EVIDENCE ABOUT THE AXIS, NOT ABOUT THE
> CONTROLS.** Two independent implementations of one field will diverge on properties nobody is
> comparing — that is §1's *"every screen was solved; nothing was solved once"* — and **the routing
> axis then decides which users get which behaviour.** ⚠️ **Accessibility is one property that
> happened to be measured. The argument does not identify what else diverged, and nothing here
> establishes that this was the only one.**
>
> ⛔ **THE QUESTION STAYS OPEN.** Whether COMPLETENESS is the right axis is design-track and belongs
> with the component vocabulary, exactly as recorded above. **This adds a cost to the current answer;
> it does not choose a different one.**

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

> ➕ **ANNOTATED 8 September 2026 (evening) — THE RECOMMENDATION ABOVE IS LEFT EXACTLY AS WRITTEN
> AND WAS DEPARTED FROM. See §13(av), decision D3.**
>
> ⛔ **§13(a) shipped a confirmation dialog, which is the one thing the sentence above advises
> against.** D3 upholds the departure on two grounds — that capture-and-leave would let a change
> reach storage **without** the confirmation the developer required, and that the dialog sits on the
> EDIT path rather than the capture path, with 13 tests asserting every tap still records.
>
> ⚠️ **AND D3 RECORDS THE UNFLATTERING PART: this recommendation was not considered and set aside.
> It was never read.** ⭐ **So the departure is sound and its provenance is not** — the reasoning in
> D3 was constructed afterwards, when the conflict was found by reading this document.
>
> ✅ **THE OTHER HALF OF THIS FINDING IS UNTOUCHED AND STILL OPEN: seven top-level screens carry no
> exit guard of any kind.** D3 decides the shape of one screen's guard and decides nothing about the
> seven. ⛔ **Whether the app now has TWO exit rules — capture-and-leave on the wizard,
> confirm-on-dirty on the form — is named in D3 as undecided.**

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

⛔ **CORRECTED 8 September 2026 (evening) — THE RECONCILIATION ABOVE RUNS IN THE WRONG DIRECTION,
and it appears in three places in this document.** [The sentence it corrects reads that the bases
differ because *"§7 measured a device capture including a status bar"* while these are *"widget
tests without one"*. **It stays readable above; it does not explain the gap.**]

⚠️ **A status bar makes the void above the content LARGER in frame coordinates, never smaller** —
it pushes everything down. §7's figures are **smaller** than the widget tests', so a status bar is
the wrong sign. **And every non-empty occupancy state in §13(e) raises `btnTop` further**, so no
occupancy explains it either. ⛔ **The bases are not incommensurable. §7's numbers are simply out
by 57 to 105 px, and §7 now records that** — an explanation was offered where a measurement was
available.

⭐ **THE LESSON IS ABOUT THE EXPLANATION, NOT THE NUMBERS: a plausible reconciliation closed a
question that a re-run of an existing test would have settled.** Both widget tests already existed
when that sentence was written. **Where two figures for the same quantity disagree, re-measure
before reconciling** — a reconciliation that is never checked is indistinguishable from one that
is right, and this one survived three separate writings.

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
➕ **FEASIBILITY READ, 9 September 2026 — THE FINDING STANDS AND ITS DIAGNOSIS IS CORRECTED. The
banner is pointed at the WRONG RISK, not at a risk that does not exist.**

⛔ **THE CLAIM THIS FINDING RESTS ON IS NOT UNIFORMLY TRUE, AND THE REPLACEMENT COPY CANNOT STATE
IT FLATLY.** The sentence above — *"restore on a fresh install merges against an empty list and
reconstructs what an uninstall destroys"* — assumes an uninstall destroys the data on every
platform. **It does not.**

| Platform | Does uninstall destroy it? | Basis |
|---|---|---|
| **Windows** | ✅ **Yes.** MSIX uninstall removes app data and there is no OS cloud backup | ⚠️ **INFERRED** — platform behaviour, not read from this repo |
| **Android** | ⛔ **NOT RELIABLY.** `android:allowBackup` is **absent from the manifest**, and its documented default is **true**, so Google Auto Backup may capture the app data directory and restore it on reinstall | **READ:** `allowBackup` 0 hits (control `android:label` 2 hits); no `dataExtractionRules` or `fullBackupContent` XML anywhere in `android/` (0 files). ⚠️ **INFERRED:** what Android then does with it |
| **iOS** | ⛔ **NOT RELIABLY.** The database lives in `getApplicationSupportDirectory()`, which is included in iCloud and Finder device backups, and **nothing excludes it** | **READ:** `isExcludedFromBackup` 0 hits across `ios/` and `lib/` (control: 4 files reference the App Group). ⚠️ **INFERRED:** iOS backup inclusion rules |

⭐ **SO THE FINDING SURVIVES AND ITS ARGUMENT CHANGES.** The banner is still wrong — but not because
it understates a total-loss risk. **It is wrong because it names DEVICE TRANSFER, which is the least
important thing the file does, when the real point is that a backup is the only copy under the
user's own control.** ⚠️ *"A backup is the only way to keep your events"* would have been wrong in
the other direction, and would have been **the fourth time this app's copy was written from a
belief rather than from the model.**

⛔ **AND A CLAIM THAT NEVER REACHED A FILE IS RECORDED HERE SO IT CANNOT ARRIVE LATER.** *"The
desktop backup counter never clears"* was asserted repeatedly in briefing and **is false**.
`backupCountsAsTaken` gates only the SHARE path; `backupSaveAs` calls `markBackupTaken()` directly
after a successful write, and the source says so: *"Desktop users still clear it via Save to a file,
where completion is known."* ✅ **Searched: 0 occurrences in `docs/`, `STATUS.md` or `CLAUDE.md`
(control: a known phrase returns 2), so there is nothing to retract in place — it never landed.**

⚠️ **THE REAL ASYMMETRY THE COPY MUST SURVIVE, AND IT IS NOT THE ONE THAT WAS FEARED:**

    iOS       Share only  ("Save to a file" is compiled out -- file_selector has no iOS
                           save implementation)          -> Share DOES clear the counter
    Android   Save (to Downloads) or Share               -> both clear it
    Windows   Save (file picker) or Share                -> ONLY Save clears it;
                                                            Share reports `unavailable`

⛔ **So on Windows a user can complete a share and still be told they have events since their last
backup.** The copy must not promise that backing up clears the banner.

**MEASURED FOR THE REPLACEMENT, 9 September 2026** — `test/backup_banner_copy_measure_test.dart`.
⭐ **The text column is READ from the live widget tree, not estimated:**

| Viewport | Banner width | Text column |
|---|---|---|
| 375 | 335 | **306** |
| 430 | 390 | **361** |
| 800 | 520 | **491** — the `maxWidth: 520` cap of §13(aa) binding |

**Line counts in ROBOTO, which is Android's real font, at 13 px w400:**

| | 375 | 430 | 800 |
|---|---|---|---|
| current, 98 chars | 2 | 2 | 2 |
| LONG candidate, 126 chars | **3** | **3** | 2 |
| SHORT candidate, 94 chars | 2 | 2 | 2 |

⭐ **Banner height is `131 + body height`, so on Android the LONG candidate makes the banner 18
logical points TALLER at 375 and 430. The SHORT candidate does not change it at all.**

⛔ **AND THE CONTROL FAILED, WHICH IS REPORTED RATHER THAN WORKED AROUND.** The current copy wraps
to **2 lines in Roboto at 430** and the real iOS device capture shows **3**. ⚠️ **So Roboto is not a
stand-in for SF Pro and the iOS line counts above are NOT established.** Calibrated against that
capture's first line — 45 characters rendered at 313.3 logical — **SF Pro measures 23.3% wider than
Roboto at the same nominal size.**

⚠️ **AND THAT 23.3% CANNOT BE DECOMPOSED FROM ONE CAPTURE.** It is a real user's device, its Dynamic
Type setting is unknown, and §13(u) records that this app never reads `textScaler` — so the figure
combines the font difference with whatever text scale that device was set to. ⛔ **It is an upper
bound on the font difference, not a measurement of it.**

⭐ **WHAT THIS MEANS FOR THE DECISION: the Android figures are real, the iOS figures are not
available, and iOS is the tighter case** — the current 98 characters already take three lines there
at 430, so a 126-character string will take more at 306. **A candidate chosen on the Android numbers
alone will be chosen on the wider of the two margins.**
✅ **FIXED 9 September 2026. The finding above stands as written; the copy it describes is gone.**

**SHIPPED, quoted from `home_screen.dart`:**

> *A backup is your own copy — the only one that moves to a new device. Save it somewhere lasting.*

**95 characters against 98.** The superseded wording is preserved verbatim in a comment above it, per
this document's convention.

⭐ **IT IS SHORTER AND ONE LINE SHORTER, not merely not-longer.** Measured in
`test/backup_banner_copy_measure_test.dart`, Roboto at the theme-resolved style:

| | 375 | 430 | 800 |
|---|---|---|---|
| previous, 98 chars | **3 lines · body 54.0 · banner 185** | 2 · 36.0 · 167 | 2 · 36.0 · 167 |
| **shipped, 95 chars** | ✅ **2 lines · body 36.0 · banner 167** | 2 · 36.0 · 167 | 2 · 36.0 · 167 |
| the longer candidate, 126 chars | 3 · 54.0 · 185 | **3 · 54.0 · 185** | 2 · 36.0 · 167 |

**Text column READ from the live widget tree: 306 / 361 / 491** — the last being §13(aa)'s
`maxWidth: 520` cap binding. **Banner height is `131 + body height`.**

**WHY THE SHORTER CANDIDATE BEAT THE LONGER ONE THAT NAMED DESTINATIONS:**

1. ⛔ **The chooser already names them one tap later** — *"Email, cloud storage, spreadsheets"*. A
   banner that names destinations **pre-empts the chooser rather than complementing it.**
2. ⛔ **On iOS, "save it" is the one verb the app does not offer.** `file_selector` implements only
   `openFile`/`openFiles` there, so *"Save to a file"* is compiled out and Share is the only route.
3. ⭐ **Naming a cloud destination puts the suggestion before the user has chosen to share at all**,
   in an app whose whole differentiator is that nothing leaves the device unless the user sends it.
4. ✅ **And it cannot make the banner taller on the platform that could not be measured.** The longer
   one takes 3 lines at both 375 and 430 in Roboto, and iOS is wider still.

**WHAT THE COPY DELIBERATELY DOES NOT SAY, each ruled out on evidence:**

| Not said | Why |
|---|---|
| that an uninstall destroys the events | ⛔ **not reliably true.** `android:allowBackup` absent so Android defaults to allowing Auto Backup, no `dataExtractionRules` or `fullBackupContent`; `isExcludedFromBackup` 0 hits and the database sits in `getApplicationSupportDirectory()`, which device backups include. ⚠️ **Both INFERRED** — platform behaviour, not read from this repo |
| that a backup is the only way to KEEP events | ⛔ **false**, for the same reason |
| that it contains everything | ⛔ **false** — §13(ba): no vocabulary, no hide/retire state |
| that backing up clears this banner | ⛔ **not true on Windows via Share** — §13(bb) |

⚠️ **"device", not "phone", and it is not a style preference.** This app ships on the Microsoft
Store, so *"phone"* addresses a Windows user as someone they are not — and *"device"* is already the
word on screen here and in the share sheet. **A third word for one thing is what §1 is about.**

⛔ **iOS REMAINS UNMEASURED AND THAT IS NOT A GAP THIS FIX CLOSES.** Roboto puts the PREVIOUS copy at
2 lines at 430 while the real iOS device capture shows **3**, so the method is not valid for iOS and
the figures above are Android's. ⭐ **The shorter string is the safe choice precisely because iOS
could not be measured** — it is one line shorter than a string already known to fit there.

⚠️ **AND YESTERDAY'S CALIBRATION FIGURE IS CORRECTED: 18.1%, not 23.3%.** The first computation
omitted the theme's `letterSpacing: 0.25`, which the app's own `TextStyle` does not set and
therefore inherits. ⛔ **That was the same class of error as §13(ay) — a measurement missing an
INPUT the harness supplied — caught this time because the rendered paragraph and the calculator
disagreed on the previous copy's line count at 375, 3 against 2.** ⭐ **Two instruments on one
quantity is what found it; they now agree to 0.0 at every width.** The 18.1% is still an upper bound
on the font difference, since the reference capture's Dynamic Type setting is unknown and §13(u)
records that this app never reads `textScaler`.

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
⛔ **CORRECTED 9 September 2026 — ONE OF THIS FINDING'S THREE SITES IS A DEFECT. The other two are
not, and the read found TWO MORE that are.** The finding above stays exactly as written.

**SITE BY SITE, each judged against what it is FOR rather than against the definition:**

| site | what it is for | verdict |
|---|---|---|
| `eventsSinceLastBackup` | counts what is **unsaved** since the last backup | ✅ **CORRECT AS IS.** `logged_at` is the right value |
| `_thisMonthCount` (`home_screen.dart:523`) | a clinical count of events | ⛔ **STANDS AS A DEFECT.** Should be `whenHappened` |
| the CSV | export to a clinician | ✅ **ALREADY CORRECT**, and the omission is a DECIDED TRADE |

**1. ⛔ `eventsSinceLastBackup` IS NOT A DEFECT, AND THE REASON IS THE POINT OF THE WHOLE
DISTINCTION.** What is unsaved is what was **WRITTEN.** ⭐ **A record backdated to July but typed
after the last backup genuinely is unbacked-up**, and counting it by its occurrence time would tell
the user they were covered when they are not. **This site must keep `logged_at`.**

⚠️ **So "each of these silently uses the fallback as though it were the value" is wrong about this
one.** The fallback IS the value it wants.

**2. ⛔ THE CSV IS ALREADY CORRECT, AND THE CLAIM ABOUT IT IS WRONG TWICE OVER.** This finding says
the CSV *"carries no logged-at column at all; all three time columns are `whenHappened`"* and files
that under a heading about misuse.

✅ **Read from `buildCsv`: all three time columns — `timestamp_iso`, `date`, `time` — derive from
`whenHappened`, and so does the sort key (`rows.sort` on `r.whenHappened`). Of the 17 columns,
ZERO derive from `logged_at`.** The three agree with each other and with the row order, which is
the property History's own sort comment calls the defect the CSV used to have.

⛔ **AND THE OMISSION IS A DECISION, NOT AN OVERSIGHT.** `event_record.dart:925-945` records it as
the deliberate **v6** change, in its own words:

> *"⚠️ CONSEQUENCE, STATED RATHER THAN BURIED: where the two differ, the LOG TIME IS NO LONGER IN
> THE CSV. It is not lost — it is in the JSON backup and in `event.logged_at` — but a clinician
> reading only the file cannot see that a record was written three days late. A fourth time column
> was considered and rejected: the file already carries three, and one consistent meaning is worth
> more here than a completeness nobody asked for."*

⭐ **THIS FINDING PRESENTED AS A DEFECT WHAT THE SOURCE PRESENTS AS A DECISION — with the trade
stated, the loss bounded, and the alternative explicitly rejected.** ⚠️ **Same class as
`ARCHITECTURE.md` row 2 in §13(n): a document describing a deliberate arrangement as an error.**
⛔ **The FACT survives — the value the app counts by is the one the export omits — and the
CHARACTERISATION does not.**

**3. ✅ `_thisMonthCount` STANDS UNCHANGED AS A DEFECT.** A count of events in a month is a clinical
figure and should count by when they happened. The forward-looking risk this finding already records
— a days-in-month denominator against a logging-time numerator — is the same argument.

⭐ **AND TWO SITES THIS FINDING NEVER HAD, both more visible than the one it got right: see
§13(bc).** ⛔ **Plus a live defect in no finding at all: §13(bd).**

⚠️ **PRIORITY DROPPED 9 September 2026: UNEXERCISED on current device data — zero non-null
`occurred_at` across all 58 records, with `duration_seconds` (13/45) and `event_type` (45/13) as
discriminating controls. ⛔ NOT CLOSED — untriggered is not fixed. The full annotation is at the end
of §13(bd).**

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

➕ **INSTANCE 12, 8 September 2026 (evening) — and it is a DISTINCT SUB-SHAPE, not another
instance of distance.**

| # | The knowledge | Where it sat | What happened anyway |
|---|---|---|---|
| 12 | `setMockInitialValues` *"does NOT take effect once an instance exists earlier in the same file"* — **once, not once per state** | **`CLAUDE.md`'s own test-harness rule, in the rule's FIRST PARAGRAPH** | the same rule's **heading** said *"ONE STATE PER PROCESS"* and its **MUST 1** said *"more than one state means more than one file"*. Six tests needed three files, all setting the identical state |

⛔ **EVERY OTHER INSTANCE IN THIS TABLE IS A DISTANCE PROBLEM — the fact was in another file, another
section, or twenty lines away, and was not read. THIS ONE WAS READ.** The rule was consulted; the
mechanism paragraph was correct and correctly understood. **What misled was the rule's own SUMMARY
of itself.**

⭐ **A heading and a numbered MUST are what a reader uses to decide whether a rule applies to their
situation.** Both pointed at *how many STATES* a file uses. The situation was *how many TESTS
depend on prefs at all* — a file with two prefs-dependent tests setting the SAME state is already
broken, which the summary excluded by its own wording. **So the rule was consulted, believed, and
gave the wrong answer, while the paragraph above the wrong answer held the right one.**

⚠️ **AND IT PRESENTED AS SOMETHING ELSE ENTIRELY, which is why it cost two rounds.** Not a test
failure and not a wrong measurement — **a helper function returning `-1`**, because the screen the
test expected was not the screen on display. **The helper was rewritten twice, once by geometry,
before the process boundary became the suspect.** A diagnostic in a separate file then printed the
expected text immediately, which is what pointed at the file boundary rather than the finder.

⭐ **THE SUB-SHAPE, STATED SO IT IS RECOGNISABLE NEXT TIME: a rule can be undermined by its own
summary.** Distance is not the only failure mode for written knowledge — **compression is another,
and it is harder to spot, because the summary is exactly the part a reader trusts to tell them
whether to read the rest.** ⛔ **Practical form: when a rule states a mechanism and then states a
countable condition, check that the condition follows from the mechanism.** Here it did not: *"once
an instance exists"* does not license *"more than one state means more than one file"*.

➕ **INSTANCE 13, 8 September 2026 (evening) — A CLAIM ABOUT THIS ARTEFACT, ASSERTED FROM
RECOLLECTION IN NEARLY EVERY BRIEF OF THE SESSION, AND NEVER CHECKED AGAINST IT.**

| # | The knowledge | Where it sat | What happened anyway |
|---|---|---|---|
| 13 | §10's six fixes carry **no status annotation of any kind** | **this document, §10, since 31 Aug 2026** — the list has never been annotated | *"the five remaining section 10 fixes"* was asserted as a standing figure in brief after brief, and used to scope work, without once being read |

⛔ **THE FIGURE IS UNSUPPORTED.** §10's *"Then six fixes that depend on none of the above"* is
followed by six numbered items and one parenthetical about a seventh that was withdrawn. **There is
no ✅, no FIXED, no date, no annotation on any of the six.** The only status statement anywhere is
inside §13(ae): *"Fix 1A is visible and working in the same capture"* — the History copy reads
`Add details:` rather than `Needs:`, confirmed on the real device.

⚠️ **AND NO CORRECTED COUNT IS OFFERED HERE, DELIBERATELY.** ⛔ **§10's FIX STATUS IS UNTRACKED.**
"Five remaining" may even be right; **nothing in the repository says so**, and substituting a
different number invented the same way would repeat the error with better luck. ⭐ **Establishing
the status of the six is an OPEN ITEM**, and it is a cheap one: each of the six names a specific
behaviour, and each can be checked against `lib/` in one pass.

⭐ **THE SUB-SHAPE, AND IT IS DIFFERENT FROM INSTANCE 12's.** Instance 12 was a rule undermined by
its own summary — the document said the wrong thing about itself. **This is a document that says
nothing, and a reader who supplied the missing statement from memory and then treated it as read.**
⛔ **An absent status is not a neutral gap: it is an invitation to fill in, and the filled-in value
is indistinguishable in a brief from a quoted one.**

⚠️ **AND THE HALF-SHIPPED FIX IS WHY THE FIGURE WAS PLAUSIBLE.** Fix 1 has a **copy half that
shipped** and a **design half that §5 explicitly leaves unanswered** — *"the counter-argument that
must be answered, not bypassed."* ⛔ **So "one down, five to go" is not even the right SHAPE for
fix 1**, let alone a count of the rest. **A partially-shipped item cannot be counted in either
column, and that is exactly the state that made an unchecked count feel safe.**

⭐ **PRACTICAL FORM, and it is this document's own rule turned on the document: a status is a claim
about a FILE, and is verified by reading the file.** Where an artefact carries no status field, the
honest report is **UNTRACKED** — never a number.

---

**⛔ AND THE COUNT GROWS AGAIN, 9 September 2026 — THIS TIME THE ARTEFACT ITSELF DID NOT TRAVEL.
A NEW VARIANT: not knowledge that failed to reach a reader, but a TRAVELLING DOCUMENT CITING A
NON-TRAVELLING ARTEFACT.**

**§13(be) was written on Windows and committed. It cited the evidence for an unrecoverable data loss
by OneDrive path and sha256 — `MER Device Baselines/EVIDENCE 2026-08-30 session transcript
(59-record state)`.** ⛔ **`AUDIT.md` travels by `git push`. That file does not.** So the pointer was
correct, verifiable, and **resolvable only on the one machine that already had the file** — which is
the one machine that did not need the pointer.

⭐ **THE SHAPE, AND IT IS NEW TO THIS SECTION: every earlier instance here is a fact that was written
down and not read. This is a fact that was written down, WAS read, and pointed somewhere the reader
could not follow.** ⚠️ **A citation is only as portable as the artefact it names, and nothing in a
markdown reference declares its own reachability.**

⛔ **AND THE RULE AGAINST IT WAS ALREADY IN THIS REPOSITORY'S OWN CONTEXT FILES** — *"anything
recording another artifact's hash, size or version needs a sync step in the same pass that changes
the artifact"*, recorded after a recovery runbook was found carrying a hash for a payload that had
moved on. ⭐ **Same failure, one turn later, in the document that records the data loss.** ⚠️ **The
rule was not missing. It was filed as a documents-and-tooling rule, and this was read as a findings
document.**

✅ **REPAIRED, not rewritten:** the 8,436-byte extract is now committed at
`docs/EVIDENCE-2026-08-30-59-record-reading.txt` with its hash stated in §13(be), so the
load-bearing part of the citation resolves for any reader who has the repository. ⛔ **The
7,800,641-byte transcript still exists on one machine only and cannot be made to travel by this
route** — that half is recorded as unresolved rather than repaired, which is the honest end state
and not a closed one.

⚠️ **PRACTICAL FORM, and it is the section's own rule extended one step: a reference is a claim about
REACHABILITY, not only about content.** When a document that travels cites an artefact that does
not, either bring the artefact into the travelling set or **state in the citation that it does not
travel and where it actually lives.** ⭐ **Never leave a hash as the only evidence of something a
reader cannot open.**

---

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

> ⚠️ **DESCRIPTION CORRECTED 9 September 2026 — THE FINDING STANDS AND ITS DESCRIPTION OF THE VISUAL
> CUE WAS WRONG. Two different things, and the distinction is the point.**
>
> ⛔ **WHAT WAS WRONG.** The row above reads *"border width 0.5 → 1.5 only. Non-colour, but s[mall]"*.
> **Selection changes FIVE properties, not one**, read from `_SelectionRow` and `_SelectionWrap`:
>
>     fill colour      MERColours.primary / alert   vs  MERColours.surface
>     border colour    the same colour              vs  MERColours.border
>     border width     1.5                          vs  0.5
>     font WEIGHT      w600                         vs  w500 (Row) / w400 (Wrap)
>     text colour      white                        vs  textMuted (Row) / textPrimary (Wrap)
>
> ⭐ **So the non-colour differentiation is border width AND FONT WEIGHT** — two cues, not one. The
> row's *"no weight change"* is false.
>
> ✅ **WHAT STANDS, UNCHANGED: none of the five is reachable by a screen reader.** All five are
> visual, so the WCAG 1.4.1 concern and the semantics gap both hold exactly as recorded.
> ⭐ **The finding was right about the consequence and wrong about the mechanism**, which is the
> distinction §13(al) exists to teach: a correct conclusion resting on a mis-described cause is
> still a liability, because the next reader reasons from the cause.
>
> ⚠️ **AND IT MATTERED PRACTICALLY.** The fix brief for this control was written from *"border width
> only"*, and a reader could reasonably have concluded the remedy was to strengthen the non-colour
> cue — adding an icon or a weight change **that was already there.** ⛔ **The remedy was semantics,
> and the description pointed away from it.**

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


✅ **FIXED 9 September 2026 — `_SelectionRow` NOW ANNOUNCES WHICH OPTION IS SELECTED. Nothing
visual changed.** `lib/screens/log_event_screen.dart`, verified in
`test/selection_row_semantics_test.dart`.

**BEFORE, from the semantics tree on unpatched code:**

    SELECTED : []

⛔ **Empty. Not one of the five fields announced its answer** — severity, rescue given, did-it-help,
second dose, referral.

**AFTER, same tree, same record (severity Severe, given Yes, helped Partly, second dose No,
referral Yes):**

    SELECTED   : [Severe, Yes, Partly, No, Yes]
    unselected : [... Mild, Moderate ... No, Yes, No, Yes, No ...]
    node: label="Severe" tap=true isSelected=Tristate.isTrue  isButton=true
    node: label="Mild"   tap=true isSelected=Tristate.isFalse isButton=true

**THE MECHANISM IS COPIED, NOT INVENTED.** `Semantics(container: true, button: true, selected:
kIsWeb ? null : isSelected, checked: kIsWeb ? isSelected : null)` — **the exact shape `RawChip`
uses, READ at `chip.dart:1503-1513`**, including the framework's own reason for the web branch
(*aria-selected only applies to certain roles*). ⚠️ **Web is not a shipped target, so that branch is
inert today.**

⭐ **AND THE CHOICE OF `RawChip` OVER `Radio` WAS DECIDED BY THE APP, NOT BY TASTE. The wizard
already announces these same fields** — `event_wizard_screen.dart` renders them with real
`ChoiceChip`s (5) and `FilterChip`s (2), which get this for free. **Copying the chip shape makes the
two edit paths agree instead of giving this screen a third idiom** (§1; §10 decision 1).

⛔ **AND THAT IS THE FINDING THIS FIX UNCOVERED, WHICH IS LARGER THAN THE FIX: THE TWO EDIT PATHS
DISAGREED ON WHETHER A MEDICAL RECORD IS READABLE NON-VISUALLY.** `wantsWizard` routes an
INCOMPLETE record to the wizard and a COMPLETE one to the form (§10 decision 1). So before this
change, **a screen-reader user could read back the severity of a record they had not finished, and
could not read back the severity of one they had.** ⭐ **The completeness routing axis decided
accessibility.** That is now closed for `_SelectionRow`; §10 decision 1's open half is unaffected.

**VERIFICATION, each capable of failing, with the control run against unpatched `lib/`:**

| | patched | unpatched control |
|---|---|---|
| 1. all five fields announce their answer | ✅ pass | ⛔ **FAILS** — `SELECTED: []` |
| 2. changing a selection changes the announcement | ✅ pass — after tapping `Severe`: `[Severe, Yes, Yes, No, No]` | ⛔ **FAILS** |
| 3. **the render is unchanged at 375, 430, 800** | ✅ pass | ✅ pass |

⭐ **TEST 3 IS THE ONE THAT MATTERS FOR "NOTHING VISUAL CHANGED", AND IT PASSES IN BOTH STATES BY
DESIGN.** Its baseline is **36 rects — 12 option pills × 3 widths — captured from the UNPATCHED
code and pasted in.** It still matches with the wrapper in place, so the wrapper moved nothing.
⚠️ **A test that passed only after the change would not have proved this.**

✅ **And the diff itself is the other half of that proof: one import and a `Semantics` wrapper.** No
colour, fill, border colour, border width, padding, font size, font weight, text or layout property
appears in it. `flutter analyze` on `log_event_screen.dart`: **13 infos before, 13 after, delta 0.**

⚠️ **ONE CORRECTION TO §13(t)'s DESCRIPTION OF THIS CONTROL, found while reading it.** §13(t) says
selection is accompanied by *"border width 0.5 → 1.5 only"*. ⛔ **It is five properties, not one:**
fill colour, border colour, border width, **font weight w500 → w600**, and text colour. **So the
non-colour differentiation is border width AND font weight** — §13(t) understates it. ⭐ **None of
the five is reachable non-visually, so the finding stands; its description of the visual cue does
not.**

⚠️ **AND `_SelectionWrap` HAS THE SAME DEFECT AND IS NOT FIXED.** The multi-select for feelings and
triggers is also a hand-rolled `GestureDetector` with no semantics, so **which observations are
selected is still unavailable non-visually.** ⛔ **Out of this pass's scope and recorded as OPEN.**

**WHY THIS WAS FIXED NOW RATHER THAN QUEUED, under §13(aw)'s test:** ⭐ **`Semantics(selected:)` is a
property of a control, not a design decision.** Whatever the component vocabulary chooses for a
selection control, it still has to announce its state — so the decision survives even if this
implementation does not.

⛔ **AND THE HONEST COUNTER-ARGUMENT, RECORDED BECAUSE IT IS REAL: if the vocabulary replaces
`_SelectionRow` with a standard Flutter chip, selection semantics come free and this work is
discarded.** It was fixed anyway because **the vocabulary has no date and this is a medical form
whose severity a user could not read back.**

⛔⛔ **AND THE SURVIVES-THE-REDESIGN ARGUMENT IS NOT SELF-VALIDATING. THE SAME ARGUMENT WAS MADE FOR
§13(ay) ON 8 SEPTEMBER AND WAS WRONG — THERE WAS NO DEFECT AT ALL.** ⭐ **A future reader should
treat this paragraph with suspicion, not as a warrant.** What distinguishes this case from that one
is not the argument's form: it is that **the defect here was demonstrated by an instrument that has
not lied** — the semantics tree, showing an empty selected set — **before any fix was written**,
whereas §13(ay) rested on glyph widths from a harness whose font is fake.
✅ **AND `_SelectionWrap` FIXED 9 September 2026 — THE MATCHED PAIR IS NOW WHOLE.** The multi-select
for **observations (afterwards)** and **triggers (beforehand)** announces which options the record
holds. Verified in `test/selection_wrap_semantics_test.dart`.

⭐ **THE DEFECT WAS IDENTICAL IN KIND, AND THE SUSPICION THAT THE MECHANISM WOULD DIFFER WAS
REFUTED BY READING THE SDK.** It was reasonable to expect a multi-select to need a different shape —
`FilterChip` rather than `ChoiceChip`. ⛔ **They pass `selected` to `RawChip` identically, and
`RawChip` has exactly ONE `Semantics(` block.** The only difference between the two chips is
`showCheckmark`'s default, which is **visual**. **So one form serves both, which is also the right
answer for consistency.**

**BEFORE / AFTER, from the semantics tree, same blank record, tapping two observations:**

    UNPATCHED   after tapping 😴 Tired and 🪫 Weak:   SELECTED = [Mild, No]
    PATCHED     after the same two taps:              SELECTED = [Mild, 😴 Tired, 🪫 Weak, No]

⚠️ **`Mild` and `No` in BOTH columns are `_SelectionRow`, fixed earlier the same day** — and their
presence is what made the *"fixed control beside an unfixed twin"* state visible in the tree.
⛔ **A first version of this test asserted the whole-tree selected set was empty on a blank record
and failed on its own sibling's CORRECT output.** Scoped to this widget's chips instead.

**VERIFICATION, with the control run against unpatched `lib/`:**

| | patched | unpatched |
|---|---|---|
| 1. nothing announces on a blank record | ✅ | ✅ |
| 2. **selecting TWO announces BOTH** | ✅ | ⛔ **FAILS** |
| 3. triggers announce, and de-selecting stops announcing | ✅ | ⛔ **FAILS** |
| 4. **render unchanged at 375, 430, 800** | ✅ | ✅ |

⭐ **TEST 2 IS THE MULTI-SELECT-SPECIFIC CONTROL: two chips, not one.** A single-selection assertion
would pass on a broken multi-select that only ever marked the most recent tap. ⭐ **And test 4's
baseline — 12 rects, 4 chip labels × 3 widths — was captured from the UNPATCHED code, so it passes
in both states.** That is what makes it a proof rather than a formality.

✅ **`flutter analyze` on `log_event_screen.dart`: 13 infos before, 13 after, delta 0.** The diff
contains no `color`, `width`, `padding`, `fontSize`, `fontWeight`, `borderRadius`, `duration` or
`Icon` — checked mechanically, comments excluded.

⚠️ **ONE THING IN THIS WIDGET IS DELIBERATELY UNTOUCHED: the "Add your own" pill.** It is a
`GestureDetector` wrapping an `Icon` plus a `Text`, so **it already has a name from its visible
text** — but it is not marked `button: true` and it is an ACTION rather than a selectable. ⛔ **Left
alone: it is not the selection defect, and marking it would be a separate decision.**

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

⛔ **AND WHY IT WAS MISSED IS A TAXONOMY FAILURE, NOT A CONTROL FAILURE — recorded 8 September
2026, because the distinction changes the remedy.**

**Every control in this search fired.** `AnimatedContainer = 5` proved the reader reached the
widgets. `sqflite = 3` proved `pubspec` was read. The known-absent probe returned zero. **Eleven
`repeat` hits and six `reverse` hits were each adjudicated individually rather than counted.**
⭐ **Nothing about the apparatus was wrong. The FRAME was wrong.**

**The search enumerated animation CONSTRUCTS BY TYPE** — `AnimatedContainer`,
`AnimationController`, `Tween`, `Lottie`, `.repeat(`, animation packages, GIF assets. **WCAG 2.3.1
is not about constructs. It is about LUMINANCE OVER TIME.** A `bool` swapped inside a
`backgroundColor` expression, driven by a `Timer` this search did examine and classified by the
*other* thing that timer drives, is a 76.4%-of-full-scale luminance change at up to five per
second — and it is not an animation widget, so a type-based enumeration cannot see it.

⭐ **THE TRANSFERABLE RULE: SEARCH THE CRITERION, NOT THE IMPLEMENTATION.** The criterion is
"luminance changing at rate", so the search should have enumerated **every expression that can
change a colour over time** — ternaries on a `bool`, `WidgetStateColor.resolveWith`, `setState`
touching any colour field, and timers by *what they set* rather than by their type. §13(t) found
the same shape from the other direction: the colour-alone search found 4 conditional colours until
it was run multiline, and then found 14.

⚠️ **The scope of this search was set before the criterion was read carefully**, and that is the
correctable part. ⛔ **A control can only tell you your instrument works on the corpus you pointed
it at. It cannot tell you that you pointed it at the wrong corpus** — which is the same lesson as
the declared-versus-derived scope class this document already records, arriving in a criterion set
rather than in a script.

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
✅ **MEASURED 9 September 2026 — the measurement half of this finding is closed. The finding above
stands as written; it is answered, not corrected.** Instruments:
`test/semantics_tree_home_test.dart` and the sweep recorded below.

**1. THE DENOMINATOR — 117, NOT 108, AND 108 HAS NO STATED DERIVATION.**

⛔ **§13(x)'s figure of *"108 interactive constructions"* is not reproducible, because neither
§13(x) nor this finding says what was counted.** A re-derivation gives **117**. ⚠️ **Coincidence
worth naming so it is not read as agreement: 108 is also the number that carry a name below. Two
different quantities, one number.**

**Method, so the figure can be disagreed with:** every `.dart` under `lib/` (34 files), comments and
string literals stripped first, counting constructor calls for buttons, tiles, raw gestures, menus,
toggles, chips and text entry. **13 excluded and itemised, nothing silently dropped:**
`TextButton.styleFrom` ×5, `ElevatedButton.styleFrom` ×3, `FilledButton.styleFrom` ×3,
`OutlinedButton.styleFrom` ×2 — **`ButtonStyle` factories, not controls.**

| group | n |
|---|---|
| buttons | 58 |
| raw gestures (`InkWell`, `GestureDetector`) | 18 |
| menus | 11 |
| tiles | 10 |
| chips | 10 |
| text entry | 9 |
| toggles | 1 |
| **TOTAL** | **117** |

⚠️ **FIVE DEFECTS IN THIS PROBE, ALL FOUND BY READING ITS OUTPUT AND ALL FIXED BEFORE THE FIGURES
BELOW.** Recorded because the brief warned that the last several probe failures were the probe
encoding an assumption about the answer, and four of these are exactly that:

    1. GENERICS      `PopupMenuButton<_HomeMenuAction>(` never matched -- the pattern
                     required '(' straight after the name. Every generic control was invisible.
    2. STYLE FACTORY `TextButton.styleFrom(` counted as a control, which is why
                     theme/mer_theme.dart appeared with 3 "controls" in it.
    3. LINE NUMBERS  block comments were replaced with one space, collapsing them and
                     shifting every line after. Caught because medication's tooltip
                     printed at :170 where §8 cites :171.
    4. NESTED NAMES  a parent inherited a child's name -- medication's ListTile was
                     credited with the `tooltip: 'Delete'` of the IconButton in its
                     `trailing:`. Caught by a COUNT: 5 tooltip-named controls against
                     only 4 `tooltip:` in all of lib/.
    5. OFF BY ONE    the fix for (4) skipped the first nested control, because the span
                     starts at the opening paren, not the widget name.

**2. COVERAGE — 112 of 117 CARRY A NAME. FIVE DO NOT.**

| name source | n |
|---|---|
| its own visible text | 97 |
| `labelText` / `hintText` on a field | 9 |
| `tooltip` | 4 |
| framework default (`PopupMenuButton` → `showMenuTooltip`) | 1 |
| **⛔ NONE** | **5** |

⭐ **`semanticLabel` is used ZERO times in `lib/`. Every name in this app is a side effect of
something visible.**

⚠️ **FOUR FALSE POSITIVES WERE ADJUDICATED OUT BY READING EACH SITE, and they are named because a
static classifier is a candidate generator, not a finding:** `event_wizard:776` and
`log_event:118` are `TextField`s whose `labelText: prompt` is a **variable**, so the literal-only
matcher missed a real label; `help_screen:852` is an `InkWell` wrapping a `Row` that contains text;
and `home_screen:942`'s `PopupMenuButton` gets **`showMenuTooltip`** from the framework — READ at
`popup_menu.dart:1748` and `:1780`, `widget.tooltip ?? MaterialLocalizations.of(context).showMenuTooltip`.

**THE FIVE WITH NO NAME:**

| file | line | control | what it does | destructive? |
|---|---|---|---|---|
| `event_wizard_screen.dart` | 373 | `IconButton` `arrow_back` | wizard back / exit | no — §13(b): captures and leaves |
| `history_screen.dart` | 460 | `IconButton` `clear` | clears the SEARCH FIELD | no |
| **`history_screen.dart`** | **1248** | **`IconButton` `delete_outline`** | **deletes a record** | 🔴 **YES, and irreversible** |
| `log_event_screen.dart` | 522 | `IconButton` `arrow_back` | form back / exit | no — §13(a) prompts when dirty |
| `vocabulary_screen.dart` | 443 | `Checkbox` | selection in "Your lists" | no — selection only |

⛔ **ONE OF THE FIVE IS DESTRUCTIVE, NOT THREE.** A first pass flagged three by matching
`clear|remove` in the surrounding code — but `history:460` clears a **search box** and
`vocabulary:443`'s `remove` is `_selected.remove(k)`, a **selection set**. ⭐ **Neither touches
data.** `history:1248` does, and §13(ax) records that a delete leaves no row, no flag and no log.

✅ **POSITIVE CONTROL, as the brief required — the sweep finds BOTH sides of §8's observation:**
`history_screen.dart:1248` `IconButton` → **source NONE, icon-only**, and
`medication_screen.dart:170` `IconButton` → **source tooltip, "Delete"**. **The inconsistency §8
recorded is reproduced by an independent instrument.**

⚠️ **AND THE FOUR TOOLTIPS RECONCILE EXACTLY WITH §13(ab)** — `history:670` Filters,
`history:703` Export CSV, `home:1650` Dismiss, `medication:171` Delete. ⛔ **§13(ab) cites
`home:1604` for the third, and that citation is now STALE** — the banner rewrite of §13(h) moved it.
⭐ **The line-number rot this project already warns about, arriving again from an unrelated edit.**

**3. WHAT COVERAGE DOES NOT ANSWER.**

**(a) §13(t)'s THREE COLOUR-ALONE INSTANCES — ONE IS MOOT AND TWO ARE WORSE THAN §13(t) RECORDS.**

| §13(t) instance | reachable by a screen reader? |
|---|---|
| **"This month"** in `alert` when non-zero | ⭐ **MOOT.** `_StatCell` renders `Text(value)` then `Text(label)`, so the reader gets *"0"* then *"This month"*. **The number is fully available; only the emphasis is lost — and §13(k) argues that emphasis is editorial and should not exist.** No information is withheld |
| **walkthrough page dots** | ⛔ **WORSE. Not colour-alone — ABSENT.** They are bare `Container`s with a `BoxDecoration` colour, no text, no `Semantics`. **A non-visual user gets no step indicator at all**, in either state |
| **`_SelectionRow` selected state** | ⛔ **WORSE.** A `GestureDetector` (`log_event_screen.dart:1082`) wrapping a `Text` (`:1097`), with **no `Semantics(selected:)`**. The label is announced; **which option is chosen is not.** It is carried by fill colour and a 0.5→1.5 border only, both visual |

⚠️ **AND THE THIRD IS THE CLINICAL ONE.** `_SelectionRow` is severity, rescue given, did-it-help,
second dose and referral — **the fields §13(m) was about.** A reader hears the options and not the
answer.

**(b) `excludeSemantics` AND `ExcludeSemantics`: ZERO. Nothing is hidden from the tree.**
✅ **Adjudicated with a control** — `excludeSemantics` 0, `ExcludeSemantics` 0, `MergeSemantics` 0,
against `setState(` at **74** in the same corpus by the same method.
⭐ **And the one `Semantics(` in all of `lib/` is GOOD practice, not a gap:**
`history_screen.dart:961` wraps the filter summary in `liveRegion: true, container: true`, so a
change to it is announced. **It is the app's only deliberate semantics, and it is correct.**

**(c) READING ORDER ON HOME — REPORTED, NOT JUDGED**, from the traversal-order dump at 430x932,
28 nodes, count-reconciled against the paint-order walk:

    app bar "Medical Event Recorder / Record · Review · Share"  ->  "Show menu" [tooltip]
    -> "12 events since your last backup" -> "Dismiss" [tooltip] -> the banner body
    -> "Back up now" -> "Record Event / Tap to timestamp now" -> "Record with details"
    -> "0" "This month" -> "12" "Total saved" -> "20" "Days since" -> "0" "Referrals"
    -> "LAST EVENT" -> "20 Aug 2026 · 03:12" -> "Tap edit to update details"
    -> "Edit details" -> "All history" -> "Need Help with MER?"

✅ **HOME HAS ZERO TAPPABLE NODES WITH NO NAME.** All 8 of its tap targets announce something.
⚠️ **Two of them get their name from `tooltip` rather than `label`** — Dismiss and Show menu — and a
first version of this probe read `label` only and reported both as unlabelled. **Same class as
§13(az): the probe encoded an assumption about where the answer lives.**

⚠️ **Stated without judgement, as the brief required: each statistic reads as its VALUE and then its
LABEL** — *"0", "This month"* — and **"0" occurs twice**, for This month and Referrals, with nothing
between them but the intervening labels.

**(d) ICON-ONLY CONTROLS: EIGHT `IconButton`s. FOUR ANNOUNCE A NAME, FOUR ANNOUNCE NOTHING.**

    NAMED    history:669 "Filters"   history:702 "Export CSV"
             home:1645 "Dismiss"     medication:170 "Delete"
    UNNAMED  event_wizard:373 back   history:460 clear search
             history:1248 DELETE     log_event:522 back

⚠️ **What an unnamed one announces today is NOT "the icon's name" — it is nothing.** Flutter emits a
node with a tap action and an empty label and tooltip; what a reader then says is the reader's
fallback, not the app's. ⛔ **Which fallback each reader uses is part of what this audit does not
establish.**

**4. ⛔ WHAT THIS DOES NOT ESTABLISH, AND IT IS MOST OF WHAT MATTERS.**

**A static audit of the widget tree is not a screen-reader test.** This measured what the app
*exposes*. TalkBack, VoiceOver and Narrator each apply their own grouping, gesture model, verbosity
setting and fallback naming **on top of** that tree, and they disagree with each other.
⛔ **NONE HAS BEEN RUN. Not once, on any platform.**

**What would close it, per platform:**

| | What it needs | Possible from this machine? |
|---|---|---|
| **Android / TalkBack** | TalkBack enabled on a device, and a pass through every screen | ⚠️ **Partly.** The Teclast tablet is reachable by `adb` and TalkBack can be toggled without touching app data — ⛔ **but that device holds the 72 records, and this pass did not do it** |
| **iOS / VoiceOver** | a Mac, a provisioned device, VoiceOver on | ⛔ **No.** Mac-only work |
| **Windows / Narrator** | the Windows build running, Narrator on | ⚠️ **Yes in principle**, and §13(ap) is the warning: the app exposes nothing a desktop automation tool could navigate by, which is this same absence seen from outside |

⚠️ **AND ONE THING NO READER TEST WOULD CATCH EITHER: whether a name is USEFUL.** *"Dismiss"* and
*"Delete"* are names; neither says **what** is dismissed or deleted. ⛔ **Coverage is not
comprehension, and this finding measured coverage.**
⚠️ **STILL OPEN AFTER THE 9 September FIX — five things, and the fix closed the smallest of them.**
`_SelectionRow` now announces selection state; nothing else on this list changed.

1. ⛔ **THE FIVE UNNAMED CONTROLS, ONE OF THEM DESTRUCTIVE.** `event_wizard:373` back,
   `history:460` clear-search, **`history:1248` the per-row DELETE**, `log_event:522` back,
   `vocabulary:443` selection checkbox. ⭐ **The delete is the one that matters** — it is
   irreversible and §13(ax) records that it leaves no row, no flag and no log. **§8 has carried it
   since 31 August.**

2. ⛔ **THE WALKTHROUGH PAGE DOTS ARE ABSENT, NOT COLOUR-ALONE.** Bare `Container`s with a
   `BoxDecoration` colour, no text and no `Semantics`, so **a non-visual user gets no step
   indicator in either state.** §13(t) files this under colour-alone; it is worse than that.

3. ⛔ **`_SelectionWrap` — feelings and triggers — HAS THE SAME DEFECT `_SelectionRow` JUST HAD.**
   Also a hand-rolled `GestureDetector`, also no semantics, so **which observations are selected is
   still unavailable non-visually.** ⚠️ **Deliberately out of scope this pass and recorded so it is
   not assumed fixed by association.**

4. ⭐ **`semanticLabel` IS USED ZERO TIMES IN `lib/`, AND THAT IS THE STRUCTURAL FACT UNDER ALL OF
   THIS.** Every name in this app is **incidental to something visible** — 97 of 117 controls are
   named by their own text, 9 by a field label, 4 by a tooltip, 1 by a framework default.
   ⛔ **Nothing is named on purpose.** So a control that happens to have no visible text has no name
   by default, which is exactly the shape of the five above.

5. ⚠️ **COVERAGE IS NOT COMPREHENSION.** *"Dismiss"* and *"Delete"* are names that say nothing about
   **what** is dismissed or deleted — and both sit beside per-row content a reader has to hold in
   memory to disambiguate. ⛔ **No audit in this document has assessed whether a name is USEFUL, and
   this fix did not either.**

⛔ **AND THE STANDING LIMIT, UNCHANGED BY THIS FIX: NO SCREEN READER HAS BEEN RUN ON ANY PLATFORM.**
Not TalkBack, not VoiceOver, not Narrator. ⭐ **Everything above — including the fix — is measured
from the widget and semantics trees**, and those three readers apply their own grouping, gesture
model, verbosity and fallback naming on top and disagree with each other. ⚠️ **`Tristate.isTrue` in
the tree is not the same claim as "a user hears 'selected'".**
✅ **ALL FIVE UNNAMED CONTROLS NAMED — 9 September 2026. Nothing visual moved.** Verified in
`test/named_wizard_back_test.dart`, `named_history_controls_test.dart`, `named_form_back_test.dart`
and `vocab_checkbox_semantics_test.dart`.

| control | mechanism | string |
|---|---|---|
| wizard back | `tooltip:` | **`Back`** |
| history clear-search | `tooltip:` | **`Clear search`** |
| **history per-row delete** | `tooltip:` | **`Delete this event`** |
| form back | `tooltip:` | **`Back`** |
| "Your lists" checkbox | ⚠️ **`semanticLabel:`** — `Checkbox` has no `tooltip`, and this is the **first use of `semanticLabel` in the codebase** | **`Select ${e.display}`** |

**BEFORE / AFTER, and the control is the same run against unpatched `lib/`:**

    UNPATCHED   0 of 4 announced        "Select …" names: 0
    PATCHED     4 of 4 announced        "Select …" names: 69, all distinct

⭐ **`tooltip:` in `lib/` went 4 → 8; `semanticLabel:` went 0 → 1.**

**BOTH BACK CONTROLS ARE "Back", AND THAT WAS DECIDED FROM THE CODE.** The wizard's is
`_step == 0 ? _onWillPop() : _step--` — it steps backwards, or at step 0 leaves. The form's is
`_cancel`, which since §13(a)'s fix **prompts when dirty and leaves silently when clean.**
⛔ **So "Cancel" and "Discard" would both be false of both.** `Back` is true of every state and is
the word `MaterialLocalizations` gives `BackButton`. ⭐ **Same string on both paths, which is the
point after §10 decision 1.**

---

**(a) ⛔ THE TOOLTIP-VISIBILITY CONSTRAINT — A GENERAL PROPERTY OF THIS APP, NOT A ONE-OFF.**

**A tooltip is VISIBLE on hover and on long-press.** So a tooltip is not a private channel to a
screen reader: **whatever it says becomes displayable.**

⛔ **THAT RULED OUT `'Delete ${time}'`.** A dynamic tooltip on a record control would surface
**health data into a newly-visible element** — in an app whose whole property is that nothing leaves
the device unless the user sends it (§13(ar) constraint 2, §12). ⭐ **The name of a control is
allowed to describe the ACTION; it is not automatically allowed to describe the RECORD.**

⚠️ **This will come up every time a per-row control needs naming, and there are more of them
coming** — History's rows already carry one destructive control each (§13(ab)) and a second record
kind is designed for (§13(l)). **Where a per-item name needs the item's identity, `semanticLabel`
is the channel and `tooltip` is not.**

---

**(b) ⚠️ THE ASYMMETRY, RECORDED EXPLICITLY BECAUSE TWO DYNAMIC-STRING DECISIONS WENT OPPOSITE WAYS
ON ONE DAY.** Without this a future reader reads it as inconsistency.

| | per-row DELETE — dynamic REJECTED | "Your lists" CHECKBOX — dynamic ACCEPTED |
|---|---|---|
| **is the channel visible?** | ⛔ **yes** — `tooltip` shows on hover and long-press | ✅ **no** — `semanticLabel` is never displayed |
| **what would the content be?** | ⛔ **record data** — a timestamp from a medical record | ✅ **a vocabulary label** the user already sees on the row |
| **would it disambiguate?** | ⛔ **no** — §13(ad): seven byte-identical rows | ✅ **yes** — every entry differs |

⭐ **All three factors point the same way within each column and the opposite way between them.**
**The decision is not a preference; it falls out of three readings.**

---

**(c) ⚠️ THE RENDER TEST'S BOUNDARY, STATED BECAUSE THE PASSING TEST DOES NOT CLAIM WHAT IT LOOKS
LIKE IT CLAIMS.**

The baselines are rects captured from UNPATCHED code, so each test passes in **both** states — the
shape that has now caught a real difference three times. ⛔ **But it measures the STATIC render
only.** Adding a `tooltip` to a control that had none **adds a hover and long-press label that did
not exist before.** ⭐ **So this change is not literally zero visible change, and the green test is
not evidence that it is.**

⭐ **RECORDED AS THE TWO-PROPERTIES PATTERN OF §13(aj) APPLIED BEFORE A FAILURE RATHER THAN AFTER
ONE.** That entry's lesson is that proving one property of an instrument reads as clearing the
instrument. Here the property proven is *static geometry is unchanged*; the property NOT proven is
*nothing newly visible exists*. **Both were needed and only one was tested — said in advance this
time, instead of being discovered by a retraction.**

---

**⛔ STILL OPEN, AND 117 OF 117 MUST NOT BURY ANY OF IT.**

⚠️ **First, the coverage figure itself, honestly.** The re-run sweep reports **117 constructions,
113 named, 4 unnamed** — and **all four are the FALSE POSITIVES this finding already documented**:
`event_wizard:782` and `log_event:121` are `TextField`s whose `labelText: prompt` is a **variable**
rather than a literal; `help_screen:852` is an `InkWell` wrapping a `Row` that contains text; and
`home_screen:942`'s `PopupMenuButton` takes `showMenuTooltip` from the framework. ⭐ **Adjudicated,
it is 117 of 117 and zero destructive unnamed.** ⛔ **The sweep was NOT adjusted to print 117** —
that would be fitting the instrument to the expected answer, and the denominator is only as good as
its stated method.

1. ⭐ **`semanticLabel` is now used ONCE, not zero — and that changes almost nothing.** 97 of 117
   names are still the control's own visible text, 8 are tooltips, 7 are field labels, 1 is a
   framework default. ⛔ **Every name in this app except one remains INCIDENTAL to something
   visible.** A control that happens to have no visible text still has no name by default, and that
   is the structural fact the five gaps came from.
2. ⛔ **COVERAGE IS NOT COMPREHENSION.** *"Back"* does not say back from what. *"Delete this
   event"* does not say which. **117 of 117 is a count of names, not of names that help.**
3. ⛔ **WHICH-RECORD IDENTIFICATION ON THE DELETE CONTROL IS UNSOLVED.** Measured: the row's own
   content **is** the semantics node immediately BEFORE the button in traversal order, so forward
   navigation supplies context. ⚠️ **But control-only navigation — TalkBack's next-control gesture,
   VoiceOver's rotor set to buttons — skips the row entirely**, leaving *"Delete this event, Delete
   this event, Delete this event"*. ⭐ **Adjacency is true and insufficient**, and §13(ad)'s seven
   byte-identical rows mean the adjacent node would not settle it either.
4. ⛔ **THE WALKTHROUGH PAGE DOTS: ABSENT, NOT COLOUR-ALONE.** Bare `Container`s with a
   `BoxDecoration` colour, no text, no `Semantics`. **Untouched by this pass.**
5. ⛔ **NO SCREEN READER HAS BEEN RUN ON ANY PLATFORM.** ⭐ **`Tristate.isTrue` in a tree is not a
   user hearing "selected", and a `tooltip` string in a tree is not a user hearing it either.**
   TalkBack, VoiceOver and Narrator each apply their own grouping, verbosity and fallback naming and
   disagree with each other.
6. ⛔ **§13(ab)'s DESIGN QUESTION REMAINS OPEN: does a destructive control belong on every row at
   all?** ⚠️ **Naming it does not answer that — it makes an unlabelled hazard a labelled one.**

⭐ **AND ONE HARNESS FINDING THIS PASS PRODUCED, RECORDED BECAUSE IT COST TWO FALSE NEGATIVES.**
Pumping several screens inside ONE `testWidgets` under-reports: "Your lists"' 69 checkboxes rendered
as **zero** as the fourth pump and 69 alone; the form's `tooltip: 'Back'` reported **SILENT** as the
third pump and `[Back]` alone — while the wizard's identical tooltip on the FIRST pump was found.
⚠️ **The cause was not established. The DIRECTION was: a later pump under-reports, so a SILENT
verdict from a multi-screen test cannot be trusted while an ANNOUNCED one can.** ⛔ **Same
asymmetry as the prefs-per-process rule, and the same remedy — one screen per file.** Recorded in
`test/semantics_names.dart` where the next author will meet it.

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

⛔ **CORRECTED 8 September 2026 (evening) — THE RECONCILIATION ABOVE RUNS IN THE WRONG DIRECTION,
and it appears in three places in this document.** [The sentence it corrects reads that the bases
differ because *"§7 measured a device capture including a status bar"* while these are *"widget
tests without one"*. **It stays readable above; it does not explain the gap.**]

⚠️ **A status bar makes the void above the content LARGER in frame coordinates, never smaller** —
it pushes everything down. §7's figures are **smaller** than the widget tests', so a status bar is
the wrong sign. **And every non-empty occupancy state in §13(e) raises `btnTop` further**, so no
occupancy explains it either. ⛔ **The bases are not incommensurable. §7's numbers are simply out
by 57 to 105 px, and §7 now records that** — an explanation was offered where a measurement was
available.

⭐ **THE LESSON IS ABOUT THE EXPLANATION, NOT THE NUMBERS: a plausible reconciliation closed a
question that a re-run of an existing test would have settled.** Both widget tests already existed
when that sentence was written. **Where two figures for the same quantity disagree, re-measure
before reconciling** — a reconciliation that is never checked is indistinguishable from one that
is right, and this one survived three separate writings.

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

✅ **FIXED 8 September 2026 — BOUNDED, NOT REMOVED. The finding above stands as written.**

**The flash stays.** It is deliberate feedback on the one-tap capture path. What changed is that a
flash ONSET may now begin no sooner than **500 ms** after the previous onset. **The 200 ms hold is
unchanged, the colours are unchanged, and the appearance of a single flash is unchanged.**

**BEFORE and AFTER, onsets per second, swept over every tap interval from 10 to 1000 ms:**

| Tap interval | BEFORE | AFTER | over 3/sec before | over 3/sec after |
|---|---|---|---|---|
| 150 ms | 1 | 1 | no | no |
| **250 ms** | **4** | **2** | ⛔ **YES** | no |
| **300 ms** | **4** | **2** | ⛔ **YES** | no |
| 400 ms | 3 | 2 | no | no |
| 600 ms | 2 | 2 | no | no |
| **worst case, any interval** | **5 onsets/sec at 240 ms** | **2 onsets/sec** | ⛔ **OVER** | **compliant** |

⭐ **THE AFTER FIGURE IS THE POINT: no tap interval reaches four onsets in a second any more.**

⛔ **500 ms, NOT the 334 ms that merely satisfies the criterion — and this is recorded as a MARGIN
DECISION, not a correctness one, because a mutation at 334 ms passes every test.** One millisecond
from failing is not a margin in an epilepsy app.

**WHAT SETTLED IT, AND WHAT WAS NOT NEEDED.** ⭐ **Flutter's own `kDoubleTapTimeout` is 300 ms** —
read from `flutter/packages/flutter/lib/src/gestures/constants.dart`, where its own comment says
it is *"the maximum time from the start of the first tap to the start of the second tap in a
double-tap gesture."* **300 ms falls inside the original 200-333 ms band.** So the interval the
framework itself treats as one deliberate double-tap was an interval that produced four onsets per
second.

⛔ **That is why the CSV export of the 72 records' millisecond timestamps was NOT needed.** The
export was identified as the way to measure how fast this user actually taps. **The platform's own
model of a double-tap lands in the band regardless of what any one user does**, so the question
stopped being empirical. ⭐ **A measurement that would have settled it was available and was made
unnecessary by a cheaper one that settled it more generally.**

⚠️ **THE POLARITY FINDING, AND IT IS THE REASON THIS SURVIVED VISUAL TESTING.** The button is
**mostly WHITE with brief dark notches**, not mostly-orange with bright pulses. At 250 ms it was
white for 200 ms and alert for 50 — three frames at 60 Hz:

    BEFORE  250 ms  4 taps  4 onsets/sec  ⛔ OVER 3/sec
            WWWWWWWWWWWWWWWWWWWWaaaaaWWWWWWWWWWWWWWWWWWWWaaaaaWWWWWWWWWWWWWWWWWWWWaaaaaWWWWWWWWWWWWWWWWWWWWaaaaa
     AFTER  250 ms  4 taps  2 onsets/sec  compliant
            WWWWWWWWWWWWWWWWWWWWaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaWWWWWWWWWWWWWWWWWWWWaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

⛔ **ANYONE TESTING THIS BY EYE WOULD LIKELY HAVE SAID IT DOES NOT STROBE.** A mostly-white button
with a 50 ms interruption does not look like a flashing orange button, which is what "flash" primes
a tester to look for. ⭐ **The luminance test caught what the visual impression would not — the same
shape as the storage-fallback banner, whose copy and layout were confirmed on a device render while
its contrast sat at 3.46:1 against a 4.5:1 requirement (§13(s)).** **Looking at it is not measuring
it, in both directions: it can pass what should fail, and it can seem to pass what does fail.**

⭐ **AND THE THIRD CASE WAS FORCED BY THE MECHANISM RATHER THAN CHOSEN.** The question of what a
suppressed tap should do — extend the current white, or be ignored — has only one available answer:

| Tap arrives | State | What happens |
|---|---|---|
| within 200 ms of an onset | button is **WHITE** | **EXTENDS** the white. No new onset. These taps were always safe — they hold the fill on rather than strobe |
| 200-500 ms after an onset | button is **ALERT** | **IGNORED for display.** ⛔ There is no active flash to extend, so "extend" is not an available option |
| 500 ms or more after an onset | either | a new **ONSET**, and the cooldown restarts |

**An extension deliberately does NOT push the cooldown forward**, or a sustained run of fast taps
would defer the next onset indefinitely.

⛔ **THE RECORD IS NEVER GATED, AND THAT IS TESTED SEPARATELY BECAUSE IT OUTRANKS THE FIX.** Every
tap creates a record at every interval. **Measured at 150 ms: 7 taps, 7 records, 1 onset.** At
250 ms: **4 taps, 4 records, 2 onsets** — so onsets really were suppressed there, which is what
stops that check passing vacuously. ⭐ **And the mutation that reverts the gate leaves both record
counts unchanged**, proving the two paths are independent in both directions.

**VERIFIED, mutation-proven** — `test/flash_rate_bound_test.dart`,
`test/flash_records_never_gated_test.dart`, `test/flash_records_never_gated_250_test.dart`.
Reverting the gate fails exactly tests 1, 2 and 5b and returns 250 ms and 300 ms to four onsets.
⭐ **The onset counter samples the button's ACTUAL PAINTED FILL frame by frame and counts
alert-to-white edges** — it does not read the private flag and does not trust the timer.

⚠️ **THREE TEST FILES FOR SIX TESTS, and the reason is the rule in `CLAUDE.md`.** The two tests
that read the app's own "Total saved" figure depend on `SharedPreferences` state, and
`setMockInitialValues` does not take effect once an instance exists earlier in the same file. **Run
alongside the rate tests they returned -1 for the count; run together as a pair, the second still
returned -1.** ⛔ **The rule is not "one file per concern" — it is ONE PREFS STATE PER PROCESS, and
a file with two prefs-dependent tests already breaks it.**


➕ **CLOSED 8 September 2026 (evening) — THE "UNMEASURED" QUESTION ABOVE IS MOOT, AND THIS IS
ATTRIBUTED READING RATHER THAN MEASUREMENT.**

⚠️ **The sentence it closes reads *"WHETHER A USER REACHES THAT BAND IS UNMEASURED AND IS NOT
GUESSED HERE"*, and it stays readable above.** It was written before the fix and was correct when
written.

⛔ **The fix caps flash ONSETS at 2 per second at every tap interval from 10 to 1000 ms** — the
sweep above shows 2 at 250 ms, 2 at 300 ms, 2 at 400 ms, and **2 in the worst case at any
interval**, against a threshold of more than three. ⭐ **So the 200-333 ms exposed band is
unreachable regardless of how fast anyone taps.** The question *"does a user reach 3 to 5 taps per
second"* no longer has a consequence attached to it: **both answers now give the same compliant
result.**

⭐ **AND THAT IS WHY THE CSV EXPORT OF THE 72 RECORDS' MILLISECOND TIMESTAMPS WAS NEVER NEEDED.**
The export would have answered *"has a real user ever tapped into the band"* — a question whose
answer stopped mattering the moment the band became unreachable. **A measurement made unnecessary
by a fix, rather than one skipped.**

⚠️ **ATTRIBUTION, STATED BECAUSE THIS DOCUMENT'S RULE REQUIRES IT: this closure is a READING, taken
by chat, from figures the CLI measured.** ⛔ **No new measurement was taken, and the CLI declined to
close it on the ground that the document does not say so.** ⭐ **That refusal was right and this
closure is not a correction of it** — the two are different acts. The CLI reported what the
artefact states; the reading draws a conclusion the artefact supports but does not state, and it is
recorded here as such so a later reader can reject the inference while keeping the sweep.

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

---

### (aj) 🔴 THE CAPTURE INSTRUMENT PRODUCED A FALSE FINDING WITH CORROBORATION

**8 September 2026.** ⛔ **This is a finding about the audit's own instrument, not about the app,
and it is the most serious of those recorded so far** — because unlike a declared scope or a
mis-framed search, **this one produced a specific, plausible, corroborated defect that does not
exist.**

**WHAT ALMOST SHIPPED:** that the walkthrough has **no navigation controls on Windows** — no
`Next`, no `Skip`, no page indicators — so **a first-run Windows user cannot get past step 1 of 5**,
and since `walkthroughSeenVersion` is written only by the walkthrough's own completion handler,
**the app is unusable on a fresh Windows profile.**

⭐ **IT WAS CORROBORATED FOUR WAYS, AND EVERY ONE OF THEM AGREED:**

| Corroboration | What it said |
|---|---|
| A row-scan of the frame | **no non-background pixel anywhere below y=400** |
| The same scan at a LARGER window | still nothing but a 3-pixel edge artefact |
| A pixel-sampling probe | app-bar navy at the top, scaffold grey below — *"consistent with MER"* |
| **A causal story that fit** | there is **no Windows app data on this machine** — the MSIX install from 25 Aug has 2 files and no database, **exactly what a first run that never completed looks like** |

⛔ **ALL OF IT WAS WRONG, AND FROM TWO SEPARATE FAULTS IN ONE INSTRUMENT:**

**Fault 1 — a FALSE NEGATIVE.** The window had been sized to 882 px tall against an 816 px working
area (`GetWindowRect` reported `T=-14`), so the client area's bottom sat at screen y=861 —
**below the visible desktop.** `Graphics.CopyFromScreen` photographed the desktop there. **The
navigation was rendering the whole time, off-screen.**

**Fault 2 — a FALSE POSITIVE, minutes later.** `SetForegroundWindow` **failed silently**, so the
next capture was **the user's Gmail inbox**. The row-scan then reported *"76 rows of real content
below y=400"* — a number that looked exactly like the refutation of Fault 1. ⛔ **Had that frame
not been read, the sequence would have run: defect found, defect confirmed, defect disproved, all
three from photographs of things that were not the app.**

⭐ **THE SAME INSTRUMENT GAVE A FALSE NEGATIVE AND A FALSE POSITIVE WITHIN MINUTES, ON THE SAME
QUESTION.** Not a biased instrument — an unreliable one, wrong in whichever direction the desktop
happened to be arranged.

⛔ **WHAT CAUGHT IT WAS READING THE FRAME. NO CHECK CAUGHT IT.** The row-scan confirmed the false
finding twice, with counts that looked like data. The pixel probe agreed. **Both were measuring
faithfully; they were measuring the wrong pixels.**

⚠️ **THE TRANSFERABLE RULE, AND IT IS THE SAME SHAPE AS §13(v)'s TAXONOMY FAILURE.** `CopyFromScreen`
does not measure a window. **It measures the screen region where a window is** — a PROXY, standing
in for the thing, and identical to it only while nothing is on top and nothing is off-screen.
⭐ **An instrument that measures a proxy fails in ways its own controls cannot detect, because the
controls run on the proxy too.** (v) enumerated animation constructs when the criterion was
luminance over time; this photographed screen regions when the subject was a window. **Both had
working controls pointed at the wrong thing.**

✅ **RESOLVED THE SAME DAY, AND THE REPLACEMENT WAS PROVEN BEFORE ANY CAPTURE WAS KEPT.**
`PrintWindow` with `PW_RENDERFULLCONTENT`, into a **window-rect** bitmap, then **cropped to the
client rect**:

| Proof | Result |
|---|---|
| Two consecutive captures of an unchanged window | **byte-identical md5** — `6C9ADEE5…` |
| **The same window FULLY OCCLUDED by a topmost form covering the whole screen** | **BYTE-IDENTICAL md5 to the unoccluded capture** |
| Captured while MER was **not frontmost** | succeeded; `GetForegroundWindow` confirmed it was not |

⚠️ **Three method faults were found and fixed getting there, each recorded because each would have
corrupted captures silently:** `PrintWindow` renders the **whole window** at 0,0, so a
client-sized bitmap clips the bottom-right and includes the title bar; the **title bar repaints on
focus change**, so window-rect captures of an unchanged window differ — cropping to the client area
removes it and restores determinism; and in the PowerShell helper **`$h = Get-MerWindow` silently
overwrote the `$H` height parameter, because PowerShell variables are case-insensitive**, producing
`requested_logical=1012x62852502` and a resize to an unintended size.

⛔ **AND THE FRAME CHECK VERIFIES IDENTITY, NOT COMPLETENESS. THE TWO ARE DIFFERENT GUARANTEES AND
NEITHER SUBSTITUTES FOR THE OTHER.** A four-property check — a ≥30-row contiguous `#0D4F82`
app-bar band, `#F5F8FB` dominating the body, fewer than 900 distinct colours in a sample, and all
three theme colours present — was **demonstrated failing** before being trusted:

| Frame | check |
|---|---|
| real MER | **pass** — 64 app-bar rows, bgFrac 0.631, 88 distinct |
| **the Gmail frame that fooled the old probe** | ⛔ **FAIL** — 0 app-bar rows, bgFrac 0, **1317 distinct colours** |
| a magenta form filling the screen | ⛔ **FAIL** |
| a desktop-only region | ⛔ **FAIL** |
| **the two mis-sized MER frames** | ⚠️ **PASS — and correctly, because they WERE MER, merely clipped** |

⭐ **So this check would NOT have caught Fault 1.** Completeness is guaranteed by the METHOD
instead — `PrintWindow` plus a `GetClientRect` crop is structurally independent of screen position,
which is what the occlusion proof establishes. ⛔ **The old check — "app-bar navy at the top and
grey below" — passed on Gmail, and is retired.**

➕ **A FOURTH INSTRUMENT FAILURE, 8 September 2026 (evening) — AND IT IS THE SHARPEST, BECAUSE IT
HAPPENED AFTER THIS FINDING WAS WRITTEN.**

**The sequence, in one session:**

| | |
|---|---|
| **1** | The capture instrument produced a **false negative** — the walkthrough's missing navigation |
| **2** | The same instrument produced a **false positive** minutes later — the Gmail frame |
| **3** | **THIS FINDING WAS WRITTEN**, naming the cause: an instrument that measures a PROXY fails in ways its own controls cannot detect |
| **4** | The replacement instrument was proven occlusion-independent, and then produced a **third false finding** — §13(al)'s DPI offset — which was **committed as 🔴 with a "SETTLED" claim** |

⛔ **THE DOCUMENT, THE AUTHOR, AND THE REPEAT, ALL IN ONE SESSION.** §13(r) records that documenting
a failure mode does not inoculate against it. **This is that at its sharpest: the rule was written
here, four hours before being walked into.**

⚠️ **AND THE MECHANISM OF THE REPEAT IS WORTH NAMING PRECISELY, BECAUSE IT IS NOT THE SAME AS
INSTANCES 1 AND 2.** Those were an instrument measuring the wrong pixels. **This one was a reading
of a frame treated as INDEPENDENT CONFIRMATION of a measurement that came through the same
pipeline.** The offset was called *"visible to the eye"* and *"unmistakable"*, and the clipping in
two frames was said to have *"tipped"* the verdict.

⛔ **NONE OF THAT WAS INDEPENDENT. Reading a frame and measuring a frame are the same evidence when
the frame is the thing at fault.** An eye applied to a corrupted image confirms the corruption with
complete sincerity — which is exactly what instances 1 and 2 already demonstrated, and exactly what
was forgotten.

⭐ **THE COUNTERWEIGHT, AND IT IS REAL: reading the frame is what CAUGHT instances 1 and 2.** So the
lesson is not "do not read frames". **It is that reading a frame tests whether the frame shows what
you think it shows — the SUBJECT — and cannot test whether the frame's GEOMETRY is faithful.** The
Gmail frame was caught because the subject was visibly wrong; a correctly-subjected frame with
wrong geometry looks exactly right. ⛔ **Subject and geometry are two properties, and the eye only
checks one.**

⭐ **THE PATTERN UNDERNEATH ALL FOUR, ADDED 8 September 2026 (evening): AN INSTRUMENT HAS SEVERAL
PROPERTIES, AND PROVING ONE READS AS PROVING THE INSTRUMENT.**

**Recorded HERE rather than in §13(r), and the reason matters.** §13(r) is about correct knowledge
that existed, was written down, and did not travel. **This is not that** — it is a property of
instruments and belongs with the instrument record. ⚠️ **There IS an §13(r) instance inside it,
named below, but the pattern itself is not one.**

⛔ **`PrintWindow` was proven OCCLUSION-INDEPENDENT and then trusted for GEOMETRY.** The proof was
real: byte-identical md5 under a full-screen topmost window, which is a genuine result about a
genuine property. ⛔ **It says nothing whatever about scale.** Two properties were needed —
occlusion-independence and geometry-fidelity — **exactly one was tested, and the tested one was
reported as though the instrument had been cleared.**

**The same shape, three times over, at three different levels:**

| Level | Property proven | Property assumed | Cost |
|---|---|---|---|
| **The eye** | the frame's **SUBJECT** is right | the frame's **GEOMETRY** is right | §13(al), committed as 🔴 |
| **The instrument** | **occlusion**-independent | **scale**-faithful | §13(al), and (an)/(ao)'s withdrawn figures |
| **The check** | `bgFrac`, `palette`, `bar`, `rows` all passed | the frame therefore measures truly | two narrow captures failed a check that was measuring the wrong thing — §13(aq) |

⭐ **AND THE TELL IS ALWAYS THE SAME: the passing result is TRUE.** Nothing in any of those three
rows is a false measurement of the property it measured. **The falsehood enters in the WIDTH of the
conclusion drawn**, which is why no amount of re-running the check catches it. ⛔ **A clean result
over an unstated set of properties is indistinguishable from a clean result over all of them.**

**PRACTICAL FORM: before trusting an instrument, ENUMERATE the properties the claim depends on,
and mark each one tested or assumed.** For a capture that is at least: subject, occlusion, scale,
crop, colour fidelity, and timing. ⭐ **Name the assumed ones in the finding.** The INDEX.md
annotation now does exactly this — *"occlusion-independent and NOT geometry-faithful at scaled
DPI; both properties were needed and only one was tested"* — and that sentence is the whole lesson.

⚠️ **THE §13(r) INSTANCE, AND IT IS A CLEAN ONE.** `C:\dev\CLAUDE.md` already carries this rule in
general form, written weeks earlier: **DERIVED SCOPE IS NOT THE SAME AS COMPLETE COVERAGE**, with
the instruction to *"state what a check's denominator IS, and never let 'derived' be read as
'total'"*. ⛔ **A capture-proof's denominator is its PROPERTIES, and it was never stated.** The
knowledge existed, in a file that loads every session, phrased generally enough to cover this
exactly — **and it did not travel from a rule about audit scripts to a rule about a screenshot.**
⭐ **That is §13(r)'s pattern precisely: the lesson was not missing, it was not where it would be
read.**

### (ak) THE APP REQUESTS A WINDOW LARGER THAN A COMMON LAPTOP DISPLAY CAN SHOW

**Code-verified and measured, 8 September 2026.** `windows/runner/main.cpp`:

```cpp
Win32Window::Size size(1280, 720);
```

⚠️ **That is LOGICAL**, and `win32_window.cpp:134-135` scales it by `dpi / 96.0` before
`CreateWindow`. On this machine:

| | |
|---|---|
| Monitor DPI | **120**, so scale **1.25** |
| Requested window | 1280x720 logical = **1600x900 PHYSICAL** |
| Physical display | **1536x864** — working area **1536x816** |
| ⛔ **Fits?** | **No, in either dimension** |
| What the OS granted | **1280x720 physical = 1012x546 LOGICAL** |

⭐ **So the app opens 21% narrower and 24% shorter, in logical terms, than its own source asks
for** — and nothing in the app knows, because there are no width or height breakpoints anywhere
(§13(aa): `MediaQuery...size.width` 0 hits, width-threshold branching 0 hits).

⚠️ **1280x720 logical is not an unreasonable request** — it is a common default. **What makes it
unreachable here is DPI scaling**, which is the ordinary configuration on a laptop, not an exotic
one. ⭐ **A 1536x864 panel at 125% is a mainstream Windows laptop**, and on it this app can never
open at the size it requests.

✅ **AND THE CLAMP IS GRACEFUL — measured, not assumed, and this is the part §13(aj) nearly got
wrong.** At the granted 1012x546 logical, and at the machine's maximum 1216x622, the walkthrough's
`Next`, `Skip` and page indicators are all **present in the tree and fully inside the window**,
with **zero elements overflowing** — verified in
`test/windows_walkthrough_layout_test.dart` under `TargetPlatform.windows`.

⭐ **The control is what makes that mean something: the SAME test under `TargetPlatform.android` at
the SAME two sizes agrees exactly.** So the clamp is not a Windows problem, and §13(aj)'s
walkthrough concern is **WITHDRAWN in full**. The only platform difference measured is the button's
own height — `nextTop` 494 on Windows against 478 on Android, both ending at 526 — which is
`shrinkWrap` giving a **32 px** control where `padded` gives **48 px**, exactly as §13(y) predicts.

⚠️ **UNMEASURED, AND NOT GUESSED: what happens at a genuinely wide desktop size.** The maximum
logical client this display allows is about **1216x622**, so **1920-wide cannot be captured or
measured on this machine at all.** §13(aa)'s 3.6x width split was measured in a widget test at
1920 rather than on a real window, and that distinction is deliberate.


➕ **THE RUNNER-TEMPLATE CONTROL, PRESERVED 9 September 2026 BEFORE D2 SPENDS IT.**

⛔ **§13(al)'s retraction rests in part on `windows/runner/` matching the SDK template, and D2
(§13(au)) adds a `WM_GETMINMAXINFO` case to `Win32Window::MessageHandler`, which ends that property
permanently.** ⭐ **Once it lands, a future reader CANNOT re-derive this** — the template it matched
is the SDK's, the SDK moves, and a diff against a later template would report differences that were
never MER's. **So it is recorded as a dated fact, with hashes, now.**

**Template:** `C:\Flutter\flutter\packages\flutter_tools\templates\app\windows.tmpl\runner`,
**Flutter 3.41.3 stable**, framework revision `48c32af034`, **engine hash
`14e407f99287c74c73a9a055680e7c9341773f6e`**, Dart 3.11.1.

**EIGHT FILES BYTE-IDENTICAL, sha256:**

| File | sha256 |
|---|---|
| `flutter_window.cpp` | `d615eedc06ae37321e59c2c00c7687d1887dcd97904eb7225fafd8dcb5b83da6` |
| `flutter_window.h` | `0252b804f5da380c7709cbe1daff2b8d18daf6c49d7e6dd43e5af3c99c19f56c` |
| `win32_window.cpp` | `4e4f4dcf8e86ea6e097562cb3476039e693449bd8045367538afee579c017511` |
| `win32_window.h` | `d154cf89ba85f820631a9b5bedacbe64fc5815e428fe6bc5da579ce649f69841` |
| `utils.cpp` | `fbb18524c22593d0ce7869b0733e237be38e668fe045e3023bcf2d0b31784fa3` |
| `utils.h` | `832e246b6758253f89016fb0374b30791242e97ad950d27fc678b3d9feacfdc4` |
| `resource.h` | `d0e8bf7835468b4b6b1f8f0747f2e8f25c19841f2df2ac60aaa584ddae3aa7c6` |
| `runner.exe.manifest` | `639a56233fcd8cbcb8bbefcd93e4680ec2664f32d9acfb3d2ec1d8726a96e090` |

⭐ **AND THE ONE NUMBER TO CHECK IT WITH: those eight concatenated in that order hash to
`fd318f1e407f73ba5258edbaaa2d9c181677eeffb43bd99e4642e13f70aff754`, repo and template alike.**
A single figure is harder to half-verify than eight.

✅ **`Win32Window::MessageHandler`'s cases are identical, repo and template — `WM_DESTROY`,
`WM_DPICHANGED`, `WM_SIZE`, `WM_ACTIVATE`, `WM_DWMCOLORIZATIONCOLORCHANGED`. FIVE. D2's
`WM_GETMINMAXINFO` would be the SIXTH and the first behavioural divergence MER has ever made in the
embedder.**

⚠️ **AND THE CLAIM IN §13(al) IS OVERSTATED IN ITS HEADLINE AND UNDERSTATED IN ITS SUBSTANCE.
BOTH ARE CORRECTED HERE, NOT THERE.**

**Overstated:** that row says *"`windows/runner/` — BYTE-IDENTICAL to the SDK template"* and *"MER
has not touched the embedder"*. ⛔ **Three files in the directory DO differ** — `CMakeLists.txt`,
`main.cpp` and `Runner.rc` — plus `resources/app_icon.ico`, which is the branded icon against the
template's `app_icon.ico.img.tmpl`. **Read as a whole-directory claim it is false.**

**Understated:** the row *enumerates* six files, and **every file it names is byte-identical**, so
the claim as scoped is TRUE. ⭐ **And the three differences are project-identity substitution and
nothing else, which is a STRONGER result than the enumeration:**

    CMakeLists.txt   project(runner)  ->  project(MedicalEventRecorder)          1 line
    main.cpp         L"{{projectName}}"  ->  L"Medical Event Recorder"            1 line
    Runner.rc        {{organization}} / {{projectName}} / {{year}} substituted    6 lines

⛔ **ZERO BEHAVIOURAL DELTA. Every difference is a name.** So "MER has not touched the embedder" is
correct in substance across the whole directory, which the enumeration could not establish.

⚠️ **One count in that row is simply wrong: it says *"both headers"*. There are FOUR** —
`flutter_window.h`, `win32_window.h`, `utils.h`, `resource.h` — **and all four are identical**, so
the error undercounts its own evidence. ⭐ **This is the declared-scope class again: a list that
happens to be right, beside a headline that generalises past it, and a count that matches neither.**

⛔ **AND A FACT FOR THIS FINDING ITSELF, WHICH IS WHY THE CONTROL LANDED HERE RATHER THAN IN
§13(al): `Win32Window::Size size(1280, 720)` IS THE TEMPLATE'S OWN LINE 29, VERBATIM.** Repo and
`main.cpp.tmpl` agree on it, and `Point origin(10, 10)` too. ⭐ **So this finding is not about a
decision MER made. It is a property of the Flutter Windows template**, which requests 1280x720
logical on every generated app — and on a 1536x864 panel at 125% that cannot be granted. **The
window MER asks for was never chosen; it was inherited.**

---

### (al) 🔴 ON WINDOWS THE LAYOUT IS 1.25x WIDER THAN THE WINDOW — CONTENT IS OFFSET RIGHT AND CLIPPED

⭐ **THE FIRST FINDINGS IN THIS DOCUMENT THAT REST ON REAL WINDOWS CAPTURES.** Not 1x Android
proxies, not widget tests: `PrintWindow(PW_RENDERFULLCONTENT)` into a window-rect bitmap cropped
by `GetClientRect`, the method proven occlusion-independent in §13(aj). **Four frames, each
content-checked, in `captures/`.**

**MEASURED at four window widths, 8 September 2026, at the machine's real 125% scaling:**

| Client | Content | Left margin | Right margin | Centred would be |
|---|---|---|---|---|
| 876 px | 650 | 225 | **2** | 113 |
| 1124 px | 650 | 380 | 94 | 237 |
| 1265 px | 650 | 468 | 147 | 307 |
| 1520 px | 649 | 628 | 243 | 435 |

⛔ **THE CAUSE, AND IT IS ONE CAUSE FOR TWO SYMPTOMS.** The app **lays out at a width equal to the
PHYSICAL pixel count while rendering at the DPI scale factor**, so the layout is **1.25x wider than
the window it is drawn into**. Content centred inside that over-wide layout is pushed right, and
the right-hand portion falls outside the client area entirely. **The offset and the clipping are
the same defect.**

**The model fits every measurement to within 3 px** — content centred as if the viewport's logical
width equalled its physical pixel count:

    876 px  -> predicted 222.5, measured 225      1265 px -> predicted 465.6, measured 468

✅ **SETTLED BY A PREDICTION THAT COULD HAVE FAILED IN A SPECIFIC DIRECTION.** Relaunched
**DPI-unaware** — per-process via `__COMPAT_LAYER=DPIUNAWARE`, so **no system setting was written**
— which makes logical and physical identical. The model predicted the offset would **vanish**:

| At `GetDpiForWindow` = 96 | Content | Left | Right | Centred? |
|---|---|---|---|---|
| client 875 px | 518 | **178** | **179** | ✅ |
| client 1264 px | 519 | **372** | **373** | ✅ |

⭐ **AND THE WIDGET-TEST CONTROL CLOSES IT: the two instruments agree EXACTLY at DPR 1.0 and
disagree only at 1.25.**

| | widget test | real capture |
|---|---|---|
| DPR 1.0, 875 px | 177.5 | **178** ✅ |
| DPR 1.0, 1264 px | 372 | **372** ✅ |
| DPR 1.25, 1265 px | 307.5 px equivalent | **468** ⛔ |
| DPR 1.25, 876 px | 113 px equivalent | **225** ⛔ |

⛔ **So this is a REAL, DPI-DEPENDENT DEFECT, not a capture artefact** — and two further checks rule
the artefact out independently: the offset is **invariant to window position on screen** (468 /
467 / 468 at x=20, 250, 0), and cropped and uncropped captures agree.

⚠️ **THE REACH IS THE SERIOUS PART. 125% is the DEFAULT on most modern Windows laptops** — this
machine is a 1536x864 panel at 125%, an entirely ordinary configuration. **On any Windows display
scaled above 100%, MER's content is offset right and clipped on the right.** The app ships on the
Microsoft Store.

⭐ **WHAT TIPPED THE READING, AND IT IS THE REASON THIS WAS NOT LEFT OPEN: the CLIPPING.** A
compositing artefact shifts a frame; it does not clip content against a boundary **the layout
believes is there**. At 876 px the right margin is **2 px** — content flush against the edge. That
is a layout terminating where it thinks the viewport ends, and the viewport it thinks it has is the
wrong one.

⛔ **RETRACTED 8 September 2026 (evening). THE FINDING ABOVE IS WRONG. Its text and its 🔴 are
left exactly as written, because a record of what was concluded that day must stay true — and
because the reasoning that produced it is the transferable part.**

**THERE IS NO APP DEFECT HERE. The offset is an artefact of the capture instrument.**

**THE DECISIVE MEASUREMENT, which needs neither `PrintWindow` nor a click.** Flutter's Windows
surface is a CHILD window, so its rect can be read directly:

    PARENT   class=FLUTTER_RUNNER_WIN32_WINDOW  clientRect=1265x682  dpi=120
    AT-PT    class=FLUTTERVIEW                  clientRect=1265x682  parent=46665734  dpi=120

⭐ **The `FLUTTERVIEW` child's client rect EQUALS the parent's — 1265x682, not the 1581 the model
required.** So the embedder passes the correct physical size, Flutter's logical width is
1265 / 1.25 = **1012**, and **the widget test at exactly those metrics reports 246 / 246 — centred.**

**THREE LAYERS RULED OUT, each with evidence:**

| Candidate | Verdict |
|---|---|
| `windows/runner/` | ⛔ **BYTE-IDENTICAL to the SDK template.** `flutter_window.cpp`, `win32_window.cpp`, `utils.cpp`, both headers and `runner.exe.manifest` all diff clean against `flutter_tools/templates/app/windows.tmpl/runner`. **MER has not touched the embedder.** The manifest declares `PerMonitorV2`, so the app is correctly DPI-aware |
| the engine / embedder | ⛔ **RULED OUT by the `FLUTTERVIEW` rect above** |
| Dart-side layout | ⛔ **RULED OUT** — the widget test at DPR 1.25 / 1265x682 centres exactly |
| Flutter version | **Not implicated.** Recorded because the finding cites it: Flutter **3.41.3** stable, engine `14e407f9`, Dart 3.11.1 |

⚠️ **THE `windows/runner/` ROW ABOVE IS PRESERVED WITH HASHES IN §13(ak), 9 September 2026, BECAUSE §13(au)'s decision D2 ENDS THAT PROPERTY.** ⛔ **It is also corrected there** — read as a whole-directory claim it is false (three files differ, all by project-identity substitution only), *"both headers"* undercounts four, and the claim as ENUMERATED is true. ⭐ **The eight identical files concatenate to sha256 `fd318f1e407f73ba5258edbaaa2d9c181677eeffb43bd99e4642e13f70aff754`, repo and Flutter 3.41.3 template alike.**

⛔ **SO IT IS THE CAPTURE. THIRD FALSE FINDING FROM THAT PIPELINE**, after the off-screen false
negative and the Gmail false positive in §13(aj).

⚠️ **THE MECHANISM IS INFERRED, NOT VERIFIED, AND IS RECORDED AS AN EXPLANATION RATHER THAN A
MEASUREMENT.** `PW_RENDERFULLCONTENT` appears to composite the DirectComposition / ANGLE
`FLUTTERVIEW` child imperfectly on a DPI-scaled window. **What is MEASURED is that the offset is not
in the app; the internals of `PrintWindow` were not instrumented.**

---

⛔ **WHY THE DPI-96 TEST DID NOT SETTLE IT, AND THIS IS THE PART WORTH KEEPING.**

The retracted finding called itself *"SETTLED BY A PREDICTION THAT COULD HAVE FAILED IN A SPECIFIC
DIRECTION."* **The prediction was falsifiable. It was not DISCRIMINATING.**

| Hypothesis | Prediction at DPI 96 |
|---|---|
| the app lays out wrong at high DPI | offset vanishes |
| **`PrintWindow` mis-scales at high DPI** | **offset vanishes** |

⭐ **Both rivals predict the same result, so the result chose neither.** At DPI 96 there is no
scaling for `PrintWindow` to get wrong, which is precisely why the test looked conclusive and was
not.

> ⛔ **THE RULE: A PREDICTION MUST DISCRIMINATE BETWEEN HYPOTHESES, NOT MERELY BE FALSIFIABLE.**
> Before running a test, ask what the RIVAL hypothesis predicts. **If both predict the same
> outcome, the test cannot settle it** — however cleanly it succeeds, and however specific the
> direction of the prediction sounds.

⚠️ **AND THE TWO EXCLUSIONS CITED WITH IT WERE WEAKER THAN THEY WERE PRESENTED:**

- **"Invariant to window position"** rules out a **translation** error. The artefact is a **scale**
  error. ⛔ **It was never in scope for the thing it was offered against.**
- **"Cropped and uncropped captures agree"** shows only that the crop is **self-consistent** —
  **both go through `PrintWindow`.** A shared upstream fault is invisible to a comparison of two
  things downstream of it.

⭐ **This is the proxy-instrument class from §13(aj) recurring: the controls ran on the proxy, so
they could not see the proxy failing.**

---

### (am) 🔴 CONTENT CLIPS AT NARROW WIDTHS, AND THERE IS NO FLOOR

**Seen directly in real Windows captures, 8 September 2026.**

| Width | What is lost |
|---|---|
| **400 logical** | the stats card's fourth column is **cut mid-word** — the `R` of `Referrals` visible, the rest gone |
| **94 logical** | **`Record Event` breaks as `Recor / d / Event`** — a mid-word break in the PRIMARY ACTION's label — and the stats row is four numbers in unreadable two-letter fragments |

⛔ **MER ENFORCES NO MINIMUM WINDOW SIZE.** `WM_GETMINMAXINFO` and `MinTrackSize`: **0 hits** across
`windows/runner/`; control `Win32Window` = **21 hits**, so the search was live. **The only floor is
the OS's own**, measured by asking for smaller and smaller widths:

    requested 400 -> granted 400.0     requested 150 -> granted 150.4
    requested 300 -> granted 300.8     requested 100 -> granted 100.0
    requested 200 -> granted 199.2     requested  60 -> granted  94.4  (clamped by Windows)

⭐ **94.4 logical is reachable in ONE DRAG**, from a window whose default the OS already clamps
(§13(ak)).

⚠️ **A VIEW, MARKED AS A VIEW: this outranks §13(al)'s offset.** The offset **misplaces readable
content**; this **loses it**. A user who cannot read `Referrals` cannot know what the number means,
and a primary action labelled `Recor d Event` is not a label. ⛔ **AND THE COUNTERWEIGHT: "reachable"
is not "likely".** Nobody drags a window to 94 px on purpose, there is **no usage evidence either
way** (§13(u): no telemetry of any kind), and a user who does it can drag back.

⛔ **THE DESIGN QUESTION, RECORDED AND NOT ANSWERED: prevent, or support.**

| | |
|---|---|
| **Prevent** | a minimum window size in `windows/runner/` makes 400 unreachable. **Small** — one `WM_GETMINMAXINFO` handler |
| **Support** | responsive layout makes narrow widths work. **Not small** — and §13(aa) records that there are no breakpoints anywhere to build on |

**DESIGN-TRACK, and it belongs with the component vocabulary** rather than ahead of it.

⚠️ **CORRECTED 8 September 2026 (evening). The finding above is PARTLY WRONG. Its text is left as
written; what follows separates what survives from what does not.**

⛔ **WRONG — BOTH DESCRIPTIONS WERE READ FROM ARTEFACT FRAMES**, produced by the capture pipeline
retracted in §13(al):

| Claimed | Actual, from the widget test at DPR 1.25 |
|---|---|
| *"at 400 logical the stats card's fourth column is cut mid-word — the `R` of `Referrals` visible, the rest gone"* | ⛔ **FALSE. At 400 logical: content 360 wide, 20 px padding each side, ZERO overflowing texts.** The layout is fine |
| *"at 94 logical `Record Event` breaks as `Recor / d / Event`"* | ⛔ **FALSE for that element.** No overflow of `Record Event` at any width measured |
| *"the stats row is four numbers in unreadable two-letter fragments"* | ⛔ **Not reproduced** |

✅ **REAL, and measured with the reliable instrument:**

    NARROW logical=400  capLeft=20.0 capW=360.0  overflowingTexts=0  exception=true
    NARROW logical=94   capLeft=20.0 capW=54.0   overflowingTexts=2  exception=true
                        Medical Event Reco@66..352 | Record · Review · @66..296

⭐ **At 94 logical there IS genuine overflow — but it is the APP BAR, not the body.** Two texts
extend to x=352 and x=296 in a **94-wide** viewport: the title `Medical Event Recorder` and the
subtitle `Record · Review · Share`. **Nothing in the content column overflows at either width.**

⚠️ **AND SOMETHING REAL THAT THIS FINDING DID NOT NOTICE: both widths raise a framework
exception.** Recorded separately as **§13(as)**, because it is reliably measured and nobody has
examined it.

⭐ **THE DESIGN QUESTION SURVIVES — BUT ITS EVIDENCE HAS SHRUNK, AND THAT CHANGES ITS WEIGHT.** The
prevent-versus-support choice above stands as a question. **What it no longer rests on is a failure
at 400 logical.** The measured failure is at **94** — the OS floor, reachable only by dragging a
window to a sliver — rather than at 400, which is an ordinary narrow window. ⛔ **A defect at 400
would have made "prevent" nearly obvious. A defect only at 94 does not.**

⚠️ **The claims about the RUNNER stand and were re-verified**: `WM_GETMINMAXINFO` and `MinTrackSize`
return **0 hits** across `windows/runner/`, control `Win32Window` **21 hits**; and the granted-width
table down to **94.4 logical** came from `GetClientRect` read-back, **not from any capture.**

---

### (an) THE WIDTH STRATEGY PRODUCES BOTH FAILURES FROM ONE ABSENCE

**8 September 2026.** ⭐ **§13(aa) reaching its conclusion, and it is not restated here** — 3 screens
capped at `maxWidth: 520`, 9 uncapped, **no width breakpoints anywhere**.

⛔ **ONE ABSENCE, TWO OPPOSITE FAILURES.** A wide window **strands** capped content in an empty
field — §13(ac) measured 34.9% void on each side at 800 logical, and the desktop captures show the
same shape at 1216. A narrow window **clips** it — §13(am). **There is no width at which a single
fixed cap is right for both, which is what a breakpoint is for.**

⚠️ **AND THE APP BAR ADVERTISES THE WIDTH THE CONTENT IGNORES.** The `#0D4F82` band spans the full
client width at every size measured — 40 to 69 contiguous rows at widths from 118 px to 1520 px —
while the body sits in a 520-logical column. ⭐ **The chrome tells the user how wide the window is;
the content behaves as though it were on a phone.**

⛔ **SPLIT 8 September 2026 (evening) — THE CONCLUSION IS SOUND AND TWO CORROBORATIONS ARE
WITHDRAWN. Both halves of this finding are here on purpose; they have different instruments.**

✅ **SOUND — the whole argument, and it needs no capture.** *3 screens capped at `maxWidth: 520`,
9 uncapped, no width breakpoints anywhere* is §13(aa), **measured in a widget test**. *A wide
window strands capped content* is §13(ac), **measured in a widget test** — 34.9 % void each side
at 800 logical. *A narrow window clips it* is §13(am) as corrected, **measured in a widget test**
at 94 logical. ⭐ **One absence, two opposite failures, and no breakpoint to resolve them: that
stands entirely on widget tests.**

⛔ **WITHDRAWN — the two claims read off `PrintWindow` frames at DPR 1.25.** *"the desktop captures
show the same shape at 1216"* and *"the `#0D4F82` band spans the full client width at every size
measured — 40 to 69 contiguous rows at widths from 118 px to 1520 px."* **That is the instrument
that produced §13(al)**, and §13(al)'s mechanism is recorded as **inferred, not verified**, so its
unfaithfulness is not established to be horizontal-only. ⚠️ **A row count is a vertical geometric
quantity and a band's extent is a horizontal one. Neither is safe from an unidentified scale
artefact**, and *"spans the full client width"* is exactly the kind of claim a uniform scale error
leaves looking correct.

⭐ **THE APP-BAR OBSERVATION IS NOT LOST, IT IS DEMOTED TO WHAT A CAPTURE CAN CARRY: the chrome
LOOKS as wide as the window while the body LOOKS like a phone column.** ✅ **That is an appearance
reading, it is what the frames are valid for, and it is the rhetorical point of the paragraph.**
⛔ **What is withdrawn is every NUMBER in it.** The `520`-logical column it is contrasted against
is a widget-test figure and survives; the `1216`, the `1520` and the `40 to 69` do not.

⚠️ **NOT RE-MEASURED. Establishing the desktop app bar's height and extent needs a widget test at
`TargetPlatform.windows`, which has not been written** — §13(ak)'s existing desktop test measures
the walkthrough, not the app bar.

---

### (ao) THE TABLET'S VOID READING DOES NOT TRANSFER TO DESKTOP

**8 September 2026.** ⛔ **§13(ac) recorded a reading that the void BELOW home's content may be the
more serious half, from measurements at 430x932 and 800x1280. THAT READING DOES NOT DESCRIBE
DESKTOP, and this records the limit rather than withdrawing it.**

**At the OS-granted 546 logical height there is no bottom void** — the captures show content
running from the app bar to near the lower edge, with `Need Help with MER?` close to the bottom.
**The window is short, not tall.**

⭐ **The desktop constraint is HORIZONTAL, not vertical**, which is the opposite of the tablet's.
§13(ac)'s figures were 876 and 1224 logical **tall**; desktop gets **546**, and the machine's
maximum is **622** (§13(ak)).

⛔ **§7 AND §13(e) ARE NOT SUPERSEDED. Both stand.** §7's recommendation to anchor rather than
centre still addresses the tablet case it was made about. ⚠️ **What is recorded here is that a
reading taken at one aspect ratio was carried toward a platform with a different one**, and the
carrying was not warranted.

⛔ **SPLIT 8 September 2026 (evening) — THE LIMIT THIS FINDING RECORDS IS SOUND. THE EVIDENCE
OFFERED FOR IT IS PARTLY WITHDRAWN.**

✅ **SOUND — the heights, because they are the OS's own numbers.** `546` logical granted and `622`
logical maximum come from `GetClientRect` and the Win32 DPI and working-area values in §13(ak),
**not from a frame**. ⭐ **That is the same class of evidence that DISPROVED §13(al)** — reading
the window rect directly is what settled it — so these two figures are as reliable as anything in
this document.

✅ **SOUND — the reasoning, which needs no measurement at all.** §13(ac)'s figures were taken at
**876 and 1224 logical tall** and desktop gets **546**. ⭐ **A reading about vertical void does not
transfer to a viewport less than half the height, and that follows from the two heights alone.**
The claim that the desktop constraint is horizontal rather than vertical follows from the aspect
ratio, not from any frame.

⛔ **WITHDRAWN — the one claim read off `PrintWindow` frames at DPR 1.25.** *"the captures show
content running from the app bar to near the lower edge, with `Need Help with MER?` close to the
bottom."* **That is a vertical-extent measurement from the §13(al) instrument**, whose
unfaithfulness is recorded as inferred rather than verified and is therefore not established to
spare the vertical axis. ⚠️ **So *"at the OS-granted 546 logical height there is no bottom void"*
is DOWNGRADED from measured to unverified.**

⭐ **AND THE FINDING SURVIVES THE DOWNGRADE INTACT, WHICH IS WHY IT IS SPLIT RATHER THAN
RETRACTED.** Its purpose is to stop §13(ac)'s tablet reading being carried to desktop. **That
purpose is served by the height difference — 546 against 1224 — which is OS-derived.** ⛔ **Whether
a bottom void exists on desktop is now OPEN, and it was never load-bearing here.** ⚠️ **What a
capture CAN still say: the screen LOOKS full rather than empty at that height.** That is an
appearance reading and is retained as one.

⛔ **§7 AND §13(e) REMAIN UNSUPERSEDED, AND §7 IS SEPARATELY CORRECTED** — its void figures were
withdrawn the same evening for a different reason, precision rather than fidelity. **Neither
correction touches its recommendation.**

---

### (ap) THREE SCREENS WERE NOT CAPTURED, AND THE REASON IS §13(z)

**8 September 2026.** `history`, `form` and the discard dialog were **not** captured on Windows.

⛔ **DESKTOP HAS NO `uiautomator` EQUIVALENT.** Every tablet capture was confirmed against the
accessibility tree before the shot — that is how the state was known. On Windows the only route
was pixel-hunting: the app bar's top-right band was searched for a menu glyph and returned
**0 white-ish pixels**, so the navigation could not be located reliably. ⭐ **After §13(aj), guessing
at coordinates was not an acceptable method.**

⚠️ **KEYBOARD NAVIGATION IS UNTESTED, NOT A FINDING.** `TAB` produced **byte-identical md5s** before
and after — `6C9ADEE5E747` both times — which would suggest no focus indication. ⛔ **But there is
no control proving `SendKeys` reached the app at all**, and a silent input failure looks exactly
like an unresponsive app. **Recorded as untested.**

⭐ **THE CONNECTION, AND IT IS THE POINT OF THIS FINDING: this is §13(z)'s semantics gap arriving as
a practical obstacle.** The app exposes nothing a desktop automation tool can navigate by — and
**that is the same absence that makes it unnavigable by a screen reader.** §13(z) recorded semantics
as unmeasured from source; this is what unmeasured semantics feels like from outside. **The four
`tooltip:` occurrences in all of `lib/` (§13(ab)) are the whole of the app's exposed vocabulary.**

---

### (aq) THE CONTENT CHECK'S bgFrac WAS RETIRED, AND THE METHOD MATTERS MORE THAN THE CHANGE

**8 September 2026.** The frame-identity check built in §13(aj) had four properties. Both narrow
captures **FAILED** it:

    home__narrow__400x546              bar=52  bgFrac=0.319  distinct=65  palette=True  -> FAIL
    home__narrowest-os-permits__94x546 bar=40  bgFrac=0.311  distinct=61  palette=True  -> FAIL

**Both are genuine MER frames.** They failed on `bgFrac` alone — the requirement that `#F5F8FB`
dominate the body — **because content legitimately fills more of a narrow frame.** The threshold
had been calibrated on wide frames.

⛔ **THE THRESHOLD WAS NOT LOOSENED TO MAKE THEM PASS. THAT WOULD BE BENDING THE CHECK TO FIT THE
DATA.** Instead, dropping `bgFrac` from the verdict was **tested against every negative**:

| Frame | bar | distinct | palette | verdict without bgFrac |
|---|---|---|---|---|
| real MER, wide | 64 | 88 | True | **pass** |
| **the Gmail frame** | **0** | **1317** | **False** | ⛔ **FAIL** |
| a magenta form filling the screen | **0** | 1 | **False** | ⛔ **FAIL** |
| a desktop-only region | **0** | 548 | **False** | ⛔ **FAIL** |

⭐ **Every negative still fails, on `bar` and `palette`. `bgFrac` was doing no work against them** —
it was excluding legitimate frames and catching nothing. It is now **reported but not decisive**,
with the reasoning in the script.

⚠️ **THE TRANSFERABLE RULE: remove a criterion only after showing the NEGATIVES still fail without
it.** ⛔ **The tempting move is to check whether the positives still pass, which proves nothing** —
a check with no criteria passes every positive. **A criterion earns its place by rejecting
something, and it can only be removed by demonstrating that nothing it rejected is now accepted.**

---
### (ar) THE WALKTHROUGH MISSED ITS BRIEF — DESIGN-TRACK

**Recorded 8 September 2026 from the developer's own account, and it is not a defect finding.**
Nothing in the walkthrough is broken: §13(ak) verified its controls are present and fully within
the window at every size tested, on both platforms. ⛔ **The gap is between what was asked for and
what was built.**

**IN HIS TERMS:** he asked for a **visual, interactive walkthrough of the app's function** — the
user tapping the real button, editing a real record, seeing the notification path — and received
**a card slideshow.** Five pages of text and an icon, with `Next`, `Back` and `Skip`.

⭐ **AND THE COINCIDENCE IS NOT ONE: THE SCREEN NOBODY ASSESSED IS THE SCREEN THAT MISSED ITS
BRIEF.** `walkthrough_screen` has **zero findings in §§1-12**, **one capture** in the whole set
(step 1 of 5, at 375 only), and is **uncapturable on the tablet without destroying the 72 records**
(§13(q)). **It was never looked at, and it was the thing that had gone wrong.**

**TWO CANDIDATE SHAPES, AND NEITHER IS CHOSEN HERE:**

| | How it works | What it costs |
|---|---|---|
| **COACH MARKS over the live app** | an overlay dims the screen, cuts a hole around the **real** control, and the user taps the real thing | **No data is created and there is nothing to reset.** ⛔ But the user never completes a capture, so they learn where the button is without learning what happens after |
| **GUIDED SANDBOX** | the user drives real screens and creates a **real** record, cleaned up afterwards | Teaches by doing, which is what was asked for. ⛔ **Cleanup that misidentifies a record deletes a medical record** — and §13(ad) shows seven rows in this history are byte-identical, so "the one we just made" is not always distinguishable |

⛔ **TWO CONSTRAINTS ANY SOLUTION MUST SURVIVE:**

1. **WINDOWS HAS NO NOTIFICATION PATH AT ALL** — `notification_service.init()` returns before any
   channel is created. **A step pointing at lock-screen capture points at nothing.** ⭐ **The Help
   screen already solves exactly this**, and §8 records it as working: Windows gets a **replacement
   section** explaining the absence, because *"a user who finds nothing here cannot tell whether the
   section is missing or the feature is absent."* **Borrow that pattern rather than hiding the step.**
2. **NOTHING GATES CAPTURE, THE RECORD, OR EXPORT** — that is a standing property of this app.
   **Coach marks must therefore be dismissible at every step**, and a walkthrough that must be
   completed before the button works would break it.

⚠️ **A VIEW, MARKED AS A VIEW: coach marks plus one deliberate throwaway record.** The core action
is **one tap**, and there is little to teach beyond where the button is — so the overlay carries
most of the value and a single sandboxed record covers the "what happens next" the overlay cannot.

⛔ **AND THE LIMIT ON THAT VIEW IS STATED BECAUSE IT MATTERS: this has not been used.** The
developer has used this app; the view above has not. **If what users actually miss is the EDITING
flow rather than the capture — the wizard, the form, `Add details` — then the answer changes**,
because editing is where the app has two paths, two idioms and two densities (§10 decision 1).

⚠️ **IT BELONGS WITH THE COMPONENT VOCABULARY, NOT AHEAD OF IT. A walkthrough overlay IS a
component** — a dim layer, a cutout, an anchored tooltip, a step controller — and §1 records that
this app's problem is that every screen was solved and nothing was solved once. **Building the
overlay before the vocabulary means building it twice.**

#### The packages, evaluated 8 September 2026 from pub.dev rather than from memory

| Package | Version | Published | Likes | Points | Windows |
|---|---|---|---|---|---|
| **showcaseview** | 5.1.0 | 2026-06-17 | **3115** | 150 | ✅ |
| **tutorial_coach_mark** | 1.3.4 | **2026-08-28** | 1599 | 150 | ✅ |
| onboarding_overlay | 3.2.3 | 2025-10-24 | 375 | 150 | ✅ |
| overlay_tooltip | 0.2.4 | 2025-03-26 | 240 | 140 | ✅ |
| flutter_welcome_kit | 2.1.0 | 2026-05-07 | 19 | 150 | ✅ |
| ~~feature_discovery~~ | 0.14.2 | **2024-12-07** | 788 | 140 | ✅ |

**All six carry `platform:windows` on pub.dev, plus `is:dart3-compatible`, `is:null-safe` and
`is:wasm-ready`.** None declares platforms in its own `pubspec`, which for a **pure-Dart** package
means universal support — and pub.dev's tags confirm it.

⛔ **WINDOWS SUPPORT WAS EXPECTED TO BE THE FILTER AND IT ELIMINATED NOBODY.** The expectation was
reasonable — many Flutter packages quietly omit desktop, and MER ships on the Microsoft Store — but
**a coach-mark overlay is a `Stack` and a `CustomPainter`, so there is no native code to port.**
⭐ **The filter that mattered turned out to be maintenance, not platform:** `feature_discovery` is
**21 months stale** and is the only one ruled out.

**THE HAND-ROLLED ALTERNATIVE, COSTED SO THE CHOICE HAS BOTH SIDES:** a `Stack` over the app, a
dimming layer, a **cutout** (`ClipPath` with an inverted `Path`, or a `CustomPainter` using
`BlendMode.clear` on a saved layer), **`GlobalKey`-anchored positioning** to read each real
control's `RenderBox` rect, **tooltip placement that flips near an edge**, and a controller
sequencing the steps. ⭐ **The cutout and the edge-flipping are the real work; the rest is a
`Stack`.**

⚠️ **MER has 12 direct dependencies today**, so adding one for a first-run feature is a real cost
to weigh against `showcaseview`'s 3,115 likes.

⛔ **NO PACKAGE CHOSEN, and no shape chosen. DESIGN-TRACK.**

---

### (as) ⚠️ A FRAMEWORK EXCEPTION IS RAISED AT NARROW WIDTHS — UNEXAMINED

**Measured in a widget test, 8 September 2026, at `TargetPlatform.windows` and DPR 1.25.**

    NARROW logical=400  capW=360.0  overflowingTexts=0  exception=true
    NARROW logical=94   capW=54.0   overflowingTexts=2  exception=true

⛔ **`tester.takeException()` returns non-null at BOTH widths** — including **400 logical, where
nothing overflows visually and the content column is a healthy 360 px wide.** So the exception is
not the same thing as the visible overflow, and it fires where nothing looks wrong.

⚠️ **ALMOST CERTAINLY A `RenderFlex` OVERFLOW, AND THAT IS INFERRED RATHER THAN READ.** The
exception object was not captured or printed — only its presence was recorded. ⛔ **The actual
exception type and message are UNKNOWN and were not looked at.**

⭐ **WHY THIS IS RECORDED SEPARATELY RATHER THAN FOLDED INTO §13(am): it is the one thing in that
area measured by an instrument that has not lied.** §13(am)'s descriptions came from artefact
frames and are retracted; this came from a widget test. **It is also the only finding here that
suggests the narrow case has a real problem at 400 logical after all** — just not the one that was
claimed.

⛔ **NOT INVESTIGATED. What raises it, in which widget, and whether it also fires on Android at the
same width, are all open.** ⚠️ **Do not assume it is Windows-specific** — the test set
`TargetPlatform.windows`, but nothing establishes that the platform matters, and §13(ak) found the
platforms agreeing on the walkthrough layout at every size tested.
➕ **DIAGNOSED 9 September 2026 — AND THE DIAGNOSIS OVERTURNS THIS FINDING'S OWN FRAMING. The
finding above stays as written; every claim in it that this corrects is named.**

**(a) THE TYPE AND MESSAGE, VERBATIM.** Read from `FlutterErrorDetails`, not from
`takeException()`:

    type      : FlutterError
    library   : rendering library
    context   : during layout
    message   : A RenderFlex overflowed by 8.0 pixels on the right.

⚠️ **So *"almost certainly a `RenderFlex` overflow"* was RIGHT** — and it was recorded as inferred,
correctly, because nobody had looked. **The stack is EMPTY**: `RenderFlex` overflow carries none.
The owner comes from `informationCollector`, which `takeException()` does not expose.

**(b) THE WIDGET.** `debugCreator: Row ← _AppBarTitleBox ← Semantics ← DefaultTextStyle ←
MediaQuery ← Builder ← LayoutId-[<_ToolbarSlot.middle>] ← CustomMultiChildLayout ←
NavigationToolbar` — ⛔ **home's APP-BAR TITLE `Row`**, `home_screen.dart`'s
`title: const Row(...)`: `MERIconWidget(size: 40)` + `SizedBox(width: 10)` + a `Column` of two
`Text`s. **It wants a fixed 336 px and it is `const`, so nothing about it is data-dependent.**

**(c) THE 400 AND 94 EXCEPTIONS ARE NOT THE SAME EXCEPTION. ⛔ THE ASSUMPTION THAT THEY WERE ONE
FINDING WAS WRONG.** At 94 there are **TWO** overflowing flexes, and the one the error reported is
the second:

    w=400   1 overflow    8.0px   Row < _AppBarTitleBox        (app-bar title)
    w=94    2 overflows  314.0px  Row < _AppBarTitleBox        (app-bar title)
                          25.0px  Row < Padding < Listener     (a different widget entirely)

⭐ **The "25 pixels" quoted in this finding's own measurement was the `Listener` Row, not the app
bar** — the app-bar Row was overflowing by 314 px at that width and went unreported.

⛔ **(d) AND THIS IS THE CORRECTION THAT MATTERS: "the exception fires at 400 and not at wider
widths" WAS NEVER A FACT ABOUT THE LAYOUT.** Measured at 400 logical, same width, same platform,
consecutive pumps:

    PASS 1  errors=1  constraint <= 328.0  size=328.0  childrenTotal=336.0
    PASS 2  errors=0  constraint <= 328.0  size=328.0  childrenTotal=336.0

⭐ **IDENTICAL GEOMETRY. AN 8 px OVERFLOW IN BOTH PASSES.** Only the report differed, because
**`RenderFlex` reports an overflow ONCE per render-object instance per process** and `pumpWidget`
reuses the instance. ⛔ **A sweep predicated on "did it throw" reported every width from 1200 down
to 100 as CLEAN**, because an earlier probe had already consumed the report. **The instrument
measured a debug flag and was read as measuring the layout.**

⚠️ **THE WARM-UP HYPOTHESIS WAS TESTED AND KILLED, WHICH IS HOW THE REAL CAUSE SURFACED.** Pumping a
trivial widget first, then home at 400, **still raised the overflow** — so it was not process
warm-up. That is what forced the geometric measurement. ⭐ **The two hypotheses predicted opposite
outcomes, per `CLAUDE.md`'s discrimination rule, which is what the DPI-96 test failed to arrange.**

⛔ **THE MEASURED THRESHOLD, from `childrenTotal - constraints.maxWidth` rather than from whether
anything threw. Predicted from the model BEFORE sweeping, then confirmed at 1 px granularity:**

| Platform | Action width | Available | Overflows below | Confirmed |
|---|---|---|---|---|
| **Windows** (`shrinkWrap`) | 40 | `W − 72` | **408** | clean 408, 1 px at 407 |
| **Android** (`padded`) | 48 | `W − 80` | **416** | clean 416, 1 px at 415 |
| **iOS** (`padded`) | 48 | `W − 80` | **416** | clean 416, 1 px at 415 |

⭐ **The 8 px platform difference IS §13(y), showing up as geometry** — `MaterialTapTargetSize.padded`
gives the single `PopupMenuButton` 48 px and `shrinkWrap` gives it 40, so **Windows gets a WIDER
title box because its tap targets are smaller.** Four independent points fit exactly before the
boundary was swept: 320→96 px, 360→56 px, 375→41 px on Android, 375→33 px on Windows.

**(e) NOT WINDOWS-SPECIFIC. ⛔ This finding's warning not to assume it was is now settled in the
negative.** Windows, Android and iOS all overflow, and DPR is irrelevant — 1.0 and 1.25 give
identical geometry at identical logical widths.

**(f) IT FIRES ON OTHER SCREENS, AND THEY ARE DIFFERENT WIDGETS AT DIFFERENT WIDTHS.** Measured on
three screens, Windows and Android identical:

| Screen | Flex overflow below | Owner | Text overflow below |
|---|---|---|---|
| **home** | **408 / 416** | app-bar title `Row` | ⛔ **never** — 0 at every width |
| **history** | **300** (11.5 px at 275, ×12) | `Row < DefaultTextStyle < AnimatedDefaultTextStyle` | **350** (2 texts at 325) |
| **form** | **175** (24 px at 150) | `Row < Padding < Listener` | **325** (2 texts at 300) |

⚠️ **NINE SCREENS ARE STILL UNMEASURED** — the wizard, medication, vocabulary, your-data, about,
disclaimer, help, walkthrough and conditions. ⛔ **Do not read the three above as the app.**

⛔ **AND A FALSE CLEAN WAS CAUGHT BY INSTRUMENTING FOR IT: history at 100 logical reports NO
overflow, because it lays out only 5 paragraphs against 54 at 125, with 18 errors swallowed.**
Nothing overflowed because almost nothing was built. ⭐ **The probe now prints the paragraph count
and the swallowed-error count beside every verdict, so an empty tree can never again read as a
clean one.**

⚠️ **IS IT BENIGN? PARTLY, AND THE SPLIT MATTERS.** ⛔ **The EXCEPTION is debug-only** — `RenderFlex`
overflow reporting does not run in a release build, so no user ever sees an error. ⛔ **The OVERFLOW
IS NOT.** It is present in every frame at every affected width, in release as in debug, and what a
user gets is **silent clipping** of the app-bar title. **So §13(as) is not a harness artefact and
not a defect in the framework: it is a real layout defect whose only diagnostic surface happens to
be debug-only.** ⭐ **See §13(ay) — the widths this actually affects are shipped phones, not narrow
windows.**

⛔ **AND THE REPRODUCIBILITY GAP THAT HAD TO BE CLOSED FIRST, RECORDED AS AN §13(r) INSTANCE IN
SUBSTANCE: the test that produced this finding on 8 September DID NOT EXIST IN THE REPOSITORY.** It
was a throwaway; only its stdout survived, quoted above. ⭐ **Re-deriving it was the first task of
the diagnosis.** The instrument now lives in `test/narrow_geometry.dart` with per-screen sweeps in
`test/narrow_geometry_{home,history,form,home_devices}_test.dart`, and
`test/narrow_probe.dart` is kept **as the counter-example** — the exception-based probe whose
verdicts were an artefact.
⛔ **EVERY WIDTH IN THE DIAGNOSIS ABOVE IS A `flutter_test` FONT WIDTH AND IS INVALID FOR REAL
DEVICES — CORRECTED 9 September 2026 (evening). The MECHANISM findings all stand; only the numbers
go.** See §13(ay), retracted the same evening, for the proof.

**The harness font is monospaced at one em per glyph** — `iiiii` and `WWWWW` both measure 66.3 at
13 px, and 12 of 12 measurements advance exactly `fontSize + 0.25` per glyph
(`test/test_font_width_test.dart`). ⛔ **So any threshold that depends on how wide a string renders
is inflated by roughly 1.8x at this size.**

| Reported above | Status |
|---|---|
| home **408** Windows / **416** Android/iOS, confirmed at 1 px | ⛔ **INVALID as a device width.** Real bound ≈ **289**, below every shipping phone |
| history **300** flex / **350** text | ⛔ **INVALID** |
| form **175** flex / **325** text | ⛔ **INVALID** |
| the four points *"fitting the model exactly"* — 320→96, 360→56, 375→41, 375→33 | ⛔ **All four are the same artefact.** ⚠️ **They fit because they share one wrong input, which is exactly how a wrong model looks right** |

✅ **WHAT STANDS, and none of it depends on glyph width:**

- **(a)** the type, library, context and message — `FlutterError`, rendering library, during layout.
- **(b)** the owner: home's app-bar title `Row`, `const`, fixed-width by construction.
- **(c)** the 400 and 94 exceptions are **two different widgets**, not one finding.
- **(d)** ⭐ **the once-per-render-object-instance reporting**, and that a sweep predicated on
  `threw` reports clean while the layout overflows. **That is the most transferable thing here and
  it is font-independent.**
- **(e)** platform- and DPR-independence.
- **(f)** that other screens overflow at other widths, as different widgets — **the widths are
  wrong, the fact is not.**
- The **8 px** `padded`-versus-`shrinkWrap` gap: 48 against 40 is a constant, not a measurement.

⚠️ **AND THE FALSE CLEAN AT HISTORY 100 STANDS AS RECORDED** — 5 paragraphs against 54, 18 errors
swallowed — because it is a count of what was built, not a width.

⭐ **THE SHAPE, RECORDED BECAUSE IT IS A NEW ONE FOR THIS DOCUMENT: the instrument was correct and
its INPUT was fake.** §13(al) was an instrument that measured the wrong pixels. §13(aj)'s frames
were the wrong subject. **This was the right instrument, measuring the right property, on a
substitute the harness supplied without saying so.** ⛔ **A widget test is authoritative for
POSITION, CONSTRAINT and PROPORTION — and for nothing that turns on how wide a glyph is.**

---

---

### (at) ✅ DECISION D1 — THE COMPONENT VOCABULARY'S SCOPE INCLUDES COLOUR TOKENS

**Decided 8 September 2026.** §10 defines the component vocabulary as **seven** things: *one add
affordance · one selection control per cardinality · one label case · one date control · one
destructive treatment visually distinct from confirmation · one disclosure · one icon idiom.*
⭐ **It is now EIGHT. One colour system is added, and it is the vocabulary's FIRST piece.**

⛔ **§10's list is left exactly as written. This entry is the amendment; that list is the record of
what was scoped on 31 August.**

**THE REASONING, AND IT IS NOT "28 FAILURES NEED FIXING".** §13(w) found three things that are not
defects in a palette but the absence of one:

| | |
|---|---|
| `textPrimary` is **byte-identical** to `primary` | both `#0D4F82` — **two names, one colour** |
| `success` and `warning` appear in **NO measured pair** | the greens and ambers actually rendered are raw literals — `#2E7D32`, `#1B5E20`, `#E65100`, `#F57C00` |
| **~40 raw `Color(0x…)` literals sit outside the theme** | in `home_screen.dart`, `history_screen.dart`, `disclaimer_screen.dart`, `help_screen.dart`, `event_record.dart` |

⭐ **A palette with two names for one colour, two names used nowhere, and four times as many
colours outside it as inside is not a palette with defects. It is a system nobody designed.**
⛔ **§13(s)'s 28 failures are the SYMPTOM, not the finding.** Fixing 28 ratios without deciding the
system leaves the next colour added in exactly the position these forty are in.

**WHAT THIS UNBLOCKS: §13(s), §13(t), §13(w).** All three were correction-track and are now
vocabulary-track, and all three wait on the colour system rather than preceding it.

⛔ **AND THE OPERATIONAL WARNING FROM §13(w) SURVIVES THIS DECISION UNCHANGED, because it is about
the fix's REACH and not about its track.** The 28 failures split **11 named-token / 17
raw-literal** — ⭐ **recomputed from §13(s)'s emitted table for this entry rather than read off it,
per §13(w)'s own countermeasure: rows 1, 3, 4, 5, 11, 21, 22, 24, 25, 26 and 27 are the eleven
where every colour in the pair is a `MERColours` value or white.** The other seventeen are every
banner, both info cards including their alpha-composited bodies, the three help-status rows, and
the two blue info-card titles.

⛔ **SO A FIX APPLIED TO `MERColours` ALONE WOULD LOOK COMPLETE — one file, all named colours
corrected, a tidy diff — AND LEAVE 17 OF 28 UNTOUCHED.** The raw literals are the larger half.
⭐ **That is the strongest single argument for D1: a token-level fix is not even sufficient for the
symptom, let alone the system.**

⚠️ **ONE PROSE AMBIGUITY IN §13(w), NOTED AND NOT CORRECTED HERE.** Its 11-row cell reads *"the
five `textMuted` text styles, the input label, and the four `border` outlines plus the divider, and
the SnackBar action label"*, which parses as twelve. **The figure 11 is right**; the ambiguity is
that the divider is one OF the four `border` failures rather than additional to them, exactly as
§13(s)'s leverage table states — *"FOUR failures … rows 3, 4, 5 and the divider"*. **Recorded
because §13(w) is the entry that warns about prose figures drifting from computed ones, and this is
that, in miniature, inside the warning itself.**

⚠️ **WHAT D1 DOES NOT DECIDE:** what the colours should BE. No value, ramp, contrast target or
semantic name is chosen here. **Only that choosing them is inside the vocabulary's scope, and
first.**

---

### (au) ✅ DECISION D2 — PREVENT, NOT SUPPORT, AT NARROW WIDTHS

**Decided 8 September 2026.** §13(am)'s open design question — whether the app should **support**
arbitrarily narrow windows or **prevent** them — is answered: **PREVENT.** A minimum window size,
enforced in the Windows runner by handling **`WM_GETMINMAXINFO`**.

**THE REASONING IS THAT THE EVIDENCE SHRANK.** §13(am) was committed as 🔴 on frames from the
`PrintWindow` pipeline and corrected the same evening when a widget test measured the same widths:

| | claimed | measured |
|---|---|---|
| 400 logical | *"the stats card's fourth column is cut mid-word"*, `Recor / d / Event` | **content 360 wide, 20 px padding each side, ZERO overflowing texts** |
| 94 logical | — | **two APP BAR texts overflow** — the title and the subtitle. Nothing in the content column overflows at either width |

⭐ **So the failure is not at a width anyone reaches. It is at the OS floor, reachable only by
dragging a window to a sliver.** §13(am) already records that *"a defect at 400 would have made
'prevent' nearly obvious; a defect only at 94 does not"* — **and the decision goes the other way
for a different reason: not that prevent is obvious, but that support is not worth building.**

⛔ **RESPONSIVE LAYOUT FOR A 94 px WINDOW IS NOT WORTH BUILDING. A RUNNER CONSTANT IS.** Two
app-bar strings overflowing at a width no user works at does not justify breakpoints, a compact
app-bar variant, or a text-scaling rule. **One message handler removes the entire case.**

⚠️ **UNDECIDED, AND DELIBERATELY: WHAT THE MINIMUM SHOULD BE.** ⛔ **Nobody has measured the width
at which the layout actually begins to degrade.** The two figures that exist are 400 (clean) and 94
(two overflows), and **the boundary between them is unmeasured across a 306 px range.** ⭐ **A
number picked now would be a guess dressed as a constant** — and a minimum set too high is worse
than none, because it forbids window sizes that work. **Measuring it is the prerequisite, and it is
one widget test sweeping widths for `overflowingTexts > 0` or a non-null `takeException()`.**

⚠️ **AND §13(as) COMPLICATES THAT MEASUREMENT, WHICH IS WHY IT IS NAMED HERE.** A framework
exception fires at **400 logical as well as 94** — at a width where nothing overflows visually and
the content column is a healthy 360 px. ⛔ **So "the width at which the layout degrades" has at
least two candidate definitions — first visible overflow, and first raised exception — and they do
not coincide.** §13(as) must be diagnosed before the minimum can be chosen, or the sweep measures
one thing and the constant is set from the other.

⛔ **ONE CONSEQUENCE, RECORDED BECAUSE IT COSTS AN EVIDENCE BASE.** §13(al)'s retraction rests in
part on `windows/runner/` being **BYTE-IDENTICAL to the SDK template** — stated in §13(al)'s own
evidence table. **Adding a `WM_GETMINMAXINFO` case to `Win32Window::MessageHandler`
(`win32_window.cpp:181`, alongside the existing `WM_DPICHANGED` and `WM_SIZE` cases) ends that
property.** ⚠️ **Not an argument against D2** — the retraction is already independently settled by
the `FLUTTERVIEW` client rect and the widget test. **But the next session must not reach for
"byte-identical to the template" as a live control after this lands.**
➕ **THE TWO THRESHOLDS, MEASURED 9 September 2026. The "UNDECIDED" above stands — this supplies its
missing input, and does NOT choose the constant.**

⛔ **THE PREREQUISITE THIS ENTRY NAMED IS DISCHARGED: §13(as) IS DIAGNOSED.** It is a `RenderFlex`
overflow in home's app-bar title `Row`, and the reason it appeared to fire at 400 but not wider was
that `RenderFlex` reports once per render-object instance per process. **The exception was never a
width signal.** Geometry is: `childrenTotal − constraints.maxWidth`.

**Measured across three screens, Windows and Android identical at every width:**

| Screen | FRAMEWORK throws / flex overflows below | CONTENT degrades (text past its line budget) below |
|---|---|---|
| **home** | **408** Windows · **416** Android/iOS | ⛔ **never** — zero overflowing texts at every width from 1300 to 90 |
| **history** | **300** | **350** |
| **form** | **175** | **325** |
| **⭐ GOVERNING** | **416** | **350** |

⭐ **THE TWO DEFINITIONS DO NOT COINCIDE, AND THE FRAMEWORK ONE IS HIGHER — 416 against 350.** So
under this entry's own rule, **416 governs**: a minimum has to clear both, and the higher number is
the one that does.

⚠️ **AND THE GAP IS 66 px OF WIDTH IN WHICH THE FRAMEWORK COMPLAINS AND NO TEXT IS TRUNCATED**,
which is exactly the divergence this entry predicted. ⛔ **The reason is that they are DIFFERENT
DETECTORS, not two views of one thing:** a `RenderFlex` overflow is a *row* wider than its slot and
the parent clips it; a text overflow is a *paragraph* past its `maxLines`. **Home's title clips
without any text being truncated, because the clipping happens to the Row, not inside the Text.**
⭐ **§13(am)'s "zero overflowing texts at 400" was TRUE and was read as "nothing overflows at 400",
which is false.** One detector, two conclusions.

⛔ **BUT THE 416 FIGURE MUST NOT BE USED AS D2's MINIMUM, AND THIS IS THE REASON D2 STAYS
UNDECIDED.** Home's 408/416 is **§13(ay)** — a defect that affects **shipped phones**, where a
375-wide iPhone loses 41 px of title. ⛔ **A desktop minimum window size cannot fix a phone.** So
setting D2's minimum to 416 would **hide the symptom on the one platform where it is least
important** and leave it live on three others. ⚠️ **The honest reading: home's threshold should be
REMOVED by fixing §13(ay), not cleared by a window minimum** — and once it is, the governing
desktop figure drops to **350** (history's content threshold) or **300** (history's flex
threshold), depending on which definition is chosen.

⭐ **SO D2's CONSTANT DEPENDS ON A DECISION THAT IS NOT D2's: whether §13(ay) is fixed first.**
Recorded rather than resolved, because choosing the constant is explicitly not this pass's job.

⚠️ **NINE SCREENS UNMEASURED** — wizard, medication, vocabulary, your-data, about, disclaimer, help,
walkthrough, conditions. ⛔ **Any minimum chosen from three screens is a minimum for three
screens.** The sweep is one call per screen against `test/narrow_geometry.dart`; the cost is
knowing the harness each screen needs, not the measuring.

⚠️ **AND ONE FALSE CLEAN IS ON RECORD SO IT IS NOT RE-DISCOVERED: history at 100 logical reports NO
overflow** because it lays out **5 paragraphs against 54 at 125 logical, with 18 errors
swallowed.** ⛔ **Nothing overflowed because almost nothing was built.** The probe now prints
paragraph and swallowed-error counts beside every verdict, and a zero-paragraph width is marked
`VOID(nothing-laid-out)` rather than clean.
⛔ **BOTH THRESHOLDS ABOVE ARE WITHDRAWN — 9 September 2026 (evening). D2 STILL HAS NO MEASURED
INPUT, and this entry's "UNDECIDED" is now undecided for a second, better reason.**

**They were measured with the `flutter_test` font, which is monospaced at one em per glyph** —
proof in §13(ay) and `test/test_font_width_test.dart`. ⛔ **`416 governs` and `350 content` are
both inflated, and the reasoning built on their 66 px gap goes with them.**

⚠️ **THE STRUCTURAL POINT THE GAP WAS MAKING SURVIVES, AND IT WAS NEVER ABOUT THE NUMBERS:** a
`RenderFlex` overflow and a text overflow are **different detectors** — a row wider than its slot
against a paragraph past its line budget — so they can and do diverge. ⭐ **§13(am)'s "zero
overflowing texts at 400" was true and was read as "nothing overflows at 400", which is false.**
**That remains the reason a minimum cannot be chosen from one detector.**

⛔ **AND THE CONCLUSION THIS ENTRY DREW FROM THE NUMBERS IS NOW WRONG IN ITS PREMISE.** It reasoned
that home's 416 must not become D2's minimum because home's threshold is a **phone** defect that a
desktop window minimum cannot fix. ⭐ **There is no phone defect** — §13(ay) is retracted. **The
conclusion "do not set the minimum to 416" still holds, for the simpler reason that 416 was never
a real width.**

**WHAT D2 WOULD NEED, STATED SO IT IS NOT RE-DERIVED WRONG A THIRD TIME:**

1. ⛔ **A real-font measurement.** A widget test cannot supply it as configured. Either load the
   platform font into the harness with `FontLoader` and re-sweep, or measure from **framebuffer
   captures** at known DPR — the method used in §13(ay), which is occlusion- and DPI-honest and is
   **not** the `PrintWindow` pipeline.
2. ⚠️ **Per platform, because the fonts differ** — SF Pro, Roboto and Segoe UI are three different
   width tables, and only iOS has been measured at all.
3. ⛔ **Nine screens are still unmeasured**, and that was true before this correction.

⭐ **ONE THING IS NOW KNOWN THAT WAS NOT: the real widths are FAR lower than the harness suggested.**
Home's title needs **≈209 logical** against **295 available at 375**, with **127 points of clear
space**. ⚠️ **So a minimum window width may not be needed at all for the reasons this decision was
taken** — §13(am)'s 94-logical case is the only overflow ever demonstrated on a real surface, and
94 is a width reached only by dragging a window to a sliver. **D2 is not withdrawn; its
justification is now thinner than when it was decided.**

---

### (av) ✅ DECISION D3 — THE DISCARD DIALOG STANDS, AS A CONSIDERED DEPARTURE FROM §13(b)

**Decided 8 September 2026.** §13(a)'s fix shipped a confirmation dialog. §13(b) recommends against
exactly that. **The dialog stands, and the departure is recorded rather than left as a
contradiction between two entries in one document.**

**THE CONFLICT, QUOTED FROM BOTH SIDES:**

> §13(b) — *"It satisfies the standing rule that nothing gates capture, the record, or export — a
> confirm dialog on exit would gate exactly that. **Any fix to (a) should follow this pattern
> rather than introduce a dialog.**"*

> §13(a) — *"a clean exit leaves immediately with no prompt on either button and on the OS pop; a
> dirty exit prompts on all three."*

⛔ **AND §13(ai) THEN ASSESSED THAT DIALOG ON THE DEVICE AT THREE WIDTHS WITHOUT NOTING THE
TENSION.** Three entries, one document, one session.

⛔ **RECORDED PLAINLY, BECAUSE THE HONEST VERSION IS WORSE THAN THE FLATTERING ONE: THE
RECOMMENDATION WAS NOT CONSIDERED AND SET ASIDE. IT WAS NEVER READ.** The party that specified the
fix had not read §13(b) — or any of `AUDIT.md` §§1-12 — at the time. ⚠️ **So this is not a
documented design trade-off that happened to go the other way. It is §13(r)'s pattern again:
correct knowledge existing, in the same document, and not travelling.** The decision was reached
from the developer's stated requirement that **any change must still be confirmed** — a requirement
that **post-dates §13(b)** and was never tested against it.

⭐ **THE DEPARTURE IS UPHELD ANYWAY, AND ON ITS MERITS RATHER THAN ON THE FIX ALREADY BEING IN.**

1. ⛔ **CAPTURE-AND-LEAVE WOULD DEFEAT THE REQUIREMENT, NOT SATISFY IT.** The wizard's pattern
   preserves the draft on exit — it lets a change **reach storage without the confirmation**. That
   is the *opposite* of "any change must still be confirmed". §13(b)'s pattern is right for the
   wizard, where the alternative was **losing** the step; it is wrong here, where the alternative
   is **saving unreviewed**.
2. ✅ **AND THE DIALOG DOES NOT GATE CAPTURE, WHICH IS §13(b)'s ACTUAL OBJECTION.** The standing
   rule is that nothing gates capture, the record, or export. **13 widget tests in
   `test/log_event_exit_test.dart` assert every tap still records** — the dialog is on the EDIT
   path, on exit from a screen reached only with an `existing` record. **Nothing on the capture
   path meets it.** ⭐ **§13(b) generalised "a confirm dialog on exit" from the wizard, where exit
   *was* on the capture path, to a screen where it is not.**

⚠️ **§13(b)'s RECOMMENDATION STAYS EXACTLY AS WRITTEN AND IS NOT AMENDED.** It is annotated with a
pointer to this entry. ⛔ **Its OTHER half is untouched and still open: seven top-level screens
carry no exit guard of any kind.** D3 settles what shape a guard takes on `LogEventScreen`; **it
settles nothing about the seven.**

⭐ **THE UNRESOLVED QUESTION D3 CREATES, NAMED SO IT IS NOT INHERITED AS SETTLED: is the app's exit
rule now TWO rules?** Capture-and-leave on the wizard, confirm-on-dirty on the form. **That may be
correct — the two screens differ in exactly the way the reasoning above turns on — but nobody has
decided it as a rule, and the seven unguarded screens will each need one of the two.** ⛔ **That
belongs with the component vocabulary: an exit rule is interaction vocabulary.**

---

### (aw) ✅ DECISION D4 — THE FIFTEEN INDEPENDENTS FIRST, THEN THE VOCABULARY

**Decided 8 September 2026.** The fifteen items below are fixed before the component vocabulary
begins. ⛔ **None is provisional, none waits on anything, and several are behaviour or data rather
than surface.**

**THE STANDING TEST THAT PRODUCED THIS LIST, AND IT IS THE THING TO REUSE:**

> ⭐ **DOES THIS FIX SURVIVE THE REDESIGN, OR WILL IT BE REBUILT?**
> **SURVIVES** — behaviour, timing, data, logic, documents.
> **REBUILT** — anything with a visual or interaction surface.

⚠️ **THE COUNTERWEIGHT THE DEVELOPER RAISED, RECORDED BECAUSE IT IS THE REASON THE TEST EXISTS:**
*fixing little things while a holistic review may require major changes is how work gets done
twice.* ⭐ **That objection is correct, and it is an argument for the test rather than against
fixing anything.** ⛔ **The trap is fixing VISUAL things before the framework exists — not fixing
things at all.** A rename, a data-model correction and a document repair are not made obsolete by a
colour system.

**THE FIFTEEN, as identified 8 September 2026:**

| | Item | Why it survives |
|---|---|---|
| 1 | **§13(d)** `_hasUnsavedEvents` means a disk write failed | pure rename, no surface |
| 2 | **§13(j)** `logged_at` used as `whenHappened` at three sites | data and logic |
| 3 | **§13(n)** `ARCHITECTURE.md` §3's table membership | documents |
| 4 | **§13(o)** whether anything else depends on the rebuild a note edit does not trigger | logic, and **not investigated** |
| 5 | **§13(as)** read the framework exception's type and message | diagnosis; costs one test run |
| 6 | **§13(ak)** the runner requests a window the display cannot show | platform constant, no visual surface of its own |
| 7 | **§13(q)** pass 2b, the disposable-profile captures | process — ⚠️ **UNSCOPED, see below** |
| 8 | **§13(r)** the knowledge-not-travelling record | documents |
| 9 | **§13(f)** the unsaved banner and backup reminder cannot co-occur, undocumented | documents |
| 10 | **§13(g)** the 2.11 screenful figure's provenance | documents; already annotated where recorded |
| 11 | **§11** whether retired legacy values can be mapped forward | data |
| 12 | **§13(h)** 🔴 the backup banner frames backup as device transfer | **copy carries a factual error TODAY** |
| 13 | **§13(z)**'s audit half — semantics across 108 interactive constructions | measurement |
| 14 | **§13(u)**'s measurement half — render at 200% text scale | measurement |
| 15 | **§13(y)**'s theme half — the app sets neither `materialTapTargetSize` value | one theme property |

⭐ **ITEM 12 IS THE ONE WITH A USER-VISIBLE COST TODAY.** The banner tells a single-device user that
backup is *"the only way to get them onto another one"* — so the user for whom losing the phone
means losing every record reads it and concludes it does not apply to them. **The words are wrong
whatever the banner is rebuilt to look like.**

⚠️ **ITEMS 13, 14 AND 15 ARE SPLIT DELIBERATELY, AND ONLY THEIR SURVIVING HALVES ARE IN SCOPE.**
§13(z)'s individual labels, §13(u)'s layout adaptations and §13(y)'s per-control sizing are all
REBUILT and are **not** in this fifteen. ⭐ **Measuring is what survives; adapting is what does
not** — and measuring first is what tells the vocabulary what it has to satisfy.

⛔ **ITEM 7 CARRIES A KNOWN UNKNOWN AND IS NOT PRICED.** §13(q) records that 2b *"IS UNSCOPED AND
ITS COST IS NOT KNOWN"* — a second user account, a second `applicationId`, an emulator or a spare
handset, with **nothing established about which, or what any of them costs.** ⚠️ **It is in the
fifteen because it does not wait on anything, not because it is cheap.**

⛔ **WHAT IS NOT IN THE FIFTEEN, AND MUST NOT DRIFT INTO IT:** §10's six fixes (all REBUILT except
fix 6, which is item 13's territory), §13(s)/(t)/(w) — **now vocabulary-track by D1** — §13(aa),
(ab), (ac), (ad), (ae), (af), (ag), (ai), (am), (an), (ar), (h-ii), (i), (k), (l), (p), §§3-7 and
§9's two adviser items.

⭐ **AND THE ORDER AFTER THE FIFTEEN IS SET BY D1: the vocabulary's FIRST piece is the colour
system.** ⚠️ **One item is upstream of the vocabulary itself and is neither an independent nor part
of it — §10 decision 1's open half, whether COMPLETENESS is the right axis for two edit paths,
because §10 records that its answer *"decides how many idioms the vocabulary must cover"*.**

---

### (ax) ⚠️ THE RECORD-COUNT DISCREPANCY — CHAT'S SHAPE IS WRONG, AND A REAL UNRECONCILED DELTA IS UNDERNEATH IT

**Searched 8 September 2026 (evening), across `AUDIT.md` (3,028 lines), `STATUS.md` (1,762 lines)
and the Change Register (5,810 lines).**

⛔ **NOT IN `AUDIT.md` AT ALL.** Zero hits for a 58- or 59-record count across all 3,028 lines.
✅ **Positive control: `72 records` returns 5 hits in the same file, searched the same way**, so the
apparatus works and the null is real.

⭐ **BUT IT IS NOT "NOWHERE", WHICH IS WHAT WAS EXPECTED. IT LIVES IN `STATUS.md`, WITH FOUR
NUMBERS ACROSS TWO DEVICES — AND THE FRAMING CARRIED INTO THIS SESSION CONFLATES THEM.**

| Count | Device | Where | When | Instrument |
|---|---|---|---|---|
| **59** | **iPhone** (iPhone16,2, iOS 26.6) | `STATUS.md:541` | 30 Aug 2026 | `devicectl device copy from --user mobile --domain-type appDataContainer` (`:645-647`) |
| **58** | **the same iPhone** | `STATUS.md:163` | 7 Sep 2026 | `mer_events.db` copied off and **re-read four times, `sha256 e6366d33…` byte-identical every time** |
| **66** | **Teclast P30 tablet** | `STATUS.md:915-917` | at the SQLite migration | `sourceEntries 66 / loadable 66 / inserted 66 / distinctIds 66 / skipped 0` |
| **72** | **the same tablet** | `STATUS.md:227, 281, 344, 385` and throughout | design-audit sessions | the live store, `adb install -r` throughout |

⛔ **SO "59 vs 58 vs 72" IS TWO DEVICES READ AS ONE.** ✅ **The 72 is not part of any discrepancy**
— it is the Android tablet, and 66 → 72 is ordinary growth between the migration and the audit.
⭐ **The claim was wrong in its SHAPE while pointing at something real, which is the most expensive
kind of half-right: the wrong pair invites the wrong investigation.**

⛔ **WHAT IS GENUINELY OPEN: THE iPHONE WENT 59 → 58 IN EIGHT DAYS, AND NOTHING RECONCILES IT.**
Zero hits for any sentence relating the two figures, in `STATUS.md` or in the Change Register.
**A one-record decrease on a device holding real medical records, unexplained and unremarked.**

⚠️ **THE MOST LIKELY BENIGN EXPLANATION, STATED AS UNVERIFIED RATHER THAN ADOPTED — see §13(r) and
`feedback_available_explanation_bias`.** ⛔ **The 59's STORE IS NOT NAMED.** `STATUS.md:541` says
only *"59 event records on the device"*, and `:645-647` names the method without naming the file.
The 58 is explicitly `mer_events.db`, the **SQLite** store. **So the two figures may be counts of
DIFFERENT STORES**, in which case there is no loss at all — the same session measured
`epilepsy_event_records_v1` holding a partial history, *"iOS, 7 Sep 2026: **42 of 58**"*
(`:34-35`, `:315`). ⚠️ **That is a hypothesis to TEST, not a resolution.**

⭐ **AND THE OPPOSITE READING HAS EVIDENCE TOO, WHICH IS WHY THIS IS NOT CLOSED EITHER WAY.** The
migration was designed specifically so a count could not drop — `STATUS.md:906-908`: *"`id` is
deliberately NOT a primary key. The JSON array permits duplicates; rejecting one would turn 'this
device has two records sharing an id' into 'the migration lost a record'. Duplicates are carried
and counted."* ⛔ **So if a record did go missing, a mechanism built expressly to prevent it
failed** — and the tablet's `skipped 0` shows the design working there.

✅ **IT CLOSES CHEAPLY AND WITHOUT TOUCHING EITHER DEVICE.** `STATUS.md:163` records that **three
copies of `mer_events.db` now exist off-device**, and the 30 August session copied the iPhone's app
container. ⭐ **Counting rows in the archived copies, and naming which store each count came from,
settles it.** ⛔ **Until then: recorded as an OPEN, UNEXPLAINED DELTA on the iOS device. Not a
finding of data loss, and not dismissed as a measurement artefact.**

⚠️ **AND THE PROCESS POINT, WHICH IS WHY THIS ENTRY EXISTS RATHER THAN A ONE-LINE CORRECTION.** The
figures were carried into this session from a conversation, in the wrong pairing, with no citation
— and had they been checked once against `STATUS.md`, both the error and the real delta would have
surfaced together on the first look. ⭐ **A discrepancy that exists only in a chat transcript is
exactly what this project's two-tool split says cannot be relied on; the fix is not to distrust it
but to go and read the file it is about.**
➕ **RECONCILIATION ATTEMPTED 9 September 2026 AND NOT ACHIEVED. The delta stays OPEN, and this
records what was established, what was ruled out, and what would close it.**

⛔ **THE OFF-DEVICE COPIES ARE NOT ON THIS MACHINE.** This entry says the reconciliation *"closes
cheaply"* from the three `mer_events.db` copies. ⚠️ **They were made on the MAC** —
`STATUS.md`'s *"Session: 7 September 2026 (evening) — Mac"* — and a Windows session cannot reach
them.

**Searched with live controls, because eleven probe failures this session were apparatus, not
absence:**

    mer_events / epilepsy*db / mer*.sqlite across C:\dev, OneDrive\Projects,
    ~/.claude, Documents, Downloads, Desktop        0 hits
    any .db or .sqlite ever committed to this repo   0
    POSITIVE CONTROL  AUDIT.md under C:\dev          1 hit
    POSITIVE CONTROL  *.db under OneDrive\Projects   1 hit

⭐ **THE APPARATUS IS LIVE AND THE NULL IS REAL. The copies exist; they are on the other machine.**

⭐ **AND A BASELINE SET NOBODY HAD RECORDED WAS FOUND, WHICH IS THE WRONG DEVICE AND IS RECORDED SO
IT IS NOT MISTAKEN FOR THE COPIES.** `OneDrive\Projects\App Dev\Claude\MER Device Baselines` —
**11 files, all 27 August 2026**: three JSON backups, three CSV exports, three `BASELINE …txt`
notes, `baseline.py` and `seeds.txt`. ⛔ **Every one is the TECLAST P30 TABLET at 72 records**, and
the notes say so in their first line. **They bear on the tablet, not the iPhone, and settle nothing
here.**

⚠️ **They do incidentally confirm the tablet's arithmetic in this entry**: 66 at the SQLite
migration (25 August, evening) and 72 by 27 August — **six added in two days of ordinary use**, so
66→72 needs no explanation and remains no part of any discrepancy.

**(d) IS ANSWERED, AND IT IS A FIRM NO. NOTHING RECORDS A DELETION — BY DESIGN.**

    tombstone / deleted_at / is_deleted across lib/    0 hits
    POSITIVE CONTROL  is_active across lib/            5 files

⛔ **A single-record delete rewrites the ENTIRE event table.** `_deleteAndPersist`
(`history_screen.dart`) does `removeWhere` then `onRecordsChanged`, which reaches
`SqliteEventStore.save(List)` — `txn.delete('event')` followed by a re-insert of everything that
remains, inside one transaction. ⭐ **So a deleted record leaves NO row, NO flag, NO log and NO
Sentry event, and the surviving rows are renumbered by `eventToRow(record, i)`.**

⚠️ **THAT IS EXACTLY THE SIGNATURE OBSERVED: a count one lower and nothing else changed.** ⛔ **It
does not make deletion the cause. It means deletion cannot be excluded by looking**, which is a
different and weaker statement — and §13(ab) is worth reading beside it: **an unlabelled
destructive control on every History row, eleven on one screen, 25 px apart.**

**(c) WHAT THE 59 COUNTED — INFERRED, NOT READ, AND FLAGGED AS SUCH.** `STATUS.md:541` says only
*"59 event records on the device"*; `:645-647` names the method — a `devicectl` app-container copy
— **without naming the file**. ⚠️ **The inference: the same sentence says that copy is how *"the
59-record count AND the 34/32 active-vocabulary counts were verified"*, and the vocabulary counts
live in SQLite tables**, so the container read that produced both was almost certainly
`mer_events.db`. ⛔ **If that holds, the benign reading in this entry — that 59 and 58 count
DIFFERENT STORES — is substantially weakened, because both would be the same store.** ⚠️ **It is
an inference from one sentence and is NOT offered as a finding.**

**(a) and (b) CANNOT BE ANSWERED FROM THIS MACHINE.** No per-store row count, and no
present-in-earlier / absent-in-later comparison by id. ⛔ **A count alone was never going to settle
it anyway — a count stays level while one row replaces another, which is why (b) was asked for by
id rather than by total.**

⛔ **NO CAUSE IS SUPPLIED, AND THAT IS DELIBERATE.** The workspace rule is explicit: a false cause
is worse than no cause, because it closes the question. **Recorded as UNEXPLAINED.** ⚠️ One fact
narrows it without explaining it: **no session touched the iPhone between 30 August and 7
September** — the intervening sessions are 7 September Windows (tablet) and 7 September evening Mac
(where 58 was measured). **So whatever happened was not a recorded development action.**

✅ **WHAT WOULD CLOSE IT, precisely, and it needs the Mac and nothing else:**

1. `SELECT COUNT(*) FROM event` in each of the three off-device `mer_events.db` copies, **naming
   which copy is which** — they were taken before the first install and re-read four times.
2. The same count against `epilepsy_event_records_v1` in the container copy, so the two stores are
   counted separately and the *"different stores"* reading is tested rather than assumed.
3. ⭐ **The 30 August container copy, if it was kept** — that is the only artefact that can say what
   the 59 counted, and (c) is inference until it is read.
4. **An id-level set difference between the earliest and latest copies**, not a count.

---

### (ay) 🔴 HOME'S APP-BAR TITLE IS CLIPPED ON EVERY PHONE NARROWER THAN 416 LOGICAL — INCLUDING ONE IN THE CAPTURE SET

**Measured in widget tests, 9 September 2026** — `test/narrow_geometry_home_devices_test.dart`, at
real shipped device metrics, `TargetPlatform.android` and `.iOS`.

⛔ **THIS IS NOT §13(as) AND IT IS NOT §13(am). Both of those were about NARROW WINDOWS on the
desktop — widths reachable only by dragging. This is about PHONES, at their normal size, shipped,
today.**

| Logical | Device | Verdict | Clipped |
|---|---|---|---|
| **320x568** | iPhone SE 1st gen | ⛔ **OVERFLOW** | **96 px** |
| **360x800** | common Android phone | ⛔ **OVERFLOW** | **56 px** |
| **375x667** | iPhone 8 / SE 2nd–3rd gen — ⭐ **IN THE DESIGN-AUDIT CAPTURE SET** | ⛔ **OVERFLOW** | **41 px** |
| 430x932 | iPhone 15 Pro Max — in the capture set | ✅ clean | — |
| 800x1280 | tablet proxy — in the capture set | ✅ clean | — |
| 1012x546 | what Windows is granted (§13(ak)) | ✅ clean | — |

⛔ **THE CAUSE IS ONE FIXED-WIDTH `const Row` AND IT IS EXACT, NOT APPROXIMATE.** Home's
`title: const Row(...)` is `MERIconWidget(size: 40)` + `SizedBox(width: 10)` + a `Column` whose
widest child is `Text(kAppName)` at 13 px w600. **It wants 336 px and never negotiates.** Available
width is `logicalW − actionWidth`, so:

    Android / iOS   avail = W - 80   overflows below 416   (48 px action, MaterialTapTargetSize.padded)
    Windows         avail = W - 72   overflows below 408   (40 px action, shrinkWrap)

⭐ **Four independent measurements fit that model exactly before the boundary was swept, and the
boundary then confirmed at 1 px: clean at 416, 1 px at 415 on both Android and iOS; clean at 408,
1 px at 407 on Windows.** The 8 px platform difference **is §13(y)** — `padded` gives the overflow
menu 48 px, `shrinkWrap` 40, so **Windows gets a wider title box because its tap targets are
smaller.**

⛔ **WHAT A USER SEES: NOTHING. `RenderFlex` overflow reporting is DEBUG-ONLY, so no error reaches
a release build — the title is simply cut off on the right, silently, in every frame.** ⭐ **That is
why 41 px of clipping has sat in a capture at 375 without being written down.**

⚠️ **AND THE CAPTURE AT 375 IS THE PART THAT SHOULD HAVE CAUGHT IT.** `§7` reads *"At **375** this
is the best-composed screen in the app"* — ⛔ **assessed from a frame in which the app-bar title was
clipped by 41 px.** The clipping is at the right-hand edge of a dark navy band, behind an overflow
menu, in the least-scrutinised part of the screen. **A capture CAN show this; it is appearance. It
was looked at and not seen.**

⭐ **THIS IS THE COUNTER-EXAMPLE TO THIS SESSION'S OWN CAPTURE RULE, AND IT IS RECORDED AS ONE.**
`CLAUDE.md` now says captures answer *"how does it look"* and never *"how big is it"* — and it is
right. **But here the geometric defect WAS visible in a capture and the eye missed it**, while the
widget test found it immediately and exactly. ⛔ **So the rule's asymmetry is real but its comfort
is not: a capture may not be able to MEASURE, and the eye cannot be relied on to NOTICE either.**
**Neither instrument was used; only one was available at the time.**

⚠️ **RELATIONSHIP TO §13(am), STATED BECAUSE IT SHRINKS THAT FINDING FURTHER.** §13(am) as corrected
reports *"two APP BAR texts overflow"* at **94 logical** and treats 94 as the interesting width.
⛔ **94 is not a floor phenomenon — it is one far point on a continuum that begins at 416.** The
same `Row`, overflowing 314 px there and 41 px at 375. **§13(am)'s subject was never the narrow
window; it was this.**

⚠️ **NOT A D2 CASE, AND THIS IS WHY IT IS SEPARATE.** §13(au)'s decision is PREVENT-by-minimum-window
on the **desktop**. ⛔ **A minimum window size cannot help a phone.** Fixing this needs the title to
negotiate — `Flexible`/`Expanded` on the `Column`, ellipsis or a shorter string — which is a
**layout change on a visual surface**, so by D4's test it is **REBUILT, not SURVIVES**, and it
belongs with the component vocabulary rather than the fifteen independents.

⛔ **NO FIX PROPOSED HERE. Two shapes exist and neither is chosen: let the title shrink, or drop the
subtitle below a breakpoint.** §13(aa) records that the app has **no width breakpoints anywhere**,
so the second shape would be the first one in the codebase.

⭐ **SEVERITY, ARGUED RATHER THAN ASSERTED.** It is 🔴 because it is **live on shipped devices**, on
the **primary screen**, affecting the **app's own name**, on **three of the six widths measured** —
and because the smallest common phone loses **96 px**, which is most of the title. ⚠️ **It is not
data loss and it gates nothing**: capture, the record and the export are untouched.
⛔ **RETRACTED 9 September 2026 (evening) — THIS FINDING IS AN ARTEFACT OF THE `flutter_test` FONT.
THERE IS NO DEFECT. The finding above stands as written and is wrong.**

⭐ **IT WAS RECORDED AS 🔴, PUSHED, AND A FIX WAS BRIEFED BEFORE THE FIRST QUESTION WAS ASKED: does
a widget test measure text the way a device does?** ⛔ **It does not.**

**1. THE HARNESS FONT IS MONOSPACED AT ONE EM PER GLYPH.** Measured in
`test/test_font_width_test.dart`:

    iiiii  at 13px = 66.3        WWWWW  at 13px = 66.3        equal
    12 of 12 measurements advance exactly fontSize + 0.25 per glyph,
    across sizes 10, 13, 24 and four different strings

⭐ **`iiiii` and `WWWWW` measuring the same is the discriminator, and no proportional font can do
it.** Length and glyph COUNT are the only inputs; which glyphs they are makes no difference.

**2. THE NUMBER THAT STARTED THIS WAS THAT ARTEFACT, EXACTLY.** `kAppName` is
**22 characters**, and **22 x 13 = 286** — precisely the `Column` width measured. ⛔ **The
"wanted 336" was `40 + 10 + 286`, and 286 was never a text width.**

**3. THE REAL RENDER AT 375 IS NOT CLIPPED, AND HAS 127 LOGICAL POINTS TO SPARE.** From
`captures/home__empty__375x667__2026-09-07-ios-se3-sim.png` — a **framebuffer** capture at DPR 2,
⭐ **not the `PrintWindow` pipeline**, so a distance in the file is a distance in the layout over a
known DPR:

    title block (icon + gap + text)   x   7.5 .. 216.0 logical    208.5 wide
    the ... overflow menu             x 343.0 .. 365.0 logical
    CLEAR SPACE BETWEEN THEM                             127.0 logical

⚠️ **Apparatus controlled, and its FIRST version failed its own control and was rebuilt.** The
band detector took `min()`/`max()` over a sparse set of navy rows, folded the navy *"Record with
details"* button into the app bar, and reported a band of y 0..762. **The midline control returned
0.000 navy, which is what exposed it.** Corrected to the first contiguous run: navy **0.899** at the
band midline, **0.000** forty pixels below it. **Both controls required to pass before any figure
was read.**

⛔ **SO THE REAL THRESHOLD IS ABOUT 289 LOGICAL, NOT 416** — `209 + 80` — and **the narrowest
shipping phone is 320.** ✅ **No phone overflows. Not the iPhone SE at 320, not a 360 Android, not
the 375 in the capture set.** ⚠️ **That 289 is derived from ONE capture, SF Pro on iOS; Roboto and
Segoe UI differ, and the figure is a BOUND rather than a threshold.** ⛔ **It is not offered as a
new number to build on.**

⛔ **AND THE COUNTER-EXAMPLE FRAMING IN THIS FINDING IS RETRACTED WITH IT, BECAUSE IT WAS THE
OPPOSITE OF THE TRUTH.** This entry claimed *"the defect WAS visible in a capture and the eye missed
it"*, and read §7's *"best-composed screen"* as a judgement made from a clipped frame. ⭐ **The
frame was never clipped. The eye was RIGHT and the widget test was wrong.** ⚠️ **§7 needs no
annotation and has not been given one** — the brief for this pass asked for one, and it would have
put a false correction into the document.

⭐ **THE REAL LESSON IS THE INVERSE OF THE ONE RECORDED HERE, AND IT IS THE MORE USEFUL ONE.**
`CLAUDE.md` says geometry comes from widget tests and appearance from captures. **That rule is still
right — and it does not say a widget test's geometry is UNCONDITIONALLY true.** ⛔ **A widget test
measures the LAYOUT ALGORITHM exactly and the INPUTS to it only as well as the harness supplies
them.** Text width is an input, and the harness supplies a fake one. **So: a widget test is
authoritative for POSITION, CONSTRAINT and PROPORTION, and NOT for any figure that depends on how
wide a glyph is.**

⚠️ **WHAT SURVIVES FROM THIS FINDING: nothing about widths.** The `Row` is still fixed-width by
construction, and it would still overflow at a sufficiently narrow width — ⛔ **but the widths at
which it does are all below any shipping device**, and §13(am)'s 94-logical case is the only one
ever demonstrated on a real surface.
➕ **THE PROCESS RECORD, 9 September 2026. The retraction above is the technical fact; this is how
it came to be written, and it is the more useful half.**

⛔ **THIS FINDING WAS WRONG WHEN IT WAS WRITTEN, PUSHED WHILE WRONG, AND A FIX FOR IT WAS BRIEFED
AND SPECIFIED BEFORE ANYONE ASKED WHETHER A WIDGET TEST MEASURES TEXT THE WAY A DEVICE DOES.**

**Recorded from the briefing party's own account, and attributed rather than asserted** — the same
sourcing as §13(av)'s *"it was never read"*: ⚠️ **a fix was pushed through over this entry's own
`⛔ NO FIX PROPOSED HERE`, by a party that had said in the same breath that a pushback should be
taken seriously rather than overridden — and it was overridden twice.**

⭐ **WHAT ACTUALLY STOPPED IT WAS THE BRIEF'S OWN ESCAPE CLAUSE, not the pushback.** The fix brief
carried *"you can read the widget and chat cannot. If the evidence says otherwise, say so"*, and a
stop condition for the case where no option worked. **Both were used.** ⛔ **A brief that had merely
instructed the fix would have shipped a change to `home_screen.dart` to satisfy a number that was
never a text width** — and every one of this document's checks would have passed on it.

⛔ **AND THE COUNTER-EXAMPLE FRAMING IN THIS ENTRY WAS BACKWARDS, WHICH IS THE PART MOST WORTH
KEEPING.** It reads: *"the defect WAS visible in a capture and the eye missed it"*, and it read §7's
*"best-composed screen"* as a judgement made from a clipped frame. ⭐ **The frame was never clipped.
The EYE WAS RIGHT and the WIDGET TEST WAS WRONG.** The capture showed the title rendering in full
with 127 logical points to spare, which is exactly what a capture is for and exactly what it
reported.

⚠️ **SO §7 IS DELIBERATELY NOT ANNOTATED, AND THAT REFUSAL IS PART OF THE RECORD.** This pass was
briefed to annotate §7's *"best-composed screen"* as assessed from a clipped frame. ⛔ **It was
declined, because the annotation would have inserted a FALSE CORRECTION into a section that was
right.** ⭐ **A correction is a claim like any other and gets checked like any other** — and an
audit that only ever adds corrections will eventually correct something that was never wrong.

⭐ **THE ASYMMETRY THIS ENTRY CLAIMED IS REAL BUT POINTS THE OTHER WAY.** `CLAUDE.md`'s capture rule
— geometry from widget tests, appearance from captures — held for §13(al), where a capture lied
about geometry. ⛔ **Here the widget test lied about geometry and the capture told the truth**,
because the quantity at issue was **how wide a glyph is**, which is an INPUT the harness fakes and
a device renders. **Both rules are right about different properties, and neither is a general
licence.**

---

### (az) ⛔ THE APPARATUS WAS FLAWLESS AND THE INPUT WAS WRONG — EVERY CHECK THIS SESSION BUILT OPERATES DOWNSTREAM OF THE INPUT

**9 September 2026.** ⭐ **Recorded as its own entry rather than appended to §13(aj), and the reason
is where a future reader will look.** §13(aj) is titled for the CAPTURE instrument and all four of
its instances are capture-pipeline failures. **This is a WIDGET TEST failure**, and filing it under
a capture finding would put it exactly where nobody searching *"why did a widget test lie"* would
look. ⚠️ §13(aj)'s own thesis — an instrument measuring a PROXY — is also not what happened here.

**WHAT HAPPENED, AND EVERY LINE OF IT PASSED:**

| Check | Result |
|---|---|
| the geometry was measured correctly | ✅ `childrenTotal − constraints.maxWidth`, exact |
| a model was built and fitted | ✅ **four independent points**: 320→96, 360→56, 375→41, 375→33 |
| the boundary was PREDICTED before sweeping | ✅ stated as 336+80 and 336+72 in advance |
| the prediction was confirmed at 1 px | ✅ clean 416 / 1 px at 415; clean 408 / 1 px at 407 |
| three platforms agreed | ✅ Windows, Android, iOS |
| a rival hypothesis was tested and killed | ✅ the warm-up hypothesis, with opposite predictions |

⛔ **AND THE ANSWER WAS STILL WRONG, BECAUSE NOT ONE OF THOSE CHECKS WAS ABOUT THE INPUT.** The
harness supplied a monospaced font at one em per glyph; every figure downstream inherited it.
⭐ **A WRONG INPUT PRODUCES A PERFECTLY SELF-CONSISTENT SET OF WRONG NUMBERS — and consistency is
what usually reads as proof.** The four points fitted **because** they shared one wrong input.
**Fit is evidence about a model, never about its inputs.**

⛔ **THIRD TIME THIS SESSION, AND THE THREE ARE NOT THE SAME FAILURE — WHICH IS THE POINT.**
Collapsing them would repeat the error this document keeps finding:

| | Where it broke | What was checked instead |
|---|---|---|
| **`PrintWindow`** (§13(al)) | the instrument's **OUTPUT** — it measured the wrong pixels | occlusion-independence, proven and true |
| **the DPI-96 test** (§13(al)) | the **INFERENCE** — falsifiable but not discriminating | that the prediction could fail, which it could |
| **the Ahem font** (§13(ay)) | the **INPUT** — a substitute supplied silently | the geometry, the model, the boundary, the platforms |

⭐ **THE COMMON THREAD IS NOT THE MECHANISM. IT IS THE POSITION: each was verified DOWNSTREAM of
where it broke.** ⛔ **And every rule added to `CLAUDE.md` this session sits downstream too** — the
capture rule governs which instrument answers which question, the discrimination rule governs the
inference, the prefs rule governs harness state, and the annotation rule governs the write. **Not
one of them asks what the harness is standing in for.**

**PRACTICAL FORM, and it is the one thing this entry is for: before trusting a measurement, name
every INPUT the harness supplied rather than the system under test, and say which are real.** For a
widget test that is at least: the font and its metrics, the platform override, the device pixel
ratio, the view size, the locale, the text scale factor, and the clock. ⭐ **Each is a substitute
until shown otherwise, and a substitute that is never named is never checked.**

⚠️ **AND THE CHEAPEST CONTROL IS A DISCRIMINATING ONE, WHICH IS WHAT SETTLED IT IN SECONDS AFTER
DAYS OF CONFIDENT WRONG NUMBERS: `iiiii` and `WWWWW`.** They measure identically at 66.3, and no
proportional font can do that. ⛔ **The question was never "is the measurement right" — it was
"what is this measuring with".**

---

### (ba) 🔴 THE BACKUP DOES NOT CONTAIN THE VOCABULARY — A PRESERVATION GAP, NOT A COPY PROBLEM

**Code-verified, 9 September 2026**, against `models/backup.dart` and `services/backup_service.dart`.
⛔ **Nothing in this document has recorded it.**

**WHAT THE ENVELOPE CARRIES** (`buildBackupJson`, schema **4**): `format`, `schemaVersion`,
`appVersion`, `exportedAt`; `recordCount` + `records`; `medicationNoteCount` + `medicationNotes`;
`conditionCount` + `conditions` (as **names**, with `seededKey`, `isActive`, `sortOrder` — no ids,
because `condition.id` is AUTOINCREMENT and local); and `eventTypeConditions`, the event-type-value
to condition-name map.

⛔ **WHAT IT DOES NOT CARRY: the vocabulary tables.** No `event_type`, no `observation`, no
`trigger_option`. ✅ **And the restore path never touches them** — `Vocabular` returns **0 hits**
across `backup_service.dart` (control: `MedicationNote` returns 5).

**SO A RESTORE ONTO A FRESH INSTALL LOSES:**

1. ⛔ **Every USER-DEFINED vocabulary entry that no surviving record happens to use.** An
   observation or trigger the user added and has not yet logged is simply gone.
2. ⛔ **Every hide / retire decision.** `is_active` is the mechanism §13's D6 rests on — *"entries
   are hidden, never deleted"* — and **none of that state is in the file.** A user who curated a
   long seeded list down to the handful they use gets the full list back.

⚠️ **RECORD VALUES DO SURVIVE, WHICH IS WHY THIS IS EASY TO MISS.** `EventRecord.toMap()` carries
`feelings` and `triggers` as plain strings, and §2 records that `_pinned` exempts *"orphan values a
record already holds"*, so a restored record still displays what it holds. ⭐ **The DATA is intact
and the user's CURATION is not.** Nothing is silently wrong on screen, which is exactly the property
that would keep this unnoticed.

⭐ **THIS IS THE SAME ARGUMENT THAT PUT MEDICATION NOTES IN THE ENVELOPE AT SCHEMA 2 AND CONDITIONS
AT SCHEMA 3, AND THE FILE SAYS SO IN ITS OWN WORDS** — *"a restore onto a new device silently lost
every one of them, in the single feature whose stated purpose is that this file is the only copy
that survives losing the phone"*, and for conditions, *"lost PREFERENCE rather than lost records …
But SILENT is the property that matters: nobody would know to restate it."* ⛔ **Both arguments
apply to the vocabulary unchanged, and it was not added.**

⚠️ **NOT PROPOSED AS A FIX HERE, AND THE SHAPE IS NOT OBVIOUS.** Adding vocabulary to the envelope
is a schema 5 change, and merge semantics need deciding: append-only means a restored `is_active:
false` must not silently re-hide an entry the target user has since un-hidden. **That is a design
question, not a serialisation one.**

---

⚠️ **AND A SECOND COPY DEFECT, FOUND IN THE SAME READ AND RECORDED SO IT GETS ITS OWN DECISION
RATHER THAN BEING SWEPT INTO §13(h).** The backup chooser's blurb (`backup_service.dart`, the sheet
opened by `Back up now`) reads:

> *"Saves every event to a file you can share or store. Keep it somewhere off this device."*

⛔ **It is wrong in both directions at once.** It **understates** — the file also carries medication
notes, conditions and the type-to-condition map, which is precisely what schemas 2 and 3 were added
to fix. And it **overstates** — *"every event"* invites the reading that the file is a complete
picture of the app, when the vocabulary is absent.

⭐ **Recorded as a SEPARATE defect from §13(h) on purpose.** §13(h) is the home banner; this is the
sheet the banner opens. **They are two strings, they can disagree with each other, and fixing one
does not fix the other** — but any replacement for §13(h) has to be read against this one, because
a user meets them four seconds apart.

---

### (bb) 🔴 ON WINDOWS THE SHARE PATH DOES NOT CLEAR THE BACKUP COUNTER

**Code-verified, 9 September 2026**, in `services/backup_service.dart`. ⛔ **Behaviour, not copy.
Found while checking the copy for §13(h), and it is not a copy problem.**

    iOS      Share only ("Save to a file" is compiled out)  ->  Share CLEARS it
    Android  Save (to Downloads) or Share                   ->  BOTH clear it
    Windows  Save (file picker) or Share                    ->  ONLY Save clears it

**THE MECHANISM.** `markBackupTaken()` has three call sites. Two are unconditional after a
successful write — `backupSaveAs`'s Android Downloads branch and its desktop file-picker branch. The
third is gated:

    bool backupCountsAsTaken(ShareResultStatus status) => status == ShareResultStatus.success;

⛔ **And `share_plus` reports `unavailable` on Windows, macOS and Linux — the source says so:**
*"Windows, macOS and Linux report `unavailable` — nothing is knowable, so nothing is counted and the
reminder simply keeps running."*

⭐ **SO A WINDOWS USER CAN COMPLETE A SHARE — email the file to themselves, put it in cloud storage
— AND STILL BE TOLD THEY HAVE EVENTS SINCE THEIR LAST BACKUP.** The banner reappears at the next
launch, from the same tenth event, having been actioned.

✅ **THE DESIGN INTENT IS RIGHT AND IS RECORDED IN THE SOURCE**, which is why this is a defect and
not a mistake: *"Invoking the sheet is not evidence of a backup. A user who opens it and cancels
must keep their reminder, not be told they are covered."* ⭐ **Erring toward the reminder is the
correct direction for a safety feature.** The cost is that on desktop it cannot tell a completed
share from a cancelled one, and treats both as cancelled.

⛔ **AND THIS IS THE ACCURATE VERSION OF A CONCERN THAT WAS PREVIOUSLY ASSERTED WRONG.** It was
claimed in briefing that *"the desktop backup counter never clears"* — that the banner is permanent
on Windows from the tenth event. **That was false**, and §13(h) records that it never reached any
file (0 occurrences across `docs/`, `STATUS.md` and `CLAUDE.md`, against a live control).
⭐ **`backupSaveAs` clears it, and the source explicitly says desktop users clear it that way.**
⚠️ **The real defect is narrower and only reachable through one of the two options** — which is why
the wrong version could not be found by looking, and the right one only surfaced from reading both
paths.

⚠️ **NO FIX PROPOSED, and the shape is not obvious.** `ShareResultStatus.unavailable` genuinely
carries no information, so the choices are to count an unavailable status as taken on desktop
(which would mark a cancelled sheet as a backup, the exact thing the guard exists to prevent), to
tell the user on desktop that Share will not clear the reminder (copy, and it contradicts nothing),
or to leave it. ⛔ **All three are decisions, not repairs.**

⚠️ **UNMEASURED: whether macOS and Linux behave as Windows does here.** The source names all three
together, but only Windows is a shipping target and only Windows was reasoned about. ⛔ **Do not
infer the other two from this entry.**

---

### (bc) 🔴 HOME SHOWS THE LOGGING TIME WHERE HISTORY SHOWS THE EVENT TIME — TWO SITES §13(j) NEVER HAD

**Code-verified, 9 September 2026**, by sweeping every read of `r.timestamp` in `lib/` — **25 of
them** — and classifying each by purpose. ⭐ **§13(j) named three sites and got one of them right.
These two are more visible than any of the three.**

| site | what it renders | value used |
|---|---|---|
| **`home_screen.dart:528`** `_daysSinceLastEvent` | the **"Days since"** statistic on home | ⛔ `timestamp` — **days since a record was TYPED** |
| **`home_screen.dart:1915-1919`** `_LastEventCard` | the **"LAST EVENT"** date and time | ⛔ `record.timestamp` — **the logging time** |

⛔ **AND BOTH READ `_records.first`, WHICH IS ORDERED BY `timestamp`.** Home sorts at `:667` and
`:696` on `b.timestamp.compareTo(a.timestamp)`. ⭐ **So "most recent" on home means most recently
LOGGED, not latest event** — and for a backdated record home's "LAST EVENT" may not be the latest
event at all.

⭐ **THE VISIBLE CONSEQUENCE, AND IT IS AN INCONSISTENCY RATHER THAN A DEFINITION QUESTION: the same
record shows one time on home and a different time in History.** History uses `whenHappened`
throughout — the row time (`:250`, `:1160`), the date grouping (`:328`, `:346-347`) and the sort
(`:633`). ⛔ **Two screens, one record, two times.**

⚠️ **History's sort carries the comment that makes this a contradiction rather than an oversight:**

> *"Sorted on the same value the rows display and group by. A list that sorts on one time and
> prints another is the defect the CSV had."*

⭐ **The CSV was fixed for exactly this. History was fixed for exactly this. Home was not.** Home is
internally consistent — it sorts and displays the same value — and inconsistent with **both** of the
other two surfaces that render the same records.

⛔ **THE TWO MUST CHANGE TOGETHER WITH HOME'S SORTS, AND THAT IS NOT A PREFERENCE.** Both read
`_records.first`. **Changing `_daysSinceLastEvent` or `_LastEventCard` alone would compute the right
value from the wrong ordering** — the first element of a `logged_at`-ordered list is not the latest
event. ⚠️ **Three sites, one change.**

⭐ **AND A THIRD, SEPARATE SITE FOUND IN THE SAME SWEEP: `backup.dart:559-560`.** The restore
dialog's `earliest` and `latest` are computed from `r.timestamp`, so **"this backup covers X to Y"
describes the backup's LOGGING span, not the span of events inside it.** ⚠️ **Independent of the
home cluster and independently changeable.**

✅ **WHAT THE SWEEP FOUND CORRECT, recorded so the list is a classification and not a list of
complaints:** both store load sorts and the capture-inbox and iOS-drain sorts (internal ordering,
`logged_at` defensible); every construction site that preserves `timestamp`; and
`event_store_sqlite.dart:322`, which writes `'logged_at': r.timestamp` — **correct by definition.**

⛔ **NO FIX PROPOSED, AND THE HIGHEST-LEVERAGE POINT IS THE ONE NOT TO TOUCH FIRST.** The two
store-level load sorts (`event_record.dart:633`, `event_store_sqlite.dart:432`) define the canonical
order handed to **every** screen, so changing them would fix home's ordering and §13(bd) at one
point. ⚠️ **Every consumer inherits it, and they need enumerating BEFORE that is touched, not
after.** ⭐ **The CSV is already immune — it re-sorts on its own key at `event_record.dart:1117` —
but that is one consumer checked, not all of them.**

⚠️ **PRIORITY DROPPED 9 September 2026: UNEXERCISED on current device data — zero non-null
`occurred_at` across all 58 records, with `duration_seconds` (13/45) and `event_type` (45/13) as
discriminating controls. ⛔ NOT CLOSED — untriggered is not fixed. The full annotation is at the end
of §13(bd).**

---

### (bd) 🔴 HISTORY'S INITIAL ORDER IS `logged_at` — IT SORTS BY ONE VALUE AND GROUPS BY ANOTHER UNTIL THE FIRST EDIT

**Code-verified, 9 September 2026.** ⛔ **In no finding in this document, and it is the defect
History's own comment claims to have fixed.**

**THE THREE READS THAT MAKE IT:**

    initState                        _records = List<EventRecord>.from(widget.records)
                                     — NO SORT. It inherits whatever order it is handed.
    event_record.dart:633            ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
    event_store_sqlite.dart:432      ..sort((a, b) => b.timestamp.compareTo(a.timestamp))
                                     — BOTH stores hand out `logged_at` order.
    the grouping loop (:328, :346)   keys every heading on `r.whenHappened`
    history_screen.dart:633          `whenHappened` — and it runs ONLY after an edit

⭐ **SO ON FIRST OPEN THE LIST IS ORDERED BY `logged_at` AND HEADED BY `whenHappened` DAYS.** The
grouping emits a new date heading whenever the day changes from the previous row, so out-of-order
rows produce **repeated or interleaved date headings** — 20 AUG, 27 AUG, 20 AUG again. ⛔ **And the
order only becomes correct after the user edits something.**

⛔ **THIS IS THE EXACT DEFECT `history_screen.dart:633`'s COMMENT SAYS IT FIXED:**

> *"Sorted on the same value the rows display and group by. A list that sorts on one time and
> prints another is the defect the CSV had."*

⭐ **THE FIX LANDED ON THE POST-EDIT PATH AND THE COMMENT CLAIMS THE CLASS.** That is the
propagation pattern of `C:\dev\CLAUDE.md`'s *local correctness does not propagate* — **occurring
INSIDE ONE FILE, twenty lines from the comment asserting it.** ⚠️ **Not a distant document that was
not read: the same author, the same screen, the same sitting.** ⛔ **Proximity is not propagation,
and neither is a correct comment.**

⚠️ **CODE-VERIFIED AND UNEXERCISED — and those are two different claims, so both are stated.**
Nothing in this repository or in any off-device data has ever triggered it, because no record
carries a non-null `occurredAt` (see below). ⭐ **It is not hypothetical. It is UNTRIGGERED** — the
code path is wrong today and the data has not yet asked it the question.

⛔ **NOT TESTED, and deliberately: this pass was read-only.** A test would need a record whose
`logged_at` and `occurredAt` orders disagree, which is the same fixture the measurement below
cannot obtain.

---

**⛔ WHY NONE OF THIS CLUSTER IS MEASURABLE YET — this covers §13(j), §13(bc) AND this finding.**

**The only off-device data is the `MER Device Baselines` set: three JSON backups, 27 August 2026,
72 records each, `schemaVersion 1`, app `1.1.0+40`.** Measured 9 September 2026.

⛔ **`occurredAt` IS ABSENT FROM EVERY RECORD.** The 14 keys present are `detailsCompleted`,
`duration`, `durationSeconds`, `eventType`, `feelings`, `id`, `notes`, `referralRequired`,
`rescueMedGiven`, `rescueMedHelped`, `rescueMedSecondDose`, `severity`, `timestamp`, `triggers`.
✅ **Positive control: `timestamp` non-empty on 72 of 72, so the parse works and the null is real.**

⚠️ **"ABSENT" IS NOT "ZERO", AND THE DISTINCTION DECIDES WHAT CAN BE CLAIMED.** `toMap()` writes
`'occurredAt'` **including as null** — the same always-written rule as `severity` — so a
present-but-null field would still appear as a key. ⭐ **It does not appear at all, which means the
field did not exist in the model on 27 August. The question was never asked of this data**, rather
than asked and answered zero.

⛔ **AND EVERY MIGRATED RECORD HAS IT NULL BY DESIGN.** `DATA-MODEL.md` on the migration:
*"`timestamp` → `logged_at`. **`occurred_at` stays NULL** — the old value was log time, and
pretending otherwise fabricates data."* ⚠️ **`backup.dart:437` says the same forward: "Revisit when
occurred_at is populated by the expansion."**

✅ **It IS user-writable on both edit paths** — `event_wizard_screen.dart:273` and
`log_event_screen.dart:380` — so §4's *"backdating exists, is well built, and is buried"* holds.

⭐ **SO EVERY DIVERGENCE IN THIS CLUSTER IS REAL IN CODE AND UNEXERCISED IN ALL OFF-DEVICE DATA.**
The distribution, the different-month count and the sort-order difference are **UNMEASURABLE from
what exists**, not measured as nil.

⛔ **MEASURING THEM NEEDS A CURRENT DEVICE READ, WHICH MAKES THIS A MAC ITEM BESIDE §13(ax)'s 59 →
58 RECONCILIATION.** ⭐ **They share an instrument:** both need a database copied off a device and
counted, both were blocked in the same way, and one trip answers both. ⚠️ **Neither is a Windows
item and neither should be attempted from here.**

---

**⛔ PRIORITY DROPPED 9 September 2026 — THE CLUSTER IS NOW MEASURED, AND IT IS UNEXERCISED. This
covers §13(j) (including `_thisMonthCount`), §13(bc) AND §13(bd).**

⭐ **THIS IS AN UPGRADE IN THE CLAIM, AND THE CHANGE IS THE POINT.** The section above says the
cluster is **UNMEASURABLE from what exists, not measured as nil** — because on the 27 August
baselines `occurredAt` was **absent as a key**, so the question had never been asked of that data.
⚠️ **It has now been asked.** A current device read of the 58 records reports **ZERO non-null
`occurred_at`.**

✅ **AND IT CARRIES DISCRIMINATING CONTROLS, which is what makes the zero a measurement rather than
an apparatus failure:**

    duration_seconds     13 populated / 45 null
    event_type           45 populated / 13 null
    occurred_at          0 populated / 58 null

⭐ **Two fields in the same read return MIXED distributions, so the query can distinguish populated
from unpopulated. The zero is real.** ⚠️ **Mac-reported, not verified from Windows.**

⛔ **SO EVERY DIVERGENCE IN THIS CLUSTER IS REAL IN CODE AND UNEXERCISED ON CURRENT DEVICE DATA.**
Nothing on the device has yet asked home's statistics, the `_LastEventCard` time, `_thisMonthCount`
or History's initial order to disagree with `logged_at`, because on all 58 records
`whenHappened == timestamp` by definition of the fallback.

⚠️ **NONE OF THESE IS CLOSED, AND UNTRIGGERED IS NOT FIXED.** The code paths are wrong today. ⭐ **The
first backdated record makes all four visible at once** — and backdating is user-writable on both
edit paths, so this is a matter of when, not whether. ⛔ **The measurement lowers the priority. It
does not change the verdict.**

---

### (be) 🔴 ONE EVENT RECORD WAS LOST ON 30 AUGUST 2026 — UNRECOVERABLE, AND THE STORAGE MODEL CANNOT SAY HOW

⛔ **THE HIGHEST-PRIORITY OPEN ITEM IN THIS DOCUMENT.** Recorded 9 September 2026. ⛔ **ONE EVENT
RECORD WAS LOST ON 30 AUGUST 2026, IN THE WRITE AT 16:36:41 AEST. UNRECOVERABLE.**

**Nine of the ten tables are identical between the 14:50:33 count and now. `event` alone is minus
one.** Seven device copies are one state, byte-identical, sha256 `e6366d33`. `mer_last_backup_at`
(`constants.dart:179`, `kLastBackupKey`) is **24 August**, so **no backup covers the 59 state.**

⭐ **WHAT SETTLED IT WAS THE SESSION TRANSCRIPT, NOT THE DATABASE.** The database cannot answer the
question at all — see the mechanism below. The count of 59 exists only because a transcript recorded
it in passing.

---

**⚠️ PROVENANCE, STATED BEFORE ANY OF IT IS RELIED ON.** The device measurements in this finding were
taken on the **Mac** and are recorded here **as reported, not as verified from Windows.** What is
marked ✅ **WINDOWS-VERIFIED** below was read from source in this repository on 9 September 2026 and
is independent of that report. ⛔ **The distinction is load-bearing: this document has twice recorded
a Mac-reported figure as though Windows had measured it.**

---

**⛔ THE BENIGN READING IS FALSIFIED. No store holds 59.**

| store | count |
|---|---|
| SQLite `event` | **58** |
| `SharedPreferences` (pre-SQLite key) | 42 |
| iOS App Group mirror | **empty** |
| pre-SQLite store | 42 |
| a fresh read, 9 September 2026 | **58** |

⭐ **So the record is not misplaced, unmigrated or stranded in a mirror. It is gone.**

---

**⛔ THE WRITE DID NOT COME FROM THE CLI.** 280 transcript entries cover **14:50:33 to 15:41:49**. A
**55-minute gap** follows. **16:36:41 falls inside it — 16 seconds before the transcript resumes.**
The covered window shows **simulator** work: no `devicectl install`, no app launch on the iPhone.
⭐ **The write came from the app on the phone during a blind period. That is an answer, not a
shortfall** — it excludes the tooling and locates the actor.

---

**⛔ THE TRACE-ERASING MECHANISM — ✅ WINDOWS-VERIFIED FROM SOURCE, 9 September 2026.**

    event_store_sqlite.dart:441-451   save() is REWRITE-EVERYTHING, in ONE transaction:
                                        :444   await txn.delete('event')
                                        :447   batch.insert('event', eventToRow(snapshot[i], i))
    event_store_sqlite.dart:319-320   eventToRow writes 'ordinal': ordinal — THE LOOP INDEX
    lib/ grep                         deleteEvent | removeEvent | deleteById | deleteRecord
                                        — ZERO hits. NO PER-RECORD DELETE EXISTS.
    event_store_sqlite.dart:461       the only other event delete is clearAll(), the reset path

⭐ **A record leaves this store by not being in the list that gets written.** So a deletion leaves
**no row, no flag, no log, no Sentry event, no ordinal gap and no freelist residue.** ⛔ **The
storage model is incapable of saying afterwards that a record ever existed.**

---

**⛔ BOTH FORENSIC TESTS WERE RUN AND BOTH ARE VOID. ✅ Both voidings are WINDOWS-VERIFIED.**

| test | result | why it proves nothing |
|---|---|---|
| dense `ordinal` sequence | no gaps | ⛔ `ordinal` is **reassigned from list position** on every write (`:319-320`). A dense sequence is guaranteed, not evidence |
| `freelist_count` | 0 | ⛔ pages are freed and reused **wholesale** by the delete-and-reinsert, so 0 is the expected value either way |

⭐ **THE GAP QUERY'S CONTROL FIRED ON 997/998/999, SO THE APPARATUS WORKED AND THE QUESTION WAS
WRONG.** ⚠️ **That is the §13(az) shape again, and it is the second instance: the instrument was
sound, the input could not carry the answer.** Recorded because a working control on a void test is
the most persuasive wrong result available.

---

**⛔ THE TIMESTAMP CANNOT BE BOUNDED.** A reading of **51 at 27 August 20:13** does not bracket the
loss: **52 current records predate that reading**, and `51 + 6 = 57`, not 59. ⭐ **Backdated inserts
were occurring, and merge-by-id preserves original timestamps** (`ios_capture_bridge.dart:243-247`
rebuilds with `timestamp: existing.timestamp` — ✅ Windows-verified). **So the lost record may carry
any timestamp**, and no date-range reasoning about it is admissible.

---

**⭐ THE CANDIDATE MECHANISM SET — ✅ WINDOWS-VERIFIED, AND WIDER THAN A DELETION.**

**Every write to the table funnels through exactly ONE call:** `event_record.dart:750`, inside
`persistEvents` (`:748`). **It has five call sites in three files:**

| entry point | user action required? |
|---|---|
| `home_screen.dart:490`, `:499`, `:669` | the app's own list writes — add, edit, delete, sort |
| `capture_inbox.dart:369` | ⛔ **NONE.** A drain merge writes `plan.merged` |
| `ios_capture_bridge.dart:292` | ⛔ **NONE.** The iOS drain writes `merged` |

⛔ **THE DEVICE IS AN iPHONE, SO THE iOS DRAIN IS LIVE ON IT — AND THE App Group MIRROR IS NOW
EMPTY, WHICH IS WHAT A DRAIN THAT RAN LEAVES BEHIND.**

⛔ **AND BOTH MERGE PATHS SILENTLY DE-DUPLICATE BY id:**

    ios_capture_bridge.dart:211    if (byId.containsKey(r.id)) continue;
    capture_inbox.dart:121         if (byId.containsKey(record.id)) continue;
    ios_capture_bridge.dart:272    merged ..addAll([for (final id in order) byId[id]!])
    capture_inbox.dart:256         final merged = [for (final id in order) byId[id]!]

⭐ **A record whose id already appears is DROPPED, not merged, and the written list is one shorter
with no user action anywhere in the path.**

⛔ **AND THE SCHEMA PERMITS THE DUPLICATE THAT WOULD TRIGGER IT: `event_store_sqlite.dart:90` declares
`id TEXT NOT NULL` — NOT `PRIMARY KEY`, NOT `UNIQUE`.** ⚠️ **So the merge-by-id semantics the whole
app rests on are an unenforced assumption, and the dedup branch is live code rather than a dead
guard.**

⛔ **CORRECTED 9 September 2026 — "AN UNENFORCED ASSUMPTION" IS WRONG, AND IT IS THIS DOCUMENT'S OWN
RECURRING ERROR.** The sentence above stays as written. **The missing constraint is a DOCUMENTED
DELIBERATE DECISION, stated at `event_store_sqlite.dart:76-85` in its own words:**

> *"`id` is NOT a PRIMARY KEY, and that is deliberate. The old store is a JSON array, which permits
> duplicate ids. Making id unique here would make a duplicate an INSERT failure — turning 'this
> device has two records sharing an id' into 'the migration lost records', which is the exact
> outcome this build exists to rule out. Duplicates are carried across and counted into
> `migration_distinct_ids` instead, so the question is answered on the device rather than decided
> here."*

⛔ **SO THE FINDING ABOVE PRESENTED AS AN OVERSIGHT WHAT THE SOURCE PRESENTS AS A DECISION — with the
alternative named, the failure mode stated, and a measurement put in its place.** ⚠️ **Same class as
§13(j) on the CSV and `ARCHITECTURE.md` row 2 in §13(n), and this is the third instance.** ⭐ **The
mechanism survives and the characterisation does not:** the dedup branch **is** live code, a
duplicate id **would** be dropped rather than merged, and the schema **does** permit the duplicate.
⛔ **What is retracted is the implication that nobody had considered it.**

⚠️ **AND THE DECISION IS THE STRONGER ARGUMENT AGAINST THE OBVIOUS REPAIR.** ✅ **Windows-verified:
`batch.insert` at `:447` passes no `conflictAlgorithm`**, so the statement carries no `ON CONFLICT`
clause and SQLite's default **ABORT** applies. The insert throws, `save()`'s single transaction rolls
back — including its own `txn.delete('event')` — and `persistEvents` catches, reports to Sentry and
raises the unsaved-events warning. ⛔ **So adding `UNIQUE` today would convert a silent one-record
drop into a total failure to save the ENTIRE list.** ⭐ **That is strictly worse, and it is precisely
the outcome `:76-85` says the absence exists to prevent.**

⚠️ **THIS IS A CANDIDATE, NOT THE CAUSE, AND IT IS NOT OFFERED AS ONE.** It is recorded because it is
the first mechanism found that produces a **silent one-record loss with no deliberate act**, and
because it was absent from the enumeration this finding was briefed from. ⛔ **It leaves no trace
either, so it cannot be confirmed or excluded from the device.** ⚠️ **Do NOT let it become the
explanation** — that is precisely the available-explanation bias already recorded against this
project, where a known defect was accepted as the cause of three unrelated failures.

⚠️ **One qualifier on the deletion reading, ✅ Windows-verified and cutting both ways:** History's
delete is **confirmed by a dialog** — `history_screen.dart:589` guards on `confirm != true` — before `removeWhere` at `:591`
and `onRecordsChanged` at `:592`. **So it is a two-tap sequence, not a single stray tap** — which
weakens the accidental-tap reading without excluding it, and does not touch §13(ab)'s density
argument at all.

---

**⚠️ INFERRED RATHER THAN READ, AND FLAGGED AS SUCH:**

  · **which code path removed the record** — five candidate call sites, nothing distinguishing them
  · **whether a deletion was deliberate**
  · **the record's identity, timestamp and contents** — ⛔ **unrecoverable.** Transcripts recorded
    **counts, never ids.**

---

**⚠️ THE CONVERGENCE, RECORDED WITHOUT OVERCLAIMING.** The session that lost a record is the same
session that recorded History's unlabelled delete control as a finding. ⛔ **That is a coincidence of
subject matter, not evidence.** A trash tap fits the facts; so do other paths; **nothing
distinguishes them**, and the storage model guarantees nothing ever will.

---

**⛔ CROSS-REFERENCE §13(ab), WHICH CHANGES CHARACTER TODAY.** §13(ab) records **eleven unlabelled
destructive controls per screen, 25 px apart, announcing nothing** until the labels landed on
9 September 2026. ⭐ **It was a question about density. It is now a question about density in a system
with no audit trail** — where the affordance is dense, was silent, and the storage cannot say
afterwards whether one was pressed.

---

**⛔ WHAT THIS FINDING DOES NOT LICENSE.** No storage-model change is proposed here and none should be
attempted from this finding alone. ⚠️ **The obvious repairs — a per-record delete, a tombstone, an
`id` uniqueness constraint, an audit log — each change the write path that every screen and both
drains depend on**, and §13(bc) already records why the store-level surface needs its consumers
enumerated **before** it is touched, not after. ⭐ **The one thing that is safe and not yet done is
preserving the evidence**, below.

---

**⚠️ THE EVIDENCE, AND IT IS THE ONLY PROOF THE 59 STATE EXISTED. Mac-reported paths and hashes:**

| artefact | detail |
|---|---|
| session transcript | `OneDrive/Projects/App Dev/Claude/MER Device Baselines/EVIDENCE 2026-08-30 session transcript (59-record state)` |
| its hash and size | sha256 `9aac0a4f…aad58`, **7,800,641 bytes** |
| a separate extract | **8,436 bytes** |
| second copies | `~/Downloads` on the Mac |

🔴 **AND A LIVE GAP, ✅ WINDOWS-VERIFIED THE SAME DAY: NONE OF IT HAS REACHED WINDOWS.** That folder
holds **12 files, every one dated 27 August 2026**, and a case-insensitive search for `EVIDENCE`
returns **zero**. ⚠️ **Three readings and this finding picks none of them:** OneDrive has not yet
propagated it; it was written to a local path that is not inside the synced folder; or sync is
stalled. ⛔ **Until one of those is settled, the only evidence that the 59 state ever existed is on a
single machine** — which is this workspace's own decoy-backup lesson, on the artefact that documents
an unrecoverable data loss. **Verify it from the Mac and confirm the upload, rather than assuming the
path implies it.**

---

**✅ ARRIVAL, MEASURED ON WINDOWS 9 September 2026 — THE EXTRACT NOW TRAVELS BY `git push`. The
citation above is repaired here rather than rewritten.**

⭐ **THE EXTRACT IS IN THIS REPOSITORY: `docs/EVIDENCE-2026-08-30-59-record-reading.txt`** —
**8,436 bytes, 116 lines,** sha256
`185a12703f5c3caec87e69ec35d7a6653dce3ef54bc6e8c2d3b0939094c8f73c`. **All three match the expected
values exactly.** ✅ **And the OneDrive copy is byte-identical to it** (`cmp` clean, same sha256),
mtime 9 September 18:58 — so OneDrive did propagate the extract.

⛔ **THE 7,800,641-BYTE TRANSCRIPT DID NOT ARRIVE, AND THIS REMAINS UNRESOLVED.** ✅ **Windows-verified
null with a positive control:** zero files over 1 MB in that folder, and zero name matches for
`*session transcript*` anywhere under `OneDrive/Projects/App Dev/Claude`, while the same search shape
for `*EVIDENCE*` returns **1**. ⭐ **So the apparatus works and the absence is real.**

⛔ **THE FULL TRANSCRIPT THEREFORE EXISTS ON ONE MACHINE, IN TWO LOCATIONS ON IT** — the Mac's
OneDrive folder and the Mac's `~/Downloads`. ⚠️ **Two copies on one disk is one failure away from
none.** **The 8,436-byte extract is now genuinely redundant across machines; the 7.8 MB transcript is
not, and nothing in this repository can make it so.**

**⚠️ THE FOLDER-COUNT DISAGREEMENT, RESOLVED AGAINST THIS DOCUMENT.** The entry above reports
**"12 files, every one dated 27 August"** at a moment when the Mac reported 11 pre-existing. ⛔ **The
Mac was right and this document was wrong: there were ELEVEN.** Re-enumerated today with a
space-safe `find` and an explicit count: **12 files now — the 11 pre-existing plus the arrived
extract**, 0 subdirectories, 0 hidden entries. ⭐ **There is no unidentifiable extra file, and there
never was one. It was a miscount here**, and it is recorded rather than quietly corrected because a
count asserted against another machine's count is exactly the kind of figure this audit has twice
been wrong about.

⚠️ **AND "THE FOLDER IS IN SYNC" WAS NEVER ESTABLISHED AND STILL IS NOT.** One of two files arrived.
⛔ **A folder that delivered the small file and not the large one is not a folder that has been shown
to work** — it is consistent with propagation still in progress, with a size-related stall, or with
the large file never having been placed inside the synced tree. **None of the three is excluded, and
the earlier entry's three readings stand unresolved.**

---

**⛔ IS THE DUPLICATE-ID MECHANISM LIVE? TESTED 9 September 2026 — AND THE ANSWER IS NEITHER
PROMOTED NOR RETIRED, FOR A REASON WORTH RECORDING.**

**What was measurable on Windows: the three 27 August tablet envelopes only.**

    per envelope           72 records, 72 DISTINCT ids, schemaVersion 1
    duplicates WITHIN      0, in all three
    ids in all three       72 of 72
    same id, differing     0
      content across them
    CONTROL id non-empty          72/72
    CONTROL timestamp non-empty   72/72
    CONTROL mixed-null field      durationSeconds 1 populated / 71 null
    CONTROL comparator            detects an INJECTED diff: TRUE

⛔ **BUT THE CROSS-ENVELOPE TEST HAD NO POWER, AND THAT IS THE FINDING RATHER THAN THE ZERO.** The
three envelopes differ **only** in `exportedAt` and `appVersion` (`1.1.0+38`, `+38`, `+40`); their
`records` arrays are **identical**. ⭐ **So "no duplicate id with differing content across the
stores" was guaranteed by construction — three exports of one device's unchanged store, taken hours
apart with no edit between.** ⚠️ **This is the guaranteed-to-pass sample that `C:\dev\CLAUDE.md`
already records from the melliform backup**, and it was caught only by hashing the three and
diffing their record arrays rather than trusting that three files meant three states.

**⛔ WHAT IS NOT MEASURABLE FROM WINDOWS, AND WHY — both are MAC ITEMS:**

| question | blocked on |
|---|---|
| **(a)** any duplicate id among the current 58 | no SQLite copy on this machine |
| **(c)** do the 37 shared tablet/iPhone ids differ in any other field | no iPhone id list on this machine — the 58, the prefs 42 and the pre-SQLite 42 are all absent here |

⚠️ **AND THE ZERO THAT WAS MEASURED DOES NOT RETIRE THE CANDIDATE.** A dedup that has already fired
leaves **no** surviving duplicate, so "none survives now" is exactly what both the innocent and the
guilty case look like. ⛔ **Recorded as no surviving duplicate in the tablet envelopes, not as
absence of the mechanism.**

---

**⭐ AND THE TEST FOUND SOMETHING BETTER THAN ITS OWN ANSWER: THE DEVICE ALREADY HOLDS A PERSISTED
DUPLICATE DETECTOR, AND NOBODY HAS READ IT.** ✅ **Windows-verified from source.**

`schema_meta` (`event_store_sqlite.dart:58-71`) carries, written by
`storage_migration.dart:247-256`:

    migration_source_count      records in the OLD store at migration
    migration_inserted_count    rows actually inserted
    migration_distinct_ids      DISTINCT ids among them
    migration_absent_<field>    per-field absent counts
    migration_backup_path       the path of a pre-migration backup
    migration_state             'migrated' | 'failed_verification'

⛔ **`storage_migration.dart:56-58` states the comparison outright: distinct ids "below
[insertedCount] means the device" carried duplicates.** ⭐ **So the question "did this device ever
hold duplicate ids" has a persisted, on-device answer, computed at migration and never overwritten**
— and it is the **first store-level forensic artefact in this investigation that is not void.**
⚠️ **It bounds the migration state (42 records), not the 59 state, so it cannot recover the lost
record** — but it is the difference between the duplicate-id candidate being untestable and being
merely unread.

🔴 **AND A NEVER-DELETED PRE-MIGRATION BACKUP EXISTS ON THE DEVICE.** `storage_boot.dart:119-125`
writes it **before anything is touched**, into the application documents directory, and its own
comment says it **"is never deleted"**; the path is persisted as `migration_backup_path`. ⚠️ **It
holds the pre-SQLite state, so it is not a copy of the 59 state and will not recover the record.**
⭐ **It has never been retrieved, and its path is recorded in the database that is already being read
on the Mac.**

⛔ **NOT RETRIEVED, NOT READ, AND NOT ATTEMPTED FROM HERE.** ⚠️ **Reading `schema_meta` and pulling
that backup are the two cheapest unrun measurements in this investigation, and both are Mac items
beside §13(ax)'s reconciliation and the `occurredAt` cluster.**

---

**⭐ NARROWED 9 September 2026 — THE LOST RECORD WAS ONE OF THE 17 POST-MIGRATION ADDITIONS.**

**READ, not inferred: all 42 pre-migration ids are present in the current 58 — 0 missing, with a
discriminating control.** ⚠️ **Mac-measured.**

    42 pre-migration ids       42 of 42 present in the current 58
    missing                    0
    so at 30 August            59 = 42 + 17
    surviving post-migration   16
    therefore lost             ONE OF THE 17 POST-MIGRATION ADDITIONS

**The 16 survivors are all 27 August, spanning 18:40:09 to 21:19:47.**

⛔ **THIS DOES NOT IDENTIFY THE RECORD, AND THE 17th's TIMESTAMP IS NOT RECOVERABLE.** ⭐ **It removes
a whole class instead: the pre-migration 42 are all accounted for, so nothing was lost from the
migrated body of records.** ⚠️ **The narrowing is a set exclusion, not a candidate. Nothing here
bounds when the 17th was written, what it contained, or which of the five write paths removed it** —
and §13(be)'s unbounded-timestamp note still governs, because the 16 survivors' range says nothing
about the one that is gone.

---

**✅ THE PRE-MIGRATION BACKUP IS VERIFIED PRESENT, and `storage_boot.dart`'s "never deleted" HOLDS.**
⚠️ **Mac-measured.**

    size            8,796 bytes
    sha256          47dd9a62…a91b
    records         42  — matching migration_source_count exactly
    survived        two reinstalls and fifteen days

⭐ **A claim in a comment turned out to be true of a real file on a real device after two reinstalls.**
⛔ **It is still not a copy of the 59 state and cannot recover the lost record** — it predates the 17
additions by definition. **What it does is convert §13(be)'s "never retrieved" into "retrieved and
intact", and confirm that the one deliberately permanent artefact in this storage model behaves as
documented.**

---

**⛔ AND THE DEAD PROBE — THE FIFTEENTH APPARATUS FAULT IN THIS AUDIT, AND THE HIGHEST-STAKES ONE
YET.** The first container listing **returned nothing, and its own control ALSO returned 0** — which
is impossible for a live listing, because the control term is present by construction.
**`CoreDeviceService` could not locate the device at all.**

⭐ **THE FAILURE MODE IS THE ONE THIS DOCUMENT KEEPS RECORDING: a null that is indistinguishable from
a real absence.** ⛔ **Trusting it would have reported a file the source documents as NEVER DELETED as
ABSENT — on a forensic question about data loss.** ⚠️ **The consequence would not have been a wrong
number. It would have been "the permanent backup is gone too", which is a conclusion about the
integrity of the storage model itself, drawn from an apparatus that was not connected.**

⭐ **IT WAS CAUGHT BY THE CONTROL AND BY NOTHING ELSE.** The listing looked like a clean empty
directory. **This is the fifteenth such fault across three days and not one has been a real
absence** — which is now a strong enough base rate to state as a rule rather than a caution:
⛔ **in this investigation, an unqualified null is an apparatus report until its control says
otherwise.**

---

**⭐ `schema_meta` HAS BEEN READ, AND WHAT IT DOES NOT SAY MATTERS MORE THAN WHAT IT DOES.**
⚠️ **Mac-measured, 9 September 2026.**

    migration_source_count    42
    migration_inserted_count  42
    migration_distinct_ids    42
    migration_state           migrated

⭐ **42 / 42 / 42. Per `storage_migration.dart:56-58`'s own definition — distinct below inserted means
duplicates — there was NO DUPLICATE id among the inserted rows.**

⛔ **WHAT IT SUPPORTS, STATED PRECISELY: the 42 records present at 25 August 20:40:07 carried 42
distinct ids. THAT IS ALL.** ⚠️ **It is NOT "no duplicates ever."** It is **silent about the 17
records added afterwards** and **silent about 30 August**, because ✅ **it is written once at
migration and never updated** (`storage_migration.dart:247-256`, inside the one-time branch guarded
by `migration_state == 'migrated'` at `:196`). ⭐ **So the one persisted duplicate detector in this
storage model stops measuring at exactly the point the interesting period begins.**

**⚠️ ALL `migration_absent_*` COUNTS ARE 0 — AND THE DENOMINATOR DISAGREES WITH TODAY'S SOURCE.** The
report gives **eight** keys at zero. ✅ **Windows-verified: `kMigratedOptionalKeys`
(`storage_migration.dart:77-87`) holds NINE — `id`, `duration`, `durationSeconds`, `eventType`,
`severity`, `feelings`, `triggers`, `notes`, `referralRequired` — and `:250-251` writes one row per
key in that list.** ⛔ **So today's source would write nine rows and the device reportedly has eight.**

⚠️ **TWO READINGS AND THIS ENTRY PICKS NEITHER:** the list had eight entries in the build that ran the
migration on 25 August and has since gained one, in which case both figures are correct and neither
is an error; or a row is genuinely missing. ⭐ **Recorded because "all of them are zero" is
unfalsifiable without its denominator, and the denominator is build-dependent** — which makes this
the same stale-figure class §13(r) collects, arriving through a count rather than a citation.

**⚠️ `skipped = 0` IS INFERRED, NOT READ.** It follows from `verified = inserted == loadableCount`
(`storage_migration.dart:245`) together with the persisted `migrated` state — ⛔ **but
`loadableCount` is NOT stored in `schema_meta`.** ⭐ **So the inference is sound only if the
verification's own inputs were what the code says they were, and that cannot be re-checked from the
persisted rows.** **Flagged rather than promoted.**

---

**⛔ THE DUPLICATE-ID TEST ON THE CURRENT 58: ZERO — AND THE APPARATUS DISCRIMINATES ON THAT EXACT
DATA.** ⚠️ **Mac-measured.**

    duplicate ids among the 58     0
    CONTROL event_type             45 -> 1 distinct
    CONTROL severity               45 -> 2 distinct
    CONTROL duration_bucket        42 -> 3 distinct

⭐ **Three controls returning small distinct counts over the same 58 rows, so the query can see
repetition where repetition exists. The zero is a measurement.**

⛔ **AND IT MEANS NO DUPLICATE *SURVIVES*, WHICH IS PRECISELY WHAT A DEDUP THAT ALREADY FIRED LEAVES
BEHIND.** ⚠️ **The candidate is NOT retired.** ⭐ **Both the innocent and the guilty case predict this
exact result, so the measurement cannot separate them** — and no measurement taken after the fact
can, because the mechanism removes its own evidence.

⚠️ **THE POWERLESS CROSS-ENVELOPE TEST IS ALREADY RECORDED ABOVE** — the three tablet envelopes'
`records` arrays hash identically, so Windows' comparison had zero power and its zero was guaranteed
by construction. ⛔ **Not restated here, so the finding is not double-counted as two pieces of
evidence.**

---

### (bf) 🔴 THE SAME id HOLDS DIFFERENT CONTENT ON THE TWO DEVICES, AND RESTORE PICKS A WINNER WITHOUT LOOKING

**Recorded 9 September 2026.** ⛔ **Three of the 37 shared ids differ in `feelings_json`. The iPhone
holds `['😵 Confused']`; the tablet holds the same emoji's UTF-8 bytes DOUBLE-ENCODED — mis-decoded
as latin-1, then re-encoded.** The ids: **`1c3acb1b`, `2cba7cd2`, `6712EAD0`.**

✅ **THE TABLET HALF IS WINDOWS-VERIFIED FROM THE 27 AUGUST ENVELOPES, NOT TAKEN ON REPORT.** All
three ids were located and all three carry the corrupt value:

    stored value        'ð\x9f\x98µ Confused'
    its UTF-8 bytes     c3 b0 c2 9f c2 98 c2 b5 20 43 6f 6e 66 75 73 65 64
    latin-1 -> utf-8    REPAIRS TO '😵 Confused'
    ids matched         3 of 3

⛔ **AND THE FILE IS NOT THE PROBLEM: it decodes as STRICT UTF-8, carries NO BOM, and the difference
survives an explicit UTF-8 re-read.** ⭐ **The CLI's first reading of this blamed its own decoder and
was wrong.** The bytes above are the UTF-8 encoding of U+00F0 U+009F U+0098 U+00B5 — which are
precisely the latin-1 readings of `f0 9f 98 b5`, the real UTF-8 for `😵`. **The corruption is in the
stored data.**

⚠️ **The iPhone half — that its copy is CLEAN — is Mac-reported and not verified from Windows.** The
iPhone's 58 records are not on this machine.

---

**⭐ THE MERGE CONSEQUENCE IS LIVE, NOT HYPOTHETICAL — AND ✅ WINDOWS-VERIFIED FROM SOURCE.** Restore
is **merge-by-id, add-only, existing wins**:

    backup.dart:494    existingIds = existing.map((e) => e.id).toSet()
    backup.dart:514    if (record.id.isNotEmpty && existingIds.contains(record.id))
    backup.dart:515      alreadyPresent++            <- counted, NOT compared
    backup.dart:553    merged = [...existing, ...additions]
    backup.dart:397    "That is existing-wins working as designed"

⛔ **THE INCOMING RECORD'S CONTENT IS NEVER INSPECTED.** The id matches, a counter increments, and the
whole record is discarded. ⭐ **So one of the two values is kept and one silently dropped, and which
one survives is decided ENTIRELY by which device is being restored INTO — never by which value is
correct.** Restore the tablet from an iPhone backup and the clean value is discarded and the
corruption persists; restore the other way and the corruption is what gets dropped. **All three ids
sit in the shared lineage, so both directions are reachable.**

---

**⛔ NOT "CONSISTENT WITH" — CONFIRMED. THE FAMILY WAS ENUMERATED, AND THIS DEPARTS FROM THE BRIEF
DELIBERATELY.** The brief directed that this be recorded as *consistent with, not confirmed as*,
`vocabulary.dart:1142`'s `isMisdecodedTwin` family, **because `mangledLegacyObservations()` had not
been enumerated.** ⭐ **That blocking condition was removable from Windows, so it was removed rather
than recorded around.**

✅ **The enumeration:** `mangledLegacyObservations()` (`vocabulary.dart:622-634`) derives its seeds
from `kLegacyObservations` (`:275-287`, eleven entries) by applying `latin1Mangled()`, which encodes
each rune to UTF-8 and then reads those bytes back as code points — **exactly the transformation
measured above.** `'😵 Confused'` is entry six of that list (`:282`). ⛔ **So the corrupt value is a
SEEDED vocabulary row, `isActive: false`, with a clean sibling carrying an identical label.**

⛔ **AND THE SOURCE ALREADY NAMES BOTH THE CASE AND THE COUNT.** `vocabulary.dart:19`:
*"The three records carrying `😵 Confused` keep that exact string."* `:1315-1317` classifies it
explicitly as **"LEGACY, MIS-DECODED"**, and `:1419` calls it *"a Latin-1 mis-decode of an emoji."*
⭐ **Three records is what the source says, three is what the brief reports, and three is what this
machine found. The count is corroborated from three independent directions.**

⚠️ **SO THE RENDERING IS HANDLED AND THAT IS NOT THE DEFECT.** A twin row exists precisely so a
corrupt record renders a readable label. ⛔ **WHAT IS NOT HANDLED IS THE MERGE:** nothing in
`mangledLegacyObservations()` or `isMisdecodedTwin` participates in restore, and `backup.dart:514`
does not consult them. **The vocabulary layer makes the corruption legible; it does not make the
merge choose correctly.**

---

**⚠️ THE id-CASE CORROBORATION, recorded as reported.** **30 uppercase (Swift-written) versus 28
lowercase (Dart-written) on the iPhone, and all 28 Dart-written ids are shared with the tablet.**
⛔ **Mac-reported: the iPhone id list is not on this machine and this cannot be checked here.**

✅ **What Windows can add, on the tablet's 72: 9 ids contain uppercase, 63 are all-lowercase**, with
both classes non-empty as the control. ⚠️ **A different device and a different denominator, so it
neither confirms nor contradicts the 30/28 split** — recorded so the two figures are not later
mistaken for one measurement.

⭐ **The case split is a provenance marker, and that is why it matters here:** it separates records
written by the native Swift path from those written by Dart, and `(be)`'s candidate mechanism set
turns on exactly which writer produced a row.

---

⚠️ **UNRESOLVED AND DELIBERATELY SO — recording only, per the brief. No merge change, no dedup
change, no repair of the three values.** ⛔ **And a repair is not obviously safe:** the corrupt string
is the stored `value` that attaches those records to a vocabulary row, and `vocabulary.dart:648`
states that `value` **"is never touched, by anything, ever — that is what keeps records attached to
their entry."** ⭐ **So the obvious fix collides with a stated invariant, and belongs in the same
enumerate-the-consumers queue as §13(bc)'s store-level sorts.**
