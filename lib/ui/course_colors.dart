import 'package:flutter/cupertino.dart';

/// 课程配色板。浅色背景 + 深色强调条/文字,保证在白底、暗底都看得清。
/// 颜色之间保持色相 30° 左右的间距,相邻课程一眼能分开。
class CourseColors {
  /// (bg, accent) — bg 用作课程块整体浅色底,accent 用作左侧彩条和文字。
  static const List<(Color, Color)> palettes = [
    (Color(0xFFE8EEFF), Color(0xFF3D5AFE)), // 靛蓝
    (Color(0xFFFDE4EC), Color(0xFFD81B60)), // 玫红
    (Color(0xFFE3F4EA), Color(0xFF2E7D32)), // 森林绿
    (Color(0xFFFFEFD9), Color(0xFFE65100)), // 暖橙
    (Color(0xFFF0E6FA), Color(0xFF6A1B9A)), // 紫罗兰
    (Color(0xFFDEF3F8), Color(0xFF00838F)), // 青蓝
    (Color(0xFFFFE6E1), Color(0xFFC62828)), // 砖红
    (Color(0xFFEDF4DE), Color(0xFF558B2F)), // 橄榄绿
    (Color(0xFFEDE7F6), Color(0xFF4527A0)), // 深紫
    (Color(0xFFFFF4CC), Color(0xFF9A7B00)), // 芥末黄
    (Color(0xFFD9EFFF), Color(0xFF0277BD)), // 蓝
    (Color(0xFFFDE4D4), Color(0xFFBF360C)), // 橘褐
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
