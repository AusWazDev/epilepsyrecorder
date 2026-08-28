# Medical Event Recorder — Session Log

---

## Session: 28 August 2026 — Windows (Claude Code CLI)

**Six commits, then a reconciliation pass.** Full detail is in the Change
Register under *The record catches up — 28 August 2026*; this is the summary.

| Commit | What |
|--------|------|
| `d73222a` | Triggers become a vocabulary table (schema v9) |
| `9892031` | The hide affordance — "Your lists", the first UI ever to reach `is_active` |
| `690e024` | Medication notes enter the backup envelope (backup schema 1 to 2) |
| `cc3a450` | The empty-backup gate counts both streams |
| `47be40b` | Four small fixes: search hint, summary labels, junk records |
| `5b94af1` | The retired block on "Your lists": 48 rows to 27 |

### The reconciliation, and why it was needed

The register had stopped tracking the code at 27 Aug 20:33. **Ten commits landed
after it**, including four schema versions and a backup-format change. Nothing was
wrong with the work; it was invisible to every artefact except git.

Corrected in this pass:

- **`docs/DATA-MODEL.md` §0** regenerated from v5 to v9. All five of its divergence
  claims were false, and it had begun contradicting itself — `rescue_med_*` appeared
  under both "columns that exist" and "columns that do NOT exist". Four "as at v3"
  claims in the body corrected too, including *"There is no `condition` table yet"*,
  false since v8.
- **`CLAUDE.md`** said `Version: 1.1.0+5` (live: `1.1.0+49`) on the same line as
  *never hardcode this*. The number is now removed rather than updated. It also said
  **"no SQLite"** in the auto-loaded Data storage section — false since schema v1, and
  seeding every session with a wrong model of the storage layer. Sixteen source files
  were missing from the structure listing.
- **The Change Register**: ten commits added, the $4.99 pricing marked superseded in
  place, the Terms backlog note corrected (it named §8, which is Disclaimer of
  Warranties), and the abandoned-event defect closed.
- **This file**: two stale-open items closed, below.

### What is DECIDED and NOT BUILT

**Monetisation: MER is free with an optional donation.** Decided 20 August 2026,
superseding the June freemium plan and the $4.99 one-time price. **Nothing is built** —
no donation mechanism exists anywhere in `lib/` or `pubspec.yaml`. Recorded in the
register as open items M1 to M4, not as a decision. The Terms still promise a paid app
in two places and must be revised **before** the store price changes.

🔴 **CORRECTED 28 Aug 2026 — this said the decision "lived only in conversation" and
that was FALSE.** It was recorded on 20 August in
`docs/claude-ai-project-instructions.md:175` and its `.txt` twin, dated, with the
supersession named.

**The real finding is sharper: the two halves of this project read different files.**
Chat reads `docs/claude-ai-project-instructions.md`, which held it from day one. The
build side reads this file, the Change Register and `~/.claude` memory, none of which
did. So the decision was **recorded and invisible at the same time**, and a CLI audit of
"what is recorded" confirmed the gap every time because it was looking in the build
side's files.

**A decision is not recorded until it is in an artefact the half of the project that must
ACT on it will read.** Monetisation is a build obligation — a donation mechanism, a Terms
revision, a listing rewrite, a price change. See the Change Register entry for the full
correction, including how the false claim was produced (a search scoped to the Register
and `lib/`, never `docs/`, then generalised to "the repo").

---

## Session: 26 August 2026 — Windows (Claude Code CLI)

⚠️ **PARTIAL. This section records the CSV delimited change only.** 23 commits landed
today — the duration quantity, the wizard, user-defined vocabularies, the observation
revision, the History filter redesign, the "Needs details" queue and Help corrections among
them. Those 22 are in the Change Register and in `git log`, and are not yet summarised here.
Written this way rather than left blank so the gap is visible instead of implied.

### The CSV delimited change

**The one-hot export is gone in both halves. 26 → 17 → 11 columns.** Eleven observation
columns collapsed earlier today when observations became user-extensible; the seven trigger
columns collapsed here.

- **Delimiter `; `.** A value containing it is **quoted with its own quotes doubled** —
  `"Dizzy; unsteady"; Stress` — the convention CSV already uses, one level down. The words
  someone chose are never altered; only punctuation is added around the entry that needed it.
- **Empty set is blank**, never `none`. Two states, not three — and `none` would be a value
  indistinguishable from a user-defined observation called "None".
- **Shape marker is a filename suffix**, `..._20260826_230917.v2.csv`. Nothing reads it. Both
  export paths now build the name through one `csvFilename`, where they previously assembled
  it independently.
- **The emoji stripper was replaced, not reused.** The retired one was POSITIONAL and would
  have eaten the first WORD of any user-defined entry — `Dizzy spell` as `spell`. The
  replacement writes each entry's LABEL, so the guess is gone rather than improved. Test 10
  is the negative control and asserts the positional output explicitly.

### ⚠️ The column is `beforehand`, not `triggers`, and a test caught it

The first implementation named it `triggers`. `beforehand_wording_test` failed on the same
run. **The seven one-hot columns were the OPTION NAMES with no group heading, so the export
had nowhere for a causal label to live** — which is why three briefs of causal-wording work
never reached it. Collapsing to one column forces a heading, and the structural protection
vanished in the same edit that created the need for it.

⭐ **A property that holds because of how something is SHAPED stops holding when the shape
changes, and nothing announces that.** The check has to outlive the structure it was written
against; this one did. Its own positive control had to move from the header to the row in the
same edit, because the option names stopped being columns.

### Verified

`flutter analyze` 44 issues, 0 errors, 0 warnings. `flutter test` **364 pass**, 2 known
pre-existing failures (was 344/2). `ios/` subtree `63d3251` unchanged, working tree clean.
Device: Teclast P30, versionCode 31, `adb install -r`.

**Device diff, 17-column export pulled before installing against 11-column after:**
710 shared cells over 71 rows, **CELLS THAT DIFFER: NONE**; the re-encoded field read back
from both encodings, **SETS THAT DIFFER: NONE**. ⚠️ That last denominator is thin — 1
non-empty row of 71 — so multi-value and ordering were shown on a throwaway record, deleted
afterwards, device confirmed back to 71. Its row: `Confused; Tired,Stress; Illness` with
`Illness` tapped FIRST, so the reordering to picker order is demonstrated rather than argued.

**Not demonstrated on hardware:** the quoting of a delimiter-bearing value. It would need a
user-defined observation containing `;`, and the vocabulary has no delete — only hide — so it
would leave permanent junk. Covered by tests 4–7 including the negative control.

**Backup shares no code with the export**, verified by enumeration: `backup.dart` takes only
`EventRecord`, `fromMap` and `toMap`, and every diff hunk falls after the CSV banner.
`backup_service.dart` has its own filename builder, so `.v2` cannot reach it.

Also corrected: **`DATA-MODEL.md` §0 said "as at schema v3" while the code is at v4** — the
one section whose whole claim is that it was derived from the DDL rather than remembered.

---

## Session: 25 August 2026 (evening) — Windows (Claude Code CLI)

