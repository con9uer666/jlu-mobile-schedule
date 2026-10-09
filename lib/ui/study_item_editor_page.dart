import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/study_item.dart';
import '../state/schedule_providers.dart';
import '../state/study_providers.dart';

class StudyItemEditorPage extends ConsumerStatefulWidget {
  const StudyItemEditorPage({
    super.key,
    required this.kind,
    this.existing,
    this.draft,
  });
  final StudyItemKind kind;
  final StudyItem? existing;
  final StudyItem? draft;

  @override
  ConsumerState<StudyItemEditorPage> createState() =>
      _StudyItemEditorPageState();
}

class _StudyItemEditorPageState extends ConsumerState<StudyItemEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _submission;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  late List<int> _reminders;
  String? _courseId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final item = widget.existing ?? widget.draft;
    final now = DateTime.now();
    final defaultAt = DateTime(now.year, now.month, now.day + 1, 22);
    _title = TextEditingController(text: item?.title ?? '');
    _location = TextEditingController(text: item?.location ?? '');
    _submission = TextEditingController(text: item?.submissionMethod ?? '');
    _start = item?.startAt ?? defaultAt;
    _end = item?.endAt ?? defaultAt.add(const Duration(hours: 2));
    _allDay = item?.allDay ?? false;
    _reminders = List<int>.from(
      item?.reminderMinutes ?? StudyItem.defaultReminders(widget.kind),
    );
    _courseId = item?.courseId;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _submission.dispose();
    super.dispose();
  }

  String get _kindName => switch (widget.kind) {
    StudyItemKind.assignment => '作业',
    StudyItemKind.exam => '考试',
    StudyItemKind.personal => '个人待办',
  };

  String _reminderLabel(int minutes) {
    if (minutes >= 1440 && minutes % 1440 == 0) {
      return '提前${minutes ~/ 1440}天';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      return '提前${minutes ~/ 60}小时';
    }
    return '提前$minutes分钟';
  }

  Future<void> _pickReminders() async {
    var selected = List<int>.from(_reminders);
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => CupertinoActionSheet(
          title: const Text('提醒时间'),
          message: const Text('可以选择多个提醒时间'),
          actions: [
            for (final minutes in const [10, 30, 60, 120, 1440, 2880])
              CupertinoActionSheetAction(
                onPressed: () {
                  setSheetState(() {
                    if (selected.contains(minutes)) {
                      selected.remove(minutes);
                    } else {
                      selected.add(minutes);
                      selected.sort((a, b) => b.compareTo(a));
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28,
                      child: selected.contains(minutes)
                          ? const Icon(CupertinoIcons.check_mark)
                          : null,
                    ),
                    Text(_reminderLabel(minutes)),
                  ],
                ),
              ),
            CupertinoActionSheetAction(
              onPressed: () => setSheetState(selected.clear),
              child: const Text('不提醒'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () {
              setState(() => _reminders = selected);
              Navigator.pop(ctx);
            },
            child: const Text('完成'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '请输入标题');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final old = widget.existing;
      final item = StudyItem(
        id:
            old?.id ??
            widget.draft?.id ??
            'study_${DateTime.now().microsecondsSinceEpoch}',
        kind: widget.kind,
        title: title,
        startAt: _allDay
            ? DateTime(_start.year, _start.month, _start.day)
            : _start,
        endAt: widget.kind == StudyItemKind.exam ? _end : null,
        courseId: widget.kind == StudyItemKind.personal ? null : _courseId,
        location:
            widget.kind == StudyItemKind.exam &&
                _location.text.trim().isNotEmpty
            ? _location.text.trim()
            : null,
        submissionMethod:
            widget.kind == StudyItemKind.assignment &&
                _submission.text.trim().isNotEmpty
            ? _submission.text.trim()
            : null,
        allDay: _allDay,
        reminderMinutes: _reminders,
        completedAt: old?.completedAt,
        createdAt: old?.createdAt,
      );
      await ref.read(studyItemsControllerProvider).save(item);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool end) async {
    var value = end ? _end : _start;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 320,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    child: const Text('取消'),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    child: const Text('完成'),
                    onPressed: () {
                      setState(() {
                        if (end)
                          _end = value.isBefore(_start)
                              ? _start.add(const Duration(hours: 1))
                              : value;
                        else {
                          final duration = _end.difference(_start);
                          _start = value;
                          _end = value.add(duration);
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  initialDateTime: value,
                  mode: _allDay
                      ? CupertinoDatePickerMode.date
                      : CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: true,
                  onDateTimeChanged: (v) => value = v,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickCourse(List<Course> courses) async {
    final value = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('所属课程'),
        actions: [
          for (final c in courses)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(ctx, c.id),
              child: Text(c.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
      ),
    );
    if (value != null) setState(() => _courseId = value);
  }

  String _courseName(List<Course> courses) {
    for (final c in courses) {
      if (c.id == _courseId) return c.name;
    }
    return '未选择';
  }

  @override
  Widget build(BuildContext context) {
    final courses =
        ref.watch(coursesProvider).asData?.value ?? const <Course>[];
    final isExam = widget.kind == StudyItemKind.exam;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.existing == null ? '新建$_kindName' : '编辑$_kindName'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _saving ? null : _save,
          child: _saving
              ? const CupertinoActivityIndicator()
              : const Text('保存'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoTextFormFieldRow(
                  prefix: const Text('标题'),
                  placeholder: '$_kindName名称',
                  controller: _title,
                ),
                if (widget.kind != StudyItemKind.personal)
                  CupertinoListTile(
                    title: const Text('所属课程'),
                    additionalInfo: Text(_courseName(courses)),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickCourse(courses),
                  ),
                if (isExam)
                  CupertinoTextFormFieldRow(
                    prefix: const Text('考场'),
                    placeholder: '选填',
                    controller: _location,
                  ),
                if (widget.kind == StudyItemKind.assignment)
                  CupertinoTextFormFieldRow(
                    prefix: const Text('提交方式'),
                    placeholder: '如 学习通、纸质',
                    controller: _submission,
                  ),
              ],
            ),
            CupertinoListSection.insetGrouped(
              children: [
                CupertinoListTile(
                  title: Text(isExam ? '开始时间' : '时间'),
                  additionalInfo: Text(
                    DateFormat(
                      _allDay ? 'yyyy/M/d' : 'yyyy/M/d HH:mm',
                    ).format(_start),
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: () => _pickDate(false),
                ),
                if (isExam)
                  CupertinoListTile(
                    title: const Text('结束时间'),
                    additionalInfo: Text(
                      DateFormat('yyyy/M/d HH:mm').format(_end),
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickDate(true),
                  ),
                if (!isExam)
                  CupertinoListTile(
                    title: const Text('全天'),
                    trailing: CupertinoSwitch(
                      value: _allDay,
                      onChanged: (v) => setState(() => _allDay = v),
                    ),
                  ),
                CupertinoListTile(
                  title: const Text('提醒'),
                  additionalInfo: Text(
                    _reminders.isEmpty
                        ? '关闭'
                        : _reminders.map(_reminderLabel).join('、'),
                    maxLines: 2,
                  ),
                  trailing: const CupertinoListTileChevron(),
                  onTap: _pickReminders,
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            if (widget.existing != null)
              CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: const Text(
                      '删除',
                      style: TextStyle(color: CupertinoColors.systemRed),
                    ),
                    onTap: () async {
                      await ref
                          .read(studyItemsControllerProvider)
                          .delete(widget.existing!.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
