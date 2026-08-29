# Medical Event Recorder — Architecture

**Generated from code at commit `d7760b2`, 28 August 2026, version 1.1.0+49, schema v9, backup schema 2.**

⚠️ **Sections 2, 3, 4, 6, 8 and 9 were regenerated on 28 August 2026 after this document had stood 116 commits and four schema versions behind.** §4 asserted the app did not use SQLite; §9, the section listing what is known to be wrong, was itself wrong in three of its four entries. §1's store claim is marked UNVERIFIED rather than corrected — it needs a console this machine cannot reach.

This document is derived by reading the repository, not written from the
website, the store listing, or memory. Those three have each been wrong about
this app at least once.

> **Regenerate at every version bump.** A stale architecture document is worse
> than none, because it reads as authoritative.
>
> ⛔ **THE STALENESS CHECK HERE WAS INVERTED, AND IT PASSED FOR 116 COMMITS.**
> It read: *"If the commit hash above is not an ancestor of your HEAD, treat
> everything here as a claim to verify."* **An ancestor test can only fail on a
> diverged branch.** As history grows, an old commit becomes more of an ancestor,
> not less — so the guard reported FRESH precisely when the document was most
> stale. Same class as a `grep` that counts lines instead of matches, and a widget
> test that finds nothing because it never laid the widget out: a check that
> reports clean by construction.
>
> **Use this instead, and it must be equality or a distance, never ancestry:**
>
> ```
> git rev-parse --short HEAD                 # equal to the hash above?
> git rev-list <hash>..HEAD --count          # if not, how far behind?
> ```
>
> **If the count is not 0, everything below is a claim to verify, not a fact.**
> At the last regeneration this document had been 116 commits and four schema
> versions behind, and §4 asserted the app did not use SQLite.
>
> Prefer citing files and SYMBOL NAMES over line numbers — the line numbers in an
> earlier revision rotted three times in one week, and then the very table warning
> about it cited six of them, three of which were wrong within days.

---

## 1. What the app is

A local-only medical event recorder. No account, no server, no sync. Every
event lives on the device that recorded it. Notiva never receives event data.

Published on the Apple App Store and the Microsoft Store.

⚠️ **GOOGLE PLAY STATUS UNVERIFIED FROM THIS MACHINE.** An earlier revision said
"Apple App Store, Google Play and Microsoft Store". The Change Register's most
recent statement (26 August 2026) names **two** stores — *"MER is live on the App
Store and the Microsoft Store"* — and the only Play record found is a listing
"submitted for review". **Neither claim is settled from here**; it needs the Play
Console. Recorded as unverified rather than resolved in either direction.

**Windows has materially reduced functionality — see §5.**

---

## 2. The capture model — two record kinds

`EventRecord` and `MedicationNote`, both in `lib/models/`. **This was "nine
fields, and nothing else" and is no longer either half of that**: there are 14
fields on `EventRecord` and a second record kind beside it.

### `EventRecord` — 14 fields

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | uuid v4. Internal; never shown |
| `timestamp` | `DateTime` | **Time of logging, not time of the event.** The `event` table has an `occurred_at` column; the MODEL does not carry it and nothing populates it |
| `duration` | `DurationCategory?` | `lt1, oneToFive, gt5`. **NULLABLE** |
| `durationSeconds` | `int?` | The measured quantity. Wins over the bucket wherever present |
| `detailsCompleted` | `bool?` | Three-state. NULL means a record that predates the concept, not "incomplete" |
| `eventType` | `String?` | **A STRING, not an enum.** The `EventType` enum no longer exists. Holds a vocabulary `value`; user-extensible |
| `severity` | `EventSeverity?` | `mild, moderate, severe`. **NULLABLE** |
| `feelings` | `List<String>` | The AFTERWARDS list. Vocabulary values from the `observation` table — 13 seeded, user-extensible |
| `triggers` | `List<String>` | The BEFOREHAND list. Vocabulary values from `trigger_option` — 7 seeded, user-extensible |
| `rescueMedGiven` | `bool?` | |
| `rescueMedHelped` | `RescueResponse?` | `helped, partly, didNotHelp`. Gated behind `rescueMedGiven` |
| `rescueMedSecondDose` | `bool?` | Gated the same way |
| `referralRequired` | `bool` | A yes/no flag |
| `notes` | `String` | Free text. No length limit, no validation |

