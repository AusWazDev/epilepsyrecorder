const String kAppName           = 'Medical Event Recorder';
const String kCompanyName       = 'Notiva';

// The app version is NOT declared here. It is read from the platform's own
// packaged metadata at runtime via AppInfo (lib/app_info.dart), so it cannot
// drift from pubspec.yaml. This replaced a three-way drift: pubspec said
// 1.0.3+4, this file said 1.0.2, and main.dart told Sentry 1.0.2+3.

// Bump this string whenever the disclaimer or privacy policy changes.
// Any user who accepted an older version will be shown the screen again.
const String kDisclaimerVersion = '1.1';

/// Which version of the walkthrough content this is.
///
/// Bumped when the walkthrough changes enough that re-showing it could be
/// worth CONSIDERING - a new step, not a reworded sentence.
///
/// ⚠️ **NOTHING CURRENTLY READS THIS TO DECIDE THE TRIGGER, and that is
/// deliberate.** See [kWalkthroughSeenVersionKey].
const String kWalkthroughVersion = '1';

/// Which walkthrough version the user has seen, or absent if none.
///
/// ## Why a VERSION and not a bool
///
/// Mirrors `disclaimerAcceptedVersion`, which earned its version tracking the
/// hard way: it was a bool until the disclaimer text changed, and retrofitting
/// a version onto a bool means every existing user is indistinguishable from a
/// user who saw the old text. A walkthrough that gains a step later has exactly
/// the same problem. **Cheap to store now, awkward to add retrospectively.**
///
/// ## ⛔ BUT THE TRIGGER IS "NEVER SEEN", NOT "VERSION DIFFERS"
///
/// Storing the version buys the OPTION; it is not an instruction to use it.
/// Someone who has used MER for a year does not want a five-step tour because
/// step 5 gained a sentence.
///
/// So [kWalkthroughVersion] is recorded and never compared. Any future change
/// to that must be a deliberate decision with its own reasoning, not a
/// consequence of the version being available.
///
/// ⚠️ **Independent of `disclaimerAcceptedVersion` and it must stay so.**
/// The disclaimer gate IS a version comparison, so bumping `kDisclaimerVersion`
/// sends every user back through the disclaimer. Sharing that signal would
/// replay the walkthrough on every disclaimer change.
const String kWalkthroughSeenVersionKey = 'walkthroughSeenVersion';

/// ⚠️ **LEGACY. The bool this replaced, read once and upgraded in place.**
///
/// Build 37 wrote `true` here. Dropping the read would show the walkthrough a
/// second time to anyone who had already seen it - which is the one thing the
/// flag exists to prevent, reintroduced by the change that made the flag
/// better.
///
/// The affected population is exactly one device: build 37 was a local build
/// and was never released. Carried anyway, because the cost is four lines and
/// the alternative is a defect whose only defence is that it is unlikely.
const String kWalkthroughSeenLegacyBoolKey = 'mer_walkthrough_seen_v1';

// Storage key for the saved event list. Referenced by EventStore and by the
// notification service. NEVER change this string — it would orphan every
// record already on a user's device.
const String kEventStorageKey = 'epilepsy_event_records_v1';

// Rollback copy of the event list, written immediately before every save so an
// interrupted write costs one event rather than the whole history. NEVER change
// this string — it would orphan the rollback copy already on a user's device.
const String kEventRollbackKey = 'epilepsy_event_records_v1_rollback';

// Schema version of the JSON backup envelope. Increment ONLY when the envelope
// shape changes. A backup declaring a higher number than this build knows is
// refused rather than partially understood.
/// ⛔ **BUMPED 1 -> 2 WHEN MEDICATION NOTES ENTERED THE ENVELOPE.**
///
/// The bump is not bookkeeping — it is the whole safety mechanism for the
/// change. `parseBackup` already refuses `schema > kBackupSchemaVersion`, so
/// an OLDER build handed a notes-bearing backup now stops with "made by a
/// newer version of Medical Event Recorder" instead of passing the gate,
/// reading `records`, and **silently discarding every note in the file** —
/// which is the same data loss this change exists to fix, moved one layer
/// along.
///
/// A NEW build reading a version 1 backup is unaffected: 1 > 2 is false, and
/// the absent `medicationNotes` key reads as an empty list rather than an
/// error. Every backup ever taken lacks that key, so treating its absence as a
/// fault would break restore for all of them.
/// ⛔ **BUMPED 2 -> 3 WHEN CONDITIONS AND THE TYPE MAPPING ENTERED THE
/// ENVELOPE.** Same reasoning as the 1 -> 2 bump, and the same mechanism: an
/// OLDER build handed a schema 3 backup now REFUSES on the existing gate,
/// instead of restoring the records and silently dropping the attribution — a
/// user would then have 72 records reading `unknown` with no way to know they
/// had lost a mapping they never see written down.
/// ⛔ **BUMPED 3 -> 4 WHEN `occurredAt` ENTERED THE RECORD.**
///
/// ⚠️ **The envelope's top-level keys did NOT change this time** — records
/// serialise through `EventRecord.toMap`, which is the single authority, so the
/// new field arrived in the file with no change to `buildBackupJson` at all.
/// The bump is made on the RULE rather than on the literal wording above: the
/// stated purpose of every previous bump is that **an older build must refuse a
/// file it would otherwise partially understand.**
///
/// Without it, a build predating this field restores a backdated record and
/// **silently drops when it happened**, keeping only when it was typed — the
/// exact shape of the medication-note and condition losses that forced the
/// first two bumps. That the loss is now inside `records` rather than beside it
/// makes it harder to notice, not less real.
const int kBackupSchemaVersion = 4;

