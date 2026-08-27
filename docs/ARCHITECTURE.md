# Medical Event Recorder — Architecture

**Generated from code at commit `5c2fc73`, 20 August 2026, version 1.1.0+5.**

This document is derived by reading the repository, not written from the
website, the store listing, or memory. Those three have each been wrong about
this app at least once.

> **Regenerate at every version bump.** A stale architecture document is worse
> than none, because it reads as authoritative. If the commit hash above is not
> an ancestor of your HEAD, treat everything here as a claim to verify rather
> than a fact. Prefer citing files and symbol names over line numbers — the line
> numbers below were correct at `5c2fc73` and rot on the next edit.

---

## 1. What the app is

A local-only medical event recorder. No account, no server, no sync. Every
event lives on the device that recorded it. Notiva never receives event data.

Published on Apple App Store, Google Play and Microsoft Store. **Windows has
materially reduced functionality — see §5.**

---

## 2. The capture model — nine fields, and nothing else

`EventRecord` in `lib/models/event_record.dart`. This is the whole model.

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | uuid v4. Internal; never shown |
| `timestamp` | `DateTime` | **Time of logging, not time of the event.** No date or time picker exists anywhere in the app |
| `eventType` | `EventType` | enum: `seizure, absence, medication, other` |
| `duration` | `DurationCategory` | enum: `lt1, oneToFive, gt5` (`< 1 min`, `1–5 min`, `> 5 min`) |
| `severity` | `EventSeverity` | enum: `mild, moderate, severe`. Labels only, no numeric scale |
| `feelings` | `List<String>` | Multi-select from 11 fixed options in `kFeelingsOptions`. **Present tense only** |
| `triggers` | `List<String>` | Multi-select from 7 fixed options in `kTriggerOptions` |
| `referralRequired` | `bool` | A yes/no flag |
| `notes` | `String` | Free text. No length limit, no validation |

### Claims this model does NOT support

These have all appeared in published or drafted copy and are false. Check any
new copy against this list:

- **"How you felt before, during and after"** — there is one feelings list with
  no temporal dimension at all. The prompt is "How are you feeling?".
- **"Referral information"** — it is a single bool.
- **"Date and time of the event"** — it is the time of logging.
- **"Enter it afterwards"** — you can log later, but the timestamp will be the
  moment you logged, not when it happened.
- **"Event type (e.g. seizure type, symptom category)"** — four enum values, no
  sub-types and no symptom categories. `Other / custom` has no free-text field;
  the only place to say what it was is `notes`.

### Validation

There is none. No `Form`, no validator, no `maxLength`. Every field except
`notes` has a non-null default, so a record can be saved without the user
touching a control.

---

## 3. Record creation — five sites across three runtimes

The Dart code shows three. Two more are native Swift and are invisible from
Dart. This is the single most common source of wrong assumptions about this
app.

| # | Site | Trigger | Runtime | Writes |
|---|---|---|---|---|
| 1 | `home_screen.dart:226` `_quickRecord` | Record Event button | Main isolate | `_persist()` → `EventStore.save` → `writeEventPayload` |
| 2 | `log_event_screen.dart:164` | Save on the detail form | Main isolate | returns to home, then `_persist()` |
| 3 | `notification_service.dart:161` `_handleStart` | "Log Event Now" | **Android background isolate** | `writeEventPayload`; sets `mer_active_event` |
| 4 | `notification_service.dart:219` `_handleEnd` | "Event Ended" | **Android background isolate** | rebuilds record to set `duration` from elapsed time |
| 5 | `ios/Runner/AppDelegate.swift:250` `handleQuickLogStart` | "Log Event Now" on iOS | **iOS native, no Dart** | writes `flutter.epilepsy_event_records_v1` in `UserDefaults` directly, mirrors to App Group |
| 5b | `ios/MERWidget/EndMEREventIntent.swift` | Live Activity "Event Ended" | **iOS widget extension process** | mutates `duration` in the App Group copy only |

Sites 5 and 5b **do not pass through `writeEventPayload`** and know nothing
about any Dart-side storage convention. Anything added to the Dart write path
must be assumed absent on iOS quick-log until proven otherwise.

---

## 4. Storage

Single JSON array under a single `shared_preferences` key. Not SQLite.

| Key | Purpose |
|---|---|
| `epilepsy_event_records_v1` | The event list. **The `_v1` is a naming convention, not a schema mechanism** — the payload is a bare array with no version field |
| `epilepsy_event_records_v1_rollback` | Copy of the previous payload, written before each save. **Never written on iOS — see below** |
| `mer_active_event` | In-progress event `{id, startIso}` |
| `mer_open_latest_event` | Android cold-start flag from a notification tap |
| `mer_last_backup_at` | Last backup timestamp, for the reminder banner |
| `disclaimerAcceptedVersion` | String, not a bool. Compared against `kDisclaimerVersion` |

