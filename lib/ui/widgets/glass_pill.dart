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
        ? CupertinoColors.systemGrey6.darkColor.withValues(alpha: 0.92)
        : CupertinoColors.white.withValues(alpha: 0.94);
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : const Color(0xFF3C3C43).withValues(alpha: 0.18);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
