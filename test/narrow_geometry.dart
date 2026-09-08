import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geometry instrument for AUDIT.md §13(as) and decision D2's threshold.
///
/// ⛔ WHY THIS REPLACES THE EXCEPTION-BASED PROBE, and it is the whole lesson of
/// this pass. `narrow_probe.dart` measured whether a `FlutterError` was raised.
/// Measured 8 September 2026 on home at 400 logical:
///
///     PASS 1  errors=1  constraint<=328.0  size=328.0  childrenTotal=336.0
///     PASS 2  errors=0  constraint<=328.0  size=328.0  childrenTotal=336.0
///
/// ⭐ IDENTICAL GEOMETRY. AN 8 px OVERFLOW IN BOTH PASSES. Only the REPORT
/// differed, because `RenderFlex` reports an overflow ONCE per render-object
/// instance per process, and `pumpWidget` reuses the instance across pumps.
///
/// ⛔ SO "the exception fires at 400 and not later" was never a fact about the
/// layout. A sweep predicated on `threw` reported every width from 1200 down to
/// 100 as clean, because the report had already been consumed by an earlier
/// probe. **The instrument measured a debug flag and was read as measuring the
/// layout** — the same shape as a count that reads as assurance while measuring
/// something adjacent.
///
/// ⭐ THE MEASURABLE QUANTITY IS `childrenTotal - constraints.maxWidth`. It is
/// available in every frame, at every width, with no once-per-process state.
///
/// ⚠️ AND NOTE WHAT THE OLD PROBE'S OTHER SIGNAL WAS DOING: `overflowingTexts`
/// counted `RenderParagraph`s exceeding their line budget, and stayed at 0
/// throughout — correctly, because this is a `RenderFlex` overflow, not a text
/// overflow. §13(am)'s "zero overflowing texts at 400" was TRUE and was read as
/// "nothing overflows at 400", which is false. Two different detectors.

/// One overflowing flex, with enough identity to name the owner.
class FlexOverflow {
  FlexOverflow(this.owner, this.axis, this.available, this.wanted);

  /// Leading segment of the creator chain — the widget that owns it.
  final String owner;
  final Axis axis;
  final double available;
  final double wanted;

  double get px => wanted - available;

  @override
  String toString() =>
      '${px.toStringAsFixed(1)}px ${axis.name} avail=${available.toStringAsFixed(1)} '
      'wanted=${wanted.toStringAsFixed(1)} owner=$owner';
}

class Geometry {
  Geometry({
    required this.logicalW,
    required this.overflows,
    required this.overflowingTexts,
    required this.widestText,
    required this.swallowed,
    required this.paragraphs,
  });

  final double logicalW;

  /// Every horizontal `RenderFlex` whose children exceed the incoming
  /// constraint, worst first.
  final List<FlexOverflow> overflows;

  /// `RenderParagraph`s past their line budget — a DIFFERENT detector, kept so
  /// the two can never again be conflated.
  final int overflowingTexts;
  final double widestText;

  /// Errors intercepted during pump. A non-zero count with an EMPTY tree is a
  /// false clean, not a clean -- nothing was laid out, so nothing overflowed.
  final int swallowed;

  /// Total RenderParagraphs laid out. ZERO means the screen produced no
  /// measurable content and the width's verdict is VOID rather than clean.
  final int paragraphs;

  bool get flexOverflowed => overflows.isNotEmpty;
  double get worstPx => overflows.isEmpty ? 0 : overflows.first.px;
}

String _owner(RenderObject ro) {
  final s = ro.debugCreator?.toString() ?? '?';
  final chain = s.replaceFirst('debugCreator: ', '').split(' ← ');
  return chain.take(3).join(' < ');
}

