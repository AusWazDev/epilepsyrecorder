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

### 6. The corrected data-location copy exists only in iOS 65; Android 64 was never uploaded ✅ ⛔ SUPERSEDED BY MEASUREMENT, 30 Sep 2026: see the last bullet
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
- ⛔ **SUPERSEDED BY MEASUREMENT, 30 September 2026 (Brief 313); this item's text is left as
  written.** A Play Console read by the chat half at about 19:30 AEST shows *"Release 64 (1.1.1)
  in review · 172 countries / regions"*. **Android 1.1.1 (64) WAS uploaded,** to the production
  track, and is in review. It carries the pre-`bf5a2ae` copy, which Brief 295 found true on
  Android except the disclaimer's crash-report sentence.
  ⭐ **Why this item was wrong: it inherited a stale row rather than making its own reading.**
  Ledger row 64's *"Not uploaded"* was written on 28 September and never updated, because the
  upload was the developer's own action in the Play Console and left no trace in the repo. This
  item, dated 30 September, restated that row, so by date alone it outranked its own source. The
  failure is the method, not the fact: **before ranking a dated statement, ask what it was read
  from.** Row 64 is annotated in place the same day.

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
- ◐ **Annotated 19 Nov 2026 (Brief MER-REL-1 A, handover item 12); the bullets above are left as
  written.** The AEL session's handover restates this item as *"History's crossed-out eye ('Hide
  this event') reads as 'hidden'"*. Recorded here rather than as a new item.
  - ✅ **Still in place, re-read 19 Nov 2026:** `Icons.visibility_off_outlined` with the tooltip
    `'Hide this event'`, `history_screen.dart` (cited by symbol, not line).
  - ⚠️ **The reading is still unobserved.** The handover's wording ("reads as hidden") is a second
    report of the same concern, not a user observation.

### 9. Privacy policy §6 describes session tracking ⚠️ / ◐
- ⚠️ **§6's content** [unverified — chat half's recollection, 30 Sep 2026]. The policy is not in
  this repo, and the Notiva site repo is not on this Mac.
- **Routing, Brief 311, 30 Sep 2026: a WINDOWS job.** It stays unverified and marked until it is
  read on Windows, where the `notiva-site` repo is.
- ✅ **The dependency is real:** `enableAutoSessionTracking` is set nowhere in `lib/`, so the
  Sentry SDK's default applies. `bf5a2ae`'s own new copy says the diagnostic reports record
  *"when the app is opened as a count of sessions"*. If item 12 turns session tracking off, both
  that copy and §6 would need to change with it.
- ✅ **Annotated 19 Nov 2026 (Brief MER-REL-1 A): §6's content is now READ, on Windows, as item 9
  routed it. The ⚠️ above is left as written.**
  - `notiva-site`, `src/pages/medical-event-recorder/privacy/index.astro`, section *"6.
    Third-Party Services"*: *"The service also records when the app is opened and for how long,
    as a count of sessions; that carries no information about what you did in the app."* Last
    changed in `d23ca2c` (18 Oct 2026).
  - ⭐ **And a second dependent sentence the item did not know about**, in section *"4. Data We Do
    Not Collect"*, from `dd55bdc` (30 Sep 2026): *"Each installation of the app is given a random
    identifier by the error-reporting service … It is created when the app is first installed
    and is stored with the app's own files; using Reset does not change it."* The same section
    lists *"Device identifiers"* among the data not collected, three lines above.
  - The in-app copy is still at `disclaimer_screen.dart` (*"app is opened as a count of
    sessions"*).
  - **All three change when item 26 ships.** See item 26.

### 22. About shows "1.1.1" with no build number ✅
- **What:** About gives the version name only. On Windows there is no other way for a user to
  tell us which build they have, so a report from the field cannot be tied to a ledger row.
- **Evidence:**
  - Observed in MER-W4 on 17 Oct 2026, on the 1.1.66.0 test install: About read "1.1.1".
  - From the code: `about_screen.dart` renders `AppInfo.version` in its title line
    (`'Version ${AppInfo.version}'`) and in its "Version" row. `AppInfo.buildNumber` is not shown
    on either.
  - Cited by symbol, not line.
- **Found:** 17 Oct 2026, Brief MER-W4 (ledger, "Row 66 device test").

*Items 26 to 37 below were added 19 Nov 2026 by Brief MER-REL-1 Part A, from the AEL session's
handover (`claude/HANDOVER-MER-from-AEL-session-2026-11-19.md`). Each was checked against the code
at `88657e1` before it was written. Handover item 12 is recorded on item 8, not here.*

### 26. Strip the Sentry per-install ID and session tracking (decision A4) ◐
- **What:** the native Sentry SDKs attach a per-install identifier to reports, and session
  tracking is on by default. Decision A4 removes both.
- ✅ **From the repo and the resolved packages:**
  - One Sentry init in `lib/`: `SentryFlutter.init(configureSentryOptions, …)` in `main()`. No
    Swift file initialises Sentry (`AppDelegate.swift` mentions it only in a comment).
  - `sendDefaultPii = false` (`configureSentryOptions`). No `setUser` anywhere in `lib/`.
  - `enableAutoSessionTracking` is unset, so it is `true` (item 12, re-read today).
  - Resolved, not pinned: `pubspec.yaml` says `sentry_flutter: ^9.0.0`; `pubspec.lock` resolves
    9.19.0; the plugin's `android/build.gradle` names `io.sentry:sentry-android:8.39.1`; its
    podspec and `ios/Podfile.lock` name `Sentry/HybridSDK` 8.58.1; its Windows build fetches
    sentry-native 0.13.7 (`sentry-native/CMakeCache.txt`).
  - Android, read from the compiled `sentry-android-core-8.39.1.aar` in the Gradle cache (a byte
    search of `classes.jar`, 198 classes): the class `io.sentry.android.core.Installation` holds
    the string `INSTALLATION`, and `DefaultAndroidEventProcessor`, `DeviceInfoUtil`,
    `AndroidOptionsInitializer`, `InternalSentrySdk` and `ApplicationExitInfoEventProcessor`
    reference it.
- ⚠️ **Not established here** [report: MER-SENTRY-2, at `5fce27e`]:
  - that the ID is set as `user.id`, `device.id` and session `did`;
  - that this happens **regardless of `sendDefaultPii`**. `DefaultAndroidEventProcessor` also
    reads `isSendDefaultPii`, so a byte search cannot say which fields the flag gates. Needs the
    source or a decompile;
  - anything about iOS (Sentry Cocoa is not on this machine) or Windows.
- ⭐ **When this ships, three texts change with it:** item 9's policy §6 sessions sentence, the
  policy's §4 install-identifier paragraph (see item 9's annotation), and `bf5a2ae`'s in-app
  copy in `disclaimer_screen.dart` (*"a count of sessions"*). Item 29's store labels revert too.
