import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schedule/data/event_item.dart';
import 'package:schedule/data/reminder.dart';
import 'package:schedule/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            calls.add(call);
            if (call.method == 'initialize') return true;
            if (call.method == 'checkPermissions') return {'isEnabled': true};
            if (call.method == 'getNotificationAppLaunchDetails') {
              return {
                'notificationLaunchedApp': true,
                'notificationResponse': {
                  'notificationId': 1,
                  'notificationResponseType': 0,
                  'payload': 'schedule://study?id=task',
                },
              };
            }
            return null;
          },
        );
  });
  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
  });
  test('cold notification launch is consumed once after startup', () async {
    await NotificationService.init();
    expect(
      NotificationService.consumeInitialDeepLink().toString(),
      'schedule://study?id=task',
    );
    expect(NotificationService.consumeInitialDeepLink(), isNull);
  });
  test(
    'native requests use different IDs for distinct reminder times',
    () async {
      await NotificationService.init();
      calls.clear();
      final start = DateTime.now().add(const Duration(days: 3));
      await NotificationService.rescheduleAll(
        studyItems: [],
        events: [
          EventItem(
            id: 'e',
            title: 'E',
            startAt: start,
            endAt: start.add(const Duration(hours: 1)),
            reminders: [
              Reminder(amount: 1, unit: ReminderUnit.day),
              Reminder(amount: 2, unit: ReminderUnit.hour),
            ],
          ),
        ],
        courses: [],
        courseReminders: {},
        weeklyDigestEnabled: false,
      );
      final scheduled = calls
          .where((c) => c.method == 'zonedSchedule')
          .toList();
      expect(scheduled.length, 2);
      expect(scheduled.map((c) => c.arguments['id']).toSet().length, 2);
      expect(
        scheduled.every((c) => c.arguments['matchDateTimeComponents'] == null),
        isTrue,
      );
    },
  );
}