### `MedicationNote` — the second kind

Exceptions only: a dose **missed, late or changed**. Not an event, and
deliberately not part of `EventStore`.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | uuid v4 |
| `occurredAt` | `DateTime` | **When the dose was missed** — a real date and time, entered by the user |
| `loggedAt` | `DateTime` | When it was written down. Never editable |
| `kind` | `MedicationDeviation` | `missed, late, changed`. Stored as `.name`, not an ordinal |
| `notes` | `String` | **No drug-name field**, on burden grounds |

The two streams meet only in the CSV, which carries a `record_kind` column
(`kRecordKindEvent` / `kRecordKindMedication`) and sorts them onto one timeline.
**MER does not correlate them** — charting missed doses against events would be
interpretation.

### ⛔ Claims this model does NOT support

These have appeared in published or drafted copy and are false. Check any new
copy against this list.

⚠️ **THIS LIST IS THE ONLY PART OF THIS DOCUMENT USED TO APPROVE OR REJECT STORE
COPY, AND TWO OF ITS FIVE ENTRIES HAD INVERTED — they rejected the TRUE thing.**
Accurate copy saying "before and after" would have been refused by a list that
had not noticed the app gained a beforehand field. Re-derive this list at every
regeneration, and treat an entry that has become true as the more dangerous
failure: a false negative here blocks correct copy, silently, and reads as
diligence.

- **"Date and time of the event"** — for an EVENT it is the time of logging.
  ⚠️ **Now true for a medication note**, which carries a real `occurredAt`.
  Do not generalise either way.
- **"Enter it afterwards"** — you can log an event later, but its timestamp is
  the moment you logged.
- **"Referral information"** — it is a single bool.
- **"Continuous monitoring", "detects", "alerts you"** — nothing observes,
  infers or notifies about a user's condition. The only notification is the
  capture affordance the user started.
- **"Analyses", "insights", "trends", "predicts"** — there is no analysis of any
  kind. History counts and lists; the CSV exports. Nothing derives.

**RETIRED FROM THIS LIST, because the app changed and the entry became true:**

| Was listed as false | Now |
|---|---|
| *"How you felt before, during and after"* — was *"one feelings list with no temporal dimension at all. The prompt is 'How are you feeling?'"* | **TRUE for before and after.** Two temporally-framed lists: *"What was happening beforehand?"* and *"How were things afterwards?"* — renamed 29 Aug 2026 to drop the PERSON, since the store listing claims carers and the old wording addressed the patient. There is still nothing DURING — copy claiming that is false |
| *"Event type (e.g. seizure type, symptom category)"* — was *"four enum values, no sub-types"* | **Partly true.** Types are user-extensible, so a user may name their own. Still no sub-type hierarchy and no symptom categories, and `Other / custom` still has no free-text field — `notes` is the only place to say what it was |
| *"customisable details"* (live App Store listing) | **TRUE.** Three vocabularies are user-extensible |

### Validation

Still none: no `Form`, no validator, no `maxLength`.

⚠️ **But the reason recorded here was retired.** It read *"every field except
`notes` has a non-null default, so a record can be saved without the user
touching a control"*. `duration`, `eventType` and `severity` are now **nullable**,
and NULL means NOT ASKED. A record saved without touching a control no longer
FABRICATES values — it records their absence, and `isIncomplete` surfaces it in
the "Needs details" queue.

---

## 3. Record creation — sites across three runtimes

The Dart code shows most of them. Two are native Swift and are invisible from
Dart. This is the single most common source of wrong assumptions about this app.

