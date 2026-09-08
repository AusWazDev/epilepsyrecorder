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

### ⭐ DESKTOP CAPTURES — the convention, decided 8 September 2026 BEFORE any shot

**The existing rule, unchanged for mobile:**

    {screen}__{state}__{logicalW}x{logicalH}[__{date}-{tag}].png

⛔ **THE QUESTION WAS WHETHER A WINDOW SIZE BELONGS WHERE A LOGICAL WIDTH DOES. IT DOES, AND THE
RUNNER SETTLES IT RATHER THAN TASTE.** `windows/runner/main.cpp` requests
`Win32Window::Size size(1280, 720)`, and `win32_window.cpp:134-135` scales that by
`dpi / 96.0` before `CreateWindow`:

```cpp
UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
double scale_factor = dpi / 96.0;
... Scale(size.width, scale_factor), Scale(size.height, scale_factor) ...
```

⭐ **So the number in the source is LOGICAL and the OS supplies a separate DPR multiplier — the
identical relationship the mobile suffixes already encode.** `430x932` is an iPhone's logical size
with DPR carried by the device tag; `1280x720` is the desktop window's logical size with DPR
carried the same way. **No new segment is needed, and inventing one would have made the two
platforms look structurally different when they are not.**

**So, for Windows:**

| Segment | Windows meaning |
|---|---|
| `{screen}` | unchanged — `home`, `history`, `form`, and the same names as mobile |
| `{state}` | unchanged — `default`, `discard-dialog`, and so on |
| `{logicalW}x{logicalH}` | **the WINDOW's logical size, not the display's.** A desktop window is resizable, so this is the only size that means anything about the layout |
| `{date}-{tag}` | **`{date}-windows-desktop`**, and the tag is MANDATORY here rather than optional |

⛔ **THE TAG IS MANDATORY ON EVERY DESKTOP CAPTURE, and that is the one real change.** On mobile an
untagged file means "1x Android proxy" — a default that exists because 66 of 89 files are that.
**A desktop capture must never be able to inherit that default**, because a reader who mistakes a
Windows window for an Android proxy at the same numbers draws a wrong conclusion from a correct
file. ⭐ **Same reason the width-proxy warning exists at the top of this document.**

⚠️ **DPR IS RECORDED IN THIS INDEX, NOT IN THE FILENAME**, exactly as it is for mobile — where the
scale factor is carried by `ios-15promax-device` versus `ios-se3-sim` versus untagged, and the
actual `1290x2796` never appears in a name.

⛔ **`assets/screenshots/windows/` IS NOT THIS SET AND MUST NOT BE READ AS IT.** Those four files —
`mer-win-1` to `mer-win-4`, at 1103x927, 1102x922, 1107x928 and 1106x925, dated 3 May 2026 — are
**Microsoft Store listing screenshots**. They carry **no screen segment, no state segment, no size
segment and no date**, so they are structurally incapable of joining this convention. **They are
evidence that the target has been photographed before; they are not design-audit captures.**

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

---

## Added 8 September 2026 — pass 2a, the reachable shots

⛔ **NEITHER THE 30 AUGUST SET NOR THE 7 SEPTEMBER ADDITIONS ARE MODIFIED. This is an ADDITION**,
following the precedent set by `history__default__430x932__2026-09-07-after-fix-1.png`.

**Why 2a and not "pass 2".** §13(q) of `AUDIT.md` decided a three-pass refresh on 8 Sep 2026 whose
pass 2 was *"disclaimer and walkthrough at the widths they lack"*. ⭐ **That pass is unrunnable on
this device, and THIS FILE already said so** — see "Not captured, and why" above, where both
screens are recorded as **unreachable without `pm clear`**, which destroys the 72 records. The
decision was made without reading it. Pass 2 therefore split: **2a is what the live device can
give; 2b is the disposable-profile pass this file already specifies.**

### What was captured — 10 files, all 1x Android at the stated logical width

