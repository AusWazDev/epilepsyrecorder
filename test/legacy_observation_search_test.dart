import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// **The revision must not silently break search for existing data.**
///
/// The one requirement of the observation revision that had no test. Hidden
/// legacy keeps the old strings inside records — a record can hold
/// `😴 Tired and weary` while the picker only offers `Tired` — and a person
/// searching "tired" typed a WORD, not a data format. They must find it.
///
/// ## Why this needs a widget test rather than a unit test
///
/// The haystack is built inside `HistoryScreen`'s filter and is not reachable
/// from outside it. Asserting on a re-implementation would make the second
/// implementation's bug the finding, so this drives the real screen: type into
/// the real search field, count the real rows.
///
/// ## The two halves, which fail independently
///
///   * the record's STORED VALUE contains the word — `😴 Tired and weary`
///     matches "tired" by substring even with no vocabulary at all;
///   * the record's resolved LABEL contains it — which is what catches a value
///     whose stored form does NOT contain the search word.
///
/// The second is the one that would break silently, so test 3 uses a value that
/// only the label can match.

/// The legacy string, written as escapes so this file cannot itself be the
/// thing that mangles the emoji it is asserting about.
const String kLegacyTiredAndWeary = '\u{1F634} Tired and weary';
const String kLegacyConfused = '\u{1F635} Confused';

EventRecord withFeelings(String id, DateTime ts, List<String> feelings) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: null,
      feelings: feelings,
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
    );

void main() {
  final t0 = DateTime(2026, 8, 20, 9, 0);

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> pump(WidgetTester tester, List<EventRecord> records) async {
    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: records,
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String q) async {
    await tester.enterText(find.byType(TextField).first, q);
    await tester.pumpAndSettle();
  }

  testWidgets('1. searching "tired" finds a record holding the LEGACY string',
      (tester) async {
    await pump(tester, <EventRecord>[
      withFeelings('legacy', t0, <String>[kLegacyTiredAndWeary]),
      withFeelings('modern', t0.add(const Duration(hours: 1)), <String>['Tired']),
    ]);

    await search(tester, 'tired');

    expect(find.textContaining('2 of 2'), findsOneWidget,
        reason: 'both the legacy record and the revised one must match — the '
            'revision changed what is OFFERED, not what is FINDABLE');
  });

  testWidgets('2. NEGATIVE CONTROL: a word in NEITHER record finds nothing',
      (tester) async {
    // Without this, test 1 passes just as well against a filter that has
    // stopped filtering.
    await pump(tester, <EventRecord>[
      withFeelings('legacy', t0, <String>[kLegacyTiredAndWeary]),
    ]);

    await search(tester, 'nauseous');

    // findsWidgets, not findsOneWidget: the phrase appears twice — the count
    // line and the empty-state body. Two is the correct answer here.
    expect(find.textContaining('No events match'), findsWidgets);
  });

  testWidgets(
      '3. THE HALF THAT WOULD BREAK SILENTLY: a value whose STORED form does '
      'not contain the search word', (tester) async {
    // `😵 Confused` contains "confused", so it would match on the raw value
    // alone — that half cannot fail. This one cannot match on the value: the
    // stored string is the MIS-DECODED form, whose bytes are not the word.
    // Only resolving it through the vocabulary to its label finds it.
    const mangled = 'ðµ Confused';
    expect(mangled.contains('Confused'), isTrue,
        reason: 'precondition: the tail is intact, the glyph is not');

    // A value that shares NO searchable word with its label at all.
    Vocabularies.debugSet(observations: <VocabularyEntry>[
      const VocabularyEntry(
        id: 1,
        value: 'obs_7',
        label: 'Nauseous',
        isSeeded: true,
        isActive: false,
        isProtected: false,
        sortOrder: 1,
      ),
    ]);

    await pump(tester, <EventRecord>[
      withFeelings('opaque', t0, <String>['obs_7']),
    ]);

    await search(tester, 'nauseous');

    expect(find.textContaining('1 of 1'), findsOneWidget,
        reason: 'the stored value "obs_7" contains nothing searchable, so this '
            'match can only come from the resolved LABEL — the half that would '
            'have broken with no visible symptom');
  });

  testWidgets('4. and the legacy record RENDERS its label, not its raw value',
      (tester) async {
    // Search finding it is half the requirement; reading correctly is the
    // other. The row resolves through the vocabulary, so the emoji never
    // reaches a text style that cannot draw it.
    await pump(tester, <EventRecord>[
      withFeelings('legacy', t0, <String>[kLegacyConfused]),
    ]);

    expect(find.textContaining('Confused'), findsWidgets);
    expect(find.textContaining(kLegacyConfused), findsNothing,
        reason: 'the raw emoji-bearing value must not reach the row — it '
            'rendered as mojibake on the tablet');
  });
}
