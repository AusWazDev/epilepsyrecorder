# MER — Design Audit Capture Set

**Captured 30 August 2026, AEST.** For the whole-app design audit.

---

## ⛔ READ THIS FIRST: THESE ARE WIDTH PROXIES, NOT iOS SCREENSHOTS

**They reproduce logical width, and therefore wrapping and layout.**

**They do NOT reproduce iOS fonts, safe-area insets, the Dynamic Island, or iOS chrome.**

Every image here was rendered by **Android on a Teclast P30 tablet** with the display size
overridden to an iPhone's logical dimensions. **Anything about appearance needs the developer's
manual iPhone shots.** Anything about *how many rows a chip wall wraps to at 430 pt* is exactly
what these answer.

⚠️ **A later reader who mistakes these for iOS captures will draw a wrong conclusion from a
correct file.** The 375 and 430 sets are Android pixels at iPhone widths — nothing more.

---

## Device and method

| | |
|---|---|
| Device | **Teclast P30 (`P30_ROW`), Android 15** |
| Physical size | **800 × 1280** |
| Physical density | **160 dpi (mdpi)** — so **1 dp = 1 px**, and an override in pixels is an override in dp |
| Orientation | **Portrait, forced.** `accelerometer_rotation 0` + `user_rotation 0` |
| Build | release APK built from the working tree **after** `c2f6d80` and `0b8830c`, so **the bounded chip pickers are present** |

**Overrides used, one set per width:**

```
adb shell wm size 430x932     iPhone 15 Pro Max logical size
adb shell wm size 375x667     iPhone 8 logical size
adb shell wm size 800x1280    the tablet's own, portrait
```

**Reset afterwards** — verified as `Physical size: 800x1280` / `Physical density: 160` with **no
`Override` line**, and `accelerometer_rotation` restored to `1`, its value before this pass.

⚠️ **The native set is the tablet in PORTRAIT.** The developer uses this tablet in landscape, so
`800x1280` is not "how the tablet is normally seen" — it is the tablet's own width, captured in
the same orientation as the other two so the three are directly comparable. **A width comparison
needs one variable.**

---

## Database state at capture time

**Verified on the device during this pass, not carried over from an earlier reading.**

| | |
|---|---|
| Records | **72** total, **62** this month |
| Conditions | **1** — "Epilepsy", user-typed, `seeded_key` null |
| Event types | **4 seeded**, plus **1 user-added and hidden** (`Cluster headache`) |
| Observations | **34**, all seeded, none user-added |
| Beforehand | **32**, all seeded, none user-added |
| Persistence | **available** — a real database, so gated elements render |

⛔ **NO SYNTHETIC ENTRIES WERE ADDED, DELIBERATELY.** Vocabularies are **append-only**: values are
permanent and entries are hidden, never deleted. Six synthetic entries would be six permanent rows
in the developer's real vocabulary, in every future picker and export. **A capture set is not
worth an irreversible change to real data.**

⚠️ **So this set does not show the heavy-vocabulary case**, and in particular it does not show
**wizard step 2 with a second condition** — the picker that is still unbounded and whose grouped
variant a second condition switches on. **That case needs a disposable profile and is a separate
task.**

✅ **The gated element that caused the earlier measurement fault renders correctly here.** The
form's "Add your own" tile is present, because persistence is available. A widget test without a
database omitted it, and that run reported a layout the device never renders.

---

## What is here

**65 files, 3.4 MB.** 22 layouts at 430×932, **21** at 375×667, 22 at 800×1280.

```
about__default                    conditions__add-field-open       conditions__default
form__confirm-dialog              form__scroll-1-of-2              form__scroll-2-of-2
help__default                     history__default                 history__filter-sheet
home__default                     home__menu-open                  medication__add-sheet
medication__default               medication__delete-dialog        vocabulary__default
vocabulary__selection-mode        wizard-1-duration__default       wizard-2-type__default
wizard-3-beforehand__default      wizard-4-afterwards__default     wizard-5-summary__default
your-data__default
```

**Naming:** `{screen}__{state}__{width}x{height}.png`. **No dates in filenames** — this index
carries the timestamp, and a dated filename goes stale the moment it is re-shot.

**The form is two screens, not three.** Segments 2 and 3 of a first attempt were byte-identical
(`md5 be3d0730…`), so it is named `1-of-2` / `2-of-2`. That agrees with the recorded measurement
of 2.11 screens at 430.

