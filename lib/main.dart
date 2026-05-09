import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'data/storage.dart';
import 'services/widget_bridge.dart';
import 'services/widget_launch_handler.dart';
import 'services/widget_sync.dart';
import 'ui/home_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AppStorage.openAll();
  await WidgetBridge.init();
  runApp(const ProviderScope(child: ScheduleApp()));
  await WidgetLaunchHandler.attach(rootNavigatorKey);
}

class ScheduleApp extends ConsumerWidget {
  const ScheduleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSyncProvider);
    return CupertinoApp(
      title: '课程表',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.systemIndigo,
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}
