import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'course_colors.dart';

class CourseEditorPage extends ConsumerStatefulWidget {
  const CourseEditorPage({super.key, this.existing, this.prefill});

  final Course? existing;

  /// 主页拖选后预填:day / 起始节 / 结束节 / 当前周。
  /// 与 existing 互斥(有 existing 时忽略)。
  final ({int dayOfWeek, int startSection, int endSection, int week})? prefill;

  @override
  ConsumerState<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends ConsumerState<CourseEditorPage> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _locationCtrl;
  late int _dayOfWeek;
  late int _startSection;
  late int _endSection;
  late List<int> _weeks;
  late int _colorIndex;

  @override
  void initState() {
    super.initState();
    final c = widget.existing;
    final p = widget.prefill;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _teacherCtrl = TextEditingController(text: c?.teacher ?? '');
    _locationCtrl = TextEditingController(text: c?.location ?? '');
    _dayOfWeek = c?.dayOfWeek ?? p?.dayOfWeek ?? 1;
    _startSection = c?.startSection ?? p?.startSection ?? 1;
    _endSection = c?.endSection ?? p?.endSection ?? 2;
    _weeks = List<int>.from(
      c?.weeks ?? (p != null ? <int>[p.week] : List.generate(18, (i) => i + 1)),
    );
    _colorIndex = c?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _teacherCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final course = Course(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      teacher: _teacherCtrl.text.trim(),
      location: _locationCtrl.text.trim(),
      dayOfWeek: _dayOfWeek,
      startSection: _startSection,
      endSection: _endSection,
      weeks: _weeks,
      colorIndex: _colorIndex,
    );
    await AppStorage.courses.put(course.id, course);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.existing;
    if (c == null) return;
    await AppStorage.courses.delete(c.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(currentSemesterProvider);
    final sectionCount = semester?.sectionCount ?? 12;
    final totalWeeks = semester?.totalWeeks ?? 20;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.existing == null ? '新建课程' : '编辑课程'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('基础信息'),
              children: [
                CupertinoTextFormFieldRow(
                  prefix: const Text('名称'),
                  placeholder: '课程名',
                  controller: _nameCtrl,
                ),
                CupertinoTextFormFieldRow(
                  prefix: const Text('教师'),
                  placeholder: '选填',
                  controller: _teacherCtrl,
                ),
                CupertinoTextFormFieldRow(
                  prefix: const Text('地点'),
                  placeholder: '如 一教A101',
                  controller: _locationCtrl,
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('时间'),
              children: [
                _pickerRow(
                  label: '星期',
                  value: ['一', '二', '三', '四', '五', '六', '日'][_dayOfWeek - 1],
                  onTap: () => _pickDay(),
                ),
                _pickerRow(
                  label: '起始节',
                  value: '第 $_startSection 节',
                  onTap: () => _pickSection(true, sectionCount),
                ),
                _pickerRow(
                  label: '结束节',
                  value: '第 $_endSection 节',
                  onTap: () => _pickSection(false, sectionCount),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('周次'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var w = 1; w <= totalWeeks; w++)
                        GestureDetector(
                          onTap: () => setState(() {
                            if (_weeks.contains(w)) {
                              _weeks.remove(w);
                            } else {
                              _weeks.add(w);
                            }
                            _weeks.sort();
                          }),
                          child: Container(
                            width: 36,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _weeks.contains(w)
                                  ? CupertinoColors.systemIndigo
                                  : CupertinoColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$w',
                              style: TextStyle(
                                color: _weeks.contains(w)
                                    ? CupertinoColors.white
                                    : CupertinoColors.label,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('颜色'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (var i = 0; i < CourseColors.palettes.length; i++)
                        GestureDetector(
                          onTap: () => setState(() => _colorIndex = i),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CourseColors.pick(i).$2,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: i == _colorIndex
                                    ? CupertinoColors.label
                                    : CupertinoColors.separator,
                                width: i == _colorIndex ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.existing != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoButton(
                  color: CupertinoColors.systemRed,
                  onPressed: _delete,
                  child: const Text('删除课程'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pickerRow({required String label, required String value, required VoidCallback onTap}) {
    return CupertinoFormRow(
      prefix: Text(label),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Text(value),
      ),
    );
  }

  void _pickDay() {
    _showPicker(
      initial: _dayOfWeek - 1,
      itemCount: 7,
      builder: (i) => '星期${['一', '二', '三', '四', '五', '六', '日'][i]}',
      onChanged: (i) => setState(() => _dayOfWeek = i + 1),
    );
  }

  void _pickSection(bool start, int sectionCount) {
    _showPicker(
      initial: (start ? _startSection : _endSection) - 1,
      itemCount: sectionCount,
      builder: (i) => '第 ${i + 1} 节',
      onChanged: (i) => setState(() {
        if (start) {
          _startSection = i + 1;
          if (_endSection < _startSection) _endSection = _startSection;
        } else {
          _endSection = i + 1;
          if (_startSection > _endSection) _startSection = _endSection;
        }
      }),
    );
  }

  void _showPicker({
    required int initial,
    required int itemCount,
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
          children: [for (var i = 0; i < itemCount; i++) Center(child: Text(builder(i)))],
        ),
      ),
    );
  }
}
