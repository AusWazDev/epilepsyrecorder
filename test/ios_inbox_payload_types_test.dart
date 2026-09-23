import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The TYPES the Swift inbox writers put into a payload, not the field names.
///
/// ⛔ WHY THIS EXISTS, AND WHY THE EXISTING PIN DOES NOT COVER IT.
/// `ios_handoff_test.dart` → *both Swift writers emit the schema this build
/// parses* checks the field NAMES and the version literal the writers spell.
/// It does not check the TYPES they pass in, and the types are what would
/// break.
///
/// ⭐ THE FAILURE IT GUARDS, which is the worst shape found in the 21 September
/// 2026 sweep:
///
///   `writeInboxInstruction` opens with
///       guard let shared = …,
///             let data = try? JSONSerialization.data(withJSONObject: payload),
///             let json = String(data: data, encoding: .utf8) else { return }
///
///   A payload containing a `Date`, a `URL`, a `Data` or an optional is not a
///   valid JSON object, so `JSONSerialization.data` returns nil, the `try?`
///   swallows it, and the function RETURNS SILENTLY. On the end path that means:
///
///     1. `secs` was computed correctly from a marker that parsed
///     2. no instruction is written — the duration now exists nowhere
///     3. `endedCleanly` is still true, so NO PRESERVE RUNS
///     4. the user is told "Event ended · 5m"
///     5. both marker copies are deleted
///
///   The duration is destroyed and the user has been told it was captured.
///   Wrong data rather than missing data, on the capture path.
///
/// ⚠️ IT IS SHUT TODAY BY CONSTRUCTION AND NOTHING HELD IT SHUT. The payload is
/// built in three places, all from `String` and `NSNumber`, all JSON-valid by
/// inspection. A fourth caller, or one changed value, would open it with no
/// test going red. That is what this file is.
///
/// ⚠️ WHAT THIS FILE CANNOT ESTABLISH:
///
///  * It is a TEXT SCAN over Swift. It does not type-check Swift and cannot.
///    It recognises a closed set of value SHAPES and rejects everything else,
///    which is deliberately conservative: an unrecognised shape fails and is
///    adjudicated by a human, rather than passing because it looked harmless.
///  * It does not prove `JSONSerialization` succeeds. It proves the inputs are
///    drawn from the shapes that make it succeed.
String _posix(String p) => p.replaceAll(Platform.pathSeparator, '/');

/// One `"key": value,` pair lifted out of a Swift dictionary literal.
class PayloadValue {
  PayloadValue(this.key, this.expression, this.line);
  final String key;
  final String expression;
  final int line;
  @override
  String toString() => 'line $line: "$key": $expression';
}

/// Extracts the dictionary literal that starts at [openLine] and returns its
/// values. Handles the multi-line form, which is the only form used.
List<PayloadValue> valuesOfLiteral(List<String> lines, int openLine) {
  final out = <PayloadValue>[];
  var depth = 0;
  for (var i = openLine; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trimLeft().startsWith('//')) continue;
    depth += '['.allMatches(raw).length - ']'.allMatches(raw).length;

    final m = RegExp(r'"(\w+)"\s*:\s*(.+?),?\s*$').firstMatch(raw.trim());
    if (m != null) out.add(PayloadValue(m.group(1)!, m.group(2)!, i + 1));

    if (i > openLine && depth <= 0) break;
  }
  return out;
}

/// Whether [expression] is a shape that JSON serialisation accepts, given the
/// String-typed names visible in [stringNames].
///
/// ⛔ ALLOWLIST, NOT DENY-LIST. A deny-list of `Date(`/`URL(` would pass any
/// bad shape nobody thought of, which is precisely how this class of defect
/// arrives.
bool isJsonSafe(String expression, Set<String> stringNames) {
  final e = expression.trim();
  if (RegExp(r'^NSNumber\(value:').hasMatch(e)) return true; // number
  if (RegExp(r'^".*"$').hasMatch(e)) return true;            // string literal
  if (e.contains('.string(from:')) return true;              // DateFormatter
  if (e.contains('.string(forKey:')) return true;            // defaults read
  if (RegExp(r'^String\(').hasMatch(e)) return true;         // explicit String
  if (RegExp(r'^\w+$').hasMatch(e)) return stringNames.contains(e);
  return false;
}

