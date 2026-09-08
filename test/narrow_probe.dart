import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared instrument for AUDIT.md §13(as) — WHAT raises the framework exception
/// at narrow widths, on WHICH screen, at WHICH width, and on WHICH platform.
///
/// ⛔ WHY THIS FILE EXISTS AT ALL. §13(as) was measured on 8 September 2026 by a
/// throwaway test that was never saved. Only its stdout survives, quoted in the
/// document — so the finding was not reproducible from the repository, and
/// re-deriving it was the first thing this diagnosis had to do. Anything that
/// produces a recorded figure lives in `test/` from now on.
///
/// ⭐ THE PROBE CAPTURES `FlutterErrorDetails`, NOT `takeException()`.
/// `takeException()` returns the exception object only — no library, no context,
/// no stack — and §13(as) records that "the exception type and message are
/// UNKNOWN and were not looked at" precisely because presence was all that was
/// ever read. Overriding `FlutterError.onError` intercepts the details BEFORE
/// the test binding records them, which also stops the sweep failing the test.
///
/// ⚠️ `debugDefaultTargetPlatformOverride` is reset INLINE, never via
/// `addTearDown` — the framework asserts "the value of a foundation debug
/// variable was changed by the test" when a tear-down does it.

/// One measurement at one width, on one platform, at one device pixel ratio.
class Probe {
  Probe({
    required this.platform,
    required this.dpr,
    required this.logicalW,
    required this.logicalH,
    required this.errors,
    required this.overflowingTexts,
    required this.widestText,
  });

  final TargetPlatform platform;
  final double dpr;
  final double logicalW;
  final double logicalH;

  /// Every `FlutterErrorDetails` raised during pump and settle, in order.
  final List<FlutterErrorDetails> errors;

  /// `RenderParagraph`s whose text painter exceeded its line budget — the
  /// CONTENT-degradation signal, which is a different thing from an exception.
  final int overflowingTexts;

  /// Widest laid-out paragraph, for reading how content responds to the width.
  final double widestText;

  bool get threw => errors.isNotEmpty;

  /// Distinct `exception.runtimeType` names, so two different faults at two
  /// widths cannot be read as one finding.
  Set<String> get types => errors.map((e) => e.exception.runtimeType.toString()).toSet();

  /// First line of each exception, which is what identifies a RenderFlex
  /// overflow's owning widget without asserting that is what it is.
  List<String> get firstLines => errors
      .map((e) => e.exception.toString().split('\n').first.trim())
      .toList();
}

/// Pumps [build] at [logicalW] x [logicalH] logical points on [platform] at
/// [dpr], and reports what the framework raised.
Future<Probe> probeAt(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double dpr,
  required double logicalW,
  required double logicalH,
  required Widget Function() build,
}) async {
  final captured = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = captured.add;
  debugDefaultTargetPlatformOverride = platform;

  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logicalW * dpr, logicalH * dpr);

  var overflowing = 0;
  var widest = 0.0;
  try {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    for (final e in tester.allElements) {
      final ro = e.renderObject;
      if (ro is RenderParagraph) {
        if (ro.didExceedMaxLines) overflowing++;
        if (ro.hasSize && ro.size.width > widest) widest = ro.size.width;
      }
    }
  } catch (error, stack) {
    // A throw that escapes pump is recorded rather than failing the sweep, so
    // the width at which it starts is still measurable.
    captured.add(FlutterErrorDetails(exception: error, stack: stack));
  }

  // ⛔ Both resets inline. Order matters only in that neither may be deferred.
  FlutterError.onError = previous;
  debugDefaultTargetPlatformOverride = null;

  return Probe(
    platform: platform,
    dpr: dpr,
    logicalW: logicalW,
    logicalH: logicalH,
    errors: captured,
    overflowingTexts: overflowing,
    widestText: widest,
  );
}

/// Descending coarse sweep, then a bisection of the transition, so the reported
/// threshold is measured rather than picked off a round number.
///
/// Returns `(highestClean, lowestFailing)` for [predicate]; either may be null
/// when the predicate never flips inside the swept range, which is itself the
/// result and must not be reported as a threshold.
Future<(double?, double?)> findThreshold(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double dpr,
  required double logicalH,
  required Widget Function() build,
  required bool Function(Probe) predicate,
  required String label,
  double from = 1200,
  double to = 90,
  double coarseStep = 50,
}) async {
  double? clean;
  double? failing;

  for (var w = from; w >= to; w -= coarseStep) {
    final p = await probeAt(tester,
        platform: platform, dpr: dpr, logicalW: w, logicalH: logicalH, build: build);
    final bad = predicate(p);
    // ignore: avoid_print
    print('  SWEEP $label ${platform.name} dpr=$dpr w=${w.toStringAsFixed(0)} '
        'bad=$bad errors=${p.errors.length} overflow=${p.overflowingTexts} '
        'widestText=${p.widestText.toStringAsFixed(0)} '
        'types=${p.types.join("|")}');
    if (bad) {
      failing = w;
      break; // sweeping DOWN: the first failure, bracketed by the last clean width
    }
    clean = w;
  }

  if (clean == null || failing == null) return (clean, failing);

  // Bisect to 2 logical points.
  var lo = clean, hi = failing;
  while ((lo - hi).abs() > 2) {
    final mid = ((lo + hi) / 2).roundToDouble();
    final p = await probeAt(tester,
        platform: platform, dpr: dpr, logicalW: mid, logicalH: logicalH, build: build);
    if (predicate(p)) {
      hi = mid;
    } else {
      lo = mid;
    }
  }

  // ⛔ MONOTONICITY IS AN ASSUMPTION. Bisection is only valid if the
  // predicate flips once. Both endpoints are re-probed so a non-monotonic
  // predicate shows up as a contradictory bracket rather than a clean number.
  final vLo = await probeAt(tester,
      platform: platform, dpr: dpr, logicalW: lo, logicalH: logicalH, build: build);
  final vHi = await probeAt(tester,
      platform: platform, dpr: dpr, logicalW: hi, logicalH: logicalH, build: build);
  // ignore: avoid_print
  print('  BRACKET-CHECK $label ${platform.name} dpr=$dpr '
      'lo=${lo.toStringAsFixed(0)} bad=${predicate(vLo)} (want false)  '
      'hi=${hi.toStringAsFixed(0)} bad=${predicate(vHi)} (want true)');
  return (lo, hi);
}

/// Full dump of one error, used once per distinct fault rather than per width.
void dumpError(String where, FlutterErrorDetails d) {
  // ignore: avoid_print
  print('''

======== EXCEPTION DETAIL — $where
  type      : ${d.exception.runtimeType}
  library   : ${d.library}
  context   : ${d.context}
  message   :
${d.exception.toString().split('\n').map((l) => '    $l').join('\n')}
  information (this is where the OWNING WIDGET is named):
${(d.informationCollector?.call() ?? const <DiagnosticsNode>[]).map((n) => '    ${n.toStringDeep().split('\n').join('\n    ')}').join('\n')}
  stack (first 18 frames):
${(d.stack?.toString().split('\n').take(18) ?? const <String>[]).map((l) => '    $l').join('\n')}
========''');
}
