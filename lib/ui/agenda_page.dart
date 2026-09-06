import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/event_item.dart';
import '../data/semester.dart';
import '../data/storage.dart';
import '../services/notification_service.dart';
import '../services/recurrence.dart';
import '../state/agenda_providers.dart';
import '../state/schedule_providers.dart';
import 'event_editor_page.dart';
import 'course_detail_sheet.dart';

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key});

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskPermission());
  }

  Future<void> _maybeAskPermission() async {
    const askedKey = 'notif_perm_asked';
    final asked = AppStorage.settings.get(askedKey) == true;
    if (asked) return;
    if (!mounted) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('开启通知'),
        content: const Text('用于到点提醒你的日程和课程。可以在系统设置中随时关闭。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('暂不'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('好的'),
          ),
        ],
      ),
    );
    await AppStorage.settings.put(askedKey, true);
    if (ok == true) {
      await NotificationService.requestPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final semester = ref.watch(currentSemesterProvider);
    final coursesAsync = ref.watch(coursesProvider);
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('日程'),
            backgroundColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            border: null,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const EventEditorPage()),
              ),
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          eventsAsync.when(
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('加载失败:$e')),
            ),
            data: (events) {
              final courses = coursesAsync.asData?.value ?? const <Course>[];
              final groups = _buildGroups(events, courses, semester);
              if (groups.isEmpty) return const _EmptyAgenda();
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 96),
                sliver: SliverList.builder(
                  itemCount: groups.length,
                  itemBuilder: (_, i) => _DayGroup(group: groups[i]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<_DayGroupData> _buildGroups(
    List<EventItem> events,
    List<Course> courses,
    Semester? semester,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final windowStart = today;
    final windowEnd = today.add(const Duration(days: 60));
    final items = <_AgendaItem>[];

    // 展开 event occurrence
    for (final e in events) {
      final occ = expandOccurrences(
        event: e,
        windowStart: windowStart,
        windowEnd: windowEnd,
        maxCount: 60,
      );
      for (final o in occ) {
        items.add(_AgendaItem.event(event: e, startAt: o.startAt));
      }
    }

    // 加今日 + 明天的课程
    if (semester != null) {
      for (int offset = 0; offset <= 1; offset++) {
        final day = today.add(Duration(days: offset));
        final week = semester.currentWeek(day);
        if (week < 1 || week > semester.totalWeeks) continue;
        final weekday = day.weekday;
        for (final c in courses) {
          if (c.dayOfWeek != weekday) continue;
          if (!c.activeInWeek(week)) continue;
          final startStr = semester.sectionStart(c.startSection);
          final parts = startStr.split(':');
          if (parts.length != 2) continue;
          final hh = int.tryParse(parts[0]);
          final mm = int.tryParse(parts[1]);
          if (hh == null || mm == null) continue;
          final at = DateTime(day.year, day.month, day.day, hh, mm);
          items.add(_AgendaItem.course(course: c, startAt: at, semester: semester));
        }
      }
    }

    items.sort((a, b) => a.startAt.compareTo(b.startAt));
    final map = <DateTime, List<_AgendaItem>>{};
    for (final it in items) {
      final day = DateTime(it.startAt.year, it.startAt.month, it.startAt.day);
      map.putIfAbsent(day, () => []).add(it);
    }
    final keys = map.keys.toList()..sort();
    return [for (final k in keys) _DayGroupData(date: k, items: map[k]!)];
  }
}

class _AgendaItem {
  _AgendaItem.event({required this.event, required this.startAt})
      : course = null,
        endLabel = null,
        semester = null;

  _AgendaItem.course({
    required this.course,
    required this.startAt,
    required this.semester,
  })  : event = null,
        endLabel = semester!.sectionEnd(course!.endSection);

  final EventItem? event;
  final Course? course;
  final DateTime startAt;
  final String? endLabel;
  final Semester? semester;

  bool get isCourse => course != null;
}

class _DayGroupData {
  _DayGroupData({required this.date, required this.items});
  final DateTime date;
  final List<_AgendaItem> items;
}

class _DayGroup extends ConsumerWidget {
  const _DayGroup({required this.group});

  final _DayGroupData group;

  String _title() {
    final today = DateTime.now();
    final t0 = DateTime(today.year, today.month, today.day);
    final diff = group.date.difference(t0).inDays;
    final weekday =
        ['一', '二', '三', '四', '五', '六', '日'][group.date.weekday - 1];
    final base = '${group.date.month}月${group.date.day}日 周$weekday';
    if (diff == 0) return '今天 · $base';
    if (diff == 1) return '明天 · $base';
    if (diff == -1) return '昨天 · $base';
    return base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoListSection.insetGrouped(
      header: Text(_title()),
      children: [
        for (final it in group.items)
          if (it.isCourse) _CourseRow(item: it) else _EventRow(item: it),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.item});
  final _AgendaItem item;

  @override
  Widget build(BuildContext context) {
    final e = item.event!;
    return CupertinoListTile(
      title: Text(e.title),
      subtitle: e.location != null && e.location!.isNotEmpty
          ? Text(e.location!)
          : null,
      additionalInfo: Text(
        e.allDay ? '全天' : DateFormat('HH:mm').format(item.startAt),
      ),
      trailing: e.recurrence != null && !e.recurrence!.isNever
          ? const Icon(
              CupertinoIcons.repeat,
              size: 16,
              color: CupertinoColors.systemGrey,
            )
          : const CupertinoListTileChevron(),
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => EventEditorPage(existing: e)),
      ),
    );
  }
}