/// Names bound to a `String` within [start]..[end], from a function signature
/// or from a binding whose right-hand side produces a String.
Set<String> stringNamesIn(List<String> lines, int start, int end) {
  final names = <String>{};
  for (var i = start; i < end && i < lines.length; i++) {
    final l = lines[i];
    if (l.trimLeft().startsWith('//')) continue;
    for (final m in RegExp(r'\b(\w+)\s*:\s*String\b').allMatches(l)) {
      names.add(m.group(1)!);
    }
    for (final m in RegExp(
            r'\blet\s+(\w+)\s*=\s*(.+?)(?:,|\s*\{|$)')
        .allMatches(l)) {
      final rhs = m.group(2)!;
      if (rhs.contains('as? String') ||
          rhs.contains('.string(from:') ||
          rhs.contains('.string(forKey:') ||
          RegExp(r'^String\(').hasMatch(rhs.trim()) ||
          RegExp(r'^".*"').hasMatch(rhs.trim())) {
        names.add(m.group(1)!);
      }
    }
  }
  return names;
}

/// ⛔ THE NEGATIVE CONTROL. The realistic mistake, in the real shape.
///
/// ⚠️ A canary easier to detect than the real population proves nothing. This
/// is a multi-line dictionary literal with the same five keys, the same
/// formatting and the same surrounding binding style as the live writers — the
/// only difference is that `at` is handed the `Date` rather than the string
/// made from it, which is exactly the slip a person makes here.
const String kBadPayload = r'''
    private func writeInboxEndBad(id: String, at iso: String, seconds: Int) {
      let endTime = Date()
      writeInboxInstruction([
        "v": NSNumber(value: 1),
        "kind": "end",
        "id": id,
        "at": endTime,
        "seconds": NSNumber(value: max(0, seconds)),
      ])
    }
''';

