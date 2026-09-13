import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// THE COLOUR SYSTEM ASSERTS ITS OWN THRESHOLDS.
///
/// ⛔ WHY A TEST AND NOT A COMMENT. Seven values clear by less than 0.04 and
/// `caution.onContainer` by **0.0037**. That is not fragility in the
/// arithmetic — a computed ratio has no measurement error — it is fragility
/// against a future edit. A one-step change to `#FFF3E0` drops
/// `cautionOnContainer` below 4.5 and nothing else in this repository would
/// say so.
///
/// ⛔ AND IT TESTS FILLS, NOT ONLY TEXT. `warning` `#BA7517` hid from TWO
/// separate sweeps — §13(w)'s and the colour specification's — because both
/// enumerated foreground-on-background TEXT pairs, and `warning`'s only use
/// was a fill behind a white label. A sweep that looks only at text cannot
/// see a fill. Three live 4.5 failures sat behind that blind spot.
///
/// ⚠️ EVERY RATIO HERE IS A DEFINED PAIR, which is what §13(s) measures and
/// what it says it measures. §13(ck) records that a 0.5-logical stroke paints
/// at roughly half strength on a 1× device — `outline` reads 1.72 painted
/// against 3.38 defined — so the non-text values here are not honest until
/// C3 takes theme strokes to 1.0. That is recorded, not hidden.
///
/// > ⭐ **DISCHARGED 13 Sep 2026 at `0d57f09`.** C3 took all 26 strokes
/// > carrying a contrast claim to 1.0, and `outline` was then measured
/// > painting its defined `#798EA3` at full coverage. The caveat above stays
/// > readable as written because it records what was true when the set
/// > landed; it no longer applies to the current tree.

// ── the apparatus, written from the sRGB formula ───────────────────────────

