import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      
      tz.initializeTimeZones();
      await _notificationsPlugin.initialize(initializationSettings);
      debugPrint("🔔 Notification service initialized successfully.");
    } catch (e) {
      debugPrint("⚠️ Failed to initialize notifications: $e");
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      if (scheduledDate.isBefore(DateTime.now())) return;

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'subscription_channel',
            'Subscription Reminders',
            channelDescription: 'Reminders about free trial expiration',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("🔔 Scheduled notification $id for $scheduledDate");
    } catch (e) {
      debugPrint("⚠️ Failed to schedule notification: $e");
    }
  }

  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
      debugPrint("🔔 Cancelled all scheduled notifications.");
    } catch (e) {
      debugPrint("⚠️ Failed to cancel notifications: $e");
    }
  }
}
