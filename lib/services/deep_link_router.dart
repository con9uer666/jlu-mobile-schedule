import 'package:flutter/cupertino.dart';

import '../data/storage.dart';
import '../navigation/nav_keys.dart';
import '../navigation/tab_router.dart';
import '../ui/course_detail_sheet.dart';
import '../ui/event_editor_page.dart';

class DeepLinkRouter {
  DeepLinkRouter._();

  /// 入口:解析 schedule://course?id=xxx、schedule://event?id=xxx、schedule://agenda。
  static void handle(Uri uri) {
    if (uri.scheme != 'schedule') return;
    switch (uri.host) {
      case 'course':
        final id = uri.queryParameters['id'];
        if (id != null && id.isNotEmpty) _openCourse(id);
      case 'event':
        final id = uri.queryParameters['id'];
        if (id != null && id.isNotEmpty) _openEvent(id);
      case 'agenda':
        TabRouter.switchTo(1);
    }
  }

  static String? _currentCourseSheet;

  static void _openCourse(String id) {
    final course = AppStorage.courses.get(id);
    if (course == null) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;

    // 同一门课已开着 sheet → 忽略
    if (_currentCourseSheet == id) return;

    // 如果当前有任何 sheet 在前面(可能是另一门课的详情、event 编辑、登录页等),
    // 先把 root navigator 上面所有非根路由都 pop 掉,再延一帧 push 新 sheet。
    // popUntil 是同步的,但 sheet 的 dismiss 动画异步;给 100ms 让动画走完再 push,
    // 避免新 sheet 被旧 sheet 的 dismiss 动画覆盖,或 whenComplete 把状态清成错的。
    final rootNav = Navigator.of(ctx, rootNavigator: true);
    final hadOverlay = _currentCourseSheet != null || rootNav.canPop();
    _currentCourseSheet = id;
    if (hadOverlay) {
      rootNav.popUntil((r) => r.isFirst);
    }

    void show() {
      final ctx2 = rootNavigatorKey.currentContext;
      if (ctx2 == null) return;
      showCourseDetailSheet(ctx2, course).whenComplete(() {
        if (_currentCourseSheet == id) _currentCourseSheet = null;
      });
    }

    if (hadOverlay) {
      Future.delayed(const Duration(milliseconds: 120), show);
    } else {
      show();
    }
  }

  static void _openEvent(String id) {
    final event = AppStorage.events.get(id);
    if (event == null) return;
    TabRouter.pushOnTab(
      1,
      CupertinoPageRoute(builder: (_) => EventEditorPage(existing: event)),
    );
  }
}
