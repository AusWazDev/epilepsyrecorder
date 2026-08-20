const String kAppName           = 'Medical Event Recorder';
const String kCompanyName       = 'Notiva';

// The app version is NOT declared here. It is read from the platform's own
// packaged metadata at runtime via AppInfo (lib/app_info.dart), so it cannot
// drift from pubspec.yaml. This replaced a three-way drift: pubspec said
// 1.0.3+4, this file said 1.0.2, and main.dart told Sentry 1.0.2+3.

// Bump this string whenever the disclaimer or privacy policy changes.
// Any user who accepted an older version will be shown the screen again.
const String kDisclaimerVersion = '1.1';

// Storage key for the saved event list. Referenced by EventStore and by the
// notification service. NEVER change this string — it would orphan every
// record already on a user's device.
const String kEventStorageKey = 'epilepsy_event_records_v1';

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

const List<String> kTriggerOptions = [
  'Stress',
  'Poor sleep',
  'Missed medication',
  'Alcohol',
  'Flashing lights',
  'Illness',
  'Unknown',
];