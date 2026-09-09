import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// AUDIT.md §13(z) — the semantics tree of HOME, in traversal order.
///
/// ⛔ MEASUREMENT ONLY. This reports what the tree contains and in what order.
/// It does NOT judge the order, and it is NOT a screen-reader test: TalkBack,
/// VoiceOver and Narrator each apply their own grouping and gesture model on
/// top of this tree, and none has been run.
///
/// ⭐ `ensureSemantics()` is required — without it Flutter builds no semantics
/// tree at all in a test, and a sweep would report an empty tree as a finding.
/// That is the shape §13(az) is about, so the handle is taken first and the node
/// count is asserted non-zero before anything is read.
///
/// ⚠️ One prefs-dependent test in this file, per `CLAUDE.md`.

String seededRecordsJson() {
  final records = List.generate(
    12,
    (i) => EventRecord(
      id: 'seed-$i',
      timestamp: DateTime(2026, 8, 20, 3, i + 1),
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
  return jsonEncode(records.map((r) => r.toMap()).toList());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey: seededRecordsJson(),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('HOME semantics tree, traversal order', (tester) async {
    // handle.dispose() is called at the END OF THE BODY, not via addTearDown:
    // the framework's "a SemanticsHandle was active at the end of the test"
    // check runs BEFORE tear-downs, so addTearDown fails it.
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 932);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // ⚠️ NOT `tester.binding.pipelineOwner.semanticsOwner`, which is deprecated.
    // Walk up from a node that definitely exists to the root instead.
    var root = tester.getSemantics(find.byType(HomeScreen));
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

    // ⭐ CONTROL: an empty tree must fail loudly rather than read as "nothing
    // is exposed". `ensureSemantics` not being called is the usual cause.
    expect(flat.length, greaterThan(5),
        reason: 'the semantics tree is empty or trivial — ensureSemantics() '
            'almost certainly did not take effect, and any reading of the tree '
            'below would be an artefact');

    var announced = 0;
    var tappable = 0;
    var order = 0;
    // ignore: avoid_print
    print('  semantics nodes: ${flat.length}');
    // ignore: avoid_print
    print('  ── HOME, traversal order ──');
    for (final n in flat) {
      final d = n.getSemanticsData();
      final label = d.label.replaceAll('\n', ' / ').trim();
      // ⛔ TOOLTIP IS A SEPARATE FIELD FROM LABEL. A tooltip'd IconButton has an
      // EMPTY label and is still announced — checking `label` alone reported
      // the banner's Dismiss button and the overflow menu as unlabelled when
      // both carry a name. Same class as §13(az): the probe encoded an
      // assumption about where the answer lives.
      final tip = d.tooltip.replaceAll('\n', ' / ').trim();
      final tap = d.hasAction(SemanticsAction.tap);
      final hasName = label.isNotEmpty || tip.isNotEmpty;
      if (hasName) announced++;
      if (tap) tappable++;
      if (!hasName && !tap) continue; // structural nodes carry nothing to read
      order++;
      final flags = <String>[
        if (tap) 'TAP',
        if (d.flagsCollection.isButton) 'button',
        if (d.flagsCollection.isHeader) 'header',
        // ⚠️ `isSelected` is a Tristate and `isChecked` a CheckedState in this
        // Flutter version, not bools. Rendered as their enum name so a
        // "not-set" state is visible as itself rather than collapsed to false.
        if (d.flagsCollection.isSelected.toString() != 'Tristate.none')
          'selected=${d.flagsCollection.isSelected.name}',
        if (d.flagsCollection.isChecked.toString() != 'CheckedState.none')
          'checked=${d.flagsCollection.isChecked.name}',
        if (d.flagsCollection.isTextField) 'textfield',
        if (d.flagsCollection.isImage) 'image',
      ];
      // ignore: avoid_print
      print('  ${order.toString().padLeft(3)}. '
          '${flags.isEmpty ? "-" : flags.join(",")}'.padRight(28) +
          (hasName
              ? '"${label.isNotEmpty ? label : tip}"'
                  '${label.isEmpty ? "   [from TOOLTIP, not label]" : ""}'
              : '⛔ NO NAME AT ALL'));
    }
    // ignore: avoid_print
    print('  ── totals: ${flat.length} nodes, $announced with a label, '
        '$tappable with a tap action ──');

    // Tappable nodes carrying NO label are the ones a reader cannot name.
    final silentTaps = flat.where((n) {
      final d = n.getSemanticsData();
      return d.hasAction(SemanticsAction.tap) &&
          d.label.trim().isEmpty &&
          d.tooltip.trim().isEmpty;
    }).length;
    // ignore: avoid_print
    print('  ⛔ tappable nodes with NO name at all on this screen: $silentTaps');

    // ⚠️ THE WALK ABOVE IS PAINT ORDER. `visitChildren` returns children in
    // paint order, which is NOT the order a screen reader walks — that is
    // computed separately and is reachable only through the debug dump. It is
    // printed as its own thing rather than the walk being presented as if it
    // were traversal order.
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('  ── TRAVERSAL ORDER, what a reader actually walks ──');
    final dump =
        root.toStringDeep(childOrder: DebugSemanticsDumpOrder.traversalOrder);
    // ⛔ ENUMERATE NODES, NOT REGEX HITS. A first version matched
    // `label: "..."` / `tooltip: "..."` per line and produced 19 entries
    // against the paint walk's 22 — a silently short list, which the workspace
    // rule forbids: a list of names must be validated against a count from the
    // same source. Multi-line labels ("Record Event\nTap to timestamp now")
    // were what it dropped.
    // Node id -> its name, from the walk (labels can span lines in the dump,
    // so they are resolved by ID rather than scraped out of the text).
    final nameOf = <int, String>{};
    for (final n in flat) {
      final d = n.getSemanticsData();
      final l = d.label.replaceAll('\n', ' / ').trim();
      final t = d.tooltip.replaceAll('\n', ' / ').trim();
      nameOf[n.id] = l.isNotEmpty
          ? l
          : (t.isNotEmpty ? '$t   [tooltip]' : '⛔ no name');
    }

    var i = 0;
    for (final m in RegExp(r'SemanticsNode#(\d+)').allMatches(dump)) {
      i++;
      final id = int.parse(m.group(1)!);
      // ignore: avoid_print
      print('  ${i.toString().padLeft(3)}. #${id.toString().padRight(3)} '
          '${nameOf[id] ?? "(not in walk)"}');
    }
    // ignore: avoid_print
    print('  traversal nodes enumerated: $i   paint-order nodes: ${flat.length}'
        '   (must match, or the list above is short)');
    expect(i, flat.length,
        reason: 'the traversal dump lists fewer nodes than the tree contains, '
            'so the order above is incomplete');

    handle.dispose();
  });
}
