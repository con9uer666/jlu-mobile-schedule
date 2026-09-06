import 'package:flutter/cupertino.dart';

import '../data/recurrence_rule.dart';

class RecurrencePickerPage extends StatefulWidget {
  const RecurrencePickerPage({super.key, this.initial, required this.anchor});

  final RecurrenceRule? initial;
  final DateTime anchor;

  @override
  State<RecurrencePickerPage> createState() => _RecurrencePickerPageState();
}

class _RecurrencePickerPageState extends State<RecurrencePickerPage> {
  late RecurrenceFreq _freq;
  late int _interval;
  late Set<int> _byWeekday;
  DateTime? _until;
  int? _count;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    _freq = r?.freq ?? RecurrenceFreq.none;
    _interval = r?.interval ?? 1;
    _byWeekday = (r?.byWeekday == null || r!.byWeekday!.isEmpty)
        ? <int>{widget.anchor.weekday}
        : r.byWeekday!.toSet();
    _until = r?.until;
    _count = r?.count;
  }

  void _save() {
    if (_freq == RecurrenceFreq.none) {
      Navigator.of(context).pop(RecurrenceRule(freq: RecurrenceFreq.none));
      return;
    }
    Navigator.of(context).pop(RecurrenceRule(
      freq: _freq,
      interval: _interval.clamp(1, 99),
      byWeekday: _freq == RecurrenceFreq.weekly
          ? (_byWeekday.toList()..sort())
          : null,
      until: _until,
      count: _until == null ? _count : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('重复'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _save,
          child: const Text('完成'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                for (final f in RecurrenceFreq.values)
                  CupertinoListTile(
                    title: Text(_freqLabel(f)),
                    trailing: f == _freq
                        ? const Icon(
                            CupertinoIcons.check_mark,
                            color: CupertinoColors.activeBlue,
                          )
                        : null,
                    onTap: () => setState(() => _freq = f),
                  ),
              ],
            ),
            if (_freq != RecurrenceFreq.none) ...[
              CupertinoListSection.insetGrouped(
                header: const Text('间隔'),
                children: [
                  CupertinoListTile(
                    title: Text('每 $_interval ${_unitName(_freq)}'),
                    trailing: _IntervalStepper(
                      value: _interval,
                      onChanged: (v) => setState(() => _interval = v),
                    ),
                  ),
                ],
              ),
              if (_freq == RecurrenceFreq.weekly)
                CupertinoListSection.insetGrouped(
                  header: const Text('星期几'),
                  children: [
                    CupertinoListTile(
                      title: _WeekdayChips(
                        selected: _byWeekday,
                        onToggle: (wd) {
                          setState(() {
                            if (_byWeekday.contains(wd)) {
                              if (_byWeekday.length > 1) _byWeekday.remove(wd);
                            } else {
                              _byWeekday.add(wd);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
              CupertinoListSection.insetGrouped(
                header: const Text('结束'),
                children: [
                  CupertinoListTile(
                    title: const Text('无结束日期'),
                    trailing: (_until == null && _count == null)
                        ? const Icon(CupertinoIcons.check_mark,
                            color: CupertinoColors.activeBlue)
                        : null,
                    onTap: () => setState(() {
                      _until = null;
                      _count = null;
                    }),
                  ),
                  CupertinoListTile(
                    title: const Text('在指定日期结束'),
                    additionalInfo: _until != null
                        ? Text(
                            '${_until!.year}/${_until!.month}/${_until!.day}')
                        : null,
                    onTap: () async {
                      final picked = await _pickDate(context,
                          initial: _until ??
                              DateTime.now().add(const Duration(days: 30)));
                      if (picked != null) {
                        setState(() {
                          _until = picked;
                          _count = null;
                        });
                      }
                    },
                    trailing: _until != null
                        ? const Icon(CupertinoIcons.check_mark,
                            color: CupertinoColors.activeBlue)
                        : null,
                  ),
                  CupertinoListTile(
                    title: const Text('重复次数'),
                    additionalInfo:
                        _count != null ? Text('$_count 次') : null,
                    onTap: () async {
                      final picked = await _pickCount(context,
                          initial: _count ?? 10);
                      if (picked != null) {
                        setState(() {
                          _count = picked;
                          _until = null;
                        });
                      }
                    },
                    trailing: _count != null
                        ? const Icon(CupertinoIcons.check_mark,
                            color: CupertinoColors.activeBlue)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _freqLabel(RecurrenceFreq f) => switch (f) {
        RecurrenceFreq.none => '永不',
        RecurrenceFreq.daily => '每天',
        RecurrenceFreq.weekly => '每周',
        RecurrenceFreq.monthly => '每月',
        RecurrenceFreq.yearly => '每年',
      };

  String _unitName(RecurrenceFreq f) => switch (f) {
        RecurrenceFreq.daily => '天',
        RecurrenceFreq.weekly => '周',
        RecurrenceFreq.monthly => '月',
        RecurrenceFreq.yearly => '年',
        RecurrenceFreq.none => '',
      };
}

Future<DateTime?> _pickDate(BuildContext context,
    {required DateTime initial}) async {
  DateTime tentative = initial;
  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (ctx) => Container(
      height: 280,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(tentative),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: initial,
                mode: CupertinoDatePickerMode.date,
                onDateTimeChanged: (v) => tentative = v,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<int?> _pickCount(BuildContext context, {required int initial}) async {
  int tentative = initial;
  return showCupertinoModalPopup<int>(
    context: context,
    builder: (ctx) => Container(
      height: 240,
      color: CupertinoColors.systemBackground.resolveFrom(ctx),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () => Navigator.of(ctx).pop(tentative),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 36,
                scrollController:
                    FixedExtentScrollController(initialItem: initial - 1),
                onSelectedItemChanged: (i) => tentative = i + 1,
                children: [
                  for (int i = 1; i <= 365; i++)
                    Center(child: Text('$i 次')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IntervalStepper extends StatelessWidget {
  const _IntervalStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          child: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: value < 99 ? () => onChanged(value + 1) : null,
          child: const Icon(CupertinoIcons.add_circled),
        ),
      ],
    );
  }
}

class _WeekdayChips extends StatelessWidget {
  const _WeekdayChips({required this.selected, required this.onToggle});
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  static const _labels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (int i = 1; i <= 7; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(i),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected.contains(i)
                      ? accent
                      : CupertinoColors.systemGrey5.resolveFrom(context),
                ),
                child: Text(
                  _labels[i - 1],
                  style: TextStyle(
                    color: selected.contains(i)
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