- **Overlaps:** item 12 is this item's sessions half; item 9 holds the dependent texts.
- **Found:** before 19 Nov 2026 (MER-SENTRY-2); recorded 19 Nov 2026.

### 27. Sanitiser gap: a native error's message reaches Sentry through `mechanism.data` ✅
- **What:** `sanitiseEventValues` (`main.dart`, CR-49, MER-F5, "default-deny") rewrites each
  exception's `value`, but never touches `mechanism.data`. The SDK copies a
  `PlatformException`'s `message` there.
- **Evidence:**
  - MER's own doc comment on `sanitiseEventValues` says so: *"Stack frames, types, levels,
    mechanisms and SDK contexts are untouched."* The body has no `mechanism` reference.
  - `sentry_flutter` 9.19.0, `platform_exception_event_processor.dart`: *"Add code & message
    from [PlatformException] to [SentryException]"*, and `data['message'] =
    platformException.message;`.
  - AEL `4e91232` (read-only, for comparison): its commit body says the same loop *"never"*
    reached `mechanism.data['message']`, found by a test in which a store message's text
    reached the transport. Its fix keeps `code` and withholds every other value. Its own
    comment: *"Inherited from MER, which has the same loop and the same SDK; MER is not changed
    here."*
  - ⚠️ **Correction to the brief's framing:** `4e91232`'s subject is *"Sentry: report to AEL's own
    project"*. The sanitiser fix is one hunk inside it, not a commit of its own.
- **Why it is a claim:** the disclaimer says reports *"are designed not to include anything you
  have recorded"*. A `PlatformException` message can carry whatever the native side put in it.
- ⚠️ **Not established:** whether any MER `PlatformException` today carries user text in its
  message. Part B sizes this.
- **Found:** 17 Nov 2026 by AEL (AV-18); confirmed in MER 19 Nov 2026.

### 29. Store privacy labels: declare the install ID until item 26 ships, then revert ⚠️ ⛔ HELD
- ⛔ **HELD: developer approval not given. Recorded only. No console is touched.**
- **What (report):** Play Data safety ("Device or other IDs") and App Store App Privacy ("Device
  ID") would declare the identifier while it is sent, and be reverted when item 26 ships.
- ⚠️ **Console state is not readable from the repo.** The App Store label's current state was not
  read by anyone (handover).
- ✅ **What the repo shows:** the published privacy policy already discloses the identifier
  (section 4, `dd55bdc`, quoted on item 9), while the same section lists *"Device identifiers"*
  as not collected. So the policy and any label that says "no device ID" disagree today.
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 30. Store listing: "nothing is sent to the cloud or any third party" ◐
- ✅ **The sentence is recorded in the repo as live on the App Store:** `STATUS.md`, App Store
  Connect audit of 28 Aug (*"The unqualified privacy claim (… "nothing is sent to the cloud or any
  third party", against Sentry) is the one Apple reviews against"*). It is not in `notiva-site`
  (searched `src/`, no hit). Whether it is still live: ⚠️, console.
- ✅ **False** against Sentry generally (crash reports go to a third party) and against item 26
  (a per-install identifier goes with them).
- ⛔ **The "26 Sep replacement" was not found.** No file in this repo or in `notiva-site` holds a
  replacement dated 26 Sep. What exists is older: `docs/Store Listing Copy — v1.1 revision.md`
  (Briefs 42, 43, 63 Part D; 18 to 20 Sep 2026), marked *"Not applied anywhere."* Its PRIVACY
  block replaces the sentence with:
  - *"Your event data is stored only on your device"*: the exclusivity shape banned on 26 Sep
    2026 (items 1 to 3), and false on iOS for the same reason as item 1;
  - *"Anonymous crash reports help fix faults; they contain no event data"*: "anonymous" is
    contradicted by item 26 if the install ID is confirmed.
  - **So that replacement is itself stale against two later findings.** Do not paste it as is.
- **Found:** by 28 Aug 2026 (the App Store Connect audit in `STATUS.md`); recorded here 19 Nov
  2026.
- ◐ **Annotated 23 Nov 2026 (Brief MER-REL-2, item 2); the bullets above are left as written.**
  **The same class of claim exists in the app**, and is recorded as item 40. Both say there is no
  remote recipient, and Sentry contradicts both. Help's *"has no account and no server"* is the
  unqualified in-app form; the disclaimer's and walkthrough's *"no server of ours"* are scoped.
  Different surfaces, so they need different fixes: this item is store console text, item 40 is
  code. Keep them together when the wording is decided.

### 31. Play Data safety: "Data can't be deleted" ⚠️ (console) / ✅ (what the repo says)
- ⚠️ **The console answer** [report: handover]. Not readable from the repo.
- ✅ **Deletion paths in the app and policy, for checking that answer later:**
  - **Reset:** About's *"Reset app (clear all data)"*, `onReset` → `_confirmResetDisclaimer`
    (`home_screen.dart`); the store side empties `kResetClearedTables`
    (`event_store_sqlite.dart`). Its own copy: *"This cannot be undone."*
  - **Hide is not delete:** policy section 7, *"Removing individual events hides them from the
    history rather than erasing the underlying record"*.
  - **Uninstall:** Android `allowBackup="false"` with `dataExtractionRules` (item 1), so uninstall
    removes the app's data; on iOS a device backup can keep a copy (policy section 3).
  - **Sentry-held data:** no user deletion path in the app. The install ID survives Reset (policy
    section 4).
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 32. Live Activity "End" control may clip ◐
- ✅ **MER has two End controls**, both `Button(intent: EndMEREventIntent())` in
  `ios/MERWidget/MERLiveActivity.swift`:
  - one with `Label("End", systemImage: "stop.circle.fill")`: text plus icon;
  - one, under `if #available(iOS 17.0, *)`, with `Text("Event Ended")`, padded and on a red
    background.