---

## ⛔ Not captured, and why

| Layout | Reason |
|---|---|
| **`form__confirm-dialog` at 375×667 only** | Present at 430 and 800. At 375 the `Save changes` button stayed below the fold after two scrolls, so the dialog was never triggered. **Not a layout finding — a navigation limit of the capture script** |
| **`history__delete-dialog`, all widths** | The trash control is an **unlabelled `Button` with `content-desc=""`**, located only by geometry. Three attempts failed to open it. ⭐ **`medication__delete-dialog` is captured at all three widths and is the same `AlertDialog` shape** |
| **`DisclaimerScreen` and `WalkthroughScreen` (5 steps)** | ⛔ **Unreachable without destroying data.** Their gates are `disclaimerAcceptedVersion` and `walkthroughSeenVersion` in SharedPreferences. `run-as` is refused on a release build — *"package not debuggable"* — so the only way to clear them is `pm clear`, which **wipes all app data including the 72 records** |
| **Empty states** — History, Conditions and Medication with no rows | ⛔ Same reason: they require destroying records |
| **`Reset app?` dialog** | ⛔ **Deliberately not opened.** It is the single most destructive control in the app and one mis-tap on its confirm button destroys 72 irreplaceable records. **The value of its screenshot does not justify that risk** |

⭐ **Every one of these is reachable on a disposable profile** — which is also where the
heavy-vocabulary case belongs. **They should be captured together in that later pass**, where a
fresh install has no records and therefore nothing to lose.

---

## Findings noticed while capturing

**Recorded here because they came out of doing the work, not from reading code.**

⚠️ **The delete control in History has no accessibility label.** It is a `Button` with
`content-desc=""` — a destructive action with nothing for a screen reader to announce, sitting on
every row. **An accessibility finding, and it is why the delete dialog is missing above.**

⚠️ **The `applicationId` and the `namespace` differ** — `au.com.notiva.medicaleventrecorder`
versus `au.com.notiva.medical_event_recorder` — so `am start -n <pkg>/.MainActivity` fails with
`Error type 3`. The full activity is
`au.com.notiva.medicaleventrecorder/au.com.notiva.medical_event_recorder.MainActivity`.
**Relevant to anyone scripting against this app.**

⚠️ **`disclaimerAcceptedVersion` is a raw string literal in three files** — `main.dart`,
`disclaimer_screen.dart`, `home_screen.dart` — while the walkthrough gate has a proper constant,
`kWalkthroughSeenVersionKey`. **Three copies of a storage key that must never change.** All three
readers only route on it; none has a side effect.

---

## Added 7 September 2026 — after fix 1

⛔ **THE 30 AUGUST SET IS NOT MODIFIED. This is an ADDITION.** A capture in that set is the
record of what the screen looked like on 30 August; overwriting one would make a dated
artefact show undated content.

| File | What changed |
|---|---|
| `history__default__430x932__2026-09-07-after-fix-1.png` | **Fix 1, the quick-log row — BOTH parts.** (B) The gap list moved out of the content run onto its own smaller, muted line, so a timestamp-only record no longer describes itself solely by what it lacks. (A) The copy is now `Add details:` rather than `Needs:`, matching the app-bar title of the wizard the row opens. Compare against `history__default__430x932.png` (30 Aug). |

**Row heights measured from the two captures, not inferred:** complete row 73 px unchanged ·
partial row 73 → 77 px · timestamp-only row unchanged. One row boundary drops below the fold.

---

## Added 7 September 2026 (evening) — FIRST REAL-iOS CAPTURES

⛔ **THE 30 AUGUST SET IS NOT MODIFIED. This is an ADDITION, and it is REAL iOS.**
The 30 August files are Android pixels at iPhone widths. These are iOS rendering iOS: real
fonts, real safe-area insets, real status bar and Dynamic Island region, real iOS chrome.
**Every file is marked device or simulator, and that distinction is the whole point of the
exercise.**

| Suffix | Source | Marked |
|---|---|---|
| `2026-09-07-ios-15promax-device` | **iPhone 15 Pro Max**, iOS 26.6.1 (23G83) — 1290×2796 = 430×932 @3x | **PHYSICAL DEVICE** |
| `2026-09-07-ios-se3-sim` | **iPhone SE (3rd gen)** simulator, iOS 26.3 — 750×1334 = 375×667 @2x | **SIMULATOR** |