⚠️ **CITED BY SYMBOL, NOT LINE NUMBER.** An earlier revision cited six line
numbers in this table and three were wrong within days.

| # | Site | Trigger | Runtime | Writes |
|---|---|---|---|---|
| 1 | `home_screen.dart` `_quickRecord` | Record Event button | Main isolate | `_persist()` → `EventStore.save` |
| 2 | `log_event_screen.dart` save | Save on the single-page form | Main isolate | returns the record, then `_persist()` |
| 3 | `event_wizard_screen.dart` `_capture` / `_build` | Next, Skip to end, or backing out | Main isolate | returns the record, then `_persist()`. ⚠️ **Guarded by `_hasAnyInput`** — an untouched wizard creates nothing |
| 4 | `notification_service.dart` `_handleStart` | "Log Event Now" | **Android background isolate** | `writeEventPayload`; sets `mer_active_event` |
| 5 | `notification_service.dart` `_handleEnd` | "Event Ended" | **Android background isolate** | rebuilds the record to set `duration` from elapsed time |
| 6 | `AppDelegate.swift` `handleQuickLogStart` | "Log Event Now" on iOS | **iOS native, no Dart** | writes `flutter.epilepsy_event_records_v1` in `UserDefaults` directly, mirrors to App Group |
| 7 | `MERWidget/EndMEREventIntent.swift` | Live Activity "Event Ended" | **iOS widget extension process** | mutates `duration` in the App Group copy only |
| 8 | `medication_screen.dart` → `MedicationStore.add` | Record a deviation | Main isolate | `insertMedicationNote` — **a different table and record kind** |
| 9 | `home_screen.dart` restore handler | Restore from a backup | Main isolate | `insertMedicationNote` per note in `RestoreOutcome.notesToAdd` |

Sites 6 and 7 **do not pass through `writeEventPayload`** and know nothing about
any Dart-side storage convention. Anything added to the Dart write path must be
assumed absent on iOS quick-log until proven otherwise.

---

## 4. Storage

⛔ **SQLite.** An earlier revision of this section read *"Single JSON array under
a single `shared_preferences` key. Not SQLite."* That was TRUE when written on
20 August 2026 — SQLite did not exist in the repo at that commit — and it was
false for 116 commits afterwards, in the section a reader consults to answer
"how does MER store data". It is the reason the staleness guard above was
rewritten.

`StorageBoot` picks the store at launch: `SqliteEventStore` normally, falling
back to the shared_preferences store only when the database cannot be opened.

### Tables — schema `kSqliteSchemaVersion`, currently **v9**

| Table | Added | Notes |
|---|---|---|
| `schema_meta` | v1 | key/value. Schema version and migration markers |
| `event` | v1 | 17 columns |
| `event_type` | v2 | Vocabulary. `id, condition_id, value, label, is_seeded, is_active, is_protected, sort_order, emoji` |
| `observation` | v2 | Same shape. Shared across conditions, so `condition_id` is never populated |
| `event_observation` | v7 | `event_id, observation_id, position`. **Additive — `feelings_json` stays authoritative and nothing reads this yet** |
| `medication_note` | v7 | The second record kind. `condition_id` added v8 |
| `condition` | v8 | **Created empty and assigned to nothing.** No UI reaches it |
| `condition_observation` | v8 | Relevance ORDERING, never membership. No rows |
| `trigger_option` | v9 | The beforehand vocabulary |
| `event_trigger` | v9 | `triggers_json` stays authoritative, same rule as observations |

`condition_trigger`, `condition_field`, `event_field_value` and `daily_entry`
are designed and **not built** — see `docs/DATA-MODEL.md`.

### `shared_preferences` keys that remain

