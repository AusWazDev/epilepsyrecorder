// How a duration in seconds is rendered for a person. THE ONE MAPPING.
//
// Its own file, with NO imports, because the two callers cannot share one
// otherwise and neither may take on the other's dependencies:
//
//  * `notification_service.dart` deliberately does not import the record model
//    — four of the seven historical notification failures lived in the
//    background isolate, and less code there is the point.
//  * `event_record.dart` is the record model, and is where duration lives.
//
// A second copy of this formatting in each is exactly the drift a test cannot
// see, because both copies would look reasonable. It replaced `_fmtElapsed`,
// which had the same rules and lived only in the notification path — so the
// elapsed time shown when an event ENDS is now, by construction, the same
// string History shows for that event afterwards.

/// Seconds as a person reads them: `7s`, `3m`, `3m 7s`.
///
/// A raw second count reads badly — "137 seconds" is worse than "1-5 minutes",
/// which is why the buckets it replaces were not simply deleted.
///
/// Clamped at both ends. Negative elapsed is not a duration, and the upper bound
/// is 99 hours: past that the number is a clock fault, not an event.
String durationSecondsLabel(int seconds) {
  final s = seconds.clamp(0, 359999);
  final m = s ~/ 60;
  final r = s % 60;
  if (m == 0) return '${r}s';
  if (r == 0) return '${m}m';
  return '${m}m ${r}s';
}