### Adding a field is not a migration

`fromMap` reads defensively — `firstWhere(orElse:)` for enums, type guards for
the rest. Add a field with a default, a line in `toMap`, and a guarded read in
`fromMap`; old records acquire it on next save. `eventType`, `severity` and
`triggers` were added exactly this way.

**What IS dangerous:** renaming an enum value (persisted by `.name`, so a rename
silently reclassifies every historical record to the fallback), or editing a
string in `kFeelingsOptions` / `kTriggerOptions` (stored verbatim inside records
and matched by `contains`, so an edit orphans it everywhere).

### Resilience

- `EventRecord.fromMap` returns **nullable**. A record with an absent, wrongly
  typed or unparseable timestamp yields null and is skipped. It is deliberately
  not defaulted to `now()` — a silently wrong date in a medical record is worse
  than an omission.
- `EventStore.load` skips non-map entries and null-yielding records
  individually, so one bad record cannot cost the whole history.
- `jsonDecode` of the whole payload is **deliberately unguarded**. That is total
  corruption, not one bad record, and swallowing it would present an empty
  history as though the user had never logged anything.

### iOS has no rollback copy, on purpose

`writeEventPayload` skips the rollback write on iOS and clears any stale key.
Because sites 5 and 5b write the primary key natively, a rollback copy on iOS
would freeze at whenever Dart last wrote, and restoring from it would resurrect
deleted events and lose recent ones. An absent copy is safe; a silently stale
one is a data-loss mechanism. The guard carries a DO NOT REMOVE comment.

**Long-term fix:** replicate the snapshot in the Swift write paths. Required
before any migration that would want to roll back.

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
3. SentryFlutter.init(...)                     release stamped in beforeSend
4. NotificationService.init()
5. runApp()
```

**Nothing on the cold-start path may await a platform channel.** On Android a
cold start from a notification action *is* the capture path, and it sits
upstream of the `mer_open_latest_event` polling loop (8 × 250ms).

Version and Sentry release come from `lib/app_info.dart`, which reads the
platform's own packaged metadata via `package_info_plus`. There is no hardcoded
version anywhere; a previous three-way drift (pubspec, `constants.dart`, and the
Sentry release string) is why.

Sentry release format: `au.com.notiva.medicaleventrecorder@<version>+<build>`.

---

## 7. Backup and restore

- **Format:** JSON envelope with `format`, `schemaVersion` (int), `appVersion`,
  `exportedAt`, `recordCount`, `records`. Deliberately not a bare array — the
  storage payload's lack of a version marker is a mistake not repeated here.
- **Backup:** user picks the destination every time via the system picker. No
  stored path, no bookmark, no credential, no background write.
- **Restore:** merges by uuid id, so dedup is exact. **Only ever adds.** Existing
  records always win. There is no replace mode by design; `clearAll()` is a
  separate deliberate action.
- **Refusals:** not-a-backup, unreadable/truncated JSON, and a schema newer than
  this build. Validated fully before anything is written, so a restore is never
  partially applied. Unreadable records inside a valid backup are counted and
  reported, not dropped silently.
- **Reminder banner** at 10 events since last backup, suppressed entirely when
  opened from a notification action, while an event is in progress, or when an
  event was logged this session. The capture path is never gated.
- **Counter resets only on demonstrable completion.** iOS and Android report
  share success vs dismissed; desktop reports `unavailable` and so never resets
  from the share path.

---

## 8. Platform branches

38 `Platform.is*` sites in `lib/`, plus availability gates in Swift
(`iOS 16.0 / 16.2 / 17.0`) that Dart cannot see. Concentrated in:
`notification_service.dart` (init gate, iOS bailouts, Android icon resources),
`home_screen.dart` (cold start, UI gating), `help_screen.dart` (UI gating),
`event_record.dart` and `backup_service.dart` (export destinations).

---

## 9. Known-wrong and unverifiable

**Stale in this repo:** `CLAUDE.md` records version 1.0.3+4 and describes iOS
notifications as `awesome_notifications` with `ActionType.Default`. iOS has been
native Swift since CR-42 (May 2026).

**Backlog, recorded in `STATUS.md`:** `_clearIfTimedOut` discards an active event
after 30 minutes but leaves `duration` at its `lt1` default, so an abandoned
event reads as "< 1 minute" in the medical record. Needs a new
`DurationCategory` value — a capture-model change.

**Two pre-existing test failures:** `app_smoke_test` and `export_options_test`
set an obsolete `disclaimerAccepted` bool and never set
`disclaimerAcceptedVersion`. They have failed since the version gate was
introduced, well before v1.1.0.

**Everything about iOS runtime behaviour in this document is read from source,
not observed.** It cannot be verified from Windows. Lock-screen actions, Live
Activity behaviour, the iOS 16.x fallback path, App Group reconciliation, and
cold start from a notification all require a Mac and a device.
