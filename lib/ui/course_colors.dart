import 'package:flutter/cupertino.dart';

/// 课程配色板。糖果色系 — 作为课程块实底,配白字看着亮而不糊。
/// 相邻色相间隔 30° 左右,各色明度控制在 55-70% 之间,避免深黄/深褐糊成一团。
class CourseColors {
  /// (bg, accent) — bg 保留(详情页仍用作浅底),accent 现在直接作为课程块实底。
  static const List<(Color, Color)> palettes = [
    (Color(0xFFE8EEFF), Color(0xFF5B8DEE)), // 天空蓝
    (Color(0xFFFDE4EC), Color(0xFFEE6B89)), // 珊瑚粉
    (Color(0xFFE3F4EA), Color(0xFF52B35A)), // 春绿
    (Color(0xFFFFEFD9), Color(0xFFFF9B52)), // 暖橙
    (Color(0xFFF0E6FA), Color(0xFFA569D1)), // 薰衣草紫
    (Color(0xFFDEF3F8), Color(0xFF42B6C6)), // 薄荷青
    (Color(0xFFFFE6E1), Color(0xFFE66A6A)), // 柿红
    (Color(0xFFEDF4DE), Color(0xFF93BB4F)), // 鳄梨绿
    (Color(0xFFEDE7F6), Color(0xFF8877D0)), // 紫藤
    (Color(0xFFFFF4CC), Color(0xFFDDB54A)), // 蜂蜜黄
    (Color(0xFFD9EFFF), Color(0xFF5BAFE1)), // 湖蓝
    (Color(0xFFFDE4D4), Color(0xFFDD7F4D)), // 橘褐
  ];

  static (Color bg, Color accent) pick(int index) {
    final p = palettes[index.abs() % palettes.length];
    return (p.$1, p.$2);
  }

  /// 稳定哈希。Dart 的 String.hashCode 在不同进程里不保证一致,
  /// 而且相近字符串常常落到相邻的桶里。这里用 FNV-1a 32 位。
  static int stableIndex(String key) {
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