double _lin(int c) {
  final v = c / 255.0;
  return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _lum(Color c) {
  final argb = c.toARGB32();
  return 0.2126 * _lin((argb >> 16) & 0xFF) +
      0.7152 * _lin((argb >> 8) & 0xFF) +
      0.0722 * _lin(argb & 0xFF);
}

double ratio(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

String hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// WCAG 2.2: 4.5 for normal text, 3.0 for large text and non-text UI.
/// Large is 18.67 px bold or 24 px regular — §13(s)'s conversion from 14pt
/// bold / 18pt, `w600` read as bold, which is the generous reading.
const double kNormalText = 4.5;
const double kLargeOrNonText = 3.0;

bool isLarge(double px, FontWeight w) =>
    px >= 24 || (px >= 18.67 && w.value >= FontWeight.w600.value);

void mustClear(Color fg, Color bg, double need, String what) {
  final r = ratio(fg, bg);
  expect(r >= need, isTrue,
      reason: '$what: ${hex(fg)} on ${hex(bg)} is '
          '${r.toStringAsFixed(4)}, needs $need');
}

// ── the set, as a table the test walks ─────────────────────────────────────

typedef Status = ({String name, Color container, Color onContainer, Color accent});
typedef Identity = ({String name, Color container, Color on});

const List<Status> kStatus = <Status>[
  (name: 'info', container: MERColours.infoContainer,
   onContainer: MERColours.infoOnContainer, accent: MERColours.infoAccent),
  (name: 'caution', container: MERColours.cautionContainer,
   onContainer: MERColours.cautionOnContainer, accent: MERColours.cautionAccent),
  (name: 'positive', container: MERColours.positiveContainer,
   onContainer: MERColours.positiveOnContainer, accent: MERColours.positiveAccent),
  (name: 'critical', container: MERColours.criticalContainer,
   onContainer: MERColours.criticalOnContainer, accent: MERColours.criticalAccent),
];

const List<Identity> kIdentity = <Identity>[
  (name: 'seizure', container: MERColours.identitySeizureContainer,
   on: MERColours.identitySeizureOn),
  (name: 'absence', container: MERColours.identityAbsenceContainer,
   on: MERColours.identityAbsenceOn),
  (name: 'medication', container: MERColours.identityMedicationContainer,
   on: MERColours.identityMedicationOn),
  (name: 'other', container: MERColours.identityOtherContainer,
   on: MERColours.identityOtherOn),
];

/// ⛔ EVERY FILL IN THE APP THAT CARRIES A WHITE LABEL, with the label's real
/// size and weight. This is the table `warning` would have been caught by.
/// A fill's threshold depends on the LABEL, not on the fill.
const List<({String what, Color fill, double px, FontWeight weight})> kWhiteOnFill =
    <({String what, Color fill, double px, FontWeight weight})>[
  (what: 'Record Event', fill: MERColours.captureFill,
   px: 26, weight: FontWeight.w700),
  (what: 'selected chip / selected severity', fill: MERColours.primary,
   px: 13, weight: FontWeight.w600),
  (what: 'failed-write retry button', fill: MERColours.criticalOnContainer,
   px: 14, weight: FontWeight.w600),
  (what: 'storage-fallback button', fill: MERColours.cautionOnContainer,
   px: 13, weight: FontWeight.w600),
  (what: 'selected type button, seizure', fill: MERColours.identitySeizureOn,
   px: 13, weight: FontWeight.w600),
  (what: 'selected type button, absence', fill: MERColours.identityAbsenceOn,
   px: 13, weight: FontWeight.w600),
  (what: 'selected type button, medication', fill: MERColours.identityMedicationOn,
   px: 13, weight: FontWeight.w600),
  (what: 'selected type button, other', fill: MERColours.identityOtherOn,
   px: 13, weight: FontWeight.w600),
];

void main() {
  const surface = MERColours.surface;
  const sunken = MERColours.surfaceSunken;

  test('1. the apparatus, on WCAG\'s own boundary', () {
    // ⛔ A control on the calculator BEFORE any real value is read. One that
    // rounded would call both of these 4.5 and both passing.
    expect(ratio(const Color(0xFF767676), surface) >= 4.5, isTrue);
    expect(ratio(const Color(0xFF777777), surface) >= 4.5, isFalse);
  });

  test('2. foundation and text, on both grounds', () {
    mustClear(MERColours.outline, surface, kLargeOrNonText, 'outline');
    mustClear(MERColours.outline, sunken, kLargeOrNonText, 'outline on sunken');
    for (final bg in <Color>[surface, sunken]) {
      mustClear(MERColours.onSurface, bg, kNormalText, 'onSurface');
      mustClear(MERColours.onSurfaceMuted, bg, kNormalText, 'onSurfaceMuted');
      mustClear(MERColours.link, bg, kNormalText, 'link');
    }
  });

  test('3. brand and focus, including the three constrained tokens', () {
    mustClear(MERColours.onPrimary, MERColours.primary, kNormalText, 'onPrimary');
    mustClear(MERColours.focusRing, surface, kLargeOrNonText, 'focusRing');
    mustClear(MERColours.focusRing, sunken, kLargeOrNonText, 'focusRing on sunken');
    mustClear(MERColours.accentOnPrimary, MERColours.primary, kNormalText,
        'accentOnPrimary');

    // ⛔ RULE 4, ASSERTED AS A NEGATIVE. These are not accidents to be fixed
    // later; a future edit that made either safe elsewhere would mean the
    // constraint in the name had stopped being true, and that must be noticed.
    expect(ratio(MERColours.focusRing, surface) >= kNormalText, isFalse,
        reason: 'focusRing is NON-TEXT. If it now clears 4.5 the rule beside '
            'it is stale and `link` may be redundant.');
    expect(ratio(MERColours.accentOnPrimary, surface) >= kLargeOrNonText, isFalse,
        reason: 'accentOnPrimary is ON-PRIMARY ONLY.');

    // ⛔ THE THIRD ON-PRIMARY-ONLY TOKEN, added by C2. 5.11 on primary, and
    // 1.67 on white — so the same negative that guards `accentOnPrimary`
    // guards this, for the same reason: a name that carries a constraint has
    // to fail loudly if the constraint stops being true.
    mustClear(MERColours.onPrimaryMuted, MERColours.primary, kNormalText,
        'onPrimaryMuted');
    expect(ratio(MERColours.onPrimaryMuted, surface) >= kLargeOrNonText, isFalse,
        reason: 'onPrimaryMuted is ON-PRIMARY ONLY.');

    // ⛔ AND IT MUST NOT COLLAPSE INTO `accentOnPrimary`. Both are on-primary
    // and both pass, which is exactly the condition under which two roles
    // quietly become one. One is muted prose, the other a SnackBar action.
    expect(MERColours.onPrimaryMuted, isNot(MERColours.accentOnPrimary),
        reason: 'two on-primary roles, two values, on purpose.');
  });

  test('4. status — onContainer on all three grounds, accent likewise', () {
    for (final s in kStatus) {
      mustClear(s.onContainer, s.container, kNormalText, '${s.name}.onContainer');
      mustClear(s.onContainer, surface, kNormalText, '${s.name}.onContainer/surface');
      mustClear(s.onContainer, sunken, kNormalText, '${s.name}.onContainer/sunken');
      mustClear(s.accent, s.container, kLargeOrNonText, '${s.name}.accent');
      mustClear(s.accent, surface, kLargeOrNonText, '${s.name}.accent/surface');
      mustClear(s.accent, sunken, kLargeOrNonText, '${s.name}.accent/sunken');
    }
  });

  test('5. identity — eight pairs on all three grounds', () {
    for (final i in kIdentity) {
      mustClear(i.on, i.container, kNormalText, 'identity ${i.name}');
      mustClear(i.on, surface, kNormalText, 'identity ${i.name}/surface');
      mustClear(i.on, sunken, kNormalText, 'identity ${i.name}/sunken');
    }
  });

  test('6. destructive', () {
    mustClear(MERColours.destructive, surface, kNormalText, 'destructive');
    mustClear(MERColours.destructive, sunken, kNormalText, 'destructive/sunken');
  });

  test('7. WHITE ON EVERY FILL, at the label\'s real size', () {
    for (final f in kWhiteOnFill) {
      final need = isLarge(f.px, f.weight) ? kLargeOrNonText : kNormalText;
      mustClear(MERColours.onPrimary, f.fill, need,
          'white on ${f.what} (${f.px}px ${f.weight})');
    }
  });

  test('8. white clears 4.5 on every status onContainer and identity on', () {
    // What retires the fallback banner's white-on-#E65100 at 3.79, and what
    // makes a filled status button work with no fifth value.
    for (final s in kStatus) {
      mustClear(MERColours.onPrimary, s.onContainer, kNormalText,
          'white on ${s.name}.onContainer');
    }
    for (final i in kIdentity) {
      mustClear(MERColours.onPrimary, i.on, kNormalText,
          'white on identity ${i.name}');
    }
  });

  test('9. no token is a duplicate of another under a different name', () {
    // ⛔ RULE 3's other half. `onSurface` and `primary` ARE equal today and
    // are exempt BY NAME; anything else colliding means two roles have
    // silently become one, which is §13(w)'s complaint.
    const named = <String, Color>{
      'surface': MERColours.surface, 'surfaceSunken': MERColours.surfaceSunken,
      'outline': MERColours.outline, 'onSurfaceMuted': MERColours.onSurfaceMuted,
      'focusRing': MERColours.focusRing, 'accentOnPrimary': MERColours.accentOnPrimary,
      'onPrimaryMuted': MERColours.onPrimaryMuted,
      'captureFill': MERColours.captureFill, 'link': MERColours.link,
      'infoContainer': MERColours.infoContainer,
      'infoOnContainer': MERColours.infoOnContainer,
      'infoAccent': MERColours.infoAccent,
      'cautionContainer': MERColours.cautionContainer,
      'cautionOnContainer': MERColours.cautionOnContainer,
      'cautionAccent': MERColours.cautionAccent,
      'positiveContainer': MERColours.positiveContainer,
      'positiveOnContainer': MERColours.positiveOnContainer,
      'positiveAccent': MERColours.positiveAccent,
      'criticalContainer': MERColours.criticalContainer,
      'criticalOnContainer': MERColours.criticalOnContainer,
      'criticalAccent': MERColours.criticalAccent,
      'identitySeizureContainer': MERColours.identitySeizureContainer,
      'identitySeizureOn': MERColours.identitySeizureOn,
      'identityAbsenceContainer': MERColours.identityAbsenceContainer,
      'identityAbsenceOn': MERColours.identityAbsenceOn,
      'identityMedicationContainer': MERColours.identityMedicationContainer,
      'identityMedicationOn': MERColours.identityMedicationOn,
      'identityOtherContainer': MERColours.identityOtherContainer,
      'identityOtherOn': MERColours.identityOtherOn,
    };
    final seen = <int, String>{};
    for (final e in named.entries) {
      final v = e.value.toARGB32();
      expect(seen.containsKey(v), isFalse,
          reason: '${e.key} and ${seen[v]} are both ${hex(e.value)} — two '
              'names for one colour, which is what rule 3 exists for');
      seen[v] = e.key;
    }
    // `destructive` deliberately shares `critical.onContainer`: one red
    // family, one meaning, with FORM carrying the distinction. Asserted so
    // the sharing stays deliberate.
    expect(MERColours.destructive.toARGB32(),
        MERColours.criticalOnContainer.toARGB32());
    expect(MERColours.onSurface.toARGB32(), MERColours.primary.toARGB32());
  });

  // ⛔ THE ONE PREFS-DEPENDENT TEST IN THIS FILE, per CLAUDE.md's harness rule.
  testWidgets('10. captureFill asserts its SIZE, not only its contrast',
      (tester) async {
    // `captureFill` is valid at 3.67 only because `Record Event` is large
    // text. That dependency has already been violated once — the same value
    // sat behind a 13 px w600 severity chip at 3.67 against 4.5 — so the
    // token's validity is asserted from the RENDERED label, not from a
    // comment describing it.
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey: jsonEncode(<Map<String, dynamic>>[]),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
    addTearDown(() {
      StorageBoot.debugSet();
      Vocabularies.debugReset();
    });

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        MaterialApp(theme: MERTheme.light, home: const HomeScreen()));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}

    final label = tester.widget<Text>(find.text('Record Event'));
    final px = label.style!.fontSize!;
    final weight = label.style!.fontWeight!;
    expect(isLarge(px, weight), isTrue,
        reason: 'Record Event renders at ${px}px $weight, which is NOT large '
            'text. White on captureFill is '
            '${ratio(MERColours.onPrimary, MERColours.captureFill).toStringAsFixed(2)}, '
            'so the token is invalid at this size. Either the label grows back '
            'or the fill changes.');
  });
  test('11. onFill, and the rule that makes it unconditional', () {
    // ⛔ EVERY FILL IT IS PERMITTED TO LAND ON. `primary`, all four
    // `onContainer`s and all four identity `on`s — enumerated, so a new
    // family cannot be added without this failing until it is listed.
    mustClear(MERColours.onFill, MERColours.primary, kNormalText,
        'onFill on primary');
    for (final s in kStatus) {
      mustClear(MERColours.onFill, s.onContainer, kNormalText,
          'onFill on ${s.name}OnContainer');
    }
    for (final i in kIdentity) {
      mustClear(MERColours.onFill, i.on, kNormalText,
          'onFill on identity ${i.name}');
    }

    // ⛔ THE RULE, ASSERTED AS A NEGATIVE — accents are never fills. Two of
    // the four DO clear, which is exactly why the rule is about fills and not
    // about this colour: "white works on accents" would be true of info and
    // critical and false of caution and positive, and a rule that is half
    // true ships a failure the first time somebody reaches for the wrong one.
    // If either of these ever passes, the accent has been lightened and the
    // rule beside `onFill` needs re-reading, not deleting.
    for (final name in <String>['caution', 'positive']) {
      final accent = kStatus.firstWhere((s) => s.name == name).accent;
      expect(ratio(MERColours.onFill, accent) >= kNormalText, isFalse,
          reason: '$name accent now clears 4.5 under white. Accents are '
              'STROKES, ICONS AND DOTS, derived against 3.0. If one is being '
              'used as a fill the rule has been broken, not outgrown.');
    }

    // ⚠️ `captureFill` is NOT in the permitted set and keeps its own
    // large-text exception, asserted separately in test 10. Folding it in
    // here would make `onFill` conditional again.
    expect(ratio(MERColours.onFill, MERColours.captureFill) >= kNormalText,
        isFalse,
        reason: 'captureFill is a large-text-only fill and must not be '
            'readable as an ordinary onFill ground.');
  });

  test('12. rule 2 is enforced over lib/, not described', () {
    // ⛔ THE CHECK THAT USED TO LIVE IN A TRANSCRIPT. C1 verified "no raw
    // literals" over hex only and reported zero, which was true and was not
    // the same as no widget naming a colour: two `Colors.red.shade…` had
    // survived every sweep, on the app's most destructive control, one of
    // them a live 2.9866. This scans BOTH forms.
    //
    // ⛔ AND IT SKIPS COMMENT LINES. Without that it flags the rule's own
    // documentation, because the note recording those two retired names
    // quotes them.
    final hex = RegExp(r'\bColor\(\s*0x[0-9a-fA-F]{8}\s*\)');
    final named = RegExp(r'\bColors\.([A-Za-z][A-Za-z0-9]*)');
    final neutral = RegExp(r'^(white|black)\d*$');

    // ⛔ THE RESIDUE, BY ADDRESS. Every survivor is listed with the reason it
    // survives. A new one fails this test; removing one fails it too, so the
    // list cannot rot in either direction.
    const allowed = <String, String>{
      'lib/main.dart:173': 'splash tagline, white 50% on primary — 3.3779, LIVE 4.5 FAILURE',
      'lib/main.dart:185': 'splash spinner, white 50% on primary — 3.3779, passes as non-text',
      'lib/main.dart:195': 'splash version, white 35% on primary — 2.4169, LIVE 4.5 FAILURE',
      'lib/models/event_record.dart:1656': 'export icon box, white 15% on a white sheet — paints nothing',
      'lib/models/event_record.dart:1662': 'export icon, white on that box — 0 non-white pixels in 30x30',
      'lib/screens/about_screen.dart:96': 'About version, white 55% on primary — 3.7663, LIVE 4.5 FAILURE',
      'lib/screens/about_screen.dart:104': 'About tagline, white 40% on primary — 2.6938, LIVE 4.5 FAILURE',
      'lib/screens/home_screen.dart:1217': 'Tap to timestamp now, white 65% on captureFill — 2.3805, LIVE 4.5 FAILURE and no token can fix it',
    };

    final chromatic = <String>[];
    final neutrals = <String>[];
    var scanned = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('theme/mer_theme.dart')) continue;
      scanned++;
      final lines = const LineSplitter().convert(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('///') ||
            trimmed.startsWith('*')) {
          continue;
        }
        final where = '$path:${i + 1}';
        if (hex.hasMatch(line)) chromatic.add('$where  hex literal');
        for (final m in named.allMatches(line)) {
          if (neutral.hasMatch(m.group(1)!)) {
            neutrals.add(where);
          } else {
            chromatic.add('$where  ${m.group(0)}');
          }
        }
      }
    }

    expect(scanned, greaterThan(20),
        reason: 'the scan found only $scanned files, so it did not run — a '
            'null here would otherwise be indistinguishable from a clean one');

    expect(chromatic, isEmpty,
        reason: 'rule 2: a widget names a colour.\n  ${chromatic.join("\n  ")}');

    final unexpected = neutrals.where((n) => !allowed.containsKey(n)).toList();
    expect(unexpected, isEmpty,
        reason: 'a NEW neutral literal appeared outside the theme. Give it a '
            'token or add it to the allowlist with its measurement:\n'
            '  ${unexpected.join("\n  ")}');

    final gone = allowed.keys.where((k) => !neutrals.contains(k)).toList();
    expect(gone, isEmpty,
        reason: 'the allowlist names a site that no longer has a literal. '
            'Delete the entry — a stale allowlist hides the next one:\n'
            '  ${gone.join("\n  ")}');
  });
}