- **Reference only (decision A1, no code moves):** AEL made its control icon-only in `48ffaa0`.
- ⚠️ **That MER's control clips** is not observed in the repo. It needs a device or simulator look,
  in Release per this repo's simulator rule.
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 37. D1 donation not built; the Terms still promise a paid app ✅
- ✅ **No donation mechanism:** `grep -rni donat lib/` returns nothing at `88657e1`. Control: the
  same command for `sentry` returns hits (28 in `main.dart` alone), so the search runs.
  `STATUS.md` row M1-M4 records the same.
- ✅ **The Terms** (`notiva-site`, `src/pages/medical-event-recorder/terms/index.astro`, read
  19 Nov 2026 at `5dcd6a3`):
  - line 18: *"Medical Event Recorder is a paid, one-time purchase app for recording personal
    health events."*
  - line 38: *"The app is a <strong>one-time paid purchase</strong>. No subscription or ongoing
    fee applies."*
  - ⭐ **and a third D1 does not cite**, line 82: liability *"is limited to the amount you paid for
    the app"*. A free app makes that cap zero, which is a legal question, not a copy edit.
  - D1's cited lines 18 and 38 have not moved.
- **Found:** 20 Aug 2026 (D1); re-read 19 Nov 2026.

*Items 39 to 45 below, plus items 46 and 47 further down, were added 23 Nov 2026 by Brief MER-REL-2
from AEL's later findings. Each was checked against MER's code at `81548b1`. Line numbers are as
read on 23 Nov 2026 and mark where a literal run starts; cite by the quoted text, not the line.*

### 39. Every in-app sentence about what MER sends, and whether it survives the strip (decision A4) ◐
- **What:** decision A4 (item 26) turns sessions off and removes the per-install ID. Any sentence
  that describes what the app sends has to change in the same build.
- **How they were found:** a script assembled every string literal in `lib/**/*.dart` (39 files,
  1,856 assembled strings, with adjacent and `+`-joined literals joined, `//` comments dropped).
  It also read iOS plists, `.strings` and Swift, Android `res/**/*.xml` and the Windows runner
  `.rc`. Pattern: `no server|no account|count of sessions|diagnostic report|error.monitoring|
  third.party|never receives|transmit|nothing (is )?(sent|leaves)|leaves? (your|the|this) device|
  sent to|identifier|crash report|anonymous`.
  - **Positive control:** it finds the brief's known hit, `disclaimer_screen.dart` *"count of
    sessions"*, which is spread across seven adjacent literals and invisible to a line grep for
    the whole phrase. It also finds Help's *"no account and no server"*.
  - **Native hits:** none is user copy. They are bundle and notification identifiers, plus one
    XML comment in `data_extraction_rules.xml`.
- **The sentences, each with what happens when item 26 ships:**

  | Where | Sentence | After the strip |
  |---|---|---|
  | `disclaimer_screen.dart:243`, "Data storage & privacy" | *"The app sends diagnostic reports to a third-party error-monitoring service so faults can be diagnosed and fixed, and records when the app is opened as a count of sessions."* | ⛔ **Becomes false:** the sessions clause |
  | same `Text`, next sentence | *"These reports are designed not to include anything you have recorded, and the identifier they carry is generated by that service."* | ⚠️ **Depends on item 26's open half.** If no identifier remains, *"the identifier they carry"* is false. Item 26 has not established which fields carry it |
  | `disclaimer_screen.dart:233` | *"The developer does not collect, transmit or store your personal or medical information."* | Unchanged by the strip. The first sentence of the same `Text` is item 3 |
  | `disclaimer_screen.dart:259` | *"There is no account and no server of ours; your events are kept in the app's own storage on your device."* | Unchanged by the strip. See item 40 |
  | `help_screen.dart:382` | *"Medical Event Recorder has no account and no server, and Notiva never receives your events."* | Unchanged by the strip, and **false today** on "no server". See item 40 |
  | `walkthrough_screen.dart:140` | *"There is no account and no server of ours. Notiva never receives your events and cannot recover them."* | Unchanged by the strip. See item 40 |
  | `your_data_screen.dart:130` | *"Notiva never receives your events and cannot recover them for you."* | Unchanged by the strip. Item 27 is its only caveat |

- **Checked, with no sending claim found:**
  - **About:** its `_InfoRow` table cells are Developer, Version, Platforms and Data storage
    (items 1 and 2), and none describes sending. The footer is item 2.
  - **Help's** *"Version, privacy and terms"* row only points to the policy.
  - **Onboarding:** this is the walkthrough, covered in the table above.
- ⭐ **One more dependency for item 26:** item 26 lists the disclaimer's *"count of sessions"* as the
  in-app text that changes. **The NEXT sentence in the same `Text`, the identifier clause, depends
  on item 26 too.** So the in-app copy has two dependent clauses, not one.
- **Cross-references:** item 9 (policy §6 and §4) and item 26 (the strip).
- **Found:** 23 Nov 2026 (AEL report); located in MER 23 Nov 2026.

