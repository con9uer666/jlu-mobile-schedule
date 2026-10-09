import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/storage.dart';
import 'navigation/nav_keys.dart';
import 'services/deep_link_router.dart';
import 'services/notification_service.dart';
import 'services/notification_sync.dart';
import 'services/widget_bridge.dart';
import 'services/widget_launch_handler.dart';
import 'services/widget_sync.dart';
import 'state/appearance_provider.dart';
import 'ui/root_tab_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  bool storageOk = true;
  try {
    await AppStorage.openAll();
  } catch (_) {
    storageOk = false;
  }
  await WidgetBridge.init();
  await NotificationService.init(onDeepLink: DeepLinkRouter.handle);
  runApp(const ProviderScope(child: ScheduleApp()));
  if (!storageOk) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      showCupertinoDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('数据库错误'),
          content: const Text('本地数据无法打开。清除数据后重启可恢复正常使用。'),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                await Hive.deleteFromDisk();
              },
              child: const Text('清除数据'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('忽略'),
            ),
          ],
        ),
      );
    });
  }
  await WidgetLaunchHandler.attach();
}

class ScheduleApp extends ConsumerStatefulWidget {
  const ScheduleApp({super.key});

  @override
  ConsumerState<ScheduleApp> createState() => _ScheduleAppState();
}

class _ScheduleAppState extends ConsumerState<ScheduleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationSyncProvider);
      unawaited(ref.read(widgetSyncProvider).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(widgetSyncProvider);
    ref.watch(notificationSyncProvider);
    final appearance = ref.watch(appearanceProvider);
    return CupertinoApp(
      title: '吉林大学手机课表',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: CupertinoThemeData(
        brightness: appearance.explicitBrightness,
        primaryColor: appearance.accent,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        barBackgroundColor: CupertinoColors.systemBackground.withValues(
          alpha: 0.82,
        ),
        textTheme: const CupertinoTextThemeData(
          navLargeTitleTextStyle: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
          navTitleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: const RootTabScaffold(),
    );
  }
}