**SQLite phase one shipped and verified on two platforms; notification and
backup-selection work; Windows packaging identity settled.** Seven commits.
`ios/` untouched by this machine throughout — the subtree moved only when the
Mac pushed `537a613`, a `pod install` adding `sqflite_darwin` to `Podfile.lock`.

### SQLite phase one (`9461f27`)

Storage implementation swapped behind `EventStore`. Today's nine fields
relationally, `schema_meta` from the start, every optional column nullable.

- **The migration reads RAW JSON, not `EventRecord`.** `fromMap` coerces an
  absent `eventType` to `seizure`, an absent `severity` to `mild` and an
  unparseable `duration` to `lt1` — its own comment calls them "safe fallbacks".
  Reading through it would convert UNKNOWN into a confident wrong value,
  permanently, in the schema whose premise is that NULL means unknown. Absence
  is written as NULL and counted into `schema_meta`, because the NULLs are not
  durable: `save(List)` rewrites every row and `EventRecord` cannot express
  unknown.
- **`id` is deliberately NOT a primary key.** The JSON array permits duplicates;
  rejecting one would turn "this device has two records sharing an id" into "the
  migration lost a record". Duplicates are carried and counted.
- `save(List)` and `load()` keep their signatures — the fallback path needs both
  stores to satisfy one interface at run time.
- **The fallback is tested**: verification fails, the launch runs on
  shared_preferences, and the inbox still drains into the OLD store, with keys
  deleted only after the write is confirmed.

### Verified on the tablet — 66 records, zero field-level change

`sourceEntries 66 / loadable 66 / inserted 66 / distinctIds 66 / skipped 0`,
read from Sentry because an unrooted release build cannot be read by adb.
Pre- and post-migration backups compared: **same 66 ids, 528 field comparisons,
zero differences**, record order identical, and three double-encoded feelings
preserved verbatim rather than "fixed".

⚠️ **`absent: {}` — no optional key was missing from any record, so the
NULL-vs-fabrication machinery DID NOT FIRE on real data.** It is covered by
tests 3 and 4 only.

### Version bumps (`513215c`, `2828faa`, `c129343`)

`1.1.0+5` → `1.1.0+6`, because the SQLite and pre-SQLite builds were
indistinguishable on device — which is how a pre-migration state was read as a
completed migration. Derivation verified end to end: gradle reads
`flutter.versionCode`, `package_info_plus` reads that manifest back.

`msix_version` `1.0.0.0` → `1.1.6.0`, and **NOT derivable**: the msix tool's
`_getPubspecVersion` returns `[major, minor, patch, 0]`, discarding the build
number, so every build within a patch version packages identically. MSIX
reserves the fourth part and requires zero, so `1.1.0+6` folds into the three
usable parts. The identity values were already correct since the initial commit;
what was missing was any statement that they are IMMUTABLE.

### Notifications (`ed6fb7a`, `e6bb5a5`)

`locked: true` on the standing notification. **It reaches the notification**
(`flags=SHOW_LIGHTS|ONGOING_EVENT`, measured) and **Android 14+ ignores it** —
since API 34 only foreground-service and call notifications resist dismissal.
It pins on API ≤ 33; `minSdk` is 24.

The foreground service was considered and REJECTED, with the reasoning recorded
in `notification_service.dart` so it is not reached for again: one answer beats
two (iOS has the identical defect and no service exists there), the cost recurs
at every Play review, and it does not close the hole — `shortService` caps at
three minutes and `health` asserts a clinical purpose this app does not claim.
The plugin could not express it honestly regardless: no `specialUse`, `health`
or `shortService` in its enum, and its manifest hardcodes `phoneCall`.

**Root cause of the sinking is still unfixed:** Android treats a re-post of the
same id as a silent in-place update, so it never resurfaces. iOS already does
`removeDeliveredNotifications` then `add` — cancel-then-post is the fix and it
is a port, not an invention.

### Backup file selection (`cd53b28`, `d8a2291`)

Prompted by a real mis-restore: a 37-record file restored onto a device holding
66. No data lost — merge-only — but nothing made the mistake visible.

- Filename `medical_event_recorder_backup_…` → `mer_backup_…`, 48 → 31 chars.
  **Nothing matches on the prefix**, now guarded by a source scan with a control.
- The dialog shows the **export timestamp**, already in the envelope and simply
  not read. Two files identical in count, size and contents now differ by one
  line. Verified on device.
- A staleness caution was built and REMOVED: `timestamp` is `logged_at`, so
  across two devices it compares which last logged something, not which holds
  newer events. Deferred until `occurred_at` is populated.

### Windows: SQLite packaged and run

First packaging of the real app with SQLite. `sqlite3.dll` confirmed inside the
archive by inspection (1,657,856 / 923,003 compressed). Packaged app launches,
opens the database, migration completes: `schema_version 1`,
`migration_state migrated`.

