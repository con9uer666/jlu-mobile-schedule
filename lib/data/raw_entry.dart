class CourseRawEntry {
  CourseRawEntry({
    required this.name,
    required this.teacher,
    required this.location,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.weeks,
  });

  final String name;
  final String teacher;
  final String location;
  final int dayOfWeek;
  final int startSection;
  final int endSection;
  final List<int> weeks;
}

class JwappFetchResult {
  JwappFetchResult({required this.entries, required this.semesterName});

  final List<CourseRawEntry> entries;
  final String? semesterName;
}

class JwappException implements Exception {
  JwappException(this.message);
  final String message;

  @override
  String toString() => 'JwappException: $message';
}
