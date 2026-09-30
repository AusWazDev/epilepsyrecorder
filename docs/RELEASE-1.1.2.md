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
- ⛔ **Correction, Brief 311, 30 Sep 2026.** On 30 Sep 2026 the chat half described Brief 298's
  gap as a **file-set** gap. That was too generous. Line 233 is in the same section Brief 298
  edited, ten lines above its first change (re-checked: `bf5a2ae`'s first changed line is +243,
  and line 233 holds the same string at `bf5a2ae` and at `ec4c99d`). A file-set gap would mean
  the brief never looked at this file. It did look, and it edited this section. **The gap was the
  METHOD WITHIN A FILE IT COVERED, not only its file set.**
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

### 4. Decided KEEP, with a dependency: "Your events stay in the app" ✅
*Heading before Brief 311: "For judgement: "Your events stay in the app" ✅ (the text exists;
whether it is a claim is the judgement)".*
- **What:** the new title from `bf5a2ae`. Read alone it is the "stays in" shape. Its own body,
  directly beneath it, says *"Your device's own backup may include them."*
- **Evidence:** `lib/screens/help_screen.dart:381` and `lib/screens/walkthrough_screen.dart:129`.
- **Found:** 30 Sep 2026, Brief 308.
- ✅ **Decision, Brief 311, 30 Sep 2026: KEEP, with a recorded dependency.** The heading is true
  **only alongside the sentence beneath it** (*"Your device's own backup may include them."*).
  Its truth is borrowed from that body text, not its own.
- ⛔ **If that body text is shortened, moved, or the heading is reused anywhere without it, the
  heading becomes a bare containment claim and must be rewritten.** That applies to both sites
  above. Any edit to either body is an edit to this heading's truth.

### 5. Decided KEEP: "A backup file is the only copy you control" ✅
*Heading before Brief 311: "For judgement: "A backup file is the only copy you control" ✅ (the
text exists)".*
- **What:** an exclusivity word about control, not location. On iOS the device's own backup is
  arguably also a copy the user controls.
- **Evidence:** `lib/screens/help_screen.dart:414` and `lib/screens/walkthrough_screen.dart:175`.
- **Found:** 30 Sep 2026, Brief 308.
- ✅ **Decision, Brief 311, 30 Sep 2026: CONFIRMED KEEP.** It passes because it is **scoped to
  the user's control**, per the standing rule: it says which copy the user controls, not where
  the data is.
- **Re-examine it at every copy review, and expect it to pass.** A failure there would mean the
  wording or the scope has changed.

### 6. The corrected data-location copy exists only in iOS 65; Android 64 was never uploaded ✅
*Heading before Brief 311: "The corrected data-location copy is iOS-only this release ◐ / ⛔ in
one word".*
- ✅ **What is true (Brief 311, 30 Sep 2026), replacing "shipped with the old copy":** Android
  1.1.1 (64) **was not uploaded**. It was only installed on the Teclast P30. Its source,
  `4da1751`, predates `bf5a2ae`, so **the corrected wording exists only in iOS 65.** The superseded
  wording is quoted in the next bullet.
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
- **Routing, Brief 311, 30 Sep 2026: a WINDOWS job.** It stays unverified and marked until it is
  read on Windows, where the `notiva-site` repo is.
- ✅ **The dependency is real:** `enableAutoSessionTracking` is set nowhere in `lib/`, so the
  Sentry SDK's default applies. `bf5a2ae`'s own new copy says the diagnostic reports record
  *"when the app is opened as a count of sessions"*. If item 12 turns session tracking off, both
  that copy and §6 would need to change with it.

---

## TOOLING: build, test, release

⬆ **Priority raised, Brief 311, 30 Sep 2026: items 20, 13 and 14 lead this section.** They were
moved here from their numbered places; the numbers are unchanged so that references still hold.
**Why:** a permanently red test is not inert noise. It is a place where new defects land unseen,
and 30 September 2026 is the demonstration (item 20).

### 20. A test that is already failing absorbs new failures unseen: its signal is saturated ✅
- **Recorded 30 Sep 2026 (Brief 311).**
- **What happened:**
  - `checklist_citations_test`'s unresolvable citations rose from **14** (Brief 301's run) to
    **16**. The failing TEST count stayed at **2**, so nothing reported the change.
  - Two of the new citations were added by **chat-half briefs on 30 Sep 2026**: `.p8` (Sign-off,
    checklist line 851, from `1adf6b3`) and a second `~/.sentryclirc` (Sign-off, checklist line
    805, from `c43ca57`).
  - Re-run at `ec4c99d` for this entry: 10 unresolved symbols plus 6 unresolved paths (16), in 2
    failing tests out of 6 in the file, with `.p8` at line 851 and `~/.sentryclirc` at lines 794
    and 805. Both lines were attributed with `git log -L`.
