String manualCourseId(String semesterId, {DateTime? now}) {
  final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
  return '$semesterId-manual-$stamp';
}

bool isManualCourseId(String semesterId, String courseId) =>
    courseId.startsWith('$semesterId-manual-');

bool isLegacyManualCourseId(String courseId) =>
    RegExp(r'^\d{13,}$').hasMatch(courseId);
