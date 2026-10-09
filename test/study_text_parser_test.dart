import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course.dart';
import 'package:schedule/data/study_item.dart';
import 'package:schedule/services/study_text_parser.dart';

void main() {
  final now = DateTime(2026, 9, 8, 12);
  final course = Course(
    id: 'semester-高频',
    name: '高频电子技术',
    teacher: '',
    location: '',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    weeks: const [1],
  );

  test('解析作业、课程和晚上时间', () {
    final parsed = StudyTextParser.parse(
      '周五晚上十点交高频电子技术作业',
      now: now,
      courses: [course],
    ).item;
    expect(parsed.kind, StudyItemKind.assignment);
    expect(parsed.courseId, course.id);
    expect(parsed.startAt, DateTime(2026, 9, 11, 22));
  });

  test('解析下周考试、中文时间和考场', () {
    final parsed = StudyTextParser.parse('下周三下午两点在一教考试', now: now).item;
    expect(parsed.kind, StudyItemKind.exam);
    expect(parsed.startAt, DateTime(2026, 9, 16, 14));
    expect(parsed.location, '一教');
    expect(parsed.endAt, DateTime(2026, 9, 16, 16));
  });

  test('无具体时间使用晚上十点默认值', () {
    final parsed = StudyTextParser.parse('明天交作业', now: now).item;
    expect(parsed.startAt, DateTime(2026, 9, 9, 22));
  });

  test('作业中没有时段的十点按晚上十点解析', () {
    final parsed = StudyTextParser.parse('周五十点交高频作业', now: now).item;
    expect(parsed.startAt, DateTime(2026, 9, 11, 22));
  });

  test('普通语句默认为个人待办', () {
    final parsed = StudyTextParser.parse('今晚七点取快递', now: now).item;
    expect(parsed.kind, StudyItemKind.personal);
    expect(parsed.startAt, DateTime(2026, 9, 8, 19));
    expect(parsed.title, contains('取快递'));
  });
}