### 40. "No server" sentences in the app ✅
- **What:** AEL removed Help's *"no account and no server"* because Sentry receives reports. MER has
  the same sentence, plus two scoped versions of it.
- **Evidence** (from the item 39 sweep):
  - ⛔ **`help_screen.dart:382`, false today:** *"Medical Event Recorder has no account and no
    server, and Notiva never receives your events."*
    - The app does send to a server: `SentryFlutter.init(configureSentryOptions, …)` in `main()`.
    - The second clause is true as designed, with item 27 as its caveat.
  - ✅ **`disclaimer_screen.dart:259`, true as scoped:** *"There is no account and no server of
    ours"*. Two sentences earlier, the same section names the third-party service.
  - ◐ **`walkthrough_screen.dart:140`, true as scoped:** *"There is no account and no server of
    ours."* Nothing on that walkthrough step mentions Sentry, so a reader meets the "of ours"
    qualifier without what it excludes. Whether that is enough is for the chat half to judge.
  - **Not found in user copy:** a "nothing leaves the device" sentence. The only hit is a comment in
    `android/app/src/main/res/xml/data_extraction_rules.xml`.
- ⭐ **Help's sentence is the body that item 4's heading depends on.** Item 4 keeps *"Your events stay
  in the app"* only alongside the body text directly beneath it, at the same Help row. **Rewriting
  this body is an edit to item 4's truth.** Re-check item 4's heading when this changes, in Help and
  in the walkthrough.
- **Same class as item 30** (store listing); annotated there.
- **Found:** 23 Nov 2026 (AEL report); located in MER 23 Nov 2026.

### 41. FOR DECISION: the "Storage migrated to SQLite" report fires on every fresh install ✅
- **For the chat half: keep or remove.** AEL removed its copy (AV-44, `96eaff0` in the fork, read for
  comparison only).
- **The predicate, not the string:** `main()`, inside `SentryFlutter.init`'s `appRunner`. It sends
  `kMsgStorageMigrated` at info level when `storage.succeeded` and `storage.state ==
  MigrationState.migrated`.
- **Why that is true on a fresh install:**
  - `StorageBoot.init()` checks `getMeta(db, kMetaMigrationState) == 'migrated'`. A new database has
    no meta, so it calls `migrateJsonToSqlite` with `rawJson` from prefs, which is null.
  - `writeMigrationBackup` returns null for a null payload without failing, so the early return is
    not taken.
  - `migrateJsonToSqlite` decodes null to an empty list. It inserts 0 rows, counts 0, and sets
    `verified = inserted == loadableCount`, which is `0 == 0`. It returns `MigrationState.migrated`.
- **Measured 23 Nov 2026** with a scratch test, run on Windows and not committed:
  - A null payload on a fresh in-memory database built by `createSchema` gives `state=migrated
    succeeded=true inserted=0`. **So it fires.**
  - Control: a one-record payload with `dropForNegativeControl: 1` gives `failedVerification`, so the
    same harness can return a non-migrated state.
  - It fires once per database: after that the meta reads `migrated`, and Reset keeps `schema_meta`
    (`SqliteEventStore.clearAll`).
- **So what it measures today:** every new install and reinstall, plus any device still upgrading
  from a pre-SQLite build. The message cannot tell those cases apart, because it has no context
  fields. Its own comment calls it *"the adoption signal"*; what it reports now is mostly
  installs.
- **Related:** item 24 only regroups this message (annotated there), and item 26 strips the
  identifier and sessions.
- **Found:** 23 Nov 2026 (AEL report); predicate traced in MER 23 Nov 2026.

### 42. The Android in-progress notification can be swiped away: no `locked` on it ✅
- **What MER sets** (`lib/services/notification_service.dart`):
  - `_showNormal`, the standing "Log Event Now" state: `locked: true` and `autoDismissible: false`.
  - `_showActive`, "Event in progress": `autoDismissible: false` and **no `locked`**. Both post the
    same `_persistentId`, so starting an event replaces the standing content, and the ongoing flag
    goes with it.
- **The code says so itself:** the comment on `_showNormal`'s `locked` reads *"the active-event
  notification stays dismissible as a consequence of that replacement, not because it carries its
  own flag."* The KNOWN LIMITATION block above `_showNormal` records the effect on the lock screen.
- **So the in-progress notification is dismissible on every API level**, not only on Android 14+,
  where `locked` would not hold it anyway. Restore on resume (`restoreNotification`) shortens the
  gap but does not close it.
- **Why the brief's search found nothing:** the plugin calls it `locked`; `ongoing:` is not its
  name. A search for `locked` finds the standing state, which confirms the search works.
- **Comparison, read only:** AEL `a0231d2` (20 Nov 2026) added `locked: true` to `_showActive`, with
  `test/active_notification_ongoing_test.dart`. Its comment notes the same Android 14+ limit.
- **Found:** 23 Nov 2026 (AEL report); confirmed in MER 23 Nov 2026.

### 43. An open History screen does not refresh after a notification episode ✅ (record only)
- **Same behaviour, from the code:**
  - `HistoryScreen` takes `records` in its constructor. `home_screen.dart` `_openHistory` passes
    `_records`.
  - `_HistoryScreenState.initState` copies it once: `_records = List<EventRecord>.from(widget.records)`.
  - `lib/` has **no** `didUpdateWidget` (0 files). Control: the same search for `initState` returns
    9 files.
  - So a record drained into Home while History is open does not show until History is reopened.
- **Same test:** `test/support/history_clobber_contract.dart`, run per store by
  `history_stale_snapshot_clobber_prefs_test.dart` and `history_stale_snapshot_clobber_sqlite_test.dart`.
  - It drains `gamma` while History is open (*"POSITIVE CONTROL: the resume did not drain"*). It
    then requires `gamma` to survive a History action (*"THE CLOBBER"*).
