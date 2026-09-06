import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/semester.dart';
import '../ui/course_colors.dart';

/// 把"今日课表"推给 Android/iOS/macOS 桌面小组件。
/// 原生侧只负责渲染 — 周次筛选、排序、颜色索引都在 Dart 做好,原生读 JSON 就行。
class WidgetBridge {
  static const _androidProvider = 'ScheduleWidgetProvider';
  static const _iosName = 'ScheduleWidget';
  static const _groupId = 'group.com.jlu.schedule';
  static const _macChannel = MethodChannel('com.jlu.schedule/widget');

  static Future<void> init() async {
    if (Platform.isMacOS) return; // macOS 走 MethodChannel, 不用 home_widget
    await HomeWidget.setAppGroupId(_groupId);
  }

  static Future<void> refresh({
    required Semester? semester,
    required List<Course> allCourses,
    List<CourseOverride> overrides = const [],
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final payload = _buildPayload(
      semester: semester,
      allCourses: allCourses,
      overrides: overrides,
      now: stamp,
    );
    final jsonStr = jsonEncode(payload);

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
    await HomeWidget.saveWidgetData<String>('today_week_label', payload['weekLabel'] as String);
    await HomeWidget.saveWidgetData<String>('today_day_label', payload['dayLabel'] as String);

    await HomeWidget.updateWidget(
      name: _androidProvider,
      androidName: _androidProvider,
      iOSName: _iosName,
    );
  }

  static Map<String, dynamic> _buildPayload({
    required Semester? semester,
    required List<Course> allCourses,
    required List<CourseOverride> overrides,
    required DateTime now,
  }) {
    final dow = now.weekday; // 1..7
    final week = semester?.currentWeek(now) ?? 0;

    // 先按本周 overrides 得出每门课的"有效位置/地点",再筛出今天 & 今周。
    final thisWeekOverrides = <String, CourseOverride>{
      for (final o in overrides.where((o) => o.week == week)) o.courseId: o,
    };

    final todays = <_Today>[];
    for (final c in allCourses) {
      if (week != 0 && !c.activeInWeek(week)) continue;
      final o = thisWeekOverrides[c.id];
      if (o != null && o.isCancel) continue;
      final day = o?.isMove == true ? o!.newDayOfWeek : c.dayOfWeek;
      if (day != dow) continue;
      final startSec = o?.isMove == true ? o!.newStartSection : c.startSection;
      final endSec = o?.isMove == true ? o!.newEndSection : c.endSection;
      final loc = (o?.isMove == true && (o!.newLocation?.isNotEmpty ?? false))
          ? o.newLocation!
          : c.location;
      todays.add(_Today(c, startSec, endSec, loc));
    }
    todays.sort((a, b) => a.startSection.compareTo(b.startSection));

    return {
      'updatedAt': now.millisecondsSinceEpoch,
      'weekLabel': semester == null ? '未设置学期' : (week == 0 ? '未开学' : '第 $week 周'),
      'dayLabel': _weekdayLabel(dow),
      'dateShort': '${now.month}.${now.day}',
      'semesterName': semester?.name ?? '',
      'courses': [
        for (final t in todays)
          {
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
          },
      ],
    };
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
