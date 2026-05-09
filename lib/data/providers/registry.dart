import '../school_provider.dart';
import 'hhu_jsxsd.dart';
import 'jlu_iedu.dart';

/// 所有可用学校 provider。加新学校只需要 import 后往这里塞一个实例。
const List<SchoolProvider> schoolProviders = <SchoolProvider>[
  JluIeduProvider(),
  HhuJsxsdProvider(),
];

SchoolProvider? findProvider(String id) {
  for (final p in schoolProviders) {
    if (p.id == id) return p;
  }
  return null;
}

/// 默认(第一次装 app 或 prefs 里没值时)。
SchoolProvider get defaultProvider => schoolProviders.first;