⚠️ **AppData is NOT virtualised for this package.** `runFullTrust` /
`Windows.FullTrustApplication`, `LocalCache` empty, and the database sits at the
real `%APPDATA%\au.com.bedlin\epilepsyrecorder\`. Packaged and loose builds
share one store — so the loose build IS a fair proxy for storage location.

⚠️ **The Windows migration ran over an EMPTY store.** `sourceEntries 0`. The
conversion remains untested on Windows.

⚠️ **Windows Sentry release is `epilepsyrecorder@1.1.0+6`**, not
`au.com.notiva.medicaleventrecorder@…` — `PackageInfo.packageName` returns the
project name on Windows, so releases do not group across platforms.

### The tablet lost the app, and it was recoverable

After an OEM build update (V1.05 → V1.06; **Android 15 / API 35 unchanged**) the
package was gone — not disabled, not hidden, no retained data, `firstInstallTime`
reset on reinstall. Cause unknown and left unexplained: the events buffer only
reaches back to 16:47 and the removal predates it.

**Nothing was lost, because `/sdcard/Download` is not app-scoped.** Four backups
survived there and three on this PC. Restored to 69 records.

⚠️ **A OneDrive folder named `MER backup test` sits in the same picker namespace
as real backups**, holding exports of 4, 11, 14, 31 and 37 records plus a
deliberately corrupt file. That folder caused the mis-restore. Thirteen backup
files are reachable from the picker across two providers; the default Recent
view shows four, and **excludes the newest local file** — a 5:41 PM backup was
still absent from Recent at 6:51 PM.

### Windows certificate — blocked, deliberately

Non-exportable signing certificate created, `EB323808D9E67D95888196E9388022CC7FC68299`,
subject `CN=520D1E31-…`, valid to Aug 2027. Signing works.

**`CurrentUser\TrustedPeople` is NOT sufficient for MSIX deployment** — still
`0x800B0109`. Microsoft's "**Local Machine** Trusted People" is a hard
requirement, and that needs admin. Not escalated without approval. Removal
commands are in the session report; the certificate is currently trusted
per-user only, which grants nothing.

### Verified

`flutter analyze` 40 issues, **0 errors, 0 warnings**. Tests **154 pass, 2 known
failures** — the same two, unchanged all session. A `flutter create` control app
and a compiled-plugin disassembly were both used to settle questions the
documentation could not.

---

## Session: 25 August 2026 — Windows (Claude Code CLI)

**History screen: date range filter, day grouping, an honest export label. Plus a
test that could not fail on Windows.** ✅ Built and installed to the Teclast P30;
nothing archived, uploaded or submitted. `ios/` untouched.

### History screen (`51fa65e`)

- **Export label corrected.** The sheet header said "Export N filtered events"
  unconditionally, which was true only by coincidence: `showExportOptions`
  recomputes the count from what it is handed, so it always reports 100% of the
  export set and can never say whether anything was narrowed. It now reads
  **"Export 56 of 66 events"** when narrowed and **"Export all 66 events"** when
  not. `_isNarrowed` is derived from the FILTERS, not by comparing counts — a
  count comparison would call an active filter "not narrowed" whenever it
  happened to exclude nothing, the same accidentally-true failure being replaced.
- **Date range filter added** — four presets, no custom range. Filters on
  `timestamp`, which `DATA-MODEL.md` maps to `logged_at` ("never null, never
  editable"), deliberately NOT `occurred_at`: that column is nullable and the
  migration leaves it NULL for every record that exists today, so a filter
  against it would match none of them and would change meaning when the
  expansion lands.
- **Day grouping** — one header per day, times beneath, Today/Yesterday then the
  date. The list stays lazy: grouping by nesting a ListView per day would need
  `shrinkWrap`, which builds every row up front.
- A defect was caught **on the device before commit**: the selected chip rendered
  a checkmark with an invisible label, because an explicit `labelStyle` overrode
  both the theme's `labelStyle` and its `secondaryLabelStyle` (white), leaving
  dark text on the dark blue `selectedColor`.

### `ios_handoff_test` could not fail on Windows

`Directory.listSync` returns native separators, so on Windows every path arrives
as `ios\MERWidget\...` and three `contains('/Foo/')` predicates silently missed.
The consequences ran both ways:

- `/MERWidget/` is an **inclusion**, so the extension list came back empty, the
  test's own positive control fired, and the guard was **unfalsifiable on
  Windows while passing on the Mac**.
- `/Pods/` and `/.symlinks/` are **exclusions**, so they excluded nothing.
  Harmless only because neither directory exists on a Windows checkout —
  CocoaPods is Mac-only. One vendored-Pods checkout and the scan quietly becomes
  a search through other people's example apps, which is precisely what the
  `setUp` comment warns against.

Fixed by normalising at the comparison rather than rewriting `f.path`, so failure
messages still print the real native path.

**Proved it can now fail**, rather than asserting it: a line containing
`mer_records` was appended to `ios/MERWidget/MERWidget.swift`, the guard failed on
the REAL assertion (`Expected: false, Actual: <true>`, naming
`ios\MERWidget\MERWidget.swift`) rather than on the positive control, and the file
was restored with `git checkout`. `ios/` subtree hash confirmed identical before
and after: `7c7a71623846fdb6337dae5cc4cf562b0e7fa33c`.

### Test baseline — corrected

**The baseline is 2 known failures on BOTH platforms.**

Between the Mac's iOS-transport work landing and this fix, Windows showed **3**.
The third was never a real failure: it was the path-separator bug above, firing
its own positive control. Earlier entries in this log record "2 pre-existing
failures" and were accurate when written — `ios_handoff_test` did not exist in
those windows — and they are accurate again now. Nothing in them needs amending.

The two that remain are unchanged and still not fixed:

| Test | Why |
|---|---|
| `app_smoke_test` | sets the obsolete `disclaimerAccepted` bool; the app reads `disclaimerAcceptedVersion` |
| `export_options_test` | same obsolete key, and additionally taps a menu item that no longer exists after the Your data restructure |

### Verified

`flutter analyze` 39 issues, zero errors and zero warnings. Tests **132 pass, 2
known failures**. `ios/` subtree `7c7a71623846fdb6337dae5cc4cf562b0e7fa33c`,
unchanged. Verified on the Teclast P30 from the running screen: both export
headers, the narrowed count, Clear filters, day grouping including a
non-relative header (`WED 6 MAY 2026`), and the empty state.

---

## Session: 24 August 2026 — Windows (Claude Code CLI)

**Android capture inbox built and tested on a physical device. Backlog items 13
and 14 closed.** ✅ Built and installed to a device; nothing archived, uploaded
or submitted. `ios/` untouched.

Full detail in the Change Register entry **"Android inbox — device test,
24 August 2026"** — measurements, certificate digests and the device property
dump are there rather than repeated here.

### Android capture inbox (`ba3f99a`)

- **The property: Dart's main isolate is now the only writer of
  `epilepsy_event_records_v1`.** Every other capture path posts a fact.
  Established mechanically, not asserted — `setString(kEventStorageKey, …)`
  appears exactly once in `lib/`, inside `writeEventPayload`, whose only caller
  is `EventStore._write`, behind the serialising queue. A test walks every
  `.dart` under `lib/` and fails if any other file writes that key.
- **One key per instruction**, `mer_inbox_<uuidv4>`, never an array append —
  appending to a JSON array is itself a read-modify-write, so an inbox built
  that way would fix nothing. Two kinds, facts only, the drain applies defaults.
  An end carries **seconds**, not a bucket; the bucket is a storage decision and
  belongs with the writer of the store.
- **The drain lives in `_loadRecords`**: apply, write, verify, and only then
  delete the keys. Clearing first would lose whatever the write failed to
  persist. Off the capture path entirely — `_quickRecord` and the unawaited
  `_persist()` are untouched.
- **`_handleStart` and `_handleEnd` no longer read or write the record list.**
  They previously decoded the whole stored list, inserted or amended, and
  re-encoded it past the queue. That was backlog item 13.
- **Windows guard on `endEvent()`** (backlog item 14). Changes nothing today,
  which is the point: it was unreachable only by a two-step argument about
  another key, and is now a guard.
- Schema documented as a cross-platform contract, because step 2 adds a Swift
  writer against it. Two contract requirements are written into the schema docs
  rather than only the code: `at` is parsed `DateTime.tryParse(raw)?.toLocal()`,
  never bare — the same normalisation as `EventRecord`, and the ten-hour trap
  fixed in `e48d91b` — and ids are compared by exact string equality and never
  case-folded, because Swift emits uppercase UUIDs and restore matches exactly.

### Deferred-start orphan case closed (`ad14413`)

- An end whose start is deferred (unknown `v` or kind) is now **held back
  alongside it** instead of being dropped as an orphan. The orphan rule was
  written for an end whose record the user deleted; applied to an end whose
  start sits undrained three keys away, it lost a duration that was present and
  readable.
- The unchanged path is asserted as unchanged: an end matching nothing at all is
  still dropped and still reported. Deferral and drop stay distinguishable in
  telemetry.
- Required reading `id` out of a payload the version gate otherwise says not to
  inspect — narrow and deliberate, reasoned at the point of the read.

### Android device test — Teclast P30 tablet

- **Release build**, not debug, deliberately: the historical Android failures
  lived in the background isolate and isolate behaviour differs between the two.
  `flutter build apk --release`, signed with the release keystore, `apksigner
  verify` reports **Verifies**, v2 scheme.
- Device: **Teclast P30 tablet** (`P30_ROW`, 800×1280 @ 160dpi, ~9.4"),
  **Android 15 / API 35**, `arm64-v8a`. Unchanged since the May test. See the
  24-Aug-26 clarification on the 6 May entry below — "P30" is a tablet, not a
  Huawei phone.
- **In-place upgrade, data preserved** — established BEFORE installing, because
  the answer turns entirely on the signature: same certificate, same package,
  versionCode 3 → 5. Confirmed on device afterwards by `firstInstallTime`
  unchanged at 2026-05-06 with a new `lastUpdateTime`. Device reports back
  `1.1.0` / `5`.
- A Play-installed build would NOT have matched, since Play App Signing re-signs;
  that install fails cleanly and only a subsequent uninstall would wipe.

### Verified on device

- **`kDisclaimerVersion` 1.0 → 1.1 re-prompted an existing user. First
  confirmation of that path anywhere** — the iPhone was always a fresh install
  after the earlier wipe, so the upgrade branch had never actually run.
- Data retained across the upgrade.
- **Notification round trip with correct bucketing:** start → 2m30s → end →
  "1-5 minutes" in the edit screen. The seconds travelled as an end instruction
  and were bucketed at drain time, not at capture time.
- Feedback notification then the restored persistent notification — the
  3-second-delay ordering, correct.
- **BACKLOG ITEM 13 CLOSED on hardware.** Red button followed immediately by a
  notification start/stop produced **both** events, neither clobbered. The
  quick-record event kept its `lt1` default — correct, nothing measured it — and
  the notification event showed "1-5 minutes" from 1m15s. That interleaving used
  to lose one of the two.
- **Ten rapid taps produced exactly ten records.**
- **Backup and restore verified on Android for the first time.** Both had only
  ever been exercised on Windows and iOS.
- Backup reminder banner showing correctly, and its suppression rules not firing
  when they should not.

### Removed from the device

- **`au.com.notiva.medical_event_recorder`** (v1.0.0, pre-rebrand) was still
  installed alongside the real `au.com.notiva.medicaleventrecorder`. It shipped
  the underscored **namespace** as its `applicationId` — the value `CLAUDE.md`
  records as "internal R class only" — so the app drawer held two identical MER
  icons. Uninstalled by the developer during this test.
- Recorded for the failure mode, not the clutter: **opening the wrong icon would
  have looked exactly like the drain failing** — an event captured in one app and
  absent in the other, with no visible reason, on the one code path this release
  changed.

### Gaps — recorded, not closed

- **No Android coverage below API 35** (backlog item 15). MER ships to roughly
  API 23, and the entire tested range is one API level. Foreground-service and
  background-isolate behaviour changed materially at **26**, **31** and **34** —
  and the inbox writes from exactly that isolate.
- **No Android phone form factor, ever** (backlog item 16). Every Android test on
  record is on a tablet.
- **EMUI has never been exercised.** `ro.build.version.emui` is empty on a
  Teclast. EMUI is one of the more aggressive notification regimes on Android, so
  treating past "P30" results as covering it would overstate exactly the surface
  where four of the seven historical failures lived.
- The 30-minute abandonment timeout remains untested, and is still the only
  recovery when an event cannot be ended.

### Verified

`flutter analyze` 42 issues, zero errors and zero warnings — unchanged from the
session baseline, read as the total rather than a filtered count. Tests 91 pass,
up from 86, with the same two pre-existing widget failures (`app_smoke_test`,
`export_options_test`, both on the obsolete `disclaimerAccepted` key;
`export_options_test` additionally targets a menu item that no longer exists).

**`ios/` byte-identical throughout:** subtree `40aacaa8363a450038750af8d2225144811d7e0f`
at every commit this session, so v1.1.0's iOS device test remains a regression
check rather than full re-verification.

---

## Session: 19–22 August 2026 — Windows (Claude Code CLI)

**v1.1.0 work: data-loss fix, version drift fix, JSON backup/restore. Plus a full
claims pass across the app and notiva.com.au.** ✅ Nothing built, released or deployed.

### Data loss (P0)
- `EventRecord.fromMap` returned non-nullable and parsed the timestamp unguarded.
  One malformed record threw inside `load()` and made the ENTIRE history
  unreachable — every record lives in one JSON string under one key, so there was
  no partial recovery. `fromMap` now returns `EventRecord?`; bad records are
  skipped individually. Two adjacent casts with the same blast radius were guarded
  the same way. `jsonDecode` of the whole payload left unguarded on purpose.
- A bad timestamp is NOT defaulted to `now()` — a silently wrong date in a medical
  record is worse than an omission.
- Proven, not reasoned: `test/event_store_load_test.dart`, plus a scratch run
  showing the pre-fix path threw and recovered nothing on the same payload.
- Commit `8b73ad2`.

### Version drift (#130)
- pubspec said `1.0.3+4`, `constants.dart` said `1.0.2`, `main.dart` hardcoded the
  Sentry release as `1.0.2+3` — so every error since 1.0.2 was misattributed.
- `kAppVersion` removed. `lib/app_info.dart` reads platform package metadata via
  `package_info_plus`; the Sentry release derives from it. No hardcoded version
  remains anywhere.
- Bumped to **1.1.0+5**. Release format unchanged (`package@version+build`).
- Then taken OFF the cold-start path: `AppInfo.load()` is no longer awaited before
  `NotificationService.init()`, because on Android a cold start from a notification
  action IS the capture path. The release is stamped in `beforeSend` instead.
- Commits `bc4dc77`, `5f1c457`.

### Backup / restore (#133), rollback key (#135), reminder (#134), warnings (#136)
- JSON envelope with schema version, merge-by-id restore that only ever adds,
  refusing corrupt / foreign / newer-schema files without touching stored data.
- Rollback copy before every save — **never on iOS**, deliberately: the native
  Swift capture path bypasses Dart, so a rollback copy there would go stale and
  restoring from it would resurrect deleted events. Guard carries a DO NOT REMOVE
  comment.
- Reminder banner at 10 events, suppressed entirely around the capture path.
  Counter now resets only on a demonstrably completed backup, not on opening the
  share sheet.
- Help and disclaimer warnings about what destroys data.
- **iOS backup sheet: "Save to a file" removed (22 Aug).** It threw
  `UnimplementedError` — `file_selector` ships no save dialog for iOS, so
  `getSaveLocation` fell through to the platform-interface default. Suppressed where
  the sheet is built (`if (!Platform.isIOS)`), not by catching the throw: an option
  that appears and then fails is worse than one that never appears, and with no iOS
  save dialog to fall back to a caught error could only become an apology. iOS now
  offers Share and Cancel; Share reaches Files, so the user still chooses where the
  backup lands. `showExportOptions` has always carried this exact guard — the backup
  sheet was written later and did not inherit it, which is the same
  local-correctness-does-not-propagate pattern recorded elsewhere. Audited all six
  file_selector platforms: iOS **and Android** lack a save dialog, but Android never
  reaches it (its own Downloads branch returns first); Windows, macOS, web and Linux
  support it. CSV export was checked and was never affected. Share and restore
  untouched on every platform.
- Commits `bd5a28d`, `27981ca`, `e2edbe6`, `fa44b29`, `a56fd28`.

### Audits (read-only)
- Capture model: the model is NINE fields, and published copy claimed several it
  does not support.
- Notification/capture baseline: **five** record-creation sites, not three — two
  are native Swift, invisible from Dart.
- iOS provenance: all 92 commits reachable from HEAD; no unmerged iOS work exists
  anywhere. `AppDelegate.swift` and `ios/MERWidget/` are byte-identical to the
  shipped release.

### Documentation
- `docs/ARCHITECTURE.md` added, generated from code.
- `CLAUDE.md` corrected — it recorded 1.0.3+4 and described iOS notifications as
  awesome_notifications with `ActionType.Default`. iOS has been native Swift since
  CR-42.
- claude.ai Project instructions written and versioned in `docs/`.
- `docs/iOS Device Test Checklist.md` added — the iOS counterpart to the Windows
  Store Submission Checklist, pointed to from `CLAUDE.md`. Written from a chat draft,
  then verified line by line against `AppDelegate.swift`, `ios/MERWidget/`,
  `notification_service.dart`, `home_screen.dart` and the v1.1.0 backup code. Eleven
  corrections; the draft had the Android foreground-service model in step 1, put the
  Face ID constraint on the start path instead of the end intent, said Show Previews
  makes the lock-screen action unreachable when it only requires a password, and
  missed that step 5 proves nothing on an event under a minute because `lt1` is both
  the default and the correct answer. **Verifying it surfaced an open defect: "Save to
  a file" in the backup sheet raises `UnimplementedError` on iOS** — `file_selector_ios`
  does not implement `getSaveLocation`. Share works. Fixed the same day (see Backup /
  restore above); checklist section 9 now explains why the option is absent instead of
  recording it as a defect.
- Commits `c0e15d2`, `8fc957e`, `1532f43`, `509b744`, `e8405eb`, `be69254`, `5c2fc73`.

### Claims audit and site deploy
- **Nine unsupported claims** corrected across the app, notiva.com.au and the
  draft store copy. These are claims the product does not support — distinct from
  the nine-field capture model noted above, which is what it does.
- **notiva.com.au deployed and verified live.** Deployed and verified are two
  separate claims; both were checked, not inferred from the deploy succeeding.

### Storage key de-duplicated
- The event storage key was spelled out in more than one place. Now a single
  `kEventStorageKey` in `constants.dart`, referenced everywhere. A key written
  twice is a key that can drift in one copy only, and what it addresses is the
  entire event history in one JSON string.

### Notification failure history (read-only)
- **Seven** recorded notification failures across the project's history. All
  seven were caught pre-submission on a physical device. **None reached Apple.**
- **Four of the seven shared one root cause**, fixed by CR-42.
- The finding is the pattern, not the count: a physical-device check caught every
  one of them, and no analyzer or simulator pass would have.

### App Store Connect — verified for the first time
- The **Apple Developer Program License Agreement had lapsed**, and it was
  blocking the entire App Store Connect API — including the Xcode Organizer
  route, which fails for the same reason and does not announce why. Now accepted.
- First time App Store Connect state has been read directly rather than inferred.
- Detail lives in the ClickUp sub-page **"MER — App Store Connect Verified State
  (20 Aug 2026)"** and is not duplicated here.

### Decision: v1.1.0 ships for the P0 fix
- v1.1.0 goes out for the data-loss fix alone. **iOS is deliberately unchanged**,
  which makes the iOS device test a regression check rather than a test of new
  work: if iOS misbehaves, this release did not cause it.
- **`IPHONEOS_DEPLOYMENT_TARGET` raise to 17.0 is deferred to v1.2.0.** Bundling
  it with the P0 fix would forfeit exactly that property.

### Test device coverage
- Physical device coverage recorded — see the Change Register amendments.
- **iOS 15 through 18 are untested against the CR-42 design.** Recorded as a
  known gap rather than left as an unstated assumption. CR-42 is the native Swift
  notification architecture, so this is the least-covered load-bearing path.

### Housekeeping
- `.gitattributes` now covers `*.txt` (commit `c8b284d`). Preventative only: all
  246 tracked files were enumerated and **zero text blobs contain CRLF**, so
  `git add --renormalize .` had nothing to renormalise. The 102 CR-bearing blobs
  are all binary. Reasoning is in that commit message.

### Verified
`flutter analyze` 51 infos, zero errors/warnings — identical per-file distribution
to the session-start baseline. 21 tests pass, up from 0. Two pre-existing widget
test failures remain (`app_smoke_test`, `export_options_test`) — they set an
obsolete `disclaimerAccepted` bool and already failed at `ce2b964`. Not fixed.

Re-verified 22 Aug after the line-ending commit: `flutter analyze` 51 infos,
the list byte-identical to the session-start baseline (not merely the same count);
21 pass and the same 2 pre-existing failures.

**iOS native untouched this session, deliberately.** v1.1.0 is additions only.

---

## Session: 4 June 2026 — Mac (Claude Code CLI)

**TestFlight external testing set up for MER** ✅

- Bumped version to `1.0.3+4` — required because the 1.0.2 App Store train is fully closed to new builds
- Added `ITSAppUsesNonExemptEncryption = false` to `ios/Runner/Info.plist` — prevents export compliance prompt on future builds
- Built IPA 1.0.3+4 via `flutter build ipa --release` and uploaded to App Store Connect via `xcrun altool`
- External TestFlight group created: **"MER External Limited Time Access"**
- Public link: `https://testflight.apple.com/join/FasRwT2z` (inactive until build approved)
- Build 4 submitted for beta review — **APPROVED** ✅ (~5 Jun 2026)
- Tester added and invite sent via public link
- Commits: `739b693`, `4c18dd7`, `5966425`. Pushed to origin.

