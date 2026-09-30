# Release 1.1.2 — the list

**Created 30 September 2026 (Brief 310).**

⛔ **As at 30 September 2026 no 1.1.2 list existed in the repo. Items described in conversation
as "on the 1.1.2 list" before this date were recorded nowhere. This file is that list.**

This file records items. It fixes nothing. Each item gives what it is, the evidence, the date it
was found, and whether it is a **CLAIM** about app behaviour (something a user reads or relies
on) or **TOOLING** (build, test, release process). Claim items come first because they have
user-facing consequences.

**Verification state**, checked against the repo, the ledger and the code on 30 September 2026
at `c43ca57`, before each item was written down:

| Mark | Meaning |
|---|---|
| ✅ | verified from the repo, the ledger or the code |
| ◐ | partly verified; the part that is not is named |
| ⚠️ | **[unverified — chat half's recollection, 30 Sep 2026]**: kept, not dropped |
| ⛔ | **contradicted by the repo**: the recollection as given, then what the repo shows |

---

## CLAIMS: what the app tells the user

### 1. About: "Data storage" / "Local device only" ✅
- **What:** a label/value row asserting that the data is in one place only. This is the
  exclusivity shape banned on 26 Sep 2026.
- **Evidence:** `lib/screens/about_screen.dart:130`, `_InfoRow(label: 'Data storage', value:
  'Local device only')`. It is rendered on every platform (the file has no platform branch) and
  reached from home's drawer (`AboutScreen(`, `home_screen.dart`).
- **True?**
  - **iOS: false.** `AppDelegate.swift` records *"NO iOS BACKUP EXCLUSION, DELIBERATELY"*
    (Brief 229, 28 Sep 2026), so the data goes into iCloud Backup and device transfer when those
    are on.
  - **Android:** true as far as the app controls it. `allowBackup="false"`, plus
    `dataExtractionRules` with 10 excludes covering cloud backup and device transfer. A user's
    own export or backup file is the user's copy.
  - **Windows: not established.** The database is in `getApplicationSupportDirectory()`, and the
    repo does not record whether any Windows backup or roaming mechanism copies it.
- **Found:** 30 Sep 2026 (developer screenshot, iOS 1.1.1; located by Brief 308).

### 2. About footer: "All data is stored locally on your device." ✅
- **What:** the same shape in prose: *"For personal record‑keeping only. Not a medical device.
  … All data is stored locally on your device."*
- **Evidence:** `lib/screens/about_screen.dart:181`, a `Text`, every platform.
- **True?** As item 1 on each platform: false on iOS as an exclusivity claim.
- **Found:** 30 Sep 2026, Brief 308.

### 3. Disclaimer, "Data storage & privacy": "stored locally on your device" ✅
- **What:** *"All event data entered into this application is stored locally on your device.
  The developer does not collect, transmit or store your personal or medical information."* The
  second sentence is true. The first has the exclusivity shape.
- **Evidence:** `lib/screens/disclaimer_screen.dart:233`, every platform. Shown on first run and
  on a disclaimer version bump (`DisclaimerScreen(` in `main.dart` and `_SplashRedirect`).
- **True?** As item 1 on each platform.
- ⭐ **This one is inside a file Brief 298 covered**: the same "Data storage & privacy" section,
  ten lines above `bf5a2ae`'s first hunk (+243). So Brief 298's gap was **both** its file set
  (`about_screen.dart` was not in it) **and** its method within a covered file.
- **Found:** 30 Sep 2026, Brief 308.

**How items 1–3 were found (Brief 308):**
- **The sweep:** a sweep for the claim SHAPE (an exclusivity word beside a data or location
  word) over every assembled user-facing string at `c43ca57`. It covered 61 files
  (`lib/**/*.dart`, iOS Swift, plists and strings, Android `res/*.xml`) and 2,165 strings, with
  adjacent and `+`-joined literals assembled and every platform arm included. It produced 25
  candidates, adjudicated by hand.
- **Controls:** run on `65a9dcf`, the same sweep flags all ten claims `bf5a2ae` removed; at
  `c43ca57` it flags none of them. It also finds a phrase that exists only when literals are
  joined, finds native strings, and misses a nonsense string.
- **Not swept:** store listing and metadata text, which the repo does not hold.

### 4. For judgement: "Your events stay in the app" ✅ (the text exists; whether it is a claim is the judgement)
- **What:** the new title from `bf5a2ae`. Read alone it is the "stays in" shape. Its own body,
  directly beneath it, says *"Your device's own backup may include them."*
- **Evidence:** `lib/screens/help_screen.dart:381` and `lib/screens/walkthrough_screen.dart:129`.
- **Found:** 30 Sep 2026, Brief 308.

### 5. For judgement: "A backup file is the only copy you control" ✅ (the text exists)
- **What:** an exclusivity word about control, not location. On iOS the device's own backup is
  arguably also a copy the user controls.
- **Evidence:** `lib/screens/help_screen.dart:414` and `lib/screens/walkthrough_screen.dart:175`.
- **Found:** 30 Sep 2026, Brief 308.

### 6. The corrected data-location copy is iOS-only this release ◐ / ⛔ in one word
- **As recollected:** "Android 1.1.1 (64) **shipped** with the pre-`bf5a2ae` copy."
- ⛔ **"Shipped" is contradicted.** Ledger row 64 (Android) says *"Not uploaded"*; it went to
  the Teclast P30 only.
- ✅ **What is true:** Android's latest build, 64, was built from `4da1751` (28 Sep 2026), and
  `bf5a2ae` (30 Sep 2026) is **not** its ancestor (`git merge-base --is-ancestor`). The corrected
  wording exists only in iOS 65. The ledger records no Android 65.
- **Found:** 30 Sep 2026.

### 7. Hidden events are not marked in the Your-data export ✅
- **What:** "Export all events" on Your data writes every record, including hidden ones, and the
  CSV has no column that says which are hidden.
- **Evidence:**
  - `home_screen.dart` passes `_records` to `showExportOptions` for Your data's `onExport`.
  - `_records` is the complete list, which home's own comment calls out: *"ONE derived view
    excludes hidden rows"*.
  - `buildCsv` (`lib/models/event_record.dart`) has no `hidden` column (0 occurrences in its
    body).
- **Found:** before 30 Sep 2026 (recollection); verified 30 Sep 2026.

### 8. History's crossed-out-eye glyph reads as "all suppressed" ◐
- ✅ **The glyph exists:** `Icons.visibility_off_outlined`, `lib/screens/history_screen.dart:1964`.
  It changed from `delete_outline` when the action became a hide
  (`a11y_batch_render_comparison_test.dart`, Brief S note, 17 Sep 2026).
- ⚠️ **How users read it** [unverified — chat half's recollection, 30 Sep 2026]. No user
  observation of that reading is in the repo.

### 9. Privacy policy §6 describes session tracking ⚠️ / ◐
- ⚠️ **§6's content** [unverified — chat half's recollection, 30 Sep 2026]. The policy is not in
  this repo, and the Notiva site repo is not on this Mac.
- ✅ **The dependency is real:** `enableAutoSessionTracking` is set nowhere in `lib/`, so the
  Sentry SDK's default applies. `bf5a2ae`'s own new copy says the diagnostic reports record
  *"when the app is opened as a count of sessions"*. If item 12 turns session tracking off, both
  that copy and §6 would need to change with it.

---

## TOOLING: build, test, release

### 10. MERWidget hardcodes its version; Apple warns 90473 on every upload ✅
- **Evidence:**
  - `ios/MERWidget/Info.plist` carries the literals `CFBundleShortVersionString` `1.0.1` and
    `CFBundleVersion` `2`.
  - In `project.pbxproj` the MERWidget target sets neither `MARKETING_VERSION` nor
    `CURRENT_PROJECT_VERSION` in Debug, Release or Profile. The `MARKETING_VERSION = 1.0` lines
    in the file belong to RunnerTests.
  - Apple's 90473 warning is recorded on ledger rows 5, 64 and 65.
- **Found:** 29 Sep 2026 (rows 5 and 64).

### 11. Sentry release string collides across platforms ◐
- ✅ **In code:** `AppInfo.sentryRelease` is `'$packageName@$version+$buildNumber'`, set in
  `beforeSend`, with no `dist`. iOS's bundle id and Android's `applicationId` are the same
  string, so the same code on both platforms gives the same release. Both platforms have a
  build 64 (ledger), so the collision exists at 64.
- ⚠️ **That Sentry has actually received events from both 64s** [unverified — chat half's
  recollection, 30 Sep 2026]. It is not observable from the repo.
- **Found:** 30 Sep 2026, Brief 306.

### 12. `enableAutoSessionTracking = false` ✅ (current state verified; the change is the item)
- **Evidence:** not set anywhere in `lib/` as at 30 Sep 2026, so the SDK default applies. See
  item 9 for the copy and the policy text that depend on it.

### 13. `a11y_batch_render_comparison_test` baselines have never passed on the Mac ✅
- **What:** all four screens × three widths fail on the Mac with the paragraph count matching
  and only the hash differing.
- **Evidence:**
  - The test's own comment says home's baseline *"was captured on Windows"*.
  - `018c4c6` (23 Sep 2026) records the same four failing on the Mac.
  - Brief 302 (30 Sep 2026): identical output at `65a9dcf`, `bf5a2ae` and `1b4e723`, with full
    paragraph dumps identical across commits, so it is unrelated to the copy change.
- **Direction:** per-host baselines, not deletion.

### 14. `checklist_citations_test`: two failures ◐ / ⛔ in the description
- **As recollected:** "two Mac-only **path** failures."
- ⛔ **The description is contradicted.** Both tests fail ("every cited symbol appears…" and
  "every cited path resolves"), but they list **checklist citations of host-side things the test
  cannot find in the repo**: profile UUIDs, `xcodebuild`, `mds_stores`, `willQuit`,
  `/Applications/OneDrive.app`, `~/.sentryclirc`, and others. These are all in §12, §13 and
  Sign-off, written from 29 Sep 2026. Whether they also fail on Windows is not established here.
- ✅ **And it grew on 30 Sep 2026, by this project's own hand:** 14 unresolvable citations at
  Brief 301's run, 16 at `c43ca57`. The two new ones are `.p8` (Sign-off, from `1adf6b3`) and a
  second `~/.sentryclirc` (Sign-off, from `c43ca57`). The failing-test count stayed at 2, which
  is why nothing announced it.

### 15. Xcode's App Store Connect session expires; sign in before an Organizer upload ✅
- **Evidence:** `docs/iOS Device Test Checklist.md` §12 (Brief 242, 29 Sep 2026) and the Sign-off
  App Store Connect upload step (Brief 305). Brief 301's export log (30 Sep 2026) contains
  *"Your session has expired. Please log in."*, and provisioning still succeeded.

### 16. The `.p8` App Store Connect key is Mac-only and single-copy ✅ (as recorded; a report, not re-measured)
- **Evidence:** `STATUS.md` records it as *"Mac-only and single-copy by design"*, repeated in the
  Sign-off upload step. A single point of failure for the altool route.

### 17. The mirror-residual recovery fix ⚠️
- [unverified — chat half's recollection, 30 Sep 2026]. No defect or fix by this name is
  recorded in the repo. A "pre-inbox record mirror" does exist in code (`AppDelegate.swift`,
  `lib/services/ios_capture_bridge.dart`, `home_screen.dart`), which may be what it refers to.
  That link is not established.

### 18. `details_completed` is set on wizard PRESENTATION, not completion ⛔
- **As recollected:** as the title says.
- ⛔ **Contradicted by the code.** `detailsCompleted: true` is written in exactly two places:
  - the wizard's `_finish()` (`Navigator.pop(context, _build(completed: true))`, completion);
  - the single-page form's save (`log_event_screen.dart:487`).

  Opening or backing out of the wizard writes `_capturedCompletion`: `false` for a new record,
  the existing value otherwise, never `true`. New records get `false` (`home_screen.dart:1175`,
  `capture_inbox.dart:181`). So the repo shows the opposite of the recollection. If there is a
  real defect behind it, it is not this one as worded.

### 19. The wizard runs once per drain; a dashboard tile was discussed ◐
- ✅ **Mechanism:** a notification tap opens details for the ONE record that notification named
  (`_openEventFromNotification` → `resolveNotificationRouting` → `_openDetails`). Nothing walks
  the other records a drain brought in.
- ⚠️ **The tile** ("N more events waiting for details") [unverified — chat half's recollection,
  30 Sep 2026]. It exists only as a discussion, and no such wording is in `lib/`.

---

**Count at creation, 30 Sep 2026:** 19 items.
- ✅ **11 verified:** 1, 2, 3, 4, 5, 7, 10, 12, 13, 15, 16.
- ◐ **5 partly verified:** 6, 8, 11, 14, 19. Items 6 and 14 each carry a ⛔ on one word or
  description.
- ⚠️ **2 unverified:** 9, 17.
- ⛔ **1 contradicted outright:** 18.
