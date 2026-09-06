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
  late final TextEditingController _nameCtrl;
  late DateTime _start;
  late int _totalWeeks;
  late int _sectionCount;
  late List<String> _clock; // ["HH:mm-HH:mm", ...] 长度 == _sectionCount

  bool _initialized = false;

  static DateTime _nearestMonday(DateTime d) {
    final diff = d.weekday - DateTime.monday;
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: diff));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _initFrom(Semester? existing) {
    _nameCtrl = TextEditingController(text: existing?.name ?? '本学期');
    _start = existing?.startDate ?? _nearestMonday(DateTime.now());
    _totalWeeks = existing?.totalWeeks ?? 20;
    _sectionCount = existing?.sectionCount ?? 12;
    _clock = Semester.normalizeSectionClock(existing?.sectionClock, _sectionCount);
  }

  void _resizeClock(int count) {
    _clock = Semester.normalizeSectionClock(_clock, count);
  }

  Future<void> _pickStartDate() async {
    DateTime picked = _start;
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
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
    if (!mounted) return;
    setState(() => _start = _nearestMonday(picked));
  }

  Future<void> _pickTime(int sectionIndex, bool isStart) async {
    final parts = _clock[sectionIndex].split('-');
    final current = (isStart ? parts.first : parts.last).padLeft(5, '0');
    final now = DateTime.now();
    DateTime picked = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(current.split(':').first) ?? 8,
      int.tryParse(current.split(':').last) ?? 0,
    );
    await showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: picked,
                onDateTimeChanged: (v) => picked = v,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    final label =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      final cur = _clock[sectionIndex].split('-');
      final start = isStart ? label : cur.first;
      final end = isStart ? cur.last : label;
      _clock[sectionIndex] = '$start-$end';
    });
  }

  void _applyDefaults() {
    setState(() {
      _clock = Semester.normalizeSectionClock(const [], _sectionCount);
    });
  }

  Future<void> _save() async {
    if (_totalWeeks < 1 || _sectionCount < 1) return;
    final existing = ref.read(currentSemesterProvider);
    final sem = Semester(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim().isEmpty ? '本学期' : _nameCtrl.text.trim(),
      startDate: _start,
      totalWeeks: _totalWeeks,
      sectionCount: _sectionCount,
      sectionClock: _clock,
    );
    await ref.read(currentSemesterProvider.notifier).setCurrent(sem);
    if (mounted && !widget.isInitial) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _initFrom(ref.read(currentSemesterProvider));
      _initialized = true;
    }

    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('学期设置'),
            backgroundColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            border: null,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
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
                    onValueChanged: (v) => setState(() {
                      _sectionCount = v ?? 12;
                      _resizeClock(_sectionCount);
                    }),
                  ),
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: Row(
                children: [
                  const Text('节次时间'),
                  const Spacer(),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _applyDefaults,
                    child: const Text('恢复默认', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
              children: [
                for (var i = 0; i < _sectionCount; i++) _clockRow(i),
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
            const SizedBox(height: 20),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _clockRow(int i) {
    final parts = _clock[i].split('-');
    final start = parts.isNotEmpty ? parts.first : '';
    final end = parts.length > 1 ? parts.last : '';
    return CupertinoFormRow(
      prefix: SizedBox(width: 56, child: Text('第 ${i + 1} 节')),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _pickTime(i, true),
            child: Text(start),
          ),
          const Text('—', style: TextStyle(color: CupertinoColors.systemGrey)),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _pickTime(i, false),
            child: Text(end),
          ),
        ],
      ),
    );
  }
}
