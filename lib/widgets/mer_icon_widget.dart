import 'package:flutter/material.dart';

/// The app icon, rendered as its own badge.
///
/// The artwork is a full-bleed blue field with a ~20.5% corner radius, so it is
/// already a badge. It was previously wrapped in a translucent-white rounded
/// container at every call site, which put a rounded tile inside a rounded tile
/// and shrank the icon to roughly 62% of the space available. Combined with the
/// artwork's own padding that left the visible glyph at about 37% of the
/// footprint. The wrapper is gone; this renders at full size.
///
/// The remaining inset is in the asset and is NOT a defect: the glyph occupies
/// 58.8% of the canvas width because `assets/Blue_background_without_MER.png`
/// is also the source `flutter_launcher_icons` generates from, and a launcher
/// icon needs that safe-area padding. Going beyond 58.8% requires a
/// purpose-cut inline asset, not a layout change.
class MERIconWidget extends StatelessWidget {
  /// How far the glyph's optical centre sits above the canvas centre, as a
  /// fraction of the canvas height.
  ///
  /// Measured on the asset: the glyph occupies rows 144-785 of 1024, so its
  /// centre is row 464.5 against a canvas centre of 511.5 — 47px, or 4.59%,
  /// high. Centring the asset box therefore centres the padding rather than the
  /// artwork, and the icon reads as sitting too high.
  ///
  /// Corrected in the layout rather than the artwork, deliberately: the asset
  /// is a source for the launcher and notification icons, and editing it would
  /// silently change both.
  ///
  /// Applied as a fraction of [size], so it scales across the 28px header and
  /// the 100px splash alike instead of being a fixed nudge tuned to one of them.
  /// The shift is far smaller than the artwork's 23.2% bottom padding, so no
  /// glyph pixel can fall outside the box even where a parent clips.
  static const double _opticalCentreOffset = 0.0459;

  final double size;

  const MERIconWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  size,
      height: size,
      child: Transform.translate(
        // Transform does not affect layout, so the widget still measures
        // exactly `size` and surrounding spacing is unchanged.
        offset: Offset(0, size * _opticalCentreOffset),
        child: Image.asset(
          'assets/Blue_background_without_MER.png',
          width:         size,
          height:        size,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
