import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/mer_theme.dart';

/// How many rows of chips a COLLAPSED picker shows.
///
/// ⛔ **THE CAP IS THE WHOLE POINT, so it is named rather than typed at three
/// call sites.** The vocabulary is user-extensible by design: nothing bounds
/// how many entries a picker holds, and an unbounded picker sits UPSTREAM of
/// fields that must be reachable. Measured on an iPhone 15 Pro Max, the 34
/// seeded observations take **19 rows**, which put "Rescue medication given?"
/// 527pt below the fold and "Notes" 787pt below it. On an iPhone 8 the same
/// list is 22 rows and the rescue question is 887pt down.
///
/// Three rows is a bound, not a guess at what fits: the height of a collapsed
/// picker is now `3 * rowHeight + disclosure` no matter how large the
/// vocabulary grows. Six user-added entries took step 4 from 19 rows to 22
/// before this existed — a 32% deterioration with nothing seeded by MER.
///
/// ⚠️ Three rows is only defensible BECAUSE the head of the list is ranked.
/// Usage ordering and condition relevance mean the first rows are the likely
/// answers rather than an arbitrary prefix. If that ranking is ever removed
/// this cap becomes plain truncation and must be revisited with it.
const int kCollapsedChipRows = 3;

/// A chip [Wrap] whose collapsed height is BOUNDED, with a counted disclosure.
///
/// ## What it does that `Wrap` cannot
///
/// A `Wrap` is as tall as its content. That is correct for a fixed list and
/// wrong for a vocabulary the user can extend, because everything BELOW the
/// wrap moves down every time the list grows. This lays out identically to
/// `Wrap` and then draws only the first [maxRows] rows until it is expanded.
///
/// ## ⛔ SELECTED CHIPS ARE NEVER DROPPED
///
/// The cap governs UNSELECTED rows. A chip marked pinned renders wherever it
/// falls in the order, even past the cap, so a record that already carries
/// nine observations shows all nine. This is the same rule the wizard's
/// orphan chips already relied on — a value that is SELECTED must be visible,
/// because a picker that hides a recorded answer makes the edit path lie
/// about what the record contains. Growing past three rows is the correct
/// outcome there: the height is bounded by what is unanswered, not by what
/// has been answered.
///
/// The "add your own" pill is pinned for the same reason — it is an action,
/// not an entry, and collapsing must not put it out of reach.
///
/// ## ⚠️ THE PILL COSTS A ROW, AND A WIDGET TEST WILL TELL YOU IT DOES NOT
///
/// A collapsed picker is **3 chip rows + an add row + the disclosure**, not
/// three rows. The pill is pinned, so once three rows are full it wraps onto a
/// fourth. The projection for this change costed it at zero and was ~165pt
/// optimistic per surface on the single-page form as a result.
///
/// ⛔ **The first measurement run AGREED with the projection, and that is the
/// part worth remembering.** The form gates its pill on
/// [Vocabularies.canPersist], which is `_db != null` — and a widget test has no
/// database, so the pill was not merely mis-costed, it was ABSENT from the
/// screen being measured. The run reported a layout the device never renders.
///
/// Same class as the shared fixture in `catch_all_last_test` that read 32 rows
/// where it had created 2: an environment that differs from the real one,
/// returning a number that looks like a result. **Anything measuring this
/// layout for a real-device claim must set a database first** — the corrected
/// run does, via `Vocabularies.debugSet(db: ...)` over an in-memory sqflite.
class BoundedChipWrap extends StatefulWidget {
  /// The chips, in the order they should read.
  final List<Widget> chips;

  /// Parallel to [chips]. True means ALWAYS RENDER — see the class comment.
  final List<bool> pinned;

  /// How many entries the picker offers, for the disclosure line. Passed
  /// rather than derived because [chips] also carries the add pill, which is
  /// an action and must not be counted as something to choose from.
  final int totalCount;

  /// How many of those are selected, for the disclosure line.
  final int selectedCount;

  final double spacing;
  final double runSpacing;
  final int maxRows;

  const BoundedChipWrap({
    super.key,
    required this.chips,
    required this.pinned,
    required this.totalCount,
    required this.selectedCount,
    this.spacing = 8,
    this.runSpacing = 8,
    this.maxRows = kCollapsedChipRows,
  }) : assert(chips.length == pinned.length,
            'pinned must be parallel to chips');

  @override
  State<BoundedChipWrap> createState() => _BoundedChipWrapState();
}

