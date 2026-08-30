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
