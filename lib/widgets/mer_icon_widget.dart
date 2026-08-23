import 'package:flutter/material.dart';

/// Which cut of the app artwork to draw.
enum MERIconStyle {
  /// Blue plate with the white glyph on it — the launcher-icon cut.
  ///
  /// Correct on a light surface. **Wrong on a blue one:** the plate is
  /// `MERColours.primary`, the same colour as the AppBar, the About hero and the
  /// splash, so the badge vanishes into the background and only the glyph shows
  /// faintly. At 30px that reads as a smudge rather than a logo.
  badge,

  /// The glyph alone on transparency — a white mark.
  ///
  /// For blue surfaces. Same artwork as [badge] with the plate removed, so a
  /// white mark on navy rather than navy on navy.
  mark,
}

/// The app icon.
///
/// Two problems were fixed in sequence here, and the history is worth keeping
/// because the first fix is what exposed the second.
///
/// Originally every call site wrapped this in a translucent-white rounded
/// container, which put a rounded tile inside a rounded tile and left the
/// visible glyph at roughly 37% of the footprint. Removing the wrapper raised
/// that to 58.8% — and revealed that the asset is a *blue* badge being placed on
/// *blue*. Hence [MERIconStyle], and hence the four blue surfaces now asking for
/// [MERIconStyle.mark].
///
/// The remaining 41% padding is not a defect: both assets are sources for
/// `flutter_launcher_icons`, and a launcher icon needs that safe area. On a
/// transparent cut the padding is invisible, but it still occupies layout, so
/// [size] is the footprint and the visible mark is 58.79% of it. Size for the
/// mark you want to see, not for the box.
class MERIconWidget extends StatelessWidget {
  /// How far the glyph's optical centre sits above the canvas centre, as a
  /// fraction of the canvas height.
  ///
  /// The glyph occupies rows 144-785 of 1024 in **both** cuts — measured, not
  /// assumed — so its centre is row 464.5 against a canvas centre of 511.5:
  /// 47px, or 4.59%, high. One constant therefore covers both styles; it does
  /// not need to become asset-dependent.
  ///
  /// Corrected in the layout rather than the artwork, deliberately: the assets
  /// are launcher-icon sources and editing either would silently change the
  /// launcher and notification icons.
  ///
  /// Applied as a fraction of [size] so it scales across a 40px header and a
  /// 140px splash alike. The shift is far smaller than the artwork's 23.24%
  /// bottom padding, so no glyph pixel can leave the box even where a parent
  /// clips.
  static const double _opticalCentreOffset = 0.0459;

  static const Map<MERIconStyle, String> _assets = <MERIconStyle, String>{
    MERIconStyle.badge: 'assets/Blue_background_without_MER.png',
    MERIconStyle.mark:  'assets/Transparent_without_MER.png',
  };

  /// The footprint. The visible mark is 58.79% of this.
  final double size;

  /// Defaults to [MERIconStyle.badge] — the cut that is visible on any
  /// background. A default of [MERIconStyle.mark] would make a future use on a
  /// light surface silently invisible, which is the worse failure.
  final MERIconStyle style;

  const MERIconWidget({
    super.key,
    this.size = 20,
    this.style = MERIconStyle.badge,
  });

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
          _assets[style]!,
          width:         size,
          height:        size,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
