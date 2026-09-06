import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

/// Liquid Glass 胶囊容器。顶部 TopBar 和底部 Tab Bar 共用样式。
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.child,
    this.radius = 24,
    this.sigma = 30,
  });

  final Widget child;
  final double radius;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final pillBg = isDark
        ? const Color(0x66FFFFFF).withValues(alpha: 0.16)
        : const Color(0x80FFFFFF).withValues(alpha: 0.55);
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.white.withValues(alpha: 0.55);
    final shadowColor =
        CupertinoColors.black.withValues(alpha: isDark ? 0.45 : 0.12);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
