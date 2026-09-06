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
        case 'onCourseTap':
          final id = call.arguments as String?;
          if (id != null && id.isNotEmpty) {
            DeepLinkRouter.handle(Uri.parse('schedule://course?id=$id'));
          }
        case 'onEventTap':
          final id = call.arguments as String?;
          if (id != null && id.isNotEmpty) {
            DeepLinkRouter.handle(Uri.parse('schedule://event?id=$id'));
          }
      }
    });
    await _drainInitial();
  }

  static Future<void> _drainInitial() async {
    try {
      final id =
          await _channel.invokeMethod<String>('consumeInitialCourseId');
      if (id != null && id.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          DeepLinkRouter.handle(Uri.parse('schedule://course?id=$id'));
        });
      }
    } on MissingPluginException {
      // iOS debug 或插件未注册时忽略
    }
  }
}