| File | Logical | Size |
|---|---|---|
| `form__discard-dialog__430x932__2026-09-08.png` | 430x932 | 73 KB |
| `form__discard-dialog__800x1280__2026-09-08.png` | 800x1280 | 97 KB |
| `form__discard-dialog__375x667__2026-09-08.png` | 375x667 | 47 KB |
| `form__discard-dialog-rescue__430x932__2026-09-08.png` | 430x932 | 58 KB |
| `form__confirm-dialog-rescue__430x932__2026-09-08.png` | 430x932 | 57 KB |
| `form__scroll-1-of-2__430x932__2026-09-08.png` | 430x932 | 73 KB |
| `history__default__430x932__2026-09-08.png` | 430x932 | 60 KB |
| `history__default__800x1280__2026-09-08.png` | 800x1280 | 78 KB |
| `home__default__430x932__2026-09-08.png` | 430x932 | 44 KB |
| `home__default__800x1280__2026-09-08.png` | 800x1280 | 42 KB |

**10 files, 10 distinct md5s** — checked, because two captures taken while a dialog was still open
were byte-suspicious and were deleted rather than kept (see below).

⭐ **`form__discard-dialog` is a NEW STATE, and a dialog is named as a state of its parent screen**
— the convention `form__confirm-dialog` and `medication__delete-dialog` already set.

### Build, and why a version number is not evidence

| | |
|---|---|
| Built from | `97dfde0`, release APK, real keystore |
| Installed with | **`adb install -r`, no uninstall** — a debug signature or an uninstall destroys the 72 records |
| Version | `1.1.0` / `versionCode 53` — ⛔ **UNCHANGED from the previous install, so the version string cannot tell the two builds apart.** `lastUpdateTime` went `2026-09-07 23:49:09` → `2026-09-08 18:42:08` |
| Dialog present in the binary | ✅ **verified by scanning `libapp.so` in the APK** for `Discard your changes?`, `These changes have not been saved` and `Rescue medication: `, with `Confirm changes` as a known-present control and a known-absent probe returning nothing |

### Database state at capture time — the control for the whole pass

**Read from the device before and after, from the app's own accessibility tree, not from a note:**

| | Before | After |
|---|---|---|
| `Total saved` | **72** | **72** |
| `LAST EVENT` | **27 Aug 2026 · 16:41** | **27 Aug 2026 · 16:41** |
| `History` header | `72 events` | `72 events` |

⭐ **The matching TIMESTAMP is the stronger control, because a count can coincide.**

⚠️ **`This month` reads 0, where 30 August recorded 62.** That is the calendar rolling into
September, not data loss — and the unchanged 72 total is what establishes that.

### Procedure, including the part that was missing from this file

```
# adb is NOT on PATH and its location was recorded nowhere before today
export PATH="$PATH:/c/Users/wjl25/AppData/Local/Android/Sdk/platform-tools"

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb shell wm size            # MUST already read portrait before the override
adb shell wm size 430x932    # then 800x1280 (reset, native) then 375x667
adb shell wm size            # read back, guarded on the Override line

adb shell am start -n au.com.notiva.medicaleventrecorder/au.com.notiva.medical_event_recorder.MainActivity
adb shell uiautomator dump /sdcard/ui.xml   # Flutter exposes semantics as content-desc, not text
adb shell screencap -p /sdcard/s.png && adb pull /sdcard/s.png <name>

adb shell wm size reset
adb shell settings put system accelerometer_rotation 1
```

⚠️ **`MSYS_NO_PATHCONV=1` is required on Git Bash for every `/sdcard/...` path**, or the shell
rewrites it to a Windows path.

**Restore verified rather than assumed:** `Physical size: 800x1280`, `Physical density: 160`, **no
`Override` line**, `accelerometer_rotation` back to `1` and `user_rotation` at `0` — both their
pre-pass values.

### Findings from doing the work

⭐ **THE DISCARD FIX IS VERIFIED ON THE REAL DEVICE, THROUGH THE PATH THAT HAD NO GUARD AT ALL.**
A severity change followed by the **OS back key** produced *"Discard your changes?"* with
`• Severity: Mild → Severe`. Before 8 Sep 2026 the same gesture popped the screen silently.
**Discard then left the record reading `1m 45s · Mild`, unchanged.**

⭐ **AND THE RESCUE FIX, on the case that was empty before:** changing only *Rescue medication
given?* produced `• Rescue medication: not recorded → Yes` in **both** dialogs. ⛔ **`not recorded`
rather than `No` is the `bool?` null handling being right on a real record** — the three rescue
fields are nullable where referral is a plain bool, and null means *not asked*.

✅ **Dismissing the discard dialog behaves as Go back — confirmed by accident.** A mis-aimed tap at
800 hit the dialog barrier; the dialog closed and the form stayed open **with the edit intact**.
That is the widget test's assertion, reproduced on device without being planned.

