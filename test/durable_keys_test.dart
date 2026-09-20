import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BRIEF 63 B-3 — the durable keys are PINNED, not merely named.
///
/// ⛔ **THE HAZARD THIS EXISTS FOR.** The CSV export header carried the string
/// `referral_required`, **byte-identical to the SQLite column name.** They were
/// separate literals in separate files, so renaming the header was possible —
/// but a repository-wide find-and-replace on that string would have renamed the
/// database column and **orphaned every existing user's data.**
///
/// ⚠️ **BRIEF 63 NAMED THE SQLITE COLUMN AS IMMUTABLE AND THEN ASKED A QUESTION
/// INCAPABLE OF DETECTING IT BEING CHANGED.** It asked whether a shared
/// *constant* fed both the backup key and the CSV header — it did not ask
/// whether the header's *string* collided with a durable key's string.
/// ⭐ **Naming a thing that must not change is not the same as aiming a check
/// at it.** This file is that check.
///
/// 🔴 **WHY A TEST AND NOT A NOTE.** The rename was done safely because one
/// reader happened to notice the collision. A note records that; it does not
/// reproduce it. **This goes red the next time anyone reaches for a global
/// replace, including when nobody is watching.**
///
/// ## What is durable, and why each one is
///
///   SQLite column   written once and read back on every open, for the life of
///                   the install. Renaming it loses the column's data.
///   backup JSON key written to a file that outlives the build that wrote it,
///                   and read back by restore on a DIFFERENT device.
///   legacy prefs    the pre-SQLite array, still drained on first launch after
///                   upgrade. Renaming orphans anyone who has not yet upgraded.
///
/// ⚠️ **THE CSV HEADER IS NOT DURABLE AND IS DELIBERATELY ABSENT FROM THIS
/// FILE.** Nothing reads a CSV back — verified in Brief 63 Part A with a
/// control. It is pinned separately, by `sweep_contracts_test`, as a SHAPE
/// claim tied to the marker. **Adding it here would assert a permanence it
/// does not have and would block the next legitimate rename.**

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('SQLite — the column name is part of the on-disk contract', () {
    final ddl = _read('lib/models/event_store_sqlite.dart');

    test('1. the referral column is `referral_required` in the DDL', () {
      expect(ddl, contains("'referral_required INTEGER"),
          reason: 'THE DURABLE KEY. This column has held user data since the '
              'SQLite store shipped. Renaming it does not migrate the data — '
              'it creates a new empty column and abandons the old one.\n\n'
              'If you are here because a CSV header rename broke this, that is '
              'this test doing its job: the export header was once the SAME '
              'STRING, and a global replace is how the two get renamed '
              'together. Rename the header only, at its own site.');
    });

    test('2. and it is read and written under that same name', () {
      expect(ddl, contains("'referral_required':"),
          reason: 'the write side. A DDL that still says referral_required '
              'while the write says something else fails at runtime, not here');
      expect(ddl, contains("row['referral_required']"),
          reason: 'the read side, which is where a mismatch surfaces as silent '
              'nulls rather than as an error');
    });
  });

  group('backup JSON — the key outlives the build that wrote it', () {
    final rec = _read('lib/models/event_record.dart');

    test('3. the backup key is `referralRequired`, camelCase, unchanged', () {
      expect(rec, contains("'referralRequired': referralRequired"),
          reason: 'toMap. A backup file is read on a DIFFERENT DEVICE and a '
              'LATER build; renaming this key silently drops the field on '
              'every restore of every existing file');
      expect(rec, contains("map['referralRequired']"),
          reason: 'fromMap — the read side of the same key');
    });

    test('4. ⛔ the backup key and the CSV header are DIFFERENT STRINGS', () {
      // ⭐ THE STRUCTURAL FACT THE RENAME DEPENDED ON, pinned so it stays true.
      // If a future refactor ever routes both through one constant, the CSV
      // header stops being renameable without touching the backup format —
      // and that is exactly the case Brief 63's escape clause was written for.
      expect(rec, contains("'referralRequired'"),
          reason: 'CONTROL: the backup key is present, so the comparison below '
              'is between two live strings and not against an absent one');
      expect(rec, contains("'further_attention'"),
          reason: 'CONTROL: the CSV header is present under its new name');
      expect("'referralRequired'" == "'further_attention'", isFalse,
          reason: 'they must never be the same string, and no single constant '
              'may feed both');
    });
  });

  group('the legacy shared_preferences drain', () {
    final mig = _read('lib/models/storage_migration.dart');

    test('5. reads `referralRequired` and writes `referral_required`', () {
      expect(mig, contains("map['referralRequired']"),
          reason: 'the legacy array is JSON and uses the camelCase key');
      expect(mig, contains("'referral_required':"),
          reason: 'and it lands in the SQLite column under the snake_case '
              'name. BOTH spellings are durable here, for different stores');
    });
  });

  group('the collision itself', () {
    test('6. ⛔ the CSV header no longer collides with any durable key', () {
      final rec = _read('lib/models/event_record.dart');
      final sql = _read('lib/models/event_store_sqlite.dart');

      // The header cell, as it now stands.
      expect(rec, contains("'further_attention',"));

      // ⭐ THE ASSERTION THAT WOULD HAVE PREVENTED THE HAZARD: the CSV header
      // string must not be a substring of the SQLite schema. Before Brief 63
      // it was, and nothing said so.
      expect(sql.contains('further_attention'), isFalse,
          reason: 'the export header must not share a string with the durable '
              'schema. While it did, any global replace on that string hit '
              'both — which is the near-miss this file was built from');

      expect(sql.contains('referral_required'), isTrue,
          reason: 'CONTROL: the schema DOES still contain the RETIRED string, '
              'so the assertion above is a real separation and not an artefact '
              'of the schema having been emptied');
    });
  });
}