/// Whether the STANDING quick-log notification is posted.
///
/// ## ⛔ DEFAULT TRUE, AND IT MUST STAY THAT WAY
///
/// Absent reads as true, so every existing install keeps the notification it
/// already has. For epilepsy the standing notification is the app's strongest
/// feature — the whole point is that a record can be made without unlocking
/// the phone — and a silent opt-out on upgrade would remove it from the users
/// it was built for.
///
/// ## WHY IT EXISTS
///
/// A user recording a condition AFTER THE FACT — a migraine, an IBS flare —
/// never taps it, and it is posted whenever permission is granted rather than
/// only while an event runs. It was therefore a permanent entry in the shade
/// for a feature that user will never use, **re-posted every time the app
/// opened**, with no in-app way to stop it. Revoking the OS notification
/// permission was the only answer, and that is not an answer: it also disables
/// the end-of-event controls, and the Help screen then reports the app as
/// misconfigured.
///
/// ⚠️ **This does NOT govern the ACTIVE-EVENT notification.** If an event is
/// running the user needs its End control, whatever they think of the standing
/// one. See `_showNormal` — the switch is enforced there and nowhere else, so
/// the active path cannot accidentally inherit it.
const String kStandingNotificationKey = 'mer_standing_notification';

// Magic string identifying a file as a Medical Event Recorder backup. Used to
// reject another app's JSON before anything is read from it.
const String kBackupFormatId = 'medical-event-recorder-backup';

// Timestamp of the last backup the user took, used only to count events logged
// since, for the reminder banner. NEVER change this string.
const String kLastBackupKey = 'mer_last_backup_at';

// Set when a write of the event list failed, cleared when one succeeds.
//
// Persisted rather than held in memory because the failure it records outlives
// the session: the events are in the list the user can see but not in storage,
// so if the app is killed before a later write succeeds they are gone. The
// warning must still be there when the app comes back. NEVER change this
// string — it would silently drop a pending warning on upgrade.
const String kUnsavedEventsKey = 'mer_unsaved_events';

// Events logged since the last backup before the reminder banner appears.
// Low enough that a loss would still hurt, high enough not to nag someone who
// logs rarely. The banner is suppressed entirely around the capture path.
const int kBackupReminderThreshold = 10;

const String kWebsiteUrl   = 'https://www.notiva.com.au';
const String kPrivacyUrl   = 'https://www.notiva.com.au/medical-event-recorder/privacy/';
const String kTermsUrl     = 'https://www.notiva.com.au/medical-event-recorder/terms/';
const String kContactUrl   = 'https://www.notiva.com.au/contact/';
const String kSupportEmail = 'contact@notiva.com.au';

const List<String> kFeelingsOptions = [
  '😴 Tired and weary',
  '😪 Just tired',
  '😩 Just weary',
  '🤕 Experiencing a headache',
  '😢 Sad',
  '😵 Confused',
  '😠 Annoyed',
  '😡 Angry',
  '😰 Anxious',
  '🤢 Nauseous',
  '😣 In pain',
];

/// ⚠️ **NO LONGER THE PICKER'S SOURCE. It is the CSV's CANONICAL ORDER, and
/// nothing else.**
///
/// The beforehand field became a vocabulary table in schema v9, so the chips on
/// both screens now come from `Vocabularies.offerableTriggers`. This list
/// survives for one job: `csvOrderedTriggers` sorts the seeded seven into a
/// stable order so the column is comparable down the page, with anything
/// user-defined appended.
///
/// ⛔ **It MUST stay in step with `kSeedTriggers`** — same strings, same order.
/// Two lists holding the same values is a drift risk, and it is deliberate
/// rather than an oversight: making the CSV order depend on the live
/// vocabulary would let a user's additions REORDER the historical column.
/// `trigger_vocabulary_test` pins the two together so the duplication cannot
/// rot silently.
const List<String> kTriggerOptions = [
  'Stress',
  'Poor sleep',
  'Missed medication',
  'Alcohol',
  'Flashing lights',
  'Illness',
  'Unknown',
  // Appended 29 Aug 2026 with the same three in `kSeedTriggers`, which
  // `trigger_vocabulary_test` #9 pins together. APPENDED, so the six above keep
  // the canonical positions every existing export already used — no historical
  // column reorders. See the seed list for sourcing, including the one entry
  // marked INFERRED.
  'Period or hormonal',
  'Certain foods',
  'Dehydration',
  // The migraine symptom entries. Appended in the SAME ORDER as kSeedTriggers,
  // which trigger_vocabulary_test #9 pins — the duplication is deliberate so a
  // user's own additions cannot reorder the historical CSV column, and
  // appending leaves every existing canonical position untouched.
  'Yawning',
  'Food cravings',
  'Numbness or tingling',
  'Visual disturbance',
  'Sensitive to light',
  'Sensitive to sound',
  'Neck stiffness',
  'Difficulty concentrating',
  'Tired',
  'Nauseous',
  'Irritable',
];