⚠️ **`form__discard-dialog__375x667` WAS captured, against a prediction that it would fail.** The
reasoning had been that `form__confirm-dialog` is missing at 375 because *"the `Save changes`
button stayed below the fold after two scrolls"*, so the same would happen here. ⭐ **It does not:
the confirm dialog is reached by SAVE, which can be below the fold, and the discard dialog is
reached by BACK, which never is.** The prediction transferred a limit from one trigger to another
without checking that they share the trigger.

⚠️ **Two captures were taken while a dialog was still open and were DELETED, not kept.** A Discard
tap at 800 missed its target — the bounds were `[490,692][557,740]`, centre `(523,716)`, and the
tap went to `(620,690)` — so `home__default__800x1280` and `history__default__800x1280` were
photographs of the dialog. **Caught because the home capture was byte-identical in size to the
dialog capture.** Both re-taken after the state was confirmed by `uiautomator` rather than assumed.
⭐ **The general form: confirm the screen from the semantics tree BEFORE the screencap, not after.**

⚠️ **The most recent record does not open the form.** `Edit details` on home's Last Event card
routes `27 Aug 2026 16:41` to the **wizard**, because that record is incomplete and `wantsWizard`
is true. Reaching `LogEventScreen` needs a **complete** record from History — here the
`25 Aug 2026 22:17` row, `Seizure / fit · 1m 45s · Mild`. **Backing out of the wizard wrote
nothing, verified**, because nothing had been answered.

### ⛔ Not captured, and why — additions to the table above

| Layout | Reason |
|---|---|
| **`form__scroll-2-of-2` at 430** | Not attempted. The form's second screen is unchanged by the 8 Sep work, and `scroll-1-of-2` was taken only to date the current build |
| **`form__discard-dialog-rescue` at 375 and 800** | Not attempted. The 430 capture establishes the change-list content; the two widths add layout information the plain discard dialog already gives at all three |
| **The 200% text-scale set** | ⛔ **Deliberately out of scope for this pass.** There is no filename convention for text scale — nothing in the existing 99 files encodes one — and it needs its own decision. See `AUDIT.md` §13(u) |
| **`disclaimer` and `walkthrough` at any width** | ⛔ **Still unreachable — see the original table.** Both are pass 2b, on a disposable profile |

---

## Added 8 September 2026 — pass 1, the WINDOWS DESKTOP set

⛔ **THE FIRST REAL WINDOWS CAPTURES IN THIS SET. Nothing existing is modified.** Every earlier
file is either a 1x Android width proxy or a real iOS frame; these are Windows rendering Windows.

⛔ **AND THE METHOD IS NOT THE ONE USED FOR MOBILE.** `adb shell screencap` has no desktop
equivalent, and the obvious substitute — `Graphics.CopyFromScreen` — **photographs the screen
region where a window is, not the window.** It produced a false negative AND a false positive
within minutes on 8 Sep 2026: see `AUDIT.md` §13(aj). **It is not used here.**

### What was captured

| File | Client px | Bytes | md5 |
|---|---|---|---|
| `home__default__1012x546__2026-09-08-windows-desktop.png` | 1265x682 | 20 KB | `d4e90fd983ed` |
| `home__default__1216x622__2026-09-08-windows-desktop.png` | 1520x778 | 21 KB | `28821f212ad4` |
| `home__narrow__400x546__2026-09-08-windows-desktop.png` | 500x682 | 14 KB | `fb58ba363b62` |
| `home__narrowest-os-permits__94x546__2026-09-08-windows-desktop.png` | 118x682 | 9 KB | `96235a01dadc` |

**4 files, 4 distinct md5s.** Each was content-checked BEFORE being kept; a frame that failed the
check was deleted rather than kept with a caveat.

⚠️ **`history`, `form` and the discard dialog are NOT here** — see the not-captured table below.

### The method, and the proofs it passed

```powershell
# PrintWindow(PW_RENDERFULLCONTENT) into a WINDOW-rect bitmap, then crop to the CLIENT rect.
$wr = GetWindowRect($hwnd); $cr = GetClientRect($hwnd)
$off = ClientToScreen($hwnd, 0,0) - $wr.TopLeft        # 7,30 on this machine
$full = new Bitmap($wr.width, $wr.height)
PrintWindow($hwnd, $full.GetHdc(), 2)                   # 2 = PW_RENDERFULLCONTENT
$client = $full.Clone(Rectangle($off.X, $off.Y, $cr.R, $cr.B))
```