| Key | Purpose |
|---|---|
| `epilepsy_event_records_v1` | ⛔ **THE DRAINED INBOX, AND IT STAYS.** No longer the event store — it is what the iOS native path and the Android background isolate write into, drained into SQLite on the next foreground. **Never remove it** |
| `epilepsy_event_records_v1_rollback` | Copy of the previous payload. **Never written on iOS** — the native path bypasses it, so a stale copy would be a data-loss mechanism |
| `mer_active_event` | In-progress event `{id, startIso}` |
| `mer_open_latest_event` | Navigation signal from the Android background isolate |
| `disclaimerAcceptedVersion` | Version string, not a bool |
| `walkthroughSeenVersion` | Version string. Written on PRESENTATION, not completion |

The backup envelope is **separately versioned** at `kBackupSchemaVersion`,
currently **2**. Distinct from the schema version above and bumped on its own
cadence.

---

## 5. Notifications — two solutions, split by platform

They are not layered. The exclusion is deliberate: `awesome_notifications`
reassigns `UNUserNotificationCenter.delegate` to itself, which would break the
native iOS handler. Hence `notification_service.dart:60`:

```dart
if (Platform.isWindows || Platform.isIOS) return;
```

| | iOS | Android | Windows | macOS |
|---|---|---|---|---|
| Implementation | Native Swift: `UNUserNotificationCenter` + ActivityKit + App Intent | awesome_notifications (Dart) | **none** | awesome_notifications (scaffolding, not shipped) |
| Code | `ios/Runner/AppDelegate.swift`, `ios/MERWidget/*` | `lib/services/notification_service.dart` | — | — |
| Native shim | — | `MainActivity.kt` is a bare `FlutterActivity` | — | — |
| Start **and** stop without opening the app | Yes | Yes | **No** | — |

`onActionReceived` returns immediately on iOS (`notification_service.dart:111`).
The plugin is registered on Windows but `init()` returns before using it, so
nothing is ever posted.

⚠️ The Dart guard above is necessary but **not sufficient**, and the note that
`initialize()` is what reassigns the delegate was imprecise. The reassignment is
in the plugin's Swift **constructor**, which `GeneratedPluginRegistrant` runs on
every iOS launch whether or not Dart ever calls `initialize()`:

```
GeneratedPluginRegistrant.register       AppDelegate.swift:99
  -> AttachAwesomeNotificationsPlugin
  -> AwesomeNotifications()              SwiftAwesomeNotificationsPlugin.swift:53
  -> activateiOSNotifications()          AwesomeNotifications.swift:56
  -> addObserver(UIApplication.didFinishLaunchingNotification)  :155-158
  -> didFinishLaunch(_:) -> delegate = self                     :508
```

UIKit posts that notification **after** `didFinishLaunchingWithOptions` returns,
so the assignment at `AppDelegate.swift:132` cannot be the last word. There is a
main-queue reassignment at the end of `didFinishLaunching` and another in
`applicationDidBecomeActive`. Anything added to iOS notification handling must
assume the delegate is contested.

### iOS end-of-event routes, and where the boundary is

| | 17+ | 16.2 – 16.x |
|---|---|---|
| Live Activity posted at start | Yes | Yes |
| Live Activity **End button** | Yes — `EndMEREventIntent`, gated `#available(iOS 17.0)` | **No.** `LiveActivityIntent` needs 17; the card is display-only |
| Active notification posted at start | Yes | Yes |
| Notification **End action** works warm | Yes | Yes |
| Notification **End action** works **cold** | **No** | **No** |
| A cold end route therefore exists | Yes — Live Activity, after Face ID | **No** |
| **In-app End button** on the active-event banner | Yes | Yes |

✅ **THE IN-APP END BUTTON CLOSES THE 16.2–16.x GAP** (`eb8196e`, 27 August 2026,
backlog 25). Every route above depends on a notification or a Live Activity
surviving, and both are user-dismissible — on 16.2–16.x there was no end route at
all once the card was gone. The banner's button does not depend on either.
⚠️ **Not verified on a device**; no Dart work since 27 August has run on iOS.

**ESTABLISHED BOUNDARY — `didReceive` is not entered for a notification response
when the app is cold.**

