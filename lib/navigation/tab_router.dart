import 'package:flutter/cupertino.dart';

import 'nav_keys.dart';

class TabRouter {
  static final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);

  static void switchTo(int tab) {
    currentIndex.value = tab;
  }

  static Future<T?> pushOnTab<T>(int tab, Route<T> route) async {
    switchTo(tab);
    await WidgetsBinding.instance.endOfFrame;
    final navState = navKeyForTab(tab).currentState;
    if (navState == null) return null;
    return navState.push(route);
  }
}
