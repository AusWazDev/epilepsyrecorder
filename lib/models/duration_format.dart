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

/// Seconds as a person reads them: `7s`, `3m`, `3m 7s`, `2h`, `2h 30m`.
///
/// A raw second count reads badly — "137 seconds" is worse than "1-5 minutes",
/// which is why the buckets it replaces were not simply deleted.
///
/// Clamped at both ends. Negative elapsed is not a duration, and the upper bound
/// is 99 hours: past that the number is a clock fault, not an event.
///
/// ## ⛔ THE HOURS UNIT, ADDED 29 AUG 2026 — AND WHY IT WAS THE REAL DEFECT
///
/// **This function had no hours branch, so every duration over an hour rendered
/// in minutes.** A four-hour migraine read `240m`; a seventy-two hour one read
/// `4320m`; the clamp itself read `5999m 59s`.
///
/// The Change Register recorded this as a CLAMP problem biting at 4.17 days.
/// **It was a UNITS problem biting at ONE HOUR** — and biting on the shipped,
/// supported set rather than on a hypothetical one, because a long seizure and
/// any typed duration both come through here. The register also stated the
/// five-day case "renders as 99h 59m", which was **false when written**: nothing
/// in this file could produce an `h`.
///
/// ⚠️ **The docstring above already said "the upper bound is 99 hours" and had
/// said so since the seconds migration.** The prose was right and the code did
/// not implement it, which is why nothing contradicted the register's claim:
/// a reader checking the documented bound would have agreed with it. The two
/// now match.
///
/// **Seconds are dropped at hour scale, deliberately.** `2h 30m 17s` is noise on
/// a quantity nobody measures to the second at that length, and the exact value
/// is never lost — the CSV's `duration_seconds` column carries the unclamped
/// integer, which is what any calculation reads.
///
/// ⚠️ **The clamp is deliberately UNCHANGED.** Past 99 hours a TIMER-derived
/// value is a clock fault, not an event, and that reasoning is sound for the
/// path that produces it. A typed multi-day duration is a different question
/// and is not answered by widening this bound — the number is stored and
/// exported in full either way.
String durationSecondsLabel(int seconds) {
  final s = seconds.clamp(0, 359999);
  if (s < 60) return '${s}s';
  if (s < 3600) {
    final m = s ~/ 60;
    final r = s % 60;
    return r == 0 ? '${m}m' : '${m}m ${r}s';
  }
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
