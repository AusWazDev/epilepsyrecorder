// Shared fixture for the whenHappened cluster tests. NOT a test file.
//
// ⛔ EVERY RECORD HERE HAS `occurredAt` SET AND FAR FROM `timestamp`. That is
// the whole point. A behavioural test is BLIND on a record where `occurredAt`
// is null — `occurredAt ?? timestamp` and `timestamp` return the same value —
// and null is what most real records carry. A suite that seeds null-occurredAt
// records passes identically against the defect and against the fix, which is
// the trap this cluster sat in for nine days.
//
// ⚠️ THE GAP IS DAYS, NOT MINUTES, deliberately. A marginal difference can be
// swallowed by a formatter, a rounding, or a timezone; nine days cannot.

import 'dart:convert';

import 'package:medical_event_recorder/models/event_record.dart';

EventRecord rec({
  required String id,
  required DateTime timestamp,
  DateTime? occurredAt,
}) =>
    EventRecord(
      id: id,
      timestamp: timestamp,
      occurredAt: occurredAt,
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// ⭐ THE INVERTED PAIR — the fixture the whole cluster turns on.
///
/// `late-logged` was TYPED LAST but HAPPENED FIRST. So:
///   · sorted by `timestamp`  -> late-logged is first  (WRONG)
///   · sorted by `whenHappened` -> early-logged is first (RIGHT)
///
/// Any surface that disagrees about which of these is "last" is reading the
/// wrong clock, and it cannot be right by accident on this data.
final kEarlyLogged = rec(
  id: 'early-logged-late-occurring',
  timestamp: DateTime(2026, 9, 1, 9, 0),
  occurredAt: DateTime(2026, 9, 20, 14, 30), // happened LATE
);

final kLateLogged = rec(
  id: 'late-logged-early-occurring',
  timestamp: DateTime(2026, 9, 10, 9, 0), // typed LATER
  occurredAt: DateTime(2026, 9, 2, 8, 15), // but happened EARLY
);

/// The record whose displayed time is asserted. Logged 20 Sep, happened 11 Sep.
///
/// ⚠️ THE TIME OF DAY IS IDENTICAL ON BOTH, AND THAT IS NOT TIDINESS. With
/// 06:45 against 22:17 the two clocks are 9 days 15½ hours apart, so
/// `Duration.inDays` truncates to 10 from one reference point and 9 from
/// another. The fixture's own control caught it on the first run. Aligning the
/// minute makes the gap EXACTLY nine days, so the days-since assertion cannot
/// drift with the wall clock. The DATES still differ, so the rendered strings
/// remain discriminating.
final kBackdated = rec(
  id: 'backdated',
  timestamp: DateTime(2026, 9, 20, 22, 17),
  occurredAt: DateTime(2026, 9, 11, 22, 17),
);

String jsonFor(List<EventRecord> records) =>
    jsonEncode(records.map((r) => r.toMap()).toList());