class _CourseRow extends ConsumerWidget {
  const _CourseRow({required this.item});
  final _AgendaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = item.course!;
    final settingAsync = ref.watch(courseReminderProvider(c.id));
    final enabled = settingAsync.asData?.value?.enabled ?? true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showCourseReminderSheet(context, ref, c),
      child: CupertinoListTile(
        leading: Icon(
          CupertinoIcons.book_fill,
          size: 18,
          color: enabled
              ? CupertinoColors.activeBlue
              : CupertinoColors.systemGrey2.resolveFrom(context),
        ),
        title: Text(c.name),
        subtitle: c.location.isNotEmpty ? Text(c.location) : null,
        additionalInfo: Text(DateFormat('HH:mm').format(item.startAt)),
        trailing: enabled
            ? Icon(
                CupertinoIcons.bell_fill,
                size: 16,
                color: CupertinoColors.activeBlue.resolveFrom(context),
              )
            : const Icon(
                CupertinoIcons.bell_slash,
                size: 16,
                color: CupertinoColors.systemGrey,
              ),
        onTap: () => showCourseDetailSheet(context, c),
      ),
    );
  }

  void _showCourseReminderSheet(BuildContext context, WidgetRef ref, Course c) {
    final ctrl = ref.read(courseReminderControllerProvider);
    final setting = AppStorage.courseReminders.get(c.id);
    final enabled = setting?.enabled ?? true;
    final lead = setting?.leadMinutes ?? 10;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(c.name),
        message: Text(enabled ? '当前提前 $lead 分钟提醒' : '当前未开启提醒'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              await ctrl.setEnabled(c.id, !enabled);
              if (context.mounted) Navigator.of(ctx).pop();
            },
            child: Text(enabled ? '关闭提醒' : '开启提醒'),
          ),
          for (final m in const [5, 10, 15, 30])
            CupertinoActionSheetAction(
              onPressed: () async {
                await ctrl.setLead(c.id, m);
                await ctrl.setEnabled(c.id, true);
                if (context.mounted) Navigator.of(ctx).pop();
              },
              child: Text('提前 $m 分钟'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.calendar_badge_plus,
              size: 64,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无日程',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
