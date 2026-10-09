import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/day_swap.dart';
import '../data/semester.dart';
import '../ui/course_colors.dart';

/// 把"今日课表"推给 Android/iOS/macOS 桌面小组件。
/// 原生侧只负责渲染 — 周次筛选、排序、颜色索引都在 Dart 做好,原生读 JSON 就行。
class WidgetBridge {
  static const _androidProvider = 'ScheduleWidgetProvider';
  static const _androidProviders = [
    'ScheduleWidgetProvider',
    'ScheduleWidgetProviderSmall',
    'ScheduleWidgetProviderLarge',
  ];
  static const _iosName = 'ScheduleWidget';
  static const _groupId = 'group.com.jlu.schedule';
  static const _macChannel = MethodChannel('com.jlu.schedule/widget');
  static const _watchChannel = MethodChannel('com.jlu.schedule/watch');

  static Future<void> init() async {
    if (Platform.isMacOS) return; // macOS 走 MethodChannel, 不用 home_widget
    await HomeWidget.setAppGroupId(_groupId);
  }

  static Future<void> refresh({
    required Semester? semester,
    required List<Course> allCourses,
    List<CourseOverride> overrides = const [],
    List<DaySwap> daySwaps = const [],
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final payload = buildPayload(
      semester: semester,
      allCourses: allCourses,
      overrides: overrides,
      daySwaps: daySwaps,
      now: stamp,
    );
    final jsonStr = jsonEncode(payload);

    if (Platform.isIOS) {
      // The watch receives the whole semester, so date browsing and future
      // complication entries do not depend on opening the phone every day.
      try {
        await _watchChannel.invokeMethod<void>(
          'pushSchedule',
          jsonEncode(
            buildWatchPayload(
              semester: semester,
              allCourses: allCourses,
              overrides: overrides,
              daySwaps: daySwaps,
              now: stamp,
            ),
          ),
        );
      } on MissingPluginException {
        // Allows running with an older native host during development.
      } on PlatformException catch (error) {
        // Watch connectivity must not interrupt phone widget updates.
        debugPrint('Watch schedule sync failed: ${error.code}');
      }
    }

    if (Platform.isMacOS) {
      try {
        await _macChannel.invokeMethod<void>('pushTodayPayload', jsonStr);
      } on MissingPluginException {
        // 原生侧 channel 没注册时静默忽略
      }
      return;
    }

    await HomeWidget.saveWidgetData<String>('today_payload', jsonStr);
    await HomeWidget.saveWidgetData<String>('today_date', _formatDate(stamp));
    await HomeWidget.saveWidgetData<String>(
      'today_week_label',
      payload['weekLabel'] as String,
    );
    await HomeWidget.saveWidgetData<String>(
      'today_day_label',
      payload['dayLabel'] as String,
    );

    if (Platform.isAndroid) {
      for (final provider in _androidProviders) {
        await HomeWidget.updateWidget(
          qualifiedAndroidName: 'com.jlu.schedule.widget.$provider',
        );
      }
    } else {
      await HomeWidget.updateWidget(name: _androidProvider, iOSName: _iosName);
    }
  }

  static Map<String, dynamic> buildWatchPayload({
    required Semester? semester,
    required List<Course> allCourses,
    List<CourseOverride> overrides = const [],
    List<DaySwap> daySwaps = const [],
    required DateTime now,
  }) {
    final days = <Map<String, dynamic>>[];
    DateTime? start;
    DateTime? end;
    if (semester != null) {
      start = DateTime(
        semester.startDate.year,
        semester.startDate.month,
        semester.startDate.day,
      );
      end = DateTime(
        start.year,
        start.month,
        start.day + semester.totalWeeks * 7 - 1,
      );
      final courses = allCourses
          .where((c) => c.id.startsWith('${semester.id}-'))
          .toList();
      for (var i = 0; i < semester.totalWeeks * 7; i++) {
        final date = DateTime(start.year, start.month, start.day + i);
        final effective = _coursesForDate(
          semester: semester,
          courses: courses,
          overrides: overrides,
          daySwaps: daySwaps,
          date: date,
        );
        days.add({
          'date': _formatDate(date),
          'week': i ~/ 7 + 1,
          'courses': [
            for (final item in effective)
              {
                'id': item.course.id,
                'name': item.course.name,
                'location': item.location,
                'startTime': semester.sectionStart(item.startSection),
                'endTime': semester.sectionEnd(item.endSection),
              },
          ],
        });
      }
    }
    return {
      'schemaVersion': 1,
      'updatedAt': now.millisecondsSinceEpoch,
      'utcOffsetSeconds': now.timeZoneOffset.inSeconds,
      'semesterId': semester?.id,
      'semesterName': semester?.name ?? '',
      'startDate': start == null ? null : _formatDate(start),
      'endDate': end == null ? null : _formatDate(end),
      'days': days,
    };
  }

  static Map<String, dynamic> buildPayload({
    required Semester? semester,
    required List<Course> allCourses,
    required List<CourseOverride> overrides,
    List<DaySwap> daySwaps = const [],
    required DateTime now,
  }) {
    final dow = now.weekday; // 1..7
    final week = semester?.currentWeek(now) ?? 0;
    final semesterCourses = semester == null
        ? const <Course>[]
        : allCourses
              .where((course) => course.id.startsWith('${semester.id}-'))
              .toList();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final todays = _coursesForDate(
      semester: semester,
      courses: semesterCourses,
      overrides: overrides,
      daySwaps: daySwaps,
      date: today,
    );
    final tomorrows = _coursesForDate(
      semester: semester,
      courses: semesterCourses,
      overrides: overrides,
      daySwaps: daySwaps,
      date: tomorrow,
    );

    Map<String, dynamic> encode(_Today t) => {
      'id': t.course.id,
      'name': t.course.name,
      'teacher': t.course.teacher,
      'location': t.location,
      'startSection': t.startSection,
      'endSection': t.endSection,
      'startTime': semester?.sectionStart(t.startSection) ?? '',
      'endTime': semester?.sectionEnd(t.endSection) ?? '',
      'colorBg': _hex(CourseColors.pick(t.course.colorIndex).$1.toARGB32()),
      'colorAccent': _hex(CourseColors.pick(t.course.colorIndex).$2.toARGB32()),
    };

    return {
      'updatedAt': now.millisecondsSinceEpoch,
      'weekLabel': semester == null
          ? '未设置学期'
          : (week == 0 ? '未开学' : '第 $week 周'),
      'dayLabel': _weekdayLabel(dow),
      'dateShort': '${now.month}.${now.day}',
      'semesterName': semester?.name ?? '',
      'courses': [for (final t in todays) encode(t)],
      'tomorrowCourses': [for (final t in tomorrows) encode(t)],
    };
  }

  static List<_Today> _coursesForDate({
    required Semester? semester,
    required List<Course> courses,
    required List<CourseOverride> overrides,
    required List<DaySwap> daySwaps,
    required DateTime date,
  }) {
    if (semester == null) return const [];

    final normalizedDate = DateTime(date.year, date.month, date.day);
    DaySwap? daySwap;
    for (final swap in daySwaps) {
      final target = swap.targetDate;
      if (target.year == normalizedDate.year &&
          target.month == normalizedDate.month &&
          target.day == normalizedDate.day) {
        daySwap = swap;
        break;
      }
    }

    // 整天调课采用来源日期的固定课表，不叠加临时调课。
    if (daySwap != null) {
      final source = daySwap.sourceDate;
      final sourceWeek = semester.currentWeek(source);
      final result = <_Today>[
        for (final course in courses)
          if (course.activeInWeek(sourceWeek) &&
              course.dayOfWeek == source.weekday)
            _Today(
              course,
              course.startSection,
              course.endSection,
              course.location,
            ),
      ];
      result.sort((a, b) => a.startSection.compareTo(b.startSection));
      return result;
    }

    final dateWeek = semester.currentWeek(normalizedDate);
    final overridesByCourse = <String, CourseOverride>{
      for (final override in overrides.where((item) => item.week == dateWeek))
        override.courseId: override,
    };
    final result = <_Today>[];
    for (final course in courses) {
      if (!course.activeInWeek(dateWeek)) continue;
      final override = overridesByCourse[course.id];
      if (override != null && override.isCancel) continue;
      final isMoved = override?.isMove == true;
      final day = isMoved ? override!.newDayOfWeek : course.dayOfWeek;
      if (day != normalizedDate.weekday) continue;
      result.add(
        _Today(
          course,
          isMoved ? override!.newStartSection : course.startSection,
          isMoved ? override!.newEndSection : course.endSection,
          isMoved && (override!.newLocation?.isNotEmpty ?? false)
              ? override.newLocation!
              : course.location,
        ),
      );
    }
    result.sort((a, b) => a.startSection.compareTo(b.startSection));
    return result;
  }

  static String _weekdayLabel(int d) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${names[(d - 1).clamp(0, 6)]}';
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _hex(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

class _Today {
  _Today(this.course, this.startSection, this.endSection, this.location);
  final Course course;
  final int startSection;
  final int endSection;
  final String location;
}
