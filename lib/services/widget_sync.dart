import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'widget_bridge.dart';

/// App 启动后挂上:课程 / 学期 任何一方变了,都把今日课表重新写给桌面组件。
/// 每天 0 点附近内容会过期(今日变成昨日),这个留给系统定时刷新 + 用户打开 app 触发。
class WidgetSync {
  WidgetSync._(this._ref);

  final Ref _ref;
  StreamSubscription<dynamic>? _daySwapSubscription;

  void _start() {
    _push();
    _ref.listen(currentSemesterProvider, (_, next) => _push());
    _ref.listen(coursesProvider, (_, next) => _push());
    _ref.listen(overridesProvider, (_, next) => _push());
    _daySwapSubscription = AppStorage.daySwaps.watch().listen((_) => _push());
    _ref.onDispose(() => _daySwapSubscription?.cancel());
  }

  Future<void> refresh() => _push();

  Future<void> _push() async {
    final sem = _ref.read(currentSemesterProvider);
    final courses = AppStorage.courses.values.toList();
    final overrides = AppStorage.overrides.values.toList();
    await WidgetBridge.refresh(
      semester: sem,
      allCourses: courses,
      overrides: overrides,
      daySwaps: AppStorage.daySwaps.values.toList(),
    );
  }
}

final widgetSyncProvider = Provider<WidgetSync>((ref) {
  final sync = WidgetSync._(ref);
  sync._start();
  return sync;
});
