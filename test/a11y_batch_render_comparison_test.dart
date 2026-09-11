import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/about_screen.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// NOTHING ELSE MOVED — the render comparison for the 11 September 2026
/// accessibility batch (AUDIT.md §13(s), §13(bw), §13(bx)).
///
/// Every paragraph on home, History, About and the form is fingerprinted at
/// 375, 430 and 800 logical: its text, its glyphs' top-left position and
/// their extent. ⛔ THE BASELINES BELOW WERE CAPTURED FROM UNPATCHED CODE at
/// 2a280ca and pasted in, so this test passes in BOTH states — before the
/// batch and after it. A darkened palette token has no geometry, and a `Flexible` that
/// only matters when a row is too narrow must leave every row that fits
/// exactly where it was. If either moved a glyph, the fingerprint differs.
///
/// ⭐ WHY GLYPH BOXES AND NOT THE PARAGRAPH BOX. Taking the time out of
/// `Expanded` changes its paragraph BOX from "all the remaining width" to
/// "its own width" while painting the same glyphs in the same place. The
/// box is a layout artefact; the glyphs and their origin are what the eye
/// sees, so the fingerprint is the union of the selection boxes.
///
/// ⚠️ Measured under ROBOTO, loaded in `setUpAll` — see the note there. In
/// the harness font (§13(ay)) "10:30 AM" is 124 px and the badge beside it
/// is trimmed at 375 even at the default size, which would have reported a
/// move no device shows. The comparison is before-vs-after under the same
/// font either way; the real font makes it a comparison of what a user sees.
///
/// The History fixture is COMPLETE records only. The gap-line fix makes an
/// incomplete row taller at 375 by design (it wraps instead of clipping), so
/// an incomplete row here would measure the intended change, not an
/// unintended one. The gap line has its own test in a11y_batch_measure_test.

const List<double> kWidths = <double>[375, 430, 800];

/// ⛔ BASELINE FROM UNPATCHED CODE, 11 Sep 2026 at 2a280ca, under Roboto. `count|fnv1a64`.
/// Regenerate ONLY when a change is MEANT to move text, and say so in the
/// commit that does.
const Map<String, String> kBaseline = <String, String>{
  'about@375': '29|3315bff0702104a5',
  'about@430': '29|4c5c1897c3518a09',
  'about@800': '29|62f04e368eb08f4b',
  'form@375': '111|41f845554f9f7f6d',
  'form@430': '111|59ef24d23077d0cd',
  'form@800': '111|005d8fd11ea3da42',
  'history@375': '18|7e4a49c523f9c67a',
  'history@430': '18|1b97d4c28abbd2a3',
  'history@800': '18|419cbc150b5086a6',
  'home@375': '26|7278b6617639a096',
  'home@430': '26|533e586b465ca2dd',
  'home@800': '26|7b619995111d3ac2',
};

/// Deterministic 64-bit FNV-1a over UTF-8, so no package is needed.
String fnv1a64(String s) {
  var h = 0xcbf29ce484222325;
  for (final b in utf8.encode(s)) {
    h ^= b;
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  // Dart ints are signed 64-bit; drop the sign bit so the hex has no '-'.
  return (h & 0x7FFFFFFFFFFFFFFF).toRadixString(16).padLeft(16, '0');
}

String r1(double v) => v.toStringAsFixed(1);

/// One line per paragraph: `text|x,y|w x h`, sorted, so order of traversal
/// does not matter. `x,y` and `w x h` are the GLYPHS — the union of the
/// paragraph's selection boxes, in global coordinates — not the paragraph's
/// layout box.
///
/// ⛔ `RenderParagraph.textSize` is NOT glyph extent. Under `Expanded` the
/// paragraph is laid out with a tight minimum width, so `textSize.width` is
/// the whole slot (163.5 for "10:30 AM" at 375) while the glyphs are 67.9
/// wide. Measured 11 Sep 2026: the first version of this test flagged all
/// three History widths for exactly that, with every position identical.
List<String> paragraphs(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph) {
      final t = o.text.toPlainText().replaceAll('\n', ' ');
      final boxes = t.isEmpty
          ? const <TextBox>[]
          : o.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: t.length));
      Rect r;
      if (boxes.isEmpty) {
        // Icon glyphs and empty paragraphs: the box is all there is.
        r = Offset.zero & o.textSize;
      } else {
        r = boxes.first.toRect();
        for (final b in boxes.skip(1)) {
          r = r.expandToInclude(b.toRect());
        }
      }
      final p = o.localToGlobal(r.topLeft);
      out.add('${t.length > 40 ? t.substring(0, 40) : t}|${r1(p.dx)},${r1(p.dy)}'
          '|${r1(r.width)}x${r1(r.height)}');
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  out.sort();
  return out;
}

