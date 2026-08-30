# MER — Design Audit: 430×932 Description

**Written 31 August 2026, AEST.** Descriptive record of the 22 layouts captured at iPhone
15 Pro Max logical width, for a reader who cannot see the images.

---

## ⛔ READ THIS FIRST: WIDTH PROXIES, NOT iOS SCREENSHOTS

Every image described here was rendered by **Android on a Teclast P30 tablet** with the display
overridden to an iPhone's logical size. **They reproduce logical width, and therefore wrapping
and layout.** They reproduce **nothing** about iOS — not fonts, not safe-area insets, not the
Dynamic Island, not chrome.

⚠️ **A reader who mistakes these for iOS captures will draw a wrong conclusion from a correct
file.**

## Provenance

| | |
|---|---|
| Device | Teclast P30 (`P30_ROW`), **Android 15** |
| Physical | 800 × 1280, 160 dpi (mdpi, so **1 dp = 1 px**) |
| Override | `wm size 430x932`, auto-rotate disabled, portrait locked |
| Capture set | **`715ca95`**, `docs/design-audit/captures/` |
| Captured | 30 August 2026, AEST |

**Database state, verified at capture time:** 72 records, 62 this month · 1 condition ("Epilepsy",
user-typed) · 4 seeded event types plus 1 user-added and hidden · **34 observations** · **32
beforehand** · persistence available. **No synthetic entries were added.**

## ⭐ Corrections from the verification pass: **3**

Recorded rather than silently fixed. Both readings are stated at each site: **§W3/W4 chip
counts**, **§form-vs-wizard packing**, **§confirm-dialog occlusion**.

⚠️ **Honest limit on the verification.** Each image was re-opened and elements **recounted**
rather than recalled, but the first reading remained in context throughout. **This is a recount,
not a blind second opinion**, and it can only catch errors of counting and attribution — not a
shared misreading.

## ⚠️ Device artefact present in six captures

A translucent **app-switcher strip** (a YouTube tile and two photo thumbnails) overlays the
bottom edge of `history__filter-sheet`, `medication__add-sheet`, `medication__delete-dialog`,
`form__scroll-1-of-2`, `form__scroll-2-of-2` and `form__confirm-dialog`. **It is the Android
launcher, not MER.** In several other captures the black Android navigation bar overlaps the
last visible row.

---

# 1. `home__default`

- **Above the fold** — Blue app bar: icon, "Medical Event Recorder", "Record · Review · Share", overflow (⋮). Large empty gap. Orange block "**Record Event**" / "Tap to timestamp now". Blue block "Record with details". Stats card: 62 / 72 / 3 / 0 under "This month / Total saved / Days since / Referrals". Card "LAST EVENT" with clock icon, "27 Aug 2026 · 16:41", "Tap edit to update details", buttons "Edit details" and "All history". Card "Need Help with MER?" with chevron.
- **Below the fold** — none. Whole screen fits; empty space remains below the Help card. **1.00 screens.**
- **Element inventory** — 2 large action blocks; 1 overflow button; 4 stat figures; 2 buttons in the Last Event card; 1 help row; 1 app bar. **Text blocks: 4.** Chips: none.
- **Visual weight** — The **orange "Record Event" block** is largest and the only orange element in the app bar palette. Primary action appears to be recording an event immediately.
- **Type and spacing** — Roughly 6 sizes: app-bar title, app-bar subtitle, "Record Event" (largest), its caption, stat numerals, stat labels. Vertical rhythm is consistent between cards; the gap between the app bar and the orange block is much larger than any other gap.
- **Inconsistencies** — The orange block is the only element with that fill anywhere in the 22 layouts. "Record with details" is the same size and shape but blue.
- **Notes field** — absent.

# 2. `home__menu-open`

- **Above the fold** — As `home__default`, with a white overflow panel from the top-right covering the app bar's right half and part of the orange block. Items top to bottom: **History, Medication, What you track, Your lists, Your data, About, Help**.
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — **7 menu items**; underlying screen unchanged.
- **Visual weight** — The menu panel, by contrast against the dimmed content beneath.
- **Type and spacing** — One text size in the menu; even row spacing.
- **Inconsistencies** — The seven items are the app's only navigation surface; no tab bar or drawer appears anywhere else in the set.
- **Notes field** — absent.

# 3. `history__default`

