import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:schedule/data/course_override.dart';
import 'package:schedule/data/course_reminder_setting.dart';
import 'package:schedule/data/raw_entry.dart';
import 'package:schedule/data/storage.dart';
import 'package:schedule/data/study_item.dart';
import 'package:schedule/services/course_import.dart';
import 'package:schedule/state/schedule_providers.dart';
import 'package:schedule/ui/semester_setup_page.dart';
import 'support/fixtures.dart';

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('schedule-tests-');
    Hive.init(dir.path);
    await AppStorage.openAll();
  });
  tearDownAll(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });
  setUp(() async {
    await AppStorage.courses.clear();
    await AppStorage.overrides.clear();
    await AppStorage.courseReminders.clear();
    await AppStorage.studyItems.clear();
    await AppStorage.semesters.clear();
    await AppStorage.settings.clear();
  });
  CourseRawEntry row(
    String name, {
    String location = 'A101',
    List<int> weeks = const [1, 2],
  }) => CourseRawEntry(
    name: name,
    teacher: '教师',
    location: location,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    weeks: weeks,
  );
  test(
    'reordering or inserting courses preserves legacy identities and associations',
    () async {
      await AppStorage.courses.put('s-0', course(name: '数学'));
      await AppStorage.courses.put('s-1', course(id: 's-1', name: '物理'));
      await AppStorage.overrides.put(
        's-0@1',
        CourseOverride(
          id: 's-0@1',
          courseId: 's-0',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
      );
      await AppStorage.courseReminders.put(
        's-0',
        CourseReminderSetting(courseId: 's-0', enabled: false),
      );
      await importCourses('s', [row('新增'), row('物理'), row('数学')]);
      expect(AppStorage.courses.get('s-0')!.name, '数学');
      expect(AppStorage.courses.get('s-1')!.name, '物理');
      expect(AppStorage.overrides.get('s-0@1')!.courseId, 's-0');
      expect(AppStorage.courseReminders.get('s-0')!.enabled, isFalse);
      final inserted = AppStorage.courses.values
          .singleWhere((c) => c.name == '新增')
          .id;
      await importCourses('s', [row('数学'), row('新增'), row('物理')]);
      expect(
        AppStorage.courses.values.singleWhere((c) => c.name == '新增').id,
        inserted,
      );
    },
  );
  test(
    'removed course references are cleaned without deleting tasks or manual courses',
    () async {
      await AppStorage.courses.put('s-0', course());
      await AppStorage.courses.put('s-manual-1', course(id: 's-manual-1'));
      await AppStorage.overrides.put(
        's-0@1',
        CourseOverride(
          id: 's-0@1',
          courseId: 's-0',
          week: 1,
          kind: CourseOverride.kindCancel,
        ),
      );
      await AppStorage.studyItems.put(
        'task',
        StudyItem(
          id: 'task',
          title: 'work',
          kind: StudyItemKind.assignment,
          startAt: DateTime(2026, 9, 8),
          courseId: 's-0',
        ),
      );
      await importCourses('s', [row('新课')]);
      expect(AppStorage.courses.containsKey('s-0'), isFalse);
      expect(AppStorage.courses.containsKey('s-manual-1'), isTrue);
      expect(AppStorage.overrides.isEmpty, isTrue);
      expect(AppStorage.studyItems.get('task')!.courseId, isNull);
      expect(AppStorage.studyItems.get('task')!.title, 'work');
    },
  );
  test(
    'different rooms in disjoint weeks are retained as separate course blocks',
    () async {
      await importCourses('s', [
        row('数学', weeks: [1]),
        row('数学', location: 'B202', weeks: [2]),
      ]);
      expect(AppStorage.courses.length, 2);
      expect(AppStorage.courses.values.map((c) => c.location).toSet(), {
        'A101',
        'B202',
      });
    },
  );
  test('failed empty import cannot wipe existing courses', () async {
    await AppStorage.courses.put('s-0', course());
    await expectLater(importCourses('s', []), throwsFormatException);
    expect(AppStorage.courses.length, 1);
  });
  testWidgets('new semester saves a new ID and returns from editor', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.runAsync(
      () => container
          .read(currentSemesterProvider.notifier)
          .setCurrent(semester()),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: Builder(
            builder: (context) => CupertinoButton(
              child: const Text('create'),
              onPressed: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) => const SemesterSetupPage(createNew: true),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('create'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('保存'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final saveButton = tester.widget<CupertinoButton>(
      find.ancestor(
        of: find.text('保存'),
        matching: find.byType(CupertinoButton),
      ),
    );
    await tester.runAsync(saveButton.onPressed as Future<void> Function());
    await tester.pumpAndSettle();
    expect(AppStorage.semesters.length, 2);
    expect(AppStorage.semesters.get('s')!.name, 'S');
    expect(container.read(currentSemesterProvider)!.id, isNot('s'));
    expect(find.text('create'), findsOneWidget);
  });
}
