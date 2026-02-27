import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width = 400,
    this.height = 130,
    this.borderRadius = 10,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.asset(
        'image/logo.png',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            Icon(Icons.school_outlined, size: height * 0.85),
      ),
    );
  }
}