- **Above the fold** — App bar: back arrow, "History", "Medical Event Recorder", filter icon, share icon. "72 events". Date header "THU 27 AUG 2026". One row: "4:41 PM" / "Needs: duration, type, severity" + trash icon. Date header "TUE 25 AUG 2026". Five rows, each: time, summary line, a pink "Seizure / fit" badge, trash icon. Date header "MON 24 AUG 2026". Three further rows. A tenth row is cut by the navigation bar.
- **Below the fold** — 72 events in total; **scroll extent not measurable from a single still.**
- **Element inventory** — 2 app-bar actions plus back; **~10 rows visible**, each with 1 tappable row + 1 trash button; **9 "Seizure / fit" badges**; 3 date headers; 1 count line.
- **Visual weight** — No single dominant element. The pink badges are the only saturated colour and repeat down the list.
- **Type and spacing** — 5 sizes: app-bar title/subtitle, date header (small caps), row time, row summary. Rhythm is even; rows are separated by hairlines that stop short of the left edge.
- **Inconsistencies** — The **trash icon carries no visible label**, unlike every other destructive control in the set: `about__default` uses a labelled button. The first row has **no badge** while the other nine do.
- **Notes field** — absent.

# 4. `history__filter-sheet`

- **Above the fold** — Dimmed History beneath. Bottom sheet with drag handle. Title "Filters". Search field with magnifier, placeholder "Search notes, afterwards, beforehand, severity…". Label "SHOW ONLY" with one chip "Needs details". Label "EVENT TYPE" with three chips: "Seizure / fit", "Absence episode", "Other / custom". Label "DATE RANGE" with chips "All time" (selected, tick), "Last 30 days", "Last 3 months", and a fourth **cut off at the right edge**. Row "Referral required only" / "Show only events that required medical referral" with a toggle (off).
- **Below the fold** — none within the sheet; empty space below the toggle row.
- **Element inventory** — 1 search field; **8 chips visible** (1 + 3 + 4, the last truncated); 1 toggle; 3 section labels; 1 title.
- **Visual weight** — The search field, by size and border.
- **Type and spacing** — 4 sizes. Section labels are small caps; consistent gaps.
- **Inconsistencies** — ⚠️ **The date-range chip row runs off the right edge rather than wrapping**, the only horizontally-clipped chip row in the set. Section labels are **small caps** here and **sentence case** in the wizard.
- **Notes field** — absent. The search field mentions notes as a search target.

# 5. `medication__default`

- **Above the fold** — App bar: back, "Medication", "Medical Event Recorder". Three-line explanatory paragraph. One row: grey "Missed" pill, "27 Aug 2026 · 23:21", trash icon. Large empty area. Floating button lower right: "+ Record a deviation".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 1 record row with 1 badge and 1 trash button; 1 floating action button; 1 paragraph.
- **Visual weight** — The **floating "Record a deviation" button**, being the only filled blue element in the body.
- **Type and spacing** — 4 sizes. Large unused vertical space between the single row and the button.
- **Inconsistencies** — ⭐ **This screen uses a floating action button; no other screen in the set does.** `conditions__default` puts its add affordance inline ("+ Name a condition"), and the wizard uses an inline "+ Add something else" pill. **Three different add affordances across three screens.**
- **Notes field** — absent on the list; present in the add sheet, §6.

# 6. `medication__add-sheet`

- **Above the fold** — Dimmed Medication beneath. Sheet: title "Record a deviation". Label "What happened?" with three chips "Missed", "Late", "Changed" (none selected). Label "When?" with one outlined chip: clock icon, "30 Aug 2026 · 22:59". A bordered **Notes (optional)** box roughly four lines tall. Buttons "Cancel" (outlined) and "Save" (filled, appears disabled — grey).
- **Below the fold** — none.
- **Element inventory** — 3 kind chips; 1 date/time chip; 1 notes field; 2 buttons; 2 labels; 1 title.
- **Visual weight** — The notes box, by area.
- **Type and spacing** — 4 sizes; even.
- **Inconsistencies** — Labels are **sentence case** here ("What happened?") and **small caps** on the form (`WHAT HAPPENED?`) for the same question wording. The date/time control is a **chip** here and a **card with a "Set" link** in the wizard summary and the form.
- **Notes field** — **present, above the buttons, roughly two-thirds down the sheet.** The most reachable notes field in the set.

# 7. `medication__delete-dialog`

