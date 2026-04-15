import 'package:flutter/material.dart';

class MERIconWidget extends StatelessWidget {
  final double size;
  const MERIconWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/app_icon.png',
      width:         size,
      height:        size,
      filterQuality: FilterQuality.high,
    );
  }
}
