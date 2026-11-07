import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'widget_bridge.dart';

/// App 启动后挂上:课程 / 学期 任何一方变了,都把今日课表重新写给桌面组件。
/// Native widgets select each date from the cached semester snapshots.
class WidgetSync {
  WidgetSync._(this._ref);

  final Ref _ref;
  StreamSubscription<dynamic>? _daySwapSubscription;
  Future<void>? _inFlight;
  bool _dirty = false;
  bool _disposed = false;

  void _start() {
    unawaited(refresh());
    _ref.listen(currentSemesterProvider, (_, next) => refresh());
    _ref.listen(coursesProvider, (_, next) => refresh());
    _ref.listen(overridesProvider, (_, next) => refresh());
    _daySwapSubscription = AppStorage.daySwaps.watch().listen((_) => refresh());
    _ref.onDispose(() {
      _disposed = true;
      _daySwapSubscription?.cancel();
    });
  }

  Future<void> refresh() {
    _dirty = true;
    return _inFlight ??= Future<void>(() async {
      try {
        while (_dirty && !_disposed) {
          _dirty = false;
          await _push();
        }
      } catch (error, stack) {
        debugPrint('Widget refresh failed: $error');
        debugPrintStack(stackTrace: stack);
      } finally {
        _inFlight = null;
      }
    });
  }

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
