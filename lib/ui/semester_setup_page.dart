import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/semester.dart';
import '../state/schedule_providers.dart';

class SemesterSetupPage extends ConsumerStatefulWidget {
  const SemesterSetupPage({super.key, this.isInitial = false});

  final bool isInitial;

  @override
  ConsumerState<SemesterSetupPage> createState() => _SemesterSetupPageState();
}

class _SemesterSetupPageState extends ConsumerState<SemesterSetupPage> {
  final _nameCtrl = TextEditingController(text: '本学期');
  DateTime _start = _nearestMonday(DateTime.now());
  int _totalWeeks = 20;
  int _sectionCount = 12;

  static DateTime _nearestMonday(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    DateTime picked = _start;
    await showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _start,
                onDateTimeChanged: (v) => picked = v,
              ),
            ),
          ],
        ),
      ),
    );
    setState(() => _start = _nearestMonday(picked));
  }

  Future<void> _save() async {
    final sem = Semester(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim().isEmpty ? '本学期' : _nameCtrl.text.trim(),
      startDate: _start,
      totalWeeks: _totalWeeks,
      sectionCount: _sectionCount,
    );
    await ref.read(currentSemesterProvider.notifier).setCurrent(sem);
    if (mounted && !widget.isInitial) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('学期设置')),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoFormSection.insetGrouped(
              header: const Text('基础信息'),
              children: [
                CupertinoTextFormFieldRow(
                  prefix: const Text('名称'),
                  controller: _nameCtrl,
                ),
                CupertinoFormRow(
                  prefix: const Text('开学日期'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _pickStartDate,
                    child: Text(
                      '${_start.year}-${_start.month.toString().padLeft(2, '0')}-${_start.day.toString().padLeft(2, '0')} 周一',
                    ),
                  ),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: const Text('参数'),
              children: [
                CupertinoFormRow(
                  prefix: const Text('总周数'),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _totalWeeks,
                    children: const {
                      16: Text('16'),
                      18: Text('18'),
                      20: Text('20'),
                      22: Text('22'),
                    },
                    onValueChanged: (v) => setState(() => _totalWeeks = v ?? 20),
                  ),
                ),
                CupertinoFormRow(
                  prefix: const Text('每日节数'),
                  child: CupertinoSlidingSegmentedControl<int>(
                    groupValue: _sectionCount,
                    children: const {
                      10: Text('10'),
                      12: Text('12'),
                      14: Text('14'),
                    },
                    onValueChanged: (v) => setState(() => _sectionCount = v ?? 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CupertinoButton.filled(
                onPressed: _save,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
