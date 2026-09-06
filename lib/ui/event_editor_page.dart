import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/event_item.dart';
import '../data/recurrence_rule.dart';
import '../data/reminder.dart';
import '../services/notification_service.dart';
import '../state/agenda_providers.dart';
import 'recurrence_picker_page.dart';
import 'reminder_picker_page.dart';

class EventEditorPage extends ConsumerStatefulWidget {
  const EventEditorPage({super.key, this.existing, this.initialDate});

  final EventItem? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends ConsumerState<EventEditorPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _locationCtrl;
  late bool _allDay;
  late DateTime _startAt;
  late DateTime _endAt;
  RecurrenceRule? _recurrence;
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _locationCtrl = TextEditingController(text: e?.location ?? '');
    _allDay = e?.allDay ?? false;
    final now = widget.initialDate ?? DateTime.now();
    final anchor = DateTime(now.year, now.month, now.day, now.hour + 1);
    _startAt = e?.startAt ?? anchor;
    _endAt = e?.endAt ?? anchor.add(const Duration(hours: 1));
    _recurrence = e?.recurrence;
    _reminders = e?.reminders.map((r) => Reminder(amount: r.amount, unit: r.unit)).toList() ?? <Reminder>[];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    final e = widget.existing;
    final event = EventItem(
      id: e?.id ?? 'evt_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      allDay: _allDay,
      startAt: _allDay ? _atMidnight(_startAt) : _startAt,
      endAt: _allDay ? _atMidnight(_endAt).add(const Duration(days: 1)) : _endAt,
      recurrence: _recurrence,
      reminders: _reminders,
      colorIndex: e?.colorIndex ?? 0,
      createdAt: e?.createdAt,
    );
    await ref.read(eventsControllerProvider).upsert(event);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('删除日程'),
        content: Text('确定删除"${e.title}"吗?此操作不可恢复。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await NotificationService.cancelForEvent(e.id);
    await ref.read(eventsControllerProvider).delete(e.id);
    if (mounted) Navigator.of(context).pop();
  }

  DateTime _atMidnight(DateTime t) => DateTime(t.year, t.month, t.day);

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    DateTime tentative = current;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
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
                      onPressed: () {
                        setState(() {
                          if (isStart) {
                            final delta = _endAt.difference(_startAt);
                            _startAt = tentative;
                            _endAt = _startAt.add(delta);
                          } else {
                            _endAt = tentative.isBefore(_startAt)
                                ? _startAt.add(const Duration(hours: 1))
                                : tentative;
                          }
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: current,
                  mode: _allDay
                      ? CupertinoDatePickerMode.date
                      : CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: true,
                  onDateTimeChanged: (v) => tentative = v,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime t) {
    if (_allDay) return DateFormat('y 年 M 月 d 日').format(t);
    return DateFormat('y/M/d HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(isNew ? '新建日程' : '编辑日程'),
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
                CupertinoTextFormFieldRow(
                  controller: _titleCtrl,
                  placeholder: '标题',
                  prefix: const Text('标题'),
                ),
                CupertinoTextFormFieldRow(
                  controller: _locationCtrl,
                  placeholder: '位置',
                  prefix: const Text('位置'),
                ),
                CupertinoTextFormFieldRow(
                  controller: _noteCtrl,
                  placeholder: '备注',
                  prefix: const Text('备注'),
                  maxLines: 3,
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('全天'),
                  trailing: CupertinoSwitch(
                    value: _allDay,
                    onChanged: (v) => setState(() => _allDay = v),
                  ),
                ),
                CupertinoListTile(
                  title: const Text('开始'),
                  additionalInfo: Text(_formatDateTime(_startAt)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickDateTime(isStart: true),
                ),
                CupertinoListTile(
                  title: const Text('结束'),
                  additionalInfo: Text(_formatDateTime(_endAt)),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickDateTime(isStart: false),
                ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: const Text('重复'),
                  additionalInfo: Text(
                    _recurrence == null || _recurrence!.isNever
                        ? '永不'
                        : _recurrence!.summary(),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    final r = await Navigator.of(context).push<RecurrenceRule>(
                      CupertinoPageRoute(
                        builder: (_) => RecurrencePickerPage(
                          initial: _recurrence,
                          anchor: _startAt,
                        ),
                      ),
                    );
                    if (r != null) {
                      setState(() {
                        _recurrence = r.isNever ? null : r;
                      });
                    }
                  },
                ),
                CupertinoListTile(
                  title: const Text('提醒'),
                  additionalInfo: Text(
                    _reminders.isEmpty
                        ? '无'
                        : _reminders.length == 1
                            ? _reminders.first.label()
                            : '${_reminders.length} 条',
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () async {
                    final updated =
                        await Navigator.of(context).push<List<Reminder>>(
                      CupertinoPageRoute(
                        builder: (_) => ReminderPickerPage(initial: _reminders),
                      ),
                    );
                    if (updated != null) {
                      setState(() => _reminders = updated);
                    }
                  },
                ),
              ],
            ),
            if (!isNew)
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text(
                      '删除日程',
                      style: TextStyle(color: CupertinoColors.systemRed),
                    ),
                    onTap: _delete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
