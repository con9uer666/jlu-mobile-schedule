import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keep date-dependent pages current even when their data has not changed.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});
