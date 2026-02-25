import 'package:flutter/material.dart';

const double kPersistentLogoTopPadding = 0;
const double kPersistentLogoCardPadding = 8;
const double kPersistentLogoImageHeight = 84;
const double kPersistentLogoBottomGap = 12;
const double kPersistentLogoClearance = kPersistentLogoTopPadding +
    (kPersistentLogoCardPadding * 2) +
    kPersistentLogoImageHeight +
    kPersistentLogoBottomGap;

class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.width = 220,
    this.height = 72,
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

class PersistentLogoOverlay extends StatelessWidget {
  const PersistentLogoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: kPersistentLogoTopPadding),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(kPersistentLogoCardPadding),
                child: AppLogo(
                  width: 300,
                  height: kPersistentLogoImageHeight,
                  borderRadius: 10,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
