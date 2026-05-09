import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/semester.dart';
import '../data/storage.dart';

final currentSemesterProvider = StateNotifierProvider<CurrentSemesterController, Semester?>(
  (ref) => CurrentSemesterController(),
);

class CurrentSemesterController extends StateNotifier<Semester?> {
  CurrentSemesterController() : super(null) {
    _load();
  }

  void _load() {
    final id = AppStorage.settings.get('currentSemesterId') as String?;
    if (id != null) {
      state = AppStorage.semesters.get(id);
    } else if (AppStorage.semesters.isNotEmpty) {
      state = AppStorage.semesters.values.first;
    }
  }

  Future<void> setCurrent(Semester semester) async {
    if (!AppStorage.semesters.containsKey(semester.id)) {
      await AppStorage.semesters.put(semester.id, semester);
    }
    await AppStorage.settings.put('currentSemesterId', semester.id);
    state = semester;
  }
}

final currentWeekProvider = StateProvider<int>((ref) {
  final sem = ref.watch(currentSemesterProvider);
  if (sem == null) return 1;
  return sem.currentWeek(DateTime.now());
});

final coursesProvider = StreamProvider<List<Course>>((ref) async* {
  yield AppStorage.courses.values.toList();
  await for (final _ in AppStorage.courses.watch()) {
    yield AppStorage.courses.values.toList();
  }
});