- **Above the fold** — Dimmed Medication. Centred dialog: "Delete this note?", "This action cannot be undone.", buttons "Cancel" (text) and "Delete" (filled blue).
- **Below the fold** — none.
- **Element inventory** — 2 buttons; 2 text lines.
- **Visual weight** — The filled "Delete" button.
- **Type and spacing** — 2 sizes.
- **Inconsistencies** — The destructive action is **filled blue**, the same treatment as the confirmatory "Save" in `form__confirm-dialog`. No red or warning colour is used.
- **Notes field** — absent.

# 8. `conditions__default`

- **Above the fold** — App bar: back, "What you track", "Medical Event Recorder". Two paragraphs: "Name what you track, and say which event types belong to each." then a three-line explanation. Section "Conditions" with sub-line "The first one you named is your main one." Row "Epilepsy" / "1 event type". Inline "+ Name a condition". Section "Event types" with a two-line explanation. Three rows: "Seizure / fit — Epilepsy ▾", "Absence episode — Not set ▾", "Other / custom — Not set ▾". Empty space below.
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 1 condition row; 1 inline add button; **3 event-type rows each with a dropdown**; 2 section headings; 4 text blocks.
- **Visual weight** — No dominant element. The two paragraphs at the top occupy the largest single area.
- **Type and spacing** — 5 sizes. The explanatory text is the same size as row values, so headings carry most of the hierarchy.
- **Inconsistencies** — ⭐ **The only screen using dropdown selectors.** Every other selection in the set is a chip or a segmented pair. The add affordance is inline text here, a floating button on `medication__default`, and a pill in the wizard.
- **Notes field** — absent.

# 9. `conditions__add-field-open`

- **Above the fold** — As above through "Epilepsy / 1 event type", then an outlined text field with placeholder "**The name you use for it**" and an "Add" button to its right. Section "Event types" with its explanation and one row "Seizure / fit — Epilepsy ▾". The **on-screen keyboard occupies the lower ~40 %** of the screen.
- **Below the fold** — Two further event-type rows, hidden behind the keyboard.
- **Element inventory** — 1 text field; 1 "Add" button; 1 condition row; 1 event-type row visible; full QWERTY keyboard.
- **Visual weight** — The keyboard, by area. Within the app, the outlined text field.
- **Type and spacing** — Unchanged from §8.
- **Inconsistencies** — The "Add" button is **plain text with no border**, whereas "Save" in `medication__add-sheet` is a filled block.
- **Notes field** — absent.

# 10. `vocabulary__default`

- **Above the fold** — App bar: back, "Your lists", "Medical Event Recorder", **"Select"** at right. Two paragraphs about hiding. Section "Event types" / "Offered when you record what happened.  1 hidden." Rows: "Seizure / fit — Hide", "Absence episode — Hide", "Cluster headache" with sub-line "Hidden — still shown on records that use it" — "Show", "Other / custom — Hide". Disclosure row "⌄ 1 replaced by newer wording — Show". Section "What was happening beforehand" / "Offered on the beforehand step. Not causes." Rows "Stress — Hide", "Poor sleep — Hide", "Missed medication — Hide", and "Alcohol" partly behind the navigation bar.
- **Below the fold** — the remainder of 32 beforehand entries and all 34 observations. **Not measurable from a still; by entry count this is the longest screen in the set.**
- **Element inventory** — 1 app-bar action; **8 entry rows visible**, each with a Hide or Show text button; 1 disclosure row; 2 section headings; 2 paragraphs.
- **Visual weight** — No dominant element; a uniform list.
- **Type and spacing** — 5 sizes. Even row rhythm; section headings break it.
- **Inconsistencies** — ⭐ **Entries appear in SEED order here — "Stress" precedes "Poor sleep".** In `wizard-3-beforehand` the same vocabulary shows **"Poor sleep" first**. The same list is ordered differently on two screens. Also: "Show" appears twice with different meanings — as a row action and as the disclosure toggle.
- **Notes field** — absent.

# 11. `vocabulary__selection-mode`

