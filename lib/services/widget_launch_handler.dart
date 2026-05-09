import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../data/storage.dart';
import '../ui/course_detail_sheet.dart';

/// 桌面 widget 点击 → 原生 MainActivity → 这里。
/// 拿到 courseId 后在全局 navigator 上弹出课程详情。
class WidgetLaunchHandler {
  WidgetLaunchHandler._(this._navigatorKey);

  static const _channel = MethodChannel('com.jlu.schedule/widget');
  final GlobalKey<NavigatorState> _navigatorKey;

  static Future<WidgetLaunchHandler> attach(
    GlobalKey<NavigatorState> navigatorKey,
  ) async {
    final h = WidgetLaunchHandler._(navigatorKey);
    h._wire();
    await h._drainInitial();
    return h;
  }

  void _wire() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onCourseTap') {
        final id = call.arguments as String?;
        if (id != null) _openCourse(id);
      }
    });
  }

  Future<void> _drainInitial() async {
    try {
      final id = await _channel.invokeMethod<String>('consumeInitialCourseId');
      if (id != null && id.isNotEmpty) {
        // 等第一帧 navigator 挂起来再弹
        WidgetsBinding.instance.addPostFrameCallback((_) => _openCourse(id));
      }
    } on MissingPluginException {
      // iOS debug 或插件未注册时忽略
    }
  }

  void _openCourse(String id) {
    final course = AppStorage.courses.get(id);
    if (course == null) return;
    final ctx = _navigatorKey.currentContext;
    if (ctx == null) return;
    showCourseDetailSheet(ctx, course);
  }
}
