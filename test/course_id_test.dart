import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/course_id.dart';

void main() {
  test('手动课程 ID 属于当前学期且能和导入课程区分', () {
    final id = manualCourseId(
      '2026-fall',
      now: DateTime.fromMicrosecondsSinceEpoch(123456),
    );

    expect(id, '2026-fall-manual-123456');
    expect(isManualCourseId('2026-fall', id), isTrue);
    expect(isManualCourseId('2026-fall', '2026-fall-12'), isFalse);
    expect(isManualCourseId('2025-fall', id), isFalse);
  });

  test('识别旧版纯时间戳课程 ID', () {
    expect(isLegacyManualCourseId('1788854000123'), isTrue);
    expect(isLegacyManualCourseId('2026-fall-12'), isFalse);
    expect(isLegacyManualCourseId('123'), isFalse);
  });
}
