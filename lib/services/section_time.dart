import '../data/semester.dart';

class SectionStatus {
  SectionStatus({this.section, this.toEnd, this.toNext});
  final int? section;
  final Duration? toEnd;
  final Duration? toNext;

  bool get inClass => section != null && toEnd != null;
  bool get inBreak => section == null && toNext != null;
  bool get noClass => section == null && toNext == null;
}

/// 根据当前时刻判断:
/// - 落在某节区间内 → section + toEnd
/// - 在两节之间 → toNext(距下一节的起始)
/// - 在第一节前或最后一节后 → noClass
SectionStatus currentStatus(Semester sem, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  for (int i = 1; i <= sem.sectionCount; i++) {
    final startStr = sem.sectionStart(i);
    final endStr = sem.sectionEnd(i);
    final start = _parseTime(today, startStr);
    final end = _parseTime(today, endStr);
    if (start == null || end == null) continue;
    if (now.isBefore(start)) {
      // 还没到第 i 节,toNext = start - now
      return SectionStatus(toNext: start.difference(now));
    }
    if (now.isBefore(end)) {
      return SectionStatus(section: i, toEnd: end.difference(now));
    }
  }
  return SectionStatus();
}

DateTime? _parseTime(DateTime day, String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  return DateTime(day.year, day.month, day.day, h, m);
}