⚠️ The earlier "no dates in filenames" rule is **superseded for additions**, following
`history__default__430x932__2026-09-07-after-fix-1.png`. A dated suffix is what stops an
addition colliding with the dated set it is being compared against.

---

### 430 — PHYSICAL DEVICE, 9 files

**Database state at capture: 58 events · 0 conditions · 0 medication notes · `occurred_at`
NULL on all 58 · 13 of the 58 incomplete.** So `wizard-5-summary` shows the backdating
control untouched, every condition-dependent surface renders empty, and History opens on a
run of incomplete rows. **72 on Android and 58 on iOS are two independent histories, not a
drift** — there is no sync.

| File | State |
|---|---|
| `home__default` | Backup banner **dismissed**, for comparability with the 30 Aug proxy |
| `home__backup-reminder` | ⭐ The banner **present** — see below |
| `wizard-5-summary__default` | NEW record, every answer blank — the emptiest reachable case |
| `form__scroll-1-of-2` / `-2-of-2` | Record of **24 Aug 20:07** — bucket duration, nothing selected, rescue not given |
| `form__rescue-expanded-1-of-2` / `-2-of-2` | ⭐ Record of **27 Aug 19:03** — rescue medication GIVEN |
| `wizard-4-afterwards__default` | Step 4, defaults |
| `history__default` | 58 events, top of list |

⛔ **NOTHING WAS SAVED TO PRODUCE THESE.** Verified, not assumed: `mer_events.db` was copied
off before the first install and re-read four times during the pass. **58 events and
`sha256 e6366d33…` byte-identical every time, zero records dated 7 September, and no
vocabulary row appended.** The wizard was entered twice and the form three times.

⚠️ **THE ZERO-WRITE ROUTE IS NARROW, AND IT MATTERS FOR THE NEXT PASS.**
`event_wizard_screen.dart:201` sets `_draft = e` in `initState`, so **for an EXISTING record
`_draft` is non-null immediately** — `_onWillPop` then captures and pops non-null, and
`home_screen.dart:_openWizard` calls `persistEvents`. **Tapping a History row to look at the
wizard REWRITES that record.** A NEW wizard is safe: `_draft` starts null and both
`Skip to end` and the back-out are guarded by `if (_draft != null || _hasAnyInput)`, so an
untouched new wizard materialises nothing. The form is safe either way — `_cancel()`
(`log_event_screen.dart:373`) pops with no result.

⭐ **`home__backup-reminder` IS A CARD THE 30 AUGUST SET DOES NOT CONTAIN AT ALL.** It appears
on the app's PRIMARY screen whenever events-since-backup ≥ 10 (`kBackupReminderThreshold`,
`home_screen.dart:126`); this device sits at 21. Its absence from the Android set is a
**device-state difference, not a platform one** — that tablet had backed up more recently.
⚠️ **It fills the ENTIRE upper void**, which is the exact region the "anchor rather than
centre" recommendation is about. **Judge that recommendation against BOTH files or the answer
is wrong.** Dismissal (`_backupBannerDismissed`) is in-memory only and returns on next cold
launch.

⭐ **`form__rescue-expanded-*` IS THE `rescueChildrenVisible` BRANCH, ABSENT FROM THE AUDIT.**
Rescue medication = Yes reveals **DID IT HELP?** and **WAS A SECOND DOSE NEEDED?**, and the
chip counter changes from `32 to choose from` to **`1 of 32 selected`**. Only **1 of the 45**
form-eligible records on this device carries it, so it is easy to miss entirely.
⚠️ **It makes the form TALLER than the recorded 2.11 screenfuls — do not measure segment
counts from this pair.**

---

### 375 — SIMULATOR, 14 files

⛔ **iPhone SE (3rd gen) SUBSTITUTES FOR iPhone 8, AND THE SUBSTITUTION IS FORCED.**
**iPhone 8 cannot be created on iOS 26.3**, and 26.3 is the only iOS runtime on the Mac —
Xcode still lists the device type but the runtime does not support it. The substitution is
sound (same chassis, 375×667, 20 pt status bar, no bottom inset) but it is **forced by
tooling, not chosen.**

⛔ **THE 375 SET IS FIRST-RUN AND 0→1 RECORD STATE. IT IS NOT THE 58-EVENT STATE.**

