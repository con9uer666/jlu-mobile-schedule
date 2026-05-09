import 'package:flutter/cupertino.dart';

import '../data/course.dart';
import 'course_colors.dart';
import 'course_editor_page.dart';

/// 点课程时先弹一个下拉详情,点"编辑课程"再进入编辑页。
Future<void> showCourseDetailSheet(BuildContext context, Course course) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _CourseDetailSheet(course: course),
  );
}

class _CourseDetailSheet extends StatelessWidget {
  const _CourseDetailSheet({required this.course});

  final Course course;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final (bg, accent) = CourseColors.pick(course.colorIndex);
    final bgColor = CupertinoColors.systemBackground.resolveFrom(context);
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final subLabelColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: accent, width: 4)),
                ),
                child: Text(
                  course.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: CupertinoIcons.clock,
                label: '时间',
                value:
                    '周${_dayNames[(course.dayOfWeek - 1).clamp(0, 6)]} · 第 ${course.startSection}-${course.endSection} 节',
                labelColor: subLabelColor,
                valueColor: labelColor,
              ),
              if (course.location.isNotEmpty)
                _DetailRow(
                  icon: CupertinoIcons.location,
                  label: '地点',
                  value: course.location,
                  labelColor: subLabelColor,
                  valueColor: labelColor,
                ),
              if (course.teacher.isNotEmpty)
                _DetailRow(
                  icon: CupertinoIcons.person,
                  label: '教师',
                  value: course.teacher,
                  labelColor: subLabelColor,
                  valueColor: labelColor,
                ),
              _DetailRow(
                icon: CupertinoIcons.calendar,
                label: '周次',
                value: _formatWeeks(course.weeks),
                labelColor: subLabelColor,
                valueColor: labelColor,
              ),
              if ((course.remark ?? '').isNotEmpty)
                _DetailRow(
                  icon: CupertinoIcons.text_bubble,
                  label: '备注',
                  value: course.remark!,
                  labelColor: subLabelColor,
                  valueColor: labelColor,
                ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => CourseEditorPage(existing: course),
                    ),
                  );
                },
                child: const Text('编辑课程'),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 把周次列表压缩成 "1-8, 10, 12-16" 这种紧凑格式。
  static String _formatWeeks(List<int> weeks) {
    if (weeks.isEmpty) return '—';
    final sorted = [...weeks]..sort();
    final parts = <String>[];
    var start = sorted.first;
    var prev = start;
    for (var i = 1; i < sorted.length; i++) {
      final w = sorted[i];
      if (w == prev + 1) {
        prev = w;
        continue;
      }
      parts.add(start == prev ? '$start' : '$start-$prev');
      start = w;
      prev = w;
    }
    parts.add(start == prev ? '$start' : '$start-$prev');
    return '${parts.join(', ')} 周';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: labelColor),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: labelColor),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