| Proof | Result |
|---|---|
| Two consecutive captures of an unchanged window | **byte-identical md5** |
| The same window **fully occluded** by a topmost form covering the whole screen | **BYTE-IDENTICAL** |
| Captured while MER was **not frontmost** | succeeded; `GetForegroundWindow` confirmed it was not |
| Offset **invariant to window position** on screen | 468 / 467 / 468 at x = 20, 250, 0 |

⚠️ **Three method faults were found and fixed getting there:** `PrintWindow` renders the WHOLE
window at 0,0 so a client-sized bitmap clips and includes the title bar; the **title bar repaints
on focus change** so window-rect captures of an unchanged window differ, which the client crop
removes; and `$h = Get-MerWindow` **silently overwrote the `$H` height parameter** because
PowerShell variables are case-insensitive.

### The frame-identity check

**Three decisive properties, each reported:** a ≥30-row contiguous `#0D4F82` app-bar band spanning
the full width, fewer than 900 distinct colours in a sample, and **all three theme colours present**
(`0D4F82`, `F5F8FB`, `FFFFFF`). **Demonstrated failing before being trusted** — a Gmail frame scored
`bar=0, distinct=1317, palette=False`; a magenta form and a desktop-only region both scored
`bar=0, palette=False`.

⛔ **IT VERIFIES IDENTITY, NOT COMPLETENESS.** Both mis-sized frames from the aborted attempt PASS
it, correctly, because they were MER — merely clipped. **Completeness is guaranteed by the METHOD**:
`PrintWindow` plus a `GetClientRect` crop is structurally independent of screen position.

⚠️ **A fourth property, `bgFrac`, was RETIRED — see §13(aq).** It rejected both narrow frames
because content legitimately fills more of a narrow frame. **The threshold was not loosened;
dropping it was tested against every negative, all of which still fail.**

### Window sizes, and why they are not the ones the source requests

| | |
|---|---|
| Monitor | **1536x864 physical**, DPI **120**, scale **1.25** — working area 1536x816 |
| `main.cpp` requests | `Size(1280, 720)` **logical** = **1600x900 physical** |
| ⛔ Fits? | **No, in either dimension** |
| OS-granted launch default | **1265x682 px = 1012x546 logical** |
| Machine maximum | **1520x778 px = 1216x622 logical** |
| Narrowest the OS permits | **118 px = 94.4 logical** — a Windows floor; MER enforces none |

### Database state at capture time

⛔ **THERE IS NO APP DATA ON THIS MACHINE, so the before-and-after record discipline had nothing to
guard.** A sweep of `AppData` found one directory — `Local\Packages\Notiva.MedicalEventRecorder_…`,
the MSIX install of 25 Aug 2026 — holding **2 files, 16 KB, no database and no preferences.** The
launches in this pass created none, verified after closing. ⚠️ **That is a fact about THIS MACHINE,
not about the build.**

⭐ **Consequence worth recording: the disclaimer and walkthrough gates are UNSET on Windows**, so the
two screens that are uncapturable on the tablet without `pm clear` are reachable here for free.

### ⛔ Not captured, and why — additions to the table above

| Layout | Reason |
|---|---|
| **`history`, `form`, the discard dialog** | ⛔ **Desktop has no `uiautomator` equivalent.** Every tablet capture was confirmed against the accessibility tree before the shot; on Windows the only route was pixel-hunting, and a search of the app bar's top-right band for a menu glyph returned **0 white-ish pixels**. After §13(aj), guessing at coordinates was not an acceptable method. See §13(ap) |
| **The wide-desktop case (1920)** | ⛔ **Not possible on this machine.** The maximum logical client the 1536x864 display allows is about 1216x622 |
| **The 200% text-scale set** | Still out of scope, and still without a filename convention — see §13(u) |
| **DPI-96 test frames** | ⚠️ **Deliberately NOT kept in this set.** Two frames were captured at `GetDpiForWindow = 96`, via a per-process `__COMPAT_LAYER=DPIUNAWARE` launch, to settle §13(al). **They are evidence about a DEFECT, not records of how the app looks** — the app does not run at 96 DPI on this machine. Their measurements are in §13(al) |