- Measured on iOS 26.6 and on iOS 16.7.15 — twice, independently.
- The 26.6 run carried an internal positive control: a `UserDefaults` write made
  by the *same* cold background process persisted, while the breadcrumb inside
  `didReceive` never appeared. So the process launches and executes; the
  **response** does not arrive at our handler.
- Corroborated from the other direction by the voice-capture probe, which ran
  cold and locked and whose write persisted. Cold background execution works.
  This is specific to notification-response delivery, not to launch.
- **Cause unknown, and not attributable from here.** Delegate contention is one
  candidate and the reassignment above is in place as hardening — it has not been
  read back, and it is not recorded as the cause. Establishing the cause would
  need Apple (a Technical Support Incident). It does not change what ships.

**Consequence, and this is the line to design against:** the notification is
reliable for **visibility** and unreliable for **ending** while cold. On 17+ the
Live Activity's App Intent is the working cold end route, after Face ID. Below 17
there is no cold end route at all — the event runs to the 30-minute timeout,
which is the abandoned-duration defect recorded in the backlog.

Do not add a capture or end path that depends on `didReceive` reaching us cold.

### Windows, stated plainly

**In-app capture only.** No notification path exists. The store copy's headline
feature — starting and stopping an event from the Lock Screen without unlocking
— does not exist on Windows. The Windows build is a recording and review client.

### Background isolate reality

| Platform | Separate isolate? | `shared_preferences` there? |
|---|---|---|
| Android | **Yes.** Proven by the code needing to re-register channels in it | Yes, but each isolate has its own cache — cross-isolate visibility needs `prefs.reload()` |
| iOS | **No isolate at all** — Swift does the work | n/a |
| Windows | Never fires | n/a |

---

## 6. Startup order

```
1. WidgetsFlutterBinding.ensureInitialized()   local, no IO
2. unawaited(AppInfo.load())                   started, never awaited
3. await SentryFlutter.init(...)               release stamped in beforeSend
     inside appRunner:
4.   await StorageBoot.init()                  opens SQLite, runs the migration
5.   await NotificationService.instance.init()
6.   runApp(AppBootstrap())
```

⚠️ **`StorageBoot.init()` was MISSING from this sequence** for 116 commits — the
one step that opens the database and runs the migration, absent from the section
describing the order, in a document whose §4 also said the app did not use
SQLite. Both came from the same regeneration gap.

`StorageBoot.init()` reports its outcome to Sentry on a fallback or a failed
migration, so a device that quietly fell back to the shared_preferences store is
visible rather than silent.

**Nothing on the cold-start path may await a platform channel.** On Android a
cold start from a notification action *is* the capture path, and it sits upstream
of the `mer_open_latest_event` polling loop (8 × 250ms).

Version and Sentry release come from `lib/app_info.dart`, which reads the
platform's own packaged metadata via `package_info_plus`. There is no hardcoded
version in the code; a previous three-way drift (pubspec, `constants.dart`, and
the Sentry release string) is why. ⚠️ `CLAUDE.md` hardcoded one anyway, on the
line that forbade it, and was 44 builds stale before anyone noticed.

Sentry release format: `au.com.notiva.medicaleventrecorder@<version>+<build>`.

---

## 7. Backup and restore

- **Format:** JSON envelope with `format`, `schemaVersion` (int), `appVersion`,
  `exportedAt`, `recordCount`, `records`, **`medicationNoteCount`** and
  **`medicationNotes`** — eight fields, and the list reads as exhaustive, so it
  is. Deliberately not a bare array: the storage payload's lack of a version
  marker is a mistake not repeated here.
- **`kBackupSchemaVersion` is 2**, since medication notes entered the envelope.
  Separate from the SQLite schema version. **The bump is the safety mechanism,
  not bookkeeping** — `parseBackup` refuses a schema newer than the build, so an
  older build refuses a notes-bearing file instead of restoring the events and
  silently discarding the notes.
