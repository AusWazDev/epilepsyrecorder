import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ §10 FIX 1'S DESIGN HALF — IS THE GAP LINE THE LOUDEST THING ON THE ROW?
///
/// ⚠️ **§5's counter-argument is right and is not being bypassed.** The FIELD
/// LIST STAYS: naming which fields are open is what turns a filtered list of
/// quick-logs into a work queue rather than a broken screen. ⭐ **What is in
/// question is the REGISTER, and only the register.**
///
/// The copy half moved on 7 September (*"Needs:"* → *"Add details:"*). This
/// measures the half that remains: prominence, per H3 — *an affordance rather
/// than a sentence, never the most prominent thing on the row.*
///
/// ## ⛔ THE CASE THAT MATTERS IS THE QUICK-LOGGED ROW
///
/// On a partial row the gap line sits UNDER a content line and is already
/// subordinate. ⚠️ **On a timestamp-only row there is no content line at
/// all** — `content.isNotEmpty` omits it — so the gap line is the only thing
/// in the subtitle. **That is the carer who quick-logged during an event and
/// opened History, and it is the row they just created.**
void main() {
  setUpAll(() async {
    // ⚠️ Roboto: this file makes SIZE and WIDTH claims, and the harness font
    // is monospaced at one em per glyph.
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — a width claim needs the real font');
    }
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// A quick-logged record: a timestamp and nothing else.
  EventRecord quickLogged() => EventRecord(
        id: 'q1',
        timestamp: DateTime(2026, 9, 1, 14, 30),
        duration: null,
        durationSeconds: null,
        detailsCompleted: false,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        eventType: null,
        severity: null,
      );

  Future<void> pump(WidgetTester tester, List<EventRecord> rows) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: HistoryScreen(
        records: rows,
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  }

  ({double size, int weight, double width, bool clipped})? probe(
      WidgetTester tester, String startsWith) {
    for (final e in tester.allElements) {
      final ro = e.renderObject;
      if (ro is! RenderParagraph) continue;
      final t = ro.text.toPlainText();
      if (!t.startsWith(startsWith)) continue;
      final st = ro.text.style;
      return (
        size: st?.fontSize ?? -1,
        weight: (st?.fontWeight ?? FontWeight.w400).value,
        width: ro.size.width,
        clipped: ro.didExceedMaxLines,
      );
    }
    return null;
  }

  testWidgets('MEASUREMENT: the quick-logged row, at 375', (tester) async {
    await pump(tester, <EventRecord>[quickLogged()]);

    final gap = probe(tester, 'Add details');
    expect(gap, isNotNull,
        reason: 'positive control: the gap line is on the row at all, so the '
            'figures below describe it rather than its absence');

    // ⛔ THE TITLE IS FOUND BY POSITION, NOT BY GUESSING ITS TEXT. A first
    // version probed for '1 Sep' and got null because the date format is not
    // what I assumed — and a null there would have read as "no title".
    // Enumerate what is actually on the row instead.
    final all = <({String text, double size, int weight, double top})>[];
    for (final e in tester.allElements) {
      final ro = e.renderObject;
      if (ro is! RenderParagraph) continue;
      final st = ro.text.style;
      final txt = ro.text.toPlainText();
      // ⛔ ICONS ARE RENDERED AS PARAGRAPHS TOO, and they are the trap
      // here. An `Icon` is one private-use glyph in a 24pt font, so a
      // positional probe that takes "the paragraph above the gap line" picks
      // the ICON and reports the title as 24/w400. The first run of this test
      // did exactly that. Text is what has letters in it.
      if (!RegExp(r'[A-Za-z0-9]').hasMatch(txt)) continue;
      all.add((
        text: txt,
        size: st?.fontSize ?? -1,
        weight: (st?.fontWeight ?? FontWeight.w400).value,
        top: ro.localToGlobal(Offset.zero).dy,
      ));
    }
    all.sort((a, b) => a.top.compareTo(b.top));
    // ignore: avoid_print
    print('EVERY paragraph on the screen, top-down:');
    for (final a in all) {
      // ignore: avoid_print
      print('    y=${a.top.toStringAsFixed(1)}  ${a.size}/${a.weight}  '
          '${a.text}');
    }

    // The row's TITLE is the paragraph directly above the gap line.
    final gapTop =
        all.firstWhere((a) => a.text.startsWith('Add details')).top;
    final above = all.where((a) => a.top < gapTop).toList();
    final title = above.isEmpty
        ? null
        : (size: above.last.size, weight: above.last.weight,
           width: 0.0, clipped: false);

    // ignore: avoid_print
    print('GAP LINE vs the row it sits on — quick-logged, 375w\n'
        '  title  : size=${title?.size} weight=${title?.weight} '
        'width=${title?.width.toStringAsFixed(1)}\n'
        '  gap    : size=${gap!.size} weight=${gap.weight} '
        'width=${gap.width.toStringAsFixed(1)} clipped=${gap.clipped}');

    // ⛔ H3, AS A MEASUREMENT RATHER THAN A JUDGEMENT. The gap line must not
    // be the loudest thing on the row: strictly smaller than the title, and
    // no heavier.
    expect(gap.size, lessThan(title!.size),
        reason: 'H3: the gap line is never the most prominent thing on the '
            'row. It is ${gap.size} against the title\'s ${title.size}');
    expect(gap.weight, lessThanOrEqualTo(title.weight),
        reason: 'and it must not out-weigh the title either');
  });

  testWidgets('MEASUREMENT: does the gap line still clip at 375?',
      (tester) async {
    // ⚠️ `history_screen.dart` records this line clipping at 375 — and records
    // the fix: `maxLines: 1` was REMOVED on 11 Sep so it WRAPS instead of
    // ellipsising, because the row's whole job is to name the open fields and
    // an ellipsis hid the names.
    //
    // ⛔ So the question the brief asks — does demoting resolve the clipping
    // or merely move it — is answered by measuring whether it clips AT ALL,
    // not by comparing demoted against undemoted.
    await pump(tester, <EventRecord>[quickLogged()]);

    final gap = probe(tester, 'Add details');
    expect(gap, isNotNull, reason: 'positive control: the line is rendered');

    // ignore: avoid_print
    print('CLIPPING at 375: didExceedMaxLines=${gap!.clipped} '
        'width=${gap.width.toStringAsFixed(1)}');

    expect(gap.clipped, isFalse,
        reason: 'the field names must survive — an ellipsis here hides the '
            'very thing that makes the row actionable');
  });
}
