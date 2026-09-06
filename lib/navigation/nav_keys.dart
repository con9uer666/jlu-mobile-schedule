import 'package:flutter/cupertino.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> courseTabNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> agendaTabNavKey = GlobalKey<NavigatorState>();

GlobalKey<NavigatorState> navKeyForTab(int tab) {
  switch (tab) {
    case 1:
      return agendaTabNavKey;
    case 0:
    default:
      return courseTabNavKey;
  }
}
