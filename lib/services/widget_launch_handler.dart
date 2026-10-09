import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'deep_link_router.dart';

/// 桌面 widget 点击 → 原生 MainActivity → 这里 → DeepLinkRouter。
class WidgetLaunchHandler {
  WidgetLaunchHandler._();

  static const _channel = MethodChannel('com.jlu.schedule/widget');

  static Future<void> attach() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDeepLink':
          _handle(Uri.tryParse(call.arguments as String? ?? ''));
        case 'onCourseTap':
          final id = call.arguments as String?;
          if (id != null && id.isNotEmpty) {
            _handle(Uri.parse('schedule://course?id=$id'));
          }
        case 'onEventTap':
          final id = call.arguments as String?;
          if (id != null && id.isNotEmpty) {
            _handle(Uri.parse('schedule://event?id=$id'));
          }
      }
    });
    await _drainInitial();
  }

  static Future<void> _drainInitial() async {
    try {
      final raw = await _channel.invokeMethod<String>('consumeInitialDeepLink');
      if (raw != null && raw.isNotEmpty) _schedule(Uri.tryParse(raw));
    } on MissingPluginException {
      try {
        final id = await _channel.invokeMethod<String>('consumeInitialCourseId');
        if (id != null && id.isNotEmpty) {
          _schedule(Uri.parse('schedule://course?id=$id'));
        }
      } on MissingPluginException {
        // 原生侧未注册时忽略
      }
    }
  }

  static void _handle(Uri? uri) {
    if (uri == null) return;
    _schedule(uri);
  }

  static void _schedule(Uri? uri) {
    if (uri == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkRouter.handle(uri);
    });
  }
}
