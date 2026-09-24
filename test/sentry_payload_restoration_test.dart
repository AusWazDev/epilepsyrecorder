// Brief 175 · what MER attaches to a Sentry event, restored to the surface the
// disclosure was written against.
//
// ⛔ THE RULE. `disclaimer_screen.dart` tells the user these reports "contain
// no event data". So: categorical and boolean facts about the OPERATION may be
// sent; numeric facts derived from the USER'S RECORDS may not.
//
// ⭐ TWO REDS ARE REQUIRED OF THIS FILE, and both were demonstrated before
// either green — see the commit message. A test asserting the sanitised shape
// would pass against the old code if it only checked that the new shape is
// present; these check that the OLD content is ABSENT, which is the assertion
// the pre-change code fails.
//
// ⚠️ EVERY ASSERTION HAS A RUN-CONTROL BESIDE IT. A payload assertion that
// passes because no event was produced at all is the failure this file exists
// to avoid, so each phase proves an event exists before asserting on it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/main.dart';

/// The user text that must never appear in anything leaving the device.
const kUserNotes = 'woke at 3am with aura and a metallic taste';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  group('beforeSend value sanitisation', () {
    test('a DatabaseException carrying user text is reduced to categorical '
        'facts', () async {
      // A REAL sqflite exception, raised by a real failing statement, with the
      // user's notes as a bound argument. Not a hand-built double: the whole
      // question is what the package renders.
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1));
      Object? caught;
      try {
        await db.rawInsert(
            'INSERT INTO no_such_table (notes) VALUES (?)', [kUserNotes]);
      } catch (e) {
        caught = e;
      }
      await db.close();

      // ── RUN CONTROL ────────────────────────────────────────────────────
      expect(caught, isA<DatabaseException>(),
          reason: 'RUN CONTROL: no DatabaseException was raised, so every '
              'assertion below would be vacuous.');
      expect(caught.toString(), contains(kUserNotes),
          reason: '⛔ RUN CONTROL, AND THE PREMISE OF THE WHOLE FIX: the '
              'package\'s own rendering must embed the bound argument. If '
              'this ever stops being true the sanitiser is still correct but '
              'this test is no longer testing anything real.');

      final event = sanitiseEventValues(SentryEvent(
        throwable: caught,
        exceptions: [SentryException(type: 'x', value: caught.toString())],
      ));
      final value = event.exceptions!.single.value!;

      expect(value, isNot(contains(kUserNotes)),
          reason: '⛔ THE USER TEXT MUST BE GONE. sqflite renders bound '
              'arguments into the exception, and `notes` is free text the '
              'user typed.');
      expect(value, startsWith('DatabaseException(resultCode:'),
          reason: 'and what replaces it is categorical.');
      expect(value, contains('class: noSuchTable'),
          reason: 'the package\'s own classification survives, so the report '
              'is still diagnosable.');
    });

    test('a FormatException keeps message and offset, drops source', () {
      // The 1.0.2 path: a corrupt legacy payload decoded without a guard.
      final payload = '[{"id":"a","notes":"$kUserNotes"} NOT JSON';
      Object? caught;
      try {
        jsonDecode(payload);
      } catch (e) {
        caught = e;
      }

      // ── RUN CONTROL ────────────────────────────────────────────────────
      expect(caught, isA<FormatException>(),
          reason: 'RUN CONTROL: no FormatException was raised.');
      expect(caught.toString(), contains(kUserNotes),
          reason: '⛔ RUN CONTROL: Dart renders the source string into '
              'FormatException.toString(), which is why this path existed in '
              '1.0.2 before SQLite ever shipped.');

      final event = sanitiseEventValues(SentryEvent(
        throwable: caught,
        exceptions: [SentryException(type: 'x', value: caught.toString())],
      ));
      final value = event.exceptions!.single.value!;

      expect(value, isNot(contains(kUserNotes)),
          reason: '⛔ THE SOURCE MUST BE GONE.');
      expect(value, contains('offset:'),
          reason: 'offset is kept — it locates the fault without quoting it.');
      expect(value, contains('message:'),
          reason: 'and the parser message is kept.');
    });

    test('a FileSystemException carrying a user-chosen filename keeps only '
        'the OS error code', () {
      // ⭐ A REAL exception from the SDK, not a constructed one. Reading a
      // missing file raises PathNotFoundException — a FileSystemException
      // subclass — with the path as a field, which is the shape a file error
      // at backup_service.dart:416 arrives in.
      const chosen = 'my seizure diary 2026 FINAL.json';
      Object? caught;
      try {
        File('${Directory.systemTemp.path}/$chosen').readAsStringSync();
      } catch (e) {
        caught = e;
      }

      // ── RUN CONTROL ────────────────────────────────────────────────────
      expect(caught, isA<FileSystemException>(),
          reason: 'RUN CONTROL: no FileSystemException was raised.');
      expect(caught.toString(), contains(chosen),
          reason: '⛔ RUN CONTROL, AND THE PREMISE: the SDK renders `path` '
              'into the exception, and on this path that is a filename the '
              'user typed into a save dialog.');

      final event = sanitiseEventValues(SentryEvent(
        throwable: caught,
        exceptions: [SentryException(type: 'x', value: caught.toString())],
      ));
      final value = event.exceptions!.single.value!;

      expect(value, isNot(contains(chosen)),
          reason: '⛔ THE FILENAME MUST BE GONE.');
      expect(value, isNot(contains('seizure')),
          reason: '⛔ AND NO FRAGMENT OF IT EITHER — a filename can name the '
              'condition being recorded.');
      expect(value, contains('kind: pathNotFound'),
          reason: 'the subclass survives, tested by `is` rather than by a '
              'rendered type name, which --obfuscate would destroy.');
      expect(value, contains('osErrorCode:'),
          reason: 'and the OS classification survives as an int.');
    });

    test('a PlatformException keeps code, drops message and details', () {
      // The picker shape: plugins routinely put a path in message or details.
      const chosen = '/storage/emulated/0/Download/epilepsy log.json';
      final e = PlatformException(
        code: 'read_error',
        message: 'Failed to read $chosen',
        details: {'path': chosen},
      );

      // ── RUN CONTROL ────────────────────────────────────────────────────
      expect(e.toString(), contains(chosen),
          reason: 'RUN CONTROL: the rendering must embed the path, or this '
              'test asserts nothing.');

      final event = sanitiseEventValues(SentryEvent(
        throwable: e,
        exceptions: [SentryException(type: 'x', value: e.toString())],
      ));
      final value = event.exceptions!.single.value!;

      expect(value, isNot(contains(chosen)),
          reason: '⛔ THE PATH MUST BE GONE, from message AND details.');
      expect(value, 'PlatformException(code: read_error)',
          reason: 'only the error identifier set by the channel survives.');
    });

    test('⭐ an UNRECOGNISED type is left alone — this is a whitelist', () {
      final other = StateError('some internal invariant');
      final event = sanitiseEventValues(SentryEvent(
        throwable: other,
        exceptions: [SentryException(type: 'x', value: other.toString())],
      ));
      expect(event.exceptions!.single.value, contains('some internal invariant'),
          reason: '⛔ A rule that rewrote everything would be a scrubber, not '
              'a whitelist, and could not know what it was removing.');
    });

    test('sanitisedErrorText applies the same rule to a stringified error', () {
      expect(sanitisedErrorText(null), isNull,
          reason: 'CONTROL: null in, null out.');
      expect(sanitisedErrorText(const FormatException('bad', kUserNotes)),
          isNot(contains(kUserNotes)),
          reason: '⛔ MigrationOutcome.error is caught and STRINGIFIED into a '
              'context, so it never reaches beforeSend as a throwable. '
              'Without this it would bypass the rule entirely.');
    });
  });

  group('⛔ SOURCE — no record-derived value is attached at any capture site',
      () {
    // ⭐ THE ASSERTION THE PRE-CHANGE CODE FAILS. Each of these tokens was
    // present in a withScope context before Brief 175; their absence is the
    // change. A behavioural test cannot reach these sites without booting the
    // app, so the source is where this is checkable.
    const forbidden = <String, List<String>>{
      'lib/main.dart': [
        "'sourceEntries'",
        "'loadable'",
        "'inserted'",
        "'distinctIds'",
        "'skipped'",
        "'absent'",
      ],
      'lib/models/event_record.dart': [
        "'records': records,",
        "'records': records.length,",
      ],
      'lib/screens/home_screen.dart': [
        "'eventId'",
        "'added':",
        "'durationsRecovered':",
        "'count':   drain.deferredCount",
      ],
    };

    test('every record-derived key is gone from every capture site', () {
      final findings = <String>[];
      var scanned = 0;
      forbidden.forEach((path, tokens) {
        final src = _read(path);
        scanned++;
        // CONTROL per file: the file must actually contain a capture site, or
        // "no forbidden tokens" is true of a file we failed to read.
        expect(src, contains('Sentry.capture'),
            reason: 'CONTROL: $path has no Sentry capture — wrong file read.');
        for (final t in tokens) {
          if (src.contains(t)) findings.add('$path :: $t');
        }
      });
      expect(scanned, forbidden.length,
          reason: 'CONTROL: every listed file must have been scanned.');
      expect(findings, isEmpty,
          reason: '⛔ A RECORD-DERIVED VALUE IS STILL ATTACHED:\n'
              '${findings.join('\n')}\n'
              'Categorical and boolean facts about the operation may be sent; '
              'numeric facts derived from the user\'s records may not.');
    });

    test('⭐ the booleans that REPLACED the handoff counts are present', () {
      final src = _read('lib/screens/home_screen.dart');
      expect(src, contains("'anyAdded'"),
          reason: 'the handoff still reports WHETHER anything was folded.');
      expect(src, contains("'anyDurationsRecovered'"),
          reason: 'and whether any duration was recovered.');
    });
  });
}

/// Reads a source file for the pins above, failing loudly if it is missing —
/// a pin that silently reads nothing reports every absence as a pass.
String _read(String path) {
  final f = File(path);
  if (!f.existsSync()) throw StateError('source pin could not read $path');
  return f.readAsStringSync();
}