- **AEL's trade-off applies the same way here:** if History refreshed live, it would hold `gamma`
  itself. A save-to-replace-all regression would then keep `gamma` too, and the test could no
  longer catch that regression unless it was reworked.
- ⚠️ **Not observed on a device.** This is from the code only.
- **Found:** 23 Nov 2026 (AEL report, fix deferred there); confirmed in MER 23 Nov 2026.

### 44. The backup sheet's share subtitle says "spreadsheets" ✅
- **Evidence:** `lib/services/backup_service.dart:380`, the backup sheet's *"Share to apps"* row:
  `subtitle: const Text('Email, cloud storage, spreadsheets')`.
- **What contradicts it:**
  - `your_data_screen.dart:109`: *"This is your copy. It is not a spreadsheet file."*
  - `help_screen.dart:406`: *"A backup file is your copy … but is not a spreadsheet file."*
- **Correct where it is:** the CSV sheet's row has the same subtitle (`event_record.dart:2268`), and
  a CSV is a spreadsheet.
- ⚠️ **A comment goes stale with the fix:** the comment above the backup row says *"THIS SHARE ROW
  is the one label still duplicated by hand, and it is identical in both."* AEL annotated its copy
  in `9d6b190` when the two rows diverged.
- No test pins either string (`grep` over `test/`: no hit).
- **Found:** 23 Nov 2026 (AEL report); located in MER 23 Nov 2026.

### 45. The duration fields' screen-reader labels ⛔ as worded / ◐ what is true
- ⛔ **"Have no screen-reader labels" is wrong for MER.** Both builders set a label:
  - the wizard's `_numField(c, label)`: `InputDecoration(labelText: label, hintText: '--')`, called
    with `'minutes'` and `'seconds'` (`event_wizard_screen.dart`, `_durationStep`);
  - Edit details' `_DurationField`: `InputDecoration(labelText: label, hintText: '--')`, called with
    `'minutes'` and `'seconds'` (`log_event_screen.dart`).
- ◐ **What is true:** the spoken label is the bare word *"minutes"* or *"seconds"*, with nothing
  saying it is a duration. AEL's fix was to make the label more descriptive, not to add a missing
  one. Its `9b47b70` body says the field labels read *"minutes"* and *"seconds"* before the change,
  and it moved them to *"Duration, minutes"* and *"Duration, seconds"*.
- **How this was established, and what was NOT done:**
  - From the code. No semantics tree was walked in MER, and no uiautomator dump was taken. Per AEL's
    AV-62, a dump may not show Flutter's hint or label text anyway.
  - MER's `_numField` and `_DurationField` are **textually identical** to AEL's at `9b47b70^`
    (diffed 23 Nov 2026).
  - AEL's control walked the semantics tree on that same code and read the labels *"minutes"* and
    *"seconds"*. That measurement transfers to MER only because the code is identical.
  - ⚠️ What TalkBack or VoiceOver actually speaks: not established.
- **Found:** 23 Nov 2026 (AEL report); checked in MER 23 Nov 2026.

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
- ✅ **CLOSED 14 Oct 2026 (Brief CIT-1, CR-46); the bullets above are left as written.**
  - **Windows, answered (LP-MER, 14 Oct 2026):** the same 16 fail on Windows, identically.
  - **The fix:** the 16 occurrences carry a `[host]` marker in the checklist, and each marked
    token must be in a closed list in the test, `_hostCitations`, with a reason. The citations
    themselves were correct; the rule "resolves in this repo" was wrong for them.
  - **It can still fail:**
    - a marked token that is not on the list fails;
    - a listed token cited unmarked elsewhere fails;
    - a marked token that the repo actually has fails;
    - a list entry that nothing marks fails.
    - Controls D1 to D5 are in the Change Register, CR-46.
  - **Item 20's saturation ends for this test,** because it is green. Item 20's general point
    and item 13 are unchanged.

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
- ✅ **Re-verified and annotated 19 Nov 2026 (Brief MER-REL-1 A); the text above is left as
  written.**
  - Still unset: `enableAutoSessionTracking` has 0 occurrences in `lib/` at `88657e1`.
    `configureSentryOptions` (`main.dart`) is the only options site, and the same search finds it.
  - The default, read from the resolved package (`sentry_flutter` 9.19.0, `pubspec.lock`):
    `bool enableAutoSessionTracking = true;` in `sentry_flutter_options.dart`. It reaches Android
    through `sentry_native_java_init.dart` (`setEnableAutoSessionTracking`) and iOS through
    `SentryFlutter.swift` (`data["enableAutoSessionTracking"]`).
  - ⭐ **This item is now the sessions half of item 26** (decision A4: install ID and sessions).
    It stays numbered so references hold; the work is item 26's.

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

### 21. Play: DEX code optimisation below threshold, Obfuscation 1%, fix by February 2027 ⚠️
*Mark: a Play Console read by the chat half, 30 Sep 2026, relayed. It is not in the repo and
cannot be verified from it.*
- **As read:** *"DEX code optimization is below our threshold — Obfuscation (1%). Play states
  percentages under 25% may impact visibility and publishing capabilities. Fix by Feb 2027."*
- **Play's tags on it:** *Memory usage · Bad behavior · Release name: 64 (1.1.1)*. These are how
  Play classifies the IMPACT; a reader deciding whether the item is cosmetic needs them.
- ✅ **From the repo:** the release build has `isMinifyEnabled = false` and
  `isShrinkResources = false` (`android/app/build.gradle.kts`, unchanged since the first commit).
  That is consistent with 1%.
- ⛔ **A SEPARATE item from the "no deobfuscation file" review warning, which is closed.** That
  warning was closed on 30 September as nothing to deobfuscate: with no R8 step, no mapping file
  is possible. This one is **open, with a deadline.** Do not merge them.
  - ⚠️ **They are linked in one direction:** turning R8 on to address this item would, for the
    first time, produce a mapping file, and the deobfuscation-file warning would then matter.
