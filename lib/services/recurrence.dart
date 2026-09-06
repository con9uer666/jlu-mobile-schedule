import '../data/event_item.dart';
import '../data/recurrence_rule.dart';

class Occurrence {
  Occurrence({
    required this.startAt,
    required this.endAt,
    required this.index,
    required this.eventId,
  });

  final DateTime startAt;
  final DateTime endAt;
  final int index;
  final String eventId;
}

/// 展开一个 [EventItem] 在 [windowStart, windowEnd] 区间内的发生点。
///
/// - 用本地 wall-clock(DateTime 构造器自动归一化),避免 DST 偏移。
/// - monthly 31 号、yearly 2/29 等无效组合按 iCal 语义跳过(不 clamp 到月末)。
/// - `until` 优先于 `count`(模型上互斥,这里取 until 在前)。
/// - 返回结果按 startAt 升序;最多 [maxCount] 个。
List<Occurrence> expandOccurrences({
  required EventItem event,
  required DateTime windowStart,
  required DateTime windowEnd,
  int maxCount = 60,
}) {
  final rule = event.recurrence;
  final duration = event.duration;
  final anchor = event.startAt;
  final out = <Occurrence>[];

  void emit(DateTime start, int idx) {
    if (start.isAfter(windowEnd)) return;
    final end = start.add(duration);
    if (end.isBefore(windowStart)) return;
    out.add(Occurrence(
      startAt: start,
      endAt: end,
      index: idx,
      eventId: event.id,
    ));
  }

  if (rule == null || rule.isNever) {
    emit(anchor, 0);
    return out;
  }

  final interval = rule.interval < 1 ? 1 : rule.interval;
  final until = rule.until;
  final maxByCount = rule.count;

  int produced = 0;
  int idx = 0;

  switch (rule.freq) {
    case RecurrenceFreq.daily:
      while (true) {
        final dt = DateTime(
          anchor.year,
          anchor.month,
          anchor.day + interval * idx,
          anchor.hour,
          anchor.minute,
          anchor.second,
        );
        if (until != null && _afterDay(dt, until)) break;
        if (maxByCount != null && produced >= maxByCount) break;
        if (dt.isAfter(windowEnd)) break;
        emit(dt, idx);
        produced++;
        idx++;
        if (out.length >= maxCount) break;
      }
      break;

    case RecurrenceFreq.weekly:
      final weekdays = (rule.byWeekday == null || rule.byWeekday!.isEmpty)
          ? <int>[anchor.weekday]
          : (List<int>.from(rule.byWeekday!)..sort());
      // 找出 anchor 所在周的周一(weekday=1)。
      final weekStart = DateTime(
        anchor.year,
        anchor.month,
        anchor.day - (anchor.weekday - 1),
        anchor.hour,
        anchor.minute,
        anchor.second,
      );
      int weekIdx = 0;
      while (out.length < maxCount) {
        for (final wd in weekdays) {
          final dt = DateTime(
            weekStart.year,
            weekStart.month,
            weekStart.day + weekIdx * 7 * interval + (wd - 1),
            anchor.hour,
            anchor.minute,
            anchor.second,
          );
          if (dt.isBefore(anchor)) continue;
          if (until != null && _afterDay(dt, until)) {
            return out;
          }
          if (maxByCount != null && produced >= maxByCount) return out;
          if (dt.isAfter(windowEnd)) return out;
          emit(dt, idx);
          produced++;
          idx++;
          if (out.length >= maxCount) return out;
        }
        weekIdx++;
        if (weekIdx > 520) break; // safety, ~10 年
      }
      break;

    case RecurrenceFreq.monthly:
      final days = (rule.byMonthDay == null || rule.byMonthDay!.isEmpty)
          ? <int>[anchor.day]
          : (List<int>.from(rule.byMonthDay!)..sort());
      int monthIdx = 0;
      while (out.length < maxCount) {
        final ym = _addMonths(anchor.year, anchor.month, monthIdx * interval);
        for (final d in days) {
          final dt = DateTime(
            ym.$1,
            ym.$2,
            d,
            anchor.hour,
            anchor.minute,
            anchor.second,
          );
          // 跳过无效月日(如 2/31 会被构造器进位)。
          if (dt.month != ym.$2 || dt.day != d) continue;
          if (dt.isBefore(anchor)) continue;
          if (until != null && _afterDay(dt, until)) return out;
          if (maxByCount != null && produced >= maxByCount) return out;
          if (dt.isAfter(windowEnd)) return out;
          emit(dt, idx);
          produced++;
          idx++;
          if (out.length >= maxCount) return out;
        }
        monthIdx++;
        if (monthIdx > 240) break;
      }
      break;

    case RecurrenceFreq.yearly:
      int yIdx = 0;
      while (out.length < maxCount) {
        final dt = DateTime(
          anchor.year + yIdx * interval,
          anchor.month,
          anchor.day,
          anchor.hour,
          anchor.minute,
          anchor.second,
        );
        // 跳过非闰年的 2/29 等
        if (dt.month != anchor.month || dt.day != anchor.day) {
          yIdx++;
          if (yIdx > 50) break;
          continue;
        }
        if (dt.isBefore(anchor)) {
          yIdx++;
          continue;
        }
        if (until != null && _afterDay(dt, until)) return out;
        if (maxByCount != null && produced >= maxByCount) return out;
        if (dt.isAfter(windowEnd)) return out;
        emit(dt, idx);
        produced++;
        idx++;
        yIdx++;
        if (yIdx > 50) break;
      }
      break;

    case RecurrenceFreq.none:
      emit(anchor, 0);
      break;
  }

  return out;
}

/// daily 用纯局部变量,无需全局游标。

bool _afterDay(DateTime a, DateTime b) {
  final ay = DateTime(a.year, a.month, a.day);
  final by = DateTime(b.year, b.month, b.day);
  return ay.isAfter(by);
}

(int, int) _addMonths(int y, int m, int delta) {
  final total = (y * 12 + (m - 1)) + delta;
  return (total ~/ 12, total % 12 + 1);
}