- **Above the fold** — As §10 but the app-bar action reads **"Done"**, every actionable row's text button is replaced by an **empty checkbox**, and a bottom bar reads "Select entries" with "Show selected" and "Hide selected" (both greyed).
- **Below the fold** — as §10.
- **Element inventory** — **7 checkboxes visible**; 1 app-bar action; 2 bottom-bar actions; 1 status label; the disclosure row keeps its "Show" text link and gains no checkbox.
- **Visual weight** — The bottom bar, being the only persistent horizontal band.
- **Type and spacing** — Unchanged; row heights are identical to §10.
- **Inconsistencies** — ⚠️ **"Show" now appears three times on one screen with two meanings** — the disclosure's "Show" and the bottom bar's "Show selected". The "Cluster headache" row shows a checkbox despite being already hidden.
- **Notes field** — absent.

# 12. `your-data__default`

- **Above the fold** — App bar: back, "Your data". Intro line "Your events are stored on this device only. These are the two ways to get a copy off it — they do different jobs." Card 1: share icon, "**Export a spreadsheet**", two paragraphs, filled button "Export all events". Card 2: cloud icon, "**Back up your history**", two paragraphs, filled button "Back up now" and outlined "Restore from a backup". Closing paragraph: "Notiva never receives your events and cannot recover them for you…".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 3 buttons; 2 cards; 5 text blocks; 2 icons.
- **Visual weight** — The two cards are equal; neither dominates. "Export all events" and "Back up now" are the same filled treatment.
- **Type and spacing** — 4 sizes. Consistent rhythm; the two cards are structurally parallel.
- **Inconsistencies** — ⭐ **The most internally consistent screen in the set** — two cards built to the same template. It is also the only screen where a paragraph sits *below* the last control.
- **Notes field** — absent.

# 13. `about__default`

- **Above the fold** — A **blue hero band** taller than any other app bar: app icon, "Medical Event Recorder", "Version 1.1.0", "Record · Review · Share". Card "APP": Developer — Notiva; Version — 1.1.0; Platforms — iOS · Android · Windows; Data storage — Local device only. Card "LINKS": Website, Privacy Policy, Terms of Service, Support, each with a value and an external-link glyph; two URLs are **truncated with an ellipsis**. Card "LEGAL": "For personal record-keeping only. Not a medical device. Does not diagnose, treat, or replace professional medical advice. All data is stored locally on your device." A fourth card heading "APP DATA" is **cut by the navigation bar**.
- **Below the fold** — the APP DATA card, containing the reset control. **Approximately 1.2 screens.**
- **Element inventory** — 4 link rows; 8 label/value pairs; 3 card headings visible, 1 partial; 1 hero band.
- **Visual weight** — The blue hero band with the app icon.
- **Type and spacing** — 6 sizes, the most in the set. Card rhythm is consistent.
- **Inconsistencies** — ⭐ **The only screen with a hero band**; every other screen uses the standard two-line app bar. **The version string appears twice** — in the hero and in the APP card. ⚠️ *Observation, not a claim about the build: the screen renders "1.1.0"; the capture was of a locally built APK.*
- **Notes field** — absent.

# 14. `help__default`

- **Above the fold** — App bar: back, "Help". Status row: bell icon, "Notifications", green dot, "Active". Card: "**Quick-log notification**" / "Always in the notification shade, so an event can be recorded without unlocking the phone." with a **blue toggle, on**. Five collapsed accordion headers, each with a chevron: "RECORDING EVENTS", "HISTORY & EXPORT", "YOUR DATA — PLEASE READ", "QUICK LOG NOTIFICATION" (expanded, showing one row "Starting an event" with a three-line body), "GETTING HELP".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 1 status row; 1 toggle; **5 accordion headers**; 1 expanded row; 1 icon per accordion header.
- **Visual weight** — The quick-log card, being the only one with a filled control.
- **Type and spacing** — 5 sizes. Accordion headers are small caps.
- **Inconsistencies** — ⭐ **The only toggle switch in the app body** — `history__filter-sheet` has the only other one. **The only accordion pattern in the set.** One accordion renders expanded while four are collapsed.
- **Notes field** — absent.

# 15. `wizard-1-duration__default`

- **Above the fold** — App bar: back, "Add details", "**Skip to end**" at right, and a thin progress bar beneath showing roughly one-fifth filled. Heading "How long did it last?" Sub-line "Leave both blank if you do not know — that is recorded as unknown, not as zero." Two side-by-side outlined fields, "minutes" and "seconds". Very large empty area. Full-width filled "**Next**" at the bottom.
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 2 text fields; 1 primary button; 1 app-bar action; 1 progress bar; 2 text blocks. Chips: none.
- **Visual weight** — The "Next" button, being the only filled block.
- **Type and spacing** — 3 sizes. **Roughly 55 % of the screen is empty.**
- **Inconsistencies** — The only wizard step with **no Back button** — it shows only "Next", while steps 2 to 4 show "Back" and "Next" side by side. The duration fields here are bare outlined boxes; the same duration fields on the form carry small floating labels.
- **Notes field** — absent.