- **The same screen's release stability showed "–" for both crash metrics.** That is consistent
  with 64 being in review with no users yet: an absence of data, not a measurement of stability.
- **Found:** 30 Sep 2026. **Deadline:** February 2027, per Play.
- ⚠️ **Annotated 23 Nov 2026 (Brief MER-REL-2, item 9); the bullets above are left as written.**
  A second sighting of the same notice, on AEL's account, not MER's: AEL's release 7 shows
  *"DEX code optimization is below our threshold … Obfuscation (1%) … Fix by: Feb 2027."* Console
  read by the chat half, relayed 23 Nov 2026. Not readable from the repo.
  - **What it adds:** the notice is not specific to MER's release 64. It recurs on a sibling app
    built from the same code, so MER's next Android release will most likely get it too.
  - ⛔ **The fix has to SHIP in a release before February 2027.** Turning R8 on in the repo is not
    enough by itself. See the deobfuscation-file link above.
  - Re-read 23 Nov 2026: `isMinifyEnabled = false` and `isShrinkResources = false` are still in
    `android/app/build.gradle.kts`.

### 23. Guard the v2 to v9 `ADD COLUMN` steps with `hasColumn`, as v10 and v11 already are ✅
- **What:** in `upgradeSchema` (`event_store_sqlite.dart`), the v2 to v9 steps run
  `ALTER TABLE … ADD COLUMN` on a version bound alone. Only the v10 (`hidden`) and v11
  (`updated_at`) steps first ask the table whether the column exists.
- **Why it matters:** sqflite starts the upgrade from `PRAGMA user_version`. A database whose
  `user_version` is behind its actual columns re-runs an unguarded step, fails on
  `duplicateColumn`, and the launch falls back to shared_preferences.
- **Evidence:** reproduced on 17 Oct 2026, on a dev database with `schema_version` 9 and
  `user_version` 1. The `FALLBACK-REPRO` set and its readings are in `docs/BUILD-LEDGER.md`, in
  the "Row 66 device test" section.
- ⚠️ **Not sized.** It is a small change with a real safety argument. How a real device could
  reach that state is not established; the reproduction came from a dev-only downgrade.
- **Found:** 17 Oct 2026, Brief MER-W4.

### 24. Give the storage fallback its own Sentry fingerprint ✅
- **What:** the error-level "Storage migration did not complete; running on shared_preferences"
  message groups with the info-level "Storage migrated to SQLite" message in one issue. That
  issue then reads as error-level, and its user count belongs to the info events.
- **Evidence:** MEDICAL-EVENT-RECORDER-9, read 18 Oct 2026, grouped by title and level. Every
  event before 17 Oct 2026 is info-level; the only error-level events are MER-W4's own two.
- **Found:** 18 Oct 2026, Brief MER-W4.
- ◐ **Annotated 23 Nov 2026 (Brief MER-REL-2, item 3); the bullets above are left as written.**
  Item 41 asks whether the info-level message should exist at all. If item 41 decides REMOVE, the
  regrouping here only needs doing for the fallback message, which would then be the only member
  of its issue. If item 41 decides KEEP, this item stands as written. **Decide item 41 first.**

### 25. Mark non-store builds in Sentry ◐
- ✅ **The gap:** the only environment signal is `kReleaseMode ? 'production' : 'development'`
  (`main.dart`). A release build run locally, such as a sideload test, is tagged `production`
  exactly as a store install is.
- ⛔ **Not specified.** It needs a CLI read of the release tooling and the Sentry init path first.
  No design is given here.
- **Found:** 18 Oct 2026, Brief MER-W4.

### 28. iOS privacy manifests are absent for Runner and MERWidget ✅ (absence) / ⚠️ (ITMS-91053)
- ✅ **Absent:** no `PrivacyInfo.xcprivacy` anywhere under `ios/`, and 0 occurrences of
  `PrivacyInfo` in `ios/Runner.xcodeproj/project.pbxproj`.
- ✅ **Required-reason API use in MER's own Swift** (8 files in `ios/Runner` and `ios/MERWidget`):
  UserDefaults only, both `UserDefaults.standard` and the App Group suite
  (`UserDefaults(suiteName: kAppGroupId)`), in `AppDelegate.swift` and `EndMEREventIntent.swift`.
  No hits for file timestamps, system uptime, disk space or active keyboards. Part B widens this
  to plugins and Dart.
- ✅ **Pods that ship their own manifest** (read from the pub cache at the `pubspec.lock`
  versions): `file_selector_ios`, `flutter_native_splash`, `package_info_plus`, `share_plus`,
  `shared_preferences_foundation`, `sqflite_darwin`, `url_launcher_ios`. **None:**
  `awesome_notifications` 0.11.0 and the `sentry_flutter` plugin wrapper. Not readable from
  Windows: `Sentry/HybridSDK` 8.58.1 and `IosAwnCore` 0.11.0 (CocoaPods trunk; `ios/Pods` is
  not on this machine).
  - ⚠️ `ios/Podfile.lock` records `flutter_native_splash` 2.4.3 against `pubspec.lock`'s 2.4.7,
    so the Mac's last `pod install` predates the current lock.
- ⚠️ **ITMS-91053 on the next upload** [report: handover]. The ledger's upload rows record 90473
  warnings, not 91053. Only an upload can show it.
- **Comparison:** AEL added both manifests in `fe71879` (AV-35 B). Part B reads them.
- **Found:** before 19 Nov 2026 (handover); absence confirmed 19 Nov 2026.

### 33. Play 16 KB page-size warning ◐
- ⚠️ **The console warning** [report: handover]. Which release it names is not recorded.
- ✅ **Native libraries MER ships**, from the last local release build's merged libs
  (`build/app/intermediates/merged_native_libs/release/…`, dated 28 Sep 2026, the same night as
  `build/app/outputs/bundle/release/app-release.aab`): `libapp.so`, `libflutter.so`,
  `libsqlite3.so`, `libsentry.so`, `libsentry-android.so`, `libdartjni.so`,
  `libdatastore_shared_counter.so`, across arm64-v8a, armeabi-v7a, x86_64 and x86.
