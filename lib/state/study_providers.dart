import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/storage.dart';
import '../data/study_item.dart';

final studyItemsProvider = StreamProvider<List<StudyItem>>((ref) async* {
  List<StudyItem> snapshot() =>
      AppStorage.studyItems.values.toList()
        ..sort((a, b) => a.timelineAt.compareTo(b.timelineAt));
  yield snapshot();
  await for (final _ in AppStorage.studyItems.watch()) {
    yield snapshot();
  }
});

class StudyItemsController {
  Future<void> save(StudyItem item) => AppStorage.studyItems.put(item.id, item);
  Future<void> delete(String id) => AppStorage.studyItems.delete(id);
  Future<void> setCompleted(StudyItem item, bool completed) async {
    item.completedAt = completed ? DateTime.now() : null;
    await item.save();
  }
}

final studyItemsControllerProvider = Provider<StudyItemsController>(
  (ref) => StudyItemsController(),
);
