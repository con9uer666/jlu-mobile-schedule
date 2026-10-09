import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/course.dart';
import '../data/course_override.dart';
import '../data/semester.dart';
import '../services/section_time.dart';
import '../state/schedule_providers.dart';
import 'course_colors.dart';
import 'course_detail_sheet.dart';
import 'course_editor_page.dart';
import 'import_page.dart';
import 'semester_setup_page.dart';
import 'settings_page.dart';
import 'widgets/glass_pill.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  PageController? _pageController;
  int? _displayedWeek;
  bool _pushedInitialSetup = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
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
      if (!_pushedInitialSetup) {
        _pushedInitialSetup = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (_) => const SemesterSetupPage(isInitial: true),
            ),
          );
        });
      }
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }
    _pushedInitialSetup = false;

    final realWeek = semester.currentWeek(DateTime.now());
    _ensureController(
      semester.totalWeeks,
      realWeek.clamp(1, semester.totalWeeks),
    );
    final shownWeek = _displayedWeek ?? realWeek;
    final today = DateTime.now();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: coursesAsync.when(
                data: (courses) {
                  final overrides = overridesAsync.maybeWhen(
                    data: (v) => v,
                    orElse: () => const <CourseOverride>[],
                  );
                  return PageView.builder(
                    controller: _pageController,
                    itemCount: semester.totalWeeks,
                    onPageChanged: (i) =>
                        setState(() => _displayedWeek = i + 1),
                    itemBuilder: (_, i) => RepaintBoundary(
                      child: _WeekGrid(
                        courses: courses,
                        overrides: overrides,
                        semester: semester,
                        week: i + 1,
                        isCurrentWeek: (i + 1) == realWeek,
                      ),
                    ),
                  );
                },
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(child: Text('$e')),
              ),
            ),
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: _TopBar(
                semester: semester,
                week: shownWeek,
                realWeek: realWeek,
                today: today,
                status: shownWeek == realWeek
                    ? currentStatus(semester, today)
                    : null,
                onAdd: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const CourseEditorPage()),
                ),
                onImport: () => Navigator.of(
                  context,
                ).push(CupertinoPageRoute(builder: (_) => const ImportPage())),
                onSettings: () => Navigator.of(context).push(
                  CupertinoPageRoute(builder: (_) => const SettingsPage()),
                ),
                onJumpToCurrent: () {
                  _pageController?.animateToPage(
                    realWeek - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  );
                },
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
    required this.status,
    required this.onAdd,
    required this.onImport,
    required this.onSettings,
    required this.onJumpToCurrent,
  });

  final Semester semester;
  final int week;
  final int realWeek;
  final DateTime today;
  final SectionStatus? status;
  final VoidCallback onAdd;
  final VoidCallback onImport;
  final VoidCallback onSettings;
  final VoidCallback onJumpToCurrent;

  static const _dayNames = ['一', '二', '三', '四', '五', '六', '日'];

  String _subtitle() {
    if (status == null) {
      return '${today.month}/${today.day} · ${semester.name}';
    }
    final s = status!;
    if (s.inClass) {
      final m = s.toEnd!.inMinutes;
      return '第 ${s.section} 节进行中 · 距下课 $m 分钟';
    }
    if (s.inBreak) {
      final m = s.toNext!.inMinutes;
      if (m < 60) return '距下节课 $m 分钟';
      final h = m ~/ 60;
      final r = m % 60;
      return '距下节课 ${h}h${r}m';
    }
    return '今日无课';
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = week == realWeek;
    final dayLabel = '周${_dayNames[(today.weekday - 1).clamp(0, 6)]}';
    final accent = CupertinoTheme.of(context).primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: GlassPill(
              radius: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isCurrent ? null : onJumpToCurrent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            week == 0 ? '未开学' : '第 $week 周',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dayLabel,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                          if (!isCurrent) ...[
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.arrow_uturn_left_circle_fill,
                              size: 16,
                              color: CupertinoDynamicColor.resolve(
                                accent,
                                context,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _subtitle(),
                        style: TextStyle(
                          fontSize: 11,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GlassPill(
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PillIconButton(
                    icon: CupertinoIcons.cloud_download,
                    onTap: onImport,
                  ),
                  _PillIconButton(
                    icon: CupertinoIcons.add_circled,
                    onTap: onAdd,
                  ),
                  _PillIconButton(
                    icon: CupertinoIcons.slider_horizontal_3,
                    onTap: onSettings,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(
          icon,
          size: 20,
          color: CupertinoColors.label.resolveFrom(context),
        ),
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
    required this.isCurrentWeek,
  });

  final List<Course> courses;
  final List<CourseOverride> overrides;
  final Semester semester;
  final int week;
  final bool isCurrentWeek;

  static const double _headerHeight = 40;
  static const double _timeColWidth = 44;

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
      weekStart: widget.semester.startDate.add(
        Duration(days: (widget.week - 1) * 7),
      ),
    );
    final weekStart = widget.semester.startDate.add(
      Duration(days: (widget.week - 1) * 7),
    );
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - _WeekGrid._timeColWidth;
        final dayWidth = availableWidth / 7;
        // 网格可用高度:总高 - 顶部日期行 - 底部浮动 Tab Bar 留白。
        const reservedBottom = 96.0;
        final available =
            constraints.maxHeight - _WeekGrid._headerHeight - reservedBottom;
        final autoHeight = available / widget.semester.sectionCount;
        final sectionHeight = autoHeight.clamp(36.0, 60.0);
        final gridHeight = sectionHeight * widget.semester.sectionCount;
        final currentSection = widget.isCurrentWeek
            ? currentStatus(widget.semester, DateTime.now()).section
            : null;
        final accent = CupertinoTheme.of(context).primaryColor;
        final accentResolved = CupertinoDynamicColor.resolve(accent, context);

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
                padding: EdgeInsets.zero,
                physics: gridHeight <= available
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                child: SizedBox(
                  height: gridHeight,
                  child: Row(
                    children: [
                      _TimeColumn(
                        width: _WeekGrid._timeColWidth,
                        sectionCount: widget.semester.sectionCount,
                        sectionHeight: sectionHeight,
                        sectionClock: widget.semester.sectionClock,
                        currentSection: currentSection,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            // 今日整列染色(只在本周生效)
                            Positioned.fill(
                              child: Row(
                                children: [
                                  for (int i = 0; i < 7; i++)
                                    Expanded(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        color:
                                            (widget.isCurrentWeek &&
                                                _sameDay(days[i], today))
                                            ? accentResolved.withValues(
                                                alpha: 0.14,
                                              )
                                            : const Color(0x00000000),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            _GridBackground(
                              sectionCount: widget.semester.sectionCount,
                              sectionHeight: sectionHeight,
                              dayWidth: dayWidth,
                              highlightSection: currentSection,
                            ),
                            _DragSelectionOverlay(
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
                              onStart: (dayIdx, sec) => setState(
                                () => _drag = (
                                  dayIdx: dayIdx,
                                  startSec: sec,
                                  endSec: sec,
                                ),
                              ),
                              onUpdate: (sec) {
                                if (_drag == null) return;
                                final s = _drag!.startSec;
                                final e = sec.clamp(
                                  1,
                                  widget.semester.sectionCount,
                                );
                                setState(
                                  () => _drag = (
                                    dayIdx: _drag!.dayIdx,
                                    startSec: s,
                                    endSec: e,
                                  ),
                                );
                              },
                              onEnd: () {
                                final d = _drag;
                                if (d == null) return;
                                setState(() => _drag = null);
                                final start = d.startSec < d.endSec
                                    ? d.startSec
                                    : d.endSec;
                                final end = d.startSec < d.endSec
                                    ? d.endSec
                                    : d.startSec;
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
                                left: dayWidth * (ec.dayOfWeek - 1),
                                top: sectionHeight * (ec.startSection - 1),
                                width: dayWidth,
                                height:
                                    sectionHeight *
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
            color: CupertinoTheme.of(context).primaryColor,
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        Text(
          DateFormat('M/d').format(date),
          style: TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
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
    required this.highlightSection,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;
  final int? highlightSection;

  @override
  Widget build(BuildContext context) {
    final lineColor = CupertinoColors.separator
        .resolveFrom(context)
        .withValues(alpha: 0.3);
    final highlightColor = CupertinoTheme.of(
      context,
    ).primaryColor.withValues(alpha: 0.10);
    return CustomPaint(
      size: Size.infinite,
      painter: _GridPainter(
        sectionCount: sectionCount,
        sectionHeight: sectionHeight,
        dayWidth: dayWidth,
        lineColor: lineColor,
        highlightSection: highlightSection,
        highlightColor: highlightColor,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.sectionCount,
    required this.sectionHeight,
    required this.dayWidth,
    required this.lineColor,
    required this.highlightSection,
    required this.highlightColor,
  });

  final int sectionCount;
  final double sectionHeight;
  final double dayWidth;
  final Color lineColor;
  final int? highlightSection;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 当前节高亮带
    if (highlightSection != null &&
        highlightSection! >= 1 &&
        highlightSection! <= sectionCount) {
      final yTop = sectionHeight * (highlightSection! - 1);
      final rect = Rect.fromLTWH(0, yTop, size.width, sectionHeight);
      canvas.drawRect(rect, Paint()..color = highlightColor);
    }
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5;
    // 竖线(8 条,把 7 列分隔开)
    for (var d = 0; d <= 7; d++) {
      final x = dayWidth * d;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // 横线(sectionCount + 1 条)
    for (var i = 0; i <= sectionCount; i++) {
      final y = sectionHeight * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.sectionCount != sectionCount ||
      old.sectionHeight != sectionHeight ||
      old.dayWidth != dayWidth ||
      old.lineColor != lineColor ||
      old.highlightSection != highlightSection ||
      old.highlightColor != highlightColor;
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn({
    required this.width,
    required this.sectionCount,
    required this.sectionHeight,
    required this.sectionClock,
    required this.currentSection,
  });

  final double width;
  final int sectionCount;
  final double sectionHeight;
  final List<String> sectionClock;
  final int? currentSection;

  (String, String) _split(int i) {
    if (i < 1 || i > sectionClock.length) return ('', '');
    final parts = sectionClock[i - 1].split('-');
    if (parts.length != 2) return ('', '');
    return (parts[0], parts[1]);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          for (int i = 1; i <= sectionCount; i++)
            _SectionTimeCell(
              section: i,
              start: _split(i).$1,
              end: _split(i).$2,
              isCurrent: currentSection == i,
              height: sectionHeight,
            ),
        ],
      ),
    );
  }
}

class _SectionTimeCell extends StatelessWidget {
  const _SectionTimeCell({
    required this.section,
    required this.start,
    required this.end,
    required this.isCurrent,
    required this.height,
  });

  final int section;
  final String start;
  final String end;
  final bool isCurrent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final accentResolved = CupertinoDynamicColor.resolve(accent, context);
    final subColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final showTime = height >= 44 && start.isNotEmpty;
    final circleSize = showTime ? 22.0 : 20.0;
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: circleSize,
              height: circleSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent
                    ? accentResolved
                    : accentResolved.withValues(alpha: 0.12),
              ),
              child: Text(
                '$section',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isCurrent ? CupertinoColors.white : accentResolved,
                ),
              ),
            ),
            if (showTime) ...[
              const SizedBox(height: 3),
              Text(start, style: TextStyle(fontSize: 9, color: subColor)),
              Text(end, style: TextStyle(fontSize: 9, color: subColor)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 透明拖选层。
/// - 单点空格子 → 直接进编辑页,单节预填。
/// - 长按空格子 → 进入拖选态(轻震动),按住再向下滑可扩展多节,松手建课。
/// - 命中已有课程块时不吃事件,让 CourseBlock 自己的 onTap 处理。
/// - 普通竖滑 / 横滑不吃,避免和 SingleChildScrollView / PageView 冲突。
class _DragSelectionOverlay extends StatelessWidget {
  const _DragSelectionOverlay({
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
    final dx = local.dx;
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
                    left: dayWidth * drag!.dayIdx + 2,
                    top:
                        sectionHeight *
                            ((drag!.startSec < drag!.endSec
                                    ? drag!.startSec
                                    : drag!.endSec) -
                                1) +
                        2,
                    width: dayWidth - 4,
                    height:
                        sectionHeight *
                            ((drag!.startSec - drag!.endSec).abs() + 1) -
                        4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: CupertinoTheme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: CupertinoTheme.of(context).primaryColor,
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
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
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
