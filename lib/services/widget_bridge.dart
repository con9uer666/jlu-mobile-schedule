import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import '../data/course.dart';
import '../data/semester.dart';
import '../ui/course_colors.dart';

/// 把"今日课表"推给 Android/iOS 桌面小组件。
/// 原生侧只负责渲染 — 周次筛选、排序、颜色索引都在 Dart 做好,原生读 JSON 就行。
class WidgetBridge {
  static const _androidProvider = 'ScheduleWidgetProvider';
  static const _iosName = 'ScheduleWidget';
  static const _groupId = 'group.com.jlu.schedule';

  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_groupId);
  }

  static Future<void> refresh({
    required Semester? semester,
    required List<Course> allCourses,
    DateTime? now,
  }) async {
    final stamp = now ?? DateTime.now();
    final payload = _buildPayload(semester: semester, allCourses: allCourses, now: stamp);

    await HomeWidget.saveWidgetData<String>('today_payload', jsonEncode(payload));
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
    required DateTime now,
  }) {
    final dow = now.weekday; // 1..7
    final week = semester?.currentWeek(now) ?? 0;

    final todays = allCourses
        .where((c) => c.dayOfWeek == dow)
        .where((c) => week == 0 ? true : c.activeInWeek(week))
        .toList()
      ..sort((a, b) => a.startSection.compareTo(b.startSection));

    return {
      'updatedAt': now.millisecondsSinceEpoch,
      'weekLabel': semester == null ? '未设置学期' : '第 $week 周',
      'dayLabel': _weekdayLabel(dow),
      'semesterName': semester?.name ?? '',
      'courses': [
        for (final c in todays)
          {
            'id': c.id,
            'name': c.name,
            'teacher': c.teacher,
            'location': c.location,
            'startSection': c.startSection,
            'endSection': c.endSection,
            'colorBg': _hex(CourseColors.pick(c.colorIndex).$1.toARGB32()),
            'colorAccent': _hex(CourseColors.pick(c.colorIndex).$2.toARGB32()),
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
