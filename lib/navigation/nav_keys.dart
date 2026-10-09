import 'package:flutter/cupertino.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> courseTabNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> agendaTabNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> assignmentTabNavKey =
    GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> examTabNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> personalTabNavKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> settingsTabNavKey = GlobalKey<NavigatorState>();

GlobalKey<NavigatorState> navKeyForTab(int tab) {
  switch (tab) {
    case 1:
      return agendaTabNavKey;
    case 2:
      return assignmentTabNavKey;
    case 3:
      return examTabNavKey;
    case 4:
      return personalTabNavKey;
    case 5:
      return settingsTabNavKey;
    case 0:
    default:
      return courseTabNavKey;
  }
}
