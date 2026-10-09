import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/event_item.dart';
import '../data/semester.dart';
import '../data/storage.dart';
import '../data/study_item.dart';
import '../services/notification_service.dart';
import '../services/recurrence.dart';
import '../state/agenda_providers.dart';
import '../state/schedule_providers.dart';
import '../state/study_providers.dart';
import 'course_detail_sheet.dart';
import 'event_editor_page.dart';
import 'quick_add_page.dart';
import 'study_item_editor_page.dart';

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
    const key = 'notif_perm_asked';
    if (AppStorage.settings.get(key) == true || !mounted) return;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('开启通知'),
        content: const Text('用于提醒课程、作业、考试和个人待办。可以在系统设置中随时关闭。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('暂不'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('好的'),
          ),
        ],
      ),
    );
    await AppStorage.settings.put(key, true);
    if (ok == true) await NotificationService.requestPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(currentSemesterProvider);
    final courses =
        ref.watch(coursesProvider).asData?.value ?? const <Course>[];
    final overrides =
        ref.watch(overridesProvider).asData?.value ?? const <CourseOverride>[];
    final study = ref.watch(studyItemsProvider);
    final events =
        ref.watch(eventsProvider).asData?.value ?? const <EventItem>[];
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('今日'),
                backgroundColor: CupertinoColors.systemBackground
                    .resolveFrom(context)
                    .withValues(alpha: 0.7),
                border: null,
              ),
              study.when(
                loading: () => const SliverFillRemaining(
                  child: Center(child: CupertinoActivityIndicator()),
                ),
                error: (e, _) =>
                    SliverFillRemaining(child: Center(child: Text('加载失败：$e'))),
                data: (items) {
                  final timeline = _timeline(
                    semester,
                    courses,
                    overrides,
                    events,
                    items,
                  );
                  if (timeline.isEmpty) return const _EmptyToday();
                  return SliverPadding(
                    padding: const EdgeInsets.only(bottom: 180),
                    sliver: SliverList.list(
                      children: [
                        _TodaySummary(items: timeline),
                        CupertinoListSection.insetGrouped(
                          header: const Text('时间线'),
                          children: [
                            for (final item in timeline)
                              _TimelineRow(item: item),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoTheme.of(context).primaryColor,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.all(15),
                  onPressed: () => showStudyAddMenu(context),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_TimelineItem> _timeline(
    Semester? semester,
    List<Course> courses,
    List<CourseOverride> overrides,
    List<EventItem> events,
    List<StudyItem> studyItems,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final result = <_TimelineItem>[];
    if (semester != null) {
      final week = semester.currentWeek(today);
      final weekStart = today.subtract(Duration(days: today.weekday - 1));
      final effective = effectiveCoursesForWeek(
        courses,
        overrides,
        week,
        weekStart: weekStart,
      );
      for (final entry in effective.where(
        (e) => e.dayOfWeek == today.weekday,
      )) {
        final start = _clock(today, semester.sectionStart(entry.startSection));
        final end = _clock(today, semester.sectionEnd(entry.endSection));
        if (start != null)
          result.add(
            _TimelineItem.course(entry.course, start, end, entry.location),
          );
      }
    }
    for (final event in events) {
      final occurrences = expandOccurrences(
        event: event,
        windowStart: today,
        windowEnd: tomorrow,
        maxCount: 8,
      );
      for (final occurrence in occurrences) {
        if (occurrence.startAt.isBefore(tomorrow))
          result.add(_TimelineItem.event(event, occurrence.startAt));
      }
    }
    for (final item in studyItems) {
      final day = DateTime(
        item.startAt.year,
        item.startAt.month,
        item.startAt.day,
      );
      final completedToday =
          item.completedAt != null &&
          DateTime(
                item.completedAt!.year,
                item.completedAt!.month,
                item.completedAt!.day,
              ) ==
              today;
      var include = completedToday;
      if (!item.isCompleted) {
        include = switch (item.kind) {
          StudyItemKind.assignment =>
            (day.isBefore(today) && today.difference(day).inDays <= 3) ||
                (!day.isBefore(today) &&
                    day.isBefore(today.add(const Duration(days: 4)))),
          StudyItemKind.exam =>
            !day.isBefore(today) &&
                day.isBefore(today.add(const Duration(days: 8))),
          StudyItemKind.personal =>
            day == today ||
                (day.isBefore(today) && today.difference(day).inDays <= 3),
        };
      }
      if (include)
        result.add(
          _TimelineItem.study(
            item,
            overdue: day.isBefore(today) && !item.isCompleted,
          ),
        );
    }
    result.sort((a, b) {
      if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.at.compareTo(b.at);
    });
    return result;
  }

  DateTime? _clock(DateTime day, String value) {
    final p = value.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return h == null || m == null
        ? null
        : DateTime(day.year, day.month, day.day, h, m);
  }
}

enum _TimelineKind { course, event, study }

class _TimelineItem {
  _TimelineItem.course(this.course, this.at, this.endAt, this.location)
    : kind = _TimelineKind.course,
      event = null,
      study = null,
      allDay = false,
      overdue = false;
  _TimelineItem.event(this.event, this.at)
    : kind = _TimelineKind.event,
      course = null,
      study = null,
      endAt = null,
      location = event?.location,
      allDay = event?.allDay ?? false,
      overdue = false;
  _TimelineItem.study(this.study, {required this.overdue})
    : kind = _TimelineKind.study,
      course = null,
      event = null,
      at = study!.startAt,
      endAt = study.endAt,
      location = study.location,
      allDay = study.allDay;
  final _TimelineKind kind;
  final Course? course;
  final EventItem? event;
  final StudyItem? study;
  final DateTime at;
  final DateTime? endAt;
  final String? location;
  final bool allDay;
  final bool overdue;
  String get title => course?.name ?? event?.title ?? study!.title;
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.items});
  final List<_TimelineItem> items;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final remaining = items
        .where((i) => i.endAt?.isAfter(now) ?? i.at.isAfter(now))
        .length;
    final overdue = items.where((i) => i.overdue).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      child: Row(
        children: [
          Text(
            '今天共 ${items.length} 项',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '剩余 $remaining 项',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const Spacer(),
          if (overdue > 0)
            Text(
              '$overdue 项逾期',
              style: const TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemRed,
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  const _TimelineRow({required this.item});
  final _TimelineItem item;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final study = item.study;
    final completed = study?.isCompleted ?? false;
    final color = item.overdue ? CupertinoColors.systemRed : _color(item);
    return CupertinoListTile(
      leading: study != null && study.kind != StudyItemKind.exam
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => ref
                  .read(studyItemsControllerProvider)
                  .setCompleted(study, !completed),
              child: Icon(
                completed
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                color: completed ? CupertinoColors.systemGreen : color,
              ),
            )
          : Icon(_icon(item), color: color, size: 21),
      title: Text(
        item.title,
        style: TextStyle(
          decoration: completed ? TextDecoration.lineThrough : null,
          color: completed
              ? CupertinoColors.secondaryLabel.resolveFrom(context)
              : null,
        ),
      ),
      subtitle: item.location?.isNotEmpty == true
          ? Text(item.location!)
          : _subtitle(item),
      additionalInfo: Text(
        item.overdue
            ? '逾期'
            : item.allDay
            ? '全天'
            : DateFormat('M/d HH:mm').format(item.at),
        style: TextStyle(
          color: item.overdue ? CupertinoColors.systemRed : null,
        ),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: () {
        if (item.course != null) {
          showCourseDetailSheet(context, item.course!);
          return;
        }
        if (item.event != null) {
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => EventEditorPage(existing: item.event!),
            ),
          );
          return;
        }
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) =>
                StudyItemEditorPage(kind: study!.kind, existing: study),
          ),
        );
      },
    );
  }

  Widget? _subtitle(_TimelineItem item) {
    final study = item.study;
    if (study?.submissionMethod?.isNotEmpty == true)
      return Text(study!.submissionMethod!);
    if (study?.kind == StudyItemKind.exam) return const Text('考试');
    if (study?.kind == StudyItemKind.assignment) return const Text('作业');
    if (study?.kind == StudyItemKind.personal) return const Text('个人待办');
    return null;
  }

  IconData _icon(_TimelineItem item) {
    if (item.course != null) return CupertinoIcons.book_fill;
    if (item.event != null) return CupertinoIcons.calendar;
    return item.study!.kind == StudyItemKind.exam
        ? CupertinoIcons.doc_text_fill
        : CupertinoIcons.circle;
  }

  Color _color(_TimelineItem item) {
    if (item.course != null) return CupertinoColors.activeBlue;
    if (item.event != null) return CupertinoColors.systemPurple;
    return switch (item.study!.kind) {
      StudyItemKind.assignment => CupertinoColors.systemOrange,
      StudyItemKind.exam => CupertinoColors.systemRed,
      StudyItemKind.personal => CupertinoColors.systemTeal,
    };
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday();
  @override
  Widget build(BuildContext context) => SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.sun_max,
            size: 60,
            color: CupertinoColors.systemGrey3.resolveFrom(context),
          ),
          const SizedBox(height: 14),
          Text(
            '今天暂时没有安排',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
              fontSize: 17,
            ),
          ),
        ],
      ),
    ),
  );
}