| Capture | State |
|---|---|
| `home__empty`, `history__empty`, `home__menu-open-empty` | **0 records** — true empty state |
| `disclaimer__first-run`, `walkthrough-1__first-run` | **first run**, gates unset |
| `wizard-*`, `form__*`, `history__one-*` | **1 record**, created to reach them |

`home` and `history` are named `__empty` rather than `__default` because they genuinely
differ with records — home gains the LAST EVENT card and non-zero counters; History shows
rows instead of "No events yet". `wizard-*` and `form__*` keep `__default`: they render from
one record's own fields plus the seeded vocabulary, so record count does not change them.

⚠️ **Reaching the wizard and the form REQUIRES records**, so `history__empty` was shot first
while the database was genuinely empty. The **form** (`LogEventScreen`) opens only for a
record with duration, type AND severity all set (`event_record.dart:151`); "Record with
details" goes to the **WIZARD** (`home_screen.dart:567`, `_openWizard(existing: null)`).
**Conflating this set with the device state would be the artefact.**

⭐ **Five of these are listed above as unreachable on Android without destroying the 72
records** — the disclaimer, the walkthrough, and the empty History, Conditions and Medication
states. **A fresh simulator reaches them for free.** That is what the disposable profile was
always for.

---

### ⛔ THE SIMULATOR MISRENDERS EMOJI. DO NOT READ CHIP LAYOUT FROM THE 375 SET.

The iOS 26.3 **simulator runtime lacks the emoji font.** Chips that render
🥱 Tired · 🪫 Weak · 🗣 Speech difficulty · 😵 Confused · 🤕 Headache on the DEVICE render as
**boxed `?` placeholders** in the simulator.

⚠️ **Affects `form__scroll-1-of-2__375x667`, `form__scroll-mid-a__375x667` and
`wizard-2-type__default__375x667`.** Chip WIDTH and therefore WRAPPING are wrong in those
three. **It is a tooling artefact, not a layout fact** — compare the two
`form__scroll-1-of-2` files to see it directly.

---

### Measurements, from the captures rather than inferred

⚠️ **The form is NOT two screenfuls at 375.** The bottom is reached only after three ~420 pt
scrolls; a fourth was byte-identical. `form__scroll-mid-a` and `-mid-b` are the intermediate
segments the 1-of-2 / 2-of-2 naming has nowhere to put. **At 430 the 2.11-screenful figure
holds.**

⭐ **`Save changes` IS on screen at 375 on iOS**, visible in `form__scroll-2-of-2__375x667`.
The reason recorded above for `form__confirm-dialog` missing at 375 — that the button stayed
below the fold after two scrolls — **does not hold on iOS. That gap is now fillable.**

⚠️ **The wizard summary's back arrow does NOT exit the wizard** — it steps back one page
(`event_wizard_screen.dart:391`, `_step == 0 ? _onWillPop() : setState(() => _step--)`).
Exiting from the summary takes five taps. That is how `wizard-4-afterwards__default` came to
be captured.

---

### Fix 1 verified on real iOS, three ways

`history__default__430x932__2026-09-07-ios-15promax-device.png` shows the quick-log rows
reading **`Add details: type, severity`** on their own smaller, muted line BENEATH the
duration — **Fix 1A and Fix 1B both visible on hardware.** A row with no duration reads
`Add details: duration, type, severity`. **No row reads "Needs:".** The 375 pair
`history__one-partial` / `history__one-complete` gives the partial and complete row layouts
side by side.

⚠️ **A BUILD CANNOT BE VERIFIED BY ITS VERSION NUMBER.** Installed and tree both read
`1.1.0+53` before and after. It was verified by probing the binary, anchored on the
**interpolation form**:

| Probe | Debug `kernel_blob.bin` | Release `App.framework/App` |
|---|---|---|
| `Add details: ` | 1 | 1 |
| `Needs: ` | **0** | **0** |
| `Needs details` (control) | 1 | 1 |

⛔ **THE CONTROL IS THE LOAD-BEARING PART.** `Needs details` is the filter chip
(`history_screen.dart:918`) — unchanged by Fix 1A and present in BOTH builds. It proves the
search WOULD have found `Needs: ` had it been there. **Grepping the bare word "Needs" returns
hits on a FIXED build**, and a debug blob also contains the comment
`"Add details:", not "Needs:"`. Anchor on `'Needs: ${` in a debug blob, and on the emitted
prefix `Add details: ` in a release binary — **`${` does not survive AOT compilation.**
