import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/about_screen.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// AUDIT.md §13(bw) and §13(bx) — the three named-cause layout fixes of
/// 11 September 2026, each asserted at the size where its finding measured it.
///
/// ⚠️ EVERY PIXEL FIGURE HERE CARRIES THE §13(ay) FONT CAVEAT: the harness font
/// is monospaced at one em per glyph, so an overflow AMOUNT is not a device
/// number. The STRUCTURAL facts do not depend on the font — a `Row` that
/// overflows at all, a URL laid out at zero width, a paragraph that exceeded
/// its `maxLines` — and those are what is asserted.
///
/// ⛔ CONTROLS. Each assertion was run against the UNPATCHED widgets first
/// (recorded in the comments beside it, 11 Sep 2026) and failed there for the
/// reason the finding gives. A check that cannot fail is not a check.
///
/// The two screens under test read no `SharedPreferences`, so this file has
/// no prefs state and the one-prefs-test-per-process rule does not bite.

/// Six rows, four badged, two not — §13(bx)'s "four rows out of six".
/// The badged rows are COMPLETE so the gap line is not in play here.
List<EventRecord> badgedRows() => List.generate(
      6,
      (i) => EventRecord(
        id: 'b$i',
        timestamp: DateTime(2026, 8, 20, 9, 1 + i),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: i < 4 ? (i.isEven ? kTypeSeizure : kTypeAbsence) : null,
        severity: i < 4 ? EventSeverity.mild : null,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: i < 4,
      ),
    );

/// One record missing all three detail fields, so the gap line reads
/// "Add details: duration, type, severity" — the string §13(bw) measured.
List<EventRecord> gapRow() => <EventRecord>[
      EventRecord(
        id: 'g',
        timestamp: DateTime(2026, 8, 20, 9, 0),
        duration: null,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: false,
      ),
    ];

/// Every overflowing RenderFlex in the tree, as its overflow amount along its
/// main axis. Read STRUCTURALLY from the render tree — `RenderFlex` marks
/// itself `OVERFLOWING` in `toStringShort()` — rather than from the error
/// report, which is emitted once per RenderFlex at first paint and is easy to
/// miss. The amount is the children's extent less the flex's own extent.
/// Any reported exceptions are drained too, so they cannot fail the test on
/// their own; the assertion is on this list.
List<double> overflows(WidgetTester tester) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  final out = <double>[];
  void visit(RenderObject o) {
    if (o is RenderFlex && o.toStringShort().contains('OVERFLOWING')) {
      var extent = 0.0;
      o.visitChildren((c) {
        final s = (c as RenderBox).size;
        extent += o.direction == Axis.horizontal ? s.width : s.height;
      });
      final own =
          o.direction == Axis.horizontal ? o.size.width : o.size.height;
      out.add(double.parse((extent - own).toStringAsFixed(1)));
      // Name the widget so a failure says WHICH row, not just how much.
      // ignore: avoid_print
      print('    overflowing: ${o.debugCreator}');
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  return out;
}

void sizeAndScale(WidgetTester tester, Size logical, double scale) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> pumpHistory(WidgetTester tester, List<EventRecord> records) async {
  await tester.pumpWidget(MaterialApp(
    theme: MERTheme.light,
    home: HistoryScreen(
      records: records,
      onRecordsChanged: (_) async {},
      onEdit: (_, {required confirmOnSave}) async {},
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(375, 667);

  group('§13(bx) — the History title row with a type badge', () {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('no RenderFlex overflow at $scale (375 wide)', (tester) async {
        sizeAndScale(tester, phone, scale);
        await pumpHistory(tester, badgedRows());
        final o = overflows(tester);
        // ⛔ CONTROL, UNPATCHED 11 Sep 2026: at 2.0 this list read
        // [66.5, 111.5, 66.5] — 66.5 on each Seizure row, §13(bx)'s figure,
        // and 111.5 on the longer Absence label; at 1.0 it was empty. The
        // finding's exact shape.
        // ignore: avoid_print
        print('  history badge row @${scale}x: overflows=$o');
        expect(o, isEmpty,
            reason: 'the badge must shrink instead of pushing past the row');
        // The badge is still rendered, not dropped, at both scales.
        expect(find.text(eventTypeLabel(kTypeSeizure)), findsWidgets);
      });
    }
  });

  group('§13(bw) — History\'s "Add details" gap line', () {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('not clipped at $scale (375 wide)', (tester) async {
        sizeAndScale(tester, phone, scale);
        await pumpHistory(tester, gapRow());
        final gap = find.textContaining('Add details:');
        expect(gap, findsOneWidget);
        final p = tester.renderObject<RenderParagraph>(gap);
        // ⛔ CONTROL, UNPATCHED 11 Sep 2026: `didExceedMaxLines` was TRUE at
        // 1.0 — `maxLines: 1` on a string that does not fit 243 px.
        // ignore: avoid_print
        print('  gap line @${scale}x: textSize=${p.textSize} '
            'exceeded=${p.didExceedMaxLines}');
        expect(p.didExceedMaxLines, isFalse,
            reason: 'the gap line names the fields to add; cutting it off '
                'hides which');
        expect(overflows(tester), isEmpty);
      });
    }
  });

  group('§13(bw) — About\'s _InfoRow and _LinkRow', () {
    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('no overflow and URLs have width at $scale (375 wide)',
          (tester) async {
        sizeAndScale(tester, phone, scale);
        await tester.pumpWidget(MaterialApp(theme: MERTheme.light, home: const AboutScreen()));
        await tester.pumpAndSettle();
        final o = overflows(tester);
        // ⛔ CONTROL, UNPATCHED 11 Sep 2026: at 1.0 [109.0, 69.3] from
        // `_InfoRow`'s non-flexible value — §13(bw)'s 109 and 69; at 2.0
        // seven overflows, the largest 525.0.
        // ignore: avoid_print
        print('  about @${scale}x: overflows=$o');
        expect(o, isEmpty, reason: 'label-and-value rows must wrap, not spill');

        // The three https links render as host-relative text; each must be
        // laid out at a non-zero width. ⛔ CONTROL, UNPATCHED: 0.0 at 2.0.
        for (final url in <String>[kWebsiteUrl, kPrivacyUrl, kTermsUrl]) {
          final shown =
              url.replaceFirst('https://', '').replaceFirst('www.', '');
          final f = find.text(shown);
          expect(f, findsOneWidget, reason: 'link text "$shown" present');
          final w = tester.getSize(f).width;
          // ignore: avoid_print
          print('  about @${scale}x: "$shown" width=${w.toStringAsFixed(1)}');
          expect(w, greaterThan(0),
              reason: 'a link with no width cannot be read or tapped');
        }
      });
    }
  });
}
