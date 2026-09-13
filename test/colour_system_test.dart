import 'dart:convert';
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

  test('3. brand and focus, including the two constrained tokens', () {
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
}
