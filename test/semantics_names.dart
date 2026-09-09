import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared readers for AUDIT.md §13(z)'s naming tests.
///
/// ⛔ ONE SCREEN PER TEST FILE, AND THAT IS NOT STYLE — IT IS A MEASURED
/// HARNESS DEFECT. Pumping several screens inside one `testWidgets` produced
/// FALSE NEGATIVES twice on 9 September 2026:
///
///   * "Your lists"' 69 checkboxes rendered as ZERO when the vocabulary screen
///     was the fourth pump; alone, 69.
///   * the form's `tooltip: 'Back'` reported SILENT as the third pump, while
///     the wizard's identical tooltip on the first pump was found; alone, the
///     form reports `[Back]`.
///
/// ⚠️ The cause was never established. What is established is the DIRECTION:
/// a later pump under-reports, so a SILENT verdict from a multi-screen test
/// cannot be trusted while an ANNOUNCED one can. That asymmetry is exactly the
/// shape of the prefs-per-process rule in `CLAUDE.md`, and the remedy is the
/// same one: isolate.

/// Every name a reader could hear: label OR tooltip, on any node.
///
/// ⚠️ ANCHORED ON `MaterialApp`, NOT ON THE SCREEN WIDGET. A screen widget need
/// not map to a semantics node of its own — `VocabularyScreen` does not — and
/// `getSemantics` throws rather than returning an empty set when it does not.
///
/// ⛔ TOOLTIP IS A SEPARATE FIELD FROM LABEL. A tooltip'd `IconButton` has an
/// EMPTY label and is still announced; reading `label` alone reports every one
/// of these four controls as unnamed.
Set<String> announcedNames(WidgetTester tester) {
  var root = tester.getSemantics(find.byType(MaterialApp));
  while (root.parent != null) {
    root = root.parent!;
  }
  final out = <String>{};
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.label.trim().isNotEmpty) out.add(d.label.trim());
    if (d.tooltip.trim().isNotEmpty) out.add(d.tooltip.trim());
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(root);
  return out;
}

/// Rects of the named icons, in paint order — the geometry a `tooltip:` must
/// not move.
List<String> iconRects(WidgetTester tester, List<IconData> icons) {
  final out = <String>[];
  for (final e in tester.allElements) {
    final w = e.widget;
    final ro = e.renderObject;
    if (ro is! RenderBox || !ro.hasSize) continue;
    if (w is! Icon || !icons.contains(w.icon)) continue;
    final r = ro.localToGlobal(Offset.zero) & ro.size;
    out.add('${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)} '
        '${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}');
  }
  return out;
}