/// Compares one screen-at-width against its baseline. Returns null on a
/// match, or a one-line description of the mismatch; the caller collects
/// these so every width is measured and printed before anything fails.
String? check(WidgetTester tester, String key) {
  // ⚠️ §13(ay): home's app-bar title overflows 41 px at 375 IN THE HARNESS
  // FONT ONLY — retracted as an artefact, 127 points to spare on a device.
  // Drain those so a pre-existing artefact does not fail a comparison whose
  // subject is whether THIS batch moved anything; print them so a NEW one
  // would still be seen.
  final drained = <String>[];
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {
    final m = RegExp(r'overflowed by ([0-9.]+) pixels').firstMatch('$e');
    drained.add(m == null ? '$e'.split('\n').first : '${m.group(1)}px');
  }
  if (drained.isNotEmpty) {
    // ignore: avoid_print
    print('  $key drained exceptions (pre-existing, §13(ay)): $drained');
  }
  final lines = paragraphs(tester);
  final got = '${lines.length}|${fnv1a64(lines.join('\n'))}';
  final want = kBaseline[key];
  // ignore: avoid_print
  print('  $key => $got');
  if (want == null) {
    // First run: emit the material for the baseline map and the full list so
    // a later mismatch can be diffed against something.
    // ignore: avoid_print
    print("  '$key': '$got',\n    ${lines.join('\n    ')}");
    return null;
  }
  if (got != want) {
    // ignore: avoid_print
    print('  MISMATCH on $key — current paragraphs:\n    ${lines.join('\n    ')}');
    return '$key: got $got, baseline $want';
  }
  return null;
}

/// Anchored to TODAY so home's relative-day copy ("today") is stable across
/// runs; the clock time is fixed so its glyph count is fixed.
List<EventRecord> completeRows() {
  final now = DateTime.now();
  return List.generate(
    3,
    (i) => EventRecord(
      id: 'c$i',
      timestamp: DateTime(now.year, now.month, now.day, 10, 30 + i),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: i == 2 ? kTypeAbsence : kTypeSeizure,
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    ),
  );
}

void setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, w >= 800 ? 1280 : 932);
  tester.view.devicePixelRatio = 1.0;
}

void main() {
  // The ONLY prefs-dependent test in this file (home). History and the form
  // read no prefs.
  setUpAll(() async {
    // ⭐ A REAL FONT, for the reason the CLAUDE.md rule gives: the harness
    // font is monospaced at one em per glyph, so at 375 "10:30 AM" measured
    // 124 px and the badge beside it was trimmed at 1.0 — a difference the
    // eye would never see on a device, where the same string is 67.9 px in
    // Roboto (measured here) and both fit with room to spare. Whether the History title row changed is a
    // question about glyph widths, and the widget test can only answer it
    // with the platform's font loaded. Roboto from the SDK cache, the same
    // way test/backup_banner_copy_measure_test.dart loads it.
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — cannot compare real glyph widths.');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();

    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey:
          jsonEncode(completeRows().map((e) => e.toMap()).toList()),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDownAll(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('home — paragraphs unchanged at 375, 430, 800', (tester) async {
    addTearDown(tester.view.reset);
    final moved = <String>[];
    for (final w in kWidths) {
      setWidth(tester, w);
      await tester.pumpWidget(
          MaterialApp(theme: MERTheme.light, home: const HomeScreen()));
      await tester.pumpAndSettle();
      final m = check(tester, 'home@${w.toInt()}');
      if (m != null) moved.add(m);
    }
    expect(moved, isEmpty, reason: 'a glyph moved on home');
  });

  testWidgets('history — paragraphs unchanged at 375, 430, 800',
      (tester) async {
    addTearDown(tester.view.reset);
    final moved = <String>[];
    for (final w in kWidths) {
      setWidth(tester, w);
      await tester.pumpWidget(MaterialApp(
        theme: MERTheme.light,
        home: HistoryScreen(
          records: completeRows(),
          onRecordsChanged: (_) async {},
          onEdit: (_, {required confirmOnSave}) async {},
        ),
      ));
      await tester.pumpAndSettle();
      final m = check(tester, 'history@${w.toInt()}');
      if (m != null) moved.add(m);
    }
    expect(moved, isEmpty, reason: 'a glyph moved on History');
  });

  // ⭐ ABOUT IS A CONTROL ON THE ABOUT FIXES THEMSELVES. In Roboto every
  // label-and-value row fits at 375, so the `Flexible`s and the half-row cap
  // have nothing to do at the default size and must leave each paragraph
  // where it was. (In the harness font two rows overflowed at 375 — §13(bw)'s
  // 109 and 69 px — which is what a11y_batch_measure_test asserts against.)
  testWidgets('about — paragraphs unchanged at 375, 430, 800', (tester) async {
    addTearDown(tester.view.reset);
    final moved = <String>[];
    for (final w in kWidths) {
      setWidth(tester, w);
      await tester.pumpWidget(
          MaterialApp(theme: MERTheme.light, home: const AboutScreen()));
      await tester.pumpAndSettle();
      final m = check(tester, 'about@${w.toInt()}');
      if (m != null) moved.add(m);
    }
    expect(moved, isEmpty, reason: 'a glyph moved on About');
  });

  testWidgets('form — paragraphs unchanged at 375, 430, 800', (tester) async {
    addTearDown(tester.view.reset);
    final moved = <String>[];
    for (final w in kWidths) {
      setWidth(tester, w);
      await tester.pumpWidget(MaterialApp(
          theme: MERTheme.light,
          home: LogEventScreen(existing: completeRows().first)));
      await tester.pumpAndSettle();
      final m = check(tester, 'form@${w.toInt()}');
      if (m != null) moved.add(m);
    }
    expect(moved, isEmpty, reason: 'a glyph moved on the form');
  });
}