# 16. `wizard-2-type__default`

- **Above the fold** — App bar as §15, progress bar further along. Heading "What happened?" Sub-line "Pick what best describes it." Group label "**Epilepsy**" with one chip "Seizure / fit". Group label "**Not set**" with two chips "Absence episode", "Other / custom". Pill "+ Add an event type". Label "Compared with the others here" with three chips "Mild", "Moderate", "Severe". Empty area. "Back" (outlined) and "Next" (filled).
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — **3 event-type chips in 2 groups**; 1 add pill; **3 severity chips**; 2 group labels; 1 section label; 2 buttons.
- **Visual weight** — "Next".
- **Type and spacing** — 4 sizes. Roughly 40 % empty below the severity row.
- **Inconsistencies** — ⭐ **This picker has no "N to choose from · Show all" disclosure**, unlike steps 3 and 4 and both form sections. [code-derived] *It is the one picker not routed through the bounded widget.* ⭐ **Event types are chips here and a 2×2 grid of bordered cards with icons on the form** — the same choice, two different controls. Severity is a chip row here and a **filled segmented control** on the form.
- **Notes field** — absent.

# 17. `wizard-3-beforehand__default`

- **Above the fold** — App bar as §15. Heading "What was happening beforehand?" Sub-line "Anything you noticed. This is not a cause — just what was going on." **Eight chips in three rows**: Poor sleep, Stress, Missed medication / Alcohol, Flashing lights, Illness / Period or hormonal, Certain foods. Pill "+ Add something else". Disclosure "⌄ **32 to choose from**" with "**Show all**" at the right. Large empty area. "Back" and "Next".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — **8 chips**; 1 add pill; 1 disclosure row with 1 text link; 2 buttons; 2 text blocks.
- **Visual weight** — "Next".
- **Type and spacing** — 4 sizes. Roughly 40 % empty.
- **Inconsistencies** — ⭐ **"Poor sleep" appears first here; on `vocabulary__default` the same list begins "Stress".** The same vocabulary is ordered differently on the two screens.
- **Notes field** — absent.

# 18. `wizard-4-afterwards__default`

- **Above the fold** — App bar as §15, progress bar nearly complete. Heading "How were things afterwards?" Sub-line "In the minutes and hours after it ended." **Seven chips in three rows**: Tired, Weak, Memory gap / Speech difficulty, Confused / Headache, Sore or aching. Pill "+ Add something else". Disclosure "⌄ **34 to choose from**" — "Show all". Label "Rescue medication given?" with "No" / "Yes". Label "Medical referral required?" with "No" (selected, ticked, filled) / "Yes". A bordered "**Notes (optional)**" box about four lines tall. "Back" and "Review".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — **7 chips**; 1 add pill; 1 disclosure; **4 answer chips** across two questions; 1 notes field; 2 buttons; 4 text blocks.
- **Visual weight** — "Review", the filled button.
- **Type and spacing** — 4 sizes; even rhythm; **no empty region** — this is the fullest wizard step.
- **Inconsistencies** — ⛔ **CORRECTION 1, recorded.** *First reading:* the bounded pickers show a fixed set of entries. *Second reading:* step 3 shows **8** chips and step 4 shows **7**, both in three rows. **The document adopts the second reading: the picker bounds by ROWS, not by count**, so the number of entries offered varies with label width. ⭐ This step is the **only wizard step carrying the two questions and notes**; steps 1 to 3 carry none of them.
- **Notes field** — **present, above the buttons, roughly 78 % down the screen.** Visible without scrolling.

# 19. `wizard-5-summary__default`