/// Pumps [build] at [logicalW] and measures flex overflow geometrically.
///
/// ⚠️ A FRESH WIDGET TREE PER CALL. `key` is varied so the element tree is
/// rebuilt rather than reused — otherwise render objects persist across widths
/// and a stale layout can be measured. This does NOT affect the once-per-object
/// report (which is why geometry, not the report, is what is read).
Future<Geometry> measureAt(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double dpr,
  required double logicalW,
  required double logicalH,
  required Widget Function() build,
}) async {
  final swallowed = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = swallowed.add;
  debugDefaultTargetPlatformOverride = platform;

  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(logicalW * dpr, logicalH * dpr);

  final found = <FlexOverflow>[];
  var overflowingTexts = 0;
  var widest = 0.0;
  var paragraphs = 0;

  try {
    // A distinct key per width forces a rebuild rather than a relayout of
    // reused render objects.
    await tester.pumpWidget(
        KeyedSubtree(key: ValueKey('w$logicalW-${platform.name}-$dpr'), child: build()));
    await tester.pumpAndSettle();

    for (final e in tester.allElements) {
      final ro = e.renderObject;
      if (ro is RenderFlex && ro.direction == Axis.horizontal && ro.hasSize) {
        var total = 0.0;
        var child = ro.firstChild;
        while (child != null) {
          if (child.hasSize) total += child.size.width;
          child = ro.childAfter(child);
        }
        final avail = ro.constraints.maxWidth;
        if (avail.isFinite && total > avail + 0.01) {
          found.add(FlexOverflow(_owner(ro), Axis.horizontal, avail, total));
        }
      }
      if (ro is RenderParagraph) {
        paragraphs++;
        if (ro.didExceedMaxLines) overflowingTexts++;
        if (ro.hasSize && ro.size.width > widest) widest = ro.size.width;
      }
    }
  } catch (error, stack) {
    swallowed.add(FlutterErrorDetails(exception: error, stack: stack));
  }

  FlutterError.onError = previous;
  debugDefaultTargetPlatformOverride = null;

  found.sort((a, b) => b.px.compareTo(a.px));
  return Geometry(
    logicalW: logicalW,
    overflows: found,
    overflowingTexts: overflowingTexts,
    widestText: widest,
    swallowed: swallowed.length,
    paragraphs: paragraphs,
  );
}

/// Descending sweep at [step], reporting the widest width that overflows and
/// the narrowest that does not. Geometry is monotone in practice but the
/// bracket is re-checked rather than assumed.
Future<void> sweep(
  WidgetTester tester, {
  required String screen,
  required TargetPlatform platform,
  required double dpr,
  required double logicalH,
  required Widget Function() build,
  double from = 1300,
  double to = 90,
  double step = 25,
}) async {
  double? lastClean;
  double? firstOverflow;
  final owners = <String>{};

  for (var w = from; w >= to; w -= step) {
    final g = await measureAt(tester,
        platform: platform, dpr: dpr, logicalW: w, logicalH: logicalH, build: build);
    if (g.flexOverflowed) {
      firstOverflow ??= w;
      for (final o in g.overflows) {
        owners.add(o.owner);
      }
    } else {
      lastClean = w;
    }
    // ignore: avoid_print
    print('  GEO $screen ${platform.name} dpr=$dpr w=${w.toStringAsFixed(0)} '
        'flexOverflow=${g.flexOverflowed} worst=${g.worstPx.toStringAsFixed(1)}px '
        'n=${g.overflows.length} texts=${g.overflowingTexts} '
        'paras=${g.paragraphs} swallowed=${g.swallowed} '
        '${g.paragraphs == 0 ? "VOID(nothing-laid-out) " : ""}'
        '${g.overflows.isEmpty ? "" : g.overflows.first.owner}');
  }

  // ignore: avoid_print
  print('  ==> $screen ${platform.name} dpr=$dpr  '
      'widest OVERFLOWING=${firstOverflow?.toStringAsFixed(0) ?? "none in range"}  '
      'narrowest CLEAN=${lastClean?.toStringAsFixed(0) ?? "none in range"}  '
      'owners={${owners.join(", ")}}');
}
