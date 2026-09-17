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

/// ⛔ BASELINE FROM UNPATCHED CODE, 11 Sep 2026 at 2a280ca, under Roboto, RECAPTURED 12 Sep 2026 when the date exclusion landed. `count|fnv1a64`.
/// Regenerate ONLY when a change is MEANT to move text, and say so in the
/// commit that does.
///
/// ⚠️ RECAPTURED AGAIN, SAME DAY, FOR THE SUBSTITUTION. The theme pass
/// moved every paragraph resolving to a `textTheme` slot; this pass moved
/// the 103 sites that carried a LOCAL style and now name a `MERType`
/// constant. ⭐ PARAGRAPH COUNTS UNCHANGED AGAIN at 29/111/18/26, across
/// both passes — text moved twice and nothing appeared or disappeared
/// either time.
///
/// ⚠️ ALL FOUR SCREENS RECAPTURED 17 September 2026 FOR THE TYPE SCALE,
/// and this is the largest "change that is MEANT to move text" the rule
/// above has covered. The theme's six steps replace seven sizes between
/// 9 and 16, so every paragraph resolving to a `textTheme` slot changed
/// size. ⭐ THE PARAGRAPH COUNT IS UNCHANGED IN ALL TWELVE CASES — 29,
/// 111, 18 and 26 — which is the other half of the check: text moved,
/// and nothing appeared or disappeared.
///
/// ⚠️ **HOME AND THE FORM RECAPTURED 13 September 2026 FOR C3, and this is the
/// "change that is MEANT to move text" the line above anticipates.** Taking 26
/// strokes from 0.5 logical to 1.0 adds height to every bordered box, and
/// `Border.all` paints inside the box, so the boxes grow. **About and History
/// are UNCHANGED and were not recaptured** — they carry no bordered box that
/// moves, and leaving their baselines at 2a280ca keeps them proving what they
/// always proved.
///
/// ⭐ **WHAT WAS CHECKED BEFORE RECAPTURING, because a hash cannot say it:**
/// a fingerprint reports that something moved, never whether anything
/// RESIZED. Every glyph box on home, the form and the vocabulary screen was
/// compared before and after at all three widths — **528 boxes, 162
/// translated, 0 resized.** Nothing wrapped, nothing clipped, no extent
/// changed by so much as a tenth. Home's glyphs move BOTH ways (-2.0 to +1.5)
/// because home is centred; see AUDIT.md §13(ac)'s annotation of the same
/// date, which records that as standing brittleness rather than a C3 artefact.
///
/// ⚠️ **HOME RECAPTURED AGAIN 13 September 2026, for Brief L**, and again it
/// is a change MEANT to move text. *"Tap to timestamp now"* left the capture
/// button's fill for the surface beneath it, because at 11 px on
/// `captureFill` no colour clears 4.5 — even solid white is 3.67 there. The
/// button loses that line's height and the page gains it, which home's
/// centring redistributes about the midpoint. **Measured at all three widths:
/// 22 of 26 glyph boxes translated, 0 RESIZED, one up and 21 down by 2.5.**
/// History, About and the form are untouched and keep their baselines.
///
/// ⛔ **THE HINT'S OWN BOX IS NOT A REAL EXTENT CHANGE — it is the font caveat
/// from `CLAUDE.md` arriving somewhere new.** Its box reads 220.0 x 11.0
/// before and 114.4 x 13.2 after, which looks like a shrink and is not:
/// *"Tap to timestamp now"* is 20 characters, 20 x 11.0 = 220.0 exactly, and
/// the line box equals the font size — the one-em-per-glyph signature of the
/// harness font. Inside an `ElevatedButton` the text inherits
/// `elevatedButtonTheme`'s `textStyle`, which names no family and inherits
/// none, so it resolved to the ENGINE default even with Roboto loaded;
/// outside the button it inherits the app's `textTheme` and resolves to
/// Roboto. **The rule was written about the app-bar title. It applies to any
/// `ButtonStyle.textStyle` that names no family.** The after figure is the
/// real one.
const Map<String, String> kBaseline = <String, String>{
  'about@375': '29|02511aa5c288620a',
  'about@430': '29|25ce74635aecd66d',
  'about@800': '29|2104bac54e69c174',
  // ⚠️ FORM RECAPTURED 17 September 2026 FOR S3, which migrated the form's
  // selection controls to `FilterChip`/`ChoiceChip`. A chip migration is a
  // change that is MEANT to move text, so the hashes move with it.
  //
  // ⭐ **THE COUNT IS THE PART THAT DID NOT MOVE, AND IT IS THE PART THAT
  // MATTERS HERE: 111 paragraphs at every width, before and after.** The
  // hash says glyphs are in different places; the count says none was added
  // and none was lost. A migration that had dropped a label — the retired
  // legacy value, say, whose whole point is that it is easy to lose — would
  // have changed the count, not just the hash.
  //   S3 before  111|56ece42ea2561b54  111|01961f3a33b9a433  111|1bfce1dcaf07c456
  //
  // ⚠️ MOVED AGAIN FOR V4, same day. `occurred_at_field`'s section label is
  // one of the eight strings that joined the uppercase register, and it is on
  // this screen — so the glyphs move and the hash with them.
  //   V4 before  111|3cd1a2421b855f64  111|2c9c2ab5df28b2e7  111|551c4704e46052bf
  //
  // ⭐ Still 111 at every width across BOTH changes. Casing a label alters the
  // glyphs, never the paragraph count.
  //
  // 🔴 MOVED AGAIN FOR B1 — AND THIS IS THE FIRST TIME THE **COUNT** HAS
  // MOVED, so it is explained rather than just re-recorded. The form's event
  // type went from a `GridView` of hand-rolled tiles to `ChoiceChip`s in a
  // `BoundedChipWrap`.
  //   B1 before  111|38d3ee217359d306  111|6bae0bf974af9c1d  111|1c3371e344744849
  //
  // ⚠️ **114 at 375 and 430, still 111 at 800**, and the three extra
  // paragraphs were MEASURED, not assumed: diffing the form's paragraphs
  // across widths, the only strings present at 375 and absent at 800 are
  // `4 to choose from`, a chevron icon glyph, and `Show all`. **That is the
  // bounded picker's disclosure**, which appears at 375/430 because the four
  // type chips need a fourth row there and not at 800.
  //
  // ⛔ AND THE CONSEQUENCE, RECORDED BECAUSE IT IS A REAL COST: at 375 the
  // picker renders **3 of 4** event types, with the fourth behind `Show all`.
  // The grid always showed all four. The selected chip and any orphan are
  // PINNED, so a value the record holds can never be hidden — but an
  // unselected type costs one tap at 375. The wizard's picker behaves
  // identically (**4 of 5** at 375), which is what B1 set out to achieve.
  'form@375': '114|6ab040606e0afa76',
  'form@430': '114|28fb9b5df8b0c24c',
  'form@800': '111|24c6846d23152844',
  // ⚠️ HISTORY RECAPTURED 17 September 2026 FOR BRIEF S, and this is a
  // "change that is MEANT to move text" in the sense the rule above requires.
  //
  // The per-row control's ICON changed from `delete_outline` to
  // `visibility_off_outlined` when the action became a hide. An `Icon` is a
  // glyph in an icon font, so it IS a paragraph here — a different codepoint
  // is different text and the fingerprint must change.
  //
  // ⭐ PROVED RATHER THAN ASSERTED, because "only the icon moved" is exactly
  // the kind of claim this file exists to distrust. With the icon alone
  // reverted and the new tooltip and colour left in place, all four cases
  // PASSED against the old baselines — so the tooltip and the colour move no
  // glyph, and the whole delta is the codepoint. The paragraph COUNT is
  // unchanged at 18 in every case, which is the second half of the same check.

// ⛔ RE-BASELINED 18 September 2026 — THE SPACING SCALE, NOT A LAYOUT CHANGE.
//
// `home` 20 → 16 and `history` 14 → 16 horizontal body inset. ⭐ THE DISPLACEMENT
// IS A PURE TRANSLATION AND THAT IS WHY THESE WERE RE-BASELINED RATHER THAN
// INVESTIGATED: every paragraph COUNT is unchanged (home 26, history 18, at
// every width), every size is unchanged, and only x moved — home left by 4,
// history right by 2. Nothing re-wrapped.
//
// ⚠️ `home@800` DID NOT MOVE and keeps its original baseline. That is not luck:
// above 560 the `maxWidth: 520` cap binds and the body inset goes inert, which
// is §13(aa)'s measurement confirming itself from the other direction.
//
// PREVIOUS VALUES, preserved so the move is auditable:
//   history@375  18|5b9a6e7eb59bde87    home@375  26|0311d5988de3e462
//   history@430  18|00b7a64db41605a1    home@430  26|6e840b2ee1728db9
//   history@800  18|51b8a4a60ef0f99c
  'history@375': '18|1a406a316c5807c3',
  'history@430': '18|505ffac4fb98c4f0',
  'history@800': '18|41816790020f9797',
  // ⚠️ HOME RECAPTURED 17 September 2026 for Amendment 1.2, which recased
  // `Record Event` to `Record event`. A label the census measures changed its
  // glyphs, so the hash moves — this is a change that is MEANT to move text.
  //   before  26|11ff9fc06c3f4b04  26|797ecb4fea786548  26|4e7775de03f9b076
  //
  // ⭐ COUNT HELD AT 26 at every width. The capture control is still exactly
  // one paragraph — recasing a label must not split or merge one, and a
  // ripple that had missed a quoting site would show up as a count change on
  // whichever screen still said the old name.
  //
  // ⛔ MOVED AGAIN FOR §10 FIX 4 — HOME IS NOW ANCHORED TO THE TOP. `Center`
  // became `Align.topCenter` and the Column starts rather than centres, so
  // EVERY glyph on home moved up. This is the largest deliberate movement on
  // this screen and it is the fix, not a regression: the content no longer
  // floats when a banner appears or disappears.
  //   Amendment 1.2  26|680aa3b95bd039a4  26|5e8b430f8b8f1928  26|0fe9ec35e9ad5a56
  //
  // ⭐ COUNT STILL 26 at every width, across three separate changes now.
  // Anchoring moves paragraphs; it must not create or destroy one.

// RE-BASELINED 18 September 2026 (second time today) - HOME'S COMPOSITION IS
// CENTRED AGAIN, reversing 6fd3f1c's anchoring. A PURE VERTICAL TRANSLATION:
// every paragraph count is unchanged at 26, across all three widths.
//
// NOTE THE DIFFERENCE FROM THIS MORNING'S SPACING RE-BASELINE, because it is
// evidence rather than trivia: that one left home@800 untouched, since above
// 560 the maxWidth: 520 cap binds and a horizontal inset goes inert. This is a
// VERTICAL change, which no horizontal cap can absorb, so all three moved.
//
// PREVIOUS VALUES:
//   home@375  26|0f4328a65b772386
//   home@430  26|4213dbc43d975993
//   home@800  26|52789e80c2f9064c
  'home@375': '26|0b86b546f29e3373',
  'home@430': '26|15d4582aab01e8aa',
  'home@800': '26|0fe9ec35e9ad5a56',
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

/// A rendered date, `d MMM yyyy` — what `_LastEventCard` and `OccurredAtField`
/// print. See the exclusion in [paragraphs].
final RegExp kRenderedDate = RegExp(r'\b\d{1,2} \w{3} 20\d\d\b');

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
      if (kRenderedDate.hasMatch(t)) {
        // ⛔ EXCLUDED, AND ENUMERATED — 12 Sep 2026. A paragraph that renders a
        // DATE changes text and width every day, so hashing it made this
        // comparison fail on the calendar rolling over rather than on anything
        // moving. It did, the next morning: home's LAST EVENT line and the
        // form's occurred-at line, one per screen, printed by `check` below.
        // Their ORIGIN is still compared — only the glyphs are dropped, which
        // is the smallest exclusion that removes the dependence.
        // ⚠️ RESIDUAL, stated rather than hidden: a date whose width changes
        // (1 Oct against 12 Sep) can still move a SIBLING on the same row, and
        // that sibling is compared. The failure would be loud and the printed
        // list identifies it.
        out.add('<DATE>|${r1(p.dx)},${r1(p.dy)}');
        return;
      }
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
  // Name what the date exclusion removed, per the enumerate-every-exclusion
  // rule. A date paragraph appearing or disappearing still changes the count.
  final dates = lines.where((l) => l.startsWith('<DATE>|')).toList();
  // ignore: avoid_print
  print('  $key date paragraphs excluded: ${dates.length} $dates');
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