- **Above the fold** — App bar: back and "**Check and save**" — **no "Skip to end", and no progress bar.** Heading "Check and save". Sub-line "Save to finish. What you have entered is kept either way." Card "**When it happened**" / "27 Aug 2026 · 16:41" / "The time this was recorded. Change it if it happened earlier." with a "**Set**" link at right. One bullet: "• Duration: not recorded". Very large empty area. Full-width filled "**Save**".
- **Below the fold** — none. **1.00 screens.**
- **Element inventory** — 1 card with 1 text link; **1 summary bullet**; 1 primary button; 2 text blocks.
- **Visual weight** — "Save".
- **Type and spacing** — 4 sizes. **Roughly 60 % empty** — the emptiest screen in the set.
- **Inconsistencies** — ⭐ **The only wizard screen whose app-bar title changes** from "Add details" to the step's own heading, so the heading appears **twice**. It is also the only step without "Skip to end" or a progress bar, and the only place "When it happened" appears in the wizard.
- **Notes field** — absent. Notes entered on step 4 are not echoed here; the summary lists only "Duration: not recorded".

# 20. `form__scroll-1-of-2`

- **Above the fold** — App bar: back, "**Edit event**", "Medical Event Recorder". Label "WHAT HAPPENED?" and a **2 × 2 grid of bordered cards**, each with an icon: "Seizure / fit" (selected — pink fill, orange border), "Absence episode", "Other / custom", "+ Add your own". Label "DURATION" with two fields carrying floating labels, containing "1" and "45". Card "When it happened" / "25 Aug 2026 · 22:17" / explanation, with "Set". Label "SEVERITY" and a three-part control: "Mild" (filled blue), "Moderate", "Severe". Label "HOW WERE THINGS AFTERWARDS?" with its sub-line and **nine chips in three rows**: Tired, Weak, Memory gap / Speech difficulty, Confused, Headache / Sore or aching, Nauseous, Sad. Pill "+ Add something else". Disclosure "⌄ 34 to choose from — Show all". Label "WHAT WAS HAPPENING BEFOREHAND?" is **cut at the bottom edge**.
- **Below the fold** — see §21. **Total 2 screens** (a first capture attempt produced byte-identical segments 2 and 3, `md5 be3d0730…`, confirming the extent).
- **Element inventory** — **4 event-type cards**; 2 duration fields; 1 date card with 1 link; **3 severity segments**; **9 observation chips**; 1 add pill; 1 disclosure; 5 small-caps labels.
- **Visual weight** — The 2 × 2 event-type grid, by area and by being the only bordered-card cluster.
- **Type and spacing** — 5 sizes. Section labels are small caps throughout. Rhythm is consistent but denser than any wizard step.
- **Inconsistencies** — ⛔ **CORRECTION 2, recorded.** *First reading:* the form and wizard show the same afterwards picker. *Second reading:* the form shows **9** chips where wizard step 4 shows **7**, from the same 34-entry vocabulary under the same three-row bound. **The document adopts the second reading: the form's chips are narrower, so more fit per row.** ⭐ Further: **section labels are small caps here and sentence case in the wizard**; event types are **cards** here and **chips** in the wizard; severity is a **filled segmented control** here and **chips** in the wizard.
- **Notes field** — not in this segment; see §21.

# 21. `form__scroll-2-of-2`

- **Above the fold (of this segment)** — Label "WHAT WAS HAPPENING BEFOREHAND?" with sub-line "Not a cause — just what was going on." **Nine chips in three rows**: Poor sleep, Stress, Missed medication / Alcohol, Flashing lights, Illness / Period or hormonal, Certain foods, Dehydration. Pill "+ Add something else". Disclosure "⌄ 32 to choose from — Show all". Label "RESCUE MEDICATION GIVEN?" with "No" / "Yes" (neither selected). Label "MEDICAL REFERRAL REQUIRED?" with "No" (filled) / "Yes". Label "NOTES (OPTIONAL)" and a bordered box, placeholder "Add any additional observations…", about five lines tall. Filled "**Save changes**". Outlined "**Cancel**".
- **Below the fold** — none. End of screen.
- **Element inventory** — **9 chips**; 1 add pill; 1 disclosure; **4 answer buttons**; 1 notes field; 2 buttons; 4 labels.
- **Visual weight** — "Save changes".
- **Type and spacing** — 4 sizes; even.
- **Inconsistencies** — The beforehand list here shows **9 chips including "Dehydration"**, where wizard step 3 shows **8** and stops at "Certain foods". Notes placeholder text differs: "Add any additional observations…" here, plain "Notes (optional)" in the wizard and the medication sheet.
- **Notes field** — **present, immediately above the buttons — on the second screen**, so it is reached only after a full screen of scrolling. **The deepest notes field in the set.**

