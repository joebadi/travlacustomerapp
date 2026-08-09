import 'package:flutter/material.dart';

class TravlaLogo extends StatelessWidget {
  const TravlaLogo({super.key, this.onDark = false, this.width = 150});

  final bool onDark;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark
          ? 'assets/brand/travla-logo-white.png'
          : 'assets/brand/travla-logo-green.png',
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Travla',
    );
  }
}