- ✅ **Every one has ELF LOAD alignment of at least 16 KB** (25 of 25 files; 16384 or 65536), read
  from the program headers by a script.
  - **Control:** a copy of `libsqlite3.so` with its LOAD alignment patched to 4096 is reported
    "under 16KB" by the same script; the unpatched copy beside it passes.
- ⚠️ **What this does not establish:** that the 28 Sep build is what Play warned about; that the
  AAB stores the libraries uncompressed and 16 KB zip-aligned (Play's other condition); and any
  library a later build adds. A check of the uploaded AAB itself would settle the first two.
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 34. Apple 90725: uploads need the Xcode 27 / iOS 27 SDK from April 2027 ⚠️
- ⚠️ **The requirement** [report: handover]. Not readable from the repo.
- ⚠️ **Whether MER's iOS build Mac can run Xcode 27: not established.** The repo records the Mac as
  an *"8 GB Intel MacBook Air"* (`STATUS.md`; `iOS Device Test Checklist.md` §13, *"the Mac (8 GB
  Intel)"*) running Xcode 26.3 (`BUILD-LEDGER.md`, rows 5 and 65). Whether Xcode 27 supports
  Intel Macs is not in the repo.
- **Why it matters:** if it cannot, MER has no iOS upload path from April 2027.
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 35. Sentry dSYM upload ✅ (with the brief's premise corrected)
- ⛔ **"A dSYM upload build phase was added with CR-43" is wrong twice:**
  - it came in with `192ae40` (v1.0.2+3), the same commit that carries CR-43 per the
    instructions file, not with CR-43's own commits (`4d1514a`, `0468e6f`, which are
    Android-only);
  - **the build phase no longer exists.** `4cc50d3` (Brief 244, 29 Sep 2026) removed it; the
    pbxproj today has no `sentry-cli`, `dSYM` upload or `Upload dSYMs` phase. The upload is
    `tool/upload_dsyms.sh`, run after archiving (`iOS Device Test Checklist.md` §12).
- ✅ **It has run successfully, with an independent read:** `BUILD-LEDGER.md` row 65 (iOS 1.1.1):
  *"uploaded to Sentry 30 Sep 2026 (`tool/upload_dsyms.sh`, Brief 306)"*, 3 sent and 1 already
  held, *"Verified independently … by a read of Sentry's Debug Files listing"*. Row 64's dSYMs
  were not uploaded (a separate decision, per that row).
- **What remains is process:** nothing makes the script run for each release. Whether it ran for
  any build after 65 is not recorded.
- **Found:** before 19 Nov 2026 (handover); corrected 19 Nov 2026.

### 36. `project.pbxproj` re-sort churn on `pod install` ◐
- ✅ **From history**, by a script comparing each commit's pbxproj with its parent's as a multiset of
  lines: of 17 commits touching `ios/Runner.xcodeproj/project.pbxproj`, **1 is reorder-only**,
  `4b32e3c` (6 May 2026, *"… + Xcode project reorder"*); 15 change content; 1 is the file's
  creation. Of 7 commits touching `ios/Podfile.lock`, none is reorder-only.
- ⚠️ **What this cannot see:** reorder hunks inside a content-changing commit, and churn never
  committed (reverted on the Mac before commit). That `pod install` is the cause is the handover's
  report.
- **Found:** before 19 Nov 2026 (handover); recorded 19 Nov 2026.

### 38. AEL data-loss fixes since the fork that MER must check (decision A2): NONE FOUND ✅
- **Range:** `git log b859d9a..HEAD` in `event-recorder-fork` at `a6a1f55`, read-only: **90
  commits**, 23 touching `lib/`. `b859d9a` is an ancestor of HEAD.
- **Filter 1, by file:** commits touching storage, migration, backup, restore, reset, export, the
  capture inbox or vocabulary files. **7 commits**, each classified:

  | Commit | What | Data-loss fix? |
  |---|---|---|
  | `f92ddea` | identity rename; storage key prefix `mer_` to `ael_`, db file `ael_events.db` | No: renames for a new app, not a defect fix |
  | `479b8ef` | seed vocabulary replaced with the animal set | No: content, AEL-only |
  | `12752d4` | user-visible copy renamed (backup error strings among it) | No: copy |
  | `ddd18b2` | episode summary PDF; `reset_files.dart` pattern gains `pdf` | No: new file type for a new feature |
  | `8a19281` | `animal` table, schema 12, backup schema 5, Reset census | No: new feature built to the data-loss standard; fixes nothing inherited |
  | `8a98e1e` | seeded catch-all relabelled, `value` unchanged | No: presentation |
  | `f4c9aa7` | reading-width cap on screens incl. Your lists | No: layout |

- **Filter 2, by content** (`git log -G` over `lib/` for persist, save, restore plan, delete,
  storage boot and migration code): 5 commits, the four above plus `eb9bd34` ("Your animal"
  screen, a new feature). No addition.
- **Native side:** the commits touching `ios/Runner`, `ios/MERWidget` or `android/app/src/main`
  are manifests (`fe71879`), Live Activity look (`48ffaa0`, `deecd06`) and splash images
  (`6e2e146`). None touches capture or storage.
- **Control:** both filters catch `8a19281`, a known storage commit (schema 12), so each can
  return a storage commit when one exists.
- **Result: 0 of 90 is a data-loss fix to code MER shares.** ⚠️ The A2 obligation is a standing
  one; this answers it at `a6a1f55` only.
- **Found:** 19 Nov 2026.

### 46. Two stale "never deleted" comments on the pre-migration backup ✅ (record only, not edited)
- **The comments, all occurrences:** `grep -rni "never delete" lib/` gives 8 hits. Six are about
  records or vocabulary. These two are about this file:
  - `lib/models/storage_migration.dart:331`, doc comment on `writeMigrationBackup`: *"Written BEFORE
    anything is touched, silently, and never deleted."*
  - `lib/models/storage_boot.dart:156`, at its call site in `StorageBoot.init()`: *"The backup is
    written BEFORE anything is touched, and is never deleted."*
- **What Reset actually does:**
  - `SqliteEventStore.clearAll` step 4 calls `deleteResetFiles(recordedBackupPath: …)`.
  - `deleteResetFiles` (`lib/models/reset_files.dart`, Brief 208 Part B, 28 Sep 2026) sweeps
    `kPreMigrationBackupName` (`mer_pre_sqlite_backup_…json`) from Application Support, plus the
    path recorded in `schema_meta`.
- **The exception, the same as AEL's:** a Reset on a fallback launch runs `EventStore.clearAll`,
  which clears prefs only. `SqliteEventStore.clearAll`'s own comment says this is *"deliberate
  (Brief 208 B5)"*. So on that one path the backup does survive.
- `reset_files.dart`'s own doc comment is correct. Only the two writer-side comments are stale.
- **Also true, though no comment claims otherwise:** on a fresh install `writeMigrationBackup`
  writes nothing, because it returns null for a null or empty payload.
- **Comparison:** AEL AV-46 C6.
- **Found:** 23 Nov 2026 (AEL report); located in MER 23 Nov 2026.

---

## ACCOUNT: console state, not code

### 47. Three account deadlines, for the developer and the chat half, not code ⚠️
*None of these is readable from the repo. Each is a console read relayed by the chat half, made on
AEL's side of a shared account.*
- ⚠️ **Google Play trader status, Notiva account:** not declared as at 20 Nov 2026 (AEL's console
  read). Deadline February 2027. Play's text says apps are removed globally if the status is
  undeclared. It is an account-level declaration, so **it covers MER.**
- ⚠️ **App Store Connect account notice:** answers to the new age-rating questions (Location Sharing,
  Dating) are due 15 Jan 2027, seen 23 Nov 2026 in AEL's account view. **Whether MER's rating is
  affected: not read.**
- ⚠️ **App Store Connect, China mainland security assessment and AIGC declaration:** due 31 Jan 2027.
  They apply only if MER is distributed in China mainland. **MER's availability: not read.**
- **Found:** 20 and 23 Nov 2026 (chat half); recorded 23 Nov 2026.

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

**Count after Brief 313, 30 Sep 2026:** 20 items on the list, plus item 18 kept as a withdrawn
record. The counts above are left as written.
- **Item 6 is superseded by measurement:** its heading's claim, "Android 64 was never uploaded",
  is false as at 30 Sep 2026.
- **Item 21 is new** and ⚠️ unverified from the repo: a Play Console read.

**Count after Brief MER-W4, 18 Oct 2026:** 24 items on the list, plus item 18 kept as a withdrawn
record. The counts above are left as written.
- **Items 22 to 25 are new**, from the Windows 1.1.66.0 device test. They are rows, not work;
  none is fixed here.
- ✅ **3 verified:** 22, 23, 24.
- ◐ **1 partly verified:** 25. The gap is verified; the specification is deliberately not
  written.

**Count after Brief MER-REL-1 Part A, 19 Nov 2026:** 37 items on the list, plus item 18 kept as a
withdrawn record. The counts above are left as written.
- **Items 26 to 38 are new** (13), from the AEL session's handover, each checked against the code
  at `88657e1` before it was written. Handover item 12 was recorded on item 8 instead of as a new
  item.
- **Annotated in place, dated 19 Nov 2026:** 8 (handover item 12), 9 (policy §6 now read, and a
  second dependent paragraph found in §4) and 12 (re-verified; now item 26's sessions half).
- ✅ **4 verified:** 27, 35 (premise corrected), 37, 38 (a null result, with a control).
- ◐ **7 partly verified:** 26, 28, 30, 31, 32, 33, 36. Items 28 and 31 each verify the repo half
  and leave a console or upload half ⚠️.
- ⚠️ **2 unverified from the repo:** 29 (also ⛔ HELD for developer approval) and 34.
- **Item 9 moves from ⚠️ to ✅:** §6's content is read.
- ⛔ **Premises in the brief found wrong:** 35's "added with CR-43" and its implied live build
  phase (removed by `4cc50d3`); 30's "26 Sep replacement" (none exists; the repo's replacement is
  from 18 to 20 Sep and is itself stale); 27's commit `4e91232` is a DSN change carrying the
  sanitiser fix as one hunk.

**Count after Brief MER-REL-2, 23 Nov 2026:** 46 items on the list, plus item 18 kept as a
withdrawn record. The counts above are left as written.
- **Items 39 to 47 are new** (9), from AEL's later findings, each checked against MER's code at
  `81548b1`. Brief item 9 was recorded on item 21 instead of as a new item. A new ACCOUNT section
  holds item 47.
- **Annotated in place, dated 23 Nov 2026:**
  - 21: AEL's sighting of the same Play notice; the fix must ship before February 2027.
  - 24: depends on item 41's decision.
  - 30: same class as item 40.
- ✅ **6 verified:** 40, 41 (predicate traced and measured, with a control), 42, 43, 44, 46.
- ◐ **2 partly verified:**
  - 39: every sentence is located; the identifier clause's fate depends on item 26's open half.
  - 45: ⛔ as worded; the labels exist but are bare.
- ⚠️ **1 unverified from the repo:** 47 (console items).
- **For decision:** 41 (keep or remove the fresh-install report).
- ⛔ **Premise in the brief found wrong:** item 7's *"no screen-reader labels"*. MER's duration
  fields carry the labels *"minutes"* and *"seconds"*, and AEL's fix made them more descriptive.
