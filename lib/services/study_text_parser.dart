import '../data/course.dart';
import '../data/study_item.dart';

class StudyParseResult {
  const StudyParseResult({required this.item, required this.matchedTime});

  final StudyItem item;
  final bool matchedTime;
}

class StudyTextParser {
  const StudyTextParser._();

  static StudyParseResult parse(
    String input, {
    DateTime? now,
    List<Course> courses = const [],
    int defaultHour = 22,
    StudyItemKind? preferredKind,
  }) {
    final base = now ?? DateTime.now();
    final text = input.trim();
    final kind = preferredKind ?? _detectKind(text);
    final date = _detectDate(text, base);
    final time = _detectTime(text, kind);
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time?.$1 ?? defaultHour,
      time?.$2 ?? 0,
    );
    final course = _matchCourse(text, courses);
    final title = _cleanTitle(text, kind, course?.name);
    final duration = kind == StudyItemKind.exam
        ? const Duration(hours: 2)
        : Duration.zero;
    return StudyParseResult(
      matchedTime: time != null,
      item: StudyItem(
        id: 'study_${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        title: title.isEmpty ? _fallbackTitle(kind, course?.name) : title,
        startAt: at,
        endAt: kind == StudyItemKind.exam ? at.add(duration) : null,
        courseId: kind == StudyItemKind.personal ? null : course?.id,
        location: kind == StudyItemKind.exam ? _detectLocation(text) : null,
      ),
    );
  }

  static StudyItemKind _detectKind(String text) {
    if (text.contains('考试') || text.contains('测验') || text.contains('考场')) {
      return StudyItemKind.exam;
    }
    if (text.contains('作业') || text.contains('提交') || text.contains('交')) {
      return StudyItemKind.assignment;
    }
    return StudyItemKind.personal;
  }

  static DateTime _detectDate(String text, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    if (text.contains('后天')) return today.add(const Duration(days: 2));
    if (text.contains('明天') || text.contains('明早') || text.contains('明晚')) {
      return today.add(const Duration(days: 1));
    }
    if (text.contains('今天') || text.contains('今晚') || text.contains('今早')) {
      return today;
    }

    final match = RegExp(r'(下|本|这)?(?:周|星期)([一二三四五六日天])').firstMatch(text);
    if (match != null) {
      final wanted =
          '一二三四五六日'.indexOf(match.group(2)!.replaceAll('天', '日')) + 1;
      var delta = wanted - now.weekday;
      if (match.group(1) == '下') {
        delta += delta > 0 ? 7 : 14;
      } else if (delta <= 0) {
        delta += 7;
      }
      return today.add(Duration(days: delta));
    }

    final numeric = RegExp(r'(\d{1,2})月(\d{1,2})[日号]?').firstMatch(text);
    if (numeric != null) {
      var year = now.year;
      final candidate = DateTime(
        year,
        int.parse(numeric.group(1)!),
        int.parse(numeric.group(2)!),
      );
      if (candidate.isBefore(today)) year++;
      return DateTime(year, candidate.month, candidate.day);
    }
    return today;
  }

  static (int, int)? _detectTime(String text, StudyItemKind kind) {
    final colon = RegExp(
      r'(?<!\d)([01]?\d|2[0-3])[:：]([0-5]\d)',
    ).firstMatch(text);
    if (colon != null)
      return (int.parse(colon.group(1)!), int.parse(colon.group(2)!));

    final match = RegExp(
      r'(凌晨|早上|上午|中午|下午|晚上|今晚|明早|明晚)?([零〇一二两三四五六七八九十百\d]{1,3})点(?:(半)|([零〇一二两三四五六七八九十\d]{1,2})分?)?',
    ).firstMatch(text);
    if (match == null) return null;
    var hour = _chineseNumber(match.group(2)!);
    final period = match.group(1) ?? '';
    if ((period.contains('下午') ||
            period.contains('晚上') ||
            period.contains('晚')) &&
        hour < 12)
      hour += 12;
    if (period == '中午' && hour < 11) hour += 12;
    if (period == '凌晨' && hour == 12) hour = 0;
    if (period.isEmpty && kind == StudyItemKind.assignment && hour < 12) {
      hour += 12;
    }
    final minute = match.group(3) != null
        ? 30
        : _chineseNumber(match.group(4) ?? '0');
    if (hour > 23 || minute > 59) return null;
    return (hour, minute);
  }

  static int _chineseNumber(String value) {
    final direct = int.tryParse(value);
    if (direct != null) return direct;
    const digits = {
      '零': 0,
      '〇': 0,
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (value == '十') return 10;
    if (value.contains('十')) {
      final parts = value.split('十');
      return (parts.first.isEmpty ? 1 : digits[parts.first] ?? 0) * 10 +
          (parts.length == 1 || parts.last.isEmpty
              ? 0
              : digits[parts.last] ?? 0);
    }
    var result = 0;
    for (final rune in value.runes) {
      result = result * 10 + (digits[String.fromCharCode(rune)] ?? 0);
    }
    return result;
  }

  static Course? _matchCourse(String text, List<Course> courses) {
    Course? best;
    for (final course in courses) {
      if (text.contains(course.name) &&
          (best == null || course.name.length > best.name.length)) {
        best = course;
      }
    }
    return best;
  }

  static String _cleanTitle(
    String text,
    StudyItemKind kind,
    String? courseName,
  ) {
    var value = text
        .replaceAll(RegExp(r'(今天|明天|后天|今晚|明早|明晚)'), '')
        .replaceAll(RegExp(r'(下|本|这)?(?:周|星期)[一二三四五六日天]'), '')
        .replaceAll(RegExp(r'\d{1,2}月\d{1,2}[日号]?'), '')
        .replaceAll(
          RegExp(
            r'(凌晨|早上|上午|中午|下午|晚上)?[零〇一二两三四五六七八九十百\d]{1,3}点(?:半|[零〇一二两三四五六七八九十\d]{1,2}分?)?',
          ),
          '',
        )
        .replaceAll(RegExp(r'(?<!\d)([01]?\d|2[0-3])[:：][0-5]\d'), '')
        .replaceAll(RegExp(r'^(请|记得|提醒我)'), '')
        .replaceAll(RegExp(r'[，,。！!]+'), ' ')
        .trim();
    if (kind == StudyItemKind.assignment) {
      value = value.replaceAll(RegExp(r'^(交|提交)'), '').trim();
    }
    if (kind == StudyItemKind.exam) {
      value = value.replaceAll(RegExp(r'在[^ ]+(?=考试)'), '').trim();
    }
    return value;
  }

  static String _fallbackTitle(StudyItemKind kind, String? courseName) =>
      switch (kind) {
        StudyItemKind.assignment => '${courseName ?? ''}作业',
        StudyItemKind.exam => '${courseName ?? ''}考试',
        StudyItemKind.personal => '个人待办',
      };

  static String? _detectLocation(String text) {
    final match = RegExp(r'在([^，,。 ]+)(?:考试|测验)').firstMatch(text);
    return match?.group(1);
  }
}
