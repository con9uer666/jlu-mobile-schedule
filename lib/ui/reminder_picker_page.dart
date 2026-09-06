import 'package:flutter/cupertino.dart';

import '../data/reminder.dart';

class ReminderPickerPage extends StatefulWidget {
  const ReminderPickerPage({super.key, this.initial});

  final List<Reminder>? initial;

  @override
  State<ReminderPickerPage> createState() => _ReminderPickerPageState();
}

class _ReminderPickerPageState extends State<ReminderPickerPage> {
  late List<Reminder> _reminders;

  @override
  void initState() {
    super.initState();
    _reminders = widget.initial == null
        ? <Reminder>[]
        : widget.initial!.map(_copy).toList();
  }

  Reminder _copy(Reminder r) => Reminder(amount: r.amount, unit: r.unit);

  void _save() {
    Navigator.of(context).pop(_reminders);
  }

  Future<void> _addPreset(Reminder r) async {
    setState(() => _reminders.add(r));
  }

  Future<void> _addCustom() async {
    int amount = 5;
    ReminderUnit unit = ReminderUnit.minute;
    final added = await showCupertinoModalPopup<Reminder>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Container(
          height: 320,
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
                        onPressed: () => Navigator.of(ctx)
                            .pop(Reminder(amount: amount, unit: unit)),
                        child: const Text('完成'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoSlidingSegmentedControl<ReminderUnit>(
                    groupValue: unit,
                    children: const {
                      ReminderUnit.minute: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('分钟'),
                      ),
                      ReminderUnit.hour: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('小时'),
                      ),
                      ReminderUnit.day: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('天'),
                      ),
                      ReminderUnit.week: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text('周'),
                      ),
                    },
                    onValueChanged: (v) {
                      if (v != null) setLocal(() => unit = v);
                    },
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 36,
                    scrollController:
                        FixedExtentScrollController(initialItem: amount - 1),
                    onSelectedItemChanged: (i) => setLocal(() => amount = i + 1),
                    children: [
                      for (int i = 1; i <= 60; i++) Center(child: Text('$i')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (added != null) {
      setState(() => _reminders.add(added));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('提醒'),
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
              header: const Text('已添加'),
              children: [
                if (_reminders.isEmpty)
                  const CupertinoListTile(
                    title: Text(
                      '尚未添加提醒',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  ),
                for (int i = 0; i < _reminders.length; i++)
                  CupertinoListTile(
                    title: Text(_reminders[i].label()),
                    trailing: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () =>
                          setState(() => _reminders.removeAt(i)),
                      child: const Icon(
                        CupertinoIcons.minus_circle_fill,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              header: const Text('添加预设'),
              children: [
                _preset('准时', Reminder(amount: 0, unit: ReminderUnit.minute)),
                _preset('提前 5 分钟',
                    Reminder(amount: 5, unit: ReminderUnit.minute)),
                _preset('提前 10 分钟',
                    Reminder(amount: 10, unit: ReminderUnit.minute)),
                _preset('提前 15 分钟',
                    Reminder(amount: 15, unit: ReminderUnit.minute)),
                _preset('提前 30 分钟',
                    Reminder(amount: 30, unit: ReminderUnit.minute)),
                _preset(
                    '提前 1 小时', Reminder(amount: 1, unit: ReminderUnit.hour)),
                _preset('提前 1 天', Reminder(amount: 1, unit: ReminderUnit.day)),
                CupertinoListTile(
                  title: const Text(
                    '自定义…',
                    style: TextStyle(color: CupertinoColors.activeBlue),
                  ),
                  onTap: _addCustom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _preset(String label, Reminder r) {
    return CupertinoListTile(
      title: Text(label),
      onTap: () => _addPreset(r),
    );
  }
}