**Note:** 1.0.3 is now the active version string — next App Store submission must use 1.0.3+5 or higher.

---

## Session: 13 May 2026 — Windows (Claude Code CLI)

**Google Play MER v1.0.2 CONFIRMED LIVE** ✅
- v1.0.2 (version code 3) approved and published on Google Play
- Submitted 10 May 2026, confirmed live 13 May 2026
- All three stores now on v1.0.2: Apple App Store ✅ · Google Play ✅ · Microsoft Store (v1.0.0, no update submitted)

---

## Session: 6 May 2026 — Windows (Claude Code CLI)

**CR-43: Android notification flow — complete** ✅
- End-event feedback notification navigates to edit screen on tap
- `onActionReceived`: `openLatest` payload handled *before* `initialize()` call to eliminate race window
- `HomeScreen._handleResume()` + cold-start: 8×250ms polling loop (replaces fragile fixed delay)
- Notification branding: all feedback notifications now have `largeIcon` + `color(0xFF0D4F82)` + `BigText` — mandatory pattern documented in CLAUDE.md
- Notification wording: Android-appropriate copy (tap, not long-press)
- Notification ordering: 3s delay before `_showNormal()` in `_handleEnd()` so end-event summary stays at top of shade
- Help screen: "Reviewing the event" row added for Android
- Commits: `4d1514a`, `0468e6f`. Pushed to origin.
- Tested on P30 ROW (Android 15) — all flows confirmed ✅
  **Device clarified 24-Aug-26: "P30 ROW" is a TECLAST P30 TABLET** (`P30_ROW`,
  800×1280 @ 160dpi, ~9.4"), not a Huawei P30 phone. Same model string, entirely
  different device. So this and every other Android result on record are tablet
  results, and no Huawei/EMUI notification behaviour applies to any of them
  (`ro.build.version.emui` is empty). Nothing here is retracted — the line was
  ambiguous rather than wrong, and the 7 May register entry already recorded it
  as a tablet.

---

## Session: 6 May 2026 — Mac (Claude Code CLI)

**CR-42: Lock screen notification — iOS complete** ✅
- Simplified notification tap navigation: signal-based (`openLatestEvent`) — no ID passing needed; Flutter opens `_records.first` after reload
- Fixed reliable duration capture: `didReceive` now explicitly syncs App Group records → `UserDefaults.standard` before signalling Flutter; eliminates dependency on `syncFromSharedIfNeeded`
- Sentry release + environment tags added to `main.dart` (release: `au.com.notiva.medicaleventrecorder@1.0.1+2`, environment: production)
- Tested 5 consecutive runs on both Wazza's iPhone 15 Pro Max and Danny's iPad Pro — all passed ✅
- Commits: `285bb74`, `17a0a4b`, `2b18cdd` + 8 further CR-42 commits
- Sentry MCP authenticated via OAuth on Mac (HTTP transport, user scope)

**Sentry work complete** ✅
- MEDICAL-EVENT-RECORDER-2, -3, -4 — confirmed test artifacts (adhoc builds, Danny's iPad, 3–5 May). Archived in Sentry dashboard.
- Notiva privacy policy — Sentry disclosure already live at notiva.com.au/medical-event-recorder/privacy/. No changes needed.
- dSYM upload build phase added to `ios/Runner.xcodeproj/project.pbxproj` (UUID 49199A0DF28845FAB5747A7B). sentry-cli 3.4.1 at /usr/local/bin. Auth token (org:ci) in ~/.sentryclirc. 4 dSYMs confirmed uploaded on first build.

**MER v1.0.2 built and submitted to Apple App Store** ✅
- v1.0.1 confirmed live (released 5 May 2026)
- Version bumped to 1.0.2+3. Fixed `kAppVersion` splash screen bug (was displaying 1.0.0). Sentry release tag updated.
- MERWidget/Assets.xcassets widget icon assets committed (omitted from CR-42).
- All commits pushed to origin from Mac.
- IPA built via `flutter build ipa --release`. Uploaded via Xcode Organizer.
- **Submitted — Waiting for Review.** Submission ID: `baa1f74d-c017-4878-8767-3dcdef69156b`. 6 May 2026 at 5:20 AM. Automatic release, 7-day phased rollout.
- Commit: `192ae40`

**Next (Windows session):**
- ~~Add CR-42 + v1.0.2 entries to Change Register (OneDrive)~~ ✅ Done 6 May 2026
- ~~Update Notiva privacy policy with Sentry disclosure~~ ✅ Already live — verified 6 May 2026
- Set up TestFlight internal testing — add Waz + Paula in App Store Connect → NOTIVA Internal group (after v1.0.2 review clears)

---

## Session: 3 May 2026 — Mac (Claude Code CLI)

**MER v1.0.1 SUBMITTED to Apple App Store** ✅
- Submitted 3 May 2026 — Waiting for Review
- Submission ID: `063bcd45-6947-491e-b34b-b17b9e89e1e7`
- Version 1.0.1, Build 2
- iPhone + iPad (TARGETED_DEVICE_FAMILY = "1,2")
- iPad screenshots uploaded (6 × 2048×2732 from Danny's iPad)

**What was done:**
- Bumped version to `1.0.1+2` in pubspec.yaml. Commit `6168af4`.
- Changed `TARGETED_DEVICE_FAMILY` from `1` to `"1,2"` across all Xcode configurations (Debug/Profile/Release). Commit `6168af4`.
- Built IPA with `flutter build ipa --release` (23.3MB)
- Uploaded via Xcode Organizer → App Store Connect → Distribute App
- Created v1.0.1 in App Store Connect, uploaded 6 iPad Pro 13" screenshots
- Answered export compliance: None of the algorithms (no custom encryption)
- Submitted for App Store review

**Next:**
- Await Apple review result (email to apps@notiva.com.au, up to 48 hours)
- Update Change Register on Windows with session commits
- Complete TestFlight internal testing setup — add Waz and Paula as Users in App Store Connect, then add to NOTIVA Internal group
- Update Notiva privacy policy with Sentry disclosure

---

## Session: 29 April 2026 — Mac (Claude Code CLI)

**MER v1.0.0 SUBMITTED to Apple App Store** ✅
- Submitted 29 April 2026 — under review (up to 48 hours)
- Bundle ID: `au.com.notiva.medicaleventrecorder`
- Version 1.0.0, Build 1
- iPhone only for v1.0 (iPad deferred to v1.0.1)
- Distribution certificate: Apple Distribution: NOTIVA (B7LWF6Z674)
- IPA built via `flutter build ipa --release`, uploaded via Xcode Organizer

**What was done:**
- Fixed DEVELOPMENT_TEAM — unified all configurations to Notiva `B7LWF6Z674`. Commit `0e6bd04`.
- Changed TARGETED_DEVICE_FAMILY from "1,2" to "1" (iPhone only). Commit `0e6bd04`.
- Created Apple Distribution certificate for Notiva in Xcode
- Built App Store IPA (23.3MB) — `flutter build ipa --release`
- Resolved export compliance — no custom encryption (None of the algorithms)
- Set App Information: Category (Medical), Content Rights
- Submitted for App Store review

**Next:**
- Await Apple review result (email to apps@notiva.com.au, up to 48 hours)
- Update Change Register with today's commits
- Plan v1.0.1: iPad support (TARGETED_DEVICE_FAMILY = "1,2"), iPad screenshots, lock-screen-without-unlock (Phase 5)

---

## Session: 29 April 2026 — Windows

**MER v1.0.0 PUBLISHED on Microsoft Store** ✅
- Store ID: `9PMJ09CDSL6K`
- Published 29 April 2026 — live and available to customers
- Email confirmed: "Your submission for the app Medical Event Recorder has been processed."
- URL: https://apps.microsoft.com/detail/9PMJ09CDSL6K

---

## Session: 26 April 2026 (evening) — Windows (Claude Code CLI)

**What was done:**

- **MS Store tax/payout banner resolved** — ticket #2604210030008414 cleared. Blocker removed.
- **DEF-37: Quick Log Notification section hidden on Windows** — Help screen was showing the notification section on Windows (mobile-only feature). Wrapped `_Section` in `Platform.isWindows` guard. Commit `b289a26`.
- **MSIX signing fixed** — `msix` package passes certificate password through cmd.exe where `!`, `%`, `[` are mangled, causing silent fallback to test cert. Fix: `sign_msix: false` in pubspec.yaml, sign manually with `signtool.exe` via PowerShell. Signing password removed from pubspec.yaml permanently. Commit `8801097`.
- **Microsoft OpenJDK 21 installed** — required by `sentry_flutter` transitive `jni` dependency for Windows compilation. Build-time only, not in MSIX.
- **MER MSIX v1.0.0.0 built and submitted to MS Store for certification** — Store ID: `9PMJ09CDSL6K`. Signed with `CN=520D1E31-3542-4059-8124-5366ECCA4994`. Submitted 26 April 2026.
- **Change Register updated** — entries 41–42 added (DEF-37, MSIX build/signing).
- **ClickUp updated**.

**Tested:**
- Windows smoke test (exe) — all functions confirmed ✅
- Norton 360 flagged as suspicious (expected for self-signed new exe — not an issue for Store version) ✅

**Next:**
- Await MS Store certification result for MER (email to apps@notiva.com.au)
- Await MS Store certification result for SoundFind (email to apps@uniquegames.com.au)
- Await illion CSC-207240 — unblocks Google Play and Apple for both apps

---

## Session: 26 April 2026 (afternoon) — Mac (Claude Code CLI)

**What was done:**

- **DEF-36: Reverted iOS notification action type to Default** — `SilentBackgroundAction` (added in commit `368bb34`) was confirmed unreliable in release builds on a locked device. Background Dart isolate does not execute consistently in release mode. Reverted both buttons (`Log Event Now` and `Event Ended`) to `ActionType.Default` for iOS. Requires FaceID/unlock but works 100% reliably. Lock-screen-without-unlock deferred to Phase 5 (`UNNotificationServiceExtension`). Commit `9877054`.
- **Installed clean release build** on Wazza's iPhone 15 Pro Max via `xcodebuild` + `xcrun devicectl` (DerivedData path required — flutter build path lacks proper framework signing).
- **Confirmed working:** Both notification buttons work after FaceID unlock. Active event banner shows/clears correctly.

**Tested on device:**
- Wazza's iPhone 15 Pro Max (iOS 26.3.1) — full notification flow confirmed with Default action type ✅

**Next (Windows session):**
- Add Change Register entry for DEF-36 (commit `9877054`)
- Update pending entries from previous session (DEF-35, CR-36, CR-37, CR-38)
- Take iOS App Store screenshots from Wazza's iPhone 15 Pro Max (connected via USB)
- See ClickUp handoff doc for screenshot spec and screen list

**Phase 5 backlog (future release):**
- Lock-screen-without-unlock via `UNNotificationServiceExtension` — proper native iOS extension that runs in its own process, independent of Flutter app lifecycle

---

## Session: 26 April 2026 — Mac (Claude Code CLI)

**What was done:**

- **DEF-35: iOS background isolate crash** — `SharedPreferencesPlugin` not registered in awesome_notifications background isolate. Fixed by adding `SharedPreferencesPlugin.register(...)` and `import shared_preferences_foundation` to `AppDelegate.swift`. Commit `52b41b9`.
- **CR-36: Active Event Banner** — HomeScreen now shows a red "Event in progress" banner above the Record Event button when `mer_active_event` is set in SharedPreferences. Shows start time, elapsed duration, and one-tap End Event button. Banner clears when event is ended via app or notification. Commit `a42594f`.
- **CR-37: iOS Help screen notification instructions** — "QUICK LOG NOTIFICATION" section in HelpScreen is now platform-aware. iOS: long-press instructions + Show Previews → Always path. Android: existing instructions unchanged. Commit `a42594f`.
- **CR-38: iOS feedback notification wording** — Confirmation shown after "Log Event Now" now says "Long-press the notification to end the event" on iOS. Commit `fc01e97`.

**Tested on device:**
- Wazza's iPhone 15 Pro Max (iOS 26.3.1) — full notification flow confirmed ✅
- Paula's iPhone (iOS 16.7.15) — notification flow confirmed, UI sizing confirmed ✅

**Next (Windows session):**
- Add Change Register entries for DEF-35, CR-36, CR-37, CR-38 (commits above)
- Take iOS App Store screenshots from Wazza's iPhone 15 Pro Max (connected via USB)
- See ClickUp handoff doc for screenshot spec and screen list

---

## Pending Change Register Entries (add on Windows) — ✅ ALL DONE

⚠️ **CLOSED 28 Aug 2026. Every entry below is present in the Change Register**
(CR-36 through CR-44, DEF-35, DEF-36, v1.0.2, v1.0.3 — verified by grep, with
`CR-15` as a negative control returning zero). The table was left standing after
the work was done, so it read as an outstanding obligation for weeks.

**Kept as the record of what was owed and when.** Do not re-add these.

| ID | Type | What | Commit |
|----|------|------|--------|
| DEF-35 | Defect fix | iOS background isolate crash — SharedPreferencesPlugin not registered | `52b41b9` |
| CR-36 | Change | Active Event Banner on HomeScreen | `a42594f` |
| CR-37 | Change | iOS Help screen notification instructions (platform-aware) | `a42594f` |
| CR-38 | Change | iOS feedback notification wording | `fc01e97` |
| DEF-36 | Defect fix | Revert iOS notification action type to Default — SilentBackgroundAction unreliable in release builds | `9877054` |
| CR-41 | Change | Sentry crash reporting — sentry_flutter added, SentryFlutter.init() wraps appRunner in main.dart, DSN hardcoded for test builds | `cab928b` |
| CR-42 | Change | iOS lock screen notification actions — Live Activity, consecutive event support, reliable duration capture, simplified navigation signal, help screen updates, home screen banner | `285bb74`, `17a0a4b`, `2b18cdd`, `6dac380`, `5cb044f`, `a82742d`, `6e0f4f4`, `48631d6`, `2f02365`, `55e3354`, `8f204df` |
| v1.0.2 | Release | Version bump 1.0.1+2 → 1.0.2+3, fix kAppVersion splash bug, Sentry dSYM build phase, widget icon assets | `192ae40` |
| CR-43 | Change | Android notification flow: tap-to-edit, branded icons, correct wording, ordering fix, help screen update | `4d1514a`, `0468e6f` |
| CR-44 | Config | Add ITSAppUsesNonExemptEncryption=false to ios/Runner/Info.plist — pre-declares export compliance, skips manual prompt on future TestFlight/App Store uploads | `5966425` |
| v1.0.3 | Release | Version bump 1.0.2+3 → 1.0.3+4 for TestFlight external testing build (1.0.2 App Store train closed) | `4c18dd7` |

Also note earlier commits not yet in Change Register:

| What | Commit |
|------|--------|
| iOS setup — awesome_notifications deployment target 15.0, Podfile, AppDelegate | `f693b57` |
| Add quick-log notification service + Help screen | `b5980de` |

## Notes for Windows Claude — Android Notification Path (CR-42 follow-up)

### Background
CR-42 gave iOS the full notification flow: Log Event Now → Live Activity timer → "Event Ended" → feedback notification → **tap feedback notification → MER opens directly to the edit screen**.

The Android path (all in `lib/services/notification_service.dart`) handles start/end correctly but is missing the last step. On Android, tapping the "Event ended · Xm Ys — Open MER to add details" feedback notification opens MER to the home screen — the user then has to find and tap the event manually.

### Android gap — two issues to fix

**Issue 1: Feedback notification auto-dismisses in 4 seconds (too short for end-event)**
In `_showFeedback()`, `timeoutAfter: Platform.isAndroid ? const Duration(seconds: 4) : null` applies to both start and end events. The 4-second window is fine for the "Event started" confirmation but too short for the "Event ended" notification that the user needs to tap.
Fix: pass an optional `timeout` to `_showFeedback`, use `Duration(seconds: 4)` for start, `null` (or 30s) for end.

**Issue 2: Tapping the end feedback notification does not navigate to the edit screen**
Android `onActionReceived` runs in a background isolate — cannot invoke navChannel directly.
Use the same SharedPreferences flag pattern as iOS cold-start (`kPendingOpenLatest`):

1. In `_showFeedback()` (end-event call in `_handleEnd()`), add a payload:
   ```dart
   payload: {'action': 'openLatest'},
   ```

2. In `onActionReceived()`, add after the existing `_btnEnd` block:
   ```dart
   } else if (action.buttonKeyPressed.isEmpty &&
              action.payload?['action'] == 'openLatest') {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setBool('mer_open_latest_event', true);
   }
   ```
   Note: `buttonKeyPressed.isEmpty` means the notification body was tapped (default action), not an action button.

3. In `lib/screens/home_screen.dart`, `didChangeAppLifecycleState` already calls `_loadRecords()` on resume. After that call, add the flag check (Android only):
   ```dart
   if (Platform.isAndroid) {
     final prefs = await SharedPreferences.getInstance();
     final shouldOpen = prefs.getBool('mer_open_latest_event') ?? false;
     if (shouldOpen) {
       await prefs.remove('mer_open_latest_event');
       if (mounted && _records.isNotEmpty) _openLogScreen(existing: _records.first);
     }
   }
   ```

### Testing on Android (Windows)
- Tap "Log Event Now", wait ~1 min, tap "Event Ended"
- Verify: feedback notification stays visible for >4 seconds
- Tap the feedback notification body
- MER should open directly to the edit screen for that event
- Also test cold-start: kill MER from recents, tap feedback notification → should still open to edit screen

## TODO — Next Windows Session
- Update Notiva privacy policy (notiva-site) with Sentry disclosure — same pattern as SoundFind privacy update (short version callout, new Sentry section, rights section). Commit and deploy to notiva.com.au.
- ~~Add all pending Change Register entries to OneDrive doc (see table above)~~ **DONE — verified 28 Aug 2026**
- Update ClickUp handoff doc — TestFlight external testing set up (4 Jun 2026 Mac session), public link https://testflight.apple.com/join/FasRwT2z, awaiting beta review

## Backlog — recorded, not fixed

### OPEN — items that existed only in conversation until 28 Aug 2026

| # | Item |
|---|------|
| C1 | **MER will not render in portrait on the Teclast P30.** No `screenOrientation` in `AndroidManifest.xml`, no `setPreferredOrientations` anywhere in `lib/`, yet the app stays at 1280x800 through `user_rotation 0`, a `wm size 800x1280` override and a relaunch, while the launcher rotates. **Cause unknown and deliberately not guessed.** Consequence: every device verification this session tested ONE orientation, and the landscape-only defects already found (`1c6c359`, the Save button under the nav bar) are exactly the class this hides. |
| C2 | **`renameEntry` is built, tested and unreachable** — no caller in `lib/`. Identical shape to `setActive`, which sat unreachable for three schema versions until "Your lists" shipped. Two entries added on the device while testing (`Cluster headache`, `Jaw ache`) can now be hidden but not corrected. |
| M1-M4 | **Monetisation is decided and not built** — see the Change Register, *The record catches up — 28 August 2026*. No donation mechanism; Terms and store listing still promise a paid app. |


### CLOSED — item 26, the notification-delegate one-liner
Closed as recorded on a premise that cannot be settled from here, not as fixed.

The reassignment itself is in the tree (`0bb8aa7`): a main-queue block at the end
of `didFinishLaunchingWithOptions` that takes `UNUserNotificationCenter.delegate`
back after `awesome_notifications`' constructor-registered observer takes it. It
is cheap, it is correct hardening regardless, and it carries an `os_log` line
recording whether the delegate had in fact been stolen. **It has not been read
back, and it is not claimed as the cause.**

What is settled is the boundary, not the mechanism — see
`docs/ARCHITECTURE.md` §5, "iOS end-of-event routes, and where the boundary is".
`didReceive` is not entered for a notification response while the app is cold,
measured twice with an internal control, cause unattributable without Apple.
Chasing it further is a Technical Support Incident and does not change what ships.

Stop re-deriving this. Both the sub-17 and the iOS 26 investigations returned to
it and neither could close it from source.


### CLOSED 28 Aug 2026 — abandoned events get a wrong duration
**Fixed by the capture-model change, not by a fix aimed at this.** Records are
now created with a NULL duration, so an abandoned event is already honest and
there is nothing to correct. `_clearIfTimedOut` clears the MARKER only, and says
so at the call site.

An `abandon` instruction WAS built here and then removed: it solved a problem
that belongs at creation, it only ever reached Android because the iOS timeout is
native, and it could null a duration the user had since filled in by hand.

⚠️ **This item was still being cited as the top open defect on 28 August**, in a
memory file and in this document, after it had been fixed. Stale-open is the
mirror of stale-decided, and it is harder to spot because it looks like
diligence. The original text is preserved below for the reasoning, which is still
correct about why a wrong duration would have been worse than a missing one.

> `NotificationService._clearIfTimedOut()` discards an active event after 30
> minutes, but the record it leaves behind keeps `duration` at its `lt1`
> default. An event that was started and never ended therefore reads as
> "< 1 minute" in the user's medical record. Wrong data is worse than missing
> data, and a clinician reading the export cannot tell the two apart.

### v1.2.0+ (native) — iOS has no rollback copy
`writeEventPayload` deliberately skips the rollback key on iOS, because the
native Swift capture path writes the primary key without passing through
Dart. The proper fix is to replicate the snapshot in
`AppDelegate.handleQuickLogStart` and `EndMEREventIntent`, so iOS gets real
protection rather than none. Required before any migration (e.g. SQLite) that
would want to roll back.

### Stale — this repo's CLAUDE.md
`CLAUDE.md` still records "Version: 1.0.3+4" (now 1.1.0+5) and describes iOS
notifications as `awesome_notifications` with `ActionType.Default`. iOS has
been native Swift since CR-42 (May 2026) and awesome_notifications is
deliberately never initialised there. Not corrected in this pass — flagged so
it is not read as current.

## Notes for Mac Claude

- `sentry_flutter: ^9.0.0` added to `pubspec.yaml`
- `main.dart` updated — DSN hardcoded, `SentryFlutter.init()` wraps `appRunner`
- Run `flutter pub get` then build and side-load to iPad as normal
- No `--dart-define` needed, no dSYM upload — dSYM upload is for final App Store build only
- CR-41 commit hash updated: `cab928b`
- Confirmed working on Wazza's iPhone 15 Pro Max ✅ — ready to install on iPad when available
