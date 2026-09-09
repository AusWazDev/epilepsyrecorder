import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// ⛔ THE QUESTION THIS PROBE EXISTS TO ANSWER, and it decides the wording of
/// the per-row delete's name: IS THE ROW'S OWN CONTENT REACHABLE IN THE
/// SEMANTICS TREE ADJACENT TO THE DELETE CONTROL?
///
/// If it is, a bare "Delete" may be sufficient, because a reader moving through
/// the tree hears the record and then the control. If it is not, the string has
/// to carry the context itself.
///
/// ⚠️ §13(ad) is why this matters here specifically: seven rows in the real
/// history are byte-identical, so "which record" cannot be recovered from the
/// row content alone even when it IS announced.
///
/// ⚠️ One prefs-dependent test in this file, per `CLAUDE.md`.

List<EventRecord> rows() => List.generate(
      3,
      (i) => EventRecord(
        id: 'r$i',
        timestamp: DateTime(2026, 8, 20, 3, 1 + i),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: true,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('HISTORY row semantics, traversal order', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 932);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: rows(),
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();

    var root = tester.getSemantics(find.byType(HistoryScreen));
    while (root.parent != null) {
      root = root.parent!;
    }

    final flat = <SemanticsNode>[];
    void walk(SemanticsNode n) {
      flat.add(n);
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root);
    expect(flat.length, greaterThan(5),
        reason: 'an empty tree would mean ensureSemantics did not take effect');

    // Traversal order, resolved by id, per the method established in
    // semantics_tree_home_test.dart.
    final nameOf = <int, String>{};
    for (final n in flat) {
      final d = n.getSemanticsData();
      final l = d.label.replaceAll('\n', ' / ').trim();
      final t = d.tooltip.replaceAll('\n', ' / ').trim();
      final tap = d.hasAction(SemanticsAction.tap);
      nameOf[n.id] = '${tap ? "TAP " : "    "}'
          '${l.isNotEmpty ? '"$l"' : (t.isNotEmpty ? '"$t" [tooltip]' : "⛔ NO NAME")}';
    }

    final dump =
        root.toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder);
    var i = 0;
    // ignore: avoid_print
    print('  ── HISTORY traversal order, 3 identical-shaped records ──');
    for (final m in RegExp(r'SemanticsNode#(\d+)').allMatches(dump)) {
      i++;
      final id = int.parse(m.group(1)!);
      // ignore: avoid_print
      print('  ${i.toString().padLeft(3)}. #${id.toString().padRight(3)} ${nameOf[id]}');
    }
    // ignore: avoid_print
    print('  traversal nodes: $i   paint-order nodes: ${flat.length}');
    expect(i, flat.length, reason: 'a short list would hide nodes');

    handle.dispose();
  });
}