void main() {
  final appPath = 'ios/Runner/AppDelegate.swift';
  final intentPath = 'ios/MERWidget/EndMEREventIntent.swift';
  final app = File(appPath).readAsStringSync().split('\n');
  final intent = File(intentPath).readAsStringSync().split('\n');

  group('the control — the checker rejects a bad payload', () {
    // ⭐ A control that passes where its siblings all fail is reporting on
    // itself. This one must FAIL the same predicate the live sources PASS,
    // or the green results below are uninformative.
    test('a Date in the "at" slot is rejected', () {
      final lines = kBadPayload.split('\n');
      final open = lines.indexWhere((l) => l.contains('writeInboxInstruction(['));
      expect(open, isNot(-1), reason: 'positive control: the literal was found');

      final names = stringNamesIn(lines, 0, lines.length);
      final values = valuesOfLiteral(lines, open);
      expect(values, hasLength(5),
          reason: 'positive control: all five pairs were extracted, '
              'so the extractor is reading the multi-line form');

      final bad = values.where((v) => !isJsonSafe(v.expression, names)).toList();
      expect(bad, hasLength(1),
          reason: 'the checker must reject exactly the Date. Found: $bad');
      expect(bad.single.key, 'at');
    });

    test('the same checker accepts the corrected form', () {
      // Proves the rejection above is about the Date and not about the shape
      // of the fixture — the two differ in one expression only.
      final fixed = kBadPayload.replaceAll(
          '"at": endTime,', '"at": ISO8601DateFormatter().string(from: endTime),');
      final lines = fixed.split('\n');
      final open = lines.indexWhere((l) => l.contains('writeInboxInstruction(['));
      final names = stringNamesIn(lines, 0, lines.length);
      final bad = valuesOfLiteral(lines, open)
          .where((v) => !isJsonSafe(v.expression, names))
          .toList();
      expect(bad, isEmpty, reason: 'Found: $bad');
    });
  });

  group('the caller set — the construction is "only these callers"', () {
    test('writeInboxInstruction has exactly two call sites', () {
      final callers = <String>[];
      for (var i = 0; i < app.length; i++) {
        final l = app[i];
        if (l.trimLeft().startsWith('//')) continue;
        if (!l.contains('writeInboxInstruction(')) continue;
        if (l.contains('private func writeInboxInstruction')) continue;
        callers.add('$appPath:${i + 1}: ${l.trim()}');
      }
      expect(callers, hasLength(2),
          reason: '⛔ A THIRD CALLER IS THE FAILURE MODE. The encode is safe '
              'only because every payload reaching it is built from String and '
              'NSNumber. A new caller must be checked by hand and added here '
              'deliberately. Found:\n${callers.join('\n')}');
    });
  });

  group('the payloads — every value is a JSON-safe shape', () {
    void checkLiteral({
      required String path,
      required List<String> lines,
      required int open,
      required int expectedPairs,
    }) {
      // Scope for String names: the enclosing function, taken generously as
      // the 40 lines above the literal. Over-wide is safe here — a wider scope
      // can only ADMIT more names, and every admitted name still had to be
      // bound to a String.
      final from = (open - 40).clamp(0, lines.length);
      final names = stringNamesIn(lines, from, open + 10);
      final values = valuesOfLiteral(lines, open);

      expect(values, hasLength(expectedPairs),
          reason: 'positive control: the extractor read all $expectedPairs '
              'pairs at $path:${open + 1}. A short read would make the check '
              'below silently narrower than it claims. Found: $values');

      final bad = values.where((v) => !isJsonSafe(v.expression, names)).toList();
      expect(bad, isEmpty,
          reason: '⛔ NOT A JSON-SAFE SHAPE. JSONSerialization.data returns nil '
              'for this payload, the try? swallows it, writeInboxInstruction '
              'returns silently, endedCleanly stays true so no preserve runs, '
              'the user is told the event ended with a duration, and both '
              'marker copies are deleted. The duration is destroyed.\n'
              'At $path: ${bad.join('\n')}\n'
              'String names in scope: $names');
    }

    test('writeInboxStart', () {
      final fn = app.indexWhere((l) => l.contains('func writeInboxStart'));
      expect(fn, isNot(-1), reason: 'positive control');
      final open = app.indexWhere((l) => l.contains('writeInboxInstruction(['), fn);
      checkLiteral(path: appPath, lines: app, open: open, expectedPairs: 4);
    });

    test('writeInboxEnd', () {
      final fn = app.indexWhere((l) => l.contains('func writeInboxEnd'));
      expect(fn, isNot(-1), reason: 'positive control');
      final open = app.indexWhere((l) => l.contains('writeInboxInstruction(['), fn);
      checkLiteral(path: appPath, lines: app, open: open, expectedPairs: 5);
    });

    test('EndMEREventIntent\'s inline copy', () {
      // Duplicated across the target boundary rather than shared, because
      // Runner and MERWidget are separate targets. Same rule applies to it.
      final open =
          intent.indexWhere((l) => l.contains('let payload: [String: Any] = ['));
      expect(open, isNot(-1), reason: 'positive control: the literal was found');
      checkLiteral(path: intentPath, lines: intent, open: open, expectedPairs: 5);
    });
  });

  group('the guard itself is still the shape this file reasons about', () {
    test('writeInboxInstruction still encodes under try? and returns silently',
        () {
      final fn =
          app.indexWhere((l) => l.contains('private func writeInboxInstruction'));
      expect(fn, isNot(-1), reason: 'positive control');
      final body = app.sublist(fn, fn + 8).join('\n');

      expect(body, contains('try? JSONSerialization.data(withJSONObject: payload)'),
          reason: 'if the encode stops being a silent try?, the reasoning in '
              'this file no longer describes the code, and the file should be '
              'revisited rather than left passing');
      expect(body, contains('else { return }'),
          reason: 'same: the silent return is the thing that makes a bad '
              'payload destroy a duration rather than crash');
    });
  });

  group('the Swift sources were actually read', () {
    test('positive control', () {
      expect(app.length, greaterThan(500), reason: _posix(appPath));
      expect(intent.length, greaterThan(100), reason: _posix(intentPath));
    });
  });
}
