import 'package:flutter/cupertino.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/semester.dart';
import '../data/storage.dart';

/// 本周临时调课 sheet。保存后幂等写到 overrides box。
/// id 固定 "${courseId}@${week}",同周再改直接覆盖。
Future<void> showRescheduleSheet(
  BuildContext context, {
  required Course course,
  required Semester semester,
  required int week,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) => _RescheduleSheet(
      course: course,
      semester: semester,
      week: week,
    ),
  );
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({
    required this.course,
    required this.semester,
    required this.week,
  });

  final Course course;
  final Semester semester;
  final int week;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late int _day;
  late int _start;
  late int _end;
  late TextEditingController _locCtrl;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final existing = AppStorage.overrides
        .get(CourseOverride.buildId(widget.course.id, widget.week));
    if (existing != null && existing.isMove) {
      _day = existing.newDayOfWeek;
      _start = existing.newStartSection;
      _end = existing.newEndSection;
      _locCtrl = TextEditingController(text: existing.newLocation ?? '');
    } else {
      _day = widget.course.dayOfWeek;
      _start = widget.course.startSection;
      _end = widget.course.endSection;
      _locCtrl = TextEditingController(text: '');
    }
  }

  @override
  void dispose() {
    _locCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = CourseOverride.buildId(widget.course.id, widget.week);
    final o = CourseOverride(
      id: id,
      courseId: widget.course.id,
      week: widget.week,
      kind: CourseOverride.kindMove,
      newDayOfWeek: _day,
      newStartSection: _start,
      newEndSection: _end,
      newLocation: _locCtrl.text.trim().isEmpty ? null : _locCtrl.text.trim(),
    );
    await AppStorage.overrides.put(id, o);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    final id = CourseOverride.buildId(widget.course.id, widget.week);
    await AppStorage.overrides.delete(id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoColors.systemBackground.resolveFrom(context);
    final sub = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Container(
      decoration: BoxDecoration(
        color: bg,
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
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '第 ${widget.week} 周临时调课',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.course.name,
                style: TextStyle(fontSize: 13, color: sub),
              ),
              const SizedBox(height: 12),
              _row(
                label: '星期',
                value: '周${_dayNames[(_day - 1).clamp(0, 6)]}',
                onTap: () => _pick(
                  initial: _day - 1,
                  count: 7,
                  builder: (i) => '星期${_dayNames[i]}',
                  onChanged: (i) => setState(() => _day = i + 1),
                ),
              ),
              _row(
                label: '起始节',
                value: '第 $_start 节',
                onTap: () => _pick(
                  initial: _start - 1,
                  count: widget.semester.sectionCount,
                  builder: (i) => '第 ${i + 1} 节',
                  onChanged: (i) => setState(() {
                    _start = i + 1;
                    if (_end < _start) _end = _start;
                  }),
                ),
              ),
              _row(
                label: '结束节',
                value: '第 $_end 节',
                onTap: () => _pick(
                  initial: _end - 1,
                  count: widget.semester.sectionCount,
                  builder: (i) => '第 ${i + 1} 节',
                  onChanged: (i) => setState(() {
                    _end = i + 1;
                    if (_start > _end) _start = _end;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: CupertinoTextField(
                  controller: _locCtrl,
                  placeholder: '地点(留空沿用原教室)',
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton.filled(
                onPressed: _save,
                child: const Text('保存调课'),
              ),
              const SizedBox(height: 6),
              CupertinoButton(
                onPressed: _clear,
                child: const Text(
                  '清除本周调课',
                  style: TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text(label)),
            const Spacer(),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(CupertinoIcons.chevron_right, size: 14),
          ],
        ),
      ),
    );
  }

  void _pick({
    required int initial,
    required int count,
    required String Function(int) builder,
    required void Function(int) onChanged,
  }) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 240,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: CupertinoPicker(
          scrollController: FixedExtentScrollController(initialItem: initial),
          itemExtent: 36,
          onSelectedItemChanged: onChanged,
          children: [for (var i = 0; i < count; i++) Center(child: Text(builder(i)))],
        ),
      ),
    );
  }
}