- **Medication notes merge by id exactly as records do**, and an absent
  `medicationNotes` key reads as an empty list, never an error — every backup
  taken before schema 2 lacks it.
- **Backup:** user picks the destination every time via the system picker. No
  stored path, no bookmark, no credential, no background write.
- **Restore:** merges by uuid id, so dedup is exact. **Only ever adds.** Existing
  records always win. There is no replace mode by design; `clearAll()` is a
  separate deliberate action.
- **Refusals:** not-a-backup, unreadable/truncated JSON, and a schema newer than
  this build. Validated fully before anything is written, so a restore is never
  partially applied. Unreadable records inside a valid backup are counted and
  reported, not dropped silently.
- **The empty-backup refusal counts BOTH streams.** It was `inBackup == 0`,
  written when events were the only kind, and it refused a backup holding
  medication notes but no events — telling a user who logs only deviations that
  their file contained nothing. A backup is empty when neither stream has
  anything.
- **Reminder banner** at 10 events since last backup, suppressed entirely when
  opened from a notification action, while an event is in progress, or when an
  event was logged this session. The capture path is never gated.
- **Counter resets only on demonstrable completion.** iOS and Android report
  share success vs dismissed; desktop reports `unavailable` and so never resets
  from the share path.

---

## 8. Platform branches

**49** `Platform.is*` sites in `lib/` — an earlier revision said 38. Plus
availability gates in Swift (`iOS 16.0 / 16.2 / 17.0`) that Dart cannot see.

| File | Sites |
|---|---|
| `help_screen.dart` | 13 |
| `home_screen.dart` | 12 |
| `notification_service.dart` | 10 |
| `event_record.dart` | 6 |
| `walkthrough_screen.dart` | 3 |
| `backup_service.dart` | 2 |
| `storage_boot.dart` | 1 |

---

## 9. Known-wrong and unverifiable

⚠️ **THREE OF THE FOUR ENTRIES THAT STOOD HERE HAD BEEN FIXED** — the section
listing what is known to be wrong was itself the most wrong section in the
document. Retired entries are listed below rather than deleted, because a
"known-wrong" list that silently drops items cannot be distinguished from one
nobody maintains.

**Still true — everything about iOS runtime behaviour in this document is read
from source, not observed.** It cannot be verified from Windows. Lock-screen
actions, Live Activity behaviour, the iOS 16.x fallback path, App Group
reconciliation, and cold start from a notification all require a Mac and a
device. **No Dart work since 27 August 2026 has run on iOS at all.**

**Open, and verified open:**

- **`renameEntry` is built, tested and unreachable** — no caller in `lib/`. The
  same shape as `setActive`, which sat unreachable for three schema versions
  until "Your lists" shipped.
- **Multi-condition has schema and no UI.** `ConditionStore`, `loadConditions`
  and `addCondition` have no caller outside `lib/models/`.
- **MER will not render in portrait on the Teclast P30.** No `screenOrientation`
  in the manifest, no `setPreferredOrientations` in `lib/`, cause unknown. Every
  device verification has therefore tested one orientation.
- **Windows conversion untested** — every Windows run has migrated an empty
  store.

**RETIRED — fixed, and the entry outlived the defect:**

| Entry | Fate |
|---|---|
| *"`CLAUDE.md` records version 1.0.3+4 and describes iOS notifications as `awesome_notifications` with `ActionType.Default`"* | Both corrected. `CLAUDE.md` now states no version at all and describes iOS as native Swift |
| *"`_clearIfTimedOut` … leaves `duration` at its `lt1` default, so an abandoned event reads as '< 1 minute'"* | Fixed by the capture-model change — records are created with a NULL duration. The missing-data half remains but surfaces in "Needs details" |
| *"Two pre-existing test failures: `app_smoke_test` and `export_options_test` set an obsolete `disclaimerAccepted` bool"* | Both pass. Each had THREE stacked faults; the obsolete bool was only the first |