# 22. `form__confirm-dialog`

- **Above the fold** — Dimmed form beneath, scrolled as §21 with "Poor sleep" now **selected (filled)**. Centred dialog: "**Confirm changes**", "Save the following changes?", bullet "• Beforehand updated", buttons "Keep editing" (text) and "Save" (filled blue).
- **Below the fold** — none.
- **Element inventory** — 2 buttons; 3 text lines; 1 bullet.
- **Visual weight** — The filled "Save".
- **Type and spacing** — 3 sizes.
- **Inconsistencies** — The confirmatory "Save" is **filled blue**, the same treatment as the destructive "Delete" in §7. **"Keep editing" is a text button where the parallel control elsewhere is "Cancel" outlined.**
- **Notes field** — visible beneath the dialog, unchanged from §21.
- ⛔ **CORRECTION 3, recorded.** *First reading:* the beforehand disclosure reads "1 of 32". *Second reading:* **the dialog occludes the string and only "1 of 3…" is legible.** **The document adopts the second reading and flags this capture as not confidently readable at that point.** ⚠️ **Recommend pasting this capture rather than relying on the description for the disclosure label.**

---

# Step 3 — Targeted comparisons

## 3.1 The wizard's five steps against the form's two segments

**Element order.**

| Wizard | Form |
|---|---|
| 1 duration · 2 type + severity · 3 beforehand · 4 afterwards + rescue + referral + notes · 5 summary | type → duration → **when it happened** → severity → afterwards → beforehand → rescue → referral → notes |

⭐ **The two paths present the same fields in different orders.** The wizard asks **duration first**; the form asks **type first**. The wizard splits **severity onto the type step**; the form gives severity its own labelled block. The wizard puts **beforehand before afterwards**; the form puts **afterwards before beforehand**.

**Above-fold content.** Each wizard step fits in **1.00 screens** with 40–55 % empty on steps 1, 2, 3 and 5. The form is **2 screens with no empty region**.

**Inventory.** Wizard total across five steps: 2 text fields, 3 event-type chips, 3 severity chips, 8 + 7 vocabulary chips, 2 add pills, 2 disclosures, 4 answer chips, 1 notes field, 1 date card, 9 navigation buttons. Form total: 4 event-type **cards**, 2 text fields, 1 date card, 3 severity **segments**, 9 + 9 vocabulary chips, 2 add pills, 2 disclosures, 4 answer buttons, 1 notes field, 2 buttons.

**What each path asks that the other does not.**
- **Wizard only:** a per-step **progress bar**; a **"Skip to end"** action on steps 1 to 4; a **summary step** that re-states the date and lists what is unrecorded.
- **Form only:** **"When it happened" inline** rather than only on a summary; a **"+ Add your own"** event-type tile in the grid; a **Cancel** button; a **confirm dialog** on save.
- **Neither** echoes notes back before saving.

## 3.2 Every screen where "notes" appears, ranked by depth

| Rank | Screen | Depth |
|---|---|---|
| 1 | `medication__add-sheet` | ~two-thirds down a single sheet, **no scrolling** |
| 2 | `wizard-4-afterwards` | ~78 % down, **no scrolling** |
| 3 | `form__scroll-2-of-2` | **second screen** — a full screen of scrolling first |
| — | `history__filter-sheet` | notes named only as a **search target**, not an input |

**Deepest: the form.** Absent entirely from all other layouts.

## 3.3 The three configuration screens

| | **What you track** | **Your lists** | **Your data** |
|---|---|---|---|
| Governs | which conditions exist; which event type belongs to which condition | which vocabulary entries are offered in pickers | getting a copy of records off the device |
| Controls | 3 dropdowns, 1 inline add | per-row Hide/Show text buttons; a selection mode with checkboxes and a bottom bar; 1 disclosure | 3 buttons in 2 parallel cards |
| Lists | conditions (1) and event types (3) | event types, beforehand, afterwards — **all in one scroll** | nothing |
| Overlap | ⭐ **Event types appear on both**: as rows with condition dropdowns here, and as hideable rows there | ⭐ same | none |
| Length | 1.00 screens | longest screen in the set | 1.00 screens |
| Explanatory text | 2 paragraphs | 2 paragraphs | 1 intro, 4 body paragraphs, 1 closing |

**Stated without conclusion:** event types are the only entity that appears on two of the three; conditions appear only on the first; records appear only on the third.