class _BoundedChipWrapState extends State<BoundedChipWrap> {
  bool _expanded = false;

  /// Whether anything is actually being withheld.
  ///
  /// Reported UP from layout, because whether 34 chips overflow three rows
  /// depends on the width they are given — they do on every phone and do not
  /// on a wide Windows window. Offering "Show all" over a list that is
  /// already entirely visible is the same defect as hiding the count.
  bool _truncated = false;

  void _onTruncated(bool value) {
    if (_truncated == value || !mounted) return;
    setState(() => _truncated = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BoundedWrap(
          pinned: widget.pinned,
          expanded: _expanded,
          maxRows: widget.maxRows,
          spacing: widget.spacing,
          runSpacing: widget.runSpacing,
          onTruncated: _onTruncated,
          children: widget.chips,
        ),
        if (_truncated || _expanded)
          _disclosure(
            expanded: _expanded,
            total: widget.totalCount,
            selected: widget.selectedCount,
            onTap: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}

/// The disclosure row. Deliberately the same shape as the retired-vocabulary
/// toggle on "Your lists": a chevron, a MUTED COUNT, and an action word.
///
/// ⛔ **THE COUNT IS STATED IN BOTH STATES**, which is the rule that answers
/// "does a collapsed picker read as empty". A closed picker showing three
/// rows and nothing else invites the reading that three is all there is.
/// "34 to choose from" cannot be read that way, and once something is chosen
/// "2 of 34 selected" says the same thing about a picker that is now partly
/// answered. There is no state in which this row is silent about size.
Widget _disclosure({
  required bool expanded,
  required int total,
  required int selected,
  required VoidCallback onTap,
}) {
  final count = selected == 0
      ? '$total to choose from'
      : '$selected of $total selected';
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(expanded ? Icons.expand_less : Icons.expand_more,
              size: 20, color: MERColours.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(count,
                style: const TextStyle(
                    fontSize: 14, color: MERColours.textMuted)),
          ),
          Text(expanded ? 'Show fewer' : 'Show all',
              style:
                  const TextStyle(fontSize: 14, color: MERColours.action)),
        ],
      ),
    ),
  );
}

/* ===========================
   LAYOUT
   =========================== */

class BoundedWrapParentData extends ContainerBoxParentData<RenderBox> {
  bool visible = true;
}

class BoundedWrap extends MultiChildRenderObjectWidget {
  final List<bool> pinned;
  final bool expanded;
  final int maxRows;
  final double spacing;
  final double runSpacing;
  final ValueChanged<bool> onTruncated;

  const BoundedWrap({
    super.key,
    required super.children,
    required this.pinned,
    required this.expanded,
    required this.maxRows,
    required this.spacing,
    required this.runSpacing,
    required this.onTruncated,
  });

  @override
  RenderBoundedWrap createRenderObject(BuildContext context) =>
      RenderBoundedWrap(
        pinned: pinned,
        expanded: expanded,
        maxRows: maxRows,
        spacing: spacing,
        runSpacing: runSpacing,
        onTruncated: onTruncated,
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderBoundedWrap renderObject) {
    renderObject
      ..pinned = pinned
      ..expanded = expanded
      ..maxRows = maxRows
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..onTruncated = onTruncated;
  }
}

class RenderBoundedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, BoundedWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, BoundedWrapParentData> {
  RenderBoundedWrap({
    required List<bool> pinned,
    required bool expanded,
    required int maxRows,
    required double spacing,
    required double runSpacing,
    required this.onTruncated,
  })  : _pinned = pinned,
        _expanded = expanded,
        _maxRows = maxRows,
        _spacing = spacing,
        _runSpacing = runSpacing;

  ValueChanged<bool> onTruncated;

  List<bool> _pinned;
  set pinned(List<bool> v) {
    if (listEquals(_pinned, v)) return;
    _pinned = v;
    markNeedsLayout();
  }

  bool _expanded;
  set expanded(bool v) {
    if (_expanded == v) return;
    _expanded = v;
    markNeedsLayout();
  }

  int _maxRows;
  set maxRows(int v) {
    if (_maxRows == v) return;
    _maxRows = v;
    markNeedsLayout();
  }

  double _spacing;
  set spacing(double v) {
    if (_spacing == v) return;
    _spacing = v;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double v) {
    if (_runSpacing == v) return;
    _runSpacing = v;
    markNeedsLayout();
  }