- ⭐ **The general form: a test that is already failing absorbs further failures without any
  change in its output. Its signal is saturated.**
- **The same property holds for `a11y_batch_render_comparison_test` on the Mac** (item 13),
  which has never passed there. A new rendering regression on any of its four screens would be
  one more red case in a test that is already red.
- ⚠️ **Open question, not a decision:** should either test report a **COUNT** rather than a
  pass/fail, so that "worse" shows while it stays red? **Not implemented. Nothing in `test/` is
  changed by this entry.**

### 13. `a11y_batch_render_comparison_test` baselines have never passed on the Mac ✅
*Moved up and priority raised, Brief 311, 30 Sep 2026: its red state is a saturated signal on
the Mac (item 20).*
- **What:** all four screens × three widths fail on the Mac with the paragraph count matching
  and only the hash differing.
- **Evidence:**
  - The test's own comment says home's baseline *"was captured on Windows"*.
  - `018c4c6` (23 Sep 2026) records the same four failing on the Mac.
  - Brief 302 (30 Sep 2026): identical output at `65a9dcf`, `bf5a2ae` and `1b4e723`, with full
    paragraph dumps identical across commits, so it is unrelated to the copy change.
- **Direction:** per-host baselines, not deletion.

### 14. `checklist_citations_test`: citations of host artefacts the test cannot resolve in the repo ✅
*Heading before Brief 311: "`checklist_citations_test`: two failures ◐ / ⛔ in the description".
Moved up and priority raised, Brief 311, 30 Sep 2026: its red state is a saturated signal (item
20).*
- ✅ **Description, Brief 311, 30 Sep 2026, replacing "two Mac-only path failures":** citations
  of host artefacts that the test cannot resolve in the repo, written into §12, §13 and Sign-off
  from 29 Sep 2026 onward. The superseded wording is quoted in the next bullet.
- **As recollected:** "two Mac-only **path** failures."
- ⛔ **The description is contradicted.** Both tests fail ("every cited symbol appears…" and
  "every cited path resolves"), but they list **checklist citations of host-side things the test
  cannot find in the repo**: profile UUIDs, `xcodebuild`, `mds_stores`, `willQuit`,
  `/Applications/OneDrive.app`, `~/.sentryclirc`, and others. These are all in §12, §13 and
  Sign-off, written from 29 Sep 2026. Whether they also fail on Windows is not established here.
- ✅ **And it grew on 30 Sep 2026, by this project's own hand:** 14 unresolvable citations at
  Brief 301's run, 16 at `c43ca57`. The two new ones are `.p8` (Sign-off, from `1adf6b3`) and a
  second `~/.sentryclirc` (Sign-off, from `c43ca57`). The failing-test count stayed at 2, which
  is why nothing announced it. Recorded as a finding in its own right as item 20.

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
- **Routing, Brief 311, 30 Sep 2026: stays unverified and marked.** Nothing by that name exists
  in the repo. A pre-inbox record mirror does exist. **The chat half cannot substantiate the
  connection between the two.** The item may be a garbled recollection.

### 18. WITHDRAWN, not a defect: the chat half asserted a behaviour the code refuses ⛔
*Heading before Brief 311: "`details_completed` is set on wizard PRESENTATION, not completion
⛔".*
- ⛔ **Removed from the defect list, Brief 311, 30 Sep 2026.** It is not counted as an item and
  nothing is owed on it. **Recorded in its place: on 30 Sep 2026 the chat half asserted a
  behaviour of `details_completed` that the code refuses.** `detailsCompleted: true` is set only
  in the wizard's `_finish()` and the single-page form's save (below).
- **Why it is kept and not deleted:** a wrong item that vanishes teaches nothing. The original
  entry stands below as written.
- **As recollected:** as the title says. (Since Brief 311 that means the heading before
  Brief 311, quoted above.)
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

**Count after Brief 311, 30 Sep 2026:** 19 items on the list, plus item 18 kept as a
withdrawn record. The count at creation, above, is left as written.
- ✅ **14 verified:** 1, 2, 3, 4, 5, 6, 7, 10, 12, 13, 14, 15, 16, 20. Items 6 and 14 moved from
  ◐ when their wrong wording was replaced with what the repo shows. The superseded wording is
  quoted in each. Item 20 is new.
- ◐ **3 partly verified:** 8, 11, 19.
- ⚠️ **2 unverified:** 9 (a Windows job), 17.
- ⛔ **Withdrawn, not counted:** 18.
- ⬆ **Priority raised:** 20, 13, 14 (they lead TOOLING).
- **Decided:** 4 (KEEP, with a dependency) and 5 (CONFIRMED KEEP).
