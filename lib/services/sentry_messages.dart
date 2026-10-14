/// The app's own fixed-text Sentry messages, and the allowlist built from them.
///
/// ⛔ **THE ALLOWLIST IS THE CALL SITES (Brief MER-F5, 14 October 2026).** The
/// sanitiser in `main.dart` is default-deny: a message's text leaves the device
/// only if it is EXACTLY one of these. Every `Sentry.captureMessage` in `lib/`
/// passes one of these constants, never a literal, so adding a message means
/// adding it here, and an interpolated message cannot match by construction.
library;

const String kMsgStorageFallback =
    'Storage migration did not complete; running on shared_preferences';
const String kMsgStorageMigrated = 'Storage migrated to SQLite';
const String kMsgPersistStrand = 'Persist strand: save has not completed';
const String kMsgPersistWithheld =
    'Persist withheld: the record list is not known to be complete';
const String kMsgHandoffFolded = 'iOS handoff: legacy shared records folded in';
const String kMsgInboxOrphanEnd =
    'Capture inbox: end instruction with no matching record';
const String kMsgInboxDeferred =
    'Capture inbox: entries left in place, not applied';

/// The only message texts the sanitiser lets through.
const Set<String> kSentryFixedMessages = {
  kMsgStorageFallback,
  kMsgStorageMigrated,
  kMsgPersistStrand,
  kMsgPersistWithheld,
  kMsgHandoffFolded,
  kMsgInboxOrphanEnd,
  kMsgInboxDeferred,
};

/// What replaces any text the sanitiser withholds.
const String kSentryWithheld = '[withheld]';
