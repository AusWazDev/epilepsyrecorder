import 'package:flutter/material.dart';

class MERIconWidget extends StatelessWidget {
  final double size;
  const MERIconWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MERIconPainter(),
    );
  }
}

class _MERIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color       = Colors.white
      ..strokeWidth = w * 0.1
      ..strokeCap   = StrokeCap.round
      ..strokeJoin  = StrokeJoin.round
      ..style       = PaintingStyle.stroke;

    // Clipboard body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.2, h * 0.28, w * 0.62, h * 0.62),
        Radius.circular(w * 0.1),
      ),
      strokePaint,
    );

    // Clip at top
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.17, w * 0.28, h * 0.14),
        Radius.circular(w * 0.07),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill,
    );

    // ECG line
    final ecg = Path()
      ..moveTo(w * 0.2,  h * 0.58)
      ..lineTo(w * 0.34, h * 0.58)
      ..lineTo(w * 0.42, h * 0.42)
      ..lineTo(w * 0.5,  h * 0.74)
      ..lineTo(w * 0.57, h * 0.5)
      ..lineTo(w * 0.63, h * 0.63)
      ..lineTo(w * 0.69, h * 0.58)
      ..lineTo(w * 0.82, h * 0.58);
    canvas.drawPath(ecg, strokePaint);

    // Coral cross — vertical
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.68, h * 0.3, w * 0.08, h * 0.22),
        Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFFE05B3A)
        ..style = PaintingStyle.fill,
    );

    // Coral cross — horizontal
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.6, h * 0.37, w * 0.24, h * 0.08),
        Radius.circular(2),
      ),
      Paint()
        ..color = const Color(0xFFE05B3A)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}