  bool _lastTruncated = false;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! BoundedWrapParentData) {
      child.parentData = BoundedWrapParentData();
    }
  }

  /// Test seam: WHICH CHIPS ARE ACTUALLY DRAWN, in order.
  ///
  /// Hidden children stay in the tree — they must be laid out to know which
  /// row they would occupy — so `find.text` alone cannot tell a shown chip
  /// from a withheld one. Tests assert against this, and against hit-testing.
  @visibleForTesting
  List<bool> get childVisibility => [
        for (final c in _children)
          (c.parentData! as BoundedWrapParentData).visible
      ];

  List<RenderBox> get _children {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  /// Which wrap row each child falls in IF EVERYTHING IS SHOWN.
  ///
  /// The decision has to be made against the full list: a chip is kept because
  /// of the row it would occupy in the complete layout, not the row it happens
  /// to land in once earlier chips have been removed. Deciding against the
  /// reflowed list would let hidden chips pull later ones up into the cap.
  List<int> _rowsOf(List<Size> sizes, double maxW) {
    final rows = <int>[];
    double x = 0;
    var row = 0;
    for (final s in sizes) {
      if (x > 0 && x + s.width > maxW) {
        row++;
        x = 0;
      }
      rows.add(row);
      x += s.width + _spacing;
    }
    return rows;
  }

  @override
  void performLayout() {
    final kids = _children;
    final maxW = constraints.maxWidth;

    if (kids.isEmpty) {
      size = constraints.constrain(Size.zero);
      _report(false);
      return;
    }

    final inner = BoxConstraints(maxWidth: maxW);
    final sizes = <Size>[];
    for (final k in kids) {
      k.layout(inner, parentUsesSize: true);
      sizes.add(k.size);
    }

    final rows = _rowsOf(sizes, maxW);
    var truncated = false;

    double x = 0, y = 0, rowH = 0;
    for (var i = 0; i < kids.length; i++) {
      final pd = kids[i].parentData! as BoundedWrapParentData;
      final show = _expanded ||
          rows[i] < _maxRows ||
          (i < _pinned.length && _pinned[i]);
      pd.visible = show;
      if (!show) {
        truncated = true;
        continue;
      }
      final s = sizes[i];
      if (x > 0 && x + s.width > maxW) {
        x = 0;
        y += rowH + _runSpacing;
        rowH = 0;
      }
      pd.offset = Offset(x, y);
      x += s.width + _spacing;
      rowH = math.max(rowH, s.height);
    }

    size = constraints.constrain(Size(maxW, y + rowH));
    _report(truncated);
  }

  /// ⚠️ Deferred to a post-frame callback ON PURPOSE. This is discovered
  /// during layout, and the listener rebuilds to add or remove the disclosure
  /// row — calling setState inside performLayout is illegal.
  void _report(bool truncated) {
    if (_lastTruncated == truncated) return;
    _lastTruncated = truncated;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      onTruncated(truncated);
    });
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final kids = _children;
    if (kids.isEmpty) return constraints.constrain(Size.zero);
    final maxW = constraints.maxWidth;
    final inner = BoxConstraints(maxWidth: maxW);
    final sizes = [for (final k in kids) k.getDryLayout(inner)];
    final rows = _rowsOf(sizes, maxW);

    double x = 0, y = 0, rowH = 0;
    for (var i = 0; i < kids.length; i++) {
      final show = _expanded ||
          rows[i] < _maxRows ||
          (i < _pinned.length && _pinned[i]);
      if (!show) continue;
      final s = sizes[i];
      if (x > 0 && x + s.width > maxW) {
        x = 0;
        y += rowH + _runSpacing;
        rowH = 0;
      }
      x += s.width + _spacing;
      rowH = math.max(rowH, s.height);
    }
    return constraints.constrain(Size(maxW, y + rowH));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var c = firstChild;
    while (c != null) {
      final pd = c.parentData! as BoundedWrapParentData;
      if (pd.visible) context.paintChild(c, pd.offset + offset);
      c = childAfter(c);
    }
  }

  /// ⛔ Hidden chips must not be TAPPABLE. Skipping them in paint alone would
  /// leave an invisible chip that still toggles a value.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var c = lastChild;
    while (c != null) {
      final pd = c.parentData! as BoundedWrapParentData;
      if (pd.visible) {
        final hit = result.addWithPaintOffset(
          offset: pd.offset,
          position: position,
          hitTest: (r, p) => c!.hitTest(r, position: p),
        );
        if (hit) return true;
      }
      c = childBefore(c);
    }
    return false;
  }
}
