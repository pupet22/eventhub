import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../models/event.dart';
import 'reminder_web_store_stub.dart'
    if (dart.library.html) 'reminder_web_store_web.dart'
    as web_store;

class ReminderNotificationService {
  ReminderNotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'event_reminders';
  static const String _channelName = 'Event reminders';
  static const String _channelDescription =
      'Reminders for events you are registered for.';

  static Future<void> initialize() async {
    if (kIsWeb) return;
    timezone_data.initializeTimeZones();

    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(timezone.getLocation(localTimezone.identifier));
    } catch (_) {
      // BulSU students are generally in the Philippines. Use Manila if the
      // device does not return a recognized IANA timezone.
      timezone.setLocalLocation(timezone.getLocation('Asia/Manila'));
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notifications.initialize(settings: initializationSettings);
  }

  static int _notificationId(String eventId) {
    var id = eventId.codeUnits.fold<int>(
      0,
      (value, codeUnit) => ((value * 31) + codeUnit) & 0x7fffffff,
    );

    if (id == 0) id = 1;
    return id;
  }

  static Future<bool> isReminderScheduled(String eventId) async {
    if (kIsWeb) return web_store.isEnabled(eventId);

    final pendingNotifications = await _notifications
        .pendingNotificationRequests();

    final id = _notificationId(eventId);
    return pendingNotifications.any((notification) => notification.id == id);
  }

  static Future<bool> scheduleReminder(Event event) async {
    final reminderDate = event.startsAt.subtract(const Duration(days: 1));

    if (!kIsWeb && !reminderDate.isAfter(DateTime.now())) {
      throw StateError(
        'This event is less than one day away, so a 1-day reminder cannot be set.',
      );
    }

    if (kIsWeb) {
      web_store.enable(event.id);
      return true;
    }

    final androidNotifications = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final permissionGranted = await androidNotifications
        ?.requestNotificationsPermission();

    if (permissionGranted == false) {
      return false;
    }

    await _notifications.zonedSchedule(
      id: _notificationId(event.id),
      title: 'Event reminder',
      body: '${event.name} starts in 1 day at ${event.location}.',
      scheduledDate: timezone.TZDateTime.from(reminderDate, timezone.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: event.id,
    );

    return true;
  }

  static Future<void> cancelReminder(String eventId) async {
    if (kIsWeb) {
      web_store.disable(eventId);
      return;
    }

    await _notifications.cancel(id: _notificationId(eventId));
  }
}
