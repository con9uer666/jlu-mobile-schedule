import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/course_override.dart';
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
    final overridesAsync = ref.watch(overridesProvider);

    if (semester == null) {
      return const SemesterSetupPage(isInitial: true);
    }

    final realWeek = semester.currentWeek(DateTime.now());
    _ensureController(semester.totalWeeks, realWeek);
    final shownWeek = _displayedWeek ?? realWeek;
    final today = DateTime.now();

    return CupertinoPageScaffold(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              semester: semester,
              week: shownWeek,
              realWeek: realWeek,
              today: today,
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
                data: (courses) {
                  final overrides = overridesAsync.maybeWhen(
                    data: (v) => v,
                    orElse: () => const <CourseOverride>[],
                  );
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: semester.totalWeeks,
                    onPageChanged: (i) => setState(() => _displayedWeek = i + 1),
                    itemBuilder: (_, i) => RepaintBoundary(
                      child: _WeekGrid(
                        courses: courses,
                        overrides: overrides,
                        semester: semester,
                        week: i + 1,
                      ),
                    ),
                  );
                },
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
    required this.today,
    required this.onAdd,
    required this.onImport,
    required this.onSettings,
    required this.onJumpToCurrent,
  });

  final Semester semester;
  final int week;
  final int realWeek;
  final DateTime today;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onSettings;
  final VoidCallback onJumpToCurrent;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final isCurrent = week == realWeek;
    final dayLabel = '周${_dayNames[(today.weekday - 1).clamp(0, 6)]}';
    final dateText = '${today.year}/${today.month}/${today.day}';

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
                      const SizedBox(width: 8),
                      Text(
                        dayLabel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.systemRed,
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
                    '$dateText · ${semester.name}',
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

class _WeekGrid extends StatefulWidget {
  const _WeekGrid({
    required this.courses,
    required this.overrides,
    required this.semester,
    required this.week,
  });

  final List<Course> courses;
  final List<CourseOverride> overrides;
  final Semester semester;
  final int week;

  static const double _headerHeight = 40;
  static const double _timeColWidth = 34;
  static const double _sectionHeight = 60;

  @override
  State<_WeekGrid> createState() => _WeekGridState();
}

class _WeekGridState extends State<_WeekGrid> {
  ({int dayIdx, int startSec, int endSec})? _drag;

  @override
  Widget build(BuildContext context) {
    final effective = effectiveCoursesForWeek(
      widget.courses,
      widget.overrides,
      widget.week,
    );
    final weekStart = widget.semester.startDate
        .add(Duration(days: (widget.week - 1) * 7));
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _WeekGrid._timeColWidth;
        final dayWidth = availableWidth / 7;
        final sectionHeight = _WeekGrid._sectionHeight;
        final gridHeight = sectionHeight * widget.semester.sectionCount;

        return Column(
          children: [
            // 吸顶日期行(不进滚动体)
            SizedBox(
              height: _WeekGrid._headerHeight,
              child: Row(
                children: [
                  const SizedBox(width: _WeekGrid._timeColWidth),
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: SizedBox(
                  height: gridHeight,
                  child: Stack(
                    children: [
                      _GridBackground(
                        sectionCount: widget.semester.sectionCount,
                        sectionHeight: sectionHeight,
                        dayWidth: dayWidth,
                        sectionClock: widget.semester.sectionClock,
                      ),
                      _DragSelectionOverlay(
                        timeColWidth: _WeekGrid._timeColWidth,
                        dayWidth: dayWidth,
                        sectionHeight: sectionHeight,
                        sectionCount: widget.semester.sectionCount,
                        drag: _drag,
                        occupied: _buildOccupied(effective),
                        onTapEmpty: (dayIdx, sec) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => CourseEditorPage(
                                prefill: (
                                  dayOfWeek: dayIdx + 1,
                                  startSection: sec,
                                  endSection: sec,
                                  week: widget.week,
                                ),
                              ),
                            ),
                          );
                        },
                        onStart: (dayIdx, sec) =>
                            setState(() => _drag = (dayIdx: dayIdx, startSec: sec, endSec: sec)),
                        onUpdate: (sec) {
                          if (_drag == null) return;
                          final s = _drag!.startSec;
                          final e = sec.clamp(1, widget.semester.sectionCount);
                          setState(() =>
                              _drag = (dayIdx: _drag!.dayIdx, startSec: s, endSec: e));
                        },
                        onEnd: () {
                          final d = _drag;
                          if (d == null) return;
                          setState(() => _drag = null);
                          final start = d.startSec < d.endSec ? d.startSec : d.endSec;
                          final end = d.startSec < d.endSec ? d.endSec : d.startSec;
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => CourseEditorPage(
                                prefill: (
                                  dayOfWeek: d.dayIdx + 1,
                                  startSection: start,
                                  endSection: end,
                                  week: widget.week,
                                ),
                              ),
                            ),
                          );
                        },
                        onCancel: () => setState(() => _drag = null),
                      ),
                      for (final ec in effective)
                        Positioned(
                          left: _WeekGrid._timeColWidth +
                              dayWidth * (ec.dayOfWeek - 1),
                          top: sectionHeight * (ec.startSection - 1),
                          width: dayWidth,
                          height: sectionHeight *
                              (ec.endSection - ec.startSection + 1),
                          child: _CourseBlock(
                            effective: ec,
                            onTap: () => showCourseDetailSheet(
                              context,
                              ec.course,
                              semester: widget.semester,
                              week: widget.week,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 用一张 (day, section) → bool 表做命中检测;一次拖选前算一次。
  Set<int> _buildOccupied(List<EffectiveCourse> effective) {
    final out = <int>{};
    for (final ec in effective) {
      for (var s = ec.startSection; s <= ec.endSection; s++) {
        out.add((ec.dayOfWeek - 1) * 1000 + s);
      }
    }
    return out;
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
    if (isToday) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '周${_names[date.weekday - 1]}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: CupertinoColors.white,
                ),
              ),
              Text(
                DateFormat('M/d').format(date),
                style: const TextStyle(
                  fontSize: 11,
                  color: CupertinoColors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '周${_names[date.weekday - 1]}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label,
          ),
        ),
        Text(
          DateFormat('M/d').format(date),
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel,
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
    required this.sectionClock,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;
  final List<String> sectionClock;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        CupertinoColors.separator.resolveFrom(context).withValues(alpha: 0.3);
    final sectionLabelColor =
        CupertinoColors.label.resolveFrom(context);
    final subLabelColor =
        CupertinoColors.secondaryLabel.resolveFrom(context);
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(
        sectionCount: sectionCount,
        sectionHeight: sectionHeight,
        dayWidth: dayWidth,
        timeColWidth: _WeekGrid._timeColWidth,
        lineColor: lineColor,
        labelColor: sectionLabelColor,
        subLabelColor: subLabelColor,
        sectionClock: sectionClock,
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
    required this.subLabelColor,
    required this.sectionClock,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;
  final double timeColWidth;
  final Color lineColor;
  final Color labelColor;
  final Color subLabelColor;
  final List<String> sectionClock;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;
    for (var d = 0; d <= 7; d++) {
      final x = timeColWidth + dayWidth * d;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var i = 0; i <= sectionCount; i++) {
      final y = sectionHeight * i;
      canvas.drawLine(
        Offset(timeColWidth, y),
        Offset(size.width, y),
        paint,
      );
    }
    for (var i = 1; i <= sectionCount; i++) {
      final numSpan = TextSpan(
        text: '$i',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
      );
      final (start, end) = _splitClock(i);
      final numTp = TextPainter(text: numSpan, textDirection: ui.TextDirection.ltr)
        ..layout();
      final yTop = sectionHeight * (i - 1) + 4;
      numTp.paint(canvas, Offset((timeColWidth - numTp.width) / 2, yTop));
      if (start.isNotEmpty) {
        final startTp = TextPainter(
          text: TextSpan(
            text: start,
            style: TextStyle(fontSize: 9, color: subLabelColor),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        startTp.paint(
          canvas,
          Offset((timeColWidth - startTp.width) / 2, yTop + numTp.height + 2),
        );
        final endTp = TextPainter(
          text: TextSpan(
            text: end,
            style: TextStyle(fontSize: 9, color: subLabelColor),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        endTp.paint(
          canvas,
          Offset(
            (timeColWidth - endTp.width) / 2,
            yTop + numTp.height + 2 + startTp.height,
          ),
        );
      }
    }
  }

  (String, String) _splitClock(int section) {
    if (section < 1 || section > sectionClock.length) return ('', '');
    final parts = sectionClock[section - 1].split('-');
    if (parts.length != 2) return ('', '');
    return (parts[0], parts[1]);
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.sectionCount != sectionCount ||
      old.sectionHeight != sectionHeight ||
      old.dayWidth != dayWidth ||
      old.lineColor != lineColor ||
      old.labelColor != labelColor ||
      old.subLabelColor != subLabelColor ||
      !_listEq(old.sectionClock, sectionClock);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 透明拖选层。
/// - 单点空格子 → 直接进编辑页,单节预填。
/// - 长按空格子 → 进入拖选态(轻震动),按住再向下滑可扩展多节,松手建课。
/// - 命中已有课程块时不吃事件,让 CourseBlock 自己的 onTap 处理。
/// - 普通竖滑 / 横滑不吃,避免和 SingleChildScrollView / PageView 冲突。
class _DragSelectionOverlay extends StatelessWidget {
  const _DragSelectionOverlay({
    required this.timeColWidth,
    required this.dayWidth,
    required this.sectionHeight,
    required this.sectionCount,
    required this.drag,
    required this.occupied,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.onTapEmpty,
  });

  final double timeColWidth;
  final double dayWidth;
  final double sectionHeight;
  final int sectionCount;
  final ({int dayIdx, int startSec, int endSec})? drag;
  final Set<int> occupied;
  final void Function(int dayIdx, int sec) onStart;
  final void Function(int sec) onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onCancel;
  final void Function(int dayIdx, int sec) onTapEmpty;

  (int dayIdx, int sec)? _hit(Offset local) {
    final dx = local.dx - timeColWidth;
    if (dx < 0) return null;
    final dayIdx = (dx / dayWidth).floor();
    if (dayIdx < 0 || dayIdx > 6) return null;
    final sec = (local.dy / sectionHeight).floor() + 1;
    if (sec < 1 || sec > sectionCount) return null;
    return (dayIdx, sec);
  }

  bool _isOccupied(int dayIdx, int sec) =>
      occupied.contains(dayIdx * 1000 + sec);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        // translucent: 空白区吃事件,但不吞掉纵/横滑;有现存 GestureRecognizer
        // 竞争时,长按 / tap 比 scroll 优先级高,竖滑不命中。
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          final hit = _hit(d.localPosition);
          if (hit == null) return;
          if (_isOccupied(hit.$1, hit.$2)) return;
          onTapEmpty(hit.$1, hit.$2);
        },
        onLongPressStart: (d) {
          final hit = _hit(d.localPosition);
          if (hit == null) return;
          if (_isOccupied(hit.$1, hit.$2)) return;
          HapticFeedback.mediumImpact();
          onStart(hit.$1, hit.$2);
        },
        onLongPressMoveUpdate: (d) {
          if (drag == null) return;
          final sec = (d.localPosition.dy / sectionHeight).floor() + 1;
          onUpdate(sec);
        },
        onLongPressEnd: (_) {
          if (drag != null) onEnd();
        },
        onLongPressCancel: onCancel,
        child: drag == null
            ? const SizedBox.shrink()
            : Stack(
                children: [
                  Positioned(
                    left: timeColWidth + dayWidth * drag!.dayIdx + 2,
                    top: sectionHeight *
                            ((drag!.startSec < drag!.endSec
                                    ? drag!.startSec
                                    : drag!.endSec) -
                                1) +
                        2,
                    width: dayWidth - 4,
                    height: sectionHeight *
                            ((drag!.startSec - drag!.endSec).abs() + 1) -
                        4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemIndigo.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoColors.systemIndigo,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({required this.effective, required this.onTap});

  final EffectiveCourse effective;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (_, accent) = CourseColors.pick(effective.course.colorIndex);
    return Padding(
      padding: const EdgeInsets.all(2),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      effective.course.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (effective.location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        effective.location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: CupertinoColors.white.withValues(alpha: 0.85),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (effective.isAdjusted)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
