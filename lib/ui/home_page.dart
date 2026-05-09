import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/semester.dart';
import '../state/schedule_providers.dart';
import 'course_colors.dart';
import 'course_detail_sheet.dart';
import 'course_editor_page.dart';
import 'import_page.dart';
import 'semester_setup_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  PageController? _pageController;
  int? _displayedWeek;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensureController(int totalWeeks, int initialWeek) {
    if (_pageController == null) {
      _pageController = PageController(initialPage: initialWeek - 1);
      _displayedWeek = initialWeek;
    }
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(currentSemesterProvider);
    final coursesAsync = ref.watch(coursesProvider);

    if (semester == null) {
      return const SemesterSetupPage(isInitial: true);
    }

    final realWeek = semester.currentWeek(DateTime.now());
    _ensureController(semester.totalWeeks, realWeek);
    final shownWeek = _displayedWeek ?? realWeek;

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              semester: semester,
              week: shownWeek,
              realWeek: realWeek,
              onAdd: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const CourseEditorPage()),
              ),
              onImport: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const ImportPage()),
              ),
              onSettings: () => Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const SemesterSetupPage()),
              ),
              onJumpToCurrent: () {
                _pageController?.animateToPage(
                  realWeek - 1,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
            Expanded(
              child: coursesAsync.when(
                data: (courses) => PageView.builder(
                  controller: _pageController,
                  itemCount: semester.totalWeeks,
                  onPageChanged: (i) => setState(() => _displayedWeek = i + 1),
                  itemBuilder: (_, i) => RepaintBoundary(
                    child: _WeekGrid(
                      courses: courses,
                      semester: semester,
                      week: i + 1,
                    ),
                  ),
                ),
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.semester,
    required this.week,
    required this.realWeek,
    required this.onAdd,
    required this.onImport,
    required this.onSettings,
    required this.onJumpToCurrent,
  });

  final Semester semester;
  final int week;
  final int realWeek;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onSettings;
  final VoidCallback onJumpToCurrent;

  @override
  Widget build(BuildContext context) {
    final weekStart = semester.startDate.add(Duration(days: (week - 1) * 7));
    final weekEnd = weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('M/d');
    final isCurrent = week == realWeek;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator
                .resolveFrom(context)
                .withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: isCurrent ? null : onJumpToCurrent,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '第 $week 周',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemIndigo
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '回到本周',
                            style: TextStyle(
                              fontSize: 10,
                              color: CupertinoColors.systemIndigo,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmt.format(weekStart)} – ${fmt.format(weekEnd)} · ${semester.name}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onImport,
            child: const Icon(CupertinoIcons.cloud_download),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onAdd,
            child: const Icon(CupertinoIcons.add_circled),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onSettings,
            child: const Icon(CupertinoIcons.slider_horizontal_3),
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.courses,
    required this.semester,
    required this.week,
  });

  final List<Course> courses;
  final Semester semester;
  final int week;

  static const double _headerHeight = 36;
  static const double _timeColWidth = 34;

  @override
  Widget build(BuildContext context) {
    final activeCourses = courses.where((c) => c.activeInWeek(week)).toList();
    final weekStart = semester.startDate.add(Duration(days: (week - 1) * 7));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _timeColWidth;
        final dayWidth = availableWidth / 7;
        const sectionHeight = 60.0;
        final gridHeight = sectionHeight * semester.sectionCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            children: [
              SizedBox(
                height: _headerHeight,
                child: Row(
                  children: [
                    const SizedBox(width: _timeColWidth),
                    for (var i = 0; i < 7; i++)
                      SizedBox(
                        width: dayWidth,
                        child: _DayHeader(
                          date: days[i],
                          isToday: _sameDay(days[i], today),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: gridHeight,
                child: Stack(
                  children: [
                    _GridBackground(
                      sectionCount: semester.sectionCount,
                      sectionHeight: sectionHeight,
                      dayWidth: dayWidth,
                    ),
                    for (final c in activeCourses)
                      Positioned(
                        left: _timeColWidth + dayWidth * (c.dayOfWeek - 1),
                        top: sectionHeight * (c.startSection - 1),
                        width: dayWidth,
                        height: sectionHeight * (c.endSection - c.startSection + 1),
                        child: _CourseBlock(course: c),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.isToday});

  final DateTime date;
  final bool isToday;

  static const _names = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '周${_names[date.weekday - 1]}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isToday ? CupertinoColors.systemIndigo : CupertinoColors.label,
          ),
        ),
        Text(
          DateFormat('M/d').format(date),
          style: TextStyle(
            fontSize: 11,
            color: isToday
                ? CupertinoColors.systemIndigo
                : CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }
}

class _GridBackground extends StatelessWidget {
  const _GridBackground({
    required this.sectionCount,
    required this.sectionHeight,
    required this.dayWidth,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.3);
    final sectionLabelColor =
        CupertinoColors.label.resolveFrom(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(
        sectionCount: sectionCount,
        sectionHeight: sectionHeight,
        dayWidth: dayWidth,
        timeColWidth: _WeekGrid._timeColWidth,
        lineColor: lineColor,
        labelColor: sectionLabelColor,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.sectionCount,
    required this.sectionHeight,
    required this.dayWidth,
    required this.timeColWidth,
    required this.lineColor,
    required this.labelColor,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;
  final double timeColWidth;
  final Color lineColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;
    // 竖线:7 列 + 左侧时间列
    for (var d = 0; d <= 7; d++) {
      final x = timeColWidth + dayWidth * d;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 横线:每节一条
    for (var i = 0; i <= sectionCount; i++) {
      final y = sectionHeight * i;
      canvas.drawLine(
        Offset(timeColWidth, y),
        Offset(size.width, y),
        paint,
      );
    }
    // 节次编号
    final textStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: labelColor,
    );
    for (var i = 1; i <= sectionCount; i++) {
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: textStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          (timeColWidth - tp.width) / 2,
          sectionHeight * (i - 1) + (sectionHeight - tp.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.sectionCount != sectionCount ||
      old.sectionHeight != sectionHeight ||
      old.dayWidth != dayWidth ||
      old.lineColor != lineColor ||
      old.labelColor != labelColor;
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final (bg, accent) = CourseColors.pick(course.colorIndex);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: () => showCourseDetailSheet(context, course),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(color: accent, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(5, 5, 4, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  course.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent.withValues(alpha: 0.75),
                    fontSize: 10,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
