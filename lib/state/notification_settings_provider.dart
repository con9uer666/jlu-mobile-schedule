import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage.dart';

class NotificationSettings {
  const NotificationSettings({
    this.coursesEnabled = true,
    this.defaultLeadMinutes = 10,
    this.weeklyDigestEnabled = true,
  });

  final bool coursesEnabled;
  final int defaultLeadMinutes;
  final bool weeklyDigestEnabled;

  NotificationSettings copyWith({
    bool? coursesEnabled,
    int? defaultLeadMinutes,
    bool? weeklyDigestEnabled,
  }) =>
      NotificationSettings(
        coursesEnabled: coursesEnabled ?? this.coursesEnabled,
        defaultLeadMinutes: defaultLeadMinutes ?? this.defaultLeadMinutes,
        weeklyDigestEnabled: weeklyDigestEnabled ?? this.weeklyDigestEnabled,
      );
}

class NotificationSettingsController
    extends StateNotifier<NotificationSettings> {
  NotificationSettingsController() : super(const NotificationSettings()) {
    _load();
  }

  static const _coursesKey = 'notif_courses_global';
  static const _leadKey = 'notif_default_lead';
  static const _weeklyKey = 'notif_weekly_digest';

  void _load() {
    final c = AppStorage.settings.get(_coursesKey);
    final l = AppStorage.settings.get(_leadKey);
    final w = AppStorage.settings.get(_weeklyKey);
    state = NotificationSettings(
      coursesEnabled: c is bool ? c : true,
      defaultLeadMinutes: l is int ? l : 10,
      weeklyDigestEnabled: w is bool ? w : true,
    );
  }

  Future<void> setCoursesEnabled(bool v) async {
    state = state.copyWith(coursesEnabled: v);
    await AppStorage.settings.put(_coursesKey, v);
  }

  Future<void> setDefaultLead(int minutes) async {
    state = state.copyWith(defaultLeadMinutes: minutes);
    await AppStorage.settings.put(_leadKey, minutes);
  }

  Future<void> setWeeklyDigestEnabled(bool v) async {
    state = state.copyWith(weeklyDigestEnabled: v);
    await AppStorage.settings.put(_weeklyKey, v);
  }
}

final notificationSettingsProvider = StateNotifierProvider<
    NotificationSettingsController,
    NotificationSettings>((ref) => NotificationSettingsController());
